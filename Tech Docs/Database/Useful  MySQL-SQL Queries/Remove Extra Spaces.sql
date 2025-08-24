-- Works SQL Server and MySQL
UPDATE TableName
SET
    ColName = LTRIM (RTRIM (ColName)), -- Trims both leading and trailing spaces
    ColName = LTRIM (ColName), -- Trims only leading spaces
    ColName = RTRIM (ColName); -- Trims only trailing spaces

