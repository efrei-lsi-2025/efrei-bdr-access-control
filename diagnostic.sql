select * from citus_get_active_worker_nodes();

SET citus.explain_all_tasks = 1;

EXPLAIN
    SELECT * FROM Building;

EXPLAIN ANALYSE
    SELECT * FROM Person;

SELECT * FROM Person;

EXPLAIN
    SELECT * FROM Gate;

EXPLAIN
    SELECT Person.name, GateGroup.name, AccessRight.expirationdate
    FROM AccessRight
    JOIN Person ON AccessRight.badgeid = Person.badgeid
    JOIN GateGroup ON AccessRight.gategroupid = GateGroup.gategroupid;