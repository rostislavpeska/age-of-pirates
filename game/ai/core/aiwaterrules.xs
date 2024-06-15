//==============================================================================
/* aiWaterRules.xs

   This file contains additional functions written by Assertive Wall

   These functions are all water specific, though other water rules still exist
   in aimilitary and aiassertivewall

*/
//==============================================================================

//==============================================================================
/* addWarshipsToPlan: 
   Looks for warships not currently occupied by another plan

   Goes through preferred type first
*/
//==============================================================================
bool addWarshipsToPlan(int planID = -1, int min = 1, int desired = 1, int pri = 10, int preferredType = -1) 
{
   // Add a boat
   int tempShip = -1;
   int puid = -1;
   int tempShipValue = -1;
   int countAdded = 0;

   if (preferredType > 0)
   {
      int preferredShipQuery = createSimpleUnitQuery(preferredType, cPlayerRelationSelf, cUnitStateAlive);
      int preferredShipNumber = kbUnitQueryExecute(preferredShipQuery);

      for (i = 0; < preferredShipNumber)
      {
         tempShip = kbUnitQueryGetResult(preferredShipQuery, i);
         puid = kbUnitGetProtoUnitID(tempShip);

         if (aiPlanGetActualPriority(kbUnitGetPlanID(tempShip)) >= pri)
         {
            continue;
         }

         if (aiPlanAddUnit(planID, tempShip) == false)
         {
            aiPlanDestroy(planID);
            return (false);
         }
         countAdded += 1;

         if (countAdded >= desired)
         {
            return (true);
         }
      }
   }

   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   int shipNumber = kbUnitQueryExecute(shipQuery);

   for (i = 0; < shipNumber)
   {
      tempShip = kbUnitQueryGetResult(shipQuery, i);
      puid = kbUnitGetProtoUnitID(tempShip);

      if (aiPlanGetActualPriority(kbUnitGetPlanID(tempShip)) >= pri)
      {
         continue;
      }

      if (aiPlanAddUnit(planID, tempShip) == false)
      {
         aiPlanDestroy(planID);
         return (false);
      }
      countAdded += 1;

      if (countAdded >= desired)
      {
         return (true);
      }
   }

   if (countAdded < min)
   {  // no ships, quit
      aiPlanDestroy(planID);
      return (false);
   }

   // Means we have more than the min, but not the desired
   return (true);
}

//==============================================================================
/* getCoastalPoint: 
   Give two points. It will go in that direction until it hits water, then drop
   back a couple steps

   Typically the landPoint will be the main base
*/
//==============================================================================
vector getCoastalPoint(vector landPoint = cInvalidVector, vector waterPoint = cInvalidVector, int stepsBack = 1, bool isWaterPoint = false)
{
	// Start at land point. Take small increments toward water point until we hit water, then use steps back or forward
   // depending on whether waterPoint is true or false
	vector testPoint = landPoint;
	int range = distance(landPoint, waterPoint);
	vector normalizedVector = xsVectorNormalize(waterPoint - landPoint);
	vector previousPoint = testPoint;
   vector nextPoint = cInvalidVector;
	int testAreaID = -1;

	for (i = 0; < range)
	{
		testPoint = testPoint + normalizedVector;
		testAreaID = kbAreaGetIDByPosition(testPoint);

		if (kbAreaGetType(testAreaID) == cAreaTypeWater)
		{
         if (isWaterPoint == true)
         {
            return (nextPoint);
         }
         else
         {
			   return (previousPoint);
         }
		}

		previousPoint = testPoint;
      nextPoint = testPoint;
		for (j = 0; < stepsBack)
		{
			previousPoint = previousPoint - normalizedVector; // Two steps back toward land
         nextPoint = nextPoint + normalizedVector; // Two steps toward water
		}
	}
	return cInvalidVector;
}



//==============================================================================
/* getFirstNavalTarget
   Goes straight toward the enemy, then flips around the island on 
   subsequent iterations
*/
//==============================================================================
vector getFirstNavalTarget(int iteration = 5)
{
   vector enemyPos = guessEnemyLocation();
   vector returnedVector = cInvalidVector;
   vector tempVec = cInvalidVector;
   vector myPos = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   static int leftRight = -1;
   int angleFloat = 0;

   if (leftRight < 0)
   {
      leftRight = aiRandInt(2);
   }

   if (iteration == 0)
   {
      returnedVector = getCoastalPoint(enemyPos, myPos, 10, true);
   }
   else if (iteration == 1)
   {
      if (leftRight == 1)
      {
         angleFloat = PI * 0.5;
      }
      else
      {
         angleFloat = 0.0 - PI * 0.5;
      }

      // Don't normalize this vector, keep it far away
      tempVec = myPos - enemyPos;
      // Depends on spread angle determined above
      tempVec = rotateByReferencePoint(enemyPos, tempVec, angleFloat);
      // Gets the point on the coast between these two
      returnedVector = getCoastalPoint(enemyPos, tempVec, 10, true);
   }
   else if (iteration == 2)
   {
      if (leftRight == 1)
      {
         angleFloat = 0.0 - PI * 0.5;
      }
      else
      {
         angleFloat = PI * 0.5;
      }

      // Don't normalize this vector, keep it far away
      tempVec = myPos - enemyPos;
      // Depends on spread angle determined above
      tempVec = rotateByReferencePoint(enemyPos, tempVec, angleFloat);
      // Gets the point on the coast between these two
      returnedVector = getCoastalPoint(enemyPos, tempVec, 10, true);
   }
   else
   {
      if (aiRandInt(2) == 1)
      {
         angleFloat = 0.0 - PI * 0.5;
      }
      else
      {
         angleFloat = PI * 0.5;
      }

      // Don't normalize this vector, keep it far away
      tempVec = myPos - enemyPos;
      // Depends on spread angle determined above
      tempVec = rotateByReferencePoint(enemyPos, tempVec, angleFloat);
      // Gets the point on the coast between these two
      returnedVector = getCoastalPoint(enemyPos, tempVec, 10, true);
   }

   return (returnedVector);
}

//==============================================================================
/* first naval assault

   Waits until we have enough warships to launch our first attack

*/
//==============================================================================

rule firstNavalAssault
inactive
minInterval 20
{
   // early out if plan is already going
   if (aiPlanGetActive(gFirstWaterAttack) == true)
   {
      return;
   }

   //aiPlanDestroy(gFirstWaterAttack);

   // Min number of ships based on disposition
   int minShips = 2;
   int maxIterations = 1;
   static int iteration = 0;

   if (gStrategy == cStrategyRush)
   {
      minShips = 1;
      maxIterations = 99;
      if (kbGetAge() >= cAge3)
      {  // stop in age 3
         maxIterations = 0;
      }
   }
   else if (gStrategy == cStrategyNakedFF || gStrategy == cStrategySafeFF)
   {
      minShips = 1;
      maxIterations = 3;
   }
   else if (gStrategy == cStrategyFastIndustrial || gStrategy == cStrategyGreed)
   {
      minShips = 3;
      maxIterations = 2;
   }

   if (iteration > maxIterations || kbGetAge() >= cAge3)
   {  // If we're past the number of times we want to do this, end this rule and enable water explore
      xsEnableRule("waterExplore");
      xsDisableSelf();
      return;
   }

   if (civIsNative() == true)
   {
      minShips += 2;
   }

   if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) < minShips)
   {  // Wait until we have enough ships
      return;
   }

   vector targetPosition = getFirstNavalTarget(iteration);

   gFirstWaterAttack = aiPlanCreate("First Water Raid: " + iteration, cPlanCombat);
   aiPlanSetDesiredPriority(gFirstWaterAttack, 60); // Important
   aiPlanAddUnitType(gFirstWaterAttack, cUnitTypeAbstractWarShip, minShips, minShips, minShips + kbGetAge());
      aiPlanSetNoMoreUnits(gFirstWaterAttack, true);
      if (addWarshipsToPlan(gFirstWaterAttack, minShips, minShips + kbGetAge(), 60) == false)
      {
         aiPlanDestroy(gFirstWaterAttack);
         gFirstWaterAttack = -1;
         return;
      }
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
   //aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanTargetPlayerID, 0, navalTargetPlayer);
   aiPlanSetVariableVector(gFirstWaterAttack, cCombatPlanTargetPoint, 0, targetPosition);
   aiPlanSetVariableVector(gFirstWaterAttack, cCombatPlanGatherPoint, 0, gNavyVec);
   aiPlanSetVariableFloat(gFirstWaterAttack, cCombatPlanGatherDistance, 0, 80.0); // Big gather radius
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);

   // AssertiveWall: Allow more units
   aiPlanSetVariableBool(gFirstWaterAttack, cCombatPlanAllowMoreUnitsDuringAttack, 0, true);
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanRefreshFrequency, 0, 700);

   // Done when we retreat, retreat when outnumbered, done when there's no target after 20 seconds
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeNoTarget);
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
   aiPlanSetVariableInt(gFirstWaterAttack, cCombatPlanNoTargetTimeout, 0, 20000);
   aiPlanSetBaseID(gFirstWaterAttack, kbUnitGetBaseID(getUnit(gDockUnit, cMyID, cUnitStateAlive)));
   aiPlanSetInitialPosition(gFirstWaterAttack, gNavyVec);

   aiPlanSetActive(gFirstWaterAttack);
   iteration += 1;
}


//==============================================================================
/* checkForClumpedShips: 
   Sometimes ships are too clumped around the transport. Tell everyone else to 
   move to a random point nearby

   transportShip2 can also be used, preventing it from controlling ship 2
*/
//==============================================================================
int checkForClumpedShips(int transportShip = -1, int transportShip2 = -1) 
{
   if (transportShip < 0 && transportShip2 < 0)
   {
      return (-1);
   }

   vector shipPosition = kbUnitGetPosition(transportShip);
   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive, shipPosition, 10.0);
   int shipNumber = kbUnitQueryExecute(shipQuery);
   int tempShip = -1;

   vector startingVec = shipPosition;
   startingVec = xsVectorSetX(startingVec, xsVectorGetX(startingVec) + 20);
   startingVec = rotateByReferencePoint(shipPosition, startingVec - shipPosition, aiRandInt(360) / (180.0 / PI));

   for (i = 0; < shipNumber)
   {
      if (tempShip != transportShip && tempShip != transportShip2)
      {
         tempShip = kbUnitQueryGetResult(shipQuery, i);
         aiTaskUnitMove(tempShip, startingVec);
      }
   }

   return (shipNumber);
}

//==============================================================================
/* AssertiveTransportRule
   I hate transports
*/
//==============================================================================
extern int gAssertiveTransportPlan = -1;
extern int gAssertiveTransportShip = -1;
extern vector gAssertivePickup = cInvalidVector;
extern vector gAssertiveDropoff = cInvalidVector;
extern int gAssertiveTransportStage = -1;
extern int gAssertiveTransportTime = -1;

extern const int cAssertiveTransportGather = 1;               
extern const int cAssertiveTransportLoad = 2;      
extern const int cAssertiveTransportMove = 3; 
extern const int cAssertiveTransportEnd = 4;       


bool confirmAssertivePickup(vector pickup = cInvalidVector) 
{
   if (pickup == cInvalidVector)
   {
      pickup = gAssertivePickup;
   }

   if (pickup == cInvalidVector)
   { // gAssertivePickup is bad
      return (false);
   }

   // check for buildings in immediate vicinity of pickup
   int buildingQ = createSimpleUnitQuery(cUnitTypeBuilding, cPlayerRelationAny, cUnitStateAlive, pickup, 5.0); 
   int buildingNum = kbUnitQueryExecute(buildingQ);
   if (buildingNum <= 0)
   {
      return(true);
   }

   // Add something to select new pickup nearby

   return (false);
}

int AssertiveTransportInitiate(vector pickup = cInvalidVector, vector dropoff = cInvalidVector, int pri = 100)
{
   if (gAssertiveTransportPlan >= 0)
   {
      // Can't do anything, quit
      return (-1);
   }

   // Fix pickup and dropoff
   pickup = getCoastalPoint(pickup, dropoff, 1, false);
   dropoff = getCoastalPoint(dropoff, pickup, 1, false);

   // Create the plan
   gAssertiveTransportPlan = aiPlanCreate("Assertive Transport Plan", cPlanReserve);
   aiPlanSetDesiredPriority(gAssertiveTransportPlan, pri); 

   // Add a boat
   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   int shipNumber = kbUnitQueryExecute(shipQuery);
   int tempShip = -1;
   int puid = -1;
   int tempShipValue = -1;
   int ship1 = -1;
   int ship1Value = -1;

   if (shipNumber <= 0)
   {  // no ships, quit
      aiPlanDestroy(gAssertiveTransportPlan);
      gAssertiveTransportPlan = -1;
      return (-1);
   }

   for (i = 0; < shipNumber)
   {
      tempShip = kbUnitQueryGetResult(shipQuery, i);
      puid = kbUnitGetProtoUnitID(tempShip);
      tempShipValue = kbUnitGetHealth(tempShip) * (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                     kbUnitCostPerResource(puid, cResourceInfluence));
      if (aiPlanGetActualPriority(kbUnitGetPlanID(tempShip)) > 22)
      {
         continue;
      }

      if (puid == gGalleonUnit)
      {
         tempShipValue = tempShipValue * 2;
      }
      else if (puid == gFrigateUnit)
      {
         tempShipValue = tempShipValue / 3;
      }

      if (tempShipValue > ship1Value)
      {
         ship1 = tempShip;
         ship1Value = tempShipValue;
      }
   }

   if (ship1 < 0)
   {
      // Couldn't find a ship
      aiPlanDestroy(gAssertiveTransportPlan);
      gAssertiveTransportPlan = -1;
      return (-1);
   }

   aiPlanAddUnitType(gAssertiveTransportPlan, cUnitTypeAbstractWarShip, 1, 1, 1);
   if (aiPlanAddUnit(gAssertiveTransportPlan, ship1) == false)
   {
      aiPlanDestroy(gAssertiveTransportPlan);
      gAssertiveTransportPlan = -1;
      return (-1);
   }

   aiPlanSetNoMoreUnits(gAssertiveTransportPlan, true);

   // Set the parameters and activate the rule to handle the transport
   aiPlanSetActive(gAssertiveTransportPlan);

   gAssertiveTransportShip = ship1;
   gAssertivePickup = pickup;
   gAssertiveDropoff = dropoff;
   gAssertiveTransportStage = cAssertiveTransportGather;
   gAssertiveTransportTime = xsGetTime();

   xsEnableRule("AssertiveTransportRule");
   return (gAssertiveTransportPlan);
}


rule AssertiveTransportRule
inactive
minInterval 5
{
   // Can only handle one transport (for now)

   // Check to make sure boat is alive
   if (kbUnitGetHealth(gAssertiveTransportShip) <= 0)
   {
      gAssertiveTransportStage = cAssertiveTransportEnd;
   }

   // Check if there are ships clumped up nearby
   if (xsGetTime() > gAssertiveTransportTime + 30 * 1000)
   {
      int clumpedShips = checkForClumpedShips(gAssertiveTransportShip);
   }

   // Confirm the pickup location is clear of buildings
   if (gAssertiveTransportStage <= cAssertiveTransportLoad)
   {
      confirmAssertivePickup();
   }

   int passengerNumber = aiPlanGetNumberUnits(gAssertiveTransportPlan, cUnitTypeLogicalTypeGarrisonInShips);
   int totalNumber = aiPlanGetNumberUnits(gAssertiveTransportPlan, cUnitTypeAll);
   int tempUnit = -1;
   int passengerQ = -1;
   int loadedNum = -1;
   int time = xsGetTime();

   //aiChat(1, "gAssertiveTransportStage: " + gAssertiveTransportStage);
   //sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, gAssertivePickup);
   //sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, gAssertiveDropoff);
   //sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, kbUnitGetPosition(gAssertiveTransportShip));
   
   switch (gAssertiveTransportStage)
	{
      // Gather Stage
		case cAssertiveTransportGather:
		{
         // Just tell everyone to move to the pickup
         if (distance(kbUnitGetPosition(gAssertiveTransportShip), gAssertivePickup) > 15)
         {
            aiTaskUnitMove(gAssertiveTransportShip, gAssertivePickup);
         }
         else
         {
            gAssertiveTransportStage = cAssertiveTransportLoad;
            gAssertiveTransportTime = time;
         }

         for (i = 0; < totalNumber)
         {
            tempUnit = aiPlanGetUnitByIndex(gAssertiveTransportPlan, i);
            if (kbUnitIsType(tempUnit, cUnitTypeLogicalTypeGarrisonInShips) == true)
            {
               if (distance(kbUnitGetPosition(tempUnit), gAssertivePickup) > 20)
               {
                  aiTaskUnitMove(tempUnit, gAssertivePickup);
               }
            }
         }
      }
      case cAssertiveTransportLoad:
		{
         // Tell everyone to board
         for (i = 0; < totalNumber)
         {
            tempUnit = aiPlanGetUnitByIndex(gAssertiveTransportPlan, i);
            if (kbUnitIsType(tempUnit, cUnitTypeLogicalTypeGarrisonInShips) == true)
            {
               aiTaskUnitWork(tempUnit, gAssertiveTransportShip);
            }
         }

         // Check how many are on board, go if it's been too long
         passengerQ = createSimpleUnitQuery(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationAny, cUnitStateAlive, kbUnitGetPosition(gAssertiveTransportShip), 1.0); 
         loadedNum = kbUnitQueryExecute(passengerQ);
         if (loadedNum == passengerNumber || (gAssertiveTransportTime > (45 * 1000 + gAssertiveTransportTime)))
         {
            gAssertiveTransportStage = cAssertiveTransportMove;
            aiTaskUnitMove(gAssertiveTransportShip, gAssertiveDropoff);
            gAssertiveTransportTime = time;
         }
      }
      case cAssertiveTransportMove:
		{
         // Check how many are on board
         passengerQ = createSimpleUnitQuery(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationAny, cUnitStateAlive, kbUnitGetPosition(gAssertiveTransportShip), 1.0); 
         loadedNum = kbUnitQueryExecute(passengerQ);
         if (loadedNum <= 0)
         {
            gAssertiveTransportStage = cAssertiveTransportEnd;
            gAssertiveTransportTime = xsGetTime();
         }

         // Check if our ship is on a coastal point to drop off. Check 8 points around the boat
         vector shipLoc = kbUnitGetPosition(gAssertiveTransportShip); // Start with base location
         vector testVec = shipLoc;
         testVec = xsVectorSetX(testVec, xsVectorGetX(testVec) + 4.0);
         int areaGroupID = kbAreaGroupGetIDByPosition(testVec);
         bool onCoast = false;
         for (j = 0; < 8)
         {
            testVec = rotateByReferencePoint(shipLoc, testVec - shipLoc, j * PI / 4.0);
            areaGroupID = kbAreaGroupGetIDByPosition(testVec);
            if (kbAreaGroupGetType(areaGroupID) != cAreaGroupTypeWater)
            {
               onCoast = true;
               break;
            }
         }

         if (onCoast == true || distance(shipLoc, gAssertiveDropoff) < 5.0)
         {
            aiTaskUnitEject(gAssertiveTransportShip);
         }
         else
         {
            aiTaskUnitMove(gAssertiveTransportShip, gAssertiveDropoff);
         }
      }
      case cAssertiveTransportEnd:
		{
         aiPlanDestroy(gAssertiveTransportPlan);
         gAssertiveTransportPlan = -1;
         gAssertiveTransportShip = -1;
         gAssertivePickup = cInvalidVector;
         gAssertiveDropoff = cInvalidVector;
         gAssertiveTransportStage = -1;
         gAssertiveTransportTime = -1;

         xsDisableSelf();
      }
   }
}

//==============================================================================
// getNavyStrength
// AssertiveWall: gets the navy value of the given player relation at the given 
//  location and radius
//==============================================================================

int getNavyStrength(int playerRelationVar = cPlayerRelationSelf, vector location = cInvalidVector, int radius = -1)
{
   // Navy Value
   int enNavyQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, playerRelationVar, cUnitStateAlive, location, radius);
   int enNavySize = kbUnitQueryExecute(enNavyQuery);
   int enNavyValue = 0;
   int unitID = -1;
   int puid = -1;

   for (i = 0; < enNavySize)
   {
      unitID = kbUnitQueryGetResult(enNavyQuery, i);
      puid = kbUnitGetProtoUnitID(unitID);
      enNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));
   }

   return (enNavyValue);
}

//==============================================================================
/* endlessWaterRaids
   AssertiveWall: creates a persistent plan to roam the map and look for
   things to attack

*/
//==============================================================================
rule endlessWaterRaids
inactive
minInterval 15
{
   vector targetPosition = cInvalidVector;
   int targetUnit = -1;
   int shipMin = 1;

   // First Run, or after plan gets destroyed
   if (getUnit(cUnitTypeAbstractWarShip, cMyCiv, cUnitStateAlive) <= 0)
   {
      return;
   }

   // Check to see if our plan has no ships. If not, make sure it's clear before continuing
   int numberWarships = aiPlanGetNumberUnits(gEndlessWaterRaidPlan, cUnitTypeAbstractWarShip);
   if (numberWarships <= 0)
   {  // Reset
      aiPlanDestroy(gEndlessWaterRaidPlan);
      gEndlessWaterRaidPlan = -1;
   }

   if (gEndlessWaterRaidPlan < 0)
   {
      // First find a random target
      targetPosition = getRandomGaiaUnitPosition(cUnitTypeAbstractWhale, getStartingLocation(), (0.5 * kbGetMapXSize()));
      if (targetPosition == cInvalidVector)
      {
         targetPosition = getRandomGaiaUnitPosition(cUnitTypeAbstractFish, getStartingLocation(), (0.5 * kbGetMapXSize()));
      }
      if (targetPosition == cInvalidVector)
      {  // There are no more locations, so turn off (very rare)
         xsDisableSelf();
      }

      // Determine minimum number of ships to send based on age
      if (kbGetAge() == cAge2)
      {
         shipMin = 1;
      }
      else
      {
         shipMin = 2;
      }

      gEndlessWaterRaidPlan = aiPlanCreate("Endless Water Raids", cPlanCombat);
      aiPlanSetDesiredPriority(gEndlessWaterRaidPlan, 21); // Not very important. Below exploring and nugget gathering
      aiPlanAddUnitType(gEndlessWaterRaidPlan, cUnitTypeAbstractWarShip, shipMin, 2, 3);
         aiPlanSetNoMoreUnits(gEndlessWaterRaidPlan, true);
         addWarshipsToPlan(gEndlessWaterRaidPlan, shipMin, 3, 21);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      //aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanTargetPlayerID, 0, navalTargetPlayer);
      aiPlanSetVariableVector(gEndlessWaterRaidPlan, cCombatPlanTargetPoint, 0, targetPosition);
      aiPlanSetVariableVector(gEndlessWaterRaidPlan, cCombatPlanGatherPoint, 0, gNavyVec);
      aiPlanSetVariableFloat(gEndlessWaterRaidPlan, cCombatPlanGatherDistance, 0, 80.0); // Big gather radius
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);



      // AssertiveWall: Never bring any extra boats on these. Balanced refresh frequency
      aiPlanSetVariableBool(gEndlessWaterRaidPlan, cCombatPlanAllowMoreUnitsDuringAttack, 0, true);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanRefreshFrequency, 0, 700);

      // Done when we retreat, retreat when outnumbered, done when there's no target after 20 seconds
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeNoTarget);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanNoTargetTimeout, 0, 20000);
      aiPlanSetBaseID(gEndlessWaterRaidPlan, kbUnitGetBaseID(getUnit(gDockUnit, cMyID, cUnitStateAlive)));
      aiPlanSetInitialPosition(gEndlessWaterRaidPlan, gNavyVec);

      aiPlanSetActive(gEndlessWaterRaidPlan);
   }
}

//==============================================================================
/* gatherNavalNuggets
   AssertiveWall: looks for water nuggets to gather

*/
//==============================================================================
rule gatherNavalNuggets
inactive
minInterval 10
{
   /*extern int gWaterNuggetPlan = -1;            // Persistent plan goes out to try and find water nuggets
   //extern const int cWaterNuggetSearch = -1;    // Units moving to the water nugget
   //extern const int cWaterNuggetAttack = 0;     // Units attacking the guardians 
   //extern const int cWaterNuggetGather = 1;     // Units gathering the nugget
   //extern int gWaterNuggetState = cWaterNuggetSearch;           // Stores the state of the water nugget plan
   //extern int gWaterNuggetTarget = -1;          // Stores the target of whatever the water nugget plan is doing
   */

   // First Run, or after plan gets destroyed
   if (gWaterNuggetPlan < 0)
   {
      int nuggetPlanID = aiPlanCreate("Nugget Raiding Plan", cPlanReserve);
      aiPlanSetDesiredPriority(nuggetPlanID, 21); // Higher than fishing and exploring. Fishing boats normally explore anyway

      if (civIsNative() == true)
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 3, 5);
         aiPlanSetNoMoreUnits(gWaterNuggetPlan, true);
         addWarshipsToPlan(gWaterNuggetPlan, 1, 5, 21);
      }
      else
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 2, 3);
         aiPlanSetNoMoreUnits(gWaterNuggetPlan, true);
         addWarshipsToPlan(gWaterNuggetPlan, 1, 3, 21);
      }
      aiPlanSetActive(nuggetPlanID);
      gWaterNuggetPlan = nuggetPlanID;
   }

   if (xsGetTime() > gWaterNuggetTimeout + 30*1000)
   {  // Reset
      gWaterNuggetState = cWaterNuggetSearch;
      gWaterNuggetTimeout = xsGetTime();
      return;
   }

   int numberExplorerWarships = aiPlanGetNumberUnits(gWaterNuggetPlan, cUnitTypeAbstractWarShip);
   // See if we have idle ships to add
   int idleWarshipQuery = createSimpleIdleUnitQuery(cUnitTypeAbstractWarShip, cMyID, cUnitStateAlive);
   int numberIdleWSFound = kbUnitQueryExecute(idleWarshipQuery);

   if (numberExplorerWarships < 3 && numberIdleWSFound > 0)
   {
      if (civIsNative() == true)
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 3, 5);
         aiPlanSetNoMoreUnits(gWaterNuggetPlan, true);
         addWarshipsToPlan(gWaterNuggetPlan, 1, 5, 21);
      }
      else
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 2, 3);
         aiPlanSetNoMoreUnits(gWaterNuggetPlan, true);
         addWarshipsToPlan(gWaterNuggetPlan, 1, 3, 21);
      }
   }

   if (numberExplorerWarships <= 0)
   {  // Reset
      gWaterNuggetState = cWaterNuggetSearch;
      return;
   }

   int nuggetID = -1;
   int guardianQuery = -1;
   int guardianID = -1;
   int guardianNumber = -1;
   int guardianHealth = 0;
   vector waterNuggetLocation = cInvalidVector;
   int bestNugget = -1;
   int bestGuardianHP = 10000;
   int bestGuardianID = -1;
   vector targetLocation = cInvalidVector;
   numberExplorerWarships = aiPlanGetNumberUnits(gWaterNuggetPlan, cUnitTypeAbstractWarShip);

   switch (gWaterNuggetState)
   {
      case cWaterNuggetSearch:
      {  
         xsSetRuleMinIntervalSelf(15);
         int explorerUnit = aiPlanGetUnitByIndex(gWaterNuggetPlan, 0);
         vector explorerLoc = kbUnitGetPosition(explorerUnit);
         int indexedExplorerUnit = -1;
         int explorerFleetHP = 0;

         // Looks for a suitable nugget and tells the ships to attack it
         aiPlanSetDesiredPriority(gWaterNuggetPlan, 21);
         for (i = 0; < numberExplorerWarships)
         {  // Only consider units that are close together
            indexedExplorerUnit = aiPlanGetUnitByIndex(gWaterNuggetPlan, i);
            if (distance(kbUnitGetPosition(indexedExplorerUnit), explorerLoc) < 75)
            {
               explorerFleetHP = explorerFleetHP + kbUnitGetCurrentHitpoints(indexedExplorerUnit);
            }
         }

         // Store enemy location so we can avoid it
         vector guessedEnemyLocation = guessEnemyLocation();

         // Find a suitable water nugget. Only check 5 random locations. (decrease if AI is too good at spotting treasures)
         for (j = 0; < 5)
         {
            waterNuggetLocation = getRandomGaiaUnitPosition(cUnitTypeAbstractNuggetWater, explorerLoc, 0.3*kbGetMapXSize());
            nuggetID = getUnitByLocation(cUnitTypeAbstractNuggetWater, cPlayerRelationAny, cUnitStateAlive, waterNuggetLocation, 4.0);

            // Check to make sure nugget is on water
            int testAreaID = kbAreaGetIDByPosition(waterNuggetLocation);
            if (kbAreaGetType(testAreaID) != cAreaTypeWater)
            {
               continue;
            }

            // skip if nugget is too close to enemy
            if (distance(waterNuggetLocation, guessedEnemyLocation) < 150)
            {
               continue;
            }

            guardianHealth = 0;
            guardianQuery = createSimpleUnitQuery(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, waterNuggetLocation, 10.0);
            guardianNumber = kbUnitQueryExecute(guardianQuery);

            // Get total health of water guardians
            if (guardianNumber > 0)
            {
               for (k = 0; < guardianNumber)
               {
                  guardianID = kbUnitQueryGetResult(guardianQuery, k);
                  guardianHealth = guardianHealth + kbUnitGetCurrentHitpoints(guardianID);
               }
            }
            // Discourage further treasures
            guardianHealth = guardianHealth + 0.7 * distance(waterNuggetLocation, explorerLoc);

            if (guardianHealth < bestGuardianHP)
            {
               bestNugget = nuggetID; // Store this as the best nugget
               bestGuardianHP = guardianHealth;
               bestGuardianID = guardianID;
            }
         }

         // Don't bother unless there's a good chance of winning
         if (explorerFleetHP < 1.5 * bestGuardianHP)
         {
            return;
         }
      
         // Now tell the ships to attack it
         if (bestNugget > 0)
         { 
            gWaterNuggetTarget = bestNugget;
            gWaterNuggetTargetLoc = kbUnitGetPosition(bestNugget);
            gWaterNuggetTimeout = xsGetTime();
            xsSetRuleMinIntervalSelf(3);
            if (bestGuardianID > 0)
            {  // There are guardians, so attack
               for (m = 0; < numberExplorerWarships)
               {
                  aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, m), bestGuardianID);
               }
               gWaterNuggetState = cWaterNuggetAttack;
               aiPlanSetDesiredPriority(gWaterNuggetPlan, 55); // We're in it now
            }
            else
            {  // No guardians, so go straight to nugget
               for (n = 0; < numberExplorerWarships)
               {
                  aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, n), bestNugget);
               }
               gWaterNuggetState = cWaterNuggetGather;
               aiPlanSetDesiredPriority(gWaterNuggetPlan, 90); // We're in it now
            }
         }
         break;
      }

      case cWaterNuggetAttack:
      {
         // Keep checking our nugget until all guardians are destroyed. If our fleet is gone, reset
         guardianNumber = getUnitCountByLocation(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 10.0);
         int currentGuardianID = getUnitByLocation(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 10.0);

         if (guardianNumber <= 0)
         {
            gWaterNuggetState = cWaterNuggetGather;
            gWaterNuggetTarget = getUnitByLocation(cUnitTypeAbstractNuggetWater, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 4.0);
            aiPlanSetDesiredPriority(gWaterNuggetPlan, 90);
            for (s = 0; < numberExplorerWarships)
            {
               aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, s), gWaterNuggetTarget);
            }
         }
         else
         {
            for (p = 0; < numberExplorerWarships)
            {
               aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, p), currentGuardianID);
            }
         }
         break;
      }

      case cWaterNuggetGather:
      {
         // Keep checking our nugget until it's gone
         // Ships are already tasked to gather nugget. Just wait until nugget is gone 
         int nuggetsAtLoc = getUnitCountByLocation(cUnitTypeAbstractNuggetWater, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 2.0);
         if (nuggetsAtLoc > 0)
         {
            for (n = 0; < numberExplorerWarships)
            {
               aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, n), gWaterNuggetTarget);
            }
         } 
         else
         {
            gWaterNuggetState = cWaterNuggetSearch;
            aiPlanSetDesiredPriority(gWaterNuggetPlan, 21);
         }
         break;
      }
   }
}