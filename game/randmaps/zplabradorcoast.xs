/*
======================
	Labrador Coast
	by dansil92, edited by roda2324
======================
*/

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
 
void main(void) {

// >>>>>>>>>>>>>>>>>>> Make loadbar Move	
rmSetStatusText("",0.01);
 
//pick map size

//size is determined by the number of players across the x axis
//y axis is mostly static, varying minimally

int sizeX = 200*cNumberNonGaiaPlayers;
int sizeY = 410;

if (cNumberNonGaiaPlayers == 2){
sizeY = 275;
}

rmSetMapSize(sizeY, sizeX);


rmSetMapType("land");
rmSetMapType("snow");
rmSetMapType("ArcticTerritories");
rmSetSeaType("ZP Labrador Coast");

rmTerrainInitialize("water");
rmSetLightingSet("yukon_skirmish");

// Define some classes
rmDefineClass("classForest");
rmDefineClass("classPlateau");
int classPatch = rmDefineClass("patch");
int classIce= rmDefineClass("iceTerrain");		
int classCenter = rmDefineClass("center");
int classMountains=rmDefineClass("mountains");
int avoidMountains = rmCreateClassDistanceConstraint("avoid mountains", classMountains, 22.0);
        

//Constraints
int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 3.0);
int avoidIceShort = rmCreateClassDistanceConstraint("avoid Ice short", classIce, 25.0);
int avoidIceZero = rmCreateClassDistanceConstraint("avoid Ice zero", classIce, 2.0);
int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
int avoidPlateau=rmCreateClassDistanceConstraint("stuff vs. cliffs", rmClassID("classPlateau"), 10.0);

int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(0), rmDegreesToRadians(360));

int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 35.0);
int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);

int avoidHunt=rmCreateTypeDistanceConstraint("hunts avoid hunts", "huntable", 55.0);
int waterHunt = rmCreateTerrainMaxDistanceConstraint("hunts stay near the water", "land", false, 10.0);

int avoidHerd=rmCreateTypeDistanceConstraint("herds avoid herds", "herdable", 50.0);

int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 12.0);
int avoidCoinMed=rmCreateTypeDistanceConstraint("avoid coin medium", "Mine", 70.0);
int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short 2", "Land", false, 12.0);
//int avoidWaterX = rmCreateTerrainDistanceConstraint("avoid water short 21", "Land", false, 31.0);
int avoidWaterX = rmCreateTerrainDistanceConstraint("avoid water X", "Land", false, 20.0);

int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 8.0);
int avoidSocket=rmCreateClassDistanceConstraint("socket avoidance", rmClassID("socketClass"), 25.0);

int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 35.0);
int avoidTownCenterSmall=rmCreateTypeDistanceConstraint("avoid Town Center small", "townCenter", 15.0);
int avoidTownCenterMore=rmCreateTypeDistanceConstraint("avoid Town Center more", "townCenter", 40.0);  

int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);

int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 16.0);
int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 6.5);
int avoidLandShort = rmCreateTerrainDistanceConstraint("ship avoid land short", "land", true, 7.0); 
int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 5.0);
       

// Player placing  
float spawnSwitch = rmRandInt(0,1);

int TeamNum = cNumberTeams;
int numPlayer = cNumberPlayers;
int weirdSpawn = 0;

int PlayerNum = cNumberNonGaiaPlayers;
int teamZeroCount = rmGetNumberPlayersOnTeam(0);
int teamOneCount = rmGetNumberPlayersOnTeam(1);


if ( cNumberTeams == 2 && ((teamZeroCount - teamOneCount) == 0)){
	if (spawnSwitch ==0){

		if (PlayerNum == 2)
		{
			rmPlacePlayer(1, 0.40, 0.28);
			rmPlacePlayer(2, 0.40, 0.72);
		}
		else if (PlayerNum == 4)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.15, 0.38, 0.38, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.62, 0.38, 0.85, 0, 0);
		}
		else if (PlayerNum == 6)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.11, 0.38, 0.4, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.6, 0.38, 0.89, 0, 0);
		}
		else
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.08, 0.38, 0.42, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.58, 0.38, 0.92, 0, 0);
		}

	}
	
	else if(spawnSwitch ==1){

		if (PlayerNum == 2)
		{
			rmPlacePlayer(2, 0.40, 0.28);
			rmPlacePlayer(1, 0.40, 0.72);
		}
		else if (PlayerNum == 4)
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.15, 0.38, 0.38, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.62, 0.38, 0.85, 0, 0);
		}
		else if (PlayerNum == 6)
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.11, 0.38, 0.4, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.6, 0.38, 0.89, 0, 0);
		}
		else
		{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.38, 0.08, 0.38, 0.42, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.38, 0.58, 0.38, 0.92, 0, 0);
		}
	}

}

else{
	weirdSpawn =1;
	float placementGap =0;
	if (cNumberNonGaiaPlayers <= 4){
		if (spawnSwitch ==0){
			for (k=1; <= cNumberNonGaiaPlayers) {
				rmPlacePlayer(k, 0.38, 0.15+placementGap);
				placementGap = placementGap+0.7/(cNumberNonGaiaPlayers-1);
			}
		}
		else{
			for (k=1; <= cNumberNonGaiaPlayers) {
				rmPlacePlayer(k, 0.38, 0.85-placementGap);
				placementGap = placementGap+0.7/(cNumberNonGaiaPlayers-1);
			}
		}
	}

	else {
		if (spawnSwitch ==0){
			for (k=1; <= cNumberNonGaiaPlayers) {
				rmPlacePlayer(k, 0.38, 0.08+placementGap);
				placementGap = placementGap+0.84/(cNumberNonGaiaPlayers-1);
			}
		}
		else{
			for (k=1; <= cNumberNonGaiaPlayers) {
				rmPlacePlayer(k, 0.38, 0.92-placementGap);
				placementGap = placementGap+0.84/(cNumberNonGaiaPlayers-1);
			}
		}
	}
}
		
chooseMercs();

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.1); 

int continent2 = rmCreateArea("continent");
rmSetAreaSize(continent2, 0.67, 0.67);
rmSetAreaLocation(continent2, 0.3, 0.5);
rmAddAreaInfluenceSegment(continent2, 0.3, 0.0, 0.3, 1.0);
rmSetAreaMix(continent2, "rockies_snow");
rmSetAreaBaseHeight(continent2, 2.0);
rmSetAreaCoherence(continent2, 1.0);
rmSetAreaSmoothDistance(continent2, 10);
rmSetAreaHeightBlend(continent2, 1);
rmSetAreaElevationNoiseBias(continent2, 0);
rmSetAreaElevationEdgeFalloffDist(continent2, 10);
rmSetAreaElevationVariation(continent2, 4);
rmSetAreaElevationPersistence(continent2, .2);
rmSetAreaElevationOctaves(continent2, 5);
rmSetAreaElevationMinFrequency(continent2, 0.04);
rmSetAreaElevationType(continent2, cElevTurbulence);  
rmBuildArea(continent2);    


// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.2); 

// ************************ PLACE PLACE TRADE ROUTES  *******************************

int stopperID=rmCreateObjectDef("Armored Train Stopper");
rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID, true);
rmSetObjectDefMinDistance(stopperID, 0.0);
rmSetObjectDefMaxDistance(stopperID, 0.0);  

int stopperID2=rmCreateObjectDef("Armored Train Stopper 2");
rmAddObjectDefItem(stopperID2, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID2, true);
rmSetObjectDefMinDistance(stopperID2, 0.0);
rmSetObjectDefMaxDistance(stopperID2, 0.0);  

int stopperID3=rmCreateObjectDef("Armored Train Stopper 3");
rmAddObjectDefItem(stopperID3, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID3, true);
rmSetObjectDefMinDistance(stopperID3, 0.0);
rmSetObjectDefMaxDistance(stopperID3, 0.0);  

int stopperID4=rmCreateObjectDef("Armored Train Stopper 4");
rmAddObjectDefItem(stopperID4, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID4, true);
rmSetObjectDefMinDistance(stopperID4, 0.0);
rmSetObjectDefMaxDistance(stopperID4, 0.0);  

int stopperID5=rmCreateObjectDef("Armored Train Stopper 5");
rmAddObjectDefItem(stopperID5, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID5, true);
rmSetObjectDefMinDistance(stopperID5, 0.0);
rmSetObjectDefMaxDistance(stopperID5, 0.0);  

int stopperID6=rmCreateObjectDef("Armored Train Stopper 6");
rmAddObjectDefItem(stopperID6, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID6, true);
rmSetObjectDefMinDistance(stopperID6, 0.0);
rmSetObjectDefMaxDistance(stopperID6, 0.0);  

int stopperID7=rmCreateObjectDef("Armored Train Stopper 7");
rmAddObjectDefItem(stopperID7, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID7, true);
rmSetObjectDefMinDistance(stopperID7, 0.0);
rmSetObjectDefMaxDistance(stopperID7, 0.0);  

int stopperID8=rmCreateObjectDef("Armored Train Stopper 8");
rmAddObjectDefItem(stopperID8, "zpSPCWaterSpawnPoint", 1, 0.0);
rmSetObjectDefAllowOverlap(stopperID8, true);
rmSetObjectDefMinDistance(stopperID8, 0.0);
rmSetObjectDefMaxDistance(stopperID8, 0.0); 

// Define Station Groupings

int stationGrouping01 = -1;
stationGrouping01 = rmCreateGrouping("station grouping 01", "Railway_Station_Big_SW_nostation"); // for independent Train station
rmSetGroupingMinDistance(stationGrouping01, 0.0);
rmSetGroupingMaxDistance (stationGrouping01, 0.0);

int stationGrouping001 = -1;
stationGrouping001 = rmCreateGrouping("station 01", "Railway_Station_Big_SW_stationA"); // Independent Train Station
rmSetGroupingMinDistance(stationGrouping001, 0.0);
rmSetGroupingMaxDistance (stationGrouping001, 0.0);


// ------------------------------ TRADE ROUTES ------------------------------------------


// Trade Route 1

int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID2, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID3, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID4, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID5, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID6, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID7, tradeRouteID);
rmSetObjectDefTradeRouteID(stopperID8, tradeRouteID);
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, .01);
rmAddTradeRouteWaypoint(tradeRouteID, .3, .5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, .99);

rmBuildTradeRoute(tradeRouteID, "snow");

// Place stations
if (cNumberNonGaiaPlayers <=2){	

	rmPlaceObjectDefAtLoc(stopperID, 0, 0.31,  rmPlayerLocZFraction(1));
	vector StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
	rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));

	rmPlaceObjectDefAtLoc(stopperID2, 0, 0.31,  rmPlayerLocZFraction(2));
	vector StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
	rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
	rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
}
else{	
	if (spawnSwitch ==0){
		rmPlaceObjectDefAtLoc(stopperID, 0, 0.29,  rmPlayerLocZFraction(1));
		StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));

		rmPlaceObjectDefAtLoc(stopperID2, 0, 0.29,  rmPlayerLocZFraction(2));
		StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));

		rmPlaceObjectDefAtLoc(stopperID3, 0, 0.29,  rmPlayerLocZFraction(3));
		vector StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));		

		rmPlaceObjectDefAtLoc(stopperID4, 0, 0.29,  rmPlayerLocZFraction(4));
		vector StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));

		rmPlaceObjectDefAtLoc(stopperID5, 0, 0.29,  rmPlayerLocZFraction(5));
		vector StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));

		rmPlaceObjectDefAtLoc(stopperID6, 0, 0.29,  rmPlayerLocZFraction(6));
		vector StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

		rmPlaceObjectDefAtLoc(stopperID7, 0, 0.29,  rmPlayerLocZFraction(7));
		vector StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));

		rmPlaceObjectDefAtLoc(stopperID8, 0, 0.29,  rmPlayerLocZFraction(8));
		vector StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
	}
	else{
		rmPlaceObjectDefAtLoc(stopperID, 0, 0.29,  rmPlayerLocZFraction(8));
		StopperLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc1)), rmZMetersToFraction(xsVectorGetZ(StopperLoc1)));

		rmPlaceObjectDefAtLoc(stopperID2, 0, 0.29,  rmPlayerLocZFraction(7));
		StopperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID2, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc2)), rmZMetersToFraction(xsVectorGetZ(StopperLoc2)));

		rmPlaceObjectDefAtLoc(stopperID3, 0, 0.29,  rmPlayerLocZFraction(6));
		StopperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID3, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc3)), rmZMetersToFraction(xsVectorGetZ(StopperLoc3)));		

		rmPlaceObjectDefAtLoc(stopperID4, 0, 0.29,  rmPlayerLocZFraction(5));
		StopperLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID4, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc4)), rmZMetersToFraction(xsVectorGetZ(StopperLoc4)));

		rmPlaceObjectDefAtLoc(stopperID5, 0, 0.29,  rmPlayerLocZFraction(4));
		StopperLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID5, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc5)), rmZMetersToFraction(xsVectorGetZ(StopperLoc5)));

		rmPlaceObjectDefAtLoc(stopperID6, 0, 0.29,  rmPlayerLocZFraction(3));
		StopperLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID6, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc6)), rmZMetersToFraction(xsVectorGetZ(StopperLoc6)));

		rmPlaceObjectDefAtLoc(stopperID7, 0, 0.29,  rmPlayerLocZFraction(2));
		StopperLoc7 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID7, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc7)), rmZMetersToFraction(xsVectorGetZ(StopperLoc7)));

		rmPlaceObjectDefAtLoc(stopperID8, 0, 0.29,  rmPlayerLocZFraction(1));
		StopperLoc8 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID8, 0));
		rmPlaceGroupingAtLoc(stationGrouping01, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
		rmPlaceGroupingAtLoc(stationGrouping001, 0, rmXMetersToFraction(xsVectorGetX(StopperLoc8)), rmZMetersToFraction(xsVectorGetZ(StopperLoc8)));
	}
}


// Armored Train 1

int tradeRouteID2 = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, .01);
rmAddTradeRouteWaypoint(tradeRouteID2, .3, .5);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, .99);

rmBuildTradeRoute(tradeRouteID2, "armored_train");

// Armored Train 2

int tradeRouteID3 = rmCreateTradeRoute();
rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, .99);
rmAddTradeRouteWaypoint(tradeRouteID3, .3, .5);
rmAddTradeRouteWaypoint(tradeRouteID3, 0.3, .01);

rmBuildTradeRoute(tradeRouteID3, "armored_train");

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.30);


//=============Place Natives====================

//Choose Natives
int subCiv0=-1;
int subCiv1=-1;
int subCiv2=-1;
int subCiv3=-1;

//Cameleers are awesome

if (rmAllocateSubCivs(4) == true)
{
	subCiv0=rmGetCivID("inuitnatives");
	rmEchoInfo("subCiv0 is inuitnatives "+subCiv0);
	if (subCiv0 >= 0)
		rmSetSubCiv(0, "inuitnatives");

	subCiv1=rmGetCivID("inuitnatives");
	rmEchoInfo("subCiv1 is inuitnatives"+subCiv1);
	if (subCiv1 >= 0)
			rmSetSubCiv(1, "inuitnatives");
	
	subCiv2=rmGetCivID("zpscientists");
	rmEchoInfo("subCiv2 is zpscientists"+subCiv2);
	if (subCiv2 >= 0)
		rmSetSubCiv(2, "zpscientists");

	subCiv3=rmGetCivID("zpscientists");
	rmEchoInfo("subCiv3 is zpscientists"+subCiv3);
	if (subCiv3 >= 0)
		rmSetSubCiv(3, "zpscientists");
}

//===========Draw Major Landforms===============


//cliffs keep area narrower and define area
int cliffs = rmCreateArea("NW cliffs");
rmSetAreaSize(cliffs, 0.1, 0.11); 
rmAddAreaToClass(cliffs, rmClassID("classPlateau"));
rmSetAreaCliffType(cliffs, "Rocky Mountain Edge");    
rmSetAreaCliffEdge(cliffs, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
rmSetAreaCliffPainting(cliffs, true, true, true, 0.4, true);
rmSetAreaCliffHeight(cliffs, 4, 0.1, 0.5);
rmSetAreaCoherence(cliffs, .97);
rmSetAreaLocation(cliffs, .03, .5);	
rmAddAreaInfluenceSegment(cliffs, 0.05, 0.95, 0.05, 0.05);
rmBuildArea(cliffs);

//laugh at wall lamers
				
int iceWall =rmCreateArea("icy patch");
rmSetAreaLocation(iceWall, 0.7, 0.5);
rmAddAreaInfluenceSegment(iceWall, 0.7, 1.0, 0.7, 0.0);
rmSetAreaTerrainType(iceWall, "great_lakes\ground_ice1_gl");      
rmSetAreaSmoothDistance(iceWall, 10);
rmSetAreaHeightBlend(iceWall, 1);
rmSetAreaSize(iceWall, .1, .1);      
rmSetAreaBaseHeight(iceWall, 1.0);
rmSetAreaCoherence(iceWall, .8);
rmAddAreaToClass(iceWall, classIce);
rmBuildArea(iceWall);

if ((weirdSpawn==1 || rmGetIsKOTH() == true) && cNumberNonGaiaPlayers>2){
	int iceWall2 =rmCreateArea("icy patch2");
	rmSetAreaLocation(iceWall2, 0.95, 0.5);
	rmAddAreaInfluenceSegment(iceWall2, 0.95, 0.63, 0.95, 0.37);
	rmSetAreaTerrainType(iceWall2, "great_lakes\ground_ice1_gl");      
	rmSetAreaSmoothDistance(iceWall2, 10);
	rmSetAreaHeightBlend(iceWall2, 1);
	rmSetAreaSize(iceWall2, .03, .03);      
	rmSetAreaBaseHeight(iceWall2, 1.0);
	rmSetAreaCoherence(iceWall2, .8);
	rmAddAreaToClass(iceWall2, classIce);
	rmBuildArea(iceWall2);
}

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.4); 

// ************************** Scientists ***************************

// Place Controllers

int scientistControllerID = rmCreateObjectDef("scientist controller 1");
rmAddObjectDefItem(scientistControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);

int scientistControllerID2 = rmCreateObjectDef("scientist controller 2");
rmAddObjectDefItem(scientistControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);

if (weirdSpawn==1){
	rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.93, 0.63);
	rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.93, 0.37);
}

else{
	if (cNumberNonGaiaPlayers ==2){
		rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.77, 0.85);
		rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.77, 0.15);
	}
	else if (cNumberNonGaiaPlayers ==6){
		rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.77, 0.55);
		rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.77, 0.45);
	}
	else{
		rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.77, 0.73);
		rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.77, 0.27);
	}
}

vector scientistControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID, 0));
vector scientistControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID2, 0));

// Scientist Village 1

int westLabIsland = rmCreateArea ("west lab island");
rmSetAreaSize(westLabIsland, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(westLabIsland, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)));
rmSetAreaCoherence(westLabIsland, 0.8);
rmSetAreaBaseHeight(westLabIsland, 1.0);
rmAddAreaToClass(westLabIsland, classIce);
rmSetAreaTerrainType(westLabIsland, "great_lakes\ground_ice1_gl");
rmSetAreaSmoothDistance(westLabIsland, 10);
rmBuildArea(westLabIsland);

int westLabTerrain = rmCreateArea ("west lab terrain");
rmSetAreaSize(westLabTerrain, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
rmSetAreaLocation(westLabTerrain, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)));
rmSetAreaCoherence(westLabTerrain, 1.0);
rmSetAreaTerrainType(westLabTerrain, "yukon\ground1_yuk");
rmBuildArea(westLabTerrain);

int scientistVillageID1 = -1;
int scientistVillage1Type = rmRandInt(1,2);
scientistVillageID1 = rmCreateGrouping("scientist lab 1", "Scientist_Lab02");


rmPlaceGroupingAtLoc(scientistVillageID1, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)), 1);

int nativewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
rmAddObjectDefItem(nativewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
rmAddClosestPointConstraint(flagLand);
rmAddClosestPointConstraint(playerEdgeConstraint);

vector closeToVillage1 = rmFindClosestPointVector(scientistControllerLoc1 , rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(nativewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

rmClearClosestPointConstraints();

int pirateportID1 = -1;
pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
rmAddClosestPointConstraint(portOnShore);
rmAddClosestPointConstraint(playerEdgeConstraint);

vector closeToVillage1a = rmFindClosestPointVector(scientistControllerLoc1, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

rmClearClosestPointConstraints();

// Scientist Village 2
int eastLabIsland = rmCreateArea ("east lab island");
rmSetAreaSize(eastLabIsland, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
rmSetAreaLocation(eastLabIsland, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)));
rmSetAreaCoherence(eastLabIsland, 0.8);
rmSetAreaBaseHeight(eastLabIsland, 1.0);
rmAddAreaToClass(eastLabIsland, classIce);
rmSetAreaSmoothDistance(eastLabIsland, 10);
rmSetAreaTerrainType(eastLabIsland, "great_lakes\ground_ice1_gl");
rmBuildArea(eastLabIsland);

int eastLabTerrain = rmCreateArea ("east lab terrain");
rmSetAreaSize(eastLabTerrain, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
rmSetAreaLocation(eastLabTerrain, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)));
rmSetAreaCoherence(eastLabTerrain, 1.0);
rmSetAreaTerrainType(eastLabTerrain, "yukon\ground1_yuk");

rmBuildArea(eastLabTerrain);

int scientistVillageID2 = -1;
int scientistVillage2Type = rmRandInt(1,2);
scientistVillageID2 = rmCreateGrouping("scientist lab 2", "Scientist_Lab01");


rmPlaceGroupingAtLoc(scientistVillageID2, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)), 1);

int nativewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
rmAddObjectDefItem(nativewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
rmAddClosestPointConstraint(flagLand);
rmAddClosestPointConstraint(playerEdgeConstraint);

vector closeToVillage2 = rmFindClosestPointVector(scientistControllerLoc2 , rmXFractionToMeters(1.0));
rmPlaceObjectDefAtLoc(nativewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

rmClearClosestPointConstraints();

int pirateportID2 = -1;
pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
rmAddClosestPointConstraint(portOnShore);
rmAddClosestPointConstraint(playerEdgeConstraint);

vector closeToVillage2a = rmFindClosestPointVector(scientistControllerLoc2, rmXFractionToMeters(1.0));
rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

rmClearClosestPointConstraints();

// ****************** KotH ***********************

if (rmGetIsKOTH() == true) {
	int KotHIsland = rmCreateArea ("koth island");
	rmSetAreaSize(KotHIsland, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
	rmSetAreaLocation(KotHIsland, 0.93, 0.5);
	rmSetAreaCoherence(KotHIsland, 0.8);
	rmSetAreaBaseHeight(KotHIsland, 1.0);
	rmAddAreaToClass(KotHIsland, classIce);
	rmSetAreaTerrainType(KotHIsland, "great_lakes\ground_ice1_gl");
	rmSetAreaSmoothDistance(KotHIsland, 10);
	rmBuildArea(KotHIsland);

	int KotHTerrain = rmCreateArea ("koth terrain");
	rmSetAreaSize(KotHTerrain, rmAreaTilesToFraction(150.0), rmAreaTilesToFraction(150.0));
	rmSetAreaLocation(KotHTerrain, 0.93, 0.5);
	rmSetAreaCoherence(KotHTerrain, 1.0);
	rmSetAreaTerrainType(KotHTerrain, "yukon\ground1_yuk");
	rmBuildArea(KotHTerrain);
	ypKingsHillPlacer(0.93, 0.5, 0.00, 0);
}

// ************************ Inuits ************************
	
// Set up Natives	
int nativeID0 = -1;
int nativeID1 = -1;
int nativeID2 = -1;
int nativeID3 = -1;

int nootka1VillageType = rmRandInt(1,5);
int nootka2VillageType = rmRandInt(1,5);
	
nativeID0 = rmCreateGrouping("native site 1", "native inuit village 0"+nootka1VillageType);
rmSetGroupingMinDistance(nativeID0, 0.00);
rmSetGroupingMaxDistance(nativeID0, 0.00);
rmAddGroupingToClass(nativeID0, rmClassID("classPlateau"));

nativeID1 = rmCreateGrouping("native site 2", "native inuit village 0"+nootka2VillageType);
rmSetGroupingMinDistance(nativeID1, 0.00);
rmSetGroupingMaxDistance(nativeID1, 0.00);
rmAddGroupingToClass(nativeID1, rmClassID("classPlateau"));

//========place=====

rmPlaceGroupingAtLoc(nativeID0, 0, 0.18, 0.5);
rmPlaceGroupingAtLoc(nativeID0, 0, 0.18, 0.85);
rmPlaceGroupingAtLoc(nativeID0, 0, 0.18, 0.15);


	if (PlayerNum >= 7)
{
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.18, 0.3);
	rmPlaceGroupingAtLoc(nativeID0, 0, 0.18, 0.7);


}

// ********************** Player sections ***********************

//=========cliffs to northeast and southwest of each player=====

int stayOnLand=rmCreateBoxConstraint("stay on land", 0.0, 0.0, 0.65, 1.0);

//first draw an area around tc to mark player areas

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int center = rmCreateArea("center"+i);
	rmAddAreaToClass(center, rmClassID("center"));
	rmSetAreaSize(center, rmAreaTilesToFraction(5600), rmAreaTilesToFraction(5600));
	rmSetAreaLocation(center, 0.6, rmPlayerLocZFraction(i));
	rmAddAreaInfluenceSegment(center, 0.2, rmPlayerLocZFraction(i), 0.75, rmPlayerLocZFraction(i));
	rmSetAreaCoherence(center, 0.9);
	rmBuildArea(center);   
}

//draw cliffs to NW of each tc that avoid player area

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int playerCliffSW = rmCreateArea("playerCliffSW"+i);
	rmSetAreaSize(playerCliffSW, rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800)); 
	rmAddAreaToClass(playerCliffSW, rmClassID("classPlateau"));
	rmSetAreaCliffType(playerCliffSW, "Rocky Mountain Edge");
	rmSetAreaCliffEdge(playerCliffSW, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
	rmSetAreaCliffPainting(playerCliffSW, false, true, true, 0.4, true);
	rmSetAreaCliffHeight(playerCliffSW, 5, 0.1, 0.5);
	rmAddAreaConstraint(playerCliffSW, avoidCenter);
	rmAddAreaConstraint(playerCliffSW, avoidIceZero);
	rmAddAreaConstraint(playerCliffSW, avoidPlateau);
	rmAddAreaConstraint(playerCliffSW, stayOnLand);
	rmAddAreaConstraint(playerCliffSW, avoidTradeRouteSmall);
	rmSetAreaSmoothDistance(playerCliffSW, 10);
	rmAddAreaConstraint(playerCliffSW, avoidSocket); 
	rmSetAreaCoherence(playerCliffSW, .7);
	rmSetAreaLocation(playerCliffSW, 0.5, rmPlayerLocZFraction(i)-rmZTilesToFraction(50));
	rmAddAreaToClass(playerCliffSW, classMountains);	
	rmBuildArea(playerCliffSW);
}


//draw cliffs to SE of each tc that avoid player area

for(i=1; < cNumberNonGaiaPlayers + 1) {
	int playerCliffNE = rmCreateArea("playerCliffNE"+i);
	rmSetAreaSize(playerCliffNE, rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800)); 
	rmAddAreaToClass(playerCliffNE, rmClassID("classPlateau"));
	rmSetAreaCliffType(playerCliffNE, "Rocky Mountain Edge");
	rmSetAreaCliffEdge(playerCliffNE, 1, 1.0, 0.0, 0.0, 2); //4,.225 looks cool too
	rmSetAreaCliffPainting(playerCliffNE, false, true, true, 0.4, true);
	rmSetAreaCliffHeight(playerCliffNE, 5, 0.1, 0.5);
	rmAddAreaConstraint(playerCliffNE, avoidCenter);
	rmAddAreaConstraint(playerCliffNE, avoidIceZero);
	rmAddAreaConstraint(playerCliffNE, avoidPlateau);
	rmAddAreaConstraint(playerCliffNE, avoidTradeRouteSmall);
	rmAddAreaConstraint(playerCliffNE, stayOnLand);
	rmSetAreaSmoothDistance(playerCliffNE, 10);
	rmAddAreaConstraint(playerCliffNE, avoidSocket); 
	rmSetAreaCoherence(playerCliffNE, .9);
	rmSetAreaLocation(playerCliffNE, 0.6,  rmPlayerLocZFraction(i)+rmZTilesToFraction(50));	
	rmAddAreaToClass(playerCliffNE, classMountains);
	rmBuildArea(playerCliffNE);
}

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
rmAddObjectDefItem(treeID, "ypTreeHimalayas", rmRandInt(5,6), 7.0);
rmSetObjectDefMinDistance(treeID, 15.0);
rmSetObjectDefMaxDistance(treeID, 18.0);
rmAddObjectDefConstraint(treeID, avoidTownCenterSmall);
rmAddObjectDefConstraint(treeID, avoidCoin);

int foodID = rmCreateObjectDef("starting hunt");
rmAddObjectDefItem(foodID, "elk", 6, 8.0);
rmSetObjectDefMinDistance(foodID, 10.0);
rmSetObjectDefMaxDistance(foodID, 10.0);
rmSetObjectDefCreateHerd(foodID, true);
rmAddObjectDefConstraint(foodID, avoidPlateau);	


int foodID2 = rmCreateObjectDef("starting hunt 2");
rmAddObjectDefItem(foodID2, "elk", 7, 8.0);
rmSetObjectDefMinDistance(foodID2, 28.0);
rmSetObjectDefMaxDistance(foodID2, 29.0);
rmSetObjectDefCreateHerd(foodID2, true);
rmAddObjectDefConstraint(foodID2, avoidPlateau);	

				
int foodID3 = rmCreateObjectDef("starting hunt 3");
rmAddObjectDefItem(foodID3, "bighornsheep", 8, 8.0);
rmSetObjectDefMinDistance(foodID3, 45.0);
rmSetObjectDefMaxDistance(foodID3, 45.0);
rmSetObjectDefCreateHerd(foodID3, true);
rmAddObjectDefConstraint(foodID3, avoidPlateau);	

int extraberrywagon=rmCreateObjectDef("jApaN cAnT hUnT");
rmAddObjectDefItem(extraberrywagon, "ypBerryWagon1", 1, 0.0);
rmSetObjectDefMinDistance(extraberrywagon, 10.0);
rmSetObjectDefMaxDistance(extraberrywagon, 10.0);

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.5);


for(i=1; < cNumberNonGaiaPlayers + 1) {
	int id=rmCreateArea("Player"+i);
	rmSetPlayerArea(i, id);

	int startID = rmCreateObjectDef("object"+i);
	rmAddObjectDefItem(startID, "TownCenter", 1, 3.0);
	rmSetObjectDefMinDistance(startID, 0.0);
	rmSetObjectDefMaxDistance(startID, 4.0);

	rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	//rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(treeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	//rmPlaceObjectDefAtLoc(goldID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID2, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(foodID3, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	int waterFlag = rmCreateObjectDef("HC water flag "+i);
	rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0.0);
	rmSetObjectDefMinDistance(waterFlag, 1);
	rmSetObjectDefMaxDistance(waterFlag, 10);
	rmAddObjectDefConstraint(waterFlag, avoidLandShort);	
	rmPlaceObjectDefAtLoc(waterFlag, i, 0.82, rmPlayerLocZFraction(i), 1);

	if (rmGetPlayerCiv(i) == rmGetCivID("Japanese")) {
		rmPlaceObjectDefAtLoc(extraberrywagon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}

}

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.6);
	/*
==================
resource placement
==================
*/


int pronghornHunts = rmCreateObjectDef("pronghornHunts");
rmAddObjectDefItem(pronghornHunts, "bighornsheep", 8, 14.0);
rmSetObjectDefCreateHerd(pronghornHunts, true);
rmSetObjectDefMinDistance(pronghornHunts, 0);
rmSetObjectDefMaxDistance(pronghornHunts, rmZFractionToMeters(0.44));
rmAddObjectDefConstraint(pronghornHunts, avoidTownCenterMore);
rmAddObjectDefConstraint(pronghornHunts, avoidHunt);
rmAddObjectDefConstraint(pronghornHunts, avoidPlateau);
rmAddObjectDefConstraint(pronghornHunts, avoidWaterShort);	
rmPlaceObjectDefAtLoc(pronghornHunts, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

int islandminesID = rmCreateObjectDef("island silver");
rmAddObjectDefItem(islandminesID, "mine", 1, 1.0);
rmSetObjectDefMinDistance(islandminesID, 0.0);
rmSetObjectDefMaxDistance(islandminesID, rmZFractionToMeters(0.46));
rmAddObjectDefConstraint(islandminesID, avoidCoinMed);
rmAddObjectDefConstraint(islandminesID, avoidTownCenterMore);
rmAddObjectDefConstraint(islandminesID, avoidSocket);
rmAddObjectDefConstraint(islandminesID, avoidAll); 
rmAddObjectDefConstraint(islandminesID, avoidPlateau);	
rmAddObjectDefConstraint(islandminesID, avoidWaterShort);
rmAddObjectDefConstraint(islandminesID, forestConstraintShort);
//rmAddObjectDefConstraint(islandminesID, circleConstraint);
rmPlaceObjectDefAtLoc(islandminesID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

int nuggetID= rmCreateObjectDef("nugget"); 
rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0); 
rmSetObjectDefMinDistance(nuggetID, 0.0); 
rmSetObjectDefMaxDistance(nuggetID, rmZFractionToMeters(0.45)); 
rmAddObjectDefConstraint(nuggetID, avoidNugget); 
//rmAddObjectDefConstraint(nuggetID, circleConstraint);
rmAddObjectDefConstraint(nuggetID, avoidTownCenter);
rmAddObjectDefConstraint(nuggetID, forestConstraintShort);
rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSmall);
rmAddObjectDefConstraint(nuggetID, avoidSocket); 
rmAddObjectDefConstraint(nuggetID, avoidAll); 
rmAddObjectDefConstraint(nuggetID, avoidPlateau);	
rmAddObjectDefConstraint(nuggetID, avoidWaterShort);
rmSetNuggetDifficulty(1, 2); 
rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);   

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.7);

int mapTrees=rmCreateObjectDef("map trees");
rmAddObjectDefItem(mapTrees, "ypTreeHimalayas", rmRandInt(12,15), rmRandFloat(14.0,15.0));
rmAddObjectDefToClass(mapTrees, rmClassID("classForest")); 
rmSetObjectDefMinDistance(mapTrees, 0);
rmSetObjectDefMaxDistance(mapTrees, rmZFractionToMeters(0.48));
rmAddObjectDefConstraint(mapTrees, avoidTradeRouteSmall);
rmAddObjectDefConstraint(mapTrees, avoidSocket);
rmAddObjectDefConstraint(mapTrees, forestConstraint);
rmAddObjectDefConstraint(mapTrees, avoidTownCenter);	
rmAddObjectDefConstraint(mapTrees, avoidIceShort);	
//rmAddObjectDefConstraint(mapTrees, avoidMountains);	
//rmAddObjectDefConstraint(mapTrees, avoidWaterShort);	
rmPlaceObjectDefAtLoc(mapTrees, 0, 0.5, 0.5, 25*cNumberNonGaiaPlayers);


// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.8);


int bonusTrees=rmCreateObjectDef("bonusTrees");
rmAddObjectDefItem(bonusTrees, "UnderbrushRockiesSnow", rmRandInt(2,3), rmRandFloat(8.0,11.0));
rmAddObjectDefConstraint(bonusTrees, circleConstraint);
//rmAddObjectDefConstraint(bonusTrees, forestConstraint);
rmAddObjectDefConstraint(bonusTrees, avoidTradeRouteSmall);	
rmAddObjectDefConstraint(bonusTrees, avoidIceShort);	
//rmAddObjectDefConstraint(bonusTrees, avoidMountains);
rmPlaceObjectDefInArea(bonusTrees, 0, continent2, 25*cNumberNonGaiaPlayers);



//fish and their constraints placed together at the end for ease of removal
int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "FishCod", 17.0);
int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 60.0);
int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 26.0);

int fishID=rmCreateObjectDef("fish Mahi");
rmAddObjectDefItem(fishID, "FishCod", 1, 0.0);
rmSetObjectDefMinDistance(fishID, 0.0);
rmSetObjectDefMaxDistance(fishID, rmZFractionToMeters(0.5));
rmAddObjectDefConstraint(fishID, fishVsFishID);
rmAddObjectDefConstraint(fishID, fishLand);
rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 12*cNumberNonGaiaPlayers);

if (cNumberTeams >= 3){
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);
}


int whaleID=rmCreateObjectDef("whale");
rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
rmSetObjectDefMinDistance(whaleID, 0.0);
rmSetObjectDefMaxDistance(whaleID, 5);
//===place a whale directly below each player tc====

for(i=1; < cNumberNonGaiaPlayers + 1) {
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.87, rmPlayerLocZFraction(i));
}
if (cNumberNonGaiaPlayers == 2){
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.87, 0.5);
}

// >>>>>>>>>>>>>>>> Make Loadbar Move
rmSetStatusText("",0.9);

// ------Triggers--------//
string unitID1 = "8";
string unitID2 = "58";
string unitID3 = "108";
string unitID4 = "158";
string unitID5 = "208";
string unitID6 = "258";
string unitID7 = "308";
string unitID8 = "358";
int armoredTrainActive = 90;
int armoredTrainCooldown = 10;
int armoredTrainCooldown2 = 240;

// Ship Training
string unitIDsc00 = "455";
string unitIDsc01 = "545";

if (cNumberNonGaiaPlayers <=2){
	unitID1 = "8";
	unitID2 = "58";
	unitIDsc00 = "132";
	unitIDsc01 = "222";
	}
if (cNumberNonGaiaPlayers ==3){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitIDsc00 = "182";
	unitIDsc01 = "272";
	}
if (cNumberNonGaiaPlayers ==4){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitID4 = "158";
	unitIDsc00 = "232";
	unitIDsc01 = "322";
	}
if (cNumberNonGaiaPlayers ==5){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitID4 = "158";
	unitID5 = "208";
	unitIDsc00 = "282";
	unitIDsc01 = "372";
	}
if (cNumberNonGaiaPlayers ==6){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitID4 = "158";
	unitID5 = "208";
	unitID6 = "258";
	unitIDsc00 = "332";
	unitIDsc01 = "422";
	}
if (cNumberNonGaiaPlayers ==7){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitID4 = "158";
	unitID5 = "208";
	unitID6 = "258";
	unitID7 = "308";
	unitIDsc00 = "382";
	unitIDsc01 = "472";
	}
if (cNumberNonGaiaPlayers ==8){
	unitID1 = "8";
	unitID2 = "58";
	unitID3 = "108";
	unitID4 = "158";
	unitID5 = "208";
	unitID6 = "258";
	unitID7 = "308";
	unitID8 = "358";
	unitIDsc00 = "432";
	unitIDsc01 = "522";
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Trade Route Setup

rmCreateTrigger("AT_Initialize");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
rmSetTriggerEffectParam("ShowUnit","false");
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

// Renegades Control




// Trade Route Upgrade

for(k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("AT_TR_Upgrade_Plr"+k);
}

for(k=1; <= cNumberNonGaiaPlayers) {
rmSwitchToTrigger(rmTriggerID("AT_TR_Upgrade_Plr"+k));
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("Trade Route Set Level");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParamInt("Level",2);
rmAddTriggerEffect("Trade Route Set Level");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParamInt("Level",1);
rmAddTriggerEffect("Trade Route Set Level");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParamInt("Level",1);	
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
for(i=1; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_TR_Upgrade_Plr"+i));
}
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Update Sockets


rmCreateTrigger("I Update Sockets");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","Stagecoach");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Sockets");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",0);
rmSetTriggerConditionParam("Protounit","TrainEngine");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");
for(i=0; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpTrainStationUpgradeA");
	rmSetTriggerEffectParamInt("Status",2);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Normalize Trade Routes

rmCreateTrigger("AT1_Normalize_TR");
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",1000);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","ArmoredTrain");
rmSetTriggerEffectParamInt("Value",0);

rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",3);
rmSetTriggerEffectParam("ShowUnit","false");

rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// ****** ARMORED TRAIN SEND AND STOP ******

// Define Triggers

for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT1_Send_Station1_Plr"+k);
	rmCreateTrigger("AT1_Send_Station2_Plr"+k);
	rmCreateTrigger("AT1_Break_Station1_Plr"+k);
	rmCreateTrigger("AT1_Break_Station2_Plr"+k);

	if (cNumberNonGaiaPlayers >= 3){
		rmCreateTrigger("AT1_Send_Station3_Plr"+k);
		rmCreateTrigger("AT1_Break_Station3_Plr"+k);
		}

	if (cNumberNonGaiaPlayers >= 4){
		rmCreateTrigger("AT1_Send_Station4_Plr"+k);
		rmCreateTrigger("AT1_Break_Station4_Plr"+k);
		}

	if (cNumberNonGaiaPlayers >= 5){
		rmCreateTrigger("AT1_Send_Station5_Plr"+k);
		rmCreateTrigger("AT1_Break_Station5_Plr"+k);
		}

	if (cNumberNonGaiaPlayers >= 6){
		rmCreateTrigger("AT1_Send_Station6_Plr"+k);
		rmCreateTrigger("AT1_Break_Station6_Plr"+k);
		}

	if (cNumberNonGaiaPlayers >=7){
		rmCreateTrigger("AT1_Send_Station7_Plr"+k);
		rmCreateTrigger("AT1_Break_Station7_Plr"+k);
		}

	if (cNumberNonGaiaPlayers >=8){
		rmCreateTrigger("AT1_Send_Station8_Plr"+k);
		rmCreateTrigger("AT1_Break_Station8_Plr"+k);
		}


	rmCreateTrigger("AT1_STOP_Station1_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station2_Plr"+k);
	if (cNumberNonGaiaPlayers >= 3)

		rmCreateTrigger("AT1_STOP_Station3_Plr"+k);
	if (cNumberNonGaiaPlayers >= 4)

		rmCreateTrigger("AT1_STOP_Station4_Plr"+k);
	if (cNumberNonGaiaPlayers >= 5)

		rmCreateTrigger("AT1_STOP_Station5_Plr"+k);
	if (cNumberNonGaiaPlayers >= 6)

		rmCreateTrigger("AT1_STOP_Station6_Plr"+k);
	if (cNumberNonGaiaPlayers >=7)

		rmCreateTrigger("AT1_STOP_Station7_Plr"+k);
	if (cNumberNonGaiaPlayers >=8)

		rmCreateTrigger("AT1_STOP_Station8_Plr"+k);

		rmCreateTrigger("AT_Destroy_Plr"+k);
	rmCreateTrigger("AT_Revert_Plr"+k);
	rmCreateTrigger("AT_Counter_Plr"+k);
}


for (k=1; <= cNumberNonGaiaPlayers) {

	// Station 1

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
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
	rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
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
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Unit Create from Source");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("ProtoName","zpArmoredTrainKitchenWagonEmitter");

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","false");
	if (cNumberNonGaiaPlayers <=3){
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");
	}
	else{
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParam("ShowUnit","true");
	}
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
	rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
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
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	if (cNumberNonGaiaPlayers >= 3){

		// Station 3

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station3_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		if (cNumberNonGaiaPlayers <=4){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else{
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
			rmSetTriggerEffectParam("ShowUnit","true");
		}

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
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station3_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
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
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID3);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	}

	if (cNumberNonGaiaPlayers >= 4){

		// Station 4

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station4_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		if (cNumberNonGaiaPlayers <=7){
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",3);
			rmSetTriggerEffectParam("ShowUnit","true");
		}
		else{
			rmAddTriggerEffect("Trade Route Toggle State");
			rmSetTriggerEffectParamInt("TradeRoute",2);
			rmSetTriggerEffectParam("ShowUnit","true");
		}

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station4_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station4_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station4_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station4_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID4);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
		
	}

	if (cNumberNonGaiaPlayers >= 5){
		
		// Station 5

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station5_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station5_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station5_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	}

	if (cNumberNonGaiaPlayers >= 6){

		// Station 6

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station6_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station6_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station6_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

		}

		if (cNumberNonGaiaPlayers >= 7){

		// Station 7

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);

		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");

		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station7_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station7_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station7_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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

	}

	if (cNumberNonGaiaPlayers >= 8){

		// Station 8

		rmSwitchToTrigger(rmTriggerID("AT1_Send_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
		rmSetTriggerConditionParamInt("Dist",40);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParam("ShowUnit","false");
		rmAddTriggerEffect("Trade Route Toggle State");
		rmSetTriggerEffectParamInt("TradeRoute",3);
		rmSetTriggerEffectParam("ShowUnit","true");
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain");
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
		rmSetTriggerEffectParamInt("Value",1);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station8_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("FakeCounter Set Text");
		rmSetTriggerEffectParam("Text", "Armored Train \" + kbGetPlayerName(" + k + ") + \": On the way"); // Get exact player name
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_Break_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station8_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station8_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		
		rmAddTriggerEffect("ZP Armored Train Stop");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",100);

		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
		rmSetTriggerEffectParamInt("Start",armoredTrainActive);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParam("Msg", "Armored Train \" + kbGetPlayerName(" + k + ") + \""); // Get exact player name
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
	}


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


for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Unlock_Plr"+k);
	rmCreateTrigger("AT_Lock_Plr"+k);
	rmCreateTrigger("AT_NoResource_Plr"+k);
	rmCreateTrigger("AT_Resource_Plr"+k);

}

for (k=1; <= cNumberNonGaiaPlayers) {
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
	
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

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
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
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

// CONVERT STATIONS	

	// Station 1

for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Station1_on_Plr"+k);
	rmCreateTrigger("Station1_off_Plr"+k);

	rmSwitchToTrigger(rmTriggerID("Station1_on_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);

	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station1_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station1_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",35);

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
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station2_off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Station2_off_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitID2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	
	rmAddTriggerEffect("ZP Convert Station Grouping");
	rmSetTriggerEffectParam("SrcObject",unitID2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParamInt("Dist",35);

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station2_on_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	if (cNumberNonGaiaPlayers >= 3){

		// Station 3

		rmCreateTrigger("Station3_on_Plr"+k);
		rmCreateTrigger("Station3_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station3_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station3_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station3_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	}

	if (cNumberNonGaiaPlayers >= 4){

		// Station 4

		rmCreateTrigger("Station4_on_Plr"+k);
		rmCreateTrigger("Station4_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station4_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station4_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station4_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station4_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	}

	if (cNumberNonGaiaPlayers >= 5){

		// Station 5

		rmCreateTrigger("Station5_on_Plr"+k);
		rmCreateTrigger("Station5_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station5_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station5_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station5_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID5);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID5);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station5_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers >= 6){

		// Station 6

		rmCreateTrigger("Station6_on_Plr"+k);
		rmCreateTrigger("Station6_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station6_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station6_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station6_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID6);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID6);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station6_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers >=7){

		// Station 7

		rmCreateTrigger("Station7_on_Plr"+k);
		rmCreateTrigger("Station7_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station7_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station7_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station7_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID7);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		
		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID7);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station7_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers >=8){

		// Station 8

		rmCreateTrigger("Station8_on_Plr"+k);
		rmCreateTrigger("Station8_off_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Station8_on_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station8_off_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Station8_off_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",unitID8);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",15);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);

		rmAddTriggerEffect("ZP Convert Station Grouping");
		rmSetTriggerEffectParam("SrcObject",unitID8);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParamInt("Dist",35);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station8_on_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

}

for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain1ONPlr"+k);
	rmCreateTrigger("BlackbTrain1OFFPlr"+k);

	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain2ONPlr"+k);
	rmCreateTrigger("BlackbTrain2OFFPlr"+k);


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

	rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
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
	rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
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

}

// Renegades Control

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

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc00);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc00);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc00);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
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
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc01);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",unitIDsc01);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",unitIDsc01);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

}

// AI Renegade Leaders

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
		rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistGortz"); //operator
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

rmSetStatusText("",0.99);
}

