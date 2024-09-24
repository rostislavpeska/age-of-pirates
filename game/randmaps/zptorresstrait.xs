
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
int subCiv2=-1;
int subCiv3=-1;
int nativeVariant = rmRandInt(1,2);


subCiv0=rmGetCivID("natpirates");
rmEchoInfo("subCiv0 is natpirates "+subCiv0);
if (subCiv0 >= 0)
		rmSetSubCiv(0, "natpirates");

subCiv2=rmGetCivID("wokou");
rmEchoInfo("subCiv2 is wokou "+subCiv2);
if (subCiv2 >= 0)
	rmSetSubCiv(2, "wokou");

subCiv1=rmGetCivID("AboriginalNatives");
rmEchoInfo("subCiv1 is AboriginalNatives "+subCiv1);
if (subCiv1 >= 0)
	rmSetSubCiv(1, "AboriginalNatives");

subCiv3=rmGetCivID("korowai");
rmEchoInfo("subCiv3 is korowai "+subCiv1);
if (subCiv3 >= 0)
	rmSetSubCiv(3, "korowai");

	
// Set size.
int playerTiles=29000;
if (cNumberNonGaiaPlayers ==4)
	playerTiles = 27000;
if (cNumberNonGaiaPlayers >4)
	playerTiles = 24000;
if (cNumberNonGaiaPlayers >7)
	playerTiles = 21000;			
int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
rmEchoInfo("Map size="+size+"m x "+size+"m");
rmSetMapSize(size, size);

// Set up default water.
rmSetSeaLevel(2.0);
rmSetSeaType("ZP Torres Strait");
rmSetBaseTerrainMix("deccan_skirmish");
rmSetMapType("australia");
rmSetMapType("grass");
rmSetMapType("water");
rmSetLightingSet("caribbean_skirmish");
//rmSetOceanReveal(true);

// Init map.
rmTerrainInitialize("water");
rmSetGlobalRain( 0.3);

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
int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 34.0);
int northAvoidConstraint=rmCreateClassDistanceConstraint("avoid north island", classNorthIsland, 40.0);
int southAvoidConstraint=rmCreateClassDistanceConstraint("avoid south island", classSouthIsland, 40.0);

// Constraints to avoid water trade Route
int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 20.0);
int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);

// Player objects constraints
int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "TownCenter", 25.0);
int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "TownCenter", 60.0);
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
int avoidKorowaiLong=rmCreateTypeDistanceConstraint("avoid socket long korowai", "zpSocketKorowai", 50.0);
int avoidKorowaiShort=rmCreateTypeDistanceConstraint("avoid socket short korowai", "zpSocketKorowai", 25.0);
int avoidAboriginalsLong=rmCreateTypeDistanceConstraint("avoid socket long aboriginals", "zpSocketAboriginals", 50.0);
int avoidAboriginalsShort=rmCreateTypeDistanceConstraint("avoid socket short aboriginals", "zpSocketAboriginals", 25.0);
int avoidKotH=rmCreateTypeDistanceConstraint("avoid koth", "ypKingsHill", 28.0);

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
int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "zpJadeMine", 35.0);
int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 35.0);
int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 30.0);
int avoidNuggetLong=rmCreateTypeDistanceConstraint("nugget avoid nugget long", "abstractNugget", 50.0);
int fishVsFishID2=rmCreateTypeDistanceConstraint("fish v squid", "ypSquid", 20.0);
int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishBass", 20.0);
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);

int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0); 
int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0); 

// Object Constraints
int avoidTradeSocket = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 20.0);
int avoidPirates=rmCreateTypeDistanceConstraint("stay away from Pirates", "zpSocketPirates", 25.0);
int avoidWokou=rmCreateTypeDistanceConstraint("stay away from Scientists", "zpSocketWokou", 25.0);
int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 10.0);
int avoidWaterFraction = rmCreateTerrainDistanceConstraint("avoid water fraction", "Land", false, rmXFractionToMeters(0.05));
int avoidHighMountains=rmCreateClassDistanceConstraint("stuff avoids high mountains", classHighMountains, 3.0);
int avoidHighMountainsFar=rmCreateClassDistanceConstraint("stuff avoids high mountains far", classHighMountains, 20.0);
int avoidNativeHarbour=rmCreateTypeDistanceConstraint("stay away from Native Harbours", "zpHarbourPlatform", 20.0);
int flagVsPirateFlag1 = rmCreateTypeDistanceConstraint("flag avoid pirate flag 1", "zpPirateWaterSpawnFlag1", 35);
int flagVsPirateFlag2 = rmCreateTypeDistanceConstraint("flag avoid pirate flag 2", "zpPirateWaterSpawnFlag2", 35);
int flagVsInventorFlag1 = rmCreateTypeDistanceConstraint("flag avoid native flag 1", "zpNativeWaterSpawnFlag1", 35); 
int flagVsInventorFlag2 = rmCreateTypeDistanceConstraint("flag avoid native flag 2", "zpNativeWaterSpawnFlag2", 35);   
int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);
int RevealerVSRevealer=rmCreateTypeDistanceConstraint("revealer v revealer", "zpCinematicRevealerToAll", 10.0);



// ****************** Trade Routes *****************

int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);
rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.35);
rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.35);
rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.3);
rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.0);

bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

int tradeRouteID2 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID2);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.65);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.35, 0.65);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.7);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 1.0);

bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");

// Text
rmSetStatusText("",0.10);

// ****************** Player Islands *****************

if (rmGetIsKOTH()){

	float xLoc = 0.5;
	float yLoc = 0.5;
	float walk = 0.0;

	int KotHVariant = rmRandInt(1, 2);

	int kothIsland=rmCreateArea("kothIsland");
    rmSetAreaWarnFailure(kothIsland, false);
    rmSetAreaSize(kothIsland, rmAreaTilesToFraction(350), rmAreaTilesToFraction(350));
	if (KotHVariant == 1)
		rmSetAreaTerrainType(kothIsland, "caribbean\ground_shoreline1_crb");
	else
		rmSetAreaTerrainType(kothIsland, "Africa\sand_afr");
	rmSetAreaLocation(kothIsland, 0.5, 0.5);
    rmSetAreaCoherence(kothIsland, 0.99);
    rmSetAreaSmoothDistance(kothIsland, 15);
    rmSetAreaBaseHeight(kothIsland, 3.5);
    rmAddAreaToClass(kothIsland, classIsland);
	rmBuildArea(kothIsland);
	
}

// Port Sites

int portSite3 = rmCreateArea ("port_site3");
rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite3, 0.1, 0.65-rmZTilesToFraction(22));
rmSetAreaCoherence(portSite3, 1);
rmSetAreaTerrainType(portSite3, "Africa\sand_afr");
rmSetAreaSmoothDistance(portSite3, 15);
rmSetAreaBaseHeight(portSite3, 3.5);
rmAddAreaToClass(portSite3, classPortSite);
rmBuildArea(portSite3);

int portSite4 = rmCreateArea ("port_site4");
rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite4, 0.3, 0.65-rmXTilesToFraction(22));
rmSetAreaCoherence(portSite4, 1);
rmSetAreaTerrainType(portSite4, "Africa\sand_afr");
rmSetAreaSmoothDistance(portSite4, 15);
rmSetAreaBaseHeight(portSite4, 3.5);
rmAddAreaToClass(portSite4, classPortSite);
rmBuildArea(portSite4);

// South Island
int southIsland = rmCreateArea ("south island");
rmSetAreaSize(southIsland, 0.15, 0.15);
rmSetAreaLocation(southIsland, 0.0, 0.3);
rmSetAreaCoherence(southIsland, 0.60);
rmSetAreaMinBlobs(southIsland, 8);
rmSetAreaMaxBlobs(southIsland, 12);
rmSetAreaMinBlobDistance(southIsland, 8.0);
rmSetAreaMaxBlobDistance(southIsland, 10.0);
rmSetAreaSmoothDistance(southIsland, 15);
rmSetAreaMix(southIsland, "california_snowground5");
	rmAddAreaTerrainLayer(southIsland, "Africa\sand_afr", 0, 5);
	rmAddAreaTerrainLayer(southIsland, "AfricaRainforest\ground_grass2_afriRainforest", 5, 8);
rmSetAreaBaseHeight(southIsland, 3.5);
rmAddAreaConstraint(southIsland, islandConstraint);
rmAddAreaConstraint(southIsland, islandAvoidTradeRoute); 
rmAddAreaConstraint(southIsland, avoidKotH);
rmSetAreaElevationType(southIsland, cElevTurbulence);
rmSetAreaElevationVariation(southIsland, 5.0);
rmSetAreaElevationPersistence(southIsland, 0.2);
rmSetAreaElevationNoiseBias(southIsland, 1);
rmAddAreaToClass(southIsland, classIsland);
rmAddAreaToClass(southIsland, classSouthIsland);
rmAddAreaToClass(southIsland, classTeamIsland);
rmAddAreaInfluenceSegment(southIsland, 0.2, 0.1, 0.4, 0.55);
rmAddAreaInfluenceSegment(southIsland, 0.4, 0.55, 0.0, 0.5);
rmAddAreaInfluenceSegment(southIsland, 0.0, 0.5, 0.2, 0.1);
rmBuildArea(southIsland);


// Port Sites North
int portSite1 = rmCreateArea ("port_site1");
rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite1, 0.9, 0.35+rmXTilesToFraction(22));
rmSetAreaTerrainType(portSite1, "caribbean\ground_shoreline1_crb");
rmSetAreaCoherence(portSite1, 1);
rmSetAreaSmoothDistance(portSite1, 15);
rmSetAreaBaseHeight(portSite1, 3.5);
rmAddAreaToClass(portSite1, classPortSite);
rmBuildArea(portSite1);

int portSite2 = rmCreateArea ("port_site2");
rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(portSite2, 0.7,0.35+rmXTilesToFraction(22));
rmSetAreaTerrainType(portSite2, "caribbean\ground_shoreline1_crb");
rmSetAreaCoherence(portSite2, 1);
rmSetAreaSmoothDistance(portSite2, 15);
rmSetAreaBaseHeight(portSite2, 3.5);
rmAddAreaToClass(portSite2, classPortSite);
rmBuildArea(portSite2);

// North Island
int northIsland = rmCreateArea ("north island");
rmSetAreaSize(northIsland, 0.15, 0.15);
rmSetAreaLocation(northIsland, 1.0, 0.7);
rmSetAreaCoherence(northIsland, 0.6);
rmSetAreaMinBlobs(northIsland, 8);
rmSetAreaMaxBlobs(northIsland, 12);
rmSetAreaMinBlobDistance(northIsland, 8.0);
rmSetAreaMaxBlobDistance(northIsland, 10.0);
rmSetAreaSmoothDistance(northIsland, 15);
rmSetAreaMix(northIsland, "indochina_grass_a");
	rmAddAreaTerrainLayer(northIsland, "caribbean\ground_shoreline1_crb", 0, 5);
	rmAddAreaTerrainLayer(northIsland, "borneo\ground_grass1_borneo", 5, 8);
rmSetAreaBaseHeight(northIsland, 3.5);
rmAddAreaConstraint(northIsland, islandConstraint);
rmAddAreaConstraint(northIsland, islandAvoidTradeRoute);
rmAddAreaConstraint(northIsland, avoidKotH);
rmSetAreaElevationType(northIsland, cElevTurbulence);
rmSetAreaElevationVariation(northIsland, 5.0);
rmSetAreaElevationPersistence(northIsland, 0.2);
rmSetAreaElevationNoiseBias(northIsland, 1);
rmAddAreaToClass(northIsland, classNorthIsland);
rmAddAreaToClass(northIsland, classIsland);
rmAddAreaToClass(northIsland, classTeamIsland);
rmAddAreaInfluenceSegment(northIsland, 0.8, 0.9, 0.6, 0.45);
rmAddAreaInfluenceSegment(northIsland, 0.6, 0.45, 1.0, 0.5);
rmAddAreaInfluenceSegment(northIsland, 1.0, 0.5, 0.8, 0.9);
rmBuildArea(northIsland);


// Pirate Sites

int portSite5 = rmCreateArea ("port_site5");
rmSetAreaSize(portSite5, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(portSite5, 0.5, 0.78);
rmSetAreaCoherence(portSite5, 1);
rmSetAreaTerrainType(portSite5, "caribbean\ground_shoreline1_crb");
rmSetAreaSmoothDistance(portSite5, 15);
rmSetAreaBaseHeight(portSite5, 2.5);
rmAddAreaToClass(portSite5, classPortSite);
rmBuildArea(portSite5);


// Bonus Island North

int bonusIslandID = rmCreateArea ("bonus island");
rmSetAreaSize(bonusIslandID, 0.02, 0.02);
rmSetAreaLocation(bonusIslandID, 0.55, 0.85);
rmSetAreaCoherence(bonusIslandID, 0.4);
rmSetAreaMinBlobs(bonusIslandID, 8);
rmSetAreaMaxBlobs(bonusIslandID, 12);
rmSetAreaMinBlobDistance(bonusIslandID, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID, 10.0);
rmSetAreaSmoothDistance(bonusIslandID, 15);
rmSetAreaMix(bonusIslandID, "indochina_grass_a");
	rmAddAreaTerrainLayer(bonusIslandID, "caribbean\ground_shoreline1_crb", 0, 5);
	rmAddAreaTerrainLayer(bonusIslandID, "borneo\ground_grass1_borneo", 5, 8);
rmSetAreaBaseHeight(bonusIslandID, 2.5);
rmAddAreaConstraint(bonusIslandID, islandConstraint);
rmAddAreaConstraint(bonusIslandID, islandAvoidTradeRoute); 
rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID, 4.0);
rmSetAreaElevationPersistence(bonusIslandID, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID, 1);
rmAddAreaToClass(bonusIslandID, classIsland);
rmAddAreaToClass(bonusIslandID, classBonusIsland);
rmAddAreaToClass(bonusIslandID, classNorthIsland);
rmBuildArea(bonusIslandID);


int portSite6 = rmCreateArea ("port_site6");
rmSetAreaSize(portSite6, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(portSite6, 0.5, 0.22);
rmSetAreaCoherence(portSite6, 1);
rmSetAreaTerrainType(portSite6, "Africa\sand_afr");
rmSetAreaSmoothDistance(portSite6, 15);
rmSetAreaBaseHeight(portSite6, 2.5);
rmAddAreaToClass(portSite6, classPortSite);
rmBuildArea(portSite6);


int bonusIslandID2 = rmCreateArea ("bonus island 2");
rmSetAreaSize(bonusIslandID2, 0.02, 0.02);
rmSetAreaLocation(bonusIslandID2, 0.45, 0.15);
rmSetAreaCoherence(bonusIslandID2, 0.4);
rmSetAreaMinBlobs(bonusIslandID2, 8);
rmSetAreaMaxBlobs(bonusIslandID2, 12);
rmSetAreaMinBlobDistance(bonusIslandID2, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID2, 10.0);
rmSetAreaSmoothDistance(bonusIslandID2, 15);
rmSetAreaMix(bonusIslandID2, "california_snowground5");
	rmAddAreaTerrainLayer(bonusIslandID2, "Africa\sand_afr", 0, 5);
	rmAddAreaTerrainLayer(bonusIslandID2, "AfricaRainforest\ground_grass2_afriRainforest", 5, 8);
rmSetAreaBaseHeight(bonusIslandID2, 2.5);
rmAddAreaConstraint(bonusIslandID2, islandConstraint);
rmAddAreaConstraint(bonusIslandID2, islandAvoidTradeRoute); 
rmSetAreaElevationType(bonusIslandID2, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID2, 4.0);
rmSetAreaElevationPersistence(bonusIslandID2, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID2, 1);
rmAddAreaToClass(bonusIslandID2, classIsland);
rmAddAreaToClass(bonusIslandID2, classBonusIsland);
rmAddAreaToClass(bonusIslandID2, classSouthIsland);
rmBuildArea(bonusIslandID2);


// North Island Cliffs
int northIslandCliffs = rmCreateArea ("north island cliffs");
rmSetAreaSize(northIslandCliffs, 0.035, 0.035);
rmSetAreaLocation(northIslandCliffs, 1.0, 0.7);
rmSetAreaCoherence(northIslandCliffs, 0.6);
rmSetAreaMinBlobs(northIslandCliffs, 8);
rmSetAreaMaxBlobs(northIslandCliffs, 12);
rmSetAreaMinBlobDistance(northIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(northIslandCliffs, 10.0);
rmSetAreaSmoothDistance(northIslandCliffs, 15);
rmSetAreaCliffType(northIslandCliffs, "ZP Borneo Grass");
rmSetAreaCliffEdge(northIslandCliffs, 4, 0.18, 0.0, 0.0, 0);
rmSetAreaCliffHeight(northIslandCliffs, 5.0, 0.0, 0.5);
rmSetAreaCliffPainting(northIslandCliffs, false, true, true, 0.4, true);
rmAddAreaConstraint(northIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(northIslandCliffs, avoidTradeSocket);
rmAddAreaConstraint(northIslandCliffs, southAvoidConstraint);
rmSetAreaElevationType(northIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(northIslandCliffs, 3.0);
rmSetAreaElevationPersistence(northIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(northIslandCliffs, 1);
rmAddAreaToClass(northIslandCliffs, classMountains);
rmAddAreaInfluenceSegment(northIslandCliffs, 0.95, 0.75, 0.8, 0.6);
rmAddAreaInfluenceSegment(northIslandCliffs, 0.8, 0.6, 1.0, 0.6);
rmAddAreaInfluenceSegment(northIslandCliffs, 1.0, 0.6, 0.95, 0.75);
rmBuildArea(northIslandCliffs);


int southIslandCliffs = rmCreateArea ("south island cliffs");
rmSetAreaSize(southIslandCliffs, 0.035, 0.035);
rmSetAreaLocation(southIslandCliffs, 0.0, 0.3);
rmSetAreaCoherence(southIslandCliffs, 0.6);
rmSetAreaMinBlobs(southIslandCliffs, 8);
rmSetAreaMaxBlobs(southIslandCliffs, 12);
rmSetAreaMinBlobDistance(southIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(southIslandCliffs, 10.0);
rmSetAreaSmoothDistance(southIslandCliffs, 15);
rmSetAreaCliffType(southIslandCliffs, "Africa Rainforest Grass");
rmSetAreaCliffEdge(southIslandCliffs, 4, 0.18, 0.0, 0.0, 0);
rmSetAreaCliffHeight(southIslandCliffs, 5.0, 0.0, 0.5);
rmSetAreaCliffPainting(southIslandCliffs, false, true, true, 0.4, true);
rmAddAreaConstraint(southIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(southIslandCliffs, avoidTradeSocket);
rmAddAreaConstraint(southIslandCliffs, northAvoidConstraint);
rmSetAreaElevationType(southIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(southIslandCliffs, 3.0);
rmSetAreaElevationPersistence(southIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(southIslandCliffs, 1);
rmAddAreaToClass(southIslandCliffs, classMountains);
rmAddAreaInfluenceSegment(southIslandCliffs, 0.05, 0.25, 0.2, 0.4);
rmAddAreaInfluenceSegment(southIslandCliffs, 0.2, 0.4, 0.0, 0.4);
rmAddAreaInfluenceSegment(southIslandCliffs, 0.0, 0.4, 0.05, 0.25);
rmBuildArea(southIslandCliffs);



// Text
	rmSetStatusText("",0.20);


// ****************** Place Pirates ***************************

// add island constraints
int northIslandConstraint=rmCreateAreaConstraint("north Island", northIsland);
int southIslandConstraint=rmCreateAreaConstraint("south Island", southIsland);


// Place Controllers
int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID1, 0.0);
rmSetObjectDefMaxDistance(controllerID1, 0.0);

int controllerID2 = rmCreateObjectDef("Controler 2");
rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID2, 0.0);
rmSetObjectDefMaxDistance(controllerID2, 0.0);

rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5, 0.78);
rmPlaceObjectDefAtLoc(controllerID2, 0, 0.5, 0.22);

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
   
// Pirate Village 1

int piratesVillageID = -1;
int piratesVillageType = rmRandInt(1,2);
piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");
rmSetGroupingMinDistance(piratesVillageID, 0);

rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
rmAddClosestPointConstraint(flagLandShort);

vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

rmClearClosestPointConstraints();

int pirateportID1 = -1;
pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
rmAddClosestPointConstraint(portOnShore);

vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

rmClearClosestPointConstraints();
      
// Wokou Village 1

int piratesVillageID3 = -1;
piratesVillageID3 = rmCreateGrouping("pirate city 3", "Wokou_Village_01");
rmSetGroupingMinDistance(piratesVillageID3, 0);

rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);

int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
rmAddObjectDefItem(piratewaterflagID3, "zpWokouWaterSpawnFlag1", 1, 1.0);
rmAddClosestPointConstraint(flagLandShort);

vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(piratewaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

rmClearClosestPointConstraints();

int pirateportID3 = -1;
pirateportID3 = rmCreateGrouping("pirate port 3", "Platform_Universal");
rmAddClosestPointConstraint(portOnShore);

vector closeToVillage3a = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));

rmClearClosestPointConstraints();


// *************** Place ports ********************

// Port 1
int portID01 = rmCreateObjectDef("port 01");
//portID01 = rmCreateGrouping("portG 01", "C:/Users/rosti/Games/Age of Empires 3 DE/76561198347905238/mods/local/Tortuga Local/RandMaps/groupings/harbour_01");
portID01 = rmCreateGrouping("portG 01", "Harbour_Universal_SE");
rmPlaceGroupingAtLoc(portID01, 0, 0.9, 0.35+rmXTilesToFraction(10));

// Port 2
int portID02 = rmCreateObjectDef("port 02");
portID02 = rmCreateGrouping("portG 02", "Harbour_Universal_SE");
rmPlaceGroupingAtLoc(portID02, 0, 0.7, 0.35+rmXTilesToFraction(10));

// Port 3
int portID03 = rmCreateObjectDef("port 03");
portID03 = rmCreateGrouping("portG 03", "Harbour_Universal_NW");
rmPlaceGroupingAtLoc(portID03, 0, 0.1, 0.65-rmZTilesToFraction(10));

// Port 4
int portID04 = rmCreateObjectDef("port 04");
portID04 = rmCreateGrouping("portG 04", "Harbour_Universal_NW");
rmPlaceGroupingAtLoc(portID04, 0, 0.3, 0.65-rmZTilesToFraction(10));

// King of the Hill

if(rmGetIsKOTH()) {
	ypKingsHillPlacer(xLoc, yLoc, walk, 0);
	rmEchoInfo("XLOC = "+xLoc);
	rmEchoInfo("XLOC = "+yLoc);
}

// Text
rmSetStatusText("",0.30);



// ************************* Korowai Natives *************************

int caribs2VillageID = -1;
int caribs2VillageType = rmRandInt(1,5);
caribs2VillageID = rmCreateGrouping("caribs2 city", "korowai_village_0"+caribs2VillageType);
rmAddGroupingConstraint(caribs2VillageID, avoidTC);
rmAddGroupingConstraint(caribs2VillageID, avoidCW);
rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs2VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs2VillageID, avoidKorowaiLong);
rmAddGroupingConstraint(caribs2VillageID, avoidWater20);
rmAddGroupingConstraint(caribs2VillageID, avoidHighMountainsFar);
rmAddClosestPointConstraint(villageEdgeConstraint);

int caribs4VillageID = -1;
int caribs4VillageType = rmRandInt(1,5);
caribs4VillageID = rmCreateGrouping("caribs4 city", "korowai_village_0"+caribs4VillageType);
rmAddGroupingConstraint(caribs4VillageID, avoidTC);
rmAddGroupingConstraint(caribs4VillageID, avoidCW);
rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs4VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs4VillageID, avoidKorowaiLong);
rmAddGroupingConstraint(caribs4VillageID, avoidWater20);
rmAddGroupingConstraint(caribs4VillageID, avoidHighMountainsFar);
rmPlaceGroupingInArea(caribs4VillageID, 0, northIsland, 1);
rmAddClosestPointConstraint(villageEdgeConstraint);

if (cNumberNonGaiaPlayers <= 4){
rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 1);
}

else {
rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 2);
}


// ************************* Aboriginal Natives *************************

int caribs3VillageID = -1;
int caribs3VillageType = rmRandInt(1,5);
caribs3VillageID = rmCreateGrouping("caribs3 city", "Aboriginal_Rainforest_0"+caribs3VillageType);
rmAddGroupingConstraint(caribs3VillageID, avoidTC);
rmAddGroupingConstraint(caribs3VillageID, avoidCW);
rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs3VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs3VillageID, avoidAboriginalsLong);
rmAddGroupingConstraint(caribs3VillageID, avoidWater20);
rmAddGroupingConstraint(caribs3VillageID, avoidHighMountainsFar);
rmAddClosestPointConstraint(villageEdgeConstraint);

int caribs5VillageID = -1;
int caribs5VillageType = rmRandInt(1,5);
caribs5VillageID = rmCreateGrouping("caribs5 city", "Aboriginal_Rainforest_0"+caribs5VillageType);
rmAddGroupingConstraint(caribs5VillageID, avoidTC);
rmAddGroupingConstraint(caribs5VillageID, avoidCW);
rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
rmAddGroupingConstraint(caribs5VillageID, avoidSocketLong);
rmAddGroupingConstraint(caribs5VillageID, avoidAboriginalsLong);
rmAddGroupingConstraint(caribs5VillageID, avoidHighMountainsFar);
rmAddGroupingConstraint(caribs5VillageID, avoidWater20);
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
	rmSetPlacementSection(0.0, 0.99);
	rmSetTeamSpacingModifier(0.75);
	rmPlacePlayersCircular(0.15, 0.4, 0);
}
else
{
	// 4 players in 2 teams
	if (teamStartLoc > 0.5)
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.1, 0.25);
		rmPlacePlayersCircular(0.15, 0.4, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.6, 0.75); 
		rmPlacePlayersCircular(0.15, 0.4, rmDegreesToRadians(5.0));
	}
	else
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.6, 0.75); 
		rmPlacePlayersCircular(0.15, 0.4, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.1, 0.25);
		rmPlacePlayersCircular(0.15, 0.4, rmDegreesToRadians(5.0));
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
rmAddObjectDefItem(playerSilverID, "MineGold", 1, 0);
rmSetObjectDefMinDistance(playerSilverID, 10.0);
rmSetObjectDefMaxDistance(playerSilverID, 30.0);
rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand); 

int playerDeerID=rmCreateObjectDef("player deer");
rmAddObjectDefItem(playerDeerID, "zpRedNeckedWallaby", rmRandInt(6,10), 10.0);
rmSetObjectDefMinDistance(playerDeerID, 15.0);
rmSetObjectDefMaxDistance(playerDeerID, 30.0);
rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
rmSetObjectDefCreateHerd(playerDeerID, true);

// Starting area nuggets
int playerNuggetID=rmCreateObjectDef("player nugget");
rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
rmSetObjectDefMinDistance(playerNuggetID, 10.0);
rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
rmAddObjectDefConstraint(playerNuggetID, avoidAll);
rmAddObjectDefConstraint(playerNuggetID, shortAvoidImpassableLand);

rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, playersAwayPort);
if (cNumberTeams <= 2 || cNumberNonGaiaPlayers <=4)
	rmAddObjectDefConstraint(TCID, avoidBonusIslands);
rmAddObjectDefConstraint(TCID, avoidKorowaiLong);
rmAddObjectDefConstraint(TCID, avoidAboriginalsLong);
rmAddObjectDefConstraint(TCID, avoidPirates);
rmAddObjectDefConstraint(TCID, avoidWokou);
rmAddObjectDefConstraint(TCID, avoidMountains);

// Fake Frouping to fix the auto-grouping TC bug
int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.6);

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
rmAddClosestPointConstraint(flagVsPirateFlag1);
rmAddClosestPointConstraint(flagVsPirateFlag2);
rmAddClosestPointConstraint(flagVsInventorFlag1);
rmAddClosestPointConstraint(flagVsInventorFlag2);
rmAddClosestPointConstraint(flagLand);
rmAddClosestPointConstraint(ObjectAvoidTradeRoute);
rmAddClosestPointConstraint(avoidNativeHarbour);
vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

// Place resources
rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

// Place starting nugget
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

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
rmPlaceObjectDefAtLoc(goldID, 0, 0.5, 0.8);

int goldID2 = rmCreateObjectDef("gold mine2");
rmAddObjectDefItem(goldID2, "MineGold", 1, 0.0);
rmSetObjectDefMinDistance(goldID2, 0.0);
rmSetObjectDefMaxDistance(goldID2, 30);
rmPlaceObjectDefAtLoc(goldID2, 0, 0.5, 0.2);


int silverType = -1;
int silverID = -1;
int silverCount = (cNumberNonGaiaPlayers*1.5);
rmEchoInfo("silver count = "+silverCount);

for(i=0; < silverCount)
{
	int southSilverID = rmCreateObjectDef("south silver "+i);
	rmAddObjectDefItem(southSilverID, "MineGold", 1, 0.0);
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
	rmAddObjectDefItem(silverID, "MineGold", 1, 0.0);
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
int numTries=7*cNumberNonGaiaPlayers;
int failCount=0;
for (i=0; <numTries) {   
	int forest=rmCreateArea("forest "+i);
	rmSetAreaWarnFailure(forest, false);
	rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
	rmSetAreaForestType(forest, "z84 North Australian Rainforest");
	rmSetAreaTerrainType(forest, "AfricaRainforest\ground_forest1_afriRainforest");
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
	rmAddAreaConstraint(forest, avoidWokou);
	rmAddAreaConstraint(forest, avoidPirates);
	rmAddAreaConstraint(forest, avoidTradeSocket);
	rmAddAreaConstraint(forest, avoidWater15);
	rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
	rmAddAreaConstraint(forest, northAvoidConstraint); 
	if(rmBuildArea(forest)==false) {
		// Stop trying once we fail 3 times in a row.
		failCount++;
		
		if(failCount==5)
			break;
	}

   	else
         failCount=0; 
} 

for (i=0; <numTries) {   
    int forest2=rmCreateArea("forest 2 "+i);
    rmSetAreaWarnFailure(forest2, false);
    rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest2, "Borneo Forest");
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
	rmAddAreaConstraint(forest2, avoidWokou);
	rmAddAreaConstraint(forest2, avoidTradeSocket);
	rmAddAreaConstraint(forest2, avoidWater15);
    rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
	rmAddAreaConstraint(forest2, southAvoidConstraint);
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
rmSetNuggetDifficulty(12, 13);
rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nuggetNorth, avoidNuggetLong);
rmAddObjectDefConstraint(nuggetNorth, avoidAll);
rmAddObjectDefConstraint(nuggetNorth, avoidTCshort);
rmAddObjectDefConstraint(nuggetNorth, avoidWater4);
rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
rmAddObjectDefConstraint(nuggetNorth, avoidMountains);
rmPlaceObjectDefInArea(nuggetNorth, 0, northIsland, cNumberNonGaiaPlayers);

int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(2, 3);
rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nuggetSouth, avoidNuggetLong);
rmAddObjectDefConstraint(nuggetSouth, avoidAll);
rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
rmAddObjectDefConstraint(nuggetSouth, avoidMountains);
rmPlaceObjectDefInArea(nuggetSouth, 0, southIsland, cNumberNonGaiaPlayers);

int nugget2North= rmCreateObjectDef("nugget hard north"); 
rmAddObjectDefItem(nugget2North, "Nugget", 1, 0.0);
if (cNumberTeams > 2 && cNumberNonGaiaPlayers >4) // Easier nuggets for FFA
	rmSetNuggetDifficulty(12, 13);
else
	rmSetNuggetDifficulty(14, 14);
rmAddObjectDefConstraint(nugget2North, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget2North, avoidNugget);
rmAddObjectDefConstraint(nugget2North, avoidAll);
rmAddObjectDefConstraint(nugget2North, avoidTCshort);
rmAddObjectDefConstraint(nugget2North, avoidWater4);
rmAddObjectDefConstraint(nugget2North, playerEdgeConstraint);
rmPlaceObjectDefInArea(nugget2North, 0, bonusIslandID, 1+cNumberNonGaiaPlayers/2);

int nugget2South= rmCreateObjectDef("nugget hard south"); 
rmAddObjectDefItem(nugget2South, "Nugget", 1, 0.0);
if (cNumberTeams > 2 && cNumberNonGaiaPlayers >4) // Easier nuggets for FFA
	rmSetNuggetDifficulty(2, 3);
else
	rmSetNuggetDifficulty(4, 4);
rmAddObjectDefConstraint(nugget2South, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget2South, avoidNugget);
rmAddObjectDefConstraint(nugget2South, avoidAll);
rmAddObjectDefConstraint(nugget2South, avoidTCshort);
rmAddObjectDefConstraint(nugget2South, avoidWater4);
rmAddObjectDefConstraint(nugget2South, playerEdgeConstraint);
rmPlaceObjectDefInArea(nugget2South, 0, bonusIslandID2, 1+cNumberNonGaiaPlayers/2);


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

// Kangaroos
int deerID=rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "zpRedKangaroo", rmRandInt(3,5), 10.0);
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(deerID, avoidAll);
rmAddObjectDefConstraint(deerID, avoidImpassableLand);
rmAddObjectDefConstraint(deerID, avoidHighMountains);
rmSetObjectDefCreateHerd(deerID, true);
rmPlaceObjectDefInArea(deerID, 0, southIsland, 1+cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(deerID, 0, bonusIslandID2, 1+cNumberNonGaiaPlayers/4);

// Pigs
int kiwiID=rmCreateObjectDef("kiwi herd");
rmAddObjectDefItem(kiwiID, "zpFeralPig", rmRandInt(4,6), 10.0);
rmSetObjectDefMinDistance(kiwiID, 0.0);
rmSetObjectDefMaxDistance(kiwiID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(kiwiID, avoidAll);
rmAddObjectDefConstraint(kiwiID, avoidImpassableLand);
rmAddObjectDefConstraint(kiwiID, avoidMountains);
rmSetObjectDefCreateHerd(kiwiID, true);
rmPlaceObjectDefInArea(kiwiID, 0, northIsland, 1+cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(kiwiID, 0, bonusIslandID, 1+cNumberNonGaiaPlayers/4);

// Cassowary
int cassowaryID=rmCreateObjectDef("random cassowary");
rmAddObjectDefItem(cassowaryID, "zpCassowary", rmRandInt(1,2), 8.0); 
rmSetObjectDefMinDistance(cassowaryID, 0.0);
rmSetObjectDefMaxDistance(cassowaryID, rmXFractionToMeters(0.3));
rmAddObjectDefConstraint(cassowaryID, avoidAll);
rmAddObjectDefConstraint(cassowaryID, avoidImpassableLand);
rmAddObjectDefConstraint(cassowaryID, avoidMountains);
rmSetObjectDefCreateHerd(cassowaryID, true);
rmPlaceObjectDefInArea(cassowaryID, 0, northIsland, 1+cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(cassowaryID, 0, southIsland, 1+cNumberNonGaiaPlayers/2);

// Text
rmSetStatusText("",0.90);

//Fishes

int fishID=rmCreateObjectDef("fish Mahi");
rmAddObjectDefItem(fishID, "FishBass", 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fishID, fishVsFishID);
rmAddObjectDefConstraint(fishID, fishLand);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 22*cNumberNonGaiaPlayers);

int fish2ID=rmCreateObjectDef("fish Tarpon");
rmAddObjectDefItem(fish2ID, "ypSquid", 1, 0.0);
rmSetObjectDefMinDistance(fish2ID, 0.0);
rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fish2ID, fishVsFishID);
rmAddObjectDefConstraint(fish2ID, fishVsFishID2);
rmAddObjectDefConstraint(fish2ID, fishLand);
rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);

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
rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.45));
rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);
rmAddObjectDefConstraint(randomTreeID, avoidAll); 

rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);

//Water revealers

int revealerID=rmCreateObjectDef("water revealer");
   rmAddObjectDefItem(revealerID, "zpCinematicRevealerToAll", 1, 0.0);
   rmSetObjectDefMinDistance(revealerID, 0.0);
   rmSetObjectDefMaxDistance(revealerID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(revealerID, RevealerVSRevealer);
   rmAddObjectDefConstraint(revealerID, fishLand);
   rmPlaceObjectDefAtLoc(revealerID, 0, 0.5, 0.5, 100*cNumberNonGaiaPlayers);


// ------Triggers--------//

string pirate1ID = "5";
string wokou1ID = "64";
string centerID = "135";

int stormBreakMin = 600;
int stormBreakMax = 800;
int stormBreak = rmRandInt(stormBreakMin,stormBreakMax);
int stormLenght = 50;
int stormDamage = 9;
int thunderBreak = 9.5;

// Storm
rmCreateTrigger("Storm_Start");
rmCreateTrigger("Storm_Strike");
rmCreateTrigger("Storm_End");


rmSwitchToTrigger(rmTriggerID("Storm_Start"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",stormBreak);
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","spcjc5b");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Storm_Strike"));
rmAddTriggerEffect("Render Rain");
rmSetTriggerEffectParamInt("Percent", 100);
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","StormCounter");
rmSetTriggerEffectParamInt("Start", stormLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Storm ends in");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Storm_End"));
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Storm_End"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","caribbean_skirmish");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Storm_Strike"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Storm_Start"));
rmAddTriggerEffect("Render Rain");
rmSetTriggerEffectParamInt("Percent", 30);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Storm_Strike"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",thunderBreak);
for(i=1; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("Damage Units in Area");
	rmSetTriggerEffectParam("SrcObject",centerID);
	rmSetTriggerEffectParamInt("Player",i);
	rmSetTriggerEffectParam("UnitType","Ship");
	rmSetTriggerEffectParamFloat("Dist",100000);
	rmSetTriggerEffectParamFloat("Damage",stormDamage);
}
rmAddTriggerEffect("Fade To Color");
rmSetTriggerEffectParamInt("R", 150);
rmSetTriggerEffectParamInt("G", 150);
rmSetTriggerEffectParamInt("B", 150);
rmSetTriggerEffectParamInt("Duration", 200);
rmSetTriggerEffectParamInt("Delay", 1);
rmSetTriggerEffectParam("Fade", "false");
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Thunder_strike");
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(true);



// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteWater"); // DEEneableTradeRouteWater
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australian Mercenaries
rmSetTriggerEffectParamInt("Status",2);
}
for(i=0; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpMapOceania"); // Oceania TradePosts
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
rmCreateTrigger("Activate Wokou"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpBlackmailing"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWokouSouth"); //operator
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
rmCreateTrigger("Activate Tortuga"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesAustralia"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmers"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Wokou"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Privateer training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainPrivateer1ON Plr"+k);
rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
rmCreateTrigger("TrainPrivateer1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",pirate1ID);
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
rmSetTriggerConditionParamInt("Param1",1200);
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
   rmSetTriggerConditionParam("DstObject",pirate1ID);
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCPirateSteamerProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainPirateSteamer1"); //operator
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
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Grace
   rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject",pirate1ID);
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
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Caesar
   rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject",pirate1ID);
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpSPCFlyingDutchmanProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainFlyingDutchman1"); //operator
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
   rmSetTriggerConditionParamInt("Param1",1200);
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
rmSetTriggerConditionParam("DstObject",pirate1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackJack"); //operator
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesDutchman"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Junk training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainJunk1ON Plr"+k);
rmCreateTrigger("TrainJunk1OFF Plr"+k);
rmCreateTrigger("TrainJunk1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouJunkProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk1OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpWokouJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Fire Ship training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("trainFuchuan1ON Plr"+k);
rmCreateTrigger("trainFuchuan1OFF Plr"+k);
rmCreateTrigger("trainFuchuan1TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPrauProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan1TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpFireJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Wokou trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Wokou1on Player"+k);
rmCreateTrigger("Wokou1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Wokou1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou1ID);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Wokou1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou1ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou1ID);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Wokou Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int wokouCaptain=-1;
wokouCaptain = rmRandInt(1,3);

if (wokouCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSaoFeng"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (wokouCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSiRigam"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (wokouCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouSwallow"); //operator
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
	rmSetStatusText("",1.0);

} 