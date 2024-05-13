INSERT INTO Building (buildingId, name, address) VALUES (gen_random_uuid(), 'Building 1', 'Address 1');

INSERT INTO Person (badgeid, name) VALUES (gen_random_uuid(), 'Alice');

INSERT INTO Gate (gateId) VALUES (gen_random_uuid());

WITH building AS (SELECT buildingId FROM Building WHERE name = 'Building 1')
INSERT INTO GateGroup (gateGroupId, buildingId, name)
SELECT gen_random_uuid(), building.buildingid, 'Gate Group 1'
FROM building;

WITH gategroup AS (SELECT gateGroupId FROM GateGroup WHERE name = 'Gate Group 1'), gate AS (SELECT gateId FROM Gate LIMIT 1)
INSERT INTO GateToGateGroup (gatetogategroupid, gateid, gategroupid, direction)
SELECT gen_random_uuid(), gate.gateid, gategroup.gategroupid, true
FROM gategroup, gate;

WITH gategroup AS (SELECT gateGroupId FROM GateGroup WHERE name = 'Gate Group 1'),
        person AS (SELECT badgeid FROM Person WHERE name = 'Alice')
INSERT INTO AccessRight (gategroupid, badgeid, expirationdate)
SELECT gategroup.gategroupid, person.badgeid, '2025-01-01'
FROM gategroup, person;

WITH person AS (SELECT badgeid FROM Person WHERE name = 'Alice'),
        gate AS (SELECT gateId FROM Gate LIMIT 1)
INSERT INTO accesslog (accesslogid, badgeid, gateid, accesstime, success)
SELECT gen_random_uuid(), person.badgeid, gate.gateid, '2021-01-01 12:00:00', true
FROM person, gate;

WITH person AS (SELECT badgeid FROM Person WHERE name = 'Alice'),
        gategroup AS (SELECT gateGroupId FROM GateGroup WHERE name = 'Gate Group 1'),
        accesslog AS (SELECT accesslogid FROM accesslog LIMIT 1)
INSERT INTO presencelog (presencelogid, badgeid, gategroupid, entranceaccesslogid)
SELECT gen_random_uuid(), person.badgeid, gategroup.gategroupid, accesslog.accesslogid
FROM person, gategroup, accesslog;