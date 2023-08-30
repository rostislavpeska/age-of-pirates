// Burma Monasteries 1.0 10 08 2022

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

  int whichVersion = 1;
   
  // initialize map type variables 
  string nativeCiv1 = "spczen";
  string nativeCiv2 = "spcsufi";
  string nativeCiv3 = "wokou";
  string baseMix = "indochina_grass_a";
  string paintMix = "indochina_underbrush";
  string baseTerrain = "borneo\ground_grass4_borneo";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "indochina coast";
  string startTreeType = "ypTreeBorneo";
  string forestType = "z59 Bamboo Jungle";  // Borneo Forest
  string forestType2 = "Borneo Palm Forest";
  string patchTerrain = "borneo\ground_grass3_borneo";
  string patchType1 = "borneo\ground_grass5_borneo";
  string patchType2 = "borneo\ground_forest_borneo";
  string mapType1 = "borneo";
  string mapType2 = "grass";
  string herdableType = "ypWaterBuffalo";
  string huntable1 = "ypSerow";
  string huntable2 = "ypWildElephant";
  string fish1 = "ypFishMolaMola";
  string fish2 = "ypFishTuna";
  string whale1 = "MinkeWhale";
  string lightingType = "Indochina_Skirmish";
  
  bool weird = false;
  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
    
  // FFA and imbalanced teams
  if ( cNumberTeams > 2)
    weird = true;
  
  rmEchoInfo("weird = "+weird);
  
// Natives
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

  if (rmAllocateSubCivs(3) == true)
  {
		  // Klamath, Comanche, or Hurons
		  subCiv0=rmGetCivID(nativeCiv1);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, nativeCiv1);

		  // Cherokee, Apache, or Cheyenne
		  subCiv1=rmGetCivID(nativeCiv2);
      if (subCiv1 >= 0)
         rmSetSubCiv(1, nativeCiv2);

      // Wokou
		  subCiv2=rmGetCivID(nativeCiv3);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, nativeCiv3);
  }
	
// Map Basics
	int playerTiles = 16000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 16000;
  if (cNumberNonGaiaPlayers <=2)
		playerTiles = 18000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 15000;		

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	rmSetMapElevationParameters(cElevTurbulence, 0.05, 10, 0.4, 7.0);
	rmSetMapElevationHeightBlend(1);
	
	rmSetSeaLevel(1.0);
	rmSetLightingSet(lightingType);
  rmSetOceanReveal(true);


	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmTerrainInitialize("water");
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("water");
  rmSetMapType("burma");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(3.0);

	chooseMercs();
	
// Classes
	int classPlayer=rmDefineClass("player");
	int classSocket=rmDefineClass("socketClass");
  int classIsland=rmDefineClass("island");
  int classBonusIsland=rmDefineClass("bonusIsland");
	rmDefineClass("classPatch");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");

// Constraints
    
	// Map edge constraints
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
  int longPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players long", classPlayer, 35.0);
  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int playerConstraintNative=rmCreateClassDistanceConstraint("natives stay away from players far", classPlayer, 75.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 10.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
  int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 30.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);

	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 7.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int shortAvoidResource=rmCreateTypeDistanceConstraint("resource avoid resource short", "resource", 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 8.0);
  int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
  int riverGrass = rmCreateTerrainMaxDistanceConstraint("stay near the water", "land", false, 6.0);
  int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);

  // resource avoidance
	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "mine", 65.0);
  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
  int avoidNugget=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetsFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "AbstractNugget", 65.0);
  int avoidHerdable=rmCreateTypeDistanceConstraint("herdables avoid herdables", herdableType, 75.0);
  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 55.0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
  int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 40.0);

	// Unit avoidance
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 90.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
    int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 10.0);

	// general avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);
  int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
  int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);

  // fish & whale constraints
  int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", fish1, 15.0);	
	int fishVsFish2ID=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0); 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
  
  int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 45.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);
  int whaleEdgeConstraint=rmCreatePieConstraint("whale edge of map", 0.5, 0.5, 0, rmGetMapXSize()-20, 0, 0, 0);

  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
  int nuggetVsFlag = rmCreateTypeDistanceConstraint("nugget v flag", "HomeCityWaterSpawnFlag", 8.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25.0);
	int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, rmGetMapXSize()-25, rmGetMapXSize()-10, 0, rmDegreesToRadians(0), rmDegreesToRadians(180));
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 10.0);

    //dk
    int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 5.0);
    int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "Socket", 20.0);
    int avoidSocket2=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 40.0);
    int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
    int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
    int avoidHunt2=rmCreateTypeDistanceConstraint("herds avoid herds2", "huntable", 32.0);
    int avoidHunt3=rmCreateTypeDistanceConstraint("herds avoid herds3", "huntable", 14.0);
	  int avoidAll2=rmCreateTypeDistanceConstraint("avoid all2", "all", 4.0);
    int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("avoid gold type  far 2", "gold", 32.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

  // Avoid Water
  int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
  int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
  int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
  int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 30.0);

  // Trade route constraints
  int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 9.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 41.0);
  int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 70.0);
  int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 0.0);
  int ObjectAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("object avoid trade route short", 3.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

// ************************** DEFINE OBJECTS ****************************
	
  
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable1, 8, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, true);
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 7.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);

int avoidStartingGold_dk =rmCreateTypeDistanceConstraint("starting berries avoid starting coin dk", "Mine", 16.0);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "berrybush", 4, 4.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
  rmAddObjectDefConstraint(StartBerriesID, avoidSocket2);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartingGold_dk);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 12.0);
	rmSetObjectDefMaxDistance(startSilverID, 20.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
  rmAddObjectDefConstraint(startSilverID, avoidSocket2);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
  
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 15.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 18.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
  rmAddObjectDefConstraint(playerNuggetID, avoidSocket2);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  
  int playerLombardID=rmCreateObjectDef("player lombard");
  rmAddObjectDefItem(playerLombardID, "deLombard", 1, 0.0);
  rmSetObjectDefMinDistance(playerLombardID, 12.0);
  rmSetObjectDefMaxDistance(playerLombardID, 16.0);
	rmAddObjectDefConstraint(playerLombardID, avoidAll);
  rmAddObjectDefConstraint(playerLombardID, avoidSocket2);
	rmAddObjectDefConstraint(playerLombardID, avoidImpassableLand);
  
  int playerSaloonID=rmCreateObjectDef("player saloon");
  rmAddObjectDefItem(playerSaloonID, "deTavern", 1, 0.0);
  rmSetObjectDefMinDistance(playerSaloonID, 12.0);
  rmSetObjectDefMaxDistance(playerSaloonID, 16.0);
	rmAddObjectDefConstraint(playerSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerSaloonID, avoidImpassableLand);
  
  int playerCommunityPlazaID=rmCreateObjectDef("player community plaza");
  rmAddObjectDefItem(playerCommunityPlazaID, "CommunityPlaza", 1, 0.0);
  rmSetObjectDefMinDistance(playerCommunityPlazaID, 12.0);
  rmSetObjectDefMaxDistance(playerCommunityPlazaID, 16.0);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidAll);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidImpassableLand);
  
  int playerMonID=rmCreateObjectDef("player monastery");
  rmAddObjectDefItem(playerMonID, "ypMonastery", 1, 0.0);
  rmSetObjectDefMinDistance(playerMonID, 12.0);
  rmSetObjectDefMaxDistance(playerMonID, 16.0);
	rmAddObjectDefConstraint(playerMonID, avoidAll);
	rmAddObjectDefConstraint(playerMonID, avoidImpassableLand);
	
  int playerUSSaloonID=rmCreateObjectDef("player USsaloon");
  rmAddObjectDefItem(playerUSSaloonID, "Saloon", 1, 0.0);
  rmSetObjectDefMinDistance(playerUSSaloonID, 12.0);
  rmSetObjectDefMaxDistance(playerUSSaloonID, 16.0);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidImpassableLand);
   
  int playerAfrTowerID=rmCreateObjectDef("player afr tower");
  rmAddObjectDefItem(playerAfrTowerID, "deTower", 1, 0.0);
  rmSetObjectDefMinDistance(playerAfrTowerID, 12.0);
  rmSetObjectDefMaxDistance(playerAfrTowerID, 16.0);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidAll);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidImpassableLand);
      
	// -------------Done defining objects
  // Text
  rmSetStatusText("",0.10);
  
  // Make the island


  // Water Trade Route
  int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);

rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.1);
rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.2);
rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.4);

rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);

rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.4);
rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.2);
rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.1);


bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "asian_water_trail");



  //~ if(cNumberNonGaiaPlayers > 4)
    	//~ rmSetAreaSize(mainIslandID, 0.6, 0.6);
      
  //~ else

  int mainIslandID=rmCreateArea("indochina");
  rmSetAreaSize(mainIslandID, 0.28, 0.28);
  
	rmSetAreaCoherence(mainIslandID, 0.75);
	rmSetAreaBaseHeight(mainIslandID, 3.0);
  rmSetAreaLocation(mainIslandID, 0.1, 0.5);
	rmSetAreaSmoothDistance(mainIslandID, 20);
	rmSetAreaMix(mainIslandID, baseMix);
    rmAddAreaTerrainLayer(mainIslandID, "borneo\ground_sand1_borneo", 0, 4);
    rmAddAreaTerrainLayer(mainIslandID, "borneo\ground_sand2_borneo", 4, 6);
    rmAddAreaTerrainLayer(mainIslandID, "borneo\ground_sand3_borneo", 6, 9);
    rmAddAreaTerrainLayer(mainIslandID, "borneo\ground_grass4_borneo", 9, 12);
	rmSetAreaObeyWorldCircleConstraint(mainIslandID, false);
	rmSetAreaElevationType(mainIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(mainIslandID, 4.0);
	rmSetAreaElevationMinFrequency(mainIslandID, 0.09);
	rmSetAreaElevationOctaves(mainIslandID, 3);
	rmSetAreaElevationPersistence(mainIslandID, 0.2);
	rmSetAreaElevationNoiseBias(mainIslandID, 1);
  rmAddAreaInfluenceSegment(mainIslandID, 0.1, 0.5, 0.4, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID, 0.1, 0.5, 0.1, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID, 0.4, 0.9, 0.1, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID, 0.2, 0.7, 0.3, 0.6);

  rmAddAreaConstraint(mainIslandID, islandAvoidTradeRoute);
  rmAddAreaConstraint(mainIslandID, avoidKOTH);
  
	rmSetAreaWarnFailure(mainIslandID, false);
	rmBuildArea(mainIslandID);

  int mainIslandID2=rmCreateArea("indochina2");
  rmSetAreaSize(mainIslandID2, 0.28, 0.28);
  
	rmSetAreaCoherence(mainIslandID2, 0.75);
	rmSetAreaBaseHeight(mainIslandID2, 3.0);
  rmSetAreaLocation(mainIslandID2, 0.9, 0.5);
	rmSetAreaSmoothDistance(mainIslandID2, 20);
	rmSetAreaMix(mainIslandID2, baseMix);
    rmAddAreaTerrainLayer(mainIslandID2, "borneo\ground_sand1_borneo", 0, 4);
    rmAddAreaTerrainLayer(mainIslandID2, "borneo\ground_sand2_borneo", 4, 6);
    rmAddAreaTerrainLayer(mainIslandID2, "borneo\ground_sand3_borneo", 6, 9);
    rmAddAreaTerrainLayer(mainIslandID2, "borneo\ground_grass4_borneo", 9, 12);
	rmSetAreaObeyWorldCircleConstraint(mainIslandID2, false);
	rmSetAreaElevationType(mainIslandID2, cElevTurbulence);
	rmSetAreaElevationVariation(mainIslandID2, 4.0);
	rmSetAreaElevationMinFrequency(mainIslandID2, 0.09);
	rmSetAreaElevationOctaves(mainIslandID2, 3);
	rmSetAreaElevationPersistence(mainIslandID2, 0.2);
	rmSetAreaElevationNoiseBias(mainIslandID2, 1);
  rmAddAreaInfluenceSegment(mainIslandID2, 0.9, 0.5, 0.6, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID2, 0.9, 0.5, 0.9, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID2, 0.6, 0.9, 0.9, 0.9);
  rmAddAreaInfluenceSegment(mainIslandID2, 0.8, 0.7, 0.7, 0.6);

  rmAddAreaConstraint(mainIslandID2, islandAvoidTradeRoute);
  rmAddAreaConstraint(mainIslandID2, avoidKOTH);
  
	rmSetAreaWarnFailure(mainIslandID2, false);
	rmBuildArea(mainIslandID2);


  
  int eastIslandConstraint=rmCreateAreaConstraint("east island", mainIslandID);
  int westIslandConstraint=rmCreateAreaConstraint("west Island", mainIslandID2);

  
  
// Wokou Sites


   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite1, 0.62, 0.35);
   rmSetAreaMix(portSite1, baseMix);
    rmAddAreaTerrainLayer(portSite1, "borneo\ground_sand1_borneo", 0, 4);
    rmAddAreaTerrainLayer(portSite1, "borneo\ground_sand2_borneo", 4, 6);
    rmAddAreaTerrainLayer(portSite1, "borneo\ground_sand3_borneo", 6, 9);
    rmAddAreaTerrainLayer(portSite1, "borneo\ground_grass4_borneo", 9, 12);
   rmSetAreaCoherence(portSite1, 0.8);
   rmAddAreaConstraint(portSite1, islandAvoidTradeRoute);
   rmSetAreaSmoothDistance(portSite1, 20);
   rmSetAreaBaseHeight(portSite1, 3.0);
   rmAddAreaToClass(portSite1, rmClassID("bonusIsland")); 
   rmBuildArea(portSite1);

   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.38, 0.35);
   rmSetAreaMix(portSite2, baseMix);
    rmAddAreaTerrainLayer(portSite2, "borneo\ground_sand1_borneo", 0, 4);
    rmAddAreaTerrainLayer(portSite2, "borneo\ground_sand2_borneo", 4, 6);
    rmAddAreaTerrainLayer(portSite2, "borneo\ground_sand3_borneo", 6, 9);
    rmAddAreaTerrainLayer(portSite2, "borneo\ground_grass4_borneo", 9, 12);
   rmSetAreaCoherence(portSite2, 0.8);
   rmAddAreaConstraint(portSite2, islandAvoidTradeRoute);
   rmSetAreaSmoothDistance(portSite2, 20);
   rmAddAreaToClass(portSite2, rmClassID("bonusIsland")); 
   rmSetAreaBaseHeight(portSite2, 3.0);
   rmBuildArea(portSite2);


  // Text
  rmSetStatusText("",0.15);

  //Wokou

      int controllerID1 = rmCreateObjectDef("Controler 1");
      rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID1, 0.0);
	   rmSetObjectDefMaxDistance(controllerID1, 0.0);
      rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
      rmPlaceObjectDefAtLoc(controllerID1, 0, 0.62, 0.35);


      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID2, 0.0);
	   rmSetObjectDefMaxDistance(controllerID2, 0.0);
      rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
     rmPlaceObjectDefAtLoc(controllerID2, 0, 0.38, 0.35);

      vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

      // Pirate Village 1
      if (subCiv2 == rmGetCivID(nativeCiv3))
      {  
         int piratesVillageID = -1;
         int piratesVillageType = rmRandInt(1,2);
         piratesVillageID = rmCreateGrouping("pirate city", "Wokou_Village_01");

      
         rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

        int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
         rmAddObjectDefItem(piratewaterflagID1, "zpWokouWaterSpawnFlag1", 1, 1.0);
         rmAddClosestPointConstraint(flagLandShort);

         vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

         rmClearClosestPointConstraints();

         int pirateportID1 = -1;
         pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport04");
         rmAddClosestPointConstraint(portOnShore);

         vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
         
         rmClearClosestPointConstraints();
      
      }

      // Pirate Village 2

         if (subCiv2 == rmGetCivID(nativeCiv3))
         {  
            int piratesVillageID2 = -1;
            int piratesVillage2Type = 3-piratesVillageType;
            piratesVillageID2 = rmCreateGrouping("pirate city 2", "Wokou_Village_02");


            rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);
         
            int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
            rmAddObjectDefItem(piratewaterflagID2, "zpWokouWaterSpawnFlag2", 1, 1.0);
            rmAddClosestPointConstraint(flagLandShort);

            vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

            rmClearClosestPointConstraints();

            int pirateportID2 = -1;
            pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport04");
            rmAddClosestPointConstraint(portOnShore);

            vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
            rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
            
            rmClearClosestPointConstraints();
         }


  


  // Ports

  if (cNumberNonGaiaPlayers >= 4){
    int portID01 = rmCreateObjectDef("port 01");
    portID01 = rmCreateGrouping("portG 01", "treasure_ship_harbour1");
    rmPlaceGroupingAtLoc(portID01, 0, 0.35, 0.5+rmXTilesToFraction(6));

    int portID02 = rmCreateObjectDef("port 02");
    portID02 = rmCreateGrouping("portG 02", "treasure_ship_harbour1");
    rmPlaceGroupingAtLoc(portID02, 0, 0.65, 0.5+rmXTilesToFraction(6));
  }

  int portID03 = rmCreateObjectDef("port 03");
  portID03 = rmCreateGrouping("portG 03", "treasure_ship_harbour2");
  rmPlaceGroupingAtLoc(portID03, 0, 0.75+rmXTilesToFraction(7), 0.45+rmXTilesToFraction(7));

  int portID04 = rmCreateObjectDef("port 04");
  portID04 = rmCreateGrouping("portG 04", "treasure_ship_harbour3");
  rmPlaceGroupingAtLoc(portID04, 0, 0.25-rmXTilesToFraction(7), 0.45+rmXTilesToFraction(7));

 // Natives
  
  // always at least two native villages of each type
  if (subCiv0 == rmGetCivID(nativeCiv1))
  {

      // Middle Monastery

      int zenControllerID = rmCreateObjectDef("zen controller 1");
      rmAddObjectDefItem(zenControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID, 0.0);

      rmPlaceObjectDefAtLoc(zenControllerID, 0, 0.5, 0.95);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID, 0));

      int eastIslandVillage1 = rmCreateArea ("east island village 1");
      int zenWaterBasin1 = rmCreateArea ("zen water basin 1");
      int eastIslandVillage1ramp1 = rmCreateArea ("east island village1 ramp 1");
      int eastIslandVillage1ramp2 = rmCreateArea ("east island village1 ramp 2");

      rmSetAreaSize(zenWaterBasin1, rmAreaTilesToFraction(3500.0), rmAreaTilesToFraction(3500.0));
      rmSetAreaLocation(zenWaterBasin1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaWaterType(zenWaterBasin1, "indochina coast");
      rmSetAreaCoherence(zenWaterBasin1, 0.6);
      rmSetAreaObeyWorldCircleConstraint(zenWaterBasin1, false);
      rmSetAreaSmoothDistance(zenWaterBasin1, 20);
      rmAddAreaInfluenceSegment(zenWaterBasin1, 0.5, 0.9, 0.5, 0.5);
      rmBuildArea(zenWaterBasin1);

      rmSetAreaSize(eastIslandVillage1ramp1, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(eastIslandVillage1ramp1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)-35), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaBaseHeight(eastIslandVillage1ramp1, 6.2);
      rmSetAreaCoherence(eastIslandVillage1ramp1, 0.8);
      rmSetAreaMix(eastIslandVillage1ramp1, baseMix);
        rmAddAreaTerrainLayer(eastIslandVillage1ramp1, "borneo\ground_grass4_borneo", 9, 12);
      rmSetAreaSmoothDistance(eastIslandVillage1ramp1, 30);
      rmBuildArea(eastIslandVillage1ramp1);

      rmSetAreaSize(eastIslandVillage1ramp2, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(eastIslandVillage1ramp2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)+35), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaBaseHeight(eastIslandVillage1ramp2, 6.2);
      rmSetAreaCoherence(eastIslandVillage1ramp2, 0.8);
      rmSetAreaMix(eastIslandVillage1ramp2, baseMix);
        rmAddAreaTerrainLayer(eastIslandVillage1ramp2, "borneo\ground_grass4_borneo", 9, 12);
      rmSetAreaSmoothDistance(eastIslandVillage1ramp2, 30);



      rmBuildArea(eastIslandVillage1ramp2);

      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaCliffType(eastIslandVillage1, "ZP Borneo");
      rmSetAreaCliffEdge(eastIslandVillage1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage1, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(eastIslandVillage1, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);

      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage1, false);

      rmBuildArea(eastIslandVillage1);

      int middleSufiVillageID = -1;
      int middleSufiVillageIDType = rmRandInt(1,2);
      middleSufiVillageID = rmCreateGrouping("native city", "Middle_Monastery_0"+middleSufiVillageIDType);
      rmAddGroupingConstraint(middleSufiVillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)-10), 1);
     
      rmSetOceanReveal(true);

      // check for KOTH game mode
      if (rmGetIsKOTH())
      {
        
        int randLoc = rmRandInt(1,2);
        float xLoc = 0.5;
        float yLoc = 0.6;
        float walk = 0.0;

        int KotHLakeID = rmCreateArea ("KotH Lake");
        rmSetAreaSize(KotHLakeID, rmAreaTilesToFraction(1500.0), rmAreaTilesToFraction(1500.0));
        rmSetAreaLocation(KotHLakeID, 0.5, 0.6);
        rmSetAreaWaterType(KotHLakeID, "indochina coast");
        rmSetAreaCoherence(KotHLakeID, 0.8);
        rmSetAreaObeyWorldCircleConstraint(KotHLakeID, false);
        rmSetAreaSmoothDistance(KotHLakeID, 20);
        rmBuildArea(KotHLakeID);
        
        ypKingsHillLandfill(xLoc, yLoc, rmAreaTilesToFraction(375), 2.0, "borneo_sand_a", 0);
        ypKingsHillPlacer(xLoc, yLoc, walk, 0);
        rmEchoInfo("XLOC = "+xLoc);
        rmEchoInfo("XLOC = "+yLoc);
      }
      
      // West Monastery 1

      int monasteryPlacement = rmRandInt(1,2);

      int zenControllerID2 = rmCreateObjectDef("zen controller 2");
      rmAddObjectDefItem(zenControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID2, 0.0);
      rmAddObjectDefConstraint(zenControllerID2, avoidController); 
      rmAddObjectDefConstraint(zenControllerID2, playerEdgeConstraint); 

      if (monasteryPlacement == 1)
      {
      rmPlaceObjectDefAtLoc(zenControllerID2, 0, 0.2, 0.7);
      }
      else 
      {
      rmPlaceObjectDefAtLoc(zenControllerID2, 0, 0.8, 0.7);
      }

      vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID2, 0));

      int eastIslandVillage2 = rmCreateArea ("east island village 2");
      int zenWaterBasin2 = rmCreateArea ("zen water basin 2");
      int eastIslandVillage2ramp = rmCreateArea ("east island village2 ramp 1");

      rmSetAreaSize(zenWaterBasin2, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(zenWaterBasin2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaWaterType(zenWaterBasin2, "zp borneo lake");
      rmSetAreaBaseHeight(zenWaterBasin2, 0);
      rmSetAreaCoherence(zenWaterBasin2, 0.65);
      rmBuildArea(zenWaterBasin2);

      rmSetAreaSize(eastIslandVillage2ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage2ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)-30));
      rmSetAreaBaseHeight(eastIslandVillage2ramp, 6.2);
      rmSetAreaCoherence(eastIslandVillage2ramp, 0.8);
      rmSetAreaMix(eastIslandVillage2ramp, baseMix);
        rmAddAreaTerrainLayer(eastIslandVillage2ramp, "borneo\ground_grass4_borneo", 9, 12);
      rmSetAreaSmoothDistance(eastIslandVillage2ramp, 30);
      rmBuildArea(eastIslandVillage2ramp);

      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.9);
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      rmSetAreaCliffType(eastIslandVillage2, "ZP Borneo");
      rmSetAreaCliffEdge(eastIslandVillage2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage2, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage2, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmBuildArea(eastIslandVillage2);

      int middleSufiVillageID2 = -1;
      int middleSufiVillageID2Type = rmRandInt(1,3);
      middleSufiVillageID2 = rmCreateGrouping("native2 city", "Zen_GreatBuddha_0"+middleSufiVillageID2Type);
      rmAddGroupingConstraint(middleSufiVillageID2, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID2, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);

      // East Monastery 1

      int zenControllerID5 = rmCreateObjectDef("zen controller 5");
      rmAddObjectDefItem(zenControllerID5, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID5, 0.0);
      rmAddObjectDefConstraint(zenControllerID5, avoidController); 
      rmAddObjectDefConstraint(zenControllerID5, playerEdgeConstraint); 

      if (monasteryPlacement == 1)
      {
      rmPlaceObjectDefAtLoc(zenControllerID5, 0, 0.8, 0.7);
      }
      else 
      {
      rmPlaceObjectDefAtLoc(zenControllerID5, 0, 0.2, 0.7);
      }

      vector malteseControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID5, 0));

      int eastIslandVillage5 = rmCreateArea ("east island village 5");
      int zenWaterBasin5 = rmCreateArea ("zen water basin 5");
      int eastIslandVillage5ramp = rmCreateArea ("east island village5 ramp 1");

      rmSetAreaSize(zenWaterBasin5, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(zenWaterBasin5, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)));
      rmSetAreaWaterType(zenWaterBasin5, "zp borneo lake");
      rmSetAreaBaseHeight(zenWaterBasin5, 0);
      rmSetAreaCoherence(zenWaterBasin5, 0.65);
      rmBuildArea(zenWaterBasin5);

      rmSetAreaSize(eastIslandVillage5ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage5ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)-30));
      rmSetAreaBaseHeight(eastIslandVillage5ramp, 6.2);
      rmSetAreaCoherence(eastIslandVillage5ramp, 0.8);
      rmSetAreaMix(eastIslandVillage5ramp, baseMix);
        rmAddAreaTerrainLayer(eastIslandVillage5ramp, "borneo\ground_grass4_borneo", 9, 12);
      rmSetAreaSmoothDistance(eastIslandVillage5ramp, 30);
      rmBuildArea(eastIslandVillage5ramp);

      rmSetAreaSize(eastIslandVillage5, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
      rmSetAreaLocation(eastIslandVillage5, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)));
      rmSetAreaCoherence(eastIslandVillage5, 0.9);
      rmSetAreaSmoothDistance(eastIslandVillage5, 5);
      rmSetAreaCliffType(eastIslandVillage5, "ZP Borneo");
      rmSetAreaCliffEdge(eastIslandVillage5, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage5, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage5, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage5, 0.0);
      rmBuildArea(eastIslandVillage5);

      int middleSufiVillageID5 = -1;
      int middleSufiVillageID5Type = rmRandInt(1,3);
      middleSufiVillageID5 = rmCreateGrouping("native5 city", "Sufi_GreatMosque_0"+middleSufiVillageID5Type);
      rmAddGroupingConstraint(middleSufiVillageID5, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID5, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)), 1);

      
      if (cNumberNonGaiaPlayers >= 5){
        // West Monastery 2

        int zenControllerID3 = rmCreateObjectDef("zen controller 3");
        rmAddObjectDefItem(zenControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
        rmSetObjectDefMinDistance(zenControllerID3, 0.0);
        rmAddObjectDefConstraint(zenControllerID3, avoidController); 
        rmAddObjectDefConstraint(zenControllerID3, playerEdgeConstraint); 

        if (monasteryPlacement == 1)
        {
        rmPlaceObjectDefAtLoc(zenControllerID3, 0, 0.1, 0.5);
        }
        else 
        {
        rmPlaceObjectDefAtLoc(zenControllerID3, 0, 0.9, 0.5);
        }
        vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID3, 0));

        int eastIslandVillage3 = rmCreateArea ("east island village 3");
        int zenWaterBasin3 = rmCreateArea ("zen water basin 3");
        int eastIslandVillage3ramp = rmCreateArea ("east island village3 ramp 1");

        rmSetAreaSize(zenWaterBasin3, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
        rmSetAreaLocation(zenWaterBasin3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
        rmSetAreaWaterType(zenWaterBasin3, "zp borneo lake");
        rmSetAreaBaseHeight(zenWaterBasin3, 0);
        rmSetAreaCoherence(zenWaterBasin3, 0.65);
        rmBuildArea(zenWaterBasin3);

        rmSetAreaSize(eastIslandVillage3ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
        rmSetAreaLocation(eastIslandVillage3ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)-30));
        rmSetAreaBaseHeight(eastIslandVillage3ramp, 6.2);
        rmSetAreaCoherence(eastIslandVillage3ramp, 0.8);
        rmSetAreaMix(eastIslandVillage3ramp, baseMix);
          rmAddAreaTerrainLayer(eastIslandVillage3ramp, "borneo\ground_grass4_borneo", 9, 12);
        rmSetAreaSmoothDistance(eastIslandVillage3ramp, 30);
        rmBuildArea(eastIslandVillage3ramp);

        rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
        rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
        rmSetAreaCoherence(eastIslandVillage3, 0.9);
        rmSetAreaSmoothDistance(eastIslandVillage3, 5);
        rmSetAreaCliffType(eastIslandVillage3, "ZP Borneo");
        rmSetAreaCliffEdge(eastIslandVillage3, 1, 1.0, 0.0, 1.0, 0);
        rmSetAreaCliffHeight(eastIslandVillage3, 1.0, 0.0, 0.5); 
        rmSetAreaBaseHeight(eastIslandVillage3, 5.2);
        rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
        rmBuildArea(eastIslandVillage3);

        int middleSufiVillageID3 = -1;
        int middleSufiVillageID3Type = rmRandInt(1,3);
        middleSufiVillageID3 = rmCreateGrouping("native3 city", "Zen_GreatBuddha_0"+middleSufiVillageID3Type);
        rmAddGroupingConstraint(middleSufiVillageID3, avoidImpassableLand);
        rmPlaceGroupingAtLoc(middleSufiVillageID3, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);

        // East Monastery 2

        int zenControllerID6 = rmCreateObjectDef("zen controller 6");
        rmAddObjectDefItem(zenControllerID6, "zpSPCWaterSpawnPoint", 1, 0.0);
        rmSetObjectDefMinDistance(zenControllerID6, 0.0);
        rmAddObjectDefConstraint(zenControllerID6, avoidController); 
        rmAddObjectDefConstraint(zenControllerID6, playerEdgeConstraint); 

        if (monasteryPlacement == 1)
        {
        rmPlaceObjectDefAtLoc(zenControllerID6, 0, 0.9, 0.5);
        }
        else 
        {
        rmPlaceObjectDefAtLoc(zenControllerID6, 0, 0.1, 0.5);
        }
        vector malteseControllerLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID6, 0));

        int eastIslandVillage6 = rmCreateArea ("east island village 6");
        int zenWaterBasin6 = rmCreateArea ("zen water basin 6");
        int eastIslandVillage6ramp = rmCreateArea ("east island Village6 ramp 1");

        rmSetAreaSize(zenWaterBasin6, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
        rmSetAreaLocation(zenWaterBasin6, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)));
        rmSetAreaWaterType(zenWaterBasin6, "zp borneo lake");
        rmSetAreaBaseHeight(zenWaterBasin6, 0);
        rmSetAreaCoherence(zenWaterBasin6, 0.65);
        rmBuildArea(zenWaterBasin6);

        rmSetAreaSize(eastIslandVillage6ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
        rmSetAreaLocation(eastIslandVillage6ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)-30));
        rmSetAreaBaseHeight(eastIslandVillage6ramp, 6.2);
        rmSetAreaCoherence(eastIslandVillage6ramp, 0.8);
        rmSetAreaMix(eastIslandVillage6ramp, baseMix);
          rmAddAreaTerrainLayer(eastIslandVillage6ramp, "borneo\ground_grass4_borneo", 9, 12);
        rmSetAreaSmoothDistance(eastIslandVillage6ramp, 30);
        rmBuildArea(eastIslandVillage6ramp);

        rmSetAreaSize(eastIslandVillage6, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
        rmSetAreaLocation(eastIslandVillage6, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)));
        rmSetAreaCoherence(eastIslandVillage6, 0.9);
        rmSetAreaSmoothDistance(eastIslandVillage6, 5);
        rmSetAreaCliffType(eastIslandVillage6, "ZP Borneo");
        rmSetAreaCliffEdge(eastIslandVillage6, 1, 1.0, 0.0, 1.0, 0);
        rmSetAreaCliffHeight(eastIslandVillage6, 1.0, 0.0, 0.5); 
        rmSetAreaBaseHeight(eastIslandVillage6, 5.2);
        rmSetAreaElevationVariation(eastIslandVillage6, 0.0);
        rmBuildArea(eastIslandVillage6);

        int middleSufiVillageID6 = -1;
        int middleSufiVillageID6Type = rmRandInt(1,3);
        middleSufiVillageID6 = rmCreateGrouping("native6 city", "Sufi_GreatMosque_0"+middleSufiVillageID6Type);
        rmAddGroupingConstraint(middleSufiVillageID6, avoidImpassableLand);
        rmPlaceGroupingAtLoc(middleSufiVillageID6, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)), 1);
      }

      if (cNumberNonGaiaPlayers >= 7){
        // West Monastery 3

        int zenControllerID4 = rmCreateObjectDef("zen controller 4");
        rmAddObjectDefItem(zenControllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
        rmSetObjectDefMinDistance(zenControllerID4, 0.0);
        rmAddObjectDefConstraint(zenControllerID4, avoidController); 
        rmAddObjectDefConstraint(zenControllerID4, playerEdgeConstraint); 

        if (monasteryPlacement == 1)
        {
        rmPlaceObjectDefAtLoc(zenControllerID4, 0, 0.35, 0.8);
        }
        else 
        {
        rmPlaceObjectDefAtLoc(zenControllerID4, 0, 0.65, 0.8);
        }
        vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID4, 0));

        int eastIslandVillage4 = rmCreateArea ("east island village 4");
        int zenWaterBasin4 = rmCreateArea ("zen water basin 4");
        int eastIslandVillage4ramp = rmCreateArea ("east island village4 ramp 1");

        rmSetAreaSize(zenWaterBasin4, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
        rmSetAreaLocation(zenWaterBasin4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
        rmSetAreaWaterType(zenWaterBasin4, "zp borneo lake");
        rmSetAreaBaseHeight(zenWaterBasin4, 0);
        rmSetAreaCoherence(zenWaterBasin4, 0.65);
        rmBuildArea(zenWaterBasin4);

        rmSetAreaSize(eastIslandVillage4ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
        rmSetAreaLocation(eastIslandVillage4ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)+30));
        rmSetAreaBaseHeight(eastIslandVillage4ramp, 6.2);
        rmSetAreaCoherence(eastIslandVillage4ramp, 0.8);
        rmSetAreaMix(eastIslandVillage4ramp, baseMix);
          rmAddAreaTerrainLayer(eastIslandVillage4ramp, "borneo\ground_grass4_borneo", 9, 12);
        rmSetAreaSmoothDistance(eastIslandVillage4ramp, 30);
        rmBuildArea(eastIslandVillage4ramp);

        rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
        rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
        rmSetAreaCoherence(eastIslandVillage4, 0.9);
        rmSetAreaSmoothDistance(eastIslandVillage4, 5);
        rmSetAreaCliffType(eastIslandVillage4, "ZP Borneo");
        rmSetAreaCliffEdge(eastIslandVillage4, 1, 1.0, 0.0, 1.0, 0);
        rmSetAreaCliffHeight(eastIslandVillage4, 1.0, 0.0, 0.5); 
        rmSetAreaBaseHeight(eastIslandVillage4, 5.2);
        rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
        rmBuildArea(eastIslandVillage4);

        int middleSufiVillageID4 = -1;
        int middleSufiVillageID4Type = rmRandInt(1,3);
        middleSufiVillageID4 = rmCreateGrouping("native4 city", "Zen_GreatBuddha_0"+middleSufiVillageID4Type);
        rmAddGroupingConstraint(middleSufiVillageID4, avoidImpassableLand);
        rmPlaceGroupingAtLoc(middleSufiVillageID4, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);

      
        // East Monastery 3

        int zenControllerID7 = rmCreateObjectDef("zen controller 7");
        rmAddObjectDefItem(zenControllerID7, "zpSPCWaterSpawnPoint", 1, 0.0);
        rmSetObjectDefMinDistance(zenControllerID7, 0.0);
        rmAddObjectDefConstraint(zenControllerID7, avoidController); 
        rmAddObjectDefConstraint(zenControllerID7, playerEdgeConstraint); 

        if (monasteryPlacement == 1)
        {
        rmPlaceObjectDefAtLoc(zenControllerID7, 0, 0.65, 0.8);
        }
        else 
        {
        rmPlaceObjectDefAtLoc(zenControllerID7, 0, 0.35, 0.8);
        }
        vector malteseControllerLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID7, 0));

        int eastIslandVillage7 = rmCreateArea ("east island village 7");
        int zenWaterBasin7 = rmCreateArea ("zen water basin 7");
        int eastIslandVillage7ramp = rmCreateArea ("east island Village7 ramp 1");

        rmSetAreaSize(zenWaterBasin7, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
        rmSetAreaLocation(zenWaterBasin7, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc7)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc7)));
        rmSetAreaWaterType(zenWaterBasin7, "zp borneo lake");
        rmSetAreaBaseHeight(zenWaterBasin7, 0);
        rmSetAreaCoherence(zenWaterBasin7, 0.65);
        rmBuildArea(zenWaterBasin7);

        rmSetAreaSize(eastIslandVillage7ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
        rmSetAreaLocation(eastIslandVillage7ramp, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc7)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc7)-30));
        rmSetAreaBaseHeight(eastIslandVillage7ramp, 6.2);
        rmSetAreaCoherence(eastIslandVillage7ramp, 0.8);
        rmSetAreaMix(eastIslandVillage7ramp, baseMix);
          rmAddAreaTerrainLayer(eastIslandVillage7ramp, "borneo\ground_grass4_borneo", 9, 12);
        rmSetAreaSmoothDistance(eastIslandVillage7ramp, 30);
        rmBuildArea(eastIslandVillage7ramp);

        rmSetAreaSize(eastIslandVillage7, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
        rmSetAreaLocation(eastIslandVillage7, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc7)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc7)));
        rmSetAreaCoherence(eastIslandVillage7, 0.9);
        rmSetAreaSmoothDistance(eastIslandVillage7, 5);
        rmSetAreaCliffType(eastIslandVillage7, "ZP Borneo");
        rmSetAreaCliffEdge(eastIslandVillage7, 1, 1.0, 0.0, 1.0, 0);
        rmSetAreaCliffHeight(eastIslandVillage7, 1.0, 0.0, 0.5); 
        rmSetAreaBaseHeight(eastIslandVillage7, 5.2);
        rmSetAreaElevationVariation(eastIslandVillage7, 0.0);
        rmBuildArea(eastIslandVillage7);

        int middleSufiVillageID7 = -1;
        int middleSufiVillageID7Type = rmRandInt(1,3);
        middleSufiVillageID7 = rmCreateGrouping("native7 city", "Sufi_GreatMosque_0"+middleSufiVillageID7Type);
        rmAddGroupingConstraint(middleSufiVillageID7, avoidImpassableLand);
        rmPlaceGroupingAtLoc(middleSufiVillageID7, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc7)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc7)), 1);
      }
  }  

    // Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.70, 0.30);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.2, 0.3, 0);
		}
		else
		{
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.70, 0.90);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.10, 0.30);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.10, 0.30);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.70, 0.90);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
			}
		}

    // Insert Players
    int TCfloat = -1;
    if (cNumberTeams == 2)
	    TCfloat = 50;
    else 
	    TCfloat = 135;



    int TCID = rmCreateObjectDef("player TC");
    if (rmGetNomadStart())
      {
        rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
      }
    else{
      rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
    }

    int colonyShipID = 0;
    

  rmSetObjectDefMinDistance(TCID, 0.0);
  rmSetObjectDefMaxDistance(TCID, TCfloat);

//Player resources
   int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
   rmAddObjectDefConstraint(playerMineID, avoidImpassableLand); 

   int playerDeerID=rmCreateObjectDef("player deer");
   rmAddObjectDefItem(playerDeerID, "ypSerow", rmRandInt(10,15), 10.0);
   rmSetObjectDefMinDistance(playerDeerID, 15.0);
   rmSetObjectDefMaxDistance(playerDeerID, 30.0);
   rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(playerDeerID, true);

rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, avoidBonusIslands);
rmAddObjectDefConstraint(TCID, avoidSocket2);
  

for(i=1; <cNumberPlayers) {

// Place town centers
   rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

// Water flag placement rules
   colonyShipID=rmCreateObjectDef("colony ship "+i);
   rmAddObjectDefItem(colonyShipID, "HomeCityWaterSpawnFlag", 1, 1.0);
   if ( rmGetNomadStart())
   {
      if(rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
        rmAddObjectDefItem(colonyShipID, "Galley", 1, 10.0);
      else
        rmAddObjectDefItem(colonyShipID, "caravel", 1, 10.0);
   }
   rmAddClosestPointConstraint(flagEdgeConstraint);
   rmAddClosestPointConstraint(flagVsFlag);
   rmAddClosestPointConstraint(flagLand);
   vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

// Place resources
   rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
   rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

   if(ypIsAsian(i) && rmGetNomadStart() == false)
     rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
}

rmClearClosestPointConstraints();


	// Text
	rmSetStatusText("",0.45);
   
  // Berries
  int berriesID=rmCreateObjectDef("berries");
	rmAddObjectDefItem(berriesID, "berrybush", 7, 6.0);
	rmSetObjectDefMinDistance(berriesID, 0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, longPlayerConstraint);
  rmAddObjectDefConstraint(berriesID, avoidBerries);
  rmAddObjectDefConstraint(berriesID, shortAvoidImportantItem);
  rmAddObjectDefConstraint(berriesID, shortAvoidResource);
  rmAddObjectDefConstraint(berriesID, eastIslandConstraint);
  rmPlaceObjectDefPerPlayer(berriesID, false, 1.5);

  int berriesID2=rmCreateObjectDef("berries 2");
	rmAddObjectDefItem(berriesID2, "berrybush", 7, 6.0);
	rmSetObjectDefMinDistance(berriesID2, 0);
	rmSetObjectDefMaxDistance(berriesID2, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(berriesID2, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID2, longPlayerConstraint);
  rmAddObjectDefConstraint(berriesID2, avoidBerries);
  rmAddObjectDefConstraint(berriesID2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(berriesID2, shortAvoidResource);
  rmAddObjectDefConstraint(berriesID2, westIslandConstraint);
  rmPlaceObjectDefPerPlayer(berriesID2, false, 1.5);
  

  
  // Forests
  int forestTreeID = 0;
  int numTries=6*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest, forestType);
    rmSetAreaForestDensity(forest, 0.6);
    rmSetAreaForestClumpiness(forest, 0.4);
    rmSetAreaForestUnderbrush(forest, 0.0);
    rmSetAreaMinBlobs(forest, 1);
    rmSetAreaMaxBlobs(forest, 5);
    rmSetAreaMinBlobDistance(forest, 16.0);
    rmSetAreaMaxBlobDistance(forest, 40.0);
    rmSetAreaCoherence(forest, 0.4);
    rmSetAreaSmoothDistance(forest, 10);
    rmAddAreaToClass(forest, rmClassID("classForest")); 
    rmAddAreaConstraint(forest, forestConstraint);
    rmAddAreaConstraint(forest, avoidAll);
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
  
	// Text
	rmSetStatusText("",0.85);
  
  
  // MINES

   int mineType = -1;
	int mineID = -1;
	int mineCount = (cNumberNonGaiaPlayers*1.25);
	rmEchoInfo("mine count = "+mineCount);

	for(i=0; < mineCount)
	{
	  int westmineID = rmCreateObjectDef("west mine "+i);
	  rmAddObjectDefItem(westmineID, "Mine", 1, 0.0);
      rmSetObjectDefMinDistance(westmineID, 0.0);
      rmSetObjectDefMaxDistance(westmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(westmineID, avoidCoin);
      rmAddObjectDefConstraint(westmineID, avoidAll);
      rmAddObjectDefConstraint(westmineID, playerConstraintNugget);
      rmAddObjectDefConstraint(westmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(westmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(westmineID, westIslandConstraint);
	  rmPlaceObjectDefAtLoc(westmineID, 0, 0.5, 0.5);
   }

   for(i=0; < mineCount)
	{
	  int eastmineID = rmCreateObjectDef("east mine "+i);
	  rmAddObjectDefItem(eastmineID, "Mine", 1, 0.0);
      rmSetObjectDefMinDistance(eastmineID, 0.0);
      rmSetObjectDefMaxDistance(eastmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(eastmineID, avoidCoin);
      rmAddObjectDefConstraint(eastmineID, avoidAll);
      rmAddObjectDefConstraint(eastmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(eastmineID, playerConstraintNugget);
      rmAddObjectDefConstraint(eastmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(eastmineID, eastIslandConstraint);
	  rmPlaceObjectDefAtLoc(eastmineID, 0, 0.5, 0.5);
   } 
 
  // Nuggets
  int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
  rmAddObjectDefConstraint(nuggetNorth, avoidSocket);
	rmAddObjectDefConstraint(nuggetNorth, avoidTCMedium);
  rmAddObjectDefConstraint(nuggetNorth, avoidWater4);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorth, 0, mainIslandID, cNumberNonGaiaPlayers);

  int nuggetSouthHard= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouthHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefConstraint(nuggetSouthHard, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouthHard, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouthHard, avoidSocket);
	rmAddObjectDefConstraint(nuggetSouthHard, avoidTCMedium);
   rmAddObjectDefConstraint(nuggetSouthHard, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouthHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouthHard, 0, mainIslandID2, cNumberNonGaiaPlayers);
  
  int nuggetNorthHard= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetNorthHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefConstraint(nuggetNorthHard, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidNugget);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidSocket);
	rmAddObjectDefConstraint(nuggetNorthHard, avoidTCshort);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidWater4);
	rmAddObjectDefConstraint(nuggetNorthHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorthHard, 0, mainIslandID, cNumberNonGaiaPlayers);

  int nuggetSouth= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouth, avoidSocket);
	rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, mainIslandID2, cNumberNonGaiaPlayers);
  
	
	// Resources that can be placed after forests
  if (cNumberNonGaiaPlayers > 2)
  {
    int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, shortAvoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
  rmAddObjectDefConstraint(food1ID, eastIslandConstraint);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable2, rmRandInt(2,3), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, shortAvoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
  rmAddObjectDefConstraint(food2ID, westIslandConstraint);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);

    rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
    rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);
  }
  else
  {
    //1v1 hunts

   /* int deerID=rmCreateObjectDef("ibex herd");
	int bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(deerID, "ypSerow", rmRandInt(4,6), 10.0);
   else
      rmAddObjectDefItem(deerID, "ypSerow", rmRandInt(8,10), 10.0);
   rmSetObjectDefMinDistance(deerID, 0.0);
   rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
   rmAddObjectDefConstraint(deerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(deerID, true);
   rmPlaceObjectDefInArea(deerID, 0, eastIsland, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, westIsland, cNumberNonGaiaPlayers);*/
    
    int mapElephants = rmCreateObjectDef("mapElephants");
    rmAddObjectDefItem(mapElephants, "ypWildElephant", 4, 5.0);
    rmSetObjectDefCreateHerd(mapElephants, true);
    rmSetObjectDefMinDistance(mapElephants, 0);
    rmSetObjectDefMaxDistance(mapElephants, 15);
    rmAddObjectDefConstraint(mapElephants, avoidSocket2);
    rmAddObjectDefConstraint(mapElephants, forestConstraintShort);	
    rmAddObjectDefConstraint(mapElephants, avoidHunt3);
    rmAddObjectDefConstraint(mapElephants, avoidAll);       
    rmAddObjectDefConstraint(mapElephants, circleConstraint2);  
    rmAddObjectDefConstraint(mapElephants, avoidBonusIslands); 
    rmAddObjectDefConstraint(mapElephants, avoidWater5);  
    //left side
        //elifents
    rmPlaceObjectDefAtLoc(mapElephants, 0, 0.2, 0.6, 1);
    rmPlaceObjectDefAtLoc(mapElephants, 0, 0.4, 0.8, 1);

    //right side
        //elifents
    rmPlaceObjectDefAtLoc(mapElephants, 0, 0.8, 0.6, 1);
    rmPlaceObjectDefAtLoc(mapElephants, 0, 0.6, 0.8, 1);

  }
	// Text
	rmSetStatusText("",0.90);
    
  int fishID=rmCreateObjectDef("fish 1");
  rmAddObjectDefItem(fishID, fish1, 1, 0.0);
  rmSetObjectDefMinDistance(fishID, 0.0);
  rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fishID, fishVsFishID);
  rmAddObjectDefConstraint(fishID, fishLand);
  rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.15, 6*cNumberNonGaiaPlayers);
    
  int fish2ID=rmCreateObjectDef("fish 2");
  rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
  rmSetObjectDefMinDistance(fish2ID, 0.0);
  rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fish2ID, fishVsFish2ID);
  rmAddObjectDefConstraint(fish2ID, fishLand);
  rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.15, 6*cNumberNonGaiaPlayers);
  
  // extra fish for under 5 players
  if (cNumberNonGaiaPlayers < 5)
  {
    int fish3ID=rmCreateObjectDef("fish 3");
    rmAddObjectDefItem(fish3ID, fish1, 1, 0.0);
    rmSetObjectDefMinDistance(fish3ID, 0.0);
    rmSetObjectDefMaxDistance(fish3ID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(fish3ID, fishVsFishID);
    rmAddObjectDefConstraint(fish3ID, fishLand);
    rmPlaceObjectDefAtLoc(fish3ID, 0, 0.5, 0.1, 7*cNumberNonGaiaPlayers);
  }  
    
  int whaleID=rmCreateObjectDef("whale");
  rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
  rmSetObjectDefMinDistance(whaleID, 0.0);
  rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);  
  rmAddObjectDefConstraint(whaleID, whaleEdgeConstraint);
  rmAddObjectDefConstraint(whaleID, whaleLand);
  rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);
  
  // Water nuggets
  
  int nuggetW= rmCreateObjectDef("nugget water"); 
  rmAddObjectDefItem(nuggetW, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetW, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetW, nuggetVsFlag);
  rmPlaceObjectDefAtLoc(nuggetW, 0, 0.5, 0.1, cNumberNonGaiaPlayers*4);

      // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "ypTreeBorneo", 1, 0.0);
   rmAddObjectDefConstraint(villageTreeID, ObjectAvoidTradeRouteShort);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage1, 15);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage2, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage3, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage4, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage5, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage6, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage7, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, portSite1, 20);
   rmPlaceObjectDefInArea(villageTreeID, 0, portSite2, 20);
    
// ------Triggers--------//

int tch0=1671; // tech operator

// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpIsBurmaMap"); // Trade Route Setup
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

// Update ports

rmCreateTrigger("I Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","zpChinaTreasureShip");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
for (k=1; <= cNumberNonGaiaPlayers) {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpGaiaKillTreasureship");
      rmSetTriggerEffectParamInt("Status",2);
    }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

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
rmCreateTrigger("Activate Wokou"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpBlackmailing"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWokou"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Wokou"+k));
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
   rmSetTriggerConditionParam("DstObject","56");
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


rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
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
   rmSetTriggerConditionParam("DstObject","56");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   
   rmSwitchToTrigger(rmTriggerID("trainFuchuan2TIME_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","3");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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

// Pirate trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Pirates1on Player"+k);
rmCreateTrigger("Pirates1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","3");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","3");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Pirates2on Player"+k);
   rmCreateTrigger("Pirates2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   }


// Send Wokou Random Ship

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("Takanobu Random Ship"+k);
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpWokouRandomShip");
rmSetTriggerConditionParamInt("Status",2);

int randShip=-1;
randShip = rmRandInt(1,5);

if (randShip==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpSendQueenAnne"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (randShip==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpSendBlackPearl"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (randShip==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpSendNeptune"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (randShip==4)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpSendSteamer"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (randShip==5)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpSendSubmarine"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Pirate Captains

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
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",4929);
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",3645);
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}*/
  
  
  // Text
	rmSetStatusText("",0.99);
}  
