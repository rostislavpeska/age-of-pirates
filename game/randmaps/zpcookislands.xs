// COOK ISLANDS 1.0

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
  string seaType = "ZP Cook Islands 4";
  //string seaType = "ZP Cook Islands"; // This obe works with latest AoP Beta
  //string seaType = "Ceylon Coast"; // While custom water is missing
  string startTreeType = "ypTreeCeylon";
  string forestType = "Ceylon Forest";
  string cliffType = "ceylon";
  string mapType1 = "cookislands";
  string mapType2 = "grass";
  string huntable1 = "zpFeralPig";
  string huntable2 = "ypWildElephant";
  string fish1 = "ypFishMolaMola";
  string fish2 = "FishMahi";
  string fish3 = "ypSquid";
  string whale1 = "MinkeWhale";
  string lightingType = "spcjc5a";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";
  
	// Define Natives
  int subCiv0=-1;
  int subCiv1=-1;
  int subCiv2=-1;

  if (rmAllocateSubCivs(3) == true)
  {
  subCiv0=rmGetCivID("natpirates");
  rmEchoInfo("subCiv0 is pirates "+subCiv0);
  if (subCiv0 >= 0)
      rmSetSubCiv(0, "natpirates");

  subCiv1=rmGetCivID("zpScientists");
  rmEchoInfo("subCiv1 is zpScientists "+subCiv1);
  if (subCiv1 >= 0)
  rmSetSubCiv(1, "zpScientists");

  subCiv2=rmGetCivID("MaoriNatives");
  rmEchoInfo("subCiv2 is MaoriNatives "+subCiv2);
  if (subCiv2 >= 0)
      rmSetSubCiv(2, "MaoriNatives");

  }

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=25000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 30000;
  if (cNumberNonGaiaPlayers == 3)
		playerTiles = 35000;
  if (cNumberNonGaiaPlayers == 2)
		playerTiles = 45000;
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(0.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("water");
	rmSetLightingSet("spcjc5a");
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
  int classTeamIsland=rmDefineClass("teamIsland");
  int classBonusIsland=rmDefineClass("bonusIsland");
  int classTeamCliff=rmDefineClass("teamCliff");
  int classUnderwaterPatch=rmDefineClass("underwaterPatch");

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

  int playerIslandConstraint=rmCreatePieConstraint("player island constraint", 0.5, 0.5, rmXFractionToMeters(0.2), rmXFractionToMeters(0.5), rmDegreesToRadians(0), rmDegreesToRadians(360));
  int bonusIslandConstraint=rmCreatePieConstraint("bonus island constraint", 0.5, 0.5, rmXFractionToMeters(0.13), rmXFractionToMeters(0.22), rmDegreesToRadians(0), rmDegreesToRadians(360));
  if (cNumberNonGaiaPlayers<6)
    int underwaterPatchConstraint=rmCreatePieConstraint("underwater patch constraint", 0.5, 0.5, 60, rmXFractionToMeters(0.15), rmDegreesToRadians(0), rmDegreesToRadians(360));
  else
    underwaterPatchConstraint=rmCreatePieConstraint("underwater patch constraint", 0.5, 0.5, 80, rmXFractionToMeters(0.14), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 10.0);
  int avoidTPLong=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets far", "SocketTradeRoute", 35.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
  int avoidLandLong = rmCreateTerrainDistanceConstraint("ship avoid land long", "land", true, 20.0);
  int avoidLandShort = rmCreateTerrainDistanceConstraint("ship avoid land short", "land", true, 5.0);
  int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion of island", .35, .55, .65, .35);
  int northConstraint = rmCreateBoxConstraint("huntable constraint for north side of island", .25, .55, .8, .85);
  int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 12.0);
  int avoidTCLong=rmCreateTypeDistanceConstraint("stay away from TC by far", "TownCenter", 30.0);

	// Island Constraints  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 58.0);
  int islandConstraintShort=rmCreateClassDistanceConstraint("islands avoid each other short", classIsland, 38.0);
  if (cNumberNonGaiaPlayers<=2){
    int avoidBonusIslands=rmCreateClassDistanceConstraint("avoid bonus island constraint", classBonusIsland, 23.0);
    int avoidBonusIslandsShort=rmCreateClassDistanceConstraint("avoid bonus island constraint short", classBonusIsland, 22.0);
  }
  else{
    avoidBonusIslands=rmCreateClassDistanceConstraint("avoid bonus island constraint", classBonusIsland, 28.0);
    avoidBonusIslandsShort=rmCreateClassDistanceConstraint("avoid bonus island constraint short", classBonusIsland, 27.0);
  }
  int avoidTeamCliffs=rmCreateClassDistanceConstraint("avoid team cliff constraint", classTeamCliff, 28.0);
  int avoidTeamCliffsShort=rmCreateClassDistanceConstraint("avoid team cliff constraint short", classTeamCliff, 6.0);
  int avoidTeamIslands=rmCreateClassDistanceConstraint("avoid team island constraint", classTeamIsland, 28.0);
  int avoidTeamIslandsShort=rmCreateClassDistanceConstraint("avoid team island short", classTeamIsland, 20.0);
  int avoidTeamIslands1=rmCreateClassDistanceConstraint("avoid team island 1", classTeamIsland, 1.0);
  int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
  
	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
	int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
  int avoidFish3=rmCreateTypeDistanceConstraint("fish v fish3", fish3, 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "zpJadeMine", 45.0);
  int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "zpPearlSource", 40.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
  int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
  int avoidNuggetWater3=rmCreateTypeDistanceConstraint("avoid water nuggets3", "abstractNugget", 60.0);
  int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 
  int avoidPatch=rmCreateClassDistanceConstraint("stay away from water patch", classUnderwaterPatch, 40.0);

  int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 30.0);
  int avoidScientists=rmCreateTypeDistanceConstraint("avoid socket Scientists", "zpSocketScientists", 30.0);
  int avoidMaori=rmCreateTypeDistanceConstraint("avoid socket Maori", "zpSocketMaori", 30.0);

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
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 19.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 4.5);

  // things
	int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
  int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
  
  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 30.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
  int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
  int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
	int flagVsScientists1 = rmCreateTypeDistanceConstraint("flag avoid Scientists 1", "zpNativeWaterspawnFlag1", 40);
  int flagVsScientists2 = rmCreateTypeDistanceConstraint("flag avoid Scientists 2", "zpNativeWaterspawnFlag2", 40);
  int flagVsScientists1Short = rmCreateTypeDistanceConstraint("flag avoid Scientists 1 short", "zpNativeWaterspawnFlag1", 20);
  int flagVsScientists2Short = rmCreateTypeDistanceConstraint("flag avoid Scientists 2 short", "zpNativeWaterspawnFlag2", 20);
  int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

   //Trade Route Contstraints
   int islandAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route island short", 4.0);
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

  // ***************** Transparent water **************************************

  // Inner lakes with transparent water

  int deadSeaLakeOuterID=rmCreateArea("Lake Eyre03");
	rmSetAreaWaterType(deadSeaLakeOuterID, "ZP Cook Islands 3");
	rmSetAreaSize(deadSeaLakeOuterID, 0.15, 0.15);
	rmSetAreaCoherence(deadSeaLakeOuterID, 1.0);
	rmSetAreaLocation(deadSeaLakeOuterID, 0.5, 0.5);
	rmSetAreaSmoothDistance(deadSeaLakeOuterID, 10);
	rmBuildArea(deadSeaLakeOuterID);

  int deadSeaLakeMediumID=rmCreateArea("Lake Eyre02");
	rmSetAreaWaterType(deadSeaLakeMediumID, "ZP Cook Islands 2");
	rmSetAreaSize(deadSeaLakeMediumID, 0.1, 0.1);
	rmSetAreaCoherence(deadSeaLakeMediumID, 1.0);
	rmSetAreaLocation(deadSeaLakeMediumID, 0.5, 0.5);
	rmSetAreaSmoothDistance(deadSeaLakeMediumID, 10);
	rmBuildArea(deadSeaLakeMediumID);

  int deadSeaLakeDeepID=rmCreateArea("Lake Eyre");
	rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Cook Islands");
	rmSetAreaSize(deadSeaLakeDeepID, 0.06, 0.06);
	rmSetAreaCoherence(deadSeaLakeDeepID, 1.0);
	rmSetAreaLocation(deadSeaLakeDeepID, 0.5, 0.5);
	rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);
	rmBuildArea(deadSeaLakeDeepID);

	    	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

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

  if (cNumberNonGaiaPlayers <=2){
      rmSetPlacementSection(0.375, 0.374);
      rmPlacePlayersCircular(0.4, 0.4, 0);
  }
  if (cNumberNonGaiaPlayers ==3){
      rmSetPlacementSection(0.125, 0.791);
      rmPlacePlayersCircular(0.37, 0.37, 0);
  }
  if (cNumberNonGaiaPlayers ==4){
      rmSetPlacementSection(0.125, 0.875);
      rmPlacePlayersCircular(0.4, 0.4, 0);
  }
  if (cNumberNonGaiaPlayers ==5){
      rmSetPlacementSection(0.125, 0.925);
      rmPlacePlayersCircular(0.35, 0.35, 0);
  }
  if (cNumberNonGaiaPlayers ==6){
      rmSetPlacementSection(0.125, 0.959);
      rmPlacePlayersCircular(0.35, 0.35, 0);
  }
  if (cNumberNonGaiaPlayers ==7){
      rmSetPlacementSection(0.125, 0.982);
      rmPlacePlayersCircular(0.3, 0.3, 0);
  }
  if (cNumberNonGaiaPlayers ==8){
      rmSetPlacementSection(0.125, 0.999);
      rmPlacePlayersCircular(0.3, 0.3, 0);
  }

  float isleSize = 0.00;
  if (cNumberTeams == 2)
    isleSize = (0.2 / cNumberTeams);
  else
    isleSize = (0.18 / cNumberTeams);
  rmEchoInfo("Isle size "+isleSize);

  int bonusIslandID = rmCreateArea ("bonus island");
  rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
  rmSetAreaLocation(bonusIslandID, 0.5, 0.7);
  rmSetAreaCoherence(bonusIslandID, 0.4);
  rmSetAreaMinBlobs(bonusIslandID, 8);
  rmSetAreaMaxBlobs(bonusIslandID, 12);
  rmSetAreaMinBlobDistance(bonusIslandID, 8.0);
  rmSetAreaMaxBlobDistance(bonusIslandID, 10.0);
  rmSetAreaSmoothDistance(bonusIslandID, 10);
  rmSetAreaHeightBlend(bonusIslandID, 2.0);
  rmSetAreaMix(bonusIslandID, baseMix);
    rmAddAreaTerrainLayer(bonusIslandID, "Ceylon\ground_sand1_Ceylon", 0, 6);
    rmAddAreaTerrainLayer(bonusIslandID, "Ceylon\ground_sand2_Ceylon", 6, 9);
    rmAddAreaTerrainLayer(bonusIslandID, "Ceylon\ground_sand3_Ceylon", 9, 12);
    rmAddAreaTerrainLayer(bonusIslandID, "Ceylon\ground_grass2_Ceylon", 12, 25);
  rmSetAreaBaseHeight(bonusIslandID, 2.5);
  rmAddAreaConstraint(bonusIslandID, islandConstraintShort);
  rmAddAreaConstraint(bonusIslandID, islandAvoidTradeRoute); 
  rmAddAreaConstraint(bonusIslandID, bonusIslandConstraint); 
  rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
  rmSetAreaElevationVariation(bonusIslandID, 4.0);
  rmSetAreaElevationPersistence(bonusIslandID, 0.2);
  rmSetAreaElevationNoiseBias(bonusIslandID, 1);
  rmAddAreaToClass(bonusIslandID, classIsland);
  rmSetAreaTerrainLayerVariance(bonusIslandID, false);
  rmAddAreaToClass(bonusIslandID, classBonusIsland);
  rmBuildArea(bonusIslandID);

  int bonusIslandID2 = rmCreateArea ("bonus island 2");
  rmSetAreaSize(bonusIslandID2, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
  rmSetAreaLocation(bonusIslandID2, 0.5, 0.3);
  rmSetAreaCoherence(bonusIslandID2, 0.4);
  rmSetAreaMinBlobs(bonusIslandID2, 8);
  rmSetAreaMaxBlobs(bonusIslandID2, 12);
  rmSetAreaMinBlobDistance(bonusIslandID2, 8.0);
  rmSetAreaMaxBlobDistance(bonusIslandID2, 10.0);
  rmSetAreaSmoothDistance(bonusIslandID2, 10);
  rmSetAreaHeightBlend(bonusIslandID2, 2.0);
  rmSetAreaMix(bonusIslandID2, baseMix);
    rmAddAreaTerrainLayer(bonusIslandID2, "Ceylon\ground_sand1_Ceylon", 0, 6);
    rmAddAreaTerrainLayer(bonusIslandID2, "Ceylon\ground_sand2_Ceylon", 6, 9);
    rmAddAreaTerrainLayer(bonusIslandID2, "Ceylon\ground_sand3_Ceylon", 9, 12);
    rmAddAreaTerrainLayer(bonusIslandID2, "Ceylon\ground_grass2_Ceylon", 12, 25);
  rmSetAreaBaseHeight(bonusIslandID2, 2.5);
  rmAddAreaConstraint(bonusIslandID2, islandConstraintShort);
  rmAddAreaConstraint(bonusIslandID2, islandAvoidTradeRoute); 
  rmAddAreaConstraint(bonusIslandID2, bonusIslandConstraint); 
  rmSetAreaElevationType(bonusIslandID2, cElevTurbulence);
  rmSetAreaElevationVariation(bonusIslandID2, 4.0);
  rmSetAreaElevationPersistence(bonusIslandID2, 0.2);
  rmSetAreaElevationNoiseBias(bonusIslandID2, 1);
  rmAddAreaToClass(bonusIslandID2, classIsland);
  rmAddAreaToClass(bonusIslandID2, classBonusIsland);
  rmBuildArea(bonusIslandID2);

  int bonusIslandID3 = rmCreateArea ("bonus island 3");
  rmSetAreaSize(bonusIslandID3, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
  rmSetAreaLocation(bonusIslandID3, 0.7, 0.5);
  rmSetAreaCoherence(bonusIslandID3, 0.4);
  rmSetAreaMinBlobs(bonusIslandID3, 8);
  rmSetAreaMaxBlobs(bonusIslandID3, 12);
  rmSetAreaMinBlobDistance(bonusIslandID3, 8.0);
  rmSetAreaMaxBlobDistance(bonusIslandID3, 10.0);
  rmSetAreaSmoothDistance(bonusIslandID3, 10);
  rmSetAreaHeightBlend(bonusIslandID3, 2.0);
  rmSetAreaMix(bonusIslandID3, baseMix);
    rmAddAreaTerrainLayer(bonusIslandID3, "Ceylon\ground_sand1_Ceylon", 0, 6);
    rmAddAreaTerrainLayer(bonusIslandID3, "Ceylon\ground_sand2_Ceylon", 6, 9);
    rmAddAreaTerrainLayer(bonusIslandID3, "Ceylon\ground_sand3_Ceylon", 9, 12);
    rmAddAreaTerrainLayer(bonusIslandID3, "Ceylon\ground_grass2_Ceylon", 12, 25);
  rmSetAreaBaseHeight(bonusIslandID3, 2.5);
  rmAddAreaConstraint(bonusIslandID3, islandConstraintShort);
  rmAddAreaConstraint(bonusIslandID3, islandAvoidTradeRoute); 
  rmAddAreaConstraint(bonusIslandID3, bonusIslandConstraint); 
  rmSetAreaElevationType(bonusIslandID3, cElevTurbulence);
  rmSetAreaElevationVariation(bonusIslandID3, 4.0);
  rmSetAreaElevationPersistence(bonusIslandID3, 0.2);
  rmSetAreaElevationNoiseBias(bonusIslandID3, 1);
  rmAddAreaToClass(bonusIslandID3, classIsland);
  rmAddAreaToClass(bonusIslandID3, classBonusIsland);
  rmBuildArea(bonusIslandID3);

  int bonusIslandID4 = rmCreateArea ("bonus island 4");
  rmSetAreaSize(bonusIslandID4, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
  rmSetAreaLocation(bonusIslandID4, 0.3, 0.5);
  rmSetAreaCoherence(bonusIslandID4, 0.4);
  rmSetAreaMinBlobs(bonusIslandID4, 8);
  rmSetAreaMaxBlobs(bonusIslandID4, 12);
  rmSetAreaMinBlobDistance(bonusIslandID4, 8.0);
  rmSetAreaMaxBlobDistance(bonusIslandID4, 10.0);
  rmSetAreaSmoothDistance(bonusIslandID4, 10);
  rmSetAreaHeightBlend(bonusIslandID4, 2.0);
  rmSetAreaMix(bonusIslandID4, baseMix);
    rmAddAreaTerrainLayer(bonusIslandID4, "Ceylon\ground_sand1_Ceylon", 0, 6);
    rmAddAreaTerrainLayer(bonusIslandID4, "Ceylon\ground_sand2_Ceylon", 6, 9);
    rmAddAreaTerrainLayer(bonusIslandID4, "Ceylon\ground_sand3_Ceylon", 9, 12);
    rmAddAreaTerrainLayer(bonusIslandID4, "Ceylon\ground_grass2_Ceylon", 12, 25);
  rmSetAreaBaseHeight(bonusIslandID4, 2.5);
  rmAddAreaConstraint(bonusIslandID4, islandConstraintShort);
  rmAddAreaConstraint(bonusIslandID4, islandAvoidTradeRoute); 
  rmAddAreaConstraint(bonusIslandID4, bonusIslandConstraint); 
  rmSetAreaElevationType(bonusIslandID4, cElevTurbulence);
  rmSetAreaElevationVariation(bonusIslandID4, 4.0);
  rmSetAreaElevationPersistence(bonusIslandID4, 0.2);
  rmSetAreaElevationNoiseBias(bonusIslandID4, 1);
  rmAddAreaToClass(bonusIslandID4, classIsland);
  rmAddAreaToClass(bonusIslandID4, classBonusIsland);
  rmBuildArea(bonusIslandID4);

  float playerFraction=rmAreaTilesToFraction(7500 - cNumberNonGaiaPlayers*300);

  if (cNumberNonGaiaPlayers ==3 ){
    for(i=0; <cNumberPlayers) {
      // Create the area.
      int teamCliffID1=rmCreateArea("team cliff 1"+i);
      rmSetAreaSize(teamCliffID1, rmAreaTilesToFraction(6000.0), rmAreaTilesToFraction(6000.0));
      rmSetAreaMinBlobs(teamCliffID1, 30);
      rmSetAreaMaxBlobs(teamCliffID1, 45);
      rmSetAreaMinBlobDistance(teamCliffID1, 20.0);
      rmSetAreaMaxBlobDistance(teamCliffID1, 40.0);
      rmSetAreaCoherence(teamCliffID1, 0.45);
      rmSetAreaBaseHeight(teamCliffID1, -5.0);
      rmSetAreaSmoothDistance(teamCliffID1, 40);
      rmSetAreaCliffType(teamCliffID1, "Cave");
      rmSetAreaCliffEdge(teamCliffID1, 1, 1.0, 0.1, 1.0, 0);
      rmSetAreaCliffHeight(teamCliffID1, 0, 1.0, 1.0);
      rmSetAreaHeightBlend(teamCliffID1, 1.9);
      rmAddAreaConstraint(teamCliffID1, islandAvoidTradeRouteShort); 
      rmAddAreaConstraint(teamCliffID1, avoidBonusIslandsShort);
      rmAddAreaConstraint(teamCliffID1, avoidTeamCliffs);
      rmSetAreaElevationVariation(teamCliffID1, 0.0);
      rmSetAreaWarnFailure(teamCliffID1, false);
      rmAddAreaToClass(teamCliffID1, classTeamCliff);
      rmSetAreaLocPlayer(teamCliffID1, i);
      rmEchoInfo("Team cliff 1"+i);
      rmBuildArea(teamCliffID1);
    }
    for(i=0; <cNumberPlayers)
    {
      // Create the area.
      int teamID2=rmCreateArea("team 2"+i);
      rmSetAreaSize(teamID2, rmAreaTilesToFraction(6000.0), rmAreaTilesToFraction(6000.0));
      rmSetAreaMinBlobs(teamID2, 30);
      rmSetAreaMaxBlobs(teamID2, 45);
      rmSetAreaMinBlobDistance(teamID2, 20.0);
      rmSetAreaMaxBlobDistance(teamID2, 40.0);
      rmSetAreaCoherence(teamID2, 0.45);
      rmSetAreaBaseHeight(teamID2, -0.25);
      rmSetAreaSmoothDistance(teamID2, 40);
      rmSetAreaHeightBlend(teamID2, 1.9);
      rmSetAreaMix(teamID2, baseMix);
      rmAddAreaConstraint(teamID2, islandAvoidTradeRoute);
      rmAddAreaConstraint(teamID2, playerIslandConstraint); 
      rmAddAreaConstraint(teamID2, avoidBonusIslands);
      rmAddAreaConstraint(teamID2, avoidTeamIslands);
      rmSetAreaElevationNoiseBias(teamID2, 0);
      rmSetAreaElevationEdgeFalloffDist(teamID2, 6);
      rmSetAreaElevationVariation(teamID2, 0.5);
      rmSetAreaElevationPersistence(teamID2, .4);
      rmSetAreaElevationOctaves(teamID2, 5);
      rmSetAreaElevationMinFrequency(teamID2, 0.02);
      rmSetAreaElevationType(teamID2, cElevTurbulence); 
      rmSetAreaWarnFailure(teamID2, false);
      rmAddAreaToClass(teamID2, classTeamIsland);
      rmSetAreaLocPlayer(teamID2, i);
      rmEchoInfo("Team area"+i);
      rmBuildArea(teamID2);
    }
  }
  else{
    // Place underwater cliff just if not having weird teams and if there is enough space inbetween the islands
    /*if (cNumberNonGaiaPlayers >= 4 && cNumberTeams == 2 && (rmGetNumberPlayersOnTeam(0)-rmGetNumberPlayersOnTeam(1)) == 0){
      
    }*/
    for(i=0; <cNumberTeams) {
      // Create the area.
      int teamCliffID2=rmCreateArea("team cliff"+i);
      rmSetAreaSize(teamCliffID2, isleSize, isleSize);
      rmSetAreaMinBlobs(teamCliffID2, 30);
      rmSetAreaMaxBlobs(teamCliffID2, 45);
      rmSetAreaMinBlobDistance(teamCliffID2, 20.0);
      rmSetAreaMaxBlobDistance(teamCliffID2, 40.0);
      rmSetAreaCoherence(teamCliffID2, 0.45);
      rmSetAreaBaseHeight(teamCliffID2, -5.0);
      rmSetAreaSmoothDistance(teamCliffID2, 40);
      rmSetAreaCliffType(teamCliffID2, "Cave");
      rmSetAreaCliffEdge(teamCliffID2, 1, 1.0, 0.1, 1.0, 0);
      rmSetAreaCliffHeight(teamCliffID2, 0, 1.0, 1.0);
      rmSetAreaHeightBlend(teamCliffID2, 1.9);
      rmAddAreaConstraint(teamCliffID2, islandAvoidTradeRouteShort); 
      rmAddAreaConstraint(teamCliffID2, avoidBonusIslandsShort);
      rmAddAreaConstraint(teamCliffID2, avoidTeamCliffs);
      rmSetAreaElevationVariation(teamCliffID2, 0.0);
      rmSetAreaWarnFailure(teamCliffID2, false);
      rmAddAreaToClass(teamCliffID2, classTeamCliff);
      rmSetAreaLocTeam(teamCliffID2, i);
      rmEchoInfo("Team cliff"+i);
      rmBuildArea(teamCliffID2);
    }
    for(i=0; <cNumberTeams)
    {
      // Create the area.
      int teamID=rmCreateArea("team "+i);
      rmSetAreaSize(teamID, isleSize, isleSize);
      rmSetAreaMinBlobs(teamID, 30);
      rmSetAreaMaxBlobs(teamID, 45);
      rmSetAreaMinBlobDistance(teamID, 20.0);
      rmSetAreaMaxBlobDistance(teamID, 40.0);
      rmSetAreaCoherence(teamID, 0.45);
      rmSetAreaBaseHeight(teamID, -0.25);
      rmSetAreaSmoothDistance(teamID, 40);
      rmSetAreaHeightBlend(teamID, 1.9);
      rmSetAreaMix(teamID, baseMix);
      rmAddAreaConstraint(teamID, islandAvoidTradeRoute);
      rmAddAreaConstraint(teamID, playerIslandConstraint); 
      rmAddAreaConstraint(teamID, avoidBonusIslands);
      rmAddAreaConstraint(teamID, avoidTeamIslands);
      rmSetAreaElevationNoiseBias(teamID, 0);
      rmSetAreaElevationEdgeFalloffDist(teamID, 6);
      rmSetAreaElevationVariation(teamID, 0.5);
      rmSetAreaElevationPersistence(teamID, .4);
      rmSetAreaElevationOctaves(teamID, 5);
      rmSetAreaElevationMinFrequency(teamID, 0.02);
      rmSetAreaElevationType(teamID, cElevTurbulence); 
      rmSetAreaWarnFailure(teamID, false);
      rmAddAreaToClass(teamID, classTeamIsland);
      rmSetAreaLocTeam(teamID, i);
      rmEchoInfo("Team area"+i);
      rmBuildArea(teamID);
    }
  }

	playerFraction=rmAreaTilesToFraction(7000 - cNumberNonGaiaPlayers*300);
	for(i=1; <cNumberPlayers)
	{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmSetAreaSize(playerID, playerFraction, playerFraction);
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	  rmSetAreaCoherence(playerID, 0.5);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 10);
    rmSetAreaHeightBlend(playerID, 2.0);
    rmSetAreaMix(playerID, baseMix);
      rmAddAreaTerrainLayer(playerID, "Ceylon\ground_sand1_Ceylon", 0, 6);
      rmAddAreaTerrainLayer(playerID, "Ceylon\ground_sand2_Ceylon", 6, 9);
      rmAddAreaTerrainLayer(playerID, "Ceylon\ground_sand3_Ceylon", 9, 12);
      rmAddAreaTerrainLayer(playerID, "Ceylon\ground_grass2_Ceylon", 12, 25);
	// rmSetAreaTerrainType(playerID, playerTerrain);
    rmAddAreaToClass(playerID, classIsland);
    rmAddAreaConstraint(playerID, islandConstraint);
    rmAddAreaConstraint(playerID, islandEdgeConstraint);
    rmAddAreaConstraint(playerID, playerIslandConstraint);
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
	
    

  // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
  
	// NATIVES
  
  // Place Controllers
  int controllerID1 = rmCreateObjectDef("Controler 1");
  rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);

  int controllerID2 = rmCreateObjectDef("Controler 2");
  rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);

  int controllerID3 = rmCreateObjectDef("Controler 3");
  rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);

  int controllerID4 = rmCreateObjectDef("Controler 4");
  rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);


  rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5, 0.68+rmXTilesToFraction(6));
  rmPlaceObjectDefAtLoc(controllerID2, 0, 0.5, 0.32-rmXTilesToFraction(6));
  rmPlaceObjectDefAtLoc(controllerID3, 0, 0.68-rmXTilesToFraction(7), 0.5);
  rmPlaceObjectDefAtLoc(controllerID4, 0, 0.32+rmXTilesToFraction(7), 0.5);



  vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
  vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
  vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
  vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

  // Pirate Village 1

  int pirateSite1 = rmCreateArea ("pirate_site1");
  rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
  rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
  rmSetAreaMix(pirateSite1, baseMix);
  rmSetAreaCoherence(pirateSite1, 1);
  rmSetAreaSmoothDistance(pirateSite1, 15);
  rmSetAreaBaseHeight(pirateSite1, 2.0);
  rmAddAreaToClass(pirateSite1, classBonusIsland);
  rmBuildArea(pirateSite1);

  int piratesVillageID = -1;
  int piratesVillageType = rmRandInt(1,2);
  piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");


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
  int pirateSite2 = rmCreateArea ("pirate_site2");
  rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
  rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
  rmSetAreaMix(pirateSite2, baseMix);
  rmSetAreaCoherence(pirateSite2, 1);
  rmSetAreaSmoothDistance(pirateSite2, 15);
  rmSetAreaBaseHeight(pirateSite2, 2.0);
  rmAddAreaToClass(pirateSite2, classBonusIsland);
  rmBuildArea(pirateSite2);

  int piratesVillageID2 = -1;
  int piratesVillage2Type = 3-piratesVillageType;
  piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06");

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
  int pirateSite3 = rmCreateArea ("pirate_site3");
  rmSetAreaSize(pirateSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(pirateSite3, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)));
  rmSetAreaMix(pirateSite3, baseMix);
  rmSetAreaCoherence(pirateSite3, 1);
  rmSetAreaSmoothDistance(pirateSite3, 15);
  rmSetAreaBaseHeight(pirateSite3, 2.0);
  rmAddAreaToClass(pirateSite3, classBonusIsland);
  rmBuildArea(pirateSite3);

  int piratesVillageID3 = -1;
  piratesVillageID3 = rmCreateGrouping("pirate city 3", "Scientist_lab05");

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
  int pirateSite4 = rmCreateArea ("pirate_site4");
  rmSetAreaSize(pirateSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(pirateSite4, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)));
  rmSetAreaMix(pirateSite4, baseMix);
  rmSetAreaCoherence(pirateSite4, 1);
  rmSetAreaSmoothDistance(pirateSite4, 15);
  rmSetAreaBaseHeight(pirateSite4, 2.0);
  rmAddAreaToClass(pirateSite4, classBonusIsland);
  rmBuildArea(pirateSite4);


  int piratesVillageID4 = -1;
  piratesVillageID4 = rmCreateGrouping("pirate city 4", "Scientist_lab06");
  rmSetGroupingMinDistance(piratesVillageID4, 0);
  rmSetGroupingMaxDistance(piratesVillageID4, 20);
  rmAddGroupingConstraint(piratesVillageID4, ferryOnShore);

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


  //************************* UNDERWATER OBJECTS *********************************
  int underwaterCaveID = -1;
  if (cNumberNonGaiaPlayers <=5)
    underwaterCaveID = rmCreateGrouping("underwater_grouping", "underwater_grouping");
  else
    underwaterCaveID = rmCreateGrouping("underwater_grouping", "underwater_grouping2");
  rmPlaceGroupingAtLoc(underwaterCaveID, 0, 0.5, 0.5, 1);

  int patchNum = -1;

  if (cNumberNonGaiaPlayers ==2)
    patchNum = 3;
  if (cNumberNonGaiaPlayers ==3)
    patchNum = 4;
  if (cNumberNonGaiaPlayers ==4)
    patchNum = 5;
  if (cNumberNonGaiaPlayers ==5)
    patchNum = 6;
  if (cNumberNonGaiaPlayers ==6)
    patchNum = 5;
  if (cNumberNonGaiaPlayers ==7)
    patchNum = 6;
  if (cNumberNonGaiaPlayers ==8)
    patchNum = 7;


  for(i=0; <patchNum) {
    int patchArea = rmCreateArea ("underwater_patch_area"+i);
    rmSetAreaSize(patchArea, rmAreaTilesToFraction(200.0), rmAreaTilesToFraction(200.0));
    rmSetAreaCoherence(patchArea, 1.0);
    rmAddAreaConstraint(patchArea, avoidPatch);
    rmAddAreaConstraint(patchArea, avoidTeamCliffsShort);
    rmAddAreaConstraint(patchArea, flagVsScientists1Short);
    rmAddAreaConstraint(patchArea, flagVsScientists2Short);
    rmAddAreaConstraint(patchArea, avoidLandLong);
    rmAddAreaConstraint(patchArea, underwaterPatchConstraint);
    rmAddAreaToClass(patchArea, classUnderwaterPatch);
    rmBuildArea(patchArea);

    int patchType = (rmRandInt(1, 3));
    int underwaterPatchID = -1;
    underwaterPatchID = rmCreateGrouping("underwater_patch"+i, "underwater_grouping_xs_0"+patchType);
    rmPlaceGroupingInArea(underwaterPatchID, 0, rmAreaID("underwater_patch_area"+i), 1);
  }


  // Placing Player Trade Route Sockets

  int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
  rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
  rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
  rmSetObjectDefAllowOverlap(socketID, true);
  rmSetObjectDefMinDistance(socketID, 5.0);
  rmSetObjectDefMaxDistance(socketID, 30.0);

  vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);


  float playerSpace = 1/cNumberNonGaiaPlayers;
  int socketCount = cNumberNonGaiaPlayers+1;

  if (cNumberNonGaiaPlayers==3)
  playerSpace =0.333;

  if (cNumberNonGaiaPlayers==4)
  playerSpace =0.25;

  if (cNumberNonGaiaPlayers==5)
  playerSpace =0.2;

  if (cNumberNonGaiaPlayers==6)
  playerSpace =0.166;

  if (cNumberNonGaiaPlayers==7)
  playerSpace =0.142;

  if (cNumberNonGaiaPlayers==8)
  playerSpace =0.125;

  if(cNumberNonGaiaPlayers <= 2){
  socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
  rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

  socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.80);
  rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
  }

  else{
  for (i=1; <socketCount){  
    socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, playerSpace*i-0.02);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
  }
  }


  // check for KOTH game mode

  if(rmGetIsKOTH()){
    int KotHID= rmCreateObjectDef("KotH"); 
    int KotHVariation = 1;
    if (cNumberTeams == 2)
      KotHVariation =(rmRandInt(1, 2));
    else
      KotHVariation =(rmRandInt(1, 4));
    rmAddObjectDefItem(KotHID, "ypKingsHill", 1, 0.0);
    rmAddObjectDefConstraint(KotHID, avoidAll);
    if (KotHVariation == 1)
      rmPlaceObjectDefInArea(KotHID, 0, bonusIslandID, 1);
    else if (KotHVariation == 2)
      rmPlaceObjectDefInArea(KotHID, 0, bonusIslandID2, 1);
    else if (KotHVariation == 3)
      rmPlaceObjectDefInArea(KotHID, 0, bonusIslandID3, 1);
    else
      rmPlaceObjectDefInArea(KotHID, 0, bonusIslandID4, 1);
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
	rmAddObjectDefConstraint(TCID, avoidScientists);
  rmAddObjectDefConstraint(TCID, avoidMaori);
  rmAddObjectDefConstraint(TCID, avoidTP);
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
	rmSetObjectDefMinDistance(playerGoldID, 7.0);
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

  // Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

	for(i=1; <cNumberPlayers) {
    
    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
		rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
   
    // Player Native

    if (cNumberNonGaiaPlayers<=2)
      int whichSettlement = 5;
    else
      whichSettlement = rmRandInt(1,5);

    int playerNativeID = -1;
    playerNativeID = rmCreateGrouping("player native "+i, "maori_tropic_0"+whichSettlement);
    rmSetGroupingMinDistance(playerNativeID, 30);
    rmSetGroupingMaxDistance(playerNativeID, 60);
    rmAddGroupingConstraint(playerNativeID, avoidAll);
    rmAddGroupingConstraint(playerNativeID, avoidImpassableLand);
    rmAddGroupingConstraint(playerNativeID, avoidTCLong);
    rmAddGroupingConstraint(playerNativeID, avoidTPLong);
    if (cNumberNonGaiaPlayers ==2)
      rmAddObjectDefConstraint(playerNativeID, avoidWater8);
    else
      rmAddObjectDefConstraint(playerNativeID, avoidWater20);


    rmPlaceGroupingAtLoc(playerNativeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

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
    rmAddClosestPointConstraint(avoidTeamIslandsShort);
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
    rmAddAreaConstraint(forest, avoidScientists);
    rmAddAreaConstraint(forest, avoidMaori);
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

	// Pearl Sources
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "zpPearlSource", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, 30.0);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidGold);
  rmAddObjectDefConstraint(goldID, avoidImportantItem);
  rmAddObjectDefConstraint(goldID, avoidCoin);
  rmAddObjectDefConstraint(goldID, avoidLandShort);
  //rmPlaceObjectDefAtLoc(goldID, 0, 0.15, 0.5);

  if (cNumberNonGaiaPlayers==3){
    for (i=0; <cNumberPlayers)
    {
      rmPlaceObjectDefInArea(goldID, 0, rmAreaID("team 2"+i), 3);
    }
  }
  else{
    for (i=0; <cNumberTeams)
    {
      if (cNumberTeams == 2)
        rmPlaceObjectDefInArea(goldID, 0, rmAreaID("team "+i), cNumberNonGaiaPlayers/cNumberTeams*3);
      else
        rmPlaceObjectDefInArea(goldID, 0, rmAreaID("team "+i), cNumberNonGaiaPlayers/cNumberTeams*2);
    }
  }

  // Decorative Corals
  int coralID = rmCreateObjectDef("random coral");
	rmAddObjectDefItem(coralID, "zpUnderbrushCoral", 1, 0);
	rmSetObjectDefMinDistance(coralID, 0.0);
	rmSetObjectDefMaxDistance(coralID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(coralID, avoidTeamIslands1);
  rmAddObjectDefConstraint(coralID, avoidLandShort);
  if (cNumberNonGaiaPlayers == 3){
    for (i=0; <cNumberPlayers)
    {
      rmPlaceObjectDefInArea(coralID, 0, rmAreaID("team cliff 1"+i), 30);
    }
  }
  else{
  for (i=0; <cNumberTeams)
    {
      rmPlaceObjectDefInArea(coralID, 0, rmAreaID("team cliff"+i), cNumberNonGaiaPlayers/cNumberTeams*30);
    }
  }

  if (cNumberTeams >2){
    int silverID = rmCreateObjectDef("random silver");
    rmAddObjectDefItem(silverID, "zpJadeMine", 1, 0);
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
    for (i=0; <cNumberPlayers)
    {
      rmPlaceObjectDefInArea(silverID, 0, rmAreaID("player "+i), 2);
    }
  }
   
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
	//rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers/2);
  
  // Huntables scattered on island
	int foodID2=rmCreateObjectDef("random food two");
	rmAddObjectDefItem(foodID2, huntable1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID2, avoidTP);
  rmAddObjectDefConstraint(foodID2, avoidTCLong);
  rmAddObjectDefConstraint(foodID2, avoidImportantItem);
  rmAddObjectDefConstraint(foodID2, avoidHuntable1);
	for (i=0; <cNumberPlayers)
	{
		rmPlaceObjectDefInArea(foodID2, 0, rmAreaID("player "+i), 2);
	}

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
	for (i=0; <cNumberPlayers)
	{
		rmPlaceObjectDefInArea(nugget1, 0, rmAreaID("player "+i), 2);
	}

	// Water nuggets

  // Special nuggets to unlock diver training
  int nuggetCount = cNumberNonGaiaPlayers;
  int bonusNuggets = rmRandInt(1, 2);

  int NUGGETspc = rmCreateObjectDef("nugget water SPC" + i); 
  rmAddObjectDefItem(NUGGETspc, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(16, 16);
  rmAddObjectDefConstraint(NUGGETspc, avoidLand);
  if (bonusNuggets ==1){
    for(i=0; <patchNum) {
      rmPlaceObjectDefInArea(NUGGETspc, 0,  rmAreaID("underwater_patch_area"+i), 1);
    }
  }
  else{
    for(i=1; <patchNum) {
      rmPlaceObjectDefInArea(NUGGETspc, 0,  rmAreaID("underwater_patch_area"+i), 1);
    }
    rmSetNuggetDifficulty(17, 17);
    rmPlaceObjectDefInArea(NUGGETspc, 0,  rmAreaID("underwater_patch_area"+0), 1);
  }

  // Extra special nuggets for PvP
  if (cNumberTeams>2){
    int NUGGETspc2 = rmCreateObjectDef("nugget water SPC2"); 
    rmAddObjectDefItem(NUGGETspc2, "ypNuggetBoat", 1, 0.0);
    rmSetNuggetDifficulty(15, 15);
    rmAddObjectDefConstraint(NUGGETspc2, avoidLand);
    rmAddObjectDefConstraint(NUGGETspc2, avoidNuggetWater);
    rmPlaceObjectDefInArea(NUGGETspc2, 0,  deadSeaLakeMediumID, cNumberNonGaiaPlayers/2);
  }


  int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2b, avoidLand);
  rmAddObjectDefConstraint(nugget2b, avoidNuggetWater2);
  rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nugget2b, false, 2);
  
  int nugget2= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nugget2, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nugget2, avoidLand);
  rmAddObjectDefConstraint(nugget2, avoidNuggetWater);
  rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nugget2, false, 3);
  
  // really tough nuggets confined to south central cliffy area
  int nugget3= rmCreateObjectDef("nugget hardest"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidHardNugget);
  rmAddObjectDefConstraint(nugget3, mesaConstraint);
  rmAddObjectDefConstraint(nugget3, avoidImportantItem);
  rmAddObjectDefConstraint(nugget3, avoidAll);
	rmPlaceObjectDefInArea(nugget3, 0, bonusIslandID, 1);
  rmPlaceObjectDefInArea(nugget3, 0, bonusIslandID2, 1);
  rmPlaceObjectDefInArea(nugget3, 0, bonusIslandID3, 1);
  rmPlaceObjectDefInArea(nugget3, 0, bonusIslandID4, 1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 

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

  int fish3ID=rmCreateObjectDef("fish 3");
	rmAddObjectDefItem(fish3ID, fish3, 1, 0.0);
	rmSetObjectDefMinDistance(fish3ID, 0.0);
	rmSetObjectDefMaxDistance(fish3ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish3ID, avoidFish3);
	rmAddObjectDefConstraint(fish3ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish3ID, fishLand);
	rmPlaceObjectDefAtLoc(fish3ID, 0, 0.5, 0.5, 8*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}

  // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, startTreeType, 1, 0.0);
   rmAddObjectDefConstraint(villageTreeID, avoidAll);
   rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite1, 5);
   rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite2, 5);
   rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite3, 5);
   rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite4, 5);

// Starter shipment triggers

// ------Triggers--------//

string pirate1ID = "0";
string pirate2ID = "0";
string scientist1ID = "0";
string scientist2ID = "0";

pirate1ID = "5";
pirate2ID = "64";
scientist1ID = "96";
scientist2ID = "181";

int tch0=1671; // tech operator

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
rmSetTriggerEffectParam("TechID","cTechzpUnderwaterScientists"); // Mercenary
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
rmCreateTrigger("Activate Scientists"+k);
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmers"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Scientists"+k));
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

   if (cNumberNonGaiaPlayers >= 4){
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
   }

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

   if (cNumberNonGaiaPlayers >= 4){
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
   }

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

if (cNumberNonGaiaPlayers >= 4){
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
		rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainSubmarineSPC2"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainSubmarine2"); //operator
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
    rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainSubmarineSPC1"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainSubmarine1"); //operator
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainNautilusSPC2"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainNautilus2"); //operator
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainNautilusSPC1"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainNautilus1"); //operator
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",scientist1ID); // Unique Object ID Village 1
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
		rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",scientist1ID); // Unique Object ID Village 1
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
		rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",scientist2ID); // Unique Object ID Village 2
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
		rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",scientist2ID); // Unique Object ID Village 2
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

    for(k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Submarine Transform"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "true");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTransformNemoSubmarines"); //operator
    rmSetTriggerEffectParamInt("Status",2);
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