## Overview

This is a [Ruby on Rails](https://rubyonrails.org/) application. It includes:

- [U.S. Web Design System (USWDS)](https://designsystem.digital.gov/) for themeable styling and a set of common components
  - Custom USWDS form builder
- Cloud-agnostic design with optional AWS integrations, including
  - Database integration with PostgreSQL using UUIDs (AWS RDS in AWS deployment)
  - Active Storage configuration (AWS S3 in AWS deployment)
  - Action Mailer configuration (AWS SES in AWS deployment)
  - Authentication with [devise](https://github.com/heartcombo/devise) (AWS Cognito in AWS deployment)
- Internationalization (i18n)
- Authorization using [pundit](https://github.com/varvet/pundit)
- Linting and code formatting using [rubocop](https://rubocop.org/)
- Testing using [rspec](https://rspec.info)

## 📂 Directory structure

As a Rails app, much of the directory structure is driven by Rails conventions. We've also included directories for common patterns, such as adapters, form objects and services.

**[Refer to the Software Architecture doc for more detail](../docs/reporting-app/software-architecture.md).**

Below are the primary directories to be aware of when working on the app:

```
├── app
│   ├── adapters         # External services
│   │   └── *_adapter.rb
│   ├── controllers
│   ├── forms            # Form objects
│   │   └── *_form.rb
│   ├── mailers
│   ├── models
│   │   └── concerns
│   ├── services         # Shared cross-model business logic
│   │   └── *_service.rb
│   └── views
├── db
│   ├── migrate
│   └── schema.rb
├── config
│   ├── locales          # i18n
│   └── routes.rb
├── spec                 # Tests
```

## 💻 Getting started with local development

### Prerequisites

- A container runtime (e.g. [Docker](https://www.docker.com/) or [Finch](https://github.com/runfinch/finch))
  - By default, `docker` is used. To change this, set the `CONTAINER_CMD` variable to `finch` (or whatever your container runtime is) in the shell.

**For AWS deployment (optional):**
- An AWS account with a Cognito User Pool and App Client configured
  - The application can be configured for authentication using AWS Cognito, or other authentication providers

### 💾 Setup

You can run the app within a container or natively. Each requires slightly different setup steps.

#### Environment variables

In either case, first generate a `.env` file:

1. Run `make .env` to create a `.env` file based on shared template.
1. Variables marked with `<FILL ME IN>` need to be manually set, and otherwise edit to your needs.

#### Running in a container

1. `make init-container`

#### Running natively

Prerequisites:

- Ruby version matching [`.ruby-version`](./.ruby-version)
- [Node LTS](https://nodejs.org/en)
- (Optional but recommended): [rbenv](https://github.com/rbenv/rbenv)

Steps:

1. `make init-native`

### 🛠️ Development

#### Running the app

Once you've completed the setup steps above, you can run the site natively or within a container runtime.

To run within a container:

1. `make start-container`
1. Then visit http://localhost:3000

To run natively:

1. `make start-native`
1. Then visit http://localhost:3000

#### Local Authentication

The .env example sets local authentication to mock, meaning you can log in using any email and password. To use Cognito, set `AUTH_ADAPTER` in your .env like so:
```
AUTH_ADAPTER=cognito
```

You will need to set the other cognito variables as well; setting `AUTH_ADAPTER` alone will merely set the auth flow to cognito, not enable cognito log in.

#### IDE tips

<details>
<summary>VS Code</summary>

##### Recommended extensions

- [Ruby LSP](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp)
- [Simple ERB](https://marketplace.visualstudio.com/items?itemName=vortizhe.simple-ruby-erb), for tag autocomplete and snippets

</details>

## 📇 Additional reading

Beyond this README, you should also refer to the [`docs/reporting-app` directory](../docs/reporting-app) for more detailed info. Some highlights:

- [Technical foundation](../docs/reporting-app/technical-foundation.md)
- [Software architecture](../docs/reporting-app/software-architecture.md)
- [Authentication & Authorization](../docs/reporting-app/auth.md)
- [Internationalization (i18n)](../docs/reporting-app/internationalization.md)
- [Container images](../docs/reporting-app/container-images.md)
