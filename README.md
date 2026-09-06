
# ☁️ PulseWatch Infrastructure

### AWS Infrastructure & Deployment Automation

This repository contains the AWS infrastructure configuration and deployment scripts for **PulseWatch**, a serverless website and API uptime monitoring platform.

The infrastructure is managed using **AWS CLI-based shell scripts**, allowing the complete AWS environment to be created, configured, tested, and removed in a structured way.

---

## 🎥 Project Demo

[Watch the PulseWatch Demo on YouTube](https://www.youtube.com/watch?v=lCfbnnLQq3o)

## 🎨 Frontend Repository

[PulseWatch Frontend](https://github.com/mahi-8758/pulsewatch-frontend)

## ⚙️ Backend Repository

[PulseWatch Backend](https://github.com/mahi-8758/pulsewatch-backend)

---

## 🏗️ AWS Architecture

PulseWatch uses a serverless, event-driven AWS architecture.

```text
                              ┌─────────────────┐
                              │      Users      │
                              │   Web Browser   │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   Amazon S3     │
                              │ React Frontend  │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │ Amazon Cognito  │
                              │ Authentication  │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  API Gateway    │
                              │    REST API     │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   API Lambda    │
                              │ pulsewatch-api  │
                              └────────┬────────┘
                                       │
                                       ▼
                        ┌──────────────────────────┐
                        │      Amazon DynamoDB     │
                        │                          │
                        │   MonitorTargets         │
                        │   CheckResults           │
                        │   Incidents              │
                        └──────────────────────────┘


                    Automatic Monitoring
                              │
                              ▼
                     ┌───────────────────┐
                     │ Amazon EventBridge│
                     │    Every 5 min    │
                     └─────────┬─────────┘
                               │
                               ▼
                     ┌───────────────────┐
                     │   Checker Lambda  │
                     │ pulsewatch-checker│
                     └─────────┬─────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
             ┌─────────────┐       ┌─────────────┐
             │  DynamoDB   │       │ Amazon SNS  │
             │ Results &   │       │Email Alerts │
             │ Incidents   │       └─────────────┘
             └─────────────┘
```

---

## ☁️ AWS Resources

| Resource | Purpose |
|---|---|
| **Amazon Cognito** | User authentication |
| **Amazon DynamoDB** | Application data storage |
| **AWS IAM** | Lambda permissions and access control |
| **AWS Lambda** | Backend API and monitoring |
| **Amazon EventBridge** | Scheduled monitoring |
| **Amazon API Gateway** | REST API |
| **Amazon S3** | Frontend hosting |
| **Amazon SNS** | Email notifications |
| **Amazon CloudWatch** | Monitoring and alarms |

---

## 📁 Project Structure

```text
pulsewatch-infrastructure/
│
├── config/
│   └── variables.sh
│
├── scripts/
│   ├── 01-cognito.sh
│   ├── 02-dynamodb.sh
│   ├── 03-sns.sh
│   ├── 04-iam.sh
│   ├── 05-lambda.sh
│   ├── 06-eventbridge.sh
│   ├── 07-api-gateway.sh
│   ├── 08-s3.sh
│   ├── 09-cloudwatch.sh
│   ├── 10-test.sh
│   └── 11-teardown.sh
│
└── README.md
```

---

## ⚙️ Configuration

The project uses a central configuration file:

```bash
config/variables.sh
```

Example:

```bash
export REGION=ap-south-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export PROJECT=pulsewatch
```

This allows the deployment scripts to use the same AWS region, account, and project configuration.

---

## 🚀 Deployment

### Prerequisites

Make sure the following are installed and configured:

- AWS CLI
- Git
- Bash / Git Bash
- Node.js and npm
- An AWS account with appropriate permissions

Verify AWS CLI:

```bash
aws --version
```

Verify your AWS account:

```bash
aws sts get-caller-identity
```

---

## 📦 Deployment Steps

Run the scripts in order.

### 1. Cognito

Creates the Cognito User Pool and application client.

```bash
bash scripts/01-cognito.sh
```

### 2. DynamoDB

Creates the monitoring database tables.

```bash
bash scripts/02-dynamodb.sh
```

### 3. SNS

Creates the SNS topic and email notification configuration.

```bash
bash scripts/03-sns.sh
```

### 4. IAM

Creates the Lambda execution role and required permissions.

```bash
bash scripts/04-iam.sh
```

### 5. Lambda

Creates and deploys the API and checker Lambda functions.

```bash
bash scripts/05-lambda.sh
```

### 6. EventBridge

Creates the scheduled monitoring rule.

```bash
bash scripts/06-eventbridge.sh
```

### 7. API Gateway

Creates the REST API and connects it to the API Lambda.

```bash
bash scripts/07-api-gateway.sh
```

### 8. S3

Creates/configures the frontend hosting bucket.

```bash
bash scripts/08-s3.sh
```

### 9. CloudWatch

Creates monitoring and error alarms.

```bash
bash scripts/09-cloudwatch.sh
```

### 10. Test

Runs infrastructure and application checks.

```bash
bash scripts/10-test.sh
```

---

## 🔄 Deployment Flow

```text
01 Cognito
     │
     ▼
02 DynamoDB
     │
     ▼
03 SNS
     │
     ▼
04 IAM
     │
     ▼
05 Lambda
     │
     ▼
06 EventBridge
     │
     ▼
07 API Gateway
     │
     ▼
08 S3
     │
     ▼
09 CloudWatch
     │
     ▼
10 Test
```

---

## ⏱️ Scheduled Monitoring

Amazon EventBridge triggers the checker Lambda every **5 minutes**.

```text
EventBridge
     │
     │ rate(5 minutes)
     ▼
pulsewatch-checker
     │
     ├── Check monitored URLs
     ├── Measure response time
     ├── Store results
     ├── Detect incidents
     └── Send notifications
```

---

## 🔐 IAM & Security

The infrastructure creates an IAM role for Lambda execution.

The role provides only the AWS permissions required by the application, including access to:

- DynamoDB
- Amazon SNS
- CloudWatch Logs
- Required Lambda operations

Authentication is handled separately through Amazon Cognito.

> ⚠️ Never store AWS access keys, secret keys, passwords, tokens, or other sensitive credentials in this repository.

---

## 📊 CloudWatch Monitoring

Amazon CloudWatch is used to monitor the health of the backend infrastructure.

The project includes a Lambda error alarm:

```text
pulsewatch-checker-errors
```

This helps identify failures in the scheduled monitoring process.

---

## 🧪 Infrastructure Testing

The test script verifies important AWS resources and application components.

Run:

```bash
bash scripts/10-test.sh
```

The testing process can be used to verify:

- Cognito configuration
- DynamoDB tables
- SNS topic
- IAM role
- Lambda functions
- EventBridge rule
- API Gateway
- S3 bucket
- CloudWatch alarm

---

## 🗑️ Teardown

To remove the PulseWatch AWS infrastructure:

```bash
bash scripts/11-teardown.sh
```

> ⚠️ **Warning:** The teardown script removes AWS resources. Make sure you understand what will be deleted before running it.

---

## 🌎 AWS Region

The project is currently configured for:

```text
ap-south-1
```

**AWS Region:** Asia Pacific (Mumbai)

---

## 🧩 Infrastructure Components

### Amazon Cognito

Provides:

- User registration
- Login
- Email verification
- Authentication tokens

### Amazon DynamoDB

Stores:

- Monitor targets
- Check results
- Incidents

### AWS Lambda

Two Lambda functions are used:

```text
pulsewatch-api
pulsewatch-checker
```

### Amazon EventBridge

Triggers the checker Lambda every 5 minutes.

### Amazon API Gateway

Provides REST endpoints for the frontend.

### Amazon SNS

Sends email notifications for monitoring state changes.

### Amazon S3

Hosts the production React frontend.

### Amazon CloudWatch

Provides backend monitoring and error alarms.

---

## 🔗 Application Flow

```text
                    USER
                      │
                      ▼
              React Frontend
                      │
                      ▼
              Amazon Cognito
                      │
                   JWT Token
                      │
                      ▼
                API Gateway
                      │
                      ▼
                API Lambda
                      │
                      ▼
                  DynamoDB


        Automatic Monitoring
                │
                ▼
          EventBridge
                │
          Every 5 Minutes
                │
                ▼
        Checker Lambda
                │
        ┌───────┴────────┐
        ▼                ▼
    DynamoDB           SNS
                         │
                         ▼
                   Email Alert
```

---

## 🛠️ Infrastructure Approach

PulseWatch infrastructure is organized as **numbered shell scripts**, where each script is responsible for a specific AWS service or deployment stage.

This approach provides:

- Simple deployment steps
- Clear separation of AWS resources
- Easy troubleshooting
- Repeatable setup
- Easy teardown
- Beginner-friendly AWS infrastructure management

---

## 🎯 Project Goals

This infrastructure project demonstrates practical experience with:

- AWS cloud architecture
- Serverless application deployment
- AWS CLI automation
- IAM permissions
- Event-driven architecture
- Infrastructure organization
- Lambda deployment
- API Gateway configuration
- DynamoDB provisioning
- Cognito configuration
- SNS notifications
- CloudWatch monitoring

---

## 🚀 Future Improvements

- ☁️ CloudFront + HTTPS deployment
- 🤖 CI/CD pipeline
- 🏗️ Infrastructure as Code using Terraform
- 🌍 Multi-region deployment
- 📊 Advanced CloudWatch dashboards
- 🔄 Automated infrastructure testing
- 🔐 Further IAM permission hardening

---

## 📚 Related Repositories

| Repository | Description |
|---|---|
| [Frontend](https://github.com/mahi-8758/pulsewatch-frontend) | React + Vite frontend |
| [Backend](https://github.com/mahi-8758/pulsewatch-backend) | AWS Lambda backend |
| [Infrastructure](https://github.com/mahi-8758/pulsewatch-infrastructure) | AWS infrastructure and deployment scripts |

---

## 👨‍💻 Author

**Mahi Kumar**

GitHub: [@mahi-8758](https://github.com/mahi-8758)

---

## ⭐ Project

If you find PulseWatch useful, consider giving the project a ⭐ on GitHub.

---
