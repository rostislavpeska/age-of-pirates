// Paris
// October 2024

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
    int subCiv3=-1;

	if (rmAllocateSubCivs(4) == true)
	{
		subCiv0=rmGetCivID("maltese");
		rmEchoInfo("subCiv0 is maltese "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "maltese");

		subCiv1=rmGetCivID("spcjesuit");
		rmEchoInfo("subCiv1 is spcjesuit "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "spcjesuit");
  
		subCiv2=rmGetCivID("SPCbourbon");
		rmEchoInfo("subCiv2 is SPCbourbon "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "SPCbourbon");

        subCiv3=rmGetCivID("zpSansculottes");
		rmEchoInfo("subCiv3 is zpSansculottes "+subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "zpSansculottes");
	}

    int sizeZ = 360;
	int sizeX = 573;

	if (cNumberNonGaiaPlayers >=3)
		sizeX = 653;
	if (cNumberNonGaiaPlayers >=6)
		sizeX = 823;
	rmSetMapSize(sizeX, sizeZ);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original

	// Big city for 6+ players
	int bigCity = 0;
	if (cNumberNonGaiaPlayers>=6)
		bigCity = 1;
	int citySize = 0;
	//int citySizeN = 0.5;
	if (bigCity == 1){
		citySize = 17;
		//citySizeN = rmXTilesToFraction(34);
	}

	rmSetAllMapReveal(true);
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);
   
   	// LIGHT SET

	rmSetLightingSet("age3challenges09a");


	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
    //rmSetSeaType(seaType);
    //rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("land");
    rmSetMapType("default");
    rmSetMapType("westEurope");
	rmSetMapType("piratehistoricalmap");
    rmSetMapType("euroTradeRouteUpgradeAll");

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
	int classStreet=rmDefineClass("classStreet");

	// Spawn Switch
	float spawnSwitch = rmRandInt(0,1);

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
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineTin", 30.0);
	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "Mine", 30.0);
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
	int avoidNugget=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 60.0);
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
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "deSPCCommandPost", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "deSPCCommandPost", 6.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);


   	float playerFraction=rmAreaTilesToFraction(850);

	int southwestWall = rmCreateGrouping("wall sw", "eu_wall_sw_socketable");
    rmSetGroupingMinDistance(southwestWall, 0.00);
    rmSetGroupingMaxDistance(southwestWall, 0.00);
	rmAddGroupingToClass(southwestWall, rmClassID("classBlock"));

	int northeastWall = rmCreateGrouping("wall ne", "eu_wall_ne_socketable");
    rmSetGroupingMinDistance(northeastWall, 0.00);
    rmSetGroupingMaxDistance(northeastWall, 0.00);
	rmAddGroupingToClass(northeastWall, rmClassID("classBlock"));

	int cityWall1 = rmPlaceGroupingInstanceAtLoc(southwestWall, 0.5-rmXTilesToFraction(citySize+90), 0.519, 0);
	int cityWall2 = rmPlaceGroupingInstanceAtLoc(northeastWall, 0.5+rmXTilesToFraction(citySize+90), 0.512, 0);


	// ********************* Trade Route *******************************

    // Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

	int socketID=rmCreateObjectDef("TR Socket");
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0);

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
   
    rmAddTradeRouteWaypoint(tradeRouteID, 0.0, .5);
    rmAddTradeRouteWaypoint(tradeRouteID, .5, .5);
    rmAddTradeRouteWaypoint(tradeRouteID, 1.00, .5);
    rmBuildTradeRoute(tradeRouteID, "dirt");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
	if (cNumberNonGaiaPlayers ==2){
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.05);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.95);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	}
	else{
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	}



	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	//  ************************** River ******************************

    // River must be defined before the islands are placed
    int riverID = rmRiverCreate(-1, "ZP Paris River", 4, 4, 30, 30); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.5, 0.0);
    rmRiverAddWaypoint(riverID, 0.5, 1.0);
	rmRiverBuild(riverID);

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!! ISLANDS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    rmDefineClass("classPlateau");

    // Bastille in the center
	int bastilleGrouping = rmCreateGrouping("bridge1", "EU_island_Bastille");
    rmSetGroupingMinDistance(bastilleGrouping, 0.00);
    rmSetGroupingMaxDistance(bastilleGrouping, 0.00);
	rmAddGroupingToClass(bastilleGrouping, rmClassID("classPlateau"));
	//rmPlaceGroupingAtLoc(bastilleGrouping, 0, 0.5-rmXTilesToFraction(1), 0.5+rmXTilesToFraction(4));

	int victoryGrouping1 = rmPlaceGroupingInstanceAtLoc(bastilleGrouping, 0.5-rmXTilesToFraction(1), 0.5+rmXTilesToFraction(4), 0);

    // Nothe Dame West
    int notredameGrouping = rmCreateGrouping("bridge2", "EU_island_Notre_Dame");
    rmSetGroupingMinDistance(notredameGrouping, 0.00);
    rmSetGroupingMaxDistance(notredameGrouping, 0.00);
	rmAddGroupingToClass(notredameGrouping, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(notredameGrouping, 0, 0.5, 0.83);

    // Bridge East
    int bridgeGrouping = rmCreateGrouping("bridge3", "EU_island_Bridge");
    rmSetGroupingMinDistance(bridgeGrouping, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping, 0.00);
	rmAddGroupingToClass(bridgeGrouping, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(bridgeGrouping, 0, 0.5-rmXTilesToFraction(1), 0.2);

    // Additional Constraints - based on dansil original constraints
    int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);
    int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.5-rmXTilesToFraction(citySize+85), 0.0, 0.5-rmXTilesToFraction(16), 1.0);
    int cityNorthConstraint = rmCreateBoxConstraint("stay in the city north", 0.5+rmXTilesToFraction(16), 0.0, 0.5+rmXTilesToFraction(citySize+85), 1.0);

    int classPatch = rmDefineClass("patch");
    int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 2.0);
	int avoidStreet = rmCreateClassDistanceConstraint("avoid street", classStreet, 10.0);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall object", "AbstractWall", 0.001);
	int avoidWallMedium=rmCreateTypeDistanceConstraint("avoid wall object medium", "AbstractWall", 2.0);
	int avoidWallLong=rmCreateTypeDistanceConstraint("avoid wall object long", "AbstractWall", 10.0);

	rmSetStatusText("",0.30);
        
    // Shorelines to make the bridges look smooth

    int shoreLineSouth = rmCreateArea("shore South");
    rmSetAreaSize(shoreLineSouth, 0.7, 0.7);
    rmSetAreaLocation(shoreLineSouth, 0.5-rmXTilesToFraction(55), 0.5);	
    rmSetAreaCoherence(shoreLineSouth, 1.0);	
    rmSetAreaBaseHeight(shoreLineSouth, 1.0);
    rmAddAreaInfluenceSegment(shoreLineSouth, 0.4, 0.85, 0.4, 0.15);
    rmSetAreaCliffType(shoreLineSouth, "ZP City");
    //rmSetAreaSmoothDistance(shoreLineSouth, 20);
    rmSetAreaCliffEdge(shoreLineSouth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineSouth, 0, 0.0, 1.0);
    rmAddAreaConstraint(shoreLineSouth , citySouthConstraint);
    rmAddAreaToClass(shoreLineSouth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineSouth, false);
    rmBuildArea(shoreLineSouth); 

    int shoreLineNorth = rmCreateArea("shore North");
    rmSetAreaSize(shoreLineNorth, 0.7, 0.7);
    rmSetAreaLocation(shoreLineNorth, 0.5+rmXTilesToFraction(55), 0.5);	
    rmSetAreaCoherence(shoreLineNorth, 1.0);	
    rmSetAreaBaseHeight(shoreLineNorth, 1.0);
    rmAddAreaInfluenceSegment(shoreLineNorth, 0.6, 0.85, 0.6, 0.15);
    rmSetAreaCliffType(shoreLineNorth, "ZP City");
    //rmSetAreaSmoothDistance(shoreLineNorth, 20);
    rmSetAreaCliffEdge(shoreLineNorth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineNorth, 0, 0.0, 1.0);
    rmAddAreaConstraint(shoreLineNorth , cityNorthConstraint);
    rmAddAreaToClass(shoreLineNorth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineNorth, false);
    rmBuildArea(shoreLineNorth); 

	// Streets terrain
	int streetsSouth = rmCreateArea("streets South");
    rmSetAreaSize(streetsSouth, 0.7, 0.7);
    rmSetAreaLocation(streetsSouth, 0.5-rmXTilesToFraction(55), 0.5);		
    rmSetAreaCoherence(streetsSouth, 1.0);	
	rmSetAreaTerrainType(streetsSouth, "city\ground1_cob_dark");
    rmAddAreaInfluenceSegment(streetsSouth, 0.4, 0.85, 0.4, 0.15);
    rmAddAreaConstraint(streetsSouth , citySouthConstraint);
	rmAddAreaConstraint(streetsSouth , avoidWater4);
    rmSetAreaObeyWorldCircleConstraint(streetsSouth, false);
	rmAddAreaToClass(streetsSouth , classStreet);
    rmBuildArea(streetsSouth); 

	// Streets terrain
	int streetsNorth = rmCreateArea("streets North");
    rmSetAreaSize(streetsNorth, 0.7, 0.7);
    rmSetAreaLocation(streetsNorth, 0.5+rmXTilesToFraction(55), 0.5);		
    rmSetAreaCoherence(streetsNorth, 1.0);	
	rmSetAreaTerrainType(streetsNorth, "city\ground1_cob_dark");
    rmAddAreaInfluenceSegment(streetsNorth, 0.4, 0.85, 0.4, 0.15);
    rmAddAreaConstraint(streetsNorth , cityNorthConstraint);
	rmAddAreaConstraint(streetsNorth , avoidWater4);
    rmSetAreaObeyWorldCircleConstraint(streetsNorth, false);
	rmAddAreaToClass(streetsNorth, classStreet);
    rmBuildArea(streetsNorth); 

    // Countryside terrain

    int countrysideSouth = rmCreateArea("countryside S");
    rmSetAreaSize(countrysideSouth , 0.6, 0.6);
    rmSetAreaLocation(countrysideSouth , 0.5-rmXTilesToFraction(130), 0.5);		
    rmSetAreaCoherence(countrysideSouth , 1.0);
    rmSetAreaBaseHeight(countrysideSouth, 1.0);
    rmAddAreaConstraint(countrysideSouth , avoidPlateauShort);
	rmAddAreaConstraint(countrysideSouth , avoidWallMedium);
    rmSetAreaMix(countrysideSouth, "nwt_grass1");
    rmSetAreaElevationType(countrysideSouth, cElevTurbulence);
    rmSetAreaElevationVariation(countrysideSouth, 2.0);
    rmSetAreaElevationPersistence(countrysideSouth, 0.2);
    rmSetAreaElevationNoiseBias(countrysideSouth, 1);
    rmBuildArea(countrysideSouth ); 

    int countrysideNorth = rmCreateArea("countryside N");
    rmSetAreaSize(countrysideNorth , 0.6, 0.6);
    rmSetAreaLocation(countrysideNorth , 0.5+rmXTilesToFraction(130), 0.5);		
    rmSetAreaCoherence(countrysideNorth , 1.0);
    rmSetAreaBaseHeight(countrysideNorth, 1.0);
    rmAddAreaConstraint(countrysideNorth , avoidPlateauShort);
	rmAddAreaConstraint(countrysideNorth , avoidWallMedium);
    rmSetAreaMix(countrysideNorth, "nwt_grass1");
    rmSetAreaElevationType(countrysideNorth, cElevTurbulence);
    rmSetAreaElevationVariation(countrysideNorth, 2.0);
    rmSetAreaElevationPersistence(countrysideNorth, 0.2);
    rmSetAreaElevationNoiseBias(countrysideNorth, 1);
    rmBuildArea(countrysideNorth ); 


	// Text
	rmSetStatusText("",0.40);


    //===========dansil code start============

		rmDefineClass("classBlock");
		//Constraints

int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), .001);
int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);

int cliffConstraint = rmCreateBoxConstraint("stay close to city", 0.5-rmXTilesToFraction(95), -0.5, 0.5+rmXTilesToFraction(95), 1.5);
int cliffHeightConstraint = rmCreateMaxHeightConstraint("not too high", 7);

//===================set up grid locations===================

	float locX1 = 0.5-rmXTilesToFraction(27);
	float locX2 = 0.5-rmXTilesToFraction(43);
	float locX3 = 0.5-rmXTilesToFraction(59);
	float locX4 = 0.5-rmXTilesToFraction(75);
	float locX5 = 0.5-rmXTilesToFraction(92);
	float locX6 = 0.5-rmXTilesToFraction(109);
	
	float locXm1 = 0.5+rmXTilesToFraction(27);
	float locXm2 = 0.5+rmXTilesToFraction(43);
	float locXm3 = 0.5+rmXTilesToFraction(59);
	float locXm4 = 0.5+rmXTilesToFraction(75);
	float locXm5 = 0.5+rmXTilesToFraction(92);
	float locXm6 = 0.5+rmXTilesToFraction(109);


	float locZ0 = 0.94;
	float locZ1 = 0.851;
	float locZ2 = 0.755;
	float locZ3 = 0.66;
	float locZ4 = 0.57;
	float locZ5 = 0.45;
	float locZ6 = 0.35;
	float locZ7 = 0.25;
	float locZ8 = 0.15;
	float locZ9 = 0.06;

	float palaceZ1 = 0.615;
	float palaceZ2 = 0.4;




//===================define groupings========================

// Fixed Placement

	// Palaces
	int blockPalaceBig01 = rmCreateGrouping("palace1", "EU_Natives_Block_Bourbon_1");
    rmSetGroupingMinDistance(blockPalaceBig01, 0.00);
    rmSetGroupingMaxDistance(blockPalaceBig01, 0.50);
	rmAddGroupingToClass(blockPalaceBig01, rmClassID("classBlock"));

	int blockPalaceBig02 = rmCreateGrouping("palace2", "EU_Natives_Block_Bourbon_2");
    rmSetGroupingMinDistance(blockPalaceBig02, 0.00);
    rmSetGroupingMaxDistance(blockPalaceBig02, 0.50);
	rmAddGroupingToClass(blockPalaceBig02, rmClassID("classBlock"));

	// Menagerie
	int blockMenagerie = rmCreateGrouping("menagerie", "EU_Resource_Block_Menagerie");
    rmSetGroupingMinDistance(blockMenagerie, 0.00);
    rmSetGroupingMaxDistance(blockMenagerie, 0.50);
	rmAddGroupingToClass(blockMenagerie, rmClassID("classBlock"));

	// Park
	int blockPark = rmCreateGrouping("park", "EU_House_Block_Park");
    rmSetGroupingMinDistance(blockPark, 0.00);
    rmSetGroupingMaxDistance(blockPark, 0.50);
	rmAddGroupingToClass(blockPark, rmClassID("classBlock"));

// City Center

	// Market
	int blockMarket = rmCreateGrouping("market", "EU_Resource_Block_All2");
    rmSetGroupingMinDistance(blockMarket, 0.00);
    rmSetGroupingMaxDistance(blockMarket, 0.50);
	rmAddGroupingToClass(blockMarket, rmClassID("classBlock"));

	// Bank
	int blockBank = rmCreateGrouping("bank", "EU_Resource_Block_Gold1");
    rmSetGroupingMinDistance(blockBank, 0.00);
    rmSetGroupingMaxDistance(blockBank, 0.50);
	rmAddGroupingToClass(blockBank, rmClassID("classBlock"));

	// Jesuit natives
	int blockJesuit = rmCreateGrouping("jesuit natives", "EU_Native_Block_Jesuit");
    rmSetGroupingMinDistance(blockJesuit, 0.00);
    rmSetGroupingMaxDistance(blockJesuit, 0.50);
	rmAddGroupingToClass(blockJesuit, rmClassID("classBlock"));

	// Maltese natives
	int blockMaltese = rmCreateGrouping("maltese natives", "EU_Native_Block_Maltese");
    rmSetGroupingMinDistance(blockMaltese, 0.00);
    rmSetGroupingMaxDistance(blockMaltese, 0.50);
	rmAddGroupingToClass(blockMaltese, rmClassID("classBlock"));

	// Text
	rmSetStatusText("",0.50);

// Outer Center

	// Sansculotte natives
	int blockSansculot = rmCreateGrouping("Sansculotte natives", "EU_Native_Block_Sanscoulot");
    rmSetGroupingMinDistance(blockSansculot, 0.00);
    rmSetGroupingMaxDistance(blockSansculot, 0.50);
	rmAddGroupingToClass(blockSansculot, rmClassID("classBlock"));

	// Bourbon natives
	int blockBourbon = rmCreateGrouping("Bourbon natives", "EU_Natives_Block_Bourbon_3");
    rmSetGroupingMinDistance(blockBourbon, 0.00);
    rmSetGroupingMaxDistance(blockBourbon, 0.50);
	rmAddGroupingToClass(blockBourbon, rmClassID("classBlock"));

	// Gold Smelter
	int blockGoldSmelter = rmCreateGrouping("Gold Smelter", "EU_Resource_Block_Gold2");
    rmSetGroupingMinDistance(blockGoldSmelter, 0.00);
    rmSetGroupingMaxDistance(blockGoldSmelter, 0.50);
	rmAddGroupingToClass(blockGoldSmelter, rmClassID("classBlock"));

	// Factory
	int blockFactory = rmCreateGrouping("Factory", "EU_Resource_Block_All1");
    rmSetGroupingMinDistance(blockFactory, 0.00);
    rmSetGroupingMaxDistance(blockFactory, 0.50);
	rmAddGroupingToClass(blockFactory, rmClassID("classBlock"));

	// Military Block
	int blockMilitary = rmCreateGrouping("Military Block", "EU_SPC_Block_Military");
    rmSetGroupingMinDistance(blockMilitary, 0.00);
    rmSetGroupingMaxDistance(blockMilitary, 0.50);
	rmAddGroupingToClass(blockMilitary, rmClassID("classBlock"));

	// Royal Court
	int blockCourt = rmCreateGrouping("Court", "EU_SPC_Block_Court");
    rmSetGroupingMinDistance(blockCourt, 0.00);
    rmSetGroupingMaxDistance(blockCourt, 0.50);
	rmAddGroupingToClass(blockCourt, rmClassID("classBlock"));

	// TownHall
	int blockTownHall = rmCreateGrouping("TownHall", "EU_SPC_Block_TownHall");
    rmSetGroupingMinDistance(blockTownHall, 0.00);
    rmSetGroupingMaxDistance(blockTownHall, 0.50);
	rmAddGroupingToClass(blockTownHall, rmClassID("classBlock"));

// Suburb

	// Mill
	int blockMill = rmCreateGrouping("Mill", "EU_Resource_Block_Food1");
    rmSetGroupingMinDistance(blockMill, 0.00);
    rmSetGroupingMaxDistance(blockMill, 0.50);
	rmAddGroupingToClass(blockMill, rmClassID("classBlock"));

	// Destilery
	int blockDestilery = rmCreateGrouping("Destilery", "EU_Resource_Block_Food2");
    rmSetGroupingMinDistance(blockDestilery, 0.00);
    rmSetGroupingMaxDistance(blockDestilery, 0.50);
	rmAddGroupingToClass(blockDestilery, rmClassID("classBlock"));

	// Forester
	int blockForester = rmCreateGrouping("Forester", "EU_Resource_Block_Wood2");
    rmSetGroupingMinDistance(blockForester, 0.00);
    rmSetGroupingMaxDistance(blockForester, 0.50);
	rmAddGroupingToClass(blockForester, rmClassID("classBlock"));

	// Warehouse
	int blockWarehouse = rmCreateGrouping("Warehouse", "EU_Resource_Block_Wood1");
    rmSetGroupingMinDistance(blockWarehouse, 0.00);
    rmSetGroupingMaxDistance(blockWarehouse, 0.50);
	rmAddGroupingToClass(blockWarehouse, rmClassID("classBlock"));

	// Construction Block
	int blockConstruction = rmCreateGrouping("Construction", "EU_SPC_Block_Constr");
    rmSetGroupingMinDistance(blockConstruction, 0.00);
    rmSetGroupingMaxDistance(blockConstruction, 0.50);
	rmAddGroupingToClass(blockConstruction, rmClassID("classBlock"));

// Everywhere

	// Bastion Blocks
	int blockBastion01 = rmCreateGrouping("Bastion1", "EU_House_Block_Bastion01");
    rmSetGroupingMinDistance(blockBastion01, 0.00);
    rmSetGroupingMaxDistance(blockBastion01, 0.50);
	rmAddGroupingToClass(blockBastion01, rmClassID("classBlock"));

	int blockBastion02 = rmCreateGrouping("Bastion2", "EU_House_Block_Bastion02");
    rmSetGroupingMinDistance(blockBastion02, 0.00);
    rmSetGroupingMaxDistance(blockBastion02, 0.50);
	rmAddGroupingToClass(blockBastion02, rmClassID("classBlock"));

	int blockEmbassy = rmCreateGrouping("Native Embassy", "EU_House_Block_Embassy");
    rmSetGroupingMinDistance(blockEmbassy, 0.00);
    rmSetGroupingMaxDistance(blockEmbassy, 0.50);
	rmAddGroupingToClass(blockEmbassy, rmClassID("classBlock"));

	// Treasure Blocks
	int blockTreasure01 = rmCreateGrouping("Treasure1", "EU_House_Block_Treasure1");
    rmSetGroupingMinDistance(blockTreasure01, 0.00);
    rmSetGroupingMaxDistance(blockTreasure01, 0.50);
	rmAddGroupingToClass(blockTreasure01, rmClassID("classBlock"));

	int blockTreasure02 = rmCreateGrouping("Treasure2", "EU_House_Block_Treasure2");
    rmSetGroupingMinDistance(blockTreasure02, 0.00);
    rmSetGroupingMaxDistance(blockTreasure02, 0.50);
	rmAddGroupingToClass(blockTreasure02, rmClassID("classBlock"));

	// House Blocks
	int blockHouse01 = rmCreateGrouping("house1", "EU_House_Block_01");
    rmSetGroupingMinDistance(blockHouse01, 0.00);
    rmSetGroupingMaxDistance(blockHouse01, 0.50);
	rmAddGroupingToClass(blockHouse01, rmClassID("classBlock"));

	int blockHouse02 = rmCreateGrouping("house2", "EU_House_Block_02");
    rmSetGroupingMinDistance(blockHouse02, 0.00);
    rmSetGroupingMaxDistance(blockHouse02, 0.50);
	rmAddGroupingToClass(blockHouse02, rmClassID("classBlock"));

	int blockHouse03 = rmCreateGrouping("house3", "EU_House_Block_03");
    rmSetGroupingMinDistance(blockHouse03, 0.00);
    rmSetGroupingMaxDistance(blockHouse03, 0.50);
	rmAddGroupingToClass(blockHouse03, rmClassID("classBlock"));

	int blockHouse04 = rmCreateGrouping("house4", "EU_House_Block_04");
    rmSetGroupingMinDistance(blockHouse04, 0.00);
    rmSetGroupingMaxDistance(blockHouse04, 0.50);
	rmAddGroupingToClass(blockHouse04, rmClassID("classBlock"));

	int blockHouse05 = rmCreateGrouping("house5", "EU_House_Block_05");
    rmSetGroupingMinDistance(blockHouse05, 0.00);
    rmSetGroupingMaxDistance(blockHouse05, 0.50);
	rmAddGroupingToClass(blockHouse05, rmClassID("classBlock"));

	int blockHouse06 = rmCreateGrouping("house6", "EU_House_Block_06");
    rmSetGroupingMinDistance(blockHouse06, 0.00);
    rmSetGroupingMaxDistance(blockHouse06, 0.50);
	rmAddGroupingToClass(blockHouse06, rmClassID("classBlock"));

	// Riverside groupings on both sides of the river 
	int cityShoreline01 = rmCreateGrouping("shoreline_grouping_01", "EU_Riverside_SW_01");
    rmSetGroupingMinDistance(cityShoreline01, 0.00);
    rmSetGroupingMaxDistance(cityShoreline01, 0.50);
	rmAddGroupingToClass(cityShoreline01, rmClassID("classBlock"));

	int cityShoreline02 = rmCreateGrouping("shoreline_grouping_02", "EU_Riverside_NE_01");
    rmSetGroupingMinDistance(cityShoreline02, 0.00);
    rmSetGroupingMaxDistance(cityShoreline02, 0.50);
	rmAddGroupingToClass(cityShoreline02, rmClassID("classBlock"));



//===================define randomizer for placement============

//	int cityRandomizer = rmRandInt(0,0);

	rmSetStatusText("",0.60);

// Placement Variables
int jesuitMaltese = rmRandInt(1, 2);

//===================place the stuff=========================

// Fixed stuff first

	// Palaces
	rmPlaceGroupingAtLoc(blockPalaceBig01, 0, locX1, palaceZ1);
	rmPlaceGroupingAtLoc(blockPalaceBig02, 0, locXm1, palaceZ2);

	// Palace gardens
	rmPlaceGroupingAtLoc(blockMenagerie, 0, locX2, locZ3);
	rmPlaceGroupingAtLoc(blockMenagerie, 0, locXm2, locZ5);

	rmPlaceGroupingAtLoc(blockPark, 0, locXm2, locZ6);
	rmPlaceGroupingAtLoc(blockPark, 0, locX2, locZ4);


	if (bigCity==0){
	// City Center

		rmPlaceGroupingAtLoc(blockMarket, 0, locX2, locZ1);
		rmPlaceGroupingAtLoc(blockMarket, 0, locXm2, locZ8);

		if (cNumberNonGaiaPlayers>=4){
			rmPlaceGroupingAtLoc(blockMarket, 0, locX2, locZ8);
			rmPlaceGroupingAtLoc(blockMarket, 0, locXm2, locZ1);
		}

		rmPlaceGroupingAtLoc(blockBank, 0, locX1, locZ7);
		rmPlaceGroupingAtLoc(blockBank, 0, locXm1, locZ2);

		if (cNumberNonGaiaPlayers>=4){
			rmPlaceGroupingAtLoc(blockBank, 0, locX1, locZ2);
		rmPlaceGroupingAtLoc(blockBank, 0, locXm1, locZ7);
		}


	// Outer Center

		rmPlaceGroupingAtLoc(blockSansculot, 0, locX3, locZ7);
		rmPlaceGroupingAtLoc(blockSansculot, 0, locXm3, locZ2);

		if (cNumberNonGaiaPlayers>=4){
			if (spawnSwitch ==0){
				rmPlaceGroupingAtLoc(blockSansculot, 0, locX1, locZ0);
				rmPlaceGroupingAtLoc(blockBourbon, 0, locXm1, locZ9);
			}
			else{
				rmPlaceGroupingAtLoc(blockBourbon, 0, locX1, locZ0);
				rmPlaceGroupingAtLoc(blockSansculot, 0, locXm1, locZ9);
			}
		}

		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locX3, locZ2);
		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locXm3, locZ7);

		rmPlaceGroupingAtLoc(blockFactory, 0, locX3, locZ8);
		rmPlaceGroupingAtLoc(blockFactory, 0, locXm3, locZ1);

		int cityState1 = rmPlaceGroupingInstanceAtLoc(blockMilitary, locX3, locZ4, 0);
		int cityState2 = rmPlaceGroupingInstanceAtLoc(blockMilitary, locXm3, locZ5, 0);

		int victoryGrouping2 = rmPlaceGroupingInstanceAtLoc(blockCourt, locX3, locZ1, 0);
		int victoryGrouping3 = rmPlaceGroupingInstanceAtLoc(blockTownHall, locXm3, locZ8, 0);


	// Suburb


		rmPlaceGroupingAtLoc(blockDestilery, 0, locX4, locZ3);
		rmPlaceGroupingAtLoc(blockDestilery, 0, locXm4, locZ6);

		rmPlaceGroupingAtLoc(blockWarehouse, 0, locX4, locZ9);
		rmPlaceGroupingAtLoc(blockWarehouse, 0, locXm4, locZ0);

		rmPlaceGroupingAtLoc(blockConstruction, 0, locX4, locZ4);
		rmPlaceGroupingAtLoc(blockConstruction, 0, locXm4, locZ5);

		if (cNumberNonGaiaPlayers>=4){
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX4, locZ8);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locXm4, locZ1);
		}

	// Everywhere

		rmSetNuggetDifficulty(194, 194);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locX3, locZ3);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locXm3, locZ6);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locXm3, locZ3);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locX3, locZ6);

		rmSetNuggetDifficulty(195, 195);
		rmPlaceGroupingAtLoc(blockEmbassy, 0, locX1, locZ5);
		rmPlaceGroupingAtLoc(blockEmbassy, 0, locXm1, locZ4);

		rmSetNuggetDifficulty(192, 192);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locXm4, locZ2);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locXm1, locZ0);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locX4, locZ7);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locX1, locZ9);

	}

	else{
	// City Center


		rmPlaceGroupingAtLoc(blockMarket, 0, locX3, locZ5);
		rmPlaceGroupingAtLoc(blockMarket, 0, locXm3, locZ4);

		rmPlaceGroupingAtLoc(blockBank, 0, locX1, locZ7);
		rmPlaceGroupingAtLoc(blockBank, 0, locXm1, locZ2);

		if (jesuitMaltese ==1){
			rmPlaceGroupingAtLoc(blockJesuit, 0, locX2, locZ5);
			rmPlaceGroupingAtLoc(blockMaltese, 0, locXm2, locZ4);
		}
		else{
			rmPlaceGroupingAtLoc(blockMaltese, 0, locX2, locZ5);
			rmPlaceGroupingAtLoc(blockJesuit, 0, locXm2, locZ4);
		}

	// Outer Center

		if (spawnSwitch ==0){
			rmPlaceGroupingAtLoc(blockSansculot, 0, locX3, locZ7);
			rmPlaceGroupingAtLoc(blockSansculot, 0, locXm3, locZ2);

			rmPlaceGroupingAtLoc(blockSansculot, 0, locX3, locZ2);
			rmPlaceGroupingAtLoc(blockBourbon, 0, locXm3, locZ7);

			rmPlaceGroupingAtLoc(blockSansculot, 0, locX4, locZ6);
			rmPlaceGroupingAtLoc(blockBourbon, 0, locXm4, locZ3);

			if (cNumberNonGaiaPlayers==8){
				rmPlaceGroupingAtLoc(blockSansculot, 0, locX4, locZ3);
				rmPlaceGroupingAtLoc(blockBourbon, 0, locXm4, locZ6);
			}
		}

		if (spawnSwitch ==1){
			rmPlaceGroupingAtLoc(blockSansculot, 0, locX3, locZ7);
			rmPlaceGroupingAtLoc(blockSansculot, 0, locXm3, locZ2);

			rmPlaceGroupingAtLoc(blockBourbon, 0, locX3, locZ2);
			rmPlaceGroupingAtLoc(blockSansculot, 0, locXm3, locZ7);

			rmPlaceGroupingAtLoc(blockBourbon, 0, locX4, locZ6);
			rmPlaceGroupingAtLoc(blockSansculot, 0, locXm4, locZ3);

			if (cNumberNonGaiaPlayers==8){
				rmPlaceGroupingAtLoc(blockBourbon, 0, locX4, locZ3);
				rmPlaceGroupingAtLoc(blockSansculot, 0, locXm4, locZ6);
			}
		}

		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locX3, locZ6);
		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locXm3, locZ3);

		rmPlaceGroupingAtLoc(blockFactory, 0, locX3, locZ8);
		rmPlaceGroupingAtLoc(blockFactory, 0, locXm3, locZ1);

		cityState1 = rmPlaceGroupingInstanceAtLoc(blockMilitary, locX4, locZ4, 0);
		cityState2 = rmPlaceGroupingInstanceAtLoc(blockMilitary, locXm4, locZ5, 0);

		victoryGrouping2 = rmPlaceGroupingInstanceAtLoc(blockCourt, locX3, locZ1, 0);
		victoryGrouping3 = rmPlaceGroupingInstanceAtLoc(blockTownHall, locXm3, locZ8, 0);


	// Suburb

		rmPlaceGroupingAtLoc(blockDestilery, 0, locX5, locZ1);
		rmPlaceGroupingAtLoc(blockDestilery, 0, locXm5, locZ8);

		rmPlaceGroupingAtLoc(blockWarehouse, 0, locX5, locZ2);
		rmPlaceGroupingAtLoc(blockWarehouse, 0, locXm5, locZ7);

		rmPlaceGroupingAtLoc(blockConstruction, 0, locX5, locZ5);
		rmPlaceGroupingAtLoc(blockConstruction, 0, locXm5, locZ4);

		rmPlaceGroupingAtLoc(blockConstruction, 0, locX5, locZ4);
		rmPlaceGroupingAtLoc(blockConstruction, 0, locXm5, locZ5);

		rmPlaceGroupingAtLoc(blockConstruction, 0, locX4, locZ8);
		rmPlaceGroupingAtLoc(blockConstruction, 0, locXm4, locZ1);

		if (cNumberNonGaiaPlayers==8){
			rmPlaceGroupingAtLoc(blockConstruction, 0, locX4, locZ9);
			rmPlaceGroupingAtLoc(blockConstruction, 0, locXm4, locZ0);
		}

	// Everywhere

		rmSetNuggetDifficulty(194, 194);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locX3, locZ3);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locXm3, locZ6);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locXm3, locZ3);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locX3, locZ6);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locX4, locZ5);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locXm4, locZ5);
		//rmPlaceGroupingAtLoc(blockBastion01, 0, locXm6, locZ0);
		//rmPlaceGroupingAtLoc(blockBastion02, 0, locX6, locZ9);

		rmSetNuggetDifficulty(195, 195);
		rmPlaceGroupingAtLoc(blockEmbassy, 0, locX1, locZ5);
		rmPlaceGroupingAtLoc(blockEmbassy, 0, locXm1, locZ4);

		rmSetNuggetDifficulty(192, 192);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locXm1, locZ9);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locXm1, locZ0);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locX1, locZ0);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locX1, locZ9);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locXm5, locZ0);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locX5, locZ9);
		//rmPlaceGroupingAtLoc(blockTreasure02, 0, locXm6, locZ9);
		//rmPlaceGroupingAtLoc(blockTreasure01, 0, locX6, locZ0);

	}

// South Bank

	//first row
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX1, locZ0);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX1, locZ1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX1, locZ2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX1, locZ3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX1, locZ4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX1, locZ5);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX1, locZ6);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX1, locZ7);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX1, locZ8);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX1, locZ9);

	//second row

	rmPlaceGroupingAtLoc(blockHouse05, 0, locX2, locZ0);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX2, locZ1);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZ2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX2, locZ3);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX2, locZ4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX2, locZ5);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX2, locZ6);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX2, locZ7);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX2, locZ8);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX2, locZ9);

	//third row

	rmPlaceGroupingAtLoc(blockHouse03, 0, locX3, locZ0);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZ1);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX3, locZ2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX3, locZ3);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX3, locZ4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZ5);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX3, locZ6);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZ7);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX3, locZ8);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX3, locZ9);

	//fourth row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZ0);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX4, locZ1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX4, locZ3);
	//rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZ4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX4, locZ5);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZ6);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX4, locZ7);
	if (cNumberNonGaiaPlayers <=3)
		rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ8);
	if (bigCity == 0)
		rmPlaceGroupingAtLoc(blockHouse04, 0, locX4, locZ9);
	
	if (bigCity == 1){

		//fifth row

		rmPlaceGroupingAtLoc(blockHouse05, 0, locX5, locZ0);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZ1);
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX5, locZ2);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX5, locZ3);
		//rmPlaceGroupingAtLoc(blockHouse03, 0, locX5, locZ4);
		//rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZ5);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locX5, locZ6);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZ7);
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX5, locZ8);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX5, locZ9);
		
	}

// North Bank

	//first row
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm1, locZ0);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm1, locZ1);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm1, locZ2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm1, locZ3);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm1, locZ4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locXm1, locZ5);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm1, locZ6);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm1, locZ7);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm1, locZ8);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm1, locZ9);

	//second row

	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm2, locZ0);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locXm2, locZ1);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm2, locZ2);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm2, locZ3);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm2, locZ4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm2, locZ5);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm2, locZ6);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locXm2, locZ7);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm2, locZ8);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm2, locZ9);

	//third row

	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm3, locZ0);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm3, locZ1);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm3, locZ2);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locXm3, locZ3);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm3, locZ4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm3, locZ5);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm3, locZ6);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm3, locZ7);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm3, locZ8);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locXm3, locZ9);

	//fourth row

	if (bigCity == 0)
		rmPlaceGroupingAtLoc(blockHouse05, 0, locXm4, locZ0);
	if (cNumberNonGaiaPlayers <=3)
		rmPlaceGroupingAtLoc(blockHouse06, 0, locXm4, locZ1);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm4, locZ2);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm4, locZ3);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locXm4, locZ4);
	//rmPlaceGroupingAtLoc(blockHouse04, 0, locXm4, locZ5);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locXm4, locZ6);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locXm4, locZ7);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locXm4, locZ8);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locXm4, locZ9);

	if (bigCity == 1){
		
		//fifth row

		rmPlaceGroupingAtLoc(blockHouse02, 0, locXm5, locZ0);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locXm5, locZ1);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locXm5, locZ2);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locXm5, locZ3);
		//rmPlaceGroupingAtLoc(blockHouse06, 0, locXm5, locZ4);
		//rmPlaceGroupingAtLoc(blockHouse01, 0, locXm5, locZ5);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locXm5, locZ6);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locXm5, locZ7);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locXm5, locZ8);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locXm5, locZ9);

	}

// Decorations

	// Place riverside groupings with swans on both sides of the river
	rmPlaceGroupingAtLoc(cityShoreline01, 0, 0.5+rmXTilesToFraction(15), 0.65);
	rmPlaceGroupingAtLoc(cityShoreline01, 0, 0.5+rmXTilesToFraction(15), 0.35);
	rmPlaceGroupingAtLoc(cityShoreline01, 0, 0.5+rmXTilesToFraction(15), 0.92);
	rmPlaceGroupingAtLoc(cityShoreline01, 0, 0.5+rmXTilesToFraction(15), 0.08);

	rmPlaceGroupingAtLoc(cityShoreline02, 0, 0.5-rmXTilesToFraction(16), 0.65);
	rmPlaceGroupingAtLoc(cityShoreline02, 0, 0.5-rmXTilesToFraction(16), 0.35);
	rmPlaceGroupingAtLoc(cityShoreline02, 0, 0.5-rmXTilesToFraction(16), 0.92);
	rmPlaceGroupingAtLoc(cityShoreline02, 0, 0.5-rmXTilesToFraction(16), 0.08);


//================we will add the other 4 rows after the groupings are defined and the randomizer is working=========

rmSetStatusText("",0.70);


// Add city hills

	for (j=0; < 4) {   

		// City Hill Bottom
		int smallPatch = rmCreateArea("smallPatch"+j);
		rmSetAreaSize(smallPatch, rmAreaTilesToFraction(100), rmAreaTilesToFraction(100));
		//rmSetAreaTerrainType(smallPatch, "city\ground1_cob_dark");
		rmAddAreaToClass(smallPatch, rmClassID("classPlateau"));
		rmSetAreaHeightBlend(smallPatch, 3);
		rmSetAreaCoherence(smallPatch, 1.0);
		if (j == 0){
		rmSetAreaLocation(smallPatch, 0.5-rmXTilesToFraction(citySize+85), 0.8);
		}
		if (j == 1){
		rmSetAreaLocation(smallPatch, 0.5-rmXTilesToFraction(citySize+85), 0.2);
		}
		if (j == 2){
		rmSetAreaLocation(smallPatch, 0.5+rmXTilesToFraction(citySize+85), 0.2);
		}
		if (j == 3){
		rmSetAreaLocation(smallPatch, 0.5+rmXTilesToFraction(citySize+85), 0.8);
		}
		rmBuildArea(smallPatch);  

		// City Hill Ramp
		int smallPatchRamp = rmCreateArea("smallPatchRamp"+j);
		rmSetAreaSize(smallPatchRamp, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
		rmSetAreaHeightBlend(smallPatchRamp, 3);
		rmSetAreaCoherence(smallPatchRamp, 1.0);
		rmSetAreaHeightBlend(smallPatchRamp, 2);
		rmSetAreaSmoothDistance(smallPatchRamp, 7);
		rmSetAreaBaseHeight(smallPatchRamp, 7.0);
		if (j == 0){
		rmSetAreaLocation(smallPatchRamp, 0.5-rmXTilesToFraction(citySize+90), 0.8);
		}
		if (j == 1){
		rmSetAreaLocation(smallPatchRamp, 0.5-rmXTilesToFraction(citySize+90), 0.2);
		}
		if (j == 2){
		rmSetAreaLocation(smallPatchRamp, 0.5+rmXTilesToFraction(citySize+90), 0.2);
		}
		if (j == 3){
		rmSetAreaLocation(smallPatchRamp, 0.5+rmXTilesToFraction(citySize+90), 0.8);
		}
		rmBuildArea(smallPatchRamp);  

		// WallBlockerCliff
		int wallBlocker = rmCreateArea("wallBlocker"+j);
		rmSetAreaSize(wallBlocker, rmAreaTilesToFraction(100), rmAreaTilesToFraction(100));
		rmSetAreaObeyWorldCircleConstraint(wallBlocker, false);
		rmAddAreaConstraint(wallBlocker, avoidPlateauShort);
		rmAddAreaConstraint(wallBlocker, avoidTradeRouteFar);
		rmAddAreaConstraint(wallBlocker, avoidWall);
		rmSetAreaCliffType(wallBlocker, "Northwest Territory");
		rmSetAreaCliffEdge(wallBlocker, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(wallBlocker, false, true, true, 1.5, true);
		rmSetAreaCliffHeight(wallBlocker, 0, 0, 0.5);
		rmSetAreaBaseHeight(wallBlocker, 6.0);
		rmSetAreaHeightBlend(wallBlocker, 3);
		rmSetAreaCoherence(wallBlocker, 1.0);
		if (j == 0){
		rmSetAreaLocation(wallBlocker, 0.5-rmXTilesToFraction(citySize+92), 0.62);
		}
		if (j == 1){
		rmSetAreaLocation(wallBlocker, 0.5-rmXTilesToFraction(citySize+92), 0.4);
		}
		if (j == 2){
		rmSetAreaLocation(wallBlocker, 0.5+rmXTilesToFraction(citySize+92), 0.4);
		}
		if (j == 3){
		rmSetAreaLocation(wallBlocker, 0.5+rmXTilesToFraction(citySize+92), 0.62);
		}
		rmBuildArea(wallBlocker);  

		// City Hill Cliff
		int wallCliffs = rmCreateArea("wallCliffs"+j);
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(1200), rmAreaTilesToFraction(1200));
		rmSetAreaObeyWorldCircleConstraint(wallCliffs, false);
		rmAddAreaToClass(wallCliffs, rmClassID("classPlateau"));
		rmAddAreaConstraint(wallCliffs, avoidBlock);
		rmAddAreaConstraint(wallCliffs, avoidPlateauShort);
		rmAddAreaConstraint(wallCliffs, avoidTradeRouteFar);
		rmAddAreaConstraint(wallCliffs, avoidWall);
		rmSetAreaCliffType(wallCliffs, "Northwest Territory");
		rmAddAreaToClass(wallCliffs , classMountains);
		rmSetAreaCliffEdge(wallCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(wallCliffs, false, true, true, 1.5, true);
		rmSetAreaCliffHeight(wallCliffs, 0, 0, 0.5);
		rmSetAreaBaseHeight(wallCliffs, 6.0);
		rmSetAreaHeightBlend(wallCliffs, 3);
		rmSetAreaCoherence(wallCliffs, .93);
		if (j == 0){
		rmSetAreaLocation(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.8);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.66, 0.5-rmXTilesToFraction(citySize+92), 1.0);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.7, 0.5-rmXTilesToFraction(citySize+105), 0.75);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+105), 0.75, 0.5-rmXTilesToFraction(citySize+105), 0.85);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+105), 0.85, 0.5-rmXTilesToFraction(citySize+92), 0.9);
		}
		if (j == 1){
		rmSetAreaLocation(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.2);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.37, 0.5-rmXTilesToFraction(citySize+92), 0.0);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+92), 0.3, 0.5-rmXTilesToFraction(citySize+105), 0.25);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+105), 0.25, 0.5-rmXTilesToFraction(citySize+105), 0.15);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5-rmXTilesToFraction(citySize+105), 0.15, 0.5-rmXTilesToFraction(citySize+92), 0.1);
		}
		if (j == 2){
		rmSetAreaLocation(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.2);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.37, 0.5+rmXTilesToFraction(citySize+92), 0.0);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.3, 0.5+rmXTilesToFraction(citySize+105), 0.25);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+105), 0.25, 0.5+rmXTilesToFraction(citySize+105), 0.15);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+105), 0.15, 0.5+rmXTilesToFraction(citySize+92), 0.1);
		}
		if (j == 3){
		rmSetAreaLocation(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.8);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.66, 0.5+rmXTilesToFraction(citySize+92), 1.0);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+92), 0.7, 0.5+rmXTilesToFraction(citySize+105), 0.75);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+105), 0.75, 0.5+rmXTilesToFraction(citySize+105), 0.85);
		rmAddAreaInfluenceSegment(wallCliffs, 0.5+rmXTilesToFraction(citySize+105), 0.85, 0.5+rmXTilesToFraction(citySize+92), 0.9);
		}
		rmBuildArea(wallCliffs);  

		// City Hill Top
		int largePatch = rmCreateArea("largePatch"+j);
		rmSetAreaSize(largePatch, rmAreaTilesToFraction(170), rmAreaTilesToFraction(170));
		rmSetAreaTerrainType(largePatch, "city\ground1_cob_dark");
		rmAddAreaToClass(largePatch, rmClassID("classPlateau"));
		rmSetAreaHeightBlend(largePatch, 3);
		rmSetAreaCoherence(largePatch, 1.0);
		if (j == 0){
		rmSetAreaLocation(largePatch, 0.5-rmXTilesToFraction(citySize+97), 0.8);
		}
		if (j == 1){
		rmSetAreaLocation(largePatch, 0.5-rmXTilesToFraction(citySize+97), 0.2);
		}
		if (j == 2){
		rmSetAreaLocation(largePatch, 0.5+rmXTilesToFraction(citySize+97), 0.2);
		}
		if (j == 3){
		rmSetAreaLocation(largePatch, 0.5+rmXTilesToFraction(citySize+97), 0.8);
		}
		rmBuildArea(largePatch);  

		// City Road
		int patchRoad = rmCreateArea("patchRoad"+j);
		rmSetAreaSize(patchRoad, rmAreaTilesToFraction(50), rmAreaTilesToFraction(50));
		rmSetAreaTerrainType(patchRoad, "city\ground1_cob_dark");
		rmAddAreaToClass(patchRoad, rmClassID("classPlateau"));
		rmSetAreaHeightBlend(patchRoad, 3);
		rmSetAreaCoherence(patchRoad, 1.0);
		rmAddAreaToClass(patchRoad, classStreet);
		if (j == 0){
		rmSetAreaLocation(patchRoad, 0.5-rmXTilesToFraction(citySize+95), 0.8);
		rmAddAreaInfluenceSegment(patchRoad, 0.5-rmXTilesToFraction(citySize+85), 0.8, 0.5-rmXTilesToFraction(citySize+100), 0.8);
		}
		if (j == 1){
		rmSetAreaLocation(patchRoad, 0.5-rmXTilesToFraction(citySize+95), 0.2);
		rmAddAreaInfluenceSegment(patchRoad, 0.5-rmXTilesToFraction(citySize+85), 0.2, 0.5-rmXTilesToFraction(citySize+100), 0.2);
		}
		if (j == 2){
		rmSetAreaLocation(patchRoad, 0.5+rmXTilesToFraction(citySize+95), 0.2);
		rmAddAreaInfluenceSegment(patchRoad, 0.5+rmXTilesToFraction(citySize+85), 0.2, 0.5+rmXTilesToFraction(citySize+100), 0.2);
		}
		if (j == 3){
		rmSetAreaLocation(patchRoad, 0.5+rmXTilesToFraction(citySize+95), 0.8);
		rmAddAreaInfluenceSegment(patchRoad, 0.5+rmXTilesToFraction(citySize+85), 0.8, 0.5+rmXTilesToFraction(citySize+100), 0.8);
		}
		rmBuildArea(patchRoad);  
		
	}

// Place additional objects

	// Groupings
	int jesuitVillageType = rmRandInt(1, 3);
	int jesuitMonasteryID = rmCreateGrouping("countryMonastery1", "Jesuit_Cathedral_EU_0"+jesuitVillageType);
    rmSetGroupingMinDistance(jesuitMonasteryID, 0.00);
    rmSetGroupingMaxDistance(jesuitMonasteryID, 0.50);
	rmAddGroupingToClass(jesuitMonasteryID, rmClassID("classBlock"));

	int malteseVillageType = rmRandInt(1, 5);
	int malteseMonasteryID = rmCreateGrouping("countryMonastery2", "maltese_village0"+malteseVillageType);
    rmSetGroupingMinDistance(malteseMonasteryID, 0.00);
    rmSetGroupingMaxDistance(malteseMonasteryID, 0.50);
	rmAddGroupingToClass(malteseMonasteryID, rmClassID("classBlock"));

	int blockMillVillage = rmCreateGrouping("Mill3", "EU_Resource_Block_Food3");
    rmSetGroupingMinDistance(blockMillVillage, 0.00);
    rmSetGroupingMaxDistance(blockMillVillage, 0.50);
	rmAddGroupingToClass(blockMillVillage, rmClassID("classBlock"));
	
	int countryVar = rmRandInt(1, 2);

	if (countryVar ==1){
		if (jesuitMaltese ==1){
			rmPlaceGroupingAtLoc(malteseMonasteryID, 0, 0.5-rmXTilesToFraction(citySize+99), 0.8, 1);
			rmPlaceGroupingAtLoc(jesuitMonasteryID, 0, 0.5+rmXTilesToFraction(citySize+99), 0.2, 1);
		}
		else{
			rmPlaceGroupingAtLoc(jesuitMonasteryID, 0, 0.5-rmXTilesToFraction(citySize+99), 0.8, 1);
			rmPlaceGroupingAtLoc(malteseMonasteryID, 0, 0.5+rmXTilesToFraction(citySize+99), 0.2, 1);
		}
		rmPlaceGroupingAtLoc(blockMillVillage, 0, 0.5+rmXTilesToFraction(citySize+100), 0.8, 1);
		rmPlaceGroupingAtLoc(blockMillVillage, 0, 0.5-rmXTilesToFraction(citySize+100), 0.2, 1);
	}
	else{
		if (jesuitMaltese ==1){
			rmPlaceGroupingAtLoc(malteseMonasteryID, 0, 0.5-rmXTilesToFraction(citySize+99), 0.2, 1);
			rmPlaceGroupingAtLoc(jesuitMonasteryID, 0, 0.5+rmXTilesToFraction(citySize+99), 0.8, 1);
		}
		else{
			rmPlaceGroupingAtLoc(jesuitMonasteryID, 0, 0.5-rmXTilesToFraction(citySize+99), 0.2, 1);
			rmPlaceGroupingAtLoc(malteseMonasteryID, 0, 0.5+rmXTilesToFraction(citySize+99), 0.8, 1);
		}
		rmPlaceGroupingAtLoc(blockMillVillage, 0, 0.5+rmXTilesToFraction(citySize+100), 0.2, 1);
		rmPlaceGroupingAtLoc(blockMillVillage, 0, 0.5-rmXTilesToFraction(citySize+100), 0.8, 1);
	}

	// Forester
	int foresterID = rmCreateObjectDef("random forester");
	rmAddObjectDefItem(foresterID, "zpSPCForester", 1, 0);
	rmAddObjectDefConstraint(foresterID, avoidBlockMedium);
	rmAddObjectDefConstraint(foresterID, playerEdgeConstraint);
	if (countryVar ==1){
		rmPlaceObjectDefInArea(foresterID, 0, rmAreaID("wallCliffs1"), 1);
		rmPlaceObjectDefInArea(foresterID, 0, rmAreaID("wallCliffs3"), 1);
	}
	else{
		rmPlaceObjectDefInArea(foresterID, 0, rmAreaID("wallCliffs0"), 1);
		rmPlaceObjectDefInArea(foresterID, 0, rmAreaID("wallCliffs2"), 1);
	}

	// Random Houses
	int randomHouseID = rmCreateObjectDef("random house");
	rmAddObjectDefItem(randomHouseID, "zpSPCVillageHouseProp", 1, 0);
	rmAddObjectDefConstraint(randomHouseID, avoidBlockLong);
	rmAddObjectDefConstraint(randomHouseID, playerEdgeConstraint);
	for (j=0; < 4) {   
      	rmPlaceObjectDefInArea(randomHouseID, 0, rmAreaID("wallCliffs"+j), 6);
	}

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidSilver);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidBlockLong);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	if (cNumberNonGaiaPlayers>=4){ 
		for (j=0; < 4) {   
			rmPlaceObjectDefInArea(randomGoldID, 0, rmAreaID("wallCliffs"+j), 2);
		}
	}
	

	// Random Trees
	int cliffTreeID = rmCreateObjectDef("cliffTree");
	rmAddObjectDefItem(cliffTreeID, "TreePonderosaPine", rmRandInt(6,7), rmRandFloat(11.0,12.0));
	rmAddObjectDefItem(cliffTreeID, "TreeGreatPlains", rmRandInt(3,4), 10.0);
	rmAddObjectDefItem(cliffTreeID, "underbrushTexasGrass", rmRandInt(6,7), 12.0);
	rmAddObjectDefItem(cliffTreeID, "deer", 2, 6.0);
	rmAddObjectDefToClass(cliffTreeID, rmClassID("classForest")); 
	rmAddObjectDefConstraint(cliffTreeID, avoidBlockMedium);
	rmAddObjectDefConstraint(cliffTreeID, avoidStreet);
	for (j=0; < 4) {   

      rmPlaceObjectDefInArea(cliffTreeID, 0, rmAreaID("wallCliffs"+j), 4);

	}

	// Random Flowers
	int flowersID = rmCreateObjectDef("cliffFlower");
	rmAddObjectDefItem(flowersID, "deUnderbrushFlowersJapan", rmRandInt(2,3), rmRandFloat(4.0,5.0));
	rmAddObjectDefConstraint(flowersID, avoidBlockMedium);
	rmAddObjectDefConstraint(flowersID, avoidStreet);
	for (j=0; < 4) {   
      rmPlaceObjectDefInArea(flowersID, 0, rmAreaID("wallCliffs"+j), 4);

	}

	rmSetStatusText("",0.80);


//==============================================================
//dansil player placement
//==============================================================

// =============Player placement ======================= 
	//spawnSwitch = 0.1;


	if (cNumberTeams == 2){
		if (spawnSwitch ==0){

			if (PlayerNum == 2)
			{
				rmPlacePlayer(1, 0.07, 0.65);
				rmPlacePlayer(2, 0.93, 0.35);
			}

			if (PlayerNum == 3 || PlayerNum == 4)
			{			
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.1, 0.75, 0.1, 0.25, 0, 0);
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.9, 0.25, 0.9, 0.75, 0, 0);

			}

			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.10, 0.9, 0.10, 0.1, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.90, 0.1, 0.90, 0.9, 0, 0);


		}
		
		else{

			if (PlayerNum == 2)
			{
				rmPlacePlayer(2, 0.07, 0.65);
				rmPlacePlayer(1, 0.93, 0.35);
			}



			if (PlayerNum == 3 || PlayerNum == 4)
			{			
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.1, 0.75, 0.1, 0.25, 0, 0);
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.9, 0.25, 0.9, 0.75, 0, 0);
			}


			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.10, 0.9, 0.10, 0.1, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.90, 0.1, 0.90, 0.9, 0, 0);

		}
	}


//town centre start

//starting res

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);

	int foodID = rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(foodID, "deer", 9, 6.0);
	rmSetObjectDefMinDistance(foodID, 12.0);
	rmSetObjectDefMaxDistance(foodID, 14.0);
	rmSetObjectDefCreateHerd(foodID, true);

	int goldID = rmCreateObjectDef("starting gold");
	rmAddObjectDefItem(goldID, "MineTin", 1, 2.0);
	rmSetObjectDefMinDistance(goldID, 14.0);
	rmSetObjectDefMaxDistance(goldID, 15.0);
	rmAddObjectDefConstraint(goldID, avoidTradeRouteMin);

	/*int goldID2 = rmCreateObjectDef("starting gold 2");
	rmAddObjectDefItem(goldID2, "MineTin", 1, 2.0);
	rmSetObjectDefMinDistance(goldID2, 20.0);
	rmSetObjectDefMaxDistance(goldID2, 50.0);
	rmAddObjectDefConstraint(goldID2, avoidTradeRouteMin);
	rmAddObjectDefConstraint(goldID2, avoidCoin);*/

	int berryID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID, 16.0);
	rmSetObjectDefMaxDistance(berryID, 17.0);
	rmAddObjectDefConstraint(berryID, shortAvoidCoin);

	int aiStartUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiStartUrban, "zpAIStartUrbanMap", 1, 0.0);

//place tcs

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "deSPCCommandPost", 1, 2.0);
		rmSetObjectDefMinDistance(startID, 0.0);
        rmSetObjectDefMaxDistance(startID, 1.0);
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);
		/*if (cNumberNonGaiaPlayers >=4)
			rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));*/

	}

    int avoidPlateauLarge = rmCreateClassDistanceConstraint("avoid city", rmClassID("classPlateau"), 15.0);
	int avoidWalls =rmCreateClassDistanceConstraint("stuff vs. the walls", rmClassID("classBlock"), 25);


	int countrysideTrees=rmCreateObjectDef("countryside Trees");
	rmAddObjectDefItem(countrysideTrees, "TreePonderosaPine", rmRandInt(6,7), rmRandFloat(11.0,12.0));
	rmAddObjectDefItem(countrysideTrees, "TreeGreatPlains", rmRandInt(3,4), 10.0);
	rmAddObjectDefItem(countrysideTrees, "underbrushTexasGrass", rmRandInt(6,7), 12.0);
	rmAddObjectDefItem(countrysideTrees, "deer", 1, 6.0);
	rmAddObjectDefToClass(countrysideTrees, rmClassID("classForest")); 
	rmSetObjectDefMinDistance(countrysideTrees, 0);
	rmSetObjectDefMaxDistance(countrysideTrees, rmXFractionToMeters(0.99));
	rmAddObjectDefConstraint(countrysideTrees, avoidTradeRouteMin);
	rmAddObjectDefConstraint(countrysideTrees, shortAvoidCoin);
	rmAddObjectDefConstraint(countrysideTrees, forestConstraint);
	rmAddObjectDefConstraint(countrysideTrees, avoidPlateauLarge);
	rmAddObjectDefConstraint(countrysideTrees, avoidWallLong);
	rmAddObjectDefConstraint(countrysideTrees, avoidTownCenter);	
	rmPlaceObjectDefAtLoc(countrysideTrees, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);   

	// Nuggets

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetNorth, avoidMountains);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorth, 0, countrysideNorth, cNumberNonGaiaPlayers);

	int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetSouth, avoidMountains);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, countrysideSouth, cNumberNonGaiaPlayers);

	int nuggetHard= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggetHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmAddObjectDefConstraint(nuggetHard, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHard, avoidAll);
	rmAddObjectDefConstraint(nuggetHard, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetHard, 0, rmAreaID("wallCliffs1"), 1);
	rmPlaceObjectDefInArea(nuggetHard, 0, rmAreaID("wallCliffs2"), 1);
	rmPlaceObjectDefInArea(nuggetHard, 0, rmAreaID("wallCliffs3"), 1);
	rmPlaceObjectDefInArea(nuggetHard, 0, rmAreaID("wallCliffs0"), 1);




//add fish because why not
	rmSetStatusText("",0.90);

	int fishIsland = rmCreateClassDistanceConstraint("avoid island bridges", rmClassID("classPlateau"), 2.0);
	int noTouchingFish = rmCreateTypeDistanceConstraint("fish vs other fish", "fishCod", 12.0);


	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, "fishCod", 1, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, noTouchingFish);
	rmAddObjectDefConstraint(fishID, fishIsland);
	rmAddObjectDefConstraint(fishID, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

	//********************* GENERAL SETUP *************************

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

	// _________________ Map Objectives ______________________________
	rmObjectiveScreenSetTitle(302018);
	rmObjectiveScreenSetGoal(302021);
	rmObjectiveAdd(302022, 302023, true, true, true); // General objective
	rmObjectiveAdd(302024, 302023, true, true, true); // Royal Court REV
	rmObjectiveSetTeam(2, 1);
	rmObjectiveAdd(302024, 302023, true, true, true); // Royal Court ROY
	rmObjectiveSetTeam(3, 2);
	rmObjectiveAdd(302025, 302023, true, true, true); // City Hall REV
	rmObjectiveSetTeam(4, 1);
	rmObjectiveAdd(302025, 302023, true, true, true); // City Hall ROY
	rmObjectiveSetTeam(5, 2);
	rmObjectiveAdd(302026, 302023, true, true, true); // Bastille REV
	rmObjectiveSetTeam(6, 1);
	rmObjectiveAdd(302026, 302023, true, true, true); // Bastille ROY
	rmObjectiveSetTeam(7, 2);

	// ************************* TRIGGERS ******************************

	//----- DEFINE VARIABLES -----

	// Targeting Unit IDs
	int cityStateFlag1 = rmGetGroupingInstanceUnitByType(cityState1, "zpSPCCapturableFlagInvisible");
	int cityStateFlag2 = rmGetGroupingInstanceUnitByType(cityState2, "zpSPCCapturableFlagInvisible");

	int gateSocket1 = rmGetGroupingInstanceUnitByType(cityWall1, "zpSPCPortSocket");
	int gateSocket2 = rmGetGroupingInstanceUnitByType(cityWall2, "zpSPCPortSocket");
	int gateStopper1 = rmGetGroupingInstanceUnitByType(cityWall1, "zpTrainStopper");
	int gateStopper2 = rmGetGroupingInstanceUnitByType(cityWall2, "zpTrainStopper");

	int victoryFlag1 = rmGetGroupingInstanceUnitByType(victoryGrouping1, "zpSPCCapturableFlagNoIcon");
	int victoryFlag2 = rmGetGroupingInstanceUnitByType(victoryGrouping2, "zpSPCCapturableFlagNoIcon");
	int victoryFlag3 = rmGetGroupingInstanceUnitByType(victoryGrouping3, "zpSPCCapturableFlagNoIcon");

	int flag1ID =cityStateFlag1+1;
	int flag2ID =cityStateFlag2+1;
	int flag3ID =victoryFlag1+1;
	int flag4ID =victoryFlag2+1;
	int flag5ID =victoryFlag3+1;
	
	int socket1ID =gateSocket1+0;
	int socket2ID =gateSocket2+0;
	int stopper1ID =gateStopper1+0;
	int stopper2ID =gateStopper2+0;

	// Victory Timer
	int victoryCountDown = 480;

	//----- START -----

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpForbidRevolutions"); // No normal revolutions on this map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpDisableWalls"); // No normal revolutions on this map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpParisSetup"); // No normal revolutions on this map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpBonusBourbon"); // No normal revolutions on this map
		rmSetTriggerEffectParamInt("Status",2);
		if (rmGetPlayerTeam(i) == 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpNatBourbonBigbuttonDisableShadow"); // Disable Bourbon techs for Revolutionaries
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpNatBigbuttonDisableShadow"); // Disable Bourbon techs for Revolutionaries
			rmSetTriggerEffectParamInt("Status",2);
		}
		else {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpNatSansculotteBigbuttonDisableShadow"); // Disable Sansculotte Big button for Royalists
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpNatSansculoteoffShadow"); // Disable Bourbon techs for Revolutionaries
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	for(i=0; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpTollstation"); // Toll Station icon
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // European Embassy
	rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Civilization","SPCBourbon");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("StringID","301968");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Set up default resource values
	if (cNumberNonGaiaPlayers >2){
		rmCreateTrigger("Starting Resources");
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","MineGold");
		rmSetTriggerEffectParam("Resource","Gold");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","deMineCoalBuildable");
		rmSetTriggerEffectParam("Resource","Gold");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","zpValuableSource");
		rmSetTriggerEffectParam("Resource","Gold");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","zpGrapeBush");
		rmSetTriggerEffectParam("Resource","Food");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","zpTreeRubble");
		rmSetTriggerEffectParam("Resource","Wood");
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmSetTriggerEffectParamInt("Field",2);
		rmSetTriggerEffectParamInt("Delta",0.5*cNumberNonGaiaPlayers);
		rmSetTriggerEffectParamInt("Relativity",3);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	//----- VICTORY CONDITIONS -----

	// Convert Flags
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("ConvertCourt_Plr"+k);
	rmCreateTrigger("ConvertBastille_Plr"+k);
	rmCreateTrigger("ConvertCityHall_Plr"+k);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("ConvertBastille_Plr"+k));
	rmAddTriggerCondition("Units Owned");
	rmSetTriggerConditionParam("SrcObject",""+flag3ID);
	rmSetTriggerConditionParamInt("Player",k);
	for (i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag3ID);
		rmSetTriggerEffectParamInt("SrcPlayer",i);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpBastille");
		rmSetTriggerEffectParamInt("Dist",35);
	}
	for (i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ConvertBastille_Plr"+i));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("ConvertCourt_Plr"+k));
	rmAddTriggerCondition("Units Owned");
	rmSetTriggerConditionParam("SrcObject",""+flag4ID);
	rmSetTriggerConditionParamInt("Player",k);
	for (i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag4ID);
		rmSetTriggerEffectParamInt("SrcPlayer",i);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpRoyalCourt");
		rmSetTriggerEffectParamInt("Dist",35);
	}
	for (i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ConvertCourt_Plr"+i));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("ConvertCityHall_Plr"+k));
	rmAddTriggerCondition("Units Owned");
	rmSetTriggerConditionParam("SrcObject",""+flag5ID);
	rmSetTriggerConditionParamInt("Player",k);
	for (i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag5ID);
		rmSetTriggerEffectParamInt("SrcPlayer",i);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityHall");
		rmSetTriggerEffectParamInt("Dist",35);
	}
	for (i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ConvertCityHall_Plr"+i));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Team Victory and handling Objectives

	for(i = 1; < cNumberTeams+1)
    {
        rmCreateTrigger("TeamVictory"+i);
		rmCreateTrigger("RoyalCourt_ON"+i);
		rmCreateTrigger("CityHall_ON"+i);
		rmCreateTrigger("Bastille_ON"+i);
		rmCreateTrigger("Victory_Counter"+i);
		rmCreateTrigger("Victory_Counter_OFF"+i);
	}

	for(i = 1; < cNumberTeams+1)
    {
	   // Team Victory 
		rmSwitchToTrigger(rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Team Victory");
        rmSetTriggerEffectParamInt("TeamID", i);
        rmSetTriggerPriority(4); 
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);
        
		// Royal Court ownership
		rmSwitchToTrigger(rmTriggerID("RoyalCourt_ON"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpRoyalCourt");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Objective : Complete");

		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 2);
		else
			rmSetTriggerEffectParamInt("Objective", 3);

		rmAddTriggerEffect("Objective : Incomplete");
		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 3);
		else
			rmSetTriggerEffectParamInt("Objective", 2);

		rmAddTriggerEffect("Fire Event");
		if (i==1)
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("RoyalCourt_ON2"));
		else
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("RoyalCourt_ON1"));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Bastille ownership
		rmSwitchToTrigger(rmTriggerID("Bastille_ON"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpBastille");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Objective : Complete");

		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 6);
		else
			rmSetTriggerEffectParamInt("Objective", 7);

		rmAddTriggerEffect("Objective : Incomplete");
		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 7);
		else
			rmSetTriggerEffectParamInt("Objective", 6);

		rmAddTriggerEffect("Fire Event");
		if (i==1)
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Bastille_ON2"));
		else
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Bastille_ON1"));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// City Hall
		rmSwitchToTrigger(rmTriggerID("CityHall_ON"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpCityHall");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Objective : Complete");

		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 4);
		else
			rmSetTriggerEffectParamInt("Objective", 5);

		rmAddTriggerEffect("Objective : Incomplete");
		if (i==1)
			rmSetTriggerEffectParamInt("Objective", 5);
		else
			rmSetTriggerEffectParamInt("Objective", 4);

		rmAddTriggerEffect("Fire Event");
		if (i==1)
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CityHall_ON2"));
		else
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CityHall_ON1"));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Victory Counter
		rmSwitchToTrigger(rmTriggerID("Victory_Counter"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpSPCCapturableFlagNoIcon");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop",0);

		if (i==1)
			rmSetTriggerEffectParam("Msg","Team ATTACKERS (Revolutionaries) wins in"); // Counter Revolutionaries
		else
			rmSetTriggerEffectParam("Msg","Team DEFENDERS (Royalists) wins in"); // Counter Revolutionaries
		rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter_OFF"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter_OFF"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpSPCCapturableFlagNoIcon");
		rmSetTriggerConditionParam("Op","<");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	}

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
	rmCreateTrigger("Activate Sansculottes"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpSansculotteRevolution"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffSansculottes"); //operator
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

	rmCreateTrigger("Revolution_MusicEnd"+k);

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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Sansculottes"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// ----- REVOLUTIONS -----

	// Flag Change
	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Flag Lafayette"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateRevLafayette");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","zpRevParis");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","301916");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Flag Jacobine"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateRevJacobine");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","DERevFrance");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","301925");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Flag Napoleon"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateRevNapoleon");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","DERevFranceNE");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","301926");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Revolution_MusicEnd"+k));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",5);
	rmAddTriggerEffect("Music Play");
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	}

	// ---- CITY GROUPINGS -----

	// Convert City Bastions
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Convert Bastions"+k);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("Protounit","zpParisCitadelGaia");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpConvertBastions"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}

	// Convert Military Blocks
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Military_Block1_Plr"+k);
		rmCreateTrigger("Military_Block2_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Military_Block1_Plr"+k));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject",""+flag1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+flag1ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+flag1ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","Outpost");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortStableProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortBarracksProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		for (i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Military_Block1_Plr"+i));
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Military_Block2_Plr"+k));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject",""+flag2ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+flag2ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+flag2ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","Outpost");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortStableProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortBarracksProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+flag2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		for (i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Military_Block2_Plr"+i));
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Convert Gates
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Gate1_ON_Plr"+k);
		rmCreateTrigger("Gate1_OFF_Plr"+k);
		rmCreateTrigger("Gate2_ON_Plr"+k);
		rmCreateTrigger("Gate2_OFF_Plr"+k);
		rmCreateTrigger("Gate1_Rebuild_Plr"+k);
		rmCreateTrigger("Gate2_Rebuild_Plr"+k);
		rmCreateTrigger("Gate1_Convert_Plr"+k);
		rmCreateTrigger("Gate2_Convert_Plr"+k);

	// Gate 1
		rmSwitchToTrigger(rmTriggerID("Gate1_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socket1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuild_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Convert_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate1_OFF_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socket1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallMedium");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallLarge");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallSmall");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCEuroTower");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortCorner");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuild_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Convert_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate1_Rebuild_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+stopper1ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate1_Convert_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+stopper1ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper1ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuild_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	// Gate 2

		rmSwitchToTrigger(rmTriggerID("Gate2_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socket2ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuild_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Convert_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate2_OFF_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+socket2ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallMedium");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallLarge");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortWallSmall");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCEuroTower");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortCorner");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuild_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Convert_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate2_Rebuild_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+stopper2ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate2_Convert_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+stopper2ID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+stopper2ID);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuild_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	// Common for both

		rmCreateTrigger("Walls_Transform_ON"+k);
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCFortCornerProp");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConvertWall"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
		
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Gates_Rebuilt"+k);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("Protounit","zpInvisibleGateSocket");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpConverGate"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}

	rmCreateTrigger("Walls_Transform_OFF");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","SPCFortCorner");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpConvertWallBack"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

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

	// AI Revolutionary Fractions

	for (k=1; <= cNumberNonGaiaPlayers) {
	if (rmGetPlayerTeam(k) == 0) {
		rmCreateTrigger("ZP_Iniciate_Revolution"+k);
		rmCreateTrigger("ZP_Execute_Revolution"+k);
		rmCreateTrigger("ZP_Timer_Revolution"+k);

		rmSwitchToTrigger(rmTriggerID("ZP_Iniciate_Revolution"+k));
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechIndustrialize");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Timer_Revolution"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Timer_Revolution"+k));
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1",10);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeSansculottes");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Execute_Revolution"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeSansculottes");
		rmSetTriggerConditionParamInt("Status",2);

		int revFraction=-1;
		revFraction = rmRandInt(1,3);

		if (revFraction==1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateRevLafayette"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateRevJacobine"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateRevNapoleon"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
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
	rmSetStatusText("",0.99);


    
	




	
    
	
} // END