// Corsairs of Mediterranean 1.0

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
  string baseMix = "africa desert grass";
  string paintMix = "africa desert rock";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ZP Anno 1404";
  string startTreeType = "ypTreeCeylon";
  string forestType = "z42 Italian Forest";
  string forestType2 = "z45 Arabian Desert";
  string cliffType = "Africa Desert Grass";
  string mapType1 = "mediSea";
  string mapType2 = "grass";
  string huntable1 = "ypibex";
  string huntable2 = "ypWildElephant";
  string fish1 = "FishSalmon";
  string fish2 = "ypFishTuna";
  string whale1 = "MinkeWhale";
  string lightingType = "punjab_skirmish";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";
  
	// Define Natives
  int subCiv0=-1;
  int subCiv1=-1;
  int subCiv2=-1;
  int subCiv3=-1;
  int subCiv4=-1;

  int mapVariation = rmRandInt(1, 2);

  if (rmAllocateSubCivs(5) == true)
  {
  subCiv0=rmGetCivID("natpirates");
    rmEchoInfo("subCiv0 is pirates "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "natpirates");

    subCiv1=rmGetCivID("zpvenetians");
    rmEchoInfo("subCiv1 is zpvenetians "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "zpvenetians");

  subCiv2=rmGetCivID("zpscientists");
    rmEchoInfo("subCiv2 is zpscientists "+subCiv2);
    if (subCiv2 >= 0)
        rmSetSubCiv(2, "zpscientists");

    if (mapVariation == 1){
      subCiv3=rmGetCivID("maltese");
      rmEchoInfo("subCiv3 is maltese "+subCiv3);
      if (subCiv3 >= 0)
          rmSetSubCiv(3, "maltese");
    
      subCiv4=rmGetCivID("spcsufi");
      rmEchoInfo("subCiv4 is spcsufi "+subCiv4);
      if (subCiv4 >= 0)
          rmSetSubCiv(4, "spcsufi");
    }

    if (mapVariation == 2){
      subCiv3=rmGetCivID("spcjesuit");
      rmEchoInfo("subCiv3 is spcjesuit "+subCiv3);
      if (subCiv3 >= 0)
          rmSetSubCiv(3, "spcjesuit");
    
      subCiv4=rmGetCivID("jewish");
      rmEchoInfo("subCiv4 is jewish "+subCiv4);
      if (subCiv4 >= 0)
          rmSetSubCiv(4, "jewish");
    }
  }


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=28000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 32000;
  if (cNumberNonGaiaPlayers < 3)
		playerTiles = 42000;
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
  rmSetMapType("mediEurope");
  rmSetMapType("euroNavalTradeRoute");
  rmSetMapType("anno");
	rmSetLightingSet("punjab_skirmish");
  rmSetOceanReveal(true);

	// Initialize map.
	rmTerrainInitialize(baseTerrain);

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("classPatch");
	rmDefineClass("importantItem");
	int classCanyon=rmDefineClass("canyon");
  int classAtol=rmDefineClass("atol");
  int classEuIsland=rmDefineClass("europe island");
  int classAfIsland=rmDefineClass("africa island");
  int classPortSite=rmDefineClass("portSite");

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
  int avoidAtol=rmCreateClassDistanceConstraint("stuff avoids atols", classAtol, 30.0);
  int avoidEurope=rmCreateClassDistanceConstraint("stuff avoids eu islands", classEuIsland, 30.0);
  int avoidAfrica=rmCreateClassDistanceConstraint("stuff avoids af islands", classAfIsland, 30.0);
  
	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
	int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "minecopper", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minetin", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 70.0); 
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 20.0);
  int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 30.0);
  int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketSPCJesuit", 30.0);
  int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 17.0);
  int avoidControllerFar=rmCreateTypeDistanceConstraint("stay away from Controller Far", "zpSPCWaterSpawnPoint", 60.0);
  int avoidControllerMediumFar=rmCreateTypeDistanceConstraint("stay away from Controller Medium Far", "zpSPCWaterSpawnPoint", 25.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
  int avoidMesa=rmCreateClassDistanceConstraint("avoid random mesas on south central portion of migration island", classCanyon, 10.0);

	// Constraint to avoid water.
	int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 4.0);
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

  // things
	int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
  int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 10.0);
  
  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 12.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
  int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
  int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
	int flagVsWokou1 = rmCreateTypeDistanceConstraint("flag avoid wokou 1", "zpWokouWaterSpawnFlag1", 40);
  int flagVsWokou2 = rmCreateTypeDistanceConstraint("flag avoid wokou  2", "zpWokouWaterSpawnFlag2", 40);
  int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

   //Trade Route Contstraints
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
   int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 30.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);
	    	

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
  
	  rmSetPlacementSection(0.375, 0.374);

    if (cNumberNonGaiaPlayers < 4)
    rmPlacePlayersCircular(0.20, 0.20, 0);
    
    else
	  rmPlacePlayersCircular(0.18, 0.18, 0);

	float playerFraction=rmAreaTilesToFraction(7000 - cNumberNonGaiaPlayers*300);
	for(i=1; <cNumberPlayers)
	{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmSetAreaSize(playerID, rmAreaTilesToFraction(900.0), rmAreaTilesToFraction(900.0));
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	  rmSetAreaCoherence(playerID, 1.0);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, baseMix);
      rmAddAreaTerrainLayer(playerID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(playerID, "AfricaDesert\ground_grass4_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(playerID, "AfricaDesert\ground_grass3_afriDesert", 9, 12);
    rmAddAreaTerrainLayer(playerID, "AfricaDesert\ground_grass2_afriDesert", 12, 15);
	// rmSetAreaTerrainType(playerID, playerTerrain);
    rmAddAreaToClass(playerID, classAtol);
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
    rmBuildArea(playerID);   	
	}


    // Make one big island.  
	int smallIslandID=rmCreateArea("corsair island");
	rmSetAreaSize(smallIslandID, rmAreaTilesToFraction(1670.0), rmAreaTilesToFraction(1670.0));
	rmSetAreaCoherence(smallIslandID, 0.45);
	rmSetAreaBaseHeight(smallIslandID, 2.0);
	rmSetAreaSmoothDistance(smallIslandID, 20);
	rmSetAreaMix(smallIslandID, baseMix);
	rmAddAreaToClass(smallIslandID, classIsland);
  rmAddAreaToClass(smallIslandID, classEuIsland);
  rmAddAreaConstraint(smallIslandID, islandAvoidTradeRoute);
	rmAddAreaConstraint(smallIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIslandID, false);
  rmSetAreaLocation(smallIslandID, 0.73, 0.73);
    rmAddAreaTerrainLayer(smallIslandID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(smallIslandID, "AfricaDesert\ground_grass4_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(smallIslandID, "AfricaDesert\ground_grass3_afriDesert", 9, 12);
    rmAddAreaTerrainLayer(smallIslandID, "AfricaDesert\ground_grass2_afriDesert", 12, 15);
  
	rmBuildArea(smallIslandID);

  int seaLakeID=rmCreateArea("Sea Lake");
	rmSetAreaWaterType(seaLakeID, seaType);
  rmSetAreaSize(seaLakeID, rmAreaTilesToFraction(1330.0), rmAreaTilesToFraction(1330.0));
	rmSetAreaCoherence(seaLakeID, 1.0);
	rmSetAreaLocation(seaLakeID, 0.73-rmZTilesToFraction(10), 0.73);
	rmSetAreaBaseHeight(seaLakeID, 1.0);
	rmSetAreaObeyWorldCircleConstraint(seaLakeID, false);
	rmSetAreaSmoothDistance(seaLakeID, 10);
	rmBuildArea(seaLakeID); 

  int smallIsland2ID=rmCreateArea("corsair island2");
	rmSetAreaSize(smallIsland2ID, 0.015, 0.015);
	rmSetAreaCoherence(smallIsland2ID, 0.45);
	rmSetAreaBaseHeight(smallIsland2ID, 2.0);
	rmSetAreaSmoothDistance(smallIsland2ID, 20);
	rmSetAreaMix(smallIsland2ID,paintMix);
	rmAddAreaToClass(smallIsland2ID, classIsland);
  rmAddAreaToClass(smallIsland2ID, classAfIsland);
	rmAddAreaConstraint(smallIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIsland2ID, false);
	rmSetAreaElevationType(smallIsland2ID, cElevTurbulence);
  rmAddAreaConstraint(smallIsland2ID, islandAvoidTradeRoute);
	rmSetAreaElevationVariation(smallIsland2ID, 2.0);
	rmSetAreaElevationMinFrequency(smallIsland2ID, 0.09);
	rmSetAreaElevationOctaves(smallIsland2ID, 3);
	rmSetAreaElevationPersistence(smallIsland2ID, 0.2);
	rmSetAreaElevationNoiseBias(smallIsland2ID, 1);
  rmSetAreaLocation(smallIsland2ID, .25, .25);
    rmAddAreaTerrainLayer(smallIsland2ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(smallIsland2ID, "AfricaDesert\ground_dirt2_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(smallIsland2ID, "AfricaDesert\ground_sand1_afriDesert", 9, 15);
    rmAddAreaTerrainLayer(smallIsland2ID, "AfricaDesert\ground_rock1_afriDesert", 15, 22);
  rmBuildArea(smallIsland2ID);

    int controllerID2 = rmCreateObjectDef("Controler 2");
   rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmPlaceObjectDefAtLoc(controllerID2, 0, 0.29, 0.29);
   vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

  int pirateSite1 = rmCreateArea ("pirate_site1");
   rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
   rmSetAreaMix(pirateSite1, "africa desert sand");
   rmSetAreaCoherence(pirateSite1, 1);
   rmSetAreaSmoothDistance(pirateSite1, 15);
   rmSetAreaBaseHeight(pirateSite1, 2.0);
   rmAddAreaToClass(pirateSite1, classIsland);
  rmAddAreaToClass(pirateSite1, classAfIsland);
   rmBuildArea(pirateSite1);
  

  int smallIsland3ID=rmCreateArea("corsair island3");
	rmSetAreaSize(smallIsland3ID, 0.018, 0.018);
	rmSetAreaCoherence(smallIsland3ID, 0.45);
	rmSetAreaBaseHeight(smallIsland3ID, 2.0);
	rmSetAreaSmoothDistance(smallIsland3ID, 20);
	rmSetAreaMix(smallIsland3ID, baseMix);
	rmAddAreaToClass(smallIsland3ID, classIsland);
  rmAddAreaToClass(smallIsland3ID, classEuIsland);
	rmAddAreaConstraint(smallIsland3ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIsland3ID, false);
	rmSetAreaElevationType(smallIsland3ID, cElevTurbulence);
  rmAddAreaConstraint(smallIsland3ID, islandAvoidTradeRoute);
	rmSetAreaElevationVariation(smallIsland3ID, 2.0);
	rmSetAreaElevationMinFrequency(smallIsland3ID, 0.09);
	rmSetAreaElevationOctaves(smallIsland3ID, 3);
	rmSetAreaElevationPersistence(smallIsland3ID, 0.2);
	rmSetAreaElevationNoiseBias(smallIsland3ID, 1);
  rmSetAreaLocation(smallIsland3ID, .5, .5);
    rmAddAreaTerrainLayer(smallIsland3ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(smallIsland3ID, "AfricaDesert\ground_grass4_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(smallIsland3ID, "AfricaDesert\ground_grass3_afriDesert", 9, 12);
    rmAddAreaTerrainLayer(smallIsland3ID, "AfricaDesert\ground_grass2_afriDesert", 12, 15);
  rmBuildArea(smallIsland3ID);

  int controllerID3 = rmCreateObjectDef("Controler 3");
      rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmPlaceObjectDefAtLoc(controllerID3, 0, 0.45, 0.45);
      vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));

  int pirateSite2 = rmCreateArea ("pirate_site2");
   rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)));
   rmSetAreaMix(pirateSite2, "africa desert grass dry");
   rmSetAreaCoherence(pirateSite2, 1);
   rmSetAreaSmoothDistance(pirateSite2, 15);
   rmSetAreaBaseHeight(pirateSite2, 2.0);
   rmAddAreaToClass(pirateSite2, classIsland);
  rmAddAreaToClass(pirateSite2, classEuIsland);
   rmBuildArea(pirateSite2);


  int nativeIslandConstraint=rmCreateAreaConstraint("native Island", smallIslandID);

    int playerIsland1ID=rmCreateArea("player island 1");
    rmSetAreaLocation(playerIsland1ID, .45, .8);
    rmSetAreaSize(playerIsland1ID, 0.04, 0.04);
    rmAddAreaToClass(playerIsland1ID, classIsland);
    rmAddAreaToClass(playerIsland1ID, classEuIsland);
    rmSetAreaWarnFailure(playerIsland1ID, false);
	  rmSetAreaCoherence(playerIsland1ID, 0.5);
    rmSetAreaBaseHeight(playerIsland1ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland1ID, 20);
    rmSetAreaMix(playerIsland1ID, baseMix);
      rmAddAreaTerrainLayer(playerIsland1ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(playerIsland1ID, "AfricaDesert\ground_grass4_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(playerIsland1ID, "AfricaDesert\ground_grass3_afriDesert", 9, 12);
    rmAddAreaTerrainLayer(playerIsland1ID, "AfricaDesert\ground_grass2_afriDesert", 12, 15);
    rmAddAreaConstraint(playerIsland1ID, islandConstraint);
    rmAddAreaConstraint(playerIsland1ID, islandEdgeConstraint);
    rmAddAreaConstraint(playerIsland1ID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerIsland1ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland1ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland1ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland1ID, 3);
    rmSetAreaElevationPersistence(playerIsland1ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland1ID, 1);
    rmBuildArea(playerIsland1ID);

    int playerIsland2ID=rmCreateArea("player island 2");
    rmSetAreaLocation(playerIsland2ID, .8, .45);
    rmSetAreaSize(playerIsland2ID,  0.04, 0.04);
    rmAddAreaToClass(playerIsland2ID, classIsland);
    rmAddAreaToClass(playerIsland2ID, classEuIsland);
    rmSetAreaWarnFailure(playerIsland2ID, false);
	  rmSetAreaCoherence(playerIsland2ID, 0.5);
    rmSetAreaBaseHeight(playerIsland2ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland2ID, 20);
    rmSetAreaMix(playerIsland2ID, baseMix);
      rmAddAreaTerrainLayer(playerIsland2ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
      rmAddAreaTerrainLayer(playerIsland2ID, "AfricaDesert\ground_grass4_afriDesert", 6, 9);
      rmAddAreaTerrainLayer(playerIsland2ID, "AfricaDesert\ground_grass3_afriDesert", 9, 12);
      rmAddAreaTerrainLayer(playerIsland2ID, "AfricaDesert\ground_grass2_afriDesert", 12, 15);
    rmAddAreaConstraint(playerIsland2ID, islandConstraint);
    rmAddAreaConstraint(playerIsland2ID, islandEdgeConstraint);
    rmAddAreaConstraint(playerIsland2ID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerIsland2ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland2ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland2ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland2ID, 3);
    rmSetAreaElevationPersistence(playerIsland2ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland2ID, 1);	
    rmBuildArea(playerIsland2ID);

    int playerIsland3ID=rmCreateArea("player island 3");
    rmSetAreaLocation(playerIsland3ID, .2, .55);
    rmSetAreaSize(playerIsland3ID,  0.04, 0.04);
    rmAddAreaToClass(playerIsland3ID, classIsland);
    rmAddAreaToClass(playerIsland3ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland3ID, false);
	  rmSetAreaCoherence(playerIsland3ID, 0.5);
    rmSetAreaBaseHeight(playerIsland3ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland3ID, 20);
    rmSetAreaMix(playerIsland3ID, paintMix);
    rmAddAreaTerrainLayer(playerIsland3ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(playerIsland3ID, "AfricaDesert\ground_dirt2_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(playerIsland3ID, "AfricaDesert\ground_sand1_afriDesert", 9, 15);
    rmAddAreaTerrainLayer(playerIsland3ID, "AfricaDesert\ground_rock1_afriDesert", 15, 22);
    rmAddAreaConstraint(playerIsland3ID, islandConstraint);
    rmAddAreaConstraint(playerIsland3ID, islandEdgeConstraint);
    rmAddAreaConstraint(playerIsland3ID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerIsland3ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland3ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland3ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland3ID, 3);
    rmSetAreaElevationPersistence(playerIsland3ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland3ID, 1);  	
    rmBuildArea(playerIsland3ID);

    int playerIsland4ID=rmCreateArea("player island 4");
    rmSetAreaLocation(playerIsland4ID, .55, .2);
    rmSetAreaSize(playerIsland4ID,  0.04, 0.04);
    rmAddAreaToClass(playerIsland4ID, classIsland);
    rmAddAreaToClass(playerIsland4ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland4ID, false);
	  rmSetAreaCoherence(playerIsland4ID, 0.5);
    rmSetAreaBaseHeight(playerIsland4ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland4ID, 20);
    rmSetAreaMix(playerIsland4ID, paintMix);
    rmAddAreaTerrainLayer(playerIsland4ID, "AfricaDesert\ground_dirt1_afriDesert", 0, 6);
    rmAddAreaTerrainLayer(playerIsland4ID, "AfricaDesert\ground_dirt2_afriDesert", 6, 9);
    rmAddAreaTerrainLayer(playerIsland4ID, "AfricaDesert\ground_sand1_afriDesert", 9, 15);
    rmAddAreaTerrainLayer(playerIsland4ID, "AfricaDesert\ground_rock1_afriDesert", 15, 22);
    rmAddAreaConstraint(playerIsland4ID, islandConstraint);
    rmAddAreaConstraint(playerIsland4ID, islandEdgeConstraint);
    rmAddAreaConstraint(playerIsland4ID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerIsland4ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland4ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland4ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland4ID, 3);
    rmSetAreaElevationPersistence(playerIsland4ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland4ID, 1);  	
    rmBuildArea(playerIsland4ID);


	
    

  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);
  
	// NATIVES

    int controllerID1 = rmCreateObjectDef("Controler 1");
    rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmSetObjectDefMinDistance(controllerID1, 0.0);
    rmSetObjectDefMaxDistance(controllerID1, 0.0);
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.73, 0.73+rmZTilesToFraction(6));
    vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

  
  // Pirate Village

         int piratesVillageID = -1;
         piratesVillageID = rmCreateGrouping("pirate city", "pirate_village03");     


         rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

         int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
         rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
         rmAddClosestPointConstraint(flagLandShort);
         rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

         vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
         rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

         rmClearClosestPointConstraints();

         int pirateportID1 = -1;
         pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport03");
         rmAddClosestPointConstraint(portOnShore);
         rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

         vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
         rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
         
         rmClearClosestPointConstraints();

// Scientist Village 3

     int piratesVillageID3 = -1;
      piratesVillageID3 = rmCreateGrouping("pirate city 3", "Scientist_Lab06");

      rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);
    
      int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
      rmAddObjectDefItem(piratewaterflagID3, "zpNativeWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

      rmClearClosestPointConstraints();

      int pirateportID3 = -1;
      pirateportID3 = rmCreateGrouping("pirate port 3", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage3a = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));
      
      rmClearClosestPointConstraints();

         
// Venice Settlement

      int veniceVillageID = -1;
      veniceVillageID = rmCreateGrouping("venice city", "Venice_01");

      rmPlaceGroupingAtLoc(veniceVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))-rmXTilesToFraction(0), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))-rmXTilesToFraction(8), 1);

      int venicewaterflagID1 = rmCreateObjectDef("venice water flag 1");
      rmAddObjectDefItem(venicewaterflagID1, "zpVenetianWaterSpawnFlag1", 1, 1.0);
      rmPlaceObjectDefAtLoc(venicewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))-rmXTilesToFraction(10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))+rmXTilesToFraction(6));
  
      // Port Sites

   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.95-rmXTilesToFraction(25), 0.5);
   rmSetAreaMix(portSite1, "Africa Desert Grass dry");
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 2.5);
   rmAddAreaToClass(portSite1, classPortSite);
   rmAddAreaToClass(portSite1, classEuIsland);
   rmBuildArea(portSite1);


   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.5,0.05+rmXTilesToFraction(25));
   rmSetAreaMix(portSite2, paintMix);
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 2.5);
   rmAddAreaToClass(portSite2, classPortSite);
   rmAddAreaToClass(portSite2, classAfIsland);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));

   rmSetAreaMix(portSite3, paintMix);
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.5);
   rmAddAreaToClass(portSite3, classPortSite);
   rmAddAreaToClass(portSite3, classAfIsland);
  rmSetAreaLocation(portSite3, 0.05+rmXTilesToFraction(25), 0.5);
  rmBuildArea(portSite3);

  int portSite4 = rmCreateArea ("port_site4");
  rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(portSite4, 0.5,0.95-rmXTilesToFraction(25));
  rmSetAreaMix(portSite4, "Africa Desert Grass dry");
  rmSetAreaCoherence(portSite4, 1);
  rmSetAreaSmoothDistance(portSite4, 15);
  rmSetAreaBaseHeight(portSite4, 2.5);
  rmAddAreaToClass(portSite4, classPortSite);
  rmAddAreaToClass(portSite4, classEuIsland);
  rmBuildArea(portSite4);



  // Port 1
  int portID01 = rmCreateObjectDef("port 02");
  portID01 = rmCreateGrouping("portG 01", "Harbour_Center_NE");
  rmPlaceGroupingAtLoc(portID01, 0, 0.95-rmXTilesToFraction(12), 0.5);

  // Port 2
  int portID02 = rmCreateObjectDef("port 02");
  portID02 = rmCreateGrouping("portG 02", "harbour_arabia_SE");
  rmPlaceGroupingAtLoc(portID02, 0, 0.5,0.05+rmXTilesToFraction(12));

  // Port 3
  int portID03 = rmCreateObjectDef("port 03");
  portID03 = rmCreateGrouping("portG 03", "harbour_arabia_SW");
  rmPlaceGroupingAtLoc(portID03, 0, 0.05+rmXTilesToFraction(12), 0.5);

  // Port 4
  int portID04 = rmCreateObjectDef("port 04");
  portID04 = rmCreateGrouping("portG 04", "Harbour_Center_NW");
  rmPlaceGroupingAtLoc(portID04, 0, 0.5,0.95-rmXTilesToFraction(12));
      


      // check for KOTH game mode
      if(rmGetIsKOTH()) {
        
        float xLoc = 0.515;
        float yLoc = 0.515;
        float walk = 0.00;
        
        ypKingsHillPlacer(xLoc, yLoc, walk, 0);
        rmEchoInfo("XLOC = "+xLoc);
        rmEchoInfo("XLOC = "+yLoc);
      }


	// text
	rmSetStatusText("",0.50);

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
	rmAddObjectDefItem(playerGoldID, "mine", 1, 0);
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
  

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 5.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 15.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 17.0);
  

	int waterSpawnPointID = 0;

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.60);
   
	// *********** Place Home City Water Spawn Flag ***************************************************
  
  rmClearClosestPointConstraints();

	for(i=1; <cNumberPlayers) {

    int colonyShipID=rmCreateObjectDef("colony ship 2"+i);
    rmAddObjectDefItem(colonyShipID, "deStartingUnitPrivateer", 1, 0.0);
    rmSetObjectDefMinDistance(colonyShipID, 0.0);
    rmSetObjectDefMaxDistance(colonyShipID, 10.0);
    
    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
		rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    
		// Place water spawn points for the players along with a canoe
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 2.0);
		rmAddClosestPointConstraint(flagVsFlag);
    rmAddClosestPointConstraint(flagVsPirates1);
    rmAddClosestPointConstraint(flagVsPirates2);
    rmAddClosestPointConstraint(flagVsWokou1);
    rmAddClosestPointConstraint(flagVsWokou2);
		rmAddClosestPointConstraint(flagLand);
    rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
    rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
		rmClearClosestPointConstraints();
   }

   // Place additional Natives

    int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, 50);
      rmAddObjectDefConstraint(malteseControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater20);
      rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.4, 0.8);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));

      int malteseControllerID2 = rmCreateObjectDef("maltese controller 2");
      rmAddObjectDefItem(malteseControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID2, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID2, 50);
      rmAddObjectDefConstraint(malteseControllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID2, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID2, avoidWater20);
      rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.8, 0.4);
      vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));

      int malteseControllerID3 = rmCreateObjectDef("maltese controller 3");
      rmAddObjectDefItem(malteseControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID3, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID3, 50);
      rmAddObjectDefConstraint(malteseControllerID3, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID3, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID3, avoidWater20);
      rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.2, 0.6);
      vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));

      int malteseControllerID4 = rmCreateObjectDef("maltese controller 4");
      rmAddObjectDefItem(malteseControllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID4, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID4, 50);
      rmAddObjectDefConstraint(malteseControllerID4, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID4, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID4, avoidWater20);
      rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.6, 0.2);
      vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));

      int eastIslandVillage1 = rmCreateArea ("east island village 1");
      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaBaseHeight(eastIslandVillage1, 4.0);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmBuildArea(eastIslandVillage1);

      int eastIslandVillage2 = rmCreateArea ("east island village 2");
      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      rmSetAreaBaseHeight(eastIslandVillage2, 4.0);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmBuildArea(eastIslandVillage2);

      int eastIslandVillage3 = rmCreateArea ("east island village 3");
      rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage3, 5);
      rmSetAreaBaseHeight(eastIslandVillage3, 4.0);
      rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
      rmBuildArea(eastIslandVillage3);

      int eastIslandVillage4 = rmCreateArea ("east island village 4");
      rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
      rmSetAreaCoherence(eastIslandVillage4, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage4, 5);
      rmSetAreaBaseHeight(eastIslandVillage4, 4.0);
      rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
      rmBuildArea(eastIslandVillage4);



  
    int jesuit1VillageID = -1;

    if (mapVariation == 1){
      int jesuit1VillageType = rmRandInt(1,5);
      jesuit1VillageID = rmCreateGrouping("jesuit 1", "Maltese_Village0"+jesuit1VillageType);
    }
    else {
      jesuit1VillageType = rmRandInt(1,3);
      jesuit1VillageID = rmCreateGrouping("jesuit 1", "Jesuit_Cathedral_EU_0"+jesuit1VillageType);
    }
    rmAddGroupingConstraint(jesuit1VillageID , avoidImpassableLand);
    rmAddGroupingConstraint(jesuit1VillageID , avoidWater20);
    rmAddGroupingConstraint(jesuit1VillageID , avoidTCLong);
    rmAddGroupingConstraint(jesuit1VillageID , avoidTPLong);


    int jesuit2VillageID = -1;
    if (mapVariation == 1){
      int jesuit2VillageType = rmRandInt(1,5);
      jesuit2VillageID = rmCreateGrouping("jesuit 2", "Maltese_Village0"+jesuit2VillageType);
    }
    if (mapVariation == 2){
      jesuit2VillageType = rmRandInt(1,3);
      jesuit2VillageID = rmCreateGrouping("jesuit 2", "Jesuit_Cathedral_EU_0"+jesuit2VillageType);
    }
    rmAddGroupingConstraint(jesuit2VillageID , avoidImpassableLand);
    rmAddGroupingConstraint(jesuit2VillageID , avoidWater20);
    rmAddGroupingConstraint(jesuit2VillageID , avoidTCLong);
    rmAddGroupingConstraint(jesuit2VillageID , avoidTPLong);


    int jesuit3VillageID = -1;
    int jesuit3VillageType = rmRandInt(1,3);
    if (mapVariation == 1){
      jesuit3VillageID = rmCreateGrouping("jesuit 3", "sufibluemosque_0"+jesuit3VillageType);
    }
    if (mapVariation == 2){
      jesuit3VillageID = rmCreateGrouping("jesuit 3", "Jewish_Settlement_0"+jesuit3VillageType);
    }
    rmAddGroupingConstraint(jesuit3VillageID , avoidImpassableLand);
    rmAddGroupingConstraint(jesuit3VillageID , avoidWater20);
    rmAddGroupingConstraint(jesuit3VillageID , avoidTCLong);
    rmAddGroupingConstraint(jesuit3VillageID , avoidTPLong);


    int jesuit4VillageID = -1;
    int jesuit4VillageType = rmRandInt(1,3);
    if (mapVariation == 1){
      jesuit4VillageID = rmCreateGrouping("jesuit 4", "sufibluemosque_0"+jesuit4VillageType);
    }
    if (mapVariation == 2){
      jesuit4VillageID = rmCreateGrouping("jesuit 4", "Jewish_Settlement_0"+jesuit4VillageType);
    }
    rmAddGroupingConstraint(jesuit4VillageID , avoidImpassableLand);
    rmAddGroupingConstraint(jesuit4VillageID , avoidWater20);
    rmAddGroupingConstraint(jesuit4VillageID , avoidTCLong);
    rmAddGroupingConstraint(jesuit4VillageID , avoidTPLong);


  rmPlaceGroupingAtLoc(jesuit1VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);
  rmPlaceGroupingAtLoc(jesuit2VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);
  rmPlaceGroupingAtLoc(jesuit3VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);
  rmPlaceGroupingAtLoc(jesuit4VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);


	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
  int forestTreeID = 0;
  numTries=7*cNumberNonGaiaPlayers;
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
    rmAddAreaConstraint(forest, avoidJesuit);
    rmAddAreaConstraint(forest, avoidTP);
    rmAddAreaConstraint(forest, avoidTCMedium);
    rmAddAreaConstraint(forest, avoidAtol);
    rmAddAreaConstraint(forest, avoidKOTH);
    rmAddAreaConstraint(forest, avoidAfrica);
    rmAddAreaConstraint(forest, shortAvoidImpassableLand);  
    if(rmBuildArea(forest)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount++;
      
      if(failCount==5)
        break;
    }
    
    else
      failCount=0; 
  } 

  int failCount2=0;
  for (i=0; <numTries) {   
    int forest2=rmCreateArea("forest2 "+i);
    rmSetAreaWarnFailure(2, false);
    rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
    rmSetAreaForestType(forest2, forestType2);
    rmSetAreaForestDensity(forest2, 0.6);
    rmSetAreaForestClumpiness(forest2, 0.1);
    rmSetAreaForestUnderbrush(forest2, 0.6);
    rmSetAreaMinBlobs(forest2, 1);
    rmSetAreaMaxBlobs(forest2, 5);
    rmSetAreaMinBlobDistance(forest2, 16.0);
    rmSetAreaMaxBlobDistance(forest2, 40.0);
    rmSetAreaCoherence(forest2, 0.4);
    rmSetAreaSmoothDistance(forest2, 10);
    rmAddAreaToClass(forest2, rmClassID("classForest")); 
    rmAddAreaConstraint(forest2, forestConstraint);
    rmAddAreaConstraint(forest2, avoidAll);
    rmAddAreaConstraint(forest2, avoidPirates);
    rmAddAreaConstraint(forest2, avoidJesuit);
    rmAddAreaConstraint(forest2, avoidTP);
    rmAddAreaConstraint(forest2, avoidTCMedium);
    rmAddAreaConstraint(forest2, avoidAtol);
    rmAddAreaConstraint(forest2, avoidEurope);
    rmAddAreaConstraint(forest2, shortAvoidImpassableLand);  
    if(rmBuildArea(forest2)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount2++;
      
      if(failCount2==5)
        break;
    }
    
    else
      failCount2=0; 
  } 

    
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered silver throughout island and gold in south central area
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minecopper", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(goldID, avoidAll);
  rmAddObjectDefConstraint(goldID, avoidWater4);
	rmAddObjectDefConstraint(goldID, avoidGold);
  rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(goldID, avoidImportantItem);
  rmAddAreaConstraint(goldID, avoidJesuit);
  rmAddObjectDefConstraint(goldID, avoidController);
  rmAddObjectDefConstraint(goldID, avoidCoin);
  rmAddObjectDefConstraint(goldID, avoidTP);
	rmPlaceObjectDefInArea(goldID, 0, smallIslandID, 1);
  rmPlaceObjectDefInArea(goldID, 0, smallIsland2ID, cNumberNonGaiaPlayers/4);
  rmPlaceObjectDefInArea(goldID, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(goldID, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);

  int silverID = rmCreateObjectDef("random silver");
	rmAddObjectDefItem(silverID, "minetin", 1, 0);
	rmSetObjectDefMinDistance(silverID, 0.0);
	rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(silverID, avoidAll);
  rmAddObjectDefConstraint(silverID, avoidWater8);
	rmAddObjectDefConstraint(silverID, avoidGold);
  rmAddObjectDefConstraint(silverID, avoidCoin);
  rmAddAreaConstraint(silverID, avoidPirates);
  rmAddObjectDefConstraint(silverID, avoidController);
  rmAddAreaConstraint(silverID, avoidWokou);
  rmAddObjectDefConstraint(silverID, avoidTCLong);
  rmAddObjectDefConstraint(silverID, avoidTP);
  rmAddObjectDefConstraint(silverID, avoidImportantItem);
  rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);
  rmPlaceObjectDefInArea(silverID, 0, smallIsland3ID, cNumberNonGaiaPlayers/4);
  rmPlaceObjectDefInArea(silverID, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(silverID, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);
   
	// Scattered berries all over island
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 4.0); 
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(berriesID, avoidTP);   
	rmAddObjectDefConstraint(berriesID, avoidAll);
  rmAddObjectDefConstraint(berriesID, avoidImportantItem);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, shortAvoidImpassableLand);
	rmPlaceObjectDefInArea(berriesID, 0, smallIslandID, );
  rmPlaceObjectDefInArea(berriesID, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(berriesID, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);

	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, northConstraint);
  rmAddObjectDefConstraint(foodID1, avoidController);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
	rmPlaceObjectDefInArea(foodID1, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(foodID1, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(foodID1, 0, smallIsland3ID, cNumberNonGaiaPlayers/4);
  
  // Huntables scattered on island
	int foodID2=rmCreateObjectDef("random food two");
	rmAddObjectDefItem(foodID2, huntable2, rmRandInt(2,4), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID2, avoidTP);
  rmAddObjectDefConstraint(foodID2, avoidTCLong);
  rmAddObjectDefConstraint(foodID2, avoidImportantItem);
  rmAddObjectDefConstraint(foodID2, avoidController);
  rmAddObjectDefConstraint(foodID2, avoidHuntable2);
	rmPlaceObjectDefInArea(foodID2, 0, smallIsland2ID, cNumberNonGaiaPlayers/4);
  rmPlaceObjectDefInArea(foodID2, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(foodID2, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);

	// Define and place Nuggets
    
	// Easier nuggets North
	int nugget1= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 3);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
  rmAddObjectDefConstraint(nugget1, avoidImportantItem);
	rmAddObjectDefConstraint(nugget1, avoidTP);
	rmAddObjectDefConstraint(nugget1, avoidAll);
  rmAddObjectDefConstraint(nugget1, avoidController);
	rmAddObjectDefConstraint(nugget1, avoidWater8);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland1ID, cNumberNonGaiaPlayers);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland2ID, cNumberNonGaiaPlayers);

  // Harder nuggets North
	int nugget2= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
  rmAddObjectDefConstraint(nugget2, avoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidController);
	rmAddObjectDefConstraint(nugget2, avoidTP);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater4);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
  rmPlaceObjectDefInArea(nugget2, 0, smallIsland3ID, 1+cNumberNonGaiaPlayers/4);
  rmPlaceObjectDefInArea(nugget2, 0, smallIslandID, 1);

  // Easier nuggets South
	int nugget1b= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nugget1b, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(71, 73);
	rmSetObjectDefMinDistance(nugget1b, 0.0);
	rmSetObjectDefMaxDistance(nugget1b, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget1b, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1b, avoidNugget);
  rmAddObjectDefConstraint(nugget1b, avoidImportantItem);
  rmAddObjectDefConstraint(nugget1b, avoidController);
	rmAddObjectDefConstraint(nugget1b, avoidTP);
	rmAddObjectDefConstraint(nugget1b, avoidAll);
	rmAddObjectDefConstraint(nugget1b, avoidWater8);
	rmAddObjectDefConstraint(nugget1b, playerEdgeConstraint);
  rmPlaceObjectDefInArea(nugget1b, 0, playerIsland3ID, cNumberNonGaiaPlayers);
  rmPlaceObjectDefInArea(nugget1b, 0, playerIsland4ID, cNumberNonGaiaPlayers);

  // Harder nuggets South
	int nugget2b= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nugget2b, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(74, 74);
	rmSetObjectDefMinDistance(nugget2b, 0.0);
	rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget2b, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2b, avoidNugget);
  rmAddObjectDefConstraint(nugget2b, avoidImportantItem);
  rmAddObjectDefConstraint(nugget2b, avoidController);
	rmAddObjectDefConstraint(nugget2b, avoidTP);
	rmAddObjectDefConstraint(nugget2b, avoidAll);
	rmAddObjectDefConstraint(nugget2b, avoidWater4);
	rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
  rmPlaceObjectDefInArea(nugget2b, 0, smallIsland2ID, 1+cNumberNonGaiaPlayers/4);


	// Water nuggets
  int nuggetCount = cNumberNonGaiaPlayers;
  
  int nuggetWater= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nuggetWater, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetWater, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetWater, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetWater, avoidLand);
  rmAddObjectDefConstraint(nuggetWater, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetWater, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetWater, flagVsFlag);
  rmAddObjectDefConstraint(nuggetWater, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nuggetWater, false, nuggetCount);

  int nuggetWaterb = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nuggetWaterb, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nuggetWaterb, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nuggetWaterb, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetWaterb, avoidLand);
  rmAddObjectDefConstraint(nuggetWaterb, flagVsFlag);
  rmAddObjectDefConstraint(nuggetWaterb, avoidNuggetWater2);
  rmAddObjectDefConstraint(nuggetWaterb, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetWaterb, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nuggetWaterb, false, nuggetCount/2);
  

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
  rmAddObjectDefConstraint(whaleID, avoidControllerFar);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4); 

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
  rmAddObjectDefConstraint(fishID, avoidControllerMediumFar);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

	int fish2ID=rmCreateObjectDef("fish 2");
	rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, avoidFish2);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
  rmAddObjectDefConstraint(fish2ID, avoidControllerMediumFar);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 17*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}

    // Starter shipment triggers

    // ------Triggers--------//

int tch0=1671; // tech operator

// Starter shipment triggers
for(i = 1; < cNumberPlayers) {
rmCreateTrigger("XP"+i);
rmSwitchToTrigger(rmTriggerID("XP"+i));
rmSetTriggerPriority(1); 
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmAddTriggerCondition("Always");

rmAddTriggerEffect("Grant Resources");
rmSetTriggerEffectParamInt("PlayerID", i, false);
rmSetTriggerEffectParam("ResName", "Ships", false);
rmSetTriggerEffectParam("Amount", "1", false);
}

// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Europen Map
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpMediterraneanSufi"); // Sufi Mosque
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpAnnoMercenaries"); // Mercenaries
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerEffectParam("TechID","cTechzpNativeHeavyMap"); // Native Embassy Techs
rmSetTriggerEffectParamInt("Status",2);
}
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
rmCreateTrigger("Activate Maltese"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpMalteseCross"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffMaltese"); //operator
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

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Jewish"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpJewishStar"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffJewish"); //operator
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

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Venice"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpVenetianExpansion"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffVenice"); //operator
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

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Renegades"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientists"); //operator
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Venice"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Jewish"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Update ports

rmCreateTrigger("I Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingGalleon");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingFluyt");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Privateer training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainPrivateer1ON Plr"+k);
rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
rmCreateTrigger("TrainPrivateer1TIME Plr"+k);

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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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

// Build limit reducer
rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
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
rmSetTriggerEffectParamInt("Dist",150);
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
rmSetTriggerEffectParamInt("Dist",150);
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

// Galley training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainGalley1ON Plr"+k);
rmCreateTrigger("TrainGalley1OFF Plr"+k);
rmCreateTrigger("TrainGalley1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","129");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainGalley1OFF_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainGalley1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Galeass Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("trainGalleass1ON Plr"+k);
rmCreateTrigger("trainGalleass1OFF Plr"+k);
rmCreateTrigger("trainGalleass1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("trainGalleass1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","129");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainGalleass1OFF_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainGalleass1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Venice trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Venice1on Player"+k);
rmCreateTrigger("Venice1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Venice1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","129");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","129");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Venice1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","129");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","129");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Venice Captains

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Venice Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int veniceCaptain=-1;
veniceCaptain = rmRandInt(1,3);

if (veniceCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceCornaro"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (veniceCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceContarini"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (veniceCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceDolphin"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}







// Submarine Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainSubmarine1ON Plr"+k);
rmCreateTrigger("TrainSubmarine1OFF Plr"+k);
rmCreateTrigger("TrainSubmarine1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","58"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine1OFF_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Unique ship Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Steamer1TIMEPlr"+k);

rmCreateTrigger("SteamerTrain1ONPlr"+k);
rmCreateTrigger("SteamerTrain1OFFPlr"+k);


// Build limit reducer
rmSwitchToTrigger(rmTriggerID("Steamer1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceSteamerBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Steamer 1
rmSwitchToTrigger(rmTriggerID("SteamerTrain1ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","58"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Steamer1TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("SteamerTrain1OFFPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
  

}

// Nautilus Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Nautilus1TIMEPlr"+k);

rmCreateTrigger("Nautilus1ONPlr"+k);
rmCreateTrigger("Nautilus1OFFPlr"+k);

// Build limit reducer 1
rmSwitchToTrigger(rmTriggerID("Nautilus1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Nautilus 1
rmSwitchToTrigger(rmTriggerID("Nautilus1ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","58"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Nautilus1OFFPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Renegade trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Renegades1on Player"+k);
rmCreateTrigger("Renegades1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Renegades1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","58"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","58"); // Unique Object ID Village 1
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Renegades1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","58"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","58"); // Unique Object ID Village 1
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Renegade Captains

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Renegade Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int renegadeCaptain=-1;
renegadeCaptain = rmRandInt(1,3);

if (renegadeCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistNemo"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (renegadeCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistValentine"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (renegadeCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistkhora"); //operator
      rmSetTriggerEffectParamInt("Status",2);
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpAIAirshipSetup"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Maltese Fractions

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Maltese Fraction"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int malteseFraction=-1;
malteseFraction = rmRandInt(1,3);

if (malteseFraction==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseFlorentians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseFraction==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseJerusalem"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseFraction==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseVenetians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Jewish Fractions

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Jewish Fraction"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int jewishFraction=-1;
jewishFraction = rmRandInt(1,3);

if (jewishFraction==1)
   {
	  rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishAmericans"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (jewishFraction==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishRussians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (jewishFraction==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishGermans"); //operator
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