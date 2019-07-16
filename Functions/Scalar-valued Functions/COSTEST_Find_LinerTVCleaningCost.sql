USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_LinerTVCleaningCost]    Script Date: 7/16/2019 10:39:35 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_LinerTVCleaningCost]
(
  @DiamWidth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @TVCost FLOAT
  
  --IF (ISNULL(@DiamWidth,0) > ISNULL(@Height,0)) BEGIN SET @LargestSize = ISNULL(@DiamWidth,0) END ELSE BEGIN SET @LargestSize = ISNULL(@Height,0) END
  
  DECLARE @LowMark FLOAT
  
  SELECT  TOP(1) @TVCost = Cost
  FROM    [dbo].COSTEST_LinerTVCleaningCosts
  WHERE   @DiamWidth >= Diameter
  ORDER BY Diameter DESC
  
  
  RETURN @TVCost

END



GO

