USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_TrafficControlUnitRate]    Script Date: 7/16/2019 10:41:42 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_TrafficControlUnitRate]
(
  @uxCLx INT,
  @pStrtTyp INT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @BaseStreets FLOAT = 2.0
  DECLARE @AdditionalStreets FLOAT = 0.0
  DECLARE @TrafficControlUnitCost FLOAT = 0.0
  
  IF ISNULL(@uxCLx, 0) < 2
    SET @AdditionalStreets = 0
  ELSE
    SET @AdditionalStreets = @uxCLx - 2.0 
  
  SET @TrafficControlUnitCost = 0.0
  IF @pStrtTyp IN 
    (
      1221, 1222, 1223
    )
    SET @TrafficControlUnitCost = 3000.0
  IF @pStrtTyp IN 
    (
      1300, 1400, 1450, 5301, 5401
    )
    SET @TrafficControlUnitCost = 1000.0
  IF @pStrtTyp IN 
    (
      1500, 1521, 1700, 1740, 1750, 1800, 1950, 5501
    )
    SET @TrafficControlUnitCost = 500.0
  
  RETURN @TrafficControlUnitCost * (@AdditionalStreets + @BaseStreets)/@BaseStreets
    

END



GO

