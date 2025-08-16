-- Works in SQL Server


SELECT 
FROM OPENROWSET(
    BULK 'C:\Path\To\Your\File.csv',  -- Replace with your file path
    FORMAT = 'CSV',
    FIRSTROW = 2,  -- Skip the header row if present
    CODEPAGE = '65001' -- Ensure UTF-8 encoding support
) AS CSVData;

FROM 'C:\Users\Chirag\Downloads\CRM Dummy Data  - Leads[Ani].csv'
WITH (
    FIELDTERMINATOR = ',',  -- Field delimiter
    ROWTERMINATOR = '\n',   -- Row delimiter
    FIRSTROW = 2,           -- Skip the header row
    TABLOCK
);
-------------------------------------------------------------------------------------
DECLARE @FilePath NVARCHAR(500) = 'C:\Path\To\Your\File.csv';

DECLARE @SQLQuery NVARCHAR(MAX) = 
'SELECT  FROM OPENROWSET(
    BULK ''' + @FilePath + ''',
    FORMAT = ''CSV'',
    FIRSTROW = 2
) AS CSVData;';

EXEC sp_executesql @SQLQuery;
-------------------------------------------------------------------------------------
SELECT 
FROM OPENROWSET(
    BULK 'C:\Path\To\Your\File.csv',  -- Replace with actual file path
    FORMAT = 'CSV',
    FIRSTROW = 2
) AS CSVData
WITH (
    Column1 NVARCHAR(255),
    Column2 INT,
    Column3 DATETIME,
    Column4 FLOAT
);