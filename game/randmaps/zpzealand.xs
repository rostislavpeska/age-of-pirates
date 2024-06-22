
// New Zealand
// 06/2024

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

// Text
rmSetStatusText("",0.01);

int subCiv0=-1;
int subCiv1=-1;
int nativeVariant = rmRandInt(1,2);

if (nativeVariant == 1)
	{
		subCiv0=rmGetCivID("natpirates");
		rmEchoInfo("subCiv0 is natpirates "+subCiv0);
		if (subCiv0 >= 0)
				rmSetSubCiv(0, "natpirates");

	}

	if (nativeVariant == 2)
	{
		subCiv0=rmGetCivID("zpScientists");
		rmEchoInfo("subCiv0 is zpScientists "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpScientists");

	}

subCiv1=rmGetCivID("maorinatives");
rmEchoInfo("subCiv1 is maorinatives "+subCiv1);
if (subCiv1 >= 0)
	rmSetSubCiv(1, "maorinatives");

	
// Set size.
int playerTiles=23000;
	if (cNumberNonGaiaPlayers ==4)
		playerTiles = 22000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 17500;
	if (cNumberNonGaiaPlayers >7)
		playerTiles = 15000;			
int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
rmEchoInfo("Map size="+size+"m x "+size+"m");
rmSetMapSize(size, size);

// Set up default water.
rmSetSeaLevel(2.0);
rmSetSeaType("zp new zealand coast");
rmSetBaseTerrainMix("caribbeanSkirmish");
rmSetMapType("newzealand");
rmSetMapType("grass");
rmSetMapType("water");
rmSetLightingSet("rm_afri_atlas");
rmSetOceanReveal(true);

// Init map.
rmTerrainInitialize("water");

// Define some classes.
int classPlayer=rmDefineClass("player");
int classIsland=rmDefineClass("island");
int classBonusIsland=rmDefineClass("bonusIsland");
int classTeamIsland=rmDefineClass("teamIsland");
int classPortSite=rmDefineClass("portSite");
rmDefineClass("classForest");
rmDefineClass("importantItem");
rmDefineClass("natives");
rmDefineClass("classSocket");
int classMountains=rmDefineClass("mountains");
int classHighMountains=rmDefineClass("high mountains");
int classNorthIsland=rmDefineClass("north island");
int classSouthIsland=rmDefineClass("south island");

	chooseMercs();



// -------------Define constraints

// Create a edge of map constraint.
int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

// Cardinal Directions
int Northward=rmCreatePieConstraint("northMapConstraint", 0.55, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
int Southward=rmCreatePieConstraint("southMapConstraint", 0.45, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.45, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
int Westward=rmCreatePieConstraint("westMapConstraint", 0.55, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

// Island constraints
int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48.0);
int northAvoidConstraint=rmCreateClassDistanceConstraint("avoid north island", classNorthIsland, 40.0);
int southAvoidConstraint=rmCreateClassDistanceConstraint("avoid south island", classSouthIsland, 40.0);

// Constraints to avoid water trade Route
int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 20.0);
int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);

// Player objects constraints
int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "TownCenter", 25.0);
int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "TownCenter", 40.0);
int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 55);
int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  
int playersAwayPort=rmCreateAreaDistanceConstraint("players not in port ", classPortSite, 0.01);
int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 29.0);
int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 15.0);
int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 8.0);
int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);

//Socket Constraints
int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("Socket"), 10.0);
int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
int avoidSocketLongCarib=rmCreateTypeDistanceConstraint("avoid socket long carib", "zpSocketMaori", 50.0);
int avoidSocketLongCaribShort=rmCreateTypeDistanceConstraint("avoid socket long maori short", "zpSocketMaori", 25.0);

// Bonus Area Constraints
int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 30.0);
int avoidTeamIslands=rmCreateClassDistanceConstraint("stuff avoids team islands", classTeamIsland, 30.0);
int villageEdgeConstraint = rmCreatePieConstraint("willabe awlaay from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-50, 0, 0, 0);

// Avoid impassable Land
int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 13.0);
int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);

// Avoid water
int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 20.0);
int avoidWater15 = rmCreateTerrainDistanceConstraint("avoid water large 2", "Land", false, 15.0);
int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 20.0);
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

// Nature Constraints
int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 35.0);
int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 35.0);
int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishTuna", 20.0);
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);

int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0); 
int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0); 

// Object Constraints
int avoidTradeSocket = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 20.0);
int avoidPirates=rmCreateTypeDistanceConstraint("stay away from Pirates", "zpSocketPirates", 35.0);
int avoidScientists=rmCreateTypeDistanceConstraint("stay away from Scientists", "zpSocketScientists", 35.0);
int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 10.0);
int avoidWaterFraction = rmCreateTerrainDistanceConstraint("avoid water fraction", "Land", false, rmXFractionToMeters(0.05));
int avoidHighMountains=rmCreateClassDistanceConstraint("stuff avoids high mountains", classHighMountains, 3.0);
int avoidHighMountainsFar=rmCreateClassDistanceConstraint("stuff avoids high mountains far", classHighMountains, 20.0);
int avoidNativeHarbour=rmCreateTypeDistanceConstraint("stay away from Native Harbours", "zpHarbourPlatform", 20.0);


// ****************** Trade Routes *****************

int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 1.0);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.8);
if (cNumberNonGaiaPlayers ==3)
	rmAddTradeRouteWaypoint(tradeRouteID, 0.39, 0.7);
else
	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.7);	
rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.9);

bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

int tradeRouteID2 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID2);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.0);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.2);
if (cNumberNonGaiaPlayers <=3 || cNumberNonGaiaPlayers ==8)
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.61, 0.3);
else
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.3);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.1);

bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");

// Text
rmSetStatusText("",0.10);

// ****************** Player Islands *****************

// North Island
int northIsland = rmCreateArea ("north island");
rmSetAreaSize(northIsland, 0.28, 0.28);
rmSetAreaLocation(northIsland, 1.0, 0.7);
rmSetAreaCoherence(northIsland, 0.6);
rmSetAreaMinBlobs(northIsland, 8);
rmSetAreaMaxBlobs(northIsland, 12);
rmSetAreaMinBlobDistance(northIsland, 8.0);
rmSetAreaMaxBlobDistance(northIsland, 10.0);
rmSetAreaSmoothDistance(northIsland, 15);
rmSetAreaMix(northIsland, "california_grassrocks");
	rmAddAreaTerrainLayer(northIsland, "california\desert4_cal", 0, 6);
	rmAddAreaTerrainLayer(northIsland, "california\desert5_cal", 6, 10);
	rmAddAreaTerrainLayer(northIsland, "california\desert6_cal", 10, 14);
rmSetAreaBaseHeight(northIsland, 2.2);
rmAddAreaConstraint(northIsland, islandConstraint);
rmAddAreaConstraint(northIsland, islandAvoidTradeRoute);
rmSetAreaElevationType(northIsland, cElevTurbulence);
rmSetAreaElevationVariation(northIsland, 4.0);
rmSetAreaElevationPersistence(northIsland, 0.2);
rmSetAreaElevationNoiseBias(northIsland, 1);
rmAddAreaToClass(northIsland, classNorthIsland);
rmAddAreaToClass(northIsland, classIsland);
rmAddAreaToClass(northIsland, classTeamIsland);

	// Port Sites North
	int portSite1 = rmCreateArea ("port_site1");
	rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
	rmSetAreaLocation(portSite1, 0.5+rmXTilesToFraction(23), 0.8);
	rmSetAreaMix(portSite1, "california_desert2");
	rmSetAreaCoherence(portSite1, 1);
	rmSetAreaSmoothDistance(portSite1, 15);
	rmSetAreaBaseHeight(portSite1, 2.5);
	rmAddAreaToClass(portSite1, classPortSite);

	int connectionID1 = rmCreateConnection ("connection_island1");
	rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
	rmSetConnectionWidth(connectionID1, 20, 4);
	rmSetConnectionCoherence(connectionID1, 0.7);
	rmSetConnectionWarnFailure(connectionID1, false);
	rmAddConnectionArea(connectionID1, northIsland);
	rmAddConnectionArea(connectionID1, portSite1);
	rmSetConnectionBaseHeight(connectionID1, 2);
	rmBuildConnection(connectionID1);

	int portSite2 = rmCreateArea ("port_site2");
	rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
	rmSetAreaLocation(portSite2, 0.6+rmXTilesToFraction(17),0.3+rmXTilesToFraction(17));
	rmSetAreaMix(portSite2, "california_desert2");
	rmSetAreaCoherence(portSite2, 1);
	rmSetAreaSmoothDistance(portSite2, 15);
	rmSetAreaBaseHeight(portSite2, 2.5);
	rmAddAreaToClass(portSite2, classPortSite);

	int connectionID2 = rmCreateConnection ("connection_island2");
	rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
	rmSetConnectionWidth(connectionID2, 20, 4);
	rmSetConnectionCoherence(connectionID2, 0.7);
	rmSetConnectionWarnFailure(connectionID2, false);
	rmAddConnectionArea(connectionID2, northIsland);
	rmAddConnectionArea(connectionID2, portSite2);
	rmSetConnectionBaseHeight(connectionID2, 2);
	rmBuildConnection(connectionID2);

// Area builder
rmBuildAllAreas();

// South Island
int southIsland = rmCreateArea ("south island");
rmSetAreaSize(southIsland, 0.28, 0.28);
rmSetAreaLocation(southIsland, 0.0, 0.3);
rmSetAreaCoherence(southIsland, 0.60);
rmSetAreaMinBlobs(southIsland, 8);
rmSetAreaMaxBlobs(southIsland, 12);
rmSetAreaMinBlobDistance(southIsland, 8.0);
rmSetAreaMaxBlobDistance(southIsland, 10.0);
rmSetAreaSmoothDistance(southIsland, 15);
rmSetAreaMix(southIsland, "california_grassrocks");
	rmAddAreaTerrainLayer(southIsland, "california\desert4_cal", 0, 6);
	rmAddAreaTerrainLayer(southIsland, "california\desert5_cal", 6, 10);
	rmAddAreaTerrainLayer(southIsland, "california\desert6_cal", 10, 14);
rmSetAreaBaseHeight(southIsland, 2.2);
rmAddAreaConstraint(southIsland, islandConstraint);
rmAddAreaConstraint(southIsland, islandAvoidTradeRoute); 
rmSetAreaElevationType(southIsland, cElevTurbulence);
rmSetAreaElevationVariation(southIsland, 4.0);
rmSetAreaElevationPersistence(southIsland, 0.2);
rmSetAreaElevationNoiseBias(southIsland, 1);
rmAddAreaToClass(southIsland, classIsland);
rmAddAreaToClass(southIsland, classSouthIsland);
rmAddAreaToClass(southIsland, classTeamIsland);

	// Port Sites

	int portSite3 = rmCreateArea ("port_site3");
	rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
	rmSetAreaLocation(portSite3, 0.5-rmZTilesToFraction(23), 0.2);
	rmSetAreaCoherence(portSite3, 1);
	rmSetAreaMix(portSite3, "california_desert2");
	rmSetAreaSmoothDistance(portSite3, 15);
	rmSetAreaBaseHeight(portSite3, 2.5);
	rmAddAreaToClass(portSite3, classPortSite);

	int connectionID3 = rmCreateConnection ("connection_island3");
	rmSetConnectionType(connectionID3, cConnectAreas, false, 1);
	rmSetConnectionWidth(connectionID3, 17, 4);
	rmSetConnectionCoherence(connectionID3, 0.5);
	rmSetConnectionWarnFailure(connectionID3, false);
	rmAddConnectionArea(connectionID3, southIsland);
	rmAddConnectionArea(connectionID3, portSite3);
	rmSetConnectionBaseHeight(connectionID3, 2);
	rmBuildConnection(connectionID3);

	int portSite4 = rmCreateArea ("port_site4");
	rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
	rmSetAreaLocation(portSite4, 0.4-rmXTilesToFraction(17), 0.7-rmXTilesToFraction(17));
	rmSetAreaCoherence(portSite4, 1);
	rmSetAreaMix(portSite4, "california_desert2");
	rmSetAreaSmoothDistance(portSite4, 15);
	rmSetAreaBaseHeight(portSite4, 2.5);
	rmAddAreaToClass(portSite4, classPortSite);

	int connectionID4 = rmCreateConnection ("connection_island4");
	rmSetConnectionType(connectionID4, cConnectAreas, false, 1);
	rmSetConnectionWidth(connectionID4, 20, 4);
	rmSetConnectionCoherence(connectionID4, 0.4);
	rmSetConnectionWarnFailure(connectionID4, false);
	rmAddConnectionArea(connectionID4, southIsland);
	rmAddConnectionArea(connectionID4, portSite4);
	rmSetConnectionBaseHeight(connectionID4, 2);
	rmBuildConnection(connectionID4);

// Text
	rmSetStatusText("",0.20);


// ****************** Place Pirates ***************************

// Pirate Sites

int portSite5 = rmCreateArea ("port_site5");
rmSetAreaSize(portSite5, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite5, 0.45+rmXTilesToFraction(25), 0.65);
rmSetAreaCoherence(portSite5, 1);
rmSetAreaMix(portSite5, "california_desert2");
rmSetAreaSmoothDistance(portSite5, 15);
rmSetAreaBaseHeight(portSite5, 2.5);
rmAddAreaToClass(portSite5, classPortSite);

int connectionID5 = rmCreateConnection ("connection_island5");
rmSetConnectionType(connectionID5, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID5, 17, 4);
rmSetConnectionCoherence(connectionID5, 0.5);
rmSetConnectionWarnFailure(connectionID5, false);
rmAddConnectionArea(connectionID5, northIsland);
rmAddConnectionArea(connectionID5, portSite5);
rmSetConnectionBaseHeight(connectionID5, 2);
rmBuildConnection(connectionID5);

int portSite6 = rmCreateArea ("port_site6");
rmSetAreaSize(portSite6, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite6, 0.55-rmXTilesToFraction(25), 0.35);
rmSetAreaCoherence(portSite6, 1);
rmSetAreaMix(portSite6, "california_desert2");
rmSetAreaSmoothDistance(portSite6, 15);
rmSetAreaBaseHeight(portSite6, 2.5);
rmAddAreaToClass(portSite6, classPortSite);

int connectionID6 = rmCreateConnection ("connection_island6");
rmSetConnectionType(connectionID6, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID6, 20, 4);
rmSetConnectionCoherence(connectionID6, 0.4);
rmSetConnectionWarnFailure(connectionID6, false);
rmAddConnectionArea(connectionID6, southIsland);
rmAddConnectionArea(connectionID6, portSite6);
rmSetConnectionBaseHeight(connectionID6, 2);
rmBuildConnection(connectionID6);

// Area builder
rmBuildAllAreas();

// add island constraints
int northIslandConstraint=rmCreateAreaConstraint("north Island", northIsland);
int southIslandConstraint=rmCreateAreaConstraint("south Island", southIsland);

   

// Place Controllers
int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
rmPlaceObjectDefAtLoc(controllerID1, 0, 0.45+rmXTilesToFraction(25), 0.65);


int controllerID2 = rmCreateObjectDef("Controler 2");
rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmPlaceObjectDefAtLoc(controllerID2, 0, 0.55-rmXTilesToFraction(25), 0.35);


vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

// Pirate Village 1

int piratesVillageID = -1;
int piratesVillageType = rmRandInt(5,6);
if (nativeVariant == 1)
piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05"); 
else
piratesVillageID = rmCreateGrouping("pirate city", "Scientist_Lab03");   
rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
if (nativeVariant == 1)
rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
else
rmAddObjectDefItem(piratewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
rmAddClosestPointConstraint(villageEdgeConstraint);
rmAddClosestPointConstraint(flagLand);

vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

rmClearClosestPointConstraints();

int pirateportID1 = -1;
pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
rmAddClosestPointConstraint(villageEdgeConstraint);
rmAddClosestPointConstraint(portOnShore);

vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

rmClearClosestPointConstraints();
      


// Pirate Village 2


int piratesVillageID2 = -1;
int piratesVillage2Type = 11-piratesVillageType;
if (nativeVariant == 1)
piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06"); 
else
piratesVillageID2 = rmCreateGrouping("pirate city 2", "Scientist_Lab04");   
rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
if (nativeVariant == 1)
rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
else
rmAddObjectDefItem(piratewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
rmAddClosestPointConstraint(villageEdgeConstraint);
rmAddClosestPointConstraint(flagLand);

vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

rmClearClosestPointConstraints();

int pirateportID2 = -1;
pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
rmAddClosestPointConstraint(villageEdgeConstraint);
rmAddClosestPointConstraint(portOnShore);

vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

rmClearClosestPointConstraints();
 
// ***************** KotH ******************

// Place King's Hill
if (rmGetIsKOTH() == true) {

	// Bonus Island

	int bonusVariation = rmRandInt(1,2);
	int bonusIslandID = rmCreateArea ("bonus island");
	rmSetAreaSize(bonusIslandID, 0.02, 0.02);

	if (bonusVariation == 1)
		rmSetAreaLocation(bonusIslandID, 0.4, 1.0);
	else
		rmSetAreaLocation(bonusIslandID, 0.6, 0.0);
	rmSetAreaCoherence(bonusIslandID, 0.4);
	rmSetAreaMinBlobs(bonusIslandID, 8);
	rmSetAreaMaxBlobs(bonusIslandID, 12);
	rmSetAreaMinBlobDistance(bonusIslandID, 8.0);
	rmSetAreaMaxBlobDistance(bonusIslandID, 10.0);
	rmSetAreaSmoothDistance(bonusIslandID, 15);
	rmSetAreaMix(bonusIslandID, "california_grassrocks");
		rmAddAreaTerrainLayer(bonusIslandID, "california\desert4_cal", 0, 6);
		rmAddAreaTerrainLayer(bonusIslandID, "california\desert5_cal", 6, 10);
		rmAddAreaTerrainLayer(bonusIslandID, "california\desert6_cal", 10, 14);
	rmSetAreaBaseHeight(bonusIslandID, 2.2);
	rmAddAreaConstraint(bonusIslandID, islandConstraint);
	rmAddAreaConstraint(bonusIslandID, islandAvoidTradeRoute); 
	rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bonusIslandID, 4.0);
	rmSetAreaElevationPersistence(bonusIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bonusIslandID, 1);
	rmAddAreaToClass(bonusIslandID, classIsland);
	rmAddAreaToClass(bonusIslandID, classBonusIsland);
	rmBuildArea(bonusIslandID);

	if (bonusVariation == 1)
		ypKingsHillPlacer(0.4, 0.9, 0.05, 0);
	else
		ypKingsHillPlacer(0.6, 0.1, 0.05, 0);
}


// *************** Place ports ********************

// Port 1
int portID01 = rmCreateObjectDef("port 01");
//portID01 = rmCreateGrouping("portG 01", "C:/Users/rosti/Games/Age of Empires 3 DE/76561198347905238/mods/local/Tortuga Local/RandMaps/groupings/harbour_01");
portID01 = rmCreateGrouping("portG 01", "Harbour_Universal_SW");
rmPlaceGroupingAtLoc(portID01, 0, 0.5+rmXTilesToFraction(11), 0.8);

// Port 2
int portID02 = rmCreateObjectDef("port 02");
portID02 = rmCreateGrouping("portG 02", "Harbour_Universal_SE");
rmPlaceGroupingAtLoc(portID02, 0, 0.6+rmXTilesToFraction(15),0.3+rmXTilesToFraction(6));

// Port 3
int portID03 = rmCreateObjectDef("port 03");
portID03 = rmCreateGrouping("portG 03", "Harbour_Universal_NE");
rmPlaceGroupingAtLoc(portID03, 0, 0.5-rmZTilesToFraction(11), 0.2);

// Port 4
int portID04 = rmCreateObjectDef("port 04");
portID04 = rmCreateGrouping("portG 04", "Harbour_Universal_NW");
rmPlaceGroupingAtLoc(portID04, 0, 0.4-rmXTilesToFraction(14), 0.7-rmXTilesToFraction(4));

// Text
rmSetStatusText("",0.30);


// **************************** North Terrain ************************************

// North Island Cliffs
int northIslandCliffs = rmCreateArea ("east island cliffs");
rmSetAreaSize(northIslandCliffs, 0.25, 0.25);
rmSetAreaLocation(northIslandCliffs, 1.0, 0.7);
rmSetAreaCoherence(northIslandCliffs, 0.6);
rmSetAreaMinBlobs(northIslandCliffs, 8);
rmSetAreaMaxBlobs(northIslandCliffs, 12);
rmSetAreaMinBlobDistance(northIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(northIslandCliffs, 10.0);
rmSetAreaSmoothDistance(northIslandCliffs, 15);
rmSetAreaCliffType(northIslandCliffs, "ZP New Zealand Low");
rmSetAreaCliffEdge(northIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(northIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(northIslandCliffs, "california_grass");
rmSetAreaBaseHeight(northIslandCliffs, 3.2);
rmAddAreaConstraint(northIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(northIslandCliffs, avoidTradeSocket);
rmAddAreaConstraint(northIslandCliffs, avoidPirates);
rmAddAreaConstraint(northIslandCliffs, avoidScientists);
rmAddAreaConstraint(northIslandCliffs, southAvoidConstraint);
rmSetAreaElevationType(northIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(northIslandCliffs, 3.0);
rmSetAreaElevationPersistence(northIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(northIslandCliffs, 1);
rmBuildArea(northIslandCliffs);

int northMountainTerrain=rmCreateArea("north mountains terrain"); 
rmSetAreaSize(northMountainTerrain, 0.27, 0.27);
rmSetAreaLocation(northMountainTerrain, 1.0, 0.7);
rmSetAreaCoherence(northMountainTerrain, 0.6);
rmSetAreaMix(northMountainTerrain, "california_grass");
rmSetAreaObeyWorldCircleConstraint(northMountainTerrain, false);
rmBuildArea(northMountainTerrain);

// North Mountains

int northIslandCliffs2=rmCreateArea("north mountain 2");
rmSetAreaTerrainType(northIslandCliffs2, "painteddesert_groundmix_4");
rmSetAreaLocation(northIslandCliffs2, 1.00, 0.70);
rmSetAreaSize(northIslandCliffs2, 0.14, 0.14);
rmSetAreaWarnFailure(northIslandCliffs2, false);
rmSetAreaCliffType(northIslandCliffs2, "ZP New Zealand Medium");
rmSetAreaCliffEdge(northIslandCliffs2, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(northIslandCliffs2, 6.0, 2.0, 0.3);
rmSetAreaCoherence(northIslandCliffs2, 0.6);
rmSetAreaSmoothDistance(northIslandCliffs2, 12);
rmSetAreaElevationVariation(northIslandCliffs2, 3.0);
rmAddAreaToClass(northIslandCliffs2, classMountains);
rmSetAreaHeightBlend(northIslandCliffs2, 1);
rmSetAreaCliffPainting(northIslandCliffs2, true, false, true);
rmBuildArea(northIslandCliffs2);

int northMountainTerrain2=rmCreateArea("north mountains terrain 2"); 
rmSetAreaSize(northMountainTerrain2, 0.14, 0.14);
rmSetAreaLocation(northMountainTerrain2, 1.0, 0.7);
rmSetAreaCoherence(northMountainTerrain2, 0.6);
rmSetAreaMix(northMountainTerrain2, "newengland_grass");
rmSetAreaObeyWorldCircleConstraint(northMountainTerrain2, false);
rmBuildArea(northMountainTerrain2);

int northIslandCliffs3=rmCreateArea("north mountain 3");
rmSetAreaTerrainType(northIslandCliffs3, "painteddesert_groundmix_4");
rmSetAreaLocation(northIslandCliffs3, 1.00, 0.70);
rmSetAreaSize(northIslandCliffs3, 0.07, 0.07);
rmSetAreaWarnFailure(northIslandCliffs3, false);
rmSetAreaCliffType(northIslandCliffs3, "ZP New Zealand High");
rmSetAreaCliffEdge(northIslandCliffs3, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(northIslandCliffs3, 6.0, 2.0, 0.3);
rmSetAreaCoherence(northIslandCliffs3, 0.6);
rmSetAreaSmoothDistance(northIslandCliffs3, 12);
rmSetAreaElevationVariation(northIslandCliffs3, 3.0);
rmSetAreaHeightBlend(northIslandCliffs3, 1);
rmSetAreaCliffPainting(northIslandCliffs3, true, false, true);
rmBuildArea(northIslandCliffs3);

int northMountainTerrain3=rmCreateArea("north mountains terrain 3"); 
rmSetAreaSize(northMountainTerrain3, 0.07, 0.07);
rmSetAreaLocation(northMountainTerrain3, 1.0, 0.7);
rmSetAreaCoherence(northMountainTerrain3, 0.6);
rmSetAreaMix(northMountainTerrain3, "patagonia_dirt");
rmSetAreaObeyWorldCircleConstraint(northMountainTerrain3, false);
rmBuildArea(northMountainTerrain3);

// North High Mountains

int northIslandCliffs4=rmCreateArea("north mountain 4");
rmSetAreaTerrainType(northIslandCliffs4, "painteddesert_groundmix_4");
rmSetAreaLocation(northIslandCliffs4, 1.00, 0.70);
rmSetAreaSize(northIslandCliffs4, 0.035, 0.035);
rmSetAreaWarnFailure(northIslandCliffs4, false);
rmSetAreaCliffType(northIslandCliffs4, "ZP New Zealand High 2");
rmSetAreaCliffEdge(northIslandCliffs4, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(northIslandCliffs4, 6.0, 2.0, 0.3);
rmSetAreaCoherence(northIslandCliffs4, 0.6);
rmSetAreaSmoothDistance(northIslandCliffs4, 12);
rmSetAreaElevationVariation(northIslandCliffs4, 3.0);
rmAddAreaToClass(northIslandCliffs4, classHighMountains);
rmSetAreaHeightBlend(northIslandCliffs4, 1);
rmSetAreaCliffPainting(northIslandCliffs4, true, false, true);
rmBuildArea(northIslandCliffs4);

int northMountainTerrain4=rmCreateArea("north mountains terrain 4"); 
rmSetAreaSize(northMountainTerrain4, 0.03, 0.03);
rmSetAreaLocation(northMountainTerrain4, 1.0, 0.7);
rmSetAreaCoherence(northMountainTerrain4, 0.6);
rmSetAreaMix(northMountainTerrain4, "patagonia_snow");
rmSetAreaObeyWorldCircleConstraint(northMountainTerrain4, false);
rmBuildArea(northMountainTerrain4);

int northIslandCliffs5=rmCreateArea("north mountain 5");
rmSetAreaTerrainType(northIslandCliffs5, "painteddesert_groundmix_4");
rmSetAreaLocation(northIslandCliffs5, 1.00, 0.70);
rmSetAreaSize(northIslandCliffs5, 0.015, 0.015);
rmSetAreaWarnFailure(northIslandCliffs5, false);
rmSetAreaCliffType(northIslandCliffs5, "ZP New Zealand High 3");
rmSetAreaCliffEdge(northIslandCliffs5, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(northIslandCliffs5, 6.0, 2.0, 0.3);
rmSetAreaCoherence(northIslandCliffs5, 0.6);
rmSetAreaSmoothDistance(northIslandCliffs5, 12);
rmSetAreaElevationVariation(northIslandCliffs5, 3.0);
rmSetAreaHeightBlend(northIslandCliffs5, 1);
rmSetAreaCliffPainting(northIslandCliffs5, true, false, true);
rmBuildArea(northIslandCliffs5);

// **************************** South Terrain ************************************

// South Island Cliffs
int southIslandCliffs = rmCreateArea ("south island cliffs");
rmSetAreaSize(southIslandCliffs, 0.25, 0.25);
rmSetAreaLocation(southIslandCliffs, 0.0, 0.3);
rmSetAreaCoherence(southIslandCliffs, 0.6);
rmSetAreaMinBlobs(southIslandCliffs, 8);
rmSetAreaMaxBlobs(southIslandCliffs, 12);
rmSetAreaMinBlobDistance(southIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(southIslandCliffs, 10.0);
rmSetAreaSmoothDistance(southIslandCliffs, 15);
rmSetAreaCliffType(southIslandCliffs, "ZP New Zealand Low");
rmSetAreaCliffEdge(southIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(southIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(southIslandCliffs, "california_grass");
rmSetAreaBaseHeight(southIslandCliffs, 3.2);
rmAddAreaConstraint(southIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(southIslandCliffs, avoidTradeSocket);
rmAddAreaConstraint(southIslandCliffs, avoidPirates);
rmAddAreaConstraint(southIslandCliffs, avoidScientists);
rmAddAreaConstraint(southIslandCliffs, northAvoidConstraint);
rmSetAreaElevationType(southIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(southIslandCliffs, 3.0);
rmSetAreaElevationPersistence(southIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(southIslandCliffs, 1);
rmBuildArea(southIslandCliffs);

int southMountainTerrain=rmCreateArea("south mountains terrain"); 
rmSetAreaSize(southMountainTerrain, 0.27, 0.27);
rmSetAreaLocation(southMountainTerrain, 0.0, 0.3);
rmSetAreaCoherence(southMountainTerrain, 0.6);
rmSetAreaMix(southMountainTerrain, "california_grass");
rmSetAreaObeyWorldCircleConstraint(southMountainTerrain, false);
rmBuildArea(southMountainTerrain);

// south Mountains

int southIslandCliffs2=rmCreateArea("south mountain 2");
rmSetAreaTerrainType(southIslandCliffs2, "painteddesert_groundmix_4");
rmSetAreaLocation(southIslandCliffs2, 0.00, 0.30);
rmSetAreaSize(southIslandCliffs2, 0.14, 0.14);
rmSetAreaWarnFailure(southIslandCliffs2, false);
rmSetAreaCliffType(southIslandCliffs2, "ZP New Zealand Medium");
rmSetAreaCliffEdge(southIslandCliffs2, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(southIslandCliffs2, 6.0, 2.0, 0.3);
rmSetAreaCoherence(southIslandCliffs2, 0.6);
rmSetAreaSmoothDistance(southIslandCliffs2, 12);
rmSetAreaElevationVariation(southIslandCliffs2, 3.0);
rmAddAreaToClass(southIslandCliffs2, classMountains);
rmSetAreaHeightBlend(southIslandCliffs2, 1);
//rmSetAreaCliffPainting(southIslandCliffs2, true, false, true);
rmBuildArea(southIslandCliffs2);

int southMountainTerrain2=rmCreateArea("south mountains terrain 2"); 
rmSetAreaSize(southMountainTerrain2, 0.14, 0.14);
rmSetAreaLocation(southMountainTerrain2, 0.0, 0.3);
rmSetAreaCoherence(southMountainTerrain2, 0.6);
rmSetAreaMix(southMountainTerrain2, "newengland_grass");
rmSetAreaObeyWorldCircleConstraint(southMountainTerrain2, false);
rmBuildArea(southMountainTerrain2);

int southIslandCliffs3=rmCreateArea("south mountain 3");
rmSetAreaTerrainType(southIslandCliffs3, "painteddesert_groundmix_4");
rmSetAreaLocation(southIslandCliffs3, 0.00, 0.30);
rmSetAreaSize(southIslandCliffs3, 0.07, 0.07);
rmSetAreaWarnFailure(southIslandCliffs3, false);
rmSetAreaCliffType(southIslandCliffs3, "ZP New Zealand High");
rmSetAreaCliffEdge(southIslandCliffs3, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(southIslandCliffs3, 6.0, 2.0, 0.3);
rmSetAreaCoherence(southIslandCliffs3, 0.6);
rmSetAreaSmoothDistance(southIslandCliffs3, 12);
rmSetAreaElevationVariation(southIslandCliffs3, 3.0);
rmSetAreaHeightBlend(southIslandCliffs3, 1);
rmSetAreaCliffPainting(southIslandCliffs3, true, false, true);
rmBuildArea(southIslandCliffs3);

int southMountainTerrain3=rmCreateArea("south mountains terrain 3"); 
rmSetAreaSize(southMountainTerrain3, 0.07, 0.07);
rmSetAreaLocation(southMountainTerrain3, 0.0, 0.3);
rmSetAreaCoherence(southMountainTerrain3, 0.6);
rmSetAreaMix(southMountainTerrain3, "patagonia_dirt");
rmSetAreaObeyWorldCircleConstraint(southMountainTerrain3, false);
rmBuildArea(southMountainTerrain3);

// south High Mountains

int southIslandCliffs4=rmCreateArea("south mountain 4");
rmSetAreaTerrainType(southIslandCliffs4, "painteddesert_groundmix_4");
rmSetAreaLocation(southIslandCliffs4, 0.00, 0.30);
rmSetAreaSize(southIslandCliffs4, 0.035, 0.035);
rmSetAreaWarnFailure(southIslandCliffs4, false);
rmSetAreaCliffType(southIslandCliffs4, "ZP New Zealand High 2");
rmSetAreaCliffEdge(southIslandCliffs4, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(southIslandCliffs4, 6.0, 2.0, 0.3);
rmSetAreaCoherence(southIslandCliffs4, 0.6);
rmSetAreaSmoothDistance(southIslandCliffs4, 12);
rmSetAreaElevationVariation(southIslandCliffs4, 3.0);
rmAddAreaToClass(southIslandCliffs4, classHighMountains);
rmSetAreaHeightBlend(southIslandCliffs4, 1);
rmSetAreaCliffPainting(southIslandCliffs4, true, false, true);
rmBuildArea(southIslandCliffs4);

int southMountainTerrain4=rmCreateArea("south mountains terrain 4"); 
rmSetAreaSize(southMountainTerrain4, 0.03, 0.03);
rmSetAreaLocation(southMountainTerrain4, 0.0, 0.3);
rmSetAreaCoherence(southMountainTerrain4, 0.6);
rmSetAreaMix(southMountainTerrain4, "patagonia_snow");
rmSetAreaObeyWorldCircleConstraint(southMountainTerrain4, false);
rmBuildArea(southMountainTerrain4);

int southIslandCliffs5=rmCreateArea("south mountain 5");
rmSetAreaTerrainType(southIslandCliffs5, "painteddesert_groundmix_4");
rmSetAreaLocation(southIslandCliffs5, 0.00, 0.30);
rmSetAreaSize(southIslandCliffs5, 0.015, 0.015);
rmSetAreaWarnFailure(southIslandCliffs5, false);
rmSetAreaCliffType(southIslandCliffs5, "ZP New Zealand High 3");
rmSetAreaCliffEdge(southIslandCliffs5, 4, 0.21, 0.0, 0.0, 0);
rmSetAreaCliffHeight(southIslandCliffs5, 6.0, 2.0, 0.3);
rmSetAreaCoherence(southIslandCliffs5, 0.6);
rmSetAreaSmoothDistance(southIslandCliffs5, 12);
rmSetAreaElevationVariation(southIslandCliffs5, 3.0);
rmSetAreaHeightBlend(southIslandCliffs5, 1);
rmSetAreaCliffPainting(southIslandCliffs5, true, false, true);
rmBuildArea(southIslandCliffs5);

// ************************* Maori Natives *************************

int caribs2VillageID = -1;
int caribs2VillageType = rmRandInt(1,5);
caribs2VillageID = rmCreateGrouping("caribs2 city", "maori_village_0"+caribs2VillageType);
rmAddGroupingConstraint(caribs2VillageID, avoidTC);
rmAddGroupingConstraint(caribs2VillageID, avoidCW);
rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs2VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs2VillageID, avoidHighMountainsFar);
rmAddClosestPointConstraint(villageEdgeConstraint);

int caribs4VillageID = -1;
int caribs4VillageType = rmRandInt(1,5);
caribs4VillageID = rmCreateGrouping("caribs4 city", "maori_village_0"+caribs4VillageType);
rmAddGroupingConstraint(caribs4VillageID, avoidTC);
rmAddGroupingConstraint(caribs4VillageID, avoidCW);
rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs4VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs4VillageID, avoidHighMountainsFar);
rmPlaceGroupingInArea(caribs4VillageID, 0, northIsland, 1);
rmAddClosestPointConstraint(villageEdgeConstraint);

if (cNumberNonGaiaPlayers <= 4){
rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 1);
}

else {
rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 2);
}



int caribs3VillageID = -1;
int caribs3VillageType = rmRandInt(1,5);
caribs3VillageID = rmCreateGrouping("caribs3 city", "maori_village_0"+caribs3VillageType);
rmAddGroupingConstraint(caribs3VillageID, avoidTC);
rmAddGroupingConstraint(caribs3VillageID, avoidCW);
rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs3VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs3VillageID, avoidHighMountainsFar);
rmAddClosestPointConstraint(villageEdgeConstraint);

int caribs5VillageID = -1;
int caribs5VillageType = rmRandInt(1,5);
caribs5VillageID = rmCreateGrouping("caribs5 city", "maori_village_0"+caribs5VillageType);
rmAddGroupingConstraint(caribs5VillageID, avoidTC);
rmAddGroupingConstraint(caribs5VillageID, avoidCW);
rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs5VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs5VillageID, avoidHighMountainsFar);
rmPlaceGroupingInArea(caribs5VillageID, 0, southIsland, 1);
rmAddClosestPointConstraint(villageEdgeConstraint);

if (cNumberNonGaiaPlayers <= 4){
rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 1);
}

else {
rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 2);
}


// Text
	rmSetStatusText("",0.40);

// ***************************** Place Players ***********************************

// Place Town Centers
rmSetTeamSpacingModifier(0.6);

float teamStartLoc = rmRandFloat(0.0, 1.0);
if(cNumberTeams > 2)
{
	rmSetPlacementSection(0.07, 0.8);
	rmSetTeamSpacingModifier(0.75);
	rmPlacePlayersCircular(0.3, 0.3, 0);
}
else
{
	// 4 players in 2 teams
	if (teamStartLoc > 0.5)
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.07, 0.25);
		rmPlacePlayersCircular(0.30, 0.30, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.6, 0.8); 
		rmPlacePlayersCircular(0.30, 0.30, rmDegreesToRadians(5.0));
	}
	else
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.6, 0.8); 
		rmPlacePlayersCircular(0.30, 0.30, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.07, 0.25);
		rmPlacePlayersCircular(0.30, 0.30, rmDegreesToRadians(5.0));
	}
}



// Insert Players
int TCfloat = -1;
if (cNumberTeams == 2)
	TCfloat = 50;
else 
	TCfloat = 135;

int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
   	}

int colonyShipID = 0;

rmSetObjectDefMinDistance(TCID, 0.0);
rmSetObjectDefMaxDistance(TCID, TCfloat);

//Player resources
int playerSilverID = rmCreateObjectDef("player silver");
rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
rmSetObjectDefMinDistance(playerSilverID, 10.0);
rmSetObjectDefMaxDistance(playerSilverID, 30.0);
rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand); 

int playerDeerID=rmCreateObjectDef("player deer");
rmAddObjectDefItem(playerDeerID, "Elk", rmRandInt(10,15), 10.0);
rmSetObjectDefMinDistance(playerDeerID, 15.0);
rmSetObjectDefMaxDistance(playerDeerID, 30.0);
rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
rmSetObjectDefCreateHerd(playerDeerID, true);

rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, playersAwayPort);
rmAddObjectDefConstraint(TCID, avoidBonusIslands);
rmAddObjectDefConstraint(TCID, avoidSocketLongCaribShort);
rmAddObjectDefConstraint(TCID, avoidPirates);
rmAddObjectDefConstraint(TCID, avoidScientists);
rmAddObjectDefConstraint(TCID, avoidMountains);


for(i=1; <cNumberPlayers) {

// Place town centers
rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

// Water flag placement rules
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
rmAddClosestPointConstraint(flagLand);
rmAddClosestPointConstraint(ObjectAvoidTradeRoute);
rmAddClosestPointConstraint(avoidNativeHarbour);
vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

// Place resources
rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

if(ypIsAsian(i) && rmGetNomadStart() == false)
    rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
}

rmClearClosestPointConstraints();

// Text
rmSetStatusText("",0.50);

//************************ Resources **************************
   
// MINES

int goldID = rmCreateObjectDef("gold mine");
rmAddObjectDefItem(goldID, "MineGold", 1, 0.0);
rmSetObjectDefMinDistance(goldID, 0.0);
rmSetObjectDefMaxDistance(goldID, 30);
rmAddObjectDefConstraint(goldID, avoidAll);
rmAddObjectDefConstraint(goldID, avoidImpassableLand);
rmPlaceObjectDefAtLoc(goldID, 0, 1.0, 0.7);

int goldID2 = rmCreateObjectDef("gold mine2");
rmAddObjectDefItem(goldID2, "MineGold", 1, 0.0);
rmSetObjectDefMinDistance(goldID2, 0.0);
rmSetObjectDefMaxDistance(goldID2, 30);
rmPlaceObjectDefAtLoc(goldID2, 0, 0.0, 0.3);

if (rmGetIsKOTH() == true) {
	int goldID3 = rmCreateObjectDef("gold mine3");
	rmAddObjectDefItem(goldID3, "deShipRuins", 1, 0.0);
	rmSetObjectDefMinDistance(goldID3, 0.0);
	rmSetObjectDefMaxDistance(goldID3, 30);
	rmPlaceObjectDefInArea(goldID3, 0, bonusIslandID, 1);
}

int silverType = -1;
int silverID = -1;
int silverCount = (cNumberNonGaiaPlayers);
rmEchoInfo("silver count = "+silverCount);

for(i=0; < silverCount)
{
	int southSilverID = rmCreateObjectDef("south silver "+i);
	rmAddObjectDefItem(southSilverID, "mine", 1, 0.0);
	rmSetObjectDefMinDistance(southSilverID, 0.0);
	rmSetObjectDefMaxDistance(southSilverID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(southSilverID, avoidCoin);
	rmAddObjectDefConstraint(southSilverID, avoidGold);
	rmAddObjectDefConstraint(southSilverID, avoidAll);
	rmAddObjectDefConstraint(southSilverID, avoidTownCenterFar);
	rmAddObjectDefConstraint(southSilverID, avoidImpassableLand);
	rmAddObjectDefConstraint(southSilverID, southIslandConstraint);
	rmPlaceObjectDefAtLoc(southSilverID, 0, 0.5, 0.5);
}

for(i=0; < silverCount)
{
	silverID = rmCreateObjectDef("north silver "+i);
	rmAddObjectDefItem(silverID, "mine", 1, 0.0);
	rmSetObjectDefMinDistance(silverID, 0.0);
	rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(silverID, avoidCoin);
	rmAddObjectDefConstraint(silverID, avoidGold);
	rmAddObjectDefConstraint(silverID, avoidAll);
	rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
	rmAddObjectDefConstraint(silverID, avoidImpassableLand);
	rmAddObjectDefConstraint(silverID, northIslandConstraint);
	rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
} 
	

// Text
rmSetStatusText("",0.60);

// FORESTS
int forestTreeID = 0;
int numTries=10*cNumberNonGaiaPlayers;
int failCount=0;
for (i=0; <numTries) {   
	int forest=rmCreateArea("forest "+i);
	rmSetAreaWarnFailure(forest, false);
	rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
	rmSetAreaForestType(forest, "z81 New Zealand");
	rmSetAreaForestDensity(forest, 0.6);
	rmSetAreaForestClumpiness(forest, 0.4);
	rmSetAreaForestUnderbrush(forest, 0.0);
	rmSetAreaMinBlobs(forest, 1);
	rmSetAreaMaxBlobs(forest, 5);
	rmSetAreaMinBlobDistance(forest, 16.0);
	rmSetAreaMaxBlobDistance(forest, 40.0);
	rmSetAreaCoherence(forest, 0.4);
	rmSetAreaSmoothDistance(forest, 10);
	rmAddAreaToClass(forest, rmClassID("classForest")); 
	rmAddAreaConstraint(forest, forestConstraint);
	rmAddAreaConstraint(forest, avoidAll);
	rmAddAreaConstraint(forest, avoidTCMedium);
	rmAddAreaConstraint(forest, avoidMountains);
	rmAddAreaConstraint(forest, avoidScientists);
	rmAddAreaConstraint(forest, avoidPirates);
	rmAddAreaConstraint(forest, avoidTradeSocket);
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

for (i=0; <numTries/2) {   
    int forest2=rmCreateArea("forest 2 "+i);
    rmSetAreaWarnFailure(forest2, false);
    rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(200));
    rmSetAreaForestType(forest2, "California Pine Forest");
    rmSetAreaForestDensity(forest2, 0.6);
    rmSetAreaForestClumpiness(forest2, 0.4);
    rmSetAreaForestUnderbrush(forest2, 0.0);
    rmSetAreaMinBlobs(forest2, 1);
    rmSetAreaMaxBlobs(forest2, 5);
    rmSetAreaMinBlobDistance(forest2, 16.0);
    rmSetAreaMaxBlobDistance(forest2, 40.0);
    rmSetAreaCoherence(forest2, 0.4);
    rmSetAreaSmoothDistance(forest2, 10);
    rmAddAreaToClass(forest2, rmClassID("classForest")); 
    rmAddAreaConstraint(forest2, forestConstraint);
    rmAddAreaConstraint(forest2, avoidAll);
    rmAddAreaConstraint(forest2, avoidTCMedium);
	rmAddAreaConstraint(forest2, avoidPirates);
	rmAddAreaConstraint(forest2, avoidScientists);
	rmAddAreaConstraint(forest2, avoidTradeSocket);
    rmAddAreaConstraint(forest2, avoidHighMountains);
    rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
    if(rmBuildArea(forest2)==false) {
		// Stop trying once we fail 3 times in a row.
		failCount++;
      
		if(failCount==5)
			break;
    }

   	else
        failCount=0; 
}

// Text
rmSetStatusText("",0.70);

// Nuggets
 
int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(1, 1);
rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
rmAddObjectDefConstraint(nuggetNorth, avoidAll);
rmAddObjectDefConstraint(nuggetNorth, avoidTCshort);
rmAddObjectDefConstraint(nuggetNorth, avoidWater4);
rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
rmAddObjectDefConstraint(nuggetNorth, avoidMountains);
rmPlaceObjectDefInArea(nuggetNorth, 0, northIsland, 1+cNumberNonGaiaPlayers/2);

int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(1, 1);
rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
rmAddObjectDefConstraint(nuggetSouth, avoidAll);
rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
rmAddObjectDefConstraint(nuggetSouth, avoidMountains);
rmPlaceObjectDefInArea(nuggetSouth, 0, southIsland, 1+cNumberNonGaiaPlayers/2);

int nugget2North= rmCreateObjectDef("nugget hard north"); 
rmAddObjectDefItem(nugget2North, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(4, 4);
rmAddObjectDefConstraint(nugget2North, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget2North, avoidNugget);
rmAddObjectDefConstraint(nugget2North, avoidAll);
rmAddObjectDefConstraint(nugget2North, avoidTCshort);
rmAddObjectDefConstraint(nugget2North, avoidWater4);
rmAddObjectDefConstraint(nugget2North, playerEdgeConstraint);
rmPlaceObjectDefInArea(nugget2North, 0, northIslandCliffs2, 1+cNumberNonGaiaPlayers/2);

int nugget2South= rmCreateObjectDef("nugget hard south"); 
rmAddObjectDefItem(nugget2South, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(4, 4);
rmAddObjectDefConstraint(nugget2South, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget2South, avoidNugget);
rmAddObjectDefConstraint(nugget2South, avoidAll);
rmAddObjectDefConstraint(nugget2South, avoidTCshort);
rmAddObjectDefConstraint(nugget2South, avoidWater4);
rmAddObjectDefConstraint(nugget2South, playerEdgeConstraint);
rmPlaceObjectDefInArea(nugget2South, 0, southIslandCliffs2, 1+cNumberNonGaiaPlayers/2);

if (rmGetIsKOTH() == true) {
	int nugget2Bonus= rmCreateObjectDef("nugget hard bonus"); 
	rmAddObjectDefItem(nugget2Bonus, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmAddObjectDefConstraint(nugget2Bonus, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2Bonus, avoidNugget);
	rmAddObjectDefConstraint(nugget2Bonus, avoidAll);
	rmAddObjectDefConstraint(nugget2Bonus, avoidTCshort);
	rmAddObjectDefConstraint(nugget2Bonus, avoidWater4);
	rmAddObjectDefConstraint(nugget2Bonus, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2Bonus, 0, bonusIslandID, 1+cNumberNonGaiaPlayers/4);
}

// Water nuggets

int nuggetCount = 1;

int nuggetWater= rmCreateObjectDef("nugget water" + i); 
rmAddObjectDefItem(nuggetWater, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(5, 5);
rmSetObjectDefMinDistance(nuggetWater, rmXFractionToMeters(0.0));
rmSetObjectDefMaxDistance(nuggetWater, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nuggetWater, avoidLand);
rmAddObjectDefConstraint(nuggetWater, flagVsFlag);
rmAddObjectDefConstraint(nuggetWater, avoidNativeHarbour);
rmAddObjectDefConstraint(nuggetWater, ObjectAvoidTradeRoute);
rmAddObjectDefConstraint(nuggetWater, avoidNuggetWater2);
rmAddObjectDefConstraint(nuggetWater, playerEdgeConstraint);
rmPlaceObjectDefPerPlayer(nuggetWater, false, nuggetCount);

int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(6, 6);
rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nugget2b, avoidLand);
rmAddObjectDefConstraint(nugget2b, flagVsFlag);
rmAddObjectDefConstraint(nugget2b, avoidNativeHarbour);
rmAddObjectDefConstraint(nugget2b, ObjectAvoidTradeRoute);
rmAddObjectDefConstraint(nugget2b, avoidNuggetWater);
rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount);

// Text
rmSetStatusText("",0.80);

// DEER	
int deerID=rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "Elk", rmRandInt(4,6), 10.0);
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(deerID, avoidAll);
rmAddObjectDefConstraint(deerID, avoidImpassableLand);
rmSetObjectDefCreateHerd(deerID, true);
rmPlaceObjectDefInArea(deerID, 0, northIslandCliffs2, 1+cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(deerID, 0, southIslandCliffs2, 1+cNumberNonGaiaPlayers/2);

// Kiwi	
int kiwiID=rmCreateObjectDef("kiwi herd");
rmAddObjectDefItem(kiwiID, "zpKiwi", rmRandInt(8,10), 10.0);
rmSetObjectDefMinDistance(kiwiID, 0.0);
rmSetObjectDefMaxDistance(kiwiID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(kiwiID, avoidAll);
rmAddObjectDefConstraint(kiwiID, avoidImpassableLand);
rmAddObjectDefConstraint(kiwiID, avoidMountains);
rmSetObjectDefCreateHerd(kiwiID, true);
rmPlaceObjectDefInArea(kiwiID, 0, northIsland, 1+cNumberNonGaiaPlayers);
rmPlaceObjectDefInArea(kiwiID, 0, southIsland, 1+cNumberNonGaiaPlayers);

// Text
rmSetStatusText("",0.90);

//Fishes

int fishID=rmCreateObjectDef("fish Mahi");
rmAddObjectDefItem(fishID, "ypFishTuna", 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fishID, fishVsFishID);
rmAddObjectDefConstraint(fishID, fishLand);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);

int fish2ID=rmCreateObjectDef("fish Tarpon");
rmAddObjectDefItem(fish2ID, "FishSalmon", 1, 0.0);
rmSetObjectDefMinDistance(fish2ID, 0.0);
rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fish2ID, fishVsFishID);
rmAddObjectDefConstraint(fish2ID, fishLand);
rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

int whaleID=rmCreateObjectDef("whale");
rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
rmSetObjectDefMinDistance(whaleID, 0.0);
rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
rmAddObjectDefConstraint(whaleID, whaleLand);
rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

// RANDOM TREES
int randomTreeID=rmCreateObjectDef("random tree");
rmAddObjectDefItem(randomTreeID, "ypTreeBorneoCanopy", 1, 0.0);
rmSetObjectDefMinDistance(randomTreeID, 0.0);
rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
rmAddObjectDefConstraint(randomTreeID, avoidHighMountains);
rmAddObjectDefConstraint(randomTreeID, avoidAll); 

rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

// RANDOM TREES SNOW
int randomTreeSnowID=rmCreateObjectDef("random tree snow north");
rmAddObjectDefItem(randomTreeSnowID, "treePatagoniaSnow", 1, 0.0);
rmSetObjectDefMinDistance(randomTreeSnowID, 20.0);
rmSetObjectDefMaxDistance(randomTreeSnowID, rmXFractionToMeters(0.11));
rmAddObjectDefConstraint(randomTreeSnowID, avoidAll); 
rmPlaceObjectDefAtLoc(randomTreeSnowID, 0, 1.0, 0.7, 5*cNumberNonGaiaPlayers);
rmPlaceObjectDefAtLoc(randomTreeSnowID, 0, 0.0, 0.3, 5*cNumberNonGaiaPlayers);


// ------Triggers--------//

string pirate1ID = "0";
string pirate2ID = "0";
string scientist1ID = "0";
string scientist2ID = "0";

if (nativeVariant ==1) {
	pirate1ID = "15";
	pirate2ID = "50";
}

if (nativeVariant ==2) {
	scientist1ID = "15";
	scientist2ID = "100";

}

// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
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


if (nativeVariant ==2) {
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate Renegades"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientists"); //operator
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
}
if (nativeVariant ==1) {
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Activate Tortuga"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPirates"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Renegades"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

if (nativeVariant ==1) {

	// Privateer training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("TrainPrivateer1ON Plr"+k);
	rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
	rmCreateTrigger("TrainPrivateer1TIME Plr"+k);


	rmCreateTrigger("TrainPrivateer2ON Plr"+k);
	rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
	rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Unique ship Training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain1ONPlr"+k);
	rmCreateTrigger("BlackbTrain1OFFPlr"+k);

	rmCreateTrigger("GraceTrain1ONPlr"+k);
	rmCreateTrigger("GraceTrain1OFFPlr"+k);

	rmCreateTrigger("CaesarTrain1ONPlr"+k);
	rmCreateTrigger("CaesarTrain1OFFPlr"+k);

	
	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain2ONPlr"+k);
	rmCreateTrigger("BlackbTrain2OFFPlr"+k);

	rmCreateTrigger("GraceTrain2ONPlr"+k);
	rmCreateTrigger("GraceTrain2OFFPlr"+k);

	rmCreateTrigger("CaesarTrain2ONPlr"+k);
	rmCreateTrigger("CaesarTrain2OFFPlr"+k);
	
	rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne2"); //operator
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
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
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
	rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Blackbeard
	rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne1"); //operator
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
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Grace
	rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Caesar
	rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}


	// Pirate trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates1on Player"+k);
	rmCreateTrigger("Pirates1off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1ID); // Unique Object ID Village 3
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
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
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate2ID); // Unique Object ID Village 4
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}


	// AI Pirate Captains

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Pirate Captain"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int pirateCaptain=-1;
	pirateCaptain = rmRandInt(1,3);

	if (pirateCaptain==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesGrace"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackCaesar"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}
}

if (nativeVariant ==2) {

	// Submarine Training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("TrainSubmarine1ON Plr"+k);
	rmCreateTrigger("TrainSubmarine1OFF Plr"+k);
	rmCreateTrigger("TrainSubmarine1TIME Plr"+k);


	rmCreateTrigger("TrainSubmarine2ON Plr"+k);
	rmCreateTrigger("TrainSubmarine2OFF Plr"+k);
	rmCreateTrigger("TrainSubmarine2TIME Plr"+k);

	rmSwitchToTrigger(rmTriggerID("TrainSubmarine2ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("TrainSubmarine2OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainSubmarine2TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("TrainSubmarine1ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainSubmarine1OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainSubmarine1TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Unique ship Training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Steamer1TIMEPlr"+k);

	rmCreateTrigger("SteamerTrain1ONPlr"+k);
	rmCreateTrigger("SteamerTrain1OFFPlr"+k);

	rmCreateTrigger("Steamer2TIMEPlr"+k);

	rmCreateTrigger("SteamerTrain2ONPlr"+k);
	rmCreateTrigger("SteamerTrain2OFFPlr"+k);


	rmSwitchToTrigger(rmTriggerID("Steamer2TIMEPlr"+k));
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

	rmSwitchToTrigger(rmTriggerID("SteamerTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Steamer2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("SteamerTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	// Build limit reducer
	rmSwitchToTrigger(rmTriggerID("Steamer1TIMEPlr"+k));
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
	rmSwitchToTrigger(rmTriggerID("SteamerTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Steamer1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("SteamerTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	

	}

	// Nautilus Training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Nautilus1TIMEPlr"+k);

	rmCreateTrigger("Nautilus1ONPlr"+k);
	rmCreateTrigger("Nautilus1OFFPlr"+k);

	rmCreateTrigger("Nautilus2TIMEPlr"+k);

	rmCreateTrigger("Nautilus2ONPlr"+k);
	rmCreateTrigger("Nautilus2OFFPlr"+k);

	// Build limit reducer 2
	rmSwitchToTrigger(rmTriggerID("Nautilus2TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Nautilus 2

	rmSwitchToTrigger(rmTriggerID("Nautilus2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Nautilus2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	// Build limit reducer 1
	rmSwitchToTrigger(rmTriggerID("Nautilus1TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Nautilus 1
	rmSwitchToTrigger(rmTriggerID("Nautilus1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Nautilus1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	

	}



	// Renegade trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Renegades1on Player"+k);
	rmCreateTrigger("Renegades1off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Renegades1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Renegades1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",scientist1ID); // Unique Object ID Village 1
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}


	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Renegades2on Player"+k);
	rmCreateTrigger("Renegades2off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Renegades2on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Renegades2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",scientist2ID); // Unique Object ID Village 2
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades2on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine2ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("SteamerTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}

	// AI Renegade Captains

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
		rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistNemo"); //operator
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
rmSetStatusText("",1.0);

} 