-- Install the pg_cron extension if not already installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function to unschedule a job by name
CREATE OR REPLACE FUNCTION unschedule_job(job_name TEXT) RETURNS VOID AS $$
DECLARE
    job_id int; -- declare a variable with the same type as the column jobid in the table cron.job
BEGIN
    FOR job_id IN (SELECT jobid FROM cron.job WHERE jobname = unschedule_job.job_name)
    LOOP
        PERFORM cron.unschedule(job_id);
    END LOOP;
END;
$$ LANGUAGE PLPGSQL;

-- Unschedule the existing jobs
SELECT unschedule_job('delete_old_access_logs_job');
SELECT unschedule_job('delete_old_presence_logs_job');
SELECT unschedule_job('delete_old_database_logs_job');

-- Procedure to delete access logs older than 3 months
-- This procedure will be called every day at midnight
CREATE OR REPLACE PROCEDURE delete_old_access_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM accesslog WHERE accessTime < now() - interval '3 months';
END;
$$ LANGUAGE PLPGSQL;

-- Schedule the deletion of access logs
SELECT *
FROM cron.schedule(
    'delete_old_access_logs_job',
    '0 0 * * *',
    $$CALL delete_old_access_logs();$$
);

-- Procedure to delete presence logs older than 5 years
-- This procedure will be called every day at midnight
CREATE OR REPLACE PROCEDURE delete_old_presence_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM presencelog WHERE presenceTime < now() - interval '5 years';
END;
$$ LANGUAGE PLPGSQL;

-- Schedule the deletion of presence logs
SELECT *
FROM cron.schedule(
    'delete_old_presence_logs_job',
    '0 0 * * *',
    $$CALL delete_old_presence_logs();$$
);

-- Procedure to delete Database logs older than one week
-- This procedure will be called every hour
CREATE OR REPLACE PROCEDURE delete_old_database_logs() AS $$
BEGIN
    -- Each cluster executes the delete operation on its own data
    DELETE FROM dblogs WHERE operationtime < now() - interval '1 week';
END;
$$ LANGUAGE PLPGSQL;

-- Schedule the deletion of database logs
SELECT *
FROM cron.schedule(
    'delete_old_database_logs_job',
    '0 * * * *',
    $$CALL delete_old_database_logs();$$
);

-- Query to check the scheduled jobs
-- SELECT * FROM cron.job;

-- Query to check the last 5 job run details
-- SELECT * FROM cron.job_run_details ORDER BY end_time DESC LIMIT 5;