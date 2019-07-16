USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[USP_EC_01]    Script Date: 7/16/2019 10:07:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/****** Script for SelectTopNRows command from SSMS  ******/
CREATE PROCEDURE [dbo].[USP_EC_01]
AS
BEGIN
  
  IF OBJECT_ID('tempdb.dbo.#BaseSubset', 'U') IS NOT NULL DROP TABLE #BaseSubset;
  IF OBJECT_ID('tempdb.dbo.#PrimarySubset', 'U') IS NOT NULL DROP TABLE #PrimarySubset;
  IF OBJECT_ID('tempdb.dbo.#SecondarySubset', 'U') IS NOT NULL DROP TABLE #SecondarySubset;
  IF OBJECT_ID('tempdb.dbo.#FinalSubset', 'U') IS NOT NULL DROP TABLE #FinalSubset;
  IF OBJECT_ID('tempdb.dbo.#MiscellaneousCosts', 'U') IS NOT NULL DROP TABLE #MiscellaneousCosts;
  IF OBJECT_ID('tempdb.dbo.#Laterals', 'U') IS NOT NULL DROP TABLE #Laterals;
  IF OBJECT_ID('tempdb.dbo.#ManholeCosts', 'U') IS NOT NULL DROP TABLE #ManholeCosts;
  
  DECLARE @Var_MHAct_OC int = 2
  --OCFinalCostCalculations
  DECLARE @Var_CCI_Base float = 8090
  DECLARE @Var_CCI_Curr float = 10092
  DECLARE @ProjContingencyPercent float = 25
  DECLARE @UtilityCrossingCost float = 5000
  
  
  DECLARE @IndirectProjectCostsPercent float = 15
  DECLARE @DesignPercent float = 20
  DECLARE @ICEasementsAndEnvironmentalPercent float = 1
  DECLARE @PublicInvolvementPercent float = 3
  DECLARE @StartupAndCloseoutPercent float = 1
  
  --Standard unit constants
  DECLARE @CubicFeetPerCubicYard float = 27.0
  DECLARE @SquareFeetPerAcre float = 43560
  
  DECLARE @Var_Rate_Exc float = 140 --CY/day
  DECLARE @Var_Rate_UtilX float = 0.5 --days per crossing
  DECLARE @Var_Rate_Pave float = 250 --feet/day
  
  --Lateral Variables
  DECLARE @Var_LatCost float = 3000
  DECLARE @Var_LatPercent_OC float = 60
  
  --Bypass pumping variables
  DECLARE @Var_Cost_Byp_3 float = 500
  DECLARE @Var_Cost_Byp_7 float = 1000
  DECLARE @Var_Cost_Byp_15 float = 2000
  DECLARE @Var_Cost_Byp_Other float = 3000
  
  --Environmental Variables
  DECLARE @Var_Price_Haz float = 50 --Dollars per cubic yard
  DECLARE @Var_Price_Env float = 150000 -- Dollars per acre
  
  --Economic variables
  DECLARE @Var_CCI_Factor float =  @Var_CCI_Curr/@Var_CCI_Base
  DECLARE @Var_LifeFactor float =  (1 + @ProjContingencyPercent/100.0)
                                  *(1 +
                                       (
                                          @IndirectProjectCostsPercent
                                        + @DesignPercent
                                        + @ICEasementsAndEnvironmentalPercent
                                        + @PublicInvolvementPercent
                                        + @StartupAndCloseoutPercent
                                       )/100.0
                                   )
                                   
  CREATE TABLE #ManholeCosts (Compkey int, MH_MinD float, MH_Base float, MH_Rim float, MH_DepthCost float, MH_Factor float, MH_FinalCost float, MH_LifeCost_Used float)
  
  CREATE TABLE #BaseSubset (Compkey int, OC_TWidth float, OC_TDepth float)
  INSERT INTO #BaseSubSet (Compkey, OC_TWidth, OC_TDepth)
  SELECT  hansen_Compkey 
          ,[GIS].[COSTEST_EC_FindTrenchWidth](
                                        Material 
                                        ,A.DiamWidth 
                                        ,(uDepth+DDepth) /2.0
                                       ) AS OC_TWidth
          ,[GIS].[COSTEST_EC_FindTrenchDepth_OC](
                                           Material 
                                           ,A.DiamWidth 
                                           ,(uDepth+DDepth) /2.0
                                         ) AS OC_TDepth
  FROM    REHAB.dbo.COSTEST_PIPEXP AS A
          INNER JOIN
          [REHAB].[GIS].[nBCR_Data] AS B
          ON  A.hansen_compkey = B.COMPKEY
              AND
              A.Cutno = 0
              AND
              B.Cutno = 0
  WHERE   hansen_compkey = 101726
  
  CREATE TABLE #PrimarySubset (Compkey int, Byp_FlowRt float, OC_ExcVol float, xUtilCount float)
  INSERT INTO  #PrimarySubset (Compkey, Byp_FlowRt, OC_ExcVol, xUtilCount)
  SELECT  hansen_Compkey, 
          CASE
            WHEN  xPipSlope <= 0 OR xPipSlope = ''
            THEN  2*0.2*PI()*0.25*(POWER(DiamWidth/12.0,2))
            ELSE  0.2*0.464/0.013*(POWER(DiamWidth/12.0,(8.0/3.0))*(POWER(xPipSlope,0.5)))
          END AS Byp_FlowRt
          ,OC_TWidth*((uDepth+DDepth) /2.0)/@CubicFeetPerCubicYard AS OC_ExcVol
          ,ISNULL(xGas,0)+ISNULL(xFiber,0)+ISNULL(xSewer,0)+ISNULL(xWtr,0) AS xUtilCount
  FROM    REHAB.dbo.COSTEST_PIPEXP AS A
          INNER JOIN
          #BaseSubset AS B
          ON  A.hansen_compkey = B.Compkey
  WHERE   CutNo = 0
          AND
          hansen_compkey = 101726
  
  CREATE TABLE #SecondarySubset (Compkey int, Byp_DailyCost float, ConDays_Repair_OC float, ConDays_MH_OC float)
  
  INSERT INTO #SecondarySubset (Compkey, Byp_DailyCost, ConDays_Repair_OC)        
  SELECT  Compkey, 
          CASE
            WHEN  Byp_FlowRt <= 3
            THEN  @Var_Cost_Byp_3
            WHEN  Byp_FlowRt <= 7
            THEN  @Var_Cost_Byp_7
            WHEN  Byp_FlowRt <= 15
            THEN  @Var_Cost_Byp_15
            ELSE  @Var_Cost_Byp_Other
          END AS Byp_DailyCost  
          ,OC_ExcVol*[length]/@Var_Rate_Exc+@Var_Rate_UtilX*xUtilCount+[length]/@Var_Rate_Pave AS ConDays_Repair_OC
  FROM    REHAB.dbo.COSTEST_PIPEXP AS A
          INNER JOIN
          #PrimarySubset AS B
          ON  A.hansen_compkey = B.Compkey
  WHERE   CutNo = 0
          AND
          hansen_compkey = 101726
          
  UPDATE  #SecondarySubset
  SET     ConDays_MH_OC = 
          CASE
            WHEN @Var_MHAct_OC=2
            THEN CASE WHEN 25 < CASE WHEN 10 > OC_TDepth THEN 10 ELSE OC_TDepth END THEN 25 ELSE CASE WHEN 10 > OC_TDepth THEN 10 ELSE OC_TDepth END END 
            ELSE 0
          END / 10.0
  FROM    #SecondarySubset AS A
          INNER JOIN
          #BaseSubset AS B
          ON  A.Compkey = B.Compkey
  
  --Miscellaneous Costs
  CREATE TABLE #MiscellaneousCosts (Compkey int, Cost_Haz float, Cost_Env float)
  
  INSERT INTO #MiscellaneousCosts (Compkey, Cost_Haz, Cost_Env)
  SELECT  Compkey
          ,CASE
            WHEN  ISNULL(B.xECSI,0) > 0
            THEN  ((CASE WHEN xECSILen > 50 THEN 50 ELSE xECSILen END)/[length])*(OC_ExcVol*[length])* @Var_Price_Haz
            ELSE  0
          END AS Cost_Haz
          ,CASE
            WHEN  ISNULL(xEzonC, 0) > 0 OR ISNULL(xEzonP, 0) > 0
            THEN  (ISNULL(xFtEzonP,0)+ISNULL(xFtEZonC,0))*25*@Var_Price_Env/@SquareFeetPerAcre
            ELSE  0 
          END AS Cost_Env
  FROM    #PrimarySubset AS A
          INNER JOIN
          COSTEST_PIPEXP AS B
          ON  A.Compkey = B.hansen_Compkey
              AND
              B.Cutno = 0
          
  CREATE TABLE #Laterals (Compkey int, Lat_EstRepl_OC float, Lat_LatCost_OC float)
  
  INSERT INTO  #Laterals (Compkey, Lat_EstRepl_OC)
  SELECT  Compkey
          ,CEILING(@Var_LatPercent_OC*ISNULL(lateralCount,0))  
  FROM    REHAB.GIS.nBCR_Data
  
  UPDATE  #Laterals
  SET     Lat_LatCost_OC = Lat_EstRepl_OC * @Var_LatCost
  
  
  CREATE TABLE #FinalSubset (Compkey int, Total_OC float)
  
  INSERT INTO #FinalSubset (Compkey, Total_OC)        
  SELECT  Compkey
          ,1  AS Total_OC      
          --=((IF(OR(L7="PVC",L7="HDPE"),DT7,IF(OR(L7="VCP",L7="VSP"),DX7,EB7))+HS7+HR7+HA7+IF(@Var_MHAct_OC=2,GW7,0))*(1+Var_GenCond+Var_WasteAllow)+HQ7+HN7+FC7+EL7+ET7)*Var_CCI_Factor*AS7
          /*
            (
              (
                IF(
                  OR(Material="PVC",v="HDPE")
                  ,Cost_DCC_PVC
                  ,IF(
                     OR(Material="VCP",Material="VSP")
                     ,Cost_DCC_Clay
                     ,EB7
                     )
                  )
                +Cost_Haz+Cost_Env+Lat_LatCost_OC
                +IF(
                     @Var_MHAct_OC=2
                     ,MH_FinalCost
                     ,0
                  )
              )
                *(1+Var_GenCond+Var_WasteAllow)+HQ7+HN7+FC7+EL7+ET7
            )*Var_CCI_Factor*AS7
          
          */
          
  FROM    #SecondarySubset AS A
   
  SELECT * FROM #BaseSubset       
  SELECT * FROM #PrimarySubset
  SELECT * FROM #SecondarySubset
  SELECT * FROM #FinalSubSet
  
  SELECT  Hansen_Compkey,
          CASE
            WHEN  HardArea > 0
            THEN  1.5
            ELSE  1.0
          END 
          *
          CASE
            WHEN  gSlope > 0.1
            THEN  1.5
            ELSE  1.0
          END
          *
          CASE
            WHEN  xRail > 0 OR xLRT > 0
            THEN  1.5
            ELSE  1.0
          END
          AS DifficultWorkAreaMultiplier,
          @UtilityCrossingCost * (ISNULL(xFiber,0)+ISNULL(xGas,0)+ISNULL(xSewer,0)+ISNULL(xWtr,0)) AS Cost_Crossing,
          CASE
            WHEN  pWtr > 0
            THEN  7.9126*pWtrMaxD+74.093
            ELSE  0
          END  AS Cost_pWater
          ,Byp_DailyCost*(ConDays_Repair_OC+ConDays_MH_OC) AS Byp_OC
  FROM    REHAB.dbo.COSTEST_PIPEXP AS A
          INNER JOIN
          #SecondarySubset AS B
          ON  A.Hansen_Compkey = B.Compkey
  WHERE   CutNo = 0
          AND
          hansen_compkey = 101726   
     
  
  DROP TABLE #BaseSubset      
  DROP TABLE #PrimarySubset
  DROP TABLE #SecondarySubset
  DROP TABLE #FinalSubset
  DROP TABLE #MiscellaneousCosts
  DROP TABLE #Laterals
  DROP TABLE #ManholeCosts
  
  /*
  SELECT  @Var_CCI_Factor*DifficultWorkAreaMultiplier*
          (
            Cost_Crossing+Cost_pWater+BypOC+EL7+ET7+
            (1+Var_GenCond+Var_WasteAllow)
            *
            (
              CASE
                WHEN  Material IN ('PVC', 'HDPE')
                THEN  DT7
                WHEN  Material IN ('VCP', 'VSP')
                THEN  DX7
                ELSE  EB7
              END + HS7 +HR7 + HA7 + 
              CASE
                WHEN  @Var_MHAct_OC=2
                THEN  GW7
                ELSE  0
              END
            )
          )
          
  FROM    [REHAB].[GIS].[nBCR_Data]
  WHERE   Compkey = 101726
  */
  
  /*
    SELECT  OCFinalCost * @Var_LifeFactor AS OCFinalLifeCost
    FROM    [REHAB].[GIS].[nBCR_Data]
  */
  
  END
GO

