# Use the official Playwright image as a base
FROM mcr.microsoft.com/playwright:v1.59.1-noble

# Skip apt unless you need extra packages; `apt-get update` flakes when Ubuntu mirrors are mid-sync.

# Set the working directory to the root of the project inside the Docker container
WORKDIR /e2e

# Setup npm install layer that can be cached
COPY e2e/package.json e2e/package-lock.json ./

# install deps
RUN npm ci

# Copy entire e2e folder over
COPY e2e /e2e

CMD ["npm", "test", "--"]
