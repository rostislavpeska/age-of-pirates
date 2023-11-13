// Venice 10/2023

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   // Text
   // These status text lines are used to manually animate the map generation progress bar
   rmSetStatusText("",0.01);

  int whichVersion = 1;
   
  // initialize map type variables 
  string nativeCiv1 = "zpvenetians";
  string nativeCiv2 = "maltese";
  string nativeCiv3 = "spcjesuit";
  string nativeCiv4 = "zporthodox";
  string baseMix = "italy_grass";
  string paintMix = "italy_grass_lush";
  string baseTerrain = "borneo\ground_grass4_borneo";
  string playerTerrain = "borneo\ground_sand3_borneo";
  string seaType = "ZP Adralic coast";
  string startTreeType = "TreeGreatLakes";
  string forestType = "Italian Forest";  // Borneo Forest
  string forestType2 = "Borneo Palm Forest";
  string patchTerrain = "borneo\ground_grass3_borneo";
  string patchType1 = "borneo\ground_grass5_borneo";
  string patchType2 = "borneo\ground_forest_borneo";
  string mapType1 = "italy";
  string mapType2 = "grass";
  string herdableType = "ypWaterBuffalo";
  string huntable1 = "Deer";
  string huntable2 = "ypIbex";
  string fish1 = "ypFishTuna";
  string fish2 = "ypFishTuna";
  string whale1 = "MinkeWhale";
  string lightingType = "Florida_Skirmish";
  
  bool weird = false;
  int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);
    
  // FFA and imbalanced teams
  if ( cNumberTeams > 2)
    weird = true;
  
  rmEchoInfo("weird = "+weird);

  int monasteryPlacement = rmRandInt(1,2);
  
// Natives
   int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

  if (rmAllocateSubCivs(3) == true)
  {
		  // Venetians
		  subCiv0=rmGetCivID(nativeCiv1);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, nativeCiv1);

		  // Maltese or Orthodox
      if (monasteryPlacement == 2){
        subCiv1=rmGetCivID(nativeCiv2);
        if (subCiv1 >= 0)
          rmSetSubCiv(1, nativeCiv2);
      }
      if (monasteryPlacement == 1){
        subCiv1=rmGetCivID(nativeCiv4);
        if (subCiv1 >= 0)
          rmSetSubCiv(1, nativeCiv4);
      }

      // Jesuit
		  subCiv2=rmGetCivID(nativeCiv3);
      if (subCiv2 >= 0)
         rmSetSubCiv(2, nativeCiv3);
  }
	
// Map Basics
	int playerTiles = 16000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 16000;
  if (cNumberNonGaiaPlayers ==4)
		playerTiles = 18000;
  if (cNumberNonGaiaPlayers ==3)
		playerTiles = 22000;
  if (cNumberNonGaiaPlayers ==2)
		playerTiles = 24000;
  if (cNumberNonGaiaPlayers ==1)
		playerTiles = 64000;
	if (cNumberNonGaiaPlayers >6)
		playerTiles = 15000;		

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);

	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 10, 0.4, 7.0);
	rmSetMapElevationHeightBlend(4);
	
	rmSetSeaLevel(1.0);
	rmSetLightingSet(lightingType);
  rmSetOceanReveal(true);


	rmSetSeaType(seaType);
	rmSetBaseTerrainMix(baseMix);
	rmTerrainInitialize("deccan\ground_grass3_deccan", 1);
	rmSetMapType(mapType1);
	rmSetMapType(mapType2);
	rmSetMapType("water");
  rmSetMapType("mediEurope");
  rmSetMapType("euroNavalTradeRoute");
  rmSetMapType("adralicsea");
	rmSetWorldCircleConstraint(true);
	rmSetWindMagnitude(3.0);

	chooseMercs();
	
// Classes
	int classPlayer=rmDefineClass("player");
	int classSocket=rmDefineClass("socketClass");
  int classIsland=rmDefineClass("island");
  int classBonusIsland=rmDefineClass("bonusIsland");
	rmDefineClass("classPatch");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
  int classPortSite=rmDefineClass("portSite");
  int classMountains=rmDefineClass("mountains");

// Constraints
    
	// Map edge constraints
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

	// Player constraints
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 20.0);
  int longPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players long", classPlayer, 35.0);
  int playerConstraintNugget=rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 55.0);
  int playerConstraintNative=rmCreateClassDistanceConstraint("natives stay away from players far", classPlayer, 75.0);
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 10.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("short stay away from players", classPlayer, 5.0);
  int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 100.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
   int avoidBonusIslandsShort=rmCreateClassDistanceConstraint("stuff avoids bonus islands short", classBonusIsland, 40.0);

	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 7.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 10.0);
	int shortAvoidResource=rmCreateTypeDistanceConstraint("resource avoid resource short", "resource", 5.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
	int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 8.0);
  int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);
  int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 20.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
  int riverGrass = rmCreateTerrainMaxDistanceConstraint("stay near the water", "land", false, 6.0);
  int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);

  // resource avoidance
	int avoidSilver=rmCreateTypeDistanceConstraint("avoid silver", "mine", 65.0);
  int avoidHuntable1=rmCreateTypeDistanceConstraint("avoid huntable1", huntable1, 60.0);
	int avoidHuntable2=rmCreateTypeDistanceConstraint("avoid huntable2", huntable2, 60.0);
  int avoidNuggetsShort=rmCreateTypeDistanceConstraint("vs nugget short", "AbstractNugget", 10.0);
  int avoidNugget=rmCreateTypeDistanceConstraint("nugget vs. nugget", "AbstractNugget", 40.0);
	int avoidNuggetsFar=rmCreateTypeDistanceConstraint("nugget vs. nugget far", "AbstractNugget", 70.0);
  int avoidNuggetWater=rmCreateTypeDistanceConstraint("nugget vs. nugget water", "AbstractNugget", 65.0);
  int avoidHerdable=rmCreateTypeDistanceConstraint("herdables avoid herdables", herdableType, 75.0);
  int avoidBerries=rmCreateTypeDistanceConstraint("avoid berries", "berrybush", 55.0);

	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
  int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "mine", 40.0);

	// Unit avoidance
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 90.0);
	int shortAvoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other short", rmClassID("importantItem"), 8.0);
    int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 10.0);

	// general avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);
  int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0);
  int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 48.0);
  int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
  int portSiteConstraint=rmCreateClassDistanceConstraint("land far from port site", classPortSite, 35.0);

  // fish & whale constraints
  int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", fish1, 15.0);	
	int fishVsFish2ID=rmCreateTypeDistanceConstraint("fish v fish2", fish2, 15.0); 
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);			
  
  int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", whale1, 45.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 20.0);
  int whaleEdgeConstraint=rmCreatePieConstraint("whale edge of map", 0.5, 0.5, 0, rmGetMapXSize()-20, 0, 0, 0);

  // flag constraints
  int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
  int nuggetVsFlag = rmCreateTypeDistanceConstraint("nugget v flag", "HomeCityWaterSpawnFlag", 8.0);
	int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 25.0);
  int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpVenetianWaterSpawnFlag1", 40.0);
  int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpVenetianWaterSpawnFlag2", 40.0);
	int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  
  int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 10.0);

    //dk
    int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 5.0);
    int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "Socket", 20.0);
    int avoidSocket2=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 40.0);
    int avoidTradeRouteSmall = rmCreateTradeRouteDistanceConstraint("objects avoid trade route small", 6.0);
    int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("classForest"), 4.0);
    int avoidHunt2=rmCreateTypeDistanceConstraint("herds avoid herds2", "huntable", 32.0);
    int avoidHunt3=rmCreateTypeDistanceConstraint("herds avoid herds3", "huntable", 14.0);
	  int avoidAll2=rmCreateTypeDistanceConstraint("avoid all2", "all", 4.0);
    int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("avoid gold type  far 2", "gold", 32.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));

  // Avoid Water
  int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
  int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
  int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
  int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 30.0);

  // Trade route constraints
  int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 9.0);
  int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 41.0);
  int avoidController=rmCreateTypeDistanceConstraint("stay away from Controller", "zpSPCWaterSpawnPoint", 40.0);
  int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 0.0);
  int ObjectAvoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("object avoid trade route short", 3.0);
  int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
  int avoidControllerShort=rmCreateTypeDistanceConstraint("stay away from Controller Short", "zpSPCWaterSpawnPoint", 25.0);
  int avoidControllerFar=rmCreateTypeDistanceConstraint("stay away from Controller Far", "zpSPCWaterSpawnPoint", 60.0);
   int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "zpSPCPortSocket", 10.0);
   int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket Far", "zpSPCPortSocket", 35.0);

// ************************** DEFINE OBJECTS ****************************
	
  
  
  int startFoodID=rmCreateObjectDef("starting herd");
	rmAddObjectDefItem(startFoodID, huntable1, 8, 4.0);
	rmSetObjectDefMinDistance(startFoodID, 12.0);
	rmSetObjectDefMaxDistance(startFoodID, 18.0);
	rmSetObjectDefCreateHerd(startFoodID, true);
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable1);    
//	rmAddObjectDefConstraint(startFoodID, avoidHuntable2);    
  
  int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, startTreeType, 10, 7.0);
	rmSetObjectDefMinDistance(StartAreaTreeID, 16);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 20);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidStartResource);
	rmAddObjectDefConstraint(StartAreaTreeID, shortAvoidImpassableLand);

int avoidStartingGold_dk =rmCreateTypeDistanceConstraint("starting berries avoid starting coin dk", "Mine", 16.0);

	int StartBerriesID=rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(StartBerriesID, "berrybush", 4, 4.0);
	rmSetObjectDefMinDistance(StartBerriesID, 10);
	rmSetObjectDefMaxDistance(StartBerriesID, 15);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartResource);
  rmAddObjectDefConstraint(StartBerriesID, avoidSocket2);
	rmAddObjectDefConstraint(StartBerriesID, avoidStartingGold_dk);
	rmAddObjectDefConstraint(StartBerriesID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(StartBerriesID, shortPlayerConstraint);

  int startSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(startSilverID, "mine", 1, 0);
	rmSetObjectDefMinDistance(startSilverID, 12.0);
	rmSetObjectDefMaxDistance(startSilverID, 20.0);
	rmAddObjectDefConstraint(startSilverID, avoidAll);
  rmAddObjectDefConstraint(startSilverID, avoidSocket2);
	rmAddObjectDefConstraint(startSilverID, avoidImpassableLand);

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
  rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);
  
  int playerNuggetID=rmCreateObjectDef("player nugget");
  rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
  rmSetObjectDefMinDistance(playerNuggetID, 15.0);
  rmSetObjectDefMaxDistance(playerNuggetID, 18.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
  rmAddObjectDefConstraint(playerNuggetID, avoidSocket2);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);
  
  int playerLombardID=rmCreateObjectDef("player lombard");
  rmAddObjectDefItem(playerLombardID, "deLombard", 1, 0.0);
  rmSetObjectDefMinDistance(playerLombardID, 12.0);
  rmSetObjectDefMaxDistance(playerLombardID, 16.0);
	rmAddObjectDefConstraint(playerLombardID, avoidAll);
  rmAddObjectDefConstraint(playerLombardID, avoidSocket2);
	rmAddObjectDefConstraint(playerLombardID, avoidImpassableLand);
  
  int playerSaloonID=rmCreateObjectDef("player saloon");
  rmAddObjectDefItem(playerSaloonID, "deTavern", 1, 0.0);
  rmSetObjectDefMinDistance(playerSaloonID, 12.0);
  rmSetObjectDefMaxDistance(playerSaloonID, 16.0);
	rmAddObjectDefConstraint(playerSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerSaloonID, avoidImpassableLand);
  
  int playerCommunityPlazaID=rmCreateObjectDef("player community plaza");
  rmAddObjectDefItem(playerCommunityPlazaID, "CommunityPlaza", 1, 0.0);
  rmSetObjectDefMinDistance(playerCommunityPlazaID, 12.0);
  rmSetObjectDefMaxDistance(playerCommunityPlazaID, 16.0);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidAll);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidImpassableLand);
  
  int playerMonID=rmCreateObjectDef("player monastery");
  rmAddObjectDefItem(playerMonID, "ypMonastery", 1, 0.0);
  rmSetObjectDefMinDistance(playerMonID, 12.0);
  rmSetObjectDefMaxDistance(playerMonID, 16.0);
	rmAddObjectDefConstraint(playerMonID, avoidAll);
	rmAddObjectDefConstraint(playerMonID, avoidImpassableLand);
	
  int playerUSSaloonID=rmCreateObjectDef("player USsaloon");
  rmAddObjectDefItem(playerUSSaloonID, "Saloon", 1, 0.0);
  rmSetObjectDefMinDistance(playerUSSaloonID, 12.0);
  rmSetObjectDefMaxDistance(playerUSSaloonID, 16.0);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidImpassableLand);
   
  int playerAfrTowerID=rmCreateObjectDef("player afr tower");
  rmAddObjectDefItem(playerAfrTowerID, "deTower", 1, 0.0);
  rmSetObjectDefMinDistance(playerAfrTowerID, 12.0);
  rmSetObjectDefMaxDistance(playerAfrTowerID, 16.0);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidAll);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidImpassableLand);
      
	// -------------Done defining objects
  // Text
  rmSetStatusText("",0.10);
  
  // Make the island





  //~ if(cNumberNonGaiaPlayers > 4)
    	//~ rmSetAreaSize(mainIslandID, 0.6, 0.6);
      
  //~ else

  int mapVariation = rmRandInt(1, 2);

  int seaLakeID=rmCreateArea("Sea Lake");
	rmSetAreaWaterType(seaLakeID, seaType);

  if (mapVariation == 1)
	rmSetAreaSize(seaLakeID, 1.0, 1.0);

  else
  rmSetAreaSize(seaLakeID, 0.82, 0.82);

	rmSetAreaCoherence(seaLakeID, 0.9);
	rmSetAreaLocation(seaLakeID, 0.5, 0.4);
	rmSetAreaBaseHeight(seaLakeID, 1.0);
	rmSetAreaObeyWorldCircleConstraint(seaLakeID, false);
	rmSetAreaSmoothDistance(seaLakeID, 10);
	rmBuildArea(seaLakeID); 

  // Trade Route
  int tradeRouteID = rmCreateTradeRoute();
  rmSetObjectDefTradeRouteID(tradeRouteID);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.82);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.7);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.65);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.55);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.45);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.35);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.3);
  rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.0);

  bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "water_trail");

  // Place Controllers
    int controllerID1 = rmCreateObjectDef("Controler 1");
    rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmSetObjectDefMinDistance(controllerID1, 0.0);
    rmSetObjectDefMaxDistance(controllerID1, 0.0);
    
    if (cNumberNonGaiaPlayers >= 4)
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.6, 0.8);

    else
    rmPlaceObjectDefAtLoc(controllerID1, 0, 0.63, 0.8);


    vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));

    int controllerID2 = rmCreateObjectDef("Controler 2");
    rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmSetObjectDefMinDistance(controllerID2, 0.0);
    rmSetObjectDefMaxDistance(controllerID2, 0.0);
     
    if (cNumberNonGaiaPlayers >= 4)
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.4, 0.8);

    else
    rmPlaceObjectDefAtLoc(controllerID2, 0, 0.37, 0.8);

    vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));


    // Bonus Island

    if (mapVariation == 1){

      int bonusIslandID = rmCreateArea ("bonus island");

      rmSetAreaSize(bonusIslandID, 0.02, 0.02);
      rmSetAreaObeyWorldCircleConstraint(bonusIslandID, false);
      rmSetAreaElevationType(bonusIslandID, cElevTurbulence);
      rmSetAreaLocation(bonusIslandID, 0.5, 1.0);
      rmSetAreaCoherence(bonusIslandID, 0.7);
      rmSetAreaSmoothDistance(bonusIslandID, 15);
      rmSetAreaMix(bonusIslandID, baseMix);
      rmSetAreaBaseHeight(bonusIslandID, 1.0);
      rmAddAreaToClass(bonusIslandID, classIsland);
      rmAddAreaConstraint(bonusIslandID, islandAvoidTradeRoute);
      rmBuildArea(bonusIslandID);

    }


  // Port Sites
   int portSite1 = rmCreateArea ("port_site1");
   rmSetAreaSize(portSite1, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite1, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(19), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)));
   rmSetAreaMix(portSite1, baseMix);
   rmSetAreaCoherence(portSite1, 1);
   rmSetAreaSmoothDistance(portSite1, 15);
   rmSetAreaBaseHeight(portSite1, 1.0);
   rmAddAreaToClass(portSite1, classPortSite);
   rmBuildArea(portSite1);

   int portSite2 = rmCreateArea ("port_site2");
   rmSetAreaSize(portSite2, rmAreaTilesToFraction(600.0), rmAreaTilesToFraction(600.0));
   rmSetAreaLocation(portSite2, rmXMetersToFraction(xsVectorGetX(ControllerLoc2))-rmXTilesToFraction(19), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)));
   rmSetAreaMix(portSite2, baseMix);
   rmSetAreaCoherence(portSite2, 1);
   rmSetAreaSmoothDistance(portSite2, 15);
   rmSetAreaBaseHeight(portSite2, 1.0);
   rmAddAreaToClass(portSite2, classPortSite);
   rmBuildArea(portSite2);

   int portSite3 = rmCreateArea ("port_site3");
   rmSetAreaSize(portSite3, 0.009, 0.009);
   rmSetAreaLocation(portSite3, 0.5, 0.85+rmZTilesToFraction(16));
   rmSetAreaMix(portSite3, baseMix);
   rmSetAreaCoherence(portSite3, 1);
   rmSetAreaSmoothDistance(portSite3, 15);
   rmSetAreaBaseHeight(portSite3, 2.0);
   rmAddAreaToClass(portSite3, classPortSite);
   rmAddAreaToClass(portSite3, classBonusIsland);
   rmAddAreaInfluenceSegment(portSite3, 0.5, 0.85+rmZTilesToFraction(16), 0.5, 1.0);
   rmBuildArea(portSite3);

   int portSite4 = rmCreateArea ("port_site4");
   rmSetAreaSize(portSite4, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(portSite4, 0.55+rmZTilesToFraction(19), 0.65);
   rmSetAreaMix(portSite4, baseMix);
   rmSetAreaCoherence(portSite4, 1);
   rmSetAreaSmoothDistance(portSite4, 15);
   rmSetAreaBaseHeight(portSite4, 2.0);
   rmAddAreaToClass(portSite4, classPortSite);
   rmBuildArea(portSite4);

   int portSite5 = rmCreateArea ("port_site5");
   rmSetAreaSize(portSite5, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(portSite5, 0.55+rmZTilesToFraction(19), 0.45);
   rmSetAreaMix(portSite5, baseMix);
   rmSetAreaCoherence(portSite5, 1);
   rmSetAreaSmoothDistance(portSite5, 15);
   rmSetAreaBaseHeight(portSite5, 2.0);
   rmAddAreaToClass(portSite5, classPortSite);
   rmBuildArea(portSite5);

   int portSite6 = rmCreateArea ("port_site6");
   rmSetAreaSize(portSite6, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(portSite6, 0.45-rmZTilesToFraction(19), 0.55);
   rmSetAreaMix(portSite6, baseMix);
   rmSetAreaCoherence(portSite6, 1);
   rmSetAreaSmoothDistance(portSite6, 15);
   rmSetAreaBaseHeight(portSite6, 2.0);
   rmAddAreaToClass(portSite6, classPortSite);
   rmBuildArea(portSite6);

   int portSite7 = rmCreateArea ("port_site7");
   rmSetAreaSize(portSite7, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(400.0));
   rmSetAreaLocation(portSite7, 0.45-rmZTilesToFraction(19), 0.35);
   rmSetAreaMix(portSite7, baseMix);
   rmSetAreaCoherence(portSite7, 1);
   rmSetAreaSmoothDistance(portSite7, 15);
   rmSetAreaBaseHeight(portSite7, 2.0);
   rmAddAreaToClass(portSite7, classPortSite);
   rmBuildArea(portSite7);

   // Venice Settlements

      int veniceVillageID = -1;
      veniceVillageID = rmCreateGrouping("venice city", "Venice_01");

      rmPlaceGroupingAtLoc(veniceVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))-rmXTilesToFraction(5), 1);

      int venicewaterflagID1 = rmCreateObjectDef("venice water flag 1");
      rmAddObjectDefItem(venicewaterflagID1, "zpVenetianWaterSpawnFlag1", 1, 1.0);
      rmPlaceObjectDefAtLoc(venicewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(6), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))-rmXTilesToFraction(14));


      int veniceVillageID2 = -1;
      veniceVillageID2 = rmCreateGrouping("venice city 2", "Venice_02");

      rmPlaceGroupingAtLoc(veniceVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

      int venicewaterflagID2 = rmCreateObjectDef("venice water flag 2");
      rmAddObjectDefItem(venicewaterflagID2, "zpVenetianWaterSpawnFlag2", 1, 1.0);
      rmPlaceObjectDefAtLoc(venicewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2))-rmXTilesToFraction(6), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2))-rmXTilesToFraction(14));

    // Place Ports

    int Port1ID = -1;
      Port1ID = rmCreateGrouping("venice harbour 01", "Venice_Harbour_01");

      if (cNumberNonGaiaPlayers <= 2){
      rmPlaceGroupingAtLoc(Port1ID, 0, 0.5, 0.85+rmZTilesToFraction(8), 1);
      }

      if (cNumberNonGaiaPlayers > 6){
      rmPlaceGroupingAtLoc(Port1ID, 0, 0.5, 0.85+rmZTilesToFraction(6), 1);
      }

      else{
      rmPlaceGroupingAtLoc(Port1ID, 0, 0.5, 0.85+rmZTilesToFraction(7), 1);
      }

      int Port2ID = -1;
      Port2ID = rmCreateGrouping("venice harbour 02", "Venice_Harbour_02");

      rmPlaceGroupingAtLoc(Port2ID, 0, 0.55+rmZTilesToFraction(9), 0.65, 1);
      rmPlaceGroupingAtLoc(Port2ID, 0, 0.55+rmZTilesToFraction(9), 0.45, 1);

      int Port3ID = -1;
      Port3ID = rmCreateGrouping("venice harbour 03", "Venice_Harbour_03");

      rmPlaceGroupingAtLoc(Port3ID, 0, 0.45-rmZTilesToFraction(9), 0.55, 1);
      rmPlaceGroupingAtLoc(Port3ID, 0, 0.45-rmZTilesToFraction(9), 0.35, 1);

      
// Text
	rmSetStatusText("",0.20);


  int mainIslandID=rmCreateArea("italy");
  rmSetAreaSize(mainIslandID, 0.23, 0.23);
  
	rmSetAreaCoherence(mainIslandID, 0.7);
	rmSetAreaBaseHeight(mainIslandID, 3.0);
  rmSetAreaLocation(mainIslandID, 0.1, 0.5);
	rmSetAreaSmoothDistance(mainIslandID, 20);
	rmSetAreaMix(mainIslandID, baseMix);
    
	rmSetAreaObeyWorldCircleConstraint(mainIslandID, false);
	rmSetAreaElevationType(mainIslandID, cElevTurbulence);
	rmSetAreaElevationVariation(mainIslandID, 4.0);
	rmSetAreaElevationMinFrequency(mainIslandID, 0.09);
	rmSetAreaElevationOctaves(mainIslandID, 3);
	rmSetAreaElevationPersistence(mainIslandID, 0.2);
	rmSetAreaElevationNoiseBias(mainIslandID, 1);
  rmAddAreaInfluenceSegment(mainIslandID, 0.2, 0.8, 0.2, 0.3);

  rmAddAreaConstraint(mainIslandID, islandAvoidTradeRoute);
  rmAddAreaConstraint(mainIslandID, avoidController);
  rmAddAreaConstraint(mainIslandID, avoidKOTH);
  
	rmSetAreaWarnFailure(mainIslandID, false);
	rmBuildArea(mainIslandID);

  int mainIslandID2=rmCreateArea("balcan");
  rmSetAreaSize(mainIslandID2, 0.23, 0.23);
  
	rmSetAreaCoherence(mainIslandID2, 0.7);
	rmSetAreaBaseHeight(mainIslandID2, 3.0);
  rmSetAreaLocation(mainIslandID2, 0.9, 0.5);
	rmSetAreaSmoothDistance(mainIslandID2, 20);
	rmSetAreaMix(mainIslandID2, baseMix);
    
	rmSetAreaObeyWorldCircleConstraint(mainIslandID2, false);
	rmSetAreaElevationType(mainIslandID2, cElevTurbulence);
	rmSetAreaElevationVariation(mainIslandID2, 4.0);
	rmSetAreaElevationMinFrequency(mainIslandID2, 0.09);
	rmSetAreaElevationOctaves(mainIslandID2, 3);
	rmSetAreaElevationPersistence(mainIslandID2, 0.2);
	rmSetAreaElevationNoiseBias(mainIslandID2, 1);
  rmAddAreaInfluenceSegment(mainIslandID2, 0.8, 0.8, 0.8, 0.3);

  rmAddAreaConstraint(mainIslandID2, islandAvoidTradeRoute);
  rmAddAreaConstraint(mainIslandID2, avoidController);
  rmAddAreaConstraint(mainIslandID2, avoidKOTH);
  
	rmSetAreaWarnFailure(mainIslandID2, false);
	rmBuildArea(mainIslandID2);
  
  int eastIslandConstraint=rmCreateAreaConstraint("east island", mainIslandID);
  int westIslandConstraint=rmCreateAreaConstraint("west Island", mainIslandID2);

  // Text
	rmSetStatusText("",0.30);


  // Team Jesuit


    // Monastery ID 1



    int zenControllerID1 = rmCreateObjectDef("zen controller 1");
    rmAddObjectDefItem(zenControllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmSetObjectDefMinDistance(zenControllerID1, 0.0);
    rmAddObjectDefConstraint(zenControllerID1, playerEdgeConstraint); 

    if (monasteryPlacement == 1)
    {
        rmPlaceObjectDefAtLoc(zenControllerID1, 0, 0.2, 0.25);
    }
    else 
    {
        rmPlaceObjectDefAtLoc(zenControllerID1, 0, 0.8, 0.25);
    }

    vector zenControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID1, 0));

    int westIslandVillage1 = rmCreateArea("west island village 1");
    int westIslandVillage1ramp = rmCreateArea("west island village1 ramp 1");

    rmSetAreaSize(westIslandVillage1ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
    rmSetAreaLocation(westIslandVillage1ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc1) + 30));
    rmSetAreaBaseHeight(westIslandVillage1ramp, 7.2);
    rmSetAreaCoherence(westIslandVillage1ramp, 0.8);
    rmSetAreaMix(westIslandVillage1ramp, baseMix);
    rmSetAreaSmoothDistance(westIslandVillage1ramp, 30);
    rmBuildArea(westIslandVillage1ramp);

    rmSetAreaSize(westIslandVillage1, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
    rmSetAreaLocation(westIslandVillage1, rmXMetersToFraction(xsVectorGetX(zenControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc1)));
    rmSetAreaCoherence(westIslandVillage1, 0.8);
    rmSetAreaSmoothDistance(westIslandVillage1, 5);
    rmSetAreaCliffType(westIslandVillage1, "Italian Cliff");
    rmSetAreaCliffEdge(westIslandVillage1, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(westIslandVillage1, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(westIslandVillage1, 5.2);
    rmSetAreaElevationVariation(westIslandVillage1, 0.0);
    rmBuildArea(westIslandVillage1);

    int westIslandVillage1Terrain = rmCreateArea ("village 1 terrain");
    rmSetAreaSize(westIslandVillage1Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
    rmSetAreaLocation(westIslandVillage1Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc1)));
    rmSetAreaCoherence(westIslandVillage1Terrain, 0.8);
    rmSetAreaMix(westIslandVillage1Terrain, paintMix);
    rmBuildArea(westIslandVillage1Terrain);

    int middleSufiVillageID1 = -1;
    int middleSufiVillageID1Type = rmRandInt(1, 3);
    middleSufiVillageID1 = rmCreateGrouping("native1 city", "Jesuit_Cathedral_EU_0" + middleSufiVillageID1Type);
    rmAddGroupingConstraint(middleSufiVillageID1, avoidImpassableLand);
    rmPlaceGroupingAtLoc(middleSufiVillageID1, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc1)), 1);



    // Monastery 2
    if (cNumberNonGaiaPlayers >2) {
      int zenControllerID2 = rmCreateObjectDef("zen controller 2");
      rmAddObjectDefItem(zenControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID2, 0.0);
      rmAddObjectDefConstraint(zenControllerID2, avoidController); 
      rmAddObjectDefConstraint(zenControllerID2, playerEdgeConstraint); 

      if (monasteryPlacement == 1)
      {
      rmPlaceObjectDefAtLoc(zenControllerID2, 0, 0.2, 0.65);
      }
      else 
      {
      rmPlaceObjectDefAtLoc(zenControllerID2, 0, 0.8, 0.65);
      }

      vector zenControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID2, 0));

      int eastIslandVillage2 = rmCreateArea ("east island village 2");

      int eastIslandVillage2ramp = rmCreateArea ("east island village2 ramp 1");



      rmSetAreaSize(eastIslandVillage2ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage2ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc2)-30));
      rmSetAreaBaseHeight(eastIslandVillage2ramp, 7.2);
      rmSetAreaCoherence(eastIslandVillage2ramp, 0.8);
      rmSetAreaMix(eastIslandVillage2ramp, baseMix);
      rmSetAreaSmoothDistance(eastIslandVillage2ramp, 30);
      rmBuildArea(eastIslandVillage2ramp);

      rmSetAreaSize(eastIslandVillage2, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(eastIslandVillage2, rmXMetersToFraction(xsVectorGetX(zenControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc2)));
      rmSetAreaCoherence(eastIslandVillage2, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage2, 5);
      rmSetAreaCliffType(eastIslandVillage2, "Italian Cliff");
      rmSetAreaCliffEdge(eastIslandVillage2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage2, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage2, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage2, 0.0);
      rmBuildArea(eastIslandVillage2);

      int westIslandVillage2Terrain = rmCreateArea ("village 2 terrain");
      rmSetAreaSize(westIslandVillage2Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(westIslandVillage2Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc2)));
      rmSetAreaCoherence(westIslandVillage2Terrain, 0.8);
      rmSetAreaMix(westIslandVillage2Terrain, paintMix);
      rmBuildArea(westIslandVillage2Terrain);

      int middleSufiVillageID2 = -1;
      int middleSufiVillageID2Type = rmRandInt(1,3);
      middleSufiVillageID2 = rmCreateGrouping("native2 city", "Jesuit_Cathedral_EU_0"+middleSufiVillageID2Type);
      rmAddGroupingConstraint(middleSufiVillageID2, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID2, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc2)), 1);
    }

    // Monastery 3

    if (cNumberNonGaiaPlayers >4) {

      int zenControllerID3 = rmCreateObjectDef("zen controller 3");
      rmAddObjectDefItem(zenControllerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID3, 0.0);
      rmAddObjectDefConstraint(zenControllerID3, avoidController);
      rmAddObjectDefConstraint(zenControllerID3, playerEdgeConstraint);

      if (monasteryPlacement == 1)
      {
          rmPlaceObjectDefAtLoc(zenControllerID3, 0, 0.15, 0.45);
      }
      else 
      {
          rmPlaceObjectDefAtLoc(zenControllerID3, 0, 0.85, 0.45);
      }

      vector zenControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID3, 0));

      int eastIslandVillage3 = rmCreateArea("east island village 3");
      int eastIslandVillage3ramp = rmCreateArea("east island village3 ramp 1");

      rmSetAreaSize(eastIslandVillage3ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage3ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc3) - 30));
      rmSetAreaBaseHeight(eastIslandVillage3ramp, 7.2);
      rmSetAreaCoherence(eastIslandVillage3ramp, 0.8);
      rmSetAreaMix(eastIslandVillage3ramp, baseMix);
      rmSetAreaSmoothDistance(eastIslandVillage3ramp, 30);
      rmBuildArea(eastIslandVillage3ramp);

      rmSetAreaSize(eastIslandVillage3, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(eastIslandVillage3, rmXMetersToFraction(xsVectorGetX(zenControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc3)));
      rmSetAreaCoherence(eastIslandVillage3, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage3, 5);
      rmSetAreaCliffType(eastIslandVillage3, "Italian Cliff");
      rmSetAreaCliffEdge(eastIslandVillage3, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage3, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage3, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage3, 0.0);
      rmBuildArea(eastIslandVillage3);

      int westIslandVillage3Terrain = rmCreateArea("village 3 terrain");
      rmSetAreaSize(westIslandVillage3Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(westIslandVillage3Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc3)));
      rmSetAreaCoherence(westIslandVillage3Terrain, 0.8);
      rmSetAreaMix(westIslandVillage3Terrain, paintMix);
      rmBuildArea(westIslandVillage3Terrain);

      int middleSufiVillageID3 = -1;
      int middleSufiVillageID3Type = rmRandInt(1, 3);
      middleSufiVillageID3 = rmCreateGrouping("native3 city", "Jesuit_Cathedral_EU_0" + middleSufiVillageID3Type);
      rmAddGroupingConstraint(middleSufiVillageID3, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID3, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc3)), 1);
    }

    // Team Maltese

    // Village 4


    int zenControllerID4 = rmCreateObjectDef("zen controller 4");
    rmAddObjectDefItem(zenControllerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
    rmSetObjectDefMinDistance(zenControllerID4, 0.0);
    rmAddObjectDefConstraint(zenControllerID4, avoidController);
    rmAddObjectDefConstraint(zenControllerID4, playerEdgeConstraint);

    if (monasteryPlacement == 2)
    {
        rmPlaceObjectDefAtLoc(zenControllerID4, 0, 0.2, 0.25);
    }
    else 
    {
        rmPlaceObjectDefAtLoc(zenControllerID4, 0, 0.8, 0.25);
    }

    vector zenControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID4, 0));

    int eastIslandVillage4 = rmCreateArea("east island village 4");
    int eastIslandVillage4ramp = rmCreateArea("east island village4 ramp 1");

    rmSetAreaSize(eastIslandVillage4ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
    rmSetAreaLocation(eastIslandVillage4ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc4) + 30));
    rmSetAreaBaseHeight(eastIslandVillage4ramp, 7.2);
    rmSetAreaCoherence(eastIslandVillage4ramp, 0.8);
    rmSetAreaMix(eastIslandVillage4ramp, baseMix);
    rmSetAreaSmoothDistance(eastIslandVillage4ramp, 30);
    rmBuildArea(eastIslandVillage4ramp);

    rmSetAreaSize(eastIslandVillage4, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
    rmSetAreaLocation(eastIslandVillage4, rmXMetersToFraction(xsVectorGetX(zenControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc4)));
    rmSetAreaCoherence(eastIslandVillage4, 0.8);
    rmSetAreaSmoothDistance(eastIslandVillage4, 5);
    rmSetAreaCliffType(eastIslandVillage4, "Italian Cliff");
    rmSetAreaCliffEdge(eastIslandVillage4, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(eastIslandVillage4, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(eastIslandVillage4, 5.2);
    rmSetAreaElevationVariation(eastIslandVillage4, 0.0);
    rmBuildArea(eastIslandVillage4);

    int westIslandVillage4Terrain = rmCreateArea("village 4 terrain");
    rmSetAreaSize(westIslandVillage4Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
    rmSetAreaLocation(westIslandVillage4Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc4)));
    rmSetAreaCoherence(westIslandVillage4Terrain, 0.8);
    rmSetAreaMix(westIslandVillage4Terrain, paintMix);
    rmBuildArea(westIslandVillage4Terrain);

    int middleSufiVillageID4 = -1;
    int middleSufiVillageID4Type = rmRandInt(1, 5);
    if (monasteryPlacement == 2)
      middleSufiVillageID4 = rmCreateGrouping("native4 city", "maltese_village0" + middleSufiVillageID4Type);
    else
      middleSufiVillageID4 = rmCreateGrouping("native4 city", "Orthodox_Monastery0" + middleSufiVillageID4Type);
    rmAddGroupingConstraint(middleSufiVillageID4, avoidImpassableLand);
    rmPlaceGroupingAtLoc(middleSufiVillageID4, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc4)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc4)), 1);


    // Village 5

    if (cNumberNonGaiaPlayers >2) {
      int zenControllerID5 = rmCreateObjectDef("zen controller 5");
      rmAddObjectDefItem(zenControllerID5, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID5, 0.0);
      rmAddObjectDefConstraint(zenControllerID5, avoidController);
      rmAddObjectDefConstraint(zenControllerID5, playerEdgeConstraint);

      if (monasteryPlacement == 2)
      {
          rmPlaceObjectDefAtLoc(zenControllerID5, 0, 0.2, 0.65);
      }
      else 
      {
          rmPlaceObjectDefAtLoc(zenControllerID5, 0, 0.8, 0.65);
      }

      vector zenControllerLoc5 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID5, 0));

      int eastIslandVillage5 = rmCreateArea("east island village 5");
      int eastIslandVillage5ramp = rmCreateArea("east island village5 ramp 1");

      rmSetAreaSize(eastIslandVillage5ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage5ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc5) - 30));
      rmSetAreaBaseHeight(eastIslandVillage5ramp, 7.2);
      rmSetAreaCoherence(eastIslandVillage5ramp, 0.8);
      rmSetAreaMix(eastIslandVillage5ramp, baseMix);
      rmSetAreaSmoothDistance(eastIslandVillage5ramp, 30);
      rmBuildArea(eastIslandVillage5ramp);

      rmSetAreaSize(eastIslandVillage5, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(eastIslandVillage5, rmXMetersToFraction(xsVectorGetX(zenControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc5)));
      rmSetAreaCoherence(eastIslandVillage5, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage5, 5);
      rmSetAreaCliffType(eastIslandVillage5, "Italian Cliff");
      rmSetAreaCliffEdge(eastIslandVillage5, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage5, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage5, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage5, 0.0);
      rmBuildArea(eastIslandVillage5);

      int westIslandVillage5Terrain = rmCreateArea("village 5 terrain");
      rmSetAreaSize(westIslandVillage5Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(westIslandVillage5Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc5)));
      rmSetAreaCoherence(westIslandVillage5Terrain, 0.8);
      rmSetAreaMix(westIslandVillage5Terrain, paintMix);
      rmBuildArea(westIslandVillage5Terrain);

      int middleSufiVillageID5 = -1;
      int middleSufiVillageID5Type = rmRandInt(1, 5);
      if (monasteryPlacement == 2)
        middleSufiVillageID5 = rmCreateGrouping("native5 city", "maltese_village0" + middleSufiVillageID5Type);
      else
        middleSufiVillageID5 = rmCreateGrouping("native5 city", "Orthodox_Monastery0" + middleSufiVillageID5Type);
      rmAddGroupingConstraint(middleSufiVillageID5, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID5, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc5)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc5)), 1);
    }

    // Village 6
    if (cNumberNonGaiaPlayers >4) {
      int zenControllerID6 = rmCreateObjectDef("zen controller 6");
      rmAddObjectDefItem(zenControllerID6, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(zenControllerID6, 0.0);
      rmAddObjectDefConstraint(zenControllerID6, avoidController);
      rmAddObjectDefConstraint(zenControllerID6, playerEdgeConstraint);

      if (monasteryPlacement == 2)
      {
          rmPlaceObjectDefAtLoc(zenControllerID6, 0, 0.15, 0.45);
      }
      else 
      {
          rmPlaceObjectDefAtLoc(zenControllerID6, 0, 0.85, 0.45);
      }

      vector zenControllerLoc6 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(zenControllerID6, 0));

      int eastIslandVillage6 = rmCreateArea("east island village 6");
      int eastIslandVillage6ramp = rmCreateArea("east island village6 ramp 1");

      rmSetAreaSize(eastIslandVillage6ramp, rmAreaTilesToFraction(250.0), rmAreaTilesToFraction(250.0));
      rmSetAreaLocation(eastIslandVillage6ramp, rmXMetersToFraction(xsVectorGetX(zenControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc6) - 30));
      rmSetAreaBaseHeight(eastIslandVillage6ramp, 7.2);
      rmSetAreaCoherence(eastIslandVillage6ramp, 0.8);
      rmSetAreaMix(eastIslandVillage6ramp, baseMix);
      rmSetAreaSmoothDistance(eastIslandVillage6ramp, 30);
      rmBuildArea(eastIslandVillage6ramp);

      rmSetAreaSize(eastIslandVillage6, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(eastIslandVillage6, rmXMetersToFraction(xsVectorGetX(zenControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc6)));
      rmSetAreaCoherence(eastIslandVillage6, 0.8);
      rmSetAreaSmoothDistance(eastIslandVillage6, 5);
      rmSetAreaCliffType(eastIslandVillage6, "Italian Cliff");
      rmSetAreaCliffEdge(eastIslandVillage6, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandVillage6, 1.0, 0.0, 0.5); 
      rmSetAreaBaseHeight(eastIslandVillage6, 5.2);
      rmSetAreaElevationVariation(eastIslandVillage6, 0.0);
      rmBuildArea(eastIslandVillage6);

      int westIslandVillage6Terrain = rmCreateArea("village 6 terrain");
      rmSetAreaSize(westIslandVillage6Terrain, rmAreaTilesToFraction(800.0), rmAreaTilesToFraction(800.0));
      rmSetAreaLocation(westIslandVillage6Terrain, rmXMetersToFraction(xsVectorGetX(zenControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc6)));
      rmSetAreaCoherence(westIslandVillage6Terrain, 0.8);
      rmSetAreaMix(westIslandVillage6Terrain, paintMix);
      rmBuildArea(westIslandVillage6Terrain);

      int middleSufiVillageID6 = -1;
      int middleSufiVillageID6Type = rmRandInt(1, 5);
      if (monasteryPlacement == 2)
        middleSufiVillageID6 = rmCreateGrouping("native6 city", "maltese_village0" + middleSufiVillageID6Type);
      else
        middleSufiVillageID6 = rmCreateGrouping("native6 city", "Orthodox_Monastery0" + middleSufiVillageID6Type);
      rmAddGroupingConstraint(middleSufiVillageID6, avoidImpassableLand);
      rmPlaceGroupingAtLoc(middleSufiVillageID6, 0, rmXMetersToFraction(xsVectorGetX(zenControllerLoc6)), rmZMetersToFraction(xsVectorGetZ(zenControllerLoc6)), 1);

    }

    int westMountain=rmCreateArea("italy mountains"); 
    rmSetAreaSize(westMountain, 0.08, 0.08);
    rmSetAreaLocation(westMountain, 0.05, 0.5);
    rmSetAreaCoherence(westMountain, 0.6);
    rmSetAreaSmoothDistance(westMountain, 5);
    rmSetAreaCliffType(westMountain, "Italian Cliff");
    rmSetAreaCliffEdge(westMountain, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(westMountain, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(westMountain, 5.2);
    rmSetAreaElevationVariation(westMountain, 0.0);
    rmSetAreaObeyWorldCircleConstraint(westMountain, false);
    rmAddAreaInfluenceSegment(westMountain, 0.1, 0.8, 0.0, 0.5);
    rmAddAreaInfluenceSegment(westMountain, 0.1, 0.2, 0.0, 0.5);
    rmAddAreaToClass(westMountain, classMountains);
    rmBuildArea(westMountain);

    int westMountainTerrain=rmCreateArea("italy mountains terrain"); 
    rmSetAreaSize(westMountainTerrain, 0.08, 0.08);
    rmSetAreaLocation(westMountainTerrain, 0.05, 0.5);
    rmSetAreaCoherence(westMountainTerrain, 0.6);
    rmSetAreaMix(westMountainTerrain, paintMix);
    rmSetAreaObeyWorldCircleConstraint(westMountainTerrain, false);
    rmAddAreaInfluenceSegment(westMountainTerrain, 0.1, 0.8, 0.0, 0.5);
    rmAddAreaInfluenceSegment(westMountainTerrain, 0.1, 0.2, 0.0, 0.5);
    rmBuildArea(westMountainTerrain);

    int eastMountain=rmCreateArea("balkan mountains"); 
    rmSetAreaSize(eastMountain, 0.08, 0.08);
    rmSetAreaLocation(eastMountain, 0.95, 0.5);
    rmSetAreaCoherence(eastMountain, 0.6);
    rmSetAreaSmoothDistance(eastMountain, 5);
    rmSetAreaCliffType(eastMountain, "Italian Cliff");
    rmSetAreaCliffEdge(eastMountain, 1, 1.0, 0.0, 1.0, 0);
    rmSetAreaCliffHeight(eastMountain, 1.0, 0.0, 0.5); 
    rmSetAreaBaseHeight(eastMountain, 5.2);
    rmSetAreaElevationVariation(eastMountain, 0.0);
    rmSetAreaObeyWorldCircleConstraint(eastMountain, false);
    rmAddAreaInfluenceSegment(eastMountain, 0.9, 0.8, 1.0, 0.5);
    rmAddAreaInfluenceSegment(eastMountain, 0.9, 0.2, 1.0, 0.5);
    rmAddAreaToClass(eastMountain, classMountains);
    rmBuildArea(eastMountain);

    int eastMountainTerrain=rmCreateArea("balkan mountains terrain"); 
    rmSetAreaSize(eastMountainTerrain, 0.08, 0.08);
    rmSetAreaLocation(eastMountainTerrain, 0.95, 0.5);
    rmSetAreaCoherence(eastMountainTerrain, 0.6);
    rmSetAreaMix(eastMountainTerrain, paintMix);
    rmSetAreaObeyWorldCircleConstraint(eastMountainTerrain, false);
    rmAddAreaInfluenceSegment(eastMountainTerrain, 0.9, 0.8, 1.0, 0.5);
    rmAddAreaInfluenceSegment(eastMountainTerrain, 0.9, 0.2, 1.0, 0.5);
    rmBuildArea(eastMountainTerrain);

    int eastMountainsConstraint=rmCreateAreaConstraint("east island mountains", eastMountain);
    int westMountainsConstraint=rmCreateAreaConstraint("west Island mountains", westMountain);


    // Place King's Hill
   if (rmGetIsKOTH() == true) {
         ypKingsHillPlacer(0.5, 0.95, 0.00, 0);

	  }
    else{

    int cemetaryID = -1;
    int cemetaryType = rmRandInt(1, 2);
    cemetaryID = rmCreateGrouping("cemetary", "Cemetary_0"+cemetaryType);
    rmAddGroupingConstraint(cemetaryID, avoidImpassableLand);
    rmPlaceGroupingAtLoc(cemetaryID, 0, 0.5, 0.95, 1);
    }

// Text
	rmSetStatusText("",0.40);

    // Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.80, 0.60);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.22, 0.32, 0);
		}
		else
		{
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.60, 0.80);
				rmPlacePlayersCircular(0.22, 0.32, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.20, 0.40);
				rmPlacePlayersCircular(0.22, 0.32, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.20, 0.40);
				rmPlacePlayersCircular(0.22, 0.32, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.60, 0.80);
				rmPlacePlayersCircular(0.22, 0.32, rmDegreesToRadians(5.0));
			}
		}


// starting resources

int TCfloat = -1;
    if (cNumberTeams == 2)
	    TCfloat = 40;
    else 
	    TCfloat = 80;

    int StartDeerID2=rmCreateObjectDef("starting serow");
    rmAddObjectDefItem(StartDeerID2, "ypSerow", 8, 7.0);
    rmSetObjectDefMinDistance(StartDeerID2, 31.0);
    rmSetObjectDefMaxDistance(StartDeerID2, 33.0);
    rmSetObjectDefCreateHerd(StartDeerID2, true);
    rmAddObjectDefConstraint(StartDeerID2, avoidWater5);
    
  int startingTCID= rmCreateObjectDef("startingTC");
  if (rmGetNomadStart())
  {
			rmAddObjectDefItem(startingTCID, "CoveredWagon", 1, 0.0);
  }
		
  else
  {
    rmAddObjectDefItem(startingTCID, "townCenter", 1, 0.0);
  }

 // mSetObjectDefMinDistance(startingTCID, 0.0);
 // rmSetObjectDefMaxDistance(startingTCID, TCfloat);

  rmSetObjectDefMinDistance(startingTCID, 0); //5
	rmSetObjectDefMaxDistance(startingTCID, TCfloat); //10
  rmAddObjectDefConstraint(startingTCID, avoidImpassableLand);
  rmAddObjectDefConstraint(startingTCID, playerEdgeConstraint);
  rmAddObjectDefConstraint(startingTCID, avoidControllerFar);
  rmAddObjectDefConstraint(startingTCID, avoidWater10);
  rmAddObjectDefConstraint(startingTCID, avoidBonusIslands);
  rmAddObjectDefConstraint(startingTCID, avoidMountains);
	rmAddObjectDefToClass(startingTCID, rmClassID("player"));

  // Text
  rmSetStatusText("",0.50);
  
  rmClearClosestPointConstraints();

  for (i = 1; < cNumberPlayers)
  {
		int placedTC = rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(startSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));

    if (rmGetNomadStart() == false)
    {
      
      if (rmGetPlayerCiv(i) == rmGetCivID("DEItalians"))
      {
        rmPlaceObjectDefAtLoc(playerLombardID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
      }
      else if (rmGetPlayerCiv(i) == rmGetCivID("Chinese") || rmGetPlayerCiv(i) == rmGetCivID("Japanese") || rmGetPlayerCiv(i) == rmGetCivID("Indians"))
      {
        rmPlaceObjectDefAtLoc(playerMonID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
      }

	else if ( rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
	  {
		rmPlaceObjectDefAtLoc(playerCommunityPlazaID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
	  }
			
	else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEAmericans") || rmGetPlayerCiv(i) ==  rmGetCivID("DEMexicans"))
	  {
		rmPlaceObjectDefAtLoc(playerUSSaloonID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
	  }
	else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))
	  {
		rmPlaceObjectDefAtLoc(playerAfrTowerID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
	  }
			else
			{
				rmPlaceObjectDefAtLoc(playerSaloonID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
		}
    
    //Japanese
    if(ypIsAsian(i) && rmGetNomadStart() == false)
      rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Food
		rmPlaceObjectDefAtLoc(StartBerriesID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation))); 
    rmPlaceObjectDefAtLoc(startFoodID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    if (cNumberNonGaiaPlayers == 2)
    {
       rmPlaceObjectDefAtLoc(StartDeerID2, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    }
    // Place a nugget for the player
if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))
    rmSetNuggetDifficulty(55, 55);
else if (rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
    rmSetNuggetDifficulty(69, 69);
else 
    rmSetNuggetDifficulty(1, 1);
    rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    
    // Place water spawn points for the players
    
    vector waterPoint = xsVectorSet(0, 0, 0);
    
    if (weird)
    {
      waterPoint = xsVectorSet(.5, .5, 0);
    }
    
    else if (rmGetPlayerTeam(i) == 0 && teamStartLoc < 0.5)
    {
      waterPoint = xsVectorSet(0, 0, 1.0);
    }
    
    else if (rmGetPlayerTeam(i) == 1 && teamStartLoc > 0.5)
    {
      waterPoint = xsVectorSet(0, 0, 1.0);
    }
      
		int waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 0.0);
		rmAddClosestPointConstraint(flagVsFlag);
    rmAddClosestPointConstraint(flagVsVenice1);
    rmAddClosestPointConstraint(flagVsVenice2);
		rmAddClosestPointConstraint(flagLand);
    rmAddClosestPointConstraint(flagEdgeConstraint);
    rmAddClosestPointConstraint(avoidTradeSocketFar);
		vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(waterSpawnPointID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));

    rmClearClosestPointConstraints();
  }


	// Text
	rmSetStatusText("",0.60);
   
  // Berries
  int berriesID=rmCreateObjectDef("berries");
	rmAddObjectDefItem(berriesID, "berrybush", 7, 6.0);
	rmSetObjectDefMinDistance(berriesID, 0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID, longPlayerConstraint);
  rmAddObjectDefConstraint(berriesID, avoidBerries);
  rmAddObjectDefConstraint(berriesID, shortAvoidImportantItem);
  rmAddObjectDefConstraint(berriesID, shortAvoidResource);
  rmAddObjectDefConstraint(berriesID, eastIslandConstraint);
  rmPlaceObjectDefPerPlayer(berriesID, false, 1.5);

  int berriesID2=rmCreateObjectDef("berries 2");
	rmAddObjectDefItem(berriesID2, "berrybush", 7, 6.0);
	rmSetObjectDefMinDistance(berriesID2, 0);
	rmSetObjectDefMaxDistance(berriesID2, rmXFractionToMeters(0.35));
	rmAddObjectDefConstraint(berriesID2, avoidImpassableLand);
	rmAddObjectDefConstraint(berriesID2, longPlayerConstraint);
  rmAddObjectDefConstraint(berriesID2, avoidBerries);
  rmAddObjectDefConstraint(berriesID2, shortAvoidImportantItem);
  rmAddObjectDefConstraint(berriesID2, shortAvoidResource);
  rmAddObjectDefConstraint(berriesID2, westIslandConstraint);
  rmPlaceObjectDefPerPlayer(berriesID2, false, 1.5);
  
  // Text
	rmSetStatusText("",0.70);
  
  // Forests
  int forestTreeID = 0;
  int numTries=6*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest, forestType);
    rmSetAreaForestDensity(forest, 0.6);
    rmSetAreaForestClumpiness(forest, 0.4);
    rmSetAreaForestUnderbrush(forest, 0.0);
    rmSetAreaMinBlobs(forest, 1);
    rmSetAreaMaxBlobs(forest, 5);
    rmSetAreaMinBlobDistance(forest, 16.0);
    rmSetAreaMaxBlobDistance(forest, 40.0);
    rmSetAreaCoherence(forest, 0.4);
    rmSetAreaSmoothDistance(forest, 10);
    rmAddAreaToClass(forest, rmClassID("classForest")); 
    rmAddAreaConstraint(forest, forestConstraint);
    rmAddAreaConstraint(forest, avoidAll);
    rmAddAreaConstraint(forest, avoidTCMedium);
    rmAddAreaConstraint(forest, avoidBonusIslandsShort);
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
  
	// Text
	rmSetStatusText("",0.80);
  
  
  // MINES

   int mineType = -1;
	int mineID = -1;
	int mineCount = (cNumberNonGaiaPlayers*1.25);
	rmEchoInfo("mine count = "+mineCount);

	for(i=0; < mineCount)
	{
	  int westmineID = rmCreateObjectDef("west mine "+i);
	  rmAddObjectDefItem(westmineID, "Mine", 1, 0.0);
      rmSetObjectDefMinDistance(westmineID, 0.0);
      rmSetObjectDefMaxDistance(westmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(westmineID, avoidCoin);
      rmAddObjectDefConstraint(westmineID, avoidAll);
      rmAddObjectDefConstraint(westmineID, playerConstraintNugget);
      rmAddObjectDefConstraint(westmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(westmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(westmineID, westIslandConstraint);
	  rmPlaceObjectDefAtLoc(westmineID, 0, 0.5, 0.5);
   }

   for(i=0; < mineCount)
	{
	  int eastmineID = rmCreateObjectDef("east mine "+i);
	  rmAddObjectDefItem(eastmineID, "Mine", 1, 0.0);
      rmSetObjectDefMinDistance(eastmineID, 0.0);
      rmSetObjectDefMaxDistance(eastmineID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(eastmineID, avoidCoin);
      rmAddObjectDefConstraint(eastmineID, avoidAll);
      rmAddObjectDefConstraint(eastmineID, avoidTownCenterFar);
      rmAddObjectDefConstraint(eastmineID, playerConstraintNugget);
      rmAddObjectDefConstraint(eastmineID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(eastmineID, eastIslandConstraint);
	  rmPlaceObjectDefAtLoc(eastmineID, 0, 0.5, 0.5);
   } 
 
  // Nuggets
  int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
  rmAddObjectDefConstraint(nuggetNorth, avoidSocket);
	rmAddObjectDefConstraint(nuggetNorth, avoidTCMedium);
  rmAddObjectDefConstraint(nuggetNorth, avoidMountains);
  rmAddObjectDefConstraint(nuggetNorth, avoidWater4);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorth, 0, mainIslandID, cNumberNonGaiaPlayers);

  int nuggetSouthHard= rmCreateObjectDef("nugget hard south"); 
	rmAddObjectDefItem(nuggetSouthHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefConstraint(nuggetSouthHard, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouthHard, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouthHard, avoidSocket);
	rmAddObjectDefConstraint(nuggetSouthHard, avoidTCMedium);
   rmAddObjectDefConstraint(nuggetSouthHard, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouthHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouthHard, 0, eastMountain, cNumberNonGaiaPlayers);

  int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouth, avoidSocket);
    rmAddObjectDefConstraint(nuggetSouth, avoidMountains);
	rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, mainIslandID2, cNumberNonGaiaPlayers);

  int nuggetNorthHard= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetNorthHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefConstraint(nuggetNorthHard, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidNugget);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidSocket);
	rmAddObjectDefConstraint(nuggetNorthHard, avoidTCshort);
  rmAddObjectDefConstraint(nuggetNorthHard, avoidWater4);
	rmAddObjectDefConstraint(nuggetNorthHard, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorthHard, 0,westMountain, cNumberNonGaiaPlayers);

  int nuggetBonusHard= rmCreateObjectDef("nugget hard bonus"); 
	rmAddObjectDefItem(nuggetBonusHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
  rmSetObjectDefMinDistance(nuggetBonusHard, 0.0);
  rmSetObjectDefMaxDistance(nuggetBonusHard, rmXFractionToMeters(0.05));
	rmAddObjectDefConstraint(nuggetBonusHard, shortAvoidImpassableLand);
  rmAddObjectDefConstraint(nuggetBonusHard, avoidWater4);
  rmAddObjectDefConstraint(nuggetBonusHard, avoidTradeSocket);
	rmPlaceObjectDefAtLoc(nuggetBonusHard, 0, 0.5, 0.9);

  
	
	// Resources that can be placed after forests

    int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, shortAvoidResource);
	rmAddObjectDefConstraint(food1ID, playerConstraint);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
  rmAddObjectDefConstraint(food1ID, eastIslandConstraint);
  rmAddObjectDefConstraint(food1ID, avoidMountains);
	rmAddObjectDefConstraint(food1ID, avoidHuntable1);
	rmAddObjectDefConstraint(food1ID, avoidHuntable2);
  rmAddObjectDefConstraint(food1ID, shortAvoidImportantItem);
  
  int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, huntable1, rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, shortAvoidResource);
	rmAddObjectDefConstraint(food2ID, playerConstraint);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
  rmAddObjectDefConstraint(food2ID, westIslandConstraint);
  rmAddObjectDefConstraint(food2ID, avoidMountains);
	rmAddObjectDefConstraint(food2ID, avoidHuntable1);
	rmAddObjectDefConstraint(food2ID, avoidHuntable2);
	rmAddObjectDefConstraint(food2ID, shortAvoidImportantItem);

    rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
    rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

  int food3ID=rmCreateObjectDef("huntable3");
	rmAddObjectDefItem(food3ID, huntable2, rmRandInt(cNumberNonGaiaPlayers,cNumberNonGaiaPlayers*1.5), 6.0);
	rmSetObjectDefCreateHerd(food3ID, true);
	rmSetObjectDefMinDistance(food3ID, 0.0);
	rmSetObjectDefMaxDistance(food3ID, rmXFractionToMeters(0.45));
  rmSetObjectDefMinDistance(food3ID, 0.0);
  rmSetObjectDefMaxDistance(food3ID, 25.0);
	rmAddObjectDefConstraint(food3ID, avoidImpassableLand);
  rmAddObjectDefConstraint(food3ID, avoidImportantItem);

  rmPlaceObjectDefAtLoc(food3ID, 0, 0.05, 0.6, 1);
  rmPlaceObjectDefAtLoc(food3ID, 0, 0.05, 0.4, 1);

  rmPlaceObjectDefAtLoc(food3ID, 0, 0.95, 0.6, 1);
  rmPlaceObjectDefAtLoc(food3ID, 0, 0.95, 0.4, 1);


  
	// Text
	rmSetStatusText("",0.90);
    
  int fishID=rmCreateObjectDef("fish 1");
  rmAddObjectDefItem(fishID, fish1, 1, 0.0);
  rmSetObjectDefMinDistance(fishID, 0.0);
  rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fishID, fishVsFishID);
  rmAddObjectDefConstraint(fishID, fishLand);
  rmAddObjectDefConstraint(fishID, avoidControllerShort);
  rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
    
  int fish2ID=rmCreateObjectDef("fish 2");
  rmAddObjectDefItem(fish2ID, fish2, 1, 0.0);
  rmSetObjectDefMinDistance(fish2ID, 0.0);
  rmSetObjectDefMaxDistance(fish2ID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(fish2ID, fishVsFish2ID);
  rmAddObjectDefConstraint(fish2ID, fishLand);
  rmAddObjectDefConstraint(fish2ID, avoidControllerShort);
  rmPlaceObjectDefAtLoc(fish2ID, 0, 0.5, 0.5, 6*cNumberNonGaiaPlayers);
  
  // extra fish for under 5 players
  if (cNumberNonGaiaPlayers < 5)
  {
    int fish3ID=rmCreateObjectDef("fish 3");
    rmAddObjectDefItem(fish3ID, fish1, 1, 0.0);
    rmSetObjectDefMinDistance(fish3ID, 0.0);
    rmSetObjectDefMaxDistance(fish3ID, rmXFractionToMeters(0.5));
    rmAddObjectDefConstraint(fish3ID, fishVsFishID);
    rmAddObjectDefConstraint(fish3ID, fishLand);
    rmAddObjectDefConstraint(fish3ID, avoidControllerShort);
    rmPlaceObjectDefAtLoc(fish3ID, 0, 0.5, 0.5, 7*cNumberNonGaiaPlayers);
  }  
    
  int whaleID=rmCreateObjectDef("whale");
  rmAddObjectDefItem(whaleID, whale1, 1, 0.0);
  rmSetObjectDefMinDistance(whaleID, 0.0);
  rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);  
  rmAddObjectDefConstraint(whaleID, whaleEdgeConstraint);
  rmAddObjectDefConstraint(whaleID, whaleLand);
  rmAddObjectDefConstraint(whaleID, avoidController);
  rmAddObjectDefConstraint(whaleID, portSiteConstraint);
  rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);
  
  // Water nuggets
  
  int nuggetW= rmCreateObjectDef("nugget water"); 
  rmAddObjectDefItem(nuggetW, "ypNuggetBoat", 1, 0.0);
  rmSetNuggetDifficulty(5, 5);
  rmSetObjectDefMinDistance(nuggetW, rmXFractionToMeters(0.0));
  rmSetObjectDefMaxDistance(nuggetW, rmXFractionToMeters(0.5));
  rmAddObjectDefConstraint(nuggetW, avoidLand);
  rmAddObjectDefConstraint(nuggetW, avoidNuggetWater);
  rmAddObjectDefConstraint(nuggetW, avoidTradeRouteSmall);
  rmAddObjectDefConstraint(nuggetW, nuggetVsFlag);
  rmPlaceObjectDefAtLoc(nuggetW, 0, 0.5, 0.1, cNumberNonGaiaPlayers*4);

      // VILLAGE TREES
   int villageTreeID=rmCreateObjectDef("village tree");
   rmAddObjectDefItem(villageTreeID, "TreeGreatLakes", 1, 0.0);
   rmAddObjectDefConstraint(villageTreeID, ObjectAvoidTradeRouteShort);
   rmAddObjectDefConstraint(villageTreeID, avoidWater4);
   rmPlaceObjectDefInArea(villageTreeID, 0, westIslandVillage1, 15);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage2, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage3, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage4, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage5, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastIslandVillage6, 10);
   rmPlaceObjectDefInArea(villageTreeID, 0, bonusIslandID, 6);
   rmPlaceObjectDefInArea(villageTreeID, 0, eastMountain, 20);
   rmPlaceObjectDefInArea(villageTreeID, 0, westMountain, 20);
    
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
rmCreateTrigger("Activate Venice"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpVenetianExpansion"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffVenice"); //operator
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

if (monasteryPlacement == 2){
  for (k=1; <= cNumberNonGaiaPlayers) {
  rmCreateTrigger("Activate Maltese"+k);
  rmAddTriggerCondition("ZP Tech Researching (XS)");
  rmSetTriggerConditionParam("TechID","cTechzpMalteseCross"); //operator
  rmSetTriggerConditionParamInt("PlayerID",k);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",k);
  rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffMaltese"); //operator
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
}

if (monasteryPlacement == 1){
  for (k=1; <= cNumberNonGaiaPlayers) {
  rmCreateTrigger("Activate Orthodox"+k);
  rmAddTriggerCondition("ZP Tech Researching (XS)");
  rmSetTriggerConditionParam("TechID","cTechzpOrthodoxInfluence"); //operator
  rmSetTriggerConditionParamInt("PlayerID",k);
  rmAddTriggerEffect("ZP Set Tech Status (XS)");
  rmSetTriggerEffectParamInt("PlayerID",k);
  rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffOrthodox"); //operator
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
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Venice"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Maltese"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Orthodox"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Galley training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainGalley1ON Plr"+k);
rmCreateTrigger("TrainGalley1OFF Plr"+k);
rmCreateTrigger("TrainGalley1TIME Plr"+k);


   rmCreateTrigger("TrainGalley2ON Plr"+k);
   rmCreateTrigger("TrainGalley2OFF Plr"+k);
   rmCreateTrigger("TrainGalley2TIME Plr"+k);

   rmSwitchToTrigger(rmTriggerID("TrainGalley2ON_Plr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","232");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2OFF_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2TIME_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainGalley2OFF_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("TrainGalley2TIME_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley2"); //operator
   rmSetTriggerEffectParamInt("Status",0);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","4");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainGalley1OFF_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("TrainGalley1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Galeass Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("trainGalleass1ON Plr"+k);
rmCreateTrigger("trainGalleass1OFF Plr"+k);
rmCreateTrigger("trainGalleass1TIME Plr"+k);


   rmCreateTrigger("trainGalleass2ON Plr"+k);
   rmCreateTrigger("trainGalleass2OFF Plr"+k);
   rmCreateTrigger("trainGalleass2TIME Plr"+k);

   rmSwitchToTrigger(rmTriggerID("trainGalleass2ON_Plr"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","232");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamInt("Count",1);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass2"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2OFF_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2TIME_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("trainGalleass2OFF_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1",5);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   
   rmSwitchToTrigger(rmTriggerID("trainGalleass2TIME_Plr"+k));
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamFloat("Param1",0.5);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
   rmSetTriggerEffectParamInt("Status",2);
   rmAddTriggerEffect("ZP Set Tech Status (XS)");
   rmSetTriggerEffectParamInt("PlayerID",k);
   rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass2"); //operator
   rmSetTriggerEffectParamInt("Status",0);
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("trainGalleass1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","4");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1OFF_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1TIME_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainGalleass1OFF_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("trainGalleass1TIME_Plr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Venice trading post activation

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Venice1on Player"+k);
rmCreateTrigger("Venice1off Player"+k);

rmSwitchToTrigger(rmTriggerID("Venice1on_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","4");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","4");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Venice1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","4");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","4");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",150);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Venice2on Player"+k);
   rmCreateTrigger("Venice2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Venice2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","232");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","232");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Venice2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","232");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","232");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",150);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice2on_Player"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
   rmAddTriggerEffect("Disable Trigger");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   }



// AI Venice Captains

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Venice Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int veniceCaptain=-1;
veniceCaptain = rmRandInt(1,3);

if (veniceCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceCornaro"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (veniceCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceContarini"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (veniceCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceDolphin"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI MalteseFactions

for (k=1; <= cNumberNonGaiaPlayers) {

rmCreateTrigger("ZP Pick Maltese Captain"+k);
rmAddTriggerCondition("ZP PLAYER Human");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("MyBool", "false");
rmAddTriggerCondition("Tech Status Equals");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParamInt("TechID",586);
rmSetTriggerConditionParamInt("Status",2);

int malteseCaptain=-1;
malteseCaptain = rmRandInt(1,3);

if (malteseCaptain==1)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseVenetians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseFlorentians"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (malteseCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateMalteseJerusalem"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// AI Venice Captains

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
      rmSetTriggerEffectParam("TechID","cTechzpConsulateOrthodoxRussians"); //operator
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
	rmSetStatusText("",0.99);
}  
