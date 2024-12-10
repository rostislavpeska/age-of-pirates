// Silk Road 
// PJJ
// Sept 2006 ~ started with a modified version of pampas
// AOE3 DE 2019 Updated by Alex Y   
//updated balance for 1v1 by Durokan for DE
// February 2021 edited by vividlyplain 

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

  int whichVersion = rmRandInt(1,3);
  //whichVersion = 2; 
 
  // initialize map type variables
  string nativeCiv1 = "";
  string nativeCiv2 = "";
  
  string nativeString1= "";
  string nativeString2= "";
 
  string baseMix = "";
  
  //The base for the trade route
  string baseTerrain = "";
  //The blending for the trade route
  string baseTrade = "";
 
  string forestType = "";
  string startTreeType = "";
  
  string patchTerrain1 = "";
  string patchTerrain2 = "";
  string patchType1 = "";
  string patchType2 = "";
  
  string playerTerrain = "";
  
  string mapType1 = "";
  string mapType2 = "";
  
  string herdableType = "";
  string huntable1 = "";
  string huntable2 = "";
  
  string lightingType = "";
  
  string guardianType = "";
  string guardianDistance = "45.0";
  int numberPosts = 1;
  int triggerCounter = 0; 
  
  string tradeRouteType = "";
  
  // Grassy - Yellow River
  if(whichVersion == 1) {
    nativeCiv1 = "Shaolin";
    nativeCiv2 = "Zen";
    nativeString1 = "native shaolin temple yr 0";
    nativeString2 = "native zen temple yr 0";
    baseMix = "yellow_river_a";
    baseTerrain = "yellow_river\grass5_yellow_riv";
	baseTrade = "yellow_river\stone2_yellow_riv";
    startTreeType = "ypTreeBamboo";
    forestType = "Yellow River Forest";
    patchTerrain1 = "yellow_river\stone2_yellow_riv";
    patchTerrain2 = "yellow_river\grass2_yellow_riv";
    patchType1 = "yellow_river\stone1_yellow_riv";
    patchType2 = "yellow_river\grass4_yellow_riv";
	playerTerrain = "Yellow_river\stone2_yellow_riv";
    mapType1 = "silkRoad1";
    mapType2 = "grass";
    herdableType = "ypWaterBuffalo";
    huntable1 = "ypIbex";
    huntable2 = "ypMarcoPoloSheep";
    lightingType = "yellow_river_dry_skirmish";
    tradeRouteType = "dirt";    
    guardianType = "ypBlindMonk";
  }
  
  // Desert/Plains - Mongolia
  else if (whichVersion == 2) {
    if (rmRandFloat(0,1) <= 0.333)
    {
      nativeCiv1 = "sufi";
      nativeString1 = "native sufi mosque mongol ";
    }
    else
    {
      nativeCiv1 = "tengri";
      nativeString1 = "native tengri village 0";
    }
    nativeCiv2 = "shaolin";
    nativeString2 = "native shaolin temple mongol 0";
    baseMix = "mongolia_grass_b";
    baseTerrain = "Mongolia\ground_grass6_mongol";
	baseTrade = "Mongolia\ground_grass5_mongol";
    forestType = "Mongolian Forest";
    startTreeType = "ypTreeSaxaul";
    patchTerrain1 = "Mongolia\ground_sand2_mongol";
    patchTerrain2 = "Mongolia\ground_grass3_mongol";
    patchType1 = "Mongolia\ground_sand3_mongol";
    patchType2 = "Mongolia\ground_grass6_mongol";
	playerTerrain = "Mongolia\ground_grass6_mongol";
    mapType1 = "silkRoad2";
    mapType2 = "grass";
    herdableType = "ypYak";
    huntable1 = "ypSaiga";
    huntable2 = "ypMuskDeer";    
    lightingType = "Mongolia_skirmish";
    tradeRouteType = "dirt";  
    guardianType = "ypWokou";
  }
  
  // Snowy - Himalayas
  else {
    nativeCiv1 = "bhakti";
    nativeCiv2 = "udasi";
    nativeString1 = "native bhakti village himal ";
    nativeString2 = "native udasi village himal ";
    baseMix = "himalayas_a";
    baseTerrain = "himalayas\ground_dirt1_himal";
	baseTrade = "himalayas\ground_dirt4_himal";
    forestType = "Himalayas Forest";
    startTreeType = "ypTreeHimalayas";
    patchTerrain1 = "himalayas\ground_dirt8_himal";
    patchTerrain2 = "himalayas\ground_dirt3_himal";
    patchType1 = "himalayas\ground_dirt6_himal";
    patchType2 = "himalayas\ground_dirt2_himal";
	playerTerrain = "himalayas\ground_dirt3_himal";
    mapType1 = "silkRoad3";
    mapType2 = "grass";
    herdableType = "ypYak";
    huntable1 = "ypSerow";
    huntable2 = "ypIbex";   
    lightingType = "Himalayas_skirmish";
    tradeRouteType = "dirt";  
    guardianType = "ypWaywardRonin";
  }
  
// Natives
   int subCiv0=-1;
   int subCiv1=-1;

  if (rmAllocateSubCivs(2) == true) {
    // 1st Native Civ
    subCiv0=rmGetCivID(nativeCiv1);
    if (subCiv0 >= 0)
      rmSetSubCiv(0, nativeCiv1);

    // 2nd Native Civ
    subCiv1=rmGetCivID(nativeCiv2);
    if (subCiv1 >= 0)
      rmSetSubCiv(1, nativeCiv2);
  }
	
// Map Basics
	int playerTiles = 12500;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 12000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 11500;		

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	rmSetMapElevationParameters(cElevTurbulence, 0.05, 10, 0.4, 7.0);
	rmSetMapElevationHeightBlend(1);
	
	rmSetSeaLevel(1.0);
	rmSetLightingSet(lightingType);
	rmSetBaseTerrainMix(baseTrade);
	rmTerrainInitialize(baseTerrain, 0.0);
	rmEnableLocalWater(false);
  rmSetMapType(mapType1);
  rmSetMapType(mapType2);
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(2.0);

	chooseMercs();

// Classes
	int classPlayer=rmDefineClass("player");
	int classSocket=rmDefineClass("socketClass");
	rmDefineClass("classPatch");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("classNugget");
	rmDefineClass("natives");

  bool weird = false;
  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
    
  if (cNumberTeams > 2 || (teamZeroCount - teamOneCount) > 2 || (teamOneCount - teamZeroCount) > 2)
    weird = true;

// Constraints
    
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(12), rmZTilesToFraction(12), 1.0-rmXTilesToFraction(12), 1.0-rmZTilesToFraction(12), 0.01);

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 25.0);
  int longPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players long", classPlayer, 45.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 15.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
  int playerConstraintNugget = rmCreateClassDistanceConstraint("nuggets stay away from players long", classPlayer, 55.0);
  int avoidKOTH = rmCreateTypeDistanceConstraint("avoid KOTH", "ypKingsHill", 6.0);
  int nativePlayerConstraint = rmCreateTypeDistanceConstraint("avoid TCs", "TownCenter", 70.0);
  int avoidTC = rmCreateTypeDistanceConstraint("tc avoid", "TownCenter", 35.0);
  //~ int nativePlayerConstraint = rmCreateClassDistanceConstraint("avoid TCs", classPlayer, 45.0);

	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 30.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int shortAvoidResource=rmCreateTypeDistanceConstraint("resource avoid resource short", "resource", 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	   
	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);

  // resource avoidance
	int avoidSilver=rmCreateTypeDistanceConstraint("gold avoid gold", "Mine", 85.0);
	int mediumAvoidSilver=rmCreateTypeDistanceConstraint("medium gold avoid gold", "Mine", 30.0);
	int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid deer", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid tapir", huntable2, 60.0);
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 20.0);
	int avoidNuggetFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
  int avoidHerdable=rmCreateTypeDistanceConstraint("herdables avoid herdables", herdableType, 75.0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int circleConstraintTwo=rmCreatePieConstraint("circle Constraint 2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Unit avoidance
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), rmXFractionToMeters(0.2));
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 12.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 7.0);
	int farAvoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives alot", rmClassID("natives"), 80.0);
    int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 10.0);


	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);

	// Trade route avoidance.
	int groundAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route ground", 0.5);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route short", 6.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 10.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
	int avoidTradeRouteSocketsShort=rmCreateTypeDistanceConstraint("avoid trade route sockets short", "zpTradingPostCaptureNaval", 4.0);
  int avoidTradeRouteSockets=rmCreateTypeDistanceConstraint("avoid trade route sockets", "zpTradingPostCaptureNaval", 12.0);
	int avoidTradeRouteSocketsFar=rmCreateTypeDistanceConstraint("avoid trade route sockets far", "zpTradingPostCaptureNaval", 20.0);
	int avoidMineSockets=rmCreateTypeDistanceConstraint("avoid mine sockets", "mine", 10.0);

    //dk
    int avoidAll_dk=rmCreateTypeDistanceConstraint("avoid all_dk", "all", 3.0);
    int avoidWater5_dk = rmCreateTerrainDistanceConstraint("avoid water long_dk", "Land", false, 5.0);
    int avoidSocket2_dk=rmCreateClassDistanceConstraint("socket avoidance gold_dk", rmClassID("socketClass"), 8.0);
    int avoidTradeRouteSmall_dk = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small_dk", 6.0);
    int forestConstraintShort_dk=rmCreateClassDistanceConstraint("object vs. forest_dk", rmClassID("classForest"), 2.0);
    int avoidHunt2_dk=rmCreateTypeDistanceConstraint("herds avoid herds2_dk", "huntable", 38.0);
    int avoidHunt3_dk=rmCreateTypeDistanceConstraint("herds avoid herds3_dk", "huntable", 18.0);
	int avoidAll2_dk=rmCreateTypeDistanceConstraint("avoid all2_dk", "all", 4.0);
    int avoidGoldTypeFar_dk = rmCreateTypeDistanceConstraint("avoid gold type  far 2_dk", "mine", 41.0);
    int circleConstraint2_dk=rmCreatePieConstraint("circle Constraint2_dk", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidMineForest_dk=rmCreateTypeDistanceConstraint("avoid mines forest _dk", "mine", 5.0);
    int avoidCow_dk=rmCreateTypeDistanceConstraint("cow avoids cow dk", "cow", 32.0);
    int avoidGoldBerry_dk=rmCreateTypeDistanceConstraint("starting berries avoid mines _dk", "mine", 6.0);

	// vivid
	int classStartingResource = rmDefineClass("startingResource");
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 12.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 4.0);

// ************************** DEFINE OBJECTS ****************************
if(cNumberNonGaiaPlayers>2){  	
  int deerID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(deerID, huntable1, 9, 6.0);
	rmSetObjectDefCreateHerd(deerID, true);
	rmSetObjectDefMinDistance(deerID, 0.0);
	rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerID, avoidResource);
	rmAddObjectDefConstraint(deerID, playerConstraint);
	rmAddObjectDefConstraint(deerID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerID, avoidHuntable1);
	rmAddObjectDefConstraint(deerID, avoidHuntable2);
  rmAddObjectDefConstraint(deerID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(deerID, avoidTradeRouteSockets);
  
  int tapirID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(tapirID, huntable2, 11, 6.0);
	rmSetObjectDefCreateHerd(tapirID, true);
	rmSetObjectDefMinDistance(tapirID, 0.0);
	rmSetObjectDefMaxDistance(tapirID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(tapirID, avoidResource);
	rmAddObjectDefConstraint(tapirID, playerConstraint);
	rmAddObjectDefConstraint(tapirID, avoidImpassableLand);
	rmAddObjectDefConstraint(tapirID, avoidHuntable1);
	rmAddObjectDefConstraint(tapirID, avoidHuntable2);
	rmAddObjectDefConstraint(tapirID, shortAvoidImportantItem);
	rmAddObjectDefConstraint(tapirID, avoidTradeRouteSockets);
}
  int StartDeerID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(StartDeerID, huntable1, 7, 4.0);
	rmSetObjectDefMinDistance(StartDeerID, 14.0);
	rmSetObjectDefMaxDistance(StartDeerID, 16.0);
	rmSetObjectDefCreateHerd(StartDeerID, true);
	rmAddObjectDefConstraint(StartDeerID, avoidHuntable1);    
	rmAddObjectDefConstraint(StartDeerID, avoidHuntable2);    
	rmAddObjectDefConstraint(StartDeerID, avoidStartingResourcesMin);    
	rmAddObjectDefConstraint(StartDeerID, avoidTradeRouteSmall_dk);    
   
	// -------------Done defining objects
  // Text
  rmSetStatusText("",0.10);
	
  // Trade routes
  int tradeRouteID = rmCreateTradeRoute();

  int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
  rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

  rmAddObjectDefItem(socketID, "zpTradingPostCaptureNaval", 1, 6.0);
  rmAddObjectDefItem(socketID, "Nugget", 1, 6.0);
  rmSetNuggetDifficulty(99, 99);
	rmSetObjectDefAllowOverlap(socketID, false);
  rmSetObjectDefMinDistance(socketID, 10.0);
  rmSetObjectDefMaxDistance(socketID, 12.0);
 	rmAddObjectDefConstraint(socketID, circleConstraintTwo);
  rmAddObjectDefConstraint(socketID, shortAvoidTradeRoute);

	if (cNumberTeams == 2) {
  rmAddTradeRouteWaypoint(tradeRouteID, 0, .5);
  rmAddTradeRouteWaypoint(tradeRouteID, 1, .5);
		}
	else {
		rmAddTradeRouteWaypoint(tradeRouteID, 0, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.2, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.3, .55);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, .55);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.7, .45);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.8, .5);
		rmAddTradeRouteWaypoint(tradeRouteID, 1, .5);
		}

  bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, tradeRouteType);
  if(placedTradeRoute == false)
    rmEchoError("Failed to place trade route"); 
  
	// add the sockets along the trade route.
  vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
  
  int tempCounter = 0;

  if(cNumberNonGaiaPlayers > 3)
    numberPosts = 7;
    
  if(cNumberNonGaiaPlayers > 5) 
    numberPosts = 9;
    
  float loc0 = 0.1;
  float loc1 = 0.3;
  float loc2 = 0.5;
  float loc3 = 0.7;
  float loc4 = 0.9;
  float loc5 = 0.2;
  float loc6 = 0.8;
  float loc7 = 0.4; 
  float loc8 = 0.6;
  float tempLoc = 0.0;

  rmPlaceObjectDefAtLoc(socketID, 0, 0.5, 0.51);

  for(i = 0; < numberPosts) {
    
    if(i == 0)
      tempLoc = loc0;
    
    else if (i == 1)
      tempLoc = loc1;
    
    else if (i == 2)
      tempLoc = loc2;
    
    else if (i == 3)
      tempLoc = loc3;
    
    else if (i == 4)
      tempLoc = loc4;
    
    else if (i == 5)
      tempLoc = loc5;
    
    else if (i == 6)
      tempLoc = loc6;
      
    else if (i == 7)
      tempLoc = loc7;
      
    else if (i == 8)
      tempLoc = loc8;
    
    socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, tempLoc);
  
    // if we fail to place something, will be the thuggees, so knock the counter down one so the rest of the triggers still line up on the posts
    if(rmPlaceObjectDefAtPoint(socketID, 0, socketLoc) < 2) {
      tempCounter++;
    }
    
    // otherwise, set up triggers
    else {
      /*rmCreateTrigger("GuardianDeath"+triggerCounter);
      rmSwitchToTrigger(rmTriggerID("GuardianDeath"+triggerCounter));
      rmSetTriggerPriority(4); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);
        
      rmAddTriggerCondition("Nugget Is Collectable");
      rmSetTriggerConditionParamInt("NuggetObject", rmGetUnitPlaced(socketID, triggerCounter + 1), false);
      
      rmAddTriggerEffect("Unit Action Suspend");
      rmSetTriggerEffectParamInt("SrcObject", rmGetUnitPlaced(socketID, triggerCounter), false);
      rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
      rmSetTriggerEffectParam("Suspend", "False", false);
      
      rmCreateTrigger("DisableAutoconvert"+triggerCounter);
      rmSwitchToTrigger(rmTriggerID("DisableAutoconvert"+triggerCounter));
      rmSetTriggerPriority(4); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);
        
      rmAddTriggerCondition("Always");
      
      rmAddTriggerEffect("Unit Action Suspend");
      
      rmSetTriggerEffectParamInt("SrcObject", rmGetUnitPlaced(socketID, triggerCounter), false);
      
      rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
      rmSetTriggerEffectParam("Suspend", "True", false);*/
      
      tempCounter = tempCounter + 2;
    }
    
    triggerCounter = tempCounter;
  }

  // Base Terrain	
  for (i=0; < 2) {
    int baseMixTerrain=rmCreateArea("first patch"+i);
    rmSetAreaWarnFailure(baseMixTerrain, false);
    rmSetAreaSize(baseMixTerrain, rmAreaTilesToFraction(10000000), rmAreaTilesToFraction(20000000));
    rmSetAreaMix(baseMixTerrain, baseMix);
	rmAddAreaTerrainLayer(baseMixTerrain, baseTrade, 0, 2);
    rmAddAreaToClass(baseMixTerrain, rmClassID("classPatch"));
    rmAddAreaConstraint(baseMixTerrain, groundAvoidTradeRoute);
	rmAddAreaConstraint(baseMixTerrain, avoidTownCenter);	
    rmBuildArea(baseMixTerrain); 
  }

// Players
  
   // Text
   rmSetStatusText("",0.20);
  
   // Players start in lines on either side of the "road"
  
	if (cNumberTeams == 2 && teamZeroCount == teamOneCount) 
	{
		rmSetPlacementTeam(0);
		rmPlacePlayersLine(.3, .2, .7, .2, .0, .0);
    
		rmSetPlacementTeam(1);
		rmPlacePlayersLine(.7, .8, .3, .8, .0, .0);
	}
	else if (cNumberTeams == 2 && teamZeroCount != teamOneCount) 
	{
		if (teamOneCount > 4)
		{
    rmSetPlacementTeam(0);
			rmPlacePlayersLine(.3, .2, .7, .2, .0, .0);
  
    rmSetPlacementTeam(1);
			rmPlacePlayersLine(.8, .8, .2, .8, .0, .0);
		}
		else if (teamZeroCount > 4)
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(.2, .2, .8, .2, .0, .0);
	
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(.7, .8, .3, .8, .0, .0);
  }
		else 
		{
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(.3, .2, .7, .2, .0, .0);
  
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(.7, .8, .3, .8, .0, .0);
		}
	}
  // ffa
   else 
   {
	   if (cNumberNonGaiaPlayers == 7) 
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.95, 0.9499);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
	   }
	   else if (cNumberNonGaiaPlayers == 4) 
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.0, 1.0);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
	   }
	   else if (cNumberNonGaiaPlayers == 5) 
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.89, 0.8899);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
	   }
	   else if (cNumberNonGaiaPlayers == 6)
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.99, 0.9899);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
  }
	   else if (cNumberNonGaiaPlayers == 3)
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.97, 0.9699);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
	   }
	   else 
	   {
		rmSetTeamSpacingModifier(0.50);
		rmSetPlacementSection(0.83, 0.77);
		rmPlacePlayersCircular(0.32, 0.32, 0.0);
		}
  }
  
   // Set up player areas.
  float playerFraction=rmAreaTilesToFraction(100);
  for(i=1; <cNumberPlayers) {
    int id=rmCreateArea("Player"+i);
    rmSetPlayerArea(i, id);
    rmSetAreaSize(id, playerFraction, playerFraction);
    rmAddAreaToClass(id, classPlayer);
    rmAddAreaConstraint(id, avoidTradeRouteSockets); 
    rmAddAreaConstraint(id, shortAvoidImportantItem); 
    rmAddAreaConstraint(id, playerConstraint); 
    rmAddAreaConstraint(id, playerEdgeConstraint); 
    rmSetAreaCoherence(id, 1.0);
    rmSetAreaLocPlayer(id, i);
	rmSetAreaTerrainType(id, playerTerrain);
    rmSetAreaWarnFailure(id, false);
  }
  
  // Build the areas.
  rmBuildAllAreas();

  // starting resources

  int TCfloat = -1;
	if (cNumberNonGaiaPlayers <= 4)
		TCfloat = 15;
  else if (cNumberTeams > 2)
    TCfloat = 15;
	else if (weird)
    TCfloat = 50;
  else
		TCfloat = 20;

  int startingTCID= rmCreateObjectDef("startingTC");
	if (rmGetNomadStart()) {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
  }
		
  else {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
  }

  rmSetObjectDefMinDistance(startingTCID, 0);
	if (cNumberTeams == 2)
		rmSetObjectDefMaxDistance(startingTCID, 0); //TCfloat
	else 
		rmSetObjectDefMaxDistance(startingTCID, 15); //TCfloat
	rmAddObjectDefToClass(startingTCID, classStartingResource);
	rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, avoidTC);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRouteSockets);
  rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
//	rmAddObjectDefToClass(startingTCID, rmClassID("player"));

  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 8, 4.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 18);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 18);
	rmAddObjectDefToClass(StartAreaTreeID, classStartingResource);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImportantItem);
  rmAddObjectDefConstraint(StartAreaTreeID, avoidTradeRouteSocketsShort);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "berrybush", 4, 4.0);
	rmSetObjectDefMinDistance(StartBerriesID, 16);
	rmSetObjectDefMaxDistance(StartBerriesID, 16);
	rmAddObjectDefToClass(StartBerriesID, classStartingResource);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartingResourcesShort);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, avoidGoldBerry_dk);
	rmAddObjectDefConstraint(StartBerriesID, avoidTradeRouteSmall_dk);
	rmAddObjectDefConstraint(StartBerriesID, avoidTradeRouteSocketsShort);

   // Text
   rmSetStatusText("",0.30);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 16.0);
	rmSetObjectDefMaxDistance(startSilverID, 16.0);
	rmAddObjectDefToClass(startSilverID, classStartingResource);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
	rmAddObjectDefConstraint(startSilverID, avoidStartingResourcesMin);
	rmAddObjectDefConstraint(startSilverID, avoidTradeRouteSmall_dk);
	rmAddObjectDefConstraint(startSilverID, avoidTradeRouteSocketsShort);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefToClass(startingUnits, classStartingResource);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

  int playerCrateID=rmCreateObjectDef("bonus starting wood");
  rmAddObjectDefItem(playerCrateID, "crateOfWood", 3, 3.0);
  rmSetObjectDefMinDistance(playerCrateID, 12);
  rmSetObjectDefMaxDistance(playerCrateID, 14);
	rmAddObjectDefToClass(playerCrateID, classStartingResource);
  rmAddObjectDefConstraint(playerCrateID, avoidStartResource);
  rmAddObjectDefConstraint(playerCrateID, shortAvoidImpassableLand);
  
  	// Market
	int startResourceBuildingID=rmCreateObjectDef("starting resource building");
  rmAddObjectDefItem(startResourceBuildingID, "Market", 1, 0.0);
	rmSetObjectDefMinDistance(startResourceBuildingID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingID, 20.0);
	rmAddObjectDefToClass(startResourceBuildingID, classStartingResource);
  rmAddObjectDefConstraint(startResourceBuildingID, avoidAll);
  rmAddObjectDefConstraint(startResourceBuildingID, avoidTradeRouteFar);
	rmAddObjectDefConstraint(startResourceBuildingID, avoidImpassableLand);
  
  // Asian Market
  int startResourceBuildingAsianID=rmCreateObjectDef("starting resource building asian");
  rmAddObjectDefItem(startResourceBuildingAsianID, "ypTradeMarketAsian", 1, 0.0);
	rmSetObjectDefMinDistance(startResourceBuildingAsianID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingAsianID, 20.0);
	rmAddObjectDefToClass(startResourceBuildingAsianID, classStartingResource);
  rmAddObjectDefConstraint(startResourceBuildingAsianID, avoidAll);
  rmAddObjectDefConstraint(startResourceBuildingAsianID, avoidTradeRouteFar);
	rmAddObjectDefConstraint(startResourceBuildingAsianID, avoidImpassableLand);

  // African Market
  int startResourceBuildingAfricanID=rmCreateObjectDef("starting resource building african");
  rmAddObjectDefItem(startResourceBuildingAfricanID, "deLivestockMarket", 1, 0.0);
	rmSetObjectDefMinDistance(startResourceBuildingAfricanID, 16.0);
	rmSetObjectDefMaxDistance(startResourceBuildingAfricanID, 20.0);
	rmAddObjectDefToClass(startResourceBuildingAfricanID, classStartingResource);
  rmAddObjectDefConstraint(startResourceBuildingAfricanID, avoidAll);
  rmAddObjectDefConstraint(startResourceBuildingAfricanID, avoidTradeRouteFar);
	rmAddObjectDefConstraint(startResourceBuildingAfricanID, avoidImpassableLand);

  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 24.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 24.0);
	rmAddObjectDefToClass(playerNuggetID, classStartingResource);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  rmAddObjectDefConstraint(playerNuggetID, avoidTradeRoute);
  
	// Text
	rmSetStatusText("",0.40);

	for(i=1; < cNumberPlayers) {
		rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    if(rmGetNomadStart() == false) {
	    if (rmGetPlayerCiv(i) ==  rmGetCivID("Chinese") || rmGetPlayerCiv(i) == rmGetCivID("Indians")) {
        rmPlaceObjectDefAtLoc(startResourceBuildingAsianID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
      }
	    else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) == rmGetCivID("DEHausa")) {
        rmPlaceObjectDefAtLoc(startResourceBuildingAfricanID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
      }
      else if(rmGetPlayerCiv(i) ==  rmGetCivID("Japanese")) {
        rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
        rmPlaceObjectDefAtLoc(startResourceBuildingAsianID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));  
      }
      
      else {
        rmPlaceObjectDefAtLoc(startResourceBuildingID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
      }
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Berry Bushes
		rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Place a nugget for the player
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    



    }      
	}

  // Natives
  
    //1
    int nativeArea1=rmCreateArea("native1");
    rmSetAreaSize(nativeArea1, .04, .04);
    rmAddAreaConstraint(nativeArea1, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea1, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea1, 0.35, 0.6);
    }
    
    else {
      rmSetAreaLocation(nativeArea1, 0.6, 0.075);
    }
    
    //2
    int nativeArea2=rmCreateArea("native2");
    rmSetAreaSize(nativeArea2, .04, .04);
    rmAddAreaConstraint(nativeArea2, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea2, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea2, 0.65, 0.4);
    }
    
    else {
      rmSetAreaLocation(nativeArea2, 0.375, 0.9);
    }
    
    //3
    int nativeArea3=rmCreateArea("native3");
    rmSetAreaSize(nativeArea3, .045, .045);
    rmAddAreaConstraint(nativeArea3, circleConstraintTwo);
    rmSetAreaCoherence(nativeArea3, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea3, 0.165, 0.3);
    }
    
    else {
      rmSetAreaLocation(nativeArea3, 0.95, 0.625);
    }
    
    //4
    int nativeArea4=rmCreateArea("native4");
    rmSetAreaSize(nativeArea4, .045, .045);
    rmAddAreaConstraint(nativeArea4, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea4, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea4, 0.83, 0.7);
    }
    
    else {
      rmSetAreaLocation(nativeArea4, 0.05, 0.375);
    }
    
    //5
    int nativeArea5=rmCreateArea("native5");
    rmSetAreaSize(nativeArea5, .045, .045);
    rmAddAreaConstraint(nativeArea5, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea5, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea5, 0.855, 0.31);
    }
    
    else {
      rmSetAreaLocation(nativeArea5, 0.8, 0.85);
    }
    
    //6
    int nativeArea6=rmCreateArea("native6");
    rmSetAreaSize(nativeArea6, .045, .045);
    rmAddAreaConstraint(nativeArea6, circleConstraintTwo); 
    rmSetAreaCoherence(nativeArea6, 1.0);
  
    if(cNumberTeams == 2) {
      rmSetAreaLocation(nativeArea6, 0.145, 0.69);
    }
    
    else {
      rmSetAreaLocation(nativeArea6, 0.2, 0.15);
    }
    
    rmBuildAllAreas();
  
  // always at least one native village of each type
  if (subCiv0 == rmGetCivID(nativeCiv1)) {  
    int nativeVillage1Type = rmRandInt(1,5);
    int nativeVillage1ID = rmCreateGrouping("native village 1", nativeString1+nativeVillage1Type);
    rmSetGroupingMinDistance(nativeVillage1ID, 0.0);
    rmSetGroupingMaxDistance(nativeVillage1ID, 10.0);
    rmAddGroupingToClass(nativeVillage1ID, rmClassID("importantItem"));
    rmAddGroupingConstraint(nativeVillage1ID, nativePlayerConstraint);
    rmAddGroupingConstraint(nativeVillage1ID, avoidTradeRoute);
    rmAddGroupingConstraint(nativeVillage1ID, circleConstraintTwo);
    rmAddGroupingConstraint(nativeVillage1ID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(nativeVillage1ID, avoidImportantItem);
    rmPlaceGroupingInArea(nativeVillage1ID, 0, nativeArea1, 1);
  }	

  if (subCiv1 == rmGetCivID(nativeCiv2)) {  
    int nativeVillage2Type = rmRandInt(1,5);
    int nativeVillage2ID = rmCreateGrouping("native village 2", nativeString2+nativeVillage2Type);
    rmSetGroupingMinDistance(nativeVillage2ID, 0.0);
    rmSetGroupingMaxDistance(nativeVillage2ID, 10.0);
    rmAddGroupingToClass(nativeVillage2ID, rmClassID("importantItem"));
    rmAddGroupingConstraint(nativeVillage2ID, nativePlayerConstraint);
    rmAddGroupingConstraint(nativeVillage2ID, avoidTradeRoute);
    rmAddGroupingConstraint(nativeVillage2ID, circleConstraintTwo);
    rmAddGroupingConstraint(nativeVillage2ID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(nativeVillage2ID, avoidImportantItem);
    rmPlaceGroupingInArea(nativeVillage2ID, 0, nativeArea2, 1);
  }   

  // Two more Natives for four and above
  int whichNative = 0;
  
  if(cNumberNonGaiaPlayers > 3) {
    int randomNativeType = rmRandInt(1,5);
    int randomNativeID = 0;
    whichNative = rmRandInt(1,2);
    if(whichNative == 1)
      randomNativeID = rmCreateGrouping("random village 1a", nativeString1+randomNativeType);
    else
      randomNativeID = rmCreateGrouping("random village 1b", nativeString2+randomNativeType);
    rmSetGroupingMinDistance(randomNativeID, 0.0);
    rmSetGroupingMaxDistance(randomNativeID, 10.0);
    rmAddGroupingToClass(randomNativeID, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID, 0, nativeArea3, 1);
    
    int randomNativeType1 = rmRandInt(1,5);
    int randomNativeID1 = 0;
    whichNative = rmRandInt(1,2);
    if(whichNative == 1)
      randomNativeID1 = rmCreateGrouping("random village 2a", nativeString1+randomNativeType1);
    else
      randomNativeID1 = rmCreateGrouping("random village 2b", nativeString2+randomNativeType1);
    rmSetGroupingMinDistance(randomNativeID1, 0.0);
    rmSetGroupingMaxDistance(randomNativeID1, 10.0);
    rmAddGroupingToClass(randomNativeID1, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID1, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID1, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID1, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID1, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID1, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID1, 0, nativeArea4, 1);
  }
  
  // Two more natives for 6 and above
  if(cNumberNonGaiaPlayers > 5) {
    int randomNativeType2 = rmRandInt(1,5);
    int randomNativeID2 = 0;
    whichNative = rmRandInt(1,2);
    if(whichNative == 1)
      randomNativeID2 = rmCreateGrouping("random village 3a", nativeString1+randomNativeType2);
    else
      randomNativeID2 = rmCreateGrouping("random village 3b", nativeString2+randomNativeType2);
    rmSetGroupingMinDistance(randomNativeID2, 0.0);
    rmSetGroupingMaxDistance(randomNativeID2, 10.0);
    rmAddGroupingToClass(randomNativeID2, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID2, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID2, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID2, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID2, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID2, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID2, 0, nativeArea5, 1);
    
    int randomNativeType3 = rmRandInt(1,5);
    int randomNativeID3 = 0;
    whichNative = rmRandInt(1,2);
    if(whichNative == 1)
      randomNativeID3 = rmCreateGrouping("random village 4a", nativeString1+randomNativeType3);
    else
      randomNativeID3 = rmCreateGrouping("random village 4b", nativeString2+randomNativeType3);
    rmSetGroupingMinDistance(randomNativeID3, 0.0);
    rmSetGroupingMaxDistance(randomNativeID3, 10.0);
    rmAddGroupingToClass(randomNativeID3, rmClassID("importantItem"));
    rmAddGroupingConstraint(randomNativeID3, nativePlayerConstraint);
    rmAddGroupingConstraint(randomNativeID3, avoidTradeRoute);
    rmAddGroupingConstraint(randomNativeID3, circleConstraintTwo);
    rmAddGroupingConstraint(randomNativeID3, avoidTradeRouteSockets);
    rmAddGroupingConstraint(randomNativeID3, avoidImportantItem);
    rmPlaceGroupingInArea(randomNativeID3, 0, nativeArea6, 1);
  }
  
	// Text
	rmSetStatusText("",0.60);

  // Vary some terrain
  for (i=0; < 30) {
    int patch=rmCreateArea("first patch "+i);
    rmSetAreaWarnFailure(patch, false);
    rmSetAreaSize(patch, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
    rmSetAreaTerrainType(patch, patchTerrain1);
    rmAddAreaTerrainLayer(patch, patchType1, 0, 1);
    rmAddAreaToClass(patch, rmClassID("classPatch"));
    rmSetAreaCoherence(patch, 0.8);
	rmAddAreaConstraint(patch, groundAvoidTradeRoute);
	rmAddAreaConstraint(patch, avoidTownCenter);
    rmAddAreaConstraint(patch, shortAvoidImpassableLand);
    rmBuildArea(patch); 
  }

	// Text
	rmSetStatusText("",0.80);
      
  for (i=0; <10) {
    int dirtPatch=rmCreateArea("paint patch "+i);
    rmSetAreaWarnFailure(dirtPatch, false);
    rmSetAreaSize(dirtPatch, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
    rmSetAreaTerrainType(dirtPatch, patchTerrain2);
    rmAddAreaTerrainLayer(dirtPatch, patchType2, 0, 1);
    rmAddAreaToClass(dirtPatch, rmClassID("classPatch"));
    rmSetAreaCoherence(dirtPatch, 0.8);
    //rmSetAreaSmoothDistance(dirtPatch, 10);
    //rmAddAreaConstraint(dirtPatch, shortAvoidImpassableLand);
	rmAddAreaConstraint(dirtPatch, groundAvoidTradeRoute);
	rmAddAreaConstraint(dirtPatch, avoidTownCenter);
    //rmAddAreaConstraint(dirtPatch, patchConstraint);
    rmBuildArea(dirtPatch); 
  }
  
	// Text
	rmSetStatusText("",0.85);

  // check for KOTH game mode
  if(rmGetIsKOTH()) {
    int hillLoc = rmRandInt(1,4);
    rmEchoInfo("Hill Loc = " + hillLoc);
    
    if(teamZeroCount == 1 && teamOneCount == 1 && cNumberTeams == 2){
      if (hillLoc < 3)
        ypKingsHillPlacer(0.75, 0.25, 0, avoidTradeRouteSockets);
      else
        ypKingsHillPlacer(0.25, 0.75, 0, avoidTradeRouteSockets);
    }
    
    else if(cNumberTeams > 2) {
      ypKingsHillPlacer(0.5, 0.5, 0.05, avoidTradeRouteSockets);
    }      

    else  
      ypKingsHillPlacer(0.5, 0.5, .05, avoidTradeRouteSockets);
  }
if(cNumberNonGaiaPlayers>2){  
	// Silver
	int silverID = -1;
 	int silverID2 = -1;

  int silverCount = 0;
  
  if (whichVersion == 2)
	  silverCount = 4;	
  
  else 
    silverCount = 3;
  
	rmEchoInfo("silver count = "+silverCount);

  silverID = rmCreateObjectDef("silver mines"+i);
  rmAddObjectDefItem(silverID, "mine", rmRandInt(1,1), 5.0);
  rmSetObjectDefMinDistance(silverID, 0.0);
  rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(silverID, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID, avoidSilver);
  rmAddObjectDefConstraint(silverID, avoidKOTH);
  rmAddObjectDefConstraint(silverID, longPlayerConstraint);
  rmAddObjectDefConstraint(silverID, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(silverID, avoidTradeRouteSockets);
  rmPlaceObjectDefPerPlayer(silverID, false, silverCount);
 
  silverID2 = rmCreateObjectDef("closer silver mines"+i);
  rmAddObjectDefItem(silverID2, "mine", rmRandInt(1,1), 5.0);
  rmSetObjectDefMinDistance(silverID2, rmXFractionToMeters(0.1));
  rmSetObjectDefMaxDistance(silverID2, rmXFractionToMeters(0.4));
  rmAddObjectDefConstraint(silverID2, avoidImpassableLand);
  rmAddObjectDefConstraint(silverID2, avoidSilver);
  rmAddObjectDefConstraint(silverID2, avoidKOTH);
  rmAddObjectDefConstraint(silverID2, playerConstraint);
  rmAddObjectDefConstraint(silverID2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(silverID2, avoidTradeRouteSockets);
  rmPlaceObjectDefPerPlayer(silverID2, false, silverCount);
}else{
    //1v1 mines
    int topMine = rmCreateObjectDef("topMine");
    rmAddObjectDefItem(topMine, "mine", 1, 1.0);
    rmSetObjectDefMinDistance(topMine, 0.0);
    rmSetObjectDefMaxDistance(topMine, 20);
    rmAddObjectDefConstraint(topMine, avoidSocket2_dk);
    rmAddObjectDefConstraint(topMine, avoidTradeRouteSmall_dk);
    rmAddObjectDefConstraint(topMine, forestConstraintShort_dk);
    rmAddObjectDefConstraint(topMine, avoidGoldTypeFar_dk);
    rmAddObjectDefConstraint(topMine, circleConstraint2_dk);       
    rmAddObjectDefConstraint(topMine, avoidAll_dk); 
    rmAddObjectDefConstraint(topMine, avoidWater5_dk);
    
    
    int basinMineFlip = rmRandInt(0,3);
    //basinMineFlip =3;
    if(basinMineFlip==0){
        //center TR mines
        rmPlaceObjectDefAtLoc(topMine, 0, 0.65, 0.55, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.35, 0.45, 1);

        //far same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.8, 0.25, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.2, 0.75, 1);
        
        //close same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.5, 0.25, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.5, 0.75, 1);
    }else if(basinMineFlip==1){
        //center TR mines
        rmPlaceObjectDefAtLoc(topMine, 0, 0.65, 0.55, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.35, 0.45, 1);

        //now the far mine is closer to the trade route
        //far same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.7, 0.35, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.3, 0.65, 1);
        
        //close same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.55, 0.15, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.45, 0.85, 1);
        
    }else if(basinMineFlip==2){
        //center TR mines are now away from the trade route
        rmPlaceObjectDefAtLoc(topMine, 0, 0.65, 0.45, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.35, 0.55, 1);
        
        //far same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.8, 0.25, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.2, 0.75, 1);
        
        //close same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.5, 0.25, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.5, 0.75, 1);
    }else if(basinMineFlip==3){
        //now the far mine is closer to the trade route
        //center TR mines are now away from the trade route
        rmPlaceObjectDefAtLoc(topMine, 0, 0.45, 0.65, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.55, 0.35, 1);
        
        //far same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.76, 0.32, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.24, 0.68, 1);
        
        //close same side mine
        rmPlaceObjectDefAtLoc(topMine, 0, 0.55, 0.15, 1);
        rmPlaceObjectDefAtLoc(topMine, 0, 0.45, 0.85, 1);
        
    }
    //far opposite side mine
    rmPlaceObjectDefAtLoc(topMine, 0, 0.88, 0.63, 1);
    rmPlaceObjectDefAtLoc(topMine, 0, 0.12, 0.37, 1);


}    
// Forests
	int forestTreeID = 0;
	
	int numTries=10*cNumberNonGaiaPlayers; 
	int failCount=0;
	for (i=0; <numTries)	{   
    int forestID=rmCreateArea("forest"+i);
    rmAddAreaToClass(forestID, rmClassID("classForest"));
    rmSetAreaWarnFailure(forestID, false);
    rmSetAreaSize(forestID, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
    rmSetAreaForestType(forestID, forestType);
    
    if(whichVersion == 2)
      rmSetAreaForestDensity(forestID, 0.4);
    
    else
      rmSetAreaForestDensity(forestID, 0.6);
    
    rmSetAreaForestClumpiness(forestID, 0.4);
    rmSetAreaForestUnderbrush(forestID, 0.6);
    rmSetAreaCoherence(forestID, 0.4);
    rmAddAreaConstraint(forestID, playerConstraint);  
    rmAddAreaConstraint(forestID, shortAvoidResource);			
    rmAddAreaConstraint(forestID, shortAvoidTradeRoute);
    rmAddAreaConstraint(forestID, avoidTradeRouteSockets);
    rmAddAreaConstraint(forestID, avoidMineSockets);
    rmAddAreaConstraint(forestID, avoidKOTH);
    rmAddAreaConstraint(forestID, forestConstraint);
    rmAddAreaConstraint(forestID, shortAvoidImportantItem);
    if(rmBuildArea(forestID)==false)
    {
      // Stop trying once we fail 5 times in a row.  
      failCount++;
      if(failCount==5)
        break;
    }
    else
      failCount=0; 
  } 

	
// *********************** OBJECTS PLACED AFTER FORESTS ********************
	// Resources that can be placed after forests
if(cNumberNonGaiaPlayers>2){  
  if(whichVersion == 1) {
	  rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 3.0*cNumberNonGaiaPlayers);
  }
  
  else if (whichVersion == 2) {
    rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
  }
  
  else {
    rmPlaceObjectDefAtLoc(deerID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
	  rmPlaceObjectDefAtLoc(tapirID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
  }
}else{
    //1v1 hunts
    int mapHunts = rmCreateObjectDef("mapHunts");
    rmAddObjectDefItem(mapHunts, huntable1, 8, 6.0);
    rmSetObjectDefCreateHerd(mapHunts, true);
    rmSetObjectDefMinDistance(mapHunts, 0);
    rmSetObjectDefMaxDistance(mapHunts, 14);
    rmAddObjectDefConstraint(mapHunts, forestConstraintShort_dk);	
    rmAddObjectDefConstraint(mapHunts, avoidHunt2_dk);
    rmAddObjectDefConstraint(mapHunts, avoidAll_dk);       
    rmAddObjectDefConstraint(mapHunts, circleConstraint2_dk);   
    rmAddObjectDefConstraint(mapHunts, avoidWater5_dk);
    
    int mapHuntsDeer = rmCreateObjectDef("mapHuntsDeer");
    rmAddObjectDefItem(mapHuntsDeer, huntable2, 8, 6.0);
    rmSetObjectDefCreateHerd(mapHuntsDeer, true);
    rmSetObjectDefMinDistance(mapHuntsDeer, 0);
    rmSetObjectDefMaxDistance(mapHuntsDeer, 14);
    rmAddObjectDefConstraint(mapHuntsDeer, forestConstraintShort_dk);	
    rmAddObjectDefConstraint(mapHuntsDeer, avoidHunt2_dk);
    rmAddObjectDefConstraint(mapHuntsDeer, avoidAll_dk);       
    rmAddObjectDefConstraint(mapHuntsDeer, circleConstraint2_dk);   
    rmAddObjectDefConstraint(mapHuntsDeer, avoidWater5_dk);
    
    //pocket hunt
    rmPlaceObjectDefAtLoc(mapHunts, 0, 0.12, 0.33, 1);
    rmPlaceObjectDefAtLoc(mapHunts, 0, 0.88, 0.67, 1);
    int huntVar=rmRandInt(1,2);
    //huntVar=1;
    if(huntVar==1){
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.8, 0.4, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.2, 0.6, 1);
        
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.65, 0.35, 1);
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.35, 0.65, 1);
        
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.42, 0.34, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.58, 0.66, 1);

        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.7, 0.15, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.3, 0.85, 1);

        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.45, 0.1, 1);
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.55, 0.9, 1);
    }else{
        //center lines
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.5, 0.5, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.655, 0.595, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.345, 0.405, 1);

        //end of TR lines
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.15, 0.55, 1);
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.85, 0.45, 1);

        //Trio
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.55, 0.1, 1);
        rmPlaceObjectDefAtLoc(mapHuntsDeer, 0, 0.45, 0.9, 1);
        //Trio pt 2     
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.55, 0.3, 1);
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.45, 0.7, 1);
        //trio pt 3
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.77, 0.22, 1);
        rmPlaceObjectDefAtLoc(mapHunts, 0, 0.23, 0.78, 1);
    }

}
	// Text
	rmSetStatusText("",0.90);
	
	// Nuggets
  
  int nugget1= rmCreateObjectDef("nugget easy"); 
  rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(1, 1);
  rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget1, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget1, shortAvoidResource);
  rmAddObjectDefConstraint(nugget1, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget1, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget1, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget1, playerConstraint);
  rmAddObjectDefConstraint(nugget1, circleConstraint);
  rmSetObjectDefMinDistance(nugget1, 40.0);
  rmSetObjectDefMaxDistance(nugget1, 60.0);
  rmPlaceObjectDefPerPlayer(nugget1, false, 2);

  int nugget2= rmCreateObjectDef("nugget medium"); 
  rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(2, 2);
  rmSetObjectDefMinDistance(nugget2, 0.0);
  rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget2, shortAvoidResource);
  rmAddObjectDefConstraint(nugget2, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget2, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget2, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget2, mediumPlayerConstraint);
  rmAddObjectDefConstraint(nugget2, circleConstraint);
  rmSetObjectDefMinDistance(nugget2, 80.0);
  rmSetObjectDefMaxDistance(nugget2, 120.0);
  rmPlaceObjectDefPerPlayer(nugget2, false, 1);

  int nugget3= rmCreateObjectDef("nugget hard"); 
  rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
  rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nugget3, 0.0);
  rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget3, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget3, shortAvoidResource);
  rmAddObjectDefConstraint(nugget3, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget3, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget3, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget3, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget3, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget3, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

  int nugget4= rmCreateObjectDef("nugget nuts"); 
  rmAddObjectDefItem(nugget4, "Nugget", 1, 0.0);
  if(cNumberNonGaiaPlayers==2 || rmGetIsTreaty() == true){
    rmSetNuggetDifficulty(3, 3);
  }else{
    rmSetNuggetDifficulty(4, 4);
  }
  rmSetObjectDefMinDistance(nugget4, 0.0);
  rmSetObjectDefMaxDistance(nugget4, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nugget4, avoidImpassableLand);
  rmAddObjectDefConstraint(nugget4, shortAvoidImportantItem);
  rmAddObjectDefConstraint(nugget4, shortAvoidResource);
  rmAddObjectDefConstraint(nugget4, avoidNuggetFar);
  rmAddObjectDefConstraint(nugget4, shortAvoidTradeRoute);
  rmAddObjectDefConstraint(nugget4, avoidTradeRouteSocketsFar);
  rmAddObjectDefConstraint(nugget4, playerConstraintNugget);
  rmAddObjectDefConstraint(nugget4, circleConstraint);
  rmPlaceObjectDefAtLoc(nugget4, 0, 0.5, 0.5, rmRandInt(2,3));

if(cNumberNonGaiaPlayers>2){
    int herdableID=rmCreateObjectDef("herdables");
    rmAddObjectDefItem(herdableID, herdableType, 2, 5.0);
    rmSetObjectDefMinDistance(herdableID, 0.0);
    rmSetObjectDefMaxDistance(herdableID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(herdableID, avoidHerdable);
    rmAddObjectDefConstraint(herdableID, avoidAll);
    rmAddObjectDefConstraint(herdableID, longPlayerConstraint);
    rmAddObjectDefConstraint(herdableID, avoidImpassableLand);
    rmAddObjectDefConstraint(herdableID, avoidTradeRoute);
  
  if(whichVersion == 2)
	  rmPlaceObjectDefAtLoc(herdableID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2.5);
}else if(whichVersion==2){
    //1v1 herds -- only place if whichVersion == 2
    int mapCows = rmCreateObjectDef("mapCows");
    rmAddObjectDefItem(mapCows, herdableType, 1, 1.0);
    rmSetObjectDefMinDistance(mapCows, 0);
    rmSetObjectDefMaxDistance(mapCows, 20);
    rmAddObjectDefConstraint(mapCows, forestConstraintShort_dk);	
    rmAddObjectDefConstraint(mapCows, avoidCow_dk);
    rmAddObjectDefConstraint(mapCows, avoidAll_dk);       
    rmAddObjectDefConstraint(mapCows, circleConstraint2_dk);   
    rmAddObjectDefConstraint(mapCows, avoidWater5_dk);
    
    int herdVariation=rmRandInt(1,2);
    //herdVariation=2;
    if(herdVariation==1){
        //2 in the basins, 1 in the pocket, 1 in the center
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.5, 0.5, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.45, 0.8, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.55, 0.2, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.75, 0.3, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.25, 0.7, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.9, 0.7, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.1, 0.3, 1);
    }else{
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.55, 0.7, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.45, 0.3, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.75, 0.35, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.25, 0.65, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.85, 0.65, 1);
        rmPlaceObjectDefAtLoc(mapCows, 0, 0.15, 0.35, 1);
    }
}   
 
  for(i = 1; < cNumberPlayers) {      
//    if ( rmGetPlayerCiv(i) == rmGetCivID("Ottomans")){
      rmCreateTrigger("XP"+i);
      rmSwitchToTrigger(rmTriggerID("XP"+i));
      rmSetTriggerPriority(4); 
      rmSetTriggerActive(true);
      rmSetTriggerRunImmediately(true);
      rmSetTriggerLoop(false);
        
      rmAddTriggerCondition("Always");
      
      rmAddTriggerEffect("Grant Resources");
      rmSetTriggerEffectParamInt("PlayerID", i, false);
      rmSetTriggerEffectParam("ResName", "XP", false);
      rmSetTriggerEffectParam("Amount", "50", false);
//    }
  }
    
	// Text
	rmSetStatusText("",0.99);
}  
