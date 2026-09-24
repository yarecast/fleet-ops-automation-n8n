#!/bin/bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" --dbname "postgres" \
  -v db_name="$FLEETOPS_DB_NAME" \
  -v app_user="$FLEETOPS_APP_USER" \
  -v app_pass="$FLEETOPS_APP_PASSWORD" \
  -v ro_user="$FLEETOPS_RO_USER" \
  -v ro_pass="$FLEETOPS_RO_PASSWORD" <<'EOSQL'

CREATE ROLE :"app_user" LOGIN PASSWORD :'app_pass';
CREATE ROLE :"ro_user"  LOGIN PASSWORD :'ro_pass';

CREATE DATABASE :"db_name" OWNER :"app_user";

REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db_name" TO :"ro_user";

EOSQL