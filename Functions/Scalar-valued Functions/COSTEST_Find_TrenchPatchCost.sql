USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_Find_TrenchPatchCost]    Script Date: 7/16/2019 10:44:37 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_Find_TrenchPatchCost]
(
  @hardArea INT,
  @pStrtTyp INT
)
RETURNS FLOAT
AS
BEGIN

  DECLARE @TrenchPatchCost FLOAT = 0.0
  
  --Arterial
  IF @pStrtTyp IN 
    (
      1300
    )
    SELECT @TrenchPatchCost = EightInchTrenchPatchAsphaltCost FROM Constants
  --Secondary Arterial
  IF @pStrtTyp IN 
    (
      1400, 1450, 5301, 5401
    )
    SELECT @TrenchPatchCost = SixInchTrenchPatchAsphaltCost FROM Constants
  --Street
  IF @pStrtTyp IN 
    (
      1500, 1521, 1700, 1740, 1750, 1800, 1950,  5501, 5500
    )
    SELECT @TrenchPatchCost = FourInchTrenchPatchAsphaltCost FROM Constants
  IF ISNULL(@hardArea, 0) > 1
    SELECT @TrenchPatchCost = EightInchTrenchPatchAsphaltCost FROM Constants
  
  RETURN @TrenchPatchCost 
    

END



GO

