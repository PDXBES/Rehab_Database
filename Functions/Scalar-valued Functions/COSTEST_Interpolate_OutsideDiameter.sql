USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Interpolate_OutsideDiameter]    Script Date: 7/16/2019 10:45:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Interpolate_OutsideDiameter]
(
  @DiamWidth FLOAT,
  @Height FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @LowID FLOAT
  DECLARE @HighID FLOAT
  DECLARE @LowOD FLOAT
  DECLARE @HighOD FLOAT
  
  IF (ISNULL(@DiamWidth,0) > ISNULL(@Height,0)) BEGIN SET @LargestSize = ISNULL(@DiamWidth,0) END ELSE BEGIN SET @LargestSize = ISNULL(@Height,0) END
  
  SELECT  TOP(1) @LowID = insideDiameterInches,
          @LowOD = outsideDiameterInches
  FROM    REHAB.dbo.COSTEST_InsideOutsideDiameterRosetta
  WHERE   @LargestSize >= insideDiameterInches
  ORDER BY insideDiameterInches DESC
  
  SELECT  TOP(1) @HighID = insideDiameterInches,
          @HighOD = outsideDiameterInches
  FROM    REHAB.dbo.COSTEST_InsideOutsideDiameterRosetta
  WHERE   @LargestSize < insideDiameterInches
  ORDER BY insideDiameterInches 
  
  IF @HighID IS NULL
  BEGIN
    SELECT  TOP(1) @HighID = insideDiameterInches,
            @HighOD = outsideDiameterInches
    FROM    REHAB.dbo.COSTEST_InsideOutsideDiameterRosetta
    WHERE   @LargestSize >= insideDiameterInches
    ORDER BY insideDiameterInches DESC
  
    SELECT  TOP(1) @LowID = insideDiameterInches,
            @LowOD = outsideDiameterInches
    FROM    REHAB.dbo.COSTEST_InsideOutsideDiameterRosetta
    WHERE   @HighID > insideDiameterInches
    ORDER BY insideDiameterInches DESC
  END
  
  RETURN @HighOD--@LowOD + (@LargestSize - @LowID)*(@HighOD - @LowOD)/(@HighID - @LowID)

END


GO

