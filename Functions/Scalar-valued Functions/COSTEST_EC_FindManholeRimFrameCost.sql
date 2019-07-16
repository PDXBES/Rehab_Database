USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_EC_FindManholeRimFrameCost]    Script Date: 7/16/2019 10:36:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_EC_FindManholeRimFrameCost]
(
  @Diameter float
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @RimFrameCost FLOAT = 0
  
  
  SELECT  TOP(1) @RimFrameCost = RimFrameCost
  FROM    [dbo].EC_ManholeCosts
  WHERE   @Diameter <= ManholeDiameterInches
  ORDER BY ManholeDiameterInches ASC

  RETURN @RimFrameCost
  
END



GO

