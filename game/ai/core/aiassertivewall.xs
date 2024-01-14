//==============================================================================
/* aiAssertiveWall.xs

   This file contains additional functions written by Assertive Wall

*/
//==============================================================================


//==============================================================================
/* attackRetreatCheck
   AssertiveWall: Goes through the attack plans and decides when to retreat 
   Also tells attack plans to attack armies if they run into one
*/
//==============================================================================
rule attackRetreatCheck
inactive
minInterval 2
{
   // Find an active attack plan
   int numPlans = aiPlanGetActiveCount();
   int existingPlanID = -1;
   int attackPlanID = -1;
   int attackScout1 = -1;
   int attackScout2 = -1;
   int attackSize = -1;
   int randInt = -1;
   int nearbyEnemyCount1 = 0;
   int nearbyEnemyCount2 = 0;
   vector scout1Loc = cInvalidVector;
   vector scout2Loc = cInvalidVector;
   int tempUnit = -1;
   int tempEnemy = -1;

   
   for (int i = 0; i < numPlans; i++)
   {
      existingPlanID = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(existingPlanID) != cPlanCombat)
      {
         continue;
      }
      if (aiPlanGetVariableInt(existingPlanID, cCombatPlanCombatType, 0) == cCombatPlanCombatTypeDefend)
      {
         if ((existingPlanID != gExplorerControlPlan) &&
             (existingPlanID != gLandDefendPlan0) && 
             (existingPlanID != gLandReservePlan) && 
             (existingPlanID != gHealerPlan) && 
             (existingPlanID != gNavyRepairPlan) && 
             (existingPlanID != gNavyDefendPlan) &&
             (existingPlanID != gNavyAttackPlan) &&
             (existingPlanID != gCoastalGunPlan) &&
             (existingPlanID != gEndlessWaterRaidPlan)) // AssertiveWall: Don't stop if there's navy attack plans
         {
            debugUtilities("isDefendingOrAttacking: don't create another combat plan because we already have one named: "
               + aiPlanGetName(existingPlanID));
            continue;
         }
      }
      else // Attack plan.
      {
         if ((aiPlanGetParentID(existingPlanID) < 0) && // No parent so not a reinforcing child plan.
             (existingPlanID != gNavyAttackPlan && existingPlanID != gCoastalGunPlan && existingPlanID != gEndlessWaterRaidPlan))
         {
            debugUtilities("isDefendingOrAttacking: don't create another combat plan because we already have one named: "
               + aiPlanGetName(existingPlanID));
            attackPlanID = existingPlanID;
            break;
         }
      }
   }

   // Return if there's no attack plan and set a long interval
   if (attackPlanID < 0)
   {
      xsSetRuleMinIntervalSelf(15);
      return;
   }
   else
   {
      xsSetRuleMinIntervalSelf(2);
   }

   // Get the "scouts" i.e. 2 random units in the attack
   attackSize = aiPlanGetNumberUnits(attackPlanID, cUnitTypeLogicalTypeLandMilitary);
   randInt = aiRandInt(attackSize - 1);
   attackScout1 = aiPlanGetUnitByIndex(attackPlanID, randInt);
   attackScout2 = aiPlanGetUnitByIndex(attackPlanID, randInt + 1);
   scout1Loc = kbUnitGetPosition(attackScout1);
   scout2Loc = kbUnitGetPosition(attackScout2);


   // Find enemies near Scout1
   nearbyEnemyCount1 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, scout1Loc, 25.0);
   nearbyEnemyCount2 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, scout2Loc, 25.0);

   // Ignore single scout
   if (nearbyEnemyCount1 + nearbyEnemyCount2 > 2)
   {
      aiChat(1, "Attacking nearby Enemy en route");
      sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, scout1Loc);
      for (i = 0; < attackSize)
      {
         tempUnit = aiPlanGetUnitByIndex(attackPlanID, i);
         tempEnemy = getUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, kbUnitGetPosition(tempUnit), 25.0);
         aiTaskUnitWork(tempUnit, tempEnemy);
      }
   }



}


//==============================================================================
/* aiCheckAttackFailure
   AssertiveWall: This function checks to see if the current attack plan is 
   doing anything and resets it if it seems to have failed (like if the 
   transport plan failed to transport)

   Just a simple timeout for now

   True means the attack is failing
*/
//==============================================================================
/*bool aiCheckAttackFailure()
{
   bool planStatus = isDefendingOrAttacking();
   //vector mainBaseLocation = kbBaseGetLocation(cMyID, mainBaseID);
   int currentTime = xsGetTime();
   int timeCheck = gLastAttackMissionTime + gAttackMissionInterval;

   if (planStatus == true && currentTime > timeCheck)
   {
      aiPlanSetVariableInt(gLandAttackPlanID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | aiPlanGetVariableInt(gLandAttackPlanID, cCombatPlanDoneMode, 0));
      aiPlanSetVariableInt(gLandAttackPlanID, cCombatPlanNoTargetTimeout, 0, 30000);
      gLastAttackMissionTime = gLastAttackMissionTime + 15 * 1000; // Give it 15 seconds before resetting again
      return true;
   }
   return false;
}*/

//==============================================================================
/* Gets the closest enemy player to you
*/
//==============================================================================
/*vector nearestEnemyStartingLocation(vector location = cInvalidVector)
{
   vector testLoc = cInvalidVector;
   vector enemyLoc = cInvalidVector;
   int dist = 9999;
   for (i = 1; < cNumberPlayers)
   {
      testDist = distance(location, enemyLocation);
      testLoc = kbGetPlayerStartingPosition(cMyID);
      getEnemyPlayerByTeamPosition
      if (testDist < dist)
      {
         dist = testDist;
         enemyLoc = testLoc;
      }
   }
   return enemyLoc;
}*/

//==============================================================================
/* scaleDifficulty
   AssertiveWall: adjusts the AI performance based on how well a player performs
   Probably causes desync issues

   Not in Use
*/
//==============================================================================
rule scaleDifficulty
inactive
minInterval 60
{
   int friendlyTeamScore = 0;
   int friendlyTeamSize = 0;
   int enemyTeamScore = 0;
   int enemyTeamSize = 0;
   int myTeam = kbGetPlayerTeam(cMyID);
   float modifier = 1.25; // 25% 
   float handicapAdjustment = 0.02; // 2%
   float newHandicap = -1;

   if (gStartingHandicap < 0)
   {
      gStartingHandicap = kbGetPlayerHandicap(cMyID); 
   }

   // Add up the scores of each team
   for (player = 1; < cNumberPlayers)
   {
      if (kbGetPlayerTeam(player) == myTeam)
      {
         friendlyTeamScore += aiGetScore(player);
         friendlyTeamSize += 1;
      }
      else
      {
         enemyTeamScore += aiGetScore(player);
         enemyTeamSize += 1;
      }
   }
   // Normalize the scores for the team size (i.e. get the average score for the team)
   // This prevents too much scaling in FFA or lopsided team games
   friendlyTeamScore = friendlyTeamScore / friendlyTeamSize;
   enemyTeamScore = enemyTeamScore / enemyTeamSize;

   if (friendlyTeamScore > enemyTeamScore * modifier)
   {
      newHandicap = kbGetPlayerHandicap(cMyID) * (1.0 - handicapAdjustment);
      aiChat(1, "Decreasing the AI handicap to " + newHandicap);
   }
   else if (friendlyTeamScore * modifier < enemyTeamScore)
   {
      newHandicap = kbGetPlayerHandicap(cMyID) * (1.0 + handicapAdjustment);
      aiChat(1, "Increasing the AI handicap to " + newHandicap);
   }
   else
   {
      return;
   }

   // Create upper and lower bounds of 10% of the initial handicap
   if (newHandicap > gStartingHandicap * 1.12 || newHandicap < gStartingHandicap * 0.88)
   {
      aiChat(1, "Blocked new handicap of: " + newHandicap + ". Starting handicap was: " + gStartingHandicap);
      return;
   }

   kbSetPlayerHandicap(cMyID, newHandicap);
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
      aiPlanAddUnitType(gEndlessWaterRaidPlan, cUnitTypeAbstractWarShip, shipMin, 2, 3);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      //aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanTargetPlayerID, 0, navalTargetPlayer);
      aiPlanSetVariableVector(gEndlessWaterRaidPlan, cCombatPlanTargetPoint, 0, targetPosition);
      aiPlanSetVariableVector(gEndlessWaterRaidPlan, cCombatPlanGatherPoint, 0, gNavyVec);
      aiPlanSetVariableFloat(gEndlessWaterRaidPlan, cCombatPlanGatherDistance, 0, 80.0); // Big gather radius
      aiPlanSetVariableInt(gEndlessWaterRaidPlan, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);
      aiPlanSetDesiredPriority(gEndlessWaterRaidPlan, 21); // Not very important. Below exploring and nugget gathering


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
      if (civIsNative() == true)
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 3, 5);
      }
      else
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 2, 3);
      }
      aiPlanSetDesiredPriority(nuggetPlanID, 21); // Higher than fishing and exploring. Fishing boats normally explore anyway
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
      }
      else
      {
         aiPlanAddUnitType(gWaterNuggetPlan, cUnitTypeAbstractWarShip, 1, 2, 3);
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

//==============================================================================
/* getRandomIslandBase
   AssertiveWall: This function gives you a random island base
   * not in use *
*/
//==============================================================================
int getRandomIslandBase(int numberIslands = -1)
{
   if (gMigrationMap == true)
   {
      return gIslandAID;
   }

   int islandSelector = aiRandInt(numberIslands);
   int returnedIsland = -1;
   if (islandSelector == 1)
   {
      returnedIsland = gIslandAID;
   }
   if (islandSelector == 2)
   {
      returnedIsland = gIslandBID;
   }
   return returnedIsland;
}



//==============================================================================
/* getIslandCount
   AssertiveWall: Returns how many islands we have settled
   ** not in use **
*/
//==============================================================================

int getIslandCount()
{  
   int islandCount = 1; // Starts at 1 for main base
   if (gIslandAID > 0)
   {
      islandCount += 1;
   }
   if (gIslandBID > 0)
   {
      islandCount += 1;
   }

   return islandCount;
}


//==============================================================================
/* isIslandNeeded
   AssertiveWall: Checks if this is a good time to occupy another island
   ** not in use **
*/
//==============================================================================

bool isIslandNeeded()
{  
   //if (gMigrationMap == true)
   //{
      if(getIslandCount() >= 2)
      {
         return false;
      }
      else
      {
         return true;
      }
   //}
   //if (gTimeToFarm == false && gTimeForPlantations == false)
   //{
   //   return true;
   //}
   
   return false;
}


//==============================================================================
/* villagerFerry
   AssertiveWall: This function grabs idle villagers and transports them to the 
   desired base and adds them to that base
   
   Pickup and dropoff is a baseID, not a location
   * not in use* 
   See catchMigrants
*/
//==============================================================================

void villagerFerry(int pickup = -1, int dropoff = -1, int villagerNumber = -1)
{
   //bool islandNeeded = isIslandNeeded();
   //int totalIslands = getIslandCount();
   int unitQueryID = -1;
   int unitID = -1;
   vector pickupLocation = kbBaseGetLocation(cMyID, pickup);
   vector dropoffLocation = kbBaseGetLocation(cMyID, dropoff);

   // Transport villagers to the new island and assign them to the base
   int transportPlanID = createTransportPlan(pickupLocation, dropoffLocation, 100, true);
   //aiPlanAddUnitType(transportPlanID, cUnitTypeAbstractVillager, 0, 0, 0); // Add individual villagers later

   //if (transportPlanID < 0)
   //{
   //   return;
   //}

   // bring wagons too
   //int nwFound = kbUnitCount(cMyID, cUnitTypeAbstractWagon, cUnitStateAlive);
   //aiPlanAddUnitType(transportPlanID, cUnitTypeAbstractWagon, nwFound, nwFound, nwFound);

   // Create a gather plan for everyone going to the new island
   int islandGatherPlanID = aiPlanCreate("Island Gather Plan", cPlanGather);
   aiPlanSetBaseID(islandGatherPlanID, dropoff);
   aiPlanSetVariableInt(islandGatherPlanID, cGatherPlanResourceType, 0, cAllResources);
   aiPlanAddUnitType(islandGatherPlanID, gEconUnit, 0, 200, 200);
   aiPlanSetDesiredPriority(islandGatherPlanID, 50);
   aiPlanSetActive(islandGatherPlanID);
   aiPlanSetNoMoreUnits(islandGatherPlanID, true);  // Manually add units to this plan

   // Goes through the idle villagers and adds them to the trasport plan and new base
   unitQueryID = createSimpleIdleUnitQuery(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, pickupLocation, 50.0);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(unitQueryID, i);
      if (aiPlanAddUnit(transportPlanID, unitID) == false)
      {
         //continue;
         aiPlanDestroy(transportPlanID);
         dropoffLocation = kbBaseGetLocation(cMyID, gMainBase);
         //return;
      }
      aiPlanAddUnit(transportPlanID, unitID);
      aiPlanAddUnit(islandGatherPlanID, unitID);
      kbBaseAddUnit(cMyID, dropoff, unitID);
   }



   aiPlanSetNoMoreUnits(transportPlanID, true);
   //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, dropoffLocation);

   return;
}


//==============================================================================
/* getRandomIsland
   AssertiveWall: Searches through tiles around your island and gives a location 
   of the closest island that's not another player's starting island
   In use by archipelago build placement
*/
//==============================================================================

vector getRandomIsland()
{
   vector startingLoc = kbGetPlayerStartingPosition(cMyID);
   int startingAreaID = kbAreaGetIDByPosition(startingLoc);
   vector testLoc = cInvalidVector;
   int testAreaID = -1;
   float j = 0.0;
   float k = 0.0;
   int m = 0;
   int occupiedFriendly = 0;
   int occupiedEnemy = 0;


   for (i = 0; < 200)
   {
      testLoc = startingLoc;
      // Get a random vector near our base
      if (i < 100)
      {
         m = i;
      }
      else
      {
         m = i - 100;
      }
      j = m * kbGetMapXSize() / 150.0; // Normalized for RM map area
      k = m * kbGetMapZSize() / 150.0;
      testLoc = xsVectorSet(xsVectorGetX(testLoc) + aiRandFloat(0.0 - j, j), 0.0, 
                xsVectorGetZ(testLoc) + aiRandFloat(0.0 - k, k));
      
      testAreaID = kbAreaGetIDByPosition(testLoc);

      // Check how occupied it is. 
      occupiedFriendly = getUnitCountByLocation(cUnitTypeBuilding, cPlayerRelationAlly, cUnitStateAlive, testLoc, 50.0);
      occupiedEnemy = getUnitCountByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive, testLoc, 50.0);
      
      if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(testLoc), kbAreaGroupGetIDByPosition(startingLoc)) == false
            && kbAreaGetType(kbAreaGetIDByPosition(testLoc)) != cAreaTypeWater)
      {      
         // Past 100, take whatever we can get that isn't home base
         if (i > 100)
         {
            return testLoc;
         }

         // If it isn't occupied by anyone, try and take it
         if (occupiedFriendly <= 0 && occupiedEnemy <= 0)
         {
            return testLoc;
         }
      }
   }
   // Prefer to return something valid if no islands can be found
   return startingLoc;
}

//==============================================================================
/* createNewIslandBase
   AssertiveWall: creates a new base at the provided location

   Note: Need to make the base on the near side of the island, not the center

   ** not in use **

*/
//==============================================================================
int createNewIslandBase(vector newIsland = cInvalidVector, int totalIslands = -1)
{
   if (totalIslands == 1)
   {
      //gIslandAState = cIslandAStateNone;
      gIslandALocation = newIsland; 
      gIslandAID = kbBaseCreate(cMyID, "Island A base", gIslandALocation, 150.0);
      kbBaseSetMaximumResourceDistance(cMyID, gIslandAID, 150.0);
      //gIslandABuildPlan = -1;
      return gIslandAID;
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, gIslandALocation);
   }
   else if (totalIslands == 2)
   {
      //gIslandBState = cIslandAStateNone;
      gIslandBLocation = newIsland; 
      gIslandBID = kbBaseCreate(cMyID, "Island B base", gIslandBLocation, 150.0);
      kbBaseSetMaximumResourceDistance(cMyID, gIslandBID, 150.0);
      //gIslandBBuildPlan = -1;
      return gIslandBID;
   }
   return -1;
}

//==============================================================================
/* islandBuildSelector
   AssertiveWall: This rule monitors our settled islands and sets gMainBaseID
   to one that makes sense
   ** not in use **
*/
//==============================================================================
rule islandBuildSelector
inactive
minInterval 30
{
   // Let us switch/check every 2 minutes
   if (xsGetTime() < gLastIslandSwitchTime + 2 * 60 * 1000)
   {
      return;
   }

   // On Ceylon make one base on the main island and that's it
   if (gMigrationMap == true)
   {
      if (gIslandAID > 0)
      {
         gMainBase = gIslandAID;
         kbBaseSetMain(cMyID, gMainBase, true);
         xsDisableSelf();
      }
   }
   
   int totalIslands = getIslandCount();
   //int idleVillagers = getNumberIdleVillagers();
   int islandSelector = aiRandInt(totalIslands);
   int buildingBase = -1;

   if (islandSelector == 1)
   {
      buildingBase = gOriginalBase;
   }
   if (islandSelector == 2)
   {
      buildingBase = gIslandAID;
   }
   if (islandSelector == 3)
   {
      buildingBase = gIslandBID;
   }

   gMainBase = buildingBase;
   gLastIslandSwitchTime = xsGetTime();
}

//==============================================================================
/* islandHopper
   AssertiveWall: This rule monitors new island building and calls villager transports
   ** not in use **
*/
//==============================================================================
rule islandHopper
inactive
minInterval 5 // down from 20
{
   // Make sure there are no active transport plans
   if (aiPlanGetIDByIndex(cPlanTransport, -1, true, 0) >= 0)
   {
      return;
   }

   bool islandNeeded = isIslandNeeded();
   int totalIslands = getIslandCount();
   int idleVillagers = getNumberIdleVillagers();
   int shipUnitQueryID = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cMyID, cUnitStateAlive);
   int shipCount = kbUnitQueryExecute(shipUnitQueryID);
   int dropoff = -1;
   vector newIsland = cInvalidVector;

   // Nothing to do if we don't have any idle villagers or ships
   if (idleVillagers <= 0 || shipCount <=0)
   {
      return;
   }

   if (islandNeeded == true)
   {
      // Check for a new island. If we find one then set the dropoff to the new one
      newIsland = getRandomIsland();
      // Testing purposes
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, newIsland); 

      if (newIsland != cInvalidVector)
      {
         dropoff = createNewIslandBase(newIsland, totalIslands);
         totalIslands = getIslandCount();
      }
   }

   // If we aren't making a new island, check if we have any islands to transport to
   if (totalIslands <= 1)
   {
      return;
   }

   // If we made it this far, we have multiple islands, some idle villagers, and a ship to 
   // transport them but if we have no new base select a random existing one
   if (islandNeeded == false)
   {
      dropoff = getRandomIslandBase(totalIslands);
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(dropoff)); 
   }

   villagerFerry(gOriginalBase, dropoff, idleVillagers);

}


//==============================================================================
/* delayWalls
   AssertiveWall: Original wall building AI the rest are based on. 
   
   Don't use this one
   ** not in use **
*/
//==============================================================================

rule delayWalls
inactive
minInterval 10
{
   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   if (gStartOnDifferentIslands == true && dockCount < 1)
   {
      return; // AssertiveWall: Need a dock on island maps to wall around
   }
   
   int wallPlanID = aiPlanCreate("WallInBase", cPlanBuildWall);
   float wallRadius = 30.0; // AssertiveWall: used to set wall ring size
   int gateNumber = 2;      // AssertiveWall: sets number of gates
   int mapWidth = kbGetMapXSize();
   vector wallCenter = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));

   if (gStartOnDifferentIslands == true)
   {
      wallCenter = kbUnitGetPosition(getUnit(gDockUnit));
      wallRadius = 30.0;
      //wallRadius = mapWidth / 5.0; // Giant so it becomes a seawall
      gateNumber = 3;
   }

   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsDisableSelf();
}


//==============================================================================
/* dockWallOne - dockWallThree
   AssertiveWall: build a wall around a random dock. Some docks will get double, 
   which is ok
*/
//==============================================================================

rule dockWallOne
inactive
minInterval 10
{
   if (btRushBoom > 0.45)
   {  // No walls for rushing civs
      xsDisableSelf();
      return;
   }

   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   if (gStartOnDifferentIslands == true && (dockCount < 1 || dockCount > 2))
   {
      return; // AssertiveWall: Need a dock, but not too many. If docks get destroyed we can start building again
   }
   
   int wallPlanID = aiPlanCreate("WallOneDock", cPlanBuildWall);
   float wallRadius = aiRandFloat(20.0, 30.0); // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(2) + 3;      // AssertiveWall: sets number of gates
   vector wallCenter = kbUnitGetPosition(getUnit(gDockUnit));


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 70);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   //xsEnableRule("dockWallTwo"); Tone back the walls and stick to just the one for now
   xsDisableSelf();
}

rule dockWallTwo
inactive
minInterval 10
{
   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   if (gStartOnDifferentIslands == true && dockCount < 2)
   {
      return; // AssertiveWall: Need a dock
   }
   
   int wallPlanID = aiPlanCreate("WallTwoDock", cPlanBuildWall);
   float wallRadius = aiRandFloat(20.0, 30.0); // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(2) + 3;      // AssertiveWall: sets number of gates
   vector wallCenter = kbUnitGetPosition(getUnit(gDockUnit));


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 50);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsEnableRule("dockWallThree");
   xsDisableSelf();
}

rule dockWallThree
inactive
minInterval 10
{
   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   if (gStartOnDifferentIslands == true && dockCount < 3)
   {
      return; // AssertiveWall: Need a dock
   }
   
   int wallPlanID = aiPlanCreate("WallThreeDock", cPlanBuildWall);
   float wallRadius = aiRandFloat(20.0, 30.0); // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(2) + 3;      // AssertiveWall: sets number of gates
   vector wallCenter = kbUnitGetPosition(getUnit(gDockUnit));


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 30);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsEnableRule("dockWallOne");
   xsDisableSelf();
}


//==============================================================================
/* innerRingWall
   AssertiveWall: Builds a small circle around the base
*/
//==============================================================================

rule innerRingWall
inactive
minInterval 10
{
   if (btRushBoom > 0.3)
   {  // No walls for rushing civs
      xsDisableSelf();
      return;
   }

   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   
   int wallPlanID = aiPlanCreate("WallInBase", cPlanBuildWall);
   int baseID = kbBaseGetMainID(cMyID);
   float wallRadius = kbBaseGetDistance(cMyID, baseID) + aiRandFloat(20.0);   // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(4) + 3;           // AssertiveWall: sets number of gates
   int mapWidth = kbGetMapXSize();
   vector wallCenter = kbBaseGetLocation(cMyID, baseID);


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, baseID);
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 60);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + baseID);
   }
   xsDisableSelf();
}


//==============================================================================
/* seaWall
   AssertiveWall: Builds a large outer ring that hopefully covers a good portion
   of coastline
*/
//==============================================================================

rule seaWall
inactive
minInterval 10
{
   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }
   
   int wallPlanID = aiPlanCreate("SeaWall", cPlanBuildWall);
   int gateNumber = aiRandInt(4) + 4;      // AssertiveWall: sets number of gates
   int mapWidth = kbGetMapXSize();
   float wallRadius = mapWidth / 5.0; // Giant so it becomes a seawall 
   vector wallCenter = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   

   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 40);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsDisableSelf();
}


//==============================================================================
// RULE fillInWallGaps
//==============================================================================
rule fillInWallGaps
minInterval 31
inactive
{
   // If we're not building walls, go away.
   if (gBuildWalls == false)
   {
      xsDisableSelf();
      return;
   }

   float wallRadius = 30.0; // AssertiveWall: used to set wall ring size
   int gateNumber = 2;      // AssertiveWall: sets number of gates
   int mapWidth = kbGetMapXSize();
   vector wallCenter = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));

   // If we already have a build wall plan, don't make another one.
   if (aiPlanGetIDByTypeAndVariableType(cPlanBuildWall, cBuildWallPlanWallType, cBuildWallPlanWallTypeRing, true) >= 0 && gStartOnDifferentIslands == false)
      return;

   int wallPlanID = aiPlanCreate("FillInWallGaps", cPlanBuildWall);
      if (gStartOnDifferentIslands == true)
   {
      wallCenter = kbUnitGetPosition(getUnit(gDockUnit));
      wallRadius = 30.0;
      //wallRadius = mapWidth / 5.0; // Giant so it becomes a seawall
      gateNumber = 3;
   }

   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);

      aiPlanSetVariableVector(wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
   }
}


//==============================================================================
/* forwardBaseWall
   AssertiveWall: build up a whole wall system around the forward base
*/
//==============================================================================

rule forwardBaseWall
inactive
minInterval 10
{
   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }

   if (gStartOnDifferentIslands == true)
   {  // Island maps are too crowded for this
      xsEnableRule("forwardBaseTowers");
      xsDisableSelf();
   }

   if (gForwardBaseState == cForwardBaseStateNone) // || gForwardBaseState == cForwardBaseStateBuilding)
   {
      return; // AssertiveWall: wait until the fort is building or built
   }
   
   int wallPlanID = aiPlanCreate("FrontierWall", cPlanBuildWall);
   float wallRadius = 30.0; // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(2) + 3;      // AssertiveWall: sets number of gates
   vector wallCenter = gForwardBaseLocation;


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsEnableRule("forwardBaseTowers");
   xsDisableSelf();
}



//==============================================================================
/* forwardBaseTowers
   AssertiveWall: build up two towers near the forward base and wall them
*/
//==============================================================================

rule forwardBaseTowers
inactive
minInterval 10
{

   if (gForwardBaseState == cForwardBaseStateNone) // || gForwardBaseState == cForwardBaseStateBuilding)
   {
      return; // AssertiveWall: wait until the fort is building or built
   }

   // Two towers, economy escrow since military doesn't have any wood, 1 builder
   createSimpleBuildPlan(gTowerUnit, 2, 80, true, cEconomyEscrowID, gForwardBaseID, 1);

   if (gStartOnDifferentIslands == true)
   {  // Island maps are too crowded for this
      xsDisableSelf();
   }
   else
   {
      xsEnableRule("forwardBaseTowerWalls") ;
      xsDisableSelf();
   }
}

//==============================================================================
/* forwardBaseTowerWalls
   AssertiveWall: build up two towers near the forward base and wall them
*/
//==============================================================================

rule forwardBaseTowerWalls
inactive
minInterval 10
{
   int wallPlanID = aiPlanCreate("forwardBaseTowerWall", cPlanBuildWall);
   float wallRadius = 8.0;  // AssertiveWall: used to set wall ring size
   int gateNumber = 2;      // AssertiveWall: sets number of gates
   vector wallCenter = cInvalidVector;
   int unitQueryID = -1;

   // Skip building towers if we are already near max
   int towerCount = kbUnitCount(cMyID, gTowerUnit, cUnitStateAlive);
   if (towerCount >= cvMaxTowers - 1)
   {
      xsEnableRule("forwardBaseGreatWall");
      xsDisableSelf();
   }

   if (gStartOnDifferentIslands == true)
   {  // Island maps are too crowded for this
      xsDisableSelf();
   }
   

   // Goes through the nearby towers and picks the two closest
   unitQueryID = createSimpleUnitQuery(gTowerUnit, cMyID, cUnitStateAlive, gForwardBaseLocation, 50.0);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound < 1)
   {  // Go away until we have a tower
      return;
   }

   vector towerOneLoc = kbUnitGetPosition(kbUnitQueryGetResult(unitQueryID, 0));
   vector towerTwoLoc = kbUnitGetPosition(kbUnitQueryGetResult(unitQueryID, 1));

   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, towerOneLoc);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));


      // Second Tower
      if (numberFound < 2)
      {  // Probably won't ever get to two this way
         xsEnableRule("forwardBaseGreatWall");
         xsDisableSelf();
      }
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, towerTwoLoc);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }

   if (gStartOnDifferentIslands == false)
   {
      xsEnableRule("forwardBaseGreatWall");
   }
   xsDisableSelf();
}


//==============================================================================
/* forwardBaseGreatWall
   AssertiveWall: once the forward base is built up, try to wall the map
*/
//==============================================================================

rule forwardBaseGreatWall
inactive
minInterval 10
{
   if (gStartOnDifferentIslands == true)
   {  // Island maps are too crowded for this
      xsDisableSelf();
   }

   if ((kbGetPopCap() - kbGetPop()) < 20)
   {
      return; // Don't start walls until we have pop room
   }

   if (gForwardBaseState == cForwardBaseStateNone || gForwardBaseState == cForwardBaseStateBuilding)
   {
      return; // AssertiveWall: wait until the fort is built
   }
   
   int wallPlanID = aiPlanCreate("forwardBaseGreatWall", cPlanBuildWall);
   float wallRadius = kbBaseGetDistance(gMainBase, gForwardBaseID); // AssertiveWall: used to set wall ring size
   int gateNumber = aiRandInt(4) + 6;      // AssertiveWall: sets number of gates
   vector wallCenter = kbBaseGetLocation(gMainBase);


   if (wallPlanID != -1)
   {
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
      aiPlanAddUnitType(wallPlanID, cUnitTypeAbstractVillager, 1, 1, 1);
      aiPlanSetVariableVector(
      wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, wallCenter);
      aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
      
      aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
      aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
      aiPlanSetBaseID(wallPlanID, kbBaseGetMainID(cMyID));
      aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlanID, 80);
      aiPlanSetActive(wallPlanID, true);
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
      // Enable our wall gap rule, too.
      //xsEnableRule("fillInWallGaps");
      debugBuildings("Enabling Wall Plan for Base ID: " + kbBaseGetMainID(cMyID));
   }
   xsDisableSelf();
}


//==============================================================================
/* catchMigrants
   makes sure all villagers get transported from small island to big one
*/
//==============================================================================

rule catchMigrants
inactive
minInterval 10
{  
   // Only fire if we have ships for transport
   if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) <= 0)
   {
      return;
   }

   // Don't create a new transport if there is already a transport in progress
   /*if (aiPlanGetIDByIndex(cPlanTransport, -1, true, 0) >= 0)
   {
      return;
   }*/

   int areaCount = 0;
   vector myLocation = cInvalidVector;
   int myAreaGroup = -1;

   int area = 0;
   int areaGroup = -1;
   int numberNeeded = getUnitCountByLocation(cUnitTypeAbstractWagon, cMyID, cUnitStateAlive, kbBaseGetLocation(gOriginalBase), 50.0);
   int numberSettlers = getUnitCountByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAny, kbBaseGetLocation(gOriginalBase), 50.0);
   int numberMilitary = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAny, kbBaseGetLocation(gOriginalBase), 50.0);

   if (numberNeeded <= 0 && numberSettlers <=0 && numberMilitary <= 0)
   {
      return;
   }

   myLocation = kbBaseGetLocation(gOriginalBase);

   int transportPlan = createTransportPlan(myLocation, kbAreaGetCenter(gCeylonStartingTargetArea), 100);
   
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractWagon, numberNeeded, numberNeeded, numberNeeded);
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractVillager, numberSettlers, numberSettlers, numberSettlers);
   aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeLandMilitary, numberMilitary, numberMilitary, numberMilitary);
   aiPlanSetNoMoreUnits(transportPlan, true);
   aiPlanSetActive(transportPlan);

   //numberNeeded = getUnitCountByLocation(cUnitTypeLogicalTypeScout, cMyID, cUnitStateAlive, kbBaseGetLocation(gOriginalBase), 50.0);
   //aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeScout, numberNeeded, numberNeeded, numberNeeded);

   // go the entire game to catch stray settlers/wagons/scouts
}

//==============================================================================
/* ceylonFailsafe
   Goes through transport plans and helps them along
   Based on DE Ceylon nomad failsafe
*/
//==============================================================================

rule ceylonFailsafe
inactive
minInterval 15
{
   int transportPlan = aiPlanGetIDByTypeAndVariableType(cPlanTransport, cTransportPlanTransportID);
   int numberUnits = aiPlanGetNumberUnits(transportPlan);
   int transportUnit = -1;
   int tempTransportUnit = -1;
   
   for (i = 0; < numberUnits)
   {
      tempTransportUnit = aiPlanGetUnitByIndex(transportPlan, i);
      if (kbUnitIsType(tempTransportUnit, cUnitTypeAbstractWarShip) == true)
      {
         transportUnit = tempTransportUnit;
         break;
      }
   }

   switch(aiPlanGetState(transportPlan))
   {
      case -1:
      {
         xsDisableSelf();
         break;
      }
      case cPlanStateEnter:
      {
         aiTaskUnitMove(transportUnit, aiPlanGetVariableVector(transportPlan, cTransportPlanGatherPoint, 0));
         break;
      }
      case cPlanStateGoto:
      {
         aiTaskUnitMove(transportUnit, aiPlanGetVariableVector(transportPlan, cTransportPlanTargetPoint, 0));
         break;
      }
   }
}

//==============================================================================
/* generalTransportFailsafe

   Goes through transport plans and deletes the broken ones. Also saves people
   stranded out at sea on a broken transport plan
*/
//==============================================================================

rule generalTransportFailsafe
inactive
minInterval 25
{
   xsSetRuleMaxIntervalSelf(25);

   int numberPlans = aiPlanGetActiveCount();
   int transportPlan = -1;
   int numberUnits = 0;
   int transportUnit = -1;
   int tempTransportUnit = -1;
   vector transportLoc = cInvalidVector;
   vector homeBaseDropoff = cInvalidVector;
   
   // Loop through all active plans

   // Handle idle ships with someone on board
   int idleWarshipQuery = createSimpleIdleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   int numberWarships = kbUnitQueryExecute(idleWarshipQuery);   
   for (i = 0; < numberWarships)
   {
      transportUnit = kbUnitQueryGetResult(idleWarshipQuery, i);
      transportLoc = kbUnitGetPosition(transportUnit);
      if (aiPlanGetType(kbUnitGetPlanID(transportUnit)) == cPlanTransport)
      {
         continue;
      }
      if (kbUnitGetActionType(transportUnit) == cActionTypeIdle && getUnitCountByLocation(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationSelf,
         cUnitStateAlive, transportLoc, 2.0) > 0)
      {
         homeBaseDropoff = getDropoffPoint(kbUnitGetPosition(transportUnit), kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
         if (distance(kbUnitGetPosition(transportUnit), homeBaseDropoff) < 10.0)
         {
            aiTaskUnitEject(transportUnit);
         }
         else
         {
            aiPlanAddUnit(gNavyDefendPlan, transportUnit);
            aiTaskUnitMove(transportUnit, homeBaseDropoff);
            xsSetRuleMaxIntervalSelf(2);
         }
      }
   }

   // Handle the plans
   for (i = 0; < numberPlans)
	{
		transportPlan = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(transportPlan) != cPlanTransport)
      {
         transportPlan = -1;
         continue;
      }

      // Find the boat
      numberUnits = aiPlanGetNumberUnits(transportPlan);
      for (j = 0; < numberUnits)
      {
         tempTransportUnit = aiPlanGetUnitByIndex(transportPlan, j);
         if (kbUnitIsType(tempTransportUnit, cUnitTypeAbstractWarShip) == true || kbUnitIsType(tempTransportUnit, cUnitTypeAbstractFishingBoat) == true)
         {
            transportUnit = tempTransportUnit;
            break;
         }
      }
      if (transportUnit < 0)
      {  // Destroy the transport plan if it doesn't have a boat
         aiPlanDestroy(transportPlan);
         continue;
      }

      // Check the state of the transport plan
      switch(aiPlanGetState(transportPlan))
      {
         case -1:
         {
            break;
         }
         case cPlanStateEnter:
         {
            // Kill the plan if it's still idle and no one is on board
            if (kbUnitGetActionType(transportUnit) == cActionTypeIdle && getUnitCountByLocation(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationSelf,
                  cUnitStateAlive, transportLoc, 2.0) <= 0)
            {
               aiPlanDestroy(transportPlan);
               aiTaskUnitMove(transportUnit, gNavyVec);
               continue;
            }
            break;
         }
         case cPlanStateGoto:
         {
            transportLoc = kbUnitGetPosition(transportUnit);
            if (getUnitCountByLocation(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationSelf,
                  cUnitStateAlive, transportLoc, 2.0) <= 0)
            {
               aiPlanDestroy(transportPlan);
               aiTaskUnitMove(transportUnit, gNavyVec);
            }
            break;
         }
      }
   }

   // Finally, kill everyone without a unit on board if there are more than 3 plans active
   numberPlans = aiPlanGetActiveCount();
   int transportPlanTotal = 0;
   idleWarshipQuery = createSimpleIdleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   numberWarships = kbUnitQueryExecute(idleWarshipQuery);
   int warshipNumber = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive, kbGetPlayerStartingPosition(cMyID), 300.0);
   for (i = 0; < numberPlans)
	{
      transportPlan = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(transportPlan) != cPlanTransport)
      {
         continue;
      }
      transportPlanTotal += 1;
   }

   if (transportPlanTotal > 3 || transportPlanTotal > warshipNumber)
   {
      for (i = 0; < numberPlans)
      {
         transportPlan = aiPlanGetIDByActiveIndex(i);
         if (aiPlanGetType(transportPlan) != cPlanTransport)
         {
            continue;
         }

         // Find the boat
         numberUnits = aiPlanGetNumberUnits(transportPlan);
         for (j = 0; < numberUnits)
         {
            tempTransportUnit = aiPlanGetUnitByIndex(transportPlan, j);
            if (kbUnitIsType(tempTransportUnit, cUnitTypeAbstractWarShip) == true || kbUnitIsType(tempTransportUnit, cUnitTypeAbstractFishingBoat) == true)
            {
               transportUnit = tempTransportUnit;
               break;
            }
         }

         transportLoc = kbUnitGetPosition(transportUnit);
         if (getUnitCountByLocation(cUnitTypeLogicalTypeGarrisonInShips, cPlayerRelationSelf,
               cUnitStateAlive, transportLoc, 2.0) <= 0)
         {
            aiPlanDestroy(transportPlan);
            //aiChat(1, "Killed All Transport Plans with no one on board");
         }
      }
   }
}

//==============================================================================
/* delayedGeneralTransportFailsafe
   Used on migration maps to delay the transport failsafe. Checks whether the 
   bulk of villagers have made it to the mainland
*/
//==============================================================================

rule delayedGeneralTransportFailsafe
inactive
minInterval 10
{
   if (kbGetAge() < cAge2)
   {  // We don't migrate until age 2
      return;
   }
   // See if our main base is no longer our starting location
   vector startingLocation = kbGetPlayerStartingPosition(cMyID);
   vector baseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(startingLocation), kbAreaGroupGetIDByPosition(baseLocation)) == true)
   {  // New base isn't set yet if it can be reached by starting location
      return;
   }

   // Get the number of villagers. If there are more by the new base than the original, then go ahead and initiate the failsafe 
   if (getUnitCountByLocation(cUnitTypeAbstractVillager, cPlayerRelationSelf, cUnitStateAlive, baseLocation, 80.0) > 
         getUnitCountByLocation(cUnitTypeAbstractVillager, cPlayerRelationSelf, cUnitStateAlive, startingLocation, 80.0))
   {
      xsEnableRule("generalTransportFailsafe");
      xsDisableRule("ceylonFailsafe");
      //aiChat(1, "Switching to standard failsafe");
      xsDisableSelf();
   }
}

//==============================================================================
/* buildPlanDeletion
   Similar to how the ceylonFailsafe deletes broken transport plans, this 
   goes through and deletes build plans. Necessary on island maps when 
   the builder doesn't transport properly.
*/
//==============================================================================

rule buildPlanDeletion
inactive
minInterval 60
{
   int numberPlans = aiPlanGetActiveCount();
   int builderUnit = -1;
   int buildUnit = -1;
   int buildPlan = -1;
   int numberUnits = 0;
   int tempBuildUnit = -1;
   for (i = 0; < numberPlans)
	{
      buildPlan = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(buildPlan) != cPlanBuild)
      {
         continue;
      }
      // Find the villager
      numberUnits = aiPlanGetNumberUnits(numberPlans);
      for (j = 0; < numberUnits)
      {
         tempBuildUnit = aiPlanGetUnitByIndex(buildPlan, j);
         if (kbUnitIsType(tempBuildUnit, cUnitTypeAbstractVillager) == true || kbUnitIsType(tempBuildUnit, cUnitTypeAbstractWagon) == true)
         {
            builderUnit = tempBuildUnit;
            break;
         }
      }

      if (builderUnit < 0)
      {
         // no builder found
         aiPlanDestroy(buildPlan);
         aiChat(1, "deleting a build plan");
      }
   }
}

//==============================================================================
/* islandMigration
   Based on Ceylon Nomad Start
*/
//==============================================================================

rule islandMigration
inactive
minInterval 3
{  // cUnitTypeypMarathanCatamaran
   //gCeylonDelay = true; // Causes building manager and military manager to wait
   int shipType = cUnitTypeTransport;
   if (kbUnitCount(cMyID, shipType, cUnitStateAlive) <= 0)
   {
      shipType = cUnitTypeypMarathanCatamaran;
      if (kbUnitCount(cMyID, shipType, cUnitStateAlive) <= 0)
      {
         //gCeylonDelay = false;
         return;
      }
   }

   int areaCount = 0;
   vector myLocation = cInvalidVector;
   int myAreaGroup = -1;

   int area = 0;
   int areaGroup = -1;
   vector startingLoc = kbGetPlayerStartingPosition(cMyID);
   int unit = getUnitByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, startingLoc, 100); // getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);

   areaCount = kbAreaGetNumber();
   myLocation = kbUnitGetPosition(unit);
   myAreaGroup = kbAreaGroupGetIDByPosition(myLocation);

   // sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, myLocation);
   
   // Build a couple things on starting island. Stuff that doesn't cause issues later
   createSimpleBuildPlan(gDockUnit, 1, 99, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
   createSimpleBuildPlan(gHouseUnit, 1, 95, false, cEconomyEscrowID, kbBaseGetMainID(cMyID), 1);
   if (btRushBoom <= 0)
   {
      createSimpleBuildPlan(gTowerUnit, 1, 50, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID));
      //createSimpleBuildPlan(gMarketUnit, 1, 90, false, cEconomyEscrowID, kbBaseGetMainID(cMyID), 1); 
   }

   // Find enemy starting location Location
   vector enPosition = kbGetPlayerStartingPosition(getEnemyPlayerByTeamPosition(1));
   int closestArea = -1;
   float closestAreaDistance = kbGetMapXSize();

   for (area = 0; < areaCount)
   {
      if (kbAreaGetType(area) == cAreaTypeWater)
      {
         continue;
      }

      areaGroup = kbAreaGroupGetIDByPosition(kbAreaGetCenter(area));
      /*if (kbAreaGroupGetNumberAreas(areaGroup) - kbAreaGroupGetNumberAreas(myAreaGroup) <= 10)
      {
         continue;
      }*/

      // Check to make sure this area is connected to center island
      if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(kbGetMapCenter()), areaGroup) == false)
      {
         continue;
      }
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(area));

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


      // Try to move landing area away from enemies
      float distToEnemyTC = xsVectorLength(kbAreaGetCenter(area) - enPosition);
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, enPosition);
      float dist = xsVectorLength(kbAreaGetCenter(area) - myLocation) - 0;//1.0 * distToEnemyTC;
      if (dist < closestAreaDistance)
      {
         closestAreaDistance = dist;
         closestArea = area;
      }
   }

   // Move main base 
   gCeylonStartingTargetArea = closestArea;
   kbBaseSetPositionAndDistance(cMyID, kbBaseGetMainID(cMyID), kbAreaGetCenter(gCeylonStartingTargetArea), 100.0);
   xsEnableRule("buildingMonitorDelayed");

   //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(gCeylonStartingTargetArea));

   // Move someone toward the center so we can see our landing spot
   /*aiTaskUnitMove(getUnit(shipType, cMyID, cUnitStateAlive), kbAreaGetCenter(closestArea));

   // This used to be "islandwaitforexplore" but a separate rule no longer necessary
   //int unit = getUnit(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive);

   int baseID = kbBaseCreate(cMyID, "Transport gather base", myLocation, 10.0);
   kbBaseAddUnit(cMyID, baseID, unit);

   int transportPlan = createTransportPlan(myLocation, kbAreaGetCenter(gCeylonStartingTargetArea), 100.0, false);
   sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(gCeylonStartingTargetArea));

   aiPlanSetEventHandler(transportPlan, cPlanEventStateChange, "initIslandTransportHandler");

   //int numberNeeded = getUnitCountByLocation(cUnitTypeAbstractWagon, cMyID, cUnitStateAlive, startingLoc, 100.0);
   int numberSettlers = getUnitCountByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, startingLoc, 100.0);
   
   //aiPlanAddUnitType(transportPlan, cUnitTypeAbstractWagon, numberNeeded, numberNeeded, numberNeeded);
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractVillager, numberSettlers, numberSettlers, numberSettlers);
   aiPlanSetNoMoreUnits(transportPlan, true);

   //numberNeeded = getUnitCountByLocation(cUnitTypeLogicalTypeScout, cMyID, cUnitStateAlive, startingLoc, 100.0);
   //aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeScout, numberNeeded, numberNeeded, numberNeeded);


   xsEnableRule("initIslandFailsafe");*/

   xsDisableSelf();
}

void initIslandTransportHandler(int planID = -1)
{
   static bool transporting = false;
   vector centerPoint = kbGetMapCenter();

   switch (aiPlanGetState(planID))
   {
   case -1:
   {
      if (transporting == true)
      {
         // transport done.

         // build a TC on the main island in the direction of the map center to our starting position.
         vector vec = xsVectorNormalize(kbGetPlayerStartingPosition(cMyID) - centerPoint);
         //int wagon = getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);
         //vector wagonLoc = kbUnitGetPosition(wagon);
         float dist = xsVectorLength(kbGetPlayerStartingPosition(cMyID) - centerPoint);

         for (i = 0; < 100)
         {
            dist = dist - i * 10;
            gTCSearchVector = centerPoint + vec * dist;
            if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(gTCSearchVector), kbAreaGroupGetIDByPosition(centerPoint)) == true)
            {  // Once we find the coast, go in a little further
               gTCSearchVector = centerPoint + vec * (dist - (40 + aiRandInt(30)));
               gStartingLocationOverride = gTCSearchVector;
               break;
            }
         }
         // Testing purposes
         // sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, gStartingLocationOverride);

         kbBaseDestroy(cMyID, gMainBase);
         int gMainBase2 = kbBaseCreate(cMyID, "Island base", gStartingLocationOverride, 100.0); // createMainBase(gStartingLocationOverride);
         kbBaseSetMain(cMyID, gMainBase2, true);
         kbBaseSetPositionAndDistance(cMyID, kbBaseGetMainID(cMyID), gStartingLocationOverride, 100.0);
         kbBaseSetActive(cMyID, gMainBase2);

         // Add existing town center to base
         int townCenterID = getUnit(cUnitTypeTownCenter, cMyID, cUnitStateAlive);
         kbBaseAddUnit(cMyID, gMainBase2, townCenterID);
         


         xsEnableRule("buildingMonitorDelayed");
         gCeylonDelay = false;

         //aiTaskUnitMove(wagon, gTCSearchVector);

         //xsEnableRule("initRule");
         //   xsEnableRule("waterAttack");
      }
      break;
   }
   case cPlanStateGather:
   {
      // hack drop-off point
      vector targetPoint = aiPlanGetVariableVector(planID, cTransportPlanTargetPoint, 0);
         aiPlanSetVariableVector(planID, cTransportPlanDropOffPoint, 0,
            xsVectorSet(0.2 * xsVectorGetX(centerPoint) + 0.8 * xsVectorGetX(targetPoint), 0.0,
              0.2 * xsVectorGetZ(centerPoint) + 0.8 * xsVectorGetZ(targetPoint)));
      break;
   }
   case cPlanStateGoto:
   {
      transporting = true;
      break;
   }
   }
}

rule initIslandFailsafe
inactive
minInterval 10
{
   int transportPlan = aiPlanGetIDByTypeAndVariableType(cPlanTransport, cTransportPlanTransportTypeID,
      cUnitTypeAbstractWarShip);
   switch (aiPlanGetState(transportPlan))
   {
   case -1:
   {
      xsDisableSelf();
      break;
   }
   case cPlanStateEnter:
   {
         aiTaskUnitMove(aiPlanGetVariableInt(transportPlan, cTransportPlanTransportID, 0),
          aiPlanGetVariableVector(transportPlan, cTransportPlanGatherPoint, 0));
      break;
   }
   }
}


//==============================================================================
// buildingMonitorDelayed
// Add a brief delay to make sure we don't accidentally build anything too soon
//==============================================================================
rule buildingMonitorDelayed
inactive
minInterval 10
{
   gCeylonDelay = false;
   // Run both as soon as the delay here is done
   //buildingMonitor();
   //militaryManager();
   xsEnableRule("catchMigrants");

   debugSetup("***Delay buildingMonitor and MilitaryManager");
   xsDisableSelf();
}


//==============================================================================
// fishFunction
// AssertiveWall: Like the rule to update fishing boat maintain plan, but as a 
//                function so the boat boom rules can call it
//==============================================================================
void fishFunction(int maxFishingBoats = 10, int boatPriority = 55, int maxDistance = 100)
{
   if (kbUnitCount(cMyID, gDockUnit, cUnitStateAlive) < 1)
   {
      aiPlanSetVariableInt(gFishingBoatMaintainPlan, cTrainPlanNumberToMaintain, 0, 0);
      return;
   }
   
   int numberFishingBoats = kbUnitCount(cMyID, gFishingUnit, cUnitStateABQ);
   int numberFoodFishingBoats = kbGetAmountValidResourcesByLocation(gNavyVec,
      cResourceFood, cAIResourceSubTypeFish, maxDistance) / 400.0;
   int numberGoldFishingBoats = getUnitCountByLocation(cUnitTypeAbstractWhale, 0, cUnitStateAny, gNavyVec, maxDistance) * 4;

   if (numberFishingBoats < numberFoodFishingBoats)
   {
      numberFishingBoats = numberFoodFishingBoats;
   }
   if (numberFishingBoats < numberGoldFishingBoats)
   {
      numberFishingBoats = numberGoldFishingBoats;
   }
   if (numberFishingBoats > maxFishingBoats)
   {
      numberFishingBoats = maxFishingBoats;
   }

   int fishingBoatQuery = createSimpleUnitQuery(gFishingUnit, cMyID, cUnitStateAlive);
   kbUnitQuerySetActionType(fishingBoatQuery, cActionTypeIdle);
   int numberFound = kbUnitQueryExecute(fishingBoatQuery);

   if (numberFound > 3 ) // We have too many idle boats indicating we don't know what to use them for so don't train more.
   {
      numberFishingBoats = 0;
   }

   aiPlanSetVariableInt(gFishingBoatMaintainPlan, cTrainPlanNumberToMaintain, 0, numberFishingBoats);
   aiPlanSetDesiredResourcePriority(gFishingBoatMaintainPlan, boatPriority);

   return;
}



//==============================================================================
/* boatBoomMonitor
   AssertiveWall: monitor that decided between little, double, and big boy boat
                  booms. 
                  This replaces fishManager
*/
//==============================================================================

rule boatBoomMonitor
inactive
minInterval 10
{
   /* There are three different boat boom types; little, double, and big boy
      Little:  Designate one dock to produce fishing boats out of and try to keep
               production up in that one dock 
      Double:  Same as Little, except designate 2 docks
      Big Boy: Like the other two, but we build 4 docks and spam tons of fishing
               boats from them.
   */

   // Some logic to determine if we'll go for the water
   if (gTimeToFish == false)
   {
      if (kbGetAge() < cAge2 && agingUp() == false)
      {
         return;
      }

      // On island maps, start in transition
      if (gStartOnDifferentIslands == true)
      {
         gTimeToFish = true;
      }

      // Check how far we are from water, and go for it if we're the closest teammate
      int closestTeammate = -1;
      int closestDist = 99999;
      int testDist = -1;
      for (i = 1; < cNumberPlayers)
      {  
         if (kbIsPlayerAlly(i) != true)
         {
            continue;
         }

         testDist = distance(kbGetPlayerStartingPosition(i), 
                  kbUnitGetPosition(getUnit(cUnitTypeHomeCityWaterSpawnFlag, i)));
         if (testDist < closestDist)
         {
            closestTeammate = i;
            closestDist = testDist;
         }
      }
      if (closestTeammate == cMyID && btRushBoom <= 0.5)
      {  // We are the closest teammate, just make sure we aren't all-in rushing
         gTimeToFish = true;
      }

      // If we are booming heavy, go for water
      if (btRushBoom < -0.4)
      {
         gTimeToFish = true;
      }

      // Now some random checks
      static int randomizer = -1;
      if (randomizer < 0) // We roll once to enable it, otherwise other economy code can enable it.
      {
         randomizer = aiRandInt(10);
      }

      if (btRushBoom <= 0.0 && randomizer < 3)
      {
         gTimeToFish = true;
      }
      else if (gTimeToFish == false)
      {
         return;
      }
   }

   int enemyWSStrength = -1;
   int friendlyWSStrength = -1;
   int friendlyWSQuery = -1;
   int enemyWSQuery = -1;
   int friendlyWSCount = -1;
   int enemyWSCount = -1;

   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateABQ);
   int mainBaseID = kbBaseGetMainID(cMyID);
   int desiredDockCount = -1;
   int maxFishingBoats = -1;
   int boatPriority = -1;
   int maxDistance = -1;
   int tempBoatUnit = -1;

   // Get the associated strength of friendly and enemy fleets
   friendlyWSQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationAlly, cUnitStateAlive);
   friendlyWSCount = kbUnitQueryExecute(friendlyWSQuery);
   for (i = 0; < friendlyWSCount)
   {
      tempBoatUnit = kbUnitGetProtoUnitID(kbUnitQueryGetResult(friendlyWSQuery, i));
      friendlyWSStrength += kbUnitCostPerResource(tempBoatUnit, cResourceWood) + kbUnitCostPerResource(tempBoatUnit, cResourceGold) +
                           kbUnitCostPerResource(tempBoatUnit, cResourceInfluence);
   }

   enemyWSQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia, cUnitStateAlive);
   enemyWSCount = kbUnitQueryExecute(enemyWSQuery);
   tempBoatUnit = -1;
   for (i = 0; < enemyWSCount)
   {
      tempBoatUnit = kbUnitGetProtoUnitID(kbUnitQueryGetResult(enemyWSQuery, i));
      enemyWSStrength += kbUnitCostPerResource(tempBoatUnit, cResourceWood) + kbUnitCostPerResource(tempBoatUnit, cResourceGold) +
                           kbUnitCostPerResource(tempBoatUnit, cResourceInfluence);
   }
   //aiChat(1, "Counts F:E " + friendlyWSCount + ":" + enemyWSCount);
   //aiChat(1, "Value F:E " + friendlyWSStrength + ":" + enemyWSStrength);


   // Conditional for Big Boy:   The opponent is not uncompetitive on water, and 
   //                            we are in a booming disposition
   if (btRushBoom < 0 && friendlyWSStrength > 3 * enemyWSStrength && friendlyWSStrength > 1500)
   {
      //aiChat(1, "Big boy boat boom");
      desiredDockCount = 4;
      maxFishingBoats = 40;
      boatPriority = 90;
      maxDistance = kbGetMapXSize()/(3 * cNumberPlayers);
   } 
   // Conditional for Double:    The opponent is losing on water, and we want to capitalize unless we are 
   //                            a rushing civ
   else if (btRushBoom < 0.2 && friendlyWSStrength > 1.3 * enemyWSStrength && friendlyWSStrength > 1100)
   {
      //aiChat(1, "Double Dock boat boom");
      desiredDockCount = 2;
      maxFishingBoats = 30;
      boatPriority = 60;
      maxDistance = 150;
   } 
   // Conditional for Single:    As long as we are ahead at least a little on water
   else if (btRushBoom < 0.4 && friendlyWSStrength > 1.0 * enemyWSStrength && friendlyWSStrength > 350)
   {
      //aiChat(1, "Single Dock Trickle");
      desiredDockCount = 1;
      maxFishingBoats = 25;
      boatPriority = 55;
      maxDistance = 80;    
   } 
   else
   {
      //aiChat(1, "No boat boom");
      desiredDockCount = 1;
      maxFishingBoats = 15;
      boatPriority = 45;
      maxDistance = 80;    
   }


   if (dockCount < desiredDockCount)
   {
      createSimpleBuildPlan(gDockUnit, 1, 70, false, cMilitaryEscrowID, mainBaseID, 1); 
   }

   fishFunction(maxFishingBoats, boatPriority, maxDistance);

}

//==============================================================================
// Checks to see if we should retreat
// 
//==============================================================================
bool retreatCheck()
{
   if (gAmphibiousAssaultStage > cGatherNavy)
   {
      // Enemy Navy Value
      int enNavyQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia, cUnitStateAlive, gAmphibiousAssaultTarget, 80);
      int enNavySize = kbUnitQueryExecute(enNavyQuery);
      int enNavyValue = 0;
      int enTowerQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeBuildingsHasRangedAttack, cPlayerRelationEnemyNotGaia, cUnitStateAlive, gAmphibiousAssaultTarget, 60);
      int enTowerSize = kbUnitQueryExecute(enTowerQuery);
      int enTowerValue = 0;
      int frNavyValue = 0;
      int unitID = -1;
      int puid = -1;

      for (i = 0; < enNavySize)
      {
         unitID = kbUnitQueryGetResult(enNavyQuery, i);
         puid = kbUnitGetProtoUnitID(unitID);
         enNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                           kbUnitCostPerResource(puid, cResourceInfluence));
      }

      for (i = 0; < enTowerSize)
      {
         unitID = kbUnitQueryGetResult(enTowerQuery, i);
         puid = kbUnitGetProtoUnitID(unitID);
         enTowerValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                           kbUnitCostPerResource(puid, cResourceInfluence));
      }

      int frNavySize = aiPlanGetNumberUnits(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip);
      for (i = 0; < frNavySize)
      {
         unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
         puid = kbUnitGetProtoUnitID(unitID);
         frNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                           kbUnitCostPerResource(puid, cResourceInfluence));
      }

      // If we're too outnumbered then retreat to gNavyVec
      if (frNavyValue * 1.2 < (enNavyValue + enTowerValue))
      {
         gAmphibiousAssaultStage = cGatherNavy;
         for (i = 0; < frNavySize)
         {
            unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
            aiTaskUnitMove(unitID, gNavyVec);
         }
         aiPlanDestroy(gAmphibiousAssaultPlan);
         aiPlanDestroy(gAmphibiousArmyPlan);
         return true;
      }
   }

   return false;
}


//==============================================================================
// Gathers the army 
// 
//==============================================================================
void gatherArmy(vector location = cInvalidVector)
{
   // Gather all the army units
   int armyQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(armyQueryID);
   int vilQueryID = createSimpleUnitQuery(gEconUnit, cMyID, cUnitStateAlive);
   int numberVilWanted = 2;
   int unitID = -1;
   int unitPlanID = -1;

   aiPlanAddUnitType(gAmphibiousArmyPlan, cUnitTypeLogicalTypeLandMilitary, 1, numberFound, numberFound);
   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(armyQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      if (aiPlanGetDesiredPriority(unitPlanID) >= 99)           // Already in the plan or on a transport
      {
         continue;
      }
      aiPlanAddUnit(gAmphibiousArmyPlan, unitID);
      aiTaskUnitMove(unitID, location);
   }

   // Gather a few villagers
   if (kbGetAge() >= cAge4)
   {
      numberVilWanted = 4;
   }
   aiPlanAddUnitType(gAmphibiousArmyPlan, gEconUnit, 1, numberVilWanted, numberVilWanted);
   for (j = 0; < numberVilWanted)
   {
      unitID = kbUnitQueryGetResult(vilQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      if (aiPlanGetDesiredPriority(unitPlanID) >= 99)           // Already in the plan or on a transport
      {
         continue;
      }
      
      aiPlanAddUnit(gAmphibiousArmyPlan, unitID);
      aiTaskUnitMove(unitID, location);
   }

   return;
}


//==============================================================================
// Gathers the navy 
// If the plan state isn't in cGatherNavy then it will only add the units to
// the reserve plan
// 
//==============================================================================
void gatherNavy(vector location = cInvalidVector)
{
   // Start by getting all the available ships
   int shipQueryID = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(shipQueryID);
   int unitID = -1;
   int unitPlanID = -1;

   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(shipQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      if (aiPlanGetDesiredPriority(unitPlanID) == 99)           // Already in this plan
      {  // Keep it close
         if (distance(kbUnitGetPosition(unitID), location) > 40)
         {
            aiTaskUnitMove(unitID, location);
         }
         continue;
      }
      if ((aiPlanGetDesiredPriority(unitPlanID) == 24) ||           // Repairing
            aiPlanGetDesiredPriority(unitPlanID) == 25 ||           // Actively Defending
            aiPlanGetType(unitPlanID) == cPlanTransport ||          // Transporting
            aiPlanGetDesiredPriority(unitPlanID) == 100 ||          // Also transporting
            kbUnitGetHealth(unitID) < 0.5)                          // Half health
      {
         continue;
      }
      aiPlanAddUnit(gAmphibiousAssaultPlan, unitID);
      if (gAmphibiousAssaultStage == cGatherNavy)
      {
         aiTaskUnitMove(unitID, location);
      }
   }

   // Check if most have made it
   if (gAmphibiousAssaultStage == cGatherNavy)
   {
      int gatherTarget = aiPlanGetNumberUnits(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip);
      int gatheredUnits = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive, location, 50.0);
      // Make sure we have 3 of 4 or at least 70%
      // Minimum 3 ships
      aiChat(1, "Gathered: " + gatheredUnits + " Of " + gatherTarget);
      if ((gatheredUnits > 4 && gatheredUnits >= gatherTarget - 1) || gatheredUnits > 0.7 * gatherTarget)
      {
         if (gatheredUnits >= 3)
         {
            aiChat(1, "moving to bombard coast");
            gAmphibiousAssaultStage = cBombardCoast;
         }
      }
   }

   return;
}

//==============================================================================
// Bombards the landing point
// Attacks ships and towers in the area
//==============================================================================
void bombardCoast()
{
   // Look for units to task our navy to attack. Focus down weakest units, then strongest units.
   // Monitors focus on buildings

   // Enemy Navy Value
   int enNavyQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia, cUnitStateAlive, gAmphibiousAssaultTarget, 80);
   int enNavySize = kbUnitQueryExecute(enNavyQuery);
   int enTotalValue = 0;
   int enNavyValue = 0;
   int weakestEnValue1 = -1;
   int weakestShip1 = -1;
   int weakestEnValue2 = -2;
   int weakestShip2 = -1;
   int enTowerQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeBuildingsHasRangedAttack, cPlayerRelationEnemyNotGaia, cUnitStateAlive, gAmphibiousAssaultTarget, 60);
   int enTowerSize = kbUnitQueryExecute(enTowerQuery);
   int enTowerValue = 0;
   int weakestEnTowerValue = 0;
   int weakestEnTower = -1;
   int weakestTower = -1;
   int frNavyValue = 0;
   int unitID = -1;
   int puid = -1;

   // Find the two weakest ships to focus on
   for (i = 0; < enNavySize)
   {
      unitID = kbUnitQueryGetResult(enNavyQuery, i);
      puid = kbUnitGetProtoUnitID(unitID);
      enNavyValue = kbUnitGetHealth(unitID) * (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));
      enTotalValue += enNavyValue;
      if (enNavyValue < weakestEnValue1 || enNavyValue < weakestEnValue2)
      {
         if (weakestEnValue1 > weakestEnValue2)
         {
            weakestShip1 = unitID;
            weakestEnValue1 = enNavyValue;
         }
         else
         {
            weakestShip2 = unitID;
            weakestEnValue2 = enNavyValue;
         }
      }
   }

   // Find the weakest tower/fort/tc to focus on
   for (i = 0; < enTowerSize)
   {
      unitID = kbUnitQueryGetResult(enTowerQuery, i);
      puid = kbUnitGetProtoUnitID(unitID);
      enTowerValue = kbUnitGetHealth(unitID) * (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));
      enTotalValue += enTowerValue;
      if (enTowerValue < weakestEnTowerValue)
      {
         weakestEnTower = unitID;
         weakestEnTowerValue = enTowerValue;
      }
   }

   // See if there is artillery. If there is, override the tower
   unitID = getUnitByLocation(cUnitTypeAbstractArtillery, cPlayerRelationEnemyNotGaia, cUnitStateAlive, gAmphibiousAssaultTarget, 40.0);
   if (unitID > 0)
   {
      weakestEnTower = unitID;
   }


   int frNavySize = aiPlanGetNumberUnits(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip);
   for (i = 0; < frNavySize)
   {  // Go through each ship. Monitors attack towers. As for others, first half attack ship1, second ship2
      unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
      puid = kbUnitGetProtoUnitID(unitID);
      frNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));

      if (weakestEnTower > 0 || weakestShip1 > 0 || weakestShip2 > 0)
      {
         if (puid == gMonitorUnit && weakestEnTower > 0)
         {
            aiTaskUnitWork(unitID, weakestEnTower);
         }
         else if (i < frNavySize / 2)
         {
            aiTaskUnitWork(unitID, weakestShip1);
         }
         else
         {
            aiTaskUnitWork(unitID, weakestShip2);
         }
      }
      // no targets, so tell them to move closer if they are too far away
      else if (distance(kbUnitGetPosition(unitID), gAmphibiousAssaultTarget) > 40)
      {
         aiTaskUnitMove(unitID, gAmphibiousAssaultTarget);
      }

      // Now check if we should go to next stage. Basically when the enemy towers and ships are taken care of
      // Make sure we have 2 ships minimum there
      if (frNavyValue > 2 * enTotalValue || enNavySize <= 1 || (enTowerSize == 0 && enNavySize < 3))
      {
         if (frNavyValue > 2)
         {
            if (gAmphibiousAssaultStage < cLoadForces)
            {
               gAmphibiousAssaultStage = cLoadForces;
            }
         }
      }
   }

   return;
}


//==============================================================================
// Creates the transport
// 
//==============================================================================
void loadForces(vector pickupPoint = cInvalidVector)
{
   // Use a standard point between our main base and the target point
   if (pickupPoint == cInvalidVector)
   {
      pickupPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMain(cMyID)));
   }

   // Find all military land units near the pickup point
   int landingForcesQuery =  createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf, cUnitStateAlive, pickupPoint, 50);
   int landingForcesSize = kbUnitQueryExecute(landingForcesQuery);
   int tempShip = -1;
   int tempShipValue = 0;
   int ship1 = -1;
   int ship1Value = 0;
   int ship2 = -1;
   int ship2Value = 0;
   int puid = -1;
   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   int shipNumber = kbUnitQueryExecute(shipQuery);
   int tempLandUnit = -1;
   int unitsOnShip1 = 0;
   int unitsOnShip2 = 0;
   bool switch1 = true;
   bool switch2 = true;
   int transportPlanID = -1;
   int transportPlan2ID = -1;

   aiChat(1, "Landing Force Size: " + landingForcesSize + " plan# " + aiPlanGetNumberUnits(gAmphibiousArmyPlan));
   // Check to see if we even have anyone. If not, restart
   if (landingForcesSize == 0)
   {
      gAmphibiousAssaultStage = cGatherNavy;
      return;
   }

   for (i = 0; < aiPlanGetNumberUnits(gAmphibiousArmyPlan))
   {  // If we only have 1 ship, everyone boards that ship. Otherwise split 50/50
      tempLandUnit = aiPlanGetUnitByIndex(gAmphibiousArmyPlan, i);
      if (ship2 < 0)
      {
         aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
      }
      else
      {
         if (i < landingForcesSize / 2)
         {
            aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
         }
         else
         {
            aiTaskUnitWork(tempLandUnit, gLandingShip2, true);
         }
      }
   }


   // Make sure our existing ships are still alive
   if (kbUnitGetHealth(gLandingShip1) < 0.0)
   {
      aiChat(1, "transport 1 died");
      gLandingShip1 = -1;
   }
   if (kbUnitGetHealth(gLandingShip2) < 0.0)
   {
      gLandingShip2 = -1;
   }


   if (landingForcesSize > 50)
   { // Needs 2 transports
      // Weight galleons higher and frigates lower (so they can keep fighting)
      for (i = 0; < shipNumber)
      {
         tempShip = kbUnitQueryGetResult(shipQuery, i);

         // Avoid switching transport ships repeatedly
         if (tempShip == gLandingShip1)
         {
            switch1 = false;
         }
         if (tempShip == gLandingShip2)
         {
            switch2 = false;
         }

         puid = kbUnitGetProtoUnitID(tempShip);
         tempShipValue = kbUnitGetHealth(tempShip) * (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));
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
         else if (tempShipValue > ship2Value)
         {
            ship2 = tempShip;
            ship2Value = tempShipValue;
         }
      }
   }
   else
   { // Needs 1 transport
      for (i = 0; < shipNumber)
      {
         tempShip = kbUnitQueryGetResult(shipQuery, i);
         puid = kbUnitGetProtoUnitID(tempShip);
         tempShipValue = kbUnitGetHealth(tempShip) * (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));
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
   }

   // Store the ships for the follow on rules
   if (switch1 == true)
   {
      gLandingShip1 = ship1;
      aiPlanAddUnit(gAmphibiousTransportPlan, ship1);
      aiTaskUnitMove(gLandingShip1, pickupPoint);
   }

   if (switch2 == true && landingForcesSize > 50)
   {
      gLandingShip2 = ship2;
      aiPlanAddUnit(gAmphibiousTransportPlan, ship2);
      aiTaskUnitMove(gLandingShip2, pickupPoint);
   }
   else if (ship2 < 0)
   {
      gLandingShip2 = -1;
   }

   // If we don't have any ships return
   if (gLandingShip1 < 0 || (landingForcesSize > 50 && gLandingShip2 < 0))
   {
      return;
   }
   aiPlanDestroy(gAmphibiousArmyPlan);

   // Create transport plan
   transportPlanID = aiPlanCreate(kbGetUnitTypeName(kbUnitGetProtoUnitID(gLandingShip1)) + " Transport Plan, ", cPlanTransport);
   aiPlanSetVariableInt(transportPlanID, cTransportPlanTransportID, 0, gLandingShip1);
   aiPlanSetVariableInt(transportPlanID, cTransportPlanTransportTypeID, 0, kbUnitGetProtoUnitID(gLandingShip1));
   aiPlanAddUnitType(transportPlanID, kbUnitGetProtoUnitID(gLandingShip1), 1, 1, 1);
   if (aiPlanAddUnit(transportPlanID, gLandingShip1) == false)
   {
      aiPlanDestroy(transportPlanID);
      return;
   }
   aiPlanSetVariableVector(transportPlanID, cTransportPlanGatherPoint, 0, pickupPoint);
   aiPlanSetVariableVector(transportPlanID, cTransportPlanTargetPoint, 0, gAmphibiousAssaultTarget);
   aiPlanSetVariableBool(transportPlanID, cTransportPlanReturnWhenDone, 0, false);
   aiPlanSetVariableBool(transportPlanID, cTransportPlanPersistent, 0, false);
   aiPlanSetVariableBool(transportPlanID, cTransportPlanMaximizeXportMovement, 0, true);
   aiPlanSetVariableInt(transportPlanID, cTransportPlanPathType, 0, cTransportPathTypePoints);

   aiPlanSetRequiresAllNeedUnits(transportPlanID, true);
   aiPlanSetDesiredPriority(transportPlanID, 100);

   // Same as above, but another one for the second transport
   if (landingForcesSize > 50)
   {
      transportPlan2ID = aiPlanCreate(kbGetUnitTypeName(kbUnitGetProtoUnitID(gLandingShip2)) + " Transport Plan, ", cPlanTransport);
      aiPlanSetVariableInt(transportPlan2ID, cTransportPlanTransportID, 0, gLandingShip2);
      aiPlanSetVariableInt(transportPlan2ID, cTransportPlanTransportTypeID, 0, kbUnitGetProtoUnitID(gLandingShip2));
      aiPlanAddUnitType(transportPlan2ID, kbUnitGetProtoUnitID(gLandingShip2), 1, 1, 1);
      if (aiPlanAddUnit(transportPlan2ID, gLandingShip2) == false)
      {
         aiPlanDestroy(transportPlan2ID);
         return;
      }
      aiPlanSetVariableVector(transportPlan2ID, cTransportPlanGatherPoint, 0, pickupPoint);
      aiPlanSetVariableVector(transportPlan2ID, cTransportPlanTargetPoint, 0, gAmphibiousAssaultTarget);
      aiPlanSetVariableBool(transportPlan2ID, cTransportPlanReturnWhenDone, 0, false);
      aiPlanSetVariableBool(transportPlan2ID, cTransportPlanPersistent, 0, false);
      aiPlanSetVariableBool(transportPlan2ID, cTransportPlanMaximizeXportMovement, 0, true);
      aiPlanSetVariableInt(transportPlan2ID, cTransportPlanPathType, 0, cTransportPathTypePoints);

      aiPlanSetRequiresAllNeedUnits(transportPlan2ID, true);
      aiPlanSetDesiredPriority(transportPlan2ID, 100);
   }


   if (gLandingShip2 < 0)
   {
      aiPlanAddUnitType(transportPlanID, cUnitTypeLogicalTypeLandMilitary, landingForcesSize, landingForcesSize, landingForcesSize);
   }
   else
   {
      aiPlanAddUnitType(transportPlanID, cUnitTypeLogicalTypeLandMilitary, landingForcesSize*0.5, landingForcesSize*0.5, landingForcesSize*0.5);
      aiPlanAddUnitType(transportPlan2ID, cUnitTypeLogicalTypeLandMilitary, landingForcesSize*0.5, landingForcesSize*0.5, landingForcesSize*0.5);
   }

   for (i = 0; < landingForcesSize)
   {  // If we only have 1 ship, everyone boards that ship. Otherwise split 50/50
      tempLandUnit = kbUnitQueryGetResult(landingForcesQuery, i);
      if (gLandingShip2 < 0)
      {
         //aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
         aiPlanAddUnit(transportPlanID, tempLandUnit);
      }
      else
      {
         if (i < 0.5 * landingForcesSize)
         {
            //aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
            aiPlanAddUnit(transportPlanID, tempLandUnit);
         }
         else
         {
            //aiTaskUnitWork(tempLandUnit, gLandingShip2, true);
            aiPlanAddUnit(transportPlan2ID, tempLandUnit);
         }
      }
   }

   aiPlanSetActive(transportPlanID);
   if (transportPlan2ID > 0)
   {
      aiPlanSetActive(transportPlan2ID);
   }

   if (transportPlanID > 0 || transportPlan2ID > 0)
   {
      gAmphibiousAssaultStage = cLandForces;
   }

   // Now check to see if we're all loaded up (within a couple units)
   /*unitsOnShip1 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip1), 1.0);
   if (ship2 > 0)
   {
      unitsOnShip2 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip2), 1.0);
   }

   aiChat(1, "Units on ship 1: " + unitsOnShip1 + " Ship 2: " + unitsOnShip2);
   if (unitsOnShip1 + unitsOnShip2 > landingForcesSize * 0.95)
   {
      gAmphibiousAssaultStage = cLandForces;
   }*/

   return;
}


//==============================================================================
// Drops off the transport
// 
//==============================================================================
void landForces()
{
   // For the method using transport plans. See if there are any units at the landing spot
   if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, gAmphibiousAssaultTarget, 30) > 3)
   {
      gAmphibiousAssaultStage = cBuildForwardBuildings;
   }
   return;

   /*

   // Check if we're done transporting
   int unitsOnShip1 = 0;
   int unitsOnShip2 = 0; 

   unitsOnShip1 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip1), 1.0);
   
   if (gLandingShip2 > 0)
   {
      unitsOnShip2 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip2), 1.0);
   }

   if (unitsOnShip1 + unitsOnShip2 == 0)
   {  // Done transporting, move to next phase
      gAmphibiousAssaultStage = cBuildForwardBuildings;
      aiPlanDestroy(gAmphibiousTransportPlan);
      return;
   }


   // Transport part
   vector dropoff = cInvalidVector;
   vector shipLoc = cInvalidVector;

   if (unitsOnShip1 > 0)
   {
      shipLoc = kbUnitGetPosition(gLandingShip1);
      dropoff = getDropoffPoint(shipLoc, gAmphibiousAssaultTarget, 0);
      if (distance(dropoff, shipLoc) < 5)
      {
         aiTaskUnitEject(gLandingShip1);
      }
      else
      {
         aiTaskUnitMove(gLandingShip1, dropoff);
      }
   }

   if (unitsOnShip2 > 0)
   {
      shipLoc = kbUnitGetPosition(gLandingShip2);
      dropoff = getDropoffPoint(shipLoc, gAmphibiousAssaultTarget, 0);
      if (distance(dropoff, shipLoc) < 5)
      {
         aiTaskUnitEject(gLandingShip2);
      }
      else
      {
         aiTaskUnitMove(gLandingShip2, dropoff);
      }
   }
*/
   // Add something to move the ship around if it can't reach the dropoff?

}


//==============================================================================
// Uses Galleons to train Units 
// 
//==============================================================================
void trainFromGalleons()
{
   aiChat(1, "training from galleon");
   int frNavySize = aiPlanGetNumberUnits(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip);
   int unitID = -1;
   int puid = -1;
   vector tempShipPosition = cInvalidVector;
   vector trainPosition = cInvalidVector;
   int unitToTrain = -1;

   // Find a suitable unit to train. Just anything for now
   for (i = 0; < gNumArmyUnitTypes)
   {
      unitToTrain = kbUnitPickGetResult(gLandUnitPicker, i);
      if (kbProtoUnitIsType(unitToTrain, cUnitTypeAbstractArtillery) == false)
      {
         break;
      }
   }

   // Create a maintain plan
   if (gAmphibiousTrainPlan < 0)
   {
      gAmphibiousTrainPlan = createSimpleMaintainPlan(unitToTrain, 20, false, -1, 1);
      aiPlanSetDesiredResourcePriority(gAmphibiousTrainPlan, 90);
      aiPlanSetVariableInt(gAmphibiousTrainPlan, cTrainPlanBuildFromType, 0, gGalleonUnit);
      aiPlanSetVariableVector(gAmphibiousTrainPlan, cTrainPlanGatherPoint, 0, gAmphibiousAssaultTarget);
   }
   
   // Keep the galleons close
   for (i = 0; < frNavySize)
   {
      unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
      puid = kbUnitGetProtoUnitID(unitID);
      if (puid == gGalleonUnit)
      {
         // make sure it's close enough
         tempShipPosition = kbUnitGetPosition(unitID);
         trainPosition = getDropoffPoint(tempShipPosition, gAmphibiousAssaultTarget, 0);
         if (distance(tempShipPosition, trainPosition) > 4)
         {
            aiTaskUnitMove(unitID, trainPosition);
         }
         else if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(unitID), 1.0) > 2)
         {
            aiTaskUnitEject(unitID);
         }
         /*else
         {
            aiTaskUnitTrain(unitID, unitToTrain);
         }*/
      }
   }
   return;
}


//==============================================================================
// Build some towers first
// 
//==============================================================================
void buildForwardTowers()
{
   int towerCount = kbUnitCount(cMyID, gTowerUnit, cUnitStateABQ);
   int towerBuildLimit = kbGetBuildLimit(cMyID, gTowerUnit);
   int towersToBuild = 0;
   int planID = -1;
   int vilQuery = -1;
   int numberVil = 0;

   if (towerBuildLimit - towerCount >= 3)
   {
      towersToBuild = 3;
   }
   else
   {
      towersToBuild = towerBuildLimit - towerCount;
   }

   if (towersToBuild <= 0)
   {
      // Can't do anything, go to next phase
      gAmphibiousAssaultStage = cEstablishForwardBase;
      return;
   }

   // Try to find nearby villagers to use
   vilQuery = createSimpleUnitQuery(gEconUnit, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 40);
   numberVil = kbUnitQueryExecute(vilQuery);
   

   planID = createLocationBuildPlan(gTowerUnit, towersToBuild, 100, true, -1, gAmphibiousAssaultTarget, numberVil);
   for (i = 0; < numberVil)
   {  // Add forward villagers
      aiPlanAddUnit(planID, kbUnitQueryGetResult(vilQuery, i));
   }

   // Check if we have a tower built. If so, move to next stage
   /*if (getUnitCountByLocation(gTowerUnit, cPlayerRelationSelf,
               cUnitStateAlive, gAmphibiousAssaultTarget, 40) > 0)
   {
      gAmphibiousAssaultStage = cEstablishForwardBase;
   }*/

   // Move on as long as the plan takes
   if (planID > 0)
   {
      gAmphibiousAssaultStage = cEstablishForwardBase;
   }
   
   return;
}


//==============================================================================
// amphibiousAssault
// Tentative plan:
//   Create stages
//      Gather Navy              first draft done
//      Bombard Coast            first draft done
//      Load Forces              first draft done 
//      Land Forces              first draft done
//      Build forward buildings
//      Establish forward base
//
// Notes:
//    transports need to be left alone (bombard plan keeps stealing them)
//    bombard stage ends too fast (make sure we have ships at the location)
//    transport may not be working yet
//    go through each stage, adding location pings
//    needs to transport villagers also
//    change minimum ship number to a value
//
//==============================================================================
void amphibiousAssault(vector location = cInvalidVector)
{
   // test the location
   if (location == cInvalidVector)
   {
      return;
   }
   // Reset the stage
   gAmphibiousAssaultStage = cGatherNavy;
   gAmphibiousAssaultTarget = getDropoffPoint(kbBaseGetLocation(cMyID, kbBaseGetMain(cMyID)), location);

   if (gAmphibiousAssaultPlan < 0)
   {
      gAmphibiousAssaultPlan = aiPlanCreate("Amphibious Assault Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAmphibiousAssaultPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousAssaultPlan, 99); // Only lower than transport
      aiPlanSetActive(gAmphibiousAssaultPlan);
   }

   if (gAmphibiousArmyPlan < 0)
   {
      gAmphibiousArmyPlan = aiPlanCreate("Amphibious Assault Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousArmyPlan, cUnitTypeLogicalTypeLandMilitary, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAmphibiousArmyPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousArmyPlan, 99); // Only lower than transport
      aiPlanSetActive(gAmphibiousArmyPlan);
   }

   if (gAmphibiousTransportPlan < 0)
   {
      gAmphibiousTransportPlan = aiPlanCreate("Amphibious Transport Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousTransportPlan, cUnitTypeAbstractWarShip, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAmphibiousTransportPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousTransportPlan, 99); // Only lower than transport
      aiPlanSetActive(gAmphibiousTransportPlan);
   }

   // Enable the rule to monitor the amphibious assault
   aiChat(1, "Amphibious Assault Rule Started");
   xsEnableRule("amphibiousAssaultRule");
}

//==============================================================================
/* amphibiousAssault
   AssertiveWall: rule to keep track of the current state of the 
                  amphibious assault
*/
//==============================================================================

rule amphibiousAssaultRule
inactive
minInterval 5
{
   /*
      cNavyRetreat = -1;             // Retreat
      cGatherNavy = 0;               // First stage, gather up the navy for the assault
      cBombardCoast = 1;             // Second Stage, attack the coast
      cLoadForces = 2                // Third Stage, load the army
      cLandForces = 3;               // Fourth Stage, try and land an army
      cBuildForwardBuildings = 4;    // Fifth Stage, move vills in to build
      cEstablishForwardBase = 5;     // Sixth stage, build a whole FB
   */

   // First check to see if we're losing
   if (retreatCheck() == true)
   {
      xsDisableSelf();
      aiChat(1, "Amphibious Assault Aborted");
      return;
   }

   // Used by multiple rules
   vector gatherPoint = gNavyVec;//getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMain(cMyID)));
   vector pickupPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMain(cMyID)), 4);

   switch (gAmphibiousAssaultStage)
   {
      case cGatherNavy:
      {
         aiChat(1, "Gathering Navy for amphibious assault");
         sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, gatherPoint);
         // Add navy to plan and send them to the gather point
         gatherNavy(gatherPoint);
         gatherArmy(pickupPoint);

         break;
      }
      case cBombardCoast:
      {
         aiChat(1, "Bombarding Landing Location");
         sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, gAmphibiousAssaultTarget);
         gatherNavy();

         bombardCoast();
         break;
      }
      case cLoadForces:
      {
         sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, pickupPoint);
         sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, gAmphibiousAssaultTarget);

         bombardCoast(); // Keep bombarding the coast
         gatherNavy();   // Keep adding navy units to the plan
         
         loadForces(pickupPoint);
         aiChat(1, "Loading Ship1: " + gLandingShip1 + " Ship2: " + gLandingShip2);
         break;
      }
      case cLandForces:
      {
         aiChat(1, "Attempting to Land Forces");
         sendStatement(cPlayerRelationAny, cAICommPromptToAllyIWillBuildMilitaryBase, gAmphibiousAssaultTarget);

         bombardCoast(); // Keep bombarding the coast
         gatherNavy();   // Keep adding navy units to the plan

         landForces();
         break;
      }
      case cBuildForwardBuildings:
      {
         aiChat(1, "Establishing Foothold");
         bombardCoast(); // Keep bombarding the coast
         gatherNavy();   // Keep adding navy units to the plan

         trainFromGalleons();
         buildForwardTowers();
         break;
      }
      case cEstablishForwardBase:
      {
         // Once we're established we can let our navy do other things, except galleons
         trainFromGalleons();
         aiChat(1, "Creating Forward Base");
         break;
      }
   }
}


//==============================================================================
// establishForwardBeachHead
// Also launches a land attack on the forward base position
// Tries to establish several buildings
//==============================================================================
void establishForwardBeachHead(vector location = cInvalidVector)
{
   //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillAttackWithYou, location);
   // Get the desired army/navy Size, increasing by age
   int armyMin = 1;
   int armyDesired = 10;
   int navyMin = 0;
   int navyDesired = 1;
   if (kbGetAge() > cAge3)
   {
      armyMin = 10;
      armyDesired = 20;
      navyMin = 0;
      navyDesired = 2;
   }
   if (kbGetAge() > cAge4)
   {
      armyMin = 18;
      armyDesired = 35;
      navyMin = 0;
      navyDesired = 3;
   }

   // Create the attack plan for the forward base
   int beachheadPlanID = aiPlanCreate("Assault the Beachhead", cPlanCombat);
   //aiPlanAddUnitType(beachheadPlanID, cUnitTypeAbstractWarShip, navyMin, navyDesired, 5);
   aiPlanAddUnitType(beachheadPlanID, cUnitTypeLogicalTypeLandMilitary, armyMin, armyDesired, 99);
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
   //aiPlanSetVariableInt(beachheadPlanID, cCombatPlanTargetPlayerID, 0, navalTargetPlayer);
   aiPlanSetVariableVector(beachheadPlanID, cCombatPlanTargetPoint, 0, location);
   aiPlanSetVariableVector(beachheadPlanID, cCombatPlanGatherPoint, 0, gNavyVec);
   aiPlanSetVariableFloat(beachheadPlanID, cCombatPlanGatherDistance, 0, 80.0); // Big gather radius to include army
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternBest);
   aiPlanSetDesiredPriority(beachheadPlanID, 99); // Super high for testing


   // AssertiveWall: Never bring any extra people on these to avoid transport issues. Balanced refresh frequency
   //aiPlanSetVariableBool(beachheadPlanID, cCombatPlanAllowMoreUnitsDuringAttack, 0, true);
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanRefreshFrequency, 0, 700);

   // Done when we retreat, retreat when outnumbered, done when there's no target after 20 seconds
   // The army should remain at the forward base after it's done
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeNoTarget);
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
   aiPlanSetVariableInt(beachheadPlanID, cCombatPlanNoTargetTimeout, 0, 2*60*1000);
   aiPlanSetBaseID(beachheadPlanID, gForwardBaseID);
   aiPlanSetInitialPosition(beachheadPlanID, gNavyVec);

   aiPlanSetActive(beachheadPlanID);

   // Move the defense reflex to the new forward base. This should happen eventually anyway, but we do it early here
   moveDefenseReflex(location, 50.0, gForwardBaseID);

   // Make several build plans at once, to make a quick forward base
   int building0 = xsArrayGetInt(gMilitaryBuildings, 0);  // typically barracks
   int building1 = xsArrayGetInt(gMilitaryBuildings, 1);  // typically stable
   int barracksNum = 1;
   int stableNum = 2;
   if (btBiasInf >= btBiasCav)
   {
      barracksNum = 2;
      stableNum = 1;
   }
   //createSimpleBuildPlan(building0, barracksNum, 100, false, cMilitaryEscrowID, gForwardBaseID, 2, -1, true);
   //createSimpleBuildPlan(building1, stableNum, 100, false, cMilitaryEscrowID, gForwardBaseID, 2, -1, true);
   createSimpleBuildPlan(building0, 1, 100, true, cEconomyEscrowID, gForwardBaseID, 1, -1, true);
   createSimpleBuildPlan(building1, 1, 100, true, cEconomyEscrowID, gForwardBaseID, 1, -1, true);
   createSimpleBuildPlan(gTowerUnit, 1, 100, true, cEconomyEscrowID, gForwardBaseID, 1, -1, true);

   //createLocationBuildPlan(building0, barracksNum, 100, false, cMilitaryEscrowID, location, 2);
   //createLocationBuildPlan(building1, stableNum, 100, false, cMilitaryEscrowID, location, 2);

}



//==============================================================================
// selectForwardBaseBeachHead
// Based on selectForwardBaseLocation, this function grabs a forward base
// location on the opponent's island
//
// Also launches a land and naval attack on that position
//==============================================================================
vector selectForwardBaseBeachHead(void)
{
   vector retVal = cInvalidVector;
   vector mainBaseVec = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   vector v = cInvalidVector; // Scratch variable for intermediate calcs.

   debugBuildings("Selecting forward beachhead");
   // Will be used to determine how far out we should put the fort on the line from our base to enemy TC.
   float distanceMultiplier = 0.5; 
   float dist = 0.0;
   int enemyPlayer = aiGetMostHatedPlayerID();

   int enemyTC = getUnitByLocation(cUnitTypeAgeUpBuilding, enemyPlayer, cUnitStateABQ, mainBaseVec, 500.0);
   float radius = 0.0;
   vector vec = cInvalidVector;
   vector bestLoc = cInvalidVector;
   float bestDist = 0.0;
   int enemyBuildingQuery = createSimpleUnitQuery(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateABQ);
   int numberFound = kbUnitQueryExecute(enemyBuildingQuery);

   if (enemyTC < 0)
   {
      v = guessEnemyLocation(enemyPlayer);
      radius = 100.0;
      if (getUnitCountByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, enemyPlayer, cUnitStateAlive, v, radius) == 0)
      {
         return (cInvalidVector);
      }
   }
   else // Enemy TC found.
   {
      v = kbUnitGetPosition(enemyTC); // Vector from main base to enemy TC.
      radius = 50.0 + kbBaseGetDistance(enemyPlayer, kbUnitGetBaseID(enemyTC));
   }

   // Find the best location within 180 degrees. (expanded from 90)
   vec = xsVectorNormalize(mainBaseVec - v) * radius;
   for (i = 0; < 4)
   {
      vector tempLoc = rotateByReferencePoint(v, vec, aiRandFloat(0.0 - PI * 0.5, PI * 0.5));
      float maxDist = 1000.0;
      int areaID = kbAreaGetIDByPosition(tempLoc);
      // Ensure we are inside the map.
      if (areaID < 0)
      {
         continue;
      }
      if (kbAreaGetNumberTiles(areaID) == kbAreaGetNumberBlackTiles(areaID))
      {
         continue;
      }
      for (j = 0; < numberFound)
      {
         int buildingID = kbUnitQueryGetResult(enemyBuildingQuery, j);
         dist = distance(kbUnitGetPosition(buildingID), tempLoc);
         if (maxDist > dist)
         {
            maxDist = dist;
         }
      }
      if (bestDist < maxDist)
      {
         bestLoc = tempLoc;
         bestDist = maxDist;
      }
   }

   if (bestLoc != cInvalidVector)
   {
      retVal = bestLoc;
      // Now, make sure it's on the same areagroup (as the enemy), back up if it isn't.
      dist = distance(v, retVal);
      int mainAreaGroup = kbAreaGroupGetIDByPosition(v);
      vector delta = mainBaseVec - retVal; 
      int step = 0;
      bool siteFound = false;

      delta *= 30.0 / xsVectorLength(delta);

      if (dist > 0.0)
      {
         for (step = 0; < 9)
         {
            debugBuildings("    " + retVal + " is in area group " + kbAreaGroupGetIDByPosition(retVal));
            siteFound = true;
            // Don't build too close to any enemy building.
            if (getUnitByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateABQ, retVal, 60.0) >= 0)
            {
               siteFound = false;
            }
            else if (mainAreaGroup != kbAreaGroupGetIDByPosition(retVal))
            {
               siteFound = false;
            }
            else
            { // DONE!
               debugBuildings("Good location found");
               break;
            }
            retVal = retVal + delta; // Move 1/10 of way back to main base, try again.
         }
      }
   }

   if (siteFound == false)
   {
      retVal = cInvalidVector;
   }
   debugBuildings("    New forward base location will be " + retVal);
   return (retVal);
}


//###############################################################################
//###############################################################################
//###############################################################################

// Military attack plan replacements

//###############################################################################
//###############################################################################
//###############################################################################

//==============================================================================
// getAreaValue
//==============================================================================
int getAreaValue(vector locationOfInterest = cInvalidVector, int searchRadius = 0, int playerRelation = cPlayerRelationEnemyNotGaia)
{
   //int baseID = kbBaseGetIDByIndex(player, baseIndex);
   int numberFound = 0;
   int numberEnemyFound = 0;
   int unitID = 0;
   int puid = 0;
   int baseAssets = 0;

   int baseQuery = kbUnitQueryCreate("areaQuery");
   kbUnitQuerySetIgnoreKnockedOutUnits(baseQuery, true);

   kbUnitQuerySetPlayerRelation(baseQuery, playerRelation);
   kbUnitQuerySetState(baseQuery, cUnitStateABQ);
   kbUnitQuerySetPosition(baseQuery, locationOfInterest);
   kbUnitQuerySetMaximumDistance(baseQuery, searchRadius);
   kbUnitQuerySetUnitType(baseQuery, cUnitTypeHasBountyValue);
   kbUnitQueryResetResults(baseQuery);
   numberFound = kbUnitQueryExecute(baseQuery);

   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(baseQuery, i);
      puid = kbUnitGetProtoUnitID(unitID);
      switch (puid)
      {
         case cUnitTypeypKingsHill:
         {
            baseAssets = baseAssets + 1600.0;
            break;
         }
         case cUnitTypeTownCenter:
         case cUnitTypedeSPCCommandPost:
         {
            baseAssets = baseAssets + 1000.0;
            break;
         }
         // Buildings generating resources.
         case cUnitTypeBank:
         {
            baseAssets = baseAssets + 800.0;
            break;
         }
         case cUnitTypeFactory:
         {
            baseAssets = baseAssets + 1600.0;
            break;
         }
         case cUnitTypeypWCPorcelainTower2:
         {
            baseAssets = baseAssets + 800.0;
            break;
         }
         case cUnitTypeypWCPorcelainTower3:
         {
            baseAssets = baseAssets + 1200.0;
            break;
         }
         case cUnitTypeypWCPorcelainTower4:
         case cUnitTypeypWCPorcelainTower5:
         {
            baseAssets = baseAssets + 1600.0;
            break;
         }
         case cUnitTypeypShrineJapanese:
         {
            baseAssets = baseAssets + 200.0;
            break;
         }
         case cUnitTypeypWJToshoguShrine2:
         case cUnitTypeypWJToshoguShrine3:
         case cUnitTypeypWJToshoguShrine4:
         case cUnitTypeypWJToshoguShrine5:
         {
            baseAssets = baseAssets + 400.0;
            break;
         }
         case cUnitTypedeHouseInca:
         case cUnitTypedeTorp:
         {
            baseAssets = baseAssets + 200.0;
            break;
         }
         case cUnitTypedeMountainMonastery:
         case cUnitTypedeUniversity:
         {
            baseAssets = baseAssets + 300.0;
            break;
         }
         // Buildings automatically creating military units.
         case cUnitTypeypWCSummerPalace2:
         case cUnitTypeypWCSummerPalace3:
         case cUnitTypeypWCSummerPalace4:
         case cUnitTypeypWCSummerPalace5:
         case cUnitTypeypDojo:
         {
            baseAssets = baseAssets + 1200.0;
            break;
         }
         // Buildings with HC drop off point.
         case cUnitTypeFortFrontier:
         case cUnitTypeOutpost:
         case cUnitTypeBlockhouse:
         case cUnitTypeNoblesHut:
         case cUnitTypeypWIAgraFort2:
         case cUnitTypeypWIAgraFort3:
         case cUnitTypeypWIAgraFort4:
         case cUnitTypeypWIAgraFort5:
         case cUnitTypeypCastle:
         case cUnitTypeYPOutpostAsian:
         case cUnitTypedeIncaStronghold:
         case cUnitTypedeTower:
         // Military buildings.
         case cUnitTypeBarracks:
         case cUnitTypeStable:
         case cUnitTypeArtilleryDepot:
         case cUnitTypeCorral:
         case cUnitTypeypWarAcademy:
         case cUnitTypeYPBarracksIndian:
         case cUnitTypeypCaravanserai:
         case cUnitTypeypBarracksJapanese:
         case cUnitTypeypStableJapanese:
         case cUnitTypedeKallanka:
         case cUnitTypedeWarCamp:
         case cUnitTypedeHospital:
         case cUnitTypedeCommandery:
         {
            baseAssets = baseAssets + 100.0;
            break;
         }
         case cUnitTypedePalace:
         {
            baseAssets = baseAssets + 200.0;
            break;
         }
         // Villagers.
         case cUnitTypeSettlerWagon:
         {
            baseAssets = baseAssets + 400.0;
            break;
         }
         case cUnitTypeSettler:
         case cUnitTypeCoureur:
         case cUnitTypeCoureurCree:
         case cUnitTypeSettlerNative:
         case cUnitTypeypSettlerAsian:
         case cUnitTypeypSettlerIndian:
         case cUnitTypeypSettlerJapanese:
         case cUnitTypedeSettlerAfrican:
         {
            baseAssets = baseAssets + 200.0;
            break;
         }
         default:
         {
            if (kbUnitIsType(unitID, cUnitTypeTradingPost) == true)
            {
               if (kbUnitGetSubCiv(unitID) >= 0)
               {
                  baseAssets += 400.0;
               }
               else // Trade route trading post.
               {
                  baseAssets += 1600.0;
               }
            }
            break;
         }
      }
   }

   return baseAssets;
}


//==============================================================================
// getAreaStrength
//==============================================================================
int getAreaStrength(vector locationOfInterest = cInvalidVector, int searchRadius = 0, int playerRelation = cPlayerRelationEnemyNotGaia)
{
   int MilitaryPower = 0;
   int numberEnemyFound = 0;
   int unitID = -1;
   int puid = -1;

   int baseEnemyQuery = kbUnitQueryCreate("areaEnemyUnitQuery");
   kbUnitQuerySetIgnoreKnockedOutUnits(baseEnemyQuery, true);

   kbUnitQuerySetPlayerRelation(baseEnemyQuery, cPlayerRelationEnemyNotGaia);
   kbUnitQuerySetState(baseEnemyQuery, cUnitStateABQ);
   kbUnitQuerySetPosition(baseEnemyQuery, locationOfInterest);
   kbUnitQuerySetMaximumDistance(baseEnemyQuery, searchRadius + 10.0);

   kbUnitQuerySetUnitType(baseEnemyQuery, cUnitTypeLogicalTypeLandMilitary);
   kbUnitQueryResetResults(baseEnemyQuery);
   numberEnemyFound = kbUnitQueryExecute(baseEnemyQuery);

   for (i = 0; < numberEnemyFound)
   {
      unitID = kbUnitQueryGetResult(baseEnemyQuery, i);
      puid = kbUnitGetProtoUnitID(unitID);
      MilitaryPower = MilitaryPower + getMilitaryUnitStrength(puid);
   }
   return MilitaryPower;
}

//==============================================================================
// findOffensiveTargetLocation
// 
// Look for potential locations that may serve as an offensive target
//
//==============================================================================
vector findOffensiveTargetLocation(int companyPlan = -1)
{
   int target = 0;
   vector targetLoc = cInvalidVector;
   vector companyLocation = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0)); // Grab the location of the first unit

   target = getUnitByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationEnemyNotGaia, cUnitStateAlive, companyLocation, 100.0);
   
   if (target > 0)
   {
      targetLoc = kbUnitGetPosition(target);
   }
   else
   {  // Advance toward enemy base
      vector enemyLoc = guessEnemyLocation();
      vector vec = xsVectorNormalize(enemyLoc - companyLocation);
      float advanceDist = 50;
      targetLoc = enemyLoc + vec * advanceDist;
   }
   
   
   return targetLoc;
}

//==============================================================================
// findDefensiveTargetLocation
// 
// Look for potential locations that may serve as an offensive target
//
//==============================================================================
vector findDefensiveTargetLocation(int companyPlan = -1)
{
   int target = 0;
   vector targetLoc = cInvalidVector;
   vector companyLocation = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0)); // Grab the location of the first unit

   target = getUnitByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationAlly, cUnitStateAlive, companyLocation, 100.0);
   targetLoc = kbUnitGetPosition(target);
   return targetLoc;
}

//==============================================================================
// getFriendlyArmyValue
// 
// Look for potential locations that may serve as an offensive target
//
//==============================================================================
int getFriendlyArmyValue(int companyPlan = -1)
{
   int unitID = -1;
   int puid = -1;
   int armyPower = 0;
   int numberUnits = aiPlanGetNumberUnits(companyPlan, cUnitTypeLogicalTypeLandMilitary);

   for (i = 0; < numberUnits)
   {
      unitID = aiPlanGetUnitByIndex(companyPlan, i);
      puid = kbUnitGetProtoUnitID(unitID);
      armyPower = armyPower + getMilitaryUnitStrength(puid);
   }
   return armyPower;
}

//==============================================================================
// assault
// 
// set the plan to assault a point location
//
//==============================================================================
void assault(int companyPlan = -1, vector targetLocation = cInvalidVector)
{
   vector gatherPoint = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0));

   aiPlanSetVariableInt(companyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);

   // Only point attacks. Base assault handled separately
   aiPlanSetVariableInt(companyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

   //aiPlanSetVariableInt(companyPlan, cCombatPlanTargetPlayerID, 0, targetPlayer);
   //aiPlanSetVariableVector(companyPlan, cCombatPlanTargetPoint, 0, baseLocation);
   aiPlanSetVariableVector(companyPlan, cCombatPlanGatherPoint, 0, gatherPoint);
   aiPlanSetVariableFloat(companyPlan, cCombatPlanGatherDistance, 0, 40.0);

   // Take the best route
   aiPlanSetVariableInt(companyPlan, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternBest);

   // Retreat when outnumbered
   aiPlanSetVariableInt(companyPlan, cCombatPlanRefreshFrequency, 0, 300);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);

   // This isn't a base attack, so default to being done once there's no target
   aiPlanSetVariableInt(companyPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | aiPlanGetVariableInt(companyPlan, cCombatPlanDoneMode, 0));
   aiPlanSetVariableInt(companyPlan, cCombatPlanNoTargetTimeout, 0, 30000);

   //aiPlanSetBaseID(companyPlan, mainBaseID);
   aiPlanSetInitialPosition(companyPlan, gatherPoint);

   addUnitsToMilitaryPlan(companyPlan);

   //aiPlanSetDesiredPriority(companyPlan, 60);
   aiPlanSetActive(companyPlan);
   return;
}

//==============================================================================
// raid
// 
// set the plan to raid a point location. The rule "callOffRaid" will cause the 
// plan to retreat when needed
//
//==============================================================================
void raid(int companyPlan = -1, vector targetLocation = cInvalidVector)
{
   vector gatherPoint = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0));

   aiPlanSetVariableInt(companyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);

   // Only point attacks. Base assault handled separately
   aiPlanSetVariableInt(companyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

   //aiPlanSetVariableInt(companyPlan, cCombatPlanTargetPlayerID, 0, targetPlayer);
   //aiPlanSetVariableVector(companyPlan, cCombatPlanTargetPoint, 0, baseLocation);
   aiPlanSetVariableVector(companyPlan, cCombatPlanGatherPoint, 0, gatherPoint);
   aiPlanSetVariableFloat(companyPlan, cCombatPlanGatherDistance, 0, 40.0);

   // Take random route
   aiPlanSetVariableInt(companyPlan, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);

   // Retreat when outnumbered
   aiPlanSetVariableInt(companyPlan, cCombatPlanRefreshFrequency, 0, 300);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);

   // This isn't a base attack, so default to being done once there's no target
   aiPlanSetVariableInt(companyPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | aiPlanGetVariableInt(companyPlan, cCombatPlanDoneMode, 0));
   aiPlanSetVariableInt(companyPlan, cCombatPlanNoTargetTimeout, 0, 30000);

   //aiPlanSetBaseID(companyPlan, mainBaseID);
   aiPlanSetInitialPosition(companyPlan, gatherPoint);

   addUnitsToMilitaryPlan(companyPlan);

   //aiPlanSetDesiredPriority(companyPlan, 60);
   aiPlanSetActive(companyPlan);

   gActiveRaid = companyPlan;
   gRaidGatherPoint = gatherPoint;
   gRaidStartTime = xsGetTime();
   
   xsEnableRule("callOffRaid");
   return;
}

//==============================================================================
// callOffRaid
//
// Rule that monitors the raid and calls it off when anything looks sour, or
// when time goes on too long
// 
//==============================================================================
rule callOffRaid
inactive
minInterval 10 
{
   int currentTime = xsGetTime();
   bool callOff = false;
   vector unitLocation = kbUnitGetPosition(aiPlanGetUnitByIndex(gActiveRaid, 0));
   int enemyStrength = getAreaStrength(unitLocation, 40.0, cPlayerRelationEnemyNotGaia);
   int friendlyStrength = getFriendlyArmyValue(gActiveRaid);

   // Call off raid after too much time passes
   if (currentTime > gRaidStartTime + 2 * 60 * 1000)
   {
      callOff = true;
   }
   else if (friendlyStrength < enemyStrength * 1.1)
   {
      callOff = true;
   }
   
   if (callOff == true)
   {
      aiPlanSetVariableInt(gActiveRaid, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);

      aiPlanSetVariableInt(gActiveRaid, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

      //aiPlanSetVariableInt(gActiveRaid, cCombatPlanTargetPlayerID, 0, targetPlayer);
      aiPlanSetVariableVector(gActiveRaid, cCombatPlanTargetPoint, 0, gRaidGatherPoint);
      //aiPlanSetVariableInt(gActiveRaid, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
      //aiPlanSetVariableInt(gActiveRaid, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | cCombatPlanDoneModeRetreat);
      //aiPlanSetVariableInt(gActiveRaid, cCombatPlanNoTargetTimeout, 0, 30000);
      aiPlanSetVariableInt(gActiveRaid, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      //aiPlanSetOrphan(gActiveRaid, true);

      addUnitsToMilitaryPlan(gActiveRaid);
      //aiPlanSetDesiredPriority(gActiveRaid, 60);
      aiPlanSetActive(gActiveRaid);

      xsDisableSelf();
   }
}

//==============================================================================
// interdict
// 
// set the plan to interdict starting at a location
//
//==============================================================================
void interdict(int companyPlan = -1, vector targetLocation = cInvalidVector)
{
   vector gatherPoint = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0));

   aiPlanSetVariableInt(companyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
   aiPlanSetVariableInt(companyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

   //aiPlanSetVariableInt(companyPlan, cCombatPlanTargetPlayerID, 0, targetPlayer);
   aiPlanSetVariableVector(companyPlan, cCombatPlanTargetPoint, 0, targetLocation);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
   //aiPlanSetVariableInt(companyPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | cCombatPlanDoneModeRetreat);
   //aiPlanSetVariableInt(companyPlan, cCombatPlanNoTargetTimeout, 0, 30000);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
   //aiPlanSetOrphan(companyPlan, true);

   addUnitsToMilitaryPlan(companyPlan);
   //aiPlanSetDesiredPriority(companyPlan, 60);
   aiPlanSetActive(companyPlan);
   
   gActiveInterdiction = companyPlan;
   xsEnableRule("interdictRule");
   return;
}

//==============================================================================
// block
//
// Set the company to defend a point, don't try to retreat unless outnumbered
// 
//==============================================================================
void block(int companyPlan = -1, vector targetLocation = cInvalidVector)
{
   vector gatherPoint = kbUnitGetPosition(aiPlanGetUnitByIndex(companyPlan, 0));

   aiPlanSetVariableInt(companyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
   aiPlanSetVariableInt(companyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

   //aiPlanSetVariableInt(companyPlan, cCombatPlanTargetPlayerID, 0, targetPlayer);
   aiPlanSetVariableVector(companyPlan, cCombatPlanTargetPoint, 0, targetLocation);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
   //aiPlanSetVariableInt(companyPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | cCombatPlanDoneModeRetreat);
   //aiPlanSetVariableInt(companyPlan, cCombatPlanNoTargetTimeout, 0, 30000);
   aiPlanSetVariableInt(companyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
   //aiPlanSetOrphan(companyPlan, true);

   addUnitsToMilitaryPlan(companyPlan);
   //aiPlanSetDesiredPriority(companyPlan, 60);
   aiPlanSetActive(companyPlan);

   return;
}

//==============================================================================
// interdictRule
//
// Rule that monitors the raid and calls it off when anything looks sour, or
// when time goes on too long
// 
//==============================================================================
rule interdictRule
inactive
minInterval 10 
{
   vector companyLoc = kbUnitGetPosition(aiPlanGetUnitByIndex(gActiveInterdiction, 0));
   bool fallBack = false;
   int enemyStrength = getAreaStrength(companyLoc, 20.0, cPlayerRelationEnemyNotGaia);
   int friendlyStrength = getFriendlyArmyValue(gActiveInterdiction);
   vector baseLoc = kbBaseGetLocation(cMyID, gMainBase);

   // fall back whenever too much military comes into range
   if (friendlyStrength < enemyStrength * 2)
   {
      fallBack = true;
      vector vec = xsVectorNormalize(baseLoc - companyLoc);
      float fallDist = xsVectorLength(baseLoc - companyLoc) * 0.9;
      vector fallBackLocation = baseLoc + vec * fallDist;
   }

   // Add something to move them closer to the enemy?
   
   if (fallBack == true)
   {
      aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);

      aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);

      //aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanTargetPlayerID, 0, targetPlayer);
      aiPlanSetVariableVector(gActiveInterdiction, cCombatPlanTargetPoint, 0, fallBackLocation);
      //aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
      //aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | cCombatPlanDoneModeRetreat);
      //aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanNoTargetTimeout, 0, 30000);
      aiPlanSetVariableInt(gActiveInterdiction, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      //aiPlanSetOrphan(gActiveInterdiction, true);

      addUnitsToMilitaryPlan(gActiveInterdiction);
      //aiPlanSetDesiredPriority(gActiveInterdiction, 60);
      aiPlanSetActive(gActiveInterdiction);
   }
   
   // If we get too close to base fall all the way back and defend the base
   if (distance(baseLoc, companyLoc) < 100.0)
   {
      block(gActiveInterdiction, baseLoc);
      xsDisableSelf();
   }

}

//==============================================================================
// decentralizedAttackManager
// Written/Edited by AssertiveWall
//
// This attack manager uses a decentralized concept to control multiple armies
// simultaneously, allowing each force to operate somewhat independantly under 
// an assigned task.
// 
//==============================================================================
rule decentralizedAttackManager
inactive
minInterval 30 // Big interval. It's all decentralized
{
   vector offensiveTargetLocationAlpha = cInvalidVector;
   vector offensiveTargetLocationBravo = cInvalidVector;

   vector defensiveTargetLocationAlpha = cInvalidVector;
   vector defensiveTargetLocationBravo = cInvalidVector;

   int areaValueAlpha = 0;
   int areaValueBravo = 0;

   int alphaArmyValue = 0;
   int bravoArmyValue = 0;

   int enMilitaryPowerAlpha = 0;
   int enMilitaryPowerBravo = 0;

   bool offenseAlpha = false;
   bool offenseBravo = false;

   bool defenseAlpha = false;
   bool defenseBravo = false;

   
   // Check for offensive targets
   offensiveTargetLocationAlpha = findOffensiveTargetLocation(gAlphaCompanyPlan); 
   //offensiveTargetLocationBravo = findOffensiveTargetLocation(gBravoCompanyPlan); 

   areaValueAlpha = getAreaValue(offensiveTargetLocationAlpha, 50.0, cPlayerRelationEnemyNotGaia);
   //areaValueBravo = getAreaValue(offensiveTargetLocationBravo, 50.0, cPlayerRelationEnemyNotGaia);
   
   enMilitaryPowerAlpha = getAreaStrength(offensiveTargetLocationAlpha, 50.0, cPlayerRelationEnemyNotGaia);
   //enMilitaryPowerBravo = getAreaStrength(offensiveTargetLocationBravo, 50.0, cPlayerRelationEnemyNotGaia);

   // Check for defensive targets
   defensiveTargetLocationAlpha = findDefensiveTargetLocation(gAlphaCompanyPlan);
   //defensiveTargetLocationBravo = findDefensiveTargetLocation(gBravoCompanyPlan);

   // Check our current strength
   alphaArmyValue = getFriendlyArmyValue(gAlphaCompanyPlan);
   //bravoArmyValue = getFriendlyArmyValue(gBravoCompanyPlan);

   // Select offense or defense
   // Bias for aggression, scale enemy military power by 1.2 for raid, 1.5 for assault
      if (alphaArmyValue > enMilitaryPowerAlpha * 1.2)
      {
         offenseAlpha = true;
      }
      else
      {
         defenseAlpha = true;
      }

      /*if (bravoArmyValue > enMilitaryPowerBravo * 1.2)
      {
         offenseBravo = true;
      }
      else
      {
         defenseBravo = true;
      }*/

   // Determine offensive task
      // Assault: Attempt to take the position and destroy everything there
      // Raid: Attack, cause some damage, and then bail
      if (offenseAlpha == true)
      {  
         if (alphaArmyValue > enMilitaryPowerAlpha * 1.5)
         {
               assault(gAlphaCompanyPlan, offensiveTargetLocationAlpha);
         }
         else
         {  // Only 1 raid at a time for code reasons
            if (gActiveRaid < 0)
            {
               raid(gAlphaCompanyPlan, offensiveTargetLocationAlpha);
            }
            else
            {
               defenseAlpha = true;
            }
         }
      }

      /*if (offenseBravo == true)
      {  
         if (bravoArmyValue > enMilitaryPowerBravo * 1.5)
         {
               assault(gBravoCompanyPlan, offensiveTargetLocationBravo);
         }
         else
         {  // Only 1 raid at a time for code reasons
            if (gActiveRaid < 0)
            {
               raid(gBravoCompanyPlan, offensiveTargetLocationBravo);
            }
            else
            {
               defenseBravo = true;
            }
         }
      }*/

   // Determine defensive task
      // Get the value of the area we are defending
      areaValueAlpha = getAreaValue(defensiveTargetLocationAlpha, 30.0, cPlayerRelationAlly);
      //areaValueBravo = getAreaValue(defensiveTargetLocationBravo, 30.0, cPlayerRelationAlly);

      // Block: Prevent the enemy from taking this location
      // Interdict: Slow the enemy down but don't decisively engage
      // Scout: Provide LOS but run away from enemies
      if (defenseAlpha == true)
      {
         if (areaValueAlpha > alphaArmyValue)
         {
            block(gAlphaCompanyPlan, defensiveTargetLocationAlpha);
         }
         else
         {
            interdict(gAlphaCompanyPlan, defensiveTargetLocationAlpha);
         }
      }

      /*if (defenseBravo == true)
      {
         if (areaValueBravo > bravoArmyValue)
         {
            block(gBravoCompanyPlan, defensiveTargetLocationBravo);
         }
         else
         {
            interdict(gBravoCompanyPlan, defensiveTargetLocationBravo);
         }
      }*/

   // Check current unit targets and tasks
      // 

   // Compare current task to new task and determine if we should assign new task
   

}


//==============================================================================
// shouldBuildDock
// AssertiveWall: Logic for when we should build a dock
//==============================================================================
bool shouldBuildDock()
{
   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   int towerCount = kbUnitCount(cMyID, gTowerUnit, cUnitStateAlive);
   int age = kbGetAge();
   int time = xsGetTime();

   // AssertiveWall: Hard and above on water spawn maps makes 2 docks Age 1 and 2, 4 Age 3 and above
   // Below Hard makes 1 and 2, respectfully
   // No dock building until age2 transition
   if ((((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 1)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 2) && (time > 6 * 60 * 1000)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 3) && (time > 12 * 60 * 1000)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gStartOnDifferentIslands == true) && (age >= cAge3)) && (dockCount < 4)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gStartOnDifferentIslands == true) && (age >= cAge4)) && (dockCount < 5)) ||
      ((cDifficultyCurrent < cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 1)) ||
      ((cDifficultyCurrent < cDifficultyHard) && ((gNavyMap == true) && (age >= cAge3)) && (dockCount < 2)) ||
      ((gTimeToFish == true) && (dockCount < 2)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && (age >= cAge4) && (dockCount < 3))) && 
      ((age >= cAge2 || agingUp() == true) && (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gDockUnit) <= 0)))
   {
      return true;
   }
   return false;
}


//==============================================================================
// cavalryCompany
// Written/Edited by AssertiveWall
//
// Manages cavalry separate from the main force. The cavalry should laways be 
// active in some capacity.
// 
// Steps:
// - Check for active defense or attack plans
// - Look for easy targets
// - Look for obvious raiding points
// - 
//
//==============================================================================
rule cavalryCompany
inactive
minInterval 15
{
   vector baseGatherPoint = kbBaseGetMilitaryGatherPoint(cMyID, kbBaseGetMainID(cMyID));
   int opportunityID = -1;
   int opportunityRange = distance(baseGatherPoint, guessEnemyLocation());
   int enemyStrength = 0;
   vector location = cInvalidVector;
   int friendlyStrength = getFriendlyArmyValue(gcavalryCompanyPlan);

   // First set up the persistent cavalry company plan
   if (gcavalryCompanyPlan < 0) // First run, create a persistent plan.
   {
      gcavalryCompanyPlan = aiPlanCreate("Persistent Cavalry Company", cPlanCombat);

      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanTargetPlayerID, 0, cMyID);
      aiPlanSetVariableVector(gcavalryCompanyPlan, cCombatPlanTargetPoint, 0, baseGatherPoint);
      aiPlanSetInitialPosition(gcavalryCompanyPlan, baseGatherPoint);
      aiPlanSetDesiredPriority(gcavalryCompanyPlan, 65);
      aiPlanSetVariableVector(gcavalryCompanyPlan, cCombatPlanGatherPoint, 0, baseGatherPoint);
      aiPlanSetVariableFloat(gcavalryCompanyPlan, cCombatPlanGatherDistance, 0, 40.0);  
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
      // Done when we retreat, retreat when outnumbered, done when there's no target after 10 seconds
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeNoTarget);
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      aiPlanSetVariableInt(gcavalryCompanyPlan, cCombatPlanNoTargetTimeout, 0, 10000);
      
      // All the cavalry
      aiPlanAddUnitType(gcavalryCompanyPlan, cUnitTypeAbstractCavalry, 0, 200, 200);
      
      aiPlanSetActive(gcavalryCompanyPlan);
   }

   // Check for if we are attacking or defending
   if (isDefendingOrAttacking() == true)
   {  // Drop the priority to allow other plans to steal from it
      aiPlanSetDesiredPriority(gcavalryCompanyPlan, 5);
   }
   else
   {  // Supposed to be higher than standard attack plans
      aiPlanSetDesiredPriority(gcavalryCompanyPlan, 65);
   }

   // Look for things to attack

   // Villagers
   if (opportunityID < 0)
   {
      opportunityID = getClosestUnitByLocation(cUnitTypeAbstractVillager, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
         baseGatherPoint, opportunityRange); 
      if (opportunityID > 0)
      {  // Find strength of nearby enemy
         location = kbUnitGetPosition(opportunityID);
         enemyStrength = getAreaStrength(location, 25.0, cPlayerRelationEnemyNotGaia);
         if (friendlyStrength < 2 * enemyStrength)
         {  // Reset if it's not good enough
            opportunityID = -1;
         }
      }
   }
   // Artillery in the Open
   if (opportunityID < 0)
   {
      opportunityID = getClosestUnitByLocation(cUnitTypeAbstractArtillery, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
         baseGatherPoint, opportunityRange); 
      if (opportunityID > 0)
      {  // Find strength of nearby enemy
         location = kbUnitGetPosition(opportunityID);
         enemyStrength = getAreaStrength(location, 25.0, cPlayerRelationEnemyNotGaia);
         if (friendlyStrength < 2 * enemyStrength)
         {  // Reset if it's not good enough
            opportunityID = -1;
         }
      }
   }
   // Trading posts
   if (opportunityID < 0)
   {
      opportunityID = getClosestUnitByLocation(cUnitTypeTradingPost, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
         baseGatherPoint, opportunityRange); 
      if (opportunityID > 0)
      {  // Find strength of nearby enemy
         location = kbUnitGetPosition(opportunityID);
         enemyStrength = getAreaStrength(location, 25.0, cPlayerRelationEnemyNotGaia);
         if (friendlyStrength < 3 * enemyStrength)
         {  // Reset if it's not good enough
            opportunityID = -1;
         }
      }
   }
   // Ports
   if (opportunityID < 0)
   {
      opportunityID = getClosestUnitByLocation(gDockUnit, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
         baseGatherPoint, opportunityRange); 
      if (opportunityID > 0)
      {  // Find strength of nearby enemy
         location = kbUnitGetPosition(opportunityID);
         enemyStrength = getAreaStrength(location, 25.0, cPlayerRelationEnemyNotGaia);
         if (friendlyStrength < 3 * enemyStrength)
         {  // Reset if it's not good enough
            opportunityID = -1;
         }
      }
   }


   if (opportunityID < 0)
   {
      return; // Return if there are no suitable targets
   }

   aiPlanSetVariableVector(gcavalryCompanyPlan, cCombatPlanTargetPoint, 0, location);




}



//==============================================================================
// AttritionAttackManager
// Written/Edited by AssertiveWall
//
// Takes the place of the regular attack manager. Instead of creating individual
// attacks against specific bases, this plan uses an attrition based strategy to
// incrementally take over the whole map before finally launching its final 
// assault on the base.
//
// Logic:
// AI breaks down the map into several sections
// Once the section is clear of enemy, the AI will either move it's forward base 
// there or position a tower for LOS.
// If enough areas are clear, the AI will expand it's main base
// 
//==============================================================================
rule AttritionAttackManager
inactive
minInterval 15
{
   int mainBaseID = kbBaseGetMainID(cMyID);
   static int currentPlayer = -1;
   static int currentBaseIndex = -1;

   // Don't attack under treaty or main base is under attack or we want to focus on aging up or if we already have an attack /
   // "real" defend plan.
   if ((aiTreatyActive() == true) || (gDefenseReflexBaseID == mainBaseID) || (aiPlanGetActualResourcePriority(gAgeUpResearchPlan) >= 52) ||
       (isDefendingOrAttacking() == true))
   {
      debugMilitary("Quiting attackManager early because we're not allowed to make a plan");
      debugMilitary("gDefenseReflexBaseID: " + gDefenseReflexBaseID + ", mainBaseID: " + mainBaseID);
      debugMilitary("gAgeUpResearchPlan prio: " + aiPlanGetActualResourcePriority(gAgeUpResearchPlan));
      debugMilitary("isDefendingOrAttacking: " + isDefendingOrAttacking());

      // Reset current player and base index if we are interrupted.
      if (currentPlayer >= 0 && currentBaseIndex >= 0)
      {
         currentPlayer = -1;
         currentBaseIndex = -1;
         xsSetRuleMinIntervalSelf(15);
      }

      // AssertiveWall: Check to see if the attack transport failed and keep going if it 
      // looks like it is (may not be the issue with attacks stallign in lategame)
      //if (gStartOnDifferentIslands == true)
      //{
       //  if (aiCheckAttackFailure() == false)
       //  {
            return;
       //  }
      //} 
   }

   static int baseQuery = -1;
   static int baseEnemyQuery = -1;
   bool defendingMonopoly = false;
   bool attackingMonopoly = false;
   bool defendingKOTH = false;
   bool attackingKOTH = false;
   int currentTime = xsGetTime();
   int numberUnits = 0;
   int numberFound = 0;
   int numberEnemyFound = 0;
   int numberBases = 0;
   int baseID = -1;
   vector mainBaseLocation = kbBaseGetLocation(cMyID, mainBaseID);
   int mainAreaGroup = kbAreaGroupGetIDByPosition(mainBaseLocation);
   int baseAreaGroup = -1;
   vector baseLocation = cInvalidVector;
   vector location = cInvalidVector;
   float baseDistance = 0.0;
   float armyPower = 0.0;
   float buildingPower = 0.0;
   float militaryPower = 0.0;
   float enemyMilitaryPower = 0.0;
   float affordable = 0.0;
   float baseAssets = 0.0;
   float distancePenalty = 0.0;
   float score = 0.0;
   bool isEnemy = false;
   bool isKOTH = false;
   bool isTradingPost = false;
   bool shouldAttack = false;
   int availableMilitaryPop = aiGetAvailableMilitaryPop();
   int unitID = -1;
   int puid = -1;
   float unitPower = 0.0;
   static int targetBaseID = -1;
   static vector targetBaseLocation = cInvalidVector;
   static int targetPlayer = 2;
   static bool targetIsEnemy = true;
   static bool targetShouldAttack = false;
   static float targetAffordable = 0.0;
   static float targetBaseAssets = 0.0;
   static float targetDistancePenalty = 0.0;
   static float targetScore = 0.0;
   float maxBaseAssets = 100.0;
   int planID = -1;
   bool isItalianWars = (cRandomMapName == "euItalianWars");
   bool isNorthernWars = (cRandomMapName == "eugreatnorthernwar");
   int cityStateQuery = -1;
   bool isCityState = false;
   int numberControlledCityStates = 0;
   int crateFlagQuery = -1;
   int numberBasesProcessed = 0;
   int age = kbGetAge();

   // --------
   //  Create the zones for building attack plans
   // --------
   vector mapCenter = kbGetMapCenter();
   float mapSize = kbGetMapXSize();
   int zoneRadius = mapSize / (9 * cNumberPlayers);

   vector retVal = cInvalidVector;
   vector mainBaseVec = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   vector v = cInvalidVector; // Scratch variable for intermediate calcs.

   // Find the most hated player, then build a series of locations around that player
   int enemyPlayer = aiGetMostHatedPlayerID();
   int enemyTC = getUnitByLocation(cUnitTypeAgeUpBuilding, enemyPlayer, cUnitStateABQ, mainBaseVec, 500.0);
   vector vec = cInvalidVector;
   vector bestLoc = cInvalidVector;
   float bestDist = 0.0;
   int enemyBuildingQuery = createSimpleUnitQuery(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateABQ);
   numberFound = kbUnitQueryExecute(enemyBuildingQuery);

   if (enemyTC < 0)
   {
      v = guessEnemyLocation(enemyPlayer);
   }
   else // Enemy TC found.
   {
      v = kbUnitGetPosition(enemyTC); // Vector from main base to enemy TC.
   }

   vec = xsVectorNormalize(mainBaseVec - v) * kbBaseGetDistance(enemyPlayer, mainBaseID);
   vector centerLaneCenter = vec * 0.5;
   vector centerLaneClose = rotateByReferencePoint(v, vec * 0.3, 0);
   vector centerLaneFar = rotateByReferencePoint(v, vec * 0.7, 0);
   vector centerFlankLeft = rotateByReferencePoint(v, vec * 0.5, 0.0 - PI * 0.5);
   vector centerFlankRight = rotateByReferencePoint(v, vec * 0.5, PI * 0.5);
   vector enemyBaseFlankLeft = rotateByReferencePoint(v, vec * 0.3, 0.0 - PI * 0.25);
   vector enemyBaseFlankRight = rotateByReferencePoint(v, vec * 0.3, PI * 0.25);
   // ---------
   // --------

   if (baseQuery < 0) // First run.
   {
      baseQuery = kbUnitQueryCreate("attackBaseQuery");
      kbUnitQuerySetIgnoreKnockedOutUnits(baseQuery, true);
      baseEnemyQuery = kbUnitQueryCreate("attackBaseEnemyQuery");
      kbUnitQuerySetIgnoreKnockedOutUnits(baseEnemyQuery, true);
   }

   if (gIsMonopolyRunning == true)
   {
      if (gMonopolyTeam == kbGetPlayerTeam(cMyID))
      {
         defendingMonopoly = true; // We're defending, let's not go launching any attacks.
      }
      else
      {
         attackingMonopoly = true; // We're attacking, focus on trade posts.
      }
   }
   else if (isItalianWars == true && kbCounterGetCurrentValue("leagueVictoryTimer") < 600)
   {
      // Italian Wars League Victory as Trade Monopoly.
      cityStateQuery = createSimpleUnitQuery(cUnitTypedeSPCSocketCityState, cPlayerRelationAny, cUnitStateAny);
      numberFound = kbUnitQueryExecute(cityStateQuery);

      for (i = 0; i < numberFound; i++)
      {
         unitID = kbUnitQueryGetResult(cityStateQuery, i);
         if (kbIsPlayerAlly(kbUnitGetPlayerID(unitID)) == true)
         {
            numberControlledCityStates++;
         }
      }

      if (numberControlledCityStates > (numberFound / 2))
      {
         attackingMonopoly = true;
      }
      else
      {
         defendingMonopoly = true;
      }
   }

   if (gIsKOTHRunning == true || aiIsKOTHAllowed() == true)
   {
      if (gKOTHTeam == kbGetPlayerTeam(cMyID))
      {
         defendingKOTH = true; // We're defending, let's not go launching any attacks.
      }
      else
      {
         attackingKOTH = true; // We're attacking, focus on the hill.
      }
   }

   numberUnits = aiPlanGetNumberUnits(gLandReservePlan, cUnitTypeLogicalTypeLandMilitary);

   for (i = 0; < numberUnits)
   {
      unitID = aiPlanGetUnitByIndex(gLandReservePlan, i);
      puid = kbUnitGetProtoUnitID(unitID);
      armyPower = armyPower + getMilitaryUnitStrength(puid);
   }

   // Reset target values if current player or base index is invalid.
   if (currentPlayer < 0 || currentBaseIndex < 0)
   {
      targetBaseID = -1;
      targetBaseLocation = cInvalidVector;
      targetPlayer = 2;
      targetIsEnemy = true;
      targetShouldAttack = false;
      targetAffordable = 0.0;
      targetBaseAssets = 0.0;
      targetDistancePenalty = 0.0;
      targetScore = 0.0;

      currentPlayer = 0;
      currentBaseIndex = 0;     
   }

   // Go through all players' bases and calculate values for comparison.
   // In attrition we go through the zones before getting to the base
   for (player = currentPlayer; < cNumberPlayers)
   {
      cityStateQuery = -1;

      if (player == 0)
      {
         if (isItalianWars == true)
         {
            cityStateQuery = createSimpleUnitQuery(cUnitTypedeSPCSocketCityState, 0, cUnitStateAny);
         }
         else if (isNorthernWars == true)
         {
            crateFlagQuery = createSimpleUnitQuery(cUnitTypedeSPCCrateFlag, 0, cUnitStateAny);
         }
         else
         {
            continue;
         }
      }

      if (cityStateQuery >= 0)
      {
         numberBases = kbUnitQueryExecute(cityStateQuery);
         isEnemy = true;
      }
      else if (crateFlagQuery >= 0)
      {
         numberBases = kbUnitQueryExecute(crateFlagQuery);
         isEnemy = true;
      }
      else
      {
         if (player == cMyID || kbHasPlayerLost(player) == true)
         {
            continue;
         }

         numberBases = kbBaseGetNumber(player);
         isEnemy = kbIsPlayerEnemy(player);


         if (isEnemy == true && (cvPlayerToAttack > 0 && cvPlayerToAttack != player && kbHasPlayerLost(cvPlayerToAttack) == false))
         {
            continue;
         }
      }

// --------
// Run through the zones
// --------
/*
   vector iterationList = (centerLaneCenter, centerLaneClose, centerLaneFar, centerFlankLeft
      centerFlankRight, enemyBaseFlankLeft, enemyBaseFlankRight)


      for (baseIndex : iterationList)
      {
         int cityStateID = -1;
         int crateFlagID = -1;

         // Split into multiple runs if we have a lot of bases to process.
         if (numberBasesProcessed >= 2)
         {
            currentPlayer = player;
            currentBaseIndex = baseIndex;
            xsSetRuleMinIntervalSelf(1);
            debugMilitary("attackManager: too many bases to process, splitting into multiple updates");
            return;
         }
         else
         {
            baseLocation = baseIndex;
            baseDistance = zoneRadius;
         }

         kbUnitQuerySetPlayerID(baseQuery, player);
         kbUnitQuerySetState(baseQuery, cUnitStateABQ);
         kbUnitQuerySetPosition(baseQuery, baseLocation);
         kbUnitQuerySetMaximumDistance(baseQuery, baseDistance);

         if (crateFlagQuery >= 0)
         {
            kbUnitQuerySetUnitType(baseQuery, cUnitTypeAbstractResourceCrate);
         }
         else
         {
            kbUnitQuerySetUnitType(baseQuery, cUnitTypeHasBountyValue);
         }
         kbUnitQueryResetResults(baseQuery);
         numberFound = kbUnitQueryExecute(baseQuery);

         buildingPower = 0.0;
         militaryPower = 0.0;
         enemyMilitaryPower = 0.0;
         // Gaia city states, prioritize them over everything.
         if (cityStateQuery >= 0)
         {
            baseAssets = 99999.0;
         }
         else if (crateFlagQuery >= 0)
         {
            // 300 points for each resource crate.
            baseAssets = numberFound * 300.0;
            // don't go through query results again.
            numberFound = 0;
         }
         else
         {
            baseAssets = 0.0;
         }
         isKOTH = false;
         isTradingPost = false;
         shouldAttack = true;
         isCityState = false;

         if (isEnemy == true)
         {
            if (currentTime - gLastAttackMissionTime < gAttackMissionInterval)
            {
               shouldAttack = false;
            }
         }
         else
         {
            if (currentTime - gLastDefendMissionTime < gDefendMissionInterval)
            {
               shouldAttack = false;
            }
         }

         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(baseQuery, i);
            puid = kbUnitGetProtoUnitID(unitID);
            switch (puid)
            {
               case cUnitTypeypKingsHill:
               {
                  baseAssets = baseAssets + 1600.0;
                  isKOTH = true;
                  break;
               }
               case cUnitTypeTownCenter:
               case cUnitTypedeSPCCommandPost:
               {
                  baseAssets = baseAssets + 1000.0;
                  break;
               }
               // Buildings generating resources.
               case cUnitTypeBank:
               {
                  baseAssets = baseAssets + 800.0;
                  break;
               }
               case cUnitTypeFactory:
               {
                  baseAssets = baseAssets + 1600.0;
                  break;
               }
               case cUnitTypeypWCPorcelainTower2:
               {
                  baseAssets = baseAssets + 800.0;
                  break;
               }
               case cUnitTypeypWCPorcelainTower3:
               {
                  baseAssets = baseAssets + 1200.0;
                  break;
               }
               case cUnitTypeypWCPorcelainTower4:
               case cUnitTypeypWCPorcelainTower5:
               {
                  baseAssets = baseAssets + 1600.0;
                  break;
               }
               case cUnitTypeypShrineJapanese:
               {
                  baseAssets = baseAssets + 200.0;
                  break;
               }
               case cUnitTypeypWJToshoguShrine2:
               case cUnitTypeypWJToshoguShrine3:
               case cUnitTypeypWJToshoguShrine4:
               case cUnitTypeypWJToshoguShrine5:
               {
                  baseAssets = baseAssets + 400.0;
                  break;
               }
               case cUnitTypedeHouseInca:
               case cUnitTypedeTorp:
               {
                  baseAssets = baseAssets + 200.0;
                  break;
               }
               case cUnitTypedeMountainMonastery:
               case cUnitTypedeUniversity:
               {
                  baseAssets = baseAssets + 300.0;
                  break;
               }
               // Buildings automatically creating military units.
               case cUnitTypeypWCSummerPalace2:
               case cUnitTypeypWCSummerPalace3:
               case cUnitTypeypWCSummerPalace4:
               case cUnitTypeypWCSummerPalace5:
               case cUnitTypeypDojo:
               {
                  baseAssets = baseAssets + 1200.0;
                  break;
               }
               // Buildings with HC drop off point.
               case cUnitTypeFortFrontier:
               case cUnitTypeOutpost:
               case cUnitTypeBlockhouse:
               case cUnitTypeNoblesHut:
               case cUnitTypeypWIAgraFort2:
               case cUnitTypeypWIAgraFort3:
               case cUnitTypeypWIAgraFort4:
               case cUnitTypeypWIAgraFort5:
               case cUnitTypeypCastle:
               case cUnitTypeYPOutpostAsian:
               case cUnitTypedeIncaStronghold:
               case cUnitTypedeTower:
               // Military buildings.
               case cUnitTypeBarracks:
               case cUnitTypeStable:
               case cUnitTypeArtilleryDepot:
               case cUnitTypeCorral:
               case cUnitTypeypWarAcademy:
               case cUnitTypeYPBarracksIndian:
               case cUnitTypeypCaravanserai:
               case cUnitTypeypBarracksJapanese:
               case cUnitTypeypStableJapanese:
               case cUnitTypedeKallanka:
               case cUnitTypedeWarCamp:
               case cUnitTypedeHospital:
               case cUnitTypedeCommandery:
               {
                  baseAssets = baseAssets + 100.0;
                  break;
               }
               case cUnitTypedePalace:
               {
                  baseAssets = baseAssets + 200.0;
                  break;
               }
               // Villagers.
               case cUnitTypeSettlerWagon:
               {
                  baseAssets = baseAssets + 400.0;
                  break;
               }
               case cUnitTypeSettler:
               case cUnitTypeCoureur:
               case cUnitTypeCoureurCree:
               case cUnitTypeSettlerNative:
               case cUnitTypeypSettlerAsian:
               case cUnitTypeypSettlerIndian:
               case cUnitTypeypSettlerJapanese:
               case cUnitTypedeSettlerAfrican:
               {
                  baseAssets = baseAssets + 200.0;
                  break;
               }
               default:
               {
                  if (kbUnitIsType(unitID, cUnitTypeTradingPost) == true)
                  {
                     if (isItalianWars == true && kbUnitGetSubCiv(unitID) == cCivSPCCityState)
                     {
                        baseAssets += 2000.0;
                        isCityState = true;
                     }
                     else if (kbUnitGetSubCiv(unitID) >= 0)
                     {
                        baseAssets += 400.0;
                     }
                     else // Trade route trading post.
                     {
                        baseAssets += 1600.0;
                     }
                     isTradingPost = true;
                  }
                  break;
               }
            }
         }

         // Ignore base when we have no good targets to attack.
         if (baseAssets == 0.0)
         {
            continue;
         }

         // Prioritize trade monopoly and king's hill when active.
         if ((attackingMonopoly == true || defendingMonopoly == true) && isTradingPost == false)
         {
            // When Italian Wars League Victory is active, only attack those TPs.
            if (isItalianWars == false || isCityState == true)
            {
               shouldAttack = false;
            }
         }
         if ((attackingKOTH == true || defendingKOTH == true) && isKOTH == false)
         {
            shouldAttack = false;
         }

         if (isEnemy == false)
         {
            kbUnitQuerySetPlayerRelation(baseEnemyQuery, cPlayerRelationEnemyNotGaia);
            kbUnitQuerySetState(baseEnemyQuery, cUnitStateABQ);
            kbUnitQuerySetPosition(baseEnemyQuery, baseLocation);
            kbUnitQuerySetMaximumDistance(baseEnemyQuery, baseDistance + 10.0);

            kbUnitQuerySetUnitType(baseEnemyQuery, cUnitTypeLogicalTypeLandMilitary);
            kbUnitQueryResetResults(baseEnemyQuery);
            numberEnemyFound = kbUnitQueryExecute(baseEnemyQuery);

            for (i = 0; < numberEnemyFound)
            {
               unitID = kbUnitQueryGetResult(baseQuery, i);
               puid = kbUnitGetProtoUnitID(unitID);
               enemyMilitaryPower = enemyMilitaryPower + getMilitaryUnitStrength(puid);
            }

            if (enemyMilitaryPower == 0.0)
            {
               continue;
         }
         }

         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(baseQuery, i);
            puid = kbUnitGetProtoUnitID(unitID);

            switch (puid)
            {
               case cUnitTypeFortFrontier:
               {
                  buildingPower = buildingPower + 10.0;
                  break;
               }
               case cUnitTypeYPOutpostAsian:
               case cUnitTypeOutpost:
               case cUnitTypeBlockhouse:
               {
                  buildingPower = buildingPower + 3.0;
                  break;
               }
               case cUnitTypeNoblesHut:
               case cUnitTypeypWIAgraFort2:
               case cUnitTypeypWIAgraFort3:
               case cUnitTypeypWIAgraFort4:
               case cUnitTypeypWIAgraFort5:
               case cUnitTypedeIncaStronghold:
               case cUnitTypeTownCenter:
               case cUnitTypedeSPCCommandPost:
               {
                  buildingPower = buildingPower + 4.0;
                  break;
               }
               case cUnitTypeypCastle:
               {
                  buildingPower = buildingPower + 3.5;
                  break;
               }
            }

            if (kbProtoUnitIsType(cMyID, puid, cUnitTypeLogicalTypeLandMilitary) == true)
            {
               militaryPower = militaryPower + getMilitaryUnitStrength(puid);
            }
         }

         // Avoid division by 0.
         if ((militaryPower + buildingPower) < 1.0)
         {
            militaryPower = 1.0;
            buildingPower = 0.0;
         }

         if (isEnemy == true)
         {
            // Do we have enough power to defeat the target base?
            if (armyPower < militaryPower && availableMilitaryPop > 0)
            {
               shouldAttack = false;
            }
         }
         else
         {
            // Is my ally really in trouble and can I handle the attack?
            if ((militaryPower + buildingPower > enemyMilitaryPower) ||
                (armyPower + militaryPower + buildingPower < enemyMilitaryPower * 0.8))
            {
               shouldAttack = false;
            }
         }

         // Prioritize defending allies.
         if (isEnemy == true && targetIsEnemy == false)
         {
            shouldAttack = false;
         }

         if (cDifficultyCurrent >= gDifficultyExpert)
         {
            // Avoid attacking until 5 minutes passed after aging up.
            // AssertiveWall: decrease this to 3 minutes
            if ((btRushBoom <= -0.5 && kbGetAge() < cAge4) || (btRushBoom <= 0.0 && kbGetAge() < cAge3))
            {
               if (currentTime - gAgeUpTime < 3 * 60 * 1000)
               {
                  shouldAttack = false;
               }
            }
         }

         if (baseAssets > maxBaseAssets)
         {
            maxBaseAssets = baseAssets;
            targetScore = (targetBaseAssets / maxBaseAssets) * targetAffordable * targetDistancePenalty;
         }

         if (isEnemy == true)
         {
            affordable = armyPower / (militaryPower + buildingPower);
         }
         else
         {
            affordable = (armyPower + militaryPower + buildingPower) / enemyMilitaryPower;
         }

         // Adjust for distance. If < 100m, leave as is.  Over 100m to 400m, penalize 10% per 100m.
         distancePenalty = distance(mainBaseLocation, baseLocation) / 1000.0;
         if (distancePenalty > 0.4)
         {
            distancePenalty = 0.4;
         }
         // Increase penalty by 40% if transporting is required. 
         // AssertiveWall: Decreases transport penalty as Age advances
         baseAreaGroup = kbAreaGroupGetIDByPosition(baseLocation);
         // AssertiveWall: I don't know if cAge is a regular integer
         int ageInt = 1;
         if (age == cAge2)
         {
            ageInt = 1;
         }
         if (age == cAge3)
         {
            ageInt = 2;
         }
         else
         {
            ageInt = 3;
         }
         
         if (mainAreaGroup != baseAreaGroup)
         {
            distancePenalty = distancePenalty + (4 - ageInt) / 10.0;
         }
         distancePenalty = 1.0 - distancePenalty;

         score = (baseAssets / maxBaseAssets) * affordable * distancePenalty;
         if (score > targetScore || (shouldAttack == true && targetShouldAttack == false))
         {
            targetBaseID = baseID;
            targetBaseLocation = baseLocation;
            targetPlayer = player;
            targetIsEnemy = isEnemy;
            targetBaseAssets = baseAssets;
            targetAffordable = affordable;
            targetDistancePenalty = distancePenalty;
            targetScore = score;
            targetShouldAttack = shouldAttack;
         }

         numberBasesProcessed++;
      }

      // If we found a city state target, break now.
      if (isItalianWars == true && cityStateQuery >= 0 && targetShouldAttack == true)
      {
         break;
      }

      // Set current base index to 0 to start from the first base of the next player.
      currentBaseIndex = 0;
   }

   // Reset current player and base index and restore rule interval.
   currentPlayer = -1;
   currentBaseIndex = -1;
   xsSetRuleMinIntervalSelf(15);

   // Update target player.
   if (targetIsEnemy == true)
   {
      aiSetMostHatedPlayerID(targetPlayer);
   }

   if (targetBaseID < 0 || targetShouldAttack == false)
   {
      // If we got nothing, and KOTH is active, grab the KOTH location.
      if (defendingKOTH == true || attackingKOTH == true)
      {
         targetIsEnemy = attackingKOTH;
         int kothID = getUnit(cUnitTypeypKingsHill, cPlayerRelationAny, cUnitStateAlive);
         targetPlayer = kbUnitGetPlayerID(kothID);
         targetBaseLocation = kbUnitGetPosition(kothID);
      }
      // Exclude city state, which doesn't have a base ID.
      else if (targetPlayer > 0)
      {
         // If we haven't attacked for too long and have plenty of resources in stock, attack anyway.
         if (targetIsEnemy == true)
         {
            if (currentTime - gLastAttackMissionTime < 2 * gAttackMissionInterval)
            {
               return;
            }
         }
         // No time check for defend, be a more helpful ally.

         // We have more resources to train a full army again.
         if ((xsArrayGetFloat(gResourceNeeds, cResourceGold) > 0.0 ||
            xsArrayGetFloat(gResourceNeeds, cResourceWood) > 0.0 ||
            xsArrayGetFloat(gResourceNeeds, cResourceFood) > 0.0) ||
            ((xsArrayGetFloat(gResourceNeeds, cResourceGold) + 
            xsArrayGetFloat(gResourceNeeds, cResourceWood) +
            xsArrayGetFloat(gResourceNeeds, cResourceFood)) < 100 * aiGetMilitaryPop()))
         {
            return;
         }
         debugMilitary("We have too much resources in stock, and idled our army for too long, "+(targetIsEnemy ? "attacking" : "defending"));
      }
   }*/
   /*else
   {
      targetBaseLocation = kbBaseGetLocation(targetPlayer, targetBaseID);
   }*/
/*
   vector gatherPoint = kbBaseGetMilitaryGatherPoint(cMyID, mainBaseID);
   if (targetIsEnemy == true)
   {
      planID = aiPlanCreate("Attack Player " + targetPlayer + " Base " + targetBaseID, cPlanCombat);

      aiPlanSetVariableInt(planID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
      if (targetBaseID >= 0)
      {
         aiPlanSetVariableInt(planID, cCombatPlanTargetMode, 0, cCombatPlanTargetModeBase);
         aiPlanSetVariableInt(planID, cCombatPlanTargetBaseID, 0, targetBaseID);
      }
      else
      {
         aiPlanSetVariableInt(planID, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      }
      aiPlanSetVariableInt(planID, cCombatPlanTargetPlayerID, 0, targetPlayer);
      aiPlanSetVariableVector(planID, cCombatPlanTargetPoint, 0, baseLocation);
      aiPlanSetVariableVector(planID, cCombatPlanGatherPoint, 0, gatherPoint);
      aiPlanSetVariableFloat(planID, cCombatPlanGatherDistance, 0, 40.0);
*/
      /*baseAreaGroup = kbAreaGroupGetIDByPosition(baseLocation);
      if (mainAreaGroup == baseAreaGroup)
      {
         aiPlanSetVariableInt(planID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternBest);
      }
      else
      {
         aiPlanSetVariableInt(planID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);
      }*/
      /*
      aiPlanSetVariableInt(planID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);

      // Override the route when it is valid.
      int routeID = cvCreateBaseAttackRoute(targetPlayer, targetBaseID);
      if (routeID >= 0)
      {
         aiPlanSetVariableInt(planID, cCombatPlanAttackRouteID, 0, routeID);
         // aiPlanSetVariableBool(planID, cCombatPlanRefreshAttackRoute, 0, false);
      }

      if (cDifficultyCurrent >= cDifficultyHard)
      {
         if (cDifficultyCurrent >= gDifficultyExpert)
         {
            aiPlanSetVariableBool(planID, cCombatPlanAllowMoreUnitsDuringAttack, 0, true);
         }
         aiPlanSetVariableInt(planID, cCombatPlanRefreshFrequency, 0, 300);
         aiPlanSetVariableInt(planID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeBaseGone);
         aiPlanSetVariableInt(planID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
         updateMilitaryTrainPlanBuildings(gForwardBaseID);
      }
      else
      {
         aiPlanSetVariableInt(planID, cCombatPlanRefreshFrequency, 0, 1000);
         aiPlanSetVariableInt(planID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeBaseGone);
      }

      // If we do not have a base, destroy the plan when we have no targets.
      if (targetBaseID < 0)
      {
         aiPlanSetVariableInt(planID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | aiPlanGetVariableInt(planID, cCombatPlanDoneMode, 0));
         aiPlanSetVariableInt(planID, cCombatPlanNoTargetTimeout, 0, 30000);
      }

      aiPlanSetBaseID(planID, mainBaseID);
      aiPlanSetInitialPosition(planID, gatherPoint);

      addUnitsToMilitaryPlan(planID);

      aiPlanSetActive(planID);

      gLandAttackPlanID = planID; // AssertiveWall: set the extern so we can kill this plan later if we need to
      gLastAttackMissionTime = xsGetTime();
      debugMilitary("***** LAUNCHING ATTACK on player " + targetPlayer + " base " + targetBaseID);
   }
   else 
   {
      planID = aiPlanCreate("Defend Player " + targetPlayer + " Base " + targetBaseID, cPlanCombat);

      aiPlanSetVariableInt(planID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
      if (targetBaseID >= 0)
      {
         aiPlanSetVariableInt(planID, cCombatPlanTargetMode, 0, cCombatPlanTargetModeBase);
         aiPlanSetVariableInt(planID, cCombatPlanTargetBaseID, 0, targetBaseID);
      }
      else
      {
         aiPlanSetVariableInt(planID, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      }
      aiPlanSetVariableInt(planID, cCombatPlanTargetPlayerID, 0, targetPlayer);
      aiPlanSetVariableVector(planID, cCombatPlanTargetPoint, 0, baseLocation);
      aiPlanSetVariableInt(planID, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
      aiPlanSetVariableInt(planID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget | cCombatPlanDoneModeRetreat);
      aiPlanSetVariableInt(planID, cCombatPlanNoTargetTimeout, 0, 30000);
      aiPlanSetVariableInt(planID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      aiPlanSetOrphan(planID, true);

      addUnitsToMilitaryPlan(planID);

      aiPlanSetActive(planID);

      gLastDefendMissionTime = xsGetTime();
      debugMilitary("***** DEFENDING player " + targetPlayer + " base " + targetBaseID);*/
   }
}