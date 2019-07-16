USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[USP_WRITE_LOG]    Script Date: 7/16/2019 10:08:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE Procedure [dbo].[USP_WRITE_LOG]
	@ScriptName varchar(50),
	@Step int,
	@Log_Msg_Abbrev varchar(50),
	@Log_Msg_Full varchar(150),
	@Log_Records_Affected int
AS

BEGIN 
	DECLARE @LogDateTime Datetime
	SET @LogDateTime = getdate()
	
	--DECLARE @SQL varchar(200)
	--SET @SQL = 

	INSERT INTO dbo.ScriptLog 
	VALUES
	(
		@ScriptName,
		@Step,
		@Log_Msg_Abbrev,
		@Log_Msg_Full,
		@Log_Records_Affected,
		@LogDateTime
	)
		
	--VALUES 
	--	(
	--	 '' + @ScriptName + '', 
	--	 '' + CAST(@Step as varchar) + '',
	--	 '' + @Log_Msg_Abbrev + '',
	--	 '' + @Log_Msg_Full + '',
	--	 '' + CAST(@Log_Records_Affected as varchar) + '', 
	--	 '' + CAST(@LogDateTime as varchar) + ''
	--	)''
		
		
		
	----EXEC @SQL
END


GO

