// AZTEC GOLD v1.0
//1v1 Balance update by Durokan for DE
// February 2021 edited by vividlyplain, updated May 2021 and again October 2021

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
		subCiv0=rmGetCivID("natpirates");
      rmEchoInfo("subCiv0 is pirates "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "natpirates");

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
	int playerTiles = 13000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 10000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 8000;			

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
   int classTeamIsland=rmDefineClass("teamIsland");
   int classMountains=rmDefineClass("mountains");
   string baseMix = "texas_grass";


   // -------------Define constraints
   // These are used to have objects and areas avoid each other
   
   // Map edge constraints
      int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.43), rmDegreesToRadians(0), rmDegreesToRadians(360));
      int villageEdgeConstraint=rmCreatePieConstraint("village edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.40), rmDegreesToRadians(0), rmDegreesToRadians(360));
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
   int islandConstraintShort=rmCreateClassDistanceConstraint("islands avoid each other short", classIsland, 7.0);
   int avoidNatives=rmCreateClassDistanceConstraint("avoid natives", classNative, 8.0);
   int avoidNativesFar=rmCreateClassDistanceConstraint("avoid natives far", classNative, 32.0);
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
   int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 7.0);

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
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 20.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 4.5);

   // Unit avoidance
   int avoidImportantItem=rmCreateClassDistanceConstraint("avoid natives, secrets", rmClassID("importantItem"), 30.0);
   int farAvoidImportantItem=rmCreateClassDistanceConstraint("secrets avoid each other by a lot", rmClassID("importantItem"), 50.0);
   int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 25.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);

   // Decoration avoidance
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidCliff=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);

     // Trade route avoidance.
   int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 5.0);
   int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 15.0);
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route island", 7.0);
   int islandAvoidTradeRouteLong = rmCreateTradeRouteDistanceConstraint("trade route island long", 20+2*cNumberNonGaiaPlayers);

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
     int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 70.0);

   // -------------Define objects
   // These objects are all defined so they can be placed later

 	// Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      int plrLineDirection = rmRandInt(0,1);

		float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(teamStartLoc > 0.5)
		{
			rmSetPlacementSection(0.10, 0.90);
			rmSetTeamSpacingModifier(0.75);
         if(plrLineDirection > 0.5) {
			   rmPlacePlayersLine(0.4, 0.9, 0.9, 0.4, 0.5, 0.5);
         }
         else {
			   rmPlacePlayersLine(0.9, 0.4, 0.4, 0.9, 0.5, 0.5);
         }
		}
        else
        {
			rmSetPlacementSection(0.10, 0.90);
			rmSetTeamSpacingModifier(0.75);
         if(plrLineDirection > 0.5) {
			   rmPlacePlayersLine(0.1, 0.6, 0.6, 0.1, 0.5, 0.5);
            }
         else {
			   rmPlacePlayersLine(0.6, 0.1, 0.1, 0.6, 0.5, 0.5);
         }
		}
		
 


	// -------------Done defining objects

  // Text
   rmSetStatusText("",0.10);


   //  Rivers
/*
   // Build the main river which defines the map more-or-less.
	int amazonRiver = rmRiverCreate(-1, "Amazon River", 5, 18, 10, 10);
	if (cNumberNonGaiaPlayers >2)
		amazonRiver = rmRiverCreate(-1, "Amazon River", 6, 30, 14, 17);
	if (cNumberNonGaiaPlayers >4)
		amazonRiver = rmRiverCreate(-1, "Amazon River", 6, 30, 16, 20);
	if (cNumberNonGaiaPlayers >6)
		amazonRiver = rmRiverCreate(-1, "Amazon River", 6, 30, 18, 22);
   rmRiverSetConnections(amazonRiver, 0.0, 1.0, 1.0, 0.0);
   //rmRiverSetShallowRadius(amazonRiver, 10);
   //rmRiverAddShallow(amazonRiver, rmRandFloat(0.2, 0.2));
   //rmRiverAddShallow(amazonRiver, rmRandFloat(0.8, 0.8));
   rmRiverSetBankNoiseParams(amazonRiver, 0.07, 2, 1.5, 20.0, 0.667, 2.0);
   rmRiverBuild(amazonRiver);
   rmRiverReveal(amazonRiver, 2);  

 */

 // Water Trade Route
  int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(tradeRouteID);
   
   
    rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.9);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.1);


    bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "native_water_trail");

   int playerIslandID = rmCreateArea("north island");
   int areaSizerNum = rmRandInt(1,10);
   float areaSizer = 0.33; 
   if (areaSizerNum > 6)
	   areaSizer = 0.40-0.005*cNumberNonGaiaPlayers;
   rmEchoInfo("Island size "+areaSizer);
   
   // Make areas for the main islands... kinda hacky I guess, but it works.
   // Build an invisible north island area.
   
   //rmSetAreaLocation(playerIslandID, 0.75, 0.75);
   if(teamStartLoc > 0.5){
      rmSetAreaLocation(playerIslandID, 1, 1);
   }
   else{
      rmSetAreaLocation(playerIslandID, 0, 0);
   }
   rmSetAreaMix(playerIslandID, "texas_grass");
   //rmSetAreaSize(playerIslandID, 0.5, 0.5);
   rmSetAreaCoherence(playerIslandID, 1.0);
   //rmAddAreaConstraint(playerIslandID, avoidWater4);
   //rmSetAreaSize(playerIslandID, isleSize, isleSize);
	rmSetAreaSize(playerIslandID, 0.45, 0.45);
      rmSetAreaMinBlobs(playerIslandID, 10);
      rmSetAreaMaxBlobs(playerIslandID, 15);
      rmSetAreaMinBlobDistance(playerIslandID, 8.0);
      rmSetAreaMaxBlobDistance(playerIslandID, 10.0);
      rmSetAreaCoherence(playerIslandID, 0.60);
      rmSetAreaBaseHeight(playerIslandID, 3.0);
      rmSetAreaSmoothDistance(playerIslandID, 20);
		rmSetAreaMix(playerIslandID, "texas_grass_Skrimish");
      rmAddAreaToClass(playerIslandID, classIsland);
      rmAddAreaConstraint(playerIslandID, islandConstraint);
      rmAddAreaConstraint(playerIslandID, islandAvoidTradeRoute);
      rmSetAreaObeyWorldCircleConstraint(playerIslandID, false);
//      rmSetAreaElevationType(playerIslandID, cElevTurbulence);
//      rmSetAreaElevationVariation(playerIslandID, 3.0);
//      rmSetAreaElevationMinFrequency(playerIslandID, 0.09);
//      rmSetAreaElevationOctaves(playerIslandID, 3);
//      rmSetAreaElevationPersistence(playerIslandID, 0.2);
//		rmSetAreaElevationNoiseBias(playerIslandID, 1);
      rmSetAreaWarnFailure(playerIslandID, false);
//      if(cNumberNonGaiaPlayers==2){
//        rmSetAreaEdgeFilling(playerIslandID, 3);
//      }
   //rmBuildArea(playerIslandID);

   // Build an invisible south island area.
   
  int nativeIslandID = rmCreateArea("south island");
   //rmSetAreaLocation(nativeIslandID, 0.25, 0.25);
   if(teamStartLoc > 0.5){
      rmSetAreaLocation(nativeIslandID, 0, 0);
   }
   else{
      rmSetAreaLocation(nativeIslandID, 1, 1);
   }
   rmSetAreaMix(nativeIslandID, "yucatan_grass");
  // rmSetAreaSize(nativeIslandID, 0.5, 0.5);
   rmSetAreaCoherence(nativeIslandID, 1.0);
   //rmAddAreaConstraint(nativeIslandID, avoidWater4);
   rmSetAreaSize(nativeIslandID, 0.3, 0.3);
      rmSetAreaMinBlobs(nativeIslandID, 10);
      rmSetAreaMaxBlobs(nativeIslandID, 15);
      rmSetAreaMinBlobDistance(nativeIslandID, 8.0);
      rmSetAreaMaxBlobDistance(nativeIslandID, 10.0);
      rmSetAreaCoherence(nativeIslandID, 0.60);
      rmSetAreaBaseHeight(nativeIslandID, 3.0);
      rmSetAreaSmoothDistance(nativeIslandID, 20);
	  rmSetAreaMix(nativeIslandID, "yucatan_grass");
         rmAddAreaTerrainLayer(nativeIslandID, "Amazon\ground5_ama", 0, 4);
         rmAddAreaTerrainLayer(nativeIslandID, "Amazon\ground4_ama", 4, 6);
         rmAddAreaTerrainLayer(nativeIslandID, "Amazon\ground3_ama", 6, 9);
         rmAddAreaTerrainLayer(nativeIslandID, "Amazon\ground2_ama", 9, 12);

      rmAddAreaToClass(nativeIslandID, classIsland);
      rmAddAreaConstraint(nativeIslandID, islandConstraint);
      rmAddAreaConstraint(nativeIslandID, islandAvoidTradeRouteLong);
      rmSetAreaObeyWorldCircleConstraint(nativeIslandID, false);
//      rmSetAreaElevationType(nativeIslandID, cElevTurbulence);
//      rmSetAreaElevationVariation(nativeIslandID, 3.0);
//      rmSetAreaElevationMinFrequency(nativeIslandID, 0.09);
//      rmSetAreaElevationOctaves(nativeIslandID, 3);
//      rmSetAreaElevationPersistence(nativeIslandID, 0.2);
//		rmSetAreaElevationNoiseBias(nativeIslandID, 1);
      rmSetAreaWarnFailure(nativeIslandID, false);
   //rmBuildArea(nativeIslandID);



   rmBuildAllAreas();


   // Player Island Cliffs
   int PlayerCliffID1 = rmCreateArea("player island cliff 1");
   if(teamStartLoc > 0.5){
      rmSetAreaLocation(PlayerCliffID1, 0.8, 0.8);
   }
   else{
      rmSetAreaLocation(PlayerCliffID1, 0.2, 0.2);
   }
   rmSetAreaSize(PlayerCliffID1, 0.02, 0.02);
   rmSetAreaCliffType(PlayerCliffID1, "Texas No Cactus");
   rmSetAreaCliffEdge(PlayerCliffID1, 1, 1.0, 0.0, 1.0, 0);
   rmSetAreaCliffHeight(PlayerCliffID1, 1.0, 0.0, 0.0); 
   rmSetAreaBaseHeight(PlayerCliffID1, 8.2);
   rmSetAreaCoherence(PlayerCliffID1, 0.5);
   rmAddAreaToClass(PlayerCliffID1, classMountains);
   rmSetAreaObeyWorldCircleConstraint(PlayerCliffID1, false);

   rmBuildArea(PlayerCliffID1);

   if(cNumberNonGaiaPlayers > 3){
      int PlayerCliffID2 = rmCreateArea("player island cliff 2");
      if(teamStartLoc > 0.5){
      rmSetAreaLocation(PlayerCliffID2, 0.63, 0.63);
      }
      else{
         rmSetAreaLocation(PlayerCliffID2, 0.37, 0.37);
      }
      rmSetAreaSize(PlayerCliffID2, 0.007, 0.007);
      rmSetAreaCliffType(PlayerCliffID2, "Texas No Cactus");
      rmSetAreaCliffEdge(PlayerCliffID2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(PlayerCliffID2, 1.0, 0.0, 0.0); 
      rmSetAreaBaseHeight(PlayerCliffID2, 8.2);
      rmSetAreaCoherence(PlayerCliffID2, 0.5);
      rmAddAreaToClass(PlayerCliffID2, classMountains);
      rmSetAreaObeyWorldCircleConstraint(PlayerCliffID2, false);

      rmBuildArea(PlayerCliffID2);
   }
   // add island constraints
   int playerIslandConstraint=rmCreateAreaConstraint("player Island", playerIslandID);
   int nativeIslandConstraint=rmCreateAreaConstraint("native Island", nativeIslandID);
/*
   // Tributaries
   //northern tributaries
   int tribID1 = -1;
   int tribID2 = -1;
   //southern tributaries
   int tribID3 = -1; 
   int tribID4 = -1; 

   float RiverPlaceN = rmRandFloat(0,1);
   float RiverPlaceS = rmRandFloat(0,1);

*/


   // Text
   rmSetStatusText("",0.20);


  // check for KOTH game mode

	//King's "Island"
	if (rmGetIsKOTH() == true) {
		int kingislandID=rmCreateArea("King's Island");
		rmSetAreaSize(kingislandID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));
		if(teamStartLoc > 0.5){
         rmSetAreaLocation(kingislandID, 0.5-rmXTilesToFraction(20), 0.5-rmXTilesToFraction(20));
      }
      else{
         rmSetAreaLocation(kingislandID, 0.5+rmXTilesToFraction(20), 0.5+rmXTilesToFraction(20));
      }
		rmSetAreaMix(kingislandID, "yucatan_grass");
		rmAddAreaToClass(kingislandID, classIsland);
		rmSetAreaReveal(kingislandID, 01);
		rmSetAreaBaseHeight(kingislandID, 3.0);
		rmSetAreaCoherence(kingislandID, 1.0);
		rmBuildArea(kingislandID); 
	}

	// Place King's Hill
   if (rmGetIsKOTH() == true) {
      if(teamStartLoc > 0.5){
         ypKingsHillPlacer(0.5-rmXTilesToFraction(20), 0.5-rmXTilesToFraction(20), 0, 0);
      }
      else{
         ypKingsHillPlacer(0.5+rmXTilesToFraction(20), 0.5+rmXTilesToFraction(20), 0, 0);
      }
	}

		int avoidKOTH = rmCreateAreaDistanceConstraint("avoid KOTH", kingislandID, 4.0);

   //!!! NATIVES AND PORTS !!!//

   

   // Pirates
   
   int pirateLake1ID = rmCreateArea ("pirate lake 01");
   rmSetAreaSize(pirateLake1ID, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
   if(cNumberNonGaiaPlayers > 3){
      if(teamStartLoc > 0.5){
         rmSetAreaLocation(pirateLake1ID, 0.2+rmXTilesToFraction(4), 0.8+rmXTilesToFraction(4));
      }
      else{
         rmSetAreaLocation(pirateLake1ID, 0.2-rmXTilesToFraction(4), 0.8-rmXTilesToFraction(4));
      }
   }
   else {
      if(teamStartLoc > 0.5){
         rmSetAreaLocation(pirateLake1ID, 0.5+rmXTilesToFraction(4), 0.5+rmXTilesToFraction(4));
      }
      else{
         rmSetAreaLocation(pirateLake1ID, 0.5-rmXTilesToFraction(3), 0.5-rmXTilesToFraction(3));
      }
   }
   rmSetAreaWaterType(pirateLake1ID, "ZP Mexico River");
   rmSetAreaBaseHeight(pirateLake1ID, 0);
   rmSetAreaCoherence(pirateLake1ID, 0.9);
   rmBuildArea(pirateLake1ID);
   

   // Place Controllers
   int controllerID1 = rmCreateObjectDef("Controler 1");
   rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmSetObjectDefMinDistance(controllerID1, 0.0);
   rmSetObjectDefMaxDistance(controllerID1, 0.0);
   rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
   rmAddObjectDefConstraint(controllerID1, playerEdgeConstraint);

   if(cNumberNonGaiaPlayers > 3){
      if(teamStartLoc > 0.5){ 
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.2+rmXTilesToFraction(29), 0.8+rmXTilesToFraction(10));
      }
      else{
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.2-rmXTilesToFraction(10), 0.8-rmXTilesToFraction(29));
      }
   }
   else{
      if(teamStartLoc > 0.5){ 
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5+rmXTilesToFraction(22), 0.5+rmXTilesToFraction(22));
      }
      else{
         rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5-rmXTilesToFraction(22), 0.5-rmXTilesToFraction(22));
      }
   }
   vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

   int controllerID2 = rmCreateObjectDef("Controler 2");
   rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
   rmSetObjectDefMinDistance(controllerID2, 0.0);
	rmSetObjectDefMaxDistance(controllerID2, 0.0);
   rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
   rmAddObjectDefConstraint(controllerID2, playerEdgeConstraint);
   if(teamStartLoc > 0.5){ 
      rmPlaceObjectDefAtLoc(controllerID2, 0, 0.8+rmXTilesToFraction(10), 0.2+rmXTilesToFraction(29));
   }
   else{
      rmPlaceObjectDefAtLoc(controllerID2, 0, 0.8-rmXTilesToFraction(29), 0.2-rmXTilesToFraction(10));
   }
   vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

   int piratesVillageID = -1;
   piratesVillageID = rmCreateGrouping("pirate city", "pirate_village04");      
   rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

   int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
   rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
   rmAddObjectDefConstraint(piratewaterflagID1, avoidTradeRoute);
   rmAddClosestPointConstraint(playerEdgeConstraint);
   rmAddClosestPointConstraint(flagLandShort);

   vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
   rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

   rmClearClosestPointConstraints();

   int pirateportID1 = -1;
   pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport04");
   rmAddClosestPointConstraint(playerEdgeConstraint);
   rmAddClosestPointConstraint(portOnShore);

   vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
   rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
   
   rmClearClosestPointConstraints();

   if(cNumberNonGaiaPlayers>3){
   
      int pirateLake2ID = rmCreateArea ("pirate lake 02");
      rmSetAreaSize(pirateLake2ID, rmAreaTilesToFraction(1000.0), rmAreaTilesToFraction(1000.0));
      if(teamStartLoc > 0.5){
         rmSetAreaLocation(pirateLake2ID, 0.8+rmXTilesToFraction(4), 0.2+rmXTilesToFraction(4));
      }
      else{
         rmSetAreaLocation(pirateLake2ID, 0.8-rmXTilesToFraction(4), 0.2-rmXTilesToFraction(4));
      }
      rmSetAreaWaterType(pirateLake2ID, "ZP Mexico River");
      rmSetAreaBaseHeight(pirateLake2ID, 0);
      rmSetAreaCoherence(pirateLake2ID, 0.9);
      rmBuildArea(pirateLake2ID);

      int piratesVillageID2 = -1;
      piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village05");      
      rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

      int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
      rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
      rmAddObjectDefConstraint(piratewaterflagID2, avoidTradeRoute);
      rmAddClosestPointConstraint(playerEdgeConstraint);
      rmAddClosestPointConstraint(flagLandShort);

      vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

      int pirateportID2 = -1;
      pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport04");
      rmAddClosestPointConstraint(playerEdgeConstraint);
      rmAddClosestPointConstraint(portOnShore);

      vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();
   }


   // Place Ports
   int riverPortID = -1;
   if(cNumberNonGaiaPlayers<=3){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.25+rmXTilesToFraction(9), 0.75+rmXTilesToFraction(9), 1);
         
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.75+rmXTilesToFraction(9), 0.25+rmXTilesToFraction(9), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.25-rmXTilesToFraction(3), 0.75-rmXTilesToFraction(3), 1);
         
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.75-rmXTilesToFraction(3), 0.25-rmXTilesToFraction(3), 1);
      }
   }

   if(cNumberNonGaiaPlayers==4){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35+rmXTilesToFraction(3), 0.65+rmXTilesToFraction(3), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5+rmXTilesToFraction(3), 0.5+rmXTilesToFraction(3), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65+rmXTilesToFraction(3), 0.35+rmXTilesToFraction(3), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35-rmXTilesToFraction(8), 0.65-rmXTilesToFraction(8), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5-rmXTilesToFraction(9), 0.5-rmXTilesToFraction(9), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65-rmXTilesToFraction(8), 0.35-rmXTilesToFraction(8), 1);
      }
   }
   if(cNumberNonGaiaPlayers==5){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35+rmXTilesToFraction(6), 0.65+rmXTilesToFraction(6), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5+rmXTilesToFraction(6), 0.5+rmXTilesToFraction(6), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65+rmXTilesToFraction(6), 0.35+rmXTilesToFraction(6), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35-rmXTilesToFraction(7), 0.65-rmXTilesToFraction(7), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5-rmXTilesToFraction(8), 0.5-rmXTilesToFraction(8), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65-rmXTilesToFraction(7), 0.35-rmXTilesToFraction(7), 1);
      }
   }
   if(cNumberNonGaiaPlayers==6){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35+rmXTilesToFraction(6), 0.65+rmXTilesToFraction(6), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5+rmXTilesToFraction(6), 0.5+rmXTilesToFraction(6), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65+rmXTilesToFraction(6), 0.35+rmXTilesToFraction(6), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35-rmXTilesToFraction(5), 0.65-rmXTilesToFraction(5), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5-rmXTilesToFraction(6), 0.5-rmXTilesToFraction(6), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65-rmXTilesToFraction(5), 0.35-rmXTilesToFraction(5), 1);
      }
   }
   if(cNumberNonGaiaPlayers==7){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35+rmXTilesToFraction(4), 0.65+rmXTilesToFraction(4), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5+rmXTilesToFraction(4), 0.5+rmXTilesToFraction(4), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65+rmXTilesToFraction(4), 0.35+rmXTilesToFraction(4), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35-rmXTilesToFraction(9), 0.65-rmXTilesToFraction(9), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5-rmXTilesToFraction(10), 0.5-rmXTilesToFraction(10), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65-rmXTilesToFraction(9), 0.35-rmXTilesToFraction(9), 1);
      }
   }
   if(cNumberNonGaiaPlayers==8){
      if(teamStartLoc > 0.5){
         riverPortID = rmCreateGrouping("river port 1", "River Port 01");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35+rmXTilesToFraction(7), 0.65+rmXTilesToFraction(7), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5+rmXTilesToFraction(7), 0.5+rmXTilesToFraction(7), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65+rmXTilesToFraction(7), 0.35+rmXTilesToFraction(7), 1);
      }
      else{
         riverPortID = rmCreateGrouping("river port 1", "River Port 02");
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.35-rmXTilesToFraction(4), 0.65-rmXTilesToFraction(4), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.5-rmXTilesToFraction(5), 0.5-rmXTilesToFraction(5), 1);
         rmPlaceGroupingAtLoc(riverPortID, 0, 0.65-rmXTilesToFraction(4), 0.35-rmXTilesToFraction(4), 1);
      }
   }


   // Place Aztecs

   int malteseControllerID = rmCreateObjectDef("maltese controller 1");
      rmAddObjectDefItem(malteseControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(malteseControllerID, 0.0);
      rmSetObjectDefMaxDistance(malteseControllerID, rmXFractionToMeters(0.45));
      rmAddObjectDefConstraint(malteseControllerID, avoidImpassableLand);
      rmAddObjectDefConstraint(malteseControllerID, avoidWater30);
      rmAddObjectDefConstraint(malteseControllerID, avoidController); 
      rmAddObjectDefConstraint(malteseControllerID, nativeIslandConstraint); 
      rmAddObjectDefConstraint(malteseControllerID, villageEdgeConstraintFar); 
      rmPlaceObjectDefAtLoc(malteseControllerID, 0, 0.5, 0.5);
      vector malteseControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseControllerID, 0));

      int eastIslandVillage1 = rmCreateArea ("east island village 1");

      rmSetAreaSize(eastIslandVillage1, rmAreaTilesToFraction(750.0), rmAreaTilesToFraction(750.0));
      rmSetAreaLocation(eastIslandVillage1, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc1)));
      rmSetAreaCoherence(eastIslandVillage1, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage1, 5);
      rmSetAreaBaseHeight(eastIslandVillage1, 3.5);
      rmSetAreaElevationVariation(eastIslandVillage1, 0.0);
      rmBuildArea(eastIslandVillage1);

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
         rmAddObjectDefConstraint(malteseController2ID, avoidWater30);
         rmAddObjectDefConstraint(malteseController2ID, avoidController); 
         rmAddObjectDefConstraint(malteseController2ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController2ID, villageEdgeConstraint); 
         rmPlaceObjectDefAtLoc(malteseController2ID, 0, 0.5, 0.5);
         vector malteseControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController2ID, 0));

         int eastIslandVillage2 = rmCreateArea ("east island village 2");

         rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(750.0), rmAreaTilesToFraction(750.0));
         rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc2)));
         rmSetAreaCoherence(eastIslandVillage2, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage2, 5);
         rmSetAreaBaseHeight(eastIslandVillage2, 3.5);
         rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
         rmBuildArea(eastIslandVillage2);

         int maltese3VillageID = -1;
         int maltese3VillageType = rmRandInt(1,4);
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
         rmAddObjectDefConstraint(malteseController3ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController3ID, villageEdgeConstraint); 
         rmPlaceObjectDefAtLoc(malteseController3ID, 0, 0.5, 0.5);
         vector malteseControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController3ID, 0));

         int eastIslandVillage3 = rmCreateArea ("east island village 3");

         rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(750.0), rmAreaTilesToFraction(750.0));
         rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc3)));
         rmSetAreaCoherence(eastIslandVillage3, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage3, 5);
         rmSetAreaBaseHeight(eastIslandVillage3, 3.5);
         rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
         rmBuildArea(eastIslandVillage3);

         int maltese4VillageID = -1;
         int maltese4VillageType = rmRandInt(1,4);
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
         rmAddObjectDefConstraint(malteseController4ID, avoidWater30);
         rmAddObjectDefConstraint(malteseController4ID, avoidController); 
         rmAddObjectDefConstraint(malteseController4ID, nativeIslandConstraint); 
         rmAddObjectDefConstraint(malteseController4ID, villageEdgeConstraint); 
         rmPlaceObjectDefAtLoc(malteseController4ID, 0, 0.5, 0.5);
         vector malteseControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(malteseController4ID, 0));

         int eastIslandVillage4 = rmCreateArea ("east island village 4");

         rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(750.0), rmAreaTilesToFraction(750.0));
         rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)));
         rmSetAreaCoherence(eastIslandVillage4, 0.8);
         rmSetAreaSmoothDistance(eastIslandVillage4, 5);
         rmSetAreaBaseHeight(eastIslandVillage4, 3.5);
         rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
         rmBuildArea(eastIslandVillage4);

         int maltese5VillageID = -1;
         int maltese5VillageType = rmRandInt(1,4);
         maltese5VillageID = rmCreateGrouping("temple city 4", "Aztec_Temple_0"+maltese5VillageType);
         rmAddGroupingConstraint(maltese5VillageID, avoidImpassableLand);
         rmPlaceGroupingAtLoc(maltese5VillageID, 0, rmXMetersToFraction(xsVectorGetX(malteseControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(malteseControllerLoc4)), 1);
      
      }


      // Aztec Houses
      int randomHouseID=rmCreateObjectDef("random tree");
      rmAddObjectDefItem(randomHouseID, "zpNativeHouseAztec", 1, 0.0);
      rmSetObjectDefMinDistance(randomHouseID, 0.0);
      rmSetObjectDefMaxDistance(randomHouseID, rmXFractionToMeters(0.5));
      rmAddObjectDefConstraint(randomHouseID, avoidImpassableLand);
      rmAddObjectDefConstraint(randomHouseID, avoidAll_dk); 
      rmAddObjectDefConstraint(randomHouseID, nativeIslandConstraint);

      rmPlaceObjectDefAtLoc(randomHouseID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);

    // wood resources
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeSonora", 1, 1.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidResource);
   rmAddObjectDefConstraint(randomTreeID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, avoidMountains);
   if (rmGetIsKOTH() == true)
	   rmAddObjectDefConstraint(randomTreeID, avoidKOTH);

	// Player placement
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

   // Placement order
   // Trade route -> River (none on this map) -> Natives -> Secrets -> Cliffs -> Nuggets

   // Text
   rmSetStatusText("",0.30);

	int tpVariation = rmRandInt(1,2);
//		tpVariation = 2;		// for testing

	

   // Text
   rmSetStatusText("",0.40);

	// PLAYER STARTING RESOURCES

   rmClearClosestPointConstraints();
   int TCfloat = -1;
   if (cNumberTeams == 2)
	   TCfloat = 50;
   else 
	   TCfloat = 85;
    
    if(cNumberNonGaiaPlayers==2){
        TCfloat = 15;
    }
    
	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);

		int playerMarketID = rmCreateObjectDef("player market");
		rmAddObjectDefItem(playerMarketID, "SPCXPWoodFortTower", 1, 0);
		rmAddObjectDefConstraint(playerMarketID, avoidTradeRoute);
		rmSetObjectDefMinDistance(playerMarketID, 10.0);
		rmSetObjectDefMaxDistance(playerMarketID, 18.0);
		rmAddObjectDefConstraint(playerMarketID, playerEdgeConstraint);
		rmAddObjectDefConstraint(playerMarketID, mediumShortAvoidImpassableLand);
      rmAddObjectDefConstraint(playerMarketID, avoidSocket2);
      rmAddObjectDefConstraint(playerMarketID, avoidMountains);
    
    int playerAsianMarketID = rmCreateObjectDef("player asian market");
		rmAddObjectDefItem(playerAsianMarketID , "SPCXPWoodFortTower", 1, 0);
		rmAddObjectDefConstraint(playerAsianMarketID , avoidTradeRoute);
		rmSetObjectDefMinDistance(playerAsianMarketID , 10.0);
		rmSetObjectDefMaxDistance(playerAsianMarketID , 18.0);
		rmAddObjectDefConstraint(playerAsianMarketID , playerEdgeConstraint);
		rmAddObjectDefConstraint(playerAsianMarketID , mediumShortAvoidImpassableLand);
      rmAddObjectDefConstraint(playerAsianMarketID, avoidSocket2);
      rmAddObjectDefConstraint(playerAsianMarketID, avoidMountains);
		
		int playerAfricanMarketID = rmCreateObjectDef("player african market");
		rmAddObjectDefItem(playerAfricanMarketID , "SPCXPWoodFortTower", 1, 0);
		rmAddObjectDefConstraint(playerAfricanMarketID , avoidTradeRoute);
		rmSetObjectDefMinDistance(playerAfricanMarketID , 10.0);
		rmSetObjectDefMaxDistance(playerAfricanMarketID , 18.0);
		rmAddObjectDefConstraint(playerAfricanMarketID , playerEdgeConstraint);
		rmAddObjectDefConstraint(playerAfricanMarketID , mediumShortAvoidImpassableLand);
      rmAddObjectDefConstraint(playerAfricanMarketID, avoidSocket2);
      rmAddObjectDefConstraint(playerAfricanMarketID, avoidMountains);
  }
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, TCfloat);

	rmAddObjectDefConstraint(TCID, avoidTradeRouteFar);
	rmAddObjectDefConstraint(TCID, avoidTownCenter);
   rmAddObjectDefConstraint(TCID, avoidSocket2);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, mediumShortAvoidImpassableLand);
   rmAddObjectDefConstraint(TCID, avoidMountains);
	//rmPlaceObjectDefPerPlayer(TCID, true);

	//WATER HC ARRIVAL POINT

   int waterFlagID = 0;
   for(i=1; <cNumberPlayers)
    {
        waterFlagID=rmCreateObjectDef("HC water flag "+i);
        rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
		rmAddClosestPointConstraint(flagEdgeConstraint);
		rmAddClosestPointConstraint(flagVsFlag);
      rmAddClosestPointConstraint(flagVsPirate1);
      rmAddClosestPointConstraint(flagVsPirate2);
		rmAddClosestPointConstraint(flagLand);
   if (rmGetIsKOTH() == true)
		rmAddObjectDefConstraint(waterFlagID, avoidKOTH);
	}  

	int playerSilverID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerSilverID, "minecopper", 1, 0);
	rmAddObjectDefConstraint(playerSilverID, avoidTradeRoute);
   rmAddObjectDefConstraint(playerSilverID, avoidMountains);
    if(cNumberNonGaiaPlayers>2){
        rmAddObjectDefConstraint(playerSilverID, avoidTownCenter);
    }
	rmSetObjectDefMinDistance(playerSilverID, 10.0);
	rmSetObjectDefMaxDistance(playerSilverID, 25.0);
  rmAddObjectDefConstraint(playerSilverID, mediumAvoidImpassableLand);

	int playerDeerID=rmCreateObjectDef("player herd");
  rmAddObjectDefItem(playerDeerID, "pronghorn", 8, 10.0);
  rmSetObjectDefMinDistance(playerDeerID, 10);
  rmSetObjectDefMaxDistance(playerDeerID, 16);
	rmAddObjectDefConstraint(playerDeerID, avoidAll);
  rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerDeerID, avoidMountains);
  rmSetObjectDefCreateHerd(playerDeerID, true);

	int playerTreeID=rmCreateObjectDef("player trees");
  rmAddObjectDefItem(playerTreeID, "TreeSonora", rmRandInt(7,10), 2.0);
  rmSetObjectDefMinDistance(playerTreeID, 16);
  rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
  rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerTreeID, avoidMountains);

	for(i=1; <cNumberPlayers) {
    rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
    vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

    if (rmGetNomadStart() == false)
    {
      if(ypIsAsian(i)) {
        rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
        rmPlaceObjectDefAtLoc(playerAsianMarketID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
      }
      
      else if(rmGetPlayerCiv(i) ==  rmGetCivID("Chinese") || rmGetPlayerCiv(i) ==  rmGetCivID("Indians")) {
        rmPlaceObjectDefAtLoc(playerAsianMarketID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
      }
      
      else if(rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa")) {
        rmPlaceObjectDefAtLoc(playerAfricanMarketID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
      }
      
      else 
        rmPlaceObjectDefAtLoc(playerMarketID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    }
    rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
    rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

    vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
    rmPlaceObjectDefAtLoc(waterFlagID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
	
  }
  
  rmClearClosestPointConstraints();



	
   // Text
   rmSetStatusText("",0.50);

   int numTries = -1;
   int failCount = -1;

   // Text
   rmSetStatusText("",0.60);

   // Text
   rmSetStatusText("",0.70);
 // if(cNumberNonGaiaPlayers>2){
	int silverType = -1;
	int silverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*1.5);
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

	for(i=0; < silverCount)
	{
	  silverID = rmCreateObjectDef("player copper "+i);
	  rmAddObjectDefItem(silverID, "minecopper", 1, 0.0);
      rmSetObjectDefMinDistance(silverID, 0.0);
      rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
	  rmAddObjectDefConstraint(silverID, avoidCopper);
      rmAddObjectDefConstraint(silverID, avoidAll);
      rmAddObjectDefConstraint(silverID, avoidTownCenterFar);
	  rmAddObjectDefConstraint(silverID, avoidTradeRoute);
     rmAddObjectDefConstraint(silverID, avoidMountains);
      rmAddObjectDefConstraint(silverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(silverID, playerIslandConstraint);
	  rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5);
   } 

/* }else{
    //1v1 mines
    int topMine = rmCreateObjectDef("topMine");
    rmAddObjectDefItem(topMine, "mine", 1, 0.0);
    rmSetObjectDefMinDistance(topMine, 0.0);
    rmSetObjectDefMaxDistance(topMine, 31.0);
    rmAddObjectDefConstraint(topMine, avoidSocket2_dk);
    rmAddObjectDefConstraint(topMine, avoidTradeRouteSmall_dk);
    rmAddObjectDefConstraint(topMine, forestConstraintShort_dk);
    rmAddObjectDefConstraint(topMine, avoidGoldTypeFar_dk);
    rmAddObjectDefConstraint(topMine, circleConstraint2_dk);       
    rmAddObjectDefConstraint(topMine, avoidAll_dk); 
    rmAddObjectDefConstraint(topMine, avoidWater5_dk);
    rmAddObjectDefConstraint(topMine, avoidTownCenter);
	if (rmGetIsKOTH() == true)
		rmAddObjectDefConstraint(topMine, avoidKOTH);
    
    //top mines
    rmPlaceObjectDefAtLoc(topMine, 0, 0.63, 0.63, 1);
    if(rmRandInt(0,1)==0){
        rmPlaceObjectDefAtLoc(topMine, 0, 0.88, 0.65, 1);
    }else{
        rmPlaceObjectDefAtLoc(topMine, 0, 0.65, 0.88, 1);
    }
    rmPlaceObjectDefAtLoc(topMine, 0, 0.43, 0.83, 1);
    rmPlaceObjectDefAtLoc(topMine, 0, 0.83, 0.43, 1);
    
    //bot mines
    rmPlaceObjectDefAtLoc(topMine, 0, 0.37, 0.37, 1);
    if(rmRandInt(0,1)==0){
        rmPlaceObjectDefAtLoc(topMine, 0, 0.12, 0.35, 1);
    }else{
        rmPlaceObjectDefAtLoc(topMine, 0, 0.35, 0.12, 1);
    }
    rmPlaceObjectDefAtLoc(topMine, 0, 0.57, 0.17, 1);
    rmPlaceObjectDefAtLoc(topMine, 0, 0.17, 0.57, 1);
 }
*/



/*
   // Define and place Forests
   //ABC NEED TO BE SCATTERED BETWEEN THE TWO RIVERBANKS
   int forestTreeID = 0;
   numTries=8*cNumberNonGaiaPlayers;
   failCount=0;
   for (i=0; <numTries)
      {   
         int forestS=rmCreateArea("forestS"+i);
         rmSetAreaWarnFailure(forestS, false);
         rmSetAreaSize(forestS, rmAreaTilesToFraction(11), rmAreaTilesToFraction(11));
         rmSetAreaForestType(forestS, "amazon rain forest");
         rmSetAreaForestDensity(forestS, 0.8);
         rmSetAreaForestClumpiness(forestS, 0.6);
         rmSetAreaForestUnderbrush(forestS, 0.0);
         rmSetAreaMinBlobs(forestS, 6);
         rmSetAreaMaxBlobs(forestS, 15);
         rmSetAreaMinBlobDistance(forestS, 16.0);
         rmSetAreaMaxBlobDistance(forestS, 25.0);
         rmSetAreaCoherence(forestS, 0.4);
         rmSetAreaSmoothDistance(forestS, 10);
	      rmAddAreaToClass(forestS, rmClassID("classForest"));
         rmAddAreaConstraint(forestS, forestConstraint);
         rmAddAreaConstraint(forestS, forestObjConstraint);
         rmAddAreaConstraint(forestS, shortAvoidImpassableLand); 
         rmAddAreaConstraint(forestS, avoidTradeRoute);
		 rmAddAreaConstraint(forestS, avoidTownCenter);
		 rmAddAreaConstraint(forestS, avoidKOTH);
         if(cNumberNonGaiaPlayers==2){
           rmAddAreaConstraint(forestS, avoidMineForest_dk);
         }
	//	 rmBuildArea(forestS);	 
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==6)
               break;
         }
         else
            failCount=0; 
   
	} 
*/
 
  // Text
   rmSetStatusText("",0.80);

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
		if (rmGetIsKOTH() == true)
			rmAddObjectDefConstraint(southTreesID, avoidKOTH);
		rmAddObjectDefConstraint(southTreesID, avoidTownCenter);
		rmAddObjectDefConstraint(southTreesID, nativeIslandConstraint);
		rmPlaceObjectDefAtLoc(southTreesID, 0, 0.50, 0.50, 2+4*cNumberNonGaiaPlayers);

	int northTreesID = rmCreateObjectDef("north tree");
		rmAddObjectDefItem(northTreesID, "TreeSonora", 20, 10.0);
		rmSetObjectDefMinDistance(northTreesID,  rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(northTreesID,  rmXFractionToMeters(0.50));
		rmAddObjectDefToClass(northTreesID, rmClassID("classForest"));
		rmAddObjectDefConstraint(northTreesID, forestConstraint);
		rmAddObjectDefConstraint(northTreesID, avoidMineForest_dk);
		rmAddObjectDefConstraint(northTreesID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(northTreesID, avoidTradeRoute);
      rmAddObjectDefConstraint(northTreesID, avoidMountains);
		rmAddObjectDefConstraint(northTreesID, forestObjConstraint);
		if (rmGetIsKOTH() == true)
			rmAddObjectDefConstraint(northTreesID, avoidKOTH);
		rmAddObjectDefConstraint(northTreesID, avoidTownCenter);
		rmAddObjectDefConstraint(northTreesID, playerIslandConstraint);
		rmPlaceObjectDefAtLoc(northTreesID, 0, 0.50, 0.50, 2+4*cNumberNonGaiaPlayers);

	// Place other objects that were defined earlier
    
 // Resources that can be placed after forests
  
  //Place fish
  int fishID=rmCreateObjectDef("fish");
  rmAddObjectDefItem(fishID, "FishBass", 3, 9.0);
  rmSetObjectDefMinDistance(fishID, 0.0);
  rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fishID, fishVsFishID);
  rmAddObjectDefConstraint(fishID, fishLand);
	if (rmGetIsKOTH() == true)
		rmAddObjectDefConstraint(fishID, avoidKOTH);
  rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 11*cNumberNonGaiaPlayers); 
  
   //PAROT : underwater Decoration
   int avoidLand = rmCreateTerrainDistanceConstraint("avoid land long", "Land", true, 5.0);
   int underwaterDecoID=rmCreateObjectDef("SeaweedRocks");
   rmAddObjectDefItem(underwaterDecoID, "UnderbrushCoast", 1, 3);
   //rmAddObjectDefItem(int defID, string unitName, int count, float clusterDistance)
   rmSetObjectDefMinDistance(underwaterDecoID, 0.00);
   rmSetObjectDefMaxDistance(underwaterDecoID, rmXFractionToMeters(0.04));   
   rmAddObjectDefConstraint(underwaterDecoID, avoidLand);   
   if (rmGetIsKOTH() == true)
		rmAddObjectDefConstraint(underwaterDecoID, avoidKOTH);   
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.10, 0.70, 20);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.25, 0.90, 15);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.25, 0.60, 15);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.30, 0.80, 10);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.30, 0.50, 10);    
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.40, 0.40, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.60, 0.35, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.70, 0.50, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.70, 0.40, 5); 
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.70, 0.20, 10);
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.80, 0.30, 15);        
   rmPlaceObjectDefAtLoc(underwaterDecoID, 0, 0.90, 0.20, 20);     
       
   //rmPlaceObjectDefAtLoc(int defID, int playerID, float xFraction, float zFraction, long placeCount)   

	int tapirCount = rmRandInt(3,6);
	int capyCount = rmRandInt(9,12);

   int tapirNID=rmCreateObjectDef("north tapir crash");
   rmAddObjectDefItem(tapirNID, "bison", tapirCount, 2.0);
   rmSetObjectDefMinDistance(tapirNID, 0.0);
   rmSetObjectDefMaxDistance(tapirNID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(tapirNID, avoidImpassableLand);
   rmAddObjectDefConstraint(tapirNID, avoidMountains);
   rmAddObjectDefConstraint(tapirNID, playerIslandConstraint);
   rmSetObjectDefCreateHerd(tapirNID, true);
   rmPlaceObjectDefAtLoc(tapirNID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int tapirSID=rmCreateObjectDef("south tapir crash");
   rmAddObjectDefItem(tapirSID, "tapir", tapirCount, 2.0);
   rmSetObjectDefMinDistance(tapirSID, 0.0);
   rmSetObjectDefMaxDistance(tapirSID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(tapirSID, avoidImpassableLand);
   rmAddObjectDefConstraint(tapirSID, nativeIslandConstraint);
   rmSetObjectDefCreateHerd(tapirSID, true);
   rmPlaceObjectDefAtLoc(tapirSID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	// Text
   rmSetStatusText("",0.90);

	int capybaraNID=rmCreateObjectDef("north capybara crash");
   rmAddObjectDefItem(capybaraNID, "pronghorn", capyCount, 2.0);
   rmSetObjectDefMinDistance(capybaraNID, 0.0);
   rmSetObjectDefMaxDistance(capybaraNID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(capybaraNID, avoidImpassableLand);
   rmAddObjectDefConstraint(capybaraNID, avoidMountains);
   rmAddObjectDefConstraint(capybaraNID, playerIslandConstraint);
   rmSetObjectDefCreateHerd(capybaraNID, true);
   rmPlaceObjectDefAtLoc(capybaraNID, 0, 0.5, 0.5, (1.75*cNumberNonGaiaPlayers));

	int capybaraSID=rmCreateObjectDef("south capybara crash");
   rmAddObjectDefItem(capybaraSID, "capybara", capyCount, 2.0);
   rmSetObjectDefMinDistance(capybaraSID, 0.0);
   rmSetObjectDefMaxDistance(capybaraSID, rmXFractionToMeters(0.4));
   rmAddObjectDefConstraint(capybaraSID, avoidImpassableLand);
   rmAddObjectDefConstraint(capybaraSID, nativeIslandConstraint);
   rmSetObjectDefCreateHerd(capybaraSID, true);
   rmPlaceObjectDefAtLoc(capybaraSID, 0, 0.5, 0.5, (1.75*cNumberNonGaiaPlayers));



   // Define and place Nuggets on both sides of the river

	   int southNugget1= rmCreateObjectDef("south nugget easy"); 
	   rmAddObjectDefItem(southNugget1, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(2, 2);
	   rmAddObjectDefConstraint(southNugget1, avoidImpassableLand);
  	   rmAddObjectDefConstraint(southNugget1, avoidNugget);
  	   rmAddObjectDefConstraint(southNugget1, avoidTradeRoute);
  	   rmAddObjectDefConstraint(southNugget1, avoidAll);
	   rmAddObjectDefConstraint(southNugget1, avoidWater20);
	   rmAddObjectDefConstraint(southNugget1, nativeIslandConstraint);
	   rmAddObjectDefConstraint(southNugget1, playerEdgeConstraint);
	   rmPlaceObjectDefPerPlayer(southNugget1, false, 1);

	   int northNugget1= rmCreateObjectDef("north nugget easy"); 
	   rmAddObjectDefItem(northNugget1, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(1, 1);
	   rmAddObjectDefConstraint(northNugget1, avoidImpassableLand);
  	   rmAddObjectDefConstraint(northNugget1, avoidNugget);
  	   rmAddObjectDefConstraint(northNugget1, avoidTradeRoute);
  	   rmAddObjectDefConstraint(northNugget1, avoidAll);
	   rmAddObjectDefConstraint(northNugget1, avoidWater20);
	   rmAddObjectDefConstraint(northNugget1, playerIslandConstraint);
      rmAddObjectDefConstraint(northNugget1, avoidMountains);
	   rmAddObjectDefConstraint(northNugget1, playerEdgeConstraint);
	   rmPlaceObjectDefPerPlayer(northNugget1, false, 1);

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

	   int northNugget2= rmCreateObjectDef("north nugget medium"); 
	   rmAddObjectDefItem(northNugget2, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(2, 2);
	   rmSetObjectDefMinDistance(northNugget2, 0.0);
	   rmSetObjectDefMaxDistance(northNugget2, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(northNugget2, avoidImpassableLand);
  	   rmAddObjectDefConstraint(northNugget2, avoidNugget);
  	   rmAddObjectDefConstraint(northNugget2, avoidTownCenter);
  	   rmAddObjectDefConstraint(northNugget2, avoidTradeRoute);
      rmAddObjectDefConstraint(northNugget2, avoidMountains);
  	   rmAddObjectDefConstraint(northNugget2, avoidAll);
  	   rmAddObjectDefConstraint(northNugget2, avoidWater20);
	   rmAddObjectDefConstraint(northNugget2, playerIslandConstraint);
	   rmAddObjectDefConstraint(northNugget2, playerEdgeConstraint);
	   rmPlaceObjectDefPerPlayer(northNugget2, false, 1);

	   int southNugget3= rmCreateObjectDef("south nugget hard"); 
	   rmAddObjectDefItem(southNugget3, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(3, 3);
	   rmSetObjectDefMinDistance(southNugget3, 0.0);
	   rmSetObjectDefMaxDistance(southNugget3, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(southNugget3, avoidImpassableLand);
  	   rmAddObjectDefConstraint(southNugget3, avoidNugget);
  	   rmAddObjectDefConstraint(southNugget3, avoidTownCenter);
  	   rmAddObjectDefConstraint(southNugget3, avoidTradeRoute);
  	   rmAddObjectDefConstraint(southNugget3, avoidAll);
  	   rmAddObjectDefConstraint(southNugget3, avoidWater20);
	   rmAddObjectDefConstraint(southNugget3, nativeIslandConstraint);
	   rmAddObjectDefConstraint(southNugget3, playerEdgeConstraint);
	   //rmPlaceObjectDefPerPlayer(southNugget3, false, 1);
	   rmPlaceObjectDefAtLoc(southNugget3, 0, 0.5, 0.5, 1);

	   int northNugget3= rmCreateObjectDef("north nugget hard"); 
	   rmAddObjectDefItem(northNugget3, "Nugget", 1, 0.0);
	   rmSetNuggetDifficulty(3, 3);
	   rmSetObjectDefMinDistance(northNugget3, 0.0);
	   rmSetObjectDefMaxDistance(northNugget3, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(northNugget3, avoidImpassableLand);
  	   rmAddObjectDefConstraint(northNugget3, avoidNugget);
  	   rmAddObjectDefConstraint(northNugget3, avoidTownCenter);
  	   rmAddObjectDefConstraint(northNugget3, avoidTradeRoute);
      rmAddObjectDefConstraint(northNugget3, avoidMountains);
  	   rmAddObjectDefConstraint(northNugget3, avoidAll);
  	   rmAddObjectDefConstraint(northNugget3, avoidWater20);
	   rmAddObjectDefConstraint(northNugget3, playerIslandConstraint);
	   rmAddObjectDefConstraint(northNugget3, playerEdgeConstraint);
	   //rmPlaceObjectDefPerPlayer(northNugget3, false, 1);
	   rmPlaceObjectDefAtLoc(northNugget3, 0, 0.5, 0.5, 1);

	   //only try to place these 25% of the time
	   int nuggetNutsNum = rmRandInt(1,4);
	   if (nuggetNutsNum == 1)
	   {
	   int southNugget4= rmCreateObjectDef("south nugget nuts"); 
	   rmAddObjectDefItem(southNugget4, "Nugget", 1, 0.0);
       if(cNumberNonGaiaPlayers>2 && rmGetIsTreaty() == false){
            rmSetNuggetDifficulty(4, 4);
       }else{
            rmSetNuggetDifficulty(3, 3);
       }
	   rmSetObjectDefMinDistance(southNugget4, 0.0);
	   rmSetObjectDefMaxDistance(southNugget4, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(southNugget4, avoidImpassableLand);
  	   rmAddObjectDefConstraint(southNugget4, avoidNugget);
  	   rmAddObjectDefConstraint(southNugget4, avoidTownCenter);
  	   rmAddObjectDefConstraint(southNugget4, avoidTradeRoute);
  	   rmAddObjectDefConstraint(southNugget4, avoidAll);
  	   rmAddObjectDefConstraint(southNugget4, avoidWater20);
	   rmAddObjectDefConstraint(southNugget4, nativeIslandConstraint);
	   rmAddObjectDefConstraint(southNugget4, playerEdgeConstraint);
	   //rmPlaceObjectDefPerPlayer(southNugget4, false, 1);
	   rmPlaceObjectDefAtLoc(southNugget4, 0, 0.5, 0.5, 1);

	   int northNugget4= rmCreateObjectDef("north nugget nuts"); 
	   rmAddObjectDefItem(northNugget4, "Nugget", 1, 0.0);
	   if(cNumberNonGaiaPlayers>2 && rmGetIsTreaty() == false){
            rmSetNuggetDifficulty(4, 4);
       }else{
            rmSetNuggetDifficulty(3, 3);
       }
	   rmSetObjectDefMinDistance(northNugget4, 0.0);
	   rmSetObjectDefMaxDistance(northNugget4, rmXFractionToMeters(0.5));
	   rmAddObjectDefConstraint(northNugget4, avoidImpassableLand);
  	   rmAddObjectDefConstraint(northNugget4, avoidNugget);
  	   rmAddObjectDefConstraint(northNugget4, avoidTownCenter);
  	   rmAddObjectDefConstraint(northNugget4, avoidTradeRoute);
  	   rmAddObjectDefConstraint(northNugget4, avoidAll);
  	   rmAddObjectDefConstraint(northNugget4, avoidWater20);
	   rmAddObjectDefConstraint(northNugget4, playerIslandConstraint);
      rmAddObjectDefConstraint(northNugget4, avoidMountains);
	   rmAddObjectDefConstraint(northNugget4, playerEdgeConstraint);
	   //rmPlaceObjectDefPerPlayer(northNugget4, false, 1);
	   rmPlaceObjectDefAtLoc(northNugget4, 0, 0.5, 0.5, 1);
	   }

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
rmSetTriggerConditionParam("DstObject","7");
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
   rmSetTriggerConditionParam("DstObject","7");
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
   rmSetTriggerConditionParam("DstObject","7");
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
   rmSetTriggerConditionParam("DstObject","7");
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
rmSetTriggerConditionParam("DstObject","7");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","7");
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
rmSetTriggerConditionParam("DstObject","7");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","7");
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
