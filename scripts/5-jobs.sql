-- Procedure to delete access logs older than 3 months
-- This procedure will be called every day at midnight
CREATE OR REPLACE PROCEDURE delete_old_access_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM accesslog WHERE accessTime < now() - interval '3 months';
END;
$$ LANGUAGE PLPGSQL;

-- Procedure to delete presence logs older than 5 years
-- This procedure will be called every day at midnight
CREATE OR REPLACE PROCEDURE delete_old_presence_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM presencelog WHERE elapsedtime < now() - interval '5 years';
END;
$$ LANGUAGE PLPGSQL;

-- Procedure to delete Database logs older than one week
-- This procedure will be called every hour
CREATE OR REPLACE PROCEDURE delete_old_database_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM dblogs WHERE operationtime < now() - interval '1 week';
END;
$$ LANGUAGE PLPGSQL;
