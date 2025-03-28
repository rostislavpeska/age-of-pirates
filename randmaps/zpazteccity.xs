// AZTEC CITY DEFENSE
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
		subCiv0=rmGetCivID("aztecs");
		rmEchoInfo("subCiv0 is aztecs "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "aztecs");

		subCiv1=rmGetCivID("spcjesuit");
		rmEchoInfo("subCiv1 is spcjesuit "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "spcjesuit");

		subCiv2=rmGetCivID("maltese");
		rmEchoInfo("subCiv2 is maltese "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "maltese");
	}

    int size = 540;
	if (cNumberNonGaiaPlayers > 4){
	size = 600;
	}

	// Initialize Defender Player

	int teamTwoCount = rmGetNumberPlayersOnTeam(1);
	int teamOneCount = rmGetNumberPlayersOnTeam(0);

	int firstDefender = -1;
	for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == 1)
        {
            firstDefender = i;
            break;
        }
    }


	rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(1.0);
   
   	// LIGHT SET

	rmSetLightingSet("mexico_Skirmish");


	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("ZP Aztec Lake");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
    //rmSetSeaType(seaType);
    rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetMapType("water");
    rmSetMapType("mexico");
    rmSetMapType("default");
	rmSetMapType("piratehistoricalmap");

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
	int classCityBlock=rmDefineClass("cityBlock");

	float mapRadius = sqrt(rmGetMapXSize() * rmGetMapXSize() + rmGetMapZSize() * rmGetMapZSize()) / 2.0;

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 20.0);
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
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineCopper", 60.0);
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
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 70.0);
	int avoidNuggetsShort=rmCreateTypeDistanceConstraint("nugget avoid nugget short", "abstractNugget", 40.0);
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
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 1.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int flagVsDistrict1 = rmCreateTypeDistanceConstraint("flag avoid District 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsDistrict2 = rmCreateTypeDistanceConstraint("flag avoid District 2", "zpNativeWaterSpawnFlag2", 40.0);
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

    // Additional Constraints - based on dansil original constraints
    int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);
    int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.2, 0.0, 0.453, 1.0);
    int cityNorthConstraint = rmCreateBoxConstraint("stay in the city north", 0.557, 0.0, 0.8, 1.0);

    int classPatch = rmDefineClass("patch");
    int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 1.0);
	int avoidPlateau = rmCreateClassDistanceConstraint("avoid patch 2", rmClassID("classPlateau"), 10.0);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	int avoidCenterPoint = rmCreateTypeDistanceConstraint("avoid center point", "zpSPCWaterSpawnPointB", 110.0);
    int avoidCenterPointLong = rmCreateTypeDistanceConstraint("avoid center point long", "zpSPCWaterSpawnPointB", 200.0);
	int avoidCenterPointUltraLong = rmCreateTypeDistanceConstraint("avoid center point ultra long", "zpSPCWaterSpawnPointB", 1.3 * mapRadius);

	int aztecCityConstraint = rmCreateBoxConstraint("stay in the aztec city", 0.5-rmXTilesToFraction(62), 0.5-rmZTilesToFraction(42), 0.5+rmXTilesToFraction(62), 0.5+rmZTilesToFraction(42));
	int aztecCityConstraint2 = rmCreateBoxConstraint("stay in the aztec city 2", 0.5-rmXTilesToFraction(42), 0.5-rmZTilesToFraction(62), 0.5+rmXTilesToFraction(42), 0.5+rmZTilesToFraction(62));

	int avoidCity = rmCreateClassDistanceConstraint("avoid city block", classCityBlock, 30.0);
	
	int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), 6.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);
	int avoidJesuit=rmCreateTypeDistanceConstraint("avoid Jesuit Cathedral", "zpJesuitCathedral", 30.0);
	
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 80.0);	//Attempting to spread them out more evenly.
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", "Bison", 60.0);
	int avoidLandFish = rmCreateTerrainDistanceConstraint("avoid land medium fish", "Water", false, 6.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);


	// ********************* Trade Route *******************************

    // Trade route must be always placed as first
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

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);  
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.5-rmXTilesToFraction(65));
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.5-rmXTilesToFraction(30));
    rmBuildTradeRoute(tradeRouteID, "native_water_trail");

	int tradeRouteID2 = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID2);  
    rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.5);
    rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.5);
    rmBuildTradeRoute(tradeRouteID2, "dirt");

	int tradeRouteID3 = rmCreateTradeRoute();
    rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 0.5+rmXTilesToFraction(65));
    rmAddTradeRouteWaypoint(tradeRouteID3, 0.5, 0.5+rmXTilesToFraction(20));
    rmBuildTradeRoute(tradeRouteID3, "native_water_trail");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
	vector stoperLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
	float xCenter = rmZMetersToFraction(xsVectorGetX(stoperLoc));

	vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.5);
    rmPlaceObjectDefAtPoint(stopperID2, 0, socketLoc2);
	vector stoperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
	float zCenter = rmZMetersToFraction(xsVectorGetZ(stoperLoc2));

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts Land");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID2);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0);

	// Define lake area

	int lakeArea = rmCreateArea("lakeArea");
    rmSetAreaSize(lakeArea , rmAreaTilesToFraction(23000), rmAreaTilesToFraction(23000));
    rmSetAreaLocation(lakeArea , xCenter, zCenter);		
    rmSetAreaCoherence(lakeArea , 0.8);
    rmSetAreaElevationVariation(lakeArea, 0.0);
	rmAddAreaToClass(lakeArea, classGreatLake);
    rmBuildArea(lakeArea); 

	// Grid coordinates

	float locX1 = xCenter-rmXTilesToFraction(52);
	float locX2 = xCenter-rmXTilesToFraction(30);
	float locX3 = xCenter-rmXTilesToFraction(10);
	float locX4 = xCenter+rmXTilesToFraction(10);
	float locX5 = xCenter+rmXTilesToFraction(30);
	float locX6 = xCenter+rmXTilesToFraction(52);

	float locZ1 = zCenter-rmZTilesToFraction(50);
	float locZ2 = zCenter-rmZTilesToFraction(30);
	float locZ3 = zCenter-rmZTilesToFraction(10);
	float locZ4 = zCenter+rmZTilesToFraction(10);
	float locZ5 = zCenter+rmZTilesToFraction(30);
	float locZ6 = zCenter+rmZTilesToFraction(50);

	// Double grid coordinates

	float blockX0 = xCenter-rmZTilesToFraction(40);
	float blockX1 = xCenter-rmZTilesToFraction(20);
	float blockX2 = xCenter+rmZTilesToFraction(0);
	float blockX3 = xCenter+rmZTilesToFraction(20);
	float blockX4 = xCenter+rmZTilesToFraction(40);

	float blockZ0 = zCenter-rmZTilesToFraction(40);
	float blockZ1 = zCenter-rmZTilesToFraction(20);
	float blockZ2 = zCenter+rmZTilesToFraction(0);
	float blockZ3 = zCenter+rmZTilesToFraction(20);
	float blockZ4 = zCenter+rmZTilesToFraction(40);

	// Block constraints

	int block1Constraint = rmCreateBoxConstraint("stay in the aztec block 1", blockX1-rmZTilesToFraction(16), blockZ0-rmZTilesToFraction(16), blockX1+rmXTilesToFraction(16), blockZ0+rmZTilesToFraction(16));
	int block2Constraint = rmCreateBoxConstraint("stay in the aztec block 2", blockX3-rmZTilesToFraction(16), blockZ0-rmZTilesToFraction(16), blockX3+rmXTilesToFraction(16), blockZ0+rmZTilesToFraction(16));
	int block3Constraint = rmCreateBoxConstraint("stay in the aztec block 3", blockX1-rmZTilesToFraction(16), blockZ4-rmZTilesToFraction(16), blockX1+rmXTilesToFraction(16), blockZ4+rmZTilesToFraction(16));
	int block4Constraint = rmCreateBoxConstraint("stay in the aztec block 4", blockX3-rmZTilesToFraction(16), blockZ4-rmZTilesToFraction(16), blockX3+rmXTilesToFraction(16), blockZ4+rmZTilesToFraction(16));
	int blockCenterConstraint = rmCreateBoxConstraint("stay in the aztec block center", blockX2-rmZTilesToFraction(36), blockZ2-rmZTilesToFraction(16), blockX2+rmXTilesToFraction(36), blockZ2+rmZTilesToFraction(16));
	int blockNarrowConstraint1 = rmCreateBoxConstraint("stay in the aztec block narrow 1", locX1-rmZTilesToFraction(9), blockZ2-rmZTilesToFraction(38), locX1+rmXTilesToFraction(9), blockZ2+rmZTilesToFraction(38));
	int blockNarrowConstraint2 = rmCreateBoxConstraint("stay in the aztec block narrow 2", locX6-rmZTilesToFraction(9), blockZ2-rmZTilesToFraction(38), locX6+rmXTilesToFraction(9), blockZ2+rmZTilesToFraction(38));

	// 	Bridges
	int bridgeGrouping = rmCreateGrouping("bridge 01", "AZ_Bridge_01");
    rmSetGroupingMinDistance(bridgeGrouping, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping, 0.00);
	//rmAddGroupingToClass(bridgeGrouping, rmClassID("classPlateau"));

	int bridgeGrouping2 = rmCreateGrouping("bridge 02", "AZ_Bridge_02");
    rmSetGroupingMinDistance(bridgeGrouping2, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping2, 0.00);
	//rmAddGroupingToClass(bridgeGrouping2, rmClassID("classPlateau"));

	int bridgeGrouping3 = rmCreateGrouping("bridge 03", "AZ_Bridge_03");
    rmSetGroupingMinDistance(bridgeGrouping3, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping3, 0.00);
	//rmAddGroupingToClass(bridgeGrouping3, rmClassID("classPlateau"));

	rmPlaceGroupingAtLoc(bridgeGrouping, 0, locX1+rmXTilesToFraction(12), blockZ2+rmZTilesToFraction(1));
	rmPlaceGroupingAtLoc(bridgeGrouping, 0, locX6-rmXTilesToFraction(12), blockZ2+rmXTilesToFraction(1));

	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, blockX1, locZ2+rmZTilesToFraction(10));
	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, blockX1, locZ5-rmZTilesToFraction(10));
	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, blockX3, locZ2+rmZTilesToFraction(10));
	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, blockX3, locZ5-rmZTilesToFraction(10));

	rmPlaceGroupingAtLoc(bridgeGrouping3, 0, locX1-rmXTilesToFraction(23), blockZ2);
	rmPlaceGroupingAtLoc(bridgeGrouping3, 0, locX6+rmXTilesToFraction(22), blockZ2);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	// *************************** Place City Terrain *******************************

	int aztecBlock1 = rmCreateArea("aztec block 1");
    rmSetAreaSize(aztecBlock1 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlock1 , blockX1, blockZ0);		
    rmSetAreaCoherence(aztecBlock1 , 1.0);
    rmSetAreaBaseHeight(aztecBlock1, 2.0);
	rmSetAreaSmoothDistance(aztecBlock1, 0);
	rmSetAreaHeightBlend(aztecBlock1, 0);
	rmSetAreaCliffType(aztecBlock1, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlock1, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlock1, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlock1 , block1Constraint);
	rmAddAreaToClass(aztecBlock1, classCityBlock);
    rmBuildArea(aztecBlock1); 

	int aztecBlock2 = rmCreateArea("aztec block 2");
    rmSetAreaSize(aztecBlock2 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlock2 , blockX3, blockZ0);		
    rmSetAreaCoherence(aztecBlock2 , 1.0);
    rmSetAreaBaseHeight(aztecBlock2, 2.0);
	rmSetAreaSmoothDistance(aztecBlock2, 0);
	rmSetAreaHeightBlend(aztecBlock2, 0);
	rmSetAreaCliffType(aztecBlock2, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlock2, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlock2, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlock2 , block2Constraint);
	rmAddAreaToClass(aztecBlock2, classCityBlock);
    rmBuildArea(aztecBlock2); 

	int aztecBlock3 = rmCreateArea("aztec block 3");
    rmSetAreaSize(aztecBlock3 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlock3 , blockX1, blockZ4);		
    rmSetAreaCoherence(aztecBlock3 , 1.0);
    rmSetAreaBaseHeight(aztecBlock3, 2.0);
	rmSetAreaSmoothDistance(aztecBlock3, 0);
	rmSetAreaHeightBlend(aztecBlock3, 0);
	rmSetAreaCliffType(aztecBlock3, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlock3, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlock3, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlock3 , block3Constraint);
	rmAddAreaToClass(aztecBlock3, classCityBlock);
    rmBuildArea(aztecBlock3); 

	int aztecBlock4 = rmCreateArea("aztec block 4");
    rmSetAreaSize(aztecBlock4 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlock4 , blockX3, blockZ4);		
    rmSetAreaCoherence(aztecBlock4 , 1.0);
    rmSetAreaBaseHeight(aztecBlock4, 2.0);
	rmSetAreaSmoothDistance(aztecBlock4, 0);
	rmSetAreaHeightBlend(aztecBlock4, 0);
	rmSetAreaCliffType(aztecBlock4, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlock4, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlock4, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlock4 , block4Constraint);
	rmAddAreaToClass(aztecBlock4, classCityBlock);
    rmBuildArea(aztecBlock4);

	int aztecBlockCenter = rmCreateArea("aztec block center");
    rmSetAreaSize(aztecBlockCenter , 0.1, 0.1);
    rmSetAreaLocation(aztecBlockCenter , blockX2, blockZ2);		
    rmSetAreaCoherence(aztecBlockCenter , 1.0);
    rmSetAreaBaseHeight(aztecBlockCenter, 2.0);
	rmSetAreaSmoothDistance(aztecBlockCenter, 0);
	rmSetAreaHeightBlend(aztecBlockCenter, 0);
	rmSetAreaCliffType(aztecBlockCenter, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlockCenter, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlockCenter, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlockCenter , blockCenterConstraint);
	rmAddAreaToClass(aztecBlockCenter, classCityBlock);
    rmBuildArea(aztecBlockCenter);

	int aztecBlockNarrow1 = rmCreateArea("aztec block narrow 1");
    rmSetAreaSize(aztecBlockNarrow1 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlockNarrow1 , locX1, blockZ2);		
    rmSetAreaCoherence(aztecBlockNarrow1 , 1.0);
    rmSetAreaBaseHeight(aztecBlockNarrow1, 2.0);
	rmSetAreaSmoothDistance(aztecBlockNarrow1, 0);
	rmSetAreaHeightBlend(aztecBlockNarrow1, 0);
	rmSetAreaCliffType(aztecBlockNarrow1, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlockNarrow1, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlockNarrow1, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlockNarrow1 , blockNarrowConstraint1);
	rmAddAreaToClass(aztecBlockNarrow1, classCityBlock);
    rmBuildArea(aztecBlockNarrow1);

	int aztecBlockNarrow2 = rmCreateArea("aztec block narrow 2");
    rmSetAreaSize(aztecBlockNarrow2 , 0.1, 0.1);
    rmSetAreaLocation(aztecBlockNarrow2 , locX6, blockZ2);		
    rmSetAreaCoherence(aztecBlockNarrow2 , 1.0);
    rmSetAreaBaseHeight(aztecBlockNarrow2, 2.0);
	rmSetAreaSmoothDistance(aztecBlockNarrow2, 0);
	rmSetAreaHeightBlend(aztecBlockNarrow2, 0);
	rmSetAreaCliffType(aztecBlockNarrow2, "ZP City Aztec");
    rmSetAreaCliffEdge(aztecBlockNarrow2, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(aztecBlockNarrow2, 0, 0.0, 1.0);
    rmAddAreaConstraint(aztecBlockNarrow2 , blockNarrowConstraint2);
	rmAddAreaToClass(aztecBlockNarrow2, classCityBlock);
    rmBuildArea(aztecBlockNarrow2);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);


	// *************************** Place City Blocks *******************************

	// Temples
	int templeGrouping = rmCreateGrouping("center", "AZ_Big_TempleDistrict");
    rmSetGroupingMinDistance(templeGrouping, 0.00);
    rmSetGroupingMaxDistance(templeGrouping, 0.00);
	rmAddGroupingToClass(templeGrouping, rmClassID("classPlateau"));

	// Wood
	int woodGrouping = rmCreateGrouping("wood housing", "AZ_Big_WoodDistrict");
    rmSetGroupingMinDistance(woodGrouping, 0.00);
    rmSetGroupingMaxDistance(woodGrouping, 0.00);
	rmAddGroupingToClass(woodGrouping, rmClassID("classPlateau"));

	// Food
	int foodGrouping = rmCreateGrouping("food housing", "AZ_Big_FoodDistrict");
    rmSetGroupingMinDistance(foodGrouping, 0.00);
    rmSetGroupingMaxDistance(foodGrouping, 0.00);
	rmAddGroupingToClass(foodGrouping, rmClassID("classPlateau"));

	// Gold
	int goldGrouping = rmCreateGrouping("treasury", "AZ_Big_GoldDistrict");
    rmSetGroupingMinDistance(goldGrouping, 0.00);
    rmSetGroupingMaxDistance(goldGrouping, 0.00);
	rmAddGroupingToClass(goldGrouping, rmClassID("classPlateau"));

	// Player Start
	int playerStart = rmCreateGrouping("player Start", "AZ_Big_PlayerDistrict");
    rmSetGroupingMinDistance(playerStart, 0.00);
    rmSetGroupingMaxDistance(playerStart, 0.00);
	rmAddGroupingToClass(playerStart, rmClassID("classPlateau"));

	int playerStartEuro = rmCreateGrouping("player Start EU", "AZ_Big_PlayerDistrictEuro");
    rmSetGroupingMinDistance(playerStartEuro, 0.00);
    rmSetGroupingMaxDistance(playerStartEuro, 0.00);
	rmAddGroupingToClass(playerStartEuro, rmClassID("classPlateau"));

	// House
	int houseGrouping1 = rmCreateGrouping("1", "AZ_Big_House1");
	rmSetGroupingMinDistance(houseGrouping1, 0.00);
	rmSetGroupingMaxDistance(houseGrouping1, 0.00);
	rmAddGroupingToClass(houseGrouping1, rmClassID("classPlateau"));

	int houseGrouping2 = rmCreateGrouping("house2", "AZ_Big_House2");
	rmSetGroupingMinDistance(houseGrouping2, 0.00);
	rmSetGroupingMaxDistance(houseGrouping2, 0.00);
	rmAddGroupingToClass(houseGrouping2, rmClassID("classPlateau"));

	// Citadel
	int citadelGrouping1 = rmCreateGrouping("citadel", "AZ_SPC_Citadel_01");
	rmSetGroupingMinDistance(citadelGrouping1, 0.00);
	rmSetGroupingMaxDistance(citadelGrouping1, 0.00);
	rmAddGroupingToClass(citadelGrouping1, rmClassID("classPlateau"));

	int citadelGrouping2 = rmCreateGrouping("citadel2", "AZ_SPC_Citadel_02");
	rmSetGroupingMinDistance(citadelGrouping2, 0.00);
	rmSetGroupingMaxDistance(citadelGrouping2, 0.00);
	rmAddGroupingToClass(citadelGrouping2, rmClassID("classPlateau"));

	int citadelGrouping3 = rmCreateGrouping("citadel3", "AZ_SPC_Citadel_03");
	rmSetGroupingMinDistance(citadelGrouping3, 0.00);
	rmSetGroupingMaxDistance(citadelGrouping3, 0.00);
	rmAddGroupingToClass(citadelGrouping3, rmClassID("classPlateau"));

	int citadelGrouping4 = rmCreateGrouping("citadel4", "AZ_SPC_Citadel_04");
	rmSetGroupingMinDistance(citadelGrouping4, 0.00);
	rmSetGroupingMaxDistance(citadelGrouping4, 0.00);
	rmAddGroupingToClass(citadelGrouping4, rmClassID("classPlateau"));

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
	rmSetObjectDefMaxDistance(startingUnits, 20.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
	rmAddObjectDefConstraint(startingUnits, farAvoidTradeSockets);

	// Player start
	if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec")) 
		rmPlaceGroupingAtLoc(playerStart, firstDefender, blockX2, blockZ2);
	else
		rmPlaceGroupingAtLoc(playerStartEuro, firstDefender, blockX2, blockZ2);

	rmPlaceObjectDefAtLoc(startingUnits, firstDefender, blockX2, blockZ2);

	// Native districts

	int templePlacement = rmPlaceGroupingInstanceAtLoc(templeGrouping, blockX1, blockZ0, 0);
	int woodPlacement = rmPlaceGroupingInstanceAtLoc(woodGrouping, blockX3, blockZ0, 0);
	int foodPlacement = rmPlaceGroupingInstanceAtLoc(foodGrouping, blockX3, blockZ4, 0);
	int goldPlacement = rmPlaceGroupingInstanceAtLoc(goldGrouping, blockX1, blockZ4, 0);

	// Create house controllers to target the outpost sockets
    int housePoint1 = rmCreateObjectDef("house point1");
    rmAddObjectDefItem(housePoint1, "zpSPCWaterSpawnPoint", 1, 0.0);

	int housePoint2 = rmCreateObjectDef("house point2");
    rmAddObjectDefItem(housePoint2, "zpSPCWaterSpawnPoint", 1, 0.0);

	// Houses
	rmPlaceGroupingAtLoc(houseGrouping1, 0, locX1-rmXTilesToFraction(1), blockZ2);
	rmPlaceObjectDefAtLoc(housePoint1, 0, locX1, blockZ2, 1);
	rmPlaceGroupingAtLoc(houseGrouping2, 0, locX6+rmXTilesToFraction(1), blockZ2);
	rmPlaceObjectDefAtLoc(housePoint2, 0, locX6, blockZ2, 1);

	// Citadels
	int citadelPlacement1 = rmPlaceGroupingInstanceAtLoc(citadelGrouping2, locX1, locZ2, firstDefender);
	int citadelPlacement2 = rmPlaceGroupingInstanceAtLoc(citadelGrouping3, locX1, locZ5, firstDefender);
	int citadelPlacement3 = rmPlaceGroupingInstanceAtLoc(citadelGrouping1, locX6, locZ2, firstDefender);
	int citadelPlacement4 = rmPlaceGroupingInstanceAtLoc(citadelGrouping4, locX6, locZ5, firstDefender);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// *************************** Place countryside terrain *******************************

	// Create center point to avoid
    int centerPoint = rmCreateObjectDef("center point");
    rmAddObjectDefItem(centerPoint, "zpSPCWaterSpawnPointB", 1, 0.0);
    rmPlaceObjectDefAtLoc(centerPoint, 0, xCenter, zCenter, 1);

	// **************** Create continents ****************

	 // Create north continent
    int northContinentID = rmCreateArea("north_continent");
    rmSetAreaSize(northContinentID, 0.35, 0.35);
    rmSetAreaCoherence(northContinentID, 0.65);
    rmSetAreaMix(northContinentID, "texas_grass");
		rmAddAreaTerrainLayer(northContinentID, "Texas\ground5_tex", 0, 2);
		rmAddAreaTerrainLayer(northContinentID, "Texas\ground3_tex", 2, 4);
    rmSetAreaBaseHeight(northContinentID, 4);  // embassy structure height
    rmSetAreaHeightBlend(northContinentID, 2);
    rmSetAreaSmoothDistance(northContinentID, 50);
    rmSetAreaMinBlobs(northContinentID, 8);
    rmSetAreaMaxBlobs(northContinentID, 12);
    rmSetAreaMinBlobDistance(northContinentID, 8.0);
    rmSetAreaMaxBlobDistance(northContinentID, 12.0);
    rmSetAreaObeyWorldCircleConstraint(northContinentID, false);
    //rmAddAreaConstraint(northContinentID, avoidCenterPoint);
    rmAddAreaConstraint(northContinentID, avoidCity);
	rmAddAreaConstraint(northContinentID, greatLakesConstraint);
    rmSetAreaLocation(northContinentID, 0.1, 0.5);
    rmBuildArea(northContinentID);

    // Create south continent
    int southContinentID = rmCreateArea("south_continent");
    rmSetAreaSize(southContinentID, 0.35, 0.35);
    rmSetAreaCoherence(southContinentID, 0.65);
    rmSetAreaMix(southContinentID, "texas_grass");
		rmAddAreaTerrainLayer(southContinentID, "Texas\ground5_tex", 0, 2);
		rmAddAreaTerrainLayer(southContinentID, "Texas\ground3_tex", 2, 4);
    rmSetAreaBaseHeight(southContinentID, 4);  // embassy structure height
    rmSetAreaHeightBlend(southContinentID, 2);
    rmSetAreaSmoothDistance(southContinentID, 50);
    rmSetAreaMinBlobs(southContinentID, 8);
    rmSetAreaMaxBlobs(southContinentID, 12);
    rmSetAreaMinBlobDistance(southContinentID, 8.0);
    rmSetAreaMaxBlobDistance(southContinentID, 12.0);
    rmSetAreaObeyWorldCircleConstraint(southContinentID, false);
    //rmAddAreaConstraint(southContinentID, avoidCenterPoint);
    rmAddAreaConstraint(southContinentID, avoidCity);
	rmAddAreaConstraint(southContinentID, greatLakesConstraint);
    rmSetAreaLocation(southContinentID, 0.9, 0.5);
    rmBuildArea(southContinentID);

	vector socketLocX = rmGetTradeRouteWayPoint(tradeRouteID2, 0.1);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLocX);
	socketLocX = rmGetTradeRouteWayPoint(tradeRouteID2, 0.9);
	rmPlaceObjectDefAtPoint(socketID, 0, socketLocX);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

		// ********************** Place natives and other objects **********************

	// Place Jesuit natives

	int jesuitMonastery1Type = rmRandInt(1, 3);
	int jesuitMonastery2Type = rmRandInt(1, 3);
	int jesuitMonastery3Type = rmRandInt(1, 3);
	int jesuitMonastery4Type = rmRandInt(1, 3);

	int jesuitMonastery1ID = rmCreateGrouping("monastery 1", "Jesuit_Cathedral_Tropic_0"+jesuitMonastery1Type);
	int jesuitMonastery2ID = rmCreateGrouping("monastery 2", "Jesuit_Cathedral_Tropic_0"+jesuitMonastery2Type);
	int jesuitMonastery3ID = rmCreateGrouping("monastery 3", "Jesuit_Cathedral_Tropic_0"+jesuitMonastery3Type);
	int jesuitMonastery4ID = rmCreateGrouping("monastery 4", "Jesuit_Cathedral_Tropic_0"+jesuitMonastery4Type);
	
	rmSetGroupingMinDistance(jesuitMonastery1ID, 0);
	rmSetGroupingMaxDistance(jesuitMonastery1ID, 30);
	rmSetGroupingMinDistance(jesuitMonastery2ID, 0);
	rmSetGroupingMaxDistance(jesuitMonastery2ID, 30);
	rmSetGroupingMinDistance(jesuitMonastery3ID, 0);
	rmSetGroupingMaxDistance(jesuitMonastery3ID, 30);
	rmSetGroupingMinDistance(jesuitMonastery4ID, 0);
	rmSetGroupingMaxDistance(jesuitMonastery4ID, 30);
	
	rmAddGroupingToClass(jesuitMonastery1ID, rmClassID("classBlock"));
	rmAddGroupingToClass(jesuitMonastery2ID, rmClassID("classBlock"));
	rmAddGroupingToClass(jesuitMonastery3ID, rmClassID("classBlock"));
	rmAddGroupingToClass(jesuitMonastery4ID, rmClassID("classBlock"));

	int jesuitControllerID1 = rmCreateObjectDef("jesuit controller 1");
	rmAddObjectDefItem(jesuitControllerID1, "zpTrainStopper", 1, 0.0);
	int jesuitControllerID2 = rmCreateObjectDef("jesuit controller 2");
	rmAddObjectDefItem(jesuitControllerID2, "zpTrainStopper", 1, 0.0);
	int jesuitControllerID3 = rmCreateObjectDef("jesuit controller 3");
	rmAddObjectDefItem(jesuitControllerID3, "zpTrainStopper", 1, 0.0);
	int jesuitControllerID4 = rmCreateObjectDef("jesuit controller 4");
	rmAddObjectDefItem(jesuitControllerID4, "zpTrainStopper", 1, 0.0);

	if (teamOneCount ==1 || teamOneCount ==2 || teamOneCount ==4){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.1, 0.62, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.1, 0.62, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.9, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.9, 0.38, 1);
	}
	if (teamOneCount ==3){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.1, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.1, 0.38, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.9, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.9, 0.38, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.5, 0.90, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.5, 0.90, 1);
	}
	if (teamOneCount ==5){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.5, 0.08, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.5, 0.08, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.7, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.7, 0.85, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.3, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.3, 0.85, 1);
	}
	if (teamOneCount ==6){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.08, 0.5, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.08, 0.5, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.7, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.7, 0.85, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.7, 0.15, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.7, 0.15, 1);
	}
	if (teamOneCount ==7){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.8, 0.8, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.4, 0.05, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.4, 0.05, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.1, 0.65, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.1, 0.65, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery4ID, 0, 0.7, 0.15, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID4, 0, 0.7, 0.15, 1);
	}

	int jesuitCathedral1 = rmGetUnitPlaced(jesuitControllerID1, 0)-1;
	int jesuitCathedral2 = rmGetUnitPlaced(jesuitControllerID2, 0)-1;
	int jesuitCathedral3 = rmGetUnitPlaced(jesuitControllerID3, 0)-1;
	int jesuitCathedral4 = rmGetUnitPlaced(jesuitControllerID4, 0)-1;

	vector jesuitCathedralLoc1 = rmGetUnitPosition(jesuitCathedral1);
	vector jesuitCathedralLoc2 = rmGetUnitPosition(jesuitCathedral2);
	vector jesuitCathedralLoc3 = rmGetUnitPosition(jesuitCathedral3);
	vector jesuitCathedralLoc4 = rmGetUnitPosition(jesuitCathedral4);

	// Create north elevated area
    int northElevatedID = rmCreateArea("north_elevated");
	rmSetAreaMix(northElevatedID, "texas_grass");
    rmSetAreaSize(northElevatedID, 0.3, 0.3);
    rmSetAreaCoherence(northElevatedID, 0.35);
    rmSetAreaBaseHeight(northElevatedID, 4.6);
    rmAddAreaConstraint(northElevatedID, avoidCenterPointLong);
    rmAddAreaConstraint(northElevatedID, avoidTradeRoute);
    rmSetAreaElevationType(northElevatedID, cElevTurbulence);
    rmSetAreaElevationVariation(northElevatedID, 6.0);
    rmSetAreaElevationPersistence(northElevatedID, 0.2);
    rmSetAreaElevationNoiseBias(northElevatedID, 1);
	rmSetAreaObeyWorldCircleConstraint(northElevatedID, false);
    
    rmSetAreaLocation(northElevatedID, 0.50, 0.90);
    rmAddAreaInfluencePoint(northElevatedID, 0.40, 0.90);
    rmAddAreaInfluencePoint(northElevatedID, 0.60, 0.90);
    
    rmBuildArea(northElevatedID);

    // Create south elevated area  
    int southElevatedID = rmCreateArea("south_elevated");
	rmSetAreaMix(southElevatedID, "texas_grass");
    rmSetAreaSize(southElevatedID, 0.3, 0.3);
    rmSetAreaCoherence(southElevatedID, 0.35);
    rmSetAreaBaseHeight(southElevatedID, 4.6);
    rmAddAreaConstraint(southElevatedID, avoidCenterPointLong);
    rmAddAreaConstraint(southElevatedID, avoidTradeRoute);
    rmSetAreaElevationType(southElevatedID, cElevTurbulence);
    rmSetAreaElevationVariation(southElevatedID, 6.0);
    rmSetAreaElevationPersistence(southElevatedID, 0.2);
    rmSetAreaElevationNoiseBias(southElevatedID, 1);
    rmSetAreaObeyWorldCircleConstraint(southElevatedID, false);
    
    rmSetAreaLocation(southElevatedID, 0.50, 0.10);
    rmAddAreaInfluencePoint(southElevatedID, 0.40, 0.10);
    rmAddAreaInfluencePoint(southElevatedID, 0.60, 0.10);
    
    rmBuildArea(southElevatedID);

	// Jesuit Valleys

	int jesuitValley1 = rmCreateArea ("jesuitValley1");
	rmSetAreaSize(jesuitValley1, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
	rmSetAreaLocation(jesuitValley1, rmXMetersToFraction(xsVectorGetX(jesuitCathedralLoc1)), rmZMetersToFraction(xsVectorGetZ(jesuitCathedralLoc1)));
	rmSetAreaCoherence(jesuitValley1, 0.8);
	rmSetAreaBaseHeight(jesuitValley1, 2.983);
	rmSetAreaSmoothDistance(jesuitValley1, 15);
	rmSetAreaHeightBlend(jesuitValley1, 2);
	rmSetAreaElevationVariation(jesuitValley1, 0.0);
	rmAddAreaConstraint(jesuitValley1, avoidCenterPoint);
	rmBuildArea(jesuitValley1);

	int jesuitValley2 = rmCreateArea ("jesuitValley2");
	rmSetAreaSize(jesuitValley2, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
	rmSetAreaLocation(jesuitValley2, rmXMetersToFraction(xsVectorGetX(jesuitCathedralLoc2)), rmZMetersToFraction(xsVectorGetZ(jesuitCathedralLoc2)));
	rmSetAreaCoherence(jesuitValley2, 0.8);
	rmSetAreaBaseHeight(jesuitValley2, 2.983);
	rmSetAreaSmoothDistance(jesuitValley2, 15);
	rmSetAreaHeightBlend(jesuitValley2, 2);
	rmSetAreaElevationVariation(jesuitValley2, 0.0);
	rmAddAreaConstraint(jesuitValley2, avoidCenterPoint);
	rmBuildArea(jesuitValley2);

	int jesuitValley3 = rmCreateArea ("jesuitValley3");
	rmSetAreaSize(jesuitValley3, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
	rmSetAreaLocation(jesuitValley3, rmXMetersToFraction(xsVectorGetX(jesuitCathedralLoc3)), rmZMetersToFraction(xsVectorGetZ(jesuitCathedralLoc3)));
	rmSetAreaCoherence(jesuitValley3, 0.8);
	rmSetAreaBaseHeight(jesuitValley3, 2.983);
	rmSetAreaSmoothDistance(jesuitValley3, 15);
	rmSetAreaHeightBlend(jesuitValley3, 2);
	rmSetAreaElevationVariation(jesuitValley3, 0.0);
	rmAddAreaConstraint(jesuitValley3, avoidCenterPoint);
	rmBuildArea(jesuitValley3);

	int jesuitValley4 = rmCreateArea ("jesuitValley4");
	rmSetAreaSize(jesuitValley4, rmAreaTilesToFraction(850.0), rmAreaTilesToFraction(850.0));
	rmSetAreaLocation(jesuitValley4, rmXMetersToFraction(xsVectorGetX(jesuitCathedralLoc4)), rmZMetersToFraction(xsVectorGetZ(jesuitCathedralLoc4)));
	rmSetAreaCoherence(jesuitValley4, 0.8);
	rmSetAreaBaseHeight(jesuitValley4, 2.983);
	rmSetAreaSmoothDistance(jesuitValley4, 15);
	rmSetAreaHeightBlend(jesuitValley4, 2);
	rmSetAreaElevationVariation(jesuitValley4, 0.0);
	rmAddAreaConstraint(jesuitValley4, avoidCenterPoint);
	rmBuildArea(jesuitValley4);

	// Create north cliff area
    int northCliffID = rmCreateArea("north_cliff");
	rmSetAreaSize(northCliffID, 0.17, 0.17);
    rmSetAreaCoherence(northCliffID, 0.35);
    rmSetAreaBaseHeight(northCliffID, 8.136);  // Using EU bridge height for dramatic elevation
    rmAddAreaConstraint(northCliffID, avoidCenterPointUltraLong);
	rmAddAreaConstraint(northCliffID, avoidTradeRouteFar2);
	rmAddAreaConstraint(northCliffID, avoidJesuit);
    rmSetAreaCliffType(northCliffID, "Texas");
    rmSetAreaCliffEdge(northCliffID, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(northCliffID, 0, 0.0, 1.0);
	rmSetAreaCliffPainting(northCliffID, true, true, true, 1.5, true);
    rmSetAreaObeyWorldCircleConstraint(northCliffID, false);
	rmAddAreaToClass(northCliffID, classMountains);
    rmSetAreaLocation(northCliffID, 0.50, 0.99);
    rmAddAreaInfluencePoint(northCliffID, 0.40, 0.90);
    rmAddAreaInfluencePoint(northCliffID, 0.60, 0.90);

    rmBuildArea(northCliffID);

	// Create south cliff area
    int southCliffID = rmCreateArea("south_cliff");
	rmSetAreaSize(southCliffID, 0.17, 0.17);
    rmSetAreaCoherence(southCliffID, 0.35);
    rmSetAreaBaseHeight(southCliffID, 8.136);  // Using EU bridge height for dramatic elevation
    rmAddAreaConstraint(southCliffID, avoidCenterPointUltraLong);
	rmAddAreaConstraint(southCliffID, avoidTradeRouteFar2);
	rmAddAreaConstraint(southCliffID, avoidJesuit);
    rmSetAreaCliffType(southCliffID, "Texas");
    rmSetAreaCliffEdge(southCliffID, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(southCliffID, 0, 0.0, 1.0);
	rmSetAreaCliffPainting(southCliffID, true, true, true, 1.5, true);
    rmSetAreaObeyWorldCircleConstraint(southCliffID, false);
	rmAddAreaToClass(southCliffID, classMountains);
    rmSetAreaLocation(southCliffID, 0.50, 0.02);
    rmAddAreaInfluencePoint(southCliffID, 0.40, 0.10);
    rmAddAreaInfluencePoint(southCliffID, 0.60, 0.10);

    rmBuildArea(southCliffID);

	// Countryside embassys

	int tlaxaclanembassy1Type = 1;
	int tlaxaclanembassy2Type = 1;
	int tlaxaclanembassy3Type = 1;
	int tlaxaclanembassy4Type = 1;

	int embassyControllerID1 = rmCreateObjectDef("embassy controller 1");
	rmAddObjectDefItem(embassyControllerID1, "zpTrainStopper", 1, 0.0);
	int embassyControllerID2 = rmCreateObjectDef("embassy controller 2");
	rmAddObjectDefItem(embassyControllerID2, "zpTrainStopper", 1, 0.0);
	int embassyControllerID3 = rmCreateObjectDef("embassy controller 3");
	rmAddObjectDefItem(embassyControllerID3, "zpTrainStopper", 1, 0.0);

	rmSetNuggetDifficulty(302, 302);

	if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){
		rmPlaceObjectDefAtLoc(embassyControllerID1, 0, 0.62, 0.9);
		rmPlaceObjectDefAtLoc(embassyControllerID2, 0, 0.38, 0.1);
	}
	if (cNumberNonGaiaPlayers ==5){
		rmPlaceObjectDefAtLoc(embassyControllerID1, 0, 0.065, 0.45);
		rmPlaceObjectDefAtLoc(embassyControllerID2, 0, 0.92, 0.45);
	}
	
	if (cNumberNonGaiaPlayers ==6){
		rmPlaceObjectDefAtLoc(embassyControllerID1, 0, 0.92, 0.5);
		rmPlaceObjectDefAtLoc(embassyControllerID2, 0, 0.3, 0.85);
		rmPlaceObjectDefAtLoc(embassyControllerID3, 0, 0.3, 0.15);
	}

	if (cNumberNonGaiaPlayers ==7){
		rmPlaceObjectDefAtLoc(embassyControllerID1, 0, 0.5, 0.92);
		rmPlaceObjectDefAtLoc(embassyControllerID2, 0, 0.1, 0.35);
		rmPlaceObjectDefAtLoc(embassyControllerID3, 0, 0.9, 0.4);
	}

	
	vector embassyControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(embassyControllerID1, 0));
	vector embassyControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(embassyControllerID2, 0));
	vector embassyControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(embassyControllerID3, 0));
	
	// Place embassies

	rmSetNuggetDifficulty(311, 311);

	int countrysideEmbassyID1 = rmCreateGrouping("tlaxaclan embassy 1", "tlaxaclan_embassy_0"+tlaxaclanembassy1Type);
	int countryEmbassyInstance1 = rmPlaceGroupingInstanceAtLoc(countrysideEmbassyID1, rmXMetersToFraction(xsVectorGetX(embassyControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(embassyControllerLoc1)), 0);
	
	int countrysideEmbassyID2 = rmCreateGrouping("tlaxaclan embassy 2", "tlaxaclan_embassy_0"+tlaxaclanembassy2Type);
	int countryEmbassyInstance2 = rmPlaceGroupingInstanceAtLoc(countrysideEmbassyID2, rmXMetersToFraction(xsVectorGetX(embassyControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(embassyControllerLoc2)), 0);

	int countrysideEmbassyID3 = rmCreateGrouping("tlaxaclan embassy 3", "tlaxaclan_embassy_0"+tlaxaclanembassy3Type);
	int countryEmbassyInstance3 = rmPlaceGroupingInstanceAtLoc(countrysideEmbassyID3, rmXMetersToFraction(xsVectorGetX(embassyControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(embassyControllerLoc3)), 0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ****************** Place Players ******************

	if (teamOneCount <=2){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.4375, 0.4365);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==3){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 0.8535);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==4){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 0.9375);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==5){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 0.9875);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==6){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 1.0215);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==7){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 1.0445);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}
	if (teamOneCount ==8){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1875, 1.0615);  
		rmPlacePlayersCircular(0.42, 0.42, 0);
	}

	// Insert Players
	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	}

	rmSetObjectDefMinDistance(TCID, 0.0);
	if (teamOneCount <= 6) {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	else {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, avoidNuggetsShort);
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, farAvoidTradeSockets);
	rmAddObjectDefConstraint(TCID, avoidWater30);
	rmAddObjectDefConstraint(TCID, avoidTradeRoute);

	int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "MineCopper", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerMineID, avoidTradeRoute); 
	rmAddObjectDefConstraint(playerMineID, farAvoidTradeSockets);

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "BighornSheep", rmRandInt(7,10), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 15.0);
	rmSetObjectDefMaxDistance(playerDeerID, 30.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);
	rmAddObjectDefConstraint(playerDeerID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerDeerID, farAvoidTradeSockets);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetID, 15.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 18.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerNuggetID, farAvoidTradeSockets);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "treeTexas", 10, 12.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 15.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 25.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
	rmAddObjectDefConstraint(StartAreaTreeID, farAvoidTradeSockets);

	int berryID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID, 16.0);
	rmSetObjectDefMaxDistance(berryID, 17.0);
	rmAddObjectDefConstraint(berryID, avoidAll);
	rmAddObjectDefConstraint(berryID, avoidImpassableLand);
	rmAddObjectDefConstraint(berryID, avoidTradeRoute);
	rmAddObjectDefConstraint(berryID, farAvoidTradeSockets);

	int aiStartUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiStartUrban, "zpAIStartUrbanMap", 1, 0.0);


	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);

	for(i=1; <cNumberPlayers) {

		// Place town centers
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		// Place resources
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(berryID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);

		// Place starting nugget
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
 
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	
	// Scattered FORESTS

	int numTries = -1;
	int forestTreeID = 0;
	numTries=10*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
    rmSetAreaForestType(forest, "Texas Forest");
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
    rmAddAreaConstraint(forest, avoidTradeSockets);
	rmAddAreaConstraint(forest, avoidTradeRoute);
    rmAddAreaConstraint(forest, avoidTownCenterFar);
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

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "MineCopper", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 80.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
    rmAddObjectDefConstraint(randomGoldID, avoidCenterPoint);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmAddObjectDefConstraint(randomGoldID, Northward);
	rmAddObjectDefConstraint(randomGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldID, avoidWater10);
	rmAddObjectDefConstraint(randomGoldID, avoidCity);
	rmPlaceObjectDefAtLoc(randomGoldID, 0, 0.5, 0.5, 1+teamOneCount*1.5);

	int randomGoldSouthID = rmCreateObjectDef("random south mine");
	rmAddObjectDefItem(randomGoldSouthID, "MineCopper", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldSouthID, 80.0);
	rmSetObjectDefMaxDistance(randomGoldSouthID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldSouthID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidAll);
    rmAddObjectDefConstraint(randomGoldSouthID, avoidCenterPoint);
	rmAddObjectDefConstraint(randomGoldSouthID, playerEdgeConstraint);
	rmAddObjectDefConstraint(randomGoldSouthID, Southward);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidWater10);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidCity);
	rmPlaceObjectDefAtLoc(randomGoldSouthID, 0, 0.5, 0.5, 1+teamOneCount*1.5);

	// Huntables North
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, "Bison", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 80);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.45));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHunt1);
	rmAddObjectDefConstraint(foodID1, avoidAll);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID1, avoidCenterPoint);
	rmAddObjectDefConstraint(foodID1, Northward);
	rmAddObjectDefConstraint(foodID1, avoidCity);
	rmPlaceObjectDefAtLoc(foodID1, 0, 0.5, 0.5, 1+teamOneCount*2); 

	// Huntables South
	int foodID2=rmCreateObjectDef("random food 2");
	rmAddObjectDefItem(foodID2, "Bison", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID2, 80);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.45));
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidHunt1);
	rmAddObjectDefConstraint(foodID2, avoidAll);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID2, avoidCenterPoint);
	rmAddObjectDefConstraint(foodID2, Southward);
	rmAddObjectDefConstraint(foodID2, avoidCity);
	rmPlaceObjectDefAtLoc(foodID2, 0, 0.5, 0.5, 1+teamOneCount*2); 

	int berryID1 = rmCreateObjectDef("starting berries north");
	rmAddObjectDefItem(berryID1, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID1, 80);
	rmSetObjectDefMaxDistance(berryID1, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID1, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID1, avoidAll);
	rmAddObjectDefConstraint(berryID1, avoidWater10);
	rmAddObjectDefConstraint(berryID1, Northward);
	rmAddObjectDefConstraint(berryID1, avoidCenterPoint);
	rmAddObjectDefConstraint(berryID1, avoidCity);
	rmPlaceObjectDefAtLoc(berryID1, 0, 0.5, 0.5, teamOneCount); 

	int berryID2 = rmCreateObjectDef("starting berries south");
	rmAddObjectDefItem(berryID2, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID2, 80);
	rmSetObjectDefMaxDistance(berryID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID2, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID2, avoidAll);
	rmAddObjectDefConstraint(berryID2, avoidWater10);
	rmAddObjectDefConstraint(berryID2, Southward);
	rmAddObjectDefConstraint(berryID2, avoidCenterPoint);
	rmAddObjectDefConstraint(berryID2, avoidCity);
	rmPlaceObjectDefAtLoc(berryID2, 0, 0.5, 0.5, teamOneCount); 

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	int nuggetHardNorth= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetHardNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmSetObjectDefMinDistance(nuggetHardNorth, 80.0);
	rmSetObjectDefMaxDistance(nuggetHardNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardNorth, Northward);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidCenterPoint);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidCity);
	rmPlaceObjectDefAtLoc(nuggetHardNorth, 0, 0.5, 0.5, teamOneCount/2); 

	int nuggetHardSouth= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nuggetHardSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmSetObjectDefMinDistance(nuggetHardSouth, 80.0);
	rmSetObjectDefMaxDistance(nuggetHardSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardSouth, Southward);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidCenterPoint);
		rmAddObjectDefConstraint(nuggetHardSouth, avoidCity);
	rmPlaceObjectDefAtLoc(nuggetHardSouth, 0, 0.5, 0.5, teamOneCount/2); 

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetNorth, 80.0);
	rmSetObjectDefMaxDistance(nuggetNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetNorth, Northward);
	rmAddObjectDefConstraint(nuggetNorth, avoidCenterPoint);
	rmAddObjectDefConstraint(nuggetNorth, avoidCity);
	rmPlaceObjectDefAtLoc(nuggetNorth, 0, 0.5, 0.5, 2*teamOneCount); 

	int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetSouth, 80.0);
	rmSetObjectDefMaxDistance(nuggetSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetSouth, Southward);
	rmAddObjectDefConstraint(nuggetSouth, avoidCenterPoint);
	rmAddObjectDefConstraint(nuggetSouth, avoidCity);
	rmPlaceObjectDefAtLoc(nuggetSouth, 0, 0.5, 0.5, 2*teamOneCount); 

	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, "fishBass", 1, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, avoidLandFish);
	rmAddObjectDefConstraint(fishID, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 100);

	rmForbidTradeMonopoly(true);

	// _________________ Map Objectives ______________________________
	rmObjectiveScreenSetTitle(302437);
	rmObjectiveScreenSetGoal(302438);
	rmObjectiveAdd(302452, 302453, true, true, true); // General objective
	rmObjectiveSetTeam(1, 1);
	rmObjectiveAdd(302451, 302453, true, true, true); // Royal Court REV
	rmObjectiveSetTeam(2, 2);


	// ************************* TRIGGERS ******************************

	//----- DEFINE VARIABLES -----

	int socketTemple = rmGetGroupingInstanceUnitByType(templePlacement, "SocketAztec");
	int socketWood = rmGetGroupingInstanceUnitByType(woodPlacement, "SocketAztec");
	int socketFood = rmGetGroupingInstanceUnitByType(foodPlacement, "SocketAztec");
	int socketGold = rmGetGroupingInstanceUnitByType(goldPlacement, "SocketAztec");

	int centerTemple = rmGetGroupingInstanceUnitByType(templePlacement, "zpSPCRevealerAztec");
	int centerWood = rmGetGroupingInstanceUnitByType(woodPlacement, "zpSPCRevealerAztec");
	int centerFood = rmGetGroupingInstanceUnitByType(foodPlacement, "zpSPCRevealerAztec");
	int centerGold = rmGetGroupingInstanceUnitByType(goldPlacement, "zpSPCRevealerAztec");

	int centerPointID = rmGetUnitPlaced(centerPoint, 0);

	int tower1PointID1 = rmGetUnitPlaced(housePoint1, 0)-1;
	int tower2PointID1 = rmGetUnitPlaced(housePoint1, 0)-2;
	int tower1PointID2 = rmGetUnitPlaced(housePoint2, 0)-1;
	int tower2PointID2 = rmGetUnitPlaced(housePoint2, 0)-2;

	int citadelCitadel1 = rmGetGroupingInstanceUnitByType(citadelPlacement1, "deMayaembassy");
	int citadelCitadel2 = rmGetGroupingInstanceUnitByType(citadelPlacement2, "deMayaembassy");
	int citadelCitadel3 = rmGetGroupingInstanceUnitByType(citadelPlacement3, "deMayaembassy");
	int citadelCitadel4 = rmGetGroupingInstanceUnitByType(citadelPlacement4, "deMayaembassy");

	int citadelNugget1 = rmGetGroupingInstanceUnitByType(citadelPlacement1, "zpNuggetInvisible");
	int citadelNugget2 = rmGetGroupingInstanceUnitByType(citadelPlacement2, "zpNuggetInvisible");
	int citadelNugget3 = rmGetGroupingInstanceUnitByType(citadelPlacement3, "zpNuggetInvisible");
	int citadelNugget4 = rmGetGroupingInstanceUnitByType(citadelPlacement4, "zpNuggetInvisible");

	int outpost1Grp1 = rmGetGroupingInstanceUnitByType(templePlacement, "zpSPCSocketAztecOutpost1");
	int outpost2Grp1 = rmGetGroupingInstanceUnitByType(templePlacement, "zpSPCSocketAztecOutpost2");
	int outpost3Grp1 = rmGetGroupingInstanceUnitByType(templePlacement, "zpSPCSocketAztecOutpost3");
	int outpost4Grp1 = rmGetGroupingInstanceUnitByType(templePlacement, "zpSPCSocketAztecOutpost4");

	int outpost1Grp2 = rmGetGroupingInstanceUnitByType(woodPlacement, "zpSPCSocketAztecOutpost1");
	int outpost2Grp2 = rmGetGroupingInstanceUnitByType(woodPlacement, "zpSPCSocketAztecOutpost2");
	int outpost3Grp2 = rmGetGroupingInstanceUnitByType(woodPlacement, "zpSPCSocketAztecOutpost3");
	int outpost4Grp2 = rmGetGroupingInstanceUnitByType(woodPlacement, "zpSPCSocketAztecOutpost4");

	int outpost1Grp3 = rmGetGroupingInstanceUnitByType(foodPlacement, "zpSPCSocketAztecOutpost1");
	int outpost2Grp3 = rmGetGroupingInstanceUnitByType(foodPlacement, "zpSPCSocketAztecOutpost2");
	int outpost3Grp3 = rmGetGroupingInstanceUnitByType(foodPlacement, "zpSPCSocketAztecOutpost3");
	int outpost4Grp3 = rmGetGroupingInstanceUnitByType(foodPlacement, "zpSPCSocketAztecOutpost4");

	int outpost1Grp4 = rmGetGroupingInstanceUnitByType(goldPlacement, "zpSPCSocketAztecOutpost1");
	int outpost2Grp4 = rmGetGroupingInstanceUnitByType(goldPlacement, "zpSPCSocketAztecOutpost2");
	int outpost3Grp4 = rmGetGroupingInstanceUnitByType(goldPlacement, "zpSPCSocketAztecOutpost3");
	int outpost4Grp4 = rmGetGroupingInstanceUnitByType(goldPlacement, "zpSPCSocketAztecOutpost4");

	int citadelCitadelMod1 = citadelCitadel1+0;
	int citadelCitadelMod2 = citadelCitadel2+0;
	int citadelCitadelMod3 = citadelCitadel3+0;
	int citadelCitadelMod4 = citadelCitadel4+0;

	int citadelNuggetMod1 = citadelNugget1+0;
	int citadelNuggetMod2 = citadelNugget2+0;
	int citadelNuggetMod3 = citadelNugget3+0;
	int citadelNuggetMod4 = citadelNugget4+0;

	int socketMod1 = socketTemple+0;
	int socketMod2 = socketWood+0;
	int socketMod3 = socketFood+0;
	int socketMod4 = socketGold+0;

	int centerMod1 = centerTemple+0;
	int centerMod2 = centerWood+0;
	int centerMod3 = centerFood+0;
	int centerMod4 = centerGold+0;

	int outpost1Mod1 = outpost1Grp1+0;
	int outpost2Mod1 = outpost2Grp1+0;
	int outpost3Mod1 = outpost3Grp1+0;
	int outpost4Mod1 = outpost4Grp1+0;

	int outpost1Mod2 = outpost1Grp2+0;
	int outpost2Mod2 = outpost2Grp2+0;
	int outpost3Mod2 = outpost3Grp2+0;
	int outpost4Mod2 = outpost4Grp2+0;

	int outpost1Mod3 = outpost1Grp3+0;
	int outpost2Mod3 = outpost2Grp3+0;
	int outpost3Mod3 = outpost3Grp3+0;
	int outpost4Mod3 = outpost4Grp3+0;

	int outpost1Mod4 = outpost1Grp4+0;
	int outpost2Mod4 = outpost2Grp4+0;
	int outpost3Mod4 = outpost3Grp4+0;
	int outpost4Mod4 = outpost4Grp4+0;

	vector districtLoc1 = rmGetUnitPosition(centerTemple);
	vector districtLoc2 = rmGetUnitPosition(centerWood);
	vector districtLoc3 = rmGetUnitPosition(centerFood);
	vector districtLoc4 = rmGetUnitPosition(centerGold);

	// Victory Timer
	int victoryCountDown = 1800;
	int socketMinimapFlareDuration = 10;

	// **************** Start Setup ******************

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpAztecCityGeneralSetup"); // Aztec Map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteNativeAmerican"); // Aztec Map
		rmSetTriggerEffectParamInt("Status",2);
	}
	for(i=1; <= cNumberNonGaiaPlayers) {
		if (rmGetPlayerTeam(i) == 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpAztecCityAttackerSetup"); // Aztec Map
			rmSetTriggerEffectParamInt("Status",2);
		}
		else {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpAztecCityDefenderSetup"); // Aztec Map
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	if (cNumberNonGaiaPlayers >2){
		rmCreateTrigger("Starting Resources");
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","deMineGoldBuildable");
		rmSetTriggerEffectParam("Resource","Gold");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	rmCreateTrigger("Starting Trade Routes");
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParamInt("Level",1);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParamInt("Level",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	
	// **************** Victory Conditions ******************

	rmCreateTrigger("Victory_Setup");
	rmCreateTrigger("Victory_Defenders");
	rmCreateTrigger("Victory_Attackers");
	rmCreateTrigger("4_Socket_Hold");
	rmCreateTrigger("3_Socket_Hold");
	rmCreateTrigger("2_Socket_Hold");
	rmCreateTrigger("1_Socket_Hold");

	rmSwitchToTrigger(rmTriggerID("Victory_Setup"));
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VictoryCounter");
	rmSetTriggerEffectParamInt("Start", victoryCountDown);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","{302450}"); // Counter Message
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Victory_Defenders"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Victory_Defenders"));
	rmAddTriggerEffect("Team Victory");
	rmSetTriggerEffectParamInt("TeamID", 2);
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Victory_Attackers"));
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",firstDefender);
	rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Team Victory");
	rmSetTriggerEffectParamInt("TeamID", 1);
	rmSetTriggerPriority(1); 
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("4_Socket_Hold"));
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",firstDefender);
	rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",4);
	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text", "Defender: 4 sockets");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("3_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("2_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("1_Socket_Hold"));
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("3_Socket_Hold"));
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",firstDefender);
	rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",3);
	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text", "Defender: 3 sockets");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("4_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("2_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("1_Socket_Hold"));
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("2_Socket_Hold"));
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",firstDefender);
	rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",2);
	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text", "Defender: 2 sockets");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("3_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("4_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("1_Socket_Hold"));
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("1_Socket_Hold"));
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",firstDefender);
	rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text", "Defender: 1 socket");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("3_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("2_Socket_Hold"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("4_Socket_Hold"));
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ************************ DEFENDER SETUP *******************

	rmCreateTrigger("Defender_Setup0");
	rmCreateTrigger("Defender_Setup1");

	rmSwitchToTrigger(rmTriggerID("Defender_Setup0"));
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+centerPointID);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer", firstDefender);
	rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
	rmSetTriggerEffectParamInt("Dist",300);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+centerPointID);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer", firstDefender);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketAztecOutpost1");
	rmSetTriggerEffectParamInt("Dist",300);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+centerPointID);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer", firstDefender);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketAztecOutpost2");
	rmSetTriggerEffectParamInt("Dist",300);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Defender_Setup1"));
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+socketTemple);
	rmSetTriggerEffectParam("Protounit","TradingPost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+socketWood);
	rmSetTriggerEffectParam("Protounit","TradingPost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+socketFood);
	rmSetTriggerEffectParam("Protounit","TradingPost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+socketGold);
	rmSetTriggerEffectParam("Protounit","TradingPost");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Defender_Setup1"));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",10);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", firstDefender);
	rmSetTriggerEffectParam("TechID","cTechzpAztecConverGate");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost1Mod1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost2Mod1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost3Mod1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost4Mod1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost1Mod2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost2Mod2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost3Mod2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost4Mod2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost1Mod3);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost2Mod3);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost3Mod3);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost4Mod3);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost1Mod4);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost2Mod4);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost3Mod4);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+outpost4Mod4);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");

	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+tower1PointID1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+tower1PointID2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+tower2PointID1);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerEffectParam("Socket",""+tower2PointID2);
	rmSetTriggerEffectParam("Protounit","zpAztecCityOutpost");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Attackers"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ************************* NATIVE POLITICIANS **************************	

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
	rmCreateTrigger("Activate WaterTemple"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickNativeConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWaterTemple"); //operator
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_WaterTemple"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}
	

	// ****************** Convert Districts ******************

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("District1on Player"+k);
		rmCreateTrigger("District1off Player"+k);
		rmCreateTrigger("District1off_Dellayed_Player"+k);

		rmCreateTrigger("District2on Player"+k);
		rmCreateTrigger("District2off Player"+k);
		rmCreateTrigger("District2off_Dellayed_Player"+k);

		rmCreateTrigger("District3on Player"+k);
		rmCreateTrigger("District3off Player"+k);
		rmCreateTrigger("District3off_Dellayed_Player"+k);

		rmCreateTrigger("District4on Player"+k);
		rmCreateTrigger("District4off Player"+k);
		rmCreateTrigger("District4off_Dellayed_Player"+k);

		// Grouping 1

		rmSwitchToTrigger(rmTriggerID("District1on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecGreatTemple");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecMediumTemple");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpAztecAltar");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc1)+","+xsVectorGetY(districtLoc1)+","+xsVectorGetZ(districtLoc1), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District1off_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);



		rmSwitchToTrigger(rmTriggerID("District1off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District1off_Dellayed_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District1on_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("District1off_Dellayed_Player"+k));
		rmAddTriggerCondition("Timer ms");

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecGreatTemple");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecMediumTemple");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpAztecAltar");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc1)+","+xsVectorGetY(districtLoc1)+","+xsVectorGetZ(districtLoc1), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp1);
		rmSetTriggerEffectParamInt("PlayerID",0);
        
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);


		// Grouping 2

		rmSwitchToTrigger(rmTriggerID("District2on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecShrine");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecForester");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc2)+","+xsVectorGetY(districtLoc2)+","+xsVectorGetZ(districtLoc2), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp2);
		rmSetTriggerEffectParamInt("PlayerID",k);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District2off_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);



		rmSwitchToTrigger(rmTriggerID("District2off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District2off_Dellayed_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District2on_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("District2off_Dellayed_Player"+k));
		rmAddTriggerCondition("Timer ms");

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecShrine");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecForester");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc2)+","+xsVectorGetY(districtLoc2)+","+xsVectorGetZ(districtLoc2), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp2);
		rmSetTriggerEffectParamInt("PlayerID",0);
        
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);


		// Grouping 3

		rmSwitchToTrigger(rmTriggerID("District3on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecGranary");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deField");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc3)+","+xsVectorGetY(districtLoc3)+","+xsVectorGetZ(districtLoc3), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpAztecUnlockGroupingTechs"); // Island Techs
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District3off_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);



		rmSwitchToTrigger(rmTriggerID("District3off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpAztecLockGroupingTechs"); // Island Techs
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District3off_Dellayed_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District3on_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("District3off_Dellayed_Player"+k));
		rmAddTriggerCondition("Timer ms");

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecGranary");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deField");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc3)+","+xsVectorGetY(districtLoc3)+","+xsVectorGetZ(districtLoc3), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp3);
		rmSetTriggerEffectParamInt("PlayerID",0);
        
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);


		// Grouping 4

		rmSwitchToTrigger(rmTriggerID("District4on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecTreasury");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecCityMarket");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc4)+","+xsVectorGetY(districtLoc4)+","+xsVectorGetZ(districtLoc4), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp4);
		rmSetTriggerEffectParamInt("PlayerID",k);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District4off_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);



		rmSwitchToTrigger(rmTriggerID("District4off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District4off_Dellayed_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("District4on_Player"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("District4off_Dellayed_Player"+k));
		rmAddTriggerCondition("Timer ms");

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecTreasury");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCAztecCityMarket");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+centerMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpAztecCityOutpost");
		rmSetTriggerEffectParamInt("Dist",45);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(districtLoc4)+","+xsVectorGetY(districtLoc4)+","+xsVectorGetZ(districtLoc4), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost1Grp4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost2Grp4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost3Grp4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+outpost4Grp4);
		rmSetTriggerEffectParamInt("PlayerID",0);
        
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// ***************** Other *****************

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Embassy Player"+k);
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpNativeEmbassyParisReward");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSPCAztecMercenaries");
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.99);

} // END