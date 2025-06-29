

# AWS Transactions App – IaaC: Automated Infrastructure Deployment for a 3-tier web app (frontend + backend + database)

This project provisions a full-stack application on AWS using Terraform. It includes:

- React frontend (served by Nginx on EC2)
- Node.js backend (running on EC2)
- PostgreSQL database (AWS RDS)
- File storage and app delivery via AWS S3
- Full networking, IAM, and automation setup

---

```
+--------------------------------------------------------------+
|                        AWS VPC (10.0.0.0/16)                 |
|  aws-transactions-app-vpc                                    |
|                                                              |
|  +---------------------+      +---------------------------+  |
|  | Public Subnet       |      | Internet Gateway (IGW)    |  |
|  | 10.0.1.0/24         |<---->| aws-transactions-app-igw  |  |
|  |                     |      +---------------------------+  |
|  | +----------------+  |                                     |
|  | | EC2 Instance   |  |                                     |
|  | | Frontend App   |  |                                     |
|  | | Nginx Server   |  |                                     |
|  | | Public IP      |  |                                     |
|  | | Port 80/443/22 |  |                                     |
|  | +----------------+  |                                     |
|  +---------------------+                                     |
|                                                              |
|  +------------------------+   +-------------------------+    |
|  | Private Subnet 1       |   | Private Subnet 2        |    |
|  | 10.0.2.0/24            |   | 10.0.3.0/24             |    |
|  |                        |   |                         |    |
|  | +-------------------+  |   |                         |    |
|  | | EC2 Instance      |  |   |                         |    |
|  | | Backend App (Node)|  |   |  Unused. Reserved for   |    |
|  | |                   |  |   |  future RDS replica.    |    |
|  | | Port 3000/22      |  |   |                         |    |
|  | +-------------------+  |   |                         |    |
|  +------------------------+   +-------------------------+    |
|        \                             /                       |
|         \___________________________/                        |
|                  |                                           |
|                  v                                           |
|        +----------------------------+                        |
|        | RDS PostgreSQL             |                        |
|        | aws-transactions-app-db    |                        |
|        | Port 5432                  |                        |
|        +----------------------------+                        |
|                                                              |
|  +----------------------------+                              |
|  | S3 Bucket:                 |                              |
|  | aws-transactions-app-bucket|                              |
|  | - frontend/* (React build) |                              |
|  | - backend/app.zip          |                              |
|  +----------------------------+                              |
+--------------------------------------------------------------+
```

### Notes:
•	The frontend EC2 instance is in a public subnet and connected to the internet via an Internet Gateway.
•	The backend EC2 instance should be a private subnet and using NAT Gateway to install resources like node.js, aws-cli, and unzip. But the NAT Gateway is not part of AWS Free Tie, so, as a workaround, I moved the EC2 in the public subnet for it to be able to access the internat to download those resources.
•	The RDS instance is only accessible from the backend EC2.
•	The S3 bucket serves as the storage for frontend files (copied into Nginx) and the zipped backend app (downloaded and unzipped by the Node.js instance).


---

## Project Structure

```
aws-transactions-app/
├── application-code/
│   ├── web-tier/         # React frontend source and build
│   └── app-tier/         # Node.js backend (packaged as app.zip)
└── terraform-config/
    ├── main.tf           # Entry point
    ├── vpc.tf            # VPC, subnets, and internet gateway
    ├── security_groups.tf# Security group definitions
    ├── iam.tf            # IAM roles and policies
    ├── ec2.tf            # EC2 instance definitions
    ├── s3.tf             # S3 bucket and object uploads
    ├── rds.tf            # PostgreSQL database setup
    ├── outputs.tf        # Output variables
    └── variables.tf      # Input variables
```

---

## Prerequisites

- Terraform CLI
- AWS CLI with credentials configured
- SSH key pair (`.pem`) created for EC2
- Backend zipped: `application-code/app-tier/app.zip`
- Frontend built: `npm run build` → `application-code/web-tier/build/`

---

## Terraform Components

### S3 Uploads (`s3.tf`)

This module provisions an S3 bucket and uploads the application code for both frontend and backend. S3 is used as an intermediary to host deployment artifacts (React build files and backend ZIP archive) that are then fetched by EC2 user data scripts during initialization. `aws_s3_object` resources are used to individually upload each relevant file for precise control and better tracking by Terraform. This design decouples application build from EC2 provisioning and allows rebuilds without modifying instance logic.

Uploads local app files to S3:
- Frontend: entire `build` folder
- Backend: `app.zip` only

These use `aws_s3_object` resources, keyed as:
- `frontend_files` → `s3://.../frontend/...`
- `backend_zip` → `s3://.../backend/app.zip`

### VPC (`vpc.tf`)

A custom Virtual Private Cloud is created to provide isolated networking. It includes:
- A public subnet used by the frontend and backend EC2 instances, which require public IPs to fetch data from S3 and expose services.
- Two private subnets, used by the RDS PostgreSQL instance to ensure it's not publicly accessible.
- An Internet Gateway and route table to allow outbound internet access from public subnet resources.
The network CIDR range is `10.0.0.0/16`, subdivided into appropriate subnets.

Creates:
- 1 public subnet (for frontend/backend EC2)
- 2 private subnets (for RDS)
- Internet gateway, route table and associations

### Security Groups (`security_groups.tf`)

Security groups are virtual firewalls for EC2 and RDS resources:
- `web_sg`: attached to the frontend EC2 instance. Allows HTTP (80), HTTPS (443), and SSH (22) from all IPs (for testing/demo). In production, these should be tightened.
- `app_sg`: attached to the backend EC2. Allows:
  - SSH (22) from anywhere for remote access.
  - App port (3000) only from the frontend's security group (`web_sg`) to restrict exposure.
- `db_sg`: attached to RDS. Allows traffic on port 5432 (PostgreSQL) from the backend only (`app_sg`).
This setup follows a principle of least privilege while enabling full communication between tiers.

- `web_sg`: allows HTTP(80), HTTPS(443), SSH(22) from `0.0.0.0/0`
- `app_sg`: allows:
  - port 22 from `0.0.0.0/0`
  - port 3000 from `web_sg`
- `db_sg`: allows port 5432 from `app_sg` only

### IAM (`iam.tf`)

An EC2 instance profile and IAM role are defined to grant permission for instances to access AWS services without embedding credentials. The role is granted:
- `AmazonS3FullAccess` to pull application files.
- `AmazonRDSFullAccess` to enable optional future use of IAM DB auth or RDS discovery.
- `AmazonEC2FullAccess` and `AmazonVPCFullAccess` to support flexible EC2 operations.
While these are broad policies for simplicity during prototyping, they can be narrowed down for production.

- Role: `aws-transactions-app-ec2-role` with:
  - `AmazonEC2FullAccess`
  - `AmazonS3FullAccess`
  - `AmazonRDSFullAccess`
  - `AmazonVPCFullAccess`
- Instance profile attached to EC2

### EC2 Instances (`ec2.tf`)

Two EC2 instances are provisioned:
- `frontend`: serves the static React app using Nginx. Uses Amazon Linux 2 AMI and installs Nginx via `amazon-linux-extras`.
- `backend`: runs a Node.js app. Uses Node.js 16 due to Amazon Linux 2’s glibc compatibility. The app is zipped and extracted from S3.
Both use `user_data` scripts to bootstrap at launch and use IAM roles to securely fetch artifacts from S3. They are in the public subnet for direct internet access and SSH debugging.

Each EC2 instance runs a **user data script**:

#### Frontend EC2

1. Installs Nginx and AWS CLI
2. Starts Nginx
3. Clears default web directory
4. Downloads React app from S3
5. Restarts Nginx to serve frontend

#### Backend EC2

1. Installs Node.js 16, AWS CLI, and unzip
2. Downloads `app.zip` from S3
3. Unzips backend app
4. Starts `index.js` with `nohup`

Both instances use the IAM role to access S3.

### RDS (`rds.tf`)

A managed PostgreSQL 17 instance is created using `aws_db_instance`. It's placed in private subnets to restrict internet access. Credentials (username and password) are hardcoded in Terraform variables for simplicity but should be securely stored in production.
The RDS instance is only accessible from the backend's security group (`app_sg`), which prevents unauthorized traffic.

- PostgreSQL 17 instance
- Not publicly accessible
- Subnet group configured with private subnets
- Credentials provisioned in Terraform

---

## Deployment Flow

1. Run: `terraform init`
2. Run: `terraform apply`
3. Terraform:
   - Creates S3 bucket and uploads all files
   - Provisions networking
   - Sets up IAM roles
   - Launches EC2 instances which pull code from S3
   - Sets up RDS instance

---

## Operations

### Terraform Commands

- `terraform init`  
  Initialize the Terraform working directory.

- `terraform plan`  
  Show the execution plan and review pending infrastructure changes.

- `terraform apply`  
  Apply the infrastructure changes defined in your Terraform configuration.

- `terraform destroy`  
  Destroy all Terraform-managed infrastructure resources.

- `terraform taint aws_instance.backend`  
  Mark the backend EC2 instance for forced recreation on the next apply.

- `terraform state list`  
  List all resources in the current Terraform state.

- `terraform state show <resource>`  
  Show attributes of a specific resource from the state file.

- `terraform output`  
  Display the output values defined in your configuration.

- `terraform import <resource> <id>`  
  Import existing AWS resources into your Terraform state.

### AWS CLI Commands

- `aws sts get-caller-identity`  
  Display the AWS account and IAM identity currently in use.

- `aws ec2 describe-instances`  
  List all EC2 instances and their metadata.

- `aws rds describe-db-instances`  
  Show details of RDS instances running in your AWS account.

- `aws s3 ls s3://aws-transactions-app-bucket/ --recursive`  
  List all files stored in the S3 bucket.

- `aws iam list-users`  
  View all IAM users in your account.

- `aws ec2 describe-security-groups`  
  List all security groups and their configurations.

### Note: More aws cli commands in the scripts folder.

---

## Notes

- Node.js 18 requires glibc ≥ 2.28. Amazon Linux 2 supports Node.js 16.
- Make sure the `app.zip` is built before apply.
- SSH access only works if the correct SG rule (port 22) is in place and `.pem` is present.

---