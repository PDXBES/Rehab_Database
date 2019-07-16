USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_EC_FindManholeBaseCost]    Script Date: 7/16/2019 10:31:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_EC_FindManholeBaseCost]
(
  @Diameter float
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @BaseCost FLOAT = 0
  
  
  SELECT  TOP(1) @BaseCost = BaseCost
  FROM    [dbo].EC_ManholeCosts
  WHERE   @Diameter <= ManholeDiameterInches
  ORDER BY ManholeDiameterInches ASC

  RETURN @BaseCost
  
END



GO

