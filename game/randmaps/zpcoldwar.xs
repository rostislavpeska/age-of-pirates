
// First Cold War 05 / 2023

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

  // Text
   rmSetStatusText("",0.01);

	int subCiv0=-1;
   int subCiv1=-1;
   int subCiv2=-1;

   if (rmAllocateSubCivs(3) == true)
   {
		subCiv0=rmGetCivID("inuitnatives");
      rmEchoInfo("subCiv0 is inuitnatives "+subCiv0);
      if (subCiv0 >= 0)
         rmSetSubCiv(0, "inuitnatives");

      subCiv1=rmGetCivID("inuitnatives");
      rmEchoInfo("subCiv1 is inuitnatives "+subCiv1);
      if (subCiv1 >= 0)
			rmSetSubCiv(1, "inuitnatives");
  
		subCiv2=rmGetCivID("zpscientists");
		rmEchoInfo("subCiv2 is zpscientists "+subCiv2);
		if (subCiv2 >= 0)
				rmSetSubCiv(2, "zpscientists");
	}
	
   string MixType = "rockies_snow";

   // Set size.
   int playerTiles=24000;
	if (cNumberNonGaiaPlayers >4)
		playerTiles = 17000;
	if (cNumberNonGaiaPlayers >7)
		playerTiles = 19000;			
   int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
   rmEchoInfo("Map size="+size+"m x "+size+"m");
   rmSetMapSize(size, size);

   // Set up default water.
   rmSetSeaLevel(2.0);
   rmSetSeaType("ZP Bering Strait");
 	rmSetBaseTerrainMix("yukon snow");
	rmSetMapType("yukon");
   rmSetMapType("arcticwater");
	rmSetMapType("snow");
	rmSetMapType("water");

   rmSetLightingSet("ArcticTerritories_Skirmish");

   // Init map.
   rmTerrainInitialize("water");



   // Define some classes.
   int classPlayer=rmDefineClass("player");
   int classIsland=rmDefineClass("island");
   int classBonusIsland=rmDefineClass("bonusIsland");
   int classTeamIsland=rmDefineClass("teamIsland");
   int classPortSite=rmDefineClass("portSite");
   rmDefineClass("classForest");
   rmDefineClass("importantItem");
   rmDefineClass("natives");
	int classSocket = rmDefineClass("classSocket");
   int classLabArea = rmDefineClass("labArea");
   int classGlacier = rmDefineClass("glacier");

	chooseMercs();



   // -------------Define constraints
   
   // Create a edge of map constraint.
   int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));

   // Cardinal Directions
   int Northward=rmCreatePieConstraint("northMapConstraint", 0.55, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
   int Southward=rmCreatePieConstraint("southMapConstraint", 0.45, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
   int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.45, 0.55, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
   int Westward=rmCreatePieConstraint("westMapConstraint", 0.55, 0.45, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

   // Island constraints
   int islandConstraint=rmCreateClassDistanceConstraint("islands avoid each other", classIsland, 60.0);

   // Constraints to avoid water trade Route
   int islandAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 20.0);
   int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);

   // Player objects constraints
   int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 25.0);
   int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
   int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 10.0);
   int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 55);
   int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  
   int playersAwayPort=rmCreateAreaDistanceConstraint("players not in port ", classPortSite, 0.01);
   int avoidTC=rmCreateTypeDistanceConstraint("stay away from TC", "TownCenter", 29.0);
   int avoidCW=rmCreateTypeDistanceConstraint("stay away from CW", "CoveredWagon", 15.0);
   int avoidTCMedium=rmCreateTypeDistanceConstraint("stay away from TC by a bit", "TownCenter", 10.0);
   int avoidTCshort=rmCreateTypeDistanceConstraint("stay away from TC by a little bit", "TownCenter", 8.0);

   //Socket Constraints
   int avoidSocket = rmCreateClassDistanceConstraint("avoid socket", rmClassID("Socket"), 10.0);
   int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "zpSocketInuits", 50.0);
   int avoidSocketLongNootka=rmCreateTypeDistanceConstraint("avoid socket long nootka", "zpSocketInuits", 50.0);
   int avoidSocketLongTrade=rmCreateTypeDistanceConstraint("avoid socket long trade", "SocketTradeRoute", 50.0);

   // Bonus Area Constraints
   int avoidBonusIslands=rmCreateClassDistanceConstraint("stuff avoids bonus islands", classBonusIsland, 30.0);
   int avoidTeamIslands=rmCreateClassDistanceConstraint("stuff avoids team islands", classTeamIsland, 30.0);
   int villageEdgeConstraint = rmCreatePieConstraint("willabe awlaay from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-50, 0, 0, 0);

   // Avoid impassable Land
   int mediumShortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("mediumshort avoid impassable land", "Land", false, 10.0);
   int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 13.0);
   int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);

   // Avoid water
  int avoidWater2 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
   int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
   int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
   int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water large", "Land", false, 20.0);
   int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 21.0);
   int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 6.5);

   // Nature Constraints
   int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
   int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "MineGold", 35.0);
   int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);
   int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 40.0);
   int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 50.0);
   int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fishSalmon", 20.0);
   int RevealerVSRevealer=rmCreateTypeDistanceConstraint("revealer v revealer", "zpCinematicRevealerToAll", 10.0);
   int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 8.0);
   int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 50.0);
   int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 25.0);

   int avoidNuggetWater=rmCreateTypeDistanceConstraint("avoid water nuggets", "abstractNugget", 75.0); 
   int avoidNuggetWater2=rmCreateTypeDistanceConstraint("avoid water nuggets2", "abstractNugget", 120.0);
   int avoidLand = rmCreateTerrainDistanceConstraint("ship avoid land", "land", true, 15.0); 


// Text
	rmSetStatusText("",0.10);

int westGlacier1= rmCreateArea ("west glacier 1");
rmSetAreaSize(westGlacier1, 0.012, 0.012);
rmSetAreaLocation(westGlacier1, 0.6, 0.9);
rmSetAreaCoherence(westGlacier1, 0.5);
rmSetAreaMinBlobs(westGlacier1, 8);
rmSetAreaMaxBlobs(westGlacier1, 25);
rmSetAreaBaseHeight(westGlacier1, 4.5);
rmSetAreaElevationVariation(westGlacier1, 0.0);
rmSetAreaSmoothDistance(westGlacier1, 30);
rmSetAreaTerrainType(westGlacier1, "yukon\ground2_yuk");
rmAddAreaTerrainLayer(westGlacier1, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(westGlacier1, "great_lakes\ground_ice2_glw", 2, 4);
rmAddAreaTerrainLayer(westGlacier1, "great_lakes\ground_ice1_gl", 4, 7);
rmAddAreaToClass(westGlacier1, classGlacier);
rmBuildArea(westGlacier1);

int westGlacier2= rmCreateArea ("west glacier 2");
rmSetAreaSize(westGlacier2, 0.02, 0.02);
rmSetAreaLocation(westGlacier2, 0.1, 0.4);
rmSetAreaCoherence(westGlacier2, 0.5);
rmSetAreaMinBlobs(westGlacier2, 8);
rmSetAreaMaxBlobs(westGlacier2, 25);
rmSetAreaBaseHeight(westGlacier2, 4.5);
rmSetAreaElevationVariation(westGlacier2, 0.0);
rmSetAreaSmoothDistance(westGlacier2, 30);
rmSetAreaTerrainType(westGlacier2, "yukon\ground2_yuk");
rmAddAreaTerrainLayer(westGlacier2, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(westGlacier2, "great_lakes\ground_ice2_glw", 2, 4);
rmAddAreaTerrainLayer(westGlacier2, "bgreat_lakes\ground_ice1_gl", 4, 7);
rmAddAreaToClass(westGlacier2, classGlacier);
rmBuildArea(westGlacier2);

int eastGlacier1= rmCreateArea ("east glacier 1");
rmSetAreaSize(eastGlacier1, 0.02, 0.02);
rmSetAreaLocation(eastGlacier1, 0.9, 0.6);
rmSetAreaCoherence(eastGlacier1, 0.5);
rmSetAreaMinBlobs(eastGlacier1, 8);
rmSetAreaMaxBlobs(eastGlacier1, 25);
rmSetAreaBaseHeight(eastGlacier1, 4.5);
rmSetAreaElevationVariation(eastGlacier1, 0.0);
rmSetAreaSmoothDistance(eastGlacier1, 30);
rmSetAreaTerrainType(eastGlacier1, "yukon\ground2_yuk");
rmAddAreaTerrainLayer(eastGlacier1, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(eastGlacier1, "great_lakes\ground_ice2_glw", 2, 4);
rmAddAreaTerrainLayer(eastGlacier1, "great_lakes\ground_ice1_gl", 4, 7);
rmAddAreaToClass(eastGlacier1, classGlacier);
rmBuildArea(eastGlacier1);

int eastGlacier2= rmCreateArea ("east glacier 2");
rmSetAreaSize(eastGlacier2, 0.012, 0.012);
rmSetAreaLocation(eastGlacier2, 0.4, 0.1);
rmSetAreaCoherence(eastGlacier2, 0.5);
rmSetAreaMinBlobs(eastGlacier2, 8);
rmSetAreaMaxBlobs(eastGlacier2, 25);
rmSetAreaBaseHeight(eastGlacier2, 4.5);
rmSetAreaElevationVariation(eastGlacier2, 0.0);
rmSetAreaSmoothDistance(eastGlacier2, 30);
rmSetAreaTerrainType(eastGlacier2, "yukon\ground2_yuk");
rmAddAreaTerrainLayer(eastGlacier2, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(eastGlacier2, "great_lakes\ground_ice2_glw", 2, 4);
rmAddAreaTerrainLayer(eastGlacier2, "great_lakes\ground_ice1_gl", 4, 7);
rmAddAreaToClass(eastGlacier2, classGlacier);
rmBuildArea(eastGlacier2);


int bonusIsland1 = rmCreateArea ("bonus island 1");
rmSetAreaSize(bonusIsland1, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(450.0));
rmSetAreaLocation(bonusIsland1, 0.22, 0.22);
rmSetAreaCoherence(bonusIsland1, 0.7);
rmSetAreaMinBlobs(bonusIsland1, 8);
rmSetAreaMaxBlobs(bonusIsland1, 25);
rmSetAreaBaseHeight(bonusIsland1, 3.5);
rmSetAreaElevationVariation(bonusIsland1, 0.0);
rmSetAreaSmoothDistance(bonusIsland1, 30);
rmSetAreaTerrainType(bonusIsland1, "yukon\ground1_yuk");
rmAddAreaTerrainLayer(bonusIsland1, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(bonusIsland1, "great_lakes\ground_ice2_glw", 2, 4);
rmSetAreaMix(bonusIsland1, "ground_ice1_gl");
rmAddAreaToClass(bonusIsland1, classBonusIsland);
rmBuildArea(bonusIsland1);

int bonusIsland2 = rmCreateArea ("bonus island 2");
rmSetAreaSize(bonusIsland2, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(450.0));
rmSetAreaLocation(bonusIsland2, 0.78, 0.78);
rmSetAreaCoherence(bonusIsland2, 0.7);
rmSetAreaMinBlobs(bonusIsland2, 8);
rmSetAreaMaxBlobs(bonusIsland2, 25);
rmSetAreaBaseHeight(bonusIsland2, 3.5);
rmSetAreaElevationVariation(bonusIsland2, 0.0);
rmSetAreaSmoothDistance(bonusIsland2, 30);
rmSetAreaTerrainType(bonusIsland2, "yukon\ground1_yuk");
rmAddAreaTerrainLayer(bonusIsland2, "great_lakes\ground_ice2_gl", 0, 2);
rmAddAreaTerrainLayer(bonusIsland2, "great_lakes\ground_ice2_glw", 2, 4);
rmSetAreaMix(bonusIsland2, "ground_ice1_gl");
rmAddAreaToClass(bonusIsland2, classBonusIsland);
rmBuildArea(bonusIsland2);


   // Port Sites








// Text
	rmSetStatusText("",0.20);

// Area builder




// Scientist Village 1
   if (subCiv2 == rmGetCivID("zpscientists"))
   {  
   int scientistControllerID = rmCreateObjectDef("scientist controller 1");
      rmAddObjectDefItem(scientistControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(scientistControllerID, 0.0);
      rmSetObjectDefMaxDistance(scientistControllerID, 0.0);
      rmPlaceObjectDefAtLoc(scientistControllerID, 0, 0.55+rmXTilesToFraction(9), 0.7);
   vector scientistControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID, 0));

   int westIslandLab1 = rmCreateArea ("west island lab");
      rmSetAreaSize(westIslandLab1, rmAreaTilesToFraction(1550.0), rmAreaTilesToFraction(1550.0));
      rmSetAreaLocation(westIslandLab1, 0.55, 0.7);
      rmSetAreaCoherence(westIslandLab1, 0.8);
      //rmSetAreaCliffType(westIslandLab1, "Rocky Mountain Edge");
      //rmSetAreaCliffEdge(westIslandLab1, 1, 1.0, 0.0, 1.0, 0);
      //rmSetAreaCliffHeight(westIslandLab1, 1.0, 0.0, 0.0); 

      rmAddAreaTerrainLayer(westIslandLab1, "great_lakes\ground_ice2_gl", 0, 2);
      rmAddAreaTerrainLayer(westIslandLab1, "great_lakes\ground_ice2_glw", 2, 4);
      rmAddAreaTerrainLayer(westIslandLab1, "great_lakes\ground_ice1_gl", 4, 6);

      rmSetAreaMinBlobs(westIslandLab1, 8);
      rmSetAreaMaxBlobs(westIslandLab1, 25);
      rmSetAreaBaseHeight(westIslandLab1, 3.5);
      rmSetAreaElevationVariation(westIslandLab1, 0.0);
      rmSetAreaSmoothDistance(westIslandLab1, 30);
      rmSetAreaTerrainType(westIslandLab1, "great_lakes\ground_ice1_gl");
      rmSetAreaMix(westIslandLab1, "ground_ice1_gl");
      rmAddAreaToClass(westIslandLab1, classLabArea);

      rmBuildArea(westIslandLab1);

   int westLabTerrain = rmCreateArea ("west lab terrain");
      rmSetAreaSize(westLabTerrain, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(westLabTerrain, 0.55+rmXTilesToFraction(9), 0.7);
      rmSetAreaCoherence(westLabTerrain, 1.0);
      rmSetAreaTerrainType(westLabTerrain, "yukon\ground1_yuk");

      rmBuildArea(westLabTerrain);

   int scientistVillageID1 = -1;
   int scientistVillage1Type = rmRandInt(1,2);
      scientistVillageID1 = rmCreateGrouping("scientist lab 1", "Scientist_Lab02");


      rmPlaceGroupingAtLoc(scientistVillageID1, 0, 0.55+rmXTilesToFraction(9), 0.7, 1);
   
   int nativewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
      rmAddObjectDefItem(nativewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
      rmAddClosestPointConstraint(flagLand);

   vector closeToVillage1 = rmFindClosestPointVector(scientistControllerLoc1 , rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(nativewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

      rmClearClosestPointConstraints();

   int pirateportID1 = -1;
      pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport02");
      rmAddClosestPointConstraint(portOnShore);

   vector closeToVillage1a = rmFindClosestPointVector(scientistControllerLoc1, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));
      
      rmClearClosestPointConstraints();

   int westIslandLabCliff1 = rmCreateArea ("west island lab cliff1");
      rmSetAreaSize(westIslandLabCliff1, rmAreaTilesToFraction(200.0), rmAreaTilesToFraction(300.0));
      rmSetAreaLocation(westIslandLabCliff1, 0.55, 0.7+rmXTilesToFraction(25));
      rmSetAreaCoherence(westIslandLabCliff1, 0.7);
       rmSetAreaCliffType(westIslandLabCliff1, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(westIslandLabCliff1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(westIslandLabCliff1, 2.2, 0.0, 0.0); 
      rmSetAreaBaseHeight(westIslandLabCliff1, 5.2);
      rmSetAreaElevationVariation(westIslandLabCliff1, 0.0);

      rmBuildArea(westIslandLabCliff1);

   int westIslandLabCliff2 = rmCreateArea ("west island lab cliff2");
      rmSetAreaSize(westIslandLabCliff2, rmAreaTilesToFraction(500.0), rmAreaTilesToFraction(500.0));
      rmSetAreaLocation(westIslandLabCliff2, 0.55-rmXTilesToFraction(25), 0.7);
      rmSetAreaCoherence(westIslandLabCliff2, 0.8);
       rmSetAreaCliffType(westIslandLabCliff2, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(westIslandLabCliff2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(westIslandLabCliff2, 2.2, 0.0, 0.0); 
      rmSetAreaBaseHeight(westIslandLabCliff2, 5.2);
      rmSetAreaElevationVariation(westIslandLabCliff2, 0.0);
      rmAddAreaInfluenceSegment(westIslandLabCliff2, 0.55-rmXTilesToFraction(25), 0.7, 0.55-rmXTilesToFraction(10), 0.7-rmXTilesToFraction(15));

      rmBuildArea(westIslandLabCliff2);

   }

// Scientist Village 2
   if (subCiv2 == rmGetCivID("zpscientists"))
   {  
   int scientistControllerID2 = rmCreateObjectDef("scientist controller 2");
      rmAddObjectDefItem(scientistControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
      rmSetObjectDefMinDistance(scientistControllerID2, 0.0);
      rmSetObjectDefMaxDistance(scientistControllerID2, 0.0);
      rmPlaceObjectDefAtLoc(scientistControllerID2, 0, 0.45-rmXTilesToFraction(9), 0.3);
   vector scientistControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(scientistControllerID2, 0));

   int eastIslandLab1 = rmCreateArea ("east island lab");
      rmSetAreaSize(eastIslandLab1, rmAreaTilesToFraction(1550.0), rmAreaTilesToFraction(1550.0));
      rmSetAreaLocation(eastIslandLab1, 0.45, 0.3);
      rmSetAreaCoherence(eastIslandLab1, 0.8);
      //rmSetAreaCliffType(eastIslandLab1, "Rocky Mountain Edge");
      //rmSetAreaCliffEdge(eastIslandLab1, 1, 1.0, 0.0, 1.0, 0);
      //rmSetAreaCliffHeight(eastIslandLab1, 1.0, 0.0, 0.0); 

      rmAddAreaTerrainLayer(eastIslandLab1, "great_lakes\ground_ice2_gl", 0, 2);
      rmAddAreaTerrainLayer(eastIslandLab1, "great_lakes\ground_ice2_glw", 2, 4);
      rmAddAreaTerrainLayer(eastIslandLab1, "great_lakes\ground_ice1_gl", 4, 6);

      rmSetAreaMinBlobs(eastIslandLab1, 8);
      rmSetAreaMaxBlobs(eastIslandLab1, 25);
      rmSetAreaBaseHeight(eastIslandLab1, 3.5);
      rmSetAreaElevationVariation(eastIslandLab1, 0.0);
      rmSetAreaSmoothDistance(eastIslandLab1, 30);
      rmSetAreaTerrainType(eastIslandLab1, "great_lakes\ground_ice1_gl");
      rmSetAreaMix(eastIslandLab1, "ground_ice1_gl");
      rmAddAreaToClass(eastIslandLab1, classLabArea);

      rmBuildArea(eastIslandLab1);

   int eastLabTerrain = rmCreateArea ("east lab terrain");
      rmSetAreaSize(eastLabTerrain, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(eastLabTerrain, 0.45-rmXTilesToFraction(9), 0.3);
      rmSetAreaCoherence(eastLabTerrain, 1.0);
      rmSetAreaTerrainType(eastLabTerrain, "yukon\ground1_yuk");
      rmBuildArea(eastLabTerrain);

   int scientistVillageID2 = -1;
   int scientistVillage2Type = rmRandInt(1,2);
      scientistVillageID2 = rmCreateGrouping("scientist lab 2", "Scientist_Lab01");


      rmPlaceGroupingAtLoc(scientistVillageID2, 0, 0.45-rmXTilesToFraction(9), 0.3, 1);
   
   int nativewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
      rmAddObjectDefItem(nativewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
      rmAddClosestPointConstraint(flagLand);

   vector closeToVillage2 = rmFindClosestPointVector(scientistControllerLoc2 , rmXFractionToMeters(1.0));
      rmPlaceObjectDefAtLoc(nativewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

      rmClearClosestPointConstraints();

   int pirateportID2 = -1;
      pirateportID2 = rmCreateGrouping("pirate port 1", "pirateport02");
      rmAddClosestPointConstraint(portOnShore);

   vector closeToVillage2a = rmFindClosestPointVector(scientistControllerLoc2, rmXFractionToMeters(1.0));
      rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));
      
      rmClearClosestPointConstraints();

   int eastIslandLabCliff1 = rmCreateArea ("east island lab cliff1");
      rmSetAreaSize(eastIslandLabCliff1, rmAreaTilesToFraction(300.0), rmAreaTilesToFraction(300.0));
      rmSetAreaLocation(eastIslandLabCliff1, 0.45, 0.3-rmXTilesToFraction(25));
      rmSetAreaCoherence(eastIslandLabCliff1, 0.7);
       rmSetAreaCliffType(eastIslandLabCliff1, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(eastIslandLabCliff1, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandLabCliff1, 2.2, 0.0, 0.0); 
      rmSetAreaBaseHeight(eastIslandLabCliff1, 5.2);
      rmSetAreaElevationVariation(eastIslandLabCliff1, 0.0);

      rmBuildArea(eastIslandLabCliff1);

   int eastIslandLabCliff2 = rmCreateArea ("east island lab cliff2");
      rmSetAreaSize(eastIslandLabCliff2, rmAreaTilesToFraction(400.0), rmAreaTilesToFraction(500.0));
      rmSetAreaLocation(eastIslandLabCliff2, 0.45+rmXTilesToFraction(25), 0.3);
      rmSetAreaCoherence(eastIslandLabCliff2, 0.8);
      rmSetAreaCliffType(eastIslandLabCliff2, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(eastIslandLabCliff2, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIslandLabCliff2, 2.2, 0.0, 0.0); 
      rmSetAreaBaseHeight(eastIslandLabCliff2, 5.2);
      rmSetAreaElevationVariation(eastIslandLabCliff2, 0.0);
      rmAddAreaInfluenceSegment(eastIslandLabCliff2, 0.45+rmXTilesToFraction(25), 0.3, 0.45+rmXTilesToFraction(10), 0.3+rmXTilesToFraction(15));

      rmBuildArea(eastIslandLabCliff2);

   }


   // Build main Islands

   // West
   int westIsland = rmCreateArea ("west island");
      rmSetAreaSize(westIsland, 0.25, 0.25);
      rmSetAreaLocation(westIsland, 0.2, 0.8);
      rmSetAreaWarnFailure(westIsland, false);
      rmSetAreaCliffType(westIsland, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(westIsland, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(westIsland, 2.2, 0.0, 0.0);
      rmSetAreaMinBlobs(westIsland, 8);
      rmSetAreaMaxBlobs(westIsland, 25);
      rmSetAreaMinBlobDistance(westIsland, 2.0);
      rmSetAreaMaxBlobDistance(westIsland, 5.0);
      rmSetAreaMix(westIsland, MixType);
      rmSetAreaBaseHeight(westIsland, 5.2); // terrain Height
      //rmSetAreaCliffPainting(westIsland, true, true, true, 10, true);
      //rmSetAreaHeightBlend(westIsland, 1);
      rmSetAreaSmoothDistance(westIsland, 10);
      rmSetAreaElevationType(westIsland, cElevTurbulence);
      rmSetAreaElevationVariation(westIsland, 3.0);
      rmSetAreaElevationPersistence(westIsland, 0.2);
      rmSetAreaCoherence(westIsland, 0.75);
      rmAddAreaConstraint(westIsland, islandConstraint);
      rmAddAreaConstraint(westIsland, islandAvoidTradeRoute);
      rmAddAreaInfluenceSegment(westIsland, 0.1, 0.5, 0.5, 0.9);
      rmAddAreaInfluenceSegment(westIsland, 0.3, 0.9, 0.1, 0.7);
      rmAddAreaInfluenceSegment(westIsland, 0.2, 0.6, 0.4, 0.65);
      rmAddAreaInfluenceSegment(westIsland, 0.4, 1.0, 0.0, 0.6);
      rmAddAreaToClass(westIsland, classIsland);
      rmAddAreaToClass(westIsland, classTeamIsland);
      rmBuildArea(westIsland);


   // east island
   int eastIsland = rmCreateArea ("east island");
      rmSetAreaSize(eastIsland, 0.25, 0.25);
      rmSetAreaLocation(eastIsland, 0.9, 0.2);
      rmSetAreaWarnFailure(eastIsland, false);
      rmSetAreaCliffType(eastIsland, "Rocky Mountain Edge");
      rmSetAreaCliffEdge(eastIsland, 1, 1.0, 0.0, 1.0, 0);
      rmSetAreaCliffHeight(eastIsland, 2.2, 0.0, 0.0);
      rmSetAreaMinBlobs(eastIsland, 8);
      rmSetAreaMaxBlobs(eastIsland, 25);
      rmSetAreaMinBlobDistance(eastIsland, 2.0);
      rmSetAreaMaxBlobDistance(eastIsland, 5.0);
      rmSetAreaMix(eastIsland, MixType);
      rmSetAreaBaseHeight(eastIsland, 5.2); // terrain Height
      //rmSetAreaCliffPainting(eastIsland, true, true, true, 10, true);
      //rmSetAreaHeightBlend(eastIsland, 1);
      rmSetAreaSmoothDistance(eastIsland, 10);
      rmSetAreaElevationType(eastIsland, cElevTurbulence);
      rmSetAreaElevationVariation(eastIsland, 3.0);
      rmSetAreaElevationPersistence(eastIsland, 0.2);
      rmSetAreaCoherence(eastIsland, 0.75);
      rmAddAreaConstraint(eastIsland, islandConstraint);
      rmAddAreaConstraint(eastIsland, islandAvoidTradeRoute);
      rmAddAreaInfluenceSegment(eastIsland, 0.5, 0.1, 0.9, 0.5);
      rmAddAreaInfluenceSegment(eastIsland, 0.9, 0.3, 0.7, 0.1);
      rmAddAreaInfluenceSegment(eastIsland, 0.8, 0.4, 0.6, 0.35);
      rmAddAreaInfluenceSegment(eastIsland, 1.0, 0.4, 0.6, 0.0);
      rmAddAreaToClass(eastIsland, classIsland);
      rmAddAreaToClass(eastIsland, classTeamIsland);
      rmBuildArea(eastIsland);

   // add island constraints
   int westIslandConstraint=rmCreateAreaConstraint("west island", westIsland);
   int eastIslandConstraint=rmCreateAreaConstraint("east island", eastIsland);
   int labConstraint=rmCreateClassDistanceConstraint("stuff avoids bonus lab area", classLabArea, 15.0);
   int avoidGlacier=rmCreateClassDistanceConstraint("stuff avoids glacier", classGlacier, 10.0);


   // Lab Ramps

   int westLabRamp = rmCreateArea ("west ramp");
      rmSetAreaSize(westLabRamp, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(westLabRamp, 0.55-rmXTilesToFraction(12), 0.7+rmXTilesToFraction(12));
      rmSetAreaBaseHeight(westLabRamp, 5.0);
      rmSetAreaCoherence(westLabRamp, 0.8);
      rmSetAreaMix(westLabRamp, MixType);
      rmSetAreaSmoothDistance(westLabRamp, 30);
      rmBuildArea(westLabRamp);

   int eastLabRamp = rmCreateArea ("east ramp");
      rmSetAreaSize(eastLabRamp, rmAreaTilesToFraction(350.0), rmAreaTilesToFraction(350.0));
      rmSetAreaLocation(eastLabRamp, 0.45+rmXTilesToFraction(12), 0.3-rmXTilesToFraction(12));
      rmSetAreaBaseHeight(eastLabRamp, 5.0);
      rmSetAreaCoherence(eastLabRamp, 0.8);
      rmSetAreaMix(eastLabRamp, MixType);
      rmSetAreaSmoothDistance(eastLabRamp, 30);
      rmBuildArea(eastLabRamp);


   // Place Trade Routes

   // Trade Route West

   int tradeRouteID = rmCreateTradeRoute();
	int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmAddObjectDefToClass(socketID, classSocket);
	rmSetObjectDefMinDistance(socketID, 2.0);
	rmSetObjectDefMaxDistance(socketID, 8.0);

	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 1.0);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.7);
   rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.6);


	bool placedTradeRoute = rmBuildTradeRoute(tradeRouteID, "snow");

   vector socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.3);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.7);
      rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);

   if (cNumberNonGaiaPlayers > 4){
      socketLoc  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
         rmPlaceObjectDefAtPoint(socketID, 0, socketLoc);
   }

   // Ttrade Route East

  int tradeRouteID2 = rmCreateTradeRoute();
	int socketID2 = rmCreateObjectDef("sockets 2 to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddObjectDefItem(socketID2, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID2, true);
	rmAddObjectDefToClass(socketID2, classSocket);
	rmSetObjectDefMinDistance(socketID2, 2.0);
	rmSetObjectDefMaxDistance(socketID2, 8.0);

	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.4);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.7, 0.3);
   rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.0);


	bool placedTradeRoute2 = rmBuildTradeRoute(tradeRouteID2, "snow");

   vector socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.3);
      rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

   socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.7);
      rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);

   if (cNumberNonGaiaPlayers > 4){
      socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID2, 0.5);
         rmPlaceObjectDefAtPoint(socketID2, 0, socketLoc2);
   }

   // Inuit West

   if (subCiv1 == rmGetCivID("inuitnatives"))
   {  
      int tengri1VillageID = -1;
      int tengri1VillageType = rmRandInt(1,5);
      tengri1VillageID = rmCreateGrouping("tengri1 city", "native inuit village 0"+tengri1VillageType);
      rmAddGroupingConstraint(tengri1VillageID, avoidTC);
      rmAddGroupingConstraint(tengri1VillageID, avoidCW);
      rmAddGroupingConstraint(tengri1VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(tengri1VillageID, avoidSocketLong);
      rmAddGroupingConstraint(tengri1VillageID, avoidSocketLongTrade);
      rmAddGroupingConstraint(tengri1VillageID, avoidGlacier);
      //rmAddGroupingConstraint(tengri1VillageID, avoidTradeRoute);
      rmAddClosestPointConstraint(villageEdgeConstraint);
      rmSetGroupingMinDistance(tengri1VillageID, 0);
      rmSetGroupingMaxDistance(tengri1VillageID, 120);

      int tengri2VillageID = -1;
      int tengri2VillageType = rmRandInt(1,5);
      tengri2VillageID = rmCreateGrouping("tengri2 city", "native inuit village 0"+tengri2VillageType);
      rmAddGroupingConstraint(tengri2VillageID, avoidTC);
      rmAddGroupingConstraint(tengri2VillageID, avoidCW);
      rmAddGroupingConstraint(tengri2VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(tengri2VillageID, avoidSocketLong);
      rmAddGroupingConstraint(tengri2VillageID, avoidSocketLongTrade);
      rmAddGroupingConstraint(tengri2VillageID, avoidGlacier);
      //rmAddGroupingConstraint(tengri2VillageID, avoidTradeRoute);
      rmAddClosestPointConstraint(villageEdgeConstraint);
      rmSetGroupingMinDistance(tengri2VillageID, 0);
      rmSetGroupingMaxDistance(tengri2VillageID, 120);

      rmPlaceGroupingAtLoc(tengri2VillageID, 0, 0.2, 0.5, 1);

      if (cNumberNonGaiaPlayers <= 4){
      rmPlaceGroupingAtLoc(tengri1VillageID, 0, 0.2, 0.5, 1);
      }

      else {
      rmPlaceGroupingAtLoc(tengri1VillageID, 0, 0.2, 0.5, 2);
      }

      rmClearClosestPointConstraints();
   }

   // Nootka

   if (subCiv0 == rmGetCivID("inuitnatives"))
   {  
      int nootka1VillageID = -1;
      int nootka1VillageType = rmRandInt(1,5);
      nootka1VillageID = rmCreateGrouping("nootka1 city", "native inuit village 0"+nootka1VillageType);
      rmAddGroupingConstraint(nootka1VillageID, avoidTC);
      rmAddGroupingConstraint(nootka1VillageID, avoidCW);
      rmAddGroupingConstraint(nootka1VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(nootka1VillageID, avoidSocketLongNootka);
      rmAddGroupingConstraint(nootka1VillageID, avoidSocketLongTrade);
      rmAddGroupingConstraint(nootka1VillageID, avoidGlacier);
      rmAddClosestPointConstraint(villageEdgeConstraint);
      rmSetGroupingMinDistance(nootka1VillageID, 0);
      rmSetGroupingMaxDistance(nootka1VillageID, 120);

      int nootka2VillageID = -1;
      int nootka2VillageType = rmRandInt(1,5);
      nootka2VillageID = rmCreateGrouping("nootka2 city", "native inuit village 0"+nootka2VillageType);
      rmAddGroupingConstraint(nootka2VillageID, avoidTC);
      rmAddGroupingConstraint(nootka2VillageID, avoidCW);
      rmAddGroupingConstraint(nootka2VillageID, avoidImpassableLand);
      rmAddGroupingConstraint(nootka2VillageID, avoidSocketLongNootka);
      rmAddGroupingConstraint(nootka2VillageID, avoidSocketLongTrade);
      rmAddGroupingConstraint(nootka2VillageID, avoidGlacier);
      rmAddClosestPointConstraint(villageEdgeConstraint);
      rmSetGroupingMinDistance(nootka2VillageID, 0);
      rmSetGroupingMaxDistance(nootka2VillageID, 120);

      rmPlaceGroupingAtLoc(nootka2VillageID, 0, 0.8, 0.5, 1);

      if (cNumberNonGaiaPlayers <= 4){
      rmPlaceGroupingAtLoc(nootka1VillageID, 0, 0.8, 0.5, 1);
      }

      else {
      rmPlaceGroupingAtLoc(nootka1VillageID, 0, 0.8, 0.5, 2);
      }

      rmClearClosestPointConstraints();
   }

      // Place King's Hill
   if (rmGetIsKOTH() == true) {
      int KOTHVariation = rmRandInt(1,2);
      if (KOTHVariation == 1) {
         ypKingsHillPlacer(0.22, 0.22, 0.00, 0);
      }
      if (KOTHVariation == 2) {
         ypKingsHillPlacer(0.78, 0.78, 0.00, 0);
      }
	}



// Text
	rmSetStatusText("",0.30);


// Place Town Centers
		rmSetTeamSpacingModifier(0.6);

      float teamStartLoc = rmRandFloat(0.0, 1.0);
		if(cNumberTeams > 2)
		{
			rmSetPlacementSection(0.00, 1.00);
			rmSetTeamSpacingModifier(0.75);
			rmPlacePlayersCircular(0.4, 0.4, 0);
		}
		else
		{
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.75, 0.00);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.25, 0.50); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.25, 0.50);
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.75, 0.00); 
				rmPlacePlayersCircular(0.40, 0.40, rmDegreesToRadians(5.0));
			}
		}



// Insert Players
 int TCfloat = -1;
   if (cNumberTeams == 2)
	   TCfloat = 50;
   else 
	   TCfloat = 135;

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
rmAddObjectDefConstraint(TCID, avoidSocketLongNootka);
rmAddObjectDefConstraint(TCID, avoidSocketLong);
rmAddObjectDefConstraint(TCID, avoidGlacier);


//Player resources
   int playerSilverID = rmCreateObjectDef("player silver");
	rmAddObjectDefItem(playerSilverID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(playerSilverID, 10.0);
	rmSetObjectDefMaxDistance(playerSilverID, 30.0);
   rmAddObjectDefConstraint(playerSilverID, avoidImpassableLand); 

   int playerDeerID=rmCreateObjectDef("player deer");
   rmAddObjectDefItem(playerDeerID, "caribou", rmRandInt(10,15), 10.0);
   rmSetObjectDefMinDistance(playerDeerID, 15.0);
   rmSetObjectDefMaxDistance(playerDeerID, 30.0);
   rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(playerDeerID, true);

rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
rmAddObjectDefConstraint(TCID, avoidImpassableLand);
rmAddObjectDefConstraint(TCID, playersAwayPort);
rmAddObjectDefConstraint(TCID, avoidBonusIslands);
rmAddObjectDefConstraint(TCID, avoidSocket);


  

for(i=1; <cNumberPlayers) {

// Place town centers
   rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

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
   rmAddAreaConstraint(colonyShipID, ObjectAvoidTradeRoute);
   vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

// Place resources
   rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
   rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   rmPlaceObjectDefAtLoc(playerSilverID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
   rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

   if(ypIsAsian(i) && rmGetNomadStart() == false)
     rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
}

rmClearClosestPointConstraints();

// Text
	rmSetStatusText("",0.50);

// check for KOTH game mode
    
   /*if(rmGetIsKOTH()) {

   ypKingsHillPlacer(0.2, 0.8, 0, 0);

   }*/
   
   // MINES

   int silverType = -1;
	int westilverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*1.5);
	rmEchoInfo("silver count = "+silverCount);

	for(i=0; < silverCount)
	{
	  int eastSilverID = rmCreateObjectDef("east silver "+i);
	  rmAddObjectDefItem(eastSilverID, "MineGold", 1, 0.0);
      rmSetObjectDefMinDistance(eastSilverID, 0.0);
      rmSetObjectDefMaxDistance(eastSilverID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(eastSilverID, avoidCoin);
      rmAddObjectDefConstraint(eastSilverID, avoidAll);
      rmAddObjectDefConstraint(eastSilverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(eastSilverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(eastSilverID, eastIslandConstraint);
      rmAddObjectDefConstraint(eastSilverID, avoidGlacier);
	  rmPlaceObjectDefAtLoc(eastSilverID, 0, 0.5, 0.5);
   }

	for(i=0; < silverCount)
	{
	  westilverID = rmCreateObjectDef("west silver "+i);
	  rmAddObjectDefItem(westilverID, "MineGold", 1, 0.0);
      rmSetObjectDefMinDistance(westilverID, 0.0);
      rmSetObjectDefMaxDistance(westilverID, rmXFractionToMeters(0.45));
	  rmAddObjectDefConstraint(westilverID, avoidCoin);
      rmAddObjectDefConstraint(westilverID, avoidAll);
      rmAddObjectDefConstraint(westilverID, avoidTownCenterFar);
      rmAddObjectDefConstraint(westilverID, mediumAvoidImpassableLand);
      rmAddObjectDefConstraint(westilverID, westIslandConstraint);
      rmAddObjectDefConstraint(westilverID, avoidGlacier);
	  rmPlaceObjectDefAtLoc(westilverID, 0, 0.5, 0.5);
   } 
	


   // Text
	rmSetStatusText("",0.60);

// FORESTS
 int forestTreeID = 0;
  int numTries=10*cNumberNonGaiaPlayers;
  int failCount=0;
  for (i=0; <numTries) {   
    int forest=rmCreateArea("forest "+i);
    rmSetAreaWarnFailure(forest, false);
    rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
    rmSetAreaForestType(forest, "great lakes forest snow");
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
    rmAddAreaConstraint(forest, labConstraint);
    rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
    rmAddAreaConstraint(forest, avoidBonusIslands);
    rmAddAreaConstraint(forest, avoidGlacier);
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
	rmSetStatusText("",0.70);

// Nuggets
 
	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetNorth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetNorth, avoidAll);
	rmAddObjectDefConstraint(nuggetNorth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetNorth, avoidWater4);
   rmAddObjectDefConstraint(nuggetNorth, labConstraint);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetNorth, 0, westIsland, cNumberNonGaiaPlayers);

   int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nuggetSouth, avoidNugget);
  	rmAddObjectDefConstraint(nuggetSouth, avoidAll);
	rmAddObjectDefConstraint(nuggetSouth, avoidTCshort);
   rmAddObjectDefConstraint(nuggetSouth, labConstraint);
   rmAddObjectDefConstraint(nuggetSouth, avoidWater4);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nuggetSouth, 0, eastIsland, cNumberNonGaiaPlayers);

   int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget2, avoidNugget);
  	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidTCshort);
   rmAddObjectDefConstraint(nugget2, avoidWater4);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget2, 0, bonusIsland2, 1);

   int nugget1= rmCreateObjectDef("nugget hard 2"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(4, 4);
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget1, avoidNugget);
  	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidTCshort);
   rmAddObjectDefConstraint(nugget1, avoidWater4);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, bonusIsland1, 1);


      // Water nuggets

   int nuggetCount = 1;
   

   int nugget2b = rmCreateObjectDef("nugget water hard" + i); 
   rmAddObjectDefItem(nugget2b, "ypNuggetBoat", 1, 0.0);
   rmSetNuggetDifficulty(6, 6);
   rmSetObjectDefMinDistance(nugget2b, rmXFractionToMeters(0.25));
   rmSetObjectDefMaxDistance(nugget2b, rmXFractionToMeters(1.0));
   rmAddObjectDefConstraint(nugget2b, avoidLand);
   rmAddObjectDefConstraint(nugget2b, ObjectAvoidTradeRoute);
   rmAddObjectDefConstraint(nugget2b, avoidNuggetWater);
   rmAddObjectDefConstraint(nugget2b, playerEdgeConstraint);
   rmPlaceObjectDefPerPlayer(nugget2b, false, nuggetCount);

   // Text
	rmSetStatusText("",0.80);

   // DEER	East
   int deerID=rmCreateObjectDef("deer herd");
	int bonusChance=rmRandFloat(0, 1);
   if(bonusChance<0.5)   
      rmAddObjectDefItem(deerID, "muskOx", rmRandInt(4,6), 10.0);
   else
      rmAddObjectDefItem(deerID, "muskOx", rmRandInt(8,10), 10.0);
   rmSetObjectDefMinDistance(deerID, 0.0);
   rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deerID, avoidAll);
   rmAddObjectDefConstraint(deerID, labConstraint);
   rmAddObjectDefConstraint(deerID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(deerID, true);
   rmPlaceObjectDefInArea(deerID, 0, eastIsland, cNumberNonGaiaPlayers);

   // DEER	West
   int deer2ID=rmCreateObjectDef("mush deer herd");
   if(bonusChance<0.5)   
      rmAddObjectDefItem(deer2ID, "ypmuskdeer", rmRandInt(4,6), 10.0);
   else
      rmAddObjectDefItem(deer2ID, "ypmuskdeer", rmRandInt(8,10), 10.0);
   rmSetObjectDefMinDistance(deer2ID, 0.0);
   rmSetObjectDefMaxDistance(deer2ID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(deer2ID, avoidAll);
   rmAddObjectDefConstraint(deer2ID, labConstraint);
   rmAddObjectDefConstraint(deer2ID, avoidImpassableLand);
   rmSetObjectDefCreateHerd(deer2ID, true);
   rmPlaceObjectDefInArea(deer2ID, 0, westIsland, cNumberNonGaiaPlayers);

   // Text
	rmSetStatusText("",0.90);

//Fishes

   int fishID=rmCreateObjectDef("fish Salmon");
   rmAddObjectDefItem(fishID, "FishSalmon", 1, 0.0);
   rmSetObjectDefMinDistance(fishID, 0.0);
   rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(fishID, fishVsFishID);
   rmAddObjectDefConstraint(fishID, fishLand);
   rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 18*cNumberNonGaiaPlayers);

   int whaleID=rmCreateObjectDef("whale");
   rmAddObjectDefItem(whaleID, "HumpbackWhale", 1, 0.0);
   rmSetObjectDefMinDistance(whaleID, 0.0);
   rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
   rmAddObjectDefConstraint(whaleID, whaleLand);
   rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

   // RANDOM TREES
   int randomTreeID=rmCreateObjectDef("random tree");
   rmAddObjectDefItem(randomTreeID, "TreeGreatLakesSnow", 1, 0.0);
   rmSetObjectDefMinDistance(randomTreeID, 0.0);
   rmSetObjectDefMaxDistance(randomTreeID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(randomTreeID, avoidImpassableLand);
   rmAddObjectDefConstraint(randomTreeID, labConstraint);
   rmAddObjectDefConstraint(randomTreeID, avoidAll); 
   rmAddObjectDefConstraint(randomTreeID, avoidGlacier);
   rmAddObjectDefConstraint(randomTreeID, avoidTCMedium);

   rmPlaceObjectDefAtLoc(randomTreeID, 0, 0.5, 0.5, 15*cNumberNonGaiaPlayers);

//Water revealers

int revealerID=rmCreateObjectDef("water revealer");
   rmAddObjectDefItem(revealerID, "zpCinematicRevealerToAll", 1, 0.0);
   rmSetObjectDefMinDistance(revealerID, 0.0);
   rmSetObjectDefMaxDistance(revealerID, rmXFractionToMeters(0.5));
   rmAddObjectDefConstraint(revealerID, RevealerVSRevealer);
   rmAddObjectDefConstraint(revealerID, fishLand);
   rmPlaceObjectDefAtLoc(revealerID, 0, 0.5, 0.5, 46*cNumberNonGaiaPlayers);

// ------Triggers--------//

int tch0=1671; // tech operator

// Map Revealer
/*rmCreateTrigger("Fade Out revealers");
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",0);
rmSetTriggerEffectParamFloat("TechID",4428+tch0); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);*/

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
rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientists"); //operator
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


// Submarine Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("TrainPrivateer1ON Plr"+k);
rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
rmCreateTrigger("TrainPrivateer1TIME Plr"+k);


rmCreateTrigger("TrainPrivateer2ON Plr"+k);
rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","89");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
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
rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine2"); //operator
rmSetTriggerEffectParamInt("Status",0);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
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
rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
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

rmCreateTrigger("UniqueShip2TIMEPlr"+k);

rmCreateTrigger("BlackbTrain2ONPlr"+k);
rmCreateTrigger("BlackbTrain2OFFPlr"+k);


rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceSteamerBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Steamer 2

rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","89");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer2"); //operator
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


// Build limit reducer
rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceSteamerBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Steamer 1
rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer1"); //operator
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
  

}

// Nautilus Training

for (k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("Nautilus1TIMEPlr"+k);

rmCreateTrigger("Nautilus1ONPlr"+k);
rmCreateTrigger("Nautilus1OFFPlr"+k);

rmCreateTrigger("Nautilus2TIMEPlr"+k);

rmCreateTrigger("Nautilus2ONPlr"+k);
rmCreateTrigger("Nautilus2OFFPlr"+k);

// Build limit reducer 2
rmSwitchToTrigger(rmTriggerID("Nautilus2TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Nautilus 2

rmSwitchToTrigger(rmTriggerID("Nautilus2ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","89");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus2"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Nautilus2OFFPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);


// Build limit reducer 1
rmSwitchToTrigger(rmTriggerID("Nautilus1TIMEPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamFloat("Param1",0.5);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

// Nautilus 1
rmSwitchToTrigger(rmTriggerID("Nautilus1ONPlr"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",1);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTrainNautilus1"); //operator
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1TIMEPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1OFFPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Nautilus1OFFPlr"+k));
rmAddTriggerCondition("Timer");
rmSetTriggerConditionParamInt("Param1",5);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
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
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamFloat("Count",1);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
rmSetTriggerEffectParamInt("SrcPlayer",0);
rmSetTriggerEffectParamInt("TrgPlayer",k);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);

rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
rmAddTriggerCondition("Units in Area");
rmSetTriggerConditionParam("DstObject","5");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParamInt("Dist",35);
rmSetTriggerConditionParam("UnitType","TradingPost");
rmSetTriggerConditionParam("Op","==");
rmSetTriggerConditionParamFloat("Count",0);
rmAddTriggerEffect("Convert Units in Area");
rmSetTriggerEffectParam("SrcObject","5");
rmSetTriggerEffectParamInt("SrcPlayer",k);
rmSetTriggerEffectParamInt("TrgPlayer",0);
rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
rmSetTriggerEffectParamInt("Dist",100);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
rmAddTriggerEffect("Disable Trigger");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}


   for (k=1; <= cNumberNonGaiaPlayers) {
   rmCreateTrigger("Pirates2on Player"+k);
   rmCreateTrigger("Pirates2off Player"+k);

   rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","89");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op",">=");
   rmSetTriggerConditionParamFloat("Count",1);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","89");
   rmSetTriggerEffectParamInt("SrcPlayer",0);
   rmSetTriggerEffectParamInt("TrgPlayer",k);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
   rmSetTriggerEffectParamInt("Dist",100);
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
   rmAddTriggerEffect("Fire Event");
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);

   rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
   rmAddTriggerCondition("Units in Area");
   rmSetTriggerConditionParam("DstObject","89");
   rmSetTriggerConditionParamInt("Player",k);
   rmSetTriggerConditionParamInt("Dist",35);
   rmSetTriggerConditionParam("UnitType","TradingPost");
   rmSetTriggerConditionParam("Op","==");
   rmSetTriggerConditionParamFloat("Count",0);
   rmAddTriggerEffect("Convert Units in Area");
   rmSetTriggerEffectParam("SrcObject","89");
   rmSetTriggerEffectParamInt("SrcPlayer",k);
   rmSetTriggerEffectParamInt("TrgPlayer",0);
   rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag2");
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
   rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus2ONPlr"+k));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(false);
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
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistNemo"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (pirateCaptain==2)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistNemo"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
if (pirateCaptain==3)
   {
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistkhora"); //operator
      rmSetTriggerEffectParamInt("Status",2);
      rmAddTriggerEffect("ZP Set Tech Status (XS)");
      rmSetTriggerEffectParamInt("PlayerID",k);
      rmSetTriggerEffectParam("TechID","cTechzpAIAirshipSetup"); //operator
      rmSetTriggerEffectParamInt("Status",2);
   }
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}

// Testing
/*
for (k=1; <= cNumberNonGaiaPlayers) {

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
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",4929);
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Set Tech Status");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParamFloat("TechID",3645);
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}*/




   // Text
	rmSetStatusText("",1.0);

} 