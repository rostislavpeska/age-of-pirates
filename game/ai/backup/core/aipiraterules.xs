//==============================================================================
/* aiPirateRules.xs

   This file contains some map specific functions written for the Pirates of the
   Caribbean mod.

*/
//==============================================================================


//==============================================================================
// initializePirateRules
//==============================================================================

rule initializePirateRules
active
minInterval 5
{
    // Initializes all pirate functions if this is a pirate map
    // Add always active rules here
    xsEnableRule("CaribTPMonitor");
    xsEnableRule("pirateShipAbilityMonitor");

    // Test to check if this script gets run
    //sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyIWillBuildMilitaryBase, kbGetMapCenter());
    
    
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
    if (getGaiaUnitCount(cUnitTypezpSPCGreatBuddha) > 0)
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
    }

    if (getGaiaUnitCount(cUnitTypezpNativeHouseInuit) > 0)
    {
        xsEnableRule("zpInuitTechMonitor");
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

   if (cMyCiv == cCivDEInca)
   {
        xsEnableRule("priestessAbilityMonitor");
   }
    
    xsDisableSelf();
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
      pirateShipID = getUnit(cUnitTypezpCatamaran, cMyID, cUnitStateAlive);
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

   // =================
   // Now Jewish
   // =================
   int jewishVillager = getUnit(cUnitTypezpNatSettlerJewish, cPlayerRelationSelf, cUnitStateAlive);
   if (jewishVillager > 0)
   {
      // The build limit for the Academy is 1, so don't bother looking it up
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
minInterval 5
{
   if ( kbGetAge() <= cAge1 )
   return;
    
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
    for( i = 0; < num_sockets )
    {
        vector socket_position = kbUnitGetPosition( kbUnitQueryGetResult( socket_query, i ) );
        if ( kbAreaGroupGetIDByPosition( socket_position ) == builder_areagroup )
        {
            // This socket is reachable
            // See if it's already occupied:
            if ( getUnitCountByLocation( cUnitTypeTradingPost, cPlayerRelationAny, cUnitStateABQ, socket_position, 10.0) >= 1 )
                continue; // Yes. Well, ignore it and find the next...
            
            // No. Great, select it and proceed to the construction:
            socket = kbUnitQueryGetResult( socket_query, i );
            break;
        }
    }
    
    static int build_plan = -1;
    
    if ( aiPlanGetState( build_plan ) == -1 )
    {
        aiPlanDestroy( build_plan );
        build_plan = aiPlanCreate( "BuildCaribTP", cPlanBuild );
        aiPlanSetDesiredPriority( build_plan, 100 );
        aiPlanSetEscrowID( build_plan, cEmergencyEscrowID );
        aiPlanSetVariableInt( build_plan, cBuildPlanBuildUnitID, 0, builder );
        aiPlanAddUnitType( build_plan, kbUnitGetProtoUnitID( builder ), 1, 1, 1 );
        aiPlanAddUnit( build_plan, builder );
        aiPlanSetVariableInt( build_plan, cBuildPlanBuildingTypeID, 0, cUnitTypeTradingPost );
        aiPlanSetVariableInt( build_plan, cBuildPlanSocketID, 0, socket );
        aiPlanSetActive( build_plan, true );
    }
    
    aiChat( cMyID, ""+aiPlanGetState( build_plan ) );
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
      aiChat( cMyID, "Wokou Socket not found");
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
        aiChat( cMyID, "Great Mosque found");
        // Upgrade Great Mosque on Asian Maps
        bool canDisableSelf = researchSimpleTech(cTechzpSPCSufiGreatMosque, cUnitTypeTradingPost);

    }

   if (kbUnitCount(0, cUnitTypezpSPCBlueMosque, cUnitStateAny) >= 1)
    {
        aiChat( cMyID, "Blue Mosque found");
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
        aiChat( cMyID, "Aztec Temple found");
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
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypezpCastleZen, cUnitStateABQ) >= 1); },
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
             buildingType = cUnitTypezpCastleZen;
             break;
         }
         case cUnitTypezpWaterTempleTravois:
         {
             buildingType = cUnitTypezpWaterTemple;
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
         case cUnitTypezpAustralianSchoolWagon:
         {
             buildingType = cUnitTypezpAboriginalSchool;
             break;
         }
         case cUnitTypezpWaterFortBuilder:
         {
            buildingType = cUnitTypezpWaterFort;
            break;
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
mininterval 1
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
         aiChat( cMyID, "Airship training");
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
      aiChat( cMyID, "Venice Socket not found");
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
mininterval 60
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