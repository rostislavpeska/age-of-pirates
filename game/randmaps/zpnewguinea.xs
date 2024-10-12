/* 
=========================================
New Guinea
by dansil92
Sept 20 2024
=========================================
*/


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {

rmSetStatusText("",0.01);
// Picks the map size
int playerTiles=25000;
if (cNumberNonGaiaPlayers > 4){
	playerTiles = 18000;
}
else if (cNumberNonGaiaPlayers > 6){
	playerTiles = 13000;
}
	
int size = 2.0 * sqrt(cNumberNonGaiaPlayers*playerTiles);
rmSetMapSize(size, size);

rmSetSeaType("ZP New Guinea");
//	rmSetSeaType("Texas Pond");
// 	rmSetBaseTerrainMix("amazon grass");
rmSetMapType("newguinea");
rmSetMapType("grass");
rmSetMapType("water");
rmSetWorldCircleConstraint(true);
rmSetLightingSet("rm_bahia");
//rmSetOceanReveal(true);
rmEnableLocalWater(true);

// Init map.
rmTerrainInitialize("water");

rmDefineClass("classForest");
rmDefineClass("classPlateau");
rmSetGlobalRain( 0.7 );
rmSetSeaLevel(-1.6);




//Constraints
int avoidPlateau= rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);
int avoidPlateauSPC= rmCreateClassDistanceConstraint("nats avoid tcs", rmClassID("classPlateau"), 35);


int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0+cNumberNonGaiaPlayers);
int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);

int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 50.0);
int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 11.0);
int avoidGold=rmCreateTypeDistanceConstraint("avoid coin", "mineGold", 11.0);
int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "mineGold", 52.0);
int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 3.0);

int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 20.0+cNumberNonGaiaPlayers);
int avoidTradeRouteXS = rmCreateTradeRouteDistanceConstraint("objects avoid trade route XS", 6.0+cNumberNonGaiaPlayers);
int avoidTradeRouteFixed = rmCreateTradeRouteDistanceConstraint("objects avoid trade route fixed", 13);
int avoidTradeRouteFish = rmCreateTradeRouteDistanceConstraint("fish avoid trade route small", 5.0);

int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);

int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 42.0);  

int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18.0);
int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
int flagVsWokou1 = rmCreateTypeDistanceConstraint("flag avoid wokou1", "zpWokouWaterSpawnFlag1", 15);
int flagVsWokou2 = rmCreateTypeDistanceConstraint("flag avoid wokou2", "zpWokouWaterSpawnFlag2", 15);
int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid other", "HomeCityWaterSpawnFlag", 15);
int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketWokou", 40.0+cNumberNonGaiaPlayers*4);
int avoidPiratesShort=rmCreateTypeDistanceConstraint("avoid socket pirates short", "zpSocketWokou", 15.0);
int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 20.0);
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);

int PlayerNum = cNumberNonGaiaPlayers;
int TeamNum = cNumberTeams;
int numPlayer = cNumberPlayers;

int mapVariant = rmRandInt(1, 2);
    
// =============Player placement ======================= 
float spawnSwitch = rmRandFloat(0,1.2);
if (mapVariant==1)
	float twoPlayerZ = rmRandFloat(0.4,0.7);
else
	twoPlayerZ = rmRandFloat(0.3,0.6);


if (cNumberTeams == 2){
	if (spawnSwitch <=0.6){

		if (PlayerNum == 2){
			rmPlacePlayer(1, 0.18, twoPlayerZ);
			rmPlacePlayer(2, 0.82, twoPlayerZ);	
		}
		else if (mapVariant == 1){
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.7, 0.9);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.1, 0.3);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}
		else {
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.2, 0.4);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.6, 0.8);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}
	}

	else if(spawnSwitch <=1.2){

		if (PlayerNum == 2)
		{
			rmPlacePlayer(2, 0.18, twoPlayerZ);
			rmPlacePlayer(1, 0.82, twoPlayerZ);	
		}
		else if (mapVariant == 1){
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.7, 0.9);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.1, 0.3);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}
		else {
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.6, 0.8);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.2, 0.4);
			rmPlacePlayersCircular(0.35, 0.35, 0.02);
		}

	}
}

else {
	if (mapVariant == 1){
		rmSetPlacementSection(0.7, 0.3);
		rmPlacePlayersCircular(0.36, 0.36, 0.02);
	}
	else	{
		rmSetPlacementSection(0.2, 0.8);
		rmPlacePlayersCircular(0.36, 0.36, 0.02);
	}
}
	
chooseMercs();
rmSetStatusText("",0.1); 


//===========trade route=================
//trade route spawns first to avoid terrain conflicts and to define continent2 spawn
//routez is central coordinate
//routecurve defines how flat or rounded the route is
float routeZ = rmRandFloat(0.2,0.25);
float routeCurve = rmRandFloat(0.15,0.19);

int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
rmSetObjectDefAllowOverlap(socketID, true);
rmSetObjectDefMinDistance(socketID, 0.0);
rmSetObjectDefMaxDistance(socketID, 6.0);      

int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

if (mapVariant == 1){
	rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.15);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.22);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.15);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.0);
}
else {
	rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 1.0);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.78);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.85);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 1.0);
}



rmBuildTradeRoute(tradeRouteID, "water_trail");


//===================================================

float waterHeight = rmRandFloat(0.6,0.9);

//build land into the water. height variation here is what builds the various random islands and continent
//water height can vary slightly between more water (and less natives/res)
//or more islands and less passable areas

int continent2 = rmCreateArea("continent");
if (cNumberNonGaiaPlayers<=2)
	rmSetAreaSize(continent2, 0.53, 0.53);
else
	rmSetAreaSize(continent2, 0.55, 0.55);
rmSetAreaLocation(continent2, 0.5, 0.5);
rmSetAreaMix(continent2, "borneo_grass_a");
rmSetAreaBaseHeight(continent2, waterHeight);
rmSetAreaCoherence(continent2, 0.9);
rmSetAreaSmoothDistance(continent2, 7);
rmSetAreaHeightBlend(continent2, 1);
rmSetAreaElevationNoiseBias(continent2, 0);
rmSetAreaElevationEdgeFalloffDist(continent2, 6);
rmSetAreaElevationVariation(continent2, 7);
rmSetAreaElevationPersistence(continent2, .4);
rmSetAreaElevationOctaves(continent2, 5);
rmSetAreaElevationMinFrequency(continent2, 0.02);
rmSetAreaElevationType(continent2, cElevTurbulence); 
rmAddAreaConstraint(continent2, avoidTradeRouteSmall);
rmSetAreaObeyWorldCircleConstraint(continent2, false);
rmBuildArea(continent2);    

//extra constraints

int classPatch = rmDefineClass("patch");
int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 12.0);
int classCenter = rmDefineClass("center");
int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 2.0);
int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
  

//build central map area
//centreplacement controls where the main island is along the z axis
//size is quite variable and determines how large the central portion is guaranteed to be minimum

if (mapVariant == 1)
	float centrePlacement = rmRandFloat(0.4,0.7);
else
	centrePlacement = rmRandFloat(0.3,0.6);


int center = rmCreateArea("center");
//rmAddAreaToClass(center, rmClassID("center"));
rmSetAreaSize(center, .04, .09);
rmSetAreaLocation(center, 0.5, centrePlacement);
rmSetAreaBaseHeight(center, 1.0);
rmSetAreaCoherence(center, 0.7);
rmSetAreaMix(center, "borneo_grass_a");
rmSetAreaSmoothDistance(center, 10);
rmSetAreaHeightBlend(center, 1);
rmSetAreaElevationNoiseBias(center, 0);
rmSetAreaElevationEdgeFalloffDist(center, 6);
rmSetAreaElevationVariation(center, 3);
rmSetAreaElevationPersistence(center, .4);
rmSetAreaElevationOctaves(center, 5);
rmSetAreaElevationMinFrequency(center, 0.02);
rmAddAreaConstraint(center, avoidTradeRouteSmall);

rmBuildArea(center);   


rmSetStatusText("",0.2);


/*
========================================
LAND FOR TCS, CONNECT TO CENTRE
========================================				
*/

//connection point placed at centreplacement to get consistent results without deforming the above landform

int connectionPoint=rmCreateArea("connectionPoint");
rmSetAreaLocation(connectionPoint, 0.5, centrePlacement); 
//rmSetAreaTerrainType(connectionPoint, "Amazon\ground4_ama");      
rmSetAreaSize(connectionPoint, .002, .002); 
rmSetAreaBaseHeight(connectionPoint, 1.7);
rmSetAreaHeightBlend(connectionPoint, 2);
rmSetAreaCoherence(connectionPoint, 0.9);
//rmBuildArea(connectionPoint);


//place player areas
for(i=1; < cNumberNonGaiaPlayers + 1) {

	int PlayerArea1 = rmCreateArea("NeedLand1"+i);
	rmSetAreaSize(PlayerArea1, rmAreaTilesToFraction(1030), rmAreaTilesToFraction(1030));
	rmSetAreaBaseHeight(PlayerArea1, 1.0);
	rmAddAreaToClass(PlayerArea1, rmClassID("classPlateau"));
	rmSetAreaMix(PlayerArea1, "borneo_grass_a");
	//        rmSetAreaTerrainType(PlayerArea1, "sonora\ground7_son");
	rmSetAreaHeightBlend(PlayerArea1, 1);
	rmSetAreaLocation(PlayerArea1, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmSetAreaCoherence(PlayerArea1, 0.7);
	rmBuildArea(PlayerArea1);

	//********* build connections**********

	int connection1	= rmCreateConnection("make paths centre"+i);
	rmSetConnectionType(connection1, cConnectAreas, false, 1.0);
	rmAddConnectionArea(connection1, PlayerArea1);
	rmAddConnectionArea(connection1, connectionPoint);
	rmSetConnectionPositionVariance(connection1, 0.0);
	rmSetConnectionBaseHeight(connection1, 1.7);
	rmSetConnectionCoherence(connection1, 0.8);
	rmSetConnectionHeightBlend(connection1, 1);
	rmSetConnectionSmoothDistance(connection1, 10);
	rmSetConnectionWidth(connection1, 18+cNumberNonGaiaPlayers, 1.0);
	rmAddConnectionToClass(connection1, rmClassID("center"));
	rmBuildConnection(connection1);

} //dont touch, it works

rmSetStatusText("",0.3);


//=================end connections/landforms=============		

//island to avoid tp route, ignore circle constraint to avoid border at map edge.

//===================forced tp line island======
				
int southIsland=rmCreateArea("southIsland");
if (mapVariant == 1)
	rmSetAreaLocation(southIsland, 0.5, 0.05);
else
	rmSetAreaLocation(southIsland, 0.5, 0.95);
rmSetAreaMix(southIsland, "borneo_grass_a");
//rmAddAreaInfluenceSegment(southIsland, 0.2, 0.0, 0.8, 0.0);
rmAddAreaToClass(southIsland, rmClassID("center"));
//rmSetAreaMix(southIsland, "africa rainforest grass dry");

rmSetAreaSize(southIsland, .10, .11);      
rmSetAreaBaseHeight(southIsland, 1.0);
rmAddAreaConstraint(southIsland, avoidTradeRouteFixed);
rmSetAreaObeyWorldCircleConstraint(southIsland, false);

rmSetAreaCoherence(southIsland, .92);
rmBuildArea(southIsland);

//====================================================
//random lakes to enable fish to spawn (I hate this too)
//because the mainland is spawned over water, small added ponds are required for fish to populate properly
//small ponds avoid each other and land

int lakeLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 3.0);

for (j=0; < (50*cNumberNonGaiaPlayers)) {   
	int ffaCliffs = rmCreateArea("ffaCliffs"+j);
	rmSetAreaSize(ffaCliffs, rmAreaTilesToFraction(10), rmAreaTilesToFraction(12));
	rmAddAreaToClass(ffaCliffs, rmClassID("classPlateau"));
	//		rmAddAreaToClass(ffaCliffs, rmClassID("center"));
	rmSetAreaWaterType(ffaCliffs, "ZP New Guinea");
	rmAddAreaConstraint(ffaCliffs, avoidPlateau);
	rmAddAreaConstraint(ffaCliffs, circleConstraint2);
	rmAddAreaConstraint(ffaCliffs, lakeLand);
	rmAddAreaConstraint(ffaCliffs, avoidTradeRouteSmall);
	rmSetAreaCoherence(ffaCliffs, 1.0);
	rmBuildArea(ffaCliffs);  
}

//=======================================================


// BUILD NATIVE SITES

//Choose Natives
int subCiv0=-1;
int subCiv1=-1;
int subCiv2=-1;
int subCiv3=-1;

if (rmAllocateSubCivs(4) == true)
{
	subCiv0=rmGetCivID("Korowai");
	rmEchoInfo("subCiv0 is Korowai "+subCiv0);
	if (subCiv0 >= 0)
		rmSetSubCiv(0, "Korowai");

	subCiv1=rmGetCivID("Wokou");
	rmEchoInfo("subCiv1 is Wokou "+subCiv1);
	if (subCiv1 >= 0)
			rmSetSubCiv(1, "Wokou");
	
	if (mapVariant ==1) {
		subCiv2=rmGetCivID("SPCSufi");
		rmEchoInfo("subCiv2 is SPCSufi "+subCiv3);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "SPCSufi");
	}
	else {
		subCiv2=rmGetCivID("SPCJesuit");
		rmEchoInfo("subCiv2 is SPCJesuit "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "SPCJesuit");
	}
}

// ******************* Place Wokou **************************

// Wokou sites

int wokouSite1 = rmCreateArea("wokouSite1");
rmSetAreaSize(wokouSite1, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
if (mapVariant == 1){
	if (cNumberNonGaiaPlayers<=2)
		rmSetAreaLocation(wokouSite1, 0.3, 0.3);
	else
		rmSetAreaLocation(wokouSite1, 0.3, 0.25);
}
else{
	if (cNumberNonGaiaPlayers<=2)
		rmSetAreaLocation(wokouSite1, 0.3, 0.7);
	else
		rmSetAreaLocation(wokouSite1, 0.3, 0.75);
}
rmSetAreaBaseHeight(wokouSite1, 1.0);
rmSetAreaMix(wokouSite1, "borneo_grass_a");
rmSetAreaCoherence(wokouSite1, 0.99);
rmSetAreaSmoothDistance(wokouSite1, 10);
rmSetAreaHeightBlend(wokouSite1, 1);
rmSetAreaElevationNoiseBias(wokouSite1, 0);
rmSetAreaElevationVariation(wokouSite1, 0);
//rmAddAreaConstraint(wokouSite1, avoidTradeRouteXS);
rmBuildArea(wokouSite1);  

int wokouSite2 = rmCreateArea("wokouSite2");
rmSetAreaSize(wokouSite2, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
if (mapVariant == 1){
	if (cNumberNonGaiaPlayers<=2)
		rmSetAreaLocation(wokouSite2, 0.7, 0.3);
	else
		rmSetAreaLocation(wokouSite2, 0.7, 0.25);
}
else{
	if (cNumberNonGaiaPlayers<=2)
		rmSetAreaLocation(wokouSite2, 0.7, 0.7);
	else
		rmSetAreaLocation(wokouSite2, 0.7, 0.75);
}
rmSetAreaBaseHeight(wokouSite2, 1.0);
rmSetAreaMix(wokouSite2, "borneo_grass_a");
rmSetAreaCoherence(wokouSite2, 0.99);
rmSetAreaSmoothDistance(wokouSite2, 10);
rmSetAreaHeightBlend(wokouSite2, 1);
rmSetAreaElevationNoiseBias(wokouSite2, 0);
rmSetAreaElevationVariation(wokouSite2, 0);
//rmAddAreaConstraint(wokouSite2, avoidTradeRouteXS);
rmBuildArea(wokouSite2);  

// Place Controllers

int controllerID1 = rmCreateObjectDef("Controler 1");
rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);

int controllerID2 = rmCreateObjectDef("Controler 2");
rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);

if (mapVariant == 1){
	if (cNumberNonGaiaPlayers<=2){
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3, 0.3);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.7, 0.3);
	}
	else{
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3, 0.25);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.7, 0.25);
	}
}
else{
	if (cNumberNonGaiaPlayers<=2){
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3, 0.7);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.7, 0.7);
	}
	else{
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.3, 0.75);
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.7, 0.75);
	}
}

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

// Wokou Village 1

int piratesVillageID = -1;
piratesVillageID = rmCreateGrouping("pirate city", "Wokou_Village_01");

rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
rmAddObjectDefItem(piratewaterflagID1, "zpWokouWaterSpawnFlag1", 1, 1.0);
if (mapVariant == 1)
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)+10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)-27));
else
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)+10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)+27));

int pirateportID1 = -1;
pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
if (mapVariant == 1)
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)-25));
else
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)+27));

// Wokou Village 2

int piratesVillageID2 = -1;
piratesVillageID2 = rmCreateGrouping("pirate city2", "Wokou_Village_02");

rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
rmAddObjectDefItem(piratewaterflagID2, "zpWokouWaterSpawnFlag2", 1, 1.0);
if (mapVariant == 1)
	rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)-10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)-27));
else
	rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)-10), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)+27));

int pirateportID2 = -1;
pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
if (mapVariant == 1)
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)-25));
else
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)+27));

// *********************** Additional Natives *************************
	
// Set up additional Natives	
int nativeID0 = -1;
int nativeID1 = -1;
int nativeID2 = -1;
int nativeID3 = -1;
int nativeID4 = -1;

int jesuitID0 = -1;
int jesuitID1 = -1;

int natDistance = cNumberNonGaiaPlayers*4;
int avoidNatives = rmCreateClassDistanceConstraint("natives avoid natives", rmClassID("patch"), 35+natDistance);

int nativeID0Type = rmRandInt(1,2);
nativeID0 = rmCreateGrouping("native site 0", "Korowai_Village_0"+nativeID0Type);
rmSetGroupingMinDistance(nativeID0, 0.00);
rmSetGroupingMaxDistance(nativeID0, rmXFractionToMeters(0.35));
rmAddGroupingToClass(nativeID0, rmClassID("patch"));
rmAddGroupingConstraint(nativeID0, avoidNatives);
rmAddGroupingConstraint(nativeID0, avoidWaterShort);
rmAddGroupingConstraint(nativeID0, avoidPlateauSPC);
if (cNumberNonGaiaPlayers>=4)
	rmAddGroupingConstraint(nativeID0, avoidCenter);
rmAddGroupingConstraint(nativeID0, avoidPirates);
rmAddGroupingConstraint(nativeID0, circleConstraint2);

int nativeID1Type = rmRandInt(1,2);
nativeID1 = rmCreateGrouping("native site 1", "Korowai_Village_0"+nativeID1Type);
rmSetGroupingMinDistance(nativeID1, 0.00);
rmSetGroupingMaxDistance(nativeID1, rmXFractionToMeters(0.35));
rmAddGroupingToClass(nativeID1, rmClassID("patch"));
rmAddGroupingConstraint(nativeID1, avoidNatives);
rmAddGroupingConstraint(nativeID1, avoidWaterShort);
rmAddGroupingConstraint(nativeID1, avoidPlateauSPC);
if (cNumberNonGaiaPlayers>=4)
	rmAddGroupingConstraint(nativeID1, avoidCenter);
rmAddGroupingConstraint(nativeID1, avoidPirates);
rmAddGroupingConstraint(nativeID1, circleConstraint2);

int nativeID2Type = rmRandInt(3,5);
nativeID2 = rmCreateGrouping("native site 2", "Korowai_Village_0"+nativeID2Type);
rmSetGroupingMinDistance(nativeID2, 0.00);
rmSetGroupingMaxDistance(nativeID2, rmXFractionToMeters(0.35));
rmAddGroupingToClass(nativeID2, rmClassID("patch"));
rmAddGroupingConstraint(nativeID2, avoidNatives);
rmAddGroupingConstraint(nativeID2, avoidWaterShort);
rmAddGroupingConstraint(nativeID2, avoidPlateauSPC);
rmAddGroupingConstraint(nativeID2, avoidCenter);
rmAddGroupingConstraint(nativeID2, avoidPirates);
rmAddGroupingConstraint(nativeID2, circleConstraint2);

int nativeID3Type = rmRandInt(3,5);
nativeID3 = rmCreateGrouping("native site 3", "Korowai_Village_0"+nativeID3Type);
rmSetGroupingMinDistance(nativeID3, 0.00);
rmSetGroupingMaxDistance(nativeID3, rmXFractionToMeters(0.35));
rmAddGroupingToClass(nativeID3, rmClassID("patch"));
rmAddGroupingConstraint(nativeID3, avoidNatives);
rmAddGroupingConstraint(nativeID3, avoidWaterShort);
rmAddGroupingConstraint(nativeID3, avoidPlateauSPC);
rmAddGroupingConstraint(nativeID3, avoidCenter);
rmAddGroupingConstraint(nativeID3, avoidPirates);
rmAddGroupingConstraint(nativeID3, circleConstraint2);

int nativeID4Type = rmRandInt(1,5);
nativeID4 = rmCreateGrouping("native site 4", "Korowai_Village_0"+nativeID4Type);
rmSetGroupingMinDistance(nativeID4, 0.00);
rmSetGroupingMaxDistance(nativeID4, rmXFractionToMeters(0.35));
rmAddGroupingToClass(nativeID4, rmClassID("patch"));
rmAddGroupingConstraint(nativeID4, avoidNatives);
rmAddGroupingConstraint(nativeID4, avoidWaterShort);
rmAddGroupingConstraint(nativeID4, avoidPlateauSPC);
rmAddGroupingConstraint(nativeID4, avoidCenter);
rmAddGroupingConstraint(nativeID4, avoidPirates);
rmAddGroupingConstraint(nativeID4, circleConstraint2);

if (mapVariant == 1)
	jesuitID0 = rmCreateGrouping("jesuit site 1", "sufi_greatmosque_01");
else
	jesuitID0 = rmCreateGrouping("jesuit site 1", "Jesuit_Cathedral_Tropic_Big");
rmAddGroupingToClass(jesuitID0, rmClassID("patch"));

int jesuitID1Type = rmRandInt(1,3);
if (mapVariant == 1)
	jesuitID1 = rmCreateGrouping("jesuit site 2", "sufi_greatmosque_04");
else
	jesuitID1 = rmCreateGrouping("jesuit site 2", "Jesuit_Cathedral_Tropic_0"+jesuitID1Type);
rmAddGroupingToClass(jesuitID1, rmClassID("patch"));


//========place=====

 // check for KOTH game mode
if (rmGetIsKOTH())
{       
    float xLoc = 0.5;
    float yLoc = centrePlacement;
    float walk = 0.0;

    ypKingsHillPlacer(xLoc, yLoc, walk, 0);
    rmEchoInfo("XLOC = "+xLoc);
    rmEchoInfo("XLOC = "+yLoc);

	rmPlaceGroupingAtLoc(jesuitID1, 0, 0.5, centrePlacement-rmXTilesToFraction(15));
}
else {
	rmPlaceGroupingAtLoc(jesuitID1, 0, 0.5, centrePlacement);
}

//place korowai	
rmPlaceGroupingAtLoc(nativeID0, 0, 0.3, 0.5);
rmPlaceGroupingAtLoc(nativeID1, 0, 0.7, 0.5);

if (PlayerNum >= 3){
	if (mapVariant == 1)
		rmPlaceGroupingAtLoc(nativeID2, 0, 0.5, 0.8);
	else
		rmPlaceGroupingAtLoc(nativeID2, 0, 0.5, 0.2);
	rmPlaceGroupingAtLoc(nativeID3, 0, 0.5, 0.4);
}
if (PlayerNum >= 7)
	rmPlaceGroupingAtLoc(nativeID4, 0, 0.5, 0.6);


//place island jesuit, order is important for constraints
if (mapVariant == 1)
	rmPlaceGroupingAtLoc(jesuitID0, 0, 0.5, 0.08);
else
	rmPlaceGroupingAtLoc(jesuitID0, 0, 0.5, 0.92);

rmSetStatusText("",0.3);


// Port Sites
   
int portSite1 = rmCreateArea ("port_site1");
rmSetAreaSize(portSite1, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
rmSetAreaMix(portSite1, "borneo_grass_a");
rmSetAreaCoherence(portSite1, 1);
rmSetAreaSmoothDistance(portSite1, 15);
rmSetAreaBaseHeight(portSite1, 1.0);

int portSite2 = rmCreateArea ("port_site2");
rmSetAreaSize(portSite2, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
rmSetAreaMix(portSite2, "borneo_grass_a");
rmSetAreaCoherence(portSite2, 1);
rmSetAreaSmoothDistance(portSite2, 15);
rmSetAreaBaseHeight(portSite2, 1.0);

int portSite3 = rmCreateArea ("port_site3");
rmSetAreaSize(portSite3, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
rmSetAreaMix(portSite3, "borneo_grass_a");
rmSetAreaCoherence(portSite3, 1);
rmSetAreaSmoothDistance(portSite3, 15);
rmSetAreaBaseHeight(portSite3, 1.0);

int stationGrouping01 = -1;
stationGrouping01 = rmCreateGrouping("station grouping 01", "Harbour_Universal_NW");
rmSetGroupingMinDistance(stationGrouping01, 0.0);
rmSetGroupingMaxDistance (stationGrouping01, 0.0);

int stationGrouping02 = -1;
stationGrouping02 = rmCreateGrouping("station grouping 02", "Harbour_Universal_SE");
rmSetGroupingMinDistance(stationGrouping02, 0.0);
rmSetGroupingMaxDistance (stationGrouping02, 0.0);

vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.3);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
if (mapVariant == 1){
	rmSetAreaLocation(portSite1, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-40));
	rmBuildArea(portSite1);
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-20));
}
else{
	rmSetAreaLocation(portSite1, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+40));
	rmBuildArea(portSite1);
	rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+25));
}

socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
if (mapVariant == 1){
	rmSetAreaLocation(portSite2, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-37));
	rmBuildArea(portSite2);
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-17));
}
else{
	rmSetAreaLocation(portSite2, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+37));
	rmBuildArea(portSite2);
	rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+22));
}

socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.7);
rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
if (mapVariant == 1){
	rmSetAreaLocation(portSite3, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-40));
	rmBuildArea(portSite3);
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)-20));
}
else{
	rmSetAreaLocation(portSite3, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+40));
	rmBuildArea(portSite3);
	rmPlaceGroupingAtLoc(stationGrouping02, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)+25));
}


// ******************* Place Players ********************************

//starting objects

int playerStart = rmCreateStartingUnitsObjectDef(5.0);
rmSetObjectDefMinDistance(playerStart, 7.0);
rmSetObjectDefMaxDistance(playerStart, 12.0);

int goldID = rmCreateObjectDef("starting gold");
rmAddObjectDefItem(goldID, "mine", 1, 2.0);
rmSetObjectDefMinDistance(goldID, 12.0);
rmSetObjectDefMaxDistance(goldID, 12.0);

int goldID2 = rmCreateObjectDef("starting gold 2");
rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
rmSetObjectDefMinDistance(goldID2, 12.0);
rmSetObjectDefMaxDistance(goldID2, 12.0);
rmAddObjectDefConstraint(goldID2, avoidCoin);

int berryID = rmCreateObjectDef("starting berries");
rmAddObjectDefItem(berryID, "BerryBush", 5, 3.0);
rmSetObjectDefMinDistance(berryID, 16.0);
rmSetObjectDefMaxDistance(berryID, 16.0);
rmAddObjectDefConstraint(berryID, avoidCoin);

int treeID = rmCreateObjectDef("starting trees");
rmAddObjectDefItem(treeID, "ypTreeBorneo", rmRandInt(14,15), 7.0);
rmSetObjectDefMinDistance(treeID, 12.0);
rmSetObjectDefMaxDistance(treeID, 18.0);
rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
rmAddObjectDefConstraint(treeID, avoidCoin);

int foodID = rmCreateObjectDef("starting hunt");
rmAddObjectDefItem(foodID, "zpFeralPig", 6, 8.0);
rmSetObjectDefMinDistance(foodID, 10.0);
rmSetObjectDefMaxDistance(foodID, 10.0);
rmSetObjectDefCreateHerd(foodID, true);

int foodID2 = rmCreateObjectDef("starting hunt 2");
rmAddObjectDefItem(foodID2, "zpFeralPig", 4, 8.0);
rmSetObjectDefMinDistance(foodID2, 40.0);
rmSetObjectDefMaxDistance(foodID2, 40.0);
rmSetObjectDefCreateHerd(foodID2, true);
rmAddObjectDefConstraint(foodID2, avoidWaterShort);
                       
int foodID3 = rmCreateObjectDef("starting hunt 3");
rmAddObjectDefItem(foodID3, "zpCassowary", 3, 8.0);
rmSetObjectDefMinDistance(foodID3, 65.0);
rmSetObjectDefMaxDistance(foodID3, 65.0);
rmSetObjectDefCreateHerd(foodID3, true);
rmAddObjectDefConstraint(foodID3, avoidWaterShort);

rmSetStatusText("",0.5);      

//flag stuff, utilize tp route to place flags without complex coords

vector flagLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
int flagLand = rmCreateTerrainDistanceConstraint("flags dont like land", "land", true, 3.0);

// Fake Frouping to fix the auto-grouping TC bug
int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.6);

//===============place tcs===================

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int id=rmCreateArea("Player"+i);
	rmSetPlayerArea(i, id);
	int startID = rmCreateObjectDef("object"+i);
	rmAddObjectDefItem(startID, "TownCenter", 1, 1.0);
	rmSetObjectDefMinDistance(startID, 0.0);
	rmSetObjectDefMaxDistance(startID, 1.0);
	rmSetAreaSize(startID, .015, .017);              	rmSetAreaBaseHeight(startID, 1.0);

	//=========place start res=================

	rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));


	//water flag at x% along trade route
	flagLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, rmPlayerLocXFraction(i));
	int waterFlag = rmCreateObjectDef("HC water flag "+i);
	rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 2.0);
	rmSetObjectDefMinDistance(waterFlag, 0);
	rmSetObjectDefMaxDistance(waterFlag, rmXFractionToMeters(0.05));
	rmAddObjectDefConstraint(waterFlag, flagLand);
	rmAddObjectDefConstraint(waterFlag, flagVsWokou1);
	rmAddObjectDefConstraint(waterFlag, flagVsWokou2);
	rmAddObjectDefConstraint(waterFlag, flagVsFlag);
	rmAddObjectDefConstraint(waterFlag, avoidTradeSockets);
	rmAddObjectDefConstraint(waterFlag, circleConstraint);
	rmPlaceObjectDefAtPoint(waterFlag, i, flagLoc1);
}


rmSetStatusText("",0.6);


/*
==================
resource placement
==================
*/

int pronghornHunts = rmCreateObjectDef("pronghornHunts");
rmAddObjectDefItem(pronghornHunts, "zpRedNeckedWallaby", rmRandInt(3,5), 7.0);
rmSetObjectDefCreateHerd(pronghornHunts, true);
rmSetObjectDefMinDistance(pronghornHunts, 0);
rmSetObjectDefMaxDistance(pronghornHunts, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(pronghornHunts, circleConstraint);
rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);
rmAddObjectDefConstraint(pronghornHunts, avoidPatch);	
rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);

int islandminesID = rmCreateObjectDef("island silver");
rmAddObjectDefItem(islandminesID, "mineGold", 1, 3.0);
rmSetObjectDefMinDistance(islandminesID, 0.0);
rmSetObjectDefMaxDistance(islandminesID, rmXFractionToMeters(0.46));
rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
//rmAddObjectDefConstraint(islandminesID, avoidSocket);
//rmAddObjectDefConstraint(islandminesID, avoidCenter);
rmAddObjectDefConstraint(islandminesID, avoidPatch);	
rmAddObjectDefConstraint(islandminesID, avoidAll);
rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
rmAddObjectDefConstraint(islandminesID, circleConstraint);
rmAddObjectDefConstraint(islandminesID, avoidPiratesShort);	
rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);

int nuggetID= rmCreateObjectDef("nugget"); 
rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
rmSetObjectDefMinDistance(nuggetID, 0.0); 
rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.44)); 
rmAddObjectDefConstraint(nuggetID, avoidNugget); 
rmAddObjectDefConstraint(nuggetID, circleConstraint);
rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
rmAddObjectDefConstraint(nuggetID, avoidWaterShort); 
rmAddObjectDefConstraint(nuggetID, avoidAll); 
rmAddObjectDefConstraint(nuggetID, avoidPatch);		//rmAddObjectDefConstraint(nuggetID, avoidCenter);	
rmSetNuggetDifficulty(1, 2); 
rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 4+2*cNumberNonGaiaPlayers);   

int nuggetID2= rmCreateObjectDef("nugget2"); 
rmAddObjectDefItem(nuggetID2, "Nugget", 1, 0.0); 
rmSetObjectDefMinDistance(nuggetID2, 0.0); 
rmSetObjectDefMaxDistance(nuggetID2, rmXFractionToMeters(0.44)); 
rmAddObjectDefConstraint(nuggetID2, avoidNugget); 
rmAddObjectDefConstraint(nuggetID2, circleConstraint);
rmAddObjectDefConstraint(nuggetID2, avoidTownCenter);
rmAddObjectDefConstraint(nuggetID2, forestConstraintShort);
rmAddObjectDefConstraint(nuggetID2, avoidTradeRouteSmall);
rmAddObjectDefConstraint(nuggetID2, avoidWaterShort); 
rmAddObjectDefConstraint(nuggetID2, avoidAll); 
rmAddObjectDefConstraint(nuggetID2, avoidPatch);		//rmAddObjectDefConstraint(nuggetID, avoidCenter);	
rmSetNuggetDifficulty(3, 4); 
rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);   

int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(5, 5);
rmSetObjectDefMinDistance(nugget2b, 0);
rmSetObjectDefMaxDistance(nugget2b, 30);
rmAddObjectDefConstraint(nugget2b, avoidLand);
rmAddObjectDefConstraint(nugget2b, avoidTradeRouteFish);
if (mapVariant == 1){
	rmPlaceObjectDefAtLoc(nugget2b, 0, 0.4, 0.2);
	rmPlaceObjectDefAtLoc(nugget2b, 0, 0.6, 0.2);
}
else{
	rmPlaceObjectDefAtLoc(nugget2b, 0, 0.4, 0.8);
	rmPlaceObjectDefAtLoc(nugget2b, 0, 0.6, 0.8);
}

rmSetStatusText("",0.7);

int mapTrees=rmCreateObjectDef("map trees");
rmAddObjectDefItem(mapTrees, "ypTreeBorneo", rmRandInt(10,11), rmRandFloat(8.0,9.0));
rmAddObjectDefItem(mapTrees, "deTreeMangrove", rmRandInt(4,5), rmRandFloat(10.0,12.0));
rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
rmSetObjectDefMinDistance(mapTrees, 0);
rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(0.45));
rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
rmAddObjectDefConstraint(mapTrees, avoidCoin);
rmAddObjectDefConstraint(mapTrees, avoidGold);
//rmAddObjectDefConstraint(mapTrees, circleConstraint);
rmAddObjectDefConstraint(mapTrees, forestConstraint);
rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
rmAddObjectDefConstraint(mapTrees, avoidPatch);	
rmAddObjectDefConstraint(mapTrees, avoidPiratesShort);	
//rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
//rmAddObjectDefConstraint(mapTrees, avoidCenter);
rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 50*cNumberNonGaiaPlayers);

rmSetStatusText("",0.8);

//=============tinned fish===============

//fish and their constraints placed together at the end for ease of removal

int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "ypFishCatfish", 12.0);
int calamariID=rmCreateTypeDistanceConstraint("squid v squid", "ypSquid", 9.0);

int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 3.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 60.0);


int fishID=rmCreateObjectDef("fish Mahi");
rmAddObjectDefItem(fishID, "ypFishCatfish", 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(fishID, fishVsFishID);
rmAddObjectDefConstraint(fishID, avoidTradeRouteFish);
rmAddObjectDefConstraint(fishID, circleConstraint2);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 45*cNumberNonGaiaPlayers);

rmSetStatusText("",0.9);


// ------Triggers--------//

int tch0=1671; // tech operator

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

// Update ports

rmCreateTrigger("I Update Ports");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","zpChinaTreasureShip");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
for (k=1; <= cNumberNonGaiaPlayers) {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpGaiaKillTreasureship");
      rmSetTriggerEffectParamInt("Status",2);
    }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

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


   rmCreateTrigger("TrainPrivateer2ON Plr"+k);
   rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
   rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
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


rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
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
   rmSetTriggerConditionParam("DstObject","56");
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
   rmSetTriggerConditionParamFloat("Param1",1200);
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
   rmSetTriggerEffectParam("TechID","cTechzpTrainFireJunk2"); //operator
   rmSetTriggerEffectParamInt("Status",0);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("trainFuchuan1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
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
rmSetTriggerConditionParamFloat("Param1",1200);
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

// Pirate trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Pirates1on Player"+k);
rmCreateTrigger("Pirates1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","3");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","3");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","3");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Pirates2on Player"+k);
   rmCreateTrigger("Pirates2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","56");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpWokouWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainFuchuan2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   }


// AI Pirate Captains

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
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouTakanobu"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (wokouCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateWokouMadameChing"); //operator
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
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",4929);
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",3645);
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}*/
  
  
// Text
rmSetStatusText("",0.99);
}  

 
