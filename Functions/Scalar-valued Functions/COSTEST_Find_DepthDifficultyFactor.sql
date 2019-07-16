USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_DepthDifficultyFactor]    Script Date: 7/16/2019 10:38:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_DepthDifficultyFactor]
(
  @Depth FLOAT,
  @DiamWidth FLOAT,
  @Height FLOAT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @LargestSize FLOAT
  DECLARE @DifficultyFactor FLOAT
  
  IF (ISNULL(@DiamWidth,0) > ISNULL(@Height,0)) BEGIN SET @LargestSize = ISNULL(@DiamWidth,0) END ELSE BEGIN SET @LargestSize = ISNULL(@Height,0) END
  
  DECLARE @LowMark FLOAT
  
  SELECT  TOP(1) @DifficultyFactor = DifficultyFactor
  FROM    [dbo].[COSTEST_DiameterDepthDifficultyFactor]
  WHERE   @Depth >= Depth
          AND
          @LargestSize >= SmallestDiameter
  ORDER BY SmallestDiameter DESC, Depth DESC
  
  
  RETURN @DifficultyFactor

END



GO

