// Land Unknown adapted to Rocket
// ver 11 Jan 2005
// edited by vividlyplain June 2021 to include assets from other regions incorporated since vanilla
// edited by vividlyplain December 2021, new trade route logic, new terrains, and some fun stuff xD
// February 2022 and onward, updated by vivid to include more fun stuff and some added biomes
// special thanks to Ev0lution, Daniel, Enki_, dansil92 for all the help and inspiration
// updated by vivid and Roda for Age of Pirates Mod, October 2024
// last updated November 2025

include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";
include "mercenaries.xs";

void main(void)
{
    int teamZeroCount = rmGetNumberPlayersOnTeam(0);
    int teamOneCount = rmGetNumberPlayersOnTeam(1);
	int numTries=0;
	int failCount=0;
	int frozenLake = 0;
	int trollBar = rmRandInt(1,20);
//		trollBar = 1;		// for testing
	int chaosBar = rmRandInt(1,100);
//		chaosBar = 1;		// for testing
	int speedyShipment = 0;
//		speedyShipment = 1;		// for testing

	// April Fools Stuff
	int aprilFools = rmRandInt(1,1000);
	if (aprilFools == 20 && rmGetIsTreaty() == true)
		aprilFools = rmRandInt(1,19);
//		aprilFools = 1;		// for testing
	
	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 1.00);
	else if (trollBar == 1)
		rmSetStatusText("", 1.00);
	else
		rmSetStatusText("",0.01);

	// ============= Land and Water Configuration =============
	int allLand = 1;				// unused
	int sagTest = 1;				// unused
	int riverExists = -1;			// river is present
	int oceanMiddle = -1;			// great lake style spawn
	int oceanOffCenter = -1;		// saguenay style spawn
	int oceanRing = -1;				// borneo style spawn
	int splitIsland = -1;			// caribbean style spawn
	int plateauMiddle = -1;			// unused
	int forestMiddle = -1;			// big central forest
	int blockedMiddle = -1; 		// used to restrict trade routes to circular/square layouts
	int fountainChance = -1;		// small chance to spawn the fountain of youth object
	int landOnly = -1;				// open map
	int floodedLand = -1;			// swamp style map (shallow buildable flooded land)
	int fullShallow = -1;			// river is crossable at every point
	int ahoyMeMatey = -1;			// used to spawn pirates
	int electorSpawn = -1;			// used to spawn electors
	int SPCZenMountain = -1;
	int SPCSufiMiddleEast = -1;
	int rogueMap = -1;				// rogue feature
//		rogueMap = 1;							// for testing
//		rmSetMapType("piratehistoricalmap");	// for testing
	int riverWidthController = 0;	// used to control for amazonia style spawn
	if (rmRandFloat(0,1) <= 0.95 || rmGetIsTreaty() == true)
		riverWidthController = 1;	// normal, narrow river
//		riverWidthController = 0; 	// for testing

	if (rmRandFloat(0,1) <= 0.15)
		fullShallow = 1;
		
	float landConfig = rmRandFloat(0,1);	// RNG for map layout
//	if (rmGetIsKOTH() == true)
//		landConfig = rmRandFloat(0.04,0.18);
//		landConfig = 0.73;		// for testing
		rmEchoInfo("land configuration = "+landConfig);

	// ============= Land and Water Configuration =============
	if (rmGetIsKOTH() == true)
	{
		if (landConfig < 0.10)
		{
			floodedLand = 1;
		}
		else if (landConfig < 0.35)
		{
			oceanRing = 1;
		}
		else if (landConfig < 0.65)
		{
			landOnly = 1;
		}
		else
		{
			oceanOffCenter = 1;
		}
	}
	else
	{
		if (landConfig < 0.04)
		{
			floodedLand = 1;
		}
		else if (landConfig < 0.19)
		{
			oceanRing = 1;
		}
		else if (landConfig < 0.29)
		{
			splitIsland = 1;
			rogueMap = 0;
		}
		else if (landConfig < 0.39)
		{
			landOnly = 1;
		}
		else if (landConfig < 0.49)
		{
			riverExists = 1;
			rogueMap = 0;
		}
		else if (landConfig < 0.74)
		{
			oceanMiddle = 1;
			blockedMiddle = 1;
			if (rmRandFloat(0,1) <= 0.10)
				fountainChance = 1;
		}		
		else if (landConfig < 0.98)
		{
			oceanOffCenter = 1;
		}
		else
		{
			forestMiddle = 1;
			rogueMap = 0;
		}
	}

	// Set size.
	int playerTiles=11000;
	if (oceanRing == 1 || splitIsland == 1)	// big island
	{
		if (cNumberNonGaiaPlayers == 2)
			playerTiles = 20000;
		if (cNumberNonGaiaPlayers > 2)
			playerTiles = 18000;
		if (cNumberNonGaiaPlayers > 4)
			playerTiles = 16000;
		if (cNumberNonGaiaPlayers > 6)
			playerTiles = 14000;
	}
	else
	{
		if (rmGetIsTreaty() == true)
		{
			if (cNumberNonGaiaPlayers == 2)
				playerTiles = 13000;
			if (cNumberNonGaiaPlayers > 2)
				playerTiles = 11000;
			if (cNumberNonGaiaPlayers > 4)
				playerTiles = 10000;
			if (cNumberNonGaiaPlayers > 6)
				playerTiles = 9000;
		}
		else
		{
			if (cNumberNonGaiaPlayers == 2)
				playerTiles = 11000;
			if (cNumberNonGaiaPlayers > 2)
				playerTiles = 10300;
			if (cNumberNonGaiaPlayers > 4)
				playerTiles = 9200;
			if (cNumberNonGaiaPlayers > 6)
				playerTiles = 8100;
		}
	}

	int size=2.0*sqrt(cNumberNonGaiaPlayers*playerTiles);
	rmEchoInfo("Map size="+size+"m x "+size+"m");
	rmSetMapSize(size, size);
	rmSetSeaLevel(0.0);
	if (splitIsland == 1)
		rmSetOceanReveal(true);
	if (floodedLand != 1)
		rmSetMapElevationParameters(cElevTurbulence, 0.02, rmRandFloat(2, 4), 0.7, 8.0);
	else if (chaosBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetMapElevationParameters(cElevTurbulence, 0.06, 1, 0.11, 10.0); // nombre sur la map , détail dans une hauteur , taille , hauteur - from ESOC Thar Desert

	// Choose mercs.
	chooseMercs();
	
	// ============= Choose Natives =============
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	int subCiv3=-1;
	int subCiv4=-1;
	int subCiv5=-1;
	int subCiv6=-1;
	int subCiv7=-1;
	int subCiv8=-1;
	int subCiv9=-1;
	int subCiv10=-1;
	int subCiv11=-1;
	int subCiv12=-1;
	int subCiv13=-1;
	int subCiv14=-1;
	int subCiv15=-1;
	int subCiv16=-1;
	int subCiv17=-1;
	int subCiv18=-1;
	int subCiv19=-1;
	int subCiv20=-1;
	int subCiv21=-1;
	int subCiv22=-1;
	int subCiv23=-1;
	int subCiv24=-1;
	int subCiv25=-1;
	int subCiv26=-1;
	int subCiv27=-1;
	int subCiv28=-1;
	int subCiv29=-1;
	int subCiv30=-1;
	int subCiv31=-1;
	int subCiv32=-1;
	int subCiv33=-1;
	int subCiv34=-1;
	int subCiv35=-1;
	int subCiv36=-1;
	int subCiv37=-1;
	int subCiv38=-1;
	int subCiv39=-1;
	int subCiv40=-1;
	int subCiv41=-1;
	int subCiv42=-1;
	int subCiv43=-1;
	int subCiv44=-1;
	int subCiv45=-1;
	int subCiv46=-1;
	int subCiv47=-1;
	int subCiv48=-1;
	int subCiv49=-1;
	int subCiv50=-1;
	int subCiv51=-1;
	int subCiv52=-1;
	int subCiv53=-1;
	int subCiv54=-1;
	int subCiv55=-1;
	int subCiv56=-1;
	int subCiv57=-1;
	int subCiv58=-1;
	int subCiv59=-1;
	int subCiv60=-1;

	if (rmAllocateSubCivs(61) == true)
	{
		subCiv0 = rmGetCivID("Aztecs");
		subCiv1 = rmGetCivID("Caribs");
		subCiv2 = rmGetCivID("Cherokee");
		subCiv3 = rmGetCivID("Comanche");
		subCiv4 = rmGetCivID("Cree");
		subCiv5 = rmGetCivID("Incas");	
		subCiv6 = rmGetCivID("Iroquois");
		subCiv7 = rmGetCivID("Lakota");
		subCiv8 = rmGetCivID("Maya");	
		subCiv9 = rmGetCivID("Nootka");
		subCiv10 = rmGetCivID("Seminoles");
		subCiv11 = rmGetCivID("Tupi");	
		subCiv12 = rmGetCivID("Apache");
		subCiv13 = rmGetCivID("Cheyenne");
		subCiv14 = rmGetCivID("Huron");	
		subCiv15 = rmGetCivID("Klamath");
		subCiv16 = rmGetCivID("Navajo");
		subCiv17 = rmGetCivID("Mapuche");	
		subCiv18 = rmGetCivID("Zapotec");
		subCiv19 = rmGetCivID("Bhakti");
		subCiv20 = rmGetCivID("zpScientists");
		subCiv21 = rmGetCivID("Shaolin");
		subCiv22 = rmGetCivID("Wokou");
		subCiv23 = rmGetCivID("Udasi");	
		subCiv24 = rmGetCivID("NatPirates");
		subCiv25 = rmGetCivID("Akan");
		subCiv26 = rmGetCivID("Berbers");
		subCiv27 = rmGetCivID("Somali");
		subCiv28 = rmGetCivID("Sudanese");
		subCiv29 = rmGetCivID("Yoruba");
		subCiv30 = rmGetCivID("DESPCLenape");
		subCiv31 = rmGetCivID("Saltpeter");
		subCiv32 = rmGetCivID("SPCBourbon");
		subCiv33 = rmGetCivID("Habsburg");
		subCiv34 = rmGetCivID("Hanover");
		subCiv35 = rmGetCivID("Jagiellon");
		subCiv36 = rmGetCivID("Oldenburg");
		subCiv37 = rmGetCivID("Phanar");
		subCiv38 = rmGetCivID("Vasa");
		subCiv39 = rmGetCivID("Wettin");
		subCiv40 = rmGetCivID("Wittelsbach");
		subCiv41 = rmGetCivID("Tengri");
		subCiv42 = rmGetCivID("PenalColony");
		subCiv43 = rmGetCivID("Maltese");
		subCiv44 = rmGetCivID("Jewish");
		subCiv45 = rmGetCivID("InuitNatives");
		subCiv46 = rmGetCivID("MaoriNatives");
		subCiv47 = rmGetCivID("zpOrthodox");
		subCiv48 = rmGetCivID("zpWesternVillage");
		subCiv49 = rmGetCivID("AboriginalNatives");
		subCiv50 = rmGetCivID("Korowai");
		subCiv51 = rmGetCivID("SPCZen");
		subCiv52 = rmGetCivID("SPCSufi");
		subCiv53 = rmGetCivID("SPCJesuit");
		subCiv54 = rmGetCivID("zpXmassVillage");
		subCiv55 = rmGetCivID("zpvenetians");
		subCiv56 = rmGetCivID("Auditore");
		subCiv57 = rmGetCivID("zphussites");
		subCiv58 = rmGetCivID("zpPrinceElector");
		subCiv59 = rmGetCivID("zphansakontor");
		subCiv60 = rmGetCivID("zpCossacks");

		rmSetSubCiv(0, "Aztecs");
		rmSetSubCiv(1, "Caribs");
		rmSetSubCiv(2, "Cherokee");
		rmSetSubCiv(3, "Comanche");
		rmSetSubCiv(4, "Cree");
		rmSetSubCiv(5, "Incas");	
		rmSetSubCiv(6, "Iroquois");
		rmSetSubCiv(7, "Lakota");
		rmSetSubCiv(8, "Maya");	
		rmSetSubCiv(9, "Nootka");
		rmSetSubCiv(10, "Seminoles");
		rmSetSubCiv(11, "Tupi");	
		rmSetSubCiv(12, "Apache");
		rmSetSubCiv(13, "Cheyenne");
		rmSetSubCiv(14, "Huron");	
		rmSetSubCiv(15, "Klamath");
		rmSetSubCiv(16, "Navajo");
		rmSetSubCiv(17, "Mapuche");	
		rmSetSubCiv(18, "Zapotec");
		rmSetSubCiv(19, "Bhakti");
		rmSetSubCiv(20, "zpScientists");	
		rmSetSubCiv(21, "Shaolin");
		rmSetSubCiv(22, "Wokou");
		rmSetSubCiv(23, "Udasi");	
		rmSetSubCiv(24, "NatPirates");
		rmSetSubCiv(25, "Akan");
		rmSetSubCiv(26, "Berbers");
		rmSetSubCiv(27, "Somali");
		rmSetSubCiv(28, "Sudanese");
		rmSetSubCiv(29, "Yoruba");
		rmSetSubCiv(30, "DESPCLenape");
		rmSetSubCiv(31, "Saltpeter");
		rmSetSubCiv(32, "SPCBourbon");
		rmSetSubCiv(33, "Habsburg");
		rmSetSubCiv(34, "Hanover");
		rmSetSubCiv(35, "Jagiellon");
		rmSetSubCiv(36, "Oldenburg");
		rmSetSubCiv(37, "Phanar");
		rmSetSubCiv(38, "Vasa");
		rmSetSubCiv(39, "Wettin");
		rmSetSubCiv(40, "Wittelsbach");
		rmSetSubCiv(41, "Tengri");
		rmSetSubCiv(42, "PenalColony");
		rmSetSubCiv(43, "Maltese");
		rmSetSubCiv(44, "Jewish");
		rmSetSubCiv(45, "InuitNatives");
		rmSetSubCiv(46, "MaoriNatives");
		rmSetSubCiv(47, "zpOrthodox");
		rmSetSubCiv(48, "zpWesternVillage");
		rmSetSubCiv(49, "AboriginalNatives");
		rmSetSubCiv(50, "Korowai");
		rmSetSubCiv(51, "SPCZen");
		rmSetSubCiv(52, "SPCSufi");
		rmSetSubCiv(53, "SPCJesuit");
		rmSetSubCiv(54, "zpXmassVillage");
		rmSetSubCiv(55, "zpvenetians");
		rmSetSubCiv(56, "Auditore");
		rmSetSubCiv(57, "zphussites");
		rmSetSubCiv(58, "zpPrinceElector");
		rmSetSubCiv(59, "zphansakontor");
		rmSetSubCiv(60, "zpCossacks");
	}

	// ============= Base terrain ============= 
	int trollMap = -1;
	int amazonMap = -1;
	int treasureIsle = -1;		// chance to spawn islands in side bay or center lake
	int carolinaMap = -1;
	int saguenayMap = -1;
	int rockiesMap = -1;
	int sonoraMap = -1;
	int californiaMap = -1;
	int caribbeanMap = -1;
	int yellowRiverMap = -1;
	int dekkanMap = -1;
	int silkRoadMap = -1;		// chance for capturable TPs on himalMap
	int himalMap = -1;
	int borneoMap = -1;
	int japanMap = -1;
	int andesMap = -1;
	int saharaMap = -1;			// chance for capturable TPs on africanMap
	int africanMap = -1;
	int afrEast = -1;
	int afrRainforest = -1;
	int afrDesert = -1;
	int afrSavanna = -1;
	int euMap = -1;
	int asianMap = -1;
	int indonesiaMap = -1;
	int honshuMap = -1;
	int africanMerc = -1;		// regional mercs
	int africanDesertMerc = -1;	// regional mercs
	int americanMerc = -1;		// regional mercs
	int mexicanMerc = -1;		// regional mercs
	int asianMerc = -1;			// regional mercs
	int europeanMerc = -1;		// regional mercs
	int southAmMerc = -1;		// regional mercs
	int commandPost = -1;		// circus tent spawn
	int heroDog = -1;			// explorer dog
	int heroSheep = -1;			// lamb of the creator
	int bombActivator = -1;		// huang bomb controller
	int surgeonScout = -1;		// surgeon and field hospitals
	int campaignHero = rmRandInt(1,1000);	// random campaign hero
//		campaignHero = 1;	// for testing
	int mercCount = 3;
	int sennarMerc = -1;
	int askariMerc = -1;
	int dahomeyMerc = -1;
	int cannoneerMerc = -1;
	int zenataMerc = -1;
	int kanuriMerc = -1;
	int gatCamelMerc = -1;
	int corsairMerc = -1;
	int mamaMerc = -1;
	int mercBohemianKnight = -1;
	int mercHussiteWagon = -1;
	int mercSwissPike = -1;
	int mercHacka = -1;
	int mercJaeg = -1;
	int mercBombard = -1;
	int mercGiantGren = -1;
	int mercPanda = -1;
	int mercRoyalHorse = -1;
	int mercPistoleer = -1;
	int mercBrigadier = -1;
	int mercMountedRifle = -1;
	int mercBozzer = -1;
	int mercBRider = -1;
	int mercElmetto = -1;
	int mercFusileer = -1;
	int mercHighland = -1;
	int mercHarq = -1;
	int mercLandshark = -1;
	int mercStrad = -1;
	int outlawCount = 2;
	int crabatOutlaw = -1;
	int hajdukOutlaw = -1;
	int highwayOutlaw = -1;
	int inquisitorOutlaw = -1;
	int cossackOutlaw = -1;
	int manchuMerc = -1;
	int ninjaMerc = -1;
	int samMerc = -1;
	int yojimboMerc = -1;
	int jatMerc = -1;
	int ironMerc = -1;
	int autoCattle = -1;		// african starting cattle spawn on map
	int plymouthMap = -1;
	int naMap = -1;
	int araucMap = -1;
	int bayouMap = -1;
	int mongolMap = -1;
	int nwtMap = -1;
	int saMap = -1;
	int gpMap = -1;
	int snowMap = -1;
	int waterNuggz = -1;		// water nuggets spawn
	int tpCapture = -1;			// capturable trade posts
	int volcanoMap = -1;		// big volcano
//	if (rmRandFloat(0,1) <= 0.17)
//		volcanoMap = 1;
//		volcanoMap = 1;	// for testing
	int ausMap = -1;
	int hawMap = -1;
	int oceaniaMap = -1;
	int merryXmass = -1;
	int centralEU = -1;
	int westEU = -1;
	int northwestEU = -1;
	int mediSeaEU = -1;
	int mediEU = -1;
	int eastEU = -1;
	int northEU = -1;
	int northeastEU = -1;
	int icelandMap = -1;
	int icelandEU = -1;

	// strings
	string riverName = "";
	string oceanName = "";
	string pondName = "";
	string cliffName = "";
	string volcCliffLow = "";
	string volcCliffMid = "";
	string volcCliffHigh = "";
    string volcCliffCrater = "ZP Hawaii Crater";
    string volcTerrainLow = "";
    string volcTerrainHigh = "lava\volcano_dirt";
    string volcTerrainCrater = "lava\crater";
    string volcTerrainCraterPass = "lava\crater_passable";
    string volcTerrainLava = "lava\lavaflow";
	string forestName = "";
	string baseMix = "";
	string landName = "";
	string treeName = "";
	string startingCritterName = "";
	string critterOneName = "";
	string critterTwoName = "";
	string livestockName = "";
	string fishName = "";
	string whaleName = "";
	string toiletPaper = "";
	string mineralz = "";
	string petName1 = "";
	string propz = "";
	string shineAlight = "";

	float baseTerrain = rmRandFloat(0,1);	// RNG to select biome
//		baseTerrain = 0.06;		// for testing
		rmEchoInfo("base terrain = "+baseTerrain);
	
	if(baseTerrain <= 0.001)	// trollolo
		trollMap = 1;
	else if(baseTerrain <= 0.035)
		californiaMap = 1;
	else if(baseTerrain <= 0.07)
		carolinaMap = 1;
	else if(baseTerrain <= 0.105)
		sonoraMap = 1;
	else if(baseTerrain <= 0.14)
		caribbeanMap = 1;
	else if(baseTerrain <= 0.175)
		yellowRiverMap = 1;
	else if(baseTerrain <= 0.21)
		dekkanMap = 1;
	else if(baseTerrain <= 0.245)
		himalMap = 1;
	else if(baseTerrain <= 0.28)
		borneoMap = 1;
	else if(baseTerrain <= 0.315)
		japanMap = 1;
	else if(baseTerrain <= 0.35)
		andesMap = 1;
	else if(baseTerrain <= 0.385)
		araucMap = 1;
	else if(baseTerrain <= 0.42)
		mongolMap = 1;
	else if(baseTerrain <= 0.455 && floodedLand != 1)
		gpMap = 1;
	else if(baseTerrain <= 0.49 && floodedLand != 1)
		bayouMap = 1;
	else if(baseTerrain <= 0.525 && floodedLand != 1)
		nwtMap = 1;
	else if(baseTerrain <= 0.56 && floodedLand != 1)
		amazonMap = 1;
	else if(baseTerrain <= 0.605 && floodedLand != 1)
		saguenayMap = 1;
	else if(baseTerrain <= 0.64 && floodedLand != 1)
		rockiesMap = 1;
	else if(baseTerrain <= 0.78)
		euMap = 1;
	else if(baseTerrain <= 0.80)
		icelandMap = 1;
	else if(baseTerrain <= 0.83)
		afrEast = 1;
	else if(baseTerrain <= 0.86)
		afrSavanna = 1;
	else if(baseTerrain <= 0.89)
		afrRainforest = 1;
	else if(baseTerrain <= 0.92)
		afrDesert = 1;
	else if(baseTerrain <= 0.96)
		hawMap = 1;
	else
		ausMap = 1;

	int whichMix = rmRandInt(1,3);		// chooses terrain for biomes within biome (sometimes enables special maptypes)
//		whichMix = 1;		// for testing
		rmEchoInfo("which mix = "+whichMix);

	// Bonus Wagon Chooser
	int everyoneGetsAWagon = rmRandInt(950,1000);
//		everyoneGetsAWagon = 970;	// for testing
	rmEchoInfo("everyoneGetsAWagon = "+everyoneGetsAWagon);

	if(trollMap == 1)	// trollolo
	{
		chaosBar = 1;
		rmEchoInfo("trololo");
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		baseMix = "unknown funky";
		rmSetMapType("Sahara");
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "rm_afri_congoBasin";
		riverName = "africa rainforest lagoon";
		oceanName = "africa rainforest swamp";
		pondName = "Amazon River";
		cliffName = "Amazon River Bank Muddy";
		forestName = "unknown forest funky";
		if (whichMix == 1)
			landName = "testmix";
		else if (whichMix == 2)
			landName = "scorched_ground";
		else
			landName = "unknown funky";
		treeName = "dePropsTreesAfrica";
		startingCritterName = "ypIGCBird";
		critterOneName = "ypIGCBird";
		critterTwoName = "capybara";
		if (rmRandFloat(0,1) <= 0.50)
			livestockName = "deUnknownWoodCattle";
		else
			livestockName = "deUnknownGoldCattle";
		fishName = "deFishingGround";
		whaleName = "beluga";
		toiletPaper = "water_trail";
		mineralz = "ypSMSaltPeterElephant";	
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "IGCChilche";	
		else if (rmRandFloat(0,1) <= 0.01)
			petName1 = "IGCOldChilche";	
		else if (rmRandFloat(0,1) <= 0.01)
			petName1 = "IGCSeminoleChief";	
		else if (rmRandFloat(0,1) <= 0.50)
			petName1 = "deQuakerGun";	
		else
			petName1 = "SPCWhiteBuffalo";	
		propz = "PropsCave";	
		campaignHero = 1;
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			volcanoMap = 1;
    	volcCliffLow = "ZP Iceland Low";
    	volcCliffMid = "ZP Iceland Medium";
    	volcCliffHigh = "ZP Iceland High";
    	volcTerrainLow = "lava\volcano_grass";

		// Add Outlaws
		if (rmRandFloat(0,1) <= 0.50)
		{
		    rmEnableOutlaw("deSaloonOutlawBuccaneer");
		    rmEnableOutlaw("deSaloonOutlawBlowgunner");
		    rmEnableOutlaw("deREVGranadero");
			southAmMerc = 1;
		}
		else
		{
	    	rmEnableOutlaw("deSaloonOutlawAfricanSpearman");
	    	rmEnableOutlaw("deSaloonOutlawKnifeThrower");
		    rmEnableOutlaw("deSaloonOutlawArsonist");
			africanDesertMerc = 1;
		}
	}

	else if(amazonMap == 1)		// amazonia
	{
		saMap = 1;
		rmEchoInfo("Amazon terrain");
		if (rmRandFloat(0,1) <= 0.05)
			treasureIsle = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "amazon grass";
		else if (whichMix == 2)
			baseMix = "amazon grass medium";
		else
			baseMix = "amazon grass dirt";
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		rmSetMapType("bayou");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("tropical");
		rmSetMapType("land");
		shineAlight = "Amazonia_Skirmish";
	   if (whichMix == 3)
			riverName = "Amazon Rainforest River Muddy";
		else 
			riverName = "Amazon River";
		oceanName = "Yucatan Coast Alt";
		pondName = "bayou skirmish2";
		if (floodedLand == 1)
			pondName = "Bayou3";
		if (whichMix == 3)
			cliffName = "Amazon River Bank Muddy";
		else
			cliffName = "Amazon";
		forestName = "Amazon Rain Forest";
		if (whichMix == 1)
			landName = "amazon grass medium";
		else if (whichMix == 2)
			landName = "amazon grass dirt";
		else
			landName = "amazon grass";
		treeName = "treeAmazon";
		startingCritterName = "capybara";
		critterOneName = "capybara";
		critterTwoName = "tapir";
		livestockName = "sheep";
		fishName = "fishMahi";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "MineGold";	
		petName1 = "zpSettlerAztec";	
		propz = "HuariStrongholdAndes";	

	    if (rmRandFloat(0,1) <= 0.50 && everyoneGetsAWagon == 981)
		{
			// Add Outlaws and Mercs
	    	rmDisableDefaultMercs(true);
			rmDisableCivTypeMercRestriction(true);
		    rmEnableOutlaw("deSaloonOutlawBuccaneer");
		    rmEnableOutlaw("deSaloonOutlawBlowgunner");
		    rmEnableOutlaw("deREVGranadero");
			rmEnableMerc("MercRonin", -1);
			rmEnableMerc("MercHackapell", -1);
			rmEnableMerc("MercGreatCannon", -1);
			southAmMerc = 1;
		}
	}

	else if(californiaMap == 1)	// cali
	{
		rmEchoInfo("California terrain");
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "california_grass";
		else if (whichMix == 2)
			baseMix = "california_desert2";
		else
			baseMix = "california_desert0";
		if (floodedLand != 1)
			rmTerrainInitialize("california\ground6_cal", 0);
		rmSetMapType("california");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "California_Skirmish";
		riverName = "California River";
		oceanName = "California Coast";
		pondName = "Texas Pond";
		cliffName = "California";
		forestName = "California Redwood Chonky Forest";
		landName = "california_grass";
		treeName = "TreeRedwoodChonky";
		startingCritterName = "pronghorn";
		critterOneName = "pronghorn";
		critterTwoName = "elk";
		livestockName = "sheep";
		fishName = "fishCod";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "MineGold";
		if (rmRandFloat(0,1) <= 0.01)	
			petName1 = "SPCXPChiefBullBear";	
		else
			petName1 = "deMinuteman";	
		propz = "PropGrassFire";	

	    if (rmRandFloat(0,1) <= 0.50 && everyoneGetsAWagon == 981)
		{
		    // Add Outlaws and Mercs
	    	rmDisableDefaultMercs(true);
			rmDisableCivTypeMercRestriction(true);
		    rmEnableOutlaw("deSaloonGunslinger");
		    rmEnableOutlaw("deSaloonCowboy");
		    rmEnableOutlaw("deSaloonOwlhoot");
			rmEnableMerc("MercRonin", -1);
			rmEnableMerc("MercHackapell", -1);
			rmEnableMerc("MercGreatCannon", -1);
			americanMerc = 1;
		}
	}

	else if(carolinaMap == 1)	// carolina
	{
		rmEchoInfo("Carolina terrain");
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "carolina_grass";
		else if (whichMix == 2)
			baseMix = "carolina_grass_dry";
		else
			baseMix = "carolina_grassier";
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		rmSetMapType("carolina");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "Carolina_Skirmish";
		riverName = "Carolina River";
		oceanName = "Texas Coast";
		pondName = "Texas Pond";
		cliffName = "Carolina Inland";
		forestName = "Carolina Pine Forest";
		if (whichMix == 1)
			landName = "carolina_grassier";
		else if (whichMix == 2)
			landName = "carolina_grass";
		else
			landName = "carolina_grass_dry";
		treeName = "treeCarolinaGrass";
		critterOneName = "turkey";
		critterTwoName = "deer";
		startingCritterName = "zpGoose";
		livestockName = "sheep";
		fishName = "fishCod";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "deMineCoalBuildable";
		if (rmRandFloat(0,1) <= 0.69)
			petName1 = "IGCDeerUnit";	
		else
		{
			petName1 = "Surgeon";	
			surgeonScout = 1;	
		}
		propz = "EaglesNest";	
	}

	else if(saguenayMap == 1)		// saguenay, plymouth, yukon
	{
		if (whichMix == 1)
		{
			plymouthMap = 1;
			rmSetMapType("plymouth");
			baseMix = "plymouth_grass";
			if (floodedLand != 1)
				rmTerrainInitialize("saguenay\ground1_sag", 0);
			shineAlight = "NewEngland_Skirmish";
			riverName = "New England Lake";
			oceanName = "New England Skirmish";
			pondName = "New England Lake";
			forestName = "new england forest";
			landName = "plymouth_grass";
			treeName = "TreeNewEngland";
			startingCritterName = "zpGoose";
			critterOneName = "deer";
			critterTwoName = "moose";
			if (rmRandFloat(0,1) >= 0.50)
				petName1 = "TurkeyScout";	
			else
				petName1 = "SPCXPVFSoldier";	
			if (rmRandFloat(0,1) <= 0.50)
				propz = "SPCSignalFireLit";	
			else
			propz = "TurkeyScout";	
		}
		else if (whichMix == 2)
		{
            rmSetMapType("saguenay");
			if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
			baseMix = "saguenay grass";
			if (floodedLand != 1)
				rmTerrainInitialize("saguenay\ground1_sag", 0);
	   		shineAlight = "Saguenay_Skirmish";
			riverName = "Saguenay Lake";
			oceanName = "Hudson Bay";
			pondName = "Saguenay Lake";
			forestName = "Saguenay Forest";
			landName = "saguenay tundra";
			treeName = "treeSaguenay";
			startingCritterName = "zpGoose";
			critterOneName = "moose";
			critterTwoName = "caribou";
			if (rmRandFloat(0,1) <= 0.10)
				petName1 = "SPCWhiteWolf ";	
			else
				petName1 = "PetWolf";	
			propz = "FirewoodPile";	
		}
		else
		{
			snowMap = 1;
    		rmSetMapType("yukon");
			if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
			baseMix = "yukon grass";
			if (floodedLand != 1)
				rmTerrainInitialize("saguenay\ground1_sag", 0);
			shineAlight = "Saguenay_Skirmish";
			riverName = "Yukon River";
			oceanName = "Rockies Lake Ice";
			pondName = "Rockies Lake Ice";
			forestName = "Yukon Forest";
			landName = "italy_snow_dirt";
			treeName = "TreeYukonSnow";
			startingCritterName = "caribou";
			critterOneName = "caribou";
			critterTwoName = "muskox";
			if (rmRandFloat(0,1) <= 0.05)
				petName1 = "PolarBear";	
			else
				petName1 = "zpInuitDogVillager";	
			propz = "zpInuitVilProp";	
		}
		rmEchoInfo("Saguenay terrain");
		rmSetMapType("grass");
		rmSetMapType("land");
		cliffName = "New England Inland";
		livestockName = "sheep";
		fishName = "fishSalmon";
		whaleName = "minkeWhale";
		toiletPaper = "dirt";
		mineralz = "zpJadeMine";	
	}

	else if(rockiesMap == 1)	// rockies
	{
		if (rmRandFloat(0,1) <= 0.10)
			merryXmass = 1;
		rmEchoInfo("Rockies terrain");
		snowMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "italy_snow_grass_blendb";
		else if (whichMix == 2)
			baseMix = "rockies_grass_snow";
		else
			baseMix = "rockies_grass_snowb";
		if (floodedLand != 1)
			rmTerrainInitialize("rockies\groundsnow1_roc", 0);	
		rmSetMapType("yukon");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("land");
		shineAlight = "Rockie_Skirmish";
		riverName = "Yukon River";
		oceanName = "Great Lakes Ice";
		pondName = "Great Lakes Ice";
		cliffName = "Rocky Mountain2";
		forestName = "Rockies Snow Forest";
		if (whichMix == 1)
			landName = "rockies_grass_snowb";
		else if (whichMix == 2)
			landName = "rockies_snow";
		else
			landName = "rockies_grass_snow";
		if (merryXmass == 1)
		{
			critterOneName = "reindeer";
			startingCritterName = "reindeer";
			treeName = "zpChristmassTree";
			petName1 = "zpRudolf";	
//    		rmDisableDefaultMercs(true);
//			rmDisableCivTypeMercRestriction(true);
			rmEnableMerc("zpChristmasPolearm", -1);
			rmEnableMerc("zpChristmasGrenadier", -1);
			rmEnableMerc("zpChristmasOrganGun", -1);
		}
		else
		{
			critterOneName = "caribou";
			startingCritterName = "muskOx";
			treeName = "treeRockiesSnow";
			petName1 = "PetBear";	
		}
		critterTwoName = "muskOx";
		livestockName = "cow";
		fishName = "fishSardine";
		whaleName = "beluga";
		toiletPaper = "snow";
		mineralz = "zpQuarzmine";	
		propz = "zpInuitVilProp";	
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			volcanoMap = 1;
    	volcCliffLow = "ZP Iceland Low";
    	volcCliffMid = "ZP Iceland Medium";
    	volcCliffHigh = "ZP Iceland High";
    	volcTerrainLow = "lava\volcano_snow";
	}

	else if(sonoraMap == 1)		// sonora
	{
		rmEchoInfo("Sonora terrain");
		if (floodedLand != 1)
			rmTerrainInitialize("sonora\ground2_son", 0);
		if (whichMix == 1)
		{
			baseMix = "sonora_dirt";
			riverName = "Sonora River";
			oceanName = "Sonora Coast";
			pondName = "Sonora Coast";
			forestName = "Sonora Forest";
			cliffName = "Sonora";
			landName = "sonora_dirt";
		}
		else if (whichMix == 2)
		{
			baseMix = "painteddesert_groundmix_1";
			riverName = "Painted Desert River";
			oceanName = "Painted Desert Coast";
			pondName = "Painted Desert Lake";
			forestName = "Painteddesert Forest";
			cliffName = "Painteddesert";
			landName = "painteddesert_groundmix_4";
		}
		else
		{
			baseMix = "geometricpatterngrass";
			riverName = "Araucania River";
			oceanName = "Araucania North Coast";
			pondName = "Araucania North Pond";
			forestName = "Araucania Forest";
			cliffName = "Araucania North Coast";
			landName = "araucania_north_grass_a";
		}
		rmSetMapType("sonora");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "Sonora_Skirmish";
		treeName = "TreePaintedDesert";
		critterOneName = "pronghorn";
		critterTwoName = "bison";
		startingCritterName = "bison";
		livestockName = "cow";
		fishName = "FishSalmon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "zpQuarzmine";	
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "SPCXPChiefBraveWolf";	
		else
			petName1 = "SPCFierceCougar";	
		propz = "PropEaglesRocks";	

	    if (rmRandFloat(0,1) <= 0.50 && everyoneGetsAWagon == 981)
		{
	    	// Add Outlaws and Mercs
    		rmDisableDefaultMercs(true);
			rmDisableCivTypeMercRestriction(true);
	    	rmEnableOutlaw("deSaloonDesperado");
	    	rmEnableOutlaw("deSaloonVaquero");
	    	rmEnableOutlaw("deSaloonBandido");
			rmEnableMerc("MercRonin", -1);
			rmEnableMerc("MercHackapell", -1);
			rmEnableMerc("MercGreatCannon", -1);
			mexicanMerc = 1;
		}
	}

	else if(caribbeanMap == 1)			// caribbean
	{
		saMap = 1;
		rmEchoInfo("caribbean terrain");
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "caribbeanSkirmish";
		else if (whichMix == 2)
			baseMix = "caribbean grass";
		else
			baseMix = "california_shoregrass";
		if (floodedLand != 1)
			rmTerrainInitialize("caribbean\ground1_crb", 0);
		rmSetMapType("caribbean");
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "Caribbean_Skirmish";
		riverName = "caribbean coast";
		oceanName = "caribbean coast";
		pondName = "africa desert hole"; 
		cliffName = "Caribbean";
		forestName = "Caribbean Palm Forest Skirmish";
		if (whichMix == 1)
			landName = "caribbean grass";
		else if (whichMix == 2)
			landName = "caribbeanSkirmish";
		else
			landName = "caribbean grass";
		treeName = "treeCaribbean";
		critterOneName = "turkey";
		critterTwoName = "deer";
		startingCritterName = "deer";
		livestockName = "sheep";
		fishName = "fishTarpon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "deShipRuins";		
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "SPCAztecChief";	
		else
			petName1 = "deGuardBucCaptain";	
		propz = "IGCShipwreck";	
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			volcanoMap = 1;
		else
		{
			if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		volcCliffLow = "ZP Hawaii Medium";
		volcCliffMid = "ZP Hawaii High 2";
		volcCliffHigh = "ZP Hawaii High";
    	volcTerrainLow = "lava\volcano_grass";
	}

	else if(yellowRiverMap == 1)			// yellow river
	{
		rmEchoInfo("yellow river terrain");
		asianMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "yellow_river_a";
		else if (whichMix == 2)
			baseMix = "yellow_river_b";
		else
			baseMix = "yellow_river_c";
		if (floodedLand != 1)
			rmTerrainInitialize("Yellow_river\grass2_yellow_riv", 0);
		rmSetMapType("yellowRiver");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "yellow_river_wet_skirmish";
		riverName = "Yellow River Dry";
		oceanName = "Yellow River Wet Sans Fog";
		pondName = "Yellow River Wet Sans Fog"; 
		cliffName = "Yellow River";
		forestName = "Ginkgo Forest";
//		forestName = "Bamboo Forest";	// fog causing lag/fps drop? ... switched to gingko
		if (whichMix == 1)
			landName = "yellow_river_c";
		else if (whichMix == 2)
			landName = "yellow_river_a";
		else
			landName = "yellow_river_b";
//		treeName = "ypTreeBamboo";
		treeName = "ypTreeGinkgo";
		startingCritterName = "ypMarcoPoloSheep";
		critterOneName = "ypMarcoPoloSheep";
		critterTwoName = "ypIbex";
		livestockName = "ypGoat";
		fishName = "ypFishCatfish";
		whaleName = "MinkeWhale";
		toiletPaper = "water";
		mineralz = "MineGold";	
		if (rmRandFloat(0,1) <= 0.01)
		{
			bombActivator = 1;
			petName1 = "ypSPCHuang";	
		}
		else if (rmRandFloat(0,1) <= 0.20)
			petName1 = "ypPetPanda";	
		else
			petName1 = "ypPetKomodoDragon";	
		propz = "ypSPCSaltpeterSite";	
	}
	
	else if(dekkanMap == 1)			// dekkan
	{
		rmEchoInfo("dekkan terrain");
		asianMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "deccan_grassy_dirt_a_noprops";
		else if (whichMix == 2)
			baseMix = "deccan_grass_b";
		else
			baseMix = "deccan_dirt_a";
		if (floodedLand != 1)
			rmTerrainInitialize("Deccan\ground_grass2_deccan", 0);
		rmSetMapType("deccan");
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "deccan_skirmish";
		riverName = "Deccan Plateau River";
//		if (rmRandFloat(0,1) <= 0.10)
//			oceanName = "Deccan Light";
//		else
			oceanName = "Yellow River Wet Sans Fog";
		pondName = "Deccan light"; 
		cliffName = "Deccan Plateau";
		forestName = "Deccan Forest";
		if (whichMix == 1)
			landName = "deccan_dirt_a";
		else if (whichMix == 2)
			landName = "deccan_grassy_Dirt_a";
		else
			landName = "deccan_grass_b";
		treeName = "ypTreeDeccan";
		startingCritterName = "ypNilgai";
		critterOneName = "ypNilgai";
		critterTwoName = "ypSerow";
		if (rmRandFloat(0,1) <= 0.50)
			livestockName = "ypGoatFat";
		else
			livestockName = "ypWaterBuffalo";
		fishName = "ypFishMolaMola";
		whaleName = "MinkeWhale";
		toiletPaper = "water";
		mineralz = "MineGold";	
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "ypSPCEmperorBahadarSharZafar";	
		else if (rmRandFloat(0,1) <= 0.50)
			petName1 = "ypPetWhiteTiger";	
		else
			petName1 = "ypPetTiger";	
		propz = "ypSMSaltpeterElephant";	

	    if (rmRandFloat(0,1) <= 0.69 && everyoneGetsAWagon == 981)
		{
		    // Add Outlaws and Mercs
	    	rmDisableDefaultMercs(true);
			rmDisableCivTypeMercRestriction(true);
		    rmEnableOutlaw("ypDacoit");
		    rmEnableOutlaw("ypThuggee");
		    rmEnableOutlaw("deSaloonOutlawArsonist");

			for(n = 0; < mercCount)
			{
				if (rmRandInt(1,6) <= 1 && manchuMerc != 1)
				{
				    rmEnableMerc("MercManchu", -1);
					manchuMerc = 1;
				}
				else if (rmRandInt(1,5) <= 1 && ninjaMerc != 1)
				{
				    rmEnableMerc("MercNinja", -1);
					ninjaMerc = 1;
				}
				else if (rmRandInt(1,4) <= 1 && samMerc != 1)
				{
				    rmEnableMerc("MercRonin", -1);
					samMerc = 1;
				}
				else if (rmRandInt(1,3) <= 1 && yojimboMerc != 1)
				{
				    rmEnableMerc("ypMercYojimbo", -1);
					yojimboMerc = 1;
				}
				else if (rmRandInt(1,2) <= 1 && jatMerc != 1)
				{
				    rmEnableMerc("ypMercJatLancer", -1);
					jatMerc = 1;
				}
				else if (ironMerc != 1)
				{
				    rmEnableMerc("ypMercIronTroop", -1);
					ironMerc = 1;
				}
				else
				{
					mercCount++;	// ensures 3 are always chosen
				}
			}
			asianMerc = 1;
		}
	}

	else if(himalMap == 1)			// himalayas
	{
		rmEchoInfo("himal terrain");
		asianMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "himalayas_a";
		else if (whichMix == 2)
			baseMix = "himalayas_b";
		else
			baseMix = "himalayas_c";
		if (floodedLand != 1)
			rmTerrainInitialize("himalayas\ground_dirt2_himal", 0);
		rmSetMapType("silkRoad3");
		silkRoadMap = 1;
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "HimalayasUpper_skirmish";
		riverName = "Himalayas Lake";
		oceanName = "Rockies Lake Ice";
		pondName = "Himalayas Lake";
		cliffName = "himalayas";
		forestName = "Himalayas Forest";
		if (whichMix == 1)
			landName = "himalayas_a";
		else if (whichMix == 2)
			landName = "himalayas_b";
		else
			landName = "himalayas_c";
		treeName = "ypTreeHimalayas";
		startingCritterName = "ypIbex";
		critterOneName = "ypIbex";
		critterTwoName = "ypSerow";
		livestockName = "ypYak";
		fishName = "ypFishTuna";
		whaleName = "MinkeWhale";
		toiletPaper = "water";
		mineralz = "MineGold";	
		petName1 = "ypPetTibetanMacaque";	
		propz = "GroundPropsYukon";	

	    if (rmRandFloat(0,1) <= 0.69 && everyoneGetsAWagon == 981)
		{
		    // Add Outlaws and Mercs
	    	rmDisableDefaultMercs(true);
			rmDisableCivTypeMercRestriction(true);
		    rmEnableOutlaw("ypDacoit");
		    rmEnableOutlaw("ypThuggee");
		    rmEnableOutlaw("deSaloonOutlawArsonist");

			for(n = 0; < mercCount)
			{
				if (rmRandInt(1,6) <= 1 && manchuMerc != 1)
				{
				    rmEnableMerc("MercManchu", -1);
					manchuMerc = 1;
				}
				else if (rmRandInt(1,5) <= 1 && ninjaMerc != 1)
				{
				    rmEnableMerc("MercNinja", -1);
					ninjaMerc = 1;
				}
				else if (rmRandInt(1,4) <= 1 && samMerc != 1)
				{
				    rmEnableMerc("MercRonin", -1);
					samMerc = 1;
				}
				else if (rmRandInt(1,3) <= 1 && yojimboMerc != 1)
				{
				    rmEnableMerc("ypMercYojimbo", -1);
					yojimboMerc = 1;
				}
				else if (rmRandInt(1,2) <= 1 && jatMerc != 1)
				{
				    rmEnableMerc("ypMercJatLancer", -1);
					jatMerc = 1;
				}
				else if (ironMerc != 1)
				{
				    rmEnableMerc("ypMercIronTroop", -1);
					ironMerc = 1;
				}
				else
				{
					mercCount++;	// ensures 3 are always chosen
				}
			}
			asianMerc = 1;
		}
	}

	else if(borneoMap == 1)			// borneo
	{
		rmEchoInfo("borneo terrain");
		indonesiaMap = 1;
		if (rmRandFloat(0,1) <= 0.50)
			asianMap = 1;
		else
			oceaniaMap = 1;
		waterNuggz = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "borneo_grass_a";
		else if (whichMix == 2)
			baseMix = "borneo_grass_b";
		else
			baseMix = "borneo_sand_a";
		if (floodedLand != 1)
			rmTerrainInitialize("borneo\ground_sand3_borneo", 0);
		if (oceaniaMap == 1)
			rmSetMapType("newguinea");
		else
		{
			rmSetMapType("borneo");
			if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "borneo_skirmish";
		riverName = "Indochina Water";
		oceanName = "Indochina Water";
		pondName = "Indochina Water"; 
		cliffName = "africa rainforest grass";
		forestName = "Borneo Palm Forest";
		if (whichMix == 1)
			landName = "borneo_sand_a";
		else if (whichMix == 2)
			landName = "borneo_grass_a";
		else
			landName = "borneo_grass_b";
		treeName = "ypTreeBorneo";
		startingCritterName = "ypSerow";
		critterOneName = "ypSerow";
		critterTwoName = "ypWildElephant";
		livestockName = "ypYak";
		fishName = "ypFishTuna";
		whaleName = "MinkeWhale";
		if (oceaniaMap == 1)
			toiletPaper = "dirt";
		else
			toiletPaper = "water";
		mineralz = "zpJadeMine";	
		if (oceaniaMap == 1)
			petName1 = "zpGrdCannibal";	
		else
			petName1 = "ypPetOrangutan";	
		propz = "ypSMSufiGuy";	
		if (oceaniaMap == 1 && rmRandFloat(0,1) <= 0.10 && rmGetIsKOTH() == false)
			volcanoMap = 1;
		volcCliffLow = "ZP Melanesia Medium";
		volcCliffMid = "ZP Melanesia High 2";
		volcCliffHigh = "ZP Hawaii High";
    	volcTerrainLow = "lava\volcano_grass";
	}

	else if(japanMap == 1)			// japan
	{
		rmEchoInfo("japan terrain");
		asianMap = 1;
		honshuMap = 1;
		waterNuggz = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "coastal_japan_b";
		else if (whichMix == 2)
			baseMix = "coastal_japan_a";
		else
			baseMix = "coastal_japan_c";
		if (floodedLand != 1)
			rmTerrainInitialize("coastal_japan\ground_grass2_co_japan", 0);
		rmSetMapType("Japan");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "honshu_skirmish";
		riverName = "Parallel Rivers Sans Cliff";
		oceanName = "Coastal Japan";
		pondName = "Coastal Japan";
		if (floodedLand == 1)
			pondName = "Parallel Rivers Sans Cliff";
		cliffName = "Coastal Japan";
		forestName = "Coastal Japan Forest";
		if (whichMix == 1)
			landName = "coastal_japan_c";
		else if (whichMix == 2)
			landName = "coastal_japan_b";
		else
			landName = "coastal_japan_a";
		if (rmRandFloat(0,1) <= 0.50)
			treeName = "ypTreeJapaneseMaple";
		else
			treeName = "ypTreeJapanesePine";
		critterOneName = "ypGiantSalamander";
		critterTwoName = "ypSerow";
		startingCritterName = "ypSerow";
		livestockName = "ypWaterBuffalo";
		fishName = "ypSquid";
		whaleName = "MinkeWhale";
		toiletPaper = "water";
		mineralz = "MineGold";	
		petName1 = "ypPetSnowMonkey";	
		propz = "ypPropsBlossomFall";	
	}

	else if(andesMap == 1)			// andes
	{
		saMap = 1;
		rmEchoInfo("andes terrain");
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "andes_grass_a";
		else if (whichMix == 2)
			baseMix = "andes_dirt_a";
		else
			baseMix = "andes_grass_b";
		if (floodedLand != 1)
			rmTerrainInitialize("andes\ground10_and", 0);
		rmSetMapType("andes");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "Andes_Skirmish";
		riverName = "Andes River";
		oceanName = "africa east lake";
		pondName = "africa east lake"; 
		cliffName = "andes";
		forestName = "andes forest";
		if (whichMix == 1)
			landName = "grandcanyon_frstflr";
		else if (whichMix == 2)
			landName = "andes_grass_a";
		else
			landName = "grandcanyon_frstflr";
		treeName = "treePuya";
		startingCritterName = "guanaco";
		critterOneName = "guanaco";
		critterTwoName = "rhea";
		livestockName = "llama";
		fishName = "fishTarpon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail";
		mineralz = "MineGold";	
		if (rmRandFloat(0,1) <= 0.05)
		{
			petName1 = "DEExplorerSheep";	
			heroSheep = 1;	
		}
		else
			petName1 = "WarDog";	
		propz = "SPCIncaOutpost";	
	}

	else if(araucMap == 1)			// araucania
	{
		rmEchoInfo("araucania terrain");
		saMap = 1;
		andesMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "araucania_north_grass_a";
		else if (whichMix == 2)
			baseMix = "araucania_north_grass_c";
		else
			baseMix = "araucania_north_dirt_a";
		if (floodedLand != 1)
			rmTerrainInitialize("andes\ground10_and", 0);
		rmSetMapType("andes");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "Araucania_NorthGrass_Skirmish";
		riverName = "Araucania River";
		oceanName = "Araucania North Coast";
		pondName = "Araucania River"; 
		cliffName = "Araucania North Coast";
		forestName = "North Araucania Forest";
		if (whichMix == 1)
			landName = "araucania_north_dirt_a";
		else if (whichMix == 2)
			landName = "araucania_north_grass_a";
		else
			landName = "araucania_north_grass_c";
		treeName = "TreeAraucania";
		critterOneName = "guanaco";
		critterTwoName = "capybara";
		startingCritterName = "capybara";
		livestockName = "llama";
		fishName = "fishTarpon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail";
		mineralz = "zpQuarzmine";	
		if (rmRandFloat(0,1) <= 0.05)
		{
			petName1 = "ExplorerDog";	
			heroDog = 1;
		}
		else
			petName1 = "deIncaDog";	
		propz = "NativeHouseInca";	
	}

	else if(bayouMap == 1)		// bayou
	{
		rmEchoInfo("bayou terrain");
		saMap = 1;
		amazonMap = 1;
		if (rmRandFloat(0,1) <= 0.05)
			treasureIsle = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "bayou_forest";
		else
			baseMix = "bayou_grass";
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		rmSetMapType("bayou");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("tropical");
		rmSetMapType("land");
	   	shineAlight = "Bayou_Skirmish";
		riverName = "Araucania River";			// Bayou_Dry
		oceanName = "Araucania North Coast";	// Bayou SPC
		pondName = "bayou skirmish2";
		if (floodedLand == 1)
			pondName = "Bayou3";
		cliffName = "Bayou";
		forestName = "Bayou Swamp Forest";
		landName = "bayou_grass_skirmish";		// bayou_forest_02
		treeName = "TreeBayou";
		critterOneName = "turkey";
		critterTwoName = "deer";
		startingCritterName = "deer";
		livestockName = "sheep";
		fishName = "fishMahi";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "deShipRuins";
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "SPCCherokeeChief";	
		else if (rmRandFloat(0,1) <= 0.50)
			petName1 = "xpWarrior";	
		else
			petName1 = "NatMedicineMan";	
		propz = "SPCCherokeeWarhut";	
	}

	else if(mongolMap == 1)			// mongolia
	{
		rmEchoInfo("mongolia terrain");
		yellowRiverMap = 1;
		asianMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "mongolia_grass_a";
		else if (whichMix == 2)
			baseMix = "mongolia_grass_b";
		else
			baseMix = "mongolia_grass";
		if (floodedLand != 1)
			rmTerrainInitialize("Mongolia\ground_grass1_mongol", 0);
		rmSetMapType("mongolia");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "yellow_river_wet_skirmish";
		riverName = "Manchuria Inland";
		oceanName = "Manchuria Coast";
		pondName = "Yellow River Wet Sans Fog"; 
		cliffName = "Manchuria Grass";
		forestName = "Mongolian Fir Forest";
		if (whichMix == 1)
			landName = "mongolia_grass";
		else if (whichMix == 2)
			landName = "mongolia_grass_a";
		else
			landName = "mongolia_grass_b";
		treeName = "ypTreeMongolia";
		critterOneName = "ypSaiga";
		critterTwoName = "ypMuskdeer";
		startingCritterName = "ypMuskdeer";
		livestockName = "ypYak";
		fishName = "ypFishCatfish";
		whaleName = "MinkeWhale";
		toiletPaper = "water";
		mineralz = "MineGold";	
		if (rmRandFloat(0,1) <= 0.01)
		{
			bombActivator = 1;
			petName1 = "ypSPCHuang";	
		}
		else if (rmRandFloat(0,1) <= 0.10)
			petName1 = "Horse";	
		else
			petName1 = "ypMongolScout";	
		propz = "ypSMShaolinAccessory";	
	}

	else if(nwtMap == 1)	// NWT
	{
		rmEchoInfo("northwest territory terrain");
		californiaMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "nwt_dirt";
		else if (whichMix == 2)
			baseMix = "nwt_grass2";
		else
			baseMix = "nwt_grass_dirt";
		if (floodedLand != 1)
			rmTerrainInitialize("nwterritory\ground_grass1a_nwt", 0);
		rmSetMapType("california");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "NorthwestTerritory_Skirmish";
		riverName = "Northwest Territory Water";
		oceanName = "Northwest Territory Water";
		pondName = "Northwest Territory Water";
		cliffName = "Araucania North";
		forestName = "NW Territory Forest";
		if (whichMix == 1)
			landName = "nwt_grass_dirt";
		else if (whichMix == 2)
			landName = "nwt_grass_dirt";
		else
			landName = "nwt_dirt";
		treeName = "TreeNorthwestTerritory";
		startingCritterName = "elk";
		critterOneName = "elk";
		critterTwoName = "moose";
		livestockName = "sheep";
		fishName = "fishSalmon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "deMineCoalBuildable";
		if (rmRandFloat(0,1) <= 0.01)
			petName1 = "SPCXPChiefTwoMoon";	
		else
			petName1 = "deUnknownDrummer";	
		propz = "NativeHouseNootka";	
	}

	else if(euMap == 1)		// europe
	{
		rmEchoInfo("Europe terrain");
		// choose map region first for europe
		if (rmRandInt(0,8) <= 1)
		{
			rmSetMapType("historicalMaps");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,7) <= 1)
		{
			waterNuggz = 1;
			mediSeaEU = 1;
			rmSetMapType("mediSea");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,6) <= 1)
		{
			centralEU = 1;
			rmSetMapType("centralEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,5) <= 1)
		{
			northeastEU = 1;
			rmSetMapType("northeastEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,4) <= 1)
		{
			northEU = 1;
			rmSetMapType("northEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,3) <= 1)
		{
			waterNuggz = 1;
			mediEU = 1;
			rmSetMapType("mediEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,2) <= 1)
		{
			northwestEU = 1;
			rmSetMapType("westEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else if (rmRandInt(0,1) <= 1)
		{
			westEU = 1;
			rmSetMapType("westEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else
		{
			eastEU = 1;
			rmSetMapType("eastEurope");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		rmSetMapType("euroLandTradeRoute");
		rmSetMapType("land");

//		centralEU = 0;		// for testing
//		eastEU = 0;			// for testing
//		northeastEU = 0;	// for testing
//		westEU = 1;			// for testing
//		northwestEU = 0;	// for testing
//		mediEU = 0;			// for testing
//		mediSeaEU = 0;		// for testing
//		northEU = 0;		// for testing

		// now choose terrain for region
		if (rmRandFloat(0,1) <= 0.001)
		{
			baseMix = "unknown funky";
			forestName = "Italian Forest";
			treeName = "deTreeCypress";
			riverName = "Italian River";
			oceanName = "Danish Coast";
			pondName = "Italian Pond";
			cliffName = "Italian Cliff";
			startingCritterName = "zpGoose";
			shineAlight = "rm_afri_congoBasin";
		}
		else
		{
			if (centralEU == 1)		// saxony
			{
				if (whichMix == 1)
				{
					baseMix = "italy_grass_lush";
					landName = "italy_grass_medium";
				}
				else if (whichMix == 2)
				{
					baseMix = "italy_grass_medium";
					landName = "italy_grass_dirt";
				}
				else
				{
					baseMix = "italy_grass_dirt";
					landName = "italy_grass_medium";
				}
				forestName = "New England Forest";
				treeName = "TreeGreatLakes";
				riverName = "Italian River";
				oceanName = "Italian Coast";
				pondName = "Italian Pond";
				cliffName = "Italian Cliff";
				startingCritterName = "zpGoose";
				shineAlight = "carolina_Skirmish";
			}
			else if (northEU == 1)	// danish strait
			{
				if (whichMix == 1)
				{
					baseMix = "danish_grass1";
					landName = "danish_grass2";
				}
				else if (whichMix == 2)
				{
					baseMix = "danish_grass2";
					landName = "danish_grass1";
				}
				else
				{
					baseMix = "danish_grass3";
					landName = "danish_grass2";
				}
				forestName = "Rockies Forest";
				treeName = "TreeGreatLakes";
				riverName = "Danish Coast";
				oceanName = "Danish Coast";
				pondName = "Danish Shallow";
				cliffName = "Italian Cliff";
				startingCritterName = "deer";
				shineAlight = "cascade_range_skirmish";		// Rockie_Skirmish
			}
			else if (northeastEU == 1)	// lithuania
			{
				if (whichMix == 1)
				{
					baseMix = "italy_north_grass";
					landName = "italy_north_dirt";
				}
				else
				{
					baseMix = "italy_north_dirt";
					landName = "italy_north_grass";
				}
				forestName = "z39 Russian Forest";
				treeName = "TreeNorthwestTerritory";
				riverName = "Lithuania Lake";
				oceanName = "Lithuania Lake";
				pondName = "Lithuania Lake";
				cliffName = "Italian Cliff";
				startingCritterName = "zpGoose";
				shineAlight = "3x12a2_lakotavillage";
			}
			else if (eastEU == 1)	// anatolia
			{
				if (whichMix == 1)
				{
					baseMix = "italy_dirt";
					landName = "italy_cliff_top_dry_grass";
				}
				else if (whichMix == 2)
				{
					baseMix = "italy_grass_medium_dry";
					landName = "italy_grass_dry";
				}
				else
				{
					baseMix = "italy_grass_dry";
					landName = "italy_grass_medium_dry";
				}
				forestName = "Italian Forest";
				treeName = "deTreeCypress";
				riverName = "Italian River";
				oceanName = "Italian Coast";
				pondName = "Italian Pond";
				cliffName = "Italian Cliff";
				startingCritterName = "deer";
				shineAlight = "Honshu_Skirmish";
			}
			else if (westEU == 1)	// france
			{
				if (whichMix == 1)
				{
					baseMix = "nwt_grass1";
					landName = "nwt_grass2";
				}
				else if (whichMix == 2)
				{
					baseMix = "nwt_grass2";
					landName = "nwt_grass_dirt";
				}
				else
				{
					baseMix = "nwt_grass_dirt";
					landName = "nwt_grass1";
				}
				forestName = "Great Plains Forest";
				treeName = "TreeGreatLakes";
				riverName = "Italian River";
				oceanName = "Italian Coast";
				pondName = "Italian Pond";
				cliffName = "Northwest Territory";
				startingCritterName = "zpGoose";
				shineAlight = "Honshu_Skirmish";
			}
			else if (northwestEU == 1)		// british isles
			{
				if (whichMix == 1)
				{
					baseMix = "italy_cliff_top_grass";
					landName = "italy_grass";
				}
				else if (whichMix == 2)
				{
					baseMix = "italy_cliff_top";
					landName = "italy_grass";
				}
				else
				{
					baseMix = "italy_cliff_bottom";
					landName = "italy_grass";
				}
				forestName = "New England Forest";
				treeName = "TreeGreatLakes";
				riverName = "Baltic Water";
				oceanName = "Baltic Sea";
				pondName = "Baltic Water";
				cliffName = "Irish Coast";
				startingCritterName = "zpGoose";
				shineAlight = "carolina_Skirmish";
			}
			else if (mediSeaEU == 1)	// mediSea
			{
				if (whichMix == 1)
				{
					baseMix = "Africa Desert Grass";
					landName = "Africa Desert Grass Medium";
				}
				else
				{
					baseMix = "Africa Desert Grass Medium";
					landName = "Africa Desert Grass";
				}
				forestName = "Af Atlas Forest";
				treeName = "deTreeCypress";
				riverName = "Africa Desert Lake Lush";
				oceanName = "Africa Desert Beach";
				pondName = "Africa Desert Hole";
				cliffName = "Africa Desert";
				startingCritterName = "deer";
				shineAlight = "punjab_Skirmish";
			}
			else	// medi - Italy and historical map
			{
				if (whichMix == 1)
				{
					baseMix = "italy_grass_lush";
					landName = "italy_grass_medium";
				}
				else if (whichMix == 2)
				{
					baseMix = "italy_grass_medium";
					landName = "italy_grass_dirt";
				}
				else
				{
					baseMix = "italy_grass_dirt";
					landName = "italy_grass_medium";
				}
				forestName = "Italian Forest";
				treeName = "deTreeCypress";
				riverName = "Italian River";
				oceanName = "Italian Coast";
				pondName = "Italian Pond";
				cliffName = "Italian Cliff";
				startingCritterName = "zpGoose";
				shineAlight = "Honshu_Skirmish";
				if (mediEU != 1)
					westEU = 1;
			}
		}
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		critterOneName = "deer";
		critterTwoName = "ypIbex";
/*		if (rmRandFloat(0,1) <= 0.333)
			livestockName = "zpDomesticPig";
		else*/ if (rmRandFloat(0,1) <= 0.50)
			livestockName = "sheep";
		else
			livestockName = "cow";
		fishName = "FishSardine";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "zpValuableSource";	
		petName1 = "deNatRoyalHuntsman";	
		propz = "PropSwan";	

		// set-up tech for outlaws and native skins
    	rmCreateTrigger("setupthemap");
    	rmSwitchToTrigger(rmTriggerID("setupthemap"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);

    	for (p = 0; <= cNumberNonGaiaPlayers)
    	{
    	    rmAddTriggerEffect("Set Tech Status");
    	    rmSetTriggerEffectParamInt("PlayerID", p, false);
    	    rmSetTriggerEffectParamInt("TechID", rmGetTechID("deEUMapSaxony"), false);
    	    rmSetTriggerEffectParamInt("Status", 2, false);
    	}

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
   		rmDisableCivTypeMercRestriction(true);

		for(n = 0; < outlawCount) // picks 2 outlaws
		{
			rmEchoInfo("choosing outlaws"+n);
			if (rmRandInt(1,5) == 1 && crabatOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonCrabat");
				crabatOutlaw = 1;
				rmEchoInfo("outlaw is crabat");
			}
			else if (rmRandInt(1,4) == 1 && hajdukOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonHajduk");
				hajdukOutlaw = 1;
				rmEchoInfo("outlaw is hajduk");
			}
			else if (rmRandInt(1,3) == 1 && highwayOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonHighwaymanRider");
				highwayOutlaw = 1;
				rmEchoInfo("outlaw is highwayman");
			}
			else if (rmRandInt(1,2) == 1 && inquisitorOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonInquisitor");
				inquisitorOutlaw = 1;
				rmEchoInfo("outlaw is inquisitor");
			}
			else if (cossackOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonOutlawCossackRider");
				cossackOutlaw = 1;
				rmEchoInfo("outlaw is cossack");
			}
			else
			{
				outlawCount++;	// ensures 2 are always chosen
			}
		}

		if (everyoneGetsAWagon != 981)
		{
			for(n = 0; < mercCount)
			{
				rmEchoInfo("choosing mercs"+n);
				if (rmRandInt(1,20) <= 4 && mercBohemianKnight != 1)
				{
   			        rmEnableMerc("zpMercBohemianKnight", -1);
					mercBohemianKnight = 1;
					rmEchoInfo("merc is bohemian knight");
				}
				else if (rmRandInt(1,19) <= 4 && mercHussiteWagon != 1)
				{
   			        rmEnableMerc("zpMercHussiteWagon", -1);
					mercHussiteWagon = 1;
					rmEchoInfo("merc is hussite wagon");
				}
				else if (rmRandInt(1,18) <= 1 && mercSwissPike != 1)
				{
   			        rmEnableMerc("MercSwissPikeman", -1);
					mercSwissPike = 1;
					rmEchoInfo("merc is swiss pike");
				}
				else if (rmRandInt(1,17) <= 1 && mercHacka != 1)
				{
   			        rmEnableMerc("MercHackapell", -1);
					mercHacka = 1;
					rmEchoInfo("merc is hackapell");
				}
				else if (rmRandInt(1,16) <= 1 && mercJaeg != 1)
				{
   			        rmEnableMerc("MercJaeger", -1);
					mercJaeg = 1;
					rmEchoInfo("merc is jaeger");
				}
				else if (rmRandInt(1,15) <= 1 && mercBombard != 1)
				{
   			        rmEnableMerc("MercGreatCannon", -1);
					mercBombard = 1;
					rmEchoInfo("merc is lil bombard");
				}
				else if (rmRandInt(1,14) <= 1 && mercGiantGren != 1)
				{
   			        rmEnableMerc("deMercGrenadier", -1);
					mercGiantGren = 1;
					rmEchoInfo("merc is giant gren");
				}
				else if (rmRandInt(1,13) <= 1 && mercPanda != 1)
				{
   			        rmEnableMerc("deMercPandour", -1);
					mercPanda = 1;
					rmEchoInfo("merc is pandour");
				}
				else if (rmRandInt(1,12) <= 1 && mercRoyalHorse != 1)
				{
   			        rmEnableMerc("deMercRoyalHorseman", -1);
					mercRoyalHorse = 1;
					rmEchoInfo("merc is royal horseman");
				}
				else if (rmRandInt(1,11) <= 1 && mercPistoleer != 1)
				{
   			        rmEnableMerc("deMercPistoleer", -1);
					mercPistoleer = 1;
					rmEchoInfo("merc is pistoleer");
				}
				else if (rmRandInt(1,10) <= 1 && mercBrigadier != 1)
				{
   			        rmEnableMerc("deMercBrigadier", -1);
					mercBrigadier = 1;
					rmEchoInfo("merc is irish");
				}
				else if (rmRandInt(1,9) <= 1 && mercMountedRifle != 1)
				{
   			        rmEnableMerc("deMercMountedRifleman", -1);
					mercMountedRifle = 1;
					rmEchoInfo("merc is mounted rifleman");
				}
				else if (rmRandInt(1,8) <= 1 && mercBozzer != 1)
				{
   			        rmEnableMerc("deMercBosniak", -1);
					mercBozzer = 1;
					rmEchoInfo("merc is bosniak");
				}
				else if (rmRandInt(1,7) <= 1 && mercBRider != 1)
				{
   			        rmEnableMerc("MercBlackRider", -1);
					mercBRider = 1;
					rmEchoInfo("merc is black rider");
				}
				else if (rmRandInt(1,6) <= 1 && mercElmetto != 1)
				{
   			        rmEnableMerc("MercElmeti", -1);
					mercElmetto = 1;
					rmEchoInfo("merc is elmetto");
				}
				else if (rmRandInt(1,5) <= 1 && mercFusileer != 1)
				{
   			        rmEnableMerc("MercFusilier", -1);
					mercFusileer = 1;
					rmEchoInfo("merc is fusilier");
				}
				else if (rmRandInt(1,4) <= 1 && mercHighland != 1)
				{
   			        rmEnableMerc("MercHighlander", -1);
					mercHighland = 1;
					rmEchoInfo("merc is highlander");
				}
				else if (rmRandInt(1,3) <= 1 && mercHarq != 1)
				{
   			        rmEnableMerc("deMercHarquebusier", -1);
					mercHarq = 1;
					rmEchoInfo("merc is harquebusier");
				}
				else if (rmRandInt(1,2) <= 1 && mercLandshark != 1)
				{
   			        rmEnableMerc("MercLandsknecht", -1);
					mercLandshark = 1;
					rmEchoInfo("merc is landshark");
				}
				else if (mercStrad != 1)
				{
   			        rmEnableMerc("MercStradiot", -1);
					mercStrad = 1;
					rmEchoInfo("merc is stradiot");
				}
				else
				{
					mercCount++;	// ensures 3 are always chosen
				}
			}
		}
		europeanMerc = 1;
	}

	else if(icelandMap == 1)		// iceland
	{
		rmEchoInfo("Iceland terrain");
		snowMap = 1;
		// choose map region first for europe
		if (rmRandFloat(0,1) <= 0.10)
		{
			rmSetMapType("historicalMaps");
			if (rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
		else
		{
			icelandEU = 1;
			rmSetMapType("Iceland");
			if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			{
				rogueMap = 1;
				rmSetMapType("piratehistoricalmap");
			}
		}
//		icelandEU = 0;		// for testing
		rmSetMapType("euroLandTradeRoute");
		rmSetMapType("land");
		if (whichMix == 1)
		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				baseMix = "araucania_snow_b";
				landName = "italy_snow";
			}
			else
			{
				baseMix = "italy_snow";
				landName = "araucania_snow_b";
			}
			forestName = "Great Lakes Forest Snow";
		}
		else if (whichMix == 2)
		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				baseMix = "araucania_snow_a";
				landName = "italy_snow_dirt";
			}
			else
			{
				baseMix = "italy_snow_dirt";
				landName = "araucania_snow_a";
			}
			forestName = "Patagonia Snow Forest";
		}
		else
		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				baseMix = "araucania_snow_c";
				landName = "italy_snow_cliff";
			}
			else
			{
				baseMix = "italy_snow_cliff";
				landName = "araucania_snow_c";
			}
			forestName = "Patagonia Snow Forest";
		}
		treeName = "TreeGreatLakesSnow";
		riverName = "ZP Iceland Lake";
		oceanName = "ZP Iceland Lake";
		pondName = "ZP Iceland Lake";
		cliffName = "ZP Iceland Low";
		startingCritterName = "caribou";
		shineAlight = "spcjc4aflashback";
		if (floodedLand != 1)
			rmTerrainInitialize("pampas\ground5_pam", 0);
		critterOneName = "caribou";
		critterTwoName = "caribou";
		livestockName = "sheep";
		fishName = "FishSalmon";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt";
		mineralz = "zpSulphurMine";
		petName1 = "zpNatSettlerHansa";
		propz = "PropBlizzard";
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
			volcanoMap = 1;
    	volcCliffLow = "ZP Iceland Low";
    	volcCliffMid = "ZP Iceland Medium";
    	volcCliffHigh = "ZP Iceland High";
    	volcTerrainLow = "lava\volcano_snow";

		// set-up tech for outlaws and native skins
    	rmCreateTrigger("setupthemap");
    	rmSwitchToTrigger(rmTriggerID("setupthemap"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);

    	for (p = 0; <= cNumberNonGaiaPlayers)
    	{
    	    rmAddTriggerEffect("Set Tech Status");
    	    rmSetTriggerEffectParamInt("PlayerID", p, false);
    	    rmSetTriggerEffectParamInt("TechID", rmGetTechID("deEUMapDanishStrait"), false);
    	    rmSetTriggerEffectParamInt("Status", 2, false);
    	}

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
   		rmDisableCivTypeMercRestriction(true);

		for(n = 0; < outlawCount) // picks 2 outlaws
		{
			rmEchoInfo("choosing outlaws"+n);
			if (rmRandInt(1,5) == 1 && crabatOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonCrabat");
				crabatOutlaw = 1;
				rmEchoInfo("outlaw is crabat");
			}
			else if (rmRandInt(1,4) == 1 && hajdukOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonHajduk");
				hajdukOutlaw = 1;
				rmEchoInfo("outlaw is hajduk");
			}
			else if (rmRandInt(1,3) == 1 && highwayOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonHighwaymanRider");
				highwayOutlaw = 1;
				rmEchoInfo("outlaw is highwayman");
			}
			else if (rmRandInt(1,2) == 1 && inquisitorOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonInquisitor");
				inquisitorOutlaw = 1;
				rmEchoInfo("outlaw is inquisitor");
			}
			else if (cossackOutlaw != 1)
			{
	    	    rmEnableOutlaw("deSaloonOutlawCossackRider");
				cossackOutlaw = 1;
				rmEchoInfo("outlaw is cossack");
			}
			else
			{
				outlawCount++;	// ensures 2 are always chosen
			}
		}

		if (everyoneGetsAWagon != 981)
		{
			for(n = 0; < mercCount)
			{
				rmEchoInfo("choosing mercs"+n);
				if (rmRandInt(1,20) <= 4 && mercBohemianKnight != 1)
				{
   			        rmEnableMerc("zpMercBohemianKnight", -1);
					mercBohemianKnight = 1;
					rmEchoInfo("merc is bohemian knight");
				}
				else if (rmRandInt(1,19) <= 4 && mercHussiteWagon != 1)
				{
   			        rmEnableMerc("zpMercHussiteWagon", -1);
					mercHussiteWagon = 1;
					rmEchoInfo("merc is hussite wagon");
				}
				else if (rmRandInt(1,18) <= 1 && mercSwissPike != 1)
				{
   			        rmEnableMerc("MercSwissPikeman", -1);
					mercSwissPike = 1;
					rmEchoInfo("merc is swiss pike");
				}
				else if (rmRandInt(1,17) <= 1 && mercHacka != 1)
				{
   			        rmEnableMerc("MercHackapell", -1);
					mercHacka = 1;
					rmEchoInfo("merc is hackapell");
				}
				else if (rmRandInt(1,16) <= 1 && mercJaeg != 1)
				{
   			        rmEnableMerc("MercJaeger", -1);
					mercJaeg = 1;
					rmEchoInfo("merc is jaeger");
				}
				else if (rmRandInt(1,15) <= 1 && mercBombard != 1)
				{
   			        rmEnableMerc("MercGreatCannon", -1);
					mercBombard = 1;
					rmEchoInfo("merc is lil bombard");
				}
				else if (rmRandInt(1,14) <= 1 && mercGiantGren != 1)
				{
   			        rmEnableMerc("deMercGrenadier", -1);
					mercGiantGren = 1;
					rmEchoInfo("merc is giant gren");
				}
				else if (rmRandInt(1,13) <= 1 && mercPanda != 1)
				{
   			        rmEnableMerc("deMercPandour", -1);
					mercPanda = 1;
					rmEchoInfo("merc is pandour");
				}
				else if (rmRandInt(1,12) <= 1 && mercRoyalHorse != 1)
				{
   			        rmEnableMerc("deMercRoyalHorseman", -1);
					mercRoyalHorse = 1;
					rmEchoInfo("merc is royal horseman");
				}
				else if (rmRandInt(1,11) <= 1 && mercPistoleer != 1)
				{
   			        rmEnableMerc("deMercPistoleer", -1);
					mercPistoleer = 1;
					rmEchoInfo("merc is pistoleer");
				}
				else if (rmRandInt(1,10) <= 1 && mercBrigadier != 1)
				{
   			        rmEnableMerc("deMercBrigadier", -1);
					mercBrigadier = 1;
					rmEchoInfo("merc is irish");
				}
				else if (rmRandInt(1,9) <= 1 && mercMountedRifle != 1)
				{
   			        rmEnableMerc("deMercMountedRifleman", -1);
					mercMountedRifle = 1;
					rmEchoInfo("merc is mounted rifleman");
				}
				else if (rmRandInt(1,8) <= 1 && mercBozzer != 1)
				{
   			        rmEnableMerc("deMercBosniak", -1);
					mercBozzer = 1;
					rmEchoInfo("merc is bosniak");
				}
				else if (rmRandInt(1,7) <= 1 && mercBRider != 1)
				{
   			        rmEnableMerc("MercBlackRider", -1);
					mercBRider = 1;
					rmEchoInfo("merc is black rider");
				}
				else if (rmRandInt(1,6) <= 1 && mercElmetto != 1)
				{
   			        rmEnableMerc("MercElmeti", -1);
					mercElmetto = 1;
					rmEchoInfo("merc is elmetto");
				}
				else if (rmRandInt(1,5) <= 1 && mercFusileer != 1)
				{
   			        rmEnableMerc("MercFusilier", -1);
					mercFusileer = 1;
					rmEchoInfo("merc is fusilier");
				}
				else if (rmRandInt(1,4) <= 1 && mercHighland != 1)
				{
   			        rmEnableMerc("MercHighlander", -1);
					mercHighland = 1;
					rmEchoInfo("merc is highlander");
				}
				else if (rmRandInt(1,3) <= 1 && mercHarq != 1)
				{
   			        rmEnableMerc("deMercHarquebusier", -1);
					mercHarq = 1;
					rmEchoInfo("merc is harquebusier");
				}
				else if (rmRandInt(1,2) <= 1 && mercLandshark != 1)
				{
   			        rmEnableMerc("MercLandsknecht", -1);
					mercLandshark = 1;
					rmEchoInfo("merc is landshark");
				}
				else if (mercStrad != 1)
				{
   			        rmEnableMerc("MercStradiot", -1);
					mercStrad = 1;
					rmEchoInfo("merc is stradiot");
				}
				else
				{
					mercCount++;	// ensures 3 are always chosen
				}
			}
		}
		europeanMerc = 1;
	}

	else if(gpMap == 1)		// great plains and great lake
	{
		rmEchoInfo("gp or gl terrain");
		rmSetMapType("greatPlains");
		if (rmRandFloat(0,1) <= 0.10)
			merryXmass = 1;
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("land");
		if (rmRandFloat(0,1) <= 0.001)
		{
			baseMix = "unknown funky";
			landName = "africa desert grass mud blend";
			forestName = "unknown forest funky";
			riverName = "ZP Iceland Lake";
			oceanName = "ZP Iceland Lake";
			pondName = "ZP Iceland Lake";
			cliffName = "ZP Iceland Low";
			treeName = "zpChristmassTree";
			startingCritterName = "caribou";
			critterOneName = "reindeer";
			critterTwoName = "deer";
			shineAlight = "spcjc4aflashback";
			livestockName = "sheep";
			toiletPaper = "snow";
		}
		else if (whichMix == 1)		// winter great lakes
		{
			snowMap = 1;
			baseMix = "greatlakes_snow";
			landName = "italy_snow";
			forestName = "Great Lakes Forest Snow";
			treeName = "TreeGreatLakesSnow";
			riverName = "Yukon River";
			oceanName = "Great Lakes Ice";
			pondName = "great lakes ice3";
			cliffName = "Rocky Mountain2";
			shineAlight = "GreatLakes_Winter_Skirmish";
			livestockName = "sheep";
			toiletPaper = "snow";
			if (merryXmass == 1)
			{
				critterOneName = "reindeer";
				startingCritterName = "reindeer";
				treeName = "zpChristmassTree";
//    			rmDisableDefaultMercs(true);
//				rmDisableCivTypeMercRestriction(true);
				rmEnableMerc("zpChristmasPolearm", -1);
				rmEnableMerc("zpChristmasGrenadier", -1);
				rmEnableMerc("zpChristmasOrganGun", -1);
			}
			else
			{
				critterOneName = "caribou";
				startingCritterName = "muskOx";
				treeName = "treeRockiesSnow";
			}
			critterTwoName = "muskOx";
		}
		else if (whichMix == 2)		// great lakes summer
		{
			baseMix = "greatlakes_grass";
			landName = "italy_grass_medium";
			forestName = "great lakes forest";
			treeName = "TreeGreatLakes";
			riverName = "great lakes2";
			oceanName = "Great Lakes2";
			pondName = "Great Lakes3";
			cliffName = "Italian Cliff";
			critterOneName = "elk";
			critterTwoName = "deer";
			startingCritterName = "moose";
			shineAlight = "GreatLakes_Summer_Skirmish";
			livestockName = "sheep";
			toiletPaper = "dirt";
		}
		else		// great plains
		{
			baseMix = "great plains grass";
			landName = "great plains grass01";
			forestName = "Great Plains Forest";
			treeName = "TreeGreatPlains";
			riverName = "great lakes2";
			oceanName = "Great Lakes2";
			pondName = "great plains pond";
			cliffName = "Great Plains";
			critterOneName = "pronghorn";
			critterTwoName = "bison";
			startingCritterName = "bison";
			shineAlight = "GreatPlains_Skirmish";
			livestockName = "cow";
			toiletPaper = "dirt";
		}
		if (floodedLand != 1)
			rmTerrainInitialize("great_lakes\ground_grass1_gl", 0);
		fishName = "FishBass";
		whaleName = "MinkeWhale";
		mineralz = "deMineCoalBuildable";	
		if (merryXmass == 1)
			petName1 = "zpRudolf";	
		else if (rmRandFloat(0,1) <= 0.01)
			petName1 = "SPCChiefDaughter";
		else if (rmRandFloat(0,1) <= 0.01)
			petName1 = "IGCGreatPlainsChief";
		else
			petName1 = "deSPCUSVolunteer";	
		propz = "zpPropWestern";	
	}

	else if(afrEast == 1)			// african east
	{
		rmEchoInfo("af east terrain");
		africanMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "africa east grass dry";
		else if (whichMix == 2)
			baseMix = "africa east dirt";
		else
			baseMix = "africa east grass";
		if (floodedLand != 1)
			rmTerrainInitialize("Africa\groundCracked_afr", 0);
		if (rmRandFloat(0,1) <= 0.17)
		{
			saharaMap = 1;
			rmSetMapType("sahara");
		}
		else
			rmSetMapType("GreatRift");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "rm_afri_ivorycoast";
		riverName = "Andes River";
		oceanName = "africa east lake";
		pondName = "africa east lake"; 
		cliffName = "Ethiopia Highland";
		forestName = "African Forest";
		if (whichMix == 1)
			landName = "africa east dirt";
		else if (whichMix == 2)
			landName = "africa east grass";
		else
			landName = "africa east grass dry";
		treeName = "TreeAfrica";
		startingCritterName = "deZebra";
		critterOneName = "deZebra";
		critterTwoName = "deGiraffe";
		if (rmRandFloat(0,1) <= 0.10)
		{
			livestockName = "deAutoSangaCattle";
			autoCattle = 1;
		}
		else
			livestockName = "deSangaCattle";
		fishName = "deFishNilePerch";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail_african";
		mineralz = "zpDiamondMine";	
		if (rmRandFloat(0,1) <= 0.05)
			petName1 = "dePetElephant";	
		else
			petName1 = "dePetWarthog";	
		propz = "dePropsRockChurch";	

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
		rmDisableCivTypeMercRestriction(true);
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawAfricanSpearman");
	    else
			rmEnableOutlaw("deOutlawDesertWarrior");
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawKnifeThrower");
		else
		    rmEnableOutlaw("deOutlawDesertRaider");
		if (rmRandInt(0,2) == 1)
		    rmEnableOutlaw("deSaloonOutlawColoRifle");
	    else if (rmRandInt(0,1) == 1)
			rmEnableOutlaw("deOutlawDesertArcher");
	    else
			rmEnableOutlaw("deAllegianceBarbaryMarksman");
		
		for(n = 0; < mercCount)
		{
			if (rmRandInt(1,9) <= 1 && sennarMerc != 1)
			{
				rmEnableMerc("deMercSudaneseRider", -1);
				sennarMerc = 1;
			}
			else if (rmRandInt(1,8) <= 1 && askariMerc != 1)
			{
				rmEnableMerc("deMercAskari", -1);
				askariMerc = 1;
			}
			else if (rmRandInt(1,7) <= 1 && dahomeyMerc != 1)
			{
				rmEnableMerc("deMercAmazon", -1);
				dahomeyMerc = 1;
			}
			else if (rmRandInt(1,6) <= 1 && cannoneerMerc != 1)
			{
				rmEnableMerc("deMercCannoneer", -1);
				cannoneerMerc = 1;
			}
			else if (rmRandInt(1,5) <= 1 && zenataMerc != 1)
			{
				rmEnableMerc("deMercZenata", -1);
				zenataMerc = 1;
			}
			else if (rmRandInt(1,4) <= 1 && kanuriMerc != 1)
			{
				rmEnableMerc("deMercKanuri", -1);
				kanuriMerc = 1;
			}
			else if (rmRandInt(1,3) <= 1 && corsairMerc != 1)
			{
			    rmEnableMerc("MercBarbaryCorsair", -1);
				corsairMerc = 1;
			}
			else if (rmRandInt(1,2) <= 1 && mamaMerc != 1)
			{
			    rmEnableMerc("MercMameluke", -1);
				mamaMerc = 1;
			}
			else if (rmRandFloat(0,1) <= 0.001 && gatCamelMerc != 1)
			{
				rmEnableMerc("deMercGatlingCamel", -1);
				gatCamelMerc = 1;
			}
			else
			{
				mercCount++;	// ensures 3 are always chosen
			}
		}
		africanMerc = 1;
	}

	else if(afrSavanna == 1)			// african savanna
	{
		rmEchoInfo("af savanna terrain");
		africanMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "africa savanna sand";
		else if (whichMix == 2)
			baseMix = "africa savanna dirt";
		else
			baseMix = "africa savanna grass dry";
		if (floodedLand != 1)
			rmTerrainInitialize("AfricaSavanna\ground_rock1_afriSavanna", 0);
		if (rmRandFloat(0,1) <= 0.17)
		{
			saharaMap = 1;
			rmSetMapType("sahara");
		}
		else
		{
			waterNuggz = 1;
			rmSetMapType("Horn");
		}
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "rm_afri_horn";
		riverName = "africa savanna river";
		oceanName = "africa savanna coast";
		pondName = "africa lake victoria lush"; 
		cliffName = "africa savanna";
		if (rmRandFloat(0,1) <= 0.10)
			forestName = "Af Savanna Wateringhole Forest";
		else if (rmRandFloat(0,1) >= 0.90)
			forestName = "Af Savanna Baobab Forest";
		else 
			forestName = "Af Sahel Forest";
		if (whichMix == 1)
			landName = "africa savanna dirt";
		else if (whichMix == 2)
			landName = "africa savanna grass dry";
		else
			landName = "africa savanna grass";
		treeName = "deTreeSenegaliaLaeta";
		critterOneName = "deOstrich";
		critterTwoName = "Gazelle";
		startingCritterName = "Gazelle";
		if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deChonkyCattle";
		else if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deUnknownWoodCattle";
		else if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deUnknownGoldCattle";
		else
			livestockName = "deZebuCattle";
		fishName = "deFishNilePerch";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail_african";
		mineralz = "zpDiamondMine";		
		if (rmRandFloat(0,1) <= 0.05)
			petName1 = "ypPetRhino";	
		else
			petName1 = "dePetLeopard";		
		propz = "dePropsAnimalsCattle";	

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
		rmDisableCivTypeMercRestriction(true);
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawAfricanSpearman");
	    else
			rmEnableOutlaw("deOutlawDesertWarrior");
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawKnifeThrower");
		else
		    rmEnableOutlaw("deOutlawDesertRaider");
		if (rmRandInt(0,2) == 1)
		    rmEnableOutlaw("deSaloonOutlawColoRifle");
	    else if (rmRandInt(0,1) == 1)
			rmEnableOutlaw("deOutlawDesertArcher");
	    else
			rmEnableOutlaw("deAllegianceBarbaryMarksman");
		
		for(n = 0; < mercCount)
		{
			if (rmRandInt(1,9) <= 1 && sennarMerc != 1)
			{
				rmEnableMerc("deMercSudaneseRider", -1);
				sennarMerc = 1;
			}
			else if (rmRandInt(1,8) <= 1 && askariMerc != 1)
			{
				rmEnableMerc("deMercAskari", -1);
				askariMerc = 1;
			}
			else if (rmRandInt(1,7) <= 1 && dahomeyMerc != 1)
			{
				rmEnableMerc("deMercAmazon", -1);
				dahomeyMerc = 1;
			}
			else if (rmRandInt(1,6) <= 1 && cannoneerMerc != 1)
			{
				rmEnableMerc("deMercCannoneer", -1);
				cannoneerMerc = 1;
			}
			else if (rmRandInt(1,5) <= 1 && zenataMerc != 1)
			{
				rmEnableMerc("deMercZenata", -1);
				zenataMerc = 1;
			}
			else if (rmRandInt(1,4) <= 1 && kanuriMerc != 1)
			{
				rmEnableMerc("deMercKanuri", -1);
				kanuriMerc = 1;
			}
			else if (rmRandInt(1,3) <= 1 && corsairMerc != 1)
			{
			    rmEnableMerc("MercBarbaryCorsair", -1);
				corsairMerc = 1;
			}
			else if (rmRandInt(1,2) <= 1 && mamaMerc != 1)
			{
			    rmEnableMerc("MercMameluke", -1);
				mamaMerc = 1;
			}
			else if (rmRandFloat(0,1) <= 0.001 && gatCamelMerc != 1)
			{
				rmEnableMerc("deMercGatlingCamel", -1);
				gatCamelMerc = 1;
			}
			else
			{
				mercCount++;	// ensures 3 are always chosen
			}
		}
		africanMerc = 1;
	}
	
	else if(afrRainforest == 1)			// african rainforest
	{
		rmEchoInfo("af rainforest terrain");
		africanMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "africa rainforest grass medium";
		else if (whichMix == 2)
			baseMix = "africa rainforest grass";
		else
			baseMix = "africa rainforest grass dry";
		if (floodedLand != 1)
			rmTerrainInitialize("AfricaRainforest\ground_grass1_afriRainforest", 0);
		if (rmRandFloat(0,1) <= 0.17)
		{
			saharaMap = 1;
			rmSetMapType("sahara");
		}
		else
			rmSetMapType("PepperCoast");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "rm_afri_pepperCoast";
		riverName = "africa rainforest river muddy";
		oceanName = "africa rainforest coast";
		if (floodedLand != 1)
			pondName = "africa rainforest lagoon"; 
		else
			pondName = "africa rainforest lake"; 
		cliffName = "africa rainforest grass";
		forestName = "Af Niger Delta Tropical Forest";
		if (whichMix == 1)
			landName = "africa rainforest grass dry";
		else if (whichMix == 2)
			landName = "africa rainforest grass medium";
		else
			landName = "africa rainforest grass";
		treeName = "deTreeMangrove";
		startingCritterName = "deGiraffe";
		critterOneName = "deGiraffe";
		critterTwoName = "ypWildElephant";
		if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deChonkyCattle";
		else if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deUnknownGoldCattle";
		else if (rmRandFloat(0,1) <= 0.05)
			livestockName = "deUnknownWoodCattle";
		else
			livestockName = "deSangaCattle";
		fishName = "deFishNilePerch";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail_african";
		mineralz = "zpDiamondMine";	
		if (rmRandFloat(0,1) <= 0.05)
			petName1 = "dePetHippo";	
		else
			petName1 = "deGunnerLevy";
		propz = "dePropGranary";	

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
		rmDisableCivTypeMercRestriction(true);
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawAfricanSpearman");
	    else
			rmEnableOutlaw("deOutlawDesertWarrior");
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawKnifeThrower");
		else
		    rmEnableOutlaw("deOutlawDesertRaider");
		if (rmRandInt(0,2) == 1)
		    rmEnableOutlaw("deSaloonOutlawColoRifle");
	    else if (rmRandInt(0,1) == 1)
			rmEnableOutlaw("deOutlawDesertArcher");
	    else
			rmEnableOutlaw("deAllegianceBarbaryMarksman");
		
		for(n = 0; < mercCount)
		{
			if (rmRandInt(1,9) <= 1 && sennarMerc != 1)
			{
				rmEnableMerc("deMercSudaneseRider", -1);
				sennarMerc = 1;
			}
			else if (rmRandInt(1,8) <= 1 && askariMerc != 1)
			{
				rmEnableMerc("deMercAskari", -1);
				askariMerc = 1;
			}
			else if (rmRandInt(1,7) <= 1 && dahomeyMerc != 1)
			{
				rmEnableMerc("deMercAmazon", -1);
				dahomeyMerc = 1;
			}
			else if (rmRandInt(1,6) <= 1 && cannoneerMerc != 1)
			{
				rmEnableMerc("deMercCannoneer", -1);
				cannoneerMerc = 1;
			}
			else if (rmRandInt(1,5) <= 1 && zenataMerc != 1)
			{
				rmEnableMerc("deMercZenata", -1);
				zenataMerc = 1;
			}
			else if (rmRandInt(1,4) <= 1 && kanuriMerc != 1)
			{
				rmEnableMerc("deMercKanuri", -1);
				kanuriMerc = 1;
			}
			else if (rmRandInt(1,3) <= 1 && corsairMerc != 1)
			{
			    rmEnableMerc("MercBarbaryCorsair", -1);
				corsairMerc = 1;
			}
			else if (rmRandInt(1,2) <= 1 && mamaMerc != 1)
			{
			    rmEnableMerc("MercMameluke", -1);
				mamaMerc = 1;
			}
			else if (rmRandFloat(0,1) <= 0.001 && gatCamelMerc != 1)
			{
				rmEnableMerc("deMercGatlingCamel", -1);
				gatCamelMerc = 1;
			}
			else
			{
				mercCount++;	// ensures 3 are always chosen
			}
		}
		africanMerc = 1;
	}
	
	else if (afrDesert == 1)	// african desert
	{
		rmEchoInfo("af desert terrain");
		africanMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else if (whichMix == 1)
			baseMix = "africa desert sand";
		else if (whichMix == 2)
			baseMix = "africa desert grass";
		else
			baseMix = "africa desert grass dry";
		if (floodedLand != 1)
			rmTerrainInitialize("AfricaDesert\ground_dirt1_afriDesert", 0);
		if (rmRandFloat(0,1) <= 0.17)
		{
			saharaMap = 1;
			rmSetMapType("sahara");
		}
		else
			rmSetMapType("NileRiver");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "rm_afri_nileValley";
		riverName = "africa desert nile";
		oceanName = "africa desert coast";
		pondName = "africa desert lake lush"; 
		cliffName = "africa desert grass";
		forestName = "Af Atlas Forest";
		if (whichMix == 1)
			landName = "africa desert grass";
		else if (whichMix == 2)
			landName = "africa desert grass dry";
		else
			landName = "africa desert sand";
		treeName = "deTreeSaharanCypress";
		startingCritterName = "deOstrich";
		critterOneName = "deOstrich";
		critterTwoName = "Gazelle";
		if (rmRandFloat(0,1) <= 0.10)
		{
			livestockName = "deAutoZebuCattle";
			autoCattle = 1;
		}
		else
			livestockName = "deZebuCattle";
		fishName = "deFishNilePerch";
		whaleName = "MinkeWhale";
		toiletPaper = "dirt_trail_african";
		mineralz = "zpDiamondMine";	
		if (rmRandFloat(0,1) <= 0.10)
			petName1 = "ypPetLion";	
		else
			petName1 = "deBowmanLevy";		
		propz = "dePropTreesAfrica";	

	    // Add Outlaws and Mercs
    	rmDisableDefaultMercs(true);
		rmDisableCivTypeMercRestriction(true);
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawAfricanSpearman");
	    else
			rmEnableOutlaw("deOutlawDesertWarrior");
		if (rmRandInt(0,1) == 1)
		    rmEnableOutlaw("deSaloonOutlawKnifeThrower");
		else
		    rmEnableOutlaw("deOutlawDesertRaider");
		if (rmRandInt(0,2) == 1)
		    rmEnableOutlaw("deSaloonOutlawColoRifle");
	    else if (rmRandInt(0,1) == 1)
			rmEnableOutlaw("deOutlawDesertArcher");
	    else
			rmEnableOutlaw("deAllegianceBarbaryMarksman");
		
		for(n = 0; < mercCount)
		{
			if (rmRandInt(1,9) <= 1 && sennarMerc != 1)
			{
				rmEnableMerc("deMercSudaneseRider", -1);
				sennarMerc = 1;
			}
			else if (rmRandInt(1,8) <= 1 && askariMerc != 1)
			{
				rmEnableMerc("deMercAskari", -1);
				askariMerc = 1;
			}
			else if (rmRandInt(1,7) <= 1 && dahomeyMerc != 1)
			{
				rmEnableMerc("deMercAmazon", -1);
				dahomeyMerc = 1;
			}
			else if (rmRandInt(1,6) <= 1 && cannoneerMerc != 1)
			{
				rmEnableMerc("deMercCannoneer", -1);
				cannoneerMerc = 1;
			}
			else if (rmRandInt(1,5) <= 1 && zenataMerc != 1)
			{
				rmEnableMerc("deMercZenata", -1);
				zenataMerc = 1;
			}
			else if (rmRandInt(1,4) <= 1 && kanuriMerc != 1)
			{
				rmEnableMerc("deMercKanuri", -1);
				kanuriMerc = 1;
			}
			else if (rmRandInt(1,3) <= 1 && corsairMerc != 1)
			{
			    rmEnableMerc("MercBarbaryCorsair", -1);
				corsairMerc = 1;
			}
			else if (rmRandInt(1,2) <= 1 && mamaMerc != 1)
			{
			    rmEnableMerc("MercMameluke", -1);
				mamaMerc = 1;
			}
			else if (rmRandFloat(0,1) <= 0.001 && gatCamelMerc != 1)
			{
				rmEnableMerc("deMercGatlingCamel", -1);
				gatCamelMerc = 1;
			}
			else
			{
				mercCount++;	// ensures 3 are always chosen
			}
		}
		africanMerc = 1;
	}
	
	else if (hawMap == 1)	// hawaii
	{
		rmEchoInfo("hawaii terrain");
		oceaniaMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else
			baseMix = "california_snowground4";
		if (floodedLand != 1)
			rmTerrainInitialize("caribbean\ground6_crb", 0);
		waterNuggz = 1;
		rmSetMapType("hawaii");
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "age304_caribbean";
		riverName = "ZP Hawaii Coast";
		oceanName = "ZP Hawaii Coast";
		pondName = "ZP Hawaii Coast"; 
		cliffName = "Caribbean";
		forestName = "z79 hawaii";
		if (whichMix == 1)
			landName = "caribbean grass";
		else if (whichMix == 2)
			landName = "caribbeanSkirmish";
		else
			landName = "caribbean grass";
		treeName = "TreeAmazon";
		startingCritterName = "zpFeralPig";
		critterOneName = "zpFeralPig";
		critterTwoName = "zpFeralPig";
		livestockName = "sheep";
		fishName = "FishMahi";
		whaleName = "HumpbackWhale";
		toiletPaper = "dirt";
		mineralz = "zpJadeMine";	
		if (rmRandFloat(0,1) <= 0.50)
			petName1 = "zpGrdEscapedPrisoner";		
		else
			petName1 = "zpGuardianClubman";		
		propz = "dePropsAnimalsChicken";	
		if (oceaniaMap == 1 && rmRandFloat(0,1) <= 0.10 && rmGetIsKOTH() == false)
			volcanoMap = 1;
		volcCliffLow = "ZP Hawaii Medium";
		volcCliffMid = "ZP Hawaii High 2";
		volcCliffHigh = "ZP Hawaii High";
    	volcTerrainLow = "lava\volcano_grass";
	}
	
	else 	// australia	// ausMap == 1
	{
		rmEchoInfo("aussie terrain");
		oceaniaMap = 1;
		if (rmRandFloat(0,1) <= 0.001)
			baseMix = "unknown funky";
		else
		{
			if (whichMix == 1)
				baseMix = "california_snowground";
			else if (whichMix == 2)
				baseMix = "california_snowground2";
			else
				baseMix = "california_snowground3";
		}
		if (floodedLand != 1)
			rmTerrainInitialize("caribbean\ground6_crb", 0);
		waterNuggz = 1;
		rmSetMapType("australia");
		if (rmRandFloat(0,1) <= 0.25 && rmGetIsKOTH() == false)
		{
			rogueMap = 1;
			rmSetMapType("piratehistoricalmap");
		}
		rmSetMapType("grass");
		rmSetMapType("land");
		shineAlight = "PaintedDesert_Skirmish";
		riverName = "ZP Pacific Coast";
		oceanName = "ZP Australia Red Lake";
		pondName = "ZP Australia Red Lake"; 
		cliffName = "ZP Uluru";
		forestName = "z86 Australian Bush";
		if (whichMix == 1)
			landName = "california_snowground2";
		else if (whichMix == 2)
			landName = "california_snowground3";
		else
			landName = "california_snowground";
		treeName = "treeMadrone";
		if (rmRandFloat(0,1) <= 0.001)
		{
			critterOneName = "zpCassowary";
			critterTwoName = "zpCassowary";
		}
		else
		{
			if (rmRandFloat(0,1) <= 0.333)
				critterOneName = "zpEmu";
			else if (rmRandFloat(0,1) <= 0.50)
				critterOneName = "zpRedKangaroo";
			else
				critterOneName = "zpRedNeckedWallaby";
			if (rmRandFloat(0,1) <= 0.333)
				critterTwoName = "zpEmu";
			else if (rmRandFloat(0,1) <= 0.50)
				critterTwoName = "zpRedKangaroo";
			else
				critterTwoName = "zpRedNeckedWallaby";
			if (rmRandFloat(0,1) <= 0.333)
				startingCritterName = "zpEmu";
			else if (rmRandFloat(0,1) <= 0.50)
				startingCritterName = "zpRedKangaroo";
			else
				startingCritterName = "zpRedNeckedWallaby";
		}
		livestockName = "sheep";
		fishName = "ypFishTuna";
		whaleName = "zpSaltMineWater";
		toiletPaper = "dirt";
		mineralz = "zpJadeMine";	
		if (rmRandFloat(0,1) <= 0.50)
			petName1 = "zpNatConvictLabourer";		
		else
			petName1 = "zpNatBoomerang";		
		propz = "dePropsAnimalsChicken";	
	}

	if (oceaniaMap == 1)
	{
		rmCreateTrigger("Australian Techs");
	    rmSwitchToTrigger(rmTriggerID("Starting techs"));
	    for(i=0; <= cNumberNonGaiaPlayers)
		{
	    	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	    	rmSetTriggerEffectParamInt("PlayerID",i);
	    	rmSetTriggerEffectParam("TechID","cTechzpMapAustralian"); // Australian Trade unit Designs
	    	rmSetTriggerEffectParamInt("Status",2);
	    	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	    	rmSetTriggerEffectParamInt("PlayerID",i);
	    	rmSetTriggerEffectParam("TechID","cTechzpEnableTradeRouteAustralian"); // Australian Trade Route techs
	    	rmSetTriggerEffectParamInt("Status",2);
	    	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	    	rmSetTriggerEffectParamInt("PlayerID",i);
			if (ausMap == 1)
		    	rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australia Mercenaries
			else
		    	rmSetTriggerEffectParam("TechID","cTechzpOceaniaMercenaries"); // Oceania Mercenaries
	    	rmSetTriggerEffectParamInt("Status",2);
	    }
	    rmSetTriggerPriority(4);
	    rmSetTriggerActive(true);
	    rmSetTriggerRunImmediately(true);
	    rmSetTriggerLoop(false);
	}

	rmSetLightingSet(shineAlight);

	if (amazonMap == 1)
		rmSetGlobalRain(0.20);
	
	if (rmRandFloat(0,1) <= 0.001)
		rmSetWindMagnitude(69.0);
	else if (rmRandFloat(0,1) <= 0.01)
		rmSetWindMagnitude(5.0);
	else if (rmRandFloat(0,1) <= 0.10)
		rmSetWindMagnitude(2.0);
	else if (rmRandFloat(0,1) <= 0.25)
		rmSetWindMagnitude(1.0);

	if (snowMap == 1)
	{
		if (merryXmass == 1)
			rmSetGlobalSnow(1.00);
		else
			rmSetGlobalSnow(0.20);
	}

	if (floodedLand == 1)
	{
		rmSetSeaType(pondName);
		rmTerrainInitialize("water");
	}

	// add some overlapping features
	if (rmGetIsKOTH() == false)
	{
		if (splitIsland == 1)
		{
			if (rmRandFloat(0,1) <= 0.001)
			{
				riverName = oceanName;
				riverExists = 1;
			}
		}
		else if (floodedLand == 1)
		{
			if (rmRandFloat(0,1) <= 0.10)
				forestMiddle = 1;
			else if (rmRandFloat(0,1) <= 0.05)
			{
				oceanName = pondName;
				oceanMiddle = 1;
			}
			if (rmRandFloat(0,1) <= 0.05)
			{
				oceanName = pondName;
				oceanOffCenter = 1;
			}
			if (rmRandFloat(0,1) <= 0.05)
			{
				riverName = pondName;
				riverExists = 1;
				rogueMap = 0;
			}
		}
		else if (oceanOffCenter == 1)
		{
			if (rmRandFloat(0,1) <= 0.05)
				forestMiddle = 1;
			else if (rmRandFloat(0,1) <= 0.99)
				oceanMiddle = 1;
			if (rmRandFloat(0,1) <= 0.05)
			{
				riverName = oceanName;
				riverExists = 1;
				rogueMap = 0;
			}
		}
		else if (oceanMiddle == 1)
		{
			if (rmRandFloat(0,1) <= 0.10)
				oceanOffCenter = 1;
			if (rmRandFloat(0,1) <= 0.05)
			{
				riverName = oceanName;
				riverExists = 1;
				rogueMap = 0;
			}
		}
		else if (oceanRing == 1)
		{
			if (rmRandFloat(0,1) <= 0.05)
			{
				riverExists = 1;
				riverName = oceanName;
				rogueMap = 0;
			}
//			if (rmRandFloat(0,1) <= 0.10)
//				oceanOffCenter = 1;
			if (rmRandFloat(0,1) <= 0.10)
				oceanMiddle = 1;
			else if (rmRandFloat(0,1) <= 0.05)
				forestMiddle = 1;
		}
	}

	int sideBay = -1;	// random chance for middle lake to spawn as a side bay
	if (oceanOffCenter == 1 && oceanMiddle == 1 && rmRandFloat(0,1) <= 0.50)
		sideBay = 1;
//		sideBay = 1;	// for testing

	if (floodedLand == 1)
		rmEchoInfo("big flood");
	else if (oceanRing == 1)
		rmEchoInfo("big island");
	else if (splitIsland == 1)
		rmEchoInfo("split island");
	else if (landOnly == 1)
		rmEchoInfo("just land");
	else if (riverExists == 1)
		rmEchoInfo("river exists");
	else if (oceanMiddle == 1)
		rmEchoInfo("ocean in middle");
	else if (oceanOffCenter == 1)
		rmEchoInfo("ocean off center");
	else if (forestMiddle == 1)
		rmEchoInfo("forest in middle");

	int riverPosition = rmRandInt(1,8);		// randomly rotates orientation of river
	if (oceanOffCenter == 1 && riverExists == 1)
		riverPosition = rmRandInt(1,4);
//		riverPosition = 8;	// for testing
	if (riverExists == 1)
		rmEchoInfo("river position = "+riverPosition);

	float bayPosition = rmRandFloat(0,1);		// randomly rotates bay around map
	if (oceanOffCenter == 1 && riverExists == 1)
	{
		if (riverPosition == 1)
		{
			if (rmRandFloat(0,1) <= 0.50)
				bayPosition = 0.99;
			else
				bayPosition = 0.47;
		}
		if (riverPosition == 2)
		{
			if (rmRandFloat(0,1) <= 0.50)
				bayPosition = 0.83;
			else
				bayPosition = 0.35;
		}
		if (riverPosition == 3)
		{
			if (rmRandFloat(0,1) <= 0.50)
				bayPosition = 0.71;
			else
				bayPosition = 0.23;
		}
		if (riverPosition == 4)
		{
			if (rmRandFloat(0,1) <= 0.50)
				bayPosition = 0.59;
			else
				bayPosition = 0.11;
		}
	}
//		bayPosition = 0.95;		// for testing
	if (oceanOffCenter == 1)
		rmEchoInfo("bay position = "+bayPosition);

// ============= Classes =============
	int classPlayer = rmDefineClass("player");
	int classNatives = rmDefineClass("natives");
	int classPirates = rmDefineClass("pirates");
	int classElectors = rmDefineClass("electors");
	int classFlag = rmDefineClass("flag");
	int classCanyon = rmDefineClass("canyon");
	int classCliff = rmDefineClass("cliffs");
	int pondClass = rmDefineClass("pond");
	int classStarting = rmDefineClass("startingUnit");
	int classForest = rmDefineClass("classForest");
	int classGold = rmDefineClass("classGold");

// ============= Constraints =============
	int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 12.0);
	int playerAvoidImpassableLand = rmCreateTerrainDistanceConstraint("player avoid impassable land", "Land", false, 18.0);
	int mediumAvoidImpassableLand = rmCreateTerrainDistanceConstraint("slightly avoid impassable", "Land", false, 8.0);
	int shortAvoidImpassableLand = rmCreateTerrainDistanceConstraint("just barely avoid impassable", "Land", false, 4.0);
	int TCAvoidImpassableLand = rmCreateTerrainDistanceConstraint("TCs vs impassable land", "Land", false, 8.0);
	int avoidWater = rmCreateTerrainDistanceConstraint("avoid water ", "water", true, 8.0);
	int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short", "water", true, 4.0);
	int avoidWaterFar = rmCreateTerrainDistanceConstraint("avoid water far", "water", true, 10+cNumberNonGaiaPlayers);
	int avoidWaterFarPlus = rmCreateTerrainDistanceConstraint("avoid water far plus", "water", true, 20+cNumberNonGaiaPlayers);
	int stayNearWater = rmCreateTerrainMaxDistanceConstraint("stay near water ", "land", false, 18.0);
	int stayNearWaterShore = rmCreateTerrainMaxDistanceConstraint("stay near water shore", "land", false, 8.0);
	int cliffAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("cliff trade route", 2);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 20.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 4.0);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route sockets", "sockettraderoute", 8.0);
	int avoidTradeRouteSocketShort = rmCreateTypeDistanceConstraint("avoid trade route sockets short", "sockettraderoute", 4.0);
	int avoidCanyon = rmCreateClassDistanceConstraint("don't place on mesa where you can't path", classCanyon, 2.0);
	int avoidCliffs = rmCreateClassDistanceConstraint("cliffs avoid cliffs", classCliff, 21.0);
	int avoidCliffsMed = rmCreateClassDistanceConstraint("stuff avoid cliffs med", classCliff, 8.0);
	int avoidCliffsShort = rmCreateClassDistanceConstraint("stuff avoid cliffs short", classCliff, 3.0);
	int pondConstraint = rmCreateClassDistanceConstraint("ponds avoid ponds", rmClassID("pond"), 50.0);
	int pondConstraintFish = rmCreateClassDistanceConstraint("fish avoid ponds", rmClassID("pond"), 4.0);
	int forestConstraint = rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 17.0);
	int avoidTC = rmCreateTypeDistanceConstraint("vs. TC", "TownCenter", 8.0);
	int avoidTCFar = rmCreateTypeDistanceConstraint("vs. TC far", "TownCenter", 30.0);
	int avoidCommandPost = rmCreateTypeDistanceConstraint("vs. command post", "deSPCCommandPost", 8.0);
	int avoidCommandPostFar = rmCreateTypeDistanceConstraint("vs. command post far", "deSPCCommandPost", 30.0);
	int avoidCW = rmCreateTypeDistanceConstraint("vs. CW", "CoveredWagon", 8.0);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "abstractNugget", 16.0);
	int avoidNugget = rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 40.0);
	int avoidNuggetMed = rmCreateTypeDistanceConstraint("nugget avoid nugget med", "abstractNugget", 20.0);
	int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget far", "abstractNugget", 60.0);
	int avoidHuari = rmCreateTypeDistanceConstraint("huari avoid huari", "HuariStrongholdAndes", 50.0);
	int fishVsFishFar = rmCreateTypeDistanceConstraint("fish v fish far", "abstractFish", 18+cNumberNonGaiaPlayers);
	int fishVsFishID = rmCreateTypeDistanceConstraint("fish v fish", "abstractFish", 12.0);
	int whaleVsWhaleFar = rmCreateTypeDistanceConstraint("whale v whale far", "abstractWhale", 82-cNumberNonGaiaPlayers);
	int whaleVsWhaleID = rmCreateTypeDistanceConstraint("whale v whale", "abstractWhale", 24+2*cNumberNonGaiaPlayers);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 4.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 12.0);
	int whaleLandFar = rmCreateTerrainDistanceConstraint("whale v. land", "land", true, 24.0);
	int avoidFood = rmCreateTypeDistanceConstraint("food avoids food", "food", 40.0);
	int avoidFood1 = rmCreateTypeDistanceConstraint("food avoids food1", critterOneName, 40+3*cNumberNonGaiaPlayers);
	int avoidFood2 = rmCreateTypeDistanceConstraint("food avoids food2", critterTwoName, 40+3*cNumberNonGaiaPlayers);
	int avoidFood1Far = rmCreateTypeDistanceConstraint("food avoids food1 far", critterOneName, 50+2.5*cNumberNonGaiaPlayers);
	int avoidFood2Far = rmCreateTypeDistanceConstraint("food avoids food2 far", critterTwoName, 50+2.5*cNumberNonGaiaPlayers);
	int avoidHuntable = rmCreateTypeDistanceConstraint("hunt avoids hunt", "huntable", 50);
	int avoidSilver = rmCreateTypeDistanceConstraint("fast coin avoids coin", "gold", 50+2.5*cNumberNonGaiaPlayers);
	int avoidForestMin = rmCreateClassDistanceConstraint("avoid forest min", rmClassID("classForest"), 4.0);
	int avoidForestZero = rmCreateClassDistanceConstraint("avoid forest zero", rmClassID("classForest"), 1.0);
	int avoidShipwreck = rmCreateClassDistanceConstraint("avoid shipwreck", rmClassID("classForest"), 40.0);
   	int avoidPond = rmCreateClassDistanceConstraint("avoid pond min", rmClassID("pond"), 8.0);
   	int flagVsFlag = rmCreateClassDistanceConstraint("avoid flag", rmClassID("flag"), 4.0);
	int avoidPlayersSplitIsland = rmCreateClassDistanceConstraint("stay away from players split island", classPlayer, 69.0);
	int avoidPlayers = -1;
	int avoidPlayersShort = -1;
	int avoidPlayersFar = -1;
	int avoidPlayersFar1 = -1;
	if (rmGetNomadStart() == true)
	{
		avoidPlayers = rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 6.0);
		avoidPlayersShort = rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 4.0);
		avoidPlayersFar = rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 24.0);
		avoidPlayersFar1 = rmCreateClassDistanceConstraint("stay away from players far1", classPlayer, 12.0);
	}
	else
	{
		avoidPlayers = rmCreateClassDistanceConstraint("stay away from players medium", classPlayer, 15.0);
		avoidPlayersShort = rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 8.0);
//		if (splitIsland == 1)
//			avoidPlayersFar = rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 69.0);
//		else
			avoidPlayersFar = rmCreateClassDistanceConstraint("stay away from players far", classPlayer, 50.0);
		avoidPlayersFar1 = rmCreateClassDistanceConstraint("stay away from players far1", classPlayer, 30.0);
	}
	int avoidSilver1 = rmCreateTypeDistanceConstraint("fast coin avoids coin1", "gold", 12.0);
	int avoidSilver1Short = rmCreateTypeDistanceConstraint("fast coin avoids coin1 short", "gold", 8.0);
	int avoidGoldMin = rmCreateClassDistanceConstraint("stay away from minerals", classGold, 4.0);
	int avoidGoldShort = rmCreateClassDistanceConstraint("stay away from minerals short", classGold, 12.0);
	int avoidGoldMed = rmCreateClassDistanceConstraint("avoid gold class med", classGold, 20);
	int avoidGold = rmCreateClassDistanceConstraint("avoid gold class", classGold, 40);
	int avoidGoldFar = rmCreateClassDistanceConstraint("stay away from minerals far", classGold, 40+2.5*cNumberNonGaiaPlayers);
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint("stay away from minerals very far", classGold, 60+2*cNumberNonGaiaPlayers);
	int avoidAll = rmCreateTypeDistanceConstraint("avoid all", "all", 4.0);
	int avoidAllFar = rmCreateTypeDistanceConstraint("avoid all far", "all", 8.0);

   // pie constraints
	int edgeConstraintSplitIsland = rmCreatePieConstraint("split islands avoid edge",  0.5, 0.5, 0, rmGetMapXSize()-24, 0, 0, 0);
	int edgeConstraintShort = rmCreatePieConstraint("continent avoids edge short",  0.5, 0.5, 0, rmGetMapXSize()-8, 0, 0, 0);
	int edgeConstraint = rmCreatePieConstraint("continent avoids edge",  0.5, 0.5, 0, rmGetMapXSize()-30, 0, 0, 0);
	int avoidEdge = rmCreatePieConstraint("Avoid Edge",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidEdgeFar = rmCreatePieConstraint("Avoid Edge Far",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.43), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayNearEdge = rmCreatePieConstraint("stay near edge",0.5,0.5,rmXFractionToMeters(0.41), rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("stay center",0.5,0.5,rmXFractionToMeters(0.00), rmXFractionToMeters(0.15), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterMin = rmCreatePieConstraint("avoid center min",0.5,0.5,rmXFractionToMeters(0.13), rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("avoid center",0.5,0.5,rmXFractionToMeters(0.15), rmXFractionToMeters(0.35), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterFar = rmCreatePieConstraint("avoid center far",0.5,0.5,rmXFractionToMeters(0.35), rmXFractionToMeters(0.45), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterFlag = rmCreatePieConstraint("avoid center flag",0.5,0.5,rmXFractionToMeters(0.40), rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
    int staySudFar = rmCreatePieConstraint("Stay South Far", 0.50, 0.50, rmXFractionToMeters(0.35), rmXFractionToMeters(0.48), rmDegreesToRadians(200), rmDegreesToRadians(250));
    int stayNorFar = rmCreatePieConstraint("Stay North Far", 0.50, 0.50, rmXFractionToMeters(0.35), rmXFractionToMeters(0.48), rmDegreesToRadians(020), rmDegreesToRadians(070));
    int stayWstFar = rmCreatePieConstraint("Stay West Far", 0.50, 0.50, rmXFractionToMeters(0.35), rmXFractionToMeters(0.48), rmDegreesToRadians(290), rmDegreesToRadians(340));
    int stayEstFar = rmCreatePieConstraint("Stay East Far", 0.50, 0.50, rmXFractionToMeters(0.35), rmXFractionToMeters(0.48), rmDegreesToRadians(110), rmDegreesToRadians(160));
    int staySud = -1;
    int stayNor = -1;
    int stayWst = -1;
    int stayEst = -1;
	if (splitIsland == 1)
	{
    	staySud = rmCreatePieConstraint("Stay South", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.43), rmDegreesToRadians(180), rmDegreesToRadians(270));
    	stayNor = rmCreatePieConstraint("Stay North", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.43), rmDegreesToRadians(000), rmDegreesToRadians(090));
    	stayWst = rmCreatePieConstraint("Stay West", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.43), rmDegreesToRadians(270), rmDegreesToRadians(360));
    	stayEst = rmCreatePieConstraint("Stay East", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.43), rmDegreesToRadians(090), rmDegreesToRadians(180));
	}
	else
	{
    	staySud = rmCreatePieConstraint("Stay South", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(200), rmDegreesToRadians(250));
    	stayNor = rmCreatePieConstraint("Stay North", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(020), rmDegreesToRadians(070));
    	stayWst = rmCreatePieConstraint("Stay West", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(290), rmDegreesToRadians(340));
    	stayEst = rmCreatePieConstraint("Stay East", 0.50, 0.50, rmXFractionToMeters(0.00), rmXFractionToMeters(0.45), rmDegreesToRadians(110), rmDegreesToRadians(160));
	}

	// don't build ocean everytime
	if (oceanMiddle == 1)
	{
		int oceanChance = rmRandInt(1,5);		// randomly alternates blocked middle layouts
		if (rmGetIsTreaty() == false)
		{
			rmEchoInfo("it's not treaty so there's a higher chance of water");
			oceanChance = rmRandInt(1,4);
			if (oceanChance == 2 && rmRandFloat(0,1) <= 0.25)
				oceanChance = 1;
			if (oceanChance == 3 && rmRandFloat(0,1) <= 0.25)
				oceanChance = 1;
			if (oceanChance == 4 && rmRandFloat(0,1) <= 0.25)
				oceanChance = 1;
		}
	}
	if (oceanMiddle == 1 && oceanOffCenter == 1)
		oceanChance = 1;
//			oceanChance = 1;		// for testing

	if (oceanChance == 5)
		blockedMiddle = -1;

	if (oceanOffCenter == 1)
	{
		int bayChance = rmRandInt(1,5);		// randomly replaces bay with alternative layouts
		if (rmGetIsTreaty() == false)
		{
			rmEchoInfo("it's not treaty so there's a higher chance of water");
			bayChance = rmRandInt(1,4);
//			bayChance = 3;		// for testing
			if (bayChance == 2 && rmRandFloat(0,1) <= 0.25)
				bayChance = 1;
			if (bayChance == 3 && rmRandFloat(0,1) <= 0.25)
				bayChance = 1;
			if (bayChance == 4 && rmRandFloat(0,1) <= 0.25)
				bayChance = 1;
		}
	}
	if (oceanMiddle == 1 && oceanOffCenter == 1)
		bayChance = 1;
//			bayChance = 1;		// for testing

	// native variables
	int nativeNumber = (rmRandInt(2,4)+(cNumberNonGaiaPlayers/4));	// random number of natives
	int tpORnot = rmRandInt(1,10);	// if 5, only natives spawn
	int natDist = 0.00;		// controls how far apart natives are constrained

	if (riverExists == 1)
	{
		if (riverWidthController != 1)
			tpORnot = 5;
		else if (riverPosition >= 5)
			tpORnot = rmRandInt(1,5);
		else
			tpORnot = rmRandInt(3,5);
	}
	if (rmGetIsKOTH() == true && rmRandFloat(0,1) <= 0.50)
		tpORnot = 5;
	if (blockedMiddle == 1)
		tpORnot = rmRandInt(4,5);
	if (oceanRing == 1)
		tpORnot = rmRandInt(1,5);
	if (forestMiddle == 1)
		tpORnot = rmRandInt(4,5);
	if (oceanRing == 1 && riverExists == 1 && fullShallow != 1)
		tpORnot = 5;
//	if (floodedLand == 1 && oceanMiddle == 1)
//		tpORnot = 5;
	if (oceanRing == 1 && oceanMiddle == 1)
		tpORnot = 5;
	if (oceanOffCenter == 1 && oceanMiddle == 1)
	{
		if (sideBay == 1)
			tpORnot = rmRandInt(2,5);
		else
			tpORnot = 5;
	}	
	if (oceanOffCenter == 1 && riverExists == 1)
		tpORnot = 5;
//	if (floodedLand == 1 && riverExists == 1)
//		tpORnot = 5;
	if (splitIsland == 1)
		tpORnot = 5;
//	if (riverWidthController !=1)
//	{
//		if (fullShallow == 1)
//			tpORnot = rmRandInt(1,5);
//		else
//			tpORnot = 5;
//	}
//	tpORnot = 5;		// for testing
	rmEchoInfo("tpORnot = "+tpORnot);

	if (tpORnot == 5)
	{
		if (riverWidthController == 1)	// narrow river
			nativeNumber = (7+(cNumberNonGaiaPlayers/4));
		else
			nativeNumber = (6+(cNumberNonGaiaPlayers/4));
	}

//	nativeNumber = 8; 	// for testing
	rmEchoInfo("Native number = "+nativeNumber);

	if (tpORnot == 5)
	{
		if (oceanRing == 1)
		{
			if (riverWidthController == 1)	// narrow river
				natDist = 69;
			else
				natDist = 50;
		}
		else
			natDist = 30;
	}
	else
	{
		if (oceanRing == 1)
			natDist = 44;
		else
			natDist = 40;
	}
	if (rmGetNomadStart() == true)
		natDist = 24;
	if (oceanRing == 1 || splitIsland == 1)
		natDist = 44;

	int avoidNatives = rmCreateClassDistanceConstraint("stay away from natives", classNatives, natDist+6*cNumberNonGaiaPlayers);
	int avoidNativesShort = rmCreateClassDistanceConstraint("stay away from natives", classNatives, 12+cNumberNonGaiaPlayers);
	int avoidElectors = rmCreateClassDistanceConstraint("electors avoidance", classElectors, 48);
	int avoidElectorsMed = rmCreateClassDistanceConstraint("stay away from electors med", classElectors, 24);
	int avoidElectorsShort = rmCreateClassDistanceConstraint("stay away from electors short", classElectors, 8);
	int avoidPirates = rmCreateClassDistanceConstraint("controller avoidance", classPirates, 48);
	int avoidPiratesMed = rmCreateClassDistanceConstraint("stay away from pirates med", classPirates, 36);
	int avoidPiratesShort = rmCreateClassDistanceConstraint("stay away from pirates short", classPirates, 8);
	int avoidPiratesController = -1;
//	if (oceanRing == 1)
//	{
//		if (cNumberNonGaiaPlayers == 2)
//			avoidPiratesController = rmCreateClassDistanceConstraint("stay away from pirates", classPirates, 222);
//		else
//			avoidPiratesController = rmCreateClassDistanceConstraint("stay away from pirates", classPirates, ((40+cNumberNonGaiaPlayers)*8));
//	}
//	else
		avoidPiratesController = rmCreateClassDistanceConstraint("stay away from pirates", classPirates, 69);
	int nativesAvoidPlayers = rmCreateClassDistanceConstraint("natives vs. players", classPlayer, natDist);

	// Set-up terrain for each configuration
	if(floodedLand == 1)
	{
		// ============= Big Flood =============
    	int floodedContinent = rmCreateArea("floodedContinent");
        rmSetAreaSize(floodedContinent, 0.99);
        rmSetAreaLocation(floodedContinent, 0.50, 0.50);    
		if (rmGetIsTreaty() == true)
	        rmSetAreaBaseHeight(floodedContinent, 1.10);
        else
			rmSetAreaBaseHeight(floodedContinent, 0.87);
        rmSetAreaCoherence(floodedContinent, 0.999);
        rmSetAreaSmoothDistance(floodedContinent, 10);
        rmSetAreaHeightBlend(floodedContinent, -1.0);
		rmSetAreaMix(floodedContinent, landName); 
        rmSetAreaElevationNoiseBias(floodedContinent, 0);
        rmSetAreaElevationEdgeFalloffDist(floodedContinent, 10);
        rmSetAreaElevationVariation(floodedContinent, 3);
        rmSetAreaElevationPersistence(floodedContinent, .2);
        rmSetAreaElevationOctaves(floodedContinent, 5);
        rmSetAreaElevationMinFrequency(floodedContinent, 0.04);
        rmSetAreaElevationType(floodedContinent, cElevTurbulence);  
        rmBuildArea(floodedContinent);
	}
	else if(oceanRing == 1 || splitIsland == 1)
	{
		// ============= Big Ocean =============
		int worldOcean = rmCreateArea("ocean that covers whole map");
		rmSetAreaWaterType(worldOcean, oceanName);
		rmSetAreaSize(worldOcean, 1, 1);
//		rmSetAreaReveal(worldOcean, 01);
		rmSetAreaLocation(worldOcean, 0.5, 0.5);
		rmSetAreaWarnFailure(worldOcean, false);
		rmSetAreaObeyWorldCircleConstraint(worldOcean, false);
		rmBuildArea(worldOcean);

		if(oceanRing == 1)
		{
			// ============= Big Island =============
			int continent = rmCreateArea("island continent in ocean");
			rmSetAreaMix(continent, landName);
			rmSetAreaElevationType(continent, cElevTurbulence);
			rmSetAreaElevationVariation(continent, 2.0);
			rmSetAreaBaseHeight(continent, 2.0);
			rmSetAreaElevationMinFrequency(continent, 0.09);
			rmSetAreaElevationOctaves(continent, 3);
			rmSetAreaElevationPersistence(continent, 0.2);
			rmSetAreaElevationNoiseBias(continent, 1);
			rmSetAreaLocation(continent, 0.5, 0.5);
			if (chaosBar == 1)
			{
				rmSetAreaSize(continent, 0.29, 0.33);
				rmAddAreaInfluencePoint(continent, 0.70, 0.70);
				rmAddAreaInfluencePoint(continent, 0.30, 0.30);
				rmAddAreaInfluencePoint(continent, 0.70, 0.30);
				rmAddAreaInfluencePoint(continent, 0.30, 0.70);
				rmAddAreaInfluencePoint(continent, 0.80, 0.50);
				rmAddAreaInfluencePoint(continent, 0.50, 0.80);
				rmAddAreaInfluencePoint(continent, 0.50, 0.20);
				rmAddAreaInfluencePoint(continent, 0.20, 0.50);
			}
			else
				rmSetAreaSize(continent, 0.38, 0.40);
//			rmSetAreaSmoothDistance(continent, 50);
			rmSetAreaCoherence(continent, 0.444);
//			rmAddAreaConstraint(continent, avoidEdge);
			rmAddAreaConstraint(continent, edgeConstraint);
			rmBuildArea(continent);		
		}

		if(splitIsland == 1)
		{
			// ============= Split Islands =============
			int splitChance = rmRandInt(1,4);		// controls orientation of two islands
//				splitChance = 4;	// for testing
			float isle1LocX = 0;		// coordinates of islands and influence segments
			float isle1LocY = 0;		// coordinates of islands and influence segments
			float isle2LocX = 0;		// coordinates of islands and influence segments
			float isle2LocY = 0;		// coordinates of islands and influence segments
			float influence1LocX = 0;	// coordinates of islands and influence segments
			float influence1LocY = 0;	// coordinates of islands and influence segments
			float influence2LocX = 0;	// coordinates of islands and influence segments
			float influence2LocY = 0;	// coordinates of islands and influence segments
			float isleSize = rmRandFloat(0.16,0.18);

			if (splitChance == 1)	// check
			{
				isle1LocX = 0.70;
				isle1LocY = 0.70;
				isle2LocX = 0.30;
				isle2LocY = 0.30;
				influence1LocX = rmRandFloat(0.05,0.20);
				influence1LocY = rmRandFloat(0.15,0.35);
				influence2LocX = rmRandFloat(0.05,0.20);
				influence2LocY = rmRandFloat(0.15,0.35);
			}
			else if (splitChance == 2)	// check
			{
				isle1LocX = 0.70;
				isle1LocY = 0.50;
				isle2LocX = 0.30;
				isle2LocY = 0.50;
				influence1LocX = rmRandFloat(0.05,0.20);
				influence1LocY = rmRandFloat(0.15,0.35);
				influence2LocX = rmRandFloat(0.05,0.20);
				influence2LocY = rmRandFloat(0.15,0.35);
			}
			else if (splitChance == 3)	// check
			{
				isle1LocX = 0.70;
				isle1LocY = 0.30;
				isle2LocX = 0.30;
				isle2LocY = 0.70;
				influence1LocX = rmRandFloat(0.05,0.20);
				influence1LocY = rmRandFloat(0.15,0.35);
				influence2LocX = rmRandFloat(0.05,0.20);
				influence2LocY = rmRandFloat(0.15,0.35);
			}
			else	// check
			{
				isle1LocX = 0.50;
				isle1LocY = 0.30;
				isle2LocX = 0.50;
				isle2LocY = 0.70;
				influence1LocX = rmRandFloat(0.10,0.25);
				influence1LocY = rmRandFloat(0.10,0.25);
				influence2LocX = rmRandFloat(0.10,0.25);
				influence2LocY = rmRandFloat(0.10,0.25);
			}

			int avoidThisIslandID = rmCreateArea("avoid this island");
//			rmSetAreaMix(avoidThisIslandID, "testmix");		// for testing
//			rmSetAreaBaseHeight(avoidThisIslandID, 2.0);	// for testing
			rmSetAreaSize(avoidThisIslandID, 0.02);
			rmSetAreaLocation(avoidThisIslandID, 0.50, 0.50);
			if (splitChance == 1)
			{
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.70, 0.30);
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.30, 0.70);
			}
			else if (splitChance == 2)
			{
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.50, 0.70);
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.50, 0.30);
			}
			else if (splitChance == 3)
			{
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.70, 0.70);
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.30, 0.30);
			}
			else
			{
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.70, 0.50);
				rmAddAreaInfluenceSegment(avoidThisIslandID, 0.50, 0.50, 0.30, 0.50);
			}
			rmSetAreaCoherence(avoidThisIslandID, 0.50);
			if (trollBar != 1)
				rmBuildArea(avoidThisIslandID);

			int avoidMidIsland = rmCreateAreaDistanceConstraint("avoid mid island ", avoidThisIslandID, 2.0);

			int splitIslandID1 = rmCreateArea("split island 1");
			rmSetAreaMix(splitIslandID1, landName);
			rmSetAreaElevationType(splitIslandID1, cElevTurbulence);
			rmSetAreaElevationVariation(splitIslandID1, 2.0);
			rmSetAreaBaseHeight(splitIslandID1, 2.0);
			rmSetAreaElevationMinFrequency(splitIslandID1, 0.09);
			rmSetAreaElevationOctaves(splitIslandID1, 3);
			rmSetAreaElevationPersistence(splitIslandID1, 0.2);
			rmSetAreaElevationNoiseBias(splitIslandID1, 1);
			rmSetAreaSize(splitIslandID1, isleSize);
			rmSetAreaLocation(splitIslandID1, isle1LocX, isle1LocY);
			if (splitChance == 1)
			{
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX+influence1LocX, isle1LocY-influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX-influence2LocX, isle1LocY+influence2LocY);
			}
			else if (splitChance == 2)
			{
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX+influence1LocX, isle1LocY-influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX+influence2LocX, isle1LocY+influence2LocY);
			}
			else if (splitChance == 3)
			{
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX+influence1LocX, isle1LocY+influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX-influence2LocX, isle1LocY-influence2LocY);
			}
			else
			{
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX+influence1LocX, isle1LocY-influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID1, isle1LocX, isle1LocY, isle1LocX-influence2LocX, isle1LocY-influence2LocY);
			}
			rmSetAreaSmoothDistance(splitIslandID1, 50);
			rmSetAreaCoherence(splitIslandID1, 0.444);
			rmAddAreaConstraint(splitIslandID1, edgeConstraintSplitIsland);
			if (trollBar != 1)
				rmAddAreaConstraint(splitIslandID1, avoidMidIsland);
			else
			{
				rmAddAreaConstraint(splitIslandID1, avoidCenterMin);
				rmAddAreaConstraint(splitIslandID1, whaleLandFar);	
			}
			rmBuildArea(splitIslandID1);

			int splitIslandID2 = rmCreateArea("split island 2");
			rmSetAreaMix(splitIslandID2, landName);
			rmSetAreaElevationType(splitIslandID2, cElevTurbulence);
			rmSetAreaElevationVariation(splitIslandID2, 2.0);
			rmSetAreaBaseHeight(splitIslandID2, 2.0);
			rmSetAreaElevationMinFrequency(splitIslandID2, 0.09);
			rmSetAreaElevationOctaves(splitIslandID2, 3);
			rmSetAreaElevationPersistence(splitIslandID2, 0.2);
			rmSetAreaElevationNoiseBias(splitIslandID2, 1);
			rmSetAreaSize(splitIslandID2, isleSize);
			rmSetAreaLocation(splitIslandID2, isle2LocX, isle2LocY);
			if (splitChance == 1)
			{
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX+influence1LocX, isle2LocY-influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX-influence2LocX, isle2LocY+influence2LocY);
			}
			else if (splitChance == 2)
			{
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX-influence1LocX, isle2LocY-influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX-influence2LocX, isle2LocY+influence2LocY);
			}
			else if (splitChance == 3)
			{
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX+influence1LocX, isle2LocY+influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX-influence2LocX, isle2LocY-influence2LocY);
			}
			else
			{
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX+influence1LocX, isle2LocY+influence1LocY);
				rmAddAreaInfluenceSegment(splitIslandID2, isle2LocX, isle2LocY, isle2LocX-influence2LocX, isle2LocY+influence2LocY);
			}
			rmSetAreaSmoothDistance(splitIslandID2, 50);
			rmSetAreaCoherence(splitIslandID2, 0.444);
			rmAddAreaConstraint(splitIslandID2, edgeConstraintSplitIsland);
			if (trollBar != 1)
				rmAddAreaConstraint(splitIslandID2, avoidMidIsland);
			else
			{
				rmAddAreaConstraint(splitIslandID2, avoidCenterMin);
				rmAddAreaConstraint(splitIslandID2, whaleLandFar);	
			}
			rmBuildArea(splitIslandID2);		

			int avoidTeam1Island = rmCreateAreaDistanceConstraint("avoid team 1 isle", splitIslandID1, 8.0);
			int stayInTeam1Isle = rmCreateAreaMaxDistanceConstraint("stay in team 1 isle", splitIslandID1, 0.0);
			int stayNearTeam1Isle = rmCreateAreaMaxDistanceConstraint("stay near team 1 isle", splitIslandID1, 22.0);
			int avoidTeam2Island = rmCreateAreaDistanceConstraint("avoid team 2 isle", splitIslandID2, 8.0);
			int stayInTeam2Isle = rmCreateAreaMaxDistanceConstraint("stay in team 2 isle", splitIslandID2, 0.0);
			int stayNearTeam2Isle = rmCreateAreaMaxDistanceConstraint("stay near team 2 isle", splitIslandID2, 22.0);
		}
	}
	else
	{
		// Paint the land to avoid weird terrain bug
			// ============= Paint Layer =============
			int paintLayerID = rmCreateArea("paint the land");
			rmSetAreaMix(paintLayerID, baseMix);
			rmSetAreaLocation(paintLayerID, 0.5, 0.5);
			rmSetAreaSize(paintLayerID, 0.99);
			rmSetAreaCoherence(paintLayerID, 0.999);
			rmBuildArea(paintLayerID);		
	}

	// ============= Trade Route =============
	if (tpORnot != 5)
	{
		int tpVariation = rmRandInt(3,10);		// RNG for trade route shape, 1 = big circle, 2 = small circle/square, else is linear
		if (blockedMiddle == 1)
			tpVariation = 1;

		if (forestMiddle == 1 && oceanRing != 1)
			tpVariation = rmRandInt(1,10);

		if (forestMiddle == 1 && oceanOffCenter == 1)
			tpVariation = rmRandInt(2,10);

		if (riverExists == 1 && riverPosition >= 5)
			tpVariation = 1;

		if (oceanRing == 1)
			tpVariation = rmRandInt(2,10);

		if (sideBay == 1)
			tpVariation = rmRandInt(2,10);

		if (rmGetIsKOTH() == true)
		{
			if (oceanRing == 1)
				tpVariation = 2;
			else if (oceanOffCenter == 1)
				tpVariation = 2;
			else if (sideBay == 1)
				tpVariation = 2;
			else
				tpVariation = rmRandInt(1,2);
		}

	//		tpVariation = 1;	// for testing
			rmEchoInfo("trade route variation = "+tpVariation);

		int socketID = rmCreateObjectDef("sockets to dock Trade Posts");
		if (trollBar == 1 && saharaMap == 1)
		{
			tpCapture = 1;
			rmAddObjectDefItem(socketID, "deTradingPostCaptureAfrican", 1, 6.0);
			rmAddObjectDefItem(socketID, "Nugget", 1, 6.0);
			rmSetNuggetDifficulty(99, 99);	
			rmAddObjectDefToClass(socketID, classCliff);
		}
		else if (trollBar == 1 && silkRoadMap == 1 && rmRandFloat(0,1) <= 0.17)
		{
			tpCapture = 1;
			rmAddObjectDefItem(socketID, "ypTradingPostCapture", 1, 6.0);
			rmAddObjectDefItem(socketID, "Nugget", 1, 6.0);
			rmSetNuggetDifficulty(99, 99);		  
			rmAddObjectDefToClass(socketID, classCliff);
		}
		else
	    rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	    rmSetObjectDefAllowOverlap(socketID, true);
	    rmAddObjectDefConstraint(socketID, avoidEdge);
	    rmSetObjectDefMinDistance(socketID, 3.0);
	    rmSetObjectDefMaxDistance(socketID, 11.0);    

	    int tradeRouteID = rmCreateTradeRoute();
	    rmSetObjectDefTradeRouteID(socketID, tradeRouteID);

		float startLocX = 0.00;		// randomly chooses start and endpoint of trade route
		float startLocY = 0.00;		// randomly chooses start and endpoint of trade route
		float endLocX = 0.00;		// randomly chooses start and endpoint of trade route
		float endLocY = 0.00;		// randomly chooses start and endpoint of trade route

		int whereTRstart = rmRandInt(1,4);	// each chooses a different map edge to start/end trade route at
		int whereTRend = rmRandInt(1,4);	// each chooses a different map edge to start/end trade route at

		if (riverExists == 1)
		{
			if (riverPosition == 1)
			{
				if (tpVariation < 7)
				{
					whereTRstart = 1;
					whereTRend = 3;	
				}
				else
				{
					whereTRstart = 3;
					whereTRend = 1;	
				}
			}
			if (riverPosition == 2)
			{
				whereTRstart = 1;
				whereTRend = 1;	
			}
			if (riverPosition == 3)
			{
				if (tpVariation < 7)
				{
					whereTRstart = 2;
					whereTRend = 4;	
				}
				else
				{
					whereTRstart = 4;
					whereTRend = 2;	
				}
			}
			if (riverPosition == 4)
			{
				whereTRstart = 1;
				whereTRend = 1;	
			}
		}

		if (oceanOffCenter == 1)
		{
			if(bayPosition < 0.12)
			{
				whereTRstart = 2;
				whereTRend = 1;	
			}
			else if(bayPosition < 0.24)
			{
				whereTRstart = 3;
				whereTRend = 1;	
			}
			else if(bayPosition < 0.36)
			{
				whereTRstart = 3;
				whereTRend = 2;	
			}
			else if(bayPosition < 0.48)
			{
				whereTRstart = 4;
				whereTRend = 2;	
			}
			else if(bayPosition < 0.60)
			{
				whereTRstart = 4;
				whereTRend = 3;	
			}
			else if(bayPosition < 0.72)
			{
				whereTRstart = 3;
				whereTRend = 1;	
			}
			else if(bayPosition < 0.84)
			{
				whereTRstart = 4;
				whereTRend = 1;	
			}
			else
			{
				whereTRstart = 4;
				whereTRend = 2;	
			}
		}

		if (whereTRstart == whereTRend && riverExists != 1)
		{
			if (tpVariation < 7)
			{
				if (oceanRing == 1)
				{
					startLocX = rmRandFloat(0.70,0.75);
					startLocY = rmRandFloat(0.70,0.75);
					endLocX = rmRandFloat(0.25,0.30);
					endLocY = rmRandFloat(0.25,0.30);
				}
				else
				{
					startLocX = rmRandFloat(0.80,0.90);
					startLocY = rmRandFloat(0.80,0.90);
					endLocX = rmRandFloat(0.10,0.20);
					endLocY = rmRandFloat(0.10,0.20);
				}
			}
			else
			{
				if (oceanRing == 1)
				{
					startLocX = rmRandFloat(0.25,0.30);
					startLocY = rmRandFloat(0.70,0.75);
					endLocX = rmRandFloat(0.70,0.75);
					endLocY = rmRandFloat(0.25,0.30);
				}
				else
				{
					startLocX = rmRandFloat(0.10,0.20);
					startLocY = rmRandFloat(0.80,0.90);
					endLocX = rmRandFloat(0.80,0.90);
					endLocY = rmRandFloat(0.10,0.20);
				}
			}
		}
		else if (whereTRstart == whereTRend && riverExists == 1)
		{
			if (riverPosition <= 2)
			{
				if (tpVariation < 7)
				{
					if (oceanRing == 1)
					{
						startLocX = rmRandFloat(0.70,0.75);
						startLocY = rmRandFloat(0.25,0.30);
						endLocX = rmRandFloat(0.25,0.30);
						endLocY = rmRandFloat(0.70,0.75);
					}
					else
					{
						startLocX = rmRandFloat(0.80,0.90);
						startLocY = rmRandFloat(0.10,0.20);
						endLocX = rmRandFloat(0.10,0.20);
						endLocY = rmRandFloat(0.80,0.90);
					}
				}
				else
				{
					if (oceanRing == 1)
					{
						startLocX = rmRandFloat(0.25,0.30);
						startLocY = rmRandFloat(0.70,0.75);
						endLocX = rmRandFloat(0.70,0.75);
						endLocY = rmRandFloat(0.25,0.30);
					}
					else
					{
						startLocX = rmRandFloat(0.10,0.20);
						startLocY = rmRandFloat(0.80,0.90);
						endLocX = rmRandFloat(0.80,0.90);
						endLocY = rmRandFloat(0.10,0.20);
					}
				}
			}
			else
			{
				if (tpVariation < 7)
				{
					if (oceanRing == 1)
					{
						startLocX = rmRandFloat(0.70,0.75);
						startLocY = rmRandFloat(0.70,0.75);
						endLocX = rmRandFloat(0.25,0.30);
						endLocY = rmRandFloat(0.25,0.30);
					}
					else
					{
						startLocX = rmRandFloat(0.80,0.90);
						startLocY = rmRandFloat(0.80,0.90);
						endLocX = rmRandFloat(0.10,0.20);
						endLocY = rmRandFloat(0.10,0.20);
					}
				}
				else
				{
					if (oceanRing == 1)
					{
						startLocX = rmRandFloat(0.25,0.30);
						startLocY = rmRandFloat(0.25,0.30);
						endLocX = rmRandFloat(0.70,0.75);
						endLocY = rmRandFloat(0.70,0.75);
					}
					else
					{
						startLocX = rmRandFloat(0.10,0.20);
						startLocY = rmRandFloat(0.10,0.20);
						endLocX = rmRandFloat(0.80,0.90);
						endLocY = rmRandFloat(0.80,0.90);
					}
				}
			}
		}
		else
		{
			if (whereTRstart == 1)
			{
//				if (rmGetIsTreaty() == true)
					startLocX = rmRandFloat(0.40,0.60);
//				else
//					startLocX = rmRandFloat(0.30,0.70);
				if (oceanRing == 1)
					startLocY = 0.85;
				else
					startLocY = 0.95;
				if (landOnly == 1 || oceanChance == 5 || oceanRing == 1)
				{
					whereTRend = 3;
				}
			}
			else if (whereTRstart == 2)
			{
				if (oceanRing == 1)
					startLocX = 0.85;
				else
					startLocX = 0.95;
				if (rmGetIsTreaty() == true)
					startLocY = rmRandFloat(0.40,0.60);
				else
					startLocY = rmRandFloat(0.30,0.70);
				if (landOnly == 1 || oceanChance == 5 || oceanRing == 1)
				{
					whereTRend = 4;
				}
			}
			else if (whereTRstart == 3)
			{
//				if (rmGetIsTreaty() == true)
					startLocX = rmRandFloat(0.40,0.60);
//				else
//					startLocX = rmRandFloat(0.30,0.70);
				if (oceanRing == 1)
					startLocY = 0.15;
				else
					startLocY = 0.05;
				if (landOnly == 1 || oceanChance == 5 || oceanRing == 1)
				{
					whereTRend = 1;
				}
			}
			else	// 4
			{
				if (oceanRing == 1)
					startLocX = 0.15;
				else
					startLocX = 0.05;
//				if (rmGetIsTreaty() == true)
					startLocY = rmRandFloat(0.40,0.60);
//				else
//					startLocY = rmRandFloat(0.30,0.70);
				if (landOnly == 1 || oceanChance == 5 || oceanRing == 1)
				{
					whereTRend = 2;
				}
			}

			if (whereTRend == 1)
			{
//				if (rmGetIsTreaty() == true)
					endLocX = rmRandFloat(0.40,0.60);
//				else
//					endLocX = rmRandFloat(0.30,0.70);
				if (oceanRing == 1)
					endLocY = 0.85;
				else
					endLocY = 0.95;
			}
			else if (whereTRend == 2)
			{
				if (oceanRing == 1)
					endLocX = 0.85;
				else
					endLocX = 0.95;
//				if (rmGetIsTreaty() == true)
					endLocY = rmRandFloat(0.40,0.60);
//				else
//					endLocY = rmRandFloat(0.30,0.70);
			}
			else if (whereTRend == 3)
			{
//				if (rmGetIsTreaty() == true)
					endLocX = rmRandFloat(0.40,0.60);
//				else
//					endLocX = rmRandFloat(0.30,0.70);
				if (oceanRing == 1)
					endLocY = 0.15;
				else
					endLocY = 0.05;
			}
			else
			{
				if (oceanRing == 1)
					endLocX = 0.15;
				else
					endLocX = 0.05;
//				if (rmGetIsTreaty() == true)
					endLocY = rmRandFloat(0.40,0.60);
//				else
//					endLocY = rmRandFloat(0.30,0.70);
			}
		}

	//		whereTRstart = 1;	// for testing
	//		whereTRend = 1;		// for testing
			rmEchoInfo("trade route start = "+whereTRstart);
			rmEchoInfo("trade route end = "+whereTRend);

	//		startLocX = 1;		// for testing
	//		startLocY = 1;		// for testing
	//		endLocX = 1;		// for testing
	//		endLocY = 1;		// for testing
			rmEchoInfo("tr start loc x = "+startLocX);
			rmEchoInfo("tr start loc y = "+startLocY);
			rmEchoInfo("tr end loc x = "+endLocX);
			rmEchoInfo("tr end loc y = "+endLocY);

		if (tpVariation == 1)	// big circle
		{
			if (riverExists != 1 || riverPosition <= 5)
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.08, 0.55);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.20, 0.83, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.93, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.67, 0.89, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.87, 0.70, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.90, 0.45, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.85, 0.30, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.70, 0.10, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.50, 0.08, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.30, 0.13, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.15, 0.25, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.08, 0.55, 3, 8); 
			}
			else if (riverExists == 1 && riverPosition == 8)
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.90, 0.45); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.85, 0.30, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.70, 0.10, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.50, 0.08, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.30, 0.13, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.15, 0.25, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.08, 0.55, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.20, 0.83, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.93, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.67, 0.89, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.87, 0.70, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.90, 0.45, 3, 8);
			}
			else if (riverExists == 1 && riverPosition != 6)
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.67, 0.89); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.87, 0.70, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.90, 0.45, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.85, 0.30, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.70, 0.10, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.50, 0.08, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.30, 0.13, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.15, 0.25, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.08, 0.55, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.20, 0.83, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.93, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.67, 0.89, 3, 8); 
			}
			else
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.20, 0.83); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.45, 0.93, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.67, 0.89, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.87, 0.70, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.90, 0.45, 3, 8);
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.85, 0.30, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.70, 0.10, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.50, 0.08, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.30, 0.13, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.15, 0.25, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.08, 0.55, 3, 8); 
				rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.20, 0.83, 3, 8); 
			}
		}
		else if (tpVariation == 2)
		{
			int randomShaper = rmRandInt(1,2);	// small circle or square
			if (randomShaper == 1)	// square
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.35); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.35); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.65); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
			}
			else	// small circle
			{
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.70, 0.50); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.35); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.30); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.35); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.50); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.35, 0.65); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.70); 
				rmAddTradeRouteWaypoint(tradeRouteID, 0.65, 0.65);
			}
		}
		else
		{
			rmAddTradeRouteWaypoint(tradeRouteID, startLocX, startLocY);
		//	if (riverExists == 1)
		//	{
		//		rmAddTradeRouteWaypoint(tradeRouteID, 0.50, 0.50);
		//		rmAddTradeRouteWaypoint(tradeRouteID, endLocX, endLocY);
		//	}
			rmAddRandomTradeRouteWaypoints(tradeRouteID, 0.50, 0.50, 8, 12); 
			rmAddRandomTradeRouteWaypoints(tradeRouteID, endLocX, endLocY, 8, 12); 
		}
	    rmBuildTradeRoute(tradeRouteID, toiletPaper);
	}

//	rmClearClosestPointConstraints();

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 0.80);
	else if (trollBar == 1)
	   rmSetStatusText("", 0.9);
	else
		rmSetStatusText("", 0.1);
   
	// ============= Big Island =============
	if(oceanRing == 1)
	{
		rmEchoInfo("ocean ring");
		if(oceanChance == 1)
			rogueMap = 0;
	}
   
	// ============= Split Islands =============
	if(splitIsland == 1)
	{
		rmEchoInfo("split islands");
		rogueMap = 0;
	}

	// ============= Land Only =============
	if(landOnly == 1)
	{
		rmEchoInfo("just land no water");
	}

	// ============= River Across Middle =============
	int unknownRiver = -1;

	if(riverExists == 1)
	{
		rogueMap = 0;
		if (riverWidthController == 1)	// narrow river
			unknownRiver = rmRiverCreate(-1, riverName, 7, 10, 5, 8);
		else
			unknownRiver = rmRiverCreate(-1, riverName, 7, 10, 12, 18);

		// Spin river randomly around the edge		
		if(riverPosition == 1)
			rmRiverSetConnections(unknownRiver, 0.0, 0.5, 1.0, 0.5);
		else if(riverPosition == 2)
			rmRiverSetConnections(unknownRiver, 0.0, 0.0, 1.0, 1.0);
		else if(riverPosition == 3)
			rmRiverSetConnections(unknownRiver, 0.5, 0.0, 0.5, 1.0);
		else if(riverPosition == 4)
			rmRiverSetConnections(unknownRiver, 0.0, 1.0, 1.0, 0.0);
		else if(riverPosition == 5)
			rmRiverSetConnections(unknownRiver, 0.0, 0.25, 1.0, 0.75);
		else if(riverPosition == 6)
			rmRiverSetConnections(unknownRiver, 0.0, 0.75, 1.0, 0.25);
		else if(riverPosition == 7)
			rmRiverSetConnections(unknownRiver, 0.25, 0.0, 0.75, 1.0);
		else
			rmRiverSetConnections(unknownRiver, 0.75, 0.0, 0.25, 1.0);
		if (riverWidthController == 1)	// amazonia style spawn when != 1
		{
			// River always has 3 shallows
			rmRiverSetShallowRadius(unknownRiver, rmRandInt(10, 12));
			rmRiverAddShallow(unknownRiver, 0.10); 
			rmRiverAddShallow(unknownRiver, 0.15); 
			rmRiverAddShallow(unknownRiver, 0.20); 

			rmRiverSetShallowRadius(unknownRiver, rmRandInt(10, 12));
			rmRiverAddShallow(unknownRiver, 0.5);

			rmRiverSetShallowRadius(unknownRiver, rmRandInt(10, 12));
			rmRiverAddShallow(unknownRiver, 0.80);
			rmRiverAddShallow(unknownRiver, 0.85);
			rmRiverAddShallow(unknownRiver, 0.90);
			// sometimes fully shallow
			if (fullShallow == 1)
			{
				rmRiverAddShallow(unknownRiver, 0.05);
				rmRiverAddShallow(unknownRiver, 0.10);
				rmRiverAddShallow(unknownRiver, 0.15);
				rmRiverAddShallow(unknownRiver, 0.20);
				rmRiverAddShallow(unknownRiver, 0.25);
				rmRiverAddShallow(unknownRiver, 0.30);
				rmRiverAddShallow(unknownRiver, 0.35);
				rmRiverAddShallow(unknownRiver, 0.40);
				rmRiverAddShallow(unknownRiver, 0.45);
				rmRiverAddShallow(unknownRiver, 0.50);
				rmRiverAddShallow(unknownRiver, 0.55);
				rmRiverAddShallow(unknownRiver, 0.60);
				rmRiverAddShallow(unknownRiver, 0.65);
				rmRiverAddShallow(unknownRiver, 0.70);
				rmRiverAddShallow(unknownRiver, 0.75);
				rmRiverAddShallow(unknownRiver, 0.80);
				rmRiverAddShallow(unknownRiver, 0.85);
				rmRiverAddShallow(unknownRiver, 0.90);
				rmRiverAddShallow(unknownRiver, 0.95);
			}
		}
		rmRiverSetBankNoiseParams(unknownRiver, 0.07, 2, 1.5, 10.0, 0.667, 3.0);
		if (rmRandFloat(0,1) <= 0.9)
			rmRiverBuild(unknownRiver);
	}

	// ============= Great Lakes Style Ocean =============
	if(oceanMiddle == 1)
	{
		if(oceanChance == 1)
		{
			rogueMap = 0;
			int lakeOfTheUnknown = rmCreateArea("big lake in middle");
			if (snowMap == 1 && rmRandFloat(0,1) <= 0.50)
			{
				frozenLake = 1;
				rmSetAreaMix(lakeOfTheUnknown, "great_lakes_ice");
				rmAddAreaToClass(lakeOfTheUnknown, pondClass);
				rmAddAreaToClass(lakeOfTheUnknown, classCliff);
				rmAddAreaToClass(lakeOfTheUnknown, classCanyon);
			}
			else
			{
				rmSetAreaWaterType(lakeOfTheUnknown, oceanName);
//				rmSetAreaReveal(lakeOfTheUnknown, 01);
			}
			if(sideBay == 1)
			{
				rmSetAreaSize(lakeOfTheUnknown, 0.10, 0.11);
				rmEchoInfo("largest lake");
			}
			else if(oceanOffCenter == 1)
			{
				rmSetAreaSize(lakeOfTheUnknown, 0.05, 0.06);
				rmEchoInfo("smallest lake");
			}
			else if(rmRandFloat(0,1) < 0.4)
			{
				rmSetAreaSize(lakeOfTheUnknown, 0.08, 0.10);
				rmEchoInfo("larger lake");
			}
			else
			{
				rmSetAreaSize(lakeOfTheUnknown, 0.06, 0.08);
				rmEchoInfo("smaller lake");
			}
			if (sideBay == 1)
			{
				if(bayPosition < 0.12)
					rmSetAreaLocation(lakeOfTheUnknown, 0.90, 0.90);
				else if(bayPosition < 0.24)
					rmSetAreaLocation(lakeOfTheUnknown, 0.95, 0.50);
				else if(bayPosition < 0.36)
					rmSetAreaLocation(lakeOfTheUnknown, 0.90, 0.10);
				else if(bayPosition < 0.48)
					rmSetAreaLocation(lakeOfTheUnknown, 0.50, 0.05);
				else if(bayPosition < 0.60)
					rmSetAreaLocation(lakeOfTheUnknown, 0.10, 0.10);
				else if(bayPosition < 0.72)
					rmSetAreaLocation(lakeOfTheUnknown, 0.05, 0.50);
				else if(bayPosition < 0.84)
					rmSetAreaLocation(lakeOfTheUnknown, 0.10, 0.90);
				else
					rmSetAreaLocation(lakeOfTheUnknown, 0.50, 0.95);
			}
			else
				rmSetAreaLocation(lakeOfTheUnknown, 0.5, 0.5);
	//		rmSetAreaSmoothDistance(lakeOfTheUnknown, 50);
			rmSetAreaCoherence(lakeOfTheUnknown, 0.666);
			rmAddAreaConstraint(lakeOfTheUnknown, avoidPlayersFar1);
			rmAddAreaConstraint(lakeOfTheUnknown, avoidTradeRoute);
			rmAddAreaConstraint(lakeOfTheUnknown, avoidTradeRouteSocket);
		}
		else if (oceanChance == 2)
		{
			if (rogueMap == 1)
			{
				// defined later
			}
			else if (volcanoMap == 1)
			{
				// ******************** Volcano **********************
				float volcPlaceX = 0.50;
				float volcPlaceY = 0.50;

				if (sideBay == 1)
				{
					if(bayPosition < 0.12)
					{
						volcPlaceX = 0.90;
						volcPlaceY = 0.90;
					}
					else if(bayPosition < 0.24)
					{
						volcPlaceX = 0.90;
						volcPlaceY = 0.50;
					}
					else if(bayPosition < 0.36)
					{
						volcPlaceX = 0.90;
						volcPlaceY = 0.10;
					}
					else if(bayPosition < 0.48)
					{
						volcPlaceX = 0.50;
						volcPlaceY = 0.10;
					}
					else if(bayPosition < 0.60)
					{
						volcPlaceX = 0.10;
						volcPlaceY = 0.10;
					}
					else if(bayPosition < 0.72)
					{
						volcPlaceX = 0.10;
						volcPlaceY = 0.50;
					}
					else if(bayPosition < 0.84)
					{
						volcPlaceX = 0.10;
						volcPlaceY = 0.90;
					}
					else
					{
						volcPlaceX = 0.50;
						volcPlaceY = 0.90;
					}
				}

				// Lava flows
				int lavaflowID = rmCreateTradeRoute();
				rmSetObjectDefTradeRouteID(lavaflowID);
				rmAddTradeRouteWaypoint(lavaflowID, volcPlaceX, volcPlaceY);
				rmAddTradeRouteWaypoint(lavaflowID, volcPlaceX+rmXTilesToFraction(15), volcPlaceY);

				bool placedLavaflowID = rmBuildTradeRoute(lavaflowID, "lava_flow");

				int lavaflowID2 = rmCreateTradeRoute();
				rmSetObjectDefTradeRouteID(lavaflowID2);
				rmAddTradeRouteWaypoint(lavaflowID2, volcPlaceX, volcPlaceY);
				rmAddTradeRouteWaypoint(lavaflowID2, volcPlaceX, volcPlaceY+rmXTilesToFraction(15));

				bool placedLavaflowID2 = rmBuildTradeRoute(lavaflowID2, "lava_flow");

				int lavaflowID3 = rmCreateTradeRoute();
				rmSetObjectDefTradeRouteID(lavaflowID3);
				rmAddTradeRouteWaypoint(lavaflowID3, volcPlaceX, volcPlaceY);
				rmAddTradeRouteWaypoint(lavaflowID3, volcPlaceX-rmXTilesToFraction(15), volcPlaceY);

				bool placedLavaflowID3 = rmBuildTradeRoute(lavaflowID3, "lava_flow");

				int lavaflowID4 = rmCreateTradeRoute();
				rmSetObjectDefTradeRouteID(lavaflowID4);
				rmAddTradeRouteWaypoint(lavaflowID4, volcPlaceX, volcPlaceY);
				rmAddTradeRouteWaypoint(lavaflowID4, volcPlaceX, volcPlaceY-rmXTilesToFraction(15));

				bool placedLavaflowID4 = rmBuildTradeRoute(lavaflowID4, "lava_flow");

				int volcanoX = rmCreateObjectDef("volcano X coordinate");
				rmAddObjectDefItem(volcanoX, "zpSPCWaterSpawnPoint", 1, 0);
				rmSetObjectDefAllowOverlap(volcanoX, true);

				int volcanoZ = rmCreateObjectDef("volcano Z coordinate");
				rmAddObjectDefItem(volcanoZ, "zpSPCWaterSpawnPoint", 1, 0);
				rmSetObjectDefAllowOverlap(volcanoZ, true);

				vector coordinateLoc1  = rmGetTradeRouteWayPoint(lavaflowID, 0.1);
				vector coordinateLoc2  = rmGetTradeRouteWayPoint(lavaflowID2, 0.1);
				rmPlaceObjectDefAtPoint(volcanoX, 0, coordinateLoc1);
				rmPlaceObjectDefAtPoint(volcanoZ, 0, coordinateLoc2);

				vector volcanoVectorX = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(volcanoZ, 0));
				vector volcanoVectorZ = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(volcanoX, 0));

				float volcLocX = rmXMetersToFraction(xsVectorGetX(volcanoVectorX));
				float volcLocY = rmZMetersToFraction(xsVectorGetZ(volcanoVectorZ));

				// Build the volcano
				int volcanoID = -1;
				int volcanoTerrainID = -1;

				for (i= 0; < 22)
				{
					volcanoID = rmCreateArea("building the volcano"+i);
					if (i <= 1)			// base cliffs
					{
						if (i == 0)		// level 1
						{
							if (cNumberNonGaiaPlayers <= 2)
								rmSetAreaSize(volcanoID, rmAreaTilesToFraction(2000));
							else
								rmSetAreaSize(volcanoID, rmAreaTilesToFraction(2500));
							rmSetAreaCoherence(volcanoID, .6);
							rmSetAreaCliffType(volcanoID, volcCliffLow);
							rmSetAreaCliffEdge(volcanoID, 4, 0.16, 0.0, 0.0, 2); 
							rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
						}
						else			// level 2
						{
							rmSetAreaSize(volcanoID, rmAreaTilesToFraction(1600));
							rmSetAreaCoherence(volcanoID, .7);
							rmSetAreaCliffType(volcanoID, volcCliffLow);
							rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
							rmSetAreaTerrainType(volcanoID, volcTerrainLow);
							rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
							rmSetAreaCliffHeight(volcanoID, 4, 0.1, 0.5);
							rmAddAreaToClass(volcanoID, classCliff);
						}
						rmSetAreaHeightBlend(volcanoID, 0);
						rmSetAreaElevationVariation(volcanoID, 4);
						rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
						rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
					}
					else if (i == 2)	// level 3
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(900));
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaBaseHeight(volcanoID, 10);
						rmSetAreaHeightBlend(volcanoID, 2);
						rmSetAreaSmoothDistance(volcanoID, 50);
						rmSetAreaCoherence(volcanoID, .7);
						rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
					}
					else if (i <= 6)	// level 3 cliffs
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(160));
						rmSetAreaElevationVariation(volcanoID, 5);
						rmSetAreaCoherence(volcanoID, .6);
						rmSetAreaHeightBlend(volcanoID, 0);
						rmSetAreaCliffType(volcanoID, volcCliffMid);
						rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
						rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
						rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
						if (i == 3)
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
						else if (i == 4)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
						else if (i == 5)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
						else
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
					}
					else if (i == 7)	// level 4
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(550));
						rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaBaseHeight(volcanoID, 14);
						rmSetAreaHeightBlend(volcanoID, 2);
						rmSetAreaSmoothDistance(volcanoID, 40);
						rmSetAreaCoherence(volcanoID, .8);
					}
					else if (i <= 11)	// level 4 cliffs
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
						rmSetAreaElevationVariation(volcanoID, 5);
						rmSetAreaCoherence(volcanoID, .6);
						rmSetAreaHeightBlend(volcanoID, 0);
						rmSetAreaCliffType(volcanoID, volcCliffHigh);
						rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
						rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
						rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
						if (i == 8)
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
						else if (i == 9)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
						else if (i == 10)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
						else
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
					}
					else if (i == 12)	// level 5
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(450));
						rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaBaseHeight(volcanoID, 18);
						rmSetAreaSmoothDistance(volcanoID, 40);
						rmSetAreaHeightBlend(volcanoID, 2);
						rmSetAreaCoherence(volcanoID, .8);
					}
					else if (i <= 16)	// peak
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(20));
						rmSetAreaElevationVariation(volcanoID, 5);
						rmSetAreaCoherence(volcanoID, .6);
						rmSetAreaHeightBlend(volcanoID, 0);
						rmSetAreaCliffType(volcanoID, volcCliffHigh);
						rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
						rmSetAreaTerrainType(volcanoID, volcTerrainLow);
						rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
						rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
						rmSetAreaCliffHeight(volcanoID, 2, 0.1, 0.5);
						rmSetAreaElevationVariation(volcanoID, 3);
						if (i == 13)
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(5), volcLocY-rmXTilesToFraction(5));
						else if (i == 14)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(5), volcLocY-rmXTilesToFraction(5));
						else if (i == 15)
							rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(5), volcLocY+rmXTilesToFraction(5));
						else
							rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(5), volcLocY+rmXTilesToFraction(5));
					}
					else if (i <= 20)	// dip
					{
						if (i == 17)
						{
							rmSetAreaSize(volcanoID, rmAreaTilesToFraction(120));
							rmSetAreaTerrainType(volcanoID, volcTerrainCrater);
							rmSetAreaBaseHeight(volcanoID, 22);
							rmSetAreaCoherence(volcanoID, 0.9);
						}
						else if (i == 18)
						{
							rmSetAreaSize(volcanoID, rmAreaTilesToFraction(230));
							rmSetAreaTerrainType(volcanoID, volcTerrainCrater);
							rmSetAreaCoherence(volcanoID, 1);
						}
						else if (i == 19)
						{
							rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
							rmSetAreaCliffType(volcanoID, volcCliffCrater);
							rmSetAreaCliffPainting(volcanoID, false, true, true, 1.5, false);
							rmSetAreaCliffHeight(volcanoID, -5, 0.1, 0.5);
							rmSetAreaCliffEdge(volcanoID, 1, 1.0, 0.0, 1.0, 0);
							rmSetAreaCoherence(volcanoID, 1);
						}
						else
						{
							rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
							rmSetAreaTerrainType(volcanoID, volcTerrainCraterPass);
							rmSetAreaCoherence(volcanoID, 1);
						}
						rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
					}
					else	// lava
					{
						rmSetAreaSize(volcanoID, rmAreaTilesToFraction(25));
						rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(1), volcLocY);
						rmSetAreaTerrainType(volcanoID, volcTerrainLava);
						rmSetAreaCoherence(volcanoID, 1);
					}
					rmAddAreaToClass(volcanoID, pondClass);
					rmAddAreaToClass(volcanoID, classCliff);
					rmAddAreaToClass(volcanoID, classCanyon);
					rmSetAreaWarnFailure(volcanoID, false);
					rmSetAreaObeyWorldCircleConstraint(volcanoID, false);
					rmAddAreaConstraint(volcanoID, avoidTradeRouteSocket);
					rmAddAreaConstraint(volcanoID, avoidPlayersFar1);
					rmBuildArea(volcanoID);
				
					volcanoTerrainID = rmCreateArea("painting the volcano"+i); 
					if (i == 0)
					{
						rmSetAreaSize(volcanoTerrainID, 0.025);
						rmSetAreaCoherence(volcanoTerrainID, 0.6);
						rmSetAreaMix(volcanoTerrainID, landName);
					}
					else if (i == 1)
					{
						rmSetAreaSize(volcanoTerrainID, rmAreaTilesToFraction(1500));
						rmSetAreaCoherence(volcanoTerrainID, 1);
						rmSetAreaTerrainType(volcanoTerrainID, volcTerrainLow);
					}
					else if (i == 2)
					{
						rmSetAreaSize(volcanoTerrainID, rmAreaTilesToFraction(700));
						rmSetAreaCoherence(volcanoTerrainID, 0.8);
						rmSetAreaTerrainType(volcanoTerrainID, volcTerrainHigh);
					}
					rmSetAreaLocation(volcanoTerrainID, volcLocX, volcLocY);
					rmSetAreaObeyWorldCircleConstraint(volcanoTerrainID, false);
					if (i <= 2)
						rmBuildArea(volcanoTerrainID);
				}
			
				// Volcano crater
				int volcanoCraterID = rmCreateGrouping("crater", "volcano_crater_noground");
				rmPlaceGroupingAtLoc(volcanoCraterID, 1, volcLocX-rmXTilesToFraction(1), volcLocY, 1);
			
				int volcanoControllerID = rmCreateObjectDef("volcano controller 1");
				rmAddObjectDefItem(volcanoControllerID, "zpSPCWaterSpawnPoint", 1, 0);
				rmPlaceObjectDefAtLoc(volcanoControllerID, 0, volcLocX, volcLocY);
			
				int volcanoAvoider = rmCreateObjectDef("ai avoider"); 
				if (cNumberNonGaiaPlayers <= 2)
				    rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderS", 1, 0);
				else if(cNumberNonGaiaPlayers <= 4)
					rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderM", 1, 0);
				else if(cNumberNonGaiaPlayers <= 6)
					rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderL", 1, 0);
				else
					rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderXL", 1, 0);
				rmPlaceObjectDefAtLoc(volcanoAvoider, 0, volcLocX, volcLocY);
			}
			else
			{
				int mountID = rmCreateArea("central mountain");
				rmSetAreaSize(mountID, 0.04, 0.06); 
				rmSetAreaWarnFailure(mountID, false);
				rmSetAreaObeyWorldCircleConstraint(mountID, true);
				rmSetAreaCliffType(mountID, cliffName); 
				rmSetAreaTerrainType(mountID, "cave\cave_ground5");
				if (rmRandFloat(0,1) <= 0.50 || floodedLand == 1 || riverExists == 1)
				rmSetAreaCliffHeight(mountID, rmRandInt(5,10), 4.0, 0.8);
				else
					rmSetAreaCliffHeight(mountID, rmRandInt(-5,-10), 4.0, 0.8);
				rmSetAreaCliffEdge(mountID, 1, 1.00, 0.0, 1.0, 1);
				rmSetAreaCoherence(mountID, 0.69);
				rmAddAreaToClass(mountID, pondClass);
				rmAddAreaToClass(mountID, classCliff);
				rmAddAreaToClass(mountID, classCanyon);
				rmSetAreaReveal(mountID, 01);
				if (sideBay == 1)
				{
					if(bayPosition < 0.12)
						rmSetAreaLocation(mountID, 1.0, 1.0);
					else if(bayPosition < 0.24)
						rmSetAreaLocation(mountID, 1.0, 0.5);
					else if(bayPosition < 0.36)
						rmSetAreaLocation(mountID, 1.0, 0.0);
					else if(bayPosition < 0.48)
						rmSetAreaLocation(mountID, 0.5, 0.0);
					else if(bayPosition < 0.60)
						rmSetAreaLocation(mountID, 0.0, 0.0);
					else if(bayPosition < 0.72)
						rmSetAreaLocation(mountID, 0.0, 0.5);
					else if(bayPosition < 0.84)
						rmSetAreaLocation(mountID, 0.0, 1.0);
					else
						rmSetAreaLocation(mountID, 0.5, 1.0);
				}
				else
					rmSetAreaLocation(mountID, 0.5, 0.5);
				rmAddAreaConstraint(mountID, avoidTradeRoute);
				rmAddAreaConstraint(mountID, avoidTradeRouteSocketShort);
				rmAddAreaConstraint(mountID, avoidPlayersFar1);
				rmBuildArea(mountID);

				int stayInMountain = rmCreateAreaMaxDistanceConstraint("stay in mount", mountID, 0.0);
				int stayNearMountain = rmCreateAreaMaxDistanceConstraint("stay near mount", mountID, 3.0);
				int avoidRampsMountain = rmCreateCliffRampDistanceConstraint("avoid mount ramps", mountID, 4.0);

				int mountPaintID = rmCreateArea("mount paint");
				rmSetAreaSize(mountPaintID, 0.14); 
				rmSetAreaMix(mountPaintID, landName);
				rmSetAreaCoherence(mountPaintID, 0.999);
				if (sideBay == 1)
				{
					if(bayPosition < 0.12)
						rmSetAreaLocation(mountPaintID, 1.0, 1.0);
					else if(bayPosition < 0.24)
						rmSetAreaLocation(mountPaintID, 1.0, 0.5);
					else if(bayPosition < 0.36)
						rmSetAreaLocation(mountPaintID, 1.0, 0.0);
					else if(bayPosition < 0.48)
						rmSetAreaLocation(mountPaintID, 0.5, 0.0);
					else if(bayPosition < 0.60)
						rmSetAreaLocation(mountPaintID, 0.0, 0.0);
					else if(bayPosition < 0.72)
						rmSetAreaLocation(mountPaintID, 0.0, 0.5);
					else if(bayPosition < 0.84)
						rmSetAreaLocation(mountPaintID, 0.0, 1.0);
					else
						rmSetAreaLocation(mountPaintID, 0.5, 1.0);
				}
				else
					rmSetAreaLocation(mountPaintID, 0.50, 0.50);
				rmAddAreaConstraint(mountPaintID, stayNearMountain);
				rmBuildArea(mountPaintID);
			}
		}
		else if (oceanChance == 3)
		{
			if (rogueMap == 1)
			{
				// defined later
			}
			else
			{
				int caveID = rmCreateArea("cave");
				rmSetAreaSize(caveID, 0.10, 0.13); 
				rmSetAreaWarnFailure(caveID, false);
				rmSetAreaObeyWorldCircleConstraint(caveID, true);
				rmSetAreaCliffType(caveID, "cave"); 
				rmSetAreaTerrainType(caveID, "cave\cave_ground5");
				if (floodedLand == 1)
					rmSetAreaCliffHeight(caveID, 4, 1.0, 0.8);
				else
					rmSetAreaCliffHeight(caveID, -6, 1.0, 0.8);
				rmSetAreaCliffEdge(caveID, 6, 0.07, 0.0, 1.0, 1);
				rmSetAreaCoherence(caveID, 0.69);
				rmAddAreaToClass(caveID, classCanyon);
				rmSetAreaSmoothDistance(caveID, 6);
				rmSetAreaReveal(caveID, 01);
				if (sideBay == 1)
				{
					if(bayPosition < 0.12)
						rmSetAreaLocation(caveID, 1.0, 1.0);
					else if(bayPosition < 0.24)
						rmSetAreaLocation(caveID, 1.0, 0.5);
					else if(bayPosition < 0.36)
						rmSetAreaLocation(caveID, 1.0, 0.0);
					else if(bayPosition < 0.48)
						rmSetAreaLocation(caveID, 0.5, 0.0);
					else if(bayPosition < 0.60)
						rmSetAreaLocation(caveID, 0.0, 0.0);
					else if(bayPosition < 0.72)
						rmSetAreaLocation(caveID, 0.0, 0.5);
					else if(bayPosition < 0.84)
						rmSetAreaLocation(caveID, 0.0, 1.0);
					else
						rmSetAreaLocation(caveID, 0.5, 1.0);
				}
				else
					rmSetAreaLocation(caveID, 0.50, 0.50);
				rmAddAreaConstraint(caveID, avoidTradeRoute);
				rmAddAreaConstraint(caveID, avoidTradeRouteSocketShort);
				rmAddAreaConstraint(caveID, avoidPlayersFar1);
				rmBuildArea(caveID);

				int stayInCave = rmCreateAreaMaxDistanceConstraint("stay in cave", caveID, 0.0);
				int stayNearCave = rmCreateAreaMaxDistanceConstraint("stay near cave", caveID, 3.0);
				int avoidRamps = rmCreateCliffRampDistanceConstraint("avoid cave ramps", caveID, 4.0);

				int cavePaintID = rmCreateArea("cave paint");
				rmSetAreaSize(cavePaintID, 0.17); 
				rmSetAreaMix(cavePaintID, "caves2");
				rmSetAreaCoherence(cavePaintID, 0.999);
				if (sideBay == 1)
				{
					if(bayPosition < 0.12)
						rmSetAreaLocation(cavePaintID, 1.0, 1.0);
					else if(bayPosition < 0.24)
						rmSetAreaLocation(cavePaintID, 1.0, 0.5);
					else if(bayPosition < 0.36)
						rmSetAreaLocation(cavePaintID, 1.0, 0.0);
					else if(bayPosition < 0.48)
						rmSetAreaLocation(cavePaintID, 0.5, 0.0);
					else if(bayPosition < 0.60)
						rmSetAreaLocation(cavePaintID, 0.0, 0.0);
					else if(bayPosition < 0.72)
						rmSetAreaLocation(cavePaintID, 0.0, 0.5);
					else if(bayPosition < 0.84)
						rmSetAreaLocation(cavePaintID, 0.0, 1.0);
					else
						rmSetAreaLocation(cavePaintID, 0.5, 1.0);
				}
				else
					rmSetAreaLocation(cavePaintID, 0.50, 0.50);
				rmAddAreaConstraint(cavePaintID, stayNearCave);
				rmBuildArea(cavePaintID);

				int stayNearCaveCliff = -1;

				for (i=0; <6+3*cNumberNonGaiaPlayers)
				{
					int caveCliffID = rmCreateArea("cave cliff"+i);
					rmSetAreaSize(caveCliffID, 0.001, 0.002);
					rmSetAreaCliffType(caveCliffID, "cave");  
					rmSetAreaTerrainType(caveCliffID, "cave\cave_top_a_passable");
					rmAddAreaToClass(caveCliffID, classCliff);
					rmSetAreaCliffHeight(caveCliffID, 6, 2.0, 0.4);
					rmSetAreaCliffEdge(caveCliffID, 1, 1.0, 0.0, 0.0, 1);
					rmSetAreaCoherence(caveCliffID, 0.69);
					rmAddAreaConstraint(caveCliffID, stayInCave);
					rmAddAreaConstraint(caveCliffID, shortAvoidImpassableLand);
					rmAddAreaConstraint(caveCliffID, avoidRamps);
					rmAddAreaConstraint(caveCliffID, avoidCliffs);
					rmBuildArea(caveCliffID);

					stayNearCaveCliff = rmCreateAreaMaxDistanceConstraint("stay near cave cliff"+i, caveCliffID, 4.0);

					int paintCliffID = rmCreateArea("paint cliff"+i);
					rmSetAreaSize(paintCliffID, 0.004);
					rmSetAreaTerrainType(paintCliffID, "cave\cave_top");
					rmSetAreaCoherence(paintCliffID, 0.999);
					rmAddAreaConstraint(paintCliffID, stayNearCaveCliff);
					rmBuildArea(paintCliffID);
				}

				// mineralz spawn in cave
				if (rmRandFloat(0,1) <= 0.05)
				{
					for (i=0; < 2*cNumberNonGaiaPlayers)
					{
						int rushMineCaveID = rmCreateObjectDef("mineral rush cave"+i);
						rmAddObjectDefItem(rushMineCaveID, mineralz, 1, 1.0);
						rmSetObjectDefMinDistance(rushMineCaveID, 0.0);
						rmSetObjectDefMaxDistance(rushMineCaveID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(rushMineCaveID, classGold);
						rmAddObjectDefConstraint(rushMineCaveID, stayInCave);
						rmAddObjectDefConstraint(rushMineCaveID, shortAvoidImpassableLand);
						rmAddObjectDefConstraint(rushMineCaveID, avoidAll);
						rmAddObjectDefConstraint(rushMineCaveID, avoidTradeRouteSocketShort);
						rmAddObjectDefConstraint(rushMineCaveID, avoidGoldShort);
						rmPlaceObjectDefAtLoc(rushMineCaveID, 0, 0.50, 0.50, 1);
					}			
				}
			}
		}
		else if (oceanChance == 4)
		{
			int plateauID = rmCreateArea("central plateau");
			rmSetAreaSize(plateauID, 0.09, 0.11); 
			rmSetAreaWarnFailure(plateauID, false);
			rmSetAreaObeyWorldCircleConstraint(plateauID, true);
			rmSetAreaCliffType(plateauID, cliffName); 
			rmSetAreaTerrainType(plateauID, "cave\cave_ground5");
			if (rmRandFloat(0,1) <= 0.50 || floodedLand == 1 || riverExists == 1)
				rmSetAreaCliffHeight(plateauID, 6, 2.0, 0.8);
			else
				rmSetAreaCliffHeight(plateauID, -6, 2.0, 0.8);
			rmSetAreaCliffEdge(plateauID, 6, 0.07, 0.0, 1.0, 1);
			rmSetAreaCoherence(plateauID, 0.69);
			rmAddAreaToClass(plateauID, classCanyon);
			rmSetAreaSmoothDistance(plateauID, 6);
			if (sideBay == 1)
			{
				if(bayPosition < 0.12)
					rmSetAreaLocation(plateauID, 1.0, 1.0);
				else if(bayPosition < 0.24)
					rmSetAreaLocation(plateauID, 1.0, 0.5);
				else if(bayPosition < 0.36)
					rmSetAreaLocation(plateauID, 1.0, 0.0);
				else if(bayPosition < 0.48)
					rmSetAreaLocation(plateauID, 0.5, 0.0);
				else if(bayPosition < 0.60)
					rmSetAreaLocation(plateauID, 0.0, 0.0);
				else if(bayPosition < 0.72)
					rmSetAreaLocation(plateauID, 0.0, 0.5);
				else if(bayPosition < 0.84)
					rmSetAreaLocation(plateauID, 0.0, 1.0);
				else
					rmSetAreaLocation(plateauID, 0.5, 1.0);
			}
			else
				rmSetAreaLocation(plateauID, 0.50, 0.50);
			rmAddAreaConstraint(plateauID, avoidTradeRoute);
			rmAddAreaConstraint(plateauID, avoidTradeRouteSocketShort);
			rmAddAreaConstraint(plateauID, avoidPlayersFar1);
			rmBuildArea(plateauID);

			int stayInPlateau = rmCreateAreaMaxDistanceConstraint("stay in plateau", plateauID, 0.0);
			int stayNearPlateau = rmCreateAreaMaxDistanceConstraint("stay near plateau", plateauID, 3.0);
			int avoidRampsPlateau = rmCreateCliffRampDistanceConstraint("avoid plateau ramps", plateauID, 4.0);

			int plateauPaintID = rmCreateArea("plateau paint");
			rmSetAreaSize(plateauPaintID, 0.14); 
			rmSetAreaMix(plateauPaintID, landName);
			rmSetAreaCoherence(plateauPaintID, 0.999);
			if (sideBay == 1)
			{
				if(bayPosition < 0.12)
					rmSetAreaLocation(plateauPaintID, 0.99, 0.99);
				else if(bayPosition < 0.24)
					rmSetAreaLocation(plateauPaintID, 0.99, 0.50);
				else if(bayPosition < 0.36)
					rmSetAreaLocation(plateauPaintID, 0.99, 0.01);
				else if(bayPosition < 0.48)
					rmSetAreaLocation(plateauPaintID, 0.50, 0.01);
				else if(bayPosition < 0.60)
					rmSetAreaLocation(plateauPaintID, 0.01, 0.01);
				else if(bayPosition < 0.72)
					rmSetAreaLocation(plateauPaintID, 0.01, 0.50);
				else if(bayPosition < 0.84)
					rmSetAreaLocation(plateauPaintID, 0.01, 0.99);
				else
					rmSetAreaLocation(plateauPaintID, 0.50, 0.99);
			}
			else
				rmSetAreaLocation(plateauPaintID, 0.50, 0.50);
			rmAddAreaConstraint(plateauPaintID, stayNearPlateau);
			rmBuildArea(plateauPaintID);

			if (rogueMap == 1)
			{
				// defined later
			}
			else if (rmRandFloat(0,1) <= 0.69)
			{
				for (i=0; <2+4*cNumberNonGaiaPlayers)
				{
    				int plateauForestID = rmCreateArea("plateau forest "+i);
    				rmSetAreaWarnFailure(plateauForestID, false);
    				rmSetAreaObeyWorldCircleConstraint(plateauForestID, true);
    				rmSetAreaSize(plateauForestID, rmAreaTilesToFraction(111));
					if (rmRandFloat(0,1) <= 0.01)
						rmSetAreaTerrainType(plateauForestID, "texas\nonpassable_temp"); 
					else
					{
    					if (rmRandFloat(0,1) <= 0.001)
							rmSetAreaForestType(plateauForestID, "unknown forest funky");
    					else 
							rmSetAreaForestType(plateauForestID, forestName);
						if (trollMap == 1)
						{
							rmSetAreaForestDensity(plateauForestID, 0.99);
							rmSetAreaForestClumpiness(plateauForestID, 0.99);
							rmSetAreaForestUnderbrush(plateauForestID, 0.99);
						}
						else
						{
							rmSetAreaForestDensity(plateauForestID, 0.8);
							rmSetAreaForestClumpiness(plateauForestID, 0.8);
							rmSetAreaForestUnderbrush(plateauForestID, 0.3);
						}
					}
    				rmSetAreaCoherence(plateauForestID, 0.5);
    				rmSetAreaSmoothDistance(plateauForestID, 0);
    				rmAddAreaToClass(plateauForestID, rmClassID("classForest")); 
    				rmAddAreaConstraint(plateauForestID, forestConstraint);
    				rmAddAreaConstraint(plateauForestID, avoidPlayers);
    				rmAddAreaConstraint(plateauForestID, stayInPlateau);
    				rmAddAreaConstraint(plateauForestID, avoidRampsPlateau);
    				rmAddAreaConstraint(plateauForestID, avoidAll);
					if (floodedLand != 1)
	    				rmAddAreaConstraint(plateauForestID, shortAvoidImpassableLand); 
    				rmAddAreaConstraint(plateauForestID, avoidTradeRoute);
    				rmAddAreaConstraint(plateauForestID, avoidGoldMin);
    				rmAddAreaConstraint(plateauForestID, avoidTradeRouteSocketShort);

    				if(rmBuildArea(plateauForestID)==false)
    				{
    				   // Stop trying once we fail 3 times in a row.
    				   failCount++;
    				   if(failCount==5)
    				      break;
    				}
    				else
    				   failCount=0; 
				}
			}
			else
			{
				float someMoreRNG = rmRandFloat(0,1);	// additional RNG for fun stuff

				for (i=0; < cNumberNonGaiaPlayers)
				{
					int plateauPropsID = rmCreateObjectDef("plateau props"+i);
					if (rmRandFloat(0,1) <= 0.69)
					{
						rmAddObjectDefItem(plateauPropsID, propz, 4, 6.0);
					}
					else if (someMoreRNG <= 0.69)
					{
						if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauPropsID, "ypMercFlailiphantMansabdar", 10, 8.0);
						else if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauPropsID, "ypShogunTokugawa", 10, 8.0);
						else if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauPropsID, "deMercGatlingCamel", 10, 8.0);
						else
							rmAddObjectDefItem(plateauPropsID, "BerryBush", 10, 8.0);
					}
					else
						rmAddObjectDefItem(plateauPropsID, "deRMFoodMill", 1, 1.0);
					rmSetObjectDefMinDistance(plateauPropsID, 0.0);
					rmSetObjectDefMaxDistance(plateauPropsID, rmXFractionToMeters(0.50));
					rmAddObjectDefToClass(plateauPropsID, classGold);
					rmAddObjectDefConstraint(plateauPropsID, avoidEdge);
					rmAddObjectDefConstraint(plateauPropsID, avoidGold);
    				rmAddObjectDefConstraint(plateauPropsID, stayInPlateau);
    				rmAddObjectDefConstraint(plateauPropsID, avoidRampsPlateau);
					if (floodedLand != 1)
						rmAddObjectDefConstraint(plateauPropsID, shortAvoidImpassableLand); 
					rmPlaceObjectDefAtLoc(plateauPropsID, 0, 0.50, 0.50, 1);
				}
			}
		}
		else
		{
			// just land
			blockedMiddle = -1;
		}
	}	// Build the lake later to avoid players

	// ============= Saguenay Style Ocean =============
	if(oceanOffCenter == 1)
	{
		if (bayChance == 1)
		{
			int unknownBay = rmCreateArea("big bay on edge");
				if (snowMap == 1 && rmRandFloat(0,1) <= 0.50)
					rmSetAreaMix(unknownBay, "great_lakes_ice");
				else
				{
					rmSetAreaWaterType(unknownBay, oceanName);
//					rmSetAreaReveal(unknownBay, 01);
				}
			rmSetAreaWarnFailure(unknownBay, false);
			if (oceanMiddle == 1)
				rmSetAreaSize(unknownBay, 0.11, 0.13);
			else
				rmSetAreaSize(unknownBay, 0.13, 0.15);

			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(unknownBay, 0.10, 0.10);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(unknownBay, 0.05, 0.50);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(unknownBay, 0.10, 0.90);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(unknownBay, 0.50, 0.95);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(unknownBay, 0.90, 0.90);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(unknownBay, 0.95, 0.50);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(unknownBay, 0.90, 0.10);
			else
				rmSetAreaLocation(unknownBay, 0.50, 0.05);
		   	rmSetAreaCoherence(unknownBay, 0.666);
	  		rmSetAreaObeyWorldCircleConstraint(unknownBay, false);
			rmAddAreaConstraint(unknownBay, avoidPlayersFar1);
			rmAddAreaConstraint(unknownBay, avoidTradeRoute);
			rmAddAreaConstraint(unknownBay, avoidTradeRouteSocket);
		}
		else if (bayChance == 2)
		{
			int mountSideID = rmCreateArea("side mountain");
			rmSetAreaSize(mountSideID, 0.06, 0.09); 
			rmSetAreaWarnFailure(mountSideID, false);
			rmSetAreaObeyWorldCircleConstraint(mountSideID, true);
			rmSetAreaCliffType(mountSideID, cliffName); 
			rmSetAreaTerrainType(mountSideID, "cave\cave_ground5");
			if (rmRandFloat(0,1) <= 0.50 || floodedLand == 1 || riverExists == 1)
				rmSetAreaCliffHeight(mountSideID, rmRandInt(5,10), 4.0, 0.8);
			else
				rmSetAreaCliffHeight(mountSideID, rmRandInt(-5,-10), 4.0, 0.8);
			rmSetAreaCliffEdge(mountSideID, 1, 1.00, 0.0, 1.0, 1);
			rmSetAreaCoherence(mountSideID, 0.69);
			rmSetAreaReveal(mountSideID, 01);
			rmAddAreaToClass(mountSideID, pondClass);
			rmAddAreaToClass(mountSideID, classCliff);
			rmAddAreaToClass(mountSideID, classCanyon);
			rmSetAreaReveal(mountSideID, 01);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(mountSideID, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(mountSideID, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(mountSideID, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(mountSideID, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(mountSideID, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(mountSideID, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(mountSideID, 1.0, 0.0);
			else
				rmSetAreaLocation(mountSideID, 0.5, 0.0);
			rmAddAreaConstraint(mountSideID, avoidTradeRoute);
			rmAddAreaConstraint(mountSideID, avoidTradeRouteSocketShort);
			rmAddAreaConstraint(mountSideID, avoidPlayersFar1);
			rmBuildArea(mountSideID);

			int stayInSideMountain = rmCreateAreaMaxDistanceConstraint("stay in side mount", mountSideID, 0.0);
			int stayNearSideMountain = rmCreateAreaMaxDistanceConstraint("stay near side mount", mountSideID, 3.0);
			int avoidRampsSideMountain = rmCreateCliffRampDistanceConstraint("avoid side mount ramps", mountSideID, 4.0);

			int mountSidePaintID = rmCreateArea("mount side paint");
			rmSetAreaSize(mountSidePaintID, 0.15); 
			rmSetAreaMix(mountSidePaintID, landName);
			rmSetAreaCoherence(mountSidePaintID, 0.999);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(mountSidePaintID, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(mountSidePaintID, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(mountSidePaintID, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(mountSidePaintID, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(mountSidePaintID, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(mountSidePaintID, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(mountSidePaintID, 1.0, 0.0);
			else
				rmSetAreaLocation(mountSidePaintID, 0.5, 0.0);
			rmAddAreaConstraint(mountSidePaintID, stayNearSideMountain);
			rmBuildArea(mountSidePaintID);
		}
		else if (bayChance == 3)
		{
			int caveSideID = rmCreateArea("side cave");
			if (oceanMiddle == 1)
				rmSetAreaSize(caveSideID, 0.09, 0.11); 
			else
				rmSetAreaSize(caveSideID, 0.11, 0.13); 
			rmSetAreaWarnFailure(caveSideID, false);
			rmSetAreaObeyWorldCircleConstraint(caveSideID, true);
			rmSetAreaCliffType(caveSideID, "cave"); 
			rmSetAreaTerrainType(caveSideID, "cave\cave_ground5");
			if (floodedLand == 1)
				rmSetAreaCliffHeight(caveSideID, 4, 1.0, 0.8);
			else
				rmSetAreaCliffHeight(caveSideID, -6, 1.0, 0.8);
			rmSetAreaCliffEdge(caveSideID, 6, 0.07, 0.0, 1.0, 0);
			rmSetAreaCoherence(caveSideID, 0.69);
			rmAddAreaToClass(caveSideID, classCanyon);
			rmSetAreaSmoothDistance(caveSideID, 6);
			rmSetAreaReveal(caveSideID, 01);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(caveSideID, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(caveSideID, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(caveSideID, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(caveSideID, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(caveSideID, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(caveSideID, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(caveSideID, 1.0, 0.0);
			else
				rmSetAreaLocation(caveSideID, 0.5, 0.0);
			rmAddAreaConstraint(caveSideID, avoidTradeRoute);
			rmAddAreaConstraint(caveSideID, avoidTradeRouteSocketShort);
			rmAddAreaConstraint(caveSideID, avoidPlayersFar1);
			rmBuildArea(caveSideID);

			int stayInSideCave = rmCreateAreaMaxDistanceConstraint("stay in side cave", caveSideID, 0.0);
			int stayNearSideCave = rmCreateAreaMaxDistanceConstraint("stay near side cave", caveSideID, 3.0);
			int avoidSideRamps = rmCreateCliffRampDistanceConstraint("avoid cave side ramps", caveSideID, 4.0);

			int caveSidePaintID = rmCreateArea("cave side paint");
			rmSetAreaSize(caveSidePaintID, 0.20); 
			rmSetAreaMix(caveSidePaintID, "caves2");
			rmSetAreaCoherence(caveSidePaintID, 0.999);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(caveSidePaintID, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(caveSidePaintID, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(caveSidePaintID, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(caveSidePaintID, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(caveSidePaintID, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(caveSidePaintID, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(caveSidePaintID, 1.0, 0.0);
			else
				rmSetAreaLocation(caveSidePaintID, 0.5, 0.0);
			rmAddAreaConstraint(caveSidePaintID, stayNearSideCave);
			rmBuildArea(caveSidePaintID);

			int stayNearSideCaveCliff = -1;

			for (i=0; <6+3*cNumberNonGaiaPlayers)
			{
				int caveSideCliffID = rmCreateArea("cave side cliff"+i);
				rmSetAreaSize(caveSideCliffID, 0.001, 0.002);
				rmSetAreaCliffType(caveSideCliffID, "cave");  
				rmSetAreaTerrainType(caveSideCliffID, "cave\cave_top_a_passable");
				rmAddAreaToClass(caveSideCliffID, classCliff);
				rmSetAreaCliffHeight(caveSideCliffID, 6, 2.0, 0.4);
				rmSetAreaCliffEdge(caveSideCliffID, 1, 1.0, 0.0, 0.0, 1);
				rmSetAreaCoherence(caveSideCliffID, 0.69);
				rmAddAreaConstraint(caveSideCliffID, stayInSideCave);
				rmAddAreaConstraint(caveSideCliffID, shortAvoidImpassableLand);
				rmAddAreaConstraint(caveSideCliffID, avoidSideRamps);
				rmAddAreaConstraint(caveSideCliffID, avoidCliffs);
				rmBuildArea(caveSideCliffID);

				stayNearSideCaveCliff = rmCreateAreaMaxDistanceConstraint("stay near side cave cliff"+i, caveSideCliffID, 4.0);

				int paintSideCliffID = rmCreateArea("paint side cliff"+i);
				rmSetAreaSize(paintSideCliffID, 0.004);
				rmSetAreaTerrainType(paintSideCliffID, "cave\cave_top");
				rmSetAreaCoherence(paintSideCliffID, 0.999);
				rmAddAreaConstraint(paintSideCliffID, stayNearSideCaveCliff);
				rmBuildArea(paintSideCliffID);
			}

			// mineralz spawn in cave
			if (rmRandFloat(0,1) <= 0.05)
			{
				for (i=0; < 2*cNumberNonGaiaPlayers)
				{
					int rushMineSideCaveID = rmCreateObjectDef("mineral rush side cave"+i);
					rmAddObjectDefItem(rushMineSideCaveID, mineralz, 1, 1.0);
					rmSetObjectDefMinDistance(rushMineSideCaveID, 0.0);
					rmSetObjectDefMaxDistance(rushMineSideCaveID, rmXFractionToMeters(0.50));
					rmAddObjectDefToClass(rushMineSideCaveID, classGold);
					rmAddObjectDefConstraint(rushMineSideCaveID, stayInSideCave);
					rmAddObjectDefConstraint(rushMineSideCaveID, shortAvoidImpassableLand);
					rmAddObjectDefConstraint(rushMineSideCaveID, avoidAll);
					rmAddObjectDefConstraint(rushMineSideCaveID, avoidTradeRouteSocketShort);
					rmAddObjectDefConstraint(rushMineSideCaveID, avoidGoldShort);
					rmPlaceObjectDefAtLoc(rushMineSideCaveID, 0, 0.50, 0.50, 1);
				}
			}
		}
		else if (bayChance == 4)
		{
			int plateauSideID = rmCreateArea("side plateau");
			if (oceanMiddle == 1)
				rmSetAreaSize(plateauSideID, 0.08, 0.10); 
			else
				rmSetAreaSize(plateauSideID, 0.09, 0.12); 
			rmSetAreaWarnFailure(plateauSideID, false);
			rmSetAreaObeyWorldCircleConstraint(plateauSideID, true);
			rmSetAreaCliffType(plateauSideID, cliffName); 
			rmSetAreaTerrainType(plateauSideID, "cave\cave_ground5");
			if (rmRandFloat(0,1) <= 0.50 || floodedLand == 1 || riverExists == 1)
				rmSetAreaCliffHeight(plateauSideID, 6, 2.0, 0.8);
			else
				rmSetAreaCliffHeight(plateauSideID, -6, 2.0, 0.8);
			rmSetAreaCliffEdge(plateauSideID, 6, 0.07, 0.0, 1.0, 1);
			rmSetAreaCoherence(plateauSideID, 0.69);
			rmAddAreaToClass(plateauSideID, classCanyon);
			rmSetAreaSmoothDistance(plateauSideID, 6);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(plateauSideID, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(plateauSideID, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(plateauSideID, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(plateauSideID, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(plateauSideID, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(plateauSideID, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(plateauSideID, 1.0, 0.0);
			else
				rmSetAreaLocation(plateauSideID, 0.5, 0.0);
			rmAddAreaConstraint(plateauSideID, avoidTradeRoute);
			rmAddAreaConstraint(plateauSideID, avoidTradeRouteSocketShort);
			rmAddAreaConstraint(plateauSideID, avoidPlayersFar1);
			rmBuildArea(plateauSideID);

			int stayInSidePlateau = rmCreateAreaMaxDistanceConstraint("stay in side plateau", plateauSideID, 0.0);
			int stayNearSidePlateau = rmCreateAreaMaxDistanceConstraint("stay near side plateau", plateauSideID, 3.0);
			int avoidSideRampsPlateau = rmCreateCliffRampDistanceConstraint("avoid plateau side ramps", plateauSideID, 4.0);

			int plateauSidePaintID = rmCreateArea("plateau side paint");
			rmSetAreaSize(plateauSidePaintID, 0.14); 
			rmSetAreaMix(plateauSidePaintID, landName);
			rmSetAreaCoherence(plateauSidePaintID, 0.999);
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(plateauSidePaintID, 0.01, 0.01);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(plateauSidePaintID, 0.01, 0.50);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(plateauSidePaintID, 0.01, 0.99);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(plateauSidePaintID, 0.50, 0.99);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(plateauSidePaintID, 0.99, 0.99);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(plateauSidePaintID, 0.99, 0.50);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(plateauSidePaintID, 0.99, 0.01);
			else
				rmSetAreaLocation(plateauSidePaintID, 0.50, 0.01);
			rmAddAreaConstraint(plateauSidePaintID, stayNearSidePlateau);
			rmBuildArea(plateauSidePaintID);

			if (rmRandFloat(0,1) <= 0.69)
			{
				for (i=0; <2+4*cNumberNonGaiaPlayers)
				{
    				int plateauSideForestID = rmCreateArea("plateau side forest "+i);
    				rmSetAreaWarnFailure(plateauSideForestID, false);
    				rmSetAreaObeyWorldCircleConstraint(plateauSideForestID, true);
    				rmSetAreaSize(plateauSideForestID, rmAreaTilesToFraction(111));
					if (rmRandFloat(0,1) <= 0.01)
						rmSetAreaTerrainType(plateauSideForestID, "texas\nonpassable_temp"); 
					else
					{
    					if (rmRandFloat(0,1) <= 0.001)
							rmSetAreaForestType(plateauSideForestID, "unknown forest funky");
    					else 
							rmSetAreaForestType(plateauSideForestID, forestName);
						if (trollMap == 1)
						{
							rmSetAreaForestDensity(plateauSideForestID, 0.99);
							rmSetAreaForestClumpiness(plateauSideForestID, 0.99);
							rmSetAreaForestUnderbrush(plateauSideForestID, 0.99);
						}
						else
						{
							rmSetAreaForestDensity(plateauSideForestID, 0.8);
							rmSetAreaForestClumpiness(plateauSideForestID, 0.8);
							rmSetAreaForestUnderbrush(plateauSideForestID, 0.3);
						}
					}
    				rmSetAreaCoherence(plateauSideForestID, 0.5);
    				rmSetAreaSmoothDistance(plateauSideForestID, 0);
    				rmAddAreaToClass(plateauSideForestID, rmClassID("classForest")); 
    				rmAddAreaConstraint(plateauSideForestID, forestConstraint);
    				rmAddAreaConstraint(plateauSideForestID, avoidPlayers);
    				rmAddAreaConstraint(plateauSideForestID, stayInSidePlateau);
    				rmAddAreaConstraint(plateauSideForestID, avoidSideRampsPlateau);
    				rmAddAreaConstraint(plateauSideForestID, avoidAll);
					if (floodedLand != 1)
	    				rmAddAreaConstraint(plateauSideForestID, shortAvoidImpassableLand); 
    				rmAddAreaConstraint(plateauSideForestID, avoidTradeRoute);
    				rmAddAreaConstraint(plateauSideForestID, avoidGoldMin);
    				rmAddAreaConstraint(plateauSideForestID, avoidTradeRouteSocketShort);

    				if(rmBuildArea(plateauSideForestID)==false)
    				{
    				   // Stop trying once we fail 3 times in a row.
    				   failCount++;
    				   if(failCount==5)
    				      break;
    				}
    				else
    				   failCount=0; 
				}
			}
			else
			{
				float andSomeMoreRNG = rmRandFloat(0,1);	// additional RNG roll

				for (i=0; < cNumberNonGaiaPlayers)
				{
					int plateauSidePropsID = rmCreateObjectDef("plateau side props"+i);
					if (rmRandFloat(0,1) <= 0.69)
					{
						rmAddObjectDefItem(plateauSidePropsID, propz, 4, 6.0);
					}
					else if (andSomeMoreRNG <= 0.69)
					{
						if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauSidePropsID, "ypMercFlailiphantMansabdar", 10, 8.0);
						else if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauSidePropsID, "ypShogunTokugawa", 10, 8.0);
						else if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(plateauSidePropsID, "deMercGatlingCamel", 10, 8.0);
						else if (euMap == 1)
							rmAddObjectDefItem(plateauSidePropsID, "zpGrapeBush", 10, 8.0);
						else if (oceaniaMap == 1)
							rmAddObjectDefItem(plateauSidePropsID, "zpPineapleBush", 10, 8.0);
						else
							rmAddObjectDefItem(plateauSidePropsID, "BerryBush", 10, 8.0);
					}
					else
						rmAddObjectDefItem(plateauSidePropsID, "deRMFoodMill", 1, 1.0);
					rmSetObjectDefMinDistance(plateauSidePropsID, 0.0);
					rmSetObjectDefMaxDistance(plateauSidePropsID, rmXFractionToMeters(0.20));
					rmAddObjectDefToClass(plateauSidePropsID, classGold);
					rmAddObjectDefConstraint(plateauSidePropsID, avoidGold);
					rmAddObjectDefConstraint(plateauSidePropsID, avoidEdge);
    				rmAddObjectDefConstraint(plateauSidePropsID, stayInSidePlateau);
    				rmAddObjectDefConstraint(plateauSidePropsID, avoidSideRampsPlateau);
					if (floodedLand != 1)
						rmAddObjectDefConstraint(plateauSidePropsID, shortAvoidImpassableLand); 
					if(bayPosition < 0.12)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.01, 0.01, 1);
					else if(bayPosition < 0.24)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.01, 0.50, 1);
					else if(bayPosition < 0.36)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.01, 0.99, 1);
					else if(bayPosition < 0.48)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.50, 0.99, 1);
					else if(bayPosition < 0.60)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.99, 0.99, 1);
					else if(bayPosition < 0.72)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.99, 0.50, 1);
					else if(bayPosition < 0.84)
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.99, 0.01, 1);
					else
						rmPlaceObjectDefAtLoc(plateauSidePropsID, 0, 0.50, 0.01, 1);		
				}
			}
		}
		else	// side forest
		{
			int sideUnknownForest = rmCreateArea("large side forest");
		      rmSetAreaWarnFailure(sideUnknownForest, false);
		    rmSetAreaSize(sideUnknownForest, 0.07);
			if (rmRandFloat(0,1) <= 0.001)
		  		rmSetAreaForestType(sideUnknownForest, "unknown forest funky");
			else
		      rmSetAreaForestType(sideUnknownForest, forestName);
			if (rmGetIsTreaty() == true)	// rmRandFloat(0,1) <= 0.69
			{
				rmSetAreaForestDensity(sideUnknownForest, 0.69);
				rmSetAreaForestClumpiness(sideUnknownForest, 0.69);
				rmSetAreaForestUnderbrush(sideUnknownForest, 0.69);
			}
			else
			{
				rmSetAreaForestDensity(sideUnknownForest, 0.99);
				rmSetAreaForestClumpiness(sideUnknownForest, 0.99);
				rmSetAreaForestUnderbrush(sideUnknownForest, 0.99);
			}
		    rmSetAreaCoherence(sideUnknownForest, 0.15);
		    rmAddAreaToClass(sideUnknownForest, rmClassID("classForest"));
			// Spin bay randomly around the edge		
			if(bayPosition < 0.12)
				rmSetAreaLocation(sideUnknownForest, 0.0, 0.0);
			else if(bayPosition < 0.24)
				rmSetAreaLocation(sideUnknownForest, 0.0, 0.5);
			else if(bayPosition < 0.36)
				rmSetAreaLocation(sideUnknownForest, 0.0, 1.0);
			else if(bayPosition < 0.48)
				rmSetAreaLocation(sideUnknownForest, 0.5, 1.0);
			else if(bayPosition < 0.60)
				rmSetAreaLocation(sideUnknownForest, 1.0, 1.0);
			else if(bayPosition < 0.72)
				rmSetAreaLocation(sideUnknownForest, 1.0, 0.5);
			else if(bayPosition < 0.84)
				rmSetAreaLocation(sideUnknownForest, 1.0, 0.0);
			else
				rmSetAreaLocation(sideUnknownForest, 0.5, 0.0);
		      rmAddAreaConstraint(sideUnknownForest, avoidPlayersFar1); 
		      rmAddAreaConstraint(sideUnknownForest, avoidTradeRoute); 
		      rmAddAreaConstraint(sideUnknownForest, avoidTradeRouteSocketShort); 
		    rmAddAreaConstraint(sideUnknownForest, avoidCliffsShort); 
		    rmAddAreaConstraint(sideUnknownForest, avoidCanyon); 
		    rmAddAreaConstraint(sideUnknownForest, avoidNativesShort); 
			rmAddAreaConstraint(sideUnknownForest, avoidWaterShort); 
			rmAddAreaConstraint(sideUnknownForest, avoidForestZero); 
		}
	}	// Build bay later to avoid players				  

	// ============= Oasis Style Forest =============
	if (forestMiddle == 1)
	{
		if (rmRandFloat(0,1) > 0.25 && trollMap != 1)
		{
			for (i=0; < 4)
			{
				int greatUnknownForest = rmCreateArea("large central forest"+i);
		      rmSetAreaWarnFailure(greatUnknownForest, false);
//				rmSetAreaSize(greatUnknownForest, 0.07);
				rmSetAreaSize(greatUnknownForest, 0.02);
				if (rmRandFloat(0,1) <= 0.001)
					rmSetAreaForestType(greatUnknownForest, "unknown forest funky");
				else
		      		rmSetAreaForestType(greatUnknownForest, forestName);
				if (rmGetIsTreaty() == true)
				{
					rmSetAreaForestDensity(greatUnknownForest, 0.69);
					rmSetAreaForestClumpiness(greatUnknownForest, 0.69);
					rmSetAreaForestUnderbrush(greatUnknownForest, 0.69);
				}
				else
				{
			  		rmSetAreaForestDensity(greatUnknownForest, 0.99);
			  		rmSetAreaForestClumpiness(greatUnknownForest, 0.99);
			  		rmSetAreaForestUnderbrush(greatUnknownForest, 0.99);
				}
		    	rmSetAreaCoherence(greatUnknownForest, 0.15);
		    	rmAddAreaToClass(greatUnknownForest, rmClassID("classForest"));
//				rmSetAreaLocation(greatUnknownForest, 0.5, 0.5);
				if (i < 1)
					rmSetAreaLocation(greatUnknownForest, 0.55, 0.55);
				else if (i < 2)
					rmSetAreaLocation(greatUnknownForest, 0.45, 0.55);
				else if (i < 3)
					rmSetAreaLocation(greatUnknownForest, 0.55, 0.45);
				else
					rmSetAreaLocation(greatUnknownForest, 0.45, 0.45);
		      rmAddAreaConstraint(greatUnknownForest, avoidPlayersFar1); 
		      rmAddAreaConstraint(greatUnknownForest, avoidTradeRoute); 
		      rmAddAreaConstraint(greatUnknownForest, avoidTradeRouteSocketShort); 
				rmAddAreaConstraint(greatUnknownForest, avoidCliffsShort); 
				rmAddAreaConstraint(greatUnknownForest, avoidCanyon); 
				rmAddAreaConstraint(greatUnknownForest, avoidWaterShort); 
				rmAddAreaConstraint(greatUnknownForest, avoidForestZero); 
				rmAddAreaConstraint(greatUnknownForest, avoidNativesShort); 
			}
		}
		else
		{
			if (trollMap == 1 || rmRandFloat(0,1) <= 0.001)
			{
				rmEchoInfo("bonus subCiv is Saltpeter");
				int saltPeterSiteID = rmCreateGrouping("saltpeter site", "saltpeter_0"+rmRandInt(1,3));
				rmSetGroupingMinDistance(saltPeterSiteID, rmXFractionToMeters(0.00));
				rmSetGroupingMaxDistance(saltPeterSiteID, rmXFractionToMeters(0.025));
				rmAddGroupingToClass(saltPeterSiteID, rmClassID("natives"));
				if (floodedLand != 1)
					rmAddGroupingConstraint(saltPeterSiteID, avoidImpassableLand);
				rmAddGroupingConstraint(saltPeterSiteID, avoidTradeRoute);
				rmAddGroupingConstraint(saltPeterSiteID, avoidTradeRouteSocket);
				rmAddGroupingConstraint(saltPeterSiteID, avoidAllFar);
				rmPlaceGroupingAtLoc(saltPeterSiteID, 0, 0.5, 0.5);
			}

			float mineORmill = rmRandFloat(0,1);	// RNG capturable mill or mid map mines

			for (i=0; < 4*cNumberNonGaiaPlayers)
			{
				int rushMineID = rmCreateObjectDef("mineral rush"+i);
				if (rmRandFloat(0,1) <= 0.98)
				{
					if (rmRandFloat(0,1) <= 0.05)
					rmAddObjectDefItem(rushMineID, "BerryBush", 10, 8.0);
					else
					{
						if (mineORmill <= 0.13)
							rmAddObjectDefItem(rushMineID, "deRMFoodMill", 1, 0.0);
						else
							rmAddObjectDefItem(rushMineID, mineralz, 1, 1.0);
					}
				}
				else	// one in a million
				{
					if (rmRandFloat(0,1) <= 0.001)
						rmAddObjectDefItem(rushMineID, "ypMercFlailiphantMansabdar", 10, 8.0);
					else if (rmRandFloat(0,1) <= 0.001)
						rmAddObjectDefItem(rushMineID, "ypShogunTokugawa", 10, 8.0);
					else if (rmRandFloat(0,1) <= 0.001)
						rmAddObjectDefItem(rushMineID, "deMercGatlingCamel", 10, 8.0);
					else if (euMap == 1)
						rmAddObjectDefItem(rushMineID, "zpGrapeBush", 10, 8.0);
					else if (oceaniaMap == 1)
						rmAddObjectDefItem(rushMineID, "zpPineapleBush", 10, 8.0);
					else
						rmAddObjectDefItem(rushMineID, "BerryBush", 10, 8.0);
				}
				rmSetObjectDefMinDistance(rushMineID, 0.0);
				rmSetObjectDefMaxDistance(rushMineID, rmXFractionToMeters(0.10));
				rmAddObjectDefToClass(rushMineID, classGold);
				rmAddObjectDefConstraint(rushMineID, avoidAll);
				rmAddObjectDefConstraint(rushMineID, avoidTradeRouteSocketShort);
				rmAddObjectDefConstraint(rushMineID, avoidGoldShort);
				rmPlaceObjectDefAtLoc(rushMineID, 0, 0.50, 0.50, 1);
			}
		}
	}	// Build forest later to avoid players

	// Rogue Map Feature
	if (rogueMap == 1)
	{
		float rogueLocX = 0.50;
		float rogueLocY = 0.50;

		if (sideBay == 1)
		{
			if(bayPosition < 0.12)
			{
				rogueLocX = 0.80;
				rogueLocY = 0.80;
			}
			else if(bayPosition < 0.24)
			{
				rogueLocX = 0.90;
				rogueLocY = 0.50;
			}
			else if(bayPosition < 0.36)
			{
				rogueLocX = 0.80;
				rogueLocY = 0.20;
			}
			else if(bayPosition < 0.48)
			{
				rogueLocX = 0.50;
				rogueLocY = 0.10;
			}
			else if(bayPosition < 0.60)
			{
				rogueLocX = 0.20;
				rogueLocY = 0.20;
			}
			else if(bayPosition < 0.72)
			{
				rogueLocX = 0.10;
				rogueLocY = 0.50;
			}
			else if(bayPosition < 0.84)
			{
				rogueLocX = 0.20;
				rogueLocY = 0.80;
			}
			else
			{
				rogueLocX = 0.50;
				rogueLocY = 0.90;
			}
		}

		int factoryChance = 0;			// factory RNG
		if (rmRandFloat(0,1) <= 0.25)
			factoryChance = 1;
		int zooChance = 0;				// zoo RNG
		if (factoryChance != 1 && rmRandFloat(0,1) <= 0.10)
			zooChance = 1;
		int rubbleChance = 0;			// rubble RNG
		if (factoryChance != 1 && rmRandFloat(0,1) <= 0.10)
			rubbleChance = 1;
		int archeoChance = 0;			// archeology RNG
		if (rmRandFloat(0,1) <= 0.75)
			archeoChance = 1;
		int rockChurchChance = 0;
		int rogueFarmChance = 0;
		int orientalCityChance = 0;
		int rogueWonderChance = 0;
		int rogueCityChance = 0;
		int rogueRubbleChance = 0;
		int rogueArcheoChance = 0;

		if (westEU == 1)
		{
			if (factoryChance == 1)
				rmSetNuggetDifficulty(506,506);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(501,501);
		}
		else if (centralEU == 1 || northEU == 1 || northeastEU == 1 || northwestEU == 1 || icelandMap == 1)
		{
			if (northEU == 1 && rubbleChance == 1)
				rmSetNuggetDifficulty(502,502);
			else if (northeastEU == 1 && rubbleChance == 1)
				rmSetNuggetDifficulty(502,502);
			else if (icelandMap == 1 && rubbleChance == 1)
				rmSetNuggetDifficulty(502,502);
			else if (factoryChance == 1)
				rmSetNuggetDifficulty(506,506);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(502,502);
		}
		else if (mediEU == 1 || eastEU == 1 || mediSeaEU == 1)
		{
			if (factoryChance == 1)
				rmSetNuggetDifficulty(506,506);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(503,503);
		}
		else if (saguenayMap == 1 || californiaMap == 1 || carolinaMap == 1 || rockiesMap == 1 || sonoraMap == 1 || bayouMap == 1 || nwtMap == 1 || naMap == 1 || caribbeanMap == 1)
		{
			if (rubbleChance == 1)
				rmSetNuggetDifficulty(504,504);
			else if (factoryChance == 1)
				rmSetNuggetDifficulty(506,506);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(504,504);
		}
		else if (andesMap == 1 || araucMap == 1 || amazonMap == 1)
		{
			if (archeoChance == 1)
				rmSetNuggetDifficulty(504,504);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(504,504);
		}
		else if (ausMap == 1)
		{
			if (factoryChance == 1)
				rmSetNuggetDifficulty(506,506);
			else if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(505,505);
		}
		else if (yellowRiverMap == 1 || himalMap == 1 || borneoMap == 1 || japanMap == 1 || mongolMap == 1 || dekkanMap == 1)
		{
			if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
			{
				if (borneoMap == 1 || dekkanMap == 1)
					rmSetNuggetDifficulty(513,513);
				else
					rmSetNuggetDifficulty(509,509);
			}
		}
		else if (afrEast == 1 || afrSavanna == 1 || afrRainforest == 1 || afrDesert == 1)
		{
			if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else if (afrSavanna == 1 || afrDesert == 1)
				rmSetNuggetDifficulty(513,513);
			else
				rmSetNuggetDifficulty(508,508);
		}
		else
		{
			if (zooChance == 1)
				rmSetNuggetDifficulty(507,507);
			else
				rmSetNuggetDifficulty(504,504);			
		}

		int rogueSiteID = -1;
		if (westEU == 1 || centralEU == 1 || northEU == 1 || northeastEU == 1 || northwestEU == 1 || icelandMap == 1)
		{
			if (northEU == 1 && rubbleChance == 1)
			{
				rogueRubbleChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Ruble");
			}
			else if (northeastEU == 1 && rubbleChance == 1)
			{
				rogueRubbleChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Ruble");
			}
			else if (icelandMap == 1 && rubbleChance == 1)
			{
				rogueRubbleChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Ruble");
			}
			else if (factoryChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_North");
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueCityChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_City_West");
			}
		}
		else if (eastEU == 1)
		{
			if (factoryChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_North");
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueCityChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_City_South");
			}
		}
		else if (mediEU == 1 || mediSeaEU == 1)
		{
			if (factoryChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_South");
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueCityChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_City_South");
			}
		}
		else if (saguenayMap == 1 || californiaMap == 1 || carolinaMap == 1 || rockiesMap == 1 || sonoraMap == 1 || bayouMap == 1 || nwtMap == 1 || naMap == 1 || caribbeanMap == 1)
		{
			if (factoryChance == 1)
			{
				if (sonoraMap == 1 || caribbeanMap == 1)
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_South");
				else if (californiaMap == 1)
				{
					if (rmRandFloat(0,1) <= 0.50)
						rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_South");
					else
						rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_North");
				}
				else
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_North");
			}
			else if (rubbleChance == 1)
			{
				if (sonoraMap == 1 || caribbeanMap == 1 || californiaMap == 1)
				{
					rogueArcheoChance = 1;
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Archeology");
				}
				else
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Ruble");
			}
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueFarmChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Farm");
			}
		}
		else if (andesMap == 1 || araucMap == 1 || amazonMap == 1)
		{
			if (archeoChance == 1)
			{
				rogueArcheoChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Archeology");
			}
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueFarmChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Farm");
			}
		}
		else if (ausMap == 1)
		{
			if (factoryChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_North");
			else if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueFarmChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Farm");
			}
		}
		else if (yellowRiverMap == 1 || himalMap == 1 || borneoMap == 1 || japanMap == 1 || mongolMap == 1 || dekkanMap == 1)
		{
			if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else if (japanMap == 1 && factoryChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Factory_Japan");
			else
			{
				if (dekkanMap == 1 || borneoMap == 1)
				{
					orientalCityChance = 1;
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_City_Oriental");
				}
				else
				{
					rogueWonderChance = 1;
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Wonder");
				}
			}
		}
		else if (afrEast == 1 || afrSavanna == 1 || afrRainforest == 1 || afrDesert == 1)
		{
			if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Safari");
			else
			{
				if (afrSavanna == 1 || afrDesert == 1)
				{
					orientalCityChance = 1;
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_City_Oriental");
				}
				else
				{
					rockChurchChance = 1;
					rogueSiteID = rmCreateGrouping("rogue site", "Rogue_RockChurch");
				}
			}
		}
		else
		{
			if (zooChance == 1)
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Zoo");
			else
			{
				rogueFarmChance = 1;
				rogueSiteID = rmCreateGrouping("rogue site", "Rogue_Farm");
			}
		}
		rmSetGroupingMinDistance(rogueSiteID, rmXFractionToMeters(0.00));
		rmSetGroupingMaxDistance(rogueSiteID, rmXFractionToMeters(0.00));
		rmAddGroupingToClass(rogueSiteID, rmClassID("natives"));
		rmAddGroupingConstraint(rogueSiteID, avoidAllFar);

		int rogueSiteInstanceID1 = rmPlaceGroupingInstanceAtLoc(rogueSiteID, rogueLocX, rogueLocY, 0);

		// Grouping unit IDs
		int rogueTreasureID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpNuggetInvisible");
		int rogueCathedralID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCGermanCathedral");
		int rogueBasilicaID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCGreatBasilicaConvertable");
		int rogueMarketID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCCityMarket");
		int rogueBankID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCNationalBank");
		int rogueDistileryID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCDestilery");
		int rogueSawMillID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCSawMill");
		int rogueFactoryID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCCapturableFactory");
		int rogueSmelterID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCGoldSmelter");
		int rogueFactorySouthID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCCapturableFactoryFlorence");
		int rogueWonderID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCPorcelainTower");
		int rogueRockChurchID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCRockChurch");
		int rogueSafariID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCSafari");
		int rogueMenagerieID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCMenagerie");
		int rogueChurchID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpHanseaticChurch");
		int rogueWarehouseID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCDemolisher");
		int rogueTreasuryID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCAztecTreasury");
		int rogueAztecTempleID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCAztecMediumTemple");
		int rogueMosqueID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCIstanbulMosque");
		int rogueBazaarID = rmGetGroupingInstanceUnitByType(rogueSiteInstanceID1, "zpSPCCityMarketOriental");


		// Conversion Suspend
		rmCreateTrigger("RogueState Convert OFF");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueCathedralID);
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBasilicaID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMarketID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBankID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueDistileryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSawMillID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueFactoryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSmelterID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueFactorySouthID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueWonderID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueRockChurchID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSafariID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMenagerieID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueChurchID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueWarehouseID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueTreasuryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueAztecTempleID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMosqueID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBazaarID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("RogueState Convert ON");
		rmAddTriggerCondition("Nugget Is Collectable");
		rmSetTriggerConditionParam("NuggetObject", ""+rogueTreasureID);
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueCathedralID);
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBasilicaID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMarketID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBankID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueDistileryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSawMillID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueFactoryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSmelterID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueFactorySouthID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueWonderID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueRockChurchID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueSafariID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMenagerieID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueChurchID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueWarehouseID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueTreasuryID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueAztecTempleID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueMosqueID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject",""+rogueBazaarID );
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "False");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("RogueState Techs");
		rmSwitchToTrigger(rmTriggerID("Starting techs"));
		for(i=0; <= cNumberNonGaiaPlayers)
		{
			if (rogueCityChance == 1) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
				if (westEU == 1 || centralEU == 1 || northEU == 1 || northeastEU == 1 || northwestEU == 1 ||  icelandMap == 1)
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueEuropean"); // Europen Map
				else
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueItalian"); // Italian Map
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (rogueFarmChance == 1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",i);
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueAmerican"); // American / Australian map
			rmSetTriggerEffectParamInt("Status",2);
			}
			if (orientalCityChance == 1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",i);
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueOriental"); // Oriental map
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (rogueRubbleChance == 1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",i);
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueNorthCity"); // Oriental map
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (rogueArcheoChance == 1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",i);
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueAztec"); // Oriental map
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (rockChurchChance == 1) {
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",i);
				rmSetTriggerEffectParam("TechID","cTechzpUnknownRogueAfrican"); // Oriental map
				rmSetTriggerEffectParamInt("Status",2);
			}
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 1.00);
	else if (trollBar == 1)
	   rmSetStatusText("", 0.8);
   	else
   		rmSetStatusText("", 0.2);
   
	// ============= Player Configurations =============
	// Sometimes teams closer together
	if (rmGetNomadStart() == true)
	{
		if (cNumberTeams == 2 && rmGetNumberPlayersOnTeam(0) == rmGetNumberPlayersOnTeam(1))
		{
			float aValue = 1.0/cNumberNonGaiaPlayers;

			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.01, 0.00);
			rmPlacePlayersCircular(0.30, 0.40, 0);

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.01+aValue, 0.00+aValue);
			rmPlacePlayersCircular(0.30, 0.40, 0.0);
		}
		else
		{
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.25, 0.40, 0);
		}
	}
	else
	{
		if (riverExists == 1)
		{
			rmSetTeamSpacingModifier(0.69);
		}
		else if (oceanMiddle == 1)
		{
			rmSetTeamSpacingModifier(0.60);
		}
		else
		{
			rmSetTeamSpacingModifier(0.50);
		}

		if(oceanOffCenter == 1)
		{
			int teamNombre = rmRandInt(1,2);
			int teamZero = -1;
			int teamOne = -1;
			if (teamNombre == 1)
			{
				teamZero = 0;
				teamOne = 1;
			}
			else
			{
				teamZero = 1;
				teamOne = 0;
			}

			if (cNumberTeams > 2 || rmGetNumberPlayersOnTeam(0) != rmGetNumberPlayersOnTeam(1))
			{
				if (bayPosition < 0.12)
					rmSetPlacementSection(0.800, 0.450);
				else if (bayPosition < 0.24)
					rmSetPlacementSection(0.925, 0.575);
				else if (bayPosition < 0.36)
					rmSetPlacementSection(0.070, 0.700);
				else if (bayPosition < 0.48)
					rmSetPlacementSection(0.195, 0.825);
				else if (bayPosition < 0.60)
					rmSetPlacementSection(0.300, 0.950);
				else if (bayPosition < 0.72)
					rmSetPlacementSection(0.425, 0.055);
				else if (bayPosition < 0.84)
					rmSetPlacementSection(0.550, 0.180);
				else 
					rmSetPlacementSection(0.685, 0.315);
				rmSetTeamSpacingModifier(0.50);
				if (cNumberNonGaiaPlayers <= 4)
					rmPlacePlayersCircular(0.36, 0.36, 0);
				else
					rmPlacePlayersCircular(0.37, 0.37, 0);
			}
			else
			{
				rmSetPlacementTeam(teamZero);
				if (cNumberNonGaiaPlayers == 2)
				{
					if (bayPosition < 0.12)
						rmSetPlacementSection(0.450, 0.451);
					else if (bayPosition < 0.24)
						rmSetPlacementSection(0.575, 0.576);
					else if (bayPosition < 0.36)
						rmSetPlacementSection(0.700, 0.701);
					else if (bayPosition < 0.48)
						rmSetPlacementSection(0.825, 0.826);
					else if (bayPosition < 0.60)
						rmSetPlacementSection(0.950, 0.951);
					else if (bayPosition < 0.72)
						rmSetPlacementSection(0.055, 0.056);
					else if (bayPosition < 0.84)
						rmSetPlacementSection(0.180, 0.181);
					else 
						rmSetPlacementSection(0.315, 0.316);
				}
				else
				{
					if (bayPosition < 0.12)
						rmSetPlacementSection(0.450-0.022*cNumberNonGaiaPlayers, 0.450);
					else if (bayPosition < 0.24)
						rmSetPlacementSection(0.575-0.022*cNumberNonGaiaPlayers, 0.575);
					else if (bayPosition < 0.36)
						rmSetPlacementSection(0.700-0.022*cNumberNonGaiaPlayers, 0.700);
					else if (bayPosition < 0.48)
						rmSetPlacementSection(0.825-0.022*cNumberNonGaiaPlayers, 0.825);
					else if (bayPosition < 0.60)
						rmSetPlacementSection(0.950-0.022*cNumberNonGaiaPlayers, 0.950);
					else if (bayPosition < 0.72)
						rmSetPlacementSection(0.055-0.022*cNumberNonGaiaPlayers, 0.055);
					else if (bayPosition < 0.84)
						rmSetPlacementSection(0.180-0.022*cNumberNonGaiaPlayers, 0.180);
					else 
						rmSetPlacementSection(0.315-0.022*cNumberNonGaiaPlayers, 0.315);
				}
				rmSetTeamSpacingModifier(0.50);
				if (cNumberNonGaiaPlayers <= 4)
					rmPlacePlayersCircular(0.36, 0.36, 0);
				else
					rmPlacePlayersCircular(0.37, 0.37, 0);

				rmSetPlacementTeam(teamOne);
				if (bayPosition < 0.12)
					rmSetPlacementSection(0.800, 0.800+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.24)
					rmSetPlacementSection(0.925, 0.925+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.36)
					rmSetPlacementSection(0.070, 0.070+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.48)
					rmSetPlacementSection(0.195, 0.195+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.60)
					rmSetPlacementSection(0.300, 0.300+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.72)
					rmSetPlacementSection(0.425, 0.425+0.022*cNumberNonGaiaPlayers);
				else if (bayPosition < 0.84)
					rmSetPlacementSection(0.550, 0.550+0.022*cNumberNonGaiaPlayers);
				else 
					rmSetPlacementSection(0.685, 0.685+0.022*cNumberNonGaiaPlayers);
				rmSetTeamSpacingModifier(0.50);
				if (cNumberNonGaiaPlayers <= 4)
					rmPlacePlayersCircular(0.36, 0.36, 0);
				else
					rmPlacePlayersCircular(0.37, 0.37, 0);
			}
		}
		else if (oceanMiddle == 1)
		{
			if (cNumberNonGaiaPlayers <= 4)
				rmPlacePlayersCircular(0.36, 0.36, 0);
			else
				rmPlacePlayersCircular(0.37, 0.37, 0);
			rmEchoInfo("players nearer edge because ocean in middle");
		}
		else if(oceanRing == 1)
		{
			rmPlacePlayersCircular(0.32, 0.34, 0);
			rmEchoInfo("players very far from edge because of continent");
		}
		else
		{
			rmPlacePlayersCircular(0.32, 0.36, 0);
			rmEchoInfo("players can be farther from edge");
		}
	}

	float playerFraction = rmAreaTilesToFraction(123);

	for(i=1; <cNumberPlayers)
	{
		// Create the area.
		int id = rmCreateArea("Player"+i);
		rmSetAreaObeyWorldCircleConstraint(id, true);
		rmSetPlayerArea(i, id);
		rmSetAreaSize(id, playerFraction);
		if (rmGetNomadStart() == false)
			rmAddAreaToClass(id, classPlayer);
		rmSetAreaMinBlobs(id, 1);
		rmSetAreaMaxBlobs(id, 1);
		rmAddAreaConstraint(id, avoidPlayers);
		if (trollMap == 1 || rmRandFloat(0,1) <= 0.001)
			rmSetAreaMix(id, "testmix");
		else
			rmSetAreaMix(id, landName);
		if (floodedLand == 1)
			rmSetAreaBaseHeight(id, 2);
		rmSetAreaCoherence(id, 0.123);
//		rmSetAreaSmoothDistance(id, 20);
		rmAddAreaConstraint(id, playerAvoidImpassableLand);
		rmSetAreaLocPlayer(id, i);
		rmSetAreaWarnFailure(id, false);
		rmBuildArea(id);
	}
	
	rmBuildAllAreas();

	int stayInLake = rmCreateAreaMaxDistanceConstraint("stay in lake", lakeOfTheUnknown, 0.0);
	int stayNearLake = rmCreateAreaMaxDistanceConstraint("stay near lake", lakeOfTheUnknown, 22.0);
	int avoidLake = rmCreateAreaDistanceConstraint("avoid lake", lakeOfTheUnknown, 28.0);
	int stayInBay = rmCreateAreaMaxDistanceConstraint("stay in bay", unknownBay, 0.0);
	int stayNearBay = rmCreateAreaMaxDistanceConstraint("stay near bay", unknownBay, 22.0);
	int stayInBigIsland = rmCreateAreaMaxDistanceConstraint("stay in big island", continent, 0.0);
	int ferryOnShore = rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 22.0);
	int flagLandShort = rmCreateTerrainDistanceConstraint("flag vs land short", "land", true, 8.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);

	// ============= Place Pirates =============
	int eurekaShip = -1;
	int donutHoleSpawn = -1;
	int stayInSideBay = -1;
	int stayInMiddleLake = -1;
	int piratePos = -1;		// randomly chooses pirate region
	int pirateType = -1;	// RNG for different pirate sites

	if (rmRandFloat(0,1) <= 0.10)	// controls for random treasure ship
	{
		if (oceanMiddle == 1 && oceanChance == 1)
			eurekaShip = 1;
		if (oceanOffCenter == 1 && bayChance == 1)
			eurekaShip = 1;
		if (oceanRing == 1 || splitIsland == 1)
			eurekaShip = 1;
	}

	if (rmRandFloat(0,1) <= 0.20)
		pirateType = 5;	// hansa
	else if (rmRandFloat(0,1) <= 0.25)
		pirateType = 1;	// pirate
	else if (rmRandFloat(0,1) <= 0.333)
		pirateType = 2;	// scientist
	else if (rmRandFloat(0,1) <= 0.50)
		pirateType = 3;	// wokou
	else
		pirateType = 4;	// venetians

	if (oceanMiddle == 1 && oceanChance == 1)
		ahoyMeMatey = 1;
	if (oceanOffCenter == 1 && bayChance == 1)
		ahoyMeMatey = 1;
	if (oceanRing == 1 || splitIsland == 1)
		ahoyMeMatey = 1;
	if (frozenLake == 1 || floodedLand == 1)
		ahoyMeMatey = -1;
	
//		ahoyMeMatey = 1;	// for testing

	// Pirate Stuff
	if (ahoyMeMatey == 1)
	{
		// Place Controllers
		int controllerID1 = rmCreateObjectDef("Controler 1");
		rmAddObjectDefItem(controllerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(controllerID1, 0.0);
		rmSetObjectDefMaxDistance(controllerID1, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(controllerID1, rmClassID("pirates"));
//		rmAddObjectDefConstraint(controllerID1, avoidAllFar);
		rmAddObjectDefConstraint(controllerID1, avoidTradeRouteFar);
		rmAddObjectDefConstraint(controllerID1, avoidImpassableLand);
		rmAddObjectDefConstraint(controllerID1, ferryOnShore);
		rmAddObjectDefConstraint(controllerID1, avoidPiratesController);
		if (riverExists == 1 && oceanRing == 1)
		{
			if (rmRandFloat(0,1) <= 0.25)
			{
				piratePos = 1;	// first pirate north
				rmAddObjectDefConstraint(controllerID1, stayNorFar); 
			}
			else if (rmRandFloat(0,1) <= 0.333)
			{
				piratePos = 2;	// first pirate east
				rmAddObjectDefConstraint(controllerID1, stayEstFar); 
			}
			else if (rmRandFloat(0,1) <= 0.50)
			{
				piratePos = 3;	// first pirate south
				rmAddObjectDefConstraint(controllerID1, staySudFar); 
			}
			else
			{
				piratePos = 4;	// first pirate west
				rmAddObjectDefConstraint(controllerID1, stayWstFar); 
			}
		}
		else if (splitIsland == 1)
		{
			rmAddObjectDefConstraint(controllerID1, avoidCenter); 
		}
		else if (oceanOffCenter != 1)
		{
			if (rmRandFloat(0,1) <= 0.25)
			{
				piratePos = 1;	// first pirate north
				rmAddObjectDefConstraint(controllerID1, stayNor); 
			}
			else if (rmRandFloat(0,1) <= 0.333)
			{
				piratePos = 2;	// first pirate east
				rmAddObjectDefConstraint(controllerID1, stayEst); 
			}
			else if (rmRandFloat(0,1) <= 0.50)
			{
				piratePos = 3;	// first pirate south
				rmAddObjectDefConstraint(controllerID1, staySud); 
			}
			else
			{
				piratePos = 4;	// first pirate west
				rmAddObjectDefConstraint(controllerID1, stayWst); 
			}
		}
		if (oceanMiddle == 1)
		{
			if (oceanRing == 1)
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					donutHoleSpawn = 1;
					rmAddObjectDefConstraint(controllerID1, stayNearLake); 
				}
				else
				{
					rmAddObjectDefConstraint(controllerID1, stayInBigIsland); 
					rmAddObjectDefConstraint(controllerID1, avoidLake); 
				}
			}
			else if (oceanOffCenter == 1)
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					stayInMiddleLake = 1;
					rmAddObjectDefConstraint(controllerID1, stayNearLake); 
					if (sideBay == 1)
						rmAddObjectDefConstraint(controllerID1, avoidCenterFar);
					else
					{
						if (rmRandFloat(0,1) <= 0.25)
						{
							piratePos = 1;	// first pirate north
							rmAddObjectDefConstraint(controllerID1, stayNor); 
						}
						else if (rmRandFloat(0,1) <= 0.333)
						{
							piratePos = 2;	// first pirate east
							rmAddObjectDefConstraint(controllerID1, stayEst); 
						}
						else if (rmRandFloat(0,1) <= 0.50)
						{
							piratePos = 3;	// first pirate south
							rmAddObjectDefConstraint(controllerID1, staySud); 
						}
						else
						{
							piratePos = 4;	// first pirate west
							rmAddObjectDefConstraint(controllerID1, stayWst); 
						}
					}
				}
				else
				{
					stayInSideBay = 1;
					rmAddObjectDefConstraint(controllerID1, stayNearBay); 
					rmAddObjectDefConstraint(controllerID1, avoidCenterFar);
				}
			}
			else
				rmAddObjectDefConstraint(controllerID1, stayNearLake); 
		}
		else if (oceanOffCenter == 1)
		{
			if (oceanMiddle == 1)
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					stayInSideBay = 1;
					rmAddObjectDefConstraint(controllerID1, stayNearBay); 
					rmAddObjectDefConstraint(controllerID1, avoidCenterFar);
				}
				else
				{
					stayInMiddleLake = 1;
					rmAddObjectDefConstraint(controllerID1, stayNearLake); 
					if (sideBay == 1)
						rmAddObjectDefConstraint(controllerID1, avoidCenterFar);
					else
					{
						if (rmRandFloat(0,1) <= 0.25)
						{
							piratePos = 1;	// first pirate north
							rmAddObjectDefConstraint(controllerID1, stayNor); 
						}
						else if (rmRandFloat(0,1) <= 0.333)
						{
							piratePos = 2;	// first pirate east
							rmAddObjectDefConstraint(controllerID1, stayEst); 
						}
						else if (rmRandFloat(0,1) <= 0.50)
						{
							piratePos = 3;	// first pirate south
							rmAddObjectDefConstraint(controllerID1, staySud); 
						}
						else
						{
							piratePos = 4;	// first pirate west
							rmAddObjectDefConstraint(controllerID1, stayWst); 
						}
					}
				}
			}
			else
			{
				rmAddObjectDefConstraint(controllerID1, stayNearBay); 
//				rmAddObjectDefConstraint(controllerID1, avoidCenterFar); 
			}
		}
		else if (oceanRing == 1)
			rmAddObjectDefConstraint(controllerID1, stayInBigIsland); 
		else // split islands
		{
			rmAddObjectDefConstraint(controllerID1, stayNearTeam1Isle); 
//			rmAddObjectDefConstraint(controllerID1, avoidCenter); 
		}
		rmPlaceObjectDefAtLoc(controllerID1, 0, 0.5, 0.5, 1);

		int controllerID2 = rmCreateObjectDef("Controler 2");
		rmAddObjectDefItem(controllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(controllerID2, 0.0);
		rmSetObjectDefMaxDistance(controllerID2, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(controllerID2, rmClassID("pirates"));
//		rmAddObjectDefConstraint(controllerID2, avoidAllFar);
		rmAddObjectDefConstraint(controllerID2, avoidTradeRouteFar);
		rmAddObjectDefConstraint(controllerID2, avoidImpassableLand);
		rmAddObjectDefConstraint(controllerID2, ferryOnShore); 
		rmAddObjectDefConstraint(controllerID2, avoidPiratesController);

		if (riverExists == 1 && oceanRing == 1)
		{
			if (piratePos == 3) // first pirate south
				rmAddObjectDefConstraint(controllerID2, stayNorFar); 
			else if (piratePos == 4) // first pirate west
				rmAddObjectDefConstraint(controllerID2, stayEstFar); 
			else if (piratePos == 1) // first pirate north
				rmAddObjectDefConstraint(controllerID2, staySudFar); 
			else	// first pirate east
				rmAddObjectDefConstraint(controllerID2, stayWstFar); 
		}
		else if (splitIsland == 1)
		{
			rmAddObjectDefConstraint(controllerID2, avoidCenter); 
		}
		else if (oceanOffCenter != 1)
		{
			if (piratePos == 3) // first pirate south
				rmAddObjectDefConstraint(controllerID2, stayNor); 
			else if (piratePos == 4) // first pirate west
				rmAddObjectDefConstraint(controllerID2, stayEst); 
			else if (piratePos == 1) // first pirate north
				rmAddObjectDefConstraint(controllerID2, staySud); 
			else	// first pirate east
				rmAddObjectDefConstraint(controllerID2, stayWst); 
		}
		if (oceanMiddle == 1)
		{
			if (oceanRing == 1)
			{
				if (rmRandFloat(0,1) <= 0.50)
				{
					donutHoleSpawn = 1;
					rmAddObjectDefConstraint(controllerID2, stayNearLake); 
				}
				else
				{
					rmAddObjectDefConstraint(controllerID2, stayInBigIsland); 
					rmAddObjectDefConstraint(controllerID2, avoidLake); 
				}
			}
			else if (oceanOffCenter == 1)
			{
				if (stayInMiddleLake == 1)
				{
					rmAddObjectDefConstraint(controllerID2, stayNearLake); 
					if (sideBay == 1)
						rmAddObjectDefConstraint(controllerID2, avoidCenterFar);
					else
					{
						if (piratePos == 3) // first pirate south
							rmAddObjectDefConstraint(controllerID2, stayNor); 
						else if (piratePos == 4) // first pirate west
							rmAddObjectDefConstraint(controllerID2, stayEst); 
						else if (piratePos == 1) // first pirate north
							rmAddObjectDefConstraint(controllerID2, staySud); 
						else	// first pirate east
							rmAddObjectDefConstraint(controllerID2, stayWst); 
					}
				}
				else
				{
					rmAddObjectDefConstraint(controllerID2, stayNearBay); 
					rmAddObjectDefConstraint(controllerID2, avoidCenterFar);
				}
			}
			else
				rmAddObjectDefConstraint(controllerID2, stayNearLake); 
		}
		else if (oceanOffCenter == 1)
		{
			if (oceanMiddle == 1)
			{
				if (stayInSideBay == 1)
				{
					rmAddObjectDefConstraint(controllerID2, stayNearBay); 
					rmAddObjectDefConstraint(controllerID2, avoidCenterFar);
				}
				else
				{
					rmAddObjectDefConstraint(controllerID2, stayNearLake); 
					if (sideBay == 1)
						rmAddObjectDefConstraint(controllerID2, avoidCenterFar);
					else
					{
						if (piratePos == 3) // first pirate south
							rmAddObjectDefConstraint(controllerID2, stayNor); 
						else if (piratePos == 4) // first pirate west
							rmAddObjectDefConstraint(controllerID2, stayEst); 
						else if (piratePos == 1) // first pirate north
							rmAddObjectDefConstraint(controllerID2, staySud); 
						else	// first pirate east
							rmAddObjectDefConstraint(controllerID2, stayWst); 
					}
				}
			}
			else
			{
				rmAddObjectDefConstraint(controllerID2, stayNearBay); 
				rmAddObjectDefConstraint(controllerID2, avoidCenterFar); 
			}
		}
		else if (oceanRing == 1)
			rmAddObjectDefConstraint(controllerID2, stayInBigIsland); 
		else // split islands
		{
			rmAddObjectDefConstraint(controllerID2, stayNearTeam2Isle); 
//			rmAddObjectDefConstraint(controllerID2, avoidCenter); 
		}
		rmPlaceObjectDefAtLoc(controllerID2, 0, 0.5, 0.5, );

		vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID1, 0));
		vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerID2, 0));

		// Pirate Village 1
		int piratesVillageID = -1;
		int piratesVillageType = rmRandInt(1,2);
		if (pirateType == 1)
			piratesVillageID = rmCreateGrouping("pirate city 1", "pirate_village01");
		else if (pirateType == 2)
			piratesVillageID = rmCreateGrouping("pirate city 1", "Scientist_Lab05");
		else if (pirateType == 3)
			piratesVillageID = rmCreateGrouping("pirate city 1", "Wokou_Village_01");
		else if (pirateType == 4)
			piratesVillageID = rmCreateGrouping("pirate city 1", "Venetian_Unknown");
		else
			piratesVillageID = rmCreateGrouping("pirate city 1", "Hansa_Unknown_01");
		rmAddGroupingToClass(piratesVillageID, rmClassID("natives"));
		rmAddGroupingToClass(piratesVillageID, rmClassID("pirates"));
		rmSetGroupingMinDistance(piratesVillageID, 0);
		rmSetGroupingMaxDistance(piratesVillageID, 22);
		rmAddGroupingConstraint(piratesVillageID, avoidEdge);
		rmAddGroupingConstraint(piratesVillageID, ferryOnShore);
		rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1)), 1);

		int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
		if (pirateType == 1)
			rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
		else if (pirateType == 2)
			rmAddObjectDefItem(piratewaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1.0);
		else if (pirateType == 3)
			rmAddObjectDefItem(piratewaterflagID1, "zpWokouWaterSpawnFlag1", 1, 1.0);
		else if (pirateType == 4)
			rmAddObjectDefItem(piratewaterflagID1, "zpVenetianWaterSpawnFlag1", 1, 1.0);
		else
			rmAddObjectDefItem(piratewaterflagID1, "zpHansaWaterSpawnFlag1", 1, 1.0);
		rmAddObjectDefToClass(piratewaterflagID1, rmClassID("pirates"));
		rmAddClosestPointConstraint(flagLandShort);
		rmAddClosestPointConstraint(avoidEdge);
		if (riverExists == 1 && oceanRing == 1)
		{
			rmAddClosestPointConstraint(avoidCenterFlag);
		}

		vector closeToVillage1 = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

		rmClearClosestPointConstraints();

		int pirateportID1 = -1;
		pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
		rmAddClosestPointConstraint(avoidEdge);
		rmAddClosestPointConstraint(portOnShore);
		if (riverExists == 1 && oceanRing == 1)
		{
			rmAddClosestPointConstraint(avoidCenterFlag);
		}

		vector closeToVillage1a = rmFindClosestPointVector(ControllerLoc1, rmXFractionToMeters(1.0));
		rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

		rmClearClosestPointConstraints();

		// Pirate Village 2
		int piratesVillageID2 = -1;
		int piratesVillage2Type = 3-piratesVillageType;
		if (pirateType == 1)
			piratesVillageID2 = rmCreateGrouping("pirate city 2", "pirate_village02");
		else if (pirateType == 2)
			piratesVillageID2 = rmCreateGrouping("pirate city 2", "Scientist_Lab06");
		else if (pirateType == 3)
			piratesVillageID2 = rmCreateGrouping("pirate city 2", "Wokou_Village_02");
		else if (pirateType == 4)
			piratesVillageID2 = rmCreateGrouping("pirate city 2", "Venetian_Unknown");
		else
			piratesVillageID2 = rmCreateGrouping("pirate city 2", "Hansa_Unknown_02");
		rmAddGroupingToClass(piratesVillageID2, rmClassID("natives"));
		rmAddGroupingToClass(piratesVillageID2, rmClassID("pirates"));
		rmSetGroupingMinDistance(piratesVillageID2, 0);
		rmSetGroupingMaxDistance(piratesVillageID2, 22);
		rmAddGroupingConstraint(piratesVillageID2, avoidEdge);
		rmAddGroupingConstraint(piratesVillageID2, ferryOnShore);

		rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2)), 1);

		int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
		if (pirateType == 1)
			rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1.0);
		else if (pirateType == 2)
			rmAddObjectDefItem(piratewaterflagID2, "zpNativeWaterSpawnFlag2", 1, 1.0);
		else if (pirateType == 3)
			rmAddObjectDefItem(piratewaterflagID2, "zpWokouWaterSpawnFlag2", 1, 1.0);
		else if (pirateType == 4)
			rmAddObjectDefItem(piratewaterflagID2, "zpVenetianWaterSpawnFlag2", 1, 1.0);
		else
			rmAddObjectDefItem(piratewaterflagID2, "zpHansaWaterSpawnFlag2", 1, 1.0);
		rmAddObjectDefToClass(piratewaterflagID2, rmClassID("pirates"));
		rmAddClosestPointConstraint(flagLandShort);
		rmAddClosestPointConstraint(avoidEdge);
		if (riverExists == 1 && oceanRing == 1)
		{
			rmAddClosestPointConstraint(avoidCenterFlag);
		}

		vector closeToVillage2 = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
		rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

		rmClearClosestPointConstraints();

		int pirateportID2 = -1;
		pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
		rmAddClosestPointConstraint(portOnShore);
		if (riverExists == 1 && oceanRing == 1)
		{
			rmAddClosestPointConstraint(avoidCenterFlag);
		}

		vector closeToVillage2a = rmFindClosestPointVector(ControllerLoc2, rmXFractionToMeters(1.0));
		rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

		rmClearClosestPointConstraints();
	}

	// Electors Stuff
//	if (rmRandFloat(0,1) <= 0.99999)	// for testing
	if (rmRandFloat(0,1) <= 0.05)
	{
		electorSpawn = 1;
		int electorCompass = rmRandInt(0,1);
//			electorCompass = 1;		// for testing

		if (sideBay == 1)
		{
			if (bayPosition < 0.12)
				electorCompass = 0;
			else if (bayPosition < 0.24)
				electorCompass = 1;
			else if (bayPosition < 0.36)
				electorCompass = 0;
			else if (bayPosition < 0.48)
				electorCompass = 1;
			else if (bayPosition < 0.60)
				electorCompass = 0;
			else if (bayPosition < 0.72)
				electorCompass = 1;
			else if (bayPosition < 0.84)
				electorCompass = 0;
			else
				electorCompass = 1;
		}

		float elecX1 = 0.00;
		float elecY1 = 0.00;
		float elecX2 = 0.00;
		float elecY2 = 0.00;
		float elecX3 = 0.00;
		float elecY3 = 0.00;
		float elecX4 = 0.00;
		float elecY4 = 0.00;

		if (electorCompass == 1)	// N E S W
		{
			if (rmRandFloat(0,1) <= 0.25)
			{
				elecX1 = 0.30;
				elecY1 = 0.30;
				elecX2 = 0.70;
				elecY2 = 0.70;
				elecX3 = 0.30;
				elecY3 = 0.70;
				elecX4 = 0.70;
				elecY4 = 0.30;
			}
			else if (rmRandFloat(0,1) <= 0.333)
			{
				elecX1 = 0.30;
				elecY1 = 0.70;
				elecX2 = 0.70;
				elecY2 = 0.30;
				elecX3 = 0.30;
				elecY3 = 0.30;
				elecX4 = 0.70;
				elecY4 = 0.70;
			}
			else if (rmRandFloat(0,1) <= 0.50)
			{
				elecX1 = 0.70;
				elecY1 = 0.30;
				elecX2 = 0.30;
				elecY2 = 0.70;
				elecX3 = 0.70;
				elecY3 = 0.70;
				elecX4 = 0.30;
				elecY4 = 0.30;
			}
			else
			{
				elecX1 = 0.70;
				elecY1 = 0.70;
				elecX2 = 0.30;
				elecY2 = 0.30;
				elecX3 = 0.70;
				elecY3 = 0.30;
				elecX4 = 0.30;
				elecY4 = 0.70;
			}
		}
		else
		{
			if (rmRandFloat(0,1) <= 0.25)
			{
				elecX1 = 0.50;
				elecY1 = 0.20;
				elecX2 = 0.50;
				elecY2 = 0.80;
				elecX3 = 0.80;
				elecY3 = 0.50;
				elecX4 = 0.20;
				elecY4 = 0.50;
			}
			else if (rmRandFloat(0,1) <= 0.333)
			{
				elecX1 = 0.80;
				elecY1 = 0.50;
				elecX2 = 0.20;
				elecY2 = 0.50;
				elecX3 = 0.50;
				elecY3 = 0.80;
				elecX4 = 0.50;
				elecY4 = 0.20;
			}
			else if (rmRandFloat(0,1) <= 0.50)
			{
				elecX1 = 0.20;
				elecY1 = 0.50;
				elecX2 = 0.80;
				elecY2 = 0.50;
				elecX3 = 0.50;
				elecY3 = 0.20;
				elecX4 = 0.50;
				elecY4 = 0.80;
			}
			else
			{
				elecX1 = 0.50;
				elecY1 = 0.80;
				elecX2 = 0.50;
				elecY2 = 0.20;
				elecX3 = 0.20;
				elecY3 = 0.50;
				elecX4 = 0.80;
				elecY4 = 0.50;
			}
		}

		int castleBohemia = rmCreateGrouping("castle bohemia", "Elector_Bohemia_02");
		rmSetGroupingMinDistance(castleBohemia, rmXFractionToMeters(0.00));
		rmSetGroupingMaxDistance(castleBohemia, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
		rmAddGroupingToClass(castleBohemia, classElectors);
		if (floodedLand != 1)
			rmAddGroupingConstraint(castleBohemia, avoidImpassableLand);
		rmAddGroupingConstraint(castleBohemia, avoidTradeRoute);
		rmAddGroupingConstraint(castleBohemia, avoidTradeRouteSocket);
		rmAddGroupingConstraint(castleBohemia, nativesAvoidPlayers);
		rmAddGroupingConstraint(castleBohemia, avoidElectors);
		rmAddGroupingConstraint(castleBohemia, avoidPiratesShort);
		rmAddGroupingConstraint(castleBohemia, avoidNatives);
		rmAddGroupingConstraint(castleBohemia, edgeConstraint);
		rmAddGroupingConstraint(castleBohemia, avoidCanyon);

		int castleSaxony = rmCreateGrouping("castle saxony", "Elector_Saxony_02");
		rmSetGroupingMinDistance(castleSaxony, rmXFractionToMeters(0.00));
		rmSetGroupingMaxDistance(castleSaxony, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
		rmAddGroupingToClass(castleSaxony, classElectors);
		if (floodedLand != 1)
			rmAddGroupingConstraint(castleSaxony, avoidImpassableLand);
		rmAddGroupingConstraint(castleSaxony, avoidTradeRoute);
		rmAddGroupingConstraint(castleSaxony, avoidTradeRouteSocket);
		rmAddGroupingConstraint(castleSaxony, nativesAvoidPlayers);
		rmAddGroupingConstraint(castleSaxony, avoidElectors);
		rmAddGroupingConstraint(castleSaxony, avoidPiratesShort);
		rmAddGroupingConstraint(castleSaxony, avoidNatives);
		rmAddGroupingConstraint(castleSaxony, edgeConstraint);
		rmAddGroupingConstraint(castleSaxony, avoidCanyon);

		int castleBavaria = rmCreateGrouping("castle bavaria", "Elector_Bavaria_02");
		rmSetGroupingMinDistance(castleBavaria, rmXFractionToMeters(0.00));
		rmSetGroupingMaxDistance(castleBavaria, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
		rmAddGroupingToClass(castleBavaria, classElectors);
		if (floodedLand != 1)
			rmAddGroupingConstraint(castleBavaria, avoidImpassableLand);
		rmAddGroupingConstraint(castleBavaria, avoidTradeRoute);
		rmAddGroupingConstraint(castleBavaria, avoidTradeRouteSocket);
		rmAddGroupingConstraint(castleBavaria, nativesAvoidPlayers);
		rmAddGroupingConstraint(castleBavaria, avoidElectors);
		rmAddGroupingConstraint(castleBavaria, avoidPiratesShort);
		rmAddGroupingConstraint(castleBavaria, avoidNatives);
		rmAddGroupingConstraint(castleBavaria, edgeConstraint);
		rmAddGroupingConstraint(castleBavaria, avoidCanyon);

		int castleAustria = rmCreateGrouping("castle austria", "Elector_Austria_02");
		rmSetGroupingMinDistance(castleAustria, rmXFractionToMeters(0.00));
		rmSetGroupingMaxDistance(castleAustria, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
		rmAddGroupingToClass(castleAustria, classElectors);
		if (floodedLand != 1)
			rmAddGroupingConstraint(castleAustria, avoidImpassableLand);
		rmAddGroupingConstraint(castleAustria, avoidTradeRoute);
		rmAddGroupingConstraint(castleAustria, avoidTradeRouteSocket);
		rmAddGroupingConstraint(castleAustria, nativesAvoidPlayers);
		rmAddGroupingConstraint(castleAustria, avoidElectors);
		rmAddGroupingConstraint(castleAustria, avoidPiratesShort);
		rmAddGroupingConstraint(castleAustria, avoidNatives);
		rmAddGroupingConstraint(castleAustria, edgeConstraint);
		rmAddGroupingConstraint(castleAustria, avoidCanyon);
		
		int SpawnerID1 = rmCreateObjectDef("Spawner 1");
		rmAddObjectDefItem(SpawnerID1, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(SpawnerID1, 0.00);
		rmSetObjectDefMaxDistance(SpawnerID1, 20.00);

		int SpawnerID2 = rmCreateObjectDef("Spawner 2");
		rmAddObjectDefItem(SpawnerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(SpawnerID2, 0.00);
		rmSetObjectDefMaxDistance(SpawnerID2, 20.00);

		int SpawnerID3 = rmCreateObjectDef("Spawner 3");
		rmAddObjectDefItem(SpawnerID3, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(SpawnerID3, 0.00);
		rmSetObjectDefMaxDistance(SpawnerID3, 20.00);

		int SpawnerID4 = rmCreateObjectDef("Spawner 4");
		rmAddObjectDefItem(SpawnerID4, "zpSPCWaterSpawnPoint", 1, 0.0);
		rmSetObjectDefMinDistance(SpawnerID4, 0.00);
		rmSetObjectDefMaxDistance(SpawnerID4, 20.00);

		if (splitIsland == 1)
		{
			if (rmRandFloat(0,1) <= 0.333)
			{
				rmPlaceGroupingInArea(castleBohemia, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID1, 0, rmAreaID("split island 1"), 1);
				rmPlaceGroupingInArea(castleSaxony, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID2, 0, rmAreaID("split island 1"), 1);
				rmPlaceGroupingInArea(castleBavaria, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID3, 0, rmAreaID("split island 2"), 1);
				rmPlaceGroupingInArea(castleAustria, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID4, 0, rmAreaID("split island 2"), 1);
			}
			else if (rmRandFloat(0,1) <= 0.50)
			{
				rmPlaceGroupingInArea(castleBohemia, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID1, 0, rmAreaID("split island 1"), 1);
				rmPlaceGroupingInArea(castleSaxony, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID2, 0, rmAreaID("split island 2"), 1);
				rmPlaceGroupingInArea(castleBavaria, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID3, 0, rmAreaID("split island 1"), 1);
				rmPlaceGroupingInArea(castleAustria, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID4, 0, rmAreaID("split island 2"), 1);
			}
			else
			{
				rmPlaceGroupingInArea(castleBohemia, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID1, 0, rmAreaID("split island 1"), 1);
				rmPlaceGroupingInArea(castleSaxony, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID2, 0, rmAreaID("split island 2"), 1);
				rmPlaceGroupingInArea(castleBavaria, 0, rmAreaID("split island 2"), 1);
				rmPlaceObjectDefInArea(SpawnerID3, 0, rmAreaID("split island 2"), 1);
				rmPlaceGroupingInArea(castleAustria, 0, rmAreaID("split island 1"), 1);
				rmPlaceObjectDefInArea(SpawnerID4, 0, rmAreaID("split island 1"), 1);
			}
		}
		else
		{
			rmPlaceGroupingAtLoc(castleBohemia, 0, elecX1, elecY1);
			rmPlaceObjectDefAtLoc(SpawnerID1, 0, elecX1, elecY1);
			rmPlaceGroupingAtLoc(castleSaxony, 0, elecX2, elecY2);
			rmPlaceObjectDefAtLoc(SpawnerID2, 0, elecX2, elecY2);
			rmPlaceGroupingAtLoc(castleBavaria, 0, elecX3, elecY3);
			rmPlaceObjectDefAtLoc(SpawnerID3, 0, elecX3, elecY3);
			rmPlaceGroupingAtLoc(castleAustria, 0, elecX4, elecY4);
			rmPlaceObjectDefAtLoc(SpawnerID4, 0, elecX4, elecY4);
		}
	}

	if (tpORnot != 5)
	{
		float tpLoc = 0.00;
		if (tpVariation < 3)
			tpLoc = 0.0625;
		else 
			tpLoc = 0.10;
 
        vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, tpLoc);
        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

		if (tpVariation < 3)
		{
			if (riverExists != 1 && cNumberNonGaiaPlayers > 4 && tpVariation == 1)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.1875);
				rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.3125);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

			if (riverExists != 1 && cNumberNonGaiaPlayers > 6 && tpVariation == 1)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.4375);
				rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5625);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

			if (riverExists != 1 && cNumberNonGaiaPlayers > 4 && tpVariation == 1)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.6875);
				rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.8125);
	        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);

			if (riverExists != 1 && cNumberNonGaiaPlayers > 6 && tpVariation == 1)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.9375);
				rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}
		}
		else
		{
			if (tpVariation > 6 || cNumberNonGaiaPlayers > 4)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.30);
				rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			if (tpVariation > 4 && riverExists != 1)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
		        rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			if (tpVariation > 6 || cNumberNonGaiaPlayers > 4)
			{
				socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.70);
	    	 	rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
			}

			socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.90);
			rmPlaceObjectDefAtPoint(socketID, 0, socketLoc1);
		}
	}

	if (oceanMiddle == 1)
	{
		if (oceanChance == 1 && ahoyMeMatey != 1)
		{
			if ((amazonMap == 1 && treasureIsle == 1) || trollMap == 1 || rmRandFloat(0,1) <= 0.01)
			{
				// Isles
				int islecount = 2+cNumberNonGaiaPlayers; 
				int stayInIsle = -1;
				int IsleMineID = -1;
				int IsleTreeID = -1;
				int IsleCritterID = -1;
				int isleCrateID = -1;
				int crateORnot = -1;
				if (rmRandFloat(0,1) <= 0.50)
					crateORnot = 1;

				for (i= 0; < islecount) 
				{
					int IsleID = rmCreateArea("lake isle"+i);
					rmAddAreaToClass(IsleID, classCliff);
					rmSetAreaSize(IsleID, 0.003);
					rmSetAreaObeyWorldCircleConstraint(IsleID, true);
					rmSetAreaMix(IsleID, landName); 
					rmSetAreaBaseHeight(IsleID, 01);
					rmSetAreaReveal(IsleID, 01);
					rmSetAreaCoherence(IsleID, 0.69);
					rmAddAreaConstraint(IsleID, avoidCliffs);
					rmAddAreaConstraint(IsleID, fishLand);
					rmAddAreaConstraint(IsleID, stayInLake);
	//				rmAddAreaConstraint(IsleID, avoidPond);
					rmSetAreaWarnFailure(IsleID, false);
					rmBuildArea(IsleID);		

					stayInIsle = rmCreateAreaMaxDistanceConstraint("stay in  isle"+i, IsleID, 0.0);

					if (crateORnot == 1)
					{
						isleCrateID = rmCreateObjectDef("lake isle crates"+i);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(isleCrateID, "CrateofCoin", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(isleCrateID, "CrateofFood", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(isleCrateID, "CrateofWood", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(isleCrateID, "deCrateofXP", 1, 3.0);
						rmAddObjectDefItem(isleCrateID, "deCrateofFood50", 1, 3.0);
						rmSetObjectDefMinDistance(isleCrateID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(isleCrateID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(isleCrateID, classForest);
						rmAddObjectDefToClass(isleCrateID, classGold);
						rmAddObjectDefConstraint(isleCrateID, stayInIsle);
						rmAddObjectDefConstraint(isleCrateID, avoidAll);
						rmPlaceObjectDefAtLoc(isleCrateID, 0, 0.50, 0.50, 1);
					}
					else
					{
						IsleMineID = rmCreateObjectDef("lake isle mine "+i);
						if (africanMap == 1 && rmRandFloat(0,1) <= 0.50)
							rmAddObjectDefItem(IsleMineID, "MineSalt", 1, 0.0);
						else
							rmAddObjectDefItem(IsleMineID, mineralz, 1, 1.0);
						rmSetObjectDefMinDistance(IsleMineID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(IsleMineID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(IsleMineID, rmClassID("classForest"));
						rmAddObjectDefConstraint(IsleMineID, stayInIsle);
						rmAddObjectDefConstraint(IsleMineID, avoidAll);
						rmPlaceObjectDefAtLoc(IsleMineID, 0, 0.50, 0.50, 1);

						IsleTreeID = rmCreateObjectDef("lake isle veg"+i);
						if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(IsleTreeID, propz, rmRandInt(1,3), 3.0);
						else
							rmAddObjectDefItem(IsleTreeID, treeName, rmRandInt(1,3), 3.0);
						rmSetObjectDefMinDistance(IsleTreeID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(IsleTreeID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(IsleTreeID, rmClassID("classForest"));
						rmAddObjectDefConstraint(IsleTreeID, stayInIsle);
						rmAddObjectDefConstraint(IsleTreeID, avoidForestMin);
						rmAddObjectDefConstraint(IsleTreeID, avoidAll);
						rmPlaceObjectDefAtLoc(IsleTreeID, 0, 0.50, 0.50, rmRandInt(1,4));

						IsleCritterID = rmCreateObjectDef("lake isle critter"+i);
						rmAddObjectDefItem(IsleCritterID, critterTwoName, rmRandInt(6,9), 5.0);
						rmSetObjectDefMinDistance(IsleCritterID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(IsleCritterID, rmXFractionToMeters(0.50));
						rmAddObjectDefConstraint(IsleCritterID, stayInIsle);
						rmAddObjectDefConstraint(IsleCritterID, avoidAll);
						rmPlaceObjectDefAtLoc(IsleCritterID, 0, 0.50, 0.50, 1);
					}
				}
			}
		}

    	// Fountain of Youth
		int fountainID = rmCreateObjectDef("fountain");
		rmSetObjectDefMinDistance(fountainID, 0);
		rmSetObjectDefMaxDistance(fountainID, 5);
		rmSetObjectDefForceFullRotation(fountainID, true);
		if (fountainChance == 1 && caribbeanMap == 1)
		{
			rmAddObjectDefItem(fountainID, "SPCFountainofYouth", 1, 1.0);
			rmPlaceObjectDefAtLoc(fountainID, 0, 0.50, 0.50);
		}
		if (fountainChance == 1 && oceaniaMap == 1)
		{
			rmAddObjectDefItem(fountainID, "zpWaterFort", 1, 1.0);
			rmPlaceObjectDefAtLoc(fountainID, 0, 0.50, 0.50);
		}
	}

	if (oceanOffCenter == 1)
	{
		if (bayChance == 1 && ahoyMeMatey != 1)
		{
			if ((amazonMap == 1 && treasureIsle == 1) || trollMap == 1 || rmRandFloat(0,1) <= 0.01)
			{
				// Isles
				int unkislecount = 2+cNumberNonGaiaPlayers; 
				int stayInUnkIsle = -1;
				int unkIsleMineID = -1;
				int unkIsleTreeID = -1;
				int unkIsleCritterID = -1;
				int unkIsleCrateID = -1;
				int unkcrateORnot = -1;
				if (rmRandFloat(0,1) <= 0.50)
					unkcrateORnot = 1;

				for (i= 0; < unkislecount) 
				{
					int unkIsleID = rmCreateArea("unknown isle"+i);
					rmAddAreaToClass(unkIsleID, classCliff);
					rmSetAreaSize(unkIsleID, 0.003);
					rmSetAreaObeyWorldCircleConstraint(unkIsleID, false);
					rmSetAreaMix(unkIsleID, landName); 
					rmSetAreaBaseHeight(unkIsleID, 01);
					rmSetAreaReveal(unkIsleID, 01);
					rmSetAreaCoherence(unkIsleID, 0.69);
					rmAddAreaConstraint(unkIsleID, avoidCliffs);
					rmAddAreaConstraint(unkIsleID, edgeConstraintShort);
					rmAddAreaConstraint(unkIsleID, fishLand);
					rmAddAreaConstraint(unkIsleID, stayInBay);
	//				rmAddAreaConstraint(unkIsleID, avoidPond);
					rmSetAreaWarnFailure(unkIsleID, false);
					rmBuildArea(unkIsleID);		

					stayInUnkIsle = rmCreateAreaMaxDistanceConstraint("stay in unk isle"+i, unkIsleID, 0.0);

					if (unkcrateORnot == 1)
					{
						unkIsleCrateID = rmCreateObjectDef("unknown isle crate "+i);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(unkIsleCrateID, "CrateofCoin", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(unkIsleCrateID, "CrateofFood", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(unkIsleCrateID, "CrateofWood", 1, 3.0);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(unkIsleCrateID, "deCrateofXP", 1, 3.0);
						rmAddObjectDefItem(unkIsleCrateID, "deCrateofFood50", 1, 3.0);
						rmSetObjectDefMinDistance(unkIsleCrateID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(unkIsleCrateID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(unkIsleCrateID, classForest);
						rmAddObjectDefToClass(unkIsleCrateID, classGold);
						rmAddObjectDefConstraint(unkIsleCrateID, stayInUnkIsle);
						rmAddObjectDefConstraint(unkIsleCrateID, avoidAll);
						rmPlaceObjectDefAtLoc(unkIsleCrateID, 0, 0.50, 0.50, 1);
					}
					else
					{
						unkIsleMineID = rmCreateObjectDef("unknown isle mine "+i);
						if (africanMap == 1 && rmRandFloat(0,1) <= 0.50)
							rmAddObjectDefItem(unkIsleMineID, "MineSalt", 1, 0.0);
						else
							rmAddObjectDefItem(unkIsleMineID, mineralz, 1, 1.0);
						rmSetObjectDefMinDistance(unkIsleMineID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(unkIsleMineID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(unkIsleMineID, rmClassID("classForest"));
						rmAddObjectDefConstraint(unkIsleMineID, stayInUnkIsle);
						rmAddObjectDefConstraint(unkIsleMineID, avoidAll);
						rmPlaceObjectDefAtLoc(unkIsleMineID, 0, 0.50, 0.50, 1);

						unkIsleTreeID = rmCreateObjectDef("unknown isle veg"+i);
						if (rmRandFloat(0,1) <= 0.001)
							rmAddObjectDefItem(unkIsleTreeID, propz, rmRandInt(1,3), 3.0);
						else
							rmAddObjectDefItem(unkIsleTreeID, treeName, rmRandInt(1,3), 3.0);
						rmSetObjectDefMinDistance(unkIsleTreeID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(unkIsleTreeID, rmXFractionToMeters(0.50));
						rmAddObjectDefToClass(unkIsleTreeID, rmClassID("classForest"));
						rmAddObjectDefConstraint(unkIsleTreeID, stayInUnkIsle);
						rmAddObjectDefConstraint(unkIsleTreeID, avoidForestMin);
						rmAddObjectDefConstraint(unkIsleTreeID, avoidAll);
						rmPlaceObjectDefAtLoc(unkIsleTreeID, 0, 0.50, 0.50, rmRandInt(1,4));

						unkIsleCritterID = rmCreateObjectDef("unknown isle critter"+i);
						rmAddObjectDefItem(unkIsleCritterID, critterTwoName, rmRandInt(6,9), 5.0);
						rmSetObjectDefMinDistance(unkIsleCritterID, rmXFractionToMeters(0.00));
						rmSetObjectDefMaxDistance(unkIsleCritterID, rmXFractionToMeters(0.50));
						rmAddObjectDefConstraint(unkIsleCritterID, stayInUnkIsle);
						rmAddObjectDefConstraint(unkIsleCritterID, avoidAll);
						rmPlaceObjectDefAtLoc(unkIsleCritterID, 0, 0.50, 0.50, 1);
					}
				}
			}
		}
	}

	// check for KOTH game mode
	if(rmGetIsKOTH())
	{
		float xLoc = 0.50;
		float yLoc = 0.50;
		float walk = 0.01;

		int kingIslandID = rmCreateArea("King's Island");
		rmSetAreaSize(kingIslandID, rmAreaTilesToFraction(200));
		rmSetAreaLocation(kingIslandID, xLoc, yLoc);
		rmSetAreaMix(kingIslandID, landName);
		rmAddAreaToClass(kingIslandID, classCliff);
		rmSetAreaReveal(kingIslandID, 01);
		rmSetAreaBaseHeight(kingIslandID, 3.0);
		rmSetAreaCoherence(kingIslandID, 1.0);
		rmBuildArea(kingIslandID); 

		ypKingsHillPlacer(xLoc, yLoc, walk, avoidCliffsShort);
		rmEchoInfo("KOTHXLOC = "+xLoc);
		rmEchoInfo("KOTHYLOC = "+yLoc);
	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 0.60);
	else if (trollBar == 1)
		rmSetStatusText("", 0.7);
	else
		rmSetStatusText("", 0.3);

	// ============= Starting Units =============
	int startingTCID = rmCreateObjectDef("startingTC");
	if (rmGetNomadStart() == true)
	    rmAddObjectDefItem(startingTCID, petName1, 1, 0.0);
	else
	{
//		if (rmRandFloat(0,1) <= 1.00 && euMap == 1)	// for testing
		if (rmRandFloat(0,1) <= 0.10 && euMap == 1)
		{
			rmAddObjectDefItem(startingTCID, "deSPCCommandPost", 1, 0.0);
			commandPost = 1;
		}
		else
			rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0);
	}
	rmSetObjectDefMinDistance(startingTCID, 0.0);
	float TCMax = 20.0;
	// For FFA and nomad, allow more of a float distance.
	if (rmGetNomadStart() == true)
	{
		TCMax = 50.0;
		rmSetObjectDefMaxDistance(startingTCID, TCMax);
	}
	else if (cNumberTeams > 2)
	{
		TCMax = 35.0;
		rmSetObjectDefMaxDistance(startingTCID, TCMax);
	}
	else
		rmSetObjectDefMaxDistance(startingTCID, TCMax);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(startingTCID, TCAvoidImpassableLand);
	if (oceanRing == 1 || (splitIsland == 1 && cNumberTeams == 2))
		rmAddObjectDefConstraint(startingTCID, avoidWaterFarPlus);
	rmAddObjectDefConstraint(startingTCID, avoidElectorsShort);
	rmAddObjectDefConstraint(startingTCID, avoidPiratesShort);
	rmAddObjectDefConstraint(startingTCID, avoidEdgeFar);
	rmAddObjectDefConstraint(startingTCID, avoidTradeRoute);
	rmAddObjectDefConstraint(startingTCID, avoidTradeRouteSocket);
	rmAddObjectDefToClass(startingTCID, classPlayer);

	int startingUnits = -1;
	if (rmGetNomadStart() == true)
	{
		startingUnits = rmCreateStartingUnitsObjectDef(50.0);
		rmSetObjectDefMinDistance(startingUnits, 5.0);
		rmSetObjectDefMaxDistance(startingUnits, 50.0);
		rmAddObjectDefToClass(startingUnits, classPlayer);
	}
	else
	{
		startingUnits = rmCreateStartingUnitsObjectDef(5.0);
		rmSetObjectDefMinDistance(startingUnits, 5.0);
		rmSetObjectDefMaxDistance(startingUnits, 12.0);
	}
	if (floodedLand != 1)
		rmAddObjectDefConstraint(startingUnits, shortAvoidImpassableLand);
	rmAddObjectDefToClass(startingUnits, rmClassID("startingUnit"));

	int whoseUnits = rmRandInt(1,1000);		// RNG for swapping starting units with another civ's
	if (chaosBar == 1 && trollBar == 1 && rmRandFloat(0,1) <= 0.50)
		whoseUnits = 1;
//		whoseUnits = 1;		// for testing

	// Place Starting Units now so other stuff can avoid them
	for(i=1; <cNumberPlayers)
	{
		if (splitIsland == 1)
		{
			if (cNumberTeams == 2)
			{
				rmAddObjectDefConstraint(startingTCID, avoidPlayersSplitIsland);
				if (rmGetPlayerTeam(i) == 0)
					rmPlaceObjectDefInArea(startingTCID, i, rmAreaID("split island 1"), 1);
				else
					rmPlaceObjectDefInArea(startingTCID, i, rmAreaID("split island 2"), 1);
			}
			else
			{
				// Weird Player Islands - from dansil92
				int weirdIsleID = rmCreateArea("playerisle "+i);
				rmSetAreaSize(weirdIsleID, rmAreaTilesToFraction(769));		// 0.2/PlayerNum
				rmSetAreaCoherence(weirdIsleID, 0.69);
				rmSetAreaBaseHeight(weirdIsleID, 1.0);
				rmSetAreaSmoothDistance(weirdIsleID, 8);
				rmSetAreaMix(weirdIsleID, landName);
				rmAddAreaToClass(weirdIsleID, classPlayer);
				rmAddAreaConstraint(weirdIsleID, edgeConstraint);
				rmAddAreaConstraint(weirdIsleID, avoidPlayersSplitIsland);
				rmAddAreaConstraint(weirdIsleID, avoidNatives);
				rmAddAreaConstraint(weirdIsleID, avoidTradeRouteSocket);
				rmAddAreaConstraint(weirdIsleID, avoidTradeRoute);
				rmSetAreaWarnFailure(weirdIsleID, false);
				rmSetAreaObeyWorldCircleConstraint(weirdIsleID, true);
				rmEchoInfo("Player Island "+i);

				int fail=0;
				for (n=2; > fail*1000) // Make sure island gets made somewhere
				{
					fail = rmBuildArea(weirdIsleID);
				}

				rmPlaceObjectDefInArea(startingTCID, i, rmAreaID("playerisle "+i), 1);

    	    	rmAddMapStartingUnit(i, "CoveredWagon");
    			rmSetNumberInitialColonies(2);

				// Increase TC BL by 1
    			rmCreateTrigger("extraTC"+i);
    			rmSwitchToTrigger(rmTriggerID("extraTC"+i));
    			rmSetTriggerActive(true);
    			rmSetTriggerRunImmediately(true);
    			rmSetTriggerPriority(4);

    			rmAddTriggerCondition("Always");
    			rmAddTriggerEffect("Modify Protounit");
    			rmSetTriggerEffectParam("Protounit", "TownCenter");
    			rmSetTriggerEffectParamInt("PlayerID", i);
    			rmSetTriggerEffectParamInt("Field", 10);		// build limit
    			rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}
		}
		else
			rmPlaceObjectDefAtLoc(startingTCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		if (rmGetNomadStart() == true)
		{
			//Starting Villagers
			int villagerID = rmCreateObjectDef("villager"+i);
			if (rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") || rmGetPlayerCiv(i) ==  rmGetCivID("XPAztec") || rmGetPlayerCiv(i) ==  rmGetCivID("DEInca"))
				rmAddObjectDefItem(villagerID, "SettlerNative", 1, 0);
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("Chinese"))
				rmAddObjectDefItem(villagerID, "ypSettlerAsian", 1, 0);
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("Indians"))	
				rmAddObjectDefItem(villagerID, "ypSettlerIndian", 1, 0);
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("Japanese"))	
				rmAddObjectDefItem(villagerID, "ypSettlerJapanese", 1, 0);
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa") || rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians"))	
				rmAddObjectDefItem(villagerID, "deSettlerAfrican", 1, 0);
			else
				rmAddObjectDefItem(villagerID, "Settler", 1, 0);
			rmAddObjectDefToClass(villagerID, rmClassID("startingUnit"));
			rmAddObjectDefToClass(villagerID, classPlayer);
			rmSetObjectDefMinDistance(villagerID, rmXFractionToMeters(0.15));
			rmSetObjectDefMaxDistance(villagerID, rmXFractionToMeters(0.50));
			if (oceanRing == 1 || splitIsland == 1)
				rmAddObjectDefConstraint(villagerID, avoidWaterShort);
			if (floodedLand != 1)
				rmAddObjectDefConstraint(villagerID, shortAvoidImpassableLand);
			rmAddObjectDefConstraint(villagerID, avoidAll);
			rmAddObjectDefConstraint(villagerID, avoidPond);
			rmAddObjectDefConstraint(villagerID, avoidTradeRouteSocketShort);
			rmAddObjectDefConstraint(villagerID, avoidPlayers);
			rmAddObjectDefConstraint(villagerID, avoidCliffsShort);
			rmAddObjectDefConstraint(villagerID, avoidEdgeFar);

			// Place Starting Resources and Objects	
			vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));

			rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
			
			rmPlaceObjectDefAtLoc(villagerID, i, 0.50, 0.50);
			rmPlaceObjectDefAtLoc(villagerID, i, 0.50, 0.50);
			rmPlaceObjectDefAtLoc(villagerID, i, 0.50, 0.50);

			if(ypIsAsian(i))
				rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		}
	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 1.00);
	else if (trollBar == 1)
		rmSetStatusText("", 0.6);
	else
		rmSetStatusText("", 0.4);

	// ============= Place Natives =============
	int unknownVillageID = -1;
	float nativeChance = -1;	// RNG native civ selection
	float natLocX = -1;
	float natLocY = -1;

	// Randomly select each native, counter ensures each native may only be placed twice max
	int counterAkan = -1;
	int counterApac = -1;
	int counterAzte = -1;
	int counterBerb = -1;
	int counterBhak = -1;
	int counterBour = -1;
	int counterCari = -1;
	int counterCher = -1;
	int counterChey = -1;
	int counterComa = -1;
	int counterCree = -1;
	int counterHabs = -1;
	int counterHano = -1;
	int counterHuro = -1;
	int counterInca = -1;
	int counterIroq = -1;
	int counterJagi = -1;
	int counterJesu = -1;
	int counterKlam = -1;
	int counterLako = -1;
	int counterLena = -1;
	int counterMapu = -1;
	int counterMaya = -1;
	int counterNava = -1;
	int counterNoot = -1;
	int counterOlde = -1;
	int counterPhan = -1;
	int counterSemi = -1;
	int counterShao = -1;
	int counterSoma = -1;
	int counterSuda = -1;
	int counterSufi = -1;
	int counterTeng = -1;
	int counterTupi = -1;
	int counterUdas = -1;
	int counterVasa = -1;
	int counterWett = -1;
	int counterWitt = -1;
	int counterYoru = -1;
	int counterZapo = -1;
	int counterZen = -1;
	int counterPen = -1;
	int counterMal = -1;
	int counterJew = -1;
	int counterInu = -1;
	int counterMao = -1;
	int counterOrt = -1;
	int counterWes = -1;
	int counterAbo = -1;
	int counterKor = -1;
	int counterSPCZen = -1;
	int counterSPCSuf = -1;
	int counterSPCJes = -1;
	int counterXmass = -1;
	int counterEzio = -1;
	int counterHussite = -1;
	int counterCossack = -1;
	int orthodoxSpawn = -1;	// 1 for north, 2 for south
	if (rmRandFloat(0,1) <= 0.50)
	    orthodoxSpawn = 1;
	else
	    orthodoxSpawn = 2;
	int habsburgSpawn = -1;	// 1 for spanish, 2 for austrian
	if (rmRandFloat(0,1) <= 0.50)
	    habsburgSpawn = 1;
	else
	    habsburgSpawn = 2;

	int electorNumber = 0;
	if (electorSpawn == 1)
		electorNumber = 2;

	int aopNativeNumber = (rmRandInt(1,3)+(cNumberNonGaiaPlayers/4));
	//	aopNativeNumber = 11;	// for testing

	// aop native exclusive loop
	for(i = 0; <(aopNativeNumber-electorNumber))
	{
		nativeChance = rmRandFloat(0,0.20);
		if (merryXmass == 1 && counterXmass <1)
			nativeChance = 0.13;
//			nativeChance = 0.41;		// for testing

		natLocX = rmRandFloat(0.05,0.95);
		natLocY = rmRandFloat(0.05,0.95);

		if(nativeChance < 0.01 && counterAzte < 1)
		{
			rmEchoInfo("subCiv"+i+" is Aztecs");
			unknownVillageID = rmCreateGrouping("aztec village AOP"+i, "aztec_temple_0"+rmRandInt(1,4));
			counterAzte++;
		}
		else if(nativeChance < 0.02 && counterSufi < 1)
		{
			rmEchoInfo("subCiv"+i+" is spc sufi");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc sufi village AOP"+i, "sufi_greatmosque_0"+rmRandInt(1,4));
			else
			{
				SPCSufiMiddleEast = 1;
				unknownVillageID = rmCreateGrouping("spc sufi village AOP"+i, "sufibluemosque_0"+rmRandInt(1,3));
			}
			counterSufi++;
		}
		else if(nativeChance < 0.03 && counterZen < 0)
		{
			rmEchoInfo("subCiv"+i+" is spc zen");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc zen village AOP"+i, "zen_greatbuddha_0"+rmRandInt(1,3));
			else
			{
				SPCZenMountain = 1;
				unknownVillageID = rmCreateGrouping("spc zen village AOP"+i, "zen_mountain_0"+rmRandInt(1,3));
			}
			counterZen++;
		}
		else if(nativeChance < 0.04 && counterJesu < 1)
		{
			rmEchoInfo("subCiv"+i+" is spc jesuit");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc jesuit village AOP"+i, "jesuit_cathedral_eu_0"+rmRandInt(1,3));
			else
				unknownVillageID = rmCreateGrouping("spc jesuit village AOP"+i, "jesuit_cathedral_tropic_0"+rmRandInt(1,3));
			counterJesu++;
		}
		else if(nativeChance < 0.05 && counterPen < 1)
		{
			rmEchoInfo("subCiv"+i+" is PenalColony");
			unknownVillageID = rmCreateGrouping("penal colony AOP"+i, "penal_colony_0"+rmRandInt(1,5));
			counterPen++;
		}
		else if(nativeChance < 0.06 && counterMal < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maltese");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("maltese village AOP"+i, "maltese_village0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("maltese village AOP"+i, "maltese_village_me0"+rmRandInt(1,3));
			counterMal++;
		}
		else if(nativeChance < 0.07 && counterJew < 1)
		{
			rmEchoInfo("subCiv"+i+" is Jewish");
			unknownVillageID = rmCreateGrouping("jewish settlement AOP"+i, "jewish_settlement_0"+rmRandInt(1,5));
			counterJew++;
		}
		else if(nativeChance < 0.08 && counterInu < 1)
		{
			rmEchoInfo("subCiv"+i+" is Inuit");
			unknownVillageID = rmCreateGrouping("inuit village AOP"+i, "native inuit village 0"+rmRandInt(1,5));
			counterInu++;
		}
		else if(nativeChance < 0.09 && counterMao < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maori");
			unknownVillageID = rmCreateGrouping("inuit village AOP"+i, "maori_tropic_0"+rmRandInt(1,5));
			counterMao++;
		}
		else if(nativeChance < 0.10 && counterOrt < 0)
		{
			rmEchoInfo("subCiv"+i+" is Orthodox");
			if (orthodoxSpawn == 1)
				unknownVillageID = rmCreateGrouping("orthodox monastery AOP"+i, "orthodox_monastery0"+rmRandInt(1,6));
			else
				unknownVillageID = rmCreateGrouping("orthodox monastery AOP"+i, "orthodox_south_0"+rmRandInt(1,3));
			counterOrt++;
		}
		else if(nativeChance < 0.11 && counterWes < 1)
		{
			rmEchoInfo("subCiv"+i+" is Wild West");
			if (rmRandFloat(0,1) <= 0.5)
				unknownVillageID = rmCreateGrouping("wild west village AOP"+i, "wildwest_village_0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("wild west village AOP"+i, "wildwest_village_east_0"+rmRandInt(1,5));
			counterWes++;
		}
		else if(nativeChance < 0.12 && counterAbo < 1)
		{
			rmEchoInfo("subCiv"+i+" is Aboriginal");
			unknownVillageID = rmCreateGrouping("aboriginal village AOP"+i, "native_aboriginal_0"+rmRandInt(1,5));
			counterAbo++;
		}
		else if(nativeChance < 0.13 && counterKor < 1)
		{
			rmEchoInfo("subCiv"+i+" is Korowai");
			unknownVillageID = rmCreateGrouping("korowai village AOP"+i, "korowai_village_0"+rmRandInt(1,5));
			counterKor++;
		}
		else if(nativeChance < 0.14 && counterXmass < 1)
		{
			rmEchoInfo("subCiv"+i+" is xmass");
			unknownVillageID = rmCreateGrouping("xmass village AOP"+i, "xmass_village0"+rmRandInt(1,3));
			counterXmass++;
		}
		else if(nativeChance < 0.15 && counterBour < 1)
		{
			rmEchoInfo("subCiv"+i+" is SPC Bourbon");
			unknownVillageID = rmCreateGrouping("Bourbon village AOP"+i, "Natives_SPCBourbon_0"+rmRandInt(1,3));
			counterBour++;
		}
		else if(nativeChance < 0.16 && counterEzio < 1)
		{
			rmEchoInfo("subCiv"+i+" is Auditore");
			unknownVillageID = rmCreateGrouping("Auditore village AOP"+i, "palace_auditore_0"+rmRandInt(1,3));
			counterEzio++;
		}
		else if(nativeChance < 0.17 && counterHussite < 1)
		{
			rmEchoInfo("subCiv"+i+" is Hussite");
			unknownVillageID = rmCreateGrouping("Hussite village AOP"+i, "hussite_camp_0"+rmRandInt(1,5));
			counterHussite++;
		}
		else if(nativeChance < 0.18 && counterMaya < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maya");
			unknownVillageID = rmCreateGrouping("Maya village AOP"+i, "maya_town_0"+rmRandInt(1,3));
			counterMaya++;
		}
		else if(nativeChance < 0.19 && counterCossack < 1)
		{
			rmEchoInfo("subCiv"+i+" is Cossacks");
			unknownVillageID = rmCreateGrouping("Cossacks camp AOP"+i, "Cossack_Camp_0"+rmRandInt(1,5));
			counterCossack++;
		}
		else if(nativeChance < 0.20 && counterHabs < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Habsburg");
			if (habsburgSpawn == 1)
				unknownVillageID = rmCreateGrouping("spanish habsburg"+i, "zpHabsburg_SP_0"+rmRandInt(1,3));
			else
				unknownVillageID = rmCreateGrouping("austrian habsburg"+i, "zpHabsburg_AU_0"+rmRandInt(1,3));
			counterHabs++;
		}
		else // this is there to still have as much native tps as decided because some can not spawn if you have already 2. Thx Riki.
		{
			aopNativeNumber++;
		}	
		rmAddGroupingToClass(unknownVillageID, rmClassID("natives"));
		if (floodedLand != 1)
			rmAddGroupingConstraint(unknownVillageID, avoidImpassableLand);
		rmAddGroupingConstraint(unknownVillageID, avoidTradeRoute);
		rmAddGroupingConstraint(unknownVillageID, avoidTradeRouteSocket);
		rmAddGroupingConstraint(unknownVillageID, nativesAvoidPlayers);
		rmAddGroupingConstraint(unknownVillageID, avoidElectors);
		rmAddGroupingConstraint(unknownVillageID, avoidPiratesMed);
		rmAddGroupingConstraint(unknownVillageID, avoidNatives);
		rmAddGroupingConstraint(unknownVillageID, edgeConstraint);
		rmAddGroupingConstraint(unknownVillageID, avoidCanyon);
//		if (oceanOffCenter != 1)
//		{
//			rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
//			rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
//			if (rmRandFloat(0,1) <= 0.50)
//			{
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, natLocX, natLocY);
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, natLocY, natLocX);
//			}
//			else
//			{
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, 1-natLocX, 1-natLocY);
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, 1-natLocY, 1-natLocX);
//			}
//		}
//		else
//		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
				rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.20+0.005*cNumberNonGaiaPlayers));
				if (splitIsland == 1)
				{
					rmPlaceGroupingInArea(unknownVillageID, 0, rmAreaID("split island 1"), 1);
					rmPlaceGroupingInArea(unknownVillageID, 0, rmAreaID("split island 2"), 1);
				}
				else
				{
					rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.25, 0.25);
					rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.75, 0.75);
				}
			}
			else
			{
				rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
				rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.20+0.005*cNumberNonGaiaPlayers));
				if (splitIsland == 1)
				{
					rmPlaceGroupingInArea(unknownVillageID, 0, rmAreaID("split island 1"), 1);
					rmPlaceGroupingInArea(unknownVillageID, 0, rmAreaID("split island 2"), 1);
				}
				else
				{
					rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.25, 0.75);
					rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.75, 0.25);
				}
			}
//		}
	}

	// all native loop
	int pirateNumber = 0;
	if (ahoyMeMatey == 1)
		pirateNumber = 1;

	for(i = 0; <(nativeNumber-aopNativeNumber-pirateNumber-electorNumber))
	{
		nativeChance = rmRandFloat(0,0.54);
//			nativeChance = 0.41;		// for testing

		natLocX = rmRandFloat(0.05,0.95);
		natLocY = rmRandFloat(0.05,0.95);

		if(nativeChance < 0.01 && counterBour < 1)
		{
			rmEchoInfo("subCiv"+i+" is SPC Bourbon");
			unknownVillageID = rmCreateGrouping("Bourbon village "+i, "Natives_SPCBourbon_0"+rmRandInt(1,3));
			counterBour++;
		}
		else if(nativeChance < 0.02 && counterHabs < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Habsburg");
			if (habsburgSpawn == 1)
				unknownVillageID = rmCreateGrouping("spanish habsburg"+i, "zpHabsburg_SP_0"+rmRandInt(1,3));
			else
				unknownVillageID = rmCreateGrouping("austrian habsburg"+i, "zpHabsburg_AU_0"+rmRandInt(1,3));
			counterHabs++;
		}
		else if(nativeChance < 0.03 && counterHano < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Hanover");
			unknownVillageID = rmCreateGrouping("Hanover village "+i, "european\native eu hanover village central "+rmRandInt(1,7));
			counterHano++;
		}
		else if(nativeChance < 0.04 && counterJagi < 1)
		{
			rmEchoInfo("subCiv"+i+" is Jagiellon");
			unknownVillageID = rmCreateGrouping("Jagiellon village "+i, "european\native eu jagiellon village central "+rmRandInt(1,7));
			counterJagi++;
		}
		else if(nativeChance < 0.05 && counterOlde < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Oldenburg");
			unknownVillageID = rmCreateGrouping("Oldenburg village "+i, "european\native eu oldenburg village central "+rmRandInt(1,7));
			counterOlde++;
		}
		else if(nativeChance < 0.06 && counterPhan < 1)
		{
			rmEchoInfo("subCiv"+i+" is Phanar");
			unknownVillageID = rmCreateGrouping("Phanar village "+i, "european\native eu phanar village italian "+rmRandInt(1,7));
			counterPhan++;
		}
		else if(nativeChance < 0.07 && counterVasa < 1)
		{
			rmEchoInfo("subCiv"+i+" is Vasa");
			unknownVillageID = rmCreateGrouping("Vasa village "+i, "european\native eu vasa village central "+rmRandInt(1,7));
			counterVasa++;
		}
		else if(nativeChance < 0.08 && counterWett < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Wettin");
			unknownVillageID = rmCreateGrouping("Wettin village "+i, "european\native eu wettin village central "+rmRandInt(1,7));
			counterWett++;
		}
		else if(nativeChance < 0.09 && counterWitt < 1 && electorSpawn < 1)
		{
			rmEchoInfo("subCiv"+i+" is Wittelsbach");
			unknownVillageID = rmCreateGrouping("Wittelsbach village "+i, "european\native eu wittelsbach village central "+rmRandInt(1,7));
			counterWitt++;
		}
		else if(nativeChance < 0.10 && counterTeng < 1)
		{
			rmEchoInfo("subCiv"+i+" is Tengri");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("tengri village "+i, "native tengri village 0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("tengri village "+i, "native tengri village snow 0"+rmRandInt(1,5));
			counterTeng++;
		}
		else if(nativeChance < 0.11 && counterAzte < 1)
		{
			rmEchoInfo("subCiv"+i+" is Aztecs");
			unknownVillageID = rmCreateGrouping("aztec village "+i, "aztec_temple_0"+rmRandInt(1,4));
			counterAzte++;
		}
		else if(nativeChance < 0.12 && counterLako < 1)
		{
			rmEchoInfo("subCiv"+i+" is Lakota");
			unknownVillageID = rmCreateGrouping("lakota village "+i, "native lakota village "+rmRandInt(1,5));
			counterLako++;
		}
		else if(nativeChance < 0.13 && counterIroq < 1)
		{
			rmEchoInfo("subCiv"+i+" is Haudenosaunee");
			unknownVillageID = rmCreateGrouping("haudenosaunee village "+i, "native iroquois village "+rmRandInt(1,5));
			counterIroq++;
		}
		else if(nativeChance < 0.14 && counterZapo < 1)
		{
			rmEchoInfo("subCiv"+i+" is Zapotec");
			unknownVillageID = rmCreateGrouping("zapotec village "+i, "native zapotec village "+rmRandInt(1,5));
			counterZapo++;
		}
		else if(nativeChance < 0.15 && counterApac < 1)
		{
			rmEchoInfo("subCiv"+i+" is Apache");
			unknownVillageID = rmCreateGrouping("apache village "+i, "native apache village "+rmRandInt(1,5));
			counterApac++;
		}
		else if(nativeChance < 0.16 && counterLena < 1)
		{
			rmEchoInfo("subCiv"+i+" is Lenape");
			unknownVillageID = rmCreateGrouping("lenape village "+i, "native lenape village "+rmRandInt(1,5));
			counterLena++;
		}
		else if(nativeChance < 0.17 && counterSoma < 1)
		{
			rmEchoInfo("subCiv"+i+" is Somali");
			unknownVillageID = rmCreateGrouping("somali village "+i, "native af somali village "+rmRandInt(1,5));
			counterSoma++;
		}
		else if(nativeChance < 0.18 && counterBerb < 1)
		{
			rmEchoInfo("subCiv"+i+" is Berbers");
			unknownVillageID = rmCreateGrouping("berber village "+i, "native af berber village "+rmRandInt(1,5));
			counterBerb++;
		}
		else if(nativeChance < 0.19 && counterSuda < 1)
		{
			rmEchoInfo("subCiv"+i+" is Sudanese");
			unknownVillageID = rmCreateGrouping("sudanese village "+i, "native af sudanese village "+rmRandInt(1,5));
			counterSuda++;
		}
		else if(nativeChance < 0.20 && counterYoru < 1)
		{
			rmEchoInfo("subCiv"+i+" is Yoruba");
			unknownVillageID = rmCreateGrouping("yoruba village "+i, "native af yoruba village "+rmRandInt(1,5));
			counterYoru++;
		}
		else if(nativeChance < 0.21 && counterAkan < 1)
		{
			rmEchoInfo("subCiv"+i+" is Akan");
			unknownVillageID = rmCreateGrouping("akan village "+i, "native af akan village "+rmRandInt(1,5));
			counterAkan++;
		}
		else if(nativeChance < 0.22 && counterShao < 1)
		{
			rmEchoInfo("subCiv"+i+" is Shaolin");
			unknownVillageID = rmCreateGrouping("Shaolin village "+i, "native shaolin temple mongol 0"+rmRandInt(1,5));
			counterShao++;
		}
		else if(nativeChance < 0.23 && counterSufi < 1)
		{
			rmEchoInfo("subCiv"+i+" is spc sufi");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc sufi village "+i, "sufi_greatmosque_0"+rmRandInt(1,4));
			else
			{
				SPCSufiMiddleEast = 1;
				unknownVillageID = rmCreateGrouping("spc sufi village "+i, "sufibluemosque_0"+rmRandInt(1,3));
			}
			counterSufi++;
		}
		else if(nativeChance < 0.24 && counterZen < 0)
		{
			rmEchoInfo("subCiv"+i+" is spc zen");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc zen village "+i, "zen_greatbuddha_0"+rmRandInt(1,3));
			else
			{
				SPCZenMountain = 1;
				unknownVillageID = rmCreateGrouping("spc zen village "+i, "zen_mountain_0"+rmRandInt(1,3));
			}
			counterZen++;
		}
		else if(nativeChance < 0.25 && counterJesu < 1)
		{
			rmEchoInfo("subCiv"+i+" is spc jesuit");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("spc jesuit village "+i, "jesuit_cathedral_eu_0"+rmRandInt(1,3));
			else
				unknownVillageID = rmCreateGrouping("spc jesuit village "+i, "jesuit_cathedral_tropic_0"+rmRandInt(1,3));
			counterJesu++;
		}
		else if(nativeChance < 0.26 && counterUdas < 1)
		{
			rmEchoInfo("subCiv"+i+" is Udasi");
			unknownVillageID = rmCreateGrouping("Udasi village "+i, "native Udasi village "+rmRandInt(1,5));
			counterUdas++;
		}
		else if(nativeChance < 0.27 && counterBhak < 1)
		{
			rmEchoInfo("subCiv"+i+" is Bhakti");
			unknownVillageID = rmCreateGrouping("Bhakti village "+i, "native Bhakti village "+rmRandInt(1,5));
			counterBhak++;
		}
		else if(nativeChance < 0.28 && counterCari < 1)
		{
			rmEchoInfo("subCiv"+i+" is Caribs");
			unknownVillageID = rmCreateGrouping("carib village "+i, "native carib village "+rmRandInt(1,5));
			counterCari++;
		}
		else if(nativeChance < 0.29 && counterHuro < 1)
		{
			rmEchoInfo("subCiv"+i+" is Huron");
			unknownVillageID = rmCreateGrouping("huron village "+i, "native huron village "+rmRandInt(1,5));
			counterHuro++;
		}	
		else if(nativeChance < 0.30 && counterCher < 1)
		{
			rmEchoInfo("subCiv"+i+" is Cherokee");
			unknownVillageID = rmCreateGrouping("cherokee village "+i, "native cherokee village "+rmRandInt(1,5));
			counterCher++;
		}
		else if(nativeChance < 0.31 && counterComa < 1)
		{	
			rmEchoInfo("subCiv"+i+" is Comanche");
			unknownVillageID = rmCreateGrouping("comanche village "+i, "native comanche village "+rmRandInt(1,5));
			counterComa++;
		}
		else if(nativeChance < 0.32 && counterCree < 1)
		{
			rmEchoInfo("subCiv"+i+" is Cree");
			unknownVillageID = rmCreateGrouping("cree village "+i, "native cree village "+rmRandInt(1,5));
			counterCree++;
		}	
		else if(nativeChance < 0.33 && counterInca < 1)
		{
			rmEchoInfo("subCiv"+i+" is Incas");
			unknownVillageID = rmCreateGrouping("inca village "+i, "native inca village "+rmRandInt(1,5));
			counterInca++;
		}	
		else if(nativeChance < 0.34 && counterMapu < 1)
		{
			rmEchoInfo("subCiv"+i+" is Mapuche");
			unknownVillageID = rmCreateGrouping("mapuche village "+i, "native mapuche village "+rmRandInt(1,5));
			counterMapu++;
		}	
		else if(nativeChance < 0.35 && counterKlam < 1)
		{
			rmEchoInfo("subCiv"+i+" is Klamath");
			unknownVillageID = rmCreateGrouping("klamath village "+i, "native klamath village "+rmRandInt(1,5));
			counterKlam++;
		}	
		else if(nativeChance < 0.36 && counterChey < 1)
		{
			rmEchoInfo("subCiv"+i+" is Cheyenne");
			unknownVillageID = rmCreateGrouping("cheyenne village "+i, "native cheyenne village "+rmRandInt(1,5));
			counterChey++;
		}		
		else if(nativeChance < 0.37 && counterMaya < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maya");
			unknownVillageID = rmCreateGrouping("Maya village "+i, "maya_town_0"+rmRandInt(1,3));
			counterMaya++;
		}
		else if(nativeChance < 0.38 && counterNoot < 1)
		{
			rmEchoInfo("subCiv"+i+" is Nootka");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("nootka village "+i, "native nootka village "+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("nootka village "+i, "native nootka village snow "+rmRandInt(1,5));
			counterNoot++;
		}	
		else if(nativeChance < 0.39 && counterNava < 1)
		{
			rmEchoInfo("subCiv"+i+" is Navajo");
			unknownVillageID = rmCreateGrouping("navajo village "+i, "native navajo village "+rmRandInt(1,5));
			counterNava++;
		}	
		else if(nativeChance < 0.40 && counterSemi < 1)
		{
			rmEchoInfo("subCiv"+i+" is Seminoles");
			unknownVillageID = rmCreateGrouping("seminoles village "+i, "native seminole village "+rmRandInt(1,5));
			counterSemi++;
		}		
		else if(nativeChance < 0.41 && counterTupi < 1)
		{
			rmEchoInfo("subCiv"+i+" is Tupi");
			unknownVillageID = rmCreateGrouping("tupi village "+i, "native tupi village "+rmRandInt(1,5));
			counterTupi++;
		}
		else if(nativeChance < 0.42 && counterPen < 1)
		{
			rmEchoInfo("subCiv"+i+" is PenalColony");
			unknownVillageID = rmCreateGrouping("penal colony "+i, "penal_colony_0"+rmRandInt(1,5));
			counterPen++;
		}
		else if(nativeChance < 0.43 && counterMal < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maltese");
			if (rmRandFloat(0,1) <= 0.50)
				unknownVillageID = rmCreateGrouping("maltese village "+i, "maltese_village0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("maltese village "+i, "maltese_village_me0"+rmRandInt(1,3));
			counterMal++;
		}
		else if(nativeChance < 0.44 && counterJew < 1)
		{
			rmEchoInfo("subCiv"+i+" is Jewish");
			unknownVillageID = rmCreateGrouping("jewish settlement "+i, "jewish_settlement_0"+rmRandInt(1,5));
			counterJew++;
		}
		else if(nativeChance < 0.45 && counterInu < 1)
		{
			rmEchoInfo("subCiv"+i+" is Inuit");
			unknownVillageID = rmCreateGrouping("inuit village "+i, "native inuit village 0"+rmRandInt(1,5));
			counterInu++;
		}
		else if(nativeChance < 0.46 && counterMao < 1)
		{
			rmEchoInfo("subCiv"+i+" is Maori");
			if (rmRandFloat(0,1) <= 0.333)
				unknownVillageID = rmCreateGrouping("inuit village "+i, "maori_village_0"+rmRandInt(1,5));
			else if (rmRandFloat(0,1) <= 0.500)
				unknownVillageID = rmCreateGrouping("inuit village "+i, "maori_hawaii_0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("inuit village "+i, "maori_tropic_0"+rmRandInt(1,5));
			counterMao++;
		}
		else if(nativeChance < 0.47 && counterOrt < 0)
		{
			rmEchoInfo("subCiv"+i+" is Orthodox");
			if (orthodoxSpawn == 1)
				unknownVillageID = rmCreateGrouping("orthodox monastery 9"+i, "orthodox_monastery0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("orthodox monastery 9"+i, "orthodox_south_0"+rmRandInt(1,3));
			counterOrt++;
		}
		else if(nativeChance < 0.48 && counterWes < 1)
		{
			rmEchoInfo("subCiv"+i+" is Wild West");
			if (rmRandFloat(0,1) <= 0.5)
				unknownVillageID = rmCreateGrouping("wild west village "+i, "wildwest_village_0"+rmRandInt(1,5));
			else
				unknownVillageID = rmCreateGrouping("wild west village "+i, "wildwest_village_east_0"+rmRandInt(1,5));
			counterWes++;
		}
		else if(nativeChance < 0.49 && counterAbo < 1)
		{
			rmEchoInfo("subCiv"+i+" is Aboriginal");
			unknownVillageID = rmCreateGrouping("aboriginal village "+i, "native_aboriginal_0"+rmRandInt(1,5));
			counterAbo++;
		}
		else if(nativeChance < 0.50 && counterKor < 1)
		{
			rmEchoInfo("subCiv"+i+" is Korowai");
			unknownVillageID = rmCreateGrouping("korowai village "+i, "korowai_village_0"+rmRandInt(1,5));
			counterKor++;
		}
		else if(nativeChance < 0.51 && counterXmass < 1)
		{
			rmEchoInfo("subCiv"+i+" is xmass");
			unknownVillageID = rmCreateGrouping("xmass village "+i, "xmass_village0"+rmRandInt(1,3));
			counterXmass++;
		}
		else if(nativeChance < 0.52 && counterEzio < 1)
		{
			rmEchoInfo("subCiv"+i+" is Auditore");
			unknownVillageID = rmCreateGrouping("Auditore village "+i, "palace_auditore_0"+rmRandInt(1,3));
			counterEzio++;
		}
		else if(nativeChance < 0.53 && counterHussite < 1)
		{
			rmEchoInfo("subCiv"+i+" is Hussite");
			unknownVillageID = rmCreateGrouping("Hussite village "+i, "hussite_camp_0"+rmRandInt(1,5));
			counterHussite++;
		}
		else if(nativeChance < 0.54 && counterCossack < 1)
		{
			rmEchoInfo("subCiv"+i+" is Cossacks");
			unknownVillageID = rmCreateGrouping("Cossacks camp AOP"+i, "Cossack_Camp_0"+rmRandInt(1,5));
			counterCossack++;
		}
		else // this is there to still have as much native tps as decided because some can not spawn if you have already 2. Thx Riki.
		{
			nativeNumber++;
		}	
		rmAddGroupingToClass(unknownVillageID, rmClassID("natives"));
		if (floodedLand != 1)
			rmAddGroupingConstraint(unknownVillageID, avoidImpassableLand);
		rmAddGroupingConstraint(unknownVillageID, avoidTradeRoute);
		rmAddGroupingConstraint(unknownVillageID, avoidTradeRouteSocket);
		rmAddGroupingConstraint(unknownVillageID, nativesAvoidPlayers);
		rmAddGroupingConstraint(unknownVillageID, avoidElectors);
		rmAddGroupingConstraint(unknownVillageID, avoidPiratesMed);
		rmAddGroupingConstraint(unknownVillageID, avoidNatives);
		rmAddGroupingConstraint(unknownVillageID, edgeConstraint);
		rmAddGroupingConstraint(unknownVillageID, avoidCanyon);
//		if (oceanOffCenter != 1)
//		{
//			rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
//			rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.10+0.005*cNumberNonGaiaPlayers));
//			if (rmRandFloat(0,1) <= 0.50)
//			{
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, natLocX, natLocY);
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, natLocY, natLocX);
//			}
//			else
//			{
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, 1-natLocX, 1-natLocY);
//				rmPlaceGroupingAtLoc(unknownVillageID, 0, 1-natLocY, 1-natLocX);
//			}
//		}
//		else
//		{
			if (rmRandFloat(0,1) <= 0.50)
			{
				rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
				rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.20+0.005*cNumberNonGaiaPlayers));
				rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.25, 0.25);
				rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.75, 0.75);
			}
			else
			{
				rmSetGroupingMinDistance(unknownVillageID, rmXFractionToMeters(0.00));
				rmSetGroupingMaxDistance(unknownVillageID, rmXFractionToMeters(0.20+0.005*cNumberNonGaiaPlayers));
				rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.25, 0.75);
				rmPlaceGroupingAtLoc(unknownVillageID, 0, 0.75, 0.25);
			}
//		}
	}

	// Load Bar, sometimes used for a bit of fun RNG
	rmSetStatusText("", 0.5);

	// ============= Add Ponds or Cliffs =============
	if(rmRandFloat(0,1) < 0.111 && riverExists == -1 && rmGetIsKOTH() == false)
	{
		rmEchoInfo("ponds exist");
		int numPonds = cNumberNonGaiaPlayers+rmRandInt(1, 2);		// determines number of ponds/cliffs which can spawn around map
		if (trollMap == 1 || rmRandFloat(0,1) <= 0.001)
		{
			for (i=0; < 2+cNumberNonGaiaPlayers)
			{
				// None Shall Pass
				int impassIslandID = rmCreateArea("impasse island"+i);
				rmSetAreaSize(impassIslandID, 0.0125-0.001*cNumberNonGaiaPlayers);
				rmSetAreaTerrainType(impassIslandID, "texas\nonpassable_temp"); 
				rmSetAreaWarnFailure(impassIslandID, false);
				rmSetAreaCoherence(impassIslandID, 0.85);
				rmSetAreaObeyWorldCircleConstraint(impassIslandID, true);
				rmAddAreaToClass(impassIslandID, pondClass);
				rmAddAreaConstraint(impassIslandID, pondConstraint);
				rmAddAreaConstraint(impassIslandID, avoidPlayersFar);
				rmAddAreaConstraint(impassIslandID, avoidElectorsMed);
				rmAddAreaConstraint(impassIslandID, avoidPiratesMed);
				rmAddAreaConstraint(impassIslandID, avoidNatives);
				if (floodedLand != 1)
					rmAddAreaConstraint(impassIslandID, shortAvoidImpassableLand);
				rmAddAreaConstraint(impassIslandID, avoidCanyon);
				rmAddAreaConstraint(impassIslandID, edgeConstraint);
				rmAddAreaConstraint(impassIslandID, avoidTradeRouteSocket);
				rmAddAreaConstraint(impassIslandID, avoidTradeRoute);
				rmAddAreaConstraint(impassIslandID, avoidGoldMin);
				rmBuildArea(impassIslandID);
			}
		}
		else if (floodedLand != 1)
		{
			for(i=0; < numPonds)
			{
				int smallPondID = rmCreateArea("small pond "+i);
				rmSetAreaSize(smallPondID, rmAreaTilesToFraction(69), rmAreaTilesToFraction(207));
				if (rmRandFloat(0,1) <= 0.50)
				{
					rmSetAreaWaterType(smallPondID, pondName);
					rmSetAreaBaseHeight(smallPondID, 4);
				}
				else
				{
	  				rmSetAreaCliffType(smallPondID, cliffName);
      				rmSetAreaCliffEdge(smallPondID, 1, 1);
      				rmSetAreaCliffPainting(smallPondID, false, true, true, 1.5, true);
					if (rmRandFloat(0,1) <= 0.50)
	      				rmSetAreaCliffHeight(smallPondID, rmRandInt(5,8), 2.0, 0.5);
      				else
						rmSetAreaCliffHeight(smallPondID, rmRandInt(-5,-8), 2.0, 0.5);
				}
				rmAddAreaToClass(smallPondID, pondClass);
				rmSetAreaCoherence(smallPondID, 0.5);
				rmAddAreaConstraint(smallPondID, pondConstraint);
				rmAddAreaConstraint(smallPondID, avoidPlayersFar);
				rmAddAreaConstraint(smallPondID, avoidElectorsMed);
				rmAddAreaConstraint(smallPondID, avoidPiratesMed);
				rmAddAreaConstraint(smallPondID, avoidNatives);
				rmAddAreaConstraint(smallPondID, shortAvoidImpassableLand);
				rmAddAreaConstraint(smallPondID, avoidCanyon);
				rmAddAreaConstraint(smallPondID, edgeConstraint);
				rmAddAreaConstraint(smallPondID, avoidTradeRouteSocket);
				rmAddAreaConstraint(smallPondID, avoidGoldMin);
				rmAddAreaConstraint(smallPondID, avoidAll);
				rmAddAreaConstraint(smallPondID, avoidTradeRoute);
				rmSetAreaWarnFailure(smallPondID, false);
				rmBuildArea(smallPondID);
			}
		}
	}

	// place flag ponds for neater water flag placement - saguenay, great lakes, borneo, caribbean, and amazonia styles
	if ((oceanOffCenter == 1 && bayChance == 1) || (oceanMiddle == 1 && oceanChance == 1) || oceanRing == 1 || splitIsland == 1 || (riverWidthController != 1 && riverExists == 1))
	{
		int flagPondID1 = rmCreateArea("flag pond 1");
		rmSetAreaSize(flagPondID1, 0.002);
		rmSetAreaObeyWorldCircleConstraint(flagPondID1, true);
//		rmSetAreaMix(flagPondID1, "testmix"); 	// for testing
//		rmSetAreaBaseHeight(flagPondID1, 01);	// for testing
		rmSetAreaCoherence(flagPondID1, 1.0);
		rmAddAreaConstraint(flagPondID1, edgeConstraintShort);
		rmAddAreaConstraint(flagPondID1, whaleLand);
		rmAddAreaConstraint(flagPondID1, avoidPiratesShort);
		if (riverExists == 1 && riverWidthController != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID1, avoidCenterMin);
		if (oceanOffCenter == 1 && oceanMiddle != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID1, stayInBay);
		if (oceanRing == 1)
		{
			rmAddAreaConstraint(flagPondID1, stayNorFar);
			if (riverExists == 1)
				rmAddAreaConstraint(flagPondID1, avoidCenterFlag);
		}
		if (oceanMiddle == 1 && oceanOffCenter != 1 && oceanRing != 1)
		{
			rmAddAreaConstraint(flagPondID1, stayInLake);
			rmAddAreaConstraint(flagPondID1, stayNor);
		}
		if (splitIsland == 1)
			rmAddAreaConstraint(flagPondID1, stayCenter);
		rmSetAreaWarnFailure(flagPondID1, false);
		rmBuildArea(flagPondID1);		

		int flagPondID2 = rmCreateArea("flag pond 2");
		rmSetAreaSize(flagPondID2, 0.0015);
		rmSetAreaObeyWorldCircleConstraint(flagPondID2, true);
//		rmSetAreaMix(flagPondID2, "testmix"); 	// for testing
//		rmSetAreaBaseHeight(flagPondID2, 01);	// for testing
		rmSetAreaCoherence(flagPondID2, 1.0);
		rmAddAreaConstraint(flagPondID2, edgeConstraintShort);
		rmAddAreaConstraint(flagPondID2, whaleLand);
		rmAddAreaConstraint(flagPondID2, avoidPiratesShort);
		if (riverExists == 1 && riverWidthController != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID2, avoidCenterMin);
		if (oceanOffCenter == 1 && oceanMiddle != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID2, stayInBay);
		if (oceanRing == 1)
		{
			rmAddAreaConstraint(flagPondID2,stayEstFar);
			if (riverExists == 1)
				rmAddAreaConstraint(flagPondID2, avoidCenterFlag);
		}
		if (oceanMiddle == 1 && oceanOffCenter != 1 && oceanRing != 1)
		{
			rmAddAreaConstraint(flagPondID2, stayInLake);
			rmAddAreaConstraint(flagPondID2,stayEst);
		}
		if (splitIsland == 1)
			rmAddAreaConstraint(flagPondID2, stayCenter);
		rmSetAreaWarnFailure(flagPondID2, false);
		rmBuildArea(flagPondID2);		

		int flagPondID3 = rmCreateArea("flag pond 3");
		rmSetAreaSize(flagPondID3, 0.0015);
		rmSetAreaObeyWorldCircleConstraint(flagPondID3, true);
//		rmSetAreaMix(flagPondID3, "testmix"); 	// for testing
//		rmSetAreaBaseHeight(flagPondID3, 01);	// for testing
		rmSetAreaCoherence(flagPondID3, 1.0);
		rmAddAreaConstraint(flagPondID3, edgeConstraintShort);
		rmAddAreaConstraint(flagPondID3, whaleLand);
		rmAddAreaConstraint(flagPondID3, avoidPiratesShort);
		if (riverExists == 1 && riverWidthController != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID3, avoidCenterMin);
		if (oceanOffCenter == 1 && oceanMiddle != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID3, stayInBay);
		if (oceanRing == 1)
		{
			rmAddAreaConstraint(flagPondID3,staySudFar);
			if (riverExists == 1)
				rmAddAreaConstraint(flagPondID3, avoidCenterFlag);
		}
		if (oceanMiddle == 1 && oceanOffCenter != 1 && oceanRing != 1)
		{
			rmAddAreaConstraint(flagPondID3, stayInLake);
			rmAddAreaConstraint(flagPondID3,staySud);
		}
		if (splitIsland == 1)
			rmAddAreaConstraint(flagPondID3, stayCenter);
		rmSetAreaWarnFailure(flagPondID3, false);
		rmBuildArea(flagPondID3);		

		int flagPondID4 = rmCreateArea("flag pond 4");
		rmSetAreaSize(flagPondID4, 0.0015);
		rmSetAreaObeyWorldCircleConstraint(flagPondID4, true);
//		rmSetAreaMix(flagPondID4, "testmix"); 	// for testing
//		rmSetAreaBaseHeight(flagPondID4, 01);	// for testing
		rmSetAreaCoherence(flagPondID4, 1.0);
		rmAddAreaConstraint(flagPondID4, edgeConstraintShort);
		rmAddAreaConstraint(flagPondID4, whaleLand);
		rmAddAreaConstraint(flagPondID4, avoidPiratesShort);
		if (riverExists == 1 && riverWidthController != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID4, avoidCenterMin);
		if (oceanOffCenter == 1 && oceanMiddle != 1 && oceanRing != 1)
			rmAddAreaConstraint(flagPondID4, stayInBay);
		if (oceanRing == 1)
		{
			rmAddAreaConstraint(flagPondID4,stayWstFar);
			if (riverExists == 1)
				rmAddAreaConstraint(flagPondID4, avoidCenterFlag);
		}
		if (oceanMiddle == 1 && oceanOffCenter != 1 && oceanRing != 1)
		{
			rmAddAreaConstraint(flagPondID4, stayInLake);
			rmAddAreaConstraint(flagPondID4,stayWst);
		}
		if (splitIsland == 1)
			rmAddAreaConstraint(flagPondID4, stayCenter);
		rmSetAreaWarnFailure(flagPondID4, false);
		rmBuildArea(flagPondID4);		
	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 0.40);
	else if (trollBar == 1)
	   rmSetStatusText("", 0.4);
   else
   rmSetStatusText("", 0.6);

	// ============= Add Forests =============
	// Shipwrecks
	int shipwreckcount = cNumberNonGaiaPlayers+4;
	if (splitIsland == 1)
		shipwreckcount = cNumberNonGaiaPlayers*3;
	if (oceanRing == 1)
		shipwreckcount = cNumberNonGaiaPlayers*3;
	rmEchoInfo("shipwreck count = "+shipwreckcount);

	int shipwreckID = rmCreateObjectDef("shipwreck");
	rmAddObjectDefItem(shipwreckID, "zpShipwreckWoodLand", 1, 0.0);
	rmSetObjectDefMinDistance(shipwreckID, 0.0);
	rmSetObjectDefMaxDistance(shipwreckID, rmXFractionToMeters(0.5));
	rmAddObjectDefToClass(shipwreckID, classForest);
	rmAddObjectDefConstraint(shipwreckID, avoidShipwreck);
	rmAddObjectDefConstraint(shipwreckID, avoidCliffs);
	rmAddObjectDefConstraint(shipwreckID, avoidPond);
	rmAddObjectDefConstraint(shipwreckID, avoidElectorsShort);
	rmAddObjectDefConstraint(shipwreckID, avoidPiratesShort);
	rmAddObjectDefConstraint(shipwreckID, avoidAll);
	if (rmGetNomadStart() == false)
		rmAddObjectDefConstraint(shipwreckID, avoidPlayersFar);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(shipwreckID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(shipwreckID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(shipwreckID, avoidTradeRoute);
	rmAddObjectDefConstraint(shipwreckID, avoidEdge);
	rmAddObjectDefConstraint(shipwreckID, stayNearWaterShore);
	if (splitIsland == 1)
	{
		rmPlaceObjectDefInArea(shipwreckID, 0, rmAreaID("split island 1"), shipwreckcount/2);
		rmPlaceObjectDefInArea(shipwreckID, 0, rmAreaID("split island 2"), shipwreckcount/2);
	}
	else if (oceanRing == 1 || (oceanMiddle == 1 && oceanChance == 1) || (oceanOffCenter == 1 && bayChance == 1))
		rmPlaceObjectDefAtLoc(shipwreckID, 0, 0.5, 0.5, shipwreckcount);

	// Forests
	numTries=6+15*cNumberNonGaiaPlayers;
	if (floodedLand == 1)
		numTries=20+15*cNumberNonGaiaPlayers;
	failCount = 0;

	int sparseForests = -1;		// sometimes forests are fewer in number and contain fewer trees
	if (rmRandFloat(0,1) <= 0.05 && rmGetIsTreaty() == false)
		sparseForests = 1;
	if (sparseForests == 1)
		numTries = 10*cNumberNonGaiaPlayers;

	for (i=0; < numTries)
	{
		int forest = rmCreateArea("forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaObeyWorldCircleConstraint(forest, true);
		if (floodedLand == 1)
			rmSetAreaSize(forest, rmAreaTilesToFraction(69));
		else
			rmSetAreaSize(forest, rmAreaTilesToFraction(111));
		if (rmRandFloat(0,1) <= 0.001)
			rmSetAreaForestType(forest, "unknown forest funky");
		else 
			rmSetAreaForestType(forest, forestName);
		if (trollMap == 1)
		{
			rmSetAreaForestDensity(forest, 0.99);
			rmSetAreaForestClumpiness(forest, 0.99);
			rmSetAreaForestUnderbrush(forest, 0.99);
		}
		else if (sparseForests == 1)
		{
			rmSetAreaForestDensity(forest, 0.25);
			rmSetAreaForestClumpiness(forest, 0.25);
			rmSetAreaForestUnderbrush(forest, 0.69);
	  	}
		else 
		{
			rmSetAreaForestDensity(forest, 0.8);
			rmSetAreaForestClumpiness(forest, 0.8);
			rmSetAreaForestUnderbrush(forest, 0.3);
		}
		rmSetAreaCoherence(forest, 0.5);
		rmSetAreaSmoothDistance(forest, 0);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		rmAddAreaConstraint(forest, forestConstraint);
		rmAddAreaConstraint(forest, avoidElectorsShort);
		rmAddAreaConstraint(forest, avoidPiratesShort);
		rmAddAreaConstraint(forest, avoidTCFar);
		rmAddAreaConstraint(forest, avoidCommandPostFar);
		rmAddAreaConstraint(forest, avoidCW);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, avoidCanyon);
		if (floodedLand != 1)
			rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		rmAddAreaConstraint(forest, avoidTradeRoute);
		rmAddAreaConstraint(forest, avoidGoldMin);
		rmAddAreaConstraint(forest, avoidPond);
		if (frozenLake == 1)
			rmAddAreaConstraint(forest, avoidCliffs);
		rmAddAreaConstraint(forest, avoidTradeRouteSocketShort);

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

	if (floodedLand == 1)
	{
		// Random Extra Trees
		int rdmTreeID = rmCreateObjectDef("rdm extra trees");
		rmAddObjectDefItem(rdmTreeID, treeName, 4, 2.0);
		rmAddObjectDefToClass(rdmTreeID, rmClassID("classForest")); 
		rmSetObjectDefMinDistance(rdmTreeID, 0);
		rmSetObjectDefMaxDistance(rdmTreeID, rmXFractionToMeters(0.50));
		rmAddObjectDefConstraint(rdmTreeID, forestConstraint);
		rmAddObjectDefConstraint(rdmTreeID, avoidElectorsShort);
		rmAddObjectDefConstraint(rdmTreeID, avoidPiratesShort);
		rmAddObjectDefConstraint(rdmTreeID, avoidTCFar);
		rmAddObjectDefConstraint(rdmTreeID, avoidCommandPostFar);	
		rmAddObjectDefConstraint(rdmTreeID, avoidCW);
		rmAddObjectDefConstraint(rdmTreeID, avoidAll);
		rmAddObjectDefConstraint(rdmTreeID, avoidCanyon);
		rmAddObjectDefConstraint(rdmTreeID, avoidTradeRouteSocketShort);
		rmAddObjectDefConstraint(rdmTreeID, avoidTradeRoute);
		rmAddObjectDefConstraint(rdmTreeID, avoidGoldMin);
		rmAddObjectDefConstraint(rdmTreeID, avoidPond);
    	if (frozenLake == 1)
			rmAddObjectDefConstraint(rdmTreeID, avoidCliffs);
		rmPlaceObjectDefAtLoc(rdmTreeID, 0, 0.5, 0.5, 10+5*cNumberNonGaiaPlayers);
		if (sparseForests == 1)
			rmPlaceObjectDefAtLoc(rdmTreeID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers);
	}
	
	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 1.00);
	else if (trollBar == 1)
		rmSetStatusText("", 0.3);
	else
		rmSetStatusText("", 0.7);

	// ============= Starting Resources =============
	// Mines
	int playerSilverID = rmCreateObjectDef("player silver");
	if (trollMap == 1 || rmRandFloat(0,1) <= 0.001)
	{
	   	rmAddObjectDefItem(playerSilverID, "ypSPCRockCrate", 20, 4.0);
        rmSetObjectDefAllowOverlap(playerSilverID, true);
	}	
	else
	{
		if (rmRandFloat(0,1) <= 0.001)
		   rmAddObjectDefItem(playerSilverID, "deFauxMine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(playerSilverID, "zpValuableSource", 2, 3.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(playerSilverID, "deMineCoalBuildable", 1, 1.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(playerSilverID, "zpSulphurMine", 1, 1.0);
		else if (rmRandFloat(0,1) <= 0.10)
		   rmAddObjectDefItem(playerSilverID, "zpQuarzmine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.10)
		   rmAddObjectDefItem(playerSilverID, "MineGold", 1, 0.0);
		else if (caribbeanMap == 1 && rmRandFloat(0,1) <= 0.25)
		   rmAddObjectDefItem(playerSilverID, "deShipRuins", 1, 0.0);
		else if (africanMap == 1 && rmRandFloat(0,1) <= 0.001)
		   rmAddObjectDefItem(playerSilverID, "deREVMineDiamondBuildable", 1, 1.0);
		else if (africanMap == 1 && rmRandFloat(0,1) >= 0.95)
		   rmAddObjectDefItem(playerSilverID, "MineSalt", 1, 0.0);
		else if (rmRandFloat(0,1) >= 0.75)
			rmAddObjectDefItem(playerSilverID, "MineCopper", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.01)
			rmAddObjectDefItem(playerSilverID, "zpDiamondMine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.05)
			rmAddObjectDefItem(playerSilverID, "MineTin", 1, 0.0);
		else
			rmAddObjectDefItem(playerSilverID, "mine", 1, 0.0);
	}
	rmAddObjectDefToClass(playerSilverID, classGold);
	rmAddObjectDefConstraint(playerSilverID, avoidTradeRoute);
	rmAddObjectDefConstraint(playerSilverID, avoidTradeRouteSocketShort);
	rmSetObjectDefMinDistance(playerSilverID, 12.0);
	rmSetObjectDefMaxDistance(playerSilverID, 16.0);
	rmAddObjectDefConstraint(playerSilverID, avoidAll);
	rmAddObjectDefConstraint(playerSilverID, avoidSilver1);
//	rmAddObjectDefConstraint(playerSilverID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(playerSilverID, avoidCliffsShort);

	int whichBerry = rmRandInt(1,100);	// randomly selects blueberries

	int playerBerryID = rmCreateObjectDef("player berries");
	if (rmRandFloat(0,1) <= 0.001)
		rmAddObjectDefItem(playerBerryID, "CinematicRevealerToAll", rmRandInt(1,4), 2.0);
	else if (whichBerry == 100)
		rmAddObjectDefItem(playerBerryID, "deTorpBush2", rmRandInt(4,6), 3.0);
	else if (euMap == 1)
		rmAddObjectDefItem(playerBerryID, "zpGrapeBush", rmRandInt(1,4), 2.0);
	else if (oceaniaMap == 1)
		rmAddObjectDefItem(playerBerryID, "zpPineapleBush", rmRandInt(1,4), 2.0);
	else
		rmAddObjectDefItem(playerBerryID, "berryBush", rmRandInt(1,4), 2.0);
	rmSetObjectDefMinDistance(playerBerryID, 15);
	rmSetObjectDefMaxDistance(playerBerryID, 15);
	rmAddObjectDefConstraint(playerBerryID, avoidAll);
	if (floodedLand != 1)
	   rmAddObjectDefConstraint(playerBerryID, shortAvoidImpassableLand);

	int shipWrecked = rmRandInt(1,100);	// randomly selects shipwreck
	if (sparseForests == 1)
		shipWrecked = 1;

	int playerShipwreckID = rmCreateObjectDef("player shipwreck");
	rmAddObjectDefItem(playerShipwreckID, "zpShipwreckWoodLand", 1, 0.0);
	rmSetObjectDefMinDistance(playerShipwreckID, 20);
	rmSetObjectDefMaxDistance(playerShipwreckID, 24);
	rmAddObjectDefConstraint(playerShipwreckID, avoidAll);
	if (floodedLand != 1)
	   rmAddObjectDefConstraint(playerShipwreckID, shortAvoidImpassableLand);

	int playerTreeID = rmCreateObjectDef("player trees");
	if (rmRandFloat(0,1) <= 0.001)
	rmAddObjectDefItem(playerTreeID, propz, 3, 3.0);
	else
		rmAddObjectDefItem(playerTreeID, treeName, 3, 3.0);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRoute);
	rmSetObjectDefMinDistance(playerTreeID, 16);
	rmSetObjectDefMaxDistance(playerTreeID, 20);
	rmAddObjectDefConstraint(playerTreeID, avoidAll);
	rmAddObjectDefConstraint(playerTreeID, avoidSilver1Short);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(playerTreeID, shortAvoidImpassableLand);

	int playerTreeFarID = rmCreateObjectDef("player trees far");
	if (rmRandFloat(0,1) <= 0.01 || trollMap == 1)
		rmAddObjectDefItem(playerTreeFarID, propz, 10, 6.0);
	else
		rmAddObjectDefItem(playerTreeFarID, treeName, 10, 6.0);
	rmAddObjectDefConstraint(playerTreeFarID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(playerTreeFarID, avoidTradeRoute);
	rmSetObjectDefMinDistance(playerTreeFarID, 36);
	rmSetObjectDefMaxDistance(playerTreeFarID, 40+cNumberNonGaiaPlayers);
	rmAddObjectDefConstraint(playerTreeFarID, avoidAll);
	rmAddObjectDefConstraint(playerTreeFarID, avoidCliffsShort);
	rmAddObjectDefConstraint(playerTreeFarID, avoidPond);
	rmAddObjectDefConstraint(playerTreeFarID, avoidSilver1Short);
	rmAddObjectDefConstraint(playerTreeFarID, avoidPlayersShort);
	rmAddObjectDefConstraint(playerTreeFarID, avoidForestMin);
	rmAddObjectDefConstraint(playerTreeFarID, avoidEdge);
//	rmAddObjectDefConstraint(playerTreeFarID, avoidCenterFar);
	if (oceanRing == 1)
	{
		rmAddObjectDefConstraint(playerTreeFarID, stayNearWater);
		rmAddObjectDefConstraint(playerTreeFarID, avoidWaterShort);
	}
	else if (splitIsland != 1)
		rmAddObjectDefConstraint(playerTreeFarID, stayNearEdge);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(playerTreeFarID, shortAvoidImpassableLand);

	int nearDeerID = rmCreateObjectDef("herds near town");
	if (rmGetIsTreaty() == true)
		rmAddObjectDefItem(nearDeerID, startingCritterName, 16, 5.0);
	else
	{
		if (rmRandFloat(0,1) <= 0.01)
			rmAddObjectDefItem(nearDeerID, "ypIGCBird", 10, 5.0);
		else
			rmAddObjectDefItem(nearDeerID, startingCritterName, 10, 5.0);
	}
	rmSetObjectDefMinDistance(nearDeerID, 12);
	rmSetObjectDefMaxDistance(nearDeerID, 14);
//	rmAddObjectDefConstraint(nearDeerID, avoidFood);
	rmAddObjectDefConstraint(nearDeerID, avoidAll);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nearDeerID, shortAvoidImpassableLand);
	if (chaosBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetObjectDefCreateHerd(nearDeerID, false);
	else
		rmSetObjectDefCreateHerd(nearDeerID, true);

	int ripTCID = rmCreateObjectDef("danger near town");
	int petardSpawn = 0;
	if (rmRandFloat(0,1) <= 0.50 || rmGetIsTreaty() == true)
		rmAddObjectDefItem(ripTCID, "deQuakerGun", 2, 4.0);
	else
	{
		petardSpawn = 1;
		rmAddObjectDefItem(ripTCID, "xpPetardNitro", 2, 4.0);
	}
	rmSetObjectDefMinDistance(ripTCID, 6);
	rmSetObjectDefMaxDistance(ripTCID, 10);
//	rmAddObjectDefConstraint(ripTCID, avoidFood);
	rmAddObjectDefConstraint(ripTCID, avoidAll);
//	rmAddObjectDefConstraint(ripTCID, shortAvoidImpassableLand);

	int farDeerID = rmCreateObjectDef("herds far away");		   
	rmAddObjectDefItem(farDeerID, critterTwoName, rmRandInt(14,16), 8.0);
	rmSetObjectDefMinDistance(farDeerID, 40);
	rmSetObjectDefMaxDistance(farDeerID, 44);
	rmAddObjectDefConstraint(farDeerID, avoidElectorsShort);
	rmAddObjectDefConstraint(farDeerID, avoidPiratesShort);
	rmAddObjectDefConstraint(farDeerID, avoidFood);
	rmAddObjectDefConstraint(farDeerID, avoidAll);									   
	if (floodedLand != 1)
		rmAddObjectDefConstraint(farDeerID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(farDeerID, avoidForestMin);
	rmAddObjectDefConstraint(farDeerID, avoidPond);
	if (oceanRing == 1)
	{
		rmAddObjectDefConstraint(farDeerID, stayNearWater);
		rmAddObjectDefConstraint(farDeerID, avoidWater);
	}
	else if (splitIsland != 1)
		rmAddObjectDefConstraint(farDeerID, stayNearEdge);
	rmAddObjectDefConstraint(farDeerID, avoidCliffsShort);
	rmAddObjectDefConstraint(farDeerID, avoidEdge);
	if (chaosBar == 1 && trollBar == 1 && rmRandFloat(0,1) <= 0.05)
		rmSetObjectDefCreateHerd(farDeerID, false);
	else
		rmSetObjectDefCreateHerd(farDeerID, true);

	int farDeer2ID = rmCreateObjectDef("herds far far away");		   
	rmAddObjectDefItem(farDeer2ID, critterTwoName, rmRandInt(8,10), 4.0);
	rmSetObjectDefMinDistance(farDeer2ID, 40);
	rmSetObjectDefMaxDistance(farDeer2ID, 50+2*cNumberNonGaiaPlayers);
	rmAddObjectDefConstraint(farDeer2ID, avoidFood);
	rmAddObjectDefConstraint(farDeer2ID, avoidAll);							   
	if (floodedLand != 1)
	   rmAddObjectDefConstraint(farDeer2ID, shortAvoidImpassableLand);
   rmAddObjectDefConstraint(farDeer2ID, avoidForestMin);
   rmAddObjectDefConstraint(farDeer2ID, avoidPond);
   rmAddObjectDefConstraint(farDeer2ID, avoidPlayersShort);
   if (oceanRing == 1 || splitIsland == 1)
   {
	   rmAddObjectDefConstraint(farDeer2ID, stayNearWater);
	   rmAddObjectDefConstraint(farDeer2ID, avoidWaterShort);
   }
	else
	   rmAddObjectDefConstraint(farDeer2ID, stayNearEdge);
   rmAddObjectDefConstraint(farDeer2ID, avoidCliffsShort);
   rmAddObjectDefConstraint(farDeer2ID, avoidEdge);
	if (chaosBar == 1 && trollBar == 1 && rmRandFloat(0,1) <= 0.05)
		rmSetObjectDefCreateHerd(farDeer2ID, false);
	else
   rmSetObjectDefCreateHerd(farDeer2ID, true);

	int startSilver3ID = rmCreateObjectDef("player farther silver");
	if (chaosBar == 1 && rmRandFloat(0,1) <= 0.01)
	{
	   	rmAddObjectDefItem(startSilver3ID, "ypSPCRockCrate", 20, 4.0);
        rmSetObjectDefAllowOverlap(startSilver3ID, true);
	}	
	else
	{
		if (rmRandFloat(0,1) <= 0.001)
		   rmAddObjectDefItem(startSilver3ID, "deFauxMine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(startSilver3ID, "zpValuableSource", 2, 3.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(startSilver3ID, "deMineCoalBuildable", 1, 1.0);
		else if (rmRandFloat(0,1) <= 0.05)
		   rmAddObjectDefItem(startSilver3ID, "zpSulphurMine", 1, 1.0);
		else if (rmRandFloat(0,1) <= 0.10)
		   rmAddObjectDefItem(startSilver3ID, "zpQuarzmine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.10)
		   rmAddObjectDefItem(startSilver3ID, "MineGold", 1, 0.0);
		else if (caribbeanMap == 1 && rmRandFloat(0,1) <= 0.25)
		   rmAddObjectDefItem(startSilver3ID, "deShipRuins", 1, 0.0);
		else if (africanMap == 1 && rmRandFloat(0,1) <= 0.001)
		   rmAddObjectDefItem(startSilver3ID, "deREVMineDiamondBuildable", 1, 1.0);
		else if (africanMap == 1 && rmRandFloat(0,1) >= 0.95)
		   rmAddObjectDefItem(startSilver3ID, "MineSalt", 1, 0.0);
		else if (rmRandFloat(0,1) >= 0.75)
			rmAddObjectDefItem(startSilver3ID, "MineCopper", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.01)
			rmAddObjectDefItem(startSilver3ID, "zpDiamondMine", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.05)
			rmAddObjectDefItem(startSilver3ID, "MineTin", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.333)
			rmAddObjectDefItem(startSilver3ID, "zpJadeMine", 1, 0.0);
		else
			rmAddObjectDefItem(startSilver3ID, "mine", 1, 0.0);
	}
	rmSetObjectDefMinDistance(startSilver3ID, 40);
	rmSetObjectDefMaxDistance(startSilver3ID, 50+2*cNumberNonGaiaPlayers);
	rmAddObjectDefToClass(startSilver3ID, classGold);
	rmAddObjectDefConstraint(startSilver3ID, avoidElectorsShort);
	rmAddObjectDefConstraint(startSilver3ID, avoidPiratesShort);
	rmAddObjectDefConstraint(startSilver3ID, avoidAll);
	rmAddObjectDefConstraint(startSilver3ID, avoidSilver1);
	rmAddObjectDefConstraint(startSilver3ID, avoidEdge);
	rmAddObjectDefConstraint(startSilver3ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(startSilver3ID, avoidGoldMin);
	rmAddObjectDefConstraint(startSilver3ID, avoidCliffsShort);
	rmAddObjectDefConstraint(startSilver3ID, avoidTradeRoute);
   if (oceanRing == 1 || splitIsland == 1)
   {
	   rmAddObjectDefConstraint(startSilver3ID, stayNearWater);
	   rmAddObjectDefConstraint(startSilver3ID, avoidWater);
   }
	else
	   rmAddObjectDefConstraint(startSilver3ID, stayNearEdge);
	rmAddObjectDefConstraint(startSilver3ID, avoidPlayersShort);

	// Player Nuggets
	int nugget1 = rmCreateObjectDef("nugget starter"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	if (trollBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetNuggetDifficulty(4, 4);
	else
		rmSetNuggetDifficulty(1, 1);
	if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(nugget1, avoidWaterShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
 	rmAddObjectDefConstraint(nugget1, avoidNuggetShort);
  	rmAddObjectDefConstraint(nugget1, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
  	rmAddObjectDefConstraint(nugget1, avoidAll);
  	rmAddObjectDefConstraint(nugget1, avoidPond);
	rmSetObjectDefMinDistance(nugget1, 22.0);
	rmSetObjectDefMaxDistance(nugget1, 25.0);

	int nugget2 = rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	if (trollBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetNuggetDifficulty(4, 4);
	else
	rmSetNuggetDifficulty(2, 2);
   if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(nugget2, avoidWaterShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(nugget2, avoidNuggetShort);
  	rmAddObjectDefConstraint(nugget2, avoidCommandPost);
  	rmAddObjectDefConstraint(nugget2, avoidTC);
  	rmAddObjectDefConstraint(nugget2, avoidElectorsShort);
  	rmAddObjectDefConstraint(nugget2, avoidPiratesShort);
  	rmAddObjectDefConstraint(nugget2, avoidCW);
  	rmAddObjectDefConstraint(nugget2, avoidCanyon);
  	rmAddObjectDefConstraint(nugget2, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
  	rmAddObjectDefConstraint(nugget2, avoidAll);
  	rmAddObjectDefConstraint(nugget2, avoidPond);
	rmSetObjectDefMinDistance(nugget2, 30.0);
	rmSetObjectDefMaxDistance(nugget2, 35.0);

	// Bonus Wagon
	if (everyoneGetsAWagon != 981)
	{
		if (rmRandFloat(0,1) <= 0.001)
			everyoneGetsAWagon = 111;		// factory wagon
		if (rmRandFloat(0,1) <= 0.005)
			everyoneGetsAWagon = 69;		// jeff wagons (1 food age 2, 1 wood age 3, 1 coin age 4, all 3 age 5)
		if (oceanRing == 1 && rmRandFloat(0,1) <= 0.25)
			everyoneGetsAWagon = 1001;
		if (splitIsland == 1 && rmRandFloat(0,1) <= 0.25)
			everyoneGetsAWagon = 1001;
//		if (oceanOffCenter == 1 && rmRandFloat(0,1) <= 0.25 && bayChance == 1)
		if (rmRandFloat(0,1) <= 0.25 && bayChance == 1 && frozenLake != 1)
			everyoneGetsAWagon = 1001;
//		if (oceanMiddle == 1 && rmRandFloat(0,1) <= 0.25  && oceanChance == 1)
		if (rmRandFloat(0,1) <= 0.25  && oceanChance == 1 && frozenLake != 1)
			everyoneGetsAWagon = 1001;
		if (dekkanMap == 1 && rmRandFloat(0,1) <= 0.25 && rmGetIsTreaty() == true)
			everyoneGetsAWagon = 1002;
		if (trollMap == 1 || rmRandFloat(0,1) <= 0.001)
			everyoneGetsAWagon = 1003;
		if (tpORnot == 5 && rmRandFloat(0,1) <= 0.10)
			everyoneGetsAWagon = 990;
		if (rmRandFloat(0,1) <= 0.01)
			everyoneGetsAWagon = 666;		// military wagon age 2
		if (rmRandFloat(0,1) <= 0.001)
			everyoneGetsAWagon = 888;		// crazy 8s - TC wagon plus BL+1
		if (rmRandFloat(0,1) <= 0.001)
			everyoneGetsAWagon = 8888;		// crazier 8s - TC wagon plus BL+1 when age up
	}
	rmEchoInfo("everyoneGetsAWagon = "+everyoneGetsAWagon);

	if (rmRandFloat(0,1) <= 0.001 || trollMap == 1 || everyoneGetsAWagon == 888 || everyoneGetsAWagon == 8888)
	{
    	rmSetNumberInitialColonies(rmRandInt(2,11));
	}

	// spice up the tp wagon start
	int tpWagonSpice = -1;
	if (everyoneGetsAWagon <= 970 && everyoneGetsAWagon >= 950)
		tpWagonSpice = 1;
	int tpTechChooser = rmRandInt(1,1000);
//		tpTechChooser = 99;		// for testing
	int railroadTech = -1;
	int religiousDistrictTech = -1;
	int advTPTech = -1;
	int cequeTech = -1;
	int tamboShadowTech = -1;
	int euFortifiedTPTech = -1;
	int greenwichTech = -1;
	int lighthouseTech = -1;
	int kamayuksTech = -1;

	if (tpWagonSpice == 1)	// random chances for some tp related techs for spice
	{
		if (andesMap == 1 && rmRandFloat(0,1) <= 0.25)
		{
			tamboShadowTech = 1;	// DEIncaTamboShadow - everyone builds tambos
		}
		else if (euMap == 1 && rmRandFloat(0,1) <= 0.05)
		{
			euFortifiedTPTech = 1;	// DESPCFortifiedCityState tps double hp
		}
		else if (tpTechChooser <= 5)
		{
			religiousDistrictTech = 1;	// DENativeSPCReligiousDistrict - healers work faster
		}
		else if (tpTechChooser <= 25)
		{
			railroadTech = 1;	// DESPCRailroadNetwork - faster shipments and tp shipment points
		}
		else if (tpTechChooser <= 40)
		{
			advTPTech = 1;	// HCAdvancedTradingPost, DEHCAdvancedTambos?
		}
		else if (tpTechChooser <= 50)
		{
			cequeTech = 1;	// DEHCCequeSystem - tps trickle xp
		}
		else if (tpTechChooser <= 65)
		{
			greenwichTech = 1;	// DEHCGreenwichTime
		}
		else if (tpTechChooser <= 85)
		{
			lighthouseTech = 1;	// DENatSomaliLighthouses - increased LOS
		}
		else if (tpTechChooser <= 100)
		{
			kamayuksTech = 1;	// DEHCQuipuKamayuks - plus a chasqui scout
		}
	}

	int butOnlySometimes = rmRandInt(1,5);	// RNG to place bonus wagon - no longer used
		butOnlySometimes = 3;		// for testing	// nevermind let's keep it active always for some fun
	
	string natUnit = "";	// choose a native unit to accompany embassy wagon
	if (yellowRiverMap == 1)
		natUnit = "ypNativeScout";
	else if (rmRandFloat(0,1) <= 0.10)
		natUnit = "NativeScout";
	else
		natUnit = "deNatSPCLenapeVillager";
	
	int playerWagonID = rmCreateObjectDef("starting wagon");
	if (everyoneGetsAWagon == 888)
		rmAddObjectDefItem(playerWagonID, "CoveredWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 8888)
		rmAddObjectDefItem(playerWagonID, propz, 1, 0.0);
	else if (everyoneGetsAWagon == 666)
	{
		rmAddObjectDefItem(playerWagonID, "SPCCasualtyCart", 1, 2.0);
		rmAddObjectDefItem(playerWagonID, "deNatEUPropVilGuards", 1, 3.0);
	}
	else if (everyoneGetsAWagon == 69)
	{
		rmAddObjectDefItem(playerWagonID, "dePropsResourceCratesFood", 1, 3.0);
		rmAddObjectDefItem(playerWagonID, "FirewoodPile", 1, 3.0);
		rmAddObjectDefItem(playerWagonID, "dePropsResourceCratesGold", 1, 3.0);
	}
	else if (everyoneGetsAWagon == 111)
		rmAddObjectDefItem(playerWagonID, "FactoryWagon", 1, 0.0);
	else if (everyoneGetsAWagon <= 970)
	{
		if (kamayuksTech == 1)
		{
			rmAddObjectDefItem(playerWagonID, "deTradingPostWagon", 1, 3.0);
			rmAddObjectDefItem(playerWagonID, "deChasqui", 1, 3.0);
		}
		else if (greenwichTech == 1)
		{
			// tech spawns a wagon
		}
		else
		rmAddObjectDefItem(playerWagonID, "deTradingPostWagon", 1, 0.0);
	}
	else if (everyoneGetsAWagon <= 971)
	{
//		rmAddObjectDefItem(playerWagonID, "ypChurchWagon", 1, 0.0);
	}
	else if (everyoneGetsAWagon <= 972)
		rmAddObjectDefItem(playerWagonID, "Envoy", 1, 0.0);
	else if (everyoneGetsAWagon == 973)
		rmAddObjectDefItem(playerWagonID, "deUniqueTowerBuilder", 1, 0.0);
	else if (everyoneGetsAWagon == 974)
		rmAddObjectDefItem(playerWagonID, "ypBerryWagon1", 1, 0.0);
	else if (everyoneGetsAWagon == 975)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "ypVillageWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 1, 3.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 976)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "deLivestockMarketWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 3, 3.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 977)
	{
		rmAddObjectDefItem(playerWagonID, "deMountainMonasteryBuilder", 1, 2.0);
		if (rmRandFloat(0,1) <= 0.01)
			rmAddObjectDefItem(playerWagonID, "deNatBerberSultan", 1, 3.0);
		else if (rmRandFloat(0,1) <= 0.10)
			rmAddObjectDefItem(playerWagonID, "deAbun", 1, 3.0);
		else
			rmAddObjectDefItem(playerWagonID, "deNatNomad", 1, 3.0);
	}
	else if (everyoneGetsAWagon == 978)
	{
		rmAddObjectDefItem(playerWagonID, "deBuilderKingdom", 1, 2.0);
		if (rmRandFloat(0,1) <= 0.01)
			rmAddObjectDefItem(playerWagonID, "deNatAkanWarchief", 1, 3.0);
		else if (rmRandFloat(0,1) <= 0.10)
			rmAddObjectDefItem(playerWagonID, "deGriot", 1, 3.0);
		else
			rmAddObjectDefItem(playerWagonID, "deNatNomad", 1, 3.0);
	}
	else if (everyoneGetsAWagon == 979)
	{
//		rmAddObjectDefItem(playerWagonID, "deAthosMonasteryWagon", 2, 4.0);
	}
	else if (everyoneGetsAWagon == 980)
	{
		rmAddObjectDefItem(playerWagonID, "NatHolcanSpearman", 1, 0.0);
	}
	else if (everyoneGetsAWagon == 981)
		rmAddObjectDefItem(playerWagonID, "dePropsResourceCratesGold", 1, 0.0);
	else if (everyoneGetsAWagon == 982)
		rmAddObjectDefItem(playerWagonID, "deCommanderyWagon", 2, 2.0);
	else if (everyoneGetsAWagon == 983)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "ypSacredFieldWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 2, 3.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 984)
		rmAddObjectDefItem(playerWagonID, "deDepotWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 985)
		rmAddObjectDefItem(playerWagonID, "SPCDamagedCannons", 1, 0.0);
	else if (everyoneGetsAWagon == 986)
		rmAddObjectDefItem(playerWagonID, "deCommandWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 987)
	{
		rmAddObjectDefItem(playerWagonID, "deLombardWagon", 1, 2.0);
		rmAddObjectDefItem(playerWagonID, "deSPCCityGuard", 1, 2.0);
	}
	else if (everyoneGetsAWagon == 988)
	{
		if (electorSpawn != 1)
			rmAddObjectDefItem(playerWagonID, "deBatteryTowerWagon", 1, 0.0);
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 989)
	{
		rmAddObjectDefItem(playerWagonID, "deProspectorWagonCoal", 1, 2.0);
		rmAddObjectDefItem(playerWagonID, "deMiner", 1, 2.0);
	}
	else if (everyoneGetsAWagon == 990)
	{
		rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
		rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
	}
	else if (everyoneGetsAWagon == 991)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "deHaciendaWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 4, 4.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 992)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "deHomesteadWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 7, 5.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 993)
		rmAddObjectDefItem(playerWagonID, "deImperialWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 994)
		rmAddObjectDefItem(playerWagonID, "BankWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 995)
		rmAddObjectDefItem(playerWagonID, "deTorpWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 996)
		rmAddObjectDefItem(playerWagonID, "OutpostWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 997)
		rmAddObjectDefItem(playerWagonID, "deRedSeaWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 998)
		rmAddObjectDefItem(playerWagonID, "SettlerWagon", 1, 0.0);
	else if (everyoneGetsAWagon == 999)
	{
		if (autoCattle != 1)
		{
			rmAddObjectDefItem(playerWagonID, "ypShrineWagon", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, livestockName, 4, 4.0);
		}
		else
		{
			everyoneGetsAWagon = 990;
			rmAddObjectDefItem(playerWagonID, "deEmbassyTravois", 1, 2.0);
			rmAddObjectDefItem(playerWagonID, natUnit, 1, 4.0);
		}
	}
	else if (everyoneGetsAWagon == 1000)
	{
		rmAddObjectDefItem(playerWagonID, "YPDojoWagon", 1, 2.0);
		rmAddObjectDefItem(playerWagonID, "ypIrregular", 1, 4.0);
		rmAddObjectDefItem(playerWagonID, "ypPeasant", 1, 4.0);
	}
	else if (everyoneGetsAWagon == 1001)
	{
		rmAddObjectDefItem(playerWagonID, "deDockWagon", 1, 0.0);
		rmAddObjectDefItem(playerWagonID, "deCrateofFish", 1, 4.0);
	}
	else if (everyoneGetsAWagon == 1002)
		rmAddObjectDefItem(playerWagonID, "YPGroveWagon", 1, 0.0);
	else
		rmAddObjectDefItem(playerWagonID, "deREVStarTrekWagon", 1, 0.0);
	rmSetObjectDefMinDistance(playerWagonID, 12.0);
	rmSetObjectDefMaxDistance(playerWagonID, 24.0);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(playerWagonID, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(playerWagonID, avoidCommandPost);
  	rmAddObjectDefConstraint(playerWagonID, avoidTC);
  	rmAddObjectDefConstraint(playerWagonID, avoidCW);
  	rmAddObjectDefConstraint(playerWagonID, avoidCanyon);
  	rmAddObjectDefConstraint(playerWagonID, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(playerWagonID, avoidTradeRoute);
  	rmAddObjectDefConstraint(playerWagonID, avoidAll);
  	rmAddObjectDefConstraint(playerWagonID, avoidEdge);

	int dutchBankWagonID = rmCreateObjectDef("dutch bank wagon");
	rmAddObjectDefItem(dutchBankWagonID, "BankWagon", 1, 0.0);
	rmSetObjectDefMinDistance(dutchBankWagonID, 12.0);
	rmSetObjectDefMaxDistance(dutchBankWagonID, 24.0);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(dutchBankWagonID, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidCommandPost);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidTC);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidCW);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidCanyon);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidTradeRoute);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidAll);
  	rmAddObjectDefConstraint(dutchBankWagonID, avoidEdge);

	int scoutID = rmCreateObjectDef("bonus scout");
	rmAddObjectDefItem(scoutID, petName1, 1, 0.0);
	rmSetObjectDefMinDistance(scoutID, 12.0);
	rmSetObjectDefMaxDistance(scoutID, 24.0);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(scoutID, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(scoutID, avoidCommandPost);
  	rmAddObjectDefConstraint(scoutID, avoidTC);
  	rmAddObjectDefConstraint(scoutID, avoidCW);
  	rmAddObjectDefConstraint(scoutID, avoidCanyon);
  	rmAddObjectDefConstraint(scoutID, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(scoutID, avoidTradeRoute);
  	rmAddObjectDefConstraint(scoutID, avoidAll);
  	rmAddObjectDefConstraint(scoutID, avoidEdge);

	int regicideID = rmCreateObjectDef("regicide unit");
	int regicideActivator = -1;
	rmAddObjectDefItem(regicideID, "ypDaimyoRegicide", 1, 0.0);
	rmSetObjectDefMinDistance(regicideID, 12.0);
	rmSetObjectDefMaxDistance(regicideID, 24.0);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(regicideID, shortAvoidImpassableLand);
  	rmAddObjectDefConstraint(regicideID, avoidCommandPost);
  	rmAddObjectDefConstraint(regicideID, avoidTC);
  	rmAddObjectDefConstraint(regicideID, avoidCW);
  	rmAddObjectDefConstraint(regicideID, avoidCanyon);
  	rmAddObjectDefConstraint(regicideID, avoidTradeRouteSocketShort);
  	rmAddObjectDefConstraint(regicideID, avoidTradeRoute);
  	rmAddObjectDefConstraint(regicideID, avoidAll);
  	rmAddObjectDefConstraint(regicideID, avoidEdge);

	// Player Flag
	int placeWaterFlag = -1;	// controls if water flag spawns
	int whaleSpawner = -1;		// controls if whales spawn
	int waterScout = -1;		// controls if water scout spawns
	if (everyoneGetsAWagon == 1001 && rmRandFloat(0,1) <= 0.50)
		waterScout = 1;
	if (splitIsland == 1 || riverWidthController != 1)	// if players divided transport is available
		waterScout = 1;

//		waterScout = 1;		// for testing
	int waterFlagID = rmCreateObjectDef("HC water flag");
	rmAddObjectDefItem(waterFlagID, "HomeCityWaterSpawnFlag", 1, 0.0);
	rmSetObjectDefMinDistance(waterFlagID, 00);
	rmSetObjectDefMaxDistance(waterFlagID, 10);
   rmAddObjectDefToClass(waterFlagID, classFlag);
   rmAddObjectDefConstraint(waterFlagID, avoidEdge);
	rmAddObjectDefConstraint(waterFlagID, flagVsFlag);
	rmAddObjectDefConstraint(waterFlagID, fishLand);
	rmAddObjectDefConstraint(waterFlagID, avoidAllFar);
	rmAddObjectDefConstraint(waterFlagID, avoidPiratesShort);

	int waterScoutID = rmCreateObjectDef("water scout");
	if (rmRandFloat(0,1) <= 0.50)
		rmAddObjectDefItem(waterScoutID, "DEFlatBoatNoCondition", 1, 0.0);
	else
		rmAddObjectDefItem(waterScoutID, "deDinghy", 1, 0.0);
	rmSetObjectDefMinDistance(waterScoutID, 00);
	rmSetObjectDefMaxDistance(waterScoutID, 10);
//	rmAddObjectDefToClass(waterScoutID, classFlag);
	rmAddObjectDefConstraint(waterScoutID, avoidEdge);
	rmAddObjectDefConstraint(waterScoutID, fishLand);
	rmAddObjectDefConstraint(waterScoutID, avoidAll);
	rmAddObjectDefConstraint(waterScoutID, avoidPiratesShort);

	int treasureShipID = rmCreateObjectDef("treasure ship");
//	if (rmRandFloat(0,1) <= 0.50)
		rmAddObjectDefItem(treasureShipID, "SPCTreasureShip", 1, 0.0);
//	else
//		rmAddObjectDefItem(treasureShipID, "YPSPCTreasureShip", 1, 0.0);
	rmSetObjectDefMinDistance(treasureShipID, 00);
	rmSetObjectDefMaxDistance(treasureShipID, 24);
	rmAddObjectDefToClass(treasureShipID, classPirates);
//	rmAddObjectDefConstraint(treasureShipID, portOnShore);
//	rmAddObjectDefConstraint(treasureShipID, avoidEdge);
//	rmAddObjectDefConstraint(treasureShipID, fishLand);
//	rmAddObjectDefConstraint(treasureShipID, avoidPiratesShort);

	// Define a parm for placing water flags on water maps
	if (bayChance == 1 && frozenLake != 1)
	{
		whaleSpawner = 1;
		placeWaterFlag = 1;
	}
	if (oceanChance == 1 && frozenLake != 1)
	{
		if (rmRandFloat(0,1) <= 0.80)
			whaleSpawner = 1;
		if (sideBay == 1)
			whaleSpawner = 1;
		placeWaterFlag = 1;
	}
	if (oceanRing == 1 || splitIsland == 1)
	{
		whaleSpawner = 1;
		placeWaterFlag = 1;
	}
	if (riverWidthController != 1 && riverExists == 1)
	{
		if (rmRandFloat(0,1) <= 0.20)
			whaleSpawner =1;
		placeWaterFlag =1;
	}

	// Now place all these definitions
	float bonusSilverChance = rmRandFloat(0,1);		// chance for extra mine
	if (rmGetIsTreaty() == true)
		bonusSilverChance = 0.01;
	if (everyoneGetsAWagon == 989 && rmGetIsTreaty() == false)
		bonusSilverChance = 0.99;
	float bonusTreeChance = rmRandFloat(0,1);		// chance for extra trees
	float berryChance = rmRandFloat(0,1);			// chance for berries
	float scoutRNG = rmRandFloat(0,1);				// chance for starting scout
	if (trollBar == 1)
		scoutRNG = 1.0;
	float boneRNG = rmRandFloat(0,1);				// chance for bone guard
//		boneRNG = 0.001;	// for testing
	float getRekt = rmRandFloat(0,1);				// chance for petards xD
//		getRekt = 0.99;	trollBar = 1;	// for testing

	int whichBone = rmRandInt(1,2);		// randomly selects bone guard unit
	string boneType = "";
	if (whichBone == 1)
		boneType = "Boneguard";
	else
		boneType = "BoneguardAge2";

	for(i=1; <cNumberPlayers)
	{
		if (rmGetNomadStart() == true)
		{
//			if 	(rmGetPlayerCiv(i) == rmGetCivID("XPSioux") == false)
				rmSetPlayerResource(i, "Wood", 700);		
//			else
//				rmSetPlayerResource(i, "Wood", 600);	
		}
		if (rmGetNomadStart() == false)
		{
			vector TCLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startingTCID, i));
			vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
			if (whoseUnits > 1)
				rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			else
			{
				// Starting Stuff
				int whichCiv = rmRandInt(1,16);		// chooses random alternative starting units
//					whichCiv = 1; 	// for testing

				int notMyStuffID = rmCreateObjectDef("not my stuff"+i);
				if (rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois"))
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux"))
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("XPAztec"))
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEInca"))
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("Chinese"))
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("Indians"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("Japanese"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEMaltese"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.25)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("Dutch"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else if (whichCiv == 12)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("Spanish"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else if (whichCiv == 12)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("French"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else if (whichCiv == 12)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
						}
					}
				}
				else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEItalians"))	
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else if (whichCiv == 12)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.50)
						{
							if (rmRandFloat(0,1) <= 0.33)
								rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
							else if (rmRandFloat(0,1) <= 0.50)
								rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
							else
								rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
						}
					}
				}
				else
				{
					if (whichCiv <= 2)
					{
						if (rmRandFloat(0,1) <= 0.50)
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral2", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "dePadre", 1, 2);
							rmAddObjectDefItem(notMyStuffID, "Cow", 1, 2);
						}
						else
						{
							rmAddObjectDefItem(notMyStuffID, "deGeneral", 1, 2);
						}
					}
					else if (whichCiv == 3)
					{
						rmAddObjectDefItem(notMyStuffID, "xpAztecWarchief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "deEagleScout", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "xpMedicineManAztec", 1, 2);
					}
					else if (whichCiv == 4)
					{
						rmAddObjectDefItem(notMyStuffID, "xpIroquoisWarChief", 1, 2);
					}
					else if (whichCiv == 5)
					{
						rmAddObjectDefItem(notMyStuffID, "xpLakotaWarchief", 1, 2);
					}
					else if (whichCiv == 6)
					{
						rmAddObjectDefItem(notMyStuffID, "deIncaWarChief", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "Llama", 1, 2);
					}
					else if (whichCiv == 7)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkChinese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkDisciple", 1, 2);
					}
					else if (whichCiv == 8)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkJapanese2", 1, 2);
					}
					else if (whichCiv == 9)
					{
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian", 1, 2);
						rmAddObjectDefItem(notMyStuffID, "ypMonkIndian2", 1, 2);
					}
					else if (whichCiv == 10)
					{
						rmAddObjectDefItem(notMyStuffID, "dePrince", 1, 2);
					}
					else if (whichCiv == 11)
					{
						rmAddObjectDefItem(notMyStuffID, "deEmir", 1, 2);
					}
					else if (whichCiv == 12)
					{
						rmAddObjectDefItem(notMyStuffID, "deGrandMaster", 1, 2);
					}
					else
					{
						rmAddObjectDefItem(notMyStuffID, "Explorer", 1, 2);
						if (rmRandFloat(0,1) <= 0.25)
							rmAddObjectDefItem(notMyStuffID, "WarDog", 1, 2);
						else if (rmRandFloat(0,1) <= 0.33)
							rmAddObjectDefItem(notMyStuffID, "Envoy", 1, 2);
						else if (rmRandFloat(0,1) <= 0.50)
							rmAddObjectDefItem(notMyStuffID, "deArchitect", 1, 2);
						else
							rmAddObjectDefItem(notMyStuffID, "NativeScout", 1, 2);
					}
				}
				if (rmGetPlayerCiv(i) ==  rmGetCivID("Japanese"))
					rmAddObjectDefItem(notMyStuffID, "YPBerryWagon1", 1, 4);
				if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))
					rmAddObjectDefItem(notMyStuffID, "deLivestockMarketWagon", 1, 4);
				rmAddObjectDefToClass(notMyStuffID, rmClassID("startingUnit"));
				rmAddObjectDefToClass(notMyStuffID, classPlayer);
				rmSetObjectDefMinDistance(notMyStuffID, 08);
				rmSetObjectDefMaxDistance(notMyStuffID, 14);
				rmAddObjectDefConstraint(notMyStuffID, avoidAll);
				rmPlaceObjectDefAtLoc(notMyStuffID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
			if (everyoneGetsAWagon == 994 && butOnlySometimes == 3 && rmGetPlayerCiv(i) == rmGetCivID("Dutch"))
				rmPlaceObjectDefAtLoc(dutchBankWagonID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			else if (butOnlySometimes == 3)
				rmPlaceObjectDefAtLoc(playerWagonID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (scoutRNG >= 0.75 || merryXmass == 1 || (indonesiaMap == 1 && scoutRNG >= 0.50) || plymouthMap == 1)
				rmPlaceObjectDefAtLoc(scoutID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (chaosBar == 1 && trollBar == 1 && japanMap == 1)
			{
				rmPlaceObjectDefAtLoc(regicideID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
				regicideActivator = 1;
			}
			// GET REKT
			if (getRekt >= 0.98 && trollBar == 1)
			{
				rmPlaceObjectDefAtLoc(ripTCID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
				if (petardSpawn == 1)
				{
					rmSetPlayerResource(i, "Ships", 1);		
					rmSetPlayerResource(i, "Wood", 700);		
				}	
			}
			// chaos
			if (chaosBar == 1 && rmRandFloat(0,1) <= 0.25)
			{
				rmSetPlayerResource(i, "Ships", 1);
				speedyShipment = 1;
			}
			// MINES - sometimes two
			if (everyoneGetsAWagon != 989)	// no close mine when coal prospector wagon spawns
				rmPlaceObjectDefAtLoc(playerSilverID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (bonusSilverChance < 0.5)						  
				rmPlaceObjectDefAtLoc(playerSilverID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			rmPlaceObjectDefAtLoc(startSilver3ID, i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			// HUNT
			if (everyoneGetsAWagon != 974)	// no close hunt when cherry wagon
				rmPlaceObjectDefAtLoc(nearDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			rmPlaceObjectDefAtLoc(farDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			rmPlaceObjectDefAtLoc(farDeer2ID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			// BERRIES - 50% of the time
			if (berryChance >= 0.5)
				rmPlaceObjectDefAtLoc(playerBerryID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			// TREES
			if (shipWrecked == 1)
			{
				rmPlaceObjectDefAtLoc(playerShipwreckID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
			else
			{
				rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
 				rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
			rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (bonusTreeChance > 0.5 || rmGetIsTreaty() == true)
				rmPlaceObjectDefAtLoc(playerTreeFarID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (bonusTreeChance > 0.8)
				rmPlaceObjectDefAtLoc(playerTreeFarID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			if (sparseForests == 1)	// if sparse forests, add extra trees (and a shipwreck for lolz)
			{
				rmPlaceObjectDefAtLoc(playerShipwreckID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
				rmPlaceObjectDefAtLoc(playerTreeFarID, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			}
			// NUGGETS
			rmPlaceObjectDefAtLoc(nugget1, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			rmPlaceObjectDefAtLoc(nugget2, 0, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
    		// Japan stuff
    		if(ypIsAsian(i) && berryChance < 0.5)
    			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
			else if(ypIsAsian(i))
      			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i), i, rmXMetersToFraction(xsVectorGetX(TCLocation)), rmZMetersToFraction(xsVectorGetZ(TCLocation)));
		}
			// WATER FLAG
			int FindWater = -1;
			if (rmRandFloat(0,1) <= 0.50)
				FindWater = rmFindCloserArea(rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), flagPondID1, flagPondID3);
			else
				FindWater = rmFindCloserArea(rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), flagPondID2, flagPondID4);

		if (placeWaterFlag == 1)
		{
			rmPlaceObjectDefAtAreaLoc(waterFlagID, i, FindWater, 1);
			vector flagLocation = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(waterFlagID, i));
			if (waterScout == 1)
				rmPlaceObjectDefAtLoc(waterScoutID, i, rmXMetersToFraction(xsVectorGetX(flagLocation)), rmZMetersToFraction(xsVectorGetZ(flagLocation)));

			if (trollBar == 1 && eurekaShip == 1)
			{
				rmAddClosestPointConstraint(avoidEdge);
//				rmAddClosestPointConstraint(portOnShore);
				rmAddClosestPointConstraint(fishLand);
				if (riverExists == 1 && oceanRing == 1)
				{
					rmAddClosestPointConstraint(avoidCenterFlag);
				}
				vector closestWaterPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
				rmPlaceObjectDefAtLoc(treasureShipID, i, rmXMetersToFraction(xsVectorGetX(closestWaterPoint)), rmZMetersToFraction(xsVectorGetZ(closestWaterPoint)));
			}
		}
	}

	rmClearClosestPointConstraints();

	if (chaosBar == 1)
		rmSetStatusText("", 0.20);
	else if (trollBar == 1)
		rmSetStatusText("", 0.2);
	else
		rmSetStatusText("", 0.8);

	// ============= Other Resources =============
	// Silver
	int silverID = -1;
	int silverCount = (cNumberNonGaiaPlayers*3);
	if (rmGetNomadStart() == true)
		silverCount = cNumberNonGaiaPlayers*5;
	if (oceanRing == 1)
		silverCount = cNumberNonGaiaPlayers*5;
	if (splitIsland == 1)
		silverCount = cNumberNonGaiaPlayers*3.5;
	if (rmGetIsTreaty() == true)
		silverCount = cNumberNonGaiaPlayers*3.5;
	rmEchoInfo("silver count = "+silverCount);

	string silverType = "";

	if (caribbeanMap == 1 && rmRandFloat(0,1) <= 0.15)
	{
	   silverType = "deShipRuins";
		rmEchoInfo("silver type is deShipRuins");
	}
//	else if (africanMap == 1 && rmRandFloat(0,1) <= 0.01)
//	{
//		silverType = "deREVMineDiamondBuildable";
//		rmEchoInfo("silver type is deREVMineDiamondBuildable");
//	}
	else if (africanMap == 1 && rmRandFloat(0,1) >= 0.95)
	{
	   silverType = "MineSalt";
		rmEchoInfo("silver type is MineSalt");
	}
//	else if (rmRandFloat(0,1) <= 0.05)
//	{
//		silverType = "deMineCoalBuildable";
//		rmEchoInfo("silver type is deMineCoalBuildable");
//	}
	else if (rmRandFloat(0,1) <= 0.10)
	{
	   silverType = "zpQuarzmine";
		rmEchoInfo("silver type is zpQuarzmine");
	}
	else if (rmRandFloat(0,1) <= 0.05)
	{
	   silverType = "zpSulphurMine";
		rmEchoInfo("silver type is zpSulphurMine");
	}
	else if (rmRandFloat(0,1) <= 0.01)
	{
	   silverType = "zpDiamondMine";
		rmEchoInfo("silver type is zpDiamondMine");
	}
	else if (rmRandFloat(0,1) <= 0.10)
	{
	   silverType = "MineGold";
		rmEchoInfo("silver type is MineGold");
	}
	else if (rmRandFloat(0,1) >= 0.75)
	{
	   silverType = "MineCopper";
		rmEchoInfo("silver type is MineCopper");
	}
	else if (rmRandFloat(0,1) <= 0.05)
	{
	   silverType = "MineTin";
		rmEchoInfo("silver type is MineTin");
	}
	else if (rmRandFloat(0,1) <= 0.333)
	{
	   silverType = "zpJadeMine";
		rmEchoInfo("silver type is zpJadeMine");
	}
	else
	{
	   silverType = "mine";
		rmEchoInfo("silver type is mine");
	}

//	silverType = "deREVMineDiamondBuildable";	// for testing

	silverID = rmCreateObjectDef("silver");
	if (chaosBar == 1 && rmRandFloat(0,1) <= 0.001)
	{
	   	rmAddObjectDefItem(silverID, "ypSPCRockCrate", 20, 4.0);
        rmSetObjectDefAllowOverlap(silverID, true);
	}	
	else
		rmAddObjectDefItem(silverID, silverType, 1, 0.0);
	rmSetObjectDefMinDistance(silverID, 0.0);
	rmSetObjectDefMaxDistance(silverID, rmXFractionToMeters(0.5));
	rmAddObjectDefToClass(silverID, classGold);
	if (oceanRing == 1)
		rmAddObjectDefConstraint(silverID, avoidGoldVeryFar);
	else
		rmAddObjectDefConstraint(silverID, avoidGold);
	rmAddObjectDefConstraint(silverID, avoidCliffsShort);
	rmAddObjectDefConstraint(silverID, avoidPond);
	rmAddObjectDefConstraint(silverID, avoidElectorsShort);
	rmAddObjectDefConstraint(silverID, avoidPiratesShort);
	rmAddObjectDefConstraint(silverID, avoidAll);
	if (rmGetNomadStart() == false)
		rmAddObjectDefConstraint(silverID, avoidPlayersFar);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(silverID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(silverID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(silverID, avoidTradeRoute);
	rmAddObjectDefConstraint(silverID, avoidEdge);
	if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(silverID, avoidWaterShort);
	if (splitIsland == 1)
	{
		rmPlaceObjectDefInArea(silverID, 0, rmAreaID("split island 1"), silverCount/2);
		rmPlaceObjectDefInArea(silverID, 0, rmAreaID("split island 2"), silverCount/2);
	}
	else
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5, silverCount);
	if (rmGetIsTreaty() == true)
		rmPlaceObjectDefAtLoc(silverID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);

	// Food
	int bisonID = rmCreateObjectDef("large herds");
   	if (trollMap == 1 || rmRandFloat(0,1) <= 0.0001)
	{
	   rmAddObjectDefItem(bisonID, "zpFeralPig", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "zpRedNeckedWallaby", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "zpRedKangaroo", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "zpKiwi", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "zpEmu", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypWildElephant", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "deZebra", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "deOstrich", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "bison", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "tapir", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "deer", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "moose", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "elk", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "pronghorn", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "deGiraffe", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "capybara", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "guanaco", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "turkey", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypGiantSalamander", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypSerow", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypMuskdeer", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "MuskOx", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "caribou", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypNilgai", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypIbex", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypMarcoPoloSheep", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "BighornSheep", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "Rhea", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "ypSaiga", 1, 10.0);
	   rmAddObjectDefItem(bisonID, "Gazelle", 1, 10.0);
	}
	else 
		rmAddObjectDefItem(bisonID, critterOneName, rmRandInt(12,16), 8.0);
	rmSetObjectDefMinDistance(bisonID, 0.0);
	rmSetObjectDefMaxDistance(bisonID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(bisonID, avoidAll);
	rmAddObjectDefConstraint(bisonID, avoidTradeRouteSocketShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(bisonID, shortAvoidImpassableLand);
	if (oceanRing == 1)
	{
		rmAddObjectDefConstraint(bisonID, avoidFood1Far);
		rmAddObjectDefConstraint(bisonID, avoidFood2Far);
	}
	else
	{
		rmAddObjectDefConstraint(bisonID, avoidFood1);
		rmAddObjectDefConstraint(bisonID, avoidFood2);
	}
	rmAddObjectDefConstraint(bisonID, avoidGoldMin);
	if (trollMap == 1)
		rmAddObjectDefConstraint(bisonID, avoidHuntable);
	rmAddObjectDefConstraint(bisonID, avoidEdge);
	rmAddObjectDefConstraint(bisonID, avoidForestMin);
	if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(bisonID, avoidWater);
	if (frozenLake != 1)
	{
		rmAddObjectDefConstraint(bisonID, avoidCliffsMed);
		rmAddObjectDefConstraint(bisonID, avoidPond);
	}
	if (chaosBar == 1 && trollBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetObjectDefCreateHerd(bisonID, false);
	else
		rmSetObjectDefCreateHerd(bisonID, true);
	if (rmGetNomadStart() == false)
	{
		rmAddObjectDefConstraint(bisonID, avoidPlayersFar1);
		rmPlaceObjectDefAtLoc(bisonID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2.5);
	}
	else
	{
		rmAddObjectDefConstraint(bisonID, avoidPlayers);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(bisonID, 0, rmAreaID("split island 1"), 1+cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(bisonID, 0, rmAreaID("split island 2"), 1+cNumberNonGaiaPlayers);
		}
		else
			rmPlaceObjectDefAtLoc(bisonID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers*2);
	}
	if (rmGetIsTreaty() == true)
		rmPlaceObjectDefAtLoc(bisonID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	int pronghornID = rmCreateObjectDef("small herds");
		if (trollMap == 1)
		rmAddObjectDefItem(pronghornID, critterOneName, rmRandInt(7,8), 4.0);
	else
		rmAddObjectDefItem(pronghornID, critterTwoName, rmRandInt(7,8), 4.0);
	rmSetObjectDefMinDistance(pronghornID, 0.0);
	rmSetObjectDefMaxDistance(pronghornID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(pronghornID, avoidElectorsShort);
	rmAddObjectDefConstraint(pronghornID, avoidPiratesShort);
	rmAddObjectDefConstraint(pronghornID, avoidAll);
	rmAddObjectDefConstraint(pronghornID, avoidTradeRouteSocketShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(pronghornID, shortAvoidImpassableLand);
	if (oceanRing == 1)
	{
		rmAddObjectDefConstraint(pronghornID, avoidFood1Far);
		rmAddObjectDefConstraint(pronghornID, avoidFood2Far);
	}
	else
	{
		rmAddObjectDefConstraint(pronghornID, avoidFood1);
		rmAddObjectDefConstraint(pronghornID, avoidFood2);
	}
	rmAddObjectDefConstraint(pronghornID, avoidGoldMin);
	if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(pronghornID, avoidWaterShort);
	if (trollMap == 1)
		rmAddObjectDefConstraint(pronghornID, avoidHuntable);
	rmAddObjectDefConstraint(pronghornID, avoidEdge);
	rmAddObjectDefConstraint(pronghornID, avoidForestMin);
	if (frozenLake != 1)
	{
		rmAddObjectDefConstraint(pronghornID, avoidCliffsShort);
		rmAddObjectDefConstraint(pronghornID, avoidPond);
	}
	if (chaosBar == 1 && trollBar == 1 && rmRandFloat(0,1) <= 0.01)
		rmSetObjectDefCreateHerd(pronghornID, false);
	else
		rmSetObjectDefCreateHerd(pronghornID, true);
	if (rmGetNomadStart() == false)
	{
		rmAddObjectDefConstraint(pronghornID, avoidPlayersFar1);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(pronghornID, 0, rmAreaID("split island 1"), 1.25*cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(pronghornID, 0, rmAreaID("split island 2"), 1.25*cNumberNonGaiaPlayers);
		}
		else
 			rmPlaceObjectDefAtLoc(pronghornID, 0, 0.5, 0.5, 2.5*cNumberNonGaiaPlayers);
	}
	else
	{
		rmAddObjectDefConstraint(pronghornID, avoidPlayers);
		rmPlaceObjectDefAtLoc(pronghornID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers*2);
	}
	if (rmGetIsTreaty() == true)
		rmPlaceObjectDefAtLoc(pronghornID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);

	// Livestock
	int sheepID = rmCreateObjectDef("livestock");
	if (rmRandFloat(0,1) <= 0.001)
		rmAddObjectDefItem(sheepID, "deUnknownWoodCattle", 2, 4.0);
	else if (rmRandFloat(0,1) <= 0.001)
		rmAddObjectDefItem(sheepID, "deUnknownGoldCattle", 2, 4.0);
	else
		rmAddObjectDefItem(sheepID, livestockName, 2, 4.0);
	rmSetObjectDefMinDistance(sheepID, 0.0);
	rmSetObjectDefMaxDistance(sheepID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(sheepID, avoidFood);
	rmAddObjectDefConstraint(sheepID, avoidGoldMin);
	if (oceanRing == 1 || splitIsland == 1)
		rmAddObjectDefConstraint(sheepID, avoidWaterShort);
	if (frozenLake != 1)
	{
		rmAddObjectDefConstraint(sheepID, avoidCliffsShort);
		rmAddObjectDefConstraint(sheepID, avoidPond);
	}
	rmAddObjectDefConstraint(sheepID, avoidElectorsShort);
	rmAddObjectDefConstraint(sheepID, avoidPiratesShort);
	rmAddObjectDefConstraint(sheepID, avoidAll);
	if (splitIsland == 1)
		rmAddObjectDefConstraint(sheepID, avoidPlayersFar1);
	else
		rmAddObjectDefConstraint(sheepID, avoidPlayersFar);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(sheepID, shortAvoidImpassableLand);
	if(rmRandFloat(0,1) > 0.20)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(sheepID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(sheepID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers);
		}
		else
 	   		rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
   		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(sheepID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 1.00);
	else if (trollBar == 1)
		rmSetStatusText("", 0.1);
	else
		rmSetStatusText("", 0.9);

	// Treasures
	int howCrazyIsTooCrazy = rmRandInt(1,61);	// randomly selects some crazy treasures
	float someRNG = rmRandFloat(0,1);			// additional RNG for fun
//		someRNG = 0.01;		// for testing

	int nuggetHuariID = rmCreateObjectDef("huari stronghold nuggz"); 
	rmAddObjectDefItem(nuggetHuariID, "HuariStrongholdAndes", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetHuariID, 0.00);
	rmSetObjectDefMaxDistance(nuggetHuariID, rmXFractionToMeters(0.20));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetHuariID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHuariID, avoidHuari);
	rmAddObjectDefConstraint(nuggetHuariID, avoidNuggetFar);
	rmAddObjectDefConstraint(nuggetHuariID, avoidPlayersFar);
	rmAddObjectDefConstraint(nuggetHuariID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetHuariID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHuariID, avoidGoldMin);
	rmAddObjectDefConstraint(nuggetHuariID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetHuariID, avoidPond);
	rmAddObjectDefConstraint(nuggetHuariID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetHuariID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetHuariID, avoidAll);
	if (andesMap == 1 && someRNG <= 0.05)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetHuariID, 0, rmAreaID("split island 1"), 2);
			rmPlaceObjectDefInArea(nuggetHuariID, 0, rmAreaID("split island 2"), 2);
		}
		else
 		  	rmPlaceObjectDefAtLoc(nuggetHuariID, 0, 0.5, 0.5, 4);
	}

	int nuggetProspectorID = rmCreateObjectDef("unknown prospector nuggets"); 
	if (amazonMap == 1 && rmRandFloat(0,1) <= 0.50)
		rmAddObjectDefItem(nuggetProspectorID, "SPCAztecMap", 1, 0.0);
	else
	{
		rmAddObjectDefItem(nuggetProspectorID, "Nugget", 1, 0.0);
		rmSetObjectDefMinDistance(nuggetProspectorID, 0.00);
		rmSetObjectDefMaxDistance(nuggetProspectorID, rmXFractionToMeters(0.069));
		if (floodedLand != 1)
			rmAddObjectDefConstraint(nuggetProspectorID, shortAvoidImpassableLand);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidNuggetFar);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidPlayers);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidTradeRouteSocketShort);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidTradeRoute);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidGoldMin);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidCliffsShort);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidPond);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidNativesShort);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidElectorsShort);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidPiratesShort);
		rmAddObjectDefConstraint(nuggetProspectorID, avoidAll);
		if (rmGetIsTreaty() == true)
			rmSetNuggetDifficulty(12345,12345);
		else
			rmSetNuggetDifficulty(12345,12346);
	}
	if (someRNG <= 0.05 || trollMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetProspectorID, 0, rmAreaID("split island 1"), 1);
			rmPlaceObjectDefInArea(nuggetProspectorID, 0, rmAreaID("split island 2"), 1);
		}
		else
 		  	rmPlaceObjectDefAtLoc(nuggetProspectorID, 0, 0.5, 0.5, 1);
	}

	int nuggetUnknownID = rmCreateObjectDef("unknown special nuggets"); 
	rmAddObjectDefItem(nuggetUnknownID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetUnknownID, 0.00);
	rmSetObjectDefMaxDistance(nuggetUnknownID, rmXFractionToMeters(0.40+0.005*cNumberNonGaiaPlayers));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetUnknownID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidNuggetFar);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidPlayers);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidGoldMin);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidPond);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidNativesShort);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetUnknownID, avoidAll);
	if (oceaniaMap == 1)
	{
		if (cNumberNonGaiaPlayers == 2 || rmGetIsFFA() == true)
			rmSetNuggetDifficulty(23,23);
		else 
			rmSetNuggetDifficulty(23,24);
	}
	else
	{
		if (cNumberNonGaiaPlayers == 2 || rmGetIsFFA() == true)
			rmSetNuggetDifficulty(13,13);
		else 
			rmSetNuggetDifficulty(13,14);
	}
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetUnknownID, 0, rmAreaID("split island 1"), 3+cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(nuggetUnknownID, 0, rmAreaID("split island 2"), 3+cNumberNonGaiaPlayers);
		}
	else
	{
	  	rmPlaceObjectDefAtLoc(nuggetUnknownID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*2);
		if (rmGetIsTreaty() == true)
	  		rmPlaceObjectDefAtLoc(nuggetUnknownID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	int nuggetHMID = rmCreateObjectDef("HM nuggz"); 
	rmAddObjectDefItem(nuggetHMID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetHMID, 0.00);
	rmSetObjectDefMaxDistance(nuggetHMID, rmXFractionToMeters(0.20));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetHMID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHMID, avoidNugget);
	rmAddObjectDefConstraint(nuggetHMID, avoidPlayers);
	rmAddObjectDefConstraint(nuggetHMID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetHMID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetHMID, avoidGoldMin);
	rmAddObjectDefConstraint(nuggetHMID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetHMID, avoidPond);
	rmAddObjectDefConstraint(nuggetHMID, avoidNativesShort);
	rmAddObjectDefConstraint(nuggetHMID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetHMID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetHMID, avoidAll);
	rmSetNuggetDifficulty(104,104);
	if (euMap == 1 && cNumberNonGaiaPlayers > 2 && rmRandFloat(0,1) <= 0.05)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetHMID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(nuggetHMID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers);
		}
		else
	    	rmPlaceObjectDefAtLoc(nuggetHMID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	}

	int nuggetAf12ID = rmCreateObjectDef("african nugget12"); 
	rmAddObjectDefItem(nuggetAf12ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetAf12ID, 0.00);
	rmSetObjectDefMaxDistance(nuggetAf12ID, rmXFractionToMeters(0.30));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetAf12ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidNugget);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidPlayers);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidGoldMin);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidPond);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidNativesShort);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetAf12ID, avoidAll);
	rmSetNuggetDifficulty(12,12);
	if (trollMap == 1 && cNumberNonGaiaPlayers > 2 && rmGetIsFFA() == false && trollBar == 1)	// troll map only because op
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetAf12ID, 0, rmAreaID("split island 1"), 1);
			rmPlaceObjectDefInArea(nuggetAf12ID, 0, rmAreaID("split island 2"), 1);
		}
		else
	    	rmPlaceObjectDefAtLoc(nuggetAf12ID, 0, 0.5, 0.5, 1);
	}

	int houseNuggetID = rmCreateObjectDef("house nugget");	// some biomes chance of outpost treasures
	rmAddObjectDefItem(houseNuggetID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(houseNuggetID, 0.025);
	rmSetObjectDefMaxDistance(houseNuggetID, rmXFractionToMeters(0.15));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(houseNuggetID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(houseNuggetID, avoidNugget);
	rmAddObjectDefConstraint(houseNuggetID, avoidPlayersFar1);
	rmAddObjectDefConstraint(houseNuggetID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(houseNuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(houseNuggetID, avoidGoldMin);
	rmAddObjectDefConstraint(houseNuggetID, avoidCliffsShort);
	rmAddObjectDefConstraint(houseNuggetID, avoidPond);
	rmAddObjectDefConstraint(houseNuggetID, avoidNativesShort);
	rmAddObjectDefConstraint(houseNuggetID, avoidElectorsShort);
	rmAddObjectDefConstraint(houseNuggetID, avoidPiratesShort);
	rmAddObjectDefConstraint(houseNuggetID, avoidAll);
	rmSetNuggetDifficulty(121, 121);
	if (someRNG <= 0.5 && (rockiesMap == 1 || saguenayMap == 1 || euMap == 1 || asianMap == 1 || plymouthMap == 1 || icelandMap == 1))
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(houseNuggetID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(houseNuggetID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(houseNuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	int crazyNugget1ID = rmCreateObjectDef("crazy nugget 1"); 
	rmAddObjectDefItem(crazyNugget1ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(crazyNugget1ID, 0.00);
	rmSetObjectDefMaxDistance(crazyNugget1ID, rmXFractionToMeters(0.23));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(crazyNugget1ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidNugget);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidPlayersFar1);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidTradeRoute);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidGoldMin);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidCliffsShort);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidPond);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidNativesShort);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidElectorsShort);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidPiratesShort);
	rmAddObjectDefConstraint(crazyNugget1ID, avoidAll);
	if (howCrazyIsTooCrazy < 11)
		rmSetNuggetDifficulty(33, 33);
	else if (howCrazyIsTooCrazy < 21)
		rmSetNuggetDifficulty(44, 44);
	else if (howCrazyIsTooCrazy < 31)
		rmSetNuggetDifficulty(55, 55);
	else if (howCrazyIsTooCrazy < 41)
		rmSetNuggetDifficulty(69, 69);
	else if (howCrazyIsTooCrazy < 51)
		rmSetNuggetDifficulty(97, 97);
    else
		rmSetNuggetDifficulty(444, 444);
	if (africanMap == 1 || trollMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(crazyNugget1ID, 0, rmAreaID("split island 1"), 1+cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(crazyNugget1ID, 0, rmAreaID("split island 2"), 1+cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(crazyNugget1ID, 0, 0.5, 0.5, 2+cNumberNonGaiaPlayers);
	}

	int crazyNuggetBorneoID = rmCreateObjectDef("crazy borneo nuggets"); 
	rmAddObjectDefItem(crazyNuggetBorneoID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(crazyNuggetBorneoID, 0.00);
	rmSetObjectDefMaxDistance(crazyNuggetBorneoID, rmXFractionToMeters(0.23));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(crazyNuggetBorneoID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidNugget);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidPlayersFar1);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidTradeRoute);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidGoldMin);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidCliffsShort);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidPond);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidNativesShort);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidElectorsShort);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidPiratesShort);
	rmAddObjectDefConstraint(crazyNuggetBorneoID, avoidAll);
	if (howCrazyIsTooCrazy < 19)
		rmSetNuggetDifficulty(33, 33);
	else if (howCrazyIsTooCrazy < 37)
		rmSetNuggetDifficulty(44, 44);
	else if (howCrazyIsTooCrazy < 45)
		rmSetNuggetDifficulty(55, 55);
	else
		rmSetNuggetDifficulty(69, 69);
	if (borneoMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(crazyNuggetBorneoID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(crazyNuggetBorneoID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(crazyNuggetBorneoID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	int crazyNuggetEuroID = rmCreateObjectDef("crazy euro nuggets"); 
	rmAddObjectDefItem(crazyNuggetEuroID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(crazyNuggetEuroID, 0.00);
	rmSetObjectDefMaxDistance(crazyNuggetEuroID, rmXFractionToMeters(0.23));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(crazyNuggetEuroID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidNugget);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidPlayersFar1);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidTradeRoute);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidGoldMin);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidCliffsShort);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidPond);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidNativesShort);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidElectorsShort);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidPiratesShort);
	rmAddObjectDefConstraint(crazyNuggetEuroID, avoidAll);
	if (howCrazyIsTooCrazy < 29)
		rmSetNuggetDifficulty(44, 44);
	else if (howCrazyIsTooCrazy < 39 && rmGetIsTreaty() == false)
		rmSetNuggetDifficulty(777, 777);
	else
		rmSetNuggetDifficulty(69, 69);
	if (euMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(crazyNuggetEuroID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(crazyNuggetEuroID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(crazyNuggetEuroID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	int crazyNugget2ID = rmCreateObjectDef("crazy nugget 2"); 
	rmAddObjectDefItem(crazyNugget2ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(crazyNugget2ID, 0.00);
	rmSetObjectDefMaxDistance(crazyNugget2ID, rmXFractionToMeters(0.23));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(crazyNugget2ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidNugget);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidPlayersFar1);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidTradeRoute);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidGoldMin);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidCliffsShort);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidPond);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidNativesShort);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidElectorsShort);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidPiratesShort);
	rmAddObjectDefConstraint(crazyNugget2ID, avoidAll);
	if (trollMap == 1)
		rmSetNuggetDifficulty(666, 671);
	else 
		rmSetNuggetDifficulty(667, 671);
	if (africanMap == 1 || trollMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(crazyNugget2ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(crazyNugget2ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(crazyNugget2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}
	
	int nugget12ID = rmCreateObjectDef("team nugget12"); 
	rmAddObjectDefItem(nugget12ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget12ID, 0.00);
	rmSetObjectDefMaxDistance(nugget12ID, rmXFractionToMeters(0.30));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget12ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget12ID, avoidNuggetMed);
	rmAddObjectDefConstraint(nugget12ID, avoidPlayers);
	rmAddObjectDefConstraint(nugget12ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nugget12ID, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget12ID, avoidGoldMin);
	rmAddObjectDefConstraint(nugget12ID, avoidCliffsShort);
	rmAddObjectDefConstraint(nugget12ID, avoidPond);
	rmAddObjectDefConstraint(nugget12ID, avoidNativesShort);
	rmAddObjectDefConstraint(nugget12ID, avoidElectorsShort);
	rmAddObjectDefConstraint(nugget12ID, avoidPiratesShort);
	rmAddObjectDefConstraint(nugget12ID, avoidAll);
	rmSetNuggetDifficulty(12,12);
    if (bayouMap == 1 || gpMap == 1 || saguenayMap == 1 || amazonMap == 1 || sonoraMap == 1 || rockiesMap == 1 || caribbeanMap == 1 || carolinaMap == 1 || andesMap == 1 || californiaMap == 1 || japanMap == 1 || dekkanMap == 1 || (borneoMap == 1 && asianMap == 1) || yellowRiverMap == 1 || himalMap == 1)
	{
		if (cNumberNonGaiaPlayers > 2 && rmGetIsFFA() == false)
		{
			if (splitIsland == 1)
			{
				rmPlaceObjectDefInArea(nugget12ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
				rmPlaceObjectDefInArea(nugget12ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
			}
			else
		    	rmPlaceObjectDefAtLoc(nugget12ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		}
	}

	int nuggetDuberID = rmCreateObjectDef("duber nuggz"); 
	rmAddObjectDefItem(nuggetDuberID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetDuberID, 0.00);
	rmSetObjectDefMaxDistance(nuggetDuberID, rmXFractionToMeters(0.25));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetDuberID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetDuberID, avoidNuggetShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidPlayers);
	rmAddObjectDefConstraint(nuggetDuberID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetDuberID, avoidGoldMin);
	rmAddObjectDefConstraint(nuggetDuberID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidPond);
	rmAddObjectDefConstraint(nuggetDuberID, avoidNativesShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetDuberID, avoidAll);
	rmSetNuggetDifficulty(96,96);
    if (himalMap == 1)
	{
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetDuberID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(nuggetDuberID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers);
		}
		else
	    	rmPlaceObjectDefAtLoc(nuggetDuberID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	}

	int nugget4ID = rmCreateObjectDef("map nugget4"); 
	rmAddObjectDefItem(nugget4ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget4ID, 0.00);
	rmSetObjectDefMaxDistance(nugget4ID, rmXFractionToMeters(0.20));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget4ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget4ID, avoidNuggetMed);
	rmAddObjectDefConstraint(nugget4ID, avoidPlayers);
	rmAddObjectDefConstraint(nugget4ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nugget4ID, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget4ID, avoidGoldMin);
	rmAddObjectDefConstraint(nugget4ID, avoidCliffsShort);
	rmAddObjectDefConstraint(nugget4ID, avoidPond);
	rmAddObjectDefConstraint(nugget4ID, avoidNativesShort);
	rmAddObjectDefConstraint(nugget4ID, avoidElectorsShort);
	rmAddObjectDefConstraint(nugget4ID, avoidPiratesShort);
	rmAddObjectDefConstraint(nugget4ID, avoidAll);
	if (mediSeaEU == 1)
	{
		rmSetNuggetDifficulty(74,74);
		if (cNumberNonGaiaPlayers > 2 && rmGetIsTreaty() == false)
		{
			if (splitIsland == 1)
			{
				rmPlaceObjectDefInArea(nugget4ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/4);
				rmPlaceObjectDefInArea(nugget4ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/4);
			}
			else
				rmPlaceObjectDefAtLoc(nugget4ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
		}
	}
	else
	{
		rmSetNuggetDifficulty(4,4);
		if (cNumberNonGaiaPlayers > 2 && rmGetIsTreaty() == false)
		{
			if (splitIsland == 1)
			{
				rmPlaceObjectDefInArea(nugget4ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
				rmPlaceObjectDefInArea(nugget4ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
			}
			else
				rmPlaceObjectDefAtLoc(nugget4ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		}
	}
	
	int nugget3ID = rmCreateObjectDef("map nugget3"); 
	rmAddObjectDefItem(nugget3ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget3ID, 0.025);
	rmSetObjectDefMaxDistance(nugget3ID, rmXFractionToMeters(0.30));
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget3ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3ID, avoidNuggetMed);
	rmAddObjectDefConstraint(nugget3ID, avoidPlayers);
	rmAddObjectDefConstraint(nugget3ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nugget3ID, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3ID, avoidGoldMin);
	rmAddObjectDefConstraint(nugget3ID, avoidCliffsShort);
	rmAddObjectDefConstraint(nugget3ID, avoidPond);
	rmAddObjectDefConstraint(nugget3ID, avoidNativesShort);
	rmAddObjectDefConstraint(nugget3ID, avoidElectorsShort);
	rmAddObjectDefConstraint(nugget3ID, avoidPiratesShort);
	rmAddObjectDefConstraint(nugget3ID, avoidAll);
	if (mediSeaEU == 1)
	{
		rmSetNuggetDifficulty(73,73);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nugget3ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/4);
			rmPlaceObjectDefInArea(nugget3ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/4);
		}
		else
			rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
	}
	else
	{
		rmSetNuggetDifficulty(3,3);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nugget3ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(nugget3ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}
	
	int nugget2ID = rmCreateObjectDef("map nugget2"); 
	rmAddObjectDefItem(nugget2ID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2ID, 0.15);
	rmSetObjectDefMaxDistance(nugget2ID, rmXFractionToMeters(0.45));
   if (oceanRing == 1 || splitIsland == 1)
	    rmAddObjectDefConstraint(nugget2ID, avoidWaterShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nugget2ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2ID, avoidNuggetMed);
	rmAddObjectDefConstraint(nugget2ID, avoidPlayers);
	rmAddObjectDefConstraint(nugget2ID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nugget2ID, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2ID, avoidGoldMin);
	rmAddObjectDefConstraint(nugget2ID, avoidCliffsShort);
	rmAddObjectDefConstraint(nugget2ID, avoidPond);
	rmAddObjectDefConstraint(nugget2ID, avoidNativesShort);
	rmAddObjectDefConstraint(nugget2ID, avoidElectorsShort);
	rmAddObjectDefConstraint(nugget2ID, avoidPiratesShort);
	rmAddObjectDefConstraint(nugget2ID, avoidAll);
	if (mediSeaEU == 1)
	{
		rmSetNuggetDifficulty(72,72);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nugget2ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/4);
			rmPlaceObjectDefInArea(nugget2ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/4);
		}
		else
			rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers/2);
	}
	else
	{
		rmSetNuggetDifficulty(2,2);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nugget2ID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers/2);
			rmPlaceObjectDefInArea(nugget2ID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers/2);
		}
		else
			rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
	}

	int nuggetID = rmCreateObjectDef("map nugget"); 
	rmAddObjectDefItem(nuggetID, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID, 0.25);
	rmSetObjectDefMaxDistance(nuggetID, rmXFractionToMeters(0.48));
   if (oceanRing == 1 || splitIsland == 1)
	    rmAddObjectDefConstraint(nuggetID, avoidWaterShort);
	if (floodedLand != 1)
		rmAddObjectDefConstraint(nuggetID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetID, avoidNugget);
	rmAddObjectDefConstraint(nuggetID, avoidPlayers);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRouteSocketShort);
	rmAddObjectDefConstraint(nuggetID, avoidTradeRoute);
	rmAddObjectDefConstraint(nuggetID, avoidCliffsShort);
	rmAddObjectDefConstraint(nuggetID, avoidNativesShort);
	rmAddObjectDefConstraint(nuggetID, avoidElectorsShort);
	rmAddObjectDefConstraint(nuggetID, avoidPiratesShort);
	rmAddObjectDefConstraint(nuggetID, avoidAll);
	rmAddObjectDefConstraint(nuggetID, avoidPond);
	rmAddObjectDefConstraint(nuggetID, avoidGoldMin);
	if (mediSeaEU == 1)
	{
		rmSetNuggetDifficulty(71,71);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers);
			rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers);
		}
		else
			rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*1.5);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*1.5);
	}
	else
	{
		rmSetNuggetDifficulty(1,1);
		if (splitIsland == 1)
		{
			rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("split island 1"), cNumberNonGaiaPlayers*1.5);
			rmPlaceObjectDefInArea(nuggetID, 0, rmAreaID("split island 2"), cNumberNonGaiaPlayers*1.5);
		}
		else
			rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
		if (rmGetIsTreaty() == true)
			rmPlaceObjectDefAtLoc(nuggetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
	}
	
	// add fish if flag
	if (placeWaterFlag == 1)
	{
		int fishID = rmCreateObjectDef("fish");
		if (rmRandFloat(0,1) <= 0.001)
			rmAddObjectDefItem(fishID, "deFishingGround", 1, 0.0);
		else if (rmRandFloat(0,1) <= 0.001)
			rmAddObjectDefItem(fishID, "zpBarracudaColony", 1, 0.0);
		else
			rmAddObjectDefItem(fishID, fishName, 2, 5.0);
		rmSetObjectDefMinDistance(fishID, 0.0);
		if (splitIsland == 1)
			rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.45));
		else
			rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.50));
		if (oceanRing == 1 || splitIsland == 1)
			rmAddObjectDefConstraint(fishID, fishVsFishFar);
		else
			rmAddObjectDefConstraint(fishID, fishVsFishID);
		rmAddObjectDefConstraint(fishID, avoidPiratesShort);
		rmAddObjectDefConstraint(fishID, pondConstraintFish);
		rmAddObjectDefConstraint(fishID, fishLand);
		rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers + 6);
		if (oceanOffCenter == 1 && oceanMiddle == 1)
			rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers + 6);
		if (oceanRing == 1 && oceanMiddle == 1)
			rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers + 6);
		if (oceanRing == 1 && riverExists == 1)
			rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, cNumberNonGaiaPlayers + 6);
		if (oceanOffCenter == 1 && riverExists == 1)
			rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, cNumberNonGaiaPlayers + 6);
		if (oceanRing == 1 || splitIsland == 1)
			rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 3*cNumberNonGaiaPlayers + 10);

		// and usually whales
		if (whaleSpawner == 1)
		{
			int whaleID = rmCreateObjectDef("whale");
			rmAddObjectDefItem(whaleID, whaleName, 1, 0.0);
			rmSetObjectDefMinDistance(whaleID, 0.0);
			if (splitIsland == 1)
				rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.43));
			else
				rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.50));
			if (oceanRing == 1 || splitIsland == 1)
				rmAddObjectDefConstraint(whaleID, whaleVsWhaleFar);
			else
				rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
			rmAddObjectDefConstraint(whaleID, avoidPiratesShort);
			rmAddObjectDefConstraint(whaleID, pondConstraintFish);
			rmAddObjectDefConstraint(whaleID, whaleLand);
			rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers + 1);
			if (oceanOffCenter == 1 && oceanMiddle == 1)
				rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers + 1);
			if (oceanRing == 1 && oceanMiddle == 1)
				rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3);
			if (oceanRing == 1 || splitIsland == 1)
				rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 3);
			if (oceanRing == 1 || splitIsland == 1)
				rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		}

		int nuggetWetterID = rmCreateObjectDef("wetter nugget"); 
		rmAddObjectDefItem(nuggetWetterID, "ypNuggetBoat", 1, 0.0);
		rmSetObjectDefMinDistance(nuggetWetterID, 0.00);
		rmSetObjectDefMaxDistance(nuggetWetterID, rmXFractionToMeters(0.48));
		rmAddObjectDefConstraint(nuggetWetterID, avoidNuggetFar);
		rmAddObjectDefConstraint(nuggetWetterID, whaleLandFar);
		rmAddObjectDefConstraint(nuggetWetterID, avoidPiratesShort);
		rmAddObjectDefConstraint(nuggetWetterID, avoidAll);
		rmAddObjectDefConstraint(nuggetWetterID, avoidPond);
		rmAddObjectDefConstraint(nuggetWetterID, flagVsFlag);
		rmSetNuggetDifficulty(6,6);
		if (waterNuggz == 1)
		{
			rmPlaceObjectDefAtLoc(nuggetWetterID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
			if (oceanRing == 1 || splitIsland == 1)
				rmPlaceObjectDefAtLoc(nuggetWetterID, 0, 0.5, 0.5, cNumberNonGaiaPlayers);
		}

		int nuggetWetID = rmCreateObjectDef("wet nugget"); 
		rmAddObjectDefItem(nuggetWetID, "ypNuggetBoat", 1, 0.0);
		rmSetObjectDefMinDistance(nuggetWetID, 0.00);
		rmSetObjectDefMaxDistance(nuggetWetID, rmXFractionToMeters(0.48));
		rmAddObjectDefConstraint(nuggetWetID, avoidNugget);
		rmAddObjectDefConstraint(nuggetWetID, whaleLand);
		rmAddObjectDefConstraint(nuggetWetID, avoidPiratesShort);
		rmAddObjectDefConstraint(nuggetWetID, avoidAll);
		rmAddObjectDefConstraint(nuggetWetID, avoidPond);
		rmAddObjectDefConstraint(nuggetWetID, flagVsFlag);
		rmSetNuggetDifficulty(5,5);
		if (waterNuggz == 1)
		{
			rmPlaceObjectDefAtLoc(nuggetWetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
			if (oceanRing == 1 || splitIsland == 1)
				rmPlaceObjectDefAtLoc(nuggetWetID, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3);
		}
	}

	// triggers and RNG not player specific
	if (tpCapture == 1)
	{
	    // Capturable Trade Posts
	    int numPosts = 2;

		if (tpVariation < 3)
		{
			numPosts = 4;

			if (riverExists != 1 && cNumberNonGaiaPlayers > 4 && tpVariation == 1)
			{
				numPosts = 6;
			}

			if (riverExists != 1 && cNumberNonGaiaPlayers > 6 && tpVariation == 1)
			{
				numPosts = 8;
			}
		}
		else
		{
			if (tpVariation > 4 && riverExists != 1)
			{
				numPosts = 3;
			}

			if (tpVariation > 6 || cNumberNonGaiaPlayers > 4)
			{
				numPosts = 5;
			}
		}

	    int triggerCounter = 0;
	    int tempCounter = 0;

	    for (i = 0; < numPosts)
	    {
	        rmCreateTrigger("GuardianDeath" + triggerCounter);
	        rmSwitchToTrigger(rmTriggerID("GuardianDeath" + triggerCounter));
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

	        rmCreateTrigger("DisableAutoconvert" + triggerCounter);
	        rmSwitchToTrigger(rmTriggerID("DisableAutoconvert" + triggerCounter));
	        rmSetTriggerPriority(4);
	        rmSetTriggerActive(true);
	        rmSetTriggerRunImmediately(true);
	        rmSetTriggerLoop(false);

	        rmAddTriggerCondition("Always");

	        rmAddTriggerEffect("Unit Action Suspend");

	        rmSetTriggerEffectParamInt("SrcObject", rmGetUnitPlaced(socketID, triggerCounter), false);

	        rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	        rmSetTriggerEffectParam("Suspend", "True", false);

	        tempCounter = tempCounter + 2;

	        triggerCounter = tempCounter;
	    }
	}

	if (rmRandFloat(0,1) <= 0.20 && euMap == 1 && tpORnot != 5 && everyoneGetsAWagon <= 970 && everyoneGetsAWagon >= 950)
	{
        rmCreateTrigger("setupRailroad");
        rmSwitchToTrigger(rmTriggerID("setupRailroad"));
        rmSetTriggerPriority(4); 
        rmSetTriggerActive(true);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        rmAddTriggerEffect("Trade Route Apply Tech");
        rmSetTriggerEffectParamInt("TradeRoute", tradeRouteID+1, false);
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DETradeRouteUpgradeEurope1"), false);

		if (rmRandFloat(0,1) <= 0.25)
		{
	        rmAddTriggerEffect("Trade Route Apply Tech");
	        rmSetTriggerEffectParamInt("TradeRoute", tradeRouteID+1, false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DETradeRouteUpgradeEurope2"), false);
		}
	}

	if (rmRandFloat(0,1) <= 0.001 || (getRekt >= 0.98 && petardSpawn == 1))
	{
		rmSetNumberInitialColonies(rmRandInt(0,2));		// chance of bonus starting units if tc destroyed
	}

	if (getRekt >= 0.98 && petardSpawn == 1)
	{
    	rmCreateTrigger("getrektwarning");
    	rmSwitchToTrigger(rmTriggerID("getrektwarning"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 1, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>GET REKT 21", false);

    	rmCreateTrigger("rebuildmessage");
    	rmSwitchToTrigger(rmTriggerID("rebuildmessage"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 10, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>Rebuild your town!", false);

    	rmCreateTrigger("taunt21");
    	rmSwitchToTrigger(rmTriggerID("taunt21"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 2, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "21", false);

		rmCreateTrigger("tankypetards");
		rmSwitchToTrigger(rmTriggerID("tankypetards"));
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerPriority(4);
		rmSetTriggerLoop(false);
		rmAddTriggerCondition("Always");
		rmAddTriggerEffect("Modify Protounit Data");
		rmSetTriggerEffectParam("Protounit", "xpPetardNitro");
		rmSetTriggerEffectParamInt("PlayerID", 0);
		rmSetTriggerEffectParamInt("Field", 0);				// hitpoints
		rmSetTriggerEffectParamInt("Delta", 1000);			// 1000%
		rmSetTriggerEffectParamInt("Relativity", 3);		// base percent
	}

	if (regicideActivator == 1)
	{
    	rmCreateTrigger("regicidemessage");
    	rmSwitchToTrigger(rmTriggerID("regicidemessage"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 4, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>It's regicide! Keep your Daimyo alive or else you lose!", false);
	}

	if (speedyShipment == 1)
	{
		rmCreateTrigger("BackToNormalTrigger");
		rmAddTriggerCondition("Timer");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		rmSwitchToTrigger(rmTriggerID("BackToNormalTrigger"));
		rmSetTriggerConditionParamInt("Param1", 30);	
		rmAddTriggerEffect("Rate Research");
		rmSetTriggerEffectParamFloat("Rate", 1.0);
//		rmAddTriggerEffect("Message");
//		rmSetTriggerEffectParam("Text", "Homecity research rates are back to normal.");	
		rmAddTriggerEffect("Send Chat");
		rmSetTriggerEffectParamInt("PlayerID", 0, false);
		rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>Homecity research rates are back to normal.", false);

		rmCreateTrigger("ResearchTrigger");
		rmSwitchToTrigger(rmTriggerID("ResearchTrigger"));	
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);	
		rmAddTriggerEffect("Rate Research");
		rmSetTriggerEffectParamFloat("Rate", 10000);
//		rmAddTriggerEffect("Message");
//		rmSetTriggerEffectParam("Text", "Homecity research rates are instant for the first 30 sec.");			
		rmAddTriggerEffect("Send Chat");
		rmSetTriggerEffectParamInt("PlayerID", 0, false);
		rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>Homecity research rates are instant for the first 30 sec.", false);	
	}

	if (everyoneGetsAWagon == 990)
	{
    	rmCreateTrigger("unknownalliancesmessage");
    	rmSwitchToTrigger(rmTriggerID("unknownalliancesmessage"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 1, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>You may choose to ally with 1 of 3 Minor Civilizations once you have constructed your Embassy. Choose wisely.", false);

		int natAllianceCount = 3;

		int pirateAlliance = -1;
		int saltpeterAlliance = -1;
		int aztecsAlliance = -1;
		int lakotaAlliance = -1;
		int iroquoisAlliance = -1;
		int caribsAlliance = -1;
		int cherokeeAlliance = -1;
		int comancheAlliance = -1;
		int creeAlliance = -1;
		int nootkaAlliance = -1;
		int quechuaAlliance = -1;
		int seminolesAlliance = -1;
		int tupiAlliance = -1;
		int apacheAlliance = -1;
		int huronAlliance = -1;
		int klamathAlliance = -1;
		int mapucheAlliance = -1;
		int navajoAlliance = -1;
		int bhaktiAlliance = -1;
		int jesuitAlliance = -1;
		int shaolinAlliance = -1;
		int sufiAlliance = -1;
		int udasiAlliance = -1;
		int zenAlliance = -1;
		int lenapeAlliance = -1;
		int tengriAlliance = -1;
		int akanAlliance = -1;
		int berbersAlliance = -1;
		int somalisAlliance = -1;
		int sudaneseAlliance = -1;
		int yorubaAlliance = -1;
		int bourbonAlliance = -1;
		int habsburgAlliance = -1;
		int hanoverAlliance = -1;
		int jagiellonAlliance = -1;
		int oldenburgAlliance = -1;
		int vasaAlliance = -1;
		int wettinAlliance = -1;
		int wittelsbachAlliance = -1;
		int malteseAlliance = -1;
		int wokouAlliance = -1;
		int venetianAlliance = -1;
		int scientistAlliance = -1;
		int orthodoxAlliance = -1;
		int jewishAlliance = -1;
		int westernAlliance = -1;
		int korowaiAlliance = -1;
		int maoriAlliance = -1;
		int australianAlliance = -1;
		int inuitAlliance = -1;
		int penalAlliance = -1;
		int hussiteAlliance = -1;
		int auditoreAlliance = -1;
		int hansaAlliance = -1;
		int sansculottesAlliance = -1;
		int teutonicAlliance = -1;
		int cossacksAlliance = -1;
		int corsairsAlliance = -1;

		for(n = 0; < natAllianceCount)		// 58 alliance options
		{
			if (rmRandFloat(0,1) <= 0.0172 && corsairsAlliance != 1 && hansaAlliance != 1)
			{
				corsairsAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0175 && cossacksAlliance != 1 && hansaAlliance != 1)
			{
				cossacksAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0179 && teutonicAlliance != 1 && hansaAlliance != 1)
			{
				teutonicAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0181 && sansculottesAlliance != 1)
			{
				sansculottesAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0185 && hansaAlliance != 1 && teutonicAlliance != 1 && ahoyMeMatey != 1)
			{
				hansaAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0189 && auditoreAlliance != 1 && counterEzio < 0)
			{
				auditoreAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0192 && hussiteAlliance != 1 && counterHussite < 0)
			{
				hussiteAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0196 && penalAlliance != 1 && counterPen < 0)
			{
				penalAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0200 && inuitAlliance != 1 && counterInu < 0)
			{
				inuitAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0204 && australianAlliance != 1 && counterAbo < 0)
			{
				australianAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0208 && maoriAlliance != 1 && counterMao < 0)
			{
				maoriAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0213 && korowaiAlliance != 1 && counterKor < 0)
			{
				korowaiAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0217 && westernAlliance != 1 && counterWes < 0)
			{
				westernAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0222 && jewishAlliance != 1 && counterJew < 0)
			{
				jewishAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0227 && orthodoxAlliance != 1 && counterOrt < 0)
			{
				orthodoxAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0233 && scientistAlliance != 1 && ahoyMeMatey != 1)
			{
				scientistAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0238 && venetianAlliance != 1 && ahoyMeMatey != 1)
			{
				venetianAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0244 && wokouAlliance != 1 && ahoyMeMatey != 1)
			{
				wokouAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0250 && malteseAlliance != 1 && counterMal < 0)
			{
				malteseAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0256 && pirateAlliance != 1 && ahoyMeMatey != 1)
			{
				pirateAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0270 && saltpeterAlliance != 1)
			{
				saltpeterAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0278 && aztecsAlliance != 1 && counterAzte < 0)
			{
				aztecsAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0286 && lakotaAlliance != 1 && counterLako < 0)
			{
				lakotaAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0294 && iroquoisAlliance != 1 && counterIroq < 0)
			{
				iroquoisAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0303 && caribsAlliance != 1 && counterCari < 0)
			{
				caribsAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0313 && cherokeeAlliance != 1 && counterCher < 0)
			{
				cherokeeAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0323 && comancheAlliance != 1 && counterComa < 0)
			{
				comancheAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0333 && creeAlliance != 1 && counterCree < 0)
			{
				creeAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0345 && nootkaAlliance != 1 && counterNoot < 0)
			{
				nootkaAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0357 && quechuaAlliance != 1 && counterInca < 0)
			{
				quechuaAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0370 && seminolesAlliance != 1 && counterSemi < 0)
			{
				seminolesAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0385 && tupiAlliance != 1 && counterTupi < 0)
			{
				tupiAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0400 && apacheAlliance != 1 && counterApac < 0)
			{
				apacheAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0417 && huronAlliance != 1 && counterHuro < 0)
			{
				huronAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0435 && klamathAlliance != 1 && counterKlam < 0)
			{
				klamathAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0455 && mapucheAlliance != 1 && counterMapu < 0)
			{
				mapucheAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0476 && navajoAlliance != 1 && counterNava < 0)
			{
				navajoAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0500 && bhaktiAlliance != 1 && counterBhak < 0)
			{
				bhaktiAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0526 && jesuitAlliance != 1 && counterJesu < 0)
			{
				jesuitAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0556 && shaolinAlliance != 1 && counterShao < 0)
			{
				shaolinAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0588 && sufiAlliance != 1 && counterSufi < 0)
			{
				sufiAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0625 && udasiAlliance != 1 && counterUdas < 0)
			{
				udasiAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0667 && zenAlliance != 1 && counterZen < 0)
			{
				zenAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0714 && lenapeAlliance != 1 && counterLena < 0)
			{
				lenapeAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0769 && tengriAlliance != 1 && counterTeng < 0)
			{
				tengriAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0833 && berbersAlliance != 1 && counterBerb < 0)
			{
				berbersAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0909 && akanAlliance != 1 && counterAkan < 0)
			{
				akanAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0100 && somalisAlliance != 1 && counterSoma < 0)
			{
				somalisAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.1111 && sudaneseAlliance != 1 && counterSuda < 0)
			{
				sudaneseAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.1250 && yorubaAlliance != 1 && counterYoru < 0)
			{
				yorubaAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.1429 && bourbonAlliance != 1 && counterBour < 0)
			{
				bourbonAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.1667 && habsburgAlliance != 1 && counterHabs < 0 && electorSpawn < 1)
			{
				habsburgAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.2000 && hanoverAlliance != 1 && counterHano < 0 && electorSpawn < 1)
			{
				hanoverAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.2500 && jagiellonAlliance != 1 && counterJagi < 0)
			{
				jagiellonAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.3333 && oldenburgAlliance != 1 && counterOlde < 0 && electorSpawn < 1)
			{
				oldenburgAlliance = 1;
			}
			else if (rmRandFloat(0,1) <= 0.5000 && vasaAlliance != 1 && counterVasa < 0)
			{
				vasaAlliance = 1;
			}
//			else if (rmRandFloat(0,1) <= 0.5000 && wettinAlliance != 1 && counterWett < 0 && electorSpawn < 1)
//			{
//				wettinAlliance = 1;
//			}
			else if (wittelsbachAlliance != 1 && counterWitt < 0 && electorSpawn < 1)
			{
				wittelsbachAlliance = 1;
			}
			else
			{
				natAllianceCount++;	// ensures 3 are always chosen
			}
		}
	}

	// alliance testing				// for testing
//		pirateAlliance = 1;		
//		saltpeterAlliance = 1;	
//		aztecsAlliance = 1;		
//		lakotaAlliance = 1;		
//		iroquoisAlliance = 1;	
//		caribsAlliance = 1;		
//		cherokeeAlliance = 1;	
//		comancheAlliance = 1;	
//		creeAlliance = 1;		
//		nootkaAlliance = 1;		
//		quechuaAlliance = 1;	
//		seminolesAlliance = 1;	
//		tupiAlliance = 1;		
//		apacheAlliance = 1;		
//		huronAlliance = 1;		
//		klamathAlliance = 1;	
//		mapucheAlliance = 1;	
//		navajoAlliance = 1;		
//		bhaktiAlliance = 1;		
//		jesuitAlliance = 1;		
//		shaolinAlliance = 1;	
//		sufiAlliance = 1;		
//		udasiAlliance = 1;		
//		zenAlliance = 1;		
//		lenapeAlliance = 1;		
//		tengriAlliance = 1;		
//		berbersAlliance = 1;	
//		akanAlliance = 1;		
//		somalisAlliance = 1;	
//		sudaneseAlliance = 1;	
//		yorubaAlliance = 1;		
//		bourbonAlliance = 1;	
//		habsburgAlliance = 1;	
//		hanoverAlliance = 1;	
//		jagiellonAlliance = 1;	
//		oldenburgAlliance = 1;	
//		vasaAlliance = 1;		
//		wittelsbachAlliance = 1;
//		malteseAlliance = 1;
//		wokouAlliance = 1;
//		venetianAlliance = 1;
//		scientistAlliance = 1;
//		orthodoxAlliance = 1;
//		jewishAlliance = 1;
//		westernAlliance = 1;
//		korowaiAlliance = 1;
//		maoriAlliance = 1;
//		australianAlliance = 1;
//		inuitAlliance = 1;
//		penalAlliance = 1;
//		hussiteAlliance = 1;
//		auditoreAlliance = 1;
//		hansaAlliance = 1;
//		sansculottesAlliance = 1;
//		teutonicAlliance = 1;

	if (everyoneGetsAWagon == 981)
	{
		string mercUnit1 = "";
		string mercUnit2 = "";
		string mercUnit3 = "";

		// choose merc 1
		if (rmRandInt(1,14) <= 1)
		{
		    mercUnit1 = "MercBarbaryCorsair";
		}
		else if (rmRandInt(1,13) <= 1)
		{
			mercUnit1 = "deMercAskari";
		}
		else if (rmRandInt(1,12) <= 1)
		{
   		    mercUnit1 = "deMercKanuri";
		}
		else if (rmRandInt(1,11) <= 1)
		{
		    mercUnit1 = "MercManchu";
		}
		else if (rmRandInt(1,10) <= 1)
		{
   		    mercUnit1 = "deMercPistoleer";
		}
		else if (rmRandInt(1,9) <= 1)
		{
		    mercUnit1 = "MercRonin";
		}
		else if (rmRandInt(1,8) <= 1)
		{
			mercUnit1 = "deMercZenata";
		}
		else if (rmRandInt(1,7) <= 1)
		{
   		    mercUnit1 = "MercSwissPikeman";
		}
		else if (rmRandInt(1,6) <= 1)
		{
   		    mercUnit1 = "deMercGrenadier";
		}
		else if (rmRandInt(1,5) <= 1)
		{
   		    mercUnit1 = "deMercBrigadier";
		}
		else if (rmRandInt(1,4) <= 1)
		{
   		    mercUnit1 = "MercBlackRider";
		}
		else if (rmRandInt(1,3) <= 1)
		{
   		    mercUnit1 = "MercFusilier";
		}
		else if (rmRandInt(1,2) <= 1)
		{
   		    mercUnit1 = "MercHighlander";
		}
		else
		{
   		    mercUnit1 = "MercLandsknecht";
		}

		// choose merc 2
		if (rmRandInt(1,11) <= 1)
		{
   		    mercUnit2 = "deMercMountedRifleman";
		}
		else if (rmRandInt(1,10) <= 1)
		{
   		    mercUnit2 = "deMercBosniak";
		}
		else if (rmRandInt(1,9) <= 1)
		{
		    mercUnit2 = "ypMercJatLancer";
		}
		else if (rmRandInt(1,8) <= 1)
		{
   		    mercUnit2 = "deMercHarquebusier";
		}
		else if (rmRandInt(1,7) <= 1)
		{
   		    mercUnit2 = "MercHackapell";
		}
		else if (rmRandInt(1,6) <= 1)
		{
   		    mercUnit2 = "deMercRoyalHorseman";
		}
		else if (rmRandInt(1,5) <= 1)
		{
   		    mercUnit2 = "MercElmeti";
		}
		else if (rmRandInt(1,4) <= 1)
		{
   		    mercUnit2 = "MercStradiot";
		}
		else if (rmRandInt(1,3) <= 1)
		{
		    mercUnit2 = "MercMameluke";
		}
		else if (rmRandInt(1,2) <= 1)
		{
			mercUnit2 = "deMercSudaneseRider";
		}
		else
		{
		    mercUnit2 = "ypMercYojimbo";
		}

		// choose merc 3
		if (rmRandInt(1,8) <= 1)
		{
   		    mercUnit3 = "MercGreatCannon";
		}
		else if (rmRandInt(1,7) <= 1)
		{
		    mercUnit3 = "MercNinja";
		}
		else if (rmRandInt(1,6) <= 1)
		{
   		    mercUnit3 = "MercJaeger";
		}
		else if (rmRandInt(1,5) <= 1)
		{
		    mercUnit3 = "ypMercIronTroop";
		}
		else if (rmRandInt(1,4) <= 1)
		{
   		    mercUnit3 = "deMercPandour";
		}
		else if (rmRandInt(1,3) <= 1)
		{
			mercUnit3 = "deMercCannoneer";
		}
		else if (rmRandInt(1,2) <= 1)
		{
			mercUnit3 = "deMercAmazon";
		}
		else
		{
			mercUnit3 = "deMercGatlingCamel";
		}
	}

	if (campaignHero == 1)
	{
		int whichCampaign = -1;		// randomly selects campaign hero
		if (rmRandFloat(0,1) <= 0.125)
		{
			whichCampaign = 1;
		}
		else if (rmRandFloat(0,1) <= 0.143)
		{
			whichCampaign = 2;
		}
		else if (rmRandFloat(0,1) <= 0.167)
		{
			whichCampaign = 3;
		}
		else if (rmRandFloat(0,1) <= 0.20)
		{
			whichCampaign = 4;
		}
		else if (rmRandFloat(0,1) <= 0.25)
		{
			whichCampaign = 5;
		}
		else if (rmRandFloat(0,1) <= 0.333)
		{
			whichCampaign = 6;
		}
		else if (rmRandFloat(0,1) <= 0.50)
		{
			whichCampaign = 7;
		}
		else
		{
			whichCampaign = 8;
		}
	}

	if (everyoneGetsAWagon == 982)
	{
		// Enable Commandery Troops
		int whichCommandery1 = rmRandInt(1,8);	// randomly chooses commandery order units
			whichCommandery1 = 8;				// always SJWs because i'm greedy as Mitoe
		int whichCommandery2 = rmRandInt(1,8);	// randomly chooses commandery order units
		string commandUnit1 = "";
		string commandUnit2 = "";

		if (whichCommandery1 == 1)
		{
			commandUnit1 = "ypConsulateLifeGuard";
			whichCommandery2 = rmRandInt(2,8);
		}
		if (whichCommandery1 == 2)
		{
			commandUnit1 = "deConsulateLongbowman";
			if (rmRandFloat(0,1) <= 0.1429)
				whichCommandery2 = 1;
			else
				whichCommandery2 = rmRandInt(3,8);
		}
		if (whichCommandery1 == 3)
		{
			commandUnit1 = "ypConsulateJinete";
			if (rmRandFloat(0,1) <= 0.2858)
				whichCommandery2 = rmRandInt(1,2);
			else
				whichCommandery2 = rmRandInt(4,8);
		}
		if (whichCommandery1 == 4)
		{
			commandUnit1 = "deConsulateCacadore";
			if (rmRandFloat(0,1) <= 0.4287)
				whichCommandery2 = rmRandInt(1,3);
			else
				whichCommandery2 = rmRandInt(5,8);
		}
		if (whichCommandery1 == 5)
		{
			commandUnit1 = "ypConsulateGarrochista";
			if (rmRandFloat(0,1) <= 0.5716)
				whichCommandery2 = rmRandInt(1,4);
			else
				whichCommandery2 = rmRandInt(6,8);
		}
		if (whichCommandery1 == 6)
		{
			commandUnit1 = "ypConsulateGendarmes";
			if (rmRandFloat(0,1) <= 0.7145)
				whichCommandery2 = rmRandInt(1,5);
			else
				whichCommandery2 = rmRandInt(7,8);
		}
		if (whichCommandery1 == 7)
		{
			commandUnit1 = "deConsulateOprichnik";
			if (rmRandFloat(0,1) <= 0.1429)
				whichCommandery2 = 8;
			else
				whichCommandery2 = rmRandInt(1,6);
		}
		if (whichCommandery1 == 8)
		{
			commandUnit1 = "SettlerWagon";
			whichCommandery2 = rmRandInt(1,7);
		}
		if (whichCommandery2 == 1)
		{
			commandUnit2 = "ypConsulateLifeGuard";
		}
		if (whichCommandery2 == 2)
		{
			commandUnit2 = "deConsulateLongbowman";
		}
		if (whichCommandery2 == 3)
		{
			commandUnit2 = "ypConsulateJinete";
		}
		if (whichCommandery2 == 4)
		{
			commandUnit2 = "deConsulateCacadore";
		}
		if (whichCommandery2 == 5)
		{
			commandUnit2 = "ypConsulateGarrochista";
		}
		if (whichCommandery2 == 6)
		{
			commandUnit2 = "ypConsulateGendarmes";
		}
		if (whichCommandery2 == 7)
		{
			commandUnit2 = "deConsulateOprichnik";
		}
		if (whichCommandery2 == 8)
		{
			commandUnit2 = "SettlerWagon";
		}
	}

	if (commandPost == 1)
	{
    	rmCreateTrigger("funkywarning");
    	rmSwitchToTrigger(rmTriggerID("funkywarning"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 1, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>There has been an Ev0lution. Things are about to get funky. xD", false);

		int howFunky = -1;	// RNG for funky command post techs
		if (rmRandFloat(0,1) <= 0.25)
		{
			howFunky = 1;
		}
		else if (rmRandFloat(0,1) <= 0.333)
		{
			howFunky = 2;
		}
		else if (rmRandFloat(0,1) <= 0.50)
		{
			howFunky = 3;
		}
		else if (rmRandFloat(0,1) <= 0.75)
		{
			howFunky = 4;
		}
		else if (rmRandFloat(0,1) <= 0.75)
		{
			howFunky = 5;
		}
		else
		{
			howFunky = 6;
		}

		int hmTechCount = 3;

		int opportunityContracts = -1;
		int rapidDeployment = -1;
		int cavalryWings = -1;
		int crownArmy = -1;
		int sejm = -1;
		int hetman = -1;
		int zlotyTax = -1;
		int winterQuarters = -1;
		int finnishRegiment = -1;
		int railroadNetwork = -1;
		int telegraph = -1;
		int footAndCannonDrills = -1;
		int minieRifles = -1;
		int renegadeJanissary = -1;
		int bankOfAntwerp = -1;
		int zeelandRegiment = -1;
		int abjuration = -1;
		int mauriceOfNaussau = -1;
		int princeOfOrange = -1;
		int viennaWingedHussar = -1;
		int overwhelmingForce = -1;
		int papalLegate = -1;
		int excommunication = -1;
		int mediciPatronage = -1;
		int bankLoan = -1;
		int mercBounties = -1;

		for(n = 0; < hmTechCount)
		{
			if (rmRandFloat(0,1) <= 0.038 && opportunityContracts != 1 && mercBounties != 1 && renegadeJanissary != 1 && finnishRegiment != 1 && viennaWingedHussar != 1)
			{
				opportunityContracts = 1;
			}
			else if (rmRandFloat(0,1) <= 0.04 && rapidDeployment != 1 && overwhelmingForce != 1)
			{
				rapidDeployment = 1;
			}
			else if (rmRandFloat(0,1) <= 0.042 && cavalryWings != 1)
			{
				cavalryWings = 1;
			}
			else if (rmRandFloat(0,1) <= 0.043 && crownArmy != 1)
			{
				crownArmy = 1;
			}
			else if (rmRandFloat(0,1) <= 0.045 && sejm != 1)
			{
				sejm = 1;
			}
			else if (rmRandFloat(0,1) <= 0.048 && hetman != 1)
			{
				hetman = 1;
			}
			else if (rmRandFloat(0,1) <= 0.05 && zlotyTax != 1)
			{
				zlotyTax = 1;
			}
			else if (rmRandFloat(0,1) <= 0.053 && winterQuarters != 1)
			{
				winterQuarters = 1;
			}
			else if (rmRandFloat(0,1) <= 0.055 && finnishRegiment != 1 && renegadeJanissary != 1 && viennaWingedHussar != 1 && opportunityContracts != 1)
			{
				finnishRegiment = 1;
			}
			else if (rmRandFloat(0,1) <= 0.059 && railroadNetwork != 1 && telegraph != 1)
			{
				railroadNetwork = 1;
			}
			else if (rmRandFloat(0,1) <= 0.0625 && telegraph != 1 && railroadNetwork != 1)
			{
				telegraph = 1;
			}
			else if (rmRandFloat(0,1) <= 0.067 && footAndCannonDrills != 1)
			{
				footAndCannonDrills = 1;
			}
			else if (rmRandFloat(0,1) <= 0.071 && minieRifles != 1)
			{
				minieRifles = 1;
			}
			else if (rmRandFloat(0,1) <= 0.077 && renegadeJanissary != 1 && finnishRegiment != 1 && viennaWingedHussar != 1 && opportunityContracts != 1)
			{
				renegadeJanissary = 1;
			}
			else if (rmRandFloat(0,1) <= 0.083 && bankOfAntwerp != 1)
			{
				bankOfAntwerp = 1;
			}
			else if (rmRandFloat(0,1) <= 0.091 && zeelandRegiment != 1)
			{
				zeelandRegiment = 1;
			}
			else if (rmRandFloat(0,1) <= 0.100 && abjuration != 1)
			{
				abjuration = 1;
			}
			else if (rmRandFloat(0,1) <= 0.111 && mauriceOfNaussau != 1)
			{
				mauriceOfNaussau = 1;
			}
			else if (rmRandFloat(0,1) <= 0.125 && princeOfOrange != 1)
			{
				princeOfOrange = 1;
			}
			else if (rmRandFloat(0,1) <= 0.143 && viennaWingedHussar != 1 && finnishRegiment != 1 && renegadeJanissary != 1 && opportunityContracts != 1)
			{
				viennaWingedHussar = 1;
			}
			else if (rmRandFloat(0,1) <= 0.167 && overwhelmingForce != 1 && rapidDeployment != 1)
			{
				overwhelmingForce = 1;
			}
			else if (rmRandFloat(0,1) <= 0.20 && papalLegate != 1)
			{
				papalLegate = 1;
			}
			else if (rmRandFloat(0,1) <= 0.25 && excommunication != 1)
			{
				excommunication = 1;
			}
			else if (rmRandFloat(0,1) <= 0.333 && mediciPatronage != 1)
			{
				mediciPatronage = 1;
			}
			else if (rmRandFloat(0,1) <= 0.500 && bankLoan != 1)
			{
				bankLoan = 1;
			}
			else if (mercBounties != 1 && opportunityContracts != 1)
			{
				mercBounties = 1;
			}
			else
			{
				hmTechCount++;	// ensures 3 are always chosen
			}
		}
	}

	if (everyoneGetsAWagon == 996)
	{
    	rmCreateTrigger("wignacourtmessage");
    	rmSwitchToTrigger(rmTriggerID("wignacourtmessage"));
    	rmSetTriggerPriority(4); 
    	rmSetTriggerActive(true);
    	rmSetTriggerRunImmediately(true);
    	rmSetTriggerLoop(false);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 1, false);
		rmAddTriggerEffect("Send Chat");
    	rmSetTriggerEffectParamInt("PlayerID", 0, false);
    	rmSetTriggerEffectParam("Message", "<font=largeingame 24><icon=(40)(resources\art\units\animals\capybara\capybara_portrait.png)><font=floatytext 20><color=0,1,1>Place your Outposts strategically to boost your economy! glhf", false);
	}

	// triggers main loop
	for(i = 1; < cNumberPlayers)
	{
		if (habsburgSpawn == 1)
		{
			rmCreateTrigger("spanishhabsburg"+i);
			rmSwitchToTrigger(rmTriggerID("spanishhabsburg"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpSpanishHabsburgs"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (habsburgSpawn == 2)
		{
			rmCreateTrigger("austrianhabsburg"+i);
			rmSwitchToTrigger(rmTriggerID("austrianhabsburg"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpAustrianHabsburgs"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (tamboShadowTech == 1)
		{
			rmCreateTrigger("tambosforall"+i);
			rmSwitchToTrigger(rmTriggerID("tambosforall"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEIncaTamboShadow"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (euFortifiedTPTech == 1)
		{
			rmCreateTrigger("fortifyeurope"+i);
			rmSwitchToTrigger(rmTriggerID("fortifyeurope"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DESPCFortifiedCityState"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (religiousDistrictTech == 1)
		{
			rmCreateTrigger("religiousdistrictactivate"+i);
			rmSwitchToTrigger(rmTriggerID("religiousdistrictactivate"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DENativeSPCReligiousDistrict"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (railroadTech == 1)
		{
			rmCreateTrigger("activaterailnetworktech"+i);
			rmSwitchToTrigger(rmTriggerID("activaterailnetworktech"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DESPCRailroadNetwork"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (advTPTech == 1)
		{
			rmCreateTrigger("advancedtpforall"+i);
			rmSwitchToTrigger(rmTriggerID("advancedtpforall"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			if (rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmAddTriggerEffect("Set Tech Status");
			    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCAdvancedTambos"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else
			{
				rmAddTriggerEffect("Set Tech Status");
			    rmSetTriggerEffectParamInt("TechID", rmGetTechID("HCAdvancedTradingPost"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (cequeTech == 1)
		{
			rmCreateTrigger("cequesystemactivate"+i);
			rmSwitchToTrigger(rmTriggerID("cequesystemactivate"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCCequeSystem"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (greenwichTech == 1)
		{
			rmCreateTrigger("GMT"+i);
			rmSwitchToTrigger(rmTriggerID("GMT"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCGreenwichTime"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (lighthouseTech == 1)
		{
			rmCreateTrigger("lighthousesforall"+i);
			rmSwitchToTrigger(rmTriggerID("lighthousesforall"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DENatSomaliLighthouses"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (kamayuksTech == 1)
		{
			rmCreateTrigger("kamayuksforall"+i);
			rmSwitchToTrigger(rmTriggerID("kamayuksforall"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCQuipuKamayuks"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (plymouthMap == 1)
		{
			rmCreateTrigger("enablepilgrims"+i);
			rmSwitchToTrigger(rmTriggerID("enablepilgrims"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownTrainablePilgrims"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (rmGetNomadStart() == true)
		{
			rmCreateTrigger("nomadgeneralbuildtc"+i);
			rmSwitchToTrigger(rmTriggerID("nomadgeneralbuildtc"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEMapAddTownCenterGeneral"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);

			rmCreateTrigger("nomadarchitectnoTC"+i);
			rmSwitchToTrigger(rmTriggerID("nomadarchitectnoTC"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DERemoveTownCenterArchitect"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (getRekt >= 0.98 && petardSpawn == 1)
		{
			rmCreateTrigger("generalbuildtc"+i);
			rmSwitchToTrigger(rmTriggerID("generalbuildtc"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
		    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEMapAddTownCenterGeneral"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);

			rmCreateTrigger("architectnoTC"+i);
			rmSwitchToTrigger(rmTriggerID("architectnoTC"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DERemoveTownCenterArchitect"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (everyoneGetsAWagon == 1003)
		{
			rmCreateTrigger("trekwagonactivate"+i);
			rmSwitchToTrigger(rmTriggerID("trekwagonactivate"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownTrekWagon"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (everyoneGetsAWagon == 971 || trollMap == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("plazawagon"+i);
				rmSwitchToTrigger(rmTriggerID("plazawagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownCommunityPlazaEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("Chinese") || rmGetPlayerCiv(i) == rmGetCivID("Japanese") || rmGetPlayerCiv(i) == rmGetCivID("Indians"))
			{
				rmCreateTrigger("monasterywagon"+i);
				rmSwitchToTrigger(rmTriggerID("monasterywagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownMonasteryEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("DEHausa"))
			{
				rmCreateTrigger("mosquewagon"+i);
				rmSwitchToTrigger(rmTriggerID("mosquewagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownHausaMosqueEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians"))
			{
				rmCreateTrigger("ethchurchwagon"+i);
				rmSwitchToTrigger(rmTriggerID("ethchurchwagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownEthiopiaChurchEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("DEMexicans"))
			{
				rmCreateTrigger("cathedralwagon"+i);
				rmSwitchToTrigger(rmTriggerID("cathedralwagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownCathedralEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("DEItalians"))
			{
				rmCreateTrigger("basilicawagon"+i);
				rmSwitchToTrigger(rmTriggerID("basilicawagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownBasilicaEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
			{
				rmCreateTrigger("ottomosquewagon"+i);
				rmSwitchToTrigger(rmTriggerID("ottomosquewagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownChurchEnablerOttomans"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("Spanish"))
			{
				rmCreateTrigger("spainchurchwagon"+i);
				rmSwitchToTrigger(rmTriggerID("spainchurchwagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownChurchEnablerSpain"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (rmGetPlayerCiv(i) == rmGetCivID("DEAmericans"))
			{
				rmCreateTrigger("usachurchwagon"+i);
				rmSwitchToTrigger(rmTriggerID("usachurchwagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownChurchEnablerUSA"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else
			{
				rmCreateTrigger("nillachurchwagon"+i);
				rmSwitchToTrigger(rmTriggerID("nillachurchwagon"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownChurchEnabler"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (everyoneGetsAWagon == 972 || trollMap == 1)
		{
			rmCreateTrigger("freemarketsforall"+i);
			rmSwitchToTrigger(rmTriggerID("freemarketsforall"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownFreeMarkets"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (everyoneGetsAWagon == 996)
		{
			rmCreateTrigger("wignacourtactivate"+i);
			rmSwitchToTrigger(rmTriggerID("wignacourtactivate"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownWignacourt"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);

			if (rmGetPlayerCiv(i) == rmGetCivID("DEMaltese"))
			{
				rmCreateTrigger("maltaproperwigna"+i);
				rmSwitchToTrigger(rmTriggerID("maltaproperwigna"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("DEHCWignacourtConstructions"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
		        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownWIgnacourtMaltaDoubleBonus"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (everyoneGetsAWagon == 995)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DESwedish"))
			{
				// plus one torp
				rmCreateTrigger("torpplus1BL"+i);
				rmSwitchToTrigger(rmTriggerID("torpplus1BL"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);

				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "deTorp");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// one
			}
			else
			{
				rmCreateTrigger("BBactivate"+i);
				rmSwitchToTrigger(rmTriggerID("BBactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerCondition("Tech Status Equals");
				rmSetTriggerConditionParamInt("PlayerID", i);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
				rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
		        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCBlueberries"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);

				rmCreateTrigger("blackberriesactivate"+i);
				rmSwitchToTrigger(rmTriggerID("blackberriesactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerCondition("Tech Status Equals");
				rmSetTriggerConditionParamInt("PlayerID", i);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
				rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
		        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCBlackberries"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);

				rmCreateTrigger("northernforestsactivate"+i);
				rmSwitchToTrigger(rmTriggerID("northernforestsactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerCondition("Tech Status Equals");
				rmSetTriggerConditionParamInt("PlayerID", i);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
				rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
		        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCNorthernForests"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (heroDog == 1)
		{
			// plus one hero dog
			rmCreateTrigger("heropupBL"+i);
			rmSwitchToTrigger(rmTriggerID("heropupBL"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
		
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ExplorerDog");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 10);		// build limit
			rmSetTriggerEffectParamInt("Delta", 01);		// none
		}

		if (heroSheep == 1)
		{
			// plus one hero sheep
			rmCreateTrigger("herosheepBL"+i);
			rmSwitchToTrigger(rmTriggerID("herosheepBL"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
		
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "DEExplorerSheep");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 10);		// build limit
			rmSetTriggerEffectParamInt("Delta", 01);		// none
		}

		if (surgeonScout == 1)
		{
			// surgeon builds field hospital
			rmCreateTrigger("fieldhospitalactivatesurgeon"+i);
			rmSwitchToTrigger(rmTriggerID("fieldhospitalactivatesurgeon"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", "FieldHospital");
		}

		if (campaignHero == 1)	// campaign heroes
		{
			if (whichCampaign == 1)
			{
				rmCreateTrigger("chenactivate"+i);
				rmSwitchToTrigger(rmTriggerID("chenactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownLaoChen"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 2)
			{
				rmCreateTrigger("stuartactivate"+i);
				rmSwitchToTrigger(rmTriggerID("stuartactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownStuart"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 3)
			{
				rmCreateTrigger("nanibactivate"+i);
				rmSwitchToTrigger(rmTriggerID("nanibactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownNanib"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 4)
			{
				rmCreateTrigger("kichiroactivate"+i);
				rmSwitchToTrigger(rmTriggerID("kichiroactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownKichiro"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 5)
			{
				rmCreateTrigger("morganactivate"+i);
				rmSwitchToTrigger(rmTriggerID("morganactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMorgan"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 6)
			{
				rmCreateTrigger("eaglemutactivate"+i);
				rmSwitchToTrigger(rmTriggerID("eaglemutactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownNonahkee"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (whichCampaign == 7)
			{
				rmCreateTrigger("alainactivate"+i);
				rmSwitchToTrigger(rmTriggerID("alainactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownAlain"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else
			{
				rmCreateTrigger("lizzieactivate"+i);
				rmSwitchToTrigger(rmTriggerID("lizzieactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
			    rmAddTriggerCondition("Tech Status Equals");
			    rmSetTriggerConditionParamInt("PlayerID", i);
		        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
			    rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownLizzie"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (commandPost == 1)	// funky techs
		{
			if (howFunky == 1)
			{
				rmCreateTrigger("handicapactivate"+i);
				rmSwitchToTrigger(rmTriggerID("handicapactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownHandicap"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (howFunky == 2)
			{
				rmCreateTrigger("overpopactivate"+i);
				rmSwitchToTrigger(rmTriggerID("overpopactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownOverpop"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (howFunky == 3)
			{
				rmCreateTrigger("fastageactivate"+i);
				rmSwitchToTrigger(rmTriggerID("fastageactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFastAge"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (howFunky == 4)
			{
				rmCreateTrigger("fasttechsactivate"+i);
				rmSwitchToTrigger(rmTriggerID("fasttechsactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFastResearch"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else if (howFunky == 5)
			{
				rmCreateTrigger("fieldhospitalsactivate"+i);
				rmSwitchToTrigger(rmTriggerID("fieldhospitalsactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFieldHospital"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			else
			{
				rmCreateTrigger("nowallsecoregenactivate"+i);
				rmSwitchToTrigger(rmTriggerID("nowallsecoregenactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownNoWallsEcoRegen"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (commandPost == 1)	// HM techs
		{
			if (opportunityContracts == 1)
			{
				rmCreateTrigger("opportunitycostsactivate"+i);
				rmSwitchToTrigger(rmTriggerID("opportunitycostsactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownOpportunityContracts"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (rapidDeployment == 1)
			{
				rmCreateTrigger("rapiddeploymentactivate"+i);
				rmSwitchToTrigger(rmTriggerID("rapiddeploymentactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownRapidDeployment"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (cavalryWings == 1)
			{
				rmCreateTrigger("cavwingsactivate"+i);
				rmSwitchToTrigger(rmTriggerID("cavwingsactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownCavalryWings"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (crownArmy == 1)
			{
				rmCreateTrigger("crownarmyactivate"+i);
				rmSwitchToTrigger(rmTriggerID("crownarmyactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownCrownArmy"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (sejm == 1)
			{
				rmCreateTrigger("sejmactivate"+i);
				rmSwitchToTrigger(rmTriggerID("sejmactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownSejm"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (hetman == 1)
			{
				rmCreateTrigger("hetmanactivate"+i);
				rmSwitchToTrigger(rmTriggerID("hetmanactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownHetman"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (zlotyTax == 1)
			{
				rmCreateTrigger("zlotyactivate"+i);
				rmSwitchToTrigger(rmTriggerID("zlotyactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownZlotyTax"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (winterQuarters == 1)
			{
				rmCreateTrigger("winterquartersactivate"+i);
				rmSwitchToTrigger(rmTriggerID("winterquartersactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownWinterQuarters"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (finnishRegiment == 1)
			{
				rmCreateTrigger("finnishregimentactivate"+i);
				rmSwitchToTrigger(rmTriggerID("finnishregimentactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFinnishRegiment"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (railroadNetwork == 1)
			{
				rmCreateTrigger("railroadnetworkactivate"+i);
				rmSwitchToTrigger(rmTriggerID("railroadnetworkactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownRailroadNetwork"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (telegraph == 1)
			{
				rmCreateTrigger("telegraphactivate"+i);
				rmSwitchToTrigger(rmTriggerID("telegraphactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownTelegraphEnable"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (footAndCannonDrills == 1)
			{
				rmCreateTrigger("footandcannonactivate"+i);
				rmSwitchToTrigger(rmTriggerID("footandcannonactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFootAndCannonDrills"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (minieRifles == 1)
			{
				rmCreateTrigger("minieriflesactivate"+i);
				rmSwitchToTrigger(rmTriggerID("minieriflesactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMinieRiflesEnable"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (renegadeJanissary == 1)
			{
				rmCreateTrigger("renegadejansactivate"+i);
				rmSwitchToTrigger(rmTriggerID("renegadejansactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownRenegadeJanissaryCorps"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (bankOfAntwerp == 1)
			{
				rmCreateTrigger("antwerpactivate"+i);
				rmSwitchToTrigger(rmTriggerID("antwerpactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownBankOfAntwerp"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (zeelandRegiment == 1)
			{
				rmCreateTrigger("zeelandactivate"+i);
				rmSwitchToTrigger(rmTriggerID("zeelandactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownhireZeelandRegiment"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);

				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("VeteranRuytersShadow"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (abjuration == 1)
			{
				rmCreateTrigger("abjurationactivate"+i);
				rmSwitchToTrigger(rmTriggerID("abjurationactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownAbjuration"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (mauriceOfNaussau == 1)
			{
				rmCreateTrigger("mauriceactivate"+i);
				rmSwitchToTrigger(rmTriggerID("mauriceactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMauriceOfNaussau"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (princeOfOrange == 1)
			{
				rmCreateTrigger("princeoforangeactivate"+i);
				rmSwitchToTrigger(rmTriggerID("princeoforangeactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownPrinceOfOrange"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (viennaWingedHussar == 1)
			{
				rmCreateTrigger("viennahussactivate"+i);
				rmSwitchToTrigger(rmTriggerID("viennahussactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownViennaWingedHussar"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (overwhelmingForce == 1)
			{
				rmCreateTrigger("overwhelmingactivate"+i);
				rmSwitchToTrigger(rmTriggerID("overwhelmingactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownOverwhelmingForce"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (papalLegate == 1)
			{
				rmCreateTrigger("papallegateactivate"+i);
				rmSwitchToTrigger(rmTriggerID("papallegateactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownPapalLegate"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (excommunication == 1)
			{
				rmCreateTrigger("excommunicationactivate"+i);
				rmSwitchToTrigger(rmTriggerID("excommunicationactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownExcommunication"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (mediciPatronage == 1)
			{
				rmCreateTrigger("mediciactivate"+i);
				rmSwitchToTrigger(rmTriggerID("mediciactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMediciPatronage"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (bankLoan == 1)
			{
				rmCreateTrigger("bankloanactivate"+i);
				rmSwitchToTrigger(rmTriggerID("bankloanactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownBankLoan"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}

			if (mercBounties == 1)
			{
				rmCreateTrigger("mercbountiesactivate"+i);
				rmSwitchToTrigger(rmTriggerID("mercbountiesactivate"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
		    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMercenaryBounties"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (africanDesertMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcafricandesertoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcafricandesertoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsAfricanDesertFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (africanMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcafricanoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcafricanoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsAfricanFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (americanMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcamericanoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcamericanoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsAmericanFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (southAmMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcsouthamericanoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcsouthamericanoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsSouthAmericanFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (mexicanMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcmexicanoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcmexicanoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsMexicanFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (asianMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twcasianoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twcasianoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsAsianFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}		

		if (europeanMerc == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
			{
				rmCreateTrigger("twceuropeanoutlaws"+i);
				rmSwitchToTrigger(rmTriggerID("twceuropeanoutlaws"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableOutlawsEuropeanFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
		}

		if (bombActivator == 1)
		{
			// add bomb - thanks Enki
			rmCreateTrigger("AddBomb"+i);
			rmSwitchToTrigger(rmTriggerID("AddBomb"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//			rmSetTriggerEffectParamInt("TechID", 2407);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPSPCCC4TreeBomb"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (trollMap == 1)
		{
			// forbid walls
			rmCreateTrigger("wallbuildlimit"+i);
			rmSwitchToTrigger(rmTriggerID("wallbuildlimit"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
		
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "WallStraight5");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 10);		// build limit
			rmSetTriggerEffectParamInt("Delta", 01);		// none
		}

		if (everyoneGetsAWagon == 983)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("Indians") == false)
			{
				rmCreateTrigger("sacredfieldfix"+i);
				rmSwitchToTrigger(rmTriggerID("sacredfieldfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
        		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownSacredFieldWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}
			else
			{
				rmCreateTrigger("extrasacredfield"+i);
				rmSwitchToTrigger(rmTriggerID("extrasacredfield"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "ypSacredField");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}
		}

		if (everyoneGetsAWagon == 988)
		{
			rmCreateTrigger("batterytowertechs"+i);
			rmSwitchToTrigger(rmTriggerID("batterytowertechs"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownBatteryTowerTechs"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 984 || trollMap == 1)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEMaltese") == false)
			{
				rmCreateTrigger("depotwagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("depotwagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
	        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownDepotWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}

			rmCreateTrigger("depotwagontraining"+i);
			rmSwitchToTrigger(rmTriggerID("depotwagontraining"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownDepotWagonTraining"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("euTreasureTechArtilleryWagonSpeed"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			// Enable Hoops
			rmCreateTrigger("hoopactivate"+i);
			rmSwitchToTrigger(rmTriggerID("hoopactivate"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", "SPCHoopThrowers");

			rmCreateTrigger("hoopbuff"+i);
			rmSwitchToTrigger(rmTriggerID("hoopbuff"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownHoopThrowersMultipliers"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 982)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEMaltese") == false)
			{
				rmCreateTrigger("commanderywagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("commanderywagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
        		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownCommanderyWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}

			// Enable Commandery Troops
			rmCreateTrigger("commanderytroopsactivate1"+i);
			rmSwitchToTrigger(rmTriggerID("commanderytroopsactivate1"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", commandUnit1);

			rmCreateTrigger("commanderytroopsactivate2"+i);
			rmSwitchToTrigger(rmTriggerID("commanderytroopsactivate2"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", commandUnit2);
		}

		if (everyoneGetsAWagon == 987)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEItalians") == false)
			{
				rmCreateTrigger("activatelombards"+i);
				rmSwitchToTrigger(rmTriggerID("activatelombards"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
        		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownLombardWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
//			else
//			{
//				rmCreateTrigger("extralombard"+i);
//				rmSwitchToTrigger(rmTriggerID("extralombard"+i));
//				rmSetTriggerActive(true);
//				rmSetTriggerRunImmediately(true);
//				rmSetTriggerPriority(4);
//				rmAddTriggerCondition("Always");
//				rmAddTriggerEffect("Modify Protounit");
//				rmSetTriggerEffectParam("Protounit", "deLombard");
//				rmSetTriggerEffectParamInt("PlayerID", i);
//				rmSetTriggerEffectParamInt("Field", 10);		// build limit
//				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
//			}

			rmCreateTrigger("depositcoin"+i);
			rmSwitchToTrigger(rmTriggerID("depositcoin"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
       		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DELombardyWagonDeposit"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

	if (everyoneGetsAWagon == 69 || trollMap == 1)	// jeff wagons
	{
		rmCreateTrigger("jeffwagonfood"+i);
		rmSwitchToTrigger(rmTriggerID("jeffwagonfood"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
	    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownJeffWagonColonial"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("jeffwagonwood"+i);
		rmSwitchToTrigger(rmTriggerID("jeffwagonwood"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
	    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownJeffWagonFortress"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("jeffwagoncoin"+i);
		rmSwitchToTrigger(rmTriggerID("jeffwagoncoin"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
	    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownJeffWagonIndustrial"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("jeffwagonall"+i);
		rmSwitchToTrigger(rmTriggerID("jeffwagonall"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
	    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownJeffWagonImperial"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);
	}

	if (everyoneGetsAWagon == 111)	// factory
	{
		rmCreateTrigger("factorystart"+i);
		rmSwitchToTrigger(rmTriggerID("factorystart"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownFactoryWagonFix"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

			if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca") || rmGetPlayerCiv(i) == 	rmGetCivID("Japanese") || rmGetPlayerCiv(i) == rmGetCivID("Indians") || rmGetPlayerCiv(i) == rmGetCivID("DEHausa") || rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians"))
		{
			rmCreateTrigger("noneurofactorytechs"+i);
			rmSwitchToTrigger(rmTriggerID("noneurofactorytechs"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownFactoryTechFix"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}
	}

	if (everyoneGetsAWagon == 973)
	{
		rmCreateTrigger("morocco"+i);
		rmSwitchToTrigger(rmTriggerID("morocco"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownMoroccanAlliance"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("activateuniquetowers"+i);
		rmSwitchToTrigger(rmTriggerID("activateuniquetowers"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
       	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownUniqueTowerWagonFix"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);
	}

	if (everyoneGetsAWagon == 990)
	{
		rmCreateTrigger("embassyenabler"+i);
		rmSwitchToTrigger(rmTriggerID("embassyenabler"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypNativeEmbassyEnabler"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("embassyenablershadow"+i);
		rmSwitchToTrigger(rmTriggerID("embassyenablershadow"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypNativeEmbassyEnableShadow"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		if (saltpeterAlliance == 1)
		{
			rmCreateTrigger("saltpeteralliance"+i);
			rmSwitchToTrigger(rmTriggerID("saltpeteralliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceSaltpeterEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (pirateAlliance == 1)
		{
			rmCreateTrigger("piratealliance"+i);
			rmSwitchToTrigger(rmTriggerID("piratealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAlliancePiratesEnabler"), false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAlliancePiratesEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (aztecsAlliance == 1)
		{
			rmCreateTrigger("aztecalliance"+i);
			rmSwitchToTrigger(rmTriggerID("aztecalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceAztecsEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (lakotaAlliance == 1)
		{
			rmCreateTrigger("lakotaalliance"+i);
			rmSwitchToTrigger(rmTriggerID("lakotaalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceLakotaEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (iroquoisAlliance == 1)
		{
			rmCreateTrigger("iroquoisalliance"+i);
			rmSwitchToTrigger(rmTriggerID("iroquoisalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceIroquoisEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (caribsAlliance == 1)
		{
			rmCreateTrigger("cariballiance"+i);
			rmSwitchToTrigger(rmTriggerID("cariballiance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceCaribsEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (cherokeeAlliance == 1)
		{
			rmCreateTrigger("cherokeealliance"+i);
			rmSwitchToTrigger(rmTriggerID("cherokeealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceCherokeeEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (comancheAlliance == 1)
		{
			rmCreateTrigger("comanchealliance"+i);
			rmSwitchToTrigger(rmTriggerID("comanchealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceComancheEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (creeAlliance == 1)
		{
			rmCreateTrigger("creealliance"+i);
			rmSwitchToTrigger(rmTriggerID("creealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceCreeEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (nootkaAlliance == 1)
		{
			rmCreateTrigger("nootkaalliance"+i);
			rmSwitchToTrigger(rmTriggerID("nootkaalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceNootkaEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (quechuaAlliance == 1)
		{
			rmCreateTrigger("quechuaalliance"+i);
			rmSwitchToTrigger(rmTriggerID("quechuaalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceQuechuasEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (seminolesAlliance == 1)
		{
			rmCreateTrigger("seminolealliance"+i);
			rmSwitchToTrigger(rmTriggerID("seminolealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceSeminolesEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (tupiAlliance == 1)
		{
			rmCreateTrigger("tupialliance"+i);
			rmSwitchToTrigger(rmTriggerID("tupialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceTupiEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (apacheAlliance == 1)
		{
			rmCreateTrigger("apachealliance"+i);
			rmSwitchToTrigger(rmTriggerID("apachealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceApacheEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (huronAlliance == 1)
		{
			rmCreateTrigger("huronalliance"+i);
			rmSwitchToTrigger(rmTriggerID("huronalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceHuronEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (klamathAlliance == 1)
		{
			rmCreateTrigger("klamathalliance"+i);
			rmSwitchToTrigger(rmTriggerID("klamathalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceKlamathEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (mapucheAlliance == 1)
		{
			rmCreateTrigger("mapuchealliance"+i);
			rmSwitchToTrigger(rmTriggerID("mapuchealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceMapucheEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (navajoAlliance == 1)
		{
			rmCreateTrigger("navajoalliance"+i);
			rmSwitchToTrigger(rmTriggerID("navajoalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceNavajoEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (bhaktiAlliance == 1)
		{
			rmCreateTrigger("bhaktialliance"+i);
			rmSwitchToTrigger(rmTriggerID("bhaktialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceBhaktiEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (jesuitAlliance == 1)
		{
			rmCreateTrigger("jesuitalliance"+i);
			rmSwitchToTrigger(rmTriggerID("jesuitalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceJesuitEnabler"), false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceJesuitEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (shaolinAlliance == 1)
		{
			rmCreateTrigger("shaolinalliance"+i);
			rmSwitchToTrigger(rmTriggerID("shaolinalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceShaolinEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (sufiAlliance == 1)
		{
			rmCreateTrigger("sufialliance"+i);
			rmSwitchToTrigger(rmTriggerID("sufialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceSufiEnabler"), false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceSufiEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (udasiAlliance == 1)
		{
			rmCreateTrigger("udasialliance"+i);
			rmSwitchToTrigger(rmTriggerID("udasialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceUdasiEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (zenAlliance == 1)
		{
			rmCreateTrigger("zenalliance"+i);
			rmSwitchToTrigger(rmTriggerID("zenalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceZenEnabler"), false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceZenEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (lenapeAlliance == 1)
		{
			rmCreateTrigger("lenapealliance"+i);
			rmSwitchToTrigger(rmTriggerID("lenapealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceLenapeEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (tengriAlliance == 1)
		{
			rmCreateTrigger("tengrialliance"+i);
			rmSwitchToTrigger(rmTriggerID("tengrialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceTengriEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (akanAlliance == 1)
		{
			rmCreateTrigger("akanalliance"+i);
			rmSwitchToTrigger(rmTriggerID("akanalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceAkanEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
					}

		if (berbersAlliance == 1)
		{
			rmCreateTrigger("berberalliance"+i);
			rmSwitchToTrigger(rmTriggerID("berberalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceBerbersEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (somalisAlliance == 1)
		{
			rmCreateTrigger("somalialliance"+i);
			rmSwitchToTrigger(rmTriggerID("somalialliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceSomalisEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (sudaneseAlliance == 1)
		{
			rmCreateTrigger("sudanesealliance"+i);
			rmSwitchToTrigger(rmTriggerID("sudanesealliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceSudaneseEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (yorubaAlliance == 1)
		{
			rmCreateTrigger("yorubaalliance"+i);
			rmSwitchToTrigger(rmTriggerID("yorubaalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceYorubaEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (bourbonAlliance == 1)
		{
			rmCreateTrigger("bourbonalliance"+i);
			rmSwitchToTrigger(rmTriggerID("bourbonalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceBourbonEnabler"), false);
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceBourbonEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (habsburgAlliance == 1)
		{
			rmCreateTrigger("habsburgalliance"+i);
			rmSwitchToTrigger(rmTriggerID("habsburgalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceHabsburgEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (hanoverAlliance == 1)
		{
			rmCreateTrigger("hanoveralliance"+i);
			rmSwitchToTrigger(rmTriggerID("hanoveralliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceHanoverEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (jagiellonAlliance == 1)
		{
			rmCreateTrigger("jagiellonalliance"+i);
			rmSwitchToTrigger(rmTriggerID("jagiellonalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceJagiellonEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (oldenburgAlliance == 1)
		{
			rmCreateTrigger("oldenburgalliance"+i);
			rmSwitchToTrigger(rmTriggerID("oldenburgalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceOldenburgEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (vasaAlliance == 1)
		{
			rmCreateTrigger("vasaalliance"+i);
			rmSwitchToTrigger(rmTriggerID("vasaalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceVasaEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (wettinAlliance == 1)
		{
			rmCreateTrigger("wettinalliance"+i);
			rmSwitchToTrigger(rmTriggerID("wettinalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceWettinEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (wittelsbachAlliance == 1)
		{
			rmCreateTrigger("wittelsbachalliance"+i);
			rmSwitchToTrigger(rmTriggerID("wittelsbachalliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownAllianceWittelsbachEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (malteseAlliance == 1)
		{
			rmCreateTrigger("malteseAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("malteseAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceMalteseEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (wokouAlliance == 1)
		{
			rmCreateTrigger("wokouAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("wokouAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceWokouEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (venetianAlliance == 1)
		{
			rmCreateTrigger("venetianAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("venetianAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceVenetiansEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (scientistAlliance == 1)
		{
			rmCreateTrigger("scientistAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("scientistAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceScientistsEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (orthodoxAlliance == 1)
		{
			rmCreateTrigger("orthodoxAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("orthodoxAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceOrthodoxEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (jewishAlliance == 1)
		{
			rmCreateTrigger("jewishAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("jewishAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceJewishEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (westernAlliance == 1)
		{
			rmCreateTrigger("westernAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("westernAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceWesternEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (korowaiAlliance == 1)
		{
			rmCreateTrigger("korowaiAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("korowaiAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceKorowaiEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (maoriAlliance == 1)
		{
			rmCreateTrigger("maoriAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("maoriAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceMaoriEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (australianAlliance == 1)
		{
			rmCreateTrigger("australianAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("australianAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceAustraliansEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (inuitAlliance == 1)
		{
			rmCreateTrigger("inuitAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("inuitAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceInuitsEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (penalAlliance == 1)
		{
			rmCreateTrigger("penalAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("penalAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAlliancePenalColonyEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (hussiteAlliance == 1)
		{
			rmCreateTrigger("hussiteAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("hussiteAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceHussitesEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (auditoreAlliance == 1)
		{
			rmCreateTrigger("auditoreAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("auditoreAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceHAuditoreEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (hansaAlliance == 1)
		{
			rmCreateTrigger("hansaAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("hansaAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceHansaEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (sansculottesAlliance == 1)
		{
			rmCreateTrigger("sansculottesAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("sansculottesAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceSansculottesEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (teutonicAlliance == 1)
		{
			rmCreateTrigger("teutonicAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("teutonicAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceTeutonicEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (cossacksAlliance == 1)
		{
			rmCreateTrigger("cossacksAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("cossacksAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceCossacksEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (corsairsAlliance == 1)
		{
			rmCreateTrigger("corsairsAlliance"+i);
			rmSwitchToTrigger(rmTriggerID("corsairsAlliance"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
	        rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpUnknownAllianceCorsairsEnabler"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}
	}

	if (everyoneGetsAWagon == 979 || trollMap == 1)
	{
		rmCreateTrigger("phanaralliance"+i);
		rmSwitchToTrigger(rmTriggerID("phanaralliance"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownPhanarAlliance"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);

		rmCreateTrigger("athosactivate"+i);
		rmSwitchToTrigger(rmTriggerID("athosactivate"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DENatPhanarMountAthos"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);				
	}

	if (everyoneGetsAWagon == 980 || trollMap == 1)
	{
		rmCreateTrigger("mayanalliance"+i);
		rmSwitchToTrigger(rmTriggerID("mayanalliance"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMayanAlliance"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		

		rmCreateTrigger("mayacastleactivate"+i);
		rmSwitchToTrigger(rmTriggerID("mayacastleactivate"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("NatMayaPyramids"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		

		rmCreateTrigger("cruzobimperialize"+i);
		rmSwitchToTrigger(rmTriggerID("cruzobimperialize"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEREVImperialCruzobInfantry"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		
	}		

	if (everyoneGetsAWagon == 985 || trollMap == 1)
	{
		rmCreateTrigger("fortressfixedgun"+i);
		rmSwitchToTrigger(rmTriggerID("fortressfixedgun"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("FortRessize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownFixedGunWagon"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		
	}		

	if (everyoneGetsAWagon == 981)
	{
		rmCreateTrigger("mercactivate1"+i);
		rmSwitchToTrigger(rmTriggerID("mercactivate1"+i));
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerPriority(4);
		rmAddTriggerCondition("Always");
		rmAddTriggerEffect("Unforbid and Enable Unit");
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParam("Protounit", mercUnit1);

		rmCreateTrigger("mercactivate2"+i);
		rmSwitchToTrigger(rmTriggerID("mercactivate2"+i));
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerPriority(4);
		rmAddTriggerCondition("Always");
		rmAddTriggerEffect("Unforbid and Enable Unit");
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParam("Protounit", mercUnit2);

		rmCreateTrigger("mercactivate3"+i);
		rmSwitchToTrigger(rmTriggerID("mercactivate3"+i));
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerPriority(4);
		rmAddTriggerCondition("Always");
		rmAddTriggerEffect("Unforbid and Enable Unit");
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParam("Protounit", mercUnit3);

		rmCreateTrigger("colotavernwagon"+i);
		rmSwitchToTrigger(rmTriggerID("colotavernwagon"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownTavernWagon"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		

		if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca") || rmGetPlayerCiv(i) == rmGetCivID("Chinese") || rmGetPlayerCiv(i) == rmGetCivID("Japanese") || rmGetPlayerCiv(i) == rmGetCivID("Indians") || rmGetPlayerCiv(i) == rmGetCivID("DEHausa") || rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) == rmGetCivID("DEItalians"))
		{
			rmCreateTrigger("activatetaverns"+i);
			rmSwitchToTrigger(rmTriggerID("activatetaverns"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownTavernWagonFix"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (rmGetPlayerCiv(i) == rmGetCivID("DEAmericans") || rmGetPlayerCiv(i) == rmGetCivID("DEMexicans"))
		{
			rmCreateTrigger("activatetaverns"+i);
			rmSwitchToTrigger(rmTriggerID("activatetaverns"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownSaloonFix"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}

		if (rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
		{
			rmCreateTrigger("twctavernfix"+i);
			rmSwitchToTrigger(rmTriggerID("twctavernfix"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
        	rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownEnableTavernTWCFix"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}
	}		

	if (everyoneGetsAWagon == 666 || trollMap == 1)
	{
		rmCreateTrigger("colomilitarywagon"+i);
		rmSwitchToTrigger(rmTriggerID("colomilitarywagon"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownMilitaryWagon"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		

		rmCreateTrigger("militaryspeedbuff"+i);
		rmSwitchToTrigger(rmTriggerID("militaryspeedbuff"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("euTreasureTechCavSpeed"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("euTreasureTechInfantrySpeed"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);		
	}		

	if (everyoneGetsAWagon == 8888 || trollMap == 1)
	{
		rmCreateTrigger("coloTC"+i);
		rmSwitchToTrigger(rmTriggerID("coloTC"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Colonialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("afTreasureTCBL"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);				

		rmCreateTrigger("fortTC"+i);
		rmSwitchToTrigger(rmTriggerID("fortTC"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownTCBL3"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);			
			
		rmCreateTrigger("indTC"+i);
		rmSwitchToTrigger(rmTriggerID("indTC"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownTCBL4"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);			

		rmCreateTrigger("impTC"+i);
		rmSwitchToTrigger(rmTriggerID("impTC"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);				
	    rmAddTriggerCondition("Tech Status Equals");
	    rmSetTriggerConditionParamInt("PlayerID", i);
        rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Set Tech Status");
        rmSetTriggerEffectParamInt("TechID", rmGetTechID("deUnknownTCBL5"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);			
	}

		if (asianMap == 1 && everyoneGetsAWagon != 980)
		{
			if (rmRandFloat(0,1) <= 0.01 || trollMap == 1)
			{
				// Enable shark at dock
				rmCreateTrigger("sharkactivate"+i);
				rmSwitchToTrigger(rmTriggerID("sharkactivate"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Unforbid and Enable Unit");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParam("Protounit", "ypGreatWhiteShark");
			}
		}

		if (euMap == 1 && boneRNG <= 0.05)
			{
				// Enable some boneguard units at rax
				rmCreateTrigger("boneguardactivate"+i);
				rmSwitchToTrigger(rmTriggerID("boneguardactivate"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Unforbid and Enable Unit");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParam("Protounit", boneType);
			}

		if (everyoneGetsAWagon == 888 || trollMap == 1)
		{
			// Increase TC BL by 1
    		rmCreateTrigger("extraTC"+i);
    		rmSwitchToTrigger(rmTriggerID("extraTC"+i));
    		rmSetTriggerActive(true);
    		rmSetTriggerRunImmediately(true);
    		rmSetTriggerPriority(4);
    		rmAddTriggerCondition("Always");
    		rmAddTriggerEffect("Modify Protounit");
    		rmSetTriggerEffectParam("Protounit", "TownCenter");
    		rmSetTriggerEffectParamInt("PlayerID", i);
    		rmSetTriggerEffectParamInt("Field", 10);		// build limit
    		rmSetTriggerEffectParamInt("Delta", 01);		// plus one
		}

		if (scoutRNG <= 0.05 || trollMap == 1)
		{
			// Enable Hot Air Balloon and Train it Instantly
			rmCreateTrigger("balloonactivation"+i);
			rmSwitchToTrigger(rmTriggerID("balloonactivation"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", "HotAirBalloon");

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "HotAirBalloon");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 10);		// build limit
			rmSetTriggerEffectParamInt("Delta", 02);		// one

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "HotAirBalloon");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -30);		// zero (30-30=0)
		}

		if (fountainChance == 1 && caribbeanMap == 1)
		{
			// Enable Fire Ships
			rmCreateTrigger("fireshipactivate"+i);
			rmSwitchToTrigger(rmTriggerID("fireshipactivate"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", "SPCFireship");
		}

		if (everyoneGetsAWagon == 991)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEMexicans") == false)
			{
				rmCreateTrigger("haciendawagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("haciendawagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 4699);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownHaciendaWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCBarbacoa"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
				if (chaosBar == 1)
				{
					rmAddTriggerEffect("Set Tech Status");
					rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEHCChipotles"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
			}

			if (rmGetPlayerCiv(i) == rmGetCivID("DEMexicans") || rmGetPlayerCiv(i) == rmGetCivID("Spanish"))
			{
				rmCreateTrigger("extrahacienda"+i);
				rmSwitchToTrigger(rmTriggerID("extrahacienda"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "deHacienda");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}	
		}

		if (everyoneGetsAWagon == 989 || trollMap == 1)
		{
			// Enable Miner
			rmCreateTrigger("mineractivate"+i);
			rmSwitchToTrigger(rmTriggerID("mineractivate"+i));
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerPriority(4);
			rmAddTriggerCondition("Always");
			rmAddTriggerEffect("Unforbid and Enable Unit");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParam("Protounit", "deMiner");
		}

		if (everyoneGetsAWagon == 994)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("Dutch") == false)
			{
				rmCreateTrigger("bankwagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("bankwagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownBankWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}
			else
			{
				rmCreateTrigger("extrabank"+i);
				rmSwitchToTrigger(rmTriggerID("extrabank"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "Bank");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}
		}

		if (everyoneGetsAWagon == 993 || trollMap == 1)
		{
			rmCreateTrigger("buildinghp"+i);
			rmSwitchToTrigger(rmTriggerID("buildinghp"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEBuildingHPNugget"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 986 || trollMap == 1)
		{
			rmCreateTrigger("fastbuilding"+i);
			rmSwitchToTrigger(rmTriggerID("fastbuilding"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownStonemasonsLite"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 1002)
		{
			rmCreateTrigger("grovebonus"+i);
			rmSwitchToTrigger(rmTriggerID("grovebonus"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownGroveWagonBonus"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 999 && rmGetPlayerCiv(i) == rmGetCivID("Japanese") == false)
		{
			rmCreateTrigger("shrinewagonfix"+i);
			rmSwitchToTrigger(rmTriggerID("shrinewagonfix"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownShrineWagonFix"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			rmCreateTrigger("shrineindusbuff"+i);
			rmSwitchToTrigger(rmTriggerID("shrineindusbuff"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);			
			rmAddTriggerCondition("Tech Status Equals");
			rmSetTriggerConditionParamInt("PlayerID", i);
			rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
			rmSetTriggerConditionParamInt("Status", 2);	
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypShrineFortressUpgrade"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			rmCreateTrigger("shrinebuddhabuff"+i);
			rmSwitchToTrigger(rmTriggerID("shrinebuddhabuff"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);			
			rmAddTriggerCondition("Tech Status Equals");
			rmSetTriggerConditionParamInt("PlayerID", i);
			rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
			rmSetTriggerConditionParamInt("Status", 2);	
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypGiantBuddhaShrineBonus"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 1000)
		{
			rmCreateTrigger("dojoworksfaster"+i);
			rmSwitchToTrigger(rmTriggerID("dojoworksfaster"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypDojoUpgrade1"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ypDojoYumiArmy");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -11);		// -11 seconds
			
			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ypDojoAshigaruArmy");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -12);		// -12 seconds

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ypDojoKenseiArmy");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -13);		// -13 seconds

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ypDojoNaginataRiderArmy");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -14);		// -14 seconds

			rmAddTriggerEffect("Modify Protounit");
			rmSetTriggerEffectParam("Protounit", "ypDojoYabusameArmy");
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Field", 3);			// train points
			rmSetTriggerEffectParamInt("Delta", -15);		// -15 seconds

			if (rmGetPlayerCiv(i) == rmGetCivID("Japanese") == false)
			{
				rmCreateTrigger("dojowagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("dojowagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 4728);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownDojoWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	

				rmCreateTrigger("disciplinedyumi"+i);
				rmSwitchToTrigger(rmTriggerID("disciplinedyumi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 586);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1772);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPDisciplinedYumi"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);			

				rmCreateTrigger("honoredyumi"+i);
				rmSwitchToTrigger(rmTriggerID("honoredyumi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 419);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1776);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHonoredYumi"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);		

				rmCreateTrigger("exaltedyumi"+i);
				rmSwitchToTrigger(rmTriggerID("exaltedyumi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 484);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1780);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPExaltedYumi"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("disciplinednagi"+i);
				rmSwitchToTrigger(rmTriggerID("disciplinednagi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 586);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1775);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPDisciplinedNaginataRider"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("honorednagi"+i);
				rmSwitchToTrigger(rmTriggerID("honorednagi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 419);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1778);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHonoredNaginataRider"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("exaltednagi"+i);
				rmSwitchToTrigger(rmTriggerID("exaltednagi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 484);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1782);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPExaltedNaginataRider"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("disciplinedashi"+i);
				rmSwitchToTrigger(rmTriggerID("disciplinedashi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 586);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1774);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPDisciplinedAshigaru"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("honoredashi"+i);
				rmSwitchToTrigger(rmTriggerID("honoredashi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 419);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1777);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHonoredAshigaru"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("exaltedashi"+i);
				rmSwitchToTrigger(rmTriggerID("exaltedashi"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 484);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1781);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPExaltedAshigaru"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("disciplinedsamurai"+i);
				rmSwitchToTrigger(rmTriggerID("disciplinedsamurai"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 586);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 2013);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPDisciplinedSamurai"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("honoredsamurai"+i);
				rmSwitchToTrigger(rmTriggerID("honoredsamurai"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 419);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 2014);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHonoredSamurai"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);		

				rmCreateTrigger("exaltedsamurai"+i);
				rmSwitchToTrigger(rmTriggerID("exaltedsamurai"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 484);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 2015);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPExaltedSamurai"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);

				rmCreateTrigger("disciplinedyabu"+i);
				rmSwitchToTrigger(rmTriggerID("disciplinedyabu"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 586);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Fortressize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 2541);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("ypDisciplinedYabusameShadow"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);				

				rmCreateTrigger("honoredyabu"+i);
				rmSwitchToTrigger(rmTriggerID("honoredyabu"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 419);
			    rmSetTriggerConditionParamInt("TechID", rmGetTechID("Industrialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1779);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHonoredYabusame"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);		

				rmCreateTrigger("exaltedyabu"+i);
				rmSwitchToTrigger(rmTriggerID("exaltedyabu"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
	    		rmAddTriggerCondition("Tech Status Equals");
	    		rmSetTriggerConditionParamInt("PlayerID", i);
//	    		rmSetTriggerConditionParamInt("TechID", 484);
	    		rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
	    		rmSetTriggerConditionParamInt("Status", 2);
				rmAddTriggerEffect("Set Tech Status");
//				rmSetTriggerEffectParamInt("TechID", 1783);
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPExaltedYabusame"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);
			}
            else
            {
				rmCreateTrigger("dojowagonbuildlimitfix"+i);
				rmSwitchToTrigger(rmTriggerID("dojowagonbuildlimitfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);
                
				rmAddTriggerEffect("Modify Protounit Data");
				rmSetTriggerEffectParam("ProtoUnit", "ypDojo", false);
				rmSetTriggerEffectParamInt("PlayerID", i, false);
				rmSetTriggerEffectParamInt("Field", 11, false);
				rmSetTriggerEffectParamInt("Delta", 1, false);
				rmSetTriggerEffectParamInt("Relativity", 0, false);
                
				rmAddTriggerEffect("Set Tech Status");
				rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEDojoWagonShadow"));
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
            }
		}

		if (everyoneGetsAWagon == 974 && rmGetPlayerCiv(i) == rmGetCivID("Japanese") == false)
		{
			rmCreateTrigger("cherrywagonfix"+i);
			rmSwitchToTrigger(rmTriggerID("cherrywagonfix"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//			rmSetTriggerEffectParamInt("TechID", 4729);
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownCherryWagonFix"));
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			rmCreateTrigger("cherrywagongather"+i);
			rmSwitchToTrigger(rmTriggerID("cherrywagongather"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
//			rmSetTriggerEffectParamInt("TechID", 4733);
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownOrchardTech"));
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	

			rmCreateTrigger("orchardgoesbrrrr"+i);
			rmSwitchToTrigger(rmTriggerID("orchardgoesbrrrr"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerCondition("Tech Status Equals");
			rmSetTriggerConditionParamInt("PlayerID", i);
			rmSetTriggerConditionParamInt("TechID", rmGetTechID("Imperialize"), false);
			rmSetTriggerConditionParamInt("Status", 2);
			rmAddTriggerEffect("Set Tech Status");
    	    rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownBerryWagonImperialize"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 975)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("Chinese") == false)
			{
				rmCreateTrigger("villagewagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("villagewagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
    	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownVillageWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}
			else
			{
				rmCreateTrigger("extravillage"+i);
				rmSwitchToTrigger(rmTriggerID("extravillage"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "ypVillage");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one

				rmAddTriggerEffect("Unforbid and Enable Unit");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParam("Protounit", "ypGoat");
			}

			// activate boxer rebellion and village defense
			rmCreateTrigger("boxeractivate"+i);
			rmSwitchToTrigger(rmTriggerID("boxeractivate"+i));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);				
			rmAddTriggerEffect("Set Tech Status");
    	    rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHCAdvancedIrregulars"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
			rmAddTriggerEffect("Set Tech Status");
    	    rmSetTriggerEffectParamInt("TechID", rmGetTechID("YPHCVillageShooty"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);	
		}

		if (everyoneGetsAWagon == 976)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEHausa") == false && rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians") == false)
			{
				rmCreateTrigger("livestockmarketfix"+i);
				rmSwitchToTrigger(rmTriggerID("livestockmarketfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
    	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownLivestockMarketWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
			}
		}

		if (everyoneGetsAWagon == 977)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians") == false)
			{
				rmCreateTrigger("mountainmonasterywagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("mountainmonasterywagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
    	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownMountainMonasteryWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
				if (rmGetPlayerCiv(i) == rmGetCivID("DEHausa") == false)
				{
					rmAddTriggerEffect("Set Tech Status");
    	    		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownMountainMonasteryTechEnabler"), false);
					rmSetTriggerEffectParamInt("PlayerID", i);
					rmSetTriggerEffectParamInt("Status", 2);	
				}
			}
			else
			{
				rmCreateTrigger("extramonastery"+i);
				rmSwitchToTrigger(rmTriggerID("extramonastery"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "deMountainMonastery");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}
		}

		if (everyoneGetsAWagon == 978)
		{
			if (rmGetPlayerCiv(i) == rmGetCivID("DEHausa") == false)
			{
				rmCreateTrigger("uniwagonfix"+i);
				rmSwitchToTrigger(rmTriggerID("uniwagonfix"+i));
				rmSetTriggerPriority(4);
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerLoop(false);				
				rmAddTriggerEffect("Set Tech Status");
    	    	rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownUniversityWagonFix"), false);
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Status", 2);	
				if (rmGetPlayerCiv(i) == rmGetCivID("DEEthiopians") == false)
				{
					rmAddTriggerEffect("Set Tech Status");
    	    		rmSetTriggerEffectParamInt("TechID", rmGetTechID("DEUnknownUniversityTechEnabler"), false);
					rmSetTriggerEffectParamInt("PlayerID", i);
					rmSetTriggerEffectParamInt("Status", 2);	
				}
			}
			else
			{
				rmCreateTrigger("extrauni"+i);
				rmSwitchToTrigger(rmTriggerID("extrauni"+i));
				rmSetTriggerActive(true);
				rmSetTriggerRunImmediately(true);
				rmSetTriggerPriority(4);
				rmAddTriggerCondition("Always");
				rmAddTriggerEffect("Modify Protounit");
				rmSetTriggerEffectParam("Protounit", "deUniversity");
				rmSetTriggerEffectParamInt("PlayerID", i);
				rmSetTriggerEffectParamInt("Field", 10);		// build limit
				rmSetTriggerEffectParamInt("Delta", 01);		// plus one
			}
		}

		if (regicideActivator == 1)
		{
		    // Lose on Daimyo's death
		    rmCreateTrigger("DaimyoDeath"+i);
		    rmSwitchToTrigger(rmTriggerID("DaimyoDeath"+i));
		    rmSetTriggerPriority(4); 
		    rmSetTriggerActive(true);
		    rmSetTriggerRunImmediately(true);
		    rmSetTriggerLoop(false);
		    rmAddTriggerCondition("Is Dead");
		    rmSetTriggerConditionParamInt("SrcObject", rmGetUnitPlacedOfPlayer(regicideID, i), false);
		    rmAddTriggerEffect("Set Player Defeated");
		    rmSetTriggerEffectParamInt("Player", i, false);			
		}
	}

	// ------------------------------Triggers------------------------------//

	int flag1 = rmGetUnitPlaced(piratewaterflagID1, 0);
	int flag2 = rmGetUnitPlaced(piratewaterflagID2, 0);

	string pirateID1 = ""+(flag1-1);
	string pirateID2 = ""+(flag2-1);
	string scientistsID1 =""+(flag1-1);
	string scientistsID2 = ""+(flag2-1);
	string wokouID1 = ""+(flag1-1);
	string wokouID2 = ""+(flag2-1);
	string venetianID1 = ""+(flag1-1);
	string venetianID2 = ""+(flag2-1);
	string hansaID1 = ""+(flag1-1);
	string hansaID2 = ""+(flag2-1);

	int electorSpawn1 =	rmGetUnitPlaced(SpawnerID1, 0);
	int electorSpawn2 =	rmGetUnitPlaced(SpawnerID2, 0);
	int electorSpawn3 =	rmGetUnitPlaced(SpawnerID3, 0);
	int electorSpawn4 =	rmGetUnitPlaced(SpawnerID4, 0);

	string electorID1 = ""+(electorSpawn1-1);
	string electorID2 = ""+(electorSpawn2-1);	
	string electorID3 = ""+(electorSpawn3-1);	
	string electorID4 = ""+(electorSpawn4-1);

	// Starting techs

	rmCreateTrigger("Native Autosetup");
	rmAddTriggerEffect("ZP Native AutoSetup: 00 General (Place First)");
	rmAddTriggerEffect("ZP Native AutoSetup: XMassVillage");
	rmAddTriggerEffect("ZP Native AutoSetup: PenalColony");
	rmAddTriggerEffect("ZP Native AutoSetup: Orthodox");
	rmAddTriggerEffect("ZP Native AutoSetup: Aztecs - Native Consulate");
	rmAddTriggerEffect("ZP Native AutoSetup: Jewish");
	rmAddTriggerEffect("ZP Native AutoSetup: Maltese");
	rmAddTriggerEffect("ZP Native AutoSetup: Western");
	rmAddTriggerEffect("ZP Native AutoSetup: Hussites");
	rmAddTriggerEffect("ZP Native AutoSetup: Cossacks");
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Set Tech Status");
		rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpBonusBourbon"), false);
		rmSetTriggerEffectParamInt("PlayerID", i);
		rmSetTriggerEffectParamInt("Status", 2);
	}
	if (bourbonAlliance != 1) {
		for(i=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Set Tech Status");
			rmSetTriggerEffectParamInt("TechID", rmGetTechID("zpExtendMaya"), false);
			rmSetTriggerEffectParamInt("PlayerID", i);
			rmSetTriggerEffectParamInt("Status", 2);
		}
	}

	// Activate a specific type of pirate tiggers
	if (pirateType == 1){
		rmAddTriggerEffect("ZP Native AutoSetup: Pirates");
		rmSetTriggerEffectParam("Socket1", pirateID1);
		rmSetTriggerEffectParam("Socket2", pirateID2);
	}
	else if (pirateType == 2){
		rmAddTriggerEffect("ZP Native AutoSetup: Inventors (Scientists)");
		rmSetTriggerEffectParam("Socket1", scientistsID1);
		rmSetTriggerEffectParam("Socket2", scientistsID2);
	}
	else if (pirateType == 3){
		rmAddTriggerEffect("ZP Native AutoSetup: Wokou");
		rmSetTriggerEffectParam("Socket1", wokouID1);
		rmSetTriggerEffectParam("Socket2", wokouID2);
	}
	else if (pirateType == 4){
		rmAddTriggerEffect("ZP Native AutoSetup: Venetians");
		rmSetTriggerEffectParam("Socket1", venetianID1);
		rmSetTriggerEffectParam("Socket2", venetianID2);
	}
	else{
		rmAddTriggerEffect("ZP Native AutoSetup: Hanseatic");
		rmSetTriggerEffectParam("Socket1", hansaID1);
		rmSetTriggerEffectParam("Socket2", hansaID2);
	}
	for(i=1; <= cNumberNonGaiaPlayers) {
		if (SPCSufiMiddleEast == 1){
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpMediterraneanSufi"); // Sufi Mosque
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (SPCZenMountain == 1){
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpMountainZen"); // Mountain Zen
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	if (electorSpawn == 1){
		rmAddTriggerEffect("ZP Native AutoSetup: Prince Electors");
		rmSetTriggerEffectParam("Socket1", electorID1);
		rmSetTriggerEffectParam("Socket2", electorID2);
		rmSetTriggerEffectParam("Socket3", electorID3);
		rmSetTriggerEffectParam("Socket4", electorID4);
	}	
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	if (electorSpawn == 1){
		// Prince Elector Increments
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Elector Increase2"+k);
			rmCreateTrigger("Elector Increase3"+k);
			rmCreateTrigger("Elector Increase4"+k);

			rmCreateTrigger("Elector Decrease1"+k);
			rmCreateTrigger("Elector Decrease2"+k);
			rmCreateTrigger("Elector Decrease3"+k);

			rmSwitchToTrigger(rmTriggerID("Elector Increase2"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase3"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease1"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector Increase3"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",3);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase4"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease2"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector Increase4"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",4);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease3"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector Decrease3"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op","<=");
			rmSetTriggerConditionParamInt("Count",3);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase4"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease2"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector Decrease2"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op","<=");
			rmSetTriggerConditionParamInt("Count",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase3"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease1"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector Decrease1"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
			rmSetTriggerConditionParam("Op","<=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase2"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}

	}

	// Load Bar, sometimes used for a bit of fun RNG
	if (chaosBar == 1)
		rmSetStatusText("", 0.00);
	else if (trollBar == 1)
		rmSetStatusText("", 0.01);
	else
   		rmSetStatusText("", 1.00);

}	// DONE!!!!