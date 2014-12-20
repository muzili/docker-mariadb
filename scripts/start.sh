#!/bin/bash
# Starts up MariaDB within the container.

# Stop on error
set -e

DATA_DIR=/data

if [[ -e /firstrun ]]; then
  source /scripts/first_run.sh
else
  source /scripts/normal_run.sh
fi

# Start MariaDB
echo "Starting MariaDB..."
exec /usr/bin/mysqld_safe
