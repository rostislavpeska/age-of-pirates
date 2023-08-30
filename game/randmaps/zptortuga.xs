
// Caribean Water Trade 1.0 24 04 2020

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

   if (rmAllocateSubCivs(3) == true)
   {
		subCiv0=rmGetCivID("natpirates");
      rmEchoInfo("subCiv0 is pirates "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "natpirates");

      subCiv1=rmGetCivID("caribs");
      rmEchoInfo("subCiv1 is caribs "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "caribs");
  
		subCiv2=rmGetCivID("caribs");
		rmEchoInfo("subCiv2 is caribs "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "caribs");

      subCiv3=rmGetCivID("caribs");
		rmEchoInfo("subCiv3 is caribs "+subCiv3);
		if (subCiv3 >= 0)
				rmSetSubCiv(3, "caribs");
	}
	
   // Set size.
   int playerTiles=24000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 17000;
	if (cNumberNonGaiaPlayers >7)
		playerTiles = 19000;			
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(2.0);
   rmSetSeaType("caribbean coast");
 	rmSetBaseTerrainMix("caribbeanSkirmish");
	rmSetMapType("caribbean");
	rmSetMapType("grass");
	rmSetMapType("water");
   rmSetMapType("caribbeanwater");
   rmSetLightingSet("Caribbean_Skirmish");
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

   // Constraints to avoid water trade Route
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 20.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);

   // Player objects constraints
   int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 25.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
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
   int avoidSocketLongCarib=rmCreateTypeDistanceConstraint("avoid socket long carib", "SocketCaribs", 50.0);

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
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

   // Nature Constraints
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 35.0);
   int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishSalmon", 20.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 50.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);

   int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0); 
   int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);
   int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0); 

// Trade Route
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 1.0);
rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.7);
rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.45);
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.55);
rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);

bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

// Text
	rmSetStatusText("",0.10);


// North Island
int northIsland = rmCreateArea ("north island");
rmSetAreaSize(northIsland, 0.24, 0.24);
rmSetAreaLocation(northIsland, 1.0, 0.7);
rmSetAreaCoherence(northIsland, 0.6);
rmSetAreaMinBlobs(northIsland, 8);
rmSetAreaMaxBlobs(northIsland, 12);
rmSetAreaMinBlobDistance(northIsland, 8.0);
rmSetAreaMaxBlobDistance(northIsland, 10.0);
rmSetAreaSmoothDistance(northIsland, 15);
rmSetAreaMix(northIsland, "caribbean grass");
rmSetAreaBaseHeight(northIsland, 2.2);
rmAddAreaConstraint(northIsland, islandConstraint);
rmAddAreaConstraint(northIsland, islandAvoidTradeRoute);
rmSetAreaElevationType(northIsland, cElevTurbulence);
rmSetAreaElevationVariation(northIsland, 4.0);
rmSetAreaElevationPersistence(northIsland, 0.2);
rmSetAreaElevationNoiseBias(northIsland, 1);
rmAddAreaToClass(northIsland, classIsland);
rmAddAreaToClass(northIsland, classTeamIsland);

   // Port Sites
   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.45+rmXTilesToFraction(25), 0.7);
   rmSetAreaMix(portSite1, "caribbean grass");
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
   rmSetAreaLocation(portSite2, 0.55+rmXTilesToFraction(20),0.5);
   rmSetAreaMix(portSite2, "caribbean grass");
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
rmSetAreaSize(southIsland, 0.24, 0.24);
rmSetAreaLocation(southIsland, 0.3, 0.0);
rmSetAreaCoherence(southIsland, 0.60);
rmSetAreaMinBlobs(southIsland, 8);
rmSetAreaMaxBlobs(southIsland, 12);
rmSetAreaMinBlobDistance(southIsland, 8.0);
rmSetAreaMaxBlobDistance(southIsland, 10.0);
rmSetAreaSmoothDistance(southIsland, 15);
rmSetAreaMix(southIsland, "caribbean grass");
rmSetAreaBaseHeight(southIsland, 2.2);
rmAddAreaConstraint(southIsland, islandConstraint);
rmAddAreaConstraint(southIsland, islandAvoidTradeRoute); 
rmSetAreaElevationType(southIsland, cElevTurbulence);
rmSetAreaElevationVariation(southIsland, 4.0);
rmSetAreaElevationPersistence(southIsland, 0.2);
rmSetAreaElevationNoiseBias(southIsland, 1);
rmAddAreaToClass(southIsland, classIsland);
rmAddAreaToClass(southIsland, classTeamIsland);

   // Port Sites

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite3, 0.5, 0.45-rmZTilesToFraction(20));
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaMix(portSite3, "caribbean grass");
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
   rmSetAreaLocation(portSite4, 0.3, 0.55-rmXTilesToFraction(20));
   rmSetAreaCoherence(portSite4, 1);
   rmSetAreaMix(portSite4, "caribbean grass");
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

// Bonus Island
int bonusIslandID = rmCreateArea ("bonus island");

if (cNumberNonGaiaPlayers <= 4){
rmSetAreaSize(bonusIslandID, 0.13, 0.13);
}

else{
rmSetAreaSize(bonusIslandID, 0.115, 0.115);
}

rmSetAreaLocation(bonusIslandID, 0.1, 0.9);
rmSetAreaCoherence(bonusIslandID, 0.4);
rmSetAreaMinBlobs(bonusIslandID, 8);
rmSetAreaMaxBlobs(bonusIslandID, 12);
rmSetAreaMinBlobDistance(bonusIslandID, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandID, 10.0);
rmSetAreaSmoothDistance(bonusIslandID, 15);
rmSetAreaMix(bonusIslandID, "caribbean grass");
rmSetAreaBaseHeight(bonusIslandID, 2.2);
rmAddAreaConstraint(bonusIslandID, islandConstraint);
rmAddAreaConstraint(bonusIslandID, islandAvoidTradeRoute); 
rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandID, 4.0);
rmSetAreaElevationPersistence(bonusIslandID, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandID, 1);
rmAddAreaToClass(bonusIslandID, classIsland);
//rmAddAreaToClass(bonusIslandID,"bonusIsland");

// Text
	rmSetStatusText("",0.20);

// Area builder
rmBuildAllAreas();

// add island constraints
   int northIslandConstraint=rmCreateAreaConstraint("north Island", northIsland);
   int southIslandConstraint=rmCreateAreaConstraint("south Island", southIsland);
   int bonusIslandConstraint=rmCreateAreaConstraint("bonus Island", bonusIslandID);

// Place Pirates

   // Place Controllers
      int controllerID1 = rmCreateObjectDef("Controler 1");
      rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID1, 0.0);
	   rmSetObjectDefMaxDistance(controllerID1, 30.0);
      rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID1, ferryOnShore); 
      rmPlaceObjectDefAtLoc(controllerID1, 0, 0.15, 0.65);


      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID2, 0.0);
	   rmSetObjectDefMaxDistance(controllerID2, 30.0);
      rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(controllerID2, ferryOnShore); 
      rmPlaceObjectDefAtLoc(controllerID2, 0, 0.35, 0.85);


      vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

   // Pirate Village 1
      if (subCiv0 == rmGetCivID("natpirates"))
      {  
         int piratesVillageID = -1;
         int piratesVillageType = rmRandInt(1,2);
         piratesVillageID = rmCreateGrouping("pirate city", "pirate_village0"+piratesVillageType);

      
         rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

         int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
         rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
         rmAddClosestPointConstraint(villageEdgeConstraint);
         rmAddClosestPointConstraint(flagLand);

         vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

         rmClearClosestPointConstraints();

         int pirateportID1 = -1;
         pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport01");
         rmAddClosestPointConstraint(villageEdgeConstraint);
         rmAddClosestPointConstraint(portOnShore);

         vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
         
         rmClearClosestPointConstraints();
      
      }

      // Pirate Village 2
      if (cNumberNonGaiaPlayers >= 4){
         if (subCiv0 == rmGetCivID("natpirates"))
         {  
            int piratesVillageID2 = -1;
            int piratesVillage2Type = 3-piratesVillageType;
            piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village0"+piratesVillage2Type);


            rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);
         
            int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
            rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
            rmAddClosestPointConstraint(villageEdgeConstraint);
            rmAddClosestPointConstraint(flagLand);

            vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

            rmClearClosestPointConstraints();

            int pirateportID2 = -1;
            pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport02");
            rmAddClosestPointConstraint(villageEdgeConstraint);
            rmAddClosestPointConstraint(portOnShore);

            vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
            rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
            
            rmClearClosestPointConstraints();
         }
      }

      // Place King's Hill
   if (rmGetIsKOTH() == true) {
      ypKingsHillPlacer(0.25, 0.75, 0.05, 0);
	}


// Place ports
   // Port 1
   int portID01 = rmCreateObjectDef("port 01");
   //portID01 = rmCreateGrouping("portG 01", "C:/Users/rosti/Games/Age of Empires 3 DE/76561198347905238/mods/local/Tortuga Local/RandMaps/groupings/harbour_01");
   portID01 = rmCreateGrouping("portG 01", "harbour_01");
   rmPlaceGroupingAtLoc(portID01, 0, 0.45+rmXTilesToFraction(16), 0.7+rmZTilesToFraction(0));

   // Port 2
   int portID02 = rmCreateObjectDef("port 02");
   portID02 = rmCreateGrouping("portG 02", "harbour_02");
   rmPlaceGroupingAtLoc(portID02, 0, 0.55+rmXTilesToFraction(11), 0.5);

   // Port 3
   int portID03 = rmCreateObjectDef("port 03");
   portID03 = rmCreateGrouping("portG 03", "harbour_03");
   rmPlaceGroupingAtLoc(portID03, 0, 0.5, 0.45-rmZTilesToFraction(10));

   // Port 4
   int portID04 = rmCreateObjectDef("port 04");
   portID04 = rmCreateGrouping("portG 04", "harbour_04");
   rmPlaceGroupingAtLoc(portID04, 0, 0.3+rmZTilesToFraction(1), 0.55-rmZTilesToFraction(9.5));

// Text
	rmSetStatusText("",0.30);

// Place Caribs

   // Lonely Caribs
   if (subCiv3 == rmGetCivID("caribs"))
   {  
		int caribsVillageID = -1;
		int caribsVillageType = rmRandInt(1,5);
      caribsVillageID = rmCreateGrouping("caribs1 city", "native carib village 0"+caribsVillageType);
      rmSetGroupingMinDistance(caribsVillageID, 500);
      rmSetGroupingMaxDistance(caribsVillageID, rmXFractionToMeters(0.3));
		rmAddGroupingConstraint(caribsVillageID, avoidTeamIslands);
		rmAddGroupingConstraint(caribsVillageID, avoidImpassableLand);
      rmAddGroupingConstraint(caribsVillageID, playerEdgeConstraint);      
      rmAddGroupingConstraint(caribsVillageID, avoidSocketLong);
      rmAddClosestPointConstraint(villageEdgeConstraint);

		rmPlaceGroupingInArea(caribsVillageID, 0, bonusIslandID, 1);

   }

   // Team Caribs
   if (subCiv1 == rmGetCivID("caribs"))
   {  
      int caribs2VillageID = -1;
      int caribs2VillageType = rmRandInt(1,5);
      caribs2VillageID = rmCreateGrouping("caribs2 city", "native carib village 0"+caribs2VillageType);
      rmAddGroupingConstraint(caribs2VillageID, avoidTC);
      rmAddGroupingConstraint(caribs2VillageID, avoidCW);
      rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(caribs2VillageID, avoidSocketLong);
      rmAddClosestPointConstraint(villageEdgeConstraint);

      int caribs4VillageID = -1;
      int caribs4VillageType = rmRandInt(1,5);
      caribs4VillageID = rmCreateGrouping("caribs4 city", "native carib village 0"+caribs4VillageType);
      rmAddGroupingConstraint(caribs4VillageID, avoidTC);
      rmAddGroupingConstraint(caribs4VillageID, avoidCW);
      rmAddGroupingConstraint(caribs4VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(caribs4VillageID, avoidSocketLong);
      rmPlaceGroupingInArea(caribs4VillageID, 0, northIsland, 1);
      rmAddClosestPointConstraint(villageEdgeConstraint);

      if (cNumberNonGaiaPlayers <= 4){
      rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 1);
      }

      else {
      rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 2);
      }
   }

   
   if (subCiv2 == rmGetCivID("caribs"))
   {  
      int caribs3VillageID = -1;
      int caribs3VillageType = rmRandInt(1,5);
      caribs3VillageID = rmCreateGrouping("caribs3 city", "native carib village 0"+caribs3VillageType);
      rmAddGroupingConstraint(caribs3VillageID, avoidTC);
      rmAddGroupingConstraint(caribs3VillageID, avoidCW);
      rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(caribs3VillageID, avoidSocketLong);
      rmAddClosestPointConstraint(villageEdgeConstraint);

      int caribs5VillageID = -1;
      int caribs5VillageType = rmRandInt(1,5);
      caribs5VillageID = rmCreateGrouping("caribs5 city", "native carib village 0"+caribs5VillageType);
      rmAddGroupingConstraint(caribs5VillageID, avoidTC);
      rmAddGroupingConstraint(caribs5VillageID, avoidCW);
      rmAddGroupingConstraint(caribs5VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(caribs5VillageID, avoidSocketLong);
      rmPlaceGroupingInArea(caribs5VillageID, 0, southIsland, 1);
      rmAddClosestPointConstraint(villageEdgeConstraint);
      
      if (cNumberNonGaiaPlayers <= 4){
      rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 1);
      }

      else {
      rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 2);
      }

   } 

   rmClearClosestPointConstraints();

// Text
	rmSetStatusText("",0.40);

// Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.00, 0.73);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.4, 0.4, 0);
		}
		else
		{
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.07, 0.25);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.47, 0.65); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.07, 0.25);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.47, 0.65); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
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
   rmAddObjectDefItem(playerDeerID, "deer", rmRandInt(10,15), 10.0);
   rmSetObjectDefMinDistance(playerDeerID, 15.0);
   rmSetObjectDefMaxDistance(playerDeerID, 30.0);
   rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(playerDeerID, true);

rmAddObjectDefConstraint(TCID, avoidTownCenter);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, playersAwayPort);
rmAddObjectDefConstraint(TCID, avoidBonusIslands);
rmAddObjectDefConstraint(TCID, avoidSocketLongCarib);


  

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
   rmAddAreaConstraint(colonyShipID, ObjectAvoidTradeRoute);
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

// check for KOTH game mode
    
   if(rmGetIsKOTH()) {

   ypKingsHillPlacer(0.2, 0.8, 0, 0);

   }
   
   // MINES

   int silverType = -1;
	int silverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*0.75);
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
	  int southSilverID = rmCreateObjectDef("south silver "+i);
	  rmAddObjectDefItem(southSilverID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(southSilverID, 0.0);
      rmSetObjectDefMaxDistance(southSilverID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(southSilverID, avoidCoin);
      rmAddObjectDefConstraint(southSilverID, avoidAll);
      rmAddObjectDefConstraint(southSilverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(southSilverID, mediumAvoidImpassableLand);
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
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(silverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(silverID, northIslandConstraint);
	  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   } 
	
   for(i=0; < 4)
	{
	  silverID = rmCreateObjectDef("bonus silver "+i);
	  rmAddObjectDefItem(silverID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(silverID, avoidCoin);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(silverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(silverID, bonusIslandConstraint);
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
    rmSetAreaForestType(forest, "caribbean palm forest");
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
	rmPlaceObjectDefInArea(nuggetNorth, 0, northIsland, cNumberNonGaiaPlayers);

   int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouth, avoidAll);
	rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, southIsland, cNumberNonGaiaPlayers);


	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget2, avoidNugget);
  	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidTCshort);
  	rmAddObjectDefConstraint(nugget2, avoidWater4);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bonusIslandID, cNumberNonGaiaPlayers);

      // Water nuggets

   int nuggetCount = 1;
   
   int nuggetWater= rmCreateObjectDef("nugget water" + i); 
   rmAddObjectDefItem(nuggetWater, "ypNuggetBoat", 1, 0.0);
   rmSetNuggetDifficulty(5, 5);
   rmSetObjectDefMinDistance(nuggetWater, rmXFractionToMeters(0.0));
   rmSetObjectDefMaxDistance(nuggetWater, rmXFractionToMeters(1.0));
   rmAddObjectDefConstraint(nuggetWater, avoidLand);
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
   rmAddObjectDefConstraint(nugget2b, ObjectAvoidTradeRoute);
   rmAddObjectDefConstraint(nugget2b, avoidNuggetWater);
   rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
   rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount);

   // Text
	rmSetStatusText("",0.80);

   // DEER	
   int deerID=rmCreateObjectDef("deer herd");
	int bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(deerID, "deer", rmRandInt(4,6), 10.0);
   else
      rmAddObjectDefItem(deerID, "deer", rmRandInt(8,10), 10.0);
   rmSetObjectDefMinDistance(deerID, 0.0);
   rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
   rmAddObjectDefConstraint(deerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(deerID, true);
	rmPlaceObjectDefInArea(deerID, 0, bonusIslandID, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, northIsland, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, southIsland, cNumberNonGaiaPlayers);

   // Text
	rmSetStatusText("",0.90);

//Fishes

   int fishID=rmCreateObjectDef("fish Mahi");
   rmAddObjectDefItem(fishID, "FishMahi", 1, 0.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);

   int fish2ID=rmCreateObjectDef("fish Tarpon");
   rmAddObjectDefItem(fish2ID, "FishTarpon", 1, 0.0);
   rmSetObjectDefMinDistance(fish2ID, 0.0);
   rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fish2ID, fishVsFishID);
   rmAddObjectDefConstraint(fish2ID, fishLand);
   rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // RANDOM TREES
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "treeCaribbean", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);


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
rmCreateTrigger("Activate Tortuga"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPirates"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
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

   if (cNumberNonGaiaPlayers >= 4){
   rmCreateTrigger("TrainPrivateer2ON Plr"+k);
   rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
   rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainPrivateer2TIME_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","5");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
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
   rmSetTriggerConditionParam("DstObject","56");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","56");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   }

   // Build limit reducer
   rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
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
   rmSetTriggerConditionParam("DstObject","5");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Grace
   rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","5");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   // Caesar
   rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","5");
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
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
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
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
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
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
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

// Testing


/*
for (k=1; <= cNumberNonGaiaPlayers) {

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
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}
*/



   // Text
	rmSetStatusText("",1.0);

} 