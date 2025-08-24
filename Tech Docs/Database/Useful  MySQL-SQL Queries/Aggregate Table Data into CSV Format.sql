---------------- Works in SQL Server
SELECT
    STRING_AGG (CAST(ColumnName AS NVARCHAR (MAX)), ', ') AS CSVList
FROM
    TableName;