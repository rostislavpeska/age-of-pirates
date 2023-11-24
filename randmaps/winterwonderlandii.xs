// July 2004
// Nov 06 - YP update
//Durokan's 1v1 July 6 update for DE
// reworked by vividlyplain, November 2021
//
// AssertiveWall: Reworked rockies into winter wonderland II
// touched up by vividlyplain in the spirit of Christmas
// November, 2023

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01); 

	// 1v1 switch
	int switchAroo = rmRandInt(1,2);
//		switchAroo = 2; // for testing

	// Strings
	// sometimes make it all snow
	/* paintmix5: player area
	   paintmix4: mountain
	   paintmix1: mountain
	   paintmix7: forest

	*/
	int forecast = rmRandInt(1,3);
	if (forecast == 1)
	{
		string paintMix1 = "rockies_snow";		// rockies_grass
		string paintMix2 = "rockies_snow";	// rockies_snow
		string paintMix3 = "rockies_snow";
		string paintMix4 = "rockies_snow";	// rockies_grass_snowa
		string paintMix5 = "rockies_snow";
		string paintMix6 = "rockies_snow";
		string paintMix7 = "rockies_snow_forest";	// rockies_grass_forest
		string paintMix8 = "rockies_snow_forest";
	}
	else if (forecast == 2)
	{
		paintMix1 = "rockies_snow";		// rockies_grass
		paintMix2 = "rockies_grass_snowc";	// rockies_snow
		paintMix3 = "rockies_grass_snowd";
		paintMix4 = "rockies_snow";	// rockies_grass_snowa
		paintMix5 = "rockies_grass_snowc";
		paintMix6 = "rockies_grass_snowc";
		paintMix7 = "rockies_snow_forest";	// rockies_grass_forest
		paintMix8 = "rockies_snow_forest";
	}
	else
	{
		paintMix1 = "rockies_snow";		// rockies_grass
		paintMix2 = "rockies_grass_snow";	// rockies_snow
		paintMix3 = "rockies_grass_snow";
		paintMix4 = "rockies_snow";	// rockies_grass_snowa
		paintMix5 = "rockies_grass_snowb";
		paintMix6 = "rockies_grass_snowc";
		paintMix7 = "rockies_snow_forest";	// rockies_grass_forest
		paintMix8 = "rockies_snow_forest";
	}

	string treasureSet = "yukon";
	string shineAlight = "WinterWonderLand";		// Rockie_Skirmish
	string mntType1 = "rocky mountain edge";
	string mntType2 = "rocky mountain2";
	string forTesting = "testmix";

	string cliffPaint1 = "rockies\groundsnow1_roc";
	string cliffPaint2 = "rockies\ground4_roc";
	string food1 = "Reindeer";
	string food2 = "elk";
	string treeType1 = "TreeYukon";	//"TreeYukon";
	string treeType2 = "TreeYukonSnow";
	string treeType3 = "TreeGreatLakesSnow";	// TreeGreatLakesSnow
	string treeType4 = "TreeNewEnglandSnow";
	string treeType5 = "TreeRockiesSnow";
	string treeType6 = "TreeChristmas";  // "TreeRockies";
	string treeType7 = "TreeChristmas";	// TreeGreatLakes
	string natType1 = "zpXmassVillage"; 
	string natType2 = "";
	string natGrpName1 = "XMass_Village0";
	string natGrpName2 = "";
/*	if (rmRandFloat(0,1) <= 0.50)
	{
		natType2 = "Cree";
		natGrpName2 = "native cree village ";
	}
	else
	{
		natType2 = "Klamath";
		natGrpName2 = "native klamath village ";
	}*/
	string propType1 = "UnderbrushRockiesSnow";
	string propType2 = "UnderbrushPatagoniaSnow";
	string propType3 = "UnderbrushRockies";
	string propType4 = "UnderbrushForest";
	string propType5 = "UnderbrushPatagoniaDirt";
	string toiletPaper = "dirt";
	
	// ____________________ General ____________________
	// Picks the map size
	int playerTiles=13000;
	if (PlayerNum >= 4)
		playerTiles = 12000;
	if (PlayerNum >= 6)
		playerTiles = 11000;
	if (TeamNum > 2 || teamZeroCount != teamOneCount)
		playerTiles = 14000;

	int size=2.0*sqrt(PlayerNum*playerTiles);
	rmSetMapSize(size, size);

	// Make the corners
	rmSetWorldCircleConstraint(false);
	
	// Picks a default water height
	rmSetSeaLevel(12.0);
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 3, 0.5, 8.0); // type, frequency, octaves, persistence, variation

	// Picks default terrain and water
	rmTerrainInitialize(cliffPaint1, 12.00); 
	rmSetMapType(treasureSet);
	rmSetMapType("ScenarioFreezing");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetGlobalSnow(1.0);
    rmSetLightingSet(shineAlight);

	// Choose Mercs
	chooseMercs();

	//Define some classes. These are used later for constraints.
	int classPlayer = rmDefineClass("player");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	int classForest = rmDefineClass("Forest");
	int classGold = rmDefineClass("Gold");
	int classStartingResource = rmDefineClass("startingResource");
	int classIsland=rmDefineClass("island");
	int classNative=rmDefineClass("natives");
	rmDefineClass("importantItem");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("center");
	rmDefineClass("tradeIslands");
    rmDefineClass("socketClass");
	int classProp = rmDefineClass("prop");
	int classAvoidance = rmDefineClass("avoidance");
	int classPatch = rmDefineClass("patch");
	int classPatch2 = rmDefineClass("patch2");
	int classPatch3 = rmDefineClass("patch3");
	
	// Text
	rmSetStatusText("",0.10);
	
	// ____________________ Constraints ____________________
	// These are used to have objects and areas avoid each other
	// Cardinal Directions - "halves" of the map.
	int NWConstraint = rmCreateBoxConstraint("stay in NW portion", 0, 0.5, 1, 1);
	int SEConstraint = rmCreateBoxConstraint("stay in SE portion", 0, 0, 1, 0.5);
	int NEConstraint = rmCreateBoxConstraint("stay in NE portion", 0.5, 0, 1, 1);
	int SWConstraint = rmCreateBoxConstraint("stay in SW portion", 0, 0, 0.5, 1);
	int staySouthHalf = rmCreatePieConstraint("Stay south half", 0.50, 0.50,rmXFractionToMeters(0.0), rmXFractionToMeters(0.50), rmDegreesToRadians(190),rmDegreesToRadians(350));
	int stayNorthHalf = rmCreatePieConstraint("Stay north half", 0.50, 0.50,rmXFractionToMeters(0.0), rmXFractionToMeters(0.50), rmDegreesToRadians(010),rmDegreesToRadians(170));

	// Cardinal Directions & Map placement
	int avoidEdge = rmCreatePieConstraint("Avoid Edge",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidEdgeMore = rmCreatePieConstraint("Avoid Edge More",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.45), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("Avoid Center",0.5,0.5,rmXFractionToMeters(0.18), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterMin = rmCreatePieConstraint("Avoid Center min",0.5,0.5,rmXFractionToMeters(0.1), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("Stay Center", 0.50, 0.50, rmXFractionToMeters(0.0), rmXFractionToMeters(0.28), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenterMore = rmCreatePieConstraint("Stay Center more",0.45,0.45,rmXFractionToMeters(0.0), rmXFractionToMeters(0.26), rmDegreesToRadians(0),rmDegreesToRadians(360));

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

    //dk
    int avoidAll_dk=rmCreateTypeDistanceConstraint("avoid all_dk", "all", 3.0);
    int avoidWater5_dk = rmCreateTerrainDistanceConstraint("avoid water long_dk", "Land", false, 5.0);
    int avoidSocket2_dk=rmCreateClassDistanceConstraint("socket avoidance gold_dk", rmClassID("socketClass"), 8.0);
    int avoidTradeRouteSmall_dk = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small_dk", 6.0);
    int forestConstraintShort_dk=rmCreateClassDistanceConstraint("object vs. forest_dk", classForest, 2.0);
    int avoidHunt2_dk=rmCreateTypeDistanceConstraint("herds avoid herds2_dk", "huntable", 32.0);
    int avoidHunt3_dk=rmCreateTypeDistanceConstraint("herds avoid herds3_dk", "huntable", 18.0);
	int avoidAll2_dk=rmCreateTypeDistanceConstraint("avoid all2_dk", "all", 4.0);
    int avoidGoldTypeFar_dk = rmCreateTypeDistanceConstraint("avoid gold type  far 2_dk", "mine", 38.0);
    int circleConstraint2_dk=rmCreatePieConstraint("circle Constraint2_dk", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidMineForest_dk=rmCreateTypeDistanceConstraint("avoid mines forest _dk", "mine", 5.0);
	
	// Resource avoidance
	int avoidForest=rmCreateClassDistanceConstraint("avoid forest", rmClassID("Forest"), 26.0);
	int avoidForestMed=rmCreateClassDistanceConstraint("avoid forest med", rmClassID("Forest"), 20.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("avoid forest far", rmClassID("Forest"), 34.0);
	int avoidForestShort=rmCreateClassDistanceConstraint("avoid forest short", rmClassID("Forest"), 15.0);
	int avoidForestShorter=rmCreateClassDistanceConstraint("avoid forest shorter", rmClassID("Forest"), 8.0);
	int avoidForestMin=rmCreateClassDistanceConstraint("avoid forest min", rmClassID("Forest"), 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("Forest"), 25.0);
	int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("Forest"), 10.0);
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", food1, 40.0);
	int avoidHunt1Min = rmCreateTypeDistanceConstraint("avoid hunt1 min", food1, 4.0);
	int avoidHunt1Short = rmCreateTypeDistanceConstraint("avoid hunt1 short", food1, 20.0);
	int avoidHunt1Med = rmCreateTypeDistanceConstraint("avoid hunt1 med", food1, 30.0);
	int avoidHunt1Far = rmCreateTypeDistanceConstraint("avoid hunt1 far", food1, 50.0);
	int avoidHunt1VeryFar = rmCreateTypeDistanceConstraint("avoid hunt1 very far", food1, 65.0);
	int avoidHunt2Far = rmCreateTypeDistanceConstraint("avoid hunt2 far", food2, 60.0);
	int avoidHunt2 = rmCreateTypeDistanceConstraint("avoid hunt2", food2, 50.0);
	int avoidHunt2Med = rmCreateTypeDistanceConstraint("avoid hunt2 med", food2, 30.0);
	int avoidHunt2Short = rmCreateTypeDistanceConstraint("avoid hunt2 short", food2, 16.0);
	int avoidHunt2Min = rmCreateTypeDistanceConstraint("avoid hunt2 min", food2, 4.0);
	int avoidGoldMed = rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 35.0);
	int avoidGoldTypeShort = rmCreateTypeDistanceConstraint("coin avoids coin short", "gold", 20.0);
	int avoidGoldType = rmCreateTypeDistanceConstraint("coin avoids coin ", "gold", 45.0);
	int avoidGoldTypeMin = rmCreateTypeDistanceConstraint("coin avoids coin min ", "gold", 4.0);
	int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("coin avoids coin far ", "gold", 55.0);
	int avoidGoldMin=rmCreateClassDistanceConstraint("min distance vs gold", rmClassID("Gold"), 8.0);
	int avoidGoldShort = rmCreateClassDistanceConstraint ("gold avoid gold short", rmClassID("Gold"), 15.0);
	int avoidGold = rmCreateClassDistanceConstraint ("gold avoid gold med", rmClassID("Gold"), 30.0);
	int avoidGoldFar = rmCreateClassDistanceConstraint ("gold avoid gold far", rmClassID("Gold"), 64.0);
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", rmClassID("Gold"), 80.0);
	int avoidNuggetMin = rmCreateTypeDistanceConstraint("nugget avoid nugget min", "AbstractNugget", 4.0);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 8.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 40.0);
	int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget Far", "AbstractNugget", 64.0);
	int avoidTownCenterVeryFar = rmCreateTypeDistanceConstraint("avoid Town Center Very Far", "townCenter", 70.0);
	int avoidTownCenterFar = rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 60.0);
	int avoidTownCenter = rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 40.0); 
	int avoidTownCenterMed = rmCreateTypeDistanceConstraint("avoid Town Center med", "townCenter", 50.0);
	int avoidTownCenterShort = rmCreateTypeDistanceConstraint("avoid Town Center short", "townCenter", 30.0);
	int avoidTownCenterMin = rmCreateTypeDistanceConstraint("avoid Town Center min", "townCenter", 20.0);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 2.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 4.0);

	// Avoid impassable land
	int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 20.0);
	int avoidPatch2 = rmCreateClassDistanceConstraint("avoid patch2", rmClassID("patch2"), 20.0);
	int avoidPatch3 = rmCreateClassDistanceConstraint("avoid patch3", rmClassID("patch3"), 20.0);
	int avoidEmbellishmentMin = rmCreateClassDistanceConstraint("prop avoid prop min", rmClassID("prop"), 4.0);
	int avoidEmbellishment = rmCreateClassDistanceConstraint("prop avoid prop", rmClassID("prop"), 8.0);
	int avoidEmbellishmentFar = rmCreateClassDistanceConstraint("prop avoid prop far", rmClassID("prop"), 12.0);
	int avoidEmbellishmentVeryFar = rmCreateClassDistanceConstraint("prop avoid prop very far", rmClassID("prop"), 24.0);
	int avoidIslandMin=rmCreateClassDistanceConstraint("avoid island min", classIsland, 8.0);
	int avoidIslandShort=rmCreateClassDistanceConstraint("avoid island short", classIsland, 12.0);
	int avoidIsland=rmCreateClassDistanceConstraint("avoid island", classIsland, 16.0);
	int avoidIslandFar=rmCreateClassDistanceConstraint("avoid island far", classIsland, 32.0);
	int avoidCliff = rmCreateClassDistanceConstraint("avoid cliff", rmClassID("classCliff"), 12.0);
	int avoidCliffMin = rmCreateClassDistanceConstraint("avoid cliff min", rmClassID("classCliff"), 5.0);
	int avoidCliffMed = rmCreateClassDistanceConstraint("avoid cliff medium", rmClassID("classCliff"), 16.0);
	int avoidCliffFar = rmCreateClassDistanceConstraint("avoid cliff far", rmClassID("classCliff"), 24.0);
	
	// VP avoidance
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
	int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 4.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 2.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "socketTradeRoute", 2.0);
	int avoidTradeRouteSocketShort = rmCreateTypeDistanceConstraint("trade route socket short", "socketTradeRoute", 4.0);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 8.0);
	int avoidNatives = rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 8.0);
	int avoidNativesShort = rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 6.0);
	int stayNatives = rmCreateClassDistanceConstraint("stuff stays near natives", rmClassID("natives"), 6.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 12.0);
	int avoidNativesVeryFar = rmCreateClassDistanceConstraint("stuff avoids natives very far", rmClassID("natives"), 24.0);
	int avoidLandMin = rmCreateTerrainDistanceConstraint("avoid land min", "Land", true, 4.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land", "Land", true, 8.0);
	int avoidWater = rmCreateTerrainDistanceConstraint("avoid water ", "water", true, 15.0);
	int stayNearLand = rmCreateTerrainMaxDistanceConstraint("stay near land ", "land", true, 6.0);
	int stayNearWater = rmCreateTerrainMaxDistanceConstraint("stay near water ", "land", false, 10.0);
	int stayNearWaterFar = rmCreateTerrainMaxDistanceConstraint("stay near water far ", "land", false, 20.0);
	int stayInWater = rmCreateTerrainMaxDistanceConstraint("stay in water ", "water", true, 0.0);
	int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short", "water", true, 3.0);
	int avoidWaterFar = rmCreateTerrainDistanceConstraint("avoid water far", "water", true, 22.0);
	int avoidWaterVeryFar = rmCreateTerrainDistanceConstraint("avoid water very far", "water", true, 40.0);
	int avoidImpassableLandMin = rmCreateTerrainDistanceConstraint("avoid impassable land min", "Land", false, 1.0);
	int avoidImpassableLandShort = rmCreateTerrainDistanceConstraint("avoid impassable land short", "Land", false, 3.0);
	int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 8.0);
	int avoidImpassableLandMed=rmCreateTerrainDistanceConstraint("avoid impassable land medium", "Land", false, 15.0);
	int avoidImpassableLandFar = rmCreateTerrainDistanceConstraint("avoid impassable land far", "Land", false, 20.0);
	
	// ____________________ Player Placement ____________________
   // Set up player starting locations.
   if (cNumberTeams > 2 || teamZeroCount != teamOneCount)
   {
		if (cNumberTeams > 2)
			rmSetPlacementSection(0.99, 0.989999);
		rmSetTeamSpacingModifier(0.50);
		rmPlacePlayersCircular(0.34, 0.34, 0);
   }
   else
   {
		if (cNumberNonGaiaPlayers == 2)
		{
			if (switchAroo == 1)
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					rmPlacePlayer(1, 0.20, 0.32);
					rmPlacePlayer(2, 0.80, 0.68);
				}
				else
				{
					rmPlacePlayer(2, 0.20, 0.32);
					rmPlacePlayer(1, 0.80, 0.68);
				}
			}
			else
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					rmPlacePlayer(1, 0.20, 0.68);
					rmPlacePlayer(2, 0.80, 0.32);
				}
				else
				{
					rmPlacePlayer(2, 0.20, 0.68);
					rmPlacePlayer(1, 0.80, 0.32);
				}
			}
		}
		else
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.15, 0.30);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.32+0.005*PlayerNum, 0.32+0.005*PlayerNum, 0);

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.65, 0.80);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.32+0.005*PlayerNum, 0.32+0.005*PlayerNum, 0);
		}
   }

	// Text
	rmSetStatusText("",0.20);
	
	// ____________________ Map Parameters ____________________
	int outerRimID = rmCreateArea("outer rim");
	rmSetAreaLocation(outerRimID, 0.5, 0.5);
	rmSetAreaWarnFailure(outerRimID, false);
	rmSetAreaSize(outerRimID,0.70);
	rmSetAreaCoherence(outerRimID, 0.90);
	rmSetAreaObeyWorldCircleConstraint(outerRimID, false);
	rmSetAreaTerrainType(outerRimID, cliffPaint1);  
	rmSetAreaCliffType(outerRimID, mntType1);  
	rmSetAreaCliffEdge(outerRimID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(outerRimID, -4, 1.0, 0.3);
	rmSetAreaCliffPainting(outerRimID, true, false, true);
	rmAddAreaToClass(outerRimID, rmClassID("classCliff"));
	rmBuildArea(outerRimID);

	int avoidBorder = rmCreateAreaDistanceConstraint("avoid border", outerRimID, 4.0);
	int stayBorder = rmCreateAreaMaxDistanceConstraint("stay in border", outerRimID, 0.0);
	int stayNearBorder = rmCreateAreaMaxDistanceConstraint("stay near border", outerRimID, 4.0);

	int playerLevelID = rmCreateArea("player level");
	rmSetAreaLocation(playerLevelID, 0.5, 0.5);
	rmSetAreaWarnFailure(playerLevelID, false);
	rmSetAreaSize(playerLevelID,0.67);
	rmSetAreaCoherence(playerLevelID, 0.90);
	rmSetAreaObeyWorldCircleConstraint(playerLevelID, false);
	rmSetAreaTerrainType(playerLevelID, cliffPaint1);  
	rmSetAreaCliffType(playerLevelID, mntType1);  
	rmSetAreaCliffEdge(playerLevelID, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(playerLevelID, -8, 1.0, 0.3);
	rmSetAreaCliffPainting(playerLevelID, false, false, true);
//	rmAddAreaToClass(playerLevelID, rmClassID("classCliff"));
//	rmBuildArea(playerLevelID);	

	int avoidPlayerLevelMin = rmCreateAreaDistanceConstraint("avoid player level min", playerLevelID, 0.5);
	int avoidPlayerLevel = rmCreateAreaDistanceConstraint("avoid player level", playerLevelID, 4.0);
	int stayPlayerLevel = rmCreateAreaMaxDistanceConstraint("stay in player level", playerLevelID, 0.0);
	int stayNearPlayerLevel = rmCreateAreaMaxDistanceConstraint("stay near player level", playerLevelID, 8.0);
	int stayNearPlayerLevelShort = rmCreateAreaMaxDistanceConstraint("stay near player level short", playerLevelID, 2.0);

	// Player areas
	for (i=1; < numPlayer)
	{
		int playerAreaID = rmCreateArea("playerarea"+i);
		rmSetPlayerArea(i, playerAreaID);
		rmSetAreaSize(playerAreaID, rmAreaTilesToFraction(222));
		rmSetAreaCoherence(playerAreaID, 0.22);
		rmSetAreaWarnFailure(playerAreaID, false);
		rmSetAreaMix(playerAreaID, paintMix5);	
		rmSetAreaLocPlayer(playerAreaID, i);
		rmSetAreaObeyWorldCircleConstraint(playerAreaID, false);
		rmAddAreaToClass(playerAreaID, classIsland);
//		rmAddAreaConstraint(playerAreaID, stayPlayerLevel);
//		rmAddAreaConstraint(playerAreaID, avoidImpassableLandFar);
		rmBuildArea(playerAreaID);
	}

	// Border Decor
	int outerRimPropsID = rmCreateObjectDef("outer rim props");
    rmAddObjectDefItem(outerRimPropsID, propType1, 10, 20.0);
    rmAddObjectDefItem(outerRimPropsID, propType2, 7, 20.0);
	rmSetObjectDefMinDistance(outerRimPropsID, 0.0);
	rmSetObjectDefMaxDistance(outerRimPropsID, rmXFractionToMeters(0.50));
	rmAddObjectDefToClass(outerRimPropsID, rmClassID("prop"));
	rmAddObjectDefConstraint(outerRimPropsID, avoidIslandFar);
	rmAddObjectDefConstraint(outerRimPropsID, avoidStartingResources);
	rmAddObjectDefConstraint(outerRimPropsID, avoidEmbellishmentFar);
//	rmAddObjectDefConstraint(outerRimPropsID, avoidPlayerLevelMin);
//	rmPlaceObjectDefAtLoc(outerRimPropsID, 0, 0.50, 0.50, 20+5*PlayerNum);
	
	// ____________________ Trade Routes ____________________
	int tradeRouteID = rmCreateTradeRoute();
//    int tradeRouteID2 = rmCreateTradeRoute();

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
    rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
    rmSetObjectDefAllowOverlap(socketID, true);
    rmSetObjectDefMinDistance(socketID, 2.0);
    rmSetObjectDefMaxDistance(socketID, 8.0);      

/*	int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
    rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
    rmSetObjectDefAllowOverlap(socketID2, true);
    rmSetObjectDefMinDistance(socketID2, 2.0);
    rmSetObjectDefMaxDistance(socketID2, 8.0);      
*/
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		if (switchAroo == 1)
		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.30);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.40, 0.45);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.50);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.60, 0.55);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.80, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.70);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.20);
			}
			else
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.70);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.80, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.60, 0.55);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.50);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.40, 0.45);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.30);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.80);
			}
		}
		else
		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.70);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.40, 0.55);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.50);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.60, 0.45);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.80, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.30);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.80);
			}
			else
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.30);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.80, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.20);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.60, 0.45);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.50);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.40, 0.55);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.80);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.70);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.20);
			}
		}
	}
	else
	{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.93); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.90);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.81, 0.81);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.92, 0.65); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.95, 0.50); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.89, 0.29); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.81, 0.18); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.08); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.05); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.10); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.18, 0.18); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.07, 0.35); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.05, 0.50); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.09, 0.65); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.80); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.91); 
		rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.93); 
	}
    
/*    rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.20, 0.70);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.30, 0.80);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.40, 0.85);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.50, 0.90);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.60, 0.85);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.70, 0.80);
		}
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.80, 0.70);
*/	
    rmBuildTradeRoute(tradeRouteID, toiletPaper);
//    rmBuildTradeRoute(tradeRouteID2, toiletPaper);
	
	float sktLoc1 = 0.02;
	if (TeamNum > 2 || teamZeroCount != teamOneCount)
		sktLoc1 = 0.00;
	float sktLoc2 = 0.20;
	float sktLoc3 = 0.80;
	float sktLoc4 = 0.98;
	float sktLoc5 = 0.11;
	float sktLoc6 = 0.89;
	if (PlayerNum > 6)
	{
		sktLoc5 = 0.08;
		sktLoc6 = 0.92;
	}
	float sktLoc7 = 0.14;
	float sktLoc8 = 0.86;

    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		if (PlayerNum > 4)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc5);
	    	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}

		if (PlayerNum > 6)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc7);
	    	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);		

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc3);
	    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

		if (PlayerNum > 4)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc6);
	    	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}

		if (PlayerNum > 6)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc8);
	    	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}

		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc4);
	    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	}
	else
	{
		if (PlayerNum == 8)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.125);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.250);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.375);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.500);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.625);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.750);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.875);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
		else if (PlayerNum == 7)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1429);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.2858);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4287);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5716);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.7145);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.8574);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
		else if (PlayerNum == 6)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.16667);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.33334);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50001);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.66668);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.83335);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
		else if (PlayerNum == 5)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.20);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.40);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.60);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.80);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
		else if (PlayerNum == 4)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.25);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.75);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
		else if (PlayerNum == 3)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.33333);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.66666);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}		
		else if (PlayerNum == 2)
		{
			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}						
	}
/*    vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
		}
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc3);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
*/
	rmSetStatusText("",0.30);

	// Paint Areas
	int playerPaintID=rmCreateArea("paint the player level");
	rmSetAreaMix(playerPaintID, paintMix2);
//	rmSetAreaMix(playerPaintID, forTesting);
	rmSetAreaLocation(playerPaintID, 0.50, 0.50);
	rmSetAreaSize(playerPaintID, 0.90);
	rmSetAreaWarnFailure(playerPaintID, false);
	rmSetAreaCoherence(playerPaintID, 1.00);
//	rmAddAreaConstraint(playerPaintID, stayBorder);
//	rmAddAreaConstraint(playerPaintID, stayPlayerLevel);
	rmBuildArea(playerPaintID);	

	// ____________________ Natives ____________________
	// Set up Natives
	int subCiv0 = -1;
//	int subCiv1 = -1;
	subCiv0 = rmGetCivID(natType1);
//	subCiv1 = rmGetCivID(natType2);
	rmSetSubCiv(0, natType1);
//	rmSetSubCiv(1, natType2);

	// Place Natives
	int nativeID0 = -1;
	int nativeID1 = -1;
	int nativeID2 = -1;
	int nativeID3 = -1;

	int whichNative = rmRandInt(1,2);
	int whichVillage1 = rmRandInt(1,3);
	int whichVillage2 = rmRandInt(1,3);	
	int whichVillage3 = rmRandInt(1,3);
	int whichVillage4 = rmRandInt(1,3);

//	if (whichNative == 1)
//	{
		nativeID0 = rmCreateGrouping("native A", natGrpName1+whichVillage1);
		nativeID1 = rmCreateGrouping("native B", natGrpName1+whichVillage2);
//		nativeID2 = rmCreateGrouping("native C", natGrpName2+whichVillage3);
//		nativeID3 = rmCreateGrouping("native D", natGrpName2+whichVillage4);
//	}
//	else
//	{
//		nativeID0 = rmCreateGrouping("native A", natGrpName2+whichVillage1);
//		nativeID1 = rmCreateGrouping("native B", natGrpName2+whichVillage2);
//		nativeID2 = rmCreateGrouping("native C", natGrpName1+whichVillage3);	
//		nativeID3 = rmCreateGrouping("native D", natGrpName1+whichVillage4);	
//	}	
	
	rmAddGroupingToClass(nativeID0, rmClassID("natives"));
	rmAddGroupingToClass(nativeID1, rmClassID("natives"));
//	rmAddGroupingToClass(nativeID2, rmClassID("natives"));
//	rmAddGroupingToClass(nativeID3, rmClassID("natives"));

	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		if (switchAroo == 1)
		{
			if (PlayerNum == 2)
			{
				rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.35);
				rmPlaceGroupingAtLoc(nativeID1, 0, 0.25, 0.65);
			}
			else
			{
				rmPlaceGroupingAtLoc(nativeID0, 0, 0.70, 0.35);
				rmPlaceGroupingAtLoc(nativeID1, 0, 0.30, 0.65);
			}
		}
		else
		{
			if (PlayerNum == 2)
			{
				rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.65);
				rmPlaceGroupingAtLoc(nativeID1, 0, 0.25, 0.35);
			}
			else
			{
				rmPlaceGroupingAtLoc(nativeID0, 0, 0.70, 0.65);
				rmPlaceGroupingAtLoc(nativeID1, 0, 0.30, 0.35);
			}
		}
	}

//	if (PlayerNum == 2)
//		rmPlaceGroupingAtLoc(nativeID2, 0, 0.50, 0.50);
//	else
//	{
//		rmPlaceGroupingAtLoc(nativeID2, 0, 0.50, 0.63);
//		rmPlaceGroupingAtLoc(nativeID3, 0, 0.50, 0.37);
//	}

	// ____________________ Avoidance Islands ____________________
	int midIslandID=rmCreateArea("Mid Island");
	if (PlayerNum == 2)
		rmSetAreaSize(midIslandID, 0.35);
	else if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmSetAreaSize(midIslandID, 0.32+0.01*PlayerNum);
	else
		rmSetAreaSize(midIslandID, 0.25+0.005*PlayerNum);
	rmSetAreaLocation(midIslandID, 0.5, 0.5);
//	rmSetAreaMix(midIslandID, forTesting);
	rmSetAreaCoherence(midIslandID, 1.00);
	rmBuildArea(midIslandID); 
	
	int avoidMidIsland = rmCreateAreaDistanceConstraint("avoid mid island ", midIslandID, 8.0);
	int avoidMidIslandMin = rmCreateAreaDistanceConstraint("avoid mid island min", midIslandID, 0.5);
	int avoidMidIslandFar = rmCreateAreaDistanceConstraint("avoid mid island far", midIslandID, 16.0);
	int stayMidIsland = rmCreateAreaMaxDistanceConstraint("stay mid island ", midIslandID, 0.0);

	int stayNearEdge = rmCreatePieConstraint("stay near edge",0.5,0.5,rmXFractionToMeters(0.43), rmXFractionToMeters(0.49), rmDegreesToRadians(0),rmDegreesToRadians(360));
				
	// Text
	rmSetStatusText("",0.40);

	// ____________________ Starting Resources ____________________
	// Town center & units
	int TCID = rmCreateObjectDef("player TC");
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	if (rmGetNomadStart())
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
	else
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	rmAddObjectDefToClass(TCID, classStartingResource);
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 0.0);

	// Starting mines
	int playerGoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerGoldID, "Mine", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 16.0);
	rmSetObjectDefMaxDistance(playerGoldID, 16.0);
	rmAddObjectDefToClass(playerGoldID, classStartingResource);
	rmAddObjectDefToClass(playerGoldID, classGold);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteSocket);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerGoldID, avoidNativesShort);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteSocketMin);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmAddObjectDefConstraint(playerGoldID, stayMidIsland);
	
	int playerGold2ID = rmCreateObjectDef("player second mine");
	rmAddObjectDefItem(playerGold2ID, "Mine", 1, 0);
	rmSetObjectDefMinDistance(playerGold2ID, 26);
	rmSetObjectDefMaxDistance(playerGold2ID, 30+PlayerNum);
	rmAddObjectDefToClass(playerGold2ID, classStartingResource);
	rmAddObjectDefToClass(playerGold2ID, classGold);
	rmAddObjectDefConstraint(playerGold2ID, avoidGoldTypeShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidEdge);
	rmAddObjectDefConstraint(playerGold2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerGold2ID, avoidNativesShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(playerGold2ID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerGold2ID, avoidImpassableLandShort);
//	rmAddObjectDefConstraint(playerGold2ID, stayPlayerLevel);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmAddObjectDefConstraint(playerGold2ID, avoidMidIsland);
	else
		rmAddObjectDefConstraint(playerGold2ID, avoidMidIslandFar);
	
	// Starting trees
	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, treeType7, 1, 0.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 19);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, classForest);
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidForestMin);
	rmAddObjectDefConstraint(playerTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLandMin);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteSocketMin);

	int playerTree2ID = rmCreateObjectDef("player trees2");
	rmAddObjectDefItem(playerTree2ID, treeType1, 6, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType2, 4, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType3, 2, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType4, 2, 8.0);
    rmSetObjectDefMinDistance(playerTree2ID, 36);
    rmSetObjectDefMaxDistance(playerTree2ID, 40);
	rmAddObjectDefToClass(playerTree2ID, classStartingResource);
	rmAddObjectDefToClass(playerTree2ID, classForest);
	rmAddObjectDefConstraint(playerTree2ID, avoidEdge);
	rmAddObjectDefConstraint(playerTree2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTree2ID, avoidForestShort);
	rmAddObjectDefConstraint(playerTree2ID, avoidNativesShort);
//	rmAddObjectDefConstraint(playerTree2ID, stayPlayerLevel);
	rmAddObjectDefConstraint(playerTree2ID, avoidMidIslandFar);
	rmAddObjectDefConstraint(playerTree2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTree2ID, avoidTradeRouteSocket);
	
	// Starting herds
	int playerHerdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerHerdID, food1, 8, 3.0);
	rmSetObjectDefMinDistance(playerHerdID, 10);
	rmSetObjectDefMaxDistance(playerHerdID, 12);
	rmSetObjectDefCreateHerd(playerHerdID, true);
	rmAddObjectDefToClass(playerHerdID, classStartingResource);
	rmAddObjectDefConstraint(playerHerdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerdID, avoidNativesShort);
	rmAddObjectDefConstraint(playerHerdID, avoidImpassableLandMin);
	rmAddObjectDefConstraint(playerHerdID, avoidTradeRouteSocketMin);
		
	int playerHerd2ID = rmCreateObjectDef("player 2nd herd");
	rmAddObjectDefItem(playerHerd2ID, food2, 10, 6.0);
    rmSetObjectDefMinDistance(playerHerd2ID, 26);
    rmSetObjectDefMaxDistance(playerHerd2ID, 28);
	rmAddObjectDefToClass(playerHerd2ID, classStartingResource);
	rmSetObjectDefCreateHerd(playerHerd2ID, true);
	rmAddObjectDefConstraint(playerHerd2ID, avoidNativesShort);
	rmAddObjectDefConstraint(playerHerd2ID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerHerd2ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerHerd2ID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerd2ID, avoidEdge);
//	rmAddObjectDefConstraint(playerHerd2ID, stayPlayerLevel);
	if (PlayerNum > 2 && TeamNum == 2)
		rmAddObjectDefConstraint(playerHerd2ID, avoidMidIsland);
	if (teamZeroCount != teamOneCount)
		rmAddObjectDefConstraint(playerHerd2ID, avoidMidIslandFar);
		
	int playerHerd3ID = rmCreateObjectDef("player 3rd herd");
	rmAddObjectDefItem(playerHerd3ID, food1, 10, 6.0);
    rmSetObjectDefMinDistance(playerHerd3ID, 34);
    rmSetObjectDefMaxDistance(playerHerd3ID, 36);
	rmAddObjectDefToClass(playerHerd3ID, classStartingResource);
	rmSetObjectDefCreateHerd(playerHerd3ID, true);
	rmAddObjectDefConstraint(playerHerd3ID, avoidEdge);
	rmAddObjectDefConstraint(playerHerd3ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerHerd3ID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerd3ID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerHerd3ID, avoidNativesShort);
//	rmAddObjectDefConstraint(playerHerd3ID, stayPlayerLevel);
	rmAddObjectDefConstraint(playerHerd3ID, avoidMidIslandFar);
	
	// Starting treasures
	int playerNuggetID = rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMinDistance(playerNuggetID, 24.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 26.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingResourcesShort);
	if (teamZeroCount != teamOneCount)
		rmAddObjectDefConstraint(playerNuggetID, avoidMidIslandFar);
//	else 
//		rmAddObjectDefConstraint(playerNuggetID, avoidMidIsland);
	rmAddObjectDefConstraint(playerNuggetID, avoidNuggetMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidNativesShort);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLandMin);
//	rmAddObjectDefConstraint(playerNuggetID, stayPlayerLevel);
	rmAddObjectDefConstraint(playerNuggetID, avoidEdge);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteShort);

	//  Place Starting Objects/Resources
	
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		// starting native for weird spawns
		int playerNativeID = rmCreateGrouping("player native"+i, natGrpName1+rmRandInt(1,3));
		rmSetGroupingMinDistance(playerNativeID, 24.0);
		rmSetGroupingMaxDistance(playerNativeID, 36.0);
		rmAddGroupingToClass(playerNativeID, rmClassID("natives"));
		rmAddGroupingToClass(playerNativeID, classStartingResource);
		rmAddGroupingConstraint(playerNativeID, stayMidIsland);
		rmAddGroupingConstraint(playerNativeID, avoidStartingResourcesShort);
		rmAddGroupingConstraint(playerNativeID, avoidTradeRouteShort);
		rmAddGroupingConstraint(playerNativeID, avoidTradeRouteSocketMin);

		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2 || teamZeroCount != teamOneCount || rmGetIsKOTH() == true)
			rmPlaceGroupingAtLoc(playerNativeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGold2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerd2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTree2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2 || teamZeroCount != teamOneCount)
			rmPlaceObjectDefAtLoc(playerTree2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2 || teamZeroCount != teamOneCount)
			rmPlaceObjectDefAtLoc(playerHerd3ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i,1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
	}

	// Text
	rmSetStatusText("",0.50);

	// ____________________ Mountains ____________________
	// build mountains
	int centralMount1ID=rmCreateArea("center mountain 1");
	rmSetAreaTerrainType(centralMount1ID, cliffPaint2);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		rmSetAreaLocation(centralMount1ID, 0.50, 0.70);
		rmSetAreaSize(centralMount1ID, 0.07);
	}
	else
	{
		rmSetAreaLocation(centralMount1ID, 0.50, 0.50);
		rmSetAreaSize(centralMount1ID, 0.20);
	}
	rmSetAreaWarnFailure(centralMount1ID, false);
	rmSetAreaCliffType(centralMount1ID, mntType2);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmSetAreaCliffEdge(centralMount1ID, 4, 0.21, 0.0, 0.0, 0);
	else
		rmSetAreaCliffEdge(centralMount1ID, 8, 0.10, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralMount1ID, 10.0, 2.0, 0.3);
	rmSetAreaCoherence(centralMount1ID, 0.8);
	rmSetAreaSmoothDistance(centralMount1ID, 12);
	rmSetAreaHeightBlend(centralMount1ID, 1);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmAddAreaInfluenceSegment(centralMount1ID, 0.50, 0.60, 0.50, 0.80);
	rmSetAreaCliffPainting(centralMount1ID, true, false, true);
	rmAddAreaConstraint(centralMount1ID, avoidTradeRouteShort);
	rmAddAreaConstraint(centralMount1ID, avoidIslandMin);
	rmAddAreaConstraint(centralMount1ID, avoidNativesShort);
	rmAddAreaConstraint(centralMount1ID, avoidStartingResourcesShort);
//	rmAddAreaConstraint(centralMount1ID, stayPlayerLevel);
	rmBuildArea(centralMount1ID);

	int avoidMount1 = rmCreateAreaDistanceConstraint("avoid mount 1", centralMount1ID, 4.0);
	int avoidMount1Far = rmCreateAreaDistanceConstraint("avoid mount 1 far", centralMount1ID, 12.0);
	int stayMount1 = rmCreateAreaMaxDistanceConstraint("stay in mount 1", centralMount1ID, 0.0);
	int stayNearMount1 = rmCreateAreaMaxDistanceConstraint("stay near mount 1", centralMount1ID, 2.0);
	int avoidRamp1 = rmCreateCliffRampDistanceConstraint("avoid ramp1", centralMount1ID, 10);

	int centralMount2ID=rmCreateArea("center mountain 2");
	rmSetAreaTerrainType(centralMount2ID, cliffPaint2);
	rmSetAreaLocation(centralMount2ID, 0.50, 0.30);
	rmSetAreaSize(centralMount2ID, 0.07);
	rmSetAreaWarnFailure(centralMount2ID, false);
	rmSetAreaCliffType(centralMount2ID, mntType2);
	rmSetAreaCliffEdge(centralMount2ID, 4, 0.21, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralMount2ID, 10.0, 2.0, 0.3);
	rmSetAreaCoherence(centralMount2ID, 0.8);
	rmSetAreaSmoothDistance(centralMount2ID, 12);
	rmSetAreaHeightBlend(centralMount2ID, 1);
	rmAddAreaInfluenceSegment(centralMount2ID, 0.50, 0.40, 0.50, 0.20);
	rmSetAreaCliffPainting(centralMount2ID, true, false, true);
	rmAddAreaConstraint(centralMount2ID, avoidTradeRouteShort);
	rmAddAreaConstraint(centralMount2ID, avoidNativesShort);
	rmAddAreaConstraint(centralMount2ID, avoidStartingResourcesShort);
//	rmAddAreaConstraint(centralMount2ID, stayPlayerLevel);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmBuildArea(centralMount2ID);

	int avoidMount2 = rmCreateAreaDistanceConstraint("avoid mount 2", centralMount2ID, 4.0);
	int avoidMount2Far = rmCreateAreaDistanceConstraint("avoid mount 2 far", centralMount2ID, 12.0);
	int stayMount2 = rmCreateAreaMaxDistanceConstraint("stay in mount 2", centralMount2ID, 0.0);
	int stayNearMount2 = rmCreateAreaMaxDistanceConstraint("stay near mount 2", centralMount2ID, 2.0);
	int avoidRamp2 = rmCreateCliffRampDistanceConstraint("avoid ramp2", centralMount2ID, 10);

	// Static Mines 
	int staticgoldID = rmCreateObjectDef("static gold");
	rmAddObjectDefItem(staticgoldID, "MineGold", 1, 0.0);
	rmSetObjectDefMinDistance(staticgoldID, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(staticgoldID, rmXFractionToMeters(0.0));
	rmAddObjectDefToClass(staticgoldID, classGold);
	rmAddObjectDefConstraint(staticgoldID, avoidImpassableLandMin);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.50, 0.85);
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.50, 0.15);
	}

	// build peaks
	int centralPeak1ID=rmCreateArea("center peak 1");
	rmSetAreaTerrainType(centralPeak1ID, cliffPaint2);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		rmSetAreaLocation(centralPeak1ID, 0.50, 0.70);
		rmSetAreaSize(centralPeak1ID, 0.02);
	}
	else
	{
		rmSetAreaLocation(centralPeak1ID, 0.50, 0.50);
		rmSetAreaSize(centralPeak1ID, 0.05);
	}
	rmSetAreaWarnFailure(centralPeak1ID, false);
	rmSetAreaCliffType(centralPeak1ID, mntType2);
	if (rmGetIsKOTH() == true)
		rmSetAreaCliffEdge(centralPeak1ID, 3, 0.275, 0.0, 0.0, 0);
	else
		rmSetAreaCliffEdge(centralPeak1ID, 1, 1.00, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralPeak1ID, 6.0, 2.0, 0.3);
	rmSetAreaCoherence(centralPeak1ID, 0.8);
	rmSetAreaSmoothDistance(centralPeak1ID, 12);
	rmSetAreaHeightBlend(centralPeak1ID, 1);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmAddAreaInfluenceSegment(centralPeak1ID, 0.50, 0.65, 0.50, 0.75);
	rmSetAreaCliffPainting(centralPeak1ID, true, false, true);
	rmAddAreaConstraint(centralPeak1ID, stayMount1);
	rmAddAreaConstraint(centralPeak1ID, avoidTradeRoute);
	rmAddAreaConstraint(centralPeak1ID, avoidGoldMin);
//	rmAddAreaConstraint(centralPeak1ID, avoidImpassableLand);
	rmBuildArea(centralPeak1ID);

	int avoidPeak1 = rmCreateAreaDistanceConstraint("avoid peak 1", centralPeak1ID, 4.0);
	int stayPeak1 = rmCreateAreaMaxDistanceConstraint("stay in peak 1", centralPeak1ID, 0.0);

	int centralPeak2ID=rmCreateArea("center peak 2");
	rmSetAreaTerrainType(centralPeak2ID, cliffPaint2);
	rmSetAreaLocation(centralPeak2ID, 0.50, 0.30);
	rmSetAreaSize(centralPeak2ID, 0.02);
	rmSetAreaWarnFailure(centralPeak2ID, false);
	rmSetAreaCliffType(centralPeak2ID, mntType2);
	rmSetAreaCliffEdge(centralPeak2ID, 1, 1.00, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralPeak2ID, 6.0, 2.0, 0.3);
	rmSetAreaCoherence(centralPeak2ID, 0.8);
	rmSetAreaSmoothDistance(centralPeak2ID, 12);
	rmSetAreaHeightBlend(centralPeak2ID, 1);
	rmAddAreaInfluenceSegment(centralPeak2ID, 0.50, 0.35, 0.50, 0.25);
	rmSetAreaCliffPainting(centralPeak2ID, true, false, true);
	rmAddAreaConstraint(centralPeak2ID, stayMount2);
	rmAddAreaConstraint(centralPeak2ID, avoidTradeRoute);
	rmAddAreaConstraint(centralPeak2ID, avoidGoldMin);
//	rmAddAreaConstraint(centralPeak2ID, avoidImpassableLand);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmBuildArea(centralPeak2ID);

	int avoidPeak2 = rmCreateAreaDistanceConstraint("avoid peak 2", centralPeak2ID, 4.0);
	int stayPeak2 = rmCreateAreaMaxDistanceConstraint("stay in peak 2", centralPeak2ID, 0.0);

	// Paint Areas
	// player area painted before native placement
	/*int playerPaintID=rmCreateArea("paint the player level");
	rmSetAreaMix(playerPaintID, paintMix2);
//	rmSetAreaMix(playerPaintID, forTesting);
	rmSetAreaLocation(playerPaintID, 0.50, 0.50);
	rmSetAreaSize(playerPaintID, 0.90);
	rmSetAreaWarnFailure(playerPaintID, false);
	rmSetAreaCoherence(playerPaintID, 1.00);
//	rmAddAreaConstraint(playerPaintID, stayBorder);
//	rmAddAreaConstraint(playerPaintID, stayPlayerLevel);
	rmBuildArea(playerPaintID);	*/
	
	int mountPaint1ID=rmCreateArea("paint the valley");
	rmSetAreaMix(mountPaint1ID, paintMix4);
//	rmSetAreaMix(mountPaint1ID, forTesting);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
	{
		rmSetAreaLocation(mountPaint1ID, 0.50, 0.70);
		rmSetAreaSize(mountPaint1ID, 0.10);
	}
	else
	{
		rmSetAreaLocation(mountPaint1ID, 0.50, 0.50);
		rmSetAreaSize(mountPaint1ID, 0.25);
	}
	rmSetAreaWarnFailure(mountPaint1ID, false);
	rmSetAreaCoherence(mountPaint1ID, 0.85);
	rmAddAreaConstraint(mountPaint1ID, stayNearMount1);
	rmBuildArea(mountPaint1ID);	
	
	int mountPaint2ID=rmCreateArea("paint the valley2");
	rmSetAreaMix(mountPaint2ID, paintMix1);
//	rmSetAreaMix(mountPaint2ID, forTesting);
	rmSetAreaLocation(mountPaint2ID, 0.50, 0.30);
	rmSetAreaSize(mountPaint2ID, 0.10);
	rmSetAreaWarnFailure(mountPaint2ID, false);
	rmSetAreaCoherence(mountPaint2ID, 0.75);
	rmAddAreaConstraint(mountPaint2ID, stayNearMount2);
	if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		rmBuildArea(mountPaint2ID);	

	// ____________________ KOTH ____________________
	if (rmGetIsKOTH() == true)
	{
		// King's Island
		int kingislandID=rmCreateArea("King's Island");
		rmSetAreaSize(kingislandID, rmAreaTilesToFraction(333));
		rmSetAreaLocation(kingislandID, 0.50, 0.50);
		rmSetAreaMix(kingislandID, paintMix1);  
		rmAddAreaToClass(kingislandID, classIsland);
		rmSetAreaReveal(kingislandID, 01);
//		rmSetAreaBaseHeight(kingislandID, -4.0);
		rmSetAreaCoherence(kingislandID, 1.0);
		rmBuildArea(kingislandID); 
	
		// Place King's Hill
		float xLoc = 0.5;
		float yLoc = 0.5;
		float walk = 0.0;
	
		ypKingsHillPlacer(xLoc, yLoc, walk, 0);
		rmEchoInfo("XLOC = "+xLoc);
		rmEchoInfo("XLOC = "+yLoc);
	}
	
	int avoidKOTH = rmCreateAreaDistanceConstraint("avoid koth island", kingislandID, 4.0);
	
	// Text
	rmSetStatusText("",0.60);

	// ____________________ Mines ____________________
	// Team Mines
	int minecount = 3*PlayerNum;
	if (TeamNum > 2 || teamZeroCount != teamOneCount)
		minecount = 4*PlayerNum;

	for (i=0; < minecount)
	{
		int mapMinesID = rmCreateObjectDef("map mines"+i);
		rmAddObjectDefItem(mapMinesID, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(mapMinesID, rmXFractionToMeters(0.0));
		rmSetObjectDefMaxDistance(mapMinesID, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(mapMinesID, classGold);
		if (i < minecount/2)
			rmAddObjectDefConstraint(mapMinesID, stayNorthHalf);
		else
			rmAddObjectDefConstraint(mapMinesID, staySouthHalf);
		rmAddObjectDefConstraint(mapMinesID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(mapMinesID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(mapMinesID, avoidGoldFar);
		rmAddObjectDefConstraint(mapMinesID, avoidEdge);
	//	rmAddObjectDefConstraint(mapMinesID, stayPlayerLevel);
		rmAddObjectDefConstraint(mapMinesID, avoidNatives);
		rmAddObjectDefConstraint(mapMinesID, avoidImpassableLandShort);
		rmAddObjectDefConstraint(mapMinesID, avoidIslandMin);
		rmAddObjectDefConstraint(mapMinesID, avoidStartingResources);
		rmAddObjectDefConstraint(mapMinesID, avoidTownCenter);
		rmAddObjectDefConstraint(mapMinesID, avoidMount1);
		rmAddObjectDefConstraint(mapMinesID, avoidMount2);
		rmAddObjectDefConstraint(mapMinesID, avoidCenterMin);
		rmPlaceObjectDefAtLoc(mapMinesID, 0, 0.50, 0.50, 1);
	}

	// ____________________ Trees ____________________
	// Random Trees
	int rdmTreeCount = 10+2*PlayerNum;

	for (i=0; < rdmTreeCount)
	{
		int randomtreeID = rmCreateObjectDef("random tree "+i);
		rmAddObjectDefItem(randomtreeID, treeType1, rmRandInt(1,3), 3.0);
		rmAddObjectDefItem(randomtreeID, treeType2, rmRandInt(1,3), 3.0);
		rmAddObjectDefItem(randomtreeID, treeType3, rmRandInt(1,3), 3.0);
		rmAddObjectDefItem(randomtreeID, treeType4, rmRandInt(1,3), 3.0);
		rmSetObjectDefMinDistance(randomtreeID,  rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(randomtreeID,  rmXFractionToMeters(0.48));
		rmAddObjectDefToClass(randomtreeID, classForest);
		rmAddObjectDefConstraint(randomtreeID, avoidImpassableLand);
		rmAddObjectDefConstraint(randomtreeID, avoidForestShort);
		rmAddObjectDefConstraint(randomtreeID, avoidGoldShort);
		rmAddObjectDefConstraint(randomtreeID, avoidIslandMin);
		rmAddObjectDefConstraint(randomtreeID, avoidStartingResourcesMin);
		rmAddObjectDefConstraint(randomtreeID, avoidNativesShort);
		rmAddObjectDefConstraint(randomtreeID, avoidTradeRouteMin);
		rmAddObjectDefConstraint(randomtreeID, avoidTradeRouteSocketMin);
		if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		{
			if (i < rdmTreeCount/2)
			{
				rmAddObjectDefConstraint(randomtreeID, stayMount1);
				rmAddObjectDefConstraint(randomtreeID, avoidRamp1);
				rmAddObjectDefConstraint(randomtreeID, avoidPeak1);
			}
			else
			{
				rmAddObjectDefConstraint(randomtreeID, stayMount2);
				rmAddObjectDefConstraint(randomtreeID, avoidRamp2);
				rmAddObjectDefConstraint(randomtreeID, avoidPeak2);
			}
		}
		else
		{
			rmAddObjectDefConstraint(randomtreeID, stayMount1);
			rmAddObjectDefConstraint(randomtreeID, avoidRamp1);
			rmAddObjectDefConstraint(randomtreeID, avoidPeak1);
		}
		rmPlaceObjectDefAtLoc(randomtreeID, 0, 0.50, 0.50, 1);
	}

	// Text
	rmSetStatusText("",0.70);

	// Valley Forest
	int valleyforestcount = 14+3*PlayerNum;
	int stayInValleyForestPatch = -1;

	for (i=0; < valleyforestcount)
    {
        int valleyForestPatchID = rmCreateArea("main forest patch"+i);
        rmSetAreaWarnFailure(valleyForestPatchID, false);
		rmSetAreaObeyWorldCircleConstraint(valleyForestPatchID, true);
        rmSetAreaSize(valleyForestPatchID, rmAreaTilesToFraction(55));
        rmSetAreaCoherence(valleyForestPatchID, 0.2);
		rmSetAreaMix(valleyForestPatchID, paintMix7);
		rmAddAreaConstraint(valleyForestPatchID, avoidTradeRouteSocketShort);
		rmAddAreaConstraint(valleyForestPatchID, avoidForestShort);
		rmAddAreaConstraint(valleyForestPatchID, avoidGoldTypeMin);
		rmAddAreaConstraint(valleyForestPatchID, avoidNativesShort); 
		rmAddAreaConstraint(valleyForestPatchID, avoidCenterMin); 
		rmAddAreaConstraint(valleyForestPatchID, avoidMount1); 
		rmAddAreaConstraint(valleyForestPatchID, avoidRamp1); 
		if (TeamNum == 2 && teamZeroCount == teamOneCount && rmGetIsKOTH() == false)
		{
			rmAddAreaConstraint(valleyForestPatchID, avoidMount2); 
			rmAddAreaConstraint(valleyForestPatchID, avoidRamp2); 
		}
		rmAddAreaConstraint(valleyForestPatchID, avoidImpassableLandShort);        
		rmAddAreaConstraint(valleyForestPatchID, avoidIslandMin);
		if (i < (valleyforestcount/2)-2)
			rmAddAreaConstraint(valleyForestPatchID, stayNorthHalf); 
		else if (i < valleyforestcount-4)
			rmAddAreaConstraint(valleyForestPatchID, staySouthHalf); 
		rmBuildArea(valleyForestPatchID);

		stayInValleyForestPatch = rmCreateAreaMaxDistanceConstraint("stay in valley forest patch"+i, valleyForestPatchID, 0.0);

		int valleyForestTreeID = rmCreateObjectDef("valley forest trees"+i);
		rmAddObjectDefItem(valleyForestTreeID, treeType6, 1+PlayerNum/4, 3+PlayerNum);
		rmAddObjectDefItem(valleyForestTreeID, treeType2, 1+PlayerNum/2, 3+PlayerNum);
		rmAddObjectDefItem(valleyForestTreeID, treeType3, 1+PlayerNum/2, 3+PlayerNum);
		rmAddObjectDefItem(valleyForestTreeID, treeType4, 1+PlayerNum/2, 3+PlayerNum);
		rmSetObjectDefMinDistance(valleyForestTreeID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(valleyForestTreeID, rmXFractionToMeters(0.50));
		rmAddObjectDefToClass(valleyForestTreeID, classForest);
		rmAddObjectDefConstraint(valleyForestTreeID, stayInValleyForestPatch);
		rmAddObjectDefConstraint(valleyForestTreeID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(valleyForestTreeID, avoidImpassableLandMin);
		rmAddObjectDefConstraint(valleyForestTreeID, avoidIslandMin);
		rmPlaceObjectDefAtLoc(valleyForestTreeID, 0, 0.50, 0.50, 5);
    }

	// Text
	rmSetStatusText("",0.80);

	int huntcount = 4*PlayerNum;

	// Team Hunts
	for (i=0; < huntcount)
	{
		int mapHuntsID = rmCreateObjectDef("map hunts"+i);
		rmAddObjectDefItem(mapHuntsID, food1, 8, 3.0);
		rmSetObjectDefMinDistance(mapHuntsID, rmXFractionToMeters(0.0));
		rmSetObjectDefMaxDistance(mapHuntsID, rmXFractionToMeters(0.45));
		rmSetObjectDefCreateHerd(mapHuntsID, true);
		if (i < huntcount/2)
			rmAddObjectDefConstraint(mapHuntsID, stayNorthHalf);
		else
			rmAddObjectDefConstraint(mapHuntsID, staySouthHalf);
		rmAddObjectDefConstraint(mapHuntsID, avoidCenterMin);
		rmAddObjectDefConstraint(mapHuntsID, avoidHunt1);
		rmAddObjectDefConstraint(mapHuntsID, avoidHunt2);
		rmAddObjectDefConstraint(mapHuntsID, avoidMount1);
		rmAddObjectDefConstraint(mapHuntsID, avoidMount2);
		rmAddObjectDefConstraint(mapHuntsID, avoidIslandMin);
		rmAddObjectDefConstraint(mapHuntsID, avoidForestMin);
		rmAddObjectDefConstraint(mapHuntsID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(mapHuntsID, avoidImpassableLandShort);
		rmAddObjectDefConstraint(mapHuntsID, avoidNativesShort);
		rmAddObjectDefConstraint(mapHuntsID, avoidStartingResourcesShort);
		rmAddObjectDefConstraint(mapHuntsID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(mapHuntsID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(mapHuntsID, avoidEdge);
		rmAddObjectDefConstraint(mapHuntsID, avoidTownCenterFar);
		rmPlaceObjectDefAtLoc(mapHuntsID, 0, 0.50, 0.50, 1);
	}
	
	// Text
	rmSetStatusText("",0.90);

	// ____________________ Treasures ____________________
	int treasure2count = 4+PlayerNum;
	int treasure3count = 2+PlayerNum;
	int treasure4count = PlayerNum;
	
	// Treasures L4
	for (i=0; < treasure4count)
	{
		int nugget4ID = rmCreateObjectDef("nugget lvl4 "+i); 
		rmAddObjectDefItem(nugget4ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget4ID, 0);
		rmSetObjectDefMaxDistance(nugget4ID, rmXFractionToMeters(0.25));
		rmAddObjectDefConstraint(nugget4ID, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget4ID, avoidNugget);
		rmAddObjectDefConstraint(nugget4ID, avoidHunt1Min);
		rmAddObjectDefConstraint(nugget4ID, avoidHunt2Min);
		rmAddObjectDefConstraint(nugget4ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(nugget4ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(nugget4ID, avoidGoldMin);
		rmAddObjectDefConstraint(nugget4ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget4ID, avoidEdge); 
		rmAddObjectDefConstraint(nugget4ID, avoidNatives); 
		rmAddObjectDefConstraint(nugget4ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget4ID, avoidIsland); 
		if (i < treasure4count/2)
		{
			rmAddObjectDefConstraint(nugget4ID, stayMount1);
			rmAddObjectDefConstraint(nugget4ID, avoidPeak1);
			rmAddObjectDefConstraint(nugget4ID, avoidRamp1);
		}
		else
		{
			rmAddObjectDefConstraint(nugget4ID, stayMount2);
			rmAddObjectDefConstraint(nugget4ID, avoidPeak2);
			rmAddObjectDefConstraint(nugget4ID, avoidRamp2);
		}
//		if (PlayerNum > 2)
//		{
			rmSetNuggetDifficulty(4,4);
//			rmPlaceObjectDefAtLoc(nugget4ID, 0, 0.50, 0.50, 1);
//		}
	}

	// Treasures L3
	for (i=0; < treasure3count)
	{
		int nugget3ID = rmCreateObjectDef("nugget lvl3 "+i); 
		rmAddObjectDefItem(nugget3ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget3ID, rmXFractionToMeters(0.05));
		rmSetObjectDefMaxDistance(nugget3ID, rmXFractionToMeters(0.30));
		rmSetNuggetDifficulty(3,3);
		rmAddObjectDefConstraint(nugget3ID, avoidNuggetFar);
		rmAddObjectDefConstraint(nugget3ID, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget3ID, avoidHunt1Min);
		rmAddObjectDefConstraint(nugget3ID, avoidHunt2Min);
		rmAddObjectDefConstraint(nugget3ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(nugget3ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(nugget3ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nugget3ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget3ID, avoidEdge);	
//		rmAddObjectDefConstraint(nugget3ID, stayPlayerLevel); 
		rmAddObjectDefConstraint(nugget3ID, avoidNatives); 
		rmAddObjectDefConstraint(nugget3ID, avoidIsland); 
		rmAddObjectDefConstraint(nugget3ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget3ID, avoidMount1); 
		rmAddObjectDefConstraint(nugget3ID, avoidMount2); 
		rmAddObjectDefConstraint(nugget3ID, avoidRamp1); 
		rmAddObjectDefConstraint(nugget3ID, avoidRamp2); 
		if (i < treasure3count/2)
			rmAddObjectDefConstraint(nugget3ID, stayNorthHalf); 
		else
			rmAddObjectDefConstraint(nugget3ID, staySouthHalf); 
		rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.50, 0.50, 1);
	}

	// Treasures L2
	for (i=0; < treasure2count)
	{
		int nugget2ID = rmCreateObjectDef("nugget lvl2 "+i); 
		rmAddObjectDefItem(nugget2ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget2ID, rmXFractionToMeters(0.10));
		rmSetObjectDefMaxDistance(nugget2ID, rmXFractionToMeters(0.40));
		rmSetNuggetDifficulty(2,2);
		rmAddObjectDefConstraint(nugget2ID, avoidNugget);
		rmAddObjectDefConstraint(nugget2ID, avoidHunt1Min);
		rmAddObjectDefConstraint(nugget2ID, avoidHunt2Min);
		rmAddObjectDefConstraint(nugget2ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(nugget2ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(nugget2ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nugget2ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget2ID, avoidEdge);	
//		rmAddObjectDefConstraint(nugget2ID, stayPlayerLevel); 
		rmAddObjectDefConstraint(nugget2ID, avoidNatives); 
		rmAddObjectDefConstraint(nugget2ID, avoidTownCenterFar); 
		rmAddObjectDefConstraint(nugget2ID, avoidStartingResources); 
		rmAddObjectDefConstraint(nugget2ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget2ID, avoidIslandMin);
		rmAddObjectDefConstraint(nugget2ID, avoidMount1); 
		rmAddObjectDefConstraint(nugget2ID, avoidMount2); 
		rmAddObjectDefConstraint(nugget2ID, avoidRamp1); 
		rmAddObjectDefConstraint(nugget2ID, avoidRamp2); 
		if (i < treasure2count/2)
			rmAddObjectDefConstraint(nugget2ID, stayNorthHalf); 
		else
			rmAddObjectDefConstraint(nugget2ID, staySouthHalf); 
		rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.50, 0.50, 1);
	}

	// ____________________ Moar Embellishments ____________________
	int playerLevelPropsID = rmCreateObjectDef("player level decor");
		rmAddObjectDefItem(playerLevelPropsID, propType1, rmRandInt(1,3), 8.0);
		rmAddObjectDefItem(playerLevelPropsID, propType2, rmRandInt(2,3), 8.0);
		rmAddObjectDefItem(playerLevelPropsID, propType5, rmRandInt(1,2), 8.0);
		rmSetObjectDefMinDistance(playerLevelPropsID, 0);
		rmSetObjectDefMaxDistance(playerLevelPropsID, rmXFractionToMeters(0.5));
		rmAddObjectDefToClass(playerLevelPropsID, rmClassID("prop"));
		rmAddObjectDefConstraint(playerLevelPropsID, avoidIsland);
		rmAddObjectDefConstraint(playerLevelPropsID, avoidStartingResources);
		rmAddObjectDefConstraint(playerLevelPropsID, avoidEmbellishmentVeryFar);
//		rmPlaceObjectDefAtLoc(playerLevelPropsID, 0, 0.50, 0.50, 5+5*PlayerNum);

	int valleyPropsID = rmCreateObjectDef("valley decor");
		rmAddObjectDefItem(valleyPropsID, propType3, rmRandInt(1,4), 6.0);
		rmAddObjectDefItem(valleyPropsID, propType4, rmRandInt(1,5), 6.0);
		rmSetObjectDefMinDistance(valleyPropsID, 0);
		rmSetObjectDefMaxDistance(valleyPropsID, rmXFractionToMeters(0.5));
		rmAddObjectDefToClass(valleyPropsID, rmClassID("prop"));
		rmAddObjectDefConstraint(valleyPropsID, avoidIslandShort);
		rmAddObjectDefConstraint(valleyPropsID, avoidStartingResources);
		rmAddObjectDefConstraint(valleyPropsID, avoidEmbellishment);
//		rmPlaceObjectDefAtLoc(valleyPropsID, 0, 0.50, 0.50, 6+3*PlayerNum);

	// Text
	rmSetStatusText("", 1.00);

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
	rmSetTriggerConditionParam("TechID","cTechzpXMassExpansion"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffXMass"); //operator
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
		rmSetTriggerEffectParam("TechID","cTechzpConsulateXMass1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateXMass2"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateXMass3"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}
} // END
	
	