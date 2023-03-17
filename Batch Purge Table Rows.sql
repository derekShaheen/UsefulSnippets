DECLARE
    @v_nSysErrorNum               INTEGER,
    @v_vchErrMsg                  NVARCHAR(MAX),
    @v_vchCode                    uddt_output_code,
    @v_vchMsg                     uddt_output_msg
SET NOCOUNT ON
DECLARE @BatchSize INT = 5000;
DECLARE @TotalRows INT = (SELECT COUNT(*) FROM t_allocation_q (NOLOCK));
DECLARE @RowsProcessed INT = 0;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @CurrentTimeStr NVARCHAR(21)

PRINT 'PLEASE NOTE, ONLY 500 PRINT STATEMENTS WILL APPEAR UNTIL THE LOG MAXES OUT....'

WHILE @RowsProcessed < @TotalRows
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE TOP (@BatchSize) FROM t_table;
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
