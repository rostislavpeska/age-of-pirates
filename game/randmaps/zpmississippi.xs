// MISSISSIPPI
// February 2024

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
		subCiv0=rmGetCivID("zpscientists");
		rmEchoInfo("subCiv0 is mzpscientists "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpscientists");

		subCiv1=rmGetCivID("zpwesternvillage");
		rmEchoInfo("subCiv1 is zpwesternvillage "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zpwesternvillage");
  
		subCiv2=rmGetCivID("cherokee");
		rmEchoInfo("subCiv2 is cherokee "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "cherokee");
	}

    // Picks the map size
	int playerTiles = 18000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 15000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 13000;			

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);
   
   	// LIGHT SET

	rmSetLightingSet("Ozarks_Skirmish");


	// Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("nwt_grass2");
	rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
	rmSetMapType("bayou");
	rmSetMapType("grass");
	rmSetMapType("water");

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
	int classGreatLake=rmDefineClass("great lake");
	int classDeepWater=rmDefineClass("deep lake");
	int classStartingResource = rmDefineClass("startingResource");
    int classMountains=rmDefineClass("mountains");
	int classPortSite=rmDefineClass("portSite");

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	


	// Cardinal Directions
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
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
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 30.0);
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
	int avoidNuggets=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 60.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "deer", 20.0);
	int mooseConstraint=rmCreateTypeDistanceConstraint("avoid the moose", "moose", 40.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
    int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 5.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 15.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int avoidBridge = rmCreateTypeDistanceConstraint("avoid bridge", "zpRuinWallSmall", 20.0);

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
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// Text
	rmSetStatusText("",0.10);


   	float playerFraction=rmAreaTilesToFraction(850);

	//Trade Route
	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0); 

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

	int stopperID4=rmCreateObjectDef("Armored Train Stopper 4");
	rmAddObjectDefItem(stopperID4, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID4, true);
	rmSetObjectDefMinDistance(stopperID4, 0.0);
	rmSetObjectDefMaxDistance(stopperID4, 0.0);  

	int stopperID5=rmCreateObjectDef("Armored Train Stopper 5");
	rmAddObjectDefItem(stopperID5, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID5, true);
	rmSetObjectDefMinDistance(stopperID5, 0.0);
	rmSetObjectDefMaxDistance(stopperID5, 0.0);  

	int stopperID6=rmCreateObjectDef("Armored Train Stopper 6");
	rmAddObjectDefItem(stopperID6, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID6, true);
	rmSetObjectDefMinDistance(stopperID6, 0.0);
	rmSetObjectDefMaxDistance(stopperID6, 0.0);  

	int stopperID7=rmCreateObjectDef("Armored Train Stopper 7");
	rmAddObjectDefItem(stopperID7, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID7, true);
	rmSetObjectDefMinDistance(stopperID7, 0.0);
	rmSetObjectDefMaxDistance(stopperID7, 0.0);  

	int stopperID8=rmCreateObjectDef("Armored Train Stopper 8");
	rmAddObjectDefItem(stopperID8, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID8, true);
	rmSetObjectDefMinDistance(stopperID8, 0.0);
	rmSetObjectDefMaxDistance(stopperID8, 0.0); 

	int stopperID9=rmCreateObjectDef("Armored Train Stopper 9");
	rmAddObjectDefItem(stopperID9, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID9, true);
	rmSetObjectDefMinDistance(stopperID9, 0.0);
	rmSetObjectDefMaxDistance(stopperID9, 0.0); 

    int stopperID00=rmCreateObjectDef("Armored Train Stopper 00");
	rmAddObjectDefItem(stopperID00, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID00, true);
	rmSetObjectDefMinDistance(stopperID00, 0.0);
	rmSetObjectDefMaxDistance(stopperID00, 0.0);  

    int stopperID01=rmCreateObjectDef("Armored Train Stopper 01");
	rmAddObjectDefItem(stopperID01, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID01, true);
	rmSetObjectDefMinDistance(stopperID01, 0.0);
	rmSetObjectDefMaxDistance(stopperID01, 0.0);  

	int stationGrouping01 = -1;
    //stationGrouping01 = rmCreateGrouping("station grouping 01", "Railway_Station_Big_SW"); 
	stationGrouping01 = rmCreateGrouping("station grouping 01", "Railway_Station_Big_SW_nostation"); // for independent Train station
	rmSetGroupingMinDistance(stationGrouping01, 0.0);
	rmSetGroupingMaxDistance (stationGrouping01, 0.0);

	int stationGrouping02 = -1;
    stationGrouping02 = rmCreateGrouping("station grouping 02", "Railway_Station_Big_SE_nostation");
	rmSetGroupingMinDistance(stationGrouping02, 0.0);
	rmSetGroupingMaxDistance (stationGrouping02, 0.0);

	int stationGrouping03 = -1;
    stationGrouping03 = rmCreateGrouping("station grouping 03", "Railway_Station_Big_N_nostation");
	rmSetGroupingMinDistance(stationGrouping03, 0.0);
	rmSetGroupingMaxDistance (stationGrouping03, 0.0);

	int stationGrouping04 = -1;
    stationGrouping04 = rmCreateGrouping("station grouping 04", "Railway_Station_Big_E_nostation");
	rmSetGroupingMinDistance(stationGrouping04, 0.0);
	rmSetGroupingMaxDistance (stationGrouping04, 1.0);

	int stationGrouping001 = -1;
    stationGrouping001 = rmCreateGrouping("station 01", "Railway_Station_Big_SW_stationA"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping001, 0.0);
	rmSetGroupingMaxDistance (stationGrouping001, 0.0);

	int stationGrouping002 = -1;
    stationGrouping002 = rmCreateGrouping("station 02", "Railway_Station_Big_SW_stationB"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping002, 0.0);
	rmSetGroupingMaxDistance (stationGrouping002, 0.0);

	int stationGrouping003 = -1;
    stationGrouping003 = rmCreateGrouping("station 03", "Railway_Station_Big_SE_stationA"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping003, 0.0);
	rmSetGroupingMaxDistance (stationGrouping003, 0.0);

	int stationGrouping004 = -1;
    stationGrouping004 = rmCreateGrouping("station 04", "Railway_Station_Big_SE_stationB"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping004, 0.0);
	rmSetGroupingMaxDistance (stationGrouping004, 0.0);

	int stationGrouping005 = -1;
    stationGrouping005 = rmCreateGrouping("station 05", "Railway_Station_Big_N_stationA"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping005, 0.0);
	rmSetGroupingMaxDistance (stationGrouping005, 0.0);

	int stationGrouping006 = -1;
    stationGrouping006 = rmCreateGrouping("station 06", "Railway_Station_Big_N_stationB"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping006, 0.0);
	rmSetGroupingMaxDistance (stationGrouping006, 0.0);

	int stationGrouping007 = -1;
    stationGrouping007 = rmCreateGrouping("station 07", "Railway_Station_Big_E_stationA"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping007, 0.0);
	rmSetGroupingMaxDistance (stationGrouping007, 0.0);

	int stationGrouping008 = -1;
    stationGrouping008 = rmCreateGrouping("station 08", "Railway_Station_Big_E_stationB"); // Independent Train Station
	rmSetGroupingMinDistance(stationGrouping008, 0.0);
	rmSetGroupingMaxDistance (stationGrouping008, 0.0);

    int stationGrouping00 = -1;
    stationGrouping00 = rmCreateGrouping("station 00", "Invisible_Grouping"); // Invisible Stoper 0
	rmSetGroupingMinDistance(stationGrouping00, 0.0);
	rmSetGroupingMaxDistance (stationGrouping00, 0.0);

	if (rmGetIsKOTH())
	{
		// **** KotH Setup ****


		// Trade Route 1

		int tradeRouteID = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
		
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.0);

		rmBuildTradeRoute(tradeRouteID, "dirt");

		int deadSeaLakeID=rmCreateArea("Dead Sea Lake Shallow");
		rmSetAreaWaterType(deadSeaLakeID, "ZP Mississippi River");
		if (cNumberNonGaiaPlayers <= 2)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(3850.0), rmAreaTilesToFraction(3850.0));
		if (cNumberNonGaiaPlayers == 3)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(4450.0), rmAreaTilesToFraction(4450.0));
		if (cNumberNonGaiaPlayers == 4)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(5450.0), rmAreaTilesToFraction(5450.0));
		if (cNumberNonGaiaPlayers == 5)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(5750.0), rmAreaTilesToFraction(5750.0));
		if (cNumberNonGaiaPlayers == 6)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(5950.0), rmAreaTilesToFraction(5950.0));
		if (cNumberNonGaiaPlayers == 7)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(6350.0), rmAreaTilesToFraction(6350.0));
		if (cNumberNonGaiaPlayers == 8)
			rmSetAreaSize(deadSeaLakeID, rmAreaTilesToFraction(6650.0), rmAreaTilesToFraction(6650.0));
		rmSetAreaCoherence(deadSeaLakeID, 1.0);
		rmSetAreaLocation(deadSeaLakeID, 0.5, 0.9);
		rmSetAreaObeyWorldCircleConstraint(deadSeaLakeID, false);
		rmAddAreaInfluenceSegment(deadSeaLakeID, 0.5, 1.0, 0.5, 0.75);
		rmBuildArea(deadSeaLakeID); 

		vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(stopperID9, 0, socketLoc1);
		vector StopperLoc9 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID9, 0));

		int bridgeSite0 = rmCreateArea ("bridge site 0");
		rmSetAreaSize(bridgeSite0, rmAreaTilesToFraction(1250.0), rmAreaTilesToFraction(1250.0));
		rmSetAreaLocation(bridgeSite0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		rmSetAreaMix(bridgeSite0, "nwt_grass2");
		rmSetAreaCoherence(bridgeSite0, 1);
		rmSetAreaSmoothDistance(bridgeSite0, 20);
		rmSetAreaBaseHeight(bridgeSite0, 0.5);
		rmAddAreaToClass(bridgeSite0, classPortSite);
		rmAddAreaInfluenceSegment(bridgeSite0, 0.5, rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+14), 0.5, rmZMetersToFraction(xsVectorGetZ(StopperLoc9)-14));
		rmSetAreaObeyWorldCircleConstraint(bridgeSite0, false);
		rmBuildArea(bridgeSite0);

		// North Bank

		if (cNumberNonGaiaPlayers >=3){
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.66);
			rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
			vector StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		}

		if (cNumberNonGaiaPlayers >=7){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.72);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			vector StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));


			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.81);
			rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc1);
			vector StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));

		}

		if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		}

		if (cNumberNonGaiaPlayers >=3){
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.89);
			rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
			vector StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		}

		// South Bank

		if (cNumberNonGaiaPlayers >=4){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.11);
			rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
			vector StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		}

		if (cNumberNonGaiaPlayers ==8){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.19);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			vector StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.28);
			rmPlaceObjectDefAtPoint(stopperID7, 0, socketLoc1);
			vector StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		}

		if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==6 || cNumberNonGaiaPlayers ==7){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		}
		
		if (cNumberNonGaiaPlayers >=4){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.34);
			rmPlaceObjectDefAtPoint(stopperID8, 0, socketLoc1);
			vector StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}

		// Koth Station

		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));

		int tradeRouteID2 = rmCreateTradeRoute();		
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.2, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.2, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.0);

		rmBuildTradeRoute(tradeRouteID2, "armored_train");

		int tradeRouteID3 = rmCreateTradeRoute();
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.2, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.2, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.8, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.8, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.65, 0.0);

		rmBuildTradeRoute(tradeRouteID3, "armored_train");
	}

	else
	{
	
	// **** No Koth ****

		// Trade Route 1

		tradeRouteID = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
		
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 1.0);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.0);

		rmBuildTradeRoute(tradeRouteID, "dirt");


			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);
			rmPlaceObjectDefAtPoint(stopperID00, 0, socketLoc1);
			vector StopperLoc00 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID00, 0));
			rmPlaceGroupingAtLoc(stationGrouping00, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc00)), rmZMetersToFraction(xsVectorGetZ(StopperLoc00)));


		if (cNumberNonGaiaPlayers >=3){
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
			rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
			StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		}

		if (cNumberNonGaiaPlayers >=7){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.43);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));


			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.57);
			rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc1);
			StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));

		}

		if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		}

		if (cNumberNonGaiaPlayers >=3){
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
			rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
			StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		}

		tradeRouteID2 = rmCreateTradeRoute();
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 1.0);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.65, 0.0);

		rmBuildTradeRoute(tradeRouteID2, "armored_train");

		// Trade Route 2

		tradeRouteID3 = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(stopperID5, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID6, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID7, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID8, tradeRouteID3);

		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.2, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.2, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.35, 1.0);

		rmBuildTradeRoute(tradeRouteID3, "dirt");

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.1);
		rmPlaceObjectDefAtPoint(stopperID01, 0, socketLoc1);
		vector StopperLoc001 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID01, 0));
		rmPlaceGroupingAtLoc(stationGrouping00, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc001)), rmZMetersToFraction(xsVectorGetZ(StopperLoc001)));

		if (cNumberNonGaiaPlayers >=4){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.24);
			rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
			StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
			rmPlaceGroupingAtLoc(stationGrouping006, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		}

		if (cNumberNonGaiaPlayers ==8){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.43);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping002, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.57);
			rmPlaceObjectDefAtPoint(stopperID7, 0, socketLoc1);
			StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
			rmPlaceGroupingAtLoc(stationGrouping002, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		}

		if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==6 || cNumberNonGaiaPlayers ==7){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.50);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping002, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		}
		
		if (cNumberNonGaiaPlayers >=4){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.73);
			rmPlaceObjectDefAtPoint(stopperID8, 0, socketLoc1);
			StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
			rmPlaceGroupingAtLoc(stationGrouping008, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}

		int tradeRouteID4 = rmCreateTradeRoute();
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.35, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.35, 0.2);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.2, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.2, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.35, 0.8);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.35, 1.0);

		rmBuildTradeRoute(tradeRouteID4, "armored_train");	
	}

	// Text
	rmSetStatusText("",0.20);

	// River

	if (cNumberNonGaiaPlayers <=2)	
		int riverID = rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 18, 18); //  (-1, "new england lake", 18, 14, 5, 5)
	else	
		riverID = rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 20, 20); //  (-1, "new england lake", 18, 14, 5, 5)
	if (rmGetIsKOTH()){
		rmRiverAddWaypoint(riverID, 0.5, 0.75);
		rmRiverAddWaypoint(riverID, 0.55, 0.55); 
		rmRiverAddWaypoint(riverID, 0.45, 0.45);
		rmRiverAddWaypoint(riverID, 0.5, 0.2);
		rmRiverAddWaypoint(riverID, 0.5, 0.0);
	}
	else {	
		rmRiverAddWaypoint(riverID, 0.5, 1.0);
		rmRiverAddWaypoint(riverID, 0.5, 0.8);
		rmRiverAddWaypoint(riverID, 0.55, 0.55); 
		rmRiverAddWaypoint(riverID, 0.45, 0.45);
		rmRiverAddWaypoint(riverID, 0.5, 0.2);
		rmRiverAddWaypoint(riverID, 0.5, 0.0);
		rmRiverSetBankNoiseParams(riverID, 0.00, 0, 0.0, 0.0, 0.0, 0.0);
		rmRiverSetShallowRadius(riverID, 10);
		rmRiverAddShallow(riverID, 0.05);
	}
	rmRiverBuild(riverID);

    // Renegades

	int scientistControllerID = rmCreateObjectDef("scientist controller 1");
	rmAddObjectDefItem(scientistControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(scientistControllerID, 0.0);
	rmSetObjectDefMaxDistance(scientistControllerID, 0.0);
	rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.45-rmXTilesToFraction(26),0.45+rmXTilesToFraction(13));
	vector scientistControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID, 0));

	int scientistControllerID2 = rmCreateObjectDef("scientist controller 2");
	rmAddObjectDefItem(scientistControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(scientistControllerID2, 0.0);
	rmSetObjectDefMaxDistance(scientistControllerID2, 0.0);
	rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.55+rmXTilesToFraction(25), 0.55-rmXTilesToFraction(14));
	vector scientistControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID2, 0));

	int maltese1VillageTypeID = rmRandInt(5,6);
	int maltese1ID = -1;
	maltese1ID = rmCreateGrouping("maltese 1", "Scientist_Lab06");
	rmSetGroupingMinDistance(maltese1ID, 0);
	rmSetGroupingMaxDistance(maltese1ID, 0);
	

	int maltese2VillageTypeID = 11-maltese1VillageTypeID;
	int maltese2ID = -1;
	maltese2ID = rmCreateGrouping("maltese 2", "Scientist_Lab05");
	rmSetGroupingMinDistance(maltese2ID, 0);
	rmSetGroupingMaxDistance(maltese2ID, 0);

	rmPlaceGroupingAtLoc(maltese1ID, 0, 0.45-rmXTilesToFraction(25),0.45+rmXTilesToFraction(13));
	rmPlaceGroupingAtLoc(maltese2ID, 0, 0.55+rmXTilesToFraction(24), 0.55-rmXTilesToFraction(14));

	int nativewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
	rmAddObjectDefItem(nativewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage1 = rmFindClosestPointVector(scientistControllerLoc1 , rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(nativewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

	rmClearClosestPointConstraints();

	int pirateportID1 = -1;
	pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport02");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage1a = rmFindClosestPointVector(scientistControllerLoc1, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

	rmClearClosestPointConstraints();

	int nativewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
	rmAddObjectDefItem(nativewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage2 = rmFindClosestPointVector(scientistControllerLoc2 , rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(nativewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

	rmClearClosestPointConstraints();

	int pirateportID2 = -1;
	pirateportID2 = rmCreateGrouping("pirate port 1", "pirateport02");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage2a = rmFindClosestPointVector(scientistControllerLoc2, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

	rmClearClosestPointConstraints();

	// Water Trade Route
	
	int tradeRouteID5 = rmCreateTradeRoute();
	if (cNumberNonGaiaPlayers <= 6){
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5-rmXTilesToFraction(15), 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5-rmXTilesToFraction(15), 0.4+rmXTilesToFraction(15));
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6-rmXTilesToFraction(15));
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6);
	}
	else{
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(5), 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5-rmXTilesToFraction(5), 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5-rmXTilesToFraction(15), 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5-rmXTilesToFraction(15), 0.4+rmXTilesToFraction(15));
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6-rmXTilesToFraction(15));
	rmAddTradeRouteWaypoint(tradeRouteID5, 0.5+rmXTilesToFraction(15), 0.6);
    }

	rmBuildTradeRoute(tradeRouteID5, "native_water_trail");

	int portSite1 = rmCreateArea ("port_site1");
	rmSetAreaSize(portSite1, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
	rmSetAreaLocation(portSite1, 0.55-rmXTilesToFraction(30), 0.55+rmXTilesToFraction(13));
	rmSetAreaMix(portSite1, "nwt_grass2");
	rmSetAreaCoherence(portSite1, 1);
	rmSetAreaSmoothDistance(portSite1, 20);
	rmSetAreaBaseHeight(portSite1, 0.5);
	rmAddAreaToClass(portSite1, classPortSite);
	rmBuildArea(portSite1);


	int portSite2 = rmCreateArea ("port_site2");
	rmSetAreaSize(portSite2, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
	rmSetAreaLocation(portSite2, 0.45+rmXTilesToFraction(28),0.45-rmXTilesToFraction(12));
	rmSetAreaMix(portSite2, "nwt_grass2");
	rmSetAreaCoherence(portSite2, 1);
	rmSetAreaSmoothDistance(portSite2, 20);
	rmSetAreaBaseHeight(portSite2, 0.5);
	rmAddAreaToClass(portSite2, classPortSite);
	rmBuildArea(portSite2);

	// Port 1
	int portID01 = rmCreateObjectDef("port 02");
	portID01 = rmCreateGrouping("portG 01", "Harbour_Center_River_NE");
	rmPlaceGroupingAtLoc(portID01, 0, 0.55-rmXTilesToFraction(23), 0.55+rmXTilesToFraction(13));

	// Port 2
	int portID02 = rmCreateObjectDef("port 02");
	portID02 = rmCreateGrouping("portG 02", "Harbour_Center_River_SW");
	rmPlaceGroupingAtLoc(portID02, 0, 0.45+rmXTilesToFraction(20),0.45-rmXTilesToFraction(12));

	// Text
	rmSetStatusText("",0.30);


	// Western Village

	int jewish1VillageTypeID = rmRandInt(1, 5);
	int jewish2VillageTypeID = rmRandInt(1, 5);

	int jewish1ID = rmCreateGrouping("jewish 1", "WildWest_Village_East_0"+jewish1VillageTypeID);
	int jewish2ID = rmCreateGrouping("jewish 2", "WildWest_Village_East_0"+jewish2VillageTypeID);

	rmSetGroupingMinDistance(jewish1ID, 0);
	rmSetGroupingMaxDistance(jewish1ID, 50);
	rmSetGroupingMinDistance(jewish2ID, 0);
	rmSetGroupingMaxDistance(jewish2ID, 50);

    rmAddGroupingConstraint(jewish1ID, avoidWater30);
	rmAddGroupingConstraint(jewish1ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(jewish1ID, avoidMaltese);
    rmAddGroupingConstraint(jewish1ID, avoidImpassableLand);
    rmAddGroupingConstraint(jewish2ID, avoidWater30);
	rmAddGroupingConstraint(jewish2ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(jewish2ID, avoidMaltese);
    rmAddGroupingConstraint(jewish2ID, avoidImpassableLand);

    rmPlaceGroupingAtLoc(jewish1ID, 0, 0.4, 0.4, 1);
    rmPlaceGroupingAtLoc(jewish2ID, 0, 0.6, 0.6, 1);

	// Text
	rmSetStatusText("",0.30);

	// Mountain Terrain

	int westMountain=rmCreateArea("italy mountains"); 
    rmSetAreaSize(westMountain, 0.08, 0.08);
    rmSetAreaLocation(westMountain, 0.05, 0.5);
    rmSetAreaCoherence(westMountain, 0.6);
    rmSetAreaSmoothDistance(westMountain, 5);
    rmSetAreaCliffType(westMountain, "Araucania Central Ozarks");
    rmSetAreaCliffEdge(westMountain, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(westMountain, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(westMountain, 4.0);
    rmSetAreaObeyWorldCircleConstraint(westMountain, false);
    rmSetAreaElevationType(westMountain, cElevTurbulence);
    rmSetAreaElevationVariation(westMountain, 3.0);
    rmSetAreaElevationPersistence(westMountain, 0.2);
    rmSetAreaElevationNoiseBias(westMountain, 1);
    rmAddAreaInfluenceSegment(westMountain, 0.1, 0.8, 0.0, 0.5);
    rmAddAreaInfluenceSegment(westMountain, 0.1, 0.2, 0.0, 0.5);
	rmAddAreaConstraint(westMountain, avoidTradeSocketShort);
	rmAddAreaConstraint(westMountain, avoidTradeRouteFar);
    rmAddAreaToClass(westMountain, classMountains);
    rmBuildArea(westMountain);

    int westMountainTerrain=rmCreateArea("italy mountains terrain"); 
    rmSetAreaSize(westMountainTerrain, 0.08, 0.08);
    rmSetAreaLocation(westMountainTerrain, 0.05, 0.5);
    rmSetAreaCoherence(westMountainTerrain, 0.6);
    rmSetAreaMix(westMountainTerrain, "nwt_grass1");
    rmSetAreaObeyWorldCircleConstraint(westMountainTerrain, false);
    rmAddAreaInfluenceSegment(westMountainTerrain, 0.1, 0.8, 0.0, 0.5);
    rmAddAreaInfluenceSegment(westMountainTerrain, 0.1, 0.2, 0.0, 0.5);
    rmBuildArea(westMountainTerrain);

    int eastMountain=rmCreateArea("balkan mountains"); 
    rmSetAreaSize(eastMountain, 0.08, 0.08);
    rmSetAreaLocation(eastMountain, 0.95, 0.5);
    rmSetAreaCoherence(eastMountain, 0.6);
    rmSetAreaSmoothDistance(eastMountain, 5);
    rmSetAreaCliffType(eastMountain, "Araucania Central Ozarks");
    rmSetAreaCliffEdge(eastMountain, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(eastMountain, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(eastMountain, 4.0);
    rmSetAreaObeyWorldCircleConstraint(eastMountain, false);
    rmSetAreaElevationType(eastMountain, cElevTurbulence);
    rmSetAreaElevationVariation(eastMountain, 3.0);
    rmSetAreaElevationPersistence(eastMountain, 0.2);
    rmSetAreaElevationNoiseBias(eastMountain, 1);
	rmAddAreaConstraint(eastMountain, avoidTradeSocketShort);
	rmAddAreaConstraint(eastMountain, avoidTradeRouteFar);
    rmAddAreaInfluenceSegment(eastMountain, 0.9, 0.8, 1.0, 0.5);
    rmAddAreaInfluenceSegment(eastMountain, 0.9, 0.2, 1.0, 0.5);
    rmAddAreaToClass(eastMountain, classMountains);
    rmBuildArea(eastMountain);

    int eastMountainTerrain=rmCreateArea("balkan mountains terrain"); 
    rmSetAreaSize(eastMountainTerrain, 0.08, 0.08);
    rmSetAreaLocation(eastMountainTerrain, 0.95, 0.5);
    rmSetAreaCoherence(eastMountainTerrain, 0.6);
    rmSetAreaMix(eastMountainTerrain, "nwt_grass1");
    rmSetAreaObeyWorldCircleConstraint(eastMountainTerrain, false);
    rmAddAreaInfluenceSegment(eastMountainTerrain, 0.9, 0.8, 1.0, 0.5);
    rmAddAreaInfluenceSegment(eastMountainTerrain, 0.9, 0.2, 1.0, 0.5);
    rmBuildArea(eastMountainTerrain);

    int eastMountainsConstraint=rmCreateAreaConstraint("east island mountains", eastMountain);
    int westMountainsConstraint=rmCreateAreaConstraint("west Island mountains", westMountain);

	// Cherokee Villages

    int sufi1VillageTypeID = rmRandInt(1,5);
	int mosque1ID = -1;
	mosque1ID = rmCreateGrouping("mosque 1", "native cherokee village "+sufi1VillageTypeID);
	rmSetGroupingMinDistance(mosque1ID, 20);
	rmSetGroupingMaxDistance(mosque1ID, rmXFractionToMeters(0.2));
	rmAddGroupingConstraint(mosque1ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque1ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque1ID, circleConstraint);
	rmAddGroupingConstraint(mosque1ID, avoidSufi);
	rmPlaceGroupingInArea(mosque1ID, 0, westMountain, 1);


	int sufi2VillageTypeID = rmRandInt(1,5);
	int mosque2ID = -1;
	mosque2ID = rmCreateGrouping("mosque 2", "native cherokee village "+sufi2VillageTypeID);
	rmSetGroupingMinDistance(mosque2ID, 20);
	rmSetGroupingMaxDistance(mosque2ID, rmXFractionToMeters(0.2));
	rmAddGroupingConstraint(mosque2ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque2ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque2ID, avoidSufi);
	rmAddGroupingConstraint(mosque2ID, circleConstraint);
	rmPlaceGroupingInArea(mosque2ID, 0, eastMountain, 1);


	if(cNumberNonGaiaPlayers >= 6){
		int sufi3VillageTypeID = rmRandInt(1,5);
		int mosque3ID = -1;
		mosque3ID = rmCreateGrouping("Sufi Village 3", "native cherokee village "+sufi3VillageTypeID);
		rmSetGroupingMinDistance(mosque3ID, 20);
		rmSetGroupingMaxDistance(mosque3ID, rmXFractionToMeters(0.2));
		rmAddGroupingConstraint(mosque3ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque3ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque3ID, circleConstraint);
		rmAddGroupingConstraint(mosque3ID, avoidSufi);
		rmPlaceGroupingInArea(mosque3ID, 0, westMountain, 1);

		int sufi4VillageTypeID = rmRandInt(1,5);
		int mosque4ID = -1;
		mosque4ID = rmCreateGrouping("Sufi Village 4", "native cherokee village "+sufi4VillageTypeID);
		rmSetGroupingMinDistance(mosque4ID, 20);
		rmSetGroupingMaxDistance(mosque4ID, rmXFractionToMeters(0.2));
		rmAddGroupingConstraint(mosque4ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque4ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque4ID, circleConstraint);
		rmAddGroupingConstraint(mosque4ID, avoidSufi);
		rmPlaceGroupingInArea(mosque4ID, 0, eastMountain, 1);
	}

	// Text
	rmSetStatusText("",0.40);

	// Place Players

	float teamStartLoc = rmRandFloat(0.0, 1.0);

	if (cNumberNonGaiaPlayers <= 2){
		rmSetPlacementSection(0.25, 0.745); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.3, 0.3, 0);
		}

	if (cNumberNonGaiaPlayers == 3){
		rmPlacePlayer(1, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmXMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlacePlayer(2, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmXMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlacePlayer(3, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmXMetersToFraction(xsVectorGetZ(StopperLoc6)));
		}

	// 4 players in 2 teams
	if (cNumberNonGaiaPlayers == 4){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.625, 0.870);
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.625, 0.870); 
			rmPlacePlayersCircular(0.3, 0.3, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
		}
		else{
		rmSetPlacementSection(0.125, 0.870); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.32, 0.32, 0);
		}
	}

	if (cNumberNonGaiaPlayers == 5){
		rmPlacePlayer(1, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmXMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlacePlayer(2, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmXMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlacePlayer(3, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmXMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlacePlayer(4, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmXMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlacePlayer(5, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmXMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}

	if (cNumberNonGaiaPlayers == 6){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.625, 0.870);
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.625, 0.870); 
			rmPlacePlayersCircular(0.3, 0.3, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
		}
		else{
		rmPlacePlayer(1, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmXMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlacePlayer(2, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmXMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlacePlayer(3, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmXMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlacePlayer(4, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmXMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlacePlayer(5, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmXMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlacePlayer(6, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmXMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}
	}

	if (cNumberNonGaiaPlayers == 7){
		rmPlacePlayer(1, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmXMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlacePlayer(2, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmXMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlacePlayer(3, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmXMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlacePlayer(4, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmXMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlacePlayer(5, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmXMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlacePlayer(6, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmXMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlacePlayer(7, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmXMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}

	if (cNumberNonGaiaPlayers == 8){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.625, 0.870);
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.625, 0.870); 
			rmPlacePlayersCircular(0.3, 0.3, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.125, 0.370); 
			rmPlacePlayersCircular(0.32, 0.32, 0);
			}
		}
		else{
		rmPlacePlayer(1, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmXMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlacePlayer(2, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmXMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlacePlayer(3, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmXMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlacePlayer(4, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmXMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlacePlayer(5, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmXMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlacePlayer(6, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmXMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlacePlayer(7, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmXMetersToFraction(xsVectorGetZ(StopperLoc7)));
		rmPlacePlayer(8, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmXMetersToFraction(xsVectorGetZ(StopperLoc8)));
		}
	}


	// Define Player Objects

	int TCID = rmCreateObjectDef("player TC");
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	if (rmGetNomadStart())
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
	else
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	rmAddObjectDefToClass(TCID, classStartingResource);
	rmAddObjectDefConstraint(TCID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(TCID, avoidTrainStationA);
	rmAddObjectDefConstraint(TCID, avoidTrainStationB);
	rmAddObjectDefConstraint(TCID, avoidJewish);
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmSetObjectDefMinDistance(TCID, 10.0);
	rmSetObjectDefMaxDistance(TCID, 17.0);

	// Starting mines
	int playerGoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerGoldID, "Mine", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 20.0);
	rmAddObjectDefToClass(playerGoldID, classStartingResource);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerGoldID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerGoldID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerGoldID, longPlayerEdgeConstraint);

	// Starting Trees
	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "TreeCarolinaGrass", 15, 8.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 25);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, rmClassID("classForest"));
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerTreeID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerTreeID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerTreeID, longPlayerEdgeConstraint);

	// Starting herds
	int playerHerdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerHerdID, "turkey", 14, 4.0);
	rmSetObjectDefMinDistance(playerHerdID, 12);
	rmSetObjectDefMaxDistance(playerHerdID, 12);
	rmSetObjectDefCreateHerd(playerHerdID, true);
	rmAddObjectDefToClass(playerHerdID, classStartingResource);		
	rmAddObjectDefConstraint(playerHerdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerHerdID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerHerdID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerHerdID, longPlayerEdgeConstraint);

	// Starting treasures
	int playerNuggetID = rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(playerNuggetID, 24.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 26.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerNuggetID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerNuggetID, longPlayerEdgeConstraint);

	// Water Flag
    int colonyShipID = 0;

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

	// Place TC
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

	// Place Player Objects
	for(i=1; <numPlayer)
	{
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
		
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		
		// Water Flag Placement
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
		rmAddClosestPointConstraint(flagVsVenice1);
		rmAddClosestPointConstraint(flagVsVenice2);
		rmAddClosestPointConstraint(flagLand);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

		rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));

    }

	rmClearClosestPointConstraints();

	// Text
	rmSetStatusText("",0.50);

	// Define North and South Directions

	int southBank=rmCreateArea("south bank");
	rmSetAreaCoherence(southBank, 1.0);
	rmAddAreaConstraint(southBank, avoidWater20);
	rmSetAreaObeyWorldCircleConstraint(southBank, false);
	rmSetAreaSize(southBank, 0.3, 0.3);
	rmSetAreaLocation(southBank, 0.2, 0.5);
	rmBuildArea(southBank);

	int northBank=rmCreateArea("north bank");
	rmSetAreaCoherence(northBank, 1.0);
	rmAddAreaConstraint(northBank, avoidWater20);
	rmSetAreaObeyWorldCircleConstraint(northBank, false);
	rmSetAreaSize(northBank, 0.3, 0.3);
	rmSetAreaLocation(northBank, 0.8, 0.5);
	rmBuildArea(northBank);

	int southConstraint=rmCreateAreaConstraint("south constraint", southBank);
	int northConstraint=rmCreateAreaConstraint("north constraint", northBank);

	// KotH
	if (rmGetIsKOTH())
	{

	int bridgeID = -1;

	if (cNumberNonGaiaPlayers<=3){
		bridgeID = rmCreateGrouping("mississippi bridge", "mississippi_bridge_02");
		rmPlaceGroupingAtLoc(bridgeID, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+41), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+5));
		rmPlaceGroupingAtLoc(bridgeID, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-41), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+5));
	}

   	else{
		bridgeID = rmCreateGrouping("mississippi bridge", "mississippi_bridge_01");
		rmPlaceGroupingAtLoc(bridgeID, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+46), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+3));
		rmPlaceGroupingAtLoc(bridgeID, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-46), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+3));
	}

	int bridgeSite1 = rmCreateArea ("bridge site 1");
	if (cNumberNonGaiaPlayers<=3)
		rmSetAreaSize(bridgeSite1, rmAreaTilesToFraction(1350.0), rmAreaTilesToFraction(1350.0));
	if (cNumberNonGaiaPlayers>=7)
		rmSetAreaSize(bridgeSite1, rmAreaTilesToFraction(1650.0), rmAreaTilesToFraction(1650.0));
	else
		rmSetAreaSize(bridgeSite1, rmAreaTilesToFraction(1450.0), rmAreaTilesToFraction(1450.0));
	rmSetAreaLocation(bridgeSite1, rmXMetersToFraction(xsVectorGetX(StopperLoc9)), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
	rmSetAreaCoherence(bridgeSite1, 1);
	rmSetAreaSmoothDistance(bridgeSite1, 20);
	rmSetAreaBaseHeight(bridgeSite1, 0.5);
	rmAddAreaToClass(bridgeSite1, classPortSite);
	rmAddAreaInfluenceSegment(bridgeSite1, 0.5, rmZMetersToFraction(xsVectorGetZ(StopperLoc9)+14), 0.5, rmZMetersToFraction(xsVectorGetZ(StopperLoc9)-14));
	rmSetAreaObeyWorldCircleConstraint(bridgeSite1, false);
	rmBuildArea(bridgeSite1);

	int bridgeSite2 = rmCreateArea ("bridge site 2");
	rmSetAreaSize(bridgeSite2, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
	if (cNumberNonGaiaPlayers<=3)
		rmSetAreaLocation(bridgeSite2, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-67), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
	else
		rmSetAreaLocation(bridgeSite2, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-73), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
	rmSetAreaCoherence(bridgeSite2, 1);
	rmSetAreaSmoothDistance(bridgeSite2, 20);
	rmSetAreaBaseHeight(bridgeSite2, 0.5);
	rmAddAreaToClass(bridgeSite2, classPortSite);
	rmBuildArea(bridgeSite2);

	int bridgeSite3 = rmCreateArea ("bridge site 3");
	rmSetAreaSize(bridgeSite3, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
	if (cNumberNonGaiaPlayers<=3)
		rmSetAreaLocation(bridgeSite3, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+67), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
	else
		rmSetAreaLocation(bridgeSite3, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+73), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
	rmSetAreaCoherence(bridgeSite3, 1);
	rmAddAreaTerrainLayer(bridgeSite3, "city\ground1_cob", 0, 12);
	rmSetAreaSmoothDistance(bridgeSite3, 20);
	rmSetAreaBaseHeight(bridgeSite3, 0.5);
	rmAddAreaToClass(bridgeSite3, classPortSite);
	rmBuildArea(bridgeSite3);

	int bridgeTerrain1 = rmCreateArea ("bridge terrain 1");
	if (cNumberNonGaiaPlayers<=3) {
		rmSetAreaSize(bridgeTerrain1, rmAreaTilesToFraction(200.0), rmAreaTilesToFraction(200.0));
		rmSetAreaLocation(bridgeTerrain1, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+41), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		}
	else {
		rmSetAreaSize(bridgeTerrain1, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
		rmSetAreaLocation(bridgeTerrain1, rmXMetersToFraction(xsVectorGetX(StopperLoc9)+46), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		}
	rmSetAreaTerrainType(bridgeTerrain1, "city\ground1_cob");
	rmSetAreaCoherence(bridgeTerrain1, 1);
	rmBuildArea(bridgeTerrain1);

	int bridgeTerrain2 = rmCreateArea ("bridge terrain 2");
	if (cNumberNonGaiaPlayers<=3) {
		rmSetAreaSize(bridgeTerrain2, rmAreaTilesToFraction(200.0), rmAreaTilesToFraction(200.0));
		rmSetAreaLocation(bridgeTerrain2, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-41), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		}
	else {
		rmSetAreaSize(bridgeTerrain2, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
		rmSetAreaLocation(bridgeTerrain2, rmXMetersToFraction(xsVectorGetX(StopperLoc9)-46), rmZMetersToFraction(xsVectorGetZ(StopperLoc9)));
		}
	rmSetAreaTerrainType(bridgeTerrain2, "city\ground1_cob");
	rmSetAreaCoherence(bridgeTerrain2, 1);
	rmBuildArea(bridgeTerrain2);

	int randLoc = rmRandInt(1,2);
	float xLoc = rmXMetersToFraction(xsVectorGetX(StopperLoc9));
	float yLoc = rmXMetersToFraction(xsVectorGetZ(StopperLoc9)-28);
	float walk = 0.0;

	ypKingsHillPlacer(xLoc, yLoc, walk, 0);
	rmEchoInfo("XLOC = "+xLoc);
	rmEchoInfo("XLOC = "+yLoc);
	
	}

	// Mines

	int saltCount = (cNumberNonGaiaPlayers*1.5);

	for(i=0; < saltCount)
	{
		int  lakeSaltMineID = rmCreateObjectDef("mine south "+i);
		rmAddObjectDefItem(lakeSaltMineID, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(lakeSaltMineID, 0.0);
		rmSetObjectDefMaxDistance(lakeSaltMineID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(lakeSaltMineID, avoidCoin);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidAll);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidTradeRoute);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidSocket);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidWater20);
		rmAddObjectDefConstraint(lakeSaltMineID, southConstraint);
		rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.5, 0.5);

		int  lakeSaltMineID2 = rmCreateObjectDef("mine north "+i);
		rmAddObjectDefItem(lakeSaltMineID2, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(lakeSaltMineID2, 0.0);
		rmSetObjectDefMaxDistance(lakeSaltMineID2, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(lakeSaltMineID2, avoidCoin);
		rmAddObjectDefConstraint(lakeSaltMineID2, avoidAll);
		rmAddObjectDefConstraint(lakeSaltMineID2, avoidTradeRoute);
		rmAddObjectDefConstraint(lakeSaltMineID2, avoidSocket);
		rmAddObjectDefConstraint(lakeSaltMineID2, avoidWater20);
		rmAddObjectDefConstraint(lakeSaltMineID2, northConstraint);
		rmPlaceObjectDefAtLoc(lakeSaltMineID2, 0, 0.5, 0.5);

		int berriesID = rmCreateObjectDef("berries"+i);
		rmAddObjectDefItem(berriesID, "berrybush", 3, 4.0);
		rmSetObjectDefMinDistance(berriesID, 0.0);
		rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(berriesID, avoidCoin);
		rmAddObjectDefConstraint(berriesID, avoidAll);
		rmAddObjectDefConstraint(berriesID, avoidTradeRoute);
		rmAddObjectDefConstraint(berriesID, avoidSocket);
		rmAddObjectDefConstraint(berriesID, avoidWater20);
		rmAddObjectDefConstraint(berriesID, southConstraint);
		rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5);

		int berriesID2 = rmCreateObjectDef("berries 2"+i);
		rmAddObjectDefItem(berriesID2, "berrybush", 3, 4.0);
		rmSetObjectDefMinDistance(berriesID2, 0.0);
		rmSetObjectDefMaxDistance(berriesID2, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(berriesID2, avoidCoin);
		rmAddObjectDefConstraint(berriesID2, avoidAll);
		rmAddObjectDefConstraint(berriesID2, avoidTradeRoute);
		rmAddObjectDefConstraint(berriesID2, avoidSocket);
		rmAddObjectDefConstraint(berriesID2, avoidWater20);
		rmAddObjectDefConstraint(berriesID2, northConstraint);
		rmPlaceObjectDefAtLoc(berriesID2, 0, 0.5, 0.5);

	}

	// Text
	rmSetStatusText("",0.60);

	// Forests

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=28+5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 below
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, "z68 North Carolinas");
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(northForest, shortAvoidCoin);
		rmAddAreaConstraint(northForest, avoidTownCenterFar);
		rmAddAreaConstraint(northForest, avoidJewish);
		rmAddAreaConstraint(northForest, avoidMaltese);
		rmAddAreaConstraint(northForest, avoidTradeSocket);
		rmAddAreaConstraint(northForest, avoidHarbour);
		rmAddAreaConstraint(northForest, avoidSufi);
		rmAddAreaConstraint(northForest, avoidTradeRoute);
		rmAddAreaConstraint(northForest, avoidWater20);
		rmAddAreaConstraint(northForest, avoidKOTH);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, northConstraint);				// DAL adeed, to keep forests in the north.
		if(rmBuildArea(northForest)==false)
		{
			// Stop trying once we fail 5 times in a row.  
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount=0; 
	}

	
	numTries=5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		rmSetAreaForestType(southForest, "z68 North Carolinas");
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidImportantItem);
		rmAddAreaConstraint(southForest, shortAvoidCoin);
		rmAddAreaConstraint(southForest, avoidTownCenterFar);
		rmAddAreaConstraint(southForest, avoidJewish);
		rmAddAreaConstraint(southForest, avoidMaltese);
		rmAddAreaConstraint(southForest, avoidTradeSocket);
		rmAddAreaConstraint(southForest, avoidHarbour);
		rmAddAreaConstraint(southForest, avoidSufi);
		rmAddAreaConstraint(southForest, avoidTradeRoute);
		rmAddAreaConstraint(southForest, avoidWater20);
		rmAddAreaConstraint(southForest, avoidKOTH);
		rmAddAreaConstraint(southForest, forestConstraint);
		rmAddAreaConstraint(southForest, southConstraint);
		if (rmBuildArea(southForest) == false)
		{
			// Stop trying once we fail 5 times in a row.
			failCount++;
			if (failCount == 5)
				break;
		}
		else
			failCount = 0;
	}

	// Text
	rmSetStatusText("",0.70);

	// Place some extra deer herds.  
	int deerHerdID=rmCreateObjectDef("northern deer herd");
	rmAddObjectDefItem(deerHerdID, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID, true);
	rmSetObjectDefMinDistance(deerHerdID, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID, avoidAll);
	rmAddObjectDefConstraint(deerHerdID, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID, northConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID, 0, 0.5, 0.5);
	}

	int deerHerdID2=rmCreateObjectDef("southern deer herd");
	rmAddObjectDefItem(deerHerdID2, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID2, true);
	rmSetObjectDefMinDistance(deerHerdID2, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID2, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID2, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID2, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID2, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID2, avoidAll);
	rmAddObjectDefConstraint(deerHerdID2, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID2, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID2, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID2, southConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}

    int mooseHerdID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseHerdID, "turkey", rmRandInt(8,14), 6.0);
	rmSetObjectDefCreateHerd(mooseHerdID, true);
	rmSetObjectDefMinDistance(mooseHerdID, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(mooseHerdID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(mooseHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(mooseHerdID, avoidAll);
	rmAddObjectDefConstraint(mooseHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(mooseHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(mooseHerdID, avoidKOTH);
	rmAddObjectDefConstraint(mooseHerdID, mooseConstraint);
	rmAddObjectDefConstraint(mooseHerdID, shortDeerConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(mooseHerdID, 0, 0.5, 0.5);
	}

	// Text
	rmSetStatusText("",0.80);

    
	// Define and place Nuggets
    
	int nugget4= rmCreateObjectDef("nugget nuts"); 
	rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmAddObjectDefToClass(nugget4, rmClassID("nuggets"));
	rmSetObjectDefMinDistance(nugget4, rmXFractionToMeters(0.3));
	rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nugget4, longPlayerConstraint);
	rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget4, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget4, avoidNuggets);
	rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget4, circleConstraint);
	rmAddObjectDefConstraint(nugget4, avoidKOTH);
	rmAddObjectDefConstraint(nugget4, avoidAll);
	rmAddObjectDefConstraint(nugget4, avoidWater20);
	//rmAddObjectDefConstraint(nugget4, longPlayerEdgeConstraint);
	if (cNumberNonGaiaPlayers > 2 && rmGetIsTreaty() == false)
		rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int nugget3= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefToClass(nugget3, rmClassID("nuggets"));
	rmSetObjectDefMinDistance(nugget3, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nugget3, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNuggets);
	rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3, circleConstraint);
	rmAddObjectDefConstraint(nugget3, avoidKOTH);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget4, avoidWater20);
	rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int nugget2= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmAddObjectDefToClass(nugget2, rmClassID("nuggets"));
	rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.05));
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.25));
	rmAddObjectDefConstraint(nugget2, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNuggets);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidKOTH);
	rmAddObjectDefConstraint(nugget2, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget2, circleConstraint);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2,avoidWater20);
	rmSetObjectDefMinDistance(nugget2, 80.0);
	rmSetObjectDefMaxDistance(nugget2, 120.0);
	rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefToClass(nugget1, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget1, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTownCenter);
	rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNuggets);
	rmAddObjectDefConstraint(nugget1, avoidTradeSockets);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidKOTH);
	rmAddObjectDefConstraint(nugget1, circleConstraint);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.49));
	rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);

	// Fishes

    int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	if (rmGetIsKOTH() == true)
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.4));
	else
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);


    // River Trees
    
	int villageTreeID=rmCreateObjectDef("village tree");
	rmAddObjectDefItem(villageTreeID, "TreeBayou", 1, 0.0);
	rmSetObjectDefMinDistance(villageTreeID, rmXFractionToMeters(0.00));
	rmSetObjectDefMaxDistance(villageTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(villageTreeID, ferryOnShore);
	rmAddObjectDefConstraint(villageTreeID, avoidWater10);
	rmAddObjectDefConstraint(villageTreeID, avoidCoin);
	rmAddObjectDefConstraint(villageTreeID, avoidKOTH);
	rmAddObjectDefConstraint(villageTreeID, avoidBridge);
	rmAddObjectDefConstraint(villageTreeID, avoidImportantItem);
	for (i=0; <4*numTries){
		rmPlaceObjectDefAtLoc(villageTreeID, 0, 0.5, 0.5, 1);
	}

	// Text
	rmSetStatusText("",0.90);

	// ------Triggers--------//

	// Stations
    string unitID00 = "5";
    string unitID01 = "225";
	string unitID1 = "18";
	string unitID2 = "68";
	string unitID3 = "118";
	string unitID4 = "168";
	string unitID5 = "238";
	string unitID6 = "288";
	string unitID7 = "338";
	string unitID8 = "388";
	string unitID9 = "438";

	// Ship Training
    string unitIDsc00 = "455";
    string unitIDsc01 = "545";

	// Cooldowns
	int armoredTrainActive = 90;
	int armoredTrainCooldown = 10;
	int armoredTrainCooldown2 = 10;
	int noStations = 2;
	int trainDirection = 22;

    if (cNumberNonGaiaPlayers <=2){
		unitID2 = "88";
        unitID01 = "75";
        unitIDsc00 = "155";
        unitIDsc01 = "245";
		noStations = 2;
		trainDirection = 22;
		}
    if (cNumberNonGaiaPlayers ==3){
		unitID3 = "138";
        unitID01 = "125";
        unitIDsc00 = "205";
        unitIDsc01 = "295";
		noStations = 3;
		trainDirection = 23;
		}
    if (cNumberNonGaiaPlayers ==4){
		unitID3 = "138";
        unitID4 = "188";
        unitID01 = "125";
        unitIDsc00 = "255";
        unitIDsc01 = "345";
		noStations = 4;
		trainDirection = 24;
		}
    if (cNumberNonGaiaPlayers ==5){
		unitID3 = "138";
        unitID4 = "188";
        unitID01 = "125";
		unitIDsc00 = "305";
        unitIDsc01 = "395";
		noStations = 5;
		trainDirection = 25;
		}
    if (cNumberNonGaiaPlayers ==6){
        unitID4 = "188";
        unitID01 = "175";
		unitIDsc00 = "355";
        unitIDsc01 = "445";
		noStations = 6;
		trainDirection = 26;
		}
	if (cNumberNonGaiaPlayers ==7){
		unitIDsc00 = "405";
        unitIDsc01 = "495";
		noStations = 7;
		trainDirection = 27;
		}
	if (cNumberNonGaiaPlayers ==8){
		noStations = 8;
		trainDirection = 28;
		}

	if (rmGetIsKOTH()){
		unitID1 = "8";
		unitID2 = "58";
		unitID3 = "108";
		unitID4 = "158";
		unitID5 = "208";
		unitID6 = "258";
		unitID7 = "308";
		unitID8 = "358";
		unitID9 = "408";
		if (cNumberNonGaiaPlayers <=2){
			noStations = 3;
			trainDirection = 12;
		}
		if (cNumberNonGaiaPlayers ==3){
			noStations = 4;
			trainDirection = 13;
		}
		if (cNumberNonGaiaPlayers ==4){
			noStations = 5;
			trainDirection = 14;
		}
		if (cNumberNonGaiaPlayers ==5){
			noStations = 6;
			trainDirection = 15;
		}
		if (cNumberNonGaiaPlayers ==6){
			noStations = 7;
			trainDirection = 16;
		}
		if (cNumberNonGaiaPlayers ==7){
			noStations = 8;
			trainDirection = 17;
		}
		if (cNumberNonGaiaPlayers ==8){
			noStations = 9;
			trainDirection = 18;
		}
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
    rmSetTriggerEffectParam("TechID","cTechzpIsAztecMap"); // DEEneableTradeRouteWater
    rmSetTriggerEffectParamInt("Status",2);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechTradeRouteUpgrade1"); // DEEneableTradeRouteWater
    rmSetTriggerEffectParamInt("Status",1);
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",i);
    rmSetTriggerEffectParam("TechID","cTechTradeRouteUpgrade2"); // DEEneableTradeRouteWater
    rmSetTriggerEffectParamInt("Status",1);
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
	rmCreateTrigger("Activate Tortuga"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientistsLand"); //operator
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
	rmCreateTrigger("Activate Western"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpWesternAgeUp"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWestern"); //operator
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Western"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Trade Route Setup

	rmCreateTrigger("AT_Initialize");
	if (rmGetIsKOTH()){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+i);
		rmSetTriggerEffectParamInt("Value",0);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","TrainImprove_Plr"+i);
		rmSetTriggerEffectParamInt("Value",0);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Upgrade

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Cooldown_Upgrade"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainImprove");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","TrainImprove_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	
	rmCreateTrigger("AT_Cooldown_On_Plr"+k);
	rmCreateTrigger("AT_Cooldown_Off_Plr"+k);
	}


	// Trade Route Upgrade

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_TR_Upgrade_Plr"+k);
	}

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("AT_TR_Upgrade_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerConditionParamInt("Status",2);
	if (rmGetIsKOTH()){
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",5);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTradeRouteUpgradeWaterNative"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTradeRouteUpgradeWaterNative2"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_TR_Upgrade_Plr"+i));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Update Sockets


	rmCreateTrigger("I Update Sockets 1");
	if (rmGetIsKOTH()){
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",0);
		rmSetTriggerConditionParam("Protounit","Stagecoach");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID00);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","Stagecoach");
		rmSetTriggerConditionParamInt("Dist",150);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("II Update Sockets 1");
	if (rmGetIsKOTH()){
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",0);
		rmSetTriggerConditionParam("Protounit","TrainEngine");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID00);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","TrainEngine");
		rmSetTriggerConditionParamInt("Dist",150);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpTrainStationUpgradeA");
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	
	if (rmGetIsKOTH()){
	}
	else {
		rmCreateTrigger("I Update Sockets 2");
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID01);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","Stagecoach");
		rmSetTriggerConditionParamInt("Dist",150);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("II Update Sockets 2");
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID01);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","TrainEngine");
		rmSetTriggerConditionParamInt("Dist",150);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
		for(i=0; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpTrainStationUpgradeB");
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Normalize Trade Routes

	rmCreateTrigger("AT1_Normalize_TR");
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1000);
	if (rmGetIsKOTH()){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","true");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","true");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");
	}
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ****** ARMORED TRAIN SEND AND STOP ******

	// Define Triggers

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT1_Send_Station1_Plr"+k);
	rmCreateTrigger("AT1_Send_Station2_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station1_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station2_Plr"+k);
	rmCreateTrigger("AT1_Break_Station1_Plr"+k);
	rmCreateTrigger("AT1_Break_Station2_Plr"+k);
    if (noStations >= 3){
	    rmCreateTrigger("AT1_Send_Station3_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station3_Plr"+k);
		rmCreateTrigger("AT1_Break_Station3_Plr"+k);
	}
    if (noStations >= 4){
	    rmCreateTrigger("AT1_Send_Station4_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station4_Plr"+k);
		rmCreateTrigger("AT1_Break_Station4_Plr"+k);
	}
	if (noStations >= 5){
		rmCreateTrigger("AT1_Send_Station5_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station5_Plr"+k);
		rmCreateTrigger("AT1_Break_Station5_Plr"+k);
	}
	if (noStations >= 6){
		rmCreateTrigger("AT1_Send_Station6_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station6_Plr"+k);
		rmCreateTrigger("AT1_Break_Station6_Plr"+k);
	}
	if (noStations >= 7){
		rmCreateTrigger("AT1_Send_Station7_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station7_Plr"+k);
		rmCreateTrigger("AT1_Break_Station7_Plr"+k);
	}
	if (noStations >= 8){
		rmCreateTrigger("AT1_Send_Station8_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station8_Plr"+k);
		rmCreateTrigger("AT1_Break_Station8_Plr"+k);
	}
	if (noStations >= 9){
		rmCreateTrigger("AT1_Send_Station9_Plr"+k);
		rmCreateTrigger("AT1_STOP_Station9_Plr"+k);
		rmCreateTrigger("AT1_Break_Station9_Plr"+k);
	}

	rmCreateTrigger("AT_Destroy_Plr"+k);
	rmCreateTrigger("AT_Revert_Plr"+k);
	rmCreateTrigger("AT_Counter_Plr"+k);

	// Station 1

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station1_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
	rmSetTriggerEffectParamInt("Status",2);

	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Train_Breaks");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station1_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	

	rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Unit Create from Source");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("ProtoName","zpArmoredTrainKitchenWagonEmitter");

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

	rmAddTriggerEffect("FakeCounter Clear");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Station 2

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	if (rmGetIsKOTH()){
		if (cNumberNonGaiaPlayers <=2){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
	}
	else {
		if (cNumberNonGaiaPlayers <=2){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",4);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
	}
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station2_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
	rmSetTriggerEffectParamInt("Status",2);

	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Train_Breaks");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station2_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

	rmAddTriggerEffect("FakeCounter Clear");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	if (noStations >= 3){

        // Station 3

        rmSwitchToTrigger(rmTriggerID("AT1_Send_Station3_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID3);
        rmSetTriggerConditionParamInt("Player",k);
        rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
        rmSetTriggerConditionParamInt("Dist",40);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
		if (rmGetIsKOTH()){
			if (cNumberNonGaiaPlayers <=5){
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",3);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
			else {
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",2);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
		}
		else {
			if (cNumberNonGaiaPlayers <=5){
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",3);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",4);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
			else {
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",2);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
		}
        rmAddTriggerEffect("Quest Var Set");
        rmSetTriggerEffectParam("QVName","ArmoredTrain");
        rmSetTriggerEffectParamInt("Value",1);
        rmAddTriggerEffect("Quest Var Set");
        rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
        rmSetTriggerEffectParamInt("Value",1);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station3_Plr"+k));

        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
        rmSetTriggerEffectParamInt("Status",2);

        rmAddTriggerEffect("FakeCounter Set Text");
        rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        rmSwitchToTrigger(rmTriggerID("AT1_Break_Station3_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID3);
        rmSetTriggerConditionParamInt("Player",0);
        rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
        rmSetTriggerConditionParamInt("Dist",15);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",0);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
        rmSetTriggerEffectParamInt("Status",2);
        rmAddTriggerEffect("Play Soundset");
        rmSetTriggerEffectParam("Soundset","Train_Breaks");
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station3_Plr"+k));
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);


        rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station3_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID3);
        rmSetTriggerConditionParamInt("Player",0);
        rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
        rmSetTriggerConditionParamInt("Dist",10);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
        
        rmAddTriggerEffect("ZP Armored Train Stop");
        rmSetTriggerEffectParam("SrcObject",unitID3);
        rmSetTriggerEffectParamInt("TrgPlayer",k);
        rmSetTriggerEffectParamInt("Dist",100);

        rmAddTriggerEffect("Counter:Add Timer");
        rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
        rmSetTriggerEffectParamInt("Start",armoredTrainActive);
        rmSetTriggerEffectParamInt("Stop",0);
        rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
        rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
        rmSetTriggerEffectParamInt("Status",1);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

        rmAddTriggerEffect("FakeCounter Clear");
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

    }

	if (noStations >= 4){

        // Station 4

        rmSwitchToTrigger(rmTriggerID("AT1_Send_Station4_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID4);
        rmSetTriggerConditionParamInt("Player",k);
        rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
        rmSetTriggerConditionParamInt("Dist",40);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
		if (rmGetIsKOTH()){
			if (cNumberNonGaiaPlayers <=6){
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",3);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
			else {
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",2);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
		}
		else {
			if (cNumberNonGaiaPlayers <=6){
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",3);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",4);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
			else {
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",1);
				rmSetTriggerEffectParam("ShowUnit","false");
				rmAddTriggerEffect("Trade Route Toggle State");
				rmSetTriggerEffectParamInt("TradeRoute",2);
				rmSetTriggerEffectParam("ShowUnit","true");
			}
		}
        rmAddTriggerEffect("Quest Var Set");
        rmSetTriggerEffectParam("QVName","ArmoredTrain");
        rmSetTriggerEffectParamInt("Value",1);
        rmAddTriggerEffect("Quest Var Set");
        rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
        rmSetTriggerEffectParamInt("Value",1);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station4_Plr"+k));

        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
        rmSetTriggerEffectParamInt("Status",2);

        rmAddTriggerEffect("FakeCounter Set Text");
        rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        rmSwitchToTrigger(rmTriggerID("AT1_Break_Station4_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID4);
        rmSetTriggerConditionParamInt("Player",0);
        rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
        rmSetTriggerConditionParamInt("Dist",15);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",0);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
        rmSetTriggerEffectParamInt("Status",2);
        rmAddTriggerEffect("Play Soundset");
        rmSetTriggerEffectParam("Soundset","Train_Breaks");
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station4_Plr"+k));
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station4_Plr"+k));
        rmAddTriggerCondition("Units in Area");
        rmSetTriggerConditionParam("DstObject",unitID4);
        rmSetTriggerConditionParamInt("Player",0);
        rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
        rmSetTriggerConditionParamInt("Dist",10);
        rmSetTriggerConditionParam("Op",">=");
        rmSetTriggerConditionParamInt("Count",1);
        
        rmAddTriggerEffect("ZP Armored Train Stop");
        rmSetTriggerEffectParam("SrcObject",unitID4);
        rmSetTriggerEffectParamInt("TrgPlayer",k);
        rmSetTriggerEffectParamInt("Dist",100);

        rmAddTriggerEffect("Counter:Add Timer");
        rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
        rmSetTriggerEffectParamInt("Start",armoredTrainActive);
        rmSetTriggerEffectParamInt("Stop",0);
        rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
        rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
        rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID",k);
        rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
        rmSetTriggerEffectParamInt("Status",1);
        rmAddTriggerEffect("Fire Event");
        rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

        rmAddTriggerEffect("FakeCounter Clear");
        rmSetTriggerPriority(4);
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);
    }
	
	if (noStations >= 5){
		
		// Station 5

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		if (rmGetIsKOTH()){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {	
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",4);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station5_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","Train_Breaks");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station5_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
		rmSetTriggerEffectParamInt("Status",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

		rmAddTriggerEffect("FakeCounter Clear");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (noStations >= 6){

		// Station 6

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

        if (rmGetIsKOTH()){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {	
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",4);
			rmSetTriggerEffectParam("ShowUnit","true");
		}

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station6_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","Train_Breaks");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station6_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
		rmSetTriggerEffectParamInt("Status",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

		rmAddTriggerEffect("FakeCounter Clear");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (noStations >= 7){
		// Station 7

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

        if (rmGetIsKOTH()){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {	
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",4);
			rmSetTriggerEffectParam("ShowUnit","true");
		}

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station7_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","Train_Breaks");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station7_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
		rmSetTriggerEffectParamInt("Status",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

		rmAddTriggerEffect("FakeCounter Clear");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (noStations >= 8){
		// Station 8

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

		if (rmGetIsKOTH()){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else {	
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",4);
			rmSetTriggerEffectParam("ShowUnit","true");
		}

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station8_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","Train_Breaks");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station8_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
		rmSetTriggerEffectParamInt("Status",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

		rmAddTriggerEffect("FakeCounter Clear");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (noStations >= 9){
		
		// Station 9

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station9_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID9);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station9_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text","Armored Train Player "+k+": Heading to destination");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station9_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID9);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","Train_Breaks");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station9_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station9_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID9);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID9);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg","Armored Train Player "+k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
		rmSetTriggerEffectParamInt("Status",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

		rmAddTriggerEffect("FakeCounter Clear");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Destroy Armored Train

	rmSwitchToTrigger(rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpKillArmoredTrain");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","AmbienceTrain");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Normalize_TR"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Revert Button

	rmSwitchToTrigger(rmTriggerID("AT_Revert_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Counter Stop");
	rmSetTriggerEffectParam("Name", "ArmoredTrainPlr"+k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Destroy_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Revert Counter

	rmSwitchToTrigger(rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}


	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Unlock_Plr"+k);
	rmCreateTrigger("AT_Lock_Plr"+k);
	rmCreateTrigger("AT_NoResource_Plr"+k);
	rmCreateTrigger("AT_Resource_Plr"+k);

	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("AT_Unlock_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Lock_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT_NoResource_Plr"+k));
	rmAddTriggerCondition("Player Resource Count");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("Resource","gold");
	rmSetTriggerConditionParam("Op","<");
	rmSetTriggerConditionParamInt("Count",500);

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT_Resource_Plr"+k));
	rmAddTriggerCondition("Player Resource Count");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("Resource","gold");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",500);

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station4_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station5_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station6_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station7_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station8_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station9_Plr"+k));
	
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT_Lock_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Unlock_Plr"+k));

	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station4_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station5_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station6_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station7_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station8_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station9_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Armored Train Counter Upgrade

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","TrainImprove_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainCooldown);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Next Armored Train Available in");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("ZP Counter Visible for Player");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Player",k);	
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT_Cooldown_On_Plr"+k));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","TrainImprove_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainCooldown2);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Next Armored Train Available in");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("ZP Counter Visible for Player");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Player",k);	
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// CONVERT STATIONS	

	// Station 1

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Station1_on_Plr"+k);
	rmCreateTrigger("Station1_off_Plr"+k);

	rmSwitchToTrigger(rmTriggerID("Station1_on_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);

	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station1_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station1_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station1_on_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Station 2

	rmCreateTrigger("Station2_on_Plr"+k);
	rmCreateTrigger("Station2_off_Plr"+k);

	rmSwitchToTrigger(rmTriggerID("Station2_on_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station2_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station2_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station2_on_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Station 3

	if (noStations >= 3){
		rmCreateTrigger("Station3_on_Plr"+k);
		rmCreateTrigger("Station3_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station3_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station3_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}

	if (noStations >= 4){

		// Station 4

		rmCreateTrigger("Station4_on_Plr"+k);
		rmCreateTrigger("Station4_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station4_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station4_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station4_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station4_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		}

	if (noStations >= 5){

		// Station 5

		rmCreateTrigger("Station5_on_Plr"+k);
		rmCreateTrigger("Station5_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station5_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station5_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station5_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station5_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}

	if (noStations >= 6){

		// Station 6

		rmCreateTrigger("Station6_on_Plr"+k);
		rmCreateTrigger("Station6_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station6_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station6_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station6_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station6_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}

	if (noStations >= 7){

		// Station 7

		rmCreateTrigger("Station7_on_Plr"+k);
		rmCreateTrigger("Station7_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station7_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station7_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station7_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station7_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}

	if (noStations >= 8){

		// Station 8

		rmCreateTrigger("Station8_on_Plr"+k);
		rmCreateTrigger("Station8_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station8_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station8_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station8_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station8_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}

	if (noStations >= 9){

		// Station 9

		rmCreateTrigger("Station9_on_Plr"+k);
		rmCreateTrigger("Station9_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station9_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID9);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID9);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station9_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station9_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID9);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID9);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station9_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		}
	}


    for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain1ONPlr"+k);
	rmCreateTrigger("BlackbTrain1OFFPlr"+k);

	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain2ONPlr"+k);
	rmCreateTrigger("BlackbTrain2OFFPlr"+k);


	rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
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

	rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
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


	// Build limit reducer
	rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
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
	rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
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

	}

	// Renegade Water trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates1on Player"+k);
	rmCreateTrigger("Pirates1off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc00);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc00);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
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
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc01);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc01);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}

	// Update ports

	rmCreateTrigger("I Update WaterTrade");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","zpTradeCaravel");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpUpdatePort1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	if (rmGetIsKOTH()){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
			rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("II Update WaterTrade");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","zpTradeSteamer");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	if (rmGetIsKOTH()){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	else {
			rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// AI Renegade Leaders

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
		rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistGortz"); //operator
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

	// AI Western Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Western Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int westernLeader=-1;
	westernLeader = rmRandInt(1,3);

	if (westernLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternWyatEarp"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (westernLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternPinkertons"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (westernLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternJesseJames"); //operator
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
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}*/
	
	
	// Text
	rmSetStatusText("",1.00);
	
} // END