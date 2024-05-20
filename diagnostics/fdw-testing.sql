-- Person

INSERT INTO distributed.person_view(badgeid, name, region)
VALUES (gen_random_uuid(), 'Antoine', 'EU');

INSERT INTO distributed.person_view(badgeid, name, region)
VALUES (gen_random_uuid(), 'Thibaut', 'US');

SELECT * FROM distributed.person_view;

SELECT * FROM eu_remote.person;

SELECT * FROM us_remote.person;

-- Building

INSERT INTO distributed.building_view(buildingid, name, address, region)
VALUES (gen_random_uuid(), 'Bezons', '80 Quai Voltaire, 95870 Bezons', 'EU');

INSERT INTO distributed.building_view(buildingid, name, address, region)
VALUES (gen_random_uuid(), 'New York', 'One Exchange Plaza, 1 Exchange Aly # 2001, New York, NY 10006', 'US');

SELECT * FROM distributed.building_view;

SELECT * FROM eu_remote.building;

SELECT * FROM us_remote.building;

-- Gate Group

INSERT INTO distributed.gategroup_view(gategroupid, name, buildingid)
VALUES (gen_random_uuid(), 'Campus', (SELECT buildingid FROM distributed.building_view WHERE name = 'Bezons'));

INSERT INTO distributed.gategroup_view(gategroupid, name, buildingid)
VALUES (gen_random_uuid(), 'Office', (SELECT buildingid FROM distributed.building_view WHERE name = 'New York'));

SELECT * FROM distributed.gategroup_view;

SELECT * FROM eu_remote.gategroup;

SELECT * FROM us_remote.gategroup;

-- Gate

INSERT INTO distributed.gate_and_gatetogategroup_view(gateid, gategroupid, direction)
VALUES (gen_random_uuid(), (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Campus'), true);

INSERT INTO distributed.gate_and_gatetogategroup_view(gateid, gategroupid, direction)
VALUES (gen_random_uuid(), (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Campus'), false);

INSERT INTO distributed.gate_and_gatetogategroup_view(gateid, gategroupid, direction)
VALUES (gen_random_uuid(), (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Office'), true);

INSERT INTO distributed.gate_and_gatetogategroup_view(gateid, gategroupid, direction)
VALUES (gen_random_uuid(), (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Office'), false);

SELECT * FROM distributed.gate_and_gatetogategroup_view;
SELECT * FROM distributed.gate_view;

SELECT * FROM eu_remote.gate;
SELECT * FROM eu_remote.gatetogategroup;

SELECT * FROM us_remote.gate;
SELECT * FROM us_remote.gatetogategroup;

-- Access Right

INSERT INTO distributed.accessright_view(badgeid, gategroupid, expirationdate)
VALUES (
        (SELECT badgeid FROM distributed.person_view WHERE name = 'Antoine'),
        (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Campus'),
        '2025-12-31'
);

INSERT INTO distributed.accessright_view(badgeid, gategroupid, expirationdate)
VALUES (
        (SELECT badgeid FROM distributed.person_view WHERE name = 'Thibaut'),
        (SELECT gategroupid FROM distributed.gategroup_view WHERE name = 'Office'),
        '2025-12-31'
);

SELECT * FROM distributed.accessright_view;

SELECT * FROM eu_remote.accessright;
SELECT * FROM us_remote.accessright;

-- Building Access Simulation

SELECT distributed.enter_building((SELECT badgeid FROM distributed.person_view WHERE name = 'Antoine')::text, (SELECT gateid FROM distributed.gate_and_gatetogategroup_view JOIN distributed.gategroup_view ON distributed.gategroup_view.gategroupid = distributed.gate_and_gatetogategroup_view.gategroupid WHERE name = 'Campus' AND direction = true LIMIT 1)::text);
SELECT distributed.enter_building((SELECT badgeid FROM distributed.person_view WHERE name = 'Antoine')::text, (SELECT gateid FROM distributed.gate_and_gatetogategroup_view JOIN distributed.gategroup_view ON distributed.gategroup_view.gategroupid = distributed.gate_and_gatetogategroup_view.gategroupid WHERE name = 'Campus' AND direction = false LIMIT 1)::text);

SELECT * FROM distributed.presencelog_view WHERE badgeid = (SELECT badgeid FROM distributed.person_view WHERE name = 'Antoine');