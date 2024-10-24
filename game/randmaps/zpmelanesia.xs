// Melanesia 1.0

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
  string baseMix = "indochina_grass_a";
  string paintMix = "indochina_grass_a";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ZP Melanesia";
  string startTreeType = "ypTreeBorneoPalm";
  string forestType = "Borneo forest";
  string forestType2 = "Borneo Palm forest";
  string cliffType = "Africa Desert Grass";
  string mapType1 = "melanesia";
  string mapType2 = "grass";
  string huntable1 = "zpFeralPig";
  string huntable2 = "BighornSheep";
  string fish1 = "FishMahi";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string lightingType = "Borneo_Skirmish";
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
  subCiv0=rmGetCivID("wokou");
    rmEchoInfo("subCiv0 is wokou "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "wokou");

    subCiv1=rmGetCivID("NatPirates");
    rmEchoInfo("subCiv1 is NatPirates "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "NatPirates");

  subCiv2=rmGetCivID("zpScientists");
    rmEchoInfo("subCiv2 is zpScientists "+subCiv2);
    if (subCiv2 >= 0)
        rmSetSubCiv(2, "zpScientists");


  subCiv3=rmGetCivID("Korowai");
  rmEchoInfo("subCiv3 is Korowai "+subCiv3);
  if (subCiv3 >= 0)
      rmSetSubCiv(3, "Korowai");

  subCiv4=rmGetCivID("SPCJesuit");
  rmEchoInfo("subCiv4 is SPCJesuit"+subCiv4);
  if (subCiv4 >= 0)
      rmSetSubCiv(4, "SPCJesuit");
    
  }


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=19000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 23000;
  if (cNumberNonGaiaPlayers < 3)
		playerTiles = 30000;
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, 1.4*size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("water");
	rmSetLightingSet(lightingType);
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
  int avoidAtol=rmCreateClassDistanceConstraint("stuff avoids atols", classAtol, 30.0);
  int avoidPirateArea=rmCreateClassDistanceConstraint("stuff avoids piratea rea", classPortSite, 30.0);
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
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "zpJadeMine", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 70.0); 
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 25.0);
  int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 25.0);
  int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketJesuit", 25.0);
  int avoidKorowai=rmCreateTypeDistanceConstraint("avoid socket korowai", "zpSocketKorowai", 25.0);
  int avoidMaori=rmCreateTypeDistanceConstraint("avoid socket maori", "zpSocketScientists", 25.0);
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
  int avoidWater12 = rmCreateTerrainDistanceConstraint("avoid water 12", "Land", false, 12.0);
  int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water 30 long", "Land", false, 30.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
  int ferryOnShore20=rmCreateTerrainMaxDistanceConstraint("ferry v. water 20", "water", true, 20.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 4.5);

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
  int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 15.0);
  int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
  int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 30.0);


  int avoidKOTHshort=rmCreateTypeDistanceConstraint("stay away from Kings Hill short", "ypKingsHill", 8.0);
  int cliffAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("cliff rade route", 2.0);
  int avoidHighMountains=rmCreateClassDistanceConstraint("stuff avoids high mountains", classHighMountains, 3.0);
  int avoidHighMountainsFar=rmCreateClassDistanceConstraint("stuff avoids high mountains far", classHighMountains, 20.0);

  if (cNumberNonGaiaPlayers <=3 ){
    int avoidMaoriLong=rmCreateTypeDistanceConstraint("avoid socket maori long", "zpSocketScientists", 65.0);
    int avoidkorowaiLong=rmCreateTypeDistanceConstraint("avoid socket korowai long", "zpSocketKorowai", 65.0);
    int avoidJesuitLong=rmCreateTypeDistanceConstraint("avoid socket jesuit long", "zpSocketJesuit", 65.0);
  }

  else{
    avoidMaoriLong=rmCreateTypeDistanceConstraint("avoid socket maori long", "zpSocketScientists", 85.0);
    avoidkorowaiLong=rmCreateTypeDistanceConstraint("avoid socket korowai long", "zpSocketKorowai", 85.0);
    avoidJesuitLong=rmCreateTypeDistanceConstraint("avoid socket jesuit long", "zpSocketJesuit", 85.0);
  }






	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);
	    	

   int tradeRouteID = rmCreateTradeRoute();
   int tradeRoute2ID = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.00);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 1.0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

  rmSetObjectDefTradeRouteID(tradeRoute2ID);
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.95, 1.0); 
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.95, 0.0);

   bool placedTradeRoute2 = rmBuildTradeRoute(tradeRoute2ID, "water_trail");

   // PLACE PLAYERS
  
    if (cNumberNonGaiaPlayers == 3)
      rmSetPlacementSection(0.375, 0.374);
    else
      rmSetPlacementSection(0.125, 0.124);
    
    if (cNumberNonGaiaPlayers < 4)
    rmPlacePlayersCircular(0.21, 0.21, 0);
    
    else
	  rmPlacePlayersCircular(0.20, 0.20, 0);

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
	    rmAddAreaTerrainLayer(playerID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerID, "borneo\ground_grass4_borneo", 9, 12);
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
    if (cNumberNonGaiaPlayers <=3){
      rmSetAreaSize(smallIslandID, 0.065, 0.065);
      rmSetAreaCoherence(smallIslandID, 0.7);
    }
    else{
      rmSetAreaSize(smallIslandID, 0.06, 0.06);
      rmSetAreaCoherence(smallIslandID, 0.45);
    }
    rmSetAreaBaseHeight(smallIslandID, 2.0);
    rmSetAreaSmoothDistance(smallIslandID, 20);
    rmSetAreaMix(smallIslandID, baseMix);
    rmAddAreaToClass(smallIslandID, classIsland);
    rmAddAreaToClass(smallIslandID, classEuIsland);
    //rmAddAreaConstraint(smallIslandID, islandAvoidTradeRoute);
    //rmAddAreaConstraint(smallIslandID, islandConstraint);
    rmSetAreaObeyWorldCircleConstraint(smallIslandID, false);
    rmSetAreaElevationType(smallIslandID, cElevTurbulence);
    rmSetAreaElevationVariation(smallIslandID, 3.0);
    rmSetAreaElevationMinFrequency(smallIslandID, 0.09);
    rmSetAreaElevationOctaves(smallIslandID, 3);
    rmAddAreaConstraint(smallIslandID, islandConstraint);
    rmSetAreaElevationPersistence(smallIslandID, 0.2);
    rmSetAreaElevationNoiseBias(smallIslandID, 1);
    rmSetAreaLocation(smallIslandID, 0.5, 0.93);
        rmAddAreaTerrainLayer(smallIslandID, "borneo\ground_sand1_borneo", 0, 4);
        rmAddAreaTerrainLayer(smallIslandID, "borneo\ground_sand2_borneo", 4, 6);
        rmAddAreaTerrainLayer(smallIslandID, "borneo\ground_sand3_borneo", 6, 9);
        rmAddAreaTerrainLayer(smallIslandID, "borneo\ground_grass4_borneo", 9, 12);
	rmBuildArea(smallIslandID);


    int smallIsland2ID=rmCreateArea("corsair island2");
    if (cNumberNonGaiaPlayers <=3){
      rmSetAreaSize(smallIsland2ID, 0.065, 0.065);
      rmSetAreaCoherence(smallIsland2ID, 0.7);
    }
    else{
      rmSetAreaSize(smallIsland2ID, 0.06, 0.06);
      rmSetAreaCoherence(smallIsland2ID, 0.45);
    }
    rmSetAreaBaseHeight(smallIsland2ID, 2.0);
    rmSetAreaSmoothDistance(smallIsland2ID, 20);
    rmSetAreaMix(smallIsland2ID, paintMix);
    rmAddAreaToClass(smallIsland2ID, classIsland);
    rmAddAreaToClass(smallIsland2ID, classEuIsland);
    //rmAddAreaConstraint(smallIsland2ID, islandConstraint);
    rmSetAreaObeyWorldCircleConstraint(smallIsland2ID, false);
    rmSetAreaElevationType(smallIsland2ID, cElevTurbulence);
    //rmAddAreaConstraint(smallIsland2ID, islandAvoidTradeRoute);
    rmSetAreaElevationVariation(smallIsland2ID, 3.0);
    rmSetAreaElevationMinFrequency(smallIsland2ID, 0.09);
    rmSetAreaElevationOctaves(smallIsland2ID, 3);
    rmAddAreaConstraint(smallIsland2ID, islandConstraint);
    rmSetAreaElevationPersistence(smallIsland2ID, 0.2);
    rmSetAreaElevationNoiseBias(smallIsland2ID, 1);
    rmSetAreaLocation(smallIsland2ID, 0.5, 0.07);
        rmAddAreaTerrainLayer(smallIsland2ID, "borneo\ground_sand1_borneo", 0, 4);
        rmAddAreaTerrainLayer(smallIsland2ID, "borneo\ground_sand2_borneo", 4, 6);
        rmAddAreaTerrainLayer(smallIsland2ID, "borneo\ground_sand3_borneo", 6, 9);
        rmAddAreaTerrainLayer(smallIsland2ID, "borneo\ground_grass4_borneo", 9, 12);
    rmBuildArea(smallIsland2ID);

  

  int smallIsland3ID=rmCreateArea("corsair island3");
	rmSetAreaSize(smallIsland3ID, 0.025, 0.025);
	rmSetAreaCoherence(smallIsland3ID, 0.45);
	rmSetAreaBaseHeight(smallIsland3ID, 2.0);
	rmSetAreaSmoothDistance(smallIsland3ID, 20);
	rmAddAreaToClass(smallIsland3ID, classIsland);
	rmAddAreaConstraint(smallIsland3ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIsland3ID, false);
	rmSetAreaElevationType(smallIsland3ID, cElevTurbulence);
  rmAddAreaConstraint(smallIsland3ID, islandAvoidTradeRoute);
	rmSetAreaElevationVariation(smallIsland3ID, 3.0);
	rmSetAreaElevationMinFrequency(smallIsland3ID, 0.09);
	rmSetAreaElevationOctaves(smallIsland3ID, 3);
	rmSetAreaElevationPersistence(smallIsland3ID, 0.2);
	rmSetAreaElevationNoiseBias(smallIsland3ID, 1);
  rmAddAreaConstraint(smallIsland3ID, islandConstraint);
  rmSetAreaLocation(smallIsland3ID, .5, .5);

  rmSetAreaMix(smallIsland3ID, baseMix);
        rmAddAreaTerrainLayer(smallIsland3ID, "borneo\ground_sand1_borneo", 0, 4);
        rmAddAreaTerrainLayer(smallIsland3ID, "borneo\ground_sand2_borneo", 4, 6);
        rmAddAreaTerrainLayer(smallIsland3ID, "borneo\ground_sand3_borneo", 6, 9);
        rmAddAreaTerrainLayer(smallIsland3ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaToClass(smallIsland3ID, classAfIsland);
  
  rmBuildArea(smallIsland3ID);


  int nativeIslandConstraint=rmCreateAreaConstraint("native Island", smallIslandID);


  int playerIsland1ID=rmCreateArea("player island 1");
    rmSetAreaLocation(playerIsland1ID, .8, .8);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland1ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland1ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland1ID, classIsland);
    rmAddAreaToClass(playerIsland1ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland1ID, false);
	  rmSetAreaCoherence(playerIsland1ID, 0.5);
    rmSetAreaBaseHeight(playerIsland1ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland1ID, 20);
    rmSetAreaMix(playerIsland1ID, baseMix);
      rmAddAreaTerrainLayer(playerIsland1ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland1ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland1ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland1ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland1ID, islandConstraint);
    rmAddAreaConstraint(playerIsland1ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland1ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland1ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland1ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland1ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland1ID, 3);
    rmSetAreaElevationPersistence(playerIsland1ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland1ID, 1);
    rmBuildArea(playerIsland1ID);

  

    int playerIsland2ID=rmCreateArea("player island 2");
    rmSetAreaLocation(playerIsland2ID, .2, .8);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland2ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland2ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland2ID, classIsland);
    rmAddAreaToClass(playerIsland2ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland2ID, false);
	  rmSetAreaCoherence(playerIsland2ID, 0.5);
    rmSetAreaBaseHeight(playerIsland2ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland2ID, 20);
    rmSetAreaMix(playerIsland2ID, baseMix);
      rmAddAreaTerrainLayer(playerIsland2ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland2ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland2ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland2ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland2ID, islandConstraint);
    rmAddAreaConstraint(playerIsland2ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland2ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland2ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland2ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland2ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland2ID, 3);
    rmSetAreaElevationPersistence(playerIsland2ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland2ID, 1);	
    rmBuildArea(playerIsland2ID);


    int playerIsland3ID=rmCreateArea("player island 3");
    rmSetAreaLocation(playerIsland3ID, .2, .2);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland3ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland3ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland3ID, classIsland);
    rmAddAreaToClass(playerIsland3ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland3ID, false);
	  rmSetAreaCoherence(playerIsland3ID, 0.5);
    rmSetAreaBaseHeight(playerIsland3ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland3ID, 20);
    rmSetAreaMix(playerIsland3ID, paintMix);
      rmAddAreaTerrainLayer(playerIsland3ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland3ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland3ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland3ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland3ID, islandConstraint);
    rmAddAreaConstraint(playerIsland3ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland3ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland3ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland3ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland3ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland3ID, 3);
    rmSetAreaElevationPersistence(playerIsland3ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland3ID, 1);  	
    rmBuildArea(playerIsland3ID);

    int playerIsland4ID=rmCreateArea("player island 4");
    rmSetAreaLocation(playerIsland4ID, .8, .2);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland4ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland4ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland4ID, classIsland);
    rmAddAreaToClass(playerIsland4ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland4ID, false);
	  rmSetAreaCoherence(playerIsland4ID, 0.5);
    rmSetAreaBaseHeight(playerIsland4ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland4ID, 20);
    rmSetAreaMix(playerIsland4ID, paintMix);
      rmAddAreaTerrainLayer(playerIsland4ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland4ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland4ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland4ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland4ID, islandConstraint);
    rmAddAreaConstraint(playerIsland4ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland4ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland4ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland4ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland4ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland4ID, 3);
    rmSetAreaElevationPersistence(playerIsland4ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland4ID, 1);  	
    rmBuildArea(playerIsland4ID);

    int playerIsland5ID=rmCreateArea("player island 5");
    rmSetAreaLocation(playerIsland5ID, .8, .5);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland5ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland5ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland5ID, classIsland);
    rmAddAreaToClass(playerIsland5ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland5ID, false);
	  rmSetAreaCoherence(playerIsland5ID, 0.5);
    rmSetAreaBaseHeight(playerIsland5ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland5ID, 20);
    rmSetAreaMix(playerIsland5ID, paintMix);
      rmAddAreaTerrainLayer(playerIsland5ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland5ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland5ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland5ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland5ID, islandConstraint);
    rmAddAreaConstraint(playerIsland5ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland5ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland5ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland5ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland5ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland5ID, 3);
    rmSetAreaElevationPersistence(playerIsland5ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland5ID, 1);  	
    rmBuildArea(playerIsland5ID);


  int playerIsland6ID=rmCreateArea("player island 6");
    rmSetAreaLocation(playerIsland6ID, .2, .5);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland6ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland6ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland6ID, classIsland);
    rmAddAreaToClass(playerIsland6ID, classAfIsland);
    rmSetAreaWarnFailure(playerIsland6ID, false);
	  rmSetAreaCoherence(playerIsland6ID, 0.5);
    rmSetAreaBaseHeight(playerIsland6ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland6ID, 20);
    rmSetAreaMix(playerIsland6ID, paintMix);
      rmAddAreaTerrainLayer(playerIsland6ID, "borneo\ground_sand1_borneo", 0, 4);
      rmAddAreaTerrainLayer(playerIsland6ID, "borneo\ground_sand2_borneo", 4, 6);
      rmAddAreaTerrainLayer(playerIsland6ID, "borneo\ground_sand3_borneo", 6, 9);
      rmAddAreaTerrainLayer(playerIsland6ID, "borneo\ground_grass4_borneo", 9, 12);
    rmAddAreaConstraint(playerIsland6ID, islandConstraint);
    rmAddAreaConstraint(playerIsland6ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland6ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland6ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland6ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland6ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland6ID, 3);
    rmSetAreaElevationPersistence(playerIsland6ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland6ID, 1);  	
    rmBuildArea(playerIsland6ID);

// NATIVES
  
// Place Controllers
int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID1, 0.0);
rmSetObjectDefMaxDistance(controllerID1, 30.0);
rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID1, ferryOnShore); 
rmAddObjectDefConstraint(controllerID1, avoidEurope); 
rmAddObjectDefConstraint(controllerID1, avoidAtol); 

int controllerID2 = rmCreateObjectDef("Controler 2");
rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID2, 0.0);
rmSetObjectDefMaxDistance(controllerID2, 30.0);
rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID2, ferryOnShore); 
rmAddObjectDefConstraint(controllerID2, avoidEurope); 
rmAddObjectDefConstraint(controllerID2, avoidAtol); 

int controllerID3 = rmCreateObjectDef("Controler 3");
rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID3, 0.0);
rmSetObjectDefMaxDistance(controllerID3, 30.0);
rmAddObjectDefConstraint(controllerID3, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID3, ferryOnShore); 
rmAddObjectDefConstraint(controllerID3, avoidEurope); 
rmAddObjectDefConstraint(controllerID3, avoidAtol); 

int controllerID4 = rmCreateObjectDef("Controler 4");
rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID4, 0.0);
rmSetObjectDefMaxDistance(controllerID4, 30.0);
rmAddObjectDefConstraint(controllerID4, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID4, ferryOnShore);
rmAddObjectDefConstraint(controllerID4, avoidEurope); 
rmAddObjectDefConstraint(controllerID4, avoidAtol); 

int controllerID5 = rmCreateObjectDef("Controler 5");
rmAddObjectDefItem(controllerID5, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID5, 0.0);
rmSetObjectDefMaxDistance(controllerID5, 30.0);
rmAddObjectDefConstraint(controllerID5, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID5, ferryOnShore);
rmAddObjectDefConstraint(controllerID5, avoidAtol); 

      
rmPlaceObjectDefAtLoc(controllerID1, 0, 0.25, 0.28);
rmPlaceObjectDefAtLoc(controllerID2, 0, 0.75, 0.28);
rmPlaceObjectDefAtLoc(controllerID3, 0, 0.25, 0.72);
rmPlaceObjectDefAtLoc(controllerID4, 0, 0.75, 0.72);
rmPlaceObjectDefAtLoc(controllerID5, 0, 0.5, 0.58);

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));
vector ControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID5, 0));

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

      // Pirate Village 3

      int piratesVillageID3 = -1;
      piratesVillageID3 = rmCreateGrouping("pirate city 3", "Wokou_Village_01");
      rmSetGroupingMinDistance(piratesVillageID3, 0);
      rmSetGroupingMaxDistance(piratesVillageID3, 20);
      rmAddGroupingConstraint(piratesVillageID3, ferryOnShore);

      rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);
    
      int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
      rmAddObjectDefItem(piratewaterflagID3, "zpWokouWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

      rmClearClosestPointConstraints();

      int pirateportID3 = -1;
      pirateportID3 = rmCreateGrouping("pirate port 3", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage3a = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));
      
      rmClearClosestPointConstraints();

      // Pirate Village 4

      int piratesVillageID4 = -1;
      piratesVillageID4 = rmCreateGrouping("pirate city 4", "Wokou_Village_02");
      rmSetGroupingMinDistance(piratesVillageID4, 0);
      rmSetGroupingMaxDistance(piratesVillageID4, 20);
      rmAddGroupingConstraint(piratesVillageID4, ferryOnShore);

      rmPlaceGroupingAtLoc(piratesVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);
    
      int piratewaterflagID4 = rmCreateObjectDef("pirate water flag 4");
      rmAddObjectDefItem(piratewaterflagID4, "zpWokouWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage4 = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4)));

      rmClearClosestPointConstraints();

      int pirateportID4 = -1;
      pirateportID4 = rmCreateGrouping("pirate port 4", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage4a = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4a)));
      
      rmClearClosestPointConstraints();

      // Scientist Village

      int piratesVillageID5 = -1;
      piratesVillageID5 = rmCreateGrouping("pirate city 5", "Scientist_Lab05");
      rmSetGroupingMinDistance(piratesVillageID5, 0);
      rmSetGroupingMaxDistance(piratesVillageID5, 25);
      rmAddGroupingConstraint(piratesVillageID5, ferryOnShore20);

      rmPlaceGroupingAtLoc(piratesVillageID5, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc5)), 1);

      int piratewaterflagID5 = rmCreateObjectDef("pirate water flag 5");
      rmAddObjectDefItem(piratewaterflagID5, "zpNativeWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage5 = rmFindClosestPointVector(ControllerLoc5, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID5, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage5)), rmZMetersToFraction(xsVectorGetZ(closeToVillage5)));

      rmClearClosestPointConstraints();

      int pirateportID5 = -1;
      pirateportID5 = rmCreateGrouping("pirate port 5", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage5a = rmFindClosestPointVector(ControllerLoc5, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID5, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage5a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage5a)));

      rmClearClosestPointConstraints();
	


//*************************** NORTHERN VOLCANO **************************************


// ----------- Lava Flows ---------------------------------------------------------------------------------------

int lavaflowID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID);
if (cNumberNonGaiaPlayers == 4){
  rmAddTradeRouteWaypoint(lavaflowID, 0.5, 0.925);
  rmAddTradeRouteWaypoint(lavaflowID, 0.5+rmXTilesToFraction(10), 0.925);
}
else{
  rmAddTradeRouteWaypoint(lavaflowID, 0.5, 0.93);
  rmAddTradeRouteWaypoint(lavaflowID, 0.5+rmXTilesToFraction(10), 0.93);
}
bool placedLavaflowID = rmBuildTradeRoute(lavaflowID, "lava_flow");


int lavaflowID3 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID3);

if (cNumberNonGaiaPlayers == 4){
  rmAddTradeRouteWaypoint(lavaflowID3, 0.5, 0.925);
rmAddTradeRouteWaypoint(lavaflowID3, 0.5-rmXTilesToFraction(10), 0.925);
}
else{
  rmAddTradeRouteWaypoint(lavaflowID3, 0.5, 0.93);
rmAddTradeRouteWaypoint(lavaflowID3, 0.5-rmXTilesToFraction(10), 0.93);
}

bool placedLavaflowID3 = rmBuildTradeRoute(lavaflowID3, "lava_flow");

int stopperID=rmCreateObjectDef("Volceno Center 1");
rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID, true);
rmSetObjectDefMinDistance(stopperID, 0.0);
rmSetObjectDefMaxDistance(stopperID, 0.0);  

rmSetObjectDefTradeRouteID(stopperID, lavaflowID);
vector stopperLoc = rmGetTradeRouteWayPoint(lavaflowID, 0.01);
rmPlaceObjectDefAtPoint(stopperID, 0, stopperLoc);
vector volcanoLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));

    
// ------------------ Volcano Terrain -----------------------------------------------------------------------

// Level 2

int basecliffID2 = rmCreateArea("base cliff2");
if (cNumberNonGaiaPlayers <=3)
  rmSetAreaSize(basecliffID2, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
else
  rmSetAreaSize(basecliffID2, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
rmSetAreaWarnFailure(basecliffID2, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID2, false);		
rmSetAreaElevationVariation(basecliffID2, 4);
rmSetAreaCoherence(basecliffID2, .8);
rmSetAreaHeightBlend(basecliffID2, 0);
rmSetAreaCliffType(basecliffID2, "ZP Melanesia Medium");
rmSetAreaTerrainType(basecliffID2, "lava\volcano_borneo");
rmSetAreaCliffEdge(basecliffID2, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID2, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID2, 4, 0.1, 0.5);
rmSetAreaLocation(basecliffID2, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmAddAreaToClass(basecliffID2, classHighMountains);
rmAddAreaConstraint(basecliffID2, avoidKOTHshort);
//rmSetAreaReveal(basecliffID2, 1);
rmBuildArea(basecliffID2);

// Level 3

int fujiPeaklvl3 = rmCreateArea("fujiPeaklvl3");
rmSetAreaSize(fujiPeaklvl3, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
rmSetAreaLocation(fujiPeaklvl3, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiPeaklvl3, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeaklvl3, 10.0);
rmAddAreaConstraint(fujiPeaklvl3, avoidKOTHshort);
rmSetAreaHeightBlend(fujiPeaklvl3, 2.0);
rmSetAreaSmoothDistance(fujiPeaklvl3, 50);
rmSetAreaCoherence(fujiPeaklvl3, .7);
rmBuildArea(fujiPeaklvl3);  

int basecliffID31 = rmCreateArea("base cliff31");
rmSetAreaSize(basecliffID31, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffID31, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID31, false);		
rmSetAreaElevationVariation(basecliffID31, 5);
rmSetAreaCoherence(basecliffID31, .6);
rmSetAreaHeightBlend(basecliffID31, 0);
rmSetAreaCliffType(basecliffID31, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffID31, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID31, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID31, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID31, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID31, 14.0);
rmSetAreaLocation(basecliffID31, 0.5+rmXTilesToFraction(5), 0.93-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID31, avoidKOTHshort);
rmAddAreaConstraint(basecliffID31, cliffAvoidTradeRoute);
rmBuildArea(basecliffID31);

int basecliffID32 = rmCreateArea("base cliff32");
rmSetAreaSize(basecliffID32, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffID32, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID32, false);		
rmSetAreaElevationVariation(basecliffID32, 5);
rmSetAreaCoherence(basecliffID32, .6);
rmSetAreaHeightBlend(basecliffID32, 0);
rmSetAreaCliffType(basecliffID32, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffID32, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID32, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID32, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID32, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID32, 14.0);
rmSetAreaLocation(basecliffID32, 0.5-rmXTilesToFraction(5), 0.93-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID32, avoidKOTHshort);
rmAddAreaConstraint(basecliffID32, cliffAvoidTradeRoute);
rmBuildArea(basecliffID32);

int basecliffID33 = rmCreateArea("base cliff33");
rmSetAreaSize(basecliffID33, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffID33, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID33, false);		
rmSetAreaElevationVariation(basecliffID33, 5);
rmSetAreaCoherence(basecliffID33, .6);
rmSetAreaHeightBlend(basecliffID33, 0);
rmSetAreaCliffType(basecliffID33, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffID33, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID33, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID33, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID33, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID33, 14.0);
rmSetAreaLocation(basecliffID33, 0.5-rmXTilesToFraction(5), 0.93+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID33, avoidKOTHshort);
rmAddAreaConstraint(basecliffID33, cliffAvoidTradeRoute);
rmBuildArea(basecliffID33);

int basecliffID34 = rmCreateArea("base cliff34");
rmSetAreaSize(basecliffID34, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffID34, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID34, false);		
rmSetAreaElevationVariation(basecliffID34, 5);
rmSetAreaCoherence(basecliffID34, .6);
rmSetAreaHeightBlend(basecliffID34, 0);
rmSetAreaCliffType(basecliffID34, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffID34, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID34, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID34, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID34, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID34, 14.0);
rmSetAreaLocation(basecliffID34, 0.5+rmXTilesToFraction(5), 0.93+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID34, avoidKOTHshort);
rmAddAreaConstraint(basecliffID34, cliffAvoidTradeRoute);
rmBuildArea(basecliffID34);

// Level 4

int fujiPeaklvl4 = rmCreateArea("fujiPeaklvl4");
rmSetAreaSize(fujiPeaklvl4, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
rmSetAreaLocation(fujiPeaklvl4, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiPeaklvl4, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeaklvl4, 14.0);
rmSetAreaHeightBlend(fujiPeaklvl4, 2.0);
rmAddAreaConstraint(fujiPeaklvl4, avoidKOTHshort);
rmSetAreaSmoothDistance(fujiPeaklvl4, 40);
rmSetAreaCoherence(fujiPeaklvl4, .8);
rmBuildArea(fujiPeaklvl4);  

int basecliffID41 = rmCreateArea("base cliff41");
rmSetAreaSize(basecliffID41, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffID41, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID41, false);		
rmSetAreaElevationVariation(basecliffID41, 5);
rmSetAreaCoherence(basecliffID41, .6);
rmSetAreaHeightBlend(basecliffID41, 0);
rmSetAreaCliffType(basecliffID41, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID41, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID41, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID41, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID41, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID41, 18.0);
rmSetAreaElevationVariation(basecliffID41, 3);
rmSetAreaLocation(basecliffID41, 0.5+rmXTilesToFraction(5), 0.93-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID41, avoidKOTHshort);
rmAddAreaConstraint(basecliffID41, cliffAvoidTradeRoute);
rmBuildArea(basecliffID41);

int basecliffID42 = rmCreateArea("base cliff42");
rmSetAreaSize(basecliffID42, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffID42, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID42, false);		
rmSetAreaElevationVariation(basecliffID42, 5);
rmSetAreaCoherence(basecliffID42, .6);
rmSetAreaHeightBlend(basecliffID42, 0);
rmSetAreaCliffType(basecliffID42, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID42, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID42, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID42, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID42, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID42, 18.0);
rmSetAreaElevationVariation(basecliffID42, 3);
rmSetAreaLocation(basecliffID42, 0.5-rmXTilesToFraction(5), 0.93-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID42, avoidKOTHshort);
rmAddAreaConstraint(basecliffID42, cliffAvoidTradeRoute);
rmBuildArea(basecliffID42);

int basecliffID43 = rmCreateArea("base cliff43");
rmSetAreaSize(basecliffID43, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffID43, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID43, false);		
rmSetAreaElevationVariation(basecliffID43, 5);
rmSetAreaCoherence(basecliffID43, .6);
rmSetAreaHeightBlend(basecliffID43, 0);
rmSetAreaCliffType(basecliffID43, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID43, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID43, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID43, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID43, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID43, 18.0);
rmSetAreaElevationVariation(basecliffID43, 3);
rmSetAreaLocation(basecliffID43, 0.5-rmXTilesToFraction(5), 0.93+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID43, avoidKOTHshort);
rmAddAreaConstraint(basecliffID43, cliffAvoidTradeRoute);
rmBuildArea(basecliffID43);

int basecliffID44 = rmCreateArea("base cliff44");
rmSetAreaSize(basecliffID44, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffID44, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID44, false);		
rmSetAreaElevationVariation(basecliffID44, 5);
rmSetAreaCoherence(basecliffID44, .6);
rmSetAreaHeightBlend(basecliffID44, 0);
rmSetAreaCliffType(basecliffID44, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID44, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID44, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID44, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID44, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID44, 18.0);
rmSetAreaElevationVariation(basecliffID44, 3);
rmSetAreaLocation(basecliffID44, 0.5+rmXTilesToFraction(5), 0.93+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID44, avoidKOTHshort);
rmAddAreaConstraint(basecliffID44, cliffAvoidTradeRoute);
rmBuildArea(basecliffID44);

// Level 5

int fujiPeaklvl5 = rmCreateArea("fujiPeaklvl5");
rmSetAreaSize(fujiPeaklvl5, rmAreaTilesToFraction(380.0), rmAreaTilesToFraction(380.0));
rmSetAreaLocation(fujiPeaklvl5, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiPeaklvl5, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeaklvl5, 18.0);
rmAddAreaConstraint(fujiPeaklvl5, avoidKOTHshort);
rmSetAreaSmoothDistance(fujiPeaklvl5, 40);
rmSetAreaHeightBlend(fujiPeaklvl5, 2.0);
rmSetAreaCoherence(fujiPeaklvl5, .8);
rmBuildArea(fujiPeaklvl5); 

int basecliffID51 = rmCreateArea("base cliff51");
rmSetAreaSize(basecliffID51, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffID51, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID51, false);		
rmSetAreaElevationVariation(basecliffID51, 5);
rmSetAreaCoherence(basecliffID51, .6);
rmSetAreaHeightBlend(basecliffID51, 0);
rmSetAreaCliffType(basecliffID51, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID51, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID51, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID51, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID51, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID51, 22.0);
rmSetAreaElevationVariation(basecliffID51, 3);
rmSetAreaLocation(basecliffID51, 0.5+rmXTilesToFraction(3), 0.93-rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffID51, avoidKOTHshort);
rmAddAreaConstraint(basecliffID51, cliffAvoidTradeRoute);
rmBuildArea(basecliffID51);

int basecliffID52 = rmCreateArea("base cliff52");
rmSetAreaSize(basecliffID52, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffID52, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID52, false);		
rmSetAreaElevationVariation(basecliffID52, 5);
rmSetAreaCoherence(basecliffID52, .6);
rmSetAreaHeightBlend(basecliffID52, 0);
rmSetAreaCliffType(basecliffID52, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID52, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID52, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID52, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID52, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID52, 22.0);
rmSetAreaElevationVariation(basecliffID52, 3);
rmSetAreaLocation(basecliffID52, 0.5-rmXTilesToFraction(3), 0.93-rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffID52, avoidKOTHshort);
rmAddAreaConstraint(basecliffID52, cliffAvoidTradeRoute);
rmBuildArea(basecliffID52);

int basecliffID53 = rmCreateArea("base cliff23");
rmSetAreaSize(basecliffID53, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffID53, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID53, false);		
rmSetAreaElevationVariation(basecliffID53, 5);
rmSetAreaCoherence(basecliffID53, .6);
rmSetAreaHeightBlend(basecliffID53, 0);
rmSetAreaCliffType(basecliffID53, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID53, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID53, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID53, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID53, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID53, 22.0);
rmSetAreaElevationVariation(basecliffID53, 3);
rmSetAreaLocation(basecliffID53, 0.5-rmXTilesToFraction(3), 0.93+rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffID53, avoidKOTHshort);
rmAddAreaConstraint(basecliffID53, cliffAvoidTradeRoute);
rmBuildArea(basecliffID53);

int basecliffID54 = rmCreateArea("base cliff54");
rmSetAreaSize(basecliffID54, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffID54, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID54, false);		
rmSetAreaElevationVariation(basecliffID54, 5);
rmSetAreaCoherence(basecliffID54, .6);
rmSetAreaHeightBlend(basecliffID54, 0);
rmSetAreaCliffType(basecliffID54, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID54, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID54, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID54, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID54, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID54, 22.0);
rmSetAreaElevationVariation(basecliffID54, 3);
rmSetAreaLocation(basecliffID54, 0.5+rmXTilesToFraction(3), 0.93+rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffID54, avoidKOTHshort);
rmAddAreaConstraint(basecliffID54, cliffAvoidTradeRoute);
rmBuildArea(basecliffID54);

// Level 6

int fujiPeaklvl6 = rmCreateArea("fujiPeaklvl6");
rmSetAreaSize(fujiPeaklvl6, rmAreaTilesToFraction(100.0), rmAreaTilesToFraction(100.0));
rmSetAreaLocation(fujiPeaklvl6, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiPeaklvl6, "lava\crater");
rmSetAreaBaseHeight(fujiPeaklvl6, 22.0);
rmAddAreaConstraint(fujiPeaklvl6, avoidKOTHshort);
rmSetAreaCoherence(fujiPeaklvl6, .9);
rmBuildArea(fujiPeaklvl6);  

int fujiPeaklvl6Terrain = rmCreateArea("fujiPeaklvl6Terrain");
rmSetAreaSize(fujiPeaklvl6Terrain, rmAreaTilesToFraction(210.0), rmAreaTilesToFraction(210.0));
rmSetAreaLocation(fujiPeaklvl6Terrain, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiPeaklvl6Terrain, "lava\crater");
rmSetAreaCoherence(fujiPeaklvl6Terrain, 1.0);
rmBuildArea(fujiPeaklvl6Terrain);

int fujiDip = rmCreateArea("fujiDip");
rmSetAreaSize(fujiDip, rmAreaTilesToFraction(30.0), rmAreaTilesToFraction(30.0));
rmSetAreaLocation(fujiDip, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaCliffType(fujiDip, "ZP Hawaii Crater");
rmSetAreaCliffPainting(fujiDip, false, true, true, 1.5, false);
rmSetAreaCliffHeight(fujiDip, -5, 0.1, 0.5);
rmSetAreaCliffEdge(fujiDip, 1, 1.0, 0.0, 1.0, 0);
//rmSetAreaTerrainType(fujiDip, "lava\lavaflow");
rmSetAreaCoherence(fujiDip, 1.0);
rmBuildArea(fujiDip);

int fujiDipTerrain1 = rmCreateArea("fujiDipTerrain1");
rmSetAreaSize(fujiDipTerrain1, rmAreaTilesToFraction(30.0), rmAreaTilesToFraction(30.0));
rmSetAreaLocation(fujiDipTerrain1, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));
rmSetAreaTerrainType(fujiDipTerrain1, "lava\crater_passable");
rmSetAreaCoherence(fujiDipTerrain1, 1.0);
rmBuildArea(fujiDipTerrain1);  

int fujiDipTerrain = rmCreateArea("fujiDipTerrain");
rmSetAreaSize(fujiDipTerrain, rmAreaTilesToFraction(12.0), rmAreaTilesToFraction(12.0));
rmSetAreaLocation(fujiDipTerrain, 0.5-rmXTilesToFraction(1), 0.93);
rmSetAreaTerrainType(fujiDipTerrain, "lava\lavaflow");
rmSetAreaCoherence(fujiDipTerrain, 1.0);
rmBuildArea(fujiDipTerrain);



// ********************************* VOLCANO SOUTH **************************************************

int lavaflowID2 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID2);
rmAddTradeRouteWaypoint(lavaflowID2, 0.5, 0.07);
rmAddTradeRouteWaypoint(lavaflowID2, 0.5+rmXTilesToFraction(10), 0.07);

bool placedLavaflowID2 = rmBuildTradeRoute(lavaflowID2, "lava_flow");


int lavaflowID4 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID4);
rmAddTradeRouteWaypoint(lavaflowID4, 0.5, 0.07);
rmAddTradeRouteWaypoint(lavaflowID4, 0.5-rmXTilesToFraction(10), 0.07);

bool placedLavaflowID4 = rmBuildTradeRoute(lavaflowID4, "lava_flow");

int stopperID2=rmCreateObjectDef("Volceno Center 2");
rmAddObjectDefItem(stopperID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID2, true);
rmSetObjectDefMinDistance(stopperID2, 0.0);
rmSetObjectDefMaxDistance(stopperID2, 0.0);  

rmSetObjectDefTradeRouteID(stopperID, lavaflowID2);
vector stopperLoc2 = rmGetTradeRouteWayPoint(lavaflowID2, 0.01);
rmPlaceObjectDefAtPoint(stopperID2, 0, stopperLoc2);
vector volcanoLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));


// Level 2

int basecliffSoutID2 = rmCreateArea("base cliff south 2");
if (cNumberNonGaiaPlayers <=3)
  rmSetAreaSize(basecliffSoutID2, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
else
  rmSetAreaSize(basecliffSoutID2, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
rmSetAreaWarnFailure(basecliffSoutID2, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID2, false);		
rmSetAreaElevationVariation(basecliffSoutID2, 4);
rmSetAreaCoherence(basecliffSoutID2, .8);
rmSetAreaHeightBlend(basecliffSoutID2, 0);
rmSetAreaCliffType(basecliffSoutID2, "ZP Melanesia Medium");
rmSetAreaTerrainType(basecliffSoutID2, "lava\volcano_borneo");
rmSetAreaCliffEdge(basecliffSoutID2, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID2, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID2, 4, 0.1, 0.5);
rmSetAreaLocation(basecliffSoutID2, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmAddAreaToClass(basecliffSoutID2, classHighMountains);
rmAddAreaConstraint(basecliffSoutID2, avoidKOTHshort);
//rmSetAreaReveal(basecliffSoutID2, 1);
rmBuildArea(basecliffSoutID2);

// Level 3

int fujiPeakSouthlvl3 = rmCreateArea("fujiPeakSouthlvl3");
rmSetAreaSize(fujiPeakSouthlvl3, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
rmSetAreaLocation(fujiPeakSouthlvl3, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiPeakSouthlvl3, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeakSouthlvl3, 10.0);
rmAddAreaConstraint(fujiPeakSouthlvl3, avoidKOTHshort);
rmSetAreaSmoothDistance(fujiPeakSouthlvl3, 50);
rmSetAreaHeightBlend(fujiPeakSouthlvl3, 2.0);
rmSetAreaCoherence(fujiPeakSouthlvl3, .7);
rmBuildArea(fujiPeakSouthlvl3);  

int basecliffSoutID31 = rmCreateArea("base cliff south 31");
rmSetAreaSize(basecliffSoutID31, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffSoutID31, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID31, false);		
rmSetAreaElevationVariation(basecliffSoutID31, 5);
rmSetAreaCoherence(basecliffSoutID31, .6);
rmSetAreaHeightBlend(basecliffSoutID31, 0);
rmSetAreaCliffType(basecliffSoutID31, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffSoutID31, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID31, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID31, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID31, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID31, 14.0);
rmSetAreaLocation(basecliffSoutID31, 0.5+rmXTilesToFraction(5), 0.07-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID31, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID31, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID31);

int basecliffSoutID32 = rmCreateArea("base cliff south 32");
rmSetAreaSize(basecliffSoutID32, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffSoutID32, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID32, false);		
rmSetAreaElevationVariation(basecliffSoutID32, 5);
rmSetAreaCoherence(basecliffSoutID32, .6);
rmSetAreaHeightBlend(basecliffSoutID32, 0);
rmSetAreaCliffType(basecliffSoutID32, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffSoutID32, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID32, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID32, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID32, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID32, 14.0);
rmSetAreaLocation(basecliffSoutID32, 0.5-rmXTilesToFraction(5), 0.07-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID32, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID32, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID32);

int basecliffSoutID33 = rmCreateArea("base cliff south 33");
rmSetAreaSize(basecliffSoutID33, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffSoutID33, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID33, false);		
rmSetAreaElevationVariation(basecliffSoutID33, 5);
rmSetAreaCoherence(basecliffSoutID33, .6);
rmSetAreaHeightBlend(basecliffSoutID33, 0);
rmSetAreaCliffType(basecliffSoutID33, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffSoutID33, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID33, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID33, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID33, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID33, 14.0);
rmSetAreaLocation(basecliffSoutID33, 0.5-rmXTilesToFraction(5), 0.07+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID33, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID33, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID33);

int basecliffSoutID34 = rmCreateArea("base cliff south34");
rmSetAreaSize(basecliffSoutID34, rmAreaTilesToFraction(140.0), rmAreaTilesToFraction(140.0));
rmSetAreaWarnFailure(basecliffSoutID34, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID34, false);		
rmSetAreaElevationVariation(basecliffSoutID34, 5);
rmSetAreaCoherence(basecliffSoutID34, .6);
rmSetAreaHeightBlend(basecliffSoutID34, 0);
rmSetAreaCliffType(basecliffSoutID34, "ZP Melanesia High 2");
rmSetAreaTerrainType(basecliffSoutID34, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID34, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID34, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID34, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID34, 14.0);
rmSetAreaLocation(basecliffSoutID34, 0.5+rmXTilesToFraction(5), 0.07+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID34, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID34, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID34);

// Level 4

int fujiPeakSouthlvl4 = rmCreateArea("fujiPeakSouthlvl4");
rmSetAreaSize(fujiPeakSouthlvl4, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
rmSetAreaLocation(fujiPeakSouthlvl4, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiPeakSouthlvl4, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeakSouthlvl4, 14.0);
rmAddAreaConstraint(fujiPeakSouthlvl4, avoidKOTHshort);
rmSetAreaSmoothDistance(fujiPeakSouthlvl4, 40);
rmSetAreaHeightBlend(fujiPeakSouthlvl4, 2.0);
rmSetAreaCoherence(fujiPeakSouthlvl4, .8);
rmBuildArea(fujiPeakSouthlvl4);  

int basecliffSoutID41 = rmCreateArea("base cliff south41");
rmSetAreaSize(basecliffSoutID41, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffSoutID41, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID41, false);		
rmSetAreaElevationVariation(basecliffSoutID41, 5);
rmSetAreaCoherence(basecliffSoutID41, .6);
rmSetAreaHeightBlend(basecliffSoutID41, 0);
rmSetAreaCliffType(basecliffSoutID41, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID41, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID41, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID41, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID41, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID41, 18.0);
rmSetAreaElevationVariation(basecliffSoutID41, 3);
rmSetAreaLocation(basecliffSoutID41, 0.5+rmXTilesToFraction(5), 0.07-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID41, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID41, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID41);

int basecliffSoutID42 = rmCreateArea("base cliff south42");
rmSetAreaSize(basecliffSoutID42, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffSoutID42, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID42, false);		
rmSetAreaElevationVariation(basecliffSoutID42, 5);
rmSetAreaCoherence(basecliffSoutID42, .6);
rmSetAreaHeightBlend(basecliffSoutID42, 0);
rmSetAreaCliffType(basecliffSoutID42, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID42, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID42, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID42, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID42, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID42, 18.0);
rmSetAreaElevationVariation(basecliffSoutID42, 3);
rmSetAreaLocation(basecliffSoutID42, 0.5-rmXTilesToFraction(5), 0.07-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID42, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID42, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID42);

int basecliffSoutID43 = rmCreateArea("base cliff south43");
rmSetAreaSize(basecliffSoutID43, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffSoutID43, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID43, false);		
rmSetAreaElevationVariation(basecliffSoutID43, 5);
rmSetAreaCoherence(basecliffSoutID43, .6);
rmSetAreaHeightBlend(basecliffSoutID43, 0);
rmSetAreaCliffType(basecliffSoutID43, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID43, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID43, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID43, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID43, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID43, 18.0);
rmSetAreaElevationVariation(basecliffSoutID43, 3);
rmSetAreaLocation(basecliffSoutID43, 0.5-rmXTilesToFraction(5), 0.07+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID43, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID43, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID43);

int basecliffSoutID44 = rmCreateArea("base cliff south44");
rmSetAreaSize(basecliffSoutID44, rmAreaTilesToFraction(40.0), rmAreaTilesToFraction(40.0));
rmSetAreaWarnFailure(basecliffSoutID44, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID44, false);		
rmSetAreaElevationVariation(basecliffSoutID44, 5);
rmSetAreaCoherence(basecliffSoutID44, .6);
rmSetAreaHeightBlend(basecliffSoutID44, 0);
rmSetAreaCliffType(basecliffSoutID44, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID44, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID44, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID44, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID44, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID44, 18.0);
rmSetAreaElevationVariation(basecliffSoutID44, 3);
rmSetAreaLocation(basecliffSoutID44, 0.5+rmXTilesToFraction(5), 0.07+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffSoutID44, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID44, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID44);

// Level 5

int fujiPeakSouthlvl5 = rmCreateArea("fujiPeakSouthlvl5");
rmSetAreaSize(fujiPeakSouthlvl5, rmAreaTilesToFraction(380.0), rmAreaTilesToFraction(380.0));
rmSetAreaLocation(fujiPeakSouthlvl5, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiPeakSouthlvl5, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeakSouthlvl5, 18.0);
rmAddAreaConstraint(fujiPeakSouthlvl5, avoidKOTHshort);
rmSetAreaSmoothDistance(fujiPeakSouthlvl5, 40);
rmSetAreaHeightBlend(fujiPeakSouthlvl5, 2.0);
rmSetAreaCoherence(fujiPeakSouthlvl5, .8);
rmBuildArea(fujiPeakSouthlvl5); 

int basecliffSoutID51 = rmCreateArea("base cliff south51");
rmSetAreaSize(basecliffSoutID51, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffSoutID51, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID51, false);		
rmSetAreaElevationVariation(basecliffSoutID51, 5);
rmSetAreaCoherence(basecliffSoutID51, .6);
rmSetAreaHeightBlend(basecliffSoutID51, 0);
rmSetAreaCliffType(basecliffSoutID51, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID51, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID51, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID51, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID51, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID51, 22.0);
rmSetAreaElevationVariation(basecliffSoutID51, 3);
rmSetAreaLocation(basecliffSoutID51, 0.5+rmXTilesToFraction(3), 0.07-rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffSoutID51, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID51, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID51);

int basecliffSoutID52 = rmCreateArea("base cliff south52");
rmSetAreaSize(basecliffSoutID52, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffSoutID52, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID52, false);		
rmSetAreaElevationVariation(basecliffSoutID52, 5);
rmSetAreaCoherence(basecliffSoutID52, .6);
rmSetAreaHeightBlend(basecliffSoutID52, 0);
rmSetAreaCliffType(basecliffSoutID52, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID52, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID52, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID52, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID52, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID52, 22.0);
rmSetAreaElevationVariation(basecliffSoutID52, 3);
rmSetAreaLocation(basecliffSoutID52, 0.5-rmXTilesToFraction(3), 0.07-rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffSoutID52, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID52, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID52);

int basecliffSoutID53 = rmCreateArea("base cliff south23");
rmSetAreaSize(basecliffSoutID53, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffSoutID53, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID53, false);		
rmSetAreaElevationVariation(basecliffSoutID53, 5);
rmSetAreaCoherence(basecliffSoutID53, .6);
rmSetAreaHeightBlend(basecliffSoutID53, 0);
rmSetAreaCliffType(basecliffSoutID53, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID53, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID53, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID53, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID53, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID53, 22.0);
rmSetAreaElevationVariation(basecliffSoutID53, 3);
rmSetAreaLocation(basecliffSoutID53, 0.5-rmXTilesToFraction(3), 0.07+rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffSoutID53, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID53, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID53);

int basecliffSoutID54 = rmCreateArea("base cliff south54");
rmSetAreaSize(basecliffSoutID54, rmAreaTilesToFraction(17.0), rmAreaTilesToFraction(17.0));
rmSetAreaWarnFailure(basecliffSoutID54, false);
rmSetAreaObeyWorldCircleConstraint(basecliffSoutID54, false);		
rmSetAreaElevationVariation(basecliffSoutID54, 5);
rmSetAreaCoherence(basecliffSoutID54, .6);
rmSetAreaHeightBlend(basecliffSoutID54, 0);
rmSetAreaCliffType(basecliffSoutID54, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffSoutID54, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffSoutID54, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffSoutID54, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffSoutID54, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffSoutID54, 22.0);
rmSetAreaElevationVariation(basecliffSoutID54, 3);
rmSetAreaLocation(basecliffSoutID54, 0.5+rmXTilesToFraction(3), 0.07+rmXTilesToFraction(3));
rmAddAreaConstraint(basecliffSoutID54, avoidKOTHshort);
rmAddAreaConstraint(basecliffSoutID54, cliffAvoidTradeRoute);
rmBuildArea(basecliffSoutID54);

// Level 6

int fujiPeakSouthlvl6 = rmCreateArea("fujiPeakSouthlvl6");
rmSetAreaSize(fujiPeakSouthlvl6, rmAreaTilesToFraction(100.0), rmAreaTilesToFraction(100.0));
rmSetAreaLocation(fujiPeakSouthlvl6, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiPeakSouthlvl6, "lava\crater");
rmSetAreaBaseHeight(fujiPeakSouthlvl6, 22.0);
rmAddAreaConstraint(fujiPeakSouthlvl6, avoidKOTHshort);
rmSetAreaCoherence(fujiPeakSouthlvl6, .9);
rmBuildArea(fujiPeakSouthlvl6);  

int fujiPeakSouthlvl6Terrain = rmCreateArea("fujiPeakSouthlvl6Terrain");
rmSetAreaSize(fujiPeakSouthlvl6Terrain, rmAreaTilesToFraction(210.0), rmAreaTilesToFraction(210.0));
rmSetAreaLocation(fujiPeakSouthlvl6Terrain, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiPeakSouthlvl6Terrain, "lava\crater");
rmSetAreaCoherence(fujiPeakSouthlvl6Terrain, 1.0);
rmBuildArea(fujiPeakSouthlvl6Terrain);

int fujiDipSouth = rmCreateArea("fujiDipSouth");
rmSetAreaSize(fujiDipSouth, rmAreaTilesToFraction(30.0), rmAreaTilesToFraction(30.0));
rmSetAreaLocation(fujiDipSouth, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaCliffType(fujiDipSouth, "ZP Hawaii Crater");
rmSetAreaCliffPainting(fujiDipSouth, false, true, true, 1.5, false);
rmSetAreaCliffHeight(fujiDipSouth, -5, 0.1, 0.5);
rmSetAreaCliffEdge(fujiDipSouth, 1, 1.0, 0.0, 1.0, 0);
//rmSetAreaTerrainType(fujiDipSouth, "lava\lavaflow");
rmSetAreaCoherence(fujiDipSouth, 1.0);
rmBuildArea(fujiDipSouth);

int fujiDipSouthTerrain1 = rmCreateArea("fujiDipSouthTerrain1");
rmSetAreaSize(fujiDipSouthTerrain1, rmAreaTilesToFraction(30.0), rmAreaTilesToFraction(30.0));
rmSetAreaLocation(fujiDipSouthTerrain1, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));
rmSetAreaTerrainType(fujiDipSouthTerrain1, "lava\crater_passable");
rmSetAreaCoherence(fujiDipSouthTerrain1, 1.0);
rmBuildArea(fujiDipSouthTerrain1);  

int fujiDipSouthTerrain = rmCreateArea("fujiDipSouthTerrain");
rmSetAreaSize(fujiDipSouthTerrain, rmAreaTilesToFraction(12.0), rmAreaTilesToFraction(12.0));
rmSetAreaLocation(fujiDipSouthTerrain, 0.5-rmXTilesToFraction(1), 0.07);
rmSetAreaTerrainType(fujiDipSouthTerrain, "lava\lavaflow");
rmSetAreaCoherence(fujiDipSouthTerrain, 1.0);
rmBuildArea(fujiDipSouthTerrain);


// ------------------ Volcano Craters ---------------------------------------------------------------

// Crater 1

int volcanoCraterID = -1;
volcanoCraterID = rmCreateGrouping("crater", "volcano_crater_small_A");
rmPlaceGroupingAtLoc(volcanoCraterID, 1, 0.5-rmXTilesToFraction(1.0), rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1), 1);
rmSetGroupingMinDistance(volcanoCraterID, 0);
rmSetGroupingMaxDistance(volcanoCraterID, 0);

int volcanoAvoider = rmCreateObjectDef("ai avoider"); 
if (cNumberNonGaiaPlayers <= 2)
    rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderS", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 4)
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderM", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 6)
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderL", 1, 0.0);
else
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderXL", 1, 0.0);

 rmPlaceObjectDefAtLoc(volcanoAvoider, 0, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc1))+rmZTilesToFraction(1));

// Crater 2

int volcanoCraterID2 = -1;
volcanoCraterID2 = rmCreateGrouping("crater2", "volcano_crater_small_B");
rmPlaceGroupingAtLoc(volcanoCraterID2, 1, 0.5-rmXTilesToFraction(1.0), rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)), 1);

int volcanoAvoider2 = rmCreateObjectDef("ai avoider2"); 
if (cNumberNonGaiaPlayers <= 2)
    rmAddObjectDefItem(volcanoAvoider2, "zpVolcanoAvoiderS", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 4)
rmAddObjectDefItem(volcanoAvoider2, "zpVolcanoAvoiderM", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 6)
rmAddObjectDefItem(volcanoAvoider2, "zpVolcanoAvoiderL", 1, 0.0);
else
rmAddObjectDefItem(volcanoAvoider2, "zpVolcanoAvoiderXL", 1, 0.0);
rmPlaceObjectDefAtLoc(volcanoAvoider2, 0, 0.5, rmZMetersToFraction(xsVectorGetZ(volcanoLoc2)));


	//==========KotH==============

// check for KOTH game mode
if(rmGetIsKOTH()) {

    float xLoc = 0.5;
    float yLoc = 0.5;
    float walk = 0.00;

    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
    rmEchoInfo("XLOC = "+xLoc);
    rmEchoInfo("XLOC = "+yLoc);
}


// Port Sites

   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.05+rmXTilesToFraction(22), 0.5);
   rmSetAreaMix(portSite1, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 2.5);
   rmAddAreaToClass(portSite1, classPortSite);
   rmBuildArea(portSite1);


   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.05+rmXTilesToFraction(22),0.2);
   rmSetAreaMix(portSite2, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 2.5);
   rmAddAreaToClass(portSite2, classPortSite);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaMix(portSite3, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.5);
   rmAddAreaToClass(portSite3, classPortSite);
  rmSetAreaLocation(portSite3, 0.05+rmXTilesToFraction(22),0.8);
  rmBuildArea(portSite3);

  int portSite4 = rmCreateArea ("port_site4");
  rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmSetAreaLocation(portSite4, 0.95-rmXTilesToFraction(22), 0.5);
  else
    rmSetAreaLocation(portSite4, 0.95-rmXTilesToFraction(25), 0.5);
  rmSetAreaMix(portSite4, "Caribbean Ground 3");
  rmSetAreaCoherence(portSite4, 1);
  rmSetAreaSmoothDistance(portSite4, 15);
  rmSetAreaBaseHeight(portSite4, 2.5);
  rmAddAreaToClass(portSite4, classPortSite);
  rmBuildArea(portSite4);

  int portSite5 = rmCreateArea ("port_site5");
  rmSetAreaSize(portSite5, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmSetAreaLocation(portSite5, 0.95-rmXTilesToFraction(22), 0.2);
  else
    rmSetAreaLocation(portSite5, 0.95-rmXTilesToFraction(25), 0.2);
  rmSetAreaMix(portSite5, "Caribbean Ground 3");
  rmSetAreaCoherence(portSite5, 1);
  rmSetAreaSmoothDistance(portSite5, 15);
  rmSetAreaBaseHeight(portSite5, 2.5);
  rmAddAreaToClass(portSite5, classPortSite);
  rmBuildArea(portSite5);

  int portSite6 = rmCreateArea ("port_site6");
  rmSetAreaSize(portSite6, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmSetAreaLocation(portSite6, 0.95-rmXTilesToFraction(22), 0.8);
  else
    rmSetAreaLocation(portSite6, 0.95-rmXTilesToFraction(25), 0.8);
  rmSetAreaMix(portSite6, "Caribbean Ground 3");
  rmSetAreaCoherence(portSite6, 1);
  rmSetAreaSmoothDistance(portSite6, 15);
  rmSetAreaBaseHeight(portSite6, 2.5);
  rmAddAreaToClass(portSite6, classPortSite);
  rmBuildArea(portSite6);

      // Port 1
  int portID01 = rmCreateObjectDef("port 02");
  portID01 = rmCreateGrouping("portG 01", "harbour_universal_SW");
  rmPlaceGroupingAtLoc(portID01, 0, 0.05+rmXTilesToFraction(9), 0.2);

   // Port 4
  int portID04 = rmCreateObjectDef("port 04");
  portID04 = rmCreateGrouping("portG 04", "harbour_universal_NE");
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmPlaceGroupingAtLoc(portID04, 0, 0.95-rmXTilesToFraction(9), 0.8);
  else
    rmPlaceGroupingAtLoc(portID04, 0, 0.95-rmXTilesToFraction(12), 0.8);

  // Port 2
  int portID02 = rmCreateObjectDef("port 02");
  portID02 = rmCreateGrouping("portG 02", "harbour_universal_SW");
  rmPlaceGroupingAtLoc(portID02, 0, 0.05+rmXTilesToFraction(9), 0.5);

  // Port 3
  int portID03 = rmCreateObjectDef("port 03");
  portID03 = rmCreateGrouping("portG 03", "harbour_universal_SW");
  rmPlaceGroupingAtLoc(portID03, 0, 0.05+rmXTilesToFraction(9), 0.8);

  // Port 5
  int portID05 = rmCreateObjectDef("port 05");
  portID05 = rmCreateGrouping("portG 05", "harbour_universal_NE");
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmPlaceGroupingAtLoc(portID05, 0, 0.95-rmXTilesToFraction(9), 0.2);
  else
    rmPlaceGroupingAtLoc(portID05, 0, 0.95-rmXTilesToFraction(12), 0.2);

  // Port 6
  int portID06 = rmCreateObjectDef("port 06");
  portID06 = rmCreateGrouping("portG 06", "harbour_universal_NE");
  if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6)
    rmPlaceGroupingAtLoc(portID06, 0, 0.95-rmXTilesToFraction(9), 0.5);
  else
    rmPlaceGroupingAtLoc(portID06, 0, 0.95-rmXTilesToFraction(12), 0.5);
    

  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);
  
	// ADDITIONAL NATIVES

  /*int maori2VillageID = -1;
  maori2VillageID = rmCreateGrouping("maori2 city", "maori_tropic_01");
  rmAddGroupingConstraint(maori2VillageID, avoidTCLong);
  rmAddGroupingConstraint(maori2VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(maori2VillageID, avoidMaoriLong);
  rmAddGroupingConstraint(maori2VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(maori2VillageID, avoidWater20);
  rmPlaceGroupingInArea(maori2VillageID, 0, smallIsland2ID, 1);

  int maori4VillageID = -1;
  maori4VillageID = rmCreateGrouping("maori4 city", "maori_tropic_02");
  rmAddGroupingConstraint(maori4VillageID, avoidTCLong);
  rmAddGroupingConstraint(maori4VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(maori4VillageID, avoidMaoriLong);
  rmAddGroupingConstraint(maori4VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(maori4VillageID, avoidWater20);
  rmPlaceGroupingInArea(maori4VillageID, 0, smallIsland2ID, 1);*/


  int korowai2VillageID = -1;
  int korowai2VillageType = rmRandInt(1,5);
  korowai2VillageID = rmCreateGrouping("korowai2 city", "korowai_village_0"+korowai2VillageType);
  rmAddGroupingConstraint(korowai2VillageID, avoidTCLong);
  rmAddGroupingConstraint(korowai2VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(korowai2VillageID, avoidkorowaiLong);
  rmAddGroupingConstraint(korowai2VillageID, avoidHighMountainsFar);
  if (cNumberNonGaiaPlayers>=4)
    rmAddGroupingConstraint(korowai2VillageID, avoidWater20);
  rmPlaceGroupingInArea(korowai2VillageID, 0, smallIslandID, 1);

  int korowai4VillageID = -1;
  int korowai4VillageType = rmRandInt(1,5);
  korowai4VillageID = rmCreateGrouping("korowai4 city", "korowai_village_0"+korowai4VillageType);
  rmAddGroupingConstraint(korowai4VillageID, avoidTCLong);
  rmAddGroupingConstraint(korowai4VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(korowai4VillageID, avoidkorowaiLong);
  rmAddGroupingConstraint(korowai4VillageID, avoidHighMountainsFar);
  if (cNumberNonGaiaPlayers>=4)
    rmAddGroupingConstraint(korowai4VillageID, avoidWater20);
  rmPlaceGroupingInArea(korowai4VillageID, 0, smallIslandID, 1);


  int jesuit2VillageID = -1;
  int jesuit2VillageType = rmRandInt(1,3);
  jesuit2VillageID = rmCreateGrouping("jesuit2 city", "Jesuit_Cathedral_Tropic_0"+jesuit2VillageType);
  rmAddGroupingConstraint(jesuit2VillageID, avoidTCLong);
  rmAddGroupingConstraint(jesuit2VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(jesuit2VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(jesuit2VillageID, avoidJesuitLong);
  if (cNumberNonGaiaPlayers>=4)
    rmAddGroupingConstraint(jesuit2VillageID, avoidWater20);
  rmPlaceGroupingInArea(jesuit2VillageID, 0, smallIsland2ID, 1);

  int jesuit4VillageID = -1;
  int jesuit4VillageType = rmRandInt(1,3);
  jesuit4VillageID = rmCreateGrouping("jesuit4 city", "Jesuit_Cathedral_Tropic_0"+jesuit4VillageType);
  rmAddGroupingConstraint(jesuit4VillageID, avoidTCLong);
  rmAddGroupingConstraint(jesuit4VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(jesuit4VillageID, avoidHighMountainsFar);
  if (cNumberNonGaiaPlayers>=4)
    rmAddGroupingConstraint(jesuit4VillageID, avoidWater20);
  rmAddGroupingConstraint(jesuit4VillageID, avoidJesuitLong);
  rmPlaceGroupingInArea(jesuit4VillageID, 0, smallIsland2ID, 1);

  /*int jesuit1VillageID = -1;
  int jesuit1VillageType = rmRandInt(1,3);
  jesuit1VillageID = rmCreateGrouping("jesuit1 city", "Jesuit_Cathedral_Tropic_0"+jesuit1VillageType);
  rmAddGroupingConstraint(jesuit1VillageID, avoidTCLong);
  rmAddGroupingConstraint(jesuit1VillageID, avoidImpassableLand);
  rmAddGroupingConstraint(jesuit1VillageID, avoidHighMountainsFar);
  rmAddGroupingConstraint(jesuit1VillageID, avoidWater20);
  rmPlaceGroupingInArea(jesuit1VillageID, 0, playerIsland6ID, 1);*/



      




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

  // Fake Frouping to fix the auto-grouping TC bug
  int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
  rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
  rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.4, 0.4);

	for(i=1; <cNumberPlayers) {

    int colonyShipID=rmCreateObjectDef("colony ship 2"+i);
    rmAddObjectDefItem(colonyShipID, "ypWokouJunk", 1, 0.0);
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




  // check for KOTH game mode
      if(rmGetIsKOTH()) {
        
        int kothID = rmCreateObjectDef("koth castle");
        rmAddObjectDefItem(kothID, "ypKingsHill", 1, 0);
        rmSetObjectDefMinDistance(kothID, 0.0);
        rmSetObjectDefMaxDistance(kothID, rmXFractionToMeters(0.3));
        rmAddObjectDefConstraint(kothID, avoidAll);
        rmAddObjectDefConstraint(kothID, avoidWater20);
        rmAddObjectDefConstraint(kothID, shortAvoidImpassableLand);
        rmAddObjectDefConstraint(kothID, avoidImportantItem);
        rmAddObjectDefConstraint(kothID, playerEdgeConstraint);
        rmAddAreaConstraint(kothID, avoidJesuit);
        rmAddObjectDefConstraint(kothID, avoidController);
        rmAddObjectDefConstraint(kothID, avoidTP);

          rmPlaceObjectDefInArea(kothID, 0, smallIsland3ID, 1);

      }


	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
  int forestTreeID = 0;
  numTries=6*cNumberNonGaiaPlayers;
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
    rmAddAreaConstraint(forest, avoidWater12);
    rmAddAreaConstraint(forest, avoidWokou);
    rmAddAreaConstraint(forest, avoidKorowai);
    rmAddAreaConstraint(forest, avoidMaori);
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
  numTries=9*cNumberNonGaiaPlayers;
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
    rmAddAreaConstraint(forest2, avoidWokou);
    rmAddAreaConstraint(forest2, avoidKorowai);
    rmAddAreaConstraint(forest2, avoidMaori);
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
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
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
	rmPlaceObjectDefInArea(goldID, 0, smallIslandID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(goldID, 0, smallIsland2ID, cNumberNonGaiaPlayers/2);

  int silverID = rmCreateObjectDef("random silver");
	rmAddObjectDefItem(silverID, "zpJademine", 1, 0);
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
  rmPlaceObjectDefInArea(silverID, 0, playerIsland3ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
  rmPlaceObjectDefInArea(silverID, 0, playerIsland4ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
  rmPlaceObjectDefInArea(silverID, 0, playerIsland1ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
  rmPlaceObjectDefInArea(silverID, 0, playerIsland2ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
  rmPlaceObjectDefInArea(silverID, 0, playerIsland5ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
  rmPlaceObjectDefInArea(silverID, 0, playerIsland6ID, rmRandInt(1,cNumberNonGaiaPlayers/2));
   
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
	rmPlaceObjectDefInArea(berriesID, 0, smallIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(berriesID, 0, smallIslandID, cNumberNonGaiaPlayers/2);


	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(3,5), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, avoidController);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
  rmPlaceObjectDefInArea(foodID1, 0, smallIslandID, cNumberNonGaiaPlayers);
  rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, cNumberNonGaiaPlayers);

  

	// Define and place Nuggets
    
	// Easy Nuggets All
	int nugget1= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
  rmAddObjectDefConstraint(nugget1, avoidImportantItem);
	rmAddObjectDefConstraint(nugget1, avoidTP);
	rmAddObjectDefConstraint(nugget1, avoidAll);
  rmAddObjectDefConstraint(nugget1, avoidController);
	rmAddObjectDefConstraint(nugget1, avoidWater8);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland1ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland2ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland3ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland4ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland5ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland6ID, 1);
  rmPlaceObjectDefInArea(nugget1, 0, smallIsland3ID, 1);

  // Harder nuggets South
	int nugget2= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 3);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
  rmAddObjectDefConstraint(nugget2, avoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidController);
	rmAddObjectDefConstraint(nugget2, avoidTP);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater4);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland5ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland6ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, smallIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, smallIsland3ID, cNumberNonGaiaPlayers/2);

  // Harder nuggets South
	int nugget3= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(12, 13);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNugget);
  rmAddObjectDefConstraint(nugget3, avoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidController);
	rmAddObjectDefConstraint(nugget3, avoidTP);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidWater4);
  rmPlaceObjectDefInArea(nugget3, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget3, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget3, 0, smallIslandID, cNumberNonGaiaPlayers/2);

  int nugget4= rmCreateObjectDef("nugget hardest north"); 
	rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(14, 14);
	rmSetObjectDefMinDistance(nugget4, 0.0);
	rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget4, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget4, avoidNugget);
  rmAddObjectDefConstraint(nugget4, avoidImportantItem);
  rmAddObjectDefConstraint(nugget4, avoidController);
	rmAddObjectDefConstraint(nugget4, avoidTP);
	rmAddObjectDefConstraint(nugget4, avoidAll);
	rmAddObjectDefConstraint(nugget4, avoidWater20);
  rmPlaceObjectDefInArea(nugget4, 0, smallIslandID, cNumberNonGaiaPlayers/2);

  int nugget5= rmCreateObjectDef("nugget hardest south"); 
	rmAddObjectDefItem(nugget5, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget5, 0.0);
	rmSetObjectDefMaxDistance(nugget5, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget5, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget5, avoidNugget);
  rmAddObjectDefConstraint(nugget5, avoidImportantItem);
  rmAddObjectDefConstraint(nugget5, avoidController);
	rmAddObjectDefConstraint(nugget5, avoidTP);
	rmAddObjectDefConstraint(nugget5, avoidAll);
	rmAddObjectDefConstraint(nugget5, avoidWater20);
  rmPlaceObjectDefInArea(nugget5, 0, smallIsland2ID, cNumberNonGaiaPlayers/2);



	// Water nuggets
  int nuggetCount = cNumberNonGaiaPlayers;
  
  int nuggetWaterb = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nuggetWaterb, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nuggetWaterb, 0.0);
  rmSetObjectDefMaxDistance(nuggetWaterb, rmXFractionToMeters(0.7));
  rmAddObjectDefConstraint(nuggetWaterb, avoidLand);
  rmAddObjectDefConstraint(nuggetWaterb, flagVsFlag);
  rmAddObjectDefConstraint(nuggetWaterb, avoidNuggetWater2);
  rmAddObjectDefConstraint(nuggetWaterb, ObjectAvoidTradeRoute);
  rmPlaceObjectDefAtLoc(nuggetWaterb, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

  int nugget2c= rmCreateObjectDef("nugget water" + i); 
	rmAddObjectDefItem(nugget2c, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(5, 5);
	rmSetObjectDefMinDistance(nugget2c, 0.0);
	rmSetObjectDefMaxDistance(nugget2c, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(nugget2c, avoidLand);
  rmAddObjectDefConstraint(nugget2c, flagVsFlag);
  rmAddObjectDefConstraint(nugget2c, avoidNuggetWater2);
  rmAddObjectDefConstraint(nugget2c, ObjectAvoidTradeRoute);
	rmPlaceObjectDefAtLoc(nugget2c, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
  

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
  rmAddObjectDefConstraint(whaleID, avoidControllerFar);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4); 

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.7));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
  rmAddObjectDefConstraint(fishID, avoidControllerMediumFar);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 30*cNumberNonGaiaPlayers);

   // VILLAGE TREES
   /*int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "TreeGreatLakesSnow", 1, 0.0);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage1, 12);
   if (mapVariation == 1)
    rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage2, 12);

  int villageTree2ID=rmCreateObjectDef("village tree 2");
   rmAddObjectDefItem(villageTree2ID, "ypTreeMongolianFir", 1, 0.0);
   rmPlaceObjectDefInArea(villageTree2ID, 0,  eastIslandVillage3, 12);
   if (mapVariation == 2)
    rmPlaceObjectDefInArea(villageTree2ID, 0,  eastIslandVillage2, 12);*/



    // Starter shipment triggers

// ------Triggers------------------------------------------------------------------------------------//

int tch0=1671; // tech operator

int eruptionLenght = 120;
int eqAreaDamage = 20;
int islandSize = 150;
int gapMin = 700;
int gapMax = 1200;
int eruptionBreakInitial = rmRandInt(700,1200);
int eruptionBreak1 = rmRandInt(gapMin,gapMax);
int eruptionBreak2 = rmRandInt(gapMin,gapMax);
int eruptionBreak3 = rmRandInt(gapMin,gapMax);
int eruptionBreak4 = rmRandInt(gapMin,gapMax);
int eruptionBreak5 = rmRandInt(gapMin,gapMax);

string volcanoID = "361";
string volcanoID2 = "408";
string pirate1Socket = "5";
string pirate2Socket = "41";
string pirate1ID = "8";
string pirate2ID = "65";
string wokou1ID = "99";
string wokou2ID = "113";
string scientistsID = "163";

string port1ID = "440";
string port2ID = "490";



if (cNumberNonGaiaPlayers <=5) {
  eruptionLenght = 100;
  islandSize = 130;
  eqAreaDamage = 24;
}

if (cNumberNonGaiaPlayers <=2) {
  eruptionLenght = 80;
  islandSize = 90;
  eqAreaDamage = 30;
}

int eruptionVariant=-1;
eruptionVariant = rmRandInt(1,2);

// Volcano trigger definition
rmCreateTrigger("Volcano_StartInitial");
rmCreateTrigger("Volcano_Start1");
rmCreateTrigger("Volcano_Start2");
rmCreateTrigger("Volcano_Start3");
rmCreateTrigger("Volcano_Start4");

rmCreateTrigger("Volcano_Lava");
rmCreateTrigger("Volcano_Lava2");

rmCreateTrigger("Volcano_Lava_Death");

rmCreateTrigger("Volcano_Lava_Delay1");
rmCreateTrigger("Volcano_Lava_Delay2");
rmCreateTrigger("Volcano_Lava_Delay3");
rmCreateTrigger("Volcano_Lava_Delay4");
rmCreateTrigger("Volcano_Lava_Delay5");

rmCreateTrigger("Volcano_Lava_Delay21");
rmCreateTrigger("Volcano_Lava_Delay22");
rmCreateTrigger("Volcano_Lava_Delay23");
rmCreateTrigger("Volcano_Lava_Delay24");
rmCreateTrigger("Volcano_Lava_Delay25");

rmCreateTrigger("Volcano_Lava_Transform");

rmCreateTrigger("Volcano_Short");
rmCreateTrigger("Volcano_Short2");
rmCreateTrigger("Volcano_Medium");
rmCreateTrigger("Volcano_Long");
rmCreateTrigger("Volcano_UltraLong");
rmCreateTrigger("Volcano_Stop");
rmCreateTrigger("Volcano_Stop2");

rmCreateTrigger("Volcano_Damage");
rmCreateTrigger("Volcano_Damage2");

rmCreateTrigger("Volcano_Music1");
rmCreateTrigger("Volcano_Music2");
rmCreateTrigger("Volcano_Music3");
rmCreateTrigger("Volcano_MusicEnd");

// Volcano Music

rmSwitchToTrigger(rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\BubbleChum.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",4.0);
rmAddTriggerEffect("Sound Timer");
rmSetTriggerEffectParamInt("Time", 50000);
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Music2"));
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\CamelsStrawsAndBacks.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",2.0);
if (cNumberNonGaiaPlayers >=6){
  rmAddTriggerEffect("Sound Timer");
  rmSetTriggerEffectParamInt("Time", 60000);
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
}
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

if (cNumberNonGaiaPlayers >=6){
  rmSwitchToTrigger(rmTriggerID("Volcano_Music3"));
  rmAddTriggerEffect("Music Filename");
  rmSetTriggerEffectParam("Music","music\battle\Ruinion.mp3"); // Music Filename
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerPriority(1);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(false);
  rmSetTriggerLoop(false);
}

rmSwitchToTrigger(rmTriggerID("Volcano_MusicEnd"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Music Play");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

// Volcano Area Damage

rmSwitchToTrigger(rmTriggerID("Volcano_Damage"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","VolcanoStartID");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
for(i=1; <= cNumberNonGaiaPlayers) {
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Unit");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",eqAreaDamage);
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Building");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",20*eqAreaDamage);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Damage2"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","VolcanoStartID");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",2);
for(i=1; <= cNumberNonGaiaPlayers) {
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID2);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Unit");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",eqAreaDamage);
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID2);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Building");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",20*eqAreaDamage);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano random starts

rmSwitchToTrigger(rmTriggerID("Volcano_StartInitial"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreakInitial);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
if (eruptionVariant == 1)
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Northern Volcano
else
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoActiveB"); // Activates Southern Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","spcjc4brain");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
if (eruptionVariant == 1){
  rmSetTriggerEffectParam("Msg", "Northern Volcano eruption");
  rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
}
else{
  rmSetTriggerEffectParam("Msg", "Southern Volcano eruption");
  rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop2"));
}
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","VolcanoStartID");
if (eruptionVariant == 1)
  rmSetTriggerEffectParamInt("Value",1);
else
  rmSetTriggerEffectParamInt("Value",2);
rmAddTriggerEffect("Fire Event");
if (eruptionVariant == 1)
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
else
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start2"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
if (eruptionVariant == 1)
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));
else
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava2"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
if (eruptionVariant == 1)
  rmSetTriggerEffectParam("Message","The Northern Volcano is waking up!");
else
  rmSetTriggerEffectParam("Message","The Southern Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
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
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActiveB"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","spcjc4brain");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Southern Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop2"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","VolcanoStartID");
rmSetTriggerEffectParamInt("Value",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start2"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava2"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Southern Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
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
rmSetTriggerEffectParam("SetName","spcjc4brain");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Northern Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","VolcanoStartID");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start3"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Northern Volcano is waking up!");
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
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActiveB"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","spcjc4brain");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Southern Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop2"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","VolcanoStartID");
rmSetTriggerEffectParamInt("Value",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start4"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava2"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Southern Volcano is waking up!");
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
rmSetTriggerEffectParam("SetName","spcjc4brain");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Northern Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","VolcanoStartID");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Northern Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano Lava Flow

rmSwitchToTrigger(rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",4);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay1"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava2"));

rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",5);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",6);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay21"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Death"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",4);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",5);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",6);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","WesternEurope");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay1"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Chinese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay2"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay21"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Chinese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay22"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay2"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon2");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Japanese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay3"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay22"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon2");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Japanese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay23"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay3"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon3");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Indian");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay4"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay23"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon3");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Indian");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay24"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay4"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon4");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Mediterranean");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay5"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay24"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon4");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Mediterranean");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay25"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay5"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon5");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","EasternEurope");
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay25"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon5");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",10);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","EasternEurope");
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Transform"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",15);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoLavaBack");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

// Volcano Eruption Phases

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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage2"));
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
if (cNumberNonGaiaPlayers <=2){
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
}
else{
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Long"));
}
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage2"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

if (cNumberNonGaiaPlayers >=3){
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
  rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage2"));
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
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage2"));
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Transform"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano stop

rmSwitchToTrigger(rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoPassive"); // Desctivates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","borneo_skirmish");
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Stop2"));
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoPassiveB"); // Desctivates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","borneo_skirmish");
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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
rmSetTriggerEffectParam("TechID","cTechzpOceaniaMercenaries"); // Mercenary
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpNativeHeavyMap"); // Native Embassy Techs
rmSetTriggerEffectParamInt("Status",2);
}
for(i=0; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpMapOceania"); // Oceania TradePosts
rmSetTriggerEffectParamInt("Status",2);
}
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpMelanesiaVolcano"); // Polynesia Volcano
rmSetTriggerEffectParamInt("Status",2);
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
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesAustralia"); //operator
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
rmCreateTrigger("Activate Wokou"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpBlackmailing"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWokouSouth"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Wokou"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Update ports

rmCreateTrigger("I Update Ports1");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",port1ID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParamInt("Dist",200);
rmSetTriggerConditionParam("UnitType","deTradingGalleon");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports1");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",port1ID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParamInt("Dist",200);
rmSetTriggerConditionParam("UnitType","deTradingFluyt");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("I Update Ports2");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",port2ID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParamInt("Dist",200);
rmSetTriggerConditionParam("UnitType","deTradingGalleon");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports2");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",port2ID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParamInt("Dist",200);
rmSetTriggerConditionParam("UnitType","deTradingFluyt");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

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
rmSetTriggerConditionParam("DstObject",pirate2ID);
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPirateSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPirateSteamer2"); //operator
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCFlyingDutchmanProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainFlyingDutchman2"); //operator
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPirateSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPirateSteamer1"); //operator
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCFlyingDutchmanProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainFlyingDutchman1"); //operator
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate2ID);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate2ID);
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackJack"); //operator
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesDutchman"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Junk training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainJunk1ON Plr"+k);
rmCreateTrigger("TrainJunk1OFF Plr"+k);
rmCreateTrigger("TrainJunk1TIME Plr"+k);


rmCreateTrigger("TrainJunk2ON Plr"+k);
rmCreateTrigger("TrainJunk2OFF Plr"+k);
rmCreateTrigger("TrainJunk2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouJunkProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk2OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk2TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpWokouJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouJunkProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk1OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpWokouJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Fire Ship training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("trainFuchuan1ON Plr"+k);
rmCreateTrigger("trainFuchuan1OFF Plr"+k);
rmCreateTrigger("trainFuchuan1TIME Plr"+k);

rmCreateTrigger("trainFuchuan2ON Plr"+k);
rmCreateTrigger("trainFuchuan2OFF Plr"+k);
rmCreateTrigger("trainFuchuan2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("trainFuchuan2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPrauProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan2OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1", 1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("trainFuchuan2TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpFireJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPrauProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1", 1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpFireJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Wokou trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Wokou1on Player"+k);
rmCreateTrigger("Wokou1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Wokou1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou1ID);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Wokou1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou1ID);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Wokou2on Player"+k);
rmCreateTrigger("Wokou2off Player"+k);

rmSwitchToTrigger(rmTriggerID("Wokou2on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou2ID);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou2off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Wokou2off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou2ID);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou2on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Wokou Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int wokouCaptain=-1;
wokouCaptain = rmRandInt(1,3);

if (wokouCaptain==1)
{
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSaoFeng"); //operator
    rmSetTriggerEffectParamInt("Status",2);
}
if (wokouCaptain==2)
{
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSiRigam"); //operator
    rmSetTriggerEffectParamInt("Status",2);
}
if (wokouCaptain==3)
{
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSwallow"); //operator
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
rmSetTriggerConditionParam("DstObject",scientistsID); // Unique Object ID Village 1
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
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
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
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
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
rmSetTriggerConditionParam("DstObject",scientistsID); // Unique Object ID Village 1
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
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
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
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
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
rmSetTriggerConditionParam("DstObject",scientistsID); // Unique Object ID Village 1
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
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
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
rmSetTriggerConditionParam("DstObject",scientistsID); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",scientistsID); // Unique Object ID Village 1
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
rmSetTriggerConditionParam("DstObject",scientistsID); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",scientistsID); // Unique Object ID Village 1
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