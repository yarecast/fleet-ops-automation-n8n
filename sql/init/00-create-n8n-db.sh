#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" \
  -v n8n_user="$N8N_DB_USER" -v n8n_pass="$N8N_DB_PASSWORD" -v n8n_db="$N8N_DB_NAME" <<'EOSQL'
CREATE ROLE :"n8n_user" LOGIN PASSWORD :'n8n_pass';
CREATE DATABASE :"n8n_db" OWNER :"n8n_user";
REVOKE ALL ON DATABASE :"n8n_db" FROM PUBLIC;
EOSQL
