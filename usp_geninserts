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
--			INSERT INTO @tmp_Tables 
--			VALUES ('t_order', 'dbo', 'order_number =''881055921'' '), 
--				   ('t_order_detail', 'dbo', 'order_number =''881055921'' ')
--      
--    TARGET: 
--        SQL Server
--
--    HISTORY:
--		 <1.0 -			   - Sandy Watkins - Inital Logic design
--        1.0 - 2023/03/31 - Derek Shaheen - Optimization, sprocified.
--
--    Example Calls
--        EXEC usp_geninserts 't_order', 'dbo', 'order_number =''881055921'' ';
--        EXEC usp_geninserts 't_order_detail', 'dbo', 'order_number =''881055921'' ';
-------------------------------------------------------------------------------

CREATE PROCEDURE usp_geninserts
    @TableName SYSNAME, 
    @SchemaName SYSNAME, 
    @Condition VARCHAR(500)
AS
BEGIN
    DECLARE @ColumnList VARCHAR(max) = '', 
            @InsertList VARCHAR(max) = '', 
            @SQL varchar(max), 
            @WhereSQL varchar(max);

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

    SELECT 
        @WhereSQL = CASE WHEN LTRIM(RTRIM(@Condition)) <> '' THEN ' WHERE ' + @Condition ELSE '' END,
        @ColumnList = SUBSTRING(@ColumnList, 1, LEN(@ColumnList)-1),
        @InsertList = SUBSTRING(@InsertList, 1, LEN(@InsertList)-4) + '''',
        @SQL = 'SELECT ''INSERT INTO ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + char(10)+ '(' + @ColumnList + ')'' + char(10)+  ''SELECT '' + ' + @InsertList + ' FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + @WhereSQL;

    EXEC(@SQL);
END;
GO
