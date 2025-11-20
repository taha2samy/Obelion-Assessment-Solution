
# 🏗️ AWS Remote Backend Bootstrap

This project contains the **Terraform Bootstrapping** configuration. Its specific purpose is to provision the AWS resources required to store the Terraform state for the main infrastructure project securely and remotely.

## 🧐 The "Chicken and Egg" Problem

In Terraform, we face a logical paradox when setting up a Remote Backend:
1. We want to store the Terraform state in an **S3 Bucket**.
2. However, we need Terraform to **create** that S3 Bucket.
3. We cannot store the state in the S3 bucket before the bucket exists.

**The Solution:**
We use this dedicated project with a **Local State** (stored on your machine temporarily) to provision the S3 Bucket and DynamoDB Table. Once these resources exist, the main project can use them to store its state remotely.

---

## ☁️ Resources Provisioned

This code follows AWS Best Practices to create:

### 1. S3 Bucket (State Storage)
*   **Unique Naming:** Automatically generates a globally unique bucket name.
*   **Versioning Enabled:** 🛡️ Critical for recovery. Allows you to roll back to previous state versions if a file is corrupted or accidentally deleted.
*   **Server-Side Encryption (SSE):** 🔒 Encrypts state data at rest using AES-256.
*   **Public Access Block:** 🚫 Ensures the sensitive state file is never accessible via the public internet.

### 2. DynamoDB Table (State Locking)
*   **Locking Mechanism:** Prevents concurrent operations. If two engineers (or CI/CD pipelines) try to run `terraform apply` at the same time, DynamoDB locks the state to prevent corruption.

---

## 🚀 Usage Guide

This project utilizes a `Makefile` to streamline the deployment process.

### Prerequisites
*   Terraform installed (`>= 1.0.0`)
*   AWS CLI configured with valid credentials (`aws configure`)

### Deployment Steps

1.  **Initialize Terraform:**
    ```bash
    make init
    ```

2.  **Review the Plan:**
    ```bash
    make plan
    ```

3.  **Apply and Create Resources:**
    ```bash
    make apply
    ```

---

## 🔗 Integration with Main Project (GitHub Actions)

After a successful run, Terraform will display **Outputs** in your terminal. You need these values to configure the CI/CD pipeline for your main infrastructure.

### 1. Get the Values
Look for the output section in your terminal:
```text
backend_bucket_name  = "obelion-tf-state-xxxx"
backend_dynamodb_table = "obelion-tf-locks"
backend_region       = "us-east-1"
```

### 2. Configure GitHub Secrets
Go to your Main Infrastructure Repository -> **Settings** -> **Secrets and variables** -> **Actions**, and add the following secrets:

| Secret Name | Value Source | Description |
| :--- | :--- | :--- |
| `TF_BACKEND_BUCKET` | Output: `backend_bucket_name` | The S3 bucket name. |
| `TF_BACKEND_TABLE` | Output: `backend_dynamodb_table` | The DynamoDB table name. |
| `TF_BACKEND_REGION` | Output: `backend_region` | The AWS Region (eu-west-1) |

---

## ⚠️ Important Notes

1.  **Do Not Delete:** Never delete these resources manually via the AWS Console. Doing so will destroy the "memory" of your entire infrastructure.
2.  **Local State:** This specific project keeps its state locally (`terraform.tfstate` file in this directory). Do not commit this file to Git if it contains sensitive information (though this bootstrap code usually doesn't contain secrets).
