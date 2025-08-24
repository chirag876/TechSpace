/*
-----------------------------------------------------------------------------------
Script: Monitor Database Sizes in SQL Server
Technology: T-SQL (System Catalog Views)

Purpose:
- Provides an overview of all databases on the SQL Server instance.
- Displays total allocated size and current status of each database.

Features:
- Shows:
 * Database name
 * Total size (in MB)
 * Database state (e.g., ONLINE, OFFLINE, RESTORING)
- Orders results by size, largest databases first.

Use Cases:
- Monitor space usage across all databases.
- Identify large databases that may require storage planning.
- Check status of databases at a glance.

Notes:
- Run this in the **master** database context using SSMS.
- Size is calculated from `sys.master_files` (includes data + log files).
-----------------------------------------------------------------------------------
 */
 
SELECT
    name AS DatabaseName, -- Name of the database
    SUM(size) * 8 / 1024 AS SizeInMB, -- Total size in MB (1 page = 8 KB)
    state_desc AS Status -- Current status of the database
FROM
    sys.master_files
GROUP BY
    name,
    state_desc
ORDER BY
    SizeInMB DESC; -- Largest databases first
