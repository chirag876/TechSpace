-- Works in SQL Server

SELECT 
   f.name AS 'Name of Foreign Key',
   OBJECT_NAME(f.parent_object_id) AS 'Table name',
   COL_NAME(fc.parent_object_id,fc.parent_column_id) AS 'Fieldname',
   OBJECT_NAME(t.object_id) AS 'References Table name',
   COL_NAME(t.object_id,fc.referenced_column_id) AS 'References fieldname',

   'ALTER TABLE [' + OBJECT_NAME(f.parent_object_id) + ']  DROP CONSTRAINT [' + f.name + ']' AS 'Delete foreign key',

   'ALTER TABLE [' + OBJECT_NAME(f.parent_object_id) + ']  WITH NOCHECK ADD CONSTRAINT [' + 
        f.name + '] FOREIGN KEY([' + COL_NAME(fc.parent_object_id,fc.parent_column_id) + ']) REFERENCES ' + 
        '[' + OBJECT_NAME(t.object_id) + '] ([' +
        COL_NAME(t.object_id,fc.referenced_column_id) + '])' AS 'Create foreign key'
    -- , delete_referential_action_desc AS 'UsesCascadeDelete'
FROM sys.foreign_keys AS f,
     sys.foreign_key_columns AS fc,
     sys.tables t 


WHERE f.OBJECT_ID = fc.constraint_object_id
AND t.OBJECT_ID = fc.referenced_object_id
AND OBJECT_NAME(t.object_id)  LIKE 'PositionCategory%'      --  Just show the FKs which reference a particular table
ORDER BY 2