USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[USP_Cleanup_SDE_Column_Registry]    Script Date: 7/16/2019 10:06:43 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[USP_Cleanup_SDE_Column_Registry] @FeatureClass varchar(50)

as

BEGIN
	DELETE FROM [REHAB].[sde].[SDE_column_registry]
	WHERE table_name = @FeatureClass;
END
GO

