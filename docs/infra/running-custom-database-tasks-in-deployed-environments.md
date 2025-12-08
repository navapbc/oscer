# Running Custom Database Tasks in Deployed Environments

This guide explains how to run custom CLI commands (like Rails console commands) against a deployed application in AWS.

## Overview

The `./bin/run-command` script allows you to execute arbitrary commands in your deployed application container. It:

1. Uses Terraform to get the necessary AWS resources (cluster, task definition, log group, etc.)
2. Launches an ECS task with your command
3. Streams the task's logs to your terminal
4. Returns the task's exit code

## Prerequisites

- AWS credentials configured (with appropriate permissions)
- Terraform initialized for the target environment
- The application deployed to AWS

## Basic Steps

### 1. Set Required Variables

```bash
app_name="reporting-app"              # Name of the application
environment="dev"                      # Environment name (dev, sandbox, etc.)
```

### 2. Prepare Your Command

The command must be formatted as a JSON array. Here are some common examples:

**Rails Runner** - Execute arbitrary Ruby code:
```bash
command='["./bin/rails", "runner", "User.find_by(email: \"person@navapbc.com\").update(full_name: \"Billy Bob\", region: \"East\")"]'
```

**Database Maintenance** - Run database migrations:
```bash
command='["db-migrate"]'
```

**Custom Script** - Run a custom script:
```bash
command='["./bin/my-custom-script", "arg1", "arg2"]'
```

### 3. Initialize Terraform

```bash
./bin/terraform-init "infra/${app_name}/service" "${environment}"
```

This ensures Terraform is initialized and selects the correct workspace for your environment.

### 4. Retrieve Infrastructure Variables

After terraform is initialized, get the migrator IAM role and database user:

```bash
db_migrator_user=$(terraform -chdir="infra/${app_name}/service" output -raw migrator_username)
migrator_role_arn=$(terraform -chdir="infra/${app_name}/service" output -raw migrator_role_arn)
```

### 5. Set Environment Variables

If your command needs environment variables, format them as a JSON array:

```bash
environment_variables=$(cat << EOF
[{ "name" : "DB_USER", "value" : "${db_migrator_user}" }]
EOF
)
```

### 6. Execute the Command

Run the command with the required parameters:

```bash
./bin/run-command \
  --task-role-arn "${migrator_role_arn}" \
  --environment-variables "${environment_variables}" \
  "${app_name}" \
  "${environment}" \
  "${command}"
```

## Complete Example

Here's a complete script to update a user's information:

```bash
#!/bin/bash

app_name="reporting-app"
environment="dev"
command='["./bin/rails", "runner", "User.find_by(email: \"person@navapbc.com\").update(full_name: \"Billy Bob\", region: \"East\")"]'

# Initialize terraform
./bin/terraform-init "infra/${app_name}/service" "${environment}"

# Get infrastructure variables
db_migrator_user=$(terraform -chdir="infra/${app_name}/service" output -raw migrator_username)
migrator_role_arn=$(terraform -chdir="infra/${app_name}/service" output -raw migrator_role_arn)

# Set environment variables
environment_variables=$(cat << EOF
[{ "name" : "DB_USER", "value" : "${db_migrator_user}" }]
EOF
)

# Run the command
./bin/run-command \
  --task-role-arn "${migrator_role_arn}" \
  --environment-variables "${environment_variables}" \
  "${app_name}" \
  "${environment}" \
  "${command}"
```
