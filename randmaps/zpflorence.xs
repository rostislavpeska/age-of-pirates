// Florence vs. Rome
// March 2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

string fish1 = "ypFishCarp";

void main(void)
{
	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01);

	// Choose summer or winter 

	//		seasonPicker = 0.77; 		// for testing
	float seasonPicker = rmRandFloat(0,1);//rmRandFloat(0,1); //high # is snow, low is spring

   	//Chooses which natives appear on the map
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

	if (rmAllocateSubCivs(3) == true)
	{
		subCiv0=rmGetCivID("auditore");
		rmEchoInfo("subCiv0 is auditore "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "auditore");

		subCiv1=rmGetCivID("spcjesuit");
		rmEchoInfo("subCiv1 is spcjesuit "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "spcjesuit");
  
		subCiv2=rmGetCivID("maltese");
		rmEchoInfo("subCiv2 is maltese "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "maltese");

	}

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	int firstDefender = -1;
	int secondDefender = -1;
	int thirdDefender = -1;
	int fourthDefender = -1;
	int fifthDefender = -1;
	int sixthDefender = -1;
	int seventhDefender = -1;
	
	int firstAttacker = -1;
	int secondAttacker = -1;
	int thirdAttacker = -1;
	int fourthAttacker = -1;
	int fifthAttacker = -1;
	int sixthAttacker = -1;
	int seventhAttacker = -1;

	// Defenders	

		for (i = 1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				firstDefender = i;
				break;
			}
		}
		for (i = firstDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				secondDefender = i;
				break;
			}
		}
		for (i = secondDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				thirdDefender = i;
				break;
			}
		}
		for (i = thirdDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				fourthDefender = i;
				break;
			}
		}
		for (i = fourthDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				fifthDefender = i;
				break;
			}
		}
		for (i = fifthDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				sixthDefender = i;
				break;
			}
		}
		for (i = sixthDefender+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 1)
			{
				seventhDefender = i;
				break;
			}
		}

	// Attackers

		for (i = 1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				firstAttacker = i;
				break;
			}
		}

		for (i = firstAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				secondAttacker = i;
				break;
			}
		}
		for (i = secondAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				thirdAttacker = i;
				break;
			}
		}
		for (i = thirdAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				fourthAttacker = i;
				break;
			}
		}
		for (i = fourthAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				fifthAttacker = i;
				break;
			}
		}
		for (i = fifthAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				sixthAttacker = i;
				break;
			}
		}
		for (i = sixthAttacker+1; <= cNumberNonGaiaPlayers)
		{
			if (rmGetPlayerTeam(i) == 0)
			{
				seventhAttacker = i;
				break;
			}
		}

    int sizeZ = 560;
	int sizeX = 360;
	if (cNumberNonGaiaPlayers>=4)
		sizeZ = 600;
	if (cNumberNonGaiaPlayers>=6)
		sizeZ = 640;
	rmSetMapSize(sizeX, sizeZ);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original

	// Big city for 6+ players
	int bigCity = 0;
	if (cNumberNonGaiaPlayers>=4)
		bigCity = 1;
	if (cNumberNonGaiaPlayers>=6)
		bigCity = 2;


	// One vs. All - special setup for 7 players on one side
	int oneVsAll = 0;
	if (teamZeroCount>=7 || teamOneCount>=7)
		oneVsAll = 1;

	rmSetAllMapReveal(true);
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(1.0);
   
   	// LIGHT SET

	rmSetLightingSet("California_Skirmish");


	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("italy_grass_lush");
	rmTerrainInitialize("araucania\ground12_ara", 1.0);
    //rmSetSeaType(seaType);
    //rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("land");
    rmSetMapType("default");
    rmSetMapType("mediEurope");
	rmSetMapType("piratehistoricalmap");
    rmSetMapType("euroLandRiverTradeRoute");

	chooseMercs();

	// Corner constraint.
	rmSetWorldCircleConstraint(true);

   	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classHill");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("center");
	rmDefineClass("tradeIslands");
	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	int classGreatLake=rmDefineClass("great lake");
	int classDeepWater=rmDefineClass("deep lake");
	int classStartingResource = rmDefineClass("startingResource");
    int classMountains=rmDefineClass("mountains");
	int classPortSite=rmDefineClass("portSite");
	int classStreet=rmDefineClass("classStreet");
	int classCemetary=rmDefineClass("cemetary");

	// Spawn Switch
	float spawnSwitch = rmRandInt(0,1);

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
	int avoidWater25 = rmCreateTerrainDistanceConstraint("avoid water long 25", "Land", false, 25.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water long 40", "Land", false, 40.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	int avoidLandFish = rmCreateTerrainDistanceConstraint("avoid land medium fish", "Water", false, 4.0);


	// Cardinal Directions
	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

	// Player constraints
	int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0);  
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 40.0);  
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 45.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 20.0);
	int avoidTradeIslands=rmCreateClassDistanceConstraint("stay away from trade islands", rmClassID("tradeIslands"), 40.0);
	int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 2.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 4.0);
    int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  

	// Nature avoidance
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 7.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 18.0);
	int forestConstraintShort=rmCreateClassDistanceConstraint("forest vs. forest short", rmClassID("classForest"), 20.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "SPCMine", 40.0);
	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "Mine", 40.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
    int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 20.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int hillConstraint=rmCreateClassDistanceConstraint("hill vs. hill", rmClassID("classHill"), 10.0);
	int shortHillConstraint=rmCreateClassDistanceConstraint("patches vs. hill", rmClassID("classHill"), 5.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
	int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
	int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "water", false, 20.0);

	// Unit avoidance
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 45.0);
	int shortAvoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units short", rmClassID("startingUnit"), 10.0);
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 8.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
	int avoidSecrets=rmCreateClassDistanceConstraint("stuff avoids secrets", rmClassID("secrets"), 20.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 60.0);
	int avoidForester=rmCreateTypeDistanceConstraint("forester avoid forester", "zpSPCForester", 30.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "deer", 20.0);
	int mooseConstraint=rmCreateTypeDistanceConstraint("avoid the moose", "moose", 40.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
    int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 7.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 18.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 15.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int avoidBridge = rmCreateTypeDistanceConstraint("avoid bridge", "zpRuinWallSmall", 10.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 5.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpNativeWaterSpawnFlag2", 40.0);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 5.0);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "SocketCherokee", 70.0);
	int avoidMaltese=rmCreateTypeDistanceConstraint("stay away from Maltese", "zpSocketScientists", 45.0);
	int avoidJewish=rmCreateTypeDistanceConstraint("stay away from Jewish", "zpSPCSocketWesternVillage", 25.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "deSPCCommandPost", 40.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 6.0);
	int avoidTradeRouteWall = rmCreateTradeRouteDistanceConstraint("trade route wall", 4.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "deSPCCommandPost", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "deSPCCommandPost", 6.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// Additional Constraints - based on dansil original constraints
    int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);

    int classPatch = rmDefineClass("patch");
    int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 2.0);
	int avoidPlateau = rmCreateClassDistanceConstraint("avoid patch 22", rmClassID("classPlateau"), 5.0);
	int avoidStreet = rmCreateClassDistanceConstraint("avoid street", classStreet, 10.0);
	int avoidStreetShort = rmCreateClassDistanceConstraint("avoid street short", classStreet, 1.0);
	int avoidStreetZero = rmCreateClassDistanceConstraint("avoid street zero", classStreet, 0.01);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall object", "AbstractWall", 0.001);
	int avoidWallMedium=rmCreateTypeDistanceConstraint("avoid wall object medium", "AbstractWall", 2.0);
	int avoidWallLong=rmCreateTypeDistanceConstraint("avoid wall object long", "AbstractWall", 7.0);
	int avoidFence=rmCreateTypeDistanceConstraint("avoid palace fence", "zpHarbourPathBlock3", 1.00);

	int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), 1.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);
	int avoidBlockStreet =rmCreateClassDistanceConstraint("stuff vs. blocks street", rmClassID("classBlock"), 6.0);

	int cliffHeightConstraint = rmCreateMaxHeightConstraint("not too high", 7);
	int cemetaryConstraint=rmCreateClassDistanceConstraint("stay away from cemetary", classCemetary, 40.0);
	int cemetaryConstraintShort=rmCreateClassDistanceConstraint("stay away from cemetary short", classCemetary, 5.0);

    int avoidPark = rmCreateTypeDistanceConstraint("avoid park tree", "deSPCTreeCypressProp", 30);
	int avoidFixedGun = rmCreateTypeDistanceConstraint("avoid fixed gun", "zpSPCVerseillesFixedGun", 30);

    int avoidStopper = rmCreateTypeDistanceConstraint("avoid stopper", "zpSPCWaterSpawnPoint", 30);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	float playerFraction=rmAreaTilesToFraction(850);

	int cityEdgeInner =97;
    int cityEdgeOuter =0;


	// Wall placement

	int southEastWall = rmCreateGrouping("wall se", "IT_wall_se_player");
    rmSetGroupingMinDistance(southEastWall, 0.00);
    rmSetGroupingMaxDistance(southEastWall, 0.00);
	rmAddGroupingToClass(southEastWall, rmClassID("classBlock"));

	int northWestWall = rmCreateGrouping("wall nw", "IT_wall_nw_player");
    rmSetGroupingMinDistance(northWestWall, 0.00);
    rmSetGroupingMaxDistance(northWestWall, 0.00);
	rmAddGroupingToClass(northWestWall, rmClassID("classBlock"));

	rmPlaceGroupingAtLoc(southEastWall, firstDefender, 0.5+rmXMetersToFraction(4), 1.0-rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(southEastWall, firstDefender, 0.2, 1.0-rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(southEastWall, firstDefender, 0.8, 1.0-rmZTilesToFraction(cityEdgeInner+6));

	rmPlaceGroupingAtLoc(northWestWall, firstAttacker, 0.5+rmXMetersToFraction(5), 0.0+rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(northWestWall, firstAttacker, 0.2, 0.0+rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(northWestWall, firstAttacker, 0.8, 0.0+rmZTilesToFraction(cityEdgeInner+6));


    // ****************** Trade Routes **********************

    // Define Trade Route stoppers to place the other objects precisely

    // Define stoppers
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

    int stopperID2=rmCreateObjectDef("Armored Train Stopper 2");
	rmAddObjectDefItem(stopperID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID2, true);
	rmSetObjectDefMinDistance(stopperID2, 0.0);
	rmSetObjectDefMaxDistance(stopperID2, 0.0);  

	int stopperID3=rmCreateObjectDef("Armored Train Stopper 3");
	rmAddObjectDefItem(stopperID3, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID3, true);
	rmSetObjectDefMinDistance(stopperID3, 0.0);
	rmSetObjectDefMaxDistance(stopperID3, 0.0);  

    // Trade Routes

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
    rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.0, .5);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.4, .5);
    rmBuildTradeRoute(tradeRouteID, "river_trail");

    int tradeRouteID2 = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
    rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, .5);
    rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, .5);
    rmBuildTradeRoute(tradeRouteID2, "river_trail");

	int tradeRouteID3 = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID3);
	if (oneVsAll == 1)
	{
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 0.75);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 0.25);
	}
	else
	{
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 1.0);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 0.0);
	}
    rmBuildTradeRoute(tradeRouteID3, "dirt");

	vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

	vector stoperLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));

	// Define Map center
	float mapCenter = rmZMetersToFraction(xsVectorGetZ(stoperLoc));
    float mapRatio = 1.66;
	if (bigCity == 2)
		float riverCenter = mapCenter*1.74;
	else if (bigCity == 1)
		riverCenter = mapCenter*1.67;
	else
		riverCenter = mapCenter*1.56;

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

    // ************************** River ******************************

    // River must be defined before the islands are placed
    int riverID = rmRiverCreate(-1, "ZP Arno River Pond", 4, 4, 15, 15); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.0, riverCenter);
    rmRiverAddWaypoint(riverID, 1.0, riverCenter);
    rmRiverSetBankNoiseParams(riverID, 0.00, 0, 0.0, 0.0, 0.0, 0.0);
    rmRiverSetShallowRadius(riverID, 10);
    rmRiverAddShallow(riverID, 0.15);
    rmRiverAddShallow(riverID, 0.85);
	rmRiverBuild(riverID);

    vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.35);
    rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc2);

    vector socketLoc3 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.65);
    rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc3);

	vector stoperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
	vector stoperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));

    // Bridges in the center
	int bridgeGrouping = rmCreateGrouping("bridge1", "Bridge_Universal_03");
    rmSetGroupingMinDistance(bridgeGrouping, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping, 0.00);
	rmAddGroupingToClass(bridgeGrouping, rmClassID("classPlateau"));
    rmPlaceGroupingAtLoc(bridgeGrouping, 0, 0.5+rmXTilesToFraction(3), mapCenter);

	// Cardinal Constraints

	int Northward=rmCreateBoxConstraint("northMapConstraint", 0.0, 1.0, 1.0, mapCenter, 0.01);
	int Southward=rmCreateBoxConstraint("southMapConstraint", 0.0, mapCenter, 1.0, 0.0, 0.01);
	int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.0, 0.0+rmZTilesToFraction(cityEdgeOuter), 1.0, 0.0+rmZTilesToFraction(cityEdgeInner));
	int cityNorthConstraint = rmCreateBoxConstraint("stay in the city north", 0.0, 1.0-rmZTilesToFraction(cityEdgeOuter), 1.0, 1.0-rmZTilesToFraction(cityEdgeInner));
    int countrysideSouthConstraint = rmCreateBoxConstraint("stay in the countryside south", 0.0, mapCenter-rmZTilesToFraction(10), 1.0, 0.0);
    int countrysideNorthConstraint = rmCreateBoxConstraint("stay in the countryside north", 0.0, mapCenter+rmZTilesToFraction(9), 1.0, 1.0);
    int countrysideSouthConstraintFar = rmCreateBoxConstraint("stay in the countryside south far", 0.0, mapCenter-rmZTilesToFraction(14), 1.0, 0.0+rmZTilesToFraction(cityEdgeInner));
    int countrysideNorthConstraintFar = rmCreateBoxConstraint("stay in the countryside north far", 0.0, mapCenter+rmZTilesToFraction(13), 1.0, 1.0-rmZTilesToFraction(cityEdgeInner));

    int shoreLineSouth = rmCreateArea("shore South");
    rmSetAreaSize(shoreLineSouth, 0.7, 0.7);
    rmSetAreaLocation(shoreLineSouth, 0.5, 0.5-rmXTilesToFraction(55));	
    rmSetAreaCoherence(shoreLineSouth, 1.0);	
    rmSetAreaBaseHeight(shoreLineSouth, 2.1);
    rmSetAreaCliffType(shoreLineSouth, "Italian Cliff River");
    rmSetAreaCliffEdge(shoreLineSouth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineSouth, 0, 0.0, 1.0);
    rmAddAreaConstraint(shoreLineSouth , countrysideSouthConstraint);
    rmAddAreaConstraint(shoreLineSouth, avoidStopper);
    rmSetAreaObeyWorldCircleConstraint(shoreLineSouth, false);
	//rmSetAreaCliffPainting(shoreLineSouth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineSouth); 

    int shoreLineNorth = rmCreateArea("shore North");
    rmSetAreaSize(shoreLineNorth, 0.7, 0.7);
    rmSetAreaLocation(shoreLineNorth, 0.5, 0.5+rmXTilesToFraction(55));	
    rmSetAreaCoherence(shoreLineNorth, 1.0);	
    rmSetAreaBaseHeight(shoreLineNorth, 2.1);
    rmSetAreaCliffType(shoreLineNorth, "Italian Cliff River");
    rmSetAreaCliffEdge(shoreLineNorth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineNorth, 0, 0.0, 1.0);
    rmAddAreaConstraint(shoreLineNorth , countrysideNorthConstraint);
    rmAddAreaConstraint(shoreLineNorth, avoidStopper);
    rmSetAreaObeyWorldCircleConstraint(shoreLineNorth, false);
    //rmSetAreaCliffPainting(shoreLineNorth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineNorth); 

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// ************************** City Terrain ******************************

	// Streets terrain
	int citySouth = rmCreateArea("city South");
    rmSetAreaSize(citySouth, 0.7, 0.7);
    rmSetAreaLocation(citySouth, 0.5, 0.25);		
    rmSetAreaCoherence(citySouth, 1.0);	
	rmSetAreaTerrainType(citySouth, "city\ground1_cob");
    rmAddAreaConstraint(citySouth , citySouthConstraint);
    rmSetAreaObeyWorldCircleConstraint(citySouth, false);
	rmAddAreaToClass(citySouth , classStreet);
	rmAddAreaToClass(citySouth , rmClassID("classPlateau"));
    rmBuildArea(citySouth); 
   
	int cityNorth = rmCreateArea("streets North");
    rmSetAreaSize(cityNorth, 0.7, 0.7);
    rmSetAreaLocation(cityNorth, 0.5, 0.75);		
    rmSetAreaCoherence(cityNorth, 1.0);	
	rmSetAreaTerrainType(cityNorth, "city\ground1_cob");
    rmAddAreaConstraint(cityNorth , cityNorthConstraint);
    rmSetAreaObeyWorldCircleConstraint(cityNorth, false);
	rmAddAreaToClass(cityNorth , classStreet);
	rmAddAreaToClass(cityNorth , rmClassID("classPlateau"));
    rmBuildArea(cityNorth); 

	// Countryside Terrain
    int countrysideTerrainSouth = rmCreateArea("countryside South");
    rmSetAreaSize(countrysideTerrainSouth, 0.4, 0.4);
    rmSetAreaLocation(countrysideTerrainSouth, 0.5, 0.5-rmXTilesToFraction(15));	
    rmSetAreaCoherence(countrysideTerrainSouth, 1.0);	
    rmSetAreaBaseHeight(countrysideTerrainSouth, 2.1);
    rmAddAreaConstraint(countrysideTerrainSouth , countrysideSouthConstraintFar);
    rmAddAreaConstraint(countrysideTerrainSouth, avoidStopper);
	rmAddAreaConstraint(countrysideTerrainSouth, avoidWallMedium);
	rmSetAreaSmoothDistance(countrysideTerrainSouth, 10);
	rmSetAreaHeightBlend(countrysideTerrainSouth, 2);
    rmSetAreaObeyWorldCircleConstraint(countrysideTerrainSouth, false);
    rmSetAreaMix(countrysideTerrainSouth, "italy_grass_lush");
    rmBuildArea(countrysideTerrainSouth); 

    int countrysideTerrainNorth = rmCreateArea("countryside North");
    rmSetAreaSize(countrysideTerrainNorth, 0.4, 0.4);
    rmSetAreaLocation(countrysideTerrainNorth, 0.5, 0.5+rmXTilesToFraction(15));	
    rmSetAreaCoherence(countrysideTerrainNorth, 1.0);	
    rmSetAreaBaseHeight(countrysideTerrainNorth, 2.1);
    rmAddAreaConstraint(countrysideTerrainNorth, countrysideNorthConstraintFar);
    rmAddAreaConstraint(countrysideTerrainNorth, avoidStopper);
    rmAddAreaConstraint(countrysideTerrainNorth, avoidWallMedium);
    rmSetAreaSmoothDistance(countrysideTerrainNorth, 10);	
    rmSetAreaHeightBlend(countrysideTerrainNorth, 2);
    rmSetAreaObeyWorldCircleConstraint(countrysideTerrainNorth, false);
    rmSetAreaMix(countrysideTerrainNorth, "italy_grass_lush");
    rmBuildArea(countrysideTerrainNorth); 

	int elevationSouth1 = rmCreateArea("elevationSouth1");
	rmSetAreaSize(elevationSouth1, 0.05, 0.05);
	rmSetAreaLocation(elevationSouth1, 0.2, 0.5-rmXTilesToFraction(15));	
	rmSetAreaElevationType(elevationSouth1, cElevTurbulence);
    rmSetAreaElevationVariation(elevationSouth1, 5.0);
    rmSetAreaElevationPersistence(elevationSouth1, 0.2);
    rmSetAreaElevationNoiseBias(elevationSouth1, 1);
	rmSetAreaBaseHeight(elevationSouth1, 2.1);
	rmAddAreaConstraint(elevationSouth1, avoidStopper);
	rmAddAreaConstraint(elevationSouth1, avoidBlock);
	rmAddAreaConstraint(elevationSouth1, avoidTradeRoute);
	rmAddAreaConstraint(elevationSouth1, avoidWater10);
	rmAddAreaConstraint(elevationSouth1, countrysideSouthConstraintFar);
	rmSetAreaObeyWorldCircleConstraint(elevationSouth1, false);
	rmBuildArea(elevationSouth1);

	int elevationSouth2 = rmCreateArea("elevationSouth2");
	rmSetAreaSize(elevationSouth2, 0.05, 0.05);
	rmSetAreaLocation(elevationSouth2, 0.8, 0.5-rmXTilesToFraction(15));	
	rmSetAreaElevationType(elevationSouth2, cElevTurbulence);
    rmSetAreaElevationVariation(elevationSouth2, 5.0);
    rmSetAreaElevationPersistence(elevationSouth2, 0.2);
    rmSetAreaElevationNoiseBias(elevationSouth2, 1);
	rmSetAreaBaseHeight(elevationSouth2, 2.1);
	rmAddAreaConstraint(elevationSouth2, avoidStopper);
	rmAddAreaConstraint(elevationSouth2, avoidBlock);
	rmAddAreaConstraint(elevationSouth2, avoidTradeRoute);
	rmAddAreaConstraint(elevationSouth2, avoidWater10);
	rmAddAreaConstraint(elevationSouth2, countrysideSouthConstraintFar);
	rmSetAreaObeyWorldCircleConstraint(elevationSouth2, false);
	rmBuildArea(elevationSouth2);

	int elevationNorth1 = rmCreateArea("elevationNorth1");
	rmSetAreaSize(elevationNorth1, 0.05, 0.05);
	rmSetAreaLocation(elevationNorth1, 0.2, 0.5+rmXTilesToFraction(15));	
	rmSetAreaElevationType(elevationNorth1, cElevTurbulence);
    rmSetAreaElevationVariation(elevationNorth1, 5.0);
    rmSetAreaElevationPersistence(elevationNorth1, 0.2);
    rmSetAreaElevationNoiseBias(elevationNorth1, 1);
	rmSetAreaBaseHeight(elevationNorth1, 2.1);
	rmAddAreaConstraint(elevationNorth1, avoidStopper);
	rmAddAreaConstraint(elevationNorth1, avoidBlock);
	rmAddAreaConstraint(elevationNorth1, avoidTradeRoute);
	rmAddAreaConstraint(elevationNorth1, avoidWater10);
	rmAddAreaConstraint(elevationNorth1, countrysideNorthConstraintFar);
	rmSetAreaObeyWorldCircleConstraint(elevationNorth1, false);
	rmBuildArea(elevationNorth1);

	int elevationNorth2 = rmCreateArea("elevationNorth2");
	rmSetAreaSize(elevationNorth2, 0.05, 0.05);
	rmSetAreaLocation(elevationNorth2, 0.8, 0.5+rmXTilesToFraction(15));	
	rmSetAreaElevationType(elevationNorth2, cElevTurbulence);
    rmSetAreaElevationVariation(elevationNorth2, 5.0);
    rmSetAreaElevationPersistence(elevationNorth2, 0.2);
    rmSetAreaElevationNoiseBias(elevationNorth2, 1);
	rmSetAreaBaseHeight(elevationNorth2, 2.1);
	rmAddAreaConstraint(elevationNorth2, avoidStopper);
	rmAddAreaConstraint(elevationNorth2, avoidBlock);
	rmAddAreaConstraint(elevationNorth2, avoidTradeRoute);
	rmAddAreaConstraint(elevationNorth2, avoidWater10);
	rmAddAreaConstraint(elevationNorth2, countrysideNorthConstraintFar);
	rmSetAreaObeyWorldCircleConstraint(elevationNorth2, false);
	rmBuildArea(elevationNorth2);

	int gateRoad1 = rmCreateArea("gateRoad1");
    rmSetAreaSize(gateRoad1 , 0.003, 0.003);
    rmSetAreaLocation(gateRoad1 , 0.2, 0.0+rmZTilesToFraction(cityEdgeInner+5));	
	rmSetAreaMix(gateRoad1, "italy_path");
	rmAddAreaToClass(gateRoad1 , rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(gateRoad1,0.2, 0.0+rmZTilesToFraction(cityEdgeInner+5), rmXMetersToFraction(xsVectorGetX(stoperLoc2)), rmZMetersToFraction(xsVectorGetZ(stoperLoc2)));
    rmSetAreaCoherence(gateRoad1 , 0.5);
    rmBuildArea(gateRoad1 );

	int gateRoad2 = rmCreateArea("gateRoad2");
    rmSetAreaSize(gateRoad2 , 0.003, 0.003);
    rmSetAreaLocation(gateRoad2 , 0.8, 0.0+rmZTilesToFraction(cityEdgeInner+5));	
	rmSetAreaMix(gateRoad2, "italy_path");
	rmAddAreaToClass(gateRoad2 , rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(gateRoad2,0.8, 0.0+rmZTilesToFraction(cityEdgeInner+5), rmXMetersToFraction(xsVectorGetX(stoperLoc3)), rmZMetersToFraction(xsVectorGetZ(stoperLoc3)));
    rmSetAreaCoherence(gateRoad2 , 0.5);
    rmBuildArea(gateRoad2 );

	int gateRoad3 = rmCreateArea("gateRoad3");
    rmSetAreaSize(gateRoad3 , 0.003, 0.003);
    rmSetAreaLocation(gateRoad3 , 0.2, 1.0-rmZTilesToFraction(cityEdgeInner+5));	
	rmSetAreaMix(gateRoad3, "italy_path");
	rmAddAreaToClass(gateRoad3 , rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(gateRoad3,0.2, 1.0-rmZTilesToFraction(cityEdgeInner+5), rmXMetersToFraction(xsVectorGetX(stoperLoc2)), rmZMetersToFraction(xsVectorGetZ(stoperLoc2)));
    rmSetAreaCoherence(gateRoad3 , 0.5);
    rmBuildArea(gateRoad3 );

	int gateRoad4 = rmCreateArea("gateRoad4");
    rmSetAreaSize(gateRoad4 , 0.003, 0.003);
    rmSetAreaLocation(gateRoad4 , 0.8, 1.0-rmZTilesToFraction(cityEdgeInner+5));	
	rmSetAreaMix(gateRoad4, "italy_path");
	rmAddAreaToClass(gateRoad4 , rmClassID("classPlateau"));
	rmAddAreaInfluenceSegment(gateRoad4,0.8, 1.0-rmZTilesToFraction(cityEdgeInner+5), rmXMetersToFraction(xsVectorGetX(stoperLoc3)), rmZMetersToFraction(xsVectorGetZ(stoperLoc3)));
    rmSetAreaCoherence(gateRoad4 , 0.5);
    rmBuildArea(gateRoad4 );

	int southEastWallTerrain = rmCreateGrouping("wall se terrain", "IT_wall_se_terrain_player");
    rmSetGroupingMinDistance(southEastWallTerrain, 0.00);
    rmSetGroupingMaxDistance(southEastWallTerrain, 0.00);
	rmAddGroupingToClass(southEastWallTerrain, rmClassID("classBlock"));

	int northWestWallTerrain = rmCreateGrouping("wall nw terrain", "IT_wall_nw_terrain_player");
    rmSetGroupingMinDistance(northWestWallTerrain, 0.00);
    rmSetGroupingMaxDistance(northWestWallTerrain, 0.00);
	rmAddGroupingToClass(northWestWallTerrain, rmClassID("classBlock"));

	rmPlaceGroupingAtLoc(southEastWallTerrain, 0, 0.5+rmXMetersToFraction(4), 1.0-rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(southEastWallTerrain, 0, 0.2, 1.0-rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(southEastWallTerrain, 0, 0.8, 1.0-rmZTilesToFraction(cityEdgeInner+6));

	rmPlaceGroupingAtLoc(northWestWallTerrain, 0, 0.5+rmXMetersToFraction(5), 0.0+rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(northWestWallTerrain, 0, 0.2, 0.0+rmZTilesToFraction(cityEdgeInner+6));
	rmPlaceGroupingAtLoc(northWestWallTerrain, 0, 0.8, 0.0+rmZTilesToFraction(cityEdgeInner+6));

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	//===================set up grid locations===================

	// LocZ

	float locZ1 = 1.0-rmZTilesToFraction(cityEdgeInner-10);
	float locZ2 = 1.0-rmZTilesToFraction(cityEdgeInner-27);
	float locZ3 = 1.0-rmZTilesToFraction(cityEdgeInner-44);
	float locZ4 = 1.0-rmZTilesToFraction(cityEdgeInner-60);
	float locZ5 = 1.0-rmZTilesToFraction(cityEdgeInner-77);
	float locZ6 = 1.0-rmZTilesToFraction(cityEdgeInner-94);
	float locZ7 = 1.0-rmZTilesToFraction(cityEdgeInner-112);
	float locZ8 = 1.0-rmZTilesToFraction(cityEdgeInner-129);
	float locZ9 = 1.0-rmZTilesToFraction(cityEdgeInner-146);

    float locZm1 = 0.0+rmZTilesToFraction(cityEdgeInner-10);
	float locZm2 = 0.0+rmZTilesToFraction(cityEdgeInner-27);
	float locZm3 = 0.0+rmZTilesToFraction(cityEdgeInner-44);
	float locZm4 = 0.0+rmZTilesToFraction(cityEdgeInner-60);
	float locZm5 = 0.0+rmZTilesToFraction(cityEdgeInner-77);
	float locZm6 = 0.0+rmZTilesToFraction(cityEdgeInner-94);
	float locZm7 = 0.0+rmZTilesToFraction(cityEdgeInner-112);
	float locZm8 = 0.0-rmZTilesToFraction(cityEdgeInner-129);
	float locZm9 = 0.0-rmZTilesToFraction(cityEdgeInner-146);
	

	// LocX

	float locX0 = 0.94;
	float locX1 = 0.851;
	float locX2 = 0.755;
	float locX3 = 0.66;
	float locX4 = 0.57;
	float locX5 = 0.45;
	float locX6 = 0.35;
	float locX7 = 0.25;
	float locX8 = 0.15;
	float locX9 = 0.06;


	//===================define and place groupings========================

	// Unique City Groupings

	// Florence
	int blockFlorence = rmCreateGrouping("florence cathedral", "IT_SPC_Florence");
    rmSetGroupingMinDistance(blockFlorence, 0.00);
    rmSetGroupingMaxDistance(blockFlorence, 0.50);
	rmAddGroupingToClass(blockFlorence, rmClassID("classBlock"));

    // Rome
	int blockRome = rmCreateGrouping("rome cathedral", "IT_SPC_Rome");
    rmSetGroupingMinDistance(blockRome, 0.00);
    rmSetGroupingMaxDistance(blockRome, 0.50);
	rmAddGroupingToClass(blockRome, rmClassID("classBlock"));

    int florencePlacement1 = rmPlaceGroupingInstanceAtLoc(blockFlorence, 0.61, 1.0-rmZTilesToFraction(cityEdgeInner-36), 0);
    int romePlacement1 = rmPlaceGroupingInstanceAtLoc(blockRome, 0.4, 0.0+rmZTilesToFraction(cityEdgeInner-36), 0);

    // Define Blocks

	// Market
	int blockMarket = rmCreateGrouping("market", "IT_Resource_Block_All2");
    rmSetGroupingMinDistance(blockMarket, 0.00);
    rmSetGroupingMaxDistance(blockMarket, 0.50);
	rmAddGroupingToClass(blockMarket, rmClassID("classBlock"));

	// Bank
	int blockBank = rmCreateGrouping("bank", "IT_Resource_Block_Gold1");
    rmSetGroupingMinDistance(blockBank, 0.00);
    rmSetGroupingMaxDistance(blockBank, 0.50);
	rmAddGroupingToClass(blockBank, rmClassID("classBlock"));

	// Jesuit natives
	int blockJesuit = rmCreateGrouping("jesuit natives", "IT_Native_Block_Jesuit");
    rmSetGroupingMinDistance(blockJesuit, 0.00);
    rmSetGroupingMaxDistance(blockJesuit, 0.50);
	rmAddGroupingToClass(blockJesuit, rmClassID("classBlock"));

    // Maltese natives
	int blockMaltese = rmCreateGrouping("maltese natives", "IT_Native_Block_Maltese");
    rmSetGroupingMinDistance(blockMaltese, 0.00);
    rmSetGroupingMaxDistance(blockMaltese, 0.50);
	rmAddGroupingToClass(blockMaltese, rmClassID("classBlock"));

    // Auditore natives
	int blockAuditore = rmCreateGrouping("Auditore natives", "IT_Native_Block_Auditore");
    rmSetGroupingMinDistance(blockAuditore, 0.00);
    rmSetGroupingMaxDistance(blockAuditore, 0.50);
	rmAddGroupingToClass(blockAuditore, rmClassID("classBlock"));

	// Factory
	int blockFactory = rmCreateGrouping("Factory", "IT_Resource_Block_All1");
    rmSetGroupingMinDistance(blockFactory, 0.00);
    rmSetGroupingMaxDistance(blockFactory, 0.50);
	rmAddGroupingToClass(blockFactory, rmClassID("classBlock"));

	// Mill
	int blockMill = rmCreateGrouping("Mill", "IT_Resource_Block_Food1");
    rmSetGroupingMinDistance(blockMill, 0.00);
    rmSetGroupingMaxDistance(blockMill, 0.50);
	rmAddGroupingToClass(blockMill, rmClassID("classBlock"));

	// Warehouse
	int blockWarehouse = rmCreateGrouping("Warehouse", "IT_Resource_Block_Wood1");
    rmSetGroupingMinDistance(blockWarehouse, 0.00);
    rmSetGroupingMaxDistance(blockWarehouse, 0.50);
	rmAddGroupingToClass(blockWarehouse, rmClassID("classBlock"));

	// Lombard
    int blockLombard = rmCreateGrouping("Lombard", "IT_House_Block_Lombard");
    rmSetGroupingMinDistance(blockLombard, 0.00);
    rmSetGroupingMaxDistance(blockLombard, 0.50);
	rmAddGroupingToClass(blockLombard, rmClassID("classBlock"));
    
    // Trade Post
    int blockTrade = rmCreateGrouping("Trade", "IT_SPC_Block_Trade");
    rmSetGroupingMinDistance(blockTrade, 0.00);
    rmSetGroupingMaxDistance(blockTrade, 0.50);
	rmAddGroupingToClass(blockTrade, rmClassID("classBlock"));

    // Treasures
    int blockTreasure01 = rmCreateGrouping("Treasure1", "IT_House_Block_Treasure01");
    rmSetGroupingMinDistance(blockTreasure01, 0.00);
    rmSetGroupingMaxDistance(blockTreasure01, 0.50);
	rmAddGroupingToClass(blockTreasure01, rmClassID("classBlock"));

	int blockTreasure02 = rmCreateGrouping("Treasure2", "IT_House_Block_Treasure02");
    rmSetGroupingMinDistance(blockTreasure02, 0.00);
    rmSetGroupingMaxDistance(blockTreasure02, 0.50);
	rmAddGroupingToClass(blockTreasure02, rmClassID("classBlock"));

    // Park
    int blockPark = rmCreateGrouping("park", "IT_House_Block_Park");
    rmSetGroupingMinDistance(blockPark, 0.00);
    rmSetGroupingMaxDistance(blockPark, 0.50);
	rmAddGroupingToClass(blockPark, rmClassID("classBlock"));

	// Menagerie
    int blockMenagerie = rmCreateGrouping("Menagerie", "IT_Resource_Block_Menager");
    rmSetGroupingMinDistance(blockMenagerie, 0.00);
    rmSetGroupingMaxDistance(blockMenagerie, 0.50);
	rmAddGroupingToClass(blockMenagerie, rmClassID("classBlock"));

    // Italian Castle Rome
    int blockCastello = rmCreateGrouping("Castello", "IT_SPC_Castello");
    rmSetGroupingMinDistance(blockCastello, 0.00);
    rmSetGroupingMaxDistance(blockCastello, 0.50);
	rmAddGroupingToClass(blockCastello, rmClassID("classBlock"));

	// Italian Castle Florence
    int blockCastello2 = rmCreateGrouping("Castello 2", "IT_SPC_Castello2");
    rmSetGroupingMinDistance(blockCastello2, 0.00);
    rmSetGroupingMaxDistance(blockCastello2, 0.50);
	rmAddGroupingToClass(blockCastello2, rmClassID("classBlock"));

	// Construction
    int blockConstruction = rmCreateGrouping("Construction", "IT_SPC_Block_Constr");
    rmSetGroupingMinDistance(blockConstruction, 0.00);
    rmSetGroupingMaxDistance(blockConstruction, 0.50);
	rmAddGroupingToClass(blockConstruction, rmClassID("classBlock"));

    // House Blocks
	int blockHouse01 = rmCreateGrouping("house1", "IT_House_Block_01");
    rmSetGroupingMinDistance(blockHouse01, 0.00);
    rmSetGroupingMaxDistance(blockHouse01, 0.50);
	rmAddGroupingToClass(blockHouse01, rmClassID("classBlock"));

	int blockHouse02 = rmCreateGrouping("house2", "IT_House_Block_02");
    rmSetGroupingMinDistance(blockHouse02, 0.00);
    rmSetGroupingMaxDistance(blockHouse02, 0.50);
	rmAddGroupingToClass(blockHouse02, rmClassID("classBlock"));

	int blockHouse03 = rmCreateGrouping("house3", "IT_House_Block_03");
    rmSetGroupingMinDistance(blockHouse03, 0.00);
    rmSetGroupingMaxDistance(blockHouse03, 0.50);
	rmAddGroupingToClass(blockHouse03, rmClassID("classBlock"));

	int blockHouse04 = rmCreateGrouping("house4", "IT_House_Block_04");
    rmSetGroupingMinDistance(blockHouse04, 0.00);
    rmSetGroupingMaxDistance(blockHouse04, 0.50);
	rmAddGroupingToClass(blockHouse04, rmClassID("classBlock"));

	int blockHouse05 = rmCreateGrouping("house5", "IT_House_Block_05");
    rmSetGroupingMinDistance(blockHouse05, 0.00);
    rmSetGroupingMaxDistance(blockHouse05, 0.50);
	rmAddGroupingToClass(blockHouse05, rmClassID("classBlock"));

	int blockHouse06 = rmCreateGrouping("house6", "IT_House_Block_06");
    rmSetGroupingMinDistance(blockHouse06, 0.00);
    rmSetGroupingMaxDistance(blockHouse06, 0.50);
	rmAddGroupingToClass(blockHouse06, rmClassID("classBlock"));

    // Place Groupings

    rmPlaceGroupingAtLoc(blockMarket, 0, locX5, locZ2);
    rmPlaceGroupingAtLoc(blockMarket, 0, locX4, locZm2);

    rmPlaceGroupingAtLoc(blockBank, 0, locX6, locZ3);
    rmPlaceGroupingAtLoc(blockBank, 0, locX3, locZm3);

    rmPlaceGroupingAtLoc(blockJesuit, 0, locX6, locZ1);
    rmPlaceGroupingAtLoc(blockJesuit, 0, locX3, locZm1);

    rmPlaceGroupingAtLoc(blockMaltese, 0, locX3, locZ1);
    rmPlaceGroupingAtLoc(blockMaltese, 0, locX6, locZm1);

    rmPlaceGroupingAtLoc(blockAuditore, 0, locX2, locZ2);
    rmPlaceGroupingAtLoc(blockAuditore, 0, locX7, locZm2);

	if (teamOneCount >= 2 && oneVsAll == 0)
	rmPlaceGroupingAtLoc(blockAuditore, 0, locX4, locZ4);
	if (teamZeroCount >= 2 && oneVsAll == 0)
	rmPlaceGroupingAtLoc(blockAuditore, 0, locX5, locZm4);

    rmSetNuggetDifficulty(305, 305);
	int factoryPlacement1 = rmPlaceGroupingInstanceAtLoc(blockFactory, locX7, locZ2, 0);
	int factoryPlacement2 = rmPlaceGroupingInstanceAtLoc(blockFactory, locX2, locZm2, 0);

    rmPlaceGroupingAtLoc(blockMill, 0, locX2, locZ3,);
    rmPlaceGroupingAtLoc(blockMill, 0, locX7, locZm3);

    rmPlaceGroupingAtLoc(blockWarehouse, 0, locX7, locZ1);
    rmPlaceGroupingAtLoc(blockWarehouse, 0, locX2, locZm1);

    rmPlaceGroupingAtLoc(blockTrade, 0, locX4, locZ1);
    rmPlaceGroupingAtLoc(blockTrade, 0, locX4, locZm1);

	rmSetNuggetDifficulty(304, 304);
	if (oneVsAll == 0)
	{
		rmPlaceGroupingAtLoc(blockTrade, 0, locX4, locZ5);
		rmPlaceGroupingAtLoc(blockTrade, 0, locX4, locZm5);
		rmPlaceGroupingAtLoc(blockLombard, 0, locX5, locZ5);
		rmPlaceGroupingAtLoc(blockLombard, 0, locX5, locZm5);
	}

    rmSetNuggetDifficulty(303, 303);
    rmPlaceGroupingAtLoc(blockTreasure01, 0, locX2, locZ1);
    rmPlaceGroupingAtLoc(blockTreasure01, 0, locX7, locZm1);

	rmPlaceGroupingAtLoc(blockTreasure02, 0, locX7, locZ3);
    rmPlaceGroupingAtLoc(blockTreasure02, 0, locX2, locZm3);

    rmPlaceGroupingAtLoc(blockCastello2, firstDefender, locX5, locZ3);
    rmPlaceGroupingAtLoc(blockCastello, firstAttacker, locX4, locZm3);

    rmPlaceGroupingAtLoc(blockPark, 0, locX5, locZ1);
    rmPlaceGroupingAtLoc(blockPark, 0, locX5, locZm1);

    rmSetNuggetDifficulty(98, 98);
	int menageriePlacement1 = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX6, locZ2, 0);
	int menageriePlacement2 = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX3, locZm2, 0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	//==============================================================
	//roda player placement
	//==============================================================

	if (cNumberTeams == 2){
		if (teamOneCount == 1)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ2);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX7, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZ4);
		}
		if (teamZeroCount == 1)				
		{	
			rmPlacePlayer(firstAttacker, locX1, locZm2);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX2, locZm4);
		}
		if (teamOneCount == 2)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ2);
			rmPlacePlayer(secondDefender, locX0, locZ2);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX2, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX7, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZ4);
		}
		if (teamZeroCount == 2)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm2);
			rmPlacePlayer(secondAttacker, locX1, locZm2);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX7, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX2, locZm4);
		}
		if (teamOneCount == 3)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ2);
			rmPlacePlayer(secondDefender, locX0, locZ2);
			rmPlacePlayer(thirdDefender, locX2, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX7, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX5, locZ5);
		}
		if (teamZeroCount == 3)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm2);
			rmPlacePlayer(secondAttacker, locX1, locZm2);
			rmPlacePlayer(thirdAttacker, locX7, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX5, locZm5);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX2, locZm4);
		}
		if (teamOneCount == 4)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ2);
			rmPlacePlayer(secondDefender, locX0, locZ2);
			rmPlacePlayer(thirdDefender, locX2, locZ4);
			rmPlacePlayer(fourthDefender, locX6, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX9, locZ1);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZ4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZ1);
		}
		if (teamZeroCount == 4)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm2);
			rmPlacePlayer(secondAttacker, locX1, locZm2);
			rmPlacePlayer(thirdAttacker, locX7, locZm4);
			rmPlacePlayer(fourthAttacker, locX3, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX9, locZm1);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZm4);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZm1);
		}
		if (teamOneCount == 5)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ1);
			rmPlacePlayer(secondDefender, locX0, locZ1);
			rmPlacePlayer(thirdDefender, locX2, locZ4);
			rmPlacePlayer(fourthDefender, locX6, locZ4);
			rmPlacePlayer(fifthDefender, locX8, locZ3);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZ3);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX1, locZ3);
		}
		if (teamZeroCount == 5)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm1);
			rmPlacePlayer(secondAttacker, locX1, locZm1);
			rmPlacePlayer(thirdAttacker, locX7, locZm4);
			rmPlacePlayer(fourthAttacker, locX3, locZm4);
			rmPlacePlayer(fifthAttacker, locX1, locZm3);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX8, locZm3);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX9, locZm3);
		}
		if (teamOneCount == 6)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ1);
			rmPlacePlayer(secondDefender, locX0, locZ1);
			rmPlacePlayer(thirdDefender, locX2, locZ4);
			rmPlacePlayer(fourthDefender, locX6, locZ4);
			rmPlacePlayer(fifthDefender, locX8, locZ3);
			rmPlacePlayer(sixthDefender, locX0, locZ3);
		}
		if (teamZeroCount == 6)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm1);
			rmPlacePlayer(secondAttacker, locX1, locZm1);
			rmPlacePlayer(thirdAttacker, locX7, locZm4);
			rmPlacePlayer(fourthAttacker, locX3, locZm4);
			rmPlacePlayer(fifthAttacker, locX1, locZm3);
			rmPlacePlayer(sixthAttacker, locX9, locZm3);
		}
		if (teamOneCount == 7)				
		{	
			rmPlacePlayer(firstDefender, locX8, locZ1);
			rmPlacePlayer(secondDefender, locX0, locZ1);
			rmPlacePlayer(thirdDefender, locX2, locZ4);
			rmPlacePlayer(fourthDefender, locX6, locZ4);
			rmPlacePlayer(fifthDefender, locX8, locZ3);
			rmPlacePlayer(sixthDefender, locX0, locZ3);
			rmPlacePlayer(seventhDefender, locX4, locZ4);
		}
		if (teamZeroCount == 7)				
		{	
			rmPlacePlayer(firstAttacker, locX9, locZm1);
			rmPlacePlayer(secondAttacker, locX1, locZm1);
			rmPlacePlayer(thirdAttacker, locX7, locZm4);
			rmPlacePlayer(fourthAttacker, locX3, locZm4);
			rmPlacePlayer(fifthAttacker, locX1, locZm3);
			rmPlacePlayer(sixthAttacker, locX9, locZm3);
			rmPlacePlayer(seventhAttacker, locX5, locZm4);
		}
	}

	// Player Blocks

	int blockPlayerStart = rmCreateGrouping("blockPlayerStart", "IT_SPC_PlayerStart");
    rmSetGroupingMinDistance(blockPlayerStart, 0.00);
    rmSetGroupingMaxDistance(blockPlayerStart, 0.50);
	rmAddGroupingToClass(blockPlayerStart, rmClassID("classBlock"));

	int blockPlayerStartMalta = rmCreateGrouping("blockPlayerStartMalta", "IT_SPC_PlayerStartMaltese");
    rmSetGroupingMinDistance(blockPlayerStartMalta, 0.00);
    rmSetGroupingMaxDistance(blockPlayerStartMalta, 0.50);
	rmAddGroupingToClass(blockPlayerStartMalta, rmClassID("classBlock"));

	int blockPlayerGold = rmCreateGrouping("blockPlayerGold", "IT_SPC_PlayerGold");
    rmSetGroupingMinDistance(blockPlayerGold, 0.00);
    rmSetGroupingMaxDistance(blockPlayerGold, 0.50);
	rmAddGroupingToClass(blockPlayerGold, rmClassID("classBlock"));

	int blockPlayerFood = rmCreateGrouping("blockPlayerFood", "IT_SPC_PlayerFood");
    rmSetGroupingMinDistance(blockPlayerFood, 0.00);
    rmSetGroupingMaxDistance(blockPlayerFood, 0.50);
	rmAddGroupingToClass(blockPlayerFood, rmClassID("classBlock"));

	int blockPlayerWood = rmCreateGrouping("blockPlayerWood", "IT_SPC_PlayerWood");
    rmSetGroupingMinDistance(blockPlayerWood, 0.00);
    rmSetGroupingMaxDistance(blockPlayerWood, 0.50);
	rmAddGroupingToClass(blockPlayerWood, rmClassID("classBlock"));

	//place tcs

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);
	rmSetNuggetDifficulty(1, 1);

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);
    
    for(i=1; <= cNumberNonGaiaPlayers) {
			int id=rmCreateArea("Player"+i);
			rmSetPlayerArea(i, id);
			if (rmGetPlayerCiv(i) == rmGetCivID("DEMaltese"))
				rmPlaceGroupingAtLoc(blockPlayerStartMalta, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			else
			rmPlaceGroupingAtLoc(blockPlayerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			if (rmGetPlayerTeam(i) == 0) {
				rmPlaceGroupingAtLoc(blockPlayerFood, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)-rmZTilesToFraction(17));
				rmPlaceGroupingAtLoc(blockPlayerGold, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(17), rmPlayerLocZFraction(i));
				rmPlaceGroupingAtLoc(blockPlayerWood, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(17), rmPlayerLocZFraction(i)-rmZTilesToFraction(17));
			}
			else {
				rmPlaceGroupingAtLoc(blockPlayerFood, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)+rmZTilesToFraction(17));
				rmPlaceGroupingAtLoc(blockPlayerGold, i, rmPlayerLocXFraction(i)-rmXTilesToFraction(17), rmPlayerLocZFraction(i));
				rmPlaceGroupingAtLoc(blockPlayerWood, i, rmPlayerLocXFraction(i)-rmXTilesToFraction(17), rmPlayerLocZFraction(i)+rmZTilesToFraction(17));
			}
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// ****************** Filler Houses ***********************

	// North City

	//first row
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX0, locZ1);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX1, locZ1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX2, locZ1);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZ1);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZ1);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZ1);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX6, locZ1);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX7, locZ1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZ1);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX9, locZ1);

	//second row

	rmPlaceGroupingAtLoc(blockHouse05, 0, locX0, locZ2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX1, locZ2);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZ2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZ2);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZ2);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX6, locZ2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZ2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX8, locZ2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX9, locZ2);

	//third row

	rmPlaceGroupingAtLoc(blockHouse03, 0, locX0, locZ3);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX1, locZ3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX2, locZ3);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX3, locZ3);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZ3);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX5, locZ3);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX6, locZ3);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX7, locZ3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX8, locZ3);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX9, locZ3);

	//fourth row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX1, locZ4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX2, locZ4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX3, locZ4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX4, locZ4);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX5, locZ4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX6, locZ4);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX7, locZ4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZ4);

	//fifth row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZ5);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZ5);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ5);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZ5);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX6, locZ5);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZ5);

// South City

	//first row
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX0, locZm1);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX1, locZm1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX2, locZm1);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZm1);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZm1);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZm1);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX6, locZm1);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX7, locZm1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZm1);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX9, locZm1);

	//second row

	rmPlaceGroupingAtLoc(blockHouse05, 0, locX0, locZm2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX1, locZm2);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZm2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZm2);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZm2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZm2);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX6, locZm2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZm2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX8, locZm2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX9, locZm2);

	//third row

	rmPlaceGroupingAtLoc(blockHouse03, 0, locX0, locZm3);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX1, locZm3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX2, locZm3);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX3, locZm3);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZm3);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX5, locZm3);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX6, locZm3);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX7, locZm3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX8, locZm3);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX9, locZm3);

	//fourth row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX1, locZm4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX2, locZm4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX3, locZm4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX4, locZm4);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX5, locZm4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX6, locZm4);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX7, locZm4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZm4);

	//fifth row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZm5);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZm5);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZm5);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZm5);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX6, locZm5);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZm5);

	// Back Forests

	int backForestNorth1=rmCreateArea("back forest north 1");
	rmSetAreaSize(backForestNorth1, 0.038, 0.038);
	rmSetAreaForestType(backForestNorth1, "Italian Forest");
	rmSetAreaForestDensity(backForestNorth1, 0.7);
	rmSetAreaForestClumpiness(backForestNorth1, 0.4);
	rmSetAreaForestUnderbrush(backForestNorth1, 0.0);
	rmSetAreaCoherence(backForestNorth1, 1.0);
	rmSetAreaMix(backForestNorth1, "italy_grass_lush");
	rmAddAreaToClass(backForestNorth1, rmClassID("classForest")); 
	rmAddAreaConstraint(backForestNorth1, avoidBlockStreet);
	rmAddAreaConstraint(backForestNorth1, avoidTradeRouteMin);
	rmSetAreaObeyWorldCircleConstraint(backForestNorth1, false);
	rmSetAreaLocation(backForestNorth1, locX1, locZ5);		
	rmBuildArea(backForestNorth1);

	int backForestNorth2=rmCreateArea("back forest north 2");
	rmSetAreaSize(backForestNorth2, 0.038, 0.038);
	rmSetAreaForestType(backForestNorth2, "Italian Forest");
	rmSetAreaForestDensity(backForestNorth2, 0.7);
	rmSetAreaForestClumpiness(backForestNorth2, 0.4);
	rmSetAreaForestUnderbrush(backForestNorth2, 0.0);
	rmSetAreaCoherence(backForestNorth2, 1.0);
	rmSetAreaMix(backForestNorth2, "italy_grass_lush");
	rmAddAreaToClass(backForestNorth2, rmClassID("classForest")); 
	rmAddAreaConstraint(backForestNorth2, avoidBlockStreet);
	rmAddAreaConstraint(backForestNorth2, avoidTradeRouteMin);
	rmSetAreaObeyWorldCircleConstraint(backForestNorth2, false);
	rmSetAreaLocation(backForestNorth2, locX8, locZ5);		
	rmBuildArea(backForestNorth2);

	int backForestSouth1=rmCreateArea("back forest south 1");
	rmSetAreaSize(backForestSouth1, 0.038, 0.038);
	rmSetAreaForestType(backForestSouth1, "Italian Forest");
	rmSetAreaForestDensity(backForestSouth1, 0.7);
	rmSetAreaForestClumpiness(backForestSouth1, 0.4);
	rmSetAreaForestUnderbrush(backForestSouth1, 0.0);
	rmSetAreaCoherence(backForestSouth1, 1.0);
	rmSetAreaMix(backForestSouth1, "italy_grass_lush");
	rmAddAreaToClass(backForestSouth1, rmClassID("classForest")); 
	rmAddAreaConstraint(backForestSouth1, avoidBlockStreet);
	rmAddAreaConstraint(backForestSouth1, avoidTradeRouteMin);
	rmSetAreaObeyWorldCircleConstraint(backForestSouth1, false);
	rmSetAreaLocation(backForestSouth1, locX1, locZm5);		
	rmBuildArea(backForestSouth1);

	int backForestSouth2=rmCreateArea("back forest south 2");
	rmSetAreaSize(backForestSouth2, 0.038, 0.038);
	rmSetAreaForestType(backForestSouth2, "Italian Forest");
	rmSetAreaForestDensity(backForestSouth2, 0.7);
	rmSetAreaForestClumpiness(backForestSouth2, 0.4);
	rmSetAreaForestUnderbrush(backForestSouth2, 0.0);
	rmSetAreaCoherence(backForestSouth2, 1.0);
	rmSetAreaMix(backForestSouth2, "italy_grass_lush");
	rmAddAreaToClass(backForestSouth2, rmClassID("classForest")); 
	rmAddAreaConstraint(backForestSouth2, avoidBlockStreet);
	rmAddAreaConstraint(backForestSouth2, avoidTradeRouteMin);
	rmSetAreaObeyWorldCircleConstraint(backForestSouth2, false);
	rmSetAreaLocation(backForestSouth2, locX8, locZm5);		
	rmBuildArea(backForestSouth2);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	// City Hill Cliff
	for (j=0; < 8) {   
		int wallCliffs = rmCreateArea("wallCliffs"+j);
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(240), rmAreaTilesToFraction(240));
		rmSetAreaObeyWorldCircleConstraint(wallCliffs, false);
		rmAddAreaToClass(wallCliffs, rmClassID("classPlateau"));
		rmAddAreaConstraint(wallCliffs, avoidPlateauShort);
		rmAddAreaConstraint(wallCliffs, avoidTradeRouteWall);
		rmAddAreaConstraint(wallCliffs, avoidWall);
		rmSetAreaCliffType(wallCliffs, "Italian Cliff");
		rmAddAreaToClass(wallCliffs , classMountains);
		rmSetAreaCliffEdge(wallCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaObeyWorldCircleConstraint(wallCliffs, false);
		rmSetAreaCliffHeight(wallCliffs, 0, 0, 0.5);
		rmSetAreaBaseHeight(wallCliffs, 8.0);
		rmSetAreaHeightBlend(wallCliffs, 3);
		rmSetAreaCoherence(wallCliffs, .93);
		if (j == 0){
		rmSetAreaLocation(wallCliffs, 0.05, 1.0-rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 1){
		rmSetAreaLocation(wallCliffs, 0.95, 1.0-rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 2){
		rmSetAreaLocation(wallCliffs, 0.65, 1.0-rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 3){
		rmSetAreaLocation(wallCliffs, 0.35, 1.0-rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 4){
		rmSetAreaLocation(wallCliffs, 0.05, 0.0+rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 5){
		rmSetAreaLocation(wallCliffs, 0.65, 0.0+rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 6){
		rmSetAreaLocation(wallCliffs, 0.365, 0.0+rmZTilesToFraction(cityEdgeInner+3));
		}
		if (j == 7){
		rmSetAreaLocation(wallCliffs, 0.95, 0.0+rmZTilesToFraction(cityEdgeInner+3));
		}
		rmBuildArea(wallCliffs);  
	}

	// ****************** Trade Route Sockets *******************************

	int socketID=rmCreateObjectDef("TR Socket");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0);
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

	int socketID2=rmCreateObjectDef("TR Socket 2");
	rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID2, true);
	rmSetObjectDefMinDistance(socketID2, 2.0);
	rmSetObjectDefMaxDistance(socketID2, 8.0);
	rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);

	rmPlaceObjectDefAtLoc(socketID, 0, 0.28, 0.5+rmXTilesToFraction(8));
	rmPlaceObjectDefAtLoc(socketID, 0, 0.4, 0.5-rmXTilesToFraction(8));
	rmPlaceObjectDefAtLoc(socketID2, 0, 0.6, 0.5+rmXTilesToFraction(8));
	rmPlaceObjectDefAtLoc(socketID2, 0, 0.72, 0.5-rmXTilesToFraction(8));

	// Scattered FORESTS
	int forestTreeID = 0;
	if (bigCity == 2)
		int numTries=24;
	else if (bigCity == 1)
		numTries=18;
	else
		numTries=12;
	int failCount=0;
	for (i=0; <numTries)
		{   
			int forest=rmCreateArea("forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest, "Italian Forest");
		rmSetAreaForestDensity(forest, 0.9);
		rmSetAreaForestClumpiness(forest, 0.4);
		rmSetAreaForestUnderbrush(forest, 0.0);
		rmSetAreaCoherence(forest, 0.4);
		rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		rmAddAreaConstraint(forest, forestConstraintShort);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest, avoidPlateau);
		rmAddAreaConstraint(forest, avoidTradeRouteMin);
		rmAddAreaConstraint(forest, avoidWallLong);
		rmAddAreaConstraint(forest, avoidWater4);
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

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidSilver);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(randomGoldID, avoidWallMedium);
	rmAddObjectDefConstraint(randomGoldID, avoidPlateauShort);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmPlaceObjectDefInArea(randomGoldID, 0, countrysideTerrainNorth, 2+cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomGoldID, 0, countrysideTerrainSouth, 2+cNumberNonGaiaPlayers);

	// Deers
	int deerID=rmCreateObjectDef("deer herd");
	rmAddObjectDefItem(deerID, "ypIbex", rmRandInt(8,10), 10.0);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
	rmAddObjectDefConstraint(deerID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerID, shortDeerConstraint);
	rmAddObjectDefConstraint(deerID, avoidPlateauShort);
	rmSetObjectDefCreateHerd(deerID, true);
	rmPlaceObjectDefInArea(deerID, 0, countrysideTerrainNorth, 2+cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(deerID, 0, countrysideTerrainSouth, 2+cNumberNonGaiaPlayers/2);

	// Nuggets
	int nuggetEasy= rmCreateObjectDef("nugget easy countryside"); 
	rmAddObjectDefItem(nuggetEasy, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 3);
	rmAddObjectDefConstraint(nuggetEasy, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetEasy, avoidNugget);
	rmAddObjectDefConstraint(nuggetEasy, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetEasy, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetEasy, avoidPlateauShort);
	rmAddObjectDefConstraint(nuggetEasy, avoidMountains);
	rmAddObjectDefConstraint(nuggetEasy, avoidStreetZero);
	rmAddObjectDefConstraint(nuggetEasy, avoidTradeSocket);
	rmAddObjectDefConstraint(nuggetEasy, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetEasy, 0, countrysideTerrainNorth, 2+cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(nuggetEasy, 0, countrysideTerrainSouth, 2+cNumberNonGaiaPlayers/2);

	int nuggetHard= rmCreateObjectDef("nugget hard countryside"); 
	rmAddObjectDefItem(nuggetHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmAddObjectDefConstraint(nuggetHard, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHard, avoidAll);
    rmAddObjectDefConstraint(nuggetHard, avoidPark);
	rmAddObjectDefConstraint(nuggetHard, avoidNugget);
	rmAddObjectDefConstraint(nuggetHard, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHard, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHard, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHard, avoidFixedGun);
	rmAddObjectDefConstraint(nuggetHard, avoidTradeRouteFar);
	rmAddObjectDefConstraint(nuggetHard, avoidTradeSocket);
	rmAddObjectDefConstraint(nuggetHard, avoidPlateauShort);
	rmPlaceObjectDefInArea(nuggetHard, 0, countrysideTerrainNorth, 2);
	rmPlaceObjectDefInArea(nuggetHard, 0, countrysideTerrainSouth, 2);

	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, "fishCod", 1, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, avoidLandFish);
	rmAddObjectDefConstraint(fishID, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 25);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.90);

	// ____________________ LOCAL MERCENARIES ____________________
	rmDisableDefaultMercs(true);
	rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercSwissPikeman", -1);
	rmEnableMerc("MercLandsknecht", -1);
	rmEnableMerc("MercElmeti", -1);
	rmEnableMerc("MercGreatCannon", -1);
	rmEnableMerc("deMercCannoneer", -1);
	rmEnableMerc("deMercPistoleer", -1);

	rmForbidTradeMonopoly(true);

	// ____________________ MAP OBJECTIVES ____________________
    // _________________ Map Objectives ______________________________
	rmObjectiveScreenSetTitle(302391);
	rmObjectiveScreenSetGoal(302392);
	rmObjectiveAdd(302402, 302406, true, true, true); // DEFEND OBJECTIVE ROME
	rmObjectiveSetTeam(1, 1);
	rmObjectiveAdd(302404, 302406, true, true, true); // DEFEND OBJECTIVE FLORENTINE
	rmObjectiveSetTeam(2, 2);
	rmObjectiveAdd(302403, 302406, true, true, true); // ATTACK OBJECTIVE ROME
	rmObjectiveSetTeam(3, 1);
	rmObjectiveAdd(302405, 302406, true, true, true); // ATTACK OBJECTIVE FLORENTINE
	rmObjectiveSetTeam(4, 2);

	// ************************* TRIGGERS ******************************

	//----- DEFINE VARIABLES -----

	int factoryBuilding1 = rmGetGroupingInstanceUnitByType(factoryPlacement1, "zpSPCCapturableFactoryFlorence");
	int factoryNugget1 = rmGetGroupingInstanceUnitByType(factoryPlacement1, "zpNuggetInvisible");
	int factoryBuilding2 = rmGetGroupingInstanceUnitByType(factoryPlacement2, "zpSPCCapturableFactoryFlorence");
	int factoryNugget2 = rmGetGroupingInstanceUnitByType(factoryPlacement2, "zpNuggetInvisible");

	int menagerieBuilding1 = rmGetGroupingInstanceUnitByType(menageriePlacement1, "zpSPCMenagerie");
	int menagerieNugget1 = rmGetGroupingInstanceUnitByType(menageriePlacement1, "zpNuggetInvisible");
	int menagerieBuilding2 = rmGetGroupingInstanceUnitByType(menageriePlacement2, "zpSPCMenagerie");
	int menagerieNugget2 = rmGetGroupingInstanceUnitByType(menageriePlacement2, "zpNuggetInvisible");

	int menagerieBuildingMod1 = menagerieBuilding1+1;
	int menagerieBuildingMod2 = menagerieBuilding2+1;
	int menagerieNuggetMod1 = menagerieNugget1+1;
	int menagerieNuggetMod2 = menagerieNugget2+1;
	int factoryBuildingMod1 = factoryBuilding1+1;
	int factoryBuildingMod2 = factoryBuilding2+1;
	int factoryNuggetMod1 = factoryNugget1+1;
	int factoryNuggetMod2 = factoryNugget2+1;
	
	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Europen Map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID", i);
        rmSetTriggerEffectParam("TechID","cTechzpSPCFlorenceSetup"); // Map Setup
        rmSetTriggerEffectParamInt("Status", 2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Set up default resource values
	rmCreateTrigger("Starting Resources");
	rmAddTriggerEffect("Modify Protounit Resource");
	rmSetTriggerEffectParam("ProtoUnit","deMineCoalBuildable");
	rmSetTriggerEffectParam("Resource","Gold");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParamInt("Field",2);
	rmSetTriggerEffectParamFloat("Delta",1*cNumberNonGaiaPlayers);
	rmSetTriggerEffectParamInt("Relativity",3);
	rmAddTriggerEffect("Modify Protounit Resource");
	rmSetTriggerEffectParam("ProtoUnit","zpValuableSource");
	rmSetTriggerEffectParam("Resource","Gold");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParamInt("Field",2);
	rmSetTriggerEffectParamFloat("Delta",1*cNumberNonGaiaPlayers);
	rmSetTriggerEffectParamInt("Relativity",3);
	rmAddTriggerEffect("Modify Protounit Resource");
	rmSetTriggerEffectParam("ProtoUnit","zpGrapeBush");
	rmSetTriggerEffectParam("Resource","Food");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParamInt("Field",2);
	rmSetTriggerEffectParamFloat("Delta",1*cNumberNonGaiaPlayers);
	rmSetTriggerEffectParamInt("Relativity",3);
	rmAddTriggerEffect("Modify Protounit Resource");
	rmSetTriggerEffectParam("ProtoUnit","zpTreeRubble");
	rmSetTriggerEffectParam("Resource","Wood");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParamInt("Field",2);
	rmSetTriggerEffectParamFloat("Delta",1*cNumberNonGaiaPlayers);
	rmSetTriggerEffectParamInt("Relativity",3);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	// Resource Building Convert
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+menagerieBuildingMod1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+menagerieBuildingMod2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+factoryBuildingMod1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+factoryBuildingMod2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+menagerieNuggetMod1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+menagerieBuildingMod1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+factoryNuggetMod1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+factoryBuildingMod1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+menagerieNuggetMod2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+menagerieBuildingMod2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+factoryNuggetMod2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+factoryBuildingMod2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ----- Victory Conditions -----
	rmCreateTrigger("Victory_Defenders");
	rmCreateTrigger("Victory_Attackers");

	rmSwitchToTrigger(rmTriggerID("Victory_Defenders"));
	rmAddTriggerCondition("Team Unit Count");
	rmSetTriggerConditionParamInt("TeamID",1);
	rmSetTriggerConditionParam("Protounit","zpItalianFort");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Team Unit Count");
	rmSetTriggerConditionParamInt("TeamID",2);
	rmSetTriggerConditionParam("Protounit","zpItalianFortB");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Team Victory");
	rmSetTriggerEffectParamInt("TeamID", 2);
	rmSetTriggerPriority(1); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Victory_Attackers"));
	rmAddTriggerCondition("Team Unit Count");
	rmSetTriggerConditionParamInt("TeamID",2);
	rmSetTriggerConditionParam("Protounit","zpItalianFortB");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Team Unit Count");
	rmSetTriggerConditionParamInt("TeamID",1);
	rmSetTriggerConditionParam("Protounit","zpItalianFort");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Team Victory");
	rmSetTriggerEffectParamInt("TeamID", 1);
	rmSetTriggerPriority(1); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	//  ----- NATIVE POLITICIANS -----

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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
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
	malteseFraction = rmRandInt(1,2);

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
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}



	//================we will add the other 4 rows after the groupings are defined and the randomizer is working=========

	rmSetStatusText("",0.99);
    
	
} // END