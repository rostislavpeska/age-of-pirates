// WILD WEST
// January 2024

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

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
  
		subCiv2=rmGetCivID("comanche");
		rmEchoInfo("subCiv2 is comanche "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "comanche");
	}

    // Picks the map size
	int playerTiles = 18000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 15000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 11000;			

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(6.0);
   
   // LIGHT SET

	rmSetLightingSet("Texas_Skirmish");


	// Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("texas_dirt_Skirmish");
	rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
	rmSetMapType("texas");
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

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
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

	// Nature avoidance
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 35.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineGold", 20.0);
	int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 20.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);

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

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 5.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 16.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 5.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "SocketComanche", 70.0);
	int avoidSufiShort=rmCreateTypeDistanceConstraint("stay away from Sufi short", "SocketComanche", 30.0);
	int avoidMaltese=rmCreateTypeDistanceConstraint("stay away from Maltese", "zpSocketScientists", 25.0);
	int avoidJewish=rmCreateTypeDistanceConstraint("stay away from Jewish", "zpSPCSocketWesternVillage", 25.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

   // KOTH
   int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

   // Text
	rmSetStatusText("",0.01);


   	float playerFraction=rmAreaTilesToFraction(850);

	// ************************ PLACE PLACE TRADE ROUTES  *******************************

    // Define Stoppers
	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmAddObjectDefItem(socketID, "zpTradingPostCaptureInvisible", 1, 0.0);
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

	// Define Station Groupings

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

	// Even / Odd Player versions

	if (cNumberNonGaiaPlayers <=2 || cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==6 || cNumberNonGaiaPlayers ==8)
		evenOdd =2;
	else
		evenOdd =1;

	// Even Players

	if (evenOdd==2){

		// Trade Route 1

		int tradeRouteID = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.0);

		
		rmBuildTradeRoute(tradeRouteID, "dirt");
		
		// Place stations 1

		vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
		vector StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));

		if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.39);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			vector StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));


			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.61);
			rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc1);
			vector StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));

		}

		if (cNumberNonGaiaPlayers ==6){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
			rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
			StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
			rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		}

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
		rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
		vector StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));

		// Armored Train 1

		int tradeRouteID2 = rmCreateTradeRoute();
		//rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.1, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.1, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.7, 0.0);
		
		rmBuildTradeRoute(tradeRouteID2, "armored_train");

		// Trade Route 2

		int tradeRouteID3 = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(stopperID5, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID6, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID7, tradeRouteID3);
		rmSetObjectDefTradeRouteID(stopperID8, tradeRouteID3);
		rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.9, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.9, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.6, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.4, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, 1.0);

		rmBuildTradeRoute(tradeRouteID3, "dirt");

		// Place Stations 2

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.2);
		rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
		vector StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)+2), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlaceGroupingAtLoc(stationGrouping002, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)+2), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));

		if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.39);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			vector StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping006, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.61);
			rmPlaceObjectDefAtPoint(stopperID7, 0, socketLoc1);
			vector StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
			rmPlaceGroupingAtLoc(stationGrouping006, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		}

		if (cNumberNonGaiaPlayers ==6){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.50);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping006, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		}
		
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID3, 0.8);
		rmPlaceObjectDefAtPoint(stopperID8, 0, socketLoc1);
		vector StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		rmPlaceGroupingAtLoc(stationGrouping004, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));

		// Armored Train 2

		int tradeRouteID4 = rmCreateTradeRoute();
		//rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);
		rmAddTradeRouteWaypoint(tradeRouteID4, 1.0, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.9, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.9, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.6, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.3, 1.0);
		
		rmBuildTradeRoute(tradeRouteID4, "armored_train");

	}

	if (evenOdd==1){

		// Trade Route Odd

		tradeRouteID = rmCreateTradeRoute();
		rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID5, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID6, tradeRouteID);
		rmSetObjectDefTradeRouteID(stopperID7, tradeRouteID);
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.4);
		if (cNumberNonGaiaPlayers ==7)
			rmAddTradeRouteWaypoint(tradeRouteID, 0.61, 0.09);
		else
			rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.4);
		if (cNumberNonGaiaPlayers ==7)
			rmAddTradeRouteWaypoint(tradeRouteID, 0.09, 0.61);
		else
			rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 1.0);
		
		rmBuildTradeRoute(tradeRouteID, "dirt");

		// Place stations Odd

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
		StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc1);
		StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
		rmPlaceGroupingAtLoc(stationGrouping03, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlaceGroupingAtLoc(stationGrouping005, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
		rmPlaceObjectDefAtPoint(stopperID3, 0, socketLoc1);
		StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
		rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));

		if (cNumberNonGaiaPlayers ==7){	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.24);
			rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
			StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.76);
			rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
			StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.64);
			rmPlaceObjectDefAtPoint(stopperID6, 0, socketLoc1);
			StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
			rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
			
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.36);
			rmPlaceObjectDefAtPoint(stopperID7, 0, socketLoc1);
			StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
			rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
			rmPlaceGroupingAtLoc(stationGrouping003, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		}

		else {	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.285);
			rmPlaceObjectDefAtPoint(stopperID4, 0, socketLoc1);
			StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
			
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.715);
			rmPlaceObjectDefAtPoint(stopperID5, 0, socketLoc1);
			StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
			rmPlaceGroupingAtLoc(stationGrouping04, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
			rmPlaceGroupingAtLoc(stationGrouping007, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		}

		// Armored Train Odd

		tradeRouteID2 = rmCreateTradeRoute();
		rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.9, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.9, 0.4);
		if (cNumberNonGaiaPlayers ==7)
			rmAddTradeRouteWaypoint(tradeRouteID2, 0.61, 0.09);
		else
			rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.1);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.1, 0.4);
		if (cNumberNonGaiaPlayers ==7)
			rmAddTradeRouteWaypoint(tradeRouteID2, 0.09, 0.61);
		else
			rmAddTradeRouteWaypoint(tradeRouteID2, 0.1, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.9);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.7, 1.0);
		
		rmBuildTradeRoute(tradeRouteID2, "armored_train");

	}

	// Text
	rmSetStatusText("",0.10);

	// ********************	FIX POSITION NATIVES ********************


	// Western Village

	int jewish1VillageTypeID = rmRandInt(1, 5);
	int jewish2VillageTypeID = rmRandInt(1, 5);
	int jewish3VillageTypeID = rmRandInt(1, 2);

	int jewish1ID = rmCreateGrouping("jewish 1", "WildWest_Village_0"+jewish1VillageTypeID);
	int jewish2ID = rmCreateGrouping("jewish 2", "WildWest_Village_0"+jewish2VillageTypeID);
	int jewish3ID = rmCreateGrouping("jewish 3", "WildWest_Village_0"+jewish3VillageTypeID);

	rmSetGroupingMinDistance(jewish1ID, 0);
	rmSetGroupingMaxDistance(jewish1ID, 0);
	rmSetGroupingMinDistance(jewish2ID, 0);
	rmSetGroupingMaxDistance(jewish2ID, 0);
	rmSetGroupingMinDistance(jewish3ID, 0);
	rmSetGroupingMaxDistance(jewish3ID, 0); 

	if(cNumberNonGaiaPlayers <= 2){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.81, 0.5, 1);
	}
	if(cNumberNonGaiaPlayers == 3){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.65, 0.25, 1);
	}
	if(cNumberNonGaiaPlayers == 4){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.9, 0.7, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.1, 0.3, 1);
	}
	if(cNumberNonGaiaPlayers == 5){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.25, 0.85, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.3, 0.3, 1);
	}
	if(cNumberNonGaiaPlayers == 6){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.25, 0.85, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.75, 0.15, 1);
	}
	if(cNumberNonGaiaPlayers == 7){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.75, 0.85, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.6, 0.2, 1);
	}
	if(cNumberNonGaiaPlayers == 8){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.25, 0.85, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.75, 0.15, 1);
	}

	// Renegades

	int maltese1VillageTypeID = rmRandInt(5,6);
	int maltese1ID = -1;
	maltese1ID = rmCreateGrouping("maltese 1", "Scientist_Lab0"+maltese1VillageTypeID);
	rmSetGroupingMinDistance(maltese1ID, 0);
	rmSetGroupingMaxDistance(maltese1ID, 0);
  

	int maltese2VillageTypeID = 11-maltese1VillageTypeID;
	int maltese2ID = -1;
	maltese2ID = rmCreateGrouping("maltese 2", "Scientist_Lab0"+maltese2VillageTypeID);
	rmSetGroupingMinDistance(maltese2ID, 0);
	rmSetGroupingMaxDistance(maltese2ID, 0);


   	if(cNumberNonGaiaPlayers <= 2){	
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.21, 0.5, 1);
	}
	if(cNumberNonGaiaPlayers == 3){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.25, 0.65, 1);
	}
	if(cNumberNonGaiaPlayers == 4){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.72, 0.88, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.3, 0.1, 1);
	}
	if(cNumberNonGaiaPlayers == 5){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.85, 0.25, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.8, 0.8, 1);
	}
	if(cNumberNonGaiaPlayers == 6){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.15, 0.75, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.85, 0.25, 1);
	}
	if(cNumberNonGaiaPlayers == 7){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.85, 0.75, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.2, 0.6, 1);
	}
	if(cNumberNonGaiaPlayers == 8){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.15, 0.75, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.85, 0.25, 1);
	}

	// Text
	rmSetStatusText("",0.20);


	// ************************ PLACE TERRAIN *******************************

   	// Dead Sea Valley
    int DeadSeaValleyID = rmCreateArea ("dead sea valley");
    rmSetAreaSize(DeadSeaValleyID, 0.3, 0.3);
    rmSetAreaLocation(DeadSeaValleyID, 0.5, 0.5);
    rmSetAreaCoherence(DeadSeaValleyID, 0.7);
    rmSetAreaMinBlobs(DeadSeaValleyID, 8);
    rmSetAreaMaxBlobs(DeadSeaValleyID, 12);
    rmSetAreaMinBlobDistance(DeadSeaValleyID, 8.0);
    rmSetAreaMaxBlobDistance(DeadSeaValleyID, 10.0);
    rmSetAreaSmoothDistance(DeadSeaValleyID, 15);
    rmSetAreaCliffType(DeadSeaValleyID, "Texas");
    rmSetAreaCliffEdge(DeadSeaValleyID, 1, 1.0, 0.0, 0.5, 0);
    rmSetAreaCliffHeight(DeadSeaValleyID, -0.1, 0.0, 0.5);
    rmSetAreaBaseHeight(DeadSeaValleyID, 0.0);
    rmSetAreaElevationType(DeadSeaValleyID, cElevTurbulence);
    rmSetAreaElevationVariation(DeadSeaValleyID, 2.0);
    rmSetAreaElevationPersistence(DeadSeaValleyID, 0.2);
    rmSetAreaElevationNoiseBias(DeadSeaValleyID, 1);
	if (evenOdd==2){
		rmAddAreaInfluenceSegment(DeadSeaValleyID, 0.35, 0.65, 0.65, 0.35);
		rmAddAreaInfluenceSegment(DeadSeaValleyID, 0.45, 0.45, 0.55, 0.55);
	}
	rmAddAreaConstraint(DeadSeaValleyID, avoidTradeSocketFar);
	rmAddAreaConstraint(DeadSeaValleyID, avoidMaltese);
	rmAddAreaConstraint(DeadSeaValleyID, avoidJewish);
	rmAddAreaConstraint(DeadSeaValleyID, avoidTradeRoute);
    rmBuildArea(DeadSeaValleyID);

	int DeadSeaValleyMixID = rmCreateArea ("dead sea valley mix");
    rmSetAreaSize(DeadSeaValleyMixID, 0.27, 0.27);
    rmSetAreaLocation(DeadSeaValleyMixID, 0.5, 0.5);
    rmSetAreaCoherence(DeadSeaValleyMixID, 0.9);
    rmSetAreaMix(DeadSeaValleyMixID, "texas_grass");
	if (evenOdd==2){
		rmAddAreaInfluenceSegment(DeadSeaValleyMixID, 0.35, 0.65, 0.65, 0.35);
		rmAddAreaInfluenceSegment(DeadSeaValleyMixID, 0.45, 0.45, 0.55, 0.55);
	}
	rmAddAreaConstraint(DeadSeaValleyMixID, avoidMaltese);
	rmAddAreaConstraint(DeadSeaValleyMixID, avoidJewish);
	rmAddAreaConstraint(DeadSeaValleyMixID, avoidTradeSocketFar2);
	rmAddAreaConstraint(DeadSeaValleyMixID, avoidTradeRoute);
    rmBuildArea(DeadSeaValleyMixID);

	int valleyConstraint=rmCreateAreaConstraint("valley constraint", DeadSeaValleyID);
	int avoidValley=rmCreateAreaDistanceConstraint("avoid valley", DeadSeaValleyID, 10); 

	//King of the Hill
	
	if (rmGetIsKOTH() == true) {
         ypKingsHillPlacer(0.5, 0.5, 0, 0);
	}

	else {
   	int deadSeaLakeID=rmCreateArea("Dead Sea Lake Shallow");
	rmSetAreaWaterType(deadSeaLakeID, "Texas Pond");
	rmSetAreaSize(deadSeaLakeID, 0.007, 0.007);
	rmSetAreaCoherence(deadSeaLakeID, 0.6);
	rmSetAreaLocation(deadSeaLakeID, 0.5, 0.5);
	rmAddAreaToClass(deadSeaLakeID, classGreatLake);
	rmSetAreaBaseHeight(deadSeaLakeID, 0.0);
	rmSetAreaObeyWorldCircleConstraint(deadSeaLakeID, false);
	rmSetAreaSmoothDistance(deadSeaLakeID, 10);
	rmBuildArea(deadSeaLakeID); 
	}

	// Text
	rmSetStatusText("",0.30);
    
	// Place Players

	float teamStartLoc = rmRandFloat(0.0, 1.0);

	if (cNumberNonGaiaPlayers <= 2){
		rmSetPlacementSection(0.995, 0.495); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.395, 0.395, 0);
		}

	if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7){
		rmSetPlacementSection(0.245, 0.995); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.395, 0.395, 0);
		}

	// 4 players in 2 teams
	if (cNumberNonGaiaPlayers == 4){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.995, 0.245); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.995, 0.245);
			rmPlacePlayersCircular(0.395, 0.395, 0);
			}
		}
		else{
		rmSetPlacementSection(0.995, 0.745); 
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.395, 0.395, 0);
		}
	}

	if (cNumberNonGaiaPlayers == 6){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.995, 0.245); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.995, 0.245);
			rmPlacePlayersCircular(0.395, 0.395, 0);
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

	if (cNumberNonGaiaPlayers == 8){
		if(cNumberTeams == 2){
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.995, 0.245); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			}
			else
			{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.495, 0.745); 
			rmPlacePlayersCircular(0.395, 0.395, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.995, 0.245);
			rmPlacePlayersCircular(0.395, 0.395, 0);
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
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmSetObjectDefMinDistance(TCID, 10.0);
	rmSetObjectDefMaxDistance(TCID, 17.0);

	// Starting mines
	int playerGoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerGoldID, "MineCopper", 1, 0);
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
	rmAddObjectDefItem(playerTreeID, "TreeSonora", 15, 8.0);
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
	rmAddObjectDefItem(playerHerdID, "pronghorn", 8, 4.0);
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

	// Fake grouping - prevent autogrouping Bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

	// Place objects
	for(i=1; <numPlayer)
		{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		}

	for(i=1; <numPlayer)
		{
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
		
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	}


	// Text
	rmSetStatusText("",0.40);

	// ************************************* Place Natives **************************************

	int villageCircle = rmRandInt(1,3);

	int sufi1VillageTypeID = rmRandInt(1,5);
	int mosque1ID = -1;
	mosque1ID = rmCreateGrouping("mosque 1", "native comanche village "+sufi1VillageTypeID);
	rmSetGroupingMinDistance(mosque1ID, 20);
	rmSetGroupingMaxDistance(mosque1ID, rmXFractionToMeters(0.2));
	rmAddGroupingConstraint(mosque1ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque1ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque1ID, circleConstraint);
	rmAddGroupingConstraint(mosque1ID, avoidSufi);
	rmPlaceGroupingAtLoc(mosque1ID, 0, 0.5, 0.5, 1);


	int sufi2VillageTypeID = rmRandInt(1,5);
	int mosque2ID = -1;
	mosque2ID = rmCreateGrouping("mosque 2", "native comanche village "+sufi2VillageTypeID);
	rmSetGroupingMinDistance(mosque2ID, 20);
	rmSetGroupingMaxDistance(mosque2ID, rmXFractionToMeters(0.2));
	rmAddGroupingConstraint(mosque2ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque2ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque2ID, avoidSufi);
	rmAddGroupingConstraint(mosque2ID, circleConstraint);
	rmPlaceGroupingAtLoc(mosque2ID, 0, 0.5, 0.5, 1);


	if(cNumberNonGaiaPlayers >= 4){
		int sufi3VillageTypeID = rmRandInt(1,5);
		int mosque3ID = -1;
		mosque3ID = rmCreateGrouping("Sufi Village 3", "native comanche village "+sufi3VillageTypeID);
		rmSetGroupingMinDistance(mosque3ID, 20);
		rmSetGroupingMaxDistance(mosque3ID, rmXFractionToMeters(0.2));
		rmAddGroupingConstraint(mosque3ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque3ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque3ID, circleConstraint);
		rmAddGroupingConstraint(mosque3ID, avoidSufi);
		rmPlaceGroupingAtLoc(mosque3ID, 0, 0.5, 0.5, 1);
	}

	if(cNumberNonGaiaPlayers >= 7){
		int sufi4VillageTypeID = rmRandInt(1,5);
		int mosque4ID = -1;
		mosque4ID = rmCreateGrouping("Sufi Village 4", "native comanche village "+sufi4VillageTypeID);
		rmSetGroupingMinDistance(mosque4ID, 20);
		rmSetGroupingMaxDistance(mosque4ID, rmXFractionToMeters(0.2));
		rmAddGroupingConstraint(mosque4ID, avoidImpassableLand);
		rmAddGroupingConstraint(mosque4ID, avoidTownCenterFar);
		rmAddGroupingConstraint(mosque4ID, circleConstraint);
		rmAddGroupingConstraint(mosque4ID, avoidSufi);
		rmPlaceGroupingAtLoc(mosque4ID, 0, 0.5, 0.5, 1);
	}

	// Text
	rmSetStatusText("",0.50);

	// Mines

	int saltCount = (cNumberNonGaiaPlayers*4);

	for(i=0; < saltCount)
	{
		int  lakeSaltMineID = rmCreateObjectDef("lake mine salt "+i);
		rmAddObjectDefItem(lakeSaltMineID, "MineGold", 1, 0.0);
		rmSetObjectDefMinDistance(lakeSaltMineID, 0.0);
		rmSetObjectDefMaxDistance(lakeSaltMineID, rmXFractionToMeters(0.25));
		rmAddObjectDefConstraint(lakeSaltMineID, avoidCoin);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidAll);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidTradeRoute);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidSocket);
		rmAddObjectDefConstraint(lakeSaltMineID, avoidWater20);
		rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.5, 0.5);
	}

	for(i=0; < cNumberNonGaiaPlayers*2)
	{
		int berriesID = rmCreateObjectDef("berries"+i);
		rmAddObjectDefItem(berriesID, "berrybush", 3, 4.0);
		rmSetObjectDefMinDistance(berriesID, 0.0);
		rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.25));
		rmAddObjectDefConstraint(berriesID, avoidCoin);
		rmAddObjectDefConstraint(berriesID, avoidAll);
		rmAddObjectDefConstraint(berriesID, avoidTradeRoute);
		rmAddObjectDefConstraint(berriesID, avoidSocket);
		rmAddObjectDefConstraint(berriesID, avoidWater20);
		rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5);
	}

	// Text
	rmSetStatusText("",0.60);


	// ******************* FORESTS ********************

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south

	// Valley Forrest

	int forestTreeID = 0;
	
	numTries=10+4*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i=0; <numTries)
	{   
		int valleyForest=rmCreateArea("valleyForest"+i);
		rmSetAreaWarnFailure(valleyForest, false);
		rmSetAreaSize(valleyForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(valleyForest, "Texas Forest");
		rmSetAreaForestDensity(valleyForest, 1.0);
		rmAddAreaToClass(valleyForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(valleyForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(valleyForest, 0.0);
		rmSetAreaCoherence(valleyForest, 0.4);
		rmAddAreaConstraint(valleyForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(valleyForest, shortAvoidCoin);
		rmAddAreaConstraint(valleyForest, avoidTownCenterFar);
		rmAddAreaConstraint(valleyForest, avoidJewish);
		rmAddAreaConstraint(valleyForest, avoidMaltese);
		rmAddAreaConstraint(valleyForest, avoidTradeSocket);
		rmAddAreaConstraint(valleyForest, avoidSufiShort);
		rmAddAreaConstraint(valleyForest, avoidTradeRoute);
		rmAddAreaConstraint(valleyForest, avoidWater20);
		rmAddAreaConstraint(valleyForest, avoidKOTH);
		rmAddAreaConstraint(valleyForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(valleyForest, valleyConstraint);
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

	// Cliff Forrests
	
	numTries=4+2*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		rmSetAreaForestType(southForest, "Texas Forest Dirt");
		rmSetAreaForestDensity(southForest, 0.7);
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
		rmAddAreaConstraint(southForest, avoidSufi);
		rmAddAreaConstraint(southForest, avoidTradeRoute);
		rmAddAreaConstraint(southForest, avoidWater20);
		rmAddAreaConstraint(southForest, avoidKOTH);
		rmAddAreaConstraint(southForest, forestConstraint);
		rmAddAreaConstraint(southForest, Southward);
		rmAddAreaConstraint(southForest, avoidValley);	
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

	numTries=4+2*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 below.
	failCount=0;
	for (i=0; <numTries)
	{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, "Texas Forest Dirt");
		rmSetAreaForestDensity(northForest, 0.7);
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
		rmAddAreaConstraint(northForest, avoidSufi);
		rmAddAreaConstraint(northForest, avoidTradeRoute);
		rmAddAreaConstraint(northForest, avoidWater20);
		rmAddAreaConstraint(northForest, avoidKOTH);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, Northward);
		rmAddAreaConstraint(northForest, avoidValley);				// DAL adeed, to keep forests in the north.
		if(rmBuildArea(northForest)==false)
		{
			// Stop trying once we fail 5 times in a row.  
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount = 0;
	}
   
	// Text
	rmSetStatusText("",0.70);

	// Fauna: Bisons and Deers

	int deerHerdID2=rmCreateObjectDef("southern deer herd");
	rmAddObjectDefItem(deerHerdID2, "bison", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID2, true);
	rmSetObjectDefMinDistance(deerHerdID2, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID2, rmXFractionToMeters(0.25));
	rmAddObjectDefConstraint(deerHerdID2, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID2, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID2, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID2, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID2, avoidAll);
	rmAddObjectDefConstraint(deerHerdID2, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID2, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID2, deerConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}

	int mooseHerdID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseHerdID, "deer", rmRandInt(5,9), 6.0);
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
	rmSetObjectDefMinDistance(nugget4, rmXFractionToMeters(0.05));
	rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.25));
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
	rmSetObjectDefMinDistance(nugget3, rmXFractionToMeters(0.05));
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.25));
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
	rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.25));
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

	// Define and place decorations: rocks and grass and stuff 

	// Random Vegetation
	float treeOne = rmRandInt(1,4);

	int dryGrassID = rmCreateObjectDef("dry grass");
	rmAddObjectDefItem(dryGrassID, "UnderbrushTexas", rmRandInt(3,5), 10.0);
	rmAddObjectDefItem(dryGrassID, "UnderbrushTexasGrass", rmRandInt(1,2), 6.0);
	rmSetObjectDefMinDistance(dryGrassID, 0);
	rmSetObjectDefMaxDistance(dryGrassID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(dryGrassID, avoidStartingResources);
	rmAddObjectDefConstraint(dryGrassID, avoidWater4);
	rmAddObjectDefConstraint(dryGrassID, avoidSufiShort);
	rmAddObjectDefConstraint(dryGrassID, shortAvoidCoin);
	rmAddObjectDefConstraint(dryGrassID, avoidTradeRouteSocketMin);
	rmPlaceObjectDefAtLoc(dryGrassID, 0, 0.50, 0.50, 10*PlayerNum);


	int rockID=rmCreateObjectDef("lone rock");
	int avoidRock=rmCreateTypeDistanceConstraint("avoid rock", "BigPropTexas", 50.0);
	rmAddObjectDefItem(rockID, "BigPropTexas", 1, 0.0);
	rmSetObjectDefMinDistance(rockID, rmXFractionToMeters(0.25));
	rmSetObjectDefMaxDistance(rockID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(rockID, avoidAll);
	rmAddObjectDefConstraint(rockID, avoidImpassableLand);
	rmAddObjectDefConstraint(rockID, avoidKOTH);
	rmAddObjectDefConstraint(rockID, avoidTownCenter);
	rmAddObjectDefConstraint(rockID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(rockID, avoidTradeSocket);
	rmAddObjectDefConstraint(rockID, avoidRock);
	rmPlaceObjectDefAtLoc(rockID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);


 	// Text
	rmSetStatusText("",0.90);

	// ------Triggers--------//
	string unitID1 = "8";
	string unitID2 = "58";
	string unitID3 = "108";
	string unitID4 = "158";
	string unitID5 = "208";
	string unitID6 = "258";
	string unitID7 = "308";
	string unitID8 = "358";
	int armoredTrainActive = 90;
	int armoredTrainCooldown = 300;
	int armoredTrainCooldown2 = 240;

	if (cNumberNonGaiaPlayers <=2){
		unitID1 = "8";
		unitID2 = "58";
		unitID3 = "121";
		unitID4 = "171";
		}
	if (cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==7){
		unitID1 = "8";
		unitID2 = "58";
		unitID3 = "108";
		unitID4 = "158";
		unitID5 = "208";
		unitID6 = "258";
		unitID7 = "308";
		}
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){
		unitID1 = "8";
		unitID2 = "58";
		unitID3 = "108";
		unitID4 = "158";
		unitID5 = "221";
		unitID6 = "271";
		unitID7 = "321";
		unitID8 = "371";
		}
	if (cNumberNonGaiaPlayers ==6){
		unitID1 = "8";
		unitID2 = "58";
		unitID3 = "108";
		unitID4 = "171";
		unitID5 = "221";
		unitID6 = "271";
		}

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=1; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpLandScientists"); // Renegades Land Variant
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechdeMapDisableDock"); // Disable Dock
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmer"+k));
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
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	if (evenOdd==2){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
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
	if (evenOdd==2){
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParamInt("Level",2);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
	}
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

	if (evenOdd==1){
		rmCreateTrigger("I Update Sockets");
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",0);
		rmSetTriggerConditionParam("Protounit","Stagecoach");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("II Update Sockets");
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",0);
		rmSetTriggerConditionParam("Protounit","TrainEngine");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
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
	}

	if (evenOdd==2){
		rmCreateTrigger("I Update Sockets 1");
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID1);
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
		rmSetTriggerConditionParam("DstObject",unitID1);
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
		if (cNumberNonGaiaPlayers <= 2)
			rmSetTriggerConditionParam("DstObject",unitID3);
		if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers == 8)
			rmSetTriggerConditionParam("DstObject",unitID5);
		if (cNumberNonGaiaPlayers ==6)
			rmSetTriggerConditionParam("DstObject",unitID4);
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
		if (cNumberNonGaiaPlayers <= 2)
			rmSetTriggerConditionParam("DstObject",unitID3);
		if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers == 8)
			rmSetTriggerConditionParam("DstObject",unitID5);
		if (cNumberNonGaiaPlayers ==6)
			rmSetTriggerConditionParam("DstObject",unitID4);
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
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	if (evenOdd==2){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",4);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ****** ARMORED TRAIN SEND AND STOP ******

	// Define Triggers

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT1_Send_Station1_Plr"+k);
	rmCreateTrigger("AT1_Send_Station2_Plr"+k);
	rmCreateTrigger("AT1_Send_Station3_Plr"+k);
	rmCreateTrigger("AT1_Send_Station4_Plr"+k);
	if (cNumberNonGaiaPlayers >= 3)
		rmCreateTrigger("AT1_Send_Station5_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 6)
		rmCreateTrigger("AT1_Send_Station6_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 7)
		rmCreateTrigger("AT1_Send_Station7_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers == 8)
		rmCreateTrigger("AT1_Send_Station8_Plr"+k);

	rmCreateTrigger("AT1_STOP_Station1_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station2_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station3_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station4_Plr"+k);
	if (cNumberNonGaiaPlayers >= 3)
		rmCreateTrigger("AT1_STOP_Station5_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 6)
		rmCreateTrigger("AT1_STOP_Station6_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 7)
	rmCreateTrigger("AT1_STOP_Station7_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers == 8)
		rmCreateTrigger("AT1_STOP_Station8_Plr"+k);

	rmCreateTrigger("AT1_Break_Station1_Plr"+k);
	rmCreateTrigger("AT1_Break_Station2_Plr"+k);
	rmCreateTrigger("AT1_Break_Station3_Plr"+k);
	rmCreateTrigger("AT1_Break_Station4_Plr"+k);
	if (cNumberNonGaiaPlayers >= 3)
		rmCreateTrigger("AT1_Break_Station5_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 6)
		rmCreateTrigger("AT1_Break_Station6_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers >= 7)
	rmCreateTrigger("AT1_Break_Station7_Plr"+k);
	if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers == 8)
		rmCreateTrigger("AT1_Break_Station8_Plr"+k);

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
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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


	// Station 3

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID3);
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
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	// Station 4

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station4_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID4);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	if (cNumberNonGaiaPlayers <=2 || cNumberNonGaiaPlayers ==6){
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
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	
	if (cNumberNonGaiaPlayers >= 3){
		
		// Station 5

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		if (cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==6 || cNumberNonGaiaPlayers ==8){
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
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers >=6){

		// Station 6

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		if (cNumberNonGaiaPlayers ==7){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
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
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers >=7){
		// Station 7

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		if (cNumberNonGaiaPlayers ==7){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",1);
			rmSetTriggerEffectParam("ShowUnit","false");
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
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
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers ==8){
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
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
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

	if (cNumberNonGaiaPlayers >= 3){

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

		if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers >=6){

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

		if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers >=7){

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

		if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers ==8){

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
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}*/
	
	
	// Text
	rmSetStatusText("",1.00);
	
} // END