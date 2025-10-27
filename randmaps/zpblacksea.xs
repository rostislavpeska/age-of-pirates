// Black Sea
// October 2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;

string natives1 = "zpSultanate";
string natives2 = "zpOrthodox";
string natives3 = "zpCossacks";

string baseMix = "italy_grass";
string paintMix = "italy_grass_dry";
string paintMix2 = "italy_grass_medium_dry";
string paintMix3 = "italy_grass_medium";
string paintMix4 = "italy_cliff_top";
string paintMix5 = "italy_cliff_top_dry";
string paintMix6 = "italy_dirt";

string seaType1 = "ZP Black Sea Lagoon";
string seaType2 = "ZP Black Sea Water";

string forestType1 = "z42 Italian Forest";
string forestType2 = "East European Forest";

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

string fish1 = "FishSalmon";
string whale1 = "MinkeWhale";
string hunt1 = "Deer";
string hunt2 = "ypIbex";

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

	subCiv0=rmGetCivID(natives1);
	rmEchoInfo("subCiv0 is "+natives1+" "+subCiv0);
	if (subCiv0 >= 0)
		rmSetSubCiv(0, natives1);

	subCiv1=rmGetCivID(natives2);
	rmEchoInfo("subCiv1 is "+natives2+" "+subCiv1);
	if (subCiv1 >= 0)
		rmSetSubCiv(1, natives2);

	subCiv2=rmGetCivID(natives3);
	rmEchoInfo("subCiv2 is "+natives3+" "+subCiv2);
	if (subCiv2 >= 0)
		rmSetSubCiv(2, natives3);


	int size = 450;
	if (cNumberNonGaiaPlayers > 2){
		size = 530;
	}
	if (cNumberNonGaiaPlayers > 4){
		size = 580;
	}
	if (cNumberNonGaiaPlayers > 6){
		size = 640;
	}

	rmSetMapSize(size, size);


	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(1.0);
   
   	// LIGHT SET

	rmSetLightingSet("florida_Skirmish");


	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType(seaType1);
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	//rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
    //rmSetSeaType(seaType);
    rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("water");
    rmSetMapType("eastEurope");
    rmSetMapType("default");
	rmSetMapType("piratehistoricalmap");
	rmSetMapType("eurotradeRouteCapture");

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
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int longPlayerEdgeConstraint=rmCreatePieConstraint("player edge of map long", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.42), rmDegreesToRadians(0), rmDegreesToRadians(360));
	
	int avoidWaterMin = rmCreateTerrainDistanceConstraint("avoid water min", "Land", false, 2.0);
	int avoidWater7 = rmCreateTerrainDistanceConstraint("avoid water 7", "Land", false, 7.0);
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water extra long", "Land", false, 35.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	


	// Cardinal Directions
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(0), rmDegreesToRadians(180));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(180), rmDegreesToRadians(0));
	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(90), rmDegreesToRadians(270));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(270), rmDegreesToRadians(90));

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
	int avoidNuggetsShort=rmCreateTypeDistanceConstraint("nugget avoid nugget short", "abstractNugget", 30.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int ibexConstraint=rmCreateTypeDistanceConstraint("avoid the ibex", "ypIbex", 40.0);
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
	int avoidTradeRouteFar3 = rmCreateTradeRouteDistanceConstraint("trade route far 3", 20.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 12.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int avoidBridge = rmCreateTypeDistanceConstraint("avoid bridge", "zpRuinWallSmall", 10.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 1.0);
	int mediumGreatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes medium", classGreatLake, 8.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
	int avoidSocketMediumLong=rmCreateTypeDistanceConstraint("avoid socket medium long", "Socket", 30.0);
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
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "zpKingsHillNaval", 20.0);

    // Additional Constraints - based on dansil original constraints
    int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);
    int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.2, 0.0, 0.453, 1.0);
    int cityNorthConstraint = rmCreateBoxConstraint("stay in the city north", 0.557, 0.0, 0.8, 1.0);

    int classPatch = rmDefineClass("patch");
    int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 1.0);
	int avoidPlateau = rmCreateClassDistanceConstraint("avoid patch 2", rmClassID("classPlateau"), 10.0);
	int avoidPlateauLong = rmCreateClassDistanceConstraint("avoid patch 3", rmClassID("classPlateau"), 20.0);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	int avoidCenterPoint = rmCreateTypeDistanceConstraint("avoid center point", "zpSPCWaterSpawnPointB", 110.0);
    int avoidCenterPointLong = rmCreateTypeDistanceConstraint("avoid center point long", "zpSPCWaterSpawnPointB", 200.0);
	int avoidCenterPointUltraLong = rmCreateTypeDistanceConstraint("avoid center point ultra long", "zpSPCWaterSpawnPointB", 1.3 * mapRadius);

	int aztecCityConstraint = rmCreateBoxConstraint("stay in the aztec city", 0.5-rmXTilesToFraction(62), 0.5-rmZTilesToFraction(42), 0.5+rmXTilesToFraction(62), 0.5+rmZTilesToFraction(42));
	int aztecCityConstraint2 = rmCreateBoxConstraint("stay in the aztec city 2", 0.5-rmXTilesToFraction(42), 0.5-rmZTilesToFraction(62), 0.5+rmXTilesToFraction(42), 0.5+rmZTilesToFraction(62));

	int avoidCity = rmCreateTypeDistanceConstraint("avoid ccity", "AbstractWall", 7);
	int avoidCityShort = rmCreateTypeDistanceConstraint("avoid city short", "AbstractWall", 2);
	int avoidCityLong = rmCreateTypeDistanceConstraint("avoid city long", "AbstractWall", 20);
	
	int avoidBlock =rmCreateClassDistanceConstraint("stuff vs. blocks", rmClassID("classBlock"), 6.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);
	int avoidJesuit=rmCreateTypeDistanceConstraint("avoid Jesuit Cathedral", "zpJesuitCathedral", 30.0);
	
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 80.0);	//Attempting to spread them out more evenly.
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", "Bison", 60.0);
	int avoidLandFish = rmCreateTerrainDistanceConstraint("avoid land medium fish", "Water", false, 6.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
   	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ************** INVISIBLE TERRAIN LAYERS ************

	// Create invisible areas to place correctly Venice Grouping and future terrain

	int landMassID = rmCreateArea("land mass 1");
	if (PlayerNum == 2) {
		rmSetAreaSize(landMassID , rmAreaTilesToFraction(9000), rmAreaTilesToFraction(9000));
	}
	else {
		rmSetAreaSize(landMassID , rmAreaTilesToFraction(14000), rmAreaTilesToFraction(14000));
	}
    rmSetAreaLocation(landMassID , 0.15, 0.5);		
    rmSetAreaCoherence(landMassID , 1.0);
    rmSetAreaBaseHeight(landMassID, 2.0);
	rmSetAreaWarnFailure(landMassID, false);
    rmSetAreaMix(landMassID, "italy_grass");
    rmSetAreaElevationVariation(landMassID, 0.0);
	rmAddAreaInfluenceSegment(landMassID, 0.15, 0.9, 0.15, 0.1);
    rmBuildArea(landMassID ); 

	// Define lake area

	int lakeArea = rmCreateArea("lakeArea");
    rmSetAreaSize(lakeArea , 0.22, 0.22);
    rmSetAreaLocation(lakeArea , 0.5, 0.5);		
    rmSetAreaCoherence(lakeArea , 0.6);
	rmSetAreaMinBlobs(lakeArea, 8);
    rmSetAreaMaxBlobs(lakeArea, 12);
    rmSetAreaMinBlobDistance(lakeArea, 8.0);
    rmSetAreaMaxBlobDistance(lakeArea, 12.0);
    rmSetAreaElevationVariation(lakeArea, 0.0);
	rmAddAreaToClass(lakeArea, classGreatLake);
	if (rmGetIsKOTH())
		rmSetAreaReveal(lakeArea, 1);
    rmBuildArea(lakeArea);

	int bosporArea = rmCreateArea("bosporArea");
    rmSetAreaSize(bosporArea , rmAreaTilesToFraction(2000), rmAreaTilesToFraction(2000));
    rmSetAreaLocation(bosporArea , 0.5, 0.5);		
    rmSetAreaCoherence(bosporArea , 1.0);
    rmSetAreaElevationVariation(bosporArea, 0.0);
	rmAddAreaToClass(bosporArea, classGreatLake);
	rmSetAreaObeyWorldCircleConstraint(bosporArea, false);
	rmAddAreaInfluenceSegment(bosporArea, 0.0, 0.5, 0.25, 0.5);
	if (rmGetIsKOTH())
		rmSetAreaReveal(bosporArea, 1);
    rmBuildArea(bosporArea);

	int mediterraneanArea = rmCreateArea("mediterraneanArea");
    rmSetAreaSize(mediterraneanArea , 0.06, 0.06);
    rmSetAreaLocation(mediterraneanArea , 0.0, 0.5);		
    rmSetAreaCoherence(mediterraneanArea , 1.0);
    rmSetAreaElevationVariation(mediterraneanArea, 0.0);
	rmAddAreaToClass(mediterraneanArea, classGreatLake);
	rmSetAreaObeyWorldCircleConstraint(mediterraneanArea, false);
	if (rmGetIsKOTH())
		rmSetAreaReveal(mediterraneanArea, 1);
    rmBuildArea(mediterraneanArea);

	// ********************* Trade Route *******************************

    // Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

	int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);  
	if (cNumberNonGaiaPlayers == 2){
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.71);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.32);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.32, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
	}
	else{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.29, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.49, 0.29);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.29, 0.5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);
	}
    rmBuildTradeRoute(tradeRouteID, "water_trail");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);


	//  ************************** River ******************************

    // River must be defined before the islands are placed
	if (cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==4)
    	int riverID = rmRiverCreate(-1, seaType2, 4, 4, 72, 72); //  (-1, "new england lake", 18, 14, 5, 5)
	else if (cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==6)
    	riverID = rmRiverCreate(-1, seaType2, 4, 4, 75, 75); //  (-1, "new england lake", 18, 14, 5, 5)
	else if (cNumberNonGaiaPlayers >6)
    	riverID = rmRiverCreate(-1, seaType2, 4, 4, 105, 105); //  (-1, "new england lake", 18, 14, 5, 5)
	else
		riverID = rmRiverCreate(-1, seaType2, 4, 4, 40, 40); //  (-1, "new england lake", 18, 14, 5, 5)
	if (PlayerNum == 2) {
		rmRiverAddWaypoint(riverID, 0.15, 0.9);
		rmRiverAddWaypoint(riverID, 0.15, 0.1);
	}
	else {
		rmRiverAddWaypoint(riverID, 0.0, 0.5);
		rmRiverAddWaypoint(riverID, 0.5, 0.5);
	}
	rmRiverBuild(riverID);

	// *********************** ISTANBUL GROUPINGS ***************************

	// Define and place Ports

	int harbour01ID=rmCreateObjectDef("harbour");
	rmAddObjectDefItem(harbour01ID, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefAllowOverlap(harbour01ID, true);
	rmSetObjectDefMinDistance(harbour01ID, 0.0);
	rmSetObjectDefMaxDistance(harbour01ID, 0.0);
	rmSetObjectDefTradeRouteID(harbour01ID, tradeRouteID);
	if (PlayerNum == 2|| PlayerNum > 6)
		rmPlaceObjectDefAtLoc(harbour01ID, 0, 0.15-rmXTilesToFraction(0),0.5+rmXTilesToFraction(13));
	else
		rmPlaceObjectDefAtLoc(harbour01ID, 0, 0.15-rmXTilesToFraction(0),0.5+rmXTilesToFraction(10));
	vector harbourLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour01ID, 0));

	int harbour02ID=rmCreateObjectDef("harbour2");
	rmAddObjectDefItem(harbour02ID, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefAllowOverlap(harbour02ID, true);
	rmSetObjectDefMinDistance(harbour02ID, 0.0);
	rmSetObjectDefMaxDistance(harbour02ID, 0.0);
	rmSetObjectDefTradeRouteID(harbour02ID, tradeRouteID);
	if (PlayerNum == 2|| PlayerNum > 6)
		rmPlaceObjectDefAtLoc(harbour02ID, 0, 0.15+rmXTilesToFraction(15),0.5-rmXTilesToFraction(7));
	else
		rmPlaceObjectDefAtLoc(harbour02ID, 0, 0.15+rmXTilesToFraction(15),0.5-rmXTilesToFraction(10));
	vector harbourLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour02ID, 0));

	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour01ID, 0));
	vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour02ID, 0));

	// Place Istanbul Groupings

	rmSetNuggetDifficulty(512, 512);

	int istanbulEurope = rmCreateGrouping("istanbulEU", "Istanbul_EU");
	rmSetGroupingMinDistance(istanbulEurope, 0.00);
    rmSetGroupingMaxDistance(istanbulEurope, 0.01);
	rmAddGroupingToClass(istanbulEurope, rmClassID("classPlateau"));

	int istanbulInstanceID1 = rmPlaceGroupingInstanceAtLoc(istanbulEurope, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(8), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))+rmZTilesToFraction(15), 0);

	int istanbulAsia = rmCreateGrouping("istanbulAS", "Istanbul_AS");
	rmSetGroupingMinDistance(istanbulAsia, 0.00);
    rmSetGroupingMaxDistance(istanbulAsia, 0.01);
	rmAddGroupingToClass(istanbulAsia, rmClassID("classPlateau"));

	int istanbulInstanceID2 = rmPlaceGroupingInstanceAtLoc(istanbulAsia, rmXMetersToFraction(xsVectorGetX(ControllerLoc2))-rmXTilesToFraction(6), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2))-rmZTilesToFraction(16), 0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// **************** Create continents ****************

	// Create north continent
    int northContinentID = rmCreateArea("north_continent");
    rmSetAreaSize(northContinentID, 0.65, 0.65);
    rmSetAreaCoherence(northContinentID, 0.65);
    rmSetAreaMix(northContinentID, paintMix);
		rmAddAreaTerrainLayer(northContinentID, "carolinas\ground_shoreline2_car", 0, 1);
		rmAddAreaTerrainLayer(northContinentID, "carolinas\ground_shoreline3_car", 1, 2);
    rmSetAreaBaseHeight(northContinentID, 4);  // embassy structure height
    rmSetAreaHeightBlend(northContinentID, 2);
    rmSetAreaSmoothDistance(northContinentID, 50);
    rmSetAreaObeyWorldCircleConstraint(northContinentID, false);
	rmAddAreaConstraint(northContinentID, greatLakesConstraint);
	rmAddAreaConstraint(northContinentID, avoidTradeRouteFar3);
	rmAddAreaConstraint(northContinentID, avoidCity);
    rmSetAreaLocation(northContinentID, 0.9, 0.5);
    rmBuildArea(northContinentID);

	for (i=0; < 2){
		int patchID = rmCreateArea("patch "+i);
		rmSetAreaSize(patchID, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
		rmSetAreaCoherence(patchID, 1.0);
		rmSetAreaMix(patchID, paintMix);
		rmAddAreaConstraint(patchID, avoidCityShort);
		rmAddAreaConstraint(patchID, mediumGreatLakesConstraint);
		rmAddAreaConstraint(patchID, avoidTradeRouteFar3);
		if (i == 0){
			rmSetAreaLocation(patchID, 0.2, 0.5+rmZTilesToFraction(48));
			rmAddAreaInfluenceSegment(patchID, 0.15, 0.5+rmZTilesToFraction(48), 0.25, 0.5+rmZTilesToFraction(48));
		}
		else{
			rmSetAreaLocation(patchID, 0.2, 0.5-rmZTilesToFraction(49));
			rmAddAreaInfluenceSegment(patchID, 0.15, 0.5-rmZTilesToFraction(49), 0.25, 0.5-rmZTilesToFraction(49));
		}
		rmBuildArea(patchID);
	}

	// Create south elevated area  
    int terrainElevatedID = rmCreateArea("terrain_elevated");
    rmSetAreaSize(terrainElevatedID, 0.45, 0.45);
    rmSetAreaCoherence(terrainElevatedID, 0.35);
    rmSetAreaBaseHeight(terrainElevatedID, 4.8);
    rmAddAreaConstraint(terrainElevatedID, farGreatLakesConstraint);
    rmSetAreaElevationType(terrainElevatedID, cElevTurbulence);
	rmSetAreaElevationType(terrainElevatedID, cElevTurbulence);
	rmAddAreaConstraint(terrainElevatedID, avoidCityLong);
    rmSetAreaElevationVariation(terrainElevatedID, 6.0);
    rmSetAreaElevationPersistence(terrainElevatedID, 0.2);
    rmSetAreaElevationNoiseBias(terrainElevatedID, 1);
    rmSetAreaObeyWorldCircleConstraint(terrainElevatedID, false);
    
    rmSetAreaLocation(terrainElevatedID, 0.95, 0.5);
    rmAddAreaInfluencePoint(terrainElevatedID, 0.3, 0.90);
    rmAddAreaInfluencePoint(terrainElevatedID, 0.3, 0.10);

	rmBuildArea(terrainElevatedID);

	for (i=0; < 100+cNumberNonGaiaPlayers*50){
		int patchID2 = rmCreateArea("second patch"+i);
		rmSetAreaWarnFailure(patchID2, false);
		rmSetAreaSize(patchID2, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
		rmSetAreaMix(patchID2, baseMix);
		rmSetAreaSmoothDistance(patchID2, 1.0);
		rmAddAreaConstraint(patchID2, avoidCityLong);
		rmAddAreaConstraint(patchID2, avoidWater7);
		rmAddAreaConstraint(patchID2, Northward);
		rmBuildArea(patchID2); 
	}
	for (i=0; < 60+cNumberNonGaiaPlayers*30){
		int patchID3 = rmCreateArea("third patch"+i);
		rmSetAreaWarnFailure(patchID3, false);
		rmSetAreaSize(patchID3, rmAreaTilesToFraction(37), rmAreaTilesToFraction(42));
		rmSetAreaMix(patchID3, paintMix6);
		rmSetAreaSmoothDistance(patchID3, 1.0);
		rmAddAreaConstraint(patchID3, avoidCityLong);
		rmAddAreaConstraint(patchID3, avoidWater7);
		rmAddAreaConstraint(patchID3, Southward);
		rmBuildArea(patchID3); 
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// **************** ADD PORT SITES ****************

	for (i=0; < 3){
		int portSite = rmCreateArea ("port_site5"+i);
		rmSetAreaSize(portSite, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
		rmSetAreaMix(portSite, paintMix);
			rmAddAreaTerrainLayer(portSite, "carolinas\ground_shoreline2_car", 0, 1);
			rmAddAreaTerrainLayer(portSite, "carolinas\ground_shoreline3_car", 1, 2);
		rmSetAreaCoherence(portSite, 1);
		rmSetAreaHeightBlend(portSite, 2.0);
		rmSetAreaSmoothDistance(portSite, 15);
		rmSetAreaBaseHeight(portSite, 3.5);
		rmAddAreaToClass(portSite, classPortSite);

		int portSiteOverlay = rmCreateArea ("port_site_overlay"+i);
		if (PlayerNum == 2) {
			rmSetAreaSize(portSiteOverlay, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
		}
		else {
			rmSetAreaSize(portSiteOverlay, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
		}
		rmSetAreaCoherence(portSiteOverlay, 1);

		if (i == 0){
			rmSetAreaLocation(portSite, 0.5, 0.7+rmZTilesToFraction(22));
			rmSetAreaLocation(portSiteOverlay, 0.5, 0.7+rmZTilesToFraction(29));
			rmSetAreaMix(portSiteOverlay, paintMix);
		}
		else if (i == 1){
			rmSetAreaLocation(portSite, 0.7+rmZTilesToFraction(22), 0.5);
			rmSetAreaLocation(portSiteOverlay, 0.7+rmZTilesToFraction(29), 0.5);
			rmSetAreaMix(portSiteOverlay, baseMix);
		}
		else{
			rmSetAreaLocation(portSite, 0.5, 0.3-rmZTilesToFraction(22));
			rmSetAreaLocation(portSiteOverlay, 0.5, 0.3-rmZTilesToFraction(29));
			rmSetAreaMix(portSiteOverlay, paintMix);
		}

		rmBuildArea(portSite);
		rmBuildArea(portSiteOverlay);
	}

	int harbourID1=rmCreateObjectDef("sockets to dock Trade Posts1");
	rmSetObjectDefTradeRouteID(harbourID1, tradeRouteID);
	rmAddObjectDefItem(harbourID1, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(harbourID1, 0.0);
  	rmSetObjectDefMaxDistance(harbourID1, 0.5);

	int harbourID2=rmCreateObjectDef("sockets to dock Trade Posts2");
	rmSetObjectDefTradeRouteID(harbourID2, tradeRouteID);
	rmAddObjectDefItem(harbourID2, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(harbourID2, 0.0);
  	rmSetObjectDefMaxDistance(harbourID2, 0.5);

	int harbourID3=rmCreateObjectDef("sockets to dock Trade Posts3");
	rmSetObjectDefTradeRouteID(harbourID3, tradeRouteID);
	rmAddObjectDefItem(harbourID3, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(harbourID3, 0.0);
  	rmSetObjectDefMaxDistance(harbourID3, 0.5);

	int nuggetID1=rmCreateObjectDef("nuggets to dock Trade Posts1");
	rmSetObjectDefTradeRouteID(nuggetID1, tradeRouteID);
	rmAddObjectDefItem(nuggetID1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID1, 4.0);
  	rmSetObjectDefMaxDistance(nuggetID1, 6.0);

	int nuggetID2=rmCreateObjectDef("nuggets to dock Trade Posts2");
	rmSetObjectDefTradeRouteID(nuggetID2, tradeRouteID);
	rmAddObjectDefItem(nuggetID2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID2, 4.0);
  	rmSetObjectDefMaxDistance(nuggetID2, 6.0);

	int nuggetID3=rmCreateObjectDef("nuggets to dock Trade Posts3");
	rmSetObjectDefTradeRouteID(nuggetID3, tradeRouteID);
	rmAddObjectDefItem(nuggetID3, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID3, 4.0);
  	rmSetObjectDefMaxDistance(nuggetID3, 6.0);

	rmSetNuggetDifficulty(511, 511);

	rmPlaceObjectDefAtLoc(harbourID1, 0, 0.5, 0.7+rmZTilesToFraction(18));
	rmPlaceObjectDefAtLoc(harbourID2, 0, 0.7+rmZTilesToFraction(18), 0.5);
	rmPlaceObjectDefAtLoc(harbourID3, 0, 0.5, 0.3-rmZTilesToFraction(18));
	rmPlaceObjectDefAtLoc(nuggetID1, 0, 0.5, 0.7+rmZTilesToFraction(18));
	rmPlaceObjectDefAtLoc(nuggetID2, 0, 0.7+rmZTilesToFraction(18), 0.5);
	rmPlaceObjectDefAtLoc(nuggetID3, 0, 0.5, 0.3-rmZTilesToFraction(18));

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// **************** PLACE NATIVES ****************
	int nativeCount = 4;
	int placementOrder = rmRandInt(1, 2);
	int orthodoxMonastery1Type = rmRandInt(4, 6);
	int orthodoxMonastery2Type = rmRandInt(1, 3);
	int cossackCamp1Type = rmRandInt(1, 5);
	int cossackCamp2Type = rmRandInt(1, 5);

	for (i=0; < nativeCount){
		int NativeControllerID = rmCreateObjectDef("Native controller "+i);
		rmAddObjectDefItem(NativeControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(NativeControllerID, 0.0);

		if(PlayerNum == 2){
			if (i == 0)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.39, 0.92);
			else if (i == 1)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.39, 0.08);
			else if (i == 2)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.85, 0.25);
			else
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.85, 0.75);
		}
		else{
			if (i == 0)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.39, 0.92);
			else if (i == 1)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.39, 0.08);
			else if (i == 2)
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.87, 0.25);
			else
				rmPlaceObjectDefAtLoc(NativeControllerID, 0, 0.87, 0.75);
		}

		vector NativeControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(NativeControllerID, 0));

		int nativeVillage1 = rmCreateArea ("native village "+i);
		rmSetAreaSize(nativeVillage1, rmAreaTilesToFraction(750.0), rmAreaTilesToFraction(750.0));
		rmSetAreaLocation(nativeVillage1, rmXMetersToFraction(xsVectorGetX(NativeControllerLoc)), rmZMetersToFraction(xsVectorGetZ(NativeControllerLoc)));
		rmSetAreaCoherence(nativeVillage1, 0.7);
		rmSetAreaCliffPainting(nativeVillage1, false, true, true, 1.5, true);
		rmSetAreaObeyWorldCircleConstraint(nativeVillage1, false);
		rmSetAreaSmoothDistance(nativeVillage1, 3.5);
		rmSetAreaBaseHeight(nativeVillage1, 6.0);
		if (i == 3 || i == 2){
			rmSetAreaCliffType(nativeVillage1, "Italian Cliff Grassy");
		}
		else{
			rmSetAreaCliffType(nativeVillage1, "Italian Cliff");
		}
		rmSetAreaCliffEdge(nativeVillage1, 1, 1.00, 0.0, 0.0, 2); 
		rmSetAreaCliffHeight(nativeVillage1, 2.0, 0.0, 0.5); 
		rmSetAreaElevationVariation(nativeVillage1, 0.0);
		if (PlayerNum == 2){
			rmAddAreaConstraint(nativeVillage1, avoidWater20);
		}
		else{
			rmAddAreaConstraint(nativeVillage1, avoidWater40);
		}
		rmAddAreaToClass(nativeVillage1, rmClassID("classPlateau"));
		rmBuildArea(nativeVillage1);

		int nativeCampID = -1;
		if (i == 0){
			if (placementOrder == 1){
				nativeCampID = rmCreateGrouping("native camp"+i, "Orthodox_Monastery0" + orthodoxMonastery1Type);
			}
			else{
				nativeCampID = rmCreateGrouping("native camp"+i, "Cossack_Camp_0"+cossackCamp1Type);
			}
		}
		else if (i == 1){
			if (placementOrder == 2){
				nativeCampID = rmCreateGrouping("native camp"+i, "Orthodox_Monastery0" + orthodoxMonastery1Type);
			}
			else{
				nativeCampID = rmCreateGrouping("native camp"+i, "Cossack_Camp_0"+cossackCamp1Type);
			}
		}
		else if (i == 2){
			if (placementOrder == 1){
				nativeCampID = rmCreateGrouping("native camp"+i, "Orthodox_Monastery0" + orthodoxMonastery2Type);
			}
			else{
				nativeCampID = rmCreateGrouping("native camp"+i, "Cossack_Camp_0"+cossackCamp2Type);
			}
		}
		else{
			if (placementOrder == 2){
				nativeCampID = rmCreateGrouping("native camp"+i, "Orthodox_Monastery0" + orthodoxMonastery2Type);
			}
			else{
				nativeCampID = rmCreateGrouping("native camp"+i, "Cossack_Camp_0"+cossackCamp2Type);
			}
		}
		rmPlaceGroupingAtLoc(nativeCampID, 0, rmXMetersToFraction(xsVectorGetX(NativeControllerLoc)), rmZMetersToFraction(xsVectorGetZ(NativeControllerLoc)), 1);

	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	//*************** PLACE PLAYERS ****************

	// Define Teams and map variations
    int teamZeroCount = rmGetNumberPlayersOnTeam(0);
    int teamOneCount = rmGetNumberPlayersOnTeam(1);
	float teamStartLoc = rmRandFloat(0.0, 1.0);

	if (PlayerNum == 2){
		if (teamStartLoc > 0.5)
		{
			rmPlacePlayer(1, 0.37, 0.8);
			rmPlacePlayer(2, 0.37, 0.2);
		}
		else
		{
			rmPlacePlayer(1, 0.37, 0.2);
			rmPlacePlayer(2, 0.37, 0.8);
		}
	}
	else{
		if (TeamNum == 2 && teamZeroCount == teamOneCount){
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.888, 0.070);
				rmPlacePlayersCircular(0.34, 0.36, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.430, 0.612);
				rmPlacePlayersCircular(0.34, 0.36, 0);
			}
			else
			{
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.888, 0.070);
				rmPlacePlayersCircular(0.34, 0.36, 0);
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.430, 0.612);
				rmPlacePlayersCircular(0.34, 0.36, 0);
			}

		}
		else{
			rmSetPlacementSection(0.888, 0.612);  
			rmPlacePlayersCircular(0.34, 0.36, 0);
		}
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
	rmSetObjectDefMaxDistance(TCID, 30);
	if (cNumberNonGaiaPlayers <= 6) {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	else {
		rmSetObjectDefMaxDistance(TCID, 20);
	}
	rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, avoidPlateau);
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, farAvoidTradeSockets);
	rmAddObjectDefConstraint(TCID, avoidWater20);

    int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
	rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
	rmAddObjectDefConstraint(startingUnits, farAvoidTradeSockets);

	int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "MineCopper", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerMineID, farAvoidTradeSockets);

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "ypIbex", rmRandInt(7,10), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 15.0);
	rmSetObjectDefMaxDistance(playerDeerID, 30.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);
	rmAddObjectDefConstraint(playerDeerID, farAvoidTradeSockets);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetID, 15.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 18.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerNuggetID, farAvoidTradeSockets);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "treeGreatlakes", 10, 12.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 15.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 25.0);
	rmAddObjectDefConstraint(StartAreaTreeID, farAvoidTradeSockets);

	int berryID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID, 16.0);
	rmSetObjectDefMaxDistance(berryID, 17.0);
	rmAddObjectDefConstraint(berryID, avoidAll);
	rmAddObjectDefConstraint(berryID, avoidImpassableLand);
	rmAddObjectDefConstraint(berryID, farAvoidTradeSockets);


	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);

	for(i=1; <cNumberPlayers) {

		rmSetNuggetDifficulty(1, 1);

		// Place town centers
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		// Place resources
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(berryID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place starting nugget
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		int waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 0.0);

		int mapX = 300;
		int mapZ = 300;
		int centerX = mapX / 2;
		int centerZ = mapZ / 2;
		int playerX = rmPlayerLocXFraction(i) * mapX;
		int playerZ = rmPlayerLocZFraction(i) * mapZ;

		vector centerPos = xsVectorSet(centerX, 0, centerZ);
		vector playerPos = xsVectorSet(playerX, 0, playerZ);
		vector playerToCenter = xsVectorNormalize(centerPos - playerPos);
		if (PlayerNum == 3 || PlayerNum == 5 || PlayerNum == 7 || PlayerNum == 6 || PlayerNum == 8)
			int distance = 50; // 10 meters. Increase until everything works.
		else
			distance = 40; // 10 meters. Increase until everything works.
		vector flagPos = playerPos + playerToCenter * distance;
		float flagX = xsVectorGetX(flagPos);
		float flagZ = xsVectorGetZ(flagPos);

		// Convert meters to fraction:
		flagX = flagX / mapX;
		flagZ = flagZ / mapZ;

		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, flagX, flagZ);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	//**************************** Kongs's Castle ***********************************

   if (rmGetIsKOTH()){
      int kotHID2 = rmCreateGrouping("koth castle", "Caribbean_Naval_KotH");
      rmSetGroupingMinDistance(kotHID2, 0.00);
      rmSetGroupingMaxDistance(kotHID2, 0.01);
      rmAddGroupingToClass(kotHID2, rmClassID("classPlateau"));
      //rmPlaceGroupingAtLoc(kotHID2, 0, 0.5, 0.5, 1);

      int kotHInstance = rmPlaceGroupingInstanceAtLoc(kotHID2,  0.5, 0.5, 0);
   }
	

	// **************** PLACE RESOURCES ****************

	// Random Gold
	for(i=0; <2){
		int randomGoldID = rmCreateObjectDef("random mine"+i);
		rmAddObjectDefItem(randomGoldID, "MineCopper", 1, 0.0);
		rmSetObjectDefMinDistance(randomGoldID, 0.0);
		rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(randomGoldID, avoidCoin);
		rmAddObjectDefConstraint(randomGoldID, avoidAll);
		rmAddObjectDefConstraint(randomGoldID, avoidTownCenterFar);
		rmAddObjectDefConstraint(randomGoldID, avoidSocketLong);
		rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
		rmAddObjectDefConstraint(randomGoldID, avoidWater20);
		rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
		if (i == 0)
			rmAddObjectDefConstraint(randomGoldID, Eastward);
		else
			rmAddObjectDefConstraint(randomGoldID, Westward);
		rmPlaceObjectDefAtLoc(randomGoldID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
	}


	// Forests

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=42;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 56;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 70;
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, forestType2);
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(northForest, shortAvoidCoin);
		rmAddAreaConstraint(northForest, avoidTownCenterFar);
		rmAddAreaConstraint(northForest, avoidSocketMediumLong);
		rmAddAreaConstraint(northForest, avoidWater10);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, Northward);			// DAL adeed, to keep forests in the north.
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

	
	numTries=42;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 56;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 70;
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		rmSetAreaForestType(southForest, forestType1);
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(southForest, shortAvoidCoin);
		rmAddAreaConstraint(southForest, avoidTownCenterFar);
		rmAddAreaConstraint(southForest, avoidSocketMediumLong);
		rmAddAreaConstraint(southForest, avoidWater10);
		rmAddAreaConstraint(southForest, forestConstraint);   // DAL added, to keep forests away from each other.
		rmAddAreaConstraint(southForest, Southward);	
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

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);
	

	// Scattered BERRRIES	
	for(i=0; <2){
		int berriesID=rmCreateObjectDef("random berries"+i);
		rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
		rmSetObjectDefMinDistance(berriesID, 0.0);
		rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(berriesID, avoidTownCenter);
		rmAddObjectDefConstraint(berriesID, avoidAll);
		rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
		rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
		rmAddObjectDefConstraint(berriesID, avoidWater10);
		if (i == 0)
			rmAddObjectDefConstraint(berriesID, Eastward);
		else
			rmAddObjectDefConstraint(berriesID, Westward);
		rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
	}

	int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, "Deer", rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidAll);
	rmAddObjectDefConstraint(food1ID, avoidTownCenter);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, deerConstraint);
	rmAddObjectDefConstraint(food1ID, playerEdgeConstraint);
    rmAddObjectDefConstraint(food1ID, avoidWater10);
	rmAddObjectDefConstraint(food1ID, Northward);

	int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, "ypIbex", rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidAll);
	rmAddObjectDefConstraint(food2ID, avoidTownCenter);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, playerEdgeConstraint);
	rmAddObjectDefConstraint(food2ID, ibexConstraint);
    rmAddObjectDefConstraint(food2ID, avoidWater10);
	rmAddObjectDefConstraint(food2ID, Southward);

	rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);
	rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

	// Nuggets

	for(i=0; <2){
		int nuggetHard= rmCreateObjectDef("nugget hard"+i); 
		rmAddObjectDefItem(nuggetHard, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(3, 4);
		rmAddObjectDefConstraint(nuggetHard, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(nuggetHard, avoidAll);
		rmAddObjectDefConstraint(nuggetHard, avoidNuggets);
		rmAddObjectDefConstraint(nuggetHard, avoidTownCenterFar);
		rmAddObjectDefConstraint(nuggetHard, playerEdgeConstraint);
		rmAddObjectDefConstraint(nuggetHard, avoidWater40);
		rmAddObjectDefConstraint(nuggetHard, avoidBlockLong);
		if (i == 0)
			rmAddObjectDefConstraint(nuggetHard, Eastward);
		else
			rmAddObjectDefConstraint(nuggetHard, Westward);
		rmSetObjectDefMinDistance(nuggetHard, 0.0);
		rmSetObjectDefMaxDistance(nuggetHard, rmXFractionToMeters(0.45));
		rmPlaceObjectDefAtLoc(nuggetHard, 0, 0.5, 0.5, 1+cNumberNonGaiaPlayers/2);

		int nuggetEasy= rmCreateObjectDef("nugget easy"+i); 
		rmAddObjectDefItem(nuggetEasy, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(1, 2);
		rmAddObjectDefConstraint(nuggetEasy, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(nuggetEasy, avoidNuggets);
		rmAddObjectDefConstraint(nuggetEasy, avoidAll);
		rmAddObjectDefConstraint(nuggetEasy, avoidTownCenter);
		rmAddObjectDefConstraint(nuggetEasy, playerEdgeConstraint);
		rmAddObjectDefConstraint(nuggetEasy, avoidWater10);
		rmAddObjectDefConstraint(nuggetEasy, avoidBlockLong);
		if (i == 0)
			rmAddObjectDefConstraint(nuggetEasy, Eastward);
		else
			rmAddObjectDefConstraint(nuggetEasy, Westward);
		rmSetObjectDefMinDistance(nuggetEasy, 0.0);
		rmSetObjectDefMaxDistance(nuggetEasy, rmXFractionToMeters(0.45));
		rmPlaceObjectDefAtLoc(nuggetEasy, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);
	}

	// Fishes

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, avoidLandFish);
	rmAddObjectDefConstraint(fishID, avoidPlateauShort);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 60+cNumberNonGaiaPlayers+25);


	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmAddObjectDefConstraint(whaleID, avoidKOTH);
	rmAddObjectDefConstraint(whaleID, playerEdgeConstraint);
	rmAddObjectDefConstraint(whaleID, avoidPlateauLong);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.90);

	// ____________________ LOCAL MERCENARIES ____________________
    rmDisableDefaultMercs(true);
    rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("deMercZenata", -1);
	rmEnableMerc("deMercPandour", -1);
    rmEnableMerc("MercGreatCannon", -1);
	rmEnableMerc("deSaloonCrabat", -1);
	rmEnableMerc("deSaloonHajduk", -1);

	// ____________________ MAP OBJECTIVES ____________________
    if (rmGetIsKOTH()){
		rmObjectiveScreenSetTitle(3303265);
		rmObjectiveScreenSetGoal(303264);
		rmObjectiveAdd(302236, 302232, true, true, true);
	}

	// ****************** TRIGGERS ******************

	// Define Variables

	int varIncrement = 1;
	if (PlayerNum == 2)
		varIncrement = 0;

	int loneHarbourID1 = rmGetUnitPlaced(harbourID1, 0)+varIncrement;
	int loneHarbourID2 = rmGetUnitPlaced(harbourID2, 0)+varIncrement;
	int loneHarbourID3 = rmGetUnitPlaced(harbourID3, 0)+varIncrement;

	int loneHarbourNuggetID1 = rmGetUnitPlaced(nuggetID1, 0)+varIncrement;
	int loneHarbourNuggetID2 = rmGetUnitPlaced(nuggetID2, 0)+varIncrement;
	int loneHarbourNuggetID3 = rmGetUnitPlaced(nuggetID3, 0)+varIncrement;
	
	int sultanateSocket1 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "zpSPCSocketSultanateCityState")+varIncrement;
	int sultanateSocket2 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "zpSPCSocketSultanateCityState")+varIncrement;

	int sultanateCenter1 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "zpCinematicRevealer")+varIncrement;
	int sultanateCenter2 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "zpCinematicRevealer")+varIncrement;

	int sultanateMosque1 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "zpSPCIstanbulMosque")+varIncrement;
	int sultanateMosque2 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "zpSPCIstanbulMosque")+varIncrement;

	int sultanateDock1 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "zpSPCPirateDock")+varIncrement;
	int sultanateDock2 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "zpSPCPirateDock")+varIncrement;

	int sultanateTower11 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "deSPCSocketCityTower")+varIncrement;
	int sultanateTower12 = rmGetGroupingInstanceUnitByType(istanbulInstanceID1, "zpSPCSocketCityTowerClone")+varIncrement;
	int sultanateTower21 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "deSPCSocketCityTower")+varIncrement;
	int sultanateTower22 = rmGetGroupingInstanceUnitByType(istanbulInstanceID2, "zpSPCSocketCityTowerClone")+varIncrement;

	int kothCastle = rmGetGroupingInstanceUnitByType(kotHInstance, "zpKingsHillNaval");
	vector kothLoc = rmGetUnitPosition(kothCastle);

	int kothCastleMod = kothCastle+varIncrement;

	int socketMinimapFlareDuration = 10;
	int victoryCountDown = 600;

	// Arrays

	// Sultanate Socket Array
	int sultanateSockets = xsArrayCreateInt(2, -1, "Sultanate Sockets");
	xsArraySetInt(sultanateSockets, 0, sultanateSocket1);
	xsArraySetInt(sultanateSockets, 1, sultanateSocket2);

	int sultanateSocketID = -1;

	// Sultanate Center Array
	int sultanateCenters = xsArrayCreateInt(2, -1, "Sultanate Centers");
	xsArraySetInt(sultanateCenters, 0, sultanateCenter1);
	xsArraySetInt(sultanateCenters, 1, sultanateCenter2);

	int sultanateCenterID = -1;

	// Sultanate Mosque Array
	int sultanateMosques = xsArrayCreateInt(2, -1, "Sultanate Mosques");
	xsArraySetInt(sultanateMosques, 0, sultanateMosque1);
	xsArraySetInt(sultanateMosques, 1, sultanateMosque2);

	int sultanateMosqueID = -1;

	// Sultanate Dock Array
	int sultanateDocks = xsArrayCreateInt(2, -1, "Sultanate Docks");
	xsArraySetInt(sultanateDocks, 0, sultanateDock1);
	xsArraySetInt(sultanateDocks, 1, sultanateDock2);

	int sultanateDockID = -1;

	// Sultanate Tower Array
	int sultanateTowers = xsArrayCreateInt(2, -1, "Sultanate Towers");
	xsArraySetInt(sultanateTowers, 0, sultanateTower11);
	xsArraySetInt(sultanateTowers, 1, sultanateTower12);
	xsArraySetInt(sultanateTowers, 2, sultanateTower21);
	xsArraySetInt(sultanateTowers, 3, sultanateTower22);

	// Strings

	string guardianUnit = "zpNatJanissary";

	// ====== DEFINE TRIGGERS ====== //

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpEnableIstanbulCityTechs"); // All in One
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);
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
		rmSetTriggerEffectParam("TechID","cTechzpSPCVeniceCityStatesAI"); // Only for the AI to train the city state units from sockets
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID3);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+sultanateSocket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+sultanateSocket2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 1 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+sultanateSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+sultanateSocket1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+sultanateSocket1, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Socket 2 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+sultanateSocket2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+sultanateSocket2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+sultanateSocket2, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Harbour 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 3 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID3);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID3, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// **************** KotH Victory ************************

	if (rmGetIsKOTH()){
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("ConvertKotH_Player"+k);
	}

	rmSwitchToTrigger(rmTriggerID("Revolution_MusicEnd"+i));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",5);
	rmAddTriggerEffect("Music Play");
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	// KotH Conversion
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("ConvertKotH_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+kothCastleMod);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("UnitType","AbstractWarShip");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	for (i=1; <= cNumberNonGaiaPlayers) {
		if (i != k){
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+kothCastleMod);
			rmSetTriggerConditionParamInt("Player",i);
			rmSetTriggerConditionParamInt("Dist",25);
			rmSetTriggerConditionParam("UnitType","AbstractWarShip");
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamFloat("Count",0);
		}
	}
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+kothCastleMod);
	rmSetTriggerEffectParamInt("PlayerID",k);
	for (i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+kothCastleMod);
		rmSetTriggerEffectParamInt("SrcPlayer",i);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",15);
	}
	for (i=1; <= cNumberNonGaiaPlayers) {
		if (i != k){
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("ConvertKotH_Player"+i));
		}
	}
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","SheepFound");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for(i = 1; < cNumberTeams+1) {
	rmCreateTrigger("TeamVictory"+i);
	rmCreateTrigger("KotH_ON"+i);
	}
	for(i = 1; < cNumberTeams+1) {

	// Team Victory 
	rmSwitchToTrigger(rmTriggerID("TeamVictory"+i));
	rmAddTriggerEffect("Team Victory");
	rmSetTriggerEffectParamInt("TeamID", i);
	rmSetTriggerPriority(4); 
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Team KotH Ownership
	rmSwitchToTrigger(rmTriggerID("KotH_ON"+i));
	rmAddTriggerCondition("Team Unit Count");
	rmSetTriggerConditionParamInt("TeamID",i);
	rmSetTriggerConditionParam("Protounit","zpKingsHillNaval");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	for(x=1; <= cNumberNonGaiaPlayers) {
		if (rmGetPlayerTeam(x) == i-1) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(kothLoc)+","+xsVectorGetY(kothLoc)+","+xsVectorGetZ(kothLoc), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}
	}
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VictoryCounter"+i);
	rmSetTriggerEffectParamInt("Start", victoryCountDown);
	rmSetTriggerEffectParamInt("Stop",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",1);
	rmSetTriggerEffectParam("TechID","cTechzpKingOfTheSeasShadow"); // Europen Map
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Koth.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+i));
	rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
	if (i==1)
		rmSetTriggerEffectParam("Msg","{302234}"); // Counter Revolutionaries
	else
		rmSetTriggerEffectParam("Msg","{302235}"); // Counter Revolutionaries
	rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+i));

	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+kothCastleMod, false);
	if (i==1){
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter2");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("KotH_ON2"));
	}
	else{
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter1");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("KotH_ON1"));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}
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
		rmCreateTrigger("Activate Sultanate"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpSultanateExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffSultanate"); //operator
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
		rmCreateTrigger("Activate Orthodox"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpOrthodoxInfluence"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffOrthodoxBalkan"); //operator
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
		rmCreateTrigger("Activate Cossacks"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpCossackExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffCossacks"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Sultanate"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Orthodox"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Cossacks"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Update TR Plr"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpSultanateTradeRouteUpgrade");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Sultanate Pop Increments
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Sultanate Increase2"+k);
		rmCreateTrigger("Sultanate Decrease1"+k);

		rmSwitchToTrigger(rmTriggerID("Sultanate_Increase2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCinematicRevealer");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSultanateSiteIncrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Sultanate_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Sultanate_Decrease1"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpCinematicRevealer");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSultanateSiteDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Sultanate_Increase2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Specific for AI

	// AI Builds Pirate City States from Sockets
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("BuildTower11_ON_Plr"+k);
		rmCreateTrigger("BuildTower11_OFF_Plr"+k);
		rmCreateTrigger("BuildTower12_ON_Plr"+k);
		rmCreateTrigger("BuildTower12_OFF_Plr"+k);
		rmCreateTrigger("BuildTower21_ON_Plr"+k);
		rmCreateTrigger("BuildTower21_OFF_Plr"+k);
		rmCreateTrigger("BuildTower22_ON_Plr"+k);
		rmCreateTrigger("BuildTower22_OFF_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("BuildTower11_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+sultanateTower11);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+sultanateTower11);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower11_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower12_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+sultanateTower12);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+sultanateTower12);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower12_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower21_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+sultanateTower21);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+sultanateTower21);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower21_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower22_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+sultanateTower22);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+sultanateTower22);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower22_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("AI_Check1_Plr"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("AI_Check2_Plr"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}


	// Convert Sultanate Settlements
	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Sultanate"+s+"ON Plr"+k);
			rmCreateTrigger("Sultanate"+s+"OFF Plr"+k);
			rmCreateTrigger("Sultanate"+s+"OFF Delayed Plr"+k);

			sultanateSocketID = xsArrayGetInt(sultanateSockets, s-1);
			sultanateCenterID = xsArrayGetInt(sultanateCenters, s-1);
			sultanateMosqueID = xsArrayGetInt(sultanateMosques, s-1);
			sultanateDockID = xsArrayGetInt(sultanateDocks, s-1);
			rmSwitchToTrigger(rmTriggerID("Sultanate"+s+"ON_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+sultanateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateMosqueID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateDockID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNavalOriental");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpIndianFortCornerProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallMediumProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallSmallProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallLargeProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Sultanate"+s+"OFF_Plr"+k));
			if (s == 1){
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check1_Plr"+k));
			}
			else{
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check2_Plr"+k));
			}
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Sultanate"+s+"OFF_Plr"+k));			
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+sultanateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamInt("Count",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateDockID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNavalOriental");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpIndianFortCornerProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallMediumProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallSmallProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpIndianFortWallLargeProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+sultanateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Sultanate"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Sultanate"+s+"OFF_Delayed_Plr"+k));
			if (s == 1){
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
			}
			else{
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
			}
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpLockIstanbul"); // Island Techs
			rmSetTriggerEffectParamInt("Status",2);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);


			rmSwitchToTrigger(rmTriggerID("Sultanate"+s+"OFF_Delayed_Plr"+k));	
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1", 1000, false);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+sultanateMosqueID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpUnlockIstanbul"); // Island Techs
			rmSetTriggerEffectParamInt("Status",2);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
	}

	// Blockade
	for(i = 1; < cNumberTeams+1){
    
		rmCreateTrigger("Blockade_ON"+i);
		rmCreateTrigger("Blockade_OFF"+i);

		rmSwitchToTrigger(rmTriggerID("Blockade_ON"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpSPCIstanbulMosque");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",2);
		for(k=1; <= cNumberNonGaiaPlayers) {
			if (rmGetPlayerTeam(k) == i-1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpSPCBosporBlockadeShadow"); // Island Techs
				rmSetTriggerEffectParamInt("Status",2);
			}
		}
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockade_OFF"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Blockade_OFF"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpSPCIstanbulMosque");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",1);
		for(k=1; <= cNumberNonGaiaPlayers) {
			if (rmGetPlayerTeam(k) == i-1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpSPCBosporBlockadeShadow"); // Island Techs
				rmSetTriggerEffectParamInt("Status",0);
			}
		}
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockade_ON"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}


	// AI Sultanate Leaders

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
		rmSetTriggerConditionParam("TechID","cTechzpNativeSultanate");
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
		rmSetTriggerConditionParam("TechID","cTechzpNativeSultanate");
		rmSetTriggerConditionParamInt("Status",2);

		int revFraction=-1;
		revFraction = rmRandInt(1,3);

		if (revFraction==1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateSultanatePhanar"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateSultanateSufi"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateSultanateCorsairs"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
	}

	// AI Cossack Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Cossack Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int cossackLeader=-1;
	cossackLeader = rmRandInt(1,3);

	if (cossackLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateCossackBohdan"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (cossackLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateCossackMazepa"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (cossackLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateCossackPetro"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Orthodox Captains

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Orthodox Captain"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int orthodoxCaptain=-1;
	orthodoxCaptain = rmRandInt(1,3);

	if (orthodoxCaptain==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxGeorgians"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (orthodoxCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxBulgarians"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (orthodoxCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxConstantinopole"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

} // END