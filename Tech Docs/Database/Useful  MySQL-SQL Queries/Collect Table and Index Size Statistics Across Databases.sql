/*
-----------------------------------------------------------------------------------
Script: Collect Table and Index Size Statistics Across Databases
Technology: T-SQL (Dynamic SQL + DMVs)

Purpose:
- Collects size and usage statistics for all tables and indexes across databases.
- Stores results in custom snapshot tables (`maint.tTableSizes`, `maint.tIndexSizes`).

Features:
- Gathers details like:
   * Row count
   * Total, used, and unused pages
   * Space (MB) used and free
   * Table and index creation/last modified dates
- Differentiates between:
   * HEAP tables
   * CLUSTERED indexes
   * NONCLUSTERED indexes
- Inserts summarized results into central monitoring tables.

Use Cases:
- Monitor database growth over time.
- Identify large tables and indexes consuming space.
- Support capacity planning and performance optimization.

Notes:
- Run this script in the SQL Server Management Studio (SSMS).
- Uses `sp_msforeachdb` to iterate databases (limited to 2000 chars).
- Requires the `[maint].[tTableSizes]` and `[maint].[tIndexSizes]` tables 
  to exist beforehand for capturing snapshots.
-----------------------------------------------------------------------------------
*/

BEGIN
    SET NOCOUNT ON;

    -- Cleanup temp tables if they already exist
    DROP TABLE IF EXISTS #AllTablesIndexes;
    DROP TABLE IF EXISTS #AllTables;
    DROP TABLE IF EXISTS #AllIndexes;

    -- Parameters (customize these before running)
    DECLARE @DatabaseName sysname = 'DWH';    -- Target database
    DECLARE @TableName sysname = '';          -- Specific table name (optional)
    DECLARE @SchemaName sysname = '';         -- Specific schema (optional)
    DECLARE @TableMatch AS bit = 0;           -- 0 = partial match, 1 = exact match

    -- Adjust table matching
    IF @TableMatch = 0
    BEGIN
        SET @TableName = CONCAT(N'%', @TableName, N'%');
    END;

    -- Wrapping parameters in quotes for dynamic SQL
    DECLARE @NewDatabaseName sysname = CONCAT('''', @DatabaseName, '''');
    DECLARE @NewTableName sysname = CONCAT('''', @TableName, '''');
    DECLARE @NewSchemaName sysname = CONCAT('''', @SchemaName, '''');

    DECLARE @SQL nvarchar(2000);

    -- Temp table to hold intermediate results
    CREATE TABLE #AllTablesIndexes (
        [DBID] int NOT NULL,
        [DBname] nvarchar(128) NOT NULL,
        [TableName] nvarchar(128) NOT NULL,
        [TableID] int NOT NULL,
        [FullTableName] nvarchar(386) NOT NULL,
        [IndexName] nvarchar(128),
        [IndexType] nvarchar(60) NOT NULL,
        [IndexSubType] nvarchar(60) NOT NULL,
        [Rows] bigint NOT NULL,
        [TotalPages] bigint NOT NULL,
        [UsedPages] bigint NOT NULL,
        [UnusedPages] bigint NOT NULL,
        [CreateDateTime] datetime2(3),
        [ModifyDateTime] datetime2(3)
    );

    -- Dynamic SQL to collect table + index stats per database
    SET @SQL = CONCAT(
    'USE [?];
    SELECT
        DB_ID (DB_NAME()) AS [DBID],
        DB_NAME() AS [DBname],
        t.[name] AS [TableName],
        t.[object_id] AS [TableID],
        CONCAT(N''['',DB_NAME(),N''].'', N''['', s.[name], N''].'', N''['', t.[name], N'']'') AS [FullTableName],
        i.[name] AS IndexName,
        CASE
            WHEN i.index_id = 0 THEN ''HEAP''
            WHEN i.index_id = 1 THEN ''CLUSTERED''
            WHEN i.index_id > 1 THEN ''NONCLUSTERED''
        END AS [IndexType],
        CASE
            WHEN i.type = 0 THEN ''HEAP''
            WHEN i.type = 1 THEN ''ROWSTORE''
            WHEN i.type = 2 THEN ''ROWSTORE''
            WHEN i.type = 3 THEN ''XML''
            WHEN i.type = 4 THEN ''Spatial''
            WHEN i.type = 5 THEN ''COLUMNSTORE''
            WHEN i.type = 6 THEN ''COLUMNSTORE''
            WHEN i.type = 7 THEN ''HASH''
        END AS [IndexSubType],
        p.[Rows],
        SUM(a.total_pages) AS TotalPages,
        SUM(a.used_pages) AS UsedPages,
        SUM(a.total_pages) - SUM(a.used_pages) AS UnusedPages,
        t.create_date AS CreateDate,
        t.modify_date AS ModifyDate
    FROM sys.tables AS t WITH(NOLOCK)
    INNER JOIN sys.schemas AS s WITH(NOLOCK) ON t.schema_id = s.schema_id
    INNER JOIN sys.indexes AS i WITH(NOLOCK) ON t.object_id = i.object_id
    INNER JOIN sys.partitions AS p WITH(NOLOCK) ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units AS a WITH(NOLOCK) ON p.partition_id = a.container_id
    WHERE 1=1
        AND (ISNULL(', @NewDatabaseName, ', '''') = '''' OR DB_NAME() = ', @NewDatabaseName, ')
        AND (ISNULL(', @NewTableName, ', '''') = '''' OR t.[Name] LIKE ', @NewTableName, ')
        AND (ISNULL(', @NewSchemaName, ', '''') = '''' OR s.[Name] LIKE ', @NewSchemaName, ')
    GROUP BY
        t.[name],
        t.[object_id],
        CONCAT(N''['',DB_NAME(),N''].'', N''['', s.[name], N''].'', N''['', t.[name], N'']''),
        i.[name],
        i.index_id,
        i.type,
        p.[Rows],
        t.create_date,
        t.modify_date'
    );

    -- Execute dynamic SQL across all DBs
    INSERT INTO #AllTablesIndexes
    EXEC sp_msforeachdb @SQL;

    -----------------------------------------------------------------------------------
    -- Summarize by tables (HEAP + CLUSTERED)
    -----------------------------------------------------------------------------------
    SELECT
        [DBID], [DBname], [TableName], [TableID], [FullTableName],
        [IndexName], [IndexType], [IndexSubType],
        SUM([rows]) AS [RowCount],
        SUM(TotalPages) AS [TotalPages],
        SUM(UsedPages) AS [UsedPages],
        SUM(TotalPages) - SUM(UsedPages) AS [UnusedPages],
        CAST((SUM(TotalPages) * 8) / 1024.00 as decimal(18,0)) AS [TotalSpace_MB],
        CAST((SUM(UsedPages) * 8) / 1024.00 as decimal(18,0)) AS [UsedSpace_MB],
        CAST((SUM(TotalPages) * 8) / 1024.00 as decimal(18,0)) - 
        CAST((SUM(UsedPages) * 8) / 1024.00 as decimal(18,0)) AS [UnusedSpace_MB],
        [CreateDateTime], [ModifyDateTime]
    INTO #AllTables
    FROM #AllTablesIndexes
    WHERE [IndexType] IN ('HEAP', 'CLUSTERED') -- Only table structures
    GROUP BY [DBID], [DBname], [TableName], [TableID], [FullTableName],
             [IndexName], [IndexType], [IndexSubType], [CreateDateTime], [ModifyDateTime];

    -----------------------------------------------------------------------------------
    -- Summarize by indexes (NONCLUSTERED + CLUSTERED)
    -----------------------------------------------------------------------------------
    SELECT
        [DBID], [DBname], [TableName], [TableID], [FullTableName],
        [IndexName], [IndexType], [IndexSubType],
        SUM([rows]) AS [RowCount],
        SUM(TotalPages) AS [TotalPages],
        SUM(UsedPages) AS [UsedPages],
        SUM(TotalPages) - SUM(UsedPages) AS [UnusedPages],
        CAST((SUM(TotalPages) * 8) / 1024.00 as decimal(18,0)) AS [TotalSpace_MB],
        CAST((SUM(UsedPages) * 8) / 1024.00 as decimal(18,0)) AS [UsedSpace_MB],
        CAST((SUM(TotalPages) * 8) / 1024.00 as decimal(18,0)) - 
        CAST((SUM(UsedPages) * 8) / 1024.00 as decimal(18,0)) AS [UnusedSpace_MB],
        [CreateDateTime], [ModifyDateTime]
    INTO #AllIndexes
    FROM #AllTablesIndexes
    WHERE [IndexType] IN ('NONCLUSTERED', 'CLUSTERED') -- Only indexes
    GROUP BY [DBID], [DBname], [TableName], [TableID], [FullTableName],
             [IndexName], [IndexType], [IndexSubType], [CreateDateTime], [ModifyDateTime];

    -----------------------------------------------------------------------------------
    -- Insert snapshots into monitoring tables
    -----------------------------------------------------------------------------------

    -- Table sizes
    INSERT INTO [maint].[tTableSizes]
    SELECT
        'TblStats' AS TableStats,
        [DBname], [TableName], [FullTableName],
        [IndexType], [IndexSubType],
        [RowCount], [TotalPages], [UsedPages], [UnusedPages],
        [TotalSpace_MB], [UsedSpace_MB], [UnusedSpace_MB],
        CAST(GETDATE() AS date) AS SnapshotDate
    FROM #AllTables
    ORDER BY TotalSpace_MB DESC;

    -- Index sizes (only NONCLUSTERED)
    INSERT INTO [maint].[tIndexSizes]
    SELECT
        'IndexStats' AS IndexStats,
        [DBname], [FullTableName], [IndexName],
        [IndexType], [IndexSubType],
        [RowCount], [TotalPages], [UsedPages], [UnusedPages],
        [TotalSpace_MB], [UsedSpace_MB], [UnusedSpace_MB],
        CAST(GETDATE() AS date) AS SnapshotDate
    FROM #AllIndexes
    WHERE [IndexType] IN ('NONCLUSTERED')
    ORDER BY TotalSpace_MB DESC;
END
