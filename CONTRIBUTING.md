# Contributing to Community Engagement Medicaid

Thank you for your interest in contributing to the Community Engagement Medicaid platform! This project helps state Medicaid agencies manage community engagement requirements, and we welcome contributions from developers, designers, policy experts, and community members. This document outlines how members of the community should approach the contribution process.

## Community

We are committed to providing a welcoming and inclusive environment for all contributors. All contributors are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Bugs and issues

Bug reports are welcome, as they make OSCER better for everyone who uses it. Create a GitHub issue using the bug template to make sure it contains the neccessary information for us to triage the issue. Prior to filing an issue, please search the existing issues to make sure it is not a duplicate.

If the issue is related to security, please email us directly at strata@navapbc.com

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git installed and configured
- Docker or Finch (container runtime)
- Basic familiarity with Ruby on Rails (for backend contributions)
- Understanding of AWS services (for infrastructure contributions)
- Familiarity with U.S. Web Design System (for frontend contributions)

## Development Setup

### Choose Your Setup Method

We offer two ways to run the application locally:

#### **Docker Setup**

- **Pros**: No need to install Ruby, PostgreSQL, or manage dependencies
- **Cons**: Requires Docker Desktop
- **Best for**: New contributors, quick setup, consistent environments

#### **Native Setup**

- **Pros**: Faster performance, familiar development environment
- **Cons**: Need to install and manage Ruby, PostgreSQL, and dependencies
- **Best for**: Experienced Rails developers, performance-sensitive work

---

## Docker Setup (Recommended)

### What You'll Need

Before we start, make sure you have:

- **Docker** installed and running ([Download here](https://www.docker.com/products/docker-desktop/))
- **Git** to clone the repository
- A **text editor** or IDE of your choice
- About **10-15 minutes** for the initial setup

> **New to Docker?** Don't worry! Docker will handle all the complex environment setup for you. You won't need to install Ruby, PostgreSQL, or manage dependencies manually.

### Quick Start (5 Steps)

#### Step 1: Clone the Repository

First, get a copy of the code on your local machine:

```bash
git clone https://github.com/navapbc/oscer.git
cd oscer
```

#### Step 2: Set Up Your Environment

Navigate to the reporting app directory and create your local environment file:

```bash
cd reporting-app
cp local.env.example .env
```

> **What's this doing?** The `.env` file contains configuration settings for your local development environment. The example file has sensible defaults that work out of the box, including mock authentication so you don't need real AWS credentials to get started.

#### Step 3: Check Docker is Running

Make sure Docker is running, then verify it's working:

```bash
docker --version
```

You should see something like `Docker version 26.1.4, build 5650f9b102`. If you get an error, make sure Docker is started.

#### Step 4: Start the Application

This is where the magic happens! Run this single command to build and start everything:

```bash
docker-compose up --build -d
```

> **What's happening?** Docker is:
>
> - Building a container with Ruby, Rails, and all dependencies
> - Starting a PostgreSQL database
> - Setting up the development environment
> - Running everything in the background (`-d` flag)

This will take a few minutes the first time as Docker downloads and builds everything.

#### Step 5: Set Up the Database

Run the database migrations to create the necessary tables:

```bash
docker-compose exec reporting-app bin/rails db:migrate
```

#### You're Done!

Open your browser and go to **http://localhost:3000**

You should see the Community Engagement Medicaid reporting app running locally!

## Native Setup (Alternative)

If you prefer to run the application natively without Docker, follow these steps. This approach gives you more control and potentially better performance, but requires managing dependencies yourself.

### What You'll Need

- **Ruby 3.4.6** (check `.ruby-version` file for exact version)
- **PostgreSQL 14+** running locally
- **Node.js 22+** and **npm** for asset compilation
- **Git** to clone the repository
- **Bundler** gem for Ruby dependency management

### Installation Steps

#### Step 1: Install System Dependencies

##### On macOS (using Homebrew):

```bash
# Install Ruby version manager (if you don't have one)
brew install rbenv

# Install the required Ruby version
rbenv install 3.4.6
rbenv global 3.4.6

# Install PostgreSQL
brew install postgresql@14
brew services start postgresql@14

# Install Node.js
brew install node@22
```

##### On Ubuntu/Debian:

```bash
# Install Ruby dependencies
sudo apt update
sudo apt install -y build-essential libssl-dev libreadline-dev zlib1g-dev libpq-dev

# Install rbenv for Ruby version management
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby
rbenv install 3.4.6
rbenv global 3.4.6

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

#### Step 2: Clone and Setup the Repository

```bash
git clone https://github.com/navapbc/oscer.git
cd oscer/reporting-app
```

#### Step 3: Install Ruby Dependencies

```bash
# Install bundler if you don't have it
gem install bundler

# Install application gems
bundle install
```

#### Step 4: Install JavaScript Dependencies

```bash
npm install
```

#### Step 5: Set Up Your Environment

```bash
cp local.env.example .env
```

Edit the `.env` file and update the database settings:

```bash
# Change these lines in your .env file:
DB_HOST=localhost
DB_NAME=community_engagement_medicaid_development
DB_USER=your_postgres_username
DB_PASSWORD=your_postgres_password
DB_PORT=5432
```

#### Step 6: Set Up the Database

```bash
# Create the database user (if needed)
createuser -s app  # or use your preferred PostgreSQL user

# Create and set up the database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Optional: load sample data
```

#### Step 7: Start the Application

```bash
# Start the development server
bin/dev
```

This will start:

- The Rails server on http://localhost:3000
- The CSS build process (watching for changes)

## Development Workflow

### 1. Choose an Issue

- Browse [open issues](https://github.com/navapbc/oscer/issues)
- Look for issues labeled `good first issue` for newcomers
- Comment on the issue to indicate you're working on it
- Ask questions if you need clarification

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 3. Make Changes

- Follow our coding standards (see below)
- Write tests for new functionality
- Update documentation as needed
- Ensure accessibility compliance
- Test your changes thoroughly

### 4. Commit Changes

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
git commit -m "feat: add new activity reporting feature"
git commit -m "fix: resolve authentication redirect issue"
git commit -m "docs: update API documentation"
```

### 5. Push and Create Pull Request

```bash
git push origin your-branch-name
```

Then create a pull request on GitHub with:

- Clear title and description
- Reference to related issues
- Screenshots for UI changes
- Test results and coverage

## Code Review Process

### Submitting for Review

- Ensure all tests pass
- Update documentation
- Self-review your changes
- Request review from appropriate team members

### Review Criteria

Reviewers will check for:

- **Functionality**: Does the code work as intended?
- **Security**: Are there any security vulnerabilities?
- **Performance**: Will this impact system performance?
- **Accessibility**: Does this maintain accessibility standards?
- **Maintainability**: Is the code readable and maintainable?
- **Testing**: Are there adequate tests?

### Addressing Feedback

- Respond promptly to review comments
- Make requested changes or discuss alternatives
- Update tests and documentation as needed
- Re-request review after making changes

Thank you for contributing to the Community Engagement Medicaid platform! Your contributions help improve healthcare access and administration for millions of Americans.
