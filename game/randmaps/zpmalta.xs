
// Malta 2.5 08 10 2022

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
		subCiv0=rmGetCivID("maltese");
      rmEchoInfo("subCiv0 is maltese "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "maltese");

      subCiv1=rmGetCivID("maltese");
      rmEchoInfo("subCiv1 is maltese "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "maltese");
  
		subCiv2=rmGetCivID("natpirates");
		rmEchoInfo("subCiv2 is pirates "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "natpirates");
	}
	
   // Set size.
   int playerTiles=25000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 18000;
	if (cNumberNonGaiaPlayers >7)
		playerTiles = 20000;			
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(1.0);
   rmSetSeaType("Africa Desert Beach");
	rmSetMapType("euroLaclasssocketndNavalTradeRoute");
	rmSetMapType("grass");
	rmSetMapType("water");
  	rmSetMapType("mediEurope");
   rmSetMapType("euroNavalTradeRoute");

   rmSetLightingSet("punjab_skirmish");
   rmSetOceanReveal(true);

   // Init map.
   rmTerrainInitialize("water");

   // Define some classes.
   int classPlayer=rmDefineClass("player");
   int classIsland=rmDefineClass("island");
   int classBonusIsland=rmDefineClass("bonusIsland");
   int classDesertIsland=rmDefineClass("desertIsland");
   int classTeamIsland=rmDefineClass("teamIsland");
   int classPortSite=rmDefineClass("portSite");
   int westIslandClass=rmDefineClass("westIsland");
   int eastIslandClass=rmDefineClass("eastIsland");
   int classMountains=rmDefineClass("mountains");
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
   int westIslandCliffConstraint=rmCreateClassDistanceConstraint("no cliffs on west Island", westIslandClass, 48.0);
   int eastIslandCliffConstraint=rmCreateClassDistanceConstraint("no cliffs on east island", eastIslandClass, 48.0);
   int portSiteConstraint=rmCreateClassDistanceConstraint("no cliffs on port site", classPortSite, 5.0);

   // Constraints to avoid water trade Route
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 20.0);
   int islandAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 7.0);
   int islandAvoidTradeRouteMedium = rmCreateTradeRouteDistanceConstraint("trade route medium", 11.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
   int ObjectAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("object avoid trade route short", 3.0);

   // Player objects constraints
   int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 25.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 55);
   int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-130, 0, 0, 0);  
   int playersAwayPort=rmCreateAreaDistanceConstraint("players not in port ", classPortSite, 0.01);
   int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 29.0);
   int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 15.0);
   int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 8.0);
   int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);

   //Socket Constraints
   int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("Socket"), 10.0);
   int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
   int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 70.0);

   // Bonus Area Constraints
   int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 30.0);
   int avoidDesertIslands=rmCreateClassDistanceConstraint("stuff avoids desert islands", classDesertIsland, 30.0);
   int avoidTeamIslands=rmCreateClassDistanceConstraint("stuff avoids team islands", classTeamIsland, 30.0);
   int villageEdgeConstraint = rmCreatePieConstraint("willabe awlaay from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-50, 0, 0, 0);
   int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 7.0);

   // Avoid impassable Land
   int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 13.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);

   // Avoid water
  int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 30.0);
   int avoidWater70 = rmCreateTerrainDistanceConstraint("avoid water very large", "Land", false, 30.0);
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 5.5);

   // Nature Constraints
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mineSalt", 35.0);
   int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishSalmon", 20.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);

   int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0); 
   int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);
   int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0); 

// Trade Routes
int tradeRouteID = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID);

rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.4);
rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.4);
rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.3);
rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.1);
rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.0);

bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

int tradeRouteID2 = rmCreateTradeRoute();
rmSetObjectDefTradeRouteID(tradeRouteID2);

rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.3);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.5);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.55, 0.55);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.8);
rmAddTradeRouteWaypoint(tradeRouteID2, 0.3, 1.0);


bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "water_trail");

// Text
	rmSetStatusText("",0.10);


// east island
int eastIsland = rmCreateArea ("east island");
rmSetAreaSize(eastIsland, 0.10, 0.10);
rmSetAreaLocation(eastIsland, 0.6, 0.2);
rmSetAreaCoherence(eastIsland, 0.6);
rmSetAreaMinBlobs(eastIsland, 8);
rmSetAreaMaxBlobs(eastIsland, 12);
rmSetAreaMinBlobDistance(eastIsland, 8.0);
rmSetAreaMaxBlobDistance(eastIsland, 10.0);
rmSetAreaSmoothDistance(eastIsland, 15);
rmSetAreaMix(eastIsland, "Africa Desert Grass dry");
rmSetAreaBaseHeight(eastIsland, 2.2);
rmAddAreaConstraint(eastIsland, islandConstraint);
rmAddAreaConstraint(eastIsland, islandAvoidTradeRoute);
rmSetAreaElevationType(eastIsland, cElevTurbulence);
rmSetAreaElevationVariation(eastIsland, 3.0);
rmSetAreaElevationPersistence(eastIsland, 0.2);
rmSetAreaElevationNoiseBias(eastIsland, 1);
rmAddAreaToClass(eastIsland, classIsland);
rmAddAreaToClass(eastIsland, classTeamIsland); 
rmAddAreaToClass(eastIsland, eastIslandClass); 

rmAddAreaInfluenceSegment(eastIsland, 0.5, 0.2, 0.65, 0.45);


   // Port Sites
   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite1, 0.4+rmXTilesToFraction(18), 0.1);
   rmSetAreaMix(portSite1, "africa desert grass 4");
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 2.2);
   rmAddAreaToClass(portSite1, classPortSite);

   int connectionID1 = rmCreateConnection ("connection_island1");
   rmSetConnectionType(connectionID1, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID1, 20, 4);
   rmSetConnectionCoherence(connectionID1, 0.7);
   rmSetConnectionWarnFailure(connectionID1, false);
   rmAddConnectionArea(connectionID1, eastIsland);
   rmAddConnectionArea(connectionID1, portSite1);
   rmSetConnectionBaseHeight(connectionID1, 2);
   rmBuildConnection(connectionID1);


   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, 0.8,0.5-rmXTilesToFraction(28));
   rmSetAreaMix(portSite2, "africa desert grass 4");
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 2.5);
   rmAddAreaToClass(portSite2, classPortSite);

   int connectionID2 = rmCreateConnection ("connection_island2");
   rmSetConnectionType(connectionID2, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID2, 20, 4);
   rmSetConnectionCoherence(connectionID2, 0.7);
   rmSetConnectionWarnFailure(connectionID2, false);
   rmAddConnectionArea(connectionID2, eastIsland);
   rmAddConnectionArea(connectionID2, portSite2);
   rmSetConnectionBaseHeight(connectionID2, 2);
   rmBuildConnection(connectionID2);


// west Island
int westIsland = rmCreateArea ("west Island");
rmSetAreaSize(westIsland, 0.09, 0.09);
rmSetAreaLocation(westIsland, 0.2, 0.6);
rmSetAreaCoherence(westIsland, 0.60);
rmSetAreaMinBlobs(westIsland, 8);
rmSetAreaMaxBlobs(westIsland, 12);
rmSetAreaMinBlobDistance(westIsland, 8.0);
rmSetAreaMaxBlobDistance(westIsland, 10.0);
rmSetAreaSmoothDistance(westIsland, 15);
rmSetAreaMix(westIsland, "Africa Desert Grass dry");
rmSetAreaBaseHeight(westIsland, 2.2);
rmAddAreaConstraint(westIsland, islandConstraint);
rmAddAreaConstraint(westIsland, islandAvoidTradeRoute); 
rmSetAreaElevationType(westIsland, cElevTurbulence);
rmSetAreaElevationVariation(westIsland, 3.0);
rmSetAreaElevationPersistence(westIsland, 0.2);
rmSetAreaElevationNoiseBias(westIsland, 1);
rmAddAreaToClass(westIsland, classIsland);
rmAddAreaToClass(westIsland, classTeamIsland);
rmAddAreaToClass(westIsland, westIslandClass);

rmAddAreaInfluenceSegment(westIsland, 0.2, 0.5, 0.45, 0.65);

   // Port Sites

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite3, 0.1, 0.4+rmZTilesToFraction(18));
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaMix(portSite3, "africa desert grass 4");
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.5);
   rmAddAreaToClass(portSite3, classPortSite);

   int connectionID3 = rmCreateConnection ("connection_island3");
   rmSetConnectionType(connectionID3, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID3, 17, 4);
   rmSetConnectionCoherence(connectionID3, 0.5);
   rmSetConnectionWarnFailure(connectionID3, false);
   rmAddConnectionArea(connectionID3, westIsland);
   rmAddConnectionArea(connectionID3, portSite3);
   rmSetConnectionBaseHeight(connectionID3, 2);
   rmBuildConnection(connectionID3);

   int portSite4 = rmCreateArea ("port_site4");
   rmSetAreaSize(portSite4, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite4, 0.5-rmXTilesToFraction(28), 0.8);
   rmSetAreaCoherence(portSite4, 1);
   rmSetAreaMix(portSite4, "africa desert grass 4");
   rmSetAreaSmoothDistance(portSite4, 15);
   rmSetAreaBaseHeight(portSite4, 2.5);
   rmAddAreaToClass(portSite4, classPortSite);

   int connectionID4 = rmCreateConnection ("connection_island4");
   rmSetConnectionType(connectionID4, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID4, 20, 4);
   rmSetConnectionCoherence(connectionID4, 0.4);
   rmSetConnectionWarnFailure(connectionID4, false);
   rmAddConnectionArea(connectionID4, westIsland);
   rmAddConnectionArea(connectionID4, portSite4);
   rmSetConnectionBaseHeight(connectionID4, 2);
   rmBuildConnection(connectionID4);

// North Bonus Island

// bonus Island North
int bonusIslandNorth = rmCreateArea ("bonus Island North");
rmSetAreaSize(bonusIslandNorth, 0.15, 0.15);
rmSetAreaLocation(bonusIslandNorth, 0.9, 0.9);
rmSetAreaCoherence(bonusIslandNorth, 0.4);
rmSetAreaMinBlobs(bonusIslandNorth, 8);
rmSetAreaMaxBlobs(bonusIslandNorth, 12);
rmSetAreaMinBlobDistance(bonusIslandNorth, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandNorth, 10.0);
rmSetAreaSmoothDistance(bonusIslandNorth, 15);
rmSetAreaMix(bonusIslandNorth, "Africa Desert Grass dry");
rmSetAreaBaseHeight(bonusIslandNorth, 2.2);
rmAddAreaConstraint(bonusIslandNorth, islandConstraint);
rmAddAreaConstraint(bonusIslandNorth, islandAvoidTradeRoute); 
rmSetAreaElevationType(bonusIslandNorth, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandNorth, 3.0);
rmSetAreaElevationPersistence(bonusIslandNorth, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandNorth, 1);
rmAddAreaToClass(bonusIslandNorth, classIsland);
rmAddAreaToClass(bonusIslandNorth, classBonusIsland);

int portSite5 = rmCreateArea ("port_site5");
   rmSetAreaSize(portSite5, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(portSite5, 0.55+rmXTilesToFraction(15), 0.55+rmXTilesToFraction(15));
   rmSetAreaMix(portSite5, "africa desert grass 4");
   rmSetAreaCoherence(portSite5, 1);
   rmSetAreaSmoothDistance(portSite5, 15);
   rmSetAreaBaseHeight(portSite5, 2.2);
   rmAddAreaToClass(portSite5, classPortSite);

   int connectionID5 = rmCreateConnection ("connection_island5");
   rmSetConnectionType(connectionID5, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID5, 20, 4);
   rmSetConnectionCoherence(connectionID5, 0.7);
   rmSetConnectionWarnFailure(connectionID5, false);
   rmAddConnectionArea(connectionID5, bonusIslandNorth);
   rmAddConnectionArea(connectionID5, portSite5);
   rmSetConnectionBaseHeight(connectionID5, 2);
   rmBuildConnection(connectionID5);

// South Bonus Island

int bonusIslandSouth = rmCreateArea ("bonus Island South");
rmSetAreaSize(bonusIslandSouth, 0.07, 0.07);
rmSetAreaLocation(bonusIslandSouth, 0.1, 0.1);
rmSetAreaCoherence(bonusIslandSouth, 0.4);
rmSetAreaMinBlobs(bonusIslandSouth, 8);
rmSetAreaMaxBlobs(bonusIslandSouth, 12);
rmSetAreaMinBlobDistance(bonusIslandSouth, 8.0);
rmSetAreaMaxBlobDistance(bonusIslandSouth, 10.0);
rmSetAreaSmoothDistance(bonusIslandSouth, 15);
rmSetAreaMix(bonusIslandSouth, "africa desert sand");
rmSetAreaBaseHeight(bonusIslandSouth, 2.2);
rmAddAreaConstraint(bonusIslandSouth, islandConstraint);
rmAddAreaConstraint(bonusIslandSouth, islandAvoidTradeRouteShort); 
rmSetAreaElevationType(bonusIslandSouth, cElevTurbulence);
rmSetAreaElevationVariation(bonusIslandSouth, 3.0);
rmSetAreaElevationPersistence(bonusIslandSouth, 0.2);
rmSetAreaElevationNoiseBias(bonusIslandSouth, 1);
rmAddAreaToClass(bonusIslandSouth, classIsland);
rmAddAreaToClass(bonusIslandSouth, classBonusIsland);
rmAddAreaToClass(bonusIslandSouth, classDesertIsland);

/*int pirateSite = rmCreateArea ("pirate site");
   rmSetAreaSize(pirateSite, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
    rmSetAreaLocation(pirateSite, 0.3-rmXTilesToFraction(20), 0.3-rmXTilesToFraction(20));
   rmSetAreaMix(pirateSite, "africa desert");
   rmSetAreaCoherence(pirateSite, 1);
   rmSetAreaSmoothDistance(pirateSite, 15);
   rmSetAreaBaseHeight(pirateSite, 2.2);
   rmAddAreaToClass(pirateSite, classPortSite);

   int connectionID6 = rmCreateConnection ("connection_island5");
   rmSetConnectionType(connectionID6, cConnectAreas, false, 1);
   rmSetConnectionWidth(connectionID6, 20, 4);
   rmSetConnectionCoherence(connectionID6, 0.7);
   rmSetConnectionWarnFailure(connectionID6, false);
   rmAddConnectionArea(connectionID6, bonusIslandSouth);
   rmAddConnectionArea(connectionID6, pirateSite);
   rmSetConnectionBaseHeight(connectionID6, 2);
   rmBuildConnection(connectionID6);*/

// Area builder
rmBuildAllAreas();

// Place Controllers
   int controllerID1 = rmCreateObjectDef("Controler 1");
   rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmSetObjectDefMinDistance(controllerID1, 0.0);
   rmSetObjectDefMaxDistance(controllerID1, 40.0);
   rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
   rmAddObjectDefConstraint(controllerID1, ferryOnShore); 
   rmPlaceObjectDefAtLoc(controllerID1, 0, 0.2, 0.3);
   vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

   int controllerID2 = rmCreateObjectDef("Controler 2");
   rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmSetObjectDefMinDistance(controllerID2, 0.0);
	rmSetObjectDefMaxDistance(controllerID2, 40.0);
   rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
   rmAddObjectDefConstraint(controllerID2, ferryOnShore);
   rmPlaceObjectDefAtLoc(controllerID2, 0, 0.3, 0.15);
   vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

// Place Trade Route
   int tradeRoute3ID = rmCreateTradeRoute();
   int socket3ID=rmCreateObjectDef("sockets to dock Trade Posts");
   rmSetObjectDefTradeRouteID(socket3ID, tradeRoute3ID);

      rmAddObjectDefItem(socket3ID, "SocketTradeRoute", 1, 0.0);
      rmSetObjectDefAllowOverlap(socket3ID, true);
      rmSetObjectDefMinDistance(socket3ID, 2.0);
      rmSetObjectDefMaxDistance(socket3ID, 8.0);

   rmAddTradeRouteWaypoint(tradeRoute3ID, 0.6, 1.0);
   rmAddTradeRouteWaypoint(tradeRoute3ID, 0.7, 0.7);
   rmAddTradeRouteWaypoint(tradeRoute3ID, 1.0, 0.6);
   bool placedTradeRoute3 = rmBuildTradeRoute(tradeRoute3ID, "dirt");

   vector socketLoc  = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.3);
      rmPlaceObjectDefAtPoint(socket3ID, 0, socketLoc);

   socketLoc  = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.7);
      rmPlaceObjectDefAtPoint(socket3ID, 0, socketLoc);

   if (cNumberNonGaiaPlayers > 4){
      socketLoc  = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.5);
         rmPlaceObjectDefAtPoint(socket3ID, 0, socketLoc);
   }

// Place King's Hill
   if (rmGetIsKOTH() == true) {
      ypKingsHillPlacer(0.7-rmXTilesToFraction(15), 0.7-rmXTilesToFraction(15), 0.05, 0);
	}


// Island Cliffs
int eastIslandCliffs = rmCreateArea ("east island cliffs");
rmSetAreaSize(eastIslandCliffs, 0.07, 0.07);
rmSetAreaLocation(eastIslandCliffs, 0.6, 0.2);
rmSetAreaCoherence(eastIslandCliffs, 0.6);
rmSetAreaMinBlobs(eastIslandCliffs, 8);
rmSetAreaMaxBlobs(eastIslandCliffs, 12);
rmSetAreaMinBlobDistance(eastIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(eastIslandCliffs, 10.0);
rmSetAreaSmoothDistance(eastIslandCliffs, 15);
rmSetAreaCliffType(eastIslandCliffs, "Africa Desert Grass");
rmSetAreaCliffEdge(eastIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(eastIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(eastIslandCliffs, "Africa Desert Grass");
rmSetAreaBaseHeight(eastIslandCliffs, 2.2);
rmAddAreaConstraint(eastIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(eastIslandCliffs, westIslandCliffConstraint);
rmAddAreaConstraint(eastIslandCliffs, portSiteConstraint);
rmSetAreaElevationType(eastIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(eastIslandCliffs, 3.0);
rmSetAreaElevationPersistence(eastIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(eastIslandCliffs, 1);
rmAddAreaInfluenceSegment(eastIslandCliffs, 0.5, 0.2, 0.65, 0.45);

int westIslandCliffs = rmCreateArea ("west Island cliffs");
rmSetAreaSize(westIslandCliffs, 0.07, 0.07);
rmSetAreaLocation(westIslandCliffs, 0.2, 0.6);
rmSetAreaCoherence(westIslandCliffs, 0.6);
rmSetAreaMinBlobs(westIslandCliffs, 8);
rmSetAreaMaxBlobs(westIslandCliffs, 12);
rmSetAreaMinBlobDistance(westIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(westIslandCliffs, 10.0);
rmSetAreaSmoothDistance(westIslandCliffs, 15);
rmSetAreaCliffType(westIslandCliffs, "Africa Desert Grass");
rmSetAreaCliffEdge(westIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(westIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(westIslandCliffs, "Africa Desert Grass");
rmSetAreaBaseHeight(westIslandCliffs, 2.2);
rmAddAreaConstraint(westIslandCliffs, islandAvoidTradeRoute);
rmAddAreaConstraint(westIslandCliffs, eastIslandCliffConstraint);
rmAddAreaConstraint(westIslandCliffs, portSiteConstraint);
rmSetAreaElevationType(westIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(westIslandCliffs, 3.0);
rmSetAreaElevationPersistence(westIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(westIslandCliffs, 1);
rmAddAreaInfluenceSegment(westIslandCliffs, 0.2, 0.5, 0.45, 0.65);

int northIslandCliffs = rmCreateArea ("north island cliffs");
rmSetAreaSize(northIslandCliffs, 0.15, 0.15);
rmSetAreaLocation(northIslandCliffs, 0.9, 0.9);
rmSetAreaCoherence(northIslandCliffs, 0.6);
rmSetAreaMinBlobs(northIslandCliffs, 8);
rmSetAreaMaxBlobs(northIslandCliffs, 12);
rmSetAreaMinBlobDistance(northIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(northIslandCliffs, 10.0);
rmSetAreaSmoothDistance(northIslandCliffs, 15);
rmSetAreaCliffType(northIslandCliffs, "Africa Desert Grass");
rmSetAreaCliffEdge(northIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(northIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(northIslandCliffs, "Africa Desert Grass");
rmSetAreaBaseHeight(northIslandCliffs, 2.2);
rmAddAreaConstraint(bonusIslandSouth, islandAvoidTradeRoute);
rmAddAreaConstraint(northIslandCliffs, westIslandCliffConstraint);
rmAddAreaConstraint(northIslandCliffs, eastIslandCliffConstraint);
rmSetAreaElevationType(northIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(northIslandCliffs, 3.0);
rmSetAreaElevationPersistence(northIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(northIslandCliffs, 1);

/*int southIslandCliffs = rmCreateArea ("south island cliffs");
rmSetAreaSize(southIslandCliffs, 0.07, 0.07);
rmSetAreaLocation(southIslandCliffs, 0.1, 0.1);
rmSetAreaCoherence(southIslandCliffs, 0.6);
rmSetAreaMinBlobs(southIslandCliffs, 8);
rmSetAreaMaxBlobs(southIslandCliffs, 12);
rmSetAreaMinBlobDistance(southIslandCliffs, 8.0);
rmSetAreaMaxBlobDistance(southIslandCliffs, 10.0);
rmSetAreaSmoothDistance(southIslandCliffs, 15);
rmSetAreaCliffType(southIslandCliffs, "Africa Desert");
rmSetAreaCliffEdge(southIslandCliffs, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(southIslandCliffs, 3.2, 0.0, 0.5);
rmSetAreaMix(southIslandCliffs, "Africa Desert");
rmSetAreaBaseHeight(southIslandCliffs, 2.2);
rmAddAreaConstraint(southIslandCliffs, islandAvoidTradeRouteShort);
rmAddAreaConstraint(southIslandCliffs, westIslandCliffConstraint);
rmAddAreaConstraint(southIslandCliffs, eastIslandCliffConstraint);
rmSetAreaElevationType(southIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(southIslandCliffs, 3.0);
rmSetAreaElevationPersistence(southIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(southIslandCliffs, 1);*/


rmBuildAllAreas();

// North Island Mountains

int northIslandMountains = rmCreateArea ("north island mountains");
rmSetAreaSize(northIslandMountains, 0.08, 0.08);
rmSetAreaLocation(northIslandMountains, 0.9, 0.9);
rmSetAreaCoherence(northIslandMountains, 0.6);
rmSetAreaMinBlobs(northIslandMountains, 8);
rmSetAreaMaxBlobs(northIslandMountains, 25);
rmSetAreaMinBlobDistance(northIslandMountains, 2.0);
rmSetAreaMaxBlobDistance(northIslandMountains, 5.0);
rmSetAreaSmoothDistance(northIslandMountains, 5);
rmSetAreaCliffType(northIslandMountains, "Africa Desert Grass");
rmSetAreaCliffEdge(northIslandMountains, 1, 1.0, 0.0, 1.0, 0);
rmSetAreaCliffHeight(northIslandMountains, 7.2, 0.0, 0.0);
rmSetAreaMix(northIslandMountains, "Africa Desert Grass dirt");
rmSetAreaBaseHeight(northIslandMountains, 7.2);
rmAddAreaConstraint(northIslandMountains, portSiteConstraint);
rmAddAreaConstraint(northIslandMountains, islandAvoidTradeRouteMedium);
rmSetAreaElevationType(northIslandMountains, cElevTurbulence);
rmSetAreaElevationVariation(northIslandMountains, 5.0);
rmSetAreaElevationPersistence(northIslandMountains, 0.2);
rmSetAreaElevationNoiseBias(northIslandMountains, 1);
rmAddAreaToClass(northIslandMountains, classMountains);

rmBuildAllAreas();

// Text
	rmSetStatusText("",0.20);


// east island Cliffs
/*int eastIslandCliffs = rmCreateArea ("east island cliffs");
rmSetAreaSize(eastIslandCliffs, 0.02, 0.02);
rmSetAreaLocation(eastIslandCliffs, 0.6, 0.2);
rmSetAreaCoherence(eastIslandCliffs, 1.0);
rmSetAreaMix(eastIslandCliffs, "Africa Desert Grass medium");
rmSetAreaCliffType(eastIslandCliffs, "Africa Desert Grass");
rmSetAreaBaseHeight(eastIslandCliffs, 8.2);
rmSetAreaElevationType(eastIslandCliffs, cElevTurbulence);
rmSetAreaElevationVariation(eastIslandCliffs, 0.0);
rmSetAreaElevationPersistence(eastIslandCliffs, 0.2);
rmSetAreaElevationNoiseBias(eastIslandCliffs, 1);*/


// add island constraints
   int eastIslandConstraint=rmCreateAreaConstraint("east island", eastIsland);
   int westIslandConstraint=rmCreateAreaConstraint("west Island", westIsland);
   int bonusIslandNorthConstraint=rmCreateAreaConstraint("north Island", bonusIslandNorth);
   int bonusIslandSouthConstraint=rmCreateAreaConstraint("south Island", bonusIslandSouth);


// Place Pirates

   

   // Pirate Village 1
      if (subCiv2 == rmGetCivID("natpirates"))
      {  
         int piratesVillageID = -1;
         piratesVillageID = rmCreateGrouping("pirate city", "pirate_village03");      
         rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

         int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
         rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
         rmAddClosestPointConstraint(villageEdgeConstraint);
         rmAddClosestPointConstraint(flagLand);

         vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

         rmClearClosestPointConstraints();

         int pirateportID1 = -1;
         pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport03");
         rmAddClosestPointConstraint(villageEdgeConstraint);
         rmAddClosestPointConstraint(portOnShore);

         vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
         rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
         
         rmClearClosestPointConstraints();

         
      
      }

      // Pirate Village 2
      if (cNumberNonGaiaPlayers >= 4){
         if (subCiv2 == rmGetCivID("natpirates"))
         {  
            int piratesVillageID2 = -1;
            int piratesVillage2Type = rmRandInt(1,2);
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




// Place ports
   // Port 1

   int portID01 = rmCreateObjectDef("port 01");
   portID01 = rmCreateGrouping("portG 01", "harbour_malta_01");
   rmPlaceGroupingAtLoc(portID01, 0, 0.4+rmXTilesToFraction(7), 0.1);

   // Port 2
   int portID02 = rmCreateObjectDef("port 02");
   portID02 = rmCreateGrouping("portG 02", "harbour_malta_03");
   rmPlaceGroupingAtLoc(portID02, 0, 0.8+rmXTilesToFraction(9), 0.5-rmXTilesToFraction(19));

   // Port 3
   int portID03 = rmCreateObjectDef("port 03");
   portID03 = rmCreateGrouping("portG 03", "harbour_malta_02");
   rmPlaceGroupingAtLoc(portID03, 0, 0.1, 0.4+rmZTilesToFraction(6));

   // Port 4
   int portID04 = rmCreateObjectDef("port 04");
   portID04 = rmCreateGrouping("portG 04", "harbour_malta_03");
   rmPlaceGroupingAtLoc(portID04, 0, 0.5-rmXTilesToFraction(19), 0.8+rmXTilesToFraction(9));

   // Port 5
   int portID05 = rmCreateObjectDef("port 05");
   portID05 = rmCreateGrouping("portG 05", "harbour_malta_04");
   rmPlaceGroupingAtLoc(portID05, 0, 0.55+rmXTilesToFraction(10), 0.55+rmXTilesToFraction(9));

// Text
	rmSetStatusText("",0.30);

// Place Caribs

   // Lonely Caribs
   //if (subCiv3 == rmGetCivID("caribs"))


   // Team Maltese East
   if (subCiv1 == rmGetCivID("maltese"))
   {  
      int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID, eastIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.5, 0.5);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));

      int eastIslandVillage1 = rmCreateArea ("east island village 1");
      int eastIslandVillage2 = rmCreateArea ("east island village 2");
      int eastIslandVillage5 = rmCreateArea ("east island village 5");
      int eastIslandVillage6 = rmCreateArea ("east island village 6");

      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaCliffType(eastIslandVillage1, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage1, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage1, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage1, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmBuildArea(eastIslandVillage1);


      int maltese2VillageID = -1;
      int maltese2VillageType = rmRandInt(1,5);
      int maltese3VillageType = rmRandInt(1,5);
      int maltese1VillageType = rmRandInt(1,5);
      int maltese4VillageType = rmRandInt(1,5);
      int maltese5VillageType = rmRandInt(1,5);
      int maltese6VillageType = rmRandInt(1,5);

      maltese2VillageID = rmCreateGrouping("maltese2 city", "Maltese_Village0"+maltese2VillageType);
      rmAddGroupingConstraint(maltese2VillageID, avoidImpassableLand);

      if (cNumberNonGaiaPlayers <= 3){
      rmPlaceGroupingAtLoc(maltese2VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);
      }


      else {
      rmPlaceGroupingAtLoc(maltese2VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);
      
      int malteseControllerID2 = rmCreateObjectDef("maltese controller 2");
      rmAddObjectDefItem(malteseControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID2, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID2, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID2, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID2, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID2, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID2, eastIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.5, 0.5);
      vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));

      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      rmSetAreaCliffType(eastIslandVillage2, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage2, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage2, 1.0, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage2, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmBuildArea(eastIslandVillage2);

      int maltese3VillageID = -1;

      maltese3VillageID = rmCreateGrouping("maltese3 city", "Maltese_Village0"+maltese3VillageType);
      rmAddGroupingConstraint(maltese3VillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(maltese3VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);

      }

      if (cNumberNonGaiaPlayers >= 6){
       int malteseControllerID5 = rmCreateObjectDef("maltese controller 5");
      rmAddObjectDefItem(malteseControllerID5, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID5, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID5, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID5, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID5, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID5, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID5, eastIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID5, 0, 0.5, 0.5);
      vector malteseControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID5, 0));

      rmSetAreaSize(eastIslandVillage5, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage5, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)));
      rmSetAreaCoherence(eastIslandVillage5, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage5, 5);
      rmSetAreaCliffType(eastIslandVillage5, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage5, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage5, 1.0, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage5, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage5, 0.0);
      rmBuildArea(eastIslandVillage5);

      int maltese5VillageID = -1;

      maltese5VillageID = rmCreateGrouping("maltese5 city", "Maltese_Village0"+maltese5VillageType);
      rmAddGroupingConstraint(maltese5VillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(maltese5VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)), 1);
      }
   }

   // Team Maltese West
   if (subCiv0 == rmGetCivID("maltese"))
   {  
      int malteseControllerID3 = rmCreateObjectDef("maltese controller 3");
      rmAddObjectDefItem(malteseControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID3, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID3, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID3, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID3, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID3, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID3, westIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.5, 0.5);
      vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));

      int eastIslandVillage3 = rmCreateArea ("east island village 3");
      int eastIslandVillage4 = rmCreateArea ("east island village 4");

      rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage3, 5);
      rmSetAreaCliffType(eastIslandVillage3, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage3, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage3, 1.0, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage3, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
      rmBuildArea(eastIslandVillage3);

      int maltese1VillageID = -1;
      maltese1VillageID = rmCreateGrouping("maltese1 city", "Maltese_Village0"+maltese1VillageType);
      rmAddGroupingConstraint(maltese1VillageID, avoidImpassableLand);
            
      if (cNumberNonGaiaPlayers <= 3){
      rmPlaceGroupingAtLoc(maltese1VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);
      }

      else {
      rmPlaceGroupingAtLoc(maltese1VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);

      int malteseControllerID4 = rmCreateObjectDef("maltese controller 4");
      rmAddObjectDefItem(malteseControllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID4, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID4, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID4, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID4, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID4, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID4, westIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.5, 0.5);
      vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));

      rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
      rmSetAreaCoherence(eastIslandVillage4, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage4, 5);
      rmSetAreaCliffType(eastIslandVillage4, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage4, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage4, 1.0, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage4, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
      rmBuildArea(eastIslandVillage4);
      
      int maltese4VillageID = -1;
      maltese4VillageID = rmCreateGrouping("maltese4 city", "Maltese_Village0"+maltese4VillageType);
      rmAddGroupingConstraint(maltese4VillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(maltese4VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);
      }

      if (cNumberNonGaiaPlayers >= 6){
       int malteseControllerID6 = rmCreateObjectDef("maltese controller 6");
      rmAddObjectDefItem(malteseControllerID6, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID6, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID6, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID6, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID6, avoidWater70);
      rmAddObjectDefConstraint(malteseControllerID6, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID6, westIslandConstraint); 
      rmPlaceObjectDefAtLoc(malteseControllerID6, 0, 0.5, 0.5);
      vector malteseControllerLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID6, 0));

      rmSetAreaSize(eastIslandVillage6, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
      rmSetAreaLocation(eastIslandVillage6, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)));
      rmSetAreaCoherence(eastIslandVillage6, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage6, 5);
      rmSetAreaCliffType(eastIslandVillage6, "ZP Malta Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage6, 1, 0.8, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage6, 1.0, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage6, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage6, 0.0);
      rmBuildArea(eastIslandVillage6);

      int maltese6VillageID = -1;

      maltese6VillageID = rmCreateGrouping("maltese6 city", "Maltese_Village0"+maltese6VillageType);
      rmAddGroupingConstraint(maltese6VillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(maltese6VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)), 1);
      }
      
   } 


// Bonus Bourbon
   /*if (subCiv3 == rmGetCivID("bourbon"))
   {  
		int bourbonVillageID = -1;
		int bourbonVillageType = rmRandInt(1,5);
      bourbonVillageID = rmCreateGrouping("bourbon1 city", "european/native eu bourbon village italian "+bourbonVillageType);
      rmSetGroupingMinDistance(bourbonVillageID, 500);
      rmSetGroupingMaxDistance(bourbonVillageID, rmXFractionToMeters(0.3));
		rmAddGroupingConstraint(bourbonVillageID, avoidTeamIslands);
		rmAddGroupingConstraint(bourbonVillageID, avoidImpassableLand);
      rmAddGroupingConstraint(bourbonVillageID, playerEdgeConstraint);      
      rmAddGroupingConstraint(bourbonVillageID, avoidSocketLong);
      rmAddGroupingConstraint(bourbonVillageID, avoidMountains);

		rmPlaceGroupingInArea(bourbonVillageID, 0, bonusIslandNorth, 1);

   }

   if (subCiv3 == rmGetCivID("bourbon"))
   {  
		int bourbon2VillageID = -1;
		int bourbon2VillageType = rmRandInt(1,5);
      bourbon2VillageID = rmCreateGrouping("bourbon2 city", "european/native eu bourbon village italian "+bourbon2VillageType);
      rmSetGroupingMinDistance(bourbon2VillageID, 500);
      rmSetGroupingMaxDistance(bourbon2VillageID, rmXFractionToMeters(0.3));
		rmAddGroupingConstraint(bourbon2VillageID, avoidTeamIslands);
		rmAddGroupingConstraint(bourbon2VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(bourbon2VillageID, playerEdgeConstraint);      
      rmAddGroupingConstraint(bourbon2VillageID, avoidSocketLong);
      rmAddGroupingConstraint(bourbon2VillageID, avoidMountains);

		rmPlaceGroupingInArea(bourbon2VillageID, 0, bonusIslandNorth, 1);

   }*/


// Text
	rmSetStatusText("",0.40);

// Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.40, 0.00);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.2, 0.3, 0);
		}
		else
		{
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.40, 0.55);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.75, 0.90);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.75, 0.90);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.40, 0.55);
				rmPlacePlayersCircular(0.20, 0.30, rmDegreesToRadians(5.0));
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
   int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "mineSalt", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
   rmAddObjectDefConstraint(playerMineID, avoidImpassableLand); 

   int playerDeerID=rmCreateObjectDef("player deer");
   rmAddObjectDefItem(playerDeerID, "ypibex", rmRandInt(10,15), 10.0);
   rmSetObjectDefMinDistance(playerDeerID, 15.0);
   rmSetObjectDefMaxDistance(playerDeerID, 30.0);
   rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(playerDeerID, true);

rmAddObjectDefConstraint(TCID, avoidTownCenter);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, playersAwayPort);
rmAddObjectDefConstraint(TCID, avoidSocketLong);
rmAddObjectDefConstraint(TCID, avoidBonusIslands);


  

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
   rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
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

   int mineType = -1;
	int mineID = -1;
	int mineCount = (cNumberNonGaiaPlayers*0.75);
	rmEchoInfo("mine count = "+mineCount);

	for(i=0; < mineCount)
	{
	  int westmineID = rmCreateObjectDef("west mine "+i);
	  rmAddObjectDefItem(westmineID, "mineSalt", 1, 0.0);
      rmSetObjectDefMinDistance(westmineID, 0.0);
      rmSetObjectDefMaxDistance(westmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(westmineID, avoidCoin);
      rmAddObjectDefConstraint(westmineID, avoidAll);
      rmAddObjectDefConstraint(westmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(westmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(westmineID, westIslandConstraint);
	  rmPlaceObjectDefAtLoc(westmineID, 0, 0.5, 0.5);
   }

   for(i=0; < mineCount)
	{
	  int eastmineID = rmCreateObjectDef("east mine "+i);
	  rmAddObjectDefItem(eastmineID, "mineSalt", 1, 0.0);
      rmSetObjectDefMinDistance(eastmineID, 0.0);
      rmSetObjectDefMaxDistance(eastmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(eastmineID, avoidCoin);
      rmAddObjectDefConstraint(eastmineID, avoidAll);
      rmAddObjectDefConstraint(eastmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(eastmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(eastmineID, eastIslandConstraint);
	  rmPlaceObjectDefAtLoc(eastmineID, 0, 0.5, 0.5);
   } 
	
   for(i=0; < 4)
	{
	  int northmineID = rmCreateObjectDef("bonus mine "+i);
	  rmAddObjectDefItem(northmineID, "mineSalt", 1, 0.0);
      rmSetObjectDefMinDistance(northmineID, 0.0);
      rmSetObjectDefMaxDistance(northmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(northmineID, avoidCoin);
      rmAddObjectDefConstraint(northmineID, avoidAll);
      rmAddObjectDefConstraint(northmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(northmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(northmineID, bonusIslandNorthConstraint);
      rmAddObjectDefConstraint(northmineID, avoidMountains);
      rmAddObjectDefConstraint(northmineID, ObjectAvoidTradeRoute);
	  rmPlaceObjectDefAtLoc(northmineID, 0, 0.5, 0.5);
   } 

	  int southmineID = rmCreateObjectDef("bonus mine "+i);
	  rmAddObjectDefItem(southmineID, "deShipRuins", 1, 0.0);
      rmSetObjectDefMinDistance(southmineID, 0.0);
      rmSetObjectDefMaxDistance(southmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(southmineID, avoidCoin);
      rmAddObjectDefConstraint(southmineID, avoidAll);
      rmAddObjectDefConstraint(southmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(southmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(southmineID, bonusIslandSouthConstraint);
	  rmPlaceObjectDefAtLoc(southmineID, 0, 0.5, 0.5);

   // Text
	rmSetStatusText("",0.60);

// FORESTS
 int forestTreeID = 0;
  int numTries=8*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest, "z31 Mediterranean Coastal Forest");
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
    rmAddAreaConstraint(forest, avoidDesertIslands);
    rmAddAreaConstraint(forest, avoidMountains);
    rmAddAreaConstraint(forest, shortAvoidImpassableLand);
    rmAddAreaConstraint(forest, ObjectAvoidTradeRouteShort);
    if(rmBuildArea(forest)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount++;
      
      if(failCount==5)
        break;
    }

   else
         failCount=0; 
   } 

  for (i=0; <numTries/4) {   
    int forest2=rmCreateArea("forest2 "+i);
    rmSetAreaWarnFailure(forest2, false);
    rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest2, "Af Tassili Forest");
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
    rmAddAreaConstraint(forest2, bonusIslandSouthConstraint);
    rmAddAreaConstraint(forest2, avoidMountains);
    rmAddAreaConstraint(forest2, shortAvoidImpassableLand);
    rmAddAreaConstraint(forest2, ObjectAvoidTradeRouteShort);
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
	rmPlaceObjectDefInArea(nuggetNorth, 0, eastIsland, cNumberNonGaiaPlayers);

   int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouth, avoidAll);
	rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, westIsland, cNumberNonGaiaPlayers);


	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget2, avoidNugget);
  	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidTCshort);
  	rmAddObjectDefConstraint(nugget2, avoidWater4);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bonusIslandSouth, cNumberNonGaiaPlayers/2);

   int nugget3= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 3);
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget3, avoidNugget);
  	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidTCshort);
  	rmAddObjectDefConstraint(nugget3, avoidWater4);
	rmAddObjectDefConstraint(nugget3, playerEdgeConstraint);
   rmAddObjectDefConstraint(nugget3, avoidMountains);
   rmAddObjectDefConstraint(nugget3, ObjectAvoidTradeRoute);
	rmPlaceObjectDefInArea(nugget3, 0, bonusIslandNorth, cNumberNonGaiaPlayers);


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
   int deerID=rmCreateObjectDef("ibex herd");
	int bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(deerID, "ypibex", rmRandInt(4,6), 10.0);
   else
      rmAddObjectDefItem(deerID, "ypibex", rmRandInt(8,10), 10.0);
   rmSetObjectDefMinDistance(deerID, 0.0);
   rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
   rmAddObjectDefConstraint(deerID, avoidImpassableLand);
   rmAddObjectDefConstraint(deerID, avoidMountains);
   rmAddObjectDefConstraint(deerID, ObjectAvoidTradeRouteShort);
   rmSetObjectDefCreateHerd(deerID, true);
   rmPlaceObjectDefInArea(deerID, 0, eastIsland, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, westIsland, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, bonusIslandNorth, cNumberNonGaiaPlayers);
   rmPlaceObjectDefInArea(deerID, 0, bonusIslandSouth, 1);
   // Text
	rmSetStatusText("",0.90);

//Fishes

   int fishID=rmCreateObjectDef("fish Salmon");
   rmAddObjectDefItem(fishID, "FishSalmon", 1, 0.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 30*cNumberNonGaiaPlayers);

   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // RANDOM TREES
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeTexas", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidMountains);
   rmAddObjectDefConstraint(randomTreeID, avoidDesertIslands);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 
   rmAddObjectDefConstraint(randomTreeID, ObjectAvoidTradeRouteShort);

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 13*cNumberNonGaiaPlayers);

   int randomTree2ID=rmCreateObjectDef("random tree 2");
   rmAddObjectDefItem(randomTree2ID, "deTreeSaharanCypress", 1, 0.0);
   rmSetObjectDefMinDistance(randomTree2ID, 0.0);
   rmSetObjectDefMaxDistance(randomTree2ID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTree2ID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTree2ID, avoidMountains);
   rmAddObjectDefConstraint(randomTree2ID, bonusIslandSouthConstraint);
   rmAddObjectDefConstraint(randomTree2ID, avoidAll); 
   rmAddObjectDefConstraint(randomTree2ID, ObjectAvoidTradeRouteShort);

   rmPlaceObjectDefAtLoc(randomTree2ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

    // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "TreeTexas", 1, 0.0);
   rmAddObjectDefConstraint(villageTreeID, ObjectAvoidTradeRouteShort);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage1, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage2, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage3, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage4, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage5, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage6, 7);


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
rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Europen Map
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


for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Activate Maltese"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpMalteseCross"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffMaltese"); //operator
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
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
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
   rmSetTriggerConditionParam("DstObject","66");
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
rmSetTriggerConditionParam("DstObject","9");
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
   rmSetTriggerConditionParam("DstObject","66");
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
   rmSetTriggerConditionParam("DstObject","66");
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
   rmSetTriggerConditionParam("DstObject","66");
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
   rmSetTriggerConditionParam("DstObject","9");
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
   rmSetTriggerConditionParam("DstObject","9");
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
   rmSetTriggerConditionParam("DstObject","9");
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
rmSetTriggerConditionParam("DstObject","9");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","9");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
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
rmSetTriggerConditionParam("DstObject","9");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","9");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
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
   rmSetTriggerConditionParam("DstObject","66");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","66");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
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
   rmSetTriggerConditionParam("DstObject","66");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","66");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
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

// AI Maltese Fractions

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
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseVenetians"); //operator
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
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",527);
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