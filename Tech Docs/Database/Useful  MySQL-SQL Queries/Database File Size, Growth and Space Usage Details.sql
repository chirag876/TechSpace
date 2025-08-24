/*
===================================================================================
Script Title: Modern Database File Size, Growth and Space Usage Details
===================================================================================

Script: Returns details about database data/log files
Technology: T-SQL (System Catalog Views)

Purpose:
- Shows file names, type (Data/Log), size, growth setting, 
used space, and free space for the specified database.
- Works on all modern SQL Server versions (2005+).

Features:
- Uses sys.database_files (current DB) and sys.master_files (for all DBs).
- Displays:
• File Name
• File Path
• File Type (Data / Log)
• File Size (MB)
• Space Used (MB)
• Free Space (MB)
• Growth Increment (MB or %)

How to Use:
- Replace `DB_Name` with the target database name.
- Run in SQL Server Management Studio (SSMS).
- Example:
USE DB_Name;   -- Mention database name to get the details
GO

Use Cases:
- Modern replacement of sysfiles query.
- Works reliably across SQL Server versions.
- Helps with monitoring, performance tuning, and space planning.
-----------------------------------------------------------------------------------
 */
USE DB_Name; -- Replace with your database name


GO
SELECT
    df.name AS FileName,
    df.physical_name AS FilePath,
    df.type_desc AS FileType, -- ROWS = Data File, LOG = Log File
    CONVERT(decimal(12, 2), df.size / 128.0) AS FileSize_MB,
    CONVERT(
        decimal(12, 2),
        FILEPROPERTY (df.name, 'SpaceUsed') / 128.0
    ) AS SpaceUsed_MB,
    CONVERT(
        decimal(12, 2),
        (df.size - FILEPROPERTY (df.name, 'SpaceUsed')) / 128.0
    ) AS FreeSpace_MB,
    CASE df.is_percent_growth
        WHEN 1 THEN CAST(df.growth AS VARCHAR(10)) + ' %'
        ELSE CAST(df.growth / 128 AS VARCHAR(10)) + ' MB'
    END AS GrowthSetting
FROM
    sys.database_files df;