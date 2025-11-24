

# Static Assets Migration Documentation
**Method:** Server-to-Server Synchronization via `rsync`
**Source:** AWS EC2
**Destination:** Azure Virtual Machine

## 1. Objective
To transfer unstructured data (Product Images, User Uploads, PDFs, and Logs) from the AWS storage file system to the new Azure environment. We utilize `rsync` to ensure file permissions, modification timestamps, and directory structures are preserved exactly as they are on the source.

## 2. Prerequisites
Before executing the transfer, ensure the following:
*   **SSH Access:** You are logged into the **Azure VM** (Destination).
*   **AWS Private Key:** The `.pem` key used to access the AWS EC2 instance is available.
*   **Firewall Rules:** The AWS Security Group must allow SSH (Port 22) connections from the Azure VM's IP address.

---

## 3. Execution Steps

### Step 1: Prepare Authentication (On Azure VM)
The Azure server needs the AWS private key to authorize the file pull request.

1.  **Upload the Key:** (Run this from your **Local Machine**)
    ```bash
    scp -i azure-key.pem obelion-aws-key.pem azureuser@<AZURE_VM_IP>:/home/azureuser/
    ```

2.  **Set Key Permissions:** (Run this on **Azure VM**)
    AWS requires strict permission settings on private keys.
    ```bash
    chmod 600 /home/azureuser/obelion-aws-key.pem
    ```

### Step 2: Define Paths
Identify the source directory on AWS and the destination directory on Azure.
*(Assuming a standard Laravel structure)*

*   **Source Path:** `/var/www/html/obelion/storage/app/public/`
*   **Destination Path:** `/var/www/html/obelion/storage/app/public/`

### Step 3: Run Simulation (Dry Run)
Before moving actual data, perform a "Dry Run" to verify connection and file paths without writing any data.

**Command (Run on Azure VM):**
```bash
rsync -avz --dry-run \
  -e "ssh -i /home/azureuser/obelion-aws-key.pem" \
  ubuntu@<AWS_EC2_IP>:/var/www/html/obelion/storage/app/public/ \
  /var/www/html/obelion/storage/app/public/
```

*   **`-a` (Archive):** Preserves permissions, symlinks, and timestamps.
*   **`-v` (Verbose):** Lists files being processed.
*   **`-z` (Compress):** Compresses data to speed up transfer.
*   **`--dry-run`**: Simulates the process.

**Validation:** Check the output to ensure it lists the image/PDF files you expect to see.

### Step 4: Execute Synchronization
Remove the `--dry-run` flag to begin the actual transfer. We add `--progress` to monitor large files.

**Command (Run on Azure VM):**
```bash
rsync -avz --progress \
  -e "ssh -i /home/azureuser/obelion-aws-key.pem" \
  ubuntu@<AWS_EC2_IP>:/var/www/html/obelion/storage/app/public/ \
  /var/www/html/obelion/storage/app/public/
```

### Step 5: Fix Ownership & Permissions
`rsync` preserves the user ownership from AWS (e.g., `ubuntu` user). On Azure, the web server (Nginx/Apache) usually runs as `www-data`. If this is not fixed, the website will show "Permission Denied" errors when trying to load images.

**Command:**
```bash
# 1. Change Owner to Web Server User
sudo chown -R www-data:www-data /var/www/html/obelion/storage/app/public/

# 2. Ensure Write Permissions
sudo chmod -R 775 /var/www/html/obelion/storage/app/public/
```

---

## 4. Verification

To ensure no files were lost during transfer, compare the directory sizes.

1.  **Check Source (AWS):**
    ```bash
    du -sh /var/www/html/obelion/storage/app/public/
    # Output Example: 2.4G
    ```

2.  **Check Destination (Azure):**
    ```bash
    du -sh /var/www/html/obelion/storage/app/public/
    # Output Example: 2.4G
    ```

**Status:** If the sizes match, the Asset Migration is successful.