USE [REHAB]
GO

/****** Object:  StoredProcedure [dbo].[COST_ESTIMATOR_WHOLE]    Script Date: 7/16/2019 9:52:32 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:    Gardner, Issac
-- Create date: 8/14/2015
-- Description:  This stored procedure does not need to be run,
-- but if you wish to run it, it must 
-- be run after [dbo].[COST_ESTIMATOR]
-- It may be beneficial to merge the two in the future.

--Tables used by this stored procedure:
--
--[Rehab10FtSegs]
--
-- =============================================

CREATE PROCEDURE [dbo].[COST_ESTIMATOR_WHOLE] @inputCOMPKEY INT = 0
AS
BEGIN
DECLARE @ENR FLOAT --1.7375
DECLARE @CCIBase FLOAT
DECLARE @CCICurrent FLOAT
DECLARE @EmergencyRepairFactor FLOAT = 1.4

--Apply the codes to those variables
SELECT TOP 1 @CCICurrent = [cci_value] FROM [REHAB].[dbo].[COSTEST_ENR] order by theDate desc--1.7375
SELECT @CCIBase = 8090--Jan 2008
SET @ENR = @CCICurrent/@CCIBase
  DECLARE @DifficultAreaFactor FLOAT = 1.5
  DECLARE @CubicFeetPerCubicYard FLOAT = 27
  DECLARE @SquareFeetPerSquareYard  FLOAT = 9
  DECLARE @SquareFeetPerAcre FLOAT = 43560
  DECLARE @InchesPerYard FLOAT = 36
  DECLARE @InchesPerFoot FLOAT = 12
  DECLARE @PipeZoneDepthAdditionalInches FLOAT = 18
  DECLARE @MaxManholeDepth FLOAT = 25
  DECLARE @PipeMainlineBuildRate FLOAT = 140.0 --cubic yards per day
  DECLARE @ManholeBuildRate FLOAT = 10.0 --ft per day
  DECLARE @UtilityCrossingRate FLOAT = 0.5 --days/crossing
  DECLARE @PavementRepairRate FLOAT = 250 -- Ft/day
  DECLARE @SlowBoreRate FLOAT = 75 -- Ft/day
  DECLARE @FastBoreRate FLOAT = 125 -- Ft/day
  DECLARE @BoringJackingCost FLOAT = 566.95 -- Dollars/thing
  DECLARE @GeneralConditionsFactor FLOAT = 0.1
  DECLARE @WasteAllowanceFactor FLOAT = 0.05
  DECLARE @ContingencyFactor FLOAT = 0.25
  DECLARE @ConstructionManagementInspectionTestingFactor FLOAT = 0.15
  DECLARE @DesignFactor FLOAT = 0.2
  DECLARE @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor FLOAT = 0.03
  DECLARE @StartupCloseoutFactor FLOAT = 0.01
  DECLARE @MinShoringDepth FLOAT = 18.0
  DECLARE @daysForWholePipeLinerConstruction FLOAT = 3.0
  DECLARE @WorkingHoursPerDay FLOAT = 8.0
  
  DECLARE @CostOfLaterals INT
  SELECT @CostOfLaterals = EMLateralRepairCost FROM Constants
  
  -------------------------------------
  -- Insert all of the IDs into the Cost Estimator table
  
  DELETE FROM COSTEST_PIPEDETAILS
  WHERE ID < 40000000
  
  INSERT INTO COSTEST_PIPEDETAILS (ID, GLOBALID, USnode, DSNode, [length], diamWidth, height, cutno, compkey)
  SELECT ID, GLOBALID, USNode, DSNode, [length], diamwidth, height, cutno, compkey FROM GIS.REHAB_Segments
  WHERE ID < 40000000
  
  ALTER INDEX ALL ON COSTEST_PIPEDETAILS REBUILD
  
  
  -------------------------------------
  -- Set the outsideDiameter
  -- This procedure needs to be near the top, as many calcs after this depend on this one
  UPDATE COSTEST_PIPEDETAILS
  SET    [OutsideDiameter] = GIS.COSTEST_Interpolate_OutsideDiameter(B.diamwidth, B.height)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         GIS.REHAB_Segments AS B
         ON  A.ID = B.ID
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
  
  -------------------------------------
  -- Set the Trench base width
  -- This procedure needs to be near the top, as many calcs after this depend on this one
  UPDATE COSTEST_PIPEDETAILS
  SET    [TrenchBaseWidth] = GIS.COSTEST_Interpolate_TrenchWidth(B.diamwidth, B.height)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         GIS.REHAB_Segments AS B
         ON  A.ID = B.ID
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--

  -------------------------------------
  -- Set the excavation volume
  -- This procedure needs to be near the top, as many calcs after this depend on this one
  ----------
  -- ExcavationVolume (yd^3/ft)= Average pipe depth (ft) * Trench Base width (ft) * (1yd^3/27ft^3)
  UPDATE COSTEST_PIPEDETAILS
  SET    [ExcavationVolume] = ((uDepth + dDepth)/2)*[TrenchBaseWidth]/@CubicFeetPerCubicYard
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
  
  -------------------------------------
  --pWtrMaxD
  --pWtr
  ----------
  -- pWtrMaxD = inside diameter of largest water line in proximity
  -- pWtr = water line in proximity
  ----------
  -- Is pWtr > 0?
  ----Yes
  -----Cost for parallel Relocation ($) = $7.9126*pWtrMaxD + $74.093
  UPDATE COSTEST_PIPEDETAILS
  SET    [ParallelWaterRelocation] = pWtrRelocationCostPerInch * pWtrMaxD + pWtrRelocationCostBase
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
             AND
             B.pWtr > 0
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants
         
  -------------------------------------
  --xSewer
  --xWtr
  --xGas
  --xFiber
  ----------
  -- xSewer : does the conduit cross a Sewer line?
  -- xWtr : does the conduit cross a water line?
  -- xGas : does the conduit cross a gas line?
  -- xFiber : does the conduit cross a fiber line?
  ----------
  -- Sum xSewer, xWtr, xGas, xFiber, multiply the result by 5000 to get the Crossing Relocation cost
  UPDATE COSTEST_PIPEDETAILS
  SET    [CrossingRelocation] = UtilityCrossingCost * 
                                (
                                  ISNULL(xSewer,0) 
                                  + ISNULL(xWtr,0) 
                                  + ISNULL(xGas,0) 
                                  + ISNULL(xFiber,0)
                                )
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants
  
  -------------------------------------
  -- Segment Length (used to be xEcsiLen)
  -- xEcsi
  ----------
  -- xEcsiLen : length of segment within 50' of contamination site
  -- xEcsi: located near contamination site
  ----------
  -- Hazardous materials cost = 
  UPDATE COSTEST_PIPEDETAILS
  SET    [HazardousMaterials] = (CASE WHEN A.[length] > 50 THEN 50 ELSE A.[length] END) * A.[ExcavationVolume] * HazardousMaterialsCost
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants
  WHERE  B.xEcsi > 0
  
  -------------------------------------
  -- xFtEzonC
  -- xFtEzonP
  ----------
  -- 
  ----------
  -- Environmental mitigation cost = 
  UPDATE COSTEST_PIPEDETAILS
  SET    [EnvironmentalMitigation] = C.EnvMitigationUnitCost*(ISNULL(B.xFtEzonC,0)*C.EnvMitigationWidth + ISNULL(B.xFtEzonP,0) * C.EnvMitigationWidth)/@squareFeetPerAcre
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants AS C
  WHERE  B.xFtEzonC > 0
         OR
         B.xFtEzonP > 0
  
  -------------------------------------
  -- Asphalt removal, trench patch, and base course
  ----------
  -- trench base width
  ----------
  -- 
  UPDATE COSTEST_PIPEDETAILS
  SET    --AsphaltRemovalWidth = A.TrenchBaseWidth + C.ExcessAsphaltWidth,
         --AsphaltRemovalArea = AsphaltRemovalWidth / @SquareFeetPerSquareYard,
         --AsphaltConcreteBaseVolume = AsphaltRemovalWidth*C.AsphaltBaseCourseDepth/@CubicFeetPerCubicYard,
         --A.AsphaltRemoval = C.AsphaltRemovalUnitCost * AsphaltRemovalArea * A.[length],
         --A.AsphaltTrenchPatch = AsphaltRemovalArea * C.TrenchPatchAsphaltCost * A.[length],
         --A.AsphaltTrenchPatchBaseCourse = AsphaltConcreteBaseVolume * C.AsphaltTrenchPatchBaseCourseCost* A.[length]
         AsphaltRemoval = C.AsphaltRemovalUnitCost * ((A.TrenchBaseWidth + C.ExcessAsphaltWidth) / @SquareFeetPerSquareYard) * A.[length],
         --AsphaltTrenchPatch = ((A.TrenchBaseWidth + C.ExcessAsphaltWidth) / @SquareFeetPerSquareYard) * C.TrenchPatchAsphaltCost * A.[length],
         AsphaltBaseCourse = ((A.TrenchBaseWidth + C.ExcessAsphaltWidth)*C.AsphaltBaseCourseDepth/@CubicFeetPerCubicYard) * C.AsphaltTrenchPatchBaseCourseCost* A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         CROSS JOIN 
         dbo.Constants AS C
  WHERE  A.ID < 40000000
  
  UPDATE COSTEST_PIPEDETAILS
  SET    AsphaltTrenchPatch = ((A.TrenchBaseWidth + C.ExcessAsphaltWidth) / @SquareFeetPerSquareYard) * GIS.COSTEST_Find_TrenchPatchCost(B.hardArea, B.pStrtTyp) * A.[length]
  FROM   (
           COSTEST_PIPEDETAILS AS A
           INNER JOIN
           COSTEST_PipeXP AS B
           ON  A.ID = B.ID
         )
         CROSS JOIN 
         dbo.Constants AS C
  WHERE  A.ID < 40000000
  AND --
			 B.cutno = 0--
         
  -------------------------------------
  -- Fill above pipe zone, pipe zone backfill, asphalt saw cutting
  ----------
  -- trench base width
  -- Excavation volume
  -- outside diameter
  ----------
  -- 
  UPDATE COSTEST_PIPEDETAILS
  SET    --pipe zone depth  = (A.OutsideDiameter + @PipeZoneDepthAdditionalInches)/12
         --Pipe volume      = (POWER(A.OutsideDiameter,2) * @InchesPerFoot  (PI/4.0))/POWER(@InchesPerYard,3.0)
         --Pipe zone volume = A.TrenchBaseWidth * PipeZoneDepth/@CubicFeetPerCubicYard - ((POWER(A.OutsideDiameter,2) * @InchesPerFoot  (PI/4.0))/POWER(@InchesPerYard,3.0))
         --Above zone volume= A.ExcavationVolume - 
         --                   (
         --                     ((POWER(A.OutsideDiameter,2) * @InchesPerFoot  (PI/4.0))/POWER(@InchesPerYard,3.0))
         --                     +
         --                     (A.TrenchBaseWidth * PipeZoneDepth/@CubicFeetPerCubicYard - ((POWER(A.OutsideDiameter,2) * @InchesPerFoot  (PI/4.0))/POWER(@InchesPerYard,3.0)))
         --                     +
         --                     ACBaseVolume (UNDEFINED)
         --                     
         --                   )
         FillAbovePipeZone = (
                               A.ExcavationVolume - 
                               /*(
                                 ((POWER(A.OutsideDiameter,2.0) * @InchesPerFoot * (PI()/4.0))/POWER(@InchesPerYard,3.0))
                                 --+
                                 --(A.TrenchBaseWidth * ((A.OutsideDiameter + @PipeZoneDepthAdditionalInches)/@InchesPerFoot)/@CubicFeetPerCubicYard - ((POWER(A.OutsideDiameter,2.0) * @InchesPerFoot * (PI()/4.0))/POWER(@InchesPerYard,3.0)))
                                 +
                                   ((A.TrenchBaseWidth + C.ExcessAsphaltWidth)*C.AsphaltBaseCourseDepth/@CubicFeetPerCubicYard)
                               )*/
                               A.TrenchBaseWidth*((C.AsphaltBaseCourseDepth+A.OutsideDiameter+@PipeZoneDepthAdditionalInches)/@InchesPerFoot)/@CubicFeetPerCubicYard
                             )*A.[length]*C.FillAbovePipeZoneCost,
         PipeZoneBackfill  = (
                               A.TrenchBaseWidth * ((A.OutsideDiameter + @PipeZoneDepthAdditionalInches)/@InchesPerFoot)/@CubicFeetPerCubicYard - ((POWER(A.OutsideDiameter,2.0) * @InchesPerFoot * (PI()/4.0))/POWER(@InchesPerYard,3.0))
                             ) * A.[length] * C.PipeZoneBackfillCost
  FROM   COSTEST_PIPEDETAILS AS A
         CROSS JOIN 
         dbo.Constants AS C
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- AsphaltSawCutting
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    SawcuttingAC = C.SawcutPavementLength*C.SawcutPavementUnitCost*A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants AS C
               
  -------------------------------------
  -- Trench Excavation
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    --TrenchExcavationUnitCost = COSTEST_Interpolate_ExcavationDepthCost((uDepth+dDepth)/2.0)
         --Spoils Volume = ExcavationVolume *1.2
         --#TruckHaulSpoilsUnitCost = 4.72
         TrenchExcavation =  GIS.COSTEST_Interpolate_ExcavationDepthCost((B.uDepth+B.dDepth)/2.0) * A.ExcavationVolume * C.ExcavationVolumeFactor * A.[length],
         TruckHaul = (A.ExcavationVolume * C.ExcavationVolumeFactor)*C.TruckHaulSpoilsUnitCost* A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
         CROSS JOIN
         dbo.Constants AS C
        
 -------------------------------------
  -- Shoring
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    --
         TrenchShoring = ((B.uDepth + B.dDepth)/2.0) * C.ShoringSquareFeetPerFoot * C.ShoringCostPerSquareFoot * A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
         CROSS JOIN
         dbo.Constants AS C
  WHERE  (B.uDepth + B.dDepth)/2.0 > @MinShoringDepth --18.0
  AND --
			 B.cutno = 0--
  
  -------------------------------------
  -- Pipe Material
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    --
         PipeMaterial = GIS.COSTEST_Find_DepthDifficultyFactor((B.uDepth + B.dDepth)/2.0, A.diamWidth, A.height)
                        *GIS.COSTEST_Interpolate_PipeCost(A.DiamWidth, A.height)
                        *A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
  
  
  -------------------------------------
  -- Manhole
  ----------
  -- 
  ----------
  UPDATE A
  SET    --
         A.Manhole = B.Manhole --GIS.[COSTEST_Find_ManholeBaseCost](A.diamWidth, B.uDepth, B.dDepth)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         COSTEST_PIPEDETAILS AS B
         ON  A.Compkey = B.Compkey
             AND
             B.cutno = 1
             AND
             A.cutno = 0
  
  /*           
  -------------------------------------
  -- Construction Duration
  ----------
  -- Pipe Duration
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration =  A.ExcavationVolume * A.[Length]/@PipeMainlineBuildRate,
         OpenCutBuildDuration =  A.ExcavationVolume * A.[Length]/@PipeMainlineBuildRate
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
         
  -------------------------------------
  -- Construction Duration
  ----------
  -- Manhole Duration
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration = ISNULL(ConstructionDuration,0) +  ((B.uDepth + B.dDepth)/2.0)/ @ManholeBuildRate ,
         OpenCutBuildDuration = ISNULL(OpenCutBuildDuration,0) + A.ExcavationVolume * A.[Length]/@PipeMainlineBuildRate
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
  
  -------------------------------------
  -- Construction Duration
  ----------
  -- Utility Crossing Duration
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration = ISNULL(ConstructionDuration, 0) + @UtilityCrossingRate * (ISNULL(xWtr, 0) + ISNULL(xGas, 0) + ISNULL(xFiber, 0) + ISNULL(xSewer, 0)),
         OpenCutBuildDuration = ISNULL(OpenCutBuildDuration,0) + @UtilityCrossingRate * (ISNULL(xWtr, 0) + ISNULL(xGas, 0) + ISNULL(xFiber, 0) + ISNULL(xSewer, 0))
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
  
  -------------------------------------
  -- Construction Duration
  ----------
  -- Pavement Repair Duration
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration = CEILING(ISNULL(ConstructionDuration, 0) + A.[length] / @PavementRepairRate ),
         OpenCutBuildDuration = CEILING(ISNULL(OpenCutBuildDuration,0) + A.[length] / @PavementRepairRate )
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
  
  -------------------------------------
  -- Construction Duration
  ----------
  -- Trenchless Method (slow)
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration =  CEILING(A.[length]/@SlowBoreRate),
         OpenCutBuildDuration =  CEILING(A.[length]/@SlowBoreRate)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
             AND
             A.diamWidth >30
             AND
             (
               (B.uDepth + B.dDepth)/2.0 > 25
               OR
               B.xBldg > 0
               OR
               B.xLRT > 0
               OR
               B.xRail > 0
               OR
               B.countxFrwy > 0
             )
  
  -------------------------------------
  -- Construction Duration
  ----------
  -- Trenchless Method (fast)
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ConstructionDuration = CEILING(A.[length]/@FastBoreRate),
         OpenCutBuildDuration = CEILING(A.[length]/@FastBoreRate)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP_WHOLE AS B
         ON  A.Compkey = B.Compkey
             AND
             A.ID < 40000000
             AND
             A.diamWidth <=30
             AND
             (
               (B.uDepth + B.dDepth)/2.0 > 25
               OR
               B.xBldg > 0
               OR
               B.xLRT > 0
               OR
               B.xRail > 0
               OR
               B.countxFrwy > 0
             )
  */
  
  UPDATE COSTEST_PIPEDETAILS
  SET    nonMobilizationConstructionDuration = ISNULL(B.BaseOpenCutRepairTime, (ISNULL(B.[boreJackPitExcavation],0)+ ISNULL([baseBoreJackRepairTime],0))) + B.ManholeReplacement
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         COSTEST_ConstructionDurations AS B
         ON  A.ID = B.ID
             AND
             A.ID < 40000000
  
  UPDATE COSTEST_PIPEDETAILS
  SET    mobilizationConstructionDuration = B.trafficControl + B.mainlineBypass
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         COSTEST_ConstructionDurations AS B
         ON  A.ID = B.ID
             AND
             A.ID < 40000000
  
  
  
  
  
  -------------------------------------
  -- Bypass Pumping
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    BypassPumping = GIS.COSTEST_Find_BypassPumpingUnitRate(B.xPipSlope, A.[length], A.diamWidth) * (nonMobilizationConstructionDuration + mobilizationConstructionDuration)/@WorkingHoursPerDay
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
  
  UPDATE REHAB.dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalMobilizationRate = ISNULL(GIS.COSTEST_Find_BypassPumpingUnitRate(B.xPipSlope, B.[length], B.diamWidth),0) 
  FROM   REHAB.dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
                        
  -------------------------------------
  -- Traffic Control
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    TrafficControl = GIS.COSTEST_Find_TrafficControlUnitRateWhole(B.uxClx, B.pStrtTyp) * (nonMobilizationConstructionDuration + mobilizationConstructionDuration)/@WorkingHoursPerDay
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
  
  UPDATE REHAB.dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0) + ISNULL(GIS.COSTEST_Find_TrafficControlUnitRateWhole(B.uxClx, B.pStrtTyp),0) 
  FROM   REHAB.dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
			 AND --
			 B.cutno = 0--
                    
  -------------------------------------
  -- Boring Jacking
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    BoringJacking = @BoringJackingCost * (@ENR) * EXP(0.0119 * A.diamWidth) * A.[length]
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
             AND
             (
               (B.uDepth + B.dDepth)/2.0 > 25.0
               OR
               --countxFrwy > 0
               B.xFrwy > 0
               OR
               B.xBldg > 0
               OR
               B.xLRT > 0
               OR
               B.xRail > 0
             )
			 AND --
			 B.cutno = 0--
  -------------------------------------
  -- Difficult Area
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    DifficultArea = POWER(@DifficultAreaFactor, 
                                  (
                                    CASE WHEN ISNULL(B.HardArea, 0) > 0 THEN 1 ELSE 0 END + 
                                    CASE WHEN ISNULL(pRail, 0) > 0 THEN 1 ELSE 0 END + 
                                    CASE WHEN ISNULL(pLRT,0) > 0 THEN 1 ELSE 0 END+
                                    CASE WHEN ABS(ISNULL(B.gSlope, 0)) >= 0.1 AND (pStrt = 0 OR pStrt IS NULL) THEN 1 ELSE 0 END
                                  )
                              )
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         --dbo.COSTEST_PIPEXP_WHOLE AS B
         dbo.COSTEST_PIPEXP AS B
         ON  A.Compkey = B.hansen_compkey
             AND
             A.ID < 40000000
             /*AND
             (
               B.HardArea > 0
               OR
               pRail > 0
               OR
               pLRT > 0
             )*/
			 AND --
			 B.cutno = 0--
  
  -------------------------------------
  -- Laterals
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    Lateral = SumLateral
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         (
           SELECT  COMPKEY, SUM(Lateral) AS SumLateral
           FROM    COSTEST_PIPEDETAILS
           WHERE   ID >= 40000000
           GROUP BY COMPKEY
         ) AS B
         ON  A.COMPKEY = B.COMPKEY
  WHERE  ID < 40000000
  
  -------------------------------------
  -- Direct Construction Costs
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    DirectConstructionCost = (ISNULL(DifficultArea, 1) * (@ENR))
                                  *
                                  (
                                    ISNULL(TrafficControl, 0)
                                    + ISNULL(BypassPumping, 0)
                                    + ISNULL(TrenchShoring, 0)
                                    + ISNULL(TrenchExcavation, 0)
                                    + ISNULL(TruckHaul, 0)
                                    + ISNULL(PipeMaterial, 0)
                                    + ISNULL(Manhole, 0)
                                    + ISNULL(FillAbovePipeZone, 0)
                                    + ISNULL(PipeZoneBackfill, 0)
                                    + ISNULL(SawcuttingAC, 0)
                                    + ISNULL(AsphaltRemoval, 0)
                                    + ISNULL(AsphaltTrenchPatch, 0)
                                    + ISNULL(AsphaltBaseCourse, 0)
                                    + ISNULL(ParallelWaterRelocation, 0)
                                    + ISNULL(CrossingRelocation, 0)
                                    + ISNULL(HazardousMaterials, 0)
                                    + ISNULL(EnvironmentalMitigation, 0)
                                    --+ ISNULL(Lateral, 0)
                                  )
  WHERE   ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  (ISNULL(DifficultArea, 1) * (@ENR))
                                  *
                                  (
                                    + ISNULL(TrenchShoring, 0)
                                    + ISNULL(TrenchExcavation, 0)
                                    + ISNULL(TruckHaul, 0)
                                    + ISNULL(PipeMaterial, 0)
                                    + ISNULL(Manhole, 0)
                                    + ISNULL(FillAbovePipeZone, 0)
                                    + ISNULL(PipeZoneBackfill, 0)
                                    + ISNULL(SawcuttingAC, 0)
                                    + ISNULL(AsphaltRemoval, 0)
                                    + ISNULL(AsphaltTrenchPatch, 0)
                                    + ISNULL(AsphaltBaseCourse, 0)
                                    + ISNULL(ParallelWaterRelocation, 0)
                                    + ISNULL(CrossingRelocation, 0)
                                    + ISNULL(HazardousMaterials, 0)
                                    + ISNULL(EnvironmentalMitigation, 0)
                                  ),
         CapitalMobilizationRate = (ISNULL(DifficultArea, 1) * (@ENR))* ISNULL(CapitalMobilizationRate,0)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Dig'                           
  -------------------------------------
  -- Standard Pipe Factors
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    StandardPipeFactorCost = DirectConstructionCost * (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor )
  WHERE  ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Dig'
  -------------------------------------
  -- Contingency Cost
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    ContingencyCost = StandardPipeFactorCost * (1.0 + @ContingencyFactor)
  WHERE  ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* (1.0 + @ContingencyFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* (1.0 + @ContingencyFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Dig'
  
  -------------------------------------
  -- Capital Cost
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    CapitalCost = ContingencyCost * ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor)
  WHERE  ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Dig'
  -------------------------------------
  -- LinerTrafficControl (+Manhole)
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerTrafficControl = (@daysForWholePipeLinerConstruction /*+ ((B.uDepth + B.dDepth)/2.0)/ @ManholeBuildRate*/) * GIS.COSTEST_Find_TrafficControlUnitRate(B.uxClx, B.pStrtTyp)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP AS B
         ON  A.ID = B.ID
  WHERE  A.ID < 40000000
     
  -------------------------------------
  -- LinerBypassPumping (+Manhole)
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerBypassPumping = (@daysForWholePipeLinerConstruction /*+ ((B.uDepth + B.dDepth)/2.0)/ @ManholeBuildRate*/) * GIS.COSTEST_Find_BypassPumpingUnitRate(B.xPipSlope, A.[length], A.diamWidth)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP AS B
         ON  A.ID = B.ID
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- LinerBuildDuration (+Manhole)
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    SpotLineBuildDuration =(@daysForWholePipeLinerConstruction /*+ ((B.uDepth + B.dDepth)/2.0)/ @ManholeBuildRate*/)
  FROM   COSTEST_PIPEDETAILS AS A
         INNER JOIN
         dbo.COSTEST_PIPEXP AS B
         ON  A.ID = B.ID
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- LinerLaterals
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerLaterals = Lateral
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
   
  -------------------------------------
  -- LinerPipeMaterial
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerPipeMaterial = [GIS].[COSTEST_Find_LinerCost](diamWidth) *[length]
                             --1.1406 * POWER(diamWidth, 1.4882) *[length]
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- LinerTVCleaning
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerTVCleaning = [GIS].[COSTEST_Find_LinerTVCleaningCost](diamWidth) * [length]
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- LinerManhole
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerManhole = Manhole
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  -------------------------------------
  -- Liner Direct Construction Costs
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerDirectConstructionCost = (ISNULL(DifficultArea, 1) * (@ENR))
                                  *
                                  (
                                    ISNULL(LinerTrafficControl, 0)
                                    + ISNULL(LinerBypassPumping, 0)
                                    + ISNULL(LinerPipeMaterial, 0)
                                    --+ ISNULL(LinerManhole, 0)
                                    + ISNULL(LinerTVCleaning, 0)
                                    --+ ISNULL(LinerLaterals, 0)
                                  )
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  (ISNULL(DifficultArea, 1) * (@ENR))
                                  *
                                  (
                                    ISNULL(LinerPipeMaterial, 0)
                                    --+ ISNULL(LinerManhole, 0)
                                    + ISNULL(LinerTVCleaning, 0)
                                  ),
         CapitalMobilizationRate = (ISNULL(DifficultArea, 1) * (@ENR))* ISNULL(CapitalMobilizationRate,0)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Line' 
                                  
  -------------------------------------
  -- Standard Pipe Factors
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerStandardPipeFactorCost = LinerDirectConstructionCost * (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor)
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* (1.0 + @GeneralConditionsFactor + @WasteAllowanceFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Line'
  -------------------------------------
  -- Contingency Cost
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerContingencyCost = LinerStandardPipeFactorCost * (1.0 + @ContingencyFactor)
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* (1.0 + @ContingencyFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* (1.0 + @ContingencyFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Line'
  
  -------------------------------------
  -- Capital Cost
  ----------
  -- 
  ----------
  UPDATE COSTEST_PIPEDETAILS
  SET    LinerCapitalCost = LinerContingencyCost * ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor)
  FROM   COSTEST_PIPEDETAILS AS A
  WHERE  A.ID < 40000000
  
  UPDATE dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
  SET    CapitalNonMobilization =  ISNULL(CapitalNonMobilization,0)* ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor),
         CapitalMobilizationRate = ISNULL(CapitalMobilizationRate,0)* ( 1.0 + @ConstructionManagementInspectionTestingFactor + @DesignFactor + @PublicInvolvementInstrumentationAndControlsEasementEnvironmentalFactor + @StartupCloseoutFactor)
  FROM   dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes
         INNER JOIN
         COSTEST_PIPEDETAILS   
         ON  dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID = COSTEST_PIPEDETAILS.ID
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.ID < 40000000   
             AND
             dbo.COSTEST_CapitalCostsMobilizationRatesAndTimes.[Type] = 'Line'
             
  EXEC  __USP_REHAB_XX_LineShim
  
END


GO

