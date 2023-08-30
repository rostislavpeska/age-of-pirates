//==============================================================================
/* aiGlobals.xs

   This file contains all global constants and variables.

*/
//==============================================================================

//==============================================================================
// Utilities.
//==============================================================================

extern const float PI = 3.1415926;
extern const int cTileBlack = 1;
extern const int cTileFog = 2;
extern const int cTileVisible = 4;

//==============================================================================
// Islands. AssertiveWall
//==============================================================================

extern bool gMigrationMap = false;          // True for migration style maps like Ceylon
extern bool gCeylonDelay = false;           // Used to delay buildings until we makee a base
extern int gCeylonStartingTargetArea = -1;
extern int gLastIslandSwitchTime = -1;      // Stores the last time we switched islands for building
extern int gOriginalBase = -1;              // Stores whatever our original base was
extern const int cIslandAStateNone = -1;    // None exists, none in progress
extern const int cIslandAStateBuilding = 0; // Fort wagon exists, but no fort yet.
extern const int cIslandAStateActive = 1;   // Base is active, defend and train plans there.
extern int gIslandAState = cIslandAStateNone;
extern int gIslandAID = -1;                      // Set when state goes to Active
extern vector gIslandALocation = cInvalidVector; // Set when state goes to 'building' or earlier.
extern int gIslandABuildPlan = -1;
//extern int gIslandAUpTime = -600000;
extern bool gIslandAShouldDefend = false;

extern int gIslandBState = cIslandAStateNone;
extern int gIslandBID = -1;                      // Set when state goes to Active
extern vector gIslandBLocation = cInvalidVector; // Set when state goes to 'building' or earlier.
extern int gIslandBBuildPlan = -1;
//extern int gIslandBUpTime = -600000;
extern bool gIslandBShouldDefend = false;

extern int gWaterNuggetPlan = -1;            // Persistent plan goes out to try and find water nuggets
extern const int cWaterNuggetSearch = -1;    // Units moving to the water nugget
extern const int cWaterNuggetAttack = 0;     // Units attacking the guardians 
extern const int cWaterNuggetGather = 1;     // Units gathering the nugget
extern int gWaterNuggetState = cWaterNuggetSearch;           // Stores the state of the water nugget plan
extern int gWaterNuggetTarget = -1;          // Stores the target of whatever the water nugget plan is doing
extern vector gWaterNuggetTargetLoc = cInvalidVector;
extern int gWaterNuggetTimeout = -1;         // Stores when a water nugget plan is made so it can be reset after too long

extern bool gIsPirateMap = false;            // Set true for testing. Used for pirates of the carribean mod

extern int gMainAttackGoal = -1;             // Used for legacy attack system


//==============================================================================
// Buildings.
//==============================================================================

extern int gTCBuildPlanID = -1;
extern vector gTCSearchVector = cInvalidVector; // Used to define the center of the TC building placement search.
extern int gTCStartTime = 10000;                // Used to define when the TC build plan can go active.  In ms.
extern const int cForwardBaseStateNone = -1;    // None exists, none in progress
extern const int cForwardBaseStateBuilding = 0; // Fort wagon exists, but no fort yet.
extern const int cForwardBaseStateActive = 1;   // Base is active, defend and train plans there.
extern int gForwardBaseState = cForwardBaseStateNone;
extern int gForwardBaseID = -1;                      // Set when state goes to Active
extern vector gForwardBaseLocation = cInvalidVector; // Set when state goes to 'building' or earlier.
extern int gForwardBaseBuildPlan = -1;
extern int gForwardBaseUpTime = -600000;
extern bool gForwardBaseShouldDefend = false;
extern int gMainBase = -1;
extern bool gBuildWalls = false;         // Global indicating if we're walling up or not.
extern int gNumTowers = 0;               // How many towers do we want to build?
extern bool gTowerCommandActive = false; // This is set by commHandler and used to determine which Tower amount to build.
extern int gCommandNumTowers = 0;        // Set inside of commHandler and used when we build Towers based on a command.
extern vector gTorpPosition = cInvalidVector;
extern int gTorpPositionsToAvoid = -1;
extern int gMilitaryBuildings = -1;
extern int gArmyUnitBuildings = -1;
extern int gFullGranaries = -1;  // List of granaries surrounded by fields
extern int gFieldGranaryID = -1; // The current granary chosen to build a field nearby
extern int gQueuedBuildPlans = -1;

extern int gHouseUnit = cUnitTypeHouse;
extern int gTowerUnit = cUnitTypeOutpost;
extern int gFarmUnit = cUnitTypeMill;
extern int gPlantationUnit = cUnitTypePlantation;
extern int gLivestockPenUnit = cUnitTypeLivestockPen;
extern int gMarketUnit = cUnitTypeMarket;
extern int gDockUnit = cUnitTypeDock;

//==============================================================================
// Techs.
//==============================================================================

extern int gConsulateFlagTechID = -1;     // the consulate flag tech we are going to research.
extern bool gConsulateFlagChosen = false; // need to make sure they only build one
extern int gAgeUpResearchPlan = -1; // Plan used to send politician from HC, used to detect if an age upgrade is in progress.
extern int gAgeUpTime = 0;          // Time we entered this age
extern int gAgeUpPlanTime = 0;      // Time to plan for next age up.

// Trade Route Array Constants.
extern const int cTradeRouteNorthAmerica = 0;
extern const int cTradeRouteSouthAmerica = 1;
extern const int cTradeRouteAsia = 2;
extern const int cTradeRouteAfrica = 3;
extern const int cTradeRouteNaval = 4;
extern const int cTradeRouteAll =
    5; // This is used for maps where upgrading one route also upgrades others, textures default to NA ones.
extern const int cTradeRouteCapturableAsia = 6;
extern const int cTradeRouteCapturableAfrica = 7; // If ever more Capturable routes are added this needs to be updated.
extern const int cTradeRouteFirstUpgrade = 0;
extern const int cTradeRouteSecondUpgrade = 1;
extern int gNumberTradeRoutes = -1; // Saves how many Trade Routes there are on the map via kbGetNumberTradeRoutes(), this never
                                    // changes so can just be a global sort of constant.

// Trade Route Arrays
// This saves how many Trade Routes there are on the map (index in the array is also the index of the TR at the same time)
// and what type these TRs are (land(continent)/naval).
extern int gTradeRouteIndexAndType = -1;
// This will be a bool array and false means the specific TR isn't fully upgraded and true means it is.
extern int gTradeRouteIndexMaxUpgraded = -1;
// Here we store what crates are actually delivered by each trade route so we can correctly
// set the tactic in tradeRouteTacticMonitor.
extern int gTradeRouteCrates = -1;
// Index 0 will be the first upgrade on the Route and 1 the second upgrade on the Route.
extern int gTradeRouteUpgrades = -1;

// In these variables we save the IDs of the minor native civs that are present on the map.
// We use these in the setupNativeUpgrades logic.
// We have 3 of these variables because the maximum amount of minor native civs you can get on a regular map is 3.
// This means that if you for example have a map with 4 different natives the 4th native will be ignored.
extern int gNativeTribeCiv1 = -1;
extern int gNativeTribeCiv2 = -1;
extern int gNativeTribeCiv3 = -1;
// We use these function pointers to research minor native upgrades via setupNativeUpgrades.
bool nativeResearchTechsEmpty(int tradingPostID = -1) { return (false); }
extern bool(int) gNativeTribeResearchTechs1 = nativeResearchTechsEmpty;
extern bool(int) gNativeTribeResearchTechs2 = nativeResearchTechsEmpty;
extern bool(int) gNativeTribeResearchTechs3 = nativeResearchTechsEmpty;

extern int gAfricanAlliancesAgedUpWith = 1; // Array of Alliances we've aged up with so far this game.
// Array of statuses of upgrades gained via Alliances. True is researched false is not researched.
extern int gAfricanAlliancesUpgrades =1;

// Hausa Alliance Constants.
extern const int cAllianceBerbersIndex = 0;
extern const int cAllianceHausaIndex = 1;
extern const int cAllianceSonghaiIndex = 2;
extern const int cAllianceAkanIndex = 3;
extern const int cAllianceBritishIndex = 4;

// Ethiopia Alliance Constants.
extern const int cAllianceSomalisIndex = 0;
extern const int cAlliancePortugueseIndex = 1;
extern const int cAllianceSudaneseIndex = 2;
extern const int cAllianceJesuitIndex = 3;
extern const int cAllianceOromoIndex = 4;

extern int gRevolutionList = -1; // List of Revolutions.
extern int gAfricanAlliances = -1;     // Array used to select from the different African alliances
extern int gMexicanFederalStates = -1; // Array used to select from the different Mexican Federal States.
extern int gAmericanFederalStates = -1; // Array used to select from the different United States Federal States.

// We save at what time the first person in the game advanced to Fortress/Industrial/Imperial in this array.
// In ageUpgradeMonitor we determine how badly we need to age up taking this into account.
extern int gFirstAgeTime = -1;

//==============================================================================
// Exploration.
//==============================================================================

extern int gWaterExplorePlan = -1;    // Plan ID for ocean exploration plan
extern int gExplorerControlPlan = -1; // Defend plan set up to control the explorer's location
extern int gLandExplorePlan = -1;     // Primary land exploration
extern int gIslandExploreTransportScoutID = -1;
extern bool gIslandMap = false; // Does this map have lands with waters in between?

//==============================================================================
// Economy.
//==============================================================================

extern int cMaxSettlersPerFarm = 10;
extern int cMaxSettlersPerPlantation = 10;
extern const int cMinResourcePerGatherer = 100; // When our supply gets below this level, start farming/plantations.
extern bool gTimeToFarm = false;                // Set to true when we start to run out of cheap early food.
extern bool gTimeForPlantations = false;        // Set to true when we start to run out of mine-able gold.
extern bool gPrioritizeFarms = false;           // Set to true when we should prioritize farms.
extern bool gPrioritizeEstates = false;         // Set to true when we should prioritze estates.
extern bool gCountBerries = false;              // Set to true when we should count berries as calculating natural resources we have left.

extern int gEconUpgradePlan = -1;
extern bool gGoodFishingMap = false;      // Set in init(), can be overridden in postInit() if desired.  True indicates that
                                          // fishing is a good idea on this map.
extern int gFishingPlan = -1;             // Plan ID for main fishing plan.
extern int gFishingBellPlan = -1;         // AssertiveWall: Dummy plan that allows fishing boats to be controlled easier
extern int gFishingBoatMaintainPlan = -1; // Fishing boats to maintain
extern bool gTimeToFish = false;          // Set to true when we want to start fishing.
extern int gHerdPlanID = -1;
extern int gResourceNeeds = -1;
extern int gExtraResourceNeeds = -1;
extern bool gLowOnResources = false;
extern bool gExcessResources = true;

extern int gGatherPlanPriorityHunt = 80;
extern int gGatherPlanPriorityBerry = 81;
extern int gGatherPlanPriorityMill = 82;
extern int gGatherPlanPriorityWood = 81;
extern int gGatherPlanPriorityMine = 78;
extern int gGatherPlanPriorityEstate = 83;
extern int gGatherPlanPriorityFish = 20;
extern int gGatherPlanPriorityWhale = 19;

extern int gGatherPlanNumHuntPlans = 0;
extern int gGatherPlanNumBerryPlans = 0;
extern int gGatherPlanNumMillPlans = 0;
extern int gGatherPlanNumWoodPlans = 0;
extern int gGatherPlanNumMinePlans = 0;
extern int gGatherPlanNumEstatePlans = 0;
extern int gGatherPlanNumFishPlans = 0;
extern int gGatherPlanNumWhalePlans = 0;

extern int gAdjustBreakdownAttempts = -1;

extern int gDepletedResources = 0; // Depleted resources mask.
extern const int cMarketBuyFoodWithGold = 0;
extern const int cMarketBuyWoodWithGold = 1;
extern const int cMarketSellFoodForGold = 2;
extern const int cMarketSellWoodForGold = 3;
extern int gMarketBuySellTypes = 0; // Market buy sell type mask.
extern int gMarketBuySellPercentages = -1; // Array of resource percentages to exchange to another one.
extern int gRawResourcePercentages = -1; // Raw resource percentages before market buy sell adjustments.
extern int gFarmFoodTactic = -1;
extern int gFarmGoldTactic = -1;

extern int gFishingUnit = cUnitTypeFishingBoat;
extern const int cResourceCanExceedMaxDistanceFood = 1;
extern const int cResourceCanExceedMaxDistanceWood = 2;
extern const int cResourceCanExceedMaxDistanceGold = 4;
extern int gResourceCanExceedMaxDistance = 0;
extern bool gResourceSearchAllAreaGroups = false;

//==============================================================================
// Decentralized Military 
//==============================================================================
// AssertiveWall: used to set up decentralized attack plans

extern int gAlphaCompanyPlan = -1;
extern int gBravoCompanyPlan = -1;
extern int gCharlieCompanyPlan = -1;
extern int gActiveRaid = -1;
extern vector gRaidGatherPoint = cInvalidVector;
extern int gRaidStartTime = 0;
extern int gActiveInterdiction = -1;

//==============================================================================
// Military.
//==============================================================================
extern int gLastTribSentTime = 0;

extern int gLandDefendPlan0 = -1; // Primary land defend plan
extern int gLandReservePlan = -1; // Reserve defend plan, gathers units for use in the next military mission
extern int gHealerPlan = -1;      // Defend plan that controls our healers in our base.
extern int gCoastalGunPlan = -1;  // AssertiveWall: Plan to stage artillery near docks and coast on island maps
extern int gEndlessWaterRaidPlan = -1; // AssertiveWall: Used to roam the map and raid areas

extern bool gDefenseReflex = false; // Set true when a defense reflex is overriding normal ops.
extern bool gDefenseReflexPaused =
    false; // Set true when we're in a defense reflex, but overwhelmed, so we're hiding to rebuild an army.
extern int gDefenseReflexBaseID = -1;                  // Set to the base ID that we're defending in this emergency
extern vector gDefenseReflexLocation = cInvalidVector; // Location we're defending in this emergency
extern int gDefenseReflexTimeout = 0;

extern int gLandUnitPicker = -1; // Picks the best land military units to train.

extern int gCaravelMaintain = -1; // Maintain plans for naval units.
extern int gGalleonMaintain = -1;
extern int gFrigateMaintain = -1;
extern int gMonitorMaintain = -1;
extern int gCanoeMaintain = -1; // AssertiveWall: for native canoes

extern float gNetNavyValue = -1; // Saves the power balance on the water.
extern int gNavyRepairPlan = -1; // Saves the ID of the naval defend combat (hijacked for repair) plan to manage land/navy interactions. 
extern int gNavyDefendPlan = -1; // Persistent naval defend plan.
extern int gNavyAttackPlan = -1; // Saves the ID of the naval attack combat plan to manage land/navy interactions.
extern vector gNavyVec = cInvalidVector; // The center of the navy's operations.
extern int gLastWSTime = 0; // AssertiveWall: used to know the last time enemy Warships were spotted
extern bool gHaveWaterSpawnFlag = false;
extern int gWaterSpawnFlagID = -1;
extern bool gNavyMap = false; // Setting this false prevents navies

extern int gNumArmyUnitTypes = 3; // How many land unit types do we want to train?

extern int gGoodArmyPop =
    -1; // This number is updated by the pop manager, only used to calculate stuff in the defence reflex logic.

extern int gUnitPickSource = cOpportunitySourceAutoGenerated; // Indicates who decides which units are being
                                                              // trained...self, trigger, or ally player.

extern int gLastVilTransportTime = -1; // AssertiveWall: used to give villager transport time to dropoff
extern int gLastClaimTradeMissionTime = -1;
extern int gLastNavalAttackTime = -1;
extern int gLastAttackMissionTime = -1;
extern int gLastDefendMissionTime = -1;
extern int gAttackMissionInterval =
    180000; // 2-3 minutes depending on difficulty level.  Suppresses attack scores (linearly) for 2-3 minutes after one
            // launches.  Attacks will usually happen before this period is over.
extern int gDefendMissionInterval = 300000; // 5 minutes.   Makes the AI less likely to do another defend right after doing one.
extern int gClaimTradeMissionInterval = 300000;  // 5 minutes.
extern int gClaimNativeMissionInterval = 600000; // 10 minutes.
extern int gLastClaimNativeMissionTime = -1;

extern int gNumEnemies = -1;             // Used to pick a target to attack.
extern int gArrayEnemyPlayerIDs = -1;    // Used to pick a target to attack.
extern int gStartingPosDistances = -1;   // Used to sort enemies from closest to furthest away for target picking in FFA.

extern bool gIAmCaptain = false;
extern int gCaptainPlayerNumber = -1;

extern bool gIsMonopolyRunning = false; // Set true while a monopoly countdown is in effect.
extern int gMonopolyTeam = -1;          // TeamID of team that will win if the monopoly timer completes.

extern bool gIsKOTHRunning = false; // Set true while a KOTH countdown is in effect.
extern int gKOTHTeam = -1;          // TeamID of team that will win if the KOTH timer completes.

extern int gArmyUnitMaintainPlans = -1;

extern int gCaravelUnit = cUnitTypeCaravel;
extern int gGalleonUnit = cUnitTypeGalleon;
extern int gFrigateUnit = cUnitTypeFrigate;
extern int gMonitorUnit = cUnitTypeMonitor;
extern int gCanoeUnit = -1;                    // Canoe type determined in navymanager

//==============================================================================
// Home City cards.
//==============================================================================

extern int gDefaultDeck = -1; // Home city deck used by each AI

//==============================================================================
// Chats.
//==============================================================================

extern int gFeedGoldTo = -1; // If set, this indicates which player we need to be supplying with regular gold shipments.
extern int gFeedWoodTo = -1; // See commHandler and monitorFeeding rule.
extern int gFeedFoodTo = -1;
extern int gMapNames = -1; // An array of random map names, so we can store ID numbers in player histories

extern int gLateInAgePlayerID = -1;
extern int gLateInAgeAge = -1;

//==============================================================================
// Setup.
//==============================================================================
// Start mode constants.
extern int gStartMode = -1;                   // See start mode constants, above.  This variable is set
                                              // in main() and is used to decide which cascades of rules
                                              // should be used to start the AI.
extern const int cStartModeScenarioNoTC = 0;  // Scenario, wait for aiStart unit, then play without a TC
extern const int cStartModeScenarioTC = 1;    // Scenario, wait for aiStart unit, then play with starting TC
extern const int cStartModeScenarioWagon = 2; // Scenario, wait for aiStart unit, then start TC build plan.
extern const int cStartModeLandTC = 3;        // RM or GC game, starting with a TC...just go.
extern const int cStartModeLandWagon = 4;     // RM or GC game, starting with a wagon.  Explore, start TC build plan.
extern const int cStartModeLandResources = 5; // RM or GC game, starting with enough resources to build a TC.

extern vector gStartingLocationOverride = cInvalidVector;
extern bool gStartOnDifferentIslands = false; // Does this map have players starting on different islands?

//==============================================================================
// All other stuffs.
//==============================================================================

extern int gMaxPop = 200; // Absolute hard limit pop cap for game...will be set lower on some difficulty levels
extern int gNativeDancePlan = -1;
extern bool gSPC = false; // Set true in main if this is an spc or campaign game

extern const int cRevolutionMilitary = 1;
extern const int cRevolutionEconomic = 2;
extern const int cRevolutionFinland = 4;
extern int gRevolutionType = 0;

// Save which age variant of Asian Wonder we aged up with to be used instead of kbUnitCount checks.
// Chinese.
extern int gWhitePagodaPUID = -1;
extern int gSummerPalacePUID = -1;
extern int gConfucianAcademyPUID = -1;
extern int gTempleOfHeavenPUID = -1;
extern int gPorcelainTowerPUID = -1;

// Indians.
extern int gAgraFortPUID = -1;
extern int gCharminarGatePUID = -1;
extern int gKarniMataPUID = -1;
extern int gTajMahalPUID = -1;
extern int gTowerOfVictoryPUID = -1;

// Japanese.
extern int gGreatBuddhaPUID = -1;
extern int gGoldenPavilionPUID = -1;
extern int gTheShogunatePUID = -1;
extern int gToriiGatesPUID = -1;
extern int gToshoguShrinePUID = -1;

extern int gEconUnit = cUnitTypeSettler;
extern int gSettlerMaintainPlan = -1; // Main plan to control settler population
extern int gTargetSettlerCounts = -1; // How many settlers do we want in a given age?
                                      // We call aiSetEconomyPop with a number calculated with this array since that takes all
                                      // eco units into account and this array only our gEconUnit.
extern int gTargetSettlerCountsDefault = -1; // This array stores the values the non special Settler civs have.
                                             // It is then used to calculate a proper military population.

extern int gDifficultyExpert = cDifficultyExpert; // Equivalent of expert difficulty, hard for SPC content.

//==============================================================================
// Debug variables.
//==============================================================================
extern const bool cDebugUtilities = false;
extern const bool cDebugBuildings = false;
extern const bool cDebugTechs = false;
extern const bool cDebugExploration = false;
extern const bool cDebugEconomy = false;
extern const bool cDebugMilitary = false;
extern const bool cDebugHCCards = false;
extern const bool cDebugChats = false;
extern const bool cDebugSetup = false;
extern const bool cDebugCore = false;