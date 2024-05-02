DROP TABLE IF EXISTS PresenceLog;
DROP TABLE IF EXISTS AccessLog;
DROP TABLE IF EXISTS AccessRight;
DROP TABLE IF EXISTS GateToGateGroup;
DROP TABLE IF EXISTS GateGroup;
DROP TABLE IF EXISTS Gate;
DROP TABLE IF EXISTS Building;
DROP TABLE IF EXISTS Person;

CREATE TABLE IF NOT EXISTS Person (
    badgeId SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS Building (
    buildingId SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(511) NOT NULL
);

CREATE TABLE IF NOT EXISTS Gate (
    gateId SERIAL PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS GateGroup (
    gateGroupId SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    buildingId INT NOT NULL,
    FOREIGN KEY (buildingId) REFERENCES Building(buildingId)
);

CREATE TABLE IF NOT EXISTS GateToGateGroup (
    gateToGateGroupId SERIAL PRIMARY KEY,
    gateId INT NOT NULL,
    gateGroupId INT NOT NULL,
    direction BOOLEAN NOT NULL,
    FOREIGN KEY (gateId) REFERENCES Gate(gateId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId)
);

CREATE TABLE IF NOT EXISTS AccessRight (
    gateGroupId INT NOT NULL,
    badgeId INT NOT NULL,
    expirationDate DATE NOT NULL,
    PRIMARY KEY (gateGroupId, badgeId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId),
    FOREIGN KEY (badgeId) REFERENCES Person(badgeId)
);

CREATE TABLE IF NOT EXISTS AccessLog (
    accessLogId SERIAL PRIMARY KEY,
    gateId INT NOT NULL,
    badgeId INT NOT NULL,
    accessTime TIMESTAMP NOT NULL,
    success BOOLEAN NOT NULL,
    FOREIGN KEY (gateId) REFERENCES Gate(gateId),
    FOREIGN KEY (badgeId) REFERENCES Person(badgeId)
);

CREATE TABLE IF NOT EXISTS PresenceLog (
    presenceLogId SERIAL PRIMARY KEY,
    badgeId INT NOT NULL,
    gateGroupId INT NOT NULL,
    entranceAccessLogId INT NOT NULL,
    exitAccessLogId INT,
    elapsedTime TIME,
    FOREIGN KEY (badgeId) REFERENCES Person(badgeId),
    FOREIGN KEY (gateGroupId) REFERENCES GateGroup(gateGroupId),
    FOREIGN KEY (entranceAccessLogId) REFERENCES AccessLog(accessLogId),
    FOREIGN KEY (exitAccessLogId) REFERENCES AccessLog(accessLogId)
);