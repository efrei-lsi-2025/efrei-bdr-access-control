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
LIMIT TO (accesslog, accessright, building, gate, gategroup, gatetogategroup, person, presencelog, region)
FROM SERVER "eu" INTO eu_remote;

IMPORT FOREIGN SCHEMA public
LIMIT TO (accesslog, accessright, building, gate, gategroup, gatetogategroup, person, presencelog, region)
FROM SERVER "us" INTO us_remote;

-- Distributed views

DROP SCHEMA IF EXISTS distributed CASCADE;
CREATE SCHEMA distributed;

-- Person

CREATE OR REPLACE VIEW distributed.person_view AS
    SELECT badgeId, name, region
    FROM us_remote.person
UNION ALL
    SELECT badgeId, name, region
    FROM eu_remote.person;

-- TODO: GDPR?

CREATE OR REPLACE FUNCTION distributed.insert_person() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.region = 'US'::region THEN
        INSERT INTO us_remote.person (badgeId, name, region) VALUES (NEW.badgeId, NEW.name, NEW.region::region);
    ELSIF NEW.region = 'EU'::region THEN
        INSERT INTO eu_remote.person (badgeId, name, region) VALUES (NEW.badgeId, NEW.name, NEW.region::region);
    ELSE
        RAISE EXCEPTION 'Invalid region: %', NEW.region;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_person() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.region <> NEW.region THEN
        RAISE EXCEPTION 'Region cannot be changed';
    END IF;

    IF NEW.region = 'US'::region THEN
        UPDATE us_remote.person SET name = NEW.name WHERE badgeId = NEW.badgeId;
    ELSIF NEW.region = 'EU'::region THEN
        UPDATE eu_remote.person SET name = NEW.name WHERE badgeId = NEW.badgeId;
    ELSE
        RAISE EXCEPTION 'Invalid region: %', NEW.region;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_person() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.region = 'US'::region THEN
        DELETE FROM us_remote.person WHERE badgeId = OLD.badgeId;
    ELSIF OLD.region = 'EU'::region THEN
        DELETE FROM eu_remote.person WHERE badgeId = OLD.badgeId;
    ELSE
        RAISE EXCEPTION 'Invalid region: %', OLD.region;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER insert_person_trigger
INSTEAD OF INSERT ON distributed.person_view
FOR EACH ROW EXECUTE FUNCTION distributed.insert_person();

CREATE OR REPLACE TRIGGER update_person_trigger
INSTEAD OF UPDATE ON distributed.person_view
FOR EACH ROW EXECUTE FUNCTION distributed.update_person();

CREATE OR REPLACE TRIGGER delete_person_trigger
INSTEAD OF DELETE ON distributed.person_view
FOR EACH ROW EXECUTE FUNCTION distributed.delete_person();

-- Building

CREATE OR REPLACE VIEW distributed.building_view AS
    SELECT buildingId, name, address, region
    FROM us_remote.building
UNION ALL
    SELECT buildingId, name, address, region
    FROM eu_remote.building;

CREATE OR REPLACE FUNCTION distributed.insert_building() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.region = 'US'::region THEN
        INSERT INTO us_remote.building (buildingId, name, address, region) VALUES (NEW.buildingId, NEW.name, NEW.address, NEW.region::Region);
    ELSIF NEW.region = 'EU'::region THEN
        INSERT INTO eu_remote.building (buildingId, name, address, region) VALUES (NEW.buildingId, NEW.name, NEW.address, NEW.region::Region);
    ELSE
        RAISE EXCEPTION 'Invalid region: %', NEW.region;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_building() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.region <> NEW.region THEN
        RAISE EXCEPTION 'Region cannot be changed';
    END IF;

    IF OLD.region = 'US'::region THEN
        UPDATE us_remote.building
        SET name = NEW.name, address = NEW.address, region = NEW.region::Region
        WHERE buildingId = OLD.buildingId;
    ELSIF OLD.region = 'EU'::region THEN
        UPDATE eu_remote.building
        SET name = NEW.name, address = NEW.address, region = NEW.region::Region
        WHERE buildingId = OLD.buildingId;
    ELSE
        RAISE EXCEPTION 'Invalid region: %', OLD.region;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_building() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.region = 'US'::region THEN
        DELETE FROM us_remote.building WHERE buildingId = OLD.buildingId;
    ELSIF OLD.region = 'EU'::region THEN
        DELETE FROM eu_remote.building WHERE buildingId = OLD.buildingId;
    ELSE
        RAISE EXCEPTION 'Invalid region: %', OLD.region;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_building
INSTEAD OF INSERT ON distributed.building_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_building();

CREATE TRIGGER instead_of_update_building
INSTEAD OF UPDATE ON distributed.building_view
FOR EACH ROW
EXECUTE FUNCTION distributed.update_building();

CREATE TRIGGER instead_of_delete_building
INSTEAD OF DELETE ON distributed.building_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_building();

-- Gate Group

CREATE OR REPLACE VIEW distributed.gategroup_view AS
    SELECT gateGroupId, name, buildingId
    FROM us_remote.gategroup
UNION ALL
    SELECT gateGroupId, name, buildingId
    FROM eu_remote.gategroup;

CREATE OR REPLACE FUNCTION distributed.insert_gategroup() RETURNS TRIGGER AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = NEW.buildingId;

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = NEW.buildingId;
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US'::region THEN
            INSERT INTO us_remote.gategroup (gateGroupId, name, buildingId) VALUES (NEW.gateGroupId, NEW.name, NEW.buildingId);
        ELSIF building_region = 'EU'::region THEN
            INSERT INTO eu_remote.gategroup (gateGroupId, name, buildingId) VALUES (NEW.gateGroupId, NEW.name, NEW.buildingId);
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region: %', NEW.buildingId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_gategroup() RETURNS TRIGGER AS $$
DECLARE
    old_building_region Region;
    new_building_region Region;
BEGIN
    -- Find the region of the old associated building in the US remote schema
    SELECT region INTO old_building_region
    FROM us_remote.building
    WHERE buildingId = OLD.buildingId;

    -- If not found in the US remote schema, check the EU remote schema
    IF old_building_region IS NULL THEN
        SELECT region INTO old_building_region
        FROM eu_remote.building
        WHERE buildingId = OLD.buildingId;
    END IF;

    -- Find the region of the new associated building in the US remote schema
    SELECT region INTO new_building_region
    FROM us_remote.building
    WHERE buildingId = NEW.buildingId;

    -- If not found in the US remote schema, check the EU remote schema
    IF new_building_region IS NULL THEN
        SELECT region INTO new_building_region
        FROM eu_remote.building
        WHERE buildingId = NEW.buildingId;
    END IF;

    -- Ensure both buildings are in the same region
    IF old_building_region = new_building_region THEN
        IF old_building_region = 'US'::region THEN
            UPDATE us_remote.gategroup SET name = NEW.name, buildingId = NEW.buildingId WHERE gateGroupId = OLD.gateGroupId;
        ELSIF old_building_region = 'EU'::region THEN
            UPDATE eu_remote.gategroup SET name = NEW.name, buildingId = NEW.buildingId WHERE gateGroupId = OLD.gateGroupId;
        END IF;
    ELSE
        RAISE EXCEPTION 'New building must be in the same region as the old building';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_gategroup() RETURNS TRIGGER AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = OLD.buildingId;

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = OLD.buildingId;
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US'::region THEN
            DELETE FROM us_remote.gategroup WHERE gateGroupId = OLD.gateGroupId;
        ELSIF building_region = 'EU'::region THEN
            DELETE FROM eu_remote.gategroup WHERE gateGroupId = OLD.gateGroupId;
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region: %', OLD.buildingId;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_gategroup
INSTEAD OF INSERT ON distributed.gategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_gategroup();

CREATE TRIGGER instead_of_update_gategroup
INSTEAD OF UPDATE ON distributed.gategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.update_gategroup();

CREATE TRIGGER instead_of_delete_gategroup
INSTEAD OF DELETE ON distributed.gategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_gategroup();

-- Gate

CREATE OR REPLACE VIEW distributed.gate_view AS
    SELECT gateid
    FROM us_remote.gate
UNION ALL
    SELECT gateId
    FROM eu_remote.gate;

-- Creating a view for inserts of new gates through the distributed.create_gate_and_gatetogategroup function below

CREATE OR REPLACE VIEW distributed.gate_and_gatetogategroup_view AS
    SELECT gate.gateId, gatetogategroup.gateGroupId, gatetogategroup.direction
    FROM us_remote.gate
    JOIN us_remote.gatetogategroup ON us_remote.gate.gateId = us_remote.gatetogategroup.gateId
UNION ALL
    SELECT gate.gateId, gatetogategroup.gateGroupId, gatetogategroup.direction
    FROM eu_remote.gate
    JOIN eu_remote.gatetogategroup ON eu_remote.gate.gateId = eu_remote.gatetogategroup.gateId;

CREATE OR REPLACE FUNCTION distributed.insert_gate_and_gatetogategroup_trigger() RETURNS TRIGGER AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = (SELECT buildingId FROM us_remote.gategroup WHERE gateGroupId = NEW.gateGroupId);

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = (SELECT buildingId FROM eu_remote.gategroup WHERE gateGroupId = NEW.gateGroupId);
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US'::region THEN
            -- Insert gate in the US remote schema
            INSERT INTO us_remote.gate (gateId) VALUES (NEW.gateId);

            -- Insert GateToGateGroup in the US remote schema
            INSERT INTO us_remote.gatetogategroup (gateToGateGroupId, gateId, gateGroupId, direction)
            VALUES (gen_random_uuid(), NEW.gateId, NEW.gateGroupId, NEW.direction);

        ELSIF building_region = 'EU'::region THEN
            -- Insert gate in the EU remote schema
            INSERT INTO eu_remote.gate (gateId) VALUES (NEW.gateId);

            -- Insert GateToGateGroup in the EU remote schema
            INSERT INTO eu_remote.gatetogategroup (gateToGateGroupId, gateId, gateGroupId, direction)
            VALUES (gen_random_uuid(), NEW.gateId, NEW.gateGroupId, NEW.direction);
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region for gateGroupId: %', NEW.gateGroupId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_gate_and_gatetogategroup_trigger() RETURNS TRIGGER AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = (SELECT buildingId FROM us_remote.gategroup WHERE gateGroupId = NEW.gateGroupId);

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = (SELECT buildingId FROM eu_remote.gategroup WHERE gateGroupId = NEW.gateGroupId);
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US'::region THEN
            -- Update GateToGateGroup in the US remote schema
            UPDATE us_remote.gatetogategroup SET direction = NEW.direction WHERE gateId = NEW.gateId AND gateGroupId = NEW.gateGroupId;
        ELSIF building_region = 'EU'::region THEN
            -- Update GateToGateGroup in the EU remote schema
            UPDATE eu_remote.gatetogategroup SET direction = NEW.direction WHERE gateId = NEW.gateId AND gateGroupId = NEW.gateGroupId;
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region for gateGroupId: %', NEW.gateGroupId;
    END IF;
    RETURN NEW;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_gate_and_gatetogategroup_trigger() RETURNS TRIGGER AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = (SELECT buildingId FROM us_remote.gategroup WHERE gateGroupId = OLD.gateGroupId);

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = (SELECT buildingId FROM eu_remote.gategroup WHERE gateGroupId = OLD.gateGroupId);
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US'::region THEN
            -- Delete GateToGateGroup in the US remote schema
            DELETE FROM us_remote.gatetogategroup WHERE gateId = OLD.gateId AND gateGroupId = OLD.gateGroupId;
        ELSIF building_region = 'EU'::region THEN
            -- Delete GateToGateGroup in the EU remote schema
            DELETE FROM eu_remote.gatetogategroup WHERE gateId = OLD.gateId AND gateGroupId = OLD.gateGroupId;
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region for gateGroupId: %', OLD.gateGroupId;
    END IF;
    RETURN OLD;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_gate_and_gatetogategroup
INSTEAD OF INSERT ON distributed.gate_and_gatetogategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_gate_and_gatetogategroup_trigger();

CREATE TRIGGER instead_of_update_gate_and_gatetogategroup
INSTEAD OF UPDATE ON distributed.gate_and_gatetogategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.update_gate_and_gatetogategroup_trigger();

CREATE TRIGGER instead_of_delete_gate_and_gatetogategroup
INSTEAD OF DELETE ON distributed.gate_and_gatetogategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_gate_and_gatetogategroup_trigger();

-- Access Right

CREATE OR REPLACE VIEW distributed.accessright_view AS
    SELECT gateGroupId, badgeId, expirationDate
    FROM us_remote.accessright
UNION ALL
    SELECT gateGroupId, badgeId, expirationDate
    FROM eu_remote.accessright;

CREATE OR REPLACE FUNCTION distributed.insert_accessright() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = NEW.badgeId;

    IF person_region = 'US'::region THEN
        INSERT INTO us_remote.accessright (gateGroupId, badgeId, expirationDate) VALUES (NEW.gateGroupId, NEW.badgeId, NEW.expirationDate);
    ELSIF person_region = 'EU'::region THEN
        INSERT INTO eu_remote.accessright (gateGroupId, badgeId, expirationDate) VALUES (NEW.gateGroupId, NEW.badgeId, NEW.expirationDate);
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', NEW.badgeId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_accessright() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = NEW.badgeId;

    IF person_region = 'US'::region THEN
        UPDATE us_remote.accessright SET expirationDate = NEW.expirationDate WHERE gateGroupId = NEW.gateGroupId AND badgeId = NEW.badgeId;
    ELSIF person_region = 'EU'::region THEN
        UPDATE eu_remote.accessright SET expirationDate = NEW.expirationDate WHERE gateGroupId = NEW.gateGroupId AND badgeId = NEW.badgeId;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', NEW.badgeId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_accessright() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = OLD.badgeId;

    IF person_region = 'US'::region THEN
        DELETE FROM us_remote.accessright WHERE gateGroupId = OLD.gateGroupId AND badgeId = OLD.badgeId;
    ELSIF person_region = 'EU'::region THEN
        DELETE FROM eu_remote.accessright WHERE gateGroupId = OLD.gateGroupId AND badgeId = OLD.badgeId;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', OLD.badgeId;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_accessright
INSTEAD OF INSERT ON distributed.accessright_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_accessright();

CREATE TRIGGER instead_of_update_accessright
INSTEAD OF UPDATE ON distributed.accessright_view
FOR EACH ROW
EXECUTE FUNCTION distributed.update_accessright();

CREATE TRIGGER instead_of_delete_accessright
INSTEAD OF DELETE ON distributed.accessright_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_accessright();

-- Access Log

CREATE OR REPLACE VIEW distributed.accesslog_view AS
    SELECT accesslogid, gateId, badgeId, accessTime
    FROM us_remote.accesslog
UNION ALL
    SELECT accesslogid, gateId, badgeId, accessTime
    FROM eu_remote.accesslog;

CREATE OR REPLACE FUNCTION distributed.insert_accesslog() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = NEW.badgeId;

    IF person_region = 'US'::region THEN
        INSERT INTO us_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
        VALUES (NEW.accesslogid, NEW.gateId, NEW.badgeId, NEW.accessTime, NEW.success);
    ELSIF person_region = 'EU'::region THEN
        INSERT INTO eu_remote.accesslog (accesslogid, gateId, badgeId, accessTime, success)
        VALUES (NEW.accesslogid, NEW.gateId, NEW.badgeId, NEW.accessTime, NEW.success);
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', NEW.badgeId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_accesslog() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = OLD.badgeId;

    IF person_region = 'US'::region THEN
        DELETE FROM us_remote.accesslog WHERE gateId = OLD.gateId AND badgeId = OLD.badgeId;
    ELSIF person_region = 'EU'::region THEN
        DELETE FROM eu_remote.accesslog WHERE gateId = OLD.gateId AND badgeId = OLD.badgeId;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', OLD.badgeId;
    END IF;
    RETURN OLD;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_accesslog
INSTEAD OF INSERT ON distributed.accesslog_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_accesslog();

CREATE TRIGGER instead_of_delete_accesslog
INSTEAD OF DELETE ON distributed.accesslog_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_accesslog();

-- Presence Log

CREATE OR REPLACE VIEW distributed.presencelog_view AS
    SELECT presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime
    FROM us_remote.presencelog
UNION ALL
    SELECT presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime
    FROM eu_remote.presencelog;

CREATE OR REPLACE FUNCTION distributed.insert_presencelog() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = NEW.badgeId;

    IF person_region = 'US'::region THEN
        INSERT INTO us_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime)
        VALUES (NEW.presencelogid, NEW.badgeid, NEW.entranceaccesslogid, NEW.exitaccesslogid, NEW.gategroupid, NEW.elapsedtime);
    ELSIF person_region = 'EU'::region THEN
        INSERT INTO eu_remote.presencelog (presencelogid, badgeid, entranceaccesslogid, exitaccesslogid, gategroupid, elapsedtime)
        VALUES (NEW.presencelogid, NEW.badgeid, NEW.entranceaccesslogid, NEW.exitaccesslogid, NEW.gategroupid, NEW.elapsedtime);
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', NEW.badgeId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.update_presencelog() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = NEW.badgeId;

    IF person_region = 'US'::region THEN
        UPDATE us_remote.presencelog
        SET entranceaccesslogid = NEW.entranceaccesslogid, exitaccesslogid = NEW.exitaccesslogid, gategroupid = NEW.gategroupid, elapsedtime = NEW.elapsedtime
        WHERE presencelogid = NEW.presencelogid;
    ELSIF person_region = 'EU'::region THEN
        UPDATE eu_remote.presencelog
        SET entranceaccesslogid = NEW.entranceaccesslogid, exitaccesslogid = NEW.exitaccesslogid, gategroupid = NEW.gategroupid, elapsedtime = NEW.elapsedtime
        WHERE presencelogid = NEW.presencelogid;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', NEW.badgeId;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_presencelog() RETURNS TRIGGER AS $$
DECLARE
    person_region Region;
BEGIN
    -- Get the person's region
    SELECT region INTO person_region FROM distributed.person_view WHERE badgeId = OLD.badgeId;

    IF person_region = 'US'::region THEN
        DELETE FROM us_remote.presencelog WHERE presencelogid = OLD.presencelogid;
    ELSIF person_region = 'EU'::region THEN
        DELETE FROM eu_remote.presencelog WHERE presencelogid = OLD.presencelogid;
    ELSE
        RAISE EXCEPTION 'Person not found or invalid region: %', OLD.badgeId;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_presencelog
INSTEAD OF INSERT ON distributed.presencelog_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_presencelog();

CREATE TRIGGER instead_of_update_presencelog
INSTEAD OF UPDATE ON distributed.presencelog_view
FOR EACH ROW
EXECUTE FUNCTION distributed.update_presencelog();

CREATE TRIGGER instead_of_delete_presencelog
INSTEAD OF DELETE ON distributed.presencelog_view
FOR EACH ROW
EXECUTE FUNCTION distributed.delete_presencelog();

-- Extra functions for the business logic

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