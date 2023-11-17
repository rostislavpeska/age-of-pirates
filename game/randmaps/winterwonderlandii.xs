// July 2004
// Nov 06 - YP update
//Durokan's 1v1 July 6 update for DE
// reworked by vividlyplain, November 2021
//
// AssertiveWall: Reworked rockies into winter wonderland II
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
	string treasureSet = "rockies";
	string shineAlight = "Rockie_Skirmish";
	string mntType1 = "rocky mountain edge";
	string mntType2 = "rocky mountain2";
	string forTesting = "testmix";
	string paintMix1 = "rockies_grass_snow";//"rockies_grass";
	string paintMix2 = "rockies_snow";
	string paintMix3 = "rockies_grass_snow";
	string paintMix4 = "rockies_grass_snowa";
	string paintMix5 = "rockies_grass_snowb";
	string paintMix6 = "rockies_grass_snowc";
	string paintMix7 = "rockies_grass_forest";
	string paintMix8 = "rockies_snow_forest";
	string cliffPaint1 = "rockies\groundsnow1_roc";
	string cliffPaint2 = "rockies\ground4_roc";
	string food1 = "Reindeer";
	string food2 = "elk";
	string treeType1 = "TreeChristmas";//"TreeYukon";
	string treeType2 = "TreeChristmas";//"TreeYukonSnow";
	string treeType3 = "TreeGreatLakesSnow";
	string treeType4 = "TreeNewEnglandSnow";
	string treeType5 = "TreeChristmas";//"TreeRockiesSnow";
	string treeType6 = "TreeRockies";
	string treeType7 = "TreeGreatLakes";
	string natType1 = "Klamath";
	string natType2 = "zpXmassVillage";
	string natGrpName1 = "native klamath village ";
	string natGrpName2 = "native xmass village";
	/*if (rmRandFloat(0,1) <= 0.50)
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
	string toiletPaper = "";
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		toiletPaper = "dirt";
	else
		toiletPaper = "snow";	
	
	// ____________________ General ____________________
	// Picks the map size
	int playerTiles=12000;
	if (PlayerNum >= 4)
		playerTiles = 11000;
	if (PlayerNum >= 6)
		playerTiles = 10000;
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
    rmSetLightingSet("WinterWonderLand");

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

	// Cardinal Directions & Map placement
	int avoidEdge = rmCreatePieConstraint("Avoid Edge",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidEdgeMore = rmCreatePieConstraint("Avoid Edge More",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.45), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("Avoid Center",0.5,0.5,rmXFractionToMeters(0.18), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterMin = rmCreatePieConstraint("Avoid Center min",0.5,0.5,rmXFractionToMeters(0.1), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("Stay Center", 0.50, 0.50, rmXFractionToMeters(0.0), rmXFractionToMeters(0.28), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenterMore = rmCreatePieConstraint("Stay Center more",0.45,0.45,rmXFractionToMeters(0.0), rmXFractionToMeters(0.26), rmDegreesToRadians(0),rmDegreesToRadians(360));

	int staySouthPart = rmCreatePieConstraint("Stay south part", 0.55, 0.55,rmXFractionToMeters(0.0), rmXFractionToMeters(0.60), rmDegreesToRadians(135),rmDegreesToRadians(315));
	int stayNorthHalf = rmCreatePieConstraint("Stay north half", 0.50, 0.50,rmXFractionToMeters(0.0), rmXFractionToMeters(0.50), rmDegreesToRadians(360),rmDegreesToRadians(180));
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
	int avoidForestMin=rmCreateClassDistanceConstraint("avoid forest min", rmClassID("Forest"), 4.0);
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
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", rmClassID("Gold"), 72.0);
	int avoidNuggetMin = rmCreateTypeDistanceConstraint("nugget avoid nugget min", "AbstractNugget", 10.0);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 16.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 24.0);
	int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget Far", "AbstractNugget", 40.0);
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
	int avoidCliffMin = rmCreateClassDistanceConstraint("avoid cliff min", rmClassID("classCliff"), 4.0);
	int avoidCliffMed = rmCreateClassDistanceConstraint("avoid cliff medium", rmClassID("classCliff"), 16.0);
	int avoidCliffFar = rmCreateClassDistanceConstraint("avoid cliff far", rmClassID("classCliff"), 24.0);
	
	// VP avoidance
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 12.0);
	int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 8.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "socketTradeRoute", 6.0);
	int avoidTradeRouteSocketShort = rmCreateTypeDistanceConstraint("trade route socket short", "socketTradeRoute", 8.0);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 20.0);
	int avoidNatives = rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 8.0);
	int avoidNativesShort = rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 4.0);
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
   if ( cNumberTeams > 2 || teamZeroCount != teamOneCount)
   {
		rmSetTeamSpacingModifier(0.50);
		rmPlacePlayersCircular(0.30, 0.30, 0);
   }
   else
   {
		rmSetPlacementTeam(0);
		if ( cNumberNonGaiaPlayers == 2 ) {
			if (switchAroo == 1)
				rmSetPlacementSection(0.20, 0.25);
			else
				rmSetPlacementSection(0.30, 0.35);
			}
		else
			rmSetPlacementSection(0.10, 0.40);
		rmPlacePlayersCircular(0.32+0.005*PlayerNum, 0.32+0.005*PlayerNum, 0);
		
		rmSetPlacementTeam(1);
		if ( cNumberNonGaiaPlayers == 2 ) {
			if (switchAroo == 1)
				rmSetPlacementSection(0.70, 0.75);
			else
				rmSetPlacementSection(0.80, 0.85);
			}
		else
			rmSetPlacementSection(0.60, 0.90);
		rmPlacePlayersCircular(0.32+0.005*PlayerNum, 0.32+0.005*PlayerNum, 0);
   }
	//	rmPlacePlayersCircular(0.45, 0.45, rmDegreesToRadians(5.0));

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
	rmSetAreaCliffPainting(outerRimID, false, false, true);
//	rmAddAreaToClass(outerRimID, rmClassID("classCliff"));
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
	rmBuildArea(playerLevelID);	

	int avoidPlayerLevelMin = rmCreateAreaDistanceConstraint("avoid player level min", playerLevelID, 0.5);
	int avoidPlayerLevel = rmCreateAreaDistanceConstraint("avoid player level", playerLevelID, 4.0);
	int stayPlayerLevel = rmCreateAreaMaxDistanceConstraint("stay in player level", playerLevelID, 0.0);
	int stayNearPlayerLevel = rmCreateAreaMaxDistanceConstraint("stay near player level", playerLevelID, 8.0);
	int stayNearPlayerLevelShort = rmCreateAreaMaxDistanceConstraint("stay near player level short", playerLevelID, 2.0);

	// trade islands for cliffs to avoid
	int tpIsland1ID=rmCreateArea("tp 1 Island");
	rmSetAreaSize(tpIsland1ID, 0.05);
	rmSetAreaLocation(tpIsland1ID, 0.8, 0.3);
	rmAddAreaInfluenceSegment(tpIsland1ID, 0.8, 0.3, 0.2, 0.3);
	rmAddAreaToClass(tpIsland1ID, classAvoidance);
//	rmSetAreaMix(tpIsland1ID, forTesting);
	rmSetAreaCoherence(tpIsland1ID, 1.00);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmBuildArea(tpIsland1ID); 

	int tpIsland2ID=rmCreateArea("tp 2 Island");
	rmSetAreaSize(tpIsland2ID, 0.05);
	rmSetAreaLocation(tpIsland2ID, 0.2, 0.7);
	rmAddAreaInfluenceSegment(tpIsland2ID, 0.8, 0.7, 0.2, 0.7);
	rmAddAreaToClass(tpIsland2ID, classAvoidance);
//	rmSetAreaMix(tpIsland2ID, forTesting);
	rmSetAreaCoherence(tpIsland2ID, 1.00);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmBuildArea(tpIsland2ID); 

	int tpIsland3ID=rmCreateArea("tp 3 Island");
	if (PlayerNum == 2)
		rmSetAreaSize(tpIsland3ID, 0.025);
	else
		rmSetAreaSize(tpIsland3ID, 0.05);
	rmSetAreaLocation(tpIsland3ID, 0.5, 0.5);
	if (PlayerNum > 2)
		rmAddAreaInfluenceSegment(tpIsland3ID, 0.0, 0.5, 1.0, 0.5);
	rmAddAreaInfluenceSegment(tpIsland3ID, 0.5, 1.0, 0.5, 0.0);
	rmAddAreaToClass(tpIsland3ID, classAvoidance);
//	rmSetAreaMix(tpIsland3ID, forTesting);
	rmSetAreaCoherence(tpIsland3ID, 1.00);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmBuildArea(tpIsland3ID); 

	// build valley
	int centralValleyID=rmCreateArea("center valley");
	rmSetAreaTerrainType(centralValleyID, cliffPaint2);
	rmSetAreaLocation(centralValleyID, 0.50, 0.50);
	rmSetAreaSize(centralValleyID, 0.15);
	rmSetAreaWarnFailure(centralValleyID, false);
	rmSetAreaCliffType(centralValleyID, mntType2);
	rmAddAreaCliffEdgeAvoidClass(centralValleyID, classAvoidance, 1);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmSetAreaCliffEdge(centralValleyID, 1, 1.00, 0.0, 0.0, 0);
	else
		rmSetAreaCliffEdge(centralValleyID, 8, 0.10, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(centralValleyID, -8.0, 2.0, 0.3);
	rmSetAreaCoherence(centralValleyID, 0.8);
	rmSetAreaSmoothDistance(centralValleyID, 12);
	rmSetAreaHeightBlend(centralValleyID, 1);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmAddAreaInfluenceSegment(centralValleyID, 0.50, 0.30, 0.50, 0.70);
//	rmAddAreaToClass(centralValleyID, rmClassID("classCliff"));
//	if (TeamNum == 2) {
//		rmAddAreaCliffWaypoint(centralValleyID, 0.5, 0.25);
//		rmAddAreaCliffWaypoint(centralValleyID, 0.5, 0.75);
//		}
//	else {
//		rmAddAreaCliffWaypoint(centralValleyID, 0.5, 0.35);
//		rmAddAreaCliffWaypoint(centralValleyID, 0.5, 0.65);
//		}
	rmSetAreaCliffPainting(centralValleyID, true, false, true);
	rmBuildArea(centralValleyID);

	int avoidValley = rmCreateAreaDistanceConstraint("avoid valley", centralValleyID, 4.0);
	int stayValley = rmCreateAreaMaxDistanceConstraint("stay in valley", centralValleyID, 0.0);

	// Paint Areas
	int playerPaintID=rmCreateArea("paint the player level");
	rmSetAreaMix(playerPaintID, paintMix2);
//	rmSetAreaMix(playerPaintID, forTesting);
	rmSetAreaLocation(playerPaintID, 0.50, 0.50);
	rmSetAreaSize(playerPaintID, 0.90);
	rmSetAreaWarnFailure(playerPaintID, false);
	rmSetAreaCoherence(playerPaintID, 1.00);
//	rmAddAreaConstraint(playerPaintID, stayBorder);
	rmAddAreaConstraint(playerPaintID, stayPlayerLevel);
	rmBuildArea(playerPaintID);	
	
	int valleyPaintID=rmCreateArea("paint the valley");
	rmSetAreaMix(valleyPaintID, paintMix4);
//	rmSetAreaMix(valleyPaintID, forTesting);
	rmSetAreaLocation(valleyPaintID, 0.50, 0.50);
	rmSetAreaSize(valleyPaintID, 0.20);
	rmSetAreaWarnFailure(valleyPaintID, false);
	rmSetAreaCoherence(valleyPaintID, 0.85);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmAddAreaInfluenceSegment(valleyPaintID, 0.50, 0.65, 0.50, 0.35);
	rmAddAreaConstraint(valleyPaintID, stayValley);
	rmBuildArea(valleyPaintID);	
	
	int valleyPaint2ID=rmCreateArea("paint the valley2");
	rmSetAreaMix(valleyPaint2ID, paintMix1);
//	rmSetAreaMix(valleyPaint2ID, forTesting);
	rmSetAreaLocation(valleyPaint2ID, 0.50, 0.50);
	rmSetAreaSize(valleyPaint2ID, 0.07);
	rmSetAreaWarnFailure(valleyPaint2ID, false);
	rmSetAreaCoherence(valleyPaint2ID, 0.75);
	if (TeamNum == 2 && teamZeroCount == teamOneCount)
		rmAddAreaInfluenceSegment(valleyPaint2ID, 0.50, 0.63, 0.50, 0.37);
	rmAddAreaConstraint(valleyPaint2ID, stayValley);
	rmBuildArea(valleyPaint2ID);	

	int avoidValleyGrassFar = rmCreateAreaDistanceConstraint("avoid grass far", valleyPaint2ID, 8.0);
	int avoidValleyGrass = rmCreateAreaDistanceConstraint("avoid grass", valleyPaint2ID, 4.0);
	int stayValleyGrass = rmCreateAreaMaxDistanceConstraint("stay in grass", valleyPaint2ID, 0.0);
	int stayNearValleyGrass = rmCreateAreaMaxDistanceConstraint("stay near grass", valleyPaint2ID, 4+2*PlayerNum);

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
		rmAddAreaConstraint(playerAreaID, stayPlayerLevel);
		rmAddAreaConstraint(playerAreaID, avoidImpassableLandFar);
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
	rmAddObjectDefConstraint(outerRimPropsID, avoidPlayerLevelMin);
	rmPlaceObjectDefAtLoc(outerRimPropsID, 0, 0.50, 0.50, 20+5*PlayerNum);
	
	rmSetStatusText("",0.30);

	// ____________________ Trade Routes ____________________
	int tradeRouteID = rmCreateTradeRoute();
    int tradeRouteID2 = rmCreateTradeRoute();

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
    rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
    rmSetObjectDefAllowOverlap(socketID, true);
    rmSetObjectDefMinDistance(socketID, 2.0);
    rmSetObjectDefMaxDistance(socketID, 8.0);      

	int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
    rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
    rmSetObjectDefAllowOverlap(socketID2, true);
    rmSetObjectDefMinDistance(socketID2, 2.0);
    rmSetObjectDefMaxDistance(socketID2, 8.0);      
	
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.80, 0.30);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.20);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.60, 0.15);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.10);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.40, 0.15);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.20);
		}
	rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.30);
    
    rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.20, 0.70);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.30, 0.80);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.40, 0.85);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.50, 0.90);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.60, 0.85);
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.70, 0.80);
		}
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.80, 0.70);
	
    rmBuildTradeRoute(tradeRouteID, toiletPaper);
    rmBuildTradeRoute(tradeRouteID2, toiletPaper);
	
	float sktLoc1 = 0.01;
	float sktLoc2 = 0.50;
	float sktLoc3 = 0.99;
	
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);		
		}
	socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc3);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
    vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
	if (TeamNum > 2 || teamZeroCount != teamOneCount) {
		socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
		}
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc3);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

	// ____________________ KOTH ____________________
	if (rmGetIsKOTH() == true) {
		// King's Island
		int kingislandID=rmCreateArea("King's Island");
		rmSetAreaSize(kingislandID, rmAreaTilesToFraction(333));
		rmSetAreaLocation(kingislandID, 0.50, 0.50);
		rmSetAreaMix(kingislandID, paintMix1);  
		rmAddAreaToClass(kingislandID, classIsland);
		rmSetAreaReveal(kingislandID, 01);
		rmSetAreaBaseHeight(kingislandID, -4.0);
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

	// ____________________ Natives ____________________
	// Set up Natives
	int subCiv0 = -1;
	int subCiv1 = -1;
	subCiv0 = rmGetCivID(natType1);
	subCiv1 = rmGetCivID(natType2);
	rmSetSubCiv(0, natType1);
	rmSetSubCiv(1, natType2);

	// Place Natives
	int nativeID0 = -1;
	int nativeID1 = -1;
	int nativeID2 = -1;
	int nativeID3 = -1;

	int whichNative = rmRandInt(1,2);
	int whichVillage1 = rmRandInt(1,5);
	int whichVillage2 = rmRandInt(1,5);	
	int whichVillage3 = rmRandInt(1,5);
	int whichVillage4 = rmRandInt(1,5);
	
	if (whichNative == 1) {
		nativeID0 = rmCreateGrouping("native A", natGrpName1+whichVillage1);
		nativeID1 = rmCreateGrouping("native B", natGrpName1+whichVillage2);
		nativeID2 = rmCreateGrouping("native C", natGrpName2+whichVillage3);
		nativeID3 = rmCreateGrouping("native D", natGrpName2+whichVillage4);
		}
	else {
		nativeID0 = rmCreateGrouping("native A", natGrpName2+whichVillage1);
		nativeID1 = rmCreateGrouping("native B", natGrpName2+whichVillage2);
		nativeID2 = rmCreateGrouping("native C", natGrpName1+whichVillage3);	
		nativeID3 = rmCreateGrouping("native D", natGrpName1+whichVillage4);	
		}	
	
	rmAddGroupingToClass(nativeID0, rmClassID("natives"));
	rmAddGroupingToClass(nativeID1, rmClassID("natives"));
	rmAddGroupingToClass(nativeID2, rmClassID("natives"));
	rmAddGroupingToClass(nativeID3, rmClassID("natives"));

	if (TeamNum == 2 && teamZeroCount == teamOneCount) {
		rmPlaceGroupingAtLoc(nativeID0, 0, 0.75, 0.50);
		rmPlaceGroupingAtLoc(nativeID1, 0, 0.25, 0.50);
		}
	else {
		rmPlaceGroupingAtLoc(nativeID0, 0, 0.87, 0.50);
		rmPlaceGroupingAtLoc(nativeID1, 0, 0.13, 0.50);
		}
	if (PlayerNum == 2)
		rmPlaceGroupingAtLoc(nativeID2, 0, 0.50, 0.50);
	else {
		rmPlaceGroupingAtLoc(nativeID2, 0, 0.50, 0.63);
		rmPlaceGroupingAtLoc(nativeID3, 0, 0.50, 0.37);
		}

	// ____________________ Avoidance Islands ____________________
	int midIslandID=rmCreateArea("Mid Island");
	if (teamZeroCount == teamOneCount && PlayerNum == 2)
		rmSetAreaSize(midIslandID, 0.33);
	else if (TeamNum == 2 && teamZeroCount == teamOneCount)
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
	{
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
	}
	else
	{
	rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	}
	rmAddObjectDefToClass(TCID, classStartingResource);
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 0.0);
	
	int frontORback = rmRandInt(1,2);
	
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
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteShort);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerGoldID, avoidTradeRouteSocketMin);
	if (TeamNum == 2 && teamZeroCount == teamOneCount) {
		if (frontORback == 1)
			rmAddObjectDefConstraint(playerGoldID, stayMidIsland);
		else
			rmAddObjectDefConstraint(playerGoldID, avoidMidIslandMin);
		}
	
	int playerGold2ID = rmCreateObjectDef("player second mine");
	rmAddObjectDefItem(playerGold2ID, "Mine", 1, 0);
	rmSetObjectDefMinDistance(playerGold2ID, 26);
	rmSetObjectDefMaxDistance(playerGold2ID, 26+PlayerNum/2);
	rmAddObjectDefToClass(playerGold2ID, classStartingResource);
	rmAddObjectDefToClass(playerGold2ID, classGold);
	rmAddObjectDefConstraint(playerGold2ID, avoidGoldTypeShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidEdge);
	rmAddObjectDefConstraint(playerGold2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerGold2ID, avoidNativesShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidTradeRouteShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerGold2ID, stayPlayerLevel);
	if (teamZeroCount == teamOneCount && TeamNum == 2)
		rmAddObjectDefConstraint(playerGold2ID, avoidMidIsland);
	if (teamZeroCount != teamOneCount)
		rmAddObjectDefConstraint(playerGold2ID, avoidMidIslandFar);
	
	// Starting trees
	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, treeType5, 1, 0.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 19);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, classForest);
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidForestMin);
	rmAddObjectDefConstraint(playerTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLandMin);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerTreeID, avoidValley);

	int playerTree2ID = rmCreateObjectDef("player trees2");
	rmAddObjectDefItem(playerTree2ID, treeType1, 6, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType2, 4, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType3, 2, 8.0);
	rmAddObjectDefItem(playerTree2ID, treeType4, 2, 8.0);
    rmSetObjectDefMinDistance(playerTree2ID, 36);
    rmSetObjectDefMaxDistance(playerTree2ID, 40);
	rmAddObjectDefToClass(playerTree2ID, classStartingResource);
	rmAddObjectDefToClass(playerTree2ID, classForest);
	rmAddObjectDefConstraint(playerTree2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTree2ID, avoidForestShort);
	rmAddObjectDefConstraint(playerTree2ID, avoidNativesShort);
	rmAddObjectDefConstraint(playerTree2ID, stayPlayerLevel);
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
	rmAddObjectDefConstraint(playerHerdID, avoidValley);
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
	rmAddObjectDefConstraint(playerHerd2ID, stayPlayerLevel);
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
	rmAddObjectDefConstraint(playerHerd3ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerHerd3ID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerHerd3ID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerHerd3ID, avoidNativesShort);
	rmAddObjectDefConstraint(playerHerd3ID, stayPlayerLevel);
	rmAddObjectDefConstraint(playerHerd3ID, avoidMidIslandFar);
	
	// Starting treasures
	int playerNuggetID = rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(playerNuggetID, 24.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 26.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingResourcesShort);
	if (teamZeroCount != teamOneCount)
		rmAddObjectDefConstraint(playerNuggetID, avoidMidIslandFar);
//	else 
//		rmAddObjectDefConstraint(playerNuggetID, avoidMidIsland);
	rmAddObjectDefConstraint(playerNuggetID, avoidNativesShort);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLandMin);
	rmAddObjectDefConstraint(playerNuggetID, stayPlayerLevel);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRouteShort);

	//  Place Starting Objects/Resources
	
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2 || teamZeroCount != teamOneCount)
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

	// ____________________ Mines ____________________
	// Static Mines 
	int staticgoldID = rmCreateObjectDef("static gold");
	rmAddObjectDefItem(staticgoldID, "Mine", 1, 2.0);
	rmSetObjectDefMinDistance(staticgoldID, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(staticgoldID, rmXFractionToMeters(0.03));
	rmAddObjectDefToClass(staticgoldID, classGold);
	rmAddObjectDefConstraint(staticgoldID, avoidIslandMin);
	rmAddObjectDefConstraint(staticgoldID, avoidTradeRouteShort);
	rmAddObjectDefConstraint(staticgoldID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(staticgoldID, avoidImpassableLandMin);
	rmAddObjectDefConstraint(staticgoldID, avoidNativesShort);
	rmAddObjectDefConstraint(staticgoldID, stayPlayerLevel);
	rmAddObjectDefConstraint(staticgoldID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(staticgoldID, avoidGoldShort);
	if (TeamNum == 2 && teamZeroCount == teamOneCount) {
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.50, 0.90);
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.50, 0.10);
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.40, 0.60);
		rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.60, 0.40);
		if (PlayerNum == 2) {
			if (switchAroo == 1) {
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.85, 0.40);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.15, 0.60);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.75, 0.20);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.25, 0.80);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.80, 0.80);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.20, 0.20);
				}
			else {
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.85, 0.60);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.15, 0.40);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.75, 0.80);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.25, 0.20);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.80, 0.20);
				rmPlaceObjectDefAtLoc(staticgoldID, 0, 0.20, 0.80);
				}
			}
		}

	// Team Mines 
	int mapMinesID = rmCreateObjectDef("map mines");
	rmAddObjectDefItem(mapMinesID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(mapMinesID, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(mapMinesID, rmXFractionToMeters(0.45));
	rmAddObjectDefToClass(mapMinesID, classGold);
	rmAddObjectDefConstraint(mapMinesID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(mapMinesID, avoidTradeRouteShort);
	rmAddObjectDefConstraint(mapMinesID, avoidGoldFar);
	rmAddObjectDefConstraint(mapMinesID, stayPlayerLevel);
	rmAddObjectDefConstraint(mapMinesID, avoidNatives);
	rmAddObjectDefConstraint(mapMinesID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(mapMinesID, avoidIslandMin);
	rmAddObjectDefConstraint(mapMinesID, avoidStartingResources);
	rmAddObjectDefConstraint(mapMinesID, avoidTownCenterFar);
	if (PlayerNum > 2) {
		rmPlaceObjectDefAtLoc(mapMinesID, 0, 0.50, 0.50, (3*PlayerNum)-4);
		if (TeamNum > 2 || teamZeroCount != teamOneCount)
			rmPlaceObjectDefAtLoc(mapMinesID, 0, 0.50, 0.50, PlayerNum);
		}

	// Random Trees
	int rdmTreeCount = rmRandInt(1,3);

	int randomtreeID = rmCreateObjectDef("random tree ");
		rmAddObjectDefItem(randomtreeID, treeType1, rdmTreeCount, 3.0);
		rmAddObjectDefItem(randomtreeID, treeType3, 4-rdmTreeCount, 3.0);
		rmSetObjectDefMinDistance(randomtreeID,  rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(randomtreeID,  rmXFractionToMeters(0.48));
		rmAddObjectDefToClass(randomtreeID, classForest);
		rmAddObjectDefConstraint(randomtreeID, avoidImpassableLand);
		rmAddObjectDefConstraint(randomtreeID, avoidForestShorter);
		rmAddObjectDefConstraint(randomtreeID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(randomtreeID, avoidIslandMin);
		rmAddObjectDefConstraint(randomtreeID, avoidStartingResourcesMin);
		rmAddObjectDefConstraint(randomtreeID, avoidNatives);
		rmAddObjectDefConstraint(randomtreeID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(randomtreeID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(randomtreeID, stayValley);
		rmAddObjectDefConstraint(randomtreeID, avoidValleyGrassFar);
		rmPlaceObjectDefAtLoc(randomtreeID, 0, 0.50, 0.50, 2+2*PlayerNum);

	// Text
	rmSetStatusText("",0.60);

	// ____________________ Trees ____________________
	// Valley Forest
	int valleyforestcount = 4+3*PlayerNum;
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
		rmAddAreaConstraint(valleyForestPatchID, stayNearValleyGrass); 
//		rmAddAreaConstraint(valleyForestPatchID, stayValley); 
		rmAddAreaConstraint(valleyForestPatchID, avoidImpassableLandShort);        
		rmAddAreaConstraint(valleyForestPatchID, avoidIslandMin);
		rmBuildArea(valleyForestPatchID);

		stayInValleyForestPatch = rmCreateAreaMaxDistanceConstraint("stay in valley forest patch"+i, valleyForestPatchID, 0.0);

		int valleyForestTreeID = rmCreateObjectDef("valley forest trees"+i);
			rmAddObjectDefItem(valleyForestTreeID, treeType6, 2+PlayerNum/2, 3+PlayerNum/2);
			rmAddObjectDefItem(valleyForestTreeID, treeType7, 2+PlayerNum/2, 3+PlayerNum/2);
			rmSetObjectDefMinDistance(valleyForestTreeID, rmXFractionToMeters(0.00));
			rmSetObjectDefMaxDistance(valleyForestTreeID, rmXFractionToMeters(0.50));
			rmAddObjectDefToClass(valleyForestTreeID, classForest);
			rmAddObjectDefConstraint(valleyForestTreeID, stayInValleyForestPatch);
			rmAddObjectDefConstraint(valleyForestTreeID, avoidTradeRouteSocketMin);
			rmAddObjectDefConstraint(valleyForestTreeID, avoidImpassableLandMin);
			rmAddObjectDefConstraint(valleyForestTreeID, stayValley);
			rmAddObjectDefConstraint(valleyForestTreeID, avoidIslandMin);
			rmPlaceObjectDefAtLoc(valleyForestTreeID, 0, 0.50, 0.50, 2);
    }

	// Text
	rmSetStatusText("",0.70);

	// Mountain Forest
	int mountainforestcount = 8+6*PlayerNum;
	int stayInMountainForestPatch = -1;

		int rndTree1 = rmRandInt(1,5);
		int rndTree2 = rmRandInt(6,10);
		int rndTree3 = rmRandInt(11,15);
		int rndTree4 = rmRandInt(16,20);
		int rndTree5 = rmRandInt(21,25);

		int treeCount2 = rndTree1+rndTree2;
		int treeCount3 = treeCount2+rndTree3;
		int treeCount4 = treeCount3+rndTree4;

	for (i=0; < mountainforestcount)
    {
        int mountainForestPatchID = rmCreateArea("mount forest patch"+i);
        rmSetAreaWarnFailure(mountainForestPatchID, false);
		rmSetAreaObeyWorldCircleConstraint(mountainForestPatchID, true);
        rmSetAreaSize(mountainForestPatchID, rmAreaTilesToFraction(100));
        rmSetAreaCoherence(mountainForestPatchID, 0.2);
		rmSetAreaMix(mountainForestPatchID, paintMix8);
		rmSetAreaForestType(mountainForestPatchID, "Christmas Forest");
		rmAddAreaConstraint(mountainForestPatchID, avoidTradeRouteSocketShort);
		rmAddAreaConstraint(mountainForestPatchID, avoidForest);
		rmAddAreaConstraint(mountainForestPatchID, avoidGoldTypeMin);
		rmAddAreaConstraint(mountainForestPatchID, avoidNativesShort); 
		rmAddAreaConstraint(mountainForestPatchID, avoidIsland); 
		rmAddAreaConstraint(mountainForestPatchID, stayPlayerLevel);        
		rmAddAreaConstraint(mountainForestPatchID, avoidImpassableLand);        
		rmAddAreaConstraint(mountainForestPatchID, avoidValleyGrass);        
		rmBuildArea(mountainForestPatchID);

		stayInMountainForestPatch = rmCreateAreaMaxDistanceConstraint("stay in forest patch"+i, mountainForestPatchID, 0.0);

		int mountainForestTreeID = rmCreateObjectDef("mount forest trees"+i);
			rmAddObjectDefItem(mountainForestTreeID, treeType1, rndTree1, 6.0);
			rmAddObjectDefItem(mountainForestTreeID, treeType2, rndTree2-rndTree1, 6.0);
			rmAddObjectDefItem(mountainForestTreeID, treeType3, rndTree3-treeCount2, 6.0);
			rmAddObjectDefItem(mountainForestTreeID, treeType4, rndTree4-treeCount3, 6.0);
			rmAddObjectDefItem(mountainForestTreeID, treeType5, rndTree5-treeCount4, 6.0);
			rmSetObjectDefMinDistance(mountainForestTreeID, rmXFractionToMeters(0.00));
			rmSetObjectDefMaxDistance(mountainForestTreeID, rmXFractionToMeters(0.50));
			rmAddObjectDefToClass(mountainForestTreeID, classForest);
			rmAddObjectDefConstraint(mountainForestTreeID, stayInMountainForestPatch);
			rmAddObjectDefConstraint(mountainForestTreeID, avoidTradeRouteSocketMin);
			rmAddObjectDefConstraint(mountainForestTreeID, avoidImpassableLandShort);
			rmAddObjectDefConstraint(mountainForestTreeID, stayPlayerLevel);
			rmAddObjectDefConstraint(mountainForestTreeID, avoidIslandMin);
			rmPlaceObjectDefAtLoc(mountainForestTreeID, 0, 0.50, 0.50, 2);
    }

	// Text
	rmSetStatusText("",0.80);

	// Moar Random Trees
	int randomtree2ID = rmCreateObjectDef("random tree2 ");
		rmAddObjectDefItem(randomtree2ID, treeType1, rmRandInt(3,4), 4.0);
		rmSetObjectDefMinDistance(randomtree2ID,  rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(randomtree2ID,  rmXFractionToMeters(0.48));
		rmAddObjectDefToClass(randomtree2ID, classForest);
		rmAddObjectDefConstraint(randomtree2ID, avoidForestShort);
		rmAddObjectDefConstraint(randomtree2ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(randomtree2ID, avoidStartingResourcesMin);
		rmAddObjectDefConstraint(randomtree2ID, avoidNatives);
		rmAddObjectDefConstraint(randomtree2ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(randomtree2ID, stayPlayerLevel);
		rmAddObjectDefConstraint(randomtree2ID, avoidImpassableLandFar);
		rmAddObjectDefConstraint(randomtree2ID, avoidValleyGrass);
		rmAddObjectDefConstraint(randomtree2ID, avoidIslandMin);
		rmPlaceObjectDefAtLoc(randomtree2ID, 0, 0.50, 0.50, 2*PlayerNum);

	// ____________________ Hunts ____________________	
	// Map Hunts
	int staticHuntID = rmCreateObjectDef("static hunts");
	rmAddObjectDefItem(staticHuntID, food2, 8, 3.0);
	rmSetObjectDefMinDistance(staticHuntID, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(staticHuntID, rmXFractionToMeters(0.05));
	rmSetObjectDefCreateHerd(staticHuntID, true);
	rmAddObjectDefConstraint(staticHuntID, avoidHunt2Short);
	rmAddObjectDefConstraint(staticHuntID, avoidIslandMin);
	rmAddObjectDefConstraint(staticHuntID, avoidForestMin);
	rmAddObjectDefConstraint(staticHuntID, avoidGoldTypeMin);
	rmAddObjectDefConstraint(staticHuntID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(staticHuntID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(staticHuntID, avoidNativesShort);
	rmAddObjectDefConstraint(staticHuntID, stayPlayerLevel);
	rmAddObjectDefConstraint(staticHuntID, avoidStartingResourcesShort);
	if (TeamNum == 2 && teamZeroCount == teamOneCount) {
		rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.40, 0.90);
		rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.60, 0.10);
		rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.50, 0.75);
		rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.50, 0.25);
		if (PlayerNum == 2) {
			if (switchAroo == 1) {
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.70, 0.80);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.80, 0.40);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.55, 0.55);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.70, 0.30);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.30, 0.20);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.20, 0.60);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.30, 0.70);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.45, 0.45);
				}
			else {
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.70, 0.20);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.80, 0.60);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.55, 0.55);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.70, 0.70);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.30, 0.80);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.20, 0.40);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.30, 0.30);
				rmPlaceObjectDefAtLoc(staticHuntID, 0, 0.45, 0.45);
				}
			}
		}

	// Team Hunts 
	int mapHuntsID = rmCreateObjectDef("map hunts");
	rmAddObjectDefItem(mapHuntsID, food1, 8, 3.0);
	rmSetObjectDefMinDistance(mapHuntsID, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(mapHuntsID, rmXFractionToMeters(0.45));
	rmSetObjectDefCreateHerd(mapHuntsID, true);
	rmAddObjectDefConstraint(mapHuntsID, avoidHunt1);
	rmAddObjectDefConstraint(mapHuntsID, avoidHunt2);
	rmAddObjectDefConstraint(mapHuntsID, avoidIslandMin);
	rmAddObjectDefConstraint(mapHuntsID, avoidForestMin);
	rmAddObjectDefConstraint(mapHuntsID, avoidGoldTypeMin);
	rmAddObjectDefConstraint(mapHuntsID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(mapHuntsID, avoidNativesShort);
	rmAddObjectDefConstraint(mapHuntsID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(mapHuntsID, avoidTradeRouteSocketMin);
	rmAddObjectDefConstraint(mapHuntsID, avoidTradeRouteShort);
	rmAddObjectDefConstraint(mapHuntsID, stayPlayerLevel);
	rmAddObjectDefConstraint(mapHuntsID, avoidTownCenterFar);
	if (PlayerNum > 2) {
		rmPlaceObjectDefAtLoc(mapHuntsID, 0, 0.50, 0.50, (5*PlayerNum)-4);
		if (TeamNum > 2 || teamZeroCount != teamOneCount)
			rmPlaceObjectDefAtLoc(mapHuntsID, 0, 0.50, 0.50, PlayerNum);
		}
	
	// Text
	rmSetStatusText("",0.90);
		
	// ____________________ Treasures ____________________
	int treasure1count = 6+PlayerNum;
	int treasure2count = 6+PlayerNum;
	int treasure3count = PlayerNum/2;
	
	// Treasures L3	
	int Nugget3ID = rmCreateObjectDef("nugget lvl3"); 
		rmAddObjectDefItem(Nugget3ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(Nugget3ID, 0);
		rmSetObjectDefMaxDistance(Nugget3ID, rmXFractionToMeters(0.25));
		rmAddObjectDefConstraint(Nugget3ID, avoidTownCenterFar);
		rmAddObjectDefConstraint(Nugget3ID, avoidNuggetFar);
		rmAddObjectDefConstraint(Nugget3ID, avoidHunt1Min);
		rmAddObjectDefConstraint(Nugget3ID, avoidHunt2Min);
		rmAddObjectDefConstraint(Nugget3ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(Nugget3ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(Nugget3ID, avoidGoldMin);
		rmAddObjectDefConstraint(Nugget3ID, avoidForestMin);	
		rmAddObjectDefConstraint(Nugget3ID, avoidEdge); 
		rmAddObjectDefConstraint(Nugget3ID, avoidNatives); 
		rmAddObjectDefConstraint(Nugget3ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(Nugget3ID, avoidIsland); 
		if (PlayerNum < 6)
			rmAddObjectDefConstraint(Nugget3ID, stayValleyGrass);
		else
			rmAddObjectDefConstraint(Nugget3ID, stayValley);
		if (PlayerNum >= 4 && rmGetIsTreaty() == false) {
			rmSetNuggetDifficulty(4,4);
			rmPlaceObjectDefAtLoc(Nugget3ID, 0, 0.50, 0.50, treasure3count);
			}
		if (PlayerNum > 2) {
			rmSetNuggetDifficulty(3,3);
			rmPlaceObjectDefAtLoc(Nugget3ID, 0, 0.50, 0.50, treasure3count);
			}

	// Treasures L2	
	int Nugget2ID = rmCreateObjectDef("nugget lvl2 "); 
		rmAddObjectDefItem(Nugget2ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(Nugget2ID, 0);
		if (PlayerNum == 2)
			rmSetObjectDefMaxDistance(Nugget2ID, rmXFractionToMeters(0.10));
		else
			rmSetObjectDefMaxDistance(Nugget2ID, rmXFractionToMeters(0.40));
		rmSetNuggetDifficulty(2,2);
		rmAddObjectDefConstraint(Nugget2ID, avoidNugget);
		rmAddObjectDefConstraint(Nugget2ID, avoidTownCenterFar);
		rmAddObjectDefConstraint(Nugget2ID, avoidHunt1Min);
		rmAddObjectDefConstraint(Nugget2ID, avoidHunt2Min);
		rmAddObjectDefConstraint(Nugget2ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(Nugget2ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(Nugget2ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(Nugget2ID, avoidForestMin);	
		rmAddObjectDefConstraint(Nugget2ID, stayPlayerLevel); 
		rmAddObjectDefConstraint(Nugget2ID, avoidNatives); 
		rmAddObjectDefConstraint(Nugget2ID, avoidIsland); 
		rmAddObjectDefConstraint(Nugget2ID, avoidImpassableLand); 
		if (PlayerNum == 2) {
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.60, 0.60);
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.40, 0.40);
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.70, 0.90);
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.70, 0.10);
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.30, 0.90);
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.30, 0.10);
			}
		else
			rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.50, 0.50, treasure2count);

	int nuggetExtraID = rmCreateObjectDef("nugget extra "); 
		rmAddObjectDefItem(nuggetExtraID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nuggetExtraID, 0);
		rmSetObjectDefMaxDistance(nuggetExtraID, rmXFractionToMeters(0.40));
		if (PlayerNum == 2)
			rmSetNuggetDifficulty(2,2);
		else
			rmSetNuggetDifficulty(3,3);
		rmAddObjectDefConstraint(nuggetExtraID, avoidNuggetShort);
		rmAddObjectDefConstraint(nuggetExtraID, stayValley);
		rmAddObjectDefConstraint(nuggetExtraID, avoidHunt1Min);
		rmAddObjectDefConstraint(nuggetExtraID, avoidHunt2Min);
		rmAddObjectDefConstraint(nuggetExtraID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(nuggetExtraID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(nuggetExtraID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nuggetExtraID, avoidForestMin);	
		rmAddObjectDefConstraint(nuggetExtraID, avoidNatives); 
		rmAddObjectDefConstraint(nuggetExtraID, avoidIsland); 
		rmAddObjectDefConstraint(nuggetExtraID, avoidImpassableLand); 
		rmPlaceObjectDefAtLoc(nuggetExtraID, 0, 0.50, 0.50, PlayerNum+2);
	
	// Treasures L1
	int Nugget1ID = rmCreateObjectDef("nugget lvl1 "); 
		rmAddObjectDefItem(Nugget1ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(Nugget1ID, 0);
		rmSetObjectDefMaxDistance(Nugget1ID, rmXFractionToMeters(0.48));
		rmSetNuggetDifficulty(1,1);
		rmAddObjectDefConstraint(Nugget1ID, avoidNugget);
		rmAddObjectDefConstraint(Nugget1ID, avoidHunt1Min);
		rmAddObjectDefConstraint(Nugget1ID, avoidHunt2Min);
		rmAddObjectDefConstraint(Nugget1ID, avoidTradeRouteSocketMin);
		rmAddObjectDefConstraint(Nugget1ID, avoidTradeRouteShort);
		rmAddObjectDefConstraint(Nugget1ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(Nugget1ID, avoidForestMin);	
		rmAddObjectDefConstraint(Nugget1ID, stayPlayerLevel); 
		rmAddObjectDefConstraint(Nugget1ID, avoidNatives); 
		rmAddObjectDefConstraint(Nugget1ID, avoidTownCenterFar); 
		rmAddObjectDefConstraint(Nugget1ID, avoidStartingResources); 
		rmAddObjectDefConstraint(Nugget1ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(Nugget1ID, avoidIslandMin);
		rmPlaceObjectDefAtLoc(Nugget1ID, 0, 0.50, 0.50, treasure1count);

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
		rmAddObjectDefConstraint(playerLevelPropsID, avoidValleyGrass);
		rmPlaceObjectDefAtLoc(playerLevelPropsID, 0, 0.50, 0.50, 5+5*PlayerNum);

	int valleyPropsID = rmCreateObjectDef("valley decor");
		rmAddObjectDefItem(valleyPropsID, propType3, rmRandInt(1,4), 6.0);
		rmAddObjectDefItem(valleyPropsID, propType4, rmRandInt(1,5), 6.0);
		rmSetObjectDefMinDistance(valleyPropsID, 0);
		rmSetObjectDefMaxDistance(valleyPropsID, rmXFractionToMeters(0.5));
		rmAddObjectDefToClass(valleyPropsID, rmClassID("prop"));
		rmAddObjectDefConstraint(valleyPropsID, avoidIslandShort);
		rmAddObjectDefConstraint(valleyPropsID, avoidStartingResources);
		rmAddObjectDefConstraint(valleyPropsID, avoidEmbellishment);
		rmAddObjectDefConstraint(valleyPropsID, stayValleyGrass);
		rmPlaceObjectDefAtLoc(valleyPropsID, 0, 0.50, 0.50, 6+3*PlayerNum);

	// Text
	rmSetStatusText("", 1.00);

} // END
	
	