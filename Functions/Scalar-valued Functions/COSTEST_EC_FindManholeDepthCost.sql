USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_EC_FindManholeDepthCost]    Script Date: 7/16/2019 10:32:10 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_EC_FindManholeDepthCost]
(
  @Diameter float,
  @Depth float
)
--=IF(BV7>8,INDEX(MHCost_Base,MATCH(1,(MHCost_Diam>=M7)*1,0))*(BV7-8),0)
--=IF(OC_TDepth>8,INDEX(MHCost_Base,MATCH(1,(MHCost_Diam>=DiamWidth)*1,0))*(OC_TDepth-8),0)
RETURNS FLOAT
AS
BEGIN

  DECLARE @MH_DepthCost FLOAT = 0
  DECLARE @DepthCostMarkerFeet FLOAT = 8
  
  IF (@Depth > @DepthCostMarkerFeet)
  BEGIN
    SELECT  TOP(1) @MH_DepthCost = CostPerFtOfDepthBeyond8Feet
    FROM    [dbo].EC_ManholeCosts
    WHERE   @Diameter <= ManholeDiameterInches
    ORDER BY ManholeDiameterInches ASC
  END

  RETURN @MH_DepthCost * (@Depth - @DepthCostMarkerFeet) 
  
END



GO

