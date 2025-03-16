#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE beam_flow_test;
  GRANT ALL PRIVILEGES ON DATABASE beam_flow_test TO postgres;
EOSQL