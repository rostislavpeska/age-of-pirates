// ATOLS 1.0

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
  string baseMix = "ceylon_grass_a";
  string paintMix = "ceylon_sand_a";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ceylon coast";
  string startTreeType = "TreeCaribbean";
  string forestType = "Ceylon Forest";
  string cliffType = "ceylon";
  string mapType1 = "hawaii";
  string mapType2 = "grass";
  string huntable1 = "zpFeralPig";
  string huntable2 = "ypWildElephant";
  string fish1 = "ypFishMolaMola";
  string fish2 = "ypSquid";
  string whale1 = "MinkeWhale";
  string lightingType = "ceylon_skirmish";
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

    subCiv1=rmGetCivID("wokou");
    rmEchoInfo("subCiv1 is wokou "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "wokou");

  subCiv2=rmGetCivID("spcjesuit");
  rmEchoInfo("subCiv2 is spcjesuit "+subCiv2);
  if (subCiv2 >= 0)
      rmSetSubCiv(2, "spcjesuit");

    subCiv3=rmGetCivID("spcjesuit");
  rmEchoInfo("subCiv3 is spcjesuit "+subCiv3);
  if (subCiv3 >= 0)
      rmSetSubCiv(3, "spcjesuit");
  }

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=42000;
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
	rmSetLightingSet("caribbean_skirmish");
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

  int classStartingIsland=rmDefineClass("startingIsland");
  int classNativeIsland=rmDefineClass("nativeIsland");
  int classTradeIsland=rmDefineClass("tradeIsland");
  int classBuildingIsland=rmDefineClass("buildingIsland");
  int classGoldIsland=rmDefineClass("goldIsland");
  int classExtraIsland=rmDefineClass("extraIsland");

  // -------------Define constraints----------------------------------------

  // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));

  // Cardinal Directions
  int staySouthPart = rmCreatePieConstraint("Stay south part", 0.55, 0.55,rmXFractionToMeters(0.0), rmXFractionToMeters(0.60), rmDegreesToRadians(180),rmDegreesToRadians(360));
	int stayNorthHalf = rmCreatePieConstraint("Stay north half", 0.50, 0.50,rmXFractionToMeters(0.0), rmXFractionToMeters(0.50), rmDegreesToRadians(360),rmDegreesToRadians(180));

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
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 21.0);
  int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
  
	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
	int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 15.0);
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "minecopper", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 35.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 10.0);
  int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 10.0);
  int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketSPCJesuit", 30.0);

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
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

  // things
	int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
  int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
  
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


  // Island type avoidance
  int avoidStartingIslands=rmCreateClassDistanceConstraint("stuff avoids starting islands", classStartingIsland, 20.0);
  int avoidNativeIslands=rmCreateClassDistanceConstraint("stuff avoids native islands", classNativeIsland, 20.0);
  int avoidTradeIslands=rmCreateClassDistanceConstraint("stuff avoids trade islands", classTradeIsland, 20.0);
  int avoidBuildingIslands=rmCreateClassDistanceConstraint("stuff avoids building islands", classBuildingIsland, 20.0);
  int avoidGoldIslands=rmCreateClassDistanceConstraint("stuff avoids gold islands", classGoldIsland, 20.0);
  int avoidExtraIslands=rmCreateClassDistanceConstraint("stuff avoids extra islands", classExtraIsland, 20.0);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	// Make one big island.  
	int bigIslandID=rmCreateArea("migration island");
	rmSetAreaSize(bigIslandID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaCoherence(bigIslandID, 0.7);
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, baseMix);
	rmAddAreaToClass(bigIslandID, classIsland);
  rmAddAreaToClass(bigIslandID, classGoldIsland);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
  rmSetAreaLocation(bigIslandID, .5, .5);
	rmBuildArea(bigIslandID);


  // Native islands  
	int nativeIsland1ID=rmCreateArea("native island 1");
	rmSetAreaSize(nativeIsland1ID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaCoherence(nativeIsland1ID, 0.8);
	rmSetAreaBaseHeight(nativeIsland1ID, 2.0);
	rmSetAreaSmoothDistance(nativeIsland1ID, 20);
	rmSetAreaMix(nativeIsland1ID, baseMix);
	rmAddAreaToClass(nativeIsland1ID, classIsland);
  rmAddAreaToClass(nativeIsland1ID, classNativeIsland);
	rmAddAreaConstraint(nativeIsland1ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(nativeIsland1ID, false);
	rmSetAreaElevationType(nativeIsland1ID, cElevTurbulence);
	rmSetAreaElevationVariation(nativeIsland1ID, 2.0);
	rmSetAreaElevationMinFrequency(nativeIsland1ID, 0.09);
	rmSetAreaElevationOctaves(nativeIsland1ID, 3);
	rmSetAreaElevationPersistence(nativeIsland1ID, 0.2);
	rmSetAreaElevationNoiseBias(nativeIsland1ID, 1);
  if (cNumberNonGaiaPlayers <=2)
    rmSetAreaLocation(nativeIsland1ID, .5, .8);
  else
    rmSetAreaLocation(nativeIsland1ID, 0.5, 0.6);
	rmBuildArea(nativeIsland1ID);

  int nativeIsland2ID=rmCreateArea("native island 2");
	rmSetAreaSize(nativeIsland2ID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaCoherence(nativeIsland2ID, 0.8);
	rmSetAreaBaseHeight(nativeIsland2ID, 2.0);
	rmSetAreaSmoothDistance(nativeIsland2ID, 20);
	rmSetAreaMix(nativeIsland2ID, baseMix);
	rmAddAreaToClass(nativeIsland2ID, classIsland);
  rmAddAreaToClass(nativeIsland2ID, classNativeIsland);
	rmAddAreaConstraint(nativeIsland2ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(nativeIsland2ID, false);
	rmSetAreaElevationType(nativeIsland2ID, cElevTurbulence);
	rmSetAreaElevationVariation(nativeIsland2ID, 2.0);
	rmSetAreaElevationMinFrequency(nativeIsland2ID, 0.09);
	rmSetAreaElevationOctaves(nativeIsland2ID, 3);
	rmSetAreaElevationPersistence(nativeIsland2ID, 0.2);
	rmSetAreaElevationNoiseBias(nativeIsland2ID, 1);
  if (cNumberNonGaiaPlayers <=2)
    rmSetAreaLocation(nativeIsland2ID, .5, .2);
  else if (cNumberNonGaiaPlayers ==3)
    rmSetAreaLocation(nativeIsland2ID, .6, .5);
  else
    rmSetAreaLocation(nativeIsland2ID, 0.5, 0.4);
	rmBuildArea(nativeIsland2ID);

  int nativeIsland3ID=rmCreateArea("native island 3");
	rmSetAreaSize(nativeIsland3ID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaCoherence(nativeIsland3ID, 0.8);
	rmSetAreaBaseHeight(nativeIsland3ID, 2.0);
	rmSetAreaSmoothDistance(nativeIsland3ID, 20);
	rmSetAreaMix(nativeIsland3ID, baseMix);
	rmAddAreaToClass(nativeIsland3ID, classIsland);
  rmAddAreaToClass(nativeIsland3ID, classNativeIsland);
	rmAddAreaConstraint(nativeIsland3ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(nativeIsland3ID, false);
	rmSetAreaElevationType(nativeIsland3ID, cElevTurbulence);
	rmSetAreaElevationVariation(nativeIsland3ID, 2.0);
	rmSetAreaElevationMinFrequency(nativeIsland3ID, 0.09);
	rmSetAreaElevationOctaves(nativeIsland3ID, 3);
	rmSetAreaElevationPersistence(nativeIsland3ID, 0.2);
	rmSetAreaElevationNoiseBias(nativeIsland3ID, 1);
  if (cNumberNonGaiaPlayers <=2)
    rmSetAreaLocation(nativeIsland3ID, .8, .5);
  else
    rmSetAreaLocation(nativeIsland3ID, 0.22, 0.78);
	rmBuildArea(nativeIsland3ID);

  int nativeIsland4ID=rmCreateArea("native island 4");
	rmSetAreaSize(nativeIsland4ID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaCoherence(nativeIsland4ID, 0.8);
	rmSetAreaBaseHeight(nativeIsland4ID, 2.0);
	rmSetAreaSmoothDistance(nativeIsland4ID, 20);
	rmSetAreaMix(nativeIsland4ID, baseMix);
	rmAddAreaToClass(nativeIsland4ID, classIsland);
  rmAddAreaToClass(nativeIsland4ID, classNativeIsland);
	rmAddAreaConstraint(nativeIsland4ID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(nativeIsland4ID, false);
	rmSetAreaElevationType(nativeIsland4ID, cElevTurbulence);
	rmSetAreaElevationVariation(nativeIsland4ID, 2.0);
	rmSetAreaElevationMinFrequency(nativeIsland4ID, 0.09);
	rmSetAreaElevationOctaves(nativeIsland4ID, 3);
	rmSetAreaElevationPersistence(nativeIsland4ID, 0.2);
	rmSetAreaElevationNoiseBias(nativeIsland4ID, 1);
  if (cNumberNonGaiaPlayers <=2)
    rmSetAreaLocation(nativeIsland4ID, .2, .5);
  else
    rmSetAreaLocation(nativeIsland4ID, 0.78, 0.22);
	rmBuildArea(nativeIsland4ID);

  // Trade Islands 

  int portSite1 = rmCreateArea ("port_site1");
  rmSetAreaSize(portSite1, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
  rmSetAreaLocation(portSite1, 0.18+rmXTilesToFraction(15), 0.18+rmXTilesToFraction(15));
  rmSetAreaMix(portSite1, baseMix);
  rmSetAreaCoherence(portSite1, 1);
  rmSetAreaSmoothDistance(portSite1, 15);
  rmSetAreaBaseHeight(portSite1, 2.5);
  rmAddAreaToClass(portSite1, classIsland);
  rmAddAreaToClass(portSite1, classTradeIsland);
  rmAddAreaConstraint(portSite1, islandConstraint);
  rmBuildArea(portSite1);

  int portSite2 = rmCreateArea ("port_site2");
  rmSetAreaSize(portSite2, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
  rmSetAreaLocation(portSite2, 0.82-rmXTilesToFraction(15), 0.82-rmXTilesToFraction(15));
  rmSetAreaMix(portSite2, baseMix);
  rmSetAreaCoherence(portSite2, 1);
  rmSetAreaSmoothDistance(portSite2, 15);
  rmSetAreaBaseHeight(portSite2, 2.5);
  rmAddAreaToClass(portSite2, classIsland);
  rmAddAreaToClass(portSite2, classTradeIsland);
  rmAddAreaConstraint(portSite2, islandConstraint);
  rmBuildArea(portSite2);

  if (cNumberNonGaiaPlayers >2){
    int portSite3 = rmCreateArea ("port_site3");
    rmSetAreaSize(portSite3, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
    rmSetAreaMix(portSite3, baseMix);
    rmSetAreaCoherence(portSite3, 1);
    rmSetAreaSmoothDistance(portSite3, 15);
    rmSetAreaBaseHeight(portSite3, 2.5);
    rmAddAreaToClass(portSite3, classIsland);
    rmAddAreaToClass(portSite3, classTradeIsland);
    rmAddAreaConstraint(portSite3, islandConstraint);
    rmSetAreaLocation(portSite3, 0.05+rmXTilesToFraction(25), 0.5);
    rmBuildArea(portSite3);

    int portSite4 = rmCreateArea ("port_site4");
    rmSetAreaSize(portSite4, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
    rmSetAreaLocation(portSite4, 0.5,0.95-rmXTilesToFraction(25));
    rmSetAreaMix(portSite4, baseMix);
    rmSetAreaCoherence(portSite4, 1);
    rmSetAreaSmoothDistance(portSite4, 15);
    rmSetAreaBaseHeight(portSite4, 2.5);
    rmAddAreaToClass(portSite4, classIsland);
    rmAddAreaToClass(portSite4, classTradeIsland);
    rmAddAreaConstraint(portSite4, islandConstraint);
    rmBuildArea(portSite4);

    int portSite5 = rmCreateArea ("port_site5");
    rmSetAreaSize(portSite5, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
    rmSetAreaLocation(portSite5, 0.5,0.05+rmXTilesToFraction(25));
    rmSetAreaMix(portSite5, baseMix);
    rmSetAreaCoherence(portSite5, 1);
    rmSetAreaSmoothDistance(portSite5, 15);
    rmSetAreaBaseHeight(portSite5, 2.5);
    rmAddAreaToClass(portSite5, classIsland);
    rmAddAreaToClass(portSite5, classTradeIsland);
    rmAddAreaConstraint(portSite5, islandConstraint);
    rmBuildArea(portSite5);

    int portSite6 = rmCreateArea ("port_site6");
    rmSetAreaSize(portSite6, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
    rmSetAreaLocation(portSite6, 0.95-rmXTilesToFraction(25), 0.5);
    rmSetAreaMix(portSite6, baseMix);
    rmSetAreaCoherence(portSite6, 1);
    rmSetAreaSmoothDistance(portSite6, 15);
    rmSetAreaBaseHeight(portSite6, 2.5);
    rmAddAreaToClass(portSite6, classIsland);
    rmAddAreaToClass(portSite6, classTradeIsland);
    rmAddAreaConstraint(portSite6, islandConstraint);
    rmBuildArea(portSite6);
  }


	    	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
  rmSetStatusText("",0.40);

  int tradeRouteID = rmCreateTradeRoute();
  rmSetObjectDefTradeRouteID(tradeRouteID);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 1.0);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
  rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.45);

  bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

  int tradeRouteID2 = rmCreateTradeRoute();
  rmSetObjectDefTradeRouteID(tradeRouteID2);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.55, 0.00);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.05);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.55, 0.00);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.18, 0.18);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.05, 0.5);
  rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.55);

  bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");
  
	// ---------- Place Players ---------------------------------------------------------------------------------------

  if (cNumberNonGaiaPlayers <=2){
      rmSetPlacementSection(0.375, 0.374);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }
  if (cNumberNonGaiaPlayers ==3){
      rmSetPlacementSection(0.125, 0.791);
      rmPlacePlayersCircular(0.27, 0.27, 0);
  }
  if (cNumberNonGaiaPlayers ==4){
      rmSetPlacementSection(0.125, 0.875);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }
  if (cNumberNonGaiaPlayers ==5){
      rmSetPlacementSection(0.125, 0.925);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }
  if (cNumberNonGaiaPlayers ==6){
      rmSetPlacementSection(0.125, 0.959);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }
  if (cNumberNonGaiaPlayers ==7){
      rmSetPlacementSection(0.125, 0.982);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }
  if (cNumberNonGaiaPlayers ==8){
      rmSetPlacementSection(0.125, 0.999);
      rmPlacePlayersCircular(0.25, 0.25, 0);
  }

	for(i=1; <cNumberPlayers)
	{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmSetAreaSize(playerID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	  rmSetAreaCoherence(playerID, 0.5);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, baseMix);
    rmAddAreaToClass(playerID, classIsland);
    rmAddAreaToClass(playerID, classStartingIsland);
    rmAddAreaConstraint(playerID, islandConstraint);
    rmAddAreaConstraint(playerID, islandEdgeConstraint);
    rmAddAreaConstraint(playerID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerID, cElevTurbulence);
    rmSetAreaElevationVariation(playerID, 4.0);
    rmSetAreaElevationMinFrequency(playerID, 0.09);
    rmSetAreaElevationOctaves(playerID, 3);
    rmSetAreaElevationPersistence(playerID, 0.2);
    rmSetAreaElevationNoiseBias(playerID, 1);	 
    rmEchoInfo("Player area"+i);   	

	}


	// Build the areas. 
	rmBuildAllAreas();
	
    

  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
  
	// Natives

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

  int controllerID3 = rmCreateObjectDef("Controler 3");
  rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
  rmSetObjectDefMinDistance(controllerID3, 0.0);
  rmSetObjectDefMaxDistance(controllerID3, 30.0);
  rmAddObjectDefConstraint(controllerID3, avoidImpassableLand);
  rmAddObjectDefConstraint(controllerID3, ferryOnShore); 

  int controllerID4 = rmCreateObjectDef("Controler 4");
  rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
  rmSetObjectDefMinDistance(controllerID4, 0.0);
  rmSetObjectDefMaxDistance(controllerID4, 30.0);
  rmAddObjectDefConstraint(controllerID4, avoidImpassableLand);
  rmAddObjectDefConstraint(controllerID4, ferryOnShore);

  if (cNumberNonGaiaPlayers <=2){
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5, 0.8);
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.5, 0.2);
    rmPlaceObjectDefAtLoc(controllerID3, 0, 0.2, 0.5);
    rmPlaceObjectDefAtLoc(controllerID4, 0, 0.8, 0.5);
  }

  else if (cNumberNonGaiaPlayers ==3) {
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.22, 0.78);
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.6, 0.5);
    rmPlaceObjectDefAtLoc(controllerID3, 0, 0.5, 0.6);
    rmPlaceObjectDefAtLoc(controllerID4, 0, 0.78, 0.22);
  }

  else {
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.22, 0.78);
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.5, 0.4);
    rmPlaceObjectDefAtLoc(controllerID3, 0, 0.5, 0.6);
    rmPlaceObjectDefAtLoc(controllerID4, 0, 0.78, 0.22);
  }


  vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
  vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
  vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
  vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

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
  rmAddClosestPointConstraint(playerEdgeConstraint);

  vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
  rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

  rmClearClosestPointConstraints();

  int pirateportID2 = -1;
  pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
  rmAddClosestPointConstraint(portOnShore);
  rmAddClosestPointConstraint(playerEdgeConstraint);

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
  rmAddClosestPointConstraint(playerEdgeConstraint);

  vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
  rmPlaceObjectDefAtLoc(piratewaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

  rmClearClosestPointConstraints();

  int pirateportID3 = -1;
  pirateportID3 = rmCreateGrouping("pirate port 3", "Platform_Universal");
  rmAddClosestPointConstraint(portOnShore);
  rmAddClosestPointConstraint(playerEdgeConstraint);

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

  // check for KOTH game mode
	if (rmGetIsKOTH())
	{       
    float xLoc = 0.5;
    float yLoc = 0.5;
    float walk = 0.0;

    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
    rmEchoInfo("XLOC = "+xLoc);
    rmEchoInfo("XLOC = "+yLoc);
  }

  // Trade Route Sockets

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 5.0);

  rmPlaceObjectDefAtLoc(socketID, 0, 0.82-rmXTilesToFraction(15), 0.82-rmXTilesToFraction(15));

  if (cNumberNonGaiaPlayers >2){
    rmPlaceObjectDefAtLoc(socketID, 0, 0.5,0.95-rmXTilesToFraction(20));
    rmPlaceObjectDefAtLoc(socketID, 0, 0.95-rmXTilesToFraction(20), 0.5);
  }

  int socketID2=rmCreateObjectDef("sockets to dock Trade Posts 2");
	rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID2, true);
	rmSetObjectDefMinDistance(socketID2, 0.0);
	rmSetObjectDefMaxDistance(socketID2, 5.0);


  rmPlaceObjectDefAtLoc(socketID2, 0, 0.18+rmXTilesToFraction(15), 0.18+rmXTilesToFraction(15));

  if (cNumberNonGaiaPlayers >2){
    rmPlaceObjectDefAtLoc(socketID2, 0, 0.5,0.05+rmXTilesToFraction(20));
    rmPlaceObjectDefAtLoc(socketID2, 0, 0.05+rmXTilesToFraction(20), 0.5);
  }


	// --------------- Make load bar move. ----------------------------------------------------------------------------
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
	rmAddObjectDefItem(playerGoldID, "mineGold", 1, 0);
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
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 16, 5.0);
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

	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);

	for(i=1; <cNumberPlayers) {
    
    
    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
		rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 


    // Place additional Islands

    // Big Islands

    int northIsland=rmCreateArea("north "+i);
    rmSetAreaSize(northIsland, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(900.0));
    rmAddAreaToClass(northIsland, classIsland);
    rmSetAreaWarnFailure(northIsland, false);
	  rmSetAreaCoherence(northIsland, 0.5);
    rmSetAreaBaseHeight(northIsland, 2.0);
    rmSetAreaSmoothDistance(northIsland, 20);
    rmSetAreaMix(northIsland, baseMix);
    rmAddAreaToClass(northIsland, classIsland);
    rmAddAreaToClass(northIsland, classBuildingIsland);
    rmAddAreaConstraint(northIsland, islandConstraint);
    rmAddAreaConstraint(northIsland, islandEdgeConstraint);
    rmAddAreaConstraint(northIsland, islandAvoidTradeRoute);
    rmSetAreaElevationType(northIsland, cElevTurbulence);
    rmSetAreaElevationVariation(northIsland, 4.0);
    rmSetAreaElevationMinFrequency(northIsland, 0.09);
    rmSetAreaElevationOctaves(northIsland, 3);
    rmSetAreaElevationPersistence(northIsland, 0.2);
    rmSetAreaElevationNoiseBias(northIsland, 1);
    rmSetAreaLocation(northIsland,  rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)+90));	 
    rmBuildArea(northIsland);   

    int southIsland=rmCreateArea("south "+i);
    rmSetAreaSize(southIsland, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(900.0));
    rmAddAreaToClass(southIsland, classIsland);
    rmSetAreaWarnFailure(southIsland, false);
	  rmSetAreaCoherence(southIsland, 0.5);
    rmSetAreaBaseHeight(southIsland, 2.0);
    rmSetAreaSmoothDistance(southIsland, 20);
    rmSetAreaMix(southIsland, baseMix);
    rmAddAreaToClass(southIsland, classIsland);
    rmAddAreaToClass(southIsland, classBuildingIsland);
    rmAddAreaConstraint(southIsland, islandConstraint);
    rmAddAreaConstraint(southIsland, islandEdgeConstraint);
    rmAddAreaConstraint(southIsland, islandAvoidTradeRoute);
    rmSetAreaElevationType(southIsland, cElevTurbulence);
    rmSetAreaElevationVariation(southIsland, 4.0);
    rmSetAreaElevationMinFrequency(southIsland, 0.09);
    rmSetAreaElevationOctaves(southIsland, 3);
    rmSetAreaElevationPersistence(southIsland, 0.2);
    rmSetAreaElevationNoiseBias(southIsland, 1);
    rmSetAreaLocation(southIsland,  rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)-90));	 
    rmBuildArea(southIsland);   

    // Small Islands

    int eastIsland=rmCreateArea("east "+i);
    rmSetAreaSize(eastIsland, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmAddAreaToClass(eastIsland, classIsland);
    rmSetAreaWarnFailure(eastIsland, false);
	  rmSetAreaCoherence(eastIsland, 0.5);
    rmSetAreaBaseHeight(eastIsland, 2.0);
    rmSetAreaSmoothDistance(eastIsland, 20);
    rmSetAreaMix(eastIsland, baseMix);
    rmAddAreaToClass(eastIsland, classIsland);
    rmAddAreaToClass(eastIsland, classGoldIsland);
    rmAddAreaConstraint(eastIsland, islandConstraint);
    rmAddAreaConstraint(eastIsland, islandEdgeConstraint);
    rmAddAreaConstraint(eastIsland, islandAvoidTradeRoute);
    rmSetAreaElevationType(eastIsland, cElevTurbulence);
    rmSetAreaElevationVariation(eastIsland, 4.0);
    rmSetAreaElevationMinFrequency(eastIsland, 0.09);
    rmSetAreaElevationOctaves(eastIsland, 3);
    rmSetAreaElevationPersistence(eastIsland, 0.2);
    rmSetAreaElevationNoiseBias(eastIsland, 1);
    rmSetAreaLocation(eastIsland,  rmXMetersToFraction(xsVectorGetX(TCLoc)+90), rmZMetersToFraction(xsVectorGetZ(TCLoc)));	 
    rmBuildArea(eastIsland);   

    int westIsland=rmCreateArea("west "+i);
    rmSetAreaSize(westIsland, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmAddAreaToClass(westIsland, classIsland);
    rmSetAreaWarnFailure(westIsland, false);
	  rmSetAreaCoherence(westIsland, 0.5);
    rmSetAreaBaseHeight(westIsland, 2.0);
    rmSetAreaSmoothDistance(westIsland, 20);
    rmSetAreaMix(westIsland, baseMix);
    rmAddAreaToClass(westIsland, classIsland);
    rmAddAreaToClass(westIsland, classGoldIsland);
    rmAddAreaConstraint(westIsland, islandConstraint);
    rmAddAreaConstraint(westIsland, islandEdgeConstraint);
    rmAddAreaConstraint(westIsland, islandAvoidTradeRoute);
    rmSetAreaElevationType(westIsland, cElevTurbulence);
    rmSetAreaElevationVariation(westIsland, 4.0);
    rmSetAreaElevationMinFrequency(westIsland, 0.09);
    rmSetAreaElevationOctaves(westIsland, 3);
    rmSetAreaElevationPersistence(westIsland, 0.2);
    rmSetAreaElevationNoiseBias(westIsland, 1);
    rmSetAreaLocation(westIsland,  rmXMetersToFraction(xsVectorGetX(TCLoc)-90), rmZMetersToFraction(xsVectorGetZ(TCLoc)));	 
    rmBuildArea(westIsland);   

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    
    // Place starting nugget
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    
    // Place HC Water Flag
    rmClearClosestPointConstraints();
		int waterSpawnPointID = 0;

    int colonyShipID=rmCreateObjectDef("colony ship 2"+i);
    rmAddObjectDefItem(colonyShipID, "zpCatamaran", 1, 0.0);
    rmSetObjectDefMinDistance(colonyShipID, 2.0);
    rmSetObjectDefMaxDistance(colonyShipID, 5.0);
    
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
    rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
    
     
		rmClearClosestPointConstraints();
  }

  // Random Islands

  numTries=2.5*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int extraIsland=rmCreateArea("extraIsland "+i);
    rmSetAreaWarnFailure(extraIsland, false);
    rmSetAreaSize(extraIsland, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
    rmSetAreaCoherence(extraIsland, 0.7);
    rmSetAreaSmoothDistance(extraIsland, 15);
    rmSetAreaMix(extraIsland, baseMix);
    rmSetAreaBaseHeight(extraIsland, 2.5);
    rmAddAreaToClass(extraIsland, classIsland);
    rmAddAreaToClass(extraIsland, classExtraIsland);
    rmAddAreaConstraint(extraIsland, islandConstraint);
    rmAddAreaConstraint(extraIsland, islandAvoidTradeRoute);
    rmAddAreaConstraint(extraIsland, playerEdgeConstraint);
    rmAddAreaConstraint(extraIsland, staySouthPart);

    if(rmBuildArea(extraIsland)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount++;
      
      if(failCount==5)
        break;
    }
    
    else
      failCount=0; 
  } 

  for (i=0; <numTries) {   
    int extraIsland2=rmCreateArea("extraIsland2 "+i);
    rmSetAreaWarnFailure(extraIsland2, false);
    rmSetAreaSize(extraIsland2, rmAreaTilesToFraction(400), rmAreaTilesToFraction(700));
    rmSetAreaCoherence(extraIsland2, 0.7);
    rmSetAreaSmoothDistance(extraIsland2, 15);
    rmSetAreaMix(extraIsland2, baseMix);
    rmSetAreaBaseHeight(extraIsland2, 2.5);
    rmAddAreaToClass(extraIsland2, classIsland);
    rmAddAreaToClass(extraIsland2, classExtraIsland);
    rmAddAreaConstraint(extraIsland2, islandConstraint);
    rmAddAreaConstraint(extraIsland2, islandAvoidTradeRoute);
    rmAddAreaConstraint(extraIsland2, playerEdgeConstraint);
    rmAddAreaConstraint(extraIsland2, stayNorthHalf);

    if(rmBuildArea(extraIsland2)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount++;
      
      if(failCount==5)
        break;
    }
    
    else
      failCount=0; 
  } 


  // Additional Resources

  // Gold

  int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidAll);
  rmAddObjectDefConstraint(goldID, avoidWater4);
	rmAddObjectDefConstraint(goldID, avoidGold);
  rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(goldID, avoidNativeIslands);
  rmAddObjectDefConstraint(goldID, avoidBuildingIslands);
  rmAddObjectDefConstraint(goldID, avoidTradeIslands);
  rmAddObjectDefConstraint(goldID, avoidExtraIslands);
  rmAddObjectDefConstraint(goldID, avoidStartingIslands);
  rmAddObjectDefConstraint(goldID, avoidTP);
	rmPlaceObjectDefAtLoc(goldID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

  // Forests

  int villageTreeID=rmCreateObjectDef("village tree");
  rmAddObjectDefItem(villageTreeID, "TreeCaribbean", 1, 0.0);
  rmSetObjectDefMinDistance(villageTreeID, 0.0);
  rmSetObjectDefMaxDistance(villageTreeID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(villageTreeID, avoidAll);
  rmAddObjectDefConstraint(villageTreeID, avoidStartingIslands);
  rmAddObjectDefConstraint(villageTreeID, avoidNativeIslands);
  rmAddObjectDefConstraint(villageTreeID, avoidBuildingIslands);
  rmAddObjectDefConstraint(villageTreeID, avoidTradeIslands);
  rmAddObjectDefConstraint(villageTreeID, avoidKOTH);
  rmAddObjectDefConstraint(villageTreeID, shortAvoidImpassableLand);  
  rmPlaceObjectDefAtLoc(villageTreeID, 0, 0.5, 0.5, 200*cNumberNonGaiaPlayers);

  // Random Trees
  int randomTreeID=rmCreateObjectDef("random tree");
  rmAddObjectDefItem(randomTreeID, "TreeCaribbean", 1, 0.0);
  rmSetObjectDefMinDistance(randomTreeID, 0.0);
  rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
  rmAddObjectDefConstraint(randomTreeID, avoidAll); 
  rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);
   
  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Nuggets
  int nugget1= rmCreateObjectDef("nugget 1"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 4);
  rmSetObjectDefMinDistance(nugget1, 0.0);
  rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.3));
  rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, avoidStartingIslands);
  rmAddObjectDefConstraint(nugget1, avoidWater8);
  rmAddObjectDefConstraint(nugget1, avoidWokou);
  rmAddObjectDefConstraint(nugget1, avoidNugget);
  rmAddObjectDefConstraint(nugget1, avoidPirates);
  rmAddObjectDefConstraint(nugget1, staySouthPart);
  rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 

  int nugget2= rmCreateObjectDef("nugget 2"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 4);
  rmSetObjectDefMinDistance(nugget2, 0.0);
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
  rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, avoidStartingIslands);
  rmAddObjectDefConstraint(nugget2, avoidWater8);
  rmAddObjectDefConstraint(nugget2, avoidWokou);
  rmAddObjectDefConstraint(nugget2, avoidNugget);
  rmAddObjectDefConstraint(nugget2, avoidPirates);
  rmAddObjectDefConstraint(nugget2, stayNorthHalf);
  rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2.5); 

  // Whales
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
  rmAddObjectDefConstraint(whaleID, staySouthPart);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3.5); 

  int whaleID2=rmCreateObjectDef("whale2");
	rmAddObjectDefItem(whaleID2, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID2, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID2, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID2, whaleLand);
  rmAddObjectDefConstraint(whaleID2, stayNorthHalf);
	rmPlaceObjectDefAtLoc(whaleID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3.5); 

	// Fishes

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

	int fish2ID=rmCreateObjectDef("fish 2");
	rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, avoidFish2);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}
	
  // Water nuggets
  int nuggetCount = 3;

  int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2b, avoidLand);
  rmAddObjectDefConstraint(nugget2b, avoidNuggetWater2);
  rmAddObjectDefConstraint(nugget2b, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2b, staySouthPart);
  rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount/2);

  int nuggetB= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nuggetB, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetB, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetB, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetB, avoidLand);
  rmAddObjectDefConstraint(nuggetB, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetB, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetB, staySouthPart);
  rmPlaceObjectDefPerPlayer(nuggetB, false, nuggetCount);

  int nnugget2bNorth = rmCreateObjectDef("nugget water hard 2" + i); 
  rmAddObjectDefItem(nnugget2bNorth, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nnugget2bNorth, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nnugget2bNorth, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nnugget2bNorth, avoidLand);
  rmAddObjectDefConstraint(nnugget2bNorth, avoidNuggetWater2);
  rmAddObjectDefConstraint(nnugget2bNorth, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nnugget2bNorth, stayNorthHalf);
  rmPlaceObjectDefPerPlayer(nnugget2bNorth, false, nuggetCount/2);

  int nuggetBNorth= rmCreateObjectDef("nugget water 2" + i); 
  rmAddObjectDefItem(nuggetBNorth, "ypnuggetBoat", 1, 0.0)    ;
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetBNorth, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetBNorth, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetBNorth, avoidLand);
  rmAddObjectDefConstraint(nuggetBNorth, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetBNorth, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetBNorth, stayNorthHalf);
  rmPlaceObjectDefPerPlayer(nuggetBNorth, false, nuggetCount);

  // Starter shipment triggers

  // ------Triggers--------//

  string pirate1ID = "6";
  string pirate2ID = "65";
  string wokou1ID = "97";
  string wokou2ID = "113";

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