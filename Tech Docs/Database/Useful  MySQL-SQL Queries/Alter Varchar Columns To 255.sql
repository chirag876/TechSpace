------------------------------------------------------------- Works in SQL Server
-- Declare a variable to hold the dynamic SQL statement
DECLARE @sql NVARCHAR(MAX) = N'';

-- Build the dynamic SQL by concatenating ALTER TABLE statements for each varchar column
SELECT @sql = @sql + N'
ALTER TABLE [dbo].[Ticket] 
ALTER COLUMN ' + QUOTENAME(c.name) + ' VARCHAR(255) ' +

-- Check whether the column allows NULLs or not, and add the appropriate clause
CASE 
    WHEN c.is_nullable = 1 THEN 'NULL'   -- If the column is nullable, append 'NULL'
    ELSE 'NOT NULL'                      -- If the column is not nullable, append 'NOT NULL'
END + ';'

-- Retrieve the column metadata from sys.columns and sys.types system views
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id

-- Filter to only include columns from the 'Ticket' table with a varchar data type
WHERE c.object_id = OBJECT_ID('dbo.Ticket')
AND t.name = 'varchar'

-- Filter out columns that already have a length of 255, to avoid unnecessary changes
AND c.max_length <> 255;

-- Execute the dynamically generated SQL statement
EXEC sp_executesql @sql;