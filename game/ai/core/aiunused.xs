//==============================================================================
/* aiBuildOrders.xs

   This file contains old unused rules and functions. 
   Helps keep the main files more tidy, without deleting things that may be 
   useful later.

*/
//==============================================================================

//==============================================================================
/* attackRetreatCheck
   AssertiveWall: Goes through the attack plans and decides when to retreat 
   Also tells attack plans to attack armies if they run into one

   * not in use* Done better by rule attackRetreat
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
      //aiChat(1, "Attacking nearby Enemy en route");
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
/* gatherLostNuggets
   AssertiveWall: looks for wood nuggets to gather
   Copied from the water nugget script, didn;t rename any variables
   * not in use *
*/
//==============================================================================
rule gatherLostNuggets
inactive
minInterval 2
{
   /*extern int gWaterNuggetPlan = -1;            // Persistent plan goes out to try and find water nuggets
   //extern const int cWaterNuggetSearch = -1;    // Units moving to the water nugget
   //extern const int cWaterNuggetAttack = 0;     // Units attacking the guardians 
   //extern const int cWaterNuggetGather = 1;     // Units gathering the nugget
   //extern int gWaterNuggetState = cWaterNuggetSearch;           // Stores the state of the water nugget plan
   //extern int gWaterNuggetTarget = -1;          // Stores the target of whatever the water nugget plan is doing
   */

   // First Run, or after plan gets destroyed
   // Just borrow all the water variables
   if (gWaterNuggetPlan < 0)
   {
      int nuggetPlanID = aiPlanCreate("Nugget Raiding Plan", cPlanReserve);

      aiPlanAddUnitType(nuggetPlanID, cUnitTypeLogicalTypeLandMilitary, 1, 99, 99);
      aiPlanAddUnit(nuggetPlanID, gExplorerID);
      aiPlanAddUnit(nuggetPlanID, gExplorer2ID);

      aiPlanSetDesiredPriority(nuggetPlanID, 80); // Only thing going on
      aiPlanSetActive(nuggetPlanID);
      gWaterNuggetPlan = nuggetPlanID;
   }

   int explorerUnit = gExplorerID;
   if (xsGetTime() > gWaterNuggetTimeout + 30*1000 && kbUnitGetActionType(explorerUnit) == cActionTypeIdle)
   {  // Reset
      gWaterNuggetState = cWaterNuggetSearch;
      gWaterNuggetTimeout = xsGetTime();
      return;
   }

   if (kbResourceGet(cResourceWood) >= 500)
   {
      // we have enough resources
      xsDisableSelf();
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
   int numberExplorerWarships = aiPlanGetNumberUnits(gWaterNuggetPlan, cUnitTypeLogicalTypeLandMilitary);
   //aiChat(1, "#" + numberExplorerWarships);

   switch (gWaterNuggetState)
   {
      case cWaterNuggetSearch:
      {  
         xsSetRuleMinIntervalSelf(15);
         vector explorerLoc = kbUnitGetPosition(explorerUnit);
         int indexedExplorerUnit = -1;
         int explorerFleetHP = 0;
         int woodTreasure = -1;

         // Looks for a suitable nugget and tells the ships to attack it
         aiPlanSetDesiredPriority(gWaterNuggetPlan, 21);
         for (i = 0; < numberExplorerWarships)
         {
            indexedExplorerUnit = aiPlanGetUnitByIndex(gWaterNuggetPlan, i);
            explorerFleetHP = explorerFleetHP + kbUnitGetCurrentHitpoints(indexedExplorerUnit);
         }

         // Store enemy location so we can avoid it
         vector guessedEnemyLocation = guessEnemyLocation();

         // Find a suitable water nugget. Only check some random locations. (decrease if AI is too good at spotting treasures)
         for (j = 0; < 50)
         {
            waterNuggetLocation = getRandomGaiaUnitPosition(cUnitTypeAbstractNuggetLand, explorerLoc, 0.3*kbGetMapXSize());
            nuggetID = getUnitByLocation(cUnitTypeAbstractNuggetLand, cPlayerRelationAny, cUnitStateAlive, waterNuggetLocation, 4.0);

            // skip if nugget is too close to enemy
            /*if (distance(waterNuggetLocation, guessedEnemyLocation) < 150)
            {
               continue;
            }*/

            guardianHealth = 0;
            guardianQuery = createSimpleUnitQuery(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, waterNuggetLocation, 5.0);
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

               //aiChat(1, "Wood: " + kbResourceGetSubType(nuggetID));
               
            // Nothing other than freebies or wood on lost
            int nuggetPUID = kbUnitGetProtoUnitID(nuggetID);
            //aiChat(1, "puid: " + nuggetPUID + " " + cUnitTypeNuggetDroppedWood);
            if ((nuggetPUID != cUnitTypeNuggetDroppedWood &&
                  nuggetPUID != cUnitTypeypNuggetDroppedWoodAsian &&
                  nuggetPUID != cUnitTypedeNuggetAfricanDroppedWood))//&&
                  //guardianHealth > 0)
            {
               continue;
            }

            if (j == 49)
            {
               // found nothing, activate exploration plan as a last hope
               xsEnableRule("exploreMonitor");
            }
            //aiChat(1, "found wood treasure");
            
            /*if (kbUnitGetResourceAmount(nuggetID, cResourceWood) <= 0)//guardianHealth > 0)
            {
               continue;
            }*/

            if (guardianHealth < bestGuardianHP)
            {
               bestNugget = nuggetID; // Store this as the best nugget
               bestGuardianHP = guardianHealth;
               bestGuardianID = guardianID;
            }
         }

         // Don't bother unless there's a good chance of winning
         /*if (explorerFleetHP < 1.5 * bestGuardianHP)
         {
            return;
         }*/
      
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
         guardianNumber = getUnitCountByLocation(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 6.0);
         int currentGuardianID = getUnitByLocation(cUnitTypeGuardian, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 6.0);

         if (guardianNumber <= 0 && kbUnitGetActionType(explorerUnit) == cActionTypeIdle)
         {
            gWaterNuggetState = cWaterNuggetGather;
            gWaterNuggetTarget = getUnitByLocation(cUnitTypeAbstractNuggetLand, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 4.0);
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
         int nuggetsAtLoc = getUnitCountByLocation(cUnitTypeAbstractNuggetLand, cPlayerRelationAny, cUnitStateAlive, gWaterNuggetTargetLoc, 3.0);
         if (nuggetsAtLoc > 0)
         {
            for (n = 0; < numberExplorerWarships)
            {
               aiTaskUnitWork(aiPlanGetUnitByIndex(gWaterNuggetPlan, n), gWaterNuggetTarget);
            }
         } 
         else if (kbUnitGetActionType(explorerUnit) == cActionTypeIdle)
         {
            gWaterNuggetState = cWaterNuggetSearch;
            aiPlanSetDesiredPriority(gWaterNuggetPlan, 21);
         }
         break;
      }
   }
}

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
      //aiChat(1, "Decreasing the AI handicap to " + newHandicap);
   }
   else if (friendlyTeamScore * modifier < enemyTeamScore)
   {
      newHandicap = kbGetPlayerHandicap(cMyID) * (1.0 + handicapAdjustment);
      //aiChat(1, "Increasing the AI handicap to " + newHandicap);
   }
   else
   {
      return;
   }

   // Create upper and lower bounds of 10% of the initial handicap
   if (newHandicap > gStartingHandicap * 1.12 || newHandicap < gStartingHandicap * 0.88)
   {
      //aiChat(1, "Blocked new handicap of: " + newHandicap + ". Starting handicap was: " + gStartingHandicap);
      return;
   }

   kbSetPlayerHandicap(cMyID, newHandicap);
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
/* seaWall
   AssertiveWall: Builds a large outer ring that hopefully covers a good portion
   of coastline
   * not in use *
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
// idleFishBoatMonitor
// AssertiveWall: Looks for idle fishing boats and sends them to a safer fishing
//                spot with more fish & whales
// * not in use * Doesn't work very well. Always fighting fishing boats who want
//                to do their own thing
//==============================================================================
rule idleFishBoatMonitor
inactive
minInterval 12
{
   int idleBoatQuery = createSimpleIdleUnitQuery(gFishingUnit, cPlayerRelationSelf, cUnitStateAlive);
   int idleBoatCount = kbUnitQueryExecute(idleBoatQuery);
   int tempBoat = -1;
   vector newFishingSpot = cInvalidVector;

   // Return if we didn't find any idle boats
   if (idleBoatCount <= 0)
   {
      return;
   }

   // Find a good spot. Just go through fish and whales, pick furthest one from enemy. 
   // Willing to go a little closer for whales, about 85% as far
   int fishQuery = createSimpleUnitQuery(cUnitTypeAbstractFish, cPlayerRelationAny, cUnitStateAlive);
   int fishCount = kbUnitQueryExecute(fishQuery);
   int bestFishID = -1;
   int bestFishDistance = -1;
   int tempFishID = -1;
   int tempFishDistance = -1;
   vector tempFishLocation = cInvalidVector;
   vector enemyPosition = guessEnemyLocation();

   for (j = 0; < fishCount)
   {
      tempFishID = kbUnitQueryGetResult(fishQuery, j);
      tempFishLocation = kbUnitGetPosition(tempFishID);
      tempFishDistance = distance(tempFishLocation, enemyPosition);
      if (tempFishDistance > bestFishDistance && tempFishLocation != cInvalidVector)
      {
         bestFishDistance = tempFishDistance;
         bestFishID = tempFishID;
      }
   }

   int whaleQuery = createSimpleUnitQuery(cUnitTypeAbstractWhale, cPlayerRelationAny, cUnitStateAlive);
   int whaleCount = kbUnitQueryExecute(whaleQuery);
   for (k = 0; < whaleCount)
   {
      tempFishID = kbUnitQueryGetResult(whaleQuery, j);
      tempFishLocation = kbUnitGetPosition(tempFishID);
      tempFishDistance = 1.17 * distance(tempFishLocation, enemyPosition);
      if (tempFishDistance > bestFishDistance && tempFishLocation != cInvalidVector)
      {
         bestFishDistance = tempFishDistance;
         bestFishID = tempFishID;
      }
   }

   newFishingSpot = kbUnitGetPosition(bestFishID);
   idleBoatQuery = createSimpleIdleUnitQuery(gFishingUnit, cPlayerRelationSelf, cUnitStateAlive);
   idleBoatCount = kbUnitQueryExecute(idleBoatQuery);
   for (i = 0; < idleBoatCount)
   {
      // Just move them. Let the auto-fishing take over from there
      tempBoat = kbUnitQueryGetResult(idleBoatQuery, i);
      // Only move boats that aren't on plans
      if (aiPlanGetDesiredPriority(kbUnitGetPlanID(tempBoat)) <= 19)
      {
         aiTaskUnitMove(tempBoat, newFishingSpot);
      }
   }
}