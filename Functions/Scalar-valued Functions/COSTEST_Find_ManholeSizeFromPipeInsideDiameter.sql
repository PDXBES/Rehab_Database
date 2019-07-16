USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_ManholeSizeFromPipeInsideDiameter]    Script Date: 7/16/2019 10:40:46 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_ManholeSizeFromPipeInsideDiameter]
(
  @DiamWidth FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @ManholeSize FLOAT
  
  --IF (ISNULL(@DiamWidth,0) > ISNULL(@Height,0)) BEGIN SET @LargestSize = ISNULL(@DiamWidth,0) END ELSE BEGIN SET @LargestSize = ISNULL(@Height,0) END
  
  DECLARE @LowMark FLOAT
  
  SELECT  TOP(1) @ManholeSize = manholeDiameterInches
  FROM    [dbo].COSTEST_InsideDiameterToManholeDiameterTable
  WHERE   @DiamWidth >= insideDiameterInches
  ORDER BY insideDiameterInches DESC
  
  
  RETURN @ManholeSize

END



GO

