// KING OF BOHEMIA
// February 2025

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
		subCiv0=rmGetCivID("zpBohemianKing");
		rmEchoInfo("subCiv0 is zpBohemianKing "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpBohemianKing");

		subCiv1=rmGetCivID("spcjesuit");
		rmEchoInfo("subCiv1 is spcjesuit "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "spcjesuit");
  
		subCiv2=rmGetCivID("bourbon");
		rmEchoInfo("subCiv2 is bourbon "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "bourbon");

	}

    // Picks the map size
	int size = 400;
	if (cNumberNonGaiaPlayers >= 5) {
		size = 460;
	}
	if (cNumberNonGaiaPlayers >= 5) {
		size = 520;
	}
	rmSetMapSize(size, size);
	
	// Set up map elevation variation - using subtle parameters to maintain height progression
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 2, 0.4, 2.5); // type, frequency, octaves, persistence, variation
	rmSetMapElevationHeightBlend(1);
	
	// Make the corners
	rmSetWorldCircleConstraint(true);

   	// LIGHT SET

	rmSetLightingSet("honshu_Skirmish");

	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("ZP Venice Lagoon");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	rmTerrainInitialize("nwterritory\ground_grass2_nwt", -0.114);  // Base terrain at lowest level (EU Island ground)
	rmSetMapType("grass");
	rmSetMapType("land");
    rmSetMapType("default");
    rmSetMapType("centralEurope");
    rmSetMapType("euroLandTradeRoute");
	rmSetMapType("piratehistoricalmap");

	chooseMercs();

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
	rmDefineClass("classBlock");

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(15), rmZTilesToFraction(15), 1.0-rmXTilesToFraction(15), 1.0-rmZTilesToFraction(15), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	int shoreAvoidLand = rmCreateTerrainDistanceConstraint("shore avoid land", "Land", true, 20.0);

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
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 50.0);
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
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
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
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 13.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 1.0);
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
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidFort=rmCreateTypeDistanceConstraint("avoid Fort", "zpFortConvertable", 50.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", "Elk", 50.0);
	
	int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), 6.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);
	int avoidJesuit=rmCreateTypeDistanceConstraint("avoid Jesuit Cathedral", "zpSocketJesuitEU", 30.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ********************* Trade Route *******************************

    // Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
   
    // Create circular trade route around the map edge
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.85);    // Top
    rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.75);   // Top Right
    rmAddTradeRouteWaypoint(tradeRouteID, 0.85, 0.5);    // Right
    rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.25);   // Bottom Right
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.15);    // Bottom
    rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.25);   // Bottom Left
    rmAddTradeRouteWaypoint(tradeRouteID, 0.15, 0.5);    // Left
    rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.75);   // Top Left
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.85);    // Back to Top
    rmBuildTradeRoute(tradeRouteID, "dirt");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts Land");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);


	//  ************************** Island and River ******************************

	// Prague Castle in the center
	int pragueCastle = rmCreateGrouping("bridge1", "prague_castle");
    rmSetGroupingMinDistance(pragueCastle, 0.00);
    rmSetGroupingMaxDistance(pragueCastle, 0.00);
	rmAddGroupingToClass(pragueCastle, rmClassID("classPlateau"));


    // River must be defined before the islands are placed
    int riverID = rmRiverCreate(-1, "ZP Bohemian River", 4, 4, 89, 89); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.5, 0.0);
    rmRiverAddWaypoint(riverID, 0.5, 1.5);
	rmRiverBuild(riverID);

    // Place the grouping on the island - using 0.5,0.5 as base and adjusting by -30,-24 tiles
	rmSetNuggetDifficulty(301, 301);
	int pragueCastleInstance = rmPlaceGroupingInstanceAtLoc(pragueCastle, 0.5-rmXMetersToFraction(2), 0.5+rmZMetersToFraction(8), 0);

    // Create center point to avoid
    int centerPoint = rmCreateObjectDef("center point");
    rmAddObjectDefItem(centerPoint, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmPlaceObjectDefAtLoc(centerPoint, 0, 0.5, 0.5);
    
    // Create constraint to avoid center point
    int avoidCenterPoint = rmCreateTypeDistanceConstraint("avoid center point", "zpSPCWaterSpawnPoint", 92.0);
    int avoidCenterPointLong = rmCreateTypeDistanceConstraint("avoid center point long", "zpSPCWaterSpawnPoint", 110.0);
    // Calculate map radius and adjust for height progression:
    // Base terrain (-0.114 to 0.000) -> Castle (2.983) -> Standard bridges (3.088-3.150) -> EU bridges (5.136)
    float mapRadius = sqrt(rmGetMapXSize() * rmGetMapXSize() + rmGetMapZSize() * rmGetMapZSize()) / 2.0;
    int avoidCenterPointUltraLong = rmCreateTypeDistanceConstraint("avoid center point ultra long", "zpSPCWaterSpawnPoint", 0.95 * mapRadius);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid plateau short", rmClassID("classPlateau"), 20.0);

    // Create north continent
    int northContinentID = rmCreateArea("north_continent");
    rmSetAreaSize(northContinentID, 0.55, 0.55);
    rmSetAreaCoherence(northContinentID, 0.65);
    rmSetAreaMix(northContinentID, "italy_grass_lush");
    rmSetAreaBaseHeight(northContinentID, 2.983);  // Castle structure height
    rmSetAreaHeightBlend(northContinentID, 2);
    rmSetAreaSmoothDistance(northContinentID, 50);
    rmSetAreaMinBlobs(northContinentID, 8);
    rmSetAreaMaxBlobs(northContinentID, 12);
    rmSetAreaMinBlobDistance(northContinentID, 8.0);
    rmSetAreaMaxBlobDistance(northContinentID, 12.0);
    rmSetAreaObeyWorldCircleConstraint(northContinentID, false);
    rmAddAreaToClass(northContinentID, rmClassID("classPlateau"));
    rmAddAreaConstraint(northContinentID, avoidCenterPoint);
    
    rmSetAreaLocation(northContinentID, 0.50, 0.9);
    rmAddAreaInfluencePoint(northContinentID, 0.50, 0.97);
    rmAddAreaInfluencePoint(northContinentID, 0.30, 0.95);
    rmAddAreaInfluencePoint(northContinentID, 0.15, 0.85);
    rmAddAreaInfluencePoint(northContinentID, 0.05, 0.70);
    rmAddAreaInfluencePoint(northContinentID, 0.03, 0.50);
    rmAddAreaInfluencePoint(northContinentID, 0.95, 0.70);
    rmAddAreaInfluencePoint(northContinentID, 0.85, 0.85);
    rmAddAreaInfluencePoint(northContinentID, 0.70, 0.95);
    
    rmBuildArea(northContinentID);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// **************** Create continents ****************

    // Create south continent
    int southContinentID = rmCreateArea("south_continent");
    rmSetAreaSize(southContinentID, 0.55, 0.55);
    rmSetAreaCoherence(southContinentID, 0.65);
    rmSetAreaMix(southContinentID, "italy_grass_lush");
    rmSetAreaBaseHeight(southContinentID, 2.983);  // Castle structure height
    rmSetAreaHeightBlend(southContinentID, 2);
    rmSetAreaSmoothDistance(southContinentID, 50);
    rmSetAreaMinBlobs(southContinentID, 8);
    rmSetAreaMaxBlobs(southContinentID, 12);
    rmSetAreaMinBlobDistance(southContinentID, 8.0);
    rmSetAreaMaxBlobDistance(southContinentID, 12.0);
    rmSetAreaObeyWorldCircleConstraint(southContinentID, false);
    rmAddAreaToClass(southContinentID, rmClassID("classPlateau"));
    rmAddAreaConstraint(southContinentID, avoidCenterPoint);
    
    rmSetAreaLocation(southContinentID, 0.50, 0.10);
    rmAddAreaInfluencePoint(southContinentID, 0.50, 0.03);
    rmAddAreaInfluencePoint(southContinentID, 0.70, 0.05);
    rmAddAreaInfluencePoint(southContinentID, 0.85, 0.15);
    rmAddAreaInfluencePoint(southContinentID, 0.95, 0.30);
    rmAddAreaInfluencePoint(southContinentID, 0.97, 0.50);
    rmAddAreaInfluencePoint(southContinentID, 0.05, 0.30);
    rmAddAreaInfluencePoint(southContinentID, 0.15, 0.15);
    rmAddAreaInfluencePoint(southContinentID, 0.30, 0.05);
    
    rmBuildArea(southContinentID);

	// ********************** Place natives and other objects **********************

	// Place Jesuit natives

	int jesuitMonastery1Type = rmRandInt(1, 3);
	int jesuitMonastery2Type = rmRandInt(1, 3);
	int jesuitMonastery3Type = rmRandInt(1, 3);
	int jesuitMonastery4Type = rmRandInt(1, 3);

	int jesuitMonastery1ID = rmCreateGrouping("monastery 1", "Jesuit_Cathedral_EU_0"+jesuitMonastery1Type);
	int jesuitMonastery2ID = rmCreateGrouping("monastery 2", "Jesuit_Cathedral_EU_0"+jesuitMonastery2Type);
	int jesuitMonastery3ID = rmCreateGrouping("monastery 3", "Jesuit_Cathedral_EU_0"+jesuitMonastery3Type);
	int jesuitMonastery4ID = rmCreateGrouping("monastery 4", "Jesuit_Cathedral_EU_0"+jesuitMonastery4Type);
	
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

	if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.1, 0.62, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.1, 0.62, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.9, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.9, 0.38, 1);
	}
	if (cNumberNonGaiaPlayers ==3){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.1, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.1, 0.38, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.9, 0.38, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.9, 0.38, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.5, 0.90, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.5, 0.90, 1);
	}
	if (cNumberNonGaiaPlayers ==5){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.5, 0.08, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.5, 0.08, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.7, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.7, 0.85, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.3, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.3, 0.85, 1);
	}
	if (cNumberNonGaiaPlayers ==6){
		rmPlaceGroupingAtLoc(jesuitMonastery1ID, 0, 0.08, 0.5, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID1, 0, 0.08, 0.5, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery2ID, 0, 0.7, 0.85, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID2, 0, 0.7, 0.85, 1);
		rmPlaceGroupingAtLoc(jesuitMonastery3ID, 0, 0.7, 0.15, 1);
		rmPlaceObjectDefAtLoc(jesuitControllerID3, 0, 0.7, 0.15, 1);
	}
	if (cNumberNonGaiaPlayers ==7){
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
	

	// Countryside Castles

	int bohemianCastle1Type = 1;
	int bohemianCastle2Type = 1;
	int bohemianCastle3Type = 1;
	int bohemianCastle4Type = 1;

	int castleControllerID1 = rmCreateObjectDef("castle controller 1");
	rmAddObjectDefItem(castleControllerID1, "zpTrainStopper", 1, 0.0);
	int castleControllerID2 = rmCreateObjectDef("castle controller 2");
	rmAddObjectDefItem(castleControllerID2, "zpTrainStopper", 1, 0.0);
	int castleControllerID3 = rmCreateObjectDef("castle controller 3");
	rmAddObjectDefItem(castleControllerID3, "zpTrainStopper", 1, 0.0);

	rmSetNuggetDifficulty(302, 302);

	if (cNumberNonGaiaPlayers ==2 || cNumberNonGaiaPlayers ==4 || cNumberNonGaiaPlayers ==8){
		rmPlaceObjectDefAtLoc(castleControllerID1, 0, 0.62, 0.9);
		rmPlaceObjectDefAtLoc(castleControllerID2, 0, 0.38, 0.1);
	}
	if (cNumberNonGaiaPlayers ==5){
		rmPlaceObjectDefAtLoc(castleControllerID1, 0, 0.065, 0.45);
		rmPlaceObjectDefAtLoc(castleControllerID2, 0, 0.92, 0.45);
	}
	
	if (cNumberNonGaiaPlayers ==6){
		rmPlaceObjectDefAtLoc(castleControllerID1, 0, 0.92, 0.5);
		rmPlaceObjectDefAtLoc(castleControllerID2, 0, 0.3, 0.85);
		rmPlaceObjectDefAtLoc(castleControllerID3, 0, 0.3, 0.15);
	}

	if (cNumberNonGaiaPlayers ==7){
		rmPlaceObjectDefAtLoc(castleControllerID1, 0, 0.5, 0.92);
		rmPlaceObjectDefAtLoc(castleControllerID2, 0, 0.1, 0.35);
		rmPlaceObjectDefAtLoc(castleControllerID3, 0, 0.9, 0.4);
	}

	
	vector castleControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(castleControllerID1, 0));
	vector castleControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(castleControllerID2, 0));
	vector castleControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(castleControllerID3, 0));
	
	// Place Castles

	int countrysideCastleID1 = rmCreateGrouping("Bohemian Castle 1", "Bohemian_Castle_0"+bohemianCastle1Type);
	int countryCastleInstance1 = rmPlaceGroupingInstanceAtLoc(countrysideCastleID1, rmXMetersToFraction(xsVectorGetX(castleControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc1)), 0);
	
	int countrysideCastleID2 = rmCreateGrouping("Bohemian Castle 2", "Bohemian_Castle_0"+bohemianCastle2Type);
	int countryCastleInstance2 = rmPlaceGroupingInstanceAtLoc(countrysideCastleID2, rmXMetersToFraction(xsVectorGetX(castleControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc2)), 0);

	int countrysideCastleID3 = rmCreateGrouping("Bohemian Castle 3", "Bohemian_Castle_0"+bohemianCastle3Type);
	int countryCastleInstance3 = rmPlaceGroupingInstanceAtLoc(countrysideCastleID3, rmXMetersToFraction(xsVectorGetX(castleControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc3)), 0);

	// Create north elevated area
    int northElevatedID = rmCreateArea("north_elevated");
    rmSetAreaSize(northElevatedID, 0.3, 0.3);
    rmSetAreaCoherence(northElevatedID, 0.35);
    rmSetAreaBaseHeight(northElevatedID, 4.6);
    rmAddAreaConstraint(northElevatedID, avoidCenterPointLong);
    rmSetAreaElevationType(northElevatedID, cElevTurbulence);
    rmSetAreaElevationVariation(northElevatedID, 6.0);
    rmSetAreaElevationPersistence(northElevatedID, 0.2);
    rmSetAreaElevationNoiseBias(northElevatedID, 1);
	rmSetAreaObeyWorldCircleConstraint(northElevatedID, false);
    
    rmSetAreaLocation(northElevatedID, 0.50, 0.8);
    rmAddAreaInfluencePoint(northElevatedID, 0.40, 0.90);
    rmAddAreaInfluencePoint(northElevatedID, 0.60, 0.90);
    
    rmBuildArea(northElevatedID);

    // Create south elevated area  
    int southElevatedID = rmCreateArea("south_elevated");
    rmSetAreaSize(southElevatedID, 0.3, 0.3);
    rmSetAreaCoherence(southElevatedID, 0.35);
    rmSetAreaBaseHeight(southElevatedID, 4.6);
    rmAddAreaConstraint(southElevatedID, avoidCenterPointLong);
    rmSetAreaElevationType(southElevatedID, cElevTurbulence);
    rmSetAreaElevationVariation(southElevatedID, 6.0);
    rmSetAreaElevationPersistence(southElevatedID, 0.2);
    rmSetAreaElevationNoiseBias(southElevatedID, 1);
    rmSetAreaObeyWorldCircleConstraint(southElevatedID, false);
    
    rmSetAreaLocation(southElevatedID, 0.50, 0.20);
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
	if (cNumberNonGaiaPlayers>=5){
		rmSetAreaSize(northCliffID, 0.19, 0.19);
	}
	else{
		rmSetAreaSize(northCliffID, 0.15, 0.15);
	}
    rmSetAreaCoherence(northCliffID, 0.35);
    rmSetAreaBaseHeight(northCliffID, 7.136);  // Using EU bridge height for dramatic elevation
    rmAddAreaConstraint(northCliffID, avoidCenterPointUltraLong);
	if (cNumberNonGaiaPlayers>=5){
		rmAddAreaConstraint(northCliffID, avoidBlockLong);
	}
	else{
		rmAddAreaConstraint(northCliffID, avoidBlock);
	}
    rmSetAreaCliffType(northCliffID, "Italian Cliff Grassy");
    rmSetAreaCliffEdge(northCliffID, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(northCliffID, 0, 0.0, 1.0);
	rmSetAreaCliffPainting(northCliffID, false, true, true, 1.5, true);
    rmSetAreaObeyWorldCircleConstraint(northCliffID, false);
	rmAddAreaToClass(northCliffID, classMountains);

    rmSetAreaLocation(northCliffID, 0.50, 0.98);
    rmAddAreaInfluencePoint(northCliffID, 0.40, 0.90);
    rmAddAreaInfluencePoint(northCliffID, 0.60, 0.90);

    rmBuildArea(northCliffID);

	// Create south cliff area
    int southCliffID = rmCreateArea("south_cliff");
    if (cNumberNonGaiaPlayers>=5){
		rmSetAreaSize(southCliffID, 0.19, 0.19);
	}
	else{
		rmSetAreaSize(southCliffID, 0.15, 0.15);
	}
    rmSetAreaCoherence(southCliffID, 0.35);
    rmSetAreaBaseHeight(southCliffID, 7.136);  // Using EU bridge height for dramatic elevation
    rmAddAreaConstraint(southCliffID, avoidCenterPointUltraLong);
	rmAddAreaConstraint(southCliffID, avoidTradeRouteFar2);
	if (cNumberNonGaiaPlayers>=5){
		rmAddAreaConstraint(southCliffID, avoidBlockLong);
	}
	else{
		rmAddAreaConstraint(southCliffID, avoidBlock);
	}
    rmSetAreaCliffType(southCliffID, "Italian Cliff Grassy");
    rmSetAreaCliffEdge(southCliffID, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(southCliffID, 0, 0.0, 1.0);
	rmSetAreaCliffPainting(southCliffID, false, true, true, 1.5, true);
    rmSetAreaObeyWorldCircleConstraint(southCliffID, false);
	rmAddAreaToClass(southCliffID, classMountains);

    rmSetAreaLocation(southCliffID, 0.50, 0.02);
    rmAddAreaInfluencePoint(southCliffID, 0.40, 0.10);
    rmAddAreaInfluencePoint(southCliffID, 0.60, 0.10);

    rmBuildArea(southCliffID);

	// Castle Cliffs

	int castleCliff1 = rmCreateArea ("castle cliff 1");
	rmSetAreaSize(castleCliff1, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
	rmSetAreaLocation(castleCliff1, rmXMetersToFraction(xsVectorGetX(castleControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc1)));
	rmSetAreaCoherence(castleCliff1, 0.8);
	rmAddAreaConstraint(castleCliff1, shortAvoidTradeRoute);
	rmSetAreaSmoothDistance(castleCliff1, 5);
	rmSetAreaBaseHeight(castleCliff1, 7.136);
	rmSetAreaCliffType(castleCliff1, "Italian Cliff Grassy");
	rmSetAreaCliffPainting(castleCliff1, false, true, true, 1.5, true);
	rmSetAreaCliffEdge(castleCliff1, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(castleCliff1, 0.0, 0.0, 1.0); 
	rmSetAreaElevationVariation(castleCliff1, 0.0);
	rmBuildArea(castleCliff1);

	int castleCliff2 = rmCreateArea ("castle cliff 2");
	rmSetAreaSize(castleCliff2, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
	rmSetAreaLocation(castleCliff2, rmXMetersToFraction(xsVectorGetX(castleControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc2)));
	rmSetAreaCoherence(castleCliff2, 0.8);
	rmAddAreaConstraint(castleCliff2, shortAvoidTradeRoute);
	rmSetAreaSmoothDistance(castleCliff2, 5);
	rmSetAreaBaseHeight(castleCliff2, 7.136);
	rmSetAreaCliffType(castleCliff2, "Italian Cliff Grassy");
	rmSetAreaCliffPainting(castleCliff2, false, true, true, 1.5, true);
	rmSetAreaCliffEdge(castleCliff2, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(castleCliff2, 0.0, 0.0, 1.0); 
	rmSetAreaElevationVariation(castleCliff2, 0.0);
	rmBuildArea(castleCliff2);

	int castleCliff3 = rmCreateArea ("castle cliff 3");
	rmSetAreaSize(castleCliff3, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
	rmSetAreaLocation(castleCliff3, rmXMetersToFraction(xsVectorGetX(castleControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(castleControllerLoc3)));
	rmSetAreaCoherence(castleCliff3, 0.8);
	rmAddAreaConstraint(castleCliff3, shortAvoidTradeRoute);
	rmSetAreaSmoothDistance(castleCliff3, 5);
	rmSetAreaBaseHeight(castleCliff3, 7.136);
	rmSetAreaCliffType(castleCliff3, "Italian Cliff Grassy");
	rmSetAreaCliffPainting(castleCliff3, false, true, true, 1.5, true);
	rmSetAreaCliffEdge(castleCliff3, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(castleCliff3, 0.0, 0.0, 1.0); 
	rmSetAreaElevationVariation(castleCliff3, 0.0);
	rmBuildArea(castleCliff3);



	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// **************** Trade route sockets ****************

    // Get number of players and calculate sockets
    int numPlayers = cNumberNonGaiaPlayers;
    int numSockets = 8;
    if(numPlayers == 5)
        numSockets = 5;
    else if(numPlayers == 6 || numPlayers == 3)
        numSockets = 6;
    else if(numPlayers == 7)
        numSockets = 7;

    vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.0);

    // Place sockets based on player count, maintaining base terrain level (-0.114 to 0.000)
    if(numSockets == 5)
    {
        // 5 sockets - optimal spacing avoiding castle structures (2.983)
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.12);  // Start at base terrain
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.31);  // Before castle area
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);  // Center point at base level
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.69);  // After castle area
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.88);  // End at base terrain
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
    }
    else if(numSockets == 6)
    {
        // 6 sockets - avoiding bridge heights (3.088-3.150)
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.26);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.42);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.58);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.74);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
    }
    else if(numSockets == 7)
    {
        // 7 sockets - avoiding EU bridge height (5.136)
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.09);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.23);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.37);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.63);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.77);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.91);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
    }
    else // 8 sockets
    {
        // 8 sockets - maximizing base terrain usage (-0.114 to 0.000)
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.125);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.34375);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.625);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.875);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
        socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID, 0.99);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc2);
    }

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ****************** Place Players ******************

	if (cNumberNonGaiaPlayers <=2){
      rmSetPlacementSection(0.4375, 0.4365);  
      rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==3){
		rmSetPlacementSection(0.1875, 0.8535);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==4){
		rmSetPlacementSection(0.1875, 0.9375);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==5){
		rmSetPlacementSection(0.1875, 0.9875);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==6){
		rmSetPlacementSection(0.1875, 1.0215);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==7){
		rmSetPlacementSection(0.1875, 1.0445);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
	}
	if (cNumberNonGaiaPlayers ==8){
		rmSetPlacementSection(0.1875, 1.0615);  
		rmPlacePlayersCircular(0.44, 0.44, 0);
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
	if (cNumberNonGaiaPlayers <= 6) {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	else {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, farAvoidTradeSockets);
	rmAddObjectDefConstraint(TCID, avoidWater30);
	rmAddObjectDefConstraint(TCID, avoidTradeRoute);
	rmAddObjectDefConstraint(TCID, avoidFort);

    int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
	rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
	rmAddObjectDefConstraint(startingUnits, avoidTradeRoute);
	rmAddObjectDefConstraint(startingUnits, farAvoidTradeSockets);

	int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "Mine", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerMineID, avoidTradeRoute); 
	rmAddObjectDefConstraint(playerMineID, farAvoidTradeSockets);

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "Deer", rmRandInt(7,10), 10.0);
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
	rmAddObjectDefItem(StartAreaTreeID, "treeNewEngland", 10, 12.0);
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
    rmSetAreaForestType(forest, "z69 North New England");
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
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
    rmAddObjectDefConstraint(randomGoldID, avoidCenterPoint);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmAddObjectDefConstraint(randomGoldID, Northward);
	rmAddObjectDefConstraint(randomGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldID, avoidWater10);
	rmPlaceObjectDefAtLoc(randomGoldID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	int randomGoldSouthID = rmCreateObjectDef("random south mine");
	rmAddObjectDefItem(randomGoldSouthID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldSouthID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldSouthID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldSouthID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidAll);
    rmAddObjectDefConstraint(randomGoldSouthID, avoidCenterPoint);
	rmAddObjectDefConstraint(randomGoldSouthID, playerEdgeConstraint);
	rmAddObjectDefConstraint(randomGoldSouthID, Southward);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidWater10);
	rmPlaceObjectDefAtLoc(randomGoldSouthID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	// Huntables North
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, "Elk", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.45));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHunt1);
	rmAddObjectDefConstraint(foodID1, avoidAll);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID1, avoidCenterPoint);
	rmAddObjectDefConstraint(foodID1, Northward);
	rmPlaceObjectDefAtLoc(foodID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

	// Huntables South
	int foodID2=rmCreateObjectDef("random food 2");
	rmAddObjectDefItem(foodID2, "Elk", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.45));
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidHunt1);
	rmAddObjectDefConstraint(foodID2, avoidAll);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID2, avoidCenterPoint);
	rmAddObjectDefConstraint(foodID2, Southward);
	rmPlaceObjectDefAtLoc(foodID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

	int berryID1 = rmCreateObjectDef("starting berries north");
	rmAddObjectDefItem(berryID1, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID1, 0);
	rmSetObjectDefMaxDistance(berryID1, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID1, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID1, avoidAll);
	rmAddObjectDefConstraint(berryID1, avoidWater10);
	rmAddObjectDefConstraint(berryID1, Northward);
	rmAddObjectDefConstraint(berryID1, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(berryID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers); 

	int berryID2 = rmCreateObjectDef("starting berries south");
	rmAddObjectDefItem(berryID2, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID2, 0);
	rmSetObjectDefMaxDistance(berryID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID2, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID2, avoidAll);
	rmAddObjectDefConstraint(berryID2, avoidWater10);
	rmAddObjectDefConstraint(berryID2, Southward);
	rmAddObjectDefConstraint(berryID2, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(berryID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers); 

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	int nuggetHardNorth= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetHardNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardNorth, 0.0);
	rmSetObjectDefMaxDistance(nuggetHardNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardNorth, Northward);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(nuggetHardNorth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2); 

	int nuggetHardSouth= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nuggetHardSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardSouth, 0.0);
	rmSetObjectDefMaxDistance(nuggetHardSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardSouth, Southward);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(nuggetHardSouth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2); 

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetNorth, 0.0);
	rmSetObjectDefMaxDistance(nuggetNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetNorth, Northward);
	rmAddObjectDefConstraint(nuggetNorth, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(nuggetNorth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers); 

	int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetSouth, 0.0);
	rmSetObjectDefMaxDistance(nuggetSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetSouth, Southward);
	rmAddObjectDefConstraint(nuggetSouth, avoidCenterPoint);
	rmPlaceObjectDefAtLoc(nuggetSouth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers); 

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>	
	rmSetStatusText("",0.90);

	//********************* GENERAL SETUP *************************

	// ____________________ LOCAL MERCENARIES ____________________
    rmDisableDefaultMercs(true);
    rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercFusilier", -1);
	rmEnableMerc("deMercPandour", -1);
	rmEnableMerc("deMercGrenadier", -1);
    rmEnableMerc("zpMercBohemianKnight", -1);
    rmEnableMerc("MercGreatCannon", -1);
    
    rmForbidTradeMonopoly(true);

	// _________________ Map Objectives ______________________________
	rmObjectiveScreenSetTitle(302344);
	rmObjectiveScreenSetGoal(302345);
	rmObjectiveAdd(302357, 302358, true, true, true); // General objective

	// ************************* TRIGGERS ******************************

	//----- Define Variables -----

	int castleSocket = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketBohemianKing");
	int castleCathedral = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCGermanCathedral");
	int castleFactory = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCCapturableFactory");
	int castleMarket = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCCityMarket");
	int castleMill = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCTownMill");
	int castleSmelter = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCGoldSmelter");
	int castleWarehouse = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCDemolisher");
	int castleMaltese = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCCathedral");
	int castleSynagogue = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpCathedralJewish");
	int castleCanter = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpCinematicRevealer");
	int castleNugget = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpNuggetInvisible");

	int castleGate1 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketA");
	int castleGate2 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketB");
	int castleGate3 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketC");
	int castleGate4 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketD");
	int castleGate5 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketE");
	int castleGate6 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketF");
	int castleGate7 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketG");
	int castleGate8 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpInvisibleGateSocketH");

	int castleTower1 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "deSPCSocketCityTower");
	int castleTower2 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone");
	int castleTower3 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone3");
	int castleTower4 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone4");
	int castleTower5 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone5");
	int castleTower6 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone6");
	int castleTower7 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone7");
	int castleTower8 = rmGetGroupingInstanceUnitByType(pragueCastleInstance, "zpSPCSocketCityTowerClone8");

	int countrysideCastleFlag1 = rmGetGroupingInstanceUnitByType(countryCastleInstance1, "zpSPCCapturableFlagInvisible");
	int countrysideCastleFlag2 = rmGetGroupingInstanceUnitByType(countryCastleInstance2, "zpSPCCapturableFlagInvisible");
	int countrysideCastleFlag3 = rmGetGroupingInstanceUnitByType(countryCastleInstance3, "zpSPCCapturableFlagInvisible");
	int countrysideCastleNugget1 = rmGetGroupingInstanceUnitByType(countryCastleInstance1, "zpNuggetInvisible");
	int countrysideCastleNugget2 = rmGetGroupingInstanceUnitByType(countryCastleInstance2, "zpNuggetInvisible");
	int countrysideCastleNugget3 = rmGetGroupingInstanceUnitByType(countryCastleInstance3, "zpNuggetInvisible");
	int countrysideCastleFort1 = rmGetGroupingInstanceUnitByType(countryCastleInstance1, "zpFortConvertable");
	int countrysideCastleFort2 = rmGetGroupingInstanceUnitByType(countryCastleInstance2, "zpFortConvertable");
	int countrysideCastleFort3 = rmGetGroupingInstanceUnitByType(countryCastleInstance3, "zpFortConvertable");
	
	int castleGate1Mod = castleGate1+1;
	int castleGate2Mod = castleGate2+1;
	int castleGate3Mod = castleGate3+1;
	int castleGate4Mod = castleGate4+1;
	int castleGate5Mod = castleGate5+1;
	int castleGate6Mod = castleGate6+1;
	int castleGate7Mod = castleGate7+1;
	int castleGate8Mod = castleGate8+1;

	int castleTower1Mod = castleTower1+1;
	int castleTower2Mod = castleTower2+1;
	int castleTower3Mod = castleTower3+1;
	int castleTower4Mod = castleTower4+1;
	int castleTower5Mod = castleTower5+1;
	int castleTower6Mod = castleTower6+1;
	int castleTower7Mod = castleTower7+1;
	int castleTower8Mod = castleTower8+1;

	int castleSocketMod = castleSocket+1;
	int castleCathedralMod = castleCathedral+1;
	int castleFactoryMod = castleFactory+1;
	int castleMarketMod = castleMarket+1;
	int castleMillMod = castleMill+1;
	int castleSmelterMod = castleSmelter+1;
	int castleWarehouseMod = castleWarehouse+1;
	int castleMalteseMod = castleMaltese+1;
	int castleSynagogueMod = castleSynagogue+1;
	int castleCanterMod = castleCanter+1;
	int castleNuggetMod = castleNugget+1;

	int countrysideCastleFlag1Mod	 = countrysideCastleFlag1+1;
	int countrysideCastleFlag2Mod = countrysideCastleFlag2+1;
	int countrysideCastleFlag3Mod = countrysideCastleFlag3+1;
	int countrysideCastleNugget1Mod = countrysideCastleNugget1+1;
	int countrysideCastleNugget2Mod = countrysideCastleNugget2+1;
	int countrysideCastleNugget3Mod = countrysideCastleNugget3+1;
	int countrysideCastleFort1Mod = countrysideCastleFort1+1;
	int countrysideCastleFort2Mod = countrysideCastleFort2+1;
	int countrysideCastleFort3Mod = countrysideCastleFort3+1;

	vector castleCanterLoc = rmGetUnitPosition(castleCanter);

	string guardianUnit = "zpNatBohemianLandsknecht";

	// Victory Timer
	int victoryCountDown = 900;
	int socketMinimapFlareDuration = 10;

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Europen Map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID", i);
        rmSetTriggerEffectParam("TechID","cTechzpKingOfBohemiaSetup"); // King of Bohemia Setup
        rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","SocketHolder"+i);
		rmSetTriggerEffectParamInt("Value",0);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	for(k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("AI Techs"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSPCKingOfBohemiaAI"); // Only for the AI to train the city state units from sockets
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Set up default resource values
	if (cNumberNonGaiaPlayers >2){
		rmCreateTrigger("Starting Resources");
		rmAddTriggerEffect("Modify Protounit Resource");
		rmSetTriggerEffectParam("ProtoUnit","zpValuableSource");
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

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+castleSocketMod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Conversion ON
	rmCreateTrigger("Socket 1 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+castleSocketMod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+castleSocketMod, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+castleSocketMod, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	for (k=1; <= cNumberNonGaiaPlayers) {
        rmCreateTrigger("PlayerVictory"+k);
		rmCreateTrigger("Victory_Counter"+k);
		rmCreateTrigger("Victory_Counter_OFF"+k);
		rmCreateTrigger("Revolution_MusicEnd"+k);
	}

    for (k=1; <= cNumberNonGaiaPlayers) {
        // Player Victory
		rmSwitchToTrigger(rmTriggerID("PlayerVictory"+k));
		rmAddTriggerEffect("Player Victory");
        rmSetTriggerEffectParamInt("Player", k);
        rmSetTriggerPriority(4); 
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        // Victory Counter
		rmSwitchToTrigger(rmTriggerID("Victory_Counter"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCGermanCathedral");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpKingOfBohemiaProclaimedShadow");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","VictoryCounter"+k);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg",""+rmGetPlayerName(k)+" wins in"); // Get exact player name
		rmSetTriggerEffectParamInt("Event", rmTriggerID("PlayerVictory"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter_OFF"+k));
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
		rmSetTriggerEffectParamFloat("Duration",0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpKingOfBohemiaRevShadow");
		rmSetTriggerEffectParamInt("Status",2);
		for(x=1; <= cNumberNonGaiaPlayers) {
			for(y=1; <= cNumberNonGaiaPlayers) {
				if (x == y || x == k || y == k) {
				}
				else {
					rmAddTriggerEffect("Diplomacy");
					rmSetTriggerEffectParamInt("Player1", x);
					rmSetTriggerEffectParamInt("Player2", y,);
					rmSetTriggerEffectParam("Status", "Ally", false);
					rmAddTriggerEffect("Diplomacy");
					rmSetTriggerEffectParamInt("Player1", y);
					rmSetTriggerEffectParamInt("Player2", x,);
					rmSetTriggerEffectParam("Status", "Ally", false);
				}
			}
		
			if (x != k) {
				rmAddTriggerEffect("Diplomacy");
				rmSetTriggerEffectParamInt("Player1", k);
				rmSetTriggerEffectParamInt("Player2", x,);
				rmSetTriggerEffectParam("Status", "Enemy", false);
				rmAddTriggerEffect("Diplomacy");
				rmSetTriggerEffectParamInt("Player1", x);
				rmSetTriggerEffectParamInt("Player2", k,);
				rmSetTriggerEffectParam("Status", "Enemy", false);
			}
		}
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player",k);
		rmSetTriggerEffectParam("Civilization","zpBohemianKing");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter_OFF"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCGermanCathedral");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+k));
		rmAddTriggerEffect("ZP Player : Reset Civilization for Flag");
		rmSetTriggerEffectParamInt("Player",k);
		for(x=1; <= cNumberNonGaiaPlayers) {
			for(y=1; <= cNumberNonGaiaPlayers) {
				if (x != y ) {
					rmAddTriggerEffect("Diplomacy");
					rmSetTriggerEffectParamInt("Player1", x);
					rmSetTriggerEffectParamInt("Player2", y,);
					rmSetTriggerEffectParam("Status", "Enemy", false);
					rmAddTriggerEffect("Diplomacy");
					rmSetTriggerEffectParamInt("Player1", y);
					rmSetTriggerEffectParamInt("Player2", x,);
					rmSetTriggerEffectParam("Status", "Enemy", false);
				}
			}
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
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
		rmCreateTrigger("Activate Bohemians"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpSPCKingOfBohemia"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffKingOfBohemia"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Bohemians"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}



	// City conversion

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("CastleOn_Player"+k);
		rmCreateTrigger("CastleOff_Player"+k);
		rmCreateTrigger("CastleOff_Dellayed_Player"+k);
		rmCreateTrigger("Gate1_Rebuilt"+k);
		rmCreateTrigger("Gate2_Rebuilt"+k);
		rmCreateTrigger("Gate3_Rebuilt"+k);
		rmCreateTrigger("Gate4_Rebuilt"+k);
		rmCreateTrigger("Gate5_Rebuilt"+k);
		rmCreateTrigger("Gate6_Rebuilt"+k);
		rmCreateTrigger("Gate7_Rebuilt"+k);
		rmCreateTrigger("Gate8_Rebuilt"+k);
		rmCreateTrigger("Gate_Rebuilt_Deactivator"+k);
		rmCreateTrigger("Tolerantion_Patent_On_Plr"+k);
		rmCreateTrigger("Tolerantion_Patent_Off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("CastleOn_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleSocketMod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",120);

		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone3");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone4");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone5");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone6");
		rmSetTriggerEffectParamInt("Dist",120);	
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone7");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone8");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deMercCannoneer");
		rmSetTriggerEffectParamInt("Dist",120);

		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",120);

		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortBarracksProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortStableProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deField");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCFortWallLargeProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate1Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate2Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate3Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate4Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate5Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate6Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate7Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate8Mod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleCathedralMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleFactoryMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMarketMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMillMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleSmelterMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleWarehouseMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMalteseMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleSynagogueMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralMaltese"); // Maltese
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralJewish"); // Jewish
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","SocketHolder"+k);
		rmSetTriggerEffectParamInt("Value",1);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(castleCanterLoc)+","+xsVectorGetY(castleCanterLoc)+","+xsVectorGetZ(castleCanterLoc), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("CastleOff_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate3_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate4_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate5_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate6_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate7_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate8_Rebuilt"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate_Rebuilt_Deactivator"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("CastleOff_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleSocketMod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpLockKingOfBohemiaTechs"); // Island Techs
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpLockCathedralMaltese"); // Maltese
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpLockCathedralJewish"); // Jewish
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","SocketHolder"+k);
		rmSetTriggerEffectParamInt("Value",0);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(castleCanterLoc)+","+xsVectorGetY(castleCanterLoc)+","+xsVectorGetZ(castleCanterLoc), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("CastleOff_Dellayed_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("CastleOn_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate3_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate4_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate5_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate6_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate7_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate8_Rebuilt"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("CastleOff_Dellayed_Player"+k));
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone3");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone4");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone5");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone6");
		rmSetTriggerEffectParamInt("Dist",120);	
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone7");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone8");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",120);

		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFortBarracks");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFortStable");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deField");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCFortWallLargeProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","SPCFortGate");
		rmSetTriggerEffectParamInt("Dist",120);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate1Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate2Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate3Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate4Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate5Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate6Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate7Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleGate8Mod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleCathedralMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleFactoryMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMarketMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMillMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleSmelterMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleWarehouseMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleMalteseMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleSynagogueMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+castleCanterMod);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpUnlockKingOfBohemiaTechs"); // Island Techs
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("Walls_Transform_ON1"+k);
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCFortStableProp");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConvertWallBohemia"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);

		rmCreateTrigger("Walls_Transform_ON2"+k);
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCFortBarracksProp");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConvertWallBohemia"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);

		rmSwitchToTrigger(rmTriggerID("Gate1_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate1Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate2_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate2Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate2"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate3_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate3Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate3"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate4_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate4Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate4"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate5_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate5Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate5"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate6_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate6Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate6"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate7_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate7Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate7"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate8_Rebuilt"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleGate8Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","SPCFortGate");
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConverGate8"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Gate_Rebuilt_Deactivator"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",500);
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate1_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate2_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate3_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate4_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate5_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate6_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate7_Rebuilt"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Gate8_Rebuilt"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Tolerantion_Patent_On_Plr"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpBohemianMercenaries");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerCondition("Quest Var Check");
		rmSetTriggerConditionParam("QuestVar","SocketHolder"+k);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Value",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBohemianMercenariesShadow");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Tolerantion_Patent_Off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Tolerantion_Patent_Off_Plr"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpBohemianMercenaries");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerCondition("Quest Var Check");
		rmSetTriggerConditionParam("QuestVar","SocketHolder"+k);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Value",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBohemianMercenariesShadowBack");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Tolerantion_Patent_On_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	rmCreateTrigger("Walls_Transform_OFF1");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","zpSPCFortStable");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpConvertWallBohemiaBack"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

	rmCreateTrigger("Walls_Transform_OFF2");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","zpSPCFortBarracks");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpConvertWallBohemiaBack"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

	// Convert Military Blocks

	rmCreateTrigger("Military_Block1_Unlock");
	rmCreateTrigger("Military_Block2_Unlock");
	rmCreateTrigger("Military_Block3_Unlock");

	rmSwitchToTrigger(rmTriggerID("Military_Block1_Unlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+countrysideCastleNugget1Mod);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag1Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","SPCFortGate");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag1Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpMountainCitadel");
	rmSetTriggerConditionParamInt("Dist",45);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "False");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Military_Block2_Unlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+countrysideCastleNugget2Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag2Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","SPCFortGate");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag2Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpMountainCitadel");
	rmSetTriggerConditionParamInt("Dist",45);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "False");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Military_Block3_Unlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+countrysideCastleNugget3Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag3Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","SPCFortGate");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+countrysideCastleFlag3Mod);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpMountainCitadel");
	rmSetTriggerConditionParamInt("Dist",45);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "False");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Military_Block1_Plr"+k);
		rmCreateTrigger("Military_Block2_Plr"+k);
		rmCreateTrigger("Military_Block3_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Military_Block1_Plr"+k));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag1Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpFortConvertable");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Flash Units");
		rmSetTriggerEffectParam("SrcObject", ""+countrysideCastleFort1Mod);
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
		rmSetTriggerConditionParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag2Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpFortConvertable");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Flash Units");
		rmSetTriggerEffectParam("SrcObject", ""+countrysideCastleFort2Mod);
		for (i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Military_Block2_Plr"+i));
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Military_Block3_Plr"+k));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallMediumProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortWallSmallProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortTowerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFortCornerProp");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpInvisibleGateSocket");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpParisFlagNoIcon");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+countrysideCastleFlag3Mod);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpFortConvertable");
		rmSetTriggerEffectParamInt("Dist",35);
		rmAddTriggerEffect("Flash Units");
		rmSetTriggerEffectParam("SrcObject", ""+countrysideCastleFort3Mod);
		for (i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Military_Block3_Plr"+i));
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

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
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpConverGate"); //operator
	rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}

	// AI King of Bohemia Fractions

	for (k=1; <= cNumberNonGaiaPlayers) {
	if (rmGetPlayerTeam(k) == 0) {
		rmCreateTrigger("ZP_Iniciate_King"+k);
		rmCreateTrigger("ZP_Execute_King"+k);
		rmCreateTrigger("ZP_Timer_King"+k);

		rmSwitchToTrigger(rmTriggerID("ZP_Iniciate_King"+k));
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechIndustrialize");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Timer_King"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Timer_King"+k));
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1",10);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeBohemianKing");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Execute_King"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Execute_King"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeBohemianKing");
		rmSetTriggerConditionParamInt("Status",2);

		int revFraction=-1;
		revFraction = rmRandInt(1,3);

		if (revFraction==1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateKingOfBohemiaHabsburg"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateKingOfBohemiaJagiellon"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateKingOfBohemiaWittelsbach"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
	}

	// AI Build Towers

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("BuildTower1_ON_Plr"+k);
		rmCreateTrigger("BuildTower1_OFF_Plr"+k);
		rmCreateTrigger("BuildTower2_ON_Plr"+k);
		rmCreateTrigger("BuildTower2_OFF_Plr"+k);
		rmCreateTrigger("BuildTower3_ON_Plr"+k);
		rmCreateTrigger("BuildTower3_OFF_Plr"+k);
		rmCreateTrigger("BuildTower4_ON_Plr"+k);
		rmCreateTrigger("BuildTower4_OFF_Plr"+k);
		rmCreateTrigger("BuildTower5_ON_Plr"+k);
		rmCreateTrigger("BuildTower5_OFF_Plr"+k);
		rmCreateTrigger("BuildTower6_ON_Plr"+k);
		rmCreateTrigger("BuildTower6_OFF_Plr"+k);
		rmCreateTrigger("BuildTower7_ON_Plr"+k);
		rmCreateTrigger("BuildTower7_OFF_Plr"+k);
		rmCreateTrigger("BuildTower8_ON_Plr"+k);
		rmCreateTrigger("BuildTower8_OFF_Plr"+k);


		rmSwitchToTrigger(rmTriggerID("BuildTower1_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower1Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower1Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower1_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower1_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower1_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower2_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower2Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower2Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower2_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower2_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower2_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower3_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower3Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower3Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower3_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower3_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower3_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	
		rmSwitchToTrigger(rmTriggerID("BuildTower4_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower4Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower4Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower4_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower4_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower4_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	
		rmSwitchToTrigger(rmTriggerID("BuildTower5_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower5Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower5Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower5_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower5_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower5_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower6_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower6Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower6Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower6_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower6_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower6_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower7_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower7Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower7Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower7_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower7_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower7_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower8_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleTower8Mod);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+castleTower8Mod);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower8_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower8_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower8_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("AI_Check1_Plr"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower8_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower7_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower6_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower5_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower4_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower3_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower2_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower1_ON_Plr"+k));
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
	rmSetStatusText("",0.99);
} // END