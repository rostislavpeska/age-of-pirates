// Polynesia 1.0
// 08/2024

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.10);

// initialize map type variables 
string nativeCiv1 = "bhakti";
string nativeCiv2 = "zen";
string nativeString1 = "native bhakti village ceylon ";
string nativeString2 = "native zen temple ceylon 0";
string baseMix = "california_snowground4";
string paintMix = "ceylon_sand_a";
string baseTerrain = "water";
string playerTerrain = "borneo\ground_sand3_borneo";
string seaType = "ZP Polynesian Coast";
string startTreeType = "TreeAmazon";
string forestType = "z79 hawaii";
string cliffType = "caribbean";
string mapType1 = "hawaii";
string mapType2 = "grass";
string huntable1 = "zpFeralPig";
string huntable2 = "ypWildElephant";
string fish1 = "ypFishTuna";
string fish2 = "FishMahi";
string whale1 = "HumpbackWhale";
string patchTerrain = "ceylon\ground_grass2_ceylon";
string patchType1 = "ceylon\ground_grass4_ceylon";
string patchType2 = "ceylon\ground_sand4_ceylon";


// Define Natives
int subCiv0=-1;
int subCiv1=-1;
int subCiv2=-1;


if (rmAllocateSubCivs(3) == true)
  {
  subCiv0=rmGetCivID("natpirates");
    rmEchoInfo("subCiv0 is pirates "+subCiv0);
    if (subCiv0 >= 0)
        rmSetSubCiv(0, "natpirates");

    subCiv1=rmGetCivID("wokou");
    rmEchoInfo("subCiv1 is wokou "+subCiv1);
    if (subCiv1 >= 0)
    rmSetSubCiv(1, "wokou");

  subCiv2=rmGetCivID("maorinatives");
  rmEchoInfo("subCiv2 is maorinatives "+subCiv2);
  if (subCiv2 >= 0)
      rmSetSubCiv(2, "maorinatives");

  }


// Map variations: 

chooseMercs();

// Set size of map
int playerTiles=29000;
if(cNumberNonGaiaPlayers < 5)
playerTiles = 35000;
if (cNumberNonGaiaPlayers < 3)
    playerTiles = 44000;
int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
rmEchoInfo("Map size="+size+"m x "+size+"m");
rmSetMapSize(size, size);

// Set up default water type.
rmSetSeaLevel(1.0);          
rmSetSeaType(seaType);
rmSetBaseTerrainMix(baseMix);
rmSetMapType(mapType1);
rmSetMapType(mapType2);
rmSetMapType("water");
rmSetLightingSet("age304_caribbean");
rmSetOceanReveal(true);

// Initialize map.
rmTerrainInitialize(baseTerrain);

// Misc variables for use later
int numTries = -1;
int weird = -1;
int TeamNum = cNumberTeams;
int teamZeroCount = rmGetNumberPlayersOnTeam(0);
int teamOneCount = rmGetNumberPlayersOnTeam(1);

// Define some classes.
int classPlayer=rmDefineClass("player");
int classIsland=rmDefineClass("island");
rmDefineClass("classForest");
rmDefineClass("classPatch");
rmDefineClass("importantItem");
int classCanyon=rmDefineClass("canyon");
int classHighMountains=rmDefineClass("high mountains");
int classCentralIsland=rmDefineClass("central island");
int classPortSite=rmDefineClass("portSite");
int classBonusIsland=rmDefineClass("bonus island");

// -------------Define constraints----------------------------------------

// Create an edge of map constraint.
int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

// Player area constraint.
int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 10.0);
int avoidTPLong=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets far", "SocketTradeRoute", 20.0);
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 18.0);
int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion of island", .35, .55, .65, .35);
int northConstraint = rmCreateBoxConstraint("huntable constraint for north side of island", .25, .55, .8, .85);
int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 12.0);
int avoidTCLong=rmCreateTypeDistanceConstraint("stay away from TC by far", "TownCenter", 30.0);

// Island Constraints  
int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 25.0);
int islandConstraintLong=rmCreateClassDistanceConstraint("islands avoid each other long", classIsland, 55.0);
int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
int bonusIslandConstraint=rmCreateClassDistanceConstraint("bonus islands avoid each other", classBonusIsland, 15.0);

// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 25.0);	
int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 12.0);
int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "zpJadeMine", 45.0);
int avoidCoinShort=rmCreateTypeDistanceConstraint("avoid coin short", "zpJadeMine", 15.0);
int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 35.0);
int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "zpPineapleBush", 55.0);
int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 100.0);
int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 40.0);
int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 30.0);
int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketMaori", 30.0);
int avoidJesuitLong=rmCreateTypeDistanceConstraint("avoid socket jesuit long", "zpSocketMaori", 65.0);

// Avoid impassable land
int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
int avoidMesa=rmCreateClassDistanceConstraint("avoid random mesas on south central portion of migration island", classCanyon, 10.0);
int avoidHighMountains=rmCreateClassDistanceConstraint("stuff avoids high mountains", classHighMountains, 3.0);
int avoidHighMountainsFar=rmCreateClassDistanceConstraint("stuff avoids high mountains far", classHighMountains, 20.0);
int avoidCentralIsland=rmCreateClassDistanceConstraint("stuff avoids central island", classCentralIsland, 30.0);

// Constraint to avoid water.
int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 4.0);
int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

// things
int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
int avoidKOTHshort=rmCreateTypeDistanceConstraint("stay away from Kings Hill short", "ypKingsHill", 8.0);
int avoidPlayerCenter=rmCreateTypeDistanceConstraint("stay away from PlayerCenter", "zpSPCWaterSpawnPoint", 13.0);

// flag constraints
int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 15.0);
int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
int flagVsWokou1 = rmCreateTypeDistanceConstraint("flag avoid wokou 1", "zpWokouWaterSpawnFlag1", 40);
int flagVsWokou2 = rmCreateTypeDistanceConstraint("flag avoid wokou  2", "zpWokouWaterSpawnFlag2", 40);
int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 12.0);

//Trade Route Contstraints
int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
int cliffAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("cliff rade route", 2.0);


// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.20);

// Make one big island.  
int centralIslandID=rmCreateArea("central island");
rmSetAreaSize(centralIslandID, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
rmSetAreaCoherence(centralIslandID, 1.0);
rmSetAreaBaseHeight(centralIslandID, 2.0);
rmSetAreaSmoothDistance(centralIslandID, 20);
rmSetAreaMix(centralIslandID, baseMix);
rmAddAreaConstraint(centralIslandID, islandConstraint);
rmSetAreaObeyWorldCircleConstraint(centralIslandID, false);
rmSetAreaElevationType(centralIslandID, cElevTurbulence);
rmSetAreaElevationVariation(centralIslandID, 2.0);
rmSetAreaElevationMinFrequency(centralIslandID, 0.09);
rmSetAreaElevationOctaves(centralIslandID, 3);
rmSetAreaElevationPersistence(centralIslandID, 0.2);
rmSetAreaElevationNoiseBias(centralIslandID, 1);
rmSetAreaLocation(centralIslandID, .5, .5);

rmBuildArea(centralIslandID);
	    	


// ----------- Trade Routes ---------------------------------------------------------------------------------------

int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.18);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.05);
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18);
rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.82);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.95);
rmAddTradeRouteWaypoint(tradeRouteID, 0.82, 0.82);

bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

// ---------- Place Players ---------------------------------------------------------------------------------------

if (TeamNum > 2 || abs(teamZeroCount - teamOneCount)> 0)
    weird = 1;
else
    weird = 0;

if (cNumberNonGaiaPlayers <=2){
    rmSetPlacementSection(0.375, 0.374);
    rmPlacePlayersCircular(0.11, 0.11, 0);
}
if (cNumberNonGaiaPlayers ==3){
    rmSetPlacementSection(0.125, 0.791);
    rmPlacePlayersCircular(0.10, 0.10, 0);
}
if (cNumberNonGaiaPlayers ==4){
    rmSetPlacementSection(0.125, 0.875);
    rmPlacePlayersCircular(0.10, 0.10, 0);
}
if (cNumberNonGaiaPlayers ==5){
    rmSetPlacementSection(0.125, 0.925);
    rmPlacePlayersCircular(0.11, 0.11, 0);
}
if (cNumberNonGaiaPlayers ==6){
    rmSetPlacementSection(0.125, 0.959);
    rmPlacePlayersCircular(0.12, 0.12, 0);
}
if (cNumberNonGaiaPlayers ==7){
    rmSetPlacementSection(0.125, 0.982);
    rmPlacePlayersCircular(0.13, 0.13, 0);
}
if (cNumberNonGaiaPlayers ==8){
    rmSetPlacementSection(0.125, 0.999);
    rmPlacePlayersCircular(0.14, 0.14, 0);
}


int playerStart = rmCreateObjectDef("player Start");
rmAddObjectDefItem(playerStart, "zpSPCWaterSpawnPoint", 1, 0);

for(i=1; <cNumberPlayers)
{
    // Create the Player's area.
    int playerID=rmCreateArea("player "+i);
    rmSetPlayerArea(i, playerID);
    rmAddAreaToClass(playerID, classIsland);
    rmSetAreaSize(playerID, rmAreaTilesToFraction(1200), rmAreaTilesToFraction(1200));
    rmSetAreaLocPlayer(playerID, i);
    rmSetAreaWarnFailure(playerID, false);
	rmSetAreaCoherence(playerID, 0.8);
    rmSetAreaBaseHeight(playerID, 2.0);
    rmSetAreaSmoothDistance(playerID, 20);
    rmSetAreaMix(playerID, baseMix);
        rmAddAreaTerrainLayer(playerID, "caribbean\ground_shoreline1_crb", 0, 1);
        rmAddAreaTerrainLayer(playerID, "caribbean\ground_shoreline2_crb", 1, 2);
        rmAddAreaTerrainLayer(playerID, "caribbean\ground4_crb", 2, 4);
        rmAddAreaTerrainLayer(playerID, "caribbean\ground3_crb", 4, 6);
        rmAddAreaTerrainLayer(playerID, "caribbean\ground2_crb", 6, 8);
	// rmSetAreaTerrainType(playerID, playerTerrain);
    rmAddAreaConstraint(playerID, islandConstraint);
    rmAddAreaConstraint(playerID, islandEdgeConstraint);
    rmAddAreaConstraint(playerID, islandAvoidTradeRoute);
    rmSetAreaElevationType(playerID, cElevTurbulence);
    rmSetAreaElevationVariation(playerID, 4.0);
    rmSetAreaElevationMinFrequency(playerID, 0.09);
    rmSetAreaElevationOctaves(playerID, 3);
    rmSetAreaElevationPersistence(playerID, 0.2);
    rmSetAreaElevationNoiseBias(playerID, 1);	 
    rmBuildArea(playerID);
    rmEchoInfo("Team area"+i);

    int connectionID1 = rmCreateConnection ("connection player "+i);
    rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
    rmSetConnectionWidth(connectionID1, 15, 8);
    rmSetConnectionCoherence(connectionID1, 0.6);
    rmSetConnectionWarnFailure(connectionID1, false);
    rmAddConnectionArea(connectionID1, centralIslandID);
    rmAddConnectionArea(connectionID1, playerID);
    rmSetConnectionBaseHeight(connectionID1, 2.0);
    rmSetConnectionHeightBlend(connectionID1, 20);
    rmBuildConnection(connectionID1);

    rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

}

if(rmGetIsKOTH()) {
    // Create Kings Islands
    int KotHVariant = rmRandInt(1,2);
    int kingIsland=rmCreateArea("kings island");
    rmSetAreaSize(kingIsland, rmAreaTilesToFraction(800), rmAreaTilesToFraction(800));
    rmSetAreaCoherence(kingIsland, 0.8);
    rmSetAreaBaseHeight(kingIsland, 2.0);
    rmSetAreaSmoothDistance(kingIsland, 20);
    rmSetAreaMix(kingIsland, baseMix);
        rmAddAreaTerrainLayer(kingIsland, "caribbean\ground_shoreline1_crb", 0, 1);
        rmAddAreaTerrainLayer(kingIsland, "caribbean\ground_shoreline2_crb", 1, 2);
        rmAddAreaTerrainLayer(kingIsland, "caribbean\ground4_crb", 2, 4);
        rmAddAreaTerrainLayer(kingIsland, "caribbean\ground3_crb", 4, 6);
        rmAddAreaTerrainLayer(kingIsland, "caribbean\ground2_crb", 6, 8);
    rmAddAreaToClass(kingIsland, classIsland);
    rmSetAreaObeyWorldCircleConstraint(kingIsland, false);
    rmAddAreaConstraint(kingIsland, islandConstraintLong);
    rmAddAreaConstraint(kingIsland, islandAvoidTradeRoute);
    if (KotHVariant == 1) {
        rmSetAreaLocation(kingIsland, .73, .73);
    }
    else {
        rmSetAreaLocation(kingIsland, .27, .27);
    }
}

// Create Connections
int connectionIsland1a=rmCreateArea("connection island 1a");
rmSetAreaSize(connectionIsland1a, 0.01, 0.01);
rmSetAreaCoherence(connectionIsland1a, 0.5);
rmSetAreaBaseHeight(connectionIsland1a, 2.0);
rmSetAreaSmoothDistance(connectionIsland1a, 20);
rmSetAreaMix(connectionIsland1a, baseMix);
    rmAddAreaTerrainLayer(connectionIsland1a, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(connectionIsland1a, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(connectionIsland1a, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(connectionIsland1a, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(connectionIsland1a, "caribbean\ground2_crb", 6, 8);
rmSetAreaObeyWorldCircleConstraint(connectionIsland1a, false);
rmAddAreaConstraint(connectionIsland1a, islandConstraintLong);
rmAddAreaConstraint(connectionIsland1a, islandAvoidTradeRoute);
rmSetAreaLocation(connectionIsland1a, .8, .4);  
rmBuildArea(connectionIsland1a);

int connectionIsland1b=rmCreateArea("connection island 1b");
rmSetAreaSize(connectionIsland1b, 0.01, 0.01);
rmSetAreaCoherence(connectionIsland1b, 0.5);
rmSetAreaBaseHeight(connectionIsland1b, 2.0);
rmSetAreaSmoothDistance(connectionIsland1b, 20);
rmSetAreaMix(connectionIsland1b, baseMix);
    rmAddAreaTerrainLayer(connectionIsland1b, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(connectionIsland1b, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(connectionIsland1b, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(connectionIsland1b, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(connectionIsland1b, "caribbean\ground2_crb", 6, 8);
rmSetAreaObeyWorldCircleConstraint(connectionIsland1b, false);
rmAddAreaConstraint(connectionIsland1b, islandConstraintLong);
rmAddAreaConstraint(connectionIsland1b, islandAvoidTradeRoute);
rmSetAreaLocation(connectionIsland1b, .6, .2);  
rmBuildArea(connectionIsland1b);

int connectionIsland2a=rmCreateArea("connection island 2a");
rmSetAreaSize(connectionIsland2a, 0.01, 0.01);
rmSetAreaCoherence(connectionIsland2a, 0.5);
rmSetAreaBaseHeight(connectionIsland2a, 2.0);
rmSetAreaSmoothDistance(connectionIsland2a, 20);
rmSetAreaMix(connectionIsland2a, baseMix);
    rmAddAreaTerrainLayer(connectionIsland2a, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(connectionIsland2a, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(connectionIsland2a, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(connectionIsland2a, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(connectionIsland2a, "caribbean\ground2_crb", 6, 8);
rmSetAreaObeyWorldCircleConstraint(connectionIsland2a, false);
rmAddAreaConstraint(connectionIsland2a, islandConstraintLong);
rmAddAreaConstraint(connectionIsland2a, islandAvoidTradeRoute);
rmSetAreaLocation(connectionIsland2a, .4, .8);  
rmBuildArea(connectionIsland2a);

int connectionIsland2b=rmCreateArea("connection island 2b");
rmSetAreaSize(connectionIsland2b, 0.01, 0.01);
rmSetAreaCoherence(connectionIsland2b, 0.5);
rmSetAreaBaseHeight(connectionIsland2b, 2.0);
rmSetAreaSmoothDistance(connectionIsland2b, 20);
rmSetAreaMix(connectionIsland2b, baseMix);
    rmAddAreaTerrainLayer(connectionIsland2b, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(connectionIsland2b, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(connectionIsland2b, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(connectionIsland2b, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(connectionIsland2b, "caribbean\ground2_crb", 6, 8);
rmSetAreaObeyWorldCircleConstraint(connectionIsland2b, false);
rmAddAreaConstraint(connectionIsland2b, islandConstraintLong);
rmAddAreaConstraint(connectionIsland2b, islandAvoidTradeRoute);
rmSetAreaLocation(connectionIsland2b, .2, .6);  
rmBuildArea(connectionIsland2b);

int connectionID11 = rmCreateConnection ("connection 11");
//rmSetConnectionType(connectionID11, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID11, 30, 8);
rmSetConnectionCoherence(connectionID11, 0.3);
rmSetConnectionWarnFailure(connectionID11, false);
rmAddConnectionArea(connectionID11, connectionIsland1a);
rmAddConnectionArea(connectionID11, connectionIsland1b);
rmSetConnectionBaseHeight(connectionID11, 0.5);
rmSetConnectionHeightBlend(connectionID11, 20);
rmBuildConnection(connectionID11);

int connectionID12 = rmCreateConnection ("connection 22");
//rmSetConnectionType(connectionID12, cConnectAreas, false, 1);
rmSetConnectionWidth(connectionID12, 30, 8);
rmSetConnectionCoherence(connectionID12, 0.3);
rmSetConnectionWarnFailure(connectionID12, false);
rmAddConnectionArea(connectionID12, connectionIsland2a);
rmAddConnectionArea(connectionID12, connectionIsland2b);
rmSetConnectionBaseHeight(connectionID12, 0.5);
rmSetConnectionHeightBlend(connectionID12, 20);
rmBuildConnection(connectionID12);

// Create Bonus Islands
int bonusIsland1=rmCreateArea("bonus island 1");
rmSetAreaSize(bonusIsland1, 0.06, 0.06);
rmSetAreaCoherence(bonusIsland1, 0.5);
rmSetAreaBaseHeight(bonusIsland1, 2.0);
rmSetAreaSmoothDistance(bonusIsland1, 20);
rmSetAreaMix(bonusIsland1, baseMix);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(bonusIsland1, "caribbean\ground2_crb", 6, 8);
rmAddAreaToClass(bonusIsland1, classBonusIsland);
rmSetAreaObeyWorldCircleConstraint(bonusIsland1, false);
rmSetAreaElevationType(bonusIsland1, cElevTurbulence);
rmSetAreaElevationVariation(bonusIsland1, 4.0);
rmSetAreaElevationMinFrequency(bonusIsland1, 0.09);
rmSetAreaElevationOctaves(bonusIsland1, 3);
rmSetAreaElevationPersistence(bonusIsland1, 0.2);
rmSetAreaElevationNoiseBias(bonusIsland1, 1);
rmAddAreaConstraint(bonusIsland1, islandConstraintLong);
rmAddAreaConstraint(bonusIsland1, bonusIslandConstraint);
rmAddAreaConstraint(bonusIsland1, islandAvoidTradeRoute);
rmSetAreaLocation(bonusIsland1, .5, .8);  


int bonusIsland2=rmCreateArea("bonus island 2");
rmSetAreaSize(bonusIsland2, 0.06, 0.06);
rmSetAreaCoherence(bonusIsland2, 0.5);
rmSetAreaBaseHeight(bonusIsland2, 2.0);
rmSetAreaSmoothDistance(bonusIsland2, 20);
rmSetAreaMix(bonusIsland2, baseMix);
    rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(bonusIsland2, "caribbean\ground2_crb", 6, 8);
rmAddAreaToClass(bonusIsland2, classBonusIsland);
rmSetAreaObeyWorldCircleConstraint(bonusIsland2, false);
rmSetAreaElevationType(bonusIsland2, cElevTurbulence);
rmSetAreaElevationVariation(bonusIsland2, 2.0);
rmSetAreaElevationMinFrequency(bonusIsland2, 0.09);
rmSetAreaElevationOctaves(bonusIsland2, 3);
rmSetAreaElevationPersistence(bonusIsland2, 0.2);
rmSetAreaElevationNoiseBias(bonusIsland2, 1);
rmAddAreaConstraint(bonusIsland2, islandConstraintLong);
rmAddAreaConstraint(bonusIsland2, bonusIslandConstraint);
rmAddAreaConstraint(bonusIsland2, islandAvoidTradeRoute);
rmSetAreaLocation(bonusIsland2, .5, .2);  

int bonusIsland3=rmCreateArea("bonus island 3");
rmSetAreaSize(bonusIsland3, 0.06, 0.06);
rmSetAreaCoherence(bonusIsland3, 0.5);
rmSetAreaBaseHeight(bonusIsland3, 2.0);
rmSetAreaSmoothDistance(bonusIsland3, 20);
rmSetAreaMix(bonusIsland3, baseMix);
    rmAddAreaTerrainLayer(bonusIsland3, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(bonusIsland3, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(bonusIsland3, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(bonusIsland3, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(bonusIsland3, "caribbean\ground2_crb", 6, 8);
rmAddAreaToClass(bonusIsland3, classBonusIsland);
rmSetAreaObeyWorldCircleConstraint(bonusIsland3, false);
rmSetAreaElevationType(bonusIsland3, cElevTurbulence);
rmSetAreaElevationVariation(bonusIsland3, 2.0);
rmSetAreaElevationMinFrequency(bonusIsland3, 0.09);
rmSetAreaElevationOctaves(bonusIsland3, 3);
rmSetAreaElevationPersistence(bonusIsland3, 0.2);
rmSetAreaElevationNoiseBias(bonusIsland3, 1);
rmAddAreaConstraint(bonusIsland3, islandConstraintLong);
rmAddAreaConstraint(bonusIsland3, bonusIslandConstraint);
rmAddAreaConstraint(bonusIsland3, islandAvoidTradeRoute);
rmSetAreaLocation(bonusIsland3, .2, .5);  

int bonusIsland4=rmCreateArea("bonus island 4");
rmSetAreaSize(bonusIsland4, 0.06, 0.06);
rmSetAreaCoherence(bonusIsland4, 0.5);
rmSetAreaBaseHeight(bonusIsland4, 2.0);
rmSetAreaSmoothDistance(bonusIsland4, 20);
rmSetAreaMix(bonusIsland4, baseMix);
    rmAddAreaTerrainLayer(bonusIsland4, "caribbean\ground_shoreline1_crb", 0, 1);
    rmAddAreaTerrainLayer(bonusIsland4, "caribbean\ground_shoreline2_crb", 1, 2);
    rmAddAreaTerrainLayer(bonusIsland4, "caribbean\ground4_crb", 2, 4);
    rmAddAreaTerrainLayer(bonusIsland4, "caribbean\ground3_crb", 4, 6);
    rmAddAreaTerrainLayer(bonusIsland4, "caribbean\ground2_crb", 6, 8);
rmAddAreaToClass(bonusIsland4, classBonusIsland);
rmSetAreaObeyWorldCircleConstraint(bonusIsland4, false);
rmSetAreaElevationType(bonusIsland4, cElevTurbulence);
rmSetAreaElevationVariation(bonusIsland4, 2.0);
rmSetAreaElevationMinFrequency(bonusIsland4, 0.09);
rmSetAreaElevationOctaves(bonusIsland4, 3);
rmSetAreaElevationPersistence(bonusIsland4, 0.2);
rmSetAreaElevationNoiseBias(bonusIsland4, 1);
rmAddAreaConstraint(bonusIsland4, islandConstraintLong);
rmAddAreaConstraint(bonusIsland4, bonusIslandConstraint);
rmAddAreaConstraint(bonusIsland4, islandAvoidTradeRoute);
rmSetAreaLocation(bonusIsland4, .8, .5);  


// Build the areas. 
rmBuildAllAreas();



// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.30);

// NATIVES
  
// Place Controllers
int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID1, 0.0);
rmSetObjectDefMaxDistance(controllerID1, 30.0);
rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID1, ferryOnShore); 


int controllerID2 = rmCreateObjectDef("Controler 2");
rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID2, 0.0);
rmSetObjectDefMaxDistance(controllerID2, 30.0);
rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID2, ferryOnShore); 

int controllerID3 = rmCreateObjectDef("Controler 3");
rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID3, 0.0);
rmSetObjectDefMaxDistance(controllerID3, 30.0);
rmAddObjectDefConstraint(controllerID3, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID3, ferryOnShore); 

int controllerID4 = rmCreateObjectDef("Controler 4");
rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefMinDistance(controllerID4, 0.0);
rmSetObjectDefMaxDistance(controllerID4, 30.0);
rmAddObjectDefConstraint(controllerID4, avoidImpassableLand);
rmAddObjectDefConstraint(controllerID4, ferryOnShore);

      
rmPlaceObjectDefAtLoc(controllerID1, 0, 0.65, 0.85);
rmPlaceObjectDefAtLoc(controllerID3, 0, 0.85, 0.65);
rmPlaceObjectDefAtLoc(controllerID2, 0, 0.35, 0.15);
rmPlaceObjectDefAtLoc(controllerID4, 0, 0.15, 0.35);

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

      // Pirate Village 1

      int piratesVillageID = -1;
      int piratesVillageType = rmRandInt(1,2);
      piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");
      rmSetGroupingMinDistance(piratesVillageID, 0);
      rmSetGroupingMaxDistance(piratesVillageID, 20);
      rmAddGroupingConstraint(piratesVillageID, ferryOnShore);

  
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

      // Pirate Village 2

      int piratesVillageID2 = -1;
      int piratesVillage2Type = 3-piratesVillageType;
      piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06");
      rmSetGroupingMinDistance(piratesVillageID2, 0);
      rmSetGroupingMaxDistance(piratesVillageID2, 20);
      rmAddGroupingConstraint(piratesVillageID2, ferryOnShore);

      rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);
    
      int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
      rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

      int pirateportID2 = -1;
      pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();

      // Pirate Village 3

      int piratesVillageID3 = -1;
      piratesVillageID3 = rmCreateGrouping("pirate city 3", "Wokou_Village_01");
      rmSetGroupingMinDistance(piratesVillageID3, 0);
      rmSetGroupingMaxDistance(piratesVillageID3, 20);
      rmAddGroupingConstraint(piratesVillageID3, ferryOnShore);

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

      // Pirate Village 4

      int piratesVillageID4 = -1;
      piratesVillageID4 = rmCreateGrouping("pirate city 4", "Wokou_Village_02");
      rmSetGroupingMinDistance(piratesVillageID4, 0);
      rmSetGroupingMaxDistance(piratesVillageID4, 20);
      rmAddGroupingConstraint(piratesVillageID4, ferryOnShore);

      rmPlaceGroupingAtLoc(piratesVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);
    
      int piratewaterflagID4 = rmCreateObjectDef("pirate water flag 4");
      rmAddObjectDefItem(piratewaterflagID4, "zpWokouWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage4 = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4)));

      rmClearClosestPointConstraints();

      int pirateportID4 = -1;
      pirateportID4 = rmCreateGrouping("pirate port 4", "Platform_Universal");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage4a = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4a)));
      
      rmClearClosestPointConstraints();
	
//==========KotH==============

// check for KOTH game mode
if(rmGetIsKOTH()) {
    if (KotHVariant == 1) {
        float xLoc = 0.73;
        float yLoc = 0.73;
    }
    else {
        xLoc = 0.27;
        yLoc = 0.27;
    }
    float walk = 0.00;

    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
    rmEchoInfo("XLOC = "+xLoc);
    rmEchoInfo("XLOC = "+yLoc);
}

// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.40);

//====================Volcano===============================================================

// ----------- Lava Flows ---------------------------------------------------------------------------------------

int lavaflowID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID);
rmAddTradeRouteWaypoint(lavaflowID, 0.5, 0.5);
rmAddTradeRouteWaypoint(lavaflowID, 0.5+rmXTilesToFraction(15), 0.5);

bool placedLavaflowID = rmBuildTradeRoute(lavaflowID, "lava_flow");

int lavaflowID2 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID2);
rmAddTradeRouteWaypoint(lavaflowID2, 0.5, 0.5);
rmAddTradeRouteWaypoint(lavaflowID2, 0.5, 0.5+rmXTilesToFraction(15));

bool placedLavaflowID2 = rmBuildTradeRoute(lavaflowID2, "lava_flow");

int lavaflowID3 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID3);
rmAddTradeRouteWaypoint(lavaflowID3, 0.5, 0.5);
rmAddTradeRouteWaypoint(lavaflowID3, 0.5-rmXTilesToFraction(15), 0.5);

bool placedLavaflowID3 = rmBuildTradeRoute(lavaflowID3, "lava_flow");

int lavaflowID4 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(lavaflowID4);
rmAddTradeRouteWaypoint(lavaflowID4, 0.5, 0.5);
rmAddTradeRouteWaypoint(lavaflowID4, 0.5, 0.5-rmXTilesToFraction(15));

bool placedLavaflowID4 = rmBuildTradeRoute(lavaflowID4, "lava_flow");

/*int stopperID=rmCreateObjectDef("Stopper 1");
rmAddObjectDefItem(stopperID, "zpTreeCaribbean", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID, true);
rmSetObjectDefMinDistance(stopperID, 0.0);
rmSetObjectDefMaxDistance(stopperID, 0.0);

int stopperID2=rmCreateObjectDef("Stopper 2");
rmAddObjectDefItem(stopperID2, "zpTreeCaribbean", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID2, true);
rmSetObjectDefMinDistance(stopperID2, 0.0);
rmSetObjectDefMaxDistance(stopperID2, 0.0);

int stopperID3=rmCreateObjectDef("Stopper 3");
rmAddObjectDefItem(stopperID3, "zpTreeCaribbean", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID3, true);
rmSetObjectDefMinDistance(stopperID3, 0.0);
rmSetObjectDefMaxDistance(stopperID3, 0.0);

int stopperID4=rmCreateObjectDef("Stopper 4");
rmAddObjectDefItem(stopperID4, "zpTreeCaribbean", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID4, true);
rmSetObjectDefMinDistance(stopperID4, 0.0);
rmSetObjectDefMaxDistance(stopperID4, 0.0);

rmSetObjectDefTradeRouteID(stopperID, lavaflowID);
rmSetObjectDefTradeRouteID(stopperID2, lavaflowID2);
rmSetObjectDefTradeRouteID(stopperID3, lavaflowID3);
rmSetObjectDefTradeRouteID(stopperID4, lavaflowID4);*/



// ------------------ Volcano Terrain -----------------------------------------------------------------------

// Level 2

int basecliffID2 = rmCreateArea("base cliff2");
rmSetAreaSize(basecliffID2, rmAreaTilesToFraction(1600.0), rmAreaTilesToFraction(1600.0));
rmSetAreaWarnFailure(basecliffID2, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID2, false);		
rmAddAreaToClass(basecliffID2, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID2, 4);
rmSetAreaCoherence(basecliffID2, .7);
rmSetAreaHeightBlend(basecliffID2, 0);
rmSetAreaCliffType(basecliffID2, "ZP Volcano Shore");
rmSetAreaTerrainType(basecliffID2, "lava\volcano_grass");
rmSetAreaCliffEdge(basecliffID2, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID2, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID2, 0, 0.1, 0.5);
rmSetAreaBaseHeight(basecliffID2, 6.0);
rmSetAreaLocation(basecliffID2, 0.5, 0.5);
rmAddAreaToClass(basecliffID2, classHighMountains);
rmAddAreaConstraint(basecliffID2, avoidKOTHshort);
rmAddAreaConstraint(basecliffID2, avoidPlayerCenter);	
//rmSetAreaReveal(basecliffID2, 1);
rmBuildArea(basecliffID2);

// Level 3

int fujiPeaklvl3 = rmCreateArea("fujiPeaklvl3");
rmSetAreaSize(fujiPeaklvl3, rmAreaTilesToFraction(900.0), rmAreaTilesToFraction(900.0));
rmSetAreaLocation(fujiPeaklvl3, 0.5, 0.5);
rmSetAreaTerrainType(fujiPeaklvl3, "lava\volcano_grass");
rmSetAreaBaseHeight(fujiPeaklvl3, 11.0);
rmAddAreaConstraint(fujiPeaklvl3, avoidKOTHshort);
rmAddAreaConstraint(fujiPeaklvl3, avoidPlayerCenter);
rmSetAreaSmoothDistance(fujiPeaklvl3, 50);
rmSetAreaCoherence(fujiPeaklvl3, .7);
rmBuildArea(fujiPeaklvl3);  

int volcanoMountainTerrain3=rmCreateArea("volcano terrain 23"); 
rmSetAreaSize(volcanoMountainTerrain3, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
rmSetAreaLocation(volcanoMountainTerrain3, 0.5, 0.5);
rmSetAreaCoherence(volcanoMountainTerrain3, 0.6);
rmSetAreaTerrainType(volcanoMountainTerrain3, "lava\volcano_dirt");
rmAddAreaConstraint(volcanoMountainTerrain3, avoidKOTHshort);
rmSetAreaObeyWorldCircleConstraint(volcanoMountainTerrain3, false);
rmBuildArea(volcanoMountainTerrain3);

int basecliffID31 = rmCreateArea("base cliff31");
rmSetAreaSize(basecliffID31, rmAreaTilesToFraction(160.0), rmAreaTilesToFraction(160.0));
rmSetAreaWarnFailure(basecliffID31, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID31, false);
rmAddAreaConstraint(basecliffID31, avoidPlayerCenter);		
rmAddAreaToClass(basecliffID31, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID31, 5);
rmSetAreaCoherence(basecliffID31, .6);
rmSetAreaHeightBlend(basecliffID31, 0);
rmSetAreaCliffType(basecliffID31, "ZP Hawaii High 2");
rmSetAreaTerrainType(basecliffID31, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID31, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID31, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID31, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID31, 14.0);
rmSetAreaLocation(basecliffID31, 0.5+rmXTilesToFraction(7), 0.5-rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID31, avoidKOTHshort);
rmAddAreaConstraint(basecliffID31, cliffAvoidTradeRoute);
rmBuildArea(basecliffID31);

int basecliffID32 = rmCreateArea("base cliff32");
rmSetAreaSize(basecliffID32, rmAreaTilesToFraction(160.0), rmAreaTilesToFraction(160.0));
rmSetAreaWarnFailure(basecliffID32, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID32, false);
rmAddAreaConstraint(basecliffID32, avoidPlayerCenter);		
rmAddAreaToClass(basecliffID32, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID32, 5);
rmSetAreaCoherence(basecliffID32, .6);
rmSetAreaHeightBlend(basecliffID32, 0);
rmSetAreaCliffType(basecliffID32, "ZP Hawaii High 2");
rmSetAreaTerrainType(basecliffID32, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID32, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID32, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID32, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID32, 14.0);
rmSetAreaLocation(basecliffID32, 0.5-rmXTilesToFraction(7), 0.5-rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID32, avoidKOTHshort);
rmAddAreaConstraint(basecliffID32, cliffAvoidTradeRoute);
rmBuildArea(basecliffID32);

int basecliffID33 = rmCreateArea("base cliff33");
rmSetAreaSize(basecliffID33, rmAreaTilesToFraction(160.0), rmAreaTilesToFraction(160.0));
rmSetAreaWarnFailure(basecliffID33, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID33, false);	
rmAddAreaConstraint(basecliffID33, avoidPlayerCenter);	
rmAddAreaToClass(basecliffID33, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID33, 5);
rmSetAreaCoherence(basecliffID33, .6);
rmSetAreaHeightBlend(basecliffID33, 0);
rmSetAreaCliffType(basecliffID33, "ZP Hawaii High 2");
rmSetAreaTerrainType(basecliffID33, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID33, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID33, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID33, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID33, 14.0);
rmSetAreaLocation(basecliffID33, 0.5-rmXTilesToFraction(7), 0.5+rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID33, avoidKOTHshort);
rmAddAreaConstraint(basecliffID33, cliffAvoidTradeRoute);
rmBuildArea(basecliffID33);

int basecliffID34 = rmCreateArea("base cliff34");
rmSetAreaSize(basecliffID34, rmAreaTilesToFraction(160.0), rmAreaTilesToFraction(160.0));
rmSetAreaWarnFailure(basecliffID34, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID34, false);	
rmAddAreaConstraint(basecliffID34, avoidPlayerCenter);	
rmAddAreaToClass(basecliffID34, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID34, 5);
rmSetAreaCoherence(basecliffID34, .6);
rmSetAreaHeightBlend(basecliffID34, 0);
rmSetAreaCliffType(basecliffID34, "ZP Hawaii High 2");
rmSetAreaTerrainType(basecliffID34, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID34, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID34, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID34, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID34, 14.0);
rmSetAreaLocation(basecliffID34, 0.5+rmXTilesToFraction(7), 0.5+rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID34, avoidKOTHshort);
rmAddAreaConstraint(basecliffID34, cliffAvoidTradeRoute);
rmBuildArea(basecliffID34);

// Level 4

int fujiPeaklvl4 = rmCreateArea("fujiPeaklvl4");
rmSetAreaSize(fujiPeaklvl4, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
rmSetAreaLocation(fujiPeaklvl4, 0.5, 0.5);
rmSetAreaTerrainType(fujiPeaklvl4, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeaklvl4, 15.0);
rmAddAreaConstraint(fujiPeaklvl4, avoidKOTHshort);
rmAddAreaConstraint(fujiPeaklvl4, avoidPlayerCenter);
rmSetAreaSmoothDistance(fujiPeaklvl4, 40);
rmSetAreaCoherence(fujiPeaklvl4, .8);
rmBuildArea(fujiPeaklvl4);  

int basecliffID41 = rmCreateArea("base cliff41");
rmSetAreaSize(basecliffID41, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaWarnFailure(basecliffID41, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID41, false);		
rmAddAreaToClass(basecliffID41, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID41, 5);
rmSetAreaCoherence(basecliffID41, .6);
rmSetAreaHeightBlend(basecliffID41, 0);
rmSetAreaCliffType(basecliffID41, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID41, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID41, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID41, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID41, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID41, 18.0);
rmSetAreaElevationVariation(basecliffID41, 3);
rmSetAreaLocation(basecliffID41, 0.5+rmXTilesToFraction(7), 0.5-rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID41, avoidKOTHshort);
rmAddAreaConstraint(basecliffID41, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID41, avoidPlayerCenter);
rmBuildArea(basecliffID41);

int basecliffID42 = rmCreateArea("base cliff42");
rmSetAreaSize(basecliffID42, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaWarnFailure(basecliffID42, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID42, false);		
rmAddAreaToClass(basecliffID42, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID42, 5);
rmSetAreaCoherence(basecliffID42, .6);
rmSetAreaHeightBlend(basecliffID42, 0);
rmSetAreaCliffType(basecliffID42, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID42, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID42, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID42, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID42, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID42, 18.0);
rmSetAreaElevationVariation(basecliffID42, 3);
rmSetAreaLocation(basecliffID42, 0.5-rmXTilesToFraction(7), 0.5-rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID42, avoidKOTHshort);
rmAddAreaConstraint(basecliffID42, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID42, avoidPlayerCenter);
rmBuildArea(basecliffID42);

int basecliffID43 = rmCreateArea("base cliff43");
rmSetAreaSize(basecliffID43, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaWarnFailure(basecliffID43, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID43, false);		
rmAddAreaToClass(basecliffID43, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID43, 5);
rmSetAreaCoherence(basecliffID43, .6);
rmSetAreaHeightBlend(basecliffID43, 0);
rmSetAreaCliffType(basecliffID43, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID43, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID43, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID43, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID43, 3, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID43, 18.0);
rmSetAreaElevationVariation(basecliffID43, 3);
rmSetAreaLocation(basecliffID43, 0.5-rmXTilesToFraction(7), 0.5+rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID43, avoidKOTHshort);
rmAddAreaConstraint(basecliffID43, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID43, avoidPlayerCenter);
rmBuildArea(basecliffID43);

int basecliffID44 = rmCreateArea("base cliff44");
rmSetAreaSize(basecliffID44, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaWarnFailure(basecliffID44, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID44, false);		
rmAddAreaToClass(basecliffID44, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID44, 5);
rmSetAreaCoherence(basecliffID44, .6);
rmSetAreaHeightBlend(basecliffID44, 0);
rmSetAreaCliffType(basecliffID44, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID44, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID44, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID44, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID44, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID44, 18.0);
rmSetAreaElevationVariation(basecliffID44, 3);
rmSetAreaLocation(basecliffID44, 0.5+rmXTilesToFraction(7), 0.5+rmXTilesToFraction(7));
rmAddAreaConstraint(basecliffID44, avoidKOTHshort);
rmAddAreaConstraint(basecliffID44, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID44, avoidPlayerCenter);
rmBuildArea(basecliffID44);

// Level 5

int fujiPeaklvl5 = rmCreateArea("fujiPeaklvl5");
rmSetAreaSize(fujiPeaklvl5, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
rmSetAreaLocation(fujiPeaklvl5, 0.5, 0.5);
rmSetAreaTerrainType(fujiPeaklvl5, "lava\volcano_dirt");
rmSetAreaBaseHeight(fujiPeaklvl5, 19.0);
rmAddAreaConstraint(fujiPeaklvl5, avoidKOTHshort);
rmAddAreaConstraint(fujiPeaklvl5, avoidPlayerCenter);
rmSetAreaSmoothDistance(fujiPeaklvl5, 40);
rmSetAreaCoherence(fujiPeaklvl5, .8);
rmBuildArea(fujiPeaklvl5); 

int basecliffID51 = rmCreateArea("base cliff51");
rmSetAreaSize(basecliffID51, rmAreaTilesToFraction(20.0), rmAreaTilesToFraction(20.0));
rmSetAreaWarnFailure(basecliffID51, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID51, false);		
rmAddAreaToClass(basecliffID51, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID51, 5);
rmSetAreaCoherence(basecliffID51, .6);
rmSetAreaHeightBlend(basecliffID51, 0);
rmSetAreaCliffType(basecliffID51, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID51, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID51, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID51, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID51, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID51, 22.0);
rmSetAreaElevationVariation(basecliffID51, 3);
rmSetAreaLocation(basecliffID51, 0.5+rmXTilesToFraction(5), 0.5-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID51, avoidKOTHshort);
rmAddAreaConstraint(basecliffID51, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID51, avoidPlayerCenter);
rmBuildArea(basecliffID51);

int basecliffID52 = rmCreateArea("base cliff52");
rmSetAreaSize(basecliffID52, rmAreaTilesToFraction(20.0), rmAreaTilesToFraction(20.0));
rmSetAreaWarnFailure(basecliffID52, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID52, false);		
rmAddAreaToClass(basecliffID52, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID52, 5);
rmSetAreaCoherence(basecliffID52, .6);
rmSetAreaHeightBlend(basecliffID52, 0);
rmSetAreaCliffType(basecliffID52, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID52, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID52, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID52, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID52, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID52, 22.0);
rmSetAreaElevationVariation(basecliffID52, 3);
rmSetAreaLocation(basecliffID52, 0.5-rmXTilesToFraction(5), 0.5-rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID52, avoidKOTHshort);
rmAddAreaConstraint(basecliffID52, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID52, avoidPlayerCenter);
rmBuildArea(basecliffID52);

int basecliffID53 = rmCreateArea("base cliff23");
rmSetAreaSize(basecliffID53, rmAreaTilesToFraction(20.0), rmAreaTilesToFraction(20.0));
rmSetAreaWarnFailure(basecliffID53, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID53, false);		
rmAddAreaToClass(basecliffID53, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID53, 5);
rmSetAreaCoherence(basecliffID53, .6);
rmSetAreaHeightBlend(basecliffID53, 0);
rmSetAreaCliffType(basecliffID53, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID53, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID53, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID53, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID53, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID53, 22.0);
rmSetAreaElevationVariation(basecliffID53, 3);
rmSetAreaLocation(basecliffID53, 0.5-rmXTilesToFraction(5), 0.5+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID53, avoidKOTHshort);
rmAddAreaConstraint(basecliffID53, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID53, avoidPlayerCenter);
rmBuildArea(basecliffID53);

int basecliffID54 = rmCreateArea("base cliff54");
rmSetAreaSize(basecliffID54, rmAreaTilesToFraction(20.0), rmAreaTilesToFraction(20.0));
rmSetAreaWarnFailure(basecliffID54, false);
rmSetAreaObeyWorldCircleConstraint(basecliffID54, false);		
rmAddAreaToClass(basecliffID54, rmClassID("classPlateau"));
rmSetAreaElevationVariation(basecliffID54, 5);
rmSetAreaCoherence(basecliffID54, .6);
rmSetAreaHeightBlend(basecliffID54, 0);
rmSetAreaCliffType(basecliffID54, "ZP Hawaii High");
rmSetAreaTerrainType(basecliffID54, "lava\volcano_dirt");
rmSetAreaCliffEdge(basecliffID54, 1, 1.00, 0.0, 0.0, 2); 
rmSetAreaCliffPainting(basecliffID54, true, true, true, 1.5, true);
rmSetAreaCliffHeight(basecliffID54, 2, 0.1, 0.5);
//rmSetAreaBaseHeight(basecliffID54, 22.0);
rmSetAreaElevationVariation(basecliffID54, 3);
rmSetAreaLocation(basecliffID54, 0.5+rmXTilesToFraction(5), 0.5+rmXTilesToFraction(5));
rmAddAreaConstraint(basecliffID54, avoidKOTHshort);
rmAddAreaConstraint(basecliffID54, cliffAvoidTradeRoute);
rmAddAreaConstraint(basecliffID54, avoidPlayerCenter);
rmBuildArea(basecliffID54);

// Level 6

int fujiPeaklvl6 = rmCreateArea("fujiPeaklvl6");
rmSetAreaSize(fujiPeaklvl6, rmAreaTilesToFraction(120.0), rmAreaTilesToFraction(120.0));
rmSetAreaLocation(fujiPeaklvl6, 0.5, 0.5);
rmSetAreaTerrainType(fujiPeaklvl6, "lava\crater");
rmSetAreaBaseHeight(fujiPeaklvl6, 23.0);
rmAddAreaConstraint(fujiPeaklvl6, avoidKOTHshort);
rmAddAreaConstraint(fujiPeaklvl6, avoidPlayerCenter);
rmSetAreaCoherence(fujiPeaklvl6, .9);
rmBuildArea(fujiPeaklvl6);  

int fujiPeaklvl6Terrain = rmCreateArea("fujiPeaklvl6Terrain");
rmSetAreaSize(fujiPeaklvl6Terrain, rmAreaTilesToFraction(230.0), rmAreaTilesToFraction(230.0));
rmSetAreaLocation(fujiPeaklvl6Terrain, 0.5, 0.5);
rmSetAreaTerrainType(fujiPeaklvl6Terrain, "lava\crater");
rmSetAreaCoherence(fujiPeaklvl6Terrain, 1.0);
rmBuildArea(fujiPeaklvl6Terrain);

int fujiDip = rmCreateArea("fujiDip");
rmSetAreaSize(fujiDip, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaLocation(fujiDip, 0.5, 0.5);
rmSetAreaCliffType(fujiDip, "ZP Hawaii Crater");
rmSetAreaCliffPainting(fujiDip, false, true, true, 1.5, false);
rmSetAreaCliffHeight(fujiDip, -5, 0.1, 0.5);
rmSetAreaCliffEdge(fujiDip, 1, 1.0, 0.0, 1.0, 0);
//rmSetAreaTerrainType(fujiDip, "lava\lavaflow");
rmSetAreaCoherence(fujiDip, 1.0);
rmBuildArea(fujiDip);

int fujiDipTerrain1 = rmCreateArea("fujiDipTerrain1");
rmSetAreaSize(fujiDipTerrain1, rmAreaTilesToFraction(50.0), rmAreaTilesToFraction(50.0));
rmSetAreaLocation(fujiDipTerrain1, 0.5, 0.5);
rmSetAreaTerrainType(fujiDipTerrain1, "lava\crater_passable");
rmSetAreaCoherence(fujiDipTerrain1, 1.0);
rmBuildArea(fujiDipTerrain1);  

int fujiDipTerrain = rmCreateArea("fujiDipTerrain");
rmSetAreaSize(fujiDipTerrain, rmAreaTilesToFraction(25.0), rmAreaTilesToFraction(25.0));
rmSetAreaLocation(fujiDipTerrain, 0.5-rmXTilesToFraction(1), 0.5);
rmSetAreaTerrainType(fujiDipTerrain, "lava\lavaflow");
rmSetAreaCoherence(fujiDipTerrain, 1.0);
rmBuildArea(fujiDipTerrain);

// ------------------ Volcano Crater ---------------------------------------------------------------

int volcanoCraterID = -1;
volcanoCraterID = rmCreateGrouping("crater", "volcano_crater_noground");
rmPlaceGroupingAtLoc(volcanoCraterID, 1, 0.5-rmXTilesToFraction(1.0), 0.5, 1);

int volcanoAvoider = rmCreateObjectDef("ai avoider"); 
if (cNumberNonGaiaPlayers <= 2)
    rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderS", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 4)
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderM", 1, 0.0);
else if(cNumberNonGaiaPlayers <= 6)
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderL", 1, 0.0);
else
rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderXL", 1, 0.0);
rmPlaceObjectDefAtLoc(volcanoAvoider, 0, 0.5, 0.5);
 

// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.50);

/*vector stopperLoc1 = rmGetTradeRouteWayPoint(lavaflowID, 0.8);
rmPlaceObjectDefAtPoint(stopperID, 1, stopperLoc1);*/



/*int seaTerrain = rmCreateArea("seaTerrain");
rmSetAreaSize(seaTerrain, 0.5, 0.5);
rmSetAreaLocation(seaTerrain, 0.2, 0.5);
rmSetAreaTerrainType(seaTerrain, "caribbean\seafloor_coral0_crb");
rmSetAreaCoherence(seaTerrain, 1.0);
rmAddAreaConstraint(seaTerrain, avoidLand);
rmBuildArea(seaTerrain);*/

// Port Sites

   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.95-rmXTilesToFraction(25), 0.5);
   rmSetAreaMix(portSite1, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 2.5);
   rmAddAreaToClass(portSite1, classPortSite);
   rmBuildArea(portSite1);


   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.5,0.05+rmXTilesToFraction(25));
   rmSetAreaMix(portSite2, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 2.5);
   rmAddAreaToClass(portSite2, classPortSite);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaMix(portSite3, "Caribbean Ground 3");
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.5);
   rmAddAreaToClass(portSite3, classPortSite);
  rmSetAreaLocation(portSite3, 0.05+rmXTilesToFraction(25), 0.5);
  rmBuildArea(portSite3);

  int portSite4 = rmCreateArea ("port_site4");
  rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
  rmSetAreaLocation(portSite4, 0.5,0.95-rmXTilesToFraction(25));
  rmSetAreaMix(portSite4, "Caribbean Ground 3");
  rmSetAreaCoherence(portSite4, 1);
  rmSetAreaSmoothDistance(portSite4, 15);
  rmSetAreaBaseHeight(portSite4, 2.5);
  rmAddAreaToClass(portSite4, classPortSite);
  rmBuildArea(portSite4);
  

// Placing Player Trade Route Sockets

// Port 1
  int portID01 = rmCreateObjectDef("port 02");
  portID01 = rmCreateGrouping("portG 01", "Harbour_Center_NE");
  rmPlaceGroupingAtLoc(portID01, 0, 0.95-rmXTilesToFraction(12), 0.5);

  // Port 2
  int portID02 = rmCreateObjectDef("port 02");
  portID02 = rmCreateGrouping("portG 02", "Harbour_Center_SE");
  rmPlaceGroupingAtLoc(portID02, 0, 0.5,0.05+rmXTilesToFraction(12));

  // Port 3
  int portID03 = rmCreateObjectDef("port 03");
  portID03 = rmCreateGrouping("portG 03", "Harbour_Center_SW");
  rmPlaceGroupingAtLoc(portID03, 0, 0.05+rmXTilesToFraction(12), 0.5);

  // Port 4
  int portID04 = rmCreateObjectDef("port 04");
  portID04 = rmCreateGrouping("portG 04", "Harbour_Center_NW");
  rmPlaceGroupingAtLoc(portID04, 0, 0.5,0.95-rmXTilesToFraction(12));


// Maori Natives


    int caribs1VillageID = -1;
    int caribs1VillageType = rmRandInt(1,5);
    caribs1VillageID = rmCreateGrouping("caribs1 city", "maori_hawaii_0"+caribs1VillageType);
    rmAddGroupingConstraint(caribs1VillageID, avoidImpassableLand);
    //rmAddGroupingConstraint(caribs1VillageID, avoidHighMountainsFar);
    //rmAddGroupingConstraint(caribs1VillageID, avoidJesuit);
    rmSetGroupingMinDistance(caribs1VillageID, 0);
    rmSetGroupingMaxDistance(caribs1VillageID, 40);
    rmAddObjectDefConstraint(caribs1VillageID, avoidWater8);
    rmPlaceGroupingAtLoc(caribs1VillageID, 0, 0.8, 0.5, 1);
    //rmPlaceGroupingInArea(caribs1VillageID, 0, bigIslandID, 1);

    int caribs2VillageID = -1;
    int caribs2VillageType = rmRandInt(1,5);
    caribs2VillageID = rmCreateGrouping("caribs2 city", "maori_hawaii_0"+caribs2VillageType);
    rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
    //rmAddGroupingConstraint(caribs2VillageID, avoidHighMountainsFar);
    //rmAddGroupingConstraint(caribs2VillageID, avoidJesuit);
    rmSetGroupingMinDistance(caribs2VillageID, 0);
    rmSetGroupingMaxDistance(caribs2VillageID, 40);
    rmAddObjectDefConstraint(caribs2VillageID, avoidWater8);
    rmPlaceGroupingAtLoc(caribs2VillageID, 0, 0.2, 0.5, 1);
    //rmPlaceGroupingInArea(caribs2VillageID, 0, bigIslandID, 1);

    int caribs3VillageID = -1;
    int caribs3VillageType = rmRandInt(1,5);
    caribs3VillageID = rmCreateGrouping("caribs3 city", "maori_hawaii_0"+caribs3VillageType);
    rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
    //rmAddGroupingConstraint(caribs3VillageID, avoidTPLong);
    //rmAddGroupingConstraint(caribs3VillageID, avoidHighMountainsFar);
    rmAddGroupingConstraint(caribs3VillageID, avoidJesuitLong);
    rmAddGroupingConstraint(caribs3VillageID, avoidPirates);
    rmAddObjectDefConstraint(caribs3VillageID, avoidWater8);
    rmSetGroupingMinDistance(caribs3VillageID, 0);

        rmSetGroupingMaxDistance(caribs3VillageID, 40);
        rmPlaceGroupingAtLoc(caribs3VillageID, 0, 0.5, 0.2, 1);


    int caribs4VillageID = -1;
    int caribs4VillageType = rmRandInt(1,5);
    caribs4VillageID = rmCreateGrouping("caribs4 city", "maori_hawaii_0"+caribs4VillageType);
    rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
    //rmAddGroupingConstraint(caribs4VillageID, avoidTPLong);
    //rmAddGroupingConstraint(caribs4VillageID, avoidHighMountainsFar);
    rmAddGroupingConstraint(caribs4VillageID, avoidJesuitLong);
    rmAddGroupingConstraint(caribs4VillageID, avoidPirates);
    rmAddObjectDefConstraint(caribs4VillageID, avoidWater8);
    rmSetGroupingMinDistance(caribs4VillageID, 0);

        rmSetGroupingMaxDistance(caribs4VillageID, 40);
        rmPlaceGroupingAtLoc(caribs4VillageID, 0, 0.5, 0.8, 1);




// text
rmSetStatusText("",0.60);

//Place player TCs and starting Gold Mines. 

int TCID = rmCreateObjectDef("player TC");
if ( rmGetNomadStart())
    rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
else
    rmAddObjectDefItem(TCID, "townCenter", 1, 0);

//Prepare to place TCs
rmSetObjectDefMinDistance(TCID, 0.0);
rmSetObjectDefMaxDistance(TCID, 40.0);
rmSetObjectDefMaxDistance(TCID, avoidPirates);
rmAddObjectDefConstraint(TCID, avoidWokou);
rmAddObjectDefConstraint(TCID, avoidJesuit);
rmAddObjectDefConstraint(TCID, avoidWater8);

//Prepare to place Explorers, Explorer's dog, etc.
int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
rmSetObjectDefMinDistance(startingUnits, 8.0);
rmSetObjectDefMaxDistance(startingUnits, 12.0);
rmAddObjectDefConstraint(startingUnits, avoidAll);
rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

//Prepare to place player starting Mines 
int playerGoldID = rmCreateObjectDef("player silver");
rmAddObjectDefItem(playerGoldID, "zpJadeMine", 1, 0);
rmSetObjectDefMinDistance(playerGoldID, 12.0);
rmSetObjectDefMaxDistance(playerGoldID, 20.0);
rmAddObjectDefConstraint(playerGoldID, avoidAll);
rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

//Prepare to place player starting food
int playerFoodID=rmCreateObjectDef("player food");
rmAddObjectDefItem(playerFoodID, huntable1, 8, 4.0);
rmSetObjectDefMinDistance(playerFoodID, 10);
rmSetObjectDefMaxDistance(playerFoodID, 15);	
rmAddObjectDefConstraint(playerFoodID, avoidAll);
rmAddObjectDefConstraint(playerFoodID, avoidImpassableLand);
rmSetObjectDefCreateHerd(playerFoodID, true);

//Prepare to place player starting Berries
int playerBerriesID=rmCreateObjectDef("player berries");
rmAddObjectDefItem(playerBerriesID, "zpPineapleBush", 6, 4.0);
rmSetObjectDefMinDistance(playerBerriesID, 15);
rmSetObjectDefMaxDistance(playerBerriesID, 20);		
rmAddObjectDefConstraint(playerBerriesID, avoidAll);
rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);

//Prepare to place player starting trees
int StartAreaTreeID=rmCreateObjectDef("starting trees");
rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 12.0);
rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
rmSetObjectDefMinDistance(StartAreaTreeID, 10.0);
rmSetObjectDefMaxDistance(StartAreaTreeID, 17.0);

// Starting area nuggets
int playerNuggetID=rmCreateObjectDef("player nugget");
rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
rmSetObjectDefMinDistance(playerNuggetID, 10.0);
rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
rmAddObjectDefConstraint(playerNuggetID, avoidAll);
rmAddObjectDefConstraint(playerNuggetID, shortAvoidImpassableLand);

int waterSpawnPointID = 0;

// --------------- Make load bar move. ----------------------------------------------------------------------------`
rmSetStatusText("",0.70);

// *********** Place Home City Water Spawn Flag ***************************************************

rmClearClosestPointConstraints();


// Fake Frouping to fix the auto-grouping TC bug
int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.4, 0.4);

for(i=1; <cNumberPlayers) {

    int colonyShipID=rmCreateObjectDef("colony ship 2"+i);
    rmAddObjectDefItem(colonyShipID, "zpCatamaran", 1, 0.0);
    rmSetObjectDefMinDistance(colonyShipID, 0.0);
    rmSetObjectDefMaxDistance(colonyShipID, 10.0);

    // Place TC and starting units
    rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
    rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));    
    rmPlaceObjectDefAtLoc(playerFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
    rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 

    // Place player starting trees
    rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

    // Place starting nugget
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

    if(ypIsAsian(i) && rmGetNomadStart() == false)
    rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

    // Place water spawn points for the players along with a canoe
    waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
    rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);
    rmAddClosestPointConstraint(flagVsFlag);
    rmAddClosestPointConstraint(flagVsPirates1);
    rmAddClosestPointConstraint(flagVsPirates2);
    rmAddClosestPointConstraint(flagVsWokou1);
    rmAddClosestPointConstraint(flagVsWokou2);
    rmAddClosestPointConstraint(flagLand);
    rmAddClosestPointConstraint(avoidHighMountainsFar);
    rmAddClosestPointConstraint(flagEdgeConstraint);
    vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
    rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
    rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));

    rmClearClosestPointConstraints();
}

   

	
// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.75);

//rmClearClosestPointConstraints();

// ***************** SCATTERED RESOURCES **************************************
// Scattered FORESTS
int forestTreeID = 0;
numTries=15*cNumberNonGaiaPlayers;
int failCount=0;
for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
    rmSetAreaForestType(forest, forestType);
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
    rmAddAreaConstraint(forest, avoidPirates);
    rmAddAreaConstraint(forest, avoidWokou);
    rmAddAreaConstraint(forest, avoidKOTH);
    rmAddAreaConstraint(forest, avoidJesuit);
    rmAddAreaConstraint(forest, avoidTCLong);
    rmAddAreaConstraint(forest, avoidTP);
    rmAddAreaConstraint(forest, avoidTCMedium);
    rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
    rmAddAreaConstraint(forest, avoidHighMountains); 
    if(rmBuildArea(forest)==false) {
        // Stop trying once we fail 3 times in a row.
        failCount++;
        
        if(failCount==5)
        break;
    }

    else
        failCount=0; 
} 


    
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);


int jadeID = rmCreateObjectDef("random jade");
rmAddObjectDefItem(jadeID, "zpJadeMine", 1, 0);
rmSetObjectDefMinDistance(jadeID, 0.0);
rmSetObjectDefMaxDistance(jadeID, rmXFractionToMeters(0.3));
rmAddObjectDefConstraint(jadeID, avoidAll);
rmAddObjectDefConstraint(jadeID, avoidWater8);
rmAddObjectDefConstraint(jadeID, avoidGold);
rmAddObjectDefConstraint(jadeID, shortAvoidImpassableLand);
rmAddObjectDefConstraint(jadeID, avoidImportantItem);
rmAddAreaConstraint(jadeID, avoidJesuit);
rmAddObjectDefConstraint(jadeID, avoidCoin);
rmAddObjectDefConstraint(jadeID, avoidTP);
rmAddObjectDefConstraint(jadeID, avoidHighMountains);
rmPlaceObjectDefInArea(jadeID, 0, bonusIsland1, cNumberNonGaiaPlayers);
rmPlaceObjectDefInArea(jadeID, 0, bonusIsland2, cNumberNonGaiaPlayers);
rmPlaceObjectDefInArea(jadeID, 0, bonusIsland3, cNumberNonGaiaPlayers);
rmPlaceObjectDefInArea(jadeID, 0, bonusIsland4, cNumberNonGaiaPlayers);

// Scattered berries all over island
int berriesID=rmCreateObjectDef("random berries");
rmAddObjectDefItem(berriesID, "zpPineapleBush", rmRandInt(5,8), 4.0); 
rmSetObjectDefMinDistance(berriesID, 0.0);
rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.3));
rmAddObjectDefConstraint(berriesID, avoidTP);   
rmAddObjectDefConstraint(berriesID, avoidAll);
rmAddObjectDefConstraint(berriesID, avoidImportantItem);
rmAddObjectDefConstraint(berriesID, avoidHighMountains);
rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
rmAddObjectDefConstraint(berriesID, shortAvoidImpassableLand);
rmPlaceObjectDefInArea(berriesID, 0, bonusIsland1, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(berriesID, 0, bonusIsland2, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(berriesID, 0, bonusIsland3, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(berriesID, 0, bonusIsland4, cNumberNonGaiaPlayers/2);

// Huntables scattered on N side of island
int foodID1=rmCreateObjectDef("random food");
rmAddObjectDefItem(foodID1, huntable1, rmRandInt(6,7), 5.0);
rmSetObjectDefMinDistance(foodID1, 0.0);
rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
rmSetObjectDefCreateHerd(foodID1, true);
rmAddObjectDefConstraint(foodID1, avoidHuntable1);
rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
rmAddObjectDefConstraint(foodID1, avoidTP);
rmAddObjectDefConstraint(foodID1, avoidHighMountains);
rmAddObjectDefConstraint(foodID1, avoidImportantItem);
rmPlaceObjectDefInArea(foodID1, 0, bonusIsland1, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(foodID1, 0, bonusIsland2, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(foodID1, 0, bonusIsland3, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(foodID1, 0, bonusIsland4, cNumberNonGaiaPlayers/2);



// Define and place Nuggets

// Easier nuggets
int nugget1= rmCreateObjectDef("nugget easy"); 
rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(1, 2);
rmSetObjectDefMinDistance(nugget1, 0.0);
rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.3));
rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget1, avoidNugget);
rmAddObjectDefConstraint(nugget1, avoidImportantItem);
rmAddObjectDefConstraint(nugget1, avoidTP);
rmAddObjectDefConstraint(nugget1, avoidAll);
rmAddObjectDefConstraint(nugget1, avoidJesuit);
rmAddObjectDefConstraint(nugget1, avoidHighMountains);
rmAddObjectDefConstraint(nugget1, avoidWater8);
rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
for (i=0; <cNumberPlayers)
{
    rmPlaceObjectDefInArea(nugget1, 0, rmAreaID("player "+i), 2);
}

// Water nuggets
int nuggetCount = 2;

int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(6, 6);
rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nugget2b, avoidLand);
rmAddObjectDefConstraint(nugget2b, avoidNuggetWater2);
rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount/2);

int nugget2= rmCreateObjectDef("nugget water" + i); 
rmAddObjectDefItem(nugget2, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(5, 5);
rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.0));
rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nugget2, avoidLand);
rmAddObjectDefConstraint(nugget2, avoidNuggetWater);
rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
rmPlaceObjectDefPerPlayer(nugget2, false, nuggetCount);

// really tough nuggets confined to south central cliffy area
int nugget3= rmCreateObjectDef("nugget hardest"); 
rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
rmSetNuggetDifficulty(3, 4);
rmSetObjectDefMinDistance(nugget3, 0.0);
rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.3));
rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
rmAddObjectDefConstraint(nugget3, avoidHardNugget);
rmAddObjectDefConstraint(nugget3, avoidHighMountains);
rmAddObjectDefConstraint(nugget3, avoidJesuit);
rmAddObjectDefConstraint(nugget3, avoidImportantItem);
rmAddObjectDefConstraint(nugget3, avoidCoinShort);
rmPlaceObjectDefInArea(nugget3, 0, bonusIsland1, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(nugget3, 0, bonusIsland2, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(nugget3, 0, bonusIsland3, cNumberNonGaiaPlayers/2);
rmPlaceObjectDefInArea(nugget3, 0, bonusIsland4, cNumberNonGaiaPlayers/2);

// --------------- Make load bar move. ----------------------------------------------------------------------------
rmSetStatusText("",0.90);

//Place random whales everywhere --------------------------------------------------------
int whaleID=rmCreateObjectDef("whale");
rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.08));
rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.17));
rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
rmAddObjectDefConstraint(whaleID, whaleLand);
rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

int fishID=rmCreateObjectDef("fish 1");
rmAddObjectDefItem(fishID, fish1, 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fishID, avoidFish1);
rmAddObjectDefConstraint(fishID, fishVsWhaleID);
rmAddObjectDefConstraint(fishID, fishLand);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

int fish2ID=rmCreateObjectDef("fish 2");
rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
rmSetObjectDefMinDistance(fish2ID, 0.0);
rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fish2ID, avoidFish2);
rmAddObjectDefConstraint(fish2ID, avoidFish1);
rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
rmAddObjectDefConstraint(fish2ID, fishLand);
rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);

if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
{
    rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
}

/*int randomTreeID=rmCreateObjectDef("random tree");
rmAddObjectDefItem(randomTreeID, "treeAmazon", 1, 0.0);
rmSetObjectDefMinDistance(randomTreeID, 0.0);
rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
rmAddObjectDefConstraint(randomTreeID, avoidAll); 

rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);*/


// ------Triggers------------------------------------------------------------------------------------//

int tch0=1671; // tech operator

int eruptionLenght = 140;
int eqAreaDamage = 20;
int islandSize = 200;
int gapMin = 700;
int gapMax = 1200;
int eruptionBreakInitial = 720;
int eruptionBreakInitialLong = 960;
int eruptionBreak1 = rmRandInt(gapMin,gapMax);
int eruptionBreak2 = rmRandInt(gapMin,gapMax);
int eruptionBreak3 = rmRandInt(gapMin,gapMax);
int eruptionBreak4 = rmRandInt(gapMin,gapMax);
int eruptionBreak5 = rmRandInt(gapMin,gapMax);

string volcanoID = "0";
string pirate1Socket = "5";
string pirate2Socket = "41";
string pirate1ID = "6";
string pirate2ID = "65";
string wokou1ID = "97";
string wokou2ID = "113";

if (cNumberNonGaiaPlayers == 1){
pirate1ID = "6";
pirate2ID = "65";
wokou1ID = "97";
wokou2ID = "113";
volcanoID = "270";
}
if (cNumberNonGaiaPlayers == 2){
pirate1ID = "7";
pirate2ID = "66";
wokou1ID = "98";
wokou2ID = "114";
volcanoID = "271";
}
if (cNumberNonGaiaPlayers == 3){
pirate1ID = "8";
pirate2ID = "67";
wokou1ID = "99";
wokou2ID = "115";
volcanoID = "272";
}
if (cNumberNonGaiaPlayers == 4){
pirate1ID = "9";
pirate2ID = "68";
wokou1ID = "100";
wokou2ID = "116";
volcanoID = "273";
}
if (cNumberNonGaiaPlayers == 5){
pirate1ID = "10";
pirate2ID = "69";
wokou1ID = "101";
wokou2ID = "117";
volcanoID = "274";
}
if (cNumberNonGaiaPlayers == 6){
pirate1ID = "11";
pirate2ID = "70";
wokou1ID = "102";
wokou2ID = "118";
volcanoID = "275";
}
if (cNumberNonGaiaPlayers == 7){
pirate1ID = "12";
pirate2ID = "71";
wokou1ID = "103";
wokou2ID = "119";
volcanoID = "276";
}
if (cNumberNonGaiaPlayers == 8){
pirate1ID = "13";
pirate2ID = "72";
wokou1ID = "104";
wokou2ID = "120";
volcanoID = "277";
}

if (cNumberNonGaiaPlayers <=6) {
  eruptionLenght = 120;
  islandSize = 180;
  eqAreaDamage = 24;
}

if (cNumberNonGaiaPlayers <=4) {
  eruptionLenght = 100;
  islandSize = 160;
  eqAreaDamage = 30;
}

if (cNumberNonGaiaPlayers <=2) {
  eruptionLenght = 80;
  islandSize = 120;
  eqAreaDamage = 40;
}

// Volcano trigger definition
rmCreateTrigger("Volcano_Counter_Hard");
rmCreateTrigger("Volcano_Counter_Easy");
rmCreateTrigger("Volcano_StartInitial");
rmCreateTrigger("Volcano_Start1");
rmCreateTrigger("Volcano_Start2");
rmCreateTrigger("Volcano_Start3");
rmCreateTrigger("Volcano_Start4");
rmCreateTrigger("Volcano_Start5");

rmCreateTrigger("Volcano_Lava");
rmCreateTrigger("Volcano_Lava_Death");
rmCreateTrigger("Volcano_Lava_Delay1");
rmCreateTrigger("Volcano_Lava_Delay2");
rmCreateTrigger("Volcano_Lava_Delay3");
rmCreateTrigger("Volcano_Lava_Delay4");
rmCreateTrigger("Volcano_Lava_Delay5");
rmCreateTrigger("Volcano_Lava_Transform");

rmCreateTrigger("Volcano_Short");
rmCreateTrigger("Volcano_Short2");
rmCreateTrigger("Volcano_Medium");
rmCreateTrigger("Volcano_Long");
rmCreateTrigger("Volcano_UltraLong");
rmCreateTrigger("Volcano_XXLong");
rmCreateTrigger("Volcano_Stop");
rmCreateTrigger("Volcano_Damage");

rmCreateTrigger("Volcano_Music1");
rmCreateTrigger("Volcano_Music2");
rmCreateTrigger("Volcano_Music3");
rmCreateTrigger("Volcano_MusicEnd");

// Volcano Music

rmSwitchToTrigger(rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\BubbleChum.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",4.0);
rmAddTriggerEffect("Sound Timer");
rmSetTriggerEffectParamInt("Time", 50000);
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Music2"));
rmAddTriggerEffect("Music Filename");
rmSetTriggerEffectParam("Music","music\battle\CamelsStrawsAndBacks.mp3"); // Music Filename
rmSetTriggerEffectParamFloat("Duration",2.0);
if (cNumberNonGaiaPlayers >=6){
  rmAddTriggerEffect("Sound Timer");
  rmSetTriggerEffectParamInt("Time", 60000);
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
}
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

if (cNumberNonGaiaPlayers >=6){
  rmSwitchToTrigger(rmTriggerID("Volcano_Music3"));
  rmAddTriggerEffect("Music Filename");
  rmSetTriggerEffectParam("Music","music\battle\Ruinion.mp3"); // Music Filename
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerPriority(1);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(false);
  rmSetTriggerLoop(false);
}

rmSwitchToTrigger(rmTriggerID("Volcano_MusicEnd"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Music Play");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

// Volcano Area Damage

rmSwitchToTrigger(rmTriggerID("Volcano_Damage"));
for(i=1; <= cNumberNonGaiaPlayers) {
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Unit");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",eqAreaDamage);
  rmAddTriggerEffect("Damage Units in Area");
  rmSetTriggerEffectParam("SrcObject",volcanoID);
  rmSetTriggerEffectParamInt("Player",i);
  rmSetTriggerEffectParam("UnitType","Building");
  rmSetTriggerEffectParamFloat("Dist",islandSize);
  rmSetTriggerEffectParamFloat("Damage",20*eqAreaDamage);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano random starts

rmSwitchToTrigger(rmTriggerID("Volcano_Counter_Hard"));
rmAddTriggerCondition("Difficulty Level");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Level",3);
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoCounter");
rmSetTriggerEffectParamInt("Start", eruptionBreakInitial);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano erupts in");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_StartInitial"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Counter_Easy"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Counter_Easy"));
rmAddTriggerCondition("Difficulty Level");
rmSetTriggerConditionParam("Op","<");
rmSetTriggerConditionParamInt("Level",3);
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoCounter");
rmSetTriggerEffectParamInt("Start", eruptionBreakInitialLong);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano erupts in");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_StartInitial"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Counter_Hard"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_StartInitial"));
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start1"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start2"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start2"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start3"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start3"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak3);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start4"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start4"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak4);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start5"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Start5"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",eruptionBreak5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","carribean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",3.0);
rmSetTriggerEffectParamFloat("Strength",0.4);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Counter:Add Timer");
rmSetTriggerEffectParam("Name","VolcanoEruption");
rmSetTriggerEffectParamInt("Start",eruptionLenght);
rmSetTriggerEffectParamInt("Stop",0);
rmSetTriggerEffectParam("Msg", "Volcano eruption");
rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("Message","The Volcano is waking up!");
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano Lava Flow

rmSwitchToTrigger(rmTriggerID("Volcano_Lava"));

rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",4);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",5);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay1"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Death"));
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","Eruption");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",4);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",5);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","WesternEurope");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay1"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",20);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Chinese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay2"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay2"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon2");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",20);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Japanese");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay3"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay3"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon3");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",20);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Indian");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay4"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay4"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon4");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",20);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","Mediterranean");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay5"));
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay5"));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",volcanoID);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon5");
rmSetTriggerConditionParamInt("Dist",12.0);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",20);

rmAddTriggerEffect("Player : Override Culture for Art");
rmSetTriggerEffectParamInt("Player",0);
rmSetTriggerEffectParam("Culture","EasternEurope");
rmSetTriggerPriority(1);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Transform"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",15);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoLavaBack");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(false);
rmSetTriggerLoop(false);

// Volcano Eruption Phases

rmSwitchToTrigger(rmTriggerID("Volcano_Short"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort"); 
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Medium"));
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",2.0);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Volcano_Medium"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeMedium");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",2.0);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
if (cNumberNonGaiaPlayers <=2){
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
}
else{
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Long"));
}
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

if (cNumberNonGaiaPlayers >=3){
  rmSwitchToTrigger(rmTriggerID("Volcano_Long"));
  rmAddTriggerCondition("Timer");
  rmSetTriggerConditionParamInt("Param1",20);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",0);
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeLong");
  rmSetTriggerEffectParamInt("Status",2);
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  if (cNumberNonGaiaPlayers <=4){
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
  }
  else{
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_UltraLong"));
  }
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
  rmSetTriggerPriority(4);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(true);
  rmSetTriggerLoop(false);
}

if (cNumberNonGaiaPlayers >=5){
  rmSwitchToTrigger(rmTriggerID("Volcano_UltraLong"));
  rmAddTriggerCondition("Timer");
  rmSetTriggerConditionParamInt("Param1",20);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",0);
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeUltraLong");
  rmSetTriggerEffectParamInt("Status",2);
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
   if (cNumberNonGaiaPlayers <=6){
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
  }
  else{
    rmAddTriggerEffect("Fire Event");
    rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_XXLong"));
  }
  rmSetTriggerPriority(4);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(true);
  rmSetTriggerLoop(false);
}

if (cNumberNonGaiaPlayers >=7){
  rmSwitchToTrigger(rmTriggerID("Volcano_XXLong"));
  rmAddTriggerCondition("Timer");
  rmSetTriggerConditionParamInt("Param1",20);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",0);
  rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeXXLong");
  rmSetTriggerEffectParamInt("Status",2);
  rmAddTriggerEffect("Shake Camera");
  rmSetTriggerEffectParamFloat("Duration",2.0);
  rmSetTriggerEffectParamFloat("Strength",0.2);
  rmAddTriggerEffect("Play Soundset");
  rmSetTriggerEffectParam("Soundset","Earthquake");
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
  rmAddTriggerEffect("Fire Event");
  rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
  rmSetTriggerPriority(4);
  rmSetTriggerActive(false);
  rmSetTriggerRunImmediately(true);
  rmSetTriggerLoop(false);
}

rmSwitchToTrigger(rmTriggerID("Volcano_Short2"));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",20);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",1.5);
rmSetTriggerEffectParamFloat("Strength",0.2);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Transform"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Volcano stop

rmSwitchToTrigger(rmTriggerID("Volcano_Stop"));
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpVolcanoPassive"); // Desctivates Volcano
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start"));
rmAddTriggerEffect("Set Lighting");
rmSetTriggerEffectParam("SetName","age304_caribbean");
rmSetTriggerEffectParamFloat("FadeTime",5.0);
rmAddTriggerEffect("Shake Camera");
rmSetTriggerEffectParamFloat("Duration",1.0);
rmSetTriggerEffectParamFloat("Strength",0.1);
rmAddTriggerEffect("Play Soundset");
rmSetTriggerEffectParam("Soundset","Earthquake");
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("FadeOutMusic");
rmSetTriggerEffectParamFloat("Duration",4.0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_MusicEnd"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Update Sockets

rmCreateTrigger("I Update Sockets");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingGalleon");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Sockets");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingFluyt");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Starter shipment triggers
for(i = 1; < cNumberPlayers) {
rmCreateTrigger("XP"+i);
rmSwitchToTrigger(rmTriggerID("XP"+i));
rmSetTriggerPriority(1); 
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmAddTriggerCondition("Always");

rmAddTriggerEffect("Grant Resources");
rmSetTriggerEffectParamInt("PlayerID", i, false);
rmSetTriggerEffectParam("ResName", "Ships", false);
rmSetTriggerEffectParam("Amount", "1", false);
}

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
rmSetTriggerEffectParam("TechID","cTechzpOceaniaMercenaries"); // Mercenary
rmSetTriggerEffectParamInt("Status",2);
}
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","Eruption");
rmSetTriggerEffectParamInt("Value",1);
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Wokou"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Update ports

rmCreateTrigger("I Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingGalleon");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","deTradingFluyt");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

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
rmSetTriggerConditionParam("DstObject",pirate2ID);
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
rmSetTriggerConditionParamInt("Param1",1200);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPirateSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPirateSteamer2"); //operator
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
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",pirate2ID);
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
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCFlyingDutchmanProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainFlyingDutchman2"); //operator
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
rmSetTriggerConditionParamInt("Param1",1200);
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


for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Pirates2on Player"+k);
rmCreateTrigger("Pirates2off Player"+k);

rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate2ID);
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
rmSetTriggerConditionParam("DstObject",pirate2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",pirate2ID);
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


rmCreateTrigger("TrainJunk2ON Plr"+k);
rmCreateTrigger("TrainJunk2OFF Plr"+k);
rmCreateTrigger("TrainJunk2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouJunkProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk2OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainJunk2TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpWokouJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouJunk2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


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

rmCreateTrigger("trainFuchuan2ON Plr"+k);
rmCreateTrigger("trainFuchuan2OFF Plr"+k);
rmCreateTrigger("trainFuchuan2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("trainFuchuan2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSPCPrauProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainFuchuan2OFF_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1", 1200);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("trainFuchuan2TIME_Plr"+k));
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamFloat("Param1",200);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpFireJunkBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

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
rmSetTriggerConditionParamInt("Param1", 1200);
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
rmSetTriggerEffectParam("TechID","cTechzpTrainPrau1"); //operator
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
rmCreateTrigger("Wokou2on Player"+k);
rmCreateTrigger("Wokou2off Player"+k);

rmSwitchToTrigger(rmTriggerID("Wokou2on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou2ID);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou2off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Wokou2off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",wokou2ID);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",wokou2ID);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Wokou2on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainJunk2ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
rmSetTriggerPriority(4);
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


    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);
}