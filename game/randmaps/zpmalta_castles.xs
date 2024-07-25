// Malta Castles 1.0

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
  string baseMix = "Africa Desert Grass dry";
  string paintMix = "africa desert rock";
  string baseTerrain = "water";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "Africa Desert Beach";
  string startTreeType = "ypTreeCeylon";
  string forestType = "z31 Mediterranean Coastal Forest";
  string forestType2 = "z30 AFrican Coast";
  string cliffType = "Africa Desert Grass";
  string mapType1 = "mediSea";
  string mapType2 = "grass";
  string huntable1 = "ypibex";
  string huntable2 = "ypWildElephant";
  string fish1 = "FishSalmon";
  string fish2 = "ypFishTuna";
  string whale1 = "MinkeWhale";
  string lightingType = "punjab_skirmish";
  string patchTerrain = "ceylon\ground_grass2_ceylon";
  string patchType1 = "ceylon\ground_grass4_ceylon";
  string patchType2 = "ceylon\ground_sand4_ceylon";
  
	// Define Natives
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


	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	
	chooseMercs();
	
	// Set size of map
	int playerTiles=22000;
  if(cNumberNonGaiaPlayers < 5)
    playerTiles = 25000;
  if (cNumberNonGaiaPlayers < 3)
		playerTiles = 32000;
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
  rmSetMapType("mediEurope");
  rmSetMapType("euroNavalTradeRoute");
  rmSetMapType("anno");
	rmSetLightingSet("punjab_skirmish");
  rmSetOceanReveal(true);

	// Initialize map.
	rmTerrainInitialize(baseTerrain);

	// Misc variables for use later
	int numTries = -1;

   // Define some classes.
   int classPlayer=rmDefineClass("player");
   int classIsland=rmDefineClass("island");
   rmDefineClass("classForest");
   rmDefineClass("classPatch");
   rmDefineClass("importantItem");
   int classCanyon=rmDefineClass("canyon");
   int classAtol=rmDefineClass("atol");
   int classEuIsland=rmDefineClass("europe island");
   int classAfIsland=rmDefineClass("africa island");
   int classPortSite=rmDefineClass("portSite");
   int classPlayerArea=rmDefineClass("player area");
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
   int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
   int mesaConstraint = rmCreateBoxConstraint("mesas stay in southern portion of island", .35, .55, .65, .35);
   int northConstraint = rmCreateBoxConstraint("huntable constraint for north side of island", .25, .55, .8, .85);
   int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 12.0);
   int avoidTCLong=rmCreateTypeDistanceConstraint("stay away from TC by far", "TownCenter", 30.0);

   // Island Constraints  
   int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 40.0);
   int islandConstraintShort=rmCreateClassDistanceConstraint("islands avoid each other short", classIsland, 30.0);
   int islandEdgeConstraint=rmCreatePieConstraint("island edge of map", 0.5, 0.5, 0, rmGetMapXSize()-5, 0, 0, 0);
   int avoidAtol=rmCreateClassDistanceConstraint("stuff avoids atols", classAtol, 40.0);
   int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus island", classBonusIsland, 40.0);
   int avoidEurope=rmCreateClassDistanceConstraint("stuff avoids eu islands", classEuIsland, 30.0);
   int avoidAfrica=rmCreateClassDistanceConstraint("stuff avoids af islands", classAfIsland, 30.0);
   int avoidPlayerArea=rmCreateClassDistanceConstraint("stuff avoids player area", classPlayerArea, 15.0);
   int avoidPortArea=rmCreateClassDistanceConstraint("stuff avoids port area", classPortSite, 30.0);

   // Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
   int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 20.0);	
   int avoidFish2=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 75.0);	
   int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", whale1, 8.0);   
   int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 22.0);
   int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 45.0);
   int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "minetin", 35.0);
   int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 55.0);
   int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 30.0);
   int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 40.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 45.0); 
   int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 45.0); 
   int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 70.0); 
   int avoidHardNugget=rmCreateTypeDistanceConstraint("hard nuggets avoid other nuggets less", "abstractNugget", 20.0); 

   int avoidPirates=rmCreateTypeDistanceConstraint("avoid socket pirates", "zpSocketPirates", 20.0);
   int avoidWokou=rmCreateTypeDistanceConstraint("avoid socket wokou", "zpSocketWokou", 30.0);
   int avoidJesuit=rmCreateTypeDistanceConstraint("avoid socket jesuit", "zpSocketMaltese", 30.0);
   int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 17.0);
   int avoidControllerFar=rmCreateTypeDistanceConstraint("stay away from Controller Far", "zpSPCWaterSpawnPoint", 70.0);
   int avoidControllerMediumFar=rmCreateTypeDistanceConstraint("stay away from Controller Medium Far", "zpSPCWaterSpawnPoint", 25.0);

   // Avoid impassable land
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
   int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
   int avoidMesa=rmCreateClassDistanceConstraint("avoid random mesas on south central portion of migration island", classCanyon, 10.0);

   // Constraint to avoid water.
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 4.0);
   int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 10.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
   int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

   // things
   int avoidImportantItem = rmCreateClassDistanceConstraint("avoid natives", rmClassID("importantItem"), 7.0);
   int avoidImportantItemNatives = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 70.0);
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
   int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 15.0);

   // flag constraints
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 12.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 40);
   int flagVsPirates1 = rmCreateTypeDistanceConstraint("flag avoid pirates 1", "zpPirateWaterSpawnFlag1", 40);
   int flagVsPirates2 = rmCreateTypeDistanceConstraint("flag avoid pirates 2", "zpPirateWaterSpawnFlag2", 40);
   int flagVsWokou1 = rmCreateTypeDistanceConstraint("flag avoid wokou 1", "zpWokouWaterSpawnFlag1", 40);
   int flagVsWokou2 = rmCreateTypeDistanceConstraint("flag avoid wokou  2", "zpWokouWaterSpawnFlag2", 40);
   int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, 0, rmGetMapXSize()-100, 0, 0, 0);
   int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);

   //Trade Route Contstraints
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 12.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
   int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "zpSPCPortSocket", 37.0);
   int avoidTradeSocketsShort = rmCreateTypeDistanceConstraint("avoid trade sockets short", "zpSPCPortSocket", 12.0);


	    	

   // --------------- Place Trade Route ----------------------

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

   // Port Sites

   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(630.0), rmAreaTilesToFraction(630.0));
   rmSetAreaLocation(portSite1, 0.95-rmXTilesToFraction(25), 0.5);
   rmSetAreaMix(portSite1, baseMix);
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 20);
   rmSetAreaBaseHeight(portSite1, 3.5);
   rmAddAreaToClass(portSite1, classPortSite);
   rmBuildArea(portSite1);


   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(630.0), rmAreaTilesToFraction(630.0));
   rmSetAreaLocation(portSite2, 0.5,0.05+rmXTilesToFraction(25));
   rmSetAreaMix(portSite2, baseMix);
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 20);
   rmSetAreaBaseHeight(portSite2, 3.5);
   rmAddAreaToClass(portSite2, classPortSite);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, rmAreaTilesToFraction(630.0), rmAreaTilesToFraction(630.0));

   rmSetAreaMix(portSite3, baseMix);
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 20);
   rmSetAreaBaseHeight(portSite3, 3.5);
   rmAddAreaToClass(portSite3, classPortSite);


   if (cNumberNonGaiaPlayers <= 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7){
      rmSetAreaLocation(portSite3, 0.18+rmXTilesToFraction(17), 0.82-rmXTilesToFraction(17));
      rmBuildArea(portSite3);
      }

   else{
      rmSetAreaLocation(portSite3, 0.05+rmXTilesToFraction(25), 0.5);
      rmBuildArea(portSite3);

      int portSite4 = rmCreateArea ("port_site4");
      rmSetAreaSize(portSite4, rmAreaTilesToFraction(630.0), rmAreaTilesToFraction(630.0));
      rmSetAreaLocation(portSite4, 0.5,0.95-rmXTilesToFraction(25));
      rmSetAreaMix(portSite4, baseMix);
      rmSetAreaCoherence(portSite4, 1);
      rmSetAreaSmoothDistance(portSite4, 20);
      rmSetAreaBaseHeight(portSite4, 3.5);
      rmAddAreaToClass(portSite4, classPortSite);
      rmBuildArea(portSite4);
      }
 
  
	// ----------- Place Players ------------------

   float teamStartLoc = rmRandFloat(0.0, 1.0);

   // 2 and 3 Players

   if(cNumberNonGaiaPlayers < 4){
      rmSetPlacementSection(0.125, 0.625);
      rmPlacePlayersCircular(0.285, 0.285, 0);
   }

   // 4 Players

   if(cNumberNonGaiaPlayers == 4){
      if(cNumberTeams == 2){

         // 4 players in 2 teams
         if (teamStartLoc > 0.5)
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.02, 0.52);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.23, 0.72);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
         else
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.23, 0.72);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.02, 0.52);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
      }
      else{

         // 4 players in multiple teams
         rmSetPlacementSection(0.00, 0.75);
         rmPlacePlayersCircular(0.285, 0.285, 0);
      }
   }

   // 5 Players

   if(cNumberNonGaiaPlayers == 5){
      rmSetPlacementSection(0.0, 0.8);
      rmPlacePlayersCircular(0.285, 0.285, 0);
   }

   // 6 Players

   if(cNumberNonGaiaPlayers == 6)
   {
      if(cNumberTeams == 2){

         // 6 players in 2 teams
         if (teamStartLoc > 0.5)
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.05, 0.71);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.206, 0.883);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
         else
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.206, 0.883);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.05, 0.71);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
      }
         else{

         // 6 players in multiple teams
         rmSetPlacementSection(0.05, 0.883);
         rmPlacePlayersCircular(0.25, 0.25, 0);
      }
   }

   // 7 Players

   if(cNumberNonGaiaPlayers == 7){
      rmSetPlacementSection(0.97, 0.77);
      rmPlacePlayersCircular(0.285, 0.285, 0);
   }

   // 8 Players

   if(cNumberNonGaiaPlayers == 8)
   {
      if(cNumberTeams == 2){

         // 8 players in 2 teams
         if (teamStartLoc > 0.5)
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.95, 0.3);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.45, 0.8);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
         else
         {
            rmSetPlacementTeam(0);
            rmSetPlacementSection(0.45, 0.8);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
            rmSetPlacementTeam(1);
            rmSetPlacementSection(0.95, 0.3);
            rmPlacePlayersCircular(0.285, 0.285, rmDegreesToRadians(5.0));
         }
      }
      else{

         // 8 players in multiple teams
         rmSetPlacementSection(0.95, 0.8);
         rmPlacePlayersCircular(0.285, 0.285, 0);
      }
   }

   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);


   // ------------------ Corsair Islands ----------------------------

   // Bigger Island

   int smallIsland1ID=rmCreateArea("corsair island");
   rmSetAreaCoherence(smallIsland1ID, 0.45);
   rmSetAreaBaseHeight(smallIsland1ID, 2.0);
   rmSetAreaSmoothDistance(smallIsland1ID, 20);
   rmSetAreaMix(smallIsland1ID,paintMix);
   rmAddAreaToClass(smallIsland1ID, classIsland);
   rmAddAreaToClass(smallIsland1ID, classAtol);
   rmAddAreaToClass(smallIsland1ID, classAfIsland);
   rmAddAreaToClass(smallIsland1ID, classBonusIsland);
   rmAddAreaConstraint(smallIsland1ID, islandConstraint);
   rmSetAreaObeyWorldCircleConstraint(smallIsland1ID, false);
   rmSetAreaElevationType(smallIsland1ID, cElevTurbulence);
   rmAddAreaConstraint(smallIsland1ID, islandAvoidTradeRoute);
   rmSetAreaElevationVariation(smallIsland1ID, 2.0);
   rmSetAreaElevationMinFrequency(smallIsland1ID, 0.09);
   rmSetAreaElevationOctaves(smallIsland1ID, 3);
   rmSetAreaElevationPersistence(smallIsland1ID, 0.2);
   rmSetAreaElevationNoiseBias(smallIsland1ID, 1);

   if(cNumberNonGaiaPlayers <= 3){
      rmSetAreaSize(smallIsland1ID, rmAreaTilesToFraction(1800.0), rmAreaTilesToFraction(1800.0));
      rmSetAreaLocation(smallIsland1ID, .5, .5);
      rmBuildArea(smallIsland1ID);
      }

   else{
      rmSetAreaSize(smallIsland1ID, rmAreaTilesToFraction(1300.0), rmAreaTilesToFraction(1300.0));
      rmSetAreaLocation(smallIsland1ID, .55, .55);
      rmBuildArea(smallIsland1ID);

      // Smaller Island

      int smallIsland2ID=rmCreateArea("corsair island2");
      rmSetAreaSize(smallIsland2ID, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1500.0));
      rmSetAreaCoherence(smallIsland2ID, 0.45);
      rmSetAreaBaseHeight(smallIsland2ID, 2.0);
      rmSetAreaSmoothDistance(smallIsland2ID, 20);
      rmSetAreaMix(smallIsland2ID,paintMix);
      rmAddAreaToClass(smallIsland2ID, classIsland);
      rmAddAreaToClass(smallIsland2ID, classAtol);
      rmAddAreaToClass(smallIsland2ID, classAfIsland);
      rmAddAreaToClass(smallIsland2ID, classBonusIsland);
      rmAddAreaConstraint(smallIsland2ID, islandConstraintShort);
      rmSetAreaObeyWorldCircleConstraint(smallIsland2ID, false);
      rmSetAreaElevationType(smallIsland2ID, cElevTurbulence);
      rmAddAreaConstraint(smallIsland2ID, islandAvoidTradeRoute);
      rmSetAreaElevationVariation(smallIsland2ID, 2.0);
      rmSetAreaElevationMinFrequency(smallIsland2ID, 0.09);
      rmSetAreaElevationOctaves(smallIsland2ID, 3);
      rmSetAreaElevationPersistence(smallIsland2ID, 0.2);
      rmSetAreaElevationNoiseBias(smallIsland2ID, 1);
      rmSetAreaLocation(smallIsland2ID, .45, .45);
      rmBuildArea(smallIsland2ID);

      }

   // ---------------- Pirates ----------------------------

   // Place Controllers

   int controllerID = rmCreateObjectDef("Controler 1");
   rmAddObjectDefItem(controllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmPlaceObjectDefAtLoc(controllerID, 0, 0.53, 0.53+rmXTilesToFraction(17));
   vector ControllerLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID, 0));

   if (cNumberNonGaiaPlayers > 3){ 
      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmPlaceObjectDefAtLoc(controllerID2, 0, 0.43, 0.43-rmXTilesToFraction(13));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));
      }

   int pirateSite1 = rmCreateArea ("pirate_site1");
   rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc)));
   rmSetAreaMix(pirateSite1, paintMix);
   rmSetAreaCoherence(pirateSite1, 1);
   rmSetAreaSmoothDistance(pirateSite1, 15);
   rmSetAreaBaseHeight(pirateSite1, 2.0);
   rmAddAreaToClass(pirateSite1, classBonusIsland);
   rmBuildArea(pirateSite1);

   int pirateSite2 = rmCreateArea ("pirate_site2");
   rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
    rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
   rmSetAreaMix(pirateSite2, paintMix);
   rmSetAreaCoherence(pirateSite2, 1);
   rmSetAreaSmoothDistance(pirateSite2, 15);
   rmSetAreaBaseHeight(pirateSite2, 2.0);
   rmAddAreaToClass(pirateSite2, classBonusIsland);
   rmBuildArea(pirateSite2);

   // Pirate Village 1

   int piratesVillageID = -1;
   piratesVillageID = rmCreateGrouping("pirate city", "pirate_village03");     



   rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc)), 1);

   int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
   rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
   rmAddClosestPointConstraint(flagLandShort);
   rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

   vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc, rmXFractionToMeters(1.0));
   rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

   rmClearClosestPointConstraints();

   int pirateportID1 = -1;
   pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport03");
   rmAddClosestPointConstraint(portOnShore);
   rmAddClosestPointConstraint(ObjectAvoidTradeRoute);

   vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc, rmXFractionToMeters(1.0));
   rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
   
   rmClearClosestPointConstraints();

   if (cNumberNonGaiaPlayers >= 4){

      // Pirate Village 2

      int piratesVillageID2 = -1;
      int piratesVillage2Type = rmRandInt(1,2);
      piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village0"+piratesVillage2Type);



      rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);
   
      int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
      rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLand);

      vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

      int pirateportID2 = -1;
      pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport02");
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();

   }

   // ---------------- KotH ----------------------------

   // check for KOTH game mode
   if(rmGetIsKOTH()) {
      
      int randLoc = rmRandInt(1,2);

      if (cNumberNonGaiaPlayers <= 3){
      float xLoc = 0.5;
      float yLoc = 0.5;
      }
      else{
      xLoc = 0.53;
      yLoc = 0.53;
      }

      float walk = 0.00;
      
      ypKingsHillPlacer(xLoc, yLoc, walk, 0);
      rmEchoInfo("XLOC = "+xLoc);
      rmEchoInfo("XLOC = "+yLoc);
      }

   // ---------------- Trade Route Ports ----------------------------
         
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

   if (cNumberNonGaiaPlayers <= 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7){
      portID03 = rmCreateGrouping("portG 03", "Harbour_Center_W");
      rmPlaceGroupingAtLoc(portID03, 0, 0.18+rmXTilesToFraction(8), 0.82-rmXTilesToFraction(9));
      }

   else{
      portID03 = rmCreateGrouping("portG 03", "Harbour_Center_SW");
      rmPlaceGroupingAtLoc(portID03, 0, 0.05+rmXTilesToFraction(12), 0.5);

      // Port 4
      int portID04 = rmCreateObjectDef("port 04");
      portID04 = rmCreateGrouping("portG 04", "Harbour_Center_NW");
      rmPlaceGroupingAtLoc(portID04, 0, 0.5,0.95-rmXTilesToFraction(12));
      }

   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

   // ------------------- Player Islands ---------------------

   // East Island

   int eastIslandCliffs = rmCreateArea ("east island cliffs");
   rmSetAreaCoherence(eastIslandCliffs, 0.6);
   rmSetAreaMinBlobs(eastIslandCliffs, 8);
   rmSetAreaMaxBlobs(eastIslandCliffs, 12);
   rmSetAreaMinBlobDistance(eastIslandCliffs, 8.0);
   rmSetAreaMaxBlobDistance(eastIslandCliffs, 10.0);
   rmSetAreaSmoothDistance(eastIslandCliffs, 15);

   rmSetAreaMix(eastIslandCliffs, baseMix);
   rmSetAreaBaseHeight(eastIslandCliffs, 3.2);
   rmAddAreaConstraint(eastIslandCliffs, islandAvoidTradeRoute);
   rmSetAreaElevationType(eastIslandCliffs, cElevTurbulence);
   rmSetAreaElevationVariation(eastIslandCliffs, 4.0);
   rmSetAreaElevationPersistence(eastIslandCliffs, 0.2);
   rmSetAreaElevationMinFrequency(eastIslandCliffs, 0.09);
   rmSetAreaElevationNoiseBias(eastIslandCliffs, 1);
   rmAddAreaConstraint(eastIslandCliffs, islandConstraint);
   rmAddAreaConstraint(eastIslandCliffs, avoidBonusIslands);
   rmAddAreaToClass(eastIslandCliffs, classIsland);

   if (cNumberNonGaiaPlayers == 6 && cNumberTeams == 2){
      rmSetAreaLocation(eastIslandCliffs, 0.6, 0.2);
      rmSetAreaSize(eastIslandCliffs, 0.07, 0.07);
      rmAddAreaInfluenceSegment(eastIslandCliffs, 0.75, 0.3, 0.6, 0.2);
      rmAddAreaInfluenceSegment(eastIslandCliffs, 0.4, 0.2, 0.6, 0.2);
      }

   else{
      if (cNumberNonGaiaPlayers == 7){
         rmSetAreaLocation(eastIslandCliffs, 0.7, 0.3);
         rmSetAreaSize(eastIslandCliffs, 0.17, 0.17);
         rmAddAreaInfluenceSegment(eastIslandCliffs, 0.8, 0.6, 0.7, 0.3);
         rmAddAreaInfluenceSegment(eastIslandCliffs, 0.4, 0.2, 0.7, 0.3);
         }
      else{
         rmSetAreaLocation(eastIslandCliffs, 0.7, 0.3);
         rmSetAreaSize(eastIslandCliffs, 0.12, 0.12);
         rmAddAreaInfluenceSegment(eastIslandCliffs, 0.8, 0.6, 0.7, 0.3);
         rmAddAreaInfluenceSegment(eastIslandCliffs, 0.4, 0.2, 0.7, 0.3);
         }
      }

   rmBuildArea(eastIslandCliffs);

   // West Island

   int westIslandCliffs = rmCreateArea ("west Island cliffs");
   rmSetAreaCoherence(westIslandCliffs, 0.6);
   rmSetAreaMinBlobs(westIslandCliffs, 8);
   rmSetAreaMaxBlobs(westIslandCliffs, 12);
   rmSetAreaMinBlobDistance(westIslandCliffs, 8.0);
   rmSetAreaMaxBlobDistance(westIslandCliffs, 10.0);
   rmSetAreaSmoothDistance(westIslandCliffs, 15);

   rmSetAreaMix(westIslandCliffs, baseMix);
   rmSetAreaBaseHeight(westIslandCliffs, 3.2);
   rmAddAreaConstraint(westIslandCliffs, islandAvoidTradeRoute);
   rmSetAreaElevationType(westIslandCliffs, cElevTurbulence);
   rmSetAreaElevationMinFrequency(westIslandCliffs, 0.09);
   rmSetAreaElevationVariation(westIslandCliffs, 4.0);
   rmSetAreaElevationPersistence(westIslandCliffs, 0.2);
   rmSetAreaElevationNoiseBias(westIslandCliffs, 1);
   rmAddAreaConstraint(westIslandCliffs, islandConstraint);
   rmAddAreaConstraint(westIslandCliffs, avoidBonusIslands);
   rmAddAreaToClass(westIslandCliffs, classIsland);

   if (cNumberNonGaiaPlayers == 6 && cNumberTeams == 2){
      rmSetAreaLocation(westIslandCliffs, 0.2, 0.6);
      rmSetAreaSize(westIslandCliffs, 0.07, 0.07);
      rmAddAreaInfluenceSegment(westIslandCliffs, 0.3, 0.75, 0.2, 0.6);
      rmAddAreaInfluenceSegment(westIslandCliffs, 0.2, 0.4, 0.2, 0.6);
      }

   else{
      if (cNumberNonGaiaPlayers <= 3){
         rmSetAreaLocation(westIslandCliffs, 0.3, 0.7);
         rmSetAreaSize(westIslandCliffs, 0.045, 0.045);
         }
      else{
         if (cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5){
            rmSetAreaLocation(westIslandCliffs, 0.3, 0.7);
            rmSetAreaSize(westIslandCliffs, 0.065, 0.065);
            }
         else {
            rmSetAreaLocation(westIslandCliffs, 0.3, 0.7);
            rmSetAreaSize(westIslandCliffs, 0.12, 0.12);
            rmAddAreaInfluenceSegment(westIslandCliffs, 0.6, 0.8, 0.3, 0.7);
            rmAddAreaInfluenceSegment(westIslandCliffs, 0.2, 0.4, 0.3, 0.7);
            }
         }
      }
      
   rmBuildArea(westIslandCliffs);

   // North Island

   int northIslandCliffs = rmCreateArea ("north Island cliffs");
   rmSetAreaLocation(northIslandCliffs, 0.7, 0.7);
   rmSetAreaCoherence(northIslandCliffs, 0.6);
   rmSetAreaMinBlobs(northIslandCliffs, 8);
   rmSetAreaMaxBlobs(northIslandCliffs, 12);
   rmSetAreaMinBlobDistance(northIslandCliffs, 8.0);
   rmSetAreaMaxBlobDistance(northIslandCliffs, 10.0);
   rmSetAreaSmoothDistance(northIslandCliffs, 15);

   rmSetAreaMix(northIslandCliffs, baseMix);
   rmSetAreaBaseHeight(northIslandCliffs, 3.2);
   rmAddAreaConstraint(northIslandCliffs, islandAvoidTradeRoute);
   rmSetAreaElevationType(northIslandCliffs, cElevTurbulence);
   rmSetAreaElevationMinFrequency(northIslandCliffs, 0.09);
   rmSetAreaElevationVariation(northIslandCliffs, 4.0);
   rmSetAreaElevationPersistence(northIslandCliffs, 0.2);
   rmSetAreaElevationNoiseBias(northIslandCliffs, 1);
   rmAddAreaConstraint(northIslandCliffs, islandConstraint);
   rmAddAreaConstraint(northIslandCliffs, avoidBonusIslands);
   rmAddAreaToClass(northIslandCliffs, classIsland);
   if (cNumberTeams == 2 && cNumberNonGaiaPlayers == 6){
      rmSetAreaSize(northIslandCliffs, 0.07, 0.07);
      rmAddAreaInfluenceSegment(northIslandCliffs, 0.8, 0.55, 0.7, 0.7);
      rmAddAreaInfluenceSegment(northIslandCliffs, 0.55, 0.8, 0.7, 0.7);
      rmBuildArea(northIslandCliffs);
   }


   // --------------------- Player Areas ------------------------

   float playerFraction=rmAreaTilesToFraction(2500 - cNumberNonGaiaPlayers*130);

   for(i=1; <cNumberPlayers)
   {
      // Create the Player's area.
      int playerID=rmCreateArea("player "+i);
      rmSetPlayerArea(i, playerID);
      rmSetAreaSize(playerID, playerFraction);
      rmAddAreaToClass(playerID, classIsland);
      rmSetAreaLocPlayer(playerID, i);
      rmSetAreaWarnFailure(playerID, false);
      rmSetAreaCoherence(playerID, 0.5);
      rmSetAreaBaseHeight(playerID, 2.5);
      rmSetAreaSmoothDistance(playerID, 20);
      rmSetAreaMix(playerID, baseMix);
      rmAddAreaToClass(playerID, classAtol);
      rmAddAreaToClass(playerID, classPlayerArea);
      rmAddAreaConstraint(playerID, avoidAtol);
      rmAddAreaConstraint(playerID, avoidBonusIslands);
      rmAddAreaConstraint(playerID, islandAvoidTradeRoute);
      rmSetAreaCliffType(playerID, "Africa Desert Grass");
      rmSetAreaCliffPainting(playerID, true, false, true);
      rmSetAreaCliffEdge(playerID, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(playerID, 3.2, 0.0, 0.5);
      rmEchoInfo("Team area"+i);
      rmBuildArea(playerID); 

      int playerCliffTerrain=rmCreateArea("player terrain"+i); 
      rmSetPlayerArea(i, playerCliffTerrain);
      rmSetAreaLocPlayer(playerCliffTerrain, i);
      rmSetAreaSize(playerCliffTerrain, playerFraction);
      rmSetAreaCoherence(playerCliffTerrain, 0.5);
      rmSetAreaMix(playerCliffTerrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(playerCliffTerrain, false);
      rmEchoInfo("Team area 2"+i);
      rmBuildArea(playerCliffTerrain);

      }

   // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);


  // ----------------- Place TC and Player Resources ----------------------


   //Prepare to place Explorers, Explorer's dog, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "mine", 1, 0);
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
  

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 5.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
   rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 15.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 17.0);
  

	int waterSpawnPointID = 0;


   int FortD = rmCreateObjectDef("player TC Fort");
      if (rmGetNomadStart())
         {
            rmAddObjectDefItem(FortD, "CoveredWagon", 1, 0.0);
         }
      else{
         rmAddObjectDefItem(FortD, "zpSPCWaterSpawnPoint", 1, 0.0);
      }

   for(i=1; <cNumberPlayers) {

    

   // Place town centers
   rmPlaceObjectDefAtLoc(FortD, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

   vector FortLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(FortD, i));
   
   if (rmGetNomadStart()){}
	else{
		int playerFortID = -1;
      playerFortID = rmCreateGrouping("player fort", "malta_player_fort");      
      rmPlaceGroupingAtLoc(playerFortID, i, rmXMetersToFraction(xsVectorGetX(FortLoc)), rmZMetersToFraction(xsVectorGetZ(FortLoc)), 1);
      }


    
   // Place TC and starting units
	rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(FortLoc)), rmZMetersToFraction(xsVectorGetZ(FortLoc)));

    
   if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(FortLoc)), rmZMetersToFraction(xsVectorGetZ(FortLoc)));
    
	// Place water spawn points for the players along with a canoe
   waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
   rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 2.0);
   rmAddClosestPointConstraint(flagVsFlag);
   rmAddClosestPointConstraint(flagVsPirates1);
   rmAddClosestPointConstraint(flagVsPirates2);
   rmAddClosestPointConstraint(flagLand);
   rmAddClosestPointConstraint(flagEdgeConstraint);

   vector closestPoint = rmFindClosestPointVector(FortLoc, rmXFractionToMeters(1.0));

   rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
     
	rmClearClosestPointConstraints();

   }


   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);



   // Place additional Natives

    int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, 80);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID, avoidPlayerArea);

      int malteseControllerID2 = rmCreateObjectDef("maltese controller 2");
      rmAddObjectDefItem(malteseControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID2, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID2, 80);
      rmAddObjectDefConstraint(malteseControllerID2, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID2, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID2, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID2, avoidPlayerArea);

      int malteseControllerID3 = rmCreateObjectDef("maltese controller 3");
      rmAddObjectDefItem(malteseControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID3, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID3, 80);
      rmAddObjectDefConstraint(malteseControllerID3, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID3, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID3, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID3, avoidPlayerArea);

      int malteseControllerID4 = rmCreateObjectDef("maltese controller 4");
      rmAddObjectDefItem(malteseControllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID4, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID4, 80);
      rmAddObjectDefConstraint(malteseControllerID4, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID4, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID4, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID4, avoidPlayerArea);

      int malteseControllerID5 = rmCreateObjectDef("maltese controller 5");
      rmAddObjectDefItem(malteseControllerID5, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID5, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID5, 80);
      rmAddObjectDefConstraint(malteseControllerID5, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID5, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID5, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID5, avoidPlayerArea);
      
      int malteseControllerID6 = rmCreateObjectDef("maltese controller 6");
      rmAddObjectDefItem(malteseControllerID6, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID6, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID6, 80);
      rmAddObjectDefConstraint(malteseControllerID6, avoidWater20);
      rmAddObjectDefConstraint(malteseControllerID6, avoidTradeSockets);
      rmAddObjectDefConstraint(malteseControllerID6, avoidControllerFar);
      rmAddObjectDefConstraint(malteseControllerID6, avoidPlayerArea);

      if(cNumberNonGaiaPlayers <= 3){
         rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.8, 0.4);
         vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.6, 0.2);
         vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.3, 0.7);
         vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
         }
      if(cNumberNonGaiaPlayers == 4){
         rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.4, 0.8);
         malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.2, 0.6);
         malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.6, 0.2);
         malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.8, 0.4);
         vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));
         }
      if(cNumberNonGaiaPlayers == 5){
         rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.8, 0.4);
         malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.6, 0.2);
         malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.3, 0.7);
         malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
         }
      if(cNumberNonGaiaPlayers == 6){
         if(cNumberTeams == 2){
            rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.2, 0.6);
            malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
            rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.6, 0.2);
            malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
            rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.7, 0.7);
            malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
            }
         else{
            rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.4, 0.8);
            malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
            rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.2, 0.6);
            malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
            rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.6, 0.2);
            malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
            rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.8, 0.4);
            malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));
            }
         }
      if(cNumberNonGaiaPlayers == 7){
         rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.5, 0.8);
         malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.2, 0.5);
         malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.5, 0.2);
         malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.8, 0.5);
         malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID5, 0, 0.7, 0.3);
         vector malteseControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID5, 0));
         }
      if(cNumberNonGaiaPlayers == 8){
         rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.5, 0.8);
         malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID2, 0, 0.2, 0.5);
         malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID2, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID3, 0, 0.5, 0.2);
         malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID3, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID4, 0, 0.8, 0.5);
         malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID4, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID5, 0, 0.7, 0.3);
         malteseControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID5, 0));
         rmPlaceObjectDefAtLoc(malteseControllerID6, 0, 0.3, 0.7);
         vector malteseControllerLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID6, 0));
         }

      int eastIslandVillage1 = rmCreateArea ("east island village 1");
      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaCliffType(eastIslandVillage1, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage1, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage1, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmAddAreaConstraint(eastIslandVillage1, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage1, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage1, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage1);

      int eastIslandVillage1Terrain=rmCreateArea("village 1 terrain"+i); 
      rmSetAreaSize(eastIslandVillage1Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage1Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage1Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage1Terrain, false);
      rmBuildArea(eastIslandVillage1Terrain);

      int eastIslandVillage2 = rmCreateArea ("east island village 2");
      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      rmSetAreaCliffType(eastIslandVillage2, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage2, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage2, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmAddAreaConstraint(eastIslandVillage2, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage2, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage2, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage2);

      int eastIslandVillage2Terrain=rmCreateArea("village 2 terrain"+i); 
      rmSetAreaSize(eastIslandVillage2Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage2Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage2Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage2Terrain, false);
      rmBuildArea(eastIslandVillage2Terrain);

      int eastIslandVillage3 = rmCreateArea ("east island village 3");
      rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage3, 5);
      rmSetAreaCliffType(eastIslandVillage3, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage3, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage3, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage3, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
      rmAddAreaConstraint(eastIslandVillage3, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage3, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage3, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage3);

      int eastIslandVillage3Terrain=rmCreateArea("village 3 terrain"+i); 
      rmSetAreaSize(eastIslandVillage3Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage3Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage3Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage3Terrain, false);
      rmBuildArea(eastIslandVillage3Terrain);

      int eastIslandVillage4 = rmCreateArea ("east island village 4");
      rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
      rmSetAreaCoherence(eastIslandVillage4, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage4, 5);
      rmSetAreaCliffType(eastIslandVillage4, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage4, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage4, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage4, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
      rmAddAreaConstraint(eastIslandVillage4, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage4, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage4, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage4);

      int eastIslandVillage4Terrain=rmCreateArea("village 4 terrain"+i); 
      rmSetAreaSize(eastIslandVillage4Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage4Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
      rmSetAreaCoherence(eastIslandVillage4Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage4Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage4Terrain, false);
      rmBuildArea(eastIslandVillage4Terrain);

      int eastIslandVillage5 = rmCreateArea ("east island village 5");
      rmSetAreaSize(eastIslandVillage5, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage5, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)));
      rmSetAreaCoherence(eastIslandVillage5, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage5, 5);
      rmSetAreaCliffType(eastIslandVillage5, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage5, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage5, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage5, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage5, 0.0);
      rmAddAreaConstraint(eastIslandVillage5, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage5, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage5, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage5);

      int eastIslandVillage5Terrain=rmCreateArea("village 5 terrain"+i); 
      rmSetAreaSize(eastIslandVillage5Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage5Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)));
      rmSetAreaCoherence(eastIslandVillage5Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage5Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage5Terrain, false);
      rmBuildArea(eastIslandVillage5Terrain);

      int eastIslandVillage6 = rmCreateArea ("east island village 6");
      rmSetAreaSize(eastIslandVillage6, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage6, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)));
      rmSetAreaCoherence(eastIslandVillage6, 0.6);
      rmSetAreaSmoothDistance(eastIslandVillage6, 5);
      rmSetAreaCliffType(eastIslandVillage6, "Africa Desert Grass");
      rmSetAreaCliffEdge(eastIslandVillage6, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage6, 3.2, 0.0, 0.5);
      rmSetAreaBaseHeight(eastIslandVillage6, 2.5);
      rmSetAreaElevationVariation(eastIslandVillage6, 0.0);
      rmAddAreaConstraint(eastIslandVillage6, avoidBonusIslands);
      rmAddAreaConstraint(eastIslandVillage6, avoidTradeSocketsShort);
      rmAddAreaConstraint(eastIslandVillage6, islandAvoidTradeRoute);
      rmBuildArea(eastIslandVillage6);

      int eastIslandVillage6Terrain=rmCreateArea("village 6 terrain"+i); 
      rmSetAreaSize(eastIslandVillage6Terrain, rmAreaTilesToFraction(1200.0), rmAreaTilesToFraction(1200.0));
      rmSetAreaLocation(eastIslandVillage6Terrain, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)));
      rmSetAreaCoherence(eastIslandVillage6Terrain, 0.5);
      rmSetAreaMix(eastIslandVillage6Terrain, "Africa Desert Grass");
      rmSetAreaObeyWorldCircleConstraint(eastIslandVillage6Terrain, false);
      rmBuildArea(eastIslandVillage6Terrain);



  
    int jesuit1VillageID = -1;

      int jesuit1VillageType = rmRandInt(1,5);
      jesuit1VillageID = rmCreateGrouping("jesuit 1", "Maltese_Village0"+jesuit1VillageType);
    rmAddGroupingConstraint(jesuit1VillageID , avoidImpassableLand);


    int jesuit2VillageID = -1;
      int jesuit2VillageType = rmRandInt(1,5);
      jesuit2VillageID = rmCreateGrouping("jesuit 2", "Maltese_Village0"+jesuit2VillageType);
    rmAddGroupingConstraint(jesuit2VillageID , avoidImpassableLand);

    int jesuit3VillageID = -1;
      int jesuit3VillageType = rmRandInt(1,5);
      jesuit3VillageID = rmCreateGrouping("jesuit 3", "Maltese_Village0"+jesuit3VillageType);
    rmAddGroupingConstraint(jesuit3VillageID , avoidImpassableLand);

    int jesuit4VillageID = -1;
      int jesuit4VillageType = rmRandInt(1,5);
      jesuit4VillageID = rmCreateGrouping("jesuit 4", "Maltese_Village0"+jesuit4VillageType);
    rmAddGroupingConstraint(jesuit4VillageID , avoidImpassableLand);

    int jesuit5VillageID = -1;
      int jesuit5VillageType = rmRandInt(1,5);
      jesuit5VillageID = rmCreateGrouping("jesuit 5", "Maltese_Village0"+jesuit5VillageType);
    rmAddGroupingConstraint(jesuit5VillageID , avoidImpassableLand);

    int jesuit6VillageID = -1;
      int jesuit6VillageType = rmRandInt(1,5);
      jesuit6VillageID = rmCreateGrouping("jesuit 6", "Maltese_Village0"+jesuit6VillageType);
    rmAddGroupingConstraint(jesuit6VillageID , avoidImpassableLand);



  rmPlaceGroupingAtLoc(jesuit1VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)), 1);
  rmPlaceGroupingAtLoc(jesuit2VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)), 1);
  
  rmPlaceGroupingAtLoc(jesuit3VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)), 1);

  rmPlaceGroupingAtLoc(jesuit4VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);
  rmPlaceGroupingAtLoc(jesuit5VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc5)), 1);
    rmPlaceGroupingAtLoc(jesuit6VillageID , 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc6)), 1);
	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.70);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
  int forestTreeID = 0;
  numTries=10*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(120));
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
    rmAddAreaConstraint(forest, avoidJesuit);
    rmAddAreaConstraint(forest, avoidTP);
    rmAddAreaConstraint(forest, avoidAfrica);
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

  int failCount2=0;
  for (i=0; <numTries/4) {   
    int forest2=rmCreateArea("forest2 "+i);
    rmSetAreaWarnFailure(2, false);
    rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(150));
    rmSetAreaForestType(forest2, forestType2);
    rmSetAreaForestDensity(forest2, 0.6);
    rmSetAreaForestClumpiness(forest2, 0.1);
    rmSetAreaForestUnderbrush(forest2, 0.6);
    rmSetAreaMinBlobs(forest2, 1);
    rmSetAreaMaxBlobs(forest2, 5);
    rmSetAreaMinBlobDistance(forest2, 16.0);
    rmSetAreaMaxBlobDistance(forest2, 40.0);
    rmSetAreaCoherence(forest2, 0.4);
    rmSetAreaSmoothDistance(forest2, 10);
    rmAddAreaToClass(forest2, rmClassID("classForest")); 
    rmAddAreaConstraint(forest2, forestConstraint);
    rmAddAreaConstraint(forest2, avoidAll);
    rmAddAreaConstraint(forest2, avoidJesuit);
    rmAddAreaConstraint(forest2, avoidTP);
    rmAddAreaConstraint(forest2, avoidController);
    rmAddAreaConstraint(forest2, avoidKOTH);
    rmAddAreaConstraint(forest2, avoidTCMedium);
    rmAddAreaConstraint(forest2, avoidEurope);
    rmAddAreaConstraint(forest2, shortAvoidImpassableLand);  
    if(rmBuildArea(forest2)==false) {
      // Stop trying once we fail 3 times in a row.
      failCount2++;
      
      if(failCount2==5)
        break;
    }
    
    else
      failCount2=0; 
  } 


    
    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);


   int silverID = rmCreateObjectDef("random silver");
   rmAddObjectDefItem(silverID, "mine", 1, 0);
   rmSetObjectDefMinDistance(silverID, 0.0);
   rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.3));
   rmAddObjectDefConstraint(silverID, avoidAll);
   rmAddObjectDefConstraint(silverID, avoidWater8);
   rmAddObjectDefConstraint(silverID, avoidGold);
   rmAddObjectDefConstraint(silverID, avoidCoin);
   rmAddAreaConstraint(silverID, avoidPirates);
   rmAddObjectDefConstraint(silverID, avoidController);
   rmAddAreaConstraint(silverID, avoidJesuit);
   rmAddAreaConstraint(silverID, avoidWokou);
   rmAddObjectDefConstraint(silverID, avoidTCLong);
   rmAddObjectDefConstraint(silverID, avoidTP);
   rmAddObjectDefConstraint(silverID, avoidImportantItem);
   rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);

   if(cNumberNonGaiaPlayers <= 3){
      rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers/2);
   }
   if(cNumberNonGaiaPlayers == 4){
      rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }
   if(cNumberNonGaiaPlayers == 5){
      rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers-1);
   }
   if(cNumberNonGaiaPlayers == 6){
      if(cNumberTeams == 2){
         rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers-21);
         rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
         rmPlaceObjectDefInArea(silverID, 0, northIslandCliffs, cNumberNonGaiaPlayers-2);
      }
      else{
         rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
         rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
      }
   }
   if(cNumberNonGaiaPlayers == 7){
      rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
   }
   if(cNumberNonGaiaPlayers == 8){
      rmPlaceObjectDefInArea(silverID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(silverID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }

   int southmineID = rmCreateObjectDef("bonus mine "+i);
   rmAddObjectDefItem(southmineID, "deShipRuins", 1, 0.0);
   rmSetObjectDefMinDistance(southmineID, 0.0);
   rmSetObjectDefMaxDistance(southmineID, rmXFractionToMeters(0.45));
   rmAddObjectDefConstraint(southmineID, avoidCoin);
   rmAddAreaConstraint(southmineID, avoidKOTH);
   rmAddObjectDefConstraint(southmineID, avoidAll);
   rmAddObjectDefConstraint(southmineID, shortAvoidImpassableLand);
   rmPlaceObjectDefInArea(southmineID,, 0, smallIsland1ID, 1);
   rmPlaceObjectDefInArea(southmineID,, 0, smallIsland2ID, 1);

   
   
	// Scattered berries all over island
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 4.0); 
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(berriesID, avoidTP);   
	rmAddObjectDefConstraint(berriesID, avoidAll);
   rmAddAreaConstraint(berriesID, avoidJesuit);
  rmAddObjectDefConstraint(berriesID, avoidImportantItem);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, shortAvoidImpassableLand);
  
  if(cNumberNonGaiaPlayers <= 3){
      rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers/2);
   }
   if(cNumberNonGaiaPlayers == 4){
      rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }
   if(cNumberNonGaiaPlayers == 5){
      rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers-1);
   }
   if(cNumberNonGaiaPlayers == 6){
      if(cNumberTeams == 2){
         rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers-21);
         rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
         rmPlaceObjectDefInArea(berriesID, 0, northIslandCliffs, cNumberNonGaiaPlayers-2);
      }
      else{
         rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
         rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
      }
   }
   if(cNumberNonGaiaPlayers == 7){
      rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
   }
   if(cNumberNonGaiaPlayers == 8){
      rmPlaceObjectDefInArea(berriesID, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(berriesID, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }

	// Huntables scattered on N side of island
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, huntable1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHuntable1);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(foodID1, northConstraint);
  rmAddObjectDefConstraint(foodID1, avoidController);
  rmAddObjectDefConstraint(foodID1, avoidTP);
  rmAddObjectDefConstraint(foodID1, avoidImportantItem);
	
   if(cNumberNonGaiaPlayers <= 3){
      rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers/2);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
   }
   if(cNumberNonGaiaPlayers == 4){
      rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
   }
   if(cNumberNonGaiaPlayers == 5){
      rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers-1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
   }
   if(cNumberNonGaiaPlayers == 6){
      if(cNumberTeams == 2){
         rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers-21);
         rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
         rmPlaceObjectDefInArea(foodID1, 0, northIslandCliffs, cNumberNonGaiaPlayers-2);
         rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
      }
      else{
         rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
         rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
         rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
      }
   }
   if(cNumberNonGaiaPlayers == 7){
      rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
   }
   if(cNumberNonGaiaPlayers == 8){
      rmPlaceObjectDefInArea(foodID1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland1ID, 1);
      rmPlaceObjectDefInArea(foodID1, 0, smallIsland2ID, 1);
   }

  
	// Define and place Nuggets
    
	// Easier nuggets North
	int nugget1= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 3);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
  rmAddObjectDefConstraint(nugget1, avoidImportantItem);
	rmAddObjectDefConstraint(nugget1, avoidTP);
   rmAddAreaConstraint(nugget1, avoidJesuit);
	rmAddObjectDefConstraint(nugget1, avoidAll);
  rmAddObjectDefConstraint(nugget1, avoidController);
	rmAddObjectDefConstraint(nugget1, avoidWater8);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);

  if(cNumberNonGaiaPlayers <= 3){
      rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers/2);
   }
   if(cNumberNonGaiaPlayers == 4){
      rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }
   if(cNumberNonGaiaPlayers == 5){
      rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers-1);
   }
   if(cNumberNonGaiaPlayers == 6){
      if(cNumberTeams == 2){
         rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers-21);
         rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
         rmPlaceObjectDefInArea(nugget1, 0, northIslandCliffs, cNumberNonGaiaPlayers-2);
      }
      else{
         rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
         rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
      }
   }
   if(cNumberNonGaiaPlayers == 7){
      rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers-2);
   }
   if(cNumberNonGaiaPlayers == 8){
      rmPlaceObjectDefInArea(nugget1, 0, eastIslandCliffs, cNumberNonGaiaPlayers);
      rmPlaceObjectDefInArea(nugget1, 0, westIslandCliffs, cNumberNonGaiaPlayers);
   }

  // Harder nuggets North
	int nugget2= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
  rmAddObjectDefConstraint(nugget2, avoidImportantItem);
  rmAddObjectDefConstraint(nugget2, avoidController);
	rmAddObjectDefConstraint(nugget2, avoidTP);
	rmAddObjectDefConstraint(nugget2, avoidAll);
   rmAddAreaConstraint(nugget2, avoidKOTH);
	rmAddObjectDefConstraint(nugget2, avoidWater4);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
   rmPlaceObjectDefInArea(nugget2, 0, smallIsland2ID, 1);
   rmPlaceObjectDefInArea(nugget2, 0, smallIsland1ID, 2);

    // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "TreeTexas", 1, 0.0);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage1, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage2, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage3, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage4, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage5, 7);
   rmPlaceObjectDefInArea(villageTreeID, 0,  eastIslandVillage6, 7);


	// Water nuggets
  int nuggetCount = cNumberNonGaiaPlayers;
  
  int nuggetWater= rmCreateObjectDef("nugget water" + i); 
  rmAddObjectDefItem(nuggetWater, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetWater, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetWater, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetWater, avoidLand);
  rmAddObjectDefConstraint(nuggetWater, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetWater, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetWater, flagVsFlag);
  rmAddObjectDefConstraint(nuggetWater, avoidPortArea);
  rmAddObjectDefConstraint(nuggetWater, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nuggetWater, false, nuggetCount);

  int nuggetWaterb = rmCreateObjectDef("nugget water hard" + i); 
  rmAddObjectDefItem(nuggetWaterb, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(6, 6);
  rmSetObjectDefMinDistance(nuggetWaterb, rmXFractionToMeters(0.25));
  rmSetObjectDefMaxDistance(nuggetWaterb, rmXFractionToMeters(1.0));
  rmAddObjectDefConstraint(nuggetWaterb, avoidLand);
  rmAddObjectDefConstraint(nuggetWaterb, flagVsFlag);
  rmAddObjectDefConstraint(nuggetWaterb, avoidNuggetWater2);
  rmAddObjectDefConstraint(nuggetWaterb, ObjectAvoidTradeRoute);
  rmAddObjectDefConstraint(nuggetWaterb, avoidPortArea);
  rmAddObjectDefConstraint(nuggetWaterb, playerEdgeConstraint);
  rmPlaceObjectDefPerPlayer(nuggetWaterb, false, nuggetCount);
  

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place random whales everywhere --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.15));
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
  rmAddObjectDefConstraint(whaleID, avoidControllerFar);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*5); 

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
  rmAddObjectDefConstraint(fishID, avoidControllerMediumFar);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 35*cNumberNonGaiaPlayers);



    // Starter shipment triggers

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
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",i);
rmSetTriggerEffectParam("TechID","cTechzpAdralicMercenaries"); // Mercenaries
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