USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_ManholeBaseCost]    Script Date: 7/16/2019 10:40:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_ManholeBaseCost]
(
  @DiamWidth FLOAT,
  @uDepth FLOAT,
  @dDepth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @BaseCost FLOAT
  DECLARE @CostPerFtOfDepthAbove8Ft FLOAT
  DECLARE @RimFrameCost FLOAT
  DECLARE @PipeWallThicknessBuffer FLOAT = 1.0
  DECLARE @PipeWallThicknessFactor FLOAT = 2.0
  DECLARE @ManholeSafetySpacer FLOAT = 12
  DECLARE @Depth FLOAT = CASE WHEN (@uDepth +@dDepth)/2.0 <= 0 THEN 0 ELSE (@uDepth +@dDepth)/2.0  END
  DECLARE @TotalCost FLOAT
  DECLARE @ManholeCostDepthFactor FLOAT
  DECLARE @ProxyDepth FLOAT = CASE WHEN (@uDepth +@dDepth)/2.0 - 8.0 <= 0 THEN 0 ELSE (@uDepth +@dDepth)/2.0 - 8.0 END
  
  /*
  SET @LargestSize = (ISNULL(@DiamWidth,0) + @PipeWallThicknessBuffer) * @PipeWallThicknessFactor
  SET @LargestSize = @LargestSize + ISNULL(@DiamWidth,0) + @ManholeSafetySpacer
  SET @LargestSize = CEILING(@LargestSize/12.0)*12.0
  */
  SET @LargestSize = GIS.[COSTEST_Find_ManholeSizeFromPipeInsideDiameter](ISNULL(@DiamWidth,0))
  
  DECLARE @LowMark FLOAT
  
  SELECT  TOP(1) @BaseCost = BaseCost,
          @CostPerFtOfDepthAbove8Ft = [CostPerFootAbove8Ft],
          @RimFrameCost = [RimFrameCost]
  FROM    [dbo].[COSTEST_ManholeCostTable]
  WHERE   @LargestSize >= ManholeDiameter
  ORDER BY ManholeDiameter DESC
  
  SET @TotalCost = @BaseCost + @CostPerFtOfDepthAbove8Ft * @ProxyDepth + @RimFrameCost
  
  SELECT  TOP(1) @ManholeCostDepthFactor = [Factor]
  FROM    [dbo].[COSTEST_ManholeCostDepthFactorTable]
  WHERE   @LargestSize > [ManholeMinSize]
          AND
          @Depth > [ManholeMinDepth]
  ORDER BY [ManholeMinSize] DESC, [ManholeMinDepth] DESC
  
  SET @TotalCost = @TotalCost * @ManholeCostDepthFactor
  
  
  RETURN @TotalCost

END



GO

