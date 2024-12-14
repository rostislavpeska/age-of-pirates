// Verseilles
// November 2024

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
		subCiv0=rmGetCivID("jewish");
		rmEchoInfo("subCiv0 is jewish "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "jewish");

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

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
	int firstDefender = -1;
	int firstAttacker = -1;

	for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == 1)
        {
            firstDefender = i;
            break;
        }
    }
	for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == 0)
        {
            firstAttacker = i;
            break;
        }
    }

    int sizeZ = 560;
	int sizeX = 360;
	if (teamZeroCount >=3)
		sizeZ = 600;
	if (teamZeroCount >4)
		sizeZ = 650;
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
	rmSetSeaLevel(1.0);
   
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
    rmSetMapType("euroTradeRouteCapture");

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
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	


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
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 18.0);
	int forestConstraintShort=rmCreateClassDistanceConstraint("forest vs. forest short", rmClassID("classForest"), 5.0);
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
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
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
	int avoidStreet = rmCreateClassDistanceConstraint("avoid street", classStreet, 10.0);
	int avoidStreetShort = rmCreateClassDistanceConstraint("avoid street short", classStreet, 1.0);
	int avoidStreetZero = rmCreateClassDistanceConstraint("avoid street zero", classStreet, 0.01);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall object", "AbstractWall", 0.001);
	int avoidWallMedium=rmCreateTypeDistanceConstraint("avoid wall object medium", "AbstractWall", 2.0);
	int avoidWallLong=rmCreateTypeDistanceConstraint("avoid wall object long", "AbstractWall", 10.0);
	int avoidFence=rmCreateTypeDistanceConstraint("avoid palace fence", "SPCPathBlock3", 1.00);

	int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), 1.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);

	int cliffHeightConstraint = rmCreateMaxHeightConstraint("not too high", 7);
	int cemetaryConstraint=rmCreateClassDistanceConstraint("stay away from cemetary", classCemetary, 40.0);
	int cemetaryConstraintShort=rmCreateClassDistanceConstraint("stay away from cemetary short", classCemetary, 5.0);

    int avoidPark = rmCreateTypeDistanceConstraint("avoid park tree", "deSPCTreeCypressProp", 30);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);


   	float playerFraction=rmAreaTilesToFraction(850);


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
   
    rmAddTradeRouteWaypoint(tradeRouteID, 0.0, .55);
    rmAddTradeRouteWaypoint(tradeRouteID, .5, .55);
    rmAddTradeRouteWaypoint(tradeRouteID, 1.00, .55);
    rmBuildTradeRoute(tradeRouteID, "dirt");

	vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

	vector stoperLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
	float mapCenter = rmZMetersToFraction(xsVectorGetZ(stoperLoc));

	// Cardinal Constraints

	int Northward=rmCreateBoxConstraint("northMapConstraint", 0.0, 1.0, 1.0, mapCenter, 0.01);
	int Southward=rmCreateBoxConstraint("southMapConstraint", 0.0, mapCenter, 1.0, 0.0, 0.01);
	int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.0, mapCenter+rmZTilesToFraction(7), 1.0, mapCenter-rmZTilesToFraction(72));
	int streetSouthConstraint = rmCreateBoxConstraint("stay in the street south", 0.0, mapCenter+rmZTilesToFraction(7), 1.0, mapCenter-rmZTilesToFraction(70));


	// Roads

	// Countryside terrain

    int countrysideNorth = rmCreateArea("countryside N");
    rmSetAreaSize(countrysideNorth , 0.6, 0.6);
    rmSetAreaLocation(countrysideNorth , 0.5, 0.85);		
    rmSetAreaCoherence(countrysideNorth , 1.0);
    rmSetAreaBaseHeight(countrysideNorth, 1.0);
    rmAddAreaConstraint(countrysideNorth , avoidPlateauShort);
	rmAddAreaConstraint(countrysideNorth , avoidWallMedium);
	rmAddAreaConstraint(countrysideNorth , avoidWater4);
    rmSetAreaMix(countrysideNorth, "nwt_grass1");
    rmSetAreaElevationType(countrysideNorth, cElevTurbulence);
    rmSetAreaElevationVariation(countrysideNorth, 0.0);
    rmSetAreaElevationPersistence(countrysideNorth, 0.2);
    rmSetAreaElevationNoiseBias(countrysideNorth, 1);
    rmBuildArea(countrysideNorth); 


	int menagerieRoad = rmCreateArea("menagerieRoad");
    rmSetAreaSize(menagerieRoad , 0.002, 0.002);
    rmSetAreaLocation(menagerieRoad , 0.515, mapCenter+rmZTilesToFraction(27));	
	rmSetAreaTerrainType(menagerieRoad, "Texas\Path_Blend");	
	rmAddAreaInfluenceSegment(menagerieRoad,0.515, mapCenter+rmZTilesToFraction(27), 0.515, mapCenter+rmZTilesToFraction(65));
    rmSetAreaCoherence(menagerieRoad , 1.0);
	rmAddAreaToClass(menagerieRoad , classStreet);
    rmBuildArea(menagerieRoad ); 

	/*int jesuitRoad1 = rmCreateArea("jesuitRoad1");
    rmSetAreaSize(jesuitRoad1 , 0.003, 0.003);
    rmSetAreaLocation(jesuitRoad1 , 0.51, mapCenter+rmZTilesToFraction(27));	
	rmSetAreaTerrainType(jesuitRoad1, "Texas\Path_Blend");	
	rmAddAreaInfluenceSegment(jesuitRoad1,0.51, mapCenter+rmZTilesToFraction(27), 0.82, 0.75);
    rmSetAreaCoherence(jesuitRoad1 , 1.0);
	rmAddAreaToClass(jesuitRoad1 , classStreet);
    rmBuildArea(jesuitRoad1 ); 

	int jesuitRoad2 = rmCreateArea("jesuitRoad2");
    rmSetAreaSize(jesuitRoad2 , 0.003, 0.003);
    rmSetAreaLocation(jesuitRoad2 , 0.51, mapCenter+rmZTilesToFraction(27));	
	rmSetAreaTerrainType(jesuitRoad2, "Texas\Path_Blend");	
	rmAddAreaInfluenceSegment(jesuitRoad2,0.51, mapCenter+rmZTilesToFraction(27), 0.18, 0.75);
    rmSetAreaCoherence(jesuitRoad2 , 1.0);
	rmAddAreaToClass(jesuitRoad2 , classStreet);
    rmBuildArea(jesuitRoad2 ); 

	int gateRoad1 = rmCreateArea("gateRoad1");
    rmSetAreaSize(gateRoad1 , 0.002, 0.002);
    rmSetAreaLocation(gateRoad1 , 0.82, 0.75);	
	rmSetAreaTerrainType(gateRoad1, "Texas\Path_Blend");	
	rmAddAreaInfluenceSegment(gateRoad1, 0.825, mapCenter+rmZTilesToFraction(10), 0.82, 0.75);
    rmSetAreaCoherence(gateRoad1 , 1.0);
	rmAddAreaToClass(gateRoad1 , classStreet);
    rmBuildArea(gateRoad1 ); 

	int gateRoad2 = rmCreateArea("gateRoad2");
    rmSetAreaSize(gateRoad2 , 0.002, 0.002);
    rmSetAreaLocation(gateRoad2 , 0.18, 0.75);	
	rmSetAreaTerrainType(gateRoad2, "Texas\Path_Blend");	
	rmAddAreaInfluenceSegment(gateRoad2, 0.175, mapCenter+rmZTilesToFraction(10), 0.18, 0.75);
    rmSetAreaCoherence(gateRoad2 , 1.0);
	rmAddAreaToClass(gateRoad2 , classStreet);
    rmBuildArea(gateRoad2 ); */

	// Lakes

	int basinsID=rmCreateArea("Verseilles Basins");
	rmSetAreaWaterType(basinsID, "ZP Verseilles Pond");
	rmSetAreaSize(basinsID, 0.008, 0.008);
	rmSetAreaCoherence(basinsID, 1.0);
	rmSetAreaLocation(basinsID, 0.5, mapCenter+rmZTilesToFraction(57));
	rmAddAreaInfluenceSegment(basinsID,0.435, mapCenter+rmZTilesToFraction(57), 0.605, mapCenter+rmZTilesToFraction(57));
	rmSetAreaSmoothDistance(basinsID, 10);
	rmSetAreaBaseHeight(basinsID, 1.0);
	rmBuildArea(basinsID);

	int basinsID2=rmCreateArea("Verseilles Basins2");
	rmSetAreaWaterType(basinsID2, "ZP Verseilles Pond");
	rmSetAreaSize(basinsID2, 0.007, 0.007);
	rmSetAreaCoherence(basinsID2, 1.0);
	rmSetAreaLocation(basinsID2, 0.35, mapCenter+rmZTilesToFraction(37));
	rmAddAreaInfluenceSegment(basinsID2,0.35, mapCenter+rmZTilesToFraction(14), 0.35, mapCenter+rmZTilesToFraction(41));
	rmSetAreaSmoothDistance(basinsID2, 10);
	rmSetAreaBaseHeight(basinsID2, 1.0);
	rmBuildArea(basinsID2);

	int basinsID3=rmCreateArea("Verseilles Basins3");
	rmSetAreaWaterType(basinsID3, "ZP Verseilles Pond");
	rmSetAreaSize(basinsID3, 0.007, 0.007);
	rmSetAreaCoherence(basinsID3, 1.0);
	rmSetAreaLocation(basinsID3, 0.696, mapCenter+rmZTilesToFraction(37));
	rmAddAreaInfluenceSegment(basinsID3,0.695, mapCenter+rmZTilesToFraction(14), 0.695, mapCenter+rmZTilesToFraction(41));
	rmSetAreaSmoothDistance(basinsID3, 10);
	rmSetAreaBaseHeight(basinsID3, 1.0);
	rmBuildArea(basinsID3);


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	//  ************************** City Terrain ******************************

	// Streets terrain
	int citySouth = rmCreateArea("city South");
    rmSetAreaSize(citySouth, 0.7, 0.7);
    rmSetAreaLocation(citySouth, 0.5, mapCenter-rmZTilesToFraction(30));		
    rmSetAreaCoherence(citySouth, 1.0);	
	rmSetAreaTerrainType(citySouth, "city\ground1_city_street_ground");
    //rmAddAreaInfluenceSegment(citySouth, 0.4, 0.85, 0.4, 0.15);
    rmAddAreaConstraint(citySouth , citySouthConstraint);
    rmSetAreaObeyWorldCircleConstraint(citySouth, false);
	rmAddAreaToClass(citySouth , classStreet);
	rmAddAreaToClass(citySouth , rmClassID("classPlateau"));
    rmBuildArea(citySouth); 

   
	// Streets terrain
	int streetsSouth = rmCreateArea("streets South");
    rmSetAreaSize(streetsSouth, 0.7, 0.7);
    rmSetAreaLocation(streetsSouth, 0.5, mapCenter-rmZTilesToFraction(30));		
    rmSetAreaCoherence(streetsSouth, 1.0);	
	rmSetAreaTerrainType(streetsSouth, "city\ground1_cob_dark");
    //rmAddAreaInfluenceSegment(streetsSouth, 0.4, 0.85, 0.4, 0.15);
    rmAddAreaConstraint(streetsSouth , streetSouthConstraint);
    rmSetAreaObeyWorldCircleConstraint(streetsSouth, false);
	rmAddAreaToClass(streetsSouth , classStreet);
	rmAddAreaToClass(streetsSouth , rmClassID("classPlateau"));
    rmBuildArea(streetsSouth); 



	// Text
	rmSetStatusText("",0.40);


    //===========dansil code start============

		rmDefineClass("classBlock");
		//Constraints


//===================set up grid locations===================

	float locZ1 = mapCenter-rmZTilesToFraction(10);
	float locZ2 = mapCenter-rmZTilesToFraction(27);
	float locZ3 = mapCenter-rmZTilesToFraction(44);
	float locZ4 = mapCenter-rmZTilesToFraction(60);
	float locZ5 = mapCenter-rmZTilesToFraction(79);
	float locZ6 = mapCenter-rmZTilesToFraction(95);
	float locZ7 = mapCenter-rmZTilesToFraction(112);
	float locZ8 = mapCenter-rmZTilesToFraction(129);
	float locZ9 = mapCenter-rmZTilesToFraction(146);
	


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

	float palaceX1 = 0.615;
	float palaceX2 = 0.4;




//===================define groupings========================

// Fixed Placement

	// Palace
	int blockPalaceBig01 = rmCreateGrouping("palace1", "Verseilles_Mega3");
    rmSetGroupingMinDistance(blockPalaceBig01, 0.00);
    rmSetGroupingMaxDistance(blockPalaceBig01, 0.50);
	rmAddGroupingToClass(blockPalaceBig01, rmClassID("classBlock"));

	// Cathedral
	int blockCathedral = rmCreateGrouping("cathedral", "EU_Resource_Block_Cathedral");
    rmSetGroupingMinDistance(blockCathedral, 0.00);
    rmSetGroupingMaxDistance(blockCathedral, 0.50);
	rmAddGroupingToClass(blockCathedral, rmClassID("classBlock"));

	// Trade
	int blockTrade = rmCreateGrouping("trade", "EU_SPC_Block_Trade");
    rmSetGroupingMinDistance(blockTrade, 0.00);
    rmSetGroupingMaxDistance(blockTrade, 0.50);
	rmAddGroupingToClass(blockTrade, rmClassID("classBlock"));

	// Wall Player
	int blockWall = rmCreateGrouping("wall", "EU_Wall_SE_player");
    rmSetGroupingMinDistance(blockWall, 0.00);
    rmSetGroupingMaxDistance(blockWall, 0.50);
	rmAddGroupingToClass(blockWall, rmClassID("classBlock"));

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

	// Jewish Natives
	int blockJewish = rmCreateGrouping("jewish natives", "EU_Natives_Block_Jewish");
    rmSetGroupingMinDistance(blockJewish, 0.00);
    rmSetGroupingMaxDistance(blockJewish, 0.50);
	rmAddGroupingToClass(blockJewish, rmClassID("classBlock"));

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
	int blockMill = rmCreateGrouping("Mill", "EU_Resource_Block_Food3");
    rmSetGroupingMinDistance(blockMill, 0.00);
    rmSetGroupingMaxDistance(blockMill, 0.50);
	rmAddGroupingToClass(blockMill, rmClassID("classBlock"));

	// Destilery
	int blockDestilery = rmCreateGrouping("Destilery", "EU_Resource_Block_Food2");
    rmSetGroupingMinDistance(blockDestilery, 0.00);
    rmSetGroupingMaxDistance(blockDestilery, 0.50);
	rmAddGroupingToClass(blockDestilery, rmClassID("classBlock"));

	// Forester
	int blockForester = rmCreateGrouping("Forester", "EU_Resource_Block_Wood3");
    rmSetGroupingMinDistance(blockForester, 0.00);
    rmSetGroupingMaxDistance(blockForester, 0.50);
	rmAddGroupingToClass(blockForester, rmClassID("classBlock"));

	// Warehouse
	int blockWarehouse = rmCreateGrouping("Warehouse", "EU_Resource_Block_Wood1");
    rmSetGroupingMinDistance(blockWarehouse, 0.00);
    rmSetGroupingMaxDistance(blockWarehouse, 0.50);
	rmAddGroupingToClass(blockWarehouse, rmClassID("classBlock"));

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

	// Palace

	int verseillesPalace1 = rmPlaceGroupingInstanceAtLoc(blockPalaceBig01, 0.513, mapCenter+rmZTilesToFraction(33), 0);

	//rmPlaceGroupingAtLoc(blockWall, firstDefender, 0.175, mapCenter+rmZTilesToFraction(10));

	//rmPlaceGroupingAtLoc(blockWall, firstDefender, 0.825, mapCenter+rmZTilesToFraction(10));


	// Fixed Stuff
		rmPlaceGroupingAtLoc(blockTrade, 0, locX9, locZ1);
		rmPlaceGroupingAtLoc(blockTrade, 0, locX0, locZ1);
		rmPlaceGroupingAtLoc(blockTrade, 0, locX3, locZ1);
		rmPlaceGroupingAtLoc(blockTrade, 0, locX6, locZ1);

		rmPlaceGroupingAtLoc(blockCathedral, 0, locX4, locZ2);

	// City Center

		rmPlaceGroupingAtLoc(blockMarket, 0, locX2, locZ1);
		rmPlaceGroupingAtLoc(blockMarket, 0, locX4, locZ1);

		rmPlaceGroupingAtLoc(blockBank, 0, locX1, locZ2);
		rmPlaceGroupingAtLoc(blockBank, 0, locX5, locZ2);

		rmPlaceGroupingAtLoc(blockJewish, 0, locX8, locZ2);

		if (cNumberNonGaiaPlayers>=4){
			rmPlaceGroupingAtLoc(blockJewish, 0, locX1, locZ1);				
		}


	// Outer Center

		rmPlaceGroupingAtLoc(blockSansculot, 0, locX1, locZ3);

		if (cNumberNonGaiaPlayers>=4){
			rmPlaceGroupingAtLoc(blockSansculot, 0, locX8, locZ3);				
		}

		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locX3, locZ2);
		rmPlaceGroupingAtLoc(blockGoldSmelter, 0, locX0, locZ3);

		rmPlaceGroupingAtLoc(blockFactory, 0, locX2, locZ2);
		rmPlaceGroupingAtLoc(blockFactory, 0, locX8, locZ1);

	// Suburb


		rmPlaceGroupingAtLoc(blockDestilery, 0, locX4, locZ4);
		rmPlaceGroupingAtLoc(blockDestilery, 0, locX7, locZ4);

		rmPlaceGroupingAtLoc(blockWarehouse, 0, locX9, locZ4);
		rmPlaceGroupingAtLoc(blockWarehouse, 0, locX1, locZ4);


	// Everywhere

		rmSetNuggetDifficulty(194, 194);
		rmPlaceGroupingAtLoc(blockBastion01, 0, locX3, locZ3);
		rmPlaceGroupingAtLoc(blockBastion02, 0, locX3, locZ4);

		rmSetNuggetDifficulty(195, 195);
		rmPlaceGroupingAtLoc(blockEmbassy, 0, locX5, locZ1);

		rmSetNuggetDifficulty(192, 192);
		rmPlaceGroupingAtLoc(blockTreasure02, 0, locX4, locZ2);
		rmPlaceGroupingAtLoc(blockTreasure01, 0, locX6, locZ2);



// South Bank

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

	rmPlaceGroupingAtLoc(blockHouse01, 0, locX0, locZ4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX1, locZ4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX2, locZ4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZ4);
	rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZ4);
	rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZ4);
	rmPlaceGroupingAtLoc(blockHouse01, 0, locX6, locZ4);
	rmPlaceGroupingAtLoc(blockHouse02, 0, locX7, locZ4);
	rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZ4);
	rmPlaceGroupingAtLoc(blockHouse04, 0, locX9, locZ4);




//================we will add the other 4 rows after the groupings are defined and the randomizer is working=========

rmSetStatusText("",0.70);


// Add city hills

// City Hill Ramp

for (j=0; < 2) {  
		int smallPatchRamp = rmCreateArea("smallPatchRamp"+j);
		rmSetAreaSize(smallPatchRamp, rmAreaTilesToFraction(450), rmAreaTilesToFraction(450));
		rmSetAreaHeightBlend(smallPatchRamp, 3);
		rmSetAreaCoherence(smallPatchRamp, 1.0);
		rmSetAreaHeightBlend(smallPatchRamp, 2);
		rmSetAreaSmoothDistance(smallPatchRamp, 7);
		rmSetAreaBaseHeight(smallPatchRamp, 6.0);
		if (j == 0){
		rmSetAreaLocation(smallPatchRamp, 0.08, mapCenter+rmZTilesToFraction(45));
		}
		if (j == 1){
		rmSetAreaLocation(smallPatchRamp, 0.93, mapCenter+rmZTilesToFraction(45));
		}
		rmBuildArea(smallPatchRamp);  

		}

	for (j=0; < 6) {   

		 

		// City Hill Cliff
		int wallCliffs = rmCreateArea("wallCliffs"+j);
		rmSetAreaObeyWorldCircleConstraint(wallCliffs, false);
		rmAddAreaToClass(wallCliffs, rmClassID("classPlateau"));
		rmAddAreaConstraint(wallCliffs, avoidFence);
		rmAddAreaConstraint(wallCliffs, avoidTradeRouteWall);
		rmAddAreaConstraint(wallCliffs, avoidWall);
		rmSetAreaCliffType(wallCliffs, "Northwest Territory");
		rmAddAreaToClass(wallCliffs , classMountains);
		rmSetAreaCliffEdge(wallCliffs, 1, 1, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(wallCliffs, false, true, true, 1.5, true);
		rmSetAreaCliffHeight(wallCliffs, 0, 0, 0.5);
		rmSetAreaBaseHeight(wallCliffs, 5.0);
		rmSetAreaHeightBlend(wallCliffs, 3);
		if (j == 0){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
		rmSetAreaCoherence(wallCliffs, .93);
		rmSetAreaLocation(wallCliffs, 0.9, mapCenter+rmZTilesToFraction(9));
		rmAddAreaInfluenceSegment(wallCliffs, 0.78, mapCenter+rmZTilesToFraction(9), 1.0, mapCenter+rmZTilesToFraction(9));
		}
		if (j == 1){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
		rmSetAreaCoherence(wallCliffs, .93);
		rmSetAreaLocation(wallCliffs, 0.1, mapCenter+rmZTilesToFraction(9));
		rmAddAreaInfluenceSegment(wallCliffs, 0.0, mapCenter+rmZTilesToFraction(9), 0.26, mapCenter+rmZTilesToFraction(9));
		}
		if (j == 2){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
		rmSetAreaCoherence(wallCliffs, .93);
		rmSetAreaLocation(wallCliffs, 0.9, mapCenter+rmZTilesToFraction(46));
		rmAddAreaInfluenceSegment(wallCliffs, 0.78, mapCenter+rmZTilesToFraction(46), 1.0, mapCenter+rmZTilesToFraction(46));
		}
		if (j == 3){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
		rmSetAreaCoherence(wallCliffs, .93);
		rmSetAreaLocation(wallCliffs, 0.1, mapCenter+rmZTilesToFraction(46));
		rmAddAreaInfluenceSegment(wallCliffs, 0.0, mapCenter+rmZTilesToFraction(46), 0.27, mapCenter+rmZTilesToFraction(46));
		}
		if (j == 4){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(1200), rmAreaTilesToFraction(1200));
		rmSetAreaCoherence(wallCliffs, .8);
		rmSetAreaLocation(wallCliffs, 0.08, mapCenter+rmZTilesToFraction(27));
		rmAddAreaInfluenceSegment(wallCliffs, 0.08, mapCenter+rmZTilesToFraction(17), 0.08, mapCenter+rmZTilesToFraction(38));
		}
		if (j == 5){
		rmSetAreaSize(wallCliffs, rmAreaTilesToFraction(1200), rmAreaTilesToFraction(1200));
		rmSetAreaCoherence(wallCliffs, .8);
		rmSetAreaLocation(wallCliffs, 0.93, mapCenter+rmZTilesToFraction(27));
		rmAddAreaInfluenceSegment(wallCliffs, 0.93, mapCenter+rmZTilesToFraction(17), 0.93, mapCenter+rmZTilesToFraction(38));
		}
		rmBuildArea(wallCliffs);  
		
	}

// Place additional objects

	// Groupings
	int jesuitVillageType = rmRandInt(1, 3);
	int jesuitMonasteryID = rmCreateGrouping("countryMonastery1", "Jesuit_Cathedral_EU_0"+jesuitVillageType);
    rmSetGroupingMinDistance(jesuitMonasteryID, 0.00);
    rmSetGroupingMaxDistance(jesuitMonasteryID, 0.50);
	rmAddGroupingToClass(jesuitMonasteryID, rmClassID("classBlock"));

	int jesuitVillageType2 = rmRandInt(1, 3);
	int jesuitMonasteryID2 = rmCreateGrouping("countryMonastery2", "Jesuit_Cathedral_EU_0"+jesuitVillageType2);
    rmSetGroupingMinDistance(jesuitMonasteryID2, 0.00);
    rmSetGroupingMaxDistance(jesuitMonasteryID2, 0.50);
	rmAddGroupingToClass(jesuitMonasteryID2, rmClassID("classBlock"));

	rmPlaceGroupingAtLoc(jesuitMonasteryID, 0, 0.08, mapCenter+rmZTilesToFraction(30), 1);
	rmPlaceGroupingAtLoc(jesuitMonasteryID2, 0, 0.93, mapCenter+rmZTilesToFraction(30), 1);


	// Menagerie
	int blockMenagerie = rmCreateGrouping("menagerie", "EU_Resource_Block_Menager2");
    rmSetGroupingMinDistance(blockMenagerie, 0.00);
    rmSetGroupingMaxDistance(blockMenagerie, 0.50);
	rmAddGroupingToClass(blockMenagerie, rmClassID("classBlock"));

	rmSetNuggetDifficulty(98, 98);
	int menageriePlacement = rmPlaceGroupingInstanceAtLoc(blockMenagerie, 0.515, mapCenter+rmZTilesToFraction(70), 0);
		

	rmSetStatusText("",0.80);


//==============================================================
//dansil player placement
//==============================================================

// =============Player placement ======================= 
	//spawnSwitch = 0.1;

	if (cNumberTeams == 2){
		if (PlayerNum == 2)
		{
			if (rmGetPlayerTeam(1) == 0) {
				rmPlacePlayer(2, 0.7, 0.87);
				rmPlacePlayer(1, locX6, locZ6);
			}
			else {
				rmPlacePlayer(1, 0.7, 0.87);
				rmPlacePlayer(2, locX6, locZ6);
			}
			int playerAreaConstraint = rmCreateBoxConstraint("stay in player area", 0.2-rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(70), 0.81+rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(124));
			int playerStreetConstraint = rmCreateBoxConstraint("stay in street", 0.2, mapCenter-rmZTilesToFraction(70), 0.81, mapCenter-rmZTilesToFraction(122));
		}
		else {
			if (teamZeroCount == 1)			
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				for(i=1; <= cNumberNonGaiaPlayers) {
					if (rmGetPlayerTeam(i) == 0) {
						rmPlacePlayer(i, locX6, locZ6);
					}
				}
				playerAreaConstraint = rmCreateBoxConstraint("stay in player area", 0.2-rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(70), 0.81+rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(124));
				playerStreetConstraint = rmCreateBoxConstraint("stay in street", 0.2, mapCenter-rmZTilesToFraction(70), 0.81, mapCenter-rmZTilesToFraction(122));
			}
			if (teamZeroCount == 2)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);

				rmSetPlacementTeam(0);
				rmPlacePlayersLine(locX3, locZ6, locX7, locZ6, 0, 0);

				playerAreaConstraint = rmCreateBoxConstraint("stay in player area", 0.2-rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(70), 0.81+rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(124));
				playerStreetConstraint = rmCreateBoxConstraint("stay in street", 0.2, mapCenter-rmZTilesToFraction(70), 0.81, mapCenter-rmZTilesToFraction(122));
			}	
			if (teamZeroCount == 3)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				rmPlacePlayer(1, locX2, locZ6);
				rmPlacePlayer(2, locX4, locZ6);
				rmPlacePlayer(3, locX6, locZ6);
				playerAreaConstraint = rmCreateBoxConstraint("stay in player area", 0.1-rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(70), 0.91+rmZTilesToFraction(3), mapCenter-rmZTilesToFraction(124));
				playerStreetConstraint = rmCreateBoxConstraint("stay in street", 0.1, mapCenter-rmZTilesToFraction(70), 0.91, mapCenter-rmZTilesToFraction(122));
			}	
			if (teamZeroCount == 4)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				rmPlacePlayer(1, locX1, locZ6);
				rmPlacePlayer(2, locX3, locZ6);
				rmPlacePlayer(3, locX7, locZ6);
				rmPlacePlayer(4, locX9, locZ6);
				playerAreaConstraint = rmCreateBoxConstraint("stay in player area", 0.0, mapCenter-rmZTilesToFraction(70), 1.0, mapCenter-rmZTilesToFraction(124));
				playerStreetConstraint = rmCreateBoxConstraint("stay in street", 0.0, mapCenter-rmZTilesToFraction(70), 1.0, mapCenter-rmZTilesToFraction(122));
			}
			if (teamZeroCount == 5)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				rmPlacePlayer(1, locX1, locZ6);
				rmPlacePlayer(5, locX3, locZ6);
				rmPlacePlayer(3, locX5, locZ6);
				rmPlacePlayer(4, locX7, locZ6);
				rmPlacePlayer(5, locX9, locZ6);
			}
			if (teamZeroCount == 6)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				rmPlacePlayer(1, locX1, locZ6);
				rmPlacePlayer(2, locX3, locZ6);
				rmPlacePlayer(3, locX5, locZ6);
				rmPlacePlayer(4, locX7, locZ6);
				rmPlacePlayer(5, locX9, locZ6);
				rmPlacePlayer(6, locX4, locZ8);
			}
			if (teamZeroCount == 7)				
			{	
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.2, 0.87, 0.8, 0.87, 0, 0);
				rmPlacePlayer(1, locX1, locZ6);
				rmPlacePlayer(2, locX3, locZ6);
				rmPlacePlayer(3, locX5, locZ6);
				rmPlacePlayer(4, locX7, locZ6);
				rmPlacePlayer(5, locX9, locZ6);
				rmPlacePlayer(6, locX3, locZ8);
				rmPlacePlayer(7, locX5, locZ8);
			}														
		}
	}

	int cityPlayer = rmCreateArea("city Player");
    rmSetAreaSize(cityPlayer, 0.2, 0.2);
    rmSetAreaLocation(cityPlayer, 0.5, mapCenter-rmZTilesToFraction(90));		
    rmSetAreaCoherence(cityPlayer, 1.0);	
	rmSetAreaTerrainType(cityPlayer, "city\ground1_city_street_ground");
    rmAddAreaConstraint(cityPlayer , playerAreaConstraint);
	rmAddAreaConstraint(cityPlayer , avoidStreetZero);
    rmSetAreaObeyWorldCircleConstraint(cityPlayer, false);
	rmAddAreaToClass(cityPlayer , classStreet);
    rmBuildArea(cityPlayer); 

	int streetsPlayer = rmCreateArea("streets Player");
    rmSetAreaSize(streetsPlayer, 0.2, 0.2);
    rmSetAreaLocation(streetsPlayer, 0.5, mapCenter-rmZTilesToFraction(90));		
    rmSetAreaCoherence(streetsPlayer, 1.0);	
	rmSetAreaTerrainType(streetsPlayer, "city\ground1_cob_dark");
    rmAddAreaConstraint(streetsPlayer , playerStreetConstraint);
    rmSetAreaObeyWorldCircleConstraint(streetsPlayer, false);
	rmAddAreaToClass(streetsPlayer , classStreet);
    rmBuildArea(streetsPlayer); 

	//1 Attacker
	if (teamZeroCount == 1){
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX2, locZ5);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX3, locZ5);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ5);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locX7, locZ5);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locX2, locZ6);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX3, locZ6);
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZ6);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX7, locZ6);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locX2, locZ7);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locX3, locZ7);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZ7);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZ7);
	}

	//2 Attackers
	if (teamZeroCount == 2 || teamZeroCount == 4){
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX4, locZ5);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX5, locZ5);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locX4, locZ6);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX5, locZ6);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locX4, locZ7);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locX5, locZ7);
	}

	//3 Attackers
	if (teamZeroCount == 3){
		rmPlaceGroupingAtLoc(blockHouse01, 0, locX8, locZ5);
		rmPlaceGroupingAtLoc(blockHouse02, 0, locX7, locZ5);
		rmPlaceGroupingAtLoc(blockHouse05, 0, locX8, locZ6);
		rmPlaceGroupingAtLoc(blockHouse06, 0, locX7, locZ6);
		rmPlaceGroupingAtLoc(blockHouse03, 0, locX8, locZ7);
		rmPlaceGroupingAtLoc(blockHouse04, 0, locX7, locZ7);
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

	int berryID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID, 16.0);
	rmSetObjectDefMaxDistance(berryID, 17.0);
	rmAddObjectDefConstraint(berryID, shortAvoidCoin);


	// Attackers Blocks

	int blockPlayerStart = rmCreateGrouping("blockPlayerStart", "EU_SPC_PlayerStart");
    rmSetGroupingMinDistance(blockPlayerStart, 0.00);
    rmSetGroupingMaxDistance(blockPlayerStart, 0.50);
	rmAddGroupingToClass(blockPlayerStart, rmClassID("classBlock"));

	int blockPlayerGold = rmCreateGrouping("blockPlayerGold", "EU_SPC_PlayerGold");
    rmSetGroupingMinDistance(blockPlayerGold, 0.00);
    rmSetGroupingMaxDistance(blockPlayerGold, 0.50);
	rmAddGroupingToClass(blockPlayerGold, rmClassID("classBlock"));

	int blockPlayerFood = rmCreateGrouping("blockPlayerFood", "EU_SPC_PlayerFood");
    rmSetGroupingMinDistance(blockPlayerFood, 0.00);
    rmSetGroupingMaxDistance(blockPlayerFood, 0.50);
	rmAddGroupingToClass(blockPlayerFood, rmClassID("classBlock"));

	int blockPlayerWood = rmCreateGrouping("blockPlayerWood", "EU_SPC_PlayerWood");
    rmSetGroupingMinDistance(blockPlayerWood, 0.00);
    rmSetGroupingMaxDistance(blockPlayerWood, 0.50);
	rmAddGroupingToClass(blockPlayerWood, rmClassID("classBlock"));

	int blockConstruction = rmCreateGrouping("Construction", "EU_SPC_Block_Constr");
    rmSetGroupingMinDistance(blockConstruction, 0.00);
    rmSetGroupingMaxDistance(blockConstruction, 0.50);
	rmAddGroupingToClass(blockConstruction, rmClassID("classBlock"));




//place tcs

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);
    
    for(i=1; <= cNumberNonGaiaPlayers) {
		if (rmGetPlayerTeam(i) == 1) {
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
			/*if (cNumberNonGaiaPlayers >=4)
				rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));*/
		}

		if (rmGetPlayerTeam(i) == 0) {
			id=rmCreateArea("Player"+i);
			rmSetPlayerArea(i, id);
			rmPlaceGroupingAtLoc(blockPlayerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceGroupingAtLoc(blockPlayerGold, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(17), rmPlayerLocZFraction(i));
			rmPlaceGroupingAtLoc(blockPlayerFood, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)+rmZTilesToFraction(17));
			rmPlaceGroupingAtLoc(blockPlayerWood, i, rmPlayerLocXFraction(i)+rmXTilesToFraction(17), rmPlayerLocZFraction(i)+rmZTilesToFraction(17));
			if (teamZeroCount <=5){
				rmPlaceGroupingAtLoc(blockConstruction, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i)-rmZTilesToFraction(17));
				rmPlaceGroupingAtLoc(blockConstruction, 0, rmPlayerLocXFraction(i)+rmXTilesToFraction(17), rmPlayerLocZFraction(i)-rmZTilesToFraction(17));
			}
			rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		}

	}

    int avoidPlateauLarge = rmCreateClassDistanceConstraint("avoid city", rmClassID("classPlateau"), 15.0);
	int avoidWalls =rmCreateClassDistanceConstraint("stuff vs. the walls", rmClassID("classBlock"), 25);


	int countrysideSouth = rmCreateArea("countryside S");
    rmSetAreaSize(countrysideSouth , 0.3, 0.3);
    rmSetAreaLocation(countrysideSouth , 0.5, 0.05);		
    rmSetAreaCoherence(countrysideSouth , 1.0);
    rmSetAreaBaseHeight(countrysideSouth, 1.0);
    rmAddAreaConstraint(countrysideSouth , avoidStreetZero);
    rmSetAreaMix(countrysideSouth, "nwt_grass1");
    rmSetAreaElevationType(countrysideSouth, cElevTurbulence);
    rmSetAreaElevationVariation(countrysideSouth, 2.0);
    rmSetAreaElevationPersistence(countrysideSouth, 0.2);
    rmSetAreaElevationNoiseBias(countrysideSouth, 1);
	rmSetAreaObeyWorldCircleConstraint(countrysideSouth, false);

	/*rmSetAreaCliffType(countrysideSouth, "Northwest Territory");
		rmSetAreaCliffEdge(countrysideSouth, 4, 0.2, 0.0, 0.0, 2); //4,.225 looks cool too
		rmSetAreaCliffPainting(countrysideSouth, false, true, true, 1.5, true);
		rmSetAreaCliffHeight(countrysideSouth, 5, 0, 0.5);*/


    rmBuildArea(countrysideSouth ); 

	int roadPlayer = rmCreateArea("road Player");
    rmSetAreaSize(roadPlayer, 0.003, 0.003);
    rmSetAreaLocation(roadPlayer, 0.51, mapCenter-rmZTilesToFraction(134));	
	rmAddAreaInfluenceSegment(roadPlayer, 0.51, mapCenter-rmZTilesToFraction(124), 0.51, 0.0);	
    rmSetAreaCoherence(roadPlayer, 1.0);	
	rmSetAreaTerrainType(roadPlayer, "Texas\Path_Blend");
	rmAddAreaConstraint(roadPlayer , avoidStreetZero);
    rmSetAreaObeyWorldCircleConstraint(roadPlayer, false);
	rmAddAreaToClass(roadPlayer , classStreet);
    rmBuildArea(roadPlayer); 

	int verseillesGate = rmCreateGrouping("verseillesGate", "EU_Verseilles_Gate");
    rmSetGroupingMinDistance(verseillesGate, 0.00);
    rmSetGroupingMaxDistance(verseillesGate, 0.50);
	rmAddGroupingToClass(verseillesGate, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(verseillesGate, firstAttacker, 0.51, mapCenter-rmZTilesToFraction(126));	

	// Place Additional Blocks

	if (teamZeroCount <=2) {
		rmPlaceGroupingAtLoc(blockMill, 0, locX8, locZ5);
		rmPlaceGroupingAtLoc(blockMill, 0, locX1, locZ5);

		rmPlaceGroupingAtLoc(blockForester, 0, locX7, locZ8);
		rmPlaceGroupingAtLoc(blockForester, 0, locX2, locZ8);
	}

	if (teamZeroCount ==3) {
		rmPlaceGroupingAtLoc(blockMill, 0, locX9, locZ5);
		rmPlaceGroupingAtLoc(blockMill, 0, locX0, locZ5);

		rmPlaceGroupingAtLoc(blockForester, 0, locX9, locZ7);
		rmPlaceGroupingAtLoc(blockForester, 0, locX0, locZ7);
	}

	if (teamZeroCount ==4) {
		rmPlaceGroupingAtLoc(blockMill, 0, locX2, locZ8);
		rmPlaceGroupingAtLoc(blockMill, 0, locX7, locZ8);

		rmPlaceGroupingAtLoc(blockForester, 0, locX3, locZ8);
		rmPlaceGroupingAtLoc(blockForester, 0, locX6, locZ8);
	}

	if (teamZeroCount >4) {
		rmPlaceGroupingAtLoc(blockMill, 0, locX2, locZ9);
		rmPlaceGroupingAtLoc(blockMill, 0, locX7, locZ9);

		rmPlaceGroupingAtLoc(blockForester, 0, locX3, locZ9);
		rmPlaceGroupingAtLoc(blockForester, 0, locX6, locZ9);
	}

	// Cemetary
	for(i=1; < 4) {
		int cemetaryType = rmRandInt(1, 2);
		int cemetary = rmCreateGrouping("cemetary"+i, "Cemetary_0"+cemetaryType);
		rmSetGroupingMinDistance(cemetary, 0.00);
		rmSetGroupingMaxDistance(cemetary, 0.50);
		rmAddGroupingToClass(cemetary, classCemetary);
		rmAddGroupingConstraint(cemetary, cemetaryConstraint);
		rmAddGroupingConstraint(cemetary, avoidStreetZero);
		rmPlaceGroupingInArea(cemetary, 0, countrysideSouth, 1);
	}

	// Forester
	/*int foresterID = rmCreateObjectDef("random forester");
	rmAddObjectDefItem(foresterID, "zpSPCForester", 1, 0);
	rmAddObjectDefConstraint(foresterID, avoidBlockMedium);
	rmAddObjectDefConstraint(foresterID, playerEdgeConstraint);
	rmAddObjectDefConstraint(foresterID, avoidForester);
	rmAddObjectDefConstraint(foresterID, avoidStreetZero);
	rmPlaceObjectDefInArea(foresterID, 0, countrysideSouth, 2);*/

	// Random Houses
	int randomHouseID = rmCreateObjectDef("random house");
	rmAddObjectDefItem(randomHouseID, "zpSPCVillageHouseProp", 1, 0);
	rmAddObjectDefConstraint(randomHouseID, avoidBlockLong);
	rmAddObjectDefConstraint(randomHouseID, playerEdgeConstraint);
	rmAddObjectDefConstraint(randomHouseID, avoidAll);
	rmAddObjectDefConstraint(randomHouseID, avoidStreetZero);
	rmAddObjectDefConstraint(randomHouseID, cemetaryConstraintShort);
	if (teamZeroCount <=2)
    	rmPlaceObjectDefInArea(randomHouseID, 0, countrysideSouth, 20);
	else
		rmPlaceObjectDefInArea(randomHouseID, 0, countrysideSouth, 12);


	// Scattered FORESTS
	int forestTreeID = 0;
	int numTries=10*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries)
    {   
		int forest=rmCreateArea("forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest, "Great Plains Forest");
		rmSetAreaForestDensity(forest, 0.9);
		rmSetAreaForestClumpiness(forest, 0.4);
		rmSetAreaForestUnderbrush(forest, 0.0);
		rmSetAreaCoherence(forest, 0.4);
		rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		//rmSetAreaMix(forest, "Deccan_Grass_A");
		rmAddAreaConstraint(forest, forestConstraintShort);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest, avoidStreetShort);
		rmAddAreaConstraint(forest, Southward);
		rmAddAreaConstraint(forest, avoidStreetZero);
		rmAddAreaConstraint(forest, avoidTradeRouteMin);
		rmAddAreaConstraint(forest, cemetaryConstraintShort);
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

	// Scattered FORESTS
	numTries=10*cNumberNonGaiaPlayers;
	int failCount2=0;
	for (i=0; <numTries)
    {   
		int forest2=rmCreateArea("forest2 "+i);
		rmSetAreaWarnFailure(forest2, false);
		rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest2, "Great Plains Forest");
		rmSetAreaForestDensity(forest2, 0.6);
		rmSetAreaForestClumpiness(forest2, 0.4);
		rmSetAreaForestUnderbrush(forest2, 0.0);
		rmSetAreaCoherence(forest2, 0.4);
		rmSetAreaSmoothDistance(forest2, 10);
		rmAddAreaToClass(forest2, rmClassID("classForest")); 
		//rmSetAreaMix(forest, "Deccan_Grass_A");
		rmAddAreaConstraint(forest2, forestConstraint);
		rmAddAreaConstraint(forest2, avoidAll);
		rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest2, avoidStreet);
		rmAddAreaConstraint(forest2, Northward);
		if(rmBuildArea(forest2)==false)
		{
		// Stop trying once we fail 3 times in a row.
		failCount2++;
		if(failCount2==5)
			break;
		}
		else
		failCount2=0; 
    } 

	// DEER	
	int deerID=rmCreateObjectDef("deer herd");
	rmAddObjectDefItem(deerID, "deer", rmRandInt(8,10), 10.0);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
	rmAddObjectDefConstraint(deerID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerID, shortDeerConstraint);
	rmSetObjectDefCreateHerd(deerID, true);
	rmPlaceObjectDefInArea(deerID, 0, countrysideSouth, cNumberNonGaiaPlayers+2);
	rmPlaceObjectDefInArea(deerID, 0, countrysideNorth, cNumberNonGaiaPlayers);

	


	// Nuggets

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetNorth, avoidMountains);
	rmAddObjectDefConstraint(nuggetNorth, avoidStreetZero);
    rmAddObjectDefConstraint(nuggetNorth, avoidPark);
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
	rmAddObjectDefConstraint(nuggetSouth, avoidStreetZero);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, countrysideSouth, cNumberNonGaiaPlayers);

	int nuggetHard= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggetHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmAddObjectDefConstraint(nuggetHard, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHard, avoidAll);
    rmAddObjectDefConstraint(nuggetHard, avoidPark);
	rmAddObjectDefConstraint(nuggetHard, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHard, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetHard, 0, countrysideNorth, cNumberNonGaiaPlayers);

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidSilver);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidBlockLong);
    rmAddObjectDefConstraint(randomGoldID, avoidPark);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmPlaceObjectDefInArea(randomGoldID, 0, countrysideNorth, cNumberNonGaiaPlayers);



//add fish because why not
	rmSetStatusText("",0.90);

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
	rmObjectiveScreenSetTitle(302069);
	rmObjectiveScreenSetGoal(302070);
	rmObjectiveAdd(302065, 302066, true, true, true); // General objective
	rmObjectiveSetTeam(1, 1);
	rmObjectiveAdd(302067, 302068, true, true, true); // Royal Court REV
	rmObjectiveSetTeam(2, 2);

	// ************************* TRIGGERS ******************************

	//----- Define Variables -----

	int royalOrangerie = rmGetGroupingInstanceUnitByType(verseillesPalace1, "zpSPCRoyalOrangerie");
	int menagerieBuilding = rmGetGroupingInstanceUnitByType(menageriePlacement, "zpSPCMenagerie");
	int menagerieNugget = rmGetGroupingInstanceUnitByType(menageriePlacement, "ypNuggetTradingPost");

	// Victory Timer
	int victoryCountDown = 1800;

	//----- START -----

	// Convert Units

	rmCreateTrigger("Convert Orangerie");
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+royalOrangerie);
	rmSetTriggerEffectParamInt("PlayerID",firstDefender);
	rmSetTriggerPriority(4);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+royalOrangerie);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",firstDefender);
	rmSetTriggerEffectParam("UnitType","SPCFortGate");
	rmSetTriggerEffectParamInt("Dist",200);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+royalOrangerie);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",firstDefender);
	rmSetTriggerEffectParam("UnitType","DESPCEuroTower");
	rmSetTriggerEffectParamInt("Dist",200);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+royalOrangerie);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",firstAttacker);
	rmSetTriggerEffectParam("UnitType","CWallGate");
	rmSetTriggerEffectParamInt("Dist",200);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+royalOrangerie);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",firstAttacker);
	rmSetTriggerEffectParam("UnitType","Outpost");
	rmSetTriggerEffectParamInt("Dist",200);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

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
		rmSetTriggerEffectParam("TechID","cTechzpBonusBourbon"); // No normal revolutions on this map
		rmSetTriggerEffectParamInt("Status",2);
		if (rmGetPlayerTeam(i) == 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpVerseillesAttackerSetup"); // No normal revolutions on this map
			rmSetTriggerEffectParamInt("Status",2);
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
			rmSetTriggerEffectParam("TechID","cTechzpVerseillesDefenderSetup"); // No normal revolutions on this map
			rmSetTriggerEffectParamInt("Status",2);
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
    rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Civilization","SPCBourbon");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("StringID","302071");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Menagerie Convert
	rmCreateTrigger("Menagerie Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+menagerieBuilding);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+menagerieNugget);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+menagerieBuilding, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
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

	// ----- Victory Conditions -----
	rmCreateTrigger("Victory_Setup");
	rmCreateTrigger("Victory_Defenders");
	rmCreateTrigger("Victory_Attackers");

	rmSwitchToTrigger(rmTriggerID("Victory_Setup"));
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VictoryCounter"+i);
	rmSetTriggerEffectParamInt("Start", victoryCountDown);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Garde du Corps will come in"); // Counter Message
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
	rmAddTriggerCondition("Is Dead");
	rmSetTriggerConditionParam("SrcObject",""+royalOrangerie);
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
	rmCreateTrigger("Activate Jewish"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpJewishStar"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffJewish"); //operator
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Jewish"+k));
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

	// AI Jewish Fractions

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Jewish Fraction"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int jewishFraction=-1;
	jewishFraction = rmRandInt(1,3);

	if (jewishFraction==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishAmericans"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (jewishFraction==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishRussians"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (jewishFraction==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishGermans"); //operator
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
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechDEHCAncienRegime"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
}*/

	// Text
	rmSetStatusText("",0.99);


    
	




	
    
	
} // END