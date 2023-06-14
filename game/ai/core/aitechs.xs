//==============================================================================
/* aiTechs.xs

   This file contains stuffs for managing techs including age upgrades.

*/
//==============================================================================

//==============================================================================
// chooseEuropeanPolitician
// Chooses age-up politicians or revolutions for European civilizations
//==============================================================================
int chooseEuropeanPolitician()
{
   static int validRevolutions = -1; // List of Revolutions that are available to us this game.
   static int ageUpPoliticians = -1; // Array of available age-up politicians,
   static int politicianScores = -1; // Array used to calculate "scores" for different European politicians.
   if (validRevolutions == -1) // First run.
   {
      validRevolutions = xsArrayCreateInt(7, 0, "Valid Revolutions");
      ageUpPoliticians = xsArrayCreateInt(5, 0, "Ageup Politicians");
      politicianScores = xsArrayCreateInt(5, 0, "European Politicians");
   }
   
   int age = kbGetAge();
   int numPoliticianChoices = aiGetPoliticianListCount(age + 1);
   int numValidPoliticians = 0;
   int politician = -1;
   int randomizer = -1;
   int bestChoice = 0; // Only used for Fortress -> Industrial.
   int bestScore = 0;  // Only used for Fortress -> Industrial.

   int arraySize = xsArrayGetSize(ageUpPoliticians);
   for (int i = 0; i < arraySize; i++)
   {
      xsArraySetInt(ageUpPoliticians, i, -1); // Reset array.
   }

   debugTechs("Valid politicians:");
   switch (age)
   {
      case cAge1:
      {
         for (i = 0; i < numPoliticianChoices; i++)
         {
            politician = aiGetPoliticianListByIndex(cAge2, i);
            // Include certain politicians.
            // AssertiveWall: Don't choose Philosopher on island maps. Swapped inventor for governor
            if ((politician == cTechPoliticianQuartermaster) ||
                ((politician == cTechPoliticianPhilosopherPrince) && (gStartOnDifferentIslands == false)) ||
                ((politician == cTechPoliticianGovernor) && (gStartOnDifferentIslands == true))) // AssertiveWall: changed from inventor to governor
            {
               debugTechs("" + kbGetTechName(politician));
               xsArraySetInt(ageUpPoliticians, numValidPoliticians, politician);
               numValidPoliticians++;
         }
      }
         randomizer = aiRandInt(numValidPoliticians);
         return (xsArrayGetInt(ageUpPoliticians, randomizer));
      }
      case cAge2:
   {
         for (i = 0; i < numPoliticianChoices; i++)
      {
            politician = aiGetPoliticianListByIndex(cAge3, i);
            // Exclude certain politicians.
            if ((politician != cTechPoliticianExiledPrince) &&
                (politician != cTechDEPoliticianMercContractorFortressDutch) &&
                (politician != cTechDEPoliticianMercContractorFortressOttoman) &&
                (politician != cTechDEPoliticianMercContractorFortressPortuguese) &&
                (politician != cTechDEPoliticianMercContractorFortress) &&
                (politician != cTechDEPoliticianMercContractorFortressSwedish) &&
                (politician != cTechDEPoliticianMercContractorFortressBritish) &&
                (politician != cTechDEPoliticianMercContractorFortressPortuguese) &&
                (politician != cTechDEPoliticianMercContractorFortressItalian) &&
                (politician != cTechDEPoliticianMercContractorFortressMaltese) &&
                (politician != cTechPoliticianAdmiral) &&
                (politician != cTechPoliticianAdmiralOttoman) &&
                (politician != cTechPoliticianPirate))
         {
               debugTechs("" + kbGetTechName(politician));
               xsArraySetInt(ageUpPoliticians, numValidPoliticians, politician);
               numValidPoliticians++;
         }
            if ((gHaveWaterSpawnFlag == true) && 
                ((politician == cTechPoliticianAdmiral) || 
                 (politician == cTechPoliticianAdmiralOttoman) || 
                 (politician != cTechPoliticianPirate) &&
                 (politician != cTechPoliticianAdmiralMaltese)))
         {
               debugTechs("" + kbGetTechName(politician));
               xsArraySetInt(ageUpPoliticians, numValidPoliticians, politician);
               numValidPoliticians++;
            }
         }
         randomizer = aiRandInt(numValidPoliticians);
         return (xsArrayGetInt(ageUpPoliticians, randomizer));
      }
      case cAge3:
         {
         // Reset array, this is only needed for if we somehow have to create a plan for this age more than once.
         arraySize = xsArrayGetSize(politicianScores);
         for (i = 0; i < arraySize; i++)
            {
            xsArraySetInt(politicianScores, i, 0); 
            }
         for (i = 0; i < numPoliticianChoices; i++)
         {
            politician = aiGetPoliticianListByIndex(cAge4, i);
            debugTechs("" + kbGetTechName(politician));
            // Include all politicians but weigh some more heavily.
            xsArraySetInt(ageUpPoliticians, numValidPoliticians, politician);
            if ((politician == cTechPoliticianEngineer) ||
                (politician == cTechPoliticianTycoon))
            {
               xsArraySetInt(politicianScores, i, 5);
         }
            // We don't want to pick a politician which ships a Fort Wagon when we're not allowed to build those.
            if (cvOkToBuildForts == false) 
         {
               if ((politician == cTechDEPoliticianLogisticianRussian) ||
                   (politician == cTechDEPoliticianLogisticianOttoman) ||
                   (politician == cTechDEPoliticianLogistician))
            {
                  xsArraySetInt(politicianScores, i, -50);
            }
         }
            numValidPoliticians++;
            // Add a random bonus to every politician.
            randomizer = aiRandInt(10);
            xsArraySetInt(politicianScores, i, xsArrayGetInt(politicianScores, i) + randomizer);
      }

         // Choose politician with best score.
         for (i = 0; i < numValidPoliticians; i++)
      {
            if (xsArrayGetInt(politicianScores, i) >= bestScore)
         {
               bestScore = xsArrayGetInt(politicianScores, i);
               bestChoice = i;
            }
         }
         return (xsArrayGetInt(ageUpPoliticians, bestChoice));
      }
      case cAge4:
         {
         // Check if we can revolt.
         randomizer = aiRandInt(4); // 25% Chance.
         if ((cDifficultyCurrent >= cDifficultyModerate) && (gSPC == false) &&
             (randomizer == 0) && (gStartOnDifferentIslands == false) &&
             (xsGetTime() < 30 * 60 * 1000) && (gTimeToFarm == false) && (gTimeForPlantations == false) &&
             (aiTreatyActive() == false) && (kbGetPop() > gMaxPop * 0.60))
            {
            debugTechs("We've decided that we're going to revolt!");
            debugTechs("Valid revolutions:");
            int numValidRevolutions = 0;
            int revolution = -1;
            
            arraySize = xsArrayGetSize(gRevolutionList);
            for (i = 0; i < arraySize; i++)
            {
               revolution = xsArrayGetInt(gRevolutionList, i);
               if (kbTechGetStatus(revolution) == cTechStatusObtainable)
               {
                  xsArraySetInt(validRevolutions, numValidRevolutions, revolution);
                  numValidRevolutions++;
                  debugTechs("" + kbGetTechName(revolution));
            }
         }
            if (numValidRevolutions > 0) // Safety check or we research age0french XD.
         {
               randomizer = aiRandInt(numValidRevolutions);
               return (xsArrayGetInt(validRevolutions, randomizer));
         }
      }

         for (i = 0; i < numPoliticianChoices; i++)
      {
            politician = aiGetPoliticianListByIndex(cAge5, i);
            // Include certain politicians.
            if ((politician == cTechPoliticianGeneral) ||
                (politician == cTechPoliticianPresidente) ||
                (politician == cTechDEPoliticianInventor))
         {
               debugTechs("" + kbGetTechName(politician));
               xsArraySetInt(ageUpPoliticians, numValidPoliticians, politician);
               numValidPoliticians++;
         }
            }
         
         // If we didn't revolt we use this logic.
         randomizer = aiRandInt(numValidPoliticians);
         return (xsArrayGetInt(ageUpPoliticians, randomizer));
         }
      }
   return (-1); // This should never hit.
}

//==============================================================================
/* chooseNativeCouncilMember
   Chooses age-up council members for native civilizations.
 
   Aztec:
   1: The Messenger
   2: The Shaman
   3: The Warrior or The Wisewoman.
   4: The one we didn't pick at 3
   Ignore The Chief completely.
   
   Haud: 
   1: The Chief
   2: The Shaman
   3: The Wisewoman or The Warrior
   4: The one we didn't pick at 3
   Ignore The Messenger completely.
   
   Lakota: 
   1: The Chief
   2: The Wisewoman
   3: The Warrior or the Shaman
   4: The one we didn't pick at 3
   Ignore The Messenger completely.

   Inca:
   1: The Chief or The Elder
   2: The one we didn't pick at 1
   3: The Wise Woman or The Warrior
   4: The one we didn't pick at 3
   Ignore The Messenger completely.
*/
//==============================================================================
int chooseNativeCouncilMember()
      {
   switch (kbGetAge())
         {
      case cAge1:
            {
         if (cMyCiv == cCivXPAztec)
         {
            return (cTechTribalAztecYouth2);
            }
         else if (cMyCiv == cCivXPIroquois)
            {
            return (cTechTribalIroquoisChief2);
            }
         else if (cMyCiv == cCivXPSioux)
            {
            return (cTechTribalSiouxChief2);
            }
         else if (cMyCiv == cCivDEInca)
         {
            if (aiRandInt(2) == 0)
            {
               return (cTechTribalIncaChief2);
         }
         else
         {
               return (cTechTribalIncaShaman2);
            }
         }
         break;
      }
      case cAge2:
      {
         if (cMyCiv == cCivXPAztec)
         {
            return (cTechTribalAztecShaman3);
         }
         else if (cMyCiv == cCivXPIroquois)
         {
            return (cTechTribalIroquoisShaman3);
      }
         else if (cMyCiv == cCivXPSioux)
         {
            return (cTechTribalSiouxWisewoman3);
   }
         else if (cMyCiv == cCivDEInca)
         {
            if (kbTechGetStatus(cTechTribalIncaChief2) == cTechStatusActive)
            {
               return (cTechTribalIncaShaman3);
   }
            else
   {
               return (cTechTribalIncaChief3);
      }
   }
         break;
}
      case cAge3:
{
         if (cMyCiv == cCivXPAztec)
   {
            if (aiRandInt(2) == 0)
      {
               return (cTechTribalAztecWarrior4);
            }
            else
         {
               return (cTechTribalAztecWisewoman4);
         }
      }
         else if (cMyCiv == cCivXPIroquois)
      {
            if (aiRandInt(2) == 0)
         {
               return (cTechTribalIroquoisWarrior4);
         }
            else
            {
               return (cTechTribalIroquoisWisewoman4);
      }
   }
         else if (cMyCiv == cCivXPIroquois)
      {
            if (aiRandInt(2) == 0)
         {
               return (cTechTribalSiouxWarrior4);
         }
            else
         {
               return (cTechTribalSiouxShaman4);
         }
      }
         else if (cMyCiv == cCivDEInca)
      {
            if (aiRandInt(2) == 0)
         {
               return (cTechTribalIncaWarrior4);
         }
            else
            {
               return (cTechTribalIncaWisewoman4);
      }
         }
      break;
   }
      case cAge4:
      {
         if (cMyCiv == cCivXPAztec)
         {
            if (kbTechGetStatus(cTechTribalAztecWarrior4) == cTechStatusActive)
            {
               return (cTechTribalAztecWisewoman5);
         }
            else
         {
               return (cTechTribalAztecWarrior5);
         }
      }
         else if (cMyCiv == cCivXPIroquois)
      {
            if (kbTechGetStatus(cTechTribalIroquoisWarrior4) == cTechStatusActive)
         {
               return (cTechTribalIroquoisWisewoman5);
         }
            else
            {
               return (cTechTribalIroquoisWarrior5);
      }
   }
         else if (cMyCiv == cCivXPSioux)
      {
            if (kbTechGetStatus(cTechTribalSiouxWarrior4) == cTechStatusActive)
         {
               return (cTechTribalSiouxShaman5);
         }
            else
         {
               return (cTechTribalSiouxWarrior5);
         }
      }
         else if (cMyCiv == cCivDEInca)
      {
            if (kbTechGetStatus(cTechTribalIncaWarrior4) == cTechStatusActive)
         {
               return (cTechTribalIncaWisewoman5);
            }
            else
            {
               return (cTechTribalIncaWarrior5);
         }
      }
      break;
   }
   }
   return (-1); // This should never hit.
}

//==============================================================================
/* chooseAsianWonder
   Chooses age-up Wonders for Asian civilizations.
   
   Chinese:
   1: Summer Palace or Porcelain Tower
   2: The one we didn't pick at 1
   3: Confucian or Temple of Heaven
   4: The one we didn't pick at 3
   Ignore White Pagoda completely.
   
   India:
   1: Agra Fort
   2: Taj Mahal or Tower of Victory
   3: Karni Mata or Charminar Gate
   4: The one we didn't pick at 2 or 3.
   
   Japanese:
   1: Torii Gates or Toshogu Shrine
   2: Golden Pavilion
   3: Shogunate
   4: Giant Buddha or the one we didn't pick at 1.
*/
//==============================================================================
int chooseAsianWonder()
{
   switch (kbGetAge())
   {
   case cAge1:
   {
      if (cMyCiv == cCivChinese)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWCSummerPalace2);
         }
         else
         {
            return (cUnitTypeypWCPorcelainTower2);
         }
      }
      else if (cMyCiv == cCivIndians)
      {
         return (cUnitTypeypWIAgraFort2);
      }
      else if (cMyCiv == cCivJapanese)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWJToriiGates2);
         }
         else
         {
            return (cUnitTypeypWJToshoguShrine2);
         }
      }
      break;
   }
   case cAge2:
   {
      if (cMyCiv == cCivChinese)
      {
         if (kbTechGetStatus(cTechYPWonderChineseSummerPalace3) == cTechStatusObtainable)
         {
            return (cUnitTypeypWCSummerPalace3);
         }
         else
         {
            return (cUnitTypeypWCPorcelainTower3);
         } 
      }
      else if (cMyCiv == cCivIndians)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWITajMahal3);
         }
         else
         {
            return (cUnitTypeypWITowerOfVictory3);
         }
      }
      else if (cMyCiv == cCivJapanese)
      {
         return (cUnitTypeypWJGoldenPavillion3);
      }
      break;
   }
   case cAge3:
   {
      if (cMyCiv == cCivChinese)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWCConfucianAcademy4);
         }
         else
         {
            return (cUnitTypeypWCTempleOfHeaven4);
         } 
      }
      else if (cMyCiv == cCivIndians)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWIKarniMata4);
         }
         else
         {
            return (cUnitTypeypWICharminarGate4);
         }
      }
      else if (cMyCiv == cCivJapanese)
      {
         return (cUnitTypeypWJShogunate4);
      }
      break;
   }
   case cAge4:
   {
      if (cMyCiv == cCivChinese)
      {
         if (kbTechGetStatus(cTechYPWonderChineseConfucianAcademy5) == cTechStatusObtainable)
         {
            return (cUnitTypeypWCConfucianAcademy5);
         }
         else
         {
            return (cUnitTypeypWCTempleOfHeaven5);
         } 
      }
      else if (cMyCiv == cCivIndians)
      {
         if (aiRandInt(2) == 0)
         {
            if (kbTechGetStatus(cTechYPWonderIndianTajMahal5) == cTechStatusObtainable)
            {
               return (cUnitTypeypWITajMahal5);
            }
            else
            {
               return (cUnitTypeypWITowerOfVictory5);
            }
         }
         else
         {
            if (kbTechGetStatus(cTechYPWonderIndianKarniMata5) == cTechStatusObtainable)
            {
               return (cUnitTypeypWIKarniMata5);
            }
            else
            {
               return (cUnitTypeypWICharminarGate5);
            }
         }
      }
      else if (cMyCiv == cCivJapanese)
      {
         if (aiRandInt(2) == 0)
         {
            return (cUnitTypeypWJGiantBuddha5);
         }
         else
         {
            if (kbTechGetStatus(cTechYPWonderJapaneseToriiGates5) == cTechStatusObtainable)
            {
               return (cUnitTypeypWJToriiGates5);
            }
            else
            {
               return (cUnitTypeypWJToshoguShrine5);
            }
         }
      }
      break;
   }
   }

   return (-1); // This should never hit.
}

//==============================================================================
// chooseAfricanAlliance
// Chooses age-up alliance for African civilizations.
//==============================================================================
int chooseAfricanAlliance()
{
   int age = kbGetAge();
   int numAllianceChoices = aiGetPoliticianListCount(age + 1);
   int numValidAlliances = 0;
   int alliance = -1;

   for (i = 0; < 8)
   {
      xsArraySetInt(gAfricanAlliances, i, -1); // Reset array.
   }

   // Fill the array with Alliances that are deemed suitable to chose from.
   // Exclude the ones we don't want is what's done below.
   switch (age)
   {
   case cAge1:
   {
      for (i = 0; < numAllianceChoices)
      {
         alliance = aiGetPoliticianListByIndex(cAge2, i);
         if ((alliance != cTechDEAllegianceJesuit2) && (alliance != cTechDEAllegianceHabesha2) &&
             (alliance != cTechDEAllegianceMoroccan2) && (alliance != cTechDEAllegianceAkan2))
         {
            xsArraySetInt(gAfricanAlliances, numValidAlliances, alliance);
            numValidAlliances++;
         }
      }
      break;
   }
   case cAge2:
   {
      for (i = 0; < numAllianceChoices)
      {
         alliance = aiGetPoliticianListByIndex(cAge3, i);
         if ((alliance != cTechDEAllegianceHabesha3) && (alliance != cTechDEAllegianceIndian3) &&
             (alliance != cTechDEAllegianceMoroccan3) && (alliance != cTechDEAllegianceFulani3))
         {
            xsArraySetInt(gAfricanAlliances, numValidAlliances, alliance);
            numValidAlliances++;
         }
      }
      break;
   }
   case cAge3:
   {
      for (i = 0; < numAllianceChoices)
      {
         alliance = aiGetPoliticianListByIndex(cAge4, i);
         if ((alliance != cTechDEAllegianceHabesha4) && (alliance != cTechDEAllegianceIndian4) &&
             (alliance != cTechDEAllegianceFulani4) && (alliance != cTechDEAllegianceMoroccan4) &&
             (alliance != cTechDEAllegianceYoruba4))
         {
            xsArraySetInt(gAfricanAlliances, numValidAlliances, alliance);
            numValidAlliances++;
         }
      }
      break;
   }
   case cAge4:
   {
      for (i = 0; < numAllianceChoices)
      {
         alliance = aiGetPoliticianListByIndex(cAge5, i);
         if ((alliance != cTechDEAllegianceHabesha5) && (alliance != cTechDEAllegianceIndian5) &&
             (alliance != cTechDEAllegianceArab5) && (alliance != cTechDEAllegianceFulani5) &&
             (alliance != cTechDEAllegianceMoroccan5) && (alliance != cTechDEAllegianceYoruba5))
         {
            xsArraySetInt(gAfricanAlliances, numValidAlliances, alliance);
            numValidAlliances++;
         }
      }
      break;
   }
   }

   alliance = xsArrayGetInt(gAfricanAlliances, aiRandInt(numValidAlliances));

   debugTechs("Alliances to chose from:");
   for (i = 0; < numValidAlliances)
   {
      debugTechs(kbGetTechName(xsArrayGetInt(gAfricanAlliances, i)));
   }

   return (alliance);
}

//==============================================================================
// chooseAmericanFederalState
// Chooses age-up Federal States for the United States civilization.
//==============================================================================
int chooseAmericanFederalState()
{
   int age = kbGetAge();
   int numFederalStateChoices = aiGetPoliticianListCount(age + 1);
   int numValidFederalStates = 0;
   int federalState = -1;

   for (int i = 0; i < numValidFederalStates; i++)
   {
      xsArraySetInt(gAmericanFederalStates, i, -1); // Reset array.
   }

   // Fill the array with Alliances that are deemed suitable to chose from.
   // Exclude the ones we don't want is what's done below.
   switch (age)
   {
   case cAge1:
   {
      for (i = 0; i < numFederalStateChoices; i++)
      {
         federalState = aiGetPoliticianListByIndex(cAge2, i);
         // AssertiveWall: let the AI pick any age 1 unless it's an island map, then choose Rhode Island
         if (gStartOnDifferentIslands == true)
         {
            if ((federalState != cTechDEPoliticianFederalMassachusetts) &&
                (federalState != cTechDEPoliticianFederalVirginia) &&
                (federalState != cTechDEPoliticianFederalPennsylvania) &&
                (federalState != cTechDEPoliticianFederalDelaware))
            {  // AssertiveWall: only Rhode Island on island maps
               xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
               numValidFederalStates++;
            }
         }
         //if ((federalState != cTechDEPoliticianFederalMassachusetts) &&
         //    (federalState != cTechDEPoliticianFederalVirginia) &&
         //    (federalState != cTechDEPoliticianFederalPennsylvania) &&
         //    (federalState != cTechDEPoliticianFederalRhodeIsland))
         else
         {  // Basically we always age up with Delaware. (AssertiveWall: overruled. chooses any)
            xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge2:
   {
      for (i = 0; i < numFederalStateChoices; i++)
      {
         federalState = aiGetPoliticianListByIndex(cAge3, i);
         //if (gStartOnDifferentIslands == true)
         //{  // AssertiveWall: AI can't really make use of Maryland, so follow old rule
         /*   if (federalState == cTechDEPoliticianFederalMaryland) 
            {
               xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
               numValidFederalStates++;
            }
         }
         else*/ if ((federalState != cTechDEPoliticianFederalIndiana) &&
             (federalState != cTechDEPoliticianFederalMaryland))
         {
            xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge3:
   {
      for (i = 0; i < numFederalStateChoices; i++)
      {
         federalState = aiGetPoliticianListByIndex(cAge4, i);
         // AssertiveWall: Allow Vermont, I like Vermont
         if (//(federalState != cTechDEPoliticianFederalVermont) &&
             (federalState != cTechDEPoliticianFederalCalifornia))
         {
            xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge4:
   {
      for (i = 0; i < numFederalStateChoices; i++)
      {  // AssertiveWall: Allow all of them, they're all good in different ways
         xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
         numValidFederalStates++;
         
         /*federalState = aiGetPoliticianListByIndex(cAge5, i);
         if (gStartOnDifferentIslands == true)
         {
            if (federalState == cTechDEPoliticianFederalConnecticut)
            {
               xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
               numValidFederalStates++;
            }
         }
         else if (federalState != cTechDEPoliticianFederalNewYork)
         {
            if (((federalState != cTechDEPoliticianFederalTexas) && (federalState != cTechDEPoliticianFederalFlorida)) || 
                (cvOkToBuildForts == true))
            {
            xsArraySetInt(gAmericanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
            }
         }*/
      }
      break;
   }
   }

   federalState = xsArrayGetInt(gAmericanFederalStates, aiRandInt(numValidFederalStates));

   debugTechs("Federal States to chose from:");
   for (i = 0; i < numValidFederalStates; i++)
   {
      debugTechs(kbGetTechName(xsArrayGetInt(gAmericanFederalStates, i)));
   }

   return (federalState);
}

//==============================================================================
// chooseMexicanFederalState
// Chooses age-up Federal States for the Mexican civilization.
//==============================================================================
int chooseMexicanFederalState()
{
   int age = kbGetAge();
   int numFederalStateChoices = aiGetPoliticianListCount(age + 1);
   int numValidFederalStates = 0;
   int federalState = -1;

   for (i = 0; < numFederalStateChoices)
   {
      xsArraySetInt(gMexicanFederalStates, i, -1); // Reset array.
   }

   // Fill the array with Alliances that are deemed suitable to chose from.
   // Exclude the ones we don't want is what's done below.
   switch (age)
   {
   case cAge1:
   {
      for (i = 0; < numFederalStateChoices)
      {
         federalState = aiGetPoliticianListByIndex(cAge2, i);
         if ((federalState != cTechDEPoliticianFederalMXDurango) &&
             ((federalState != cTechDEPoliticianFederalMXMichoacan) || (gNavyMap == true)))
         {
            xsArraySetInt(gMexicanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge2:
   {
      for (i = 0; < numFederalStateChoices)
      {
         federalState = aiGetPoliticianListByIndex(cAge3, i);
         if ((federalState != cTechDEPoliticianFederalMXSinaloa) ||
             (gNavyMap == true) && (federalState != cTechDEPoliticianFederalMXSonora) ||
             ((gTimeForPlantations == false) && (gTimeToFarm == false)))
         {
            xsArraySetInt(gMexicanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge3:
   {
      for (i = 0; < numFederalStateChoices)
      {
         federalState = aiGetPoliticianListByIndex(cAge4, i);
         if ((federalState != cTechDEPoliticianFederalMXTamaulipas) || (gNavyMap == true))
         {
            xsArraySetInt(gMexicanFederalStates, numValidFederalStates, federalState);
            numValidFederalStates++;
         }
      }
      break;
   }
   case cAge4:
   {
      for (i = 0; < numFederalStateChoices)
      {
         federalState = aiGetPoliticianListByIndex(cAge5, i);
         if (((federalState != cTechDEPoliticianFederalMXPuebla) && (federalState != cTechDEPoliticianFederalMXVeracruz)) || 
             (cvOkToBuildForts == true))
         {
         xsArraySetInt(gMexicanFederalStates, numValidFederalStates, federalState);
         numValidFederalStates++;
      }
      }
      break;
   }
   }

   federalState = xsArrayGetInt(gMexicanFederalStates, aiRandInt(numValidFederalStates));

   debugTechs("Federal States to chose from:");
   for (i = 0; < numValidFederalStates)
   {
      debugTechs(kbGetTechName(xsArrayGetInt(gMexicanFederalStates, i)));
   }

   return (federalState);
}

//==============================================================================
/* ageUpgradeMonitor
   In this rule we decide what age up option we must go for,
   and what resource priority we must give it.
*/
//==============================================================================
rule ageUpgradeMonitor
inactive
group tcComplete
minInterval 10
{
   int wonderToBuild = -1; // Used for Asian logic.
   int politician = -1;    // Used for non-Asian logic.
   int ageUpPriority = -1; // Used as resource priority for the age up plan.
   int age = kbGetAge();
   int time = xsGetTime();
   int firstAgeUpTime = xsArrayGetInt(gFirstAgeTime, age + 1);
   int mainBaseID = kbBaseGetMainID(cMyID);

   if (age >= cvMaxAge)
   {
      xsDisableSelf();
      return;
   }

   int militaryPopLimit = aiGetMilitaryPop();
   int currentMilitaryPop = militaryPopLimit - aiGetAvailableMilitaryPop();

   // Destroy the age up plan or don't create one.
   if (((age >= cAge2) && (cvOkToTrainArmy == true) && (militaryPopLimit / 4 > currentMilitaryPop) ||
        (time < gAgeUpPlanTime)) &&
       (gExcessResources == false) && (firstAgeUpTime + 15 * 60 * 1000 > time))
   {
      debugTechs("Destroying or not creating an age up plan because we're not ready for it yet");
      if (gAgeUpResearchPlan >= 0)
      {
         aiPlanDestroy(gAgeUpResearchPlan);
         gAgeUpResearchPlan = -1;
      }
      return;
   }

   // We're now 10 minutes past the first person reaching the next age increase priority no matter what.
      // OR
   // We're now 5 minutes past the first person reaching the next age, check if some other stuff is true.
   //    If we're not being attacked and have a lot of military we may bump the prio.
   //    OR
      // If we're planning to go to Industrial/Imperial make sure we have at least 75% of gMaxPop before we increase priority.
   if ((firstAgeUpTime + 10 * 60 * 1000 < time) ||
       ((firstAgeUpTime + 5 * 60 * 1000 < time) &&
        (((gDefenseReflexBaseID != mainBaseID) && (militaryPopLimit / 2 < currentMilitaryPop)) ||
        ((age >= cAge3) && (kbGetPop() > gMaxPop * 0.75)))))
      {
         ageUpPriority = 52;
      }
   else
   {
      ageUpPriority = 48;
   }

   debugTechs("Our ageUpPriority (resource priority) is: " + ageUpPriority);

   // If we already have a plan let's see if it's still valid, otherwise destroy.
   if (gAgeUpResearchPlan >= 0)
   {
      if (aiPlanGetState(gAgeUpResearchPlan) < 0) // Plan is dead.
      {
         debugTechs("WARNING our gAgeUpResearchPlan somehow died! Will try to create a new one");
         aiPlanDestroy(gAgeUpResearchPlan);
         gAgeUpResearchPlan = -1;
            }
      else // Update the existing plan's priority.
            {
         aiPlanSetDesiredResourcePriority(gAgeUpResearchPlan, ageUpPriority);
      }
   }
   // We have no plan yet so create one.
   else
   {
      if (civIsAsian() == false)
      {
         // Try to research the preferred politician / council member / alliance / federal state.
         if (civIsNative() == true)
         {
            politician = chooseNativeCouncilMember();
         }
         else if (civIsAfrican() == true)
         {
            politician = chooseAfricanAlliance();
         }
         else if (cMyCiv == cCivDEAmericans)
         {
            politician = chooseAmericanFederalState();
         }
         else if (cMyCiv == cCivDEMexicans)
         {
            politician = chooseMexicanFederalState();
         }
         else // European.
         {
            politician = chooseEuropeanPolitician();
         }

         if (politician < 0) // We somehow failed to get a valid age up option so chose the one at index 0.
         {
            politician = aiGetPoliticianListByIndex(age + 1, 0);
            debugTechs "WARNING we failed to pick an age up option to create a plan for, " + 
               "choosing first option from failsafe: " + kbGetTechName(politician));
         }

         // We have managed to pick a politician / council member / alliance / federal state (or got defaulted to index 0).
         // So let's create the research plan. If we somehow still don't have one we just don't make a plan.
         if (politician >= 0)
         {
            // We search for buildings with AgeUpBuilding abstract type which includes the command post in historical maps.
            gAgeUpResearchPlan = createSimpleResearchPlan(
               politician, cUnitTypeAgeUpBuilding, cEmergencyEscrowID, 99, ageUpPriority);
            aiPlanSetEventHandler(gAgeUpResearchPlan, cPlanEventStateChange, "ageUpEventHandler");
            return;
         }
         else
         {
            debugTechs("WARNING we failed to pick an age up option to make an age up plan for, how could this happen?");
         }
      }
      else
      { // We are Asian, time to build a Wonder.
         wonderToBuild = chooseAsianWonder();
         if (wonderToBuild >= 0)
         {
            gAgeUpResearchPlan = createSimpleBuildPlan(
               wonderToBuild, 1, 100, true, cEmergencyEscrowID, mainBaseID, 4);
            aiPlanSetDesiredResourcePriority(gAgeUpResearchPlan, ageUpPriority);
            aiPlanSetEventHandler(gAgeUpResearchPlan, cPlanEventStateChange, "ageUpEventHandler");
         }
         else
         {
            debugTechs("WARNING we failed to pick a Wonder to make an age up plan for, how could this happen?");
         }
      }
   }
}

//==============================================================================
// settlerUpgradeMonitor
//==============================================================================
rule settlerUpgradeMonitor
inactive
minInterval 180 // Research to be started 3 minutes into the Commerce Age.
{
   // Quit if there is no Market.
   if (kbUnitCount(cMyID, gMarketUnit, cUnitStateAlive) < 1)
   {
      return;
   }

   int villagerHPTechID = -1;

   if (civIsNative() == true)
   {
      villagerHPTechID = cTechSpiritMedicine;
   }
   else if (civIsAsian() == true)
   {
      villagerHPTechID = cTechypMarketSpiritMedicine;
   }
   else if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans))
   {
      villagerHPTechID = cTechDEFrontiersmen;
   }
   else if (civIsAfrican() == true)
   {
      villagerHPTechID = cTechDEAfricanVillagerHitpoints;
   }
   else // European.
   {
      villagerHPTechID = cTechGreatCoat;
   }

   bool canDisableSelf = researchSimpleTech(villagerHPTechID, gMarketUnit);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// econUpgrades
// Make sure we always have an econ upgrade plan running. Go cheapest first.
//==============================================================================
rule econUpgrades
inactive
group tcComplete
minInterval 30
{
   int planState = -1;
   int age = kbGetAge();
   int time = xsGetTime();
   int techToGet = -1;
   float lowestCost = 1000000.0;
   static int gatherTargets = -1;     // Array to hold the list of things we gather from, i.e. mill, tree, etc.
   static int gatherTargetTypes = -1; // Array.  If gatherTargets(x) == mill, then gatherTargetTypes(x) = cResourceFood.
   int target = -1;                   // Index used to step through arrays.
   static int startTime = -1;         // Time last plan was started, to make sure we're not waiting on an obsolete tech.

   if (gatherTargets < 0) // First run.
   {                      // Set up our list of target units (what we gather from) and their resource categories.
      gatherTargets = xsArrayCreateInt(8, -1, "Gather Targets");
      gatherTargetTypes = xsArrayCreateInt(8, -1, "Gather Target Types");

      xsArraySetInt(gatherTargets, 0, gFarmUnit); // Mills generate food.
      xsArraySetInt(gatherTargetTypes, 0, cResourceFood);

      xsArraySetInt(gatherTargets, 1, cUnitTypeTree); // Trees generate wood.
      xsArraySetInt(gatherTargetTypes, 1, cResourceWood);

      xsArraySetInt(gatherTargets, 2, cUnitTypeAbstractMine); // Mines generate gold.
      xsArraySetInt(gatherTargetTypes, 2, cResourceGold);

      if ((cMyCiv != cCivJapanese) && (cMyCiv != cCivSPCJapanese) && (cMyCiv != cCivSPCJapaneseEnemy))
      {
         xsArraySetInt(gatherTargets, 3, cUnitTypeHuntable); // Huntables generate food, not for the Japanese!
      }
      else
      {
         xsArraySetInt(gatherTargets, 3, cUnitTypeypBerryBuilding); // Berry bushes and cherry orchards.
      }
      xsArraySetInt(gatherTargetTypes, 3, cResourceFood);

      xsArraySetInt(gatherTargets, 4, cUnitTypeBerryBush);
      xsArraySetInt(gatherTargetTypes, 4, cResourceFood);

      xsArraySetInt(gatherTargets, 5, gPlantationUnit); // Plantations generate gold.
      xsArraySetInt(gatherTargetTypes, 5, cResourceGold);

      xsArraySetInt(gatherTargets, 6, cUnitTypeFish); // Fish generate food.
      xsArraySetInt(gatherTargetTypes, 6, cResourceFood);

      xsArraySetInt(gatherTargets, 7, cUnitTypeAbstractWhale); // Whale generates gold.
      xsArraySetInt(gatherTargetTypes, 7, cResourceGold);
   }

   planState = aiPlanGetState(gEconUpgradePlan);

   if (planState < 0)
   {                                   // Plan is done or doesn't exist.
      aiPlanDestroy(gEconUpgradePlan); // Nuke the old one, if it exists.
      startTime = -1;

      int techID = -1;           // The cheapest tech for the current target unit type.
      float rawCost = -1.0;      // The cost of the upgrade.
      float relCost = -1.0;      // The cost, relative to some estimate of the number of gatherers.
      float numGatherers = -1.0; // Number of gatherers assigned to the resource type (i.e food).

      /*
         Step through the array of gather targets.  For each, calculate the cost of the upgrade
         relative to the number of gatherers that would benefit. Choose the one with the best payoff.
      */
      for (target = 0; < 8)
      {
         techID = kbTechTreeGetCheapestEconUpgrade(xsArrayGetInt(gatherTargets, target),
            xsArrayGetInt(gatherTargetTypes, target));
         if (techID < 0) // No tech available for this target type.
         {
            continue;
         }
         rawCost = kbGetTechAICost(techID);

         numGatherers = aiGetNumberGatherers(cUnitTypeAbstractVillager,
            xsArrayGetInt(gatherTargetTypes, target), -1, xsArrayGetInt(gatherTargets, target));

         // Calculate the relative cost.
         switch (xsArrayGetInt(gatherTargets, target))
         {
         case cUnitTypeHuntable:
         {
            // Assume all food gatherers are hunting unless we have a mill.
            relCost = rawCost / numGatherers;
            if (kbUnitCount(cMyID, gFarmUnit, cUnitStateAlive) > 0)
               {
                  relCost = -1.0; // Do NOT get hunting dogs once we're farming.
               }
            break;
         }
         case cUnitTypeFish:
         {
            numGatherers = kbUnitCount(cMyID, gFishingUnit, cUnitStateAlive);
            if (numGatherers > 0.0)
               {
               relCost = rawCost / numGatherers;
               }
            else
               {
               relCost = -1.0;
               }
            break;
         }
            default: // All other resources.
         {
            if (numGatherers > 0.0)
               {
               relCost = rawCost / numGatherers;
               }
            else
               {
               relCost = -1.0;
               }
            break;
         }
         }

         // We now have the relative cost for the cheapest tech that gathers from this target type.
         // See if it's > 0, and the cheapest so far.  If so, save the stats, as long as it's obtainable.
         if ((techID >= 0) && (relCost < lowestCost) && (relCost >= 0.0) && (kbTechGetStatus(techID) == cTechStatusObtainable))
         {
            lowestCost = relCost;
            techToGet = techID;
         }
      }

      if ((techToGet >= 0) &&
          ((lowestCost < 40.0) ||                       // We have a tech, and it doesn't cost more than 40 per gatherer.
           (aiTreatyGetEnd() > time + 10 * 60 * 1000))) // Keep researching economy upgrades during treaty.
      {

         // If a plan has been running for 3 minutes...
         if ((startTime > 0) && (time > (startTime + 180000)))
         {
            // If it's still the tech we want, reset the start time counter and quit out.  Otherwise, kill it.
            if (aiPlanGetVariableInt(gEconUpgradePlan, cResearchPlanTechID, 0) == techToGet)
            {
               startTime = time;
               return;
            }
            else
            {
               debugTechs("Destroying econ upgrade plan id: " + gEconUpgradePlan +
                  " because it has been running more than 3 minutes");
               aiPlanDestroy(gEconUpgradePlan);
            }
         }

         // Research Market upgrades in age1 immediately if we can afford without tasking Villagers.
         if ((age == cAge1) && (kbUnitCount(cMyID, gMarketUnit, cUnitStateAlive) > 0) &&
             (kbCanAffordTech(techToGet, cEconomyEscrowID) == true))
         {
            aiTaskUnitResearch(getUnit(gMarketUnit), techToGet);
            return;
         }

         // Plan doesn't exist, or we just killed it due to timeout.
         gEconUpgradePlan = aiPlanCreate("Econ upgrade tech: " + kbGetTechName(techToGet), cPlanResearch);
         aiPlanSetVariableInt(gEconUpgradePlan, cResearchPlanTechID, 0, techToGet);
         aiPlanSetDesiredPriority(gEconUpgradePlan, 92);
         aiPlanSetBaseID(gEconUpgradePlan, kbBaseGetMainID(cMyID));
         if ((time > 12 * 60 * 1000) || (btRushBoom < 0.0) || (agingUp() == true) || (age >= cAge3))
         {
            aiPlanSetDesiredResourcePriority(gEconUpgradePlan, 55); // Above average.
         }
         aiPlanSetActive(gEconUpgradePlan);
         startTime = time;

         debugTechs("Creating upgrade plan for: " + kbGetTechName(techToGet) + " with id: " + gEconUpgradePlan);
      }
   }
   // Otherwise, if a plan already existed, let it run.
}

//==============================================================================
/* towerUpgradeMonitor
   Research the two upgrades for our Towers.
   The Aztecs have 2 types of Tower buildings and we can only research upgrades for one of them here.
   This forces us to have a separate rule for the War Hut upgrades
   that the Lakota also use instead of this one.
*/
//==============================================================================
rule towerUpgradeMonitor
inactive
mininterval 60
{
   // We only start upgrading Towers when we're 5 minutes away from Treaty ending.
   if (aiTreatyGetEnd() > xsGetTime() + 5 * 60 * 1000)
   {
      return;
   }

   // Defaults are the nonspecial European upgrades.
   int towerUpgrade1 = cTechFrontierOutpost;
   int towerUpgrade2 = cTechFortifiedOutpost;
   if (cMyCiv == cCivRussians)
   {
      towerUpgrade1 = cTechFrontierBlockhouse;
      towerUpgrade2 = cTechFortifiedBlockhouse;
   }
   if ((cMyCiv == cCivXPIroquois) || (cMyCiv == cCivDEInca))
   {
      towerUpgrade1 = cTechStrongWarHut;
      towerUpgrade2 = cTechMightyWarHut;
   }
   if (cMyCiv == cCivXPAztec)
   {
      towerUpgrade1 = cTechStrongNoblesHut;
      towerUpgrade2 = cTechMightyNoblesHut;
   }
   if (civIsAsian() == true)
   {
      towerUpgrade1 = cTechypFrontierCastle;
      towerUpgrade2 = cTechypFortifiedCastle;
   }
   if (civIsAfrican() == true)
   {
      towerUpgrade1 = cTechDESentryTower;
      towerUpgrade2 = cTechDEGuardTower;
   }

   bool canDisableSelf = false;

   // AssertiveWall: research tower upgrade tech a little earlier on island maps
   if (gStartOnDifferentIslands == true)
   {
      canDisableSelf = researchSimpleTechByCondition(
         towerUpgrade1, []() -> bool { return (kbUnitCount(cMyID, gTowerUnit, cUnitStateABQ) >= 2); }, gTowerUnit);

      canDisableSelf &= ((researchSimpleTechByCondition(towerUpgrade2,
         []() -> bool { return (kbUnitCount(cMyID, gTowerUnit, cUnitStateABQ) >= 3); },
         gTowerUnit)) ||
         cvMaxAge < cAge4);
   }
   else
   {
      canDisableSelf = researchSimpleTechByCondition(
         towerUpgrade1, []() -> bool { return (kbUnitCount(cMyID, gTowerUnit, cUnitStateABQ) >= 3); }, gTowerUnit);

      canDisableSelf &= ((researchSimpleTechByCondition(towerUpgrade2,
         []() -> bool { return (kbUnitCount(cMyID, gTowerUnit, cUnitStateABQ) >= 4); },
         gTowerUnit)) ||
         cvMaxAge < cAge4);
   }

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

void SufiShariaEventHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      if (kbTechGetStatus(cTechYPNatSufiSharia) == cTechStatusActive)
      {
         int settlerIncrease = gEconUnit == cUnitTypeCoureur ? 8 : 10;
         for (i = cAge1; <= cAge5)
         {
            xsArraySetInt(gTargetSettlerCounts, i, xsArrayGetInt(gTargetSettlerCounts, i) + settlerIncrease);
         }
         updateSettlersAndPopManager();
      }
   }
}

//==============================================================================
// nativeTribeUpgradeMonitor
// We have enough monitors to handle 3 different native tribes on a map.
// These rules repeatedly call the lambda to research the associated upgrades.
//==============================================================================
rule nativeTribeUpgradeMonitor1
inactive
minInterval 60
{
   int tradingPostID = checkAliveSuitableTradingPost(gNativeTribeCiv1);
   if (tradingPostID == -1)
   {
      return;
   }
   if (gNativeTribeResearchTechs1(tradingPostID) == true)
   {
      xsDisableSelf();
   }
}

rule nativeTribeUpgradeMonitor2
inactive
minInterval 60
{
   int tradingPostID = checkAliveSuitableTradingPost(gNativeTribeCiv2);
   if (tradingPostID == -1)
   {
      return;
   }
   if (gNativeTribeResearchTechs2(tradingPostID) == true)
   {
      xsDisableSelf();
   }
}

rule nativeTribeUpgradeMonitor3
inactive
minInterval 60
{
   int tradingPostID = checkAliveSuitableTradingPost(gNativeTribeCiv3);
   if (tradingPostID == -1)
   {
      return;
   }
   if (gNativeTribeResearchTechs3(tradingPostID) == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// setupNativeUpgrades
// Scan the map for minor native sockets and assign/activate the appropriate upgrade lambdas for them.
//==============================================================================
void setupNativeUpgrades()
{
   bool(int) tempLambdaStorage = nativeResearchTechsEmpty; // We need to store the lambda somewhere don't we!
   int nativeSocketType = -1;                              // Here we save the ID of the socket we found in the query.
   int amountOfUniqueNatives = 0; // We use this as a counter to determine what function pointer to assign the lambda to.
   int nativeCivFound = -1; // Every iteration we find a native socket and we assign the civ constant it belongs to to this
                            // variable. If it's not a duplicate we copy this to one of the gNativeTribeCiv variables.
   xsSetContextPlayer(0);
   int queryID = createSimpleGaiaUnitQuery(cUnitTypeNativeSocket);
   int numberResults = kbUnitQueryExecute(queryID);
   xsSetContextPlayer(cMyID);
   debugTechs("We found this many native sockets on the map: " + numberResults);
   xsSetContextPlayer(0);

   for (i = 0; < numberResults)
   {
      nativeSocketType = kbUnitGetProtoUnitID(kbUnitQueryGetResult(queryID, i)); // Get the proto constant of the socket.
      switch (nativeSocketType)
      {
      // Vanilla minor natives.
      case cUnitTypeSocketCaribs:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatKasiriBeer,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeAbstractArcher, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechNatGarifunaDrums,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArcher, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            // This upgrade is locked behind all the line upgrades for the Carib Blowgun Warriors.
            canDisableSelf &= researchSimpleTechByCondition(cTechNatCeremonialFeast,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeNatBlowgunWarrior, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivCaribs;
         break;
      }
      case cUnitTypeSocketCherokee:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechNatBasketweaving, -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivCherokee;
         break;
      }
      case cUnitTypeSocketComanche:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechNatTradeLanguage, -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechNatHorseBreeding,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

               canDisableSelf &= (researchSimpleTechByCondition(cTechNatMustangs,
                  []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 12); },
                  -1, tradingPostID));

            return (canDisableSelf);
         };
         nativeCivFound = cCivComanche;
         break;
      }
      case cUnitTypeSocketCree:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatTanning,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            canDisableSelf &= researchSimpleTech(cTechNatTextileCraftsmanship, -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivCree;
         break;
      }
      case cUnitTypeSocketMaya:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechNatCalendar, -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechNatCottonArmor,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivMaya;
         break;
      }
      case cUnitTypeSocketNootka:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechNatBarkClothing,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30);

            return (canDisableSelf);
         };
         nativeCivFound = cCivNootka;
         break;
      }
      case cUnitTypeSocketSeminole:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatBowyery,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArcher, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivSeminoles;
         break;
      }
      case cUnitTypeSocketTupi:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechNatForestBurning, -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechNatPoisonArrowFrogs,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArcher, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivTupi;
         break;
      }
      // The War Chiefs minor natives.
      case cUnitTypeSocketApache:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechNatXPApacheCactus,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30);

            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPApacheEndurance,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeLogicalTypeLandMilitary, cUnitStateABQ) >= 20); },
               -1, tradingPostID);
            
            return (canDisableSelf);
         };
         nativeCivFound = cCivApache;
         break;
      }
      case cUnitTypeSocketHuron:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            // Get after 30 minutes have passed.
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPHuronTradeMonopoly,
               []() -> bool { return (xsGetTime() >= 30 * 60 * 1000); }, -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechNatXPHuronFishWedding,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractFishingBoat, cUnitStateABQ) >= 5); },
               -1, tradingPostID)) ||
               (gGoodFishingMap == false));

            return (canDisableSelf);
         };
         nativeCivFound = cCivHuron;
         break;
      }
      case cUnitTypeSocketCheyenne:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPCheyenneHorseTrading,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 15); },
               -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechNatXPCheyenneHuntingGrounds, 
               []() -> bool { return (gTimeToFarm == false); }, -1, tradingPostID)) ||
               (gTimeToFarm == true)); // Only get this when we're not yet farming.

            return (canDisableSelf);
         };
         nativeCivFound = cCivCheyenne;
         break;
      }
      case cUnitTypeSocketKlamath:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            // Get after 30 minutes have passed.
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPKlamathHuckleberryFeast,
               []() -> bool { return (xsGetTime() >= 30 * 60 * 100); }, -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechNatXPKlamathWorkEthos,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPKlamathStrategy,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeNatKlamathRifleman, cUnitStateABQ) >= 8); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivKlamath;
         break;
      }
      case cUnitTypeSocketMapuche:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPMapucheTactics,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            // Get after 30 minutes have passed.
            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPMapucheTreatyOfQuillin,
               []() -> bool { return (xsGetTime() >= 30 * 60 * 100); },
               -1, tradingPostID);

            // Only get it relatively late in the game, aka when we have 60% of our maxPop.
            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPMapucheAdMapu,
               []() -> bool { return (kbGetPop() >= gMaxPop * 0.6); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivMapuche;
         break;
      }
      case cUnitTypeSocketNavajo:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPNavajoWeaving,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechNatXPNavajoCraftsmanship,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

            return (canDisableSelf);
         };
         nativeCivFound = cCivNavajo;
         break;
      }
      case cUnitTypeSocketZapotec:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechNatXPZapotecCultOfTheDead,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            // Get after 30 minutes have passed.
            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPZapotecCloudPeople,
               []() -> bool { return (xsGetTime() >= 30 * 60 * 100); },
               -1, tradingPostID);

            // Only get this when we're either farming or on Plantations.
            canDisableSelf &= researchSimpleTechByCondition(cTechNatXPZapotecFoodOfTheGods,
               []() -> bool { return ((gTimeToFarm || gTimeForPlantations)); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivZapotec;
         break;
      }
      // The Asian Dynasties minor natives.
      case cUnitTypeypSocketBhakti:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatBhaktiYoga,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechYPNatBhaktiReinforcedGuantlets,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeypNatTigerClaw, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeypNatMercTigerClaw, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivBhakti;
         break;
      }
      case cUnitTypeypSocketJesuit:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatJesuitSmokelessPowder,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractGunpowderTrooper, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractGunpowderCavalry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateABQ) >= 15); },
               -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechYPNatJesuitFlyingButtress,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeBuilding, cUnitStateABQ) >= 15); },
               -1, tradingPostID);

            canDisableSelf &= researchSimpleTech(cTechYPNatJesuitSchools, -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivJesuit;
         break;
      }
      case cUnitTypeypSocketShaolin:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatShaolinClenchedFist,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractRangedInfantry, cUnitStateABQ) >= 20); },
               -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechYPNatShaolinWoodClearing,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

            canDisableSelf &= researchSimpleTechByCondition(cTechYPNatShaolinDimMak,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeypNatRattanShield, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeypNatMercRattanShield, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivShaolin;
         break;
      }
      case cUnitTypeypSocketSufi:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            // Get after 30 minutes have passed.
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatSufiPilgramage, 
               []() -> bool { return (xsGetTime() >= 30 * 60 * 100); }, 
               -1, tradingPostID);

            int techStatus = kbTechGetStatus(cTechYPNatSufiSharia);

            if ((techStatus == cTechStatusActive) || (cDifficultyCurrent < cDifficultyHard))
            {
            }
            else if (techStatus == cTechStatusUnobtainable)
            {
               canDisableSelf = false;
            }
            else // Obtainable
            {
               if (kbGetAge() >= cAge3 && (cvMaxCivPop == -1) &&
                   ((gRevolutionType & cRevolutionMilitary) ==
                    0)) // We only get this upgrade on difficulties where we max out our Villagers.
                        // And don't get it when we have a cvMaxCivPop set since that can mess with what the designer intended.
                        // And don't get it when we're a military revolt, don't disable the rule though we may re-enable
                        // Settlers.
               {
                  int settlerShortfall = getSettlerShortfall();
                  int planID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, cTechYPNatSufiSharia);
                  if (planID < 0)
                  {
                     if (settlerShortfall < 10) // We're approaching our maximum Villagers so we can get this upgrade.
                     {
                        planID = createSimpleResearchPlanSpecificBuilding(cTechYPNatSufiSharia, tradingPostID);
                        aiPlanSetEventHandler(planID, cPlanEventStateChange, "SufiShariaEventHandler");
                     }
                  }
                  else if (settlerShortfall > 10) // We've lost Villagers again, first rebuild them then try this upgrade again.
                  {
                     aiPlanDestroy(planID);
                  }
               }
               canDisableSelf = false;
            }

            return (canDisableSelf);
         };
         nativeCivFound = cCivSufi;
         break;
      }
      case cUnitTypeypSocketUdasi:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatUdasiArmyOfThePure,
               []() -> bool {return (kbUnitCount(cMyID, cUnitTypeypNatChakram, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeypNatMercChakram, cUnitStateABQ) >= 10); },
               -1, tradingPostID);

            // Only get this when we're either farming or on Plantations.
            canDisableSelf &= researchSimpleTechByCondition(cTechYPNatUdasiNewYear,
               []() -> bool { return ((gTimeToFarm || gTimeForPlantations)); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivUdasi;
         break;
      }
      case cUnitTypeypSocketZen:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechYPNatZenMasterLessons,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) >= 12); },
               -1, tradingPostID);

            // Have at least some units before we want to reduce their upgrade costs.
            canDisableSelf &= researchSimpleTechByCondition(cTechYPNatZenMeritocracy,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeUnit, cUnitStateABQ) >= 20); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivZen;
         break;
      }
      // The African Royals minor natives.
      case cUnitTypedeSocketAkan:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDENatAkanHeroSpawn,
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);

            canDisableSelf &= researchSimpleTechByCondition(cTechDENatAkanDrums,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) >= 20); },
               -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechDENatAkanGoldEconomy,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30) || (gTimeForPlantations == true));

            // Only get this when we're either farming or on Plantations.
            canDisableSelf &= researchSimpleTechByCondition(cTechDENatAkanCocoaBeans,
               []() -> bool { return ((gTimeToFarm || gTimeForPlantations)); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivAkan;
         break;
      }
      case cUnitTypedeSocketBerbers:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDENatBerberDynasties, 
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);

            canDisableSelf = canDisableSelf &&((researchSimpleTechByCondition(cTechDENatBerberDesertKings,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID)) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

            canDisableSelf &= ((researchSimpleTechByCondition(cTechDENatBerberSaltCaravans, 
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3));

            return (canDisableSelf);
         };
         nativeCivFound = cCivBerbers;
         break;
      }
      case cUnitTypedeSocketSomali:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            // Expect we start farming/plantations somewhere in age 3.
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDENatSudaneseHakura, 
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID) ||
               (cvMaxAge < cAge3));

            canDisableSelf &= (researchSimpleTechByCondition(cTechDENatSomaliCoinage,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
               -1, tradingPostID) ||
               (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30) || (gTimeForPlantations == true));

            canDisableSelf &= (researchSimpleTechByCondition(cTechDENatSomaliOryxShields,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) >= 15); },
               -1, tradingPostID));

            canDisableSelf &= (researchSimpleTechByCondition(cTechDENatSomaliJileDaggers,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractFootArcher, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractRifleman, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractMeleeSkirmisher, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractUrumi, cUnitStateABQ) >= 20); },
               -1, tradingPostID));

            // We as the AI can't really use the information we gain via the Lightouse effect so get it for our human friends.
            if (getHumanAllyCount() >= 1)
            {
               canDisableSelf &= (researchSimpleTechByCondition(cTechDENatSomaliLighthouses,
                  []() -> bool { return ((kbGetAge() >= cAge4) && (getHumanAllyCount() >= 1)); }, 
                  -1, tradingPostID) ||
                  (cvMaxAge < cAge4));
            }

            return (canDisableSelf);
         };
         nativeCivFound = cCivSomali;
         break;
      }
      case cUnitTypedeSocketSudanese:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            // Expect we start farming/plantations somewhere in age 3 so get the price reduction then.
            bool canDisableSelf = researchSimpleTechByCondition(cTechDENatSudaneseHakura,
               []() -> bool { return (kbGetAge() >= cAge3); },
               -1, tradingPostID) ||
               (cvMaxAge < cAge3);

            canDisableSelf &= researchSimpleTechByCondition(cTechDENatSudaneseQuiltedArmor,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateABQ) >= 10); },
               -1, tradingPostID);

            canDisableSelf &= ((researchSimpleTechByCondition(cTechDENatSudaneseRedSeaTrade,
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3));

            return (canDisableSelf);
         };
         nativeCivFound = cCivSudanese;
         break;
      }
      case cUnitTypedeSocketYoruba:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDENatYorubaHerbalism,
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);

            return (canDisableSelf);
         };
         nativeCivFound = cCivYoruba;
         break;
      }
      // Definitive Edition (no DLC) minor natives.
      case cUnitTypeSocketInca: // Rebranded as Quechuas.
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechNatChasquisMessengers,
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);
        
            canDisableSelf &= ((researchSimpleTechByCondition(cTechNatMetalworking,
               []() -> bool { return (gTimeForPlantations == false &&
               (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) > 30)); },
               -1, tradingPostID)) ||
               (gTimeForPlantations == true) || (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

            return (canDisableSelf);
         };
         nativeCivFound = cCivIncas;
         break;
      }
      // Brooklyn minor natives.
      case cUnitTypedeSocketWittelsbach:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechDENatWittelsbachHuntingGear,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractSkirmisher, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypedeNatMountainTrooper, cUnitStateABQ) >= 10); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivWittelsbach;
         break;
      }
      case cUnitTypedeSocketHabsburg:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechDENatHabsburgViennaCongress, -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivHabsburg;
         break;
      }
      case cUnitTypedeSocketBourbon:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
         
         bool canDisableSelf = researchSimpleTechByCondition(cTechDENatBourbonRoyalTax,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeBuilding, cUnitStateABQ) >= 20); },
            -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivHabsburg;
         break;
      }
      case cUnitTypedeSocketJagiellon:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechDENatJagiellonPancerni,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandCavalry, cUnitStateABQ) >= 15); },
            -1, tradingPostID);

            canDisableSelf &= researchSimpleTechByCondition(cTechDENatJagiellonSarmatism,
               []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArcher, cUnitStateABQ) +
               kbUnitCount(cMyID, cUnitTypeShip, cUnitStateABQ) >= 15); },
               -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivJagiellon;
         break;
      }
      case cUnitTypedeSocketVasa:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDENatVasaGoldenLiberty,
               []() -> bool { return (kbGetAge() >= cAge3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);
               
            canDisableSelf &= researchSimpleTechByCondition(cTechDENatVasaTarKilns,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeUnit, cUnitStateABQ) >= 15); },
            -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivVasa;
         break;
      }
      case cUnitTypedeSocketHanover:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTech(cTechDENatHanoverRoyalScotsGrey, -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivHanover;
         break;
      }
      case cUnitTypedeSocketOldenburg:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = researchSimpleTechByCondition(cTechDENatOldenBurgKalthoffRepeaters,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractSkirmisher, cUnitStateABQ) >= 15); },
            -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivOldenburg;
         break;
      }
      case cUnitTypedeSocketWettin: // Get nothing.
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = true;

            return (canDisableSelf);
         };
         nativeCivFound = cCivWettin;
         break;
      }
      case cUnitTypedeSPCSocketCityState:
      {
         tempLambdaStorage = [](int tradingPostID = -1) -> bool {
            bool canDisableSelf = (researchSimpleTechByCondition(cTechDESPCFortifiedCityState,
               []() -> bool { return (kbGetAge() >= cAge3 && kbUnitCount(cMyID, cUnitTypedeSPCCityTower, cUnitStateAlive) >= 3); }, -1, tradingPostID)) ||
               (cvMaxAge < cAge3);
               
            canDisableSelf &= researchSimpleTechByCondition(cTechDESPCArtilleryInnovations,
            []() -> bool { return (kbGetAge() >= cAge3); },
            -1, tradingPostID);

            return (canDisableSelf);
         };
         nativeCivFound = cCivSPCCityState;
         break;
      }
      }

      // We have found a native now let's see if we have already processed the ID before and it's a duplicate or if it's new and
      // assign it to an upgrade rule. There are sockets in the game which we don't handle here so guard for assigining -1.
      if ((amountOfUniqueNatives == 0) && (nativeCivFound != -1))
      {
         xsSetContextPlayer(cMyID);
         gNativeTribeCiv1 = nativeCivFound;
         gNativeTribeResearchTechs1 = tempLambdaStorage;
         xsEnableRule("nativeTribeUpgradeMonitor1");
         amountOfUniqueNatives++;
         debugTechs("gNativeTribeCiv1 is: " + kbGetCivName(gNativeTribeCiv1));
         xsSetContextPlayer(0);
      }
      else if ((amountOfUniqueNatives == 1) && (gNativeTribeCiv1 != nativeCivFound) && (nativeCivFound != -1))
      {
         xsSetContextPlayer(cMyID);
         gNativeTribeCiv2 = nativeCivFound;
         gNativeTribeResearchTechs2 = tempLambdaStorage;
         xsEnableRule("nativeTribeUpgradeMonitor2");
         amountOfUniqueNatives++;
         debugTechs("gNativeTribeCiv2 is: " + kbGetCivName(gNativeTribeCiv2));
         xsSetContextPlayer(0);
      }
      else if ((amountOfUniqueNatives == 2) && (gNativeTribeCiv1 != nativeCivFound) && 
               (gNativeTribeCiv2 != nativeCivFound) && (nativeCivFound != -1))
      {
         xsSetContextPlayer(cMyID);
         gNativeTribeCiv3 = nativeCivFound;
         gNativeTribeResearchTechs3 = tempLambdaStorage;
         xsEnableRule("nativeTribeUpgradeMonitor3");
         amountOfUniqueNatives++;
         debugTechs("gNativeTribeCiv3 is: " + kbGetCivName(gNativeTribeCiv3));
         return; // We have hit the maximum of natives possible that we can handle, we can safely quit now.
      }
   }
   xsSetContextPlayer(cMyID);
}

rule tradeRouteUpgradeMonitor
inactive
minInterval 90
{
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
                   ownedTradingPostID) == cTechStatusObtainable) &&
             (kbGetAge() >= cAge4))
         {
            if (numberAllyTradingPosts - numberEnemyTradingPosts >= 2) 
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
// fishingBoatUpgradeMonitor
//==============================================================================
rule fishingBoatUpgradeMonitor
inactive
minInterval 60
{
   bool canDisableSelf = researchSimpleTechByCondition(cTechGillNets,
      []() -> bool { return (kbUnitCount(cMyID, gFishingUnit, cUnitStateABQ) >= 7); },
      gDockUnit);
   
   canDisableSelf &= researchSimpleTechByCondition(cTechLongLines,
      []() -> bool { return (kbUnitCount(cMyID, gFishingUnit, cUnitStateABQ) >= 9); },
      gDockUnit);
      
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
   }

//==============================================================================
// navyUpgradeMonitor
// We don't get the very expensive European navy upgrades since we're bad at water.
// Natives don't have any regular navy upgrades so this rule isn't activated for them.
//==============================================================================
rule navyUpgradeMonitor
inactive
minInterval 90
   {
   bool canDisableSelf = false;

   if (civIsAfrican() == true)
   {
      canDisableSelf = researchSimpleTechByCondition(cTechDERiverSkirmishes,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3); },
         gDockUnit);

      canDisableSelf &= researchSimpleTechByCondition(cTechDERiverboatHitpoints,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3); },
         gDockUnit);
      }
   else // Europeans or Asians.
   {
      canDisableSelf = researchSimpleTechByCondition(cTechCarronade,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3); },
         gDockUnit);

      canDisableSelf &= researchSimpleTechByCondition(cTechPercussionLocks,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3); },
         gDockUnit);

      canDisableSelf &= researchSimpleTechByCondition(cTechArmorPlating,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3); },
         gDockUnit);
      }
   
   if (canDisableSelf == true)
   {
      xsDisableSelf();
      }
   }

//==============================================================================
// arsenalUpgradeMonitor
//==============================================================================
rule arsenalUpgradeMonitor
inactive
minInterval 60
{
   int researchBuildingPUID = -1;

   // New Ways cards.
   if ((cMyCiv == cCivXPIroquois) || (cMyCiv == cCivXPSioux))
   {
      researchBuildingPUID = cMyCiv == cCivXPIroquois ? cUnitTypeLonghouse : cUnitTypeTeepee;
   }
   // Dutch Consulate Arsenal.
   else if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
   {
      researchBuildingPUID = cUnitTypeypArsenalAsian;
   }
   // This means we're either European or African (Portuguese/British Alliance).
   else
   {
      static int africanWagonMaintainPlan = -1;
      researchBuildingPUID = cUnitTypeArsenal;
   }

   if (kbUnitCount(cMyID, researchBuildingPUID, cUnitStateABQ) < 1)
   {
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         if (kbUnitCount(cMyID, cUnitTypeypArsenalWagon, cUnitStateAlive) < 1)
         { // We can't remake this so disable the Rule.
            xsDisableSelf();
         }
      }
      else if (civIsAfrican() == true)
      {
         // We only want an Arsenal when we're 10 minutes away from Treaty ending.
         if (aiTreatyGetEnd() > xsGetTime() + 10 * 60 * 1000)
         {
            return;
         }
         if (cvOkToBuild == false)
         {
            aiPlanDestroy(africanWagonMaintainPlan);
            xsDisableSelf();
         }
         if (africanWagonMaintainPlan < 0)
         {
            africanWagonMaintainPlan = createSimpleMaintainPlan(cUnitTypedeTrainArsenalWagon,
               1, true, kbBaseGetMainID(cMyID), 1);
         }
         else // Set the maintain plan to 1.
         {
            aiPlanSetVariableInt(africanWagonMaintainPlan, cTrainPlanNumberToMaintain, 0, 1);
         }
      }
      else if (cMyCiv == cCivXPSioux)
      {
         // We only want a Teepee when we're 10 minutes away from Treaty ending.
         if (aiTreatyGetEnd() > xsGetTime() + 10 * 60 * 1000)
         {
            return;
         }
         if (cvOkToBuild == false)
         {
            xsDisableSelf();
         }
         // See if we already have a build plan and otherwise create one.
         if (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypeTeepee) < 0)
         {
            createSimpleBuildPlan(cUnitTypeTeepee, 1, 50, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
         }
      }
      else if (cMyCiv != cCivXPIroquois) 
      {
         // We only want an Arsenal when we're 10 minutes away from Treaty ending.
         if (aiTreatyGetEnd() > xsGetTime() + 10 * 60 * 1000)
         {
            return;
         }
         if (cvOkToBuild == false)
         {
            xsDisableSelf();
         }
         // See if we already have a build plan and otherwise create one.
         if (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypeArsenal) < 0)
         {
            createSimpleBuildPlan(cUnitTypeArsenal, 1, 50, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
         }
      }
      return;
   }
   else if (civIsAfrican() == true)
   {
      if (africanWagonMaintainPlan >= 0) // We have an Arsenal and a plan so null out the maintain plan.
      {
         aiPlanSetVariableInt(africanWagonMaintainPlan, cTrainPlanNumberToMaintain, 0, 0);
      }
   }

   // Shared upgrades.
   bool canDisableSelf = researchSimpleTechByCondition(cTechCavalryCuirass,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHeavyCavalry, cUnitStateABQ) >= 12); },
      researchBuildingPUID);

   canDisableSelf &= researchSimpleTechByCondition(cTechInfantryBreastplate,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandInfantry, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypeAbstractFootArcher, cUnitStateABQ) >= 12); },
      researchBuildingPUID);

   // The Lakota don't have this upgrade.
   // Only get 'Heated Shot' upgrade on water maps.
   if ((cMyCiv != cCivXPSioux) && (gNavyMap == true))
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechHeatedShot,
         []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateABQ) >= 2) &&
         (getUnitCountByLocation(cUnitTypeAbstractWarShip, cPlayerRelationEnemyNotGaia, cUnitStateAlive) >= 2)); }, 
         researchBuildingPUID);
   }

   // The Haudenosaunee and Lakota don't have these 2 upgrades.
   if ((cMyCiv != cCivXPIroquois) && (cMyCiv != cCivXPSioux))
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechGunnersQuadrant,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateABQ) >= 4); },
         researchBuildingPUID);

      canDisableSelf &= researchSimpleTechByCondition(cTechBayonet,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractMusketeer, cUnitStateABQ) >= 12); },
         researchBuildingPUID);
   }

   // The Japanese Arsenal doesn't have these 2 upgrades.
   if ((cMyCiv != cCivJapanese) && (cMyCiv != cCivSPCJapanese) && (cMyCiv != cCivSPCJapaneseEnemy))
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechRifling,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractRifleman, cUnitStateABQ) >= 12); },
         researchBuildingPUID);

      canDisableSelf &= researchSimpleTechByCondition(cTechCaracole,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractLightCavalry, cUnitStateABQ) >= 12); },
         researchBuildingPUID);
   }

   // Other civs can only get this upgrade in the advanced Arsenal but for simplicity for the Lakota it's checked here just for
   // them.
   if (cMyCiv == cCivXPSioux)
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechPillage,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandCavalry, cUnitStateABQ) >= 8); },
         researchBuildingPUID);
   }

   if (canDisableSelf == true)
   {
      if (civIsAfrican() == true)
      {
         aiPlanDestroy(africanWagonMaintainPlan);
      }
      xsDisableSelf();
   }
}

//==============================================================================
// advancedArsenalUpgradeMonitor
//==============================================================================
rule advancedArsenalUpgradeMonitor
inactive
minInterval 60
{
   int researchBuildingID = -1;

   // We are Japanese and have a Golden Pavilion.
   if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
   {
      researchBuildingID = getUnit(gGoldenPavilionPUID, cMyID, cUnitStateAlive);
   }
   // We are European and have sent the Advanced Arsenal card.
   else
   {
      researchBuildingID = getUnit(cUnitTypeArsenal, cMyID, cUnitStateAlive);
   }

   if (researchBuildingID < 0)
   {
      // We've lost our Golden Pavilion, so disable this Rule.
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
      {
         xsDisableSelf();
      }
      // We only want an Arsenal when we're 10 minutes away from Treaty ending.
      else if (aiTreatyGetEnd() > xsGetTime() + 10 * 60 * 1000)
      {
         if (cvOkToBuild == false)
         {
            xsDisableSelf();
         }
         // See if we already have a build plan and otherwise create one.
         if (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, cUnitTypeArsenal) < 0)
         {
            createSimpleBuildPlan(cUnitTypeArsenal, 1, 50, false, cMilitaryEscrowID, kbBaseGetMainID(cMyID), 1);
         }
      }
      return;
   }

   // Shared Upgrades.
   bool canDisableSelf = researchSimpleTechByCondition(cTechPaperCartridge,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractGunpowderTrooper, cUnitStateABQ) >= 12); },
      -1, researchBuildingID);

   canDisableSelf &= researchSimpleTechByCondition(cTechFlintlock,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractGunpowderTrooper, cUnitStateABQ) >= 12); },
      -1, researchBuildingID);

   canDisableSelf &= researchSimpleTechByCondition(cTechProfessionalGunners,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateABQ) >= 6); },
      -1, researchBuildingID);

   canDisableSelf &= researchSimpleTechByCondition(cTechPillage,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractHandCavalry, cUnitStateABQ) >= 8); },
      -1, researchBuildingID);

   // The Golden Pavilion doesn't have the following 2 upgrades so don't check.
   if ((cMyCiv != cCivJapanese) || (cMyCiv != cCivSPCJapanese) || (cMyCiv != cCivSPCJapaneseEnemy))
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechTrunion,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateABQ) >= 6); },
         -1, researchBuildingID);

      // Only these civs have access to this upgrade from all the European civs.
      if ((cMyCiv == cCivBritish) || (cMyCiv == cCivDutch) || (cMyCiv == cCivOttomans) || (cMyCiv == cCivRussians) ||
          (cMyCiv == cCivDESwedish))
      {
         canDisableSelf &= researchSimpleTechByCondition(cTechIncendiaryGrenades,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeGrenadier, cUnitStateABQ) >= 12); },
            -1, researchBuildingID);
      }
   }

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
/* churchUpgradeMonitor
   We don't get Bastion because the AI doesn't build Walls at this moment.
   We don't get Marcantilism because the AI isn't very good with shipments.
   We don't get Mission Fervor because the AI has no proper healing system.
   This monitor is also used for the specific Mexican Cathedral upgrades.
   We don't get the Padre specific technologies since the AI doesn't know how to use their effects.
   We don't get Holy Mass because the AI isn't very good with shipments.
   We don't get State Religion because we can't plan for this and it costs Gold here.
*/
//==============================================================================
rule churchUpgradeMonitor
inactive
minInterval 60
{
   int researchBuildingPUID = -1;

   if (civIsAsian() == true)
   {
      researchBuildingPUID = cUnitTypeypChurch;
   }
   else if (cMyCiv == cCivDEMexicans)
   {
      researchBuildingPUID = cUnitTypedeCathedral;
   }
   else // We're European or Ethiopians with Jesuit alliance.
   {
      researchBuildingPUID = cUnitTypeChurch;
   }

   // Quit if there is no Church / Cathedral.
   if (kbUnitCount(cMyID, researchBuildingPUID, cUnitStateAlive) < 1)
   {
      return;
   }

   // Just get the 2 LOS upgrades, still low priority upgrades.
   bool canDisableSelf = researchSimpleTech(cTechChurchTownWatch, researchBuildingPUID, -1, 49);

   canDisableSelf &= researchSimpleTech(cTechChurchGasLighting, researchBuildingPUID, -1, 49);

   // Get the 2 training time reduction upgrades once we already have 60% of our gMaxPop.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechChurchMassCavalry,
      []() -> bool { return (kbGetPop() >= gMaxPop * 0.6); },
      researchBuildingPUID)) ||
      (cvMaxAge < cAge4));

   canDisableSelf &= ((researchSimpleTechByCondition(cTechChurchStandingArmy,
      []() -> bool { return (kbGetPop() >= gMaxPop * 0.6); },
      researchBuildingPUID)) ||
      (cvMaxAge < cAge4));

   if (cMyCiv == cCivDEMexicans)
   {
      // Only get this upgrade when we're at max Houses. We will make less Houses on lower difficulties so account for that.
      canDisableSelf &= researchSimpleTechByCondition(cTechDEChurchSevenHouses,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeHouseMed, cUnitStateAlive) == gMaxPop / 10); },
         researchBuildingPUID);

      // Get at 500xp.
      canDisableSelf &= researchSimpleTechByCondition(cTechDEChurchDiaDeLosMuertos,
         []() -> bool { return (kbTechGetHCCardValuePerResource(cTechDEChurchDiaDeLosMuertos, cResourceXP) >= 500); },
         researchBuildingPUID);
   }

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// factoryUpgradeMonitor
//==============================================================================
rule factoryUpgradeMonitor
inactive
minInterval 45
{
   if ((kbUnitCount(cMyID, cUnitTypeFactory, cUnitStateABQ) < 1) &&
       (kbUnitCount(cMyID, cUnitTypeFactoryWagon, cUnitStateAlive) < 1))
   {
      xsDisableSelf();
      return;
   }
   
   bool canDisableSelf = researchSimpleTechByCondition(cTechFactoryCannery,
      []() -> bool { return (getUnitCountByTactic(cUnitTypeFactory, cMyID, cUnitStateAlive, cTacticFood) >= 1); },
      cUnitTypeFactory);
   
   canDisableSelf &= researchSimpleTechByCondition(cTechFactoryWaterPower,
      []() -> bool { return (getUnitCountByTactic(cUnitTypeFactory, cMyID, cUnitStateAlive, cTacticWood) >= 1); },
      cUnitTypeFactory);
   
   canDisableSelf &= researchSimpleTechByCondition(cTechFactorySteamPower,
      []() -> bool { return (getUnitCountByTactic(cUnitTypeFactory, cMyID, cUnitStateAlive, cTacticNormal) >= 1); },
      cUnitTypeFactory);
   
   canDisableSelf &= researchSimpleTechByCondition(cTechFactoryMassProduction,
      []() -> bool { return (getUnitCountByTactic(cUnitTypeFactory, cMyID, cUnitStateAlive, cTechFactoryMassProduction) >= 1); },
      cUnitTypeFactory);
   
   if (cvMaxAge == cAge5)
   {
      if (cMyCiv == cCivOttomans)
      {
         canDisableSelf &= researchSimpleTechByCondition(cTechImperialBombard,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeGreatBombard, cUnitStateAlive) >= 4); },
            cUnitTypeFactory);
      }
      else if (cMyCiv == cCivBritish)
      {
         canDisableSelf &= researchSimpleTechByCondition(cTechImperialRocket,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeRocket, cUnitStateAlive) >= 4); },
            cUnitTypeFactory);
      }
      else
      {
         canDisableSelf &= researchSimpleTechByCondition(cTechImperialCannon,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeCannon, cUnitStateAlive) >= 4); },
            cUnitTypeFactory);
      }
   }
   
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

void GalataTowerDistrictEventHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      if (kbTechGetStatus(cTechChurchGalataTowerDistrict) == cTechStatusActive)
      {
         updateSettlersAndPopManager();
      }
   }
}

void TopkapiEventHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      if (kbTechGetStatus(cTechChurchTopkapi) == cTechStatusActive)
      {
         updateSettlersAndPopManager();
      }
   }
}

void TanzimatEventHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      if (kbTechGetStatus(cTechChurchTanzimat) == cTechStatusActive)
      {
         updateSettlersAndPopManager();
      }
   }
}

//==============================================================================
/* ottomanMonitor
   This Rule is a little bit more complex since we don't want to get Settler BL increases
   when that would put our BL above our own Settler limits.
   But our Settler limits change when we're playing SPC so we must take all that into account.
*/
//==============================================================================
rule ottomanMonitor
inactive
minInterval 25
{
   int planID = -1;
   // If we have no Mosque we're done.
   int mosqueID = getUnit(cUnitTypeChurch, cMyID, cUnitStateAlive);
   if (mosqueID < 0)
   {
      return;
   }
   
   bool canDisableSelf = researchSimpleTech(cTechChurchMilletSystem, -1, mosqueID, 70);
   
   if (cDifficultyCurrent >= cDifficultyModerate)
   {
      canDisableSelf &= researchSimpleTech(cTechChurchKopruluViziers, -1, mosqueID);
      
      canDisableSelf &= researchSimpleTech(cTechChurchAbbassidMarket, -1, mosqueID);
      
      // 25 Settler limit to 45.
      canDisableSelf &= researchSimpleTechByConditionEventHandler(cTechChurchGalataTowerDistrict,
         []() -> bool { return (kbGetBuildLimit(cMyID, cUnitTypeSettler) - 
         kbUnitCount(cMyID, cUnitTypeSettler, cUnitStateABQ) <= 5); },
         "GalataTowerDistrictEventHandler", -1, mosqueID, 70);

      if ((cDifficultyCurrent >= cDifficultyHard) || 
          ((cDifficultyCurrent == cDifficultyModerate) && (gSPC == false)))
      {
         // 45 Settler limit to 70.
         canDisableSelf &= researchSimpleTechByConditionEventHandler(cTechChurchTopkapi,
            []() -> bool { return (kbGetBuildLimit(cMyID, cUnitTypeSettler) - 
            kbUnitCount(cMyID, cUnitTypeSettler, cUnitStateABQ) <= 7); },
            "TopkapiEventHandler", -1, mosqueID, 70);
         
         if ((cDifficultyCurrent >= cDifficultyExpert) || 
             ((cDifficultyCurrent == cDifficultyHard) && (gSPC == false)))
         {
            // 70 Settler limit to 99.
            canDisableSelf &= researchSimpleTechByConditionEventHandler(cTechChurchTanzimat,
               []() -> bool { return (kbGetBuildLimit(cMyID, cUnitTypeSettler) - 
               kbUnitCount(cMyID, cUnitTypeSettler, cUnitStateABQ) < 10); },
               "TanzimatEventHandler", -1, mosqueID, 70);
         }
      }
   }

   if (canDisableSelf == true)
   {
      xsDisableSelf();
      return;
   }
}

//==============================================================================
// warHutUpgradeMonitor
//==============================================================================
rule warHutUpgradeMonitor
inactive
minInterval 60
{
   bool canDisableSelf = researchSimpleTechByCondition(cTechStrongWarHut, 
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateABQ) >= 3); },
      cUnitTypeWarHut);

   canDisableSelf &= ((researchSimpleTechByCondition(cTechMightyWarHut,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateABQ) >= 4); },
      cUnitTypeWarHut)) ||
      cvMaxAge < cAge4);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// bigButtonAztecMonitor
// This rule researches all the big button upgrades for the Aztecs.
// Excluding the raiding parties, those are used as minutemen in useWarParties.
// Cipactli Worship just too expensive for naval warfare.
//==============================================================================
rule bigButtonAztecMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 20)
   {
      return; // Avoid getting upgrades here with a weak economy.
   }

   // Cheap upgrade, just get it and hope our War Chief stays alive.
   bool canDisableSelf = researchSimpleTechByCondition(cTechBigFirepitFounder,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeCommunityPlaza, cUnitStateABQ) >= 1); },
      cUnitTypeCommunityPlaza);

   // Get at least 8 Otontin Slingers.
   canDisableSelf &= researchSimpleTechByCondition(cTechBigHouseCoatlicue,
      []() -> bool { return ( (xsGetTime() >= 16 * 60 * 1000) &&
      (kbUnitCount(cMyID, cUnitTypeHouseAztec, cUnitStateABQ) >= 1) &&
      (indexProtoUnitInUnitPicker(cUnitTypexpMacehualtin) > -1)); },
      cUnitTypeHouseAztec);

   // Get at least 12 Puma Spearmen.
   canDisableSelf &= researchSimpleTechByCondition(cTechBigWarHutBarometz,
      []() -> bool { return ((xsGetTime() >= 24 * 60 * 1000) && 
      (kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateABQ) >= 1) &&
      (indexProtoUnitInUnitPicker(cUnitTypexpPumaMan) > -1)); },
      cUnitTypeWarHut);

   // Get at least 10 Eagle Runner Knights.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigFarmCinteotl,
      []() -> bool {return ((xsGetTime() >= 20 * 60 * 1000) && 
      (kbUnitCount(cMyID, cUnitTypeFarm, cUnitStateABQ) >= 1) &&
      (indexProtoUnitInUnitPicker(cUnitTypexpMacehualtin) > -1)); },
      cUnitTypeFarm)) ||
      (cvMaxAge < cAge3));

   // Get at least 10 Arrow Knights.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigNoblesHutWarSong,
      []() -> bool {return ((xsGetTime() >= 20 * 60 * 1000) &&
      (kbUnitCount(cMyID, cUnitTypeNoblesHut, cUnitStateABQ) >= 1) &&
      (indexProtoUnitInUnitPicker(cUnitTypexpArrowKnight) > -1)); },
      cUnitTypeNoblesHut)) ||
      (cvMaxAge < cAge3));

   // Get at least 7 Skull Knights.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigPlantationTezcatlipoca,
      []() -> bool { return ((xsGetTime() >= 28 * 60 * 1000) &&
      (kbUnitCount(cMyID, cUnitTypePlantation, cUnitStateABQ) >= 1)); },
      cUnitTypePlantation)) ||
      (cvMaxAge < cAge3));

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// bigButtonIncaMonitor
// This rule researches all the big button upgrades for the Incas.
// Excluding the raiding parties, those are used as minutemen in useWarParties.
// We don't get Queen's Festival since it's just underpowered right now.
// We don't get Inti Festival since the AI isn't particularly good at using shipments anyway.
// We don't get Viracocha Worship since we don't have a specific strategy on what to do with those 2 builders.
// We don't get Urcuchillay Worship since we don't have a resource strategy to base this upgrade on.
//==============================================================================
rule bigButtonIncaMonitor
inactive
minInterval 60
{
   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 20)
   {
      return; // Avoid getting upgrades here with a weak economy.
   }

   // Get at least 4 Fishing Boats & Chincha Rafts.
   bool canDisableSelf = ((researchSimpleTechByCondition(cTechdeBigDockTotora,
      []() -> bool { return ((xsGetTime() >= 20 * 60 * 1000) && 
      (kbUnitCount(cMyID, cUnitTypeDock, cUnitStateABQ) >= 1)); },
      cUnitTypeDock)) ||
      (cvMaxAge < cAge3) || 
      (gNavyMap == false));

   // Have at least 20 Infantry before we get this upgrade.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechdeBigWarHutHualcana,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeAbstractInfantry, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateABQ) >= 20) &&
      (kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateABQ) >= 1)); },
      cUnitTypeWarHut)) ||
      (cvMaxAge < cAge3));

   // Get at least 6 Macemen.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechdeBigFirePitRoyalFestival,
      []() -> bool { return ((xsGetTime() >= 24 * 60 * 1000) &&
      (kbUnitCount(cMyID, cUnitTypeCommunityPlaza, cUnitStateABQ) >= 1) &&
      (indexProtoUnitInUnitPicker(cUnitTypedeMaceman) > -1)); },
      cUnitTypeCommunityPlaza)) ||
      (cvMaxAge < cAge3));

   // We're already in Industrial and have 2+ Estates, still a low priority upgrade.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechdeBigPlantationCoca,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypePlantation, cUnitStateABQ) >= 2); },
      cUnitTypePlantation, -1, 45)) ||
      (cvMaxAge < cAge4));

   // Expensive upgrade so make sure we're already progressed pretty far in the game.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechdeBigStrongholdThunderbolts,
      []() -> bool {return ((kbGetAge() >= cAge4) && 
      (kbUnitCount(cMyID, cUnitTypedeIncaStronghold, cUnitStateABQ) >= 1) &&
      (kbGetPop() >= gMaxPop * 0.6)); },
      cUnitTypedeIncaStronghold)) ||
      (cvMaxAge < cAge4));

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// bigButtonLakotaMonitor
// This rule researches all the big button upgrades for the Lakota.
// Excluding the raiding parties, those are used as minutemen in useWarParties.
// We don't get Battle Anger since it's pretty expensive and our War Chief micro/macro isn't good enough.
//==============================================================================
rule bigButtonLakotaMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 20)
   {
      return; // Avoid getting upgrades here with a weak economy.
   }

   // Get the upgrade if we have 12 or more cavalry units.
   bool canDisableSelf = researchSimpleTechByCondition(cTechBigFarmHorsemanship,
      []() -> bool {return ((kbUnitCount(cMyID, cUnitTypeFarm, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 12)); },
      cUnitTypeFarm);

   // Get the upgrade if we see at least 2 enemy artillery, since we're Lakota we can assume we will train cavalry to counter
   // the artillery.
   canDisableSelf &= researchSimpleTechByCondition(cTechBigCorralBonepipeArmor,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeCorral, cUnitStateABQ) >= 1) &&
      (getUnitCountByLocation(cUnitTypeAbstractArtillery, cPlayerRelationEnemyNotGaia, cUnitStateAlive) >= 2)); },
      cUnitTypeCorral);

   // Get the upgrade if we have atleast 30 Villagers, still a low priority upgrade.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechDEBigTribalMarketplaceCoopLakota,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypedeFurTrade, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30)); },
      cUnitTypedeFurTrade, -1, 45)) ||
      (cvMaxAge < cAge3) || 
      (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

   // Get the upgrade if we have atleast 3 War ships, lower priority upgrade just because it's naval.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigDockFlamingArrows,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeDock, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3)); },
      cUnitTypeDock, -1, 45)) ||
      (cvMaxAge < cAge3) || 
      (gNavyMap == false));

   // Just get the upgrade when in Fortress age, still a low priority upgrade.
   canDisableSelf &= ((researchSimpleTech(cTechBigWarHutWarDrums, cUnitTypeWarHut, -1, 45)) ||
      (cvMaxAge < cAge3));

   // Get the upgrade if we have at least 10 Rifle units.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigPlantationGunTrade,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypePlantation, cUnitStateABQ) >= 1) &&
      ((kbUnitCount(cMyID, cUnitTypexpWarRifle, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypexpRifleRider, cUnitStateABQ) >= 10))); },
      cUnitTypePlantation)) ||
      (cvMaxAge < cAge3));

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// bigButtonHaudenosauneeMonitor
// This rule researches all the big button upgrades for the Haudenosaunee.
// Excluding the raiding parties, those are used as minutemen in useWarParties.
// We don't get Secret Society since the AI has no real strategy for healing units and it will
// 	just lose its War Chief anyway and not retreat it to use it as a healer.
// We don't get Woodland Dwellers since we don't have a resource strategy to base this upgrade on.
// We don't get New Year Festival since the AI isn't particularly good at using shipments anyway.
// We don't get Strawberry Festival since we don't have a resource strategy to base this upgrade on.
// We don't get Maple Festival since we don't have a resource strategy to base this upgrade on.
//==============================================================================
rule bigButtonHaudenosauneeMonitor
inactive
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive) < 20)
   {
      return; // Avoid getting upgrades here with a weak economy.
   }

   // Get the upgrade if we have 12 or more cavalry units.
   bool canDisableSelf = researchSimpleTechByCondition(cTechBigCorralHorseSecrets,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeCorral, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 12)); },
      cUnitTypeCorral);

   // Get the upgrade if we have 25 or more affected units or if 20 minutes have passed and we have 10 or more affected units,
   // it's a great upgrade so we kinda need it.
   int techStatus = kbTechGetStatus(cTechBigWarHutLacrosse);
   if (techStatus == cTechStatusObtainable)
   {
      int planID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, cTechBigWarHutLacrosse);
      bool buildingAlive = kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateAlive) >= 1;
      int unitCount = kbUnitCount(cMyID, cUnitTypexpAenna, cUnitStateAlive) +
                      kbUnitCount(cMyID, cUnitTypexpTomahawk, cUnitStateAlive) +
                      kbUnitCount(cMyID, cUnitTypexpMusketWarrior, cUnitStateAlive);
      if (planID >= 0)
      {
         if ((buildingAlive == false) || (unitCount < 10))
         {
            aiPlanDestroy(planID);
         }
      }
      else if ((buildingAlive == true) && ((unitCount >= 25) || ((xsGetTime() >= 20 * 60 * 1000) && (unitCount >= 10))))
      {
         createSimpleResearchPlan(cTechBigWarHutLacrosse, cUnitTypeWarHut);
      }
   }
   canDisableSelf &= techStatus == cTechStatusActive;

   // Get the upgrade if we have atleast 30 Villagers, still a low priority upgrade.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechDEBigTribalMarketplaceCoopHaudenosaunee,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypedeFurTrade, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30)); },
      cUnitTypedeFurTrade, -1, 45)) ||
      (cvMaxAge < cAge3) || 
      (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30));

   // Get the upgrade if we have atleast 3 War ships, lower priority upgrade just because it's naval.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigDockRawhideCovers,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeDock, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypeAbstractWarShip, cUnitStateABQ) >= 3)); },
      cUnitTypeDock, -1, 45)) ||
      (cvMaxAge < cAge3) ||
      (gNavyMap == false));

   // Get this upgrade later in the game since it's not that good.
   canDisableSelf &= ((researchSimpleTechByCondition(cTechBigSiegeshopSiegeDrill,
      []() -> bool { return ((kbUnitCount(cMyID, cUnitTypeArtilleryDepot, cUnitStateABQ) >= 1) &&
      (kbUnitCount(cMyID, cUnitTypexpRam, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypexpMantlet, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypexpLightCannon, cUnitStateABQ) >= 8)); },
      cUnitTypeArtilleryDepot)) ||
      (cvMaxAge < cAge4));

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

rule tamboUpgradeMonitor
inactive
minInterval 90
{
   bool canDisableSelf = researchSimpleTechByCondition(cTechdeMightyTambos,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateABQ) >= 2); },
      cUnitTypeTradingPost);
   
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

rule strongholdUpgradeMonitor
inactive
minInterval 75
{
   bool canDisableSelf = researchSimpleTechByCondition(cTechdePukaras,
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypedeIncaStronghold, cUnitStateAlive) +
      kbUnitCount(cMyID, cUnitTypeWarHut, cUnitStateABQ) +
      kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateABQ) >= 3); },
      cUnitTypedeIncaStronghold);

   if (cDifficultyCurrent >= cDifficultyHard)
   {
      canDisableSelf &= researchSimpleTechByCondition(cTechdeSacsayhuaman,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypedeIncaStronghold, cUnitStateAlive) >= 3); },
         cUnitTypedeIncaStronghold);
   }

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// monasteryUpgradeMonitor
//==============================================================================
rule monasteryUpgradeMonitor
inactive
minInterval 60
{
   // If we don't have a Monastery alive we are done here.
   int monasteryID = getUnit(cUnitTypeypMonastery, cMyID);
   if (monasteryID < 0)
   {
      return;
   }

   bool canDisableSelf = true;

   // We don't get the 2 upgrades to increase the strength of the Monk because we have no micro for him.
   if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
   {
      canDisableSelf = researchSimpleTechByCondition(cTechypMonasteryDiscipleAura,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeypMonkDisciple, cUnitStateABQ) >= 8); },
         -1, monasteryID);

      canDisableSelf &= researchSimpleTechByCondition(cTechypMonasteryShaolinWarrior,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeypMonkDisciple, cUnitStateABQ) >= 8); },
         -1, monasteryID);
   }

   // We don't get the Tiger because that is just wasting resources for us.
   // We don't get the healing upgrade because we have no logic to use the Monks as healers and not lose them.
   // We don't get Crushing Force because we don't micro the Monks and will probably lose them.
   else if ((cMyCiv == cCivIndians) || (cMyCiv == cCivSPCIndians))
   {
      canDisableSelf = researchSimpleTechByCondition(cTechypMonasteryIndianSpeed,
         []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateABQ) >= 15); },
         -1, monasteryID);
   }

   // else // We are Japanese.
   //{
   // We don't get anything from the Japanese because all their upgrades are about improving the Monks.
   //}

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// chooseConsulateFlag
// We try to take some cv into account when choosing but it isn't 100% safe.
//==============================================================================
void chooseConsulateFlag(int consulateID = -1)
{
   int consulatePlanID = -1;
   int randomizer = aiRandInt(100); // 0-99.
   int flag_button_id = -1;

   if (gConsulateFlagTechID < 0)
   {
      // Choice biased towards Russians.
      if ((cMyCiv == cCivChinese) || (cMyCiv == cCivSPCChinese))
      {
         if (randomizer < 52) // 52% Probability.
         {
            if (cvOkToBuild == true) 
            {
            flag_button_id = cTechypBigConsulateRussians;
         }
            else // All techs are buildings so makes no sense to chose it when false.
         {
            flag_button_id = cTechypBigConsulateBritish;
         }
         }
         else if (randomizer < 68) // 16% Probability.
         {
            flag_button_id = cTechypBigConsulateBritish;
         }
         else if (randomizer < 84) // 16% Probability.
         {
            flag_button_id = cTechypBigConsulateFrench;
         }
         else // 16% Probability.
         {
            flag_button_id = cTechypBigConsulateGermans;
         }
      }

      // Choice biased towards Portuguese on water maps, towards others on land maps.
      if ((cMyCiv == cCivIndians) || (cMyCiv == cCivSPCIndians))
      {
         if (gHaveWaterSpawnFlag == true) // Water map with a spawn point.
         {
            if (randomizer < 52) // 52 % probability
            {
               flag_button_id = cTechypBigConsulatePortuguese;
            }
            else if (randomizer < 68) // 16 % probability
            {
               flag_button_id = cTechypBigConsulateBritish;
            }
            else if (randomizer < 84) // 16 % probability
            {
               flag_button_id = cTechypBigConsulateFrench;
            }
            else // 16 % probability
            {
               flag_button_id = cTechypBigConsulateOttomans;
               if (cvOkToTrainArmy == true)
               {
               xsEnableRule("consulateLevy");
            }
         }
         }
         else // Land map, ignore Portuguese since all their techs need a spawn flag.
         {
            if (randomizer < 44) // 44% Probability.
            {
               if (cvOkToTrainArmy == true)
               {
                  flag_button_id = cTechypBigConsulateBritish;
            }
               else
            {
                  flag_button_id = cTechypBigConsulateFrench;
               }
            }
            else if (randomizer < 72) // 28% Probability.
            {
               flag_button_id = cTechypBigConsulateFrench;
            }
            else // 28% Probability.
            {
               flag_button_id = cTechypBigConsulateOttomans;
               if (cvOkToTrainArmy == true)
               {
               xsEnableRule("consulateLevy");
            }
         }
      }
      }

      // Choice biased towards Portuguese on water maps, towards Isolation on land maps
      if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapanese))
      {
         if (gHaveWaterSpawnFlag == true) // Water map with a spawn point.
         {
            if (randomizer < 40) // 40% Probability.
            {
               flag_button_id = cTechypBigConsulatePortuguese;
            }
            else if (randomizer < 60) // 20% Probability.
            {
               flag_button_id = cTechypBigConsulateJapanese;
            }
            else if (randomizer < 80) // 20% Probability.
            {
               if (cvOkToBuild == true) // All techs are buildings so makes no sense to chose it when false.
            {
               flag_button_id = cTechypBigConsulateDutch;
            }
               else
            {
                  flag_button_id = cTechypBigConsulateJapanese;
               }
            }
            else // 20% Probability.
            {
               flag_button_id = cTechypBigConsulateSpanish;
            }
         }
         else // Land map, ignore Portuguese since all their techs need a spawn flag.
         {
            if (randomizer < 68) // 68% Probability.
            {
               flag_button_id = cTechypBigConsulateJapanese;
            }
            else if (randomizer < 84) // 16% Probability.
         {
               if (cvOkToBuild == true) // All techs are buildings so makes no sense to chose it when false.
            {
                  flag_button_id = cTechypBigConsulateDutch;
            }
               else
            {
               flag_button_id = cTechypBigConsulateJapanese;
            }
            }
            else // 16% Probability.
            {
               flag_button_id = cTechypBigConsulateSpanish;
            }
         }
      }

      gConsulateFlagTechID = flag_button_id;
   }

   if (kbTechGetStatus(gConsulateFlagTechID) == cTechStatusObtainable)
   {
      consulatePlanID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, gConsulateFlagTechID);
      if (consulatePlanID < 0)
      {
         debugTechs("Consulate Flag");
         debugTechs("Our Consulate flag is: " + kbGetTechName(gConsulateFlagTechID));
         consulatePlanID = createSimpleResearchPlanSpecificBuilding(gConsulateFlagTechID, consulateID, cEconomyEscrowID, 40);
         aiPlanSetEventHandler(consulatePlanID, cPlanEventStateChange, "consulateFlagHandler");
      }
   }
}

void consulateFlagHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      // Done.
      if (kbTechGetStatus(gConsulateFlagTechID) == cTechStatusActive)
      {
         gConsulateFlagChosen = true;
      }
   }
}

void russianFortHandler(int planID = -1)
{
   if (aiPlanGetState(planID) == -1)
   {
      // Done.
      if (kbTechGetStatus(cTechypConsulateRussianFortWagon) == cTechStatusActive)
      {
         forwardBaseManager(); // Handle the Fort Wagon.
      }
   }
}

//==============================================================================
/* consulateMonitor
   TODO:
   General rule: get all technologies before we move on to the next ally, ignore brigades.

   China:
   - Start with Germans
   - Russian
   - French
   - End game on British, ignore Surgeons and Spies can get the brigade.

   India:
   - Start with Ottomans, only get 4 Settlers
   - Only Portuguese on water maps, get the Ironclad
   - French
   - Back to Ottoman for the Bombard
   - End game on British, ignore Surgeons and Spies can get the brigade.
   
   Japanese:
   - Start with Portuguese on a water map, don't get the Ironclad
   - Spanish
   - Dutch don't get livestock pen
   - If water map go back to Portuguese and get the Ironclad
   - End game on Japanese isolation, ignore Meji Restoration.
*/
//==============================================================================
rule consulateMonitor
inactive
minInterval 45
{
   int consulateID = getUnit(cUnitTypeypConsulate, cMyID, cUnitStateAlive);
   if (consulateID < 0)
   {
      return;
   }
   // If no option has been chosen already, choose one now
   if (gConsulateFlagChosen == false)
   {
      chooseConsulateFlag(consulateID);
      return;
   }

   static bool allTechsActive = false;

   if (allTechsActive == false)
   {
      switch (gConsulateFlagTechID)
      {
      case cTechypBigConsulateBritish:
      {
            if (cvOkToTrainArmy == true)
            {  // 5 Petards.
               allTechsActive = researchSimpleTech(cTechypConsulateBritishLifeGuards, -1, consulateID);
            }
            else
            {
         allTechsActive = true;
            }
         break;
      }
         case cTechypBigConsulateDutch: // We can only get this when we're allowed to build.
      {
            allTechsActive = researchSimpleTech(cTechypConsulateDutchSaloonWagon, -1, consulateID); // Bank Wagon.

         if (researchSimpleTech(cTechypConsulateDutchArsenalWagon, -1, consulateID) == true)
         {
            xsEnableRule("arsenalUpgradeMonitor");
         }
         else
         {
            allTechsActive = false;
         }

         if (researchSimpleTech(cTechypConsulateDutchChurchWagon, -1, consulateID) == true)
         {
            xsEnableRule("churchUpgradeMonitor");
         }
         else
         {
            allTechsActive = false;
         }
         break;
      }
      case cTechypBigConsulateFrench:
      {
            allTechsActive = researchSimpleTech(cTechypConsulateFrenchWoodCrates, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateFrenchCoinCrates, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateFrenchFoodCrates, -1, consulateID);
         break;
      }
      case cTechypBigConsulateGermans:
      {
            allTechsActive = researchSimpleTech(cTechypConsulateGermansCoinTrickle, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateGermansWoodTrickle, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateGermansFoodTrickle, -1, consulateID);
         break;
      }
      case cTechypBigConsulateJapanese:
      {
         allTechsActive = researchSimpleTech(cTechypConsulateJapaneseMasterTraining, -1, consulateID);
            if (cvOkToBuild == true)
            {
               allTechsActive &= researchSimpleTech(cTechypConsulateJapaneseMilitaryRickshaw, -1, consulateID);
      }
         break;
      }
      case cTechypBigConsulatePortuguese:
      {
            if ((gTimeToFish == true) && (researchSimpleTech(cTechypConsulatePortugueseFishingFleet, -1, consulateID) == true))
         {
               allTechsActive = true;
         }
            if (cvOkToTrainNavy == true)
         {
               // Caravel.
               allTechsActive &= researchSimpleTech(cTechypConsulatePortugueseExplorationFleet, -1, consulateID);
               // Ironclad.
               allTechsActive &= researchSimpleTech(cTechypConsulatePortugueseExpeditionaryFleet, -1, consulateID);
         }
         break;
      }
      case cTechypBigConsulateOttomans:
      {
            // 4 Settlers.
            allTechsActive = researchSimpleTech(cTechypConsulateOttomansInfantrySpeed, -1, consulateID);
            if (cvOkToTrainArmy == true)
            {
               // Great Bombards.
               allTechsActive &= researchSimpleTech(cTechypConsulateOttomansGunpowderSiege, -1, consulateID);
            }
         break;
      }
         case cTechypBigConsulateRussians: // We can only get this when we're allowed to build.
      {
            allTechsActive = researchSimpleTech(cTechypConsulateRussianFactoryWagon, -1, consulateID); 
            if (cvOkToFortify == true)
            {  // Blockhouse Wagon.
         allTechsActive &= researchSimpleTech(cTechypConsulateRussianOutpostWagon, -1, consulateID);
            }
            if (cvOkToBuildForts == true)
         {
            allTechsActive &= researchSimpleTechByConditionEventHandler(cTechypConsulateRussianFortWagon,
               []() -> bool { return (true); }, "russianFortHandler", -1, consulateID, 50);
         }
         break;
      }
      case cTechypBigConsulateSpanish:
      {
            allTechsActive = researchSimpleTech(cTechypConsulateSpanishFasterShipments, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateSpanishEnhancedProfits, -1, consulateID);
            allTechsActive &= researchSimpleTech(cTechypConsulateSpanishMercantilism, -1, consulateID);
         break;
      }
      }
   }

   if (cvOkToTrainArmy == false)
   {
      return;
   }

   // Maintain plans.
   static int consulateUPID = -1;
   static int consulateMaintainPlans = -1;

   if (consulateUPID < 0)
   {
      // Create it.
      consulateUPID = kbUnitPickCreate("Consulate army");
      if (consulateUPID < 0)
      {
         return;
      }
      consulateMaintainPlans = xsArrayCreateInt(4, -1, "Consulate maintain plans");
   }

   int numberResults = 0;
   int trainUnitID = -1;
   int planID = -1;
   int numberToMaintain = 0;
   int mainBaseID = kbBaseGetMainID(cMyID);

   // Default init.
   kbUnitPickResetAll(consulateUPID);
   // Desired number units types, buildings.
   kbUnitPickSetDesiredNumberUnitTypes(consulateUPID, 2, 1, true);

   setUnitPickerCommon(consulateUPID);

   kbUnitPickSetMinimumCounterModePop(consulateUPID, 15);
   kbUnitPickSetPreferenceFactor(consulateUPID, cUnitTypeAbstractConsulateSiegeFortress, 1.0);
   kbUnitPickSetPreferenceFactor(consulateUPID, cUnitTypeAbstractConsulateSiegeIndustrial, 1.0);
   kbUnitPickSetPreferenceFactor(consulateUPID, cUnitTypeAbstractConsulateUnit, 1.0);
   kbUnitPickSetPreferenceFactor(consulateUPID, cUnitTypeAbstractConsulateUnitColonial, 1.0);
   // Banner armies are calculated with a weighed average of unit types the banner army contains.
   kbUnitPickRemovePreferenceFactor(consulateUPID, cUnitTypeAbstractBannerArmy);
   kbUnitPickRun(consulateUPID);

   for (i = 0; < 2)
   {
      trainUnitID = kbUnitPickGetResult(consulateUPID, i);
      planID = xsArrayGetInt(consulateMaintainPlans, i);
      if (planID >= 0)
      {
         if (trainUnitID == aiPlanGetVariableInt(planID, cTrainPlanUnitType, 0))
         {
            numberToMaintain = kbResourceGet(cResourceTrade) / kbUnitCostPerResource(trainUnitID, cResourceTrade);
            aiPlanSetVariableInt(planID, cTrainPlanNumberToMaintain, 0, numberToMaintain);
            continue;
         }
         aiPlanDestroy(planID);
      }
      if (trainUnitID < 0)
      {
         continue;
      }
      numberToMaintain = kbResourceGet(cResourceTrade) / kbUnitCostPerResource(trainUnitID, cResourceTrade);
      planID = createSimpleMaintainPlan(trainUnitID, numberToMaintain, false, mainBaseID, 1);
      aiPlanSetDesiredResourcePriority(planID, 45 - i); // Below research plans.
      xsArraySetInt(consulateMaintainPlans, i, planID);
   }
}

//==============================================================================
// agraFortUpgradeMonitor
//==============================================================================
rule agraFortUpgradeMonitor
inactive
minInterval 90
{
   // Check for the Agra Fort, if we don't find one we've lost it and we can disable this Rule.
   int agraFortID = getUnit(gAgraFortPUID);
   if (agraFortID < 0)
   {
      xsDisableSelf();
      return;
   }

   bool canDisableSelf = researchSimpleTech(cTechypFrontierAgra, -1, agraFortID);
   
   if (cDifficultyCurrent >= cDifficultyModerate)
   {
      canDisableSelf &= researchSimpleTech(cTechypFortifiedAgra, -1, agraFortID);
   }
   
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

//==============================================================================
// shrineUpgradeMonitor
//==============================================================================
rule shrineUpgradeMonitor
inactive
minInterval 60
{
   // Disable Rule once the upgrade is active.
   if (kbTechGetStatus(cTechypShrineFortressUpgrade) == cTechStatusActive)
   {
      xsDisableSelf();
      return;
   }
   int treshold = 15;
   int toshoguShrineID = getUnit(gToshoguShrinePUID);
   // Check for the Toshogu Shrine, this building boosts our Shrines so can have a lower treshold.
   if (toshoguShrineID >= 0)
   {
      treshold = 10;
   }
   
   int shrineCount = kbUnitCount(cMyID, cUnitTypeypShrineJapanese, cUnitStateABQ);

   int planID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, cTechypShrineFortressUpgrade);
   if (planID >= 0)
   {
      if (shrineCount < treshold)
      {
         aiPlanDestroy(planID);
      }
   }
   else
   {
      if (shrineCount >= treshold)
      {
         researchSimpleTech(cTechypShrineFortressUpgrade, cUnitTypeypShrineJapanese);
      }
   }
}

//==============================================================================
// allianceUpgradeMonitor
// Researches upgrades gained via alliances for the African civilizations.
// Also researches 2 upgrades which are baseline inside the University / Mountain Monastery.
//==============================================================================
rule allianceUpgradeMonitor
inactive
minInterval 45
{
   int age = kbGetAge();
   // If all the values in the bool array are set to true it means we can disable this rule, but first make sure we actually
   // can't research any more Alliances.
   if (age == cvMaxAge)
   {
      bool canDisableSelf = true;
      for (i = cAge1; < cvMaxAge + 1)
      {
         if (xsArrayGetBool(gAfricanAlliancesUpgrades, i) == false)
         {
            canDisableSelf = false;
         }
      }
      if ((cMyCiv == cCivDEEthiopians) &&
          ((kbTechGetStatus(cTechDESolomonicDynasty) != cTechStatusActive) && (cvMaxAge >= cAge4)))
      {
         canDisableSelf = false;
      }
      if (canDisableSelf == true)
      {
         xsDisableSelf();
      }
   }
   
   bool bothTechsActive = false;
   if (cMyCiv == cCivDEHausa)
   {
      // Quit if we have no University.
      int universityID = getUnit(cUnitTypedeUniversity, cMyID);
      if (universityID < 0)
      {
         return;
      }
      
      if (age != cvMaxAge)
      {
         // Give the AI some space to get it in time.
         researchSimpleTechByCondition(cTechDETimbuktuManuscripts,
            []() -> bool { return (kbGetTechPercentComplete(gAgeUpResearchPlan) < 5); },
            -1, universityID, 99);
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceBerbersIndex) == false)
      {
         if ((researchSimpleTechByCondition(cTechDENatBerberDesertKings,
            []() -> bool { return (kbUnitCount(cMyID, gEconUnit, cUnitStateABQ) >= 30); },
            -1, universityID) || 
            (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30)) == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceBerbersIndex, true);
         }
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceHausaIndex) == false)
      {
         bothTechsActive = researchSimpleTech(cTechDEAllegianceHausaKanoChronicle, -1, universityID);
         
         bothTechsActive &= researchSimpleTech(cTechDEAllegianceHausaArewa, -1, universityID);

         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceHausaIndex, true);
         }
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceSonghaiIndex) == false)
      {
         bothTechsActive = researchSimpleTech(cTechDEAllegianceSonghaiTimbuktuChronicle, -1, universityID);
         
         bothTechsActive &= researchSimpleTechByCondition(cTechDEAllegianceSonghaiMansaMusaEpic,
            []() -> bool { return (kbTechGetHCCardValuePerResource(cTechDEAllegianceSonghaiMansaMusaEpic, cResourceGold)
            >= 1000); }, -1, universityID);
            
         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceHausaIndex, true);
         }
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceAkanIndex) == false)
      {
         if (researchSimpleTech(cTechDENatAkanGoldEconomy, -1, universityID) == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceAkanIndex, true);
         }
      }
   }
   else // Ethiopia.
   {
      int mountainMonasteryID = getUnit(cUnitTypedeMountainMonastery, cMyID);
      if (mountainMonasteryID < 0)
      {
         return;
      }
      
      if (age != cvMaxAge)
      {
         // Give the AI some space to get it in time.
         researchSimpleTechByCondition(cTechDEAxumChronicle,
            []() -> bool { return (kbGetTechPercentComplete(gAgeUpResearchPlan) < 5); },
            -1, mountainMonasteryID, 99);
      }
      
      researchSimpleTech(cTechDESolomonicDynasty, -1, mountainMonasteryID);

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceSomalisIndex) == false)
      {
         bothTechsActive = researchSimpleTechByCondition(cTechDENatSomaliCoinage,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateABQ) >= 30); },
            -1, mountainMonasteryID) ||
            (xsArrayGetInt(gTargetSettlerCounts, cvMaxAge) < 30) || (gTimeForPlantations == true);
         
         if (gHaveWaterSpawnFlag == true)
         {
            bothTechsActive &= researchSimpleTech(cTechDENatSomaliBerberaSeaport, -1, mountainMonasteryID);
         }
          
         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceSomalisIndex, true);
         }  
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAlliancePortugueseIndex) == false)
      {
         bothTechsActive = researchSimpleTech(cTechDEAllegiancePortugueseCrusaders, -1, mountainMonasteryID);
         
         bothTechsActive &= researchSimpleTechByCondition(cTechDEAllegiancePortugueseOrgans,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypedeMountainMonastery, cUnitStateAlive) >= 3); },
            -1, mountainMonasteryID);
         
         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAlliancePortugueseIndex, true);
         }  
      }
      
      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceSudaneseIndex) == false)
      {
         bothTechsActive = researchSimpleTech(cTechDENatSudaneseRedSeaTrade, -1, mountainMonasteryID);
         
         bothTechsActive &= researchSimpleTechByCondition(cTechDENatSudaneseQuiltedArmor,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractCavalry, cUnitStateAlive) +
            kbUnitCount(cMyID, cUnitTypeAbstractLightInfantry, cUnitStateAlive) >= 12); },
            -1, mountainMonasteryID);
         
         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceSudaneseIndex, true);
         } 
      }
      
      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceJesuitIndex) == false)
      {
         bothTechsActive = researchSimpleTech(cTechYPNatJesuitSchools, -1, mountainMonasteryID);
         
         bothTechsActive &= researchSimpleTechByCondition(cTechYPNatJesuitSmokelessPowder,
            []() -> bool { return (kbUnitCount(cMyID, cUnitTypeAbstractGunpowderTrooper, cUnitStateAlive) +
            kbUnitCount(cMyID, cUnitTypeAbstractArtillery, cUnitStateAlive) >= 15); },
            -1, mountainMonasteryID);
         
         if (bothTechsActive == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceJesuitIndex, true);
         }  
      }

      if (xsArrayGetBool(gAfricanAlliancesUpgrades, cAllianceOromoIndex) == false)
      {
         if (researchSimpleTech(cTechDEAllegianceOromoUnits, -1, mountainMonasteryID) == true)
         {
            xsArraySetBool(gAfricanAlliancesUpgrades, cAllianceOromoIndex, true);
         }  
      }
   }
}

rule cityTowerUpgradeMonitor
inactive
minInterval 60
{
   bool canDisableSelf = researchSimpleTechByCondition(
      cTechDESPCCannonTowers, 
      // Research once we have towers on every socket we owned.
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypedeSPCCityTower, cUnitStateABQ) >= kbUnitCount(cMyID, cUnitTypedeSPCSocketCityTower, cUnitStateAny)); },
      cUnitTypedeSPCCityTower);

   canDisableSelf &= researchSimpleTechByCondition(cTechDESPCTraceItalienne,
      // Research once we have towers on every socket we owned.
      []() -> bool { return (kbUnitCount(cMyID, cUnitTypedeSPCCityTower, cUnitStateABQ) >= kbUnitCount(cMyID, cUnitTypedeSPCSocketCityTower, cUnitStateAny)); },
      cUnitTypedeSPCCityTower);

   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

/*

rule fortUpgradeMonitor
inactive
minInterval 90
{
   // Quit if there is no alive Fort.
   if (kbUnitCount(cMyID, cUnitTypeFortFrontier, cUnitStateAlive) < 1)
   {
      return;
   }
   
   bool canDisableSelf = researchSimpleTech(cTechRevetment, cUnitTypeFortFrontier);
   
   canDisableSelf &= researchSimpleTech(cTechStarFort, cUnitTypeFortFrontier);
   
   if (canDisableSelf == true)
   {
      xsDisableSelf();
   }
}

rule dojoUpgradeMonitor
inactive
minInterval 60
{
   int upgradePlanID = -1;

   // Disable rule once the upgrade is available
   if (kbTechGetStatus(cTechypDojoUpgrade1) == cTechStatusActive)
   {
      xsDisableSelf();
      return;
   }

   // Quit if there is no dojo
   if (kbUnitCount(cMyID, cUnitTypeypDojo, cUnitStateAlive) < 1)
   {
      return;
   }

   // Get upgrade
   if (kbTechGetStatus(cTechypDojoUpgrade1) == cTechStatusObtainable)
   {
      if (aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, cTechypDojoUpgrade1) >= 0)
         return;
      createSimpleResearchPlan(cTechypDojoUpgrade1, cUnitTypeypDojo, cMilitaryEscrowID, 50);
      return;
   }
}

*/