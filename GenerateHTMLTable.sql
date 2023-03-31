DROP PROCEDURE IF EXISTS dbo.GenerateHTMLTable
GO

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--    PURPOSE:
--
--        This stored procedure generates an HTML table containing the names and values of up to 8 variables.
--        The table can have a variable number of columns based on the @NumColumns parameter.
--        The table will only display rows with non-null variable values.
--        Each table cell has 1px padding and centered text.
--
--    INPUT:
--        @BatchSize		- Number of rows to purge in each batch
--        @TableName		- Table to purge
--      
--    TARGET: 
--        SQL Server
--
--    HISTORY:
--        1.0 - 2023/03/31 - Derek Shaheen - Initial version
-------------------------------------------------------------------------------

CREATE PROCEDURE dbo.GenerateHTMLTable
    @VarName1 NVARCHAR(255) = 'Var1',
    @VarName2 NVARCHAR(255) = 'Var2',
    @VarName3 NVARCHAR(255) = 'Var3',
    @VarName4 NVARCHAR(255) = 'Var4',
    @VarName5 NVARCHAR(255) = 'Var5',
    @VarName6 NVARCHAR(255) = 'Var6',
    @VarName7 NVARCHAR(255) = 'Var7',
    @VarName8 NVARCHAR(255) = 'Var8',
    @VarValue1 NVARCHAR(255) = NULL,
    @VarValue2 NVARCHAR(255) = NULL,
    @VarValue3 NVARCHAR(255) = NULL,
    @VarValue4 NVARCHAR(255) = NULL,
    @VarValue5 NVARCHAR(255) = NULL,
    @VarValue6 NVARCHAR(255) = NULL,
    @VarValue7 NVARCHAR(255) = NULL,
    @VarValue8 NVARCHAR(255) = NULL,
    @NumColumns INT = 1
AS
BEGIN
    SET NOCOUNT ON;

	-- Remove percent sign (%) characters from variable values
    SET @VarValue1 = REPLACE(@VarValue1, '%', '');
    SET @VarValue2 = REPLACE(@VarValue2, '%', '');
    SET @VarValue3 = REPLACE(@VarValue3, '%', '');
    SET @VarValue4 = REPLACE(@VarValue4, '%', '');
    SET @VarValue5 = REPLACE(@VarValue5, '%', '');
    SET @VarValue6 = REPLACE(@VarValue6, '%', '');
    SET @VarValue7 = REPLACE(@VarValue7, '%', '');
    SET @VarValue8 = REPLACE(@VarValue8, '%', '');

    -- Initialize the HTML table
    DECLARE @html NVARCHAR(MAX);
    SET @html = N'<table border="1">' + CHAR(13);

    -- Create a table with variable values and IDs
    WITH VariableValues AS (
        SELECT * FROM (
            VALUES
                (1, @VarName1, @VarValue1),
                (2, @VarName2, @VarValue2),
                (3, @VarName3, @VarValue3),
                (4, @VarName4, @VarValue4),
                (5, @VarName5, @VarValue5),
                (6, @VarName6, @VarValue6),
                (7, @VarName7, @VarValue7),
                (8, @VarName8, @VarValue8)
        ) AS V(id, VarName, VarValue)
        WHERE VarValue IS NOT NULL
    ),
    -- Calculate row numbers based on the number of columns
    Rows AS (
        SELECT
            id,
            VarName,
            VarValue,
            ((id - 1) / @NumColumns) AS RowNum
        FROM VariableValues
    ),
    -- Group rows by row number and concatenate table cells
    GroupedRows AS (
        SELECT
            RowNum,
            (SELECT '<td style="padding:1px; text-align:center;"><center><b>' + VarName + '</b></center></td><td style="padding:1px; text-align:center;">' + VarValue + '</td>'
             FROM Rows
             WHERE RowNum = R.RowNum
             FOR XML PATH(''), TYPE).value('.[1]', 'NVARCHAR(MAX)') AS Cells
        FROM Rows R
        GROUP BY RowNum
    )

    -- Concatenate table rows
    SELECT @html = @html + '<tr>' + Cells + '</tr>' + CHAR(13)
    FROM GroupedRows;

    SET @html = @html + N'</table><br>';

    SELECT @html AS HTMLTable;
END;



GO

/*Sample Output:
<table border="1"> <tr><td style="padding:1px; text-align:center;"><center><b>Fruit</b></center></td><td style="padding:1px; text-align:center;">Apple</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Color</b></center></td><td style="padding:1px; text-align:center;">Red</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Animal</b></center></td><td style="padding:1px; text-align:center;">Dog</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Size</b></center></td><td style="padding:1px; text-align:center;">Medium</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Fruit2</b></center></td><td style="padding:1px; text-align:center;">Apple2</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Color2</b></center></td><td style="padding:1px; text-align:center;">Red2</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Animal2</b></center></td><td style="padding:1px; text-align:center;">Dog2</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Size2</b></center></td><td style="padding:1px; text-align:center;">Medium2</td></tr> </table><br>
<table border="1"> <tr><td style="padding:1px; text-align:center;"><center><b>Fruit</b></center></td><td style="padding:1px; text-align:center;">Apple</td><td style="padding:1px; text-align:center;"><center><b>Color</b></center></td><td style="padding:1px; text-align:center;">Red</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Animal</b></center></td><td style="padding:1px; text-align:center;">Dog</td><td style="padding:1px; text-align:center;"><center><b>Size</b></center></td><td style="padding:1px; text-align:center;">Medium</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Fruit2</b></center></td><td style="padding:1px; text-align:center;">Apple2</td><td style="padding:1px; text-align:center;"><center><b>Color2</b></center></td><td style="padding:1px; text-align:center;">Red2</td></tr> <tr><td style="padding:1px; text-align:center;"><center><b>Animal2</b></center></td><td style="padding:1px; text-align:center;">Dog2</td><td style="padding:1px; text-align:center;"><center><b>Size2</b></center></td><td style="padding:1px; text-align:center;">Medium2</td></tr> </table><br>
*/
