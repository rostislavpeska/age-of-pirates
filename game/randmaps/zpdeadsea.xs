// DEAD SEA
// April 2023
// Main entry point for random map script I MADE A CHANGE
//

// Modified November 16, 2005 ---> KSW
// Iroquois references changed to Huron
// Lakota references changed to Cheyenne

// Nov 06 - YP update
// April 2021 edited by vividlyplain for DE

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

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
		subCiv0=rmGetCivID("maltese");
      rmEchoInfo("subCiv0 is maltese "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "maltese");

      subCiv1=rmGetCivID("jewish");
      rmEchoInfo("subCiv1 is jewish "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "jewish");
  
		subCiv2=rmGetCivID("spcsufi");
		rmEchoInfo("subCiv2 is spcsufi "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "spcsufi");
	}

    // Picks the map size
	int playerTiles = 18000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 15000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 11000;			

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(6.0);
   
   // LIGHT SET

	rmSetLightingSet("Fertile_Crescent_Skirmish");


	// Picks default terrain and water

		rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
		rmSetSeaType("great lakes2");
		rmEnableLocalWater(false);
		rmSetBaseTerrainMix("africa desert rock");
		rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
		rmSetMapType("arabia");
	   rmSetMapType("desert");
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

   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	


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

	// Nature avoidance
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineSalt", 20.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);

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

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 5.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 16.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 5.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "zpSocketSPCSufi", 40.0);
	int avoidMaltese=rmCreateTypeDistanceConstraint("stay away from Maltese", "zpSocketMaltese", 40.0);
	int avoidJewish=rmCreateTypeDistanceConstraint("stay away from Jewish", "zpSocketJewish", 40.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);

   // KOTH
   int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

   // Text
	rmSetStatusText("",0.10);

   // -------------Define objects
   // These objects are all defined so they can be placed later


	int bisonID=rmCreateObjectDef("bison herd center");
	rmAddObjectDefItem(bisonID, "bison", rmRandInt(10,12), 6.0);
	rmSetObjectDefCreateHerd(bisonID, true);
	rmSetObjectDefMinDistance(bisonID, 0.0);
	rmSetObjectDefMaxDistance(bisonID, 5.0);
	// rmAddObjectDefConstraint(bisonID, playerConstraint);
	// rmAddObjectDefConstraint(bisonID, bisonEdgeConstraint);
	// rmAddObjectDefConstraint(bisonID, avoidResource);
	// rmAddObjectDefConstraint(bisonID, avoidImpassableLand);
	// rmAddObjectDefConstraint(bisonID, Northward);


	// wood resources
	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "TreeGreatLakes", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidResource);
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);

	// -------------Done defining objects


	   // *********************************** PLACE PLAYERS ************************************
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	if ( cNumberTeams <= 2 && teamZeroCount <= 4 && teamOneCount <= 4)
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.7, 0.9); // 0.5
		rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.37, 0.37, 0);
			
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.2, 0.4); // 0.5
		rmSetTeamSpacingModifier(0.25);
		rmPlacePlayersCircular(0.37, 0.37, 0);
	}
	else
	{
		rmSetTeamSpacingModifier(0.7);
		rmPlacePlayersCircular(0.37, 0.37, 0.0);
	}

	 // Insert Players
 
   int TCfloat = -1;
	   TCfloat = 0;

int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));

int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else{
		rmAddObjectDefItem(TCID, "zpSPCWaterSpawnPoint", 1, 0.0);
   }


rmSetObjectDefMinDistance(TCID, 0.0);
rmSetObjectDefMaxDistance(TCID, TCfloat);


   /*rmAddObjectDefConstraint(TCID, avoidTradeRouteFar);
	rmAddObjectDefConstraint(TCID, avoidTownCenter);
    rmAddObjectDefConstraint(TCID, avoidSocket2);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, mediumShortAvoidImpassableLand);*/


    

  

for(i=1; <cNumberPlayers) {

    

// Place town centers
   rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
   
   if (rmGetNomadStart()){}
	else{
		int playerFortID = -1;
      playerFortID = rmCreateGrouping("player fort", "Arabia_Player_Fort");      
      rmPlaceGroupingAtLoc(playerFortID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)), 1);
   }


   


}

// Text
	rmSetStatusText("",0.20);

	// ************************ PLACE TERRAIN *******************************

   // Dead Sea Valley
    int DeadSeaValleyID = rmCreateArea ("dead sea valley");
    rmSetAreaSize(DeadSeaValleyID, 0.45, 0.45);
    rmSetAreaLocation(DeadSeaValleyID, 0.5, 0.5);
    rmSetAreaCoherence(DeadSeaValleyID, 0.9);
    rmSetAreaMinBlobs(DeadSeaValleyID, 8);
    rmSetAreaMaxBlobs(DeadSeaValleyID, 12);
    rmSetAreaMinBlobDistance(DeadSeaValleyID, 8.0);
    rmSetAreaMaxBlobDistance(DeadSeaValleyID, 10.0);
    rmSetAreaSmoothDistance(DeadSeaValleyID, 15);
    rmSetAreaCliffType(DeadSeaValleyID, "Africa Desert");
    rmSetAreaCliffEdge(DeadSeaValleyID, 1, 1.0, 0.0, 0.5, 0);
    rmSetAreaCliffHeight(DeadSeaValleyID, -0.1, 0.0, 0.5);
    rmSetAreaBaseHeight(DeadSeaValleyID, 0.0);
    rmSetAreaElevationType(DeadSeaValleyID, cElevTurbulence);
    rmSetAreaElevationVariation(DeadSeaValleyID, 2.0);
    rmSetAreaElevationPersistence(DeadSeaValleyID, 0.2);
    rmSetAreaElevationNoiseBias(DeadSeaValleyID, 1);
    rmBuildArea(DeadSeaValleyID);

	int DeadSeaValleyMixID = rmCreateArea ("dead sea valley mix");
    rmSetAreaSize(DeadSeaValleyMixID, 0.5, 0.5);
    rmSetAreaLocation(DeadSeaValleyMixID, 0.5, 0.5);
    rmSetAreaCoherence(DeadSeaValleyMixID, 0.9);
    rmSetAreaMix(DeadSeaValleyMixID, "Africa desert rock");
		rmAddAreaTerrainLayer(DeadSeaValleyMixID, "AfricaDesert\ground_dirt2_afriDesert", 0, 4);
		rmAddAreaTerrainLayer(DeadSeaValleyMixID, "AfricaDesert\ground_dirt2_afriDesert", 4, 6);
		rmAddAreaTerrainLayer(DeadSeaValleyMixID, "AfricaDesert\ground_dirt2_afriDesert", 6, 9);
		rmAddAreaTerrainLayer(DeadSeaValleyMixID, "AfricaDesert\ground_dirt2_afriDesert", 9, 12);
    rmBuildArea(DeadSeaValleyMixID);

   int deadSeaLakeID=rmCreateArea("Dead Sea Lake Shallow");
	rmSetAreaWaterType(deadSeaLakeID, "ZP Dead Sea Shallow");
	rmSetAreaSize(deadSeaLakeID, 0.23, 0.23);
	rmSetAreaCoherence(deadSeaLakeID, 0.8);
	rmSetAreaLocation(deadSeaLakeID, 0.5, 0.5);
	rmAddAreaToClass(deadSeaLakeID, classGreatLake);
	rmSetAreaBaseHeight(deadSeaLakeID, 0.0);
	rmSetAreaObeyWorldCircleConstraint(deadSeaLakeID, false);
	rmSetAreaSmoothDistance(deadSeaLakeID, 10);
	rmBuildArea(deadSeaLakeID); 

   int deadSeaLakeDeepID=rmCreateArea("Dead Sea Lake Deep");
	rmSetAreaWaterType(deadSeaLakeDeepID, "ZP Dead Sea");
	rmSetAreaSize(deadSeaLakeDeepID, 0.08, 0.08);
	rmSetAreaCoherence(deadSeaLakeDeepID, 0.9);
	rmSetAreaLocation(deadSeaLakeDeepID, 0.5, 0.5);
	rmAddAreaToClass(deadSeaLakeDeepID, classGreatLake);
	rmSetAreaBaseHeight(deadSeaLakeDeepID, 0.0);
	rmSetAreaObeyWorldCircleConstraint(deadSeaLakeDeepID, false);
	rmSetAreaSmoothDistance(deadSeaLakeDeepID, 10);
	rmBuildArea(deadSeaLakeDeepID); 
	rmAddAreaToClass(deadSeaLakeDeepID, classDeepWater);


	//King's "Island"
	if (rmGetIsKOTH() == true) {
		int kingislandID=rmCreateArea("King's Island");
		rmSetAreaSize(kingislandID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));
         rmSetAreaLocation(kingislandID, 0.5, 0.5);
		rmSetAreaMix(kingislandID, "africa desert dirt");
		rmSetAreaReveal(kingislandID, 01);
		rmSetAreaBaseHeight(kingislandID, 0.0);
		rmSetAreaCoherence(kingislandID, 1.0);
		rmBuildArea(kingislandID); 
         ypKingsHillPlacer(0.5, 0.5, 0, 0);

		}

	// add island constraints
   int deepWaterConstraint=rmCreateAreaConstraint("is in deep water", deadSeaLakeDeepID);

   float playerFraction=rmAreaTilesToFraction(850);

	for(i=1; <cNumberPlayers)
   {
      // Create the area.
      int id=rmCreateArea("Player"+i);
      // Assign to the player.
      rmSetPlayerArea(i, id);
      // Set the size.
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
	  rmSetAreaBaseHeight(id, 2.0);
	  rmSetAreaMix(id, "Africa desert rock");
		rmAddAreaTerrainLayer(id, "AfricaDesert\ground_dirt2_afriDesert", 0, 4);
		rmAddAreaTerrainLayer(id, "city\ground1_beach_street_90_ground", 4, 6);
		rmAddAreaTerrainLayer(id, "city\ground1_beach_street_90_ground", 6, 9);
		rmAddAreaTerrainLayer(id, "city\ground1_beach_street_90_ground", 9, 15);
	  rmSetAreaCoherence(id, 1.00);
	  rmSetAreaSmoothDistance(id, 20);
//		rmAddAreaConstraint(id, avoidWater);
		rmSetAreaLocPlayer(id, i);
		rmSetAreaWarnFailure(id, false);
		rmBuildArea(id); 
   }

    // Trade Routes
    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(tradeRouteID);

    rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.65);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.7);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.45);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.35);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.3);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.35);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.55);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.65);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "river_trail");

   int LakePort1ID = -1;
   LakePort1ID = rmCreateGrouping("harbour 1", "Harbour_DeadSea02");
   rmPlaceGroupingAtLoc(LakePort1ID, 0, 0.55, 0.3-rmZTilesToFraction(4.5), 1);

   int LakePort2ID = -1;
   LakePort2ID = rmCreateGrouping("harbour 2", "Harbour_DeadSea03");
   rmPlaceGroupingAtLoc(LakePort2ID, 0, 0.45, 0.7+rmZTilesToFraction(7.0), 1);

   int LakePort3ID = -1;
   LakePort3ID = rmCreateGrouping("harbour 3", "Harbour_DeadSea01");
   rmPlaceGroupingAtLoc(LakePort3ID, 0, 0.3-rmZTilesToFraction(4.5), 0.55, 1);

   int LakePort4ID = -1;
   LakePort4ID = rmCreateGrouping("harbour 4", "Harbour_DeadSea04");
   rmPlaceGroupingAtLoc(LakePort4ID, 0, 0.7+rmZTilesToFraction(7.0), 0.45, 1);


   int waterSpawnFlagID = rmCreateObjectDef("water spawn flag");
	rmAddObjectDefItem(waterSpawnFlagID, "HomeCityWaterSpawnFlag", 1, 0);
	//rmSetObjectDefMinDistance(waterSpawnFlagID, 0.3);
	//rmSetObjectDefMaxDistance(waterSpawnFlagID, 0.4);
	//rmAddObjectDefConstraint(waterSpawnFlagID, avoidKOTH);
	//rmAddObjectDefConstraint(waterSpawnFlagID, deepWaterConstraint);

for(i=1; <cNumberPlayers) {

	rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

	int mapX = 300;
	int mapZ = 300;
	int centerX = mapX / 2;
	int centerZ = mapZ / 2;
	int playerX = rmPlayerLocXFraction(i) * mapX;
	int playerZ = rmPlayerLocZFraction(i) * mapZ;

	vector centerPos = xsVectorSet(centerX, 0, centerZ);
	vector playerPos = xsVectorSet(playerX, 0, playerZ);
	vector playerToCenter = xsVectorNormalize(centerPos - playerPos);
	int distance = 80; // 10 meters. Increase until everything works.
	vector flagPos = playerPos + playerToCenter * distance;
	float flagX = xsVectorGetX(flagPos);
	float flagZ = xsVectorGetZ(flagPos);

	// Convert meters to fraction:
	flagX = flagX / mapX;
	flagZ = flagZ / mapZ;

	rmPlaceObjectDefAtLoc(waterSpawnFlagID, i, flagX, flagZ);

	//rmPlaceObjectDefAtLoc(waterSpawnFlagID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
}

   
// Text
	rmSetStatusText("",0.30);

  

// ************************************* Place Natives **************************************

int villageCircle = rmRandInt(1,3);

// Mosques

int sufi1VillageTypeID = rmRandInt(1,3);
int mosque1ID = -1;
   mosque1ID = rmCreateGrouping("mosque 1", "SufiBlueMosque_0"+sufi1VillageTypeID);
   rmSetGroupingMinDistance(mosque1ID, 0);
   rmSetGroupingMaxDistance(mosque1ID, 10);
   rmSetGroupingMinDistance(mosque1ID, 0);
   rmSetGroupingMaxDistance(mosque1ID, 60);
   rmAddGroupingConstraint(mosque1ID, avoidImpassableLand);
   rmAddGroupingConstraint(mosque1ID, avoidTownCenterFar);
   rmAddGroupingConstraint(mosque1ID, circleConstraint);


int sufi2VillageTypeID = rmRandInt(1,3);
int mosque2ID = -1;
   mosque2ID = rmCreateGrouping("mosque 2", "SufiBlueMosque_0"+sufi2VillageTypeID);
   rmSetGroupingMinDistance(mosque2ID, 0);
   rmSetGroupingMaxDistance(mosque2ID, 10);
   rmSetGroupingMinDistance(mosque2ID, 0);
   rmSetGroupingMaxDistance(mosque2ID, 60);
   rmAddGroupingConstraint(mosque2ID, avoidImpassableLand);
   rmAddGroupingConstraint(mosque2ID, avoidTownCenterFar);
   rmAddGroupingConstraint(mosque2ID, circleConstraint);


int sufi3VillageTypeID = rmRandInt(1,3);
	int mosque3ID = -1;
	mosque3ID = rmCreateGrouping("Sufi Village 3", "SufiBlueMosque_0"+sufi3VillageTypeID);
	rmSetGroupingMinDistance(mosque3ID, 0);
	rmSetGroupingMaxDistance(mosque3ID, 10);
	rmSetGroupingMinDistance(mosque3ID, 0);
	rmSetGroupingMaxDistance(mosque3ID, 60);
	rmAddGroupingConstraint(mosque3ID, avoidImpassableLand);
	rmAddGroupingConstraint(mosque3ID, avoidTownCenterFar);
	rmAddGroupingConstraint(mosque3ID, circleConstraint);


// Jewish

int jewish1VillageTypeID = rmRandInt(1, 3);
int jewish2VillageTypeID = rmRandInt(1, 3);
int jewish3VillageTypeID = rmRandInt(1, 3);

int jewish1ID = rmCreateGrouping("jewish 1", "Jewish_Settlement_0"+jewish1VillageTypeID);
int jewish2ID = rmCreateGrouping("jewish 2", "Jewish_Settlement_0"+jewish2VillageTypeID);
int jewish3ID = rmCreateGrouping("jewish 3", "Jewish_Settlement_0"+jewish3VillageTypeID);

	rmSetGroupingMinDistance(jewish1ID, 0);
	rmSetGroupingMaxDistance(jewish1ID, 60);
	rmSetGroupingMinDistance(jewish2ID, 0);
	rmSetGroupingMaxDistance(jewish2ID, 60);
	rmSetGroupingMinDistance(jewish3ID, 0);
	rmSetGroupingMaxDistance(jewish3ID, 60);

	rmAddGroupingConstraint(jewish1ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish1ID, avoidWater20);
	rmAddGroupingConstraint(jewish1ID, avoidSufi);
	rmAddGroupingConstraint(jewish1ID, avoidMaltese);
	rmAddGroupingConstraint(jewish1ID, avoidJewish);
	rmAddGroupingConstraint(jewish1ID, avoidTownCenterFar);
	rmAddGroupingConstraint(jewish2ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish1ID, circleConstraint);
	rmAddGroupingConstraint(jewish2ID, avoidWater20);
	rmAddGroupingConstraint(jewish2ID, avoidSufi);
	rmAddGroupingConstraint(jewish2ID, avoidMaltese);
	rmAddGroupingConstraint(jewish2ID, avoidJewish);
	rmAddGroupingConstraint(jewish2ID, avoidTownCenterFar);
	rmAddGroupingConstraint(jewish3ID, avoidImpassableLand);
	rmAddGroupingConstraint(jewish2ID, circleConstraint);
	rmAddGroupingConstraint(jewish3ID, avoidWater20);
	rmAddGroupingConstraint(jewish3ID, avoidSufi);
	rmAddGroupingConstraint(jewish3ID, avoidMaltese);
	rmAddGroupingConstraint(jewish3ID, avoidJewish);
	rmAddGroupingConstraint(jewish3ID, avoidTownCenterFar);
	rmAddGroupingConstraint(jewish3ID, circleConstraint);

// Maltese

int maltese1VillageTypeID = rmRandInt(1,3);
int maltese1ID = -1;
   maltese1ID = rmCreateGrouping("maltese 1", "Maltese_village_ME0"+maltese1VillageTypeID);
   rmSetGroupingMinDistance(maltese1ID, 0);
   rmSetGroupingMaxDistance(maltese1ID, 60);
   rmAddGroupingConstraint(maltese1ID, avoidImpassableLand);
   rmAddGroupingConstraint(maltese1ID, avoidWater20);
   rmAddGroupingConstraint(maltese1ID, avoidSufi);
   rmAddGroupingConstraint(maltese1ID, avoidMaltese);
   rmAddGroupingConstraint(maltese1ID, avoidJewish);
   rmAddGroupingConstraint(maltese1ID, avoidTownCenterFar);
   rmAddGroupingConstraint(maltese1ID, circleConstraint);   

int maltese2VillageTypeID = rmRandInt(1,3);
int maltese2ID = -1;
   maltese2ID = rmCreateGrouping("maltese 2", "Maltese_village_ME0"+maltese2VillageTypeID);
   rmSetGroupingMinDistance(maltese2ID, 0);
   rmSetGroupingMaxDistance(maltese2ID, 60);
   rmAddGroupingConstraint(maltese2ID, avoidImpassableLand);
   rmAddGroupingConstraint(maltese2ID, avoidWater20);
   rmAddGroupingConstraint(maltese2ID, avoidSufi);
   rmAddGroupingConstraint(maltese2ID, avoidMaltese);
   rmAddGroupingConstraint(maltese2ID, avoidJewish);
   rmAddGroupingConstraint(maltese2ID, avoidTownCenterFar);
   rmAddGroupingConstraint(maltese2ID, circleConstraint);   

int maltese3VillageTypeID = rmRandInt(1,3);
int maltese3ID = -1;
   maltese3ID = rmCreateGrouping("maltese 3", "Maltese_village_ME0"+maltese3VillageTypeID);
   rmSetGroupingMinDistance(maltese3ID, 0);
   rmSetGroupingMaxDistance(maltese3ID, 60);
   rmAddGroupingConstraint(maltese3ID, avoidImpassableLand);
   rmAddGroupingConstraint(maltese3ID, avoidWater20);
   rmAddGroupingConstraint(maltese3ID, avoidSufi);
   rmAddGroupingConstraint(maltese3ID, avoidMaltese);
   rmAddGroupingConstraint(maltese3ID, avoidJewish);
   rmAddGroupingConstraint(maltese3ID, avoidTownCenterFar);
   rmAddGroupingConstraint(maltese3ID, circleConstraint);

// Text
	rmSetStatusText("",0.40);   

// Place Natives

if (villageCircle == 1){
	if (cNumberNonGaiaPlayers < 7){
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.45, 0.8, 1);
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.8, 0.45, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.6, 0.1, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.3, 0.3, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.1, 0.6, 1);
		}
	else {
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.9, 0.5, 1);
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.8, 0.2, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.5, 0.1, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.3, 0.1, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.1, 0.3, 1);
		rmPlaceGroupingAtLoc(mosque3ID, 0, 0.1, 0.5, 1);
		rmPlaceGroupingAtLoc(jewish3ID, 0, 0.2, 0.8, 1);
		rmPlaceGroupingAtLoc(maltese3ID, 0, 0.5, 0.9, 1);
		}
	}

if (villageCircle == 2){
	if (cNumberNonGaiaPlayers < 7){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.45, 0.8, 1);
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.8, 0.45, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.6, 0.1, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.3, 0.3, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.1, 0.6, 1);
		}
	else {
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.9, 0.5, 1);
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.8, 0.2, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.5, 0.1, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.3, 0.1, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.1, 0.3, 1);
		rmPlaceGroupingAtLoc(jewish3ID, 0, 0.1, 0.5, 1);
		rmPlaceGroupingAtLoc(maltese3ID, 0, 0.2, 0.8, 1);
		rmPlaceGroupingAtLoc(mosque3ID, 0, 0.5, 0.9, 1);
		}
	}
if (villageCircle == 3){ 
	if (cNumberNonGaiaPlayers < 7){
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.45, 0.8, 1);
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.8, 0.45, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.6, 0.1, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.3, 0.3, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.1, 0.6, 1);
		}
	else {
		rmPlaceGroupingAtLoc(maltese1ID, 0, 0.8, 0.8, 1);
		rmPlaceGroupingAtLoc(mosque1ID, 0, 0.9, 0.5, 1);
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.8, 0.2, 1);
		rmPlaceGroupingAtLoc(maltese2ID, 0, 0.5, 0.1, 1);
		rmPlaceGroupingAtLoc(mosque2ID, 0, 0.3, 0.1, 1);
		rmPlaceGroupingAtLoc(jewish2ID, 0, 0.1, 0.3, 1);
		rmPlaceGroupingAtLoc(maltese3ID, 0, 0.1, 0.5, 1);
		rmPlaceGroupingAtLoc(mosque3ID, 0, 0.2, 0.8, 1);
		rmPlaceGroupingAtLoc(jewish3ID, 0, 0.5, 0.9, 1);
		}
	}

/*if (subcivMixRandom < 0.5){
	if (cNumberNonGaiaPlayers < 6){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.65, 0.85, 1);
	}
}
else {
	if (cNumberNonGaiaPlayers < 6){
		rmPlaceGroupingAtLoc(jewish1ID, 0, 0.35, 0.75, 1);
	}
}*/


// Text
	rmSetStatusText("",0.50);



// ************************************* Mines and other Lake Objects **************************************

int saltCount = (cNumberNonGaiaPlayers*1.5);

for(i=0; < saltCount)
	{
 int  lakeSaltMineID = rmCreateObjectDef("lake mine salt "+i);
	  rmAddObjectDefItem(lakeSaltMineID, "MineSalt", 1, 0.0);
      rmSetObjectDefMinDistance(lakeSaltMineID, 0.0);
      rmSetObjectDefMaxDistance(lakeSaltMineID, rmXFractionToMeters(0.16));
	  rmAddObjectDefConstraint(lakeSaltMineID, avoidCoin);
      rmAddObjectDefConstraint(lakeSaltMineID, avoidAll);
      rmAddObjectDefConstraint(lakeSaltMineID, portOnShore);
	  rmAddObjectDefConstraint(lakeSaltMineID, avoidTradeRoute);
	  rmAddObjectDefConstraint(lakeSaltMineID, avoidSocket);
	  rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.55, 0.3);
	  rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.45, 0.7);
	  rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.3, 0.55);
	  rmPlaceObjectDefAtLoc(lakeSaltMineID, 0, 0.7, 0.45);
	}


int saltCrater1ID = -1;
   saltCrater1ID = rmCreateGrouping("salt crater1", "DeadSeaSaltCrater");

   rmAddGroupingConstraint(saltCrater1ID, shortAvoidTradeRoute);
   rmAddGroupingConstraint(saltCrater1ID, portOnShore);
   rmSetGroupingMinDistance(saltCrater1ID, 5);
   rmSetGroupingMaxDistance(saltCrater1ID, 50);

   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.7, 0.4, cNumberNonGaiaPlayers);
   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.4, 0.7, cNumberNonGaiaPlayers);
   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.6, 0.3, cNumberNonGaiaPlayers);
   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.3, 0.6, cNumberNonGaiaPlayers);
   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.65, 0.65, cNumberNonGaiaPlayers);
   rmPlaceGroupingAtLoc(saltCrater1ID, 0, 0.35, 0.35, cNumberNonGaiaPlayers);
   
   
   for(i=0; < saltCount*6)
	{
 	int  lakeSaltPropID = rmCreateObjectDef("lake mine salt "+i);
	  rmAddObjectDefItem(lakeSaltPropID, "RiverPropsYuk", 1, 0.0);
      rmSetObjectDefMinDistance(lakeSaltPropID, 0.0);
      rmSetObjectDefMaxDistance(lakeSaltPropID, rmXFractionToMeters(0.16));
      rmAddObjectDefConstraint(lakeSaltPropID, portOnShore);
	  rmAddObjectDefConstraint(lakeSaltPropID, avoidDeepWater);
	  rmAddObjectDefConstraint(lakeSaltPropID, shortAvoidTradeRoute);
	  rmAddObjectDefConstraint(lakeSaltPropID, avoidSocket);
	  rmPlaceObjectDefAtLoc(lakeSaltPropID, 0, 0.55, 0.3);
	  rmPlaceObjectDefAtLoc(lakeSaltPropID, 0, 0.45, 0.7);
	  rmPlaceObjectDefAtLoc(lakeSaltPropID, 0, 0.3, 0.55);
	  rmPlaceObjectDefAtLoc(lakeSaltPropID, 0, 0.7, 0.45);
	  }

	int whaleCount = (cNumberNonGaiaPlayers);

	  for(i=0; < whaleCount)
	{

 	int  waterMineID = rmCreateObjectDef("water mine salt "+i);
	  rmAddObjectDefItem(waterMineID, "zpSaltMineWater", 1, 0.0);
      rmSetObjectDefMinDistance(waterMineID, 0.0);
      rmSetObjectDefMaxDistance(waterMineID, rmXFractionToMeters(0.16));
      rmAddObjectDefConstraint(waterMineID, deepWaterConstraint);
	  rmAddObjectDefConstraint(waterMineID, flagVsFlag);
	  rmAddObjectDefConstraint(waterMineID, saltVsSalt);
	  rmPlaceObjectDefAtLoc(waterMineID, 0, 0.5, 0.5);

	  }

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;
	
	numTries=20+7*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 below
	failCount=0;
	for (i=0; <numTries)
		{   
			int northForest=rmCreateArea("northforest"+i);
			rmSetAreaWarnFailure(northForest, false);
			rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

			rmSetAreaForestType(northForest, "z45 arabian desert");
			rmSetAreaForestDensity(northForest, 1.0);
			rmAddAreaToClass(northForest, rmClassID("classForest"));
			rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
			rmSetAreaForestUnderbrush(northForest, 0.0);
			rmSetAreaCoherence(northForest, 0.4);
			rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
			rmAddAreaConstraint(northForest, shortAvoidCoin);
			rmAddAreaConstraint(northForest, avoidTownCenterFar);
			rmAddAreaConstraint(northForest, avoidJewish);
			rmAddAreaConstraint(northForest, avoidMaltese);
			rmAddAreaConstraint(northForest, avoidSufi);
			rmAddAreaConstraint(northForest, avoidTradeRoute);
			rmAddAreaConstraint(northForest, avoidWater20);
			rmAddAreaConstraint(northForest, avoidKOTH);
			rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
			rmAddAreaConstraint(northForest, Northward);				// DAL adeed, to keep forests in the north.
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

	// Text
	rmSetStatusText("",0.60);

	
	numTries=5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i = 0; i < numTries; i++)
		{   
			int southForest = rmCreateArea("southForest" + i);
			rmSetAreaWarnFailure(southForest, false);
			rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
			rmSetAreaForestType(southForest, "z45 arabian desert");
			rmSetAreaForestDensity(southForest, 1.0);
			rmAddAreaToClass(southForest, rmClassID("classForest"));
			rmSetAreaForestClumpiness(southForest, 0.0);
			rmSetAreaForestUnderbrush(southForest, 0.0);
			rmSetAreaCoherence(southForest, 0.4);
			rmAddAreaConstraint(southForest, avoidImportantItem);
			rmAddAreaConstraint(southForest, shortAvoidCoin);
			rmAddAreaConstraint(southForest, avoidTownCenterFar);
			rmAddAreaConstraint(southForest, avoidJewish);
			rmAddAreaConstraint(southForest, avoidMaltese);
			rmAddAreaConstraint(southForest, avoidSufi);
			rmAddAreaConstraint(southForest, avoidTradeRoute);
			rmAddAreaConstraint(southForest, avoidWater20);
			rmAddAreaConstraint(southForest, avoidKOTH);
			rmAddAreaConstraint(southForest, forestConstraint);
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
   
// Place some extra deer herds.  
	int deerHerdID=rmCreateObjectDef("northern deer herd");
	rmAddObjectDefItem(deerHerdID, "ypIbex", rmRandInt(8,8), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID, true);
	rmSetObjectDefMinDistance(deerHerdID, rmXFractionToMeters(0.10));
	rmSetObjectDefMaxDistance(deerHerdID, rmXFractionToMeters(0.50));
	rmAddObjectDefConstraint(deerHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID, avoidAll);
	rmAddObjectDefConstraint(deerHerdID, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID, Northward);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID, 0, 0.5, 0.5);
	}
	// Text
	rmSetStatusText("",0.70);

	int deerHerdID2=rmCreateObjectDef("southern deer herd");
	rmAddObjectDefItem(deerHerdID2, "ypIbex", rmRandInt(8,8), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID2, true);
	rmSetObjectDefMinDistance(deerHerdID2, rmXFractionToMeters(0.10));
	rmSetObjectDefMaxDistance(deerHerdID2, rmXFractionToMeters(0.50));
	rmAddObjectDefConstraint(deerHerdID2, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID2, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID2, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID2, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID2, avoidAll);
	rmAddObjectDefConstraint(deerHerdID2, avoidKOTH);
	rmAddObjectDefConstraint(deerHerdID2, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID2, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID2, Southward);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}
	// Text
	


// Place some extra deer herds.  
	int mooseHerdID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseHerdID, "moose", rmRandInt(3,3), 6.0);
	rmSetObjectDefCreateHerd(mooseHerdID, true);
	rmSetObjectDefMinDistance(mooseHerdID, 0.0);
	rmSetObjectDefMaxDistance(mooseHerdID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(mooseHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(mooseHerdID, avoidAll);
	rmAddObjectDefConstraint(mooseHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(mooseHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(mooseHerdID, avoidKOTH);
	rmAddObjectDefConstraint(mooseHerdID, mooseConstraint);
	rmAddObjectDefConstraint(mooseHerdID, shortDeerConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(mooseHerdID, 0, 0.5, 0.5);
	}
	// Text
	rmSetStatusText("",0.80);

	// Define and place Nuggets
    
		int nugget4= rmCreateObjectDef("nugget nuts"); 
		rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(4, 4);
		rmAddObjectDefToClass(nugget4, rmClassID("nuggets"));
		rmSetObjectDefMinDistance(nugget4, rmXFractionToMeters(0.05));
		rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.30));
		rmAddObjectDefConstraint(nugget4, longPlayerConstraint);
		rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget4, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget4, avoidNuggets);
		rmAddObjectDefConstraint(nugget4, avoidTradeRoute);
		rmAddObjectDefConstraint(nugget4, circleConstraint);
		rmAddObjectDefConstraint(nugget4, avoidKOTH);
		rmAddObjectDefConstraint(nugget4, avoidAll);
		rmAddObjectDefConstraint(nugget4, avoidWater20);
		//rmAddObjectDefConstraint(nugget4, longPlayerEdgeConstraint);
		if (cNumberNonGaiaPlayers > 2 && rmGetIsTreaty() == false)
			rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

		int nugget3= rmCreateObjectDef("nugget hard"); 
		rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(3, 3);
		rmAddObjectDefToClass(nugget3, rmClassID("nuggets"));
		rmSetObjectDefMinDistance(nugget3, rmXFractionToMeters(0.05));
		rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.35));
		rmAddObjectDefConstraint(nugget3, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget3, avoidNuggets);
		rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
		rmAddObjectDefConstraint(nugget3, circleConstraint);
		rmAddObjectDefConstraint(nugget3, avoidKOTH);
		rmAddObjectDefConstraint(nugget3, avoidAll);
		rmAddObjectDefConstraint(nugget4, avoidWater20);
		rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

		int nugget2= rmCreateObjectDef("nugget medium"); 
		rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(2, 2);
		rmAddObjectDefToClass(nugget2, rmClassID("nuggets"));
		rmSetObjectDefMinDistance(nugget2, 0.0);
		rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(nugget2, shortPlayerConstraint);
		rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget2, avoidNuggets);
		rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
		rmAddObjectDefConstraint(nugget2, avoidKOTH);
		rmAddObjectDefConstraint(nugget2, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget2, circleConstraint);
		rmAddObjectDefConstraint(nugget2, avoidAll);
		rmAddObjectDefConstraint(nugget2,avoidWater20);
		rmSetObjectDefMinDistance(nugget2, 80.0);
		rmSetObjectDefMaxDistance(nugget2, 120.0);
		rmPlaceObjectDefAtLoc(nugget2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

		int nugget1= rmCreateObjectDef("nugget easy"); 
		rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(1, 1);
		rmAddObjectDefToClass(nugget1, rmClassID("nuggets"));
		rmAddObjectDefConstraint(nugget1, shortPlayerConstraint);
		rmAddObjectDefConstraint(nugget1, avoidTownCenter);
		rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget1, avoidNuggets);
		rmAddObjectDefConstraint(nugget1, avoidTradeSockets);
		rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
		rmAddObjectDefConstraint(nugget1, avoidAll);
		rmAddObjectDefConstraint(nugget1, avoidKOTH);
		rmAddObjectDefConstraint(nugget1, circleConstraint);
		rmSetObjectDefMinDistance(nugget1, 0.0);
		rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.49));
		rmPlaceObjectDefAtLoc(nugget1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*4);

		// Define and place decorations: rocks and grass and stuff 

		int rockID=rmCreateObjectDef("lone rock");
		int avoidRock=rmCreateTypeDistanceConstraint("avoid rock", "deUnderbrushSmallRocksAfrica", 8.0);
		rmAddObjectDefItem(rockID, "deUnderbrushSmallRocksAfrica", 1, 0.0);
		rmSetObjectDefMinDistance(rockID, 0.0);
		rmSetObjectDefMaxDistance(rockID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(rockID, avoidAll);
		rmAddObjectDefConstraint(rockID, avoidWater20);
		rmAddObjectDefConstraint(rockID, avoidImpassableLand);
		rmAddObjectDefConstraint(rockID, avoidKOTH);
		rmAddObjectDefConstraint(rockID, avoidTownCenter);
		rmAddObjectDefConstraint(rockID, avoidRock);
		rmPlaceObjectDefAtLoc(rockID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);


 // Text
	rmSetStatusText("",0.90);

//******************************* TRIGGERS ****************************************


int tch0=1671; // tech operator

// Starting techs

rmCreateTrigger("Starting Techs");
rmSwitchToTrigger(rmTriggerID("Starting techs"));
for(i=1; <= cNumberNonGaiaPlayers) {
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechDEEnableTradeRouteEuropeanRiver"); // DEEneableTradeRouteWater
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpIsMiddleEastMap"); // DEEneableTradeRouteWater
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpArabiaPlayerFortShadow"); // DEEneableTradeRouteWater
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
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
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(true);
}


for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Maltese"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpMalteseCross"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffMalteseLand"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(true);
}

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Jewish"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpJewishStar"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffJewish"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Jewish"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Maltese Land Fractions

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Maltese Fraction"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int malteseFraction=-1;
malteseFraction = rmRandInt(1,3);

if (malteseFraction==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseFlorentians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseFraction==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseJerusalem"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseFraction==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseCentralEuropeans"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Jewish Fractions

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Jewish Fraction"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int jewishFraction=-1;
jewishFraction = rmRandInt(1,3);

if (jewishFraction==1)
   {
	  rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishAmericans"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (jewishFraction==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishRussians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (jewishFraction==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateJewishGermans"); //operator
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