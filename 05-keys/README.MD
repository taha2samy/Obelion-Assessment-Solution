
# SSH Keys Setup 🔑

This directory is dedicated to storing the SSH keys required for accessing the Terraform-provisioned EC2 instances.

## ⚠️ Security Warning
**NEVER** commit the private key (`rsa`) to your version control system (GitHub/GitLab). The `.gitignore` file should be configured to exclude it.

## 🛠️ How to Generate the Key

To deploy the infrastructure, you need to generate an **RSA 4096-bit** key pair.

### Step-by-Step Instructions:

1. Open your terminal and navigate to this directory:
   ```bash
   cd 05-keys
   ```

2. Run the following command to generate the key pair named `rsa`:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ./rsa -N ""
   ```
   *(The `-N ""` flag creates a key without a passphrase for easier automation. Remove it if you want to set a password).*

### 📂 Expected Output
After running the command, you will have two files:

*   **`rsa`**: The **Private Key**. 
    *   *Usage:* Keep this safe. You will need to copy its content into your **GitHub Secrets** (as `SSH_PRIVATE_KEY`) for the CI/CD pipeline.
*   **`rsa.pub`**: The **Public Key**.
    *   *Usage:* The project's `Makefile` automatically reads this file and passes it to Terraform to configure the servers.
