------------ Works in SQL Server

SELECT t.name AS TableName
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.rows = 0;


------------------- Works in MySQL

SELECT table_name AS TableName
FROM information_schema.tables
WHERE table_schema = 'billing_alerts_org_local'
  AND table_rows = 0;