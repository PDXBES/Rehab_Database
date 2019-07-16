USE [REHAB]
GO

/****** Object:  StoredProcedure [GIS].[nBCRLasso]    Script Date: 7/16/2019 10:10:08 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Issac Gardner>
-- Create date: <7/30/2013>
-- Description:	<REHAB GO PROCESS>
-- =============================================
CREATE PROCEDURE [GIS].[nBCRLasso] @userName nvarchar(128), @maxBudget float, @maxYearsToFailure float, @minnBCR float, @minHansenRating float, @LateralsForSpots int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	DECLARE @intErrorCode INT
	
	SET @maxBudget = @maxBudget * 1000000.0
	
	--First identify where the user selected pipes list is coming from
	
	SELECT hansen_compkey
	INTO #REHAB_USER 
    FROM [GOLEM].[GIS].REHAB_10FtSegs_USER
    WHERE userName = @userName
	--Clear out any previous query data from this user

    DECLARE @SumCost float = 0
  
    DECLARE @iterator int = 0
    DECLARE @maxIteration int = 0
  
    SELECT @maxIteration = COUNT(*) FROM #REHAB_USER
  
    WHILE @iterator < @maxIteration AND @sumCost <= @maxBudget
    BEGIN
      SET @iterator = @iterator + 1
    
      SELECT  @sumCost = ISNULL(SUM(Cost),0)
      FROM
              (
                SELECT  Cost, 
                        RANK() OVER (ORDER BY Cost) AS theOrder 
                FROM    [REHAB].[GIS].[nBCR_View_Costs] AS A
                        INNER JOIN
                        [REHAB].[GIS].REHAB_Branches AS B
                        ON A.Compkey = B.Compkey
                WHERE   A.compkey IN
                        (
                          SELECT  hansen_compkey
                          FROM    #REHAB_USER 
                        )
                        AND
                        InitialFailYear - YEAR(GETDATE()) <= @maxYearsToFailure
                        AND
                        ASM_Gen3SolutionnBCR >= @minnBCR
                        AND
                        grade_h5 >= @minHansenRating
              ) AS X
      WHERE   theOrder <= @iterator
    END
  
    SET @iterator = @iterator 
  
    --INSERT INTO __REHAB_PIPES_USER(Compkey, Username)
    
    SELECT  Compkey,
            Resolution, 
            Cost,
            [Failure Year],
            nBCR,
            [Hansen Rating],
            [Lateral Cost]
    FROM    (
              SELECT    A.Compkey,
                        B.ASM_Gen3Solution AS Resolution, 
                        CAST(Cost AS numeric (15,0)) AS Cost,
                        InitialFailYear AS [Failure Year],
                        ASM_Gen3SolutionnBCR AS nBCR,
                        grade_h5 AS [Hansen Rating],
                        RANK() OVER (ORDER BY Cost) AS costOrder,
                        CASE WHEN @LateralsForSpots = 1 AND B.ASM_Gen3Solution = 'SP' THEN SpotLateralCost ELSE LateralCost END AS [Lateral Cost] 
                FROM    [REHAB].[GIS].[nBCR_View_Costs] AS A
                        INNER JOIN
                        [REHAB].[GIS].REHAB_Branches AS B
                        ON A.Compkey = B.Compkey
                WHERE   A.compkey IN
                        (
                          SELECT  hansen_compkey
                          FROM    #REHAB_USER 
                        )
                        AND
                        InitialFailYear - YEAR(GETDATE()) <= @maxYearsToFailure
                        AND
                        ASM_Gen3SolutionnBCR >= @minnBCR
                        AND
                        grade_h5 >= @minHansenRating
            ) AS Y 
    WHERE   costOrder < @iterator
  
  /*
    SELECT  SUM(Cost) AS SumCost 
    FROM    (
              SELECT  [Compkey]
                      ,[Cost]
                      ,[LateralCost]
                      ,RANK() OVER (ORDER BY Cost) AS costOrder
              FROM    [REHAB].[GIS].[nBCR_View_Costs]
              WHERE   Compkey < 101800 
            ) AS Y 
  WHERE  costOrder < @iterator*/
		
END

GO

