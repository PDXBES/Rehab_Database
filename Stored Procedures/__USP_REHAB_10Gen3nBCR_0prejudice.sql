USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[__USP_REHAB_10Gen3nBCR_0prejudice]    Script Date: 7/16/2019 9:45:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[__USP_REHAB_10Gen3nBCR_0prejudice] 
AS
BEGIN
  SET NOCOUNT ON;
  
  DECLARE @ENR FLOAT --1.7375
DECLARE @CCIBase FLOAT
DECLARE @CCICurrent FLOAT
DECLARE @EmergencyRepairFactor FLOAT = 1.4

--Apply the codes to those variables
SELECT TOP 1 @CCICurrent = [cci_value] FROM [REHAB].[dbo].[COSTEST_ENR] order by theDate desc--1.7375
SELECT @CCIBase = 8090--Jan 2008
SET @ENR = @CCICurrent/@CCIBase

  DECLARE @unacceptableSurchargeFootage FLOAT = 4.0--1.0
  DECLARE @unacceptableOvallingFraction FLOAT = 0.1
  DECLARE @unacceptableSagFraction FLOAT = 0.1
  
  DECLARE @thisYear int = YEAR(GETDATE())
  DECLARE @SpotRotationFrequency int = 30
  DECLARE @EmergencyFactor float = 1.4
  DECLARE @StdDevWholePipeAt120Years int = 12
  DECLARE @MaxStdDev int = 12
  DECLARE @StdDevNewLiner int = 6
  DECLARE @RULNewWholePipe int = 120
  DECLARE @RULNewLiner int = 55
  DECLARE @LineAtYearNoSpots int = 30
  DECLARE @LineAtYearSpots int = 30
  DECLARE @StdDevNewSpot int = 4
  DECLARE @RULNewSpot int = 30
  DECLARE @HoursPerDay float = 8.0
  DECLARE @PresentValueCap float = 0.1
  DECLARE @PresentValueCapCIPP float = .25--1.2
  
  CREATE TABLE #Costs
  (
    Compkey INT,
    NonMobCap FLOAT,
    Rate FLOAT,
    BaseTime FLOAT,
    MobTime FLOAT
  )
  
  TRUNCATE TABLE REHAB.GIS.REHAB_Branches_Prejudice
  
  INSERT INTO REHAB.GIS.REHAB_Branches_Prejudice(COMPKEY, [InitialFailYear], std_dev, ReplaceCost, SpotCost, /*LineCostwSpots,*/ LineCostNoSpots, grade_h5, globalID)
  SELECT  compkey, fail_yr, std_dev, replaceCost, SpotCost, /*LineCostNoSegsNoLats + SpotCost ,*/ LineCostNoSegsNoLats, grade_h5, globalID
  FROM    REHAB.GIS.REHAB_Segments AS A
  WHERE   cutno = 0
  
  UPDATE  A
  SET     A.prejudiceSpot = B.PrejudiceSpot
  FROM    REHAB.GIS.REHAB_Segments AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.ID = B.ID
              AND
              B.[Type] = 'S'
           
  UPDATE  A
  SET     A.prejudiceLine = B.PrejudiceLine
  FROM    REHAB.GIS.REHAB_Segments AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.ID = B.ID
              AND
              B.[Type] = 'L'
              
  UPDATE  A
  SET     A.prejudiceDig = B.PrejudiceDig
  FROM    REHAB.GIS.REHAB_Segments AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.ID = B.ID
              AND
              B.[Type] = 'W'
              
  UPDATE  A
  SET     A.prejudiceSpot = B.PrejudiceSpot
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.GLOBALID = B.GlobalID
              AND
              B.[Type] = 'S'
           
  UPDATE  A
  SET     A.prejudiceLine = B.PrejudiceLine
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.GLOBALID = B.GlobalID
              AND
              B.[Type] = 'L'
              
  UPDATE  A
  SET     A.prejudiceDig = B.PrejudiceDig
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          REHAB.dbo.COSTEST_PIPE AS B
          ON  A.GLOBALID = B.GlobalID
              AND
              B.[Type] = 'W'

  --Create present value table
  
  CREATE TABLE #PresentValue(Compkey int, WholePipe float, Liner float, Spot float, ReplaceCost float, LineCostNoSegsNoLats float, [Length] FLOAT)
  INSERT INTO #PresentValue (Compkey, ReplaceCost, LineCostNoSegsNoLats, [Length])
  SELECT  COMPKEY, ReplaceCost, LineCostNoSegsNoLats, [Length]
  FROM    REHAB.GIS.REHAB_Segments AS A
  WHERE   cutno = 0
  
  DECLARE @MaxWholeValue float = @PresentValueCap
  --Present value destroyed when replacing with a whole pipe
  UPDATE  A
  SET     WholePipe = CASE WHEN SumCost > @MaxWholeValue * ReplaceCost THEN ReplaceCost * @MaxWholeValue ELSE SumCost END
  FROM    #PresentValue AS A
          INNER JOIN
          (
            SELECT  COMPKEY, SUM(((PrejudiceSpot + ReplaceCost)*0.25) * CASE WHEN def_tot >= 1000 THEN 0 ELSE (1000.0-def_tot)/1000.0 END * CASE WHEN [action] = 3 THEN 0 ELSE 1 END) AS SumCost
            FROM    REHAB.GIS.REHAB_Segments
            WHERE   Cutno > 0
                    --AND
                    --fail_yr > @thisYear + @RULNewSpot
            GROUP BY COMPKEY
          )  AS B
          ON  A.Compkey = B.Compkey
          
  --Present value destroyed when replacing a sagging or ovaling whole pipe
  UPDATE  A
  SET     WholePipe = 0
  FROM    #PresentValue AS A
          INNER JOIN
          REHAB.GIS.REHAB_Branches_Prejudice  AS B
          ON  A.Compkey = B.Compkey
  WHERE   problems like '%sagging%'
          OR
          problems like '%ovaling%'
          
  --Present value destroyed when replacing with a liner
  UPDATE  A
  SET     Liner = CASE WHEN SumCost > @PresentValueCapCIPP/*@MaxWholeValue*/ * ReplaceCost THEN ReplaceCost * @PresentValueCapCIPP/*@MaxWholeValue*/ ELSE SumCost END
  FROM    #PresentValue AS A
          INNER JOIN
          (
            SELECT  COMPKEY, SUM(((ReplaceCost + PrejudiceSpot) *0.36) * CASE WHEN def_tot >= 1000 THEN 0 ELSE 1 * (1000.0-def_tot)/1000.0 END * CASE WHEN [action] = 3 THEN 0 ELSE 1 END * CASE WHEN fail_yr < @thisYear + @RULNewLiner*0.66 THEN 1 ELSE 3 END * CASE WHEN fail_yr < @thisYear + @RULNewLiner THEN 1 ELSE 3 END) AS SumCost
            FROM    REHAB.GIS.REHAB_Segments
            WHERE   Cutno > 0
                    --AND
                    --fail_yr > @thisYear + @RULNewSpot
            GROUP BY COMPKEY
          )  AS B
          ON  A.Compkey = B.Compkey
         
  --Present value destroyed when replacing with a spot (only affects linable defects that expire in this window)
  UPDATE  A
  SET     Spot = SumCost
  FROM    #PresentValue AS A
          INNER JOIN
          (
            SELECT  COMPKEY, SUM(((ReplaceCost + PrejudiceSpot) * 0.5) * CASE WHEN ([action] <> 3) THEN 1 ELSE 0 END ) AS SumCost
            FROM    REHAB.GIS.REHAB_Segments
            WHERE   Cutno > 0
                    AND
                    (
                      fail_yr_seg <= @thisYear + @SpotRotationFrequency
                      AND
                      def_tot >= 1000
                    )
            GROUP BY COMPKEY
          )  AS B
          ON  A.Compkey = B.Compkey
  

          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     SpotCost01 = ISNULL(B.TotalFirstSpotRepairs,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          (  
            SELECT  Z.compkey, SUM([CapitalNonMobilization] + Prejudice) + MAX([CapitalMobilizationRate])*(SUM(BaseTime) + MAX([MobilizationTime]))/@HoursPerDay AS TotalFirstSpotRepairs
            FROM    REHAB.GIS.REHAB_Segments AS Z
                    INNER JOIN
                    [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
                    ON  Z.ID = ZZ1.ID
                        AND
						ZZ1.[type] = 'Spot'
            WHERE   Z.cutno > 0
                    AND
                    (
                      (
                        Z.fail_yr_seg <= @thisYear + @SpotRotationFrequency
                        AND
                        Z.def_tot >= 1000
                      )
                      OR
                      [action] = 3
                    )
            GROUP BY Z.COMPKEY
          ) AS B
          ON  A.COMPKEY = B.compkey
          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     SpotCost02 = (ISNULL(B.TotalSecondSpotRepairs,0))
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          (  
            SELECT  Z.compkey, ((SUM([CapitalNonMobilization] + Prejudice) + MAX([CapitalMobilizationRate])*(SUM(BaseTime) + MAX([MobilizationTime]))/@HoursPerDay)) AS TotalSecondSpotRepairs
            FROM    REHAB.GIS.REHAB_Segments AS Z
                    INNER JOIN
                    [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
                    ON  Z.ID = ZZ1.ID
                        AND
						ZZ1.[type] = 'Spot'
            WHERE   cutno > 0
                    AND
                    --fail_yr_seg <= @thisYear + 2*@SpotRotationFrequency
                    --AND
                    fail_yr_seg > @thisYear + @SpotRotationFrequency
                    AND
                    (
                      Z.def_tot >= 1000
                      --OR
                      --[action] = 3
                    )
            GROUP BY Z.COMPKEY
          ) AS B
          ON  A.COMPKEY = B.compkey
  
                      
  --Cost to replace all of the near failing spots after the initial failure year     
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     SpotCostFail01 = ISNULL(B.TotalFirstSpotRepairs,0) 
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          (  
            SELECT  Z.compkey, (SUM([CapitalNonMobilization] + Prejudice) + MAX([CapitalMobilizationRate])*(SUM(BaseTime) + MAX([MobilizationTime]))/@HoursPerDay) AS TotalFirstSpotRepairs
            FROM    REHAB.GIS.REHAB_Segments AS Z
                    INNER JOIN
                    [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
                    ON  Z.ID = ZZ1.ID
                        AND
						ZZ1.[type] = 'Spot'
                    INNER JOIN
                    REHAB.GIS.REHAB_Branches_Prejudice AS X
                    ON  Z.compkey = X.compkey 
            WHERE   Z.cutno > 0
                    AND
                    Z.fail_yr_seg <= X.[InitialFailYear] + @SpotRotationFrequency
                    AND
                    (
                      Z.def_tot >= 1000
                      OR
                      [action] = 3
                    )
            GROUP BY Z.compkey
          ) AS B
          ON  A.COMPKEY = B.compkey
  
          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     SpotCostFail02 = ISNULL(B.TotalSecondSpotRepairs,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          (  
            SELECT  Z.compkey, SUM([CapitalNonMobilization] + Prejudice) + MAX([CapitalMobilizationRate])*(SUM(BaseTime) + MAX([MobilizationTime]))/@HoursPerDay AS TotalSecondSpotRepairs
            FROM    REHAB.GIS.REHAB_Segments AS Z
                    INNER JOIN
                    [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
                    ON  Z.ID = ZZ1.ID
                        AND
						ZZ1.[type] = 'Spot'
                    INNER JOIN
                    REHAB.GIS.REHAB_Branches_Prejudice AS X
                    ON  Z.compkey = X.compkey 
            WHERE   Z.cutno > 0
                    AND
                    --Z.fail_yr_seg <= X.[InitialFailYear] + 2*@SpotRotationFrequency
                    --AND
                    Z.fail_yr_seg > X.[InitialFailYear] + @SpotRotationFrequency
                    AND
                    (
                      Z.def_tot >= 1000
                      OR
                      [action] = 3
                    )
            GROUP BY Z.compkey
          ) AS B
          ON  A.COMPKEY = B.compkey       
          
          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWOCFail01 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  A.std_dev = B.std_dev
              AND 
              A.InitialFailYear = B.failure_yr 
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWOCFail02 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + @RULNewWholePipe= B.failure_yr 
  
  
  --On a reactive lining job, all bad spots are replaced
  
    
  TRUNCATE TABLE #Costs
  INSERT INTO #Costs ( Compkey, NonMobCap, Rate, BaseTime, MobTime )
  SELECT  Z.compkey, 
						SUM([CapitalNonMobilization]+Prejudice) AS SpotNonMobCap,
						MAX([CapitalMobilizationRate]) AS SpotRate,
						SUM(BaseTime) AS SpotBaseTime,
						MAX([MobilizationTime]) AS SpotMobTime
				FROM    REHAB.GIS.REHAB_Segments AS Z
						INNER JOIN
						[COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
						ON  Z.ID = ZZ1.ID
						    AND
						    ZZ1.[type] = 'Spot'
						INNER JOIN
						REHAB.GIS.REHAB_Branches_Prejudice AS X
						ON  Z.compkey = X.compkey 
				WHERE   Z.cutno > 0
						AND
						(
						  [action] = 3
						  OR
						  (
						    Z.def_tot >= 1000
						    AND
						    Z.fail_yr_seg <= X.[InitialFailYear] + @SpotRotationFrequency
						  )
						)
				GROUP BY Z.compkey
				
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail01 = (TotalSpotLineCost*@EmergencyFactor+C.MaxSegmentCOFwithoutReplacement)*ISNULL(B.unit_multiplier,0) 
  FROM    (
            SELECT Table1.COMPKEY, 
                   (ISNULL(NonMobCap,0) + LineNonMobCap) 
                   + (CASE WHEN ISNULL(Rate,0) > ISNULL(LineRate,0) THEN ISNULL(Rate,0) ELSE ISNULL(LineRate,0) END)
                   * (
                       CASE WHEN ISNULL(MobTime,0) > ISNULL(LineMobTime,0) THEN ISNULL(MobTime,0) ELSE ISNULL(LineMobTime,0) END
                       +
                       (ISNULL(BaseTime,0) + LineBaseTime)
                     )/@HoursPerDay AS TotalSpotLineCost
            FROM #Costs AS Table1
            INNER JOIN
            (
              SELECT  Compkey,
                      [CapitalNonMobilization]+Prejudice AS LineNonMobCap,
				      [CapitalMobilizationRate] AS LineRate,
					  BaseTime AS LineBaseTime,
					  [MobilizationTime] AS LineMobTime
              FROM    [COSTEST_CapitalCostsMobilizationRatesAndTimes]
              WHERE   [type] = 'Line'
                      AND 
                      ID < 40000000
            ) AS Table2
            ON Table1.Compkey = Table2.Compkey
          ) AS A
          INNER JOIN  
          REHAB.GIS.REHAB_Branches_Prejudice AS C
          ON  A.Compkey = C.Compkey
          INNER JOIN
          REHAB_UnitMultiplierTable AS B
          ON  C.std_dev = B.std_dev
              AND 
              C.InitialFailYear = B.failure_yr
  
  
               
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail02 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewLiner = B.std_dev
              AND 
              A.InitialFailYear + @RULNewLiner = B.failure_yr
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail03 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + @RULNewLiner +@RULNewWholePipe = B.failure_yr
              
  --Alternative whole pipe if BPWCIPPfail01 is greater than whole pipe
  --------------------------------------------------------------------
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail03 = CASE
                            WHEN  BPWCIPPfail01 > BPWOCFail01
                            THEN  0
                            ELSE  BPWCIPPfail03
                          END
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail02 = CASE
                            WHEN  BPWCIPPfail01 > BPWOCFail01
                            THEN  BPWOCFail02
                            ELSE  BPWCIPPfail02
                          END
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWCIPPfail01 = CASE
                            WHEN  BPWCIPPfail01 > BPWOCFail01
                            THEN  BPWOCFail01
                            ELSE  BPWCIPPfail01
                          END
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  
  --End of whole pipe alternative to spot repair
  -----------------------------------------------------
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail01 = (A.SpotCostFail01*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)*ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  A.std_dev = B.std_dev
              AND 
              A.InitialFailYear = B.failure_yr
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     LineAtYear = @LineAtYearSpots
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  WHERE   A.SpotCostFail02 > 0
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     LineAtYear = @LineAtYearNoSpots
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  WHERE   ISNULL(A.SpotCostFail02,0) = 0
  
  
  TRUNCATE TABLE #Costs
  INSERT INTO #Costs ( Compkey, NonMobCap, Rate, BaseTime, MobTime )
  SELECT  X.COMPKEY, 
						--Z.*, 
						ISNULL(SUM([CapitalNonMobilization] + Z.Prejudice),0) AS SpotNonMobCap,
						ISNULL(MAX([CapitalMobilizationRate]),0) AS SpotRate,
						ISNULL(SUM(BaseTime),0) AS SpotBaseTime,
						ISNULL(MAX([MobilizationTime]),0) AS SpotMobTime
				FROM    REHAB.GIS.REHAB_Branches_Prejudice AS X
						LEFT JOIN 
						(
						  [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS Z
				          INNER JOIN
						  REHAB.GIS.REHAB_Segments AS Y
						  ON  Z.ID = Y.ID
						      AND
						      Y.cutno > 0
						      --@LineAtYearSpots
						      AND
						      (
							    def_tot >= 1000
							    OR
							    [action] = 3
							  )
						)
						ON  X.Compkey = Z.COMPKEY
							AND
							Z.[type] = 'Spot'
							AND
							Y.fail_yr_seg  > X.[InitialFailYear] + X.LineAtYear
				GROUP BY X.COMPKEY
				
  --On a reactive liner job after a reactive spot job, only type 3 spots are replaced          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail02 = (TotalSpotLineCost*@EmergencyFactor+C.MaxSegmentCOFwithoutReplacement)*ISNULL(B.unit_multiplier,0) 
  FROM    (
            SELECT Table1.COMPKEY, 
                   (ISNULL(NonMobCap,0) + LineNonMobCap) 
                   + (CASE WHEN ISNULL(Rate,0) > ISNULL(LineRate,0) THEN ISNULL(Rate,0) ELSE ISNULL(LineRate,0) END)
                   * (
                       CASE WHEN ISNULL(MobTime,0) > ISNULL(LineMobTime,0) THEN ISNULL(MobTime,0) ELSE ISNULL(LineMobTime,0) END
                       +
                       (ISNULL(BaseTime,0) + LineBaseTime)
                     )/@HoursPerDay AS TotalSpotLineCost
            FROM   #Costs AS Table1
            INNER JOIN
            (
              SELECT  Compkey,
                      [CapitalNonMobilization] + Prejudice AS LineNonMobCap,
				      [CapitalMobilizationRate] AS LineRate,
					  BaseTime AS LineBaseTime,
					  [MobilizationTime] AS LineMobTime
              FROM    [COSTEST_CapitalCostsMobilizationRatesAndTimes]
              WHERE   [type] = 'Line'
                      AND 
                      ID < 40000000
            ) AS Table2
            ON Table1.Compkey = Table2.Compkey
          ) AS A
          INNER JOIN  
          REHAB.GIS.REHAB_Branches_Prejudice AS C
          ON  A.Compkey = C.Compkey
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewSpot = B.std_dev
              AND 
              C.InitialFailYear + C.LineAtYear = B.failure_yr
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail03 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewLiner = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear + @RULNewLiner = B.failure_yr  

  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail04 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear + @RULNewLiner + @RULNewWholePipe = B.failure_yr 
              
  --Alternative whole pipe if BPWSPfail02 is greater than whole pipe
  --------------------------------------------------------------------
  --Set them all to 0 if it is more expensive to do liner than whole pipe
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail04 = CASE
                          WHEN  BPWSPfail02 > ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  BPWSPfail04
                        END,
          BPWSPfail03 = CASE
                          WHEN  BPWSPfail02 > ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  BPWSPfail03
                        END,
          BPWSPfail02 = CASE
                          WHEN  BPWSPfail02 > ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  BPWSPfail02
                        END
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear = B.failure_yr
  
  --Now just update the ones that are 0
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail04 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear + @RULNewWholePipe * 2 = B.failure_yr
              AND
              BPWSPFail04 = 0
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail03 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear + @RULNewWholePipe = B.failure_yr
              AND
              BPWSPFail03 = 0
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWSPfail02 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A 
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              A.InitialFailYear + A.LineAtYear = B.failure_yr   
              AND
              BPWSPFail02 = 0 
 ----------------------------------------------------------------------------------------------------
 ----------------------------------------------------------------------------------------------------
 --APW
 ----------------------------------------------------------------------------------------------------
 ----------------------------------------------------------------------------------------------------
 UPDATE   REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWOC01 = (A.ReplaceCost + A.PrejudiceDig)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  
  
  --PresentValue
  UPDATE   REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWOC01 = ISNULL(APWOC01,0) + ISNULL(WholePipe,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          #PresentValue AS B
          ON A.Compkey = B.Compkey

  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWOC02 = ((A.ReplaceCost + A.PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + @RULNewWholePipe= B.failure_yr 
  
  --On a proactive liner job, just replace all type 3 spots
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWCIPP01 = (TotalSpotLineCost)
  FROM    (
            SELECT Table1.COMPKEY, 
                   (ISNULL(SpotNonMobCap,0) + LineNonMobCap) 
                   + (CASE WHEN ISNULL(SpotRate,0) > ISNULL(LineRate,0) THEN ISNULL(SpotRate,0) ELSE ISNULL(LineRate,0) END)
                   * (
                       CASE WHEN ISNULL(SpotMobTime,0) > ISNULL(LineMobTime,0) THEN ISNULL(SpotMobTime,0) ELSE ISNULL(LineMobTime,0) END
                       +
                       (ISNULL(SpotBaseTime,0) + LineBaseTime)
                     )/@HoursPerDay AS TotalSpotLineCost
            FROM
            (
				/*SELECT  Z.compkey, 
						SUM([CapitalNonMobilization]) AS SpotNonMobCap,
						MAX([CapitalMobilizationRate]) AS SpotRate,
						SUM(BaseTime) AS SpotBaseTime,
						MAX([MobilizationTime]) AS SpotMobTime
				FROM    REHAB.GIS.REHAB_Segments AS Z
						INNER JOIN
						[COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
						ON  Z.ID = ZZ1.ID
						    AND
						    ZZ1.[type] = 'Spot'
						INNER JOIN
						REHAB.GIS.REHAB_Branches_Prejudice AS X
						ON  Z.compkey = X.compkey 
				WHERE   Z.cutno > 0
						AND
						(
						  [action] = 3
						)
				GROUP BY Z.compkey*/
				SELECT  X.compkey, 
						ISNULL(SUM([CapitalNonMobilization]+Prejudice),0) AS SpotNonMobCap,
						ISNULL(MAX([CapitalMobilizationRate]),0) AS SpotRate,
						ISNULL(SUM(BaseTime),0) AS SpotBaseTime,
						ISNULL(MAX([MobilizationTime]),0) AS SpotMobTime
				FROM    REHAB.GIS.REHAB_Branches_Prejudice AS X
				        LEFT OUTER JOIN
				        (
				          REHAB.GIS.REHAB_Segments AS Z
				          INNER JOIN
						  [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS ZZ1
						  ON  Z.ID = ZZ1.ID
						      AND
						      ZZ1.[type] = 'Spot'
						      AND
						      [action] = 3
						      AND
						      Z.cutno = 0
						)
						ON  X.compkey = Z.compkey
                GROUP BY X.compkey
            ) AS Table1
            INNER JOIN
            (
              SELECT  Compkey,
                      [CapitalNonMobilization]+Prejudice AS LineNonMobCap,
				      [CapitalMobilizationRate] AS LineRate,
					  BaseTime AS LineBaseTime,
					  [MobilizationTime] AS LineMobTime
              FROM    [COSTEST_CapitalCostsMobilizationRatesAndTimes]
              WHERE   [type] = 'Line'
                      AND 
                      ID < 40000000
            ) AS Table2
            ON Table1.Compkey = Table2.Compkey
          ) AS A
          INNER JOIN  
          REHAB.GIS.REHAB_Branches_Prejudice AS C
          ON  A.Compkey = C.Compkey
          
  --PresentValue
  UPDATE   REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWCIPP01 = ISNULL(APWCIPP01,0) + ISNULL(Liner,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          #PresentValue AS B
          ON A.Compkey = B.Compkey
               
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWCIPP02 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewLiner = B.std_dev
              AND 
              @thisYear + @RULNewLiner = B.failure_yr
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWCIPP03 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + @RULNewLiner +@RULNewWholePipe = B.failure_yr
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP01 = A.SpotCost01
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  
  --PresentValue
  UPDATE   REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP01 = ISNULL(APWSP01,0) + ISNULL(Spot,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN
          #PresentValue AS B
          ON A.Compkey = B.Compkey
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     LineAtYearAPW = @LineAtYearSpots
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  WHERE   A.SpotCost02 > 0
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     LineAtYearAPW = @LineAtYearNoSpots
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
  WHERE   ISNULL(A.SpotCost02,0) = 0
   
  --This is a reactive liner year after a proactive spot year.  Replace only type 3 spots  
  --because we are assumed to have replaced any really bad 1000+ point segments during the spot repair portion         
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP02 = (TotalSpotLineCost*@EmergencyFactor+C.MaxSegmentCOFwithoutReplacement)*ISNULL(B.unit_multiplier,0) 
  FROM    (
            SELECT Table1.COMPKEY, 
                   (ISNULL(SpotNonMobCap,0) + LineNonMobCap) 
                   + (CASE WHEN ISNULL(SpotRate,0) > ISNULL(LineRate,0) THEN ISNULL(SpotRate,0) ELSE ISNULL(LineRate,0) END)
                   * (
                       CASE WHEN ISNULL(SpotMobTime,0) > ISNULL(LineMobTime,0) THEN ISNULL(SpotMobTime,0) ELSE ISNULL(LineMobTime,0) END
                       +
                       (ISNULL(SpotBaseTime,0) + LineBaseTime)
                     )/@HoursPerDay AS TotalSpotLineCost
            FROM
            (
				SELECT  X.COMPKEY, 
        --Z.*, 
        ISNULL(SUM([CapitalNonMobilization] + Prejudice),0) AS SpotNonMobCap,
		ISNULL(MAX([CapitalMobilizationRate]),0) AS SpotRate,
		ISNULL(SUM(BaseTime),0) AS SpotBaseTime,
		ISNULL(MAX([MobilizationTime]),0) AS SpotMobTime
FROM    REHAB.GIS.REHAB_Branches_Prejudice AS X
        LEFT JOIN 
        (
          [COSTEST_CapitalCostsMobilizationRatesAndTimes] AS Z
          INNER JOIN
          REHAB.GIS.REHAB_Segments AS Y
		  ON  Z.ID = Y.ID
		  AND
		  Y.cutno > 0
		  --@LineAtYearSpots
		  AND
          (
            def_tot >= 1000
            OR
            [action] = 3
          )
		)
		ON  X.Compkey = Z.COMPKEY
            AND
            Z.[type] = 'Spot'
            AND
		    Y.fail_yr_seg > @thisYear + @SpotRotationFrequency
GROUP BY X.COMPKEY
            ) AS Table1
            INNER JOIN
            (
              SELECT  Compkey,
                      [CapitalNonMobilization] + Prejudice AS LineNonMobCap,
				      [CapitalMobilizationRate] AS LineRate,
					  BaseTime AS LineBaseTime,
					  [MobilizationTime] AS LineMobTime
              FROM    [COSTEST_CapitalCostsMobilizationRatesAndTimes]
              WHERE   [type] = 'Line'
                      AND 
                      ID < 40000000
            ) AS Table2
            ON Table1.Compkey = Table2.Compkey
          ) AS A
          INNER JOIN  
          REHAB.GIS.REHAB_Branches_Prejudice AS C
          ON  A.Compkey = C.Compkey
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewSpot = B.std_dev
              AND 
              @thisYear + C.LineAtYearAPW = B.failure_yr
			
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP03 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @StdDevNewLiner = B.std_dev
              AND 
              @thisYear + A.LineAtYearAPW + @RULNewLiner = B.failure_yr  

  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP04 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + A.LineAtYearAPW + @RULNewLiner + @RULNewWholePipe = B.failure_yr   
              
  --Check to see if it is more expensive to line in   APWSP02 than it is to whole pipe replace.
  --Alternative whole pipe if BPWSPfail02 is greater than whole pipe
  --------------------------------------------------------------------
  --Set them all to 0 if it is more expensive to do liner than whole pipe
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP04 = CASE
                          WHEN  APWSP02 > (A.ReplaceCost*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  APWSP04
                        END,
          APWSP03 = CASE
                          WHEN  APWSP02 > (A.ReplaceCost*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  APWSP03
                        END,
          APWSP02 = CASE
                          WHEN  APWSP02 > (A.ReplaceCost*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
                          THEN  0
                          ELSE  APWSP02
                        END
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + A.LineAtYear = B.failure_yr
  
  --Now just update the ones that are 0
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP04 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + A.LineAtYear + @RULNewWholePipe * 2 = B.failure_yr
              AND
              APWSP04 = 0
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP03 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + A.LineAtYear + @RULNewWholePipe = B.failure_yr
              AND
              APWSP03 = 0
              
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     APWSP02 = ((A.ReplaceCost+PrejudiceDig)*@EmergencyFactor+A.MaxSegmentCOFwithoutReplacement)* ISNULL(B.unit_multiplier,0)
  FROM    REHAB.GIS.REHAB_Branches_Prejudice AS A 
          INNER JOIN  
          REHAB_UnitMultiplierTable AS B
          ON  @MaxStdDev = B.std_dev
              AND 
              @thisYear + A.LineAtYear = B.failure_yr   
              AND
              APWSP02 = 0       
  --------------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------------
  --nBCR Section
  --The nBCR names start with nBCR, then underscore, and the assumed ASM solution, then underscore, then the possible alternatives
  --------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------- 
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPWOC = BPWOCfail01+ISNULL(BPWOCfail02,0),
          BPWCIPP = BPWCIPPfail01+BPWCIPPfail02+ISNULL(BPWCIPPfail03,0),
          BPWSP = BPWSPfail01+BPWSPfail02+ISNULL(BPWSPfail03,0)+ISNULL(BPWSPfail04,0),
          APWOC = APWOC01+ISNULL(APWOC02,0),
          APWCIPP = APWCIPP01+APWCIPP02+ISNULL(APWCIPP03,0),
          APWSP = APWSP01+APWSP02+ISNULL(APWSP03,0)+ISNULL(APWSP04,0) 
          
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     BPW = (
                    SELECT  MIN(v) 
                    FROM   (VALUES (BPWOC),(BPWCIPP),(BPWSP)) AS value(v)
                  )
 
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     nBCR_OC = ((BPW - APWOC))/(APWOC)
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     nBCR_CIPP = ISNULL((BPW-APWCIPP)/APWCIPP, -10)       
  
  UPDATE  REHAB.GIS.REHAB_Branches_Prejudice
  SET     nBCR_SP = ISNULL((BPW-APWSP)/APWSP, -10)
  

UPDATE A
SET    PVLostWhole = WholePipe,
       PVLostLiner = Liner,
       PVLostSpot  = Spot
FROM   GIS.REHAB_Branches_Prejudice AS A
       INNER JOIN
       #PresentValue AS B
       ON  A.Compkey = B.Compkey

DROP TABLE #Costs
DROP TABLE #PresentValue
  
END




GO

