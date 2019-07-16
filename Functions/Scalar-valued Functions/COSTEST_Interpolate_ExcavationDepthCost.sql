USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Interpolate_ExcavationDepthCost]    Script Date: 7/16/2019 10:44:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Interpolate_ExcavationDepthCost]
(
  @Depth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LowMark FLOAT
  DECLARE @HighMark FLOAT
  DECLARE @LowCost FLOAT
  DECLARE @HighCost FLOAT
  
  SELECT  TOP(1) @LowMark = depthFt,
          @LowCost = costPerCuYd
  FROM    REHAB.dbo.COSTEST_DepthToTrenchExcavationCostRecord
  WHERE   @Depth >= depthFt
  ORDER BY depthFt
  
  SELECT  TOP(1) @HighMark = depthFt,
          @HighCost = costPerCuYd
  FROM    REHAB.dbo.COSTEST_DepthToTrenchExcavationCostRecord
  WHERE   @Depth < depthFt
  ORDER BY depthFt DESC
  
  IF @HighMark IS NULL
  BEGIN
    SELECT  TOP(1) @HighMark = depthFt,
            @HighCost = costPerCuYd
    FROM    REHAB.dbo.COSTEST_DepthToTrenchExcavationCostRecord
    WHERE   @Depth >= depthFt
    ORDER BY depthFt
  
    SELECT  TOP(1) @LowMark = depthFt,
            @LowCost = costPerCuYd
    FROM    REHAB.dbo.COSTEST_DepthToTrenchExcavationCostRecord
    WHERE   @HighMark < depthFt
    ORDER BY depthFt DESC
  END
  
  RETURN @LowCost + (@Depth - @LowMark)*(@HighCost - @LowCost)/(@HighMark - @LowMark)

END



GO

