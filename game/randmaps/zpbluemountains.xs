// Blue Mountains
// March 2024

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

		subCiv1=rmGetCivID("AboriginalNatives");
		rmEchoInfo("subCiv1 is AboriginalNatives "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "AboriginalNatives");
  
		subCiv2=rmGetCivID("PenalColony");
		rmEchoInfo("subCiv2 is PenalColony "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "PenalColony");
	}

    // Picks the map size
	int playerTiles = 13000;
	if (cNumberNonGaiaPlayers >2)
		playerTiles = 12000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 11000;			

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(1.2*size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(-9);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);
   
   	// LIGHT SET

	//rmSetLightingSet("herald_island_skirmish");
	//rmSetLightingSet("japan_misty_morning");
	rmSetLightingSet("india_yic1a1");


	// Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("Deccan_grass_a");
	rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
	rmSetMapType("australia");
	rmSetMapType("grass");
	rmSetMapType("land");

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
	int classSmallCliff=rmDefineClass("smallCliff");

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
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	


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
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "minegold", 30.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
    int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 10.0);
	int avoidTree=rmCreateTypeDistanceConstraint("avoid trees", "TreeSonora", 11.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "deTorpBush2", 50.0);	//Attempting to spread them out more evenly.

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
	int avoidSmallCliffs=rmCreateClassDistanceConstraint("anything vs. smcliff", classSmallCliff, 30.0);
	int avoidSmallCliffsShort=rmCreateClassDistanceConstraint("anything vs. smcliff short", classSmallCliff, 10.0);

	// Unit avoidance
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 45.0);
	int shortAvoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units short", rmClassID("startingUnit"), 10.0);
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 8.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
	int avoidSecrets=rmCreateClassDistanceConstraint("stuff avoids secrets", rmClassID("secrets"), 20.0);
	int avoidNuggets=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 60.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "zpEmu", 30.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "zpEmu", 20.0);
	int mooseConstraint=rmCreateTypeDistanceConstraint("avoid the moose", "moose", 40.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
    int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
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
	int AvoidAboriginals=rmCreateTypeDistanceConstraint("stay away from Aboriginal", "zpSocketAboriginals", 30.0);
	int AvoidAboriginalsLong=rmCreateTypeDistanceConstraint("stay away from Aboriginal Long", "zpSocketAboriginals", 50.0);
	int avoidInventors=rmCreateTypeDistanceConstraint("stay away from Inventors", "zpSocketScientists", 30.0);
	int avoidInventorsLong=rmCreateTypeDistanceConstraint("stay away from Inventors Long", "zpSocketScientists", 50.0);
	int avoidPenalColony=rmCreateTypeDistanceConstraint("stay away from Penal Colony", "zpSocketPenalColony", 33.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 25.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);
	int avoidKangaroos=rmCreateTypeDistanceConstraint("avoid random kangaroo", "zpRedKangaroo", 40.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random emu", "zpEmu", 40.0);	//Attempting to spread them out more evenly.

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// Text
	rmSetStatusText("",0.10);


   	float playerFraction=rmAreaTilesToFraction(850);

	// check for KOTH game mode
	if (rmGetIsKOTH())
	{       
        float xLoc = 0.5;
        float yLoc = 0.5;
        float walk = 0.0;
    }

	/*int SmallLake1ID=rmCreateArea("Lake 1");
	rmSetAreaWaterType(SmallLake1ID, "Deccan Plateau River");
	rmSetAreaSize(SmallLake1ID, 0.015, 0.015);
	rmSetAreaCoherence(SmallLake1ID, 0.7);
	rmSetAreaLocation(SmallLake1ID, 0.1, 0.7);
	rmSetAreaSmoothDistance(SmallLake1ID, 10);
	rmSetAreaObeyWorldCircleConstraint(SmallLake1ID, false);
	rmBuildArea(SmallLake1ID);

	int SmallLake2ID=rmCreateArea("Lake 2");
	rmSetAreaWaterType(SmallLake2ID, "Deccan Plateau River");
	rmSetAreaSize(SmallLake2ID, 0.015, 0.015);
	rmSetAreaCoherence(SmallLake2ID, 0.7);
	rmSetAreaLocation(SmallLake2ID, 0.9, 0.7);
	rmSetAreaSmoothDistance(SmallLake2ID, 10);
	rmSetAreaObeyWorldCircleConstraint(SmallLake2ID, false);
	rmBuildArea(SmallLake2ID);

	int SmallLake3ID=rmCreateArea("Lake 3");
	rmSetAreaWaterType(SmallLake3ID, "Deccan Plateau River");
	rmSetAreaSize(SmallLake3ID, 0.015, 0.015);
	rmSetAreaCoherence(SmallLake3ID, 0.7);
	rmSetAreaLocation(SmallLake3ID, 0.9, 0.3);
	rmSetAreaSmoothDistance(SmallLake3ID, 10);
	rmSetAreaObeyWorldCircleConstraint(SmallLake3ID, false);
	rmBuildArea(SmallLake3ID);

	int SmallLake4ID=rmCreateArea("Lake 4");
	rmSetAreaWaterType(SmallLake4ID, "Deccan Plateau River");
	rmSetAreaSize(SmallLake4ID, 0.015, 0.015);
	rmSetAreaCoherence(SmallLake4ID, 0.7);
	rmSetAreaLocation(SmallLake4ID, 0.1, 0.3);
	rmSetAreaSmoothDistance(SmallLake4ID, 10);
	rmSetAreaObeyWorldCircleConstraint(SmallLake4ID, false);
	rmBuildArea(SmallLake4ID);*/


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

	// Trade Route 1

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
	rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
	rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
	rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
	rmSetObjectDefTradeRouteID(stopperID00, tradeRouteID);
	
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.8);

	rmBuildTradeRoute(tradeRouteID, "dirt");


		vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
		rmPlaceObjectDefAtPoint(stopperID00, 0, socketLoc1);
		vector StopperLoc00 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID00, 0));
		rmPlaceGroupingAtLoc(stationGrouping00, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc00)), rmZMetersToFraction(xsVectorGetZ(StopperLoc00)));


	if (cNumberNonGaiaPlayers >=3){
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
		vector StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
	}

	if (cNumberNonGaiaPlayers >=7){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.43);
		rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
		vector StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));


		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.57);
		rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc1);
		vector StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));

	}

	if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==6){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
		StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
	}

	if (cNumberNonGaiaPlayers >=3){
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
		rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
		vector StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
	}

	int tradeRouteID2 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.8);

	rmBuildTradeRoute(tradeRouteID2, "armored_train");

	// Trade Route 2

	int tradeRouteID3 = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(stopperID5, tradeRouteID3);
	rmSetObjectDefTradeRouteID(stopperID6, tradeRouteID3);
	rmSetObjectDefTradeRouteID(stopperID7, tradeRouteID3);
	rmSetObjectDefTradeRouteID(stopperID8, tradeRouteID3);
	rmSetObjectDefTradeRouteID(stopperID01, tradeRouteID3);

	rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.2);
	rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.2);

	rmBuildTradeRoute(tradeRouteID3, "dirt");

	socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.15);
	rmPlaceObjectDefAtPoint(stopperID01, 0, socketLoc1);
	vector StopperLoc001 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID01, 0));
	rmPlaceGroupingAtLoc(stationGrouping00, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc001)), rmZMetersToFraction(xsVectorGetZ(StopperLoc001)));

	if (cNumberNonGaiaPlayers >=4){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.24);
		rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
		vector StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
	}

	if (cNumberNonGaiaPlayers ==8){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.43);
		rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
		vector StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.57);
		rmPlaceObjectDefAtPoint(stopperID7, 0, socketLoc1);
		vector StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
	}

	if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==6 || cNumberNonGaiaPlayers ==7){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.50);
		rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
		StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
	}
	
	if (cNumberNonGaiaPlayers >=4){	
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.73);
		rmPlaceObjectDefAtPoint(stopperID8, 0, socketLoc1);
		vector StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
	}

	int tradeRouteID4 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.0, 0.2);
	rmAddTradeRouteWaypoint(tradeRouteID4, 1.0, 0.2);

	rmBuildTradeRoute(tradeRouteID4, "armored_train");	

	// Text
	rmSetStatusText("",0.20);

	if (rmGetIsKOTH())
	{
		//ypKingsHillLandfill(xLoc, yLoc, rmAreaTilesToFraction(375), 2.0, "borneo_sand_a", 0);
		ypKingsHillPlacer(xLoc, yLoc, walk, 0);
		rmEchoInfo("XLOC = "+xLoc);
		rmEchoInfo("XLOC = "+yLoc);
	}


	// Mountain Terrain

	int mountainsID=rmCreateArea("italy mountains"); 
	rmSetAreaSize(mountainsID, 0.27, 0.27);
    rmSetAreaLocation(mountainsID, 0.5, 0.5);
    rmSetAreaCoherence(mountainsID, 0.5);
    rmSetAreaSmoothDistance(mountainsID, 15);
    rmSetAreaCliffType(mountainsID, "Deccan Plateau");
    rmSetAreaCliffEdge(mountainsID, 6, 0.13, 0.0, 0.0, 0);
    rmSetAreaCliffHeight(mountainsID, 10.0, 0.0, 0.5); 
    rmSetAreaObeyWorldCircleConstraint(mountainsID, false);
    rmSetAreaElevationNoiseBias(mountainsID, 1);
	rmAddAreaConstraint(mountainsID, avoidTradeSocket);
	rmAddAreaConstraint(mountainsID, avoidInventors);
	rmAddAreaConstraint(mountainsID, avoidTradeRoute);
    rmAddAreaInfluenceSegment(mountainsID, 1.0, 0.5, 0.0, 0.5);
	rmSetAreaWarnFailure(mountainsID, false);
	rmSetAreaElevationVariation(mountainsID, 3.0);
    rmAddAreaToClass(mountainsID, classMountains);
    rmBuildArea(mountainsID);

    int mountainsIDTerrain=rmCreateArea("italy mountains terrain"); 
    rmSetAreaSize(mountainsIDTerrain, 0.3, 0.3);
    rmSetAreaLocation(mountainsIDTerrain, 0.5, 0.5);
    rmSetAreaCoherence(mountainsIDTerrain, 0.6);
    rmSetAreaMix(mountainsIDTerrain, "Deccan_Grass_B");
    rmSetAreaObeyWorldCircleConstraint(mountainsIDTerrain, false);
    rmAddAreaInfluenceSegment(mountainsIDTerrain, 1.0, 0.5, 0.0, 0.5);
    rmBuildArea(mountainsIDTerrain);

	int northWest=rmCreateArea("north west"); 
    rmSetAreaSize(northWest, 0.1, 0.1);
    rmSetAreaLocation(northWest, 0.5, 0.9);
    rmSetAreaCoherence(northWest, 1.0);
    rmSetAreaObeyWorldCircleConstraint(northWest, false);
    rmAddAreaInfluenceSegment(northWest, 0.2, 0.9, 0.8, 0.9);
    rmBuildArea(northWest);

	int southEast=rmCreateArea("south east"); 
    rmSetAreaSize(southEast, 0.1, 0.1);
    rmSetAreaLocation(southEast, 0.5, 0.1);
    rmSetAreaCoherence(southEast, 1.0);
    rmSetAreaObeyWorldCircleConstraint(southEast, false);
    rmAddAreaInfluenceSegment(southEast, 0.2, 0.1, 0.8, 0.1);
    rmBuildArea(southEast);

	int mountainsIDsConstraint=rmCreateAreaConstraint("stay in mountains", mountainsID);
	int westConstraint=rmCreateAreaConstraint("stay NorthWest", northWest);
	int eastConstraint=rmCreateAreaConstraint("stay SouthEast", southEast);

	// Text
	rmSetStatusText("",0.30);

	// Renegades

	int maltese1VillageTypeID = rmRandInt(5,6);
	int maltese1ID = -1;
	maltese1ID = rmCreateGrouping("maltese 1", "Scientist_Lab06");
	rmSetGroupingMinDistance(maltese1ID, 0);
	rmSetGroupingMaxDistance(maltese1ID, 50);
	rmAddGroupingConstraint(maltese1ID, avoidWater30);
	rmAddGroupingConstraint(maltese1ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(maltese1ID, avoidInventors);
	rmAddGroupingConstraint(maltese1ID, avoidPenalColony);
	rmAddGroupingConstraint(maltese1ID, mountainsIDsConstraint);
    rmAddGroupingConstraint(maltese1ID, avoidImpassableLand);
	rmAddGroupingConstraint(maltese1ID, avoidTradeSocketFar);
	rmAddGroupingConstraint(maltese1ID, avoidTradeRouteFar2);
	

	int maltese2VillageTypeID = 11-maltese1VillageTypeID;
	int maltese2ID = -1;
	maltese2ID = rmCreateGrouping("maltese 2", "Scientist_Lab05");
	rmSetGroupingMinDistance(maltese2ID, 0);
	rmSetGroupingMaxDistance(maltese2ID, 50);
	rmAddGroupingConstraint(maltese2ID, avoidWater30);
	rmAddGroupingConstraint(maltese2ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(maltese2ID, avoidInventors);
	rmAddGroupingConstraint(maltese2ID, mountainsIDsConstraint);
	rmAddGroupingConstraint(maltese2ID, avoidPenalColony);
    rmAddGroupingConstraint(maltese2ID, avoidImpassableLand);
	rmAddGroupingConstraint(maltese2ID, avoidTradeSocketFar);
	rmAddGroupingConstraint(maltese2ID, avoidTradeRouteFar2);

	rmPlaceGroupingAtLoc(maltese1ID, 0, 0.2, 0.45);

	if (cNumberNonGaiaPlayers >3)
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.7, 0.55);


	// Penal Colonies

	int jewish1VillageTypeID = rmRandInt(1, 3);
	int jewish2VillageTypeID = rmRandInt(1, 3);

	int jewish1ID = rmCreateGrouping("jewish 1", "Penal_colony_0"+jewish1VillageTypeID);
	int jewish2ID = rmCreateGrouping("jewish 2", "Penal_colony_0"+jewish2VillageTypeID);

	rmSetGroupingMinDistance(jewish1ID, 0);
	rmSetGroupingMaxDistance(jewish1ID, 70);
	rmSetGroupingMinDistance(jewish2ID, 0);
	rmSetGroupingMaxDistance(jewish2ID, 70);

    rmAddGroupingConstraint(jewish1ID, avoidWater30);
	rmAddGroupingConstraint(jewish1ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(jewish1ID, avoidInventorsLong);
	rmAddGroupingConstraint(jewish1ID, avoidPenalColony);
	rmAddGroupingConstraint(jewish1ID, mountainsIDsConstraint);
	rmAddGroupingConstraint(jewish1ID, avoidTradeRouteFar2);
    rmAddGroupingConstraint(jewish1ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish1ID, avoidTradeSocketFar);
    rmAddGroupingConstraint(jewish2ID, avoidWater30);
	rmAddGroupingConstraint(jewish2ID, farAvoidTradeSockets);
    rmAddGroupingConstraint(jewish2ID, avoidInventorsLong);
	rmAddGroupingConstraint(jewish2ID, avoidPenalColony);
	rmAddGroupingConstraint(jewish2ID, mountainsIDsConstraint);
	rmAddGroupingConstraint(jewish2ID, avoidTradeRouteFar2);
    rmAddGroupingConstraint(jewish2ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish2ID, avoidTradeSocketFar);

	rmPlaceGroupingAtLoc(jewish1ID, 0, 0.8, 0.55);

	if (cNumberNonGaiaPlayers >3)
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.3, 0.45);

	

	// Aboriginal Villages

    int Aboriginal1VillageTypeID = rmRandInt(1,5);
	int mosque1ID = -1;
	mosque1ID = rmCreateGrouping("mosque 1", "Native_Aboriginal_0"+Aboriginal1VillageTypeID);
	rmSetGroupingMinDistance(mosque1ID, 0);
	rmSetGroupingMaxDistance(mosque1ID, 50);
	rmAddGroupingConstraint(mosque1ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque1ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque1ID, circleConstraint);
	rmAddGroupingConstraint(mosque1ID, AvoidAboriginalsLong);
	rmAddGroupingConstraint(mosque1ID, farAvoidTradeSockets);
	rmAddGroupingConstraint(mosque1ID, avoidMountains);
	rmAddGroupingConstraint(mosque1ID, avoidWater30);
	if(cNumberNonGaiaPlayers <= 2)
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.7, 0.15, 1);
	else if(cNumberNonGaiaPlayers == 3)
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.5, 0.15, 1);
	else
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.7, 0.15, 1);


	int Aboriginal2VillageTypeID = rmRandInt(1,5);
	int mosque2ID = -1;
	mosque2ID = rmCreateGrouping("mosque 2", "Native_Aboriginal_0"+Aboriginal2VillageTypeID);
	rmSetGroupingMinDistance(mosque2ID, 0);
	rmSetGroupingMaxDistance(mosque2ID, 50);
	rmAddGroupingConstraint(mosque2ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque2ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque2ID, AvoidAboriginalsLong);
	rmAddGroupingConstraint(mosque2ID, farAvoidTradeSockets);
	rmAddGroupingConstraint(mosque2ID, circleConstraint);
	rmAddGroupingConstraint(mosque2ID, avoidMountains);
	rmAddGroupingConstraint(mosque2ID, avoidWater30);
	rmPlaceGroupingAtLoc(mosque1ID, 0, 0.3, 0.85, 1);



	if(cNumberNonGaiaPlayers >= 3){
		int Aboriginal3VillageTypeID = rmRandInt(1,5);
		int mosque3ID = -1;
		mosque3ID = rmCreateGrouping("Aboriginal Village 3", "Native_Aboriginal_0"+Aboriginal3VillageTypeID);
		rmSetGroupingMinDistance(mosque3ID, 0);
		rmSetGroupingMaxDistance(mosque3ID, 50);
		rmAddGroupingConstraint(mosque3ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque3ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque3ID, circleConstraint);
		rmAddGroupingConstraint(mosque3ID, AvoidAboriginalsLong);
		rmAddGroupingConstraint(mosque3ID, farAvoidTradeSockets);
		rmAddGroupingConstraint(mosque3ID, avoidMountains);
		rmAddGroupingConstraint(mosque3ID, southEast);
		rmAddGroupingConstraint(mosque3ID, avoidWater30);
		rmPlaceGroupingAtLoc(mosque3ID, 0, 0.7, 0.85, 1);
	}

	if(cNumberNonGaiaPlayers >= 4){
		int Aboriginal4VillageTypeID = rmRandInt(1,5);
		int mosque4ID = -1;
		mosque4ID = rmCreateGrouping("Aboriginal Village 4", "Native_Aboriginal_0"+Aboriginal4VillageTypeID);
		rmSetGroupingMinDistance(mosque4ID, 0);
		rmSetGroupingMaxDistance(mosque4ID, 50);
		rmAddGroupingConstraint(mosque4ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque4ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque4ID, circleConstraint);
		rmAddGroupingConstraint(mosque4ID, AvoidAboriginalsLong);
		rmAddGroupingConstraint(mosque4ID, farAvoidTradeSockets);
		rmAddGroupingConstraint(mosque4ID, avoidMountains);
		rmAddGroupingConstraint(mosque4ID, northWest);
		rmAddGroupingConstraint(mosque4ID, avoidWater30);
		rmPlaceGroupingAtLoc(mosque4ID, 0, 0.3, 0.15, 1);

	}

	// Text
	rmSetStatusText("",0.40);

	// Place Players

	float teamStartLoc = rmRandFloat(0.0, 1.0);

	if (cNumberNonGaiaPlayers <= 2){
		rmSetPlacementSection(0.0, 0.495); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.3, 0.3, 0);
		}

	if (cNumberNonGaiaPlayers == 3){
		rmPlacePlayer(1, 0.28, 0.8);
		rmPlacePlayer(2, 0.72, 0.8);
		rmPlacePlayer(3, 0.5, 0.2);
		}

	// 4 players in 2 teams
	if (cNumberNonGaiaPlayers == 4){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.72, 0.8, 0.28, 0.8, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.72, 0.2, 0.28, 0.2, 0, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.72, 0.2, 0.28, 0.2, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.72, 0.8, 0.28, 0.8, 0, 0);
			}
		}
		else{
		rmSetPlacementSection(0.125, 0.870); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.34, 0.34, 0);
		}
	}

	if (cNumberNonGaiaPlayers == 5){
		rmPlacePlayer(4, 0.28, 0.8);
		rmPlacePlayer(5, 0.72, 0.8);
		rmPlacePlayer(1, 0.28, 0.2);
		rmPlacePlayer(2, 0.5, 0.2);
		rmPlacePlayer(3, 0.72, 0.2);
		}

	if (cNumberNonGaiaPlayers == 6){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.8, 0.25, 0.8, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.2, 0.25, 0.2, 0, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.2, 0.25, 0.2, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.8, 0.28, 0.5, 0, 0);
			}
		}
		else{
			rmPlacePlayer(4, 0.25, 0.2);
			rmPlacePlayer(5, 0.5, 0.2);
			rmPlacePlayer(6, 0.75, 0.2);
			rmPlacePlayer(1, 0.25, 0.8);
			rmPlacePlayer(2, 0.5, 0.8);
			rmPlacePlayer(3, 0.75, 0.8);
		}
	}

	if (cNumberNonGaiaPlayers == 7){
		rmPlacePlayer(1, 0.25, 0.8);
		rmPlacePlayer(2, 0.42, 0.8);
		rmPlacePlayer(3, 0.58, 0.8);
		rmPlacePlayer(4, 0.75, 0.8);
		rmPlacePlayer(5, 0.25, 0.2);
		rmPlacePlayer(6, 0.5, 0.2);
		rmPlacePlayer(7, 0.75, 0.2);
		}

	if (cNumberNonGaiaPlayers == 8){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.8, 0.25, 0.8, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.2, 0.25, 0.2, 0, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.75, 0.2, 0.25, 0.2, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.75, 0.8, 0.25, 0.8, 0, 0);
			}
		}
		else{
		rmPlacePlayer(1, 0.25, 0.2);
		rmPlacePlayer(2, 0.42, 0.2);
		rmPlacePlayer(3, 0.58, 0.2);
		rmPlacePlayer(4, 0.75, 0.2);
		rmPlacePlayer(5, 0.25, 0.8);
		rmPlacePlayer(6, 0.42, 0.8);
		rmPlacePlayer(7, 0.58, 0.8);
		rmPlacePlayer(8, 0.75, 0.8);
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
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, AvoidAboriginals);
	rmSetObjectDefMinDistance(TCID, 10.0);
	rmSetObjectDefMaxDistance(TCID, 17.0);

	// Starting mines
	int playerGoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerGoldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 8.0);
	rmSetObjectDefMaxDistance(playerGoldID, 25.0);
	rmAddObjectDefToClass(playerGoldID, classStartingResource);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerGoldID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerGoldID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerGoldID, avoidMountains);
	rmAddObjectDefConstraint(playerGoldID, longPlayerEdgeConstraint);

	// Starting Trees
	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "ypTreeEucalyptus", 15, 8.0);
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
	rmAddObjectDefConstraint(playerTreeID, avoidMountains);
	rmAddObjectDefConstraint(playerTreeID, longPlayerEdgeConstraint);

	// Starting berries
	int playerBerriesID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(playerBerriesID, "deTorpBush2", 6, 4.0);
	rmSetObjectDefMinDistance(playerBerriesID, 12);
	rmSetObjectDefMaxDistance(playerBerriesID, 12);
	rmSetObjectDefCreateHerd(playerBerriesID, true);
	rmAddObjectDefToClass(playerBerriesID, classStartingResource);		
	rmAddObjectDefConstraint(playerBerriesID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerBerriesID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerBerriesID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerBerriesID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerBerriesID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerBerriesID, avoidMountains);
	rmAddObjectDefConstraint(playerBerriesID, longPlayerEdgeConstraint);

	// Starting herds
	int playerHerdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerHerdID, "zpEmu", 6, 4.0);
	rmSetObjectDefMinDistance(playerHerdID, 12);
	rmSetObjectDefMaxDistance(playerHerdID, 25);
	rmSetObjectDefCreateHerd(playerHerdID, true);
	rmAddObjectDefToClass(playerHerdID, classStartingResource);		
	rmAddObjectDefConstraint(playerHerdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerHerdID, avoidTrainStationA);
	rmAddObjectDefConstraint(playerHerdID, avoidTrainStationB);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerHerdID, avoidMountains);
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
	rmAddObjectDefConstraint(playerNuggetID, avoidMountains);
	rmAddObjectDefConstraint(playerNuggetID, longPlayerEdgeConstraint);

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.6);

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
		rmPlaceObjectDefAtLoc(playerBerriesID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

    }


	// Text
	rmSetStatusText("",0.50);

	// Define North and South Directions

	int southBank=rmCreateArea("south bank");
	rmSetAreaCoherence(southBank, 1.0);
	rmAddAreaConstraint(southBank, avoidWater20);
	rmSetAreaObeyWorldCircleConstraint(southBank, false);
	rmSetAreaSize(southBank, 0.3, 0.3);
	rmSetAreaLocation(southBank, 0.1, 0.5);
	rmBuildArea(southBank);

	int northBank=rmCreateArea("north bank");
	rmSetAreaCoherence(northBank, 1.0);
	rmAddAreaConstraint(northBank, avoidWater20);
	rmSetAreaObeyWorldCircleConstraint(northBank, false);
	rmSetAreaSize(northBank, 0.3, 0.3);
	rmSetAreaLocation(northBank, 0.9, 0.5);
	rmBuildArea(northBank);

	//int northWest=rmCreateAreaConstraint("south constraint", southBank);
	//int southEast=rmCreateAreaConstraint("north constraint", northBank);

	

	// Mines

	int saltCount = (cNumberNonGaiaPlayers*1.5);

	for(i=0; < saltCount)
	{

		int lakeSaltMineID3 = rmCreateObjectDef("mine canyon "+i);
		rmAddObjectDefItem(lakeSaltMineID3, "minegold", 1, 0.0);
		rmSetObjectDefMinDistance(lakeSaltMineID3, 0.0);
		rmSetObjectDefMaxDistance(lakeSaltMineID3, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(lakeSaltMineID3, avoidCoin);
		rmAddObjectDefConstraint(lakeSaltMineID3, avoidAll);
		rmAddObjectDefConstraint(lakeSaltMineID3, avoidTradeRoute);
		rmAddObjectDefConstraint(lakeSaltMineID3, avoidSocket);
		rmAddObjectDefConstraint(lakeSaltMineID3, avoidWater10);
		rmAddObjectDefConstraint(lakeSaltMineID3, mountainsIDsConstraint);
		rmPlaceObjectDefAtLoc(lakeSaltMineID3, 0, 0.5, 0.5);

	}

	// Text
	rmSetStatusText("",0.60);

	// Random Cliffs

	int failCount = -1;
	int numTries = -1;


	for (j=0; < (6*cNumberNonGaiaPlayers)) {   
        int ffaCliffs = rmCreateArea("ffaCliffs"+j);
        rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(50), rmAreaTilesToFraction(50));
        rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
        rmSetAreaCliffType(ffaCliffs, "Deccan Plateau");
        rmSetAreaCliffEdge(ffaCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
        rmSetAreaCliffPainting(ffaCliffs, true, true, true, 1.5, true);
        rmSetAreaCliffHeight(ffaCliffs, rmRandInt(6,8), 1, 0.5);
        rmSetAreaSmoothDistance(ffaCliffs, 10);
        rmSetAreaHeightBlend(ffaCliffs, 3);
		rmAddAreaToClass(ffaCliffs, classSmallCliff);
		rmAddAreaConstraint(ffaCliffs, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(ffaCliffs, shortAvoidCoin);
		rmAddAreaConstraint(ffaCliffs, avoidTownCenterFar);
		rmAddAreaConstraint(ffaCliffs, avoidSmallCliffs);
		rmAddAreaConstraint(ffaCliffs, avoidInventors);
		rmAddAreaConstraint(ffaCliffs, avoidPenalColony);
		rmAddAreaConstraint(ffaCliffs, avoidTradeSocket);
		rmAddAreaConstraint(ffaCliffs, avoidHarbour);
		rmAddAreaConstraint(ffaCliffs, AvoidAboriginals);
		rmAddAreaConstraint(ffaCliffs, avoidTradeRouteFar2);
		rmAddAreaConstraint(ffaCliffs, avoidWater20);
		rmAddAreaConstraint(ffaCliffs, avoidKOTH);
        rmSetAreaCoherence(ffaCliffs, .93);

        rmBuildArea(ffaCliffs);  
    }


	// Forests

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 below
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, "z87 Australian Woodland");
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(northForest, shortAvoidCoin);
		rmAddAreaConstraint(northForest, avoidTownCenterFar);
		rmAddAreaConstraint(northForest, avoidInventors);
		rmAddAreaConstraint(northForest, avoidTradeSocket);
		rmAddAreaConstraint(northForest, avoidHarbour);
		rmAddAreaConstraint(northForest, AvoidAboriginals);
		rmAddAreaConstraint(northForest, avoidPenalColony);
		rmAddAreaConstraint(northForest, avoidTradeRoute);
		rmAddAreaConstraint(northForest, avoidSmallCliffsShort);
		rmAddAreaConstraint(northForest, avoidWater20);
		rmAddAreaConstraint(northForest, avoidKOTH);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, southEast);				// DAL adeed, to keep forests in the north.
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
		rmSetAreaForestType(southForest, "z87 Australian Woodland");
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidImportantItem);
		rmAddAreaConstraint(southForest, shortAvoidCoin);
		rmAddAreaConstraint(southForest, avoidTownCenterFar);
		rmAddAreaConstraint(southForest, avoidInventors);
		rmAddAreaConstraint(southForest, avoidTradeSocket);
		rmAddAreaConstraint(southForest, avoidHarbour);
		rmAddAreaConstraint(southForest, AvoidAboriginals);
		rmAddAreaConstraint(southForest, avoidTradeRoute);
		rmAddAreaConstraint(southForest, avoidPenalColony);
		rmAddAreaConstraint(southForest, avoidSmallCliffsShort);
		rmAddAreaConstraint(southForest, avoidWater20);
		rmAddAreaConstraint(southForest, avoidKOTH);
		rmAddAreaConstraint(southForest, forestConstraint);
		rmAddAreaConstraint(southForest, northWest);
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

	numTries=5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i=0; <numTries)
	{   
		int valleyForest=rmCreateArea("valleyForest"+i);
		rmSetAreaWarnFailure(valleyForest, false);
		rmSetAreaSize(valleyForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(valleyForest, "z87 Australian Woodland");
		rmSetAreaForestDensity(valleyForest, 1.0);
		rmAddAreaToClass(valleyForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(valleyForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(valleyForest, 0.0);
		rmSetAreaCoherence(valleyForest, 0.4);
		rmAddAreaConstraint(valleyForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(valleyForest, shortAvoidCoin);
		rmAddAreaConstraint(valleyForest, avoidTownCenterFar);
		rmAddAreaConstraint(valleyForest, avoidInventors);
		rmAddAreaConstraint(valleyForest, avoidTradeSocket);
		rmAddAreaConstraint(valleyForest, AvoidAboriginals);
		rmAddAreaConstraint(valleyForest, avoidPenalColony);
		rmAddAreaConstraint(valleyForest, avoidSmallCliffsShort);
		rmAddAreaConstraint(valleyForest, avoidKOTH);
		rmAddAreaConstraint(valleyForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(valleyForest, mountainsIDsConstraint);
		if(rmBuildArea(valleyForest)==false)
		{
			// Stop trying once we fail 5 times in a row.  
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount=0;
	}

	// Text
	rmSetStatusText("",0.70);

	// Place some extra deer herds.  
	int deerHerdID=rmCreateObjectDef("northern deer herd");
	rmAddObjectDefItem(deerHerdID, "zpRedKangaroo", rmRandInt(4,6), 6.0);
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
	rmAddObjectDefConstraint(deerHerdID, avoidMountains);
	rmAddObjectDefConstraint(deerHerdID, southEast);
	rmAddObjectDefConstraint(deerHerdID, avoidKangaroos);
	numTries=cNumberNonGaiaPlayers/2;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID, 0, 0.5, 0.5);
	}

	int deerHerdID2=rmCreateObjectDef("southern deer herd");
	rmAddObjectDefItem(deerHerdID2, "zpRedKangaroo", rmRandInt(4,6), 6.0);
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
	rmAddObjectDefConstraint(deerHerdID2, northWest);
	rmAddObjectDefConstraint(deerHerdID2, avoidMountains);
	rmAddObjectDefConstraint(deerHerdID2, avoidKangaroos);
	numTries=cNumberNonGaiaPlayers/2;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}

	int deerHerdID3=rmCreateObjectDef("middle deer herd");
	rmAddObjectDefItem(deerHerdID3, "zpEmu", rmRandInt(7,10), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID3, true);
	rmSetObjectDefMinDistance(deerHerdID3, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID3, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID3, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID3, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID3, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID3, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID3, avoidAll);
	rmAddObjectDefConstraint(deerHerdID3, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID3, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID3, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID3, mountainsIDsConstraint);
	numTries=cNumberNonGaiaPlayers*3;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID3, 0, 0.5, 0.5);
	}

    int mooseHerdID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseHerdID, "zpRedKangaroo", rmRandInt(6,10), 6.0);
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
	rmAddObjectDefConstraint(mooseHerdID, mountainsIDsConstraint);
	rmAddObjectDefConstraint(mooseHerdID, avoidKangaroos);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries/2)
	{
		rmPlaceObjectDefAtLoc(mooseHerdID, 0, 0.5, 0.5);
	}

	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "deTorpBush2", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, shortAvoidCoin);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidSmallCliffs);
	rmPlaceObjectDefInArea(berriesID, 0, mountainsID, cNumberNonGaiaPlayers*2);   //was *4

	// Text
	rmSetStatusText("",0.80);

    
	// Define and place Nuggets
    

	int nugget3= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmAddObjectDefToClass(nugget3, rmClassID("nuggets"));
	rmSetObjectDefMinDistance(nugget3, rmXFractionToMeters(0.00));
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nugget3, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNuggets);
	rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3, circleConstraint);
	rmAddObjectDefConstraint(nugget3, avoidKOTH);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidWater10);
	rmAddObjectDefConstraint(nugget3, mountainsIDsConstraint);
	rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

	int nugget2= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefToClass(nugget2, rmClassID("nuggets"));
	rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.00));
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nugget2, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNuggets);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidKOTH);
	rmAddObjectDefConstraint(nugget2, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget2, circleConstraint);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2,avoidWater20);
	rmAddObjectDefConstraint(nugget2,avoidMountains);
	rmAddObjectDefConstraint(nugget2,westConstraint);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.49));
	rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
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
	rmAddObjectDefConstraint(nugget1,avoidMountains);
	rmAddObjectDefConstraint(nugget1,eastConstraint);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.49));
	rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, cNumberNonGaiaPlayers);




	// Text
	rmSetStatusText("",0.90);

	// ------Triggers--------//

	// Stations
    string unitID00 = "5";
    string unitID01 = "227";
	string unitID1 = "18";
	string unitID2 = "68";
	string unitID3 = "118";
	string unitID4 = "168";
	string unitID5 = "238";
	string unitID6 = "288";
	string unitID7 = "338";
	string unitID8 = "388";
	string unitID9 = "438";


	// Cooldowns
	int armoredTrainActive = 90;
	int armoredTrainCooldown = 300;
	int armoredTrainCooldown2 = 240;
	int noStations = 2;
	int trainDirection = 22;

    if (cNumberNonGaiaPlayers <=2){
		unitID2 = "88";
        unitID01 = "77";
		noStations = 2;
		trainDirection = 22;
		}
    if (cNumberNonGaiaPlayers ==3){
		unitID3 = "138";
        unitID01 = "127";
		noStations = 3;
		trainDirection = 23;
		}
    if (cNumberNonGaiaPlayers ==4){
		unitID3 = "138";
        unitID4 = "188";
        unitID01 = "127";
		noStations = 4;
		trainDirection = 24;
		}
    if (cNumberNonGaiaPlayers ==5){
		unitID3 = "138";
        unitID4 = "188";
        unitID01 = "127";
		noStations = 5;
		trainDirection = 25;
		}
    if (cNumberNonGaiaPlayers ==6){
        unitID4 = "188";
        unitID01 = "177";
		noStations = 6;
		trainDirection = 26;
		}
	if (cNumberNonGaiaPlayers ==7){
		noStations = 7;
		trainDirection = 27;
		}
	if (cNumberNonGaiaPlayers ==8){
		noStations = 8;
		trainDirection = 28;
		}


    // Starting techs

    rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpLandScientists"); // Renegades Land Variant
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechdeMapDisableDock"); // Disable Dock
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpMapAustralian"); // Australian Designs
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpEnableTradeRouteAustralian"); // Australian land TR
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australia Mercenaries
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
	rmCreateTrigger("Khmer_Consulate"+k);

	rmCreateTrigger("Activate Consulate Khmer"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpAotWKhmers");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Khmer_Consulate"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Khmer_Consulate"+k));
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

	// Trade Route Setup

	rmCreateTrigger("AT_Initialize");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","false");
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
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+i);
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
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");

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

	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("II Update Sockets 1");

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


	// Normalize Trade Routes

	rmCreateTrigger("AT1_Normalize_TR");
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1000);

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
	rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
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
	rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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
	rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
	rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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
        rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
        rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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
        rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
        rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","true");

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
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
		rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","true");

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
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
		rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","true");

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
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
		rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","true");

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
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name 
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
		rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
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
	rmAddTriggerEffect("ZP Counter Visible for Player");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Player",k);
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
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","RenegadeControl_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	
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
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
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
	rmAddTriggerEffect("Counter Visible");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParam("Visible", "false");
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
	rmAddTriggerEffect("Counter Visible");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParam("Visible", "false");
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
	}


    // Renegades Control

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Control_Renegades_ON"+k);
	rmCreateTrigger("Control_Renegades_OFF"+k);

	rmSwitchToTrigger(rmTriggerID("Control_Renegades_ON"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpNativeScientists");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Control_Renegades_OFF"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	
	rmSwitchToTrigger(rmTriggerID("Control_Renegades_OFF"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpNativeScientists");
	rmSetTriggerConditionParamInt("Status",0);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+k);
	rmSetTriggerEffectParamInt("Value",0);

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
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Control_Renegades_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}


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
	
	
	// Text
	rmSetStatusText("",1.00);
	
} // END