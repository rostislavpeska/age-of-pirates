//==============================================================================
/* aiHCCards.xs

   This file manages home city deck building, and choosing the card to send
   when shipment arrives.
*/
//==============================================================================

float getUnitCardNetValue(int deck = -1, int index = -1, int tech = -1)
{
   return (aiHCDeckGetCardValuePerResource(deck, index, cResourceWood) + 
           aiHCDeckGetCardValuePerResource(deck, index, cResourceFood) +
           aiHCDeckGetCardValuePerResource(deck, index, cResourceGold) +
           aiHCDeckGetCardValuePerResource(deck, index, cResourceInfluence) -
           kbTechCostPerResource(tech, cResourceWood) -
           kbTechCostPerResource(tech, cResourceFood) -
           kbTechCostPerResource(tech, cResourceGold) -
           kbTechCostPerResource(tech, cResourceInfluence));
}

int findBestHCGatherUnit(int baseID = -1)
{
   vector loc = kbBaseGetLocation(cMyID, baseID);
   float dist = kbBaseGetDistance(cMyID, baseID);
   int unitID = getUnitByLocation(cUnitTypeAbstractTownCenter, cMyID, cUnitStateAlive, loc, dist);
   if (unitID < 0)
   {
      unitID = getUnitByLocation(cUnitTypeHCGatherPointPri1, cMyID, cUnitStateAlive, loc, dist);
   }
   if (unitID < 0)
   {
      unitID = getUnitByLocation(cUnitTypeHCGatherPointPri2, cMyID, cUnitStateAlive, loc, dist);
   }
   if (unitID < 0)
   {
      unitID = getUnitByLocation(cUnitTypeHCGatherPointPri3, cMyID, cUnitStateAlive, loc, dist);
   }
   return (unitID);
}

bool addCardToDeck(int deckIndex = -1, int cardIndex = -1)
{
   if (aiHCDeckAddCardToDeck(deckIndex, cardIndex) == true)
   {
      debugHCCards("Adding card to deck: " + kbGetTechName(aiHCCardsGetCardTechID(cardIndex)));
      return (true);
   }
   debugHCCards("WARNING failed adding card to deck: " + kbGetTechName(aiHCCardsGetCardTechID(cardIndex)));
   return (false);
}

//==============================================================================
// buyCards
// We create deck for the AI to use here.
//==============================================================================
rule buyCards
inactive
highFrequency // Run every frame until it's disabled.
{
   static int pass = 0; // Pass 0: init arrays. Pass 2+: create deck.

   static int cardStates = -1;          // Array used for storing the "state" of a card.
   const int cCardStateUnavailable = 0; // Never evaluate these.
   const int cCardStateAvailable = 1;   // Give these a priority, only useful for crates + upgrades.
   const int cCardStateInDeck = 2;      // Skip these when building a deck since they're already in the deck.
   static int cardPriorities = -1;      // Array used for storing priorities to determine which crate/upgrade cards to put into the deck.
   static int premadeDeckTechIDs = -1;  // Array used for storing tech IDs from a premade deck.
   static int unitCardValue = -1;       // Array used for storing the value of unit shipment cards.
   static int unitCardCost = -1;        // Array used for storing the cost of unit shipment cards.
   static int unitCardShippedUnit = -1; // Array used for storing the shipped unit the unit shipment cards.
   static int cardFlags = -1;           // Array used for storing the flags of each card.
   int totalCardCount = aiHCCardsGetTotal();
   static int numCardsProcessed = 0;
   static int numCardsPremadeDeck = 0;
   int startingResources = aiGetGameStartingResources();
   float totalValueCurrent = 0.0;
   float totalCostCurrent = 0.0;
   
   switch (pass)
   {
      case 0: // Init arrays, here we assign a priority to each card (only useful for crates/upgrades).
              // We later build a deck based on these priorities.
      {
         if (numCardsProcessed == 0) // First run.
         {
            int premadeDeckID = -1;
            int premadeCardTechID = -1;

            cardStates = xsArrayCreateInt(totalCardCount, 0, "Card states");
            cardPriorities = xsArrayCreateInt(totalCardCount, 0, "Card priorities");
            unitCardValue = xsArrayCreateInt(totalCardCount, -9999, "Unit card values");
            unitCardCost = xsArrayCreateInt(totalCardCount, -9999, "Unit card costs");
            unitCardShippedUnit = xsArrayCreateInt(totalCardCount, -1, "Unit shipped by card");
            cardFlags = xsArrayCreateInt(totalCardCount, 0, "Card flags");
            
            // Let's see if we have a premade deck.
            int numPremadeDecks = aiHCPreMadeDeckGetNumber();
            if (numPremadeDecks >= 1)
            {
               if (gHaveWaterSpawnFlag == true)
               {
                  premadeDeckID = aiHCPreMadeDeckGetIndex("Naval");
               }
               else 
               {
                  premadeDeckID = aiHCPreMadeDeckGetIndex("Land");
               }
               // If we found a premade deck we fill the array with the IDs of the cards.
               // Later on we give extra priority to cards that are also in the premade decks to bump cards that are presumably good.
               if (premadeDeckID >= 0)
               {
                  debugHCCards("We've found a premade deck to take into account");
                  numCardsPremadeDeck = aiHCPreMadeDeckGetNumberCards(premadeDeckID);
                  premadeDeckTechIDs = xsArrayCreateInt(numCardsPremadeDeck, -1, "Premade deck tech IDs");
                  for (premadeCardID = 0; < numCardsPremadeDeck)
                  {
                     premadeCardTechID = aiHCPreMadeDeckGetCardTechID(premadeDeckID, premadeCardID);
                     xsArraySetInt(premadeDeckTechIDs, premadeCardID, premadeCardTechID);
                  }
               }
            }
         }
         
         int startingCardIndex = numCardsProcessed; // We do several passes so fetch where we left off last time.
         int tech = -1; // The techtreey.xml tech the card belongs to.
         int cardAgePreReq = -1;
         int cardPriority = 0;
         int currentCardFlags = 0;
         int unit = -1;
         bool exclude = false;  // If this is true the card will be set to state unavailable.
         int cardSendCount = 0; // -1 Is infinite uses, above 0 indicates how many time it can be sent.
         int crateResourceValue = 0;
         int numNatives = getGaiaUnitCount(cUnitTypeNativeSocket);
         for (i = startingCardIndex; < totalCardCount) // Loop through each card.
         {
            tech = aiHCCardsGetCardTechID(i);
            
            // Let's see if the card we've found can actually be obtained by us.
            if (aiHCCardsIsCardBought(i) == true) // This checks if this card is enabled for us.
            {
               xsArraySetInt(cardStates, i, cCardStateAvailable);
            }
            else
            {
               // This will fire for all revolution cards that must be defined inside of the main HC and thus we pick them up here.
               // It will also pick up on cards that are defined in the HC but not actually enabled (bugged data basically).
               debugHCCards("This card is defined but can't be selected for our deck: " + kbGetTechName(tech));
               xsArraySetInt(cardStates, i, cCardStateUnavailable); // We will ignore this card from now on.
               numCardsProcessed++;
               continue;
            }
            
            unit = aiHCCardsGetCardUnitType(i); // WARNING, this only picks up the first unit listed inside the techtreey.xml tech,
                                                // so shipments with 2+ units aren't handled properly by this since we only fetch the first one.
            if ((unit == cUnitTypedeCrateSpanishGold) || (unit == cUnitTypeypSettlerIndian))
            {
               unit = -1;
            }
            currentCardFlags = aiHCCardsGetCardFlags(i);
            cardAgePreReq = aiHCCardsGetCardAgePrereq(i);
            cardSendCount = aiHCCardsGetCardCount(i);
            
            //=============
            // There are a lot of cards we just don't want to send (or can't for some reason), exclude them here.
            //=============


            switch (cMyCiv)
            {               
               case cCivBritish:
               {
                  exclude = ((tech == cTechHCXPFlorenceNightingale) || (tech == cTechHCStockyards) ||
                     (tech == cTechHCFullingMills) || (tech == cTechHCXPSouthSeaBubble) ||
                     (tech == cTechHCExplorerBritish) || (tech == cTechDEHCTheaters) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechHCRoyalDecreeBritish) ||
                     (tech == cTechHCXPAgents) || (tech == cTechHCAdmirality) ||
                     (tech == cTechHCHouseEstates) || (tech == cTechHCShipSettlers2) ||
                     (tech == cTechHCXPImprovedGrenades) || (tech == cTechHCNativeWarriors) ||
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechHCXPRanching) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivDutch:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCExplorerDutch) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPMilitaryReforms) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechHCAdmirality) ||
                     (tech == cTechHCRoyalDecreeDutch) || (tech == cTechHCXPAgents) ||
                     (tech == cTechDEHCFlemishRevolution) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechDEHCExtensiveFortificationsEuropean) ||
                     (tech == cTechHCHeavyFortifications) || (tech == cTechHCFrontierDefenses2) ||
                     (tech == cTechHCAdvancedPlantations) || (tech == cTechHCShipCulverins1) || 
					 (tech == cTechDEHCMercenaryArmyDutch) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivFrench:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCNorthwestPassage) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCXPFurTrade) || (tech == cTechHCExplorerFrench) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechHCRoyalDecreeFrench) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCAdmirality) ||
                     (tech == cTechHCXPTirailleurs) || (tech == cTechHCXPAssassins) ||
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechDEHCShipBalloonsFrench) || (tech == cTechHCShipPikemen3) ||
                     (tech == cTechHCShipCrossbowmen3) || (tech == cTechHCNativeWarriors) ||
                     (tech == cTechHCNativeCombat) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivGermans:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCExplorerGerman) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCStockyards) || (tech == cTechHCNativeTreatiesGerman) ||
                     (tech == cTechHCRoyalDecreeGerman) || (tech == cTechHCXPAgents) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCAdmiralityGerman) ||
                     (tech == cTechHCCigarRollerGerman) || (tech == cTechHCNativeWarriorsGerman) ||
                     (tech == cTechHCShipFoodCrates2German) || (tech == cTechHCShipWoodCrates2German) ||
                     (tech == cTechHCShipCoinCrates2German) || (tech == cTechHCShipSettlerWagons2) ||
                     (tech == cTechHCSpiceTradeGerman) || (tech == cTechHCTextileMillsGerman) ||
                     (tech == cTechHCXPBloodBrothersGerman) || (tech == cTechHCFencingSchoolGerman) ||
                     (tech == cTechHCCheapStablesTeam) || (tech == cTechHCRidingSchoolGerman) ||
                     (tech == cTechHCRidingSchoolGerman2) || (tech == cTechHCShipCrossbowmen5German) ||
                     (tech == cTechHCShipCrossbowmen4German) || (tech == cTechHCImprovedBuildingsGerman) ||
                     (tech == cTechHCXPBloodBrothersGerman) || (tech == cTechHCSustainableAgricultureGerman) || 
                     (tech == cTechHCHandInfantryDamageGerman) || (tech == cTechHCMedicineGerman) ||
                     (tech == cTechDEHCHandMortarGerman) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivOttomans:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCExplorerOttoman) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCXPSublimePorte) || (tech == cTechHCStockyards) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechHCBattlefieldConstruction) ||
                     (tech == cTechHCAdmirality) || (tech == cTechDEHCTheaters) ||
                     (tech == cTechHCSpiceTrade) || (tech == cTechHCSilversmith) ||
                     (tech == cTechHCXPAssassins) ||
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechHCFrontierDefenses2) ||
                     (tech == cTechHCBastionsTeam) || (tech == cTechHCMercenaryLoyalty) ||
                     (tech == cTechDEHCFencingSchoolOttoman) || (tech == cTechHCTeamCoinCrates1));
                  break;
               }
               case cCivPortuguese:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCExplorerPortuguese) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanchingLlama) ||
                     (tech == cTechHCRidingSchool) || (tech == cTechHCFencingSchool) ||
                     (tech == cTechHCSustainableAgriculture) ||
                     (tech == cTechHCMedicine) || (tech == cTechHCArtilleryHitpointsPortugueseTeam) ||
                     (tech == cTechHCShipPikemen2) ||  (tech == cTechHCShipPikemen3) ||
                     (tech == cTechHCShipBandeirantes) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechHCImprovedWallsTeam) || (tech == cTechHCRoyalDecreePortuguese) ||
                     (tech == cTechHCXPAgents) || (tech == cTechHCAdmirality) ||
                     (tech == cTechHCEngineeringSchool) || (tech == cTechHCTextileMills) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCDonatarios) ||
                     (tech == cTechHCSpawnFishingBoats) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechHCAdvancedArtillery) || (tech == cTechHCCigarRoller) || 
                     (tech == cTechHCCigarRoller) || (tech == cTechHCXPShipHorseArtillery2) ||
                     (tech == cTechDEHCNavalInfantry) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivRussians:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechHCExplorerRussian) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCStockyards) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechHCRoyalDecreeRussian) || (tech == cTechHCXPSuvorovReforms) ||
                     (tech == cTechHCXPAssassins) || (tech == cTechHCAdmirality) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCBlockhouseCannon) ||
                     (tech == cTechHCShipSettlers2) || (tech == cTechHCFrontierDefenses2) ||
                     (tech == cTechHCFencingSchool) ||(tech == cTechHCEngineeringSchool) || 
					 (tech == cTechHCDuelingSchoolTeam) || (tech == cTechHCRidingSchool) || 
					 (tech == cTechHCUnicorne) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivSpanish:
               {
                  exclude = ((tech == cTechHCExplorerSpanish) || (tech == cTechHCExplorerCombatTeam) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanchingLlama) ||
                     (tech == cTechHCStockyards) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechHCXPUnction) || (tech == cTechHCXPTercioTactics) ||
                     (tech == cTechHCRoyalDecreeSpanish) || (tech == cTechHCAdmirality) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCXPAssassins) ||
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechHCShipSettlers2) ||
                     (tech == cTechHCMercenaryLoyalty) || (tech == cTechHCColonialEstancias));
                  break;
               }
               // The War Chiefs.
               case cCivXPAztec:
               {
                  exclude = ((unit == cUnitTypePetJaguar) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechHCXPWarChiefAztec1) || (tech == cTechHCXPShipJaguars3) ||
                     (tech == cTechHCXPRanching) || (tech == cTechHCXPAdvancedScouts) ||
                     (tech == cTechHCXPSilentStrike) || (tech == cTechHCXPWarChiefAztec2) ||
                     (tech == cTechHCXPKinshipTies) || (tech == cTechHCXPPioneers2) || 
                     (tech == cTechDEHCChichimecaRebellion) ||
                     (tech == cTechHCXPTownDance) || (tech == cTechHCXPWaterDance) ||
                     (tech == cTechHCXPGreatTempleTezcatlipoca) || (tech == cTechHCXPCheapWarHuts) || 
                     (tech == cTechHCXPAgrarianWays) || (tech == cTechYPHCNativeIncorporation) ||
                     (tech == cTechHCGrainMarket) || (tech == cTechHCXPWarHutTraining) ||
                     (tech == cTechHCXPScorchedEarth) || (tech == cTechHCXPRuthlessness) ||
                     (tech == cTechHCXPChinampa1) ||                     
                     (tech == cTechHCXPCoinCratesAztec4) || (tech == cTechDEHCTeamCoinCratesAztec) ||
                     (tech == cTechHCXPExtensiveFortificationsAztec) || (tech == cTechHCHeavyFortifications));
                  break;
               }
               case cCivXPIroquois:
               {
                  exclude = ((tech == cTechDEHCShipNativeScout) || (tech == cTechHCXPWarChiefIroquois1) ||
                     (tech == cTechHCXPTownDance) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCXPOldWaysIroquois) ||
                     (tech == cTechHCStockyards) || (tech == cTechHCFullingMills) ||
                     (tech == cTechHCXPFurTrade) || (tech == cTechHCXPWaterDance) ||
                     (tech == cTechHCXPWarChiefIroquois2) || (tech == cTechHCXPBattlefieldConstructionIroquois) ||
                     (tech == cTechHCXPKinshipTies) || (tech == cTechHCXPPioneers2) ||
                     (tech == cTechHCXPShipVillagers2) || (tech == cTechHCXPExtensiveFortifications2)  ||
                     (tech == cTechDEHCExtensiveFortificationsWarchief) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechHCXPAdvancedScouts));
                  break;
               }
               case cCivXPSioux:
               {
                  exclude = ((tech == cTechHCXPWarChiefSioux1) || (tech == cTechDEHCShipNativeScout) ||
                     (tech == cTechHCXPTownDance) || (tech == cTechHCXPNomadicExpansion) ||
                     (tech == cTechHCXPRanching) || (tech == cTechHCXPEveningStar) ||
                     (tech == cTechHCXPAdvancedScouts) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechHCXPFriendlyTerritory) || (tech == cTechHCXPWarChiefSioux2) ||
                     (tech == cTechHCXPWarChiefSioux3) || (tech == cTechHCXPCommandSkill) ||
                     (tech == cTechHCXPPioneers2) || (tech == cTechHCXPKinshipTies) ||
                     (tech == cTechHCXPTeamFoodCrates1) ||(tech == cTechDEHCCampMovements) ||
                     (tech == cTechDEHCExtensiveFortificationsWarchief) || (tech == cTechHCXPCheyenneAllies2) ||
                     (tech == cTechHCHeavyFortifications) || (tech == cTechHCXPAggressivePolicy));
                  break;
               }
               // The Asian Dynasties.
               case cCivChinese:
               {
                  exclude = ((tech == cTechYPHCShipDisciple1) || (tech == cTechYPHCRanchingWaterBuffalo) ||
                     (tech == cTechYPHCEmpressDowager) || (tech == cTechYPHCChineseMonkMakeDisciple) ||
                     (tech == cTechYPHCVillageShooty) || (tech == cTechHCAdmirality) ||
                     (tech == cTechYPHCShipCastleWagons1) || (tech == cTechYPHCNativeLearning) ||
                     (tech == cTechYPHCAtonementChinese) || (tech == cTechYPHCSpawnLivestock2) ||
                     (tech == cTechYPHCGreatWall) || (tech == cTechYPHCShipShaolinMaster) ||
                     (tech == cTechYPHCWokouChinese1) || (tech == cTechYPHCWokouChinese2) ||
                     (tech == cTechYPHCWokouChinese3) || (tech == cTechYPHCSmoothRelations) ||
                     (tech == cTechYPHCExtensiveFortifications) || (tech == cTechYPHCBannerReforms) ||
                     (tech == cTechYPHCCommoditiesMarket) || (tech == cTechYPHCAdvancedMonastery) ||
                     (tech == cTechYPHCSpawnRefugees2) || (tech == cTechYPHCBannerSchool) ||
                     (tech == cTechYPHCMongolianScourge) || (tech == cTechYPHCVillagemasons) || 
                     (tech == cTechYPHCArtilleryHitpointsChinese) || (tech == cTechYPHCArtilleryDamageChinese) ||  
                     (tech == cTechYPHCConfusciousGift) || (tech == cTechYPHCAccupuncture) ||  
                     (tech == cTechYPHCSpawnMigrants1) || (tech == cTechYPHCArtilleryCombatChinese) ||  
                     (tech == cTechYPHCShipVillageWagon2) || (tech == cTechHCImprovedBuildings) ||
                     (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivIndians:
               {
                  exclude = ((tech == cTechYPHCSacredFieldHealing) || (tech == cTechYPHCShipTigers1) ||
                     (tech == cTechYPHCShipLions1) || (tech == cTechYPHCIndianMonkCombat) ||
                     (tech == cTechYPHCFurTradeIndians) || (tech == cTechYPHCGrazing) ||
                     (tech == cTechYPHCTheRaj) || (tech == cTechYPHCCalltoArms1) ||
                     (tech == cTechYPHCBattlefieldConstruction) || (tech == cTechYPHCArmedFishermenIndians) ||
                     (tech == cTechYPHCAdmiralityIndians) || (tech == cTechYPHCIndianMonkFrighten) ||
                     (tech == cTechYPHCSepoyRebellion) || (tech == cTechYPHCWokouIndians1) ||
                     (tech == cTechYPHCWokouIndians2) || (tech == cTechYPHCWokouIndians3Double) ||
                     (tech == cTechYPHCShipFoodCrates2Indians) || (tech == cTechYPHCSmoothRelationsIndians) ||
                     (tech == cTechYPHCConscriptSepoys) || (tech == cTechYPHCExtensiveFortifications) ||
                     (tech == cTechYPHCBazaar) || (tech == cTechYPHCAdvancedMonasteryIndians) ||
                     (tech == cTechYPHCShipWoodCrates3Indians) || (tech == cTechYPHCShipCoinCrates3Indians) ||
                     (tech == cTechYPHCShipWoodCratesInf2Indians) || (tech == cTechYPHCFencingSchoolIndians) || 
                     (tech == cTechYPHCRidingSchoolIndians) || (tech == cTechYPHCShipGroveWagonIndians2) || 
                     (tech == cTechYPHCMercenaryLoyaltyIndians) || (tech == cTechYPHCExtensiveFortificationsIndians) ||
					 (tech == cTechDEHCExportTradeIndians));
                  break;
               }
               case cCivJapanese:
               {
                  exclude = ((tech == cTechYPHCJapaneseMonkCombat) || (tech == cTechYPHCShipMonitorLizard1) ||
                     (tech == cTechYPHCShrineLearning) || (tech == cTechYPHCZenDiet) ||
                     (tech == cTechYPHCArmedFishermenJapanese) || (tech == cTechHCAdmirality) ||
                     (tech == cTechYPHCJapaneseMonkRangeAura) || (tech == cTechYPHCDojoRenpeikan) ||
                     (tech == cTechYPHCDojoGenbukan) || (tech == cTechYPHCRedSealShip) ||
                     (tech == cTechYPHCWokouJapanese1) || (tech == cTechYPHCWokouJapanese2) ||
                     (tech == cTechYPHCWokouJapanese3) || (tech == cTechYPHCSmoothRelations) ||
                     (tech == cTechYPHCExtensiveFortifications) || (tech == cTechYPHCExpandedMarket) ||
                     (tech == cTechypHCShipFoodCrates2) || (tech == cTechypHCShipFoodCrates4) ||
                     (tech == cTechYPHCAdvancedMonastery) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               // Definitive Edition.
               case cCivDEInca:
               {
                  exclude = ((tech == cTechDEHCChiribayaDogs) || (tech == cTechDEHCShipIncaDogs1) ||
                     (tech == cTechDEHCLlamaLifestyle) || (tech == cTechDEHCWarChiefInca1) ||
                     (tech == cTechDEHCWarChiefInca2) || (tech == cTechDEHCQuipuKamayuks) ||
                     (tech == cTechDEHCAmericanAlliesInca) || (tech == cTechHCXPWaterDance) ||
                     (tech == cTechDEHCIncaWallsTeam) || (tech == cTechDEHCFloatingIslands) ||
                     (tech == cTechDEHCCamayos) || (tech == cTechDEHCArmedFishermenInca) ||
                     (tech == cTechDEHCTempleOfMamaKilla) || (tech == cTechDEHCCloudFortresses) ||
                     (tech == cTechDEHCCloudWarriors) || (tech == cTechHCXPKinshipTies) ||
                     (tech == cTechDEHCTupacRebellion) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechDEHCExtensiveFortificationsInca) || (tech == cTechDEHCHeavyFortificationsInca) ||
                     (tech == cTechDEHCChasquisMessengers) || (tech == cTechDEHCAutarky));
                  break;
               }
               case cCivDESwedish:
               {
                  exclude = ((tech == cTechHCXPMasterSurgeons) || (tech == cTechDEHCExplorerSwedish) ||
                     (tech == cTechHCShipBalloons) || (tech == cTechHCXPRanching) ||
                     (tech == cTechDEHCOxenstiernaReforms) || (tech == cTechDEHCRoyalDecreeSwedish) ||
                     (tech == cTechHCXPAssassins) || (tech == cTechHCAdmirality) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechDEHCHakkapelitMarch) ||
                     (tech == cTechDEHCDalecarlianRebellion) ||
                     (tech == cTechHCUnlockFort) || (tech == cTechHCXPUnlockFort2) || // Exclude these Forts so we always get Kalmar.
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechHCFrontierDefenses2) || (tech == cTechHCMercenaryLoyalty));
                  break;
               }
               case cCivDEAmericans:
               {
                  exclude = ((tech == cTechDEHCImmigrantsFrench) || (tech == cTechDEHCImmigrantsGerman) ||
                     (tech == cTechDEHCAdvancedSaloon) || (tech == cTechHCXPRanching) ||
                     (tech == cTechHCStockyards) || (tech == cTechDEHCGeneralAmericans) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechHCXPAgents) ||
                     (tech == cTechDEHCFedGeneralAssembly) || (tech == cTechHCAdmirality) ||
                     (tech == cTechDEHCImmigrantsBritish) || (tech == cTechDEHCKosciuszkoFortifications) ||
                     (tech == cTechHCXPDanceHall) || (tech == cTechHCHeavyFortificationsUS) ||
                     (tech == cTechHCFrontierDefenses2) || (tech == cTechDEHCPoker) ||
                     (tech == cTechHCSilversmith) || (tech == cTechHCShipMortars2) ||
                     (tech == cTechHCShipMortars1) || (tech == cTechHCAdvancedArtillery) ||
                     (tech == cTechDEHCShipHomesteadWagons1));
                  break;
               }
               case cCivDEHausa:
               {
                  exclude = ((tech == cTechDEHCKilishiJerky) || (tech == cTechDEHCEmirKatsina) ||
                     (tech == cTechDEHCKingslayer) || (tech == cTechDEHCMoroccanLeather) ||
                     (tech == cTechDEHCCharity) || (tech == cTechDEHCDraftOxen) ||
                     (tech == cTechDEHCTsetseSabotage) || (tech == cTechDEHCKatsinaFortifications) ||
                     (tech == cTechDEHCMassinaMadrasahs) || (tech == cTechDEHCGatekeepers) ||
                     (tech == cTechDEHCMaguzawa) || (tech == cTechDEHCHabbanaya) ||
                     (tech == cTechDEHCDodoCult) || (tech == cTechHCNativeTreaties) ||
                     (tech == cTechDEHCShipGriots2) || (tech == cTechDEHCAncientKanoWalls) ||
                     (tech == cTechDEHCBerberNomads) || (tech == cTechDEHCOromoMigrations) ||
                     (tech == cTechDEHCExtensiveFortificationsHausa) || 
                     (tech == cTechDEHCShipVillagers1Repeat) ||(tech == cTechDEHCKororofaConfederacy));
                  break;
               }
               case cCivDEEthiopians:
               {
                  exclude = ((tech == cTechDEHCDejazmach) || (tech == cTechDEHCCoffeeBerries) ||
                     (tech == cTechDEHCBushburning) || (tech == cTechDEHCCharity) ||
                     (tech == cTechDEHCShipAbuns1) || (tech == cTechDEHCShipAbuns2) ||
                     (tech == cTechDEHCDraftOxen) || (tech == cTechDEHCBalambaras) ||
                     (tech == cTechDEHCTigrayMekonnen) || (tech == cTechDEHCLandSea) ||
                     (tech == cTechDEHCEraChaos) || (tech == cTechDEHCEraPrinces) ||
                     (tech == cTechDEHCBeekeepers)|| (tech == cTechDEHCMassLeviesAfrican) ||
                     (tech == cTechDEHCFasterTrainingUnitsAfrican) || 
                     (tech == cTechDEHCExtensiveFortificationsEthiopian) || (tech == cTechHCNativeTreaties));
                  break;
               }
               case cCivDEMexicans:
               {
                  exclude = ((tech == cTechHCShipBalloons) || (tech == cTechDEHCGeneralMexicans) ||
                     (tech == cTechDEHCBanderasMonumentales) || (tech == cTechDEHCRancheros) ||
                     (tech == cTechDEHCIndependenceMovements) || (tech == cTechDEHCChipotles) ||
                     (tech == cTechDEHCAmbuscade) || (tech == cTechDEHCPlanTacubaya) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechDEHCPresidios) ||
                     (tech == cTechDEHCRoyalDecreeMexican) || (tech == cTechDEHCSevenLaws) ||
                     (tech == cTechHCAdmirality) || (tech == cTechDEHCLeatherSoldiers) ||
                     (tech == cTechDEHCPlanCasaMata) || (tech == cTechDEHCPlanTuxtepec) ||
                     (tech == cTechHCXPAssassins) || (tech == cTechDEHCNinosHeroes) ||
                     (tech == cTechDEHCRefurbishedFirearms) || (tech == cTechDEHCManOfDestiny) ||
                     (tech == cTechDEHCPlanVeracruz) || (tech == cTechDEHCPlanAyutla) ||
                     (tech == cTechDEHCPlanMiramare) || (tech == cTechDEHCCharreada) ||
                     (tech == cTechDEHCHidalgoLand) || (tech == cTechDEHCCampecheFortifications) ||
                     (tech == cTechDEHCCantinas) || (tech == cTechDEHCBarbacoa) ||
                     (tech == cTechHCAdvancedArtillery) ||
                     (tech == cTechHCShipSettlers2) || (tech == cTechHCHeavyFortificationsUS) ||
                     (tech == cTechHCFrontierDefenses2) || (tech == cTechHCColonialEstancias));
                  break;
               }
               case cCivDEMaltese:
               {
                  exclude = ((tech == cTechDEHCExplorerMaltese) || (tech == cTechHCShipBalloons) ||
                     (tech == cTechHCXPSublimePorte) || (tech == cTechDEHCAuberges) ||
                     (tech == cTechHCStockyards) || (tech == cTechDEHCChipotles) ||
                     (tech == cTechDEHCAmbuscade) || (tech == cTechDEHCWignacourtConstructions) ||
                     (tech == cTechDEHCTripToJerusalem) || (tech == cTechDEHCDepotWagons) ||
                     (tech == cTechDEHCEarlyFort) || (tech == cTechDEHCPapalDecreeDissolveTemplars) ||
                     (tech == cTechDEHCWallGuns) || (tech == cTechDEHCGreekFire) ||
                     (tech == cTechHCAdmirality) || (tech == cTechDEHCTheaters) ||
                     (tech == cTechHCAdvancedArtillery) || (tech == cTechHCXPAssassins) ||
                     (tech == cTechHCXPAdvancedBalloon) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechDEHCExtensiveFortificationsEuropean) || (tech == cTechDEHCKnightsMalta));
                  break;
               }
               case cCivDEItalians:
               {
                  exclude = ((tech == cTechDEHCExplorerItalian) || (tech == cTechHCShipBalloons) ||
                     (tech == cTechHCXPRanching) || (tech == cTechHCStockyards) ||
                     (tech == cTechHCNativeTreaties) || (tech == cTechDEHCExtensiveFortificationsEuropean) ||
                     (tech == cTechDEHCRoyalDecreeItalians) || (tech == cTechHCAdmirality) ||
                     (tech == cTechDEHCTheaters) || (tech == cTechHCAdvancedArtillery) ||
                     (tech == cTechDEHCVenetianArsenal) || (tech == cTechHCXPAssassins) ||
                     (tech == cTechHCXPAdvancedBalloon) || (tech == cTechHCHeavyFortifications) ||
                     (tech == cTechDEHCPapalArsenal) || (tech == cTechDEHCUsury) ||
                     (tech == cTechDEHCUffizi));
                  break;
               }
               default: // Fallback, just in case we don't have anything specific to exclude.
               {
                  exclude = false;
                  break;
               }
            }
            
            if (exclude == false)
            {
               // We don't want herdables (even African cattle) nor healers (allow Warrior Priests) nor Spies 
               // nor Trading Post Wagons (when not an upgrade) nor Covered Wagons nor Petards, nor Dojos.
               if ((kbProtoUnitIsType(cMyID, unit, cUnitTypeHerdable) == true) ||
                   ((kbProtoUnitIsType(cMyID, unit, cUnitTypeAbstractHealer) == true) &&
                     ((cMyCiv != cCivXPAztec) || (unit != cUnitTypexpMedicineManAztec))) ||
                   (unit == cUnitTypexpSpy) || (unit == cUnitTypeTradingPostTravois) ||
                   (((currentCardFlags & cHCCardFlagUnitUpgrade) == 0) &&
                     ((unit == cUnitTypeypTradingPostWagon) || (unit == cUnitTypedeTradingPostWagon))) ||
                   ((unit == cUnitTypeCoveredWagon) && (((currentCardFlags & cHCCardFlagTeam) == 0))) ||
                   (unit == cUnitTypexpPetard) || (unit == cUnitTypexpPetardNitro) ||
                   (unit == cUnitTypeYPDojoWagon))
               {
                  exclude = true;
               }
            }
            
            if (exclude == false)
            {
               // We can only send these cards (boats) if we have a water spawn flag.
               if ((gHaveWaterSpawnFlag == false) && (unit >= 0) && ((currentCardFlags & cHCCardFlagWater) == cHCCardFlagWater))
               {
                  exclude = true;
               }
            }
            
            if (exclude == false)
            {
               // It makes no sense to send Villagers / resource crates / trickles / Factories / Banks / gathering upgrades
               // when we're starting with such high resources.
               if (((startingResources == cGameStartingResourcesInfinite) || (startingResources == cGameStartingResourcesUltra)) &&
                   (((currentCardFlags & cHCCardFlagVillager) == cHCCardFlagVillager) ||
                   ((currentCardFlags & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) ||
                   ((currentCardFlags & cHCCardFlagTrickleGold) == cHCCardFlagTrickleGold) ||
                   ((currentCardFlags & cHCCardFlagTrickleWood) == cHCCardFlagTrickleWood) ||
                   ((currentCardFlags & cHCCardFlagTrickleFood) == cHCCardFlagTrickleFood) ||
                   ((currentCardFlags & cHCCardFlagGatherRate) == cHCCardFlagGatherRate) ||
                   (kbTechAffectsUnit(tech, cUnitTypeAbstractVillager) == true) ||
                   (unit == cUnitTypeFactoryWagon) ||
                   (unit == cUnitTypeBankWagon)))
               {
                  exclude = true;
               }
            }
            
            if ((cMyCiv != cCivJapanese) && (cMyCiv != cCivXPIroquois) && (exclude == false))
            {
               if (((currentCardFlags & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) &&
                   ((currentCardFlags & cHCCardFlagTeam) == 0) &&
                   // Some resource crate cards are special and deliver fewer resources, don't exclude those.
                   (tech != cTechDEHCPalaceAmina) &&
                   (tech != cTechDEHCFasilidesCastle) &&
                   (tech != cTechDEHCSeasonalLaborTeam) &&
                   (tech != cTechDEHCMexicanMint) &&
                   (tech != cTechHCXPSpanishGold) &&
                   (tech != cTechDEHCUSExpedition) && (tech != cTechDEHCLumberMills))
               {
                  // Don't bother with the weaker (600) Commerce Age resource crate cards. 
                  // This also excludes Exploration crates but we didn't want those anyway.
                  crateResourceValue = aiHCCardsGetCardValuePerResource(i, cResourceWood) +
                                       aiHCCardsGetCardValuePerResource(i, cResourceFood) +
                                       aiHCCardsGetCardValuePerResource(i, cResourceGold) +
                                       aiHCCardsGetCardValuePerResource(i, cResourceInfluence);
                  if (crateResourceValue < 700)
                  {
                     exclude = true;
                  }
               }
            }
            
            if (exclude == false)
            {
               // Don't get any Fort cards when we're not allowed to build those.
               if ((unit == cUnitTypeFortWagon) && (cvOkToBuildForts == false))
               {
                  exclude = true;
               }
            }
            
            if (exclude == false)
            {
               // Infinite cards in age 1 are just very bad to have.
               if ((cardAgePreReq == cAge1) && (cardSendCount < 0) && (tech != cTechDEHCShipVillagersAbunRepeat) &&
                   (tech != cTechDEHCShipVillagers1Repeat)) // Hausa and Ethiopians have age 1 Villager cards on infinite.
               {
                  exclude = true;
               }
            }
            
            if (exclude == true) // Clearly this card is very bad!
            {
               debugHCCards("We're excluding this card from our deck: " + kbGetTechName(tech));
               xsArraySetInt(cardStates, i, cCardStateUnavailable);
               numCardsProcessed++;
               continue;
            }
            
            //=============
            // We actually want this card!
            // We only need to calculate a priority for upgrades and crates, units are prioritized based on value calculations.
            // All upgrades/crates start out on priority 3 and can be increased by either being in the premade decks or through RNG.
            //=============
            
            cardPriority = 0;
            
            // If currentCardFlags == 0 it must be an effect we don't recognize -> assume it's an upgrade.
            // Some upgrades are still not recognized by this, hardcode these.
            if ((((currentCardFlags & cHCCardFlagUnitUpgrade) == cHCCardFlagUnitUpgrade) || (currentCardFlags == 0)) ||
                ((currentCardFlags & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) ||
                 (tech == cTechHCAdvancedArsenalGerman) || (tech == cTechDEHCSpringfieldArmory))
            {
               cardPriority = 3;
            }
            
            // Raise priority of cards inside the premade decks.
            if (premadeDeckID >= 0)
            { 
               for (premadeCardID = 0; < numCardsPremadeDeck)
               {
                  if (xsArrayGetInt(premadeDeckTechIDs, premadeCardID) == tech)
                  {
                     cardPriority++; // +1 Boost for cards inside premade decks.
                  }
               }
            }
            
            // Randomly give a boost between 0 and 3!!!!!!!!!!!!!!!!!!!!!
            cardPriority += aiRandInt(4); 
            
            // Now based on btBiasNative we adjust the prio of some cards. Only bump cards that aren't in the Exploration Age.
            if ((tech == cTechHCXPBloodBrothers) || (tech == cTechHCXPBloodBrothersGerman) ||
                (tech == cTechHCNativeWarriors) || (tech == cTechHCNativeWarriorsGerman) ||
                (tech == cTechHCWildernessWarfare) || (tech == cTechHCNativeCombat) ||
                (tech == cTechYPHCNativeTradeTax) || (tech == cTechYPHCNativeTradeTaxIndians) ||
                (tech == cTechYPHCNativeLearning) || (tech == cTechYPHCNativeLearningIndians) ||
                (tech == cTechYPHCNativeDamage) || (tech == cTechYPHCNativeDamageIndians) ||
                (tech == cTechYPHCNativeHitpoints) || (tech == cTechYPHCNativeHitpointsIndians) ||
                (tech == cTechYPHCNativeIncorporation) || (tech == cTechYPHCNativeIncorporationIndians) ||
                (tech == cTechHCXPBlackArrow) || (tech == cTechHCNativeChampionsDutchTeam) ||
                (tech == cTechYPHCNativeIncorporation) || (tech == cTechYPHCNativeIncorporationIndians) ||
                (tech == cTechDEHCIndianFriendshipMexican) || (tech == cTechDEHCShotgunMessengers) ||
                (tech == cTechDEHCSahelianKingdoms))
            {
               // Raise priority of native related cards when we have a native bias otherwise reduce it.
               if (btBiasNative >= 0.5)
               {
                  cardPriority++;
               }
               else
               {
                  cardPriority--;
               }
               if (numNatives == 0) // Don't ever pick it.
               {
                  cardPriority = 0;
               }
            }
            
            // Now based on btBiasTrade we adjust the prio of some cards. We can bump specific Exploration Age cards here.
            if ((tech == cTechDEHCIndianTradeEthiopia) || (tech == cTechHCAdvancedTradingPost) ||
                (tech == cTechDEHCAdvancedTambos))
            {
               // Raise priority of trade related cards when we have a trade bias otherwise reduce it.
               if (btBiasTrade >= 0.5)
               {
                  cardPriority++;
               }
               else
               {
                  cardPriority--;
               }
               if (gNumberTradeRoutes == 0) // Don't ever pick it.
               {
                  cardPriority = 0;
               }
            }

            // Make sure you pick those cards
            if ((cDifficultyCurrent >= cDifficultyHard) &&
            ((tech == cTechHCMusketeerGrenadierDamageBritish) || (tech == cTechHCCavalryDamageBritish) ||
            (tech == cTechHCHandInfantryHitpointsSpanish) || (tech == cTechYPHCHanAntiCavalryBonus) ||
            (tech == cTechDEHCHeavyInfHitpointsOttoman) || (tech == cTechHCLightArtilleryHitpointsOttoman) ||            
            (tech == cTechHCJanissaryCombatOttoman) || (tech == cTechHCXPGreatHunter) || 
            (tech == cTechHCXPCavalryCombatSioux) || (tech == cTechDEHCAkicita) ||
            (tech == cTechYPHCWesternReforms) || (tech == cTechHCInfantryCombatDutch) ||
            (tech == cTechHCCavalryCombatDutch) || (tech == cTechDEHCChewaWarriors) ||
            (tech == cTechYPHCShipBerryWagon2) || (tech == cTechYPHCForeignLogging) || 
            (tech == cTechYPHCCamelDamageIndians) || (tech == cTechYPHCEastIndiaCompany) ||
            (tech == cTechHCXPKnightCombat) || (tech == cTechHCXPCoyoteCombat) ||
            (tech == cTechDEHCCurare) || (tech == cTechDEHCRoadBuilding) ||            
            (tech == cTechHCXPTempleXolotl) || (tech == cTechHCCavalryCombatFrench) ||
            (tech == cTechDEHCLongRifles) || (tech == cTechDEHCRollingArtillery)))
            
            {
               cardPriority += 100;
            }

            // Raise priority of very important cards.
            if ((cDifficultyCurrent >= cDifficultyModerate) &&
               ((tech == cTechHCXPKnightHitpoints) || (tech == cTechHCXPKnightDamage) ||
               (tech == cTechDEHCFodioTactics) || (tech == cTechDEHCEarlyLifidi) || 
               (tech == cTechDEHCShipDesertWarriors) ||(tech == cTechDEHCShipInfluence2) || 
               (tech == cTechDEHCShipInfluence3) ||  (tech == cTechDEHCHuankaSupport) || 
               (tech == cTechDEHCChichaBrewing) || (tech == cTechDEHCMeleeInfCombatInca) || 
               (tech == cTechDEHCRangedInfHitpointsInca) || (tech == cTechHCXPShipWarHutTravois1) || 
               (tech == cTechDEHCChiribayaDogs) ||          
               (tech == cTechHCXPGreatTempleHuitzilopochtli) || (tech == cTechHCMusketeerGrenadierHitpointsBritishTeam) || 
               (tech == cTechHCCavalryHitpointsBritish) || (tech == cTechDEHCRangers) ||
               (tech == cTechHCXPInfantryDamageIroquois) || (tech == cTechHCXPConservativeTactics) ||
               (tech == cTechHCXPCavalryHitpointsIroquois) || (tech == cTechHCXPCavalryDamageIroquois) ||
               (tech == cTechHCXPInfantryCombatIroquois) || (tech == cTechDEHCSiegeConstruction) ||
               (tech == cTechYPHCStandardArmyHitpoints) || (tech == cTechYPHCForbiddenArmyArmor) ||
               (tech == cTechDEHCHandCavalryHitpointsHausa) || (tech == cTechDEHCSahelianKingdoms) ||
               (tech == cTechDEHCFulaniArcherCombat) || (tech == cTechDEHCCounterCavalry) || 
               (tech == cTechypHCConsulateRelations) || (tech == cTechYPHCTerritorialArmyCombat) ||
               (tech == cTechYPHCSpawnSaigaHerd) || (tech == cTechHCMercsManchu) ||
               (tech == cTechHCInfantryHitpointsDutchTeam) ||  (tech == cTechHCInfantryDamageDutch) ||              
               (tech == cTechYPHCManchuCombat) || (tech == cTechHCXPCoyoteCombat) ||
               (tech == cTechDEHCZebenyas) || (tech == cTechDEHCTigrayMekonnen) ||
               (tech == cTechDEHCJesuitInfluence) || (tech == cTechHCWildernessWarfare) ||
               (tech == cTechHCRangedInfantryHitpointsFrench) || (tech == cTechHCRangedInfantryDamageFrenchTeam) ||
               (tech == cTechHCHandCavalryHitpointsFrench) || (tech == cTechHCCavalryCombatRussian) ||
               (tech == cTechHCUniqueCombatRussian) ||(tech == cTechHCShipCannons2) ||
               (tech == cTechDEHCMacehualtinCombat) ||(tech == cTechHCXPKnightCombat) ||  
               (tech == cTechDEHCFedGeneralAssembly) || (tech == cTechDEHCContinentalRangers) ||
               (tech == cTechDEHCRegularCombat) || (tech == cTechDEHCKosciuszkoFortifications) || 
               (tech == cTechDEHCMinneapolisMills) || (tech == cTechDEHCPeninsularGuerrillas) ||
               (tech == cTechHCHandCavalryHitpointsSpanish) || (tech == cTechHCHandInfantryCombatSpanish) ||
               (tech == cTechHCHandCavalryCombatSpanish) || (tech == cTechHCHandCavalryDamageSpanish) ||
               (tech == cTechHCXPCavalryDamageSioux) || (tech == cTechHCXPBuffalo4) || 
               (tech == cTechHCXPSiouxTwoKettleSupport) || (tech == cTechHCXPSiouxSanteeSupport) ||
               (tech == cTechHCXPCommandSkill) || (tech == cTechYPHCAshigaruDamage) || 
               (tech == cTechYPHCYumiDamage) || (tech == cTechYPHCYumiRange) || 
               (tech == cTechYPHCNaginataHitpoints) || (tech == cTechYPHCAshigaruAntiCavalryDamage) ||                
               (tech == cTechHCDragoonCombatPortuguese) ||(tech == cTechYPHCElephantCombatIndians) || 
               (tech == cTechYPHCMeleeDamageIndians) || (tech == cTechYPHCCamelFrightening) || 
               (tech == cTechYPHCSpiceTradeIndian) ||  (tech == cTechDEHCCheapSepoys) ||                                    
               (tech == cTechHCStreletsCombatRussian)))
            {
               cardPriority += 2+aiRandInt(4);
            }        


            // Raise priority of specific important cards.
            if ((cDifficultyCurrent >= cDifficultyModerate) &&
                ((tech == cTechHCXPAztecMining) || (tech == cTechDEHCChichimecaRebellion) || 
                 (tech == cTechHCXPChinampa2) || (tech == cTechHCXPShipWarHutTravois1) ||
                 (tech == cTechHCAdvancedArsenal) || (tech == cTechHCAdvancedArsenalGerman) ||
                 (tech == cTechYPHCGurkhaAid) || (tech == cTechypHCConsulateRelationsIndians) ||
                 (tech == cTechYPHCElephantTrampling) || (tech == cTechYPHCElephantLimit) ||
                 (tech == cTechDEShipRocketeersIndians) || (tech == cTechYPHCInfantrySpeedHitpointsTeam) ||
                 (tech == cTechHCXPNewWaysIroquois) || (tech == cTechDEHCSpringfieldArmory) ||
                 (tech == cTechHCXPNewWaysSioux) || (tech == cTechYPHCSpawnRefugees2) ||
                 (tech == cTechHCInfantryDamageDutch) ||(tech == cTechHCUnlockFort) || 
                 (tech == cTechDEHCLoyalWarriors) || (tech == cTechDEHCShipCoveredWagons2Inca) || 
                 (tech == cTechDEHCMachuPicchu) || (tech == cTechDEHCTerraceFarming) ||
                 (tech == cTechHCRoyalDecreeDutch) || (tech == cTechHCXPMercsGreatCannon) || 
                 (tech == cTechDEHCMercsBosniaks) || (tech == cTechDEHCMercsIrishBrigadiers) ||
                 (tech == cTechHCNavalCombat) || (tech == cTechHCNavalCombatGerman) ||
                 (tech == cTechHCMercsSwissPikemen) || (tech == cTechDEHCShipSudaneseAllies1) ||
                 (tech == cTechDEHCShipSudaneseAllies2) || (tech == cTechHCRefrigeration) ||
                 (tech == cTechDEHCImmigrantsRussian) || (tech == cTechHCAdvancedArtillery) || 
                 (tech == cTechDEHCCoffeeMillGun) || (tech == cTechHCUnlockFort) ||                 
                 (tech == cTechDEHCKnoxArtilleryTrain) || (tech == cTechDEHCLumberMills) ||                  
                 (tech == cTechDEHCMercsArmoredPistoleers) || (tech == cTechHCXPMercsGreatCannon) ||
                 (tech == cTechHCXPWarChiefAztec1) || (tech == cTechDEHCReconquista) ||                 
                 (tech == cTechHCSpiceTrade) || (tech == cTechHCCaballeros) ||
                 (tech == cTechHCRoyalMint) || (tech == cTechHCRefrigeration) ||
                 (tech == cTechHCXPSpanishGold) || (tech == cTechHCUnlockFort) ||
                 (tech == cTechDEHCNewSpainViceroyalty) || (tech == cTechDEHCMarvelousYear) ||
                 (tech == cTechDEHCMercsIrishBrigadiersGerman) || (tech == cTechDEHCShipGascenya4) ||                 
                 (tech == cTechHCArtilleryCombatOttoman) || (tech == cTechHCCavalryCombatOttoman) ||
                 (tech == cTechHCUnlockFort) || (tech == cTechDEHCFlightArchery) ||
                 (tech == cTechHCJanissaryCost) || (tech == cTechDEHCBuffaloSoldiers) ||
                 (tech == cTechHCXPOnikare) || (tech == cTechHCXPNewWaysSioux) ||
                 (tech == cTechHCXPEarthBounty) || (tech == cTechDEHCLakotaImprovedSiege) ||
                 (tech == cTechHCXPMustangs) || (tech == cTechHCShipAdvancedCapturedMortars) ||
                 (tech == cTechHCXPSiouxYanktonSupport) || (tech == cTechYPHCSamuraiDamage) || 
                 (tech == cTechYPHCSmoothRelations) || (tech == cTechypHCConsulateRelations) || 
                 (tech == cTechYPHCArtilleryHitpointsJapanese) || (tech == cTechYPHCYabusameAntiArtilleryDamage) ||                  
                 (tech == cTechYPHCNobleCombat) || (tech == cTechYPHCArtilleryCostJapanese) ||
                 (tech == cTechDEHCHandCombatPortuguese) || (tech == cTechDEHCShrineHitpoints) ||
                 (tech == cTechHCRoyalDecreeOttoman) || (tech == cTechYPHCNaginataAntiInfantryDamage) || 
                 (tech == cTechYPHCMorutaruRangeJapanese) || (tech == cTechDEHCLandwehr) ||
				 (tech == cTechDEHCElephantArmors) || (tech == cTechDEHCHandMortarOttoman) ||
				 (tech == cTechDEHCVasaAllies1) || (tech == cTechDEHCShipBattleshipRepeat) ||
				 (tech == cTechYPHCNavalCombatIndians)))
            {
               cardPriority += 1+aiRandInt(4);
            }
            



            
            // Decrease priority of specific cards we allow but don't want too often.
            if ((cDifficultyCurrent >= cDifficultyModerate) &&
                ((tech == cTechHCXPBloodBrothers) || (tech == cTechHCXPImprovedGrenades) ||
                (tech == cTechHCTextileMills) || (tech == cTechDEHCHandMortar) || 
                (tech == cTechDEHCSiegeArchery) || 
                (tech == cTechDEHCBelgianRevolution) || (tech == cTechDEHCHamiltonianEconomics) || 
                (tech == cTechHCXPSiouxOglalaSupport) || (tech == cTechHCXPSiouxSansArcSupport) || 
				(tech == cTechDEHCCentSuisses) || (tech == cTechDEHCPrinceElectors) ||
				(tech == cTechDEHCBuckriders) || (tech == cTechHCXPHuronAllies1) || 
				(tech == cTechHCGuildArtisans)))
            {
               cardPriority -= 2;
            }

            // Exclude cards we don't want in higher difficulties.
            if ((cDifficultyCurrent >= cDifficultyModerate) &&
             
                  ((tech == cTechHCImprovedBuildings) || (tech == cTechHCRidingSchool) || 
                  (tech == cTechHCFencingSchool) || (tech == cTechHCSustainableAgriculture) ||
                  (tech == cTechHCEngineeringSchool) || (tech == cTechHCHeavyFortifications) ||
                  (tech == cTechHCAdvancedArtillery) || (tech == cTechHCCigarRoller) ||
                  (tech == cTechHCXPShipHorseArtillery2) || (tech == cTechHCMedicine) ||
                  (tech == cTechHCXPBloodBrothers) || (tech == cTechHCShipCrossbowmen3) ||
                  (tech == cTechHCShipPikemen3) || (tech == cTechHCTextileMills) ||
				  (tech == cTechDEHCSeventeenProvinces) || (tech == cTechHCRansack) || 
				  (tech == cTechDEHCMercenaryCampsGerman) || (tech == cTechDEHCImmigrantsScottish) ||
				  (tech == cTechDEHCAncienRegime) || (tech == cTechDEHCCircleArmy) ||
                  (tech == cTechDEHCFencingSchoolFrench) || (tech == cTechDEHCFrenchRoyalArmy) ||
				  (tech == cTechDEHCFortySevenRonin) || (tech == cTechDEHCMarchRevolution)))

                  {
                     cardPriority = 0;
                  }  

            if (cardPriority < 0) // Can't ever happen I guess.
            {
               cardPriority = 0;
            }
            else if (cardPriority > 10)
            {
               cardPriority = 10;
            }

            debugHCCards("We gave card: " + kbGetTechName(tech) + " a priority of: " + cardPriority);
            
            // Save the flag of each card.
            xsArraySetInt(cardFlags, i, currentCardFlags);
            
            // If we're dealing with a card that ships a unit we save which unit it ships.
            if (unit >= 0)
            {
               xsArraySetInt(unitCardShippedUnit, i, unit);
            }
                   
            // If we're dealing with a unit card that is not TEAM we save a value + cost.
            if (((currentCardFlags & cHCCardFlagMilitary) == cHCCardFlagMilitary) &&
                ((currentCardFlags & cHCCardFlagUnit) == cHCCardFlagUnit) &&
                ((currentCardFlags & cHCCardFlagTeam) == 0))
            {
               totalValueCurrent = aiHCCardsGetCardValuePerResource(i, cResourceWood) +
                                   aiHCCardsGetCardValuePerResource(i, cResourceFood) +
                                   aiHCCardsGetCardValuePerResource(i, cResourceGold) +
                                   aiHCCardsGetCardValuePerResource(i, cResourceInfluence);
               xsArraySetInt(unitCardValue, i, totalValueCurrent);
               debugHCCards("We gave card: " + kbGetTechName(tech) + " a unit card value of: " + totalValueCurrent);
               totalCostCurrent = kbTechCostPerResource(tech, cResourceWood) +
                                  kbTechCostPerResource(tech, cResourceFood) +
                                  kbTechCostPerResource(tech, cResourceGold) +
                                  kbTechCostPerResource(tech, cResourceInfluence);
               xsArraySetInt(unitCardCost, i, totalCostCurrent);
               debugHCCards("We gave card: " + kbGetTechName(tech) + " a unit card cost of: " + totalCostCurrent);
            }
            
            xsArraySetInt(cardPriorities, i, cardPriority);
            numCardsProcessed++;
            // Don't process too many cards at a time, after 7 cards we quit the rule and come back next frame.
            if (i >= startingCardIndex + 7)
            {
               break;
            }
         }
         
         if (numCardsProcessed >= totalCardCount)
         {
            pass = 1; // Make a deck next time.
         }
         break;
      }
      default: // Make deck.
      {
         static bool initializedDeck = false;
         if (initializedDeck == false)
         {
            debugHCCards("Making deck");
            if (gSPC == true)
            {
               gDefaultDeck = aiHCDeckCreate("The SPC AI Deck");
               debugHCCards("Using deck at index: " + gDefaultDeck);
            }
            else
            {
               // In non spc games, the game will make an empty deck for AI's at index 0.
               gDefaultDeck = 0;
               debugHCCards("Using deck at index: " + gDefaultDeck);
            }
            debugHCCards("Starting the deck building process");
            initializedDeck = true;
         }
   
         static int cardsRemaining = 25; // Standard deck size.
         if ((cardsRemaining == 25) && ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans)))
         {
            cardsRemaining = 21; // Reduced deck size for USA / MX.
         }
         static int cardsInAge1Or2 = 0; // Keep track of how many cards we have in these ages.
         static int cardsInAge3 = 0;
         int maxCardsInAge1Or2 = 10; // Set a max for these ages so we can manage our divide.
         int maxCardsInAge3 = 9;
         if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans))
         {
            maxCardsInAge1Or2 = 9;
            maxCardsInAge3 = 7;
         }
         bool isTeamGame = false;
         if (getAllyCount() > 0)
         {
            isTeamGame = true;
         }
         float totalValueBest = 0.0;
         static int cardsPicked = 0;
         int bestCard = -1;
         int bestCardPriority = -1;
         int currentCardPriority = -1;
         static int toPick = -1;
         static int toPickNaval = 0;
         int compareFlag = 0;
         int age = kbGetAge();
         bool unitHasACost = false;
         int totalValueDifference = 0;
   
         switch (pass)
         {
            //=============
            // This case is all about selecting the starting Villagers (or other cards if no Villagers available)
            // and potentially some very good Exploration cards.
            //=============
            case 1:
            {
               if (toPick < 0) // How many cards can we pick this case.
               {
                  if (cMyCiv == cCivDEHausa)
                  {
                     toPick = 2; // Hausa Kingdom.
                  }
                  else if ((cMyCiv == cCivPortuguese) && (startingResources != cGameStartingResourcesInfinite))
                  {
                     toPick = 2; // Feitorias.                     
                  }
                   else if ((cMyCiv == cCivIncas) && (startingResources != cGameStartingResourcesInfinite))
                  {
                     toPick = 2; // American Allies.                     
                  }
                  else if ((cMyCiv == cCivFrench) && (startingResources != cGameStartingResourcesInfinite))
                  {
                     toPick = 2; // Economic Theory                     
                  }
                  else if ((cMyCiv == cCivDESwedish) && (startingResources != cGameStartingResourcesInfinite))
                  {
                     toPick = 2; // Blueberries.
                  }
                  else if ((cMyCiv == cCivDutch) && (startingResources != cGameStartingResourcesInfinite))
                  {
                     toPick = 3; // Bank limit increases.

                  }

                  else
                  {
                     toPick = 1;
                  }
                  if ((age != cAge1) ||
                      (startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra)) 
                  {
                     toPick--; // Don't add these starting Villagers when starting on a later age / have enough starting resources.
                  }
                  debugHCCards("***Exploration cards: " + toPick);
               }
               
               if (toPick > 0)
               {
                  for (card = 0; < totalCardCount) // Parse all cards.
                  {
                     if (xsArrayGetInt(cardStates, card) != cCardStateAvailable)
                     {
                        continue;
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     tech = aiHCCardsGetCardTechID(card);

                     // Add the special starting cards.
                     if (((cMyCiv == cCivIndians) && (tech == cTechYPHCAgrarianism)) || // Indian starting wood trickle.
                         ((cMyCiv == cCivRussians) && (tech == cTechHCXPDistributivism)) ||
                         ((cMyCiv == cCivPortuguese) && ((tech == cTechDEHCFeitorias) || (tech == cTechHCXPEconomicTheory))) ||  
                         ((cMyCiv == cCivIncas) && (tech == cTechDEHCAmericanAlliesInca)) ||
                         ((cMyCiv == cCivDutch) && ((tech == cTechHCBanks1) || (tech == cTechHCBanks2))) ||
                         ((cMyCiv == cCivDEHausa) && (tech == cTechDEHCHausaKingdom)) || // Hausa Kingdom.
                         ((cMyCiv == cCivDESwedish) && (tech == cTechDEHCBlueberries)) ||
                         ((cMyCiv == cCivChinese) && (tech == cTechYPHCSpawnRefugees1)) || // This card isn't recognized as Villager, add here.
                         ((cMyCiv == cCivDEAmericans) && (tech == cTechHCXPCapitalism)) ||
                         ((cMyCiv == cCivDEItalians) && (tech == cTechHCXPCapitalism)))


                     {
                        if (addCardToDeck(gDefaultDeck, card) == true)
                        {
                           xsArraySetInt(cardStates, card, cCardStateInDeck);
                           cardsRemaining--;
                           cardsPicked++;
                           cardsInAge1Or2++;
                           break;
                        }
                     }
                     
                     // Add the initial Villager card.
                     if ((startingResources != cGameStartingResourcesInfinite) &&
                         (startingResources != cGameStartingResourcesUltra) &&
                         (age == cAge1) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge1) &&
                         ((currentCardFlags & cHCCardFlagVillager) == cHCCardFlagVillager) &&
                         ((currentCardFlags & cHCCardFlagWater) == 0) && // Exclude Fishing Ships.
                         ((aiHCCardsGetCardCount(card) > 0) || ((tech == cTechDEHCShipVillagersAbunRepeat) ||
                         (tech == cTechDEHCShipVillagers1Repeat)))) // Hausa and Ethiopians have age 1 Villager cards on infinite.
                     {
                        if (addCardToDeck(gDefaultDeck, card) == true)
                        {
                           xsArraySetInt(cardStates, card, cCardStateInDeck);
                           cardsRemaining--;
                           cardsPicked++;
                           cardsInAge1Or2++;
                           break;
                        }
                     }
                  }
                  toPick--;
               }
               
               // We've picked everything we wanted this age, go on.
               if (toPick <= 0)
               {
                  pass = 2;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Commerce crates.
            //=============
            case 2:
            {
               if (toPick < 0)
               {
                  if ((startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra))
                  {
                     toPick = 0; // No need for crates.
                  }
                  else
                  {
                     toPick = 2; // 2 Resource crates in the Commerce Age.
                  }
                  if (btRushBoom > 0.0)
                  {
                     toPick++; // We stay longer in Commerce so get some resources and fewer upgrades.
                  }
                  if (cMyCiv == cCivXPSioux)
                  {
                     toPick = 2;
                  }
                  debugHCCards("***Commerce crates: " + toPick);
               }

               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
      
                  for (card = 0; < totalCardCount)
                  {
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((xsArrayGetInt(cardFlags, card) & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge2))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge1Or2++;
                     }
                  }
                  
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 3;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Commerce upgrades.
            //=============
            case 3:
            {
               if (toPick < 0) // How many Commerce Age upgrades are we picking.
               {  // AssertiveWall: include 20 minute treaties (19 v 21)
                  if (aiTreatyGetEnd() > 19 * 60 * 1000) // Long treaty game, we don't add military in Commerce so fill here.
                  {
                     toPick = maxCardsInAge1Or2 - cardsInAge1Or2; // Reach our limit.
                     if ((cMyCiv != cCivIndians) && (cMyCiv != cCivPortuguese) && (cMyCiv != cCivRussians) &&
                         (cMyCiv != cCivChinese) && (cMyCiv != cCivDESwedish) && (cMyCiv != cCivDEAmericans) &&
                         (startingResources != cGameStartingResourcesInfinite) &&
                         (startingResources != cGameStartingResourcesUltra) &&
                         (age < cAge4))
                     {
                        toPick--; // Save one spot for a Villager card if we can send Villagers.
                     }
                  }
                  else
                  {
                     if ((cMyCiv == cCivDEHausa) || (cMyCiv == cCivDESwedish) || (cMyCiv == cCivDutch) ||
                        (cMyCiv == cCivDEMexicans))
                     {
                        toPick = 2;
                     }
                     else
                     {
                        toPick = 3;
                     }
                     if (cMyCiv == cCivXPSioux)
                     {
                        toPick = 4;
                     }
                     if (btRushBoom > 0.0)
                     {
                        toPick--; // Account for the extra crate.
                     }
                     if ((startingResources == cGameStartingResourcesInfinite) ||
                         (startingResources == cGameStartingResourcesUltra)) // Add crate/starting Villager cards onto this.
                     {
                        if (((cMyCiv == cCivDutch) || (cMyCiv == cCivDESwedish)) && (startingResources == cGameStartingResourcesInfinite))
                        {
                           toPick += cMyCiv == cCivDutch? 2 : 1; // Add the Bank/Blueberries card replacements here.
                        }
                        toPick += 3;
                        if (btRushBoom > 0.0)
                        {
                           toPick++; // Account for the extra crate.
                        }
                     }
                     if ((age != cAge1) &&
                        (startingResources != cGameStartingResourcesInfinite) &&
                        (startingResources != cGameStartingResourcesUltra)) // Add the starting Villager card to this, care to not double add.
                     {
                        toPick++;
                     }
                  }
                  if ((isTeamGame == true) && (toPick > 1)) // Some civs that are rushing will have 1 less Commerce unit because of this.
                  {
                     toPick--; // Reserve for later addition of 3 TEAM cards.
                  }
                  if ((gHaveWaterSpawnFlag == true) && (toPick > 1))
                  {
                     toPickNaval = 1;
                     debugHCCards("***Naval Commerce Upgrades: " + toPickNaval);
                  }
                  debugHCCards("***Land Commerce/Exploration Upgrades: " + (toPick - toPickNaval));
               }
               
               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
                  currentCardFlags = 0;
                  if (toPickNaval > 0)
                  {
                     compareFlag = cHCCardFlagWater; // Else this is 0 so no flag (land).
                  }
                  
                  for (card = 0; < totalCardCount)
                  {
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     tech = aiHCCardsGetCardTechID(card);
                     cardAgePreReq = aiHCCardsGetCardAgePrereq(card);
                     
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((((currentCardFlags & cHCCardFlagUnitUpgrade) == cHCCardFlagUnitUpgrade) || (currentCardFlags == 0)) &&
                          ((currentCardFlags & cHCCardFlagTeam) == 0) &&
                          ((currentCardFlags & cHCCardFlagWater) == compareFlag) &&
                          ((cardAgePreReq == cAge2) || 
                          ((cardAgePreReq == cAge1) && ((tech == cTechHCXPEconomicTheory)))) ||
                           (tech == cTechDEHCIndianTradeEthiopia) || (tech == cTechHCAdvancedTradingPost) ||
                         (tech == cTechHCAdvancedArsenalGerman) || (tech == cTechDEHCSpringfieldArmory)))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge1Or2++;
                     }
                  }
                  
                  if ((toPickNaval > 0) && (bestCard < 0))
                  {
                     toPick++; // Basically if we didn't find a naval upgrade make sure we do pick a land upgrade.
                     debugHCCards("We failed to pick a Commerce Naval Upgrade, try again for a land one");
                  }
                  
                  toPickNaval--;
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 4;
                  toPick = -1;
                  toPickNaval = 0;
               }
               break;
            }
            //=============
            // Commerce units.
            //=============
            case 4:
            {
               static bool pickedCommerceCostUnit = false; // Prevent multiple units with a cost being added (we don't reserve resources for this).
               static bool addedVillager = false;
               if (toPick < 0)
               {  // AssertiveWall: include 20 minute treaties (19 v 21)
                  if (aiTreatyGetEnd() > 19 * 60 * 1000) // Long treaty game, don't add military in Commerce.
                  {
                     if ((startingResources == cGameStartingResourcesInfinite) ||
                         (startingResources == cGameStartingResourcesUltra) ||
                         (age >= cAge4) ||
                         (cMyCiv == cCivIndians) || (cMyCiv == cCivPortuguese) || (cMyCiv == cCivRussians) || 
                         (cMyCiv == cCivChinese) || (cMyCiv == cCivDESwedish) || (cMyCiv == cCivDEAmericans))
                     {
                        toPick = 0;
                     }
                     else
                     {
                        toPick = 1; // Still add the Villager though.
                     }

                  }
                  else
                  {
                     toPick = maxCardsInAge1Or2 - cardsInAge1Or2; // Reach our limit.
                  }
                  if ((isTeamGame == true) && ((toPick > 1) || // Keep our Villager always.
                      ((cMyCiv == cCivIndians) || (cMyCiv == cCivPortuguese) || (cMyCiv == cCivRussians) ||
                      (cMyCiv == cCivChinese) || (cMyCiv == cCivDESwedish) || (cMyCiv == cCivDEAmericans))))
                  {
                     toPick--; // This is to compensate for the upgrade we didn't pick before, it messes up the calc above.
                  }
                  if ((gHaveWaterSpawnFlag == true) && (toPick > (cMyCiv == cCivDutch ? 2 : 1))) // Need Villagers + Bank as Dutch for sure.
                  {
                     toPickNaval = 1;
                     if ((toPick > 3) && (gStartOnDifferentIslands == true)) // Focus a bit more on naval if we definitely need to sail.
                     {
                        toPickNaval = 2;
                     }
                     debugHCCards("Naval Commerce Units: " + toPickNaval);
                  }
                  debugHCCards("Land Commerce Units/Villagers: " + (toPick - toPickNaval));
               }
               
               if (toPick > 0)
               {
                  currentCardFlags = 0;
                  totalValueCurrent = 0.0;
                  totalValueBest = 0.0;
                  totalCostCurrent = 0.0;
                  if (toPickNaval > 0)
                  {
                     compareFlag = cHCCardFlagWater; // Else this is 0 so no flag (land).
                  }
                  
                  for (card = 0; < totalCardCount)
                  {
                     if (xsArrayGetInt(cardStates, card) != cCardStateAvailable)
                     {
                        continue;
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     tech = aiHCCardsGetCardTechID(card);
                     cardAgePreReq = aiHCCardsGetCardAgePrereq(card);
                     
                     if ((cMyCiv == cCivDutch) && // Make sure the Dutch get the Bank shipment.
                         (tech == cTechHCXPBankWagon))
                     {
                        toPickNaval++;
                        bestCard = card;
                        break;
                     }

                     if ((cMyCiv == cCivJapanese) && // Make sure the Japanese gets at least 1 Daimyo
                         (tech == cTechYPHCShipDaimyoAizu)) // || (tech == cTechYPHCShipShogunate) || (tech == cTechYPHCShipDaimyoSatsuma))
                     {
                        toPick++;
                        bestCard = card;
                        break;
                     }  
                     
                     else if ((cMyCiv == cCivIndians) || (cMyCiv == cCivJapanese))
                     {
                        if ((tech == cTechYPHCShipBerryWagon2) || (tech == cTechYPHCShipGroveWagonIndians2))
                        {
                           toPickNaval++;
                           bestCard = card;
                           break;
                        }
                     }
                     
                     // Add the second Villager card.
                     if (((cMyCiv != cCivIndians) && (cMyCiv != cCivPortuguese) && (cMyCiv != cCivRussians) &&
                         (cMyCiv != cCivChinese) && (cMyCiv != cCivDESwedish) && (cMyCiv != cCivDEAmericans)) &&
                         (addedVillager == false) &&
                         (startingResources != cGameStartingResourcesInfinite) &&
                         (startingResources != cGameStartingResourcesUltra) &&
                         (age < cAge4) &&
                         (cardAgePreReq == cAge2) &&
                         ((currentCardFlags & cHCCardFlagTeam) == 0) &&
                         ((currentCardFlags & cHCCardFlagVillager) == cHCCardFlagVillager) &&
                         ((currentCardFlags & cHCCardFlagWater) != cHCCardFlagWater) && // Exclude Fishing Ships.
                         (aiHCCardsGetCardCount(card) > 0))
                     {
                        bestCard = card;
                        addedVillager = true;
                        if (toPickNaval > 0)
                        {
                           toPickNaval++; // We will always reduce this when we add this Villager card.
                        }                 // So bump it here to offset it.
                        break;
                     }
                     
                     totalValueCurrent = xsArrayGetInt(unitCardValue, card);
                     if ((totalValueCurrent != -9999) &&
                         ((currentCardFlags & cHCCardFlagWater) == compareFlag) && // Either naval or not.
                         (cardAgePreReq == cAge2) &&
                         (aiHCCardsGetCardCount(card) > 0))
                     {
                        totalCostCurrent = xsArrayGetInt(unitCardCost, card);
                        totalValueCurrent -= totalCostCurrent;
                        if (totalValueCurrent <= 0.0)
                        {
                           totalValueCurrent = 1.0;
                        }
                        totalValueDifference = totalValueBest - totalValueCurrent; // Cards that are close together in value get some RNG.
                        if ((totalValueDifference < 100.0) && (aiRandInt(2) == 0))
                        {
                           if (totalValueDifference >= 0.0)
                           {
                              totalValueCurrent += (totalValueDifference + 1.0);
                           }
                        }
                        if ((totalValueCurrent > totalValueBest) && ((totalCostCurrent <= 0) || (pickedCommerceCostUnit == false)))
                        {
                           if (totalCostCurrent > 0)
                           {
                              unitHasACost = true;
                           }
                           bestCard = card;
                           totalValueBest = totalValueCurrent;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        if (unitHasACost == true)
                        {
                           pickedCommerceCostUnit = true;
                        }
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge1Or2++;
                     }
                  }
                  
                  if ((toPickNaval > 0) && (bestCard < 0))
                  {
                     toPick++; // Basically if we didn't find a naval unit make sure we do pick a land unit.
                     debugHCCards("We failed to pick a Commerce Naval unit, try again for a land one");
                  }
                  
                  toPick--;
                  toPickNaval--;
               }
               
               if (toPick <= 0)
               {
                  pass = 5;
                  toPick = -1;
                  toPickNaval = 0;
               }
               break;
            }
            //=============
            // Fortress crates.
            //=============
            case 5:
            {
               if (toPick < 0)
               {
                  if ((startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra))
                  {
                     toPick = 0; // No need for crates.
                  }
                  else
                  {
                     toPick = 2; // 2 Resource crates in the Fortress Age.
                  }
                  debugHCCards("***Fortress crates: " + toPick);
               }

               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
      
                  for (card = 0; < totalCardCount)
                  {
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((xsArrayGetInt(cardFlags, card) & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge3))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge3++;
                     }
                  }
                  
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 6;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Fortress upgrades.
            //=============
            case 6:
            {
               if (toPick < 0) // How many Fortress Age upgrades are we picking.
               {
                  if ((cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivPortuguese))
                  {
                     toPick = 2;
                  }
                  else
                  {
                     toPick = 3;
                  }
                  if ((startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra)) // Add crates onto this.
                  {
                     toPick += 2;
                  }
                  if (isTeamGame == true)
                  {
                     toPick--; // Reserve for later addition of 3 TEAM cards.
                  }
                  if ((gHaveWaterSpawnFlag == true) && (toPick > 1) && (gStartOnDifferentIslands == true))
                  {
                     toPickNaval = 1;
                     debugHCCards("***Naval Fortress Upgrades: " + toPickNaval);
                  }
                  debugHCCards("***Land Fortress Upgrades: " + (toPick - toPickNaval));
               }
               
               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
                  currentCardFlags = 0;
                  if (toPickNaval > 0)
                  {
                     compareFlag = cHCCardFlagWater; // Else this is 0 so no flag (land).
                  }
                  
                  for (card = 0; < totalCardCount)
                  {
                     unit = xsArrayGetInt(unitCardShippedUnit, card);
                     if (unit == cUnitTypeFortWagon)
                     {
                        continue; // There are some cards that are seen as upgrades due to giving +1 Fort BL.
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         (((currentCardFlags & cHCCardFlagUnitUpgrade) == cHCCardFlagUnitUpgrade) || (currentCardFlags == 0)) &&
                         ((currentCardFlags & cHCCardFlagTeam) == 0) &&
                         ((currentCardFlags & cHCCardFlagWater) == compareFlag) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge3))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge3++;
                     }
                  }
                  
                  if ((toPickNaval > 0) && (bestCard < 0))
                  {
                     toPick++; // Basically if we didn't find a naval upgrade make sure we do pick a land upgrade.
                     debugHCCards("We failed to pick a Fortress Naval Upgrade, try again for a land one");
                  }
                  
                  toPickNaval--;
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 7;
                  toPick = -1;
                  toPickNaval = 0;
               }
               break;
            }
            //=============
            // Fortress units.
            //=============
            case 7:
            {
               static bool pickedFortressCostUnit = false; // Prevent multiple units with a cost being added (we don't reserve resources for this).
               static bool pickedFortress = true;
               if (toPick < 0)
               {
                  if ((civIsEuropean() == true) && (btOffenseDefense <= 0) &&
                      (aiRandInt(5) == 0)) // 20% chance for "defenders" to pick a Fortress.
                  {
                     pickedFortress = false;
                  }
                  toPick = maxCardsInAge3 - cardsInAge3; // Reach our limit.
                  if (isTeamGame == true)
                  {
                     toPick--; // This is to compensate for the upgrade we didn't pick before, it messes up the calc above.
                  }
                  if ((gHaveWaterSpawnFlag == true) && (toPick > 1))
                  {
                     toPickNaval = 1;
                     debugHCCards("***Naval Fortress Units: " + toPickNaval);
                  }
                  debugHCCards("***Land Fortress Units: " + (toPick - toPickNaval));
               }
               
               if (toPick > 0)
               {
                  currentCardFlags = 0;
                  totalValueCurrent = 0.0;
                  totalValueBest = 0.0;
                  totalCostCurrent = 0.0;
                  if (toPickNaval > 0)
                  {
                     compareFlag = cHCCardFlagWater; // Else this is 0 so no flag (land).
                  }
                  
                  for (card = 0; < totalCardCount)
                  {
                     if ((xsArrayGetInt(cardStates, card) != cCardStateAvailable) ||
                         (aiHCCardsGetCardAgePrereq(card) != cAge3))
                     {
                        continue;
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     unit = xsArrayGetInt(unitCardShippedUnit, card);
                     
                     if ((pickedFortress == false) && (unit == cUnitTypeFortWagon))
                     {
                        bestCard = card;
                        pickedFortress = true;
                        toPickNaval++;
                        break;
                     }
                     
                     totalValueCurrent = xsArrayGetInt(unitCardValue, card);
                     if ((totalValueCurrent != -9999) &&
                         ((currentCardFlags & cHCCardFlagWater) == compareFlag) && // Either naval or not.
                         (aiHCCardsGetCardCount(card) > 0))
                     {
                        totalCostCurrent = xsArrayGetInt(unitCardCost, card);
                        totalValueCurrent -= totalCostCurrent;
                        if (totalValueCurrent <= 0.0)
                        {
                           totalValueCurrent = 1.0;
                        }
                        if (unit == cUnitTypeFalconet) // Get the 2 Falconet shipments always.
                        {
                           totalValueCurrent = 10000.0;
                        }
                                                if (unit == cUnitTypeOrganGun) // Get the 3 Organ Gun shipments always.
                        {
                           totalValueCurrent = 10000.0;
                        } 

                        
                        totalValueDifference = totalValueBest - totalValueCurrent; // Cards that are close together in value get some RNG.
                        if ((totalValueDifference < 100.0) && (aiRandInt(2) == 0))
                        {
                           if (totalValueDifference >= 0.0)
                           {
                              totalValueCurrent += (totalValueDifference + 1.0);
                           }
                        }
                        if ((totalValueCurrent > totalValueBest) && ((totalCostCurrent <= 0) || (pickedFortressCostUnit == false)))
                        {
                           if (totalCostCurrent > 0)
                           {
                              unitHasACost = true;
                           }
                           bestCard = card;
                           totalValueBest = totalValueCurrent;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        if (unitHasACost == true)
                        {
                           pickedFortressCostUnit = true;
                        }
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                        cardsInAge3++;
                     }
                  }
                  
                  if ((toPickNaval > 0) && (bestCard < 0))
                  {
                     toPick++; // Basically if we didn't find a naval unit make sure we do pick a land unit.
                     debugHCCards("We failed to pick a Fortress Naval unit, try again for a land one");
                  }
                  
                  toPick--;
                  toPickNaval--;
               }
               
               if (toPick <= 0)
               {
                  pass = 8;
                  toPick = -1;
                  toPickNaval = 0;
               }
               break;
            }
            //=============
            // Industrial crates.
            //=============
            case 8:
            {
               if (toPick < 0)
               {
                  if ((startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra))
                  {
                     toPick = 0; // No need for crates.
                  }
                  else
                  {
                     toPick = 0; // 0 Resource crate in the Industrial Age.
                  }
                  debugHCCards("***Industrial crates: " + toPick);
               }

               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
      
                  for (card = 0; < totalCardCount)
                  {
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((xsArrayGetInt(cardFlags, card) & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge4))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                     }
                  }
                  
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 9;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Industrial upgrades.
            //=============
            case 9:
            {
               if (toPick < 0) // How many Industrial Age upgrades are we picking.
               {
                  toPick = 1;
                  if ((startingResources == cGameStartingResourcesInfinite) ||
                      (startingResources == cGameStartingResourcesUltra)) // Add crate onto this.
                  {
                     toPick++;
                  }
                  debugHCCards("***Land Industrial Upgrades: " + (toPick));
               }
               
               if (toPick > 0)
               {
                  bestCard = -1;
                  bestCardPriority = -1;
                  currentCardFlags = 0;
                  
                  for (card = 0; < totalCardCount)
                  {
                     unit = xsArrayGetInt(unitCardShippedUnit, card);
                     if (unit == cUnitTypeFortWagon)
                     {
                        continue; // There are some cards that are seen as upgrades due to giving +1 Fort BL.
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         (((currentCardFlags & cHCCardFlagUnitUpgrade) == cHCCardFlagUnitUpgrade) || (currentCardFlags == 0)) &&
                         ((currentCardFlags & cHCCardFlagTeam) == 0) &&
                         ((currentCardFlags & cHCCardFlagWater) == 0) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge4))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                     }
                  }
                  
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 10;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Industrial infinite units.
            //=============
            case 10:
            {
               if (toPick < 0)
               {
                  toPick = 1; // Always 1 infinite land unit for Industrial.
                  debugHCCards("***Land Industrial Infinite Units: 1");
               }
               
               if (toPick > 0)
               {
                  currentCardFlags = 0;
                  totalValueCurrent = 0.0;
                  totalValueBest = 0.0;
                  totalCostCurrent = 0.0;
                  
                  for (card = 0; < totalCardCount)
                  {
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     
                     totalValueCurrent = xsArrayGetInt(unitCardValue, card);
                     if ((totalValueCurrent != -9999) &&
                         (xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((currentCardFlags & cHCCardFlagWater) == 0) &&
                         (aiHCCardsGetCardAgePrereq(card) == cAge4) &&
                         (aiHCCardsGetCardCount(card) < 0))
                     {
                        totalCostCurrent = xsArrayGetInt(unitCardCost, card);
                        totalValueCurrent -= totalCostCurrent;
                        if ((totalValueCurrent <= 0.0) || (totalCostCurrent > 0.0)) // Try to prevent infinite shipments that have a cost.
                        {
                           totalValueCurrent = 1.0;
                        }
                        totalValueDifference = totalValueBest - totalValueCurrent; // Cards that are close together in value get some RNG.
                        if ((totalValueDifference < 100.0) && (aiRandInt(2) == 0))
                        {
                           if (totalValueDifference >= 0.0)
                           {
                              totalValueCurrent += (totalValueDifference + 1.0);
                           }
                        }

                        if (totalValueCurrent > totalValueBest)
                        {
                           bestCard = card;
                           totalValueBest = totalValueCurrent;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                     }
                  }
 
                  toPick--;
               }
               
               if (toPick <= 0)
               {
                  pass = 11;
                  toPick = -1;
               }
               break;
            }
            //=============
            // Industrial units.
            //=============
            case 11:
            {
               static bool pickedIndutrialCostUnit = false; // Prevent multiple units with a cost being added (we don't reserve resources for this).
               static bool triedAgain = false;
               if (toPick < 0)
               {
                  toPick = cardsRemaining; // Reach our limit.
                  if (isTeamGame == true)
                  {
                     toPick -= 3; // Keep the space for TEAM cards intact.
                     if ((civIsEuropean() == true) && (toPick < 2))
                     {
                        toPick = 2; // Always get the Factories.
                     }
                  }
                  debugHCCards("***Land Industrial Units: " + toPick);
               }
               
               if (toPick > 0)
               {
                  currentCardFlags = 0;
                  totalValueCurrent = 0.0;
                  totalValueBest = 0.0;
                  totalCostCurrent = 0.0;
                  if (toPickNaval > 0)
                  {
                     compareFlag = cHCCardFlagWater; // else this is 0 so no flag (land).
                  }
                  
                  for (card = 0; < totalCardCount)
                  {
                     if ((xsArrayGetInt(cardStates, card) != cCardStateAvailable) ||
                         (aiHCCardsGetCardAgePrereq(card) != cAge4))
                     {
                        continue;
                     }
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     unit = xsArrayGetInt(unitCardShippedUnit, card);
                     
                     if (unit == cUnitTypeFactoryWagon)
                     {
                        bestCard = card; // Put as many factories as you can in the deck.
                        toPickNaval++;
                        break;
                     }

                     totalValueCurrent = xsArrayGetInt(unitCardValue, card);
                     if ((totalValueCurrent != -9999) &&
                         ((currentCardFlags & cHCCardFlagWater) == compareFlag) && // Either naval or not.
                         (aiHCCardsGetCardCount(card) > 0))
                     {
                        totalCostCurrent = xsArrayGetInt(unitCardCost, card);
                        totalValueCurrent -= totalCostCurrent;
                        if (totalValueCurrent <= 0.0)
                        {
                           totalValueCurrent = 1.0;
                        }
                        totalValueDifference = totalValueBest - totalValueCurrent; // Cards that are close together in value get some RNG.
                        if ((totalValueDifference < 100.0) && (aiRandInt(2) == 0))
                        {
                           if (totalValueDifference >= 0.0)
                           {
                              totalValueCurrent += (totalValueDifference + 1.0);
                           }
                        }
                        if ((totalValueCurrent > totalValueBest) && ((totalCostCurrent <= 0) || (pickedIndutrialCostUnit == false)))
                        {
                           if (totalCostCurrent > 0)
                           {
                              unitHasACost = true;
                           }
                           bestCard = card;
                           totalValueBest = totalValueCurrent;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        if (unitHasACost == true)
                        {
                           pickedIndutrialCostUnit = true; 
                        }
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                     }
                  }
                  
                  if ((toPickNaval > 0) && (bestCard < 0))
                  {
                     toPick++; // Basically if we didn't find a naval unit make sure we do pick a land unit.
                     debugHCCards("We failed to pick a Industrial Naval unit, try again for a land one");
                  }
                  
                  toPick--;
                  toPickNaval--;
               }
               
               if (toPick <= 0)
               {
                  if ((isTeamGame == false) && (cardsRemaining > 0) && (triedAgain == false))
                  {
                     triedAgain = true;
                     toPick = cardsRemaining; // More chances to fill out our deck with land unit shipments.
                     debugHCCards("We failed to fill the deck, let's try again to pick Industrial units, this many cards were missing: "
                        + cardsRemaining);
                     return;
                  }
                  if ((isTeamGame == true) || (cardsRemaining > 0)) // Insert TEAM cards when it's a teamgame.
                  {                                                 // Or if somehow our deck isn't full we use this as a failsafe.
                     pass = 12;
                  }
                  else
                  {
                     pass = 13; // Yeey we're done!
                  }
                  toPick = -1;
                  toPickNaval = 0;
               }
               break;
            }
            //=============
            // Potentially TEAM cards.
            //=============
            case 12:
            {
               static int tryCounter = 0; // If this goes too high we just opt out and prevent an infinite loop.
               static bool hasOptedOut = false;
               if (tryCounter == 0)
               {
                  debugHCCards("***TEAM cards: " + cardsRemaining);
                  debugHCCards("***Cards picked total: " + cardsPicked);
               }
               if ((cardsRemaining > 0) && (hasOptedOut == false))
               {
                  bestCard = -1;
                  bestCardPriority = -1;
                  currentCardFlags = 0;
                  
                  for (card = 0; < totalCardCount)
                  {
                     currentCardFlags = xsArrayGetInt(cardFlags, card);
                     tech = aiHCCardsGetCardTechID(card);
                     
                     if ((gNavyMap == false) && (((currentCardFlags & cHCCardFlagWater) == cHCCardFlagWater) ||
                         (tech == cTechHCCoastalDefensesTeam)))
                     {
                        continue;
                     }
                     
                     if ((xsArrayGetInt(cardStates, card) == cCardStateAvailable) &&
                         ((currentCardFlags & cHCCardFlagTeam) == cHCCardFlagTeam))
                     {
                        if (xsArrayGetInt(cardPriorities, card) > bestCardPriority)
                        {
                           bestCardPriority = xsArrayGetInt(cardPriorities, card);
                           bestCard = card;
                        }
                     }
                  }
                  
                  if (bestCard >= 0)
                  {
                     if (addCardToDeck(gDefaultDeck, bestCard) == true)
                     {
                        xsArraySetInt(cardStates, bestCard, cCardStateInDeck);
                        cardsRemaining--;
                        cardsPicked++;
                     }
                     else
                     {
                        // Maybe the age of the card is already full which can happen here.
                        // So we must guard against selecting the same unavailable card forever.
                        xsArraySetInt(cardStates, bestCard, cCardStateUnavailable); 
                     }
                  }
                  else // We didn't find a suitable card and won't ever either, opt out.
                  {
                     tryCounter = 9;
                     hasOptedOut = true;
                  }
               }
               tryCounter++;
               if (cardsRemaining == 0)
               {
                  pass = 13; // Yeey we're done!
               }
               else if ((cardsRemaining > 0) && (tryCounter == 10))
               {
                  debugHCCards("We failed to fill up the deck with TEAM cards, try again with Industrial Age units, " +
                     "we're missing this many cards: " + cardsRemaining);
                  pass = 11; // Try again to fill up with Industrial land units, if that also fails we're just rekt.
                  toPick = cardsRemaining;
               }
               else if (tryCounter >= 11) // We were also not able to fill with industrial units in our last ditch effort.
               {
                  debugHCCards("We tried everything we could but couldn't fill our deck :(");
                  pass = 13; // We haven't been able to fill our deck :(
               }
               break;
            }
         }

         if (pass >= 13)
         {
            debugHCCards("Activating deck");
            aiHCDeckActivate(gDefaultDeck);
   
            xsDisableSelf();
            break;
         }
      }
   }
}

//==============================================================================
/* shipGrantedHandler
   
   Called whenever we get a new shipment available to us.
   Analyze the cards available to us in relation to the situation in game and pick
   the best one.
*/
//==============================================================================
void shipGrantedHandler(int parm = -1) // parm is unused.
{
   if (kbResourceGet(cResourceShips) < 1.0)
   {
      return; // Early out if we don't have a shipment available.
   }
   
   debugHCCards("");
   debugHCCards("Shipment Available, analyzing which card to send");
   
   int mainBaseID = kbBaseGetMainID(cMyID);
   bool homeBaseUnderAttack = false;
   if (gDefenseReflexBaseID == mainBaseID)
   {
      homeBaseUnderAttack = true; // So don't send crates or Villagers.
   }

   // Adjust for rush or boominess.
   float econBias = 0.0; // How much to boost econ units or penalize military units.
   // Flip rushboom sign so boomer is +1 and rusher is -1.
   econBias = (btRushBoom * -1.0);
   // Set econBias as a percentage boost or penalty for crates and Settlers.
   econBias = (econBias / 4.0) + 1.0; // +/- Up to 25%.

   // USA and MX Federal State cards are in the extended deck, save if the best card is in the extended deck or not.
   bool bestCardIsExtended = false;
   int bestCard = -1;
   float bestCardValue = -1.0;
   int unitType = -1;           // The first unit the card ships, WARNING we can't properly handle cards that send multiple units.
   int unitCount = -1;          // How many units get delivered by this card.
   int cardAgePreReq = -1;      // What age do you need to use this card.
   int tech = -1;               // The techID for this card.
   int cardFlags = 0;           // The flags for this card.
   float totalValue = -1.0;     // What is this card worth to me?
   float woodValue = -1.0;
   float foodValue = -1.0;
   float goldValue = -1.0;
   float influenceValue = -1.0;
   bool isMilitaryUnit = false;
   float bankedTotalResources = kbResourceGet(cResourceFood) + kbResourceGet(cResourceWood) +
                                kbResourceGet(cResourceGold) + kbResourceGet(cResourceInfluence);
   int landUnitPickPrimary = kbUnitPickGetResult(gLandUnitPicker, 0);
   int landUnitPickSecondary = kbUnitPickGetResult(gLandUnitPicker, 1);
   int planID = -1;
   int totalCards = 0;
   bool extended = false;
   int deck = -1;
   int numberTCs = 0;
   int age = kbGetAge();

   // USA and MX Federal State cards are in the extended deck so also loop over that deck.
   for (deckIndex = 0; < 2)
   {
      deck = -1;
      extended = false;

      if (deckIndex == 0) // First iteration, standard decks are in here.
      {
         deck = gDefaultDeck;
         extended = false;
      }
      else // Look for an extended deck (Federal Cards).
      {
         if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans))
         {
            deck = aiHCGetExtendedDeck(); // This only return something >= 0 for USA / MX.
            extended = true;
         }
         else // We don't have an extended deck.
         {
            continue; 
         }
      }

      if (deck < 0)
      {
         debugHCCards("WARNING shipGrantedHandler couldn't find a valid deck this iteration: " + deck);
         continue;  
      }
      
      totalCards = aiHCDeckGetNumberCards(deck);
      for (i = 0; < totalCards)
      {
         // Skip card if we can't play it (basically we already sent it or we're not in the right age).
         if (aiHCDeckCanPlayCard(i, extended) == false)
         {
            continue;
         }
         cardFlags = aiHCDeckGetCardFlags(deck, i);
         unitType = aiHCDeckGetCardUnitType(deck, i); // The first unit the card ships,
                                                      // WARNING we can't properly handle cards that send multiple units.
         unitCount = aiHCDeckGetCardUnitCount(deck, i); // This does fetch the total amount of units.
         cardAgePreReq = aiHCDeckGetCardAgePrereq(deck, i);
         tech = aiHCDeckGetCardTechID(deck, i);
         totalValue = 0.0;

         // The value determining process is split into two parts.
         // Part 1: we switch on the unitType associated with the card. We handle some specific unit types, but that's a minority.
         // If we couldn't find a handled unit type on the card it goes to the default statement. There we assign a value to the card
         // based on its hard value (value of units it ships) / cost. At this point any card that for example increases infantry hitpoints 
         // by 10% will still have no value since it has no hard value and no cost. 
         // In the default case we then assign a value to cards we specifically want to give a custom value (overwrite the hard value calculation).
         // If by the end of the default case the card still has no value we give it a default value based on the age it belongs to.
         // Part 2: now after the switch we modify the found (or defaulted) value based on very general conditions.
         // For example a food gather rate card can have its value increased if we have a lot of gatherers on food.
         // Or a military card can have its value increased if our base is under attack.
         // But we may also adjust values of specific cards again. The ONLY reason we would do that here is if we want the card
         // to first get its default value and then adjust that default value.
         switch (unitType)
         {
            case gGalleonUnit:
            {  // AssertiveWall: Naval unit shipments are rated more valuable on island maps
               // all ship unit shipments are adjusted for value
               if ((gGalleonMaintain >= 0) &&
                   (aiPlanGetVariableInt(gGalleonMaintain, cTrainPlanNumberToMaintain, 0) >
                    kbUnitCount(cMyID, gGalleonUnit, cUnitStateABQ)))
               {
                  if (gStartOnDifferentIslands == true)
                  {  // AssertiveWall: Galleon shipment regarded as more valuable if there are enemy towers
                     int enTowerCount = kbUnitCount(cPlayerRelationEnemyNotGaia, gTowerUnit, cUnitStateAlive);
                     if (enTowerCount > 1)
                     {
                        totalValue = 1.6 * enTowerCount * getUnitCardNetValue(deck, i , tech);
                     }
                     else
                     {
                        totalValue = 1.20 * getUnitCardNetValue(deck, i , tech);
                     }
                  }
                  else
                  {
                     totalValue = getUnitCardNetValue(deck, i , tech);
                  } 
               }
               break;
            }
            case gCaravelUnit:
            {
               if (gStartOnDifferentIslands == true && age == cAge2)
               {
                  totalValue = 100.0 * getUnitCardNetValue(deck, i , tech);
               }
               else if ((gCaravelMaintain >= 0) &&
                   (aiPlanGetVariableInt(gCaravelMaintain, cTrainPlanNumberToMaintain, 0) >
                    kbUnitCount(cMyID, gCaravelUnit, cUnitStateABQ)))
               {  // AssertiveWall: Caravels are even more valuable
                  if (gStartOnDifferentIslands == true)
                  {
                     totalValue = 1.35 * getUnitCardNetValue(deck, i , tech);
                  }
                  else
                  {
                     totalValue = getUnitCardNetValue(deck, i , tech);
                  } 
               }
               break;
            }
            case gFrigateUnit:
            {
               if ((gFrigateMaintain >= 0) &&
                   (aiPlanGetVariableInt(gFrigateMaintain, cTrainPlanNumberToMaintain, 0) >
                    kbUnitCount(cMyID, gFrigateUnit, cUnitStateABQ)))
               {
                  if (gStartOnDifferentIslands == true)
                  {
                     totalValue = 1.25 * getUnitCardNetValue(deck, i , tech);
                  }
                  else
                  {
                     totalValue = getUnitCardNetValue(deck, i , tech);
                  } 
               }
               break;
            }
            case gMonitorUnit:
            {
               if ((gMonitorMaintain >= 0) &&
                   (aiPlanGetVariableInt(gMonitorMaintain, cTrainPlanNumberToMaintain, 0) >
                    kbUnitCount(cMyID, gMonitorUnit, cUnitStateABQ)))
               {
                  if (gStartOnDifferentIslands == true)
                  {
                     totalValue = 1.05 * getUnitCardNetValue(deck, i , tech);
                  }
                  else
                  {
                     totalValue = getUnitCardNetValue(deck, i , tech);
                  } 
               }
               break;
            }
            case gFishingUnit:
            {
               if (gTimeToFish == false)
               {
                  totalValue = 1.0;
               }
               else if (cvOkToFish == true)
               {
                  totalValue = getUnitCardNetValue(deck, i , tech);
               }
               break;
            }
            case cUnitTypeCoveredWagon:
            {
               numberTCs = kbUnitCount(cMyID, cUnitTypeAgeUpBuilding, cUnitStateAlive);
               if (numberTCs < 1)
               {
                  totalValue = 100000.0; // Trumps everything.
               }
               else if (kbTechGetStatus(cTechDERevolutionBrazil) == cTechStatusActive)
               {
                  if (numberTCs < 5)
                  {
                     totalValue = 2000.0;
                  }
               }
               else
               {
                  int tcTarget = 1;
                  if (age >= cAge3)
                  {
                     tcTarget = 2;
                     if (cMyCiv == cCivOttomans)
                     {
                        tcTarget = 3;
                     }
                  }
                  if (tech == cTechDEHCHuankaSupport)
                  {
                     tcTarget++;
                     unitCount = 1;
                  }
                  else if (tech == cTechDEHCResettlements)
                  {
                     unitCount = 1;
                  }
                  if ((numberTCs < tcTarget) && (homeBaseUnderAttack == false))
                  {
                     totalValue = 1600.0 * unitCount;
                  }
                  else if ((numberTCs < kbGetBuildLimit(cMyID, cUnitTypeAgeUpBuilding)) &&
                     (homeBaseUnderAttack == false))
                  {
                     totalValue = 400.0 * unitCount;
                  }
               }
               break;
            }
            case cUnitTypeOutpostWagon:
            {
               if ((kbUnitCount(cMyID, cUnitTypeOutpostWagon, cUnitStateABQ) +
                   kbUnitCount(cMyID, cUnitTypeOutpost, cUnitStateAlive)) < gNumTowers)
               {
                  totalValue = 600.0 * unitCount;
               }
               if (homeBaseUnderAttack == true)
               {
                  totalValue = 0.0;
               }
               break;
            }
            case cUnitTypeYPCastleWagon:
            {
               if ((kbUnitCount(cMyID, cUnitTypeYPCastleWagon, cUnitStateABQ) +
                   kbUnitCount(cMyID, cUnitTypeypCastle, cUnitStateAlive)) < gNumTowers)
               {
                  totalValue = 900.0 * unitCount;
               }
               if (homeBaseUnderAttack == true)
               {
                  totalValue = 0.0;
               }
               break;
            }
            case cUnitTypeFortWagon:
            {
               if ((homeBaseUnderAttack == false) &&
                   (kbUnitCount(cMyID, cUnitTypeFortFrontier, cUnitStateABQ) +
                    kbUnitCount(cMyID, cUnitTypeFortWagon, cUnitStateAlive) < 1))
               {
                  totalValue = 5000.0; // Big, but smaller than TC wagon.
               }
               break;
            }
            case cUnitTypeFactoryWagon:
            {
               if (homeBaseUnderAttack == false)
               {
                  totalValue = 2000.0 * unitCount; // Big, but smaller than TC/Fort wagon.
               }
               break;
            }
            case cUnitTypexpMedicineManAztec:
            {
               // 3 Warrior Priests card should be lower than crates and Villagers.
               totalValue = 200.0 * unitCount;
               if (homeBaseUnderAttack == true)
               {
                  totalValue = 1.0;
               }
               break;
            }
            default: 
            {
               // This totalValue may be instantly overwritten again if it's a card we specifically handle below.
               // But if it's not overwritten than this will be the final value inside this default case.
               woodValue = aiHCDeckGetCardValuePerResource(deck, i, cResourceWood) -
                           kbTechCostPerResource(tech, cResourceWood);
               foodValue = aiHCDeckGetCardValuePerResource(deck, i, cResourceFood) -
                           kbTechCostPerResource(tech, cResourceFood);
               goldValue = aiHCDeckGetCardValuePerResource(deck, i, cResourceGold) -
                           kbTechCostPerResource(tech, cResourceGold);
               influenceValue = aiHCDeckGetCardValuePerResource(deck, i, cResourceInfluence) -
                                kbTechCostPerResource(tech, cResourceInfluence);
               totalValue = woodValue + foodValue + goldValue + influenceValue;

               // Handle 'Northern Refugees' (Chinese).
               if ((tech == cTechYPHCSpawnRefugees1) || (tech == cTechYPHCSpawnRefugees2) || (tech == cTechYPHCSpawnMigrants1))
               {
                  numberTCs = kbUnitCount(cMyID, cUnitTypeAgeUpBuilding, cUnitStateAlive);
                  if ((age == cAge1) && (tech == cTechYPHCSpawnRefugees1) && (numberTCs >= 1))
                  {
                     totalValue = 5000.0; // Send this card first.
                  }
                  else if ((homeBaseUnderAttack == false) && ((numberTCs >= 1) || (numberTCs >= 1)))
                  {
                     unitCount = numberTCs + kbUnitCount(cMyID, cUnitTypeypVillage, cUnitStateAlive);
                     if (unitCount >= 2)
                     {
                        totalValue = 165 * unitCount;
                     }
                     if ((age >= cAge2) || (econBias > 1.0))
                     {
                        totalValue = totalValue * econBias; // Boomers prefer this, rushers rather skip.
                     }
                     if (getSettlerShortfall() < unitCount) // We have enough Villagers.
                     {
                        totalValue = 190.0;
                     }
                  }
                  else
                  {
                     totalValue = 1.0;
                  }
               }
               else if (((unitType == cUnitTypeypSettlerIndian) || (unitType == cUnitTypedeChasqui)) &&
                        (unitCount == 1) &&
                        (totalValue < 200.0))
               {
                  totalValue = 0.0; // Avoid rating upgrades too low because it'd base the value on the free unit instead of buffing later.
               }
               // Handle all Villager cards not handled above.
               else if ((cardFlags & cHCCardFlagVillager) == cHCCardFlagVillager)
               {
                  totalValue = totalValue * 1.65; // Make sure we send Villagers early to get the most value out of them.
                  if ((age >= cAge2) || (econBias > 1.0))
                  {
                     totalValue = totalValue * econBias; // Boomers prefer this, rushers rather skip (except in age 1).
                  }
                  if (getSettlerShortfall() < unitCount) // We have enough Settlers.
                  {
                     totalValue = 190.0;
                  }
                  if (homeBaseUnderAttack == true)
                  {
                     totalValue = 1.0;
                  }
                  if ((age == cAge1) && (cardAgePreReq == cAge1))
                  {
                     totalValue = 5000.0; // Send these cards first. 
                  }
               }
               
               // Handle resource crates.
               if ((cardFlags & cHCCardFlagResourceCrate) == cHCCardFlagResourceCrate)
               { 
                  if (bankedTotalResources >= 10000) // If we have a lot of resources already reduce the value.
                  {
                     totalValue = totalValue / 2.0;
                  }
                  else if (homeBaseUnderAttack == true)
                  {
                     totalValue = 1.0;
                  }
                  else if (influenceValue > 0.0)
                  {
                     if (kbUnitCount(cMyID, cUnitTypeNativeEmbassy, cUnitStateAlive) +
                         kbUnitCount(cMyID, cUnitTypedePalace, cUnitStateAlive) > 0)
                     {
                        totalValue -= 0.2; // Put it lower than other crates that deliver the same amount.
                     }
                     else
                     {
                        totalValue = 1.0;
                     }
                  }
                  else
                  {
                     int mostResource = cResourceWood;
                     if ((woodValue < foodValue) || (woodValue < goldValue))
                     {
                        if (foodValue < goldValue)
                        {
                           mostResource = cResourceGold;
                        }
                        else
                        {
                           mostResource = cResourceFood;
                        }
                     }
                     for (j = cResourceGold; <= cResourceFood)
                     {
                        // Prioritize resources as appropriate.
                        if (xsArrayGetFloat(gRawResourcePercentages, mostResource) < xsArrayGetFloat(gRawResourcePercentages, j))
                        {
                           totalValue -= 0.1;
                        }
                     }
   
                     if (gRevolutionType != 0)
                     {
                        if (xsArrayGetFloat(gResourceNeeds, mostResource) > 0.0)
                        {
                           totalValue = totalValue * 1.1;
                        }
                     }
                  }
               }
               
               // Handle 'Advanced Trading Post' and 'Advanced Tambos'.
               if ((tech == cTechHCAdvancedTradingPost) ||
                   (tech == cTechDEHCAdvancedTambos))
               {  
                  if ((homeBaseUnderAttack == false) && (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) >= 1))
                  {
                     totalValue = 1000.0;
                  }
                  else
                  {
                     totalValue = 1.0;
                  }
               }
               
               // Handle all cards that improve native warriors.
               if (((tech == cTechHCXPBloodBrothers) || (tech == cTechHCXPBloodBrothersGerman) ||
                  (tech == cTechHCNativeWarriors) || (tech == cTechHCNativeWarriorsGerman) ||
                  (tech == cTechHCWildernessWarfare) || (tech == cTechHCNativeCombat) ||
                  (tech == cTechYPHCNativeTradeTax) || (tech == cTechYPHCNativeTradeTaxIndians) ||
                  (tech == cTechYPHCNativeLearning) || (tech == cTechYPHCNativeLearningIndians) ||
                  (tech == cTechYPHCNativeDamage) || (tech == cTechYPHCNativeDamageIndians) ||
                  (tech == cTechYPHCNativeHitpoints) || (tech == cTechYPHCNativeHitpointsIndians) ||
                  (tech == cTechYPHCNativeIncorporation) || (tech == cTechYPHCNativeIncorporationIndians) ||
                  (tech == cTechHCXPBlackArrow) || (tech == cTechHCNativeChampionsDutchTeam) ||
                  (tech == cTechYPHCNativeIncorporation) || (tech == cTechYPHCNativeIncorporationIndians) ||
                  (tech == cTechDEHCIndianFriendshipMexican) || (tech == cTechDEHCShotgunMessengers)) &&
                  (xsArrayGetSize(kbVPSiteQuery(cVPNative, cMyID, cVPStateCompleted)) < 1))
               {
                  totalValue = 1.0; // Makes no sense to send these when we have no alive Native Trading Posts.
               }                    // Otherwise default the value based on age because the cards aren't really good.
                  
               if ((tech == cTechDEHCCequeSystem) && (kbUnitCount(cMyID, cUnitTypeTradingPost, cUnitStateAlive) < 1))
               {
                  totalValue = 1.0;
               }
   
               if ((tech == cTechHCAdvancedArsenal) || (tech == cTechHCAdvancedArsenalGerman))
               {
                  if ((homeBaseUnderAttack == true) || (kbUnitCount(cMyID, cUnitTypeArsenal, cUnitStateAlive) < 1))
                  {
                     totalValue = 1.0;
                  }
                  else if (age >= cAge3)
                  {
                     totalValue = 1305.0; // High priority in age3, default otherwise.
                     if (cMyCiv == cCivGermans)
                     {
                        totalValue = 1745.0; // Necessary to cope with Uhlans being included in calculation.
                     }
                  }
               }
               
               if (tech == cTechHCXPNewWaysIroquois)
               { 
                  if ((homeBaseUnderAttack == true) || (kbUnitCount(cMyID, cUnitTypeLonghouse, cUnitStateAlive) < 1))
                  {
                     totalValue = 1.0;
                  }
                  else if (age >= cAge3)
                  {
                     totalValue = 1300.0; // High priority in age3, default otherwise.
                  }
               }

               if (tech == cTechHCXPNewWaysSioux)
               { 
                  if ((homeBaseUnderAttack == true) || (kbUnitCount(cMyID, cUnitTypeTeepee, cUnitStateAlive) < 1))
                  {
                     totalValue = 1.0;
                  }
                  else if (age >= cAge3)
                  {
                     totalValue = 1300.0; // High priority in age3, default otherwise.
                  }
               }
               
               if ((tech == cTechDEHCMachuPicchu) && (homeBaseUnderAttack == false))
               {
                  totalValue = 2500.0; // Big, but smaller than Fort Wagon.
               }

               // This is not perfect for lower difficulties but it's something.
               if ((cMyCiv == cCivOttomans) && (tech == cTechHCMosqueConstruction))
               {
                  if ((kbUnitCount(cMyID, cUnitTypeChurch, cUnitStateABQ) >= 1) &&
                      (kbTechGetStatus(cTechChurchAbbassidMarket) != cTechStatusActive) &&
                      (kbTechGetStatus(cTechChurchTanzimat) != cTechStatusActive))
                  {
                     totalValue = 5.0; // Medium priority
                  }
                  else
                  {
                     totalValue = 1.0;
                  }
               }

               if ((tech == cTechHCBanks1) || (tech == cTechHCBanks2))
               {
                  // We need to increase BL of either.
                  if ((kbUnitCount(cMyID, cUnitTypeBank, cUnitStateAlive) >= kbGetBuildLimit(cMyID, cUnitTypeBank)) || 
                      (kbUnitCount(cMyID, cUnitTypeSettler, cUnitStateAlive) >= kbGetBuildLimit(cMyID, cUnitTypeSettler))) 
                  {
                     totalValue = 1510.0;
                  }
                  else
                  {
                     totalValue = 1.0;
                  }
               }
   
               if ((tech == cTechHCGermantownFarmers) && (gTimeToFarm == false))
               {
                  totalValue = 1.0;
               }
               
               if (tech == cTechDEHCEngelsbergIronworks)
               {
                  int torpQuery = createSimpleUnitQuery(cUnitTypedeTorp, cMyID, cUnitStateABQ);
                  int numberTorps = kbUnitQueryExecute(torpQuery);
                  int numberTorpsOnMine = 0;
                  for (j = 0; < numberTorps)
                  {
                     int torpID = kbUnitQueryGetResult(torpQuery, j);
                     if (getUnitCountByLocation(cUnitTypeAbstractMine, 0, cUnitStateAny, kbUnitGetPosition(torpID), 10.0) > 0)
                     {
                        numberTorpsOnMine = numberTorpsOnMine + 1;
                     }
                  }
                  totalValue = 90.0 * numberTorpsOnMine;
               }
   
               if (tech == cTechDEHCFedCulpeperMinutemen)
               {
                  if (homeBaseUnderAttack == true)
                  {
                     totalValue = 80.0 * 1.5 * kbUnitCount(cMyID, cUnitTypeTownCenter, cUnitStateAlive);
                  }
                  else
                  {
                     totalValue = 1.0;
                  }
               }
   
               if (tech == cTechDEHCGidanSarkin)
               {
                  if (homeBaseUnderAttack == true)
                  {
                     totalValue = 1.0;
                  }
                  else if (cDifficultyCurrent >= cDifficultyHard)
                  {
                     totalValue = 1400.0;
                  }
                  else
                  {
                     totalValue = 650.0;
                  }
               }
   
               if (tech == cTechDEHCFedBostonTeaParty)
               {
                  totalValue = 1.0;
               }
   
               // Revolution cards.
               if (gRevolutionType != 0)
               {
                  if ((gRevolutionType & cRevolutionMilitary) == cRevolutionMilitary)
                  {
                     if ((tech == cTechDEHCREVDhimma) || (tech == cTechDEHCREVCitizenship) || (tech == cTechDEHCREVCitizenshipOutpost) ||
                         (tech == cTechDEHCREVAcehExports) || (tech == cTechDEHCREVMinasGerais) || (tech == cTechDEHCREVSalitrera))
                     {
                        // We are running out of resources, send the citizenship shipment to restore our economy.
                        if ((xsArrayGetFloat(gResourceNeeds, cResourceFood) > -1000.0) ||
                            (xsArrayGetFloat(gResourceNeeds, cResourceWood) > -1000.0) ||
                            (xsArrayGetFloat(gResourceNeeds, cResourceGold) > -1000.0))
                        {
                           totalValue = 3000.0;
                        }
                        else
                        {
                           totalValue = 1.0;
                        }
                     }
                  }
                  if (tech == cTechDEHCREVNothernWilderness)
                  {
                     // We are running out of resources, send the "citizenship" shipment to restore our economy.
                     if ((xsArrayGetFloat(gResourceNeeds, cResourceFood) > -1000.0) ||
                         (xsArrayGetFloat(gResourceNeeds, cResourceGold) > -1000.0))
                     {
                        totalValue = 3000.0;
                     }
                     else
                     {
                        totalValue = 1.0;
                     }
                  }
                  if (tech == cTechDEHCREVTurkuAcademy)
                  {
                     totalValue = 1.0;
                  }
                  if (tech == cTechDEHCREVBlackberries)
                  {
                     totalValue = 115.0 * kbUnitCount(cMyID, gHouseUnit, cUnitStateAlive);
                  }
                  if (tech == cTechDEHCREVShipXhosaFoods)
                  {
                     totalValue = 900.0; // Exclude the herdables.
                  }
                  if (tech == cTechDEHCREVHuguenots)
                  {
                     totalValue = 1.0; // Allow coureurs to be trained, we don't have logic for this card.
                  }
                  if (tech == cTechDEHCREVShipHomesteadWagons)
                  {
                     if (((aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gFarmUnit) >= 0) ||
                          (aiPlanGetIDByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gPlantationUnit) >= 0)) &&
                         (xsArrayGetFloat(gResourceNeeds, cResourceWood) >= 600.0))
                     {
                        totalValue = 2000.0;
                     }
                  }
               }
               
               // Set a minimum value based on age prerequisite if the card hasn't been processed above.
               if (totalValue < 1.0)
               { 
                  if (gRevolutionType == 0)
                  {
                     switch (cardAgePreReq)
                     {
                        case cAge1:
                        {
                           totalValue = 200.0;
                           break;
                        }
                        case cAge2:
                        {
                           totalValue = 450.0;
                           break;
                        }
                        case cAge3:
                        {
                           totalValue = 750.0;
                           break;
                        }
                        case cAge4:
                        {
                           totalValue = 1100.0;
                           break;
                        }
                        case cAge5:
                        {
                           totalValue = 1100.0;
                           break;
                        }
                     }
                  }
                  else
                  {
                     totalValue = 1500.0;
                  }
               }
               break;
            }
         } // End of the switch on unit type, all cards go through the following logic.
         
         if (tech == cTechDEHCDominions && (needMoreHouses() == true))
         {
            totalValue = totalValue * 1.1;
         }

         float maxDistance = kbBaseGetMaximumResourceDistance(cMyID, mainBaseID);
         
         // Handle cards which ship the food resource (not crates) to delay our time to start farming.
         if ((gTimeToFarm == false) &&
             ((kbProtoUnitIsType(cMyID, unitType, cUnitTypeHuntable) == true) || (unitType == cUnitTypeYPBerryWagon1)))
         {
            int foodAmount = 0;
            if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
            {
               foodAmount = kbGetAmountValidResources(mainBaseID, cResourceFood, cAIResourceSubTypeEasy, maxDistance);
               foodAmount = foodAmount + (kbUnitCount(cMyID, cUnitTypeYPBerryWagon1, cUnitStateAlive) +
                                          kbUnitCount(cMyID, cUnitTypeypBerryBuilding, cUnitStateBuilding)) * 5000.0;
            }
            else
            {
               foodAmount = kbGetAmountValidResources(mainBaseID, cResourceFood, cAIResourceSubTypeHunt, maxDistance);
            }
            
            float percentOnFood = xsArrayGetFloat(gRawResourcePercentages, cResourceFood);
            int numFoodGatherers = percentOnFood * aiGetCurrentEconomyPop();
            if (numFoodGatherers < 1)
            {
               numFoodGatherers = 1;
            }
            int foodPerGatherer = foodAmount / numFoodGatherers;
            if (foodPerGatherer < 300)
            {
               totalValue = totalValue * 1.2;
            }
         }
         
         // Handle cards which ship the gold resource (not crates) to delay our time to start plantations.
         if ((gTimeForPlantations == false) &&
             ((unitType == cUnitTypedeProspectorWagon) || (unitType == cUnitTypedeProspectorWagonGold) ||
              (unitType == cUnitTypedeProspectorWagonSilver) || (unitType == cUnitTypedeProspectorWagonCoal) ||
              (unitType == cUnitTypedeREVProspectorWagon)))
         {
            int goldAmount = kbGetAmountValidResources(mainBaseID, cResourceGold, cAIResourceSubTypeEasy, maxDistance);
            float percentOnGold = xsArrayGetFloat(gRawResourcePercentages, cResourceGold);
            int numGoldGatherers = percentOnGold * kbUnitCount(cMyID, gEconUnit, cUnitStateAlive);

            goldAmount = goldAmount + (kbUnitCount(cMyID, cUnitTypedeProspectorWagon, cUnitStateAlive) +
                                       kbUnitCount(cMyID, cUnitTypedeProspectorWagonGold, cUnitStateAlive) +
                                       kbUnitCount(cMyID, cUnitTypedeProspectorWagonSilver, cUnitStateAlive) +
                                       kbUnitCount(cMyID, cUnitTypedeProspectorWagonCoal, cUnitStateAlive)) * 2000.0;
            goldAmount = goldAmount + kbUnitCount(cMyID, cUnitTypedeREVProspectorWagon, cUnitStateAlive) * 100000.0;

            if (numGoldGatherers < 1)
            {
               numGoldGatherers = 1;
            }
            int goldPerGatherer = goldAmount / numGoldGatherers;
            if (goldPerGatherer < 300)
            {
               totalValue = totalValue * 1.2;
            }
         }
         
         // Handle cards which ship the wood resource (not crates) to delay our time to start buying wood.
         if ((unitType == cUnitTypeYPGroveWagon) ||
            ((tech == cTechDEHCREVTreeSpawn) &&
             (kbUnitCount(cMyID, cUnitTypeHouseEast, cUnitStateAlive) + kbUnitCount(cMyID, gHouseUnit, cUnitStateAlive) +
              kbUnitCount(cMyID, cUnitTypeBlockhouse, cUnitStateAlive) > 15)))
         {
            int woodAmount = kbGetAmountValidResources(mainBaseID, cResourceWood, cAIResourceSubTypeEasy, maxDistance);
            float percentOnWood = xsArrayGetFloat(gRawResourcePercentages, cResourceWood);
            int numWoodGatherers = percentOnWood * kbUnitCount(cMyID, gEconUnit, cUnitStateAlive);
            woodAmount = woodAmount + (kbUnitCount(cMyID, cUnitTypeYPGroveWagon, cUnitStateAlive) +
                                       kbUnitCount(cMyID, cUnitTypeypGroveBuilding, cUnitStateBuilding)) * 5000.0;
            if (numWoodGatherers < 1)
            {
               numWoodGatherers = 1;
            }
            int woodPerGatherer = woodAmount / numWoodGatherers;
            if (woodPerGatherer < 300)
            {
               totalValue = totalValue * 1.2;
            }
         }

         isMilitaryUnit = (((cardFlags & cHCCardFlagMilitary) == cHCCardFlagMilitary) &&
                           ((cardFlags & cHCCardFlagUnit) == cHCCardFlagUnit) && ((cardFlags & cHCCardFlagWater) == 0)) ||
                           (kbProtoUnitIsType(cMyID, unitType, cUnitTypeLogicalTypeLandMilitary));
         
         if ((age < cAge3) && (isMilitaryUnit == true) && (homeBaseUnderAttack == false))
         {
            totalValue = totalValue / econBias; // Decrease value of military unit for boomer.
         }
         // AssertiveWall: Don't send military units on island maps if we aren't under attack
         if ((gStartOnDifferentIslands == true && isMilitaryUnit == true) && 
            (homeBaseUnderAttack == false))
         {
            if (age < cAge4)
            {  // AssertiveWall: Basically never do it before age 4
               totalValue = totalValue * 0.1;
            }
            else
            {  // AssertiveWall: Discourage it even in age 4
               totalValue = totalValue * 0.8;
            }
         }
         // AssertiveWall: reduce time from 10 minutes to 5 minutes
         if ((aiTreatyGetEnd() > xsGetTime() + 5 * 60 * 1000) && (isMilitaryUnit == true))
         {
            totalValue = 0.1; // Wait with unit shipments until treaty is < 10 minutes from ending.
         }
         
         bool(int, int, int, int) isAffectingUnitPick = [](int unitPickIndex = -1, int unitType = -1, int cardFlags = 0, int tech = -1) -> bool
         {
            return ((unitPickIndex >= 0) && 
                    (((unitType >= 0) && (unitType == unitPickIndex)) ||
                      (((cardFlags & cHCCardFlagTrainPoints) == 0) &&
                      (kbTechAffectsUnit(tech, unitPickIndex) == true) &&
                      ((kbUnitCount(cMyID, unitPickIndex, cUnitStateABQ) *
                      (kbUnitCostPerResource(unitPickIndex, cResourceGold) +
                       kbUnitCostPerResource(unitPickIndex, cResourceWood) +
                       kbUnitCostPerResource(unitPickIndex, cResourceFood) +
                       kbUnitCostPerResource(unitPickIndex, cResourceInfluence))) > 1000.0))));
         };
         
         if (isAffectingUnitPick(landUnitPickPrimary, unitType, cardFlags, tech) == true)
         {
            totalValue = totalValue * 1.4; // It's affecting what we're trying to train with highest priority.
         }
         else if (isAffectingUnitPick(landUnitPickSecondary, unitType, cardFlags, tech) == true)
         {
            totalValue = totalValue * 1.2; // It's affecting what we're trying to train with 2nd highest priority.
         }
         
         // Handle cards which should be sent early, for their respective age, for best value.
         if (((cardFlags & cHCCardFlagTrickleGold) == cHCCardFlagTrickleGold) ||
             ((cardFlags & cHCCardFlagTrickleWood) == cHCCardFlagTrickleWood) ||
             ((cardFlags & cHCCardFlagTrickleFood) == cHCCardFlagTrickleFood) ||
             ((cardFlags & cHCCardFlagTrickleXP) == cHCCardFlagTrickleXP) ||
             ((cardFlags & cHCCardFlagTrickleTrade) == cHCCardFlagTrickleTrade) ||
             (tech == cTechDEHCChichaBrewing) || (tech == cTechHCXPBankWagon) ||
             (tech == cTechHCBetterBanks) || (tech == cTechHCXPAdoption) ||
             (tech == cTechHCXPSpanishGold) || (tech == cTechHCXPOldWaysIroquois) ||
             (tech == cTechHCXPOldWaysSioux) || (tech == cTechHCXPOldWaysAztec) ||
             (tech == cTechDEHCOldWaysInca))
         {
            totalValue = totalValue * 2.3;
         }
         
         // Handle cards which changes gather rate.
         if (((cardFlags & cHCCardFlagGatherRate) == cHCCardFlagGatherRate) &&
             (kbTechAffectsUnit(tech, cUnitTypeAbstractVillager) == true))
         {
            static int resourceTypes = -1;
            static int resourceSubTypes = -1;
            if (resourceTypes < 0)
            {
               resourceTypes = xsArrayCreateInt(9, 0, "Resource Types");
               resourceSubTypes = xsArrayCreateInt(9, 0, "Resource Sub Types");

               xsArraySetInt(resourceTypes, 0, cResourceFood);
               xsArraySetInt(resourceSubTypes, 0, cAIResourceSubTypeEasy);
               xsArraySetInt(resourceTypes, 1, cResourceFood);
               xsArraySetInt(resourceSubTypes, 1, cAIResourceSubTypeHunt);
               xsArraySetInt(resourceTypes, 2, cResourceFood);
               xsArraySetInt(resourceSubTypes, 2, cAIResourceSubTypeHerdable);
               xsArraySetInt(resourceTypes, 3, cResourceFood);
               xsArraySetInt(resourceSubTypes, 3, cAIResourceSubTypeFarm);
               xsArraySetInt(resourceTypes, 4, cResourceFood);
               xsArraySetInt(resourceSubTypes, 4, cAIResourceSubTypeFish);
               xsArraySetInt(resourceTypes, 5, cResourceWood);
               xsArraySetInt(resourceSubTypes, 5, cAIResourceSubTypeEasy);
               xsArraySetInt(resourceTypes, 6, cResourceGold);
               xsArraySetInt(resourceSubTypes, 6, cAIResourceSubTypeEasy);
               xsArraySetInt(resourceTypes, 7, cResourceGold);
               xsArraySetInt(resourceSubTypes, 7, cAIResourceSubTypeFarm);
               xsArraySetInt(resourceTypes, 8, cResourceGold);
               xsArraySetInt(resourceSubTypes, 8, cAIResourceSubTypeFish);
            }

            int resourceType = -1;
            int resourceSubType = -1;
            float numResourceGatherers = 0;
            float numGatherers = kbUnitCount(cMyID, cUnitTypeAbstractVillager, cUnitStateAlive);
            for (j = 0; < 9)
            {
               resourceType = xsArrayGetInt(resourceTypes, j);
               resourceSubType = xsArrayGetInt(resourceSubTypes, j);
               numResourceGatherers = aiGetNumberGatherers(cUnitTypeAbstractVillager, resourceType, resourceSubType);
               if (kbTechAffectsWorkRate(tech, resourceType, resourceSubType) == true)
               {
                  if ((numResourceGatherers / numGatherers) >= 0.35)
                  {
                     totalValue = totalValue * 2.3;
                  }
                  else
                  {
                     totalValue = totalValue * 1.1;
                  }
                  // AssertiveWall: Devalue these on treaty games in higher difficulties
                  if (aiTreatyGetEnd() > 5 * 60 * 1000 && cDifficultyCurrent >= cDifficultyHard)
                  {
                     totalValue = totalValue * 0.5;
                  }
                  break;
               }
            }
         }

         // Don't send boat cards when we're ahead on the water.
         // AssertiveWall: Except on island maps. We want to dominate water there
         if ((((cardFlags & cHCCardFlagMilitary) == cHCCardFlagMilitary) && ((cardFlags & cHCCardFlagWater) == cHCCardFlagWater) &&
             (gNetNavyValue < 0.0)) && (gStartOnDifferentIslands == false))
         {
            totalValue = 0.1;
         }
         
         // Slight prefererence for team cards when we have at least one ally (10% per ally).
         if ((cardFlags & cHCCardFlagTeam) == cHCCardFlagTeam)
         {
            totalValue = totalValue * (1.0 + 0.1 * getAllyCount());
         }

         if ((homeBaseUnderAttack == true) && (isMilitaryUnit == true))
         {
            totalValue = totalValue * 1.5; // Prioritize military units when under attack.
         }

         debugHCCards("We gave card " + kbGetTechName(tech) + " a total value of: " + totalValue);

         if (totalValue > bestCardValue)
         {
            bestCardValue = totalValue;
            bestCard = i;
            bestCardIsExtended = extended;
         }
      }
   }
   
   // We're aging up, are not under attack and are not missing any important shipment. Save this shipment for next age.
   if ((agingUp() == true) && (homeBaseUnderAttack == false) && (bestCardValue <= 450.0))
   {
      debugHCCards("We're aging up, delaying this shipment until then");
      return;
   }

   // Don't send more than 1 card in Exploration Age on hard+.
   if (cDifficultyCurrent >= cDifficultyHard)
   {
      static int numberCardsSentDuringAge1 = 0;
      if (age == cAge1)
      {
         if (numberCardsSentDuringAge1 >= 1)
         {
            debugHCCards("We only want 1 card at most during the Exploration Age");
            return;
         }
         numberCardsSentDuringAge1++;
      }
   }
   
   // We call this outside of the upcoming if statement for our debug to have the correct deck.
   if (bestCardIsExtended == false)
   {
      deck = gDefaultDeck;
   }
   else
   {
      deck = aiHCGetExtendedDeck();
   }

   if (bestCard >= 0)
   {
      // Where to drop shipment.
      if (cDifficultyCurrent >= cDifficultyExpert)
      {
         int gatherUnitID = -1;
         cardFlags = aiHCDeckGetCardFlags(deck, bestCard);

         isMilitaryUnit = (((cardFlags & cHCCardFlagMilitary) == cHCCardFlagMilitary) &&
                           ((cardFlags & cHCCardFlagUnit) == cHCCardFlagUnit) && ((cardFlags & cHCCardFlagWater) == 0)) ||
                           (kbProtoUnitIsType(cMyID, unitType, cUnitTypeLogicalTypeLandMilitary));

         if (isMilitaryUnit == true)
         {
            planID = aiPlanGetIDByTypeAndVariableType(cPlanCombat, cCombatPlanCombatType, cCombatPlanCombatTypeAttack);
            if ((planID >= 0) && (aiPlanGetVariableBool(planID, cCombatPlanAllowMoreUnitsDuringAttack, 0) == true))
            {
               if (cMyCiv == cCivJapanese)
               {
                  int daimyoQuery = createSimpleUnitQuery(cUnitTypeAbstractDaimyo, cMyID, cUnitStateAlive);
                  int numDaimyos = kbUnitQueryExecute(daimyoQuery);
                  for (i = 0; < numDaimyos)
                  {
                     int daimyoID = kbUnitQueryGetResult(daimyoQuery, i);
                     if (kbUnitGetPlanID(daimyoID) != planID)
                     {
                        continue;
                     }
                     gatherUnitID = daimyoID;
                  }
               }
               if (gatherUnitID < 0 && gForwardBaseID >= 0)
               {
                  gatherUnitID = findBestHCGatherUnit(gForwardBaseID);
               }
            }
         }

         if (gatherUnitID < 0)
         {
            gatherUnitID = findBestHCGatherUnit(kbBaseGetMainID(cMyID));
         }
         aiSetHCGatherUnit(gatherUnitID);
      }
      debugHCCards("Choosing card: " + kbGetTechName(aiHCDeckGetCardTechID(deck, bestCard)));
      aiHCDeckPlayCard(bestCard, bestCardIsExtended);
   }
}

//==============================================================================
// extraShipMonitor
// Watches for extra shipments... granted in bulk via scenario, or
// due to oversight in shipGrantedHandler()?
//==============================================================================
rule extraShipMonitor
inactive
minInterval 20
{
   if (kbResourceGet(cResourceShips) > 0)
   {
      shipGrantedHandler(); // Spend the surplus.
   }
}