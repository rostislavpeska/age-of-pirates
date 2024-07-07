// HAWAII 1.0
// 06/2024

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

  // initialize map type variables 
  string nativeCiv1 = "bhakti";
  string nativeCiv2 = "zen";
  string nativeString1 = "native bhakti village ceylon ";
  string nativeString2 = "native zen temple ceylon 0";
  string baseMix = "california_snowground4";
  string paintMix = "ceylon_sand_a";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ZP Hawaii Coast";
  string startTreeType = "TreeAmazon";
  string forestType = "z79 hawaii";
  string cliffType = "caribbean";
  string mapType1 = "hawaii";
  string mapType2 = "grass";
  string huntable1 = "zpFeralPig";
  string huntable2 = "ypWildElephant";
  string fish1 = "ypFishTuna";
  string fish2 = "FishMahi";
  string whale1 = "HumpbackWhale";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";

  
	// Define Natives
  int subCiv0=-1;
  int subCiv1=-1;

  if (rmAllocateSubCivs(3) == true)
  {
  subCiv0=rmGetCivID("natpirates");
    rmEchoInfo("subCiv0 is pirates "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "natpirates");

    subCiv1=rmGetCivID("maorinatives");
    rmEchoInfo("subCiv1 is maorinatives "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "maorinatives");

  }

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=20000;
  if(cNumberNonGaiaPlayers <= 5)
    playerTiles = 26000;
  if (cNumberNonGaiaPlayers <= 3)
		playerTiles = 30000;
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("water");
	rmSetLightingSet("age304_caribbean");
  //rmSetOceanReveal(true);

	// Initialize map.
	rmTerrainInitialize(baseTerrain);

	// Misc variables for use later
	int numTries = -1;
  int weird = -1;
  int TeamNum = cNumberTeams;
  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("classPatch");
	rmDefineClass("importantItem");
	int classCanyon=rmDefineClass("canyon");
  int classHighMountains=rmDefineClass("high mountains");

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 10.0);
  int avoidTPLong=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets far", "SocketTradeRoute", 20.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
  int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion of island", .35, .55, .65, .35);
  int northConstraint = rmCreateBoxConstraint("huntable constraint for north side of island", .25, .55, .8, .85);
  int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 12.0);
  int avoidTCLong=rmCreateTypeDistanceConstraint("stay away from TC by far", "TownCenter", 30.0);

	// Island Constraints  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 35.0);
  int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
  
	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
	int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "zpJadeMine", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "zpPineapleBush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 40.0);
  int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 30.0);
  int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketMaori", 30.0);
  int avoidJesuitLong=rmCreateTypeDistanceConstraint("avoid socket jesuit long", "zpSocketMaori", 65.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
  int avoidMesa=rmCreateClassDistanceConstraint("avoid random mesas on south central portion of migration island", classCanyon, 10.0);
  int avoidHighMountains=rmCreateClassDistanceConstraint("stuff avoids high mountains", classHighMountains, 3.0);
  int avoidHighMountainsFar=rmCreateClassDistanceConstraint("stuff avoids high mountains far", classHighMountains, 12.0);

	// Constraint to avoid water.
	int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 4.0);
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

  // things
	int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
  int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
  int avoidKOTHshort=rmCreateTypeDistanceConstraint("stay away from Kings Hill short", "ypKingsHill", 8.0);
  
  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 15.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
  int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
  int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
	int flagVsWokou1 = rmCreateTypeDistanceConstraint("flag avoid wokou 1", "zpWokouWaterSpawnFlag1", 40);
  int flagVsWokou2 = rmCreateTypeDistanceConstraint("flag avoid wokou  2", "zpWokouWaterSpawnFlag2", 40);
  int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

   //Trade Route Contstraints
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	// Make one big island.  
	int centralIslandID=rmCreateArea("central island");
	rmSetAreaSize(centralIslandID, 0.01, 0.01);
	rmSetAreaCoherence(centralIslandID, 0.65);
	rmSetAreaBaseHeight(centralIslandID, 2.0);
	rmSetAreaSmoothDistance(centralIslandID, 20);
	rmSetAreaMix(centralIslandID, baseMix);
	rmAddAreaConstraint(centralIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(centralIslandID, false);
	rmSetAreaElevationType(centralIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(centralIslandID, 2.0);
	rmSetAreaElevationMinFrequency(centralIslandID, 0.09);
	rmSetAreaElevationOctaves(centralIslandID, 3);
	rmSetAreaElevationPersistence(centralIslandID, 0.2);
	rmSetAreaElevationNoiseBias(centralIslandID, 1);
  rmSetAreaLocation(centralIslandID, .5, .5);
  
	rmBuildArea(centralIslandID);
	    	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);


  // ----------- Trade Routes ---------------------------------------------------------------------------------------

   int tradeRouteID = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

   // ---------- Place Players ---------------------------------------------------------------------------------------

  if (TeamNum > 2 || abs(teamZeroCount - teamOneCount)> 0)
    weird = 1;
  else
    weird = 0;
  
  if (weird ==1) {
    rmSetPlacementSection(0.045, 0.705);
    rmPlacePlayersCircular(0.35, 0.35, 0);
  }

  else {
    float teamStartLoc = rmRandFloat(0.0, 1.0);

    if (teamStartLoc > 0.5)
    {
      rmSetPlacementTeam(0);
      rmSetPlacementSection(0.25, 0.5);
      rmPlacePlayersCircular(0.35, 0.35, 0);
      rmSetPlacementTeam(1);
      rmSetPlacementSection(0.75, 0.0); 
      rmPlacePlayersCircular(0.35, 0.35, 0);
    }
    else
    {
      rmSetPlacementTeam(0);
      rmSetPlacementSection(0.75, 0.0); 
      rmPlacePlayersCircular(0.35, 0.35, 0);
      rmSetPlacementTeam(1);
      rmSetPlacementSection(0.25, 0.5);
      rmPlacePlayersCircular(0.35, 0.35, 0);
    }
  }


	float playerFraction=rmAreaTilesToFraction(3000 - cNumberNonGaiaPlayers*100);
	for(i=1; <cNumberPlayers)
	{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaSize(playerID, rmAreaTilesToFraction(2400), rmAreaTilesToFraction(2400));
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	  rmSetAreaCoherence(playerID, 0.5);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, baseMix);
      rmAddAreaTerrainLayer(playerID, "caribbean\ground3_crb", 0, 6);
	// rmSetAreaTerrainType(playerID, playerTerrain);
    rmAddAreaConstraint(playerID, islandConstraint);
    rmAddAreaConstraint(playerID, islandEdgeConstraint);
    rmAddAreaConstraint(playerID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerID, cElevTurbulence);
    rmSetAreaElevationVariation(playerID, 4.0);
    rmSetAreaElevationMinFrequency(playerID, 0.09);
    rmSetAreaElevationOctaves(playerID, 3);
    rmSetAreaElevationPersistence(playerID, 0.2);
    rmSetAreaElevationNoiseBias(playerID, 1);	 
    rmEchoInfo("Team area"+i);

    int connectionID1 = rmCreateConnection ("connection player "+i);
    rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
    rmSetConnectionWidth(connectionID1, 30, 8);
    rmSetConnectionCoherence(connectionID1, 0.3);
    rmSetConnectionWarnFailure(connectionID1, false);
    rmAddConnectionArea(connectionID1, centralIslandID);
    rmAddConnectionArea(connectionID1, playerID);
    rmSetConnectionBaseHeight(connectionID1, 1.5);
    rmBuildConnection(connectionID1);

	}

  // Create Bonus Islands
  int bonusIsland1=rmCreateArea("bonus island 1");
  rmSetAreaCoherence(bonusIsland1, 0.8);
  rmSetAreaBaseHeight(bonusIsland1, 2.0);
  rmSetAreaSmoothDistance(bonusIsland1, 20);
  rmSetAreaMix(bonusIsland1, baseMix);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground3_crb", 0, 6);
  rmAddAreaToClass(bonusIsland1, classIsland);
  rmSetAreaObeyWorldCircleConstraint(bonusIsland1, false);
  rmSetAreaElevationType(bonusIsland1, cElevTurbulence);
  rmSetAreaElevationVariation(bonusIsland1, 4.0);
  rmSetAreaElevationMinFrequency(bonusIsland1, 0.09);
  rmSetAreaElevationOctaves(bonusIsland1, 3);
  rmSetAreaElevationPersistence(bonusIsland1, 0.2);
  rmSetAreaElevationNoiseBias(bonusIsland1, 1);
  rmAddAreaConstraint(bonusIsland1, islandConstraint);
  rmAddAreaConstraint(bonusIsland1, islandAvoidTradeRoute);

  if (weird==1){
    rmSetAreaSize(bonusIsland1, rmAreaTilesToFraction(2000), rmAreaTilesToFraction(2000));
    rmSetAreaLocation(bonusIsland1, .3, .7);  
    rmBuildArea(bonusIsland1);
  }
  else{
    rmSetAreaSize(bonusIsland1, rmAreaTilesToFraction(800), rmAreaTilesToFraction(800));
    rmSetAreaLocation(bonusIsland1, .3, .3);  
    rmBuildArea(bonusIsland1);

    int bonusIsland2=rmCreateArea("bonus island 2");
    rmSetAreaSize(bonusIsland2, rmAreaTilesToFraction(800), rmAreaTilesToFraction(800));
    rmSetAreaCoherence(bonusIsland2, 0.8);
    rmSetAreaBaseHeight(bonusIsland2, 2.0);
    rmSetAreaSmoothDistance(bonusIsland2, 20);
    rmSetAreaMix(bonusIsland2, baseMix);
      rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground3_crb", 0, 6);
    rmAddAreaToClass(bonusIsland2, classIsland);
    rmSetAreaObeyWorldCircleConstraint(bonusIsland2, false);
    rmSetAreaElevationType(bonusIsland2, cElevTurbulence);
    rmSetAreaElevationVariation(bonusIsland2, 4.0);
    rmSetAreaElevationMinFrequency(bonusIsland2, 0.09);
    rmSetAreaElevationOctaves(bonusIsland2, 3);
    rmSetAreaElevationPersistence(bonusIsland2, 0.2);
    rmSetAreaElevationNoiseBias(bonusIsland2, 1);
    rmAddAreaConstraint(bonusIsland2, islandConstraint);
    rmAddAreaConstraint(bonusIsland2, islandAvoidTradeRoute);
    rmSetAreaLocation(bonusIsland2, .7, .7);  
    rmBuildArea(bonusIsland2);
  }

  int connectionID2 = rmCreateConnection ("connection bonus 1");
  rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
  rmSetConnectionWidth(connectionID2, 30, 8);
  rmSetConnectionCoherence(connectionID2, 0.3);
  rmSetConnectionWarnFailure(connectionID2, false);
  rmAddConnectionArea(connectionID2, centralIslandID);
  rmAddConnectionArea(connectionID2, bonusIsland1);
  rmSetConnectionBaseHeight(connectionID2, 1.5);
  rmBuildConnection(connectionID2);

  if (weird==0){
    int connectionID3 = rmCreateConnection ("connection bonus 2");
    rmSetConnectionType(connectionID3, cConnectAreas, false, 1);
    rmSetConnectionWidth(connectionID3, 30, 8);
    rmSetConnectionCoherence(connectionID3, 0.3);
    rmSetConnectionWarnFailure(connectionID3, false);
    rmAddConnectionArea(connectionID3, centralIslandID);
    rmAddConnectionArea(connectionID3, bonusIsland2);
    rmSetConnectionBaseHeight(connectionID3, 1.5);
    rmBuildConnection(connectionID3);
  }


	// Build the areas. 
	rmBuildAllAreas();

  // Make one big island.  
	int bigIslandID=rmCreateArea("migration island");
  if (cNumberNonGaiaPlayers <= 3)
	  rmSetAreaSize(bigIslandID, rmAreaTilesToFraction(10000), rmAreaTilesToFraction(10000));
  else if (cNumberNonGaiaPlayers >= 6)
	  rmSetAreaSize(bigIslandID, rmAreaTilesToFraction(22000), rmAreaTilesToFraction(22000));
  else
    rmSetAreaSize(bigIslandID, rmAreaTilesToFraction(14000), rmAreaTilesToFraction(14000));
	rmSetAreaCoherence(bigIslandID, 0.55);
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, baseMix);
    rmAddAreaTerrainLayer(bigIslandID, "caribbean\ground3_crb", 0, 6);
	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
  rmSetAreaLocation(bigIslandID, .5, .5);
  
	rmBuildArea(bigIslandID);

  int nativeIslandConstraint=rmCreateAreaConstraint("native Island", bigIslandID);

  // NATIVES
  
  // Place Controllers
      int controllerID1 = rmCreateObjectDef("Controler 1");
      rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID1, 0.0);
	   rmSetObjectDefMaxDistance(controllerID1, 30.0);
      rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID1, ferryOnShore); 


      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID2, 0.0);
	   rmSetObjectDefMaxDistance(controllerID2, 30.0);
      rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID2, ferryOnShore); 


      if(weird == 0){
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3, 0.3);
         rmPlaceObjectDefAtLoc(controllerID2, 0, 0.75, 0.75);
      }

      else {
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3+rmXTilesToFraction(20), 0.7+rmXTilesToFraction(20));
         rmPlaceObjectDefAtLoc(controllerID2, 0, 0.3-rmXTilesToFraction(20), 0.7-rmXTilesToFraction(20));
      }


      vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

      // Pirate Village 1

      int piratesVillageID = -1;
      int piratesVillageType = rmRandInt(1,2);
      piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");
      rmSetGroupingMinDistance(piratesVillageID, 0);
      rmSetGroupingMaxDistance(piratesVillageID, 20);
      rmAddGroupingConstraint(piratesVillageID, ferryOnShore);

  
      rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

      int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
      rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

      rmClearClosestPointConstraints();

      int pirateportID1 = -1;
      pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
      
      rmClearClosestPointConstraints();

      // Pirate Village 2

      int piratesVillageID2 = -1;
      int piratesVillage2Type = 3-piratesVillageType;
      piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06");
      rmSetGroupingMinDistance(piratesVillageID2, 0);
      rmSetGroupingMaxDistance(piratesVillageID2, 20);
      rmAddGroupingConstraint(piratesVillageID2, ferryOnShore);

      rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);
    
      int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
      rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

      int pirateportID2 = -1;
      pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();
	
  //==========KotH==============

  // check for KOTH game mode
  if(rmGetIsKOTH()) {   
    if (weird==0)
      float xLoc = 0.5+rmXTilesToFraction(16);
    else
      xLoc = 0.5-rmXTilesToFraction(16);
    float yLoc = 0.5+rmXTilesToFraction(16);
    float walk = 0.00;
    
    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
    rmEchoInfo("XLOC = "+xLoc);
    rmEchoInfo("XLOC = "+yLoc);
  }

  //==========Volcano==============

  int basecliffID = rmCreateArea("base cliff");
  if (cNumberNonGaiaPlayers <= 3 || rmGetIsKOTH() == true)
    rmSetAreaSize(basecliffID, rmAreaTilesToFraction(2000), rmAreaTilesToFraction(2000));
  else
    rmSetAreaSize(basecliffID, rmAreaTilesToFraction(2500), rmAreaTilesToFraction(2500));
  rmSetAreaWarnFailure(basecliffID, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID, false);		
  rmAddAreaToClass(basecliffID, rmClassID("classPlateau"));
  rmSetAreaCoherence(basecliffID, .6);
  rmSetAreaHeightBlend(basecliffID, 0);
  rmSetAreaCliffType(basecliffID, "ZP Hawaii Medium");
  rmSetAreaCliffEdge(basecliffID, 4, 0.16, 0.0, 0.0, 2); 
  rmSetAreaCliffPainting(basecliffID, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID, 3, 0.1, 0.5);
  rmAddAreaConstraint(basecliffID, avoidKOTHshort);
  rmSetAreaElevationVariation(basecliffID, 4);
  rmSetAreaLocation(basecliffID, 0.5, 0.5);
  rmBuildArea(basecliffID);

  int volcanoMountainTerrain=rmCreateArea("volcano terrain"); 
  rmSetAreaSize(volcanoMountainTerrain, 0.035, 0.035);
  rmSetAreaLocation(volcanoMountainTerrain, 0.5, 0.5);
  rmSetAreaCoherence(volcanoMountainTerrain, 0.6);
  rmSetAreaMix(volcanoMountainTerrain, baseMix);
  rmSetAreaObeyWorldCircleConstraint(volcanoMountainTerrain, false);
  rmBuildArea(volcanoMountainTerrain);

  int volcanoMountainTerrain2=rmCreateArea("volcano terrain 2"); 
  rmSetAreaSize(volcanoMountainTerrain2, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
  rmSetAreaLocation(volcanoMountainTerrain2, 0.5, 0.5);
  rmSetAreaCoherence(volcanoMountainTerrain2, 1.0);
  rmSetAreaMix(volcanoMountainTerrain2, "rockies_dirt_snow");
  rmAddAreaConstraint(volcanoMountainTerrain2, avoidKOTHshort);
  rmSetAreaObeyWorldCircleConstraint(volcanoMountainTerrain2, false);
  rmBuildArea(volcanoMountainTerrain2);

  int basecliffID2 = rmCreateArea("base cliff2");
  rmSetAreaSize(basecliffID2, rmAreaTilesToFraction(1600.0), rmAreaTilesToFraction(1600.0));
  rmSetAreaWarnFailure(basecliffID2, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID2, false);		
  rmAddAreaToClass(basecliffID2, rmClassID("classPlateau"));
  rmSetAreaElevationVariation(basecliffID2, 4);
  rmSetAreaCoherence(basecliffID2, .7);
  rmSetAreaHeightBlend(basecliffID2, 0);
  rmSetAreaCliffType(basecliffID2, "ZP Hawaii Medium");
  rmSetAreaTerrainType(basecliffID2, "lava\volcano_grass");
  rmSetAreaCliffEdge(basecliffID2, 4, 0.18, 0.0, 0.0, 2); 
  rmSetAreaCliffPainting(basecliffID2, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID2, 4, 0.1, 0.5);
  rmSetAreaLocation(basecliffID2, 0.5, 0.5);
  rmAddAreaConstraint(basecliffID2, avoidKOTHshort);
  //rmSetAreaReveal(basecliffID2, 1);
  rmBuildArea(basecliffID2);

  int basecliffID3 = rmCreateArea("base cliff3");
  rmSetAreaSize(basecliffID3, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
  rmSetAreaWarnFailure(basecliffID3, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID3, false);		
  rmAddAreaToClass(basecliffID3, rmClassID("classPlateau"));
  rmSetAreaElevationVariation(basecliffID3, 5);
  rmSetAreaCoherence(basecliffID3, .72);
  rmSetAreaHeightBlend(basecliffID3, 0);
  rmSetAreaCliffType(basecliffID3, "ZP Hawaii High 2");
  rmSetAreaTerrainType(basecliffID3, "araucania\groundshore5_ara");
  rmSetAreaCliffEdge(basecliffID3, 4, 0.21, 0.0, 0.0, 2); 
  rmSetAreaCliffPainting(basecliffID3, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID3, 5, 0.1, 0.5);
  rmSetAreaLocation(basecliffID3, 0.5, 0.5);
  rmAddAreaToClass(basecliffID3, classHighMountains);
  rmAddAreaConstraint(basecliffID3, avoidKOTHshort);
  rmBuildArea(basecliffID3);

  int basecliffID4 = rmCreateArea("base cliff4");
  rmSetAreaSize(basecliffID4, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
  rmSetAreaWarnFailure(basecliffID4, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID4, false);		
  rmAddAreaToClass(basecliffID4, rmClassID("classPlateau"));
  rmSetAreaElevationVariation(basecliffID4, 5);
  rmSetAreaCoherence(basecliffID4, .75);
  rmSetAreaHeightBlend(basecliffID4, 0);
  rmSetAreaCliffType(basecliffID4, "ZP Hawaii High");
  rmSetAreaTerrainType(basecliffID4, "araucania\groundshore5_ara");
  rmSetAreaCliffEdge(basecliffID4, 4, 0.21, 0.0, 0.0, 2); 
  rmSetAreaCliffPainting(basecliffID4, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID4, 6, 0.1, 0.5);
  rmSetAreaLocation(basecliffID4, 0.5, 0.5);
  rmAddAreaConstraint(basecliffID4, avoidKOTHshort);
  rmBuildArea(basecliffID4);

  int basecliffID5 = rmCreateArea("base cliff5");
  rmSetAreaSize(basecliffID5, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
  rmSetAreaWarnFailure(basecliffID5, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID5, false);		
  rmAddAreaToClass(basecliffID5, rmClassID("classPlateau"));
  rmSetAreaElevationVariation(basecliffID5, 6);
  rmSetAreaCoherence(basecliffID5, .8);
  rmSetAreaHeightBlend(basecliffID5, 0);
  rmSetAreaCliffType(basecliffID5, "ZP Hawaii High");
  rmSetAreaTerrainType(basecliffID5, "araucania\groundshore5_ara");
  rmSetAreaCliffEdge(basecliffID5, 4, 0.21, 0.0, 0.0, 2);  
  rmSetAreaCliffPainting(basecliffID5, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID5, 7, 0.1, 0.5);
  rmSetAreaLocation(basecliffID5, 0.5, 0.5);
  rmAddAreaConstraint(basecliffID5, avoidKOTHshort);
  rmBuildArea(basecliffID5);

  int basecliffID6 = rmCreateArea("base cliff6");
  rmSetAreaSize(basecliffID6, rmAreaTilesToFraction(170.0), rmAreaTilesToFraction(170.0));
  rmSetAreaWarnFailure(basecliffID6, false);
  rmSetAreaObeyWorldCircleConstraint(basecliffID6, false);		
  rmAddAreaToClass(basecliffID6, rmClassID("classPlateau"));
  rmSetAreaElevationVariation(basecliffID6, 3);
  rmSetAreaCoherence(basecliffID6, .9);
  rmSetAreaHeightBlend(basecliffID6, 0);
  rmSetAreaCliffType(basecliffID6, "ZP Hawaii High");
  rmSetAreaTerrainType(basecliffID6, "araucania\groundshore5_ara");
  rmSetAreaCliffEdge(basecliffID6, 2, 0.4, 0.0, 0.0, 2);  
  rmSetAreaCliffPainting(basecliffID6, true, true, true, 1.5, true);
  rmSetAreaCliffHeight(basecliffID6, 4, 0.1, 0.5);
  rmSetAreaLocation(basecliffID6, 0.5, 0.5);
  rmAddAreaConstraint(basecliffID6, avoidKOTHshort);
  rmBuildArea(basecliffID6);

  int fujiPeak = rmCreateArea("fujiPeak");
  rmSetAreaSize(fujiPeak, rmAreaTilesToFraction(120.0), rmAreaTilesToFraction(120.0));
  rmSetAreaLocation(fujiPeak, 0.5, 0.5);
  rmSetAreaTerrainType(fujiPeak, "lava\crater");
  rmSetAreaBaseHeight(fujiPeak, 26.0);
  rmAddAreaConstraint(fujiPeak, avoidKOTHshort);
  rmSetAreaCoherence(fujiPeak, .9);
  rmBuildArea(fujiPeak);  

  int fujiPeakTerrain = rmCreateArea("fujiPeakTerrain");
  rmSetAreaSize(fujiPeakTerrain, rmAreaTilesToFraction(200.0), rmAreaTilesToFraction(200.0));
  rmSetAreaLocation(fujiPeakTerrain, 0.5, 0.5);
  rmSetAreaTerrainType(fujiPeakTerrain, "lava\crater");
  rmSetAreaCoherence(fujiPeakTerrain, 0.9);
  rmBuildArea(fujiPeakTerrain);
  
  int fujiDip = rmCreateArea("fujiDip");
  rmSetAreaSize(fujiDip, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
  rmSetAreaLocation(fujiDip, 0.5, 0.5);
  rmSetAreaCliffType(fujiDip, "ZP Hawaii Crater");
  rmSetAreaCliffPainting(fujiDip, false, true, true, 1.5, false);
  rmSetAreaCliffHeight(fujiDip, -5, 0.1, 0.5);
  rmSetAreaCliffEdge(fujiDip, 1, 1.0, 0.0, 1.0, 0);
  rmSetAreaTerrainType(fujiDip, "lava\lavaflow");
  rmSetAreaCoherence(fujiDip, 1.0);
  rmBuildArea(fujiDip);

  int fujiDipTerrain1 = rmCreateArea("fujiDipTerrain1");
  rmSetAreaSize(fujiDipTerrain1, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
  rmSetAreaLocation(fujiDipTerrain1, 0.5, 0.5);
  rmSetAreaTerrainType(fujiDipTerrain1, "lava\crater_passable");
  rmSetAreaCoherence(fujiDipTerrain1, 1.0);
  rmBuildArea(fujiDipTerrain1);  

  int fujiDipTerrain = rmCreateArea("fujiDipTerrain");
  rmSetAreaSize(fujiDipTerrain, rmAreaTilesToFraction(25.0), rmAreaTilesToFraction(25.0));
  rmSetAreaLocation(fujiDipTerrain, 0.5, 0.5);
  rmSetAreaTerrainType(fujiDipTerrain, "lava\lavaflow");
  rmSetAreaCoherence(fujiDipTerrain, 1.0);
  rmBuildArea(fujiDipTerrain);  

  // ------------------ Volcano Crater ---------------------------------------------------------------

  int volcanoCraterID = -1;
  volcanoCraterID = rmCreateGrouping("crater", "volcano_crater");
  rmPlaceGroupingAtLoc(volcanoCraterID, 1, 0.5, 0.5, 1);

  

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
  


      // Placing Player Trade Route Sockets

      int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
      rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
      rmSetObjectDefAllowOverlap(socketID, true);
      rmSetObjectDefMinDistance(socketID, 5.0);
      rmSetObjectDefMaxDistance(socketID, 30.0);

      vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

      if(cNumberNonGaiaPlayers <= 2){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 3){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.94);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 4){

        if(weird == 0){
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
        else {
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.60);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.93);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
      }

      if(cNumberNonGaiaPlayers == 5){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.40);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.60);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.93);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 6){
        if(weird == 0){
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
        else {
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.05);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.20);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.45);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.60);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.93);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
      }

      if(cNumberNonGaiaPlayers == 7){
        socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.02);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.38);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.48);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.60);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.93);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 8){
        if(weird == 0){
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.21);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.29);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.71);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.79);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
        else {
          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.02);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.20);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.39);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.49);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.6);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

          socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.93);
          rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
        }
      }


      // Maori Natives

if(cNumberNonGaiaPlayers ==3){}

else {
  int caribs1VillageID = -1;
  int caribs1VillageType = rmRandInt(1,5);
  caribs1VillageID = rmCreateGrouping("caribs1 city", "maori_hawaii_0"+caribs1VillageType);
  rmAddGroupingConstraint(caribs1VillageID, avoidImpassableLand);
  //rmAddGroupingConstraint(caribs1VillageID, avoidHighMountainsFar);
  //rmAddGroupingConstraint(caribs1VillageID, avoidJesuit);
  rmSetGroupingMinDistance(caribs1VillageID, 0);
  rmSetGroupingMaxDistance(caribs1VillageID, 40);
  rmAddObjectDefConstraint(caribs1VillageID, avoidWater8);
  rmPlaceGroupingAtLoc(caribs1VillageID, 0, 0.38, 0.62, 1);
  //rmPlaceGroupingInArea(caribs1VillageID, 0, bigIslandID, 1);

  int caribs2VillageID = -1;
  int caribs2VillageType = rmRandInt(1,5);
  caribs2VillageID = rmCreateGrouping("caribs2 city", "maori_hawaii_0"+caribs2VillageType);
  rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
  //rmAddGroupingConstraint(caribs2VillageID, avoidHighMountainsFar);
  //rmAddGroupingConstraint(caribs2VillageID, avoidJesuit);
  rmSetGroupingMinDistance(caribs2VillageID, 0);
  rmSetGroupingMaxDistance(caribs2VillageID, 40);
  rmAddObjectDefConstraint(caribs2VillageID, avoidWater8);
  rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.62, 0.38, 1);
  //rmPlaceGroupingInArea(caribs2VillageID, 0, bigIslandID, 1);
}

if(cNumberNonGaiaPlayers >=3) {
  int caribs3VillageID = -1;
  int caribs3VillageType = rmRandInt(1,5);
  caribs3VillageID = rmCreateGrouping("caribs3 city", "maori_hawaii_0"+caribs3VillageType);
  rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
  //rmAddGroupingConstraint(caribs3VillageID, avoidTPLong);
  //rmAddGroupingConstraint(caribs3VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(caribs3VillageID, avoidJesuitLong);
  rmAddGroupingConstraint(caribs3VillageID, avoidPirates);
  rmAddObjectDefConstraint(caribs3VillageID, avoidWater8);
  rmSetGroupingMinDistance(caribs3VillageID, 0);
  if(cNumberNonGaiaPlayers >=6) {
    rmSetGroupingMaxDistance(caribs3VillageID, 70);
    rmPlaceGroupingAtLoc(caribs3VillageID, 0, 0.62, 0.62, 2);
  }
  else {
    rmSetGroupingMaxDistance(caribs3VillageID, 40);
    rmPlaceGroupingAtLoc(caribs3VillageID, 0, 0.62, 0.62, 1);
  }
  //rmPlaceGroupingInArea(caribs3VillageID, 0, bigIslandID, 1);

  int caribs4VillageID = -1;
  int caribs4VillageType = rmRandInt(1,5);
  caribs4VillageID = rmCreateGrouping("caribs4 city", "maori_hawaii_0"+caribs4VillageType);
  rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
  //rmAddGroupingConstraint(caribs4VillageID, avoidTPLong);
  //rmAddGroupingConstraint(caribs4VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(caribs4VillageID, avoidJesuitLong);
  rmAddGroupingConstraint(caribs4VillageID, avoidPirates);
  rmAddObjectDefConstraint(caribs4VillageID, avoidWater8);
  rmSetGroupingMinDistance(caribs4VillageID, 0);
  if(cNumberNonGaiaPlayers >=6) {
    rmSetGroupingMaxDistance(caribs4VillageID, 70);
    rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.38, 0.38, 2);
  }
  else {
    rmSetGroupingMaxDistance(caribs4VillageID, 40);
    rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.38, 0.38, 1);
  }
  //rmPlaceGroupingInArea(caribs4VillageID, 0, bigIslandID, 1);
}


	// text
	rmSetStatusText("",0.60);

	//Place player TCs and starting Gold Mines. 

	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);

	//Prepare to place TCs
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 40.0);
  rmSetObjectDefMaxDistance(TCID, avoidPirates);
	rmAddObjectDefConstraint(TCID, avoidWokou);
  rmAddObjectDefConstraint(TCID, avoidJesuit);
  rmAddObjectDefConstraint(TCID, avoidWater8);

	//Prepare to place Explorers, Explorer's dog, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "zpJadeMine", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
  rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting food
	int playerFoodID=rmCreateObjectDef("player food");
  rmAddObjectDefItem(playerFoodID, huntable1, 8, 4.0);
  rmSetObjectDefMinDistance(playerFoodID, 10);
	rmSetObjectDefMaxDistance(playerFoodID, 15);	
	rmAddObjectDefConstraint(playerFoodID, avoidAll);
  rmAddObjectDefConstraint(playerFoodID, avoidImpassableLand);
  rmSetObjectDefCreateHerd(playerFoodID, true);
  
  //Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "zpPineapleBush", 6, 4.0);
  rmSetObjectDefMinDistance(playerBerriesID, 15);
  rmSetObjectDefMaxDistance(playerBerriesID, 20);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
  rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 12.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 17.0);
  
  // Starting area nuggets
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 10.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
  rmAddObjectDefConstraint(playerNuggetID, avoidAll);
  rmAddObjectDefConstraint(playerNuggetID, shortAvoidImpassableLand);

	int waterSpawnPointID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************
  
  rmClearClosestPointConstraints();


  // Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.4, 0.4);

	for(i=1; <cNumberPlayers) {
    
    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
		rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Place starting nugget
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    
		// Place water spawn points for the players along with a canoe
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
		rmAddClosestPointConstraint(flagVsFlag);
    rmAddClosestPointConstraint(flagVsPirates1);
    rmAddClosestPointConstraint(flagVsPirates2);
    rmAddClosestPointConstraint(flagVsWokou1);
    rmAddClosestPointConstraint(flagVsWokou2);
		rmAddClosestPointConstraint(flagLand);
    rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
		rmClearClosestPointConstraints();
   }

   

	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
  int forestTreeID = 0;
  numTries=10*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
    rmSetAreaForestType(forest, forestType);
    rmSetAreaForestDensity(forest, 0.6);
    rmSetAreaForestClumpiness(forest, 0.1);
    rmSetAreaForestUnderbrush(forest, 0.6);
    rmSetAreaMinBlobs(forest, 1);
    rmSetAreaMaxBlobs(forest, 5);
    rmSetAreaMinBlobDistance(forest, 16.0);
    rmSetAreaMaxBlobDistance(forest, 40.0);
    rmSetAreaCoherence(forest, 0.4);
    rmSetAreaSmoothDistance(forest, 10);
    rmAddAreaToClass(forest, rmClassID("classForest")); 
    rmAddAreaConstraint(forest, forestConstraint);
    rmAddAreaConstraint(forest, avoidAll);
    rmAddAreaConstraint(forest, avoidPirates);
    rmAddAreaConstraint(forest, avoidWokou);
    rmAddAreaConstraint(forest, avoidKOTH);
    rmAddAreaConstraint(forest, avoidJesuit);
    rmAddAreaConstraint(forest, avoidTP);
    rmAddAreaConstraint(forest, avoidTCMedium);
    rmAddAreaConstraint(forest, nativeIslandConstraint);
    rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
    rmAddAreaConstraint(forest, avoidHighMountains); 
    if(rmBuildArea(forest)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount++;
      
      if(failCount==5)
        break;
    }
    
    else
      failCount=0; 
  } 


    
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);


  int jadeID = rmCreateObjectDef("random jade");
	rmAddObjectDefItem(jadeID, "zpJadeMine", 1, 0);
	rmSetObjectDefMinDistance(jadeID, 0.0);
	rmSetObjectDefMaxDistance(jadeID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(jadeID, avoidAll);
  rmAddObjectDefConstraint(jadeID, avoidWater8);
	rmAddObjectDefConstraint(jadeID, avoidGold);
  rmAddObjectDefConstraint(jadeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(jadeID, avoidImportantItem);
  rmAddAreaConstraint(jadeID, avoidJesuit);
  rmAddObjectDefConstraint(jadeID, avoidCoin);
  rmAddObjectDefConstraint(jadeID, avoidTP);
  rmAddObjectDefConstraint(jadeID, avoidHighMountains);
	rmPlaceObjectDefInArea(jadeID, 0, bigIslandID, 4*cNumberNonGaiaPlayers);
   
	// Scattered berries all over island
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "zpPineapleBush", rmRandInt(5,8), 4.0); 
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(berriesID, avoidTP);   
	rmAddObjectDefConstraint(berriesID, avoidAll);
  rmAddObjectDefConstraint(berriesID, avoidImportantItem);
  rmAddObjectDefConstraint(berriesID, avoidHighMountains);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, shortAvoidImpassableLand);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers/2);

	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidHighMountains);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
	rmPlaceObjectDefInArea(foodID1, 0, bigIslandID, 3*cNumberNonGaiaPlayers+1);  


	// Define and place Nuggets
    
	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 3);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
  rmAddObjectDefConstraint(nugget1, avoidImportantItem);
	rmAddObjectDefConstraint(nugget1, avoidTP);
	rmAddObjectDefConstraint(nugget1, avoidAll);
  rmAddObjectDefConstraint(nugget1, avoidJesuit);
  rmAddObjectDefConstraint(nugget1, avoidHighMountains);
	rmAddObjectDefConstraint(nugget1, avoidWater8);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	for (i=0; <cNumberPlayers)
	{
		rmPlaceObjectDefInArea(nugget1, 0, rmAreaID("player "+i), 2);
	}

	// Water nuggets
  int nuggetCount = 2;

  int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2b, avoidLand);
  rmAddObjectDefConstraint(nugget2b, avoidNuggetWater2);
  rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount/2);
  
  int nugget2= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nugget2, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2, avoidLand);
  rmAddObjectDefConstraint(nugget2, avoidNuggetWater);
  rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nugget2, false, nuggetCount);
  
  // really tough nuggets confined to south central cliffy area
  int nugget3= rmCreateObjectDef("nugget hardest"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidHardNugget);
  rmAddObjectDefConstraint(nugget3, avoidHighMountains);
  rmAddObjectDefConstraint(nugget3, mesaConstraint);
  rmAddObjectDefConstraint(nugget3, avoidJesuit);
  rmAddObjectDefConstraint(nugget3, avoidImportantItem);
	rmPlaceObjectDefInArea(nugget3, 0, bigIslandID, cNumberNonGaiaPlayers*1.5);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4); 

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

	int fish2ID=rmCreateObjectDef("fish 2");
	rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, avoidFish2);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}

  int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "treeAmazon", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);

    // Starter shipment triggers

    // ------Triggers--------//

int tch0=1671; // tech operator

int eruptionLenght = -1;
int eqAreaDamage = 40;
int islandSize = 110;
int gapMin = 700;
int gapMax = 1200;
int eruptionBreak1 = rmRandInt(450,800);
int eruptionBreak2 = rmRandInt(gapMin,gapMax);
int eruptionBreak3 = rmRandInt(gapMin,gapMax);
int eruptionBreak4 = rmRandInt(gapMin,gapMax);
int eruptionBreak5 = rmRandInt(gapMin,gapMax);

if (cNumberNonGaiaPlayers <=3) {
  eruptionLenght = 80;
  islandSize = 110;
  eqAreaDamage = 30;
}

else if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==5) {
  eruptionLenght = 100;
  islandSize = 145;
  eqAreaDamage = 30;
}

else {
  eruptionLenght = 120;
  islandSize = 180;
  eqAreaDamage = 24;
}

// Volcano
rmCreateTrigger("Volcano_Start1");
rmCreateTrigger("Volcano_Start2");
rmCreateTrigger("Volcano_Start3");
rmCreateTrigger("Volcano_Start4");
rmCreateTrigger("Volcano_Start5");

rmCreateTrigger("Volcano_Short");
rmCreateTrigger("Volcano_Short2");
rmCreateTrigger("Volcano_Medium");
rmCreateTrigger("Volcano_Long");
rmCreateTrigger("Volcano_UltraLong");
rmCreateTrigger("Volcano_Stop");
rmCreateTrigger("Volcano_Damage");

rmCreateTrigger("Volcano_Music1");
rmCreateTrigger("Volcano_Music2");
rmCreateTrigger("Volcano_MusicEnd");

rmSwitchToTrigger(rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\BubbleChum.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",4.0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Music2"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",50);
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\CamelsStrawsAndBacks.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",2.0);
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_MusicEnd"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Music Play");
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Damage"));
for(i=1; <= cNumberNonGaiaPlayers) {
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject","75");
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Unit");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",eqAreaDamage);
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject","75");
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Building");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",20*eqAreaDamage);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start1"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.7);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start2"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start2"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.7);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start3"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start3"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak3);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.7);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start4"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start4"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak4);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.7);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start5"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start5"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.7);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Short"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort"); 
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Medium"));
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",2.0);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Medium"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeMedium");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",2.0);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
if (cNumberNonGaiaPlayers <=3){
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
}
else{
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Long"));
}
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

if (cNumberNonGaiaPlayers >=4){
  rmSwitchToTrigger(rmTriggerID("Volcano_Long"));
  rmAddTriggerCondition("Timer");
  rmSetTriggerConditionParamInt("Param1",20);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",0);
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeLong");
  rmSetTriggerEffectParamInt("Status",2);
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  if (cNumberNonGaiaPlayers <=5){
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
  }
  else{
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_UltraLong"));
  }
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
  rmSetTriggerPriority(4);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(true);
  rmSetTriggerLoop(false);
}

if (cNumberNonGaiaPlayers >=6){
  rmSwitchToTrigger(rmTriggerID("Volcano_UltraLong"));
  rmAddTriggerCondition("Timer");
  rmSetTriggerConditionParamInt("Param1",20);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",0);
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeUltraLong");
  rmSetTriggerEffectParamInt("Status",2);
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
  rmSetTriggerPriority(4);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(true);
  rmSetTriggerLoop(false);
}

rmSwitchToTrigger(rmTriggerID("Volcano_Short2"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",1.5);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoPassive"); // Desctivates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","age304_caribbean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",1.0);
rmSetTriggerEffectParamFloat("Strength",0.1);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("FadeOutMusic");
rmSetTriggerEffectParamFloat("Duration",4.0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_MusicEnd"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
rmSetTriggerEffectParamInt("Status",2);
}
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Italian Vilager Balance

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Italian Vilager Balance"+k);
rmAddTriggerCondition("ZP Player Civilization");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("Civilization","DEItalians");
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(2);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);
}

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Italian Gondola Balance"+k);
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechDEHCGondolas");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpItalianGondolaBallance");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(2);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);
}

// Speed Always Wins Returner

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Cheat Returner"+k);
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",10);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease");
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(2);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);
	}

// Consulate - Tradingpost politician switcher

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate Consulate Japan"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","Japanese");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnJapanese"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate Consulate China"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","Chinese");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnChinese"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate Consulate India"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","Indians");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnIndian"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}


for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Tortuga"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPirates"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(true);
}

// Specific for human players

for(k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Human Check Plr"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "true");
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpIsPirateMap"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japan"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_China"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_India"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Privateer training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainPrivateer1ON Plr"+k);
rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
rmCreateTrigger("TrainPrivateer1TIME Plr"+k);

   
   rmCreateTrigger("TrainPrivateer2ON Plr"+k);
   rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
   rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2OFF_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2TIME_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2OFF_Plr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2TIME_Plr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamFloat("Param1",200);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
   rmSetTriggerEffectParamInt("Status",0);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer1OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Unique ship Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("UniqueShip1TIMEPlr"+k);

rmCreateTrigger("BlackbTrain1ONPlr"+k);
rmCreateTrigger("BlackbTrain1OFFPlr"+k);

rmCreateTrigger("GraceTrain1ONPlr"+k);
rmCreateTrigger("GraceTrain1OFFPlr"+k);

rmCreateTrigger("CaesarTrain1ONPlr"+k);
rmCreateTrigger("CaesarTrain1OFFPlr"+k);


   rmCreateTrigger("UniqueShip2TIMEPlr"+k);

   rmCreateTrigger("BlackbTrain2ONPlr"+k);
   rmCreateTrigger("BlackbTrain2OFFPlr"+k);

   rmCreateTrigger("GraceTrain2ONPlr"+k);
   rmCreateTrigger("GraceTrain2OFFPlr"+k);

   rmCreateTrigger("CaesarTrain2ONPlr"+k);
   rmCreateTrigger("CaesarTrain2OFFPlr"+k);
   
   rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamFloat("Param1",200);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("BlackbTrain2OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain2OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("CaesarTrain2OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


   // Build limit reducer
   rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamFloat("Param1",200);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Blackbeard
   rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","5");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne1"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("BlackbTrain1OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Grace
   rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","5");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl1"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain1OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Caesar
   rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","5");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune1"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1OFFPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("CaesarTrain1OFFPlr"+k));
   rmAddTriggerCondition("Timer ms");
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

}

// Pirate trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Pirates1on Player"+k);
rmCreateTrigger("Pirates1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Pirates2on Player"+k);
   rmCreateTrigger("Pirates2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","41");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","41");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","41");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

}

// AI Pirate Captains

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Pirate Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int pirateCaptain=-1;
pirateCaptain = rmRandInt(1,3);

if (pirateCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (pirateCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesGrace"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (pirateCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackCaesar"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}



// Testing

/*for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Test Plr"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "true");
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",537);
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",2804);
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",527);
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}*/


    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);
}