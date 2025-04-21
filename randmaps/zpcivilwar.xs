// CIVIL WAR
// April 2025

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


    int size = 500;
	rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);
   
   	// LIGHT SET

	rmSetLightingSet("honshu_Skirmish");


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
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 0.1);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 1.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpNativeWaterSpawnFlag2", 40.0);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 5.0);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "SocketCherokee", 70.0);
	int avoidscientists=rmCreateTypeDistanceConstraint("stay away from scientists", "zpSocketScientists", 45.0);
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

	int stopper2ID=rmCreateObjectDef("Armored Train Stopper2");
	rmAddObjectDefItem(stopper2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper2ID, true);
	rmSetObjectDefMinDistance(stopper2ID, 0.0);
	rmSetObjectDefMaxDistance(stopper2ID, 0.0);

	int stopper3ID=rmCreateObjectDef("Armored Train Stopper3");
	rmAddObjectDefItem(stopper3ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper3ID, true);
	rmSetObjectDefMinDistance(stopper3ID, 0.0);
	rmSetObjectDefMaxDistance(stopper3ID, 0.0);

	int stopperBridge1ID=rmCreateObjectDef("Armored Train Bridge1");
	rmAddObjectDefItem(stopperBridge1ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperBridge1ID, true);
	rmSetObjectDefMinDistance(stopperBridge1ID, 0.0);
	rmSetObjectDefMaxDistance(stopperBridge1ID, 0.0);

	int stopperBridge2ID=rmCreateObjectDef("Armored Train Bridge2");
	rmAddObjectDefItem(stopperBridge2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperBridge2ID, true);
	rmSetObjectDefMinDistance(stopperBridge2ID, 0.0);
	rmSetObjectDefMaxDistance(stopperBridge2ID, 0.0);

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
   
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.75);
   	rmAddTradeRouteWaypoint(tradeRouteID, 0.27, 0.75);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.75);
    rmBuildTradeRoute(tradeRouteID, "train");

	int tradeRouteID2 = rmCreateTradeRoute(); 
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.75);
   	rmAddTradeRouteWaypoint(tradeRouteID2, 0.27, 0.75);
    rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.75);
    rmBuildTradeRoute(tradeRouteID2, "armored_train");

	int tradeRouteID3 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.6, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.27, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.75);
    rmBuildTradeRoute(tradeRouteID3, "armored_train");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.47);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc);
	vector stoperLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.17);
    rmPlaceObjectDefAtPoint(stopper2ID, 0, socketLoc);
	vector stoperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopper2ID, 0));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
    rmPlaceObjectDefAtPoint(stopper3ID, 0, socketLoc);
	vector stoperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopper3ID, 0));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.33);
    rmPlaceObjectDefAtPoint(stopperBridge1ID, 0, socketLoc);
	vector bridgeLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperBridge1ID, 0));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.655);
    rmPlaceObjectDefAtPoint(stopperBridge2ID, 0, socketLoc);
	vector bridgeLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperBridge2ID, 0));

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	//  ************************** River ******************************

    // River must be defined before the islands are placed
    int riverID = rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 150, 150); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.5, 0.0);
    rmRiverAddWaypoint(riverID, 0.5, 1.0);
	rmRiverBuild(riverID);

	// River Trade Route
	int tradeRouteID4 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.1);
   	rmAddTradeRouteWaypoint(tradeRouteID4, 0.6, 0.2);
    rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.2);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.1);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
    rmBuildTradeRoute(tradeRouteID4, "native_water3_trail");

	// water Areas

	int riverArea1 = rmCreateArea("riverArea1");
    rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(6000), rmAreaTilesToFraction(6000));
    rmSetAreaLocation(riverArea1 , 0.5, 0.5);		
    rmSetAreaCoherence(riverArea1 , 0.6);
    rmSetAreaElevationVariation(riverArea1, 0.0);
	rmAddAreaToClass(riverArea1, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea1, 0.5, 0.0, 0.5, 0.5);
	rmSetAreaObeyWorldCircleConstraint(riverArea1, false);
    rmBuildArea(riverArea1); 

	int riverArea2 = rmCreateArea("riverArea2");
    rmSetAreaSize(riverArea2, rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800));
    rmSetAreaLocation(riverArea2, 0.5, 0.5);			
    rmSetAreaCoherence(riverArea2, 0.8);
    rmSetAreaElevationVariation(riverArea2, 0.0);
	rmAddAreaToClass(riverArea2, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea2, 0.5, 0.5, 0.0, 0.6);
	rmSetAreaObeyWorldCircleConstraint(riverArea2, false);
    rmBuildArea(riverArea2); 

	int riverArea3 = rmCreateArea("riverArea3");
    rmSetAreaSize(riverArea3 , rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800));
    rmSetAreaLocation(riverArea3 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea3 , 0.8);
    rmSetAreaElevationVariation(riverArea3, 0.0);
	rmAddAreaToClass(riverArea3, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea3, 0.5, 0.5, 1.0, 0.6);
	rmSetAreaObeyWorldCircleConstraint(riverArea3, false);
    rmBuildArea(riverArea3);

	int riverArea4 = rmCreateArea("riverArea4");
    rmSetAreaSize(riverArea4 , rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600));
    rmSetAreaLocation(riverArea4 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea4 , 0.8);
    rmSetAreaElevationVariation(riverArea4, 0.0);
	rmAddAreaToClass(riverArea4, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea4, 0.5, 0.5, 0.25, 1.0);
	rmSetAreaObeyWorldCircleConstraint(riverArea4, false);
    rmBuildArea(riverArea4);

	int riverArea5 = rmCreateArea("riverArea5");
    rmSetAreaSize(riverArea5 , rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600));
    rmSetAreaLocation(riverArea5 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea5 , 0.8);
    rmSetAreaElevationVariation(riverArea5, 0.0);
	rmAddAreaToClass(riverArea5, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea5, 0.5, 0.5, 0.75, 1.0);
	rmSetAreaObeyWorldCircleConstraint(riverArea5, false);
    rmBuildArea(riverArea5);

	int centralLake = rmCreateArea("centralLake");
    rmSetAreaSize(centralLake , rmAreaTilesToFraction(5600), rmAreaTilesToFraction(5600));
    rmSetAreaLocation(centralLake , 0.5, 0.5);	
    rmSetAreaCoherence(centralLake , 0.8);
    rmSetAreaElevationVariation(centralLake, 0.0);
	rmAddAreaToClass(centralLake, classDeepWater);
    rmBuildArea(centralLake);

	// Bridges
	int bridgeGrouping1 = rmCreateGrouping("bridge1", "Bridge_universal_N");
    rmSetGroupingMinDistance(bridgeGrouping1, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping1, 0.00);
	rmAddGroupingToClass(bridgeGrouping1, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(bridgeGrouping1, 0, rmXMetersToFraction(xsVectorGetX(bridgeLoc1)-2), rmZMetersToFraction(xsVectorGetZ(bridgeLoc1)+2));

	int bridgeGrouping2 = rmCreateGrouping("bridge2", "Bridge_universal_E");
    rmSetGroupingMinDistance(bridgeGrouping2, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping2, 0.00);
	rmAddGroupingToClass(bridgeGrouping2, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, rmXMetersToFraction(xsVectorGetX(bridgeLoc2)+4), rmZMetersToFraction(xsVectorGetZ(bridgeLoc2)+4));

	// Shallows
	int Shallow1ID = rmCreateArea("shallow1");
    rmSetAreaSize(Shallow1ID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(600));
    rmSetAreaCoherence(Shallow1ID, 0.5);
    rmSetAreaHeightBlend(Shallow1ID, 1.5);
    rmSetAreaSmoothDistance(Shallow1ID, 5);
    rmSetAreaLocation(Shallow1ID, 0.1, 0.6);
	rmAddAreaInfluenceSegment(Shallow1ID, 0.1, 0.55, 0.1, 0.65);
	rmSetAreaBaseHeight(Shallow1ID, -1.5);
    rmBuildArea(Shallow1ID);

	int Shallow2ID = rmCreateArea("shallow2");
    rmSetAreaSize(Shallow2ID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(600));
    rmSetAreaCoherence(Shallow2ID, 0.5);
    rmSetAreaHeightBlend(Shallow2ID, 1.5);
    rmSetAreaSmoothDistance(Shallow2ID, 5);
    rmSetAreaLocation(Shallow2ID, 0.9, 0.6);
	rmAddAreaInfluenceSegment(Shallow2ID, 0.9, 0.55, 0.9, 0.65);
	rmSetAreaBaseHeight(Shallow2ID, -1.5);
    rmBuildArea(Shallow2ID);

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!! ISLANDS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	int nativeIsland1ID = rmCreateArea("native_island1");
    rmSetAreaSize(nativeIsland1ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland1ID, 1.0);
    rmSetAreaMix(nativeIsland1ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland1ID, 1);
    rmSetAreaSmoothDistance(nativeIsland1ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland1ID, false);
	rmAddAreaConstraint(nativeIsland1ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland1ID, 0.5, 1.0);
	rmSetAreaBaseHeight(nativeIsland1ID, 1);
    rmBuildArea(nativeIsland1ID);

	int nativeIsland2ID = rmCreateArea("native_island2");
    rmSetAreaSize(nativeIsland2ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland2ID, 1.0);
    rmSetAreaMix(nativeIsland2ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland2ID, 1);
    rmSetAreaSmoothDistance(nativeIsland2ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland2ID, false);
	rmAddAreaConstraint(nativeIsland2ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland2ID, 0.2, 0.8);
	rmSetAreaBaseHeight(nativeIsland2ID, 1);
    rmBuildArea(nativeIsland2ID);

	int nativeIsland3ID = rmCreateArea("native_island3");
    rmSetAreaSize(nativeIsland3ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland3ID, 1.0);
    rmSetAreaMix(nativeIsland3ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland3ID, 1);
    rmSetAreaSmoothDistance(nativeIsland3ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland3ID, false);
	rmAddAreaConstraint(nativeIsland3ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland3ID, 0.8, 0.8);
	rmSetAreaBaseHeight(nativeIsland3ID, 1);
    rmBuildArea(nativeIsland3ID);

	int playerIslandSouthID = rmCreateArea("playerIslandSouth");
    rmSetAreaSize(playerIslandSouthID, 0.3, 0.3);
    rmSetAreaCoherence(playerIslandSouthID, 1.0);
    rmSetAreaMix(playerIslandSouthID, "nwt_grass2");
    rmSetAreaBaseHeight(playerIslandSouthID, 1);
    rmSetAreaHeightBlend(playerIslandSouthID, 2);
    rmSetAreaSmoothDistance(playerIslandSouthID, 5);
    rmSetAreaObeyWorldCircleConstraint(playerIslandSouthID, false);
	rmAddAreaConstraint(playerIslandSouthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandSouthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandSouthID, avoidTradeRoute);
    rmSetAreaLocation(playerIslandSouthID, 0.2, 0.4);
    rmBuildArea(playerIslandSouthID);

	int playerIslandNorthID = rmCreateArea("playerIslandNorth");
	rmSetAreaSize(playerIslandNorthID, 0.3, 0.3);
	rmSetAreaCoherence(playerIslandNorthID, 1.0);
	rmSetAreaMix(playerIslandNorthID, "nwt_grass2");
	rmSetAreaBaseHeight(playerIslandNorthID, 1);
	rmSetAreaHeightBlend(playerIslandNorthID, 2);
	rmSetAreaSmoothDistance(playerIslandNorthID, 5);
	rmSetAreaObeyWorldCircleConstraint(playerIslandNorthID, false);
	rmAddAreaConstraint(playerIslandNorthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandNorthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandNorthID, avoidTradeRoute);
	rmSetAreaLocation(playerIslandNorthID, 0.8, 0.4);
	rmBuildArea(playerIslandNorthID);

	// City States

	int stopperCityState1ID=rmCreateObjectDef("Armored Train Stopper State 1");
	rmAddObjectDefItem(stopperCityState1ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState1ID, true);
	rmSetObjectDefMinDistance(stopperCityState1ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState1ID, 0.0);  

	int stopperCityState2ID=rmCreateObjectDef("Armored Train Stopper State 2");
	rmAddObjectDefItem(stopperCityState2ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState2ID, true);
	rmSetObjectDefMinDistance(stopperCityState2ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState2ID, 0.0);

	int stopperCityState3ID=rmCreateObjectDef("Armored Train Stopper State 3");
	rmAddObjectDefItem(stopperCityState3ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState3ID, true);
	rmSetObjectDefMinDistance(stopperCityState3ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState3ID, 0.0);


	int station01ID=rmCreateObjectDef("Station1");
	rmAddObjectDefItem(station01ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station01ID, true);
	rmSetObjectDefMinDistance(station01ID, 0.0);
	rmSetObjectDefMaxDistance(station01ID, 0.0);
	rmSetObjectDefTradeRouteID(station01ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station01ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc)), rmZMetersToFraction(xsVectorGetZ(stoperLoc)+9));
	vector stationLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station01ID, 0));

	int station02ID=rmCreateObjectDef("Station2");
	rmAddObjectDefItem(station02ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station02ID, true);
	rmSetObjectDefMinDistance(station02ID, 0.0);
	rmSetObjectDefMaxDistance(station02ID, 0.0);
	rmSetObjectDefTradeRouteID(station02ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station02ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc2)), rmZMetersToFraction(xsVectorGetZ(stoperLoc2)+9));
	vector stationLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station02ID, 0));

	int station03ID=rmCreateObjectDef("Station3");
	rmAddObjectDefItem(station03ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station03ID, true);
	rmSetObjectDefMinDistance(station03ID, 0.0);
	rmSetObjectDefMaxDistance(station03ID, 0.0);
	rmSetObjectDefTradeRouteID(station03ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station03ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc3)), rmZMetersToFraction(xsVectorGetZ(stoperLoc3)+9));
	vector stationLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station03ID, 0));

	int socket01 = rmCreateGrouping("socket01", "City_State_Western_Station");
    rmSetGroupingMinDistance(socket01, 0.00);
    rmSetGroupingMaxDistance(socket01, 0.00);
	rmAddGroupingToClass(socket01, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc1)), rmZMetersToFraction(xsVectorGetZ(stationLoc1)-3));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc2)), rmZMetersToFraction(xsVectorGetZ(stationLoc2)-3));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc3)), rmZMetersToFraction(xsVectorGetZ(stationLoc3)-3));

	int cityState01 = rmCreateGrouping("citystate1", "City_State_Western_01");
    rmSetGroupingMinDistance(cityState01, 0.00);
    rmSetGroupingMaxDistance(cityState01, 0.00);
	rmAddGroupingToClass(cityState01, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc1)), rmZMetersToFraction(xsVectorGetZ(stationLoc1)-3));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.49);
    rmPlaceObjectDefAtPoint(stopperCityState1ID, 0, socketLoc);

	int cityState02 = rmCreateGrouping("citystate2", "City_State_Western_02");
    rmSetGroupingMinDistance(cityState02, 0.00);
    rmSetGroupingMaxDistance(cityState02, 0.00);
	rmAddGroupingToClass(cityState02, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState02, 0, rmXMetersToFraction(xsVectorGetX(stationLoc2)), rmZMetersToFraction(xsVectorGetZ(stationLoc2)-2));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
    rmPlaceObjectDefAtPoint(stopperCityState2ID, 0, socketLoc);

	int cityState03 = rmCreateGrouping("citystate3", "City_State_Western_03");
    rmSetGroupingMinDistance(cityState03, 0.00);
    rmSetGroupingMaxDistance(cityState03, 0.00);
	rmAddGroupingToClass(cityState03, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState03, 0, rmXMetersToFraction(xsVectorGetX(stationLoc3)), rmZMetersToFraction(xsVectorGetZ(stationLoc3)-2));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.81);
    rmPlaceObjectDefAtPoint(stopperCityState3ID, 0, socketLoc);


	// Inventors

	int scientistControllerID = rmCreateObjectDef("scientist controller 1");
	rmAddObjectDefItem(scientistControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(scientistControllerID, 0.0);
	rmSetObjectDefMaxDistance(scientistControllerID, 0.0);
	rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.33,0.43);
	vector scientistControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID, 0));

	int scientistControllerID2 = rmCreateObjectDef("scientist controller 2");
	rmAddObjectDefItem(scientistControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(scientistControllerID2, 0.0);
	rmSetObjectDefMaxDistance(scientistControllerID2, 0.0);
	rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.67, 0.43);
	vector scientistControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID2, 0));

	int inventorIsland1ID = rmCreateArea("inventor_island1");
    rmSetAreaSize(inventorIsland1ID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
    rmSetAreaCoherence(inventorIsland1ID, 1.0);
    rmSetAreaMix(inventorIsland1ID, "nwt_grass2");
    rmSetAreaHeightBlend(inventorIsland1ID, 2);
    rmSetAreaSmoothDistance(inventorIsland1ID, 10);
    rmSetAreaObeyWorldCircleConstraint(inventorIsland1ID, false);
    rmSetAreaLocation(inventorIsland1ID, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)));
	rmSetAreaBaseHeight(inventorIsland1ID, 1);
    rmBuildArea(inventorIsland1ID);

	int inventorIsland2ID = rmCreateArea("inventor_island2");
    rmSetAreaSize(inventorIsland2ID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
    rmSetAreaCoherence(inventorIsland2ID, 1.0);
    rmSetAreaMix(inventorIsland2ID, "nwt_grass2");
    rmSetAreaHeightBlend(inventorIsland2ID, 2);
    rmSetAreaSmoothDistance(inventorIsland2ID, 10);
    rmSetAreaObeyWorldCircleConstraint(inventorIsland2ID, false);
    rmSetAreaLocation(inventorIsland2ID, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)));
	rmSetAreaBaseHeight(inventorIsland2ID, 1);
    rmBuildArea(inventorIsland2ID);

	int scientistLabTypeTypeID = rmRandInt(1,2);
	int scientists1ID = -1;
	scientists1ID = rmCreateGrouping("scientists 1", "Scientist_Lab_Unknown_0"+scientistLabTypeTypeID);
	rmSetGroupingMinDistance(scientists1ID, 0);
	rmSetGroupingMaxDistance(scientists1ID, 0);
	rmPlaceGroupingAtLoc(scientists1ID, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)));
	
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

	int scientists2VillageTypeID = 3-scientistLabTypeTypeID;
	int scientists2ID = -1;
	scientists2ID = rmCreateGrouping("scientists 2", "Scientist_Lab_Unknown_0"+scientists2VillageTypeID);
	rmSetGroupingMinDistance(scientists2ID, 0);
	rmSetGroupingMaxDistance(scientists2ID, 0);
	rmPlaceGroupingAtLoc(scientists2ID, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)));

	int nativewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
	rmAddObjectDefItem(nativewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage2 = rmFindClosestPointVector(scientistControllerLoc2 , rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(nativewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

	rmClearClosestPointConstraints();

	int pirateportID2 = -1;
	pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport02");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage2a = rmFindClosestPointVector(scientistControllerLoc2, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

	rmClearClosestPointConstraints();


	// Port 1
	int portID01 = rmCreateObjectDef("port 02");
	portID01 = rmCreateGrouping("portG 01", "Harbour_Center_River_SW");
	rmPlaceGroupingAtLoc(portID01, 0, 0.6+rmXTilesToFraction(8), 0.2);

	// Port 2
	int portID02 = rmCreateObjectDef("port 02");
	portID02 = rmCreateGrouping("portG 02", "Harbour_Center_River_NE");
	rmPlaceGroupingAtLoc(portID02, 0, 0.4-rmXTilesToFraction(8),0.2);



	// ------Triggers--------//

	int unitID1 = rmGetUnitPlaced(stopperCityState1ID, 0)+5;
	int unitID2 = rmGetUnitPlaced(stopperCityState2ID, 0)+5;
	int unitID3 = rmGetUnitPlaced(stopperCityState3ID, 0)+5;

	int InventorFlag1 = rmGetUnitPlaced(nativewaterflagID1, 0)+5;
	int InventorFlag2 = rmGetUnitPlaced(nativewaterflagID2, 0)+5;

	int InventorSocket1 = InventorFlag1-1;
	int InventorSocket2 = InventorFlag2-1;

	// Cooldowns
	int armoredTrainActive = 90;
	int armoredTrainCooldown = 10;
	int armoredTrainCooldown2 = 240;

	// Starting techs

    rmCreateTrigger("Starting Techs");
    rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpCivilWarGeneralStup"); // DEEneableTradeRouteWater
		rmSetTriggerEffectParamInt("Status",2);
	}
    for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpIsAztecMap"); // DEEneableTradeRouteWater
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeTradeRouteCaptureableEuropean"); // DEEneableTradeRouteLand
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",0);
    rmSetTriggerEffectParam("TechID","cTechzpCivilWarConverGate"); // DEEneableTradeRouteLand
    rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

	// ******************* NATIVE POLOTICIANS ********************

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

	// ********************* TRADE ROUTE SETUP ***********************

	// Trade Route Setup

	rmCreateTrigger("AT_Initialize");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	
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

	// Normalize Trade Routes

	rmCreateTrigger("AT1_Normalize_TR");
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1000);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// *********************** ARMORED TRAIN CONTROL MANAGEMENT *******************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT1_Send_Station1_Plr"+k);
	rmCreateTrigger("AT1_Send_Station2_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station1_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station2_Plr"+k);
	rmCreateTrigger("AT1_Break_Station1_Plr"+k);
	rmCreateTrigger("AT1_Break_Station2_Plr"+k);
	rmCreateTrigger("AT1_Send_Station3_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station3_Plr"+k);
	rmCreateTrigger("AT1_Break_Station3_Plr"+k);

	rmCreateTrigger("AT_Destroy_Plr"+k);
	rmCreateTrigger("AT_Revert_Plr"+k);
	rmCreateTrigger("AT_Counter_Plr"+k);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {

	// Station 1

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID1);
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
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID1);
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
	rmSetTriggerConditionParam("DstObject",""+unitID1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Unit Create from Source");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
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
	rmSetTriggerConditionParam("DstObject",""+unitID2);
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
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","true");
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
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID2);
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
	rmSetTriggerConditionParam("DstObject",""+unitID2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
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


	// Station 3

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID3);
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
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID3);
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
	rmSetTriggerConditionParam("DstObject",""+unitID3);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
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

	// ******************** ARMORED TRAIN ABILITY MANAGEMENT ********************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Unlock_Plr"+k);
	rmCreateTrigger("AT_Lock_Plr"+k);
	rmCreateTrigger("AT_NoResource_Plr"+k);
	rmCreateTrigger("AT_Resource_Plr"+k);

	// Train is available

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

		// Player has no resource to send the train
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

		// Player has enough resource
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
	
	// Train is not available

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

	// ***************** CONVERT STATIONS ********************

	// Station 1

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Station1_on_Plr"+k);
	rmCreateTrigger("Station1_off_Plr"+k);

	rmSwitchToTrigger(rmTriggerID("Station1_on_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);

	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCSafehouse");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station1_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station1_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCSafehouse");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);

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
	rmSetTriggerConditionParam("DstObject",""+unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCSawMill");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
	rmSetTriggerEffectParamInt("Dist",60);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station2_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station2_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCSawMill");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
	rmSetTriggerEffectParamInt("Dist",60);

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
	rmSetTriggerConditionParam("DstObject",""+unitID3);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCDestilery");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
	rmSetTriggerEffectParamInt("Dist",60);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station3_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+unitID3);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",20);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","SPCXPWoodFortGate");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCDestilery");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+unitID3);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
	rmSetTriggerEffectParamInt("Dist",60);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_on_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}


	// ***************** DESTROYER TRAINING ********************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("DestroyerTrain1ONPlr"+k);
	rmCreateTrigger("DestroyerTrain1OFFPlr"+k);

	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("DestroyerTrain2ONPlr"+k);
	rmCreateTrigger("DestroyerTrain2OFFPlr"+k);


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

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
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
	rmSwitchToTrigger(rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false); 

	}

	// ********************* INVENTORS SOCKET CONTROL *********************

	// Inventors tech available

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
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Unlock_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Lock_Plr"+k));
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

	// Renegade Water trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates1on Player"+k);
	rmCreateTrigger("Pirates1off Player"+k);
	rmCreateTrigger("Pirates2on Player"+k);
	rmCreateTrigger("Pirates2off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag1);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag1);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag2);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag2);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Testing

	for (k=1; <= cNumberNonGaiaPlayers) {

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
	}



















    rmDefineClass("classPlateau");

	// Place Players - Mississipi Besed - temporary




	// Text
	rmSetStatusText("",0.70);

	float teamStartLoc = rmRandFloat(0.0, 1.0);

    if(cNumberTeams == 2){
		if (teamStartLoc > 0.5)
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.28, 0.4); 
			rmPlacePlayersCircular(0.4, 0.4, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.6, 0.72);
			rmPlacePlayersCircular(0.4, 0.4, 0);
		}
		else
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.6, 0.72);
			rmPlacePlayersCircular(0.4, 0.4, 0);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.28, 0.4); 
			rmPlacePlayersCircular(0.4, 0.4, 0);
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
	

	// ********************** RESOURCES **********************

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidTownCenterFar);
	rmAddObjectDefConstraint(randomGoldID, avoidSocketLong);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandSouthID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandNorthID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland1ID, 2);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland2ID, 2);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland3ID, 2);
	

	
    
	
} // END