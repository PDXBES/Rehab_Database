USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_EC_FindManholeFactor]    Script Date: 7/16/2019 10:32:33 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_EC_FindManholeFactor]
(
  @Diameter float,
  @Depth float
)
--=INDEX(MHFactor_Factor,MATCH(1,(MHFactor_Size>=GR7)*(MHFactor_Depth>=BV7),0))
--=INDEX(MHFactor_Factor,MATCH(1,(MHFactor_Size>=MH_MinD)*(MHFactor_Depth>=OC_TDepth),0))
RETURNS FLOAT
AS
BEGIN

  DECLARE @MHFactor_Factor FLOAT = 0
  
  SELECT  TOP(1) @MHFactor_Factor = DepthCostFactor
  FROM    [dbo].EC_ManholeDepthCostFactor
  WHERE   @Diameter <= ManholeSizeInches
          AND
          @Depth <= MaxDepthFeet
  ORDER BY ManholeSizeInches ASC, MaxDepthFeet ASC

  RETURN @MHFactor_Factor 
  
END



GO

