USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Interpolate_PipeCost]    Script Date: 7/16/2019 10:45:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Interpolate_PipeCost]
(
  @DiamWidth FLOAT,
  @Height FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @LowMark FLOAT
  DECLARE @HighMark FLOAT
  DECLARE @LowCost FLOAT
  DECLARE @HighCost FLOAT
  DECLARE @Material NVARCHAR(50)
  
  IF (ISNULL(@DiamWidth,0) > ISNULL(@Height,0)) BEGIN SET @LargestSize = ISNULL(@DiamWidth,0) END ELSE BEGIN SET @LargestSize = ISNULL(@Height,0) END
  
  IF @LargestSize <= 15 BEGIN SET @Material = 'PVC' END ELSE BEGIN SET @Material = 'Concrete' END
  
  SELECT  TOP(1) @LowMark = MinDiameter,
          @LowCost = Cost
  FROM    dbo.COSTEST_PipeMaterial
  WHERE   @LargestSize >= MinDiameter
          AND
          @Material = Material
  ORDER BY MinDiameter DESC
  
  SELECT  TOP(1) @HighMark = MinDiameter,
          @HighCost = Cost
  FROM    dbo.COSTEST_PipeMaterial
  WHERE   @LargestSize < MinDiameter
          AND
          @Material = Material
  ORDER BY MinDiameter 
  
  IF @HighMark IS NULL
  BEGIN
    SELECT  TOP(1) @HighMark = MinDiameter,
            @HighCost = Cost
    FROM    dbo.COSTEST_PipeMaterial
    WHERE   @LargestSize >= MinDiameter
            AND
            @Material = Material
    ORDER BY MinDiameter DESC
  
    SELECT  TOP(1) @LowMark = MinDiameter,
            @LowCost = Cost
    FROM    dbo.COSTEST_PipeMaterial
    WHERE   @HighMark > MinDiameter
            AND
            @Material = Material
    ORDER BY MinDiameter DESC
  END
  
  DECLARE @Retval float
  IF ISNULL((@HighMark - @LowMark),0) = 0 
    SET @Retval = 0 
  ELSE
    SET @Retval = @LowCost + (@LargestSize - @LowMark)*(@HighCost - @LowCost)/(@HighMark - @LowMark)
  
  RETURN @Retval

END


GO

