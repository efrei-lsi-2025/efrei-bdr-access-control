-- Person
CREATE OR REPLACE VIEW distributed.person_view AS
    SELECT badgeId, region
    FROM us_remote.person
UNION ALL
    SELECT badgeId, region
    FROM eu_remote.person;

-- Building
CREATE OR REPLACE VIEW distributed.building_view AS
    SELECT buildingId, name, address, region
    FROM us_remote.building
UNION ALL
    SELECT buildingId, name, address, region
    FROM eu_remote.building;

-- Gate Group
CREATE OR REPLACE VIEW distributed.gategroup_view AS
    SELECT gateGroupId, name, buildingId
    FROM us_remote.gategroup
UNION ALL
    SELECT gateGroupId, name, buildingId
    FROM eu_remote.gategroup;

-- Gate
CREATE OR REPLACE VIEW distributed.gate_view AS
    SELECT gateid
    FROM us_remote.gate
UNION ALL
    SELECT gateId
    FROM eu_remote.gate;

-- Gate to Gate Group
CREATE OR REPLACE VIEW distributed.gatetogategroup_view AS
    SELECT gateId, gateGroupId, direction
    FROM us_remote.gatetogategroup
UNION ALL
    SELECT gateId, gateGroupId, direction
    FROM eu_remote.gatetogategroup;

-- Access Right
CREATE OR REPLACE VIEW distributed.accessright_view AS
    SELECT gateGroupId, badgeId, expirationDate
    FROM us_remote.accessright
UNION ALL
    SELECT gateGroupId, badgeId, expirationDate
    FROM eu_remote.accessright;

-- Access Log
CREATE OR REPLACE VIEW distributed.accesslog_view AS
    SELECT accesslogid, gateId, badgeId, accessTime, success
    FROM us_remote.accesslog
UNION ALL
    SELECT accesslogid, gateId, badgeId, accessTime, success
    FROM eu_remote.accesslog;

-- Presence Log
CREATE OR REPLACE VIEW distributed.presencelog_view AS
    SELECT presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime
    FROM us_remote.presencelog
UNION ALL
    SELECT presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime
    FROM eu_remote.presencelog;

-- Database Log
CREATE OR REPLACE VIEW distributed.dblogs_view AS
    SELECT logId, operationTime, userName, operationType, objectName, objectId
    FROM us_remote.dblogs
UNION ALL
    SELECT logId, operationTime, userName, operationType, objectName, objectId
    FROM eu_remote.dblogs;