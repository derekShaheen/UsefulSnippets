-------------------------------------------------------------------------------
--    PURPOSE:
--        This SQL is used to generate INSERT SQL statements dynamically for any table. 
--          The generated statements will contain the original data from these tables based on a specific condition. 
--          The code dynamically builds SQL queries and then executes them, which can be useful for generating SQL
--          statements for data migration, backup, or debugging purposes.
--
--    INPUT:
--		  You must insert into @tmp_Tables the table and clause you want to create statements for. 
--		  For example:
--		  INSERT INTO @tmp_Tables  (TableName, Condition) -- , SchemaName)
--		  VALUES ('t_order', 'order_number =''881070921'' '), 
--		      ('t_order_detail', 'order_number =''881070921'' ')
--      
--    TARGET: 
--        SQL Server
--
--    HISTORY:
--		 <1.0 -			   - Sandy Watkins - Inital Logic design
--        1.0 - 2023/03/31 - Derek Shaheen - Optimization
--        1.1 - 2024/03/18 - Derek Shaheen - Modified to prevent loop when providing null condition.
--                                           Modified input parameters to make schemaname optional.
-------------------------------------------------------------------------------

-- Declare a table variable to hold table name, schema name and condition
DECLARE @tmp_Tables TABLE 
(
    TableName SYSNAME,
    Condition VARCHAR(500),
    SchemaName SYSNAME DEFAULT 'dbo'
)

-- Insert the required table details into the table variable
INSERT INTO @tmp_Tables  (TableName, Condition) -- , SchemaName)
VALUES ('t_order', 'order_number =''881070921'' '), 
       ('t_order_detail', 'order_number =''881070921'' ')

-- Declare variables for table name, schema name and condition
DECLARE @TableName SYSNAME, @SchemaName SYSNAME, @Condition VARCHAR(500)

-- Start a loop to iterate over each table
WHILE (SELECT COUNT(*) FROM @tmp_Tables) > 0
BEGIN
    -- Select the first table details from the table variable
    SELECT TOP 1 @TableName = TableName, @SchemaName = SchemaName, @Condition = Condition FROM @tmp_Tables

    -- Declare variables for SQL query strings
    DECLARE @ColumnList VARCHAR(max) = '', 
            @InsertList VARCHAR(max) = '', 
            @SQL varchar(max), 
            @WhereSQL varchar(max);

    -- Build column list and insert list for each non-identity column not of specific types
    SELECT 
        @ColumnList += CASE WHEN st.name NOT IN (
            'timestamp', 'geography', 'geometry', 
            'hierarchyid', 'image', 'binary', 
            'varbinary'
        ) THEN Quotename(sc.name) + ',' ELSE '' END,
        @InsertList += CASE WHEN st.name NOT IN (
            'timestamp', 'geography', 'geometry', 
            'hierarchyid', 'image', 'binary', 
            'varbinary'
        ) THEN '''' + QUOTENAME(sc.name) + '='' + ' + 'CASE WHEN ' + Quotename(sc.name) + ' IS NULL THEN ''NULL'' ELSE  '''''''' +    REPLACE(CONVERT(VARCHAR(MAX),' + Quotename(sc.name) + '),'''''''','''''''''''') + ''''''''  END + ' + ' '','' + ' ELSE '' END
    FROM 
        sys.objects so 
        JOIN sys.columns sc ON so.object_id = sc.object_id 
        JOIN sys.types st ON sc.user_type_id = st.user_type_id AND sc.system_type_id = st.system_type_id 
        JOIN sys.schemas sch ON sch.schema_id = so.schema_id 
    WHERE 
        so.name = @TableName AND sch.name = @SchemaName AND sc.is_identity = 0 
    ORDER BY sc.column_id;

    -- Prepare SQL for WHERE condition, and remove trailing characters from @ColumnList and @InsertList
    SELECT 
        @WhereSQL = CASE WHEN LTRIM(RTRIM(@Condition)) <> '' THEN ' WHERE ' + @Condition ELSE '' END,
        @ColumnList = SUBSTRING(@ColumnList, 1, LEN(@ColumnList)-1),
        @InsertList = SUBSTRING(@InsertList, 1, LEN(@InsertList)-4) + '''',
        @SQL = 'SELECT ''INSERT INTO ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + char(10)+ '(' + @ColumnList + ')'' + char(10)+  ''SELECT '' + ' + @InsertList + ' FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + @WhereSQL;

    -- Execute the prepared SQL statement
    EXEC(@SQL);

    -- Delete the processed table details from the table variable
    DELETE FROM @tmp_Tables WHERE TableName = @TableName AND SchemaName = @SchemaName AND ISNULL(Condition, '') = ISNULL(@Condition, '')
END
