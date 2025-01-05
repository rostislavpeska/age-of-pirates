// Caribbean Wars Historical map
// 01/2025

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

   if (rmAllocateSubCivs(3) == true)
   {
		subCiv0=rmGetCivID("natpirates");
      rmEchoInfo("subCiv0 is pirates "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "natpirates");

      subCiv1=rmGetCivID("maltese");
      rmEchoInfo("subCiv1 is maltese "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "maltese");
  
		subCiv2=rmGetCivID("caribs");
		rmEchoInfo("subCiv2 is caribs "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "caribs");

	}
	
   // Set size.


   int size = 500;
   if (cNumberNonGaiaPlayers > 2){
		size = 640;
	}
   if (cNumberNonGaiaPlayers > 4){
		size = 730;
	}
   if (cNumberNonGaiaPlayers > 6){
      size = 830;
	}

   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(2.0);
   rmSetSeaType("caribbean coast");
 	rmSetBaseTerrainMix("caribbeanSkirmish");
	rmSetMapType("caribbean");
   rmSetMapType("piratehistoricalmap");
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
   int playersAwayPort=rmCreateTypeDistanceConstraint("players not in port ", "socketTradeRoute", 30.0);
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
   int avoidPirateHouse=rmCreateTypeDistanceConstraint("avoid pirate city state", "zpNativeHousePirateCity", 15.0);
   int avoidPirateDock1=rmCreateTypeDistanceConstraint("avoid pirate dock 1", "zpSPCPirateDock", 25.0);
   int avoidPirateDock2=rmCreateTypeDistanceConstraint("avoid pirate dock 2", "zpSPCPirateDockB", 25.0);
   int avoidRevealer=rmCreateTypeDistanceConstraint("avoid city state revealer", "zpCinematicRevealer", 25.0);
   int avoidRevealerLong=rmCreateTypeDistanceConstraint("avoid city state revealer long", "zpCinematicRevealer", 40.0);
   int avoidHarbour=rmCreateTypeDistanceConstraint("avoid harbour", "zpHarbourPlatform", 20.0);
   int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "zpKingsHillNaval", 15.0);
   int avoidKOTHLong=rmCreateTypeDistanceConstraint("stay away from Kings Hill Long", "zpKingsHillNaval", 25.0);

   // ******************* Place City states terrain and Trade Routes *************************

   // Invisible Land Mass to dock Pirate City States

   int landMassID = rmCreateArea("land mass 1");
   rmSetAreaSize(landMassID , rmAreaTilesToFraction(19000), rmAreaTilesToFraction(19000));
   rmSetAreaLocation(landMassID , 0.5, 0.5);		
   rmSetAreaCoherence(landMassID , 1.0);
   rmSetAreaBaseHeight(landMassID, 5.0);
   rmSetAreaWarnFailure(landMassID, false);
   rmSetAreaElevationVariation(landMassID, 0.0);
   rmAddAreaInfluenceSegment(landMassID, 0.1, 0.9, 0.9, 0.1);
   rmBuildArea(landMassID ); 

   // Trade Routes

   int tradeRouteID = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 1.0);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.8);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.7);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.6);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.55);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.5);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

   int tradeRouteID2 = rmCreateTradeRoute();
   rmSetObjectDefTradeRouteID(tradeRouteID2);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.0);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.2);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.55, 0.3);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.4);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.7, 0.45);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.5);

   bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");

   // define fake stopper (without it the Venetian islands don't spawn)
	int fakeStopperID=rmCreateObjectDef("TradeShipStopperFake");
	rmAddObjectDefItem(fakeStopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(fakeStopperID, true);
	rmSetObjectDefMinDistance(fakeStopperID, 0.0);
	rmSetObjectDefMaxDistance(fakeStopperID, 0.0); 

    // Place fake train stopper, because without it the islands son't spawn
	vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.05);
	rmPlaceObjectDefAtPoint(fakeStopperID, 0, socketLoc1);

   // Additional Trade Route stopper for the East Trade Route
   int fakeStopperID2=rmCreateObjectDef("TradeShipStopperFake2");
	rmAddObjectDefItem(fakeStopperID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(fakeStopperID2, true);
	rmSetObjectDefMinDistance(fakeStopperID2, 0.0);
	rmSetObjectDefMaxDistance(fakeStopperID2, 0.0); 

   vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, 0.05);
	rmPlaceObjectDefAtPoint(fakeStopperID2, 0, socketLoc2);

   // Text
	rmSetStatusText("",0.10);

   // River to dock the City States

   int riverID = rmRiverCreate(-1, "caribbean coast", 4, 4, 68, 68); //  (-1, "new england lake", 18, 14, 5, 5)
   rmRiverAddWaypoint(riverID, 0.1, 0.9);
   rmRiverAddWaypoint(riverID, 0.9, 0.1);
   rmRiverBuild(riverID);

   // ****************************** Place Pirate City States *****************************

   // Pirate City State 1

   rmDefineClass("classPlateau");

   rmSetNuggetDifficulty(294, 294);

   int piratesVillageID = rmCreateGrouping("pirate city", "Pirate_CityState_01");
   rmSetGroupingMinDistance(piratesVillageID, 0.00);
   rmSetGroupingMaxDistance(piratesVillageID, 0.01);
	rmAddGroupingToClass(piratesVillageID, rmClassID("classPlateau"));

   int pirateInstanceID1 = rmPlaceGroupingInstanceAtLoc(piratesVillageID,  0.31, 0.69, 0);

   // Pirate City State 2

   int piratesVillage2ID = rmCreateGrouping("pirate city2", "Pirate_CityState_02");
   rmSetGroupingMinDistance(piratesVillage2ID, 0.00);
   rmSetGroupingMaxDistance(piratesVillage2ID, 0.01);
	rmAddGroupingToClass(piratesVillage2ID, rmClassID("classPlateau"));

   int pirateInstanceID2 = rmPlaceGroupingInstanceAtLoc(piratesVillage2ID,  0.73, 0.33, 0);


   //**************************** Kongs's Castle ***********************************

   if (rmGetIsKOTH()){
      int kotHID2 = rmCreateGrouping("koth castle", "Caribbean_Naval_KotH");
      rmSetGroupingMinDistance(kotHID2, 0.00);
      rmSetGroupingMaxDistance(kotHID2, 0.01);
      rmAddGroupingToClass(kotHID2, rmClassID("classPlateau"));
      //rmPlaceGroupingAtLoc(kotHID2, 0, 0.5, 0.5, 1);

      int kotHInstance = rmPlaceGroupingInstanceAtLoc(kotHID2,  0.5, 0.5, 0);
   }


   // ******************************** Place Terrain ********************************

   // North Island
   int northIsland = rmCreateArea ("north island");
   rmSetAreaSize(northIsland, 0.18, 0.18);
   rmSetAreaLocation(northIsland, 0.85, 0.85);
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
      rmSetAreaLocation(portSite1, 0.5+rmXTilesToFraction(22), 0.8);
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
      rmSetAreaLocation(portSite2, 0.8, 0.5+rmZTilesToFraction(25));
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

   // South Island
   int southIsland = rmCreateArea ("south island");
   rmSetAreaSize(southIsland, 0.18, 0.18);
   rmSetAreaLocation(southIsland, 0.15, 0.15);
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
      rmSetAreaLocation(portSite3, 0.2, 0.5-rmXTilesToFraction(20));
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
      rmSetAreaLocation(portSite4, 0.5-rmXTilesToFraction(20), 0.2);
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

   // Bonus Islands

   int bonusIslandID = rmCreateArea ("bonus island");
   if (cNumberNonGaiaPlayers <= 4){
      rmSetAreaSize(bonusIslandID, 0.13, 0.13);
   }
   else{
      rmSetAreaSize(bonusIslandID, 0.115, 0.115);
   }
   rmSetAreaLocation(bonusIslandID, 0.9, 0.1);
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
   rmAddAreaConstraint(bonusIslandID, avoidPirateHouse); 
   rmAddAreaConstraint(bonusIslandID, avoidPirateDock1);
   rmAddAreaConstraint(bonusIslandID, avoidPirateDock2);
   rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
   rmSetAreaElevationVariation(bonusIslandID, 4.0);
   rmSetAreaElevationPersistence(bonusIslandID, 0.2);
   rmSetAreaElevationNoiseBias(bonusIslandID, 1);
   rmAddAreaToClass(bonusIslandID, classIsland);
   rmAddAreaToClass(bonusIslandID, classBonusIsland);

   int bonusIslandID2 = rmCreateArea ("bonus island 2");
   if (cNumberNonGaiaPlayers <= 4){
      rmSetAreaSize(bonusIslandID2, 0.13, 0.13);
   }
   else{
      rmSetAreaSize(bonusIslandID2, 0.115, 0.115);
   }
   rmSetAreaLocation(bonusIslandID2, 0.1, 0.9);
   rmSetAreaCoherence(bonusIslandID2, 0.4);
   rmSetAreaMinBlobs(bonusIslandID2, 8);
   rmSetAreaMaxBlobs(bonusIslandID2, 12);
   rmSetAreaMinBlobDistance(bonusIslandID2, 8.0);
   rmSetAreaMaxBlobDistance(bonusIslandID2, 10.0);
   rmSetAreaSmoothDistance(bonusIslandID2, 15);
   rmSetAreaMix(bonusIslandID2, "caribbean grass");
   rmSetAreaBaseHeight(bonusIslandID2, 2.2);
   rmAddAreaConstraint(bonusIslandID2, islandConstraint);
   rmAddAreaConstraint(bonusIslandID2, islandAvoidTradeRoute); 
   rmAddAreaConstraint(bonusIslandID2, avoidPirateHouse); 
   rmAddAreaConstraint(bonusIslandID2, avoidPirateDock1);
   rmAddAreaConstraint(bonusIslandID2, avoidPirateDock2);
   rmSetAreaElevationType(bonusIslandID2, cElevTurbulence);
   rmSetAreaElevationVariation(bonusIslandID2, 4.0);
   rmSetAreaElevationPersistence(bonusIslandID2, 0.2);
   rmSetAreaElevationNoiseBias(bonusIslandID2, 1);
   rmAddAreaToClass(bonusIslandID2, classIsland);
   rmAddAreaToClass(bonusIslandID2, classBonusIsland);


   // Text
	rmSetStatusText("",0.20);

   // Area builder
   rmBuildAllAreas();

   // add island constraints
   int northIslandConstraint=rmCreateAreaConstraint("north Island", northIsland);
   int southIslandConstraint=rmCreateAreaConstraint("south Island", southIsland);
   int bonusIslandConstraint=rmCreateAreaConstraint("bonus Island", bonusIslandID);
   int bonusIslandConstraint2=rmCreateAreaConstraint("bonus Island2", bonusIslandID2);

      
   // ********************* Additional Objects *****************************

   // Place ports
   // Port 1
   int portID01 = rmCreateObjectDef("port 01");
   portID01 = rmCreateGrouping("portG 01", "harbour_center_sw");
   rmPlaceGroupingAtLoc(portID01, 0, 0.5+rmXTilesToFraction(12), 0.8+rmZTilesToFraction(0));

   // Port 2
   int portID02 = rmCreateObjectDef("port 02");
   portID02 = rmCreateGrouping("portG 02", "harbour_centerb_se");
   rmPlaceGroupingAtLoc(portID02, 0, 0.8+rmXTilesToFraction(0), 0.5+rmZTilesToFraction(15));


   // Port 3
   int portID03 = rmCreateObjectDef("port 03");
   portID03 = rmCreateGrouping("portG 03", "harbour_centerb_ne");
   rmPlaceGroupingAtLoc(portID03, 0, 0.5-rmXTilesToFraction(9), 0.2+rmZTilesToFraction(1));

   // Port 4
   int portID04 = rmCreateObjectDef("port 04");
   portID04 = rmCreateGrouping("portG 04", "harbour_center_nw");
   rmPlaceGroupingAtLoc(portID04, 0, 0.2+rmXTilesToFraction(1), 0.5-rmZTilesToFraction(9.5));

   // Text
	rmSetStatusText("",0.30);

   // Place Caribs

   // Lonely Caribs
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
   rmPlaceGroupingInArea(caribsVillageID, 0, bonusIslandID2, 1);

   // Team Maltese

   int maltese4VillageID = -1;
   int maltese4VillageType = rmRandInt(1,3);
   maltese4VillageID = rmCreateGrouping("maltese4 city", "Maltese_village_ME0"+maltese4VillageType);
   rmAddGroupingConstraint(maltese4VillageID, avoidTC);
   rmAddGroupingConstraint(maltese4VillageID, avoidCW);
   rmAddGroupingConstraint(maltese4VillageID, avoidImpassableLand);
   rmAddGroupingConstraint(maltese4VillageID, avoidSocketLong);
   rmPlaceGroupingInArea(maltese4VillageID, 0, northIsland, 1);
   rmAddClosestPointConstraint(villageEdgeConstraint);

   int maltese5VillageID = -1;
   int maltese5VillageType = rmRandInt(1,3);
   maltese5VillageID = rmCreateGrouping("maltese5 city", "Maltese_village_ME0"+maltese5VillageType);
   rmAddGroupingConstraint(maltese5VillageID, avoidTC);
   rmAddGroupingConstraint(maltese5VillageID, avoidCW);
   rmAddGroupingConstraint(maltese5VillageID, avoidImpassableLand);
   rmAddGroupingConstraint(maltese5VillageID, avoidSocketLong);
   rmPlaceGroupingInArea(maltese5VillageID, 0, southIsland, 1);
   rmAddClosestPointConstraint(villageEdgeConstraint);

   // Team Caribs

   int caribs2VillageID = -1;
   int caribs2VillageType = rmRandInt(1,5);
   caribs2VillageID = rmCreateGrouping("caribs2 city", "native carib village 0"+caribs2VillageType);
   rmAddGroupingConstraint(caribs2VillageID, avoidTC);
   rmAddGroupingConstraint(caribs2VillageID, avoidCW);
   rmAddGroupingConstraint(caribs2VillageID, avoidImpassableLand);
   rmAddGroupingConstraint(caribs2VillageID, avoidSocketLong);
   rmAddClosestPointConstraint(villageEdgeConstraint);

   if (cNumberNonGaiaPlayers <= 4){
   rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 1);
   }

   else {
   rmPlaceGroupingInArea(caribs2VillageID, 0, northIsland, 2);
   }

   
   int caribs3VillageID = -1;
   int caribs3VillageType = rmRandInt(1,5);
   caribs3VillageID = rmCreateGrouping("caribs3 city", "native carib village 0"+caribs3VillageType);
   rmAddGroupingConstraint(caribs3VillageID, avoidTC);
   rmAddGroupingConstraint(caribs3VillageID, avoidCW);
   rmAddGroupingConstraint(caribs3VillageID, avoidImpassableLand);
   rmAddGroupingConstraint(caribs3VillageID, avoidSocketLong);
   rmAddClosestPointConstraint(villageEdgeConstraint);
  
   if (cNumberNonGaiaPlayers <= 4){
   rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 1);
   }

   else {
   rmPlaceGroupingInArea(caribs3VillageID, 0, southIsland, 2);
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
      rmSetPlacementTeam(0);
      rmSetPlacementSection(0.05, 0.2);
      rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
      rmSetPlacementTeam(1);
      rmSetPlacementSection(0.55, 0.7); 
      rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
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
   rmAddObjectDefConstraint(TCID, avoidSocketLong);

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
   rmAddClosestPointConstraint(avoidHarbour);
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

   for(i=0; < 4)
	{
      silverID = rmCreateObjectDef("bonus2 silver "+i);
      rmAddObjectDefItem(silverID, "mine", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(silverID, avoidCoin);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(silverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(silverID, bonusIslandConstraint2);
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
   rmPlaceObjectDefInArea(nugget2, 0, bonusIslandID2, cNumberNonGaiaPlayers);

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
   rmPlaceObjectDefInArea(deerID, 0, bonusIslandID2, cNumberNonGaiaPlayers);
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
   rmAddObjectDefConstraint(fishID, avoidRevealer);
   rmAddObjectDefConstraint(fishID, avoidKOTH);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers);

   int fish2ID=rmCreateObjectDef("fish Tarpon");
   rmAddObjectDefItem(fish2ID, "FishTarpon", 1, 0.0);
   rmSetObjectDefMinDistance(fish2ID, 0.0);
   rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fish2ID, fishVsFishID);
   rmAddObjectDefConstraint(fish2ID, fishLand);
   rmAddObjectDefConstraint(fish2ID, avoidRevealer);
   rmAddObjectDefConstraint(fish2ID, avoidKOTH);
   rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 5*cNumberNonGaiaPlayers);

   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmAddObjectDefConstraint(whaleID, avoidRevealerLong);
   rmAddObjectDefConstraint(whaleID, avoidKOTHLong);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // RANDOM TREES
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "treeCaribbean", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

   //********************* GENERAL SETUP *************************

	// ____________________ LOCAL MERCENARIES ____________________
   rmDisableDefaultMercs(true);
   rmDisableCivTypeMercRestriction(true);
   rmEnableMerc("SaloonPirate", -1);
   rmEnableMerc("MercBarbaryCorsair", -1);
   rmEnableMerc("deMercKanuri", -1);
   rmEnableMerc("deMercBrigadier", -1);
   rmEnableMerc("MercGreatCannon", -1);

   //rmForbidTradeMonopoly(true);

   // ____________________ MAP OBJECTIVES ____________________
    rmObjectiveScreenSetTitle(302118);
    rmObjectiveScreenSetGoal(302119);
    if (rmGetIsKOTH())
      rmObjectiveAdd(302236, 302232, true, true, true);
    else
      rmObjectiveAdd(302225, 302226, true, true, true);
    rmObjectiveAdd(302223, 302224, false, true, true);


// ------Triggers--------//

//----- Define Variables -----

int pirateSocket1 = rmGetGroupingInstanceUnitByType(pirateInstanceID1, "zpSPCSocketPirateCityState");
int pirateSocket2 = rmGetGroupingInstanceUnitByType(pirateInstanceID2, "zpSPCSocketPirateCityState");

int pirateNugget1 = rmGetGroupingInstanceUnitByType(pirateInstanceID1, "zpNuggetInvisible");
int pirateNugget2 = rmGetGroupingInstanceUnitByType(pirateInstanceID2, "zpNuggetInvisible");

int pirateCenter1 = rmGetGroupingInstanceUnitByType(pirateInstanceID1, "zpSPCWaterSpawnPoint");
int pirateCenter2 = rmGetGroupingInstanceUnitByType(pirateInstanceID2, "zpSPCWaterSpawnPoint");

int kothCastle = rmGetGroupingInstanceUnitByType(kotHInstance, "zpKingsHillNaval");

int pirateSocketMod1 = pirateSocket1+0;
int pirateSocketMod2 = pirateSocket2+0;

int pirateNuggetMod1 = pirateNugget1+0;
int pirateNuggetMod2 = pirateNugget2+0;

int kothCastleMod = kothCastle+0;

vector pirateCityLoc1 = rmGetUnitPosition(pirateCenter1);
vector pirateCityLoc2 = rmGetUnitPosition(pirateCenter2);
vector kothLoc = rmGetUnitPosition(kothCastle);

int TradeRouteStartID1 = rmGetUnitPlaced(fakeStopperID, 0);
int TradeRouteStartID2 = rmGetUnitPlaced(fakeStopperID2, 0);

int socketMinimapFlareDuration = 10;
int victoryCountDown = 600;

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
rmSetTriggerEffectParam("TechID","cTechzpEnableSPCPirateCityTechs");
rmSetTriggerEffectParamInt("Status",2);
}
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); 
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// **************** KotH Victory ************************

if (rmGetIsKOTH()){
   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("ConvertKotH_Player"+k);
   }

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
      rmAddTriggerEffect("Convert Units in Area");
      rmSetTriggerEffectParam("SrcObject",""+kothCastleMod);
      rmSetTriggerEffectParamInt("SrcPlayer",i);
      rmSetTriggerEffectParamInt("TrgPlayer",k);
      rmSetTriggerEffectParam("UnitType","zpPropWaterTower");
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

// *******************************************************

// Conversion Suspend
rmCreateTrigger("Buildings Convert OFF");
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParam("ActionName", "AutoConvert");
rmSetTriggerEffectParam("Suspend", "True");
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParam("ActionName", "AutoConvert");
rmSetTriggerEffectParam("Suspend", "True");
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Socket 1 Convert ON");
rmAddTriggerCondition("Nugget Is Collectable");
rmSetTriggerConditionParam("NuggetObject", ""+pirateNuggetMod1);
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject", ""+pirateSocketMod1, false);
rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
rmSetTriggerEffectParam("Suspend", "False", false);
rmAddTriggerEffect("Flash Units");
rmSetTriggerEffectParam("SrcObject", ""+pirateSocketMod1, false);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Socket 2 Convert ON");
rmAddTriggerCondition("Nugget Is Collectable");
rmSetTriggerConditionParam("NuggetObject", ""+pirateNuggetMod2);
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject", ""+pirateSocketMod2, false);
rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
rmSetTriggerEffectParam("Suspend", "False", false);
rmAddTriggerEffect("Flash Units");
rmSetTriggerEffectParam("SrcObject", ""+pirateSocketMod2, false);
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

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Maltese"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpMalteseCross"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffMaltese"); //operator
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Trade route Blockade

rmCreateTrigger("Blockad_Initialize_Variables");
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeWest");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeEast");
rmSetTriggerEffectParamInt("Value",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Blockad_TR_West");
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeWest");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeEast");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",0);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Blockad_TR_East");
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeWest");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",0);
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeEast");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Blockad_TR_All");
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeWest");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeEast");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",1);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","false");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("Blockad_TR_None");
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeWest");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",0);
rmAddTriggerCondition("Quest Var Check");
rmSetTriggerConditionParam("QuestVar","BlockadeEast");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamInt("Value",0);
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",1);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Trade Route Toggle State");
rmSetTriggerEffectParamInt("TradeRoute",2);
rmSetTriggerEffectParam("ShowUnit","true");
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("Blockad_TR1_On_Plr"+k);
rmCreateTrigger("Blockad_TR1_OFF_Plr"+k);
rmCreateTrigger("Blockad_TR2_On_Plr"+k);
rmCreateTrigger("Blockad_TR2_OFF_Plr"+k);

rmSwitchToTrigger(rmTriggerID("Blockad_TR1_On_Plr"+k));
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpSPCTradeRouteStopWest");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeWest");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR1_Off_Plr"+k));
for (i=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteStopWest");
   rmSetTriggerEffectParamInt("Status",0);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteGoWest");
   rmSetTriggerEffectParamInt("Status",1);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Blockad_TR1_Off_Plr"+k));
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpSPCTradeRouteGoWest");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeWest");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR1_On_Plr"+k));
for (i=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteStopWest");
   rmSetTriggerEffectParamInt("Status",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteGoWest");
   rmSetTriggerEffectParamInt("Status",0);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Blockad_TR2_On_Plr"+k));
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpSPCTradeRouteStopEast");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeEast");
rmSetTriggerEffectParamInt("Value",1);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR2_Off_Plr"+k));
for (i=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",i);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteStopEast");
   rmSetTriggerEffectParamInt("Status",0);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteGoEast");
   rmSetTriggerEffectParamInt("Status",1);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Blockad_TR2_Off_Plr"+k));
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechzpSPCTradeRouteGoEast");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("Quest Var Set");
rmSetTriggerEffectParam("QVName","BlockadeEast");
rmSetTriggerEffectParamInt("Value",0);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR2_On_Plr"+k));
for (i=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteStopEast");
   rmSetTriggerEffectParamInt("Status",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpSPCTradeRouteGoEast");
   rmSetTriggerEffectParamInt("Status",0);
}
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

}

// Update ports

rmCreateTrigger("I Update Ports TR1");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",""+TradeRouteStartID1);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","deTradingGalleon");
rmSetTriggerConditionParamInt("Dist",150);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports TR1");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",""+TradeRouteStartID1);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","deTradingFluyt");
rmSetTriggerConditionParamInt("Dist",150);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("I Update Ports TR2");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",""+TradeRouteStartID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","deTradingGalleon");
rmSetTriggerConditionParamInt("Dist",150);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePortB1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmCreateTrigger("II Update Ports TR2");
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject",""+TradeRouteStartID2);
rmSetTriggerConditionParamInt("Player",0);
rmSetTriggerConditionParam("UnitType","deTradingFluyt");
rmSetTriggerConditionParamInt("Dist",150);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParam("TechID","cTechzpUpdatePortB2");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_None"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_All"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_East"));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Blockad_TR_West"));
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
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
rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
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
   rmSetTriggerConditionParamInt("Param1",200);
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
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
   rmSetTriggerConditionParamInt("Param1",1200);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
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
   rmSetTriggerConditionParamInt("Param1",200);
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
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
   rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
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
rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateTavern");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCPirateDock");
rmSetTriggerEffectParamInt("Dist",100);
for(x=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("Flare Minimap");
   rmSetTriggerEffectParamInt("PlayerID", x, false);
   rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
   rmSetTriggerEffectParam("Position", ""+xsVectorGetX(pirateCityLoc1)+","+xsVectorGetY(pirateCityLoc1)+","+xsVectorGetZ(pirateCityLoc1), false);
   rmSetTriggerEffectParam("Flash", "True", false);
}
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
rmSetTriggerConditionParam("DstObject",""+pirateSocketMod1);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateTavern");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod1);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCPirateDock");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Flare Minimap");
rmSetTriggerEffectParamInt("PlayerID", k, false);
rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
rmSetTriggerEffectParam("Position", ""+xsVectorGetX(pirateCityLoc1)+","+xsVectorGetY(pirateCityLoc1)+","+xsVectorGetZ(pirateCityLoc1), false);
rmSetTriggerEffectParam("Flash", "True", false);
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
rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateTavernB");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpSPCPirateDockB");
rmSetTriggerEffectParamInt("Dist",100);
for(x=1; <= cNumberNonGaiaPlayers) {
   rmAddTriggerEffect("Flare Minimap");
   rmSetTriggerEffectParamInt("PlayerID", x, false);
   rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
   rmSetTriggerEffectParam("Position", ""+xsVectorGetX(pirateCityLoc2)+","+xsVectorGetY(pirateCityLoc2)+","+xsVectorGetZ(pirateCityLoc2), false);
   rmSetTriggerEffectParam("Flash", "True", false);
}
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
rmSetTriggerConditionParam("DstObject",""+pirateSocketMod2);
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateTavernB");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject",""+pirateSocketMod2);
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpSPCPirateDockB");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Flare Minimap");
rmSetTriggerEffectParamInt("PlayerID", k, false);
rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
rmSetTriggerEffectParam("Position", ""+xsVectorGetX(pirateCityLoc2)+","+xsVectorGetY(pirateCityLoc2)+","+xsVectorGetZ(pirateCityLoc2), false);
rmSetTriggerEffectParam("Flash", "True", false);
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