# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
# renovate: datasource=docker depName=registry.docker.com/library/ruby
ARG RUBY_VERSION=3.4.6


##########################################################################################
# BASE: Shared base docker image
##########################################################################################
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    TMPDIR="/rails/tmp"

# In production, this should be the only filesystem location with writes
VOLUME /rails/tmp

##########################################################################################
# BUILD: Throw-away build stage
##########################################################################################
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
        build-essential \
        git \
        libpq-dev \
        libvips \
        libyaml-dev \
        pkg-config \
        npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install npm packages
COPY package.json package-lock.json ./

# Install npm packages
RUN npm install


##########################################################################################
# DEV: Used for development and test
##########################################################################################
FROM build AS dev

ENV RAILS_ENV="development"

# Install packages needed for development
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
        postgresql-client \
        graphviz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install application gems for development
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without production && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install system-wide gems for development
# This version must match Gemfile.lock. Otherwise, `rdbg` will fail.
RUN gem install debug -v 1.10.0

# Copy application code
COPY . .

# During local development, app is configured to write to more places
VOLUME /rails/log
VOLUME /rails/storage

CMD ["./bin/dev"]


##########################################################################################
# RELEASE-BUILD: Throw-away build stage for RELEASE
##########################################################################################
FROM build AS release-build

# Install application gems for production
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development test && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


##########################################################################################
# RELEASE: Used for production
##########################################################################################
FROM base AS release

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

# Install packages needed for deployment
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        libvips \
        libyaml-dev \
        postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install custom db migrate script
COPY bin/db-migrate /usr/bin/

# Copy built artifacts: gems, application
COPY --from=release-build /usr/local/bundle /usr/local/bundle
COPY --from=release-build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

CMD ["./bin/rails", "server"]
