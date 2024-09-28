// Tasmania
// September 2024

// Main entry point for random map script    

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	string baseTerrainMix = "painteddesert_groundmix_4";
	string lightingSet = "spcjc4blight";
	string seaType = "ZP Tasmania Coast";
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
	int nativeVariant = 1;


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
	int playerTiles = 28000;
	if (cNumberNonGaiaPlayers >2)
		playerTiles = 25000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 22000;
	if (cNumberNonGaiaPlayers >6)
		if (cNumberTeams == 2)
			playerTiles = 18000;
		else
			playerTiles = 22000;	

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseTerrainMix);
	rmSetMapType("tasmania");
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
	int classPortSite = rmDefineClass("classPortSite");
	int classBonusIsland = rmDefineClass("classBonusIsland");
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
	int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 37.0);
	int avoidPortSite=rmCreateClassDistanceConstraint("avoid port site", classPortSite, rmXFractionToMeters(0.1));
	int avoidBonusIslands=rmCreateClassDistanceConstraint("avoid bonus area", classBonusIsland, 60.0);
	int avoidPirateSites=rmCreateTypeDistanceConstraint("stay away from Pirate Sites", "zpSocketPirates", rmXFractionToMeters(0.02));

	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishTuna", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 30.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "MinkeWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int SaltVsSaltID=rmCreateTypeDistanceConstraint("salt v salt", "zpSaltMineWater", 20.0);	//Was 8.0
	int avoidCoin=-1;
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
  int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mineCopper", 40.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "mineCopper", 50.0);	// 85.0 seems the best for event mineCopper distribution.  This number tells mineCoppers how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random emu", "zpRedNeckedWallaby", 40.0);	//Attempting to spread them out more evenly.
	int avoidKangaroos=rmCreateTypeDistanceConstraint("avoid random kangaroo", "zpRedKangaroo", 40.0);	//Attempting to spread them out more evenly.
	int avoidCassowary=rmCreateTypeDistanceConstraint("avoid random cassowary", "zpCassowary", 70.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater1 = rmCreateTerrainDistanceConstraint("avoid water 1", "Land", false, 0.5);
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water 5", "Land", false, 1.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 28.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 80); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 3.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", classNatives , 10.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("avoid natives far", classNatives , 18.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);


	// Lake Constraints
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 5.5);
	int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
	int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route island", 15.0);
	int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 12.0);
	int avoidTradeSocket = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 12.0);
	int avoidTradeSocketMedium = rmCreateTypeDistanceConstraint("avoid trade sockets medium", "sockettraderoute", 20.0);
	int avoidTradeSocketFar = rmCreateTypeDistanceConstraint("avoid trade sockets far", "sockettraderoute", 45.0);
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

	rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.25);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.2);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.1);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.85, 0.35);
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.3);

	bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");	

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	rmSetObjectDefMaxDistance(socketID, 0.0);

	int portSite1 = rmCreateArea ("port_site1");
	rmSetAreaSize(portSite1, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaTerrainType(portSite1, "california\groundshore1_cal");
	rmSetAreaCoherence(portSite1, 1);
	rmAddAreaToClass(portSite1, classPortSite);
	rmSetAreaSmoothDistance(portSite1, 15);
	rmSetAreaBaseHeight(portSite1, 2.2);

	int portSite2 = rmCreateArea ("port_site2");
	rmSetAreaSize(portSite2, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));
	rmSetAreaTerrainType(portSite2, "california\groundshore1_cal");
	rmSetAreaCoherence(portSite2, 1);
	rmAddAreaToClass(portSite2, classPortSite);
	rmSetAreaSmoothDistance(portSite2, 15);
	rmSetAreaBaseHeight(portSite2, 2.2);

	int portSite3 = rmCreateArea ("port_site3");
	rmSetAreaSize(portSite3, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
	rmSetAreaTerrainType(portSite3, "california\groundshore1_cal");
	rmSetAreaCoherence(portSite3, 1);
	rmAddAreaToClass(portSite3, classPortSite);
	rmSetAreaSmoothDistance(portSite3, 15);
	rmSetAreaBaseHeight(portSite3, 2.2);

	int stationGrouping01 = -1;
	stationGrouping01 = rmCreateGrouping("station grouping 01", "Harbour_Center_SW");
	rmSetGroupingMinDistance(stationGrouping01, 0.0);
	rmSetGroupingMaxDistance (stationGrouping01, 0.0);

	int stationGrouping02 = -1;
	stationGrouping02 = rmCreateGrouping("station grouping 02", "Harbour_Center_SE");
	rmSetGroupingMinDistance(stationGrouping02, 0.0);
	rmSetGroupingMaxDistance (stationGrouping02, 0.0);

	int stationGrouping03 = -1;
	stationGrouping03 = rmCreateGrouping("station grouping 03", "Harbour_Center_S");
	rmSetGroupingMinDistance(stationGrouping03, 0.0);
	rmSetGroupingMaxDistance (stationGrouping03, 0.0);
	
	vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	vector socketLoc11  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	vector socketLoc12  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

	socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.08);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	rmSetAreaLocation(portSite3, rmXMetersToFraction(xsVectorGetX(socketLoc)+39), rmZMetersToFraction(xsVectorGetZ(socketLoc)));
	rmBuildArea(portSite3);
	//rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)+20), rmZMetersToFraction(xsVectorGetZ(socketLoc)));

	socketLoc11  = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	rmSetAreaLocation(portSite2, rmXMetersToFraction(xsVectorGetX(socketLoc11)+32), rmZMetersToFraction(xsVectorGetZ(socketLoc11)+32));
	rmBuildArea(portSite2);
	//rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)+18), rmZMetersToFraction(xsVectorGetZ(socketLoc)+18));

	socketLoc12  = rmGetTradeRouteWayPoint(tradeRouteID, 0.92);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
	rmSetAreaLocation(portSite1, rmXMetersToFraction(xsVectorGetX(socketLoc12)), rmZMetersToFraction(xsVectorGetZ(socketLoc12)+39));
	rmBuildArea(portSite1);
	//rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+20));	
					

	// Make one big island.  
	int bigIslandID=rmCreateArea("tasmania");
	rmSetAreaSize(bigIslandID, 0.25, 0.25);
	rmSetAreaCoherence(bigIslandID, 0.7);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 2.0);
	rmSetAreaSmoothDistance(bigIslandID, 50);
	rmSetAreaMix(bigIslandID, "california_grassrocks");
		rmAddAreaTerrainLayer(bigIslandID, "california\groundshore1_cal", 0, 3);
		rmAddAreaTerrainLayer(bigIslandID, "california\groundshore3b_cal", 3, 6);
		rmAddAreaTerrainLayer(bigIslandID, "california\groundshore3c_cal", 6, 9);
	rmAddAreaConstraint(bigIslandID, islandAvoidTradeRoute);
	rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmAddAreaToClass(bigIslandID, classIsland);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);
		rmAddAreaInfluenceSegment(bigIslandID, 0.27, 0.27, 0.6, 0.3);
		rmAddAreaInfluenceSegment(bigIslandID, 0.6, 0.3, 0.75, 0.45);
		rmAddAreaInfluenceSegment(bigIslandID, 0.85, 0.45, 0.6, 0.6);
		rmAddAreaInfluenceSegment(bigIslandID, 0.6, 0.6, 0.45, 0.75);
		rmAddAreaInfluenceSegment(bigIslandID, 0.45, 0.85, 0.3, 0.6);
		rmAddAreaInfluenceSegment(bigIslandID, 0.3, 0.6, 0.27, 0.27);
	rmSetAreaWarnFailure(bigIslandID, false);
	rmSetAreaLocation(bigIslandID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID);

	// Make Australia contint on the North 
	int northIslandID=rmCreateArea("north island");
	rmSetAreaSize(northIslandID, 0.07, 0.07);
	rmSetAreaCoherence(northIslandID, 0.7);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(northIslandID, 2.0);
	rmSetAreaSmoothDistance(northIslandID, 50);
	rmSetAreaMix(northIslandID, "california_grassrocks");
		rmAddAreaTerrainLayer(northIslandID, "california\groundshore1_cal", 0, 2);
		rmAddAreaTerrainLayer(northIslandID, "california\groundshore3b_cal", 2, 4);
		rmAddAreaTerrainLayer(northIslandID, "california\groundshore3c_cal", 4, 6);
	rmAddAreaConstraint(northIslandID, islandAvoidTradeRoute);
	rmAddAreaConstraint(northIslandID, islandConstraint);
	rmAddAreaToClass(northIslandID, classIsland);
	rmAddAreaToClass(northIslandID, classBonusIsland);
	rmSetAreaObeyWorldCircleConstraint(northIslandID, false);
	rmSetAreaElevationType(northIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(northIslandID, 4.0);
	rmSetAreaElevationMinFrequency(northIslandID, 0.09);
	rmSetAreaElevationOctaves(northIslandID, 3);
	rmSetAreaElevationPersistence(northIslandID, 0.2);
	rmSetAreaElevationNoiseBias(northIslandID, 1);
	rmSetAreaWarnFailure(northIslandID, false);
	rmSetAreaLocation(northIslandID, .8, .8);		//North of the map
		rmAddAreaInfluenceSegment(northIslandID, 0.6, 1.0, 0.75, 0.75);
		rmAddAreaInfluenceSegment(northIslandID, 0.75, 0.75, 1.0, 0.6);
		rmAddAreaInfluenceSegment(northIslandID, 1.0, 0.6, 1.0, 0.7);
		rmAddAreaInfluenceSegment(northIslandID, 1.0, 0.7, 0.7, 1.0);
		rmAddAreaInfluenceSegment(northIslandID, 0.7, 1.0, 0.6, 1.0);
	rmBuildArea(northIslandID);

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

	rmPlaceObjectDefAtLoc(controllerID1, 0, 0.26, 0.55);
	rmPlaceObjectDefAtLoc(controllerID2, 0, 0.55, 0.26);

	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
	vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));


	// Pirate Village 1

	int piratesVillageID = -1;
	int piratesVillageType = rmRandInt(1,2);

		piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");

	rmSetGroupingMinDistance(piratesVillageID, 0);
	rmSetGroupingMaxDistance(piratesVillageID, 30);
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
	rmSetGroupingMaxDistance(piratesVillageID2, 30);
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

	
	
	// Tasmania Central Mountains
	int coastMountains = rmCreateArea ("coast cliffs");
	rmSetAreaSize(coastMountains, 0.19, 0.19);
	rmSetAreaLocation(coastMountains, 0.47, 0.47);
	rmSetAreaCoherence(coastMountains, 0.8);
	rmSetAreaMinBlobs(coastMountains, 8);
	rmSetAreaMaxBlobs(coastMountains, 12);
	rmSetAreaMinBlobDistance(coastMountains, 8.0);
	rmSetAreaMaxBlobDistance(coastMountains, 10.0);
	rmSetAreaSmoothDistance(coastMountains, 15);
	rmAddAreaConstraint(coastMountains, avoidPortSite);
	rmAddAreaConstraint(coastMountains, avoidWater5);
	rmAddAreaConstraint(coastMountains, avoidPirates);
	rmSetAreaCliffType(coastMountains, "ZP Tasmania Coast");
	rmSetAreaCliffEdge(coastMountains, 1, 1.0, 0.0, 1.0, 0);
	rmSetAreaCliffHeight(coastMountains, 0.0, 0.0, 0.5);
	rmSetAreaHeightBlend(coastMountains, 4);
	rmSetAreaMix(coastMountains, "california_grass");
	rmSetAreaCliffPainting(coastMountains, true, true, true, 1.5, true);
	rmSetAreaElevationType(coastMountains, cElevTurbulence);
	rmSetAreaBaseHeight(coastMountains, 7.0);
	rmSetAreaElevationVariation(coastMountains, 1.0);
	rmSetAreaElevationPersistence(coastMountains, 0.2);
	rmSetAreaElevationNoiseBias(coastMountains, 1);
	rmBuildArea(coastMountains);

	int coastMountainsTerrain2=rmCreateArea("coast mountains terrain"); 
	rmSetAreaSize(coastMountainsTerrain2, 0.18, 0.18);
	rmSetAreaLocation(coastMountainsTerrain2, 0.47, 0.47);
	rmSetAreaCoherence(coastMountainsTerrain2, 0.8);
	rmAddAreaConstraint(coastMountainsTerrain2, avoidPortSite);
	rmAddAreaConstraint(coastMountainsTerrain2, avoidWater5);
	rmAddAreaConstraint(coastMountainsTerrain2, avoidPirates);
	rmSetAreaMix(coastMountainsTerrain2, "california_grassrocks");
	rmSetAreaObeyWorldCircleConstraint(coastMountainsTerrain2, false);
	rmBuildArea(coastMountainsTerrain2);

	int rampID1 = rmCreateArea("rampID1");
	rmSetAreaSize(rampID1, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
	rmSetAreaLocation(rampID1, 0.45, 0.75);
	rmSetAreaMix(rampID1, "california_grass");
	rmSetAreaBaseHeight(rampID1, 6.0);
	rmSetAreaSmoothDistance(rampID1, 15);
	rmSetAreaHeightBlend(rampID1, 2.5);
	rmSetAreaCoherence(rampID1, .7);
	rmBuildArea(rampID1);  

	int rampID2 = rmCreateArea("rampID2");
	rmSetAreaSize(rampID2, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
	rmSetAreaLocation(rampID2, 0.75, 0.45);
	rmSetAreaMix(rampID2, "california_grass");
	rmSetAreaBaseHeight(rampID2, 6.0);
	rmSetAreaSmoothDistance(rampID2, 15);
	rmSetAreaHeightBlend(rampID2, 2.5);
	rmSetAreaCoherence(rampID2, .7);
	rmBuildArea(rampID2);  

	int rampID3 = rmCreateArea("rampID3");
	rmSetAreaSize(rampID3, 0.04, 0.04);
	rmSetAreaLocation(rampID3, 0.4, 0.4);
	rmSetAreaMix(rampID3, "california_grass");
	rmSetAreaBaseHeight(rampID3, 6.0);
	rmSetAreaSmoothDistance(rampID3, 15);
	rmSetAreaHeightBlend(rampID3, 2.5);
	rmSetAreaCoherence(rampID3, .7);
	rmBuildArea(rampID3);  

	int rampID4 = rmCreateArea("rampID4");
	rmSetAreaSize(rampID4, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
	rmSetAreaLocation(rampID4, 0.5, 0.3);
	rmSetAreaMix(rampID4, "california_grass");
	rmSetAreaBaseHeight(rampID4, 6.0);
	rmSetAreaSmoothDistance(rampID4, 15);
	rmSetAreaHeightBlend(rampID4, 2.5);
	rmSetAreaCoherence(rampID4, .7);
	rmBuildArea(rampID4);

	int rampID5 = rmCreateArea("rampID5");
	rmSetAreaSize(rampID5, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
	rmSetAreaLocation(rampID5, 0.3, 0.5);
	rmSetAreaMix(rampID5, "california_grass");
	rmSetAreaBaseHeight(rampID5, 6.0);
	rmSetAreaSmoothDistance(rampID5, 15);
	rmSetAreaHeightBlend(rampID5, 2.5);
	rmSetAreaCoherence(rampID5, .7);
	rmBuildArea(rampID5);


	int centralMountains = rmCreateArea ("cantral cliffs");
	rmSetAreaSize(centralMountains, 0.05, 0.05);
	rmSetAreaLocation(centralMountains, 0.48, 0.48);
	rmSetAreaCoherence(centralMountains, 0.6);
	rmSetAreaMinBlobs(centralMountains, 8);
	rmSetAreaMaxBlobs(centralMountains, 12);
	rmSetAreaMinBlobDistance(centralMountains, 8.0);
	rmSetAreaMaxBlobDistance(centralMountains, 10.0);
	rmSetAreaSmoothDistance(centralMountains, 15);
	rmSetAreaCliffType(centralMountains, "Tasmania Low");
	rmSetAreaCliffEdge(centralMountains, 4, 0.18, 0.0, 1.0, 0);
	rmSetAreaCliffHeight(centralMountains, 5.2, 0.0, 0.5);
	rmSetAreaMix(centralMountains, "california_grass");
	rmSetAreaElevationType(centralMountains, cElevTurbulence);
	rmSetAreaElevationVariation(centralMountains, 3.0);
	rmSetAreaElevationPersistence(centralMountains, 0.2);
	rmSetAreaElevationNoiseBias(centralMountains, 1);
	rmBuildArea(centralMountains);

	int centralMountainTerrain2=rmCreateArea("cantral mountains terrain"); 
	rmSetAreaSize(centralMountainTerrain2, 0.05, 0.05);
	rmSetAreaLocation(centralMountainTerrain2, 0.48, 0.48);
	rmSetAreaCoherence(centralMountainTerrain2, 0.6);
	rmSetAreaMix(centralMountainTerrain2, "newengland_grass");
	rmSetAreaObeyWorldCircleConstraint(centralMountainTerrain2, false);
	rmBuildArea(centralMountainTerrain2);

	int centralMountains3=rmCreateArea("cantral mountain 2");
	rmSetAreaLocation(centralMountains3, 0.47, 0.47);
	rmSetAreaSize(centralMountains3, 0.02, 0.02);
	rmSetAreaWarnFailure(centralMountains3, false);
	rmSetAreaCliffType(centralMountains3, "Tasmania Medium");
	rmSetAreaCliffEdge(centralMountains3, 4, 0.21, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralMountains3, 6.0, 2.0, 0.3);
	rmSetAreaCoherence(centralMountains3, 0.6);
	rmSetAreaSmoothDistance(centralMountains3, 12);
	rmSetAreaElevationVariation(centralMountains3, 3.0);
	rmSetAreaHeightBlend(centralMountains3, 1);
	rmSetAreaCliffPainting(centralMountains3, true, false, true);
	rmBuildArea(centralMountains3);

	int centralMountainTerrain3=rmCreateArea("central mountains terrain 2"); 
	rmSetAreaSize(centralMountainTerrain3, 0.02, 0.02);
	rmSetAreaLocation(centralMountainTerrain3, 0.47, 0.47);
	rmSetAreaCoherence(centralMountainTerrain3, 0.6);
	rmSetAreaMix(centralMountainTerrain3, "patagonia_dirt");
	rmSetAreaObeyWorldCircleConstraint(centralMountainTerrain3, false);
	rmBuildArea(centralMountainTerrain3);

	int fujiPeaklvl3 = rmCreateArea("fujiPeaklvl3");
	rmSetAreaSize(fujiPeaklvl3, 0.003, 0.003);
	rmSetAreaLocation(fujiPeaklvl3, 0.47, 0.47);
	rmSetAreaBaseHeight(fujiPeaklvl3, 17.0);
	rmSetAreaSmoothDistance(fujiPeaklvl3, 15);
	rmSetAreaHeightBlend(fujiPeaklvl3, 1.5);
	rmSetAreaCoherence(fujiPeaklvl3, .7);
	rmBuildArea(fujiPeaklvl3);  

	int centralMountains4=rmCreateArea("cantral mountain top");
	rmSetAreaLocation(centralMountains4, 0.47, 0.47);
	rmSetAreaSize(centralMountains4, 0.001, 0.001);
	rmSetAreaWarnFailure(centralMountains4, false);
	rmSetAreaCliffType(centralMountains4, "Tasmania High");
	rmSetAreaCliffEdge(centralMountains4, 1, 1.00, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralMountains4, 0.0, 2.0, 0.3);
	rmSetAreaBaseHeight(centralMountains4, 25.0);
	rmSetAreaCoherence(centralMountains4, 0.6);
	rmSetAreaSmoothDistance(centralMountains4, 12);
	rmSetAreaElevationVariation(centralMountains4, 3.0);
	rmSetAreaHeightBlend(centralMountains4, 1);
	rmSetAreaCliffPainting(centralMountains4, true, false, true);
	rmBuildArea(centralMountains4);



	 		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);


	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.
	//float teamStartLoc = rmRandFloat(0.2, 0.4);    //Temporarily force float to be .4 or lower, so Team 0 will be in the North.
	


	// Land Trade Route North
	int tradeRouteID2 = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(tradeRouteID2);

	rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.65);

	bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "dirt");	

	int socket2ID=rmCreateObjectDef("sockets to dock Trade Posts Land");
	rmSetObjectDefTradeRouteID(socket2ID, tradeRouteID2);
	rmAddObjectDefItem(socket2ID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socket2ID, true);
	rmSetObjectDefMinDistance(socket2ID, 2.0);
	rmSetObjectDefMaxDistance(socket2ID, 8.0);

	vector socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.1);

	socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.35);
	rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);

	socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.65);
	rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);


	// Trade Sockets


	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)+20), rmZMetersToFraction(xsVectorGetZ(socketLoc)+4));

	rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(socketLoc11)+17), rmZMetersToFraction(xsVectorGetZ(socketLoc11)+17));

	rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc12)-2), rmZMetersToFraction(xsVectorGetZ(socketLoc12)+21));

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);
	
	// Players

	if (cNumberTeams == 2) {
		if (cNumberNonGaiaPlayers ==2){
			if (teamStartLoc > 0.5){
				rmPlacePlayer(1, 0.2, 0.7);
				rmPlacePlayer(2, 0.7, 0.2);
			}
			else{
				rmPlacePlayer(2, 0.2, 0.7);
				rmPlacePlayer(1, 0.7, 0.2);
			}
		}
		else{
			if (teamStartLoc > 0.5){
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.35, 0.55);
				rmPlacePlayersCircular(.43, .43, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.7, 0.9);
				rmPlacePlayersCircular(.43, .43, 0);
			}
			else{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.7, 0.9);
				rmPlacePlayersCircular(.43, .43, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.35, 0.55);
				rmPlacePlayersCircular(.43, .43, 0);
			}
		}
	}
	
	else
	{
		rmSetPlacementSection(0.35, 0.90);
		rmPlacePlayersCircular(0.43, 0.43, 0);
	}
	

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);

	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************

	// Penal Colonies

	int jewish1VillageTypeID = rmRandInt(1, 3);
	int jewish2VillageTypeID = 4-jewish1VillageTypeID;
	if (jewish2VillageTypeID ==2)
		jewish2VillageTypeID = 3;

	int jewish1ID = rmCreateGrouping("jewish 1", "Tasmania_Colony_0"+jewish1VillageTypeID);
	int jewish2ID = rmCreateGrouping("jewish 2", "Tasmania_Colony_0"+jewish2VillageTypeID);

	rmSetGroupingMinDistance(jewish1ID, 0);
	rmSetGroupingMaxDistance(jewish1ID, 20);
	rmSetGroupingMinDistance(jewish2ID, 0);
	rmSetGroupingMaxDistance(jewish2ID, 20);

	rmAddGroupingConstraint(jewish1ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish2ID, avoidImpassableLand);

	rmPlaceGroupingAtLoc(jewish1ID, 0, 0.45, 0.68, 1);
	rmPlaceGroupingAtLoc(jewish2ID, 0, 0.68, 0.45, 1);
  
	// Aboriginal Villages
		
	int caribsVillageID = -1;
	int caribsVillageType = rmRandInt(1,5);
	caribsVillageID = rmCreateGrouping("caribs city", "Aboriginal_Tasmania_0"+caribsVillageType);
	rmAddGroupingToClass(caribsVillageID, classNatives);
	rmSetGroupingMinDistance(caribsVillageID, 0.0);
	rmSetGroupingMaxDistance(caribsVillageID, 30.0);
	rmAddGroupingConstraint(caribsVillageID, avoidImpassableLand);
	rmAddGroupingConstraint(caribsVillageID, avoidTradeSocketFar);
	rmPlaceGroupingAtLoc(caribsVillageID, 0, 0.35, 0.35);	// JSB - end of north long peninsula.

	int caribs2VillageID = -1;
	int caribs2VillageType = rmRandInt(1,5);
	caribs2VillageID = rmCreateGrouping("caribs2 city", "Aboriginal_Tasmania_0"+caribs2VillageType);
	rmAddGroupingToClass(caribs2VillageID, classNatives);			
	rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
	rmSetGroupingMinDistance(caribs2VillageID, 0.0);
	rmSetGroupingMaxDistance(caribs2VillageID, 30.0);
	rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.62, 0.62);  // JSB - end of south long peninsula.


	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
	int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", centralMountains4, rmXFractionToMeters(0.08));
	int smallMesaShortConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa Short", centralMountains4, rmXFractionToMeters(0.04));
		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//***************** PLAYER STARTING STUFF **********************************

	string shipType = "Privateer";
	string shipType2 = "zpWakaCanoe";

	int colonyShipID=rmCreateObjectDef("colony ship");
	rmAddObjectDefItem(colonyShipID, shipType2, 1, 0.0);
	rmSetObjectDefGarrisonStartingUnits(colonyShipID, true);
	rmSetObjectDefMinDistance(colonyShipID, 0.0);
	rmSetObjectDefMaxDistance(colonyShipID, 20.0);

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.6);

    for(i=1; < cNumberNonGaiaPlayers + 1) {

		/*if (rmGetPlayerCiv(i) == rmGetCivID("DEItalians"))
		{
			shipType = "Galleass";
			shipType2 = "Caravel";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("Dutch"))
		{
			shipType = "Fluyt";
			shipType2 = "Caravel";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
		{
			shipType = "Galleon";
			shipType2 = "Galley";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("DEMaltese"))
		{
			shipType = "Galleon";
			shipType2 = "DeOrderGalley";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("Chinese"))
		{
			shipType = "ypFuchuan";
			shipType2 = "ypWarJunk";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("Japanese"))
		{
			shipType = "ypAtakebune";
			shipType2 = "ypFune";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("DEAmericans"))
		{
			shipType = "deSteamer";
			shipType2 = "deSloop";
		}
		else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEMexicans"))
		{
			shipType = "Galleon";
			shipType2 = "deSloop";
		}
		else if (rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))
		{
			shipType = "deBattleCanoe";
			shipType2 = "deBattleCanoe";
		}
		else if ( rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux"))
		{
			shipType = "Privateer";
			shipType2 = "Privateer";
		}
		else if ( rmGetPlayerCiv(i) == rmGetCivID("XPAztec"))
		{
			shipType = "xpTlalocCanoe";
			shipType2 = "xpTlalocCanoe";
		}
		else if ( rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
		{
			shipType = "deChinchaRaft";
			shipType2 = "deChinchaRaft";
		}
		else
		{
			shipType = "Galleon";
			shipType2 = "Caravel";
		}*/

        rmPlaceObjectDefAtLoc(colonyShipID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


		rmAddPlayerResource(i, "wood", 600);
		rmAddPlayerResource(i, "XP", 80);

		int catamaranID=rmCreateObjectDef("Catamaran"+i);
		rmAddObjectDefItem(catamaranID, shipType, 1, 5.0);
		rmAddObjectDefItem(catamaranID, "CoveredWagon", 1, 0.0);
		if (rmGetPlayerCiv(i) == rmGetCivID("Japanese"))
			rmAddObjectDefItem(catamaranID, "ypGroveWagon", 1, 0.0);
		if (rmGetPlayerCiv(i) == rmGetCivID("Dutch"))
			rmAddObjectDefItem(catamaranID, "ypBankWagon", 1, 0.0);
		rmAddObjectDefItem(catamaranID, "zpNatConvictLabourer", 1, 0.0);
		rmAddObjectDefItem(catamaranID, "zpNatConvictLabourer", 1, 0.0);
		rmAddObjectDefItem(catamaranID, "zpNatConvictLabourer", 1, 0.0);
		rmSetObjectDefGarrisonStartingUnits(catamaranID, true);
		rmSetObjectDefGarrisonSecondaryUnits(catamaranID, true);
		rmPlaceObjectDefAtLoc(catamaranID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


		int waterFlag = rmCreateObjectDef("HC water flag "+i);
		rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
		rmSetObjectDefMinDistance(waterFlag, 1);
		rmSetObjectDefMaxDistance(waterFlag, 8);
		rmPlaceObjectDefAtLoc(waterFlag, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
	}

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
		//rmSetAreaTerrainType(forest, "california\groundforest_cal");
		//rmSetAreaMix(forest, "Deccan_Grass_A");
		rmAddAreaConstraint(forest, forestConstraint);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest, smallMesaConstraint); 
		rmAddAreaConstraint(forest, avoidTC);
		rmAddAreaConstraint(forest, avoidCW);
		rmAddAreaConstraint(forest, avoidWater8);
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

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "mineCopper", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, 50);
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
	rmAddObjectDefConstraint(goldID, avoidWater8);
    rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(goldID, smallMesaShortConstraint);
	rmPlaceObjectDefInArea(goldID, 0, coastMountains, cNumberNonGaiaPlayers*5);
	rmPlaceObjectDefInArea(goldID, 0, northIslandID, rmRandInt(1, 2));

	int goldID2 = rmCreateObjectDef("random gold 2");
	rmAddObjectDefItem(goldID2, "mineCopper", 1, 0);
	rmSetObjectDefMinDistance(goldID2, 0.0);
	rmSetObjectDefMaxDistance(goldID2, 50);
	rmAddObjectDefConstraint(goldID2, avoidWater8);
	rmAddObjectDefConstraint(goldID2, avoidCoin);
    rmAddObjectDefConstraint(goldID2, shortAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(goldID2, 0, 0.35, 0.35);
	rmPlaceObjectDefAtLoc(goldID2, 0, 0.45, 0.8);
	rmPlaceObjectDefAtLoc(goldID2, 0, 0.8, 0.45);

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
	rmPlaceObjectDefInArea(berriesID, 0, coastMountains, cNumberNonGaiaPlayers*2);   //was *4*/
	rmPlaceObjectDefInArea(berriesID, 0, northIslandID, rmRandInt(1, 2));

	// EMU
	int turkeyID=rmCreateObjectDef("random emu");
	rmAddObjectDefItem(turkeyID, "zpRedNeckedWallaby", rmRandInt(8,9), 8.0); 
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, smallMesaShortConstraint);
	rmSetObjectDefCreateHerd(turkeyID, true);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*3);
	rmPlaceObjectDefInArea(turkeyID, 0, northIslandID, 2);

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
	rmPlaceObjectDefInArea(kangarooID, 0, bigIslandID, cNumberNonGaiaPlayers*2);
	rmPlaceObjectDefInArea(kangarooID, 0, northIslandID, 2);

    	
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
	rmAddObjectDefConstraint(nugget2, avoidWater8);
	rmAddObjectDefConstraint(nugget2, avoidTradeSocket);
	rmAddObjectDefConstraint(nugget2, smallMesaConstraint);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmSetNuggetDifficulty(3, 4);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(nugget2, 0, northIslandID, cNumberNonGaiaPlayers/2);
	

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
	rmAddObjectDefConstraint(nugget1, smallMesaShortConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTradeSocket);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*2);
	rmPlaceObjectDefInArea(nugget1, 0, northIslandID, cNumberNonGaiaPlayers);

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
	rmAddObjectDefConstraint(nugget2c, flagVsFlag);
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
	rmAddObjectDefConstraint(fishID, avoidTradeSocketMedium);
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
	for(i=1; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
	rmSetTriggerEffectParamInt("Status",2);
	}
	for(i=0; <= cNumberNonGaiaPlayers) {
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_PenalColony"+k));
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




