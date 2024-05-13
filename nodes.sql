-- EU Nodes

SELECT * from citus_add_node('bdr-eu-1.epsilon', 5433);
SELECT * from citus_add_node('bdr-eu-1.epsilon', 5434);
SELECT * from citus_add_node('bdr-eu-1.epsilon', 5435);

-- US Nodes

SELECT * from citus_add_node('bdr-us-1.epsilon', 5433);
SELECT * from citus_add_node('bdr-us-1.epsilon', 5434);
SELECT * from citus_add_node('bdr-us-1.epsilon', 5435);

-- Check nodes

select * from citus_get_active_worker_nodes();