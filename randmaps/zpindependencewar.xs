// INDEPENDENCE WAR
// Chesapeake Bay
//
// Clone of 000_Elbe.xs, rotated 180 degrees (X -> 1-X, Z -> 1-Z).
//   - Terrain, water and lighting are New England.
//   - Hanseatic cities, Elector houses, Hussite camps, the water trade route
//     and the pirate island are stripped.
//   - Pirates sit on the shore at the mouth of the gulf, on the strip that used
//     to carry the Hanseatic settlements (Australia-style villages, see 19.5/19.6).
//   - A land trade route runs as a coastal horseshoe around the head of the bay
//     and crosses the channel on the Elbe bridge grouping, placed Mississippi-style
//     off a zpSPCWaterSpawnPoint stopper at the route midpoint.
//   - Terrain, water and lighting are New England.

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

string fish1 = "FishCod";

void main(void)
{
	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01);

	// Chooses which natives appear on the map
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;

	if (rmAllocateSubCivs(3) == true)
	{
		subCiv0=rmGetCivID("NatPirates");
		rmEchoInfo("subCiv0 is NatPirates "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "NatPirates");

		subCiv1=rmGetCivID("zpColonialEstate");
		rmEchoInfo("subCiv1 is zpColonialEstate "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zpColonialEstate");

		subCiv2=rmGetCivID("Iroquois");
		rmEchoInfo("subCiv2 is Iroquois "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "Iroquois");
	}

	// Map size follows the BIGGER TEAM, not the lobby total - a 4v1 needs
	// the same shore as a 4v4. Size classes: S=480 (1v1), M=600 (2s),
	// L=720 (3s), XL=792 (4+). The flags gate every size-dependent knob
	// below (water bodies, harbour shift, village ladder, fort slots).
	int eastTeamSize = 0;
	int westTeamSize = 0;
	for (i = 1; <cNumberPlayers) {
		if (rmGetPlayerTeam(i) == 0)
			eastTeamSize = eastTeamSize + 1;
		else
			westTeamSize = westTeamSize + 1;
	}
	int biggerTeamSize = eastTeamSize;
	if (westTeamSize > biggerTeamSize)
		biggerTeamSize = westTeamSize;
	int mapS = 0;
	int mapM = 0;
	int mapL = 0;
	int mapXL = 0;
	int size = 480;
	if (biggerTeamSize <= 1)
		mapS = 1;
	if (biggerTeamSize == 2) {
		mapM = 1;
		size = 600;
	}
	if (biggerTeamSize == 3) {
		mapL = 1;
		size = 720;
	}
	if (biggerTeamSize >= 4) {
		mapXL = 1;
		size = 792;
	}
	rmSetMapSize(size, size);

	rmSetMapElevationHeightBlend(1);

	// Picks a default water height
	rmSetSeaLevel(1.0);

	// LIGHT SET

	rmSetLightingSet("NewEngland_Skirmish");

	// Picks default terrain and water
	rmSetSeaType("ZP New England Calm");
	rmEnableLocalWater(false);
	rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetMapType("default");
	rmSetMapType("newEngland");
	rmSetMapType("piratehistoricalmap");
	rmSetMapType("caribbeanwater");

	chooseMercs();

	// Corner constraint.
	rmSetWorldCircleConstraint(true);

	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classHill");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("center");
	rmDefineClass("classPlateau");
	int classGreatLake=rmDefineClass("great lake");
	int classDeepWater=rmDefineClass("deep lake");
	int classStartingResource = rmDefineClass("startingResource");
	int classMountains=rmDefineClass("mountains");
	int classPortSite=rmDefineClass("portSite");

	// -------------Define constraints
	// These are used to have objects and areas avoid each other

	// Map edge constraints
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int longPlayerEdgeConstraint=rmCreatePieConstraint("long avoid edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.42), rmDegreesToRadians(0), rmDegreesToRadians(360));

	int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water very short", "Land", false, 5.0);
	int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);

	// Cardinal Directions
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

	// After the 180 degree flip all of the land sits in the high-Z half of the map.
	// Boxes are used instead of the pie constraints so that nothing tries to spawn
	// in the gulf.
	int landHalf = rmCreateBoxConstraint("land half", 0.0, 0.45, 1.0, 1.0);
	// Continent split only - the old z >= 0.45 clamp predates the southern
	// bay redesign and starved the south halves of forests/deer/berries.
	int westLand = rmCreateBoxConstraint("west land", 0.0, 0.0, 0.5, 1.0);
	int eastLand = rmCreateBoxConstraint("east land", 0.5, 0.0, 1.0, 1.0);

	// Player constraints
	int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 40.0);
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 45.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 20.0);
	int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 2.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 4.0);
	int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Nature avoidance
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 30.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 20.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int hillConstraint=rmCreateClassDistanceConstraint("hill vs. hill", rmClassID("classHill"), 10.0);
	int shortHillConstraint=rmCreateClassDistanceConstraint("patches vs. hill", rmClassID("classHill"), 5.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
	int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
	int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "water", false, 20.0);

	// Unit avoidance
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 45.0);
	int shortAvoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units short", rmClassID("startingUnit"), 10.0);
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 8.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
	int avoidSecrets=rmCreateClassDistanceConstraint("stuff avoids secrets", rmClassID("secrets"), 20.0);
	int avoidNuggets=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 60.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "deer", 20.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	// NOTE: these are deliberately NOT applied to the player islands / patches any more.
	// The land trade route is built before the continents, so any land area that
	// avoided it would leave the road sitting on open water.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 7.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeRouteFar3 = rmCreateTradeRouteDistanceConstraint("trade route far 3", 12.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 10.0);
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 35.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 0.1);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 20.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
	int avoidSocketMedium=rmCreateTypeDistanceConstraint("avoid socket medium", "Socket", 30.0);
	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 40.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 22.0);

	// Native Constraints
	int avoidPirates=rmCreateTypeDistanceConstraint("stay away from Pirates", "zpSocketPirates", 45.0);
	int avoidEstate=rmCreateTypeDistanceConstraint("stay away from Colonial Estates", "zpNativeHouseWesternVillageB", 30.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 30.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// Special
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall", "AbstractWall", 5.0);
	int avoidBridge=rmCreateTypeDistanceConstraint("avoid bridge", "zpBridgeFace", 15.0);
	int avoidBridgeLong=rmCreateTypeDistanceConstraint("avoid bridge long", "zpBridgeFace", 70.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ********************* Trade Route *******************************

	// Trade route must always be placed first - before the continents.

	int stopperID=rmCreateObjectDef("bridge stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);

	// Four capturable naval harbours dock onto the route (Elbe's lone-harbour system,
	// two more than Elbe had). Each one gets a guardian nugget - see the triggers.

	int loneSocketID1=rmCreateObjectDef("sockets to dock Trade Posts1");
	rmAddObjectDefItem(loneSocketID1, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(loneSocketID1, 0.0);
	rmSetObjectDefMaxDistance(loneSocketID1, 0.5);

	int loneSocketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
	rmAddObjectDefItem(loneSocketID2, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(loneSocketID2, 0.0);
	rmSetObjectDefMaxDistance(loneSocketID2, 0.5);

	int loneSocketID3=rmCreateObjectDef("sockets to dock Trade Posts3");
	rmAddObjectDefItem(loneSocketID3, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(loneSocketID3, 0.0);
	rmSetObjectDefMaxDistance(loneSocketID3, 0.5);

	int loneSocketID4=rmCreateObjectDef("sockets to dock Trade Posts4");
	rmAddObjectDefItem(loneSocketID4, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(loneSocketID4, 0.0);
	rmSetObjectDefMaxDistance(loneSocketID4, 0.5);

	int loneNuggetID1=rmCreateObjectDef("nuggets to dock Trade Posts1");
	rmAddObjectDefItem(loneNuggetID1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(loneNuggetID1, 4.0);
	rmSetObjectDefMaxDistance(loneNuggetID1, 6.0);

	int loneNuggetID2=rmCreateObjectDef("nuggets to dock Trade Posts2");
	rmAddObjectDefItem(loneNuggetID2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(loneNuggetID2, 4.0);
	rmSetObjectDefMaxDistance(loneNuggetID2, 6.0);

	int loneNuggetID3=rmCreateObjectDef("nuggets to dock Trade Posts3");
	rmAddObjectDefItem(loneNuggetID3, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(loneNuggetID3, 4.0);
	rmSetObjectDefMaxDistance(loneNuggetID3, 6.0);

	int loneNuggetID4=rmCreateObjectDef("nuggets to dock Trade Posts4");
	rmAddObjectDefItem(loneNuggetID4, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(loneNuggetID4, 4.0);
	rmSetObjectDefMaxDistance(loneNuggetID4, 6.0);

	// River trade route - Elbe's route, flipped 180 degrees. It comes down the
	// channel, runs a circuit around the gulf and goes back up the channel.

	int tradeRouteID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneSocketID1, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneSocketID2, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneSocketID3, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneSocketID4, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneNuggetID1, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneNuggetID2, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneNuggetID3, tradeRouteID);
	rmSetObjectDefTradeRouteID(loneNuggetID4, tradeRouteID);

	// Route starts just south of the bridge and runs the channel; the two
	// island legs pass the harbour pockets (Elbe idiom: cliffs 27 tiles off
	// the route line, sockets 11 tiles off - never on the route itself).
	// UNLIKE Elbe there is no per-player-count trimming: Elbe shortened its
	// route to limit resources, but here the route is always the FULL loop
	// there and back - identical waypoints at every player count / map size.
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.84);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.56);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.36);
	// westLegX stays a variable because the west harbour socket anchors it.
	float westLegX = 0.4;
	rmAddTradeRouteWaypoint(tradeRouteID, westLegX, 0.4);
	rmAddTradeRouteWaypoint(tradeRouteID, westLegX, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.56);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.84);

	rmBuildTradeRoute(tradeRouteID, "native_water_trail");

	// Place the stopper, because without it the islands won't spawn
	vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

	// !!!!!!!!!!!!!!!!!!!!!!!!!!!!! BRIDGE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	// Straight Elbe arrangement: the bridge is a plain land crossing over the
	// channel at (0.5, 0.88) and carries no trade route. Its two cliff docks are
	// built further down, after the player landmasses.

	float bridgeX = 0.5;
	float bridgeZ = 0.88;

	int bridgeCrossing = rmCreateGrouping("bridge", "Bridge_universal_long");
	rmSetGroupingMinDistance(bridgeCrossing, 0.00);
	rmSetGroupingMaxDistance(bridgeCrossing, 0.00);
	rmAddGroupingToClass(bridgeCrossing, rmClassID("classPlateau"));

	rmPlaceGroupingAtLoc(bridgeCrossing, 0, bridgeX, bridgeZ);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	// Additional Constraints - based on dansil original constraints
	int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);

	int classPatch = rmDefineClass("patch");
	int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
	int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 1.0);
	int classCenter = rmDefineClass("center");
	int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
	int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// ***************** Player islands and terrain *****************

	// Invisible marker areas. They carve nothing themselves - they keep the
	// player landmasses off the channel and off the gulf.

	int riverArea1 = rmCreateArea("riverArea1");
	rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(2700), rmAreaTilesToFraction(2700));
	if (mapM == 1)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(3500), rmAreaTilesToFraction(3500));
	if (mapL == 1)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(4500), rmAreaTilesToFraction(4500));
	if (mapXL == 1)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(6000), rmAreaTilesToFraction(6000));
	rmSetAreaLocation(riverArea1 , 0.5, 0.4);
	rmSetAreaCoherence(riverArea1 , 0.6);
	rmSetAreaElevationVariation(riverArea1, 0.0);
	rmAddAreaToClass(riverArea1, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea1, 0.5, 1.0, 0.5, 0.5);
	rmSetAreaObeyWorldCircleConstraint(riverArea1, false);
	rmSetAreaReveal(riverArea1, 1);
	rmBuildArea(riverArea1);

	int centralLake = rmCreateArea("centralLake");
	rmSetAreaSize(centralLake , rmAreaTilesToFraction(7900), rmAreaTilesToFraction(7900));
	if (mapM == 1)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(11600), rmAreaTilesToFraction(11600));
	if (mapL == 1)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(16500), rmAreaTilesToFraction(16500));
	if (mapXL == 1)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(21000), rmAreaTilesToFraction(21000));
	rmSetAreaLocation(centralLake , 0.5, 0.3);
	rmAddAreaInfluenceSegment(centralLake, 0.8, 0.1, 0.5, 0.3);
	rmAddAreaInfluenceSegment(centralLake, 0.5, 0.3, 0.2, 0.1);
	rmAddAreaInfluenceSegment(centralLake, 0.2, 0.1, 0.8, 0.1);
	rmSetAreaCoherence(centralLake , 0.8);
	rmSetAreaElevationVariation(centralLake, 0.0);
	rmAddAreaToClass(centralLake, classDeepWater);
	rmSetAreaReveal(centralLake, 1);
	rmBuildArea(centralLake);

	// Player landmasses

	int playerIslandNorthID = rmCreateArea("playerIslandNorth");
	rmSetAreaSize(playerIslandNorthID, 0.33, 0.33);
	rmSetAreaCoherence(playerIslandNorthID, 1.0);
	rmSetAreaMix(playerIslandNorthID, "newengland_grass");
		rmAddAreaTerrainLayer(playerIslandNorthID, "new_england\shoreline3_ne", 0, 1);
		rmAddAreaTerrainLayer(playerIslandNorthID, "new_england\shoreline2_ne", 1, 2);
	rmSetAreaBaseHeight(playerIslandNorthID, 3);
	rmSetAreaHeightBlend(playerIslandNorthID, 2);
	rmSetAreaSmoothDistance(playerIslandNorthID, 6);
	rmSetAreaObeyWorldCircleConstraint(playerIslandNorthID, false);
	rmAddAreaConstraint(playerIslandNorthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandNorthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandNorthID, avoidTradeRouteFar3);
	rmAddAreaConstraint(playerIslandNorthID, avoidBridge);
	rmSetAreaLocation(playerIslandNorthID, 0.8, 0.8);
	rmBuildArea(playerIslandNorthID);

	int playerIslandSouthID = rmCreateArea("playerIslandSouth");
	rmSetAreaSize(playerIslandSouthID, 0.33, 0.33);
	rmSetAreaCoherence(playerIslandSouthID, 1.0);
	rmSetAreaMix(playerIslandSouthID, "newengland_grass");
		rmAddAreaTerrainLayer(playerIslandSouthID, "new_england\shoreline3_ne", 0, 1);
		rmAddAreaTerrainLayer(playerIslandSouthID, "new_england\shoreline2_ne", 1, 2);
	rmSetAreaBaseHeight(playerIslandSouthID, 3);
	rmSetAreaHeightBlend(playerIslandSouthID, 2);
	rmSetAreaSmoothDistance(playerIslandSouthID, 6);
	rmSetAreaObeyWorldCircleConstraint(playerIslandSouthID, false);
	rmAddAreaConstraint(playerIslandSouthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandSouthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandSouthID, avoidTradeRouteFar3);
	rmAddAreaConstraint(playerIslandSouthID, avoidBridge);
	rmSetAreaLocation(playerIslandSouthID, 0.2, 0.8);
	rmBuildArea(playerIslandSouthID);

	// Cliffs to dock the bridge - offsets taken from the stopper, not hardcoded.

	int bridgeDockEast = rmCreateArea("bridgeDockEast");
	rmSetAreaSize(bridgeDockEast, rmAreaTilesToFraction(300), rmAreaTilesToFraction(300));
	rmSetAreaLocation(bridgeDockEast, bridgeX+rmXTilesToFraction(22), bridgeZ);
	rmSetAreaCoherence(bridgeDockEast, 1.0);
	rmSetAreaBaseHeight(bridgeDockEast, 3.0);
	rmSetAreaCliffType(bridgeDockEast, "ZP Elbe Cliff");
	rmSetAreaCliffEdge(bridgeDockEast, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bridgeDockEast, 0, 0.0, 1.0);
	rmAddAreaToClass(bridgeDockEast , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(bridgeDockEast, false);
	rmBuildArea(bridgeDockEast);

	int bridgeDockWest = rmCreateArea("bridgeDockWest");
	rmSetAreaSize(bridgeDockWest, rmAreaTilesToFraction(300), rmAreaTilesToFraction(300));
	rmSetAreaLocation(bridgeDockWest, bridgeX-rmXTilesToFraction(22), bridgeZ);
	rmSetAreaCoherence(bridgeDockWest, 1.0);
	rmSetAreaBaseHeight(bridgeDockWest, 3.0);
	rmSetAreaCliffType(bridgeDockWest, "ZP Elbe Cliff");
	rmSetAreaCliffEdge(bridgeDockWest, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(bridgeDockWest, 0, 0.0, 1.0);
	rmAddAreaToClass(bridgeDockWest , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(bridgeDockWest, false);
	rmBuildArea(bridgeDockWest);

	// Harbour flats to dock the trade harbours.
	// Elbe's shoreLineNorth/South layout, spread right around the gulf circuit
	// so the four harbours are properly far apart, but built as CLASSIC areas
	// (pirate-site idiom: mix + height blend, no cliff directives) - the old
	// cliffs sprawled unpredictably and once ate a fort spawn. Same 1300-tile
	// size and 27-tile route offsets; classPlateau kept so forests stay off
	// the harbour aprons.

	// 2-player (480 m) games: the random route lane has no room inside the
	// tight loop - east harbours/islands spawned nearly ON it, west ones
	// too far. Move the four islands and harbour sockets 2 tiles east;
	// the lane itself keeps its own spawn grid.
	float harbourShiftX = 0.0;
	if (mapS == 1)
		harbourShiftX = rmXTilesToFraction(2);

	int shoreLine1 = rmCreateArea("shoreLine1");
	rmSetAreaSize(shoreLine1, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
	rmSetAreaLocation(shoreLine1, 0.5+rmXTilesToFraction(27)+harbourShiftX, 0.74);
	rmSetAreaCoherence(shoreLine1, 1.0);
	rmSetAreaBaseHeight(shoreLine1, 3.5);
	rmSetAreaMix(shoreLine1, "newengland_grass");
	rmSetAreaHeightBlend(shoreLine1, 2);
	rmSetAreaSmoothDistance(shoreLine1, 15);
	rmSetAreaElevationVariation(shoreLine1, 0.0);
	rmAddAreaToClass(shoreLine1 , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(shoreLine1, false);
	rmBuildArea(shoreLine1);

	int shoreLine2 = rmCreateArea("shoreLine2");
	rmSetAreaSize(shoreLine2, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
	rmSetAreaLocation(shoreLine2, 0.5-rmXTilesToFraction(27)+harbourShiftX, 0.64);
	rmSetAreaCoherence(shoreLine2, 1.0);
	rmSetAreaBaseHeight(shoreLine2, 3.5);
	rmSetAreaMix(shoreLine2, "newengland_grass");
	rmSetAreaHeightBlend(shoreLine2, 2);
	rmSetAreaSmoothDistance(shoreLine2, 15);
	rmSetAreaElevationVariation(shoreLine2, 0.0);
	rmAddAreaToClass(shoreLine2 , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(shoreLine2, false);
	rmBuildArea(shoreLine2);

	int shoreLine3 = rmCreateArea("shoreLine3");
	rmSetAreaSize(shoreLine3, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
	rmSetAreaLocation(shoreLine3, 0.6+rmXTilesToFraction(27)+harbourShiftX, 0.5);
	rmSetAreaCoherence(shoreLine3, 1.0);
	rmSetAreaBaseHeight(shoreLine3, 3.5);
	rmSetAreaMix(shoreLine3, "newengland_grass");
	rmSetAreaHeightBlend(shoreLine3, 2);
	rmSetAreaSmoothDistance(shoreLine3, 15);
	rmSetAreaElevationVariation(shoreLine3, 0.0);
	rmAddAreaToClass(shoreLine3 , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(shoreLine3, false);
	rmBuildArea(shoreLine3);

	int shoreLine4 = rmCreateArea("shoreLine4");
	rmSetAreaSize(shoreLine4, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
	rmSetAreaLocation(shoreLine4, 0.4-rmXTilesToFraction(27)+harbourShiftX, 0.5);
	rmSetAreaCoherence(shoreLine4, 1.0);
	rmSetAreaBaseHeight(shoreLine4, 3.5);
	rmSetAreaMix(shoreLine4, "newengland_grass");
	rmSetAreaHeightBlend(shoreLine4, 2);
	rmSetAreaSmoothDistance(shoreLine4, 15);
	rmSetAreaElevationVariation(shoreLine4, 0.0);
	rmAddAreaToClass(shoreLine4 , rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(shoreLine4, false);
	rmBuildArea(shoreLine4);


	// Elevated terrain

	int playerHillsNorthID = rmCreateArea("playerHillsNorth");
	rmSetAreaMix(playerHillsNorthID, "newengland_grass");
	rmSetAreaSize(playerHillsNorthID, 0.23, 0.23);
	rmSetAreaCoherence(playerHillsNorthID, 1.0);
	rmSetAreaBaseHeight(playerHillsNorthID, 3);
	rmSetAreaHeightBlend(playerHillsNorthID, 2);
	rmSetAreaSmoothDistance(playerHillsNorthID, 6);
	rmSetAreaObeyWorldCircleConstraint(playerHillsNorthID, false);
	rmAddAreaConstraint(playerHillsNorthID, avoidWater5);
	rmAddAreaConstraint(playerHillsNorthID, avoidBridge);
	rmSetAreaElevationVariation(playerHillsNorthID, 6.0);
	rmSetAreaElevationType(playerHillsNorthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerHillsNorthID, 0.09);
	rmSetAreaElevationOctaves(playerHillsNorthID, 3);
	rmSetAreaElevationPersistence(playerHillsNorthID, 0.2);
	rmSetAreaElevationNoiseBias(playerHillsNorthID, 1);
	rmSetAreaLocation(playerHillsNorthID, 0.8, 0.8);
	rmBuildArea(playerHillsNorthID);

	int playerHillsSouthID = rmCreateArea("playerHillsSouth");
	rmSetAreaMix(playerHillsSouthID, "newengland_grass");
	rmSetAreaSize(playerHillsSouthID, 0.23, 0.23);
	rmSetAreaCoherence(playerHillsSouthID, 1.0);
	rmSetAreaBaseHeight(playerHillsSouthID, 3);
	rmSetAreaHeightBlend(playerHillsSouthID, 2);
	rmSetAreaSmoothDistance(playerHillsSouthID, 6);
	rmSetAreaObeyWorldCircleConstraint(playerHillsSouthID, false);
	rmAddAreaConstraint(playerHillsSouthID, avoidWater5);
	rmAddAreaConstraint(playerHillsSouthID, avoidBridge);
	rmSetAreaElevationVariation(playerHillsSouthID, 6.0);
	rmSetAreaElevationType(playerHillsSouthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerHillsSouthID, 0.09);
	rmSetAreaElevationOctaves(playerHillsSouthID, 3);
	rmSetAreaElevationPersistence(playerHillsSouthID, 0.2);
	rmSetAreaElevationNoiseBias(playerHillsSouthID, 1);
	rmSetAreaLocation(playerHillsSouthID, 0.2, 0.8);
	rmBuildArea(playerHillsSouthID);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// ********************** Pirates at the mouth of the gulf *****************
	// Two coastal settlements on the strip that closes off the bay, one on each
	// headland - the slots the Hanseatic cities used to occupy.

	int pirateControllerID1 = rmCreateObjectDef("pirate controller 1");
	rmAddObjectDefItem(pirateControllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(pirateControllerID1, 0.0);
	rmSetObjectDefMaxDistance(pirateControllerID1, 0.0);

	int pirateControllerID2 = rmCreateObjectDef("pirate controller 2");
	rmAddObjectDefItem(pirateControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(pirateControllerID2, 0.0);
	rmSetObjectDefMaxDistance(pirateControllerID2, 0.0);

	// Pushed out to the rim, on the two headlands where the gulf opens to the
	// sea. Anchors sit just OFFSHORE at every map size (sim-measured 2-15 m
	// seaward at 480/600/720/792) so the 700-tile site disc always straddles
	// the coastline as a peninsula; the old (0.17,0.30)/(0.83,0.30) anchors
	// ended up 41-61 m inland after the +20% resize.
	rmPlaceObjectDefAtLoc(pirateControllerID1, 0, 0.215, 0.24);
	rmPlaceObjectDefAtLoc(pirateControllerID2, 0, 0.79, 0.235);

	vector pirateControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID1, 0));
	vector pirateControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID2, 0));

	// Headland underneath each settlement (guide 19.5, "fixed placement with an
	// island underneath"). The previous build had no reliable ground here, which
	// is why the villages never appeared.

	int pirateSite1 = rmCreateArea("pirate_site1");
	rmSetAreaSize(pirateSite1, rmAreaTilesToFraction(700), rmAreaTilesToFraction(700));
	rmSetAreaLocation(pirateSite1, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1)));
	rmSetAreaCoherence(pirateSite1, 1.0);
	rmSetAreaMix(pirateSite1, "newengland_grass");
	rmSetAreaBaseHeight(pirateSite1, 3.0);
	rmSetAreaHeightBlend(pirateSite1, 2);
	rmSetAreaSmoothDistance(pirateSite1, 15);
	rmSetAreaElevationVariation(pirateSite1, 0.0);
	rmSetAreaObeyWorldCircleConstraint(pirateSite1, false);
	rmBuildArea(pirateSite1);

	int pirateSite2 = rmCreateArea("pirate_site2");
	rmSetAreaSize(pirateSite2, rmAreaTilesToFraction(700), rmAreaTilesToFraction(700));
	rmSetAreaLocation(pirateSite2, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc2)));
	rmSetAreaCoherence(pirateSite2, 1.0);
	rmSetAreaMix(pirateSite2, "newengland_grass");
	rmSetAreaBaseHeight(pirateSite2, 3.0);
	rmSetAreaHeightBlend(pirateSite2, 2);
	rmSetAreaSmoothDistance(pirateSite2, 15);
	rmSetAreaElevationVariation(pirateSite2, 0.0);
	rmSetAreaObeyWorldCircleConstraint(pirateSite2, false);
	rmBuildArea(pirateSite2);

	// Villages - the Australia pair, placed exactly on the controller.
	// min/max distance are both 0 and there are NO grouping constraints: that is
	// how Elbe's city states and the guide's fixed-placement example do it. The
	// previous max-distance-30 + ferryOnShore combination let the placement wander
	// and then fail silently.

	int piratesVillageID1 = rmCreateGrouping("pirate city 1", "pirate_village05");
	rmSetGroupingMinDistance(piratesVillageID1, 0.00);
	rmSetGroupingMaxDistance(piratesVillageID1, 0.00);

	rmPlaceGroupingAtLoc(piratesVillageID1, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1)), 1);
	rmEchoInfo("pirate village 1 placed");

	int piratesVillageID2 = rmCreateGrouping("pirate city 2", "Pirate_Village06");
	rmSetGroupingMinDistance(piratesVillageID2, 0.00);
	rmSetGroupingMaxDistance(piratesVillageID2, 0.00);

	// Water flags - one per settlement, dropped on the nearest water tile.

	int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
	rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage1 = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

	rmClearClosestPointConstraints();

	rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc2)), 1);
	rmEchoInfo("pirate village 2 placed");

	int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
	rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage2 = rmFindClosestPointVector(pirateControllerLoc2, rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

	rmClearClosestPointConstraints();

	// Pirate ports

	int pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport03");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage1a = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

	rmClearClosestPointConstraints();

	int pirateportID2 = rmCreateGrouping("pirate port 2", "pirateport04");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage2a = rmFindClosestPointVector(pirateControllerLoc2, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

	rmClearClosestPointConstraints();

	// ****************** Haudenosaunee settlements ******************
	// The Six Nations split in the Revolutionary War (Oneida/Tuscarora with
	// the revolution, Mohawk/Seneca/Cayuga with the crown), so each shore
	// holds its own villages to court. Fixed spots, mirrored east-west,
	// sim-validated at every size: >=35 m clear ground, >=70 m from every
	// fort and estate, >=80 m from the pirates. 1/2/3 per shore by players.
	// Village groupings and placement idiom copied from unknown.xs
	// ("native iroquois village 1-5"); fixed variants keep builds deterministic.
	// 1v1: the lone village moves to the north-central gap of each shore
	// so the objects spread instead of stacking the mid-edge corridor.
	float haudsV1x = 0.06;
	float haudsV1z = 0.51;
	if (mapS == 1) {
		haudsV1x = 0.29;
		haudsV1z = 0.69;
	}
	int iroquoisW1 = rmCreateGrouping("haudenosaunee village w1", "native iroquois village 1");
	rmSetGroupingMinDistance(iroquoisW1, 0.00);
	rmSetGroupingMaxDistance(iroquoisW1, 0.00);
	rmPlaceGroupingAtLoc(iroquoisW1, 0, haudsV1x, haudsV1z, 1);

	int iroquoisE1 = rmCreateGrouping("haudenosaunee village e1", "native iroquois village 2");
	rmSetGroupingMinDistance(iroquoisE1, 0.00);
	rmSetGroupingMaxDistance(iroquoisE1, 0.00);
	rmPlaceGroupingAtLoc(iroquoisE1, 0, 1.0-haudsV1x, haudsV1z, 1);

	if (mapS == 0) {
		int iroquoisW2 = rmCreateGrouping("haudenosaunee village w2", "native iroquois village 3");
		rmSetGroupingMinDistance(iroquoisW2, 0.00);
		rmSetGroupingMaxDistance(iroquoisW2, 0.00);
		rmPlaceGroupingAtLoc(iroquoisW2, 0, 0.275, 0.70, 1);

		int iroquoisE2 = rmCreateGrouping("haudenosaunee village e2", "native iroquois village 4");
		rmSetGroupingMinDistance(iroquoisE2, 0.00);
		rmSetGroupingMaxDistance(iroquoisE2, 0.00);
		rmPlaceGroupingAtLoc(iroquoisE2, 0, 0.725, 0.70, 1);
	}

	if (mapL == 1 || mapXL == 1) {
		int iroquoisW3 = rmCreateGrouping("haudenosaunee village w3", "native iroquois village 5");
		rmSetGroupingMinDistance(iroquoisW3, 0.00);
		rmSetGroupingMaxDistance(iroquoisW3, 0.00);
		rmPlaceGroupingAtLoc(iroquoisW3, 0, 0.405, 0.76, 1);

		int iroquoisE3 = rmCreateGrouping("haudenosaunee village e3", "native iroquois village 1");
		rmSetGroupingMinDistance(iroquoisE3, 0.00);
		rmSetGroupingMaxDistance(iroquoisE3, 0.00);
		rmPlaceGroupingAtLoc(iroquoisE3, 0, 0.595, 0.76, 1);
	}

	// ********************** Colonial Estates *****************************
	// Three estates on each bank of the river. The type order is randomised once
	// and then reused on BOTH banks, so reading from the upper stream downwards
	// gives the same sequence on either side (coin-wood-food, wood-food-coin, ...).
	// Each one gets a flattened valley underneath first (King of Bohemia's
	// jesuitValley technique) so the buildings never sit on a slope. Height only -
	// no rmSetAreaMix, or the valley paints a visible disc of terrain around it.

	int estateOrder = rmRandInt(1, 6);
	string estateUpper = "";
	string estateMiddle = "";
	string estateLower = "";

	if (estateOrder == 1) {
		estateUpper = "coin"; estateMiddle = "wood"; estateLower = "food";
	}
	if (estateOrder == 2) {
		estateUpper = "coin"; estateMiddle = "food"; estateLower = "wood";
	}
	if (estateOrder == 3) {
		estateUpper = "wood"; estateMiddle = "coin"; estateLower = "food";
	}
	if (estateOrder == 4) {
		estateUpper = "wood"; estateMiddle = "food"; estateLower = "coin";
	}
	if (estateOrder == 5) {
		estateUpper = "food"; estateMiddle = "coin"; estateLower = "wood";
	}
	if (estateOrder == 6) {
		estateUpper = "food"; estateMiddle = "wood"; estateLower = "coin";
	}
	rmEchoInfo("estate order from upper stream: "+estateUpper+" - "+estateMiddle+" - "+estateLower);

	// Estate ring at r ~0.39 - pulled a little off the map edge toward the
	// center, three per continent fanned along the arc with EQUAL spacing
	// (161/168 m at 600 m): near-bridge north, west arc midpoint, southwest
	// (east side the exact mirror). Sim-validated at every size: valley disc
	// fully on land (docks excluded), inside the world circle, >=77 m from
	// the pirate anchors, >=67 m from every fort slot that can coexist.
	float estateW1x = 0.29;   float estateW1z = 0.85;   // near-bridge north
	float estateW2x = 0.135;  float estateW2z = 0.645;  // west (arc midpoint)
	float estateW3x = 0.13;   float estateW3z = 0.375;  // southwest
	float estateE1x = 0.71;   float estateE1z = 0.85;
	float estateE2x = 0.865;  float estateE2z = 0.645;
	float estateE3x = 0.87;   float estateE3z = 0.375;

	// Flatten first - six valleys.

	int estateValley1 = rmCreateArea ("estateValley1");
	rmSetAreaSize(estateValley1, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley1, estateW1x, estateW1z);
	rmSetAreaCoherence(estateValley1, 0.8);
	rmSetAreaBaseHeight(estateValley1, 3.0);
	rmSetAreaSmoothDistance(estateValley1, 15);
	rmSetAreaHeightBlend(estateValley1, 2);
	rmSetAreaElevationVariation(estateValley1, 0.0);
	rmSetAreaWarnFailure(estateValley1, false);
	rmBuildArea(estateValley1);

	int estateValley2 = rmCreateArea ("estateValley2");
	rmSetAreaSize(estateValley2, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley2, estateW2x, estateW2z);
	rmSetAreaCoherence(estateValley2, 0.8);
	rmSetAreaBaseHeight(estateValley2, 3.0);
	rmSetAreaSmoothDistance(estateValley2, 15);
	rmSetAreaHeightBlend(estateValley2, 2);
	rmSetAreaElevationVariation(estateValley2, 0.0);
	rmSetAreaWarnFailure(estateValley2, false);
	rmBuildArea(estateValley2);

	int estateValley3 = rmCreateArea ("estateValley3");
	rmSetAreaSize(estateValley3, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley3, estateW3x, estateW3z);
	rmSetAreaCoherence(estateValley3, 0.8);
	rmSetAreaBaseHeight(estateValley3, 3.0);
	rmSetAreaSmoothDistance(estateValley3, 15);
	rmSetAreaHeightBlend(estateValley3, 2);
	rmSetAreaElevationVariation(estateValley3, 0.0);
	rmSetAreaWarnFailure(estateValley3, false);
	rmBuildArea(estateValley3);

	int estateValley4 = rmCreateArea ("estateValley4");
	rmSetAreaSize(estateValley4, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley4, estateE1x, estateE1z);
	rmSetAreaCoherence(estateValley4, 0.8);
	rmSetAreaBaseHeight(estateValley4, 3.0);
	rmSetAreaSmoothDistance(estateValley4, 15);
	rmSetAreaHeightBlend(estateValley4, 2);
	rmSetAreaElevationVariation(estateValley4, 0.0);
	rmSetAreaWarnFailure(estateValley4, false);
	rmBuildArea(estateValley4);

	int estateValley5 = rmCreateArea ("estateValley5");
	rmSetAreaSize(estateValley5, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley5, estateE2x, estateE2z);
	rmSetAreaCoherence(estateValley5, 0.8);
	rmSetAreaBaseHeight(estateValley5, 3.0);
	rmSetAreaSmoothDistance(estateValley5, 15);
	rmSetAreaHeightBlend(estateValley5, 2);
	rmSetAreaElevationVariation(estateValley5, 0.0);
	rmSetAreaWarnFailure(estateValley5, false);
	rmBuildArea(estateValley5);

	int estateValley6 = rmCreateArea ("estateValley6");
	rmSetAreaSize(estateValley6, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
	rmSetAreaLocation(estateValley6, estateE3x, estateE3z);
	rmSetAreaCoherence(estateValley6, 0.8);
	rmSetAreaBaseHeight(estateValley6, 3.0);
	rmSetAreaSmoothDistance(estateValley6, 15);
	rmSetAreaHeightBlend(estateValley6, 2);
	rmSetAreaElevationVariation(estateValley6, 0.0);
	rmSetAreaWarnFailure(estateValley6, false);
	rmBuildArea(estateValley6);

	// Then the estates themselves - same order on both banks.

	rmSetNuggetDifficulty(515, 515);

	int estateWestUpperID = rmCreateGrouping("estate west upper", "Colonial_estate_"+estateUpper);
	rmSetGroupingMinDistance(estateWestUpperID, 0.00);
	rmSetGroupingMaxDistance(estateWestUpperID, 0.00);
	int placeWU = rmPlaceGroupingInstanceAtLoc(estateWestUpperID, estateW1x, estateW1z, 0);

	int estateWestMiddleID = rmCreateGrouping("estate west middle", "Colonial_estate_"+estateMiddle);
	rmSetGroupingMinDistance(estateWestMiddleID, 0.00);
	rmSetGroupingMaxDistance(estateWestMiddleID, 0.00);
	int placeWM = rmPlaceGroupingInstanceAtLoc(estateWestMiddleID, estateW2x, estateW2z, 0);

	int estateWestLowerID = rmCreateGrouping("estate west lower", "Colonial_estate_"+estateLower);
	rmSetGroupingMinDistance(estateWestLowerID, 0.00);
	rmSetGroupingMaxDistance(estateWestLowerID, 0.00);
	int placeWL = rmPlaceGroupingInstanceAtLoc(estateWestLowerID, estateW3x, estateW3z, 0);

	int estateEastUpperID = rmCreateGrouping("estate east upper", "Colonial_estate_"+estateUpper);
	rmSetGroupingMinDistance(estateEastUpperID, 0.00);
	rmSetGroupingMaxDistance(estateEastUpperID, 0.00);
	int placeEU = rmPlaceGroupingInstanceAtLoc(estateEastUpperID, estateE1x, estateE1z, 0);

	int estateEastMiddleID = rmCreateGrouping("estate east middle", "Colonial_estate_"+estateMiddle);
	rmSetGroupingMinDistance(estateEastMiddleID, 0.00);
	rmSetGroupingMaxDistance(estateEastMiddleID, 0.00);
	int placeEM = rmPlaceGroupingInstanceAtLoc(estateEastMiddleID, estateE2x, estateE2z, 0);

	int estateEastLowerID = rmCreateGrouping("estate east lower", "Colonial_estate_"+estateLower);
	rmSetGroupingMinDistance(estateEastLowerID, 0.00);
	rmSetGroupingMaxDistance(estateEastLowerID, 0.00);
	int placeEL = rmPlaceGroupingInstanceAtLoc(estateEastLowerID, estateE3x, estateE3z, 0);


	// Colonial Estate instance units. The groupings contain zpCityStateFlag
	// (NOT the Team variant), zpElectorCenter and zpSocketColonialEstate.
	// The resource building differs per variant - coin/food/wood give
	// zpSPCGoldSmelter / zpSPCDestilery / zpSPCSawMill respectively.
	int centerWU = rmGetGroupingInstanceUnitByType(placeWU, "zpElectorCenter");
	int socketWU = rmGetGroupingInstanceUnitByType(placeWU, "zpSocketColonialEstate");
	int centerWM = rmGetGroupingInstanceUnitByType(placeWM, "zpElectorCenter");
	int socketWM = rmGetGroupingInstanceUnitByType(placeWM, "zpSocketColonialEstate");
	int centerWL = rmGetGroupingInstanceUnitByType(placeWL, "zpElectorCenter");
	int socketWL = rmGetGroupingInstanceUnitByType(placeWL, "zpSocketColonialEstate");
	int centerEU = rmGetGroupingInstanceUnitByType(placeEU, "zpElectorCenter");
	int socketEU = rmGetGroupingInstanceUnitByType(placeEU, "zpSocketColonialEstate");
	int centerEM = rmGetGroupingInstanceUnitByType(placeEM, "zpElectorCenter");
	int socketEM = rmGetGroupingInstanceUnitByType(placeEM, "zpSocketColonialEstate");
	int centerEL = rmGetGroupingInstanceUnitByType(placeEL, "zpElectorCenter");
	int socketEL = rmGetGroupingInstanceUnitByType(placeEL, "zpSocketColonialEstate");

	// All three production protos are queried for every estate. Only one
	// exists per variant; the other two resolve to -1 and are harmless.
	int smeltWU = rmGetGroupingInstanceUnitByType(placeWU, "zpSPCGoldSmelter");
	int stillWU = rmGetGroupingInstanceUnitByType(placeWU, "zpSPCDestilery");
	int millWU = rmGetGroupingInstanceUnitByType(placeWU, "zpSPCSawMill");
	int smeltWM = rmGetGroupingInstanceUnitByType(placeWM, "zpSPCGoldSmelter");
	int stillWM = rmGetGroupingInstanceUnitByType(placeWM, "zpSPCDestilery");
	int millWM = rmGetGroupingInstanceUnitByType(placeWM, "zpSPCSawMill");
	int smeltWL = rmGetGroupingInstanceUnitByType(placeWL, "zpSPCGoldSmelter");
	int stillWL = rmGetGroupingInstanceUnitByType(placeWL, "zpSPCDestilery");
	int millWL = rmGetGroupingInstanceUnitByType(placeWL, "zpSPCSawMill");
	int smeltEU = rmGetGroupingInstanceUnitByType(placeEU, "zpSPCGoldSmelter");
	int stillEU = rmGetGroupingInstanceUnitByType(placeEU, "zpSPCDestilery");
	int millEU = rmGetGroupingInstanceUnitByType(placeEU, "zpSPCSawMill");
	int smeltEM = rmGetGroupingInstanceUnitByType(placeEM, "zpSPCGoldSmelter");
	int stillEM = rmGetGroupingInstanceUnitByType(placeEM, "zpSPCDestilery");
	int millEM = rmGetGroupingInstanceUnitByType(placeEM, "zpSPCSawMill");
	int smeltEL = rmGetGroupingInstanceUnitByType(placeEL, "zpSPCGoldSmelter");
	int stillEL = rmGetGroupingInstanceUnitByType(placeEL, "zpSPCDestilery");
	int millEL = rmGetGroupingInstanceUnitByType(placeEL, "zpSPCSawMill");

	// Guardian nuggets: zpNuggetInvisible in each estate grouping spawns the
	// Estate Guardians (the Hansa city-state system, zpelbe.xs).
	int nuggetWU = rmGetGroupingInstanceUnitByType(placeWU, "zpNuggetInvisible");
	int nuggetWM = rmGetGroupingInstanceUnitByType(placeWM, "zpNuggetInvisible");
	int nuggetWL = rmGetGroupingInstanceUnitByType(placeWL, "zpNuggetInvisible");
	int nuggetEU = rmGetGroupingInstanceUnitByType(placeEU, "zpNuggetInvisible");
	int nuggetEM = rmGetGroupingInstanceUnitByType(placeEM, "zpNuggetInvisible");
	int nuggetEL = rmGetGroupingInstanceUnitByType(placeEL, "zpNuggetInvisible");


	// KotH

	if(rmGetIsKOTH()) {
		int kingHillID = rmCreateObjectDef("king hill");
		rmAddObjectDefItem(kingHillID, "ypKingsHill", 1, 0.0);
		rmAddObjectDefConstraint(kingHillID, avoidAll);
		rmAddObjectDefConstraint(kingHillID, playerEdgeConstraint);
		rmAddObjectDefConstraint(kingHillID, avoidWater10);
		rmAddObjectDefConstraint(kingHillID, avoidBridge);
		rmPlaceObjectDefAtLoc(kingHillID, 0, 0.5, 0.72, 1);
	}

	// Capturable trade harbours - four of them, spread around the gulf circuit and
	// the channel. Each is paired with a guardian nugget at the same spot.

	rmSetNuggetDifficulty(514, 514);

	// One per shoreLine cliff. Elbe idiom: the socket sits 11 tiles off the
	// route line, in the water pocket in front of its cliff (cliff center is
	// 27 tiles off) - docked BY the island coast, never on the route itself.

	rmPlaceObjectDefAtLoc(loneSocketID1, 0, 0.5+rmXTilesToFraction(11)+harbourShiftX, 0.74);
	rmPlaceObjectDefAtLoc(loneNuggetID1, 0, 0.5+rmXTilesToFraction(11)+harbourShiftX, 0.74);

	rmPlaceObjectDefAtLoc(loneSocketID2, 0, 0.5-rmXTilesToFraction(11)+harbourShiftX, 0.64);
	rmPlaceObjectDefAtLoc(loneNuggetID2, 0, 0.5-rmXTilesToFraction(11)+harbourShiftX, 0.64);

	rmPlaceObjectDefAtLoc(loneSocketID3, 0, 0.6+rmXTilesToFraction(11)+harbourShiftX, 0.5);
	rmPlaceObjectDefAtLoc(loneNuggetID3, 0, 0.6+rmXTilesToFraction(11)+harbourShiftX, 0.5);

	rmPlaceObjectDefAtLoc(loneSocketID4, 0, westLegX-rmXTilesToFraction(11)+harbourShiftX, 0.5);
	rmPlaceObjectDefAtLoc(loneNuggetID4, 0, westLegX-rmXTilesToFraction(11)+harbourShiftX, 0.5);


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// ************************* Place Players *****************************

	// Fort starts (up to 4 players): exact positions on the inner coasts,
	// zpFlorence-style - circular placement cannot express "forts next to
	// each other by the shore". Each slot holds a Player_Fort_AM_Single
	// grouping (own TownCenter, walls, start resources), so on this path the
	// loose TC/mine/deer/tree placements are skipped. Slots sim-validated:
	// on land, clear of harbour cliffs, docks, the route lane and the circle.
	// Fort starts at every player count (always 2 teams) - EXCEPT lobbies
	// with 5+ players on one team: a shore only owns 4 fort slots, so those
	// games fall back to the classic circular TC + resource placement
	// (Elbe-style, the pre-fort behavior kept below as the else path; the
	// TCs avoid the estate ring via avoidEstate).
	int useForts = 1;
	if (eastTeamSize > 4)
		useForts = 0;
	if (westTeamSize > 4)
		useForts = 0;

	int playerFortID = rmCreateGrouping("player fort", "Player_Fort_AM_Single");
	rmSetGroupingMinDistance(playerFortID, 0.00);
	rmSetGroupingMaxDistance(playerFortID, 0.00);

	// Place Town Centers
	rmSetTeamSpacingModifier(0.6);

	float teamStartLoc = rmRandFloat(0.0, 1.0);

	// Spawn Switch (zpparis.xs): randomises which team holds which bank.
	// Roles (Attacker/Defender cards, victory) follow TEAM numbers, not
	// geography, so only the placement side flips.
	float spawnSwitch = rmRandInt(0,1);
	int eastTeam = 0;
	if (spawnSwitch == 1)
		eastTeam = 1;
	if (useForts == 1)
	{
		// Slot tables. 1v1 ONLY: mirror-symmetric face-off straight across the
		// channel, (0.652,0.70) vs (0.348,0.70). 3+ players: NO fort sits by
		// the bridge - the old upstream slots were too close to the only
		// crossing, so each shore's first slot lives INLAND by its bend
		// harbour instead: East (0.755,0.53) behind harbour 3 (the user's
		// circle, valid as drawn), West (0.306,0.559) behind harbour 4.
		// Remaining slots: E (0.62,0.628), W (0.376,0.64) mid-bank; slots 5-8
		// southeast around the route loop.
		// Empirical placement rules from playtests: >=42 m clear of
		// water/cliffs at every size (30 m failed at 2p, 36-42 m spawned at
		// 600 m); same-team separation >=62 m (40 m = touching walls,
		// collided at 3p).
		// Always 2 teams (historical, Florence-style). Which team holds the
		// east bank is randomised per game by spawnSwitch (zpparis.xs).
		int slotNum = 0;
		int eastCount = 0;
		int westCount = 0;
		for (i = 1; <cNumberPlayers)
		{
			float fortX = 0.755;
			float fortZ = 0.53;
			// Fill order: strictly COAST -> UPSTREAM at every player count,
			// 1v1 included. The seacoast bay slots settle first (east 5 then
			// 7, west 6 then 8), then the inland harbour slots (1/4), and
			// the near-bridge slots (3/2) settle last - the line of forts
			// extends from the coast toward the bridge by team size.
			// Teams of 1 (1v1) and the first player of a team of 2 take the
			// inland river slot (9/10); a pair's second player goes to the
			// coast slot - the two teammates end up most far from each other
			// (~95 m at 600, vs 48 m of the old coast pair). Teams of 3-4
			// keep the coast->upstream ladder 5/7/1/3 (west 6/8/4/2).
			int myTeamSize = westTeamSize;
			if (rmGetPlayerTeam(i) == 0)
				myTeamSize = eastTeamSize;
			if (rmGetPlayerTeam(i) == eastTeam) {
				eastCount = eastCount + 1;
				slotNum = 5;
				if (mapS == 1)
					slotNum = 9;
				if (myTeamSize == 2) {
					slotNum = 9;
					if (eastCount == 2)
						slotNum = 5;
				}
				if (myTeamSize >= 3) {
					if (eastCount == 2)
						slotNum = 7;
					if (eastCount == 3)
						slotNum = 1;
					if (eastCount == 4)
						slotNum = 3;
				}
			}
			else {
				westCount = westCount + 1;
				slotNum = 6;
				if (mapS == 1)
					slotNum = 10;
				if (myTeamSize == 2) {
					slotNum = 10;
					if (westCount == 2)
						slotNum = 6;
				}
				if (myTeamSize >= 3) {
					if (westCount == 2)
						slotNum = 8;
					if (westCount == 3)
						slotNum = 4;
					if (westCount == 4)
						slotNum = 2;
				}
			}
			if (slotNum == 2) {
				fortX = 0.376;	fortZ = 0.64;
			}
			if (slotNum == 3) {
				fortX = 0.62;	fortZ = 0.628;
			}
			if (slotNum == 4) {
				fortX = 0.306;	fortZ = 0.559;
			}
			// Slots 5-8: third/fourth fort per shore, SOUTHEAST around the
			// trade route loop on the bay shores (exact x-mirrors). Sim-gated
			// at 600/720/792; 5+7 coexist only at 792 (sep 63 m there).
			if (slotNum == 5) {
				fortX = 0.76;	fortZ = 0.352;
			}
			if (slotNum == 6) {
				fortX = 0.24;	fortZ = 0.356;
			}
			if (slotNum == 7) {
				fortX = 0.684;	fortZ = 0.376;
			}
			if (slotNum == 8) {
				fortX = 0.316;	fortZ = 0.376;
			}
			// Inland river slots (1v1 + pair leaders): sim-scanned, ~63 m
			// water clearance at 480, more at larger sizes.
			if (slotNum == 9) {
				fortX = 0.75;	fortZ = 0.51;
			}
			if (slotNum == 10) {
				fortX = 0.25;	fortZ = 0.51;
			}
			// Flatten the fort site - the estateValley construct verbatim
			// (700 tiles, coherence 0.8, base height 3.0, smooth 15, blend 2).
			int fortValleyID = rmCreateArea("fortValley"+i);
			rmSetAreaSize(fortValleyID, rmAreaTilesToFraction(700.0), rmAreaTilesToFraction(700.0));
			rmSetAreaLocation(fortValleyID, fortX, fortZ);
			rmSetAreaCoherence(fortValleyID, 0.8);
			rmSetAreaBaseHeight(fortValleyID, 3.0);
			rmSetAreaSmoothDistance(fortValleyID, 15);
			rmSetAreaHeightBlend(fortValleyID, 2);
			rmSetAreaElevationVariation(fortValleyID, 0.0);
			rmSetAreaWarnFailure(fortValleyID, false);
			rmBuildArea(fortValleyID);
			rmPlacePlayer(i, fortX, fortZ);
			rmPlaceGroupingAtLoc(playerFortID, i, fortX, fortZ, 1);
		}
	}
	else if(cNumberTeams > 2)
	{
		rmSetPlacementSection(0.73, 0.27);
		rmSetTeamSpacingModifier(0.75);
		rmPlacePlayersCircular(0.38, 0.42, 0);
	}
	else
	{
		if (PlayerNum == 2) {
			if (teamStartLoc > 0.5) {
				rmPlacePlayer(1, 0.85, 0.55);
				rmPlacePlayer(2, 0.15, 0.55);
			}
			else {
				rmPlacePlayer(1, 0.15, 0.55);
				rmPlacePlayer(2, 0.85, 0.55);
			}
		}
		else {
			// Fallback for lobbies with 5+ players on one team: inner-circle
			// ring (r 0.22-0.26, the fort zone) with sections aimed at the
			// CONTINENTS. The old 0.38-0.42 / 0.73-0.90 sections predate the
			// bay redesign - they dropped the east team into the southern
			// sea (sim-measured up to 221 m offshore), which is why players
			// went missing. Shores fixed per team like the fort tables:
			// team 0 = Attacker = east bank, team 1 = west.
			if (spawnSwitch == 0) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.90, 0.10);
				rmPlacePlayersCircular(0.22, 0.26, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.40, 0.60);
				rmPlacePlayersCircular(0.22, 0.26, rmDegreesToRadians(5.0));
			}
			else {
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.90, 0.10);
				rmPlacePlayersCircular(0.22, 0.26, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.40, 0.60);
				rmPlacePlayersCircular(0.22, 0.26, rmDegreesToRadians(5.0));
			}
		}
	}

	// Insert Players
	int TCfloat = -1;
	if (cNumberTeams == 2)
		TCfloat = 20;
	else
		TCfloat = 60;
	// Classic-placement fallback: generous TC drift so every player always
	// gets a Town Center even if a ring point clips water or an obstacle.
	if (useForts == 0)
		TCfloat = 60;

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
	rmAddObjectDefItem(playerMineID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand);

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "deer", rmRandInt(10,15), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 15.0);
	rmSetObjectDefMaxDistance(playerDeerID, 30.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);

	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "TreeNewEngland", 15, 8.0);
	rmSetObjectDefMinDistance(playerTreeID, 15);
	rmSetObjectDefMaxDistance(playerTreeID, 25);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, rmClassID("classForest"));
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	rmAddObjectDefConstraint(TCID, avoidTownCenter);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidSocketLong);
	rmAddObjectDefConstraint(TCID, avoidWater10);
	rmAddObjectDefConstraint(TCID, avoidEstate);

	for(i=1; <cNumberPlayers) {

		// Place town centers. Fort path: Player_Fort_AM_Single already carries
		// its own TownCenter, mine, deer, trees and berries, so the loose
		// placements are skipped and TCLoc anchors on the player position.
		vector TCLoc = xsVectorSet(rmXFractionToMeters(rmPlayerLocXFraction(i)), 0.0, rmZFractionToMeters(rmPlayerLocZFraction(i)));
		if (useForts == 0) {
			rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
		}

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
		rmAddClosestPointConstraint(avoidBridgeLong);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

		// Place resources
		rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		if (useForts == 0) {
			rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
			rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
			rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		}

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	}

	rmClearClosestPointConstraints();

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ************************* Place resources *****************************

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidTownCenterFar);
	rmAddObjectDefConstraint(randomGoldID, avoidSocketLong);
	rmAddObjectDefConstraint(randomGoldID, avoidWater20);
	rmAddObjectDefConstraint(randomGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldID, avoidEstate);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandSouthID, cNumberNonGaiaPlayers*1.5);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandNorthID, cNumberNonGaiaPlayers*1.5);

	// Forests

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - one loop per landmass
	numTries=52;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 66;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 80;
	failCount=0;
	for (i=0; <numTries)
		{
		int westForest=rmCreateArea("westforest"+i);
		rmSetAreaWarnFailure(westForest, false);
		rmSetAreaSize(westForest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));

		rmSetAreaForestType(westForest, "z69 North New England");
		rmSetAreaForestDensity(westForest, 1.0);
		rmAddAreaToClass(westForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(westForest, 0.0);
		rmSetAreaForestUnderbrush(westForest, 0.0);
		rmSetAreaCoherence(westForest, 0.4);
		rmAddAreaConstraint(westForest, avoidImportantItem);
		rmAddAreaConstraint(westForest, shortAvoidCoin);
		rmAddAreaConstraint(westForest, avoidTownCenterFar);
		rmAddAreaConstraint(westForest, avoidPlateauShort);
		rmAddAreaConstraint(westForest, avoidAll);
		rmAddAreaConstraint(westForest, avoidWater10);
		rmAddAreaConstraint(westForest, avoidTradeRouteFar2);
		rmAddAreaConstraint(westForest, forestConstraint);
		rmAddAreaConstraint(westForest, westLand);
		if(rmBuildArea(westForest)==false)
		{
			// Stop trying once we fail 5 times in a row.
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount=0;
	}


	numTries=52;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 66;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 80;
	failCount=0;
	for (i = 0; i < numTries; i++)
	{
		int eastForest = rmCreateArea("eastForest" + i);
		rmSetAreaWarnFailure(eastForest, false);
		rmSetAreaSize(eastForest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
		rmSetAreaForestType(eastForest, "z69 North New England");
		rmSetAreaForestDensity(eastForest, 1.0);
		rmAddAreaToClass(eastForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(eastForest, 0.0);
		rmSetAreaForestUnderbrush(eastForest, 0.0);
		rmSetAreaCoherence(eastForest, 0.4);
		rmAddAreaConstraint(eastForest, avoidImportantItem);
		rmAddAreaConstraint(eastForest, shortAvoidCoin);
		rmAddAreaConstraint(eastForest, avoidTownCenterFar);
		rmAddAreaConstraint(eastForest, avoidPlateauShort);
		rmAddAreaConstraint(eastForest, avoidWater10);
		rmAddAreaConstraint(eastForest, avoidAll);
		rmAddAreaConstraint(eastForest, avoidTradeRouteFar2);
		rmAddAreaConstraint(eastForest, forestConstraint);
		rmAddAreaConstraint(eastForest, eastLand);
		if (rmBuildArea(eastForest) == false)
		{
			// Stop trying once we fail 5 times in a row.
			failCount++;
			if (failCount == 5)
				break;
		}
		else
			failCount = 0;
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// Berries

	int berriesID = rmCreateObjectDef("berries"+i);
	rmAddObjectDefItem(berriesID, "berrybush", 3, 4.0);
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berriesID, avoidCoin);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidTradeRoute);
	rmAddObjectDefConstraint(berriesID, avoidSocket);
	rmAddObjectDefConstraint(berriesID, avoidWater20);
	rmAddObjectDefConstraint(berriesID, westLand);
	rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5);

	int berriesID2 = rmCreateObjectDef("berries 2"+i);
	rmAddObjectDefItem(berriesID2, "berrybush", 3, 4.0);
	rmSetObjectDefMinDistance(berriesID2, 0.0);
	rmSetObjectDefMaxDistance(berriesID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berriesID2, avoidCoin);
	rmAddObjectDefConstraint(berriesID2, avoidAll);
	rmAddObjectDefConstraint(berriesID2, avoidTradeRoute);
	rmAddObjectDefConstraint(berriesID2, avoidSocket);
	rmAddObjectDefConstraint(berriesID2, avoidWater20);
	rmAddObjectDefConstraint(berriesID2, eastLand);
	rmPlaceObjectDefAtLoc(berriesID2, 0, 0.5, 0.5);

	// Water nuggets - the standard Age of Pirates set (zpcaribbeanwars.xs
	// construct verbatim). Difficulty 6 on caribbeanwater = privateer
	// wrecks, native canoe wrecks and a shark rock; no diff-5 water
	// treasure exists for our maptypes, so both defs use the guarded tier.
	int waterNuggetAvoidLand = rmCreateTerrainDistanceConstraint("water nugget avoid land", "land", true, 15.0);
	int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0);
	int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);

	int nuggetWater= rmCreateObjectDef("nugget water");
	rmAddObjectDefItem(nuggetWater, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(6, 6);
	rmSetObjectDefMinDistance(nuggetWater, rmXFractionToMeters(0.0));
	rmSetObjectDefMaxDistance(nuggetWater, rmXFractionToMeters(1.0));
	rmAddObjectDefConstraint(nuggetWater, waterNuggetAvoidLand);
	rmAddObjectDefConstraint(nuggetWater, ObjectAvoidTradeRoute);
	rmAddObjectDefConstraint(nuggetWater, avoidNuggetWater2);
	rmAddObjectDefConstraint(nuggetWater, playerEdgeConstraint);
	rmPlaceObjectDefPerPlayer(nuggetWater, false, 1);

	int nuggetWaterHard = rmCreateObjectDef("nugget water hard");
	rmAddObjectDefItem(nuggetWaterHard, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(6, 6);
	rmSetObjectDefMinDistance(nuggetWaterHard, rmXFractionToMeters(0.25));
	rmSetObjectDefMaxDistance(nuggetWaterHard, rmXFractionToMeters(1.0));
	rmAddObjectDefConstraint(nuggetWaterHard, waterNuggetAvoidLand);
	rmAddObjectDefConstraint(nuggetWaterHard, ObjectAvoidTradeRoute);
	rmAddObjectDefConstraint(nuggetWaterHard, avoidNuggetWater);
	rmAddObjectDefConstraint(nuggetWaterHard, playerEdgeConstraint);
	rmPlaceObjectDefPerPlayer(nuggetWaterHard, false, 1);

	// Place some extra deer herds.
	int deerHerdID=rmCreateObjectDef("western deer herd");
	rmAddObjectDefItem(deerHerdID, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID, true);
	rmSetObjectDefMinDistance(deerHerdID, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID, avoidAll);
	rmAddObjectDefConstraint(deerHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID, westLand);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID, 0, 0.5, 0.5);
	}

	int deerHerdID2=rmCreateObjectDef("eastern deer herd");
	rmAddObjectDefItem(deerHerdID2, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID2, true);
	rmSetObjectDefMinDistance(deerHerdID2, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID2, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID2, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID2, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID2, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID2, avoidAll);
	rmAddObjectDefConstraint(deerHerdID2, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID2, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID2, eastLand);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	// **************** Nuggets *******************

	int nugget1= rmCreateObjectDef("nugget easy");
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefToClass(nugget1, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget1, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTownCenter);
	rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNuggets);
	rmAddObjectDefConstraint(nugget1, avoidTradeSockets);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidEstate);
	rmAddObjectDefConstraint(nugget1, circleConstraint);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandSouthID, cNumberNonGaiaPlayers*1.5);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandNorthID, cNumberNonGaiaPlayers*1.5);

	int nugget2= rmCreateObjectDef("nugget medium");
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmAddObjectDefToClass(nugget2, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget2, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNuggets);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget2, avoidEstate);
	rmAddObjectDefConstraint(nugget2, circleConstraint);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2,avoidWater20);
	rmPlaceObjectDefInArea(nugget2, 0,  playerIslandSouthID, cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(nugget2, 0,  playerIslandNorthID, cNumberNonGaiaPlayers/2);

	// Fishes

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	if (rmGetIsKOTH() == true)
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.4));
	else
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 50+10*cNumberNonGaiaPlayers);

	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

	// VILLAGE TREES
	int villageTreeID=rmCreateObjectDef("village tree");
	rmAddObjectDefItem(villageTreeID, "TreeNewEngland", 1, 0.0);
	rmAddObjectDefConstraint(villageTreeID, avoidAll);
	rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite1, 6);
	rmPlaceObjectDefInArea(villageTreeID, 0,  pirateSite2, 6);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	// ------Triggers--------//

	// Unit IDxs

	int loneHarbourID1 = rmGetUnitPlaced(loneSocketID1, 0);
	int loneHarbourID2 = rmGetUnitPlaced(loneSocketID2, 0);
	int loneHarbourID3 = rmGetUnitPlaced(loneSocketID3, 0);
	int loneHarbourID4 = rmGetUnitPlaced(loneSocketID4, 0);

	int loneHarbourNuggetID1 = rmGetUnitPlaced(loneNuggetID1, 0);
	int loneHarbourNuggetID2 = rmGetUnitPlaced(loneNuggetID2, 0);
	int loneHarbourNuggetID3 = rmGetUnitPlaced(loneNuggetID3, 0);
	int loneHarbourNuggetID4 = rmGetUnitPlaced(loneNuggetID4, 0);

	// zpSocketPirates is the LAST unit inside both village groupings (29 units
	// in pirate_village05, 26 in Pirate_Village06). Unit ids are consecutive in
	// placement order and the second controller is the last unit placed before
	// the villages, so the sockets sit at fixed offsets from it - same
	// consecutive-id idiom as the loneHarbour +1 lookups above.
	// (rmGetGroupingInstanceUnitByType only works for city-state groupings and
	// returned garbage here - in-game verified.)
	int pirateSocket1 = rmGetUnitPlaced(piratewaterflagID1, 0) - 1;
	int pirateSocket2 = rmGetUnitPlaced(piratewaterflagID2, 0) - 1;

	int pirateFlag1 = rmGetUnitPlaced(piratewaterflagID1, 0);
	int pirateFlag2 = rmGetUnitPlaced(piratewaterflagID2, 0);

	// Arrays

	// Pirate Socket Array
	int pirateSockets = xsArrayCreateInt(2, -1, "Pirate Sockets");
	xsArraySetInt(pirateSockets, 0, pirateSocket1);
	xsArraySetInt(pirateSockets, 1, pirateSocket2);

	int pirateSocketID = -1;

	// Pirate Flag Array
	int pirateFlags = xsArrayCreateInt(2, -1, "Pirate Flags");
	xsArraySetInt(pirateFlags, 0, pirateFlag1);
	xsArraySetInt(pirateFlags, 1, pirateFlag2);

	int pirateFlagID = -1;

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.90);

	// Map setup: fires the Colonial Estate deck reset. Otherwise follows
	// zpcaribbeanwars.xs and only flags itself as a pirate map (see Human Check below).
	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting Techs"));
	// Colonial Estate: strip every persona's cards off the Trading Post so
	// nothing shows until a persona is elected. Same role as
	// zpPrinceElectorNativeSetup, which zpCrownlandsSetup fires the same way.
	for (x=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",x);
		rmSetTriggerEffectParam("TechID","cTechzpColonialEstateNativeSetup"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",x);
		rmSetTriggerEffectParam("TechID","cTechzpIndependenceWarSetup"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		// Capturable-harbour resource crates: the naval unlock the engine
		// auto-fires on vanilla water maps (Elbe rides it too) never fires
		// for this custom route, so grant it here.
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",x);
		rmSetTriggerEffectParam("TechID","cTechypTradeRouteCaptureable"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Declaring independence upgrades the trade route to its maximum
	// level (Cargo Boat -> Trade Steamer). zp_mississippi construct
	// (AT_TR_Upgrade_Plr: Armored Trains -> Trade Route Set Level);
	// no upgrade tech is researchable at the harbours on this map,
	// so the Revolution is the only path.
	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Revolution_TR_Upgrade"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpRevolutionAmerica");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Harbour conversion. Every harbour starts with AutoConvert suspended; it is
	// released once its guardian nugget has been cleared.



	// ****************** Colonial Estate capture ******************
	// Same mechanism as the workshop ON/OFF pair in zpcrownlands.xs: when a
	// player has a Trading Post within 15m of the estate socket, the flag,
	// the Elector Center and the resource building all Convert to that
	// player. When the Trading Post is gone they Convert back to gaia (0).
	// Each ON trigger arms its own OFF, so the pair alternates.

	int estateSockets = xsArrayCreateInt(6, -1, "Estate Sockets");
	int estateCenters = xsArrayCreateInt(6, -1, "Estate Centers");
	xsArraySetInt(estateSockets, 0, socketWU);
	xsArraySetInt(estateCenters, 0, centerWU);
	xsArraySetInt(estateSockets, 1, socketWM);
	xsArraySetInt(estateCenters, 1, centerWM);
	xsArraySetInt(estateSockets, 2, socketWL);
	xsArraySetInt(estateCenters, 2, centerWL);
	xsArraySetInt(estateSockets, 3, socketEU);
	xsArraySetInt(estateCenters, 3, centerEU);
	xsArraySetInt(estateSockets, 4, socketEM);
	xsArraySetInt(estateCenters, 4, centerEM);
	xsArraySetInt(estateSockets, 5, socketEL);
	xsArraySetInt(estateCenters, 5, centerEL);

	int estateSmelts = xsArrayCreateInt(6, -1, "Estate smelt");
	xsArraySetInt(estateSmelts, 0, smeltWU);
	xsArraySetInt(estateSmelts, 1, smeltWM);
	xsArraySetInt(estateSmelts, 2, smeltWL);
	xsArraySetInt(estateSmelts, 3, smeltEU);
	xsArraySetInt(estateSmelts, 4, smeltEM);
	xsArraySetInt(estateSmelts, 5, smeltEL);
	int estateStills = xsArrayCreateInt(6, -1, "Estate still");
	xsArraySetInt(estateStills, 0, stillWU);
	xsArraySetInt(estateStills, 1, stillWM);
	xsArraySetInt(estateStills, 2, stillWL);
	xsArraySetInt(estateStills, 3, stillEU);
	xsArraySetInt(estateStills, 4, stillEM);
	xsArraySetInt(estateStills, 5, stillEL);
	int estateMills = xsArrayCreateInt(6, -1, "Estate mill");
	xsArraySetInt(estateMills, 0, millWU);
	xsArraySetInt(estateMills, 1, millWM);
	xsArraySetInt(estateMills, 2, millWL);
	xsArraySetInt(estateMills, 3, millEU);
	xsArraySetInt(estateMills, 4, millEM);
	xsArraySetInt(estateMills, 5, millEL);
	int estateNuggets = xsArrayCreateInt(6, -1, "Estate nugget");
	xsArraySetInt(estateNuggets, 0, nuggetWU);
	xsArraySetInt(estateNuggets, 1, nuggetWM);
	xsArraySetInt(estateNuggets, 2, nuggetWL);
	xsArraySetInt(estateNuggets, 3, nuggetEU);
	xsArraySetInt(estateNuggets, 4, nuggetEM);
	xsArraySetInt(estateNuggets, 5, nuggetEL);

	// Production buildings must never auto-convert to a passer-by - they
	// follow the estate owner and nothing else.
	rmCreateTrigger("Estate Production NoAutoConvert");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltWU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillWU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millWU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltWM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillWM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millWM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltWL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillWL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millWL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltEU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillEU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millEU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltEM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillEM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millEM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+smeltEL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+stillEL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+millEL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	string guardianUnit = "zpNatColonialEstateMilitia";

	// Conversion Suspend (Crownlands/zpelbe city-state idiom): estate
	// sockets start with AutoConvert forbidden ...
	rmCreateTrigger("Estate Sockets Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketWU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketWM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketWL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketEU);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketEM);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+socketEL);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	int socketMinimapFlareDuration = 10;
	int sameTeam = -1;
	vector estateFlareLoc1 = rmGetUnitPosition(socketWU);
	vector estateFlareLoc2 = rmGetUnitPosition(socketWM);
	vector estateFlareLoc3 = rmGetUnitPosition(socketWL);
	vector estateFlareLoc4 = rmGetUnitPosition(socketEU);
	vector estateFlareLoc5 = rmGetUnitPosition(socketEM);
	vector estateFlareLoc6 = rmGetUnitPosition(socketEL);

	int estateSocketID = -1;
	int estateCenterID = -1;
	int estateSmeltID = -1;
	int estateStillID = -1;
	int estateMillID = -1;
	int estateNuggetID = -1;

	for (s=1; <=6) {
		estateSocketID = xsArrayGetInt(estateSockets, s-1);
		estateCenterID = xsArrayGetInt(estateCenters, s-1);
		estateSmeltID = xsArrayGetInt(estateSmelts, s-1);
		estateStillID = xsArrayGetInt(estateStills, s-1);
		estateMillID = xsArrayGetInt(estateMills, s-1);
		estateNuggetID = xsArrayGetInt(estateNuggets, s-1);

		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("estate"+s+" ON Player"+k);
			rmCreateTrigger("estate"+s+" OFF Player"+k);

			rmSwitchToTrigger(rmTriggerID("estate"+s+" ON Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+estateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",15);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamFloat("Count",1);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+estateSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamFloat("Dist",20);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+estateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deField");
			rmSetTriggerEffectParamFloat("Dist",35);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateCenterID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateSmeltID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateStillID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateMillID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			// Flare the estate for the capturing team (zpcrownlands
			// workshop ON idiom).
			sameTeam = rmGetPlayerTeam(k);
			for(i=1; <= cNumberNonGaiaPlayers) {
				if (sameTeam == rmGetPlayerTeam(i)) {
					rmAddTriggerEffect("Flare Minimap");
					rmSetTriggerEffectParamInt("PlayerID", i, false);
					rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
					if (s==1) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc1)+","+xsVectorGetY(estateFlareLoc1)+","+xsVectorGetZ(estateFlareLoc1), false);
					}
					if (s==2) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc2)+","+xsVectorGetY(estateFlareLoc2)+","+xsVectorGetZ(estateFlareLoc2), false);
					}
					if (s==3) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc3)+","+xsVectorGetY(estateFlareLoc3)+","+xsVectorGetZ(estateFlareLoc3), false);
					}
					if (s==4) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc4)+","+xsVectorGetY(estateFlareLoc4)+","+xsVectorGetZ(estateFlareLoc4), false);
					}
					if (s==5) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc5)+","+xsVectorGetY(estateFlareLoc5)+","+xsVectorGetZ(estateFlareLoc5), false);
					}
					if (s==6) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc6)+","+xsVectorGetY(estateFlareLoc6)+","+xsVectorGetZ(estateFlareLoc6), false);
					}
					rmSetTriggerEffectParam("Flash", "True", false);
				}
			}
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("estate"+s+"_OFF_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("estate"+s+" OFF Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+estateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",15);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamFloat("Count",0);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+estateSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamFloat("Dist",20);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+estateCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deField");
			rmSetTriggerEffectParamFloat("Dist",35);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateCenterID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateSmeltID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateStillID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+estateMillID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			// Flare the estate for the losing team (zpcrownlands workshop
			// OFF idiom).
			sameTeam = rmGetPlayerTeam(k);
			for(i=1; <= cNumberNonGaiaPlayers) {
				if (sameTeam == rmGetPlayerTeam(i)) {
					rmAddTriggerEffect("Flare Minimap");
					rmSetTriggerEffectParamInt("PlayerID", i, false);
					rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
					if (s==1) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc1)+","+xsVectorGetY(estateFlareLoc1)+","+xsVectorGetZ(estateFlareLoc1), false);
					}
					if (s==2) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc2)+","+xsVectorGetY(estateFlareLoc2)+","+xsVectorGetZ(estateFlareLoc2), false);
					}
					if (s==3) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc3)+","+xsVectorGetY(estateFlareLoc3)+","+xsVectorGetZ(estateFlareLoc3), false);
					}
					if (s==4) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc4)+","+xsVectorGetY(estateFlareLoc4)+","+xsVectorGetZ(estateFlareLoc4), false);
					}
					if (s==5) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc5)+","+xsVectorGetY(estateFlareLoc5)+","+xsVectorGetZ(estateFlareLoc5), false);
					}
					if (s==6) {
						rmSetTriggerEffectParam("Position", ""+xsVectorGetX(estateFlareLoc6)+","+xsVectorGetY(estateFlareLoc6)+","+xsVectorGetZ(estateFlareLoc6), false);
					}
					rmSetTriggerEffectParam("Flash", "True", false);
				}
			}
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("estate"+s+"_ON_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

		}
	}

	// ... and released once no gaia guardians remain within 25 m of the
	// socket (Units in Area == 0, zpelbe "Socket N Convert ON" verbatim -
	// NOT nugget-collectable, so guards that wander off still count).
	for (s=1; <=6) {
		estateSocketID = xsArrayGetInt(estateSockets, s-1);
		rmCreateTrigger("Estate Socket "+s+" Convert ON");
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+estateSocketID);
		rmSetTriggerConditionParamInt("Player",0);
		rmSetTriggerConditionParam("UnitType",guardianUnit);
		rmSetTriggerConditionParamInt("Dist",25);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject", ""+estateSocketID, false);
		rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
		rmSetTriggerEffectParam("Suspend", "False", false);
		rmAddTriggerEffect("Flash Units");
		rmSetTriggerEffectParam("SrcObject", ""+estateSocketID, false);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	rmForbidTradeMonopoly(true);

	// ****************** Colonial Estate site ladder ******************
	// Chained: only the next rung is armed, so it cannot double-fire. Counts
	// zpCityStateFlag - the groupings carry that, NOT the Team variant.
	// Created as "Estate Increase2" but referenced as "Estate_Increase2".

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Estate Increase2"+k);
		rmCreateTrigger("Estate Increase3"+k);
		rmCreateTrigger("Estate Increase4"+k);
		rmCreateTrigger("Estate Increase5"+k);
		rmCreateTrigger("Estate Increase6"+k);
		rmCreateTrigger("Estate Decrease1"+k);
		rmCreateTrigger("Estate Decrease2"+k);
		rmCreateTrigger("Estate Decrease3"+k);
		rmCreateTrigger("Estate Decrease4"+k);
		rmCreateTrigger("Estate Decrease5"+k);

		rmSwitchToTrigger(rmTriggerID("Estate Increase2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase3"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Increase3"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase4"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Increase4"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",4);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase5"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease3"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Increase5"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",5);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase6"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease4"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Increase6"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",6);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease5"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Decrease1"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteDecrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Decrease2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteDecrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase3"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Decrease3"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteDecrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase4"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Decrease4"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",4);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteDecrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase5"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease3"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Estate Decrease5"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",5);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpEstateSiteDecrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase6"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease4"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	}
	// ****************** Colonial Estate side unlocks ******************
	// Two triggers, one per team, each CommandAdd-ing that side's elect card onto
	// the Trading Post for its own players only. Same shape as zpparis.xs, which
	// loops the players inside the trigger and filters on rmGetPlayerTeam.
	// Team 0 = Attacker, team 1 = Defender - the convention zpparis.xs and
	// zpverseilles.xs already use (team 0 is the revolutionary/attacking side).

	rmCreateTrigger("Estate Unlock Attacker Team");
	for (x=1; <= cNumberNonGaiaPlayers) {
		if (rmGetPlayerTeam(x) == 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",x);
			rmSetTriggerEffectParam("TechID","cTechzpEstateUnlockAttacker"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Estate Unlock Defender Team");
	for (x=1; <= cNumberNonGaiaPlayers) {
		if (rmGetPlayerTeam(x) != 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",x);
			rmSetTriggerEffectParam("TechID","cTechzpEstateUnlockDefender"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ____________________ MAP OBJECTIVES ____________________
	// Venice/Civil War idiom. 400279-400282 = this map's own strings
	// (english stringmods; recompile the xmb after string edits).
	rmObjectiveScreenSetTitle(400279);
	rmObjectiveScreenSetGoal(400281);
	rmObjectiveAdd(400282, 400280, true, true, true);

	// ******************** Victory Conditions ***********************
	// Venice/Civil War countdown idiom (zpvenicecity.xs / zpcivilwar.xs,
	// copied verbatim): hold 4 of the 6 Colonial Estates - a held estate is
	// a team-owned zpElectorCenter, the capture triggers convert it to the
	// Trading Post's owner and back to gaia when the post falls - and the
	// 480 s countdown fires Team Victory; dropping below 4 stops the clock,
	// the ON/OFF triggers re-arm each other. Counter text reuses the shared
	// strings {302138}/{302139}.
	int victoryCountDown = 600;

	for(i = 1; < cNumberTeams+1){
		rmCreateTrigger("TeamVictory"+i);
		rmCreateTrigger("Victory_Counter"+i);
		rmCreateTrigger("Victory_Counter_OFF"+i);
	}

	for(i = 1; < cNumberTeams+1){
		// Team Victory
		rmSwitchToTrigger(rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Team Victory");
		rmSetTriggerEffectParamInt("TeamID", i);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Victory Counter
		rmSwitchToTrigger(rmTriggerID("Victory_Counter"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",4);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter_OFF"+i));
		rmAddTriggerEffect("Counter Set Text Team");
		rmSetTriggerEffectParam("Name", "VictoryCounter"+i);
		rmSetTriggerEffectParam("Msg", "{302138}");
		rmSetTriggerEffectParam("EnemyMsg", "{302139}");
		rmSetTriggerEffectParamInt("RefTeamID", i);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter_OFF"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<");
		rmSetTriggerConditionParamInt("Count",4);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID3);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID4);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 3 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID3);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID3, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 4 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID4);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID4, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	for(k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("AI Techs"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSPCVeniceCityStatesAI"); // Only for the AI to train the city state units from sockets
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

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

	// Colonial Estate election. Cloned verbatim from the "Activate Tortuga"
	// block above - only the three tech names differ.
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Estate Elect Defender"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpColonialEstateElectDefender"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffColonialEstateDefender"); //operator
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
		rmCreateTrigger("Estate Elect Attacker"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpColonialEstateElectAttacker"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffColonialEstateAttacker"); //operator
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

	// ****************** Declaration of Independence ******************
	// zpparis Flag-Lafayette ceremony verbatim: electing any of the three
	// Patriot politicians (Western / Sansculottes / Jewish - the personas
	// that activate cTechzpRevolutionAmerica on the xml side) hoists the
	// Stars and Stripes (DEAmericans, the Civil War Union flag donor),
	// renames the player to the United States of America and plays the
	// same revolution music and sting as the French Revolution.
	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Revolution_MusicEnd"+k);

	rmCreateTrigger("Flag Patriot Western"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateEstateWestern");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","DEAmericans");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","400288");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Flag Patriot Sansculottes"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateEstateSansculottes");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","DEAmericans");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","400288");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Flag Patriot Jewish"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpConsulateEstateJewish");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("Civilization","DEAmericans");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",k);
	rmSetTriggerEffectParam("StringID","400288");
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",0.5);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 61000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Revolution_MusicEnd"+k));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",5);
	rmAddTriggerEffect("Music Play");
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Elect_Defender"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Elect_Attacker"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Pirate Ship Training - one set per settlement

	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("TrainPrivateer"+s+"ON Plr"+k);
			rmCreateTrigger("TrainPrivateer"+s+"OFF Plr"+k);
			rmCreateTrigger("TrainPrivateer"+s+"TIME Plr"+k);

			rmCreateTrigger("UniqueShip"+s+"TIMEPlr"+k);
			rmCreateTrigger("BlackbTrain"+s+"ONPlr"+k);
			rmCreateTrigger("BlackbTrain"+s+"OFFPlr"+k);
			rmCreateTrigger("GraceTrain"+s+"ONPlr"+k);
			rmCreateTrigger("GraceTrain"+s+"OFFPlr"+k);
			rmCreateTrigger("CaesarTrain"+s+"ONPlr"+k);
			rmCreateTrigger("CaesarTrain"+s+"OFFPlr"+k);

			pirateSocketID = xsArrayGetInt(pirateSockets, s-1);

			rmSwitchToTrigger(rmTriggerID("TrainPrivateer"+s+"ON_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer"+s); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer"+s+"OFF_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer"+s+"TIME_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainPrivateer"+s+"OFF_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer"+s+"ON_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainPrivateer"+s+"TIME_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamFloat("Param1",200);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer"+s); //operator
			rmSetTriggerEffectParamInt("Status",0);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("UniqueShip"+s+"TIMEPlr"+k));
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

			rmSwitchToTrigger(rmTriggerID("BlackbTrain"+s+"ONPlr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne"+s); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip"+s+"TIMEPlr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain"+s+"OFFPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("BlackbTrain"+s+"OFFPlr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain"+s+"ONPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("GraceTrain"+s+"ONPlr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl"+s); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip"+s+"TIMEPlr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain"+s+"OFFPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("GraceTrain"+s+"OFFPlr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain"+s+"ONPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("CaesarTrain"+s+"ONPlr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune"+s); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip"+s+"TIMEPlr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain"+s+"OFFPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("CaesarTrain"+s+"OFFPlr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain"+s+"ONPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

		}
	}

	// Pirate settlement capture / release

	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Pirates"+s+"on Player"+k);
			rmCreateTrigger("Pirates"+s+"off Player"+k);

			pirateSocketID = xsArrayGetInt(pirateSockets, s-1);
			pirateFlagID = xsArrayGetInt(pirateFlags, s-1);

			rmSwitchToTrigger(rmTriggerID("Pirates"+s+"on_Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamFloat("Count",1);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+pirateFlagID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates"+s+"off_Player"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain"+s+"ONPlr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain"+s+"ONPlr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain"+s+"ONPlr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Pirates"+s+"off_Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+pirateSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamFloat("Count",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+pirateFlagID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates"+s+"on_Player"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain"+s+"ONPlr"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain"+s+"ONPlr"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain"+s+"ONPlr"+k));
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

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.99);

} // END
