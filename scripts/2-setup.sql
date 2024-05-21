DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
CREATE EXTENSION postgres_fdw;

-- Create FDW connection

DROP SERVER IF EXISTS "eu" CASCADE;
DROP SERVER IF EXISTS "us" CASCADE;

CREATE SERVER "eu"
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'bdr-eu-1.epsilon', dbname 'postgres', port '5432');

CREATE SERVER "us"
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'bdr-us-1.epsilon', dbname 'postgres', port '5432');

CREATE USER MAPPING FOR postgres
SERVER "eu"
OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR postgres
SERVER "us"
OPTIONS (user 'postgres', password 'postgres');

-- Import schema

DROP SCHEMA IF EXISTS eu_remote CASCADE;
DROP SCHEMA IF EXISTS us_remote CASCADE;

CREATE SCHEMA eu_remote;
CREATE SCHEMA us_remote;

IMPORT FOREIGN SCHEMA public
LIMIT TO (accesslog, accessright, building, gate, gategroup, gatetogategroup, person, presencelog, region, dblogs)
FROM SERVER "eu" INTO eu_remote;

IMPORT FOREIGN SCHEMA public
LIMIT TO (accesslog, accessright, building, gate, gategroup, gatetogategroup, person, presencelog, region, dblogs)
FROM SERVER "us" INTO us_remote;

-- Distributed views

DROP SCHEMA IF EXISTS distributed CASCADE;
CREATE SCHEMA distributed;
