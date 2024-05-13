DROP TABLE IF EXISTS PresenceLog;
DROP TABLE IF EXISTS AccessLog;
DROP TABLE IF EXISTS AccessRight;
DROP TABLE IF EXISTS GateToGateGroup;
DROP TABLE IF EXISTS GateGroup;
DROP TABLE IF EXISTS Gate;
DROP TABLE IF EXISTS Building;
DROP TABLE IF EXISTS Person;

CREATE TABLE IF NOT EXISTS Person (
    badgeId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    region VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS Building (
    buildingId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(511) NOT NULL
);

CREATE TABLE IF NOT EXISTS Gate (
    gateId UUID PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS GateGroup (
    gateGroupId UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    buildingId UUID NOT NULL,
    FOREIGN KEY (buildingId) REFERENCES Building(buildingId)
);

CREATE TABLE IF NOT EXISTS GateToGateGroup (
    gateToGateGroupId UUID PRIMARY KEY,
    gateId UUID NOT NULL,
    gateGroupId UUID NOT NULL,
    direction BOOLEAN NOT NULL,
    FOREIGN KEY (gateId) REFERENCES Gate(gateId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId)
);

CREATE TABLE IF NOT EXISTS AccessRight (
    gateGroupId UUID NOT NULL,
    badgeId UUID NOT NULL,
    expirationDate DATE NOT NULL,
    PRIMARY KEY (gateGroupId, badgeId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId),
    FOREIGN KEY (badgeId) REFERENCES Person(badgeId)
);

CREATE TABLE IF NOT EXISTS AccessLog (
    accessLogId UUID PRIMARY KEY,
    badgeId UUID NOT NULL,
    gateId UUID NOT NULL,
    accessTime TIMESTAMP NOT NULL,
    success BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS PresenceLog (
    presenceLogId UUID PRIMARY KEY,
    badgeId UUID NOT NULL,
    gateGroupId UUID NOT NULL,
    entranceAccessLogId UUID NOT NULL,
    exitAccessLogId UUID,
    elapsedTime TIME
);