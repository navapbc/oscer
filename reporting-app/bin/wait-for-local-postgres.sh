#!/bin/bash
# wait-for-local-postgres

set -e

# Color formatting
RED='\033[0;31m'
NO_COLOR='\033[0m'

MAX_WAIT_TIME=30 # seconds
wait_time=0

# If you run your DB on a port other than 5432, you'll need to specify
# the port's environment variable you want to use for this to work properly
# "export DB_PORT=<your_port_number>"
DB_PORT="${DB_PORT:=5432}"
DB_NAME="${DB_NAME:=${PGDATABASE}}"

# Support other container tools like `finch`
DOCKER_CMD="${CONTAINER_CMD:=docker}"
DOCKER_DB_SERVICE_NAME="${DOCKER_DB_SERVICE_NAME:=database}"

# If pg_isready isn't available, the loop would just keep going until it fails
# instead just do a sleep and tell the user to install it. Not as good, but shouldn't
# block developers who are just getting started this way
if ! command -v pg_isready &>/dev/null; then
  echo -e "${RED}Warning:${NO_COLOR} Postgres has not been installed locally, cannot use pg_isready to check if DB is available."
  echo ""
  echo "Please install postgresql:"
  echo "   MacOS: 'brew install postgresql'"
  echo "   Linux: 'sudo apt install postgresql-client-14 postgresql-client-common'"
  echo ""
  echo "Sleeping for 5 seconds instead"
  sleep 5
  exit 0
fi

# Use pg_isready to wait for the DB to be ready to accept connections
# We check every 3 seconds and consider it failed if it gets to 30+
# https://www.postgresql.org/docs/current/app-pg-isready.html
until pg_isready -h localhost -p "${DB_PORT}" -d "${DB_NAME}" -q; do
  echo "waiting on Postgres DB to initialize..."
  sleep 3

  wait_time=$(($wait_time + 3))
  if [ $wait_time -gt $MAX_WAIT_TIME ]; then
    echo -e "${RED}ERROR: Database appears to not be starting up, running \"${DOCKER_CMD} logs ${DOCKER_DB_SERVICE_NAME}\" to troubleshoot${NO_COLOR}"
    ${DOCKER_CMD} logs "${DOCKER_DB_SERVICE_NAME}"
    exit 1
  fi
done

echo "Postgres DB is ready after ~${wait_time} seconds"
