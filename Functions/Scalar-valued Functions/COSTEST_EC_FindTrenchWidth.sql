USE [REHAB]
GO

/****** Object:  UserDefinedFunction [GIS].[COSTEST_EC_FindTrenchWidth]    Script Date: 7/16/2019 10:37:37 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [GIS].[COSTEST_EC_FindTrenchWidth]
(
  @Material nvarchar(50),
  @Diameter float,
  @Depth float
)
RETURNS FLOAT
AS
BEGIN
  
  DECLARE @Width FLOAT = 0
  
  IF @Material NOT IN ('PVC', 'HDPE')
  BEGIN
    SELECT  TOP(1) @Width = TrenchWidthFeet
    FROM    [dbo].EC_InputsTablesConcrete
    WHERE   @Diameter <= PipeDiamInches
            AND
            @Depth <= TrenchDepthFeet
    ORDER BY PipeDiamInches ASC, TrenchDepthFeet ASC
  END
  ELSE
  BEGIN
    SELECT  TOP(1) @Width = TrenchWidthFeet
    FROM    [dbo].EC_InputsTablesPVCHDPE
    WHERE   @Diameter <= PipeDiameterInches
            AND
            @Depth <= TrenchDepthFeet
    ORDER BY PipeDiameterInches ASC, TrenchDepthFeet ASC
  END
  
  RETURN @Width
  
END



GO

