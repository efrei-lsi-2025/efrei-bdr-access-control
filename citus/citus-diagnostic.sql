CREATE EXTENSION pg_stat_statements;

SELECT * FROM citus_get_active_worker_nodes();
SELECT * FROM citus_stat_tenants();

SELECT * FROM citus_stat_statement();

SELECT table_name, table_size
  FROM citus_tables;

-- find the used space of each worker
SELECT node_name, node_size
  FROM citus_stat_nodes;

SET citus.stat_tenants_track = "all";

SET citus.explain_all_tasks = 1;

EXPLAIN
    SELECT * FROM Building;

EXPLAIN ANALYSE
    SELECT * FROM Person;

SELECT * FROM Person;

EXPLAIN
    SELECT * FROM Gate;

SELECT COUNT(*) FROM Person;

EXPLAIN
    SELECT Person.name, GateGroup.name, AccessRight.expirationdate
    FROM AccessRight
    JOIN Person ON AccessRight.badgeid = Person.badgeid
    JOIN GateGroup ON AccessRight.gategroupid = GateGroup.gategroupid;