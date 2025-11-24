# Database Migration Documentation: AWS RDS to Azure

## 1. Introduction

This document outlines the technical strategy and execution steps for migrating the mission-critical production database from **AWS RDS (MySQL)** to **Azure Database for MySQL Flexible Server**.

While the overall migration includes moving static assets (Images, PDFs, and user uploads) to Azure Blob Storage, **this specific document focuses exclusively on the Database Migration**.

### 1.1 Methodology: Data-in Replication

For this migration, we have selected the **"Data-in Replication"** (or Hybrid Replication) methodology.

Instead of a simple "Export and Import" approach—which would require shutting down the application for several hours to prevent data loss—this method utilizes a continuous synchronization process. We establish a real-time link between AWS (Master) and Azure (Replica) using MySQL Binary Logs (`binlogs`).

### 1.2 Why this Approach?

We chose this strategy to address three critical requirements:

1.  **Minimal Downtime (Business Continuity):**
    *   *Standard Method:* Requires stopping the app during the entire export/import process (potentially hours).
    *   *Replication Method:* The application remains live and functional on AWS while data is being copied to Azure in the background. Downtime is restricted only to the final "Cutover" moment (typically 5-10 minutes).

2.  **Data Consistency & Integrity:**
    *   By utilizing `binlog_format = ROW`, we ensure that every transaction (INSERT, UPDATE, DELETE) occurring on AWS is replicated exactly to Azure. This guarantees that no user data is lost during the transition period.

3.  **Risk Mitigation:**
    *   This approach allows us to test the Azure database with real production data *before* the actual switch. If any issues arise during the sync, the production site on AWS remains unaffected.

---

## Phase 1: Source Environment Preparation (AWS Side)

Before initiating any data transfer, the source database on AWS RDS must be configured to act as a "Replication Master." Since RDS is a managed service, we cannot edit configuration files directly; we must use **DB Parameter Groups**.

### 1. A- Enable Binary Logs (Parameter Group Configuration)

To allow Azure to "read" changes from AWS, we must enable detailed logging.

**Steps:**

1.  **Create Parameter Group:**
    *   Navigate to **AWS Console > RDS > Parameter Groups**.
    *   Create a new group (e.g., `replication-source-group`), ensuring the "Family" matches your DB engine version (e.g., `mysql8.0`).

2.  **Edit Parameters:**
    Modify the following settings within the group:
    *   **`binlog_format`**: Set to **`ROW`**.
        *   *Reason:* Azure requires Row-based logging to ensure exact data replication and compatibility.
    *   **`binlog_retention_hours`**: Set to **`24`** (or higher).
        *   *Reason:* AWS deletes logs quickly to save space. We increase retention to 24 hours to ensure that if a network glitch disconnects Azure, the old logs are still available to resume replication without breaking the chain.

3.  **Apply & Reboot:**
    *   Modify your AWS **DB Instance** to use this new Parameter Group.
    *   Select **"Apply Immediately"**.
    *   **Action Required:** You must manually **Reboot** the RDS instance for these static parameters to take effect.

### 2. B- Create Replication User

For security purposes, we avoid sharing the Root/Admin credentials with the external Azure service. We create a dedicated user with limited privileges solely for replication.

**Execution (SQL Command):**
Run this on the AWS Database:

```sql
-- 1. Create a dedicated user
CREATE USER 'repl_user'@'%' IDENTIFIED BY 'StrongPassword123';

-- 2. Grant Replication Privileges
-- This user only needs to read the binary logs, not modify data.
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

-- 3. Apply Changes
FLUSH PRIVILEGES;
```

### 3. C- Network Access (Security Groups)

By default, AWS firewalls (Security Groups) block external traffic. We must explicitly allow Azure to connect to the database port.

**Steps:**

1.  Go to **AWS Console > EC2 > Security Groups**.
2.  Select the Security Group attached to the RDS instance.
3.  Edit **Inbound Rules** and add:
    *   **Type:** `MySQL/Aurora` (Port 3306).
    *   **Source:**
        *   *Production:* Enter the specific Public IP of the Azure Database service.
        *   *Testing:* `0.0.0.0/0` (Allow all - **Warning:** Must be removed immediately after migration).

## Phase 2: Initial Data Load & Coordinate Extraction

With the AWS source prepared, the next objective is to transfer the existing historical data to Azure. Crucially, this process must also capture the specific binary log position (coordinates) at the exact moment the backup is taken. This ensures Azure knows exactly where to resume synchronization.

### 2.1. Create Consistent Snapshot (Data Dump)

We use the `mysqldump` utility to create a logical backup. Specific flags are used to ensure the database remains online and to automatically record the replication coordinates.

**Execution:**
Run the following command from a secure intermediary server (e.g., the Backend EC2 instance):

```bash
mysqldump -h obelion-aws.rds.amazonaws.com \
          -u admin_user -p \
          --databases obelion_db \
          --single-transaction \
          --master-data=2 \
          --order-by-primary \
          > initial_backup.sql
```

**Key Parameter Explanation:**

*   **`--single-transaction`**: Ensures the backup is taken within a single transaction scope. This prevents table locking, allowing the live application to continue running without interruption.
*   **`--master-data=2`**: **(Critical)** This flag appends a comment inside the dump file containing the current Binary Log File name and Position. This is required to configure the replication link later.
*   **`--order-by-primary`**: Optimizes the dump by sorting data by Primary Key, which speeds up the restore process on Azure.

### 2.2. Extract Replication Coordinates

Before importing the data, we must retrieve the binary log coordinates embedded in the dump file. These coordinates serve as the "bookmark" for the replication process.

**Execution:**
Run the following command to read the file header:

```bash
head -n 50 initial_backup.sql | grep "CHANGE MASTER"
```

**Expected Output:**
You will see a line similar to this:

```sql
-- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin-changelog.000034', MASTER_LOG_POS=10245;
```

**Action Required:**
Securely note down the values for:

1.  **`MASTER_LOG_FILE`** (e.g., `mysql-bin-changelog.000034`)
2.  **`MASTER_LOG_POS`** (e.g., `10245`)

*These values will be used as parameters in Phase 3.*

### 2.3. Restore Data to Target (Azure)

With the backup file ready and coordinates saved, we upload the schema and data to the new Azure Database instance.

**Execution:**
Connect to the Azure MySQL instance and pipe the SQL file:

```bash
mysql -h obelion-azure.mysql.database.azure.com \
      -u azure_admin -p \
      obelion_db < initial_backup.sql
```

**Outcome:**

*   The Azure database now contains a mirror image of the AWS database **as it existed at the time of the dump**.
*   Any data written to AWS during the time taken to Dump and Restore is currently missing from Azure. This "delta" will be retrieved in the next phase.

## Phase 3: Establishing Replication (Synchronization)

With the initial dataset loaded into Azure, we must now configure the Azure instance to act as a "Replica." It will connect to the AWS "Master," read the binary logs starting from the coordinates obtained in Phase 2, and apply all subsequent transactions to bring the data into real-time synchronization.

**Important:** All SQL commands in this phase must be executed on the **Target Database (Azure)**.

### 3.1. Configure External Master

Since Azure Database for MySQL is a managed service, standard native replication commands are replaced by Azure-specific Stored Procedures. We will use `mysql.az_replication_change_master` to define the source connection.

**Execution (SQL on Azure):**
Replace the placeholders with the actual values recorded in previous steps:

```sql
CALL mysql.az_replication_change_master(
    'obelion-aws.rds.amazonaws.com',   -- Source (AWS) Hostname
    'repl_user',                       -- Replication Username (Created in Phase 1)
    'StrongPassword123',               -- Replication User Password
    3306,                              -- Port Number
    'mysql-bin-changelog.000034',      -- Master Log File (From Phase 2 Dump)
    10245,                             -- Master Log Position (From Phase 2 Dump)
    ''                                 -- GTID Mode (Leave empty unless explicitly configured)
);
```

**Function:**
This command registers the AWS instance as the upstream master and instructs Azure to prepare for synchronization starting specifically from the defined Log File and Position.

### 3.2. Start Replication

Once the configuration is applied, we must explicitly start the replication threads.

**Execution (SQL on Azure):**

```sql
CALL mysql.az_replication_start;
```

**Function:**
Azure immediately initiates a connection to AWS. The IO Thread begins downloading binary logs, and the SQL Thread begins applying the events (Inserts, Updates, Deletes) to the Azure database.

### 3.3. Monitor Replication Status (The "Catch-up" Phase)

Initially, Azure will be "behind" AWS because it needs to process all data generated since the backup was taken. We must monitor the lag until the databases are fully synced.

**Execution (SQL on Azure):**

```sql
SHOW SLAVE STATUS;
-- Note: In newer MySQL versions, use: SHOW REPLICA STATUS;
```

**Key Metrics to Validation:**
Inspect the output row for the following values:

1. **`Slave_IO_Running`**: Must be **`Yes`**.

   *   *If No:* Check Network Security Groups (Phase 1.3) and firewall rules.

2. **`Slave_SQL_Running`**: Must be **`Yes`**.

   *   *If No:* There may be a data conflict or permission error.

3. **`Seconds_Behind_Master`**: **(Critical Metric)**

   *   This value represents how many seconds Azure is lagging behind AWS.
   *   Initially, this number may be high (e.g., `3600` seconds).

   

   

## Phase 4: Production Cutover (Go-Live)

This phase represents the final transition. To ensure absolute data consistency, a brief maintenance window (approx. 15 minutes) is required. During this time, the application will stop accepting new data on AWS, allowing Azure to capture the final transactions before becoming the primary database.

### 4.1. Halt Application Traffic (Maintenance Mode)

To prevent "Split-Brain" scenarios (where data is written to the old database *after* the migration point), we must stop all write operations on the Source.

**Execution (Backend Server):**
Place the Laravel application into maintenance mode:

```bash
php artisan down --message="System Upgrade in Progress. Please check back in 15 minutes."
```

**Impact:**

*   Users will see a maintenance page.
*   The database enters a static state (no new INSERTs or UPDATEs on AWS).

### 4.2. Verify Zero-Lag Synchronization

With the application stopped, the replication lag should immediately drop to zero. We must confirm that Azure possesses every single byte of data present in AWS.

**Execution (SQL on Azure):**

```sql
SHOW SLAVE STATUS;
```

**Validation Criteria:**

1.  **`Slave_IO_Running`**: Yes
2.  **`Slave_SQL_Running`**: Yes
3.  **`Seconds_Behind_Master`**: **Must be `0`**.

**Warning:** Do not proceed to the next step until this value is exactly `0`. Proceeding with a lag > 0 will result in permanent data loss.

### 4.3. Promote Azure Replica to Primary

Currently, the Azure database is in "Read-Only" mode (because it is a replica). We must sever the link with AWS and promote Azure to a standalone, Read-Write Master.

**Execution (SQL on Azure):**

1. **Stop the Replication Process:**

   ```sql
   CALL mysql.az_replication_stop;
   ```

2. **Remove the Master Configuration:**
   This command permanently breaks the link to AWS and enables Write permissions on the Azure instance.

   ```sql
   CALL mysql.az_replication_remove_master;
   ```

**Status:**
The Azure Database for MySQL Flexible Server is now a fully independent, writable database containing 100% of the production data.

### 4.4. Reconfigure and Launch Application

The final step is to point the application logic to the new infrastructure.

**Steps:**

1. **Update Environment Variables:**
   On the Azure Virtual Machine (or App Service), update the `.env` file with the new credentials:

   *   `DB_HOST`: *[Insert Azure Database Endpoint]*
   *   `DB_USERNAME`: *[Insert Azure Admin User]*
   *   `DB_PASSWORD`: *[Insert Azure Password]*

2. **Restart Services:**
   Clear the application cache to ensure the new config takes effect.

   ```bash
   php artisan config:cache
   ```

3. **Disable Maintenance Mode:**
   Bring the application back online.

   ```bash
   php artisan up
   ```

4. **DNS Update:**
   Update the domain DNS records (A Record / CNAME) to point to the new Azure infrastructure IP addresses.

## Phase 5: Post-Migration Validation & Cleanup

The migration is functionally complete, but the process is not finished until the new environment is validated for stability, security loopholes are closed, and legacy resources are scheduled for decommissioning.

### 5.1. Functional Validation (Sanity Checks)

Immediately after the application is back online, the following tests must be performed to confirm that the Azure Database is functioning correctly as a "Read/Write" master.

**Checklist:**

1.  **Write Test:** Register a new user or update a profile within the application.
    *   *Success Criteria:* No error 500; data persists in the database.
2.  **Read Test:** Retrieve historical data (e.g., view an order from last year).
    *   *Success Criteria:* Data loads correctly.
3.  **Log Monitoring:** Check the Laravel application logs (`storage/logs/laravel.log`) for any SQL connection errors or timeouts.

### 5.2. Security Hardening

During Phase 1, we opened network ports to facilitate the migration. Now that the data transfer is complete, these temporary access points must be closed to secure the infrastructure.

**Steps:**

1.  **Azure Firewall:**
    *   Navigate to the **Azure Database for MySQL > Networking**.
    *   Remove the temporary firewall rule allowing `0.0.0.0/0` (if used).
    *   Ensure only the **Azure Virtual Network (VNet)** or specific Backend IP addresses are allowed.

2.  **AWS Security Groups:**
    *   Remove the Inbound Rule on the AWS RDS Security Group that allowed traffic on port 3306 from Azure.

3.  **Cleanup Users:**
    *   On the AWS database (if still accessible) and Azure database, you may drop the `repl_user` as it is no longer required.
    *   *Command:* `DROP USER 'repl_user'@'%';`

### 5.3. Asset Storage Configuration

*Note: While the bulk migration of static files (PDFs, Images) is handled in a separate workflow, the application configuration must be updated to reflect the new storage location.*

**Action:**
Ensure the `.env` file on the production server is updated to point to the new Azure Blob Storage containers instead of AWS S3.

*   `FILESYSTEM_DRIVER=azure`
*   `AZURE_STORAGE_NAME=...`
*   `AZURE_STORAGE_KEY=...`

### 5.4. Legacy Resource Decommissioning

Do not delete the AWS resources immediately. A "Cool-down" period is required to ensure no hidden issues arise.

**Strategy:**

1.  **Stop Instances:** Stop the AWS RDS instance and EC2 servers to prevent further billing, but **do not terminate/delete** them yet.
2.  **Retention Period:** Keep the AWS resources in a stopped state for **72 hours**.
3.  **Final Snapshot:** Before permanent deletion, take one final manual snapshot of the AWS RDS instance for archival purposes.
4.  **Termination:** After the retention period passes with no issues, verify the AWS bill is clear and terminate the resources.

