create extension if not exists pg_cron;

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

SELECT unschedule_job('delete_old_access_logs_job');
SELECT unschedule_job('delete_old_presence_logs_job');

-- Delete access logs older than 3 months
-- This procedure will be called every day at midnight
create or replace procedure delete_old_access_logs() as $$
begin
    -- Each cluster executes the delete operation on its own data
    DELETE FROM accesslog WHERE accessTime < now() - interval '3 months';
end;
$$ language plpgsql;

select *
    from cron.schedule(
        'delete_old_access_logs_job',
        '0 0 * * *',
        $$CALL delete_old_access_logs();$$
    );

-- Delete presence logs older than 5 years
-- This procedure will be called every day at midnight
create or replace procedure delete_old_presence_logs() as $$
begin
    -- Each cluster executes the delete operation on its own data
    DELETE FROM presencelog WHERE presenceTime < now() - interval '5 years';
end;
$$ language plpgsql;

select *
    from cron.schedule(
        'delete_old_presence_logs_job',
        '0 0 * * *',
        $$CALL delete_old_presence_logs();$$
    );

-- select * from cron.job;
-- select * from cron.job_run_details order by end_time desc limit 5;