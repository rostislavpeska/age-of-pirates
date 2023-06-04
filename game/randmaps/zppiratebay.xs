// Hispaniola -- JSB
// March 2006
// edited December 2021 by vividlyplain

// Main entry point for random map script    

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
	string baseTerrainMix = "caribbean grass";
	string lightingSet = "Hispaniola_Skirmish";
	string seaType = "caribbean coast";
	string islandTerrainMix = "caribbean grass";
	string mainMountainCliffType = "Caribbean";
	string forestType = "caribbean palm forest";

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.10);

	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

    if (rmAllocateSubCivs(4) == true)
    {
		subCiv0=rmGetCivID("natpirates");
		rmEchoInfo("subCiv0 is natpirates "+subCiv0);
		if (subCiv0 >= 0)
		rmSetSubCiv(0, "natpirates");

		subCiv1=rmGetCivID("natpirates");
		rmEchoInfo("subCiv1 is natpirates "+subCiv1);
		if (subCiv1 >= 0)
		rmSetSubCiv(1, "natpirates");

		subCiv2=rmGetCivID("natpirates");
		rmEchoInfo("subCiv2 is natpirates "+subCiv2);
		if (subCiv2 >= 0)
		rmSetSubCiv(2, "natpirates");

		subCiv3=rmGetCivID("natpirates");
		rmEchoInfo("subCiv2 is natpirates "+subCiv2);
		if (subCiv3 >= 0)
		rmSetSubCiv(3, "natpirates");
	}

	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.20);
	
	// Map variations: 
	// 1 - Four Caribs, next to the big mountain and at the ends of the 2 long peninsulas. 
	// 2 - Four Caribs, at the ends of the 2 long peninsulas, and 2 on SE end of island.
    // 3 - Six Caribs, next to the mountain, 2 on the long peninsula, and 2 on SE end of island. 
	// Note from Riki: Variation 3 has been removed for DE

	int whichVariation=-1;
	
    if(rmGetIsKOTH()){
        whichVariation = 2;
    }else{
        whichVariation = rmRandInt(1,2);
    }

	rmEchoInfo("Map Variation: "+whichVariation);
	
	chooseMercs();

	if ( cNumberNonGaiaPlayers > 7 )	//If 8 player game, use only variation #2 so map builds more quickly.
	{
		whichVariation = 2;
	}
	
	// Set size of map
	int playerTiles=23500;
	if (cNumberNonGaiaPlayers >4)   // If more than 4 players...
		playerTiles = 18000;		// ...give this many tiles per player.
	if (cNumberNonGaiaPlayers >7)	// If more than 7 players...
		playerTiles = 20000;		// ...give this many tiles per player.	
	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	// Set up default water type.
	rmSetSeaLevel(1.0);          
	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseTerrainMix);
	rmSetMapType("caribbean");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetLightingSet(lightingSet);

	// Initialize map.
	rmTerrainInitialize("water");

	// Misc variables for use later
	int numTries = -1;

	// Define some classes.
	int classPlayer=rmDefineClass("player");
	int classIsland=rmDefineClass("island");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	int classNatives = rmDefineClass("natives");
	rmDefineClass("classSocket");
	rmDefineClass("canyon");

   // -------------Define constraints----------------------------------------

    // Create an edge of map constraint.
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player area constraint.
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("long stay away from players", classPlayer, 60.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 20.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int nearWaterDock = rmCreateTerrainDistanceConstraint("near water for Dock", "Water", true, 0.0);
	int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 26.0);    //Originally 20.0 -- This adjustment, as well as changing the rmSetObjectDefMaxDistance to 12.0, has corrected the problem of nomad sometimes not placing CW for each player.
	int avoidTP=rmCreateTypeDistanceConstraint("stay away from Trading Post Sockets", "SocketTradeRoute", 14.0);  // JSB 1-11-05 - Just added, to try to prevent things from stomping on TPs.
	int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 24.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);

	// Bonus area constraint.  
	//int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 55.0);
    int villageEdgeConstraint = rmCreatePieConstraint("willabe awlaay from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-50, 0, 0, 0);


	// Resource constraints - Fish, whales, forest, mines, nuggets, and sheep
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishMahi", 25.0);			// was 50.0
	// int fishVsFishTarponID=rmCreateTypeDistanceConstraint("fish v fish2", "fishTarpon", 20.0);  // was 40.0 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 8.0);	//Was 8.0
	int fishVsWhaleID=rmCreateTypeDistanceConstraint("fish v whale", "MinkeWhale", 40.0);    //Was 34.0 -- This is for trying to keep fish out of "whale bay".
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);   // Was 18.0.  This is to keep whales from swimming inside of land.
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int avoidCoin=-1;
	// Drop coin constraint on bigger maps
	if ( cNumberNonGaiaPlayers > 5 )
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 75.0);
	}
	else
	{
		avoidCoin = rmCreateTypeDistanceConstraint("avoid coin", "minegold", 85.0);	// 85.0 seems the best for event minegold distribution.  This number tells minegolds how far they should try to avoid each other.  Useful for spreading them out more evenly.
	}
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.
	int avoidRandomTurkeys=rmCreateTypeDistanceConstraint("avoid random turkeys", "turkey", 50.0);	//Attempting to spread them out more evenly.
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 54.0);  //Was 60.0 -- attempting to get more nuggets in south half of isle.
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 120.0);  //Added sheep 11-28-05 JSB

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 5.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 14.0);  //This one is used in one place: for helping place FFA TC's better.

	// Constraint to avoid water.
	int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);   //I added this one so I could experiment with it.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater40 = rmCreateTerrainDistanceConstraint("avoid water super long", "Land", false, 40.0);  //Added this one too.
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 18.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25); //Was 15, but made larger so ships don't sometimes stomp each other when arriving from HC.
	rmAddClosestPointConstraint(avoidWater8);  //was originally 8
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 6.0);
	int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", classNatives , 10.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("avoid natives far", classNatives , 18.0);
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int ferryOnShore = rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
	int seekWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", true, 5.0);

	// The following is a Pie constraint, defined in a large "majority of the pie plate" area, to make sure Water spawn flags place inside it.  Everyone should be near the mouth of the bay
	int circleConstraint=rmCreatePieConstraint("semi-circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.49), rmDegreesToRadians(270), rmDegreesToRadians(70));  //rmZFractionToMeters(0.47)- this number defines how far out from .5, .5 the center of the pie sections go. 

	// int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);
	
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.30);

   int IslandLoc = 1;								

	// Make one big island.  
	int bigIslandID=rmCreateArea("big lone island");
	rmSetAreaSize(bigIslandID, 0.33);				//Defines island's size.  .40, .40 looks about right.
	rmSetAreaCoherence(bigIslandID, 0.8);				//Determines raggedness of island's coastline.  Lower the number, more the blobby.
	rmSetAreaBaseHeight(bigIslandID, 1.5);
	rmSetAreaSmoothDistance(bigIslandID, 5);
	rmSetAreaMix(bigIslandID, islandTerrainMix);
	rmAddAreaTerrainLayer(bigIslandID, "caribbean\ground_shoreline1_crb", 0, 5);
	rmAddAreaTerrainLayer(bigIslandID, "caribbean\ground_shoreline2_crb", 5, 10);
//	rmAddAreaTerrainLayer(bigIslandID, "caribbean\ground_shoreline3_crb", 15, 20);

	rmAddAreaToClass(bigIslandID, classIsland);
	//rmAddAreaConstraint(bigIslandID, islandConstraint);
	rmSetAreaObeyWorldCircleConstraint(bigIslandID, false);
	rmSetAreaElevationType(bigIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(bigIslandID, 4.0);
	rmSetAreaElevationMinFrequency(bigIslandID, 0.09);
	rmSetAreaElevationOctaves(bigIslandID, 3);
	rmSetAreaElevationPersistence(bigIslandID, 0.2);
	rmSetAreaElevationNoiseBias(bigIslandID, 1);

/*	rmAddAreaInfluenceSegment(bigIslandID, 0.62, 0.78, 0.80, 0.51);  //Segment 1 - short top, left, right. // .69, .68, .76, .51
	rmAddAreaInfluenceSegment(bigIslandID, 0.80, 0.51, 0.65, 0.25);  //Segment 2 - long top  // last # was .56, .78, .75, .285 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.65, 0.25, 0.34, 0.21);  //Segment 3 - long lower // last # was .22, .67, .58, .20 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.34, 0.21, 0.19, 0.62);  //Segment 4 - short lower bit // last was .20, .44, .36, .21
*/
	rmAddAreaInfluenceSegment(bigIslandID, 0.74, 0.69, 0.80, 0.51);  //Segment 1 - short top, left, right. // .69, .68, .76, .51
	rmAddAreaInfluenceSegment(bigIslandID, 0.62, 0.78, 0.75, 0.30);  //Segment 2 - long top  // last # was .56, .78, .75, .285 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.19, 0.62, 0.58, 0.20);  //Segment 3 - long lower // last # was .22, .67, .58, .20 // -- Changed 3-10-06
	rmAddAreaInfluenceSegment(bigIslandID, 0.20, 0.5, 0.34, 0.21);  //Segment 4 - short lower bit // last was .20, .44, .36, .21
  	



	 		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.40);

	rmSetAreaWarnFailure(bigIslandID, false);

	if (IslandLoc == 1)
	rmSetAreaLocation(bigIslandID, .5, .5);		//Put the big island in exact middle of map.
	rmBuildArea(bigIslandID);

	// Put a big circular cove right in the center
	   int centerCoveID=rmCreateArea("Pirate Cove");
	rmSetAreaWaterType(centerCoveID, "caribbean coast");
	rmSetAreaSize(centerCoveID, 0.07, 0.07);
	rmSetAreaCoherence(centerCoveID, 0.8);
	rmSetAreaLocation(centerCoveID, 0.5, 0.5);
	rmAddAreaToClass(centerCoveID, classIsland);
	rmSetAreaBaseHeight(centerCoveID, 0.0);
	rmSetAreaObeyWorldCircleConstraint(centerCoveID, false);
	rmSetAreaSmoothDistance(centerCoveID, 10);
	rmBuildArea(centerCoveID); 
	
    // Set up player areas.  -- Each team always placed along a line.  One team in NE, other in SW.
	
	float teamStartLoc = rmRandFloat(0.0, 1.0);  //This chooses a number randomly between 0 and 1, used to pick whether team 1 is on top or bottom.
	//float teamStartLoc = rmRandFloat(0.2, 0.4);    //Temporarily force float to be .4 or lower, so Team 0 will be in the North.

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

		if (cNumberTeams == 2 && teamZeroCount == teamOneCount)
		{
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.20, 0.6, 0.25, 0.4, 0.0, 0.0); //Team 0 is in the south 
			
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.62, 0.78, 0.7, 0.6, 0.0, 0.0); //Team 1 is in the north
			}
			else
			{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.20, 0.6, 0.25, 0.4, 0.0, 0.0); //Team 1 is in the south 
			
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.62, 0.78, 0.7, 0.6, 0.0, 0.0); //Team 0 is in the north
			}
		}
		else if (cNumberTeams == 2) 
		{
			if (teamStartLoc > 0.5)
			{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.25, 0.65, 0.35, 0.25, 0.0, 0.0); //Team 0 is in the south 
			
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.7, 0.7, 0.715, 0.31, 0.0, 0.0); //Team 1 is in the north
			}
			else
			{
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.25, 0.65, 0.35, 0.25, 0.0, 0.0); //Team 1 is in the south 
			
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.7, 0.7, 0.715, 0.31, 0.0, 0.0); //Team 0 is in the north
			}			
		}

	// otherwise it's a Free-For-All, so just place everyone in one big arc around the center island.
	else
	{
  		rmSetPlacementSection(0.04, 0.82);
		rmPlacePlayersCircular(0.23, 0.23, 0.0);
	}

	float playerFraction=rmAreaTilesToFraction(100);
	for(i=1; <cNumberPlayers)
	{
      // Create the Player's area.
      int id=rmCreateArea("Player"+i);
      rmSetPlayerArea(i, id);
      rmSetAreaSize(id, playerFraction, playerFraction);
      rmAddAreaToClass(id, classPlayer);
      rmSetAreaMinBlobs(id, 1);
      rmSetAreaMaxBlobs(id, 1);
      rmSetAreaLocPlayer(id, i);
      rmSetAreaWarnFailure(id, false);
	}

	// Build the areas. 
	rmBuildAllAreas();

   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.50);

	// Clear out constraints for good measure.
    rmClearClosestPointConstraints();   //This was in the Caribbean script I started with.  Not sure what it does so afraid to axe it.

	// *****************NATIVES****************************************************************************
  

	//-------- ALWAYS: 2 PIRATE VILLAGES at ends of the 2 long peninsulas ----------------------------------------------

   // Place Controllers
      int controllerID1 = rmCreateObjectDef("Controler 1");
      rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID1, 0.0);
	  rmSetObjectDefMaxDistance(controllerID1, 30.0);
      rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
	  rmAddObjectDefConstraint(controllerID1, seekWater8);
      rmAddObjectDefConstraint(controllerID1, ferryOnShore); 
	  rmAddObjectDefConstraint(controllerID1, avoidAll);
      rmPlaceObjectDefAtLoc(controllerID1, 0, 0.77, 0.75);


      int controllerID2 = rmCreateObjectDef("Controler 2");
      rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(controllerID2, 0.0);
	  rmSetObjectDefMaxDistance(controllerID2, 30.0);
      rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
	  rmAddObjectDefConstraint(controllerID2, seekWater8);
      rmAddObjectDefConstraint(controllerID2, ferryOnShore); 
	  rmAddObjectDefConstraint(controllerID2, avoidAll);
      rmPlaceObjectDefAtLoc(controllerID2, 0, 0.15, 0.33);


      vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
      vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

	if (whichVariation == 1 || whichVariation == 2 || whichVariation == 3) 
	{
		if (subCiv1 == rmGetCivID("natpirates"))
		{  
			int piratesVillageID = -1;
			int piratesVillageType = rmRandInt(1,2);
			piratesVillageID = rmCreateGrouping("pirate city", "pirate_village0"+piratesVillageType);

			rmSetGroupingMinDistance(piratesVillageID, 0.0);
			rmSetGroupingMaxDistance(piratesVillageID, 20.0);
			rmAddGroupingConstraint(piratesVillageID, seekWater8);
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

		if (subCiv2 == rmGetCivID("natpirates"))
		{  
            int piratesVillageID2 = -1;
            int piratesVillage2Type = 3-piratesVillageType;
            piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village0"+piratesVillage2Type);

			rmSetGroupingMinDistance(piratesVillageID2, 0.0);
			rmSetGroupingMaxDistance(piratesVillageID2, 20.0);
			rmAddGroupingConstraint(piratesVillageID2, seekWater8);
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

	//-------- VARIATION 1 AND 3: 1 PIRATE VILLAGE in the center cove  -----------------------------------
		
	float pirate3X = 0.0;
	float pirate3Y = 0.0;

	float pirate4X = 0.0;
	float pirate4Y = 0.0;


	if (whichVariation == 1)
	{
		whichVariation = 2;
	}

	if (whichVariation == 1)  
	{	
		pirate3X = 0.55;
		pirate3Y = 0.3;
	}

	//-------- VARIATION 2 AND 3: 2 PIRATE VILLAGES at NE and SE ends of the island  ---------------------------------------

	if (whichVariation == 2 || whichVariation == 3) 
	{
		pirate3X = 0.73;
		pirate3Y = 0.3;

		pirate4X = 0.45;
		pirate4Y = 0.15;
	}

	//-------- PLACE VARIATIONS -----------
	// Place Controllers
	if (pirate3X > 0)
	{
		int controllerID3 = rmCreateObjectDef("Controler 3");
		rmAddObjectDefItem(controllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(controllerID3, 0.0);
		rmSetObjectDefMaxDistance(controllerID3, 40.0);
		rmAddObjectDefConstraint(controllerID3, avoidImpassableLand);
		//rmAddObjectDefConstraint(controllerID3, seekWater8);
		//rmAddObjectDefConstraint(controllerID3, avoidAll);
		rmAddObjectDefConstraint(controllerID3, ferryOnShore); 
		rmPlaceObjectDefAtLoc(controllerID3, 0, pirate3X, pirate3Y);
		vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID3, 0));
	}

	if (pirate4X > 0)
	{
		int controllerID4 = rmCreateObjectDef("Controler 4");
		rmAddObjectDefItem(controllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(controllerID4, 0.0);
		rmSetObjectDefMaxDistance(controllerID4, 40.0);
		rmAddObjectDefConstraint(controllerID4, avoidImpassableLand);
		rmAddObjectDefConstraint(controllerID4, ferryOnShore); 
		//rmAddObjectDefConstraint(controllerID4, seekWater8);
		//rmAddObjectDefConstraint(controllerID4, avoidAll);
		rmPlaceObjectDefAtLoc(controllerID4, 0, pirate4X, pirate4Y);
		vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID4, 0));
	}

	if (pirate3X > 0)
	{
		int piratesVillageID3 = -1;
		int piratesVillage3Type = 3-piratesVillageType;
		piratesVillageID3 = rmCreateGrouping("pirate city 3", "pirate_village0"+piratesVillage3Type);

		rmSetGroupingMinDistance(piratesVillageID3, 0.0);
		rmSetGroupingMaxDistance(piratesVillageID3, 20.0);
		rmAddGroupingConstraint(piratesVillageID3, seekWater8);
		rmPlaceGroupingAtLoc(piratesVillageID3, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3)), 1);
		
		int piratewaterflagID3 = rmCreateObjectDef("pirate water flag 3");
		rmAddObjectDefItem(piratewaterflagID3, "zpPirateWaterSpawnFlag3", 1, 1.0);
		rmAddClosestPointConstraint(villageEdgeConstraint);
		rmAddClosestPointConstraint(flagLand);

		vector closeToVillage3 = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(piratewaterflagID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

		rmClearClosestPointConstraints();

		int pirateportID3 = -1;
		pirateportID3 = rmCreateGrouping("pirate port 3", "pirateport03");
		rmAddClosestPointConstraint(villageEdgeConstraint);
		rmAddClosestPointConstraint(portOnShore);

		vector closeToVillage3a = rmFindClosestPointVector(ControllerLoc3, rmXFractionToMeters(1.0));
		rmPlaceGroupingAtLoc(pirateportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));
		
		rmClearClosestPointConstraints();
	}

	if (pirate4X > 0)
	{
		int piratesVillageID4 = -1;
		int piratesVillage4Type = 3-piratesVillageType;
		piratesVillageID4 = rmCreateGrouping("pirate city 4", "pirate_village0"+piratesVillage4Type);

		rmSetGroupingMinDistance(piratesVillageID4, 0.0);
		rmSetGroupingMaxDistance(piratesVillageID4, 20.0);
		rmAddGroupingConstraint(piratesVillageID4, seekWater8);
		rmPlaceGroupingAtLoc(piratesVillageID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4)), 1);
		
		int piratewaterflagID4 = rmCreateObjectDef("pirate water flag 4");
		rmAddObjectDefItem(piratewaterflagID4, "zpPirateWaterSpawnFlag4", 1, 1.0);
		rmAddClosestPointConstraint(villageEdgeConstraint);
		rmAddClosestPointConstraint(flagLand);

		vector closeToVillage4 = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(piratewaterflagID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4)));

		rmClearClosestPointConstraints();

		int pirateportID4 = -1;
		pirateportID4 = rmCreateGrouping("pirate port 4", "pirateport04");
		rmAddClosestPointConstraint(villageEdgeConstraint);
		rmAddClosestPointConstraint(portOnShore);

		vector closeToVillage4a = rmFindClosestPointVector(ControllerLoc4, rmXFractionToMeters(1.0));
		rmPlaceGroupingAtLoc(pirateportID4, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage4a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage4a)));
		
		rmClearClosestPointConstraints();
	}


   // *****************Capturable Tower Island**************************************
   // Create a small chunk of land with a capturable tower

		int smallCliffHeight=rmRandInt(0,10);
		int smallMesaID=rmCreateArea("small mesa");

		float mesaX = 0.41;
		float mesaY = 0.7;

		rmSetAreaSize(smallMesaID, rmAreaTilesToFraction(100));  // Sufficiently large so it always places
		
		rmSetAreaWarnFailure(smallMesaID, false);
		//rmSetAreaCliffType(smallMesaID, mainMountainCliffType);
		//rmSetAreaCliffPainting(smallMesaID, false, true, true, 1, false);
		rmAddAreaToClass(smallMesaID, rmClassID("canyon"));	// Attempt to keep cliffs away from each other.
		//rmSetAreaCliffEdge(smallMesaID, 1, 1.0, 0.1, 1.0, 0);
		//rmSetAreaCliffHeight(smallMesaID, rmRandInt(6, 8), 1.0, 1.0);  //was rmRandInt(6, 8)
		rmSetAreaCoherence(smallMesaID, 0.99);
		rmSetAreaBaseHeight(smallMesaID, 1.2);
		rmSetAreaSmoothDistance(smallMesaID, 5);
		rmSetAreaMix(smallMesaID, islandTerrainMix);
		rmAddAreaTerrainLayer(smallMesaID, "caribbean\ground_shoreline1_crb", 0, 5);
		rmAddAreaTerrainLayer(smallMesaID, "caribbean\ground_shoreline2_crb", 5, 10);
		rmSetAreaLocation(smallMesaID, mesaX, mesaY); 
		rmAddAreaConstraint(smallMesaID, avoidNativesFar); 
		rmSetAreaReveal(smallMesaID, 01); 
		rmSetAreaObeyWorldCircleConstraint(smallMesaID, false);
		rmSetAreaElevationType(smallMesaID, cElevTurbulence);
		rmSetAreaElevationVariation(smallMesaID, 4.0);
		rmSetAreaElevationMinFrequency(smallMesaID, 0.09);
		rmSetAreaElevationOctaves(smallMesaID, 3);
		rmSetAreaElevationPersistence(smallMesaID, 0.2);
		rmSetAreaElevationNoiseBias(smallMesaID, 1);
		rmBuildArea(smallMesaID);


	// Special AREA CONSTRAINTS and use it to make resources avoid the mountain in center:
		int smallMesaConstraint = rmCreateAreaDistanceConstraint("avoid Small Mesa", smallMesaID, 4.0);

	// Place fixed gun
	int fixedGunBaseID = rmCreateObjectDef("fixed gun emplacement");
	//rmAddObjectDefItem(fixedGunBaseID, "deSPCBatteryTowerSocket", 1, 0);
	rmAddObjectDefItem(fixedGunBaseID, "deSPCTowerCapturable", 1, 0);
	rmSetObjectDefMinDistance(fixedGunBaseID, 0.0);
	rmSetObjectDefMaxDistance(fixedGunBaseID, 0.0);
	rmAddObjectDefToClass(fixedGunBaseID, rmClassID("importantItem"));

	rmPlaceObjectDefAtLoc(fixedGunBaseID, 0, mesaX, mesaY);

		
	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.60);

	//***************** PLAYER STARTING STUFF **********************************
	//Place player TCs and starting Gold Mines. 

	int TCID = rmCreateObjectDef("player TC");
	if ( rmGetNomadStart())
		rmAddObjectDefItem(TCID, "coveredWagon", 1, 0);
	else
		rmAddObjectDefItem(TCID, "townCenter", 1, 0);

	//Prepare to place TCs
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 25.0);  // Greater than avoidWater constraint
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidWater20);
//	rmAddObjectDefConstraint(TCID, avoidTC);
//	rmAddObjectDefConstraint(TCID, avoidCW);
    	
	//Prepare to place Explorers, Explorer's dog, Explorer's Taun Taun, etc.
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 9.0);
	rmSetObjectDefMaxDistance(startingUnits, 11.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);


	//Prepare to place player starting Mines 
	int playerGoldID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerGoldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 14.0);
	rmSetObjectDefMaxDistance(playerGoldID, 15.0);
	rmAddObjectDefConstraint(playerGoldID, avoidAll);
    rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);

	//Prepare to place player starting Crates (mostly food)
	int playerCrateID=rmCreateObjectDef("starting crates");
	rmAddObjectDefItem(playerCrateID, "crateOfFood", 2, 4.0);
	rmAddObjectDefItem(playerCrateID, "crateOfWood", 1, 4.0);
	rmAddObjectDefItem(playerCrateID, "crateOfCoin", 1, 4.0);
	rmSetObjectDefMinDistance(playerCrateID, 6);
	rmSetObjectDefMaxDistance(playerCrateID, 10);
	rmAddObjectDefConstraint(playerCrateID, avoidAll);
	rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);

	//Prepare to place player starting Berries
	int playerBerriesID=rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", rmRandInt(4,6), 4.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerBerriesID, 12);
    rmSetObjectDefMaxDistance(playerBerriesID, 13);		
	rmAddObjectDefConstraint(playerBerriesID, avoidAll);
    rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerBerriesID, true);

	//Prepare to place player starting Turkeys
	int playerTurkeyID=rmCreateObjectDef("player turkeys");
    rmAddObjectDefItem(playerTurkeyID, "turkey", rmRandInt(6,7), 3.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID, 12);
	rmSetObjectDefMaxDistance(playerTurkeyID, 14);	
	rmAddObjectDefConstraint(playerTurkeyID, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID, true);

	int playerTurkeyID2=rmCreateObjectDef("player turkeys second hunt");
    rmAddObjectDefItem(playerTurkeyID2, "turkey", rmRandInt(8,9), 6.0);	//(X,X) - number of objects.  The last # is the range of distance around the center point that the objects will place.  Low means tight, higher means more widely scattered.
    rmSetObjectDefMinDistance(playerTurkeyID2, 42);
	rmSetObjectDefMaxDistance(playerTurkeyID2, 45);	
	rmAddObjectDefConstraint(playerTurkeyID2, avoidAll);
    rmAddObjectDefConstraint(playerTurkeyID2, avoidImpassableLand);
    rmSetObjectDefCreateHerd(playerTurkeyID2, true);

	//Prepare to place player starting trees
	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeCaribbean", 3, 3.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);    //This was just added to try to keep these trees from stomping on CW's.
	rmSetObjectDefMinDistance(StartAreaTreeID, 16.0);	//changed from 12.0 
	rmSetObjectDefMaxDistance(StartAreaTreeID, 22.0);	//Changed from 19.0

	int waterSpawnPointID = 0;


	// --------------- Make load bar move. ----------------------------------------------------------------------------`
	rmSetStatusText("",0.70);
   
	// *********** Place Home City Water Spawn Flag ***************************************************

	for(i=1; <cNumberPlayers)
   {
	    // Place TC and starting units
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));				
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));   
		rmPlaceObjectDefAtLoc(playerBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc))); 
		rmPlaceObjectDefAtLoc(playerTurkeyID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										
		rmPlaceObjectDefAtLoc(playerTurkeyID2, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));  										

		rmPlaceObjectDefAtLoc(playerCrateID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place player starting trees
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

 if(ypIsAsian(i) && rmGetNomadStart() == false)	
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
      
		// Place water spawn points for the players
		waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 10.0);  // ...Flag", 1, 1.0); - the first number is the number of flags.  The next number is the float distance.
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		rmAddClosestPointConstraint(circleConstraint);

		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmClearClosestPointConstraints();
   }
	
   	// --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.75);

	//rmClearClosestPointConstraints();

	// ***************** SCATTERED RESOURCES **************************************
	// Scattered FORESTS
   int forestTreeID = 0;
   numTries=10*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, forestType);
         rmSetAreaForestDensity(forest, 0.6);
         rmSetAreaForestClumpiness(forest, 0.4);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
         rmAddAreaToClass(forest, rmClassID("classForest")); 
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC);
		 rmAddAreaConstraint(forest, avoidCW);
         rmAddAreaConstraint(forest, avoidSocket); 
		 rmAddAreaConstraint(forest, smallMesaConstraint);
         if(rmBuildArea(forest)==false)
         {
            // Stop trying once we fail 3 times in a row.
            failCount++;
            if(failCount==5)
               break;
         }
         else
            failCount=0; 
      } 

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.80);

	// Scattered MINES
	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "minegold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(goldID, avoidTC);
	rmAddObjectDefConstraint(goldID, avoidCW);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidCoin);
    rmAddObjectDefConstraint(goldID, avoidImpassableLand);
	rmPlaceObjectDefInArea(goldID, 0, bigIslandID, cNumberNonGaiaPlayers*3);

	// Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidTC);
	rmAddObjectDefConstraint(berriesID, avoidTP);   //Just added this, to make sure berries don't stomp on Trade Post sockets
	rmAddObjectDefConstraint(berriesID, avoidCW);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmPlaceObjectDefInArea(berriesID, 0, bigIslandID, cNumberNonGaiaPlayers*4);   //was *4

	// Just a FEW scattered TURKEYS
	int turkeyID=rmCreateObjectDef("random turkeys");
	rmAddObjectDefItem(turkeyID, "turkey", rmRandInt(8,9), 8.0); 
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(turkeyID, avoidTC);
	rmAddObjectDefConstraint(turkeyID, avoidCW);
	rmAddObjectDefConstraint(turkeyID, avoidRandomTurkeys);
	//rmAddObjectDefConstraint(turkeyID, avoidAll);
	//rmAddObjectDefConstraint(turkeyID, avoidRandomBerries);
	rmAddObjectDefConstraint(turkeyID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(turkeyID, true);
	rmPlaceObjectDefInArea(turkeyID, 0, bigIslandID, cNumberNonGaiaPlayers*5);   //Was *2 scattered Turkeys for awhile, but players wanted more fast food.

	// Define and place Nuggets
    	
  // check for KOTH game mode	
  /*if(rmGetIsKOTH()) {	
    	
    int randLoc = rmRandInt(1,2);	
    float xLoc = 0.55;	
    float yLoc = 0.25;	
    float walk = 0.035;	
    	
    if(randLoc == 1 || cNumberTeams > 2 || cNumberNonGaiaPlayers <= 3){	
      xLoc = .48;	
      yLoc = .53;	
    }	
    	
    ypKingsHillPlacer(xLoc, yLoc, walk, smallMesaConstraint);	
    rmEchoInfo("XLOC = "+xLoc);	
    rmEchoInfo("XLOC = "+yLoc);	
  }	*/
  	
 	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTC);
	rmAddObjectDefConstraint(nugget2, avoidCW);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWater20);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	if (cNumberNonGaiaPlayers > 4 && rmGetIsTreaty() == false) {
		rmSetNuggetDifficulty(4, 4);
		rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers);
		}
	if (cNumberNonGaiaPlayers > 2) {
		rmSetNuggetDifficulty(3, 3);
		rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers);
		}
	rmSetNuggetDifficulty(2, 2);
	rmPlaceObjectDefInArea(nugget2, 0, bigIslandID, cNumberNonGaiaPlayers*2);

	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	//rmAddObjectDefConstraint(nugget1, avoidCW);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater20);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bigIslandID, cNumberNonGaiaPlayers*rmRandInt(3,4));

	//Place Sheep -- added Sheep 11-28-05
	int sheepID=rmCreateObjectDef("sheep");
	rmAddObjectDefItem(sheepID, "sheep", 2, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidSheep);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	rmAddObjectDefConstraint(sheepID, avoidSocket);
	rmAddObjectDefConstraint(sheepID, avoidTradeRoute);
	rmAddObjectDefConstraint(sheepID, avoidTC);
	rmAddObjectDefConstraint(sheepID, avoidCW);
	rmAddObjectDefConstraint(sheepID, longPlayerConstraint);
	rmAddObjectDefConstraint(sheepID, avoidImpassableLand);
	rmPlaceObjectDefAtLoc(sheepID, 0, 0.46, 0.48, cNumberNonGaiaPlayers*1);

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.90);

	//Place Whales as much in big west bay only as possible --------------------------------------------------------
	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.2));		//Distance whales will be placed from the starting spot (below)
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.48, 0.63, cNumberNonGaiaPlayers*3 + rmRandInt(2,6));  //Was .43, .67 // .37, .66 -- The whales will be placed from this spot. 1 per player, plus 1 or 2 more.

	// Place Random Fish everywhere, but restrained to avoid whales ------------------------------------------------------

	int fishID=rmCreateObjectDef("fish Mahi");
	rmAddObjectDefItem(fishID, "FishMahi", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishVsWhaleID);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers); 

	/*
	int fish2ID=rmCreateObjectDef("fish Tarpon");
	rmAddObjectDefItem(fish2ID, "FishTarpon", 1, 0.0);
	rmSetObjectDefMinDistance(fish2ID, 0.0);
	rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fish2ID, fishVsFishTarponID);
	rmAddObjectDefConstraint(fish2ID, fishVsWhaleID);
	rmAddObjectDefConstraint(fish2ID, fishLand);
	rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);  //Was 9*.  Too many.
	*/

	if (cNumberNonGaiaPlayers <5)		// If less than 5 players, place extra fish.
	{
		rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 10*cNumberNonGaiaPlayers);
	}

    // --------------- Make load bar move. ----------------------------------------------------------------------------
	rmSetStatusText("",0.99);

	// RANDOM TREES

	int randomTreeID=rmCreateObjectDef("random tree");
	rmAddObjectDefItem(randomTreeID, "treeCaribbean", 1, 0.0);
	rmSetObjectDefMinDistance(randomTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(randomTreeID, avoidTC);
	rmAddObjectDefConstraint(randomTreeID, avoidCW);
	rmAddObjectDefConstraint(randomTreeID, avoidAll); 
	rmPlaceObjectDefInArea(randomTreeID, 0, bigIslandID, 8*cNumberNonGaiaPlayers);   //Scatter 8 random trees per player.

}  




