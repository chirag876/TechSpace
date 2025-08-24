/*
===================================================================================
Script Title: List Accessible Databases for Current User
===================================================================================

Script: Show all databases the current user has access to
Technology: T-SQL (System Catalog Views)

Purpose:
- Returns only the databases that the connected user can access.
- Helps verify permissions and quickly see accessible databases.

Features:
- Queries sys.databases system view.
- Uses HAS_DBACCESS() function to filter databases.
- Orders the results alphabetically by database name.

Use Cases:
- Check which databases your login can access.
- Validate permissions after role/user changes.
- Useful for multi-tenant or shared SQL Server environments.

Notes:
- Run this on the SQL Server instance in SSMS (any database context).
- Returns only database names, not details about schemas/tables.
-----------------------------------------------------------------------------------
 */
SELECT
    name
FROM
    sys.databases
WHERE
    HAS_DBACCESS (name) = 1
ORDER BY
    name;