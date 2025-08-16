---------------- Works in SQL Server

SELECT 
    t.NAME AS TableName,
    p.rows AS RowCounts,
    SUM(a.total_pages) * 8 / 1024 AS TotalSizeMB
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
GROUP BY t.Name, p.Rows
ORDER BY TotalSizeMB DESC;


---------------- Works in MySQL
SELECT 
    table_name AS TableName,
    table_rows AS RowCounts,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS TotalSizeMB
FROM information_schema.tables
WHERE table_schema = 'billing_alerts_org_local'  -- Apne DB ka naam yahan daalo
ORDER BY TotalSizeMB DESC;