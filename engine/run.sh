#!/usr/bin/env bash

#set -x -e
#if [ -z "$OMNIDB_DATABASE" ] ; then
# echo "Environment variables OMNIDB_DATABASE must be set"
# exit 1
#fi
OPTIONS="--echo-all -v ON_ERROR_STOP=1"
echo "Create Database..."
if psql -lqt | cut -d \| -f 1 | grep -qw $OMNIDB_DATABASE; then
    echo "Database exists"
    # database exists
    # $? is 0
else
    createdb "${OMNIDB_DATABASE}" "Omniwallet wallet and transaction database"
fi

cd /flyway && FLYWAY_URL="jdbc:postgresql://${PGHOST}:${PGPORT}/${OMNIDB_DATABASE}" FLYWAY_PASSWORD="${PGPASSWORD}" flyway -user=${PGUSER} migrate

python /root/omniEngine/install/installOmniEngineCronJob.py

/usr/sbin/cron -f -L /dev/stdout
