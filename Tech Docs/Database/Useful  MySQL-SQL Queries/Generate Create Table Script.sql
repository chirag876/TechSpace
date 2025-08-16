--------------- Works in SQL Server

DECLARE @TableName NVARCHAR(MAX) = 'StaffPosition';
DECLARE @SQL NVARCHAR(MAX) = '';

-- Table metadata
SELECT @SQL = 'CREATE TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) + '(' + CHAR(13) + CHAR(10)
FROM sys.tables t
WHERE t.name = @TableName;

-- Column definitions
SELECT @SQL = @SQL + '    ' + QUOTENAME(c.name) + ' ' +
              TYPE_NAME(c.user_type_id) +
              CASE WHEN c.is_nullable = 0 THEN ' NOT NULL' ELSE ' NULL' END +
              CASE WHEN c.is_identity = 1 THEN ' IDENTITY(' + CAST(ic.seed_value AS NVARCHAR) + ',' + CAST(ic.increment_value AS NVARCHAR) + ')' ELSE '' END +
              ',' + CHAR(13) + CHAR(10)
FROM sys.columns c
LEFT JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE c.object_id = OBJECT_ID(@TableName)
ORDER BY c.column_id;

-- Remove the last comma
SET @SQL = LEFT(@SQL, LEN(@SQL) - 3) + CHAR(13) + CHAR(10);

-- Add constraints
SELECT @SQL = @SQL + CASE
            WHEN i.type = 1 THEN '    CONSTRAINT ' + QUOTENAME(i.name) + ' PRIMARY KEY (' +
                                STRING_AGG(QUOTENAME(c.name), ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) + '),' + CHAR(13) + CHAR(10)
            ELSE ''
         END
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID(@TableName) AND i.is_primary_key = 1
GROUP BY i.name, i.type;

-- Finalize script
SET @SQL = @SQL + ');';

-- Output the result
PRINT @SQL;