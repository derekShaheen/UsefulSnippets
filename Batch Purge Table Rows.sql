-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--    PURPOSE:
--        This SQL code purges a table in batches of a specified size. The number of rows processed and the remaining time are printed to the console, and any errors that occur are logged. The table to be purged is specified by setting the @TableName variable.
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

SET NOCOUNT ON

-- Declare User Set Variables
DECLARE @BatchSize INT = 100; -- Set the size of the batch
DECLARE @TableName NVARCHAR(MAX) = 't_table'; -- Set the name of the table to purge
-- Typical use does not require modification below this line if you need to purge indiscriminately.

-- Declare variables
DECLARE @TotalRows INT = 0; -- Initialize the total rows processed
DECLARE @RowsProcessed INT = 0; -- Initialize the number of rows processed
DECLARE @PrintCount INT = 0; -- Initialize the print count
DECLARE @StartTime DATETIME = GETDATE(); -- Record the start time
DECLARE @CurrentTimeStr NVARCHAR(21); -- Initialize the current time string variable
DECLARE @sql NVARCHAR(MAX); -- Initialize the SQL statement variable
-- Declare error variables
DECLARE @v_nSysErrorNum INTEGER, -- System error number variable
@v_vchErrMsg NVARCHAR(MAX), -- Error message variable
@v_vchCode NVARCHAR(500), -- Output code variable
@v_vchMsg NVARCHAR(1000); -- Output message variable
-- 

PRINT 'PLEASE NOTE, ONLY 500 PRINT STATEMENTS WILL APPEAR UNTIL THE LOG MAXES OUT....'
PRINT 'PROCESSING...'

-- Set the SQL statement and execute it using sp_executesql
SET @sql = N'SELECT @TotalRows = COUNT(*) FROM ' + @TableName + ' (NOLOCK)';
EXEC sp_executesql @sql, N'@TotalRows INT output', @TotalRows output;

-- Use a while loop to delete rows from the table in batches
WHILE @RowsProcessed < @TotalRows
BEGIN
	BEGIN TRANSACTION; -- Start a new transaction
	BEGIN TRY -- Try to execute the DELETE statement
		SET @sql = N'DELETE TOP (' + CAST(@BatchSize AS NVARCHAR(20)) + ') FROM ' + @TableName;
		EXEC(@sql); -- Execute the SQL statement
		
		SET @RowsProcessed = @RowsProcessed + @BatchSize; -- Increment the number of rows processed
		DECLARE @ElapsedTime INT = DATEDIFF(SECOND, @StartTime, GETDATE()); -- Calculate the elapsed time
		IF @ElapsedTime = 0 SET @ElapsedTime = 1; -- Make sure the elapsed time is not 0
		DECLARE @RemainingTime INT = (@TotalRows - @RowsProcessed) / (@RowsProcessed / @ElapsedTime); -- Calculate the remaining time
		SELECT @CurrentTimeStr = CONVERT(VARCHAR, GETDATE(), 21) -- Get the current formatted time

		-- Create a message to print and raise as an error
		DECLARE @msg NVARCHAR(150) = ISNULL(@CurrentTimeStr,'') + ' > Rows deleted: ' + CAST(ISNULL(@RowsProcessed,0) AS VARCHAR(20)) + ' of ' + CAST(ISNULL(@TotalRows,0) AS VARCHAR(20)) + ' (' + CAST(CAST(ISNULL(@RowsProcessed,0) AS FLOAT) / CAST(ISNULL(@TotalRows,0) AS FLOAT) * 100 AS VARCHAR(20)) + '%) - ' + CAST(ISNULL(@RemainingTime,0) / 60 AS VARCHAR(20)) + ' minutes remaining';

		PRINT @msg
		RAISERROR(@msg,0,1) WITH NOWAIT
		
		COMMIT TRANSACTION;
    END TRY
	BEGIN CATCH
		SELECT @CurrentTimeStr = CONVERT(VARCHAR, GETDATE(), 21) -- Get the current time

		SET @v_nSysErrorNum = ERROR_NUMBER(); 
		SET @v_vchCode = ERROR_LINE();

		SET @v_vchMsg = N' SQL Error = ' + ERROR_MESSAGE(); -- Set the error message

		PRINT @CurrentTimeStr + ' > ' + @v_vchMsg
		RAISERROR(@v_vchMsg,0,1) WITH NOWAIT -- Raise the error message as an error

		ROLLBACK TRANSACTION;
	END CATCH 
END

PRINT 'COMPLETE.'

/*
Example Output:
2023-03-17 17:23:39.0 > Rows deleted: 580000 of 35847824 (1.61795%) - 83 minutes remaining
2023-03-17 17:23:45.7 > Rows deleted: 585000 of 35847824 (1.63191%) - 88 minutes remaining
2023-03-17 17:23:45.9 > Rows deleted: 590000 of 35847824 (1.64585%) - 87 minutes remaining
2023-03-17 17:23:46.2 > Rows deleted: 595000 of 35847824 (1.65979%) - 87 minutes remaining
2023-03-17 17:23:46.4 > Rows deleted: 600000 of 35847824 (1.67374%) - 87 minutes remaining
*/
