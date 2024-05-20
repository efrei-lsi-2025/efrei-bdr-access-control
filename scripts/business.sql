-- Extra functions for the business.sql logic

-- Function to compute if a certain badgeid has access to a certain gateid
CREATE OR REPLACE FUNCTION distributed.check_access(p_badgeid text, p_gateid text) RETURNS BOOLEAN AS $$
DECLARE
    person_region Region;
    access BOOLEAN;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = p_badgeid::uuid;

    IF person_region = 'US'::region THEN
        SELECT EXISTS (
            SELECT 1
            FROM us_remote.accessright
            JOIN us_remote.gategroup ON us_remote.accessright.gateGroupId = us_remote.gategroup.gateGroupId
            JOIN us_remote.gatetogategroup ON us_remote.gategroup.gateGroupId = us_remote.gatetogategroup.gateGroupId
            WHERE us_remote.accessright.badgeId = p_badgeid::uuid
              AND us_remote.gatetogategroup.gateId = p_gateid::uuid
              AND us_remote.accessright.expirationDate > now()
        ) INTO access;
    ELSIF person_region = 'EU'::region THEN
        SELECT EXISTS (
            SELECT 1
            FROM eu_remote.accessright
            JOIN eu_remote.gategroup ON eu_remote.accessright.gateGroupId = eu_remote.gategroup.gateGroupId
            JOIN eu_remote.gatetogategroup ON eu_remote.gategroup.gateGroupId = eu_remote.gatetogategroup.gateGroupId
            WHERE eu_remote.accessright.badgeId = p_badgeid::uuid
              AND eu_remote.gatetogategroup.gateId = p_gateid::uuid
              AND eu_remote.accessright.expirationDate > now()
        ) INTO access;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', p_badgeid;
    END IF;

    RETURN access;
END;
$$ LANGUAGE plpgsql;

-- Function to simulate a person entering/exiting a building
CREATE OR REPLACE FUNCTION distributed.enter_building(p_badgeid text, p_gateid text) RETURNS VOID AS $$
DECLARE
    d_person_region Region;
    d_access BOOLEAN;
    d_gate_direction BOOLEAN;
    d_newlogid UUID;
    d_presencelogid UUID;
    d_entrancelogid UUID;
BEGIN
    -- Get the person's region
    SELECT region INTO d_person_region FROM distributed.person_view WHERE badgeId = p_badgeid::uuid;

    IF d_person_region = 'US'::region THEN
        SELECT distributed.check_access(p_badgeid, p_gateid) INTO d_access;

        IF d_access THEN
            SELECT direction INTO d_gate_direction
            FROM us_remote.gatetogategroup
            WHERE gateId = p_gateid::uuid;

            INSERT INTO us_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
            VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), true)
            RETURNING accesslogid INTO d_newlogid;

            IF d_gate_direction THEN
                INSERT INTO us_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, gategroupid)
                VALUES (gen_random_uuid(), p_badgeid::uuid, d_newlogid, (SELECT gateGroupId FROM us_remote.gatetogategroup WHERE gateId = p_gateid::uuid));
            ELSE
                WITH gategroupId AS (
                    SELECT gateGroupId
                    FROM us_remote.gatetogategroup
                    WHERE gateId = p_gateid::uuid
                    LIMIT 1
                )
                SELECT presencelogid, entranceaccesslogid INTO d_presencelogid, d_entrancelogid
                FROM distributed.presencelog_view
                WHERE badgeid = p_badgeid::uuid
                  AND gategroupid = (SELECT gateGroupId FROM gategroupId)
                  AND exitaccesslogid IS NULL
                LIMIT 1;

                UPDATE distributed.presencelog_view
                SET exitaccesslogid = d_newlogid, elapsedtime = now() - (SELECT accessTime FROM distributed.accesslog_view WHERE accesslogid = d_entrancelogid)
                WHERE presencelogid = d_presencelogid;
            END IF;
        ELSE
            INSERT INTO us_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
            VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), false);
            RAISE EXCEPTION 'Access denied';
        END IF;
    ELSIF d_person_region = 'EU'::region THEN
        SELECT distributed.check_access(p_badgeid, p_gateid) INTO d_access;

        IF d_access THEN
            SELECT direction INTO d_gate_direction
            FROM eu_remote.gatetogategroup
            WHERE gateId = p_gateid::uuid;

            INSERT INTO eu_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
            VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), true)
            RETURNING accesslogid INTO d_newlogid;

            IF d_gate_direction THEN
                INSERT INTO eu_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, gategroupid)
                VALUES (gen_random_uuid(), p_badgeid::uuid, d_newlogid, (SELECT gateGroupId FROM eu_remote.gatetogategroup WHERE gateId = p_gateid::uuid));
            ELSE
                WITH gategroupId AS (
                    SELECT gateGroupId
                    FROM eu_remote.gatetogategroup
                    WHERE gateId = p_gateid::uuid
                    LIMIT 1
                )
                SELECT presencelogid, entranceaccesslogid INTO d_presencelogid, d_entrancelogid
                FROM distributed.presencelog_view
                WHERE badgeid = p_badgeid::uuid
                  AND gategroupid = (SELECT gateGroupId FROM gategroupId)
                  AND exitaccesslogid IS NULL
                LIMIT 1;

                UPDATE distributed.presencelog_view
                SET exitaccesslogid = d_newlogid, elapsedtime = now() - (SELECT accessTime FROM eu_remote.accesslog WHERE accesslogid = d_entrancelogid)
                WHERE presencelogid = d_presencelogid;
            END IF;
        ELSE
            INSERT INTO eu_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
            VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), false);
            RAISE EXCEPTION 'Access denied';
        END IF;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', p_badgeid;
    END IF;
END;
$$ LANGUAGE plpgsql;