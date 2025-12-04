<h1 align="center">
  Open Source Community Engagement Reporting (OSCER)
</h1>
<p align="center">
  <p align="center"><b>A comprehensive platform for managing Medicaid community engagement requirements</b>: built to help states implement and administer work requirements and exemption processes in compliance with federal regulations.</p>
</p>
<p align="center">
  <p align="center">Built with <a href="https://github.com/navapbc/strata">Nava Strata</a></p>
</p>

<h4 align="center">
  <a href="https://github.com/navapbc/oscer/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-apache_2.0-red" alt="OSCER is released under the Apache 2.0 license" >
  </a>
  <a href="https://github.com/navapbc/oscer/blob/main/CONTRIBUTING.md">
    <img src="https://img.shields.io/badge/PRs-Welcome-brightgreen" alt="PRs welcome!" />
  </a>
  <a href="https://github.com/navapbc/oscer/commits">
    <img src="https://img.shields.io/github/commit-activity/m/navapbc/oscer" alt="git commit activity" />
  </a>
  <a href="https://github.com/navapbc/oscer/releases">
    <img src="https://img.shields.io/github/downloads/navapbc/oscer/total" alt="GitHub Downloads (all assets, all releases)" />
  </a>
</h4>

<img src="/docs/assets/OSCER_github_repo.png" width="100%" alt="Dashboard" />

## Introduction

Nava’s Open Source Community Engagement Reporting tool (OSCER) is intended to be an open-source, self-contained application that plugs into existing Medicaid systems to handle end-to-end reporting to meet H.R.1 community engagement requirements (eligibility checks, reporting, verification) without locking into proprietary platforms or brittle customizations.

- **Open by default** - transparent code and approach
- **Sidecar architecture** - integrates with existing cloud systems with minimal and well-defined touchpoints
- **State-owned** - runs in state-hosted cloud environments and states retain full ownership of the deployment, configuration, and data

### Why OSCER

State Medicaid programs face real constraints:

- **Proprietary COTS platforms**: Slow to change, rigid licensing and customization
- **Closed custom builds**: Every update becomes a costly change order, code often isn’t yours
- **Vendor lock-in**: limited code access, slower security review, no reusable improvements

OSCER is approaching this differently than other vendors with transparent code, modular integration, and an architecture designed for frequent policy change.

## Architecture

The platform consists of:

- **Reporting Application**: Ruby on Rails web application with modern UI using U.S. Web Design System (USWDS)
- **Cloud Infrastructure**: Cloud-agnostic design with Infrastructure as Code (current demo deployed on AWS)
- **Security & Compliance**: Built with security best practices and compliance requirements in mind

### Key Technologies

- **Backend**: Ruby on Rails 7.2, PostgreSQL
- **Frontend**: USWDS, ERB templates, JavaScript
- **Infrastructure**: Terraform (AWS implementation provided as reference)
- **Testing**: RSpec, Playwright (E2E)
- **CI/CD**: GitHub Actions

## Getting Started  

If you are interested in:  
- Getting OSCER set up locally, see instructions below or go to our [Getting Started guide]([docs/how-to-guides/getting-started](https://github.com/navapbc/oscer/blob/main/docs/how-to-guides/getting-started.md)).

### Prerequisites

- Docker or Finch (container runtime)
- Ruby 3.x (for native development)
- Node.js LTS (for native development)

### Installation

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

### Cloud Deployment Options

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

## Documentation

- **[Getting Started](docs/how-to-guides/)** - Instructuctions for getting started
- **[System Architecture](docs/system-architecture.md)** - High-level system overview
- **[Reporting App Documentation](docs/reporting-app/)** - Detailed application documentation
- **[Infrastructure Guide](docs/infra/)** - Deployment and infrastructure management
- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute to the project
- **[Security Policy](SECURITY.md)** - Security practices and reporting

## OSCER Public Demos  

See our previous demos and walkthroughs on our [YouTube playlist](https://www.youtube.com/playlist?list=PLLbut-Ow2h4nbfYS4Is8EGBVWKbvB9MWV).


## Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code of conduct
- Development workflow
- Pull request process
- Coding standards

## License

This repo available under the [Apache 2.0 License](https://github.com/navapbc/oscer/blob/main/LICENSE)

If you are interested in an integration for your state managed by Nava, take a look at [our website](https://navapbc.com/).

## Support

- **Documentation**: Check our [comprehensive documentation](docs/)
- **Issues**: Report bugs and request features via [GitHub Issues](https://github.com/navapbc/oscer/issues)
- **Security**: Report security vulnerabilities via our [Security Policy](SECURITY.md)

For more information about Medicaid community engagement requirements and this platform, please visit our [documentation](docs/) or contact the development team.
