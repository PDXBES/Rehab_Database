USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[__USP_REHAB_12CreatenBCRMatrix]    Script Date: 7/16/2019 9:46:55 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[__USP_REHAB_12CreatenBCRMatrix] @AsOfDate datetime = NULL
AS
BEGIN
  SET NOCOUNT ON;
  IF @AsOfDate IS NULL
   SET @AsOfDate = GETDATE()
   
  DECLARE @unacceptableSurchargeFootage FLOAT = 3.0--1.0
  DECLARE @unacceptableOvallingFraction FLOAT = 0.1
  DECLARE @unacceptableSagFraction FLOAT = 0.1
   
  DECLARE @ENR FLOAT --1.7375
DECLARE @CCIBase FLOAT
DECLARE @CCICurrent FLOAT
DECLARE @EmergencyRepairFactor FLOAT = 1.4

--Apply the codes to those variables
SELECT TOP 1 @CCICurrent = [cci_value] FROM [REHAB].[dbo].[COSTEST_ENR] order by theDate desc--1.7375
SELECT @CCIBase = 8090--Jan 2008
SET @ENR = @CCICurrent/@CCIBase
  --For each pipe, there is a valid nBCR matrix.  For example, some pipes cannot
  --be lined, some pipes cannot be spot repaired, and some pipes must be open cut only.
  --In order to create this matrix, we need the following information:
  
  --(1) Is the pipe surcharged? (Open cut or spot)
  --(2) Is the pipe sagging more than 10%? (OC only)
  --(3) Is the pipe ovaling more than 10% (OC only)
  --For now, these three situations need to be resolved.  The first one to resolve will be (1).
  --To trim the matrix, we null out the values for those pipes that include options from those scenarios:
  
  
  --Surcharging
  UPDATE  A
  SET     nBCR_CIPP = NULL
  FROM    GIS.REHAB_Branches AS A
  WHERE   Problems like '%surcharge%';
  
  --Sagging
  UPDATE  A
  SET     nBCR_CIPP = NULL,
          nBCR_SP = NULL
  FROM    GIS.REHAB_Branches AS A
  WHERE   Problems like '%sagging%';
  
  --Ovaling
  UPDATE  A
  SET     nBCR_CIPP = NULL,
          nBCR_SP = NULL
  FROM    GIS.REHAB_Branches AS A
  WHERE   Problems like '%ovaling%'
   
  --Compare all of the valid nBCR values from [REHAB].[GIS].[REHAB_Branches].
  --The maximum value is the best primary solution (BPW solution).
  --There may be problems with null nBCRs here, but I dont know
  UPDATE  A
  SET     A.ASM_Gen3Solution = B.RecompileSolution,
          A.ASM_Gen3SolutionnBCR = B.MaxnBCRRecompile
  FROM    GIS.REHAB_Branches AS A
          INNER JOIN
          (
          SELECT D.Compkey, maxnBCR, BaseRiskSolution, [MaxnBCRRecompile],
 CASE
 WHEN [MaxnBCRRecompile] = [nBCR_OC]
 THEN 'OC' 
 WHEN [MaxnBCRRecompile] = [nBCR_SP]
 THEN 'SP'
 WHEN [MaxnBCRRecompile] = [nBCR_CIPP]
 THEN 'CIPP'
 END AS RecompileSolution
 FROM [REHAB].[GIS].[REHAB_Branches] AS D
 INNER JOIN
 (
 SELECT Compkey, MaxnBCR, BaseRiskSolution,
 (SELECT Max(v) 
 FROM (VALUES (Recompare)) AS value(v)) as [MaxnBCRRecompile]
 FROM 
 (
 SELECT A.Compkey, maxnBCR,
 CASE
 WHEN maxnBCR = [nBCR_OC]
 THEN 'OC' 
 WHEN maxnBCR = [nBCR_SP]
 THEN 'SP'
 WHEN maxnBCR = [nBCR_CIPP]
 THEN 'CIPP'
 END AS BaseRiskSolution,
 CASE
 WHEN maxnBCR = [nBCR_OC]
 THEN [nBCR_OC] 
 WHEN maxnBCR = [nBCR_SP]
 THEN [nBCR_SP]
 WHEN maxnBCR = [nBCR_CIPP]
 THEN [nBCR_CIPP]
 END AS Recompare
 FROM [REHAB].[GIS].[REHAB_Branches] AS A
 INNER JOIN
 (
 SELECT Compkey,
 (SELECT Max(v) 
 FROM (VALUES ([nBCR_OC])
 ,([nBCR_CIPP])
 ,([nBCR_SP])) AS value(v)) as [MaxnBCR]
 FROM [REHAB].[GIS].[REHAB_Branches]
 ) AS B
 ON A.COMPKEY = B.COMPKEY
 ) AS C) AS E
 ON E.COMPKEY = D.COMPKEY
          ) AS B
          ON A.Compkey = B.Compkey
  
  --Once all of those comparisons are made, a few more gates need to drop.
  --This gate is the 'if there are only one or two bad spots, then it should be a spot repair pipe'
  UPDATE  A
  SET     ASM_Gen3Solution = 'SP',
          problems = ISNULL(problems, '') + ', only one or two bad spots'
  FROM    GIS.REHAB_Branches AS A
  WHERE   COMPKEY IN
          (
            SELECT  COMPKEY
            FROM    GIS.REHAB_Segments AS C
            WHERE   cutno > 0
                    AND
                    (
                      [action] = 3
                      OR
                      def_tot > 100
                    )
                    
            GROUP BY COMPKEY
            HAVING COUNT(*) > 0
                   AND
                   COUNT(*) <= 2
          )
          AND
          problems not like '%oval%'
          AND
          problems not like '%sagg%'
  
  
  --This gate is the 'OC if between two other OC pipes'
  UPDATE  A
  SET     ASM_Gen3Solution = 'OC Sandwich',
          problems = ISNULL(problems, '') + ', in between two OC'
  FROM    GIS.REHAB_Branches AS A
  WHERE   COMPKEY IN
          (
            SELECT  B.COMPKEY 
            FROM    (   
	                  SELECT  XA.*, XB.UsNode, XB.DsNode
	                  FROM    GIS.REHAB_Branches AS XA
		                      INNER JOIN
		                      GIS.REHAB_Segments AS XB
		                      ON  XA.COMPKEY = XB.COMPKEY
		                          AND
		                          XB.cutno = 0
		                          AND
		                          XB.grade_h5 >= 4
		                          AND
		                          XA.ASM_Gen3Solution != 'OC'
		                          AND
		                          XA.ASM_Gen3Solution != 'OC Sandwich'
	                ) AS B
                    INNER JOIN 
	                (
	                  SELECT  XA.*, XB.UsNode, XB.DsNode
	                  FROM    GIS.REHAB_Branches AS XA
		                      INNER JOIN
		                      GIS.REHAB_Segments AS XB
		                      ON  XA.COMPKEY = XB.COMPKEY
		                          AND
		                          XB.cutno = 0
		                          AND
	                              XB.grade_h5 >= 4
		                          AND 
		                          XA.ASM_Gen3Solution = 'OC'
	                ) AS C
	                ON  B.UsNode = C.DsNode 
	                INNER JOIN 
	                (
	                  SELECT  XA.*, XB.UsNode, XB.DsNode
	                  FROM    GIS.REHAB_Branches AS XA
		                      INNER JOIN
		                      GIS.REHAB_Segments AS XB
		                      ON  XA.COMPKEY = XB.COMPKEY
		                          AND
		                          XB.cutno = 0
		                          AND
		                          XB.grade_h5 >= 4
		                          AND
		                          XA.ASM_Gen3Solution = 'OC'
	                ) AS D 
	                ON  B.DsNode = D.UsNode
          )
          
--The following gates are for pipes that may have problems
--if there is no match in the COMPSMN or STMN tables, then identify that.
UPDATE  C
SET     problems = problems + ', no match in COMPSMN OR COMPSTMN' 
FROM    (GIS.REHAB_Branches AS C LEFT JOIN HA8_COMPSMN AS A ON C.COMPKEY = A.COMPKEY ) 
	    LEFT JOIN 
	    HA8_COMPSTMN AS B 
	    ON C.COMPKEY = B.COMPKEY 
WHERE   B.COMPKEY IS NULL 
        AND 
        A.COMPKEY is null

--identify if the pipe's inspection was before the last replacement
UPDATE  A 
SET     problems =  problems + ', pipe was replaced after last inspection' 
FROM    GIS.REHAB_Branches AS A 
        INNER JOIN
        GIS.REHAB_Segments AS B
        ON A.COMPKEY = B.COMPKEY
WHERE   insp_curr =  3

--identify if the pipe's inspection does not exist 
UPDATE  A
SET     problems =  problems + ', no valid inspection' 
FROM    GIS.REHAB_Branches AS A
        INNER JOIN
        GIS.REHAB_Segments AS B
        ON A.COMPKEY = B.COMPKEY 
WHERE   insp_curr =  4
	
--identify if the install date is null and the pipe is tbab or aban 
UPDATE  A
SET     problems =  problems + ', pipe has no install date and is tbab or aban' 
FROM    GIS.REHAB_Branches AS A
        INNER JOIN
        GIS.REHAB_Segments AS B
        ON A.COMPKEY = B.COMPKEY  
WHERE   insp_curr =  2

--identify if the the inspection was not completed in one pass
UPDATE  A
SET     problems =  problems + ', inspection not completed in one pass' 
FROM    GIS.REHAB_Branches AS A 
        INNER JOIN 
        REHAB_CONVERSION 
ON      A.COMPKEY = REHAB_CONVERSION.COMPKEY 
WHERE   COMPDTTM is null

--identify if the the inspection goes beyond the mst_links length of the pipe
UPDATE  A 
SET     problems =  problems + ', inspection is longer than known length of pipe' 
FROM    GIS.REHAB_Branches AS A 
        INNER JOIN 
        REHAB_CONVERSION 
        ON  A.COMPKEY = REHAB_CONVERSION.COMPKEY
        INNER JOIN
        GIS.REHAB_Segments AS B
        ON A.COMPKEY = B.COMPKEY
           AND
           B.cutno = 0
WHERE   convert_setdwn_from > [length] 
        OR 
        convert_setdwn_to > [length]
  


  
--This gate is 'Not a rehab pipe'
CREATE TABLE #BESMaintainedCompkeys (COMPKEY int)

INSERT INTO #BESMaintainedCompkeys
SELECT A.COMPKEY
FROM	GIS.REHAB_Branches AS A  
		INNER JOIN 
		HA8_COMPSMN AS B	
		ON	A.COMPKEY = B.COMPKEY 
			AND 
			(
				B.UnitType = 'saml' 
				OR 
				B.UnitType = 'csml' 
				OR 
				B.UnitType = 'csint' 
				OR 
				B.UnitType = 'saint' 
				OR 
				B.UnitType = 'csdet' 
				OR 
				B.UnitType = 'csotn' 
				OR 
				B.UnitType = 'embpg'
				OR 
				B.UnitType = 'csoml' OR
			    B.UnitType = 'csovr'
			) 
			--Fix because we may want to look into the past
			AND 
			B.ServStat <> 'ABAN' 
			AND 
			B.ServStat <> 'TBAB' 
			AND 
			(
			--temporary fix because DEM is poorly constructed
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9]',UNITID) > 0 
			  OR
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9] ',UNITID) > 0 
			)
			AND 
			(
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9]',UNITID2) > 0 
			  OR
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9] ',UNITID2) > 0 
			)
UNION ALL
--Identify the storm pipes as BES owned
SELECT  A.COMPKEY
FROM	GIS.REHAB_Branches AS A 
		INNER JOIN 
		HA8_COMPSTMN AS B 
		ON	A.COMPKEY = B.COMPKEY 
			AND 
			B.OWN = 'BES' 
			AND 
			(
			  B.UnitType = 'stml' OR 
			  B.UnitType = 'csml' OR 
			  B.UnitType = 'csint' OR 
			  B.UnitType = 'saint' OR 
			  B.UnitType = 'csdet' OR 
			  B.UnitType = 'csotn' OR 
			  B.UnitType = 'csoml' OR 
			  B.UnitType = 'embpg' OR
			  B.UnitType = 'csovr' OR
			  B.UnitType = 'saml'
			) 
			AND 
			--Fix because we may want to look into the past
			B.ServStat <> 'ABAN' 
			AND 
			B.ServStat <> 'TBAB' 
			AND 
			(
			--temporary fix because DEM is poorly constructed
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9]',UNITID) > 0 
			  OR
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9] ',UNITID) > 0 
			)
			AND 
			(
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9]',UNITID2) > 0 
			  OR
			  PATINDEX('[A-Z][A-Z][A-Z][0-9][0-9][0-9] ',UNITID2) > 0 
			)
			AND  
			A.COMPKEY IN (
							SELECT	HA8_COMPSTMN.COMPKEY
							FROM	HA8_COMPSTMN 
									INNER JOIN
									HA8_COPSTORMMAIN 
									ON	HA8_COMPSTMN.COMPKEY = HA8_COPSTORMMAIN.COMPKEY 
									INNER JOIN
									HA8_COPSTMNALTGRD 
									ON	HA8_COPSTORMMAIN.COPSTORMMAINKEY = HA8_COPSTMNALTGRD.COPSTORMMAINKEY
							WHERE	HA8_COMPSTMN.COMPKEY > 1
									AND
									HA8_COPSTMNALTGRD.ALTIDTYP='OFID'
						)
						
UPDATE	GIS.REHAB_Branches 
SET		ASM_Gen3Solution = 'Not a BES maintained rehab pipe',
        problems = ISNULL(problems, '') + ', not a BES maintained rehab pipe'
FROM	GIS.REHAB_Branches AS A 
        LEFT OUTER JOIN
        #BESMaintainedCompkeys AS B
        ON  A.COMPKEY = B.COMPKEY
WHERE   A.COMPKEY IS NULL
        OR 
        B.COMPKEY IS NULL


DROP TABLE #BESMaintainedCompkeys  
END


GO

