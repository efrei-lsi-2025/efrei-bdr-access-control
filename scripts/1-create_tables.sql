DROP TABLE IF EXISTS PresenceLog;
DROP TABLE IF EXISTS AccessLog;
DROP TABLE IF EXISTS AccessRight;
DROP TABLE IF EXISTS GateToGateGroup;
DROP TABLE IF EXISTS GateGroup;
DROP TABLE IF EXISTS Gate;
DROP TABLE IF EXISTS Building;
DROP TABLE IF EXISTS Person;
DROP TYPE IF EXISTS Region CASCADE;

-- SET citus.shard_replication_factor = 2;
SET citus.enable_repartition_joins = on;

CREATE TYPE Region AS ENUM ('EU', 'US');

CREATE TABLE IF NOT EXISTS Person (
    badgeId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    region Region NOT NULL
);

SELECT create_distributed_table('person', 'badgeid');

CREATE TABLE IF NOT EXISTS Building (
    buildingId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(511) NOT NULL,
    region Region NOT NULL
);

SELECT create_reference_table('building');

CREATE TABLE IF NOT EXISTS Gate (
    gateId UUID PRIMARY KEY
);

SELECT create_reference_table('gate');

CREATE TABLE IF NOT EXISTS GateGroup (
    gateGroupId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    buildingId UUID NOT NULL,
    FOREIGN KEY (buildingId) REFERENCES Building(buildingId)
);

SELECT create_reference_table('gategroup');

CREATE TABLE IF NOT EXISTS GateToGateGroup (
    gateToGateGroupId UUID PRIMARY KEY,
    gateId UUID NOT NULL,
    gateGroupId UUID NOT NULL,
    direction BOOLEAN NOT NULL,
    FOREIGN KEY (gateId) REFERENCES Gate(gateId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId)
);

SELECT create_reference_table('gatetogategroup');

CREATE TABLE IF NOT EXISTS AccessRight (
    gateGroupId UUID NOT NULL,
    badgeId UUID NOT NULL,
    expirationDate DATE NOT NULL,
    PRIMARY KEY (gateGroupId, badgeId)
);

SELECT create_distributed_table('accessright', 'badgeid', colocate_with => 'person');

-- Only if replication factor is 1:
-- ALTER TABLE AccessRight ADD FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId);
-- ALTER TABLE AccessRight ADD FOREIGN KEY (badgeId) REFERENCES Person(badgeId);

CREATE TABLE IF NOT EXISTS AccessLog (
    accessLogId UUID,
    badgeId UUID NOT NULL,
    gateId UUID NOT NULL,
    accessTime TIMESTAMP NOT NULL,
    success BOOLEAN NOT NULL,
    PRIMARY KEY (accessLogId, badgeId)
);

SELECT create_distributed_table('accesslog', 'accesslogid');

CREATE TABLE IF NOT EXISTS PresenceLog (
    presenceLogId UUID PRIMARY KEY,
    badgeId UUID NOT NULL,
    gateGroupId UUID NOT NULL,
    entranceAccessLogId UUID NOT NULL,
    exitAccessLogId UUID,
    elapsedTime TIME
);

SELECT create_distributed_table('presencelog', 'presencelogid');