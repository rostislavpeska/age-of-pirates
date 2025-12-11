// BAYOU
// Nov 06 - YP update
// April 2021 edited by vividlyplain for DE

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

// Main entry point for random map script
include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{

   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

	// ____________________ Strings ____________________
	string swampType = "Yukon River4";
	string paintMix = "yukon snow";
	string swampIslandPaintMix = "great_lakes_ice";
	string treasureSet = "yukon";
	string shineAlight = "WinterWonderLand";
	string food1 = "Reindeer";
	string food2 = "elk";
	string treeType2 = "TreeYukonSnow";
	string treeType1 = "TreeChristmas";
	string natType1 = "zpXmassNutcrackerVillage";
	string natType2 = "inuitnatives";	
	string natGrpName1 = "xmass_village_nutcracker_";
	string natGrpName2 = "native inuit village 0";

/* // original natives - removed by vividlyplain
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;
   int subCiv3=-1;
   int subCiv4=-1;

   if (rmAllocateSubCivs(5) == true)
   {
		subCiv0=rmGetCivID("Seminoles");
		rmEchoInfo("subCiv0 is Seminole "+subCiv0);
      if (subCiv0 >= 0)
			rmSetSubCiv(0, "Seminoles");
		
		subCiv1=rmGetCivID("Cherokee");
		rmEchoInfo("subCiv1 is Cherokee "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "Cherokee");

		subCiv2=rmGetCivID("Cherokee");
		rmEchoInfo("subCiv2 is Cherokee "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "Cherokee");

		subCiv3=rmGetCivID("Seminoles");
		rmEchoInfo("subCiv3 is Seminoles "+subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "Seminoles");
		
		if (rmRandFloat(0,1) < 0.5)
		{
			subCiv4=rmGetCivID("Seminoles");
			rmEchoInfo("subCiv4 is Seminoles "+subCiv4);
			if (subCiv4 >= 0)
				rmSetSubCiv(4, "Seminoles");
		}
	}			
*/
   // Picks the map size
   //int playerTiles=14400; // OLD SIZE
   int playerTiles = 11000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 9000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 7000;		
   int size=1.8*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Picks a default water height
   rmSetSeaLevel(1.0);
   rmSetLightingSet("WinterWonderLand");

   // Picks default terrain and water

//  rmSetMapElevationParameters(long type, float minFrequency, long numberOctaves, float persistence, float heightVariation)
//	rmSetMapElevationParameters(cElevTurbulence, 0.1, 4, 0.3, 2.0);
	rmSetSeaType("Great Lakes Ice2");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("rockies_snow");
	rmTerrainInitialize("water");
	rmSetMapType("bayou");
	rmSetMapType("water");
	//	rmSetMapType("grass");
	rmSetWorldCircleConstraint(true);

	// Choose mercs.
	chooseMercs();

	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classCliff");
	rmDefineClass("classPatch");
	int classbigContinent=rmDefineClass("big continent");
	rmDefineClass("importantItem");
	rmDefineClass("secrets");
	rmDefineClass("startingUnit");
	int classBay=rmDefineClass("bay");

	int classIsland=rmDefineClass("island");
	int classBonusIsland=rmDefineClass("bonus island");
	int classIce = rmDefineClass("classIce");
	rmDefineClass("corner");

		// added by vividlyplain
		int classForest = rmDefineClass("Forest");
		int classGold = rmDefineClass("Gold");
		int classStartingResource = rmDefineClass("startingResource");
		int classNative = rmDefineClass("natives");
		int classProp = rmDefineClass("prop");
	
	// -------------Define constraints
	// These are used to have objects and areas avoid each other

	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	int islandEdgeConstraint=rmCreateBoxConstraint("islands in center", 0.30, 0.30, 0.70, 0.70, 0.01);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("continent stays away from players", classPlayer, 24.0);
	int avoidTC=rmCreateTypeDistanceConstraint("avoid TC", "towncenter", 30.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player constraints
	int islandConstraint=rmCreateClassDistanceConstraint("stay away from islands", classIsland, 10.0);
	int playerConstraint=rmCreateClassDistanceConstraint("bonus Settlement stay away from players", classPlayer, 10);
	int bonusIslandConstraint=rmCreateClassDistanceConstraint("avoid bonus island", classBonusIsland, 30.0);
	int cornerConstraint=rmCreateClassDistanceConstraint("stay away from corner", rmClassID("corner"), 15.0);
	int cornerOverlapConstraint=rmCreateClassDistanceConstraint("don't overlap corner", rmClassID("corner"), 2.0);
	int bayConstraint=rmCreateClassDistanceConstraint("avoid bay", classBay, 6);
	int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
	int flagConstraint=rmCreateHCGPConstraint("flags avoid same", 30.0);
	int nearWater10 = rmCreateTerrainDistanceConstraint("near water", "Water", true, 10.0);
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 8.0);

	// Bonus area constraint.
	int bigContinentConstraint=rmCreateClassDistanceConstraint("avoid big island", classbigContinent, 20.0);

	// Resource avoidance
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 1.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "gold", 50.0);
	int farAvoidCoin=rmCreateTypeDistanceConstraint("silver avoid coin", "gold", 45.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("silver avoid coin short", "gold", 30.0);
//	int avoidNugget = rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 50.0);
	int avoidDeer=rmCreateTypeDistanceConstraint("food avoids food", "deer", 50.0);
	int avoidTurkey=rmCreateTypeDistanceConstraint("food avoids turkey", "turkey", 30.0);
	int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 10.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
	int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	
	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Avoid Ice
	int avoidIce = rmCreateClassDistanceConstraint("avoid ice", rmClassID("classIce"), 12.0);

	// VP avoidance
	int avoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 50.0);
	int shortAvoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
  int shorterAvoidImportantItem = rmCreateClassDistanceConstraint("secrets etc avoid each other shorter", rmClassID("importantItem"), 4.0);

	// Constraint to avoid water.
	int avoidWater8 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 8.0);

		// added by vividlylpainint avoidForestFar=rmCreateClassDistanceConstraint("avoid forest far", rmClassID("Forest"), 40.0);
		int avoidForest=rmCreateClassDistanceConstraint("avoid forest", rmClassID("Forest"), 30.0);
		int avoidForestShort=rmCreateClassDistanceConstraint("avoid forest short", rmClassID("Forest"), 15.0);
		int avoidForestShorter=rmCreateClassDistanceConstraint("avoid forest shorter", rmClassID("Forest"), 8.0);
		int avoidForestMin=rmCreateClassDistanceConstraint("avoid forest min", rmClassID("Forest"), 4.0);
		int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("Forest"), 20.0);
		int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("Forest"), 20.0);
		int avoidHunt2 = rmCreateTypeDistanceConstraint("avoid hunt2", food2, 30.0);
		int avoidHunt2Far = rmCreateTypeDistanceConstraint("avoid hunt2 far", food2, 40.0);
		int avoidHunt2Short = rmCreateTypeDistanceConstraint("avoid hunt2 short", food2, 20.0);
		int avoidHunt2Min = rmCreateTypeDistanceConstraint("avoid hunt2 min", food2, 10.0);
		int avoidHunt1Far = rmCreateTypeDistanceConstraint("avoid hunt1 far", food1, 60.0);
		int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", food1, 44.0);
		int avoidHunt1Short = rmCreateTypeDistanceConstraint("avoid hunt1 short", food1, 30.0);
		int avoidHunt1Min = rmCreateTypeDistanceConstraint("avoid hunt1 min", food1, 10.0);
		int avoidGoldMed = rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 25.0);
		int avoidGoldTypeShort = rmCreateTypeDistanceConstraint("coin avoids coin short", "gold", 20.0);
		int avoidGoldType = rmCreateTypeDistanceConstraint("coin avoids coin ", "gold", 45.0);
		int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("coin avoids coin far ", "gold", 52.0);
		int avoidGoldMin=rmCreateClassDistanceConstraint("min distance vs gold", rmClassID("Gold"), 8.0);
		int avoidGoldShort = rmCreateClassDistanceConstraint ("gold avoid gold short", rmClassID("Gold"), 15.0);
		int avoidGold = rmCreateClassDistanceConstraint ("gold avoid gold med", rmClassID("Gold"), 30.0);
		int avoidGoldFar = rmCreateClassDistanceConstraint ("gold avoid gold far", rmClassID("Gold"), 50.0);
		int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", rmClassID("Gold"), 75.0);
		int avoidNuggetMin = rmCreateTypeDistanceConstraint("nugget avoid nugget min", "AbstractNugget", 10.0);
		int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 20.0);
		int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 30.0);
		int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget Far", "AbstractNugget", 60.0);
		int avoidNuggetVeryFar = rmCreateTypeDistanceConstraint("nugget avoid nugget very far", "AbstractNugget", 80.0);
		int avoidTownCenterVeryFar = rmCreateTypeDistanceConstraint("avoid Town Center Very Far", "townCenter", 85.0);
		int avoidTownCenterFar = rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 60.0);
		int avoidTownCenter = rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 50.0); //46
		int avoidTownCenterMed = rmCreateTypeDistanceConstraint("avoid Town Center med", "townCenter", 30.0);
		int avoidTownCenterShort = rmCreateTypeDistanceConstraint("avoid Town Center short", "townCenter", 20.0);
		int avoidTownCenterMin = rmCreateTypeDistanceConstraint("avoid Town Center min", "townCenter", 18.0);
		int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 12.0);
		int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 8.0);
		int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 4.0);
		int avoidNativesShort = rmCreateClassDistanceConstraint("avoid natives short", rmClassID("natives"), 8.0);
		int avoidNativesMin = rmCreateClassDistanceConstraint("avoid natives min", rmClassID("natives"), 4.0);
		int avoidNatives = rmCreateClassDistanceConstraint("avoid natives", rmClassID("natives"), 12.0);
		int avoidNativesFar = rmCreateClassDistanceConstraint("avoid natives far", rmClassID("natives"), 20.0);
		int avoidProp = rmCreateClassDistanceConstraint("prop avoid prop", rmClassID("prop"), 10.0);
		int avoidPropFar = rmCreateClassDistanceConstraint("prop avoid prop far", rmClassID("prop"), 20.0);
		int avoidPropVeryFar = rmCreateClassDistanceConstraint("prop avoid prop very far", rmClassID("prop"), 30.0);
		int avoidPropExtreme = rmCreateClassDistanceConstraint("prop avoid prop extremely far", rmClassID("prop"), 40.0);
		int avoidIslandZero=rmCreateClassDistanceConstraint("avoid island zero", classIsland, 0.5);
		int avoidIslandTiny=rmCreateClassDistanceConstraint("avoid island tiny", classIsland, 1.5);
		int avoidIslandMin=rmCreateClassDistanceConstraint("avoid island min", classIsland, 8.0);
		int avoidIslandShort=rmCreateClassDistanceConstraint("avoid island short", classIsland, 12.0);
		int avoidIsland=rmCreateClassDistanceConstraint("avoid island", classIsland, 14.0+0.25*PlayerNum);
		int avoidIslandFar=rmCreateClassDistanceConstraint("avoid island far", classIsland, 18.0);
		int stayIsland=rmCreateClassDistanceConstraint("stay island", classIsland, 0.0);
		int stayNearEdge = rmCreatePieConstraint("stay near edge",0.5,0.5,rmXFractionToMeters(0.43), rmXFractionToMeters(0.49), rmDegreesToRadians(0),rmDegreesToRadians(360));

	// Text
	rmSetStatusText("",0.10);

	// ************************ ICE SHEET *******************************

   // Place Ice sheet if Winter.

	int IceArea1ID=rmCreateArea("Ice Area 1");
	rmSetAreaSize(IceArea1ID, 0.6);
	rmSetAreaLocation(IceArea1ID, 0.46, 0.50);
	//rmSetAreaTerrainType(IceArea1ID, "great_lakes\ground_ice1_glw");
	rmSetAreaMix(IceArea1ID, "great_lakes_ice");
	//rmAddAreaToClass(IceArea1ID, classGreatLake);
	rmSetAreaBaseHeight(IceArea1ID, 2.0);
		rmAddAreaInfluencePoint(IceArea1ID, 0.54, 0.5);
		rmSetAreaObeyWorldCircleConstraint(IceArea1ID, false);
	rmSetAreaSmoothDistance(IceArea1ID, 8);
	rmSetAreaCoherence(IceArea1ID, 0.8);
	rmBuildArea(IceArea1ID); 

	// ____________________ Player Placement ____________________
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

		if (cNumberTeams <= 2) // 1v1 and TEAM
		{
			if (teamZeroCount == 1 && teamOneCount == 1) // 1v1
			{
				float OneVOnePlacement=rmRandFloat(0.0, 0.9);
				if ( OneVOnePlacement < 0.5)
				{
					rmPlacePlayer(1, 0.50, 0.15);
					rmPlacePlayer(2, 0.50, 0.85);
				}
				else
				{
					rmPlacePlayer(2, 0.50, 0.15);
					rmPlacePlayer(1, 0.50, 0.85);
				}

			}
			else if (teamZeroCount == teamOneCount) // equal N of players per TEAM
			{
				if (teamZeroCount == 2) // 2v2
				{
					rmSetPlacementTeam(0);
					rmPlacePlayersLine(0.60, 0.15, 0.40, 0.15, 0, 0);

					rmSetPlacementTeam(1);
					rmPlacePlayersLine(0.60, 0.85, 0.40, 0.85, 0, 0);
				}
				else // 3v3, 4v4
				{
					rmSetPlacementTeam(0);
					rmSetTeamSpacingModifier(0.50);
					rmSetPlacementSection(0.90, 0.10);
					rmPlacePlayersCircular(0.40, 0.40, 0.0);
					
					rmSetPlacementTeam(1);
					rmSetTeamSpacingModifier(0.50);
					rmSetPlacementSection(0.40, 0.60);
					rmPlacePlayersCircular(0.40, 0.40, 0.0);
				}
			}
			else // unequal N of players per TEAM
			{
				if (teamZeroCount == 1 || teamOneCount == 1) // one team is one player
				{
					if (teamZeroCount < teamOneCount) // 1v2, 1v3, 1v4, etc.
					{
						rmSetPlacementTeam(0);
						rmPlacePlayersLine(0.50, 0.15, 0.49, 0.15, 0, 0);

						rmSetPlacementTeam(1);
						if (teamOneCount == 2)
							rmPlacePlayersLine(0.60, 0.85, 0.40, 0.85, 0, 0);
						else
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.85, 0.15);
							rmPlacePlayersCircular(0.4, 0.4, 0.0);
					}
					else // 2v1, 3v1, 4v1, etc.
					{
						rmSetPlacementTeam(1);
						rmPlacePlayersLine(0.50, 0.85, 0.49, 0.85, 0, 0);

						rmSetPlacementTeam(0);
						if (teamOneCount == 2)
							rmPlacePlayersLine(0.60, 0.15, 0.40, 0.15, 0, 0);
						else
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.35, 0.65);
							rmPlacePlayersCircular(0.4, 0.4, 0.0);
					}
				}
				else if (teamZeroCount == 2 || teamOneCount == 2) // one team has 2 players
				{
					if (teamZeroCount < teamOneCount) // 2v3, 2v4, etc.
					{
						rmSetPlacementTeam(0);
						rmPlacePlayersLine(0.60, 0.15, 0.40, 0.15, 0, 0);

						rmSetPlacementTeam(1);
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.875, 0.125);
							rmPlacePlayersCircular(0.4, 0.4, 0.0);
					}
					else // 3v2, 4v2, etc.
					{
						rmSetPlacementTeam(0);
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.375, 0.625);
							rmPlacePlayersCircular(0.4, 0.4, 0.0);
							
						rmSetPlacementTeam(1);
						rmPlacePlayersLine(0.60, 0.85, 0.40, 0.85, 0, 0);
					}
				}
				else // 3v4, 4v3, etc.
				{
					rmSetPlacementTeam(0);
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.40, 0.60);
							rmPlacePlayersCircular(0.38, 0.38, 0.0);
							
					rmSetPlacementTeam(1);
							rmSetTeamSpacingModifier(0.50);
							rmSetPlacementSection(0.90, 0.10);
							rmPlacePlayersCircular(0.38, 0.38, 0.0);
				}
			}
		}
		else // FFA
		{
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.0, 1.0);
		rmPlacePlayersCircular(0.4, 0.4, 0.0);
		}

	// ____________________ Map Parameters ____________________
	// King's Island
	int kingIslandID=rmCreateArea("King's Island");
	rmSetAreaSize(kingIslandID, rmAreaTilesToFraction(500));
	rmSetAreaLocation(kingIslandID, 0.5, 0.5);
	rmSetAreaMix(kingIslandID, paintMix); 
	rmAddAreaToClass(kingIslandID, classIsland);
	rmSetAreaBaseHeight(kingIslandID, 4.0);
	rmSetAreaCoherence(kingIslandID, 0.50);
	rmAddAreaConstraint(kingIslandID, avoidIslandMin);
	rmBuildArea(kingIslandID); 

	if (rmGetIsKOTH() == true) {

		// Place King's Hill
		float xLoc = 0.5;
		float yLoc = 0.5;
		float walk = 0.0;
	
		ypKingsHillPlacer(xLoc, yLoc, walk, 0);
		rmEchoInfo("XLOC = "+xLoc);
		rmEchoInfo("XLOC = "+yLoc);
		}

	int avoidKingIsland = rmCreateAreaDistanceConstraint("avoid king's island", kingIslandID, 0.5);
	int avoidKOTH = rmCreateTypeDistanceConstraint("avoid KOTH", "ypKingsHill", 12.0);

	// Avoidance Islands
	int midIslandID=rmCreateArea("Mid Island");
	if (PlayerNum == 2)
		rmSetAreaSize(midIslandID, 0.38);
	else if (PlayerNum < 5)
		rmSetAreaSize(midIslandID, 0.42);
	else
		rmSetAreaSize(midIslandID, 0.46);
	rmSetAreaLocation(midIslandID, 0.5, 0.5);
//	rmSetAreaMix(midIslandID, "testmix"); 	// for testing
//	rmAddAreaToClass(midIslandID, classIsland);
//	rmSetAreaBaseHeight(midIslandID, 4.0);
	rmSetAreaCoherence(midIslandID, 1.00);

	// built later
	
	int avoidMidIsland = rmCreateAreaDistanceConstraint("avoid mid island ", midIslandID, 8.0);
	int avoidMidIslandMin = rmCreateAreaDistanceConstraint("avoid mid island min", midIslandID, 0.5);
	int avoidMidIslandFar = rmCreateAreaDistanceConstraint("avoid mid island far", midIslandID, 16.0);
	int stayMidIsland = rmCreateAreaMaxDistanceConstraint("stay mid island ", midIslandID, 0.0);

	int midSmIslandID=rmCreateArea("Mid Small Island");
	rmSetAreaSize(midSmIslandID, 0.15);
	rmSetAreaLocation(midSmIslandID, 0.5, 0.5);
//	rmSetAreaMix(midSmIslandID, "great plains drygrass"); 	// for testing
//	rmAddAreaToClass(midSmIslandID, classIsland);
//	rmSetAreaBaseHeight(midSmIslandID, 4.0);
	rmSetAreaCoherence(midSmIslandID, 0.75);
	rmBuildArea(midSmIslandID); 
	
	int avoidMidSmIsland = rmCreateAreaDistanceConstraint("avoid mid sm island ", midSmIslandID, 8.0);
	int avoidMidSmIslandMin = rmCreateAreaDistanceConstraint("avoid mid sm island min", midSmIslandID, 0.5);
	int avoidMidSmIslandFar = rmCreateAreaDistanceConstraint("avoid mid sm island far", midSmIslandID, 16.0);
	int stayMidSmIsland = rmCreateAreaMaxDistanceConstraint("stay mid sm island ", midSmIslandID, 0.0);
	
	// Player Area
	for (i=1; < numPlayer) {
		int playerareaID = rmCreateArea("playerarea"+i);
		rmSetPlayerArea(i, playerareaID);
		rmSetAreaSize(playerareaID, rmAreaTilesToFraction(1600+50*PlayerNum));
		rmSetAreaLocPlayer(playerareaID, i);
		rmAddAreaToClass(playerareaID, classIsland);
		rmSetAreaCoherence(playerareaID, 0.65);
		rmSetAreaObeyWorldCircleConstraint(playerareaID, false);
		rmSetAreaMix(playerareaID, paintMix);
		rmSetAreaWarnFailure(playerareaID, false);
		rmSetAreaObeyWorldCircleConstraint(playerareaID, false);
		rmSetAreaSmoothDistance(playerareaID, 10);
		rmSetAreaElevationType(playerareaID, cElevTurbulence);
		rmSetAreaElevationVariation(playerareaID, 2.5);
		rmSetAreaBaseHeight(playerareaID, 4.0);
		rmSetAreaElevationMinFrequency(playerareaID, 0.09);
		rmSetAreaElevationOctaves(playerareaID, 3);
		rmSetAreaElevationPersistence(playerareaID, 0.4);    
//		rmAddAreaConstraint(playerareaID, avoidIslandShort);
		rmAddAreaConstraint(playerareaID, avoidMidSmIslandMin);
		rmBuildArea(playerareaID);
		rmCreateAreaDistanceConstraint("avoid player island "+i, playerareaID, 8.0);
		rmCreateAreaDistanceConstraint("avoid player island far "+i, playerareaID, 16.0);
		rmCreateAreaMaxDistanceConstraint("stay in player island "+i, playerareaID, 0.0);
		}
	
	int avoidPlayerIsland1 = rmConstraintID("avoid player island 1");
	int avoidPlayerIsland1Far = rmConstraintID("avoid player island far 1");
	int avoidPlayerIsland2 = rmConstraintID("avoid player island 2");
	int avoidPlayerIsland2Far = rmConstraintID("avoid player island far 2");
	int stayInPlayerIsland1 = rmConstraintID("stay in player island 1");
	int stayInPlayerIsland2 = rmConstraintID("stay in player island 2");  

	// ____________________ Natives ____________________
	// Native Islands
	float island1x = 0.50 + rmRandFloat(-0.02,0.02);
	float island1y = 0.625 + rmRandFloat(-0.08,0.08);
	float island2x = 0.625 + rmRandFloat(-0.02,0.02);
	float island2y = 0.50 + rmRandFloat(-0.08,0.08);
	float island3x = 0.375 + rmRandFloat(-0.02,0.02);
	float island3y = 0.50 + rmRandFloat(-0.08,0.08);
	float island4x = 0.50 + rmRandFloat(-0.02,0.02); 
	float island4y = 0.375 + rmRandFloat(-0.08,0.08);

	if (TeamNum == 2)
	{
		island1x = 0.90 + rmRandFloat(-0.02,0.02);
		island1y = 0.50 + rmRandFloat(-0.08,0.08);
		island4x = 0.10 + rmRandFloat(-0.02,0.02);
		island4y = 0.50 + rmRandFloat(-0.08,0.08);
	}


	int natIslandID=rmCreateArea("Native Island 1");
	rmSetAreaSize(natIslandID, rmAreaTilesToFraction(500));
	rmSetAreaMix(natIslandID, paintMix); 
	rmAddAreaToClass(natIslandID, classIsland);
	rmSetAreaBaseHeight(natIslandID, 4.0);
	rmSetAreaCoherence(natIslandID, 0.75);
	rmSetAreaLocation(natIslandID, island1x, island1y);
	rmBuildArea(natIslandID); 			
	
	int natIsland2ID=rmCreateArea("Native Island 2");
	rmSetAreaSize(natIsland2ID, rmAreaTilesToFraction(500));
	rmSetAreaMix(natIsland2ID, paintMix); 
	rmAddAreaToClass(natIsland2ID, classIsland);
	rmSetAreaBaseHeight(natIsland2ID, 4.0);
	rmSetAreaCoherence(natIsland2ID, 0.75);
	rmSetAreaLocation(natIsland2ID, island2x, island2y);
	rmBuildArea(natIsland2ID); 	
	
	int natIsland3ID=rmCreateArea("Native Island 3");
	rmSetAreaSize(natIsland3ID, rmAreaTilesToFraction(500));
	rmSetAreaMix(natIsland3ID, paintMix); 
	rmAddAreaToClass(natIsland3ID, classIsland);
	rmSetAreaBaseHeight(natIsland3ID, 4.0);
	rmSetAreaCoherence(natIsland3ID, 0.75);
	rmSetAreaLocation(natIsland3ID, island3x, island3y);
	rmBuildArea(natIsland3ID); 	
	
	int natIsland4ID=rmCreateArea("Native Island 4");
	rmSetAreaSize(natIsland4ID, rmAreaTilesToFraction(500));
	rmSetAreaMix(natIsland4ID, paintMix); 
	rmAddAreaToClass(natIsland4ID, classIsland);
	rmSetAreaBaseHeight(natIsland4ID, 4.0);
	rmSetAreaCoherence(natIsland4ID, 0.75);
	rmSetAreaLocation(natIsland4ID, island4x, island4y);
	rmBuildArea(natIsland4ID); 	
	
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
	int whichVillage = rmRandInt(1,2);
	
	nativeID0 = rmCreateGrouping("native A", natGrpName1+whichVillage);
	nativeID1 = rmCreateGrouping("native B", natGrpName1+whichVillage);
	nativeID2 = rmCreateGrouping("native C", natGrpName2+whichVillage);	
	nativeID3 = rmCreateGrouping("native D", natGrpName2+whichVillage);	

	rmAddGroupingToClass(nativeID0, classNative);
	rmAddGroupingToClass(nativeID1, classNative);
	rmAddGroupingToClass(nativeID2, classNative);
	rmAddGroupingToClass(nativeID3, classNative);


	if (whichNative == 1) {
		rmPlaceGroupingAtLoc(nativeID0, 0, island1x, island1y);
		rmPlaceGroupingAtLoc(nativeID1, 0, island4x, island4y);
		rmPlaceGroupingAtLoc(nativeID2, 0, island3x, island3y);
		rmPlaceGroupingAtLoc(nativeID3, 0, island2x, island2y);
		}
	else {
		rmPlaceGroupingAtLoc(nativeID0, 0, island2x, island2y);
		rmPlaceGroupingAtLoc(nativeID1, 0, island3x, island3y);
		rmPlaceGroupingAtLoc(nativeID2, 0, island1x, island1y);
		rmPlaceGroupingAtLoc(nativeID3, 0, island4x, island4y);
		}




	/*if (TeamNum == 2) {
		if (whichNative == 1) {
			rmPlaceGroupingAtLoc(nativeID0, 0, 0.90, 0.50);
			rmPlaceGroupingAtLoc(nativeID1, 0, 0.10, 0.50);
			rmPlaceGroupingAtLoc(nativeID2, 0, 0.375, 0.50);
			rmPlaceGroupingAtLoc(nativeID3, 0, 0.625, 0.50);
			}
		else {
			rmPlaceGroupingAtLoc(nativeID0, 0, 0.625, 0.50);
			rmPlaceGroupingAtLoc(nativeID1, 0, 0.375, 0.50);
			rmPlaceGroupingAtLoc(nativeID2, 0, 0.90, 0.50);
			rmPlaceGroupingAtLoc(nativeID3, 0, 0.10, 0.50);
			}
		}
	else {
		if (whichNative == 1) {
			rmPlaceGroupingAtLoc(nativeID0, 0, 0.625, 0.50);
			rmPlaceGroupingAtLoc(nativeID1, 0, 0.375, 0.50);
			rmPlaceGroupingAtLoc(nativeID2, 0, 0.50, 0.625);
			rmPlaceGroupingAtLoc(nativeID3, 0, 0.50, 0.375);
			}
		else {
			rmPlaceGroupingAtLoc(nativeID0, 0, 0.50, 0.625);
			rmPlaceGroupingAtLoc(nativeID1, 0, 0.50, 0.375);
			rmPlaceGroupingAtLoc(nativeID2, 0, 0.625, 0.50);
			rmPlaceGroupingAtLoc(nativeID3, 0, 0.375, 0.50);
			}
		}*/
	
	// ____________________ Swamp Islands ____________________
	for (i=0; <10*PlayerNum) {
		int swampislandID=rmCreateArea("swamp island"+i);
		rmSetAreaSize(swampislandID, 0.01+0.001*PlayerNum);
		rmSetAreaMix(swampislandID, swampIslandPaintMix);
		rmSetAreaWarnFailure(swampislandID, false);
		rmAddAreaToClass(swampislandID, classIsland);
		rmAddAreaToClass(swampislandID, classIce);
		rmSetAreaCoherence(swampislandID, 0.50);
		rmSetAreaBaseHeight(swampislandID, 2.0);
		rmSetAreaObeyWorldCircleConstraint(swampislandID, false);
		if (TeamNum == 2)
			rmAddAreaConstraint(swampislandID, avoidIslandTiny);	// short
		else
			rmAddAreaConstraint(swampislandID, avoidIslandTiny);
		if (PlayerNum == 2) {
			rmAddAreaConstraint(swampislandID, avoidPlayerIsland1);
			rmAddAreaConstraint(swampislandID, avoidPlayerIsland2);
			}
		rmBuildArea(swampislandID);
		}

	for (i=0; < 2+PlayerNum) {
		int bonusIslandID=rmCreateArea("bonus islands"+i);
		rmSetAreaSize(bonusIslandID, rmAreaTilesToFraction(100));
//	rmSetAreaMix(bonusIslandID, "testmix"); 	// for testing
		rmSetAreaMix(bonusIslandID, swampIslandPaintMix);
		rmSetAreaWarnFailure(bonusIslandID, false);
		rmAddAreaToClass(bonusIslandID, classIsland);
		rmAddAreaToClass(bonusIslandID, classIce);
		rmSetAreaCoherence(bonusIslandID, 0.50);
		rmSetAreaBaseHeight(bonusIslandID, 2.0);
		rmSetAreaObeyWorldCircleConstraint(bonusIslandID, false);
		rmAddAreaConstraint(bonusIslandID, avoidIslandTiny);	
		rmAddAreaConstraint(bonusIslandID, avoidNativesFar);	
		rmAddAreaConstraint(bonusIslandID, avoidKingIsland);	
		if (PlayerNum == 2) {
			rmAddAreaConstraint(bonusIslandID, avoidPlayerIsland1Far);
			rmAddAreaConstraint(bonusIslandID, avoidPlayerIsland2Far);
			}
		rmBuildArea(bonusIslandID);
		}
		
	// build mid island for avoidance (places it on top of terrain for testing)
	rmBuildArea(midIslandID); 
		
/*
//  Create a bay water area -- the mediterranean part.
	int bayID=rmCreateArea("The Gulf of Mexico");
	rmSetAreaSize(bayID, 0.15, 0.15);
	rmSetAreaLocation(bayID, 0.1, 0.05);
	rmSetAreaWaterType(bayID, "new england lake");
	rmSetAreaBaseHeight(bayID, 4.0); // Was 10
	rmSetAreaMinBlobs(bayID, 8);
	rmSetAreaMaxBlobs(bayID, 10);
	rmSetAreaMinBlobDistance(bayID, 10);
	rmSetAreaMaxBlobDistance(bayID, 20);
	rmSetAreaSmoothDistance(bayID, 50);
	rmSetAreaCoherence(bayID, 0.25);
	rmAddAreaToClass(bayID, rmClassID("bay"));
	rmSetAreaObeyWorldCircleConstraint(bayID, false);
	rmBuildArea(bayID);

   // Create connections
   int shallowsID=rmCreateConnection("shallows");
   rmSetConnectionType(shallowsID, cConnectAreas, false, 1.0);
   rmSetConnectionWidth(shallowsID, 20, 2);
   rmSetConnectionWarnFailure(shallowsID, false);
   rmSetConnectionBaseHeight(shallowsID, 2.0);
   rmSetConnectionHeightBlend(shallowsID, 2.0);
   rmSetConnectionSmoothDistance(shallowsID, 3.0);
   rmAddConnectionTerrainReplacement(shallowsID, "amazon\river1_am", "new_england\ground2_ne");
   rmAddConnectionTerrainReplacement(shallowsID, "amazon\river2_am", "new_england\ground2_ne");
 //  rmAddConnectionTerrainReplacement(shallowsID, "new_england\outerbank_ne", "new_england\ground2_ne");
 //  rmAddConnectionTerrainReplacement(shallowsID, "new_england\outerbank_ne", "new_england\ground2_ne");
 //  rmAddConnectionTerrainReplacement(shallowsID, "new_england\underwater1_ne", "new_england\ground2_ne");
 //  rmAddConnectionTerrainReplacement(shallowsID, "new_england\underwater2_ne", "new_england\ground2_ne");
	rmAddConnectionConstraint(shallowsID, bayConstraint);
*/
/*	// removed by vividlyplain 
   for(i=0; <rmRandInt(9,10))
   {
      int bonusIslandID=rmCreateArea("bonus island"+i);
      rmSetAreaSize(bonusIslandID, 0.06, 0.08);
      rmSetAreaMix(bonusIslandID, "bayou_grass_skirmish");
      rmSetAreaWarnFailure(bonusIslandID, false);
    //  if(rmRandFloat(0.0, 1.0)<0.70)
        rmAddAreaConstraint(bonusIslandID, bonusIslandConstraint);
		rmAddAreaToClass(bonusIslandID, classIsland);
		rmAddAreaToClass(bonusIslandID, classBonusIsland);
		rmAddAreaConstraint(bonusIslandID, bayConstraint);
		rmSetAreaCoherence(bonusIslandID, 0.25);
		rmSetAreaSmoothDistance(bonusIslandID, 12);
		rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
		rmSetAreaElevationVariation(bonusIslandID, 2.0);
		rmSetAreaBaseHeight(bonusIslandID, 4.0);
		rmSetAreaElevationMinFrequency(bonusIslandID, 0.09);
		rmSetAreaElevationOctaves(bonusIslandID, 3);
		rmSetAreaElevationPersistence(bonusIslandID, 0.2);      
	//  rmAddConnectionArea(shallowsID, bonusIslandID);
		rmSetAreaObeyWorldCircleConstraint(bonusIslandID, false);
   }   
*/
//	rmBuildAllAreas();

  // Text
   rmSetStatusText("",0.20);

/* 	// removed by vividlyplain
   int lakeID=rmCreateArea("Shallows lake");
   rmSetAreaSize(lakeID, 0.1, 0.1);
   rmSetAreaLocation(lakeID, 0.5, 0.5);
   rmSetAreaWaterType(lakeID, "Bayou Skirmish2");
   rmSetAreaBaseHeight(lakeID, 4.0); // Was 10
   rmSetAreaMinBlobs(lakeID, 8);
   rmSetAreaMaxBlobs(lakeID, 10);
   rmSetAreaMinBlobDistance(lakeID, 10);
   rmSetAreaMaxBlobDistance(lakeID, 20);
   rmSetAreaSmoothDistance(lakeID, 50);
   rmSetAreaCoherence(lakeID, 0.25);
	rmAddAreaToClass(lakeID, rmClassID("bay"));
   rmSetAreaObeyWorldCircleConstraint(lakeID, false);
//	rmBuildArea(lakeID);

    for(i=0; <rmRandInt(6,8))
   {
      int smallIslandID=rmCreateArea("small island"+i);
      rmSetAreaSize(smallIslandID, 0.008, 0.008);
     // rmSetAreaMix(smallIslandID, "carolina_grass");
	  rmSetAreaMix(smallIslandID, "bayou_grass_skirmish");
      rmSetAreaWarnFailure(smallIslandID, false);
      rmAddAreaToClass(smallIslandID, classIsland);
      //rmAddAreaConstraint(smallIslandID, bayConstraint);
      rmSetAreaCoherence(smallIslandID, 0.25);
      rmSetAreaSmoothDistance(smallIslandID, 12);
	  //rmSetAreaElevationType(smallIslandID, cElevTurbulence);
	  //rmSetAreaElevationVariation(smallIslandID, 2.0);
	  rmSetAreaBaseHeight(smallIslandID, 4.0);
	  //rmSetAreaElevationMinFrequency(smallIslandID, 0.09);
	  //rmSetAreaElevationOctaves(smallIslandID, 3);
	  //rmSetAreaElevationPersistence(smallIslandID, 0.2);      
	  //rmAddAreaConstraint(smallIslandID, islandConstraint);
	  rmAddAreaConstraint(smallIslandID, islandEdgeConstraint);
   }   
*/
   // Build all areas
//	rmBuildAllAreas();

/*	// original natives - removed by vividlyplain
	// Add Natives

	float nativeLoc = rmRandFloat(0,1);

	if (subCiv0 == rmGetCivID("Seminoles"))
	{  
		if ( cNumberTeams <= 2 )
		{
		int smallIslandNative1=rmCreateArea("small island native 1");
		rmSetAreaSize(smallIslandNative1, rmAreaTilesToFraction(400), rmAreaTilesToFraction(500));
		rmSetAreaLocation(smallIslandNative1, 0.9, 0.5);
		rmSetAreaMix(smallIslandNative1, "bayou_grass_skirmish");
		rmSetAreaWarnFailure(smallIslandNative1, false);
		rmAddAreaToClass(smallIslandNative1, classIsland);
		rmSetAreaCoherence(smallIslandNative1, 0.6);
		rmSetAreaSmoothDistance(smallIslandNative1, 12);
		//rmSetAreaElevationType(smallIslandNative1, cElevTurbulence);
		//rmSetAreaElevationVariation(smallIslandNative1, 2.0);
		rmSetAreaBaseHeight(smallIslandNative1, 4.0);
		rmBuildArea(smallIslandNative1);

		int SeminolesVillageID = -1;
		int SeminolesVillageType = rmRandInt(1,5);
		SeminolesVillageID = rmCreateGrouping("Seminole village", "native seminole village "+SeminolesVillageType);
		rmSetGroupingMinDistance(SeminolesVillageID, 0.0);
		rmSetGroupingMaxDistance(SeminolesVillageID, 0.0);
		//rmAddGroupingConstraint(SeminolesVillageID, avoidImpassableLand);
		//rmAddGroupingConstraint(SeminolesVillageID, avoidImportantItem);
		rmAddGroupingToClass(SeminolesVillageID, rmClassID("importantItem"));
		if (nativeLoc < 0.5)
			rmPlaceGroupingAtLoc(SeminolesVillageID, 0, 0.90, 0.50);
		else
			rmPlaceGroupingAtLoc(SeminolesVillageID, 0, 0.9, 0.5);
		}
	}

	if (subCiv1 == rmGetCivID("Cherokee"))
   {   
	   int smallIslandNative2=rmCreateArea("small island native 2");
		rmSetAreaSize(smallIslandNative2, rmAreaTilesToFraction(400), rmAreaTilesToFraction(500));
		rmSetAreaLocation(smallIslandNative2, 0.6, 0.5);
		rmSetAreaMix(smallIslandNative2, "bayou_grass_skirmish");
		rmSetAreaWarnFailure(smallIslandNative2, false);
		rmAddAreaToClass(smallIslandNative2, classIsland);
		rmSetAreaCoherence(smallIslandNative2, 0.6);
		rmSetAreaSmoothDistance(smallIslandNative2, 12);
		//rmSetAreaElevationType(smallIslandNative2, cElevTurbulence);
		//rmSetAreaElevationVariation(smallIslandNative2, 2.0);
		rmSetAreaBaseHeight(smallIslandNative2, 4.0);
		rmBuildArea(smallIslandNative2);

		int CherokeeVillageID = -1;
		int CherokeeVillageType = rmRandInt(1,5);
		CherokeeVillageID = rmCreateGrouping("Cherokee village", "native Cherokee village "+CherokeeVillageType);
		rmSetGroupingMinDistance(CherokeeVillageID, 0.0);
		rmSetGroupingMaxDistance(CherokeeVillageID, 0.0);
		//rmAddGroupingConstraint(CherokeeVillageID, avoidImpassableLand);
		//rmAddGroupingConstraint(CherokeeVillageID, avoidImportantItem);
		rmAddGroupingToClass(CherokeeVillageID, rmClassID("importantItem"));
		if (nativeLoc < 0.5)
			rmPlaceGroupingAtLoc(CherokeeVillageID, 0, 0.6, 0.5);
		else
			rmPlaceGroupingAtLoc(CherokeeVillageID, 0, 0.6, 0.5);
	}

	if (subCiv2 == rmGetCivID("Cherokee"))
   {   
		int smallIslandNative3=rmCreateArea("small island native 3");
		rmSetAreaSize(smallIslandNative3, rmAreaTilesToFraction(400), rmAreaTilesToFraction(500));
		rmSetAreaLocation(smallIslandNative3, 0.4, 0.5);
		rmSetAreaMix(smallIslandNative3, "bayou_grass_skirmish");
		rmSetAreaWarnFailure(smallIslandNative3, false);
		rmAddAreaToClass(smallIslandNative3, classIsland);
		rmSetAreaCoherence(smallIslandNative3, 0.6);
		rmSetAreaSmoothDistance(smallIslandNative3, 12);
		//rmSetAreaElevationType(smallIslandNative3, cElevTurbulence);
		//rmSetAreaElevationVariation(smallIslandNative3, 2.0);
		rmSetAreaBaseHeight(smallIslandNative3, 4.0);
		rmBuildArea(smallIslandNative3);

		int Cherokee2VillageID = -1;
		int Cherokee2VillageType = rmRandInt(1,5);
		Cherokee2VillageID = rmCreateGrouping("Cherokee2 village", "native cherokee village "+Cherokee2VillageType);
		rmSetGroupingMinDistance(Cherokee2VillageID, 0.0);
		rmSetGroupingMaxDistance(Cherokee2VillageID, 0.0);
		//rmAddGroupingConstraint(Cherokee2VillageID, avoidImpassableLand);
		//rmAddGroupingConstraint(Cherokee2VillageID, avoidImportantItem);
		rmAddGroupingToClass(Cherokee2VillageID, rmClassID("importantItem"));
		if (nativeLoc < 0.5)
			rmPlaceGroupingAtLoc(Cherokee2VillageID, 0, 0.4, 0.5);
		else
			rmPlaceGroupingAtLoc(Cherokee2VillageID, 0, 0.4, 0.5);
	}
  
	if (subCiv3 == rmGetCivID("Seminoles"))
   {   
	   if ( cNumberTeams <= 2 )
	   {
		int smallIslandNative4=rmCreateArea("small island native 4");
		rmSetAreaSize(smallIslandNative4, rmAreaTilesToFraction(400), rmAreaTilesToFraction(500));
		rmSetAreaLocation(smallIslandNative4, 0.10, 0.5);
		rmSetAreaMix(smallIslandNative4, "bayou_grass_skirmish");
		rmSetAreaWarnFailure(smallIslandNative4, false);
		rmAddAreaToClass(smallIslandNative4, classIsland);
		rmSetAreaCoherence(smallIslandNative4, 0.6);
		rmSetAreaSmoothDistance(smallIslandNative4, 12);
		//rmSetAreaElevationType(smallIslandNative4, cElevTurbulence);
		//rmSetAreaElevationVariation(smallIslandNative4, 2.0);
		rmSetAreaBaseHeight(smallIslandNative4, 4.0);
		rmBuildArea(smallIslandNative4);

		int Seminoles2VillageID = -1;
		int Seminoles2VillageType = rmRandInt(1,5);
		Seminoles2VillageID = rmCreateGrouping("Seminole2 village", "native seminole village "+Seminoles2VillageType);
		rmSetGroupingMinDistance(Seminoles2VillageID, 0.0);
		rmSetGroupingMaxDistance(Seminoles2VillageID, 0.0);
		//rmAddGroupingConstraint(Seminoles2VillageID, avoidImpassableLand);
		//rmAddGroupingConstraint(Seminoles2VillageID, avoidImportantItem);
		rmAddGroupingToClass(Seminoles2VillageID, rmClassID("importantItem"));
		if (nativeLoc < 0.5)
			rmPlaceGroupingAtLoc(Seminoles2VillageID, 0, 0.10, 0.5);
		else
			rmPlaceGroupingAtLoc(Seminoles2VillageID, 0, 0.10, 0.50);
	   }
	}
*/
	// Text
	rmSetStatusText("", 0.30);

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

	// Starting mines
	int playergoldID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playergoldID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playergoldID, 16.0);
	rmSetObjectDefMaxDistance(playergoldID, 16.0);
	rmAddObjectDefToClass(playergoldID, classStartingResource);
	rmAddObjectDefToClass(playergoldID, classGold);
	rmAddObjectDefConstraint(playergoldID, avoidNativesShort);
	rmAddObjectDefConstraint(playergoldID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playergoldID, avoidGold);
	rmAddObjectDefConstraint(playergoldID, avoidMidIslandMin);
	
	// 2nd mine
	int playergold2ID = rmCreateObjectDef("player second mine");
	rmAddObjectDefItem(playergold2ID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playergold2ID, 36.0);
	rmSetObjectDefMaxDistance(playergold2ID, 40.0);
	rmAddObjectDefToClass(playergold2ID, classStartingResource);
	rmAddObjectDefToClass(playergold2ID, classGold);
	rmAddObjectDefConstraint(playergold2ID, avoidGold);
	rmAddObjectDefConstraint(playergold2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playergold2ID, avoidNativesShort);
	if (TeamNum == 2)
		rmAddObjectDefConstraint(playergold2ID, stayNearEdge);
	
	// Starting trees
	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, treeType2, 10, 5.0);
    rmSetObjectDefMinDistance(playerTreeID, 18);
    rmSetObjectDefMaxDistance(playerTreeID, 18);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, classForest);
	rmAddObjectDefConstraint(playerTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidIce);

	// Extra Starting trees
	int playerExtraTreeID = rmCreateObjectDef("extra player trees");
	/*rmAddObjectDefItem(playerExtraTreeID, treeType2, 12, 8.0);
    rmSetObjectDefMinDistance(playerExtraTreeID, 34);
    rmSetObjectDefMaxDistance(playerExtraTreeID, 40);
	rmAddObjectDefToClass(playerExtraTreeID, classStartingResource);
	rmAddObjectDefToClass(playerExtraTreeID, classForest);
	rmAddObjectDefConstraint(playerExtraTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(playerExtraTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerExtraTreeID, avoidMidIsland);
	rmAddObjectDefConstraint(playerExtraTreeID, stayNearEdge);*/
	
	// Starting berries
	int playerberriesID = rmCreateObjectDef("player berries");
	/*rmAddObjectDefItem(playerberriesID, "berrybush", 4, 3.0);
	rmSetObjectDefMinDistance(playerberriesID, 14.0);
	rmSetObjectDefMaxDistance(playerberriesID, 14.0);
	rmAddObjectDefToClass(playerberriesID, classStartingResource);
	rmAddObjectDefConstraint(playerberriesID, avoidNativesShort);
	rmAddObjectDefConstraint(playerberriesID, avoidStartingResourcesShort);*/
//	rmAddObjectDefConstraint(playerberriesID, stayMidIsland);
	
	// Starting herd
	int playerherdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerherdID, food1, 5, 4.0);
	rmSetObjectDefMinDistance(playerherdID, 14);
	rmSetObjectDefMaxDistance(playerherdID, 14);
	rmSetObjectDefCreateHerd(playerherdID, true);
	rmAddObjectDefToClass(playerherdID, classStartingResource);
	rmAddObjectDefConstraint(playerherdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerherdID, avoidNativesShort);
//	rmAddObjectDefConstraint(playerherdID, stayMidIsland);
		
	// 2nd herd
	int player2ndherdID = rmCreateObjectDef("player 2nd herd");
	rmAddObjectDefItem(player2ndherdID, food2, 8, 5.0);
    rmSetObjectDefMinDistance(player2ndherdID, 30);
    rmSetObjectDefMaxDistance(player2ndherdID, 30);
	rmAddObjectDefToClass(player2ndherdID, classStartingResource);
	rmSetObjectDefCreateHerd(player2ndherdID, true);
	rmAddObjectDefConstraint(player2ndherdID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(player2ndherdID, avoidNativesShort);
//	rmAddObjectDefConstraint(player2ndherdID, avoidHunt1Short);
//	rmAddObjectDefConstraint(player2ndherdID, avoidHunt2Short);
	rmAddObjectDefConstraint(player2ndherdID, avoidMidIslandMin);
	if (teamOneCount != teamZeroCount)
		rmAddObjectDefConstraint(player2ndherdID, stayNearEdge);

	// Starting treasures
	int playerNuggetID = rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(playerNuggetID, 30.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 30.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerNuggetID, avoidNugget);
	rmAddObjectDefConstraint(playerNuggetID, avoidNativesShort);
//	rmAddObjectDefConstraint(playerNuggetID, stayMidIsland);
	
	//  Place Starting Objects/Resources
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playergoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (PlayerNum > 2)
			rmPlaceObjectDefAtLoc(playergold2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2)
			rmPlaceObjectDefAtLoc(playergold2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerExtraTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerberriesID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerherdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(player2ndherdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (TeamNum > 2 || PlayerNum > 5)
			rmPlaceObjectDefAtLoc(player2ndherdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
	}
   
	rmSetStatusText("", 0.40);

/*
	if (subCiv4 == rmGetCivID("Seminoles"))
   {   
      int Seminoles3VillageID = -1;
      int Seminoles3VillageType = rmRandInt(1,10);
      Seminoles3VillageID = rmCreateGrouping("Seminole3 village", "native seminole village "+Seminoles3VillageType);
      rmSetGroupingMinDistance(Seminoles3VillageID, 0.0);
      rmSetGroupingMaxDistance(Seminoles3VillageID, rmXFractionToMeters(0.15));
      rmAddGroupingConstraint(Seminoles3VillageID, avoidImpassableLand);
		rmAddGroupingConstraint(Seminoles3VillageID, avoidImportantItem);
      rmAddGroupingToClass(Seminoles3VillageID, rmClassID("importantItem"));
		if (nativeLoc < 0.5)
			rmPlaceGroupingAtLoc(Seminoles3VillageID, 0, 0.4, 0.4);
		else
			rmPlaceGroupingAtLoc(Seminoles3VillageID, 0, 0.4, 0.4);
	}
*/

/*	// original starting units and stuff - removed by viidlyplain
	// Set up player starting locations. These are just used to place Caravels away from each other.

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 2.0);
	rmSetObjectDefMaxDistance(startingUnits, 4.0);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));
	rmAddObjectDefToClass(startingUnits, rmClassID("player"));

	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
			rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
		else
		{
            rmAddObjectDefItem(TCID, "townCenter", 1, 0);
		}
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 10.0);
	//rmAddObjectDefConstraint(TCID, avoidTradeRoute);
	rmAddObjectDefToClass(TCID, rmClassID("player"));
	rmAddObjectDefToClass(TCID, rmClassID("startingUnit"));

	int playerSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerSilverID, "mine", 1, 0);
	//rmAddObjectDefConstraint(playerSilverID, avoidTradeRoute);
	rmSetObjectDefMinDistance(playerSilverID, 12.0);
	rmSetObjectDefMaxDistance(playerSilverID, 20.0);
	//rmAddObjectDefConstraint(playerSilverID, avoidAll);
	rmAddObjectDefToClass(playerSilverID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerSilverID, avoidStartingUnits);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, "TreeBayouSkirmish", rmRandInt(5,8), 4.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 8);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 15);
	rmAddObjectDefToClass(StartAreaTreeID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	//rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRoute);
	//rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidSilver);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingUnits);
	//rmAddObjectDefConstraint(StartAreaTreeID, avoidResource);

	int startBerryID=rmCreateObjectDef("starting Berries");
	rmAddObjectDefItem(startBerryID, "berrybush", 4, 5.0);
	rmSetObjectDefCreateHerd(startBerryID, true);
	rmSetObjectDefMinDistance(startBerryID, 8);
	rmSetObjectDefMaxDistance(startBerryID, 15);
	rmAddObjectDefToClass(startBerryID, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startBerryID, avoidImpassableLand);
	//rmAddObjectDefConstraint(startBerryID, avoidTradeRoute);
	rmAddObjectDefConstraint(startBerryID, avoidStartingUnits);
	rmAddObjectDefConstraint(startBerryID, avoidResource);

	int startingHunt = rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(startingHunt, "turkey", 5, 5.0);
	rmSetObjectDefCreateHerd(startingHunt, true);
	rmSetObjectDefMinDistance(startingHunt, 8);
	rmSetObjectDefMaxDistance(startingHunt, 12);
	rmAddObjectDefToClass(startingHunt, rmClassID("startingUnit"));
	rmAddObjectDefConstraint(startingHunt, avoidImpassableLand);
	rmAddObjectDefConstraint(startingHunt, avoidStartingUnits);
*/
/*	// removed by vividlyplain
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
	float randomTeamGrouping = rmRandFloat(0.0, 1.0);
	
// FFA and 2 team support
	if ( cNumberTeams <= 2 && teamZeroCount <= 4 && teamOneCount <= 4)
	{

		rmSetPlacementTeam(0);
		if (randomTeamGrouping <= 0.5)
			rmSetPlacementSection(0.4, 0.6);
		else
			rmSetPlacementSection(0.45, 0.55);
		rmSetTeamSpacingModifier(0.5);
		rmPlacePlayersCircular(0.38, 0.38, 0);

		rmSetPlacementTeam(1);
		if (randomTeamGrouping <= 0.5)
			rmSetPlacementSection(0.9, 0.1);
		else
			rmSetPlacementSection(0.95, 0.05);
		rmSetTeamSpacingModifier(0.5);
		rmPlacePlayersCircular(0.38, 0.38, 0);
	}
	else if ( cNumberTeams == 2)
	{
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.4, 0.6);
		rmSetTeamSpacingModifier(0.5);
		rmPlacePlayersCircular(0.38, 0.38, 0);

		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.9, 0.1);
		rmSetTeamSpacingModifier(0.5);
		rmPlacePlayersCircular(0.38, 0.38, 0);
	}
	else
	{
		rmSetTeamSpacingModifier(0.7);
		rmPlacePlayersCircular(0.38, 0.40, 0.0);
	}
*/
/*
if ( cNumberTeams == 2 )
	{
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(0.60, 0.10, 0.65, 0.1, 0, 0.002);
	
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(0.50, 0.9, 0.55, 0.9, 0, 0.002);
	}
	else
	{
  		rmSetPlacementSection(0.0, 0.95);
		rmPlacePlayersCircular(0.35, 0.40, 0.0);
	}
*/
/*	// old player areas - removed by vividlyplain
   // Set up player areas.
   float playerFraction=rmAreaTilesToFraction(800);
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
//      rmAddAreaConstraint(id, playerConstraint); 
//      rmAddAreaConstraint(id, playerEdgeConstraint); 
		rmSetAreaLocPlayer(id, i);
		rmSetAreaBaseHeight(id, 4);
		rmSetAreaCoherence(id, 0.8);
		//rmSetAreaTerrainType(id, "andes\ground2_and");
		rmSetAreaMix(id, "bayou_grass_skirmish");
		rmSetAreaWarnFailure(id, false);
   }
	// Build the areas.
//	rmBuildAllAreas();
   
  // Text

   for(i=1; <cNumberPlayers)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		rmPlaceObjectDefAtLoc(startingUnits, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerSilverID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startBerryID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(startingHunt, 0, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
        
    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		//vector closestPoint=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingUnits, i));
		//rmSetHomeCityGatherPoint(i, closestPoint);
	}
*/
// *********************************** TREASURES *******************************
    
/*	// original koth - removed by vividlyplain
  // check for KOTH game mode
	if (rmGetIsKOTH())
	{
    
    int randLoc = rmRandInt(1,2);
    float xLoc = 0.0;
    
    if(randLoc == 1)
      xLoc = .6;
    
    else
      xLoc = .4;
    
    ypKingsHillPlacer(xLoc, .5, 0.1, longPlayerConstraint);
    rmEchoInfo("XLOC = "+xLoc);
  }
*/
/* // original nuggets - removed by vividlyplain 
		int nugget1= rmCreateObjectDef("nugget easy"); 
		rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(1, 1);
		//rmAddObjectDefToClass(nugget1, rmClassID("classNugget"));
		rmAddObjectDefConstraint(nugget1, longPlayerConstraint);
		rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
		rmAddObjectDefConstraint(nugget1, avoidNugget);
		rmAddObjectDefConstraint(nugget1, circleConstraint);
		rmAddObjectDefConstraint(nugget1, avoidAll);
		rmSetObjectDefMinDistance(nugget1, 40.0);
		rmSetObjectDefMaxDistance(nugget1, 60.0);
		rmPlaceObjectDefPerPlayer(nugget1, false, 2);

		int nugget2= rmCreateObjectDef("nugget medium"); 
		rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(2, 2);
		//rmAddObjectDefToClass(nugget2, rmClassID("classNugget"));
		rmSetObjectDefMinDistance(nugget2, 0.0);
		rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(nugget2, longPlayerConstraint);
		rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
		rmAddObjectDefConstraint(nugget2, avoidNugget);
		rmAddObjectDefConstraint(nugget2, circleConstraint);
		rmAddObjectDefConstraint(nugget2, avoidAll);
		rmSetObjectDefMinDistance(nugget2, 80.0);
		rmSetObjectDefMaxDistance(nugget2, 120.0);
		rmPlaceObjectDefPerPlayer(nugget2, false, 1);

		int nugget3= rmCreateObjectDef("nugget hard"); 
		rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(3, 3);
		//rmAddObjectDefToClass(nugget3, rmClassID("classNugget"));
		rmSetObjectDefMinDistance(nugget3, 0.0);
		rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(nugget3, longPlayerConstraint);
		rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
		rmAddObjectDefConstraint(nugget3, avoidNugget);
		rmAddObjectDefConstraint(nugget3, circleConstraint);
		rmAddObjectDefConstraint(nugget3, avoidAll);
		rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

		int nugget4= rmCreateObjectDef("nugget nuts"); 
		rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
		rmSetNuggetDifficulty(4, 4);
		//rmAddObjectDefToClass(nugget4, rmClassID("classNugget"));
		rmSetObjectDefMinDistance(nugget4, 0.0);
		rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.4));
		rmAddObjectDefConstraint(nugget4, longPlayerConstraint);
		rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
		rmAddObjectDefConstraint(nugget4, avoidNugget);
		rmAddObjectDefConstraint(nugget4, circleConstraint);
		rmAddObjectDefConstraint(nugget4, avoidAll);
		rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, rmRandInt(2,3));
*/
/*
	int nuggetID= rmCreateObjectDef("nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID, 0.0);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.5));
	//rmAddObjectDefConstraint(nuggetID, islandEdgeConstraint);
	rmAddObjectDefConstraint(nuggetID, longPlayerConstraint);
	rmAddObjectDefConstraint(nuggetID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(nuggetID, avoidNugget);
	rmAddObjectDefConstraint(nuggetID, avoidAll);
	rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*rmRandInt(3,4));
*/
	// ____________________ Map Resources ____________________
	// Mines
	int silverType = rmRandInt(1,10);
	int silverID = -1;
	int silver2ID = -1;
	int silverCount = (cNumberNonGaiaPlayers*5);

	silverID = rmCreateObjectDef("silver");
	rmAddObjectDefItem(silverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(silverID, rmXFractionToMeters(0.10));
	rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.48));
	rmAddObjectDefToClass(silverID, classGold);
	rmAddObjectDefConstraint(silverID, avoidNativesMin);
	rmAddObjectDefConstraint(silverID, avoidGoldFar);
	rmAddObjectDefConstraint(silverID, avoidStartingResources);
	rmAddObjectDefConstraint(silverID, avoidTownCenter);
	rmAddObjectDefConstraint(silverID, avoidIce);
//	if (PlayerNum == 2) {
//		rmAddObjectDefConstraint(silverID, avoidPlayerIsland1);
//		rmAddObjectDefConstraint(silverID, avoidPlayerIsland2);
//		}
	rmAddObjectDefConstraint(silverID, avoidAll);
	rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(silverID, avoidStartingUnits);
	rmAddObjectDefConstraint(silverID, shortAvoidImportantItem);
	rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5, silverCount);

	rmSetStatusText("", 0.50);

// Text
   rmSetStatusText("",0.80);

	// Trees
	int mapTreesID=rmCreateObjectDef("map trees");
	rmAddObjectDefItem(mapTreesID, treeType2, 8, 8.0);
	rmAddObjectDefToClass(mapTreesID, rmClassID("Forest")); 
	rmSetObjectDefMinDistance(mapTreesID, 20);
	rmSetObjectDefMaxDistance(mapTreesID, rmXFractionToMeters(0.50));
	rmAddObjectDefConstraint(mapTreesID, avoidNativesShort);
	rmAddObjectDefConstraint(mapTreesID, avoidForestShort);
	rmAddObjectDefConstraint(mapTreesID, avoidTownCenterFar);	
	rmAddObjectDefConstraint(mapTreesID, avoidGoldShort);	
	rmAddObjectDefConstraint(mapTreesID, avoidStartingResources);
	rmAddObjectDefConstraint(mapTreesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(mapTreesID, avoidIce);
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(mapTreesID, avoidPlayerIsland1);
		rmAddObjectDefConstraint(mapTreesID, avoidPlayerIsland2);
		}
	rmPlaceObjectDefAtLoc(mapTreesID, 0, 0.5, 0.5, 20+5*PlayerNum);

	rmSetStatusText("", 0.60);

	int randTreesID=rmCreateObjectDef("random trees");
	rmAddObjectDefItem(randTreesID, treeType2, 2, 5.0);
	rmAddObjectDefToClass(randTreesID, rmClassID("Forest")); 
	rmSetObjectDefMinDistance(randTreesID, 14);
	rmSetObjectDefMaxDistance(randTreesID, rmXFractionToMeters(0.50));
	rmAddObjectDefConstraint(randTreesID, avoidNativesShort);
	rmAddObjectDefConstraint(randTreesID, forestConstraint);
	rmAddObjectDefConstraint(randTreesID, avoidTownCenterMed);	
	rmAddObjectDefConstraint(randTreesID, avoidGoldMin);	
	rmAddObjectDefConstraint(randTreesID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(randTreesID, avoidIce);
//	rmAddObjectDefConstraint(randTreesID, shortAvoidImpassableLand);
	rmPlaceObjectDefAtLoc(randTreesID, 0, 0.5, 0.5, 10+10*PlayerNum);

	rmSetStatusText("", 0.70);
	
/* 	// original forests - removed by vividlyplain
   // Define and place Forests
   int forestTreeID = 0;
   int numTries=5*cNumberNonGaiaPlayers;
   int failCount=0;
   for (i=0; <numTries)
      {   
         int forest=rmCreateArea("forest "+i);
         rmSetAreaWarnFailure(forest, false);
         rmSetAreaSize(forest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(400));
         rmSetAreaForestType(forest, "bayou swamp forest");
         rmSetAreaForestDensity(forest, 0.8);
         rmSetAreaForestClumpiness(forest, 0.0);
         rmSetAreaForestUnderbrush(forest, 0.0);
         rmSetAreaMinBlobs(forest, 1);
         rmSetAreaMaxBlobs(forest, 4);
         rmSetAreaMinBlobDistance(forest, 16.0);
         rmSetAreaMaxBlobDistance(forest, 20.0);
         rmSetAreaCoherence(forest, 0.4);
         rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, classForest);
         rmAddAreaConstraint(forest, forestConstraint);
         rmAddAreaConstraint(forest, avoidAll);
         rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		 rmAddAreaConstraint(forest, avoidTC); 
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
*/
	int turkeyID = rmCreateObjectDef("turkey flock");
	rmAddObjectDefItem(turkeyID, food1, 5, 5.0);
	rmSetObjectDefMinDistance(turkeyID, 0.0);
	rmSetObjectDefMaxDistance(turkeyID, rmXFractionToMeters(0.48));
	rmSetObjectDefCreateHerd(turkeyID, true);
	rmAddObjectDefConstraint(turkeyID, avoidAll);
	rmAddObjectDefConstraint(turkeyID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(turkeyID, avoidForestMin);
	rmAddObjectDefConstraint(turkeyID, avoidGoldMin);
	rmAddObjectDefConstraint(turkeyID, avoidTownCenterFar); 
	rmAddObjectDefConstraint(turkeyID, avoidNativesShort);
	rmAddObjectDefConstraint(turkeyID, avoidHunt1Far);
	rmAddObjectDefConstraint(turkeyID, avoidStartingResources);
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(turkeyID, avoidPlayerIsland1);
		rmAddObjectDefConstraint(turkeyID, avoidPlayerIsland2);
		}
	rmPlaceObjectDefAtLoc(turkeyID, 0, 0.5, 0.5, cNumberNonGaiaPlayers * 3);

	int deerID = rmCreateObjectDef("deer herd");
	rmAddObjectDefItem(deerID, food2, 5, 5.0);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.48));
	rmSetObjectDefCreateHerd(deerID, true);
	rmAddObjectDefConstraint(deerID, avoidForestMin);
	rmAddObjectDefConstraint(deerID, avoidGoldMin);
	rmAddObjectDefConstraint(deerID, avoidTownCenterFar); 
	rmAddObjectDefConstraint(deerID, avoidNativesShort);
	rmAddObjectDefConstraint(deerID, avoidHunt1);
	rmAddObjectDefConstraint(deerID, avoidHunt2);
	rmAddObjectDefConstraint(deerID, avoidStartingResources);
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(deerID, avoidPlayerIsland1);
		rmAddObjectDefConstraint(deerID, avoidPlayerIsland2);
		}
	rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, cNumberNonGaiaPlayers * 3);

	rmSetStatusText("", 0.80);

	// ____________________ Treasures  ____________________
	// Treasures L4
	int Nugget4ID = rmCreateObjectDef("nugget lvl4"); 
	rmAddObjectDefItem(Nugget4ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(Nugget4ID, 0.0);
	rmSetObjectDefMaxDistance(Nugget4ID, rmXFractionToMeters(0.30));
	rmSetNuggetDifficulty(4,4);
	rmAddObjectDefConstraint(Nugget4ID, avoidNuggetFar);
	rmAddObjectDefConstraint(Nugget4ID, avoidNativesShort);
	rmAddObjectDefConstraint(Nugget4ID, avoidGoldMin);
	rmAddObjectDefConstraint(Nugget4ID, avoidTownCenterFar);
	rmAddObjectDefConstraint(Nugget4ID, avoidStartingResources);
	rmAddObjectDefConstraint(Nugget4ID, avoidForestMin);	
	rmAddObjectDefConstraint(Nugget4ID, avoidHunt2Min); 
	rmAddObjectDefConstraint(Nugget4ID, avoidHunt1Min); 
	rmAddObjectDefConstraint(Nugget4ID, stayMidSmIsland); 
	rmAddObjectDefConstraint(Nugget4ID, avoidKOTH); 
	if (PlayerNum > 4 && rmGetIsTreaty() == false)
		rmPlaceObjectDefAtLoc(Nugget4ID, 0, 0.50, 0.50, PlayerNum);

	// Treasures L3
	int Nugget3ID = rmCreateObjectDef("nugget lvl3"); 
	rmAddObjectDefItem(Nugget3ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(Nugget3ID, 0.0);
	rmSetObjectDefMaxDistance(Nugget3ID, rmXFractionToMeters(0.30));
	rmSetNuggetDifficulty(3,3);
	rmAddObjectDefConstraint(Nugget3ID, avoidNuggetFar);
	rmAddObjectDefConstraint(Nugget3ID, avoidNativesShort);
	rmAddObjectDefConstraint(Nugget3ID, avoidGoldMin);
	rmAddObjectDefConstraint(Nugget3ID, avoidTownCenterFar);
	rmAddObjectDefConstraint(Nugget3ID, avoidStartingResources);
	rmAddObjectDefConstraint(Nugget3ID, avoidForestMin);	
	rmAddObjectDefConstraint(Nugget3ID, avoidHunt2Min); 
	rmAddObjectDefConstraint(Nugget3ID, avoidHunt1Min); 
	rmAddObjectDefConstraint(Nugget3ID, stayMidSmIsland); 
	rmAddObjectDefConstraint(Nugget3ID, avoidKOTH); 
	if (PlayerNum > 2)
		rmPlaceObjectDefAtLoc(Nugget3ID, 0, 0.50, 0.50, PlayerNum);
	
	// Treasures L2	
	int Nugget2ID = rmCreateObjectDef("nugget lvl2"); 
	rmAddObjectDefItem(Nugget2ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(Nugget2ID, 0.0);
	rmSetObjectDefMaxDistance(Nugget2ID, rmXFractionToMeters(0.45));
	rmSetNuggetDifficulty(2,2);
	rmAddObjectDefConstraint(Nugget2ID, avoidNugget);
	rmAddObjectDefConstraint(Nugget2ID, avoidNatives);
	rmAddObjectDefConstraint(Nugget2ID, avoidGoldMin);
	rmAddObjectDefConstraint(Nugget2ID, avoidTownCenterFar);
	rmAddObjectDefConstraint(Nugget2ID, avoidStartingResources);
	rmAddObjectDefConstraint(Nugget2ID, avoidForestMin);	
	rmAddObjectDefConstraint(Nugget2ID, avoidHunt2Min); 
	rmAddObjectDefConstraint(Nugget2ID, avoidHunt1Min); 
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(Nugget2ID, avoidPlayerIsland1); 
		rmAddObjectDefConstraint(Nugget2ID, avoidPlayerIsland2); 
		}
	rmAddObjectDefConstraint(Nugget2ID, avoidKOTH); 
	rmPlaceObjectDefAtLoc(Nugget2ID, 0, 0.50, 0.50, 2*PlayerNum+4);

	// Treasures L1
	int Nugget1ID = rmCreateObjectDef("nugget lvl1"); 
	rmAddObjectDefItem(Nugget1ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(Nugget1ID, 50);
	rmSetObjectDefMaxDistance(Nugget1ID, rmXFractionToMeters(0.5));
	rmSetNuggetDifficulty(1,1);
	rmAddObjectDefConstraint(Nugget1ID, avoidNugget);
	rmAddObjectDefConstraint(Nugget1ID, avoidNatives);
	rmAddObjectDefConstraint(Nugget1ID, avoidGoldMin);
	rmAddObjectDefConstraint(Nugget1ID, avoidTownCenter);
	rmAddObjectDefConstraint(Nugget1ID, avoidStartingResources);
	rmAddObjectDefConstraint(Nugget1ID, avoidForestMin);	
	rmAddObjectDefConstraint(Nugget1ID, avoidHunt2Min); 
	rmAddObjectDefConstraint(Nugget1ID, avoidHunt1Min); 
	rmPlaceObjectDefAtLoc(Nugget1ID, 0, 0.50, 0.50, 3*PlayerNum);

	rmSetStatusText("",0.90);

	// Embellishments - reduced number and adjusted constraints
	int avoidEagles = rmCreateTypeDistanceConstraint("avoids Eagles", "EaglesNest", 60.0);
	int avoidEaglesShort = rmCreateTypeDistanceConstraint("avoids Eagles short", "EaglesNest", 10.0);

	int randomEagleTreeID=rmCreateObjectDef("random eagle tree");
	rmAddObjectDefItem(randomEagleTreeID, "EaglesNest", 1, 0.0);
	rmSetObjectDefMinDistance(randomEagleTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomEagleTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomEagleTreeID, avoidAll);
	rmAddObjectDefConstraint(randomEagleTreeID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidEagles);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidStartResource);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidTownCenterFar);
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(randomEagleTreeID, avoidPlayerIsland1);
		rmAddObjectDefConstraint(randomEagleTreeID, avoidPlayerIsland2);
		}
	rmAddObjectDefConstraint(randomEagleTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidGoldShort);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidHunt1Min);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidHunt2Min);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidNuggetMin);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidKOTH);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidKingIsland);
	rmAddObjectDefConstraint(randomEagleTreeID, avoidIce);
	rmPlaceObjectDefAtLoc(randomEagleTreeID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);

	int treeVsLand = rmCreateTerrainDistanceConstraint("tree v. land", "land", true, 2.0);
	int nearShore=rmCreateTerrainMaxDistanceConstraint("tree v. water", "land", true, 14.0);

	/*int randomWaterTreeID=rmCreateObjectDef("random tree in water");
	rmAddObjectDefItem(randomWaterTreeID, "treeBayouMarshSkirmish", 1, 0.0);
	rmSetObjectDefMinDistance(randomWaterTreeID, 0.0);
	rmSetObjectDefMaxDistance(randomWaterTreeID, rmXFractionToMeters(0.5));
	rmAddObjectDefToClass(randomWaterTreeID, classForest);
	rmAddObjectDefConstraint(randomWaterTreeID, treeVsLand);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidEaglesShort);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidStartResource);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidTownCenterFar);
	if (PlayerNum == 2) {
		rmAddObjectDefConstraint(randomWaterTreeID, avoidPlayerIsland1);
		rmAddObjectDefConstraint(randomWaterTreeID, avoidPlayerIsland2);
		}
	rmAddObjectDefConstraint(randomWaterTreeID, avoidNativesShort);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidGoldShort);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidHunt1Min);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidHunt2Min);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidNuggetMin);
	rmAddObjectDefConstraint(randomWaterTreeID, avoidIce);*/

	/*int randomTurtlesID=rmCreateObjectDef("random turtles in water");
	rmAddObjectDefItem(randomTurtlesID, "propTurtles", 1, 3.0);
	rmSetObjectDefMinDistance(randomTurtlesID, 0.0);
	rmSetObjectDefMaxDistance(randomTurtlesID, rmXFractionToMeters(0.5));
	//rmAddObjectDefConstraint(randomTurtlesID, nearShore);
	rmAddObjectDefConstraint(randomTurtlesID, treeVsLand);
	rmAddObjectDefConstraint(randomTurtlesID, avoidForestMin);*/

	int randomWaterRocksID=rmCreateObjectDef("random rocks in water");
	rmAddObjectDefItem(randomWaterRocksID, "underbrushLake", rmRandInt(3,6), 3.0);
	rmSetObjectDefMinDistance(randomWaterRocksID, 0.0);
	rmSetObjectDefMaxDistance(randomWaterRocksID, rmXFractionToMeters(0.5));
	//rmAddObjectDefConstraint(randomWaterRocksID, nearShore);
	rmAddObjectDefConstraint(randomWaterRocksID, treeVsLand);
	rmAddObjectDefConstraint(randomWaterRocksID, avoidForestMin);
	
	//Added by Paul - current particles - change second line to change particle type 
	/*int randomWaterFlowID=rmCreateObjectDef("random flow in water");
	rmAddObjectDefItem(randomWaterFlowID, "RiverEdgeFlow", 1, 0);
	rmSetObjectDefMinDistance(randomWaterFlowID, 0.0);
	rmSetObjectDefMaxDistance(randomWaterFlowID, rmXFractionToMeters(0.5));
	//rmAddObjectDefConstraint(randomWaterFlowID, nearShore);
	//rmAddObjectDefConstraint(randomWaterFlowID, treeVsLand);*/

	int avoidSwans = rmCreateTypeDistanceConstraint("avoids swans", "PropSwan", 80.0);
	int avoidSwansShort = rmCreateTypeDistanceConstraint("avoids swans short", "PropSwan", 20.0);
	int avoidDucks=rmCreateTypeDistanceConstraint("avoids ducks", "DuckFamily", 50.0);

	int randSwanID = rmCreateObjectDef("random swans in water");
	rmAddObjectDefItem(randSwanID, "PropSwan", 1, 0.0);
	rmSetObjectDefMinDistance(randSwanID, 0.0);
	rmSetObjectDefMaxDistance(randSwanID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randSwanID, avoidSwans);
	rmAddObjectDefConstraint(randSwanID, treeVsLand);
	rmAddObjectDefConstraint(randSwanID, avoidForestMin);

	int randomDucksID=rmCreateObjectDef("random ducks in water");
	rmAddObjectDefItem(randomDucksID, "DuckFamily", 1, 0.0);
	rmSetObjectDefMinDistance(randomDucksID, 0.0);
	rmSetObjectDefMaxDistance(randomDucksID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(randomDucksID, avoidSwans);
	rmAddObjectDefConstraint(randomDucksID, avoidDucks);
	rmAddObjectDefConstraint(randomDucksID, treeVsLand);
	rmAddObjectDefConstraint(randomDucksID, avoidForestMin);

/*	int fishID = rmCreateObjectDef("fish");
	rmAddObjectDefItem(fishID, "FishSalmon", 3, 9.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, fishVsFishID);
	rmAddObjectDefConstraint(fishID, fishLand);
	//rmPlaceObjectDefInArea(fishID, 0, bayID, 3*cNumberNonGaiaPlayers);
*/
	//rmPlaceObjectDefAtLoc(randomWaterTreeID, 0, 0.5, 0.5, 10+cNumberNonGaiaPlayers);
	//rmPlaceObjectDefAtLoc(randomTurtlesID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);
	//rmPlaceObjectDefAtLoc(randomWaterRocksID, 0, 0.5, 0.5, 20*cNumberNonGaiaPlayers);
	//rmPlaceObjectDefAtLoc(randSwanID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);
	//rmPlaceObjectDefAtLoc(randomDucksID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);
	//added by Paul - change end number for amount
	//rmPlaceObjectDefAtLoc(randomWaterFlowID, 0, 0.5, 0.5, 100*cNumberNonGaiaPlayers);
/*
	for (i=0; <20)
      {
		int dirtPatch=rmCreateArea("open dirt patch "+i);
		rmSetAreaWarnFailure(dirtPatch, false);
		rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		//rmSetAreaMix(dirtPatch, "pampas_grass");
		rmSetAreaTerrainType(dirtPatch, "bayou\groundforest_bay");
		// rmAddAreaTerrainLayer(dirtPatch, "great_plains\ground2_gp", 0, 1);
		rmAddAreaToClass(dirtPatch, rmClassID("classPatch"));
		//rmSetAreaBaseHeight(dirtPatch, 4.0);
		rmSetAreaMinBlobs(dirtPatch, 1);
		rmSetAreaMaxBlobs(dirtPatch, 5);
		rmSetAreaMinBlobDistance(dirtPatch, 16.0);
		rmSetAreaMaxBlobDistance(dirtPatch, 40.0);
		rmSetAreaCoherence(dirtPatch, 0.2);
		rmSetAreaSmoothDistance(dirtPatch, 10);
		rmAddAreaConstraint(dirtPatch, shortAvoidImpassableLand);
		rmAddAreaConstraint(dirtPatch, patchConstraint);
		rmBuildArea(dirtPatch); 
      }
*/

//	rmEchoInfo("RANDOM TEAM GROUPING = " + randomTeamGrouping);

	// PAROT decorative particle 
		//int particleDecorationID=rmCreateObjectDef("Particle Things");
		//rmAddObjectDefItem(particleDecorationID, "RiverFlow", 1, 0.0);	
		//rmSetObjectDefMinDistance(particleDecorationID, 0.0);
		//rmSetObjectDefMaxDistance(particleDecorationID, rmXFractionToMeters(0.60));
		//rmPlaceObjectDefAtLoc(particleDecorationID, 0, 0.5, 0.5, 25);
	
// Text
	// ____________________ LOCAL MERCENARIES ____________________
    rmDisableDefaultMercs(true);
    rmDisableCivTypeMercRestriction(true);

	// Add 2 random outlaws
	int randOutlawInt = rmRandInt(1, 3);  
	if (randOutlawInt == 1)
	{   rmEnableOutlaw("SaloonOutlawPistol");
    	rmEnableOutlaw("SaloonOutlawRifleman"); }
	else if (randOutlawInt == 2)
	{   rmEnableOutlaw("SaloonOutlawPistol");
		rmEnableOutlaw("SaloonOutlawRider"); }
	else
	{   rmEnableOutlaw("SaloonOutlawRifleman");
		rmEnableOutlaw("SaloonOutlawRider"); }
		

	// Add 3 christmas Mercs
	// NOTE: now that there are more than 3 christmas mers, we need to select them randomly here. 
	//       Some techs are still tied to cTechzpXmassMercenaries, but it no longer enables mercs
	int xmassMercRandInt = rmRandInt(1, 4);  
	if (xmassMercRandInt == 1)
	{   rmEnableMerc("zpChristmasGrenadier", -1);
		rmEnableMerc("zpChristmasPolearm", -1); 
		rmEnableMerc("zpChristmasOrganGun", -1); }
	else if (xmassMercRandInt == 2)
	{   rmEnableMerc("zpChristmasGrenadier", -1);
		rmEnableMerc("zpChristmasPolearm", -1); 
		rmEnableMerc("zpChristmasNutcrackerBlunderbussMerc", -1); }
	else if (xmassMercRandInt == 3)
	{   rmEnableMerc("zpChristmasGrenadier", -1);
		rmEnableMerc("zpChristmasOrganGun", -1); 
		rmEnableMerc("zpChristmasNutcrackerBlunderbussMerc", -1); }
	else
	{   rmEnableMerc("zpChristmasPolearm", -1); 
		rmEnableMerc("zpChristmasOrganGun", -1); 
		rmEnableMerc("zpChristmasNutcrackerBlunderbussMerc", -1); }

	// One random one in addition to the festive ones
    int mercRandInt = rmRandInt(1, 9);
	if (mercRandInt == 1)
	{ rmEnableMerc("MercLandsknecht", -1); }
	else if (mercRandInt == 2)
	{ rmEnableMerc("MercSwissPikeman", -1); }
	else if (mercRandInt == 3)
	{ rmEnableMerc("MercHighlander", -1); }
	else if (mercRandInt == 4)
	{ rmEnableMerc("MercJaeger", -1); }
	else if (mercRandInt == 5)
	{ rmEnableMerc("MercFusilier", -1); }
	else if (mercRandInt == 6)
	{ rmEnableMerc("deMercZouave", -1); }
	else if (mercRandInt == 7)
	{ rmEnableMerc("deMercPandour", -1); }
	else if (mercRandInt == 8)
	{ rmEnableMerc("deMercRoyalHorseman", -1); }
	else
	{ rmEnableMerc("deMercMountedRifleman", -1); }
	
    

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpXmassMercenaries"); // Christmas Mercenaries
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpXmassTradeRoute"); // XMass Trade Route Techs
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // European Embassy
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
	rmAddTriggerCondition("Timer");
  	 rmSetTriggerConditionParamInt("Param1",0.01);
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
	rmCreateTrigger("Activate Tortuga"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpXMassExpansion"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffXMass"); //operator
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

	// Text
	rmSetStatusText("", 1.00);
}