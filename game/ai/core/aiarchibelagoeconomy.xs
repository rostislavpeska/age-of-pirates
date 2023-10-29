//==============================================================================
/* aiAssertiveWall.xs

   This file contains additional functions written by Assertive Wall

*/
//==============================================================================

//==============================================================================
// Custom Array functions.
// All from Better AI
//==============================================================================

// Integer User Variables
int arrayCreateInt(int numElements = 1, string description = "default")
{
	gArrayPlanIDs++;
	aiPlanAddUserVariableInt(gArrayPlan, gArrayPlanIDs, description, numElements);

	// 1 value (index 0) to represent the size (the defined elements) of the array at index gArrayPlanIDs.
	aiPlanAddUserVariableInt(gArrayPlanSizes, gArrayPlanIDs, "Size of Array " + description, 1);
	// Default is size 0, being that when the User Var is created, the default value is -1, or undefined.
	aiPlanSetUserVariableInt(gArrayPlanSizes, gArrayPlanIDs, 0, 0);

	// 1 value (index 0) to represent the number of (all, even undefined) elements of the array at index gArrayPlanIDs.
	aiPlanAddUserVariableInt(gArrayPlanNumElements, gArrayPlanIDs, "Num Elements of Array " + description, 1);
	aiPlanSetUserVariableInt(gArrayPlanNumElements, gArrayPlanIDs, 0, numElements);

	return(gArrayPlanIDs);
}

int arrayGetNumElements(int arrayID = -1)
{
	if (arrayID <= -1)
		return(1);
	if (arrayID > gArrayPlanIDs)
		return(1);

	return(aiPlanGetUserVariableInt(gArrayPlanNumElements, arrayID, 0));
}

void arraySetSize(int arrayID = -1, int size = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;
	if (size < 0)
		return;
	if (size > arrayGetNumElements(arrayID))
		return;

	aiPlanSetUserVariableInt(gArrayPlanSizes, arrayID, 0, size);
}

void arraySetNumElements(int arrayID = -1, int numElements = -1, bool clearValues = false)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;
	// Num elements needs to be >= 1 even if it stores nothing.
	if (numElements < 1)
		return;

	aiPlanSetNumberUserVariableValues(gArrayPlan, arrayID, numElements, clearValues);
	aiPlanSetUserVariableInt(gArrayPlanNumElements, arrayID, 0, numElements);
}

void arrayResetSelf(int arrayID = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;

	arraySetNumElements(arrayID, 1, true);
	arraySetSize(arrayID, 0);
}

int arrayGetSize(int arrayID = -1)
{
	if (arrayID <= -1)
		return(0);
	if (arrayID > gArrayPlanIDs)
		return(0);

	return(aiPlanGetUserVariableInt(gArrayPlanSizes, arrayID, 0));
}

vector arrayGetVector(int arrayID = -1, int arrayIndex = -1)
{
	if (arrayID <= -1)
		return(cInvalidVector);
	if (arrayID > gArrayPlanIDs)
		return(cInvalidVector);
	if (arrayIndex <= -1)
		return(cInvalidVector);
	if (arrayIndex >= aiPlanGetNumberUserVariableValues(gArrayPlan, arrayID))
		return(cInvalidVector);

	return(aiPlanGetUserVariableVector(gArrayPlan, arrayID, arrayIndex));
}

void arraySetInt(int arrayID = -1, int arrayIndex = -1, int value = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;
	if (arrayIndex <= -1)
		return;
	if (arrayIndex >= aiPlanGetNumberUserVariableValues(gArrayPlan, arrayID))
		return;

	aiPlanSetUserVariableInt(gArrayPlan, arrayID, arrayIndex, value);
}

int arrayGetInt(int arrayID = -1, int arrayIndex = -1)
{
	if (arrayID <= -1)
		return(-1);
	if (arrayID > gArrayPlanIDs)
		return(-1);
	if (arrayIndex <= -1)
		return(-1);
	if (arrayIndex >= aiPlanGetNumberUserVariableValues(gArrayPlan, arrayID))
		return(-1);

	return(aiPlanGetUserVariableInt(gArrayPlan, arrayID, arrayIndex));
}

void arrayDeleteInt(int arrayID = -1, int arrayIndex = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;
	if (arrayIndex <= -1)
		return;
	if (arrayIndex >= aiPlanGetNumberUserVariableValues(gArrayPlan, arrayID))
		return;

	int size = arrayGetSize(arrayID);
	int numElements = arrayGetNumElements(arrayID);
	size--;
	if (numElements > 1) // Do not set the number elements to zero, or the array malfunctions.
	{
		numElements--;
		// Length of arrayID is adjusted via this function. We should NOT use
		// the custom function arraySetNumElements, as that adjusts the size
		// by getting rid of the last element (untested), not necessarily the one
		// that we want to remove.
		aiPlanRemoveUserVariableValue(gArrayPlan, arrayID, arrayIndex);
		// Thus, we should adjust the numElements manually.
		aiPlanSetUserVariableInt(gArrayPlanNumElements, arrayID, 0, numElements);
	}
	// Probably already -1, but let's make sure, so that it won't be considered.
	else
	{
		arraySetInt(arrayID, arrayIndex, -1);
	}

	// Using the function we defined for size is fine, though.
	arraySetSize(arrayID, size);
}

void arrayRemoveDonePlans(int arrayID = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;

	for (planIndex = 0; < arrayGetSize(arrayID))
	{	// If we delete values while inside the loop, the size of the array shrinks
		// and we may face errors.
		if (aiPlanGetState(arrayGetInt(arrayID, planIndex)) < 0)
			arraySetInt(arrayID, planIndex, -1);
	}
	for (planIndex = 0; < arrayGetSize(arrayID))
	{
		if (arrayGetInt(arrayID, planIndex) < 0)
			arrayDeleteInt(arrayID, planIndex);
	}
}

void arrayPushInt(int arrayID = -1, int value = -1)
{
	if (arrayID <= -1)
		return;
	if (arrayID > gArrayPlanIDs)
		return;

	int size = arrayGetSize(arrayID);
	int numElements = arrayGetNumElements(arrayID);

	if (size >= numElements)
		arraySetNumElements(arrayID, numElements * 2);

	arraySetInt(arrayID, size, value);
	size++;
	arraySetSize(arrayID, size);
}

float getDistance(vector v1 = cInvalidVector, vector v2 = cInvalidVector)
{
	vector delta = v1 - v2;
	return (xsVectorLength(delta));
}

bool resourceCloserToAlly(int resourceID = -1)
{
	// After 25 minutes consider all resources fair game.
	static int time = 1500000;
	static bool timeCheck = false;
	if (xsGetTime() >= time)
		timeCheck = true;
	if (timeCheck == true)
		return(false);

	// If we have no allies, check no further.
	int size = arrayGetSize(gAllyBaseArray);
	if (size <= 0)
		return(false);

	float distanceToMe = getDistance(kbUnitGetPosition(resourceID), gHomeBase);
	if (distanceToMe <= 60.0) // Always consider gathering if it is this close to our base.
		return(false);
	float distanceToAlly = -1;

	int index = 0;
	for (player = 1; < cNumberPlayers)
	{
		if (kbIsPlayerAlly(player))
		{
			if (player == cMyID)
				continue;
			// If the player has lost, the resources might as well be ours.
			if (kbHasPlayerLost(player) == false)
			{
				distanceToAlly = getDistance(kbUnitGetPosition(resourceID), arrayGetVector(gAllyBaseArray, index));
				if ((distanceToAlly * 1.2) < distanceToMe) // So we have a little wiggle room, multiply by 1.2.
					return(true);
			}
			index++;
		}
	}

	return(false);
}


// ================================================================================
//	getClosestUnit
//
//	Will return a random unit matching the parameters
// ================================================================================
int getClosestUnit(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive, vector location = cInvalidVector, float radius = 20.0)
{
	static int unitQueryID = -1;

	//If we don't have the query yet, create one.
	if (unitQueryID < 0)
	{
		unitQueryID = kbUnitQueryCreate("miscGetUnitLocationQuery");
	}

	//Define a query to get all matching units
	if (unitQueryID != -1)
	{
		if (playerRelationOrID > 1000)      // Too big for player ID number
		{
			kbUnitQuerySetPlayerID(unitQueryID, -1);
			kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
		}
		else
		{
			kbUnitQuerySetPlayerRelation(unitQueryID, -1);
			kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
		}
		kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
		kbUnitQuerySetState(unitQueryID, state);
		kbUnitQuerySetPosition(unitQueryID, location);
		kbUnitQuerySetMaximumDistance(unitQueryID, radius);
		kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
		kbUnitQuerySetAscendingSort(unitQueryID, true);
	}
	else
		return(-1);

	kbUnitQueryResetResults(unitQueryID);
	int numberFound = kbUnitQueryExecute(unitQueryID);
	if (numberFound > 0)
		return(kbUnitQueryGetResult(unitQueryID, 0));   // Return the first unit
	return(-1);
}

//==============================================================================
// getDedicatedGatherers
//
// For a specific resource, fetch the number of dedicated gatherers (i.e. static
// income from factories/banks/etc.), so that we will be able to account for
// this income in our villager rule.
//==============================================================================
int getDedicatedGatherers(int resourceType = -1)
{
	float temp = 0.0;
	int dedicatedVillagerValue = 0;
	int numBuildings = 0;
	float villagerGatherRate = 0.5;
	float dedicatedGatherRate = 0.0;
	float totalGatherRate = 0.0;
	float handicap = kbGetPlayerHandicap(cMyID);

	// TODO (James): Account for torps? Will likely disregard these and let the algorithm handle deficits.
	switch (resourceType)
	{
		case cResourceFood:
		{
			if (cMyCiv == cCivJapanese)
				villagerGatherRate = kbProtoUnitGetGatherRate(gEconUnit, cUnitTypeypBerryBuilding) * handicap;
			else
				villagerGatherRate = kbProtoUnitGetGatherRate(gEconUnit, cUnitTypeHuntable) * handicap;

			// Kancha Houses.
			if (cMyCiv == cCivDEInca)
			{
				numBuildings = kbUnitCount(cMyID, cUnitTypedeHouseInca, cUnitStateAlive);
				dedicatedGatherRate = 0.6 * numBuildings * handicap;
				if (kbTechGetStatus(cTechDEHCChichaBrewing) == cTechStatusActive)
					dedicatedGatherRate = dedicatedGatherRate * 1.5;
				totalGatherRate = totalGatherRate + dedicatedGatherRate;
			}

			break;
		}
		case cResourceWood:
		{
			villagerGatherRate = kbProtoUnitGetGatherRate(gEconUnit, cUnitTypeTree) * handicap;

			// Factories (should be on wood).
			numBuildings = kbUnitCount(cMyID, cUnitTypeFactory, cUnitStateAlive);
			dedicatedGatherRate = 5.5 * numBuildings * handicap;
			if (kbTechGetStatus(cTechFactoryWaterPower) == cTechStatusActive)
				dedicatedGatherRate = dedicatedGatherRate * 1.3;
			totalGatherRate = totalGatherRate + dedicatedGatherRate;

			// TODO (James): Account for animals on the shrines.
			// Shrines (should be on wood starting in Age 2; Age 1 food is negligible).
			if (cMyCiv == cCivJapanese && kbGetAge() >= cAge2)
			{
				numBuildings = kbUnitCount(cMyID, cUnitTypeypShrineJapanese, cUnitStateAlive);
				dedicatedGatherRate = 0.1 * numBuildings * handicap;
				if (kbTechGetStatus(cTechYPHCIncreasedTribute) == cTechStatusActive)
					dedicatedGatherRate = dedicatedGatherRate * 1.5;
				if (kbTechGetStatus(cTechypShrineFortressUpgrade) == cTechStatusActive)
					dedicatedGatherRate = dedicatedGatherRate * 4.0;
				totalGatherRate = totalGatherRate + dedicatedGatherRate;
			}

			break;
		}
		case cResourceGold:
		{
			if (cMyCiv == cCivXPIroquois || cMyCiv == cCivXPSioux)
				villagerGatherRate = kbProtoUnitGetGatherRate(gEconUnit, cUnitTypedeFurTrade) * handicap;
			else
				villagerGatherRate = kbProtoUnitGetGatherRate(gEconUnit, cUnitTypeAbstractMine) * handicap;

			// Banks.
			if (cMyCiv == cCivDutch || cMyCiv == cCivDEAmericans || cMyCiv == cCivJapanese)
			{
				numBuildings = kbUnitCount(cMyID, cUnitTypeBank, cUnitStateAlive);
				dedicatedGatherRate = 2.75 * numBuildings * handicap;
				if (kbTechGetStatus(cTechHCBetterBanks) == cTechStatusActive)
					dedicatedGatherRate = dedicatedGatherRate * 1.2;
				totalGatherRate = totalGatherRate + dedicatedGatherRate;
			}

			break;
		}
	}

	temp = totalGatherRate / villagerGatherRate;
	dedicatedVillagerValue = temp;

	return(dedicatedVillagerValue);
}

//==============================================================================
// findTradingLodge
//
// Find trading lodges to work for Haudenosaunee and Lakota. If we are lacking,
// build one.
//==============================================================================
int findTradingLodge(int resourceID = -1)
{
	vector location = kbUnitGetPosition(resourceID);
	int tradingLodge = getClosestUnit(cUnitTypedeFurTrade, cMyID, cUnitStateABQ, location, 15.0);
	if (tradingLodge >= 0)
	{
		return (tradingLodge);
	}

	if (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypedeFurTrade) >= 0 ||
		((kbUnitCount(cMyID, cUnitTypedeFurTrade, cUnitStateABQ) * 10) > (gNumGoldVills + 1)))
	{
		return (-1);
	}

	// If we got here, tradingLodge < 0, so let's build one ASAP.
	int planID = aiPlanCreate("Trading Lodge Build Plan", cPlanBuild);
	aiPlanSetVariableInt(planID, cBuildPlanBuildingTypeID, 0, cUnitTypedeFurTrade);
	aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 6.0);
	aiPlanSetDesiredPriority(planID, 99);
	aiPlanSetDesiredResourcePriority(planID, 99);
	aiPlanSetEconomy(planID, true);
	aiPlanSetMilitary(planID, false);
	aiPlanSetEscrowID(planID, cRootEscrowID);
	aiPlanAddUnitType(planID, cUnitTypeLogicalTypeSettlerBuildLimit, 1, 1, 1);

	aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, location);
	aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, 30.0);
	aiPlanSetVariableVector(planID, cBuildPlanInfluencePosition, 0, location);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionDistance, 0, 100.0);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, 200.0);
	aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear);
	
	aiPlanSetVariableInt(planID, cBuildPlanInfluenceUnitTypeID, 0, cUnitTypedeFurTrade);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluenceUnitDistance, 0, 10.0);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluenceUnitValue, 0, -20.0);
	aiPlanSetVariableInt(planID, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffLinear);

	aiPlanSetActive(planID);

	return (-1); // Should be -1.
}

// AssertiveWall: Adapted from Ceylon Nomad Start. Takes an approximate pickup and dropoff, and returns the 
// closest dropoff location 
// Does not contain all the same checks as the islandMigration rule
vector getDropoffPoint(vector pickup = cInvalidVector, vector dropoff = cInvalidVector)
{
	int areaCount = 0;
	vector myLocation = pickup;
	int myAreaGroup = -1;

	int area = 0;
	int areaGroup = -1;

	areaCount = kbAreaGetNumber();
	myAreaGroup = kbAreaGroupGetIDByPosition(myLocation);

	int closestArea = -1;
	float closestAreaDistance = kbGetMapXSize();

	for (area = 0; < areaCount)
	{
		if (kbAreaGetType(area) == cAreaTypeWater)
		{
			continue;
		}

		areaGroup = kbAreaGroupGetIDByPosition(kbAreaGetCenter(area));
		if (kbAreaGroupGetNumberAreas(areaGroup) - kbAreaGroupGetNumberAreas(myAreaGroup) <= 10)
		{
			continue;
		}

		bool bordersWater = false;
		int borderAreaCount = kbAreaGetNumberBorderAreas(area);
		for (i = 0; < borderAreaCount)
		{
			if (kbAreaGetType(kbAreaGetBorderAreaID(area, i)) == cAreaTypeWater)
			{
			bordersWater = true;
			break;
			}
		}

		if (bordersWater == false)
		{
			continue;
		}

		// Check to make sure this area is connected to the dropoff
		if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(dropoff), areaGroup) == false)
		{
			continue;
		}

		float dist = xsVectorLength(kbAreaGetCenter(area) - myLocation);
		if (dist < closestAreaDistance)
		{
			closestAreaDistance = dist;
			closestArea = area;
		}
	}

   return kbAreaGetCenter(closestArea);
}

//==============================================================================
// addBetterPlantationBuildPlan
//==============================================================================
int addBetterPlantationBuildPlan(void)
{
	if (gTimeForPlantations == false)
		gTimeForPlantations = true;

	// We are already maxed out.
	if (kbUnitCount(cMyID, gPlantationUnit, cUnitStateABQ) + arrayGetSize(gPlantationTypePlans) >=
		kbGetBuildLimit(cMyID, gPlantationUnit) && kbGetBuildLimit(cMyID, gPlantationUnit) > 0)
		return(-1);

	int buildPlanID = createSimpleBuildPlan(gPlantationUnit, 1, 70, true, cEconomyEscrowID, kbBaseGetMainID(cMyID), 1);
	aiPlanSetDesiredResourcePriority(buildPlanID, 60); // above average but below villager production (indian villagers cost wood)

	return (buildPlanID);
}

//==============================================================================
// addMillBuildPlan
//==============================================================================
int addBetterMillBuildPlan(void)
{
	if (gTimeToFarm == false)
		gTimeToFarm = true;

	// We are already maxed out.
	if (kbUnitCount(cMyID, gFarmUnit, cUnitStateABQ) + arrayGetSize(gMillTypePlans) >=
		kbGetBuildLimit(cMyID, gFarmUnit) && kbGetBuildLimit(cMyID, gFarmUnit) > 0)
		return(-1);

	int buildPlanID = createSimpleBuildPlan(gFarmUnit, 1, 70, true, cEconomyEscrowID, kbBaseGetMainID(cMyID), 1);

	aiPlanSetDesiredResourcePriority(buildPlanID, 60); // above average but below villager production (indian villagers cost wood)

	return (buildPlanID);
}

//==============================================================================
// updateFoodBreakdown
//
// Populate an array with food resources that should be gathered.
//==============================================================================
void updateBetterFoodBreakdown(void)
{
	arrayResetSelf(gFoodResources);
	arrayResetSelf(gDecayingAnimals);
	arrayResetSelf(gFoodNumWorkers);
	arrayResetSelf(gDecayingNumWorkers);
	arrayResetSelf(gMaxFoodWorkers);

	int numberResults = 0;
	// Get a rough estimate on our food supply in terms of how many villagers
	// I allow to gather from the particular resource multiplied by 0.8.
	// If by the end totalResourceWorth is not enough, then we should prepare
	// to build a Mill type. Made a float for certain calculations.
	float resourceWorth = 0.0;
	float totalResourceWorth = 0.0;
	int resourceID = -1;
	int planID = -1;
	int numWorkers = -1;
	int temp = -1;

	// Search for food.
	if (gFoodQuery < 0)
	{
		gFoodQuery = kbUnitQueryCreate("Food Resources Query");
		kbUnitQuerySetIgnoreKnockedOutUnits(gFoodQuery, true);
		kbUnitQuerySetSeeableOnly(gFoodQuery, false);
		kbUnitQuerySetPosition(gFoodQuery, gHomeBase);
		//kbUnitQuerySetAreaGroupID(gFoodQuery, kbAreaGroupGetIDByPosition(gHomeBase));
	}
	kbUnitQuerySetMaximumDistance(gFoodQuery, 220.0);
	kbUnitQueryResetResults(gFoodQuery);

	// Herdables.
	if (cMyCiv != cCivJapanese && cMyCiv != cCivIndians &&
		civIsAfrican() == false && totalResourceWorth < gNumFoodVills)
	{	// Decaying.
		kbUnitQuerySetUnitType(gFoodQuery, cUnitTypeHerdable);
		kbUnitQuerySetPlayerID(gFoodQuery, 0, false);
		kbUnitQuerySetSeeableOnly(gFoodQuery, true);
		kbUnitQuerySetActionType(gFoodQuery, cActionTypeDeath);
		numberResults = kbUnitQueryExecute(gFoodQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			if (resourceCloserToAlly(resourceID))
				continue;

			xsSetContextPlayer(0);
			numWorkers = kbUnitGetNumberWorkers(resourceID);
			xsSetContextPlayer(cMyID);
			// Too many current gatherers.
			if (numWorkers >= 4)
			{
				// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			arrayPushInt(gDecayingAnimals, resourceID);
			arrayPushInt(gDecayingNumWorkers, numWorkers);
			resourceWorth = resourceWorth + 1;
		}

		kbUnitQueryResetResults(gFoodQuery);

		// Live.
		kbUnitQuerySetPlayerID(gFoodQuery, cMyID, false);
		kbUnitQuerySetActionType(gFoodQuery, -1);
		kbUnitQuerySetSeeableOnly(gFoodQuery, false);
		kbUnitQuerySetState(gFoodQuery, cUnitStateAlive);
		numberResults = kbUnitQueryExecute(gFoodQuery);
		numWorkers = 0; // If they are alive, there should be 0 workers.

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			// Avoid unfattened animals.
			if (kbUnitGetResourceAmount(resourceID, cResourceFood) <
				kbUnitGetCarryCapacity(resourceID, cResourceFood))
				continue;

			// Avoid animals on shrines. Probably will always be false as
			// since they are our herdables, they must be on our shrines, which would
			// make us Japanese -- not even in this conditional statement.
			xsSetContextPlayer(0);
			temp = kbUnitGetTargetUnitID(resourceID);
			xsSetContextPlayer(cMyID);
			if (kbUnitIsType(temp, cUnitTypeypShrineJapanese) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine2) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine3) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine4) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine5) == true)
			{
				continue;
			}

			arrayPushInt(gFoodResources, resourceID);
			arrayPushInt(gFoodNumWorkers, numWorkers);
			arrayPushInt(gMaxFoodWorkers, 5);
			resourceWorth = resourceWorth + 1;
		}

		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gFoodQuery);
	}

	// Huntables.
	if (cMyCiv != cCivJapanese && totalResourceWorth < gNumFoodVills)
	{	// Decaying
		kbUnitQuerySetUnitType(gFoodQuery, cUnitTypeHuntable);
		kbUnitQuerySetPlayerID(gFoodQuery, 0, false);
		kbUnitQuerySetActionType(gFoodQuery, cActionTypeDeath);
		kbUnitQuerySetSeeableOnly(gFoodQuery, true);
		kbUnitQuerySetState(gFoodQuery, cUnitStateAny);
		numberResults = kbUnitQueryExecute(gFoodQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			if (resourceCloserToAlly(resourceID))
				continue;

			xsSetContextPlayer(0);
			numWorkers = kbUnitGetNumberWorkers(resourceID);
			xsSetContextPlayer(cMyID);
			// Too many current gatherers.
			if (numWorkers >= 5)
			{
				// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gDecayingAnimals, resourceID);
			arrayPushInt(gDecayingNumWorkers, numWorkers);
			resourceWorth = resourceWorth + 1;
		}

		kbUnitQueryResetResults(gFoodQuery);

		// Live
		kbUnitQuerySetActionType(gFoodQuery, -1);
		kbUnitQuerySetState(gFoodQuery, cUnitStateAlive);
		kbUnitQuerySetSeeableOnly(gFoodQuery, false);
		numberResults = kbUnitQueryExecute(gFoodQuery);
		numWorkers = 0; // If they are alive, there should be 0 workers.

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			if (resourceCloserToAlly(resourceID))
				continue;

			// Avoid animals on shrines.
			xsSetContextPlayer(0);
			temp = kbUnitGetTargetUnitID(resourceID);
			xsSetContextPlayer(cMyID);
			if (kbUnitIsType(temp, cUnitTypeypShrineJapanese) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine2) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine3) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine4) == true ||
				kbUnitIsType(temp, cUnitTypeypWJToshoguShrine5) == true)
			{
				continue;
			}

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gFoodResources, resourceID);
			arrayPushInt(gFoodNumWorkers, numWorkers);
			arrayPushInt(gMaxFoodWorkers, 5);
			resourceWorth = resourceWorth + 1;
		}

		resourceWorth = resourceWorth * 4; // Count a Huntable as 4 villagers.
		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gFoodQuery);
	}

	// Cherry Orchards.
	if (totalResourceWorth < gNumFoodVills)
	{
		kbUnitQuerySetMaximumDistance(gFoodQuery, -1);
		kbUnitQuerySetPlayerID(gFoodQuery, cMyID, false);
		kbUnitQuerySetState(gFoodQuery, cUnitStateAlive);
		kbUnitQuerySetUnitType(gFoodQuery, cUnitTypeypBerryBuilding);
		numberResults = kbUnitQueryExecute(gFoodQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			// Too many current gatherers on an Orchard.
			numWorkers = kbUnitGetNumberWorkers(resourceID);
			if (numWorkers == 28)
			{	// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			arrayPushInt(gFoodResources, resourceID);
			arrayPushInt(gFoodNumWorkers, numWorkers);
			arrayPushInt(gMaxFoodWorkers, 28);
			resourceWorth = resourceWorth + 1;
		}
		resourceWorth = resourceWorth * 21; // Count a cherry orchard as 21 villagers.
		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gFoodQuery);
	}

	// Berry types.
	if (totalResourceWorth < gNumFoodVills)
	{
		kbUnitQuerySetMaximumDistance(gFoodQuery, 220.0);
		kbUnitQuerySetPlayerID(gFoodQuery, 0, false);
		kbUnitQuerySetState(gFoodQuery, cUnitStateAny);
		kbUnitQuerySetUnitType(gFoodQuery, cUnitTypeAbstractFruit);
		kbUnitQueryExecute(gFoodQuery);
		numberResults = kbUnitQueryNumberResults(gFoodQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);

			// Mango Groves are listed as 'AbstractFruit' in protoy.xml.
			if (kbUnitIsType(resourceID, cUnitTypeypGroveBuilding) == true)
				continue;

			if (resourceCloserToAlly(resourceID))
				continue;

			// Too many current gatherers on Berry Bushes.
			xsSetContextPlayer(0);
			numWorkers = kbUnitGetNumberWorkers(resourceID);
			xsSetContextPlayer(cMyID);
			if (numWorkers >= 5)
			{
				// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gFoodResources, resourceID);
			arrayPushInt(gFoodNumWorkers, numWorkers);
			arrayPushInt(gMaxFoodWorkers, 5);
			resourceWorth = resourceWorth + 1;
		}

		resourceWorth = resourceWorth * 4; // Count a cherry orchard as 21 villagers.
		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gFoodQuery);
	}

	// Mills/Farms/Paddies/Fields.
	if (totalResourceWorth < gNumFoodVills || kbGetAge() >= cAge4)
	{
		kbUnitQuerySetMaximumDistance(gFoodQuery, -1);
		kbUnitQuerySetPlayerID(gFoodQuery, cMyID, false);
		kbUnitQuerySetState(gFoodQuery, cUnitStateABQ);
		kbUnitQuerySetUnitType(gFoodQuery, gFarmUnit);
		kbUnitQueryExecute(gFoodQuery);
		numberResults = kbUnitQueryNumberResults(gFoodQuery);
		int maxNumWorkers = 10;

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gFoodQuery, i);
			numWorkers = kbUnitGetNumberWorkers(resourceID);

			// Field on Gold or maxed out.
			if (kbUnitIsType(resourceID, cUnitTypedeField))
			{
				if (aiUnitGetTactic(resourceID) == cTacticFieldCoin)
					continue;
				else if (numWorkers == 3)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
				maxNumWorkers = 3;
			}
			// Paddy on Gold or maxed out.
			else if (kbUnitIsType(resourceID, cUnitTypeypRicePaddy))
			{
				if (aiUnitGetTactic(resourceID) == cTacticPaddyCoin)
					continue;
				else if (numWorkers == 10)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
			}
			// Hacienda on Gold or maxed out.
			else if (kbUnitIsType(resourceID, cUnitTypedeHacienda))
			{
				if (aiUnitGetTactic(resourceID) == cTacticHaciendaCoin)
					continue;
				else if (numWorkers == 20)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
				maxNumWorkers = 20;
			}
			// Mill/Farm maxed out.
			else if (numWorkers == 10)
			{	// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			arrayPushInt(gFoodResources, resourceID);
			arrayPushInt(gFoodNumWorkers, numWorkers);
			arrayPushInt(gMaxFoodWorkers, maxNumWorkers);
			resourceWorth = resourceWorth + 1;
		}

		if (civIsAfrican() == true)
			resourceWorth = resourceWorth * 2.7; // Count a Food Field as 2.7 villagers.
		else if (cMyCiv == cCivDEMexicans)
			resourceWorth = resourceWorth * 18; // Count a Food Hacienda as 18 villagers.
		else
			resourceWorth = resourceWorth * 9; // Count a Mill/Farm/Food Paddy as 9 villagers.

		totalResourceWorth += resourceWorth;
		// Reset of the query is unecessary as the rule will reset it when it runs again.
	}

	// Basically, if we have reached this point, we should probably build a food-producing
	// building because we do not want to run out of gold resources.
	int millWorth = 10;
	int maxPlans = 4;
	if (cMyCiv == cCivDEMexicans)
	{
		millWorth = 20;
		maxPlans = 2;
	}
	else if (civIsAfrican() == true)
	{
		millWorth = 3;
		maxPlans = 8;
	}

	if (totalResourceWorth < gNumFoodVills && kbGetAge() >= cAge3)
	{
		arrayRemoveDonePlans(gMillTypePlans);
		if (arrayGetSize(gMillTypePlans) < maxPlans)
		{
			if (gNumFoodVills - totalResourceWorth > millWorth * arrayGetSize(gMillTypePlans))
			{
				planID = addBetterMillBuildPlan();
				if (planID >= 0)
				{
					arrayPushInt(gMillTypePlans, planID);
					aiPlanSetDesiredPriority(planID, 99);
					aiPlanSetDesiredResourcePriority(planID, 99);
				}
			}
		}
	}
}

//==============================================================================
// updateWoodBreakdown
//
// Populate an array with wood resources that should be gathered.
//==============================================================================
void updateBetterWoodBreakdown(void)
{
	arrayResetSelf(gWoodResources);
	arrayResetSelf(gWoodNumWorkers);

	int numberResults = 0;
	int resourceID = -1;
	int planID = -1;
	int numWorkers = -1;

	if (gWoodQuery < 0)
	{
		gWoodQuery = kbUnitQueryCreate("Wood Resources Query");
		kbUnitQuerySetPlayerID(gWoodQuery, -1, false);
		kbUnitQuerySetPlayerRelation(gWoodQuery, cPlayerRelationAny);
		kbUnitQuerySetIgnoreKnockedOutUnits(gWoodQuery, true);
		kbUnitQuerySetPosition(gWoodQuery, gHomeBase);
		//kbUnitQuerySetAreaGroupID(gWoodQuery, kbAreaGroupGetIDByPosition(gHomeBase));
		kbUnitQuerySetAscendingSort(gWoodQuery, true);
		kbUnitQuerySetMaximumDistance(gWoodQuery, 300.0);
	}
	kbUnitQueryResetResults(gWoodQuery);

	if (numberResults < gNumWoodVills)
	{
		kbUnitQuerySetPlayerID(gWoodQuery, 0, false);
		kbUnitQuerySetUnitType(gWoodQuery, cUnitTypeWood);
		kbUnitQuerySetState(gWoodQuery, cUnitStateAlive);
		kbUnitQuerySetSeeableOnly(gWoodQuery, false);
		kbUnitQueryExecute(gWoodQuery);

		kbUnitQuerySetUnitType(gWoodQuery, cUnitTypeTree);
		kbUnitQuerySetState(gWoodQuery, cUnitStateDead);
		kbUnitQuerySetSeeableOnly(gWoodQuery, true);
		kbUnitQueryExecute(gWoodQuery);
		numberResults = kbUnitQueryNumberResults(gWoodQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gWoodQuery, i);

			xsSetContextPlayer(0);
			numWorkers = kbUnitGetNumberWorkers(resourceID);
			xsSetContextPlayer(cMyID);

			// Too many current gatherers.
			if (numWorkers >= 5)
				continue;

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gWoodResources, resourceID);
			arrayPushInt(gWoodNumWorkers, numWorkers);
		}
		// Reset of the query is unecessary as the rule will reset it when it runs again.
	}
}

//==============================================================================
// updateGoldBreakdown
//
// Populate an array with gold resources that should be gathered.
//==============================================================================
void updateBetterGoldBreakdown(void)
{
	arrayResetSelf(gGoldResources);
	arrayResetSelf(gGoldNumWorkers);
	arrayResetSelf(gMaxGoldWorkers);

	int numberResults = 0;
	float resourceWorth = 0.0;
	float totalResourceWorth = 0.0;
	int resourceID = -1;
	int tradingLodge = -1;
	int planID = -1;
	int numWorkers = -1;

	if (gGoldQuery < 0)
	{
		gGoldQuery = kbUnitQueryCreate("Gold Resources Query");
		kbUnitQuerySetPlayerID(gGoldQuery, -1, false);
		kbUnitQuerySetPlayerRelation(gGoldQuery, cPlayerRelationAny);
		kbUnitQuerySetIgnoreKnockedOutUnits(gGoldQuery, true);
		kbUnitQuerySetSeeableOnly(gGoldQuery, true);
		kbUnitQuerySetPosition(gGoldQuery, gHomeBase);
		//kbUnitQuerySetAreaGroupID(gGoldQuery, kbAreaGroupGetIDByPosition(gHomeBase));
		kbUnitQuerySetAscendingSort(gGoldQuery, true);
	}
	kbUnitQuerySetMaximumDistance(gGoldQuery, 200.0);
	if (kbGetAge() >= cAge4)
		kbUnitQuerySetMaximumDistance(gGoldQuery, 150.0);
	kbUnitQueryResetResults(gGoldQuery);

	// Mountain Monasteries. (Note: Allies of Ethiopia can gather, but it is not enhanced)
	if (totalResourceWorth < gNumGoldVills)
	{
		kbUnitQuerySetPlayerID(gGoldQuery, -1, false);
		kbUnitQuerySetPlayerRelation(gGoldQuery, cPlayerRelationAlly);
		kbUnitQuerySetUnitType(gGoldQuery, cUnitTypedeMountainMonastery);
		kbUnitQuerySetState(gGoldQuery, cUnitStateAlive);
		kbUnitQueryExecute(gGoldQuery);
		numberResults = kbUnitQueryNumberResults(gGoldQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gGoldQuery, i);

			if (kbUnitGetResourceAmount(resourceID, cResourceGold) < 1.0)
				continue;

			numWorkers = kbUnitGetNumberWorkers(resourceID);
			if (numWorkers == 20)
			{	// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gGoldResources, resourceID);
			arrayPushInt(gGoldNumWorkers, numWorkers);
			arrayPushInt(gMaxGoldWorkers, 20);
			resourceWorth = resourceWorth + 1;
		}

		if (cMyCiv == cCivDEEthiopians)
			resourceWorth = resourceWorth * 18; // Count a Mountain Monastery as 18 Villagers for Ethiopians.
		else
			resourceWorth = resourceWorth * 9; // Count it less since Ethiopia will primarily reap its benefit.
		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gGoldQuery);
	}

	// Mines.
	//
	// Ethiopians should only check this if we do not have a suitable monastery to work
	// or are almost maxed out working them. Otherwise all civs should check this as the
	// Mountain Monastery poses no benefit to their gathering rates.
	//
	if ((totalResourceWorth < gNumGoldVills) || (cMyCiv != cCivDEEthiopians))
	{
		kbUnitQuerySetPlayerID(gGoldQuery, 0, false);
		kbUnitQuerySetPlayerRelation(gGoldQuery, cPlayerRelationAny);
		kbUnitQuerySetUnitType(gGoldQuery, cUnitTypeAbstractMine);
		kbUnitQuerySetState(gGoldQuery, cUnitStateAlive);
		kbUnitQueryExecute(gGoldQuery);
		numberResults = kbUnitQueryNumberResults(gGoldQuery);

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gGoldQuery, i);

			if (resourceCloserToAlly(resourceID))
				continue;

			// We should not consider the mine here as its monastery will have been added
			// from the previous query section.
			if (getUnitCountByLocation(cUnitTypedeMountainMonastery, cPlayerRelationAny,
				cUnitStateABQ, kbUnitGetPosition(resourceID), 5.0) > 0)
				continue;

			// Trading Lodge not in the query since PlayerID is set to 0.
			// Anyways, this works better for building one.
			if (cMyCiv == cCivXPIroquois || cMyCiv == cCivXPSioux)
			{
				tradingLodge = findTradingLodge(resourceID);
				if (tradingLodge < 0)
					continue;
				else
				{
					resourceID = tradingLodge;
					numWorkers = kbUnitGetNumberWorkers(resourceID);
					// Too many current gatherers.
					if (numWorkers == 10)
					{	// Still count it because we are gathering it.
						resourceWorth = resourceWorth + 1;
						continue;
					}
				}
			}
			else
			{
				xsSetContextPlayer(0);
				numWorkers = kbUnitGetNumberWorkers(resourceID);
				xsSetContextPlayer(cMyID);
				// Too many current gatherers.
				if (numWorkers == 20)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
			}

			if (getDistance(kbUnitGetPosition(resourceID), gHomeBase) > 45)
			{
				if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
					cUnitStateAlive, kbUnitGetPosition(resourceID), 45.0) > 2)
					continue;
			}

			arrayPushInt(gGoldResources, resourceID);
			arrayPushInt(gGoldNumWorkers, numWorkers);
			arrayPushInt(gMaxGoldWorkers, 20);
			resourceWorth = resourceWorth + 1;
		}

		if (cMyCiv == cCivXPIroquois || cMyCiv == cCivXPSioux)
			resourceWorth = resourceWorth * 9; // Count a Tribal Marketplace as 9 villagers.
		else
			resourceWorth = resourceWorth * 18; // Count a Mine as 18 villagers.
		totalResourceWorth += resourceWorth;
		// Reset for other queries.
		resourceWorth = 0.0;
		kbUnitQueryResetResults(gGoldQuery);
	}

	// Estates/Paddies/Fields.
	if (totalResourceWorth < gNumGoldVills || kbGetAge() >= cAge4)
	{
		kbUnitQuerySetMaximumDistance(gGoldQuery, -1);
		kbUnitQuerySetPlayerID(gGoldQuery, cMyID, false);
		kbUnitQuerySetUnitType(gGoldQuery, gPlantationUnit);
		kbUnitQuerySetState(gGoldQuery, cUnitStateAlive);
		kbUnitQueryExecute(gGoldQuery);
		numberResults = kbUnitQueryNumberResults(gGoldQuery);
		int maxNumWorkers = 10;

		for (i = 0; < numberResults)
		{
			resourceID = kbUnitQueryGetResult(gGoldQuery, i);
			numWorkers = kbUnitGetNumberWorkers(resourceID);

			// Field on Food or maxed out.
			if (kbUnitIsType(resourceID, cUnitTypedeField))
			{
				if (aiUnitGetTactic(resourceID) == cTacticFieldFood)
					continue;
				else if (numWorkers == 3)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
				maxNumWorkers = 3;
			}
			// Paddy on Food or maxed out.
			else if (kbUnitIsType(resourceID, cUnitTypeypRicePaddy))
			{
				if (aiUnitGetTactic(resourceID) == cTacticPaddyFood)
					continue;
				else if (numWorkers == 10)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
			}
			// Hacienda on Food or maxed out.
			else if (kbUnitIsType(resourceID, cUnitTypedeHacienda))
			{
				if (aiUnitGetTactic(resourceID) == cTacticHaciendaFood)
					continue;
				else if (numWorkers == 20)
				{	// Still count it because we are gathering it.
					resourceWorth = resourceWorth + 1;
					continue;
				}
				maxNumWorkers = 20;
			}
			// Estate maxed out.
			else if (numWorkers == 10)
			{	// Still count it because we are gathering it.
				resourceWorth = resourceWorth + 1;
				continue;
			}

			arrayPushInt(gGoldResources, resourceID);
			arrayPushInt(gGoldNumWorkers, numWorkers);
			arrayPushInt(gMaxGoldWorkers, maxNumWorkers);
			resourceWorth = resourceWorth + 1;
		}

		if (civIsAfrican() == true)
			resourceWorth = resourceWorth * 2.9; // Count a Gold Field as 2.9 villagers.
		else if (cMyCiv == cCivDEMexicans)
			resourceWorth = resourceWorth * 18; // Count a Gold Hacienda as 18 villagers.
		else
			resourceWorth = resourceWorth * 9; // Count an Estate/GoldPaddy as 9 villagers.
		
		totalResourceWorth += resourceWorth;
		// Reset of the query is unecessary as the rule will reset it when it runs again.
	}

	// Basically, if we have reached this point, we should probably build a gold-producing
	// building because we do not want to run out of gold resources.
	int plantationWorth = 10;
	int maxPlans = 4;
	if (cMyCiv == cCivDEMexicans)
	{
		plantationWorth = 20;
		maxPlans = 2;
	}
	else if (civIsAfrican())
	{
		plantationWorth = 3;
		maxPlans = 8;
	}
	if (totalResourceWorth < gNumGoldVills && kbGetAge() >= cAge3)
	{
		arrayRemoveDonePlans(gPlantationTypePlans);
		if (arrayGetSize(gPlantationTypePlans) < maxPlans)
		{
			if (gNumGoldVills - totalResourceWorth > plantationWorth * arrayGetSize(gPlantationTypePlans))
			{
				planID = addBetterPlantationBuildPlan();
				if (planID >= 0)
				{
					arrayPushInt(gPlantationTypePlans, planID);
					aiPlanSetDesiredPriority(planID, 99);
					aiPlanSetDesiredResourcePriority(planID, 99);
				}
			}
		}
	}
}

rule stealAllVillagers
inactive
minInterval 10
{
	cvOkToGatherFood = false;      // Setting it false will turn off food gathering. True turns it on.
	cvOkToGatherGold = false;      // Setting it false will turn off gold gathering. True turns it on.
	cvOkToGatherWood = false;      // Setting it false will turn off wood gathering. True turns it on.
	int planID = -1;
	int numberPlans = aiPlanGetActiveCount();
	for (i = 0; < numberPlans)
	{
		planID = aiPlanGetIDByActiveIndex(i);
		if (aiPlanGetType(planID) == cPlanGather)
		{
			aiPlanSetDesiredPriority(planID, 1);
			aiPlanSetActive(planID, false);
			aiPlanSetNoMoreUnits(planID, true);
		}
	}

	if (gVillagerReservePlan < 0)
	{
		gVillagerReservePlan = aiPlanCreate("Villager reserve plan to keep them from gather plans", cPlanReserve);
		aiPlanSetDesiredPriority(gVillagerReservePlan, 20); // Low so building plans can steal from it
		aiPlanAddUnitType(gVillagerReservePlan, gEconUnit, 1, 125, 125);
		aiPlanSetActive(gVillagerReservePlan, true);
	}
	// Look for villagers to put onto a reserve plan
	int unitID = -1;
	int unitPlanID = -1;
	int count = 0;
	int villagerQueryID = createSimpleUnitQuery(gEconUnit, cMyID, cUnitStateAlive);
	int numberFound = kbUnitQueryExecute(villagerQueryID);
	for (i = 0; < numberFound)
	{
		unitID = kbUnitQueryGetResult(villagerQueryID, i);
		unitPlanID = kbUnitGetPlanID(unitID);
		if (aiPlanGetType(unitPlanID) == cPlanGather && kbUnitGetPlanID(unitID) != gVillagerReservePlan)           
		{
			aiPlanAddUnit(gVillagerReservePlan, unitID);
			count += 1;
		}
	}
	xsDisableSelf();
}


//==============================================================================
//
// taskVillagers
//
// - Control villager gathering assignments.
//
// Adapted from the betterAI mod to work on island and archipelago maps
//
//==============================================================================
rule taskVillagers
inactive
minInterval 2
{
	if (gArrayPlan < 0)
	{
		xsEnableRule("stealAllVillagers");
	}
	//stealAllVillagers();
	if (gArrayPlan < 0)
	{
		gArrayPlan = aiPlanCreate("Array Storage", cPlanData);
		gArrayPlanSizes = aiPlanCreate("Plan Size Storage", cPlanData);
		gArrayPlanNumElements = aiPlanCreate("Plan Num Elements Storage", cPlanData);
		gFoodResources = arrayCreateInt(1, "Food Resources");
		gDecayingAnimals = arrayCreateInt(1, "Decaying Hunts");
		gWoodResources = arrayCreateInt(1, "Wood Resources");
		gGoldResources = arrayCreateInt(1, "Gold Resources");
		gFoodNumWorkers = arrayCreateInt(1, "Number Workers on Food Resource");
		gMaxFoodWorkers = arrayCreateInt(1, "Max Workers Allowed on Food Resource");
		gDecayingNumWorkers = arrayCreateInt(1, "Number Workers on Decaying Food Resource");
		gWoodNumWorkers = arrayCreateInt(1, "Number Workers on Wood Resource");
		gGoldNumWorkers = arrayCreateInt(1, "Number Workers on Gold Resource");
		gMaxGoldWorkers = arrayCreateInt(1, "Max Workers Allowed on Gold Resource");
		gMillTypePlans = arrayCreateInt(1, "Mill Type Build Plans");
		gPlantationTypePlans = arrayCreateInt(1, "Plantation Type Build Plans");
		gQueuedBuildingPriority = arrayCreateInt(1, "Inactive Build Plans Priority");
	}

	if (gVillagerQuery < 0)
	{
		gVillagerQuery = kbUnitQueryCreate("Villager Query");
		kbUnitQuerySetPlayerID(gVillagerQuery, cMyID);
		kbUnitQuerySetPlayerRelation(gVillagerQuery, -1);
		kbUnitQuerySetState(gVillagerQuery, cUnitStateAlive);
		kbUnitQuerySetPosition(gVillagerQuery, gHomeBase);
		kbUnitQuerySetAscendingSort(gVillagerQuery, true);
		kbUnitQuerySetIgnoreKnockedOutUnits(gVillagerQuery, true);
	}
	kbUnitQueryResetResults(gVillagerQuery);
	kbUnitQuerySetUnitType(gVillagerQuery, cUnitTypeLogicalTypeSettlerBuildLimit);
	kbUnitQueryExecute(gVillagerQuery);
	kbUnitQuerySetUnitType(gVillagerQuery, cUnitTypeSettlerWagon);
	kbUnitQueryExecute(gVillagerQuery);

	if (xsIsRuleEnabled("villagerRetreat") == false)
	{
		xsEnableRule("villagerRetreat");
	}

	// Used throughout the rule to manage the villagers.
	int villagerPop = kbGetPopulationSlotsByQueryID(gVillagerQuery) +
		getDedicatedGatherers(cResourceFood) +
		getDedicatedGatherers(cResourceWood) +
		getDedicatedGatherers(cResourceGold);
	int numFoodVills = 0;
	int numWoodVills = 0;
	int numGoldVills = 0;
	int pop = 1;
	int unitID = -1;
	int actionID = -1;
	int resourceID = -1;
	int planID = -1;

	// Used to compare resources within each resource type, to select the
	// "best" one relative to the villager under consideration.
	vector location = cInvalidVector;
	vector dropoffIslandLoc = cInvalidVector;
    vector resourceLocation = cInvalidVector;
	int tempIndex = -1;
	int closestResourceID = -1;
	int closestResourceIndex = -1;
	float closestDistance = 0.0;
	float tempDistance = 0.0;

	// Used to keep track of the "best" resource of each type, in the sense
	// of their relative location to the current villager being considered.
	// The villager is then tasked to the closest one of these resources.
	int foodID = -1;
	int foodIndex = -1;
	float foodDistance = 0.0;
	int woodID = -1;
	int woodIndex = -1;
	float woodDistance = 0.0;
	int goldID = -1;
	int goldIndex = -1;
	float goldDistance = 0.0;

	// For Transport
	vector pickup = cInvalidVector;
	vector dropoffLoc = cInvalidVector;
	int transportPlanID = -1;

	// Used to task a villager to shoot hunts toward a particular location.
	vector targetLocation = cInvalidVector;

   // AssertiveWall: keep track of how many to transport
   int migrantNumber = 0;

	// Subtract from our total count villagers that are assigned to a plan,
	// as well as those on crates. Also, make sure crates are gathered.
	for (i = 0; < kbUnitQueryNumberResults(gVillagerQuery))
	{
		unitID = kbUnitQueryGetResult(gVillagerQuery, i);
		if (kbUnitIsType(unitID, cUnitTypeSettlerWagon))
			pop = 2;
		else
			pop = 1;

		if (kbUnitGetPlanID(unitID) >= 0 && kbUnitGetPlanID(unitID) != gVillagerReservePlan)
			villagerPop = villagerPop - pop;
	}
	/* villagerPop = villagerPop - gReservedFoodVillagers -
		gReservedWoodVillagers - gReservedGoldVillagers;
	if (villagerPop < 0)
		villagerPop = 0; */

	numFoodVills = (villagerPop - gReservedFoodVillagers - gReservedWoodVillagers - gReservedGoldVillagers) * 
					aiGetResourcePercentage(cResourceFood) + gReservedFoodVillagers;
	numGoldVills = (villagerPop - gReservedFoodVillagers - gReservedWoodVillagers - gReservedGoldVillagers) *
					aiGetResourcePercentage(cResourceGold) + gReservedGoldVillagers;
	// villagerPop = villagerPop + gReservedFoodVillagers + gReservedGoldVillagers;
	numWoodVills = (villagerPop - gReservedFoodVillagers - gReservedWoodVillagers - gReservedGoldVillagers) *
					aiGetResourcePercentage(cResourceWood) + gReservedWoodVillagers;

	numFoodVills = numFoodVills - getDedicatedGatherers(cResourceFood);
	if (numFoodVills < 0)
		numFoodVills = 0;
	numGoldVills = numGoldVills - getDedicatedGatherers(cResourceGold);
	if (numGoldVills < 0)
		numGoldVills = 0;
	numWoodVills = numWoodVills - getDedicatedGatherers(cResourceWood);
	if (numWoodVills < 0)
		numWoodVills = 0;

	// Set the global gatherer data.
	gNumFoodVills = numFoodVills;
	gNumWoodVills = numWoodVills;
	gNumGoldVills = numGoldVills;

	// Search for food.
	updateBetterFoodBreakdown();

	// Search for wood.
	updateBetterWoodBreakdown();

	// Search for gold.
	updateBetterGoldBreakdown();

	if (arrayGetSize(gWoodResources) < 2) // Until I configure arrayGetSize to return 0.
	{
		numFoodVills = numFoodVills + (numWoodVills / 2);
		numGoldVills = numGoldVills + (numWoodVills / 2) + (numWoodVills % 2);
		numWoodVills = 0;
	}

	// ============================================================ //

	// Loop through the villagers (from the query) to give them assignments.
	for (i = 0; < kbUnitQueryNumberResults(gVillagerQuery))
	{
		unitID = kbUnitQueryGetResult(gVillagerQuery, i);
		actionID = kbUnitGetActionType(unitID);
		targetLocation = cInvalidVector;
		switch (actionID)
		{
			case cActionTypeMove: // Currently moving.
			case cActionTypeMoveByGroup: // Currently moving.
			case cActionTypeSocialise: // Currently on Community Plaza.
				continue;
			case cActionTypeBuild: // Currently building in a plan.
			{
				if (kbUnitGetPlanID(unitID) >= 0)
					continue;
			}
			default: // Units assigned to a plan.
			{
				if (kbUnitGetPlanID(unitID) >= 0 && kbUnitGetPlanID(unitID) != gVillagerReservePlan)
					continue;
			}
		}

		if (kbUnitIsType(unitID, cUnitTypeSettlerWagon))
			pop = 2;
		else
			pop = 1;

		resourceID = kbUnitGetTargetUnitID(unitID);
		if (resourceID >= 0)
		{
			// Currently on crates/berries/mines/mill units/estate units.
			// and *not* assigned to a plan.
			if (actionID == cActionTypeGather)
			{
				// 'deHacienda' is listed as '<unittype>Gold</unittype>', so we need to account for this first.
				if (kbUnitIsType(resourceID, cUnitTypedeHacienda))
				{
					if (aiUnitGetTactic(resourceID) == cTacticHaciendaCoin)
					{
						if (numGoldVills > 0)
						{
							numGoldVills = numGoldVills - pop;
							continue;
						}
					}
					else if (numFoodVills > 0) // Then it must be food tactic.
					{
						numFoodVills = numFoodVills - pop;
						continue;
					}
				}
				else if (kbUnitIsType(resourceID, cUnitTypeGold))
				{
					if (numGoldVills > 0)
					{
						numGoldVills = numGoldVills - pop;
						continue;
					}
				}
				// 'ypRicePaddy' and 'deField' are listed as '<unittype>Food</unittype>' in protoy.xml
				else if (kbUnitIsType(resourceID, cUnitTypeypRicePaddy) || kbUnitIsType(resourceID, cUnitTypedeField))
				{	// NOTE: I do not think there are 'team' rice paddy or field cards, unlike the Hacienda.
					// Otherwise I should distinguish paddy from field tactics by their constant ID in the odd case 
					// that some civ gets a one of these from an ally shipment and cannot evaluate this.
					if (aiUnitGetTactic(resourceID) == gFarmGoldTactic)
					{
						if (numGoldVills > 0)
						{
							numGoldVills = numGoldVills - pop;
							continue;
						}
					}
					else if (numFoodVills > 0) // Then it must be food tactic.
					{
						numFoodVills = numFoodVills - pop;
						continue;
					}
				}
				// Mills and Farms.
				else if (kbUnitIsType(resourceID, cUnitTypeFood))
				{
					if (numFoodVills > 0)
					{
						numFoodVills = numFoodVills - pop;
						continue;
					}
				}
			}
			// Currently hunting/chopping.
			else if (actionID == cActionTypeHunting)
			{
				if (kbUnitIsType(resourceID, cUnitTypeTree))
				{
					if (numWoodVills > 0)
					{
						numWoodVills = numWoodVills - pop;
						continue;
					}
				}
				else if (kbUnitIsType(resourceID, cUnitTypeHuntable) ||
					kbUnitIsType(resourceID, cUnitTypeHerdable))
				{
					if (numFoodVills > 0)
					{
						numFoodVills = numFoodVills - pop;
						continue;	
					}
				}
			}
		}

		location = kbUnitGetPosition(unitID);
		foodDistance = 9999.0;
		woodDistance = 9999.0;
		goldDistance = 9999.0;

		// ========================================
		// Food Resources.
		//
		if (numFoodVills > 0)
		{
			// ========================================
			// Check for decaying huntables first.
			resourceID = -1;
			// Find a starting comparison that does not have too
			// many workers.
			for (tempIndex = 0; < arrayGetSize(gDecayingAnimals))
			{	// Should not matter for Japanese as resourceID will always be -1.
				if (arrayGetInt(gDecayingNumWorkers, tempIndex) >= 5)
					continue;

				resourceID = arrayGetInt(gDecayingAnimals, tempIndex);
				break;
			}

			if (resourceID >= 0)
			{
				closestResourceID = resourceID;
				closestResourceIndex = tempIndex;
				closestDistance = getDistance(location, kbUnitGetPosition(closestResourceID));

				for (j = tempIndex + 1; < arrayGetSize(gDecayingAnimals))
				{
					resourceID = arrayGetInt(gDecayingAnimals, j);

					if (arrayGetInt(gDecayingNumWorkers, j) >= 5)
						continue;

					tempDistance = getDistance(location, kbUnitGetPosition(resourceID));
					if (tempDistance < closestDistance)
					{
						closestResourceID = resourceID;
						closestResourceIndex = j;
						closestDistance = tempDistance;
					}

					if (closestDistance < 12.0)
						break;	// This one is close enough.
				}
				foodID = closestResourceID;
				foodIndex = closestResourceIndex;
				foodDistance = closestDistance;
				goto PrioritizeDecayingAnimal;
			}
			//
			// End of check for decaying huntables.
			// ========================================

			// ========================================
			// All other land food resources.
			//
			resourceID = -1;
			// Find a starting comparison that does not have too
			// many workers.
			for (tempIndex = 0; < arrayGetSize(gFoodResources))
			{
				if (arrayGetInt(gFoodNumWorkers, tempIndex) >= arrayGetInt(gMaxFoodWorkers, tempIndex))
					continue;

				resourceID = arrayGetInt(gFoodResources, tempIndex);
				break;
			}

			if (resourceID >= 0)
			{
				closestResourceID = resourceID;
				closestResourceIndex = tempIndex;
				closestDistance = getDistance(
					location,
					kbUnitGetPosition(closestResourceID)
				);

				for (j = tempIndex + 1; < arrayGetSize(gFoodResources))
				{
					resourceID = arrayGetInt(gFoodResources, j);

					if (arrayGetInt(gFoodNumWorkers, j) >= arrayGetInt(gMaxFoodWorkers, j))
						continue;

					tempDistance = getDistance(location, kbUnitGetPosition(resourceID));
					if (tempDistance < closestDistance)
					{
						closestResourceID = resourceID;
						closestResourceIndex = j;
						closestDistance = tempDistance;
					}

					if (closestDistance < 12.0)
						break;	// This one is close enough.
				}
				foodID = closestResourceID;
				foodIndex = closestResourceIndex;
				foodDistance = closestDistance;
			}
			//
			// End of check for all other land food resources.
			// ========================================
		}
		//
		// End Food Resources.
		// ========================================

		// If we found a decaying huntable to work, we jump to this point from "goto",
		// bypassing the live huntable check.
		label PrioritizeDecayingAnimal;

		// ========================================
		// Wood Resources.
		//
		if (numWoodVills > 0)
		{
			resourceID = -1;
			// Find a starting comparison that does not have too
			// many workers.
			for (tempIndex = 0; < arrayGetSize(gWoodResources))
			{
				if (kbUnitIsType(resourceID, cUnitTypeypGroveBuilding) == true &&
					arrayGetInt(gWoodNumWorkers, tempIndex) == 25)
					continue;
				else if (arrayGetInt(gWoodNumWorkers, tempIndex) >= 5)
					continue;

				resourceID = arrayGetInt(gWoodResources, tempIndex);
				break;
			}

			if (resourceID >= 0)
			{
				closestResourceID = resourceID;
				closestResourceIndex = tempIndex;
				closestDistance = getDistance(
					location,
					kbUnitGetPosition(closestResourceID)
				);

				for (j = tempIndex + 1; < arrayGetSize(gWoodResources))
				{
					resourceID = arrayGetInt(gWoodResources, j);

					if (kbUnitIsType(resourceID, cUnitTypeypGroveBuilding) == true &&
						arrayGetInt(gWoodNumWorkers, j) == 25)
						continue;
					else if (arrayGetInt(gWoodNumWorkers, j) >= 5)
						continue;

					tempDistance = getDistance(location, kbUnitGetPosition(resourceID));
					if (tempDistance < closestDistance)
					{
						closestResourceID = resourceID;
						closestResourceIndex = j;
						closestDistance = tempDistance;
					}

					if (closestDistance < 12.0)
						break;	// This one is close enough.
				}
				woodID = closestResourceID;
				woodIndex = closestResourceIndex;
				woodDistance = closestDistance;
			}
		}
		//
		// End Wood Resources.
		// ========================================

		// ========================================
		// Gold Resources.
		//
		if (numGoldVills > 0)
		{
			resourceID = -1;
			// Find a starting comparison that does not have too
			// many workers.
			for (tempIndex = 0; < arrayGetSize(gGoldResources))
			{
				if (arrayGetInt(gGoldNumWorkers, tempIndex) >= arrayGetInt(gMaxGoldWorkers, tempIndex))
					continue;

				resourceID = arrayGetInt(gGoldResources, tempIndex);
				break;
			}

			if (resourceID >= 0)
			{
				closestResourceID = resourceID;
				closestResourceIndex = tempIndex;
				closestDistance = getDistance(
					location,
					kbUnitGetPosition(closestResourceID)
				);

				for (j = tempIndex + 1; < arrayGetSize(gGoldResources))
				{
					resourceID = arrayGetInt(gGoldResources, j);

					if (arrayGetInt(gGoldNumWorkers, j) >= arrayGetInt(gMaxGoldWorkers, j))
						continue;

					tempDistance = getDistance(location, kbUnitGetPosition(resourceID));
					if (tempDistance < closestDistance)
					{
						closestResourceID = resourceID;
						closestResourceIndex = j;
						closestDistance = tempDistance;
					}

					if (closestDistance < 12.0)
						break;	// This one is close enough.
				}
				goldID = closestResourceID;
				goldIndex = closestResourceIndex;
				goldDistance = closestDistance;
			}
		}
		//
		// End Gold Resources.
		// ========================================

		// AssertiveWall: Determine if we need transport. 
		int resourcePicked = -1; // 1 = food, 2 = gold, 3 = wood

		if (foodDistance < woodDistance) // Food is closer than Wood.
		{
			if (foodDistance < goldDistance) // Food is closer than Gold.
			{
            	resourcePicked = 1;
				if (kbUnitIsType(foodID, cUnitTypeHuntable) && /* arrayGetInt(gFoodNumWorkers, foodIndex) == 0 && */
					kbUnitGetCurrentHitpoints(foodID) >= kbUnitGetMaximumHitpoints(foodID))
				{
					// Swedish should try to herd huntables toward nearby Torps.
					if (cMyCiv == cCivDESwedish)
						targetLocation = kbUnitGetPosition(
							getClosestUnit(cUnitTypedeTorp, cMyID,
							cUnitStateABQ, kbUnitGetPosition(foodID), 45.0)
						);
					// African civs should try to herd huntables toward nearby Granaries.
					else if (civIsAfrican())
						targetLocation = kbUnitGetPosition(
							getClosestUnit(cUnitTypedeGranary, cMyID,
							cUnitStateABQ, kbUnitGetPosition(foodID), 45.0)
						);

					if (targetLocation == cInvalidVector)
						targetLocation = gHomeBase;
					aiTaskUnitMove(unitID, (targetLocation + (kbUnitGetPosition(foodID) - targetLocation) +
						xsVectorNormalize(kbUnitGetPosition(foodID) - targetLocation) * 16.0));
					//aiTaskUnitWork(unitID, foodID, true);

					// Update the number of workers on the food unit.
					arraySetInt(gFoodNumWorkers, foodIndex, (arrayGetInt(gFoodNumWorkers, foodIndex) + 1));
				}
				else
				{
					//aiTaskUnitWork(unitID, foodID);

					// Update the number of workers on the food unit.
					arraySetInt(gDecayingNumWorkers, foodIndex, (arrayGetInt(gDecayingNumWorkers, foodIndex) + 1));
				}
				numFoodVills = numFoodVills - pop;
			}
			else // Gold is closer than Food.
			{
            	resourcePicked = 2;
				//aiTaskUnitWork(unitID, goldID);
				// Update the number of workers on the gold unit.
				arraySetInt(gGoldNumWorkers, goldIndex, (arrayGetInt(gGoldNumWorkers, goldIndex) + 1));
				numGoldVills = numGoldVills - pop;
			}
		}
		else if (woodDistance < goldDistance) // Wood is closer than both Food and Gold.
		{
         	resourcePicked = 3;
			numWoodVills = numWoodVills - pop;
			//aiTaskUnitWork(unitID, woodID);
			// Help vills that sometimes get stuck.
			aiTaskUnitMove(unitID, kbUnitGetPosition(woodID) + gDirection_UP, true);

			// Update the number of workers on the wood unit.
			arraySetInt(gWoodNumWorkers, woodIndex, (arrayGetInt(gWoodNumWorkers, woodIndex) + 1));
		}
		else // Gold is closer than both Food and Wood.
		{
         	resourcePicked = 2;
			numGoldVills = numGoldVills - pop;
			//aiTaskUnitWork(unitID, goldID);

			// Update the number of workers on the gold unit.
			arraySetInt(gGoldNumWorkers, goldIndex, (arrayGetInt(gGoldNumWorkers, goldIndex) + 1));
		}

		// Get the location of what we picked, and set it to 
		if (resourcePicked == 1)
		{
			resourceLocation = kbUnitGetPosition(foodID);
			int resourcepickedid = foodID;
		}
		else if (resourcePicked == 2)
		{
			resourceLocation = kbUnitGetPosition(goldID);
			resourcepickedid = goldID;
		}
		else if (resourcePicked == 3)
		{
			resourceLocation = kbUnitGetPosition(woodID);
			resourcepickedid = woodID;
		}
		// Check to see if it needs transport
		if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(location), kbAreaGroupGetIDByPosition(resourceLocation)) == false)
		{
			// Use the first pickup and dropoff locations, and only bring migrants that can be picked up from the same spot
			if (pickup == cInvalidVector)
			{
				pickup = location;
			}

			if (dropoffIslandLoc == cInvalidVector)
			{
				dropoffIslandLoc = resourceLocation;
			}

			if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(location), kbAreaGroupGetIDByPosition(pickup)) == true)
			{
				migrantNumber += 1;
			}	
		}
		else
		{
			aiTaskUnitWork(unitID, resourcepickedid, true);
		}
	}

	if (migrantNumber > 0 && pickup != cInvalidVector && dropoffIslandLoc != cInvalidVector)
	{
		int numberTransportPlans = aiPlanGetNumber(cPlanTransport);
		vector homePosition = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
		int numberWarships = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive, homePosition, 400.0);
		
		if (numberTransportPlans <= numberWarships)
		{
			//dropoffLoc = getDropoffPoint(pickup, dropoffIslandLoc);
			transportPlanID = createTransportPlan(pickup, dropoffIslandLoc, 100);
			aiPlanAddUnitType(transportPlanID, cUnitTypeAbstractVillager, 1, migrantNumber, migrantNumber);
		}
		else // Make sure we have a dock
		{
			int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
			if (dockCount <= 0)
			{
				createSimpleBuildPlan(gDockUnit, 1, 100, false, cMilitaryEscrowID, gMainBase, 1);
			}
		}
	}
}

//==============================================================================
// selectClosestArchipelagoBuildPlanPosition
// Find the closest location to the unit to build.
//==============================================================================
void selectClosestArchipelagoBuildPlanPosition(int planID = -1, int baseID = -1)
{
	vector builderLocation = getRandomIsland();

	aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, builderLocation);
	aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, 100.0);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, 200.0);             // 200 points max
	aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff
}

//==============================================================================
// selectClosestArchipelagoMainIslandBuildPlanPosition
// Find the closest location to the unit to build.
//==============================================================================
void selectClosestArchipelagoMainIslandBuildPlanPosition(int planID = -1, int baseID = -1)
{
	aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, kbBaseGetLocation(cMyID, gMainBase));
	aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, 100.0);
	aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, 200.0);             // 200 points max
	aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff
}

//==============================================================================
// selectArchipelagoBuildPlanPosition
//==============================================================================
bool selectArchipelagoBuildPlanPosition(int planID = -1, int puid = -1, int baseID = -1)
{
   bool result = true;
   baseID = -1;

   // Position.
   switch (puid)
   {
      case cUnitTypeypShrineJapanese:
      case cUnitTypeypWJToshoguShrine2:
      case cUnitTypeypWJToshoguShrine3:
      case cUnitTypeypWJToshoguShrine4:
      case cUnitTypeypWJToshoguShrine5:
      {
         selectShrineBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeTorp:
      {
         selectTorpBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeHouseAfrican:
      case cUnitTypeHouse:
      case cUnitTypeypVillage:
      case cUnitTypeypHouseIndian:
      case cUnitTypeManor:
      case cUnitTypeHouseEast:
      case cUnitTypeHouseMed:
      case cUnitTypeLonghouse:
      case cUnitTypeHouseAztec:
      case cUnitTypedeHouseInca:
      {
         selectClosestArchipelagoBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypeOutpost:
      case cUnitTypeWarHut:
      case cUnitTypeNoblesHut:
      case cUnitTypedeIncaStronghold:
      case cUnitTypedeTower:
      case cUnitTypeBlockhouse:
      case cUnitTypeypCastle:
      case cUnitTypeYPOutpostAsian:
      {
         selectClosestArchipelagoBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypeDock:
      case cUnitTypeYPDockAsian:
      case cUnitTypedePort:
      case cUnitTypezpDrydock:    // AssertiveWall: Venitian special dock from age of pirates
      {
         // AssertiveWall: Get a new dock position for two minutes after the first one encunters danger
         vector newNavyVec = gNavyVec;
         if (gLastWSTime > xsGetTime())
         {  
            float mapSize = kbGetMapXSize() / 10.0;
            // 40 chances to pick a dock position other than the starting position
            for (j = 0; < 50)
            {  // picks random fish to build by. Radius grows as j increases
               newNavyVec = getRandomGaiaUnitPosition(cUnitTypeAbstractFish, getStartingLocation(), mapSize + j * 30.0); 
               if (newNavyVec == cInvalidVector && j > 40)
               {
                  newNavyVec = getRandomGaiaUnitPosition(cUnitTypeAbstractWhale, getStartingLocation(), mapSize + j * 30.0);
               }
               else if (newNavyVec == cInvalidVector)
               {
                  newNavyVec = gNavyVec;
               }
               else if (distance(newNavyVec, gNavyVec) > 50.0)
               {  // Keep the distance closer to gNavyVec, but vary which island it's built on
                  break;
               }
            }
         }

         aiPlanSetVariableVector(planID, cBuildPlanDockPlacementPoint, 0, getRandomIsland()); // One point at a random island
         aiPlanSetVariableVector(planID, cBuildPlanDockPlacementPoint, 1, newNavyVec); // Dock location Depends on naval baseID fed to it
         break;
      }
      case cUnitTypeBank:
      case cUnitTypeMarket:
      case cUnitTypeypTradeMarketAsian:
      case cUnitTypedeLivestockMarket:
      {
         if (gMigrationMap == true)
         {
            selectClosestArchipelagoBuildPlanPosition(planID, baseID);
            break;
         }
         // Usually we need to defend with Banks, thus placing Banks with high HP at front is a good choice.
         aiPlanSetVariableInt(planID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
         aiPlanSetBaseID(planID, baseID);
         break;
      }
      case cUnitTypeTownCenter:
      {
         selectClosestArchipelagoBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeFurTrade:
      {
         result = selectTribalMarketplaceBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeField:
      {
         // Returns false when we couldn't find a granary to build nearby, destroy the plan and wait for the granary
         // to be built.
         result = selectFieldBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeMountainMonastery:
      {
         selectMountainMonasteryBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypedeGranary:
      {
         selectGranaryBuildPlanPosition(planID, baseID);
         break;
      }
      case cUnitTypeFactory:
      case cUnitTypeypDojo:
      {
         aiPlanSetVariableInt(planID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceBack);
         // Base ID.
         aiPlanSetBaseID(planID, baseID);
         break;
      }
      default:
      {
		int numMilitaryBuildings = xsArrayGetSize(gMilitaryBuildings);
		for (i = 0; < numMilitaryBuildings)
		{
			if (puid != xsArrayGetInt(gMilitaryBuildings, i))
			{
				continue;
			}
			// This is a military building, randomize placement.
			aiPlanSetVariableInt(planID, cBuildPlanLocationPreference, 0, aiRandInt(4));
			selectClosestArchipelagoMainIslandBuildPlanPosition(planID, baseID);
			break;
		}

		selectClosestArchipelagoBuildPlanPosition(planID, baseID);
		//aiPlanSetBaseID(planID, baseID);
		break;
      }
   }

   return (result);
}