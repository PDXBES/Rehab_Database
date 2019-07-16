USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_LinerCost]    Script Date: 7/16/2019 10:38:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_LinerCost]
(
  @DiamWidth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LinerCost FLOAT
  
  SELECT  TOP(1) @LinerCost = Cost
  FROM    [dbo].COSTEST_LinerCostsTable
  WHERE   @DiamWidth <= DiameterInches
  ORDER BY DiameterInches ASC
  
  
  RETURN @LinerCost

END




GO

