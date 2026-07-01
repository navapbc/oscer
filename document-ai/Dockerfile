# syntax = docker/dockerfile:1

# renovate: datasource=docker depName=ghcr.io/navapbc/strata-service-document-ai
ARG UPSTREAM_VERSION=0.5.1
FROM --platform=linux/amd64 ghcr.io/navapbc/strata-service-document-ai:${UPSTREAM_VERSION}

# Copy project-specific schema definitions.
# SCHEMAS_MODE=replace means only schemas defined here are registered;
COPY schema.json /app/schemas/schema.json

ENV SCHEMAS_CONFIG_FILE=/app/schemas/schema.json
ENV SCHEMAS_MODE=replace
