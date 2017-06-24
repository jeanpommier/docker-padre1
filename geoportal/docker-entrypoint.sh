#!/bin/bash
set -e

if [ "$1" = 'catalina.sh' ]; then

	set -e
						
	mkdir -p "$DATA_DIR"

	#Set geonetwork data dir
	export CATALINA_OPTS="$CATALINA_OPTS -Dgeonetwork.dir=$DATA_DIR"
	
	#Set logs destination
	sed -i -E "s|\"logs\/geonetwork.log\"|\"${DATA_DIR}\/logs\/geonetwork.log\"|gm" geonetwork/WEB-INF/classes/log4j.xml

	#Setting host (use $POSTGRES_DB_HOST if it's set, otherwise use "pg")
	db_host="${POSTGRES_DB_HOST:-pg}"
	echo "db host: $db_host"

	#Setting port
	db_port="${POSTGRES_DB_PORT:-5432}"
	echo "db port: $db_port"
	

	if [ -z "$POSTGRES_DB_USERNAME" ] || [ -z "$POSTGRES_DB_PASSWORD" ]; then
		echo >&2 "you must set POSTGRES_DB_USERNAME and POSTGRES_DB_PASSWORD"
		exit 1
	fi
	
	#wait for the DB to be ready to accept connections
	until PGPASSWORD=$POSTGRES_DB_PASSWORD psql -h "$db_host" -p "$db_port" -U "$POSTGRES_DB_USERNAME" -c '\l'; do
		>&2 echo "Postgres is unavailable - sleeping"
		sleep 1
	done
	>&2 echo "Postgres is up - starting geonetwork"


	db_admin="padre"
	db_gn="geonetwork"

	#Create databases, if they do not exist yet (http://stackoverflow.com/a/36591842/433558)
	echo  "$db_host:$db_port:*:$POSTGRES_DB_USERNAME:$POSTGRES_DB_PASSWORD" > ~/.pgpass
	chmod 0600 ~/.pgpass
	for db_name in "$db_admin" "$db_gn"; do
		if psql -h "$db_host" -U "$POSTGRES_DB_USERNAME" -p "$db_port" -tqc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
			echo "database '$db_name' exists; skipping createdb"
		else
			echo "database '$db_name' doesn't exist; creating '$db_name'"
			createdb -h "$db_host" -U "$POSTGRES_DB_USERNAME" -p "$db_port" -O "$POSTGRES_DB_USERNAME" "$db_name"
		fi
	done
	rm ~/.pgpass

fi

exec "$@"
