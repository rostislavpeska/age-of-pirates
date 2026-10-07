// DANUBE
// October 2026
//
// The Danube Bend. The river is a water trade route (river_trail) bent into a U that opens east; one land trade route
// (dirt) crosses it over both arm bridges. The players sit on the outer shore around the bend, never beyond the land
// route. The inner shore is locked (the river on three sides, the east map edge on the fourth): only the bridges lead
// into it, and it holds the Prince Electors and the richest resources. Hussites on the north outer shore, Orthodox
// monasteries (Balkan variant) on the south. A normal map (game/randmaps): no .mods.xml, no map setup tech, every civ,
// team layout and game mode. Plan: docs/ideas/2026-10-01-danube-map.md ("v9", one requirements list).
//
// Order: the river routes, the land route DEFINED (London: every placement uses its asked line), the bridges into open
// water on that line, the channel drawn from the built river routes (exact discs, eased meander, 30 m of water round
// every route by construction), the shores around it, the Elbe's cliff docks, the land route BUILT through them, the
// sockets measured from the routes, players (two modes only, Dead Sea), natives at fixed spots per size,
// then nature and resources.
// Blocks copied from: King of Bohemia (look, starts, resources), Crownlands (map types, team helper, Elector
// increments), Balearic Islands (starting techs of a normal European map), Elbe (Elector castles and triggers, Hussite camps, bridge docks), Adriatic Sea (Orthodox monasteries).

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

string fish1 = "ypFishCarp";

// Get player order within a team (zpcrownlands.xs)

int g_zpTeamPlayerResult = -1;

void zpGetTeamPlayer(int teamOrder = -1, int teamID = -1)
{
    g_zpTeamPlayerResult = -1;
    if (teamOrder <= 0) {
        return;
    }

    int count = 0;
    int i = 0;
    for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == teamID)
        {
            count = count + 1;
            if (count == teamOrder)
            {
                g_zpTeamPlayerResult = i;  // "return" via global
                return;
            }
        }
    }
    // not found => stays -1
}

// Prince Elector site ladder (scripts/mapcheck/elector_ladder.py, owner 2026-10-07). Per player, triggers count the
// zpElectorCenter he owns: holding c of the map's N settlements gives c-1 steps of elector build limit (one step of
// zpElectorSiteIncrease / zpElectorSiteDecrease: +9 Landsknecht, +15 Line Infantry, ...). One toggle per threshold
// n = 2..N: "Elector Increase<n>" (count >= n, active at start) steps up and wakes only "Elector Decrease<n-1>"
// (count <= n-1), which steps down and wakes only Increase<n> again. The toggles never wake each other, so any jump
// of the count settles at c-1 steps; a chain that also woke Increase<n+1> / Decrease<n-1> re-armed rungs that had
// fired in the same tick and counted them twice (the 4-castle chain of Crownlands / Unknown: 4 -> 0 at once ended at
// -3 steps). For N = 2 this is Elbe's pair (zpelbe.xs 1730-1768).
void zpElectorSiteLadder(int numSettlements = 2)
{
	int lowerRung = 0;
	for (p=1; <= cNumberNonGaiaPlayers) {
		for (n=2; <= numSettlements) {
			rmCreateTrigger("Elector Increase"+n+p);
			lowerRung = n - 1;
			rmCreateTrigger("Elector Decrease"+lowerRung+p);
		}

		for (n=2; <= numSettlements) {
			lowerRung = n - 1;
			rmSwitchToTrigger(rmTriggerID("Elector_Increase"+n+p));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",p);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",n);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",p);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease"+lowerRung+p));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector_Decrease"+lowerRung+p));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",p);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op","<=");
			rmSetTriggerConditionParamInt("Count",lowerRung);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",p);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase"+n+p));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
	}
}

void main(void)
{
	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01);

	// Natives: 0 Hussites (north outer shore), 1 Orthodox (south outer shore), 2 Prince Electors (inner shore)
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;

	if (rmAllocateSubCivs(4) == true)
	{
		subCiv0=rmGetCivID("zphussites");
		rmEchoInfo("subCiv0 is zphussites "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zphussites");

		subCiv1=rmGetCivID("zporthodox");
		rmEchoInfo("subCiv1 is zporthodox "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zporthodox");

		subCiv2=rmGetCivID("zpprinceelector");
		rmEchoInfo("subCiv2 is zpprinceelector "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "zpprinceelector");

		subCiv3=rmGetCivID("spcjesuit");
		rmEchoInfo("subCiv3 is spcjesuit "+subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "spcjesuit");
	}

	// Map size: a multiple of 32 m, so the centre lines and the river arms sit on the trade route's 16 m cells.
	// armOffset (distance of each river arm from the centre line) is a cell centre, 16 i + 8 m.
	int size = 512;
	float sizeM = 512.0;
	float armOffset = 88.0;
	if (PlayerNum >= 3) {
		size = 576;
		sizeM = 576.0;
		armOffset = 104.0;
	}
	if (PlayerNum >= 5) {
		size = 640;
		sizeM = 640.0;
		armOffset = 120.0;
	}
	if (PlayerNum >= 7) {
		size = 704;
		sizeM = 704.0;
		armOffset = 136.0;
	}
	rmSetMapSize(size, size);

	// The bend, in metres
	float centreM = sizeM / 2.0;
	float armNorthZ = centreM + armOffset;		// north arm of the river
	float armSouthZ = centreM - armOffset;		// south arm
	float apexX = centreM - armOffset - 32.0;	// the west leg of the bend
	float eastX = sizeM - 8.0;					// both arms run out at the east edge: the inner shore stays locked
	int bridgeCell = (centreM + 0.1*sizeM) / 16.0;
	float bridgeX = 16.0*bridgeCell + 8.0;		// the arm bridges and the land route through them, on a 16 m cell line
	// the land, level with the bridges (owner 2026-10-07: the docks at the bridge's height stood above the land, "shift
	// all terrain height a bit up"): Bridge_Universal_03's block stands 4.15 m above the river bottom, 3.07..3.25 m in
	// the v12 editor saves of 2-8 players. King of Bohemia's 2.983 before
	float landHeight = 3.2;

	rmSetMapElevationHeightBlend(1);
	rmSetSeaLevel(0.0);

	// LIGHT SET

	rmSetLightingSet("honshu_Skirmish");

	// Picks default terrain and water: the map starts as water and the shores are built around the river route
	rmSetSeaType("ZP Bohemian River");
	rmSetBaseTerrainMix("italy_grass_lush");
	rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetMapType("default");
	rmSetMapType("centralEurope");
	rmSetMapType("euroLandRiverTradeRoute");
	rmSetMapType("piratehistoricalmap");

	chooseMercs();

	// Make the corners
	rmSetWorldCircleConstraint(true);

	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classPatch");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("nuggets");
	rmDefineClass("classBlock");
	rmDefineClass("classBridge");
	rmDefineClass("harbour");
	int classChannel = rmDefineClass("river channel");
	int classLand = rmDefineClass("land");
	int classStartingResource = rmDefineClass("startingResource");

	// -------------Define constraints
	// These are used to have objects and areas avoid each other

	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(15), rmZTilesToFraction(15), 1.0-rmXTilesToFraction(15), 1.0-rmZTilesToFraction(15), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	// Square map: ONE circle keeps every scattered object inside the playable circle, its radius the half map size less
	// the object's own margin (rm-objects-herds "Map-edge constraints", mapcheck S7): 8 m for mines, herds, bushes and
	// fish, 20 m for treasures (a camp with its guards). A box alone leaves the corners open
	int insideWorldRes = rmCreatePieConstraint("inside the world circle, resources", 0.5, 0.5, 0.0, rmXFractionToMeters(0.5)-8.0, rmDegreesToRadians(0), rmDegreesToRadians(360));
	int insideWorldTreasure = rmCreatePieConstraint("inside the world circle, treasures", 0.5, 0.5, 0.0, rmXFractionToMeters(0.5)-20.0, rmDegreesToRadians(0), rmDegreesToRadians(360));

	int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
	int avoidWaterNative = rmCreateTerrainDistanceConstraint("natives avoid water", "Land", false, 25.0);
	int avoidLandFish = rmCreateTerrainDistanceConstraint("avoid land medium fish", "Water", false, 4.0);

	// Cardinal directions (King of Bohemia)
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(270), rmDegreesToRadians(90));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(90), rmDegreesToRadians(270));

	// The outer shores beyond each arm (natives of each side, dry patches in the south)
	int northOuterBox = rmCreateBoxConstraint("north outer shore", 0.0, rmZMetersToFraction(armNorthZ+35.0), 1.0, 1.0, 0.01);
	int southOuterBox = rmCreateBoxConstraint("south outer shore", 0.0, 0.0, 1.0, rmZMetersToFraction(armSouthZ-35.0), 0.01);
	int notSouthOuterBox = rmCreateBoxConstraint("not the south outer shore", 0.0, rmZMetersToFraction(armSouthZ-35.0), 1.0, 1.0, 0.01);

	// Player constraints
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 8.0);

	// Nature avoidance
	int fishVsFishShort=rmCreateTypeDistanceConstraint("fish v fish short", fish1, 10.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);	// 25 m before the owner's "more vegetation" (2026-10-07)
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 50.0);
	int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 40.0);
	int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", "Elk", 50.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 15.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);

	// Unit avoidance
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 8.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
	int avoidNativesFar=rmCreateClassDistanceConstraint("natives avoid natives", rmClassID("natives"), 60.0);
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
	int avoidBridge=rmCreateClassDistanceConstraint("stuff avoids bridges", rmClassID("classBridge"), 15.0);
	int avoidHarbour=rmCreateClassDistanceConstraint("stuff avoids the sockets", rmClassID("harbour"), 12.0);
	int avoidBlockMedium =rmCreateClassDistanceConstraint("stuff vs. blocks medium", rmClassID("classBlock"), 7.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 7.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int avoidTradeSocketNative=rmCreateTypeDistanceConstraint("natives avoid trade sockets", "SocketTradeRoute", 30.0);

	// Town centres
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTownCenterNative=rmCreateTypeDistanceConstraint("natives avoid Town Centers", "townCenter", 50.0);
	int avoidTownCenterPatch=rmCreateTypeDistanceConstraint("patches avoid Town Centers", "townCenter", 20.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ********************* The river: the trade route is the skeleton *******************************

	// Trade route must be always placed as first (London law 1), with a stopper at 0.5
	int stopperID=rmCreateObjectDef("route stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);

	// Owner 2026-10-06: a trade route never crosses a bridge. The river is three separate river routes (four with the
	// bend bridge at 5+ players) on the same U, each ending 32 m short of a bridge; the water under each bridge is kept
	// open by a line of markers the shores avoid. Each route gets its stopper at 0.5. Every waypoint sits on a 16 m
	// cell centre, so the built routes are these lines (trade routes guide 5.8)
	float gapEast = bridgeX + 32.0;		// the arm routes end here
	float gapWest = bridgeX - 32.0;		// the bend route starts here

	// The arms bend lightly outwards over their last stretch (owner 2026-10-06): straight from the bridge to curveX,
	// then two legs rising 16 m each (one route cell) to the edge, about 13 degrees. Both on cell centres (16 i + 8),
	// where the engine would snap them anyway: the river channel below is drawn from these same points
	int curveCell = (centreM + 0.25*sizeM) / 16.0;
	float curveX = 16.0*curveCell + 8.0;
	int curveMidCell = (curveX + eastX) / 32.0;
	float curveMidX = 16.0*curveMidCell + 8.0;

	// Route 1: the north arm, from the east edge to the north bridge
	int tradeRouteID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID, rmXMetersToFraction(eastX), rmZMetersToFraction(armNorthZ+32.0));
	rmAddTradeRouteWaypoint(tradeRouteID, rmXMetersToFraction(curveMidX), rmZMetersToFraction(armNorthZ+16.0));
	rmAddTradeRouteWaypoint(tradeRouteID, rmXMetersToFraction(curveX), rmZMetersToFraction(armNorthZ));
	rmAddTradeRouteWaypoint(tradeRouteID, rmXMetersToFraction(gapEast), rmZMetersToFraction(armNorthZ));
	rmBuildTradeRoute(tradeRouteID, "river_trail");
	vector stopperLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	rmPlaceObjectDefAtPoint(stopperID, 0, stopperLoc);

	// Route 2: the bend, from the north bridge round the west leg to the south bridge
	int tradeRoute2ID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(gapWest), rmZMetersToFraction(armNorthZ));
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(apexX+48.0), rmZMetersToFraction(armNorthZ));
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(apexX), rmZMetersToFraction(armNorthZ-48.0));
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(apexX), rmZMetersToFraction(armSouthZ+48.0));
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(apexX+48.0), rmZMetersToFraction(armSouthZ));
	rmAddTradeRouteWaypoint(tradeRoute2ID, rmXMetersToFraction(gapWest), rmZMetersToFraction(armSouthZ));
	rmBuildTradeRoute(tradeRoute2ID, "river_trail");
	stopperLoc = rmGetTradeRouteWayPoint(tradeRoute2ID, 0.5);
	rmPlaceObjectDefAtPoint(stopperID, 0, stopperLoc);

	// Route 3: the south arm, from the south bridge to the east edge
	int tradeRoute3ID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRoute3ID, rmXMetersToFraction(gapEast), rmZMetersToFraction(armSouthZ));
	rmAddTradeRouteWaypoint(tradeRoute3ID, rmXMetersToFraction(curveX), rmZMetersToFraction(armSouthZ));
	rmAddTradeRouteWaypoint(tradeRoute3ID, rmXMetersToFraction(curveMidX), rmZMetersToFraction(armSouthZ-16.0));
	rmAddTradeRouteWaypoint(tradeRoute3ID, rmXMetersToFraction(eastX), rmZMetersToFraction(armSouthZ-32.0));
	rmBuildTradeRoute(tradeRoute3ID, "river_trail");
	stopperLoc = rmGetTradeRouteWayPoint(tradeRoute3ID, 0.5);
	rmPlaceObjectDefAtPoint(stopperID, 0, stopperLoc);

	// The LAND route (owner 2026-10-06): south edge -> south bridge -> straight across the inner shore (between the
	// Elector castles) -> north bridge -> north edge, curving lightly east beyond the bridges. Defined here, built after
	// the shores (below): built on the water base the shores would paint over it, and their route distance would cut a
	// channel along it. Every placement on it uses this asked line (London, zplondon.xs 640-646), all on 16 m cells.
	int landRouteID = rmCreateTradeRoute();
	int landCell = 0;
	float landX1 = 0.0;
	float landX2 = 0.0;
	landCell = (bridgeX + 0.12*sizeM) / 16.0;
	landX2 = 16.0*landCell + 8.0;					// at the map edges
	landCell = (bridgeX + 0.05*sizeM) / 16.0;
	landX1 = 16.0*landCell + 8.0;					// past the docks
	landCell = (armSouthZ - 0.20*sizeM) / 16.0;
	float landZS1 = 16.0*landCell + 8.0;
	landCell = (armSouthZ - 0.10*sizeM) / 16.0;
	float landZS0 = 16.0*landCell + 8.0;
	landCell = (armNorthZ + 0.10*sizeM) / 16.0;
	float landZN0 = 16.0*landCell + 8.0;
	landCell = (armNorthZ + 0.20*sizeM) / 16.0;
	float landZN1 = 16.0*landCell + 8.0;
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(landX2), rmZMetersToFraction(8.0));
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(landX1), rmZMetersToFraction(landZS1));
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(bridgeX), rmZMetersToFraction(landZS0));
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(bridgeX), rmZMetersToFraction(landZN0));
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(landX1), rmZMetersToFraction(landZN1));
	rmAddTradeRouteWaypoint(landRouteID, rmXMetersToFraction(landX2), rmZMetersToFraction(sizeM-8.0));

	// ********************* The river channel: drawn from math *******************************

	// Owner 2026-10-06: "math and precision ... a stunning and natural river", no random shapes; and the land "MUST
	// absolutely never touch the trade route by design". The channel is a chain of exact discs (invisible areas,
	// coherence 1.0, fixed size: the engine grows such areas as discs to within a metre, mapsim field.py shore notes)
	// along a smooth centreline; the shores keep 4 m from them and 7 from the river routes (v7's set, which built fully
	// in game; an 18 route floor on these big areas left 15% of the map unclaimed in v8b, save_diff.py). The land never
	// comes nearer a river route than 30 m BY CONSTRUCTION: disc radius + 4 - swing = 36 + 4 - 10 = 30.
	// 1. Skeleton: the routes' authored, cell-snapped waypoints (the built line), joined from the north edge round the
	//    bend to the south edge, resampled every 4 m. Never engine read-backs (v8b / v9: the map origin at route ends).
	// 2. Centreline: each sample averaged with its 7 neighbours either side (+-28 m), which rounds the bend's 45-degree
	//    corners and softens the kinks near the edge.
	// 3. Meander: an offset along the centreline's outward normal, eased (smoothstep) between fixed keypoints. At each
	//    arm socket the channel swings 10 m AWAY from the socket's bank (its point bar there ends 30 m from the route);
	//    at the bend apex it swings 8 m out (the cut bank; none at 5+ players, where the bend bridge stands); near the
	//    east edge 4 m in. The bridges fall near the crossings. Mirrored north to south.
	// 4. A disc of radius 36 m every 8 m (40 m at the apex), and one on each bridge, which keeps the water open under
	//    the deck: banks 40 m from the centreline. Prototype of the same algorithm: scratchpad meander_v7.py.
	float meanderA = 10.0;				// swing at the arm sockets
	float meanderBend = 8.0;			// outward swing at the bend apex
	float meanderEdge = 4.0;			// inward swing near the east edge
	float channelR = 36.0;				// disc radius
	float channelBendR = 4.0;			// extra radius at the apex

	// 1. the routes' AUTHORED waypoints, joined from the north edge round the bend to the south edge (the bridges lie on
	// the straight arms between them). All on 16 m cell centres, so this is the built line (London's "asked line").
	// NEVER rmGetTradeRouteWayPoint read-backs: in game route 1 returned the map origin at both ends and the river
	// discs ran to the corner and across the inner shore (v8b / v9 saves, 2026-10-07)
	int skelX = xsArrayCreateFloat(10, 0.0, "river skeleton x");
	int skelZ = xsArrayCreateFloat(10, 0.0, "river skeleton z");
	xsArraySetFloat(skelX, 0, eastX);			xsArraySetFloat(skelZ, 0, armNorthZ+32.0);
	xsArraySetFloat(skelX, 1, curveMidX);		xsArraySetFloat(skelZ, 1, armNorthZ+16.0);
	xsArraySetFloat(skelX, 2, curveX);			xsArraySetFloat(skelZ, 2, armNorthZ);
	xsArraySetFloat(skelX, 3, apexX+48.0);		xsArraySetFloat(skelZ, 3, armNorthZ);
	xsArraySetFloat(skelX, 4, apexX);			xsArraySetFloat(skelZ, 4, armNorthZ-48.0);
	xsArraySetFloat(skelX, 5, apexX);			xsArraySetFloat(skelZ, 5, armSouthZ+48.0);
	xsArraySetFloat(skelX, 6, apexX+48.0);		xsArraySetFloat(skelZ, 6, armSouthZ);
	xsArraySetFloat(skelX, 7, curveX);			xsArraySetFloat(skelZ, 7, armSouthZ);
	xsArraySetFloat(skelX, 8, curveMidX);		xsArraySetFloat(skelZ, 8, armSouthZ-16.0);
	xsArraySetFloat(skelX, 9, eastX);			xsArraySetFloat(skelZ, 9, armSouthZ-32.0);
	int skelCount = 10;

	// ... resampled every 4 m
	int sampleX = xsArrayCreateFloat(700, 0.0, "river sample x");
	int sampleZ = xsArrayCreateFloat(700, 0.0, "river sample z");
	int samples = 0;
	float segX0 = 0.0;
	float segZ0 = 0.0;
	float segDX = 0.0;
	float segDZ = 0.0;
	float segPos = 0.0;
	for (sk=0; < skelCount-1) {
		segX0 = xsArrayGetFloat(skelX, sk);
		segZ0 = xsArrayGetFloat(skelZ, sk);
		segDX = xsArrayGetFloat(skelX, sk+1) - segX0;
		segDZ = xsArrayGetFloat(skelZ, sk+1) - segZ0;
		int segSteps = sqrt(segDX*segDX + segDZ*segDZ) / 4.0 + 0.5;
		float segStepsF = segSteps;
		segPos = 0.0;
		for (st=0; < segSteps) {
			xsArraySetFloat(sampleX, samples, segX0 + segDX*segPos);
			xsArraySetFloat(sampleZ, samples, segZ0 + segDZ*segPos);
			samples = samples + 1;
			segPos = segPos + 1.0/segStepsF;
		}
	}
	xsArraySetFloat(sampleX, samples, xsArrayGetFloat(skelX, skelCount-1));
	xsArraySetFloat(sampleZ, samples, xsArrayGetFloat(skelZ, skelCount-1));
	samples = samples + 1;

	// 2. the centreline: a moving average over +-7 samples, the ends extended straight
	int centreX = xsArrayCreateFloat(600, 0.0, "river centre x");
	int centreZ = xsArrayCreateFloat(600, 0.0, "river centre z");
	float firstX = xsArrayGetFloat(sampleX, 0);
	float firstZ = xsArrayGetFloat(sampleZ, 0);
	float firstDX = xsArrayGetFloat(sampleX, 1) - firstX;
	float firstDZ = xsArrayGetFloat(sampleZ, 1) - firstZ;
	float lastX = xsArrayGetFloat(sampleX, samples-1);
	float lastZ = xsArrayGetFloat(sampleZ, samples-1);
	float lastDX = lastX - xsArrayGetFloat(sampleX, samples-2);
	float lastDZ = lastZ - xsArrayGetFloat(sampleZ, samples-2);
	float sumX = 0.0;
	float sumZ = 0.0;
	float beyond = 0.0;
	for (cs=0; < samples) {
		sumX = 0.0;
		sumZ = 0.0;
		for (nb=0; <= 14) {
			int nbIdx = cs + nb - 7;
			if (nbIdx < 0) {
				beyond = nbIdx;
				sumX = sumX + firstX + firstDX*beyond;
				sumZ = sumZ + firstZ + firstDZ*beyond;
			}
			else if (nbIdx >= samples) {
				beyond = nbIdx - samples + 1;
				sumX = sumX + lastX + lastDX*beyond;
				sumZ = sumZ + lastZ + lastDZ*beyond;
			}
			else {
				sumX = sumX + xsArrayGetFloat(sampleX, nbIdx);
				sumZ = sumZ + xsArrayGetFloat(sampleZ, nbIdx);
			}
		}
		xsArraySetFloat(centreX, cs, sumX / 15.0);
		xsArraySetFloat(centreZ, cs, sumZ / 15.0);
	}

	// arc length along the centreline
	int centreS = xsArrayCreateFloat(600, 0.0, "river centre s");
	float arcDX = 0.0;
	float arcDZ = 0.0;
	for (ca=1; < samples) {
		arcDX = xsArrayGetFloat(centreX, ca) - xsArrayGetFloat(centreX, ca-1);
		arcDZ = xsArrayGetFloat(centreZ, ca) - xsArrayGetFloat(centreZ, ca-1);
		xsArraySetFloat(centreS, ca, xsArrayGetFloat(centreS, ca-1) + sqrt(arcDX*arcDX + arcDZ*arcDZ));
	}

	// 3. the meander keypoints (s along the centreline, offset outward): east edge, inner socket, outer socket on the
	// north arm (walking west), the apex, then the same three mirrored on the south arm (walking east)
	int halfIdx = samples / 2;
	int keyS = xsArrayCreateFloat(7, 0.0, "meander key s");
	int keyO = xsArrayCreateFloat(7, 0.0, "meander key offset");
	int keyArmX = xsArrayCreateFloat(3, 0.0, "meander key x");
	int keyArmO = xsArrayCreateFloat(3, 0.0, "meander key arm offset");
	xsArraySetFloat(keyArmX, 0, centreM+0.42*sizeM);	xsArraySetFloat(keyArmO, 0, 0.0-meanderEdge);
	xsArraySetFloat(keyArmX, 1, centreM+0.20*sizeM);	xsArraySetFloat(keyArmO, 1, meanderA);			// inner socket
	xsArraySetFloat(keyArmX, 2, centreM-0.03*sizeM);	xsArraySetFloat(keyArmO, 2, 0.0-meanderA);		// outer socket
	int keyFound = -1;
	float keyXM = 0.0;
	for (kn=0; < 3) {
		keyXM = xsArrayGetFloat(keyArmX, kn);
		keyFound = -1;
		for (ki=0; < samples) {
			if (keyFound < 0 && ki < halfIdx && xsArrayGetFloat(centreX, ki) <= keyXM)
				keyFound = ki;
		}
		xsArraySetFloat(keyS, kn, xsArrayGetFloat(centreS, keyFound));
		xsArraySetFloat(keyO, kn, xsArrayGetFloat(keyArmO, kn));
		keyFound = -1;
		for (kj=0; < samples) {
			if (keyFound < 0 && kj >= halfIdx && xsArrayGetFloat(centreX, kj) >= keyXM)
				keyFound = kj;
		}
		xsArraySetFloat(keyS, 6-kn, xsArrayGetFloat(centreS, keyFound));
		xsArraySetFloat(keyO, 6-kn, xsArrayGetFloat(keyArmO, kn));
	}
	float apexS = xsArrayGetFloat(centreS, halfIdx);
	xsArraySetFloat(keyS, 3, apexS);
	xsArraySetFloat(keyO, 3, meanderBend);

	// 4. the discs: every second sample, centred on the centreline moved by the eased offset along its outward
	// (right-hand) normal
	float hereS = 0.0;
	float chOff = 0.0;
	float chU = 0.0;
	float keyS0 = 0.0;
	float keyS1 = 0.0;
	float keyO0 = 0.0;
	float keyO1 = 0.0;
	float tanX = 0.0;
	float tanZ = 0.0;
	float tanL = 0.0;
	float discXM = 0.0;
	float discZM = 0.0;
	float discR = 0.0;
	float apexU = 0.0;
	int discCount = samples / 2;
	for (dk=0; <= discCount) {
		int cd = 2*dk;
		if (cd < samples) {
			hereS = xsArrayGetFloat(centreS, cd);
			chOff = xsArrayGetFloat(keyO, 0);
			if (hereS >= xsArrayGetFloat(keyS, 6))
				chOff = xsArrayGetFloat(keyO, 6);
			for (kk=0; < 6) {
				keyS0 = xsArrayGetFloat(keyS, kk);
				keyS1 = xsArrayGetFloat(keyS, kk+1);
				if (hereS > keyS0 && hereS <= keyS1) {
					keyO0 = xsArrayGetFloat(keyO, kk);
					keyO1 = xsArrayGetFloat(keyO, kk+1);
					chU = (hereS - keyS0) / (keyS1 - keyS0);
					chOff = keyO0 + (keyO1 - keyO0) * chU * chU * (3.0 - 2.0*chU);
				}
			}
			int cdPrev = cd - 1;
			if (cdPrev < 0)
				cdPrev = 0;
			int cdNext = cd + 1;
			if (cdNext > samples - 1)
				cdNext = samples - 1;
			tanX = xsArrayGetFloat(centreX, cdNext) - xsArrayGetFloat(centreX, cdPrev);
			tanZ = xsArrayGetFloat(centreZ, cdNext) - xsArrayGetFloat(centreZ, cdPrev);
			tanL = sqrt(tanX*tanX + tanZ*tanZ);
			discXM = xsArrayGetFloat(centreX, cd) + chOff*tanZ/tanL;
			discZM = xsArrayGetFloat(centreZ, cd) - chOff*tanX/tanL;
			// wider round the apex: +4 m easing out over 140 m either side
			apexU = abs(hereS - apexS) / 140.0;
			if (apexU > 1.0)
				apexU = 1.0;
			discR = channelR + channelBendR * (1.0 - apexU*apexU*(3.0 - 2.0*apexU));
			int discTiles = 3.14159 * discR * discR / 4.0;
			int channelID = rmCreateArea("river channel "+cd);
			rmSetAreaSize(channelID, rmAreaTilesToFraction(discTiles), rmAreaTilesToFraction(discTiles));
			rmSetAreaLocation(channelID, rmXMetersToFraction(discXM), rmZMetersToFraction(discZM));
			rmSetAreaCoherence(channelID, 1.0);
			rmSetAreaObeyWorldCircleConstraint(channelID, false);
			rmSetAreaWarnFailure(channelID, false);
			rmAddAreaToClass(channelID, classChannel);
			rmBuildArea(channelID);
		}
	}

	// the water under each bridge: a channel disc centred on the deck
	int bridgeTiles = 3.14159 * channelR * channelR / 4.0;
	for (bw=1; <= 2) {
		int bridgeWaterID = rmCreateArea("river under bridge "+bw);
		rmSetAreaSize(bridgeWaterID, rmAreaTilesToFraction(bridgeTiles), rmAreaTilesToFraction(bridgeTiles));
		if (bw == 1)
			rmSetAreaLocation(bridgeWaterID, rmXMetersToFraction(bridgeX), rmZMetersToFraction(armNorthZ));
		if (bw == 2)
			rmSetAreaLocation(bridgeWaterID, rmXMetersToFraction(bridgeX), rmZMetersToFraction(armSouthZ));
		rmSetAreaCoherence(bridgeWaterID, 1.0);
		rmSetAreaObeyWorldCircleConstraint(bridgeWaterID, false);
		rmSetAreaWarnFailure(bridgeWaterID, false);
		rmAddAreaToClass(bridgeWaterID, classChannel);
		rmBuildArea(bridgeWaterID);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	// ********************* The shores *******************************

	// Land avoids the channel: the water left over is the river, its banks 40 m from the centreline, never nearer a
	// river route than 30 m (the channel's geometry above). The short route distance is v7's safety (about 15 m); the
	// land route is not built yet, so it carves nothing
	int avoidRiver = rmCreateClassDistanceConstraint("shores avoid the river channel", classChannel, 4.0);
	int shoreAvoidRoute = rmCreateTradeRouteDistanceConstraint("shores keep the river route clear", 7.0);

	int northShoreID = rmCreateArea("north outer shore");
	rmSetAreaSize(northShoreID, 0.5, 0.5);
	rmSetAreaLocation(northShoreID, 0.5, rmZMetersToFraction(sizeM-24.0));
	rmSetAreaBaseHeight(northShoreID, landHeight);
	rmSetAreaMix(northShoreID, "italy_grass_lush");
	rmSetAreaCoherence(northShoreID, 1.0);
	rmSetAreaSmoothDistance(northShoreID, 4);
	rmSetAreaHeightBlend(northShoreID, 2);
	rmSetAreaObeyWorldCircleConstraint(northShoreID, false);
	rmSetAreaWarnFailure(northShoreID, false);
	rmAddAreaConstraint(northShoreID, avoidRiver);
	rmAddAreaConstraint(northShoreID, shoreAvoidRoute);
	rmAddAreaToClass(northShoreID, classLand);
	rmBuildArea(northShoreID);

	int southShoreID = rmCreateArea("south outer shore");
	rmSetAreaSize(southShoreID, 0.5, 0.5);
	rmSetAreaLocation(southShoreID, 0.5, rmZMetersToFraction(24.0));
	rmSetAreaBaseHeight(southShoreID, landHeight);
	rmSetAreaMix(southShoreID, "italy_grass_lush");
	rmSetAreaCoherence(southShoreID, 1.0);
	rmSetAreaSmoothDistance(southShoreID, 4);
	rmSetAreaHeightBlend(southShoreID, 2);
	rmSetAreaObeyWorldCircleConstraint(southShoreID, false);
	rmSetAreaWarnFailure(southShoreID, false);
	rmAddAreaConstraint(southShoreID, avoidRiver);
	rmAddAreaConstraint(southShoreID, shoreAvoidRoute);
	rmAddAreaToClass(southShoreID, classLand);
	rmBuildArea(southShoreID);

	int westShoreID = rmCreateArea("west outer shore");
	rmSetAreaSize(westShoreID, 0.3, 0.3);
	rmSetAreaLocation(westShoreID, rmXMetersToFraction(24.0), 0.5);
	rmSetAreaBaseHeight(westShoreID, landHeight);
	rmSetAreaMix(westShoreID, "italy_grass_lush");
	rmSetAreaCoherence(westShoreID, 1.0);
	rmSetAreaSmoothDistance(westShoreID, 4);
	rmSetAreaHeightBlend(westShoreID, 2);
	rmSetAreaObeyWorldCircleConstraint(westShoreID, false);
	rmSetAreaWarnFailure(westShoreID, false);
	rmAddAreaConstraint(westShoreID, avoidRiver);
	rmAddAreaConstraint(westShoreID, shoreAvoidRoute);
	rmAddAreaToClass(westShoreID, classLand);
	rmBuildArea(westShoreID);

	int innerShoreID = rmCreateArea("inner shore");
	rmSetAreaSize(innerShoreID, 0.4, 0.4);
	rmSetAreaLocation(innerShoreID, rmXMetersToFraction(centreM+0.3*sizeM), 0.5);
	rmSetAreaBaseHeight(innerShoreID, landHeight);
	rmSetAreaMix(innerShoreID, "italy_grass_lush");
	rmSetAreaCoherence(innerShoreID, 1.0);
	rmSetAreaSmoothDistance(innerShoreID, 4);
	rmSetAreaHeightBlend(innerShoreID, 2);
	rmSetAreaObeyWorldCircleConstraint(innerShoreID, false);
	rmSetAreaWarnFailure(innerShoreID, false);
	rmAddAreaConstraint(innerShoreID, avoidRiver);
	rmAddAreaConstraint(innerShoreID, shoreAvoidRoute);
	rmAddAreaToClass(innerShoreID, classLand);
	rmBuildArea(innerShoreID);

	int inInnerShore = rmCreateAreaConstraint("in the inner shore", innerShoreID);
	int avoidInnerShore = rmCreateAreaDistanceConstraint("avoid the inner shore", innerShoreID, 10.0);

	// ************************** The land route built **************************

	// Built now: after the shores (built on the water base before them, the shores would paint over it and their route
	// distance would cut a channel along it) and BEFORE the bridges, which go onto the finished road (Florence 477 / 522,
	// London 743 / 810, Paris 350 / 413: every repo map builds its land routes before its bridges). v9 built it after the
	// bridges and broke them (owner 2026-10-07); mapcheck S8 and test_build_order.py pin the order
	rmBuildTradeRoute(landRouteID, "dirt");

	// ********************* Bridges: on the built land route, into open water *******************************

	// A bridge grouping carries its own island (a raised block in a water ring): placed into land it stands on a
	// pedestal (probe generations 2-6), so each goes into the open water the channel and its bridge disc keep 40 m round
	// the crossing - the shores never claim it. Both arm bridges stand on the land route, where it crosses the arms
	// (Florence: zpflorence.xs 477 road, 518-522 bridge); the docks follow
	int bridgeNorthID = rmCreateGrouping("bridge north", "Bridge_Universal_03");
	rmSetGroupingMinDistance(bridgeNorthID, 0.0);
	rmSetGroupingMaxDistance(bridgeNorthID, 0.0);
	rmAddGroupingToClass(bridgeNorthID, rmClassID("classBridge"));
	rmPlaceGroupingAtLoc(bridgeNorthID, 0, rmXMetersToFraction(bridgeX), rmZMetersToFraction(armNorthZ), 1);

	int bridgeSouthID = rmCreateGrouping("bridge south", "Bridge_Universal_03");
	rmSetGroupingMinDistance(bridgeSouthID, 0.0);
	rmSetGroupingMaxDistance(bridgeSouthID, 0.0);
	rmAddGroupingToClass(bridgeSouthID, rmClassID("classBridge"));
	rmPlaceGroupingAtLoc(bridgeSouthID, 0, rmXMetersToFraction(bridgeX), rmZMetersToFraction(armSouthZ), 1);

	// Bridge docks (zpelbe.xs 523-549): 300 tiles at each end of every bridge, about 16 m beyond the end of the
	// bridge block, so each dock overlaps the deck end and reaches into the shore; with the Elbe's cliff edge in the
	// river's own cliff type, as on the probe's north bridge (generation 6)
	for (b=1; <= 4) {
		int bridgeDockID = rmCreateArea("bridge dock "+b);
		rmSetAreaSize(bridgeDockID, rmAreaTilesToFraction(300), rmAreaTilesToFraction(300));
		if (b == 1)
			rmSetAreaLocation(bridgeDockID, rmXMetersToFraction(bridgeX-1.0), rmZMetersToFraction(armNorthZ+36.0));
		if (b == 2)
			rmSetAreaLocation(bridgeDockID, rmXMetersToFraction(bridgeX-1.0), rmZMetersToFraction(armNorthZ-36.0));
		if (b == 3)
			rmSetAreaLocation(bridgeDockID, rmXMetersToFraction(bridgeX-1.0), rmZMetersToFraction(armSouthZ+36.0));
		if (b == 4)
			rmSetAreaLocation(bridgeDockID, rmXMetersToFraction(bridgeX-1.0), rmZMetersToFraction(armSouthZ-36.0));
		rmSetAreaCoherence(bridgeDockID, 1.0);
		// at the land height, which is the bridge's (landHeight above; owner 2026-10-07: docks below the bridge "look
		// creepy")
		rmSetAreaBaseHeight(bridgeDockID, landHeight);
		rmSetAreaMix(bridgeDockID, "italy_grass_lush");
		rmSetAreaCliffType(bridgeDockID, "Italian Cliff River");
		rmSetAreaCliffEdge(bridgeDockID, 1, 1.0, 0.1, 1.0, 0);
		rmSetAreaCliffHeight(bridgeDockID, 0, 0.0, 1.0);
		// the top keeps the area's mix, the map's base mix (owner 2026-10-07: "cliffs on their own don't support terrain
		// mix ... paint the area with the base mix, only the area on top of the cliff"): the cliff paints its sides,
		// not its ground - the elector plateaus' painting (above)
		rmSetAreaCliffPainting(bridgeDockID, false, true, true, 1.5, true);
		rmAddAreaToClass(bridgeDockID, classLand);
		rmAddAreaToClass(bridgeDockID, rmClassID("classBridge"));
		rmSetAreaObeyWorldCircleConstraint(bridgeDockID, false);
		rmBuildArea(bridgeDockID);
	}

	// ************************** Trade sockets measured from the routes **************************

	// River sockets (owner 2026-10-06): each stands socketDist m from its own route's authored line, along the route's
	// normal, on the bank the channel swings away from: on each arm one on the outer bank west of the bridge (that team's) and one on the inner bank east of it
	// (contested), 18 m off the route on a harbour port site pushed out from the bank; one off the tip of the inner
	// shore at the bend apex, on the mirror axis, 18 m off too (16 m before the owner's "harbours - 1 tile back from
	// trade route always - including the land beneath them", 2026-10-07). Each is linked to the route
	// it is measured from (classic SocketTradeRoute); a small invisible area round each (class harbour) keeps hills,
	// patches, forests and fish off it.
	int numSockets = 5;
	int sockX = xsArrayCreateFloat(5, 0.0, "socket spot x");
	int sockZ = xsArrayCreateFloat(5, 0.0, "socket spot z");
	int sockRoute = xsArrayCreateInt(5, -1, "socket route");
	int sockSide = xsArrayCreateFloat(5, 0.0, "socket side");			// +1 outward, -1 inward (the inner shore)
	int sockDist = xsArrayCreateFloat(5, 18.0, "socket distance");
	int sockNorth = xsArrayCreateFloat(5, 1.0, "outward = +z on this arm");		// -1 on the south arm
	xsArraySetFloat(sockNorth, 1, -1.0);
	xsArraySetFloat(sockNorth, 3, -1.0);
	xsArraySetFloat(sockX, 0, centreM-0.03*sizeM);	xsArraySetFloat(sockZ, 0, armNorthZ);	xsArraySetInt(sockRoute, 0, tradeRoute2ID);	xsArraySetFloat(sockSide, 0, 1.0);
	xsArraySetFloat(sockX, 1, centreM-0.03*sizeM);	xsArraySetFloat(sockZ, 1, armSouthZ);	xsArraySetInt(sockRoute, 1, tradeRoute2ID);	xsArraySetFloat(sockSide, 1, 1.0);
	xsArraySetFloat(sockX, 2, centreM+0.20*sizeM);	xsArraySetFloat(sockZ, 2, armNorthZ);	xsArraySetInt(sockRoute, 2, tradeRouteID);	xsArraySetFloat(sockSide, 2, -1.0);
	xsArraySetFloat(sockX, 3, centreM+0.20*sizeM);	xsArraySetFloat(sockZ, 3, armSouthZ);	xsArraySetInt(sockRoute, 3, tradeRoute3ID);	xsArraySetFloat(sockSide, 3, -1.0);
	xsArraySetFloat(sockX, 4, apexX);	xsArraySetFloat(sockZ, 4, centreM);	xsArraySetInt(sockRoute, 4, tradeRoute2ID);	xsArraySetFloat(sockSide, 4, -1.0);	xsArraySetFloat(sockDist, 4, 18.0);

	float socketXM = 0.0;
	float socketZM = 0.0;
	float harbourLandX = 0.0;
	float harbourLandZ = 0.0;
	int harbourIslandAvoidRoutes = rmCreateTradeRouteDistanceConstraint("harbour sites keep off the routes", 4.0);	// from the 16 m road's edge: 12 m off the line (10 m before the tile back)
	for (sn=0; < numSockets) {
		// on the straight arms and the west leg the route's normal is an axis: the spot is the route point plus
		// socketDist along it (no read-back, the authored line)
		if (sn <= 3) {
			socketXM = xsArrayGetFloat(sockX, sn);
			socketZM = xsArrayGetFloat(sockZ, sn) + xsArrayGetFloat(sockDist, sn) * xsArrayGetFloat(sockSide, sn) * xsArrayGetFloat(sockNorth, sn);
		}
		else {
			socketXM = xsArrayGetFloat(sockX, sn) + xsArrayGetFloat(sockDist, sn);
			socketZM = xsArrayGetFloat(sockZ, sn);
		}

		// The harbour: the PORT-SITE pattern of the mod's harbour maps (zpaustralia.xs 454-526, zpnewguinea.xs 688-720,
		// zptorresstrait.xs 237-300, zpBalearicIslands.xs 703-810): a 400-tile site of land under the harbour, set back
		// from the route point, the harbour grouping between it and the route. Owner 2026-10-07 / 08: "on a tiny island
		// beneath and closer to the trade route ... bigger islands connected with mainland ... simpler, no prolonged molo
		// ... the sockets too far from the trade route". The site is a circle about 22.6 m round, centred 35.6 m off the
		// route line, so it pushes out to 13 m off the line (route constraints count from the 16 m road's edge, 8 m out)
		// and joins the bank (28-31 m off at the arms, 34-36 m at the tip), built like the banks (no cliff, smooth 4);
		// the harbour on it as ONE grouping with its socket (owner 2026-10-07: "why don't we simply have one grouping
		// together with the socket - standard sockets work in groupings, only capturable ones don't"; Caribbean Wars'
		// Harbour_Center_* carry theirs): the owner's "Harbour center - platform unit", the socket 18 m off the line as
		// the grouping's origin, three platforms in front, turned to face the route (Harbour_River_<NW|SE|SW>: the harbour groupings' naming, the
		// suffix the water side in SCREEN terms - NW faces world north, SE south, SW west, NE east)
		harbourLandX = 0.0;
		harbourLandZ = 0.0;
		if (sn <= 3)
			harbourLandZ = xsArrayGetFloat(sockSide, sn) * xsArrayGetFloat(sockNorth, sn);
		else
			harbourLandX = 1.0;
		int harbourIslandID = rmCreateArea("harbour port site "+sn);
		rmSetAreaSize(harbourIslandID, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
		rmSetAreaLocation(harbourIslandID, rmXMetersToFraction(socketXM + 17.6*harbourLandX), rmZMetersToFraction(socketZM + 17.6*harbourLandZ));
		rmSetAreaCoherence(harbourIslandID, 1.0);
		rmSetAreaBaseHeight(harbourIslandID, landHeight);
		rmSetAreaMix(harbourIslandID, "italy_grass_lush");
		rmSetAreaSmoothDistance(harbourIslandID, 4);
		rmSetAreaHeightBlend(harbourIslandID, 2);
		rmAddAreaToClass(harbourIslandID, classLand);
		rmAddAreaConstraint(harbourIslandID, harbourIslandAvoidRoutes);
		rmSetAreaWarnFailure(harbourIslandID, false);
		rmBuildArea(harbourIslandID);

		int harbourID = -1;
		if (harbourLandZ > 0.5)
			harbourID = rmCreateGrouping("harbour "+sn, "Harbour_River_SE");
		else if (harbourLandZ < -0.5)
			harbourID = rmCreateGrouping("harbour "+sn, "Harbour_River_NW");
		else
			harbourID = rmCreateGrouping("harbour "+sn, "Harbour_River_SW");
		rmSetGroupingMinDistance(harbourID, 0.0);
		rmSetGroupingMaxDistance(harbourID, 0.0);
		rmPlaceGroupingAtLoc(harbourID, 0, rmXMetersToFraction(socketXM), rmZMetersToFraction(socketZM), 1);

		int socketPadID = rmCreateArea("socket pad "+sn);
		rmSetAreaSize(socketPadID, rmAreaTilesToFraction(113), rmAreaTilesToFraction(113));
		rmSetAreaLocation(socketPadID, rmXMetersToFraction(socketXM), rmZMetersToFraction(socketZM));
		rmSetAreaCoherence(socketPadID, 1.0);
		rmSetAreaWarnFailure(socketPadID, false);
		rmAddAreaToClass(socketPadID, rmClassID("harbour"));
		rmBuildArea(socketPadID);
	}

	// Land route sockets (owner 2026-10-06: "south, north, middle - between the Elector palaces"): docked ON the built
	// route at its own points (London's countryside sockets, zplondon.xs 2016-2026: rmPlaceObjectDefAtPoint at
	// rmGetTradeRouteWayPoint, min 2 / max 8 m). The middle one at 0.5 - the route is mirror-symmetric, so its midpoint
	// is the inner shore's centre between the castles; the north and south ones halfway along the leg beyond each
	// bridge, mirrored (fractions from the asked waypoints' lengths)
	float landLen01 = sqrt((landX1-landX2)*(landX1-landX2) + (landZS1-8.0)*(landZS1-8.0));
	float landLen12 = sqrt((bridgeX-landX1)*(bridgeX-landX1) + (landZS0-landZS1)*(landZS0-landZS1));
	float landLen23 = landZN0 - landZS0;
	float landLen34 = sqrt((landX1-bridgeX)*(landX1-bridgeX) + (landZN1-landZN0)*(landZN1-landZN0));
	float landLen45 = sqrt((landX2-landX1)*(landX2-landX1) + (sizeM-8.0-landZN1)*(sizeM-8.0-landZN1));
	float landLen = landLen01 + landLen12 + landLen23 + landLen34 + landLen45;
	float landFracN = (landLen01 + landLen12 + landLen23 + 0.5*landLen34) / landLen;
	int landSocketID = rmCreateObjectDef("land route sockets");
	rmSetObjectDefTradeRouteID(landSocketID, landRouteID);
	rmAddObjectDefItem(landSocketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(landSocketID, true);
	rmSetObjectDefMinDistance(landSocketID, 2.0);
	rmSetObjectDefMaxDistance(landSocketID, 8.0);
	rmPlaceObjectDefAtPoint(landSocketID, 0, rmGetTradeRouteWayPoint(landRouteID, 1.0-landFracN));		// south
	rmPlaceObjectDefAtPoint(landSocketID, 0, rmGetTradeRouteWayPoint(landRouteID, 0.5));				// middle
	rmPlaceObjectDefAtPoint(landSocketID, 0, rmGetTradeRouteWayPoint(landRouteID, landFracN));			// north

	// ************************** Hills: elevation on the shores **************************

	// The Elbe's hills (zpelbe.xs 609-649): the same land again with turbulence, kept 12 m from the water, so the banks,
	// the bridge docks and the sockets stay flat at the land height
	int hillsAvoidWater = rmCreateTerrainDistanceConstraint("hills avoid water", "Land", false, 12.0);
	int hillsAvoidBridge = rmCreateClassDistanceConstraint("hills avoid bridges", rmClassID("classBridge"), 20.0);
	int hillsAvoidHarbour = rmCreateClassDistanceConstraint("hills avoid the sockets", rmClassID("harbour"), 15.0);
	for (hl=1; <= 4) {
		int hillsID = rmCreateArea("hills "+hl);
		rmSetAreaMix(hillsID, "italy_grass_lush");
		rmSetAreaSize(hillsID, 0.4, 0.4);
		rmSetAreaCoherence(hillsID, 1.0);
		rmSetAreaBaseHeight(hillsID, landHeight);
		rmSetAreaHeightBlend(hillsID, 2);
		rmSetAreaSmoothDistance(hillsID, 20);
		rmSetAreaObeyWorldCircleConstraint(hillsID, false);
		rmSetAreaWarnFailure(hillsID, false);
		rmAddAreaConstraint(hillsID, hillsAvoidWater);
		rmAddAreaConstraint(hillsID, hillsAvoidBridge);
		rmAddAreaConstraint(hillsID, hillsAvoidHarbour);
		rmSetAreaElevationVariation(hillsID, 5.0);
		rmSetAreaElevationType(hillsID, cElevTurbulence);
		rmSetAreaElevationMinFrequency(hillsID, 0.09);
		rmSetAreaElevationOctaves(hillsID, 3);
		rmSetAreaElevationPersistence(hillsID, 0.2);
		rmSetAreaElevationNoiseBias(hillsID, 1);
		if (hl == 1)
			rmSetAreaLocation(hillsID, 0.5, rmZMetersToFraction(sizeM-24.0));
		if (hl == 2)
			rmSetAreaLocation(hillsID, 0.5, rmZMetersToFraction(24.0));
		if (hl == 3)
			rmSetAreaLocation(hillsID, rmXMetersToFraction(24.0), 0.5);
		if (hl == 4)
			rmSetAreaLocation(hillsID, rmXMetersToFraction(centreM+0.3*sizeM), 0.5);
		rmBuildArea(hillsID);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// ************************** Prince Electors on the inner shore **************************

	// Two castles on cliff plateaus on the inner shore, on the mirror axis, so each team's bridge is the same distance
	// from them: Bavaria and Austria, the Danube's electors, at every map size (owner 2026-10-07: "Electors - always two
	// on map"; Bohemia, Saxony and Brandenburg do not belong here). Elbe recipe (zpelbe.xs 720-776): a plateau at 5.0
	// with two cliff segments, the castle grouping on it, and a marker the triggers address
	int numElectors = 2;
	int electorX = xsArrayCreateFloat(2, 0.0, "Elector X");
	int electorZ = xsArrayCreateFloat(2, 0.0, "Elector Z");
	int electorGrouping = xsArrayCreateString(2, "", "Elector Groupings");
	xsArraySetString(electorGrouping, 0, "Elector_Bavaria_02");
	xsArraySetString(electorGrouping, 1, "Elector_Austria_02");
	xsArraySetFloat(electorX, 0, centreM-0.02*sizeM);
	xsArraySetFloat(electorZ, 0, centreM);
	xsArraySetFloat(electorX, 1, centreM+0.24*sizeM);
	xsArraySetFloat(electorZ, 1, centreM);

	// Castle markers: plain units, so rmGetUnitPlaced is their trigger index (nugget-targeting Rule 0)
	int castleSockets = xsArrayCreateInt(2, -1, "Castle Sockets");
	int castleSocketID = -1;

	for (e=0; < numElectors) {
		float electorXM = xsArrayGetFloat(electorX, e);
		float electorZM = xsArrayGetFloat(electorZ, e);

		int electorPlateauID = rmCreateArea("elector plateau "+e);
		rmSetAreaSize(electorPlateauID, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));
		rmSetAreaLocation(electorPlateauID, rmXMetersToFraction(electorXM), rmZMetersToFraction(electorZM));
		rmSetAreaCoherence(electorPlateauID, 0.8);
		rmSetAreaSmoothDistance(electorPlateauID, 5);
		rmSetAreaBaseHeight(electorPlateauID, landHeight+2.0);		// 5.0 on the land of 2.983 before
		rmSetAreaCliffType(electorPlateauID, "Italian Cliff Grassy");
		rmSetAreaCliffEdge(electorPlateauID, 2, 0.40, 0.0, 0.0, 2);
		rmSetAreaCliffHeight(electorPlateauID, 2.0, 0.0, 0.5);
		rmSetAreaElevationVariation(electorPlateauID, 0.0);
		rmSetAreaCliffPainting(electorPlateauID, false, true, true, 1.5, true);
		rmAddAreaToClass(electorPlateauID, rmClassID("natives"));
		rmBuildArea(electorPlateauID);

		int electorCastleID = rmCreateGrouping("elector castle "+e, xsArrayGetString(electorGrouping, e));
		rmAddGroupingToClass(electorCastleID, rmClassID("natives"));
		rmPlaceGroupingAtLoc(electorCastleID, 0, rmXMetersToFraction(electorXM), rmZMetersToFraction(electorZM), 1);

		int electorMarkerID = rmCreateObjectDef("elector marker "+e);
		rmAddObjectDefItem(electorMarkerID, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefAllowOverlap(electorMarkerID, true);
		rmSetObjectDefMinDistance(electorMarkerID, 0.0);
		rmSetObjectDefMaxDistance(electorMarkerID, 0.0);
		rmPlaceObjectDefAtLoc(electorMarkerID, 0, rmXMetersToFraction(electorXM), rmZMetersToFraction(electorZM));
		xsArraySetInt(castleSockets, e, rmGetUnitPlaced(electorMarkerID, 0));
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// ************************* Players around the bend *****************************

	// Two modes (owner 2026-10-06 / 07). TWO TEAMS, any split from 1v1 to 1v7: each team on its own section of the
	// half-moon (circle fractions clockwise from north, 0.53-0.97, never beyond the land route), every player the same
	// slot width, the sections sized by the team counts, and a gap of 0.14 between the teams (owner 2026-10-07: "edge
	// player has all the resources and middle players are just cannon fodder ... teams further from each other ... gap
	// between two teams is necessary"). The Jesuit cathedral stands at the gap's centre, so it moves with the split
	// (on the apex axis for equal teams, beside the lone player's section at 1v7). Which team takes the north is
	// random. Everything else - FFA, 3 or 4 teams - one half-moon with even gaps (Dead Sea, zpdeadsea.xs 237-257).
	float arcStart = 0.53;
	float arcEnd = 0.97;
	float teamGap = 0.14;
	float jesuitFrac = -1.0;			// the cathedral's circle fraction; < 0 = no 2-team layout, no cathedral
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
	int northTeam = 0;
	int northCount = teamZeroCount;
	int southCount = teamOneCount;
	float slotWidth = 0.0;
	float southEnd = 0.0;
	float northBegin = 0.0;
	float southSecEnd = 0.0;
	float northSecEnd = 0.0;
	if (cNumberTeams == 2)
	{
		if (rmRandFloat(0.0, 1.0) > 0.5) {
			northTeam = 1;
			northCount = teamOneCount;
			southCount = teamZeroCount;
		}
		slotWidth = (arcEnd - arcStart - teamGap) / PlayerNum;
		southEnd = arcStart + slotWidth * southCount;
		northBegin = arcEnd - slotWidth * northCount;
		jesuitFrac = 0.5 * (southEnd + northBegin);
		// a section spreads its players end to end and a lone player stands at its START (mapsim, fitted on live
		// editor saves), so each section runs from its first slot centre to its last - and a lone player's keeps half
		// a slot of length: a section of no length places nobody (v12 editor saves of 1v1 and 2v1: no Town Centre for
		// the lone players; mapcheck S10)
		southSecEnd = southEnd - 0.5*slotWidth;
		if (southCount == 1)
			southSecEnd = southEnd;
		northSecEnd = arcEnd - 0.5*slotWidth;
		if (northCount == 1)
			northSecEnd = arcEnd;
		rmSetPlacementTeam(1 - northTeam);
		rmSetPlacementSection(arcStart + 0.5*slotWidth, southSecEnd);
		rmPlacePlayersCircular(0.41, 0.41, 0);
		rmSetPlacementTeam(northTeam);
		rmSetPlacementSection(northBegin + 0.5*slotWidth, northSecEnd);
		rmPlacePlayersCircular(0.41, 0.41, 0);
	}
	else
	{
		rmSetPlacementSection(arcStart, arcEnd);
		rmSetTeamSpacingModifier(1.0);
		rmPlacePlayersCircular(0.41, 0.41, 0);
	}

	// Players start in Malta's forts (owner 2026-10-07; zpmalta_castles.xs 829-859): a marker at the start, then the
	// malta_player_fort grouping on it - the Town Centre, an octagon of walls about 19 m round it with two gates and four
	// towers, a mine, berries and trees - and the starting units inside. Nomad starts keep the covered wagon. The marker
	// keeps the fort's walls off the water, the routes and the sockets (the margins below are the wall ring's)
	int tcAvoidRoutes = rmCreateTradeRouteDistanceConstraint("forts keep off the routes", 30.0);
	int fortAvoidWater = rmCreateTerrainDistanceConstraint("forts keep off the water", "Land", false, 26.0);
	int fortAvoidSockets = rmCreateTypeDistanceConstraint("forts keep off the sockets", "SocketTradeRoute", 32.0);
	// the whole fort inside the world circle (owner 2026-10-07, a 1v1 game: one start had no fort at all). The edge
	// box above fences only the square's sides; a start in a world diagonal (the minimap's left, right, top or
	// bottom) stands near the circle, where the box does not reach (rm-objects-herds, map-edge constraints). The world
	// circle drops what lies beyond ~0.455 of the map (rm-coordinates), the fort's corners reach 19.4 m from its
	// centre, and a grouping that does not fit places nothing
	int fortInsideWorld = rmCreatePieConstraint("forts inside the world circle", 0.5, 0.5, 0.0, rmXFractionToMeters(0.455)-22.0, rmDegreesToRadians(0), rmDegreesToRadians(360));
	int TCID = rmCreateObjectDef("player fort marker");
	if (rmGetNomadStart())
	{
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
	}
	else{
		rmAddObjectDefItem(TCID, "zpSPCWaterSpawnPoint", 1, 0.0);
	}
	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, 20);
	rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, longPlayerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, farAvoidTradeSockets);
	rmAddObjectDefConstraint(TCID, avoidWater30);
	rmAddObjectDefConstraint(TCID, avoidTradeRoute);
	rmAddObjectDefConstraint(TCID, tcAvoidRoutes);
	rmAddObjectDefConstraint(TCID, avoidNatives);
	rmAddObjectDefConstraint(TCID, fortAvoidWater);
	rmAddObjectDefConstraint(TCID, fortAvoidSockets);
	rmAddObjectDefConstraint(TCID, fortInsideWorld);

	// Starting units on their own (owner 2026-10-07: "starting units must be placed separately"), INSIDE the fort as on
	// Malta ("explorer should spawn inside fort as on Malta"): Malta's own block, zpmalta_castles.xs 795-799 with its
	// constraints 167 / 183 - 8-12 m from the centre, avoid all 4 m, avoid impassable land 5 m. The map's own 6 m ones
	// on a 5-10 m ring left no spot inside the walls (v11, editor save dn11d_p6: no Explorer)
	int fortUnitsAvoidAll = rmCreateTypeDistanceConstraint("starting units avoid all", "all", 4.0);
	int fortUnitsAvoidImpassable = rmCreateTerrainDistanceConstraint("starting units avoid impassable land", "Land", false, 5.0);
	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 8.0);
	rmSetObjectDefMaxDistance(startingUnits, 12.0);
	rmAddObjectDefConstraint(startingUnits, fortUnitsAvoidAll);
	rmAddObjectDefConstraint(startingUnits, fortUnitsAvoidImpassable);

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "Deer", rmRandInt(7,10), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 28.0);		// outside the fort's walls
	rmSetObjectDefMaxDistance(playerDeerID, 40.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerDeerID, insideWorldRes);
	rmSetObjectDefCreateHerd(playerDeerID, true);
	rmAddObjectDefConstraint(playerDeerID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerDeerID, farAvoidTradeSockets);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetID, 28.0);		// outside the fort's walls
	rmSetObjectDefMaxDistance(playerNuggetID, 32.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerNuggetID, farAvoidTradeSockets);

	// Fake Frouping to fix the auto-grouping TC bug
	// (user 2026-09-24) RIGHT BEFORE the first player's start units / start grouping - it prevents the player-selection bug; water is fine (.claude/skills/rm-players)
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock");
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, rmXMetersToFraction(centreM+0.1*sizeM), 0.5);

	// 1. Every fort first, then (2.) what each start carries besides it: with one loop a player's start herd, placed
	// 28-40 m out, could stand in the next fort's walls 68 m away (4v4) and the next fort did not place at all (v12e
	// editor saves: the same two middle starts lost their forts in two of three 4v4 generations)
	int fortLocX = xsArrayCreateFloat(cNumberPlayers, 0.0, "fort x");
	int fortLocZ = xsArrayCreateFloat(cNumberPlayers, 0.0, "fort z");
	for(i=1; <cNumberPlayers) {

		// the marker, then the fort (its Town Centre, walls, towers, mine, berries and trees) on it
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));
		xsArraySetFloat(fortLocX, i, xsVectorGetX(TCLoc));
		xsArraySetFloat(fortLocZ, i, xsVectorGetZ(TCLoc));
		if (rmGetNomadStart() == false) {
			// a flat site beneath the fort first (owner 2026-10-07: "do the flattening for player castles manually
			// through a flat area beneath them" - no area flattener in the fort grouping, it cost the Explorer his spot):
			// on the shores' hills (+-5 m turbulence) a fort lost its Town Centre and most of its walls (v12 editor saves
			// 3v3, 4v3, 4v4). The elector plateau's size, smoothing and zero variation (above) without its cliff, at the
			// land height, about 29 m round the marker (the walls reach 19.4 m), kept 2 m off the water. The v12 pad
			// (500 tiles, smooth 10) stayed within 0.4 m of the land height out to 20 m, 0.8 m at 24 m
			int fortSiteID = rmCreateArea("fort site "+i);
			rmSetAreaSize(fortSiteID, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));
			rmSetAreaLocation(fortSiteID, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
			rmSetAreaCoherence(fortSiteID, 1.0);
			rmSetAreaBaseHeight(fortSiteID, landHeight);
			rmSetAreaSmoothDistance(fortSiteID, 5);
			rmSetAreaElevationVariation(fortSiteID, 0.0);
			rmAddAreaConstraint(fortSiteID, avoidWater10);
			rmSetAreaWarnFailure(fortSiteID, false);
			rmBuildArea(fortSiteID);
			// danube_player_fort = malta_player_fort with its six trees New England / Great Lakes oaks (owner
			// 2026-10-07: "same for player starting trees"); test_danube_layouts pins the rest equal to Malta's
			int playerFortID = rmCreateGrouping("player fort "+i, "danube_player_fort");
			rmPlaceGroupingAtLoc(playerFortID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)), 1);
		}
	}

	for(i=1; <cNumberPlayers) {
		float fortXF = rmXMetersToFraction(xsArrayGetFloat(fortLocX, i));
		float fortZF = rmZMetersToFraction(xsArrayGetFloat(fortLocZ, i));

		// Place resources
		rmPlaceObjectDefAtLoc(startingUnits, i, fortXF, fortZF);
		rmPlaceObjectDefAtLoc(playerDeerID, 0, fortXF, fortZF);

		// Place starting nugget
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, fortXF, fortZF);

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, fortXF, fortZF);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ************************** Hussites (north) and Orthodox (south): mirrored **************************

	// Owner 2026-10-06: player symmetry and few variants (Dead Sea, zpdeadsea.xs 493-680: fixed village spots and a short
	// search that keeps them off the Town Centres). The Hussite camps (flat, the Elbe's, zpelbe.xs 778-787) on the north
	// outer shore, the Orthodox monasteries (the Balkan variant, Orthodox_Monastery04-06, on the ground) at the mirrored
	// spots on the south. ONE set of spots per map size, chosen with mapsim against every player layout of that size
	// (scratchpad native_spots_v9.py): far from every start, off the water and the land route, apart from each other.
	// Each village may still move up to 25 m to keep 25 m off the water, 50 m off the Town Centres and 20 m off the
	// routes. Index sizeClass * 3 + j.
	int sizeClass = 0;
	if (PlayerNum >= 3)
		sizeClass = 1;
	if (PlayerNum >= 5)
		sizeClass = 2;
	if (PlayerNum >= 7)
		sizeClass = 3;
	// 1v1: one Hussite and one Orthodox settlement, at the north and south edges (owner 2026-10-07: the table's second
	// 1v1 pair stood 92 m apart across the axis, a Hussite camp right next to an Orthodox monastery)
	int nativeCount = 1;
	if (sizeClass >= 1)
		nativeCount = 2;
	if (sizeClass >= 2)
		nativeCount = 3;
	int nativeX = xsArrayCreateFloat(12, 0.5, "Native X");
	int nativeZ = xsArrayCreateFloat(12, 0.5, "Native Z");
	xsArraySetFloat(nativeX, 0, 0.590); xsArraySetFloat(nativeZ, 0, 0.926);
	xsArraySetFloat(nativeX, 1, 0.074); xsArraySetFloat(nativeZ, 1, 0.590);
	xsArraySetFloat(nativeX, 2, 0.500); xsArraySetFloat(nativeZ, 2, 0.961);
	xsArraySetFloat(nativeX, 3, 0.781); xsArraySetFloat(nativeZ, 3, 0.844);
	xsArraySetFloat(nativeX, 4, 0.587); xsArraySetFloat(nativeZ, 4, 0.934);
	xsArraySetFloat(nativeX, 5, 0.500); xsArraySetFloat(nativeZ, 5, 0.965);
	xsArraySetFloat(nativeX, 6, 0.803); xsArraySetFloat(nativeZ, 6, 0.834);
	xsArraySetFloat(nativeX, 7, 0.609); xsArraySetFloat(nativeZ, 7, 0.934);
	xsArraySetFloat(nativeX, 8, 0.528); xsArraySetFloat(nativeZ, 8, 0.809);
	xsArraySetFloat(nativeX, 9, 0.815); xsArraySetFloat(nativeZ, 9, 0.827);
	xsArraySetFloat(nativeX, 10, 0.605); xsArraySetFloat(nativeZ, 10, 0.940);
	xsArraySetFloat(nativeX, 11, 0.537); xsArraySetFloat(nativeZ, 11, 0.804);
	int nativeAvoidRoutes = rmCreateTradeRouteDistanceConstraint("natives keep off the routes", 20.0);

	int nativeIndex = -1;

	// Hussite settlements from the whole pool, no repeats (owner 2026-10-07: "go a bit wilder"): Hussite_Camp_01-03 are
	// King of Bohemia's Hussite castles (zpkingofbohemia.xs 514-524), 04-05 the camps. HussiteCamp_Hidden_N / _W bring
	// their own New England trees (a forest hideout) and stay out. A shuffle: slot h takes a random one of the rest
	int hussitePool = xsArrayCreateInt(5, 0, "Hussite variants");
	for (hv=0; < 5) {
		xsArraySetInt(hussitePool, hv, hv+1);
	}
	int hussitePick = -1;
	int hussiteSwap = -1;
	for (hv=0; < 4) {
		hussitePick = rmRandInt(hv, 4);
		hussiteSwap = xsArrayGetInt(hussitePool, hv);
		xsArraySetInt(hussitePool, hv, xsArrayGetInt(hussitePool, hussitePick));
		xsArraySetInt(hussitePool, hussitePick, hussiteSwap);
	}
	int hussiteCampType = -1;

	// FFA (and 3 or 4 teams, the same half-moon) have no gap for the Jesuit cathedral: there the Hussite / Orthodox
	// pair closest to the map centre are Jesuit cathedrals instead, on the same two spots (owner 2026-10-07: "so the
	// natives will be more various ... the one closer to map center can be Jesuit ... 1 Hussite, 2 Jesuit and 1
	// Orthodox - FFA only"). Two teams keep all of them and get one cathedral in their gap (below)
	int jesuitSwapIndex = -1;			// the swapped pair's index, -1 = no swap
	float swapBest = 9.0;
	float swapDX = 0.0;
	float swapDZ = 0.0;
	if (jesuitFrac < 0.0 && nativeCount >= 2) {
		for (sw=0; < nativeCount) {
			swapDX = xsArrayGetFloat(nativeX, sizeClass * 3 + sw) - 0.5;
			swapDZ = xsArrayGetFloat(nativeZ, sizeClass * 3 + sw) - 0.5;
			if (swapDX*swapDX + swapDZ*swapDZ < swapBest) {
				swapBest = swapDX*swapDX + swapDZ*swapDZ;
				jesuitSwapIndex = sw;
			}
		}
	}

	for (h=0; < nativeCount) {
		nativeIndex = sizeClass * 3 + h;
		hussiteCampType = xsArrayGetInt(hussitePool, h);
		int hussiteCampID = -1;
		if (jesuitSwapIndex == h)
			hussiteCampID = rmCreateGrouping("jesuit cathedral north", "Jesuit_Cathedral_EU_Flat_0"+rmRandInt(1, 3));
		else
			hussiteCampID = rmCreateGrouping("hussite camp "+h, "Hussite_Camp_0"+hussiteCampType);
		rmAddGroupingToClass(hussiteCampID, rmClassID("natives"));
		rmSetGroupingMinDistance(hussiteCampID, 0.0);
		rmSetGroupingMaxDistance(hussiteCampID, 25.0);
		rmAddGroupingConstraint(hussiteCampID, avoidWaterNative);
		rmAddGroupingConstraint(hussiteCampID, avoidTownCenterNative);
		rmAddGroupingConstraint(hussiteCampID, nativeAvoidRoutes);
		// the area flattener's 40 x 40 m box stays on the map (owner 2026-10-07: "obstruction can touch the map
		// edge"): the centre may move 25 m, the 30 m edge box keeps it 30 m in
		rmAddGroupingConstraint(hussiteCampID, playerEdgeConstraint);
		rmPlaceGroupingAtLoc(hussiteCampID, 0, xsArrayGetFloat(nativeX, nativeIndex), xsArrayGetFloat(nativeZ, nativeIndex), 1);
	}

	for (m=0; < nativeCount) {
		nativeIndex = sizeClass * 3 + m;
		int orthodoxMonasteryID = -1;
		if (jesuitSwapIndex == m)
			orthodoxMonasteryID = rmCreateGrouping("jesuit cathedral south", "Jesuit_Cathedral_EU_Flat_0"+rmRandInt(1, 3));
		else
			orthodoxMonasteryID = rmCreateGrouping("orthodox monastery "+m, "Orthodox_Monastery0"+rmRandInt(4, 6));
		rmAddGroupingToClass(orthodoxMonasteryID, rmClassID("natives"));
		rmSetGroupingMinDistance(orthodoxMonasteryID, 0.0);
		rmSetGroupingMaxDistance(orthodoxMonasteryID, 25.0);
		rmAddGroupingConstraint(orthodoxMonasteryID, avoidWaterNative);
		rmAddGroupingConstraint(orthodoxMonasteryID, avoidTownCenterNative);
		rmAddGroupingConstraint(orthodoxMonasteryID, nativeAvoidRoutes);
		rmAddGroupingConstraint(orthodoxMonasteryID, playerEdgeConstraint);
		rmPlaceGroupingAtLoc(orthodoxMonasteryID, 0, xsArrayGetFloat(nativeX, nativeIndex), 1.0-xsArrayGetFloat(nativeZ, nativeIndex), 1);
	}

	// The Jesuit cathedral in the gap between the two teams (owner 2026-10-07: "gap between two teams ... possibly Jesuit
	// monastery ... position dynamic based on team member amount"): on the players' ring at the gap's centre
	// (jesuitFrac, set by the placement). King of Bohemia's Jesuits (zpkingofbohemia.xs 383-393), the flat variants.
	// FFA and 3 or 4 teams have no gap and no cathedral
	if (jesuitFrac > 0.0) {
		float jesuitXF = 0.5 + 0.41 * sin(6.2831853 * jesuitFrac);
		float jesuitZF = 0.5 + 0.41 * cos(6.2831853 * jesuitFrac);
		int jesuitCathedralID = rmCreateGrouping("jesuit cathedral", "Jesuit_Cathedral_EU_Flat_0"+rmRandInt(1, 3));
		rmAddGroupingToClass(jesuitCathedralID, rmClassID("natives"));
		rmSetGroupingMinDistance(jesuitCathedralID, 0.0);
		rmSetGroupingMaxDistance(jesuitCathedralID, 25.0);
		rmAddGroupingConstraint(jesuitCathedralID, avoidWaterNative);
		rmAddGroupingConstraint(jesuitCathedralID, avoidTownCenterNative);
		rmAddGroupingConstraint(jesuitCathedralID, nativeAvoidRoutes);
		rmAddGroupingConstraint(jesuitCathedralID, playerEdgeConstraint);
		rmPlaceGroupingAtLoc(jesuitCathedralID, 0, jesuitXF, jesuitZF, 1);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// ************************** Terrain patches **************************

	// Paint only (no height), before the forests: tiny, incoherent patches that read as part of the ground mix (owner
	// 2026-10-07: "way way smaller ... tiny, incoherent, looking like terrain mix"; Iceland's paint patches,
	// zpIceland.xs 1127-1153: 30-40 tiles, coherence 0, up to 5 blobs). The north outer shore takes Italy Cliff Top and
	// Italy Grass Medium, the south outer shore Italy Grass Dry and Italy Grass Medium (owner 2026-10-07)
	int avoidPatchTiny = rmCreateClassDistanceConstraint("tiny patch vs. patch", rmClassID("classPatch"), 8.0);
	int numPatches = 10 + 8 * PlayerNum;
	int patchMixToggle = 0;
	for (g=0; < numPatches) {
		patchMixToggle = 1 - patchMixToggle;
		for (side=0; < 2) {
			int patchID = rmCreateArea("terrain patch "+side+" "+g);
			rmSetAreaWarnFailure(patchID, false);
			rmSetAreaSize(patchID, rmAreaTilesToFraction(30), rmAreaTilesToFraction(40));
			if (patchMixToggle == 0)
				rmSetAreaMix(patchID, "italy_grass_medium");
			else if (side == 0)
				rmSetAreaMix(patchID, "italy_cliff_top");
			else
				rmSetAreaMix(patchID, "italy_grass_dry");
			rmSetAreaCoherence(patchID, 0.0);
			rmSetAreaMinBlobs(patchID, 1);
			rmSetAreaMaxBlobs(patchID, 5);
			rmSetAreaMinBlobDistance(patchID, 8.0);
			rmSetAreaMaxBlobDistance(patchID, 16.0);
			rmAddAreaToClass(patchID, rmClassID("classPatch"));
			if (side == 0)
				rmAddAreaConstraint(patchID, northOuterBox);
			else
				rmAddAreaConstraint(patchID, southOuterBox);
			rmAddAreaConstraint(patchID, avoidInnerShore);
			rmAddAreaConstraint(patchID, avoidPatchTiny);
			rmAddAreaConstraint(patchID, avoidWater20);
			rmAddAreaConstraint(patchID, avoidNativesShort);
			rmAddAreaConstraint(patchID, avoidHarbour);
			rmAddAreaConstraint(patchID, avoidTownCenterPatch);
			rmBuildArea(patchID);
		}
	}

	// ***************************Forests *****************************

	// Scattered FORESTS (King of Bohemia; owner 2026-10-06: more of them, and the south its own type: the Black Sea's
	// south forest, zpblacksea.xs 1194). 6 per player on the south outer shore, 12 per player everywhere else. Every
	// forest area carries avoidAll (rm-workflow)
	int numTries = -1;
	int forestTreeID = 0;
	numTries=18*cNumberNonGaiaPlayers;
	int numSouthForests = 6*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries) {
		if (i == numSouthForests)
			failCount = 0;					// the second family starts afresh
		if (failCount < 5) {				// five failures in a row: this family is full
			int forest=rmCreateArea("forest "+i);
			rmSetAreaWarnFailure(forest, false);
			rmSetAreaSize(forest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));	// 150 before "more vegetation"
			if (i < numSouthForests) {
				rmSetAreaForestType(forest, "z42 Italian Forest");
				rmAddAreaConstraint(forest, southOuterBox);
			}
			else {
				rmSetAreaForestType(forest, "z69 North New England");
				rmAddAreaConstraint(forest, notSouthOuterBox);
			}
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
			rmAddAreaConstraint(forest, avoidTradeSockets);
			rmAddAreaConstraint(forest, avoidTradeRoute);
			rmAddAreaConstraint(forest, avoidTownCenterFar);
			rmAddAreaConstraint(forest, avoidNatives);
			rmAddAreaConstraint(forest, avoidBridge);
			rmAddAreaConstraint(forest, avoidHarbour);
			rmAddAreaConstraint(forest, shortAvoidImpassableLand);
			if(rmBuildArea(forest)==false)
				failCount++;
			else
				failCount=0;
		}
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	// ************************** Outer shores: King of Bohemia densities **************************

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, insideWorldRes);
	rmAddObjectDefConstraint(randomGoldID, Northward);
	rmAddObjectDefConstraint(randomGoldID, avoidInnerShore);
	rmAddObjectDefConstraint(randomGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldID, avoidWater20);		// 10 m (avoidWater10 is 2 m)
	rmAddObjectDefConstraint(randomGoldID, avoidNativesShort);
	rmPlaceObjectDefAtLoc(randomGoldID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	int randomGoldSouthID = rmCreateObjectDef("random south mine");
	rmAddObjectDefItem(randomGoldSouthID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldSouthID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldSouthID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldSouthID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidAll);
	rmAddObjectDefConstraint(randomGoldSouthID, insideWorldRes);
	rmAddObjectDefConstraint(randomGoldSouthID, Southward);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidInnerShore);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidTradeRoute);
	rmAddObjectDefConstraint(randomGoldSouthID, avoidWater20);		// 10 m (avoidWater10 is 2 m)
	rmAddObjectDefConstraint(randomGoldSouthID, avoidNativesShort);
	rmPlaceObjectDefAtLoc(randomGoldSouthID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);

	// Huntables North
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, "Elk", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.45));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHunt1);
	rmAddObjectDefConstraint(foodID1, avoidAll);
	rmAddObjectDefConstraint(foodID1, insideWorldRes);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID1, Northward);
	rmAddObjectDefConstraint(foodID1, avoidInnerShore);
	rmAddObjectDefConstraint(foodID1, avoidNativesShort);
	rmPlaceObjectDefAtLoc(foodID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

	// Huntables South
	int foodID2=rmCreateObjectDef("random food 2");
	rmAddObjectDefItem(foodID2, "Elk", rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidHunt1);
	rmAddObjectDefConstraint(foodID2, avoidAll);
	rmAddObjectDefConstraint(foodID2, insideWorldRes);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID2, Southward);
	rmAddObjectDefConstraint(foodID2, avoidInnerShore);
	rmAddObjectDefConstraint(foodID2, avoidNativesShort);
	rmPlaceObjectDefAtLoc(foodID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);

	int berryID1 = rmCreateObjectDef("starting berries north");
	rmAddObjectDefItem(berryID1, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID1, 0);
	rmSetObjectDefMaxDistance(berryID1, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID1, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID1, avoidAll);
	rmAddObjectDefConstraint(berryID1, insideWorldRes);
	rmAddObjectDefConstraint(berryID1, avoidWater10);
	rmAddObjectDefConstraint(berryID1, Northward);
	rmAddObjectDefConstraint(berryID1, avoidInnerShore);
	rmPlaceObjectDefAtLoc(berryID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int berryID2 = rmCreateObjectDef("starting berries south");
	rmAddObjectDefItem(berryID2, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID2, 0);
	rmSetObjectDefMaxDistance(berryID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berryID2, avoidRandomBerries);
	rmAddObjectDefConstraint(berryID2, avoidAll);
	rmAddObjectDefConstraint(berryID2, insideWorldRes);
	rmAddObjectDefConstraint(berryID2, avoidWater10);
	rmAddObjectDefConstraint(berryID2, Southward);
	rmAddObjectDefConstraint(berryID2, avoidInnerShore);
	rmPlaceObjectDefAtLoc(berryID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	// ************************** The inner shore: rich **************************

	// Per 2 players: 3 gold mines, 2 silver mines, 3 herds and 2 or more higher-tier treasures
	int innerGoldID = rmCreateObjectDef("inner gold mine");
	rmAddObjectDefItem(innerGoldID, "MineGold", 1, 0.0);
	rmSetObjectDefMinDistance(innerGoldID, 0.0);
	rmSetObjectDefMaxDistance(innerGoldID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(innerGoldID, inInnerShore);
	rmAddObjectDefConstraint(innerGoldID, avoidGold);
	rmAddObjectDefConstraint(innerGoldID, avoidAll);
	rmAddObjectDefConstraint(innerGoldID, insideWorldRes);
	rmAddObjectDefConstraint(innerGoldID, avoidTradeRoute);
	rmAddObjectDefConstraint(innerGoldID, avoidWater20);		// 10 m (avoidWater10 is 2 m)
	rmAddObjectDefConstraint(innerGoldID, avoidNativesShort);
	rmAddObjectDefConstraint(innerGoldID, avoidBridge);
	rmPlaceObjectDefAtLoc(innerGoldID, 0, rmXMetersToFraction(centreM+0.1*sizeM), 0.5, cNumberNonGaiaPlayers*3/2);

	int innerSilverID = rmCreateObjectDef("inner silver mine");
	rmAddObjectDefItem(innerSilverID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(innerSilverID, 0.0);
	rmSetObjectDefMaxDistance(innerSilverID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(innerSilverID, inInnerShore);
	rmAddObjectDefConstraint(innerSilverID, avoidCoin);
	rmAddObjectDefConstraint(innerSilverID, avoidGold);
	rmAddObjectDefConstraint(innerSilverID, avoidAll);
	rmAddObjectDefConstraint(innerSilverID, insideWorldRes);
	rmAddObjectDefConstraint(innerSilverID, avoidTradeRoute);
	rmAddObjectDefConstraint(innerSilverID, avoidWater20);		// 10 m (avoidWater10 is 2 m)
	rmAddObjectDefConstraint(innerSilverID, avoidNativesShort);
	rmAddObjectDefConstraint(innerSilverID, avoidBridge);
	rmPlaceObjectDefAtLoc(innerSilverID, 0, rmXMetersToFraction(centreM+0.1*sizeM), 0.5, cNumberNonGaiaPlayers);

	int innerHuntID=rmCreateObjectDef("inner food");
	rmAddObjectDefItem(innerHuntID, "Elk", rmRandInt(7,9), 5.0);
	rmSetObjectDefMinDistance(innerHuntID, 0.0);
	rmSetObjectDefMaxDistance(innerHuntID, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(innerHuntID, true);
	rmAddObjectDefConstraint(innerHuntID, inInnerShore);
	rmAddObjectDefConstraint(innerHuntID, avoidHunt1);
	rmAddObjectDefConstraint(innerHuntID, avoidAll);
	rmAddObjectDefConstraint(innerHuntID, insideWorldRes);
	rmAddObjectDefConstraint(innerHuntID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(innerHuntID, avoidNativesShort);
	rmPlaceObjectDefAtLoc(innerHuntID, 0, rmXMetersToFraction(centreM+0.1*sizeM), 0.5, cNumberNonGaiaPlayers*3/2);

	int innerNuggetID= rmCreateObjectDef("inner nugget");
	rmAddObjectDefItem(innerNuggetID, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmSetObjectDefMinDistance(innerNuggetID, 0.0);
	rmSetObjectDefMaxDistance(innerNuggetID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(innerNuggetID, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(innerNuggetID, inInnerShore);
	rmAddObjectDefConstraint(innerNuggetID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(innerNuggetID, avoidNuggets);
	rmAddObjectDefConstraint(innerNuggetID, avoidAll);
	rmAddObjectDefConstraint(innerNuggetID, insideWorldTreasure);
	rmAddObjectDefConstraint(innerNuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(innerNuggetID, avoidNativesShort);
	rmAddObjectDefConstraint(innerNuggetID, avoidBridge);
	rmPlaceObjectDefAtLoc(innerNuggetID, 0, rmXMetersToFraction(centreM+0.1*sizeM), 0.5, cNumberNonGaiaPlayers);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	// ************************** Treasures on the outer shores (King of Bohemia) **************************

	int nuggetHardNorth= rmCreateObjectDef("nugget hard north");
	rmAddObjectDefItem(nuggetHardNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardNorth, 0.0);
	rmSetObjectDefMaxDistance(nuggetHardNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardNorth, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(nuggetHardNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardNorth, insideWorldTreasure);
	rmAddObjectDefConstraint(nuggetHardNorth, Northward);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidInnerShore);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNativesShort);
	rmPlaceObjectDefAtLoc(nuggetHardNorth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

	int nuggetHardSouth= rmCreateObjectDef("nugget hard south");
	rmAddObjectDefItem(nuggetHardSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(121, 121);
	rmSetObjectDefMinDistance(nuggetHardSouth, 0.0);
	rmSetObjectDefMaxDistance(nuggetHardSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetHardSouth, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(nuggetHardSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHardSouth, insideWorldTreasure);
	rmAddObjectDefConstraint(nuggetHardSouth, Southward);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidInnerShore);
	rmAddObjectDefConstraint(nuggetHardSouth, avoidNativesShort);
	rmPlaceObjectDefAtLoc(nuggetHardSouth, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);

	int nuggetNorth= rmCreateObjectDef("nugget easy north");
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetNorth, 0.0);
	rmSetObjectDefMaxDistance(nuggetNorth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetNorth, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetNorth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetNorth, insideWorldTreasure);
	rmAddObjectDefConstraint(nuggetNorth, Northward);
	rmAddObjectDefConstraint(nuggetNorth, avoidInnerShore);
	rmAddObjectDefConstraint(nuggetNorth, avoidNativesShort);
	rmPlaceObjectDefAtLoc(nuggetNorth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

	int nuggetSouth= rmCreateObjectDef("nugget easy south");
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmSetObjectDefMinDistance(nuggetSouth, 0.0);
	rmSetObjectDefMaxDistance(nuggetSouth, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(nuggetSouth, avoidWater20);		// treasures 10 m off the water (owner 2026-10-07)
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockMedium);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetSouth, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetSouth, insideWorldTreasure);
	rmAddObjectDefConstraint(nuggetSouth, Southward);
	rmAddObjectDefConstraint(nuggetSouth, avoidInnerShore);
	rmAddObjectDefConstraint(nuggetSouth, avoidNativesShort);
	rmPlaceObjectDefAtLoc(nuggetSouth, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

	// Fish all along the river (Crownlands; owner 2026-10-06: more fish everywhere)
	int fishID=rmCreateObjectDef("fishies");
	rmAddObjectDefItem(fishID, fish1, 1, 2.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.9));
	rmAddObjectDefConstraint(fishID, fishVsFishShort);
	rmAddObjectDefConstraint(fishID, avoidLandFish);
	rmAddObjectDefConstraint(fishID, avoidBridge);
	rmAddObjectDefConstraint(fishID, avoidHarbour);
	rmAddObjectDefConstraint(fishID, insideWorldRes);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 50+cNumberNonGaiaPlayers*10);		// more fish (owner 2026-10-07)

	// KotH: the hill sits on the locked inner shore
	if (rmGetIsKOTH() == true)
		ypKingsHillPlacer(rmXMetersToFraction(centreM+0.11*sizeM), 0.5, 0.00, 0);

	// Village trees on the elector plateaus (zpelbe.xs 1192-1197: nine per plateau with avoidAll, so they take the free
	// rim round the castle; owner 2026-10-07: "add few trees to the elector cliffs - look how Elbe is doing that").
	// A mix of New England trees and Great Lakes oaks (owner 2026-10-07), both of the inner shore's z69 North New
	// England forests (Independence War's village trees: zpindependencewar.xs 1607-1612). Placed last, so no unit a
	// trigger addresses moves
	int villageTreeID=rmCreateObjectDef("village tree");
	rmAddObjectDefItem(villageTreeID, "TreeNewEngland", 1, 0.0);
	rmAddObjectDefConstraint(villageTreeID, avoidAll);
	rmAddObjectDefConstraint(villageTreeID, insideWorldRes);
	int villageOakID=rmCreateObjectDef("village oak");
	rmAddObjectDefItem(villageOakID, "TreeGreatLakes", 1, 0.0);
	rmAddObjectDefConstraint(villageOakID, avoidAll);
	rmAddObjectDefConstraint(villageOakID, insideWorldRes);
	for (e=0; < numElectors) {
		rmPlaceObjectDefInArea(villageTreeID, 0, rmAreaID("elector plateau "+e), 5);
		rmPlaceObjectDefInArea(villageOakID, 0, rmAreaID("elector plateau "+e), 4);
	}

	// Scattered trees over the open grass (owner 2026-10-07: "the map is just too grassy. I want more vegetation"):
	// Caribbean Wars' random trees (zpcaribbeanwars.xs 918-926) in the forests' own species (data/forest2.xml) -
	// everywhere but the south outer shore a mix of New England trees and Great Lakes oaks (owner 2026-10-07; both of
	// z69 North New England, 16 per player); the south's z42 Italian Forest: ypTreeMongolianFir, ypTreeEucalyptus
	// (6 per player)
	for (t=0; < 4) {
		int randomTreeID=rmCreateObjectDef("random tree "+t);
		int randomTreeCount = 4*cNumberNonGaiaPlayers;
		if (t == 0) {
			rmAddObjectDefItem(randomTreeID, "TreeNewEngland", 1, 0.0);
			randomTreeCount = 8*cNumberNonGaiaPlayers;
		}
		if (t == 1) {
			rmAddObjectDefItem(randomTreeID, "TreeGreatLakes", 1, 0.0);
			randomTreeCount = 8*cNumberNonGaiaPlayers;
		}
		if (t == 2)
			rmAddObjectDefItem(randomTreeID, "ypTreeMongolianFir", 1, 0.0);
		if (t == 3)
			rmAddObjectDefItem(randomTreeID, "ypTreeEucalyptus", 1, 0.0);
		if (t >= 2)
			randomTreeCount = 3*cNumberNonGaiaPlayers;
		rmSetObjectDefMinDistance(randomTreeID, 0.0);
		rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
		rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
		rmAddObjectDefConstraint(randomTreeID, avoidAll);
		rmAddObjectDefConstraint(randomTreeID, avoidTradeRoute);
		rmAddObjectDefConstraint(randomTreeID, avoidTownCenterFar);
		rmAddObjectDefConstraint(randomTreeID, avoidNativesShort);
		rmAddObjectDefConstraint(randomTreeID, avoidBridge);
		rmAddObjectDefConstraint(randomTreeID, avoidHarbour);
		rmAddObjectDefConstraint(randomTreeID, insideWorldRes);
		if (t < 2)
			rmAddObjectDefConstraint(randomTreeID, notSouthOuterBox);
		else
			rmAddObjectDefConstraint(randomTreeID, southOuterBox);
		rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, randomTreeCount);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.90);

	// ____________________ LOCAL MERCENARIES (Crownlands) ____________________
	rmDisableDefaultMercs(true);
	rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercJaeger", -1);
	rmEnableMerc("deMercPandour", -1);
	rmEnableMerc("deMercGrenadier", -1);
	rmEnableMerc("zpMercBohemianKnight", -1);
	rmEnableMerc("MercGreatCannon", -1);

	rmForbidTradeMonopoly(true);

	// ************************* TRIGGERS ******************************

	// Lookups use underscores (rm-triggers law 3): rmCreateTrigger("A B") is found by rmTriggerID("A_B")

	// Starting techs of a normal European map (zpBalearicIslands.xs): ship capture locked for the players; for every
	// player and gaia the European embassy design and the Prince Electors' setup (their Trading Post cards stay off
	// until a prince is elected; zpelbe.xs and zpcrownlands.xs carry it in their setup techs). No map setup tech, no
	// river boats, no warship ban: a normal map (owner 2026-10-06)
	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting_Techs"));
	// players only - gaia keeps its protos (a setup tech on gaia resets AutoConvert suspensions)
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpLockShipCapture"); // ships capture nothing: ConvertsHerds off (zpLockShipCapture)
		rmSetTriggerEffectParamInt("Status",2);
	}
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Activate European Embassy for all players
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpPrinceElectorNativeSetup"); // the Electors' cards wait for the election
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

	// Native politician switchers: Electors and Hussites (zpelbe.xs 1623-1675), Orthodox (zpvenice.xs 1796-1822)

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Electors"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPrinceElectorElect"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPrinceElector"); //operator
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
		rmCreateTrigger("Activate Hussites"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpHussiteExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffHussites"); //operator
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
		rmCreateTrigger("Activate Orthodox"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpOrthodoxInfluence"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffOrthodoxBalkan"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Electors"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Hussites"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Orthodox"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Prince Elector Increments: one site step per castle held beyond the first (zpElectorSiteLadder above main)
	zpElectorSiteLadder(numElectors);

	// ****************** Elector Convert (zpelbe.xs 1770-1820) ******************
	// A Trading Post on a castle's socket converts its Elector center to the builder, losing it converts it back
	for (s=1; <= numElectors) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Elector"+s+"on Player"+k);
			rmCreateTrigger("Elector"+s+"off Player"+k);

			castleSocketID = xsArrayGetInt(castleSockets, s-1);
			rmSwitchToTrigger(rmTriggerID("Elector"+s+"on_Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+castleSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+castleSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpElectorCenter");
			rmSetTriggerEffectParamInt("Dist",35);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector"+s+"off_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector"+s+"off_Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+castleSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamInt("Count",0);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+castleSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpElectorCenter");
			rmSetTriggerEffectParamInt("Dist",35);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector"+s+"on_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
	}

	// AI Hussite Leaders (zpelbe.xs 2686-2727)

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Hussite Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int hussiteLeader=-1;
	hussiteLeader = rmRandInt(1,3);

	if (hussiteLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesZizka"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesKing"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesReformer"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Elector Leaders (zpelbe.xs 2729-2784)

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Elector Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int electorLeader=-1;
	electorLeader = rmRandInt(1,5);

	if (electorLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHabsburg"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWittelsbach"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWettin"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==4)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHanover"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==5)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorOldenburg"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Orthodox Captains (zpvenice.xs 2273-2314)

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Orthodox Captain"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int orthodoxCaptain=-1;
	orthodoxCaptain = rmRandInt(1,3);

	if (orthodoxCaptain==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxGeorgians"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (orthodoxCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxBulgarians"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (orthodoxCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxConstantinopole"); //operator
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
