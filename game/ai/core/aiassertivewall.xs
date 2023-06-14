//==============================================================================
/* aiAssertiveWall.xs

   This file contains additional functions written by Assertive Wall

*/
//==============================================================================



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
/* getRandomIslandBase
   AssertiveWall: This function gives you a random island base
*/
//==============================================================================
int getRandomIslandBase(int numberIslands = -1)
{
   if (cRandomMapName == "Ceylon" || cRandomMapName == "ceylonlarge")
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
   if (cRandomMapName == "Ceylon" || cRandomMapName == "ceylonlarge")
   {
      if(getIslandCount() >= 2)
      {
         return false;
      }
      else
      {
         return true;
      }
   }
   if (gTimeToFarm == false && gTimeForPlantations == false)
   {
      return true;
   }
   
   return false;
}


//==============================================================================
/* villagerFerry
   AssertiveWall: This function grabs idle villagers and transports them to the 
   desired base and adds them to that base
   
   Pickup and dropoff is a baseID, not a location
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
   ** not in use **
*/
//==============================================================================

vector getRandomIsland()
{
   int numberAreaGroups = 0;
   static int areaGroupIDs = -1;
   int areaGroupID = -1;
   int baseAreaGroupID = kbAreaGroupGetIDByPosition(kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
   static vector islandExplorePosition = cInvalidVector;
   int numberAreas = 0;   
   static int areaIDs = -1;
   int areaID = -1;
   int numberBorderAreas = 0;
   int borderAreaID = -1;
   vector location = cInvalidVector;
   bool startingIsland = false;
   vector tempPlayerVec = cInvalidVector;
   int thisVecAreaGroupID = -1;

   if (cRandomMapName == "Ceylon" || cRandomMapName == "ceylonlarge")
   {
      return kbGetMapCenter();
   }

   numberAreaGroups = kbAreaGroupGetNumber();
   randomShuffleIntArray(areaGroupIDs, numberAreaGroups);
   for (i = 0; < numberAreaGroups)
   {
      areaGroupID = xsArrayGetInt(areaGroupIDs, i);
      if (areaGroupID == baseAreaGroupID || /*areaGroupID == kbAreaGroupGetIDByPosition(islandExplorePosition) ||*/
            kbAreaGroupGetType(areaGroupID) != cAreaGroupTypeLand)
      {
         continue;
      }
      numberAreas = kbAreaGroupGetNumberAreas(areaGroupID);
      for (j = 0; < numberAreas)
      {
         xsArraySetInt(areaIDs, j, kbAreaGroupGetAreaID(areaGroupID, j));
      }
      randomShuffleIntArray(areaIDs, numberAreas);
      for (j = 0; < numberAreas)
      {
         areaID = xsArrayGetInt(areaIDs, j);
         numberBorderAreas = kbAreaGetNumberBorderAreas(areaID);
         for (k = 0; < numberBorderAreas)
         {
            borderAreaID = kbAreaGetBorderAreaID(areaID, k);
            if (kbAreaGetType(borderAreaID) == cAreaTypeWater)
            {
               location = kbAreaGetCenter(areaID);
               // Check if the island is any player's starting island
               for (player = 1; < cNumberPlayers)
               {
                  tempPlayerVec = kbGetPlayerStartingPosition(player);
                  if (kbAreAreaGroupsPassableByLand(areaID, kbAreaGroupGetIDByPosition(tempPlayerVec)) == true)
                  {
                     startingIsland = true;
                  }
               }
               if (startingIsland == false)
               {
                  return location;
               }
            }
         }
      }
   }
   return cInvalidVector;
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
   if (cRandomMapName == "Ceylon" || cRandomMapName == "ceylonlarge")
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
minInterval 20
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
      if (newIsland != cInvalidVector)
      {
         dropoff = createNewIslandBase(newIsland, totalIslands);
         totalIslands = getIslandCount();
      }
   }

   // If we aren't making a new island, check if we have any islands to transport to
   //if (totalIslands <= 1)
   //{
   //   return;
   //}

   // If we made it this far, we have multiple islands, some idle villagers, and a ship to 
   // transport them but if we have no new base select a random existing one
   if (islandNeeded == false)
   {
      dropoff = getRandomIslandBase(totalIslands);
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
minInterval 15
{  
   // Only fire if we have ships for transport
   if (kbUnitCount(cMyID, cUnitTypeLogicalTypeGarrisonInShips, cUnitStateAlive) <= 0)
   {
      return;
   }

   int areaCount = 0;
   vector myLocation = cInvalidVector;
   int myAreaGroup = -1;

   int area = 0;
   int areaGroup = -1;
   int unit = getUnitByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, kbBaseGetLocation(gOriginalBase), 50); // getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);

   if (unit <= 0)
   {
      return;
   }

   myLocation = kbUnitGetPosition(unit);

   int transportPlan = createTransportPlan(myLocation, kbAreaGetCenter(gCeylonStartingTargetArea), 50);
   
   int numberNeeded = getUnitCountByLocation(cUnitTypeAbstractWagon, cMyID, cUnitStateAlive, kbBaseGetLocation(gOriginalBase), 50.0);
   int numberSettlers = getUnitCountByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAny, kbBaseGetLocation(gOriginalBase), 50.0);
   
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractWagon, numberNeeded, numberNeeded, numberNeeded);
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractVillager, numberSettlers, numberSettlers, numberSettlers);
   aiPlanSetNoMoreUnits(transportPlan, true);

   //numberNeeded = getUnitCountByLocation(cUnitTypeLogicalTypeScout, cMyID, cUnitStateAlive, kbBaseGetLocation(gOriginalBase), 50.0);
   //aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeScout, numberNeeded, numberNeeded, numberNeeded);

   // go the entire game to catch stray settlers/wagons/scouts
}


//==============================================================================
/* islandMigration
   Based on Ceylon Nomad Start
*/
//==============================================================================

rule islandMigration
inactive
minInterval 20
{  // cUnitTypeypMarathanCatamaran
   //gCeylonDelay = true; // Causes building manager and military manager to wait
   int shipType = cUnitTypeLogicalTypeGarrisonInShips;
   if (kbUnitCount(cMyID, shipType, cUnitStateAlive) <= 0)
   {
      shipType = cUnitTypeypMarathanCatamaran;
      if (kbUnitCount(cMyID, shipType, cUnitStateAlive) <= 0)
      {
         gCeylonDelay = false;
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

      float dist = xsVectorLength(kbAreaGetCenter(area) - myLocation);
      if (dist < closestAreaDistance)
      {
         closestAreaDistance = dist;
         closestArea = area;
      }
   }

   // Move someone toward the center so we can see our landing spot
   aiTaskUnitMove(getUnit(shipType, cMyID, cUnitStateAlive), kbAreaGetCenter(closestArea));
   
   gCeylonStartingTargetArea = closestArea;

   // This used to be "islandwaitforexplore" but a separate rule no longer necessary
   //int unit = getUnit(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive);

   int baseID = kbBaseCreate(cMyID, "Transport gather base", myLocation, 10.0);
   kbBaseAddUnit(cMyID, baseID, unit);

   int transportPlan = createTransportPlan(myLocation, kbAreaGetCenter(gCeylonStartingTargetArea), 100.0, false);
   // sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbAreaGetCenter(gCeylonStartingTargetArea));
   
   // Temporarily move main base to landing area to avoid instant retransport
   kbBaseSetPositionAndDistance(cMyID, kbBaseGetMainID(cMyID), kbAreaGetCenter(gCeylonStartingTargetArea), 50.0);

   aiPlanSetEventHandler(transportPlan, cPlanEventStateChange, "initIslandTransportHandler");

   //int numberNeeded = getUnitCountByLocation(cUnitTypeAbstractWagon, cMyID, cUnitStateAlive, startingLoc, 100.0);
   int numberSettlers = getUnitCountByLocation(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive, startingLoc, 100.0);
   
   //aiPlanAddUnitType(transportPlan, cUnitTypeAbstractWagon, numberNeeded, numberNeeded, numberNeeded);
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractVillager, numberSettlers, numberSettlers, numberSettlers);
   aiPlanSetNoMoreUnits(transportPlan, true);

   //numberNeeded = getUnitCountByLocation(cUnitTypeLogicalTypeScout, cMyID, cUnitStateAlive, startingLoc, 100.0);
   //aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeScout, numberNeeded, numberNeeded, numberNeeded);


   xsEnableRule("initIslandFailsafe");

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
            dist = dist - i * 20;
            gTCSearchVector = centerPoint + vec * dist;
            if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(gTCSearchVector), kbAreaGroupGetIDByPosition(centerPoint)) == true)
            {
               gStartingLocationOverride = gTCSearchVector;
               break;
            }
         }
         //   sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, gStartingLocationOverride);
         
         int gMainBase2 = kbBaseCreate(cMyID, "Island base", gStartingLocationOverride, 100.0);//createMainBase(gStartingLocationOverride);
         kbBaseSetMain(cMyID, gMainBase2, true);
         kbBaseSetPositionAndDistance(cMyID, kbBaseGetMainID(cMyID), gStartingLocationOverride, 100.0);

         xsEnableRule("buildingMonitorDelayed");

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
      cUnitTypeLogicalTypeGarrisonInShips);
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
   debugSetup("***Delay buildingMonitor and MilitaryManager");
   gCeylonDelay = false;
   xsEnableRule("catchMigrants");
   xsDisableSelf();
}



//==============================================================================
// selectForwardBaseBeachHead
// Based on selectForwardBaseLocation, this function grabs a forward base
// location on the opponent's island
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
// Logic for when we should build a dock
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