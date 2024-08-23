// Australia
// June 2024

// Main entry point for random map script    

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	string baseTerrainMix = "painteddesert_groundmix_4";
	string lightingSet = "PaintedDesert_Skirmish";
	string seaType = "ZP Pacific Coast";
	string islandTerrainMix = "california_snowground";
	string mainMountainCliffType = "ZP Uluru";
	string forestType = "z86 Australian Bush";

	bool weird = false;
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	// FFA and imbalanced teams
  	if ( cNumberTeams > 2 || ((teamZeroCount - teamOneCount) > 2) || ((teamOneCount - teamZeroCount) > 2) )
    weird = true;
  
  rmEchoInfo("weird = "+weird);

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int nativeVariant = rmRandInt(1,2);


	subCiv0=rmGetCivID("AboriginalNatives");
	rmEchoInfo("subCiv0 is AboriginalNatives "+subCiv0);
	if (subCiv0 >= 0)
	rmSetSubCiv(0, "AboriginalNatives");



	if (nativeVariant == 1)
	{
		subCiv1=rmGetCivID("natpirates");
		rmEchoInfo("subCiv1 is natpirates "+subCiv0);
		if (subCiv1 >= 0)
				rmSetSubCiv(1, "natpirates");

	}

	if (nativeVariant == 2)
	{
		subCiv1=rmGetCivID("zpScientists");
		rmEchoInfo("subCiv1 is zpScientists "+subCiv0);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zpScientists");
	}

	subCiv2=rmGetCivID("PenalColony");
	rmEchoInfo("subCiv2 is PenalColony "+subCiv0);
	if (subCiv2 >= 0)
	rmSetSubCiv(2, "PenalColony");


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1 - Four Caribs, next to the big mountain and at the ends of the 2 long peninsulas. 
	// 2 - Four Caribs, at the ends of the 2 long peninsulas, and 2 on SE end of island.
    // 3 - Six Caribs, next to the mountain, 2 on the long peninsula, and 2 on SE end of island. 
	// Note from Riki: Variation 3 has been removed for DE

	int whichVariation=-1;
	
    if(rmGetIsKOTH()){
        whichVariation = 2;
    }else{
        whichVariation = rmRandInt(1,2);
    }

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();

	if ( cNumberNonGaiaPlayers > 7 )	//If 8 player game, use only variation #2 so map builds more quickly.
	{
		whichVariation = 2;
	}
	
	// Set size of map
	int playerTiles = 22000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 19000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 16000;		

	int size=3.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseTerrainMix);
	rmSetMapType("australia");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet(lightingSet);

	// Initialize map.
	rmTerrainInitialize("water");

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	int classNatives = rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);

	// Bonus area constraint.  
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 55.0);

	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishTuna", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 30.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "MinkeWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int SaltVsSaltID=rmCreateTypeDistanceConstraint("salt v salt", "zpSaltMineWater", 20.0);	//Was 8.0
	int avoidCoin=-1;
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random emu", "zpEmu", 40.0);	//Attempting to spread them out more evenly.
	int avoidKangaroos=rmCreateTypeDistanceConstraint("avoid random kangaroo", "zpRedKangaroo", 40.0);	//Attempting to spread them out more evenly.
	int avoidCassowary=rmCreateTypeDistanceConstraint("avoid random cassowary", "zpCassowary", 70.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 28.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 3.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", classNatives , 10.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("avoid natives far", classNatives , 18.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);


	// Lake Constraints
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 5.5);
	int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 20.0);
	int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route island", 10.0);
	int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 12.0);
	int avoidTradeSocket = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 12.0);
	int avoidTradeSocketFar = rmCreateTypeDistanceConstraint("avoid trade sockets far", "sockettraderoute", 35.0);
	int avoidScientists=rmCreateTypeDistanceConstraint("stay away from Scientists", "zpSocketScientists", 35.0);
	int avoidPirates=rmCreateTypeDistanceConstraint("stay away from Pirates", "zpSocketPirates", 35.0);
	int avoidWokou=rmCreateTypeDistanceConstraint("stay away from Wokou", "zpSocketPenalColony", 35.0);



	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  (It excludes the west bay, where I do not want the flags.)
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(50), rmDegreesToRadians(290));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

   	int IslandLoc = 1;

   	// Trade Routes
	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(tradeRouteID);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.15, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.2);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.0);

	bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");		

	int tradeRoute2ID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(tradeRoute2ID);

	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.2, 0.9);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.5, 0.89);
	rmAddTradeRouteWaypoint(tradeRoute2ID, 0.8, 0.9);

	bool placedTradeRoute2 = rmBuildTradeRoute(tradeRoute2ID, "water_trail");	

	int tradeRoute3ID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(tradeRoute3ID);

	rmAddTradeRouteWaypoint(tradeRoute3ID, 0.95, 0.8);
	rmAddTradeRouteWaypoint(tradeRoute3ID, 0.91, 0.1);

	bool placedTradeRoute3 = rmBuildTradeRoute(tradeRoute3ID, "water_trail");							

	// Make one big island.  
	int bigIslandID=rmCreateArea("big lone island");
	rmSetAreaSize(bigIslandID, 0.25, 0.25);
	rmSetAreaCoherence(bigIslandID, 0.95);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 50);
	rmSetAreaMix(bigIslandID, islandTerrainMix);
	rmAddAreaTerrainLayer(bigIslandID, "Africa\pathBlend_afr", 0, 6);
	rmAddAreaConstraint(bigIslandID, islandAvoidTradeRoute);

	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);

	rmAddAreaInfluenceSegment(bigIslandID, 0.15, 0.6, 0.18, 0.56);
	rmAddAreaInfluenceSegment(bigIslandID, 0.23, 0.55, 0.27, 0.52);
	rmAddAreaInfluenceSegment(bigIslandID, 0.32, 0.53, 0.36, 0.51);
	rmAddAreaInfluenceSegment(bigIslandID, 0.44, 0.44, 0.43, 0.38);
	rmAddAreaInfluenceSegment(bigIslandID, 0.49, 0.49, 0.44, 0.34);
	rmAddAreaInfluenceSegment(bigIslandID, 0.46, 0.33, 0.44, 0.27);
	rmAddAreaInfluenceSegment(bigIslandID, 0.47, 0.23, 0.49, 0.22);
	rmAddAreaInfluenceSegment(bigIslandID, 0.49, 0.19, 0.54, 0.18);
	rmAddAreaInfluenceSegment(bigIslandID, 0.56, 0.16, 0.64, 0.20);
	rmAddAreaInfluenceSegment(bigIslandID, 0.68, 0.21, 0.74, 0.24);
	rmAddAreaInfluenceSegment(bigIslandID, 0.78, 0.30, 0.80, 0.43);
	rmAddAreaInfluenceSegment(bigIslandID, 0.79, 0.48, 0.81, 0.50);
	rmAddAreaInfluenceSegment(bigIslandID, 0.84, 0.56, 0.83, 0.58);
	rmAddAreaInfluenceSegment(bigIslandID, 0.87, 0.64, 0.86, 0.66);
	rmAddAreaInfluenceSegment(bigIslandID, 0.74, 0.68, 0.72, 0.69);
	rmAddAreaInfluenceSegment(bigIslandID, 0.69, 0.68, 0.75, 0.71);
	rmAddAreaInfluenceSegment(bigIslandID, 0.69, 0.79, 0.68, 0.77);
	rmAddAreaInfluenceSegment(bigIslandID, 0.65, 0.79, 0.60, 0.77);
	rmAddAreaInfluenceSegment(bigIslandID, 0.58, 0.78, 0.58, 0.81);
	rmAddAreaInfluenceSegment(bigIslandID, 0.52, 0.82, 0.52, 0.80);
	rmAddAreaInfluenceSegment(bigIslandID, 0.48, 0.80, 0.48, 0.82);
	rmAddAreaInfluenceSegment(bigIslandID, 0.44, 0.79, 0.40, 0.79);
	rmAddAreaInfluenceSegment(bigIslandID, 0.30, 0.82, 0.24, 0.77);
	rmAddAreaInfluenceSegment(bigIslandID, 0.23, 0.74, 0.21, 0.74);
	rmAddAreaInfluenceSegment(bigIslandID, 0.18, 0.63, 0.15, 0.60);

	rmSetAreaWarnFailure(bigIslandID, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIslandID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID);


	// Make a terrain on a top of the island (for a case that previous island doesn't spawn correctly) 
	int bigIslandID2=rmCreateArea("big lone island sure");
	rmSetAreaSize(bigIslandID2, 0.25, 0.25);
	rmSetAreaCoherence(bigIslandID2, 0.95);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID2, 2.0);
	rmSetAreaSmoothDistance(bigIslandID2, 50);
	rmSetAreaMix(bigIslandID2, islandTerrainMix);
	rmAddAreaConstraint(bigIslandID2, islandAvoidTradeRoute);

	rmAddAreaToClass(bigIslandID2, classIsland);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID2, false);
	rmSetAreaElevationType(bigIslandID2, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID2, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID2, 0.09);
	rmSetAreaElevationOctaves(bigIslandID2, 3);
	rmSetAreaElevationPersistence(bigIslandID2, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID2, 1);

	rmAddAreaInfluenceSegment(bigIslandID2, 0.3, 0.6, 0.4, 0.7);
	rmAddAreaInfluenceSegment(bigIslandID2, 0.6, 0.6, 0.4, 0.7);
	rmAddAreaInfluenceSegment(bigIslandID2, 0.6, 0.6, 0.7, 0.4);
	rmAddAreaInfluenceSegment(bigIslandID2, 0.6, 0.3, 0.7, 0.4);
	rmAddAreaInfluenceSegment(bigIslandID2, 0.5, 0.5, 0.75, 0.5);
	rmAddAreaInfluenceSegment(bigIslandID2, 0.7, 0.4, 0.4, 0.7);

	 		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID2, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIslandID2, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID2);

	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.
	//float teamStartLoc = rmRandFloat(0.2, 0.4);    //Temporarily force float to be .4 or lower, so Team 0 will be in the North.
	
	// NATIVES
  
  	// Place Controllers
	int controllerID1 = rmCreateObjectDef("Controler 1");
	rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID1, 0.0);
	rmSetObjectDefMaxDistance(controllerID1, 0.0);
	rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);


	int controllerID2 = rmCreateObjectDef("Controler 2");
	rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID2, 0.0);
	rmSetObjectDefMaxDistance(controllerID2, 0.0);
	rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
	//rmAddObjectDefConstraint(controllerID2, ferryOnShore); 

	rmPlaceObjectDefAtLoc(controllerID1, 0, 0.7, 0.8);
	rmPlaceObjectDefAtLoc(controllerID2, 0, 0.4, 0.4);

	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
	vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));


	// Pirate Village 1

	int piratesVillageID = -1;
	int piratesVillageType = rmRandInt(1,2);
	if (nativeVariant == 1)
		piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");
	else
		piratesVillageID = rmCreateGrouping("pirate city", "Scientist_Lab05");
	rmSetGroupingMinDistance(piratesVillageID, 0);
	rmSetGroupingMaxDistance(piratesVillageID, 30);
	rmAddGroupingConstraint(piratesVillageID, ferryOnShore);

  
	rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);
	int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
	if (nativeVariant == 1)
		rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
	else
		rmAddObjectDefItem(piratewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, 0.7+rmXTilesToFraction(18), 0.8+rmXTilesToFraction(14));

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
	if (nativeVariant == 1)
		piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06");
	else
		piratesVillageID2 = rmCreateGrouping("pirate city 2", "Scientist_Lab06");
	rmSetGroupingMinDistance(piratesVillageID2, 0);
	rmSetGroupingMaxDistance(piratesVillageID2, 30);
	rmAddGroupingConstraint(piratesVillageID2, ferryOnShore);

	rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

	int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
	if (nativeVariant == 1)
		rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
	else
		rmAddObjectDefItem(piratewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
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


	// Trade Sockets

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 0.0);

	int socket2ID=rmCreateObjectDef("sockets to dock Trade Posts 2");
	rmSetObjectDefTradeRouteID(socket2ID, tradeRoute2ID);
	rmAddObjectDefItem(socket2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(socket2ID, true);
	rmSetObjectDefMinDistance(socket2ID, 0.0);
	rmSetObjectDefMaxDistance(socket2ID, 0.0);

	int socket3ID=rmCreateObjectDef("sockets to dock Trade Posts 3");
	rmSetObjectDefTradeRouteID(socket3ID, tradeRoute3ID);
	rmAddObjectDefItem(socket3ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(socket3ID, 0.0);
	rmSetObjectDefMaxDistance(socket3ID, 0.0);

	int portSite1 = rmCreateArea ("port_site1");
	rmSetAreaSize(portSite1, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaMix(portSite1, "california_snowground2");
	rmSetAreaCoherence(portSite1, 1);
	rmSetAreaSmoothDistance(portSite1, 15);
	rmSetAreaBaseHeight(portSite1, 2.2);

	int portSite2 = rmCreateArea ("port_site2");
	rmSetAreaSize(portSite2, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaMix(portSite2, "california_snowground2");
	rmSetAreaCoherence(portSite2, 1);
	rmSetAreaSmoothDistance(portSite2, 15);
	rmSetAreaBaseHeight(portSite2, 2.2);

	int portSite3 = rmCreateArea ("port_site3");
	rmSetAreaSize(portSite3, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaMix(portSite3, "california_snowground2");
	rmSetAreaCoherence(portSite3, 1);
	rmSetAreaSmoothDistance(portSite3, 15);
	rmSetAreaBaseHeight(portSite3, 2.2);
	
	int portSite4 = rmCreateArea ("port_site4");
	rmSetAreaSize(portSite4, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaMix(portSite4, "california_snowground2");
	rmSetAreaCoherence(portSite4, 1);
	rmSetAreaSmoothDistance(portSite4, 15);
	rmSetAreaBaseHeight(portSite4, 2.2);

	int stationGrouping01 = -1;
	stationGrouping01 = rmCreateGrouping("station grouping 01", "Harbour_Universal_NE");
	rmSetGroupingMinDistance(stationGrouping01, 0.0);
	rmSetGroupingMaxDistance (stationGrouping01, 0.0);

	int stationGrouping02 = -1;
	stationGrouping02 = rmCreateGrouping("station grouping 02", "Harbour_Universal_NW");
	rmSetGroupingMinDistance(stationGrouping02, 0.0);
	rmSetGroupingMaxDistance (stationGrouping02, 0.0);

	int stationGrouping03 = -1;
	stationGrouping03 = rmCreateGrouping("station grouping 03", "Harbour_Universal_S");
	rmSetGroupingMinDistance(stationGrouping03, 0.0);
	rmSetGroupingMaxDistance (stationGrouping03, 0.0);
	
	vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	vector socketLoc2  = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.5);
	vector socketLoc3  = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.5);

	socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.14);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	rmSetAreaLocation(portSite3, rmXMetersToFraction(xsVectorGetX(socketLoc)+27), rmZMetersToFraction(xsVectorGetZ(socketLoc)+27));
	rmBuildArea(portSite3);
	rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)+16), rmZMetersToFraction(xsVectorGetZ(socketLoc)+16));

	socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.79);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	rmSetAreaLocation(portSite4, rmXMetersToFraction(xsVectorGetX(socketLoc)+27), rmZMetersToFraction(xsVectorGetZ(socketLoc)+27));
	rmBuildArea(portSite4);
	rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)+16), rmZMetersToFraction(xsVectorGetZ(socketLoc)+16));

	socketLoc2  = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.50);
	rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);
	rmSetAreaLocation(portSite2, rmXMetersToFraction(xsVectorGetX(socketLoc2)), rmZMetersToFraction(xsVectorGetZ(socketLoc2)-38));
	rmBuildArea(portSite2);
	rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc2)), rmZMetersToFraction(xsVectorGetZ(socketLoc2)-20));

	socketLoc3  = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.22);
	rmPlaceObjectDefAtPoint(socket3ID, 0, socketLoc3);
	rmSetAreaLocation(portSite1, rmXMetersToFraction(xsVectorGetX(socketLoc3)-38), rmZMetersToFraction(xsVectorGetZ(socketLoc3)));
	rmBuildArea(portSite1);
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc3)-20), rmZMetersToFraction(xsVectorGetZ(socketLoc3)));

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
	
	// Players
    
	float teamSide = rmRandFloat(0, 1);
	// teamSide = 0;
	
	if (weird == false) {
		
		if(teamSide > .5) {
			if(cNumberNonGaiaPlayers > 7) { 
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		
			else if(cNumberNonGaiaPlayers > 5) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}

		
			else if(cNumberNonGaiaPlayers > 2) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		
			else {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		}
		
		else {
			if(cNumberNonGaiaPlayers > 7) { 
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		
			else if(cNumberNonGaiaPlayers > 5) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		
			else if(cNumberNonGaiaPlayers > 2) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		
			else {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.22, 0.5);
				rmPlacePlayersCircular(0.35, 0.35);

				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.77, 0.0);
				rmPlacePlayersCircular(0.35, 0.35);
			}
		}
	}
	
	// ffa
	else {
		rmSetTeamSpacingModifier(0.5);
		rmSetPlacementSection(0.75, 0.5);
		rmPlacePlayersCircular(.3, .3, 0.05);
	}
			

	float playerFraction=rmAreaTilesToFraction(100);
	for(i=1; <cNumberPlayers)
	{
	// Create the Player's area.
	int id=rmCreateArea("Player"+i);
	rmSetPlayerArea(i, id);
	rmSetAreaSize(id, playerFraction, playerFraction);
	rmAddAreaToClass(id, classPlayer);
	rmSetAreaMinBlobs(id, 1);
	rmSetAreaMaxBlobs(id, 1);
	rmSetAreaLocPlayer(id, i);
	rmSetAreaWarnFailure(id, false);
	}

	// Build the areas. 
	rmBuildAllAreas();

	int eastMountainTerrain=rmCreateArea("balkan mountains terrain"); 
    rmSetAreaSize(eastMountainTerrain, 0.033, 0.033);
    rmSetAreaLocation(eastMountainTerrain, 0.5, 0.2);
    rmSetAreaCoherence(eastMountainTerrain, 0.3);
    rmSetAreaMix(eastMountainTerrain, "Deccan_Grass_A");
    rmAddAreaTerrainLayer(eastMountainTerrain, "Africa\groundStraw_afr", 0, 6);
    rmSetAreaObeyWorldCircleConstraint(eastMountainTerrain, false);
    rmAddAreaConstraint(eastMountainTerrain, avoidWater2);
    rmBuildArea(eastMountainTerrain);

	int westMountainTerrain=rmCreateArea("italy mountains terrain"); 
    rmSetAreaSize(westMountainTerrain, 0.017, 0.017);
    rmSetAreaLocation(westMountainTerrain, 0.2, 0.6);
    rmSetAreaCoherence(westMountainTerrain, 0.3);
    rmSetAreaMix(westMountainTerrain, "Deccan_Grass_A");
    rmAddAreaTerrainLayer(westMountainTerrain, "Africa\groundStraw_afr", 0, 6);
    rmSetAreaObeyWorldCircleConstraint(westMountainTerrain, false);
    rmAddAreaConstraint(westMountainTerrain, avoidWater2);

    rmBuildArea(westMountainTerrain);

	

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);

	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************

	// Penal Colonies

	int jewish1VillageTypeID = rmRandInt(1, 3);
	int jewish2VillageTypeID = rmRandInt(1, 3);

	int jewish1ID = rmCreateGrouping("jewish 1", "Penal_Colony_0"+jewish1VillageTypeID);
	int jewish2ID = rmCreateGrouping("jewish 2", "Penal_Colony_0"+jewish2VillageTypeID);

	//rmSetGroupingMinDistance(jewish1ID, 0);
	//rmSetGroupingMaxDistance(jewish1ID, 50);
	//rmSetGroupingMinDistance(jewish2ID, 0);
	//rmSetGroupingMaxDistance(jewish2ID, 50);

	//rmAddGroupingConstraint(jewish1ID, avoidImpassableLand);
	//rmAddGroupingConstraint(jewish1ID, circleConstraint);
	//rmAddGroupingConstraint(jewish1ID, avoidWater20);
	//rmAddGroupingConstraint(jewish2ID, avoidImpassableLand);
	//rmAddGroupingConstraint(jewish2ID, circleConstraint);
	//rmAddGroupingConstraint(jewish2ID, avoidWater20);


	rmPlaceGroupingAtLoc(jewish1ID, 0, 0.78, 0.32, 1);
	rmPlaceGroupingAtLoc(jewish2ID, 0, 0.3, 0.8, 1);
  
	// Aboriginal Villages
		
	int caribsVillageID = -1;
	int caribsVillageType = rmRandInt(1,5);
	caribsVillageID = rmCreateGrouping("caribs city", "Native_Aboriginal_0"+caribsVillageType);
	rmAddGroupingToClass(caribsVillageID, classNatives);
	rmSetGroupingMinDistance(caribsVillageID, 0.0);
	rmSetGroupingMaxDistance(caribsVillageID, 7.0);
	rmAddGroupingConstraint(caribsVillageID, avoidImpassableLand);
	rmPlaceGroupingAtLoc(caribsVillageID, 0, 0.65, 0.65);	// JSB - end of north long peninsula.

	int caribs2VillageID = -1;
	int caribs2VillageType = rmRandInt(1,5);
	caribs2VillageID = rmCreateGrouping("caribs2 city", "Native_Aboriginal_0"+caribs2VillageType);
	rmAddGroupingToClass(caribs2VillageID, classNatives);			
	rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
	rmSetGroupingMinDistance(caribs2VillageID, 0.0);
	rmSetGroupingMaxDistance(caribs2VillageID, 7.0);
	rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.35, 0.65);  // JSB - end of south long peninsula.

	int caribs4VillageID = -1;
	int caribs4VillageType = rmRandInt(1,5);
	caribs4VillageID = rmCreateGrouping("caribs4 city", "Native_Aboriginal_0"+caribs4VillageType);
	rmAddGroupingToClass(caribs4VillageID, classNatives);			
	rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
	rmSetGroupingMinDistance(caribs4VillageID, 0.0);
	rmSetGroupingMaxDistance(caribs4VillageID, 7.0);
	rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.7, 0.4);  // JSB - SE Village in SE-center, next to mtn.

	if (cNumberNonGaiaPlayers >= 4)
	{  
		int caribs5VillageID = -1;
		int caribs5VillageType = rmRandInt(1,5);
		caribs5VillageID = rmCreateGrouping("caribs5 city", "Native_Aboriginal_0"+caribs5VillageType);
		rmAddGroupingToClass(caribs5VillageID, classNatives);						
		rmSetGroupingMinDistance(caribs5VillageID, 0.0);
		rmSetGroupingMaxDistance(caribs5VillageID, 7.0);
		rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
		rmPlaceGroupingAtLoc(caribs5VillageID, 0, 0.5, 0.25);	// Place near NE end of island.  //.73, .25
	}	

   // *****************MOUNTAIN IN CENTER**************************************
   // Always create a mountain in center of island.
   // Really big mountain for 8 players, big mountain for 6 or 7 players, and small mountain for 5 or less players.

	int smallCliffHeight=rmRandInt(0,10);
	int smallMesaID=rmCreateArea("small mesa"+i);
	if ( cNumberNonGaiaPlayers < 6 )
	{
		rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(600));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
	else if ( cNumberNonGaiaPlayers < 8 )
	{
		rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(800));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
	else
	{
		rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(1200));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
	rmSetAreaWarnFailure(smallMesaID, false);
	rmSetAreaCliffType(smallMesaID, mainMountainCliffType);
	rmSetAreaCliffPainting(smallMesaID, true, true, true, 1, false);
	rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
	rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(smallMesaID, rmRandInt(6, 8), 1.0, 1.0);  //was rmRandInt(6, 8)
	rmSetAreaCoherence(smallMesaID, 0.6);
	rmSetAreaLocation(smallMesaID, 0.5, 0.65); 
	rmAddAreaConstraint(smallMesaID, avoidNativesFar); 
	rmSetAreaReveal(smallMesaID, 01); 
	rmAddAreaInfluenceSegment(smallMesaID, 0.48, 0.43, 0.5, 0.40);  //Bottom - Original segment
	rmAddAreaInfluenceSegment(smallMesaID, 0.46, 0.40, 0.53, 0.38); //Right
	rmAddAreaInfluenceSegment(smallMesaID, 0.53, 0.45, 0.53, 0.38); //Top - Original segment
	rmAddAreaInfluenceSegment(smallMesaID, 0.53, 0.45, 0.48, 0.43); //Left
	rmBuildArea(smallMesaID);

    int messaTerrain=rmCreateArea("mountains terrain"); 
    if ( cNumberNonGaiaPlayers < 6 )
    {
		rmSetAreaSize(messaTerrain, rmAreaTilesToFraction(1000));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
	else if ( cNumberNonGaiaPlayers < 8 )
	{
		rmSetAreaSize(messaTerrain, rmAreaTilesToFraction(1400));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
	else
	{
		rmSetAreaSize(messaTerrain, rmAreaTilesToFraction(1800));  //First # is minimum square meters of material it will use to build.  Second # is maximum.  Currently I have them both set to the same because I want a certain size mountain every time.
	}
    rmSetAreaLocation(messaTerrain, 0.5, 0.65);
    rmSetAreaCoherence(messaTerrain, 0.6);
    rmSetAreaMix(messaTerrain, "california_snowground2");
    rmSetAreaObeyWorldCircleConstraint(messaTerrain, false);
    rmBuildArea(messaTerrain);

	// *****************Eyre Red Lake**************************************

	int deadSeaLakeDeepID=rmCreateArea("Lake Eyre");
	rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Australia Red Lake");
	rmSetAreaSize(deadSeaLakeDeepID, 0.007, 0.007);
	rmSetAreaCoherence(deadSeaLakeDeepID, 0.3);
	rmSetAreaLocation(deadSeaLakeDeepID, 0.55, 0.45);
	rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);
	rmBuildArea(deadSeaLakeDeepID);
   


	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
	int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", smallMesaID, 30.0);
		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//***************** PLAYER STARTING STUFF **********************************
	//Place player TCs and starting Gold Mines. 

	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);

	//Prepare to place TCs
	rmSetObjectDefMinDistance(TCID, 5.0);
	rmSetObjectDefMaxDistance(TCID, 40.0);  // Originally 10.0 -- JSB -- Allows TC placement spot to float a bit along the lines I tell them to place. 
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidTradeSocketFar);
	rmAddObjectDefConstraint(TCID, avoidScientists);
	rmAddObjectDefConstraint(TCID, avoidPirates);
	rmAddObjectDefConstraint(TCID, avoidWokou);
	//	rmAddObjectDefConstraint(TCID, avoidTC);
	//	rmAddObjectDefConstraint(TCID, avoidCW);
    	
	//Prepare to place Explorers, Explorer's dog, Explorer's Taun Taun, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 11.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidTradeSocket);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);


	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 14.0);
	rmSetObjectDefMaxDistance(playerGoldID, 15.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeSocket);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting Crates (mostly food)
	int playerCrateID=rmCreateObjectDef("starting crates");
	rmAddObjectDefItem(playerCrateID, "crateOfFood", 2, 4.0);
	rmAddObjectDefItem(playerCrateID, "crateOfWood", 1, 4.0);
	rmAddObjectDefItem(playerCrateID, "crateOfCoin", 1, 4.0);
	rmSetObjectDefMinDistance(playerCrateID, 6);
	rmSetObjectDefMaxDistance(playerCrateID, 10);
	rmAddObjectDefConstraint(playerCrateID, avoidAll);
	rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "zpEmu", rmRandInt(6,7), 3.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 12);
	rmSetObjectDefMaxDistance(playerTurkeyID, 14);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	int playerTurkeyID2=rmCreateObjectDef("player turkeys second hunt");
    rmAddObjectDefItem(playerTurkeyID2, "zpEmu", rmRandInt(8,9), 6.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID2, 42);
	rmSetObjectDefMaxDistance(playerTurkeyID2, 45);	
	rmAddObjectDefConstraint(playerTurkeyID2, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID2, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID2, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "treeMadrone", 3, 3.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);    //This was just added to try to keep these trees from stomping on CW's.
	rmAddObjectDefConstraint(StartAreaTreeID, avoidWater8);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16.0);	//changed from 12.0 
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22.0);	//Changed from 19.0

	int waterSpawnPointID = 0;

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=1; <cNumberPlayers)
   	{
	    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceObjectDefAtLoc(playerTurkeyID2, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										

		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

 	if(ypIsAsian(i) && rmGetNomadStart() == false)	
      	rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
      
		// Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		//rmAddClosestPointConstraint(avoidTradeRoute);
		//rmAddClosestPointConstraint(circleConstraint);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   	}
	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
	int forestTreeID = 0;
	numTries=10*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries)
    {   
		int forest=rmCreateArea("forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest, forestType);
		rmSetAreaForestDensity(forest, 0.6);
		rmSetAreaForestClumpiness(forest, 0.4);
		rmSetAreaForestUnderbrush(forest, 0.0);
		rmSetAreaCoherence(forest, 0.4);
		rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		rmSetAreaTerrainType(forest, "Africa\groundStraw_afr");
		//rmSetAreaMix(forest, "Deccan_Grass_A");
		rmAddAreaConstraint(forest, forestConstraint);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest, smallMesaConstraint); 
		rmAddAreaConstraint(forest, avoidTC);
		rmAddAreaConstraint(forest, avoidCW);
		rmAddAreaConstraint(forest, avoidWater40);
		rmAddAreaConstraint(forest, avoidSocket); 
		rmAddAreaConstraint(forest, avoidTradeSocket); 
		rmAddAreaConstraint(forest, avoidScientists); 
		rmAddAreaConstraint(forest, avoidPirates); 
		rmAddAreaConstraint(forest, avoidWokou); 
		if(rmBuildArea(forest)==false)
		{
		// Stop trying once we fail 3 times in a row.
		failCount++;
		if(failCount==5)
			break;
		}
		else
		failCount=0; 
    } 

	numTries=10*cNumberNonGaiaPlayers;
	failCount=0;
	for (i=0; <numTries)
    {   
		int beachForest=rmCreateArea("coastalforest "+i);
		rmSetAreaWarnFailure(beachForest, false);
		rmSetAreaSize(beachForest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(beachForest, "z89 Australian Coastal Bush");
		rmSetAreaForestDensity(beachForest, 0.6);
		rmSetAreaForestClumpiness(beachForest, 0.4);
		rmSetAreaForestUnderbrush(beachForest, 0.0);
		//rmSetAreaMix(beachForest, "Deccan_Grass_A");
		rmSetAreaCoherence(beachForest, 0.4);
		rmSetAreaSmoothDistance(beachForest, 10);
		rmAddAreaToClass(beachForest, rmClassID("classForest")); 
		rmAddAreaConstraint(beachForest, forestConstraint);
		rmAddAreaConstraint(beachForest, avoidAll);
		rmAddAreaConstraint(beachForest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(beachForest, smallMesaConstraint); 
		rmAddAreaConstraint(beachForest, avoidTC);
		rmAddAreaConstraint(beachForest, avoidCW);
		rmAddAreaConstraint(forest, avoidWater8);
		rmAddAreaConstraint(beachForest, avoidSocket); 
		rmAddAreaConstraint(beachForest, avoidTradeSocket); 
		rmAddAreaConstraint(beachForest, avoidScientists); 
		rmAddAreaConstraint(beachForest, avoidPirates); 
		rmAddAreaConstraint(beachForest, avoidWokou);
		if(rmBuildArea(beachForest)==false)
		{
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

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaConstraint);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);

	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, smallMesaConstraint);
	rmPlaceObjectDefInArea(berriesID, 0, eastMountainTerrain, cNumberNonGaiaPlayers*2);   //was *4

	int saltFloeID=rmCreateObjectDef("water mine salt");
	rmAddObjectDefItem(saltFloeID, "zpSaltMineWater", 1, 0.0); 
	rmSetObjectDefMinDistance(saltFloeID, 0.0);
	rmSetObjectDefMaxDistance(saltFloeID, 40);
	rmAddObjectDefConstraint(saltFloeID, SaltVsSaltID);
	rmPlaceObjectDefAtLoc(saltFloeID, 0, 0.55, 0.45, 2);

	// Scattered BERRRIES		
	int berries2ID=rmCreateObjectDef("random berries2");
	rmAddObjectDefItem(berries2ID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berries2ID, 0.0);
	rmSetObjectDefMaxDistance(berries2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berries2ID, avoidTC);
	rmAddObjectDefConstraint(berries2ID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berries2ID, avoidCW);
	rmAddObjectDefConstraint(berries2ID, avoidAll);
	rmAddObjectDefConstraint(berries2ID, avoidRandomBerries);
	rmAddObjectDefConstraint(berries2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(berries2ID, smallMesaConstraint);
	rmPlaceObjectDefInArea(berries2ID, 0, westMountainTerrain, cNumberNonGaiaPlayers);   //was *4

	// EMU
	int turkeyID=rmCreateObjectDef("random emu");
	rmAddObjectDefItem(turkeyID, "zpEmu", rmRandInt(8,9), 8.0); 
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(turkeyID, true);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*5);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Kangaroos
	int kangarooID=rmCreateObjectDef("random kangaroos");
	rmAddObjectDefItem(kangarooID, "zpRedKangaroo", rmRandInt(6,9), 6.0); 
	rmSetObjectDefMinDistance(kangarooID, 0.0);
	rmSetObjectDefMaxDistance(kangarooID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(kangarooID, avoidTC);
	rmAddObjectDefConstraint(kangarooID, avoidCW);
	rmAddObjectDefConstraint(kangarooID, avoidRandomTurkeys);
	rmAddObjectDefConstraint(kangarooID, avoidKangaroos);
	//rmAddObjectDefConstraint(kangarooID, avoidAll);
	//rmAddObjectDefConstraint(kangarooID, avoidRandomBerries);
	rmAddObjectDefConstraint(kangarooID, avoidImpassableLand);
	rmAddObjectDefConstraint(kangarooID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(kangarooID, true);
	rmPlaceObjectDefInArea(kangarooID, 0, bigIslandID, cNumberNonGaiaPlayers*3);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Cassowary
	int cassowaryID=rmCreateObjectDef("random cassowary");
	rmAddObjectDefItem(cassowaryID, "zpCassowary", rmRandInt(1,2), 8.0); 
	rmSetObjectDefMinDistance(cassowaryID, 0.0);
	rmSetObjectDefMaxDistance(cassowaryID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(cassowaryID, avoidTC);
	rmAddObjectDefConstraint(cassowaryID, avoidCW);
	rmAddObjectDefConstraint(cassowaryID, avoidRandomTurkeys);
	rmAddObjectDefConstraint(kangarooID, avoidKangaroos);
	rmAddObjectDefConstraint(kangarooID, avoidCassowary);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(cassowaryID, avoidImpassableLand);
	rmAddObjectDefConstraint(cassowaryID, smallMesaConstraint);
	rmSetObjectDefCreateHerd(cassowaryID, true);
	rmPlaceObjectDefInArea(cassowaryID, 0, bigIslandID, cNumberNonGaiaPlayers*2);
    	
	// check for KOTH game mode	
	if(rmGetIsKOTH()) {	
			
		int randLoc = rmRandInt(1,2);	
		float xLoc = 0.55;	
		float yLoc = 0.25;	
		float walk = 0.035;	
			
		if(randLoc == 1 || cNumberTeams > 2 || cNumberNonGaiaPlayers <= 3){	
		xLoc = .48;	
		yLoc = .53;	
		}	
			
		ypKingsHillPlacer(xLoc, yLoc, walk, smallMesaConstraint);	
		rmEchoInfo("XLOC = "+xLoc);	
		rmEchoInfo("XLOC = "+yLoc);	
	}	
  	
	//************************ Nuggets ********************************

 	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);

	rmSetNuggetDifficulty(3, 4);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers*2);
	

	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	//rmAddObjectDefConstraint(nugget1, avoidCW);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater20);
	rmAddObjectDefConstraint(nugget1, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*4);

	// Water Nuggets - Hard and Easy
	int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
	rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(6, 6);
	rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.2));
	rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2b, avoidLand);
	rmAddObjectDefConstraint(nugget2b, flagVsFlag);
	rmAddObjectDefConstraint(nugget2b, avoidNuggetWater2);
	rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(nugget2b, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 
  
	int nugget2c= rmCreateObjectDef("nugget water" + i); 
	rmAddObjectDefItem(nugget2c, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(5, 5);
	rmSetObjectDefMinDistance(nugget2c, rmXFractionToMeters(0.2));
	rmSetObjectDefMaxDistance(nugget2c, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2c, avoidLand);
	rmAddObjectDefConstraint(nugget2c, avoidNuggetWater);
	rmAddObjectDefConstraint(nugget2c, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(nugget2c, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));	
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.46));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2 + rmRandInt(4,5));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------
	int fishID=rmCreateObjectDef("fish Tuna");
	rmAddObjectDefItem(fishID, "ypFishTuna", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 14*cNumberNonGaiaPlayers); 


	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);
	}

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);

	// RANDOM TREES

	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "treeMadrone", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
	rmAddObjectDefConstraint(randomTreeID, smallMesaConstraint);
	rmPlaceObjectDefInArea(randomTreeID, 0, bigIslandID, 8*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.


	// ------Triggers--------//

	string pirate1ID = "0";
	string pirate2ID = "0";
	string scientist1ID = "0";
	string scientist2ID = "0";


	if (nativeVariant ==1) {
		pirate1ID = "15";
		pirate2ID = "46";
	}

	if (nativeVariant ==2) {
		scientist1ID = "15";
		scientist2ID = "100";

	}


	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australian Mercenaries
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpEnableTradeRouteAustralian"); // Australian TR1
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpMapAustralian"); // Australian TR2
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

	
	if (nativeVariant ==2) {
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
	}
	if (nativeVariant ==1) {
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
	}


	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate PenalColony"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPenalColonyRevolt"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPenalColony"); //operator
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_PenalColony"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	if (nativeVariant ==1) {
	
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
		rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
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
		rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
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
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Grace
		rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParamFloat("Param1",1200);
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
		rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate1ID); // Unique Object ID Village 3
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
		rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate1ID); // Unique Object ID Village 3
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
		rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate2ID); // Unique Object ID Village 4
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
		rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate2ID); // Unique Object ID Village 4
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
	}

	if (nativeVariant ==2) {

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
	}

	// AI Australian Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Australian Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int AustralianLeader=-1;
	AustralianLeader = rmRandInt(1,3);

	if (AustralianLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyParkes"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (AustralianLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyCunningham"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (AustralianLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyLogan"); //operator
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




