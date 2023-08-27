//==============================================================================
/* aiSetup.xs

   This file contains all functions and rules for initialization.

*/

//==============================================================================
/* initCivUnitTypes
   Initialize all global civilisation specific unit types.
*/
//==============================================================================
void initCivUnitTypes()
{
   debugSetup("***Initialising civilisation specific unit types***");
   if (civIsEuropean() == true)
   {
      if (cMyCiv == cCivDutch)
      {
         gGalleonUnit = cUnitTypeFluyt;
      }
      
      if (cMyCiv == cCivFrench)
      {
         gEconUnit = cUnitTypeCoureur;
      }
      
      if (cMyCiv == cCivRussians)
      {
         gTowerUnit = cUnitTypeBlockhouse;
      }
   
      if (cMyCiv == cCivOttomans)
      {
         gCaravelUnit = cUnitTypeGalley;
      }
         
      if ((cMyCiv == cCivBritish) || (cMyCiv == cCivTheCircle) || (cMyCiv == cCivPirate) || (cMyCiv == cCivSPCAct3))
      {
         gHouseUnit = cUnitTypeManor;
      }
      
      if ((cMyCiv == cCivFrench) || (cMyCiv == cCivDutch) || (cMyCiv == cCivDEAmericans))
      {
         gHouseUnit = cUnitTypeHouse;
      }
      
      if ((cMyCiv == cCivGermans) || (cMyCiv == cCivRussians))
      {
         gHouseUnit = cUnitTypeHouseEast;
      }
   
      if ((cMyCiv == cCivSpanish) || (cMyCiv == cCivPortuguese) || (cMyCiv == cCivOttomans) ||
          (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEItalians) || (cMyCiv == cCivDEMaltese))
      {
         gHouseUnit = cUnitTypeHouseMed;
      }
      
      if (cMyCiv == cCivDESwedish)
      {
         gHouseUnit = cUnitTypedeTorp;
      }
      
      if (cMyCiv == cCivDEAmericans || cMyCiv == cCivDEMexicans)
      {
         gCaravelUnit = cUnitTypedeSloop;
         gGalleonUnit = cUnitTypedeSteamer;
         gMonitorUnit = cUnitTypexpIronclad;
      }
   
      if (cMyCiv == cCivDEMexicans)
      {
         gFarmUnit = cUnitTypedeHacienda;
         gPlantationUnit = cUnitTypedeHacienda;
   
         cMaxSettlersPerFarm = 20;
         cMaxSettlersPerPlantation = 20;
   
         gFarmFoodTactic = cTacticHaciendaFood;
         gFarmGoldTactic = cTacticHaciendaCoin;
      }

      if (cMyCiv == cCivDEItalians)
      {
         gGalleonUnit = cUnitTypedeGalleass;
      }

      if (cMyCiv == cCivDEMaltese)
      {
         gCaravelUnit = cUnitTypedeOrderGalley;
      }
   }
   
   if (civIsNative() == true)
   {
      gEconUnit = cUnitTypeSettlerNative;
      gCaravelUnit = cMyCiv == cCivDEInca ? cUnitTypedeChinchaRaft : cUnitTypexpWarCanoe;
      gTowerUnit = cUnitTypeWarHut;
      gFarmUnit = cUnitTypeFarm;
      
      if (cMyCiv == cCivXPIroquois)
      {
         gHouseUnit = cUnitTypeLonghouse;
      }
    
      if (cMyCiv == cCivXPAztec)
      {
         gHouseUnit = cUnitTypeHouseAztec;
         gFrigateUnit = cUnitTypexpTlalocCanoe;
      }
    
      if (cMyCiv == cCivDEInca)
      {
         gHouseUnit = cUnitTypedeHouseInca;
      }
      
      if (cMyCiv == cCivXPAztec || cMyCiv == cCivXPIroquois || cMyCiv == cCivXPSioux)
      {
         gGalleonUnit = cUnitTypeCanoe;
      }
   }

   if (civIsAsian() == true)
   {
      gTowerUnit = cUnitTypeypCastle;
      gFarmUnit = cUnitTypeypRicePaddy;
      gPlantationUnit = cUnitTypeypRicePaddy;
      gMarketUnit = cUnitTypeypTradeMarketAsian;
      gDockUnit = cUnitTypeYPDockAsian;
      cvOkToBuildForts = false;
      gFishingUnit = cUnitTypeypFishingBoatAsian;
      gFarmFoodTactic = cTacticPaddyFood;
      gFarmGoldTactic = cTacticPaddyCoin;
      
      if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
      {
         gEconUnit = cUnitTypeypSettlerAsian;
         gHouseUnit = cUnitTypeypVillage;
         gCaravelUnit = cUnitTypeypWarJunk;
         gFrigateUnit = cUnitTypeypFuchuan;
         gLivestockPenUnit = cUnitTypeypVillage;
      }
   
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         gEconUnit = cUnitTypeypSettlerJapanese;
         gHouseUnit = cUnitTypeypShrineJapanese;
         gCaravelUnit = cUnitTypeypFune;
         gGalleonUnit = cUnitTypeypAtakabune;
         gFrigateUnit = cUnitTypeypTekkousen;
         gLivestockPenUnit = cUnitTypeypShrineJapanese;
      }
   
      if ((cMyCiv == cCivIndians) || (cMyCiv == cCivSPCIndians))
      {
         gHouseUnit = cUnitTypeypHouseIndian;
         gLivestockPenUnit = cUnitTypeypSacredField;
         gEconUnit = cUnitTypeypSettlerIndian;
      }
   }
   
   if (civIsAfrican() == true)
   {
      gEconUnit = cUnitTypedeSettlerAfrican;
      gHouseUnit = cUnitTypedeHouseAfrican;

      gTowerUnit = cUnitTypedeTower;
      gFarmUnit = cUnitTypedeField;
      gPlantationUnit = cUnitTypedeField;

      gMarketUnit = cUnitTypedeLivestockMarket;
      gDockUnit = cUnitTypedePort;
      gLivestockPenUnit = cUnitTypedeLivestockMarket;

      gFishingUnit = cUnitTypedeFishingBoatAfrican;
      gCaravelUnit = cUnitTypedeBattleCanoe;
      if (cMyCiv == cCivDEEthiopians)
      {
         gFrigateUnit = cUnitTypedeMercDhow;
      }
      else // Hausa.
      {
         gFrigateUnit = cUnitTypedeMercXebec;
      }
      gMonitorUnit = cUnitTypedeCannonBoat;

      cMaxSettlersPerFarm = 3;
      cMaxSettlersPerPlantation = 3;

      gFarmFoodTactic = cTacticFieldFood;
      gFarmGoldTactic = cTacticFieldCoin;
   }
}

//==============================================================================
/* initArrays
   Initialize all global arrays here, to make it easy to find var type and size.
*/
//==============================================================================

void initArrays(void)
{
   debugSetup("***Initialising global arrays***");
   //==============================================================================
   // Core.
   //==============================================================================

   gTargetSettlerCounts = xsArrayCreateInt(cAge5 + 1, 0, "Target Settler Counts");

   switch (cDifficultyCurrent)
   {
      case cDifficultySandbox: // Easy.
   {
      xsArraySetInt(gTargetSettlerCounts, cAge1, 10);
      xsArraySetInt(gTargetSettlerCounts, cAge2, 10);
      xsArraySetInt(gTargetSettlerCounts, cAge3, 10);
      xsArraySetInt(gTargetSettlerCounts, cAge4, 10);
      xsArraySetInt(gTargetSettlerCounts, cAge5, 10);
      break;
   }
      case cDifficultyEasy: // Standard.
   {
      xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
      xsArraySetInt(gTargetSettlerCounts, cAge2, 25);
      if (gSPC == true)
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 25);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 25);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 25);
      }
      else
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 35);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 35);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 35);
      }
      break;
   }
      case cDifficultyModerate: // Moderate.
   {
      xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
      xsArraySetInt(gTargetSettlerCounts, cAge2, 30);
      if (gSPC == true)
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 45);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 45);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 45);
      }
      else
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 60);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 60);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 60);
      }
      break;
   }
      case cDifficultyHard: // Hard.
   {
      xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
      xsArraySetInt(gTargetSettlerCounts, cAge2, 40);
      if (gSPC == true)
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 65);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 65);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 65);
      }
      else
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 99);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 99);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 99);
      }
      break;
   }
      default: // Hardest and Extreme.
   {
      xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
      xsArraySetInt(gTargetSettlerCounts, cAge2, 45);
      xsArraySetInt(gTargetSettlerCounts, cAge3, 99);
      xsArraySetInt(gTargetSettlerCounts, cAge4, 99);
      xsArraySetInt(gTargetSettlerCounts, cAge5, 99);
      break;
   }
   }

   gTargetSettlerCountsDefault = xsArrayCreateInt(cAge5 + 1, 0, "Default Target Settler Counts");
   for (i = cAge1; <= cAge5) // Fill the gTargetSettlerCountsDefault array with the default values for regular civs.
   {
      xsArraySetInt(gTargetSettlerCountsDefault, i, xsArrayGetInt(gTargetSettlerCounts, i));
   }

   // Start overriding the gTargetSettlerCounts depending on if we're a civ that has some custom Settler limit logic.
   if (cMyCiv == cCivFrench)
   {
      for (i = cAge1; <= cAge5) // Need fewer Coureur de Bois.
      {
         xsArraySetInt(gTargetSettlerCounts, i, xsArrayGetInt(gTargetSettlerCounts, i) * 0.9);
      }
      // And correct to our build limit on higher limits.
      if (cDifficultyCurrent == cDifficultyHard)
      {
         if (gSPC == false) // Otherwise just leave the defaults which will function fine.
         {
            xsArraySetInt(gTargetSettlerCounts, cAge3, 80);
            xsArraySetInt(gTargetSettlerCounts, cAge4, 80);
            xsArraySetInt(gTargetSettlerCounts, cAge5, 80);
         }
      }
      else if (cDifficultyCurrent >= cDifficultyExpert)
      {
         xsArraySetInt(gTargetSettlerCounts, cAge3, 80);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 80);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 80);
      }
   }
   if (cMyCiv == cCivDutch)
   {
      switch (cDifficultyCurrent)
      {
         case cDifficultySandbox: // Easy.
      {
         xsArraySetInt(gTargetSettlerCounts, cAge1, 10);
         xsArraySetInt(gTargetSettlerCounts, cAge2, 10);
         xsArraySetInt(gTargetSettlerCounts, cAge3, 10);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 10);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 10);
         break;
      }
         case cDifficultyEasy: // Standard.
      {
         xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
         xsArraySetInt(gTargetSettlerCounts, cAge2, 20);
         xsArraySetInt(gTargetSettlerCounts, cAge3, 25);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 25);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 25);
         break;
      }
         case cDifficultyModerate: // Moderate.
      {
         xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
         xsArraySetInt(gTargetSettlerCounts, cAge2, 25);
         xsArraySetInt(gTargetSettlerCounts, cAge3, 35);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 35);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 35);
         break;
      }
         default: // Hard / Hardest / Extreme.
      {
         xsArraySetInt(gTargetSettlerCounts, cAge1, 15);
            xsArraySetInt(gTargetSettlerCounts, cAge2, 35);
         xsArraySetInt(gTargetSettlerCounts, cAge3, 50);
         xsArraySetInt(gTargetSettlerCounts, cAge4, 50);
         xsArraySetInt(gTargetSettlerCounts, cAge5, 50);
         break;
      }
      }
   }

   //==============================================================================
   // Buildings.
   //==============================================================================

   if (cMyCiv == cCivDESwedish)
   {
      gTorpPositionsToAvoid = xsArrayCreateVector(1, cInvalidVector, "Torp Positions To Avoid");
   }

   if (cMyCiv == cCivXPAztec)
   {
      gMilitaryBuildings = xsArrayCreateInt(3, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeWarHut);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeNoblesHut);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeNativeEmbassy);
   }
   else if (cMyCiv == cCivXPIroquois)
   {
      gMilitaryBuildings = xsArrayCreateInt(3, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeWarHut);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeCorral);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeArtilleryDepot);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypeNativeEmbassy);
   }
   else if (cMyCiv == cCivXPSioux)
   {
      gMilitaryBuildings = xsArrayCreateInt(2, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeWarHut);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeCorral);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeNativeEmbassy);
   }
   else if (cMyCiv == cCivDEInca)
   {
      gMilitaryBuildings = xsArrayCreateInt(2, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeWarHut);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypedeKallanka);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeNativeEmbassy);
   }
   else if (cMyCiv == cCivChinese || cMyCiv == cCivSPCChinese)
   {
      gMilitaryBuildings = xsArrayCreateInt(3, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeypWarAcademy);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeypCastle);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeypMonastery);
   }
   else if (cMyCiv == cCivIndians || cMyCiv == cCivSPCIndians)
   {
      gMilitaryBuildings = xsArrayCreateInt(4, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeYPBarracksIndian);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeypCaravanserai);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeypCastle);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypeypMonastery);
   }
   else if (cMyCiv == cCivJapanese || cMyCiv == cCivSPCJapanese || cMyCiv == cCivSPCJapaneseEnemy)
   {
      gMilitaryBuildings = xsArrayCreateInt(5, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeypBarracksJapanese);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeypStableJapanese);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeypCastle);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypeypMonastery);
      xsArraySetInt(gMilitaryBuildings, 4, cUnitTypeypChurch);
   }
   else if (cMyCiv == cCivDEHausa || cMyCiv == cCivDEEthiopians)
   {
      gMilitaryBuildings = xsArrayCreateInt(2, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypedeWarCamp);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypedeTower);
   }
   else if (cMyCiv == cCivRussians)
   {
      gMilitaryBuildings = xsArrayCreateInt(5, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeBlockhouse);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeStable);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeArtilleryDepot);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypedeTavern);
      xsArraySetInt(gMilitaryBuildings, 4, cUnitTypeChurch);
   }
   else if (cMyCiv == cCivDEItalians)
   {
      gMilitaryBuildings = xsArrayCreateInt(5, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeBarracks);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeStable);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeArtilleryDepot);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypedeLombard);
      xsArraySetInt(gMilitaryBuildings, 4, cUnitTypeChurch);
   }   
   else if (cMyCiv == cCivDEMaltese)
   {
      gMilitaryBuildings = xsArrayCreateInt(5, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypedeHospital);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypedeCommandery);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeArtilleryDepot);
      xsArraySetInt(gMilitaryBuildings, 3, cUnitTypedeTavern);
      xsArraySetInt(gMilitaryBuildings, 4, cUnitTypeChurch);
   }      
   else
   {
      gMilitaryBuildings = xsArrayCreateInt(5, -1, "Military Buildings");
      xsArraySetInt(gMilitaryBuildings, 0, cUnitTypeBarracks);
      xsArraySetInt(gMilitaryBuildings, 1, cUnitTypeStable);
      xsArraySetInt(gMilitaryBuildings, 2, cUnitTypeArtilleryDepot);
      if (cMyCiv == cCivDEAmericans || cMyCiv == cCivDEMexicans)
         xsArraySetInt(gMilitaryBuildings, 3, cUnitTypeSaloon);
      else
         xsArraySetInt(gMilitaryBuildings, 3, cUnitTypedeTavern);
      xsArraySetInt(gMilitaryBuildings, 4, cUnitTypeChurch);
   }
   gArmyUnitBuildings = xsArrayCreateInt(gNumArmyUnitTypes, -1, "Army Unit Buildings");
   gQueuedBuildPlans = xsArrayCreateInt(5, -1, "Queued build plans");
   gFullGranaries = xsArrayCreateInt(20, -1, "Full Granaries");

   //==============================================================================
   // Techs, TR part is also for Economy.
   //==============================================================================

   gNumberTradeRoutes = kbGetNumberTradeRoutes();
   if (gNumberTradeRoutes > 0)
   {
      debugSetup("Amount of Trading Routes found: " + gNumberTradeRoutes);
      gTradeRouteIndexAndType = xsArrayCreateInt(gNumberTradeRoutes, -1, "Trade Route Types");
      gTradeRouteIndexMaxUpgraded = xsArrayCreateBool(gNumberTradeRoutes, false, "Trade Route Max Upgraded");
      // We have to save 4 crates per route. Infuence is always the same but it must be saved for the logic to work.
      gTradeRouteCrates = xsArrayCreateInt(gNumberTradeRoutes * 4, -1, "Trade Route Crates"); 
      // Always 2 upgrades per route.
      gTradeRouteUpgrades = xsArrayCreateInt(gNumberTradeRoutes * 2, -1, "Trade Route Upgrades");

      int firstMovingUnit = -1;
      int firstMovingUnitProtoID = -1;
      for (i = 0; < gNumberTradeRoutes)
      {
         xsSetContextPlayer(0);
         if (kbUnitGetPlayerID(kbTradeRouteGetTradingPostID(i, 0)) == 0)
         {
            xsSetContextPlayer(cMyID);
            xsArraySetBool(gTradeRouteIndexMaxUpgraded, i, true);
            if (kbTechGetStatus(cTechdeMapAfrican) == cTechStatusActive)
            {
               debugSetup("Route: " + i + " is an African capturable Trading Route which can't be upgraded");
               xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteCapturableAfrica);
               xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypedeCrateofCoinAfrican1);
               xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypedeCrateofWoodAfrican1);
               xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypedeCrateofFoodAfrican1);
               xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
            }
            else
            {
               debugSetup("Route: " + i + " is an Asian capturable Trading Route which can't be upgraded");
               xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteCapturableAsia);
               xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypeypTradeCrateofCoin);
               xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypeypTradeCrateofWood);
               xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypeypTradeCrateofFood);
               xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
            }
            continue;
         }
         xsSetContextPlayer(cMyID);
         firstMovingUnit = kbTradeRouteGetUnit(i, 0);
         firstMovingUnitProtoID = kbUnitGetProtoUnitID(firstMovingUnit);
         if ((firstMovingUnitProtoID == cUnitTypedeTradingShip) || (firstMovingUnitProtoID == cUnitTypedeTradingGalleon) ||
             (firstMovingUnitProtoID == cUnitTypedeTradingFluyt))
         {
            debugSetup("Route: " + i + " is a Naval Trading Route");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteNaval);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechDETradeRouteUpgradeWater1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechDETradeRouteUpgradeWater2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypedeCrateofCoinWater);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypedeCrateofWoodWater);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypedeCrateofFoodWater);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
         else if (kbTechGetStatus(cTechDEEnableTradeRouteNativeAmerican) == cTechStatusActive)
         {
            debugSetup("Route: " + i + " is a South American Trading Route");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteSouthAmerica);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechdeTradeRouteUpgradeAmerica1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechdeTradeRouteUpgradeAmerica2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypedeCrateofCoinAmerican);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypedeCrateofWoodAmerican);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypedeCrateofFoodAmerican);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
         else if (kbTechGetStatus(cTechYPEnableAsianNativeOutpost) == cTechStatusActive)
         {
            debugSetup("Route: " + i + " is an Asian Trading Route");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteAsia);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechypTradeRouteUpgrade1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechypTradeRouteUpgrade2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypeypCrateofCoin1);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypeypCrateofWood1);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypeypCrateofFood1);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
         else if (kbTechGetStatus(cTechDEEnableTradeRouteAfrican) == cTechStatusActive)
         {
            debugSetup("Route: " + i + " is an African Trading Route");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteAfrica);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechDETradeRouteUpgradeAfrica1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechDETradeRouteUpgradeAfrica2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypedeCrateofCoinAfrican);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypedeCrateofWoodAfrican);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypedeCrateofFoodAfrican);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
         else if (kbTechGetStatus(cTechDEEnableTradeRouteUpgradeAll) == cTechStatusActive)
         {
            debugSetup("Route: " + i + " is a special North American Trading Route where upgrading " +
               "one route also upgrades all the others, we can't play smart with this");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteAll);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechDETradeRouteUpgradeAll1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechDETradeRouteUpgradeAll2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypedeCrateofCoin);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypedeCrateofWood);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypedeCrateofFood);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
         else // It all defaults to North America.
         {
            debugSetup("Route: " + i + " is a North American Trading Route");
            xsArraySetInt(gTradeRouteIndexAndType, i, cTradeRouteNorthAmerica);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteFirstUpgrade + (i * 2), cTechTradeRouteUpgrade1);
            xsArraySetInt(gTradeRouteUpgrades, cTradeRouteSecondUpgrade + (i * 2), cTechTradeRouteUpgrade2);
            xsArraySetInt(gTradeRouteCrates, 0 + (i * 4), cUnitTypeTradeCrateofCoin);
            xsArraySetInt(gTradeRouteCrates, 1 + (i * 4), cUnitTypeTradeCrateofWood);
            xsArraySetInt(gTradeRouteCrates, 2 + (i * 4), cUnitTypeTradeCrateofFood);
            xsArraySetInt(gTradeRouteCrates, 3 + (i * 4), cUnitTypedeTradeCrateofInfluence);
         }
      }
   }
   else
   {
      debugSetup("We found no Trading Routes on this map");
   }

   gFirstAgeTime = xsArrayCreateInt(5, 60 * 60 * 1000, "Time age was reached");
   xsArraySetInt(gFirstAgeTime, cAge2, -10 * 60 * 1000); // So we always bump the priority for getting Commerce.

   if (civIsEuropean() == true)
   {
   gRevolutionList = xsArrayCreateInt(20, 0, "Revolution List");
   xsArraySetInt(gRevolutionList, 0, cTechDERevolutionHaiti);
   xsArraySetInt(gRevolutionList, 1, cTechDERevolutionEgypt);
   xsArraySetInt(gRevolutionList, 2, cTechDERevolutionFinland);
   xsArraySetInt(gRevolutionList, 3, cTechDERevolutionRomania);
   xsArraySetInt(gRevolutionList, 4, cTechDERevolutionPeru);
   xsArraySetInt(gRevolutionList, 5, cTechDERevolutionBrazil);
   xsArraySetInt(gRevolutionList, 6, cTechDERevolutionArgentina);
   xsArraySetInt(gRevolutionList, 7, cTechDERevolutionUSA);
   xsArraySetInt(gRevolutionList, 8, cTechDERevolutionCanadaFrench);
   xsArraySetInt(gRevolutionList, 9, cTechDERevolutionCanadaBritish);
   xsArraySetInt(gRevolutionList, 10, cTechDERevolutionIndonesia);
   xsArraySetInt(gRevolutionList, 11, cTechDERevolutionBarbaryStates);
   xsArraySetInt(gRevolutionList, 12, cTechDERevolutionHungaryRussian);
   xsArraySetInt(gRevolutionList, 13, cTechDERevolutionHungaryOttoman);
   xsArraySetInt(gRevolutionList, 14, cTechDERevolutionHungaryGerman);
   xsArraySetInt(gRevolutionList, 15, cTechDERevolutionMexico);
   xsArraySetInt(gRevolutionList, 16, cTechDERevolutionColombia);
   xsArraySetInt(gRevolutionList, 17, cTechDERevolutionColombiaPortuguese);
   xsArraySetInt(gRevolutionList, 18, cTechDERevolutionChile);
   xsArraySetInt(gRevolutionList, 19, cTechDERevolutionSouthAfrica);
   }

   gAfricanAlliances = xsArrayCreateInt(8, 0, "African Alliances");
   gAfricanAlliancesAgedUpWith = xsArrayCreateBool(5, false, "African Alliances Aged Up With");
   // Default to true and set to false when we actually age-up with the Alliance.
   gAfricanAlliancesUpgrades = xsArrayCreateBool(5, true, "African Alliances Upgrades");
   gMexicanFederalStates = xsArrayCreateInt(5, 0, "Mexican Federal States");
   gAmericanFederalStates = xsArrayCreateInt(5, 0, "United States Federal States");

   //==============================================================================
   // Economy.
   //==============================================================================

   gResourceNeeds = xsArrayCreateFloat(3, 0.0, "Resource Needs");
   gExtraResourceNeeds = xsArrayCreateFloat(3, 0.0, "Extra Resource Needs");
   gAdjustBreakdownAttempts = xsArrayCreateInt(3, 1, "Resource Breakdown Adjust Attempts");
   gMarketBuySellPercentages = xsArrayCreateFloat(3, 0.0, "Market Buy Sell Percentages");
   gRawResourcePercentages = xsArrayCreateFloat(3, 0.0, "Raw Resource Percentages");

   //==============================================================================
   // Military.
   //==============================================================================

   gArrayEnemyPlayerIDs = xsArrayCreateInt(cNumberPlayers - 2, -1, "Enemy Player IDs");
   gStartingPosDistances = xsArrayCreateFloat(cNumberPlayers, 0.0, "Player Starting Position Distances");
   vector startLoc = kbGetPlayerStartingPosition(cMyID);

   for (i = 1; < cNumberPlayers)
   {
      xsArraySetFloat(gStartingPosDistances, i, xsVectorLength(startLoc - kbGetPlayerStartingPosition(i)));
   }

   gArmyUnitMaintainPlans = xsArrayCreateInt(gNumArmyUnitTypes, -1, "Army Unit Maintain Plans");

   //==============================================================================
   // Chats.
   //==============================================================================

   gMapNames = xsArrayCreateString(242, "", "Map names");
   xsArraySetString(gMapNames, 0, "afatlas");
   xsArraySetString(gMapNames, 1, "afatlaslarge");
   xsArraySetString(gMapNames, 2, "afdarfur");
   xsArraySetString(gMapNames, 3, "afdarfurlarge");
   xsArraySetString(gMapNames, 4, "afdunes");
   xsArraySetString(gMapNames, 5, "afduneslarge");
   xsArraySetString(gMapNames, 6, "afgold coast");
   xsArraySetString(gMapNames, 7, "afgold coastlarge");
   xsArraySetString(gMapNames, 8, "afgreat rift");
   xsArraySetString(gMapNames, 9, "afgreat riftlarge");
   xsArraySetString(gMapNames, 10, "afhighlands");
   xsArraySetString(gMapNames, 11, "afhighlandslarge");
   xsArraySetString(gMapNames, 12, "afhorn");
   xsArraySetString(gMapNames, 13, "afhornlarge");
   xsArraySetString(gMapNames, 14, "afivorycoast");
   xsArraySetString(gMapNames, 15, "afivorycoastlarge");
   xsArraySetString(gMapNames, 16, "aflakechad");
   xsArraySetString(gMapNames, 17, "aflakechadlarge");
   xsArraySetString(gMapNames, 18, "afnigerdelta");
   xsArraySetString(gMapNames, 19, "afnigerdeltalarge");
   xsArraySetString(gMapNames, 20, "afniger river");
   xsArraySetString(gMapNames, 21, "afniger riverlarge");
   xsArraySetString(gMapNames, 22, "afnile valley");
   xsArraySetString(gMapNames, 23, "afnile valleylarge");
   xsArraySetString(gMapNames, 24, "afpeppercoast");
   xsArraySetString(gMapNames, 25, "afpeppercoastlarge");
   xsArraySetString(gMapNames, 26, "afsahel");
   xsArraySetString(gMapNames, 27, "afsahellarge");
   xsArraySetString(gMapNames, 28, "afsavanna");
   xsArraySetString(gMapNames, 29, "afsavannalarge");
   xsArraySetString(gMapNames, 30, "afsiwaoasis");
   xsArraySetString(gMapNames, 31, "afsiwaoasislarge");
   xsArraySetString(gMapNames, 32, "afsudd");
   xsArraySetString(gMapNames, 33, "afsuddlarge");
   xsArraySetString(gMapNames, 34, "afswahilicoast");
   xsArraySetString(gMapNames, 35, "afswahilicoastlarge");
   xsArraySetString(gMapNames, 36, "aftassili");
   xsArraySetString(gMapNames, 37, "aftassililarge");
   xsArraySetString(gMapNames, 38, "aftripolitania");
   xsArraySetString(gMapNames, 39, "aftripolitanialarge");
   xsArraySetString(gMapNames, 40, "alaska");
   xsArraySetString(gMapNames, 41, "alaskalarge");
   xsArraySetString(gMapNames, 42, "amazonia");
   xsArraySetString(gMapNames, 43, "amazonialarge");
   xsArraySetString(gMapNames, 44, "andes upper");
   xsArraySetString(gMapNames, 45, "andes upperlarge");
   xsArraySetString(gMapNames, 46, "andes");
   xsArraySetString(gMapNames, 47, "andeslarge");
   xsArraySetString(gMapNames, 48, "araucania");
   xsArraySetString(gMapNames, 49, "araucanialarge");
   xsArraySetString(gMapNames, 50, "arctic territories");
   xsArraySetString(gMapNames, 51, "arctic territorieslarge");
   xsArraySetString(gMapNames, 52, "bahia");
   xsArraySetString(gMapNames, 53, "bahialarge");
   xsArraySetString(gMapNames, 54, "baja california");
   xsArraySetString(gMapNames, 55, "baja californialarge");
   xsArraySetString(gMapNames, 56, "bayou");
   xsArraySetString(gMapNames, 57, "bayoularge");
   xsArraySetString(gMapNames, 58, "bengal");
   xsArraySetString(gMapNames, 59, "bengallarge");
   xsArraySetString(gMapNames, 60, "borneo");
   xsArraySetString(gMapNames, 61, "borneolarge");
   xsArraySetString(gMapNames, 62, "california");
   xsArraySetString(gMapNames, 63, "californialarge");
   xsArraySetString(gMapNames, 64, "caribbean");
   xsArraySetString(gMapNames, 65, "caribbeanlarge");
   xsArraySetString(gMapNames, 66, "carolina");
   xsArraySetString(gMapNames, 67, "carolinalarge");
   xsArraySetString(gMapNames, 68, "cascade range");
   xsArraySetString(gMapNames, 69, "cascade rangelarge");
   xsArraySetString(gMapNames, 70, "central plain");
   xsArraySetString(gMapNames, 71, "central plainlarge");
   xsArraySetString(gMapNames, 72, "ceylon");
   xsArraySetString(gMapNames, 73, "ceylonlarge");
   xsArraySetString(gMapNames, 74, "colorado");
   xsArraySetString(gMapNames, 75, "coloradolarge");
   xsArraySetString(gMapNames, 76, "dakota");
   xsArraySetString(gMapNames, 77, "dakotalarge");
   xsArraySetString(gMapNames, 78, "deccan");
   xsArraySetString(gMapNames, 79, "deccanLarge");
   xsArraySetString(gMapNames, 80, "fertile crescent");
   xsArraySetString(gMapNames, 81, "fertile crescentlarge");
   xsArraySetString(gMapNames, 82, "florida");
   xsArraySetString(gMapNames, 83, "floridalarge");
   xsArraySetString(gMapNames, 84, "gran chaco");
   xsArraySetString(gMapNames, 85, "gran chacolarge");
   xsArraySetString(gMapNames, 86, "great lakes");
   xsArraySetString(gMapNames, 87, "greak lakesLarge");
   xsArraySetString(gMapNames, 88, "great plains");
   xsArraySetString(gMapNames, 89, "great plainslarge");
   xsArraySetString(gMapNames, 90, "himalayas");
   xsArraySetString(gMapNames, 91, "himalayaslarge");
   xsArraySetString(gMapNames, 92, "himalayasupper");
   xsArraySetString(gMapNames, 93, "himalayasupperlarge");
   xsArraySetString(gMapNames, 94, "hispaniola");
   xsArraySetString(gMapNames, 95, "hispaniolalarge");
   xsArraySetString(gMapNames, 96, "hokkaido");
   xsArraySetString(gMapNames, 97, "hokkaidolarge");
   xsArraySetString(gMapNames, 98, "honshu");
   xsArraySetString(gMapNames, 99, "honshularge");
   xsArraySetString(gMapNames, 100, "honshuregicide");
   xsArraySetString(gMapNames, 101, "honshuregicidelarge");
   xsArraySetString(gMapNames, 102, "indochina");
   xsArraySetString(gMapNames, 103, "indochinalarge");
   xsArraySetString(gMapNames, 104, "indonesia");
   xsArraySetString(gMapNames, 105, "indonesialarge");
   xsArraySetString(gMapNames, 106, "kamchatka");
   xsArraySetString(gMapNames, 107, "kamchatkalarge");
   xsArraySetString(gMapNames, 108, "korea");
   xsArraySetString(gMapNames, 109, "korealarge");
   xsArraySetString(gMapNames, 110, "malaysia");
   xsArraySetString(gMapNames, 111, "malaysialarge");
   xsArraySetString(gMapNames, 112, "manchuria");
   xsArraySetString(gMapNames, 113, "manchurialarge");
   xsArraySetString(gMapNames, 114, "mexico");
   xsArraySetString(gMapNames, 115, "mexicolarge");
   xsArraySetString(gMapNames, 116, "minasgerais");
   xsArraySetString(gMapNames, 117, "minasgeraislarge");
   xsArraySetString(gMapNames, 118, "mongolia");
   xsArraySetString(gMapNames, 119, "mongolialarge");
   xsArraySetString(gMapNames, 120, "new england");
   xsArraySetString(gMapNames, 121, "new englandlarge");
   xsArraySetString(gMapNames, 122, "northwest territory");
   xsArraySetString(gMapNames, 123, "northwest territorylarge");
   xsArraySetString(gMapNames, 124, "orinoco");
   xsArraySetString(gMapNames, 125, "orinocolarge");
   xsArraySetString(gMapNames, 126, "ozarks");
   xsArraySetString(gMapNames, 127, "ozarkslarge");
   xsArraySetString(gMapNames, 128, "painted desert");
   xsArraySetString(gMapNames, 129, "painted desertlarge");
   xsArraySetString(gMapNames, 130, "pampas sierras");
   xsArraySetString(gMapNames, 131, "pampas sierraslarge");
   xsArraySetString(gMapNames, 132, "pampas");
   xsArraySetString(gMapNames, 133, "pampas large");
   xsArraySetString(gMapNames, 134, "parallel rivers");
   xsArraySetString(gMapNames, 135, "parallel riverslarge");
   xsArraySetString(gMapNames, 136, "patagonia");
   xsArraySetString(gMapNames, 137, "patagonialarge");
   xsArraySetString(gMapNames, 138, "plymouth");
   xsArraySetString(gMapNames, 139, "plymouthlarge");
   xsArraySetString(gMapNames, 140, "punjab");
   xsArraySetString(gMapNames, 141, "punjablarge");
   xsArraySetString(gMapNames, 142, "rockies");
   xsArraySetString(gMapNames, 143, "rockieslarge");
   xsArraySetString(gMapNames, 144, "saguenay");
   xsArraySetString(gMapNames, 145, "saguenaylarge");
   xsArraySetString(gMapNames, 146, "siberia");
   xsArraySetString(gMapNames, 147, "siberialarge");
   xsArraySetString(gMapNames, 148, "silkroad");
   xsArraySetString(gMapNames, 149, "silkroadlarge");
   xsArraySetString(gMapNames, 150, "sonora");
   xsArraySetString(gMapNames, 151, "sonoralarge");
   xsArraySetString(gMapNames, 152, "texas");
   xsArraySetString(gMapNames, 153, "texaslarge");
   xsArraySetString(gMapNames, 154, "unknown");
   xsArraySetString(gMapNames, 155, "unknownlarge");
   xsArraySetString(gMapNames, 156, "yellow riverdry");
   xsArraySetString(gMapNames, 157, "yellow riverdrylarge");
   xsArraySetString(gMapNames, 158, "yucatan");
   xsArraySetString(gMapNames, 159, "yucatanlarge");
   xsArraySetString(gMapNames, 160, "yukon");
   xsArraySetString(gMapNames, 161, "yukonlarge");
   xsArraySetString(gMapNames, 162, "aftranssahara");
   xsArraySetString(gMapNames, 163, "aftranssaharalarge");
   xsArraySetString(gMapNames, 164, "aflostsahara");
   xsArraySetString(gMapNames, 165, "aflostsaharalarge");
   xsArraySetString(gMapNames, 166, "guianas");
   xsArraySetString(gMapNames, 167, "guianaslarge");
   xsArraySetString(gMapNames, 168, "panama");
   xsArraySetString(gMapNames, 169, "panamalarge");
   xsArraySetString(gMapNames, 170, "texasfrontier");
   xsArraySetString(gMapNames, 171, "texasfrontierlarge");
   xsArraySetString(gMapNames, 172, "aflakevictoria");
   xsArraySetString(gMapNames, 173, "aflakevictorialarge");
   xsArraySetString(gMapNames, 174, "afarabia");
   xsArraySetString(gMapNames, 175, "afarabialarge");
   xsArraySetString(gMapNames, 176, "afcongobasin");
   xsArraySetString(gMapNames, 177, "afcongobasinlarge");
   xsArraySetString(gMapNames, 178, "eualps");
   xsArraySetString(gMapNames, 179, "eualpslarge");
   xsArraySetString(gMapNames, 180, "euantolia");
   xsArraySetString(gMapNames, 181, "euanatolialarge");
   xsArraySetString(gMapNames, 182, "euarchipelago");
   xsArraySetString(gMapNames, 183, "euarchipelagolarge");
   xsArraySetString(gMapNames, 184, "eubalkans");
   xsArraySetString(gMapNames, 185, "eubalkanslarge");
   xsArraySetString(gMapNames, 186, "eublackforest");
   xsArraySetString(gMapNames, 187, "eublackforestlarge");
   xsArraySetString(gMapNames, 188, "eubohemia");
   xsArraySetString(gMapNames, 189, "eubohemialarge");
   xsArraySetString(gMapNames, 190, "eucarpathians");
   xsArraySetString(gMapNames, 191, "eucarpathianslarge");
   xsArraySetString(gMapNames, 192, "eudanishstrait");
   xsArraySetString(gMapNames, 193, "eudanishstraitlarge");
   xsArraySetString(gMapNames, 194, "eudeluge");
   xsArraySetString(gMapNames, 195, "eudnieperbasin");
   xsArraySetString(gMapNames, 196, "eudnieperbasinlarge");
   xsArraySetString(gMapNames, 197, "eueightyyearswar");
   xsArraySetString(gMapNames, 198, "euengland");
   xsArraySetString(gMapNames, 199, "euenglandlarge");
   xsArraySetString(gMapNames, 200, "eufinland");
   xsArraySetString(gMapNames, 201, "eufinlandlarge");
   xsArraySetString(gMapNames, 202, "eufrance");
   xsArraySetString(gMapNames, 203, "eufrancelarge");
   xsArraySetString(gMapNames, 204, "eugreatnorthernwar");
   xsArraySetString(gMapNames, 205, "eugreatturkishwar");
   xsArraySetString(gMapNames, 206, "euhungarianplans");
   xsArraySetString(gMapNames, 207, "euhungarianplanslarge");
   xsArraySetString(gMapNames, 208, "euiberia");
   xsArraySetString(gMapNames, 209, "euiberialarge");
   xsArraySetString(gMapNames, 210, "euireland");
   xsArraySetString(gMapNames, 211, "euirelandlarge");
   xsArraySetString(gMapNames, 212, "euitalianwars");
   xsArraySetString(gMapNames, 213, "euitaly");
   xsArraySetString(gMapNames, 214, "euitalylarge");
   xsArraySetString(gMapNames, 215, "eulowcountries");
   xsArraySetString(gMapNames, 216, "eulowcountrieslarge");
   xsArraySetString(gMapNames, 217, "eunapoleonicwars");
   xsArraySetString(gMapNames, 218, "eupripetmarshes");
   xsArraySetString(gMapNames, 219, "eupripetmarsheslarge");
   xsArraySetString(gMapNames, 220, "eupyrenees");
   xsArraySetString(gMapNames, 221, "eupyreneeslarge");
   xsArraySetString(gMapNames, 222, "eurussoturkwar");
   xsArraySetString(gMapNames, 223, "eusardiniacorsica");
   xsArraySetString(gMapNames, 224, "eusardiniacorsicalarge");
   xsArraySetString(gMapNames, 225, "eusaxony");
   xsArraySetString(gMapNames, 226, "eusaxonylarge");
   xsArraySetString(gMapNames, 227, "euscandinavia");
   xsArraySetString(gMapNames, 228, "euscandinavialarge");
   xsArraySetString(gMapNames, 229, "euthirtyyearswar");
   xsArraySetString(gMapNames, 230, "euvistulabasin");
   xsArraySetString(gMapNames, 231, "euvistulabasinlarge");
   xsArraySetString(gMapNames, 232, "euwallachia");
   xsArraySetString(gMapNames, 233, "euwallachialarge");

   // AssertiveWall: Pirates of the Carribean Maps:
   xsArraySetString(gMapNames, 234, "zpburma_b");
   xsArraySetString(gMapNames, 235, "zpdeadsea");
   xsArraySetString(gMapNames, 236, "zpeldorado");
   xsArraySetString(gMapNames, 237, "zpmalta");
   xsArraySetString(gMapNames, 238, "zptortuga");
   xsArraySetString(gMapNames, 239, "zpcoldwar");
   xsArraySetString(gMapNames, 240, "zptreasureisland");
   xsArraySetString(gMapNames, 241, "zpphilippines");
   
   // List above is up to date for the Italy/Malta release.

}

//==============================================================================
/* analyzeGameSettingsAndType
   Set up all variables related to game settings and type.
*/
//==============================================================================
void analyzeGameSettingsAndType()
{
   debugSetup("***Analyzing Game Settings And Type***");
   // cGameTypeCurrent hasn't been initialized yet at this point so must use the syscall.
   int gameType = aiGetGameType();
   if ((gameType == cGameTypeCampaign) || (gameType == cGameTypeScenario))
   {
      gSPC = true;
      cvOkToResign = false; // Default is to not allow resignation in SPC.
   }
   // Taunt defaults to true, but needs to be false in gSPC games.
   if (gSPC == true)
   {
      cvOkToTaunt = false;
   }
   else // Deck building defaults to false like how it was in legacy, but we do make decks in non-SPC now.
   {
      cvOkToBuildDeck = true;
      
      // Game ending handler, to save game-to-game data before game ends.
      // There are no personality files during SPC so this doesn't work at all there.
      aiSetHandler("gameOverHandler", cXSGameOverHandler);
   }
   
   debugSetup("Game type is: " + gameType + ", 0=Scenario, 2=Random Map, 4=Campaign");
   debugSetup("gSPC is: " + gSPC);
   
   // Set the max age here - this can be overridden in preInit.
   cvMaxAge = aiGetMaxAge();
   
   // Setup the handicaps.
   // StartingHandicap is the handicap set at game launch in the UI, i.e. boost this player 10% == 1.10.  That needs to
   // be multiplied by the appropriate difficulty for each level.
   float startingHandicap = kbGetPlayerHandicap(cMyID);
   int maxPop = kbGetMaxPop();

   switch (cDifficultyCurrent)
   {
      case cDifficultySandbox: // Easy.
   {
         kbSetPlayerHandicap(cMyID, startingHandicap * 0.3); // Set handicap to a small fraction of baseline, i.e. minus 70%.
      cvOkToBuildForts = false;
      gMaxPop = 40;
      break;
   }
      case cDifficultyEasy: // Standard.
   {
      if (gSPC == true)
      {
            kbSetPlayerHandicap(cMyID, startingHandicap * 0.5); // Minus 50 percent for scenarios.
         gMaxPop = 55;
      }
      else
      {
            kbSetPlayerHandicap(cMyID, startingHandicap * 0.4); // Minus 60 percent.
         gMaxPop = 70;
      }

         gAttackMissionInterval = 480000; // 8 Minutes.
         cvOkToBuildForts = false;
      gDelayAttacks = true;
      break;
   }
      case cDifficultyModerate: // Moderate.
   {
         gAttackMissionInterval = 300000; // 5 Minutes.
      if (gSPC == true)
      {
            kbSetPlayerHandicap(cMyID, startingHandicap * 0.75); // Minus 25% for scenarios.
         gMaxPop = 105;
      }
      else
      {
            kbSetPlayerHandicap(cMyID, startingHandicap * 0.65); // Minus 35%.
         gMaxPop = 120;
      }
      break;
   }
      case cDifficultyHard: // Hard.
   {
         kbSetPlayerHandicap(cMyID, startingHandicap * 1.0); // 1.0 Handicap at hard, i.e. no bonus.
      if (gSPC == true)
      {
         aiSetMicroFlags(cMicroLevelHigh);
            gAttackMissionInterval = 180000; // 3 Minutes.
         gMaxPop = 185;
         // Playing on hard in the campaign is a little bit different than Random Map hard.
         // We enable some stuff for the SPC Hard AI that RM Hard AI doesn't have.
         gDifficultyExpert = cDifficultyHard;
      }
      else
      {  // AssertiveWall: Interval decreased to 2 minutes 
         gMaxPop = maxPop;
         aiSetMicroFlags(cMicroLevelNormal);
            gAttackMissionInterval = 120000; // 2.5 Minutes.
      }
      break;
   }
      case cDifficultyExpert: // Hardest.
   {  // AssertiveWall: +22% (up from +15%). Interval decreased to 1 min
      gMaxPop = maxPop;
         gAttackMissionInterval = 60000; // 2 Minutes.
         kbSetPlayerHandicap(cMyID, startingHandicap * 1.15); // +15% Boost.
      aiSetMicroFlags(cMicroLevelHigh);
      break;
   }
      case cDifficultyExtreme: // Extreme.
   {  // AssertiveWall: +50% (up from +30%). Interval decreased to 1 min
      gMaxPop = maxPop;
         gAttackMissionInterval = 60000; // 2 Minutes.
         kbSetPlayerHandicap(cMyID, startingHandicap * 1.30); // +30% Boost.
      aiSetMicroFlags(cMicroLevelHigh);
      break;
   }
   }
   // We can overwrite gMaxPop on one more occasion after we've initialized the cv variables.
   // We must safeguard against lower population custom settings.
   if (gMaxPop > maxPop)
   {
      gMaxPop = maxPop;
   }
   
   // We don't have a Settler maintain plan yet but that doesn't matter, call this to set a proper military pop.
   updateSettlersAndPopManager();

   debugSetup("Handicap is " + kbGetPlayerHandicap(cMyID));
   debugSetup("Difficulty is " + cDifficultyCurrent + ", 0=Easy, 1=Standard, 2=Moderate, 3=Hard, 4=Hardest, 5=Extreme");
}

//==============================================================================
/* analyzeMap
   Set up all variables related to the map layout, excluding our starting units.
*/
//==============================================================================
void analyzeMap()
{
   debugSetup("***Analyzing Map***");
   debugSetup("Map name is: " + cRandomMapName);

   // Disable any LOST maps.
   if ((cRandomMapName == "afLOSTSahara") || (cRandomMapName == "afLOSTSaharaLarge"))
   {
      aiErrorMessageId(111386); // "This map cannot be played by the AI."
      cvInactiveAI = true;
   }
   
   // Initialize all the global water variables so we know what we're dealing with on this map.
   gWaterSpawnFlagID = getUnit(cUnitTypeHomeCityWaterSpawnFlag, cMyID);
   if (gWaterSpawnFlagID >= 0)
   {
      gNavyVec = kbUnitGetPosition(gWaterSpawnFlagID);
      gHaveWaterSpawnFlag = true;
      gNavyMap = true;
      gLastWSTime = 0; // AssertiveWall: Time counter needed to prevent AI from making suicide docks
   }
   
   if (gSPC == true)
   {
      // This map type has to be set inside of the scenario itself via the editor.
      if (aiIsMapType("AIFishingUseful") == true)
      {
         gGoodFishingMap = true;
      }
      else
      {
         gGoodFishingMap = false;
      }
   }
   else
   {
      // Basically if we find any fish on the map we decide it's a good fishing map.
      if (getGaiaUnitCount(cUnitTypeFish) > 0)
      {
         if (gNavyVec == cInvalidVector) // We need to actually set the gNavyVec otherwise our Dock placement fails.
         {
            gNavyVec = getClosestGaiaUnitPosition(cUnitTypeAbstractFish, getStartingLocation());
            gNavyMap = true;
         }
         gGoodFishingMap = true;
      }
   }
   debugSetup("gWaterSpawnFlagID: " + gWaterSpawnFlagID + ", gHaveWaterSpawnFlag: " + gHaveWaterSpawnFlag);
   debugSetup("gNavyVec: " + gNavyVec + ", gNavyMap: " + gNavyMap + ", gGoodFishingMap: " + gGoodFishingMap);
   
   // This will create an interim main base at the location of any unit we do posses, since we lack a Town Center.
   // Only done if there is no TC, otherwise we rely on the auto-created base.
   int townCenterID = getUnit(cUnitTypeAgeUpBuilding, cMyID, cUnitStateAlive);
   vector baseVec = cInvalidVector;
   if (townCenterID < 0)
   {
      vector tempBaseVec = cInvalidVector;
      int unitID = getUnit(cUnitTypeAIStart, cMyID, cUnitStateAlive);
      if (unitID < 0)
      {
         unitID = getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);
      }
      if (unitID < 0)
      {
         unitID = getUnit(cUnitTypeHero, cMyID, cUnitStateAlive);
      }
      if (unitID < 0)
      {
         unitID = getUnit(cUnitTypeAbstractVillager, cMyID, cUnitStateAlive);
      }
      if (unitID < 0)
      {
         unitID = getUnit(cUnitTypeUnit, cMyID, cUnitStateAlive);
      }
   
      if (unitID < 0)
      {
         debugSetup("**** I give up... I can't find an aiStart object, Covered Wagon, Explorer, Settler or any unit."
            + " How do you expect me to play?!");
      }
      else
      {
         baseVec = kbUnitGetPosition(unitID);
         gMainBase = createMainBase(baseVec);
         kbBaseSetMain(cMyID, gMainBase, true);
         gOriginalBase = gMainBase; // AssertiveWall: Stores this base as the original
         debugSetup("Temporary main base ID is: " + kbBaseGetMainID(cMyID));
      }
   }
   else 
   {
      baseVec = kbUnitGetPosition(townCenterID);
   }
   
   // Check for island map and starting on different islands.
   vector tempPlayerVec = cInvalidVector;
   int tempBaseVecAreaGroupID = kbAreaGroupGetIDByPosition(baseVec);
   gIslandMap = kbGetIslandMap();
   for (player = 1; < cNumberPlayers)
   {
      if (player == cMyID)
      {
         continue;
      }
      tempPlayerVec = kbGetPlayerStartingPosition(player);
      if (tempPlayerVec == cInvalidVector)
      {
         continue;
      }
      if (kbAreAreaGroupsPassableByLand(tempBaseVecAreaGroupID, kbAreaGroupGetIDByPosition(tempPlayerVec)) == false)
      {
         gStartOnDifferentIslands = true;
         break;
      }
   }

   // AssertiveWall: Check for Pirate Maps and set gStartOnDIfferentIslands true for all of them
   if (cRandomMapName == "zpburma_b" ||
       cRandomMapName == "zpdeadsea" ||
       cRandomMapName == "zpeldorado" ||
       cRandomMapName == "zpmalta" ||
       cRandomMapName == "zptortuga" ||
       cRandomMapName == "zpcoldwar" ||
       cRandomMapName == "zptreasureisland" ||
       cRandomMapName == "zpphilippines")
   {
      gStartOnDifferentIslands = true;
      gIsPirateMap = true;
      gNavyMap = true;
      xsEnableRule("initializePirateRules");

      gClaimNativeMissionInterval = 3 * 60 * 1000; // 3 minutes, down from 10
      gClaimTradeMissionInterval = 4 * 60 * 1000; // 4 minutes, down from 5
   }

   debugSetup("Island map is " + gIslandMap + ", players start on different islands is " + gStartOnDifferentIslands);
   
   // On these maps we want to transport, which is what aiSetWaterMap is used for.
   if (gStartOnDifferentIslands == true)
   {
      aiSetWaterMap(true);
   }
}

//==============================================================================
/* initXSHandlers
   Set up all XS handlers that don't depend on control variables.
*/
//==============================================================================
void initXSHandlers()
{
   debugSetup("***Setting up XSHandlers***");
   // Set up the age-up handler, this is used for chats and saving fastest age up times.
   aiSetHandler("ageUpHandler", cXSPlayerAgeHandler);

   // Set up the communication handler, this is the menu where you can ask your allied AI to do something.
   // Even though this menu won't function in gSPC we still set up the handler so the AI can constantly refuse.
   aiCommsSetEventHandler("commHandler");

   if (civIsEuropean() == true)
   {
   // Called when we've revolted.
   aiSetHandler("revoltedHandler", cXSRevoltedHandler);
   }

   // Called when the engine couldn't find a proper placement for our building.
   aiSetHandler("buildingPlacementFailedHandler", cXSBuildingPlacementFailedHandler);
}

//==============================================================================
/* initPersonality
   A function to set defaults that need to be in place before the loader file's
   preInit() function is called.
*/
//==============================================================================
void initPersonality(void)
{
   debugSetup("***Initializing personality***");

   // Set behavior traits.
   debugSetup("My civ is " + kbGetCivName(cMyCiv));
   switch (cMyCiv)
   {
      case cCivBritish: // Elizabeth: Infantry oriented.
   case cCivTheCircle:
   case cCivPirate:
   case cCivSPCAct3:
   {
         btRushBoom = 0.0;
      if (aiRandInt(10) < 6)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.5;
      btBiasCav = -0.4;
      btBiasInf = 0.4;
      btBiasArt = 0.0;
         btBiasNative = 0.5;
         btBiasTrade = 0.0;
      break;
   }
   case cCivFrench: // Napoleon:  Cav oriented, balanced
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 3)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.3;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
         btBiasNative = 0.5;
      btBiasTrade = 0.0;
      break;
   }
      case cCivSpanish: // Isabella: Bias against natives.
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 4)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 1.0;
      btBiasCav = -0.4;
      btBiasInf = 0.4;
      btBiasArt = 0.0;
      btBiasNative = -0.0;
      btBiasTrade = -1.0;
      break;
   }
   case cCivRussians: // Ivan:  Infantry oriented rusher
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 9)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.5;
      btBiasCav = -0.4;
      btBiasInf = 0.4;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
         btBiasTrade = 0.5;
      break;
   }
   case cCivGermans: // Fast fortress, cavalry oriented
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 2)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.2;
      btBiasInf = -0.2;
      btBiasArt = 0.0;
      btBiasNative = -0.5;
      btBiasTrade = 0.0;
      break;
   }
   case cCivDutch: // Fast fortress, ignore trade routes.
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 3)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
         btBiasTrade = -0.5;
      break;
   }
   case cCivPortuguese: // Fast fortress, artillery oriented
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 2)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
         btBiasCav = 0.0;
      btBiasInf =    0.0;
         btBiasArt = 0.2;
      btBiasNative = 0.0;
      btBiasTrade = 0.0;
      break;
   }
   case cCivOttomans: // Artillery oriented, rusher
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 8)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.5;
      btBiasCav = -0.3;
      btBiasInf = 0.3;
      btBiasArt = 0.1;
         btBiasNative = 0.3;
         btBiasTrade = 1.0;
      break;
   }
   case cCivXPSioux: // Extreme rush
   {
      btRushBoom = 0.8;
      if (aiRandInt(10) < 1)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.5;
         btBiasCav = 0.4;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
         btBiasTrade = 0.8;
      break;
   }
   case cCivXPIroquois: // Fast fortress, trade and native bias.
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 4)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
         btBiasInf = 0.2;
      btBiasArt = 0.0;
      btBiasNative = 0.8;
      btBiasTrade = 1.0;
      break;
   }
   case cCivXPAztec: // Rusher.
   {
      btRushBoom = 0.0;
         btOffenseDefense = 0.0;
      if (aiRandInt(10) < 8)
      {
         btRushBoom = 0.5;
         btOffenseDefense = 1.0;
      }
      btBiasCav = 0.0;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      if (aiRandInt(10) < 3)
      {
         btBiasNative = 1.0;
      }
      btBiasTrade = 1.0;
      break;
   }
   case cCivChinese: // Kangxi:  Fast fortress, infantry oriented
   {
      btRushBoom = 0.0;
      if (aiRandInt(10) < 4)
      {
         btRushBoom = 0.5;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
      btBiasInf = 0.2;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      btBiasTrade = 0.0;
      break;
   }
   case cCivJapanese: // Shogun Tokugawa Ieyasu: Rusher, ignores trade routes
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 3)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = -0.4;
         btBiasInf = 0.4;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
         btBiasTrade = 0.0;
      break;
   }
   case cCivIndians: // Rusher, balanced
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 5)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
         btBiasCav = 0.0; 
      btBiasInf = 0.0;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      btBiasTrade = 0.5;
      break;
   }
   case cCivDEInca: // Huayna Capac: Rusher, trade and strong native bias.
   {
      btRushBoom = 0.5;
      if (aiRandInt(2) > 0)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
         btBiasInf = 0.3;
      btBiasArt = 0.0;
      btBiasNative = 1.0;
         btBiasTrade = 0.5; // Use Tambos.
      break;
   }
   case cCivDESwedish: // Gustav the Great: Rusher, small artillery focus.
   {
      btRushBoom = 0.7;
      if (aiRandInt(10) < 3)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.6;
      btBiasCav = 0.0;
      btBiasInf = 0.0;
      btBiasArt = 0.1;
      btBiasNative = 0.0;
      btBiasTrade = -0.5;
      break;
   }
   case cCivDEAmericans: // George Washington: Balanced.
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 5)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
         btBiasInf = 0.2;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      btBiasTrade = -0.5;
      break;
   }
      case cCivDEEthiopians: // Emperor Tewodros: Bias towards building TPs.
   {
      btRushBoom = 0.0;
      btOffenseDefense = 0.0;
      btBiasCav = -0.3;
         btBiasInf = 0.4;
      btBiasArt = 0.0;
         btBiasNative = 1.0;
         btBiasTrade = 0.4;
      break;
   }
      case cCivDEHausa: // Queen Amina: Bias towards building TPs.
   {
      btRushBoom = 0.0;
      btOffenseDefense = 0.0;
         btBiasCav = 0.2;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
         btBiasNative = 1.0;
         btBiasTrade = 0.4;
      break;
   }
   case cCivDEMexicans: // Miguel Hidalgo: Balanced.
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 5)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = -0.4;
      btBiasInf = 0.4;
         btBiasArt = -0.3;
      btBiasNative = 0.0;
      btBiasTrade = -0.5;
      break;
   }
   case cCivDEItalians: // Guiseppe Garibaldi: Balanced.
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 5)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = 0.0;
      btBiasInf = 0.0;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      btBiasTrade = 0.0;
      break;
   }
   case cCivDEMaltese: // Jean Parisot: Balanced.
   {
      btRushBoom = 0.5;
      if (aiRandInt(10) < 5)
      {
         btRushBoom = 0.0;
      }
      btOffenseDefense = 0.0;
      btBiasCav = -0.4;
      btBiasInf = 0.4;
      btBiasArt = 0.0;
      btBiasNative = 0.0;
      btBiasTrade = 0.0;
      break;
   }      
   }

   if (gSPC == false)
   { // Occasionally adjust AI preferences for more replayability without going overboard.
      int strategyRandomizer = aiRandInt(16);
      if (strategyRandomizer == 0)
      {
         btBiasCav += 0.4;
      }
      else if (strategyRandomizer == 1)
      {
         btBiasCav += 0.4;
      }
      else if (strategyRandomizer == 2)
      {
         btBiasCav -= 0.4;
      }
      else if (strategyRandomizer == 3)
      {
         btBiasCav -= 0.4;
      }
      else if (strategyRandomizer == 4)
      {
         btBiasInf += 0.4;
      }
      else if (strategyRandomizer == 5)
      {
         btBiasInf += 0.4;
      }
      else if (strategyRandomizer == 6)
      {
         btBiasInf -= 0.4;
      }
      else if (strategyRandomizer == 7)
      {
         btBiasInf -= 0.4;
      }  
   }

   if (((aiTreatyActive() == true) || (aiGetGameMode() == cGameModeDeathmatch)) && 
       (btRushBoom > 0.0))
   {
      btRushBoom = 0.0; // Don't attempt to rush in treaty or deathmatch games.
   }
   
   // We don't allow these variables to go over 1.0 or under -1.0, 
   // and they could via the randomizer so safeguard against this.
   if (btBiasCav > 1.0)
   {
      btBiasCav = 1.0;
   }
   if (btBiasCav < -1.0)
   {
      btBiasCav = -1.0;
   }
      
   if (btBiasInf > 1.0)
   {
      btBiasInf = 1.0;
   }
   if (btBiasInf < -1.0)
   {
      btBiasInf = -1.0;
   }

   // AssertiveWall: Adjust Native and Trade bias on pirate maps to be very high
   if (gIsPirateMap == true)
   {
      // Make everyone go for natives
      if (btBiasNative < 0.4)
      {
         btBiasNative = 0.5;
      }
      else if (btBiasNative < 0.8)
      {
         btBiasNative = btBiasNative + 0.1;
      }   

      // Same for trade
      if (btBiasTrade < 0.4)
      {
         btBiasTrade = 0.4;
      }
      else if (btBiasTrade < 0.8)
      {
         btBiasTrade = btBiasTrade + 0.1;
      } 
      //btBiasNative = 0.9;
      //btBiasTrade = 0.9;

   }
}
      
//==============================================================================
/* startUpChats
   Analyze our history with the players in the game and send them an appropriate message.

   Save these user vars here:
   wasMyAllyLastGame
   lastGameDifficulty
   lastMapID
   myEnemyCount
   myAllyCount

   The other used user vars will be saved by gameOverHandler.
*/
//==============================================================================
void startUpChats()
{
   debugSetup("***Sending start up chats***");

   for (pid = 1; < cNumberPlayers)
   {
      // Skip ourself.
      if (pid == cMyID)
      {
         continue;
      }

      // Get player name. This also works for playing against other AI we then get the personalities' name.
      string playerName = kbGetPlayerName(pid);
      debugSetup("PlayerName: " + playerName);
      int mapID = getMapID();

      // Have we played against them before?
      int playerHistoryID = aiPersonalityGetPlayerHistoryIndex(playerName);
      if (playerHistoryID == -1)
      {
         debugSetup("Never played against: " + playerName);
         // Lets make a new player history.
         playerHistoryID = aiPersonalityCreatePlayerHistory(playerName);
         if (playerHistoryID == -1)
         {
            debugSetup("WARNING: failed to create player history for " + playerName);
         }
         else
         {
            debugSetup("Created new history for player: " + playerName);
         }
         if (kbIsPlayerAlly(pid) == true)
         {
            sendStatement(pid, cAICommPromptToAllyIntro);
         }
         else
         {
            sendStatement(pid, cAICommPromptToEnemyIntro);
         }
      }
      else // We have a player history so we can send chats based on our history with them.
      {
         // Consider chats based on player history.

         bool wasAllyLastTime = true;
         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "wasMyAllyLastGame") == 0.0)
         {
            wasAllyLastTime = false;
         } 
         bool isAllyThisTime = true;
         if (kbIsPlayerAlly(pid) == false)
         {
            isAllyThisTime = false;
         }
         bool difficultyIsHigher = false;
         bool difficultyIsLower = false;
         int lastDifficulty = aiPersonalityGetPlayerUserVar(playerHistoryID, "lastGameDifficulty");
         if (lastDifficulty >= 0)
         {
            if (lastDifficulty > cDifficultyCurrent)
            {
               difficultyIsLower = true;
            }
            if (lastDifficulty < cDifficultyCurrent)
            {
               difficultyIsHigher = true;
         }
         }
         bool iBeatHimLastTime = false;
         bool heBeatMeLastTime = false;
         bool iCarriedHimLastTime = false;
         bool heCarriedMeLastTime = false;

         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "heBeatMeLastTime") == 1.0)
         {
            heBeatMeLastTime = true;
         }
         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "iBeatHimLastTime") == 1.0)
         {
            iBeatHimLastTime = true;
         }
         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "iCarriedHimLastTime") == 1.0)
         {
            iCarriedHimLastTime = true;
         }
         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "heCarriedMeLastTime") == 1.0)
         {
            heCarriedMeLastTime = true;
         }

         if (wasAllyLastTime == false)
         {
            if (aiPersonalityGetPlayerUserVar(playerHistoryID, "iBeatHimLastTime") == 1.0)
            {
               iBeatHimLastTime = true;
            }
            if (aiPersonalityGetPlayerUserVar(playerHistoryID, "heBeatMeLastTime") == 1.0)
            {
               heBeatMeLastTime = true;
         }
         }

         bool iWonLastGame = false;
         if (aiPersonalityGetPlayerUserVar(playerHistoryID, "iWonLastGame") == 1.0)
         {
            iWonLastGame = true;
         }

         // We've loaded all the variables, now start analyzing what chat to send.
         if (isAllyThisTime == true)
         {
            if (difficultyIsHigher == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenDifficultyHigher);
            }
            else if (difficultyIsLower == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenDifficultyLower);
            }
            else if (iCarriedHimLastTime == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenICarriedHimLastGame);
            }
            else if (heCarriedMeLastTime == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenHeCarriedMeLastGame);
            }
            else if (iBeatHimLastTime == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenIBeatHimLastGame);
            }
            else if (heBeatMeLastTime == true)
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenHeBeatMeLastGame);
            }
            else if ((mapID >= 0) && (mapID == aiPersonalityGetPlayerUserVar(playerHistoryID, "lastMapID")))
            {
               sendStatement(pid, cAICommPromptToAllyIntroWhenMapRepeats);
            }
            else if (wasAllyLastTime == true)
            {
               if (iWonLastGame == false)
               {
                  sendStatement(pid, cAICommPromptToAllyIntroWhenWeLostLastGame);
               }
               else
               {
                  sendStatement(pid, cAICommPromptToAllyIntroWhenWeWonLastGame);
            }
            }
            else // Default to a standard intro so we at least say something.
            {
               sendStatement(pid, cAICommPromptToAllyIntro);
            }
         }
         else // We are enemies.
         { 
            if (difficultyIsHigher == true)
            {
               sendStatement(pid, cAICommPromptToEnemyIntroWhenDifficultyHigher);
            }
            else if (difficultyIsLower == true)
            {
               sendStatement(pid, cAICommPromptToEnemyIntroWhenDifficultyLower);
            }
            else if ((mapID >= 0) && (mapID == aiPersonalityGetPlayerUserVar(playerHistoryID, "lastMapID")))
            {
               sendStatement(pid, cAICommPromptToEnemyIntroWhenMapRepeats);
            }
            else if (wasAllyLastTime == false) // Was enemy last game and now again.
            {
               // Check if he changed the odds.
               int allyCount = getAllyCount();
               int enemyCount = getEnemyCount();
               int previousEnemyCount = aiPersonalityGetPlayerUserVar(playerHistoryID, "myEnemyCount");
               int previousAllyCount = aiPersonalityGetPlayerUserVar(playerHistoryID, "myAllyCount");
               
               if (previousEnemyCount == enemyCount)
               {                                 
                  if (previousAllyCount > allyCount) // I have fewer allies now.
                  {
                     sendStatement(pid, cAICommPromptToEnemyIntroWhenTeamOddsEasier);
            }
                  if (previousAllyCount < allyCount) // I have more allies now.
            {
                     sendStatement(pid, cAICommPromptToEnemyIntroWhenTeamOddsHarder);
               }
               }
               else if (previousAllyCount == allyCount) // Else, check if allyCount is the same, but enemyCount is smaller.
               {
                  if (previousEnemyCount > enemyCount) // I have fewer enemies now.
                  {
                     sendStatement(pid, cAICommPromptToEnemyIntroWhenTeamOddsHarder);
            }
                  if (previousEnemyCount < enemyCount) // I have more enemies now.
                  {
                     sendStatement(pid, cAICommPromptToEnemyIntroWhenTeamOddsEasier);
                  }
               }
               else // Default to a standard intro so we at least say something.
               {
                  sendStatement(pid, cAICommPromptToEnemyIntro);
         }
      }
            else // Default to a standard intro so we at least say something.
            {
               sendStatement(pid, cAICommPromptToEnemyIntro);
            }
         }
      } // End of the chats, still in the for loop.

      // Save info about this game.
      aiPersonalitySetPlayerUserVar(playerHistoryID, "lastGameDifficulty", cDifficultyCurrent);
      int wasAlly = 0;
      if (kbIsPlayerAlly(pid) == true)
      {
         wasAlly = 1;
      }
      else
      { // He is an enemy, remember the odds (i.e. 1v3, 2v2, etc.).
         aiPersonalitySetPlayerUserVar(playerHistoryID, "myAllyCount", getAllyCount());
         aiPersonalitySetPlayerUserVar(playerHistoryID, "myEnemyCount", getEnemyCount());
      }
      aiPersonalitySetPlayerUserVar(playerHistoryID, "wasMyAllyLastGame", wasAlly);
      aiPersonalitySetPlayerUserVar(playerHistoryID, "lastMapID", mapID);
   }
}

//==============================================================================
/* preInitFinal
   Our bt/cv variables have been set to their final values.
   See if we must adjust anything we did before this point to account for this.
*/
//==============================================================================
void preInitFinal()
{
   debugSetup("***Finalizing everything related to setting cv / bt***");
   if (cvInactiveAI == true)
   {
      // Nothing else we do in Main matters anymore, just quit and let the AI completely idle.
      // We also prevent it from ever getting past the waitForStartup check.
      debugSetup("This is an inactive AI, aborting everything and idling forever");
      return;
   }
   
   // We disable gathering for now so we can focus on building, it is enabled again after the DM start.
   int startingResources = aiGetGameStartingResources();
   if ((aiGetGameMode() == cGameModeDeathmatch) || (((startingResources == cGameStartingResourcesInfinite) ||
       (startingResources == cGameStartingResourcesHigh) || (startingResources == cGameStartingResourcesUltra) ||
       (cRandomMapName == "euNapoleonicWars")) && (gSPC == false)))
   { // The starting resources aren't properly set for SPC so check for it.
      cvOkToGatherFood = false;
      cvOkToGatherGold = false;
      cvOkToGatherWood = false;
   }
   
   // Don't bother with making a lot of Villagers when we have infinite resources.
   if (startingResources == cGameStartingResourcesInfinite)
   {
      for (index = cAge1; <= cAge5)
      {
         xsArraySetInt(gTargetSettlerCounts, index, 10);
         xsArraySetInt(gTargetSettlerCountsDefault, index, 10);
      }
   }
   
   if (cvMaxCivPop > -1) // We must override the Settler targets we set previously if they're too high to
   {                     // account for this variable.
      for (index = cAge1; <= cAge5)
      {
         if (xsArrayGetInt(gTargetSettlerCounts, index) > cvMaxCivPop)
         {
            xsArraySetInt(gTargetSettlerCounts, index, cvMaxCivPop);
         }
      }
   }
   
   if ((cvMaxCivPop >= 0) && (cvMaxArmyPop >= 0)) // Both are defined so set an implied pop limit.
   {
      gMaxPop = cvMaxCivPop + cvMaxArmyPop;
      debugSetup("Both cvMaxCivPop and cvMaxArmyPop are defined, changing gMaxPop to: " + gMaxPop);
   }
   
   debugSetup("INITIAL BEHAVIOR SETTINGS");
   debugSetup("Rush / Boom: " + btRushBoom);
   debugSetup("Offense / Defense: " + btOffenseDefense);
   debugSetup("Cavalry bias: " + btBiasCav);
   debugSetup("Infantry: " + btBiasInf);
   debugSetup("Artillery: " + btBiasArt);
   debugSetup("Natives: " + btBiasNative);
   debugSetup("Trade: " + btBiasTrade);
   
   debugSetup("Our max age is set to: " + cvMaxAge + ", 0=Exploration, 1=Commerce, 2=Fortress, 3=Industrial, 4=Imperial");
}

//==============================================================================
/* prepareForInit
   Figure out our starting conditions, and deal with them.
*/
//==============================================================================
void prepareForInit()
{
   debugSetup("***Analyzing what type of start we have in preparation of activating AI***");
   if (gSPC == true)
   {
      // Wait for the aiStart object to appear, then figure out what to do.
      xsEnableRule("waitForStartup");
   }
   else // Random Map game.
   {
      aiSetRandomMap(true);
      // Now let's figure out if we're dealing with a regular Town Center start or with Nomad.
      if (kbUnitCount(cMyID, cUnitTypeAgeUpBuilding, cUnitStateAlive) > 0)
      {
         debugSetup("Start mode: Land Town Center (Command Post)");
         gStartMode = cStartModeLandTC;
         init(); // Call init directly and thus start the AI without delay.
      }
      else // This must be a Nomad start.
      {
         if (kbUnitCount(cMyID, cUnitTypeCoveredWagon, cUnitStateAlive) > 0)
         {
            debugSetup("Start mode: Land Wagon (Nomad)");
            gStartMode = cStartModeLandWagon;
         }
         else
         {
            debugSetup("Start mode: Land Resources (Nomad)");
            gStartMode = cStartModeLandResources;
         }
         
         if (cRandomMapName == "Ceylon")
         {
            initCeylonNomadStart(); // Transport our Covered Wagon to the mainland on Ceylon.
         }
         else
         {
            xsEnableRule("initRule"); // This will call init() after 3 seconds of delay.
         }
      }
   }
}

//==============================================================================
/* waitForStartup
   During Campaigns and Scenarios the AI doesn't automatically start working for real.
   It will wait until an AIStart object has been found, thus we query for it a lot.
   After we find it we figure out our starting conditions, and deal with them.
*/
//==============================================================================
rule waitForStartup
inactive
minInterval 1
{
   if (cvInactiveAI == true)
   {
      xsDisableSelf();
      return;
   }
   
   if (kbUnitCount(cMyID, cUnitTypeAIStart, cUnitStateAny) < 1)
   {
      return;
   }

   if (kbUnitCount(cMyID, cUnitTypeAgeUpBuilding, cUnitStateAlive) > 0)
   {
      debugSetup("Start mode: Scenario / Campaign with Town Center");
      gStartMode = cStartModeScenarioTC;
      init(); // Call init directly and thus start the AI without delay.
   }
   else
   {
      if (kbUnitCount(cMyID, cUnitTypeCoveredWagon, cUnitStateAlive) > 0)
      {
         debugSetup("Start mode: Scenario / Campaign with Covered Wagon");
         gStartMode = cStartModeScenarioWagon;
         xsEnableRule("initRule"); // This will call init() after 3 seconds of delay.
      }
      else
      {
         debugSetup("Start mode: Scenario / Campaign, without Town Center");
         gStartMode = cStartModeScenarioNoTC;
         init(); // Call init directly and thus start the AI without delay.
      }
   }
   xsDisableSelf();
}

//==============================================================================
// initRule
// Add a brief delay to make sure the build plan with the Covered Wagon doesn't bug out.
//==============================================================================
rule initRule
inactive
minInterval 3
{
   debugSetup("***Delayed calling of init()***");
   init(); // Actually enable the entire AI.
   xsDisableSelf();
}

//==============================================================================
// initEcon
// Set up our initial economy so we're ready to start gathering.
//==============================================================================
void initEcon(void)
{
   debugSetup("***Initialising economy***");
   
   // Adjust target Settler counts based on train limit, to take some custom rules into account.
   // Civs with dynamically increasing BLs need to be handled differently so we don't limit this array to low values at the
   // start of the game.
   if (cMyCiv != cCivOttomans)
   {
      int settlerLimit = kbGetBuildLimit(cMyID, gEconUnit);
      for (index = cAge1; <= cAge5)
      {
         if (xsArrayGetInt(gTargetSettlerCounts, index) > settlerLimit)
         {
            xsArraySetInt(gTargetSettlerCounts, index, settlerLimit);
         }
      }
   }
   
   // Make sure every ship that can fish will be used to do so.
   aiAddGathererType(cUnitTypeAbstractFishingBoat);

   int tcID = getUnit(cUnitTypeAgeUpBuilding, cMyID, cUnitStateAlive);
   
   // Create a herd plan to gather all herdables that we encounter.
   gHerdPlanID = aiPlanCreate("Gather Herdable Plan", cPlanHerd);
   if (gHerdPlanID >= 0)
   {
      aiPlanAddUnitType(gHerdPlanID, cUnitTypeHerdable, 0, 100, 100);
      aiPlanSetVariableInt(gHerdPlanID, cHerdPlanBuildingTypeID, 0, kbUnitGetProtoUnitID(tcID));
      aiPlanSetVariableFloat(gHerdPlanID, cHerdPlanDistance, 0, 5.0);
      aiPlanSetActive(gHerdPlanID);
   }
   
   // These numbers belonged to the now deprecated eco system
   // They're just used by other eco plans not being the main gathering.
   kbSetTargetSelectorFactor(cTSFactorDistance, -200.0); // negative is good
   kbSetTargetSelectorFactor(cTSFactorPoint, 5.0);       // positive is good
   kbSetTargetSelectorFactor(cTSFactorTimeToDone, 0.0);  // positive is good
   kbSetTargetSelectorFactor(cTSFactorBase, 100.0);      // positive is good
   kbSetTargetSelectorFactor(cTSFactorDanger, -10.0);    // negative is good

   // The AI no longer uses the legacy system of gathering and spending resources.
   // The 5 commands below basically turn off the old system and enable the new one.
   
   // let the engine decide which farm to set on food or gold.
   aiSetTacticFarm(gFarmFoodTactic >= 0);
   
   // By turning on we let the engine automatically handle unit gather rate differences 
   // when allocating gatherers among resources.
   aiSetDistributeGatherersByResourcePercentage(true);
   
   // Instead of creating a fixed amount of gather plans, create a new gather plan for each resource that
   // is closest to the resource type gatherers being asked to gather.
   aiSetDistributeGatherersByClosestResource(true);
   
   // Disable escrows so we can have full control of our resources, even though you sometimes still
   // have to provide escrows for certain syscalls they are completely ignored.
   aiSetEscrowsDisabled(true);             
   
   // Enable resource priority for plans.
   aiSetPlanResourcePriorityEnabled(true); 

   if ((cMyCiv != cCivJapanese) && (cMyCiv != cCivSPCJapanese) && (cMyCiv != cCivSPCJapaneseEnemy))
   {
      if (cDifficultyCurrent >= gDifficultyExpert)
      {
         xsEnableRule("backHerdMonitor");
      }
   }
   
   // The Cows only spawn when you have your first Town Center.
   if ((civIsAfrican() == true) && 
       (tcID >= 0))
   {
      xsEnableRule("earlySlaughterMonitor");
      earlySlaughterMonitor();
   }

   if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
   {  
      vector mainBaseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
      // We are Japanese and we only want to continue if we have a valid food source.
      if ((getUnitCountByLocation(cUnitTypeBerryBush, cMyID, cUnitStateAny, mainBaseLocation, 30.0) > 0) ||
          (getUnitCountByLocation(cUnitTypeypBerryBuilding, 0, cUnitStateAny, mainBaseLocation, 30.0) > 0))
      {
         initResourceBreakdowns();
      }
      else // Wait until the first Cherry Orchard is built if we have no Berry Bushes.
      {
         xsEnableRule("initResourceBreakdownsDelay");
      }
   }
   else
   {
      initResourceBreakdowns();
   }
   xsEnableRule("resourceManager");
   xsEnableRule("econMasterRule");
   xsEnableRule("herdMonitor");
   
   // Lastly, force an update on the economy by calling the function directly.
   econMaster();
}

//==============================================================================
// initMil
// Set up our initial military so we're ready to start fighting.
//==============================================================================
void initMil(void)
{
   debugSetup("***Initialising military***");
   xsEnableRule("defend0");
   xsEnableRule("defenseReflex");
   aiSetAttackResponseDistance(65.0);
   aiSetAutoGatherMilitaryUnits(true);
   // Set the Explore Danger Threshold.
   aiSetExploreDangerThreshold(110.0);
   // Allow the AI to use its abilities, we do this here so that inactive AI don't activate it.
   xsEnableRule("abilityManager");
}

//==============================================================================
// init
// Called once we have units in the new world.
//==============================================================================
void init(void)
{
   debugSetup("***Running init()***");
   // init Econ and Military stuff.
   initEcon();
   initMil();

   // When economy or military is set on plans, the plan's desired priority will be multiplied by either 
   // of the percentage which is the actual priority used for plan update order and unit assignment.
   // Us setting this to 1.0 basically means we do not use the aiPlanSetMilitary mechanic at all.
   aiSetEconomyPercentage(1.0);
   aiSetMilitaryPercentage(1.0);

   if ((gStartMode == cStartModeScenarioWagon) || (gStartMode == cStartModeLandWagon) || (gStartMode == cStartModeLandResources))
   {
      int coveredWagonID = gStartMode != cStartModeLandResources ? getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive) : -1;

      if (coveredWagonID < 0 && kbCanAffordUnit(cUnitTypeTownCenter, cEconomyEscrowID) == true)
      {
         // grab settlers and explorers when we didn't start with the wagon.
         coveredWagonID = getUnit(cUnitTypeHero, cMyID, cUnitStateAlive);
         if (coveredWagonID < 0)
         {
            coveredWagonID = getUnit(gEconUnit, cMyID, cUnitStateAlive);
         }
      }

      // If this is a scenario we should use the AIStart object's position for the gTCSearchVector.
      if (gSPC == true)
      {
         int aiStart = getUnit(cUnitTypeAIStart, cMyID, cUnitStateAny);
         if (aiStart >= 0)
         {
            gTCSearchVector = kbUnitGetPosition(aiStart);
            debugSetup("Using aiStart object at " + gTCSearchVector + " to start TC placement search");
         }
      }
      else
      {
         // Use the Covered Wagon position for the gTCSearchVector.
         vector coveredWagonPos = kbUnitGetPosition(coveredWagonID);
         vector normalVec = xsVectorNormalize(kbGetMapCenter() - coveredWagonPos);
         int offset = 40;
         gTCSearchVector = coveredWagonPos + (normalVec * offset);
     
         while (kbAreaGroupGetIDByPosition(gTCSearchVector) != kbAreaGroupGetIDByPosition(coveredWagonPos))
         {
            // Try for a goto point 40 meters toward center.  Fall back 5m at a time if that's on another continent/ocean.
            // If under 5, we'll take it.
            offset = offset - 5;
            gTCSearchVector = coveredWagonPos + (normalVec * offset);
            if (offset < 5)
            {
               break;
            }
         }
      }
      
      debugSetup("Creating startup Town Center build plan");
      // Make a town center, pri 100, econ, main base, 1 builder.
      int buildPlan = aiPlanCreate("Startup TC Build plan", cPlanBuild);
      // What to build
      aiPlanSetVariableInt(buildPlan, cBuildPlanBuildingTypeID, 0, cUnitTypeTownCenter);
      // Priority.
      aiPlanSetDesiredPriority(buildPlan, 100);
      // Builders, task every builder we got.
      addBuilderToPlan(buildPlan, cUnitTypeTownCenter, 10);
      if (kbUnitGetProtoUnitID(coveredWagonID) == cUnitTypeCoveredWagon)
      {
         aiPlanAddUnit(buildPlan, coveredWagonID);
      }

      // Instead of base ID or areas, use a center position and falloff.
      aiPlanSetVariableVector(buildPlan, cBuildPlanCenterPosition, 0, gTCSearchVector);
      aiPlanSetVariableFloat(buildPlan, cBuildPlanCenterPositionDistance, 0, 40.00);

      // Add position influences for trees, gold
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluenceUnitTypeID, 3, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluenceUnitDistance, 3, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluenceUnitValue, 3, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluenceUnitFalloff, 3, true);
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitTypeID, 0, cUnitTypeWood);
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitDistance, 0, 30.0);           // 30m range.
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitValue, 0, 10.0);              // 10 points per tree
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitFalloff, 0, cBPIFalloffLinear); // Linear slope falloff
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitTypeID, 1, cUnitTypeMine);
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitDistance, 1, 50.0);           // 50 meter range for gold
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitValue, 1, 300.0);             // 300 points each
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitFalloff, 1, cBPIFalloffLinear); // Linear slope falloff
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitTypeID, 2, cUnitTypeMine);
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitDistance, 2, 20.0);  // 20 meter inhibition to keep some space                                             
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluenceUnitValue, 2, -300.0); // -300 points each
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluenceUnitFalloff, 2, cBPIFalloffNone); // Cliff falloff

      // Two position weights
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluencePosition, 2, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluencePositionDistance, 2, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluencePositionValue, 2, true);
      aiPlanSetNumberVariableValues(buildPlan, cBuildPlanInfluencePositionFalloff, 2, true);

      // Give it a positive but wide-range prefernce for the search area, and a more intense but smaller negative to
      // avoid the landing area. Weight it to prefer the general starting neighborhood
      aiPlanSetVariableVector(buildPlan, cBuildPlanInfluencePosition, 0, gTCSearchVector);       // Focus on vec.
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluencePositionDistance, 0, 200.0);          // 200m range.
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluencePositionValue, 0, 300.0);             // 300 points max
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff

      // Add negative weight to avoid initial drop-off beach area
      aiPlanSetVariableVector(buildPlan, cBuildPlanInfluencePosition, 1,
         kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID))); // Position influence for landing position
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluencePositionDistance, 1, 50.0);           // Smaller, 50m range.
      aiPlanSetVariableFloat(buildPlan, cBuildPlanInfluencePositionValue, 1, -400.0);            // -400 points max
      aiPlanSetVariableInt(buildPlan, cBuildPlanInfluencePositionFalloff, 1, cBPIFalloffLinear); // Linear slope falloff
      // This combo will make it dislike the immediate landing (-100), score +25 at 50m, score +150 at 100m, then
      // gradually fade to +0 at 200m.

      // Wait to activate TC build plan, to allow adequate exploration
      gTCBuildPlanID = buildPlan; // Save in a global var so the rule can access it.
      aiPlanSetEventHandler(buildPlan, cPlanEventStateChange, "tcPlacedEventHandler");
      xsEnableRule("tcBuildPlanDelay");
   }
   
   // Due to a bug (or perhaps hack) in the Legacy game code, aiHCDeckAddCardToDeck() fails to add cards to the
   // AI's deck in SPC games. As a consequence, the game always reports 0 cards in the deck, and the AI does not
   // play any HC cards in Campaigns or Scenarios. The same behaviour was carried forward to the TWC and TAD expansions.
   // This bug was fixed in the DE version, so the AI can and will play cards in SPC games. Obviously this has a
   // huge impact on the behaviour and difficulty. Therefore, in order to preserve the legacy AI behaviour, we
   // default cvOkToBuildDeck to false in SPC games. This can be overwritten by the loader though.
   if (cvOkToBuildDeck == true)
   {
      // Shipment arrive handler, called when we've successfully sent a shipment.
      aiSetHandler("transportShipmentArrive", cXSHomeCityTransportArriveHandler);
      // This handler runs when you have a shipment available in the home city, decide which card to send.
      aiSetHandler("shipGrantedHandler", cXSShipResourceGranted);
      
      xsEnableRule("buyCards");
      xsEnableRule("extraShipMonitor");
   }
   
   if (cvOkToTaunt == true)
   {
      aiCommsAllowChat(true);
      xsEnableRule("IKnowWhereYouLive");
      xsEnableRule("firstEnemyUnitSpotted");
   
      // Set up the nugget handler, this is used to send chats when nuggets are collected.
      aiSetHandler("nuggetHandler", cXSNuggetHandler);
      
      int enemyCount = getEnemyCount();
      
      // We need to have 2 teams of equal sizes and have a human ally for monitorScores.
      if ((aiGetNumberTeams() == 3) && // Gaia is 1 team.
          (enemyCount == getAllyCount() + 1) && // Include myself.
          (getHumanAllyCount() >= 1))
      {
         xsEnableRule("monitorScores");
      }
      
      // This rule only works if we have more than 1 enemy.
      if (enemyCount > 1)
      {
         xsEnableRule("tcChats");
      }
   }
   
   if (cvOkToBuild == true)
   {
      xsEnableRule("wagonMonitor");
      wagonMonitor(); // Deal with our starting Wagons directly.
   }
   
   if (cvOkToResign == true)
   {
      xsEnableRule("ShouldIResign");
      // Set up the resign handler.
      aiSetHandler("resignHandler", cXSResignHandler);
   }

   if (cvOkToExplore == true)
   {
      // Don't start exploring if we need the explorer to build our starting TC.
      if (gStartMode != cStartModeLandResources)
      {
         xsEnableRule("exploreMonitor");
         exploreMonitor(); // Call it once directly so we instantly start with exploring instead of waiting 10 seconds.
      }
      
      if (gNavyMap == true)
      {
         xsEnableRule("waterExplore");
         waterExplore(); // Call instantly to start scouting if we have starting ships.
      }
      
      if (cMyCiv == cCivDutch)
      {
         xsEnableRule("envoyMonitor");
      }
      if (cMyCiv == cCivDEInca)
      {
         xsEnableRule("chasquiMonitor");
      }
      xsEnableRule("nativeScoutMonitor");
      xsEnableRule("mongolScoutMonitor");
   }
   
   xsEnableRule("townCenterComplete");
   postInit(); // All loading screen initialization is done, let loader file change what it wants to.
}

//==============================================================================
/* tcBuildPlanDelay

   Allows delayed activation of the TC build plan, so that the explorer has
   uncovered a good bit of the map before a placement is selected.

   The int gTCBuildPlanID is used to simplify passing of the build plan ID from
   init().
*/
//==============================================================================

rule tcBuildPlanDelay
inactive
minInterval 1
{
   if (xsGetTime() < gTCStartTime)
   {
      return; // Do nothing until game time is beyond 10 seconds
   }

   aiPlanSetActive(gTCBuildPlanID);
   debugBuildings("Activating startup Town Center build plan " + gTCBuildPlanID);
   xsDisableSelf();
}

//==============================================================================
/* townCenterComplete

   Wait until the Town Center is completed, then start basically everything else the AI does.
   In a start with a TC, this will fire very quickly.
   In a scenario without a TC, we do the best we can.
*/
//==============================================================================
rule townCenterComplete
inactive
minInterval 2
{
   // Let's see if we have a Town Center.
   int townCenterID = getUnit(cUnitTypeAgeUpBuilding);

   // If we have no Town Center and it isn't a special scenario where we don't start with a Covered Wagon either
   if ((townCenterID < 0) && (gStartMode != cStartModeScenarioNoTC))
   {
      return;
   }

   debugSetup("New TC is " + townCenterID + " at " + kbUnitGetPosition(townCenterID));

   if (townCenterID >= 0)
   {
      int tcBase = kbUnitGetBaseID(townCenterID);
      gMainBase = kbBaseGetMainID(cMyID);
      debugSetup(" TC base is " + tcBase + ", main base is " + gMainBase);
      // We have a TC.  Make sure that the main base exists, and it includes the TC
      if (gMainBase < 0)
      { // We have no main base, create one
         gMainBase = createMainBase(kbUnitGetPosition(townCenterID));
         debugSetup(" We had no main base, so we created one: " + gMainBase);
      }
      debugSetup("TC base area group has " +
         getAreaGroupNumberTiles(kbAreaGroupGetIDByPosition(kbUnitGetPosition(townCenterID))) +
         " number of tiles");
      tcBase = kbUnitGetBaseID(townCenterID); // in case base ID just changed
      if (tcBase != gMainBase)
      {
         debugSetup(" TC id: " + townCenterID + " is not in the main base: " + gMainBase);
         debugSetup(" Setting base " + gMainBase + " to non-main, setting base " + tcBase + " to main");
         kbBaseSetMain(cMyID, gMainBase, false);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeEasy, gMainBase);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHunt, gMainBase);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHerdable, gMainBase);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHuntAggressive, gMainBase);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeFish, gMainBase);
         aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeFarm, gMainBase);
         aiRemoveResourceBreakdown(cResourceWood, cAIResourceSubTypeEasy, gMainBase);
         aiRemoveResourceBreakdown(cResourceGold, cAIResourceSubTypeEasy, gMainBase);
         kbBaseSetMain(cMyID, tcBase, true);
         gMainBase = tcBase;
      }
      // Setup initial base distance.
      kbBaseSetPositionAndDistance(cMyID, gMainBase, kbBaseGetLocation(cMyID, gMainBase), 40.0);
   }
   else
   {
      debugSetup("No TC, leaving main base as it is");
   }

   kbBaseSetMaximumResourceDistance(cMyID, kbBaseGetMainID(cMyID), 80.0); // down from 150.

   // Town center found, start doing a bunch of activations.
   
   // Populate the list of which age ups we have available.
   aiPopulatePoliticianList(); 
   xsEnableRuleGroup("tcComplete");
   /*
      age2Monitor
      crateMonitor
      updateResourceBreakdowns
      reInitGatherers
      ageUpgradeMonitor
      econUpgrades
   */
   
   if ((cvOkToFish == true) &&
       (gGoodFishingMap == true))
   {
      xsEnableRule("startFishing");
   }

   // AssertiveWall: If there are water treasures, turn on the rule to gather them
   if (getUnit(cUnitTypeAbstractNuggetWater, cPlayerRelationAny, cUnitStateAlive) > 0)
   {
      xsEnableRule("gatherNavalNuggets");
   }
   
   if (aiIsMonopolyAllowed() == true)
   {
      xsEnableRule("monopolyManager");
      
      // Handler when a player starts the monopoly victory timer.
      aiSetHandler("monopolyStartHandler", cXSMonopolyStartHandler);
   
      // And when a monopoly timer prematurely ends.
      aiSetHandler("monopolyEndHandler", cXSMonopolyEndHandler);
   }
   
   if (aiIsKOTHAllowed() == true)
   {
      // Handler when a player starts the KOTH victory timer.
      aiSetHandler("KOTHVictoryStartHandler", cXSKOTHVictoryStartHandler);
   
      // And when a KOTH timer prematurely ends.
      aiSetHandler("KOTHVictoryEndHandler", cXSKOTHVictoryEndHandler);
   }
   
   // Create the Settler maintain plan with the right amount of Settlers that we want.
   gSettlerMaintainPlan = createSimpleMaintainPlan(gEconUnit,
      cMyCiv == cCivOttomans ? 0 : xsArrayGetInt(gTargetSettlerCounts, kbGetAge()), true, 
      kbBaseGetMainID(cMyID), 1);
   aiPlanSetDesiredResourcePriority(gSettlerMaintainPlan, 70);

   // AssertiveWall: Check whether we're on a migration style map
   if (cRandomMapName == "Ceylon" ||
         cRandomMapName == "ceylonlarge" ||
         cRandomMapName == "euarchipelago" ||
         cRandomMapName == "euarchipelagolarge" ||
         cRandomMapName == "afswahilicoast" ||
         cRandomMapName == "afswahilicoastlarge" ||
         cRandomMapName == "zpeldorado" ||
         cRandomMapName == "zptreasureisland")
   {
      gMigrationMap = true;
   }
   
   if (cvOkToBuild == true)
   {
      // AssertiveWall: Delay building if we're on ceylon or equivalent
      if (gMigrationMap == true)
      {
         gCeylonDelay = true;
      }
      xsEnableRule("buildingMonitor");

      // Lakota doesn't need houses.
      if (cMyCiv != cCivXPSioux)
      {
         xsEnableRule("houseMonitor");
      }
      
      if (((cMyCiv == cCivBritish) || (cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese) ||
          (cMyCiv == cCivDESwedish) || (cMyCiv== cCivDEInca)) &&
          (cDifficultyCurrent >= cDifficultyHard) &&
          (kbGetAge() == cAge1))
      {
         xsEnableRule("extraHouseMonitor");
      }

      if (cDifficultyCurrent >= cDifficultyModerate)
      {
         xsEnableRule("repairManager");
      }
      
      if ((cvOkToAllyNatives == true) ||
          (cvOkToClaimTrade == true))
      {
         xsEnableRule("tradingPostMonitor");
      }
      if (cMyCiv == cCivXPIroquois)
      {
         xsEnableRule("xpBuilderMonitor");
      }
   }
   
   if ((civIsEuropean() == true) && (cvOkToTrainArmy == true))
   {
      xsEnableRule("useLevy");
   }

   if (cMyCiv == cCivOttomans)
   {
      xsEnableRule("ottomanMonitor");
      xsEnableRule("toggleAutomaticSettlerSpawning");
   }

   if (civIsNative() == true)
   {
      xsEnableRule("danceMonitor");
   }
   
   if ((civIsAsian() == true) && (cvOkToTrainArmy == true))
   {
      xsEnableRule("useAsianLevy");
   }

   if ((cMyCiv != cCivIndians) && (cMyCiv != cCivSPCIndians) &&
       (cMyCiv != cCivJapanese) && (cMyCiv != cCivSPCJapanese) && (cMyCiv != cCivSPCJapaneseEnemy))
   {
      xsEnableRule("slaughterMonitor");
   }

   if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
   {
      xsEnableRule("shrineTacticMonitor");
      xsEnableRule("forwardShrineManager");
   }

   if (civIsAfrican() == true)
   {
      if (cvOkToTrainArmy == true)
      {
         xsEnableRule("useAfricanLevy");
      }
      xsEnableRule("livestockMarketMonitor");
      if (xsIsRuleEnabled("earlySlaughterMonitor") == false)
      {
         xsEnableRule("earlySlaughterMonitor");
      }
      // Enable house monitor after we sold the first livestock for wood.
      if (gSPC == false)
      {
         xsDisableRule("houseMonitor");
   }
   }

   if (cMyCiv == cCivDEMexicans)
   {
      xsEnableRule("haciendaMonitor");
   }

   int startingResources = aiGetGameStartingResources();
   if ((aiGetGameMode() == cGameModeDeathmatch) || (startingResources == cGameStartingResourcesInfinite) ||
       (startingResources == cGameStartingResourcesHigh) || (startingResources == cGameStartingResourcesUltra) ||
       (cRandomMapName == "euNapoleonicWars"))
   {
      deathMatchStartupBegin(); // Add a bunch of custom stuff for a DM jump-start.
   }

   if (kbUnitCount(cMyID, cUnitTypeypDaimyoRegicide, cUnitStateAlive) > 0)
   {
      xsEnableRule("regicideMonitor");
   }

   if (aiTreatyActive() == true)
   {
      int treatyEndTime = aiTreatyGetEnd();
      if (treatyEndTime > 10 * 60 * 1000) // Only do something if the treaty is set to longer than 10 minutes.
      {
         xsEnableRule("treatyCheckStartMakingArmy");
         // Intervals work on whole seconds not on ms.
         xsSetRuleMinInterval("treatyCheckStartMakingArmy", (treatyEndTime - 10 * 60 * 1000) / 1000); 
      }
   }

   // If we have a negative bias, don't claim trade route TPs until 10 minutes.
   if (btBiasTrade < 0.0)
   {
      gLastClaimTradeMissionTime = xsGetTime() + 600000;
   }
   else
   {
      gLastClaimTradeMissionTime = xsGetTime() - (1.0 - btBiasTrade) * gClaimTradeMissionInterval;
   }
   // Don't claim native TPs until 15 minutes in general.
   gLastClaimNativeMissionTime = xsGetTime() + 900000;
   
   xsDisableSelf();
}

//==============================================================================
// deathMatchStartupBegin, deathMatchStartupMiddle, deathMatchStartupEnd, startup of the Deathmatch Game Mode.
// Make a bunch of changes to get a deathmatch start.
//==============================================================================
void deathMatchStartupBegin(void)
{
   int mainBaseID = kbBaseGetMainID(cMyID);

   // Get houses so we can start training military.
   if (cMyCiv != cCivXPSioux)
   {
      createSimpleBuildPlan(gHouseUnit, 5, 99, true, cEconomyEscrowID, mainBaseID, 1, -1, true);
   }

   // xpBuilder will be assigned to all these houses and ruin the plans, assign villagers manually.
   if (cMyCiv == cCivXPIroquois)
   {
      int planID = -1;
      for (i = 1; < 5)
      {
         planID = aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gHouseUnit, true, i);
         if (planID != 1)
         {
            aiPlanAddUnitType(planID, cUnitTypeAbstractVillager, 1, 1, 1);
         }
      }
   }

   // Get 1 of each of the main military buildings.
   if (civIsEuropean() == true)
   {
      if ((cMyCiv != cCivRussians) && (cMyCiv != cCivDEMaltese))
      {
         createSimpleBuildPlan(cUnitTypeBarracks, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else if (cMyCiv == cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypedeHospital, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypeBlockhouse, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv != cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypeStable, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypedeCommandery, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   else if (civIsNative() == true)
   {
      createSimpleBuildPlan(cUnitTypeWarHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      if (cMyCiv == cCivXPAztec)
      {
         createSimpleBuildPlan(cUnitTypeNoblesHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv == cCivDEInca)
      {
         createSimpleBuildPlan(cUnitTypedeKallanka, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if ((cMyCiv == cCivXPIroquois) || (cMyCiv == cCivXPSioux))
      {
         createSimpleBuildPlan(cUnitTypeCorral, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv == cCivXPIroquois)
      {
         createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   }
   else if (civIsAsian() == true)
   {
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         createSimpleBuildPlan(cUnitTypeypBarracksJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
         createSimpleBuildPlan(cUnitTypeypStableJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
      {
         createSimpleBuildPlan(cUnitTypeypWarAcademy, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else // We're Indian.
      {
         createSimpleBuildPlan(cUnitTypeYPBarracksIndian, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
         createSimpleBuildPlan(cUnitTypeypCaravanserai, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      // And 1 Castle shared for all of them.
      createSimpleBuildPlan(cUnitTypeypCastle, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   else // We're African.
   {
      createSimpleBuildPlan(cUnitTypedeWarCamp, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      createSimpleBuildPlan(cUnitTypedePalace, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }

   // We want tight control over what we build so we disable these rules.
   xsDisableRule("buildingMonitor");
   xsDisableRule("houseMonitor");
   xsDisableRule("extraHouseMonitor");

   xsEnableRule("deathMatchStartupMiddle");
}

rule deathMatchStartupMiddle
inactive
minInterval 45
{
   int mainBaseID = kbBaseGetMainID(cMyID);

   // Get more houses so we can start training more military.
   if ((cMyCiv != cCivXPSioux) && (cMyCiv != cCivChinese))
   {
      createSimpleBuildPlan(gHouseUnit, 5, 99, true, cEconomyEscrowID, mainBaseID, 1, -1, true);
   }

   if (cMyCiv == cCivChinese) // Just 1 extra Village.
   {
      createSimpleBuildPlan(gHouseUnit, 1, 99, true, cEconomyEscrowID, mainBaseID, 1, -1, true);
   }

   // Get 1 more of each of the main military buildings (2 total now).
   if (civIsEuropean() == true)
   {
      if ((cMyCiv != cCivRussians) && (cMyCiv != cCivDEMaltese))
      {
         createSimpleBuildPlan(cUnitTypeBarracks, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else if (cMyCiv == cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypedeHospital, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypeBlockhouse, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv != cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypeStable, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypedeCommandery, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   else if (civIsNative() == true)
   {
      createSimpleBuildPlan(cUnitTypeWarHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      if (cMyCiv == cCivXPAztec)
      {
         createSimpleBuildPlan(cUnitTypeNoblesHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv == cCivDEInca)
      {
         createSimpleBuildPlan(cUnitTypedeKallanka, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if ((cMyCiv == cCivXPIroquois) || (cMyCiv == cCivXPSioux))
      {
         createSimpleBuildPlan(cUnitTypeCorral, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      if (cMyCiv == cCivXPIroquois)
      {
         createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   }
   else if (civIsAsian() == true)
   {
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         createSimpleBuildPlan(cUnitTypeypBarracksJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
         createSimpleBuildPlan(cUnitTypeypStableJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
      {
         createSimpleBuildPlan(cUnitTypeypWarAcademy, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else // We're Indian.
      {
         createSimpleBuildPlan(cUnitTypeYPBarracksIndian, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
         createSimpleBuildPlan(cUnitTypeypCaravanserai, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      // And 1 Castle/Consulate shared for all of them.
      createSimpleBuildPlan(cUnitTypeypCastle, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      createSimpleBuildPlan(cUnitTypeypConsulate, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }
   else // We're African.
   {
      createSimpleBuildPlan(cUnitTypedeWarCamp, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      createSimpleBuildPlan(cUnitTypedePalace, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
   }

   xsEnableRule("deathMatchStartupEnd");
   xsDisableSelf();
}

rule deathMatchStartupEnd
inactive
minInterval 30
{
   int mainBaseID = kbBaseGetMainID(cMyID);

   // Get the maximum amount of houses via build limit calculations.
   if ((cMyCiv != cCivXPSioux) && (cMyCiv != cCivChinese))
   {
      int houseCount = kbUnitCount(cMyID, gHouseUnit, cUnitStateABQ) +
                       aiPlanGetNumberByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gHouseUnit, true) +
                       aiPlanGetNumberByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gHouseUnit, false);
      int houseBL = kbGetBuildLimit(cMyID, gHouseUnit);
      int housesToBuild = houseBL - houseCount;
      if (housesToBuild > 0)
      {
         createSimpleBuildPlan(gHouseUnit, housesToBuild, 99, true, cEconomyEscrowID, mainBaseID, 1);
   }
   }

   // Get 1 more of each of the main military buildings (3 total now, sometimes 4).
   if (civIsEuropean() == true)
   {
      if ((cMyCiv != cCivRussians) && (cMyCiv != cCivDEMaltese))
      {
         createSimpleBuildPlan(cUnitTypeBarracks, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else if (cMyCiv == cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypedeHospital, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypeBlockhouse, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      if (cMyCiv != cCivDEMaltese)
      {
         createSimpleBuildPlan(cUnitTypeStable, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      else
      {
         createSimpleBuildPlan(cUnitTypedeCommandery, 1, 98, false, cMilitaryEscrowID, mainBaseID, 2);
      }
      createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
   }
   else if (civIsNative() == true)
   {
      createSimpleBuildPlan(cUnitTypeWarHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      if (cMyCiv == cCivXPAztec)
      {
         createSimpleBuildPlan(cUnitTypeNoblesHut, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      if (cMyCiv == cCivDEInca)
      {
         createSimpleBuildPlan(cUnitTypedeKallanka, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      if ((cMyCiv == cCivXPIroquois) || (cMyCiv == cCivXPSioux))
      {
         createSimpleBuildPlan(cUnitTypeCorral, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      if (cMyCiv == cCivXPIroquois)
      {
         createSimpleBuildPlan(cUnitTypeArtilleryDepot, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
   }
   }
   else if (civIsAsian() == true)
   {
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         createSimpleBuildPlan(cUnitTypeypBarracksJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
         createSimpleBuildPlan(cUnitTypeypStableJapanese, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      else if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
      {
         createSimpleBuildPlan(cUnitTypeypWarAcademy, 2, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      else // We're Indian.
      {
         createSimpleBuildPlan(cUnitTypeYPBarracksIndian, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
         createSimpleBuildPlan(cUnitTypeypCaravanserai, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      }
      // And 1 Castle shared for all of them.
      createSimpleBuildPlan(cUnitTypeypCastle, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
   }
   else // We're African.
   {
      createSimpleBuildPlan(cUnitTypedeWarCamp, 2, 98, false, cMilitaryEscrowID, mainBaseID, 1);
      createSimpleBuildPlan(cUnitTypedePalace, 1, 98, false, cMilitaryEscrowID, mainBaseID, 1);
   }

   if (aiGetGameStartingResources() != cGameStartingResourcesInfinite)
   {
   // Enable everything again that we disabled before so the AI can play on like it's a regular game.
   cvOkToGatherFood = true;
   cvOkToGatherWood = true;
   cvOkToGatherGold = true;
   }

   // Lakota doesn't need houses.
   if (cMyCiv != cCivXPSioux)
   {
      xsEnableRule("houseMonitor");
   }
   xsEnableRule("buildingMonitor");
   xsDisableSelf();
}

//==============================================================================
// initCeylonNomadStart
// If we are doing a nomad start, migrate to the main island no matter what.
//==============================================================================
//int gCeylonStartingTargetArea = -1; // AssertiveWall: Now defined in globals

void initCeylonNomadStart(void)
{
   int areaCount = 0;
   vector myLocation = cInvalidVector;
   int myAreaGroup = -1;

   int area = 0;
   int areaGroup = -1;
   int unit = getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);

   areaCount = kbAreaGetNumber();
   myLocation = kbUnitGetPosition(unit);
   myAreaGroup = kbAreaGroupGetIDByPosition(myLocation);

   int closestArea = -1;
   float closestAreaDistance = kbGetMapXSize();

   for (area = 0; < areaCount)
   {
      if (kbAreaGetType(area) == cAreaTypeWater)
      {
         continue;
      }

      areaGroup = kbAreaGroupGetIDByPosition(kbAreaGetCenter(area));
      if (kbAreaGroupGetNumberAreas(areaGroup) - kbAreaGroupGetNumberAreas(myAreaGroup) <= 10)
      {
         continue;
      }

      bool bordersWater = false;
      int borderAreaCount = kbAreaGetNumberBorderAreas(area);
      for (i = 0; < borderAreaCount)
      {
         if (kbAreaGetType(kbAreaGetBorderAreaID(area, i)) == cAreaTypeWater)
         {
            bordersWater = true;
            break;
         }
      }

      if (bordersWater == false)
      {
         continue;
      }

      float dist = xsVectorLength(kbAreaGetCenter(area) - myLocation);
      if (dist < closestAreaDistance)
      {
         closestAreaDistance = dist;
         closestArea = area;
      }
   }

   aiTaskUnitMove(getUnit(cUnitTypeypMarathanCatamaran, cMyID, cUnitStateAlive), kbAreaGetCenter(closestArea));
   gCeylonStartingTargetArea = closestArea;
   xsEnableRule("initCeylonWaitForExplore");
   xsDisableRule("waterAttack");
}

rule initCeylonWaitForExplore
inactive
minInterval 3
{
   if (kbAreaGetNumberFogTiles(gCeylonStartingTargetArea) + kbAreaGetNumberVisibleTiles(gCeylonStartingTargetArea) == 0)
   {
      aiTaskUnitMove(getUnit(cUnitTypeypMarathanCatamaran, cMyID, cUnitStateAlive), kbAreaGetCenter(gCeylonStartingTargetArea));
      return;
   }

   int unit = getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);
   vector location = kbUnitGetPosition(unit);

   int baseID = kbBaseCreate(cMyID, "Transport gather base", location, 10.0);
   kbBaseAddUnit(cMyID, baseID, unit);

   int transportPlan = createTransportPlan(location, kbAreaGetCenter(gCeylonStartingTargetArea), 100);

   aiPlanSetEventHandler(transportPlan, cPlanEventStateChange, "initCeylonTransportHandler");

   int numberNeeded = kbUnitCount(cMyID, cUnitTypeAbstractWagon, cUnitStateAlive);
   aiPlanAddUnitType(transportPlan, cUnitTypeAbstractWagon, numberNeeded, numberNeeded, numberNeeded);

   numberNeeded = kbUnitCount(cMyID, cUnitTypeLogicalTypeScout, cUnitStateAlive);
   aiPlanAddUnitType(transportPlan, cUnitTypeLogicalTypeScout, numberNeeded, numberNeeded, numberNeeded);

   xsEnableRule("initCeylonFailsafe");

   xsDisableSelf();
}

void initCeylonTransportHandler(int planID = -1)
{
   static bool transporting = false;
   vector centerPoint = kbGetMapCenter();

   switch (aiPlanGetState(planID))
   {
   case -1:
   {
      if (transporting == true)
      {
         // transport done.

         // build a TC on the main island in the direction of the map center to our starting position.
         vector vec = xsVectorNormalize(kbGetPlayerStartingPosition(cMyID) - centerPoint);
         int wagon = getUnit(cUnitTypeCoveredWagon, cMyID, cUnitStateAlive);
         vector wagonLoc = kbUnitGetPosition(wagon);
         float dist = xsVectorLength(wagonLoc - centerPoint);

         // not too close to the shore.
         if (dist >= 80.0)
            dist -= 40.0;

         gTCSearchVector = centerPoint + vec * dist;
         gStartingLocationOverride = gTCSearchVector;
         aiTaskUnitMove(wagon, gTCSearchVector);

         xsEnableRule("initRule");
            xsEnableRule("waterAttack");
      }
      break;
   }
   case cPlanStateGather:
   {
      // hack drop-off point
      vector targetPoint = aiPlanGetVariableVector(planID, cTransportPlanTargetPoint, 0);
         aiPlanSetVariableVector(planID, cTransportPlanDropOffPoint, 0,
            xsVectorSet(0.2 * xsVectorGetX(centerPoint) + 0.8 * xsVectorGetX(targetPoint), 0.0,
              0.2 * xsVectorGetZ(centerPoint) + 0.8 * xsVectorGetZ(targetPoint)));
      break;
   }
   case cPlanStateGoto:
   {
      transporting = true;
      break;
   }
   }
}

rule initCeylonFailsafe
inactive
minInterval 10
{
   int transportPlan = aiPlanGetIDByTypeAndVariableType(cPlanTransport, cTransportPlanTransportTypeID,
      cUnitTypeypMarathanCatamaran);
   switch (aiPlanGetState(transportPlan))
   {
   case -1:
   {
      xsDisableSelf();
      break;
   }
   case cPlanStateEnter:
   {
         aiTaskUnitMove(aiPlanGetVariableInt(transportPlan, cTransportPlanTransportID, 0),
          aiPlanGetVariableVector(transportPlan, cTransportPlanGatherPoint, 0));
      break;
   }
   }
}