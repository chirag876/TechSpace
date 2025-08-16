----------------- Works in SQL Server

DECLARE @sql NVARCHAR(MAX) = '';

-- Generate DROP TABLE statements for tables starting with 'Sales'
SELECT @sql = @sql + 'DROP TABLE ' + QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) + ';' + CHAR(13)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'Sales%';

-- Execute the generated SQL statements
EXEC sp_executesql @sql;