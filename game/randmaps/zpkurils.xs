// Kurils Islands 1.0

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
  string baseMix = "greatlakes_snow";
  string paintMix = "patagonia_grass";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ZP Kuril Islands";
  string startTreeType = "TreeGreatLakes";
  string forestType = "great lakes forest snow";
  string forestType2 = "z39 Russian Forest";
  string cliffType = "Africa Desert Grass";
  string mapType1 = "snow";
  string mapType2 = "grass";
  string huntable1 = "caribou";
  string huntable2 = "BighornSheep";
  string fish1 = "FishSalmon";
  string fish2 = "ypFishTuna";
  string whale1 = "HumpbackWhale";
  string lightingType = "ArcticTerritories_Skirmish";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";
  
	// Define Natives
  int subCiv0=-1;
  int subCiv1=-1;
  int subCiv2=-1;
  int subCiv3=-1;

  int mapVariation = rmRandInt(1, 2);

  if (rmAllocateSubCivs(4) == true)
  {
  subCiv0=rmGetCivID("wokou");
    rmEchoInfo("subCiv0 is wokou "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "wokou");

    subCiv1=rmGetCivID("zporthodox");
    rmEchoInfo("subCiv1 is zporthodox "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "zporthodox");

  subCiv2=rmGetCivID("zpscientists");
    rmEchoInfo("subCiv2 is zpscientists "+subCiv2);
    if (subCiv2 >= 0)
        rmSetSubCiv(2, "zpscientists");


  subCiv3=rmGetCivID("spczen");
  rmEchoInfo("subCiv3 is spczen "+subCiv3);
  if (subCiv3 >= 0)
      rmSetSubCiv(3, "spczen");
    
  }


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=24000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 30000;
  if (cNumberNonGaiaPlayers < 3)
		playerTiles = 39000;
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
  rmSetMapType("kurils");
  rmSetMapType("kamchatka");
	rmSetLightingSet("ArcticTerritories_Skirmish");
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
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 70.0); 
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketScientists", 20.0);
  int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 30.0);
  int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketOrthodox", 30.0);
  int avoidZen=rmCreateTypeDistanceConstraint("avoid socket zen", "zpSocketSPCZen", 30.0);
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
  int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water 30 long", "Land", false, 30.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
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
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
   int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 30.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);
	    	

   int tradeRouteID = rmCreateTradeRoute();
   int tradeRoute2ID = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID);
   rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.55);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.55);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.05);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

  rmSetObjectDefTradeRouteID(tradeRoute2ID);
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.0, 0.45); 
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.05, 0.45);
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.18, 0.82);
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.55, 0.95);
   rmAddTradeRouteWaypoint(tradeRoute2ID, 0.55, 1.0);

   bool placedTradeRoute2 = rmBuildTradeRoute(tradeRoute2ID, "water_trail");
  
    if (cNumberNonGaiaPlayers == 3)
      rmSetPlacementSection(0.375, 0.374);
    else
      rmSetPlacementSection(0.125, 0.124);
    
    if (cNumberNonGaiaPlayers < 4)
    rmPlacePlayersCircular(0.24, 0.24, 0);
    
    else
	  rmPlacePlayersCircular(0.21, 0.21, 0);

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
    rmSetAreaMix(playerID, "patagonia_snow");
    rmAddAreaTerrainLayer(playerID, "patagonia\ground_dirt3_pat", 0, 2);
    rmAddAreaTerrainLayer(playerID, "patagonia\ground_snow1_pat", 2, 4);
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


  int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.55+rmXTilesToFraction(22), 0.95);
   rmSetAreaMix(portSite1, "patagonia_snow");
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 2.5);
   rmAddAreaToClass(portSite1, classPortSite);
   rmAddAreaToClass(portSite1, classEuIsland);
   rmBuildArea(portSite1);

   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.45-rmXTilesToFraction(22),0.05);
   rmSetAreaMix(portSite2, "patagonia_dirt");
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 2.5);
   rmAddAreaToClass(portSite2, classPortSite);
   rmAddAreaToClass(portSite2, classAfIsland);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(portSite3, 0.05, 0.45-rmXTilesToFraction(22));
   rmSetAreaMix(portSite3, "patagonia_dirt");
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.5);
   rmAddAreaToClass(portSite3, classPortSite);
   rmAddAreaToClass(portSite3, classAfIsland);
  rmBuildArea(portSite3);

  int portSite4 = rmCreateArea ("port_site4");
  rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(portSite4, 0.95,0.55+rmXTilesToFraction(22));
  rmSetAreaMix(portSite4, "patagonia_snow");
  rmSetAreaCoherence(portSite4, 1);
  rmSetAreaSmoothDistance(portSite4, 15);
  rmSetAreaBaseHeight(portSite4, 2.5);
  rmAddAreaToClass(portSite4, classPortSite);
  rmAddAreaToClass(portSite4, classEuIsland);
  rmBuildArea(portSite4);


  int playerIsland1ID=rmCreateArea("player island 1");
    rmSetAreaLocation(playerIsland1ID, .45, .8);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland1ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland1ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland1ID, classIsland);
    rmAddAreaToClass(playerIsland1ID, classEuIsland);
    rmSetAreaWarnFailure(playerIsland1ID, false);
	  rmSetAreaCoherence(playerIsland1ID, 0.5);
    rmSetAreaBaseHeight(playerIsland1ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland1ID, 20);
    rmSetAreaMix(playerIsland1ID, baseMix);
    rmAddAreaTerrainLayer(playerIsland1ID, "patagonia\ground_dirt3_pat", 0, 1);
      rmAddAreaTerrainLayer(playerIsland1ID, "patagonia\ground_snow1_pat", 1, 3);
    rmAddAreaTerrainLayer(playerIsland1ID, "patagonia\ground_snow2_pat", 3, 5);
    rmAddAreaTerrainLayer(playerIsland1ID, "patagonia\ground_snow3_pat", 5, 7);
    rmAddAreaConstraint(playerIsland1ID, islandConstraint);
    rmAddAreaConstraint(playerIsland1ID, islandEdgeConstraint);
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
    rmSetAreaLocation(playerIsland2ID, .8, .45);
    if (cNumberNonGaiaPlayers <= 5)
      rmSetAreaSize(playerIsland2ID, 0.03, 0.03);
    else
      rmSetAreaSize(playerIsland2ID, 0.026, 0.026);
    rmAddAreaToClass(playerIsland2ID, classIsland);
    rmAddAreaToClass(playerIsland2ID, classEuIsland);
    rmSetAreaWarnFailure(playerIsland2ID, false);
	  rmSetAreaCoherence(playerIsland2ID, 0.5);
    rmSetAreaBaseHeight(playerIsland2ID, 2.0);
    rmSetAreaSmoothDistance(playerIsland2ID, 20);
    rmSetAreaMix(playerIsland2ID, baseMix);
      rmAddAreaTerrainLayer(playerIsland2ID, "patagonia\ground_dirt3_pat", 0, 1);
      rmAddAreaTerrainLayer(playerIsland2ID, "patagonia\ground_snow1_pat", 1, 3);
    rmAddAreaTerrainLayer(playerIsland2ID, "patagonia\ground_snow2_pat", 3, 5);
    rmAddAreaTerrainLayer(playerIsland2ID, "patagonia\ground_snow3_pat", 5, 7);
    rmAddAreaConstraint(playerIsland2ID, islandConstraint);
    rmAddAreaConstraint(playerIsland2ID, islandEdgeConstraint);
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
    rmSetAreaLocation(playerIsland3ID, .2, .55);
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
    rmAddAreaTerrainLayer(playerIsland3ID, "patagonia\ground_dirt3_pat", 0, 6);
    rmAddAreaTerrainLayer(playerIsland3ID, "patagonia\ground_dirt1_pat", 6, 9);
    rmAddAreaTerrainLayer(playerIsland3ID, "patagonia\ground_grass3_pat", 9, 15);
    rmAddAreaTerrainLayer(playerIsland3ID, "patagonia\ground_grass2_pat", 15, 22);
    rmAddAreaConstraint(playerIsland3ID, islandConstraint);
    rmAddAreaConstraint(playerIsland3ID, islandEdgeConstraint);
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
    rmSetAreaLocation(playerIsland4ID, .55, .2);
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
    rmAddAreaTerrainLayer(playerIsland4ID, "patagonia\ground_dirt3_pat", 0, 6);
    rmAddAreaTerrainLayer(playerIsland4ID, "patagonia\ground_dirt1_pat", 6, 9);
    rmAddAreaTerrainLayer(playerIsland4ID, "patagonia\ground_grass3_pat", 9, 15);
    rmAddAreaTerrainLayer(playerIsland4ID, "patagonia\ground_grass2_pat", 15, 22);
    rmAddAreaConstraint(playerIsland4ID, islandConstraint);
    rmAddAreaConstraint(playerIsland4ID, islandEdgeConstraint);
    rmAddAreaConstraint(playerIsland4ID, islandAvoidTradeRoute);
    rmAddAreaConstraint(playerIsland4ID, avoidPirateArea);
    rmSetAreaElevationType(playerIsland4ID, cElevTurbulence);
    rmSetAreaElevationVariation(playerIsland4ID, 4.0);
    rmSetAreaElevationMinFrequency(playerIsland4ID, 0.09);
    rmSetAreaElevationOctaves(playerIsland4ID, 3);
    rmSetAreaElevationPersistence(playerIsland4ID, 0.2);
    rmSetAreaElevationNoiseBias(playerIsland4ID, 1);  	
    rmBuildArea(playerIsland4ID);


  int controllerID2 = rmCreateObjectDef("Controler 2");
   rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmPlaceObjectDefAtLoc(controllerID2, 0, 0.55, 0.85);
   vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

  int pirateSite1 = rmCreateArea ("pirate_site1");
   rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
   rmSetAreaMix(pirateSite1, "patagonia_snow");
   rmSetAreaCoherence(pirateSite1, 1);
   rmSetAreaSmoothDistance(pirateSite1, 15);
   rmSetAreaBaseHeight(pirateSite1, 2.0);
   rmAddAreaToClass(pirateSite1, classIsland);
  rmAddAreaToClass(pirateSite1, classAfIsland);
   rmBuildArea(pirateSite1);


   int controllerID3 = rmCreateObjectDef("Controler 3");
      rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmPlaceObjectDefAtLoc(controllerID3, 0, 0.85, 0.55);
      vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));

  int pirateSite2 = rmCreateArea ("pirate_site2");
   rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)));
   rmSetAreaMix(pirateSite2, "patagonia_snow");
   rmSetAreaCoherence(pirateSite2, 1);
   rmSetAreaSmoothDistance(pirateSite2, 15);
   rmSetAreaBaseHeight(pirateSite2, 2.0);
   rmAddAreaToClass(pirateSite2, classIsland);
  rmAddAreaToClass(pirateSite2, classEuIsland);
   rmBuildArea(pirateSite2);


  int controllerID1 = rmCreateObjectDef("Controler 1");
    rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);    rmSetObjectDefMaxDistance(controllerID1, 0.0);
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.15, 0.45);
    vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

    int controllerID4 = rmCreateObjectDef("Controler 4");
    rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmPlaceObjectDefAtLoc(controllerID4, 0, 0.45, 0.15);
    vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

  int pirateSite3 = rmCreateArea ("pirate_site3");
   rmSetAreaSize(pirateSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite3, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
   rmSetAreaMix(pirateSite3, "patagonia_dirt");
   rmSetAreaCoherence(pirateSite3, 1);
   rmSetAreaSmoothDistance(pirateSite3, 15);
   rmSetAreaBaseHeight(pirateSite3, 2.0);
   rmAddAreaToClass(pirateSite3, classIsland);
  rmAddAreaToClass(pirateSite3, classAfIsland);
   rmBuildArea(pirateSite3);


  int pirateSite4 = rmCreateArea ("pirate_site4");
   rmSetAreaSize(pirateSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(pirateSite4, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)));
   rmSetAreaMix(pirateSite4, "patagonia_dirt");
   rmSetAreaCoherence(pirateSite4, 1);
   rmSetAreaSmoothDistance(pirateSite4, 15);
   rmSetAreaBaseHeight(pirateSite4, 2.0);
   rmAddAreaToClass(pirateSite4, classIsland);
  rmAddAreaToClass(pirateSite4, classEuIsland);
   rmBuildArea(pirateSite4);

   


      // Make one big island.  
	int smallIslandID=rmCreateArea("corsair island");
	rmSetAreaSize(smallIslandID, 0.06, 0.06);
	rmSetAreaCoherence(smallIslandID, 0.45);
	rmSetAreaBaseHeight(smallIslandID, 2.0);
	rmSetAreaSmoothDistance(smallIslandID, 20);
	rmSetAreaMix(smallIslandID, baseMix);
	rmAddAreaToClass(smallIslandID, classIsland);
  rmAddAreaToClass(smallIslandID, classEuIsland);
  rmAddAreaConstraint(smallIslandID, islandAvoidTradeRoute);
	rmAddAreaConstraint(smallIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIslandID, false);
  rmSetAreaElevationType(smallIslandID, cElevTurbulence);
  	rmSetAreaElevationVariation(smallIslandID, 3.0);
	rmSetAreaElevationMinFrequency(smallIslandID, 0.09);
	rmSetAreaElevationOctaves(smallIslandID, 3);
	rmSetAreaElevationPersistence(smallIslandID, 0.2);
	rmSetAreaElevationNoiseBias(smallIslandID, 1);
  rmSetAreaLocation(smallIslandID, 0.8, 0.8);
   rmAddAreaTerrainLayer(smallIslandID, "patagonia\ground_dirt3_pat", 0, 1);
      rmAddAreaTerrainLayer(smallIslandID, "patagonia\ground_snow1_pat", 1, 3);
    rmAddAreaTerrainLayer(smallIslandID, "patagonia\ground_snow2_pat", 3, 5);
    rmAddAreaTerrainLayer(smallIslandID, "patagonia\ground_snow3_pat", 5, 7);
    rmAddAreaInfluenceSegment(smallIslandID, 0.7, 0.9, 0.8, 0.8);
  rmAddAreaInfluenceSegment(smallIslandID, 0.9, 0.7, 0.8, 0.8);
  
	rmBuildArea(smallIslandID);


  int smallIsland2ID=rmCreateArea("corsair island2");
	rmSetAreaSize(smallIsland2ID, 0.06, 0.06);
	rmSetAreaCoherence(smallIsland2ID, 0.45);
	rmSetAreaBaseHeight(smallIsland2ID, 2.0);
	rmSetAreaSmoothDistance(smallIsland2ID, 20);
	rmSetAreaMix(smallIsland2ID, paintMix);
	rmAddAreaToClass(smallIsland2ID, classIsland);
  rmAddAreaToClass(smallIsland2ID, classAfIsland);
	rmAddAreaConstraint(smallIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(smallIsland2ID, false);
	rmSetAreaElevationType(smallIsland2ID, cElevTurbulence);
  rmAddAreaConstraint(smallIsland2ID, islandAvoidTradeRoute);
	rmSetAreaElevationVariation(smallIsland2ID, 3.0);
	rmSetAreaElevationMinFrequency(smallIsland2ID, 0.09);
	rmSetAreaElevationOctaves(smallIsland2ID, 3);
	rmSetAreaElevationPersistence(smallIsland2ID, 0.2);
	rmSetAreaElevationNoiseBias(smallIsland2ID, 1);
  rmSetAreaLocation(smallIsland2ID, .2, .2);
    rmAddAreaTerrainLayer(smallIsland2ID, "patagonia\ground_dirt3_pat", 0, 6);
    rmAddAreaTerrainLayer(smallIsland2ID, "patagonia\ground_dirt1_pat", 6, 9);
    rmAddAreaTerrainLayer(smallIsland2ID, "patagonia\ground_grass3_pat", 9, 15);
    rmAddAreaTerrainLayer(smallIsland2ID, "patagonia\ground_grass2_pat", 15, 22);
    rmAddAreaInfluenceSegment(smallIsland2ID, 0.1, 0.3, 0.2, 0.2);
  rmAddAreaInfluenceSegment(smallIsland2ID, 0.3, 0.1, 0.2, 0.2);
  rmBuildArea(smallIsland2ID);

  

  int smallIsland3ID=rmCreateArea("corsair island3");
	rmSetAreaSize(smallIsland3ID, 0.035, 0.035);
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
  rmSetAreaLocation(smallIsland3ID, .5, .5);
  if (mapVariation == 1){
  rmSetAreaMix(smallIsland3ID, baseMix);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_dirt3_pat", 0, 1);
      rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_snow1_pat", 1, 3);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_snow2_pat", 3, 5);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_snow3_pat", 5, 7);
    rmAddAreaToClass(smallIsland3ID, classEuIsland);
  }

  if (mapVariation == 2){
  rmSetAreaMix(smallIsland3ID, paintMix);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_dirt3_pat", 0, 6);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_dirt1_pat", 6, 9);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_grass3_pat", 9, 15);
    rmAddAreaTerrainLayer(smallIsland3ID, "patagonia\ground_grass2_pat", 15, 22);
    rmAddAreaToClass(smallIsland3ID, classAfIsland);
  }
  rmBuildArea(smallIsland3ID);


  int nativeIslandConstraint=rmCreateAreaConstraint("native Island", smallIslandID);

    


	
    

  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);
  
	// NATIVES

    

  
  // Scientist Village 1

         int scientistsVillageID = -1;
         scientistsVillageID = rmCreateGrouping("scientist city", "Scientist_Lab01");     


         rmPlaceGroupingAtLoc(scientistsVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

         int scientistwaterflagID1 = rmCreateObjectDef("scientist water flag 1");
         rmAddObjectDefItem(scientistwaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
         rmAddClosestPointConstraint(flagLandShort);
         rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

         vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
         rmPlaceObjectDefAtLoc(scientistwaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

         rmClearClosestPointConstraints();

         int scientistportID1 = -1;
         scientistportID1 = rmCreateGrouping("scientist port 1", "Platform_Universal");
         rmAddClosestPointConstraint(portOnShore);
         rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

         vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
         rmPlaceGroupingAtLoc(scientistportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
         
         rmClearClosestPointConstraints();

// Scientist Village 3

     int scientistsVillageID3 = -1;
      scientistsVillageID3 = rmCreateGrouping("scientist city 3", "Scientist_Lab02");

      rmPlaceGroupingAtLoc(scientistsVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);
    
      int scientistwaterflagID3 = rmCreateObjectDef("scientist water flag 3");
      rmAddObjectDefItem(scientistwaterflagID3, "zpNativeWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(scientistwaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

      rmClearClosestPointConstraints();

      int scientistportID3 = -1;
      scientistportID3 = rmCreateGrouping("scientist port 3", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);
      rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

      vector closeToVillage3a = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(scientistportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));
      
      rmClearClosestPointConstraints();

         
// wokou

      // wokou Village 3

      int wokouVillageID3 = -1;
      wokouVillageID3 = rmCreateGrouping("wokou city 3", "Wokou_Village_North_01");

      rmPlaceGroupingAtLoc(wokouVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);
    
      int wokouwaterflagID3 = rmCreateObjectDef("wokou water flag 3");
      rmAddObjectDefItem(wokouwaterflagID3, "zpWokouWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(wokouwaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

      int wokouportID3 = -1;
      wokouportID3 = rmCreateGrouping("wokou port 3", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(wokouportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();

      // wokou Village 4

      int wokouVillageID4 = -1;
      wokouVillageID4 = rmCreateGrouping("wokou city 4", "Wokou_Village_North_02");

      rmPlaceGroupingAtLoc(wokouVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);
    
      int wokouwaterflagID4 = rmCreateObjectDef("wokou water flag 4");
      rmAddObjectDefItem(wokouwaterflagID4, "zpWokouWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage4 = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(wokouwaterflagID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4)));

      rmClearClosestPointConstraints();

      int wokouportID4 = -1;
      wokouportID4 = rmCreateGrouping("wokou port 4", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage4a = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(wokouportID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4a)));
      
      rmClearClosestPointConstraints();
  
      // Port Sites


   int connectionID1 = rmCreateConnection ("connection_island1");
   rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID1, 20, 4);
   rmSetConnectionCoherence(connectionID1, 0.7);
   rmSetConnectionWarnFailure(connectionID1, false);
   rmAddConnectionArea(connectionID1, smallIslandID);
   rmAddConnectionArea(connectionID1, portSite1);
   rmSetConnectionBaseHeight(connectionID1, 2);
   rmBuildConnection(connectionID1);

   int connectionID2 = rmCreateConnection ("connection_island2");
   rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID2, 20, 4);
   rmSetConnectionCoherence(connectionID2, 0.7);
   rmSetConnectionWarnFailure(connectionID2, false);
   rmAddConnectionArea(connectionID2, smallIsland2ID);
   rmAddConnectionArea(connectionID2, portSite2);
   rmSetConnectionBaseHeight(connectionID2, 2);
   rmBuildConnection(connectionID2);

  int connectionID3 = rmCreateConnection ("connection_island3");
   rmSetConnectionType(connectionID3, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID3, 20, 4);
   rmSetConnectionCoherence(connectionID3, 0.7);
   rmSetConnectionWarnFailure(connectionID3, false);
   rmAddConnectionArea(connectionID3, smallIsland2ID);
   rmAddConnectionArea(connectionID3, portSite3);
   rmSetConnectionBaseHeight(connectionID3, 2);
   rmBuildConnection(connectionID3);

  int connectionID4 = rmCreateConnection ("connection_island4");
   rmSetConnectionType(connectionID4, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID4, 20, 4);
   rmSetConnectionCoherence(connectionID4, 0.7);
   rmSetConnectionWarnFailure(connectionID4, false);
   rmAddConnectionArea(connectionID4, smallIslandID);
   rmAddConnectionArea(connectionID4, portSite4);
   rmSetConnectionBaseHeight(connectionID4, 2);
   rmBuildConnection(connectionID4);



  // Port 1
  int portID01 = rmCreateObjectDef("port 02");
  portID01 = rmCreateGrouping("portG 01", "harbour_universal_NE");
  rmPlaceGroupingAtLoc(portID01, 0, 0.45-rmXTilesToFraction(9), 0.05);

  // Port 2
  int portID02 = rmCreateObjectDef("port 02");
  portID02 = rmCreateGrouping("portG 02", "harbour_universal_SE");
  rmPlaceGroupingAtLoc(portID02, 0, 0.95,0.55+rmXTilesToFraction(10));

  // Port 3
  int portID03 = rmCreateObjectDef("port 03");
  portID03 = rmCreateGrouping("portG 03", "harbour_universal_SW");
  rmPlaceGroupingAtLoc(portID03, 0, 0.55+rmXTilesToFraction(10), 0.95);

  // Port 4
  int portID04 = rmCreateObjectDef("port 04");
  portID04 = rmCreateGrouping("portG 04", "harbour_universal_NW");
  rmPlaceGroupingAtLoc(portID04, 0, 0.05,0.45-rmXTilesToFraction(9));
      




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

   // Place additional Natives

    int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, 50);
      rmAddObjectDefConstraint(malteseControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID, playerEdgeConstraint);
      rmAddObjectDefConstraint(malteseControllerID, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater30);
      rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.8, 0.8);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));

      int malteseControllerID2 = rmCreateObjectDef("maltese controller 2");
      rmAddObjectDefItem(malteseControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID2, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID2, 50);
      rmAddObjectDefConstraint(malteseControllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID2, playerEdgeConstraint);
      rmAddObjectDefConstraint(malteseControllerID2, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID2, avoidWater30);
      rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.5, 0.5);
      vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));

      int malteseControllerID3 = rmCreateObjectDef("maltese controller 3");
      rmAddObjectDefItem(malteseControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID3, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID3, 50);
      rmAddObjectDefConstraint(malteseControllerID3, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID3, playerEdgeConstraint);
      rmAddObjectDefConstraint(malteseControllerID3, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID3, avoidWater20);
      rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.2, 0.2);
      vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));


      int eastIslandVillage1 = rmCreateArea ("east island village 1");
      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaCliffType(eastIslandVillage1, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(eastIslandVillage1, 1, 0.9, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage1, 1.0, 0.0, 0.0); 
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaBaseHeight(eastIslandVillage1, 4.5);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmBuildArea(eastIslandVillage1);

      int eastIslandVillage2 = rmCreateArea ("east island village 2");
      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.8);
      if (mapVariation == 1)
        rmSetAreaCliffType(eastIslandVillage2, "Rocky Mountain Edge");
      else
        rmSetAreaCliffType(eastIslandVillage2, "Patagonia");
      rmSetAreaCliffEdge(eastIslandVillage2, 1, 0.9, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage2, 1.0, 0.0, 0.0); 
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      if (cNumberNonGaiaPlayers < 4)
        rmSetAreaBaseHeight(eastIslandVillage2, 3.5);
      else
        rmSetAreaBaseHeight(eastIslandVillage2, 4.5);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmBuildArea(eastIslandVillage2);

      int eastIslandVillage3 = rmCreateArea ("east island village 3");
      rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3, 0.8);
      rmSetAreaCliffType(eastIslandVillage3, "Patagonia");
      rmSetAreaCliffEdge(eastIslandVillage3, 1, 0.9, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage3, 1.0, 0.0, 0.0); 
      rmSetAreaSmoothDistance(eastIslandVillage3, 5);
      rmSetAreaBaseHeight(eastIslandVillage3, 4.5);
      rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
      rmBuildArea(eastIslandVillage3);

      int eastIslandVillage3Terrain = rmCreateArea ("east island village 3 terrain");
      rmSetAreaSize(eastIslandVillage3Terrain, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage3Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3Terrain, 0.8);
      rmSetAreaMix(eastIslandVillage3Terrain,paintMix);
      rmBuildArea(eastIslandVillage3Terrain);

      int eastIslandVillage2Terrain = rmCreateArea ("east island village 2 terrain");
      rmSetAreaSize(eastIslandVillage2Terrain, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage2Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2Terrain, 0.8);
      rmSetAreaMix(eastIslandVillage2Terrain,paintMix);

      if (mapVariation == 2)
        rmBuildArea(eastIslandVillage2Terrain);



  
    int jesuit1VillageID = -1;


      int jesuit1VillageType = rmRandInt(1,5);
      jesuit1VillageID = rmCreateGrouping("jesuit 1", "Orthodox_Monastery0"+jesuit1VillageType);

    rmAddGroupingConstraint(jesuit1VillageID , avoidImpassableLand);



    int jesuit2VillageID = -1;
    if (mapVariation == 1){
      int jesuit2VillageType = rmRandInt(1,5);
      jesuit2VillageID = rmCreateGrouping("jesuit 2", "Orthodox_Monastery0"+jesuit2VillageType);
    }
    if (mapVariation == 2){
      jesuit2VillageType = rmRandInt(1,3);
      jesuit2VillageID = rmCreateGrouping("jesuit 2", "Zen_Mountain_0"+jesuit2VillageType);
    }
    rmAddGroupingConstraint(jesuit2VillageID , avoidImpassableLand);


    int jesuit3VillageID = -1;
    int jesuit3VillageType = rmRandInt(1,3);

      jesuit3VillageID = rmCreateGrouping("jesuit 3", "Zen_Mountain_0"+jesuit3VillageType);

    rmAddGroupingConstraint(jesuit3VillageID , avoidImpassableLand);


  rmPlaceGroupingAtLoc(jesuit1VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);
  rmPlaceGroupingAtLoc(jesuit2VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);
  rmPlaceGroupingAtLoc(jesuit3VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);


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
    rmAddAreaConstraint(forest, avoidWokou);
    rmAddAreaConstraint(forest, avoidZen);
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
    rmAddAreaConstraint(forest2, avoidWokou);
    rmAddAreaConstraint(forest2, avoidZen);
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
  rmPlaceObjectDefInArea(goldID, 0, smallIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(goldID, 0, playerIsland1ID, 1+cNumberNonGaiaPlayers/4);
  rmPlaceObjectDefInArea(goldID, 0, playerIsland2ID, 1+cNumberNonGaiaPlayers/4);

  int silverID = rmCreateObjectDef("random silver");
	rmAddObjectDefItem(silverID, "mine", 1, 0);
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
  rmPlaceObjectDefInArea(silverID, 0, smallIsland2ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(silverID, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(silverID, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);
   
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
  rmPlaceObjectDefInArea(berriesID, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(berriesID, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);

	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(3,5), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, northConstraint);
  rmAddObjectDefConstraint(foodID1, avoidController);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
  rmPlaceObjectDefInArea(foodID1, 0, smallIslandID, cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(foodID1, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(foodID1, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(foodID1, 0, smallIsland3ID, cNumberNonGaiaPlayers/2);
  
  // Huntables scattered on island
	int foodID2=rmCreateObjectDef("random food two");
	rmAddObjectDefItem(foodID2, huntable2, rmRandInt(7,9), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID2, avoidTP);
  rmAddObjectDefConstraint(foodID2, avoidTCLong);
  rmAddObjectDefConstraint(foodID2, avoidImportantItem);
  rmAddObjectDefConstraint(foodID2, avoidController);
  rmAddObjectDefConstraint(foodID2, avoidHuntable2);
	rmPlaceObjectDefInArea(foodID2, 0, smallIsland2ID, cNumberNonGaiaPlayers/2);
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
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland1ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland2ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland3ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, playerIsland4ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, smallIslandID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, smallIsland2ID, 1+cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget1, 0, smallIsland3ID, 1+cNumberNonGaiaPlayers/2);

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
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland1ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland2ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland3ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, playerIsland4ID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, smallIslandID, cNumberNonGaiaPlayers/2);
  rmPlaceObjectDefInArea(nugget2, 0, smallIsland2ID, 1+cNumberNonGaiaPlayers/8);
  rmPlaceObjectDefInArea(nugget2, 0, smallIsland3ID, cNumberNonGaiaPlayers/2);


	// Water nuggets
  int nuggetCount = cNumberNonGaiaPlayers;
  
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
  rmPlaceObjectDefPerPlayer(nuggetWaterb, false, nuggetCount/1.4);
  

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
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 30*cNumberNonGaiaPlayers);

   // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "TreeGreatLakesSnow", 1, 0.0);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage1, 12);
   if (mapVariation == 1)
    rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage2, 12);

  int villageTree2ID=rmCreateObjectDef("village tree 2");
   rmAddObjectDefItem(villageTree2ID, "ypTreeMongolianFir", 1, 0.0);
   rmPlaceObjectDefInArea(villageTree2ID, 0,  eastIslandVillage3, 12);
   if (mapVariation == 2)
    rmPlaceObjectDefInArea(villageTree2ID, 0,  eastIslandVillage2, 12);



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
rmSetTriggerEffectParam("TechID","cTechzpMountainZen"); // Sufi Mosque
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
	rmCreateTrigger("Activate Consulate Khmer"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","Khmers");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnKhmers"); //operator
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
  rmCreateTrigger("Activate Orthodox"+k);
  rmAddTriggerCondition("ZP Tech Researching (XS)");
  rmSetTriggerConditionParam("TechID","cTechzpOrthodoxInfluence"); //operator
  rmSetTriggerConditionParamInt("PlayerID",k);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",k);
  rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffOrthodox"); //operator
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
rmCreateTrigger("Activate Wokou"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpBlackmailing"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWokou"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmer"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Wokou"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Orthodox"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
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
   rmSetTriggerConditionParam("DstObject","225");
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
rmSetTriggerConditionParam("DstObject","200");
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
   rmSetTriggerConditionParam("DstObject","225");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpWokouFuchuanProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk2"); //operator
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
   rmSetTriggerConditionParamInt("Param1",1200);
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
   rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk2"); //operator
   rmSetTriggerEffectParamInt("Status",0);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("trainFuchuan1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","200");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouFuchuanProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk1"); //operator
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
rmSetTriggerConditionParamInt("Param1",1200);
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
rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk1"); //operator
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
rmSetTriggerConditionParam("DstObject","200");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","200");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
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
rmSetTriggerConditionParam("DstObject","200");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","200");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
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
   rmSetTriggerConditionParam("DstObject","225");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","225");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
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
   rmSetTriggerConditionParam("DstObject","225");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","225");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouTakanobu"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (wokouCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouMadameChing"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


// Submarine Training

// Submarine Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainSubmarine1ON Plr"+k);
rmCreateTrigger("TrainSubmarine1OFF Plr"+k);
rmCreateTrigger("TrainSubmarine1TIME Plr"+k);


rmCreateTrigger("TrainSubmarine2ON Plr"+k);
rmCreateTrigger("TrainSubmarine2OFF Plr"+k);
rmCreateTrigger("TrainSubmarine2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","164"); // Unique Object ID Village 2
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainSubmarine2OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine2TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainSubmarine1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","10"); // Unique Object ID Village 1
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

rmCreateTrigger("Steamer2TIMEPlr"+k);

rmCreateTrigger("SteamerTrain2ONPlr"+k);
rmCreateTrigger("SteamerTrain2OFFPlr"+k);


rmSwitchToTrigger(rmTriggerID("Steamer2TIMEPlr"+k));
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

// Steamer 2

rmSwitchToTrigger(rmTriggerID("SteamerTrain2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","164"); // Unique Object ID Village 2
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Steamer2TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("SteamerTrain2OFFPlr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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
rmSetTriggerConditionParam("DstObject","10"); // Unique Object ID Village 1
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

rmCreateTrigger("Nautilus2TIMEPlr"+k);

rmCreateTrigger("Nautilus2ONPlr"+k);
rmCreateTrigger("Nautilus2OFFPlr"+k);

// Build limit reducer 2
rmSwitchToTrigger(rmTriggerID("Nautilus2TIMEPlr"+k));
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

// Nautilus 2

rmSwitchToTrigger(rmTriggerID("Nautilus2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","164"); // Unique Object ID Village 2
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Nautilus2OFFPlr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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
rmSetTriggerConditionParam("DstObject","10"); // Unique Object ID Village 1
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
rmSetTriggerConditionParam("DstObject","10"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","10"); // Unique Object ID Village 1
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
rmSetTriggerConditionParam("DstObject","10"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","10"); // Unique Object ID Village 1
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


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Renegades2on Player"+k);
   rmCreateTrigger("Renegades2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Renegades2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","164"); // Unique Object ID Village 2
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","164"); // Unique Object ID Village 2
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Renegades2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","164"); // Unique Object ID Village 2
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","164"); // Unique Object ID Village 2
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades2on_Player"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
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

// AI Orthodox Captains

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Orthodox Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int orthodoxCaptain=-1;
orthodoxCaptain = rmRandInt(1,3);

if (orthodoxCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxGeorgians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (orthodoxCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxBulgarians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (orthodoxCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxRussians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


// Testing
/*
for (k=1; <= cNumberNonGaiaPlayers) {

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