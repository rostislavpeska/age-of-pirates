// Crownlands
// June 2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void) 
{
	// Define Teams and map variations
    int teamZeroCount = rmGetNumberPlayersOnTeam(0);
    int teamOneCount = rmGetNumberPlayersOnTeam(1);

	int weirdMap = 0;
	int spawnType = 0;
	if (cNumberTeams <= 2 && teamZeroCount == teamOneCount)
	{
		weirdMap = 0;
		if (cNumberNonGaiaPlayers == 2)
			spawnType = 2;
		if (cNumberNonGaiaPlayers == 4)
			spawnType = 4;
		if (cNumberNonGaiaPlayers == 6)
			spawnType = 6;
		if (cNumberNonGaiaPlayers == 8)
			spawnType = 8;
	}
	else
	{
		weirdMap = 1;
		spawnType = 3;
	}

	// Picks the map size
	int size = 400+(cNumberNonGaiaPlayers*40);
	if (spawnType == 2) {
		size = 420;
	}
	if (spawnType == 4) {
		size = 520;
	}
	if (spawnType == 6) {
		size = 580;
	}
	if (spawnType == 8) {
		size = 630;
	}
	rmSetMapSize(size, size);

	if (weirdMap == 0)
		string fish1 = "FishSalmon";
	else
		fish1 = "ypFishCarp";

	// Define Defenders and Attackers for 2 Team map spawn
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

	if (weirdMap == 0)
	{
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
	}
    // Text
    // These status text lines are used to manually animate the map generation progress bar
    rmSetStatusText("",0.01);

    // Choose summer or winter 

    //		seasonPicker = 0.77; 		// for testing
    float seasonPicker = rmRandFloat(0,1);//rmRandFloat(0,1); //high # is snow, low is spring

	//Chooses which natives appear on the map
	int subCiv0=-1;
	int subCiv1=-1;

	if (rmAllocateSubCivs(2) == true)
	{
		subCiv0=rmGetCivID("zpPrinceElector");
		rmEchoInfo("subCiv0 is zpPrinceElector "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpPrinceElector");
  
		subCiv1=rmGetCivID("zphussites");
		rmEchoInfo("subCiv1 is zphussites "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zphussites");

	}
	
	// Set up map elevation variation - using subtle parameters to maintain height progression
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 2, 0.4, 2.5); // type, frequency, octaves, persistence, variation
	rmSetMapElevationHeightBlend(1);
	
	// Make the corners
	rmSetWorldCircleConstraint(true);

   	// LIGHT SET

	rmSetLightingSet("carolina_skirmish");

	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("ZP Venice Lagoon");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	rmTerrainInitialize("great_lakes\ground_grass1_gls", -0.114);  // Base terrain at lowest level (EU Island ground)
	rmSetMapType("grass");
	rmSetMapType("land");
    rmSetMapType("default");
    rmSetMapType("centralEurope");
    rmSetMapType("euroLandRiverTradeRoute");
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
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 12.0);
	
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
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 9.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 13.0);
	int avoidTradeRouteFar3 = rmCreateTradeRouteDistanceConstraint("trade route far 3", 20.0);
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
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 15.0);
	int avoidLandFish = rmCreateTerrainDistanceConstraint("avoid land medium fish", "Water", false, 4.0);
	
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

	int avoidCenterPoint = rmCreateTypeDistanceConstraint("avoid center point", "zpSPCWaterSpawnPoint", 92.0);
	int avoidStopper = rmCreateTypeDistanceConstraint("avoid stopper", "zpSPCWaterSpawnPoint", 35);
	int avoidStopperLong = rmCreateTypeDistanceConstraint("avoid stopper long", "zpSPCWaterSpawnPoint", 45);
	int avoidCathedral = rmCreateTypeDistanceConstraint("avoid cathedral", "zpSPCGermanCathedralCon0", 45);
	int avoidStopperShort = rmCreateTypeDistanceConstraint("avoid stopper short", "zpSPCWaterSpawnPoint", 25);
	int avoidCathedralShort = rmCreateTypeDistanceConstraint("avoid cathedral short", "zpSPCGermanCathedralCon0", 30);
	int avoidHussites = rmCreateTypeDistanceConstraint("avoid hussites", "zpHussiteFlag", 35);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ********************* Trade Route *******************************

	// Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);

	// 2 Team spawn Trade Route
	if (weirdMap==0)
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.4);    
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.6);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.4);  
		rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.6);   
		rmBuildTradeRoute(tradeRouteID, "river_trail");
	}
	// Weird Spawn trade route
	else
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.6);    
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.5);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.4);  
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.35);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.6);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.65);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.6);
		rmBuildTradeRoute(tradeRouteID, "dirt");
	}

	// 2 Team spawn only
	if (weirdMap==0){
		int riverID = rmRiverCreate(-1, "ZP Danube River", 4, 4, 14, 14); //  (-1, "new england lake", 18, 14, 5, 5)
		rmRiverAddWaypoint(riverID, 0.0, 0.4);   
		rmRiverAddWaypoint(riverID, 0.35, 0.6);
		rmRiverAddWaypoint(riverID, 0.65, 0.4);  
		rmRiverAddWaypoint(riverID, 1.0, 0.6);   
		rmRiverSetShallowRadius(riverID, 10);
		rmRiverAddShallow(riverID, 0.15);
		if (cNumberNonGaiaPlayers > 2)
			rmRiverAddShallow(riverID, 0.5);
		rmRiverAddShallow(riverID, 0.85);
		rmRiverBuild(riverID);

		// Place stoppers in shallows for the 2 tream spawn
		vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.85);
		rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);
	}
		

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	// ********************** Create Continents **************************

	// 2 Team Spawn only has riverside cliffs
	if (weirdMap==0){
		int shoreLineNorth = rmCreateArea("shore North");
		rmSetAreaSize(shoreLineNorth, 0.7, 0.7);
		rmSetAreaLocation(shoreLineNorth, 0.50, 0.90);
		rmSetAreaCoherence(shoreLineNorth, 1.0);	
		rmSetAreaBaseHeight(shoreLineNorth, 1.1);
		rmSetAreaCliffType(shoreLineNorth, "Italian Cliff River");
		rmSetAreaCliffEdge(shoreLineNorth, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(shoreLineNorth, 0, 0.0, 1.0);
		rmAddAreaConstraint(shoreLineNorth, avoidTradeRouteFar );
		rmAddAreaConstraint(shoreLineNorth, avoidStopper);
		rmSetAreaObeyWorldCircleConstraint(shoreLineNorth, false);
		rmBuildArea(shoreLineNorth); 

		int shoreLineSouth = rmCreateArea("shore South");
		rmSetAreaSize(shoreLineSouth, 0.7, 0.7);
		rmSetAreaLocation(shoreLineSouth, 0.50, 0.10);
		rmSetAreaCoherence(shoreLineSouth, 1.0);	
		rmSetAreaBaseHeight(shoreLineSouth, 1.1);
		rmSetAreaCliffType(shoreLineSouth, "Italian Cliff River");
		rmSetAreaCliffEdge(shoreLineSouth, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(shoreLineSouth, 0, 0.0, 1.0);
		rmAddAreaConstraint(shoreLineSouth, avoidTradeRouteFar );
		rmAddAreaConstraint(shoreLineSouth, avoidStopper);
		rmSetAreaObeyWorldCircleConstraint(shoreLineSouth, false);
		rmBuildArea(shoreLineSouth); 
	}

	// Create north continent
	int northContinentID = rmCreateArea("north_continent");
	rmSetAreaCoherence(northContinentID, 0.65);
	rmSetAreaMix(northContinentID, "italy_grass_lush");
	rmSetAreaHeightBlend(northContinentID, 2);
	rmSetAreaSmoothDistance(northContinentID, 10);
	rmSetAreaObeyWorldCircleConstraint(northContinentID, false);
	rmAddAreaToClass(northContinentID, rmClassID("classPlateau"));
	if (weirdMap==1){
		rmSetAreaSize(northContinentID, 0.65, 0.65);
		rmSetAreaBaseHeight(northContinentID, 1.1);
	}
	else{
		rmSetAreaSize(northContinentID, 0.51, 0.51);
		rmAddAreaConstraint(northContinentID, avoidTradeRouteFar2);
	}
	rmSetAreaLocation(northContinentID, 0.50, 0.90);

	rmBuildArea(northContinentID);

	// Create south continent
	int southContinentID = rmCreateArea("south_continent");
	rmSetAreaCoherence(southContinentID, 0.65);
	rmSetAreaMix(southContinentID, "italy_grass_lush");
	rmSetAreaHeightBlend(southContinentID, 2);
	rmSetAreaSmoothDistance(southContinentID, 10);
	rmSetAreaObeyWorldCircleConstraint(southContinentID, false);
	rmAddAreaToClass(southContinentID, rmClassID("classPlateau"));
	if (weirdMap==1){
		rmSetAreaSize(southContinentID, 0.65, 0.65);
		rmSetAreaBaseHeight(southContinentID, 1.1);
	}
	else{
		rmSetAreaSize(southContinentID, 0.51, 0.51);
		rmAddAreaConstraint(southContinentID, avoidTradeRouteFar2);
	}
	rmSetAreaLocation(southContinentID, 0.50, 0.10);

	rmBuildArea(southContinentID);

	// Weird Spawn only has a lake
	if (weirdMap==1){
		int deadSeaLakeDeepID=rmCreateArea("Central Lake");
		rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Danube River");
		rmSetAreaSize(deadSeaLakeDeepID, 0.04, 0.04);
		rmSetAreaCoherence(deadSeaLakeDeepID, 0.9);
		rmSetAreaLocation(deadSeaLakeDeepID, 0.5, 0.5);
		rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);
		rmAddAreaConstraint(deadSeaLakeDeepID, avoidTradeRoute);
		rmBuildArea(deadSeaLakeDeepID);

		// Create center point to avoid
		int centerPoint = rmCreateObjectDef("center point");
		rmAddObjectDefItem(centerPoint, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmPlaceObjectDefAtLoc(centerPoint, 0, 0.5, 0.5);
	}	

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// ********************* PLAYER PLACEMENT **************************
	float placementVariation = rmRandFloat(0.0, 0.9);

    if (weirdMap==0) // 1v1 and even teams
    {
        if (spawnType == 2) // 1v1
        {
            if (placementVariation < 0.5) 
            {
                rmPlacePlayer(firstAttacker, 0.45, 0.17);
                rmPlacePlayer(firstDefender, 0.55, 0.83);
            } 
            else 
            {
                rmPlacePlayer(firstDefender, 0.45, 0.17);
                rmPlacePlayer(firstAttacker, 0.55, 0.83);
            }
        }
        else if (spawnType == 4) // 2v2
        {
			if (placementVariation < 0.5) {
                rmPlacePlayer(firstAttacker, 0.4, 0.8);
				rmPlacePlayer(secondAttacker, 0.78, 0.72);
                rmPlacePlayer(firstDefender, 0.6, 0.2);
				rmPlacePlayer(secondDefender, 0.22, 0.28);
				 } 
           else {
                rmPlacePlayer(firstDefender, 0.4, 0.8);
				rmPlacePlayer(secondDefender, 0.78, 0.72);
                rmPlacePlayer(firstAttacker, 0.6, 0.2);
				rmPlacePlayer(secondAttacker, 0.22, 0.28);
				}
        }
        else if (spawnType == 6) // 3v3
        {
			if (placementVariation < 0.5) {
                rmPlacePlayer(firstAttacker, 0.22, 0.7);
				rmPlacePlayer(secondAttacker, 0.5, 0.85);
				rmPlacePlayer(thirdAttacker, 0.8, 0.7);
                rmPlacePlayer(firstDefender, 0.78, 0.3);
				rmPlacePlayer(secondDefender, 0.5, 0.15);
				rmPlacePlayer(thirdDefender, 0.2, 0.3);
				}
           else {
                rmPlacePlayer(firstDefender, 0.22, 0.7);
				rmPlacePlayer(secondDefender, 0.5, 0.85);
				rmPlacePlayer(thirdDefender, 0.8, 0.7);
                rmPlacePlayer(firstAttacker, 0.78, 0.3);
				rmPlacePlayer(secondAttacker, 0.5, 0.15);
				rmPlacePlayer(thirdAttacker, 0.2, 0.3);
				}
        }
		else if (spawnType == 8) // 4v4
        {
			if (placementVariation < 0.5) {
                rmPlacePlayer(firstAttacker, 0.22, 0.7);
				rmPlacePlayer(secondAttacker, 0.4, 0.85);
				rmPlacePlayer(thirdAttacker, 0.6, 0.85);
				rmPlacePlayer(fourthAttacker, 0.8, 0.7);
                rmPlacePlayer(firstDefender, 0.78, 0.3);
				rmPlacePlayer(secondDefender, 0.6, 0.15);
				rmPlacePlayer(thirdDefender, 0.4, 0.15);
				rmPlacePlayer(fourthDefender, 0.2, 0.3);
				}
           else {
                rmPlacePlayer(firstDefender, 0.22, 0.7);
				rmPlacePlayer(secondDefender, 0.4, 0.85);
				rmPlacePlayer(thirdDefender, 0.6, 0.85);
				rmPlacePlayer(fourthDefender, 0.8, 0.7);
                rmPlacePlayer(firstAttacker, 0.78, 0.3);
				rmPlacePlayer(secondAttacker, 0.6, 0.15);
				rmPlacePlayer(thirdAttacker, 0.4, 0.15);
				rmPlacePlayer(fourthAttacker, 0.2, 0.3);
				}
        }
    } 
   	else //FFA and weird spawns
    {
        if (cNumberNonGaiaPlayers ==3){
			rmSetPlacementSection(0.15, 0.85);  
			rmPlacePlayersCircular(0.385, 0.385, 0);
		}
		if (cNumberNonGaiaPlayers ==4){
			rmSetPlacementSection(0.0675, 0.8175);  
			rmPlacePlayersCircular(0.39, 0.39, 0);
		}
		if (cNumberNonGaiaPlayers ==5){
			rmSetPlacementSection(0.1875, 0.9875);  
			rmPlacePlayersCircular(0.40, 0.40, 0);
		}
		if (cNumberNonGaiaPlayers ==6){
			rmSetPlacementSection(0.1875, 1.0215);  
			rmPlacePlayersCircular(0.40, 0.40, 0);
		}
		if (cNumberNonGaiaPlayers ==7){
			rmSetPlacementSection(0.1875, 1.0445);  
			rmPlacePlayersCircular(0.41, 0.41, 0);
		}
		if (cNumberNonGaiaPlayers ==8){
			rmSetPlacementSection(0.1875, 1.0615);  
			rmPlacePlayersCircular(0.41, 0.41, 0);
		}
    }

	// ************************* Place Player Forts **************************

	// Starting Star Fort
    int playerFortID = rmCreateGrouping("starting star fort", "Player Mega Fort");
    rmSetGroupingMinDistance(playerFortID, 0.00);
    rmSetGroupingMaxDistance(playerFortID, 2.00);
    rmAddGroupingToClass(playerFortID, classStartingResource);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 0.0);
	rmSetObjectDefMaxDistance(startingUnits, 2.0);

	//  Place Starting Fort and Explorers
    for (i = 1; < numPlayer) 
    {
        rmPlaceGroupingAtLoc(playerFortID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i)-rmXTilesToFraction(12), rmPlayerLocZFraction(i));
    }

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// ************************** Natives **************************
	// Controllers
	int controllerID1 = rmCreateObjectDef("Controler 1");
	rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID1, 0.00);
	rmSetObjectDefMaxDistance(controllerID1, 0.00);

	int controllerID2 = rmCreateObjectDef("Controler 2");
	rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID2, 0.00);
	rmSetObjectDefMaxDistance(controllerID2, 0.00);

	int controllerID3= rmCreateObjectDef("Controler 3");
	rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID3, 0.00);
	rmSetObjectDefMaxDistance(controllerID3, 0.00);

	int controllerID4 = rmCreateObjectDef("Controler 4");
	rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(controllerID4, 0.00);
	rmSetObjectDefMaxDistance(controllerID4, 0.00);

	// Spawners
	int SpawnerID1 = rmCreateObjectDef("Spawner 1");
	rmAddObjectDefItem(SpawnerID1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(SpawnerID1, 0.00);
	rmSetObjectDefMaxDistance(SpawnerID1, 0.00);

	int SpawnerID2 = rmCreateObjectDef("Spawner 2");
	rmAddObjectDefItem(SpawnerID2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(SpawnerID2, 0.00);
	rmSetObjectDefMaxDistance(SpawnerID2, 0.00);

	int SpawnerID3= rmCreateObjectDef("Spawner 3");
	rmAddObjectDefItem(SpawnerID3, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(SpawnerID3, 0.00);
	rmSetObjectDefMaxDistance(SpawnerID3, 0.00);

	int SpawnerID4 = rmCreateObjectDef("Spawner 4");
	rmAddObjectDefItem(SpawnerID4, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(SpawnerID4, 0.00);
	rmSetObjectDefMaxDistance(SpawnerID4, 0.00);

	// Define Native Groupings

	// Bohemia
	int workshopBohemia = rmCreateGrouping("workshop bohemia", "Elector_Workshop_Glass");
    rmSetGroupingMinDistance(workshopBohemia, 0.00);
    rmSetGroupingMaxDistance(workshopBohemia, 0.00);
	rmAddGroupingToClass(workshopBohemia, rmClassID("classBlock"));

	int castleBohemia = rmCreateGrouping("castle bohemia", "Elector_Bohemia_01");
    rmSetGroupingMinDistance(castleBohemia, 0.00);
    rmSetGroupingMaxDistance(castleBohemia, 0.00);
	rmAddGroupingToClass(castleBohemia, rmClassID("classBlock"));

	// Saxony
	int workshopSaxony = rmCreateGrouping("workshop saxony", "Elector_Workshop_Bricks");
    rmSetGroupingMinDistance(workshopSaxony, 0.00);
    rmSetGroupingMaxDistance(workshopSaxony, 0.00);
	rmAddGroupingToClass(workshopSaxony, rmClassID("classBlock"));

	int castleSaxony = rmCreateGrouping("castle saxony", "Elector_Saxony_01");
    rmSetGroupingMinDistance(castleSaxony, 0.00);
    rmSetGroupingMaxDistance(castleSaxony, 0.00);
	rmAddGroupingToClass(castleSaxony, rmClassID("classBlock"));

	// Bavaria
	int workshopBavaria = rmCreateGrouping("workshop bavaria", "Elector_Workshop_Stone");
    rmSetGroupingMinDistance(workshopBavaria, 0.00);
    rmSetGroupingMaxDistance(workshopBavaria, 0.00);
	rmAddGroupingToClass(workshopBavaria, rmClassID("classBlock"));

	int castleBavaria = rmCreateGrouping("castle bavaria", "Elector_Bavaria_01");
    rmSetGroupingMinDistance(castleBavaria, 0.00);
    rmSetGroupingMaxDistance(castleBavaria, 0.00);
	rmAddGroupingToClass(castleBavaria, rmClassID("classBlock"));

	// Austria
	int workshopAustria = rmCreateGrouping("workshop austria", "Elector_Workshop_Copper");
    rmSetGroupingMinDistance(workshopAustria, 0.00);
    rmSetGroupingMaxDistance(workshopAustria, 0.00);
	rmAddGroupingToClass(workshopAustria, rmClassID("classBlock"));

	int castleAustria = rmCreateGrouping("castle austria", "Elector_Austria_01");
    rmSetGroupingMinDistance(castleAustria, 0.00);
    rmSetGroupingMaxDistance(castleAustria, 0.00);
	rmAddGroupingToClass(castleAustria, rmClassID("classBlock"));

	// Hussites
	int hussiteCampN = rmCreateGrouping("Hussite Camp North", "Hussite_Camp_04");
    rmSetGroupingMinDistance(hussiteCampN, 0.00);
    rmSetGroupingMaxDistance(hussiteCampN, 0.00);
	rmAddGroupingToClass(hussiteCampN, rmClassID("classBlock"));

	int hussiteCampS = rmCreateGrouping("Hussite Camp South", "Hussite_Camp_05");
    rmSetGroupingMinDistance(hussiteCampS, 0.00);
    rmSetGroupingMaxDistance(hussiteCampS, 0.00);
	rmAddGroupingToClass(hussiteCampS, rmClassID("classBlock"));

	// Place Natives based on spawn type
	if (spawnType == 2)
	{
		// Palaces
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.75, 0.7);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.32, 0.79);
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.25, 0.31);
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.68, 0.21);
	
		// Hussites
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.17, 0.7);
		rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.83, 0.3);
	}

	else if (spawnType == 4)
	{
		// Palaces
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.6, 0.65);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.22, 0.72);
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.4, 0.35);
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.78, 0.27);
	
		// Hussites
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.6, 0.87);
		rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.4, 0.14);
	}

	else if (spawnType == 6)
	{
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.65, 0.6);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.43, 0.71);
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.35, 0.4);
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.57, 0.29);
	
		// Hussites
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.35, 0.85);
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.7, 0.85);
		rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.65, 0.15);
		rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.3, 0.15);
	}

	else if (spawnType == 8)
	{
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.65, 0.57);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.43, 0.7);
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.35, 0.43);
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.57, 0.3);
	
		// Hussites
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.12, 0.6);
		rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.88, 0.4);
	}

	else
	{
		if (cNumberNonGaiaPlayers <= 5)
		{
			rmPlaceObjectDefAtLoc(controllerID1, 0, 0.42, 0.73);
			rmPlaceObjectDefAtLoc(controllerID2, 0, 0.73, 0.58);
			rmPlaceObjectDefAtLoc(controllerID3, 0, 0.58, 0.27);
			rmPlaceObjectDefAtLoc(controllerID4, 0, 0.27, 0.42);
		}
		else
		{
			rmPlaceObjectDefAtLoc(controllerID1, 0, 0.44, 0.72);
			rmPlaceObjectDefAtLoc(controllerID2, 0, 0.72, 0.56);
			rmPlaceObjectDefAtLoc(controllerID3, 0, 0.56, 0.28);
			rmPlaceObjectDefAtLoc(controllerID4, 0, 0.28, 0.44);
		}

		if (cNumberNonGaiaPlayers == 3)
		{
			// Hussites
			rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.5, 0.85);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.8, 0.35);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.15, 0.4);
		}
		if (cNumberNonGaiaPlayers == 4)
		{
			// Hussites
			rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.5, 0.85);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.5, 0.15);
			rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.15, 0.5);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.85, 0.5);
		}
		if (cNumberNonGaiaPlayers >= 5)
		{
			// Hussites
			rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.4, 0.3);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.6, 0.7);
			rmPlaceGroupingAtLoc(hussiteCampN, 0, 0.3, 0.6);
			rmPlaceGroupingAtLoc(hussiteCampS, 0, 0.7, 0.4);
		}
	}

	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
	vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
	vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
	vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

	// Place Palaces
	rmSetNuggetDifficulty(306, 306);

	// Bohemia
	int workshopBohemiaPlacement1 = rmPlaceGroupingInstanceAtLoc(workshopBohemia, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 0);
	rmPlaceGroupingAtLoc(castleBohemia, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(8), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
	rmPlaceObjectDefAtLoc(SpawnerID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(6), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))-rmXTilesToFraction(10));

	// Saxony
	int workshopSaxonyPlacement1 = rmPlaceGroupingInstanceAtLoc(workshopSaxony, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 0);
	rmPlaceGroupingAtLoc(castleSaxony, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2))-rmZTilesToFraction(6));
	rmPlaceObjectDefAtLoc(SpawnerID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2))-rmXTilesToFraction(8), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2))-rmZTilesToFraction(10));

	// Bavaria
	int workshopBavariaPlacement1 = rmPlaceGroupingInstanceAtLoc(workshopBavaria, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 0);
	rmPlaceGroupingAtLoc(castleBavaria, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))-rmXTilesToFraction(9), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))+rmZTilesToFraction(1));
	rmPlaceObjectDefAtLoc(SpawnerID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))-rmXTilesToFraction(8), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))-rmZTilesToFraction(10));

	// Austria
	int workshopAustriaPlacement1 = rmPlaceGroupingInstanceAtLoc(workshopAustria, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 0);
	rmPlaceGroupingAtLoc(castleAustria, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4))+rmZTilesToFraction(8));
	rmPlaceObjectDefAtLoc(SpawnerID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4))-rmXTilesToFraction(10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4))+rmZTilesToFraction(6));

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// Trade Route Sockets
	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);

	// *************************** Trade Sockets *****************************
	
	// 2 Teams: Soawns river tradce socket on a shore of a river
	if (weirdMap==0) {
		rmSetObjectDefMinDistance(socketID, 2.0);
		if (spawnType >= 6)
		rmSetObjectDefMaxDistance(socketID, 20.0);	
		else
			rmSetObjectDefMaxDistance(socketID, 10.0);
		rmAddObjectDefConstraint(socketID, ferryOnShore);

		rmPlaceObjectDefAtLoc(socketID, 0, 0.2, 0.57);	
		rmPlaceObjectDefAtLoc(socketID, 0, 0.5, 0.6);	
		rmPlaceObjectDefAtLoc(socketID, 0, 0.8, 0.43);	
		rmPlaceObjectDefAtLoc(socketID, 0, 0.5, 0.4);	
	}

	// Weird spawn: Spawns land sockets around the trade route
	else {
		rmSetObjectDefMinDistance(socketID, 2.0);
		rmSetObjectDefMaxDistance(socketID, 8.0);	
		rmAddObjectDefConstraint(socketID, avoidWater20);

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.99);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// **************************** Additional Cliffs *****************************
	int numCliffs =2;
	if (weirdMap == 1)
		numCliffs = 6;

	for (q = 1; <= numCliffs) {
		int edgeMountain=rmCreateArea("edge mountains"+q); 
		rmSetAreaCoherence(edgeMountain, 0.6);
		rmSetAreaSmoothDistance(edgeMountain, 5);
		rmSetAreaCliffType(edgeMountain, "Italian Cliff Grassy");
		rmSetAreaCliffEdge(edgeMountain, 4, 0.12, 0.0, 1.0, 0);
		rmSetAreaCliffHeight(edgeMountain, 6.0, 0.0, 0.5); 
		rmSetAreaObeyWorldCircleConstraint(edgeMountain, false);
		rmSetAreaElevationType(edgeMountain, cElevTurbulence);
		rmAddAreaConstraint(edgeMountain, avoidStopperLong);
		rmAddAreaConstraint(edgeMountain, avoidCathedral);
		rmAddAreaConstraint(edgeMountain, avoidHussites);
		rmAddAreaConstraint(edgeMountain, avoidTradeRouteFar3);
		rmAddAreaToClass(edgeMountain, classMountains);
		if (spawnType == 2 || spawnType == 4)
			rmSetAreaSize(edgeMountain, 0.08, 0.08);
		else if (spawnType == 6 || spawnType == 8)
			rmSetAreaSize(edgeMountain, 0.05, 0.05);
		else
			rmSetAreaSize(edgeMountain, 0.015, 0.015);

		rmSetAreaCliffPainting(edgeMountain, false, true, true, 1.5, true);

		if (q==1)
			rmSetAreaLocation(edgeMountain, 0.5, 0.98);
		if (q==2)
			rmSetAreaLocation(edgeMountain, 0.5, 0.02);
		if (q==3)
			rmSetAreaLocation(edgeMountain, 0.95, 0.63);
		if (q==4)
			rmSetAreaLocation(edgeMountain, 0.95, 0.37);
		if (q==5)
			rmSetAreaLocation(edgeMountain, 0.05, 0.37);
		if (q==6)
			rmSetAreaLocation(edgeMountain, 0.05, 0.63);
		rmBuildArea(edgeMountain);
	}

	// ***************************Forests *****************************

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
	rmAddObjectDefConstraint(randomGoldID, avoidStopperShort);
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
	rmAddObjectDefConstraint(randomGoldSouthID, avoidStopperShort);
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
	rmAddObjectDefConstraint(foodID1, Northward);
	rmAddObjectDefConstraint(foodID1, avoidStopperShort);
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
	rmAddObjectDefConstraint(foodID2, Southward);
	rmAddObjectDefConstraint(foodID2, avoidStopperShort);
	rmPlaceObjectDefAtLoc(foodID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

	int berryID1 = rmCreateObjectDef("starting berries north");
	rmAddObjectDefItem(berryID1, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID1, 0);
	rmSetObjectDefMaxDistance(berryID1, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID1, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID1, avoidAll);
	rmAddObjectDefConstraint(berryID1, avoidWater10);
	rmAddObjectDefConstraint(berryID1, Northward);
	rmAddObjectDefConstraint(berryID1, avoidStopperShort);
	rmPlaceObjectDefAtLoc(berryID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers); 

	int berryID2 = rmCreateObjectDef("starting berries south");
	rmAddObjectDefItem(berryID2, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID2, 0);
	rmSetObjectDefMaxDistance(berryID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID2, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID2, avoidAll);
	rmAddObjectDefConstraint(berryID2, avoidWater10);
	rmAddObjectDefConstraint(berryID2, Southward);
	rmAddObjectDefConstraint(berryID2, avoidStopperShort);
	rmPlaceObjectDefAtLoc(berryID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers); 

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	int nuggetHardNorth= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetHardNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardNorth, 0.3);
	rmSetObjectDefMaxDistance(nuggetHardNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardNorth, Northward);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidStopperShort);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidCathedralShort);
	rmPlaceObjectDefAtLoc(nuggetHardNorth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2); 

	int nuggetHardSouth= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nuggetHardSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardSouth, 0.3);
	rmSetObjectDefMaxDistance(nuggetHardSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardSouth, Southward);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidStopperShort);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidCathedralShort);
	rmPlaceObjectDefAtLoc(nuggetHardSouth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2); 

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetNorth, 0.0);
	rmSetObjectDefMaxDistance(nuggetNorth, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetNorth, Northward);
	rmAddObjectDefConstraint(nuggetNorth, avoidStopperShort);
	rmAddObjectDefConstraint(nuggetNorth, avoidCathedralShort);
	rmPlaceObjectDefAtLoc(nuggetNorth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers); 

	int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetSouth, 0.0);
	rmSetObjectDefMaxDistance(nuggetSouth, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetSouth, Southward);
	rmAddObjectDefConstraint(nuggetSouth, avoidStopperShort);
	rmAddObjectDefConstraint(nuggetSouth, avoidCathedralShort);
	rmPlaceObjectDefAtLoc(nuggetSouth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers); 

	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, fish1, 1, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, avoidLandFish);
	rmAddObjectDefConstraint(fishID, playerEdgeConstraint);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 25+cNumberNonGaiaPlayers*2);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>	
	rmSetStatusText("",0.90);

	// ____________________ LOCAL MERCENARIES ____________________
    rmDisableDefaultMercs(true);
    rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercJaeger", -1);
	rmEnableMerc("deMercPandour", -1);
	rmEnableMerc("deMercGrenadier", -1);
    rmEnableMerc("zpMercBohemianKnight", -1);
    rmEnableMerc("MercGreatCannon", -1);
    
    rmForbidTradeMonopoly(true);

	// _________________ Map Objectives ______________________________
	rmObjectiveScreenSetTitle(302344);
	rmObjectiveScreenSetGoal(302824);
	rmObjectiveAdd(302833, 302834, true, true, true); // General objective
	rmObjectiveAdd(302825, 302826, true, true, true); // General objective

	// ************************* TRIGGERS ******************************

	// Define Variables

	int nugget1 = rmGetUnitPlaced(SpawnerID1, 0);
	int nugget2 = rmGetUnitPlaced(SpawnerID2, 0);
	int nugget3 = rmGetUnitPlaced(SpawnerID3, 0);
	int nugget4 = rmGetUnitPlaced(SpawnerID4, 0);

	int socket1 = nugget1-1;
	int socket2 = nugget2-1;
	int socket3 = nugget3-1;
	int socket4 = nugget4-1;

	int center1 = nugget1-2;
	int center2 = nugget2-2;
	int center3 = nugget3-2;
	int center4 = nugget4-2;

	int workshopGlass = rmGetGroupingInstanceUnitByType(workshopBohemiaPlacement1, "zpSPCGlassWorks");
	int workshopBricks = rmGetGroupingInstanceUnitByType(workshopSaxonyPlacement1, "zpSPCBrickWorks");
	int workshopStone = rmGetGroupingInstanceUnitByType(workshopBavariaPlacement1, "zpSPCLimestoneWorks");
	int workshopCopper = rmGetGroupingInstanceUnitByType(workshopAustriaPlacement1, "zpSPCCopperWorks");

	int flag1 = rmGetGroupingInstanceUnitByType(workshopBohemiaPlacement1, "zpCityStateFlagTeam");
	int flag2 = rmGetGroupingInstanceUnitByType(workshopSaxonyPlacement1, "zpCityStateFlagTeam");
	int flag3 = rmGetGroupingInstanceUnitByType(workshopBavariaPlacement1, "zpCityStateFlagTeam");
	int flag4 = rmGetGroupingInstanceUnitByType(workshopAustriaPlacement1, "zpCityStateFlagTeam");

	int increment = 1;

	int workshopGlassMod = workshopGlass+increment;
	int workshopBricksMod = workshopBricks+increment;
	int workshopStoneMod = workshopStone+increment;
	int workshopCopperMod = workshopCopper+increment;

	int flag1Mod = flag1+increment;
	int flag2Mod = flag2+increment;
	int flag3Mod = flag3+increment;
	int flag4Mod = flag4+increment;

	// Vectors
	vector flagLoc1 = rmGetUnitPosition(flag1);
	vector flagLoc2 = rmGetUnitPosition(flag2);
	vector flagLoc3 = rmGetUnitPosition(flag3);
	vector flagLoc4 = rmGetUnitPosition(flag4);

	// Outpost sockets array
	int castleSockets = xsArrayCreateInt(4, -1, "Castle Sockets");
	xsArraySetInt(castleSockets, 0, socket1);
	xsArraySetInt(castleSockets, 1, socket2);
	xsArraySetInt(castleSockets, 2, socket3);
	xsArraySetInt(castleSockets, 3, socket4);

	int castleSocketID = -1;

	// Workshops array
	int workshopResource = xsArrayCreateInt(4, -1, "Workshop Resource");
	xsArraySetInt(workshopResource, 0, workshopGlass);
	xsArraySetInt(workshopResource, 1, workshopBricks);
	xsArraySetInt(workshopResource, 2, workshopStone);
	xsArraySetInt(workshopResource, 3, workshopCopper);

	int workshopResourceID = -1;

	// Flag array
	int workshopFlag = xsArrayCreateInt(4, -1, "Flag Workshop");
	xsArraySetInt(workshopFlag, 0, flag1);
	xsArraySetInt(workshopFlag, 1, flag2);
	xsArraySetInt(workshopFlag, 2, flag3);
	xsArraySetInt(workshopFlag, 3, flag4);

	int workshopFlagID = -1;

	// Center array
	int castleCenter = xsArrayCreateInt(4, -1, "Castle Center");
	xsArraySetInt(castleCenter, 0, center1);
	xsArraySetInt(castleCenter, 1, center2);
	xsArraySetInt(castleCenter, 2, center3);
	xsArraySetInt(castleCenter, 3, center4);

	int castleCenterID = -1;

	string guardianUnit = "zpNatLandsknecht";

	int sameTeam=-1;

	int victoryCountDown = 300;
	int socketMinimapFlareDuration = 8;

	// Triggers

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpCrownlandsSetup"); // All in One
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socket2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socket3);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socket4);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Conversion ON
	for (s=1; <=4) {
		castleSocketID = xsArrayGetInt(castleSockets, s-1);
		rmCreateTrigger("Socket"+s+" Convert ON");
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+castleSocketID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType",guardianUnit);
		rmSetTriggerConditionParamInt("Dist",25);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject", ""+castleSocketID, false);
		rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
		rmSetTriggerEffectParam("Suspend", "False", false);
		rmAddTriggerEffect("Flash Units");
		rmSetTriggerEffectParam("SrcObject", ""+castleSocketID, false);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Victory Conditions
	for(j = 0; < cNumberTeams){
		rmCreateTrigger("TeamVictory"+j);
		rmAddTriggerEffect("Team Victory");
        rmSetTriggerEffectParamInt("TeamID", j+1);
        rmSetTriggerPriority(4); 
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Cathedral Finished"+k);
		rmCreateTrigger("Revolution_MusicEnd"+k);

		rmSwitchToTrigger(rmTriggerID("Cathedral Finished"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpSPCCathedralStage4");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","VictoryCounter"+k);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg",""+rmGetPlayerName(k)+" monument Victory in"); // Get exact player name
		sameTeam=rmGetPlayerTeam(k);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+sameTeam));
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music","xpack\music\strategy\SomeOfAKind.mp3"); // Music Filename
		rmSetTriggerEffectParamFloat("Duration",0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","UI_Select_Building_Cathedral");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpRevealerToAll");
		rmSetTriggerEffectParamInt("Status",2);
		for (i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Revealer : Create");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("RevealerName","CathedralRevealer"+k+"_"+i);
			rmSetTriggerEffectParam("RevealerLoc", rmXFractionToMeters(rmPlayerLocXFraction(k))+",0,"+rmZFractionToMeters(rmPlayerLocZFraction(k)), false);
			rmSetTriggerEffectParamInt("RevealerLOS",15);

			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", i, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", rmXFractionToMeters(rmPlayerLocXFraction(k))+",0,"+rmZFractionToMeters(rmPlayerLocZFraction(k)), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}
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

	// 1/ Player lose when Rathaus defeated
		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Player Lose"+k);
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","deSPCCommandPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Set Player Defeated");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+k);
		rmSetTriggerPriority(2);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}
	// Native Politicians


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
		rmCreateTrigger("Activate Electors"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPrinceElectorElect"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPrinceElector"); //operator
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
		rmCreateTrigger("Activate Hussites"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpHussiteExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffHussites"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Electors"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Hussites"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Prince Elector Increments
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Elector Increase2"+k);
		rmCreateTrigger("Elector Increase3"+k);
		rmCreateTrigger("Elector Increase4"+k);

		rmCreateTrigger("Elector Decrease1"+k);
		rmCreateTrigger("Elector Decrease2"+k);
		rmCreateTrigger("Elector Decrease3"+k);

		rmSwitchToTrigger(rmTriggerID("Elector Increase2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase3"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Increase3"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase4"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Increase4"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",4);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease3"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Decrease3"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase4"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Decrease2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase3"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Decrease1"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	for (s=1; <=4) {
		castleSocketID = xsArrayGetInt(castleSockets, s-1);
		workshopResourceID = xsArrayGetInt(workshopResource, s-1);
		workshopFlagID = xsArrayGetInt(workshopFlag, s-1);
		castleCenterID = xsArrayGetInt(castleCenter, s-1);
			for (k=1; <= cNumberNonGaiaPlayers) {
				rmCreateTrigger("workshop"+s+" ON Player"+k);
				rmCreateTrigger("workshop"+s+" OFF Player"+k);

				rmSwitchToTrigger(rmTriggerID("workshop"+s+" ON Player"+k));
				rmAddTriggerCondition("Units in Area");
				rmSetTriggerConditionParam("DstObject",""+castleSocketID);
				rmSetTriggerConditionParamInt("Player",k);
				rmSetTriggerConditionParamInt("Dist",15);
				rmSetTriggerConditionParam("UnitType","TradingPost");
				rmSetTriggerConditionParam("Op",">=");
				rmSetTriggerConditionParamFloat("Count",1);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+workshopFlagID);
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+workshopResourceID);
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+castleCenterID);
				rmSetTriggerEffectParamInt("PlayerID",k);

				sameTeam = rmGetPlayerTeam(k);
				for(i=1; <= cNumberNonGaiaPlayers) {
					if (sameTeam == rmGetPlayerTeam(i)) {
						rmAddTriggerEffect("ZP Set Tech Status (XS)");
						rmSetTriggerEffectParamInt("PlayerID",i);
						if (s==1) {
							rmSetTriggerEffectParam("TechID","cTechzpGlassWorksTech"); //operator
						}
						else if (s==2) {
							rmSetTriggerEffectParam("TechID","cTechzpBrickWorksTech"); //operator
						}
						else if (s==3) {
							rmSetTriggerEffectParam("TechID","cTechzpStoneWorksTech"); //operator
						}
						else if (s==4) {
							rmSetTriggerEffectParam("TechID","cTechzpCopperWorksTech"); //operator
						}
						rmSetTriggerEffectParamInt("Status",2);

						rmAddTriggerEffect("Flare Minimap");
						rmSetTriggerEffectParamInt("PlayerID", i, false);
						rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
						if (s==1) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc1)+","+xsVectorGetY(flagLoc1)+","+xsVectorGetZ(flagLoc1), false);
						}
						if (s==2) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc2)+","+xsVectorGetY(flagLoc2)+","+xsVectorGetZ(flagLoc2), false);
						}
						if (s==3) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc3)+","+xsVectorGetY(flagLoc3)+","+xsVectorGetZ(flagLoc3), false);
						}
						if (s==4) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc4)+","+xsVectorGetY(flagLoc4)+","+xsVectorGetZ(flagLoc4), false);
						}
						rmSetTriggerEffectParam("Flash", "True", false);
					}
				}
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("workshop"+s+"_OFF_Player"+k));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);

				rmSwitchToTrigger(rmTriggerID("workshop"+s+" OFF Player"+k));
				rmAddTriggerCondition("Units in Area");
				rmSetTriggerConditionParam("DstObject",""+castleSocketID);
				rmSetTriggerConditionParamInt("Player",k);
				rmSetTriggerConditionParamInt("Dist",15);
				rmSetTriggerConditionParam("UnitType","TradingPost");
				rmSetTriggerConditionParam("Op","==");
				rmSetTriggerConditionParamFloat("Count",0);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+workshopFlagID);
				rmSetTriggerEffectParamInt("PlayerID",0);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+workshopResourceID);
				rmSetTriggerEffectParamInt("PlayerID",0);
				rmAddTriggerEffect("Convert");
				rmSetTriggerEffectParam("SrcObject",""+castleCenterID);
				rmSetTriggerEffectParamInt("PlayerID",0);

				sameTeam = rmGetPlayerTeam(k);
				for(i=0; <= cNumberNonGaiaPlayers) {
					if (sameTeam == rmGetPlayerTeam(i)) {
						rmAddTriggerEffect("ZP Set Tech Status (XS)");
						rmSetTriggerEffectParamInt("PlayerID",i);
						if (s==1) {
							rmSetTriggerEffectParam("TechID","cTechzpGlassWorksTechOFF"); //operator
						}
						else if (s==2) {
							rmSetTriggerEffectParam("TechID","cTechzpBrickWorksTechOFF"); //operator
						}
						else if (s==3) {
							rmSetTriggerEffectParam("TechID","cTechzpStoneWorksTechOFF"); //operator
						}
						else if (s==4) {
							rmSetTriggerEffectParam("TechID","cTechzpCopperWorksTechOFF"); //operator
						}
						rmSetTriggerEffectParamInt("Status",2);

						rmAddTriggerEffect("Flare Minimap");
						rmSetTriggerEffectParamInt("PlayerID", i, false);
						rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
						if (s==1) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc1)+","+xsVectorGetY(flagLoc1)+","+xsVectorGetZ(flagLoc1), false);
						}
						if (s==2) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc2)+","+xsVectorGetY(flagLoc2)+","+xsVectorGetZ(flagLoc2), false);
						}
						if (s==3) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc3)+","+xsVectorGetY(flagLoc3)+","+xsVectorGetZ(flagLoc3), false);
						}
						if (s==4) {
							rmSetTriggerEffectParam("Position", ""+xsVectorGetX(flagLoc4)+","+xsVectorGetY(flagLoc4)+","+xsVectorGetZ(flagLoc4), false);
						}
						rmSetTriggerEffectParam("Flash", "True", false);
					}
				}
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("workshop"+s+"_ON_Player"+k));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(false);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);

			}
		}

	// AI Hussite Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Hussite Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int hussiteLeader=-1;
	hussiteLeader = rmRandInt(1,3);

	if (hussiteLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesZizka"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesKing"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesReformer"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Elector Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Elector Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int electorLeader=-1;
	electorLeader = rmRandInt(1,5);

	if (electorLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHabsburg"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWittelsbach"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWettin"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==4)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHanover"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==5)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorOldenburg"); //operator
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
	rmSetStatusText("",0.99);
} // END