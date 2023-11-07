//==============================================================================
/* aiExploration.xs

   This file is intended for any scouting implementation, including both land and
   naval exploration.

*/
//==============================================================================

//==============================================================================
// findBestScoutType
//==============================================================================
int findBestScoutType(void)
{
   // Decide on which unit type to use as scout.
   // If possible, cheap infantry is used.
   int scoutType = -1;
   if (kbUnitCount(cMyID, cUnitTypeGuardian, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeGuardian;
   else if (kbUnitCount(cMyID, cUnitTypeCrossbowman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeCrossbowman;
   else if (kbUnitCount(cMyID, cUnitTypePikeman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypePikeman;
   else if (kbUnitCount(cMyID, cUnitTypeStrelet, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeStrelet;
   else if (kbUnitCount(cMyID, cUnitTypeLongbowman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeLongbowman;
   else if (kbUnitCount(cMyID, cUnitTypeMusketeer, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeMusketeer;
   else if (kbUnitCount(cMyID, cUnitTypexpWarrior, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpWarrior;
   else if (kbUnitCount(cMyID, cUnitTypexpAenna, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpAenna;
   else if (kbUnitCount(cMyID, cUnitTypexpTomahawk, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpTomahawk;
   else if (kbUnitCount(cMyID, cUnitTypexpMacehualtin, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpMacehualtin;
   else if (kbUnitCount(cMyID, cUnitTypexpPumaMan, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpPumaMan;
   else if (kbUnitCount(cMyID, cUnitTypexpWarBow, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpWarBow;
   else if (kbUnitCount(cMyID, cUnitTypexpWarClub, cUnitStateAlive) >= 1)
      scoutType = cUnitTypexpWarClub;
   else if (kbUnitCount(cMyID, cUnitTypeSaloonOutlawPistol, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeSaloonOutlawPistol;
   else if (kbUnitCount(cMyID, cUnitTypeSaloonOutlawRifleman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeSaloonOutlawRifleman;
   else if (kbUnitCount(cMyID, cUnitTypeJanissary, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeJanissary;
   else if (kbUnitCount(cMyID, cUnitTypeypQiangPikeman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypQiangPikeman;
   else if (kbUnitCount(cMyID, cUnitTypeypChuKoNu, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypChuKoNu;
   else if (kbUnitCount(cMyID, cUnitTypeypMonkDisciple, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypMonkDisciple;
   else if (kbUnitCount(cMyID, cUnitTypeypArquebusier, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypArquebusier;
   else if (kbUnitCount(cMyID, cUnitTypeypChangdao, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypChangdao;
   else if (kbUnitCount(cMyID, cUnitTypeypSepoy, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypSepoy;
   else if (kbUnitCount(cMyID, cUnitTypeypNatMercGurkha, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypNatMercGurkha;
   else if (kbUnitCount(cMyID, cUnitTypeypRajput, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypRajput;
   else if (kbUnitCount(cMyID, cUnitTypeypYumi, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypYumi;
   else if (kbUnitCount(cMyID, cUnitTypeypAshigaru, cUnitStateAlive) >= 1)
      scoutType = cUnitTypeypAshigaru;
   else if (kbUnitCount(cMyID, cUnitTypedeChasqui, cUnitStateAlive) >= 1)
      scoutType = cUnitTypedeChasqui;
   else if (kbUnitCount(cMyID, cUnitTypedeJungleBowman, cUnitStateAlive) >= 1)
      scoutType = cUnitTypedeJungleBowman;
   else if (kbUnitCount(cMyID, cUnitTypedeIncaRunner, cUnitStateAlive) >= 1)
      scoutType = cUnitTypedeIncaRunner;
   else
      scoutType = cUnitTypeLogicalTypeScout;
   return (scoutType);
}

//==============================================================================
// islandExploreMonitor
//==============================================================================
rule islandExploreMonitor
inactive
minInterval 30
{
   const int cIslandExploreModeSearch = 0;
   const int cIslandExploreModeStart = 1;
   const int cIslandExploreModeExplore = 2;
   static int islandExploreMode = cIslandExploreModeSearch;
   static int islandExplorePlan = -1;
   static vector islandExplorePosition = cInvalidVector;
   static bool exploreBlackTiles = true;
   static int exploreTimeout = 0;
   int i = 0;
   int j = 0;
   int k = 0;
   int areaGroupID = -1;
   int unitQueryID = -1;
   int numberFound = 0;
   int unitID = -1;
   int numberAreaGroups = 0;
   int numberAreas = 0;
   int time = xsGetTime();

   switch (islandExploreMode)
   {
      case cIslandExploreModeSearch:
      {
         static int areaGroupIDs = -1;
         static int areaIDs = -1;
         int numberBorderAreas = 0;
         int areaID = -1;
         int borderAreaID = -1;
         int baseAreaGroupID = kbAreaGroupGetIDByPosition(kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)));
         int enemyAreaGroupID = -1;
         vector location = cInvalidVector;
   
         if (areaGroupIDs < 0)
         {
            numberAreaGroups = kbAreaGroupGetNumber();
            numberAreas = kbAreaGetNumber();
            areaGroupIDs = xsArrayCreateInt(numberAreaGroups, -1, "Area Group IDs");
            areaIDs = xsArrayCreateInt(numberAreas, -1, "Area IDs");
            for (i = 0; < numberAreaGroups)
            {
               xsArraySetInt(areaGroupIDs, i, i);
            }
         }
   
         bool enemyBuildingFound = false;
         unitQueryID = createSimpleUnitQuery(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateABQ);
         numberFound = kbUnitQueryExecute(unitQueryID);
   
         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(unitQueryID, i);
            if (kbHasPlayerLost(kbUnitGetPlayerID(unitID)) == true)
            {
               continue;
            }
            areaGroupID = kbAreaGroupGetIDByPosition(kbUnitGetPosition(unitID));
            if (areaGroupID == baseAreaGroupID)
            {
               continue;
            }
            enemyAreaGroupID = areaGroupID;
            break;
         }
   
         // If the enemy is not in sight for a long period, search on water.
         static bool isEnemyInSight = true;
         if (gStartOnDifferentIslands == false && isEnemyInSight == true)
            isEnemyInSight = enemyAreaGroupID < 0 &&
                           (kbGetAge() < cAge2 || (time - gLastAttackMissionTime >= gAttackMissionInterval));
   
         if (exploreBlackTiles == true && (gStartOnDifferentIslands == true || isEnemyInSight == false))
         {
            bool allAreaGroupsExplored = true;
            // find land areas near our discovered water areas
            numberAreaGroups = kbAreaGroupGetNumber();
            randomShuffleIntArray(areaGroupIDs, numberAreaGroups);
            for (i = 0; < numberAreaGroups)
            {
               areaGroupID = xsArrayGetInt(areaGroupIDs, i);
               if (areaGroupID == baseAreaGroupID || kbAreaGroupGetType(areaGroupID) != cAreaGroupTypeLand)
               {
                  continue;
               }
               if (getAreaGroupTileTypePercentage(areaGroupID, cTileBlack) < 0.1)
               {
                  continue;
               }
               allAreaGroupsExplored = false;
               // When we spotted an area group with enemy buildings, just explore that particular area group.
               if (enemyAreaGroupID >= 0 && areaGroupID != enemyAreaGroupID && gLowOnResources == false)
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
                  // must be partially seen
                  if (kbAreaGetNumberTiles(areaID) == kbAreaGetNumberBlackTiles(areaID))
                  {
                     continue;
                  }
                  numberBorderAreas = kbAreaGetNumberBorderAreas(areaID);
                  for (k = 0; < numberBorderAreas)
                  {
                     borderAreaID = kbAreaGetBorderAreaID(areaID, k);
                     if (kbAreaGetType(borderAreaID) == cAreaTypeWater)
                     {
                        location = kbAreaGetCenter(areaID);
                        if (getUnitCountByLocation(cUnitTypeAbstractFort, cPlayerRelationEnemyNotGaia,
                            cUnitStateABQ, location, 30.0) == 0)
                        {
                           islandExploreMode = cIslandExploreModeStart;
                           islandExplorePosition = location;
                           debugExploration("Found good island explore location at " + location);
                           return;
                        }
                     }
                  }
               }
            }
            if (allAreaGroupsExplored == true)
            {
               exploreBlackTiles = false;
            }
            return;
         }
   
         // Only try to explore when we can't find anymore enemy buildings.
         if (enemyAreaGroupID >= 0 && gLowOnResources == false)
         {
            return;
         }
   
         numberAreaGroups = kbAreaGroupGetNumber();
         randomShuffleIntArray(areaGroupIDs, numberAreaGroups);
         for (i = 0; < numberAreaGroups)
         {
            areaGroupID = xsArrayGetInt(areaGroupIDs, i);
            if (areaGroupID == baseAreaGroupID || areaGroupID == kbAreaGroupGetIDByPosition(islandExplorePosition) ||
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
                     if (getUnitCountByLocation(cUnitTypeAbstractFort, cPlayerRelationEnemyNotGaia,
                         cUnitStateABQ, location, 30.0) == 0)
                     {
                        islandExploreMode = cIslandExploreModeStart;
                        islandExplorePosition = location;
                        debugExploration("Found good island explore location at " + location);
                        return;
                     }
                  }
               }
            }
         }
         break;
      }
      case cIslandExploreModeStart:
      {
         int scoutUnitID = -1;
         int scoutType = -1;
         int planID = -1;
   
         if (kbUnitCount(cMyID, cUnitTypeLogicalTypeScout, cUnitStateAlive) == 0)
         {
            return;
         }
         
         unitQueryID = createSimpleUnitQuery(cUnitTypeLogicalTypeScout, cMyID, cUnitStateAlive);
         kbUnitQuerySetAreaGroupID(unitQueryID, kbAreaGroupGetIDByPosition(islandExplorePosition));
         numberFound = kbUnitQueryExecute(unitQueryID);
         for (i = 0; < numberFound)
         {
            unitID = kbUnitQueryGetResult(unitQueryID, i);
            planID = kbUnitGetPlanID(unitID);
            if (planID > 0 && aiPlanGetDesiredPriority(planID) >= 75)
            {
               continue;
            }
            scoutUnitID = unitID;
            break;
         }
   
         // if we don't have any units available, take one from the main base
         if (scoutUnitID < 0)
         {
            if (aiPlanGetIDByIndex(cPlanTransport, -1, true, 0) < 0)
            {
               scoutType = findBestScoutType();
               scoutUnitID = getUnit(scoutType, cMyID, cUnitStateAlive);
               if (scoutUnitID >= 0)
               {
                  planID = createTransportPlan(kbBaseGetMilitaryGatherPoint(cMyID, kbBaseGetMainID(cMyID)), islandExplorePosition, 100);
                  if (planID >= 0)
                  {
                     aiPlanAddUnitType(planID, scoutType, 1, 1, 1);
                     if (aiPlanAddUnit(planID, scoutUnitID) == false)
                     {
                        aiPlanDestroy(planID);
                        return;
                     }
                     aiPlanSetNoMoreUnits(planID, true);
                  }
                  gIslandExploreTransportScoutID = scoutUnitID;
                  // Change interval temporarily to avoid idling too long after transporting to the island.
                  xsSetRuleMinIntervalSelf(5);
               }
            }
            return;
         }
   
         islandExplorePlan = aiPlanCreate("Island Explore", cPlanExplore);
         aiPlanSetDesiredPriority(islandExplorePlan, 95);
         aiPlanAddUnitType(islandExplorePlan, cUnitTypeLogicalTypeScout, 1, 1, 1);
         aiPlanAddUnit(islandExplorePlan, scoutUnitID);
         aiPlanSetNoMoreUnits(islandExplorePlan, true);
         aiPlanSetVariableInt(islandExplorePlan, cExplorePlanNumberOfLoops, 0, 0);
         aiPlanSetVariableBool(islandExplorePlan, cExplorePlanDoLoops, 0, false);
         aiPlanSetVariableBool(islandExplorePlan, cExplorePlanOkToGatherNuggets, 0, false);
   
         // Add a waypoint if we are on the enemy player's island.
         location = guessEnemyLocation();
         if (kbAreaGroupGetIDByPosition(location) == kbAreaGroupGetIDByPosition(kbUnitGetPosition(scoutUnitID)))
         {
            aiPlanAddWaypoint(islandExplorePlan, location);
         }
   
         aiPlanSetActive(islandExplorePlan);
         exploreTimeout = time + 180000;
         xsSetRuleMinIntervalSelf(30);
         islandExploreMode = cIslandExploreModeExplore;
         gIslandExploreTransportScoutID = -1;
   
         break;
      }
      case cIslandExploreModeExplore:
      {
         // Our scout died?
         if (aiPlanGetState(islandExplorePlan) == -1)
         {
            islandExploreMode = cIslandExploreModeStart;
            return;
         }
   
         if (exploreBlackTiles == true)
         {
            if (getAreaGroupTileTypePercentage(kbAreaGroupGetIDByPosition(islandExplorePosition), cTileBlack) >= 0.1)
            {
               return;
            }
         }
         else
         {
            if (time < exploreTimeout)
            {
               return;
            }
         }
   
         // Finished exploring, set priority to very low so transport plan can move the scout back.
         aiPlanSetDesiredPriority(islandExplorePlan, 1);
         islandExplorePlan = -1;
         islandExploreMode = cIslandExploreModeSearch;
         break;
      }
   }
}

//==============================================================================
// waterExplore
//==============================================================================
rule waterExplore
inactive
minInterval 15
{
   if (gWaterExplorePlan < 0) // First run.
   {
      vector location = cInvalidVector;
      if (getUnit(gFishingUnit, cMyID, cUnitStateAlive) >= 0)
      {
         location = kbUnitGetPosition(getUnit(gFishingUnit, cMyID, cUnitStateAlive));
      }
      else
      {
         location = gNavyVec;
      }
      gWaterExplorePlan = aiPlanCreate("Water Explore", cPlanExplore);
      aiPlanSetVariableBool(gWaterExplorePlan, cExplorePlanReExploreAreas, 0, false);
      aiPlanSetInitialPosition(gWaterExplorePlan, location);
      // Low, so that transport plans can steal it as needed, but just above fishing plans.
      aiPlanSetDesiredPriority(gWaterExplorePlan, 20); 

      // AssertiveWall: Naval "exploration" turns into patrols with multiple warships
      int age = kbGetAge();
      int minShips = 1;
      int wantedShips = 1;
      int maxShips = 1;
      if (age <= cAge2)
      {
         minShips = 1;
         wantedShips = 2;
         maxShips = 3;
      }
      if (age == cAge3)
      {
         minShips = 1;
         wantedShips = 3;
         maxShips = 4;         
      }
      if (age == cAge4)
      {
         minShips = 2;
         wantedShips = 3;
         maxShips = 5;         
      }
      if (age == cAge5)
      {
         minShips = 3;
         wantedShips = 4;
         maxShips = 6;         
      }
      if (xsGetTime() < 9 * 60 * 1000) // AssertiveWall: explore with fishing boats for first 9 minutes
      {
         aiPlanAddUnitType(gWaterExplorePlan, gFishingUnit, 1, 1, 1);
         aiPlanSetVariableBool(gWaterExplorePlan, cExplorePlanOkToGatherNuggets, 0, false); 
      }
      else
      {
         aiPlanAddUnitType(gWaterExplorePlan, cUnitTypeAbstractWarShip, minShips, wantedShips, maxShips);
         aiPlanSetVariableBool(gWaterExplorePlan, cExplorePlanOkToGatherNuggets, 0, true); 
      }

      aiPlanSetVariableBool(gWaterExplorePlan, cExplorePlanDoLoops, 0, false);
      aiPlanSetActive(gWaterExplorePlan);
   }

   // More aggressive exploring on island maps.
   if (gStartOnDifferentIslands == true)
   {
      vector initialLocation = getStartingLocation();
      if (getAreaGroupNumberTiles(kbAreaGroupGetIDByPosition(initialLocation)) < 2000)
      {
         debugExploration("Adding water explore waypoints for larger islands");
         int numberAreaGroups = kbAreaGroupGetNumber();
         int numberAreas = 0;
         int areaID = -1;
         int numberBorderAreas = 0;
         int borderAreaID = -1;
         static int waypoints = -1;
         int numberWaypoints = 0;

         if (waypoints < 0) // First run.
         {
            xsArrayCreateVector(100, cInvalidVector, "Water explore waypoints");
         }

         for (areaGroupID = 0; < numberAreaGroups)
         {
            if (kbAreaGroupGetType(areaGroupID) != cAreaGroupTypeLand || getAreaGroupNumberTiles(areaGroupID) < 2000)
            {
               continue;
            }
            numberAreas = kbAreaGroupGetNumberAreas(areaGroupID);
            for (i = 0; < numberAreas)
            {
               areaID = kbAreaGroupGetAreaID(areaGroupID, i);
               numberBorderAreas = kbAreaGetNumberBorderAreas(areaID);
               for (j = 0; < numberBorderAreas)
               {
                  borderAreaID = kbAreaGetBorderAreaID(areaID, j);
                  if (kbAreaGetType(borderAreaID) == cAreaTypeWater)
                  {
                     location = kbAreaGetCenter(areaID);
                     xsArraySetVector(waypoints, numberWaypoints, location);
                     numberWaypoints = numberWaypoints + 1;
                     if (numberWaypoints >= xsArrayGetSize(waypoints))
                     {
                        xsArrayResizeVector(waypoints, numberWaypoints * 2);
                     }
                     break;
                  }
               }
            }
         }

         debugExploration("Water explore number waypoints: " + numberWaypoints);
         for (i = 0; < numberWaypoints)
         {
            aiPlanAddWaypoint(gWaterExplorePlan, xsArrayGetVector(waypoints, i));
         }
      }
      // Only use fishing ships for exploration if we have no war ships and no combat going on.
      if ((aiPlanGetNumberUnits(gWaterExplorePlan, cUnitTypeAbstractWarShip) == 0) &&
          (gNavyAttackPlan < 0) && 
          (aiPlanGetActualPriority(gNavyDefendPlan) < 20))
      {
         aiPlanAddUnitType(gWaterExplorePlan, gFishingUnit, 1, 1, 1);
      }
      else
      {
         aiPlanAddUnitType(gWaterExplorePlan, gFishingUnit, 0, 0, 0);
      }
      aiPlanAddWaypoint(gWaterExplorePlan, guessEnemyLocation());

   }
}

//==============================================================================
// enableTreasureGatheringAgain
//==============================================================================
rule enableTreasureGatheringAgain
inactive
minInterval 30
{
   debugExploration("Enabling treasure gathering again");
   aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanOkToGatherNuggets, 0, true); // Enable treasure gathering again.
   xsDisableSelf();
}

//==============================================================================
// exploreScoutShoreline
// Used to get LOS of the shoreline so we can build a Dock.
// We send our scout to 2 points of where 2 land areas meet the water area in which our closest fish is.
//==============================================================================
void exploreScoutShoreline(int explorePlanID = -1)
{
   // Disable treasure gathering for the time being so we actually scout.
   aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanOkToGatherNuggets, 0, false); 
   debugExploration("Disabling treasure gathering for exploreScoutShoreline");

   vector mainBasePosition = getStartingLocation();
   vector closestFishPosition = getClosestGaiaUnitPosition(cUnitTypeAbstractFish, mainBasePosition);
   int closestFishAreaID = kbAreaGetIDByPosition(closestFishPosition);
   if (kbAreaGetNumberTiles(closestFishAreaID) ==
       (kbAreaGetNumberVisibleTiles(closestFishAreaID) + kbAreaGetNumberFogTiles(closestFishAreaID)))
   {
      debugExploration("This map has the sea/shorelines revealed so we don't need to scout the shorelines");
      return;
   }
   vector closestFishAreaCenter = kbAreaGetCenter(closestFishAreaID);
   debugExploration("closestFishPosition: " + closestFishPosition + ", closestFishAreaID:" + closestFishAreaID +
      ", closestFishAreaCenter: " + closestFishAreaCenter);

   int neighbouringLandAreaID1 = -1;
   vector neighbouringLandAreaCenter1 = cInvalidVector;
   int neighbouringLandAreaID2 = -1;
   vector neighbouringLandAreaCenter2 = cInvalidVector;
   int closestWaterAreaID = -1;

   float distanceToMainBase = 0.0;
   float distanceArea1 = 9999.0;
   float distanceArea2 = 9999.0;
   float distanceAreaWater = 9999.0;

   // Loop through all the areas that border our fishing area to check for suitable areas to scout (land areas).
   int numberBorderAreas = kbAreaGetNumberBorderAreas(closestFishAreaID);
   int neighbouringAreaID = -1;
   for (i = 0; < numberBorderAreas)
   {
      neighbouringAreaID = kbAreaGetBorderAreaID(closestFishAreaID, i);
      debugExploration("ID we're checking: " + neighbouringAreaID);
      debugExploration("Type of ID: " + kbAreaGetType(neighbouringAreaID));

      // -1 Here stands for "PassableLand", there is no good constant available for this atm.
      if (kbAreaGetType(neighbouringAreaID) == -1) 
      {
         distanceToMainBase = distance(mainBasePosition, kbAreaGetCenter(neighbouringAreaID));
         // Always add points if we're on island maps since we just need a Dock there no matter what.
         if ((distanceToMainBase > 150.0) && (gStartOnDifferentIslands ==  false)) 
         {
            continue; // Don't add points that are too far away to prevent the AI from sending their Scouts all the way across
                      // the map.
         }
         debugExploration("Suitable Area found that lies " + distanceToMainBase + " away from our Main Base");
         if (distanceToMainBase < distanceArea1)
         {
            // Copy what we had here to "2".
            distanceArea2 = distanceArea1;
            neighbouringLandAreaID2 = neighbouringLandAreaID1;
            neighbouringLandAreaCenter2 = neighbouringLandAreaCenter1;

            // Populate our new closest point.
            distanceArea1 = distanceToMainBase;
            neighbouringLandAreaID1 = neighbouringAreaID;
            neighbouringLandAreaCenter1 = kbAreaGetCenter(neighbouringAreaID);
         }
         else if (distanceToMainBase < distanceArea2)
         {
            distanceArea2 = distanceToMainBase;
            neighbouringLandAreaID2 = neighbouringAreaID;
            neighbouringLandAreaCenter2 = kbAreaGetCenter(neighbouringAreaID);
         }
      }
      // Create a failsafe consisting of the closest water area we find, this will be used if we don't find the 2 waypoints we
      // want with the initial search.
      if (kbAreaGetType(neighbouringAreaID) ==
          2) // 2 Here stands for "Water", there is no good constant available for this atm.
      {
         distanceToMainBase = distance(mainBasePosition, kbAreaGetCenter(neighbouringAreaID));
         if (distanceToMainBase < distanceAreaWater)
         {
            closestWaterAreaID = neighbouringAreaID;
            distanceAreaWater = distanceToMainBase;
         }
      }
   }
   // Check if we're missing a point, if we are we need to use our failsafe to try and get a valid point again.
   if ((neighbouringLandAreaID1 == -1) || (neighbouringLandAreaID2 == -1))
   {
      debugExploration("Failsafe triggered, we're missing 1 or 2 points so search again using the closest water area we found");
      debugExploration("closestWaterAreaID:" + closestWaterAreaID);
      // Loop through all the areas that border our closest water area to check for suitable areas to scout (land areas).
      numberBorderAreas = kbAreaGetNumberBorderAreas(closestWaterAreaID);
      for (i = 0; < numberBorderAreas)
      {
         neighbouringAreaID = kbAreaGetBorderAreaID(closestWaterAreaID, i);
         debugExploration("ID we're checking: " + neighbouringAreaID);
         debugExploration("Type of ID: " + kbAreaGetType(neighbouringAreaID));

         // -1 Here stands for "PassableLand", there is no good constant available for this atm, and prevent double assignment.
         if ((kbAreaGetType(neighbouringAreaID) == -1) && (neighbouringAreaID != neighbouringLandAreaID1) &&
             (neighbouringAreaID != neighbouringLandAreaID2))
         {
            distanceToMainBase = distance(mainBasePosition, kbAreaGetCenter(neighbouringAreaID));
            // Always add points if we're on island maps since we just need a Dock there no matter what.
            if ((distanceToMainBase > 150.0) && (gStartOnDifferentIslands == false)) 
            {
               continue; // Don't add points that are too far away to prevent the AI from sending their Scouts all the way
                         // across the map.
            }
            debugExploration("Suitable Area found that lies " + distanceToMainBase + " away from our Main Base");
            if (distanceToMainBase < distanceArea1)
            {
               // Copy what we had here to "2".
               distanceArea2 = distanceArea1;
               neighbouringLandAreaID2 = neighbouringLandAreaID1;
               neighbouringLandAreaCenter2 = neighbouringLandAreaCenter1;

               // Populate our new closest point.
               distanceArea1 = distanceToMainBase;
               neighbouringLandAreaID1 = neighbouringAreaID;
               neighbouringLandAreaCenter1 = kbAreaGetCenter(neighbouringAreaID);
            }
            else if (distanceToMainBase < distanceArea2)
            {
               distanceArea2 = distanceToMainBase;
               neighbouringLandAreaID2 = neighbouringAreaID;
               neighbouringLandAreaCenter2 = kbAreaGetCenter(neighbouringAreaID);
            }
         }
      }
   }

   if ((neighbouringLandAreaID1 == -1) && (neighbouringLandAreaID2 == -1))
   {
      debugExploration("We found 0 land areas next to our fishing area (or they were too far away), quiting");
      enableTreasureGatheringAgain();
      return;
   }
   debugExploration("neighbouringLandAreaID1: " + neighbouringLandAreaID1 + ", neighbouringLandAreaCenter1: "
      + neighbouringLandAreaCenter1);
   debugExploration("neighbouringLandAreaID2: " + neighbouringLandAreaID2 + ", neighbouringLandAreaCenter2: "
      + neighbouringLandAreaCenter2);

   vector neighbouringLandAreaScoutPoint1 = neighbouringLandAreaCenter1;
   vector canPathTestVector1 = cInvalidVector;

   vector directionVector1 = xsVectorNormalize(closestFishPosition - neighbouringLandAreaCenter1) * 5.0;
   int fishLandDistance1 = distance(closestFishPosition, neighbouringLandAreaCenter1);
   int amountOfSteps1 = fishLandDistance1 / 5;

   // We take "steps" from the center of the land area towards the center of the fishing area until we approximately reach the
   // shoreline.
   for (i = 1; < amountOfSteps1)
   {
      canPathTestVector1 = neighbouringLandAreaCenter1 + (directionVector1 * i);
      debugExploration("i: " + i + ", canPathTestVector1: " + canPathTestVector1 +
         " with type: " + kbAreaGetType(kbAreaGetIDByPosition(canPathTestVector1)));
      if (kbAreaGetType(kbAreaGetIDByPosition(canPathTestVector1)) == -1)
      {
         neighbouringLandAreaScoutPoint1 = canPathTestVector1;
      }
      else
      {
         break;
      }
   }
   aiPlanAddWaypoint(explorePlanID, neighbouringLandAreaScoutPoint1); // Add the point to the scout plan.

   // Point 2 can still be invalid at this point so check for it.
   if (neighbouringLandAreaCenter2 != cInvalidVector)
   {
      vector neighbouringLandAreaScoutPoint2 = neighbouringLandAreaCenter2;
      vector canPathTestVector2 = cInvalidVector;

      vector directionVector2 = xsVectorNormalize(closestFishPosition - neighbouringLandAreaCenter2) * 5.0;
      int fishLandDistance2 = distance(closestFishPosition, neighbouringLandAreaCenter2);
      int amountOfSteps2 = fishLandDistance2 / 5;

      for (i = 1; < amountOfSteps2)
      {
         canPathTestVector2 = neighbouringLandAreaCenter2 + (directionVector2 * i);
         debugExploration("i: " + i + ", canPathTestVector2: " + canPathTestVector2 +
            " with type: " + kbAreaGetType(kbAreaGetIDByPosition(canPathTestVector2)));
         if (kbAreaGetType(kbAreaGetIDByPosition(canPathTestVector2)) == -1)
         {
            neighbouringLandAreaScoutPoint2 = canPathTestVector2;
         }
         else
         {
            break;
         }
      }
      aiPlanAddWaypoint(explorePlanID, neighbouringLandAreaScoutPoint2); // Add the point to the scout plan.
   }

   xsEnableRule("enableTreasureGatheringAgain");
}

//==============================================================================
// findEnemyBase
//==============================================================================
void findEnemyBase(void)
{
   if (gStartOnDifferentIslands == true)
   {
      return (); // TODO...make a water version, look for enemy home island?
   }

   // Create an explore plan to go there.
   vector myBaseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)); // Main base location...need to find reflection.
   vector targetLocation = guessEnemyLocation();
   // TargetLocation is now a mirror image of my base.
   debugExploration("My base is at " + myBaseLocation + ", enemy base should be near " + targetLocation);
   int exploreID = aiPlanCreate("Probe Enemy Base", cPlanExplore);
   if (exploreID >= 0)
   {
      aiPlanAddUnitType(exploreID, findBestScoutType(), 1, 1, 1);
      aiPlanAddWaypoint(exploreID, targetLocation);
      aiPlanSetVariableBool(exploreID, cExplorePlanDoLoops, 0, false);
      aiPlanSetVariableBool(exploreID, cExplorePlanQuitWhenPointIsVisible, 0, true);
      aiPlanSetVariableBool(exploreID, cExplorePlanAvoidingAttackedAreas, 0, false);
      aiPlanSetVariableInt(exploreID, cExplorePlanNumberOfLoops, 0, -1);
      aiPlanSetRequiresAllNeedUnits(exploreID, true);
      aiPlanSetVariableVector(exploreID, cExplorePlanQuitWhenPointIsVisiblePt, 0, targetLocation);
      aiPlanSetDesiredPriority(exploreID, 100);
      aiPlanSetActive(exploreID);
   }
}

//==============================================================================
/* exploreMonitor

   If it's off, make sure the explore plan is killed.
   If it's on, make sure the explore plan is active.

   Initially, the explore plan gets an explorer plus 5/15/20 military units,
   so that it can effectively gather nuggets. We switch out of this mode 3 minutes
   after reaching age 2, unless the explore plan is in nugget gathering mode.
*/
//==============================================================================
rule exploreMonitor
inactive
minInterval 10
{
   const int cExploreModeStart = 0;   // Initial setting, when first starting out
   const int cExploreModeNugget = 1;  // Explore and gather nuggets.  Heavy staffing, OK to recruit more units.
   const int cExploreModeStaff = 2;   // Restaffing the plan, active for 10 seconds to let the plan grab 1 more unit.
   const int cExploreModeExplore = 3; // Normal...explore until this unit dies, check again in 5 minutes.
   
   int time = xsGetTime();
   static int exploreMode = cExploreModeStart;
   static int age2Time = -1;
   static int nextStaffTime = -1; // Prevent the explore plan from constantly sucking in units.
   static bool hasExploredShoreline = false;
   int() createExplorerControlPlan = []() -> int {
      int controlPlan = aiPlanCreate("Explorer control plan", cPlanCombat);
      int mainBaseID = kbBaseGetMainID(cMyID);
      switch (cMyCiv)
      {
         case cCivDEInca:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypedeIncaWarChief, 1, 1, 1);
            break;
         }
         case cCivXPAztec:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypexpAztecWarchief, 1, 1, 1);
            break;
         }
         case cCivXPIroquois:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypexpIroquoisWarChief, 1, 1, 1);
            break;
         }
         case cCivXPSioux:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypexpLakotaWarchief, 1, 1, 1);
            break;
         }
         case cCivChinese:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypeypMonkChinese, 1, 1, 1);
            break;
         }
         case cCivIndians:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypeypMonkIndian, 1, 1, 1);
            aiPlanAddUnitType(controlPlan, cUnitTypeypMonkIndian2, 1, 1, 1);
            break;
         }
         case cCivJapanese:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypeypMonkJapanese, 1, 1, 1);
            aiPlanAddUnitType(controlPlan, cUnitTypeypMonkJapanese2, 1, 1, 1);
            break;
         }
         case cCivDEInca:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypedeIncaWarChief, 1, 1, 1);
            break;
         }
         case cCivDEEthiopians:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypedePrince, 1, 1, 1);
            break;
         }
         case cCivDEHausa:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypedeEmir, 1, 1, 1);
            break;
         }
         default:
         {
            aiPlanAddUnitType(controlPlan, cUnitTypeExplorer, 1, 1, 1);
            break;
         }
      }
      aiPlanSetVariableInt(controlPlan, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
      aiPlanSetVariableInt(controlPlan, cCombatPlanTargetMode, 0, cCombatPlanTargetModePoint);
      aiPlanSetVariableVector(controlPlan, cCombatPlanTargetPoint, 0, kbBaseGetMilitaryGatherPoint(cMyID, mainBaseID));
      aiPlanSetVariableFloat(controlPlan, cCombatPlanTargetEngageRange, 0, 20.0); // Tight
      aiPlanSetVariableFloat(controlPlan, cCombatPlanGatherDistance, 0, 20.0);
      aiPlanSetInitialPosition(controlPlan, kbBaseGetLocation(cMyID, mainBaseID));
      aiPlanSetVariableInt(controlPlan, cCombatPlanRefreshFrequency, 0, 1000);
      if (civIsNative() == false)
      {
         aiPlanSetDesiredPriority(controlPlan, 90); // Quite high, don't suck him into routine attack plans, etc.
      }
      else
      {
         aiPlanSetDesiredPriority(controlPlan, 40); // Above default, we do want war chiefs in attacks for the aura.
      }
      if (cDifficultyCurrent >= cDifficultyHard)
      {
         aiPlanSetVariableInt(controlPlan, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
      }
      aiPlanSetActive(controlPlan);
      return (controlPlan);
   };

   if ((age2Time < 0) && (kbGetAge() >= cAge2))
   {
      age2Time = time;
   }
   
   // Check for a failed plan
   if ((gLandExplorePlan >= 0) && (aiPlanGetState(gLandExplorePlan) < 0))
   {
      // Somehow, the plan has died.  Reset it to start up again if allowed.
      gLandExplorePlan = -1;
      exploreMode = cExploreModeStart;
      nextStaffTime = -1;
   }

   if (aiPlanGetActive(gLandExplorePlan) == false)
   {
      if (gLandExplorePlan >= 0)
      {
         aiPlanSetActive(gLandExplorePlan); // Reactivate if we were shut off.
      }
   }
         
   switch (exploreMode)
   {
      case cExploreModeStart:
      {
         if (aiPlanGetState(gLandExplorePlan) < 0)
         { // Need to create it.
            gLandExplorePlan = aiPlanCreate("Land Explore", cPlanExplore);
            aiPlanSetDesiredPriority(gLandExplorePlan, 75);
            if (cvOkToGatherNuggets == true)
            {
               switch (cMyCiv)
               {
                  case cCivDEInca:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypedeIncaWarChief, 1, 1, 1);
                     break;
                  }
                  case cCivXPAztec:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpAztecWarchief, 1, 1, 1);
                     break;
                  }
                  case cCivXPIroquois:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpIroquoisWarChief, 1, 1, 1);
                     break;
                  }
                  case cCivXPSioux:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpLakotaWarchief, 1, 1, 1);
                     break;
                  }
                  case cCivChinese:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkChinese, 1, 1, 1);
                     break;
                  }
                  case cCivIndians:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian, 1, 1, 1);
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian2, 1, 1, 1);
                     break;
                  }
                  case cCivJapanese:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese, 1, 1, 1);
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese2, 1, 1, 1);
                     break;
                  }
                  default:
                  {
                     aiPlanAddUnitType(gLandExplorePlan, cUnitTypeExplorer, 1, 1, 1);
                     break;
                  }
               }
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeLogicalTypeScout, 1, 6, 10);
               aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanOkToGatherNuggets, 0, true);
               exploreMode = cExploreModeNugget;
            }
            else
            {
               if (cMyCiv == cCivDutch) // Dutch will only use envoys (mainly handled in envoyMonitor rule)
               {
                  aiPlanAddUnitType(gLandExplorePlan, cUnitTypeEnvoy, 1, 1, 1);
               }
               else
               {
                  aiPlanAddUnitType(gLandExplorePlan, findBestScoutType(), 1, 1, 1);
               }
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeExplorer, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypedeIncaWarChief, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpAztecWarchief, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpIroquoisWarChief, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpLakotaWarchief, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkChinese, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian2, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese, 0, 0, 0);
               aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese2, 0, 0, 0);
               aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanOkToGatherNuggets, 0, false);
               exploreMode = cExploreModeStaff;
               nextStaffTime = time + 120000; // Two minutes from now, let it get another soldier if it loses this one.
               if (gExplorerControlPlan < 0)
               {
                  gExplorerControlPlan = createExplorerControlPlan();
               }
            }
            aiPlanSetBaseID(gLandExplorePlan, kbBaseGetMainID(cMyID));
            aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanDoLoops, 0, true);
            aiPlanSetVariableInt(gLandExplorePlan, cExplorePlanNumberOfLoops, 0, 1);
            if (gGoodFishingMap == true)
            {
               if (hasExploredShoreline == false)
               {
                  exploreScoutShoreline(gLandExplorePlan);
                  hasExploredShoreline = true;
               }
            }
            if (btRushBoom > 0.0)
            {
               aiPlanAddWaypoint(gLandExplorePlan, guessEnemyLocation());
            }
            aiPlanSetActive(gLandExplorePlan);
         }
         else
         {
            exploreMode = cExploreModeNugget;
         }
         break;
      }
      case cExploreModeNugget:
      {
         // Check to see if we're out of time, and switch to single-unit exploring if we are.
         if (age2Time >= 0)
         {
            // Our explorer is unconscious or we've been in age 2 for a long time already.
            // Switch to a normal explore plan, create explorer control plan.
            if ((aiGetFallenExplorerID() >= 0) ||
                ((age2Time >= 0) &&
                 ((aiPlanGetState(gLandExplorePlan) != cPlanStateClaimNugget) ||
                 ((time - age2Time) > 300000)))) 
            {                 
               if (gExplorerControlPlan < 0)
               {
                  gExplorerControlPlan = createExplorerControlPlan();
               }

               // Destroy and re-create plan for single scout.
               aiPlanDestroy(gLandExplorePlan);
               gLandExplorePlan = aiPlanCreate("Land Explore", cPlanExplore);
               aiPlanSetDesiredPriority(gLandExplorePlan, 75);
               if (cMyCiv == cCivDutch) // Dutch will only use envoys (mainly handled in envoyMonitor rule)
               {
                  aiPlanAddUnitType(gLandExplorePlan, cUnitTypeEnvoy, 1, 1, 1);
               }
               else
               {
                  aiPlanAddUnitType(gLandExplorePlan, findBestScoutType(), 1, 1, 1);
               }
               aiPlanSetNoMoreUnits(gLandExplorePlan, false);
               aiPlanSetVariableInt(gLandExplorePlan, cExplorePlanNumberOfLoops, 0, 0);
               aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanDoLoops, 0, false);
               exploreMode = cExploreModeStaff;
               nextStaffTime = time + 120000; // Two minutes from now, let it get another soldier.
               debugExploration("Allowing the explore plan to grab a unit.");
            }
         }
         if (cvOkToGatherNuggets == false)
         {
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeExplorer, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypedeIncaWarChief, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpAztecWarchief, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpIroquoisWarChief, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypexpLakotaWarchief, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkChinese, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkIndian2, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, cUnitTypeypMonkJapanese2, 0, 0, 0);
            aiPlanAddUnitType(gLandExplorePlan, findBestScoutType(), 1, 1, 1);
            aiPlanSetNoMoreUnits(gLandExplorePlan, false);
            aiPlanSetVariableInt(gLandExplorePlan, cExplorePlanNumberOfLoops, 0, 0);
            aiPlanSetVariableBool(gLandExplorePlan, cExplorePlanDoLoops, 0, false);
            exploreMode = cExploreModeStaff;
            nextStaffTime = time + 120000; // Two minutes from now, let it get another soldier.
            debugExploration("Allowing the explore plan to grab a unit.");
         }
         break;
      }
      case cExploreModeStaff:
      {
         // We've been staffing for 10 seconds, set no more units to true.
         aiPlanSetNoMoreUnits(gLandExplorePlan, true);
         exploreMode = cExploreModeExplore;
         debugExploration("Setting the explore plan to 'noMoreUnits'");
         break;
      }
      case cExploreModeExplore:
      { // See if we're allowed to add another unit.
         if (time > nextStaffTime)
         {
            aiPlanSetNoMoreUnits(gLandExplorePlan, false); // Let it grab a unit.
            debugExploration("Setting the explore plan to grab a unit if needed.");
            nextStaffTime = time + 120000;
            exploreMode = cExploreModeStaff;
         }
         break;
      }
   }
}

//==============================================================================
// balloonMonitor
//==============================================================================
rule balloonMonitor
inactive
minInterval 10
{
   // Create plan only when a Balloon is available.
   if (kbUnitCount(cMyID, cUnitTypexpAdvancedBalloon) == 0)
   {
      return;
   }

   // Create explore plan.
   int balloonExplore = aiPlanCreate("Balloon Explore", cPlanExplore);
   aiPlanSetDesiredPriority(balloonExplore, 99);
   aiPlanAddUnitType(balloonExplore, cUnitTypexpAdvancedBalloon, 1, 1, 1);
   aiPlanSetBaseID(balloonExplore, kbBaseGetMainID(cMyID));
   aiPlanSetVariableBool(balloonExplore, cExplorePlanDoLoops, 0, false);
   aiPlanSetActive(balloonExplore);

   xsDisableSelf();
}

//==============================================================================
// envoyMonitor
//==============================================================================
rule envoyMonitor
inactive
minInterval 10
{
   static int envoyPlan = -1;

   if (envoyPlan < 0)
   {
      envoyPlan = createSimpleMaintainPlan(cUnitTypeEnvoy, 1, false, kbBaseGetMainID(cMyID));
   }

   // Only create plan only when envoy available.
   if (kbUnitCount(cMyID, cUnitTypeEnvoy) == 0)
   {
      return;
   }

   // Create explore plan.
   int envoyExplore = aiPlanCreate("Envoy Explore", cPlanExplore);
   aiPlanSetDesiredPriority(envoyExplore, 99);
   aiPlanAddUnitType(envoyExplore, cUnitTypeEnvoy, 1, 1, 1);
   aiPlanSetBaseID(envoyExplore, kbBaseGetMainID(cMyID));
   aiPlanSetVariableBool(envoyExplore, cExplorePlanDoLoops, 0, false);
   aiPlanSetActive(envoyExplore);

   xsDisableSelf();
}

//==============================================================================
// nativeScoutMonitor
//==============================================================================
rule nativeScoutMonitor
inactive
minInterval 10
{
   // Create plan only when native scout available.
   if (kbUnitCount(cMyID, cUnitTypeNativeScout) == 0)
   {
      return;
   }

   // Create explore plan.
   int nativeExplore = aiPlanCreate("Native Explore", cPlanExplore);
   aiPlanSetDesiredPriority(nativeExplore, 99);
   aiPlanAddUnitType(nativeExplore, cUnitTypeNativeScout, 1, 1, 1);
   aiPlanSetBaseID(nativeExplore, kbBaseGetMainID(cMyID));
   aiPlanSetVariableBool(nativeExplore, cExplorePlanDoLoops, 0, false);
   aiPlanSetActive(nativeExplore);

   xsDisableSelf();
}

//==============================================================================
// mongolScoutMonitor
//==============================================================================
rule mongolScoutMonitor
inactive
minInterval 10
{
   // Create plan only when mongol scout available.
   if (kbUnitCount(cMyID, cUnitTypeypMongolScout) == 0)
   {
      return;
   }

   // Create explore plan.
   int mongolExplore = aiPlanCreate("Mongol Explore", cPlanExplore);
   aiPlanSetDesiredPriority(mongolExplore, 99);
   aiPlanAddUnitType(mongolExplore, cUnitTypeypMongolScout, 1, 1, 1);
   aiPlanSetBaseID(mongolExplore, kbBaseGetMainID(cMyID));
   aiPlanSetVariableBool(mongolExplore, cExplorePlanDoLoops, 0, false);
   aiPlanSetActive(mongolExplore);

   xsDisableSelf();
}

//==============================================================================
// chasquiMonitor
//==============================================================================
rule chasquiMonitor
inactive
minInterval 10
{
   static int chasquiPlan = -1;

   // Create maintain plan.
   int limit = kbGetBuildLimit(cMyID, cUnitTypedeChasqui);
   if (chasquiPlan < 0)
   {
      chasquiPlan = createSimpleMaintainPlan(cUnitTypedeChasqui, 1, false, kbBaseGetMainID(cMyID));
   }
   if (kbGetAge() >= cAge2)
   {
      aiPlanSetVariableInt(chasquiPlan, cTrainPlanNumberToMaintain, 0, limit);
   }

   // Create plan only when Chasqui available.
   if (kbUnitCount(cMyID, cUnitTypedeChasqui) == 0)
   {
      return;
   }

   // Create explore plan.
   static int chasquiExplore = -1;
   if (aiPlanGetState(chasquiExplore) < 0)
   {
      chasquiExplore = aiPlanCreate("Chasqui Explore", cPlanExplore);
      aiPlanSetDesiredPriority(chasquiExplore, 99);
      aiPlanAddUnitType(chasquiExplore, cUnitTypedeChasqui, 1, 1, 1);
      aiPlanSetBaseID(chasquiExplore, kbBaseGetMainID(cMyID));
      aiPlanSetVariableBool(chasquiExplore, cExplorePlanDoLoops, 0, false);
      aiPlanSetActive(chasquiExplore);
   }
}