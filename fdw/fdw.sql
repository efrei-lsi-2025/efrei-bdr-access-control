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

-- TODO: GDPR

CREATE OR REPLACE FUNCTION distributed.insert_person() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.region = 'US' THEN
        INSERT INTO us_remote.person (badgeId, name, region) VALUES (NEW.badgeId, NEW.name, NEW.region::region);
    ELSIF NEW.region = 'EU' THEN
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

    IF NEW.region = 'US' THEN
        UPDATE us_remote.person SET name = NEW.name WHERE badgeId = NEW.badgeId;
    ELSIF NEW.region = 'EU' THEN
        UPDATE eu_remote.person SET name = NEW.name WHERE badgeId = NEW.badgeId;
    ELSE
        RAISE EXCEPTION 'Invalid region: %', NEW.region;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.delete_person() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.region = 'US' THEN
        DELETE FROM us_remote.person WHERE badgeId = OLD.badgeId;
    ELSIF OLD.region = 'EU' THEN
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
    IF NEW.region = 'US' THEN
        INSERT INTO us_remote.building (buildingId, name, address, region) VALUES (NEW.buildingId, NEW.name, NEW.address, NEW.region::Region);
    ELSIF NEW.region = 'EU' THEN
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

    IF OLD.region = 'US' THEN
        UPDATE us_remote.building
        SET name = NEW.name, address = NEW.address, region = NEW.region::Region
        WHERE buildingId = OLD.buildingId;
    ELSIF OLD.region = 'EU' THEN
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
    IF OLD.region = 'US' THEN
        DELETE FROM us_remote.building WHERE buildingId = OLD.buildingId;
    ELSIF OLD.region = 'EU' THEN
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
        IF building_region = 'US' THEN
            INSERT INTO us_remote.gategroup (gateGroupId, name, buildingId) VALUES (NEW.gateGroupId, NEW.name, NEW.buildingId);
        ELSIF building_region = 'EU' THEN
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
        IF old_building_region = 'US' THEN
            UPDATE us_remote.gategroup SET name = NEW.name, buildingId = NEW.buildingId WHERE gateGroupId = OLD.gateGroupId;
        ELSIF old_building_region = 'EU' THEN
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
        IF building_region = 'US' THEN
            DELETE FROM us_remote.gategroup WHERE gateGroupId = OLD.gateGroupId;
        ELSIF building_region = 'EU' THEN
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

CREATE OR REPLACE FUNCTION distributed.create_gate_and_gatetogategroup(
    p_gateId UUID,
    p_gateGroupId UUID,
    p_direction BOOLEAN
) RETURNS VOID AS $$
DECLARE
    building_region Region;
BEGIN
    -- Find the region of the associated building in the US remote schema
    SELECT region INTO building_region
    FROM us_remote.building
    WHERE buildingId = (SELECT buildingId FROM us_remote.gategroup WHERE gateGroupId = p_gateGroupId);

    -- If not found in the US remote schema, check the EU remote schema
    IF building_region IS NULL THEN
        SELECT region INTO building_region
        FROM eu_remote.building
        WHERE buildingId = (SELECT buildingId FROM eu_remote.gategroup WHERE gateGroupId = p_gateGroupId);
    END IF;

    IF building_region IS NOT NULL THEN
        IF building_region = 'US' THEN
            -- Insert gate in the US remote schema
            INSERT INTO us_remote.gate (gateId) VALUES (p_gateId);

            -- Insert GateToGateGroup in the US remote schema
            INSERT INTO us_remote.gatetogategroup (gateToGateGroupId, gateId, gateGroupId, direction)
            VALUES (gen_random_uuid(), p_gateId, p_gateGroupId, p_direction);

        ELSIF building_region = 'EU' THEN
            -- Insert gate in the EU remote schema
            INSERT INTO eu_remote.gate (gateId) VALUES (p_gateId);

            -- Insert GateToGateGroup in the EU remote schema
            INSERT INTO eu_remote.gatetogategroup (gateToGateGroupId, gateId, gateGroupId, direction)
            VALUES (gen_random_uuid(), p_gateId, p_gateGroupId, p_direction);
        END IF;
    ELSE
        RAISE EXCEPTION 'Building not found or invalid region for gateGroupId: %', gateGroupId;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION distributed.insert_gate_and_gatetogategroup_trigger() RETURNS TRIGGER AS $$
BEGIN
    PERFORM distributed.create_gate_and_gatetogategroup(NEW.gateId, NEW.gateGroupId, NEW.direction);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_insert_gate_and_gatetogategroup
INSTEAD OF INSERT ON distributed.gate_and_gatetogategroup_view
FOR EACH ROW
EXECUTE FUNCTION distributed.insert_gate_and_gatetogategroup_trigger();