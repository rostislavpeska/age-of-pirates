//==============================================================================
/* aiPirateRules.xs

   This file contains some map specific functions written for the Pirates of the
   Caribbean mod.

*/
//==============================================================================



//==============================================================================
// initializePirateRules
// Rule starts as active, only runs as a setup rule and disables after one cycle
// Interval set long to avoid interfering with setup.xs
//==============================================================================

rule initializePirateRules
active
minInterval 1
{
   // AssertiveWall: Check for Pirate Maps and set gStartOnDifferentIslands true for all of them
   if (cRandomMapName == "zpburma_b" ||
       cRandomMapName == "zpcoldwar" ||
       cRandomMapName == "zpdeadsea" ||
       cRandomMapName == "zpeldorado" ||
       cRandomMapName == "zpkurils" ||
       cRandomMapName == "zpmalta_castles" ||
       cRandomMapName == "zpmalta" ||
       cRandomMapName == "zpphilippines" ||
       cRandomMapName == "zptortuga" ||
       cRandomMapName == "zptreasureisland" ||
       cRandomMapName == "zpvenice" ||
       cRandomMapName == "zpmediterranean" ||
       cRandomMapName == "zpzealand")
   {
      gStartOnDifferentIslands = true;
      gIsPirateMap = true;
      gNavyMap = true;
      if (haveHumanAlly() == true)
      {
         gClaimNativeMissionInterval = 5 * 60 * 1000; // 5 minutes, down from 10
      }
      else
      {
         gClaimNativeMissionInterval = 3 * 60 * 1000; // 5 minutes, down from 10
      }

      gClaimTradeMissionInterval = 4 * 60 * 1000; // 4 minutes, down from 5
   }

   // AssertiveWall: Naval, but not starting on different islands
      if (cRandomMapName == "zphawaii")
   {
      gIsPirateMap = true;
      gNavyMap = true;

      if (haveHumanAlly() == true)
      {
         gClaimNativeMissionInterval = 5 * 60 * 1000; // 5 minutes, down from 10
      }
      else
      {
         gClaimNativeMissionInterval = 3 * 60 * 1000; // 5 minutes, down from 10
      }

      gClaimTradeMissionInterval = 4 * 60 * 1000; // 4 minutes, down from 5
   }

   // AssertiveWall: Land Maps
   if (cRandomMapName == "winterwonderlandii" ||
       cRandomMapName == "zpwildwest" ||
       cRandomMapName == "zpmississippi" ||
       cRandomMapName == "zpwwcanyon")
   {
      gIsPirateMap = true;
      if (haveHumanAlly() == true)
      {
         gClaimNativeMissionInterval = 5 * 60 * 1000; // 5 minutes, down from 10
      }
      else
      {
         gClaimNativeMissionInterval = 3 * 60 * 1000; // 5 minutes, down from 10
      }

      gClaimTradeMissionInterval = 4 * 60 * 1000; // 4 minutes, down from 5
   }

   // AssertiveWall: Archipelago style maps
   if (cRandomMapName == "euArchipelago" ||
       cRandomMapName == "euArchipelagoLarge"||
       cRandomMapName == "zpmediterranean" ||
       cRandomMapName == "zpkurils")
   {
      gIsArchipelagoMap = true;
      gStartOnDifferentIslands = true;
      gIsPirateMap = true;
      gNavyMap = true;

      cvOkToGatherFood = false;      // Setting it false will turn off food gathering. True turns it on.
      cvOkToGatherGold = false;      // Setting it false will turn off gold gathering. True turns it on.
      cvOkToGatherWood = false;      // Setting it false will turn off wood gathering. True turns it on.
      gHomeBase = kbGetPlayerStartingPosition(cMyID);
   }

   // AssertiveWall: Migration style maps
   if (cRandomMapName == "Ceylon" ||
       cRandomMapName == "ceylonlarge" ||
       cRandomMapName == "afswahilicoast" ||
       cRandomMapName == "afswahilicoastlarge" ||
       cRandomMapName == "zpeldorado" ||
       //cRandomMapName == "zppolynesia" ||
       cRandomMapName == "zptreasureisland")
   {
      gMigrationMap = true;
   }

   // Initializes all pirate functions

   // Add rules for all pirate maps here
   if (gIsPirateMap == true)
   {
      xsEnableRule("CaribTPMonitor");
      xsEnableRule("pirateShipAbilityMonitor");
   }
   
   // Initializes native specific rules
   if (getGaiaUnitCount(cUnitTypezpNativeHousePirate) > 0)
   {
      xsEnableRule("MaintainPirateShips");
      xsEnableRule("PirateTechMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeHouseWokou) > 0)
   {
      xsEnableRule("MaintainWokouShips");
      xsEnableRule("WokouTechMonitor");
      xsEnableRule("submarineTactics");
      xsEnableRule("airshipAbilityMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeHouseJewish) > 0)
   {
      xsEnableRule("maintainJewishSettlers");
      xsEnableRule("jewishBuildingMonitor");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("zpJewishTechMonitor");
   }
   if ((getGaiaUnitCount(cUnitTypezpSPCBlueMosque) > 0) || (getGaiaUnitCount(cUnitTypezpSPCGreatMosque) > 0))
   {
      xsEnableRule("maintainSufiSettlers");
      xsEnableRule("maintainSufiBedouins");
      xsEnableRule("SufiBigButtonMonitor");
      xsEnableRule("SufiTechMonitor");
      xsEnableRule("SufiWhiteFortManager");
      xsEnableRule("zenSufiBuildingMonitor");
   }
   if ((getGaiaUnitCount(cUnitTypezpSPCGreatBuddha) > 0) || (getGaiaUnitCount(cUnitTypezpSPCPropZenCastle) > 0))
   {
      xsEnableRule("maintainZenSettlers");
      xsEnableRule("ZenBigButtonMonitor");
      xsEnableRule("ZenTechMonitor");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("zenSufiBuildingMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeAztecTempleA) > 0)
   {
      xsEnableRule("zpMaintainAztecNativeVillagers");
      xsEnableRule("zpNativeAztecBigButtonMonitor");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("zpAztecTechMonitor");
      xsEnableRule("aztecBuildingMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpWeaponFactoryWinter) > 0 || (getGaiaUnitCount(cUnitTypezpWeaponFactorySummer) > 0))
   {
      xsEnableRule("MaintainScientistShips");
      xsEnableRule("MaintainScientistTanks");
      xsEnableRule("MaintainScientistAirship");
      xsEnableRule("zpScientistTechMonitor");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("submarineTactics");
      xsEnableRule("airshipAbilityMonitor");
      xsEnableRule("airshipManager");

      // Need a way to determine whether this is needed
      xsEnableRule("armoredTrainMonitor");
   }

   if (getGaiaUnitCount(cUnitTypezpNativeHouseInuit) > 0)
   {
      xsEnableRule("zpInuitTechMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeHouseMaori) > 0)
   {
      gCanoeUnit = cUnitTypezpWakaCanoe;
      xsEnableRule("zpMaoriTechMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeHouseAboriginals) > 0)
   {
      gCanoeUnit = cUnitTypezpWakaCanoe;
      xsEnableRule("zpAboriginalTechMonitor");
      xsEnableRule("zpAboriginalSchoolBuilder");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeHouseMaltese) > 0)
   {
      xsEnableRule("zpMalteseTechMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpJesuitCathedral) > 0)
   {
      xsEnableRule("zpJesuitTechMonitor");
      xsEnableRule("maintainJesuitMissionary");
      xsEnableRule("priestAbilityMonitor");
   }
   if (getGaiaUnitCount(cUnitTypezpNativeUnitVenetianFlag) > 0)
   {
      xsEnableRule("VeniceTechMonitor");
      xsEnableRule("MaintainVeniceShips");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("dottoreAbilityMonitor");
   }
   if (getUnit(cUnitTypezpPropChristmassTree) > 0)
   {
      xsEnableRule("christmasTechMonitor");
      xsEnableRule("nativeWagonMonitor");
      xsEnableRule("polarExpressUpgradeMonitor");
   }

   if (getUnit(cUnitTypezpNativeHouseOrthodox) > 0)
   {
      xsEnableRule("orthodoxTechMonitor");
      xsEnableRule("nativeWagonMonitor");
   }
   if (getUnit(cUnitTypezpNativeHouseWesternVillage) > 0)
   {
      xsEnableRule("zpWesternTechMonitor");
      xsEnableRule("nativeWagonMonitor");
   }
   if (cMyCiv == cCivDEInca)
   {
        xsEnableRule("priestessAbilityMonitor");
   }
    
   xsDisableSelf();
}


//==============================================================================
// Monitors special behavior for armored train
//==============================================================================
rule armoredTrainMonitor
inactive
minInterval 5
{
   // Look at all rail stations, if we have military nearby then send the train
   // Condition: 
   //    > 10 enemy or > 5 enemy buildings (likely in their base, killing their dudes)
   //    > 10 friendly
   //    -> then picks the most outnumbered station
   //    Will send to KOTH station if there are > 10 enemy

   /*if (aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, cTechzpArmoredTrainLevy) < 0)
   {
      researchSimpleTech(cTechzpArmoredTrainLevy, cUnitTypezpArmoredTrainBarracksBuilding, -1, 99);
   }*/
   
   int stationQueryID = -1;
   int numberFound = -1;
   int bestStationID = -1;
   int bestStationFriendlyArmyCount = -1;
   int bestStationEnemyArmyCount = -999;
   int tempFriendly = -1;
   int tempEnemy = -1;
   vector tempLocation = cInvalidVector;
   int tempUnit = -1;
   int ourStation = -1;
   int ourStationQuery = -1;
   bool dontReturn = false;
   int tempNearbyEnemyBuildings = -1;
   vector kothBuildingLoc = cInvalidVector;
   bool chooseKOTH = false;

   ourStationQuery = createSimpleUnitQuery(cUnitTypeTradingPost, cPlayerRelationSelf, cUnitStateAlive);
   numberFound = kbUnitQueryExecute(ourStationQuery);

   for (i = 0; < numberFound)
   {
      ourStation = kbUnitQueryGetResult(ourStationQuery, i);
      if (aiCanUseAbility(ourStation, cProtoPowerzpPowerArmouredTrain) == true)
      {  // If someone can use the ability, then we can continue
         dontReturn = true;
         break;
      }
   }

   if (dontReturn == false)
   {
      return;
   }

   stationQueryID = createSimpleUnitQuery(cUnitTypezpInvisibleRailwayStation, cPlayerRelationAny, cUnitStateAny);
   numberFound = kbUnitQueryExecute(stationQueryID);
   kothBuildingLoc = kbUnitGetPosition(getUnit(cUnitTypeypKingsHill, cPlayerRelationAny, cUnitStateAlive));

   for (i = 0; < numberFound)
   {
      // See if there's a suitable target, starting with KOTH
      tempUnit = kbUnitQueryGetResult(stationQueryID, i);
      tempLocation = kbUnitGetPosition(tempUnit);
      tempEnemy = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, tempLocation, 65.0);
      tempNearbyEnemyBuildings = getUnitCountByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, tempLocation, 65.0);

      if (aiIsKOTHAllowed() == true)
      { // Make sure we grab KOTH location. We'll use kothBuilding to tell whether we've found the hill nearby or not
         
         if (distance(tempLocation, kothBuildingLoc) < 50)
         {
            chooseKOTH = true;
         }
      }

      if (tempEnemy > 10 || tempNearbyEnemyBuildings > 5)
      {
         tempFriendly = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationAlly,
               cUnitStateAlive, tempLocation, 65.0);
         if (tempEnemy - tempFriendly > bestStationEnemyArmyCount - bestStationFriendlyArmyCount && (tempFriendly > 10 || chooseKOTH == true))
         {
            bestStationID = tempUnit;
            bestStationEnemyArmyCount = tempEnemy;
            bestStationFriendlyArmyCount = tempFriendly;
            if (chooseKOTH == true)
            {  // If we found the hill, and it's worth sending there, send it.
               break;
            }
         }
      }
   }

   if (bestStationID > 0)
   {
      aiTaskUnitSpecialPower(ourStation, cProtoPowerzpPowerArmouredTrain, bestStationID, cInvalidVector);
   }
}

//==============================================================================
// Airship Manager
//==============================================================================
rule airshipManager
inactive
minInterval 12
{  // Looks for any active attack or defend plan and adds the airship to it. Based on isdefendingorattacking
   int numPlans = aiPlanGetActiveCount();
   int existingPlanID = -1;

   if (getUnit(cUnitTypezpAirshipAI) < 0)
   {
      return;
   }
   
   for (int i = 0; i < numPlans; i++)
   {
      existingPlanID = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(existingPlanID) != cPlanCombat)
      {
         continue;
      }
      if (aiPlanGetVariableInt(existingPlanID, cCombatPlanCombatType, 0) == cCombatPlanCombatTypeDefend)
      {
         if ((existingPlanID != gExplorerControlPlan) &&
             (existingPlanID != gLandDefendPlan0) && 
             (existingPlanID != gLandReservePlan) && 
             (existingPlanID != gHealerPlan) && 
             (existingPlanID != gNavyRepairPlan) && 
             (existingPlanID != gNavyDefendPlan) &&
             (existingPlanID != gCoastalGunPlan))
         {
            aiPlanAddUnitType(existingPlanID, cUnitTypezpAirshipAI, 1, 1, 200);
         }
      }
      else // Attack plan.
      {
         if ((aiPlanGetParentID(existingPlanID) < 0) && // No parent so not a reinforcing child plan.
             (existingPlanID != gCoastalGunPlan))
         {
            aiPlanAddUnitType(existingPlanID, cUnitTypezpAirshipAI, 1, 1, 200);
         }
      }
   }
}

//==============================================================================
// Priestess Ability Monitor
//==============================================================================
rule priestessAbilityMonitor
inactive
minInterval 12
{
   int priestessID = -1;
   int enemyID = 0;
   vector enemyLoc = cInvalidVector;
   vector priestessLoc = cInvalidVector;
   
   // Subs dive if any enemy warships are nearby, otherwise surface
   int priestessQuery = createSimpleUnitQuery(cUnitTypedePriestess, cMyID, cUnitStateAlive);
   int numberPriestessFound = kbUnitQueryExecute(priestessQuery);

   for (i = 0; < numberPriestessFound)
   {
      priestessID = kbUnitQueryGetResult(priestessQuery, i);
      // Check for conversion ability
      if (aiCanUseAbility(priestessID, cProtoPowerPowerConvert) == true)
      {
         priestessLoc = kbUnitGetPosition(priestessID);
         enemyID = getUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, priestessLoc, 20.0);
         enemyLoc = kbUnitGetPosition(enemyID);
         if (enemyID > 0)
         {
            aiTaskUnitSpecialPower(priestessID, cProtoPowerPowerConvert, enemyID, cInvalidVector);
         }
      }
   }
}

//==============================================================================
// Jesuit Priest Ability Monitor
//==============================================================================
rule priestAbilityMonitor
inactive
minInterval 12
{
   int priestID = -1;
   int enemyID = 0;
   vector enemyLoc = cInvalidVector;
   vector priestLoc = cInvalidVector;
   
   // Subs dive if any enemy warships are nearby, otherwise surface
   int priestQuery = createSimpleUnitQuery(cUnitTypezpPriest, cMyID, cUnitStateAlive);
   int numberPriestFound = kbUnitQueryExecute(priestQuery);

   for (i = 0; < numberPriestFound)
   {
      priestID = kbUnitQueryGetResult(priestQuery, i);
      // Check for conversion ability
      if (aiCanUseAbility(priestID, cProtoPowerPowerConvert) == true)
      {
         priestLoc = kbUnitGetPosition(priestID);
         enemyID = getUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, priestLoc, 20.0);
         enemyLoc = kbUnitGetPosition(enemyID);
         if (enemyID > 0)
         {
            aiTaskUnitSpecialPower(priestID, cProtoPowerPowerConvert, enemyID, cInvalidVector);
         }
      }
   }
}

//==============================================================================
// Pirate Ship Ability Monitor
//==============================================================================
rule pirateShipAbilityMonitor
inactive
minInterval 12
{
   int pirateShipID = getUnit(cUnitTypezpSPCQueenAnne, cMyID, cUnitStateAlive);
   int enemyID = -1;
   vector pirateShipLoc = cInvalidVector;
   int enemyCount = 0;
   bool longBombard = false;

   if (pirateShipID > 0)
   {
      pirateShipLoc = kbUnitGetPosition(pirateShipID);
      if (aiCanUseAbility(pirateShipID, cProtoPowerPowerGreekFire) == true)
      {
         // Look for nearby units to use the ability on
         enemyID = getUnitByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, pirateShipLoc, 20.0);
         if (enemyID >= 0)
         {
            aiTaskUnitSpecialPower(pirateShipID, cProtoPowerPowerGreekFire, enemyID, cInvalidVector);
         }
      }
      pirateShipID = 0;
   }
   if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpSubmarine, cMyID, cUnitStateAlive);
      if (pirateShipID > 0)
      {
         pirateShipLoc = kbUnitGetPosition(pirateShipID);
         if (aiCanUseAbility(pirateShipID, cProtoPowerdePowerShunt) == true)
         {
            // Look for nearby units to use the ability on. Only ram when there are 1-2 enemies nearby
            enemyID = getUnitByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, pirateShipLoc, 15.0);
            enemyCount = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, pirateShipLoc, 45.0);
            if (enemyID >= 0 && enemyCount <= 2)
            {
               aiTaskUnitSpecialPower(pirateShipID, cProtoPowerdePowerShunt, enemyID, cInvalidVector);
            }
         }
      }
      pirateShipID = getUnit(cUnitTypezpNautilus, cMyID, cUnitStateAlive);
      if (pirateShipID > 0)
      {
         pirateShipLoc = kbUnitGetPosition(pirateShipID);
         if (aiCanUseAbility(pirateShipID, cProtoPowerdePowerShunt) == true)
         {
            // Look for nearby units to use the ability on. Only ram when there are 1-2 enemies nearby
            enemyID = getUnitByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, pirateShipLoc, 15.0);
            enemyCount = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, pirateShipLoc, 45.0);
            if (enemyID >= 0 && enemyCount <= 2)
            {
               aiTaskUnitSpecialPower(pirateShipID, cProtoPowerdePowerShunt, enemyID, cInvalidVector);
            }
         }
      }
      pirateShipID = 0;
   }

   // If we didn't find the flagship, keep looking for others
   if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpSPCBlackPearl, cMyID, cUnitStateAlive);
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpSPCNeptuneGalley, cMyID, cUnitStateAlive);
      longBombard = true;
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpWokouFuchuan, cMyID, cUnitStateAlive);
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpSPCTreasureShip, cMyID, cUnitStateAlive);
      longBombard = true;
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpMalteseRiggedShip, cMyID, cUnitStateAlive);
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpSPCLineShip, cMyID, cUnitStateAlive);
   }
   else if (pirateShipID < 0)
   {
      pirateShipID = getUnit(cUnitTypezpCatamaran, cMyID, cUnitStateAlive);
      longBombard = true;
   }
   if (pirateShipID > 0)
   {
      pirateShipLoc = kbUnitGetPosition(pirateShipID);
      if (aiCanUseAbility(pirateShipID, cProtoPowerPowerBroadside) == true)
      {
         // Look for nearby units to use the ability on
         enemyID = getUnitByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, pirateShipLoc, 28.0);
         if (enemyID >= 0)
         {
            aiTaskUnitSpecialPower(pirateShipID, cProtoPowerPowerBroadside, enemyID, cInvalidVector);
         }
      }
      if (longBombard == true)
      {
         if (aiCanUseAbility(pirateShipID, cProtoPowerPowerLongRange) == true)
         {
            // Look for nearby buildings to use the ability on
            enemyID = getUnitByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, pirateShipLoc, 65.0);
            if (enemyID >= 0)
            {
               aiTaskUnitSpecialPower(pirateShipID, cProtoPowerPowerLongRange, enemyID, cInvalidVector);
            }
         }
      }
   }
}

//==============================================================================
// Dottore Ability Monitor
//==============================================================================
rule dottoreAbilityMonitor
inactive
minInterval 12
{
   int dottoreID = -1;
   int enemyID = 0;
   vector enemyLoc = cInvalidVector;
   int friendlyNum = 0;
   int enemyNum = 0;

   // Subs dive if any enemy warships are nearby, otherwise surface
   int dottoreQuery = createSimpleUnitQuery(cUnitTypezpNatDottore, cMyID, cUnitStateAlive);
   int numberDottoreFound = kbUnitQueryExecute(dottoreQuery);

   for (i = 0; < numberDottoreFound)
   {
      dottoreID = kbUnitQueryGetResult(dottoreQuery, i);

      if (dottoreID >= 0)
      {
         vector dottoreLoc = kbUnitGetPosition(dottoreID);

         if (aiCanUseAbility(dottoreID, cProtoPowerzpMustardGasWeak) == true)
         {
            enemyNum = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, dottoreLoc, 20.0);
            enemyID = getUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
               cUnitStateAlive, dottoreLoc, 20.0);
            enemyLoc = kbUnitGetPosition(enemyID);
            friendlyNum = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationAlly, cUnitStateAlive, 
               enemyLoc, 14.0);
            if (enemyID >= 0 && (1.5 * friendlyNum < enemyNum))  // Gas it if we are losing
            {  
               aiTaskUnitSpecialPower(dottoreID, cProtoPowerzpMustardGasWeak, enemyID, cInvalidVector);
            }
         }
      }
   }
}

//==============================================================================
// Airship Ability Monitor
//==============================================================================
rule airshipAbilityMonitor
inactive
minInterval 12
{
   int airshipID = getUnit(cUnitTypezpAirshipAI, cMyID, cUnitStateAlive);
   int enemyID = 0;
   vector enemyLoc = cInvalidVector;
   int friendlyNum = 0;
   
   if (airshipID >= 0)
   {
      vector airshipLoc = kbUnitGetPosition(airshipID);
      // Check for fire bomb, then poison, then explosion
      if (aiCanUseAbility(airshipID, cProtoPowerzpPowerFireBomb) == true)
      {
         // Look for nearby units to use the ability on
         enemyID = getUnitByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, airshipLoc, 20.0);
         if (enemyID >= 0)
         {
            aiTaskUnitSpecialPower(airshipID, cProtoPowerzpPowerFireBomb, enemyID, cInvalidVector);
         }
      }

      if (aiCanUseAbility(airshipID, cProtoPowerzpMustardGas) == true && enemyID < 0)
      {
         enemyID = getUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia,
            cUnitStateAlive, airshipLoc, 20.0);
         enemyLoc = kbUnitGetPosition(enemyID);
         friendlyNum = getUnitCountByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationAlly, cUnitStateAlive, 
            enemyLoc, 14.0);
         if (enemyID >= 0 && friendlyNum <= 0)
         {
            aiTaskUnitSpecialPower(airshipID, cProtoPowerzpMustardGas, enemyID, cInvalidVector);
         }
      }
   }
}

//==============================================================================
// zenSufi Building Monitor
//==============================================================================
rule zenSufiBuildingMonitor
inactive
minInterval 5
{
   int towerCount = kbUnitCount(cMyID, gTowerUnit, cUnitStateAlive);
   int planID = -1;

   // =================
   // First look at Zen
   // =================
   int zenVillager = getUnit(cUnitTypezpSettlerZen, cPlayerRelationSelf, cUnitStateAlive);
   int sufiVillager = getUnit(cUnitTypezpSettlerSufi, cPlayerRelationSelf, cUnitStateAlive);
   if (zenVillager > 0 || sufiVillager > 0)
   {
      // Check for desired number of paddys and towers. Allow native to build +1 more than we want (via >=)
      int zenTowerLimit = kbGetBuildLimit(cMyID, cUnitTypeYPOutpostAsian);
      int zenTowerCount = kbUnitCount(cMyID, cUnitTypeYPOutpostAsian, cUnitStateABQ);
      if (gNumTowers >= towerCount && zenTowerCount < zenTowerLimit)
      {
         planID = createSimpleBuildPlan(cUnitTypeYPOutpostAsian, 1, 99, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
         if (zenVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerZen, 1, 1, 1);
         }
         else if (sufiVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerSufi, 1, 1, 1);
         }
         else
         {  // Shouldn't ever get here, but just in case
            aiPlanDestroy(planID);
         }
         //createLocationBuildPlan(YPOutpostAsian, 1, 70, false, cMilitaryEscrowID, vector position = cInvalidVector, int numberBuilders = 1)
      }

      // For now just build one rice paddy. The logic to build mills/plantations is fairly involved and difficult
      // to slip into
      int zenPaddyLimit = 1;
      int zenPaddyCount = kbUnitCount(cMyID, cUnitTypeypRicePaddy, cUnitStateABQ);
      if (zenPaddyCount < zenPaddyLimit)
      {
         planID = createSimpleBuildPlan(cUnitTypeypRicePaddy, 1, 99, true, cEconomyEscrowID, kbBaseGetMainID(cMyID), 0);
         if (zenVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerZen, 1, 1, 1);
         }
         else if (sufiVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerSufi, 1, 1, 1);
         }
         else
         {  // Shouldn't ever get here, but just in case
            aiPlanDestroy(planID);
         }
      }
   }

   // =================
   // Now look at SufiB
   // =================
   int sufiBVillager = getUnit(cUnitTypezpSettlerSufiB, cPlayerRelationSelf, cUnitStateAlive);
   if (sufiBVillager > 0)
   {
      // Check for desired number of towers. Allow native to build +1 more than we want (via >=)
      int sufiBTowerLimit = kbGetBuildLimit(cMyID, cUnitTypezpArabianTower);
      int sufiBTowerCount = kbUnitCount(cMyID, cUnitTypezpArabianTower, cUnitStateABQ);
      if (gNumTowers >= towerCount && sufiBTowerCount < sufiBTowerLimit)
      {
         planID = createSimpleBuildPlan(cUnitTypezpArabianTower, 1, 59, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
         if (sufiBVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerSufiB, 1, 1, 1);
         }
         else
         {  // Shouldn't ever get here, but just in case
            aiPlanDestroy(planID);
         }
      }
   }
}

//==============================================================================
// Aztec Building Monitor
//==============================================================================
rule aztecBuildingMonitor
inactive
minInterval 5
{
   int towerCount = kbUnitCount(cMyID, gTowerUnit, cUnitStateAlive);
   int planID = -1;

   // =================
   // Now Aztec
   // =================
   int AztecVillager = getUnit(cUnitTypezpSettlerAztec, cPlayerRelationSelf, cUnitStateAlive);
   if (AztecVillager > 0)
   {
      // Check for desired number of farms, estates, and towers. Allow native to build +1 more than we want (via >=)
      int AztecTowerLimit = kbGetBuildLimit(cMyID, cUnitTypezpAztecOutpost);
      int AztecTowerCount = kbUnitCount(cMyID, cUnitTypezpAztecOutpost, cUnitStateABQ);
      if (gNumTowers >= towerCount && AztecTowerCount < AztecTowerLimit)
      {
         planID = createSimpleBuildPlan(cUnitTypezpAztecOutpost, 1, 99, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
         if (AztecVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerAztec, 1, 1, 1);
         }
         else
         {  // Shouldn't ever get here, but just in case
            aiPlanDestroy(planID);
         }
      }

      // The build limit for the water temple is 1, so don't bother looking it up
      int AztecTempleLimit = 1;
      int AztecTempleCount = kbUnitCount(cMyID, cUnitTypezpWaterTemple, cUnitStateABQ);
      if (AztecTempleCount < AztecTempleLimit)
      {
         planID = createSimpleBuildPlan(cUnitTypezpWaterTemple, 1, 99, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
         if (AztecVillager > 0)
         {
            aiPlanAddUnitType(planID, cUnitTypezpSettlerAztec, 1, 1, 1);
         }
         else
         {  // Shouldn't ever get here, but just in case
            aiPlanDestroy(planID);
         }
      }
   }
}

//==============================================================================
// Jewish Building Monitor
//==============================================================================
rule jewishBuildingMonitor
inactive
minInterval 5
{
   int planID = -1;
   int planBID = -1;

   // =================
   // Now Jewish
   // =================
   int jewishVillager = getUnit(cUnitTypezpNatSettlerJewish, cPlayerRelationSelf, cUnitStateAlive);
   if (jewishVillager > 0)
   {
      // The build limit for the Academy is 1, so don't bother looking it up
      if (kbTechGetStatus(cTechzpJewishAcademy) == cTechStatusActive) {
         int AcademyLimit = 1;
         int AcademyCount = kbUnitCount(cMyID, cUnitTypezpAcademy, cUnitStateABQ);
         if (AcademyCount < AcademyLimit)
         {
            planID = createSimpleBuildPlan(cUnitTypezpAcademy, 1, 90, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
            if (jewishVillager > 0)
            {
               aiPlanAddUnitType(planID, cUnitTypezpNatSettlerJewish, 1, 1, 1);
            }
            else
            {  // Shouldn't ever get here, but just in case
               aiPlanDestroy(planID);
            }
         }
      }
      if (kbTechGetStatus(cTechzpJewishEmbassy) == cTechStatusActive) {
         int AmEmbassyLimit = 1;
         int AmEmbassyCount = kbUnitCount(cMyID, cUnitTypezpAmericanEmbassy, cUnitStateABQ);
         if (AmEmbassyCount < AmEmbassyLimit)
         {
            planBID = createSimpleBuildPlan(cUnitTypezpAmericanEmbassy, 1, 90, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 0);
            if (jewishVillager > 0)
            {
               aiPlanAddUnitType(planBID, cUnitTypezpNatSettlerJewish, 1, 1, 1);
            }
            else
            {  // Shouldn't ever get here, but just in case
               aiPlanDestroy(planBID);
            }
         }
      }
   }
}

//==============================================================================
// Submarine Tactics
//==============================================================================
rule submarineTactics
inactive
minInterval 3
{
   int fleetSize = 0;
   int subTactic = cTacticzpSurface;
   int unitID = -1;
   int puid = -1;

   // Stealth mode when subs go on the attack
   if (gNavyAttackPlan > 0)
   {  // Handle the ones on offense if there's an attack going on
      fleetSize = aiPlanGetNumberUnits(gNavyAttackPlan, cUnitTypeAbstractWarShip);
      subTactic = cTacticzpStealth;

      for (i = 0; < fleetSize)
      {
         unitID = aiPlanGetUnitByIndex(gNavyAttackPlan, i);
         puid = kbUnitGetProtoUnitID(unitID);
         if (puid == cUnitTypezpSubmarine || puid == cUnitTypezpNautilus)
         {
            aiUnitSetTactic(unitID, subTactic);
         }
      }
      return;
   }

   // Subs dive if any enemy warships are nearby, otherwise surface
   int shipQuery = createSimpleUnitQuery(cUnitTypeAbstractWarShip, cMyID, cUnitStateAlive);
   int numberShipFound = kbUnitQueryExecute(shipQuery);
   int nearbyEnFound = -1;
   vector shipLoc = cInvalidVector;
   int shipID = -1;
   int psid = -1;

   for (i = 0; < numberShipFound)
   {
      shipID = kbUnitQueryGetResult(shipQuery, i);
      psid = kbUnitGetProtoUnitID(shipID);
      if (psid == cUnitTypezpSubmarine || psid == cUnitTypezpNautilus)
      {
         shipLoc = kbUnitGetPosition(shipID);
         nearbyEnFound = getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia, cUnitStateAlive, shipLoc, 45.0); // Submarine range is 30
         if (nearbyEnFound > 0)
         {
            subTactic = cTacticzpStealth;
            aiUnitSetTactic(shipID, subTactic);
         }
         else
         {
            subTactic = cTacticzpSurface;
            aiUnitSetTactic(shipID, subTactic);
         }
      }
   }
} 

//==============================================================================
// Water Trade Route Sockets
//==============================================================================

rule CaribTPMonitor
inactive
minInterval 22
{
   if ( kbGetAge() <= cAge1 )
   {
      return;
   }

   // AssertiveWall: Set up cooldown
   static int caribTPCooldownTime = -1;
   if (xsGetTime() < (caribTPCooldownTime + gClaimTradeMissionInterval / 2))
   {
      return;
   }
    
    // Set up the query for the socket:
    static int socket_query = -1;
    if ( socket_query == -1 )
    {
        socket_query = kbUnitQueryCreate( "Port Socket Query" );
        kbUnitQuerySetUnitType( socket_query, cUnitTypezpSPCPortSocket );
        kbUnitQuerySetState( socket_query, cUnitStateAlive );
        kbUnitQuerySetIgnoreKnockedOutUnits( socket_query, true );
        kbUnitQuerySetPlayerRelation( socket_query, -1 );
        kbUnitQuerySetPlayerID( socket_query, 0, false );
        kbUnitQuerySetAscendingSort( socket_query, true );
    }
    
    // Set up the query for a builder:
    static int builder_query = -1;
    if ( builder_query == -1 )
    {
        builder_query = kbUnitQueryCreate( "Post Builder Query" );
        kbUnitQuerySetUnitType( builder_query, cUnitTypeHero );
        kbUnitQuerySetState( builder_query, cUnitStateAlive );
        kbUnitQuerySetIgnoreKnockedOutUnits( builder_query, true );
        kbUnitQuerySetPlayerRelation( builder_query, -1 );
        kbUnitQuerySetPlayerID( builder_query, cMyID, false );
    }
    
    // Erase all the information we got from any previous search:
    kbUnitQueryResetResults( socket_query );
    kbUnitQueryResetResults( builder_query );
    
    // Start a new search and memorize the number of units found:
    int num_builders = kbUnitQueryExecute( builder_query );
    
    if ( num_builders == 0 )
        return; // No point going further since there is no alive builder
    
    // If we're here, it's because at least one alive builder has been found.
    
    // Find a builder:
    int builder = kbUnitQueryGetResult( builder_query, aiRandInt( num_builders ) );
    
    // Determine its position on the terrain:
    vector builder_position = kbUnitGetPosition( builder );
    
    // Find a socket that the builder can reach **without** transport:
    kbUnitQuerySetPosition( socket_query, builder_position );
    kbUnitQuerySetMaximumDistance( socket_query, 5000.0 );
    int builder_areagroup = kbAreaGroupGetIDByPosition( builder_position );
    int num_sockets = kbUnitQueryExecute( socket_query );
    
    if ( num_sockets == 0 )
        return; // No point going further since no socket has been found (maybe under blackmap)
    
    // If we're here, it's because at least one socket has been found (thanks to the scouts)
    
    int socket = -1;
    int bestSocketValue = -1;
    int tempSocket = -1;
    int tempSocketValue = 0;
    int hbSocket = -1;
    bool hbBool = false;
    for( i = 0; < num_sockets )
    {
      tempSocketValue = 0;
      tempSocket = kbUnitQueryGetResult( socket_query, i );
      vector socket_position = kbUnitGetPosition( tempSocket );
      // See if it's already occupied:
      if ( getUnitCountByLocation( cUnitTypeTradingPost, cPlayerRelationAny, cUnitStateABQ, socket_position, 10.0) >= 1 )
      {
         continue; // Yes. Well, ignore it and find the next...
      }
            
      if ( kbAreaGroupGetIDByPosition( socket_position ) == builder_areagroup )
      {
         // This socket is reachable without transport
         tempSocketValue += 2;
      }
      else
      {  // In the event that out builder is away from home base, store the home base socket
         if ( kbAreaGroupGetIDByPosition( kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)) ) != builder_areagroup &&
              kbAreaGroupGetIDByPosition( kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)) ) == kbAreaGroupGetIDByPosition( socket_position ))
         {
            if (hbSocket < 0)
            {
               hbSocket = tempSocket;
            }
         }
         continue;
      }

      if (distance(socket_position, builder_position) < 50)
      {
         tempSocketValue += 3;
      }
      else if (distance(socket_position, builder_position) < 100)
      {
         tempSocketValue += 2;
      }
      else if (distance(socket_position, builder_position) < 200)
      {
         tempSocketValue += 1;
      }

      if (tempSocketValue > bestSocketValue)
      {
         socket = tempSocket;
         bestSocketValue = tempSocketValue;
      }
    }

   // AssertiveWall: Check to make sure we found one
    if (socket < 0)
    {
      // AssertiveWall: if we have a hbSocket use that one
      if (hbSocket > 0)
      {
         builder = getClosestUnitByLocation(gEconUnit, cPlayerRelationSelf, cUnitStateAlive, kbUnitGetPosition(socket)); 
         socket = hbSocket;
      }
      else
      {
         return;
      }
    }
    
    static int build_plan = -1;
    
    if ( aiPlanGetState( build_plan ) == -1 )
    {
        aiPlanDestroy( build_plan );
        build_plan = aiPlanCreate( "BuildCaribTP", cPlanBuild );
        aiPlanSetDesiredPriority( build_plan, 95 );  // down from 100
        aiPlanSetDesiredResourcePriority( build_plan, 50 );  // added july 10th
        aiPlanSetEscrowID( build_plan, cEmergencyEscrowID );
        aiPlanSetVariableInt( build_plan, cBuildPlanBuildUnitID, 0, builder );
        aiPlanAddUnitType( build_plan, kbUnitGetProtoUnitID( builder ), 1, 1, 1 );
        aiPlanAddUnit( build_plan, builder );
        aiPlanSetVariableInt( build_plan, cBuildPlanBuildingTypeID, 0, cUnitTypeTradingPost );
        aiPlanSetVariableInt( build_plan, cBuildPlanSocketID, 0, socket );
        aiPlanSetActive( build_plan, true );
    }

    if (build_plan > 0)
    {
      caribTPCooldownTime = xsGetTime();
    }
    
}

//==============================================================================
// Maintain Proxies in Pirate Trading Posts
//==============================================================================

rule MaintainPirateShips
inactive
minInterval 30
{
  const int list_size = 4;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketPirates, cUnitStateAny) == 0)
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Pirate Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Pirate Ships");

    xsArraySetInt(proxy_list, 0, cUnitTypezpPrivateerProxy);
    xsArraySetInt(ship_list, 0, cUnitTypePrivateer);

    xsArraySetInt(proxy_list, 1, cUnitTypezpSPCQueenAnneProxy);
    xsArraySetInt(ship_list, 1, cUnitTypezpSPCQueenAnne);

    xsArraySetInt(proxy_list, 2, cUnitTypezpSPCBlackPearlProxy);
    xsArraySetInt(ship_list, 2, cUnitTypezpSPCBlackPearl);

    xsArraySetInt(proxy_list, 3, cUnitTypezpSPCNeptuneGalleyProxy);
    xsArraySetInt(ship_list, 3, cUnitTypezpSPCNeptuneGalley);
  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);
    
    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// maintain Jewish Settlers
//==============================================================================
rule maintainJewishSettlers
inactive
minInterval 60
{
   static int jewishPlan = -1;

   if (kbUnitCount(cMyID, cUnitTypezpSocketJewish, cUnitStateAny) == 0)
   {
      return;
   }

   // Check build limit.
   int buildLimit = kbGetBuildLimit(cMyID, cUnitTypezpNatSettlerJewish);

   if (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1)
   {
      buildLimit = 0;
   }

   // Create/update maintain plan
   if ((jewishPlan < 0) && (buildLimit >= 1))
   {
      jewishPlan = createSimpleMaintainPlan(cUnitTypezpNatSettlerJewish, buildLimit, true, kbBaseGetMainID(cMyID), 1);
   }
   else
   {
      aiPlanSetVariableInt(jewishPlan, cTrainPlanNumberToMaintain, 0, buildLimit);
   }
}

//==============================================================================
// Maintain Proxies in Wokou Trading Posts
//==============================================================================

rule MaintainWokouShips
inactive
minInterval 30
{
  const int list_size = 2;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketWokou, cUnitStateAny) == 0)
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Wokou Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Wokou Ships");

    xsArraySetInt(proxy_list, 0, cUnitTypezpWokouJunkProxy);
    xsArraySetInt(ship_list, 0, cUnitTypeypWokouJunk);

    xsArraySetInt(proxy_list, 1, cUnitTypezpWokouFuchuanProxy);
    xsArraySetInt(ship_list, 1, cUnitTypezpWokouFuchuan);

  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);
    
    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// Sufi Big Button Monitor
//==============================================================================
rule SufiBigButtonMonitor
inactive
mininterval 60
{
   if ( kbGetAge() <= cAge2 )
   return; // Not until Fortress Age

   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 12)
    {
        return; // Avoid getting upgrades here with a weak economy.
    }


   if (kbUnitCount(0, cUnitTypezpSPCGreatMosque, cUnitStateAny) >= 1)
    {
        // Upgrade Great Mosque on Asian Maps
        bool canDisableSelf = researchSimpleTech(cTechzpSPCSufiGreatMosque, cUnitTypeTradingPost);

    }

   if (kbUnitCount(0, cUnitTypezpSPCBlueMosque, cUnitStateAny) >= 1)
    {
        // Upgrade Blue Mosque on Middle-East Maps
        canDisableSelf = researchSimpleTech(cTechzpSPCSufiBlueMosque, cUnitTypeTradingPost);
    }
   
   if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
}

//==============================================================================
// Zen Big Button Monitor
//==============================================================================
rule ZenBigButtonMonitor
inactive
mininterval 60
{
   if ( kbGetAge() <= cAge2 )
   return; // Not until Fortress Age

   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 12)
      {
          return; // Avoid getting upgrades here with a weak economy.
      }
  
      // Upgrade Great Buddha
      bool canDisableSelf = researchSimpleTech(cTechzpSPCZenBuddha, cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Native Aztec Big Button Monitor
//==============================================================================
rule zpNativeAztecBigButtonMonitor
inactive
mininterval 60
{
   if ( kbGetAge() <= cAge2 )
   return; // Not until Fortress Age

   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 12)
      {
          return; // Avoid getting upgrades here with a weak economy.
      }
  
   if (kbUnitCount(0, cUnitTypezpNativeAztecTempleA, cUnitStateAny) >= 1)
    {
        // Upgrade Aztec Temple
        bool canDisableSelf = researchSimpleTech(cTechzpNatAztecInfluence, cUnitTypeTradingPost);
    }

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// maintain Sufi Settlers
//==============================================================================
rule maintainSufiSettlers
inactive
minInterval 60
{
   static int sufiSettlerPlan = -1;

   if (kbUnitCount(cMyID, cUnitTypezpSocketSPCSufi, cUnitStateAny) == 0)
   {
      return;
   }

  if (kbTechGetStatus(cTechzpSPCSufiGreatMosque) == cTechStatusActive)  // Sufi Villagers foe Asian Maps
    {
      // Check build limit.
      int buildLimit = kbGetBuildLimit(cMyID, cUnitTypezpSettlerSufi);

      if (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1)
      {
          buildLimit = 0;
      }

      // Create/update maintain plan
      if ((sufiSettlerPlan < 0) && (buildLimit >= 1))
      {
          sufiSettlerPlan = createSimpleMaintainPlan(cUnitTypezpSettlerSufi, buildLimit, true, kbBaseGetMainID(cMyID), 1);
      }
      else
      {
          aiPlanSetVariableInt(sufiSettlerPlan, cTrainPlanNumberToMaintain, 0, buildLimit);
      }
    }
}

//==============================================================================
// maintain Sufi Bedouins
//==============================================================================
rule maintainSufiBedouins
inactive
minInterval 60
{
   static int sufiSettlerPlan = -1;

   if (kbUnitCount(cMyID, cUnitTypezpSocketSPCSufi, cUnitStateAny) == 0)
   {
      return;
   }

   if (kbTechGetStatus(cTechzpSPCSufiBlueMosque) == cTechStatusActive) // Sufi Bedouins for Middle-East Maps
    {
      // Check build limit.
      int buildLimit = kbGetBuildLimit(cMyID, cUnitTypezpSettlerSufiB);

      if (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1)
      {
          buildLimit = 0;
      }

      // Create/update maintain plan
      if ((sufiSettlerPlan < 0) && (buildLimit >= 1))
      {
          sufiSettlerPlan = createSimpleMaintainPlan(cUnitTypezpSettlerSufiB, buildLimit, true, kbBaseGetMainID(cMyID), 1);
      }
      else
      {
          aiPlanSetVariableInt(sufiSettlerPlan, cTrainPlanNumberToMaintain, 0, buildLimit);
      }
    }
}

//==============================================================================
// maintain Zen Villagers
//==============================================================================
rule maintainZenSettlers
inactive
minInterval 60
{
   static int zenSettlerPlan = -1;

   if (kbUnitCount(cMyID, cUnitTypezpSocketSPCZen, cUnitStateAny) == 0)
   {
      return;
   }

   if (kbTechGetStatus(cTechzpSPCZenBuddha) == cTechStatusActive)
    {
      // Check build limit.
      int buildLimit = kbGetBuildLimit(cMyID, cUnitTypezpSettlerZen);

      if (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1)
      {
          buildLimit = 0;
      }

      // Create/update maintain plan
      if ((zenSettlerPlan < 0) && (buildLimit >= 1))
      {
          zenSettlerPlan = createSimpleMaintainPlan(cUnitTypezpSettlerZen, buildLimit, true, kbBaseGetMainID(cMyID), 1);
      }
      else
      {
          aiPlanSetVariableInt(zenSettlerPlan, cTrainPlanNumberToMaintain, 0, buildLimit);
      }
    }
}

//==============================================================================
// maintain Aztec Villagers
//==============================================================================
rule zpMaintainAztecNativeVillagers
inactive
minInterval 60
{
   static int aztecSettlerPlan = -1;

   if (kbUnitCount(cMyID, cUnitTypeSocketAztec, cUnitStateAny) == 0)
   {
      return;
   }

   if (kbTechGetStatus(cTechzpNatAztecInfluence) == cTechStatusActive)
    {
      // Check build limit.
      int buildLimit = kbGetBuildLimit(cMyID, cUnitTypezpSettlerAztec);

      if (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1)
      {
          buildLimit = 0;
      }

      // Create/update maintain plan
      if ((aztecSettlerPlan < 0) && (buildLimit >= 1))
      {
          aztecSettlerPlan = createSimpleMaintainPlan(cUnitTypezpSettlerAztec, buildLimit, true, kbBaseGetMainID(cMyID), 1);
      }
      else
      {
          aiPlanSetVariableInt(aztecSettlerPlan, cTrainPlanNumberToMaintain, 0, buildLimit);
      }
    }
}

//==============================================================================
// Pirate Tech Monitor
//==============================================================================
rule PirateTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketPirates, cUnitStateAny) == 0)
      {
      return; // Player has no pirate socket.
      }


      // Upgrade Privateers
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpNatBlackSails,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypePrivateer, cUnitStateABQ) >= 3); },
      cUnitTypeTradingPost);

      // Black Caesar Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatPirateCorsairs,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulatePiratesBlackCaesar) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Blackbeard Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatPirateAdmiral,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulatePiratesBlackbeard) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Grace Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatPirateRecruits,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulatePiratesGrace) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Wokou Tech Monitor
//==============================================================================
rule WokouTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketWokou, cUnitStateAny) == 0)
      {
      return; // Player has no Wokou socket.
      }


      // Cheaper Wokou Junks
      bool canDisableSelf = researchSimpleTech(cTechzpWokouCheapShipyard, cUnitTypeTradingPost);

      // Sao Feng Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatTreasureFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWokouSaoFeng) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Takanobu Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpWokouRandomShip,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWokouTakanobu) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Ching Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatIronFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWokouMadameChing) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Sufi Tech Monitor
//==============================================================================
rule SufiTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketSPCSufi, cUnitStateAny) == 0)
      {
      return; // Player has no Sufi socket.
      }

      // Sufi Castle
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpSPCSufiCastle,
      []() -> bool { return (((kbTechGetStatus(cTechzpSPCSufiBlueMosque) == cTechStatusActive) || (kbTechGetStatus(cTechzpSPCSufiGreatMosque) == cTechStatusActive)) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // White Fort Starfort
      canDisableSelf &= researchSimpleTechByCondition(cTechzpStarWhiteFort,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypezpWhiteFort, cUnitStateABQ) >= 1) && ( kbGetAge() >= cAge4 )); },
      cUnitTypezpWhiteFort);

      // White Fort revement
      canDisableSelf &= researchSimpleTechByCondition(cTechzpWhiteFortRevetment,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypezpWhiteFort, cUnitStateABQ) >= 1) && ( kbGetAge() >= cAge4 )); },
      cUnitTypezpWhiteFort);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Zen Tech Monitor
//==============================================================================
rule ZenTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketSPCZen, cUnitStateAny) == 0)
      {
      return; // Player has no Zen socket.
      }

      // Zen Castle
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpSPCZenCastle,
      []() -> bool { return ((kbTechGetStatus(cTechzpSPCZenBuddha) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Fortified Monastery
      canDisableSelf &= researchSimpleTechByCondition(cTechzpFortifiedMonastery,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypezpCastleZen, cUnitStateABQ) >= 1) || (kbUnitCount(cMyID, cUnitTypezpCastleZenClone, cUnitStateABQ) >= 1)); },
      cUnitTypezpCastleZen);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Suf White Fort
//==============================================================================

rule SufiWhiteFortManager
inactive
minInterval 30
{
   if (aiTreatyActive() == true)
   {
      return;
   }

   int fortUnitID = -1;
   int buildingQuery = -1;
   int numberFound = 0;
   int numberMilitaryBuildings = 0;
   int buildingID = -1;
   int availableFortWagon = findWagonToBuild(cUnitTypezpWhiteFort);

   // We have a Fort Wagon but also already have a forward base, default the Fort position.
   if ((availableFortWagon >= 0) && (gForwardBaseState != cForwardBaseStateNone))
   {
      createSimpleBuildPlan(cUnitTypezpWhiteFort, 1, 87, true, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
      return;
   }

   switch (gForwardBaseState)
   {
      case cForwardBaseStateNone:
      {
         // We don't have a forward base, if we have a suitable Wagon we can start the chain.
         vector location = cInvalidVector;
         if (availableFortWagon > 0) // AssertiveWall: changed from >=0
         {
            // Get the Fort Wagon, start a build plan, if we go forward we try to defend it.
            //vector location = cInvalidVector;  AssertiveWall: moved up above
   
            if ((btOffenseDefense >= 0.0) && (cDifficultyCurrent >= cDifficultyModerate))
            {
               location = selectForwardBaseLocation();
            }
   
            if (location == cInvalidVector)
            {
               createSimpleBuildPlan(cUnitTypezpWhiteFort, 1, 87, true, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
               return;
            }
   
            gForwardBaseLocation = location;
            gForwardBaseBuildPlan = aiPlanCreate("Fort build plan ", cPlanBuild);
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanBuildingTypeID, 0, cUnitTypezpWhiteFort);
            aiPlanSetDesiredPriority(gForwardBaseBuildPlan, 87);
            aiPlanAddUnitType(gForwardBaseBuildPlan, cUnitTypeFortWagon, 1, 1, 1);
   
            // Instead of base ID or areas, use a center position.
            aiPlanSetVariableVector(gForwardBaseBuildPlan, cBuildPlanCenterPosition, 0, location);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanCenterPositionDistance, 0, 50.0);
   
            // Weigh it to stay very close to center point.
            aiPlanSetVariableVector(gForwardBaseBuildPlan, cBuildPlanInfluencePosition, 0, location);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluencePositionDistance, 0, 50.0); // 100m range.
            // 100 Points for center.
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluencePositionValue, 0, 100.0); 
            // Linear slope falloff.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); 
   
            // Add position influence for nearby Forts.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitTypeID, 0, cUnitTypezpWhiteFort); 
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitDistance, 0, 50.0);
            aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitValue, 0, -200.0); // -200 points per fort
            // Cliff falloff.
            aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffNone); 
   
            // AssertiveWall: Add position influence for forts building near docks on island maps
            if (gStartOnDifferentIslands == true)
            {
               aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitTypeID, 0, gDockUnit); 
               aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitDistance, 0, 30.0);
               aiPlanSetVariableFloat(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitValue, 0, 20.0); // 20 points per dock
               aiPlanSetVariableInt(gForwardBaseBuildPlan, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffLinear); 
            }

            aiPlanSetActive(gForwardBaseBuildPlan);
   
            // Chat to my allies.
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, gForwardBaseLocation);
   
            gForwardBaseState = cForwardBaseStateBuilding;
            debugBuildings("");
            debugBuildings("BUILDING FORWARD BASE, MOVING DEFEND PLANS TO COVER");
            debugBuildings("PLANNED LOCATION IS " + gForwardBaseLocation);
            debugBuildings("");
   
            if (gDefenseReflex == false)
            {
               endDefenseReflex(); // Causes it to move to the new location.
            }
         }
         break;
      }
      case cForwardBaseStateBuilding:
      {
         fortUnitID = getUnitByLocation(cUnitTypezpWhiteFort, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
         if (fortUnitID < 0)
         {
            // Check for other military buildings.
            buildingQuery = createSimpleUnitQuery(cUnitTypeMilitaryBuilding, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
            numberFound = kbUnitQueryExecute(buildingQuery);
            numberMilitaryBuildings = xsArrayGetSize(gMilitaryBuildings);
            for (i = 0; < numberFound)
            {
               buildingID = kbUnitQueryGetResult(buildingQuery, i);
               for (j = 0; < numberMilitaryBuildings)
               {
                  if (kbUnitIsType(buildingID, xsArrayGetInt(gMilitaryBuildings, j)) == true)
                  {
                     fortUnitID = buildingID;
                     break;
                  }
               }
               if (fortUnitID >= 0)
               {
                  break;
               }
            }
         }
         if (fortUnitID >= 0)
         { // Building exists and is complete, go to state Active.
            if (kbUnitGetBaseID(fortUnitID) >= 0)
            { // Base has been created for it.
               // AssertiveWall: Now build wall
               if (gStartOnDifferentIslands == false)
               {
                  xsEnableRule("forwardBaseWall"); // AssertiveWall: Chain of rules to build walls and towers
               }
               gForwardBaseState = cForwardBaseStateActive;
               gForwardBaseID = kbUnitGetBaseID(fortUnitID);
               gForwardBaseLocation = kbUnitGetPosition(fortUnitID);
               gForwardBaseUpTime = xsGetTime();
               gForwardBaseShouldDefend = kbUnitIsType(fortUnitID, cUnitTypezpWhiteFort);
               debugBuildings("Forward base location is " + gForwardBaseLocation + ", Base ID is " + 
                  gForwardBaseID + ", Unit ID is " + fortUnitID);
               debugBuildings("");
               debugBuildings("FORWARD BASE COMPLETED, GOING TO STATE ACTIVE");
               debugBuildings("");
            }
            else
            {
               debugBuildings("");
               debugBuildings("FORT COMPLETE, WAITING FOR FORWARD BASE ID");
               debugBuildings("");
            }
         }
         else // Check if plan still exists. If not, go back to state 'none'.
         {
            if (aiPlanGetState(gForwardBaseBuildPlan) < 0)
            { // It failed?
               gForwardBaseState = cForwardBaseStateNone;
               gForwardBaseLocation = cInvalidVector;
               gForwardBaseID = -1;
               gForwardBaseBuildPlan = -1;
               gForwardBaseShouldDefend = false;
               debugBuildings("");
               debugBuildings("FORWARD BASE PLAN FAILED, RETURNING TO STATE NONE");
               debugBuildings("");
            }
         }
         break;
      }
      case cForwardBaseStateActive:
      { // Normal state. If fort is destroyed and base overrun, bail.
         fortUnitID = getUnitByLocation(cUnitTypezpWhiteFort, cMyID, cUnitStateAlive, gForwardBaseLocation, 50.0);
         if (fortUnitID < 0)
         {
            // Check for other military buildings.
            buildingQuery = createSimpleUnitQuery(cUnitTypeMilitaryBuilding, cMyID, cUnitStateAlive, gForwardBaseLocation, 100.0);
            numberFound = kbUnitQueryExecute(buildingQuery);
            numberMilitaryBuildings = xsArrayGetSize(gMilitaryBuildings);
            for (i = 0; < numberFound)
            {
               buildingID = kbUnitQueryGetResult(buildingQuery, i);
               for (j = 0; < numberMilitaryBuildings)
               {
                  if (kbUnitIsType(buildingID, xsArrayGetInt(gMilitaryBuildings, j)) == true)
                  {
                     fortUnitID = buildingID;
                     break;
                  }
               }
               if (fortUnitID >= 0)
               {
                  break;
               }
            }
         }
         if (fortUnitID < 0)
         {
            // Fort is missing, is base still OK?
            if (((gDefenseReflexBaseID == gForwardBaseID) && (gDefenseReflexPaused == true)) ||
               (kbBaseGetNumberUnits(cMyID, gForwardBaseID, cPlayerRelationSelf, cUnitTypeBuilding) < 1)) 
            {  // No, not OK. Get outa Dodge.
               gForwardBaseState = cForwardBaseStateNone;
               gForwardBaseID = -1;
               gForwardBaseLocation = cInvalidVector;
               gForwardBaseShouldDefend = false;

               endDefenseReflex();
               debugBuildings("");
               debugBuildings("ABANDONING FORWARD BASE, RETREATING TO MAIN BASE");
               debugBuildings("");
            }
         }
         break;
      }
   }
}

//==============================================================================
// Native Wagon Monitor
//==============================================================================
rule nativeWagonMonitor
inactive
minInterval 15
{
   int wagonQueryID = createSimpleUnitQuery(cUnitTypeAbstractWagon, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(wagonQueryID);
   if (numberFound == 0)
   {
      debugBuildings("We didn't find any idle Wagons without a Build Plan");
      return;
   }
   
   int planID = -1;
   int numPlans = aiPlanGetActiveCount();
   int wagonType = -1;
   int wagon = -1;
   int age = kbGetAge();
   int mainBaseID = kbBaseGetMainID(cMyID);
   int buildLimit = -1;
   int buildingCount = -1;
   int buildingType = -1;

  
   // Pick up idle Wagons and let them train something on their own without existing Build Plans.
   for (i = 0; < numberFound)
   {
      wagon = kbUnitQueryGetResult(wagonQueryID, i);
      if (kbUnitGetPlanID(wagon) >= 0)
      {
         continue;
      }
      wagonType = kbUnitGetProtoUnitID(wagon);
      buildingType = -1;

      debugBuildings("Idle Wagon's name is: " + kbGetProtoUnitName(wagonType) + " with ID: " + wagon);

      switch (wagonType)
      {
      // Vanilla.
         case cUnitTypezpSPCCastleWagon:
         {
            if (kbTechGetStatus(cTechzpMountainZen) == cTechStatusActive)
               buildingType = cUnitTypezpCastleZenClone;
            else
               buildingType = cUnitTypezpCastleZen;
             break;
         }
         case cUnitTypezpWaterTempleTravois:
         {
             buildingType = cUnitTypezpWaterTemple;
             break;
         }
         case cUnitTypezpAmericanEmbassyWagon:
         {
             buildingType = cUnitTypezpAmericanEmbassy;
             break;
         }
         case cUnitTypezpAcademyWagon:
         {
             buildingType = cUnitTypezpAcademy;
             break;
         }
         case cUnitTypezpDryDockWagon:
         {
             buildingType = cUnitTypezpDrydock;
             break;
         }
         case cUnitTypezpVeniceEmbassyWagon:
         {
             buildingType = cUnitTypezpVeniceEmbassy;
             break;
         }
         case cUnitTypezpWaterFortBuilder:
         {
            buildingType = cUnitTypezpWaterFort;
            break;
         }
         case cUnitTypezpWorkshopWagon:
         {
            buildingType = cUnitTypezpWorkshop;
         }
         case cUnitTypezpMountainCitadelWagon:
         {
            buildingType = cUnitTypezpMountainCitadel;
         }
         case cUnitTypezpSheriffWagon:
         {
            buildingType = cUnitTypezpSheriffOffice;
         }
         case cUnitTypezpGunStoreWagon:
         {
            buildingType = cUnitTypezpGunStore;
         }
      }

      if (buildingType < 0) // Didn't find a building so go to the next iteration.
      {
         continue;
      }

      // Are we on build limit?
      buildLimit = kbGetBuildLimit(cMyID, buildingType);
      if (buildLimit >= 1)
      {
         buildingCount = kbUnitCount(cMyID, buildingType, cUnitStateABQ) +
                         aiPlanGetNumberByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, buildingType, true);
         if (buildingCount >= buildLimit)
         {
            continue; // We can't make this building anymore so go to the next iteration.
         }
      }

      // Need a different placement for the water fort. Just use the location build plan
      if (buildingType == cUnitTypezpWaterFort)
      {
         // Find a random point near gNavyVec
         vector location = gNavyVec;
         float xRange = 0;
         float zRange = 0;
         int randMinus = 1;
         int minRange = 20 + aiRandInt(20);
         for (j = 1; < 100)
         {  
            xRange = randMinus * (abs(xRange) + 1);
            if (aiRandInt(4) > 2)
            {
               randMinus = -1 * randMinus;
            }
            zRange = randMinus * (abs(zRange) + 1);

            location = xsVectorSetX(location, xsVectorGetX(location) + xRange);
            location = xsVectorSetZ(location, xsVectorGetZ(location) + zRange);
            if (distance(gNavyVec, location) > minRange)
            {
               break;
            }
         }
         
         // Create the build plan
         planID = createLocationBuildPlan(buildingType, 1, 100, true, -1, location, 0);
         aiPlanAddUnitType(planID, wagonType, 1, 1, 1);
         aiPlanAddUnit(planID, wagon);
         return;
      }

      // AssertiveWall: wagon plan doesn't have an escrow, and skips queue
      planID = createSimpleBuildPlan(buildingType, 1, 75, true, -1, mainBaseID, 0, -1, true);
      aiPlanAddUnitType(planID, wagonType, 1, 1, 1);
      aiPlanAddUnit(planID, wagon);

      debugBuildings("FAILSAFE: Added an idle " + kbGetProtoUnitName(kbUnitGetProtoUnitID(wagon)) + 
         " with ID: " + wagon + " to a new Build Plan ID: " + planID);
   }
}

//==============================================================================
// ZP Aztec Tech Monitor
//==============================================================================
rule zpAztecTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypeSocketAztec, cUnitStateAny) == 0)
      {
      return; // Player has no Aztec socket.
      }

      // Aztec Water Temple
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpAztecWaterTemple,
      []() -> bool { return ((kbTechGetStatus(cTechzpNatAztecInfluence) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);


  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// ZP Scientist Tech Monitor
//==============================================================================
rule zpScientistTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
      {
      return; // Player has no Scientist socket.
      }

      // Scientist Academy
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpScientistsAcademy,
      []() -> bool { return (kbGetAge() >= cAge3 ); },
      cUnitTypeTradingPost);

      canDisableSelf = researchSimpleTech(cTechzpScientistsBaloons, cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpScientistIronFleet,
      []() -> bool { return (kbGetAge() >= cAge2 ); },,
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpImperialSubmarine,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistNemo) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpSubmarineFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistNemo) == cTechStatusActive) && ( kbGetAge() >= cAge4 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpIronTanks,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistValentine) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpTankBattalion,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistValentine) == cTechStatusActive) && ( kbGetAge() >= cAge4 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpBattleAirship,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistkhora) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpMustardGas,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistkhora) == cTechStatusActive) && ( kbGetAge() >= cAge4 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpArmoredTrainTech,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistGortz) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpArmoredTrainImprove,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateScientistGortz) == cTechStatusActive) && ( kbGetAge() >= cAge4 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Maintain Submarine Proxies in Scientist Trading Post
//==============================================================================

rule MaintainScientistShips
inactive
minInterval 30
{
  const int list_size = 3;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Scientist Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Scientist Ships");

    xsArraySetInt(proxy_list, 0, cUnitTypezpSubmarineProxy);
    xsArraySetInt(ship_list, 0, cUnitTypezpSubmarine);

    xsArraySetInt(proxy_list, 1, cUnitTypezpWokouSteamerProxy);
    xsArraySetInt(ship_list, 1, cUnitTypezpWokouSteamer);

    xsArraySetInt(proxy_list, 2, cUnitTypezpNautilusProxy);
    xsArraySetInt(ship_list, 2, cUnitTypezpNautilus);
  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);
    
    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// Maintain Tanks in Scientist Trading Post
//==============================================================================

rule MaintainScientistTanks
inactive
minInterval 30
{
  const int list_size = 1;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Scientist Tank Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Scientist Tanks");

    xsArraySetInt(proxy_list, 0, cUnitTypezpIronTank);
    xsArraySetInt(ship_list, 0, cUnitTypezpIronTank);
  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);

    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = -1;
    int militaryPopPercentage = btBiasNative * 10 + 10;

   if (kbGetAge() <= cAge4)
   {
      // Resource equivalent to 0-20% of our military pop, same as native warriors
      number_to_maintain = (aiGetMilitaryPop() * militaryPopPercentage) / (kbUnitCostPerResource(proxy, cResourceGold) +
                                                                        kbUnitCostPerResource(proxy, cResourceWood) +
                                                                        kbUnitCostPerResource(proxy, cResourceFood));
   }
   else
   {
      number_to_maintain = kbGetBuildLimit(cMyID, ship);
   }

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// ZP Inuit Tech Monitor
//==============================================================================
rule zpInuitTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketInuits, cUnitStateAny) == 0)
      {
      return; // Player has no Inuit socket.
      }

      // Inuit Influence
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpNatInuitInfluence,
      []() -> bool { return (kbGetAge() >= cAge2 ); },
      cUnitTypeTradingPost);

      // Inuit Umiaks
      canDisableSelf &= researchSimpleTechByCondition(cTechzpInuitUmiaks,
      []() -> bool { return ((kbTechGetStatus(cTechzpNatInuitInfluence) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Inuit Aurora
      canDisableSelf &= researchSimpleTechByCondition(cTechzpInuitFriends,
      []() -> bool { return ((kbTechGetStatus(cTechzpNatInuitInfluence) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// ZP Maltese Tech Monitor
//==============================================================================
rule zpMalteseTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketMaltese, cUnitStateAny) == 0)
      {
      return; // Player has no Maltese socket.
      }

      // Maltese Venetians
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpNatMalteseExplorationFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseVenetians) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatMalteseExpeditionaryFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseVenetians) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Maltese Florentians
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatMalteseBanking,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseFlorentians) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatMalteseFactory,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseFlorentians) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Maltese Jerusalem
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatMalteseFort,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseJerusalem) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatMalteseOutposts,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseJerusalem) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Maltese Central Europe
      canDisableSelf &= researchSimpleTechByCondition(cTechzpMalteseMarksmen,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseCentralEuropeans) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpMalteseCannons,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateMalteseCentralEuropeans) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// Maintain Airship in Scientist Trading Post
//==============================================================================

rule MaintainScientistAirship
inactive
minInterval 10
{
  const int list_size = 1;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
   {
      return;
   }

   if ( kbGetAge() <= cAge2 )
   {
      return;
   }
      if (proxy_list == -1)
      {
         proxy_list = xsArrayCreateInt(list_size, -1, "List of Scientist Airship Proxies");
         ship_list = xsArrayCreateInt(list_size, -1, "List of Scientist Airships");

         xsArraySetInt(proxy_list, 0, cUnitTypezpAirshipAIProxy);
         xsArraySetInt(ship_list, 0, cUnitTypezpAirshipAI);
      }

      for(i = 0; < xsArrayGetSize(proxy_list))
      {
         int proxy = xsArrayGetInt(proxy_list, i);
         int ship = xsArrayGetInt(ship_list, i);
         
         int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
         int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

         if (maintain_plan == -1)
         {
            if (kbProtoUnitAvailable(proxy) == true)
            {
            maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
            aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
            aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
            aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
            aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
            aiPlanSetActive(maintain_plan, true);
            }
         }
         else
         {
            if (kbProtoUnitAvailable(proxy) == true)
            {
            aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
            }
            else
            {
            aiPlanDestroy(maintain_plan);
            }
         }
      
   }
}

//==============================================================================
// Jesuit Tech Monitor
//==============================================================================
rule zpJesuitTechMonitor
inactive
mininterval 60
{
   if ((kbUnitCount(cMyID, cUnitTypezpSocketJesuit, cUnitStateAny) == 0) && (kbUnitCount(cMyID, cUnitTypezpSocketJesuitEU, cUnitStateAny) == 0))
      {
      return; // Player has no Jesuit socket.
      }

      // Jesuit Big Button
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpJesuitCathedral,
      []() -> bool { return (kbGetAge() >= cAge2 ); },
      cUnitTypeTradingPost);

      // Jesuit Tank
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatJesuitTank,
      []() -> bool { return ((kbTechGetStatus(cTechzpJesuitCathedral) == cTechStatusActive) && ( kbGetAge() >= cAge4 )); },
      cUnitTypeTradingPost);

      // Jesuit Native Armies
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatJesuitArmory,
      []() -> bool { return ((kbTechGetStatus(cTechzpJesuitCathedral) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// maintain Jesuit Missionaries
//==============================================================================
rule maintainJesuitMissionary
inactive
minInterval 60
{
  
  const int list_size = 1;
  static int proxy_list = -1;
  static int ship_list = -1;

  if ((kbUnitCount(cMyID, cUnitTypezpSocketJesuit, cUnitStateAny) == 0) && (kbUnitCount(cMyID, cUnitTypezpSocketJesuitEU, cUnitStateAny) == 0))
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Missionary Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Missionaries");

    xsArraySetInt(proxy_list, 0, cUnitTypezpPriestProxy);
    xsArraySetInt(ship_list, 0, cUnitTypezpPriest);
  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);
    
    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// Maintain Proxies in Venetian Trading Posts
//==============================================================================

rule MaintainVeniceShips
inactive
minInterval 30
{
  const int list_size = 2;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketVenetians, cUnitStateAny) == 0)
   {
      return;
   }

  if (proxy_list == -1)
  {
    proxy_list = xsArrayCreateInt(list_size, -1, "List of Venice Proxies");
    ship_list = xsArrayCreateInt(list_size, -1, "List of Venice Ships");

    xsArraySetInt(proxy_list, 0, cUnitTypezpVeniceGalleyProxy);
    xsArraySetInt(ship_list, 0, cUnitTypezpVeniceGalley);

    xsArraySetInt(proxy_list, 1, cUnitTypezpGalleassProxy);
    xsArraySetInt(ship_list, 1, cUnitTypezpGalleass);

  }

  for(i = 0; < xsArrayGetSize(proxy_list))
  {
    int proxy = xsArrayGetInt(proxy_list, i);
    int ship = xsArrayGetInt(ship_list, i);
    
    int maintain_plan = aiPlanGetIDByTypeAndVariableType(cPlanTrain, cTrainPlanUnitType, proxy, true);
    int number_to_maintain = kbGetBuildLimit(cMyID, ship) - kbUnitCount(cMyID, ship);

    if (maintain_plan == -1)
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        maintain_plan = aiPlanCreate("Maintain " + kbGetProtoUnitName(proxy), cPlanTrain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanUnitType, 0, proxy);
        aiPlanSetVariableBool(maintain_plan, cTrainPlanUseMultipleBuildings, 0, false);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
        aiPlanSetVariableInt(maintain_plan, cTrainPlanBatchSize, 0, 1);
        aiPlanSetActive(maintain_plan, true);
      }
    }
    else
    {
      if (kbProtoUnitAvailable(proxy) == true)
      {
        aiPlanSetVariableInt(maintain_plan, cTrainPlanNumberToMaintain, 0, number_to_maintain);
      }
      else
      {
        aiPlanDestroy(maintain_plan);
      }
    }
  }
}

//==============================================================================
// Venice Tech Monitor
//==============================================================================
rule VeniceTechMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketVenetians, cUnitStateAny) == 0)
      {
      return; // Player has no venice socket.
      }


      // Upgrade Ships and Cannons
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpVeniceBetterShips,
      []() -> bool { return ( kbGetAge() >= cAge3 ); },
      cUnitTypeTradingPost);

      // Dolfin Dry Dock
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatDryDock,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateVeniceDolphin) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Cornaro Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatVeniceEmbassy,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateVeniceCornaro) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Contarini Special Upgrade
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatVeniceFort,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateVeniceContarini) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Embassy Cannons
      canDisableSelf &= researchSimpleTechByCondition(cTechzpVeniceCannonArmy,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypezpVeniceEmbassy, cUnitStateABQ) >= 1); },
      cUnitTypezpVeniceEmbassy);

      // Embassy Galleasses
      canDisableSelf &= researchSimpleTechByCondition(cTechzpVeniceExpeditionaryFleet,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypezpVeniceEmbassy, cUnitStateABQ) >= 1); },
      cUnitTypezpVeniceEmbassy);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// Orthodox Tech Monitor
//==============================================================================
rule orthodoxTechMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketOrthodox, cUnitStateAny) == 0)
      {

      return; // Player has no venice socket.
      }

      // Georgian Outposts I
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpOrthodoxGeorgianCastle,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxGeorgians) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Georgian Outposts II
      canDisableSelf &= researchSimpleTechByCondition(cTechzpOrthodoxCitadel,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxGeorgians) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Russian Army
      canDisableSelf &= researchSimpleTechByCondition(cTechzpOrthodoxRussianJaegers,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxRussians) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Russian Cannons
      canDisableSelf &= researchSimpleTechByCondition(cTechzpOrthodoxKolokol,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxRussians) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Bulgarian Steamer
      canDisableSelf &= researchSimpleTechByCondition(cTechzpOrthodoxSteamer,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxBulgarians) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Bulgarian Ironclad
      canDisableSelf &= researchSimpleTechByCondition(cTechzpOrthodoxFleet,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateOrthodoxBulgarians) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
/* shouldSendPolarExpress
  Looks at how many TP's we have compared with the enemy to determine if we 
  should try and send polar express card. 
  Shamelessly stolen from tradeRouteUpgradeMonitor, using the globals set there
*/
//==============================================================================
bool shouldSendPolarExpress()
{
   int numberTradingPostsOnRoute = 0;
   int tradingPostID = -1;
   int playerID = -1;
   int ownedTradingPostID = -1;
   int numberAllyTradingPosts = 0;
   int numberEnemyTradingPosts = 0;
   int tradeRoutePrio = 47 + (btBiasTrade * 5.0);

   for (routeIndex = 0; < gNumberTradeRoutes)
   {
      if (xsArrayGetBool(gTradeRouteIndexMaxUpgraded, routeIndex) == true)
      {
         continue;
      }

      numberTradingPostsOnRoute = kbTradeRouteGetNumberTradingPosts(routeIndex);
      ownedTradingPostID = -1;
      numberAllyTradingPosts = 0;
      numberEnemyTradingPosts = 0;
      for (postIndex = 0; < numberTradingPostsOnRoute)
      {
         // This syscall needs no LOS and finds all IDs of (built / foundation) TPs currently on that route, 
         // so no empty sockets are found.
         tradingPostID = kbTradeRouteGetTradingPostID(routeIndex, postIndex); 
         playerID = kbUnitGetPlayerID(tradingPostID);
         if (playerID == cMyID)
         {
            ownedTradingPostID = tradingPostID;
            numberAllyTradingPosts++;
            continue;
         }
         if (kbIsPlayerAlly(playerID) == true)
         {
            numberAllyTradingPosts++;
            continue;
         }
         if (kbIsPlayerAlly(playerID) == false)
         {
            numberEnemyTradingPosts++;
         }
      }
      if (ownedTradingPostID >= 0) // If we actually found a TR on this route that is ours, do the upgrade logic.
      {
         // If we're here, that means the trade route isn't fully upgraded so as long as we have more TP's than 
         //   our enemy then we'll send it.
         if (numberAllyTradingPosts - numberEnemyTradingPosts >= 1) 
         {
            return true;
         }
      }
   }
   // If we're here, we didn't find any unupgraded trade routes
   return false;
}

//==============================================================================
// Christmas Village Tech Monitor
//==============================================================================
rule christmasTechMonitor
inactive
minInterval 30
{
   if (kbUnitCount(cMyID, cUnitTypezpSPCSocketXmassVillage, cUnitStateAny) == 0)
   {
      return; // Player has no christmas socket.
   }

   // Hot chocolate, basically any time after reaching age 2
   bool canDisableSelf = researchSimpleTechByCondition(cTechzpHotChocolate,
   []() -> bool { return ( kbGetAge() >= cAge2 ); },
   cUnitTypeTradingPost);

   // Deck the halls, only after enough houses
   canDisableSelf &= researchSimpleTechByCondition(cTechzpDeckTheHalls,
   []() -> bool { return (kbUnitCount(cMyID, gHouseUnit, cUnitStateAlive) > 9 ||
                           kbUnitCount(cMyID, cUnitTypeypShrineJapanese, cUnitStateAlive) > 9); },
   cUnitTypeTradingPost);

   // Polar express, as long as it'll do something and as long as we have more TP's than the enemy
   canDisableSelf &= researchSimpleTechByCondition(cTechzpPolarExpress,
   []() -> bool { return (shouldSendPolarExpress() == true); },
   cUnitTypeTradingPost);

   // Upgrade trade route to iron horse after sending polar express
   canDisableSelf &= researchSimpleTechByCondition(cTechzpPolarExpress,
   []() -> bool { return (shouldSendPolarExpress() == true); },
   cUnitTypeTradingPost);

   // Send Rudolph as soon as available
   canDisableSelf &= researchSimpleTechByCondition(cTechzpSendRudolph,
   []() -> bool { return ( kbGetAge() >= cAge2 ); },
   cUnitTypeTradingPost);

   // Send spread the cheer after 10 minutes for large teams, 20 for medium, and 30 for solo (getAllyCount does not include self)
   canDisableSelf &= researchSimpleTechByCondition(cTechzpSpreadTheCheer,
   []() -> bool { return ( (getAllyCount() > 2 && xsGetTime() > 10*60*1000) ||
                           (getAllyCount() > 1 && xsGetTime() > 20*60*1000) ||
                           (getAllyCount() <= 0 && xsGetTime() > 30*60*1000)  ); },
   cUnitTypeTradingPost);

   // Send workshops as soon as available
   canDisableSelf &= researchSimpleTechByCondition(cTechzpSendWorkshopFood,
   []() -> bool { return ( kbTechGetStatus(cTechzpSendWorkshopFood) == cTechStatusObtainable ); },
   cUnitTypeTradingPost);

   canDisableSelf &= researchSimpleTechByCondition(cTechzpSendWorkshopWood,
   []() -> bool { return ( kbTechGetStatus(cTechzpSendWorkshopWood) == cTechStatusObtainable ); },
   cUnitTypeTradingPost);

   canDisableSelf &= researchSimpleTechByCondition(cTechzpSendWorkshopGold,
   []() -> bool { return ( kbTechGetStatus(cTechzpSendWorkshopGold) == cTechStatusObtainable ); },
   cUnitTypeTradingPost);


   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// ZP Western Tech Monitor
//==============================================================================
rule zpWesternTechMonitor
inactive
mininterval 60
{

   if (kbUnitCount(cMyID, cUnitTypezpSPCSocketWesternVillage, cUnitStateAny) == 0)
      {
      return; // Player has no Western socket.
      }

      bool canDisableSelf = researchSimpleTechByCondition(cTechzpSendDocHolliday,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternWyatEarp) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatSherriffOffice,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternWyatEarp) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpSendPinkertonsB,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternPinkertons) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpSendStageCoach,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternPinkertons) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatApocalypseHorsemen,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternJesseJames) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatGunStore,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateWesternJesseJames) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// polarExpressUpgradeMonitor
// Same as normal upgrade monitor, but will grab final upgrade much earlier
//==============================================================================
rule polarExpressUpgradeMonitor
inactive
minInterval 90
{
   if (xsIsRuleEnabled("tradeRouteUpgradeMonitor") == true)
   {
      xsDisableRule("tradeRouteUpgradeMonitor");
   }

   // Start with updating our bool array by looking at what the first unit on the TR is, 
   // if it's the last tier set the bool to true.
   int firstMovingUnit = -1;
   int firstMovingUnitProtoID = -1;
   for (i = 0; < gNumberTradeRoutes)
   {
      firstMovingUnit = kbTradeRouteGetUnit(i, 0);
      firstMovingUnitProtoID = kbUnitGetProtoUnitID(firstMovingUnit);
      if ((firstMovingUnitProtoID == cUnitTypedeTradingFluyt) || (firstMovingUnitProtoID == cUnitTypeTrainEngine) ||
          (firstMovingUnitProtoID == cUnitTypedeCaravanGuide))
      {
         xsArraySetBool(gTradeRouteIndexMaxUpgraded, i, true);
      }
   }

   // If all the values in the bool array are set to true it means we can disable this rule since we have all the upgrades
   // across all TRs on the map.
   bool canDisableSelf = true;
   for (i = 0; < gNumberTradeRoutes)
   {
      if (xsArrayGetBool(gTradeRouteIndexMaxUpgraded, i) == false)
      {
         canDisableSelf = false;
      }
   }
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }

   int numberTradingPostsOnRoute = 0;
   int tradingPostID = -1;
   int playerID = -1;
   int ownedTradingPostID = -1;
   int numberAllyTradingPosts = 0;
   int numberEnemyTradingPosts = 0;
   int tradeRoutePrio = 47 + (btBiasTrade * 5.0);

   for (routeIndex = 0; < gNumberTradeRoutes)
   {
      if (xsArrayGetBool(gTradeRouteIndexMaxUpgraded, routeIndex) == true)
      {
         continue;
      }

      numberTradingPostsOnRoute = kbTradeRouteGetNumberTradingPosts(routeIndex);
      ownedTradingPostID = -1;
      numberAllyTradingPosts = 0;
      numberEnemyTradingPosts = 0;
      for (postIndex = 0; < numberTradingPostsOnRoute)
      {
         // This syscall needs no LOS and finds all IDs of (built / foundation) TPs currently on that route, 
         // so no empty sockets are found.
         tradingPostID = kbTradeRouteGetTradingPostID(routeIndex, postIndex); 
         playerID = kbUnitGetPlayerID(tradingPostID);
         if (playerID == cMyID)
         {
            ownedTradingPostID = tradingPostID;
            numberAllyTradingPosts++;
            continue;
         }
         if (kbIsPlayerAlly(playerID) == true)
         {
            numberAllyTradingPosts++;
            continue;
         }
         if (kbIsPlayerAlly(playerID) == false)
         {
            numberEnemyTradingPosts++;
      }
      }
      if (ownedTradingPostID >= 0) // If we actually found a TR on this route that is ours, do the upgrade logic.
      {
         if (kbBuildingTechGetStatus(xsArrayGetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (routeIndex * 2)), 
               ownedTradingPostID) == cTechStatusObtainable)
         {
            // We have 1 or more TPs on this route than the enemy, doesn't work for upgrade all special maps.
            if (numberAllyTradingPosts - numberEnemyTradingPosts >= 1) 
            {
               researchSimpleTech(xsArrayGetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (routeIndex * 2)),
                  -1, ownedTradingPostID, tradeRoutePrio);
               return;
            }
         }
         else if ((kbBuildingTechGetStatus(xsArrayGetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (routeIndex * 2)),
                   ownedTradingPostID) == cTechStatusObtainable))
         {
            if (numberAllyTradingPosts - numberEnemyTradingPosts >= 1) 
            {
               researchSimpleTech(xsArrayGetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (routeIndex * 2)),
                  -1, ownedTradingPostID, tradeRoutePrio);
               return;
            }
         }
      }
   }
}

//==============================================================================
// ZP Maori Tech Monitor
//==============================================================================
rule zpMaoriTechMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketMaori, cUnitStateAny) == 0)
      {
      return; // Player has no Maori socket.
      }

      // Maori Big Button
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpMaoriExpansion,
      []() -> bool { return (kbGetAge() >= cAge2 ); },
      cUnitTypeTradingPost);

      // Maori catamarans
      canDisableSelf &= researchSimpleTechByCondition(cTechzpMaoriCatamarans,
      []() -> bool { return ((kbTechGetStatus(cTechzpMaoriExpansion) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Maori Warriors
      canDisableSelf &= researchSimpleTechByCondition(cTechzpMaoriMakahikiArmy,
      []() -> bool { return ((kbTechGetStatus(cTechzpMaoriExpansion) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// ZP Aboriginal Tech Monitor
//==============================================================================
rule zpAboriginalTechMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketaboriginals, cUnitStateAny) == 0)
      {
      return; // Player has no Aboriginal socket.
      }

      // Aboriginal Big Button
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpAustraliaExpansion,
      []() -> bool { return (kbGetAge() >= cAge2 ); },
      cUnitTypeTradingPost);

      // Aboriginal School
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatAboriginalSchool,
      []() -> bool { return ((kbTechGetStatus(cTechzpAustraliaExpansion) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Aboriginal Warriors
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatAboriginalTrackers,
      []() -> bool { return ((kbTechGetStatus(cTechzpAustraliaExpansion) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}

//==============================================================================
// ZP Aboriginal School Builder
//==============================================================================
rule zpAboriginalSchoolBuilder
inactive
minInterval 2
{
   if (kbUnitCount(cUnitTypezpAustralianSchoolWagon, cMyID) <= 0)
   {
      return;
   }

   int buildByUnit = getUnit(cUnitTypeTradingPost, cPlayerRelationSelf);
   vector buildLoc = kbUnitGetPosition(buildByUnit);

   int planID = createLocationBuildPlan(cUnitTypezpAboriginalSchool, 1, 100, true, -1, buildLoc, 1);
   // Add forward villagers
   aiPlanAddUnit(planID, getUnit(cUnitTypezpAustralianSchoolWagon, cPlayerRelationSelf));

   xsDisableSelf();
}

//==============================================================================
// ZP Jewish Tech Monitor
//==============================================================================
rule zpJewishTechMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketJewish, cUnitStateAny) == 0)
      {
      return; // Player has no Jewish socket.
      }

      // Jewish Americans
      bool canDisableSelf = researchSimpleTechByCondition(cTechzpJewishEmbassy,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateJewishAmericans) == cTechStatusActive) && ( kbGetAge() >= cAge3 )); },
      cUnitTypeTradingPost);

      // Jewish Germans
      canDisableSelf &= researchSimpleTechByCondition(cTechzpJewishAcademy,
      []() -> bool { return ((kbTechGetStatus(cTechzpConsulateJewishGermans) == cTechStatusActive) && ( kbGetAge() >= cAge2 )); },
      cUnitTypeTradingPost);

      // Embassy Cannons
      canDisableSelf &= researchSimpleTechByCondition(cTechzpNatConAmericanArmyBig,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypezpAmericanEmbassy, cUnitStateABQ) >= 1); },
      cUnitTypezpAmericanEmbassy);


  if (canDisableSelf == true)
      {
          xsDisableSelf();
      }
  
}