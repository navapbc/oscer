# Container images

This application employs the [Docker multi-stage build strategy](https://docs.docker.com/build/building/multi-stage/) to build separate docker images for different purposes:

* `dev`: designed to run tests and support local development on a developer machine
* `release`: optimized for deployment to production or other hosted environments

## Local development: `dev`

You can run the application locally within a container or natively. When running the application in a container locally, use the `dev` image.

Example `docker-compose.yml` snippet:

```yaml
services:
  local-development-app:
    build:
      target: dev
```

## Deployment to hosted environments: `release`

When you deploy this application to hosted environments (e.g. AWS, Azure, GCP), use the `release` image.

Example `docker-compose.yml` snippet:

```yaml
services:
  hosted-app:
    build:
      target: release
```

## Testing `release` locally

It is useful to be able to test the `release` image locally without needing to run a deploy to a hosted environment. For example, this can decrease the iteration time when troubleshooting the production asset precompile pipeline.

In addition to the default Rails environments (i.e. `test`, `development`, `production`), this application includes a `mock-production` Rails environment, which uses "production-like" configuration. Specifically, SSL is disabled in `/<APP_NAME>/config/environments/mock-production.rb`:

```ruby
config.assume_ssl = false
config.force_ssl = false
```

### Instructions

Follow these steps to run the `release` image locally. This process uses `/<APP_NAME>/docker-compose.mock-production.yml`.

#### 1. Change to the application directory

```bash
cd <APP_NAME>
```

#### 2. Initialize the container

```bash
make init-container DOCKER_COMPOSE_ARGS="-f ./docker-compose.mock-production.yml"
```

#### 3. Start the container

```bash
make start-container DOCKER_COMPOSE_ARGS="-f ./docker-compose.mock-production.yml"
```

To stop the container, type `Ctrl-C`.
