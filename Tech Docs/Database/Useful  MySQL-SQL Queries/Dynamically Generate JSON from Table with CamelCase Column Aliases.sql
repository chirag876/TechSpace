------------ Works in SQL Server

DECLARE @tableName NVARCHAR(100) = 'Contact'; -- Change your table name here
DECLARE @query NVARCHAR(MAX);

-- Generate column list with camelCase aliases
SELECT @query = STRING_AGG(
    QUOTENAME(COLUMN_NAME) + ' AS ' + QUOTENAME(LOWER(LEFT(COLUMN_NAME, 1)) + SUBSTRING(COLUMN_NAME, 2, LEN(COLUMN_NAME))),
    ', '
)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @tableName;

-- Build the final query
SET @query = 'SELECT ' + @query + ' FROM ' + @tableName + ' FOR JSON AUTO;';

-- Execute the query
EXEC sp_executesql @query;