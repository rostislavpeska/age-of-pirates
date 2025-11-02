// BALEARIC ISLANDS 1.0
// Mediterranean archipelago based on Philippines structure
// Uses Malta types + Habsburg/Jesuits/Pirates natives

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);
	
	// ============================================================================
  // MAP TYPE VARIABLES - Mediterranean Theme
	// ============================================================================
	
  // Natives
  string nativeCiv1 = "Habsburg";
  string nativeCiv2 = "SPCJesuit";
  string nativeCiv3 = "natpirates";
  
  // Terrain and visuals
  string baseMix = "italy_grass_dry";
  string paintMix = "italy_grass";
  string paintMix2 = "italy_grass_medium_dry";
  string paintMix3 = "italy_grass_medium";
  string paintMix4 = "italy_cliff_top";
  string paintMix5 = "italy_cliff_top_dry";
  string paintMix6 = "italy_dirt";
  string baseTerrain = "water";
  string playerTerrain = "italy\ground_grass1_ita";
  string seaType = "ZP Malta No Waves";
  string startTreeType = "TreeMediterranean";
  string forestType = "z31 mediterranean coastal forest";
  string cliffType = "Italian Cliff";
  
  // Map types
  string mapType1 = "grass";
  string mapType2 = "water";
  string mapType3 = "mediEurope";
  string mapType4 = "medisea";
  string mapType5 = "euroNavalTradeRoute";
  string mapType6 = "piratehistoricalmap";
  
  // Resources
  string huntable1 = "ypIbex";
  string fish1 = "ypFishTuna";
  string whale1 = "MinkeWhale";
  string lightingType = "punjab_skirmish";
  string patchTerrain = "italy\ground_grass2_ita";
  string patchType1 = "italy\ground_grass3_ita";
  string patchType2 = "borneo\ground_sand1_borneo";
  string mineType = "MineCopper";
  string mineType2 = "zpPearlSource";

  
	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	
  // Loop variables
  int i=0;
  int k=0;
  
  // Native pattern for player settlements (0 or 1)
  // 0 = even players get Habsburg, odd get Jesuits
  // 1 = odd players get Habsburg, even get Jesuits
  int nativePattern = rmRandInt(0,1);
	
	if (rmAllocateSubCivs(3) == true)
	{
   subCiv0=rmGetCivID("natpirates");
   rmEchoInfo("subCiv0 is pirates "+subCiv0);
		if (subCiv0 >= 0)
   rmSetSubCiv(0, "natpirates");
		
   subCiv1=rmGetCivID("Habsburg");
   rmEchoInfo("subCiv1 is Habsburg "+subCiv1);
		if (subCiv1 >= 0)
   rmSetSubCiv(1, "Habsburg");
		
   subCiv2=rmGetCivID("SPCJesuit");
   rmEchoInfo("subCiv2 is SPCJesuit "+subCiv2);
		if (subCiv2 >= 0)
   rmSetSubCiv(2, "SPCJesuit");
	}

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=23000;
	if(cNumberNonGaiaPlayers < 5)
		playerTiles = 25500;
	if (cNumberNonGaiaPlayers < 3)
		playerTiles = 29500;
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	
	// Set up default water type.
	rmSetSeaLevel(1.0);
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType(mapType3);
	rmSetMapType(mapType4);
	rmSetMapType(mapType5);
	rmSetMapType(mapType6);
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
	rmDefineClass("classCliff");
	int classCanyon=rmDefineClass("canyon");
	int classNatives=rmDefineClass("natives");
	int classShallows=rmDefineClass("shallow");
	
   // -------------Define constraints----------------------------------------
	
    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
	
	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 10.0);
	int avoidTPLong=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets far", "SocketTradeRoute", 15.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
	int avoidLandShort = rmCreateTerrainDistanceConstraint("ship avoid land short", "land", true, 5.0);
	int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion of island", .35, .55, .65, .35);
	int northConstraint = rmCreateBoxConstraint("huntable constraint for north side of island", .25, .55, .8, .85);
	int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 12.0);
	int avoidTCLong=rmCreateTypeDistanceConstraint("stay away from TC by far", "TownCenter", 30.0);
	int avoidNatives=rmCreateClassDistanceConstraint("avoid natives", classNatives, 50.0);
	int avoidNativesMed=rmCreateClassDistanceConstraint("avoid natives med", classNatives, 30.0);

		// Island Constraints  
	if (cNumberTeams < 5) {
		if (cNumberNonGaiaPlayers == 2) {
			int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 30.0);
		}
		else {
			islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 36.0);
		}
	}
	else {
		islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 30.0);
	}

	int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
  
	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 12.0);	
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidCliff=rmCreateClassDistanceConstraint("cliffs avoid each other", rmClassID("classCliff"), 30.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", mineType, 45.0);
	int avoidPearls=rmCreateTypeDistanceConstraint("avoid pearls", mineType2, 10.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
	int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
	int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 
		
	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int avoidMesa=rmCreateClassDistanceConstraint("avoid random mesas on south central portion of migration island", classCanyon, 10.0);
	int avoidShallows=rmCreateClassDistanceConstraint("stay away from shallows", classShallows, 2.0);

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
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "Socket", 10.0);
	
	// flag constraints
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 15.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
	int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
	int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
	int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
	int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

	//Trade Route Contstraints
	int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 12.0);
	int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

	// Base area at water level (elevation 0) - elongated north-south for cross effect
	int baseIslandID = rmCreateArea("base island");
	if (cNumberNonGaiaPlayers <= 3) {
		rmSetAreaSize(baseIslandID, 0.05, 0.05);
	}
	else {
		rmSetAreaSize(baseIslandID, 0.04, 0.04);
	}
	rmSetAreaCoherence(baseIslandID, 0.75);
	rmSetAreaBaseHeight(baseIslandID, 0.5); // Water level
	rmSetAreaSmoothDistance(baseIslandID, 20);
	rmSetAreaMix(baseIslandID, baseMix);
	rmAddAreaToClass(baseIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(baseIslandID, false);
	rmSetAreaLocation(baseIslandID, .5, .5);
	rmAddAreaInfluenceSegment(baseIslandID, .5, .44, .58, .5);
	rmAddAreaInfluenceSegment(baseIslandID, .5, .56, .58, .5);
	rmAddAreaInfluenceSegment(baseIslandID, .5, .44, .46, .5);
	rmAddAreaInfluenceSegment(baseIslandID, .5, .56, .46, .5);
	rmBuildArea(baseIslandID);

	// Elevated island on top (center bonus island) - elongated east-west for cross effect
	int bigIslandID=rmCreateArea("migration island");
	if (cNumberNonGaiaPlayers <= 3) {
		rmSetAreaSize(bigIslandID, 0.05, 0.05);
	}
	else {
		rmSetAreaSize(bigIslandID, 0.04, 0.04);
	}
	rmSetAreaCoherence(bigIslandID, 0.75);
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 20);
	rmSetAreaMix(bigIslandID, baseMix);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 2.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
	rmSetAreaLocation(bigIslandID, .5, .5);
	rmAddAreaInfluenceSegment(bigIslandID, .5, .44, .67, .5);
	rmAddAreaInfluenceSegment(bigIslandID, .5, .56, .67, .5);
	rmAddAreaInfluenceSegment(bigIslandID, .5, .44, .37, .5);
	rmAddAreaInfluenceSegment(bigIslandID, .5, .56, .37, .5);
	
	rmBuildArea(bigIslandID);
	
	// Pearl sources in shallow areas (coin source)
	// Add constraint to keep pearl sources apart
	
	int pearlNWID = rmCreateObjectDef("pearl northwest");
	rmAddObjectDefItem(pearlNWID, mineType2, 1, 0);
	rmSetObjectDefMinDistance(pearlNWID, 0.0);
	rmSetObjectDefMaxDistance(pearlNWID, 20.0);
	rmAddObjectDefConstraint(pearlNWID, avoidLandShort);
	rmAddObjectDefConstraint(pearlNWID, avoidPearls);
	rmPlaceObjectDefAtLoc(pearlNWID, 0, 0.50, 0.4); // Northwest (visual) = Code: medium X, low Z
	if (cNumberNonGaiaPlayers > 3) {
		rmPlaceObjectDefAtLoc(pearlNWID, 0, 0.50, 0.4);
	}
	
	int pearlSEID = rmCreateObjectDef("pearl southeast");
	rmAddObjectDefItem(pearlSEID, mineType2, 1, 0);
	rmSetObjectDefMinDistance(pearlSEID, 0.0);
	rmSetObjectDefMaxDistance(pearlSEID, 20.0);
	rmAddObjectDefConstraint(pearlSEID, avoidLandShort);
	rmAddObjectDefConstraint(pearlSEID, avoidPearls);
	rmPlaceObjectDefAtLoc(pearlSEID, 0, 0.50, 0.6); // Southeast (visual) = Code: medium-high X, high Z
	if (cNumberNonGaiaPlayers > 3) {
		rmPlaceObjectDefAtLoc(pearlSEID, 0, 0.50, 0.6);
	}
	    	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

   // Trade route (circular around center island) - rotated 90°
   int tradeRouteID = rmCreateTradeRoute();

   if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1)) { 
		// Bottom arc - Team 1
		rmAddTradeRouteWaypoint(tradeRouteID, 0.00, 0.4);   
		rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);   
		rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);  
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.4);   
		bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");
		
		// Top arc - Team 0
		int tradeRouteID2 = rmCreateTradeRoute();
		rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.6);   
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.82, 0.82);  
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.95);   
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.18, 0.82);  
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.00, 0.6);   
		bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");
   }
  	else {
		rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);   
		rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);   
		rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);   
		rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);   	
		rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82); 	

		placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");
   }

   //*************** PLACE PLAYERS ****************

   float teamStartLoc = rmRandFloat(0.0, 1.0);
  
   if (cNumberNonGaiaPlayers == 2) {
      if (teamStartLoc > 0.5)
			{
				rmPlacePlayer(1, 0.5, 0.8);
				rmPlacePlayer(2, 0.5, 0.2);
			}
			else
			{
				rmPlacePlayer(1, 0.5, 0.2);
				rmPlacePlayer(2, 0.5, 0.8);
			}
   }
   else {
      rmSetPlacementSection(0.40, 0.10);
      rmPlacePlayersCircular(0.29, 0.29, 0);
   }

   // For 3 players, use PLAYER ISLANDS (team islands have a game bug with 3 players)
   if (cNumberNonGaiaPlayers == 3) {
      float playerIsleSize = 0.18;  // Fixed size for 3 player islands
      for(i=1; <cNumberPlayers)
      {
         int playerIslandID = rmCreateArea("player island "+i);
         rmSetAreaSize(playerIslandID, playerIsleSize, playerIsleSize);
         rmSetAreaCoherence(playerIslandID, 0.5);
         rmSetAreaBaseHeight(playerIslandID, 2.0);
         rmSetAreaSmoothDistance(playerIslandID, 20);
         rmSetAreaMix(playerIslandID, baseMix);
         rmAddAreaToClass(playerIslandID, classIsland);
         rmSetAreaWarnFailure(playerIslandID, false);
         rmAddAreaConstraint(playerIslandID, islandConstraint);
         rmAddAreaConstraint(playerIslandID, islandEdgeConstraint);
         rmAddAreaConstraint(playerIslandID, islandAvoidTradeRoute);
         rmSetAreaElevationType(playerIslandID, cElevTurbulence);
         rmSetAreaElevationVariation(playerIslandID, 4.0);
         rmSetAreaElevationMinFrequency(playerIslandID, 0.09);
         rmSetAreaElevationOctaves(playerIslandID, 3);
         rmSetAreaElevationPersistence(playerIslandID, 0.2);
         rmSetAreaElevationNoiseBias(playerIslandID, 1);
         rmSetAreaLocPlayer(playerIslandID, i);  // Place island at player location
         rmEchoInfo("Player area "+i);   	

         rmBuildArea(playerIslandID);
      }
   }
   else {
      // For all other player counts, use TEAM ISLANDS
      if (cNumberTeams < 5) {
         float isleSize = (0.22 / cNumberTeams);  // Cook Islands formula
      }
      else {
         isleSize = (0.17 / cNumberTeams);  // Cook Islands formula
      }
	for(i=0; <cNumberTeams)
	{
         // Create the Team's area.
		int teamID=rmCreateArea("team "+i);
      rmSetAreaSize(teamID, isleSize, isleSize);
      rmSetAreaCoherence(teamID, 0.5);
      rmSetAreaBaseHeight(teamID, 2.0);
      rmSetAreaSmoothDistance(teamID, 20);
      rmSetAreaMix(teamID, baseMix);
      rmAddAreaToClass(teamID, classIsland);
      rmSetAreaWarnFailure(teamID, false);
      rmAddAreaConstraint(teamID, islandConstraint);
      rmAddAreaConstraint(teamID, islandEdgeConstraint);
      rmAddAreaConstraint(teamID, islandAvoidTradeRoute);
      rmSetAreaElevationType(teamID, cElevTurbulence);
      rmSetAreaElevationVariation(teamID, 4.0);
      rmSetAreaElevationMinFrequency(teamID, 0.09);
      rmSetAreaElevationOctaves(teamID, 3);
      rmSetAreaElevationPersistence(teamID, 0.2);
      rmSetAreaElevationNoiseBias(teamID, 1);
      rmSetAreaLocTeam(teamID, i);  // Place island at team's collective location
      rmEchoInfo("Team area "+i);  

      rmBuildArea(teamID);
      }
   }
		
   // Terrain patches for variation - dry Mediterranean look
	// Greener patches (italy_grass)
	for (i=0; < 20+cNumberNonGaiaPlayers*50) {
		int patchGreen = rmCreateArea("green patch "+i);
		rmSetAreaWarnFailure(patchGreen, false);
		rmSetAreaSize(patchGreen, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
		rmSetAreaMix(patchGreen, paintMix);
		rmSetAreaSmoothDistance(patchGreen, 1.0);
		rmAddAreaConstraint(patchGreen, avoidWater4);
		rmBuildArea(patchGreen); 
	}
	
	// Medium dry patches (italy_grass_medium_dry)
	for (i=0; < 100+cNumberNonGaiaPlayers*30) {
		int patchMedDry = rmCreateArea("med dry patch "+i);
		rmSetAreaWarnFailure(patchMedDry, false);
		rmSetAreaSize(patchMedDry, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
		rmSetAreaMix(patchMedDry, paintMix6);
		rmSetAreaSmoothDistance(patchMedDry, 1.0);
		rmAddAreaConstraint(patchMedDry, avoidWater4);
		rmBuildArea(patchMedDry); 
	}
	
	// Very dry cliff patches (italy_cliff_top_dry)
	for (i=0; < 40+cNumberNonGaiaPlayers*20) {
		int patchDry = rmCreateArea("dry cliff patch "+i);
		rmSetAreaWarnFailure(patchDry, false);
		rmSetAreaSize(patchDry, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
		rmSetAreaMix(patchDry, paintMix5);
		rmSetAreaSmoothDistance(patchDry, 1.0);
		rmAddAreaConstraint(patchDry, avoidNatives);
		rmBuildArea(patchDry); 
	}

   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
	
	// NATIVES
	
   int nativeIslandConstraint=rmCreateAreaConstraint("native Island", bigIslandID);
    
  
   // Place Controllers and Pirate Villages in a loop
   // 1 pirate settlement for 3 or fewer players, 2 for more than 3
   int numPirateSettlements = 1;
   if (cNumberNonGaiaPlayers > 3) {
      numPirateSettlements = 2;
   }
   
   for (i=0; <numPirateSettlements) {
      // Create controller
      int pirateControllerID = rmCreateObjectDef("Controler "+(i+1));
      rmAddObjectDefItem(pirateControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(pirateControllerID, 0.0);
      rmSetObjectDefMaxDistance(pirateControllerID, 25.0);
      rmAddObjectDefConstraint(pirateControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(pirateControllerID, ferryOnShore);
      
      // Place controller at fixed positions on island tips
      float controllerX = 0.5;
      float controllerZ = 0.5;
      
      if (i == 0) {
         // First pirate settlement - Northeast tip (visual) = Code: high X, medium-low Z
         controllerX = 0.66;
         controllerZ = 0.47;
      } else {
         // Second pirate settlement - Southwest tip (visual) = Code: low X, medium-high Z
         controllerX = 0.38;
         controllerZ = 0.53;
      }
      
      rmPlaceObjectDefAtLoc(pirateControllerID, 0, controllerX, controllerZ);
      vector pirateControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID, 0));
      
      // Create pirate village
      int piratesVillageID = -1;
      int piratesVillageType = 3;
      if (i == 1) {
         piratesVillageType = rmRandInt(1,2);
      }
      
      piratesVillageID = rmCreateGrouping("pirate city "+(i+1), "pirate_village0"+piratesVillageType);
      rmSetGroupingMinDistance(piratesVillageID, 0);
      rmSetGroupingMaxDistance(piratesVillageID, 20);
      rmAddGroupingConstraint(piratesVillageID, ferryOnShore);
      rmAddGroupingToClass(piratesVillageID, classNatives);
      rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc)), 1);
      
      // Create pirate water flag
         if (i == 0) {
            int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
            rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
            rmAddClosestPointConstraint(flagLandShort);
			rmAddClosestPointConstraint(avoidShallows);
            
            vector closeToVillage1 = rmFindClosestPointVector(pirateControllerLoc, rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));
            
            rmClearClosestPointConstraints();
         }
         if (i == 1) {
            int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
            rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
            rmAddClosestPointConstraint(flagLandShort);
            rmAddClosestPointConstraint(avoidShallows);
            
            vector closeToVillage2 = rmFindClosestPointVector(pirateControllerLoc, rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));
            
            rmClearClosestPointConstraints();
         }
   }

   // ************** jesuits in the middle *****************

   // Controller for cliff placement - SWAPPED X/Z for 90° rotation
	int cliffControllerID = rmCreateObjectDef("cliff controller");
	rmAddObjectDefItem(cliffControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
   if(cNumberNonGaiaPlayers <= 3) {
      rmPlaceObjectDefAtLoc(cliffControllerID, 0, 0.47, 0.47);
   }
   else {
      rmPlaceObjectDefAtLoc(cliffControllerID, 0, 0.5, 0.5);
   }
	vector cliffControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(cliffControllerID, 0));
	
	// South ramp (manually placed)
	int southRampID = rmCreateArea("south ramp");
	rmSetAreaSize(southRampID, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
	rmSetAreaLocation(southRampID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)-33), rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)));
	rmSetAreaBaseHeight(southRampID, 5.0);
	rmSetAreaCoherence(southRampID, 0.8);
	rmSetAreaMix(southRampID, baseMix);
	rmSetAreaSmoothDistance(southRampID, 30);
	rmBuildArea(southRampID);

	// Place Jesuit monastery on top of flat cliff
	rmSetNuggetDifficulty(503, 503);

	int rogueCityID = -1;
	rogueCityID = rmCreateGrouping("cliff monastery", "Rogue_Balearic");
	rmSetGroupingMinDistance(rogueCityID, 0);
	rmSetGroupingMaxDistance(rogueCityID, 10);
	rmAddGroupingToClass(rogueCityID, classNatives);
	int rogueSiteInstanceID1 = rmPlaceGroupingInstanceAtLoc(rogueCityID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)), 0);
	
	// North ramp (manually placed)
	int northRampID = rmCreateArea("north ramp");
	rmSetAreaSize(northRampID, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
	rmSetAreaLocation(northRampID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)+33), rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)));
	rmSetAreaBaseHeight(northRampID, 5.0);
	rmSetAreaCoherence(northRampID, 0.8);
	rmSetAreaMix(northRampID, baseMix);
	rmSetAreaSmoothDistance(northRampID, 30);
	rmBuildArea(northRampID);
	
	// Main cliff area (no automatic ramps - completely surrounded)
	int centerCliffID = rmCreateArea("center cliff");
	if(cNumberNonGaiaPlayers <= 3) {
		rmSetAreaSize(centerCliffID, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
	}
	else {
		rmSetAreaSize(centerCliffID, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	}
	rmSetAreaLocation(centerCliffID, rmXMetersToFraction(xsVectorGetX(cliffControllerLoc)), rmZMetersToFraction(xsVectorGetZ(cliffControllerLoc)));
	rmSetAreaCoherence(centerCliffID, 0.9);
	rmSetAreaSmoothDistance(centerCliffID, 5);
	rmSetAreaCliffType(centerCliffID, cliffType);
   	rmSetAreaCliffPainting(centerCliffID, false, true, true, 1.5, true);
	rmSetAreaCliffEdge(centerCliffID, 1, 1.0, 0.0, 1.0, 0);  // 1.0 = completely surrounded, no auto ramps
	rmSetAreaCliffHeight(centerCliffID, 1.0, 0.0, 0.5);
	rmSetAreaBaseHeight(centerCliffID, 4.0);
	rmAddAreaToClass(centerCliffID, rmClassID("classCliff"));
	rmSetAreaElevationVariation(centerCliffID, 0.0);
	rmBuildArea(centerCliffID);


   // check for KOTH game mode

  if(rmGetIsKOTH()){
   int KotHID= rmCreateObjectDef("KotH"); 
   rmAddObjectDefItem(KotHID, "ypKingsHill", 1, 0.0);
   rmAddObjectDefConstraint(KotHID, avoidAll);
   rmAddObjectDefConstraint(KotHID, avoidWater8);
   rmAddObjectDefConstraint(KotHID, avoidSocket);
   rmPlaceObjectDefInArea(KotHID, 0, bigIslandID, 1);
  }


	// Placing Player Trade Route Sockets with platform areas
	
	// Determine socket count and waypoint positions based on player count
	int socketCount = cNumberNonGaiaPlayers;
	
	// Socket waypoint positions for each player count (max 8 sockets for 8 players)
	float socketWaypoint0 = 0.0;
	float socketWaypoint1 = 0.0;
	float socketWaypoint2 = 0.0;
	float socketWaypoint3 = 0.0;
	float socketWaypoint4 = 0.0;
	float socketWaypoint5 = 0.0;
	float socketWaypoint6 = 0.0;
	float socketWaypoint7 = 0.0;
	
	// Set waypoints based on player count
	// For 2 equal teams, always use 4 sockets (2 per trade route)
	if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1)) {
		socketCount = 4;
		socketWaypoint0 = 0.25;  // Team 0, Socket 1
		socketWaypoint1 = 0.75;  // Team 0, Socket 2
		socketWaypoint2 = 0.25;  // Team 1, Socket 1
		socketWaypoint3 = 0.75;  // Team 1, Socket 2
	}
	else if(cNumberNonGaiaPlayers <= 2){
		socketCount = 2;
		socketWaypoint0 = 0.51;
		socketWaypoint1 = 0.01;
	}
	else if(cNumberNonGaiaPlayers == 3){
		socketCount = 3;
		socketWaypoint0 = 0.30;
		socketWaypoint1 = 0.75;
		socketWaypoint2 = 0.95;
	}
	else if(cNumberNonGaiaPlayers == 4){
		socketCount = 4;
		socketWaypoint0 = 0.03;
		socketWaypoint1 = 0.25;
		socketWaypoint2 = 0.50;
		socketWaypoint3 = 0.75;
	}
	else if(cNumberNonGaiaPlayers == 5){
		socketCount = 5;
		socketWaypoint0 = 0.20;
		socketWaypoint1 = 0.40;
		socketWaypoint2 = 0.55;
		socketWaypoint3 = 0.75;
		socketWaypoint4 = 0.99;
	}
	else if(cNumberNonGaiaPlayers == 6){
		socketCount = 6;
		socketWaypoint0 = 0.05;
		socketWaypoint1 = 0.17;
		socketWaypoint2 = 0.33;
		socketWaypoint3 = 0.45;
		socketWaypoint4 = 0.57;
		socketWaypoint5 = 0.75;
	}
	else if(cNumberNonGaiaPlayers == 7){
		socketCount = 7;
		socketWaypoint0 = 0.02;
		socketWaypoint1 = 0.15;
		socketWaypoint2 = 0.25;
		socketWaypoint3 = 0.38;
		socketWaypoint4 = 0.50;
		socketWaypoint5 = 0.63;
		socketWaypoint6 = 0.72;
	}
	else if(cNumberNonGaiaPlayers == 8){
		socketCount = 8;
		socketWaypoint0 = 0.03;
		socketWaypoint1 = 0.11;
		socketWaypoint2 = 0.22;
		socketWaypoint3 = 0.32;
		socketWaypoint4 = 0.43;
		socketWaypoint5 = 0.54;
		socketWaypoint6 = 0.63;
		socketWaypoint7 = 0.72;
	}
      
	// Place harbour groupings with platform areas offset toward center
	for(i=0; <socketCount) {
		// Get waypoint position for this socket
		float waypointPos = 0.5;
		if(i == 0) waypointPos = socketWaypoint0;
		else if(i == 1) waypointPos = socketWaypoint1;
		else if(i == 2) waypointPos = socketWaypoint2;
		else if(i == 3) waypointPos = socketWaypoint3;
		else if(i == 4) waypointPos = socketWaypoint4;
		else if(i == 5) waypointPos = socketWaypoint5;
		else if(i == 6) waypointPos = socketWaypoint6;
		else if(i == 7) waypointPos = socketWaypoint7;
		
		// Determine which trade route to use for 2 equal teams
		int useTradeRouteID = tradeRouteID;
		if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1)) {
			// Sockets 0-1 use Team 0 route (top arc), Sockets 2-3 use Team 1 route (bottom arc)
			if (i < 2) {
				useTradeRouteID = tradeRouteID2;  // Team 0 (top arc)
			}
			else {
				useTradeRouteID = tradeRouteID;   // Team 1 (bottom arc)
			}
		}
		
		// Get socket location from trade route waypoint
		vector socketLoc = rmGetTradeRouteWayPoint(useTradeRouteID, waypointPos);
		
		// Calculate offset toward map center (0.5, 0.5)
		float socketX = xsVectorGetX(socketLoc);
		float socketZ = xsVectorGetZ(socketLoc);
		float centerX = rmXFractionToMeters(0.5);
		float centerZ = rmZFractionToMeters(0.5);
		
		// Direction vector toward center
		float dirX = centerX - socketX;
		float dirZ = centerZ - socketZ;
		
		// Normalize direction
		float distance = sqrt(dirX*dirX + dirZ*dirZ);
		
		// Calculate platform offset distance (35m toward center for land guarantee)
		float platformOffsetDistance = 35.0;
		float platformOffsetX = (dirX / distance) * platformOffsetDistance;
		float platformOffsetZ = (dirZ / distance) * platformOffsetDistance;
		float platformX = socketX + platformOffsetX;
		float platformZ = socketZ + platformOffsetZ;
		
		// Create platform area offset toward center (guarantees land base)
		int socketPlatformID = rmCreateArea("socket platform "+i);
		if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1)) { 
			rmSetAreaSize(socketPlatformID, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
		}
		else{
			rmSetAreaSize(socketPlatformID, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
		}
		rmSetAreaLocation(socketPlatformID, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
		rmSetAreaMix(socketPlatformID, baseMix);
		rmSetAreaCoherence(socketPlatformID, 1.0);
		rmSetAreaSmoothDistance(socketPlatformID, 15);
		rmSetAreaBaseHeight(socketPlatformID, 2.2);
		rmSetAreaWarnFailure(socketPlatformID, false);
		rmBuildArea(socketPlatformID);
		
		// For 4-player games, use harbour groupings (works well with diagonal positions)
		if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1)) { 
			// Determine which harbour grouping to use based on direction from center to socket
			// SWAPPED: dirToSocketZ and dirToSocketX for 90° rotation
			float dirToSocketX = socketX - centerX;
			float dirToSocketZ = socketZ - centerZ;
			int harbourGroupingID = -1;
			float harbourOffsetDistance = 16.0; // Default offset
			
			// Use diagonal groupings for 4-player circular layout
			if ((dirToSocketX > 0) && (dirToSocketZ > 0)) {
				harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_N");
				harbourOffsetDistance = 12.0; // Special offset for North-facing harbour
				rmEchoInfo("Harbour "+i+" using N orientation");
			}
			else if ((dirToSocketX < 0) && (dirToSocketZ > 0)) {
				harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_W");
				harbourOffsetDistance = 14.0; // Special offset for West-facing harbour
				rmEchoInfo("Harbour "+i+" using W orientation");
			}
			else if ((dirToSocketX > 0) && (dirToSocketZ < 0)) {
				harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_E");
				harbourOffsetDistance = 17.0; // Special offset for East-facing harbour
				rmEchoInfo("Harbour "+i+" using E orientation");
			}
			else if ((dirToSocketX < 0) && (dirToSocketZ < 0)) {
				harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_S");
				rmEchoInfo("Harbour "+i+" using S orientation");
			}
			else {
				harbourGroupingID = rmCreateGrouping("harbour "+i, "Harbour_Universal_S");
				rmEchoInfo("Harbour "+i+" using S orientation (fallback)");
			}
			
			// Calculate harbour offset (closer to water for groupings)
			float harbourOffsetX = (dirX / distance) * harbourOffsetDistance;
			float harbourOffsetZ = (dirZ / distance) * harbourOffsetDistance;
			float harbourX = socketX + harbourOffsetX;
			float harbourZ = socketZ + harbourOffsetZ;
			
			// Place harbour grouping closer to water
			rmSetGroupingMinDistance(harbourGroupingID, 0.0);
			rmSetGroupingMaxDistance(harbourGroupingID, 0.0);
			rmPlaceGroupingAtLoc(harbourGroupingID, 0, rmXMetersToFraction(harbourX), rmZMetersToFraction(harbourZ));
			
			rmEchoInfo("Harbour "+i+" placed at waypoint "+waypointPos+" (4-player mode, platform at 35m, harbour at "+harbourOffsetDistance+"m)");
		}
		else {
			// For other player counts, use simple socket at platform location
			int socketID = rmCreateObjectDef("socket "+i);
			rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
			rmAddObjectDefConstraint(socketID, avoidWater4);
			rmSetObjectDefTradeRouteID(socketID, useTradeRouteID);
			rmPlaceObjectDefAtLoc(socketID, 0, rmXMetersToFraction(platformX), rmZMetersToFraction(platformZ));
			
			rmEchoInfo("Socket "+i+" placed at waypoint "+waypointPos+" on platform");
		}
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
	rmAddObjectDefConstraint(TCID, avoidWater8);

	//Prepare to place Explorers, Explorer's dog, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, mineType, 1, 0);
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
      rmAddClosestPointConstraint(flagLand);
      rmAddClosestPointConstraint(flagEdgeConstraint);

      vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
		rmClearClosestPointConstraints();
		
		// Place Habsburg OR SPCJesuit settlement with alternating pattern
		// Pattern 0: even players = Habsburg, odd players = SPCJesuit
		// Pattern 1: odd players = Habsburg, even players = SPCJesuit
		int playerNativeID = -1;
		int playerNativeID2 = -1;
		int playerIsEven = (i % 2 == 0);  // Check if player number is even
		
		// Determine which native to place based on pattern and player parity
		int getsHabsburg = 0;
		if (nativePattern == 0) {
			// Pattern 0: even = Habsburg, odd = SPCJesuit
			getsHabsburg = playerIsEven;
		} else {
			// Pattern 1: odd = Habsburg, even = SPCJesuit
			getsHabsburg = (playerIsEven == 0);
		}
		
		// Declare variant numbers BEFORE using them (scope fix)
		int habsburgVar = rmRandInt(1,3);
		int jesuitVar = rmRandInt(1,3);
		
		if (getsHabsburg == 1) {
			// Habsburg
			playerNativeID = rmCreateGrouping("player "+i+" native", "zpHabsburg_SP_0"+habsburgVar);
			rmEchoInfo("Player "+i+" gets Habsburg settlement (pattern "+nativePattern+")");
		} else {
			// SPCJesuit
			playerNativeID = rmCreateGrouping("player "+i+" native", "Jesuit_Cathedral_EU_Flat_0"+jesuitVar);
			rmEchoInfo("Player "+i+" gets SPCJesuit settlement (pattern "+nativePattern+")");
		}

		if (getsHabsburg == 1){
			playerNativeID2 = rmCreateGrouping("player "+i+" native 2", "Jesuit_Cathedral_EU_Flat_0"+jesuitVar);
		}
		else{
			playerNativeID2 = rmCreateGrouping("player "+i+" native 2", "zpHabsburg_SP_0"+habsburgVar);
		}
		
		rmAddGroupingToClass(playerNativeID, classNatives);
		if (cNumberTeams < 5) {
			if (cNumberNonGaiaPlayers == 2){
				rmSetGroupingMinDistance(playerNativeID, 30);  // Further from TC
				rmSetGroupingMaxDistance(playerNativeID, 90);  // Further from TC
			}
			else{
				rmSetGroupingMinDistance(playerNativeID, 50);  // Further from TC
				rmSetGroupingMaxDistance(playerNativeID, 90);  // Further from TC
			}
		}
		else {
			rmSetGroupingMinDistance(playerNativeID, 30);  // Further from TC
			rmSetGroupingMaxDistance(playerNativeID, 60);  // Further from TC
		}
		rmAddGroupingConstraint(playerNativeID, avoidImpassableLand);
		rmAddGroupingConstraint(playerNativeID, avoidNativesMed);
		if (cNumberNonGaiaPlayers < 2){
			rmAddGroupingConstraint(playerNativeID, avoidWater8);  // Keep away from water
		}
		else{
			rmAddGroupingConstraint(playerNativeID, avoidWater20);  // Keep away from water
		}
		rmAddGroupingConstraint(playerNativeID, avoidTPLong);  // Keep away from trade route sockets
		
		// Create larger flat zone around TC to cover entire possible spawn area
		float flatZoneRadius = 0.0;
		if (cNumberTeams < 5) {
			if (cNumberNonGaiaPlayers == 2){
				flatZoneRadius = rmAreaTilesToFraction(2500.0);  // Covers 30-90m radius
			}
			else{
				flatZoneRadius = rmAreaTilesToFraction(2800.0);  // Covers 50-90m radius
			}
		}
		else {
			flatZoneRadius = rmAreaTilesToFraction(1800.0);  // Covers 30-60m radius
		}
		
		// Now place settlement - it will land on the flattened zone
		rmPlaceGroupingAtLoc(playerNativeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		if (cNumberNonGaiaPlayers == 2){		
			rmAddGroupingConstraint(playerNativeID2, avoidImpassableLand);
			rmAddGroupingConstraint(playerNativeID2, avoidNativesMed);
			rmAddGroupingConstraint(playerNativeID2, avoidWater8);  // Keep away from water
			rmAddGroupingConstraint(playerNativeID2, avoidTPLong);  // Keep away from trade route sockets
			rmSetGroupingMinDistance(playerNativeID2, 30);  // Further from TC
			rmSetGroupingMaxDistance(playerNativeID2, 90);  // Further from TC
			rmPlaceGroupingAtLoc(playerNativeID2, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		}
		
   }

   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

   for (j=0; < (2.5*cNumberNonGaiaPlayers-cNumberTeams)) {   
         int ffaCliffs = rmCreateArea("ffaCliffs"+j);
         rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(50), rmAreaTilesToFraction(100));
         rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
         rmSetAreaCliffType(ffaCliffs, cliffType);
         rmSetAreaCliffEdge(ffaCliffs, 1, 0.8, 0.0, 0.0, 2); //4,.225 looks cool too
         rmSetAreaCliffPainting(ffaCliffs, true, true, true, 1.5, true);
         rmSetAreaCliffHeight(ffaCliffs, rmRandInt(6,8), 1, 0.5);
         rmSetAreaSmoothDistance(ffaCliffs, 10);
         rmSetAreaHeightBlend(ffaCliffs, 3);
         rmAddAreaToClass(ffaCliffs, rmClassID("classCliff"));
         rmAddAreaConstraint(ffaCliffs, forestConstraint);
         rmAddAreaConstraint(ffaCliffs, avoidAll);
         rmAddAreaConstraint(ffaCliffs, avoidTP);
         rmAddAreaConstraint(ffaCliffs, avoidTCMedium);
         rmAddAreaConstraint(ffaCliffs, avoidSocket);
         rmAddAreaConstraint(ffaCliffs, avoidCliff);
         rmAddAreaConstraint(ffaCliffs, shortAvoidImpassableLand);
         rmSetAreaCoherence(ffaCliffs, .7);

        rmBuildArea(ffaCliffs);  
    }


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
		rmAddAreaConstraint(forest, avoidTP);
		rmAddAreaConstraint(forest, avoidTCMedium);
		rmAddAreaConstraint(forest, avoidSocket);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand);
		if(rmBuildArea(forest)==false) {
			// Stop trying once we fail 5 times in a row.
			failCount++;
			
			if(failCount==5)
				break;
		}
		
		else
			failCount=0;
	}
	

    
   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered silver on team islands
   int silverID = rmCreateObjectDef("random silver");
   rmAddObjectDefItem(silverID, mineType, 1, 0);
   rmSetObjectDefMinDistance(silverID, 0.0);
   rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(silverID, avoidAll);
   rmAddObjectDefConstraint(silverID, avoidWater8);
   rmAddObjectDefConstraint(silverID, avoidCoin);
   rmAddObjectDefConstraint(silverID, avoidTCLong);
   rmAddObjectDefConstraint(silverID, avoidTP);
   rmAddObjectDefConstraint(silverID, avoidImportantItem);
   rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);
	// Place mines - use player islands for 3 players, team islands otherwise
	if (cNumberNonGaiaPlayers == 3) {
		for (i=1; <cNumberPlayers) {
			rmPlaceObjectDefInArea(silverID, 0, rmAreaID("player island "+i), 3);
		}
	}
	else {
		for (i=0; <cNumberTeams) {
			rmPlaceObjectDefInArea(silverID, 0, rmAreaID("team "+i), 3*rmGetNumberPlayersOnTeam(i));
		}
	}
	
	// Mines on center island
	int goldID = rmCreateObjectDef("random gold");
   rmAddObjectDefItem(goldID, mineType, 1, 0);
   rmSetObjectDefMinDistance(goldID, 0.0);
   rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(goldID, avoidAll);
   rmAddObjectDefConstraint(goldID, avoidWater8);
   rmAddObjectDefConstraint(goldID, avoidCoin);
   rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(goldID, avoidImportantItem);
   rmAddObjectDefConstraint(goldID, avoidNatives);
   rmAddObjectDefConstraint(goldID, avoidTP);
   rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers);
   
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
   rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers/2);

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
   rmPlaceObjectDefInArea(foodID1, 0, bigIslandID, cNumberNonGaiaPlayers+1);  
  
   // Huntables scattered on team islands
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
	// Place hunts - use player islands for 3 players, team islands otherwise
	if (cNumberNonGaiaPlayers == 3) {
		for (i=1; <cNumberPlayers) {
			rmPlaceObjectDefInArea(foodID2, 0, rmAreaID("player island "+i), 4);
		}
	}
	else {
		for (i=0; <cNumberTeams) {
			rmPlaceObjectDefInArea(foodID2, 0, rmAreaID("team "+i), 4*rmGetNumberPlayersOnTeam(i));
		}
	}

	// Define and place Nuggets
    
	// Easier nuggets on team islands
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
	// Place nuggets - use player islands for 3 players, team islands otherwise
	if (cNumberNonGaiaPlayers == 3) {
		for (i=1; <cNumberPlayers) {
			rmPlaceObjectDefInArea(nugget1, 0, rmAreaID("player island "+i), 2);
		}
	}
	else {
		for (i=0; <cNumberTeams) {
			rmPlaceObjectDefInArea(nugget1, 0, rmAreaID("team "+i), 2*rmGetNumberPlayersOnTeam(i));
		}
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
  
  // hard nuggets on center island
   int nugget3= rmCreateObjectDef("nugget hardest"); 
   rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
   rmSetNuggetDifficulty(4, 4);
   rmSetObjectDefMinDistance(nugget3, 0.0);
   rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(nugget3, avoidHardNugget);
   rmAddObjectDefConstraint(nugget3, mesaConstraint);
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
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 40+30*cNumberNonGaiaPlayers);

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
	}

   // ******************* Triggers ***********************

	// Variables
   int flag1 = rmGetUnitPlaced(piratewaterflagID1, 0);
	int flag2 = rmGetUnitPlaced(piratewaterflagID2, 0);

   string pirate1Socket = ""+(flag1-1);
	string pirate2Socket = ""+(flag2-1);

   int rogueTreasureID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpNuggetInvisible");
   int rogueCathedralID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCGermanCathedral");
   int rogueBankID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCNationalBank");

   // Triger definition

   // Conversion Suspend
   rmCreateTrigger("RogueState Convert OFF");
   rmAddTriggerEffect("Unit Action Suspend");
   rmSetTriggerEffectParam("SrcObject",""+rogueCathedralID);
   rmSetTriggerEffectParam("ActionName", "AutoConvert");
   rmSetTriggerEffectParam("Suspend", "True");
   rmAddTriggerEffect("Unit Action Suspend");
   rmSetTriggerEffectParam("SrcObject",""+rogueBankID );
   rmSetTriggerEffectParam("ActionName", "AutoConvert");
   rmSetTriggerEffectParam("Suspend", "True");
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmCreateTrigger("RogueState Convert ON");
   rmAddTriggerCondition("Nugget Is Collectable");
   rmSetTriggerConditionParam("NuggetObject", ""+rogueTreasureID);
   rmAddTriggerEffect("Unit Action Suspend");
   rmSetTriggerEffectParam("SrcObject",""+rogueCathedralID);
   rmSetTriggerEffectParam("ActionName", "AutoConvert");
   rmSetTriggerEffectParam("Suspend", "False");
   rmAddTriggerEffect("Unit Action Suspend");
   rmSetTriggerEffectParam("SrcObject",""+rogueBankID );
   rmSetTriggerEffectParam("ActionName", "AutoConvert");
   rmSetTriggerEffectParam("Suspend", "False");
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Activate European Embassy for all players
		rmSetTriggerEffectParamInt("Status",2);	
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpSpanishHabsburgs"); // Activate Spanish Habsburgs for all players
		rmSetTriggerEffectParamInt("Status",2);
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",i);
      rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueItalian"); // Activate Unknown Rogue Italian for all players
      rmSetTriggerEffectParamInt("Status",2);
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",i);
      rmSetTriggerEffectParam("TechID","cTechzpSPCRogueBalearic"); // Activate Rogue Balearic for all players
      rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ******************* Politicians *******************

	// Italian Vilager Balance

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Italian Vilager Balance"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","DEItalians");
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance"); // Italian Settler Balance
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
	rmSetTriggerConditionParam("TechID","cTechDEHCGondolas"); // Gondolas tech
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpItalianGondolaBallance"); // Italian Gondola Balance
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
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease"); // Reset research speed
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
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnJapanese"); // Turn on Japanese consulate
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
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
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnChinese"); // Turn on Chinese consulate
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
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
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); // Consulate tech available
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnIndian"); // Turn on Indian consulate
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
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
	rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); // Pirates consulate tech
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesMedi"); // Turn on Mediterranean Pirate consulate
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); // Decrease research speed
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
	rmSetTriggerEffectParam("TechID","cTechzpIsPirateMap"); // Mark as pirate map
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

	// AI Pirate Captains

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Pirate Captain"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586); // Age 1 tech
	rmSetTriggerConditionParamInt("Status",2);

	int pirateCaptain=-1;
	pirateCaptain = rmRandInt(1,3);

	if (pirateCaptain==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard"); // Blackbeard (Mediterranean)
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackCaesar"); // Black Caesar (Mediterranean)
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBarbarossa"); // Barbarossa (Mediterranean)
		rmSetTriggerEffectParamInt("Status",2);
	}
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

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket); // Pirate settlement 1
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); // Enable Privateer training at settlement 1
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
	rmSetTriggerConditionParamFloat("Param1",1200);
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
	rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); // Reduce build limit
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); // Disable Privateer training at settlement 1
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Privateer 2 training (only if more than 3 players, since second settlement only spawns then)
	
	if (cNumberNonGaiaPlayers > 3) {
		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("TrainPrivateer2ON Plr"+k);
		rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
		rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

		rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket); // Pirate settlement 2
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); // Enable Privateer training at settlement 2
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); // Reduce build limit
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); // Disable Privateer training at settlement 2
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}
	}

	// Unique ship Training (Mediterranean)

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain1ONPlr"+k);
	rmCreateTrigger("BlackbTrain1OFFPlr"+k);

	rmCreateTrigger("BarbarossaTrain1ONPlr"+k);
	rmCreateTrigger("BarbarossaTrain1OFFPlr"+k);

	rmCreateTrigger("BlackCaesarTrain1ONPlr"+k);
	rmCreateTrigger("BlackCaesarTrain1OFFPlr"+k);

	if (cNumberNonGaiaPlayers > 3) {
		rmCreateTrigger("UniqueShip2TIMEPlr"+k);

		rmCreateTrigger("BlackbTrain2ONPlr"+k);
		rmCreateTrigger("BlackbTrain2OFFPlr"+k);

		rmCreateTrigger("BarbarossaTrain2ONPlr"+k);
		rmCreateTrigger("BarbarossaTrain2OFFPlr"+k);

		rmCreateTrigger("BlackCaesarTrain2ONPlr"+k);
		rmCreateTrigger("BlackCaesarTrain2OFFPlr"+k);
		
		rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); // Reduce build limit for unique ships
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne2"); // Train Queen Anne at settlement 2
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

		rmSwitchToTrigger(rmTriggerID("BarbarossaTrain2ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCPirateGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainSultana2"); // Train Sultana (Barbarossa) at settlement 2
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain2OFFPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BarbarossaTrain2OFFPlr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain2ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain2ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune2"); // Train Neptune (Black Caesar) at settlement 2
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain2OFFPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain2OFFPlr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain2ONPlr"+k));
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
	rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); // Reduce build limit for unique ships
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Blackbeard (Queen Anne)
	rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne1"); // Train Queen Anne at settlement 1
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

	// Barbarossa (Sultana)
	rmSwitchToTrigger(rmTriggerID("BarbarossaTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCPirateGalleassProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainSultana1"); // Train Sultana (Barbarossa) at settlement 1
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BarbarossaTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Black Caesar (Neptune)
	rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune1"); // Train Neptune (Black Caesar) at settlement 1
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackCaesarTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
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
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1Socket);
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1Socket);
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers > 3) {
		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Pirates2on Player"+k);
		rmCreateTrigger("Pirates2off Player"+k);

		rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate2Socket);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
		rmSetTriggerEffectParamInt("Dist",150);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain2ONPlr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain2ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2Socket);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate2Socket);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
		rmSetTriggerEffectParamInt("Dist",150);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BarbarossaTrain2ONPlr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackCaesarTrain2ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}
	}


    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);
}