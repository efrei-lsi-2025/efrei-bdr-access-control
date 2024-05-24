-- Extra functions for the 4-business.sql logic

-- Function to compute if a certain badgeid has access to a certain gateid
CREATE OR REPLACE FUNCTION distributed.check_access(p_badgeid text, p_gateid text) RETURNS BOOLEAN AS $$
DECLARE
    person_region Region;
    access BOOLEAN;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = p_badgeid::uuid;

    IF person_region = 'US'::region THEN
        WITH
            -- Gate groups of the gate
            gate_groups AS (
                SELECT gateGroupId
                FROM us_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
            ),
            -- Gate groups the person has access to
            valid_access AS (
                SELECT gateGroupId
                FROM us_remote.accessright
                WHERE badgeId = p_badgeid::uuid
                  AND expirationDate > now()
            )
        SELECT EXISTS (
            SELECT 1
                FROM gate_groups gg
                -- Has access to at least one gate group
                WHERE EXISTS (
                    SELECT 1
                        FROM valid_access va
                        WHERE va.gateGroupId = gg.gateGroupId
                )
                -- And has access to all gate groups (no gate group without access)
                AND NOT EXISTS (
                    SELECT 1
                        FROM gate_groups gg2
                        WHERE NOT EXISTS (
                            SELECT 1
                                FROM valid_access va2
                                WHERE va2.gateGroupId = gg2.gateGroupId
                        )
                )
            )
        INTO access;
    ELSIF person_region = 'EU'::region THEN
        WITH
            -- Gate groups of the gate
            gate_groups AS (
                SELECT gateGroupId
                FROM eu_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
            ),
            -- Gate groups the person has access to
            valid_access AS (
                SELECT gateGroupId
                FROM eu_remote.accessright
                WHERE badgeId = p_badgeid::uuid
                  AND expirationDate > now()
            )
        SELECT EXISTS (
            SELECT 1
                FROM gate_groups gg
                -- Has access to at least one gate group
                WHERE EXISTS (
                    SELECT 1
                        FROM valid_access va
                        WHERE va.gateGroupId = gg.gateGroupId
                )
                -- And has access to all gate groups (no gate group without access)
                AND NOT EXISTS (
                    SELECT 1
                        FROM gate_groups gg2
                        WHERE NOT EXISTS (
                            SELECT 1
                                FROM valid_access va2
                                WHERE va2.gateGroupId = gg2.gateGroupId
                        )
                )
            )
        INTO access;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', p_badgeid;
    END IF;

    RETURN access;
END;
$$ LANGUAGE plpgsql;

-- Function to simulate a person entering/exiting a building
CREATE OR REPLACE FUNCTION distributed.enter_workspace(p_badgeid text, p_gateid text) RETURNS VOID AS $$
DECLARE
    d_person_region Region;
    d_access BOOLEAN;
    d_gate_direction BOOLEAN;
    d_newlogid UUID;
    d_presencelogid UUID;
    d_entrancelogid UUID;
    d_gategroup UUID;
BEGIN
    -- Get the person's region
    SELECT region INTO d_person_region FROM distributed.person_view WHERE badgeId = p_badgeid::uuid;

    IF d_person_region = 'US'::region THEN
        SELECT distributed.check_access(p_badgeid, p_gateid) INTO d_access;

        INSERT INTO us_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
                VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), d_access)
                RETURNING accesslogid INTO d_newlogid;

        IF d_access THEN
            FOR d_gategroup IN
                SELECT gateGroupId
                FROM us_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
            LOOP
                SELECT direction INTO d_gate_direction
                FROM us_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
                  AND gateGroupId = d_gategroup;

                IF d_gate_direction THEN
                    INSERT INTO us_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, gategroupid)
                    VALUES (gen_random_uuid(), p_badgeid::uuid, d_newlogid, d_gategroup);
                ELSE
                    WITH presencelog AS (
                        SELECT p.presencelogid, p.entranceaccesslogid
                        FROM distributed.presencelog_view p
                        JOIN distributed.accesslog_view a on p.entranceaccesslogid = a.accesslogid
                        WHERE p.badgeid = p_badgeid::uuid
                          AND p.gategroupid = d_gategroup
                          AND p.exitaccesslogid IS NULL
                        ORDER BY a.accesstime DESC
                        LIMIT 1
                    )
                    UPDATE distributed.presencelog_view
                    SET exitaccesslogid = d_newlogid, elapsedtime = now() - (SELECT accessTime FROM us_remote.accesslog WHERE accesslogid = (SELECT entranceaccesslogid FROM presencelog))
                    WHERE presencelogid = (SELECT presencelogid FROM presencelog);
                END IF;
            END LOOP;

        ELSE
            RAISE EXCEPTION 'Access denied';
        END IF;
    ELSIF d_person_region = 'EU'::region THEN
        SELECT distributed.check_access(p_badgeid, p_gateid) INTO d_access;

        INSERT INTO eu_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
                VALUES (gen_random_uuid(), p_gateid::uuid, p_badgeid::uuid, now(), d_access)
                RETURNING accesslogid INTO d_newlogid;

        IF d_access THEN
            FOR d_gategroup IN
                SELECT gateGroupId
                FROM eu_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
            LOOP
                SELECT direction INTO d_gate_direction
                FROM eu_remote.gatetogategroup
                WHERE gateId = p_gateid::uuid
                  AND gateGroupId = d_gategroup;

                IF d_gate_direction THEN
                    INSERT INTO eu_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, gategroupid)
                    VALUES (gen_random_uuid(), p_badgeid::uuid, d_newlogid, d_gategroup);
                ELSE
                    WITH presencelog AS (
                        SELECT p.presencelogid, p.entranceaccesslogid
                        FROM distributed.presencelog_view p
                        JOIN distributed.accesslog_view a on p.entranceaccesslogid = a.accesslogid
                        WHERE p.badgeid = p_badgeid::uuid
                          AND p.gategroupid = d_gategroup
                          AND p.exitaccesslogid IS NULL
                        ORDER BY a.accesstime DESC
                        LIMIT 1
                    )
                    UPDATE distributed.presencelog_view
                    SET exitaccesslogid = d_newlogid, elapsedtime = now() - (SELECT accessTime FROM eu_remote.accesslog WHERE accesslogid = (SELECT entranceaccesslogid FROM presencelog))
                    WHERE presencelogid = (SELECT presencelogid FROM presencelog);
                END IF;
            END LOOP;
        ELSE
            RAISE EXCEPTION 'Access denied';
        END IF;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', p_badgeid;
    END IF;
END;
$$ LANGUAGE plpgsql;