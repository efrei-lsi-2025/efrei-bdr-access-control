SELECT create_reference_table('building');
SELECT create_reference_table('gate');
SELECT create_reference_table('gategroup');
SELECT create_reference_table('gatetogategroup');

SELECT create_distributed_table('person', 'badgeid');
SELECT create_distributed_table('accessright', 'badgeid', colocate_with => 'person');

SELECT create_distributed_table('accesslog', 'accesslogid');
SELECT create_distributed_table('presencelog', 'presencelogid');