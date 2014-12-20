#!/bin/bash
# Starts up MariaDB within the container.

# Stop on error
set -e

DATA_DIR=/data
LOG_DIR=/var/log/mysql
chown -R mysql:adm /var/log/mysql
chown -R mysql:adm /data

if [[ -e /firstrun ]]; then
  source /scripts/first_run.sh
else
  source /scripts/normal_run.sh
fi

pre_start_action

post_start_action

# Start MariaDB
echo "Starting MariaDB..."
exec /usr/bin/mysqld_safe
