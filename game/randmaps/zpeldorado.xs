// AZTEC GOLD v2.0

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
   int subCiv3=-1;

   if (rmAllocateSubCivs(3) == true)
   {
		subCiv0=rmGetCivID("zpscientists");
      rmEchoInfo("subCiv0 is zpscientists "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "zpscientists");

      subCiv1=rmGetCivID("aztecs");
      rmEchoInfo("subCiv1 is caribs "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "aztecs");
  
		subCiv2=rmGetCivID("aztecs");
		rmEchoInfo("subCiv2 is caribs "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "aztecs");

      subCiv3=rmGetCivID("aztecs");
		rmEchoInfo("subCiv3 is caribs "+subCiv3);
		if (subCiv3 >= 0)
				rmSetSubCiv(3, "aztecs");
	}

   // Picks the map size
	int playerTiles = 21000;
   if (cNumberNonGaiaPlayers >2)
		playerTiles = 17500;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 15500;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 13500;			

   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

	rmSetWindMagnitude(2);

   // Picks a default water height
   rmSetSeaLevel(0.0);

   // Picks default terrain and water
	//	rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)
//	rmSetMapElevationParameters(cElevTurbulence, 0.04, 4, 0.4, 6.0);
//	rmAddMapTerrainByHeightInfo("amazon\ground2_am", 8.0, 10.0);
//	rmAddMapTerrainByHeightInfo("amazon\ground1_am", 10.0, 16.0);
//   rmSetSeaType("Amazon River");
	rmSetSeaType("ZP Mexico River");
 	rmSetBaseTerrainMix("texas grass");
	rmSetMapType("mexico");
	rmSetMapType("desert");
	rmSetMapType("water");
   rmSetMapType("eldorado");
	rmSetWorldCircleConstraint(true);
   rmSetLightingSet("Mexico_Skirmish");
   rmSetOceanReveal(true);

   // Init map.
   rmTerrainInitialize("water");

	chooseMercs();


   
//			rmPaintAreaTerrainByHeight(elevID, "Amazon\ground1_am", 11, 14, 1);
//		rmPaintAreaTerrainByHeight(elevID, "Amazon\ground2_am", 10, 11, 1);
//		rmPaintAreaTerrainByHeight(elevID, "Amazon\ground3_am", 8, 10);

   // Define some classes. These are used later for constraints.
   int classPlayer=rmDefineClass("player");
   rmDefineClass("starting settlement");
   rmDefineClass("socketClass");
   rmDefineClass("startingUnit");
   rmDefineClass("classForest");
   rmDefineClass("classCliff");
   rmDefineClass("importantItem");
   int classNative=rmDefineClass("natives");
   int classIsland=rmDefineClass("island");
   int classBonusIsland=rmDefineClass("bonus island");
   int classTeamIsland=rmDefineClass("team Island");
   int classPlayerArea=rmDefineClass("player area");
   int classMountains=rmDefineClass("mountains");
   string baseMix = "texas_grass";


   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
      int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.46), rmDegreesToRadians(0), rmDegreesToRadians(360));
      int villageEdgeConstraint=rmCreatePieConstraint("village edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
      int villageEdgeConstraintFar=rmCreatePieConstraint("village edge far of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.37), rmDegreesToRadians(0), rmDegreesToRadians(360));

  // int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(6), rmZTilesToFraction(6), 1.0-rmXTilesToFraction(6), 1.0-rmZTilesToFraction(6), 0.01);
//   int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 24.0);

   // Cardinal Directions
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.55, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.45, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.45, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.55, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

   // Player constraints
   int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 30.0);
   int shipVsShip=rmCreateTypeDistanceConstraint("ships avoid ship", "ship", 20.0);
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 15.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 20);
   int flagVsPirate1 = rmCreateTypeDistanceConstraint("flag avoid pirate flag 1", "zpPirateWaterSpawnFlag1", 20);
   int flagVsPirate2 = rmCreateTypeDistanceConstraint("flag avoid pirate flag 2", "zpPirateWaterSpawnFlag2", 20);
   int flagEdgeConstraint = rmCreatePieConstraint("flags stay near edge of map", 0.5, 0.5, rmGetMapXSize()-180, rmGetMapXSize()-40, 0, 0, 0);
   int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 10.0);
   int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48+cNumberNonGaiaPlayers);

   int avoidBonusIsland=rmCreateClassDistanceConstraint("avoid bonus island", classBonusIsland, 44+2*cNumberNonGaiaPlayers);
   int avoidTeamIsland=rmCreateClassDistanceConstraint("avoid team island", classTeamIsland, 48+cNumberNonGaiaPlayers);
   int avoidPlayerArea=rmCreateClassDistanceConstraint("avoid player area", classPlayerArea, 5);

   int islandConstraintShort=rmCreateClassDistanceConstraint("islands avoid each other short", classIsland, 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("avoid natives", classNative, 8.0);
   int avoidNativesFar=rmCreateClassDistanceConstraint("avoid natives far", classNative, 32.0);
   int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 45.0);
   int shortAvoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units short", rmClassID("startingUnit"), 10.0);
   int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "SocketTradeRoute", 8.0);

//   int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
 
    // Nature avoidance
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
   int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
   int avoidCopper=rmCreateTypeDistanceConstraint("avoid copper", "minecopper", 30.0);
   int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minegold", 30.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 60.0);
   int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 20.0);
   int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
   int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
   int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 25.0);
   // Constraint to avoid water.
   int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 20.0);
   int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water large 2", "Land", false, 30.0);
   int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water large 3", "Land", false, 40.0);
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 20.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 7);

   // Unit avoidance
   int avoidImportantItem=rmCreateClassDistanceConstraint("avoid natives, secrets", rmClassID("importantItem"), 30.0);
   int farAvoidImportantItem=rmCreateClassDistanceConstraint("secrets avoid each other by a lot", rmClassID("importantItem"), 50.0);
   int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 25.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
   int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 12.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidCliff=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);

     // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 5.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 15.0);
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route island", 10.0);
   int islandAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route island short", 4.0);
   int islandAvoidTradeRouteLong = rmCreateTradeRouteDistanceConstraint("trade route island long", 10+2*cNumberNonGaiaPlayers);

    int tpPlacedIn1v1 = rmRandInt(0,1);
   //tpPlacedIn1v1=0;//DEBUG
    
     //dk
    int avoidAll_dk=rmCreateTypeDistanceConstraint("avoid all_dk", "all", 3.0);
    int avoidWater5_dk = rmCreateTerrainDistanceConstraint("avoid water long_dk", "Land", false, 15.0);
    int avoidSocket2_dk=rmCreateClassDistanceConstraint("socket avoidance gold_dk", rmClassID("socketClass"), 4.0);
    int avoidTradeRouteSmall_dk = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small_dk", 2.0);
    int forestConstraintShort_dk=rmCreateClassDistanceConstraint("object vs. forest_dk", rmClassID("classForest"), 2.0);
    int avoidHunt2_dk=rmCreateTypeDistanceConstraint("herds avoid herds2_dk", "huntable", 22.0);
    int avoidHunt3_dk=rmCreateTypeDistanceConstraint("herds avoid herds3_dk", "huntable", 18.0);
	int avoidAll2_dk=rmCreateTypeDistanceConstraint("avoid all2_dk", "all", 3.0);
    int avoidGoldTypeFar_dk = rmCreateTypeDistanceConstraint("avoid gold type  far 2_dk", "mine", 21.0);
    int circleConstraint2_dk=rmCreatePieConstraint("circle Constraint2_dk", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidMineForest_dk=rmCreateTypeDistanceConstraint("avoid mines forest _dk", "mine", 9.0);
    int avoidCow_dk=rmCreateTypeDistanceConstraint("cow avoids cow dk", "cow", 32.0);
    int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "Socket", 20.0);
    int avoidSocket2=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 40.0);
    int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 60.0);
    int avoidScientists=rmCreateTypeDistanceConstraint("stay away from Scientists", "zpSocketScientists", 70+6.5*cNumberNonGaiaPlayers);
    int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);

   // -------------Define objects
   // These objects are all defined so they can be placed later

    // Text
   rmSetStatusText("",0.10);


 	// --------------------------- Place players ----------------------------- //
   

      int teamZeroCount = rmGetNumberPlayersOnTeam(0);
      int teamOneCount = rmGetNumberPlayersOnTeam(1);
      float teamStartLoc = rmRandFloat(0.0, 1.0);

      if(cNumberNonGaiaPlayers <= 2){
         rmSetTeamSpacingModifier(1.0);
         rmSetPlacementSection(0.69, 0.5); // 0.5
         rmPlacePlayersCircular(0.44, 0.44, 0);	
      }	

      else {
         rmSetTeamSpacingModifier(1.0);
         rmSetPlacementSection(0.60, 0.16); // 0.5
         rmPlacePlayersCircular(0.44, 0.44, 0);		
      }
      
   // --------------------------------  Water Trade Route  ------------------------------//

   int tradeRouteID = rmCreateTradeRoute();

   rmSetObjectDefTradeRouteID(tradeRouteID);   
   //rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.45);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.6);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.75, 0.75);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.85);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.75);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.15, 0.5);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.25, 0.25);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.1);
   //rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.0);

   bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "native_water_trail");

   // ---------------------------- Place Terrain ---------------------------------------//

      // Native Island
      
      int bigIslandID = rmCreateArea("migration island");

      rmSetAreaLocation(bigIslandID, 0.5, 0.5);
      rmSetAreaMix(bigIslandID, "yucatan_grass");
      rmSetAreaCoherence(bigIslandID, 0.9);
      rmSetAreaSize(bigIslandID, 0.4, 0.4);
      rmSetAreaMinBlobs(bigIslandID, 10);
      rmSetAreaMaxBlobs(bigIslandID, 15);
      rmSetAreaMinBlobDistance(bigIslandID, 8.0);
      rmSetAreaMaxBlobDistance(bigIslandID, 10.0);
      rmSetAreaBaseHeight(bigIslandID, 1.0);
      rmSetAreaSmoothDistance(bigIslandID, 20);
      rmSetAreaMix(bigIslandID, "yucatan_grass");
         rmAddAreaTerrainLayer(bigIslandID, "Amazon\ground5_ama", 0, 4);
         rmAddAreaTerrainLayer(bigIslandID, "Amazon\ground4_ama", 4, 6);
         rmAddAreaTerrainLayer(bigIslandID, "Amazon\ground3_ama", 6, 9);
         rmAddAreaTerrainLayer(bigIslandID, "Amazon\ground2_ama", 9, 12);
      rmAddAreaToClass(bigIslandID, classIsland);
      rmAddAreaToClass(bigIslandID, classBonusIsland);
      rmAddAreaConstraint(bigIslandID, islandConstraint);
      rmAddAreaConstraint(bigIslandID, islandAvoidTradeRouteLong);
      rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
      rmSetAreaElevationType(bigIslandID, cElevTurbulence);
      rmSetAreaElevationVariation(bigIslandID, 2.0);
      rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
      rmSetAreaElevationOctaves(bigIslandID, 3);
      rmSetAreaElevationPersistence(bigIslandID, 0.2);
		rmSetAreaElevationNoiseBias(bigIslandID, 1);
      rmSetAreaWarnFailure(bigIslandID, false);
      rmAddAreaInfluenceSegment(bigIslandID, 0.5, 0.5, 0.8, 0.2);

      rmBuildArea(bigIslandID); 

      // Player Islands

         // North Player Island

         int playerIslandNorth = rmCreateArea("north island");

         rmSetAreaLocation(playerIslandNorth, 0.8, 0.9);
         rmSetAreaCoherence(playerIslandNorth, 1.0);
         rmSetAreaSize(playerIslandNorth, 0.2, 0.2);
         rmSetAreaMinBlobs(playerIslandNorth, 10);
         rmSetAreaMaxBlobs(playerIslandNorth, 15);
         rmSetAreaMinBlobDistance(playerIslandNorth, 8.0);
         rmSetAreaMaxBlobDistance(playerIslandNorth, 10.0);
         rmSetAreaCoherence(playerIslandNorth, 0.60);
         rmSetAreaBaseHeight(playerIslandNorth, 2.0);
         rmSetAreaSmoothDistance(playerIslandNorth, 20);
         rmSetAreaMix(playerIslandNorth, "texas_grass_Skrimish");
            rmAddAreaTerrainLayer(playerIslandNorth, "Texas\ground5_tex", 0, 4);
            rmAddAreaTerrainLayer(playerIslandNorth, "Texas\ground4_tex", 4, 6);
            rmAddAreaTerrainLayer(playerIslandNorth, "Texas\ground3_tex", 6, 9);
         rmAddAreaToClass(playerIslandNorth, classIsland);
         rmAddAreaConstraint(playerIslandNorth, avoidBonusIsland);
         rmAddAreaConstraint(playerIslandNorth, islandAvoidTradeRoute);
         rmSetAreaObeyWorldCircleConstraint(playerIslandNorth, false);
         rmSetAreaWarnFailure(playerIslandNorth, false);
         
         rmBuildArea(playerIslandNorth);

         // South Player Island

         int playerIslandSouth = rmCreateArea("south island");

         rmSetAreaLocation(playerIslandSouth, 0.1, 0.2);
         rmSetAreaCoherence(playerIslandSouth, 1.0);
         rmSetAreaSize(playerIslandSouth, 0.2, 0.2);
         rmSetAreaMinBlobs(playerIslandSouth, 10);
         rmSetAreaMaxBlobs(playerIslandSouth, 15);
         rmSetAreaMinBlobDistance(playerIslandSouth, 8.0);
         rmSetAreaMaxBlobDistance(playerIslandSouth, 10.0);
         rmSetAreaCoherence(playerIslandSouth, 0.60);
         rmSetAreaBaseHeight(playerIslandSouth, 2.0);
         rmSetAreaSmoothDistance(playerIslandSouth, 20);
         rmSetAreaMix(playerIslandSouth, "texas_grass_Skrimish");
            rmAddAreaTerrainLayer(playerIslandSouth, "Texas\ground5_tex", 0, 4);
            rmAddAreaTerrainLayer(playerIslandSouth, "Texas\ground4_tex", 4, 6);
            rmAddAreaTerrainLayer(playerIslandSouth, "Texas\ground3_tex", 6, 9);
         rmAddAreaToClass(playerIslandSouth, classIsland);
         rmAddAreaConstraint(playerIslandSouth, avoidBonusIsland);
         rmAddAreaConstraint(playerIslandSouth, islandAvoidTradeRoute);
         rmSetAreaObeyWorldCircleConstraint(playerIslandSouth, false);
         rmSetAreaWarnFailure(playerIslandSouth, false);

         rmBuildArea(playerIslandSouth);

// ---------------------------- Player Areas -------------------------------------//

   // Player Cells

   /*float playerFraction=rmAreaTilesToFraction(1200);

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
      rmSetAreaMix(id, "yucatan_grass");
      rmAddAreaTerrainLayer(id, "Amazon\ground5_ama", 0, 4);
      rmAddAreaTerrainLayer(id, "Amazon\ground4_ama", 4, 6);
      rmAddAreaTerrainLayer(id, "Amazon\ground3_ama", 6, 9);
      rmAddAreaTerrainLayer(id, "Amazon\ground2_ama", 9, 12);   
      rmSetAreaCoherence(id, 1.00);
      rmSetAreaSmoothDistance(id, 20);
      rmAddAreaToClass(id, classPlayerArea);
      rmAddAreaConstraint(id, islandAvoidTradeRoute);
      rmAddAreaConstraint(id, avoidPlayerArea);
	   rmSetAreaLocPlayer(id, i);
		rmSetAreaWarnFailure(id, false);
		rmBuildArea(id); 
   }*/

   // Insert Players

   int classStartingResource = rmDefineClass("startingResource");
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 12.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 4.0);

   int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));

	int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
		}
		else
		{
         rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
		}
	rmAddObjectDefToClass(startingTCID, classStartingResource);
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	rmSetObjectDefMaxDistance(startingTCID, 0.0);
//	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
//	rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
	rmAddObjectDefToClass(startingTCID, rmClassID("player"));
   rmAddObjectDefConstraint(startingTCID, avoidMountains);
   rmAddObjectDefConstraint(startingTCID, avoidWater10);
   rmAddObjectDefConstraint(startingTCID, playerEdgeConstraint);
   rmAddObjectDefConstraint(startingTCID, avoidTradeSockets);

   rmSetObjectDefMinDistance(startingTCID, 0.0);
	rmSetObjectDefMaxDistance(startingTCID, 14.0);

   // Trees
   int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeSonora", 10, 12);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 30);
	rmAddObjectDefToClass(StartAreaTreeID, classStartingResource);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidStartingUnits);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeSockets);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidWater10);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidMountains);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidTownCenterShort);

   // Huntables
   int playerHerdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerHerdID, "pronghorn", 8, 10.0);
	rmSetObjectDefMinDistance(playerHerdID, 7);
	rmSetObjectDefMaxDistance(playerHerdID, 35);
	rmSetObjectDefCreateHerd(playerHerdID, true);
	rmAddObjectDefToClass(playerHerdID, classStartingResource);
	rmAddObjectDefConstraint(playerHerdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeSockets);
   rmAddObjectDefConstraint(playerHerdID, avoidMountains);

   // Mine
   int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "minecopper", 1, 0.0);
	rmAddObjectDefToClass(startSilverID, classStartingResource);
	rmSetObjectDefMinDistance(startSilverID, 16.0);
	rmSetObjectDefMaxDistance(startSilverID, 25.0);
	//rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);
	rmAddObjectDefConstraint(startSilverID, avoidTradeSockets);
   rmAddObjectDefConstraint(startSilverID, avoidMountains);
   rmAddObjectDefConstraint(startSilverID, avoidTownCenterShort);

   // Starting area nuggets
   int playerNuggetID=rmCreateObjectDef("player nugget");
   rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
   rmSetObjectDefMinDistance(playerNuggetID, 10.0);
   rmSetObjectDefMaxDistance(playerNuggetID, 15.0);
   rmAddObjectDefConstraint(playerNuggetID, avoidAll);
   rmAddObjectDefConstraint(playerNuggetID, avoidMountains);
   rmAddObjectDefConstraint(playerNuggetID, avoidTradeSockets);
   rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);

   // Water Flag
   int waterSpawnFlagID = rmCreateObjectDef("water spawn flag");
	rmAddObjectDefItem(waterSpawnFlagID, "HomeCityWaterSpawnFlag", 1, 0);
   

   // Player Island Cliffs

      // Defining Variables

      int PlayerCliffID1 = rmCreateArea("player island cliff 1");
      int PlayerCliffID2 = rmCreateArea("player island cliff 2");
      int PlayerCliffID3 = rmCreateArea("player island cliff 3");
      int PlayerCliffID4 = rmCreateArea("player island cliff 4");
      int PlayerCliffID5 = rmCreateArea("player island cliff 5");
      int PlayerCliffID6 = rmCreateArea("player island cliff 6");
      int PlayerCliffID7 = rmCreateArea("player island cliff 7");

      float cliffFraction=rmAreaTilesToFraction(2000-cNumberNonGaiaPlayers*150);

      // Setting up Parameters (Cliffs 1-7)

      rmSetAreaSize(PlayerCliffID1, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID1, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID1, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID1, 8.2);
      rmSetAreaCoherence(PlayerCliffID1, 0.7);
      rmAddAreaToClass(PlayerCliffID1, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID1, false);
      rmSetAreaElevationVariation(PlayerCliffID1, 0.0);
      rmAddAreaConstraint(PlayerCliffID1, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID1, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID2, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID2, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID2, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID2, 8.2);
      rmSetAreaCoherence(PlayerCliffID2, 0.7);
      rmAddAreaToClass(PlayerCliffID2, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID2, false);
      rmSetAreaElevationVariation(PlayerCliffID2, 0.0);
      rmAddAreaConstraint(PlayerCliffID2, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID2, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID3, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID3, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID3, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID3, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID3, 8.2);
      rmSetAreaCoherence(PlayerCliffID3, 0.7);
      rmAddAreaToClass(PlayerCliffID3, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID3, false);
      rmSetAreaElevationVariation(PlayerCliffID3, 0.0);
      rmAddAreaConstraint(PlayerCliffID3, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID3, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID4, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID4, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID4, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID4, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID4, 8.2);
      rmSetAreaCoherence(PlayerCliffID4, 0.7);
      rmAddAreaToClass(PlayerCliffID4, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID4, false);
      rmSetAreaElevationVariation(PlayerCliffID4, 0.0);
      rmAddAreaConstraint(PlayerCliffID4, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID4, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID5, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID5, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID5, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID5, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID5, 8.2);
      rmSetAreaCoherence(PlayerCliffID5, 0.7);
      rmAddAreaToClass(PlayerCliffID5, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID5, false);
      rmSetAreaElevationVariation(PlayerCliffID5, 0.0);
      rmAddAreaConstraint(PlayerCliffID5, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID5, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID6, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID6, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID6, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID6, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID6, 8.2);
      rmSetAreaCoherence(PlayerCliffID6, 0.7);
      rmAddAreaToClass(PlayerCliffID6, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID6, false);
      rmSetAreaElevationVariation(PlayerCliffID6, 0.0);
      rmAddAreaConstraint(PlayerCliffID6, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID6, islandAvoidTradeRouteShort);

      rmSetAreaSize(PlayerCliffID7, cliffFraction, cliffFraction);
      rmSetAreaCliffType(PlayerCliffID7, "ZP Texas Impassable");
      rmSetAreaCliffEdge(PlayerCliffID7, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID7, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID7, 8.2);
      rmSetAreaCoherence(PlayerCliffID7, 0.7);
      rmAddAreaToClass(PlayerCliffID7, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID7, false);
      rmSetAreaElevationVariation(PlayerCliffID7, 0.0);
      rmAddAreaConstraint(PlayerCliffID7, avoidPlayerArea);
      rmAddAreaConstraint(PlayerCliffID7, islandAvoidTradeRouteShort);

      // Placing Cliffs for all players cases

      if(cNumberNonGaiaPlayers == 2){
         rmSetAreaLocation(PlayerCliffID1, 0.2, 0.8);

         rmBuildArea(PlayerCliffID1);
      }

      if(cNumberNonGaiaPlayers == 3){
         rmSetAreaLocation(PlayerCliffID1, 0.5, 0.9);
         rmSetAreaLocation(PlayerCliffID2, 0.1, 0.5);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
      }

      if(cNumberNonGaiaPlayers == 4){
         rmSetAreaLocation(PlayerCliffID1, 0.7, 0.9);
         rmSetAreaLocation(PlayerCliffID2, 0.2, 0.8);
         rmSetAreaLocation(PlayerCliffID3, 0.1, 0.3);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
         rmBuildArea(PlayerCliffID3);
      }

      if(cNumberNonGaiaPlayers == 5){
         rmSetAreaLocation(PlayerCliffID1, 0.75, 0.85);
         rmAddAreaInfluenceSegment(PlayerCliffID1, 0.8, 0.9, 0.7, 0.8);

         rmSetAreaLocation(PlayerCliffID2, 0.4, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID2, 0.4, 1.0, 0.4, 0.8);

         rmSetAreaLocation(PlayerCliffID3, 0.1, 0.6);
         rmAddAreaInfluenceSegment(PlayerCliffID3, 0.0, 0.6, 0.2, 0.6);

         rmSetAreaLocation(PlayerCliffID4, 0.15, 0.25);
         rmAddAreaInfluenceSegment(PlayerCliffID4, 0.1, 0.2, 0.2, 0.3);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
         rmBuildArea(PlayerCliffID3);
         rmBuildArea(PlayerCliffID4);
      }

      if(cNumberNonGaiaPlayers == 6){
         rmSetAreaLocation(PlayerCliffID1, 0.75, 0.85);
         rmAddAreaInfluenceSegment(PlayerCliffID1, 0.8, 0.9, 0.7, 0.8);

         rmSetAreaLocation(PlayerCliffID2, 0.5, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID2, 0.5, 1.0, 0.5, 0.8);

         rmSetAreaLocation(PlayerCliffID3, 0.2, 0.8);
         rmAddAreaInfluenceSegment(PlayerCliffID3, 0.15, 0.85, 0.25, 0.75);

         rmSetAreaLocation(PlayerCliffID4, 0.1, 0.5);
         rmAddAreaInfluenceSegment(PlayerCliffID4, 0.0, 0.5, 0.2, 0.5);

         rmSetAreaLocation(PlayerCliffID5, 0.15, 0.25);
         rmAddAreaInfluenceSegment(PlayerCliffID5, 0.1, 0.2, 0.2, 0.3);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
         rmBuildArea(PlayerCliffID3);
         rmBuildArea(PlayerCliffID4);
         rmBuildArea(PlayerCliffID5);
      }

      if(cNumberNonGaiaPlayers == 7){
         rmSetAreaLocation(PlayerCliffID1, 0.75, 0.85);
         rmAddAreaInfluenceSegment(PlayerCliffID1, 0.8, 0.9, 0.7, 0.8);

         rmSetAreaLocation(PlayerCliffID2, 0.5, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID2, 0.5, 1.0, 0.5, 0.8);

         rmSetAreaLocation(PlayerCliffID3, 0.25, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID3, 0.35, 0.8, 0.25, 1.0);

         rmSetAreaLocation(PlayerCliffID6, 0.1, 0.65);
         rmAddAreaInfluenceSegment(PlayerCliffID6, 0.0, 0.75, 0.2, 0.65);

         rmSetAreaLocation(PlayerCliffID4, 0.1, 0.5);
         rmAddAreaInfluenceSegment(PlayerCliffID4, 0.0, 0.5, 0.2, 0.5);

         rmSetAreaLocation(PlayerCliffID5, 0.15, 0.25);
         rmAddAreaInfluenceSegment(PlayerCliffID5, 0.1, 0.2, 0.2, 0.3);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
         rmBuildArea(PlayerCliffID3);
         rmBuildArea(PlayerCliffID4);
         rmBuildArea(PlayerCliffID5);
         rmBuildArea(PlayerCliffID6);
      }

      if(cNumberNonGaiaPlayers == 8){
         rmSetAreaLocation(PlayerCliffID1, 0.8, 0.8);
         rmAddAreaInfluenceSegment(PlayerCliffID1, 0.85, 0.85, 0.75, 0.75);

         rmSetAreaLocation(PlayerCliffID2, 0.55, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID2, 0.55, 1.0, 0.55, 0.8);

         rmSetAreaLocation(PlayerCliffID3, 0.35, 0.9);
         rmAddAreaInfluenceSegment(PlayerCliffID3, 0.3, 1.0, 0.4, 0.8);
         
         rmSetAreaLocation(PlayerCliffID4, 0.2, 0.8);
         rmAddAreaInfluenceSegment(PlayerCliffID4, 0.15, 0.85, 0.25, 0.75);

         rmSetAreaLocation(PlayerCliffID5, 0.1, 0.65);
         rmAddAreaInfluenceSegment(PlayerCliffID5, 0.0, 0.7, 0.2, 0.6);

         rmSetAreaLocation(PlayerCliffID6, 0.1, 0.45);
         rmAddAreaInfluenceSegment(PlayerCliffID6, 0.0, 0.45, 0.5, 0.45);

         rmSetAreaLocation(PlayerCliffID7, 0.2, 0.2);
         rmAddAreaInfluenceSegment(PlayerCliffID7, 0.15, 0.15, 0.25, 0.25);

         rmBuildArea(PlayerCliffID1);
         rmBuildArea(PlayerCliffID2);
         rmBuildArea(PlayerCliffID3);
         rmBuildArea(PlayerCliffID4);
         rmBuildArea(PlayerCliffID5);
         rmBuildArea(PlayerCliffID6);
         rmBuildArea(PlayerCliffID7);
      }


      // Add island constraints

      int playerIslandConstraint=rmCreateAreaConstraint("player Island", playerIslandNorth);
      int nativeIslandConstraint=rmCreateAreaConstraint("native Island", bigIslandID);
      int playerIslandSouthConstraint=rmCreateAreaConstraint("player Island south", playerIslandSouth);

      // Placing Scientists

      // Text
      rmSetStatusText("",0.20);

         // Scientist Village 1
         if (subCiv0 == rmGetCivID("zpscientists"))
         {  
         int scientistControllerID = rmCreateObjectDef("scientist controller 1");
            rmAddObjectDefItem(scientistControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
            rmSetObjectDefMinDistance(scientistControllerID, 0.0);
            rmSetObjectDefMaxDistance(scientistControllerID, 0.0);
            if (cNumberNonGaiaPlayers <= 6){  
               rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.58, 0.1);
            }
            else {  
               rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.53, 0.1);
            }
         vector scientistControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID, 0));

         int scientistVillageID1 = -1;
         int scientistVillage1Type = rmRandInt(1,2);
            scientistVillageID1 = rmCreateGrouping("scientist lab 1", "Scientist_Lab05");
            rmSetGroupingMinDistance(scientistVillageID1, 0);
            rmSetGroupingMaxDistance(scientistVillageID1, 30);
            rmAddGroupingConstraint(scientistVillageID1, ferryOnShore);
            rmAddGroupingConstraint(scientistVillageID1, villageEdgeConstraint);

            rmPlaceGroupingAtLoc(scientistVillageID1, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc1)), 1);
         
         int nativewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
            rmAddObjectDefItem(nativewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
            rmAddClosestPointConstraint(flagLand);

         vector closeToVillage1 = rmFindClosestPointVector(scientistControllerLoc1 , rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(nativewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

            rmClearClosestPointConstraints();

         int pirateportID1 = -1;
            pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport02");
            rmAddClosestPointConstraint(portOnShore);

         vector closeToVillage1a = rmFindClosestPointVector(scientistControllerLoc1, rmXFractionToMeters(1.0));
            rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
            
            rmClearClosestPointConstraints();

         }

         // Scientist Village 2
         if (subCiv0 == rmGetCivID("zpscientists"))
         {  
         int scientistControllerID2 = rmCreateObjectDef("scientist controller 2");
            rmAddObjectDefItem(scientistControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
            rmSetObjectDefMinDistance(scientistControllerID2, 0.0);
            rmSetObjectDefMaxDistance(scientistControllerID2, 0.0);
            rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.9, 0.42);

         vector scientistControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID2, 0));

         int scientistVillageID2 = -1;
         int scientistVillage2Type = rmRandInt(1,2);
            scientistVillageID2 = rmCreateGrouping("scientist lab 2", "Scientist_Lab06");
            rmSetGroupingMinDistance(scientistVillageID2, 0);
            rmSetGroupingMaxDistance(scientistVillageID2, 30);
            rmAddGroupingConstraint(scientistVillageID2, ferryOnShore);
            rmAddGroupingConstraint(scientistVillageID2, villageEdgeConstraint);

            rmPlaceGroupingAtLoc(scientistVillageID2, 0, rmXMetersToFraction(xsVectorGetX(scientistControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(scientistControllerLoc2)), 1);
         
         int nativewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
            rmAddObjectDefItem(nativewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
            rmAddClosestPointConstraint(flagLand);

         vector closeToVillage2 = rmFindClosestPointVector(scientistControllerLoc2 , rmXFractionToMeters(1.0));
            rmPlaceObjectDefAtLoc(nativewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

            rmClearClosestPointConstraints();

         int pirateportID2 = -1;
            pirateportID2 = rmCreateGrouping("pirate port 1", "pirateport02");
            rmAddClosestPointConstraint(portOnShore);

         vector closeToVillage2a = rmFindClosestPointVector(scientistControllerLoc2, rmXFractionToMeters(1.0));
            rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
            
            rmClearClosestPointConstraints();

         }


      // Placing Player Trade Route Sockets

      int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
      rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
      rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
      rmSetObjectDefAllowOverlap(socketID, true);
      rmSetObjectDefMinDistance(socketID, 10.0);
      rmSetObjectDefMaxDistance(socketID, 30.0);

      int riverHarbourPlatform = -1;
      riverHarbourPlatform = rmCreateGrouping("river platform", "Platform01");

      int riverHarbourPlatform2 = -1;
      riverHarbourPlatform2 = rmCreateGrouping("river platform 2", "Platform02");

      int riverHarbourPlatform3 = -1;
      riverHarbourPlatform3 = rmCreateGrouping("river platform 3", "Platform03");

      vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);

      if(cNumberNonGaiaPlayers <= 2){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.33);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 3){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.55);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 4){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.13);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
         //rmPlaceGroupingAtLoc(riverHarbourPlatform, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)));

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.39);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
         //rmPlaceGroupingAtLoc(riverHarbourPlatform3, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)));

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.61);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         //socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.59);
         //rmPlaceGroupingAtLoc(riverHarbourPlatform3, 0, rmXMetersToFraction(xsVectorGetX(socketLoc)), rmZMetersToFraction(xsVectorGetZ(socketLoc)));

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.87);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 5){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.05);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.35);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.55);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.95);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 6){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.05);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.43);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.62);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.95);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 7){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.28);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.38);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.65);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.72);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      if(cNumberNonGaiaPlayers == 8){
         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.10);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.22);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.36);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.47);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.57);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.67);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.78);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

         socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
      }

      for(i=1; <cNumberPlayers)
      {
         int colonyShipID=rmCreateObjectDef("colony ship "+i);

         rmAddObjectDefItem(colonyShipID, "SPCXPFlatBoat", 1, 0.0);

         rmSetObjectDefMinDistance(colonyShipID, 0.0);
         rmSetObjectDefMaxDistance(colonyShipID, 10.0);
         
                     
         // Test of Marcin's Starting Units stuff...
         rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
         rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

      /*if(ypIsAsian(i) && rmGetNomadStart() == false)
         rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, berry), i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));*/
      
         rmPlaceObjectDefAtLoc(startSilverID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
         rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
         rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
         rmPlaceObjectDefAtLoc(playerHerdID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

         rmSetNuggetDifficulty(1, 1);
         rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

         int mapX = 300;
         int mapZ = 300;
         int centerX = mapX / 2;
         int centerZ = mapZ / 2;
         int playerX = rmPlayerLocXFraction(i) * mapX;
         int playerZ = rmPlayerLocZFraction(i) * mapZ;

         vector centerPos = xsVectorSet(centerX, 0, centerZ);
         vector playerPos = xsVectorSet(playerX, 0, playerZ);
         vector playerToCenter = xsVectorNormalize(centerPos - playerPos);
         int distance = 24+cNumberNonGaiaPlayers*0.5; // 10 meters. Increase until everything works.
         vector flagPos = playerPos + playerToCenter * distance;
         float flagX = xsVectorGetX(flagPos);
         float flagZ = xsVectorGetZ(flagPos);

         // Convert meters to fraction:
         flagX = flagX / mapX;
         flagZ = flagZ / mapZ;

         rmPlaceObjectDefAtLoc(waterSpawnFlagID, i, flagX, flagZ);
         rmPlaceObjectDefAtLoc(colonyShipID, i, flagX, flagZ);

      }

      // Text
      rmSetStatusText("",0.30);

   // check for KOTH game mode

      // Place King's Hill
      if (rmGetIsKOTH() == true) {

         ypKingsHillPlacer(0.4, 0.6, 0, 0);

      }


    // Place Aztecs

   int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater40);
      rmAddObjectDefConstraint(malteseControllerID, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID, avoidScientists); 
      rmAddObjectDefConstraint(malteseControllerID, avoidKOTH);
      rmAddObjectDefConstraint(malteseControllerID, nativeIslandConstraint); 
      rmAddObjectDefConstraint(malteseControllerID, villageEdgeConstraintFar); 
      rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.5, 0.5);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));

      int eastIslandVillage1 = rmCreateArea ("east island village 1");

      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(1300.0), rmAreaTilesToFraction(1300.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaCliffType(eastIslandVillage1, "ZP Amazon Aztec");
      rmSetAreaCliffEdge(eastIslandVillage1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage1, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(eastIslandVillage1, -2);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmBuildArea(eastIslandVillage1);

      int eastIslandVillage1ramp1 = rmCreateArea ("east island village1 ramp 1");
      rmSetAreaSize(eastIslandVillage1ramp1, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(eastIslandVillage1ramp1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)-35));
      rmSetAreaBaseHeight(eastIslandVillage1ramp1, -2.0);
      rmSetAreaCoherence(eastIslandVillage1ramp1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1ramp1, 30);
      rmBuildArea(eastIslandVillage1ramp1);

      int maltese2VillageID = -1;
      maltese2VillageID = rmCreateGrouping("temple city", "Aztec_Metropolis");
      rmAddGroupingConstraint(maltese2VillageID, avoidImpassableLand);
      rmPlaceGroupingAtLoc(maltese2VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);


      if (cNumberNonGaiaPlayers > 1){
         int malteseController2ID = rmCreateObjectDef("maltese controller 2");
         rmAddObjectDefItem(malteseController2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
         rmSetObjectDefMinDistance(malteseController2ID, 0.0);
         rmSetObjectDefMaxDistance(malteseController2ID, rmXFractionToMeters(0.45));
         rmAddObjectDefConstraint(malteseController2ID, avoidImpassableLand);
         rmAddObjectDefConstraint(malteseController2ID, avoidWater30,);
         rmAddObjectDefConstraint(malteseController2ID, avoidController); 
         rmAddObjectDefConstraint(malteseController2ID, avoidScientists); 
         rmAddObjectDefConstraint(malteseController2ID, avoidKOTH);
         rmAddObjectDefConstraint(malteseController2ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController2ID, villageEdgeConstraintFar); 
         rmPlaceObjectDefAtLoc(malteseController2ID, 0, 0.5, 0.5);
         vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController2ID, 0));

         int eastIslandVillage2 = rmCreateArea ("east island village 2");

         rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(950.0), rmAreaTilesToFraction(950.0));
         rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
         rmSetAreaCoherence(eastIslandVillage2, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage2, 5);
         rmSetAreaCliffType(eastIslandVillage2, "ZP Amazon Aztec");
         rmSetAreaCliffEdge(eastIslandVillage2, 1, 1.0, 0.0, 1.0, 0);
         rmSetAreaCliffHeight(eastIslandVillage2, 1.0, 0.0, 0.0); 
         rmSetAreaBaseHeight(eastIslandVillage2, 5);
         rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
         rmBuildArea(eastIslandVillage2);

         int eastIslandVillage1ramp2 = rmCreateArea ("east island village1 ramp 2");
         rmSetAreaSize(eastIslandVillage1ramp2, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
         rmSetAreaLocation(eastIslandVillage1ramp2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)-35));
         rmSetAreaBaseHeight(eastIslandVillage1ramp2, 5.0);
         rmSetAreaCoherence(eastIslandVillage1ramp2, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage1ramp2, 30);
         rmBuildArea(eastIslandVillage1ramp2);


         int maltese3VillageID = -1;
         int maltese3VillageType = rmRandInt(1,3);
         maltese3VillageID = rmCreateGrouping("temple city 2", "Aztec_Temple_0"+maltese3VillageType);
         rmAddGroupingConstraint(maltese3VillageID, avoidImpassableLand);
         rmPlaceGroupingAtLoc(maltese3VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);
      }

      if (cNumberNonGaiaPlayers > 3){
      
         int malteseController3ID = rmCreateObjectDef("maltese controller 3");
         rmAddObjectDefItem(malteseController3ID, "zpSPCWaterSpawnPoint", 1, 0.0);
         rmSetObjectDefMinDistance(malteseController3ID, 0.0);
         rmSetObjectDefMaxDistance(malteseController3ID, rmXFractionToMeters(0.45));
         rmAddObjectDefConstraint(malteseController3ID, avoidImpassableLand);
         rmAddObjectDefConstraint(malteseController3ID, avoidWater30);
         rmAddObjectDefConstraint(malteseController3ID, avoidController); 
         rmAddObjectDefConstraint(malteseController3ID, avoidScientists);
         rmAddObjectDefConstraint(malteseController3ID, avoidKOTH);
         rmAddObjectDefConstraint(malteseController3ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController3ID, villageEdgeConstraintFar); 
         rmPlaceObjectDefAtLoc(malteseController3ID, 0, 0.5, 0.5);
         vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController3ID, 0));

         int eastIslandVillage3 = rmCreateArea ("east island village 3");

         rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(950.0), rmAreaTilesToFraction(950.0));
         rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
         rmSetAreaCoherence(eastIslandVillage3, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage3, 5);
         rmSetAreaCliffType(eastIslandVillage3, "ZP Amazon Aztec");
         rmSetAreaCliffEdge(eastIslandVillage3, 1, 1.0, 0.0, 1.0, 0);
         rmSetAreaCliffHeight(eastIslandVillage3, 1.0, 0.0, 0.0); 
         rmSetAreaBaseHeight(eastIslandVillage3, 5);
         rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
         rmBuildArea(eastIslandVillage3);

         int eastIslandVillage1ramp3 = rmCreateArea ("east island village1 ramp 3");
         rmSetAreaSize(eastIslandVillage1ramp3, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
         rmSetAreaLocation(eastIslandVillage1ramp3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)-35));
         rmSetAreaBaseHeight(eastIslandVillage1ramp3, 5.0);
         rmSetAreaCoherence(eastIslandVillage1ramp3, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage1ramp3, 30);
         rmBuildArea(eastIslandVillage1ramp3);

         int maltese4VillageID = -1;
         int maltese4VillageType = rmRandInt(1,3);
         maltese4VillageID = rmCreateGrouping("temple city 3", "Aztec_Temple_0"+maltese4VillageType);
         rmAddGroupingConstraint(maltese4VillageID, avoidImpassableLand);
         rmPlaceGroupingAtLoc(maltese4VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);
      
      }

      if (cNumberNonGaiaPlayers > 6){
      
         int malteseController4ID = rmCreateObjectDef("maltese controller 4");
         rmAddObjectDefItem(malteseController4ID, "zpSPCWaterSpawnPoint", 1, 0.0);
         rmSetObjectDefMinDistance(malteseController4ID, 0.0);
         rmSetObjectDefMaxDistance(malteseController4ID, rmXFractionToMeters(0.45));
         rmAddObjectDefConstraint(malteseController4ID, avoidImpassableLand);
         rmAddObjectDefConstraint(malteseController4ID, avoidWater40);
         rmAddObjectDefConstraint(malteseController4ID, avoidController); 
         rmAddObjectDefConstraint(malteseController4ID, avoidScientists);
         rmAddObjectDefConstraint(malteseController4ID, avoidKOTH);
         rmAddObjectDefConstraint(malteseController4ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController4ID, villageEdgeConstraintFar); 
         rmPlaceObjectDefAtLoc(malteseController4ID, 0, 0.5, 0.5);
         vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController4ID, 0));

         int eastIslandVillage4 = rmCreateArea ("east island village 4");

         rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(1100.0), rmAreaTilesToFraction(1100.0));
         rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
         rmSetAreaCoherence(eastIslandVillage4, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage4, 5);
         rmSetAreaCliffType(eastIslandVillage4, "ZP Amazon Aztec");
         rmSetAreaCliffEdge(eastIslandVillage4, 1, 1.0, 0.0, 1.0, 0);
         rmSetAreaCliffHeight(eastIslandVillage4, 1.0, 0.0, 0.0); 
         rmSetAreaBaseHeight(eastIslandVillage4, -2);
         rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
         rmBuildArea(eastIslandVillage4);

         int eastIslandVillage1ramp4 = rmCreateArea ("east island village1 ramp 4");
         rmSetAreaSize(eastIslandVillage1ramp4, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
         rmSetAreaLocation(eastIslandVillage1ramp4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)-35), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
         rmSetAreaBaseHeight(eastIslandVillage1ramp4, -2.0);
         rmSetAreaCoherence(eastIslandVillage1ramp4, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage1ramp4, 30);
         rmBuildArea(eastIslandVillage1ramp4);

         int maltese5VillageID = -1;
         int maltese5VillageType = rmRandInt(1,4);
         maltese5VillageID = rmCreateGrouping("temple city 4", "Aztec_Temple_04");
         rmAddGroupingConstraint(maltese5VillageID, avoidImpassableLand);
         rmPlaceGroupingAtLoc(maltese5VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);
      
      }

      // Text
      rmSetStatusText("",0.40);



      // Aztec Houses
      int randomHouseID=rmCreateObjectDef("random tree");
      rmAddObjectDefItem(randomHouseID, "zpNativeHouseAztec", 1, 0.0);
      rmSetObjectDefMinDistance(randomHouseID, 0.0);
      rmSetObjectDefMaxDistance(randomHouseID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(randomHouseID, avoidImpassableLand);
      rmAddObjectDefConstraint(randomHouseID, avoidAll_dk); 
      rmAddObjectDefConstraint(randomHouseID, nativeIslandConstraint);

      rmPlaceObjectDefAtLoc(randomHouseID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

	// Player placement
	//int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

   // Placement order
   // Trade route -> River (none on this map) -> Natives -> Secrets -> Cliffs -> Nuggets


	int tpVariation = rmRandInt(1,2);
//		tpVariation = 2;		// for testing

	

   // Text
   rmSetStatusText("",0.50);

   int numTries = -1;
   int failCount = -1;


 // if(cNumberNonGaiaPlayers>2){
	int silverType = -1;
	int silverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*3);
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
	  int southSilverID = rmCreateObjectDef("native gold "+i);
	  rmAddObjectDefItem(southSilverID, "minegold", 1, 0.0);
      rmSetObjectDefMinDistance(southSilverID, 0.0);
      rmSetObjectDefMaxDistance(southSilverID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(southSilverID, avoidGold);
      rmAddObjectDefConstraint(southSilverID, avoidAll);
      rmAddObjectDefConstraint(southSilverID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(southSilverID, avoidTradeRoute);
      rmAddObjectDefConstraint(southSilverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(southSilverID, nativeIslandConstraint);
	  rmPlaceObjectDefAtLoc(southSilverID, 0, 0.5, 0.5);
   }

   // Trees 
	int southTreesID = rmCreateObjectDef("south tree");
		rmAddObjectDefItem(southTreesID, "TreeAmazon", 20, 10.0);
		rmSetObjectDefMinDistance(southTreesID,  rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(southTreesID,  rmXFractionToMeters(0.50));
		rmAddObjectDefToClass(southTreesID, rmClassID("classForest"));
		rmAddObjectDefConstraint(southTreesID, forestConstraint);
		rmAddObjectDefConstraint(southTreesID, avoidMineForest_dk);
		rmAddObjectDefConstraint(southTreesID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(southTreesID, avoidTradeRoute);
      rmAddObjectDefConstraint(southTreesID, avoidMountains);
		rmAddObjectDefConstraint(southTreesID, forestObjConstraint);
		rmAddObjectDefConstraint(southTreesID, avoidTownCenter);
		rmAddObjectDefConstraint(southTreesID, nativeIslandConstraint);
		rmPlaceObjectDefAtLoc(southTreesID, 0, 0.50, 0.50, 2+4*cNumberNonGaiaPlayers);

      // Text
      rmSetStatusText("",0.60);

   // Scattered berries all over island
	int berriesID=rmCreateObjectDef("random berries");
      rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 4.0); 
      rmSetObjectDefMinDistance(berriesID, 0.0);
      rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.3));  
      rmAddObjectDefConstraint(berriesID, avoidAll);
      rmAddObjectDefConstraint(berriesID, avoidImportantItem);
      rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
      rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
      rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers);


   // RANDOM TREES
   int randomTreeNativeID=rmCreateObjectDef("random native tree");
      rmAddObjectDefItem(randomTreeNativeID, "TreeAmazon", 1, 0.0);
      rmSetObjectDefMinDistance(randomTreeNativeID, 0.0);
      rmSetObjectDefMaxDistance(randomTreeNativeID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(randomTreeNativeID, avoidImpassableLand);
      rmAddObjectDefConstraint(randomTreeNativeID, nativeIslandConstraint);
      rmAddObjectDefConstraint(randomTreeNativeID, avoidAll); 

      rmPlaceObjectDefAtLoc(randomTreeNativeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

      int randomTreeNorthID=rmCreateObjectDef("random player tree");
      rmAddObjectDefItem(randomTreeNorthID, "TreeSonora", 1, 0.0);
      rmSetObjectDefMinDistance(randomTreeNorthID, 0.0);
      rmSetObjectDefMaxDistance(randomTreeNorthID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(randomTreeNorthID, avoidImpassableLand);
      rmAddObjectDefConstraint(randomTreeNorthID, playerIslandConstraint);
      rmAddObjectDefConstraint(randomTreeNorthID, avoidAll); 

      rmPlaceObjectDefAtLoc(randomTreeNorthID, 0, 0.5, 0.5, 10);

      int randomTreeSouthID=rmCreateObjectDef("random player tree 2");
      rmAddObjectDefItem(randomTreeSouthID, "TreeSonora", 1, 0.0);
      rmSetObjectDefMinDistance(randomTreeSouthID, 0.0);
      rmSetObjectDefMaxDistance(randomTreeSouthID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(randomTreeSouthID, avoidImpassableLand);
      rmAddObjectDefConstraint(randomTreeSouthID, playerIslandSouthConstraint);
      rmAddObjectDefConstraint(randomTreeSouthID, avoidAll); 

      rmPlaceObjectDefAtLoc(randomTreeSouthID, 0, 0.5, 0.5, 10);

      // VILLAGE TREES
      int villageTreeID=rmCreateObjectDef("village tree");
      rmAddObjectDefItem(villageTreeID, "TreeAmazon", 1, 0.0);
      rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage1, 9);
      rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage2, 9);
      rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage3, 9);
      rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage4, 9);
 
  // Text
   rmSetStatusText("",0.70);

    
 // Resources that can be placed after forests

  //Place fish
  int fishID=rmCreateObjectDef("fish");
  rmAddObjectDefItem(fishID, "FishBass", 3, 9.0);
  rmSetObjectDefMinDistance(fishID, 0.0);
  rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fishID, fishVsFishID);
  rmAddObjectDefConstraint(fishID, fishLand);
  rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers); 
  
   //PAROT : underwater Decoration
   int avoidLand = rmCreateTerrainDistanceConstraint("avoid land long", "Land", true, 5.0);
   int underwaterDecoID=rmCreateObjectDef("SeaweedRocks");
   rmAddObjectDefItem(underwaterDecoID, "UnderbrushCoast", 1, 3);
   //rmAddObjectDefItem(int defID, string unitName, int count, float clusterDistance)
   rmSetObjectDefMinDistance(underwaterDecoID, 0.00);
   rmSetObjectDefMaxDistance(underwaterDecoID, rmXFractionToMeters(0.04));   
   rmAddObjectDefConstraint(underwaterDecoID, avoidLand);   
   rmAddObjectDefConstraint(underwaterDecoID, avoidMountains);   
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.9, 0.5, 20);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.8, 0.6, 15);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.7, 0.7, 15);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.6, 0.8, 10);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.5, 0.8, 10);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.4, 0.8, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.3, 0.7, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.2, 0.6, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.2, 0.5, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.2, 0.4, 10);
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.3, 0.3, 15);        
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.4, 0.2, 20);     
       
   //rmPlaceObjectDefAtLoc(int defID, int playerID, float xFraction, float zFraction, long placeCount)   

   // Text
   rmSetStatusText("",0.80);

	int tapirCount = rmRandInt(3,6);
	int capyCount = rmRandInt(9,12);


	int tapirSID=rmCreateObjectDef("south tapir crash");
   rmAddObjectDefItem(tapirSID, "tapir", tapirCount, 2.0);
   rmSetObjectDefMinDistance(tapirSID, 0.0);
   rmSetObjectDefMaxDistance(tapirSID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(tapirSID, avoidImpassableLand);
   rmAddObjectDefConstraint(tapirSID, nativeIslandConstraint);
   rmSetObjectDefCreateHerd(tapirSID, true);
   rmPlaceObjectDefAtLoc(tapirSID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int capybaraSID=rmCreateObjectDef("south capybara crash");
   rmAddObjectDefItem(capybaraSID, "capybara", capyCount, 2.0);
   rmSetObjectDefMinDistance(capybaraSID, 0.0);
   rmSetObjectDefMaxDistance(capybaraSID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(capybaraSID, avoidImpassableLand);
   rmAddObjectDefConstraint(capybaraSID, nativeIslandConstraint);
   rmSetObjectDefCreateHerd(capybaraSID, true);
   rmPlaceObjectDefAtLoc(capybaraSID, 0, 0.5, 0.5, (1.75*cNumberNonGaiaPlayers));

   // Text
   rmSetStatusText("",0.90);



   // Define and place Nuggets

	   int southNugget1= rmCreateObjectDef("south nugget easy"); 
	   rmAddObjectDefItem(southNugget1, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(2, 2);
      rmSetObjectDefMinDistance(southNugget1, 0.0);
	   rmSetObjectDefMaxDistance(southNugget1, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(southNugget1, avoidImpassableLand);
  	   rmAddObjectDefConstraint(southNugget1, avoidNugget);
  	   rmAddObjectDefConstraint(southNugget1, avoidTradeRoute);
  	   rmAddObjectDefConstraint(southNugget1, avoidAll);
	   rmAddObjectDefConstraint(southNugget1, avoidWater20);
	   rmAddObjectDefConstraint(southNugget1, nativeIslandConstraint);
	   rmAddObjectDefConstraint(southNugget1, playerEdgeConstraint);
	   rmPlaceObjectDefPerPlayer(southNugget1, false, 1);


	   int southNugget2= rmCreateObjectDef("south nugget medium"); 
	   rmAddObjectDefItem(southNugget2, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(3, 3);
	   rmSetObjectDefMinDistance(southNugget2, 0.0);
	   rmSetObjectDefMaxDistance(southNugget2, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(southNugget2, avoidImpassableLand);
  	   rmAddObjectDefConstraint(southNugget2, avoidNugget);
  	   rmAddObjectDefConstraint(southNugget2, avoidTownCenter);
  	   rmAddObjectDefConstraint(southNugget2, avoidTradeRoute);
  	   rmAddObjectDefConstraint(southNugget2, avoidAll);
  	   rmAddObjectDefConstraint(southNugget2, avoidWater20);
	   rmAddObjectDefConstraint(southNugget2, nativeIslandConstraint);
	   rmAddObjectDefConstraint(southNugget2, playerEdgeConstraint);
	   rmPlaceObjectDefPerPlayer(southNugget2, false, 1);


// ------Triggers--------//

int tch0=1671; // tech operator

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
rmSetTriggerEffectParam("TechID","cTechzpIsAztecMap"); // Aztec Map
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
rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientists"); //operator
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
rmCreateTrigger("Activate WaterTemple"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpPickNativeConsulateTechAvailable"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWaterTemple"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_WaterTemple"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


// Submarine Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainPrivateer1ON Plr"+k);
rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
rmCreateTrigger("TrainPrivateer1TIME Plr"+k);


rmCreateTrigger("TrainPrivateer2ON Plr"+k);
rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","99");
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


rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
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
rmCreateTrigger("UniqueShip1TIMEPlr"+k);

rmCreateTrigger("BlackbTrain1ONPlr"+k);
rmCreateTrigger("BlackbTrain1OFFPlr"+k);

rmCreateTrigger("UniqueShip2TIMEPlr"+k);

rmCreateTrigger("BlackbTrain2ONPlr"+k);
rmCreateTrigger("BlackbTrain2OFFPlr"+k);


rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","99");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Build limit reducer
rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","5");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","99");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Build limit reducer 1
rmSwitchToTrigger(rmTriggerID("Nautilus1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
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
rmSetTriggerConditionParam("DstObject","5");
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
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
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
   rmSetTriggerConditionParam("DstObject","99");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","99");
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
   rmSetTriggerConditionParam("DstObject","99");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","99");
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

// AI Water Temple

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Water Temple"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("ProtoUnit","zpWaterTemple");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);

int nativePartner=-1;
nativePartner = rmRandInt(1,3);

if (nativePartner==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateNatJesuit"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (nativePartner==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateNatZapotec"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (nativePartner==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateNatMaya"); //operator
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
