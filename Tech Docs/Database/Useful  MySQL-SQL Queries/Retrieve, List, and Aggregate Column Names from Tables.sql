---------- Works in SQL Server

SELECT STRING_AGG(name, ', ') AS columns
FROM sys.columns
WHERE object_id = OBJECT_ID('Contact');

-----------------------------------------------------------
SELECT name 
FROM sys.columns
WHERE object_id = OBJECT_ID('Lead')
ORDER BY name;

-----------------------------------------------------------
SELECT STRING_AGG('""' + name + '""', ', ') AS columns
FROM sys.columns
WHERE object_id = OBJECT_ID('Opportunity');