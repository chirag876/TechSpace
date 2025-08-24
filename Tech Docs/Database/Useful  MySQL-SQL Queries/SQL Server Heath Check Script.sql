/*
-----------------------------------------------------------------------------------
 Script: SQL Server Health Check Script
 Technology: T-SQL (SQL Server)

 Purpose:
   - Perform health checks on SQL Server after applying Windows or SQL patches.
   - Run daily health checks to monitor instance, database, storage, and backup status.

 Sections Covered:
   1. Post-Patch Health Checks
      - Server & Instance details (version, edition, service pack).
      - Database status (ONLINE/OFFLINE/etc.).
      - SQL Services status (MSSQL, SQL Agent, SQL Browser).
      - Change Data Capture (CDC) jobs.
      - Always-On availability groups.
      - Replication job activity.

   2. Daily Health Checks
      - Database status & recovery model.
      - Service status (MSSQL, SQL Agent).
      - Space usage (disks, data files, log files).
      - Backup history for Full, Differential, and Transaction Log backups.

 Where to Run:
   - Run this script in **SQL Server Management Studio (SSMS)**.
   - Connect to the **SQL Server instance** you want to check.
   - Execute in a **query window** (database context: master is safe).

 Output:
   - Multiple result sets:
     * Server version and uptime.
     * Database states.
     * SQL Service status.
     * Always-On and replication status.
     * Disk, log, and DB space usage.
     * Backup job history (last run times).

 Use Cases:
   - Post-patch verification (Windows or SQL updates).
   - Daily monitoring checklist.
   - DBA handover checklist.
   - Quick health validation before deployments.

 Notes:
   - Requires appropriate permissions (sysadmin recommended).
   - Uses undocumented commands like `xp_servicecontrol` and `sp_msforeachdb`.
   - May need elevated privileges for log space and system commands.
-----------------------------------------------------------------------------------
*/

-- SERVER & VERSION INFO
SELECT @@SERVERNAME as ServerName,
       @@ServiceName as [InstanceName],
       CASE
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '16.%' THEN 'SQL Server 2022'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '15.%' THEN 'SQL Server 2019'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '14.%' THEN 'SQL Server 2017'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '13.%' THEN 'SQL Server 2016'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '12.%' THEN 'SQL Server 2014'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '11.%' THEN 'SQL Server 2012'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '10.5%' THEN 'SQL Server 2008R2'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '10.0%' THEN 'SQL Server 2008'
            WHEN CONVERT(varchar(100), SERVERPROPERTY(N'ProductVersion')) LIKE '9.0%' THEN 'SQL Server 2005'
            ELSE 'Not Found'
       END AS VersionName,
       SERVERPROPERTY(N'ProductVersion') AS [Number],
       SERVERPROPERTY('ProductLevel') AS SP,
       CAST(SERVERPROPERTY(N'Edition') AS sysname) AS [Edition],
       sqlserver_start_time
FROM sys.dm_os_sys_info;


-----------------------------------------------------------------------------------
-- 1. POST-PATCH HEALTH CHECK
-----------------------------------------------------------------------------------

-- Database Status
SELECT a.name,
       a.state_desc,
       CASE
            WHEN a.state = 0 THEN 'ONLINE'
            WHEN a.state = 1 THEN 'RESTORING'
            WHEN a.state = 2 THEN 'RECOVERING'
            WHEN a.state = 3 THEN 'RECOVERY_PENDING'
            WHEN a.state = 4 THEN 'SUSPECT'
            WHEN a.state = 5 THEN 'EMERGENCY'
            WHEN a.state = 6 THEN 'OFFLINE'
            WHEN a.state = 7 THEN 'COPYING - SQL AZURE'
            WHEN a.state = 10 THEN 'OFFLINE_SECONDARY - SQL AZURE'
       END AS StateDetail
FROM sys.databases a
WHERE a.state <> 0;


-- SQL Services Status
DECLARE @ServiceStatus TABLE
(
    ServerName nvarchar(50),
    ServiceName nvarchar(50),
    StatusOfService nvarchar(20),
    StatusAsOn datetime
);

INSERT INTO @ServiceStatus (StatusOfService)
EXEC master..xp_servicecontrol 'QueryState', 'MSSQL';
UPDATE @ServiceStatus
SET ServerName = @@SERVERNAME,
    ServiceName = 'MSSQL Server',
    StatusAsOn = GETDATE()
WHERE ServerName IS NULL;

INSERT INTO @ServiceStatus (StatusOfService)
EXEC master..xp_servicecontrol 'QueryState', 'SQLAgent';
UPDATE @ServiceStatus
SET ServerName = @@SERVERNAME,
    ServiceName = 'SQL Server Agent',
    StatusAsOn = GETDATE()
WHERE ServerName IS NULL;

INSERT INTO @ServiceStatus (StatusOfService)
EXEC master..xp_servicecontrol 'QueryState', 'SQLBrowser';
UPDATE @ServiceStatus
SET ServerName = @@SERVERNAME,
    ServiceName = 'SQL Server Browser',
    StatusAsOn = GETDATE()
WHERE ServerName IS NULL;

SELECT * FROM @ServiceStatus
WHERE StatusOfService = 'Stopped.' AND ServiceName != 'SQL Server Browser';


-- CDC Jobs Check
SELECT name FROM msdb.dbo.sysjobs_view WHERE name LIKE '%cdc.%capture%';


-- Always-On Database Replica States
SELECT database_id,
       synchronization_state_desc,
       synchronization_state,
       synchronization_health,
       synchronization_health_desc
FROM sys.dm_hadr_database_replica_states;


-- Always-On Replica Roles
SELECT RCS.replica_server_name,
       ARS.role_desc
FROM master.sys.availability_groups_cluster AS AGC
INNER JOIN master.sys.dm_hadr_availability_replica_cluster_states AS RCS
       ON RCS.group_id = AGC.group_id
INNER JOIN master.sys.dm_hadr_availability_replica_states AS ARS
       ON ARS.replica_id = RCS.replica_id
INNER JOIN master.sys.availability_group_listeners AS AGL
       ON AGL.group_id = ARS.group_id;


-- Replication Jobs
SELECT activity.start_execution_date,
       job.name,
       category.name AS Job_Category,
       job.originating_server,
       ROW_NUMBER() OVER (ORDER BY job.name) AS RowID
FROM msdb.dbo.sysjobs_view AS job
INNER JOIN msdb.dbo.sysjobactivity AS activity ON job.job_id = activity.job_id
INNER JOIN msdb.dbo.syscategories AS category ON job.category_id = category.category_id
WHERE (activity.start_execution_date >= GETDATE()-2
       AND (activity.stop_execution_date IS NULL)
       AND job.category_id IN (10, 13));


-----------------------------------------------------------------------------------
-- 2. DAILY HEALTH CHECK
-----------------------------------------------------------------------------------

-- Database Status & Recovery
SELECT name,
       DATABASEPROPERTYEX(name, 'Recovery') AS RecoveryModel,
       DATABASEPROPERTYEX(name, 'Status') AS Status
FROM master.dbo.sysdatabases
ORDER BY 1;


-- SQL Services Info
EXEC master.dbo.xp_servicecontrol 'QUERYSTATE', 'MSSQLServer';
EXEC master.dbo.xp_servicecontrol 'QUERYSTATE', 'SQLServerAgent';


-- Drive Space
EXEC xp_fixeddrives;


-- Transaction Log Space
DBCC SQLPERF ('Logspace');


-- Data & Log Space Usage
CREATE TABLE #logsize
(
    Dbname varchar(200),
    dbstatus varchar(50),
    Recovery_Model varchar(40) DEFAULT ('NA'),
    Log_File_Size_MB decimal(20,2) DEFAULT (0),
    log_Space_Used_MB decimal(20,2) DEFAULT (0),
    log_Free_Space_MB decimal(20,2) DEFAULT (0)
);

INSERT INTO #logsize
EXEC sp_msforeachdb
'use [?];
SELECT DB_NAME() AS DbName,
       CONVERT(varchar(20),DatabasePropertyEx(''?'',''Status'')),
       CONVERT(varchar(20),DatabasePropertyEx(''?'',''Recovery'')),
       SUM(size)/128.0 AS Log_File_Size_MB,
       SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT))/128.0 AS log_Space_Used_MB,
       SUM(size)/128.0 - SUM(CAST(FILEPROPERTY(name,''SpaceUsed'')) AS INT)/128.0 AS log_Free_Space_MB
FROM sysfiles WHERE groupid=0
GROUP BY groupid';

CREATE TABLE #dbsize
(
    Dbname varchar(200),
    file_Size_MB decimal(20,2) DEFAULT (0),
    Space_Used_MB decimal(20,2) DEFAULT (0),
    Free_Space_MB decimal(20,2) DEFAULT (0)
);

INSERT INTO #dbsize
EXEC sp_msforeachdb
'use [?];
SELECT DB_NAME() AS DbName,
       SUM(size)/128.0 AS File_Size_MB,
       SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT))/128.0 AS Space_Used_MB,
       SUM(size)/128.0 - SUM(CAST(FILEPROPERTY(name,''SpaceUsed'')) AS INT)/128.0 AS Free_Space_MB
FROM sysfiles WHERE groupid<>0
GROUP BY groupid';

SELECT d.Dbname,
       l.dbstatus,
       l.recovery_model,
       (d.file_size_mb + l.log_file_size_mb) AS DBsize,
       d.file_Size_MB,
       d.Space_Used_MB,
       d.Free_Space_MB,
       l.Log_File_Size_MB,
       l.log_Space_Used_MB,
       l.log_Free_Space_MB
FROM #dbsize d
JOIN #logsize l ON d.Dbname = l.Dbname;


-- Backup Job History
SET NOCOUNT ON;

DECLARE @server_name AS VARCHAR(30) = @@SERVERNAME;
DECLARE @dypart1 AS VARCHAR(2) = DATEPART(dd,GETDATE());
DECLARE @dypart2 AS VARCHAR(3) = DATENAME(mm,GETDATE());
DECLARE @dypart3 AS VARCHAR(4) = DATEPART(yy,GETDATE());
DECLARE @currentdate AS VARCHAR(10) = @dypart1 + @dypart2 + @dypart3;

PRINT "#####################################################################";
PRINT "# SERVERNAME : " + @server_name + " DATE : " + @currentdate + " #";
PRINT "#####################################################################";
PRINT "DatabaseName   Full   Diff   TranLog";
PRINT "##########################################################################################################################################";

SELECT SUBSTRING(s.name,1,50) AS [DatabaseName],
       b.backup_start_date AS [Full Backup],
       c.backup_start_date AS [Differential Backup],
       d.backup_start_date AS [Transaction Log Backup]
FROM MASTER..sysdatabases s
LEFT OUTER JOIN msdb..backupset b ON s.name = b.database_name
    AND b.backup_start_date = (SELECT MAX(backup_start_date) FROM msdb..backupset WHERE database_name = b.database_name AND TYPE = 'D')
LEFT OUTER JOIN msdb..backupset c ON s.name = c.database_name
    AND c.backup_start_date = (SELECT MAX(backup_start_date) FROM msdb..backupset WHERE database_name = c.database_name AND TYPE = 'I')
LEFT OUTER JOIN msdb..backupset d ON s.name = d.database_name
    AND d.backup_start_date = (SELECT MAX(backup_start_date) FROM msdb..backupset WHERE database_name = d.database_name AND TYPE = 'L')
WHERE s.name <> 'tempdb'
ORDER BY s.name;


-- Alternative Backup History
USE msdb;
GO
SELECT backupset.database_name,
       MAX(CASE WHEN backupset.type = 'D' THEN backupset.backup_finish_date END) AS LastFullBackup,
       MAX(CASE WHEN backupset.type = 'I' THEN backupset.backup_finish_date END) AS LastDifferential,
       MAX(CASE WHEN backupset.type = 'L' THEN backupset.backup_finish_date END) AS LastLog
FROM backupset
GROUP BY backupset.database_name
ORDER BY backupset.database_name DESC;
