//==============================================================================
/* aiAssertiveWall.xs

   This file contains additional functions written by Assertive Wall

*/
//==============================================================================

rule randomTests
inactive
minInterval 10
{
   int totalResources = 0;
   totalResources = kbTotalResourceGet(cResourceFood);

   aiChat(1, "totalResources: " + totalResources);
   
   int totalUnitQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf, cUnitStateAny);
   int totalUnit = kbUnitQueryExecute(totalUnitQuery);

   //aiChat(1, "totalResources: " + totalResources + " totalUnit: " + totalUnit);
}

//==============================================================================
// getTeamAge
// AssertiveWall: gets the average age of our team. Rounds down
//==============================================================================

int getTeamAge(bool ourTeam = true)
{
   int ageTotal = 0;
   int numPlayers = 0;
   int myTeam = kbGetPlayerTeam(cMyID);
   int averageAge = -1;

   if (ourTeam == false)
   {  // Account for Gaia
      numPlayers = -1;
   }

   for (i = 0; < cNumberPlayers)
   {
      if (ourTeam == true)
      {
         if (myTeam == kbGetPlayerTeam(i))
         {
            ageTotal += kbGetAgeForPlayer(i);
            numPlayers += 1;
         }
      }
      else
      {
         if (myTeam != kbGetPlayerTeam(i))
         {
            ageTotal += kbGetAgeForPlayer(i);
            numPlayers += 1;
         }
      }
   }

   averageAge = ageTotal / numPlayers;

   return (averageAge);
}

//==============================================================================
/* raidManager , raidEnabler , desparationRaidEnabler
   AssertiveWall: looks for stray villagers to raid. 

   plan gets made once, then deleted. Need to keep it persistent

   enabler just goes through conditions on when to enable the raid manager.
   desparationRaidEnabler kicks in when we start falling behind
*/
//==============================================================================
rule desparationRaidEnabler
inactive
minInterval 10
{
   if (xsIsRuleEnabled("raidManager") == true)
   {
      xsDisableSelf();
      return;
   }

   bool timeForDesparationRaid = false;

   // The next block looks at scores
   int teamScore = 0;
   int enemyScore = 0;
   int numEnemies = -1;   // start at -1 to account for gaia
   int numAllies = 0;
   int myTeam = kbGetPlayerTeam(cMyID);

   for (i = 0; < cNumberPlayers)
   {
      if (myTeam == kbGetPlayerTeam(i))
      {
         teamScore += aiGetScore(i);
         numAllies += 1;
      }
      else
      {
         enemyScore = aiGetScore(i);
         numEnemies += 1;
      }
   }

   // If we are winning by a decent amount attack, otherwise check if we are losing
   if (((teamScore / numAllies < (1.1 * enemyScore / numEnemies)) && getTeamAge(true) < getTeamAge(false)) ||
         (teamScore / numAllies < (0.9 * enemyScore / numEnemies)))
   {
      timeForDesparationRaid = true;
   }

   if (timeForDesparationRaid == true)
   {
      xsEnableRule("raidManager");
      xsDisableSelf();
   }
}

rule raidEnabler
inactive
minInterval 10
{
   if (gStartOnDifferentIslands == true)
   {  // defend plan can't transport across water
      xsDisableSelf();
      return;
   }

   int age = kbGetAge();
   if (age < cAge2)
   {
      return;
   }

   // Special case since they get lots of cavalry. 90% chance of wanting to raid
   if (cMyCiv == cCivGermans || cMyCiv == cCivXPSioux)
   {
      if (aiRandInt(10) == 1)
      {
         xsEnableRule("desparationRaidEnabler");         
         xsDisableSelf();
         return;
      }
      else
      {
         xsEnableRule("raidManager");
         return;
      }
   }

   if (gStrategy == cStrategyRush)
   {  // 80% chance of raiding when rushing
      if (aiRandInt(10) <= 2)
      {
         xsEnableRule("desparationRaidEnabler");         
         xsDisableSelf();
         return;
      }
      else
      {
         xsEnableRule("raidManager");
         return;
      }
   }
   else if (gStrategy == cStrategyNakedFF)
   {  // 40% chance once we hit age 3
      if (age >= cAge3)
      {
         if (aiRandInt(10) <= 6)
         {
            xsEnableRule("desparationRaidEnabler");
            xsDisableSelf();
            return;
         }
         else
         {
            xsEnableRule("raidManager");
            return;
         }
      }
   }
   else if (gStrategy == cStrategySafeFF)
   {  // 60% chance of raiding
      if (aiRandInt(10) <= 4)
      {
         xsEnableRule("desparationRaidEnabler");         
         xsDisableSelf();
         return;
      }
      else
      {
         xsEnableRule("raidManager");
         return;
      }
   }
   else if (gStrategy == cStrategyFastIndustrial)
   {  // 50% chance of raiding
      if (aiRandInt(10) <= 5)
      {
         xsEnableRule("desparationRaidEnabler");         
         xsDisableSelf();
         return;
      }
      else
      {
         xsEnableRule("raidManager");
         return;
      }
   }
   else
   {  // 30% chance of raiding
      if (aiRandInt(10) <= 7)
      {
         xsEnableRule("desparationRaidEnabler");         
         xsDisableSelf();
         return;
      }
      else
      {
         xsEnableRule("raidManager");
         return;
      }
   }
}

rule raidManager
inactive
minInterval 10
{
   // Ensure we have enough cav
   int cavNumber = kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateAlive) + kbUnitCount(cMyID, cUnitTypeAbstractCoyoteMan, cUnitStateAlive);
   int minCav = 2 + kbGetAge();
   //static int raidPlanID = -1;

   if (cavNumber < minCav)
   {
      return;
   }

   if (aiPlanGetActive(gRaidPlanID) == false)
   {
      gRaidPlanID = -1;
   }

   // Look for stray undefended villagers, favoring those closer to us
   vector ourLocation = kbUnitGetPosition(aiPlanGetUnitByIndex(gRaidPlanID, 0));
   vector homeBase = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   if (gForwardBaseState == cForwardBaseStateActive)
   {
      homeBase = gForwardBaseLocation;
   }

   if (ourLocation == cInvalidVector)
   {
      ourLocation = homeBase;
   }

   int villagerQuery = createSimpleUnitQuery(cUnitTypeAbstractVillager, cPlayerRelationEnemyNotGaia, cUnitStateAlive);
   int numberVilFound = kbUnitQueryExecute(villagerQuery);
   int tempVil = -1;
   vector tempLocation = cInvalidVector;
   int vilClumpSize = 0;
   int bestClumpSize = 0;
   vector bestLocation = cInvalidVector;
   int tempDistance = 9999;
   int bestDistance = 9999;
   int tempNearbyTowers = -1;
   int tempNearbyMilitary = -1;
   int tempNearbyTC = -1;
   bool freeRaid = false;
   int numInPlan = -1;
   static int nextChatSend = 300000;

   if (gRaidPlanID < 0) // First run, create a persistent plan.
   {
      gRaidPlanID = aiPlanCreate("Persistent Raiding Plan", cPlanCombat);

      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      aiPlanSetVariableVector(gRaidPlanID, cCombatPlanTargetPoint, 0, homeBase);
      aiPlanSetInitialPosition(gRaidPlanID, homeBase);
      aiPlanSetVariableFloat(gRaidPlanID, cCombatPlanGatherDistance, 0, 30.0);
      aiPlanSetVariableFloat(gRaidPlanID, cCombatPlanTargetEngageRange, 0, 25.0);
      aiPlanSetDesiredPriority(gRaidPlanID, 30);  // Lower than standard attack so they can join
      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanRefreshFrequency, 0, 300);
      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOpportunistic);
      aiPlanSetVariableInt(gRaidPlanID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternMRU);
      //aiPlanSetVariableInt(gRaidPlanID, cCombatPlanNoTargetTimeout, 0, 2000);
      
      // Just a small number of cav
      aiPlanAddUnitType(gRaidPlanID, cUnitTypeAbstractCavalry, 0, minCav, minCav);
      aiPlanAddUnitType(gRaidPlanID, cUnitTypeAbstractCoyoteMan, 0, minCav, minCav);

      aiPlanSetActive(gRaidPlanID);
   }

   numInPlan = aiPlanGetNumberUnits(gRaidPlanID, cUnitTypeAbstractCavalry) + aiPlanGetNumberUnits(gRaidPlanID, cUnitTypeAbstractCoyoteMan);
   if (numInPlan < minCav)
   {
      aiPlanAddUnitType(gRaidPlanID, cUnitTypeAbstractCavalry, 2, minCav, minCav);
      aiPlanAddUnitType(gRaidPlanID, cUnitTypeAbstractCoyoteMan, 2, minCav, minCav);
   }

   // Find the "closest" villager clump. each extra villager is worth 10m, for a max of 40m
   // defensive buildings weight as "further" away
   // avoid raiding anywhere with troops or too many towers nearby
   for (i = 0; < numberVilFound)
   {
      tempVil = kbUnitQueryGetResult(villagerQuery, i);
      tempLocation = kbUnitGetPosition(tempVil);
      vilClumpSize = getUnitCountByLocation(cUnitTypeAbstractVillager, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
         tempLocation, 8.0);
      tempNearbyTowers = getUnitCountByLocation(cUnitTypeAbstractDefensiveBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
         tempLocation, 25.0);
      tempNearbyMilitary = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
         tempLocation, 40.0);
      tempNearbyTC = getUnitCountByLocation(cUnitTypeTownCenter, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
         tempLocation, 40.0);

      if (tempNearbyMilitary > 2 || tempNearbyTowers > 1)
      {  // Still go for it if there's only 1 tower or a tiny force
         continue;
      }

      if (tempNearbyTC > 0) // Currently can't handle garrisoned vills
      {
         continue;
      }

      if (vilClumpSize > 4)
      {
         vilClumpSize = 4;
      }
      tempDistance = distance(ourLocation, tempLocation) - 10 * vilClumpSize + 40 * (tempNearbyTowers + tempNearbyTC) + 20 * tempNearbyMilitary;

      if (tempDistance < bestDistance)
      {
         bestClumpSize = vilClumpSize;
         bestLocation = tempLocation;
         bestDistance = tempDistance;
         if (tempNearbyTowers <= 0)
         {
            freeRaid = true;
         }
      }
   }

   // If we're here, we can't see any villagers to raid. Check random resources around the player's base
   // randomly skips through the query as it goes. Makes sure the mine isn't too close to enemy defenses
   if (bestLocation == cInvalidVector)
   {
      vector enemyLocation = guessEnemyLocation();
      int halfMapRange = distance(enemyLocation, kbGetMapCenter());
      int goldMineQuery = createSimpleFoggedUnitQuery(cUnitTypeResource, 0, cUnitStateAny, enemyLocation, halfMapRange);
      int mineNumber = kbUnitQueryExecute(goldMineQuery);
      int tempMineID = -1;
      static int nextMine = 0;
      static bool anotherMineAllowed = true;

      // Don't move to next mine until we are near it
      tempLocation = aiPlanGetVariableVector(gRaidPlanID, cCombatPlanTargetPoint, 0);
      tempDistance = distance(ourLocation, tempLocation);

      if (distance(ourLocation, tempLocation) < 35)
      {  // We can choose another place to check as long as we're close enough to our current target
         anotherMineAllowed = true;
      }

      if (anotherMineAllowed == true)
      {  
         for (i = 0; < mineNumber)
         {
            tempMineID = kbUnitQueryGetResult(goldMineQuery, i);

            if (kbProtoUnitIsType(0, kbUnitGetProtoUnitID(tempMineID), cUnitTypeWood) == true)
            {  // Skip trees
               continue;
            }

            tempLocation = kbUnitGetPosition(tempMineID);
            if (distance(ourLocation, tempLocation) < 35)
            {  // Ignore the one we are right next to
               continue;
            }
            tempNearbyTowers = getUnitCountByLocation(cUnitTypeAbstractDefensiveBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
               tempLocation, 25.0);
            tempNearbyMilitary = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
               tempLocation, 40.0);
            tempNearbyTC = getUnitCountByLocation(cUnitTypeTownCenter, cPlayerRelationEnemyNotGaia, cUnitStateAlive, 
               tempLocation, 40.0);

            if (tempNearbyMilitary > 2 || tempNearbyTowers > 0 || tempNearbyTC > 0)
            {  // Don't randomly check any dangerous spots
               continue;
            }

            tempDistance = distance(ourLocation, tempLocation) + 20 * tempNearbyMilitary;

            if (kbUnitGetActionTypeByIndex(tempMineID, 0) == cActionTypeDeath)
            {  // Prioritize dead hunts
               tempDistance = tempDistance / 4;
               break;
            }
            
            if (tempDistance < bestDistance && tempLocation != cInvalidVector)
            {
               bestClumpSize = vilClumpSize;
               bestLocation = tempLocation;
               bestDistance = tempDistance;
               anotherMineAllowed = false;
            }
         }
      }
   }

   if (bestLocation != cInvalidVector)
   {
      aiPlanSetVariableVector(gRaidPlanID, cCombatPlanTargetPoint, 0, bestLocation);

      if (xsGetTime() > nextChatSend)
      {
         sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillAttackEnemySettlers, bestLocation);
         nextChatSend = 2 * nextChatSend + aiRandInt(60000);
      }
   }
   else if (anotherMineAllowed == true)
   {  // If we're here, we tried to look for a random mine to raid but couldn't find one
      aiPlanSetVariableVector(gRaidPlanID, cCombatPlanTargetPoint, 0, homeBase);
   }

}

//==============================================================================
/* haveHumanAlly
   AssertiveWall: little function to tell you whether you have a human ally
*/
//==============================================================================

bool haveHumanAlly(void)
{
   //bool humanAlly = false; // Set true if we have a surviving human ally.
   // Look for human allies.
   for (i = 1; <= cNumberPlayers)
   {
      if ((kbIsPlayerAlly(i) == true) && (kbIsPlayerHuman(i) == true))
      {
         return true;
      }
   }

   return false;
}

//==============================================================================
/* updateWantedTowersAssertive
   Replaces old rule

   Calculate how many Towers (using the word Towers for Castles here too)
   we want for this age using the btOffenseDefense variable to set up the initial values.
   Some gTowerUnit are also military production buildings like War Huts so the
   values below aren't a guaranteed maximum for those kinds of civs.
   And shipments of Towers can push us above these limits too of course. */
//==============================================================================
void updateWantedTowersAssertive()
{
   int age = kbGetAge();
   int buildLimit = kbGetBuildLimit(cMyID, gTowerUnit);
   int towerNum = 0;

   if (age == cvMaxAge)
   {
      towerNum = buildLimit; // Just max out on Towers in Imperial/max allowed age.
                               // We will reduce this on lower difficulties of course.
   }
   // AssertiveWall: Define based on age, then disposition
   else if (gStartOnDifferentIslands == true)
   {
      if (age == cAge1)
      {
         towerNum = 0;
      }
      else if (age == cAge2)
      {
         towerNum = 1;
      }
      else if (age == cAge3)
      {
         towerNum = 3;
      }
      else if (age == cAge4)
      {
         towerNum = 5;
      }

      if (agingUp() == true)
      {
         towerNum += 1;
      }

      if (gStrategy == cStrategyRush)
      { 
         towerNum -= 2;
      }
      else if (gStrategy == cStrategyFastIndustrial && kbGetAge() < cAge4)
      {
         // nothing
      }
      else if (gStrategy == cStrategyNakedFF && kbGetAge() < cAge3)
      {
         towerNum -= 2;
      }
      else if (gStrategy == cStrategySafeFF && kbGetAge() < cAge3)
      {
         towerNum += 1;
      }
   }
   else
   {
      if (age == cAge1)
      {
         towerNum = 0;
      }
      else if (age == cAge2)
      {
         towerNum = 1;
      }
      else if (age == cAge3)
      {
         towerNum = 2;
      }
      else if (age == cAge4)
      {
         towerNum = 4;
      }

      if (agingUp() == true)
      {
         towerNum += 1;
      }

      if (gStrategy == cStrategyRush)
      { 
         towerNum -= 2;
      }
      else if (gStrategy == cStrategyFastIndustrial && kbGetAge() < cAge4)
      {
         // nothing
      }
      else if (gStrategy == cStrategyNakedFF && kbGetAge() < cAge3)
      {
         towerNum -= 2;
      }
      else if (gStrategy == cStrategySafeFF && kbGetAge() < cAge3)
      {
         towerNum += 1;
      }
   }

   // Impose some limits based on difficulty, Hardest and Extreme just go full out.
   if (cDifficultyCurrent <= cDifficultyEasy) // Easy / Standard.
   {
      if (towerNum > 2)
      {
         towerNum = 2;
         if (gStartOnDifferentIslands == true)
         {
            towerNum += 1; // AssertiveWall: +1 for island maps
         }
      }
   }
   // AssertiveWall: allow Hard to play the same as Extreme
   else if (cDifficultyCurrent < cDifficultyHard) // Moderate / Hard.
   {
      if (towerNum > 4)
      {
         towerNum = 4;
         if (gStartOnDifferentIslands == true)
         {
            towerNum += 1; // AssertiveWall: +1 for island maps
         }
      }
   }

   // Safety check.
   if (towerNum > buildLimit)
   {
      towerNum = buildLimit;
   }

   // On island maps, leave two for forward bases
   if (gStartOnDifferentIslands == true)
   {
      if (towerNum > buildLimit - 2)
      {
         towerNum = buildLimit - 2;
      }
   }

   gNumTowers = towerNum;
}

//==============================================================================
/* manageMicro
   AssertiveWall: switches our micro strategy based on how many units there are.
      If our army gets too big, switch to less micro to avoid over-micro issues
*/
//==============================================================================

rule manageMicro
inactive
minInterval 20
{
   int milNumber = kbUnitCount(cMyID, cUnitTypeLogicalTypeLandMilitary, cUnitStateAlive);
   static int switcherInt = 0;   // used to prevent setting too much. 
   
   if (milNumber > 50 && switcherInt == 0)
   {
      aiSetMicroFlags(cMicroLevelNormal);
      switcherInt = 1;
   }
   else if (switcherInt == 1)
   {
      aiSetMicroFlags(cMicroLevelHigh);
      switcherInt = 0;
   }
}

//==============================================================================
/* watchExplorer
   AssertiveWall: watches for the find base exploration plan to go away, then
      moves the explorer back to home base if it ends
*/
//==============================================================================

rule watchExplorer
inactive
minInterval 2
{
   static bool canDisable = false;
   vector mainBaseLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   static int explorerID = -1;
   static int explorer2ID = -1;

   if (kbGetAge() >= cAge2)
   {
      xsDisableSelf();
      return;
   }
   
   if (aiPlanGetActive(gFindBasePlanID) == true)
   {
      explorerID = aiPlanGetUnitByIndex(gFindBasePlanID, 0);
      explorer2ID = aiPlanGetUnitByIndex(gFindBasePlanID, 1);
      canDisable = true;
   }
   else if (canDisable == true)
   {
      aiTaskUnitMove(explorerID, mainBaseLoc);
      aiTaskUnitMove(explorer2ID, mainBaseLoc);
      xsDisableSelf();
      return;
   }
}

//==============================================================================
/* cannonCorners

   Basically just tells a cannon to move to that position

   The rule keeps cannon stationed at each corner, and only goes away 
   if the cannons die.
*/
//==============================================================================
rule cannonCornerRule
inactive
minInterval 20
{

   // Find some cannon to use
   int cannonNumber = aiPlanGetNumberUnits(gCannonCornerPlan, cUnitTypeAbstractArtillery);
   int tempCannon = -1;

   if (cannonNumber <= 0)
   {
      aiPlanDestroy(gCannonCornerPlan);
      gCannonCornerPlan = -1;
      xsDisableSelf();
      return;
   }

   for (i = 0; < cannonNumber)
   {
      tempCannon = aiPlanGetUnitByIndex(gCannonCornerPlan, i);

      // We've reserved the arty. Now put it in the spots
      if (i == 0)
      {
         if (distance(kbUnitGetPosition(tempCannon), gCannonCornerLoc1) > 4)
         {
            aiTaskUnitMove(tempCannon, gCannonCornerLoc1);
         }
      }
      else if (i == 1)
      {
         if (distance(kbUnitGetPosition(tempCannon), gCannonCornerLoc2) > 4)
         {
            aiTaskUnitMove(tempCannon, gCannonCornerLoc2);
         }
      }
      else if (i == 2)
      {
         if (distance(kbUnitGetPosition(tempCannon), gCannonCornerLoc3) > 4)
         {
            aiTaskUnitMove(tempCannon, gCannonCornerLoc3);
         }
      }
      else if (i == 3)
      {
         if (distance(kbUnitGetPosition(tempCannon), gCannonCornerLoc4) > 4)
         {
            aiTaskUnitMove(tempCannon, gCannonCornerLoc4);
         }
      }
   }
}

int cannonCorners(int pri = 21, vector position1 = cInvalidVector, vector position2 = cInvalidVector, vector position3 = cInvalidVector, vector position4 = cInvalidVector)
{
   // Find some cannon to use
   int cannonQuery = createSimpleUnitQuery(cUnitTypeAbstractArtillery, cPlayerRelationSelf, cUnitStateAlive);
   int cannonNumber = kbUnitQueryExecute(cannonQuery);
   int tempCannon = -1;
   int countAdded = 0;

   gCannonCornerPlan = -1;
   if (gCannonCornerPlan < 0)
   {
      gCannonCornerPlan = aiPlanCreate("Cannon Corner Plan", cPlanReserve);
      aiPlanAddUnitType(gCannonCornerPlan, cUnitTypeAbstractArtillery, 0, 0, 200);
      aiPlanSetNoMoreUnits(gCannonCornerPlan, true);
      aiPlanSetDesiredPriority(gCannonCornerPlan, pri); 
      aiPlanSetActive(gCannonCornerPlan);
   }

   for (i = 0; < cannonNumber)
   {
      tempCannon = kbUnitQueryGetResult(cannonQuery, i);

      if (aiPlanGetActualPriority(kbUnitGetPlanID(tempCannon)) >= pri)
      {  // Don't add any cannon currently being used
         continue;
      }

      if (aiPlanAddUnit(gCannonCornerPlan, tempCannon) == false)
      {
         xsEnableRule("cannonCornerRule");
         return (countAdded);
      }

      // We've reserved the arty. Now put it in the spots
      if (countAdded == 0 && position1 != cInvalidVector)
      {
         aiTaskUnitMove(tempCannon, position1);
         countAdded += 1;
         gCannonCornerLoc1 = position1;
      }
      else if (countAdded == 1 && position2 != cInvalidVector)
      {
         aiTaskUnitMove(tempCannon, position2);
         countAdded += 1;
         gCannonCornerLoc2 = position2;
      }
      else if (countAdded == 2 && position3 != cInvalidVector)
      {
         aiTaskUnitMove(tempCannon, position3);
         countAdded += 1;
         gCannonCornerLoc3 = position3;
      }
      else if (countAdded == 3 && position4 != cInvalidVector)
      {
         aiTaskUnitMove(tempCannon, position4);
         countAdded += 1;
         gCannonCornerLoc4 = position4;
      }
   }

   xsEnableRule("cannonCornerRule");
   return (countAdded);
}

//==============================================================================
/* sawtoothFort
   builds the sawtooth fort pattern inspired by the incan fort Sacsayhuamán
*/
//==============================================================================
void sawtoothFort(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 2.0, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0, bool ravelin = false)
{
   scale = 5 * scale;  // make it similar size to others
   if (position == cInvalidVector){
      return;}

   if (baseID < 0){
      baseID = gForwardBaseID;}

   if (baseID < 0){
      baseID = kbBaseGetMainID(cMyID);}


   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = angle + 3.14;
   }
   else
   {
      angle = angle;
   } 

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX, positionY, positionZ + 1.2 * scale); 
         vector towerPos2 = xsVectorSet(positionX, positionY, positionZ - 1.2 * scale); 
      }
      else
      {
         towerPos2 = xsVectorSet(positionX, positionY, positionZ + 1.2 * scale); 
         towerPos1 = xsVectorSet(positionX, positionY, positionZ - 1.2 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos2 = cInvalidVector;
      }
      cannonCorners(pri, towerPos2, towerPos1);
   }

   // The center position is "position"
   // Base consists of 12 segments
   vector start1 = xsVectorSet(positionX - 1.862 * scale, positionY, positionZ + 0.626 * scale);
   vector end1 = xsVectorSet(positionX -2.239 * scale, positionY, positionZ + 1.357 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX - 1.659 * scale, positionY, positionZ + 1.249 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX - 1.461 * scale, positionY, positionZ + 2.033 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX - 1.136 * scale, positionY, positionZ + 1.609 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX - 0.415 * scale, positionY, positionZ + 2.369 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX - 0.212 * scale, positionY, positionZ + 1.944 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX + 0.748 * scale, positionY, positionZ + 2.362 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX + 0.692 * scale, positionY, positionZ + 1.833 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX + 1.511 * scale, positionY, positionZ + 1.903 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX + 1.334 * scale, positionY, positionZ + 1.443 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX + 2.055 * scale, positionY, positionZ + 1.157 * scale);

   vector start12 = end11;
   vector end12 = xsVectorSet(positionX + 1.728 * scale, positionY, positionZ + 0.626 * scale);

   vector start13 = end12;
   vector end13 = xsVectorSet(positionX + 1.728 * scale, positionY, positionZ - 0.626 * scale);

   vector start14 = end13;
   vector end14 = xsVectorSet(positionX + 2.055 * scale, positionY, positionZ - 1.157 * scale);

   vector start15 = end14;
   vector end15 = xsVectorSet(positionX + 1.334 * scale, positionY, positionZ - 1.443 * scale);

   vector start16 = end15;
   vector end16 = xsVectorSet(positionX + 1.511 * scale, positionY, positionZ - 1.903 * scale);

   vector start17 = end16;
   vector end17 = xsVectorSet(positionX + 0.692 * scale, positionY, positionZ - 1.833 * scale);

   vector start18 = end17;
   vector end18 = xsVectorSet(positionX + 0.748 * scale, positionY, positionZ - 2.362 * scale);

   vector start19 = end18;
   vector end19 = xsVectorSet(positionX - 0.212 * scale, positionY, positionZ - 1.944 * scale);

   vector start20 = end19;
   vector end20 = xsVectorSet(positionX - 0.415 * scale, positionY, positionZ - 2.369 * scale);

   vector start21 = end20;
   vector end21 = xsVectorSet(positionX - 1.136 * scale, positionY, positionZ - 1.609 * scale);

   vector start22 = end21;
   vector end22 = xsVectorSet(positionX - 1.461 * scale, positionY, positionZ - 2.033 * scale);

   vector start23 = end22;
   vector end23 = xsVectorSet(positionX - 1.659 * scale, positionY, positionZ - 1.249 * scale);

   vector start24 = end23;
   vector end24 = xsVectorSet(positionX - 2.239 * scale, positionY, positionZ - 1.357 * scale);

   vector start25 = end24;
   vector end25 = xsVectorSet(positionX - 1.862 * scale, positionY, positionZ - 0.626 * scale);

   vector start26 = end25;
   vector end26 = start1;

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);

   start9 = rotateByReferencePoint(position, start9 - position, angle);
   end9 = rotateByReferencePoint(position, end9 - position, angle);

   start10 = rotateByReferencePoint(position, start10 - position, angle);
   end10 = rotateByReferencePoint(position, end10 - position, angle);

   start11 = rotateByReferencePoint(position, start11 - position, angle);
   end11 = rotateByReferencePoint(position, end11 - position, angle);

   start12 = rotateByReferencePoint(position, start12 - position, angle);
   end12 = rotateByReferencePoint(position, end12 - position, angle);

   start13 = rotateByReferencePoint(position, start13 - position, angle);
   end13 = rotateByReferencePoint(position, end13 - position, angle);

   start14 = rotateByReferencePoint(position, start14 - position, angle);
   end14 = rotateByReferencePoint(position, end14 - position, angle);

   start15 = rotateByReferencePoint(position, start15 - position, angle);
   end15 = rotateByReferencePoint(position, end15 - position, angle);

   start16 = rotateByReferencePoint(position, start16 - position, angle);
   end16 = rotateByReferencePoint(position, end16 - position, angle);

   start17 = rotateByReferencePoint(position, start17 - position, angle);
   end17 = rotateByReferencePoint(position, end17 - position, angle);

   start18 = rotateByReferencePoint(position, start18 - position, angle);
   end18 = rotateByReferencePoint(position, end18 - position, angle);

   start19 = rotateByReferencePoint(position, start19 - position, angle);
   end19 = rotateByReferencePoint(position, end19 - position, angle);

   start20 = rotateByReferencePoint(position, start20 - position, angle);
   end20 = rotateByReferencePoint(position, end20 - position, angle);

   start21 = rotateByReferencePoint(position, start21 - position, angle);
   end21 = rotateByReferencePoint(position, end21 - position, angle);

   start22 = rotateByReferencePoint(position, start22 - position, angle);
   end22 = rotateByReferencePoint(position, end22 - position, angle);

   start23 = rotateByReferencePoint(position, start23 - position, angle);
   end23 = rotateByReferencePoint(position, end23 - position, angle);

   start24 = rotateByReferencePoint(position, start24 - position, angle);
   end24 = rotateByReferencePoint(position, end24 - position, angle);

   start25 = rotateByReferencePoint(position, start25 - position, angle);
   end25 = rotateByReferencePoint(position, end25 - position, angle);

   start26 = rotateByReferencePoint(position, start26 - position, angle);
   end26 = rotateByReferencePoint(position, end26 - position, angle);


   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   // segment 13
   int wallPlan13ID = aiPlanCreate("WallInBase13", cPlanBuildWall);
   if (wallPlan13ID != -1)
   {
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan13ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallStart, 0, start13);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallEnd, 0, end13);
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan13ID, baseID);
      aiPlanSetEscrowID(wallPlan13ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan13ID, pri);
      aiPlanSetActive(wallPlan13ID, true);
   }

   // segment 14
   int wallPlan14ID = aiPlanCreate("WallInBase14", cPlanBuildWall);
   if (wallPlan14ID != -1)
   {
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan14ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallStart, 0, start14);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallEnd, 0, end14);
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan14ID, baseID);
      aiPlanSetEscrowID(wallPlan14ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan14ID, pri);
      aiPlanSetActive(wallPlan14ID, true);
   }

   // segment 15
   int wallPlan15ID = aiPlanCreate("WallInBase15", cPlanBuildWall);
   if (wallPlan15ID != -1)
   {
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan15ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallStart, 0, start15);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallEnd, 0, end15);
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan15ID, baseID);
      aiPlanSetEscrowID(wallPlan15ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan15ID, pri);
      aiPlanSetActive(wallPlan15ID, true);
   }

   // segment 16
   int wallPlan16ID = aiPlanCreate("WallInBase16", cPlanBuildWall);
   if (wallPlan16ID != -1)
   {
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan16ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallStart, 0, start16);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallEnd, 0, end16);
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan16ID, baseID);
      aiPlanSetEscrowID(wallPlan16ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan16ID, pri);
      aiPlanSetActive(wallPlan16ID, true);
   }

   // segment 17
   int wallPlan17ID = aiPlanCreate("WallInBase17", cPlanBuildWall);
   if (wallPlan17ID != -1)
   {
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan17ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallStart, 0, start17);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallEnd, 0, end17);
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan17ID, baseID);
      aiPlanSetEscrowID(wallPlan17ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan17ID, pri);
      aiPlanSetActive(wallPlan17ID, true);
   }

   // segment 18
   int wallPlan18ID = aiPlanCreate("WallInBase18", cPlanBuildWall);
   if (wallPlan18ID != -1)
   {
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan18ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallStart, 0, start18);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallEnd, 0, end18);
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan18ID, baseID);
      aiPlanSetEscrowID(wallPlan18ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan18ID, pri);
      aiPlanSetActive(wallPlan18ID, true);
   }

   // segment 19
   int wallPlan19ID = aiPlanCreate("WallInBase19", cPlanBuildWall);
   if (wallPlan19ID != -1)
   {
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan19ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallStart, 0, start19);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallEnd, 0, end19);
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan19ID, baseID);
      aiPlanSetEscrowID(wallPlan19ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan19ID, pri);
      aiPlanSetActive(wallPlan19ID, true);
   }

   // segment 20
   int wallPlan20ID = aiPlanCreate("WallInBase20", cPlanBuildWall);
   if (wallPlan20ID != -1)
   {
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan20ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallStart, 0, start20);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallEnd, 0, end20);
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan20ID, baseID);
      aiPlanSetEscrowID(wallPlan20ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan20ID, pri);
      aiPlanSetActive(wallPlan20ID, true);
   }

   // segment 21
   int wallPlan21ID = aiPlanCreate("WallInBase21", cPlanBuildWall);
   if (wallPlan21ID != -1)
   {
      aiPlanSetVariableInt(wallPlan21ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan21ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan21ID, cBuildWallPlanWallStart, 0, start21);
      aiPlanSetVariableVector(wallPlan21ID, cBuildWallPlanWallEnd, 0, end21);
      aiPlanSetVariableInt(wallPlan21ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan21ID, baseID);
      aiPlanSetEscrowID(wallPlan21ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan21ID, pri);
      aiPlanSetActive(wallPlan21ID, true);
   }

   // segment 22
   int wallPlan22ID = aiPlanCreate("WallInBase22", cPlanBuildWall);
   if (wallPlan22ID != -1)
   {
      aiPlanSetVariableInt(wallPlan22ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan22ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan22ID, cBuildWallPlanWallStart, 0, start22);
      aiPlanSetVariableVector(wallPlan22ID, cBuildWallPlanWallEnd, 0, end22);
      aiPlanSetVariableInt(wallPlan22ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan22ID, baseID);
      aiPlanSetEscrowID(wallPlan22ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan22ID, pri);
      aiPlanSetActive(wallPlan22ID, true);
   }

   // segment 23
   int wallPlan23ID = aiPlanCreate("WallInBase23", cPlanBuildWall);
   if (wallPlan23ID != -1)
   {
      aiPlanSetVariableInt(wallPlan23ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan23ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan23ID, cBuildWallPlanWallStart, 0, start23);
      aiPlanSetVariableVector(wallPlan23ID, cBuildWallPlanWallEnd, 0, end23);
      aiPlanSetVariableInt(wallPlan23ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan23ID, baseID);
      aiPlanSetEscrowID(wallPlan23ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan23ID, pri);
      aiPlanSetActive(wallPlan23ID, true);
   }

   // segment 24
   int wallPlan24ID = aiPlanCreate("WallInBase24", cPlanBuildWall);
   if (wallPlan24ID != -1)
   {
      aiPlanSetVariableInt(wallPlan24ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan24ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan24ID, cBuildWallPlanWallStart, 0, start24);
      aiPlanSetVariableVector(wallPlan24ID, cBuildWallPlanWallEnd, 0, end24);
      aiPlanSetVariableInt(wallPlan24ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan24ID, baseID);
      aiPlanSetEscrowID(wallPlan24ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan24ID, pri);
      aiPlanSetActive(wallPlan24ID, true);
   }

   // segment 25
   int wallPlan25ID = aiPlanCreate("WallInBase25", cPlanBuildWall);
   if (wallPlan25ID != -1)
   {
      aiPlanSetVariableInt(wallPlan25ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan25ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan25ID, cBuildWallPlanWallStart, 0, start25);
      aiPlanSetVariableVector(wallPlan25ID, cBuildWallPlanWallEnd, 0, end25);
      aiPlanSetVariableInt(wallPlan25ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan25ID, baseID);
      aiPlanSetEscrowID(wallPlan25ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan25ID, pri);
      aiPlanSetActive(wallPlan25ID, true);
   }

   // segment 26
   int wallPlan26ID = aiPlanCreate("WallInBase26", cPlanBuildWall);
   if (wallPlan26ID != -1)
   {
      aiPlanSetVariableInt(wallPlan26ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan26ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan26ID, cBuildWallPlanWallStart, 0, start26);
      aiPlanSetVariableVector(wallPlan26ID, cBuildWallPlanWallEnd, 0, end26);
      aiPlanSetVariableInt(wallPlan26ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan26ID, baseID);
      aiPlanSetEscrowID(wallPlan26ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan26ID, pri);
      aiPlanSetActive(wallPlan26ID, true);
   }

   return;

}

//==============================================================================
/* haudOverlappingRingFort
   builds an overlapping ring fort in the style used by the Haudenesaune

   This fort does not need gates
*/
//==============================================================================
void haudOverlappingRingFort(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 2.0, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0, bool ravelin = false)
{
   if (position == cInvalidVector){
      return;}

   if (baseID < 0){
      baseID = gForwardBaseID;}

   if (baseID < 0){
      baseID = kbBaseGetMainID(cMyID);}


   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = angle + 3.14;
   }
   else
   {
      angle = angle;
   } 

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX + 2.549 * scale, positionY, positionZ + 4.363 * scale); 
         vector towerPos2 = xsVectorSet(positionX - 2.549 * scale, positionY, positionZ - 4.363 * scale); 
      }
      else
      {
         towerPos2 = xsVectorSet(positionX + 2.549 * scale, positionY, positionZ + 4.363 * scale); 
         towerPos1 = xsVectorSet(positionX - 2.549 * scale, positionY, positionZ - 4.363 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos2 = cInvalidVector;
      }
      cannonCorners(pri, towerPos2, towerPos1);
   }

   // The center position is "position"
   // Base consists of 12 segments
   vector start1 = xsVectorSet(positionX, positionY, positionZ - 10.0 * scale);
   vector end1 = xsVectorSet(positionX + 5.878 * scale, positionY, positionZ - 8.09 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX + 9.511 * scale, positionY, positionZ - 3.09 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX + 9.511 * scale, positionY, positionZ + 3.09 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX + 5.878 * scale, positionY, positionZ + 8.09 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX + 3.5 * scale, positionY, positionZ + 8.863 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX - 0.78 * scale, positionY, positionZ + 7.472 * scale);

   vector start7 = xsVectorSet(positionX, positionY, positionZ + 10.0 * scale);
   vector end7 = xsVectorSet(positionX - 5.878 * scale, positionY, positionZ + 8.09 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX - 9.511 * scale, positionY, positionZ + 3.09 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX - 9.511 * scale, positionY, positionZ - 3.09 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX - 5.878 * scale, positionY, positionZ - 8.09 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX - 3.5 * scale, positionY, positionZ - 8.863 * scale);

   vector start12 = end11;
   vector end12 = xsVectorSet(positionX + 0.78 * scale, positionY, positionZ - 7.472 * scale);

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);

   start9 = rotateByReferencePoint(position, start9 - position, angle);
   end9 = rotateByReferencePoint(position, end9 - position, angle);

   start10 = rotateByReferencePoint(position, start10 - position, angle);
   end10 = rotateByReferencePoint(position, end10 - position, angle);

   start11 = rotateByReferencePoint(position, start11 - position, angle);
   end11 = rotateByReferencePoint(position, end11 - position, angle);

   start12 = rotateByReferencePoint(position, start12 - position, angle);
   end12 = rotateByReferencePoint(position, end12 - position, angle);


   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   return;

}

//==============================================================================
/* sumterFort
   builds the Fort Sumpter pattern. There are no ravelins and 
   only 2 tower positions

   Orientation is random. Doesn't "face" enemy positions
*/
//==============================================================================
void sumterFort(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 1.5, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0, bool ravelin = false)
{
   if (position == cInvalidVector){
      return;}

   if (baseID < 0){
      baseID = gForwardBaseID;}

   if (baseID < 0){
      baseID = kbBaseGetMainID(cMyID);}


   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = aiRandFloat(0.0, 6.28);/*atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = 6.28 - angle - 3.14 * .25;
   }
   else
   {
      angle = angle - 3.14 * .25;
   } */

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX - 13.0 * scale, positionY, positionZ - 14.0 * scale); 
         vector towerPos2 = xsVectorSet(positionX + 11.0 * scale, positionY, positionZ - 14.0 * scale); 
      }
      else
      {
         towerPos2 = xsVectorSet(positionX - 13.0 * scale, positionY, positionZ - 14.0 * scale); 
         towerPos1 = xsVectorSet(positionX + 11.0 * scale, positionY, positionZ - 14.0 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos2 = cInvalidVector;
      }
      cannonCorners(pri, towerPos2, towerPos1);
   }

   // The center position is "position"
   // Base consists of 12 segments
   vector start1 = xsVectorSet(positionX - 16 * scale, positionY, positionZ - 1.0 * scale);
   vector end1 = xsVectorSet(positionX - 4.0 * scale, positionY, positionZ + 11.0 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX + 4.0 * scale, positionY, positionZ + 11.0 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX + 16.0 * scale, positionY, positionZ - 1.0 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX + 16.0 * scale, positionY, positionZ - 13.0 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX + 12.0 * scale, positionY, positionZ - 17.0 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX - 12.0 * scale, positionY, positionZ - 17.0 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX - 16.0 * scale, positionY, positionZ - 13.0 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX - 16.0 * scale, positionY, positionZ - 1.0 * scale);

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);


   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   return;

}

//==============================================================================
/* ticonderogaStarFort
   builds the Ticonderoga Star Fort pattern. Contains two Ravelins and a 
   somewhat lopsided 4 star pattern
*/
//==============================================================================
void ticonderogaStarFort(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 2.0, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0, bool ravelin = false)
{
   if (position == cInvalidVector){
      return;}

   if (baseID < 0){
      baseID = gForwardBaseID;}

   if (baseID < 0){
      baseID = kbBaseGetMainID(cMyID);}


   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = angle + 3.14;
   }
   else
   {
      angle = angle;
   } 

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX - 10.651 * scale, positionY, positionZ + 9.093 * scale); 
         vector towerPos2 = xsVectorSet(positionX + 10.022 * scale, positionY, positionZ + 8.585 * scale); 
         vector towerPos3 = xsVectorSet(positionX + 10.022 * scale, positionY, positionZ - 9.331 * scale); 
         vector towerPos4 = xsVectorSet(positionX - 11.217 * scale, positionY, positionZ - 8.368 * scale); 
      }
      else
      {
         towerPos2 = xsVectorSet(positionX - 10.651 * scale, positionY, positionZ + 9.093 * scale); 
         towerPos1 = xsVectorSet(positionX + 10.022 * scale, positionY, positionZ + 8.585 * scale); 
         towerPos4 = xsVectorSet(positionX + 10.022 * scale, positionY, positionZ - 9.331 * scale); 
         towerPos3 = xsVectorSet(positionX - 11.217 * scale, positionY, positionZ - 8.368 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);
      towerPos3 = rotateByReferencePoint(position, towerPos3 - position, angle);
      towerPos4 = rotateByReferencePoint(position, towerPos4 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
      if (towerNum >= 3){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos3, 1);
      }
      if (towerNum >= 4){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos4, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos2 = cInvalidVector;
         towerPos3 = cInvalidVector;
         towerPos4 = cInvalidVector;
      }
      else if (cannonNum == 2)
      {
         towerPos2 = cInvalidVector;
         towerPos3 = cInvalidVector;
      }
      else if (cannonNum == 3)
      {
         towerPos2 = cInvalidVector;
      }
      cannonCorners(pri, towerPos4, towerPos3, towerPos2, towerPos1);
   }

   // The center position is "position"
   // Base consists of 12 segments
   vector start1 = xsVectorSet(positionX - 7.764 * scale, positionY, positionZ - 8.02 * scale);
   vector end1 = xsVectorSet(positionX + 5.845 * scale, positionY, positionZ -8.02 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX + 6.266 * scale, positionY, positionZ - 12.113 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX + 15.112 * scale, positionY, positionZ - 14.574 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX + 13.189 * scale, positionY, positionZ - 6.171 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX + 10.025 * scale, positionY, positionZ - 5.537 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX + 10.025 * scale, positionY, positionZ + 5.305 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX + 13.372 * scale, positionY, positionZ + 5.396 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX + 15.415 * scale, positionY, positionZ + 13.05 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX + 6.331 * scale, positionY, positionZ + 10.415 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX + 5.991 * scale, positionY, positionZ + 8.02 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX - 6.551 * scale, positionY, positionZ + 8.02 * scale);

   vector start12 = end11;
   vector end12 = xsVectorSet(positionX - 6.909 * scale, positionY, positionZ + 11.187 * scale);

   vector start13 = end12;
   vector end13 = xsVectorSet(positionX - 15.229 * scale, positionY, positionZ + 13.646 * scale);

   vector start14 = end13;
   vector end14 = xsVectorSet(positionX - 13.797 * scale, positionY, positionZ + 5.911 * scale);

   vector start15 = end14;
   vector end15 = xsVectorSet(positionX - 10.881 * scale, positionY, positionZ + 5.732 * scale);

   vector start16 = end15;
   vector end16 = xsVectorSet(positionX - 10.881 * scale, positionY, positionZ - 4.551 * scale);

   vector start17 = end16;
   vector end17 = xsVectorSet(positionX - 13.335 * scale, positionY, positionZ - 4.551 * scale);

   vector start18 = end17;
   vector end18 = xsVectorSet(positionX - 15.52 * scale, positionY, positionZ - 13.508 * scale);

   vector start19 = end18;
   vector end19 = xsVectorSet(positionX - 7.764 * scale, positionY, positionZ - 11.269 * scale);

   vector start20 = end19;
   vector end20 = start1;

   if (ravelin == true)
   {
      vector start21 = xsVectorSet(positionX - 6.391 * scale, positionY, positionZ + 14.303 * scale);
      vector end21 = xsVectorSet(positionX - 0.043 * scale, positionY, positionZ + 19.336 * scale);

      vector start22 = end21;
      vector end22 = xsVectorSet(positionX + 7.049 * scale, positionY, positionZ + 14.046 * scale);

      vector start23 = xsVectorSet(positionX + 17.524 * scale, positionY, positionZ + 7.168 * scale);
      vector end23 = xsVectorSet(positionX + 22.768 * scale, positionY, positionZ - 0.588 * scale);

      vector start24 = end23;
      vector end24 = xsVectorSet(positionX + 16.785 * scale, positionY, positionZ - 6.165 * scale);
   }

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);

   start9 = rotateByReferencePoint(position, start9 - position, angle);
   end9 = rotateByReferencePoint(position, end9 - position, angle);

   start10 = rotateByReferencePoint(position, start10 - position, angle);
   end10 = rotateByReferencePoint(position, end10 - position, angle);

   start11 = rotateByReferencePoint(position, start11 - position, angle);
   end11 = rotateByReferencePoint(position, end11 - position, angle);

   start12 = rotateByReferencePoint(position, start12 - position, angle);
   end12 = rotateByReferencePoint(position, end12 - position, angle);

   start13 = rotateByReferencePoint(position, start13 - position, angle);
   end13 = rotateByReferencePoint(position, end13 - position, angle);

   start14 = rotateByReferencePoint(position, start14 - position, angle);
   end14 = rotateByReferencePoint(position, end14 - position, angle);

   start15 = rotateByReferencePoint(position, start15 - position, angle);
   end15 = rotateByReferencePoint(position, end15 - position, angle);

   start16 = rotateByReferencePoint(position, start16 - position, angle);
   end16 = rotateByReferencePoint(position, end16 - position, angle);

   start17 = rotateByReferencePoint(position, start17 - position, angle);
   end17 = rotateByReferencePoint(position, end17 - position, angle);

   start18 = rotateByReferencePoint(position, start18 - position, angle);
   end18 = rotateByReferencePoint(position, end18 - position, angle);

   start19 = rotateByReferencePoint(position, start19 - position, angle);
   end19 = rotateByReferencePoint(position, end19 - position, angle);

   start20 = rotateByReferencePoint(position, start20 - position, angle);
   end20 = rotateByReferencePoint(position, end20 - position, angle);

   if (ravelin == true)
   {
      start21 = rotateByReferencePoint(position, start21 - position, angle);
      end21 = rotateByReferencePoint(position, end21 - position, angle);

      start22 = rotateByReferencePoint(position, start22 - position, angle);
      end22 = rotateByReferencePoint(position, end22 - position, angle);

      start23 = rotateByReferencePoint(position, start23 - position, angle);
      end23 = rotateByReferencePoint(position, end23 - position, angle);

      start24 = rotateByReferencePoint(position, start24 - position, angle);
      end24 = rotateByReferencePoint(position, end24 - position, angle);
   }


   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   // segment 13
   int wallPlan13ID = aiPlanCreate("WallInBase13", cPlanBuildWall);
   if (wallPlan13ID != -1)
   {
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan13ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallStart, 0, start13);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallEnd, 0, end13);
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan13ID, baseID);
      aiPlanSetEscrowID(wallPlan13ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan13ID, pri);
      aiPlanSetActive(wallPlan13ID, true);
   }

   // segment 14
   int wallPlan14ID = aiPlanCreate("WallInBase14", cPlanBuildWall);
   if (wallPlan14ID != -1)
   {
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan14ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallStart, 0, start14);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallEnd, 0, end14);
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan14ID, baseID);
      aiPlanSetEscrowID(wallPlan14ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan14ID, pri);
      aiPlanSetActive(wallPlan14ID, true);
   }

   // segment 15
   int wallPlan15ID = aiPlanCreate("WallInBase15", cPlanBuildWall);
   if (wallPlan15ID != -1)
   {
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan15ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallStart, 0, start15);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallEnd, 0, end15);
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan15ID, baseID);
      aiPlanSetEscrowID(wallPlan15ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan15ID, pri);
      aiPlanSetActive(wallPlan15ID, true);
   }

   // segment 16
   int wallPlan16ID = aiPlanCreate("WallInBase16", cPlanBuildWall);
   if (wallPlan16ID != -1)
   {
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan16ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallStart, 0, start16);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallEnd, 0, end16);
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan16ID, baseID);
      aiPlanSetEscrowID(wallPlan16ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan16ID, pri);
      aiPlanSetActive(wallPlan16ID, true);
   }

   // segment 17
   int wallPlan17ID = aiPlanCreate("WallInBase17", cPlanBuildWall);
   if (wallPlan17ID != -1)
   {
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan17ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallStart, 0, start17);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallEnd, 0, end17);
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan17ID, baseID);
      aiPlanSetEscrowID(wallPlan17ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan17ID, pri);
      aiPlanSetActive(wallPlan17ID, true);
   }

   // segment 18
   int wallPlan18ID = aiPlanCreate("WallInBase18", cPlanBuildWall);
   if (wallPlan18ID != -1)
   {
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan18ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallStart, 0, start18);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallEnd, 0, end18);
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan18ID, baseID);
      aiPlanSetEscrowID(wallPlan18ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan18ID, pri);
      aiPlanSetActive(wallPlan18ID, true);
   }

   // segment 19
   int wallPlan19ID = aiPlanCreate("WallInBase19", cPlanBuildWall);
   if (wallPlan19ID != -1)
   {
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan19ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallStart, 0, start19);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallEnd, 0, end19);
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan19ID, baseID);
      aiPlanSetEscrowID(wallPlan19ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan19ID, pri);
      aiPlanSetActive(wallPlan19ID, true);
   }

   // segment 20
   int wallPlan20ID = aiPlanCreate("WallInBase20", cPlanBuildWall);
   if (wallPlan20ID != -1)
   {
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan20ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallStart, 0, start20);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallEnd, 0, end20);
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan20ID, baseID);
      aiPlanSetEscrowID(wallPlan20ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan20ID, pri);
      aiPlanSetActive(wallPlan20ID, true);
   }

   if (ravelin == true)
   {
      // segment 21
      int wallPlan21ID = aiPlanCreate("WallInBase21", cPlanBuildWall);
      if (wallPlan21ID != -1)
      {
         aiPlanSetVariableInt(wallPlan21ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan21ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan21ID, cBuildWallPlanWallStart, 0, start21);
         aiPlanSetVariableVector(wallPlan21ID, cBuildWallPlanWallEnd, 0, end21);
         aiPlanSetVariableInt(wallPlan21ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan21ID, baseID);
         aiPlanSetEscrowID(wallPlan21ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan21ID, pri);
         aiPlanSetActive(wallPlan21ID, true);
      }

      // segment 22
      int wallPlan22ID = aiPlanCreate("WallInBase22", cPlanBuildWall);
      if (wallPlan22ID != -1)
      {
         aiPlanSetVariableInt(wallPlan22ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan22ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan22ID, cBuildWallPlanWallStart, 0, start22);
         aiPlanSetVariableVector(wallPlan22ID, cBuildWallPlanWallEnd, 0, end22);
         aiPlanSetVariableInt(wallPlan22ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan22ID, baseID);
         aiPlanSetEscrowID(wallPlan22ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan22ID, pri);
         aiPlanSetActive(wallPlan22ID, true);
      }

      // segment 23
      int wallPlan23ID = aiPlanCreate("WallInBase23", cPlanBuildWall);
      if (wallPlan23ID != -1)
      {
         aiPlanSetVariableInt(wallPlan23ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan23ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan23ID, cBuildWallPlanWallStart, 0, start23);
         aiPlanSetVariableVector(wallPlan23ID, cBuildWallPlanWallEnd, 0, end23);
         aiPlanSetVariableInt(wallPlan23ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan23ID, baseID);
         aiPlanSetEscrowID(wallPlan23ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan23ID, pri);
         aiPlanSetActive(wallPlan23ID, true);
      }

      // segment 24
      int wallPlan24ID = aiPlanCreate("WallInBase24", cPlanBuildWall);
      if (wallPlan24ID != -1)
      {
         aiPlanSetVariableInt(wallPlan24ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan24ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan24ID, cBuildWallPlanWallStart, 0, start24);
         aiPlanSetVariableVector(wallPlan24ID, cBuildWallPlanWallEnd, 0, end24);
         aiPlanSetVariableInt(wallPlan24ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan24ID, baseID);
         aiPlanSetEscrowID(wallPlan24ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan24ID, pri);
         aiPlanSetActive(wallPlan24ID, true);
      }
   }

   return;

}

//==============================================================================
/* buildCrownwork
   builds a crownwork. Needs the fort center and desired position, so it can
   rotate the correct amount
*/
//==============================================================================
void buildCrownwork(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 2.0, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0, bool ravelin = false)
{
   if (position == cInvalidVector){
      return;}

   if (baseID < 0){
      baseID = gForwardBaseID;}

   if (baseID < 0){
      baseID = kbBaseGetMainID(cMyID);}


   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   //angle = angle - 3.14 * .25;
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = angle + 3.14;
   }
   else
   {
      angle = angle;
   } 
   /*aiChat(1, "angle: " + angle);
   aiChat(1, "Math: " + (xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   aiChat(1, "fortX: " + xsVectorGetX(fortCenter) + " fortZ: " + xsVectorGetZ(fortCenter) + " positionX: " + positionX + " positionZ: " + positionZ);
   sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, position);*/

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX, positionY, positionZ + 4.87 * scale); 
         vector towerPos2 = xsVectorSet(positionX - 6.0 * scale, positionY, positionZ + 2.5 * scale); 
         vector towerPos3 = xsVectorSet(positionX + 6.0 * scale, positionY, positionZ + 2.5 * scale); 
      }
      else
      {
         towerPos1 = xsVectorSet(positionX, positionY, positionZ + 4.87 * scale); 
         towerPos3 = xsVectorSet(positionX - 6.0 * scale, positionY, positionZ + 2.5 * scale); 
         towerPos2 = xsVectorSet(positionX + 6.0 * scale, positionY, positionZ + 2.5 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);
      towerPos3 = rotateByReferencePoint(position, towerPos3 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
      if (towerNum >= 3){
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos3, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos2 = cInvalidVector;
      }
      cannonCorners(pri, towerPos3, towerPos2);
   }

   // The center position is "position"
   // Base consists of 12 segments
   vector start1 = xsVectorSet(positionX - 6.5 * scale, positionY, positionZ - 0.0 * scale);
   vector end1 = xsVectorSet(positionX - 7.061 * scale, positionY, positionZ + 3.181 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX - 5.337 * scale, positionY, positionZ + 3.485 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX - 4.915 * scale, positionY, positionZ + 2.578 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX - 1.969 * scale, positionY, positionZ + 3.952 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX - 2.392 * scale, positionY, positionZ + 4.858 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX + 0.0 * scale, positionY, positionZ + 7.25 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX + 2.392 * scale, positionY, positionZ + 4.858 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX + 1.969 * scale, positionY, positionZ + 3.952 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX + 4.915 * scale, positionY, positionZ + 2.578 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX + 5.337 * scale, positionY, positionZ + 3.485 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX + 7.061 * scale, positionY, positionZ + 3.181 * scale);

   vector start12 = end11;
   vector end12 = xsVectorSet(positionX + 6.5 * scale, positionY, positionZ - 0.0 * scale);

   if (ravelin == true)
   {
      vector start13 = xsVectorSet(positionX - 5.971 * scale, positionY, positionZ + 4.844 * scale);
      vector end13 = xsVectorSet(positionX - 5.317 * scale, positionY, positionZ + 7.286 * scale);

      vector start14 = end13;
      vector end14 = xsVectorSet(positionX - 3.026 * scale, positionY, positionZ + 6.218 * scale);

      vector start15 = xsVectorSet(positionX + 5.971 * scale, positionY, positionZ + 4.844 * scale);
      vector end15 = xsVectorSet(positionX + 5.317 * scale, positionY, positionZ + 7.286 * scale);

      vector start16 = end15;
      vector end16 = xsVectorSet(positionX + 3.026 * scale, positionY, positionZ + 6.218 * scale);
   }

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);

   start9 = rotateByReferencePoint(position, start9 - position, angle);
   end9 = rotateByReferencePoint(position, end9 - position, angle);

   start10 = rotateByReferencePoint(position, start10 - position, angle);
   end10 = rotateByReferencePoint(position, end10 - position, angle);

   start11 = rotateByReferencePoint(position, start11 - position, angle);
   end11 = rotateByReferencePoint(position, end11 - position, angle);

   start12 = rotateByReferencePoint(position, start12 - position, angle);
   end12 = rotateByReferencePoint(position, end12 - position, angle);

   if (ravelin == true)
   {
      start13 = rotateByReferencePoint(position, start13 - position, angle);
      end13 = rotateByReferencePoint(position, end13 - position, angle);

      start14 = rotateByReferencePoint(position, start14 - position, angle);
      end14 = rotateByReferencePoint(position, end14 - position, angle);

      start15 = rotateByReferencePoint(position, start15 - position, angle);
      end15 = rotateByReferencePoint(position, end15 - position, angle);

      start16 = rotateByReferencePoint(position, start16 - position, angle);
      end16 = rotateByReferencePoint(position, end16 - position, angle);
   }


   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 0);
      //aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   if (ravelin == true)
   {
      // segment 13
      int wallPlan13ID = aiPlanCreate("WallInBase13", cPlanBuildWall);
      if (wallPlan13ID != -1)
      {
         aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan13ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallStart, 0, start13);
         aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallEnd, 0, end13);
         aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan13ID, baseID);
         aiPlanSetEscrowID(wallPlan13ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan13ID, pri);
         aiPlanSetActive(wallPlan13ID, true);
      }

      // segment 14
      int wallPlan14ID = aiPlanCreate("WallInBase14", cPlanBuildWall);
      if (wallPlan14ID != -1)
      {
         aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan14ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallStart, 0, start14);
         aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallEnd, 0, end14);
         aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan14ID, baseID);
         aiPlanSetEscrowID(wallPlan14ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan14ID, pri);
         aiPlanSetActive(wallPlan14ID, true);
      }

      // segment 15
      int wallPlan15ID = aiPlanCreate("WallInBase15", cPlanBuildWall);
      if (wallPlan15ID != -1)
      {
         aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan15ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallStart, 0, start15);
         aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallEnd, 0, end15);
         aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan15ID, baseID);
         aiPlanSetEscrowID(wallPlan15ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan15ID, pri);
         aiPlanSetActive(wallPlan15ID, true);
      }

      // segment 16
      int wallPlan16ID = aiPlanCreate("WallInBase16", cPlanBuildWall);
      if (wallPlan16ID != -1)
      {
         aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
         aiPlanAddUnitType(wallPlan16ID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallStart, 0, start16);
         aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallEnd, 0, end16);
         aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanNumberOfGates, 0, 0);
         aiPlanSetBaseID(wallPlan16ID, baseID);
         aiPlanSetEscrowID(wallPlan16ID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlan16ID, pri);
         aiPlanSetActive(wallPlan16ID, true);
      }
   }

   return;

}

//==============================================================================
/* buildFourCornerStarFort
   builds a star fort with 2 outposts

   scale = 1.4 is the smallest fort that still has gates
   scale = 2.8 comfortably fits towers
   scale >= 2.4 can fit outposts on corners
*/
//==============================================================================
void buildFourCornerStarFort(vector position = cInvalidVector, vector fortCenter = cInvalidVector, int baseID = -1, float scale = 1.4, int pri = 80, int towerNum = 0, int cannonNum = 0, int crownwork = 0)
{
   if (position == cInvalidVector)
   {
      position = selectForwardBaseLocation();
   }

   if (baseID < 0)
   {
      baseID = gForwardBaseID;
   }

   if (baseID < 0)
   {
      baseID = kbBaseGetMainID(cMyID);
   }

   //sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, position);

   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);

   float angle = atan((xsVectorGetZ(fortCenter) - positionZ) / (xsVectorGetX(fortCenter) - positionX));
   if ((xsVectorGetX(fortCenter) - positionX) < 0 )
   {
      angle = angle + 3.14;
   }
   else
   {
      angle = angle;
   } 

   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   vector towerPos1 = cInvalidVector;
   vector towerPos2 = cInvalidVector; 
   vector towerPos3 = cInvalidVector; 
   vector towerPos4 = cInvalidVector; 
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(4);
      if (switchInt == 0)
      {
         towerPos1 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 7.5 * scale); 
         towerPos2 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos3 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos4 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale); 
      }
      else if (switchInt == 1)
      {
         towerPos2 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 7.5 * scale); 
         towerPos4 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos3 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos1 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale); 
      }
      else
      {
         towerPos3 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 7.5 * scale); 
         towerPos1 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos4 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale); 
         towerPos2 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale); 
      }

      // Rotate
      towerPos1 = rotateByReferencePoint(position, towerPos1 - position, angle);
      towerPos2 = rotateByReferencePoint(position, towerPos2 - position, angle);
      towerPos3 = rotateByReferencePoint(position, towerPos3 - position, angle);
      towerPos4 = rotateByReferencePoint(position, towerPos4 - position, angle);

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2)
      {
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }

      if (towerNum >= 3)
      {
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos3, 1);
      }

      if (towerNum >= 4)
      {
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos4, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos1 = cInvalidVector;
         towerPos2 = cInvalidVector;
         towerPos3 = cInvalidVector;
      }
      else if (cannonNum == 2)
      {
         towerPos1 = cInvalidVector;
         towerPos2 = cInvalidVector;
      }
      else if (cannonNum == 3)
      {
         towerPos1 = cInvalidVector;
      }

      cannonCorners(pri, towerPos4, towerPos3, towerPos2, towerPos1);
   }

   if (crownwork > 0)
   {
      vector crownworkLoc1 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale);
      vector crownworkLoc2 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale);
      if (switchInt > 2)
      {
         crownworkLoc2 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale);
         crownworkLoc1 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale);
      }
      buildCrownwork(crownworkLoc1, position, baseID, 2 * scale * 2, 99, 1, 0, true);
      if (crownwork > 1)
      {
         buildCrownwork(crownworkLoc2, position, baseID, 2 * scale * 2, 99, 1, 0, true);
      }
   }

   // The center position is "position"
   // Base consists of 20 segments for 4 corner towers
   vector start1 = xsVectorSet(positionX - 4.0 * scale, positionY, positionZ - 7.5 * scale);
   vector end1 = xsVectorSet(positionX + 4.0 * scale, positionY, positionZ - 7.5 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX + 7.0 * scale, positionY, positionZ - 10.5 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ - 10.5 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ - 7.0 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 4.0 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 4.0 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ + 7.0 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ + 10.5 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX + 7.0 * scale, positionY, positionZ + 10.5 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX + 4.0 * scale, positionY, positionZ + 7.5 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX - 4.0 * scale, positionY, positionZ + 7.5 * scale);

   vector start12 = end11;
   vector end12 = xsVectorSet(positionX - 7.0 * scale, positionY, positionZ + 10.5 * scale);

   vector start13 = end12;
   vector end13 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ + 10.5 * scale);

   vector start14 = end13;
   vector end14 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ + 7.0 * scale);

   vector start15 = end14;
   vector end15 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 4.0 * scale);

   vector start16 = end15;
   vector end16 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 4.0 * scale);

   vector start17 = end16;
   vector end17 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ - 7.0 * scale);

   vector start18 = end17;
   vector end18 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ - 10.5 * scale);

   vector start19 = end18;
   vector end19 = xsVectorSet(positionX - 7.0 * scale, positionY, positionZ - 10.5 * scale);

   vector start20 = end19;
   vector end20 = start1;

   // Rotate points
   start1 = rotateByReferencePoint(position, start1 - position, angle);
   end1 = rotateByReferencePoint(position, end1 - position, angle);

   start2 = rotateByReferencePoint(position, start2 - position, angle);
   end2 = rotateByReferencePoint(position, end2 - position, angle);

   start3 = rotateByReferencePoint(position, start3 - position, angle);
   end3 = rotateByReferencePoint(position, end3 - position, angle);

   start4 = rotateByReferencePoint(position, start4 - position, angle);
   end4 = rotateByReferencePoint(position, end4 - position, angle);

   start5 = rotateByReferencePoint(position, start5 - position, angle);
   end5 = rotateByReferencePoint(position, end5 - position, angle);

   start6 = rotateByReferencePoint(position, start6 - position, angle);
   end6 = rotateByReferencePoint(position, end6 - position, angle);

   start7 = rotateByReferencePoint(position, start7 - position, angle);
   end7 = rotateByReferencePoint(position, end7 - position, angle);

   start8 = rotateByReferencePoint(position, start8 - position, angle);
   end8 = rotateByReferencePoint(position, end8 - position, angle);

   start9 = rotateByReferencePoint(position, start9 - position, angle);
   end9 = rotateByReferencePoint(position, end9 - position, angle);

   start10 = rotateByReferencePoint(position, start10 - position, angle);
   end10 = rotateByReferencePoint(position, end10 - position, angle);

   start11 = rotateByReferencePoint(position, start11 - position, angle);
   end11 = rotateByReferencePoint(position, end11 - position, angle);

   start12 = rotateByReferencePoint(position, start12 - position, angle);
   end12 = rotateByReferencePoint(position, end12 - position, angle);

   start13 = rotateByReferencePoint(position, start13 - position, angle);
   end13 = rotateByReferencePoint(position, end13 - position, angle);

   start14 = rotateByReferencePoint(position, start14 - position, angle);
   end14 = rotateByReferencePoint(position, end14 - position, angle);

   start15 = rotateByReferencePoint(position, start15 - position, angle);
   end15 = rotateByReferencePoint(position, end15 - position, angle);

   start16 = rotateByReferencePoint(position, start16 - position, angle);
   end16 = rotateByReferencePoint(position, end16 - position, angle);

   start17 = rotateByReferencePoint(position, start17 - position, angle);
   end17 = rotateByReferencePoint(position, end17 - position, angle);

   start18 = rotateByReferencePoint(position, start18 - position, angle);
   end18 = rotateByReferencePoint(position, end18 - position, angle);

   start19 = rotateByReferencePoint(position, start19 - position, angle);
   end19 = rotateByReferencePoint(position, end19 - position, angle);

   start20 = rotateByReferencePoint(position, start20 - position, angle);
   end20 = rotateByReferencePoint(position, end20 - position, angle);

   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan3ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan3ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan4ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan4ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan5ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan5ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan6ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan6ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan7ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan7ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan8ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan8ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan9ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan9ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan10ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan10ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan11ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan11ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan12ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan12ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   // segment 13
   int wallPlan13ID = aiPlanCreate("WallInBase13", cPlanBuildWall);
   if (wallPlan13ID != -1)
   {
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan13ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallStart, 0, start13);
      aiPlanSetVariableVector(wallPlan13ID, cBuildWallPlanWallEnd, 0, end13);
      aiPlanSetVariableInt(wallPlan13ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan13ID, baseID);
      aiPlanSetEscrowID(wallPlan13ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan13ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan13ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan13ID, pri);
      aiPlanSetActive(wallPlan13ID, true);
   }

   // segment 14
   int wallPlan14ID = aiPlanCreate("WallInBase14", cPlanBuildWall);
   if (wallPlan14ID != -1)
   {
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan14ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallStart, 0, start14);
      aiPlanSetVariableVector(wallPlan14ID, cBuildWallPlanWallEnd, 0, end14);
      aiPlanSetVariableInt(wallPlan14ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan14ID, baseID);
      aiPlanSetEscrowID(wallPlan14ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan14ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan14ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan14ID, pri);
      aiPlanSetActive(wallPlan14ID, true);
   }

   // segment 15
   int wallPlan15ID = aiPlanCreate("WallInBase15", cPlanBuildWall);
   if (wallPlan15ID != -1)
   {
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan15ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallStart, 0, start15);
      aiPlanSetVariableVector(wallPlan15ID, cBuildWallPlanWallEnd, 0, end15);
      aiPlanSetVariableInt(wallPlan15ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan15ID, baseID);
      aiPlanSetEscrowID(wallPlan15ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan15ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan15ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan15ID, pri);
      aiPlanSetActive(wallPlan15ID, true);
   }

   // segment 16
   int wallPlan16ID = aiPlanCreate("WallInBase16", cPlanBuildWall);
   if (wallPlan16ID != -1)
   {
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan16ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallStart, 0, start16);
      aiPlanSetVariableVector(wallPlan16ID, cBuildWallPlanWallEnd, 0, end16);
      aiPlanSetVariableInt(wallPlan16ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan16ID, baseID);
      aiPlanSetEscrowID(wallPlan16ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan16ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan16ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan16ID, pri);
      aiPlanSetActive(wallPlan16ID, true);
   }

   // segment 17
   int wallPlan17ID = aiPlanCreate("WallInBase17", cPlanBuildWall);
   if (wallPlan17ID != -1)
   {
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan17ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallStart, 0, start17);
      aiPlanSetVariableVector(wallPlan17ID, cBuildWallPlanWallEnd, 0, end17);
      aiPlanSetVariableInt(wallPlan17ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan17ID, baseID);
      aiPlanSetEscrowID(wallPlan17ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan17ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan17ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan17ID, pri);
      aiPlanSetActive(wallPlan17ID, true);
   }

   // segment 18
   int wallPlan18ID = aiPlanCreate("WallInBase18", cPlanBuildWall);
   if (wallPlan18ID != -1)
   {
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan18ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallStart, 0, start18);
      aiPlanSetVariableVector(wallPlan18ID, cBuildWallPlanWallEnd, 0, end18);
      aiPlanSetVariableInt(wallPlan18ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan18ID, baseID);
      aiPlanSetEscrowID(wallPlan18ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan18ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan18ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan18ID, pri);
      aiPlanSetActive(wallPlan18ID, true);
   }

   // segment 19
   int wallPlan19ID = aiPlanCreate("WallInBase19", cPlanBuildWall);
   if (wallPlan19ID != -1)
   {
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan19ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallStart, 0, start19);
      aiPlanSetVariableVector(wallPlan19ID, cBuildWallPlanWallEnd, 0, end19);
      aiPlanSetVariableInt(wallPlan19ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan19ID, baseID);
      aiPlanSetEscrowID(wallPlan19ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan19ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan19ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan19ID, pri);
      aiPlanSetActive(wallPlan19ID, true);
   }

   // segment 20
   int wallPlan20ID = aiPlanCreate("WallInBase20", cPlanBuildWall);
   if (wallPlan20ID != -1)
   {
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan20ID, gEconUnit, 0, 1, 1);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallStart, 0, start20);
      aiPlanSetVariableVector(wallPlan20ID, cBuildWallPlanWallEnd, 0, end20);
      aiPlanSetVariableInt(wallPlan20ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan20ID, baseID);
      aiPlanSetEscrowID(wallPlan20ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan20ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan20ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan20ID, pri);
      aiPlanSetActive(wallPlan20ID, true);
   }

   return;
}

//==============================================================================
/* buildCornerPairStarFort
   builds a star fort with 2 outposts

   scale = 1 is smallest fort that still has gates
   scale = 4 can fit outposts on corners
*/
//==============================================================================
void buildCornerPairStarFort(vector position = cInvalidVector, int baseID = -1, float scale = 2.4, int pri = 80, 
                              int towerNum = 0, int cannonNum = 0)
{
   if (position == cInvalidVector)
   {
      position = selectForwardBaseLocation();
   }

   if (baseID < 0)
   {
      baseID = gForwardBaseID;
   }

   if (baseID < 0)
   {
      baseID = kbBaseGetMainID(cMyID);
   }

   //sendStatement(1, cAICommPromptToAllyIWillBuildMilitaryBase, position);

   float positionX = xsVectorGetX(position);
   float positionY = xsVectorGetY(position);
   float positionZ = xsVectorGetZ(position);


   // Build specified tower number
   // 2.4 minimum scale number to fit a tower
   if (towerNum > 0)
   {
      int switchInt = aiRandInt(2);
      if (switchInt == 0)
      {
         vector towerPos1 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 7.5 * scale); 
         vector towerPos2 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 7.5 * scale); 
      }
      else
      {
         towerPos2 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 7.5 * scale); 
         towerPos1 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 7.5 * scale); 
      }

      createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos1, 1);
      if (towerNum >= 2)
      {
         createLocationBuildPlan(gTowerUnit, 1, pri, true, cEconomyEscrowID, towerPos2, 1);
      }
   }

   if (cannonNum > 0)
   {
      if (cannonNum == 1)
      {
         towerPos1 = cInvalidVector;
      }
      cannonCorners(pri, towerPos2, towerPos1);
   }

   // The center position is "position"
   // Base consists of 12 segments for 2 corner towers
   vector start1 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ - 7.5 * scale);
   vector end1 = xsVectorSet(positionX + 4.0 * scale, positionY, positionZ - 7.5 * scale);

   vector start2 = end1;
   vector end2 = xsVectorSet(positionX + 7.0 * scale, positionY, positionZ - 10.5 * scale);

   vector start3 = end2;
   vector end3 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ - 10.5 * scale);

   vector start4 = end3;
   vector end4 = xsVectorSet(positionX + 10.5 * scale, positionY, positionZ - 7.0 * scale);

   vector start5 = end4;
   vector end5 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ - 4.0 * scale);

   vector start6 = end5;
   vector end6 = xsVectorSet(positionX + 7.5 * scale, positionY, positionZ + 7.5 * scale);

   vector start7 = end6;
   vector end7 = xsVectorSet(positionX - 4.0 * scale, positionY, positionZ + 7.5 * scale);

   vector start8 = end7;
   vector end8 = xsVectorSet(positionX - 7.0 * scale, positionY, positionZ + 10.5 * scale);

   vector start9 = end8;
   vector end9 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ + 10.5 * scale);

   vector start10 = end9;
   vector end10 = xsVectorSet(positionX - 10.5 * scale, positionY, positionZ + 7.0 * scale);

   vector start11 = end10;
   vector end11 = xsVectorSet(positionX - 7.5 * scale, positionY, positionZ + 4.0 * scale);

   vector start12 = end11;
   vector end12 = start1;

   // segment 1
   int wallPlan1ID = aiPlanCreate("WallInBase1", cPlanBuildWall);
   if (wallPlan1ID != -1)
   {
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan1ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallStart, 0, start1);
      aiPlanSetVariableVector(wallPlan1ID, cBuildWallPlanWallEnd, 0, end1);
      aiPlanSetVariableInt(wallPlan1ID, cBuildWallPlanNumberOfGates, 0, 1);
      //aiPlanSetBaseID(wallPlan1ID, baseID);
      aiPlanSetEscrowID(wallPlan1ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan1ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan1ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan1ID, pri);
      aiPlanSetActive(wallPlan1ID, true);
   }

   // segment 2
   int wallPlan2ID = aiPlanCreate("WallInBase2", cPlanBuildWall);
   if (wallPlan2ID != -1)
   {
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan2ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallStart, 0, start2);
      aiPlanSetVariableVector(wallPlan2ID, cBuildWallPlanWallEnd, 0, end2);
      aiPlanSetVariableInt(wallPlan2ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan2ID, baseID);
      aiPlanSetEscrowID(wallPlan2ID, cEconomyEscrowID);
      aiPlanSetVariableBool(wallPlan2ID, cBuildWallPlanEnRoute, 0, true);
      aiPlanSetVariableFloat(wallPlan2ID, cBuildWallPlanEdgeOfMapBuffer, 0, 0.0);
      aiPlanSetDesiredPriority(wallPlan2ID, pri);
      aiPlanSetActive(wallPlan2ID, true);
   }

   // segment 3
   int wallPlan3ID = aiPlanCreate("WallInBase3", cPlanBuildWall);
   if (wallPlan3ID != -1)
   {
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan3ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallStart, 0, start3);
      aiPlanSetVariableVector(wallPlan3ID, cBuildWallPlanWallEnd, 0, end3);
      aiPlanSetVariableInt(wallPlan3ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan3ID, baseID);
      aiPlanSetEscrowID(wallPlan3ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan3ID, pri);
      aiPlanSetActive(wallPlan3ID, true);
   }

   // segment 4
   int wallPlan4ID = aiPlanCreate("WallInBase4", cPlanBuildWall);
   if (wallPlan4ID != -1)
   {
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan4ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallStart, 0, start4);
      aiPlanSetVariableVector(wallPlan4ID, cBuildWallPlanWallEnd, 0, end4);
      aiPlanSetVariableInt(wallPlan4ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan4ID, baseID);
      aiPlanSetEscrowID(wallPlan4ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan4ID, pri);
      aiPlanSetActive(wallPlan4ID, true);
   }

   // segment 5
   int wallPlan5ID = aiPlanCreate("WallInBase5", cPlanBuildWall);
   if (wallPlan5ID != -1)
   {
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan5ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallStart, 0, start5);
      aiPlanSetVariableVector(wallPlan5ID, cBuildWallPlanWallEnd, 0, end5);
      aiPlanSetVariableInt(wallPlan5ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan5ID, baseID);
      aiPlanSetEscrowID(wallPlan5ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan5ID, pri);
      aiPlanSetActive(wallPlan5ID, true);
   }

   // segment 6
   int wallPlan6ID = aiPlanCreate("WallInBase6", cPlanBuildWall);
   if (wallPlan6ID != -1)
   {
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan6ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallStart, 0, start6);
      aiPlanSetVariableVector(wallPlan6ID, cBuildWallPlanWallEnd, 0, end6);
      aiPlanSetVariableInt(wallPlan6ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan6ID, baseID);
      aiPlanSetEscrowID(wallPlan6ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan6ID, pri);
      aiPlanSetActive(wallPlan6ID, true);
   }

   // segment 7
   int wallPlan7ID = aiPlanCreate("WallInBase7", cPlanBuildWall);
   if (wallPlan7ID != -1)
   {
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan7ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallStart, 0, start7);
      aiPlanSetVariableVector(wallPlan7ID, cBuildWallPlanWallEnd, 0, end7);
      aiPlanSetVariableInt(wallPlan7ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan7ID, baseID);
      aiPlanSetEscrowID(wallPlan7ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan7ID, pri);
      aiPlanSetActive(wallPlan7ID, true);
   }

   // segment 8
   int wallPlan8ID = aiPlanCreate("WallInBase8", cPlanBuildWall);
   if (wallPlan8ID != -1)
   {
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan8ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallStart, 0, start8);
      aiPlanSetVariableVector(wallPlan8ID, cBuildWallPlanWallEnd, 0, end8);
      aiPlanSetVariableInt(wallPlan8ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan8ID, baseID);
      aiPlanSetEscrowID(wallPlan8ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan8ID, pri);
      aiPlanSetActive(wallPlan8ID, true);
   }

   // segment 9
   int wallPlan9ID = aiPlanCreate("WallInBase9", cPlanBuildWall);
   if (wallPlan9ID != -1)
   {
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan9ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallStart, 0, start9);
      aiPlanSetVariableVector(wallPlan9ID, cBuildWallPlanWallEnd, 0, end9);
      aiPlanSetVariableInt(wallPlan9ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan9ID, baseID);
      aiPlanSetEscrowID(wallPlan9ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan9ID, pri);
      aiPlanSetActive(wallPlan9ID, true);
   }

   // segment 10
   int wallPlan10ID = aiPlanCreate("WallInBase10", cPlanBuildWall);
   if (wallPlan10ID != -1)
   {
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan10ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallStart, 0, start10);
      aiPlanSetVariableVector(wallPlan10ID, cBuildWallPlanWallEnd, 0, end10);
      aiPlanSetVariableInt(wallPlan10ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan10ID, baseID);
      aiPlanSetEscrowID(wallPlan10ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan10ID, pri);
      aiPlanSetActive(wallPlan10ID, true);
   }

   // segment 11
   int wallPlan11ID = aiPlanCreate("WallInBase11", cPlanBuildWall);
   if (wallPlan11ID != -1)
   {
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan11ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallStart, 0, start11);
      aiPlanSetVariableVector(wallPlan11ID, cBuildWallPlanWallEnd, 0, end11);
      aiPlanSetVariableInt(wallPlan11ID, cBuildWallPlanNumberOfGates, 0, 0);
      aiPlanSetBaseID(wallPlan11ID, baseID);
      aiPlanSetEscrowID(wallPlan11ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan11ID, pri);
      aiPlanSetActive(wallPlan11ID, true);
   }

   // segment 12
   int wallPlan12ID = aiPlanCreate("WallInBase12", cPlanBuildWall);
   if (wallPlan12ID != -1)
   {
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeStraight);
      aiPlanAddUnitType(wallPlan12ID, gEconUnit, 1, 1, 1);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallStart, 0, start12);
      aiPlanSetVariableVector(wallPlan12ID, cBuildWallPlanWallEnd, 0, end12);
      aiPlanSetVariableInt(wallPlan12ID, cBuildWallPlanNumberOfGates, 0, 1);
      aiPlanSetBaseID(wallPlan12ID, baseID);
      aiPlanSetEscrowID(wallPlan12ID, cEconomyEscrowID);
      aiPlanSetDesiredPriority(wallPlan12ID, pri);
      aiPlanSetActive(wallPlan12ID, true);
   }

   return;

}

//==============================================================================
/* buildWallRing
   builds a ring wall at the designated point

*/
//==============================================================================
void buildWallRing(vector position = cInvalidVector, int baseID = -1, float wallRadius = 30.0, int gateNumber = 3)
{
      int wallPlanID = aiPlanCreate("FrontierWall", cPlanBuildWall);

      if (wallPlanID != -1)
      {
         aiPlanSetVariableInt(wallPlanID, cBuildWallPlanWallType, 0, cBuildWallPlanWallTypeRing);
         aiPlanAddUnitType(wallPlanID, gEconUnit, 1, 1, 1);
         aiPlanSetVariableVector(wallPlanID, cBuildWallPlanWallRingCenterPoint, 0, position);
         aiPlanSetVariableInt(wallPlanID, cBuildPlanLocationPreference, 0, cBuildingPlacementPreferenceFront);
         
         aiPlanSetVariableFloat(wallPlanID, cBuildWallPlanWallRingRadius, 0, wallRadius);
         aiPlanSetVariableInt(wallPlanID, cBuildWallPlanNumberOfGates, 0, gateNumber);
         aiPlanSetBaseID(wallPlanID, baseID);
         aiPlanSetEscrowID(wallPlanID, cEconomyEscrowID);
         aiPlanSetDesiredPriority(wallPlanID, 80);
         aiPlanSetActive(wallPlanID, true);
      }
}


rule testStarFort
inactive
minInterval 20
{
   if (kbGetAge() < cAge3)
   {
      return;
   }

   if (kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateAlive) <= 1)
   {
      return;
   }

   if (kbUnitCount(cMyID, gEconUnit, cUnitStateAlive) < 50)
   {
      return;
   }

   vector mainBaseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));

   //buildCornerPairStarFort(kbGetMapCenter(), kbBaseGetMainID(cMyID), 2.4, 99, 1, 1);
   //buildFourCornerStarFort(kbGetMapCenter(), mainBaseLocation, kbBaseGetMainID(cMyID), 2.4, 99, 2, 2);
   //sumterFort(kbGetMapCenter(), mainBaseLocation, gForwardBaseID, 1.5, 99, 2, 0);
   //haudOverlappingRingFort(kbGetMapCenter(), mainBaseLocation, gForwardBaseID, 2.5, 99, 2, 0);
   //sawtoothFort(kbGetMapCenter(), mainBaseLocation, gForwardBaseID, 2.5, 99, 2, 0);
   buildFourCornerStarFort(kbGetMapCenter(), mainBaseLocation, kbBaseGetMainID(cMyID), 2.4, 99, 2, 0, 2);
   //buildCrownwork(kbGetMapCenter(), kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), kbBaseGetMainID(cMyID), 5, 99, 2, 1, true);
   //createLocationBuildPlan(cUnitTypeBarracks, 2, 90, true, cEconomyEscrowID, kbGetMapCenter(), 1);
   //createLocationBuildPlan(cUnitTypeStable, 2, 90, true, cEconomyEscrowID, kbGetMapCenter(), 1);
   xsDisableSelf();
}


//==============================================================================
/* fixTycoonParamaters
   alters lots of stuff for tycoon mode
*/
//==============================================================================
rule fixTycoonParamaters
inactive
minInterval 20
{
   if (aiGetGameMode() != cGameModeEconomyMode)
   {
      xsDisableSelf();
      return;
   }

   // Reduce military values
   setMilPopLimit(2, 5, 10, 12, 15);

   // Correct for the rush. Allow other strategies
   if (gStrategy == cStrategyRush)
   {
      gStrategy = cStrategyGreed;
   }

   // Make us greedy from the beginning
   gGetGreedy = true;
}

//==============================================================================
/* generateGaussian
   adds units to gLandReservePlan manually to prevent adding units that aren't 
     on the same island
*/
//==============================================================================

float generateGaussian(float center = 0.0, float range = 0.4, int iterations = 15) 
{
   // This uses the central limit theorem to approximate a gaussian. Generates
   // a random int several times, then averages
   // Range is one sides, so 3 => +/- 3
   float value = 0.0;
   for (i = 0; < iterations)
   {
      value += aiRandFloat(center - range, center + range);
   }

   value = value / iterations;
   return value;
}
float generateTripleDiceRoll(float center = 0.0, float range = 0.4) 
{
   // This uses the central limit theorem to approximate a gaussian. Generates
   // a random int several times, then averages
   // Range is one sides, so 3 => +/- 3
   float value = 0.0;
   int iterations = 3;

   for (i = 0; < iterations)
   {
      value += aiRandFloat(center - range, center + range);
   }

   value = value / iterations;
   return value;
}

rule testGaussian
inactive
minInterval 2
{
   int testUnit = getUnit(cUnitTypeAgeUpBuilding, cPlayerRelationSelf);
   if (kbUnitIsType(testUnit, cUnitTypeLogicalTypeBuildingsNotWalls) == true)
   {
      aiChat(1, "True, testUnit: " + testUnit);
   }
   else
   {
      aiChat(1, "False, testUnit: " + testUnit);
   }
   float v = generateGaussian(0.0, 0.4, 15);
   float dR = generateTripleDiceRoll(0.0, 0.4);
   //int v = (cNumberPlayers - 1) / (aiGetNumberTeams() - 1); // Gaia counts as a player and a team
   //aiChat(1, "Gaussian: " + v + " Triple Dice Roll: " + dR);
}

//==============================================================================
/* getTeamStrategy
   looks at the players/civs on our team, and returns our best strategy

   Rush:                btRushBoom >= 0.5       && btOffenseDefense >= 0.5
   Naked Fast Fortress: btRushBoom >= 0; < 0.5  && btOffenseDefense >= 0.5
   Safe Fast Fortress:  btRushBoom >= 0; < 0.5  && btOffenseDefense <  0.5
   Fast Industrial:     btRushBoom < 0          && btOffenseDefense >= 0.5
   Greedy/Safe Boom:    btRushBoom < 0          && btOffenseDefense <  0.5
*/
//==============================================================================
int getTeamStrategy(void)
{
   float rushBoom = 0.0;
   float offenseDefense = 0.0;
   int teamPlayerCount = 0;
   int civType = -1;
   int myTeam = kbGetPlayerTeam(cMyID);
   
   for (i = 0; < cNumberPlayers)
   {
      if (myTeam != kbGetPlayerTeam(i))
      {
         continue;
      }
      teamPlayerCount += 1;
      civType = kbGetCivForPlayer(i);

      switch (civType)
      {
         case cCivBritish: // Elizabeth: Infantry oriented.
         case cCivTheCircle:
         case cCivPirate:
         case cCivSPCAct3:
         {
            rushBoom += 0.5;
            offenseDefense += 0.5;
         }
         case cCivFrench: // Napoleon:  Cav oriented, balanced
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivSpanish: // Isabella: Bias against natives.
         {
            rushBoom += 0.0;
            offenseDefense += 1.0;
         }
         case cCivRussians: // Ivan:  Infantry oriented rusher
         {
            rushBoom += 0.5;
            offenseDefense += 0.5;
         }
         case cCivGermans: // Fast fortress, cavalry oriented
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivDutch: // Fast fortress, ignore trade routes.
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivPortuguese: // Fast fortress, artillery oriented
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivOttomans: // Artillery oriented, rusher
         {
            rushBoom += 0.5;
            offenseDefense += 0.5;
         }
         case cCivXPSioux: // Extreme rush
         {
            rushBoom += 0.8;
            offenseDefense += 0.5;
         }
         case cCivXPIroquois: // Fast fortress, trade and native bias.
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivXPAztec: // Rusher.
         {
            rushBoom += 0.5;
            offenseDefense += 1.0;
         }
         case cCivChinese: // Kangxi:  Fast fortress, infantry oriented
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivJapanese: // Shogun Tokugawa Ieyasu: Rusher, ignores trade routes
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }
         case cCivIndians: // Rusher, balanced
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }
         case cCivDEInca: // Huayna Capac: Rusher, trade and strong native bias.
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }
         case cCivDESwedish: // Gustav the Great: Rusher, small artillery focus.
         {
            rushBoom += 0.7;
            offenseDefense += 0.6;
         }
         case cCivDEAmericans: // George Washington: Balanced.
         {
            rushBoom += 0.0;
            offenseDefense += 1.0;
         }
         case cCivDEEthiopians: // Emperor Tewodros: Bias towards building TPs.
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivDEHausa: // Queen Amina: Bias towards building TPs.
         {
            rushBoom += 0.0;
            offenseDefense += 0.0;
         }
         case cCivDEMexicans: // Miguel Hidalgo: Balanced.
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }
         case cCivDEItalians: // Guiseppe Garibaldi: Balanced.
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }
         case cCivDEMaltese: // Jean Parisot: Balanced.
         {
            rushBoom += 0.5;
            offenseDefense += 0.0;
         }      
      }
   }

   // A couple checks to see if we should use a team strategy
   // Only do this with teams of 3 or 4. Keeps a team of human + ai more even
   if (teamPlayerCount <= 2)
   {
      return (-1);
   }

   // Average it
   rushBoom = rushBoom / teamPlayerCount;
   offenseDefense = offenseDefense / teamPlayerCount;

   // Randomize it
   //rushBoom = generateTripleDiceRoll(rushBoom);
   //offenseDefense = generateTripleDiceRoll(offenseDefense);

   // Find the strategy
   // Fudge these numbers to get more rushing
   if (rushBoom >= 0.2 && offenseDefense >= 0.2)
   {
      gStrategy = cStrategyRush;
   }
   else if (rushBoom >= 0 && rushBoom < 0.5 && offenseDefense >= 0.2)
   {
      gStrategy = cStrategyNakedFF;
   }
   else if (rushBoom >= 0 && rushBoom < 0.5 && offenseDefense <  0.5)
   {
      gStrategy = cStrategySafeFF;
   }
   else if (rushBoom < 0 && offenseDefense >= 0.5)
   {
      gStrategy = cStrategyFastIndustrial;
   }
   else //if (rushBoom < 0 && offenseDefense <  0.5) Make sure we pick something
   {
      gStrategy = cStrategyGreed;
   }

   return (gStrategy);
}

//==============================================================================
/* landReserveRefill
   adds units to gLandReservePlan manually to prevent adding units that aren't 
     on the same island
*/
//==============================================================================
rule landReserveRefill
inactive
minInterval 10
{
   // Search for all military units. If they are on the right island then add them
}

//==============================================================================
/* greedManager
   Monitors how greedy we can play 
*/
//==============================================================================
rule greedManager
inactive
minInterval 10
{
   int mainBaseID = kbBaseGetMainID(cMyID);
   vector mainBaseLocation = kbBaseGetLocation(cMyID, mainBaseID);
   int currentDistance = kbBaseGetMaximumResourceDistance(cMyID, mainBaseID);
   int greedDistance = -1;
   int time = xsGetTime();
   int smallInterval = 8 * 60 * 1000;
   int longInterval = 2 * smallInterval;
   int towerQuery = -1;
   int towerCount = -1;
   int fortQuery = -1;
   int fortCount = -1;
   int mostHatedPlayer = aiGetMostHatedPlayerID();
   vector mostHatedEnemyLoc = kbBaseGetLocation(mostHatedPlayer, kbBaseGetMainID(mostHatedPlayer));


   if (gDefenseReflex == true)
   {
      gGetGreedy = false;
   }
   // If we haven't been attacked in a long time
   else if (time > gLastHomeBaseDefendTime + smallInterval && time > gDefenseReflexTimeout + smallInterval)
   {  
      // It's been a little while, but has it been a long while?
      if (time > gLastHomeBaseDefendTime + longInterval && time > gDefenseReflexTimeout + longInterval)
      {
         gGetGreedy = true;
      }

      // It's been a while, but not a long while. Check to see if enemy is turtling
      if (gGetGreedy == false)
      {
         // Get the tower and fort count around the most hated enemy
         towerQuery = createSimpleUnitQuery(cUnitTypeAbstractOutpost, cPlayerRelationEnemyNotGaia, cUnitStateAlive, mostHatedEnemyLoc, 80);
         towerCount = kbUnitQueryExecute(towerQuery);
         fortQuery = createSimpleUnitQuery(cUnitTypeFortFrontier, cPlayerRelationEnemyNotGaia, cUnitStateAlive, mostHatedEnemyLoc, 80);
         fortCount = kbUnitQueryExecute(fortQuery);

         if (fortCount > 0)
         {
            towerCount += 4;
         }

         // Fort on a 1v1? turtling (2 players + gaia)
         if (cNumberPlayers == 3 && fortCount > 0)
         {
            gGetGreedy = true;
         }
         else if (towerCount >= 2 * (kbGetAge() + 1))
         {
            gGetGreedy = true;
         }
         else if (kbUnitCount(mostHatedPlayer, cUnitTypeAbstractWall, cUnitStateAlive) > 8)
         {
            gGetGreedy = true;
         }
      }
   }
   else
   {
      gGetGreedy = false;
   }

   if (gGetGreedy == true)
   {
      // A few distances we can use. 
      // Distance from base to forward base
      if (gForwardBaseState == cForwardBaseStateActive)
      {
         greedDistance = distance(mainBaseLocation, gForwardBaseLocation);
      }
      // Distance to 1/3 map
      else
      {
         if (gStrategy == cStrategyGreed)
         {
            greedDistance = distance(mainBaseLocation, mostHatedEnemyLoc) / 2;
         }
         else
         {
            greedDistance = distance(mainBaseLocation, mostHatedEnemyLoc) / 3;
         }
      }
   }

   // Revert to old range
   if (gGetGreedy == false && currentDistance > 1.1 * gCalculatedGatherDistance)
   {
      kbBaseSetMaximumResourceDistance(cMyID, mainBaseID, gCalculatedGatherDistance);
   }
   // Set the maximum resource range
   else if (greedDistance > currentDistance && gGetGreedy == true)
   {  
      kbBaseSetMaximumResourceDistance(cMyID, mainBaseID, greedDistance);
   }
}

//==============================================================================
/* teePeeMonitor
   Simple monitor that places some teepees randomly throughout an AI's base. 
*/
//==============================================================================
rule teePeeMonitor
inactive
minInterval 20
{
   // Check if we're already building a teepee
   if (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypeTeepee) > 0)
   {
      return;
   }

   int mainBaseID = kbBaseGetMainID(cMyID);
   vector mainBaseLocation = kbBaseGetLocation(cMyID, mainBaseID);
   int mainBaseSize = kbBaseGetDistance(cMyID, mainBaseID);
   int teePeeQuery = createSimpleUnitQuery(cUnitTypeTeepee, cMyID, cUnitStateABQ, mainBaseLocation, mainBaseSize);
   int teePeeCount = kbUnitQueryExecute(teePeeQuery);
   int buildTeepee = -1; // set to 1 for main base, 2 for forward base
   static int randTeepeeStart = -1;
   if (randTeepeeStart < 0){randTeepeeStart = 1 + aiRandInt(2);} // makes 1 - 2 teepees at start
   // teepee range: 22
   // In age2, seek to cover 25% of area
   // In age3, 50% of area
   // In age4, 75% of area
   // Area covered is pi*r^2, but pi cancels. 22^2/basesize^2
   float areaCovered = teePeeCount * 484 / (mainBaseSize * mainBaseSize);
   int playerAge = kbGetAge();

   // Check forward base first
   if (gForwardBaseID > 0 && gForwardBaseState >= cForwardBaseStateBuilding && buildTeepee < 0)
   {
      int teePeeFBQuery = createSimpleUnitQuery(cUnitTypeTeepee, cMyID, cUnitStateAlive, gForwardBaseLocation, 40);
      int teePeeFBCount = kbUnitQueryExecute(teePeeFBQuery);
      if (playerAge < cAge3)
      {
         if (teePeeFBCount < 2)
         {buildTeepee = 2;}
      }
      else if (playerAge == cAge3)
      {
         if (teePeeFBCount < 3)
         {buildTeepee = 2;}
      }
      else
      {
         if (teePeeFBCount < 4)
         {buildTeepee = 2;}
      }
   }

   if (buildTeepee < 0)
   {
      if (playerAge == cAge1)
      {
         if (areaCovered < 0.15 && teePeeCount < randTeepeeStart)
         {buildTeepee = 1;}
      }
      else if (playerAge < cAge3)
      {
         if (areaCovered < 0.15)
         {buildTeepee = 1;}
      }
      else if (playerAge == cAge3)
      {
         if (areaCovered < 0.35)
         {buildTeepee = 1;}
      }
      else
      {
         if (areaCovered < 0.50)
         {buildTeepee = 1;}
      }
   }

   if (buildTeepee > 0)
   {
      int planID = aiPlanCreate("TeePee Build Plan, " + teePeeCount, cPlanBuild);
      if (planID < 0){return;}

      // What to build
      aiPlanSetVariableInt(planID, cBuildPlanBuildingTypeID, 0, cUnitTypeTeepee);
      //aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, mainBaseLocation);
      //aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, mainBaseSize);

      // 3 meter separation
      aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 3.0);

      // Priority.
      aiPlanSetDesiredPriority(planID, 40);

      // Builders.
      if (addBuilderToPlan(planID, cUnitTypeTeepee, 1) == false)
      {
         aiPlanDestroy(planID);
         return;
      }

      aiPlanSetVariableInt(planID, cBuildPlanInfluenceUnitTypeID, 0, cUnitTypeTeepee);
      aiPlanSetVariableFloat(planID, cBuildPlanInfluenceUnitDistance, 0, 20+aiRandInt(8)); // rand int prevents grids
      aiPlanSetVariableFloat(planID, cBuildPlanInfluenceUnitValue, 0, -20.0);             // -20 points per teepee
      aiPlanSetVariableInt(planID, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffNone); // Linear slope falloff

      if (buildTeepee == 1)
      {
         aiPlanSetVariableBool(planID, cBuildPlanInfluenceAtBuilderPosition, 0, true);
         aiPlanSetVariableFloat(planID, cBuildPlanInfluenceBuilderPositionValue, 0, 15);   
         aiPlanSetVariableFloat(planID, cBuildPlanInfluenceBuilderPositionDistance, 0, 20.0);  
         aiPlanSetVariableInt(planID, cBuildPlanInfluenceBuilderPositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff

         /*aiPlanSetVariableVector(planID, cBuildPlanInfluencePosition, 0, mainBaseLocation);              
         aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionDistance, 0, mainBaseSize);          
         aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, -5);        
         aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear);*/ // Linear slope falloff

         aiPlanSetVariableInt(planID, cBuildPlanLocationPreference, 0, aiRandInt(4));
      }
      else if (buildTeepee == 2)
      {
         aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, gForwardBaseLocation);
         aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, 25);

         aiPlanSetVariableVector(planID, cBuildPlanInfluencePosition, 0, gForwardBaseLocation);              
         aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionDistance, 0, 15);          
         aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, -5);             
         aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff
      }

      if (buildTeepee == 1)
      {
         aiPlanSetBaseID(planID, mainBaseID);
         aiPlanSetActive(planID);
      }
      else
      {
         aiPlanSetBaseID(planID, gForwardBaseID);
         aiPlanSetActive(planID);
      }
   }
}



//==============================================================================
// allowedToAttack
// AssertiveWall: replaces the logic involving gAttackMissionInterval to 
//    determine if we are allowed to attack. Instead of an interval, we'll 
//    try to make an educated guess on how big our army needs to be. Bases army
//    sizes on our whole team so hopefully we will attack together
// Returns true if we are allowed to attack
// Based on the monitorScores rule in aiChats
//==============================================================================
bool allowedToAttack(void)
{
   // First make sure we have enough military depending on age
   int ageVar = getTeamAge(true);   // our team by default, currently set to our team
   int enAgeVar = getTeamAge(false);//kbGetAgeForPlayer(aiGetMostHatedPlayerID());
   int militaryQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationAlly, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(militaryQueryID);
   float militaryStrength = 0.0;
   int puid = -1;
   int playersPerTeam = (cNumberPlayers - 1) / (aiGetNumberTeams() - 1); // Gaia counts as a player and a team

   for (i = 0; < numberFound)
   {
      puid = kbUnitGetProtoUnitID(kbUnitQueryGetResult(militaryQueryID, i));
      militaryStrength = militaryStrength + getMilitaryUnitStrength(puid);
   }

   // adjust strength for lower difficulties. 
   if (cDifficultyCurrent < cDifficultyHard) {militaryStrength = militaryStrength * 1.3;} 
   //else if (cDifficultyCurrent == cDifficultyHard) {militaryStrength = militaryStrength * 1.15;} 

   // If we're trying to FI/FF, don't attack until appropriate age
   if (gStrategy == cStrategyFastIndustrial && ageVar < cAge4)
   {return false;}
   else if ((gStrategy == cStrategyNakedFF || gStrategy == cStrategySafeFF) && ageVar < cAge3)
   {return false;}

   // Create bounds where we shouldn't/should always attack regardless of score
   // This is based on the most hated enemy's age, not ours
   // If we reached our max military, allow an attack. The max values below will probably never get used in age 2, 3
   if (militaryStrength >= aiGetMilitaryPop() * playersPerTeam && playersPerTeam == 1){return true;}
   else if (enAgeVar == cAge2)
   {
      if (militaryStrength < 15 * playersPerTeam){return false;}
      else if (militaryStrength > 30 * playersPerTeam){return true;}
   }
   else if (enAgeVar == cAge3)
   {
      if (militaryStrength < 20 * playersPerTeam){return false;}
      else if (militaryStrength > 45 * playersPerTeam){return true;}
   }
   else if (enAgeVar == cAge4)
   {
      if (militaryStrength < 25 * playersPerTeam){return false;}
      else if (militaryStrength > 55 * playersPerTeam){return true;}
   }
   else if (enAgeVar == cAge5)
   {
      if (militaryStrength < 30 * playersPerTeam){return false;}
      else if (militaryStrength > 60 * playersPerTeam){return true;}
   }

   // The next block looks at scores
   int teamScore = 0;
   int enemyScore = 0;
   int numEnemies = -1;   // start at -1 to account for gaia
   int numAllies = 0;
   int myTeam = kbGetPlayerTeam(cMyID);

   for (i = 0; < cNumberPlayers)
   {
      if (myTeam == kbGetPlayerTeam(i))
      {
         teamScore += aiGetScore(i);
         numAllies += 1;
      }
      else
      {
         enemyScore = aiGetScore(i);
         numEnemies += 1;
      }
   }

   // If we have an advantage in player number or we are equal, use raw score (like a 4v3 game)
   // If we are winning by a decent amount attack, otherwise check if we are losing
   if (numAllies >= numEnemies)
   {
      if (teamScore > 1.2 * enemyScore)
      {
         return (true);
      }
      else if (teamScore < 0.8 * enemyScore)
      {
         return (false);
      }
   }
   else
   {
      if (teamScore / numAllies > 1.2 * enemyScore / numEnemies)
      {
         return (true);
      }
      else if (teamScore / numAllies < 0.8 * enemyScore / numEnemies)
      {
         return (false);
      }
   }

   // Time as a last check
   if (xsGetTime() - gLastAttackMissionTime < 2 * gAttackMissionInterval)
   {
      return (true);
   }

   return (false);
}

//==============================================================================
// getClosestGaiaUnit
// Query closest unit's position from gaia's perspective, use with caution to avoid cheating.
// AssertiveWall: based on getClosestGaiaUnitPosition but returns the unit
//==============================================================================
int getClosestGaiaUnit(int unitTypeID = -1, vector position = cInvalidVector, float radius = -1.0)
{
   xsSetContextPlayer(0);
   int gaiaUnitQueryID = kbUnitQueryCreate("getClosestGaiaUnitQuery");

   // Define a query to get all matching units.
   if (gaiaUnitQueryID != -1)
   {
      kbUnitQuerySetPlayerID(gaiaUnitQueryID, 0);
      kbUnitQuerySetUnitType(gaiaUnitQueryID, unitTypeID);
      kbUnitQuerySetState(gaiaUnitQueryID, cUnitStateAlive);
      kbUnitQuerySetPosition(gaiaUnitQueryID, position);
      kbUnitQuerySetMaximumDistance(gaiaUnitQueryID, radius);
      kbUnitQuerySetAscendingSort(gaiaUnitQueryID, true);
   }
   else
   {
      xsSetContextPlayer(cMyID);
      return (-1);
   }

   kbUnitQueryResetResults(gaiaUnitQueryID);

   if (kbUnitQueryExecute(gaiaUnitQueryID) > 0)
   {
      // Get the location of the first(closest) unit.
      int closestUnit = kbUnitQueryGetResult(gaiaUnitQueryID, 0); 
      xsSetContextPlayer(cMyID);
      return (closestUnit);
   }
   xsSetContextPlayer(cMyID);
   return (-1);
}

//==============================================================================
/* No idle Vills
   grabs idle vills and does a simple no-plan tasking to gather from the nearest
   resource. Designed to be lightweight so it can run quickly and often
*/
//==============================================================================
rule noIdleVills
inactive
minInterval 1
{
   // Don't run this until age 2
   if (kbGetAge() < cAge2)
   {
      return;
      //resourcePUID = cUnitTypeFood;
   }

   int villagerQuery = createSimpleUnitQuery(gEconUnit, cMyID, cUnitStateAlive);
   kbUnitQuerySetActionType(villagerQuery, cActionTypeIdle);
   int numberFound = kbUnitQueryExecute(villagerQuery);
   vector tempLocation = cInvalidVector;
   int nearestResource = -1;
   int tempVilID = -1;
   int resourcePUID = cUnitTypeWood;

   for (i = 0; < numberFound)
   {
      tempVilID = kbUnitQueryGetResult(villagerQuery, i);
      tempLocation = kbUnitGetPosition(tempVilID);
      nearestResource = getClosestGaiaUnit(resourcePUID, tempLocation, 30);
      if (nearestResource > 0)
      {
         aiTaskUnitWork(tempVilID, nearestResource);
      }
      else
      {
         nearestResource = getClosestGaiaUnit(cUnitTypeGold, tempLocation, 30);
         if (nearestResource > 0)
         {
            aiTaskUnitWork(tempVilID, nearestResource);
         }
      }
   }
}



//==============================================================================
/* Call City Guard
   Levies the city guard whenever it is under threat
   Based on useLevy

   DESPCLevyCityGuards
*/
//==============================================================================
rule callCityGuard
inactive
minInterval 10
{
   static int callCityarrayID = -1;
   if (callCityarrayID == -1) // First run.
   {
      callCityarrayID = xsArrayCreateInt(3, -1, "City Guard Plans");
   }
   else
   {
      for (i = 0; < 3) // Reset array.
      {
         xsArraySetInt(callCityarrayID, i, -1);
      }
   }

   int cityStateTPQueryID = createSimpleUnitQuery(cUnitTypeAgeUpBuilding, cMyID, cUnitStateAlive);
   int numberResults = kbUnitQueryExecute(cityStateTPQueryID);
   int cityStateTPID = -1;
   int techID = cTechDESPCLevyCityGuards;

   vector tPLocation = cInvalidVector;
   int allyCount = -1;
   int enemyCount = -1;
   int cityGuardPlan = -1;
   int numberGuardPlans = aiPlanGetNumberByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, techID);
   for (i = 0; < numberGuardPlans)
   {
      cityGuardPlan = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, techID, true, i);
      for (j = 0; < numberResults)
      {
         cityStateTPID = kbUnitQueryGetResult(cityStateTPQueryID, j);
         if (cityStateTPID == aiPlanGetVariableInt(cityGuardPlan, cResearchPlanBuildingID, 0))
         {
            xsArraySetInt(callCityarrayID, j, cityGuardPlan);
         }
      }
   }
   
   for (i = 0; < numberResults)
   {
      cityStateTPID = kbUnitQueryGetResult(cityStateTPQueryID, i);
      cityGuardPlan = xsArrayGetInt(callCityarrayID, i);
      if (kbBuildingTechGetStatus(techID, cityStateTPID) == cTechStatusObtainable) // TC can still use Levy.
      {

         tPLocation = kbUnitGetPosition(cityStateTPID);
         enemyCount = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary,
            cPlayerRelationEnemyNotGaia, cUnitStateAlive, tPLocation, 40.0);
         allyCount = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary,
            cPlayerRelationAlly, cUnitStateAlive, tPLocation, 40.0);

         if (enemyCount >= allyCount + 5) // We're behind by 5 or more.
         {
            if (cityGuardPlan < 0)
            {
               createSimpleResearchPlanSpecificBuilding(techID, cityStateTPID, cMilitaryEscrowID, 99, 99);
            }
         }
         else // No need to call levy.
         {
            if (cityGuardPlan >= 0) // We have a plan we must maybe destroy.
            {
               if (cityStateTPID == aiPlanGetVariableInt(cityGuardPlan, cResearchPlanBuildingID, 0))
               {
                  aiPlanDestroy(cityGuardPlan);
               }
            }
         }
      }
   }
}


//==============================================================================
/* Check for attack/defence special map
   AssertiveWall: Checks to see if the map is a special attack or defend map,
   and sets btbias accordingly
*/
//==============================================================================
void checkAttackDefenseMap(void)
{
   int headquarters = -1;

   if (cRandomMapName == "eueightyyearswar" ||
       cRandomMapName == "eugreatturkishwar")
   {
      // Look for the different HQ buildings
      headquarters = getUnit(cUnitTypedeSPCHeadquarters, cPlayerRelationAlly);
      if (headquarters < 0)
      {
         headquarters = getUnit(cUnitTypedeSPCHeadquartersVienna, cPlayerRelationAlly);
      }

      if (headquarters > 0)
      { // defender
         btOffenseDefense = 0.0;
         xsEnableRule("eightyYearsWarMonitor");
      }
      else
      { // attacker
         if (btOffenseDefense < 0.8)
         {
            btOffenseDefense = 0.8;
         }
      }
   }

   // everyone needs to focus on native sites on these maps
   if (cRandomMapName == "eugreatturkishwar" || cRandomMapName == "euitalianwars")
   {
      if (btBiasNative < 0.5)
      {
         btBiasNative = 0.5;
      }
   }

   if (cRandomMapName == "euitalianwars")
   {  // Doesn't work yet
      //xsEnableRule("callCityGuard");
   }
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
/* dockWallOne - dockWallThree
   AssertiveWall: build a wall around a random dock. Some docks will get double, 
   which is ok
*/
//==============================================================================

rule dockWallOne
inactive
minInterval 20
{
   if (gStrategy == cStrategyRush)
   {  // No walls for rushing civs
      xsDisableSelf();
      return;
   }
   else if (gIsArchipelagoMap == true)
   {  // No walls on Archipelago
      xsDisableSelf();
      return;
   }
   else if (btRushBoom > 0.4 && xsGetTime() < 25 * 60 * 1000 * btRushBoom)
   {  // Delay the wall for more aggresive civs
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
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
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
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
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
   if (gStrategy == cStrategyRush)
   {  // No walls for rushing civs
      xsDisableSelf();
      return;
   }
   else if (gStrategy == cStrategyFastIndustrial && kbGetAge() < cAge4)
   {
      return;
   }
   else if (gStrategy == cStrategyNakedFF && kbGetAge() < cAge3)
   {
      if (kbGetAge() == cAge3 && xsGetTime() < gAgeUpTime + 6 * 60 * 1000)
      {
         return;
      }
   }
   else if (gStrategy == cStrategySafeFF && kbGetAge() < cAge3)
   {
      return;
   }

   // No walls for some special maps
   if (cRandomMapName == "eueightyyearswar" ||
       cRandomMapName == "euitalianwars")
   {
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

   Uses a number of conditions to select fancy fort layouts

   Styles:
      - Corner Pair
      - Four Corner Star
      - Ring Wall
      - Fort Ticonderoga
      - Fort Sumter

   Additional Pieces:
      - Crownwork
      - Ravelin
*/
//==============================================================================

rule upgradeWalls
inactive
minInterval 37
{
   int wallCount = kbUnitCount(cMyID, cUnitTypeAbstractWall, cUnitStateAlive);

   if (wallCount <= 0 && kbGetAge() < cAge5)
   {  // No point in researching this until we have walls
      return;
   }

   int wallUnitID = getUnit(cUnitTypeAbstractWall, cMyID, cUnitStateAlive);
   int wallPlanPri = 30;
   int wallTech = cTechBastion;

   switch (cMyCiv)
   {  // Bastion is the default tech, but for others with special versions:
      case cCivDEAmericans:
      case cCivDEMexicans:
      {
         wallTech = cTechDERedoubts;
      }
      case cCivDEHausa:
      case cCivDEEthiopians:
      {
         wallTech = cTechDECityFortifications;
      }
   }

   if (wallCount > 12 || kbGetAge() >= cAge4)
   {
      wallPlanPri = 60;
   }
   bool canDisableSelf = researchSimpleTech(wallTech, -1, wallUnitID, wallPlanPri);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

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
      xsEnableRule("forwardBaseTowers"); // old version of placing towers at forward base. No longer used with star forts
      xsDisableSelf();
      return;
   }

   if (gForwardBaseState == cForwardBaseStateNone) // || gForwardBaseState == cForwardBaseStateBuilding)
   {
      return; // AssertiveWall: wait until the fort is building or built
   }
   
   if (kbGetAge() == cAge1 || (kbGetAge() == cAge2 && agingUp() == false))
   {
      return; // Go away until we're aging up to age 3
   }

   int towerNumber = 0;
   int cannonNumber = 0;
   int pri = 90;
   int crownworkNum = 0;
   int ravelinNum = 0;
   int age = kbGetAge();
   vector mainBaseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));

   // Table of fort designs:
   /*
      Rushing civs always build corner pair forts
      Naked fast fortress civs will build corner pair in age 3, star in age 4
      Safe FF will build stars starting in age 3
      FI will build stars starting in age 3
      Greed will build the biggest star forts

      Extra accessories like crownworks will get delayed until age 4

   */

   if (gStrategy == cStrategyRush)
   {
      towerNumber = 1;
      cannonNumber = 0;
      pri = 90;
      crownworkNum = 0;
      ravelinNum = 0;
   }
   else if (gStrategy == cStrategyNakedFF)
   {
      towerNumber = 2;
      cannonNumber = 0;
      pri = 90;
      crownworkNum = 0;
      ravelinNum = 0;
   }
   else if (gStrategy == cStrategySafeFF)
   {
      towerNumber = 2;
      cannonNumber = 1;
      pri = 90;
      crownworkNum = 0;
      ravelinNum = 2;
   }
   else if (gStrategy == cStrategyFastIndustrial)
   {
      towerNumber = 1;
      cannonNumber = 2;
      pri = 90;
      crownworkNum = 1;
      ravelinNum = 2;
   }
   else
   {
      towerNumber = 2;
      cannonNumber = 2;
      pri = 90;
      crownworkNum = 2;
      ravelinNum = 4;
   }

   // If we are trying to build this too close to base
   if (distance(mainBaseLocation, gForwardBaseLocation) < 60)
   {
      if (civIsNative() != true)
      {
         //buildCrownwork(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 5, pri, 1, 0, true);
      }
   }
   else if (civIsNative() == true)
   {
      if (kbUnitCount(cMyID, gEconUnit, cUnitStateAlive) < 40)
      {
         return;
      }

      if (cMyCiv == cCivXPIroquois)// || cMyCiv == cCivXPSioux)
      {
         haudOverlappingRingFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 2.4, pri, towerNumber, cannonNumber);
      }
      else if (cMyCiv == cCivDEInca || cMyCiv == cCivXPAztec)
      {
         sawtoothFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 2.4, pri, towerNumber, cannonNumber);
      }
      else
      {
         buildWallRing(gForwardBaseLocation, gForwardBaseID, 30.0, 4);
      }
   }
   else
   {
      int switcher = aiRandInt(4);
      // First corner pair
      if (gStrategy == cStrategyRush || (gStrategy == cStrategyNakedFF && age <= cAge3))
      {
         // Only build this if we have 30+ villagers
         if (kbUnitCount(cMyID, gEconUnit, cUnitStateAlive) < 30)
         {
            return;
         }
         switch (switcher)
         {
            case 1:
            {
               sumterFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 1.5, pri, towerNumber, cannonNumber);
            }
            default: 
            {
               buildCornerPairStarFort(gForwardBaseLocation, gForwardBaseID, 2.4, pri, towerNumber, cannonNumber);
            }
         }
      }
      else
      {
         // Only build this if we have 40+ villagers
         if (kbUnitCount(cMyID, gEconUnit, cUnitStateAlive) < 40)
         {
            return;
         }
         switch (switcher)
         {
            case 1:
            {
               ticonderogaStarFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 2.0, pri, towerNumber, cannonNumber, true);
            }
            default:
            {
               buildFourCornerStarFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 2.4, pri, towerNumber, cannonNumber, 0);
               //buildFourCornerStarFort(gForwardBaseLocation, mainBaseLocation, gForwardBaseID, 2.4, pri, towerNumber, cannonNumber, crownworkNum);
            }
         }
      }
   }

   //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);

   // Research the wall upgrade also
   if (xsIsRuleEnabled("upgradeWalls") == false)
   {
      xsEnableRule("upgradeWalls");
   }
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

   // Can't do this for civs that train units from them
   if (cMyCiv == cCivRussians ||
       civIsNative() == true ||
       civIsAfrican() == true)
   {
      xsDisableSelf();
      return;
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

   if (wallPlanID != -1 && distance(towerOneLoc, gForwardBaseLocation) < 60)
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
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
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
      //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIWallIn);
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
   bool takenIsland = false;
   int unit = getUnitByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, startingLoc, 100); // getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);

   areaCount = kbAreaGetNumber();
   myLocation = kbUnitGetPosition(unit);
   myAreaGroup = kbAreaGroupGetIDByPosition(myLocation);
   
   // Build a couple things on starting island. Stuff that doesn't cause issues later
   createSimpleBuildPlan(gDockUnit, 1, 99, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
   createSimpleBuildPlan(gHouseUnit, 1, 95, false, cEconomyEscrowID, kbBaseGetMainID(cMyID), 1);
   if (btOffenseDefense < 0.5)
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

      // Check to make sure this area is connected to center island, unless it's polynesia then find closest
      // island that isn't connected to starting area
      if (cRandomMapName == "zppolynesia")
      {
         for (i = 1; <= cNumberPlayers)
         {
            if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(kbGetPlayerStartingPosition(i)), areaGroup) == true)
            {
               takenIsland = true;
            }
            else if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(kbGetMapCenter()), areaGroup) == true)
            {
               takenIsland = true;
            }
            else if (distance(kbGetMapCenter(), kbAreaGetCenter(area)) < distance(kbGetMapCenter(), startingLoc))
            {
               takenIsland = true;
            }
         }

         if (takenIsland == true)
         {
            continue;
         }
      }
      else
      {
         if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(kbGetMapCenter()), areaGroup) == false)
         {
            continue;
         }
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


      // Try to move landing area away from enemies
      float distToEnemyTC = xsVectorLength(kbAreaGetCenter(area) - enPosition);
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

   //sendStatement(cPlayerRelationAlly, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(closestArea));

   // Move someone toward the center so we can see our landing spot
   /*aiTaskUnitMove(getUnit(shipType, cMyID, cUnitStateAlive), kbAreaGetCenter(closestArea));

   // This used to be "islandwaitforexplore" but a separate rule no longer necessary
   //int unit = getUnit(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive);

   int baseID = kbBaseCreate(cMyID, "Transport gather base", myLocation, 10.0);
   kbBaseAddUnit(cMyID, baseID, unit);

   int transportPlan = createTransportPlan(myLocation, kbAreaGetCenter(gCeylonStartingTargetArea), 100.0, false);
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

         kbBaseDestroy(cMyID, gMainBase);
         int gMainBase2 = kbBaseCreate(cMyID, "Island base", gStartingLocationOverride, 100.0); // createMainBase(gStartingLocationOverride);
         kbBaseSetMain(cMyID, gMainBase2, true);
         kbBaseSetPositionAndDistance(cMyID, kbBaseGetMainID(cMyID), gStartingLocationOverride, 100.0);
         kbBaseSetActive(cMyID, gMainBase2);

         // Add existing town center to base
         int townCenterID = getUnit(cUnitTypeTownCenter, cMyID, cUnitStateAlive);
         kbBaseAddUnit(cMyID, gMainBase2, townCenterID);
         
         // Set land reserve plan here
         aiPlanSetVariableVector(gLandReservePlan, cCombatPlanTargetPoint, 0, gStartingLocationOverride);
         //kbBaseSetMilitary(cMyID, gMainBase2, true);
         moveDefenseReflex(gStartingLocationOverride, 50.0, gMainBase2);

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

   // Get to within 80% of food + gold boat calculation
   if (numberFishingBoats < 0.8 * (numberFoodFishingBoats + numberGoldFishingBoats))
   {
      numberFishingBoats = 0.8 * (numberFoodFishingBoats + numberGoldFishingBoats);
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
      // Cover conditions when we start with a dock or dock wagon
      if (kbUnitCount(cMyID, gDockUnit, cUnitStateAlive) > 0)
      {  
         gTimeToFish = true;
      }
      else if (kbGetAge() < cAge2 && agingUp() == false)
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
      if (closestTeammate == cMyID && gStrategy != cStrategyRush)
      {  // We are the closest teammate, just make sure we aren't all-in rushing
         gTimeToFish = true;
      }

      // If we are being greedy, go for water
      if (gStrategy == cStrategyGreed)
      {
         gTimeToFish = true;
      }

      // Now some random checks
      static int randomizer = -1;
      if (randomizer < 0) // We roll once to enable it, otherwise other economy code can enable it.
      {
         randomizer = aiRandInt(10);
      }

      if ((gStrategy == cStrategyFastIndustrial || gStrategy == cStrategySafeFF) && randomizer < 3)
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

   int dockCount = kbUnitCount(cMyID, gDockUnit, cUnitStateAlive);
   int mainBaseID = kbBaseGetMainID(cMyID);
   int desiredDockCount = -1;
   int maxFishingBoats = -1;
   int boatPriority = -1;
   int maxDistance = -1;
   int tempBoatUnit = -1;
   int dockPlanID = aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gDockUnit);

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

   // Conditional for Big Boy:   The opponent is not competitive on water, and 
   //                            we are in a booming disposition
   if (btRushBoom <= 0 && friendlyWSStrength > 3 * enemyWSStrength && friendlyWSStrength > 1500)
   {
      desiredDockCount = 4;
      maxFishingBoats = 60;
      boatPriority = 90;
      maxDistance = kbGetMapXSize()/(0.5 * cNumberPlayers);
   } 
   // Conditional for Double:    The opponent is losing on water, and we want to capitalize unless we are 
   //                            a rushing civ
   else if (btRushBoom < 0.2 && friendlyWSStrength > 1.3 * enemyWSStrength && friendlyWSStrength > 750)
   {
      desiredDockCount = 2;
      maxFishingBoats = 45;
      boatPriority = 75;
      maxDistance = kbGetMapXSize()/(0.9 * cNumberPlayers);
   } 
   // Conditional for Single:    As long as we are ahead at least a little on water
   else if (btRushBoom < 0.4 && friendlyWSStrength > 1.0 * enemyWSStrength && friendlyWSStrength > 190)
   {
      desiredDockCount = 1;
      maxFishingBoats = 35;
      boatPriority = 65;
      maxDistance = kbGetMapXSize()/( 1.2 * cNumberPlayers);
   } 
   else
   {
      desiredDockCount = 1;
      maxFishingBoats = 20;
      boatPriority = 50;
      maxDistance = 60;    
   }

   if (dockCount < desiredDockCount && dockPlanID < 0)
   {
      createSimpleBuildPlan(gDockUnit, 1, 70, false, cMilitaryEscrowID, mainBaseID, 1); 
   }

   fishFunction(maxFishingBoats, boatPriority, maxDistance);

}

//==============================================================================
// getEnemyBase
// Gets an enemy base to use for attack plans
// Based on attackmanager, but simpler
//==============================================================================
vector getEnemyBase(int enemyPlayerID = -1, int armyPower = 0)
{
   if (enemyPlayerID < 0)
   {
      enemyPlayerID = aiGetMostHatedPlayerID();
   }

   int availableMilitaryPop = aiGetAvailableMilitaryPop();
   int numberBases = -1;
   int baseID = -1;
   int baseQuery = -1;
   int baseEnemyQuery = -1;
   vector baseLocation = cInvalidVector;
   int numberFound = -1;
   int baseAssets = -1;
   bool isKOTH = false;
   bool isTradingPost = false;
   int buildingPower = -1;
   int unitID = -1;
   int puid = -1;
   float militaryPower = 0.0;
   int maxBaseAssets = -1;
   vector targetBaseLocation = cInvalidVector;
   int targetBaseID = -1;
   int baseDistance = -1;
   bool isItalianWars = (cRandomMapName == "euItalianWars");
   bool isCityState = false;
   bool shouldAttack = true;

   // Go through list of bases, get their main base
   numberBases = kbBaseGetNumber(enemyPlayerID);
   if (baseQuery < 0) // First run.
   {
      baseQuery = kbUnitQueryCreate("islandAttackBaseQuery");
      kbUnitQuerySetIgnoreKnockedOutUnits(baseQuery, true);
      baseEnemyQuery = kbUnitQueryCreate("islandAttackBaseEnemyQuery");
      kbUnitQuerySetIgnoreKnockedOutUnits(baseEnemyQuery, true);
   }

   for (baseIndex = 0; < numberBases)
   {
      baseAssets = 0;
      buildingPower = 0;
      baseID = kbBaseGetIDByIndex(enemyPlayerID, baseIndex);
      baseLocation = kbBaseGetLocation(enemyPlayerID, baseID);
      baseDistance = kbBaseGetDistance(enemyPlayerID, baseID);

      kbUnitQuerySetPlayerID(baseQuery, enemyPlayerID);
      kbUnitQuerySetState(baseQuery, cUnitStateABQ);
      kbUnitQuerySetPosition(baseQuery, baseLocation);
      kbUnitQuerySetMaximumDistance(baseQuery, baseDistance);
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

      for (i = 0; < numberFound)
      {
         unitID = kbUnitQueryGetResult(baseQuery, i);
         puid = kbUnitGetProtoUnitID(unitID);
         shouldAttack = true;

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

      // Do we have enough power to defeat the target base?
      if (armyPower < militaryPower && availableMilitaryPop > 0)
      {
         shouldAttack = false;
      }

      if (baseAssets > maxBaseAssets && shouldAttack == true)
      {
         maxBaseAssets = baseAssets;
         targetBaseLocation = baseLocation;
         targetBaseID = baseID;
      }
   }

   if (maxBaseAssets > 0)
   {
      targetBaseID = baseID;
      targetBaseLocation = baseLocation;
      return (targetBaseLocation);
   }
   return (cInvalidVector);
}

//==============================================================================
// getRandomPoint
// 
// Gets a random point around the center point, within that radius
//==============================================================================
vector getRandomPoint(vector location = cInvalidVector, int radius = 30)
{
   vector position = location;
   float xError = radius;
   float zError = radius;
   position = xsVectorSetX(position, xsVectorGetX(position) + aiRandFloat(0.0 - xError, xError));
   position = xsVectorSetZ(position, xsVectorGetZ(position) + aiRandFloat(0.0 - zError, zError));

   return position;
}

//==============================================================================
// selectPickupPoint
// Looks at the vector between us and the enemy, and sompares several points to 
// find the best pickup
// Similar process as how coastal tower locations are picked
// To use this for dropoff points, just invert the friendly and enemy locations,
// but you must provide both in that case otherwise it will default to the 
// opposite
//==============================================================================
vector selectPickupPoint(vector friendlyLoc = cInvalidVector, vector enemyLoc = cInvalidVector, int stepsBack = 1, bool waterBool = false)
{
   int numAttempts = 15;
   int coastDist = -1;
   float spreadAngle = 0.0;
   vector tempVec = cInvalidVector;
   int nearbyBuildings = -1;
   int bestNearbyBuildings = 99;
   vector bestVec = cInvalidVector;
   bool success = false;


   if (enemyLoc == cInvalidVector)
   {
      enemyLoc = guessEnemyLocation();
   }

   if (friendlyLoc == cInvalidVector)
   {
      friendlyLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   }

   // Find out how far we are from the coast
   coastDist = distance(friendlyLoc, getCoastalPoint(friendlyLoc, enemyLoc, stepsBack, waterBool));

   // adjust how far our spread is if we're too close to the shore. Total angle is twice the spread angle
   if (coastDist < 120)
   {
      spreadAngle = PI * 0.4;
   }
   else if (coastDist < 180)
   {
      spreadAngle = PI * 0.3;
   }
   else
   {
      spreadAngle = PI * 0.2;
   }

   for (attempt = 0; < numAttempts)
   {  
      // Don't normalize this vector, keep it far away
      tempVec = enemyLoc - friendlyLoc;
      // Depends on spread angle determined above
      tempVec = rotateByReferencePoint(friendlyLoc, tempVec, aiRandFloat(0.0 - spreadAngle, spreadAngle));
      // Gets the point on the coast between these two
      tempVec = getCoastalPoint(friendlyLoc, tempVec, stepsBack, waterBool);

      if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(tempVec), kbAreaGroupGetIDByPosition(friendlyLoc)))
      {
         nearbyBuildings = getUnitCountByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationAny, cUnitStateABQ, tempVec, 15.0);
         if (nearbyBuildings < bestNearbyBuildings)
         {
            // Make sure it's in the same areagroup.
            success = true;
            bestNearbyBuildings = nearbyBuildings;
            bestVec = tempVec;
         }
      }
   }
   if (success == true)
   {
      return (bestVec);
   }

   bestVec = getCoastalPoint(friendlyLoc, enemyLoc, 1, false);
   return (bestVec);
}

//==============================================================================
// Checks to see if we should retreat
// 
//==============================================================================
bool retreatCheck(bool forceRetreat = false)
{
   // Need something to prevent retreating while transporting
   if (gAmphibiousAssaultStage == cLoadForces || gAmphibiousAssaultStage == cLandForces)
   {
      if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) > 0)
      {
         return false;
      }
   }

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

      frNavySize = aiPlanGetNumberUnits(gAmphibiousTransportPlan, cUnitTypeAbstractWarShip);
      for (i = 0; < frNavySize)
      {
         unitID = aiPlanGetUnitByIndex(gAmphibiousTransportPlan, i);
         puid = kbUnitGetProtoUnitID(unitID);
         frNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                           kbUnitCostPerResource(puid, cResourceInfluence));
      }

      if (xsGetTime() > gAmphibiousAssaultSavedTime + 10 * 60 * 1000 && gForwardBaseState != cForwardBaseStateActive)
      {  // Give up if it goes way too long. Probably got stuck on a transport or something
         forceRetreat = true;
      }

      if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) <= 0)
      {
         forceRetreat = true;
      }

      // If we're too outnumbered then retreat to gNavyVec
      if (frNavyValue * 1.2 < (enNavyValue + enTowerValue) || forceRetreat == true)
      {
         // Get the value of the army forward. Handles instances where a large army is dropped off
         int forwardArmyQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive, gForwardBaseLocation, 40.0);
         int numberFoundArmyQuery = kbUnitQueryExecute(forwardArmyQuery);
         int forwardArmyCount = 0;
         //int attackTimeSeconds = xsGetTime() / 1000;
         int armyPower = 0;
         vector unitLoc = cInvalidVector;
         for (i = 0; < numberFoundArmyQuery)
         {
            unitID = kbUnitQueryGetResult(forwardArmyQuery, i);
            unitLoc = kbUnitGetPosition(unitID);
            if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(gAmphibiousAssaultTarget), 
                                             kbAreaGroupGetIDByPosition(unitLoc)) == true)
            {
               puid = kbUnitGetProtoUnitID(unitID);
               armyPower = armyPower + (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                              kbUnitCostPerResource(puid, cResourceInfluence));
               forwardArmyCount = forwardArmyCount + 1;
            }
         }

         if (armyPower < 100 * 15 || forwardArmyCount < 5)
         {
            gAmphibiousAssaultStage = -1;//cGatherNavy;
            for (i = 0; < frNavySize)
            {
               unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
               aiTaskUnitMove(unitID, gNavyVec);
            }
            aiPlanDestroy(gAmphibiousAssaultPlan);
            aiPlanDestroy(gAmphibiousArmyPlan);
            aiPlanDestroy(gAmphibiousTransportPlan);
            gAmphibiousAssaultPlan = -1;
            gAmphibiousArmyPlan = -1;
            gNavyVec = kbUnitGetPosition(gWaterSpawnFlagID);

            return true;
         }
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
   int vilQueryID = -1;
   int numberVilWanted = 2;
   int unitID = -1;
   int unitPlanID = -1;
   vector unitLoc = cInvalidVector;
   int mainBaseAreaGroup = kbAreaGroupGetIDByPosition(kbGetPlayerStartingPosition(cMyID));

   /*aiPlanAddUnitType(gAmphibiousArmyPlan, cUnitTypeLogicalTypeLandMilitary, 1, numberFound, numberFound);
   aiPlanSetNoMoreUnits(gAmphibiousArmyPlan, true);*/
   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(armyQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      if (aiPlanGetDesiredPriority(unitPlanID) >= 99)           // Already in the plan or on a transport
      {
         continue;
      }
      // Make sure the unit is on the mainland
      unitLoc = kbUnitGetPosition(unitID);
      if (kbAreAreaGroupsPassableByLand(mainBaseAreaGroup, kbAreaGroupGetIDByPosition(unitLoc)) == false)
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

   vilQueryID = createSimpleUnitQuery(gEconUnit, cMyID, cUnitStateAlive);
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
   vector tempLocation = cInvalidVector;

   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(shipQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      if (aiPlanGetDesiredPriority(unitPlanID) == 99)           // Already in this plan
      {  // Keep it close
         if (distance(kbUnitGetPosition(unitID), location) > 40)
         {
            tempLocation = getRandomPoint(location, 37);
            aiTaskUnitMove(unitID, tempLocation);
         }
         continue;
      }
      if ((aiPlanGetDesiredPriority(unitPlanID) == 24) ||           // Repairing
            aiPlanGetDesiredPriority(unitPlanID) == 25 ||           // Actively Defending
            aiPlanGetType(unitPlanID) == cPlanTransport ||          // Transporting
            aiPlanGetDesiredPriority(unitPlanID) == 100 ||          // Also transporting, but maybe a reserve plan or child attack plan
            kbUnitGetHealth(unitID) < 0.5)                          // Half health
      {
         continue;
      }
      aiPlanAddUnit(gAmphibiousAssaultPlan, unitID);
      if (gAmphibiousAssaultStage == cGatherNavy)
      {
         tempLocation = getRandomPoint(location, 37);
         aiTaskUnitMove(unitID, tempLocation);
      }
   }

   // Check if most have made it
   if (gAmphibiousAssaultStage == cGatherNavy)
   {
      int gatherTarget = aiPlanGetNumberUnits(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip);
      int gatheredUnits = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive, location, 70.0);
      // Make sure we have 3 of 4 or at least 70%
      // Change this to ship value at some point

      // Determine how many ships we need. Based on age for now
      int currentAge = kbGetAge();
      float minimumShips = 2.0;
      if (currentAge == cAge3)
      {
         minimumShips = 3.0;
      }
      else if (currentAge >= cAge4)
      {
         minimumShips = 3.0;
      }

      if (civIsNative() == true)
      {
         minimumShips = minimumShips * 2.0;
      }

      if (cMyCiv == cCivDEInca)
      {
         minimumShips = minimumShips - 1.0;
      }

      if (gIsArchipelagoMap == true)
      {
         minimumShips = minimumShips - 1.0;
      }

      if ((gatheredUnits <= 4.0 && gatheredUnits >= gatherTarget - 1.0) || 
          (gatheredUnits > 0.7 * gatherTarget) || 
          (gatheredUnits > minimumShips * 1.4) ||
          ((gatheredUnits >= minimumShips) && (xsGetTime() > (2 * 60 * 1000 + gAmphibiousAssaultSavedTime))))
      {
         if (gatheredUnits >= minimumShips)
         {
            gAmphibiousAssaultStage = cBombardCoast;
            gAmphibiousAssaultSavedTime = xsGetTime();
         }
      }

      // If it's been way too long and we don't have enough ships, just end this
      if ((gatheredUnits < minimumShips - 1 && xsGetTime() > (3 * 60 * 1000 + gAmphibiousAssaultSavedTime)) ||
          (gatheredUnits < minimumShips && xsGetTime() > (4.5 * 60 * 1000 + gAmphibiousAssaultSavedTime)))
      {
         retreatCheck(true);
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

   // Add any warships not in the plan already
   int shipQueryID = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(shipQueryID);
   int shipUnitID = -1;
   int unitPlanID = -1;

   for (m = 0; < numberFound)
   {
      shipUnitID = kbUnitQueryGetResult(shipQueryID, m);
      unitPlanID = kbUnitGetPlanID(shipUnitID);
      if ((aiPlanGetDesiredPriority(unitPlanID) == 24) ||           // Repairing
            aiPlanGetDesiredPriority(unitPlanID) == 25 ||           // Actively Defending
            aiPlanGetType(unitPlanID) == cPlanTransport ||          // Transporting
            aiPlanGetDesiredPriority(unitPlanID) == 100 ||          // Also transporting, but maybe a reserve plan
            aiPlanGetDesiredPriority(unitPlanID) == 99 ||           // Already in this plan
            kbUnitGetHealth(shipUnitID) < 0.5)                      // Half health
      {
         continue;
      }
      aiPlanAddUnit(gAmphibiousAssaultPlan, shipUnitID);
   }


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
   bool alreadyTasked = false;
   vector targetLocation = cInvalidVector;

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
      alreadyTasked = false;
      unitID = aiPlanGetUnitByIndex(gAmphibiousAssaultPlan, i);
      puid = kbUnitGetProtoUnitID(unitID);
      frNavyValue += (kbUnitCostPerResource(puid, cResourceWood) + kbUnitCostPerResource(puid, cResourceGold) +
                        kbUnitCostPerResource(puid, cResourceInfluence));

      if (weakestEnTower > 0 || weakestShip1 > 0 || weakestShip2 > 0)
      {
         if (puid == gMonitorUnit && weakestEnTower > 0)
         {
            aiTaskUnitWork(unitID, weakestEnTower);
            alreadyTasked = true;
         }
         else if (i < frNavySize / 2)
         {
            aiTaskUnitWork(unitID, weakestShip1);
            alreadyTasked = true;
         }
         else
         {
            aiTaskUnitWork(unitID, weakestShip2);
            alreadyTasked = true;
         }
      }

      // not tasked, so tell them to move closer if they are too far away
      if (alreadyTasked == false)
      {
         if (distance(kbUnitGetPosition(unitID), gAmphibiousAssaultTarget) > 40)
         {
            targetLocation = getRandomPoint(gAmphibiousAssaultTarget, 35);
            aiTaskUnitMove(unitID, targetLocation);
         }
      }

      // Now check if we should go to next stage. Basically when the enemy towers and ships are taken care of
      // Make sure we have 1 ship minimum there
      // Give it at least 30 seconds before we try and transport
      if (xsGetTime() > gAmphibiousAssaultSavedTime + 30000)
      {
         if (frNavyValue > 2 * enTotalValue || enNavySize <= 1 || (enTowerSize == 0 && enNavySize < 3))
         {
            if (frNavyValue > 1)
            {
               if (gAmphibiousAssaultStage < cLoadForces)
               {
                  gAmphibiousAssaultSavedTime = xsGetTime();
                  gAmphibiousAssaultStage = cLoadForces;
               }
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
      pickupPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
   }

   // Find all military land units near the pickup point
   int landingForcesSize = aiPlanGetNumberUnits(gAmphibiousArmyPlan);
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

   // Check to see if we even have anyone. If not, bail
   if (landingForcesSize <= 0)
   {
      if (aiPlanGetNumberUnits(gAmphibiousArmyPlan) <= 0)
      {
         //gAmphibiousAssaultStage = cGatherNavy;
         gAmphibiousAssaultStage = -1;
         return;
      }
   }


   // Make sure our existing ships are still alive
   if (kbUnitGetHealth(gLandingShip1) <= 0.0)
   {
      gLandingShip1 = -1;
   }
   if (kbUnitGetHealth(gLandingShip2) <= 0.0)
   {
      gLandingShip2 = -1;
   }

   if (gLandingShip1 > 0 && (gLandingShip2 > 0 || landingForcesSize < 50))
   {
      // Do nothing for now, we already have our boats
   }
   else
   {
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
            if (tempShip == gLandingShip2 || landingForcesSize < 50)
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

   // If we don't have any ships return
   if (gLandingShip1 < 0 || (landingForcesSize > 50 && gLandingShip2 < 0))
   {
      return;
   }

   for (i = 0; < aiPlanGetNumberUnits(gAmphibiousArmyPlan))
   {  // If we only have 1 ship, everyone boards that ship. Otherwise split 50/50
      tempLandUnit = aiPlanGetUnitByIndex(gAmphibiousArmyPlan, i);
      if (gLandingShip2 < 0)
      {
         aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
      }
      else
      {
         if (i < landingForcesSize * 0.5)
         {
            aiTaskUnitWork(tempLandUnit, gLandingShip1, true);
         }
         else
         {
            aiTaskUnitWork(tempLandUnit, gLandingShip2, true);
         }
      }
   }

   /*aiPlanSetActive(transportPlanID);
   if (transportPlan2ID > 0)
   {
      aiPlanSetActive(transportPlan2ID);
   }*/

   /*if (transportPlanID > 0 || transportPlan2ID > 0)
   {
      gAmphibiousAssaultStage = cLandForces;
   }*/

   // Now check to see if we're all loaded up (within a couple units)
   // If over a minute has passed, just go
   unitsOnShip1 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip1), 1.0);
   if (gLandingShip2 > 0)
   {
      unitsOnShip2 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip2), 1.0);
   }

   if (unitsOnShip1 + unitsOnShip2 > landingForcesSize * 0.9 || 
       (unitsOnShip1 + unitsOnShip2 > 0 && xsGetTime() > gAmphibiousAssaultSavedTime + 60000))
   {
      gAmphibiousAssaultStage = cLandForces;
      gAmphibiousAssaultSavedTime = xsGetTime();
   }

   return;
}


//==============================================================================
// Drops off the transport
// 
//==============================================================================
void landForces()
{
   // Check if we're done transporting
   int unitsOnShip1 = 0;
   int unitsOnShip2 = 0; 
   int distFromShore = -1;

   unitsOnShip1 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip1), 1.0);
   
   if (gLandingShip2 > 0)
   {
      unitsOnShip2 = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf,
               cUnitStateAlive, kbUnitGetPosition(gLandingShip2), 1.0);
   }

   // If the first ship ejects, start doing the towers
   if (unitsOnShip1 <= 0 || (gLandingShip2 > 0 && unitsOnShip2 <= 0))
   {
      if (gIsArchipelagoMap == false)
      {
         buildForwardTowers();
      }
      if (xsIsRuleEnabled("forwardArmyPlan") == false)
      {
         xsEnableRule("forwardArmyPlan");
      }
   }

   if (unitsOnShip1 <= 0 && unitsOnShip2 <= 0)
   {  // Done transporting, move to next phase
      gAmphibiousAssaultStage = cBuildForwardBuildings;
      gAmphibiousAssaultSavedTime = xsGetTime();
      aiPlanDestroy(gAmphibiousTransportPlan);
      // Explore enabling this earlier to allow more reinforcement and parallel decision making
      if (xsIsRuleEnabled("forwardArmyPlan") == false)
      {
         xsEnableRule("forwardArmyPlan");
      }
      return;
   }


   // Transport part
   vector dropoff = cInvalidVector;
   vector shipLoc = cInvalidVector;
   vector tempDropoffTarget = gAmphibiousAssaultTarget;
   vector tempDropoffTarget2 = gAmphibiousAssaultTarget;
   vector mainBaseLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   static int lastTransportCheck = -1;

   // Set lastTransportCheck if it's been a while
   if (xsGetTime() > lastTransportCheck + 4 * 60 * 1000)
   {
      lastTransportCheck = xsGetTime();
   }

   
   // If the dropoff can't seem to cut it after 10 seconds, probably something in the way
   if (xsGetTime() > lastTransportCheck + 10 * 1000)
   {
      checkForClumpedShips(gLandingShip1, gLandingShip2);
      tempDropoffTarget = selectPickupPoint(gAmphibiousAssaultTarget, mainBaseLoc);
      tempDropoffTarget2 = selectPickupPoint(gAmphibiousAssaultTarget, mainBaseLoc);
      lastTransportCheck = xsGetTime();
   }


   if (unitsOnShip1 > 0)
   {
      shipLoc = kbUnitGetPosition(gLandingShip1);
      dropoff = tempDropoffTarget;//getDropoffPoint(shipLoc, tempDropoffTarget, 0);
      //distFromShore = distance(dropoff, shipLoc);
      aiTaskUnitEject(gLandingShip1, dropoff);
      /*if (distFromShore < 5)
      {
         aiTaskUnitEject(gLandingShip1);
      }
      else if (distFromShore < 15)
      {
         aiTaskUnitEject(gLandingShip1);
         aiTaskUnitMove(gLandingShip1, dropoff);
      }
      else
      {
         aiTaskUnitMove(gLandingShip1, dropoff);
      }*/
   }

   if (unitsOnShip2 > 0)
   {
      shipLoc = kbUnitGetPosition(gLandingShip2);
      dropoff = tempDropoffTarget2;//getDropoffPoint(shipLoc, tempDropoffTarget, 0);
      //distFromShore = distance(dropoff, shipLoc);
      aiTaskUnitEject(gLandingShip2, dropoff);
      /*if (distFromShore < 5)
      {
         aiTaskUnitEject(gLandingShip2);
      }
      else if (distFromShore < 15)
      {
         aiTaskUnitEject(gLandingShip2);
         aiTaskUnitMove(gLandingShip2, dropoff);
      }
      else
      {
         aiTaskUnitMove(gLandingShip2, dropoff);
      }*/
   }

   // Add something to move the ship around if it can't reach the dropoff?

}


//==============================================================================
// Move inland
// Move the forces inland if there's no enemy so we can build
//==============================================================================
void moveInland(vector targetPoint = cInvalidVector)
{
   // Use a standard point between our main base and the target point
   if (targetPoint == cInvalidVector)
   {
      targetPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), 10);
   }

   // Find all military land units near the pickup point
   int landingForcesSize = aiPlanGetNumberUnits(gAmphibiousArmyPlan);
   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cPlayerRelationSelf, cUnitStateAlive);
   int shipNumber = kbUnitQueryExecute(shipQuery);
   int tempLandUnit = -1;

   int enemyCount = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, gAmphibiousAssaultTarget, 30);

   if (enemyCount > 5 && landingForcesSize < 10)
   {
      return;
   }

   for (i = 0; < aiPlanGetNumberUnits(gAmphibiousArmyPlan))
   {  // If we only have 1 ship, everyone boards that ship. Otherwise split 50/50
      tempLandUnit = aiPlanGetUnitByIndex(gAmphibiousArmyPlan, i);
      aiTaskUnitMove(tempLandUnit, targetPoint);
   }

   return;
}

//==============================================================================
// Uses Galleons to train Units 
// 
//==============================================================================
void trainFromGalleons()
{
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
      if (kbProtoUnitIsType(cMyID, unitToTrain, cUnitTypeAbstractArtillery) == false)
      {
         break;
      }
   }

   // Create a maintain plan
   if (gAmphibiousTrainPlan < 0)
   {
      gAmphibiousTrainPlan = createSimpleMaintainPlan(unitToTrain, 20, false, -1, 5);
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
         else
         {
            aiTaskUnitTrain(unitID, unitToTrain);
         }
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
   int existingPlanID = -1;
   int buildingQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationSelf, cUnitStateAlive,
                                                gAmphibiousAssaultTarget, 40);
   int buildingNumber = kbUnitQueryExecute(buildingQueryID);
   int tempUnit = -1;
   int tempUnitAreaGroup = -1;
   int forwardBaseAreaGroup = kbAreaGroupGetIDByPosition(gAmphibiousAssaultTarget);

   // Check if we have something built. If so, move to next stage
   for (i = 0; < buildingNumber)
   {
      tempUnit = kbUnitQueryGetResult(buildingQueryID, i);
      tempUnitAreaGroup = kbAreaGroupGetIDByPosition(kbUnitGetPosition(tempUnit));
      if (kbAreAreaGroupsPassableByLand(tempUnitAreaGroup, forwardBaseAreaGroup) == true)
      {
         gAmphibiousAssaultSavedTime = xsGetTime();
         gAmphibiousAssaultStage = cEstablishForwardBase;
         return;
      }
   }

   // Don't make duplicate tower plans
   existingPlanID = aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gTowerUnit);
   if (existingPlanID >= 0)
   {
      return;
   }

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
   if (numberVil > 0)
   {
      planID = createLocationBuildPlan(gTowerUnit, towersToBuild, 100, true, -1, gAmphibiousAssaultTarget, numberVil);
      for (i = 0; < numberVil)
      {  // Add forward villagers
         aiPlanAddUnit(planID, kbUnitQueryGetResult(vilQuery, i));
      }
   }
   else
   {
      planID = createLocationBuildPlan(gTowerUnit, towersToBuild, 100, true, -1, gAmphibiousAssaultTarget, 1);
   }
   
   return;
}

//==============================================================================
// killForwardTransport
// AssertiveWall: kills the forward army transport in case the ship dies
//==============================================================================
rule killForwardTransport
inactive
minInterval 2
{
   int currentTransportPlanShips = aiPlanGetNumberUnits(gforwardArmyTransport, cUnitTypeShip);
   if (currentTransportPlanShips <= 0)
   {
      aiPlanDestroy(gforwardArmyTransport);
      gforwardArmyTransport = -1;
      xsDisableSelf();
   }
}

//==============================================================================
// baseUnderThreat
// AssertiveWall: kills the army gather plan allowing units to help out the town
//    This version is less likely to trigger than the defense reflex
//==============================================================================
rule baseUnderThreat
inactive
minInterval 2
{
   vector mainBaseLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   int baseRadius = kbBaseGetMaximumResourceDistance(cMyID, kbBaseGetMainID(cMyID));
   int enemiesNearBase = 0;
   int landReservePlanCount = aiPlanGetNumberUnits(gLandReservePlan, cUnitTypeLogicalTypeLandMilitary);

   // Make sure all enemies are on the island
   int armyQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, mainBaseLoc, baseRadius);
   int numberFound = kbUnitQueryExecute(armyQueryID);
   int unitID = -1;
   int puid = -1;
   vector unitLoc = cInvalidVector;
   int mainLand = kbAreaGroupGetIDByPosition(mainBaseLoc);

   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(armyQueryID, i);
      unitLoc = kbUnitGetPosition(unitID);
      if (kbAreAreaGroupsPassableByLand(mainLand, kbAreaGroupGetIDByPosition(unitLoc)) == true)
      {
         enemiesNearBase = enemiesNearBase + 1;
      }
   }

   if (enemiesNearBase > landReservePlanCount && enemiesNearBase > 8)
   {
      aiPlanDestroy(gAmphibiousArmyPlan);
      gAmphibiousArmyPlan = -1;
      if (gAmphibiousAssaultStage == cGatherNavy)
      {  // Needed to prevent the AI from stealing all the units right back
         retreatCheck(true);
      }
      xsDisableSelf();
   }
}

//==============================================================================
// forwardArmyPlan
// AssertiveWall: Create a persistent plan for forward military. 
// Tries to use 3/4 of military
//==============================================================================
rule forwardArmyPlan
inactive
minInterval 20
{
   // Check if forward base is active. If not, destroy plan
   if (gForwardBaseState == cForwardBaseStateNone && gAmphibiousAssaultStage == -1)// || gForwardBaseLocation == cInvalidVector) 
   {
      aiPlanDestroy(gforwardArmyPlan);
      gforwardArmyPlan = -1;
      if (aiPlanGetNumberUnits(gforwardArmyTransport, cUnitTypeAbstractWarShip) < 0)
      {  // If we don't destroy it here, the killForwardTransport will get it
         aiPlanDestroy(gforwardArmyTransport);
         gforwardArmyTransport = -1;
      }
      xsDisableSelf();
      return;
   }

   int totalMilitary = kbUnitCount(cMyID, cUnitTypeLogicalTypeLandMilitary);
   int desiredMilitary = totalMilitary * 0.75;
   int maxMilitary = desiredMilitary;
   int currentPlanMilitary = -1;
   int numberForward = -1;
   int numberToTransport = 0;
   int tempUnit = -1;
   int transportPlanID = -1;
   vector pickupPoint = cInvalidVector;
   vector dropoffPoint = cInvalidVector;

   // Set up first run
   if (gforwardArmyPlan < 0)
   {
      gforwardArmyPlan = aiPlanCreate("Forward Army: " + gForwardBaseID, cPlanCombat);
      aiPlanAddUnitType(gforwardArmyPlan, cUnitTypeLogicalTypeLandMilitary, 0, desiredMilitary, maxMilitary); 
      aiPlanSetVariableInt(gforwardArmyPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack); // Attack plans can transport, defend plans cannot
      aiPlanSetVariableInt(gforwardArmyPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      aiPlanSetVariableFloat(gforwardArmyPlan, cCombatPlanTargetEngageRange, 0, 60.0);   // Just use the engage range since it is away from base
      aiPlanSetVariableVector(gforwardArmyPlan, cCombatPlanTargetPoint, 0, gForwardBaseLocation);
      aiPlanSetVariableFloat(gforwardArmyPlan, cCombatPlanGatherDistance, 0, 30.0);
      aiPlanSetInitialPosition(gforwardArmyPlan, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
      aiPlanSetVariableInt(gforwardArmyPlan, cCombatPlanRefreshFrequency, 0, 300);
      aiPlanSetVariableInt(gforwardArmyPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeNone);
      aiPlanSetDesiredPriority(gforwardArmyPlan, 100); // Higher than LandDefendPlan but lower than attack plans
      aiPlanSetActive(gforwardArmyPlan);
   }

   // Make sure anyone on the forward island is in this plan
   int armyQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(armyQueryID);
   int unitID = -1;
   int puid = -1;
   int unitPlanID = -1;
   vector unitLoc = cInvalidVector;
   int mainLand = kbAreaGroupGetIDByPosition(gForwardBaseLocation);

   for (i = 0; < numberFound)
   {
      unitID = kbUnitQueryGetResult(armyQueryID, i);
      unitPlanID = kbUnitGetPlanID(unitID);
      unitLoc = kbUnitGetPosition(unitID);
      if (kbUnitGetPlanID(unitID) != gforwardArmyPlan &&
          aiPlanGetDesiredPriority(unitPlanID) < 99 &&
          kbAreAreaGroupsPassableByLand(mainLand, kbAreaGroupGetIDByPosition(unitLoc)) == true)
      {
         aiPlanAddUnit(gforwardArmyPlan, unitID);
      }
   }

   numberForward = aiPlanGetNumberUnits(gAmphibiousArmyPlan, cUnitTypeLogicalTypeLandMilitary);
   for (i = 0; < numberForward)
   {
      tempUnit = aiPlanGetUnitByIndex(gAmphibiousArmyPlan, i);
      aiPlanAddUnit(gforwardArmyPlan, tempUnit);
   }

   // Check if our army counts have significantly changed. Give a 20% buffer to prevent adding too often
   currentPlanMilitary = aiPlanGetNumberUnits(gforwardArmyPlan, cUnitTypeLogicalTypeLandMilitary);
   int currentTransportPlanShips = aiPlanGetNumberUnits(gforwardArmyTransport, cUnitTypeShip);
   if (currentTransportPlanShips > 0)
   {
      if (xsIsRuleEnabled("killForwardTransport") == false)
      {
         xsEnableRule("killForwardTransport");
      }
   }

   if (desiredMilitary > currentPlanMilitary * 1.2 && gforwardArmyTransport < 0)//aiPlanGetActive(gforwardArmyTransport) == false)
   {
      pickupPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
      dropoffPoint = gAmphibiousAssaultTarget;
      gforwardArmyTransport = createTransportPlan(pickupPoint, dropoffPoint, 100.0, true);

      if (gforwardArmyTransport > 0)
      {
         // Gather all the army units to individually add them to transport plan
         armyQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive);
         numberFound = kbUnitQueryExecute(armyQueryID);
         unitID = -1;
         unitPlanID = -1;
         unitLoc = cInvalidVector;
         mainLand = kbAreaGroupGetIDByPosition(kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
         // Get the number of people on the main island
         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(armyQueryID, i);
            unitPlanID = kbUnitGetPlanID(unitID);
            unitLoc = kbUnitGetPosition(unitID);
            if (kbUnitGetPlanID(unitID) != gforwardArmyPlan &&
               aiPlanGetDesiredPriority(unitPlanID) < 99 &&
               kbAreAreaGroupsPassableByLand(mainLand, kbAreaGroupGetIDByPosition(unitLoc)) == true)
            {
               numberToTransport = numberToTransport + 1;
            }
         }

         aiPlanAddUnitType(gforwardArmyTransport, cUnitTypeLogicalTypeLandMilitary, numberToTransport, numberToTransport, numberToTransport);

         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(armyQueryID, i);
            unitPlanID = kbUnitGetPlanID(unitID);
            unitLoc = kbUnitGetPosition(unitID);
            if (kbUnitGetPlanID(unitID) != gforwardArmyPlan &&
               aiPlanGetDesiredPriority(unitPlanID) < 99 &&
               kbAreAreaGroupsPassableByLand(mainLand, kbAreaGroupGetIDByPosition(unitLoc)) == true)
            {
               aiPlanAddUnit(gforwardArmyTransport, unitID);
            }
         }
         aiPlanSetNoMoreUnits(gforwardArmyTransport, true);

         // Don't go further to attack
         return;
      }
      //aiPlanAddUnitType(gforwardArmyPlan, cUnitTypeLogicalTypeLandMilitary, 0, desiredMilitary, maxMilitary); 
   }

   // If we have everyone, and it's big enough to be a real army, try and push into the enemy base
   //int forwardAttackWave = -1;
   int forwardArmyQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive, gForwardBaseLocation, 40.0);
   int numberFoundArmyQuery = kbUnitQueryExecute(forwardArmyQuery);
   int forwardArmyCount = 0;
   int attackTimeSeconds = xsGetTime() / 1000;
   float armyPower = 0.0;
   for (i = 0; < numberFoundArmyQuery)
   {
      unitID = kbUnitQueryGetResult(forwardArmyQuery, i);
      unitLoc = kbUnitGetPosition(unitID);
      if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(gAmphibiousAssaultTarget), 
                                        kbAreaGroupGetIDByPosition(unitLoc)) == true)
      {
         puid = kbUnitGetProtoUnitID(unitID);
         armyPower = armyPower + getMilitaryUnitStrength(puid);
         forwardArmyCount = forwardArmyCount + 1;
      }
   }
   vector attackLocation = getEnemyBase(-1, armyPower);

   // Army minimums
   int minArmy = -1;
   int enAgeVar = kbGetAgeForPlayer(aiGetMostHatedPlayerID());

   if (enAgeVar == cAge2)
   {
      minArmy = 15;
   }
   else if (enAgeVar == cAge3)
   {
      minArmy = 20;
   }
   else if (enAgeVar == cAge4)
   {
      minArmy = 25;
   }
   else if (enAgeVar == cAge5)
   {
      minArmy = 30;
   }


   if (forwardAttackWave < 0)
   {
      if ((forwardArmyCount >= minArmy || armyPower > minArmy) || (armyPower > 0 && xsGetTime() > gAmphibiousPushTime + gAttackMissionInterval))// && forwardArmyCount > numberForward * 0.7)
      {
         forwardAttackWave = aiPlanCreate("Forward Attack Wave", cPlanCombat);
         aiPlanAddUnitType(forwardAttackWave, cUnitTypeLogicalTypeLandMilitary, 0, forwardArmyCount, forwardArmyCount); 
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
         aiPlanSetVariableFloat(forwardAttackWave, cCombatPlanTargetEngageRange, 0, 60.0);   // Just use the engage range since it is away from base
         aiPlanSetVariableVector(forwardAttackWave, cCombatPlanTargetPoint, 0, attackLocation);
         aiPlanSetVariableFloat(forwardAttackWave, cCombatPlanGatherDistance, 0, 30.0);
         aiPlanSetInitialPosition(forwardAttackWave, gForwardBaseLocation);
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanRefreshFrequency, 0, 300);
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeNone);
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget);
         aiPlanSetVariableInt(forwardAttackWave, cCombatPlanNoTargetTimeout, 0, 30000); // 30 seconds
         aiPlanSetDesiredPriority(forwardAttackWave, 100); 
         aiPlanSetActive(forwardAttackWave);
         for (i = 0; < forwardArmyCount)
         {
            unitID = kbUnitQueryGetResult(forwardArmyQuery, i);
            aiPlanAddUnit(forwardAttackWave, unitID);
         }

         gAmphibiousPushTime = xsGetTime();
      }
   }


}

//==============================================================================
// Set the forward base at the landing spot
// 
//==============================================================================
void establishForwardBase()
{
   // Set the forward base
   int forwardBaseBuilding = getUnitByLocation(gTowerUnit, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 40.0);
   int existingPlanID = -1;
   int forwardVill = -1;
   int planID = -1;

   if (forwardBaseBuilding < 0)
   {
      existingPlanID = aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gTowerUnit);
      if (existingPlanID < 0)
      {
         // We have no tower and no build plan. See if we have a vil to try and work with
         forwardVill = getUnitByLocation(gEconUnit, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 40.0);
         if (forwardVill > 0)
         {
            planID = createLocationBuildPlan(gTowerUnit, 1, 100, true, -1, gAmphibiousAssaultTarget, 1);
            aiPlanAddUnit(planID, forwardVill);
         }
         else
         {
            // We have nothing left
            //gAmphibiousAssaultStage = cNavyRetreat;
         }
      }
   }

   if (gForwardBaseState != cForwardBaseStateActive)
   {
      gForwardBaseState = cForwardBaseStateActive;
      gForwardBaseID = kbBaseCreate(cMyID, "Base at Amphibious Beach Head: " + kbBaseGetNextID(), gAmphibiousAssaultTarget, 60.0);
      gForwardBaseLocation = gAmphibiousAssaultTarget;
      gForwardBaseUpTime = xsGetTime();
      gForwardBaseShouldDefend = true;

      kbBaseSetMilitary(cMyID, gForwardBaseID, true);
      moveDefenseReflex(gAmphibiousAssaultTarget, 50.0, gForwardBaseID);

      // Add all forward buildings to the forward base
      int buildingQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationSelf, cUnitStateAlive,
                                                   gAmphibiousAssaultTarget, 40);
      int buildingNumber = kbUnitQueryExecute(buildingQueryID);
      int tempUnit = -1;
      int tempUnitAreaGroup = -1;
      int forwardBaseAreaGroup = kbAreaGroupGetIDByPosition(gForwardBaseLocation);

      // Check if we have something built. If so, move to next stage
      for (i = 0; < buildingNumber)
      {
         tempUnit = kbUnitQueryGetResult(buildingQueryID, i);
         tempUnitAreaGroup = kbAreaGroupGetIDByPosition(kbUnitGetPosition(tempUnit));
         if (kbAreAreaGroupsPassableByLand(tempUnitAreaGroup, forwardBaseAreaGroup) == true)
         {
            kbBaseAddUnit(cMyID, gForwardBaseID, tempUnit);
         }
      }
   }

   // Keep things running for a minute to keep ships nearby
   /*if (xsGetTime() < gAmphibiousAssaultSavedTime + 60000)
   {
      return;
   }*/

   xsEnableRule("forwardBaseDestroyedCheck");
   //xsEnableRule("transferMilitary");
   if (xsIsRuleEnabled("forwardArmyPlan") == false)
   {
      xsEnableRule("forwardArmyPlan");
   }
   // Call it to try and take the forward army units before we destroy the plan
   forwardArmyPlan();
   //xsEnableRule("fbBuildingChain"); 

   // We're done. Destroy all the plans
   // Set the center of naval operations to the forward base
   //gNavyVec = getCoastalPoint(guessEnemyLocation(), gAmphibiousAssaultTarget, 15, true);
   gAmphibiousAssaultStage = -1;//cGatherNavy;
   aiPlanDestroy(gAmphibiousAssaultPlan);
   aiPlanDestroy(gAmphibiousArmyPlan);
   aiPlanDestroy(gAmphibiousTransportPlan);
   gAmphibiousTransportPlan = -1;
   gAmphibiousAssaultPlan = -1;
   gAmphibiousArmyPlan = -1;
}

//==============================================================================
/* FB building Chain
   builds a chain of several buildings

   Note: caused china to try and build invisible projectiles
*/
//==============================================================================

rule fbBuildingChain
inactive
minInterval 30
{  
   if (gForwardBaseState != cForwardBaseStateActive)
   {
      // Quit early if we don't have the fb
      xsDisableSelf();
      return;
   }

   // Make a couple military building plans to get the jump on the FB building logic
   int building0 = xsArrayGetInt(gMilitaryBuildings, 0);  // typically barracks
   int building1 = xsArrayGetInt(gMilitaryBuildings, 1);  // typically stable
   int tempBuilding = -1;
   bool makeAnother = false;
   int barracksNum = 1;
   int stableNum = 2;
   int vilIndex = 0;
   if (btBiasInf >= btBiasCav)
   {
      barracksNum = 2;
      stableNum = 1;
   }

   int building0num = getUnitCountByLocation(building0, cPlayerRelationSelf, cUnitStateABQ, gAmphibiousAssaultTarget, 30);
   int building1num = -1;

   if (building0num == 0)
   {
      makeAnother = true;
      tempBuilding = building0num;
   }
   else
   {
      building0num = getUnitCountByLocation(building0, cPlayerRelationSelf, cUnitStateABQ, gAmphibiousAssaultTarget, 30);
      building1num = getUnitCountByLocation(building1, cPlayerRelationSelf, cUnitStateABQ, gAmphibiousAssaultTarget, 30);
   }

   if (building0num < barracksNum)
   {
      makeAnother = true;
      tempBuilding = building0num;
   }
   else if (building1num < stableNum)
   {
      makeAnother = true;
      tempBuilding = building1num;
   }
   else
   {
      // We have enough, disable self
      xsDisableSelf();
   }

   if (makeAnother == true)
   {
      int plan0 = createLocationBuildPlan(tempBuilding, barracksNum, 100, true, -1, gAmphibiousAssaultTarget, 1);

      int vilQuery = createSimpleUnitQuery(gEconUnit, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 40);
      int numberVil = kbUnitQueryExecute(vilQuery);
      if (numberVil > 0)
      {
         for (i = 0; < numberVil)
         {  // Add forward villagers
            aiPlanAddUnit(plan0, kbUnitQueryGetResult(vilQuery, i));
         }
      }
   }
}

rule forwardBaseDestroyedCheck
inactive
minInterval 10
{
   // Do we still have buildings or military nearby?
   if (getUnitCountByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 40) <= 0)
   {  
      // No buildings. Check for a decent sized military
      if (getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationSelf, cUnitStateAlive, gAmphibiousAssaultTarget, 30) <= 10)
      {
         gForwardBaseState = cForwardBaseStateNone;
         gForwardBaseID = -1;
         gForwardBaseLocation = cInvalidVector;
         gForwardBaseShouldDefend = false;

         //endDefenseReflex();
         moveDefenseReflex();

         //gAmphibiousAssaultStage = cGatherNavy;
         gAmphibiousAssaultStage = -1;
         aiPlanDestroy(gAmphibiousAssaultPlan);
         aiPlanDestroy(gAmphibiousArmyPlan);
         aiPlanDestroy(gAmphibiousTransportPlan);
         gAmphibiousTransportPlan = -1;
         gAmphibiousAssaultPlan = -1;
         gAmphibiousArmyPlan = -1;

         //xsDisableRule("transferMilitary");
         xsDisableSelf();
      }
   }
}


//==============================================================================
// amphibiousAssault
// Tentative plan:
//   Create stages
//      Gather Navy              first draft done
//      Bombard Coast            first draft done
//      Load Forces              first draft done 
//      Land Forces              first draft done
//      Build forward buildings  first draft done
//      Establish forward base   first draft done
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
bool amphibiousAssault(vector location = cInvalidVector)
{
   if (gAmphibiousAssaultStage > cGatherNavy)
   {  // Already running
      return false;
   }

   // Try a straight shot to enemy base for testing purposes
   location = guessEnemyLocation();
   // test the location
   if (location == cInvalidVector)
   {
      location = selectForwardBaseBeachHead();
   }
   // Try just using the guessed enemy location
   if (location == cInvalidVector)
   {
      location = guessEnemyLocation();
   }
   // If location still sucks, return and wait to be called later
   if (location == cInvalidVector)
   {
      return false;
   }
   // Reset the stage
   gAmphibiousAssaultStage = cGatherNavy;
   //gAmphibiousAssaultTarget = getCoastalPoint(location, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), 3, false)
   gAmphibiousAssaultTarget = selectPickupPoint(location, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), 10, false);
   // Put something here about the time to suppress sending this too much
   if (xsGetTime() > gAmphibiousAssaultSavedTime + 8 * 60 * 1000)
   {
      sendStatement(cPlayerRelationAlly, cAICommPromptToAllyIWillBuildMilitaryBase, gAmphibiousAssaultTarget);
   }
   
   if (gAmphibiousAssaultPlan < 0)
   {
      gAmphibiousAssaultPlan = aiPlanCreate("Amphibious Assault Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousAssaultPlan, cUnitTypeAbstractWarShip, 0, 0, 200);
      //aiPlanSetNoMoreUnits(gAmphibiousAssaultPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousAssaultPlan, 99); // Only lower than transport
      //aiPlanSetActive(gAmphibiousAssaultPlan);
   }

   if (gAmphibiousArmyPlan < 0)
   {
      gAmphibiousArmyPlan = aiPlanCreate("Amphibious Assault Army Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousArmyPlan, cUnitTypeLogicalTypeLandMilitary, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAmphibiousArmyPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousArmyPlan, 99); // Only lower than transport
      //aiPlanSetActive(gAmphibiousArmyPlan);
   }

   if (gAmphibiousTransportPlan < 0)
   {
      gAmphibiousTransportPlan = aiPlanCreate("Amphibious Transport Plan", cPlanReserve);
      aiPlanAddUnitType(gAmphibiousTransportPlan, cUnitTypeAbstractWarShip, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAmphibiousTransportPlan, true);
      aiPlanSetDesiredPriority(gAmphibiousTransportPlan, 100); // Let no one steal us
      aiPlanSetAllowUnderAttackResponse(gAmphibiousTransportPlan, false);  // Don't respond to attack, try to finish transport
      //aiPlanSetActive(gAmphibiousTransportPlan);
   }

   //vector pickupPoint = getDropoffPoint(gAmphibiousAssaultTarget, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), 4);
   //gatherArmy(pickupPoint);

   // Enable the rule to monitor the amphibious assault
   xsEnableRule("amphibiousAssaultStandby");
   return true;
}

//==============================================================================
/* amphibiousAssaultStandby
   AssertiveWall: rule to delay the start of the amphibious assault until we 
   have enough ships
*/
//==============================================================================

rule amphibiousAssaultStandby
inactive
minInterval 3
{
   // Wait until we have some ships to work with to start the chain
   if (gAmphibiousAssaultStage == cGatherNavy)  // Check just in case something weird happens and this gets called multiple times
   {  // Make sure we have enough ships
      int currentAge = kbGetAge();
      int minimumShips = 2;

      if (agingUp() == true)
      {  // Since this takes time, make sure we aren't about to need more
         currentAge += 1;
      }
      
      if (currentAge == cAge3)
      {
         minimumShips = 3;
      }
      else if (currentAge >= cAge4)
      {
         minimumShips = 3;
      }

      if (civIsNative() == true)
      {
         minimumShips = minimumShips * 2;
      }

      if (cMyCiv == cCivDEInca)
      {
         minimumShips = minimumShips - 1;
      }

      if (gIsArchipelagoMap == true)
      {
         minimumShips = minimumShips - 1;
      }

      if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) < minimumShips)
      {
         return;
      }
   }
   else if (xsIsRuleEnabled("amphibiousAssaultRule") == true)
   {
      xsDisableSelf();
      return;
   }
   else
   {  // We should never reach here
      retreatCheck(true);
      xsDisableSelf();
      return;
   }

   gAmphibiousAssaultSavedTime = xsGetTime();

   // activate plans
   aiPlanSetActive(gAmphibiousAssaultPlan);
   aiPlanSetActive(gAmphibiousArmyPlan);
   aiPlanSetActive(gAmphibiousTransportPlan);

   xsEnableRule("baseUnderThreat");
   if (gIsArchipelagoMap == true)
   {
      xsEnableRule("simpleAmphibiousAttackRule");
   }
   else
   {
      xsEnableRule("amphibiousAssaultRule");
   }

}

//==============================================================================
/* amphibiousAssaultRule
   AssertiveWall: rule to keep track of the current state of the 
                  amphibious assault
*/
//==============================================================================

rule amphibiousAssaultRule
inactive
minInterval 3
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

   // First check to see if we're losing or one of the stages failed
   if (retreatCheck() == true || gAmphibiousAssaultStage == -1)
   {
      // Check if we should kick everything off right away again. Basically when we have lots of troops to use
      if (kbUnitCount(cMyID, cUnitTypeLogicalTypeLandMilitary, cUnitStateAlive) > 14 * kbGetAge())
      {
         xsDisableSelf();
         amphibiousAssault();
         return;
      }
      else
      {
         xsDisableSelf();
         return;
      }
   }

   // Check for clumped ships
   if (gAmphibiousAssaultStage == cLoadForces)
   {  // NOTE: This will never happen this way for landings since the transport looks for new spot every 10 seconds
      // for landings, this is called within the landForces() function
      if (xsGetTime() > gAmphibiousAssaultSavedTime + 20000)
      {
         checkForClumpedShips(gLandingShip1, gLandingShip2);
      }
   }

   // Used by multiple rules
   vector mainBaseLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   vector gatherPoint = getCoastalPoint(mainBaseLoc, gAmphibiousAssaultTarget, 5, true);
   vector pickupPoint = selectPickupPoint(mainBaseLoc, gAmphibiousAssaultTarget); //   getDropoffPoint(gAmphibiousAssaultTarget, mainBaseLoc, 4);

   switch (gAmphibiousAssaultStage)
   {
      case cGatherNavy:
      {  // Add navy to plan and send them to the gather point
         gatherNavy(gatherPoint);
         //gatherArmy(pickupPoint);
         break;
      }
      case cBombardCoast:
      {
         gatherArmy(pickupPoint);
         bombardCoast();
         break;
      }
      case cLoadForces:
      {
         bombardCoast(); // Keep bombarding the coast
         loadForces(pickupPoint);
         break;
      }
      case cLandForces:
      {
         bombardCoast(); // Keep bombarding the coast
         //gatherNavy();   // Keep adding navy units to the plan

         landForces();
         break;
      }
      case cBuildForwardBuildings:
      {
         bombardCoast(); // Keep bombarding the coast
         //moveInland();

         //trainFromGalleons();
         buildForwardTowers();
         break;
      }
      case cEstablishForwardBase:
      {
         // Once we're established we can let our navy do other things, except galleons
         //moveInland();
         //trainFromGalleons();
         establishForwardBase();
         break;
      }
   }
}

//==============================================================================
/* simpleAmphibiousAttackRule
   AssertiveWall: simpler than the amphibious assault rule, skipping over the
                  base building part
*/
//==============================================================================

rule simpleAmphibiousAttackRule
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

   // First check to see if we're losing or one of the stages failed
   if (retreatCheck() == true || gAmphibiousAssaultStage == -1)
   {
      // Check if we should kick everything off right away again. Basically when we have lots of troops to use
      if (kbUnitCount(cMyID, cUnitTypeLogicalTypeLandMilitary, cUnitStateAlive) > 14 * kbGetAge())
      {
         xsDisableSelf();
         amphibiousAssault();
         return;
      }
      else
      {
         xsDisableSelf();
         return;
      }
   }

   // Used by multiple rules
   vector mainBaseLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
   vector gatherPoint = getCoastalPoint(mainBaseLoc, gAmphibiousAssaultTarget, 5, true);
   vector pickupPoint = selectPickupPoint(mainBaseLoc, gAmphibiousAssaultTarget); //   getDropoffPoint(gAmphibiousAssaultTarget, mainBaseLoc, 4);

   switch (gAmphibiousAssaultStage)
   {
      case cGatherNavy:
      {  // Add navy to plan and send them to the gather point
         gatherNavy(gatherPoint);
         gatherArmy(pickupPoint);
         break;
      }
      case cBombardCoast:
      {
         //gatherArmy(pickupPoint);
         //bombardCoast();
         gAmphibiousAssaultStage = cLoadForces;
         break;
      }
      case cLoadForces:
      {
         //bombardCoast(); // Keep bombarding the coast
         loadForces(pickupPoint);
         break;
      }
      case cLandForces:
      {
         bombardCoast(); // Keep bombarding the coast
         //gatherNavy();   // Keep adding navy units to the plan

         landForces();
         break;
      }
      case cBuildForwardBuildings:
      {
         gAmphibiousAssaultStage = cEstablishForwardBase;
      }
      case cEstablishForwardBase:
      {
         // Once we're established we can let our navy do other things, except galleons
         //moveInland();
         
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

   // Create a water attack plan at the dropoff point
   int navalTargetPlayer = aiGetMostHatedPlayerID();
   vector targetDockPosition = getCoastalPoint(location, kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), 5, true);
   int time = xsGetTime();

   gNavyAttackPlan = aiPlanCreate("NAVAL Attack assist landing");
   
   aiPlanAddUnitType(gNavyAttackPlan, cUnitTypeAbstractWarShip, 1, 200, 200);
   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanTargetPlayerID, 0, navalTargetPlayer);
   aiPlanSetVariableVector(gNavyAttackPlan, cCombatPlanTargetPoint, 0, targetDockPosition);
   aiPlanSetVariableVector(gNavyAttackPlan, cCombatPlanGatherPoint, 0, gNavyVec);
   aiPlanSetVariableFloat(gNavyAttackPlan, cCombatPlanGatherDistance, 0, 40.0);
   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);
   aiPlanSetDesiredPriority(gNavyAttackPlan, 60); // Per the chart

   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanRefreshFrequency, 0, 300);

   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget);
   aiPlanSetVariableInt(gNavyAttackPlan, cCombatPlanNoTargetTimeout, 0, 30000);
   aiPlanSetBaseID(gNavyAttackPlan, kbUnitGetBaseID(getUnit(gDockUnit, cMyID, cUnitStateAlive)));
   aiPlanSetInitialPosition(gNavyAttackPlan, gNavyVec);

   aiPlanSetActive(gNavyAttackPlan);
   gLastNavalAttackTime = time;

   aiPlanSetEventHandler(gNavyAttackPlan, cPlanEventStateChange, "navalAttackPlanHandler");
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

   int enemyTC = getUnitByLocation(cUnitTypeAgeUpBuilding, enemyPlayer, cUnitStateAlive, mainBaseVec, 500.0);
   float radius = 0.0;
   vector vec = cInvalidVector;
   vector bestLoc = cInvalidVector;
   float bestDist = 0.0;
   int enemyBuildingQuery = createSimpleUnitQuery(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(enemyBuildingQuery);

   if (enemyTC < 0)
   {
      v = guessEnemyLocation(enemyPlayer);
      radius = 100.0;
      if (getUnitCountByLocation(cUnitTypeLogicalTypeBuildingsNotWalls, enemyPlayer, cUnitStateAlive, v, radius) <= 0)
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
            if (getUnitByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive, retVal, 50.0) >= 0)
            {
               siteFound = false;
            }
            else if (mainAreaGroup != kbAreaGroupGetIDByPosition(retVal))
            {
               siteFound = false;
            }
            else if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(retVal), 
                     kbAreaGroupGetIDByPosition(guessEnemyLocation())) == true)
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
float getAreaStrength(vector locationOfInterest = cInvalidVector, int searchRadius = 10, int playerRelation = cPlayerRelationEnemyNotGaia)
{
   float MilitaryPower = 0.0;
   int numberEnemyFound = 0;
   int unitID = -1;
   int puid = -1;

   int baseEnemyQuery = kbUnitQueryCreate("areaEnemyUnitQuery");
   kbUnitQuerySetIgnoreKnockedOutUnits(baseEnemyQuery, true);

   kbUnitQuerySetPlayerRelation(baseEnemyQuery, playerRelation);
   kbUnitQuerySetState(baseEnemyQuery, cUnitStateAlive);
   kbUnitQuerySetPosition(baseEnemyQuery, locationOfInterest);
   kbUnitQuerySetMaximumDistance(baseEnemyQuery, searchRadius);

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
float getFriendlyArmyValue(int companyPlan = -1)
{
   int unitID = -1;
   int puid = -1;
   float armyPower = 0.0;
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
   float enemyStrength = getAreaStrength(unitLocation, 40.0, cPlayerRelationEnemyNotGaia);
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
   float enemyStrength = getAreaStrength(companyLoc, 20.0, cPlayerRelationEnemyNotGaia);
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

   float enMilitaryPowerAlpha = 0.0;
   float enMilitaryPowerBravo = 0.0;

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
   int dockPlanID = aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gDockUnit);
   int queuedWarShips = kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) - kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive);
   int queuedFishingBoats = kbUnitCount(cMyID, gFishingUnit, cUnitStateABQ) - kbUnitCount(cMyID, gFishingUnit, cUnitStateAlive);
   bool shouldBuild = false;

   // If we already have a dock planned, return false
   if (dockPlanID > 0)
   {
      return false;
   }

   // AssertiveWall: Hard and above on water spawn maps makes 2 docks Age 1 and 2, 4 Age 3 and above
   // Below Hard makes 1 and 2, respectfully
   // No dock building until age2 transition
   if ((((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 1)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 2) && (time > 8 * 60 * 1000)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 3) && (time > 12 * 60 * 1000)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gStartOnDifferentIslands == true) && (age >= cAge3)) && (dockCount < 4)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && ((gStartOnDifferentIslands == true) && (age >= cAge4)) && (dockCount < 5)) ||
      ((cDifficultyCurrent < cDifficultyHard) && ((gNavyMap == true) && (age <= cAge2)) && (dockCount < 1)) ||
      ((cDifficultyCurrent < cDifficultyHard) && ((gNavyMap == true) && (age >= cAge3)) && (dockCount < 2)) ||
      ((gTimeToFish == true) && (dockCount < 2)) ||
      ((cDifficultyCurrent >= cDifficultyHard) && (age >= cAge4) && (dockCount < 3))) && 
      ((age >= cAge2 || agingUp() == true) && (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gDockUnit) <= 0)))
   {
      shouldBuild = true;
   }

   // Check if we don't have enough ships queued
   // Only do this if we already have at least 1 dock
   if (dockCount >= 1 && gIsPirateMap == false)
   {
      if ((queuedWarShips + queuedFishingBoats) < dockCount)
      {
         shouldBuild = false;
      }
   }


   return shouldBuild;
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
   float enemyStrength = 0.0;
   vector location = cInvalidVector;
   float friendlyStrength = getFriendlyArmyValue(gcavalryCompanyPlan);

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


//==============================================================================
/* attackRetreat
   AssertiveWall: checks if the attacking force needs to retreat
      Kills the plan and returns all units to the forward base or main base

*/
//==============================================================================
rule attackRetreatDelay
inactive
minInterval 10
{
   if (aiPlanGetNumberUnits(gLandAttackPlanID, cUnitTypeLogicalTypeLandMilitary) > 0)
   {
      xsEnableRule("attackRetreat");
      xsDisableSelf();
   }
}

rule attackRetreat
inactive
minInterval 10
{
   if (gLandAttackPlanID < 0)
   {
      // No attack plan to work with
      xsDisableSelf();
      return;
   }

   // No retreat on king of the hill if there are more than 2 teams
   /*if (aiGetNumberTeams() > 3 && aiIsKOTHAllowed() == true)
   {
      xsDisableSelf();
      return;
   }*/

   vector targetLocation = cInvalidVector;
   int friendlyArmySize = aiPlanGetNumberUnits(gLandAttackPlanID, cUnitTypeLogicalTypeLandMilitary);
   float friendlyStrength = 0.0;
   float allyStrength = 0.0;
   float enemyStrength = 0.0;
   bool retreat = false;
   int tempUnit = -1;
   vector retreatLoc = cInvalidVector;
   bool allyNear = false;
   bool weAreWinning = false;
   vector allyTargetLocation = cInvalidVector;
   bool toTheDeath = false;  // kill the plan, but don't tell people to run away
   float strengthFactor = 0.6;

   // Do some math to adjust our retreat factor a little bit based on our offense/defense disposition
   // Offense: 0 | Defense: 1.0
   // Higher number means more likely to retreat. All values fall between 0.6 and 0.7
   strengthFactor = strengthFactor + btOffenseDefense / 10.0;
   // A check, just in case and to make this future-proof
   if (strengthFactor > 0.7)
   {
      strengthFactor = 0.7;
   }
   else if (strengthFactor < 0.6)
   {
      strengthFactor = 0.6;
   }

   // Check the strength of our army
   friendlyStrength = getFriendlyArmyValue(gLandAttackPlanID);
   targetLocation = aiPlanGetVariableVector(gLandAttackPlanID, cCombatPlanTargetPoint, 0);

   // Check strength of enemy and ally army at our target location
   enemyStrength = getAreaStrength(targetLocation, 50, cPlayerRelationEnemyNotGaia);
   allyStrength = getAreaStrength(targetLocation, 50, cPlayerRelationAllyExcludingSelf);

   // Retreat if our strength is too small
   if (friendlyStrength + allyStrength < enemyStrength * strengthFactor)
   {
      if (allyStrength > 0)
      {
         allyNear = true;
         allyTargetLocation = targetLocation;
      }
      retreat = true;
   }
   // We are winning if we have double the enemy strength, and the enemy has at least 20 musk worth of units
   // Need something to prevent this from firing multiple times
   /*else if ((friendlyStrength + allyStrength > enemyStrength * 2.0) && enemyStrength > 2000)
   {
      weAreWinning = true;
   }*/

   // Now look at where we are using the first unit, but only if we don't already know we're retreating
   if (retreat == false)
   {
      targetLocation = kbUnitGetPosition(aiPlanGetUnitByIndex(gLandAttackPlanID, 0));

      // Recheck strength of enemy and ally army at our target location
      enemyStrength = getAreaStrength(targetLocation, 50, cPlayerRelationEnemyNotGaia);
      allyStrength = getAreaStrength(targetLocation, 50, cPlayerRelationAllyExcludingSelf);

      // Retreat if our strength is too small
      if ((friendlyStrength + allyStrength < enemyStrength * strengthFactor) && retreat == false)
      {
         if (allyStrength > 0)
         {
            allyNear = true;
            allyTargetLocation = targetLocation;
         }
         retreat = true;
      }
   }

   // If we're too close to the timer on KoTH then don't retreat 
   // This only works when there is only 2 teams, otherwise gKOTHEnemyTimer doesn't count down
   if ((aiIsKOTHAllowed() == true)) //gKOTHEnemyTimer < 300 && 
   {
      toTheDeath = true;
      retreat = false;
   }

   // Make sure we retreat if we have no one left
   if (friendlyStrength < 2) // 2 musketeers. We need at least 3
   {
      retreat = true;
      toTheDeath = true;
   }

   // Tell everyone to go back to base and delete the plan
   if (retreat == true)
   {
      // Attempt to set the plan inactive before telling everyone to return
      aiPlanSetActive(gLandAttackPlanID, false);

      // Set the base to return to
      if (gForwardBaseState == cForwardBaseStateActive && gForwardBaseLocation != cInvalidVector)
      {
         retreatLoc = gForwardBaseLocation;
      }
      else
      {
         retreatLoc = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
      }

      // Task everyone to return
      if (toTheDeath == false)
      {
         for (i = 0; < friendlyArmySize)
         {
            tempUnit = aiPlanGetUnitByIndex(gLandAttackPlanID, i);
            aiTaskUnitMove(tempUnit, retreatLoc);
         }
      }


      // Handle the failed chats
      // First see if allies are close by
      if (allyNear == true)
      {
         // I guess we can't use this one. A couple suggestions for later:
         /*cAICommPromptToAllyWeAreLosingHeIsStronger
         cAICommPromptToAllyWeAreLosingHeIsWeaker
         cAICommPromptToAllyAdviceWithdrawFromBattle
         */
      }
      else
      {
         // If not, go through failure chats
         targetLocation = aiPlanGetVariableVector(gLandAttackPlanID, cCombatPlanTargetPoint, 0);
         switch (gAttackTargetType)
         {
            case cAttackTargetTown:
            case cAttackTargetBase:
            {
               sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIFailedToDestroyTown, targetLocation);
            }
            case cAttackTargetTradeSite:
            {
               sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIFailedToDestroyTradeSite, targetLocation);
            }
            case cAttackTargetSettlers:
            {
               // nothing for now
            }
         }
      }

      // Destroy the plan.
      aiPlanDestroy(gLandAttackPlanID);
      aiPlanSetNoMoreUnits(gLandAttackPlanID, true);
      gLandAttackPlanID = -1;
      xsDisableSelf();
   }
   // If we aren't retreating, check if we can send a winning chat
   else
   {
      // Not written for now
      //cAICommPromptToAllyWeAreWinning
      //cAICommPromptToAllyBattleOverIWonAsExpected
   }
}

//==============================================================================
/* forwardTowerBaseManager
   Based on Forward base manager
   Handles the planning, construction, defense and maintenance of a forward military base.

   The steps involved:
   1)  Choose a location.
   2)  Defend it and send a fort wagon to build a fort.
   3)  Define it as the military base, move defend plans there, move military production there.
   4)  Undo those settings if it needs to be abandoned.
*/
//==============================================================================
rule forwardTowerBaseManager
inactive
minInterval 30
{
   if (aiTreatyActive() == true)
   {
      return;
   }

   if (gStartOnDifferentIslands == true)
   {
      if (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateAlive) <= 0)
      {
         return;
      }
   }

   int fortUnitID = -1;
   int buildingQuery = -1;
   int numberFound = 0;
   int numberMilitaryBuildings = 0;
   int buildingID = -1;
   int availableTowerWagon = findWagonToBuild(gTowerUnit);

   // AssertiveWall: On island maps, run the forwardtowerbase if we don't have a fort wagon or base already going
   if (gStartOnDifferentIslands == true && availableTowerWagon < 0 && gForwardBaseState == cForwardBaseStateNone)
   {
      if (amphibiousAssault() == true)
      {
         xsDisableSelf();
      }
      return;
   }

   // We have a Fort Wagon but also already have a forward base, default the Fort position.
   if ((availableTowerWagon >= 0) && (gForwardBaseState != cForwardBaseStateNone))
   {
      //createSimpleBuildPlan(gTowerUnit, 1, 87, true, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
      createSimpleBuildPlan(gTowerUnit, 1, 87, true, cMilitaryEscrowID, gForwardBaseID, 1);
      return;
   }

   switch (gForwardBaseState)
   {
      case cForwardBaseStateNone:
      {
         // We don't have a forward base, if we have a suitable Wagon we can start the chain.
         vector location = cInvalidVector;
         //if (availableTowerWagon >= 0)
         if (true == true)
         {
            // Get the Fort Wagon, start a build plan, if we go forward we try to defend it.
            //vector location = cInvalidVector;  AssertiveWall: moved up above
   
            // AssertiveWall: Use the forward island
            if (gStartOnDifferentIslands == true && (gMigrationMap == false))
            {
               location = selectForwardBaseBeachHead();
               if (location == cInvalidVector)
               {  // We never build in base with the tower forward base
                  return;
               }
               else if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(location), 
                     kbAreaGroupGetIDByPosition(guessEnemyLocation())) == false)
               {
                  // Try again if the FB isn't on the same island as the enemy
                  return;
               }
            }
            else if (cDifficultyCurrent >= cDifficultyModerate)
            {
               location = selectForwardBaseLocation();
            }
   
            if (location == cInvalidVector)
            {  // We never build in base with the tower forward base
               return;
            }
   
            gForwardBaseLocation = location;
            gForwardBaseBuildPlan = aiPlanCreate("Forward Tower build plan ", cPlanBuild);
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanBuildingTypeID, 0, gTowerUnit);
            aiPlanSetDesiredPriority(gForwardBaseBuildPlan, 87);
            aiPlanAddUnitType(gForwardBaseBuildPlan, gEconUnit, 1, 2, 2);
   
            // Instead of base ID or areas, use a center position.
            aiPlanSetVariableVector(gForwardBaseBuildPlan, cBuildPlanCenterPosition, 0, location);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanCenterPositionDistance, 0, 50.0);
   
            // Weigh it to stay very close to center point.
            aiPlanSetVariableVector(gForwardBaseBuildPlan, cBuildPlanInfluencePosition, 0, location);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluencePositionDistance, 0, 50.0); // 100m range.
            // 100 Points for center.
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluencePositionValue, 0, 100.0); 
            // Linear slope falloff.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); 
   
            // Add position influence for nearby Forts.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitTypeID, 0, cUnitTypeFortFrontier); 
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitDistance, 0, 50.0);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitValue, 0, -200.0); // -200 points per fort
            // Cliff falloff.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffNone); 

            aiPlanSetActive(gForwardBaseBuildPlan);
   
            // Chat to my allies.
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, gForwardBaseLocation);
            gForwardBaseState = cForwardBaseStateBuilding;
            if (gStartOnDifferentIslands == true)
            {  // This should no longer be used now that we have the amphibious assault rule
               establishForwardBeachHead(gForwardBaseLocation); 
            }

            debugBuildings("");
            debugBuildings("BUILDING FORWARD BASE, MOVING DEFEND PLANS TO COVER");
            debugBuildings("PLANNED LOCATION IS " + gForwardBaseLocation);
            debugBuildings("");
   
            if (gDefenseReflex == false)
            {
               endDefenseReflex(); // Causes it to move to the new location.
            }
         }
         break;
      }
      case cForwardBaseStateBuilding:
      {
         fortUnitID = getUnitByLocation(gTowerUnit, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
         vector fortUnitLoc = kbUnitGetPosition(fortUnitID);
         if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(fortUnitLoc), 
                                          kbAreaGroupGetIDByPosition(gForwardBaseLocation)) == false)
         {
            fortUnitID = -1;
         }

         if (fortUnitID < 0)
         {
            // Check for other military buildings.
            buildingQuery = createSimpleUnitQuery(cUnitTypeMilitaryBuilding, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
            numberFound = kbUnitQueryExecute(buildingQuery);
            numberMilitaryBuildings = xsArrayGetSize(gMilitaryBuildings);
            for (i = 0; < numberFound)
            {
               buildingID = kbUnitQueryGetResult(buildingQuery, i);
               for (j = 0; < numberMilitaryBuildings)
               {
                  if (kbUnitIsType(buildingID, xsArrayGetInt(gMilitaryBuildings, j)) == true)
                  {
                     fortUnitID = buildingID;
                     break;
                  }
               }
               if (fortUnitID >= 0)
               {
                  break;
               }
            }
         }
         else if (fortUnitID >= 0)
         { // Building exists and is complete, go to state Active.
            if (kbUnitGetBaseID(fortUnitID) >= 0)
            { // Base has been created for it.
               // AssertiveWall: Now build wall
               if (gStartOnDifferentIslands == false)
               {
                  xsEnableRule("forwardBaseWall"); // AssertiveWall: Chain of rules to build walls and towers
               }
               gForwardBaseState = cForwardBaseStateActive;
               gForwardBaseID = kbBaseCreate(cMyID, "Forward Tower Base: " + kbBaseGetNextID(), kbUnitGetPosition(fortUnitID), 40.0);
               gForwardBaseLocation = kbUnitGetPosition(fortUnitID);
               gForwardBaseUpTime = xsGetTime();
               gForwardBaseShouldDefend = kbUnitIsType(fortUnitID, gTowerUnit);
               debugBuildings("Forward base location is " + gForwardBaseLocation + ", Base ID is " + 
                  gForwardBaseID + ", Unit ID is " + fortUnitID);
               debugBuildings("");
               debugBuildings("FORWARD BASE COMPLETED, GOING TO STATE ACTIVE");
               debugBuildings("");
            }
            else
            {
               debugBuildings("");
               debugBuildings("FORT COMPLETE, WAITING FOR FORWARD BASE ID");
               debugBuildings("");
            }
         }
         else // Check if plan still exists. If not, go back to state 'none'.
         {
            if (aiPlanGetState(gForwardBaseBuildPlan) < 0)
            { // It failed?
               gForwardBaseState = cForwardBaseStateNone;
               gForwardBaseLocation = cInvalidVector;
               gForwardBaseID = -1;
               gForwardBaseBuildPlan = -1;
               gForwardBaseShouldDefend = false;
               debugBuildings("");
               debugBuildings("FORWARD BASE PLAN FAILED, RETURNING TO STATE NONE");
               debugBuildings("");
            }
         }
         break;
      }
      case cForwardBaseStateActive:
      { // Normal state. If fort is destroyed and base overrun, bail.
         fortUnitID = getUnitByLocation(gTowerUnit, cMyID, cUnitStateAlive, gForwardBaseLocation, 50.0);
         if (fortUnitID < 0)
         {
            // Check for other military buildings.
            buildingQuery = createSimpleUnitQuery(cUnitTypeMilitaryBuilding, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
            numberFound = kbUnitQueryExecute(buildingQuery);
            numberMilitaryBuildings = xsArrayGetSize(gMilitaryBuildings);
            for (i = 0; < numberFound)
            {
               buildingID = kbUnitQueryGetResult(buildingQuery, i);
               for (j = 0; < numberMilitaryBuildings)
               {
                  if (kbUnitIsType(buildingID, xsArrayGetInt(gMilitaryBuildings, j)) == true)
                  {
                     fortUnitID = buildingID;
                     break;
                  }
               }
               if (fortUnitID >= 0)
               {
                  break;
               }
            }
         }
         if (fortUnitID < 0)
         {
            // Fort is missing, is base still OK?
            if (((gDefenseReflexBaseID == gForwardBaseID) && (gDefenseReflexPaused == true)) ||
               (kbBaseGetNumberUnits(cMyID, gForwardBaseID, cPlayerRelationSelf, cUnitTypeBuilding) < 1)) 
            {  // No, not OK. Get outa Dodge.
               gForwardBaseState = cForwardBaseStateNone;
               gForwardBaseID = -1;
               gForwardBaseLocation = cInvalidVector;
               gForwardBaseShouldDefend = false;

               endDefenseReflex();
               debugBuildings("");
               debugBuildings("ABANDONING FORWARD BASE, RETREATING TO MAIN BASE");
               debugBuildings("");
            }
         }
         break;
      }
   }
}



//==============================================================================
/* forceAttack: 
   Simple attack logic that will just force an attack on the enemy 
   after too long
*/
//==============================================================================
rule forceAttack
inactive
minInterval 30
{
   if (gAmphibiousAssaultStage > 0)
   {
      xsDisableSelf();
      return;
   }
   int currentTime = xsGetTime();
   int modifiedAttackInterval = gAttackMissionInterval;
   bool attackNow = false;
   vector enemyLoc = cInvalidVector;

   if (gStrategy == cStrategyRush)
   { // Rushing
      if (kbGetAge() == cAge2)
      {
         if (currentTime > gLastAttackMissionTime + gAttackMissionInterval * 0.6)
         {
            attackNow = true;
         }
      }
      else if (kbGetAge() >= cAge3)
      {
         if (currentTime > gLastAttackMissionTime + gAttackMissionInterval)
         {
            attackNow = true;
         }
      }
   }
   else
   { // Booming
      if (kbGetAge() >= cAge3)
      {
         if (currentTime > gLastAttackMissionTime + gAttackMissionInterval * 1.1)
         {
            attackNow = true;
         }
      }
      else if (kbGetAge() >= cAge4)
      {
         if (currentTime > gLastAttackMissionTime + gAttackMissionInterval)
         {
            attackNow = true;
         }
      }
   }

   if (attackNow == true)
   {
      int forcedAttack = -1;
      vector mainLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
      int forwardArmyQuery = createSimpleUnitQuery(cUnitTypeLogicalTypeLandMilitary, cMyID, cUnitStateAlive, mainLocation, 60.0);
      int numberFoundArmyQuery = kbUnitQueryExecute(forwardArmyQuery);
      int forwardArmyCount = 0;
      float armyPower = 0.0;
      int unitID = -1;
      vector unitLoc = cInvalidVector;
      int puid = -1;

      for (i = 0; < numberFoundArmyQuery)
      {
         unitID = kbUnitQueryGetResult(forwardArmyQuery, i);
         unitLoc = kbUnitGetPosition(unitID);
         if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(mainLocation), 
                                          kbAreaGroupGetIDByPosition(unitLoc)) == true)
         {
            puid = kbUnitGetProtoUnitID(unitID);
            armyPower = armyPower + getMilitaryUnitStrength(puid);
            forwardArmyCount = forwardArmyCount + 1;
         }
      }

      if (armyPower < 12 * kbGetAge())
      {
         return;
      }

      enemyLoc = getEnemyBase(aiGetMostHatedPlayerID(), );

      forwardAttackWave = aiPlanCreate("Forced Attack Wave", cPlanCombat);
      aiPlanAddUnitType(forcedAttack, cUnitTypeLogicalTypeLandMilitary, 10, forwardArmyCount, forwardArmyCount); 
      aiPlanSetVariableInt(forcedAttack, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
      aiPlanSetVariableInt(forcedAttack, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      aiPlanSetVariableFloat(forcedAttack, cCombatPlanTargetEngageRange, 0, 80.0);   // Just use the engage range since it is away from base
      aiPlanSetVariableVector(forcedAttack, cCombatPlanTargetPoint, 0, enemyLoc);
      aiPlanSetVariableFloat(forcedAttack, cCombatPlanGatherDistance, 0, 30.0);
      aiPlanSetInitialPosition(forcedAttack, mainLocation);
      aiPlanSetVariableInt(forcedAttack, cCombatPlanRefreshFrequency, 0, 300);
      aiPlanSetVariableInt(forcedAttack, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeNone);
      aiPlanSetVariableInt(forcedAttack, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget);
      aiPlanSetVariableInt(forcedAttack, cCombatPlanNoTargetTimeout, 0, 20000); // 20 seconds
      aiPlanSetDesiredPriority(forcedAttack, 100); 
      aiPlanSetActive(forcedAttack);

      gLastAttackMissionTime = currentTime;
   }
}