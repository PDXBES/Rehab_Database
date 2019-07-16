USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Interpolate_TrenchWidth]    Script Date: 7/16/2019 10:46:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Interpolate_TrenchWidth]
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
  DECLARE @LowTrench FLOAT
  DECLARE @HighTrench FLOAT
  
  SET @LargestSize = GIS.COSTEST_Interpolate_OutsideDiameter(ISNULL(@DiamWidth,0), ISNULL(@DiamWidth,0))
  
  SELECT  TOP(1) @LowMark = OutsideDiameterInches,
          @LowTrench = widthFeet
  FROM    [REHAB].[dbo].[COSTEST_TrenchWidthByPipeDiameter]
  WHERE   @LargestSize >= outsideDiameterInches
  ORDER BY outsideDiameterInches DESC
  
  SELECT  TOP(1) @HighMark = OutsideDiameterInches,
          @HighTrench = widthFeet
  FROM    [REHAB].[dbo].[COSTEST_TrenchWidthByPipeDiameter]
  WHERE   @LargestSize < outsideDiameterInches
  ORDER BY outsideDiameterInches
  
  IF @HighMark IS NULL
  BEGIN
    SELECT  TOP(1) @HighMark = OutsideDiameterInches,
            @HighTrench = widthFeet
    FROM    [REHAB].[dbo].[COSTEST_TrenchWidthByPipeDiameter]
    WHERE   @LargestSize >= outsideDiameterInches
    ORDER BY outsideDiameterInches DESC
  
    SELECT  TOP(1) @LowMark = OutsideDiameterInches,
            @LowTrench = widthFeet
    FROM    [REHAB].[dbo].[COSTEST_TrenchWidthByPipeDiameter]
    WHERE   @HighMark > outsideDiameterInches
    ORDER BY outsideDiameterInches DESC
  END
  
  RETURN @LowTrench + (@LargestSize - @LowMark)*(@HighTrench - @LowTrench)/(@HighMark - @LowMark)

END


GO

