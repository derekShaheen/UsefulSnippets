DECLARE
    @v_nSysErrorNum               INTEGER,
    @v_vchErrMsg                  NVARCHAR(MAX),
    @v_vchCode                    uddt_output_code,
    @v_vchMsg                     uddt_output_msg
SET NOCOUNT ON
DECLARE @BatchSize INT = 5000;
DECLARE @TotalRows INT = (SELECT COUNT(*) FROM t_table (NOLOCK));
DECLARE @RowsProcessed INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @CurrentTimeStr NVARCHAR(21)

PRINT 'PLEASE NOTE, ONLY 500 PRINT STATEMENTS WILL APPEAR UNTIL THE LOG MAXES OUT....'

WHILE @RowsProcessed < @TotalRows
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE TOP (@BatchSize) FROM t_allocation_q;
        SET @RowsProcessed = @RowsProcessed + @@ROWCOUNT;
        DECLARE @ElapsedTime INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        DECLARE @RemainingTime INT = (@TotalRows - @RowsProcessed) / (@RowsProcessed / @ElapsedTime);
		SELECT @CurrentTimeStr = CONVERT(VARCHAR, GETDATE(), 21)

        DECLARE @msg NVARCHAR(150) = @CurrentTimeStr + ' > Rows deleted: ' + CAST(@RowsProcessed AS VARCHAR(20)) + ' of ' + CAST(@TotalRows AS VARCHAR(20)) + ' (' + CAST(CAST(@RowsProcessed AS FLOAT) / CAST(@TotalRows AS FLOAT) * 100 AS VARCHAR(20)) + '%) - ' + CAST(@RemainingTime / 60 AS VARCHAR(20)) + ' minutes remaining';
		PRINT @msg
		RAISERROR(@msg,0,1) WITH NOWAIT

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
		SELECT @CurrentTimeStr = CONVERT(VARCHAR, GETDATE(), 21)

		SET @v_nSysErrorNum = ERROR_NUMBER();
        SET @v_vchCode = ERROR_LINE();

        SET @v_vchMsg = @v_vchMsg + N' SQL Error = ' + ERROR_MESSAGE();

		PRINT @CurrentTimeStr + ' > ' + @v_vchMsg
		RAISERROR(@v_vchMsg,0,1) WITH NOWAIT

        ROLLBACK TRANSACTION;
    END CATCH
END

PRINT 'COMPLETE.'

/*
Example Output:
2023-03-17 17:23:39.0 > Rows deleted: 580000 of 35847824 (1.61795%) - 83 minutes remaining
2023-03-17 17:23:45.7 > Rows deleted: 585000 of 35847824 (1.6319%) - 88 minutes remaining
2023-03-17 17:23:45.9 > Rows deleted: 590000 of 35847824 (1.64585%) - 87 minutes remaining
2023-03-17 17:23:46.2 > Rows deleted: 595000 of 35847824 (1.65979%) - 87 minutes remaining
2023-03-17 17:23:46.4 > Rows deleted: 600000 of 35847824 (1.67374%) - 87 minutes remaining
*/
