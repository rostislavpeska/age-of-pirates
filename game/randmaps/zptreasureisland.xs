// Treasure Island 1.0

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
  string baseMix = "caribbean grass";
  string paintMix = "CaribbeanSkirmish";
  string baseTerrain = "water";
  string seaType = "caribbean coast";
  string startTreeType = "TreeCaribbean";
  string forestType = "caribbean palm forest";
  string cliffType = "Caribbean";
  string mapType1 = "caribbean";
  string mapType2 = "grass";
  string huntable1 = "turkey";
  string huntable2 = "Deer";
  string fish1 = "fishMahi";
  string fish2 = "fishTarpon";
  string whale1 = "MinkeWhale";
  string lightingType = "Hispaniola_Skirmish";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";
  
  
	// Define Natives
  int subCiv0=-1;
  int subCiv1=-1;
  int subCiv2=-1;
  int subCiv3=-1;

  if (rmAllocateSubCivs(3) == true)
  {
  subCiv0=rmGetCivID("natpirates");
    rmEchoInfo("subCiv0 is pirates "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "natpirates");

    subCiv1=rmGetCivID("zpscientists");
    rmEchoInfo("subCiv1 is zpscientists "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "zpscientists");

  subCiv2=rmGetCivID("caribs");
  rmEchoInfo("subCiv2 is caribs "+subCiv2);
  if (subCiv2 >= 0)
      rmSetSubCiv(2, "caribs");

    subCiv3=rmGetCivID("caribs");
  rmEchoInfo("subCiv3 is caribs "+subCiv3);
  if (subCiv3 >= 0)
      rmSetSubCiv(3, "caribs");
  }

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=23000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 25000;
  if(cNumberNonGaiaPlayers < 4)
    playerTiles = 27000;
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
  rmSetMapType("caribbeanwater");
	rmSetLightingSet("Hispaniola_Skirmish");
  rmSetOceanReveal(true);

	// Initialize map.
	rmTerrainInitialize(baseTerrain);

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
  int classAtol=rmDefineClass("atool");
  int classPlayerArea=rmDefineClass("player area");
	rmDefineClass("classForest");
	rmDefineClass("classPatch");
	rmDefineClass("importantItem");
	int classCanyon=rmDefineClass("canyon");

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
  int avoidPlayerArea=rmCreateClassDistanceConstraint("stuff avoids player areas", classPlayerArea, 30.0);

	// Island Constraints  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 35.0);
  int atolConstraint=rmCreateClassDistanceConstraint("atols avoid each other", classAtol, 20.0);
  int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
  
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
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "deShipRuins", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0); 
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 30.0);
  int avoidScientists=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketScientists", 30.0);
  int avoidFixedGun=rmCreateTypeDistanceConstraint("avoid fixed gun", "SPCFixedGunBase", 40.0);

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
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
  int ferryOnShoreLong=rmCreateTerrainMaxDistanceConstraint("ferry v. water 2", "water", true, 23.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 4.5);

  // things
	int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
  int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
  int stuffAvoidAtol=rmCreateClassDistanceConstraint("stuff avoids atol", classAtol, 50.0);

  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 15.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
  int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
  int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
	int flagVsScientists1 = rmCreateTypeDistanceConstraint("flag avoid wokou 1", "zpNativeWaterSpawnFlag1", 40);
  int flagVsScientists2 = rmCreateTypeDistanceConstraint("flag avoid wokou  2", "zpNativeWaterSpawnFlag2", 40);
  int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

   //Trade Route Contstraints
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	// Make one big island. 

  int smallIslandID=rmCreateArea("small island");
	rmSetAreaSize(smallIslandID, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
	rmSetAreaCoherence(smallIslandID, 0.65);
	rmSetAreaBaseHeight(smallIslandID, 2.0);
	rmSetAreaSmoothDistance(smallIslandID, 20);
	rmSetAreaMix(smallIslandID, paintMix);
	rmAddAreaToClass(smallIslandID, classAtol);
	rmSetAreaObeyWorldCircleConstraint(smallIslandID, false);
  rmSetAreaLocation(smallIslandID, .5, .5);
  
	rmBuildArea(smallIslandID);

	
	    	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

   int tradeRouteID = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 1.0);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 1.0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");
  
  if(cNumberNonGaiaPlayers <= 2){
	   rmSetPlacementSection(0.85, 0.15);
	   rmPlacePlayersCircular(0.37, 0.37, 0);
  }
  else{
	   rmSetPlacementSection(0.15, 0.85);
	   rmPlacePlayersCircular(0.37, 0.37, 0);
  }

	float playerFraction=rmAreaTilesToFraction(500 + cNumberNonGaiaPlayers*150);
	for(i=1; <cNumberPlayers)
	{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmSetAreaSize(playerID, playerFraction, playerFraction);
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	  rmSetAreaCoherence(playerID, 0.5);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, paintMix);
	// rmSetAreaTerrainType(playerID, playerTerrain);
    rmAddAreaToClass(playerID, classIsland);
    rmAddAreaToClass(playerID, classPlayerArea);
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
	}


	// Build the areas. 
	rmBuildAllAreas();
	
  int bigIslandID=rmCreateArea("migration island");
	rmSetAreaSize(bigIslandID, 0.08, 0.08);
	rmSetAreaCoherence(bigIslandID, 0.65);
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, baseMix);
	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
  rmAddAreaConstraint(bigIslandID, atolConstraint);
  rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
  rmSetAreaLocation(bigIslandID, .6, .5);
  rmAddAreaInfluenceSegment(bigIslandID, .6, .5, .6, .8);
  rmAddAreaInfluenceSegment(bigIslandID, .7, .5, .6, .8);
  rmAddAreaInfluenceSegment(bigIslandID, .6, .5, .6, .3);
  rmAddAreaInfluenceSegment(bigIslandID, .7, .5, .6, .3);

  
	rmBuildArea(bigIslandID);


  int bigIslandID2=rmCreateArea("migration island 2");
	rmSetAreaSize(bigIslandID2, 0.08, 0.08);
	rmSetAreaCoherence(bigIslandID2, 0.65);
	rmSetAreaBaseHeight(bigIslandID2, 2.0);
	rmSetAreaSmoothDistance(bigIslandID2, 20);
	rmSetAreaMix(bigIslandID2, baseMix);
	rmAddAreaToClass(bigIslandID2, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID2, false);
  rmAddAreaConstraint(bigIslandID2, atolConstraint);
  rmAddAreaConstraint(bigIslandID2, islandConstraint);
	rmSetAreaElevationType(bigIslandID2, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID2, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID2, 0.09);
	rmSetAreaElevationOctaves(bigIslandID2, 3);
	rmSetAreaElevationPersistence(bigIslandID2, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID2, 1);
  rmSetAreaLocation(bigIslandID2, .4, .5);
  rmAddAreaInfluenceSegment(bigIslandID2, .3, .5, .4, .8);
  rmAddAreaInfluenceSegment(bigIslandID2, .4, .5, .4, .8);
  rmAddAreaInfluenceSegment(bigIslandID2, .3, .5, .4, .3);
  rmAddAreaInfluenceSegment(bigIslandID2, .4, .5, .4, .3);
  
	rmBuildArea(bigIslandID2);


  int nativeIslandConstraint=rmCreateAreaConstraint("native Island", bigIslandID);

  int connectionID1 = rmCreateConnection ("connection_island1");
   rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID1, 20, 2);
   rmSetConnectionCoherence(connectionID1, 0.3);
   rmSetConnectionWarnFailure(connectionID1, false);
   rmAddConnectionArea(connectionID1, smallIslandID);
   rmAddConnectionArea(connectionID1, bigIslandID);
   rmSetConnectionBaseHeight(connectionID1, 2);
   rmSetConnectionHeightBlend(connectionID1, 2.0);
   rmSetConnectionSmoothDistance(connectionID1, 3.0);
   rmBuildConnection(connectionID1);

  int connectionID2 = rmCreateConnection ("connection_island2");
   rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID2, 20, 2);
   rmSetConnectionCoherence(connectionID2, 0.3);
   rmSetConnectionWarnFailure(connectionID2, false);
   rmAddConnectionArea(connectionID2, smallIslandID);
   rmAddConnectionArea(connectionID2, bigIslandID2);
   rmSetConnectionBaseHeight(connectionID2, 2);
   rmSetConnectionHeightBlend(connectionID2, 2.0);
   rmSetConnectionSmoothDistance(connectionID2, 3.0);
   rmBuildConnection(connectionID2);
    

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
  
	// NATIVES
  
  // Place Controllers
      int controllerID1 = rmCreateObjectDef("Controler 1");
      rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID1, 0.0);
	   rmSetObjectDefMaxDistance(controllerID1, 30.0);
      rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID1, stuffAvoidAtol);
      rmAddObjectDefConstraint(controllerID1, ferryOnShore); 


      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID2, 0.0);
	   rmSetObjectDefMaxDistance(controllerID2, 30.0);
      rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID2, stuffAvoidAtol);
      rmAddObjectDefConstraint(controllerID2, ferryOnShore); 

      int controllerID3 = rmCreateObjectDef("Controler 3");
      rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID3, 0.0);
	   rmSetObjectDefMaxDistance(controllerID3, 30.0);
      rmAddObjectDefConstraint(controllerID3, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID3, stuffAvoidAtol);
      rmAddObjectDefConstraint(controllerID3, ferryOnShore); 

      int controllerID4 = rmCreateObjectDef("Controler 4");
      rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID4, 0.0);
	   rmSetObjectDefMaxDistance(controllerID4, 30.0);
      rmAddObjectDefConstraint(controllerID4, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID4, stuffAvoidAtol);
      rmAddObjectDefConstraint(controllerID4, ferryOnShore);


        rmPlaceObjectDefAtLoc(controllerID3, 0, 0.4, 0.8);
        rmPlaceObjectDefAtLoc(controllerID4, 0, 0.6, 0.8);
        rmPlaceObjectDefAtLoc(controllerID1, 0, 0.35, 0.4);
        rmPlaceObjectDefAtLoc(controllerID2, 0, 0.65, 0.4);


      vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
      vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
      vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

      // Pirate Village 1

      int piratesVillageID = -1;
      int piratesVillageType = rmRandInt(1,2);
      piratesVillageID = rmCreateGrouping("pirate city", "pirate_village01");
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
      piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village02");
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
      piratesVillageID3 = rmCreateGrouping("pirate city 3", "Scientist_Lab03");
      rmSetGroupingMinDistance(piratesVillageID3, 0);
      rmSetGroupingMaxDistance(piratesVillageID3, 20);
      rmAddGroupingConstraint(piratesVillageID3, ferryOnShoreLong);

      rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);
    
      int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
      rmAddObjectDefItem(piratewaterflagID3, "zpNativeWaterSpawnFlag1", 1, 1.0);
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
      piratesVillageID4 = rmCreateGrouping("pirate city 4", "Scientist_Lab04");
      rmSetGroupingMinDistance(piratesVillageID4, 0);
      rmSetGroupingMaxDistance(piratesVillageID4, 20);
      rmAddGroupingConstraint(piratesVillageID4, ferryOnShoreLong);

      rmPlaceGroupingAtLoc(piratesVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);
    
      int piratewaterflagID4 = rmCreateObjectDef("pirate water flag 4");
      rmAddObjectDefItem(piratewaterflagID4, "zpNativeWaterSpawnFlag2", 1, 1.0);
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

      //Fixed Gun

      int fixedGunID = -1;
      fixedGunID = rmCreateGrouping("fixed gun", "Convertable_Fixed_Gun01");

      int fixedGunID2 = -1;
      fixedGunID2 = rmCreateGrouping("fixed gun 2", "Convertable_Fixed_Gun02");

      int fixedGunCliff = rmCreateArea ("fixed gun cliff");
      rmSetAreaSize(fixedGunCliff, rmAreaTilesToFraction(870.0), rmAreaTilesToFraction(870.0));
      rmSetAreaLocation(fixedGunCliff, 0.5, 0.5);
      rmSetAreaCoherence(fixedGunCliff, 0.8);
      rmSetAreaSmoothDistance(fixedGunCliff, 5);
      rmSetAreaCliffType(fixedGunCliff, "Caribbean");
      rmSetAreaCliffEdge(fixedGunCliff, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(fixedGunCliff, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(fixedGunCliff, 4.2);
      rmSetAreaElevationVariation(fixedGunCliff, 0.0);
      rmBuildArea(fixedGunCliff);

      int fixedGunRamp1 = rmCreateArea ("fixed gun ramp 1");
      rmSetAreaSize(fixedGunRamp1, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(fixedGunRamp1, 0.5-rmXMetersToFraction(30), 0.5);
      rmSetAreaBaseHeight(fixedGunRamp1, 4.2);
      rmSetAreaCoherence(fixedGunRamp1, 0.8);
      rmSetAreaMix(fixedGunRamp1, paintMix);
      rmSetAreaSmoothDistance(fixedGunRamp1, 30);
      rmBuildArea(fixedGunRamp1);

      int fixedGunRamp2 = rmCreateArea ("fixed gun ramp 2");
      rmSetAreaSize(fixedGunRamp2, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(fixedGunRamp2, 0.5+rmXMetersToFraction(30), 0.5);
      rmSetAreaBaseHeight(fixedGunRamp2, 6.2);
      rmSetAreaCoherence(fixedGunRamp2, 0.8);
      rmSetAreaMix(fixedGunRamp2, paintMix);
      rmSetAreaSmoothDistance(fixedGunRamp2, 30);
      rmBuildArea(fixedGunRamp2);


      rmPlaceGroupingAtLoc(fixedGunID, 0, 0.5, 0.5-rmXTilesToFraction(11), 1);

      rmPlaceGroupingAtLoc(fixedGunID2, 0, 0.5, 0.5+rmXTilesToFraction(11), 1);
      


      // Placing Player Trade Route Sockets

      int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
      rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
      rmSetObjectDefAllowOverlap(socketID, true);
      rmSetObjectDefMinDistance(socketID, 5.0);
      rmSetObjectDefMaxDistance(socketID, 30.0);

      vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

      if(cNumberNonGaiaPlayers <= 2){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.13);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 3){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.13);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 4){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.63);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 5){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.70);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 6){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.28);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.44);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.56);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.72);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 7){
        socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.63);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 8){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.22);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.33);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.44);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.56);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.67);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.78);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      // check for KOTH game mode
      if(rmGetIsKOTH()) {
        
        int randLoc = rmRandInt(1,2);
        float xLoc = 0.5;
        float yLoc = 0.5;
        float walk = 0.00;
        
        ypKingsHillPlacer(xLoc, yLoc, walk, 0);
        rmEchoInfo("XLOC = "+xLoc);
        rmEchoInfo("XLOC = "+yLoc);
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
  rmSetObjectDefMaxDistance(TCID, avoidPirates);
	rmAddObjectDefConstraint(TCID, avoidScientists);
  rmAddObjectDefConstraint(TCID, avoidFixedGun);
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
  
  //Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", 6, 4.0);
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
    rmAddClosestPointConstraint(flagVsScientists1);
    rmAddClosestPointConstraint(flagVsScientists2);
		rmAddClosestPointConstraint(flagLand);
    rmAddClosestPointConstraint(flagEdgeConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
    rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
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
    rmAddAreaConstraint(forest, avoidPlayerArea);
    rmAddAreaConstraint(forest, avoidScientists);
    rmAddAreaConstraint(forest, avoidFixedGun);
    rmAddAreaConstraint(forest, avoidTP);
    rmAddAreaConstraint(forest, avoidTCMedium);
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

    
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered silver throughout island and gold in south central area
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "deShipRuins", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(goldID, avoidAll);
  rmAddObjectDefConstraint(goldID, avoidWater8);
	rmAddObjectDefConstraint(goldID, avoidGold);
  rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(goldID, avoidImportantItem);
  rmAddAreaConstraint(goldID, avoidFixedGun);
  rmAddObjectDefConstraint(goldID, avoidCoin);
  rmAddObjectDefConstraint(goldID, avoidTP);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*1.5);

  int silverID = rmCreateObjectDef("random silver");
	rmAddObjectDefItem(silverID, "deShipRuins", 1, 0);
	rmSetObjectDefMinDistance(silverID, 0.0);
	rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(silverID, avoidAll);
  rmAddObjectDefConstraint(silverID, avoidWater8);
	rmAddObjectDefConstraint(silverID, avoidGold);
  rmAddObjectDefConstraint(silverID, avoidCoin);
  rmAddAreaConstraint(silverID, avoidPirates);
  rmAddAreaConstraint(silverID, avoidScientists);
  rmAddObjectDefConstraint(silverID, avoidTCLong);
  rmAddObjectDefConstraint(silverID, avoidTP);
  rmAddObjectDefConstraint(silverID, avoidImportantItem);
  rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID2, cNumberNonGaiaPlayers*1.5);
   
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
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers);
  rmPlaceObjectDefInArea(berriesID, 0, bigIslandID2, cNumberNonGaiaPlayers);

	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, northConstraint);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
	rmPlaceObjectDefInArea(foodID1, 0, bigIslandID, cNumberNonGaiaPlayers*2);  
  rmPlaceObjectDefInArea(foodID1, 0, bigIslandID2, cNumberNonGaiaPlayers*2);
  

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
	rmAddObjectDefConstraint(nugget1, avoidWater8);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*2);
  rmPlaceObjectDefInArea(nugget1, 0, bigIslandID2, cNumberNonGaiaPlayers*2);

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
  rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount);
  
  int nugget2= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nugget2, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2, avoidLand);
  rmAddObjectDefConstraint(nugget2, avoidNuggetWater);
  rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nugget2, false, nuggetCount/2);

  
  // really tough nuggets confined to south central cliffy area
  int nugget3= rmCreateObjectDef("nugget hardest"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidHardNugget);
  rmAddObjectDefConstraint(nugget3, avoidImportantItem);
	rmPlaceObjectDefInArea(nugget3, 0, bigIslandID, cNumberNonGaiaPlayers);
  rmPlaceObjectDefInArea(nugget3, 0, bigIslandID2, cNumberNonGaiaPlayers);

  // RANDOM TREES
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "treeCaribbean", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*6); 

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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
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
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2TIME_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
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

   
   rmCreateTrigger("UniqueShip2TIMEPlr"+k);

   rmCreateTrigger("BlackbTrain2ONPlr"+k);
   rmCreateTrigger("BlackbTrain2OFFPlr"+k);

   rmCreateTrigger("GraceTrain2ONPlr"+k);
   rmCreateTrigger("GraceTrain2OFFPlr"+k);

   rmCreateTrigger("CaesarTrain2ONPlr"+k);
   rmCreateTrigger("CaesarTrain2OFFPlr"+k);
   
   rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
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

   rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   

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
   rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
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
   rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
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
   rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
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
rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5"); // Unique Object ID Village 3
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
rmSetTriggerConditionParam("DstObject","5"); // Unique Object ID Village 3
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5"); // Unique Object ID Village 3
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
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56"); // Unique Object ID Village 4
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
   rmSetTriggerConditionParam("DstObject","56"); // Unique Object ID Village 4
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56"); // Unique Object ID Village 4
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
rmSetTriggerConditionParam("DstObject","189"); // Unique Object ID Village 2
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainSubmarine2TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","105"); // Unique Object ID Village 1
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

rmCreateTrigger("Steamer2TIMEPlr"+k);

rmCreateTrigger("SteamerTrain2ONPlr"+k);
rmCreateTrigger("SteamerTrain2OFFPlr"+k);


rmSwitchToTrigger(rmTriggerID("Steamer2TIMEPlr"+k));
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

// Steamer 2

rmSwitchToTrigger(rmTriggerID("SteamerTrain2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","189"); // Unique Object ID Village 2
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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
rmSetTriggerConditionParam("DstObject","105"); // Unique Object ID Village 1
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

rmCreateTrigger("Nautilus2TIMEPlr"+k);

rmCreateTrigger("Nautilus2ONPlr"+k);
rmCreateTrigger("Nautilus2OFFPlr"+k);

// Build limit reducer 2
rmSwitchToTrigger(rmTriggerID("Nautilus2TIMEPlr"+k));
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

// Nautilus 2

rmSwitchToTrigger(rmTriggerID("Nautilus2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","189"); // Unique Object ID Village 2
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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
rmSetTriggerConditionParam("DstObject","105"); // Unique Object ID Village 1
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
rmSetTriggerConditionParam("DstObject","105"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","105"); // Unique Object ID Village 1
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
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
rmSetTriggerConditionParam("DstObject","105"); // Unique Object ID Village 1
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","105"); // Unique Object ID Village 1
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
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
   rmSetTriggerConditionParam("DstObject","189"); // Unique Object ID Village 2
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","189"); // Unique Object ID Village 2
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
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
   rmSetTriggerConditionParam("DstObject","189"); // Unique Object ID Village 2
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","189"); // Unique Object ID Village 2
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
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


}  