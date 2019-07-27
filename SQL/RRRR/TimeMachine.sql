USE [REHAB]
GO
Drop Table #Temp
TRUNCATE TABLE [dbo].[RRRR_nBCR_Data]
TRUNCATE TABLE [dbo].[RRRR_REHAB_Branches]

Declare @After_Action_Inspection_Date DateTime
Declare @Before_Action_Inspection_Date DateTime

Select *

Into #Temp
From [dbo].[RRRR_Inspection_Dates]


-- LOOP through inspection dates
WHILE EXISTS(SELECT * FROM #Temp)
Begin
    Select Top 1 @After_Action_Inspection_Date = INSPDATE From #Temp
    PRINT CAST(@After_Action_Inspection_Date AS nvarchar(30))
		
    SELECT @Before_Action_Inspection_Date = DATEADD(DD, -1, @After_Action_Inspection_Date)
    PRINT CAST(@Before_Action_Inspection_Date AS nvarchar(30))	

	    -- Run Stored procedure using @After_Inspection_Date
    EXECUTE [dbo].[___USP_REHAB_0FULLPROCEDURE_0_4R] 
    @After_Action_Inspection_Date 

	    -- Append output to output table
    INSERT INTO [dbo].[RRRR_nBCR_Data]
           ([ID]
           ,[XBJECTID]
           ,[GLOBALID]
           ,[compkey]
           ,[usnode]
           ,[dsnode]
           ,[UNITTYPE]
           ,[length]
           ,[diamWidth]
           ,[height]
           ,[pipeShape]
           ,[material]
           ,[newMaterial]
           ,[instdate]
           ,[hservstat]
           ,[cutno]
           ,[fm]
           ,[to_]
           ,[segmentLength]
           ,[grade_h5]
           ,[segmentCount]
           ,[failNear]
           ,[failPrev]
           ,[failTot]
           ,[failPct]
           ,[defPts]
           ,[defLin]
           ,[defTot]
           ,[FailureYear]
           ,[StdDev]
           ,[cof]
           ,[inspDate]
           ,[inspCurrent]
           ,[ownership]
           ,[SpotsToRepairBeforeLining]
           ,[lateralCount]
           ,[lateralCost]
           ,[CostToSpotOnly]
           ,[CostToWholePipeOnly]
           ,[CostToLineOnly]
           ,[spotRepairCount]
           ,[manholeCost]
           ,[ASMFailureAction]
           ,[ASMRecommendedAction]
           ,[ASMRecommendednBCR]
           ,[SpotCapitalCost]
           ,[WholePipeCapitalCost]
           ,[LinerCapitalCost]
           ,[SpotCapitalRate]
           ,[WholePipeCapitalRate]
           ,[LinerCapitalRate]
           ,[SpotBaseTime]
           ,[WholePipeBaseTime]
           ,[LinerBaseTime]
           ,[SpotMobilizationTime]
           ,[WholePipeMobilizationTime]
           ,[LinerMobilizationTime]
           ,[SpotnBCR]
           ,[LinernBCR]
           ,[WholenBCR]
           ,[BPW]
           ,[APWSpot]
           ,[APWLiner]
           ,[APWWhole]
           ,[problems]
           ,[MaxSegmentCOFwithoutReplacement]
           ,[prejudiceSpot]
           ,[prejudiceLine]
           ,[prejudiceDig]
           ,[apparentnBCR]
		   ,[Action_Date])
     SELECT
           [ID]
           ,[XBJECTID]
           ,[GLOBALID]
           ,[compkey]
           ,[usnode]
           ,[dsnode]
           ,[UNITTYPE]
           ,[length]
           ,[diamWidth]
           ,[height]
           ,[pipeShape]
           ,[material]
           ,[newMaterial]
           ,[instdate]
           ,[hservstat]
           ,[cutno]
           ,[fm]
           ,[to_]
           ,[segmentLength]
           ,[grade_h5]
           ,[segmentCount]
           ,[failNear]
           ,[failPrev]
           ,[failTot]
           ,[failPct]
           ,[defPts]
           ,[defLin]
           ,[defTot]
           ,[FailureYear]
           ,[StdDev]
           ,[cof]
           ,R.[inspDate]
           ,[inspCurrent]
           ,[ownership]
           ,[SpotsToRepairBeforeLining]
           ,[lateralCount]
           ,[lateralCost]
           ,[CostToSpotOnly]
           ,[CostToWholePipeOnly]
           ,[CostToLineOnly]
           ,[spotRepairCount]
           ,[manholeCost]
           ,[ASMFailureAction]
           ,[ASMRecommendedAction]
           ,[ASMRecommendednBCR]
           ,[SpotCapitalCost]
           ,[WholePipeCapitalCost]
           ,[LinerCapitalCost]
           ,[SpotCapitalRate]
           ,[WholePipeCapitalRate]
           ,[LinerCapitalRate]
           ,[SpotBaseTime]
           ,[WholePipeBaseTime]
           ,[LinerBaseTime]
           ,[SpotMobilizationTime]
           ,[WholePipeMobilizationTime]
           ,[LinerMobilizationTime]
           ,[SpotnBCR]
           ,[LinernBCR]
           ,[WholenBCR]
           ,[BPW]
           ,[APWSpot]
           ,[APWLiner]
           ,[APWWhole]
           ,[problems]
           ,[MaxSegmentCOFwithoutReplacement]
           ,[prejudiceSpot]
           ,[prejudiceLine]
           ,[prejudiceDig]
           ,[apparentnBCR]
		   ,@After_Action_Inspection_Date
    FROM [GIS].[NBCR_Data] As R
	INNER JOIN [dbo].[RRRR_COMPKEYS] ON R.COMPKEY = [dbo].[RRRR_COMPKEYS].RRRR_COMPKEY

INSERT INTO [dbo].[RRRR_REHAB_Branches]
           ([COMPKEY]
           ,[ASM_Gen3Solution]
           ,[ASM_Gen3SolutionnBCR]
           ,[nBCR_OC]
           ,[nBCR_CIPP]
           ,[nBCR_SP]
           ,[InitialFailYear]
           ,[LineAtYear]
           ,[LineAtYearAPW]
           ,[std_dev]
           ,[ReplaceCost]
           ,[SpotCost]
           ,[MaxSegmentCOFwithoutReplacement]
           ,[LineCostNoSpots]
           ,[SpotCost01]
           ,[SpotCost02]
           ,[SpotCostFail01]
           ,[SpotCostFail02]
           ,[BPWOCfail01]
           ,[BPWOCfail02]
           ,[BPWCIPPfail01]
           ,[BPWCIPPfail02]
           ,[BPWCIPPfail03]
           ,[BPWSPfail01]
           ,[BPWSPfail02]
           ,[BPWSPfail03]
           ,[BPWSPfail04]
           ,[APWOC01]
           ,[APWOC02]
           ,[APWCIPP01]
           ,[APWCIPP02]
           ,[APWCIPP03]
           ,[APWSP01]
           ,[APWSP02]
           ,[APWSP03]
           ,[APWSP04]
           ,[BPW]
           ,[BPWOC]
           ,[APWOC]
           ,[BPWSP]
           ,[APWSP]
           ,[BPWCIPP]
           ,[APWCIPP]
           ,[Problems]
           ,[ASMFailureAction]
           ,[PVLostWhole]
           ,[PVLostLiner]
           ,[PVLostSpot]
           ,[grade_h5]
           ,[prejudiceSpot]
           ,[prejudiceLine]
           ,[prejudiceDig]
           ,[apparentnBCR]
           ,[GLOBALID]
           ,[ACTION_DATE])
     SELECT
           [COMPKEY]
           ,[ASM_Gen3Solution]
           ,[ASM_Gen3SolutionnBCR]
           ,[nBCR_OC]
           ,[nBCR_CIPP]
           ,[nBCR_SP]
           ,[InitialFailYear]
           ,[LineAtYear]
           ,[LineAtYearAPW]
           ,[std_dev]
           ,[ReplaceCost]
           ,[SpotCost]
           ,[MaxSegmentCOFwithoutReplacement]
           ,[LineCostNoSpots]
           ,[SpotCost01]
           ,[SpotCost02]
           ,[SpotCostFail01]
           ,[SpotCostFail02]
           ,[BPWOCfail01]
           ,[BPWOCfail02]
           ,[BPWCIPPfail01]
           ,[BPWCIPPfail02]
           ,[BPWCIPPfail03]
           ,[BPWSPfail01]
           ,[BPWSPfail02]
           ,[BPWSPfail03]
           ,[BPWSPfail04]
           ,[APWOC01]
           ,[APWOC02]
           ,[APWCIPP01]
           ,[APWCIPP02]
           ,[APWCIPP03]
           ,[APWSP01]
           ,[APWSP02]
           ,[APWSP03]
           ,[APWSP04]
           ,[BPW]
           ,[BPWOC]
           ,[APWOC]
           ,[BPWSP]
           ,[APWSP]
           ,[BPWCIPP]
           ,[APWCIPP]
           ,[Problems]
           ,[ASMFailureAction]
           ,[PVLostWhole]
           ,[PVLostLiner]
           ,[PVLostSpot]
           ,[grade_h5]
           ,[prejudiceSpot]
           ,[prejudiceLine]
           ,[prejudiceDig]
           ,[apparentnBCR]
           ,[GLOBALID]
           ,@After_Action_Inspection_Date
    FROM [GIS].[REHAB_Branches] As R	
	INNER JOIN [dbo].[RRRR_COMPKEYS] ON R.COMPKEY = [dbo].[RRRR_COMPKEYS].RRRR_COMPKEY

    Delete #Temp Where INSPDATE = @After_Action_Inspection_Date
End