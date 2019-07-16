USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[USP_UPDATE_TABLE_USAGE]    Script Date: 7/16/2019 10:08:04 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[USP_UPDATE_TABLE_USAGE]

AS


DECLARE @name VARCHAR(50)
DECLARE table_cursor CURSOR FOR  

SELECT [name]
  FROM [REHAB].[sys].[all_objects]
  Where [type] = 'U'
OPEN table_cursor 
  
FETCH NEXT FROM table_cursor INTO @name   

WHILE @@FETCH_STATUS = 0  
	BEGIN 	    
		
		INSERT INTO REHAB.dbo.REHAB_TABLE_USAGE
			([Used_TableName], [last_user_lookup], [last_user_scan], [last_user_seek],[last_user_update])
		
		SELECT 
		OBJECT_NAME(ius.[object_id]) AS [Used_TableName],
		MAX(ius.[last_user_lookup]) AS [last_user_lookup],
		MAX(ius.[last_user_scan]) AS [last_user_scan],
		MAX(ius.[last_user_seek]) AS [last_user_seek], 
		MAX(ius.[last_user_update]) AS [last_user_update] 
		FROM sys.dm_db_index_usage_stats AS ius
		WHERE ius.[database_id] = DB_ID()
		AND ius.[object_id] = OBJECT_ID(@name)
		GROUP BY ius.[database_id], ius.[object_id];
        
		FETCH NEXT FROM table_cursor INTO @name   
	END   

CLOSE table_cursor   
DEALLOCATE table_cursor;

GO

