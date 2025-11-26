# Getting Started  

This document describes how to set up OSCER locally in your own environment. 

## Prerequisites

- Docker or Finch (container runtime)
- Ruby 3.x (for native development)
- Node.js LTS (for native development)

## Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/navapbc/oscer.git
   cd oscer
   ```

2. **Set up environment variables**

   ```bash
   cd reporting-app
   make .env
   # Edit .env file with your configuration
   ```

3. **Run with Docker (Recommended)**

   ```bash
   make init-container
   make start-container
   ```

   Or **run natively**:

   ```bash
   make init-native
   make start-native
   ```

4. **Access the application**
   - Open http://localhost:3000 in your browser
   - Default authentication is set to mock mode for development

## Cloud Deployment Options

OSCER is designed to be cloud-agnostic. We provide infrastructure templates for different cloud providers:

**Prerequisites for cloud deployment (choose one):**

- **AWS**: AWS account with appropriate permissions (uses our [AWS template](https://github.com/navapbc/template-infra))
- **Azure**: Azure account with appropriate permissions (uses our [Azure template](https://github.com/navapbc/template-infra-azure))
- **Other CSPs**: Account with your chosen cloud provider (BYO infrastructure)

**AWS Deployment:**

- **Reference implementation** using our [AWS infrastructure template](https://github.com/navapbc/template-infra)
- See our [AWS implementation as a reference.](docs/infra/)

**Azure Deployment:**

- **Azure infrastructure template** available at [navapbc/template-infra-azure](https://github.com/navapbc/template-infra-azure)
- Provides equivalent functionality using Azure services

**Other Cloud Providers (GCP, etc.):**

- **Bring Your Own (BYO)** infrastructure approach
- The application architecture remains the same
- You'll need to create infrastructure code for your chosen provider's services

## Exploring the Application

After starting the application, you can explore OSCER's different interfaces and workflows:

### Demo Overview
**URL:** http://localhost:3000/demo  
Start here to see entrypoints to the different experiences in OSCER and understand the application's structure.

### Creating a Certification Request
**URL:** http://localhost:3000/demo/certifications/new

A certification request is the case that a member responds to. In production, these are created in bulk through batch processes or API, but for testing you can create them manually.

**To experience the full workflow:**
1. Create a certification request using an email address you can access
2. Configure different scenarios (lookback months, exemption triggers, etc.)
3. Test automated exemptions by indicating pregnancy or other qualifying conditions
4. Submit the request

**Note:** You can reuse the same email address for multiple certification requests—the system will automatically reset for that email.

### Member Dashboard (or Client View)
**URL:** http://localhost:3000/dashboard

This is the member-facing interface where clients respond to their certification requests. Follow the instructions on the dashboard to create an activity report or exemption request. Once submitted, you can navigate to the staff portal to view the submitted request. You must complete a certification request (see above) before you'll see any data in this view.

### Staff Portal
**URL:** http://localhost:3000/staff

This is the administrative interface where staff can review and process member certification responses.

