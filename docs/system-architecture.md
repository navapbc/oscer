# System Architecture

OSCER is designed to be cloud-agnostic with infrastructure templates for different cloud providers. This diagram shows our AWS reference implementation. [🔒 Make a copy of this Lucid template for your own application](https://lucid.app/lucidchart/8851888e-1292-4228-8fef-60a61c6b57e7/edit).

**Available Templates:**
- **AWS**: [Reference implementation](https://github.com/navapbc/template-infra) (shown below)
- **Azure**: [Infrastructure template](https://github.com/navapbc/template-infra-azure)
- **Other CSPs**: Bring Your Own (BYO) infrastructure

![System architecture](https://lucid.app/publicSegments/view/e5a36152-200d-4d95-888e-4cdbdab80d1b/image.png)

## AWS Implementation Components

* **Access Logs** — Amazon S3 bucket storing the application service's access logs.
* **Alarms SNS Topic** — SNS topic that notifies the incident management service when an alarm triggers.
* **Application Load Balancer** — Amazon application load balancer.
* **Aurora PostgreSQL Database** — Amazon Aurora Serverless PostgreSQL database used by the application.
* **Build Repository ECR Registry** — Amazon ECR registry that acts as the build repository of application container images.
* **CloudWatch Alarms** — Amazon CloudWatch Alarms that trigger on errors and latency.
* **CloudWatch Logs** — Stores application and infrastructure logs.
* **Cognito** — Amazon Cognito handles authentication and user management.
* **Database Role Manager** — AWS Lambda serverless function that provisions the database roles needed by the application.
* **GitHub** — Source code repository. Also responsible for Continuous Integration (CI) and Continuous Delivery (CD) workflows. GitHub Actions builds and deploys releases to an Amazon ECR registry that stores Docker container images for the application service.
* **Incident Management Service** — Incident management service (e.g. PagerDuty or Splunk On-Call) for managing on-call schedules and paging engineers for urgent production issues.
* **NAT Gateway** — Enables outbound internet access for resources in private subnets.
* **Secrets Manager** — Securely stores and retrieves sensitive information such as database credentials.
* **Service** — Amazon ECS service running the application.
* **SES** — Amazon Simple Email Service (SES) used for sending email notifications.
* **Terraform Backend Bucket** — Amazon S3 bucket used to store terraform state files.
* **VPC Endpoints** — VPC endpoints are used by the Database Role Manager to access Amazon Services without traffic leaving the VPC.
* **VPC Network** — Amazon VPC network.
