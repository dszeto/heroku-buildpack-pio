#!/usr/bin/env bash

# PATH must include
# * the bin/ where `pio build` ran (for an engine)
# * just the distribution's bin/ (for the eventserver)
export PATH=/app/pio-engine/PredictionIO-dist/bin:/app/PredictionIO-dist/bin:$PATH

# Transform env variables to be consumed by PredictionIO's `conf/pio-env.sh`.
#
# Requires `conf/pio-env.sh` to be based on this buildpack's
# `config/pio-env-12f.sh`, which the compile script takes care of.
#
# Originally from https://github.com/jamesward/pio-engine-heroku/blob/master/bin/env.sh

function export_db_config_for_pio() {
	local db_name="${1-PGSQL}"
	local db_url="${2-}"

	eval "export PIO_STORAGE_SOURCES_${db_name}_TYPE=jdbc"

  if [ -z "$db_url" ]; then
    eval "export PIO_STORAGE_SOURCES_${db_name}_URL=jdbc:postgresql://localhost/pio"
    eval "export PIO_STORAGE_SOURCES_${db_name}_USERNAME=pio"
    eval "export PIO_STORAGE_SOURCES_${db_name}_PASSWORD=pio"
  else
    # from: http://stackoverflow.com/a/17287984/77409
    # extract the protocol
    local proto="`echo $db_url | grep '://' | sed -e's,^\(.*://\).*,\1,g'`"
    # remove the protocol
    local url=`echo $db_url | sed -e s,$proto,,g`

    # extract the user and password (if any)
    local userpass="`echo $url | grep @ | cut -d@ -f1`"
    local pass=`echo $userpass | grep : | cut -d: -f2`
    if [ -n "$pass" ]; then
        user=`echo $userpass | grep : | cut -d: -f1`
    else
        user=$userpass
    fi

    # extract the host -- updated
    local hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
    local port=`echo $hostport | grep : | cut -d: -f2`
    if [ -n "$port" ]; then
        host=`echo $hostport | grep : | cut -d: -f1`
    else
        host=$hostport
    fi

    # extract the path (if any)
    local path="`echo $url | grep / | cut -d/ -f2-`"

    eval "export PIO_STORAGE_SOURCES_${db_name}_URL=jdbc:postgresql://${hostport}/${path}?sslmode=require"
    eval "export PIO_STORAGE_SOURCES_${db_name}_USERNAME=${user}"
    eval "export PIO_STORAGE_SOURCES_${db_name}_PASSWORD=${pass}"
  fi
}


export PIO_STORAGE_REPOSITORIES_METADATA_NAME=pio_meta
export PIO_STORAGE_REPOSITORIES_EVENTDATA_NAME=pio_event
export PIO_STORAGE_REPOSITORIES_MODELDATA_NAME=pio_model

if [ -z "$PRIVATE_DATABASE_URL" ]; then
	# Use one database for everything
	export PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL
	export PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQL
	export PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQL

	export_db_config_for_pio "PGSQL" "$DATABASE_URL"

else
	# $PRIVATE_DATABASE_URL is available.
	# Use a Private database in a Private Space,
	# Use a second Common Runtime database for
	# engine metadata that must accessible during build.
	export PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL
	export PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQLPRIVATE
	export PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQLPRIVATE

	export_db_config_for_pio "PGSQL" "$DATABASE_URL"
	export_db_config_for_pio "PGSQLPRIVATE" "$PRIVATE_DATABASE_URL"
fi
