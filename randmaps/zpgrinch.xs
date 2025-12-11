// Grinch Mountain
// by AssertiveWall with help from vividlyplain, November 2024
// started from Cascade Range script designed by Garja

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

	int TeamNum = cNumberTeams;
	int PlayerNum = cNumberNonGaiaPlayers;
	int numPlayer = cNumberPlayers;
	
	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01); 
	
	// ************************************** GENERAL FEATURES *****************************************
	
	// Picks the map size
	int playerTiles=11500; //12000
	if (PlayerNum >= 4)
		playerTiles = 10500;
	int size=2.0*sqrt(PlayerNum*playerTiles); //2.1
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	
	// Make the corners.
	rmSetWorldCircleConstraint(true);
		
	// Picks a default water height
	rmSetSeaLevel(3.5);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	rmSetMapElevationParameters(cElevTurbulence, 0.05, 3, 0.4, 4.0); // type, frequency, octaves, persistence, variation 
//	rmSetMapElevationHeightBlend(1);
	
	// Picks default terrain and water
	rmSetSeaType("great lakes");
	rmTerrainInitialize("great_lakes\ground_snow2_gl", 4.0);
	rmSetMapType("yukon"); 
	rmSetMapType("snow");
	rmSetMapType("land");
	rmSetLightingSet("WinterWonderLand"); //
	rmSetGlobalSnow(0.9);

	// Choose Mercs
	chooseMercs();
	
	// Text
	rmSetStatusText("",0.10);
	
	// Set up Natives
	int subCiv0 = -1;
	int subCiv1 = -1;
	subCiv0 = rmGetCivID("zpXmassVillage");
	subCiv1 = rmGetCivID("zpGrinchVillage");
	rmSetSubCiv(0, "zpXmassVillage");
	rmSetSubCiv(1, "zpGrinchVillage");

	//Define some classes. These are used later for constraints.
	int classPlayer = rmDefineClass("Players");
	int classHill = rmDefineClass("Hills");
	int classPatch = rmDefineClass("patch");
	int classPatch2 = rmDefineClass("patch2");
	int classPatch3 = rmDefineClass("patch3");
	int classPatch4 = rmDefineClass("patch4");
	int classGrass = rmDefineClass("grass");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	int classForest = rmDefineClass("Forest");
	int importantItem = rmDefineClass("importantItem");
	int classNative = rmDefineClass("natives");
	int classCliff = rmDefineClass("Cliffs");
	int classGold = rmDefineClass("Gold");
	int classStartingResource = rmDefineClass("startingResource");
	
	// ******************************************************************************************
	
	// Text
	rmSetStatusText("",0.20);
	
	// ************************************* CONTRAINTS *****************************************
	// These are used to have objects and areas avoid each other
   
	// Cardinal Directions & Map placement
	int avoidEdge = rmCreatePieConstraint("Avoid Edge",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.47), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidEdgeMore = rmCreatePieConstraint("Avoid Edge More",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.45), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayEdge = rmCreatePieConstraint("Stay Edge",0.5,0.5,rmXFractionToMeters(0.42), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("Avoid Center",0.5,0.5,rmXFractionToMeters(0.28), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("Stay Center",0.5,0.5,rmXFractionToMeters(0.0), rmXFractionToMeters(0.25), rmDegreesToRadians(0),rmDegreesToRadians(360));
    int stayVillageSide = rmCreatePieConstraint("Stay Village Side", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(090), rmDegreesToRadians(270));
    int stayGrinchSide = rmCreatePieConstraint("Stay Grinch Side", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(270), rmDegreesToRadians(090));
	
	// Resource avoidance
	int avoidForestFar=rmCreateClassDistanceConstraint("avoid forest far", rmClassID("Forest"), 40.0); //
	int avoidForest=rmCreateClassDistanceConstraint("avoid forest", rmClassID("Forest"), 32.0); //29.0 
	int avoidForestShort=rmCreateClassDistanceConstraint("avoid forest short", rmClassID("Forest"), 24.0); //
	int avoidForestMin=rmCreateClassDistanceConstraint("avoid forest min", rmClassID("Forest"), 4.0);
	int avoidMooseFar = rmCreateTypeDistanceConstraint("avoid moose far", "Moose", 58.0+PlayerNum);
	int avoidMoose = rmCreateTypeDistanceConstraint("avoid moose", "Moose", 45.0);
	int avoidMooseShort = rmCreateTypeDistanceConstraint("avoid moose short", "Moose", 16.0);
	int avoidMooseMin = rmCreateTypeDistanceConstraint("avoid moose min", "Moose", 5.0);
	int avoidReindeerFar = rmCreateTypeDistanceConstraint("avoid Reindeer far", "Reindeer", 58.0+PlayerNum);
	int avoidReindeer = rmCreateTypeDistanceConstraint("avoid Reindeer", "Reindeer", 45.0);
	int avoidReindeerShort = rmCreateTypeDistanceConstraint("avoid Reindeer short", "Reindeer", 16.0);
	int avoidReindeerMin = rmCreateTypeDistanceConstraint("avoid Reindeer min", "Reindeer", 5.0);
	int avoidBerriesFar = rmCreateTypeDistanceConstraint("avoid berries far", "berrybush", 56.0);
	int avoidBerries = rmCreateTypeDistanceConstraint("avoid  berries", "berrybush", 40.0);
	int avoidBerriesShort = rmCreateTypeDistanceConstraint("avoid  berries short", "berrybush", 30.0);
	int avoidBerriesMin = rmCreateTypeDistanceConstraint("avoid berries min", "berrybush", 10.0);
	int avoidGoldTypeMin = rmCreateTypeDistanceConstraint("coin avoids coin min ", "gold", 10.0);
	int avoidGoldTypeShort = rmCreateTypeDistanceConstraint("coin avoids coin short", "gold", 18.0);
	int avoidGoldType = rmCreateTypeDistanceConstraint("coin avoids coin ", "gold", 26.0);
	int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("coin avoids coin far ", "gold", 50.0);
	int avoidGoldMin=rmCreateClassDistanceConstraint("min distance vs gold", rmClassID("Gold"), 10.0);
	int avoidGold = rmCreateClassDistanceConstraint ("gold avoid gold med", rmClassID("Gold"), 30.0);
	int avoidGoldFar = rmCreateClassDistanceConstraint ("gold avoid gold far", rmClassID("Gold"), 60.0);
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", rmClassID("Gold"), 72.0);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 30.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 44.0);
	int avoidFish=rmCreateTypeDistanceConstraint("avoid fish", "fish", 8.0);
	
	int avoidTownCenterVeryFar=rmCreateTypeDistanceConstraint("avoid Town Center Very Far", "townCenter", 82.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 68.0-PlayerNum);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 26.0);
	int avoidTownCenterMed=rmCreateTypeDistanceConstraint(" avoid Town Center med", "townCenter", 24.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint(" avoid Town Center short", "townCenter", 20.0);
	int avoidTownCenterResources=rmCreateTypeDistanceConstraint(" avoid Town Center", "townCenter", 40.0);
	int avoidNatives = rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 8.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 14.0);
	int avoidStartingResources  = rmCreateClassDistanceConstraint("avoid starting resource", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesShort  = rmCreateClassDistanceConstraint("avoid starting resource short", rmClassID("startingResource"), 4.0);

	// Land and terrain constraints
	int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int avoidImpassableLandFar=rmCreateTerrainDistanceConstraint("far avoid impassable land", "Land", false, 10.0);
	int avoidImpassableLandShort = rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 3.0);
	int avoidImpassableLandMin = rmCreateTerrainDistanceConstraint("min avoid impassable land", "Land", false, 1.0);
	int avoidImpassableLandZero=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 0.2);
	int avoidWater = rmCreateTerrainDistanceConstraint("avoid water ", "water", true, 20);
	int stayNearWater = rmCreateTerrainMaxDistanceConstraint("stay near water ", "land", false, 12.0);
	int stayInWater = rmCreateTerrainMaxDistanceConstraint("stay in water ", "water", true, 0.0);
	int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short", "water", true, 3.0);
	int avoidWaterMed = rmCreateTerrainDistanceConstraint("avoid water med", "water", true, 8.0);
	int avoidPatch = rmCreateClassDistanceConstraint("patch avoid patch", rmClassID("patch"), 24.0);
	int avoidPatch2 = rmCreateClassDistanceConstraint("patch avoid patch 2", rmClassID("patch2"), 12.0);
	int avoidPatch3 = rmCreateClassDistanceConstraint("patch avoid patch 3", rmClassID("patch3"), 24.0);
	int avoidPatch4 = rmCreateClassDistanceConstraint("patch avoid patch 4", rmClassID("patch4"), 24.0);
	int avoidGrass = rmCreateClassDistanceConstraint("grass avoid grass", rmClassID("grass"), 10.0);
	int avoidCliffMin = rmCreateClassDistanceConstraint("avoid cliff min", rmClassID("Cliffs"), 1.0);
	int avoidCliff = rmCreateClassDistanceConstraint("avoid cliff", rmClassID("Cliffs"), 4.0);
	int avoidCliffMed = rmCreateClassDistanceConstraint("avoid cliff medium", rmClassID("Cliffs"), 8.0);
	int avoidCliffFar = rmCreateClassDistanceConstraint("avoid cliff far", rmClassID("Cliffs"), 16.0);
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land ", "Land", true, 8.0);

	// Unit avoidance
	int avoidStartingUnits = rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 35.0);
	int avoidColonyShip=rmCreateTypeDistanceConstraint("avoid colony ship", "HomeCityWaterSpawnFlag", 15.0);
	int avoidColonyShipShort = rmCreateTypeDistanceConstraint("avoid colony ship short", "HomeCityWaterSpawnFlag", 10.0);		
	
	// VP avoidance
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8.0);
	int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 4.0);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 8.0);
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	
	// ***********************************************************************************************
	
	// **************************************** PLACE PLAYERS ****************************************

	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
	int grinchTeam = 0;		// grinches always team 0 "attackers"

		if (cNumberTeams <= 2) // 1v1 and TEAM
		{
			if (teamZeroCount == 1 && teamOneCount == 1) // 1v1
			{
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.50, 0.80, 0.51, 0.81);	

			    rmSetPlacementTeam(1);
			    rmPlacePlayersLine(0.50, 0.20, 0.51, 0.21);
			}
			else if (teamZeroCount == teamOneCount) // equal N of players per TEAM
			{
				if (teamZeroCount == 2) // 2v2
				{
					rmSetPlacementTeam(0);
					rmSetPlacementSection(0.94, 0.06); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);

					rmSetPlacementTeam(1);
					rmSetPlacementSection(0.44, 0.56); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);
				}
				else // 3v3, 4v4
				{
					rmSetPlacementTeam(0);
					rmSetPlacementSection(0.90, 0.10); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);

					rmSetPlacementTeam(1);
					rmSetPlacementSection(0.40, 0.60); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);
				}
			}
			else // unequal N of players per TEAM
			{
				if (teamZeroCount == 1 || teamOneCount == 1) // one team is one player
				{
					if (teamZeroCount < teamOneCount) // 1v2, 1v3, 1v4, etc.
					{
						rmSetPlacementTeam(0);
						rmPlacePlayersLine(0.50, 0.82, 0.51, 0.80, 0.00, 0.00);

						rmSetPlacementTeam(1);
						if (teamOneCount == 2)
							rmSetPlacementSection(0.44, 0.56); //
						else
							rmSetPlacementSection(0.40, 0.60); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);
					}
					else // 2v1, 3v1, 4v1, etc.
					{
						rmSetPlacementTeam(0);
						if (teamZeroCount == 2)
							rmSetPlacementSection(0.94, 0.06); //
						else
							rmSetPlacementSection(0.90, 0.10); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);

						rmSetPlacementTeam(1);
						rmPlacePlayersLine(0.50, 0.18, 0.51, 0.20, 0.00, 0.00);
					}
				}
				else if (teamZeroCount == 2 || teamOneCount == 2) // one team has 2 players
				{
					if (teamZeroCount < teamOneCount) // 2v3, 2v4, etc.
					{
						rmSetPlacementTeam(0);
						rmSetPlacementSection(0.93, 0.07); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);

						rmSetPlacementTeam(1);
						rmSetPlacementSection(0.40, 0.60); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);
					}
					else // 3v2, 4v2, etc.
					{
						rmSetPlacementTeam(0);
						rmSetPlacementSection(0.90, 0.10); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);

						rmSetPlacementTeam(1);
						rmSetPlacementSection(0.43, 0.57); //
						rmSetTeamSpacingModifier(0.25);
						rmPlacePlayersCircular(0.34, 0.34, 0);
					}
				}
				else // 3v4, 4v3, etc.
				{
					rmSetPlacementTeam(0);
					rmSetPlacementSection(0.90, 0.10); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);

					rmSetPlacementTeam(1);
					rmSetPlacementSection(0.40, 0.60); //
					rmSetTeamSpacingModifier(0.25);
					rmPlacePlayersCircular(0.34, 0.34, 0);
				}
			}
		}
		else // FFA
		{
			// invalid option
		}
	
		
	// **************************************************************************************************
   
	// Text
	rmSetStatusText("",0.30);
	
	// ******************************************** MAP LAYOUT AND LANDSCAPE DESIGN **************************************************
	string groundPaint = "";
	string playerPaint = "";

		if (rmRandFloat(0,1) <= 0.15)
		{
			groundPaint = "rockies_grass";
			playerPaint = "rockies_grass_snowa";
		}
		else if (rmRandFloat(0,1) <= 0.20)
		{
			groundPaint = "rockies_grass_snow";
			playerPaint = "rockies_grass_snowa";
		}
		else if (rmRandFloat(0,1) <= 0.25)
		{
			groundPaint = "rockies_grass_snowa";
			playerPaint = "rockies_grass";
		}
		else if (rmRandFloat(0,1) <= 0.33)
		{
			groundPaint = "rockies_grass_snowc";
			playerPaint = "rockies_grass_snowa";
		}
		else
		{
			groundPaint = "rockies_grass_snowb";
			playerPaint = "rockies_grass_snowa";
		}

	int groundID = rmCreateArea("ground");
    rmSetAreaWarnFailure(groundID, false);
	rmSetAreaObeyWorldCircleConstraint(groundID, false);
    rmSetAreaSize(groundID, 1.0, 1.0);
	rmSetAreaMix(groundID, groundPaint);
    rmSetAreaCoherence(groundID, 0.0);
    rmBuildArea(groundID); 

	// Trade Routes
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
	rmAddTradeRouteWaypoint(tradeRouteID, 0.92, 0.80);
	rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.70, 0.50, 2, 4); 
	rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.92, 0.20, 2, 4); 
    
    rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.08, 0.80);
	rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.30, 0.50, 2, 4); 
	rmAddRandomTradeRouteWaypoints(tradeRouteID2, 0.08, 0.20, 2, 4); 
	
    rmBuildTradeRoute(tradeRouteID, "xmassnow");
    rmBuildTradeRoute(tradeRouteID2, "xmassnow");
	
	float sktLoc1 = 0.10;
	float sktLoc2 = 0.50;
	float sktLoc3 = 0.90;
	
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	if (PlayerNum > 4)
	{
		socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);		
	}
	socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, sktLoc3);
    rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
	
    vector socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc1);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
	if (PlayerNum > 4)
	{
		socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc2);
		rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
	}
	socketLoc2 = rmGetTradeRouteWayPoint(tradeRouteID2, sktLoc3);
    rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

	// ******************************************************************************************************

	// ******************************************** CHRISTMAS VILLAGE *************************************************

	int randomizerInt = rmRandInt(1, 2);
	int christmasVillageID = -1;
	int villageRand = 1; //rmRandInt(1,2);  //Removed variant. Only 1 grouping per player size now

	// Large Xmass grouping
	// Based on player count
	if (PlayerNum < 4)
	{
		christmasVillageID = rmCreateGrouping("xmas village", "xmass_village_lrg_" + villageRand); //+1
	}
	else if (PlayerNum < 6)
	{
		christmasVillageID = rmCreateGrouping("xmas village", "xmass_village_lrg_dbl_" + villageRand); //+1
	}
	else if (PlayerNum < 8)
	{
		christmasVillageID = rmCreateGrouping("xmas village", "xmass_village_lrg_trip_" + villageRand); //+1
	}
	else
	{
		christmasVillageID = rmCreateGrouping("xmas village", "xmass_village_lrg_quad_" + villageRand); //+1
	}
	
    rmSetGroupingMinDistance(christmasVillageID, 0.00);
    rmSetGroupingMaxDistance(christmasVillageID, 10.00);
//	rmAddGroupingConstraint(christmasVillageID, avoidImpassableLand);
	rmAddGroupingToClass(christmasVillageID, rmClassID("natives"));
//  rmAddGroupingToClass(christmasVillageID, rmClassID("importantItem"));
//	rmAddGroupingConstraint(christmasVillageID, avoidNatives);
	
	if (PlayerNum == 2)
	{
		if (randomizerInt == 1)
		{ rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.62, 0.32); }
		else
		{ rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.4, 0.34); }
		
	}
	else if (PlayerNum == 3)
	{
		if (randomizerInt == 1)
		{ rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.53, 0.32); }
		else
		{ rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.47, 0.34); }
	}
	else if (PlayerNum < 6)
	{
		rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.5, 0.3);
	}
	else if (PlayerNum < 8)
	{
		rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.5, 0.28);
	}
	else
	{
		rmPlaceGroupingAtLoc(christmasVillageID, 0, 0.5, 0.28);
	}

	// ******************************************************************************************************

	// ******************************************** CLIFFS *************************************************

	// Grinch Mountain
		// cliff portion
		int grinchMountainBaseID = rmCreateArea("grinch mountain");
		rmSetAreaLocation(grinchMountainBaseID, 0.5, 1.0);
		rmSetAreaWarnFailure(grinchMountainBaseID, false);
		rmSetAreaSize(grinchMountainBaseID, 0.30);
		rmSetAreaCoherence(grinchMountainBaseID, 0.85);
		rmSetAreaObeyWorldCircleConstraint(grinchMountainBaseID, false);
		rmSetAreaTerrainType(grinchMountainBaseID, "rockies\groundsnow1_roc");  
		rmSetAreaCliffType(grinchMountainBaseID, "rocky mountain edge");  
		rmSetAreaCliffEdge(grinchMountainBaseID, 1, 1.0, 0.0, 0.0, 0);
		rmSetAreaCliffEdge(grinchMountainBaseID, 5, 0.1, 0.0, 0.34, 1);
		rmSetAreaCliffHeight(grinchMountainBaseID, 10, 0.0, 0.2);
		rmSetAreaCliffPainting(grinchMountainBaseID, false, false, true);
	//	rmAddAreaToClass(grinchMountainBaseID, rmClassID("classCliff"));
		rmAddAreaConstraint(grinchMountainBaseID, avoidTradeRoute);
		rmAddAreaConstraint(grinchMountainBaseID, avoidTradeRouteSocket);
		rmAddAreaConstraint(grinchMountainBaseID, avoidNatives);
		rmBuildArea(grinchMountainBaseID);	

		int avoidGrinchMountain = rmCreateAreaDistanceConstraint("avoid grinch mountain", grinchMountainBaseID, 8.0);
		int StayInGrinchMountain = rmCreateAreaMaxDistanceConstraint("stay in grinch mountain", grinchMountainBaseID, 0.0);
		int StayNearGrinchMountain = rmCreateAreaMaxDistanceConstraint("stay near grinch mountain", grinchMountainBaseID, 2.0);

		// paint it snowy
		int grinchMountainSnowID = rmCreateArea("grinch snow paint");
		rmSetAreaSize(grinchMountainSnowID, 0.35);
		rmSetAreaWarnFailure(grinchMountainSnowID, false);
		rmSetAreaObeyWorldCircleConstraint(grinchMountainSnowID, false);
		rmSetAreaMix(grinchMountainSnowID, "rockies_snow");
		rmSetAreaCoherence(grinchMountainSnowID, 1.0);
		rmSetAreaLocation(grinchMountainSnowID, 0.5, 1.0);
		rmAddAreaConstraint(grinchMountainSnowID, StayNearGrinchMountain);
		rmBuildArea(grinchMountainSnowID);
	
	// Patches 
	for (i=0; < 3*PlayerNum)
    {
        int patch1ID = rmCreateArea("plateau patch"+i);
        rmSetAreaWarnFailure(patch1ID, false);
		rmSetAreaObeyWorldCircleConstraint(patch1ID, false);
        rmSetAreaSize(patch1ID, rmAreaTilesToFraction(99), rmAreaTilesToFraction(123));
		rmSetAreaMix(patch1ID, "italy_snow_dirt");
        rmAddAreaToClass(patch1ID, rmClassID("patch"));
        rmSetAreaMinBlobs(patch1ID, 1);
        rmSetAreaMaxBlobs(patch1ID, 5);
        rmSetAreaMinBlobDistance(patch1ID, 16.0);
        rmSetAreaMaxBlobDistance(patch1ID, 40.0);
        rmSetAreaCoherence(patch1ID, 0.0);
		rmAddAreaConstraint(patch1ID, avoidImpassableLandMin);
		rmAddAreaConstraint(patch1ID, avoidPatch);
		rmAddAreaConstraint(patch1ID, StayInGrinchMountain);
        rmBuildArea(patch1ID); 
    }
	
	for (i=0; < 8*PlayerNum)
    {
        int patch2ID = rmCreateArea("grass patch"+i);
        rmSetAreaWarnFailure(patch2ID, false);
		rmSetAreaObeyWorldCircleConstraint(patch2ID, false);
        rmSetAreaSize(patch2ID, rmAreaTilesToFraction(99), rmAreaTilesToFraction(123));
		rmSetAreaMix(patch2ID, "italy_snow");
	    rmAddAreaToClass(patch2ID, rmClassID("patch2"));
        rmSetAreaMinBlobs(patch2ID, 1);
        rmSetAreaMaxBlobs(patch2ID, 5);
        rmSetAreaMinBlobDistance(patch2ID, 16.0);
        rmSetAreaMaxBlobDistance(patch2ID, 40.0);
        rmSetAreaCoherence(patch2ID, 0.0);
		rmAddAreaConstraint(patch2ID, avoidImpassableLandMin);
		rmAddAreaConstraint(patch2ID, avoidPatch2);
		rmAddAreaConstraint(patch2ID, avoidGrinchMountain);
        rmBuildArea(patch2ID); 
    }

	// ******************************************************************************************************

	// ******************************************** PLAYER AREA *************************************************

	// Players area
	for (i=1; < numPlayer)
	{
		int playerareaID = rmCreateArea("playerarea"+i);
		rmSetPlayerArea(i, playerareaID);
		rmSetAreaSize(playerareaID, rmAreaTilesToFraction(321));
		rmSetAreaCoherence(playerareaID, 0.123);
		rmSetAreaWarnFailure(playerareaID, false);
        if (rmGetPlayerTeam(i) == grinchTeam)
			rmSetAreaMix(playerareaID, "italy_snow_dirt");
		else
			rmSetAreaMix(playerareaID, playerPaint);
		rmSetAreaLocPlayer(playerareaID, i);
		rmBuildArea(playerareaID);
	}

	// ******************************************************************************************************
	
	// Text
	rmSetStatusText("",0.40);

	// ------------------------------------------------------ KOTH ---------------------------------------------------------------------

//		invalid option
	
	// ******************************************** GRINCH *************************************************
	int grinchHomeID = -1;
	int grinchRand = rmRandInt(1,2);
		
	// Now Grinch grouping
	grinchHomeID = rmCreateGrouping("grinch mountain home", "grinchMtnGroup_0"+grinchRand); //+5
    rmSetGroupingMinDistance(grinchHomeID, 0.00);
    rmSetGroupingMaxDistance(grinchHomeID, 10.00);
	//rmAddGroupingConstraint(grinchHomeID, avoidImpassableLand);
	rmAddGroupingToClass(grinchHomeID, rmClassID("natives"));
//  rmAddGroupingToClass(grinchHomeID, rmClassID("importantItem"));
//	rmAddGroupingConstraint(grinchHomeID, avoidNatives);

	if (PlayerNum == 2)
	{
		if (randomizerInt == 1)
		{ rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.4, 0.68); }
		else
		{ rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.6, 0.68); }
		
	}
	else if (PlayerNum == 3)
	{
		if (randomizerInt == 1)
		{ rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.45, 0.68); }
		else
		{ rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.55, 0.68); }
	}
	else if (PlayerNum < 6)
	{
		rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.5, 0.7);
	}
	else if (PlayerNum < 8)
	{
		rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.5, 0.7);
	}
	else
	{
		rmPlaceGroupingAtLoc(grinchHomeID, 0, 0.5, 0.7);
	}

	// ******************************************************************************************************

	// Text
	rmSetStatusText("",0.50);
	
	// ************************************ PLAYER STARTING RESOURCES ***************************************

	// ******** Define ********

	// Avoidance Islands
	int midIslandID=rmCreateArea("Mid Island");
	if (PlayerNum == 2)
		rmSetAreaSize(midIslandID, 0.25);
	else 
		rmSetAreaSize(midIslandID, 0.37);
	rmSetAreaLocation(midIslandID, 0.5, 0.5);
//	rmSetAreaMix(midIslandID, "testmix"); 	// for testing
	rmSetAreaCoherence(midIslandID, 1.00);
	rmBuildArea(midIslandID); 
	
	int avoidMidIsland = rmCreateAreaDistanceConstraint("avoid mid island ", midIslandID, 8.0);
	int avoidMidIslandMin = rmCreateAreaDistanceConstraint("avoid mid island min", midIslandID, 0.5);
	int avoidMidIslandFar = rmCreateAreaDistanceConstraint("avoid mid island far", midIslandID, 16.0);
	int stayMidIsland = rmCreateAreaMaxDistanceConstraint("stay mid island ", midIslandID, 0.0);

	int midSmIslandID=rmCreateArea("Mid Small Island");
	rmSetAreaSize(midSmIslandID, 0.11);
	rmSetAreaLocation(midSmIslandID, 0.5, 0.5);
//	rmSetAreaMix(midSmIslandID, "great plains drygrass"); 	// for testing
	rmSetAreaCoherence(midSmIslandID, 0.75);
	rmBuildArea(midSmIslandID); 
	
	int avoidMidSmIsland = rmCreateAreaDistanceConstraint("avoid mid sm island ", midSmIslandID, 8.0);
	int avoidMidSmIslandMin = rmCreateAreaDistanceConstraint("avoid mid sm island min", midSmIslandID, 0.5);
	int avoidMidSmIslandFar = rmCreateAreaDistanceConstraint("avoid mid sm island far", midSmIslandID, 16.0);
	int stayMidSmIsland = rmCreateAreaMaxDistanceConstraint("stay mid sm island ", midSmIslandID, 0.0);

		int stayNearEdge = rmCreatePieConstraint("stay near edge",0.5,0.5,rmXFractionToMeters(0.40), rmXFractionToMeters(0.49), rmDegreesToRadians(0),rmDegreesToRadians(360));
	
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
	rmAddObjectDefItem(playerGoldID, "MineCopper", 1, 0);
	rmSetObjectDefMinDistance(playerGoldID, 12.0);
	rmSetObjectDefMaxDistance(playerGoldID, 14.0);
	rmAddObjectDefToClass(playerGoldID, classStartingResource);
	rmAddObjectDefToClass(playerGoldID, classGold);
	rmAddObjectDefConstraint(playerGoldID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerGoldID, avoidNatives);
	rmAddObjectDefConstraint(playerGoldID, avoidStartingResources);
	rmAddObjectDefConstraint(playerGoldID, stayMidIsland);
	
	// 2nd mine
	int playerGold2ID = rmCreateObjectDef("player second mine");
	rmAddObjectDefItem(playerGold2ID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(playerGold2ID, 40.0); //58
	rmSetObjectDefMaxDistance(playerGold2ID, 44.0); //62
	rmAddObjectDefToClass(playerGold2ID, classStartingResource);
	rmAddObjectDefToClass(playerGold2ID, classGold);
	rmAddObjectDefConstraint(playerGold2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerGold2ID, avoidNatives);
	rmAddObjectDefConstraint(playerGold2ID, avoidGoldTypeShort);
	rmAddObjectDefConstraint(playerGold2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerGold2ID, avoidCenter);
	rmAddObjectDefConstraint(playerGold2ID, avoidMidIslandFar);
	
	// Starting berries
	int playerBerriesID = rmCreateObjectDef("player berries");
	rmAddObjectDefItem(playerBerriesID, "berrybush", 4, 4.0);
	rmSetObjectDefMinDistance(playerBerriesID, 12.0);
	rmSetObjectDefMaxDistance(playerBerriesID, 14.0);
	rmAddObjectDefToClass(playerBerriesID, classStartingResource);
	rmAddObjectDefConstraint(playerBerriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerBerriesID, avoidNatives);
	rmAddObjectDefConstraint(playerBerriesID, avoidStartingResources);
	
	// Starting trees
	int playerTreeChristmasID = rmCreateObjectDef("player trees xmas");
	rmAddObjectDefItem(playerTreeChristmasID, "TreeChristmas", 5, 5.0);
    rmSetObjectDefMinDistance(playerTreeChristmasID, 12);
    rmSetObjectDefMaxDistance(playerTreeChristmasID, 16);
	rmAddObjectDefToClass(playerTreeChristmasID, classStartingResource);
	rmAddObjectDefToClass(playerTreeChristmasID, classForest);
	rmAddObjectDefConstraint(playerTreeChristmasID, avoidForestShort);
    rmAddObjectDefConstraint(playerTreeChristmasID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTreeChristmasID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerTreeChristmasID, avoidGrinchMountain);

	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "TreeGreatLakesSnow", 5, 5.0);
    rmSetObjectDefMinDistance(playerTreeID, 12);
    rmSetObjectDefMaxDistance(playerTreeID, 16);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, classForest);
	rmAddObjectDefConstraint(playerTreeID, avoidForestShort);
    rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(playerTreeID, StayInGrinchMountain);
	
	// Starting trees far
	int playerTreeChristmas2ID = rmCreateObjectDef("player trees xmas far");
	rmAddObjectDefItem(playerTreeChristmas2ID, "TreeChristmas", 1, 4.0);
	rmAddObjectDefItem(playerTreeChristmas2ID, "TreeYukon", 6, 8.0);
	rmAddObjectDefItem(playerTreeChristmas2ID, "TreeYukonSnow", 6, 8.0);
    rmSetObjectDefMinDistance(playerTreeChristmas2ID, 36);
    rmSetObjectDefMaxDistance(playerTreeChristmas2ID, 40);
	rmAddObjectDefToClass(playerTreeChristmas2ID, classStartingResource);
	rmAddObjectDefToClass(playerTreeChristmas2ID, classForest);
	rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidForest);
    rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidMidIslandMin);
	rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidNatives);
	rmAddObjectDefConstraint(playerTreeChristmas2ID, avoidGrinchMountain);

	int playerTree2ID = rmCreateObjectDef("player trees far");
	rmAddObjectDefItem(playerTree2ID, "TreeGreatLakesSnow", 7, 8.0);
	rmAddObjectDefItem(playerTree2ID, "TreeYukonSnow", 6, 8.0);
    rmSetObjectDefMinDistance(playerTree2ID, 36);
    rmSetObjectDefMaxDistance(playerTree2ID, 40);
	rmAddObjectDefToClass(playerTree2ID, classStartingResource);
	rmAddObjectDefToClass(playerTree2ID, classForest);
	rmAddObjectDefConstraint(playerTree2ID, avoidForest);
    rmAddObjectDefConstraint(playerTree2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTree2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTree2ID, avoidMidIslandMin);
	rmAddObjectDefConstraint(playerTree2ID, avoidNatives);
	rmAddObjectDefConstraint(playerTree2ID, StayInGrinchMountain);
			
	// Starting herd
	int playerHerdID = rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(playerHerdID, "Reindeer", 10, 7.0);
	rmSetObjectDefMinDistance(playerHerdID, 16.0);
	rmSetObjectDefMaxDistance(playerHerdID, 16.0);
	rmSetObjectDefCreateHerd(playerHerdID, true);
	rmAddObjectDefToClass(playerHerdID, classStartingResource);
	rmAddObjectDefConstraint(playerHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerHerdID, avoidNatives);
	rmAddObjectDefConstraint(playerHerdID, avoidStartingResourcesShort);
		
	// 2nd herd
	int playerHerd2ID = rmCreateObjectDef("2nd herd");
	rmAddObjectDefItem(playerHerd2ID, "Reindeer", 8, 5.0);
    rmSetObjectDefMinDistance(playerHerd2ID, 34);
    rmSetObjectDefMaxDistance(playerHerd2ID, 38);
	rmAddObjectDefToClass(playerHerd2ID, classStartingResource);
	rmSetObjectDefCreateHerd(playerHerd2ID, true);
	rmAddObjectDefConstraint(playerHerd2ID, avoidReindeerShort);
	rmAddObjectDefConstraint(playerHerd2ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerHerd2ID, avoidNatives);
	rmAddObjectDefConstraint(playerHerd2ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerHerd2ID, avoidCliffMed);
	rmAddObjectDefConstraint(playerHerd2ID, avoidMidIslandMin);
	
	// 3nd herd
	int playerHerd3ID = rmCreateObjectDef("3nd herd");
    rmAddObjectDefItem(playerHerd3ID, "Reindeer", 6, 5.0);
    rmSetObjectDefMinDistance(playerHerd3ID, 45);
    rmSetObjectDefMaxDistance(playerHerd3ID, 48);
	rmAddObjectDefToClass(playerHerd3ID, classStartingResource);
	rmSetObjectDefCreateHerd(playerHerd3ID, true);
	rmAddObjectDefConstraint(playerHerd3ID, avoidReindeer);
	rmAddObjectDefConstraint(playerHerd3ID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerHerd3ID, avoidNatives);
	rmAddObjectDefConstraint(playerHerd3ID, avoidStartingResources);
	rmAddObjectDefConstraint(playerHerd3ID, avoidMidIslandFar);
	
	// Starting treasures
	int playerNuggetID = rmCreateObjectDef("player nugget"); 
	rmAddObjectDefItem(playerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmSetObjectDefMinDistance(playerNuggetID, 24.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 26.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddAreaConstraint(playerNuggetID, avoidGoldTypeMin);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLandShort);
	rmAddObjectDefConstraint(playerNuggetID, avoidNatives);
	rmAddObjectDefConstraint(playerNuggetID, avoidStartingResources);
		
	// ******** Place ********
	
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
	}
	for(i=1; <numPlayer)
	{
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGoldID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerGold2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerBerriesID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeChristmasID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeChristmasID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerdID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerd2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerHerd3ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerNuggetID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTree2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeChristmas2ID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				
		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));
	}

	// ************************************************************************************************
	
	// Text
	rmSetStatusText("",0.60);
	
	// ************************************** COMMON RESOURCES ****************************************
 
	// ********** Mines ***********
	
		int goldcount = 3*PlayerNum;  //

	//Mines
	for (i=0; < goldcount)
	{
		int goldID = rmCreateObjectDef("gold"+i);
		rmAddObjectDefItem(goldID, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(goldID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(goldID, classGold);
		rmAddObjectDefConstraint(goldID, avoidImpassableLand);
		rmAddObjectDefConstraint(goldID, avoidNatives);
		rmAddObjectDefConstraint(goldID, avoidStartingResources);
		rmAddObjectDefConstraint(goldID, avoidEdge);
		rmAddObjectDefConstraint(goldID, avoidGoldFar);
		rmAddObjectDefConstraint(goldID, avoidTownCenterFar);
		if (i < goldcount/2)
			rmAddObjectDefConstraint(goldID, stayGrinchSide);
		else
			rmAddObjectDefConstraint(goldID, stayVillageSide);
		rmPlaceObjectDefAtLoc(goldID, 0, 0.50, 0.50, 1);
	}
		
	// ****************************
	
	// Text
	rmSetStatusText("",0.70);

	// ********** Forest **********
	// Valley forest
	int valleyforestcount = 3*PlayerNum;
	int stayInValleyForest = -1;
	
	for (i=0; < valleyforestcount)
	{
		int valleyforestID = rmCreateArea("valley forest"+i);
		rmSetAreaWarnFailure(valleyforestID, false);
		rmSetAreaSize(valleyforestID, rmAreaTilesToFraction(120), rmAreaTilesToFraction(130));
		rmSetAreaObeyWorldCircleConstraint(valleyforestID, false);
		rmSetAreaCoherence(valleyforestID, 0.0);
		rmSetAreaSmoothDistance(valleyforestID, 5);
		rmAddAreaToClass(valleyforestID, classForest);
		rmAddAreaConstraint(valleyforestID, avoidForest);
		rmAddAreaConstraint(valleyforestID, avoidStartingResources);
		rmAddAreaConstraint(valleyforestID, avoidGoldTypeMin);
		rmAddAreaConstraint(valleyforestID, avoidStartingResourcesShort);
		rmAddAreaConstraint(valleyforestID, avoidNativesFar);
		rmAddAreaConstraint(valleyforestID, avoidImpassableLandMin);
		rmAddAreaConstraint(valleyforestID, avoidTownCenter);
		if (i < valleyforestcount/2)
		{
			rmSetAreaMix(valleyforestID, "italy_snow_forest");
			rmAddAreaConstraint(valleyforestID, stayGrinchSide);
		}
		else
		{
			rmSetAreaMix(valleyforestID, "rockies_snow_forest");
			rmAddAreaConstraint(valleyforestID, stayVillageSide);
		}
			
		rmBuildArea(valleyforestID);
		
		stayInValleyForest = rmCreateAreaMaxDistanceConstraint("stay in valley forest"+i, valleyforestID, 0);
		
		int valleyforesttreeID = rmCreateObjectDef("valley forest trees"+i);
		rmAddObjectDefItem(valleyforesttreeID, "TreeYukon", rmRandInt(1,4), 5.0);
		rmAddObjectDefItem(valleyforesttreeID, "TreeYukonSnow", rmRandInt(1,4), 5.0);
		rmSetObjectDefMinDistance(valleyforesttreeID,  rmXFractionToMeters(0.0));
		rmSetObjectDefMaxDistance(valleyforesttreeID,  rmXFractionToMeters(0.5));
		rmAddObjectDefToClass(valleyforesttreeID, classForest);
		rmAddObjectDefConstraint(valleyforesttreeID, avoidImpassableLandMin);
		rmAddObjectDefConstraint(valleyforesttreeID, stayInValleyForest);	
		rmPlaceObjectDefAtLoc(valleyforesttreeID, 0, 0.50, 0.50, rmRandInt(2,3));
		
	}

	// ********************************
	
	// Text
	rmSetStatusText("",0.80);
	
	// ************ Herds *************

	int herdcount = 3*PlayerNum;
	
	for (i=0; < herdcount)
	{
		int herdID = rmCreateObjectDef("map herd"+i);
		if (rmRandFloat(0,1) <= 0.50)
			rmAddObjectDefItem(herdID, "Reindeer", 10, 5.0);
		else
			rmAddObjectDefItem(herdID, "Moose", 8, 5.0);
		rmSetObjectDefMinDistance(herdID, rmXFractionToMeters(0.0));
		rmSetObjectDefMaxDistance(herdID, rmXFractionToMeters(0.45));
		rmSetObjectDefCreateHerd(herdID, true);
		rmAddObjectDefConstraint(herdID, avoidStartingResources);
		rmAddObjectDefConstraint(herdID, avoidImpassableLand);
		rmAddObjectDefConstraint(herdID, avoidNatives);
		rmAddObjectDefConstraint(herdID, avoidGoldTypeShort);
		rmAddObjectDefConstraint(herdID, avoidForestMin);
		rmAddObjectDefConstraint(herdID, avoidTownCenterFar);
		rmAddObjectDefConstraint(herdID, avoidMooseFar);
		rmAddObjectDefConstraint(herdID, avoidReindeerFar);
		rmAddObjectDefConstraint(herdID, avoidEdge);
		rmPlaceObjectDefAtLoc(herdID, 0, 0.50, 0.50, 1);
	}

	// ********************************

	// ********** Random tree clumps **********
	int rdmtreecount = 4+2*PlayerNum;
	
	for (i=0; < rdmtreecount)
	{
		int randomtreeID = rmCreateObjectDef("random tree");
		rmAddObjectDefItem(randomtreeID, "TreeYukon", rmRandInt(1,3), 5.0);
		rmAddObjectDefItem(randomtreeID, "TreeYukonSnow", rmRandInt(1,3), 5.0);
		rmSetObjectDefMinDistance(randomtreeID,  rmXFractionToMeters(0.0));
		rmSetObjectDefMaxDistance(randomtreeID,  rmXFractionToMeters(0.48));
		rmAddObjectDefToClass(randomtreeID, classForest);
		rmAddObjectDefConstraint(randomtreeID, avoidStartingResources);
		rmAddObjectDefConstraint(randomtreeID, avoidForestShort);
		rmAddObjectDefConstraint(randomtreeID, avoidNatives);
		rmAddObjectDefConstraint(randomtreeID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(randomtreeID, avoidMooseMin);
		rmAddObjectDefConstraint(randomtreeID, avoidReindeerMin);
		rmAddObjectDefConstraint(randomtreeID, avoidImpassableLandShort);
		rmAddObjectDefConstraint(randomtreeID, avoidStartingResourcesShort);
		rmAddObjectDefConstraint(randomtreeID, avoidTownCenterFar);
		if (i < rdmtreecount/4)
			rmAddObjectDefConstraint(randomtreeID, stayGrinchSide);
		else if (i < rdmtreecount/2)
			rmAddObjectDefConstraint(randomtreeID, stayVillageSide);
		rmPlaceObjectDefAtLoc(randomtreeID, 0, 0.50, 0.50, 1);
	}

	// ********************************
	
	// Text
	rmSetStatusText("",0.90);

	// ********** Treasures ***********

	int treasure4count = PlayerNum;
	int treasure3count = 2*PlayerNum;
	int treasure2count = 4*PlayerNum;

	// Tier 4 	
	for (i=0; < treasure4count)
	{
		int nugget4ID = rmCreateObjectDef("Nugget 4"+i); 
		rmAddObjectDefItem(nugget4ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget4ID, 0);
    	rmSetObjectDefMaxDistance(nugget4ID, rmXFractionToMeters(0.25));
		rmSetNuggetDifficulty(4,4);
		rmAddObjectDefConstraint(nugget4ID, avoidStartingResources);
		rmAddObjectDefConstraint(nugget4ID, avoidNugget);
		rmAddObjectDefConstraint(nugget4ID, avoidNatives);
		rmAddObjectDefConstraint(nugget4ID, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget4ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nugget4ID, avoidMooseMin);
		rmAddObjectDefConstraint(nugget4ID, avoidReindeerMin);
		rmAddObjectDefConstraint(nugget4ID, avoidBerriesMin);	
		rmAddObjectDefConstraint(nugget4ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget4ID, avoidTownCenterFar);
		if (i<treasure4count/2)
			rmAddObjectDefConstraint(nugget4ID, stayGrinchSide);
		else
			rmAddObjectDefConstraint(nugget4ID, stayVillageSide);
		rmPlaceObjectDefAtLoc(nugget4ID, 0, 0.50, 0.50, 1);
	}

	// Tier 3
	for (i=0; < treasure3count)
	{
		int nugget3ID = rmCreateObjectDef("Nugget 3"+i); 
		rmAddObjectDefItem(nugget3ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget3ID, 0);
    	rmSetObjectDefMaxDistance(nugget3ID, rmXFractionToMeters(0.35));
		rmSetNuggetDifficulty(3,3);
		rmAddObjectDefConstraint(nugget3ID, avoidStartingResources);
		rmAddObjectDefConstraint(nugget3ID, avoidNugget);
		rmAddObjectDefConstraint(nugget3ID, avoidNatives);
		rmAddObjectDefConstraint(nugget3ID, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget3ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nugget3ID, avoidMooseMin);
		rmAddObjectDefConstraint(nugget3ID, avoidReindeerMin);
		rmAddObjectDefConstraint(nugget3ID, avoidBerriesMin);	
		rmAddObjectDefConstraint(nugget3ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget3ID, avoidTownCenterFar);
		if (i<treasure3count/2)
			rmAddObjectDefConstraint(nugget3ID, stayGrinchSide);
		else
			rmAddObjectDefConstraint(nugget3ID, stayVillageSide);
		rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.50, 0.50, 1);
	}

	// Tier 2
	for (i=0; < treasure2count)
	{
		int nugget2ID = rmCreateObjectDef("Nugget 2"+i); 
		rmAddObjectDefItem(nugget2ID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nugget2ID, 0);
    	rmSetObjectDefMaxDistance(nugget2ID, rmXFractionToMeters(0.45));
		rmSetNuggetDifficulty(2,2);
		rmAddObjectDefConstraint(nugget2ID, avoidStartingResources);
		rmAddObjectDefConstraint(nugget2ID, avoidNugget);
		rmAddObjectDefConstraint(nugget2ID, avoidNatives);
		rmAddObjectDefConstraint(nugget2ID, avoidImpassableLand);
		rmAddObjectDefConstraint(nugget2ID, avoidGoldTypeMin);
		rmAddObjectDefConstraint(nugget2ID, avoidMooseMin);
		rmAddObjectDefConstraint(nugget2ID, avoidReindeerMin);
		rmAddObjectDefConstraint(nugget2ID, avoidBerriesMin);	
		rmAddObjectDefConstraint(nugget2ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget2ID, avoidTownCenterFar);
		rmAddObjectDefConstraint(nugget2ID, avoidEdge);
		if (i<treasure2count/2)
			rmAddObjectDefConstraint(nugget2ID, stayGrinchSide);
		else
			rmAddObjectDefConstraint(nugget2ID, stayVillageSide);
		rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.50, 0.50, 1);
	}
		
	// ********************************

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
	
    

	// ********** Triggers ***********

	// Starting Tech
	
		rmCreateTrigger("Starting Techs");
		rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpXmassMercenaries"); // Christmas Mercenaries
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // European Embassy
		rmSetTriggerEffectParamInt("Status",2);

		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpXmassTradeRoute"); // XMass Trade Route Techs
		rmSetTriggerEffectParamInt("Status",2);
		
	}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	
	// ********************************

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
	
} //END
	
	
