USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_BypassPumpingUnitRate]    Script Date: 7/16/2019 10:38:06 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_BypassPumpingUnitRate]
(
  --@uDepth FLOAT,
  --@dDepth FLOAT,
  @xPipSlope FLOAT,
  @length FLOAT,
  @diamWidth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @Slope FLOAT
  DECLARE @LargestSize FLOAT
  DECLARE @BypassCost FLOAT
  DECLARE @BypassFlow FLOAT
  DECLARE @InchesPerFoot FLOAT = 12.0
  DECLARE @ManningsN FLOAT = 0.013
  DECLARE @Kn FLOAT = 1.486
  DECLARE @FractionalFlow FLOAT = 0.2
  DECLARE @AssumedSlope FLOAT = 0.005
  
  SET @Slope = ISNULL(@xPipSlope, 0)
  
  IF @Slope > 0
  BEGIN
    --SET @BypassFlow = 0.464/@ManningsN * POWER(ISNULL(@diamWidth,0)/@InchesPerFoot, 8.0/3.0) * SQRT(@Slope)
    SET @BypassFlow = @FractionalFlow*@Kn/@ManningsN * POWER(ISNULL(@diamWidth,0)/(4*@InchesPerFoot), 2.0/3.0) * SQRT(@Slope)
  END
  ELSE
  BEGIN
    --SET @BypassFlow = @FractionalFlow * 2.0 * PI() * 0.25 * POWER(ISNULL(@diamWidth,0)/@InchesPerFoot, 2.0)
    --Assume slope of 0.005
    SET @BypassFlow = @FractionalFlow*@Kn/@ManningsN * POWER(ISNULL(@diamWidth,0)/(4*@InchesPerFoot), 2.0/3.0) * SQRT(@AssumedSlope)
  END
  
  
  SELECT  TOP(1) @BypassCost = BypassCost
  FROM    [dbo].[COSTEST_BypassPumpingUnitRates]
  WHERE   @BypassFlow > BypassFlowGPM
  ORDER BY BypassFlowGPM DESC
  
  RETURN @BypassCost

END



GO

