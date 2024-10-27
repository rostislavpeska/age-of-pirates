/*
===============================================
	Great Barrier Reef - Pirates Edition
			  by dansil92
			  Oct 15 2024

	Edited by Baltazer Oct 25 2024
===============================================
*/

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {
	rmSetStatusText("",0.01);
 
//pick map size

//size is determined by the number of players across the x axis
//y axis is mostly static, varying minimally

int sizeX = 200*cNumberNonGaiaPlayers;
int sizeY = 320;

if (cNumberNonGaiaPlayers == 2){
	if(rmGetIsKOTH()){
		sizeX = 500;
	}
	sizeY = 320;
}

rmSetMapSize(sizeY, sizeX);


rmSetSeaType("ZP Great Barrier Reef 4");
rmSetOceanReveal(true);
rmEnableLocalWater(true);
rmSetMapType("water");
rmSetMapType("tropical");
rmSetMapType("barrierreef");
rmTerrainInitialize("water");
rmSetLightingSet("rm_afri_horn");

// Define some classes

rmDefineClass("classForest");
rmDefineClass("classPlateau");
int classTeamIsland=rmDefineClass("teamIsland");
int classTeamCliff=rmDefineClass("teamCliff");
int classBonusIsland=rmDefineClass("bonusIsland");
int classUnderwaterCliff=rmDefineClass("underwaterCliff");
int classPatch = rmDefineClass("patch");
int classCenter = rmDefineClass("center");
int classUnderwaterPatch = rmDefineClass("underwaterPatch");

// Variables for later use
string baseMix = "california_snowground5";
string whale1 = "MinkeWhale";
string fish1 = "ypFishMolaMola";
string fish2 = "FishMahi";
string fish3 = "ypSquid";
		

// ************************* Constraints ***********************************

// Cardinal directions
int stayNorthPart = rmCreatePieConstraint("Stay north part", 0.5, 0.55,rmXFractionToMeters(0.0), rmXFractionToMeters(5.30), rmDegreesToRadians(360),rmDegreesToRadians(180));
int staySouthPart = rmCreatePieConstraint("Stay south part", 0.5, 0.55,rmXFractionToMeters(0.0), rmXFractionToMeters(5.30), rmDegreesToRadians(180),rmDegreesToRadians(360));
int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));
int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
int edgeConstraint = rmCreateBoxConstraint("stay in edge", 0.05, 0.05, 0.95, 0.95);

//Nature
int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 35.0);
int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);      
int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 55.0);
int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);
int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);
int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 12.0);
int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 70.0);
int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 12.0);
int avoidWaterX = rmCreateTerrainDistanceConstraint("avoid water short 21", "Land", false, 31.0);
int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short 0", "Land", false, 2.0);
int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water short 5", "Land", false, 4.0);

// Trade route
int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 12.0);
int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("objects avoid trade route far", 47.0);
int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);
        
// Player Constraints
int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 30.0);
int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  

// Area avoidance
int avoidTeamIslands=rmCreateClassDistanceConstraint("avoid team island constraint", classTeamIsland, 20.0);
int avoidBonusIslands1=rmCreateClassDistanceConstraint("avoid bonus island constraint 1", classBonusIsland, 1.0);
int avoidTeamCliffs1=rmCreateClassDistanceConstraint("avoid team cliff constraint 1", classTeamCliff, 1.0);
int avoidTeamCliffs10=rmCreateClassDistanceConstraint("avoid team cliff constraint 10", classTeamCliff, 10.0);
int avoidTeamCliffs20=rmCreateClassDistanceConstraint("avoid team cliff constraint 20", classTeamCliff, 20.0);
int avoidTeamCliffs30=rmCreateClassDistanceConstraint("avoid team cliff constraint 30", classTeamCliff, 30.0);
int avoidTeamCliffs=rmCreateClassDistanceConstraint("avoid team cliff constraint", classTeamCliff, 10.0);
int avoidBonusIslands=rmCreateClassDistanceConstraint("avoid bonus island constraint", classBonusIsland, 30.0);
int avoidTeamIslands1=rmCreateClassDistanceConstraint("avoid team island 1", classTeamIsland, 1.0);
int avoidUnderwaterCliff=rmCreateClassDistanceConstraint("avoid underwatercliff", classUnderwaterCliff, 3.0);
int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);
int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", classUnderwaterPatch, 22.0);
int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 3.0);

// Objects
int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);
int avoidNuggetShort=rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 30.0);
int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "zpPearlSource", 35.0);
int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 5.0);
int avoidMinerals=rmCreateTypeDistanceConstraint("avoid minerals", "AbstractUnderwaterMine", 5.0);
int avoidLandShort = rmCreateTerrainDistanceConstraint("ship avoid land short", "land", true, 5.0);
int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 4.5);
int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 20.0);
int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 30.0);
int avoidPiratesShort=rmCreateTypeDistanceConstraint("avoid socket pirates short", "zpSocketPirates", 20.0);
int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 30.0);
int avoidInventorsShort=rmCreateTypeDistanceConstraint("avoid socket scientists short", "zpSocketScientists", 20.0);
int avoidInventors=rmCreateTypeDistanceConstraint("avoid socket scientists", "zpSocketScientists", 30.0);
int avoidHarbourSocket=rmCreateTypeDistanceConstraint("avoid harbour socket", "zpSPCPortSocket", 15.0);
int avoidHarbourPlatform=rmCreateTypeDistanceConstraint("avoid harbour platform", "zpHarbourPlatform", 15.0);
int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 

// Fish Constraints
int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
int avoidFish3=rmCreateTypeDistanceConstraint("fish v fish3", fish3, 15.0);
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);


rmSetStatusText("",0.1); 


// ********************************** Players Placing ************************************************

// Player placing  
float spawnSwitch = rmRandInt(0,1);

int TeamNum = cNumberTeams;
int numPlayer = cNumberPlayers;

int PlayerNum = cNumberNonGaiaPlayers;
int teamZeroCount = rmGetNumberPlayersOnTeam(0);
int teamOneCount = rmGetNumberPlayersOnTeam(1);


if ( cNumberTeams == 2 || ((teamZeroCount - teamOneCount) == 0)){
	if (spawnSwitch ==0){

		if (PlayerNum == 2)
		{
			rmPlacePlayer(1, 0.15, 0.25);
			rmPlacePlayer(2, 0.15, 0.75);
		}
		else if (PlayerNum == 4)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.18, 0.1, 0.38, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.62, 0.1, 0.82, 0, 0);
		}
		else if (PlayerNum == 6)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.13, 0.1, 0.4, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.6, 0.1, 0.87, 0, 0);
		}
		else
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.11, 0.1, 0.42, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.58, 0.1, 0.89, 0, 0);
		}

	}
	
	else if(spawnSwitch ==1){

		if (PlayerNum == 2)
		{
			rmPlacePlayer(2, 0.15, 0.25);
			rmPlacePlayer(1, 0.15, 0.75);
		}
		else if (PlayerNum == 4)
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.18, 0.1, 0.38, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.62, 0.1, 0.82, 0, 0);
		}
		else if (PlayerNum == 6)
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.13, 0.1, 0.4, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.6, 0.1, 0.87, 0, 0);
		}
		else
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.1, 0.11, 0.1, 0.42, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.1, 0.58, 0.1, 0.89, 0, 0);
		}
	}

}

else{
	if (cNumberNonGaiaPlayers <= 4)
		rmPlacePlayersLine(0.1, 0.2, 0.1, 0.8, 0, 0);
	else
		rmPlacePlayersLine(0.1, 0.15, 0.1, 0.85, 0, 0);
}

chooseMercs();

rmSetStatusText("",0.2);


//============= Trade routes ===============


int tradeRouteID = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID, 0.45, .1);
rmAddTradeRouteWaypoint(tradeRouteID, 0.45, .5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.45, .9);

rmBuildTradeRoute(tradeRouteID, "water_trail");
 
rmSetStatusText("",0.3);

//=============Place Natives====================

// Define Natives
int subCiv0=-1;
int subCiv1=-1;

if (rmAllocateSubCivs(2) == true)
{
subCiv0=rmGetCivID("natpirates");
rmEchoInfo("subCiv0 is pirates "+subCiv0);
if (subCiv0 >= 0)
	rmSetSubCiv(0, "natpirates");

subCiv1=rmGetCivID("zpScientists");
rmEchoInfo("subCiv1 is zpScientists "+subCiv1);
if (subCiv1 >= 0)
rmSetSubCiv(1, "zpScientists");

}

		
rmSetStatusText("",0.4);


// ********************** Place terrain *********************************

// Player segments 1

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int deadSeaLakeOuterID=rmCreateArea("Lake Eyre03"+i);
	rmSetAreaWaterType(deadSeaLakeOuterID, "ZP Great Barrier Reef 3");
	rmSetAreaSize(deadSeaLakeOuterID, 0.09, 0.09);
	rmSetAreaCoherence(deadSeaLakeOuterID, 1.0);
	rmSetAreaLocation(deadSeaLakeOuterID, 0.6, rmPlayerLocZFraction(i));
	rmSetAreaSmoothDistance(deadSeaLakeOuterID, 10);
	rmBuildArea(deadSeaLakeOuterID);
}
for(i=1; < cNumberNonGaiaPlayers + 1) {
	int deadSeaLakeMediumID=rmCreateArea("Lake Eyre02"+i);
	rmSetAreaWaterType(deadSeaLakeMediumID, "ZP Great Barrier Reef 2");
	rmSetAreaSize(deadSeaLakeMediumID, 0.06, 0.06);
	rmSetAreaCoherence(deadSeaLakeMediumID, 1.0);
	rmSetAreaLocation(deadSeaLakeMediumID, 0.6, rmPlayerLocZFraction(i));
	rmSetAreaSmoothDistance(deadSeaLakeMediumID, 10);
	rmBuildArea(deadSeaLakeMediumID);
}
for(i=1; < cNumberNonGaiaPlayers + 1) {
	int deadSeaLakeDeepID=rmCreateArea("Lake Eyre"+i);
	rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Great Barrier Reef");
	rmSetAreaSize(deadSeaLakeDeepID, 0.03, 0.03);
	rmSetAreaCoherence(deadSeaLakeDeepID, 1.0);
	rmSetAreaLocation(deadSeaLakeDeepID, 0.6, rmPlayerLocZFraction(i));
	rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);
	rmBuildArea(deadSeaLakeDeepID);

	int playerCliff = rmCreateArea("playerCliff"+i);
	rmSetAreaSize(playerCliff, rmAreaTilesToFraction(4700), rmAreaTilesToFraction(4700));
	rmSetAreaLocation(playerCliff, 0.15, rmPlayerLocZFraction(i));
	rmAddAreaInfluenceSegment(playerCliff, 0.01, rmPlayerLocZFraction(i), 0.25, rmPlayerLocZFraction(i));
	rmSetAreaMinBlobs(playerCliff, 30);
	rmSetAreaMaxBlobs(playerCliff, 45);
	rmSetAreaMinBlobDistance(playerCliff, 20.0);
	rmSetAreaMaxBlobDistance(playerCliff, 40.0);
	rmSetAreaCoherence(playerCliff, 0.7);
	rmSetAreaBaseHeight(playerCliff, -5.0);
	rmSetAreaSmoothDistance(playerCliff, 40);
	rmSetAreaCliffType(playerCliff, "Cave_IGC");
	rmSetAreaCliffEdge(playerCliff, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(playerCliff, 0, 1.0, 1.0);
	rmSetAreaHeightBlend(playerCliff, 1.9);
	rmSetAreaElevationVariation(playerCliff, 0.0);
	rmSetAreaWarnFailure(playerCliff, false);
	rmAddAreaConstraint(playerCliff, avoidTradeRouteSmall); 
	//rmAddAreaConstraint(playerCliff, avoidTeamCliffs);
	rmAddAreaToClass(playerCliff, classTeamCliff);
	rmEchoInfo("Team cliff 1"+i);
	rmBuildArea(playerCliff);

}

// Bonus segment 1

	// Place Controllers
	int controllerID1 = rmCreateObjectDef("Controler 1");
	rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);

	int controllerID2 = rmCreateObjectDef("Controler 2");
	rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);

	int controllerID3 = rmCreateObjectDef("Controler 3");
	rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);

	int controllerID4 = rmCreateObjectDef("Controler 4");
	rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);

	if (cNumberNonGaiaPlayers <= 3){  
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.77, 1.0-rmZMetersToFraction(60));
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.77, 0.0+rmZMetersToFraction(60));
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.8, 0.5-rmZMetersToFraction(50));
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.8, 0.5+rmZMetersToFraction(50));
	}
	else{  
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.72, 1.0-rmZMetersToFraction(60));
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.72, 0.0+rmZMetersToFraction(60));
		rmPlaceObjectDefAtLoc(controllerID3, 0, 0.8, 0.5-rmZMetersToFraction(80));
		rmPlaceObjectDefAtLoc(controllerID4, 0, 0.8, 0.5+rmZMetersToFraction(80));
	}

int reefCliff = rmCreateArea("reefCliff");
rmSetAreaSize(reefCliff, 0.13, 0.13); 
rmSetAreaLocation(reefCliff, 0.99, 0.5);
rmAddAreaInfluenceSegment(reefCliff, 0.96, 0.01, 0.99, 0.5);
rmAddAreaInfluenceSegment(reefCliff, 0.99, 0.5, 0.96, 0.99);
rmSetAreaMinBlobs(reefCliff, 30);
rmSetAreaMaxBlobs(reefCliff, 45);
rmSetAreaMinBlobDistance(reefCliff, 20.0);
rmSetAreaMaxBlobDistance(reefCliff, 40.0);
rmSetAreaCoherence(reefCliff, 0.4);
rmSetAreaBaseHeight(reefCliff, -5.0);
rmSetAreaSmoothDistance(reefCliff, 40);
rmSetAreaCliffType(reefCliff, "Cave_IGC");
rmSetAreaCliffEdge(reefCliff, 1, 1.0, 0.1, 1.0, 0);
rmSetAreaCliffHeight(reefCliff, 0, 1.0, 1.0);
rmSetAreaHeightBlend(reefCliff, 1.9);
rmSetAreaElevationVariation(reefCliff, 0.0);
rmSetAreaWarnFailure(reefCliff, false);
//rmAddAreaConstraint(reefCliff, avoidTradeRouteSmall); 
rmAddAreaConstraint(reefCliff, avoidTeamCliffs);
rmAddAreaConstraint(reefCliff, avoidController);
rmAddAreaToClass(reefCliff, classTeamCliff);
rmAddAreaConstraint(reefCliff, avoidTradeRouteFar);
rmSetAreaObeyWorldCircleConstraint(reefCliff, false);
rmBuildArea(reefCliff);

int underwaterCliff = rmCreateArea("underwaterCliff");
rmSetAreaSize(underwaterCliff, 0.7, 0.7);
rmSetAreaLocation(underwaterCliff, 0.5, 0.5);
rmSetAreaCoherence(underwaterCliff, 1.0);
//rmSetAreaWaterType(underwaterCliff, "ZP Australia Red Lake");
rmSetAreaWarnFailure(underwaterCliff, false);
rmAddAreaConstraint(underwaterCliff, avoidTeamCliffs1);
rmAddAreaToClass(underwaterCliff, classUnderwaterCliff);
rmBuildArea(underwaterCliff);

// Player segments 2

for(i=1; < cNumberNonGaiaPlayers + 1) {

	int playerShallows = rmCreateArea("playerShallows"+i);
	rmAddAreaToClass(playerShallows, rmClassID("playerShallows"));
	rmSetAreaSize(playerShallows, rmAreaTilesToFraction(3500), rmAreaTilesToFraction(3500));
	rmSetAreaLocation(playerShallows, 0.15, rmPlayerLocZFraction(i));
	rmAddAreaInfluenceSegment(playerShallows, 0.01, rmPlayerLocZFraction(i), 0.25, rmPlayerLocZFraction(i));
	rmSetAreaBaseHeight(playerShallows, -0.5);
	rmSetAreaCoherence(playerShallows, 0.6);
	rmAddAreaToClass(playerShallows, classTeamIsland);
	rmAddAreaConstraint(playerShallows, avoidTradeRouteSmall);
	rmAddAreaConstraint(playerShallows, avoidTeamIslands);
	rmAddAreaConstraint(playerShallows, avoidUnderwaterCliff);
	rmSetAreaSmoothDistance(playerShallows, 10);
	rmSetAreaHeightBlend(playerShallows, 1);
	rmSetAreaElevationVariation(playerShallows, 0.5);
	rmSetAreaElevationNoiseBias(playerShallows, 0);
	rmSetAreaElevationEdgeFalloffDist(playerShallows, 10);
	rmSetAreaElevationPersistence(playerShallows, .2);
	rmSetAreaElevationOctaves(playerShallows, 5);
	rmSetAreaElevationMinFrequency(playerShallows, 0.04);
	rmSetAreaElevationType(playerShallows, cElevTurbulence);  
	rmSetAreaMinBlobs(playerShallows, 30);
	rmSetAreaMaxBlobs(playerShallows, 45);
	rmSetAreaMinBlobDistance(playerShallows, 20.0);
	rmSetAreaMaxBlobDistance(playerShallows, 40.0);
	rmSetAreaMix(playerShallows, baseMix);
	rmSetAreaWarnFailure(playerShallows, false);
	rmEchoInfo("playerShallows"+i);
	rmBuildArea(playerShallows);   

	int playerIsland = rmCreateArea("playerIsland"+i);
	rmSetAreaSize(playerIsland, rmAreaTilesToFraction(1500), rmAreaTilesToFraction(1500));
	rmSetAreaLocation(playerIsland, 0.15, rmPlayerLocZFraction(i));
	rmAddAreaInfluenceSegment(playerIsland, 0.01, rmPlayerLocZFraction(i), 0.15, rmPlayerLocZFraction(i));
	rmSetAreaMix(playerIsland, baseMix);
	rmSetAreaBaseHeight(playerIsland, 2.0);
	rmSetAreaCoherence(playerIsland, 0.7);
	rmAddAreaConstraint(playerIsland, avoidTradeRouteSmall);
	rmSetAreaSmoothDistance(playerIsland, 10);
	rmSetAreaHeightBlend(playerIsland, 1);
	rmSetAreaElevationVariation(playerIsland, 2);
	rmSetAreaElevationNoiseBias(playerIsland, 0);
	rmSetAreaElevationEdgeFalloffDist(playerIsland, 10);
	rmSetAreaElevationPersistence(playerIsland, .2);
	rmSetAreaElevationOctaves(playerIsland, 5);
	rmSetAreaElevationMinFrequency(playerIsland, 0.04);
	rmSetAreaElevationType(playerIsland, cElevTurbulence);  
	rmSetAreaSmoothDistance(playerIsland, 15);
	rmSetAreaHeightBlend(playerIsland, 2.0);
	rmBuildArea(playerIsland);   

	int tradeIsland = rmCreateArea("tradeIsland"+i);
	rmSetAreaSize(tradeIsland, rmAreaTilesToFraction(350), rmAreaTilesToFraction(350));
	rmSetAreaLocation(tradeIsland, 0.41, rmPlayerLocZFraction(i));
	rmAddAreaInfluenceSegment(tradeIsland, 0.41, rmPlayerLocZFraction(i)-rmZMetersToFraction(10), 0.41, rmPlayerLocZFraction(i)+rmZMetersToFraction(10));
	rmAddAreaInfluenceSegment(tradeIsland, 0.39, rmPlayerLocZFraction(i), 0.41, rmPlayerLocZFraction(i)+rmZMetersToFraction(10));
	rmAddAreaInfluenceSegment(tradeIsland, 0.41, rmPlayerLocZFraction(i)-rmZMetersToFraction(10), 0.39, rmPlayerLocZFraction(i));
	rmSetAreaMix(tradeIsland, baseMix);
	rmSetAreaBaseHeight(tradeIsland, 2.0);
	rmSetAreaCoherence(tradeIsland, 1.0);
	rmSetAreaSmoothDistance(tradeIsland, 10);
	rmSetAreaHeightBlend(tradeIsland, 1);
	rmSetAreaElevationVariation(tradeIsland, 2);
	rmSetAreaElevationNoiseBias(tradeIsland, 0);
	rmSetAreaElevationEdgeFalloffDist(tradeIsland, 10);
	rmSetAreaElevationPersistence(tradeIsland, .2);
	rmSetAreaElevationOctaves(tradeIsland, 5);
	rmSetAreaElevationMinFrequency(tradeIsland, 0.04);
	rmSetAreaElevationType(tradeIsland, cElevTurbulence);  
	rmSetAreaSmoothDistance(tradeIsland, 5);
	rmBuildArea(tradeIsland);   
}


// Bonus segment 2

int reefShallows = rmCreateArea("bonusIslands SPC");
rmSetAreaSize(reefShallows, 0.12, 0.12); 
rmSetAreaLocation(reefShallows, 0.99, 0.5);
rmAddAreaInfluenceSegment(reefShallows, 0.96, 0.01, 0.99, 0.5);
rmAddAreaInfluenceSegment(reefShallows, 0.99, 0.5, 0.96, 0.99);
rmSetAreaSmoothDistance(reefShallows, 10);
rmSetAreaCoherence(reefShallows, .5);
rmSetAreaBaseHeight(reefShallows, -0.5);
rmSetAreaHeightBlend(reefShallows, 1);
rmSetAreaElevationNoiseBias(reefShallows, 0);
rmSetAreaElevationEdgeFalloffDist(reefShallows, 10);
rmSetAreaElevationVariation(reefShallows, 0.5);
rmSetAreaElevationPersistence(reefShallows, .2);
rmSetAreaElevationOctaves(reefShallows, 5);
rmSetAreaElevationMinFrequency(reefShallows, 0.04);
rmAddAreaToClass(reefShallows, classTeamIsland);
rmSetAreaElevationType(reefShallows, cElevTurbulence);  	
rmAddAreaConstraint(reefShallows, avoidUnderwaterCliff);
rmSetAreaMinBlobs(reefShallows, 30);
rmSetAreaMaxBlobs(reefShallows, 45);
rmSetAreaMinBlobDistance(reefShallows, 20.0);
rmSetAreaMaxBlobDistance(reefShallows, 40.0);
rmSetAreaMix(reefShallows, baseMix);
rmSetAreaObeyWorldCircleConstraint(reefShallows, false);
rmBuildArea(reefShallows);

if (rmGetIsKOTH()){

	float xLoc = 0.92;
	float yLoc = 0.5;
	float walk = 0.0;

	int KotHVariant = rmRandInt(1, 2);

	int kothIsland=rmCreateArea("kothIsland");
    rmSetAreaWarnFailure(kothIsland, false);
    rmSetAreaSize(kothIsland, rmAreaTilesToFraction(350), rmAreaTilesToFraction(350));
	rmSetAreaMix(kothIsland, baseMix);
	rmSetAreaLocation(kothIsland, 0.92, 0.5);
    rmSetAreaCoherence(kothIsland, 0.99);
	rmSetAreaHeightBlend(kothIsland, 2);
    rmSetAreaSmoothDistance(kothIsland, 15);
    rmSetAreaBaseHeight(kothIsland, 2.0);
    rmAddAreaToClass(kothIsland, classBonusIsland);
	rmBuildArea(kothIsland);
	
}

int bonusIslandID = rmCreateArea ("bonus island");
if (cNumberNonGaiaPlayers <= 3)
	rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(1400.0), rmAreaTilesToFraction(1400.0));
else
	rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(1700.0), rmAreaTilesToFraction(1700.0));
rmSetAreaLocation(bonusIslandID, 0.93, 0.01);
rmSetAreaCoherence(bonusIslandID, 0.5);
rmSetAreaMinBlobs(bonusIslandID, 8);
rmSetAreaMaxBlobs(bonusIslandID, 12);
rmSetAreaMinBlobDistance(bonusIslandID, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID, 10.0);
rmSetAreaSmoothDistance(bonusIslandID, 10);
rmSetAreaHeightBlend(bonusIslandID, 2.0);
rmSetAreaMix(bonusIslandID, baseMix);

rmSetAreaBaseHeight(bonusIslandID, 2.5);
//rmAddAreaConstraint(bonusIslandID, bonusIslandConstraint);
rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID, 4.0);
rmSetAreaElevationPersistence(bonusIslandID, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID, 1);
rmSetAreaTerrainLayerVariance(bonusIslandID, false);
rmAddAreaToClass(bonusIslandID, classBonusIsland);
rmBuildArea(bonusIslandID);

int bonusIslandID2 = rmCreateArea ("bonus island 2");
if (cNumberNonGaiaPlayers <= 3)
	rmSetAreaSize(bonusIslandID2, rmAreaTilesToFraction(1400.0), rmAreaTilesToFraction(1400.0));
else
	rmSetAreaSize(bonusIslandID2, rmAreaTilesToFraction(1700.0), rmAreaTilesToFraction(1700.0));
rmSetAreaLocation(bonusIslandID2, 0.93, 0.99);
rmSetAreaCoherence(bonusIslandID2, 0.6);
rmSetAreaMinBlobs(bonusIslandID2, 8);
rmSetAreaMaxBlobs(bonusIslandID2, 12);
rmSetAreaMinBlobDistance(bonusIslandID2, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID2, 10.0);
rmSetAreaSmoothDistance(bonusIslandID2, 10);
rmSetAreaHeightBlend(bonusIslandID2, 2.0);
rmSetAreaMix(bonusIslandID2, baseMix);
rmSetAreaBaseHeight(bonusIslandID2, 2.5);
//rmAddAreaConstraint(bonusIslandID2, bonusIslandConstraint);
rmSetAreaElevationType(bonusIslandID2, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID2, 4.0);
rmSetAreaElevationPersistence(bonusIslandID2, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID2, 1);
rmSetAreaTerrainLayerVariance(bonusIslandID2, false);
rmAddAreaToClass(bonusIslandID2, classBonusIsland);
rmBuildArea(bonusIslandID2);

int bonusIslandID3 = rmCreateArea ("bonus island 3");
if (cNumberNonGaiaPlayers <= 3){
	rmSetAreaSize(bonusIslandID3, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
	rmSetAreaLocation(bonusIslandID3, 0.9, 0.5+rmZMetersToFraction(50));
}
else{
	rmSetAreaSize(bonusIslandID3, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaLocation(bonusIslandID3, 0.9, 0.5+rmZMetersToFraction(80));
}
rmSetAreaCoherence(bonusIslandID3, 0.8);
rmSetAreaMinBlobs(bonusIslandID3, 8);
rmSetAreaMaxBlobs(bonusIslandID3, 12);
rmSetAreaMinBlobDistance(bonusIslandID3, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID3, 10.0);
rmSetAreaSmoothDistance(bonusIslandID3, 10);
rmSetAreaHeightBlend(bonusIslandID3, 2.0);
rmSetAreaMix(bonusIslandID3, baseMix);
rmSetAreaBaseHeight(bonusIslandID3, 2.5);
//rmAddAreaConstraint(bonusIslandID3, bonusIslandConstraint);
rmSetAreaElevationType(bonusIslandID3, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID3, 4.0);
rmSetAreaElevationPersistence(bonusIslandID3, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID3, 1);
rmSetAreaTerrainLayerVariance(bonusIslandID3, false);
rmAddAreaToClass(bonusIslandID3, classBonusIsland);
rmBuildArea(bonusIslandID3);

int bonusIslandID4 = rmCreateArea ("bonus island 4");
if (cNumberNonGaiaPlayers <= 3){
	rmSetAreaSize(bonusIslandID4, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
	rmSetAreaLocation(bonusIslandID4, 0.9, 0.5-rmZMetersToFraction(50));
}
else{
	rmSetAreaSize(bonusIslandID4, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
	rmSetAreaLocation(bonusIslandID4, 0.9, 0.5-rmZMetersToFraction(80));
}
rmSetAreaCoherence(bonusIslandID4, 0.8);
rmSetAreaMinBlobs(bonusIslandID4, 8);
rmSetAreaMaxBlobs(bonusIslandID4, 12);
rmSetAreaMinBlobDistance(bonusIslandID4, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID4, 10.0);
rmSetAreaSmoothDistance(bonusIslandID4, 10);
rmSetAreaHeightBlend(bonusIslandID4, 2.0);
rmSetAreaMix(bonusIslandID4, baseMix);
rmSetAreaBaseHeight(bonusIslandID4, 2.5);
//rmAddAreaConstraint(bonusIslandID4, bonusIslandConstraint);
rmSetAreaElevationType(bonusIslandID4, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID4, 4.0);
rmSetAreaElevationPersistence(bonusIslandID4, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID4, 1);
rmSetAreaTerrainLayerVariance(bonusIslandID4, false);
rmAddAreaToClass(bonusIslandID4, classBonusIsland);
rmBuildArea(bonusIslandID4);


int numIslands=1.5*cNumberNonGaiaPlayers;
int failCount2=0;
for (i=0; <numIslands) {   
    int extraIsland=rmCreateArea("extraIsland "+i);
    rmSetAreaWarnFailure(extraIsland, false);
    rmSetAreaSize(extraIsland, rmAreaTilesToFraction(150), rmAreaTilesToFraction(300));
    rmSetAreaCoherence(extraIsland, 0.5);
    rmSetAreaSmoothDistance(extraIsland, 15);
    rmSetAreaMix(extraIsland, baseMix);
    rmSetAreaBaseHeight(extraIsland, 2.5);
	rmAddAreaToClass(extraIsland, classBonusIsland);
	rmSetAreaSmoothDistance(extraIsland, 15);
	rmSetAreaHeightBlend(extraIsland, 2.0);
	rmAddAreaConstraint(extraIsland, stayNorthPart);
	rmAddAreaConstraint(extraIsland, avoidTradeRouteFar);
	rmAddAreaConstraint(extraIsland, avoidBonusIslands);
    

    if(rmBuildArea(extraIsland)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount2++;
      
		if(failCount2==5)
			break;
    }
    
    else
      	failCount2=0; 
} 


// ************************ NATIVES ************************************

vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));

// Pirate Village 1

int pirateSite1 = rmCreateArea ("pirate_site1");
rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
rmSetAreaMix(pirateSite1, baseMix);
rmSetAreaCoherence(pirateSite1, 1);
rmSetAreaSmoothDistance(pirateSite1, 15);
rmSetAreaBaseHeight(pirateSite1, 2.0);
rmAddAreaToClass(pirateSite1, classBonusIsland);
rmBuildArea(pirateSite1);

int piratesVillageID = -1;
int piratesVillageType = rmRandInt(1,2);
piratesVillageID = rmCreateGrouping("pirate city", "pirate_village05");
//rmSetGroupingMinDistance(piratesVillageID, 0);
//rmSetGroupingMaxDistance(piratesVillageID, 30);
//rmAddGroupingConstraint(piratesVillageID, ferryOnShore);


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
int pirateSite2 = rmCreateArea ("pirate_site2");
rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
rmSetAreaMix(pirateSite2, baseMix);
rmSetAreaCoherence(pirateSite2, 1);
rmSetAreaSmoothDistance(pirateSite2, 15);
rmSetAreaBaseHeight(pirateSite2, 2.0);
rmAddAreaToClass(pirateSite2, classBonusIsland);
rmBuildArea(pirateSite2);

int piratesVillageID2 = -1;
int piratesVillage2Type = 3-piratesVillageType;
piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village06");
//rmSetGroupingMinDistance(piratesVillageID2, 0);
//rmSetGroupingMaxDistance(piratesVillageID2, 30);
//rmAddGroupingConstraint(piratesVillageID2, ferryOnShore);

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
int pirateSite3 = rmCreateArea ("pirate_site3");
rmSetAreaSize(pirateSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(pirateSite3, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)));
rmSetAreaMix(pirateSite3, baseMix);
rmSetAreaCoherence(pirateSite3, 1);
rmSetAreaSmoothDistance(pirateSite3, 15);
rmSetAreaBaseHeight(pirateSite3, 2.0);
rmAddAreaToClass(pirateSite3, classBonusIsland);
rmBuildArea(pirateSite3);

int piratesVillageID3 = -1;
piratesVillageID3 = rmCreateGrouping("pirate city 3", "Scientist_lab05");

rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);

int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
rmAddObjectDefItem(piratewaterflagID3, "zpNativeWaterSpawnFlag1", 1, 1.0);
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
int pirateSite4 = rmCreateArea ("pirate_site4");
rmSetAreaSize(pirateSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
rmSetAreaLocation(pirateSite4, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)));
rmSetAreaMix(pirateSite4, baseMix);
rmSetAreaCoherence(pirateSite4, 1);
rmSetAreaSmoothDistance(pirateSite4, 15);
rmSetAreaBaseHeight(pirateSite4, 2.0);
rmAddAreaToClass(pirateSite4, classBonusIsland);
rmBuildArea(pirateSite4);


int piratesVillageID4 = -1;
piratesVillageID4 = rmCreateGrouping("pirate city 4", "Scientist_lab06");
rmAddGroupingConstraint(piratesVillageID4, ferryOnShore);

rmPlaceGroupingAtLoc(piratesVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);

int piratewaterflagID4 = rmCreateObjectDef("pirate water flag 4");
rmAddObjectDefItem(piratewaterflagID4, "zpNativeWaterSpawnFlag2", 1, 1.0);
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

// ********************* Trade sites ***************************

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int portID = rmCreateObjectDef("port"+i);
	portID = rmCreateGrouping("port"+i, "harbour_center_river_NE");
    rmPlaceGroupingAtLoc(portID, 0, 0.43, rmPlayerLocZFraction(i));
}

// King of the Hill

if(rmGetIsKOTH()) {
	ypKingsHillPlacer(xLoc, yLoc, walk, 0);
	rmEchoInfo("XLOC = "+xLoc);
	rmEchoInfo("XLOC = "+yLoc);
}

// ******************** Underwater areas ******************************

int coralSPC = rmCreateGrouping("underwater stuff", "underwater_grouping_sm");
rmSetGroupingMinDistance(coralSPC, 0.00);
rmSetGroupingMaxDistance(coralSPC, 0.00);
rmAddGroupingToClass(coralSPC, classUnderwaterPatch);

for(i=1; < cNumberNonGaiaPlayers + 1) {
	rmPlaceGroupingAtLoc(coralSPC, 0, 0.6, rmPlayerLocZFraction(i));
}

// ******************************** Define and place town centers and starting resources **********************************

//starting objects

int playerStart = rmCreateStartingUnitsObjectDef(5.0);
rmSetObjectDefMinDistance(playerStart, 7.0);
rmSetObjectDefMaxDistance(playerStart, 12.0);
rmAddObjectDefConstraint(playerStart, avoidPlateau);	

int goldID = rmCreateObjectDef("starting gold");
rmAddObjectDefItem(goldID, "minegold", 1, 1.0);
rmSetObjectDefMinDistance(goldID, 14.0);
rmSetObjectDefMaxDistance(goldID, 14.0);
rmAddObjectDefConstraint(goldID, avoidPlateau);	

int goldID2 = rmCreateObjectDef("starting gold 2");
rmAddObjectDefItem(goldID2, "mine", 1, 16.0);
rmSetObjectDefMinDistance(goldID2, 12.0);
rmSetObjectDefMaxDistance(goldID2, 12.0);
rmAddObjectDefConstraint(goldID2, avoidCoin);
rmAddObjectDefConstraint(goldID2, avoidPlateau);	

int berryID = rmCreateObjectDef("starting berries");
rmAddObjectDefItem(berryID, "BerryBush", 2, 6.0);
rmSetObjectDefMinDistance(berryID, 8.0);
rmSetObjectDefMaxDistance(berryID, 12.0);
rmAddObjectDefConstraint(berryID, avoidCoin);

int treeID = rmCreateObjectDef("starting trees");
rmAddObjectDefItem(treeID, "ypTreeCeylon", rmRandInt(5,6), 7.0);
rmSetObjectDefMinDistance(treeID, 15.0);
rmSetObjectDefMaxDistance(treeID, 18.0);
rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
rmAddObjectDefConstraint(treeID, avoidCoin);

int foodID = rmCreateObjectDef("starting hunt");
rmAddObjectDefItem(foodID, "zpRedNeckedWallaby", 6, 8.0);
rmSetObjectDefMinDistance(foodID, 10.0);
rmSetObjectDefMaxDistance(foodID, 10.0);
rmSetObjectDefCreateHerd(foodID, true);
rmAddObjectDefConstraint(foodID, avoidPlateau);	

int foodID2 = rmCreateObjectDef("starting hunt 2");
rmAddObjectDefItem(foodID2, "zpFeralPig", 7, 8.0);
rmSetObjectDefMinDistance(foodID2, 35.0);
rmSetObjectDefMaxDistance(foodID2, 40.0);
rmSetObjectDefCreateHerd(foodID2, true);
rmAddObjectDefConstraint(foodID2, avoidPlateau);	
				
int foodID3 = rmCreateObjectDef("starting hunt 3");
rmAddObjectDefItem(foodID3, "zpRedNeckedWallaby", 8, 8.0);
rmSetObjectDefMinDistance(foodID3, 45.0);
rmSetObjectDefMaxDistance(foodID3, 45.0);
rmSetObjectDefCreateHerd(foodID3, true);
rmAddObjectDefConstraint(foodID3, avoidPlateau);	

int extraberrywagon=rmCreateObjectDef("jApaN cAnT hUnT");
rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
rmSetObjectDefMinDistance(extraberrywagon, 10.0);
rmSetObjectDefMaxDistance(extraberrywagon, 10.0);

// Starting area nuggets
int playerNuggetID=rmCreateObjectDef("player nugget");
rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
rmSetObjectDefMinDistance(playerNuggetID, 10.0);
rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
rmAddObjectDefConstraint(playerNuggetID, avoidAll);
rmAddObjectDefConstraint(playerNuggetID, shortAvoidImpassableLand);

int playerNuggetID2=rmCreateObjectDef("player nugget 2");
rmAddObjectDefItem(playerNuggetID2, "nugget", 1, 0.0);
rmSetObjectDefMinDistance(playerNuggetID2, 20.0);
rmSetObjectDefMaxDistance(playerNuggetID2, 30.0);
rmAddObjectDefConstraint(playerNuggetID2, avoidAll);
rmAddObjectDefConstraint(playerNuggetID2, avoidNuggetShort);
rmAddObjectDefConstraint(playerNuggetID2, shortAvoidImpassableLand);

// >>>>>>>>>>>>>>>>>>>>>>>>>> Make loader move >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
rmSetStatusText("",0.5);   

// Fake Frouping to fix the auto-grouping TC bug
int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);

// Place players
for(i=1; < cNumberNonGaiaPlayers + 1) {
	int id=rmCreateArea("Player"+i);
	rmSetPlayerArea(i, id);
	int startID = rmCreateObjectDef("object"+i);
	rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
	rmSetObjectDefMinDistance(startID, 0.0);
	rmSetObjectDefMaxDistance(startID, 4.0);
	rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmSetNuggetDifficulty(1, 1); 
	rmPlaceObjectDefAtLoc(playerNuggetID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmSetNuggetDifficulty(2, 2); 
	rmPlaceObjectDefAtLoc(playerNuggetID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	int waterFlag = rmCreateObjectDef("HC water flag "+i);
	rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
	rmSetObjectDefMinDistance(waterFlag, 1);
	rmSetObjectDefMaxDistance(waterFlag, 8);
	rmPlaceObjectDefAtLoc(waterFlag, i, 0.4, rmPlayerLocZFraction(i)+rmZMetersToFraction(25), 1);

	int playerNuggetIDWater=rmCreateObjectDef("player nugget water"+i);
	rmAddObjectDefItem(playerNuggetIDWater, "ypNuggetBoat", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetIDWater, 0.0);
	rmSetObjectDefMaxDistance(playerNuggetIDWater, 20.0);
	rmSetNuggetDifficulty(15, 15); 
	rmPlaceObjectDefAtLoc(playerNuggetIDWater, 0, 0.6, rmPlayerLocZFraction(i)+rmZMetersToFraction(35), 1);

	int divingBell = rmCreateObjectDef("Diving Bell "+i);
	rmAddObjectDefItem(divingBell, "zpDivingBell", 1, 0.0);
	rmSetObjectDefMinDistance(divingBell, 0);
	rmSetObjectDefMaxDistance(divingBell, 8);
	rmAddObjectDefConstraint(divingBell, avoidMinerals);
	rmPlaceObjectDefAtLoc(divingBell, i, 0.6, rmPlayerLocZFraction(i)-rmZMetersToFraction(20), 1);

	if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
		rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

}

// >>>>>>>>>>>>>>>>>>>>>>>>>> Make loader move >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
rmSetStatusText("",0.6);
	
// **************************** Resources and other objects **********************************

// Pearl Sources
int pearlsID = rmCreateObjectDef("random pearls");
rmAddObjectDefItem(pearlsID, "zpPearlSource", 1, 0);
rmSetObjectDefMinDistance(pearlsID, 0.0);
rmSetObjectDefMaxDistance(pearlsID, 30.0);
rmAddObjectDefConstraint(pearlsID, avoidAll);
rmAddObjectDefConstraint(pearlsID, avoidGold);
rmAddObjectDefConstraint(pearlsID, avoidCoin);
rmAddObjectDefConstraint(pearlsID, avoidLandShort);

for (i=0; <cNumberPlayers)
{
	rmPlaceObjectDefInArea(pearlsID, 0, rmAreaID("playerShallows"+i), 3);
}

rmPlaceObjectDefInArea(pearlsID, 0, reefShallows, cNumberNonGaiaPlayers*2);


// Decorative Corals
int coralID = rmCreateObjectDef("random coral");
rmAddObjectDefItem(coralID, "zpUnderbrushCoral", 1, 0);
rmSetObjectDefMinDistance(coralID, 0.0);
rmSetObjectDefMaxDistance(coralID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(coralID, avoidTeamIslands1);
//rmAddObjectDefConstraint(coralID, avoidBonusIslands1);
rmAddObjectDefConstraint(coralID, avoidLandShort);

for (i=0; <cNumberPlayers)
{
	rmPlaceObjectDefInArea(coralID, 0, rmAreaID("playerCliff"+i), 40);
}

rmPlaceObjectDefInArea(coralID, 0, reefCliff, cNumberNonGaiaPlayers*20);


// Hunts
int pronghornHunts = rmCreateObjectDef("pronghornHunts");
rmAddObjectDefItem(pronghornHunts, "zpRedNeckedWallaby", 8, 14.0);
rmSetObjectDefCreateHerd(pronghornHunts, true);
rmSetObjectDefMinDistance(pronghornHunts, 0);
rmSetObjectDefMaxDistance(pronghornHunts, rmZFractionToMeters(3.44));
rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);	
rmAddObjectDefConstraint(pronghornHunts, stayNorthPart);	
rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

// Reef nuggets
 
int nuggetID= rmCreateObjectDef("nugget"); 
rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
rmSetObjectDefMinDistance(nuggetID, 0.0); 
rmSetObjectDefMaxDistance(nuggetID, rmZFractionToMeters(3.45)); 
rmAddObjectDefConstraint(nuggetID, avoidNugget); 
rmAddObjectDefConstraint(nuggetID, avoidAll);
rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
rmAddObjectDefConstraint(nuggetID, avoidSocket); 
rmAddObjectDefConstraint(nuggetID, avoidWater2); 
rmAddObjectDefConstraint(nuggetID, stayNorthPart);	
rmAddObjectDefConstraint(nuggetID, edgeConstraint);	
rmSetNuggetDifficulty(12, 14); 
rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);   

// >>>>>>>>>>>>>>>>>>>>>>>>>> Make loader move >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
rmSetStatusText("",0.7);

// Forests
int mapTrees=rmCreateObjectDef("map trees");
rmAddObjectDefItem(mapTrees, "ypTreeCeylon", rmRandInt(10,11), rmRandFloat(8.0,9.0));
rmAddObjectDefItem(mapTrees, "TreeCaribbean", rmRandInt(3,4), rmRandFloat(8.0,9.0));
rmAddObjectDefItem(mapTrees, "UnderbrushBorneo", rmRandInt(4,5), rmRandFloat(8.0,9.0));
rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
rmSetObjectDefMinDistance(mapTrees, 0);
rmSetObjectDefMaxDistance(mapTrees, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
rmAddObjectDefConstraint(mapTrees, forestConstraint);
rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
rmAddObjectDefConstraint(mapTrees, avoidWater5);	
rmAddObjectDefConstraint(mapTrees, avoidHarbourSocket);	
rmAddObjectDefConstraint(mapTrees, staySouthPart);	
rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);

int mapTrees2=rmCreateObjectDef("map trees 2");
rmAddObjectDefItem(mapTrees2, "ypTreeCeylon", rmRandInt(10,11), rmRandFloat(8.0,9.0));
rmAddObjectDefItem(mapTrees2, "TreeCaribbean", rmRandInt(3,4), rmRandFloat(8.0,9.0));
rmAddObjectDefItem(mapTrees2, "UnderbrushBorneo", rmRandInt(4,5), rmRandFloat(8.0,9.0));
rmAddObjectDefToClass(mapTrees2, rmClassID("classForest")); 
rmSetObjectDefMinDistance(mapTrees2, 0);
rmSetObjectDefMaxDistance(mapTrees2, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(mapTrees2, avoidTradeRouteSmall);
rmAddObjectDefConstraint(mapTrees2, forestConstraint);
rmAddObjectDefConstraint(mapTrees2, avoidTownCenter);	
rmAddObjectDefConstraint(mapTrees2, avoidHarbourPlatform);	
rmAddObjectDefConstraint(mapTrees2, avoidWater5);	
rmAddObjectDefConstraint(mapTrees2, avoidPirates);	
rmAddObjectDefConstraint(mapTrees2, avoidInventors);	
rmAddObjectDefConstraint(mapTrees2, stayNorthPart);
rmPlaceObjectDefAtLoc(mapTrees2, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

// >>>>>>>>>>>>>>>>>>>>>>>>>> Make loader move >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
rmSetStatusText("",0.8);

// *********************** Water objects ***********************

//Place random whales everywhere --------------------------------------------------------

int whaleID=rmCreateObjectDef("whale");
rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.00));
rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
rmAddObjectDefConstraint(whaleID, whaleLand);
rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2); 

// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

int fishID=rmCreateObjectDef("fish 1");
rmAddObjectDefItem(fishID, fish1, 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(fishID, avoidFish1);
rmAddObjectDefConstraint(fishID, fishVsWhaleID);
rmAddObjectDefConstraint(fishID, fishLand);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);

int fish2ID=rmCreateObjectDef("fish 2");
rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
rmSetObjectDefMinDistance(fish2ID, 0.0);
rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(fish2ID, avoidFish2);
rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
rmAddObjectDefConstraint(fish2ID, fishLand);
rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 9*cNumberNonGaiaPlayers);

int fish3ID=rmCreateObjectDef("fish 3");
rmAddObjectDefItem(fish3ID, fish3, 1, 0.0);
rmSetObjectDefMinDistance(fish3ID, 0.0);
rmSetObjectDefMaxDistance(fish3ID, rmXFractionToMeters(3.45));
rmAddObjectDefConstraint(fish3ID, avoidFish3);
rmAddObjectDefConstraint(fish3ID, fishVsWhaleID);
rmAddObjectDefConstraint(fish3ID, fishLand);
rmPlaceObjectDefAtLoc(fish3ID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);

if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
{
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);	
}

// Water nuggets

int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(6, 6);
rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nugget2b, avoidLand);
rmAddObjectDefConstraint(nugget2b, avoidNuggetWater);
rmAddObjectDefConstraint(nugget2b, avoidPatch);
rmAddObjectDefConstraint(nugget2b, edgeConstraint);	
rmPlaceObjectDefPerPlayer(nugget2b, false, 2);

int nugget2= rmCreateObjectDef("nugget water" + i); 
rmAddObjectDefItem(nugget2, "ypNuggetBoat", 1, 0.0);
rmSetNuggetDifficulty(5, 5);
rmSetObjectDefMinDistance(nugget2, rmXFractionToMeters(0.0));
rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(1.0));
rmAddObjectDefConstraint(nugget2, avoidLand);
rmAddObjectDefConstraint(nugget2, avoidNuggetWater);
rmAddObjectDefConstraint(nugget2, avoidPatch);
rmAddObjectDefConstraint(nugget2, edgeConstraint);	
rmPlaceObjectDefPerPlayer(nugget2, false, 3);

// ------Triggers--------//

string pirate1ID = "0";
string pirate2ID = "0";
string scientist1ID = "0";
string scientist2ID = "0";

pirate1ID = "5";
pirate2ID = "64";
scientist1ID = "96";
scientist2ID = "181";

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
rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australia Mercenaries
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpUnderwaterScientists"); // Mercenary
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
rmCreateTrigger("Activate Scientists"+k);
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Scientists"+k));
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

   if (cNumberNonGaiaPlayers >= 4){
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
   }

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

   if (cNumberNonGaiaPlayers >= 4){
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
   }

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

if (cNumberNonGaiaPlayers >= 4){
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
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainSubmarineSPC2"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainSubmarine2"); //operator
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
    rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainSubmarineSPC1"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainSubmarine1"); //operator
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
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainNautilusSPC2"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainNautilus2"); //operator
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
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainNautilusSPC1"); //operator
    rmSetTriggerEffectParam("Tech2ID","cTechzpTrainNautilus1"); //operator
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

    for(k=1; <= cNumberNonGaiaPlayers) {
    rmCreateTrigger("Submarine Transform"+k);
    rmAddTriggerCondition("ZP PLAYER Human");
    rmSetTriggerConditionParamInt("Player",k);
    rmSetTriggerConditionParam("MyBool", "true");
    rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",k);
    rmSetTriggerEffectParam("TechID","cTechzpTransformNemoSubmarines"); //operator
    rmSetTriggerEffectParamInt("Status",2);
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