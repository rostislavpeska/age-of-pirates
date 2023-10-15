//==============================================================================
/* aiAssertiveWall.xs

   This file contains additional functions written by Assertive Wall

*/
//==============================================================================

//==============================================================================
// Custom Array functions.
// All from Better AI
//==============================================================================
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
minInterval 15
{
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

		if (kbUnitGetPlanID(unitID) >= 0)
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
	updateFoodBreakdown();

	// Search for wood.
	updateWoodBreakdown();

	// Search for gold.
	updateGoldBreakdown();

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
				if (kbUnitGetPlanID(unitID) >= 0)
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
					aiTaskUnitWork(unitID, foodID, true);

					// Update the number of workers on the food unit.
					arraySetInt(gFoodNumWorkers, foodIndex, (arrayGetInt(gFoodNumWorkers, foodIndex) + 1));
				}
				else
				{
					aiTaskUnitWork(unitID, foodID);

					// Update the number of workers on the food unit.
					arraySetInt(gDecayingNumWorkers, foodIndex, (arrayGetInt(gDecayingNumWorkers, foodIndex) + 1));
				}
				numFoodVills = numFoodVills - pop;
			}
			else // Gold is closer than Food.
			{
            resourcePicked = 2;
				aiTaskUnitWork(unitID, goldID);
				// Update the number of workers on the gold unit.
				arraySetInt(gGoldNumWorkers, goldIndex, (arrayGetInt(gGoldNumWorkers, goldIndex) + 1));
				numGoldVills = numGoldVills - pop;
			}
		}
		else if (woodDistance < goldDistance) // Wood is closer than both Food and Gold.
		{
         resourcePicked = 3;
			numWoodVills = numWoodVills - pop;
			aiTaskUnitWork(unitID, woodID);
			// Help vills that sometimes get stuck.
			aiTaskUnitMove(unitID, kbUnitGetPosition(woodID) + gDirection_UP, true);

			// Update the number of workers on the wood unit.
			arraySetInt(gWoodNumWorkers, woodIndex, (arrayGetInt(gWoodNumWorkers, woodIndex) + 1));
		}
		else // Gold is closer than both Food and Wood.
		{
         resourcePicked = 2;
			numGoldVills = numGoldVills - pop;
			aiTaskUnitWork(unitID, goldID);

			// Update the number of workers on the gold unit.
			arraySetInt(gGoldNumWorkers, goldIndex, (arrayGetInt(gGoldNumWorkers, goldIndex) + 1));
		}

      // Get the location of what we picked, and set it to 
      if (resourcePicked == 1)
      {
         resourceLocation = kbUnitGetPosition(foodID);
      }
      else if (resourcePicked == 2)
      {
         resourceLocation = kbUnitGetPosition(goldID);
      }
      else if (resourcePicked == 3)
      {
         resourceLocation = kbUnitGetPosition(woodID);
      }
      // Check to see if it needs transport
      if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(location), kbAreaGroupGetIDByPosition(resourceLocation)) == false)
      {
         migrantNumber += 1;

         /*int transportPlan = createTransportPlan(location, resourceLocation, 100);
         if (transportPlan < 0)
         {
            aiChat(1, "failed to pick a transport");
            continue;
         }
         aiPlanAddUnitType(transportPlan, gEconUnit, 1, 1, 1);
         aiPlanAddUnit(transportPlan, unitID);
         sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, location);
         return;*/
      }
	}
   if (migrantNumber > 0)
   {
      vector dropoffLoc = getRandomIsland();
      int transportPlanID = createTransportPlan(kbGetPlayerStartingPosition(cMyID), dropoffLoc, 100);
      aiPlanAddUnitType(transportPlanID, gEconUnit, migrantNumber, migrantNumber, migrantNumber);
      aiChat(1, "transport plan ID: " + transportPlanID);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbGetPlayerStartingPosition(cMyID));
   }
}
