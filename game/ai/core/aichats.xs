//==============================================================================
/* aiChats.xs

   This file is intended for any communication related stuffs, including
   request handling from the chat panel.

*/
//==============================================================================

//==============================================================================
/* sendStatement

   Sends a chat statement, but first checks the control variable. 
   This is a gateway for routine "ambience" personality chats.

   If vector is not cInvalidVector, it will be added as a flare.
*/
//==============================================================================
void sendStatement(int playerIDorRelation = -1, int commPromptID = -1, vector vec = cInvalidVector)
{
   if (cvOkToTaunt == true)
   {
      // It's a player ID, not a relation.
      if (playerIDorRelation < 100)
      {
         int playerID = playerIDorRelation;
         debugChats("Sending AI Chat to player: " + playerID + ", commPromptID: " + commPromptID + ", vector: " + vec); 
         if (vec == cInvalidVector)
         {
            aiCommsSendStatement(playerID, commPromptID);
         }
         else
         {
            aiCommsSendStatementWithVector(playerID, commPromptID, vec);
         }
      }
      else // It's a player relation.
      {
         debugChats("Sending the following chat to all players that are my: " + playerIDorRelation);
         debugChats("PlayerRelationAny = 99999, PlayerRelationEnemy = 100002, " +
            "PlayerRelationAlly = 100001, PlayerRelationEnemyNotGaia = 100004");
         for (int player = 1; player < cNumberPlayers; player++)
         {
            bool send = false;
            
            switch (playerIDorRelation)
            {
               case cPlayerRelationAny:
               {
                  send = true;
                  if (player == cMyID)
                  {
                     send = false;
                  }
                  break;
               }
               case cPlayerRelationSelf:
               {
                  debugChats("WARNING sending a chat to ourselves which is impossible");
                  break;
               }
               case cPlayerRelationAllyExcludingSelf:
               {
                  send = kbIsPlayerAlly(player);
                  if (player == cMyID)
                  {
                     send = false;
                  }
                  break;
               }
               case cPlayerRelationAlly:
               {
                  send = kbIsPlayerAlly(player);
                  if (player == cMyID)
                  {
                     send = false;
                  }
                  debugChats("WARNING sending a chat to allies, should use cPlayerRelationAllyExcludingSelf");
                  break;
               }
               case cPlayerRelationEnemy:
               case cPlayerRelationEnemyNotGaia:
               {
                  send = kbIsPlayerEnemy(player);
                  break;
               }
            }
            if (send == true)
            {
               if (vec == cInvalidVector)
               {
                  aiCommsSendStatement(player, commPromptID);
                  debugChats("Sending AI Chat to player: " + player + ", commPromptID: " + commPromptID);
               }
               else
               {
                  aiCommsSendStatementWithVector(player, commPromptID, vec);
                  debugChats("Sending AI Chat to player: " + player + ", commPromptID: " + commPromptID + ", vector: " + vec);
               }
            }
         }
      }
   }
}

//==============================================================================
// IKnowWhereYouLive
// Send a menacing chat when we discover the enemy player's location.
//==============================================================================
rule IKnowWhereYouLive
inactive
minInterval 5
{
   static int targetPlayer = -1;

   if (targetPlayer < 0)
   {
      targetPlayer = getEnemyPlayerByTeamPosition(getTeamPosition(cMyID)); // Corresponding player on other team.
      if (targetPlayer < 0)
      {
         xsDisableSelf();
         debugChats("No corresponding player on other team, IKnowWhereYouLive is deactivating");
         return;
      }
      debugChats("Rule IKnowWhereYouLive will threaten player #" + targetPlayer);
   }

   int tcID = getUnit(cUnitTypeAgeUpBuilding, targetPlayer, cUnitStateAlive);
   if (tcID >= 0)
   { // We see his TC for the first time.
      if (getUnitByLocation(cUnitTypeUnit, cMyID, cUnitStateAlive, kbUnitGetPosition(tcID), 50.0) >= 0)
      { // I have a unit nearby, presumably I have LOS.
         sendStatement(targetPlayer, cAICommPromptToEnemyISpotHisTC, kbUnitGetPosition(tcID));
      }
      xsDisableSelf();
   }
}

//==============================================================================
// tcChats
// Query for enemy Town Centers and send an appropriate message.
//==============================================================================
rule tcChats
inactive
minInterval 10
{
   static int tcID1 = -1;  // First enemy TC.
   static int tcID2 = -1;  // Second enemy TC.
   static int enemy1 = -1; // ID of owner of first enemy TC.
   static int enemy2 = -1; // ID of owner of Second enemy TC.
   static int secondTCQuery = -1;

   if (tcID1 < 0)
   {
      tcID1 = getUnit(cUnitTypeAgeUpBuilding, cPlayerRelationEnemy, cUnitStateAlive);
      if (tcID1 >= 0)
      {
         enemy1 = kbUnitGetPlayerID(tcID1);
      }
   }

   // If we get here, we already know about one enemy TC.  Now, find the next closest enemy TC.
   if (secondTCQuery < 0)
   { // init - find all enemy TC's within 150 meters of first one.
      secondTCQuery = kbUnitQueryCreate("Second enemy TC");
      kbUnitQuerySetPlayerRelation(secondTCQuery, cPlayerRelationEnemy);
      kbUnitQuerySetUnitType(secondTCQuery, cUnitTypeAgeUpBuilding);
      kbUnitQuerySetState(secondTCQuery, cUnitStateAlive);
      kbUnitQuerySetPosition(secondTCQuery, kbUnitGetPosition(tcID1));
      kbUnitQuerySetMaximumDistance(secondTCQuery, 150.0);
      kbUnitQuerySetAscendingSort(secondTCQuery, true);
   }

   kbUnitQueryResetResults(secondTCQuery);
   int tcCount = kbUnitQueryExecute(secondTCQuery);
   if (tcCount > 1) // Found another enemy TC.
   {
      tcID2 = kbUnitQueryGetResult(secondTCQuery, 1); // Don't grab tcID1 again, so index 1.
      enemy2 = kbUnitGetPlayerID(tcID2);
   }

   if (tcID2 < 0)
   {
      return;
   }

   // We have found the two 2 Town Centers, evaluate if we send a chat or not but don't try again.
   xsDisableSelf();

   if (enemy1 == enemy2)
   {
      return; // Makes no sense to taunt if the same player owns both...
   }
   
   vector tcID1Location = kbUnitGetPosition(tcID1);
   vector tcID2Location = kbUnitGetPosition(tcID2);

   bool haveLOS = false;
   if (getUnitByLocation(cUnitTypeUnit, cPlayerRelationAlly, cUnitStateAlive, tcID1Location, 50.0) >= 0)
   {
      haveLOS = true;
   }
   if (getUnitByLocation(cUnitTypeUnit, cPlayerRelationAlly, cUnitStateAlive, tcID2Location, 50.0) >= 0)
   {
      haveLOS = true;
   }

   if (haveLOS == true)
   {
      float d = distance(tcID1Location, tcID2Location);
      if (d <= 100.0)
      { // Close together.
         sendStatement(enemy1, cAICommPromptToEnemyHisTCNearAlly, tcID2Location);
         sendStatement(enemy2, cAICommPromptToEnemyHisTCNearAlly, tcID1Location);
      }
      if (d > 100.0)
      { // Far apart.
         sendStatement(enemy1, cAICommPromptToEnemyHisTCIsolated, tcID2Location);
         sendStatement(enemy2, cAICommPromptToEnemyHisTCIsolated, tcID1Location);
      }
   } 
   else // Otherwise, rule is turned off, we missed our chance.
   {
      debugChats("Had no LOS of enemy TCs");
   }
}

//==============================================================================
// lateInAge
//==============================================================================
rule lateInAge
minInterval 120
inactive
{
   // This rule is used to taunt a player who is behind in the age race, but only if
   // he is still in the previous age some time (see minInterval) after the other
   // players have all advanced.  Before activating this rule, the calling function
   // (ageUpHandler) must set the global variables for playerID and age,
   // gLateInAgePlayerID and gLateInAgeAge.  When the rule finally fires minInterval
   // seconds later, it checks to see if that player is still behind, and taunts accordingly.

   // Check if he is still in the lowest age.
   if (kbGetAgeForPlayer(gLateInAgePlayerID) == gLateInAgeAge)
   {
      if (gLateInAgeAge == cAge1)
      {
         if (kbIsPlayerAlly(gLateInAgePlayerID) == true)
         {
            sendStatement(gLateInAgePlayerID, cAICommPromptToAllyHeIsAge1Late);
         }
         else if (kbIsPlayerEnemy(gLateInAgePlayerID) == true)
         {
            sendStatement(gLateInAgePlayerID, cAICommPromptToEnemyHeIsAge1Late);
         }
      }
      else
      {
         if (kbIsPlayerAlly(gLateInAgePlayerID) == true)
         {
            sendStatement(gLateInAgePlayerID, cAICommPromptToAllyHeIsStillAgeBehind);
         }
         else if (kbIsPlayerEnemy(gLateInAgePlayerID) == true)
         {
            sendStatement(gLateInAgePlayerID, cAICommPromptToEnemyHeIsStillAgeBehind);
         }
      }
   }
   gLateInAgePlayerID = -1;
   gLateInAgeAge = -1;
   xsDisableSelf();
}

//==============================================================================
// monitorScores
//==============================================================================
rule monitorScores
inactive
minInterval 60
{
   static int startingScores = -1; // Array holding initial scores for each player
   static int highScores = -1;     // Array, each player's high-score mark
   static int teamScores = -1;
   int teamSize = (cNumberPlayers -1) / 2;
   int myTeam = kbGetPlayerTeam(cMyID);
   int enemyTeam = -1;
   int score = -1;
   int firstHumanAlly = -1;

   if (highScores < 0)
   {
      highScores = xsArrayCreateInt(cNumberPlayers, 0, "High Scores"); // Init this below.
   }
   if (startingScores < 0)
   {
      startingScores = xsArrayCreateInt(cNumberPlayers, 0, "Starting Scores"); 
      for (player = 1; < cNumberPlayers)
      {
         score = aiGetScore(player);
         debugChats("Starting score for player: " + player + " is: " + score);
         xsArraySetInt(startingScores, player, score);
         xsArraySetInt(highScores, player, 0); // High scores will track score actual - starting score, to handle Deathmatch better.
      }
   }
   if (teamScores < 0) // Init this below.
   {
      teamScores = xsArrayCreateInt(3, 0, "Team total scores");
   }

   if (firstHumanAlly < 0) // First pass of this Rule.
   {
      for (player = 1; < cNumberPlayers)
      {
         if (kbGetPlayerTeam(player) == myTeam)
         {
            if ((firstHumanAlly < 1) && (kbIsPlayerHuman(player) == true))
            {
               firstHumanAlly = player;
            }
         }
         else if (enemyTeam < 0)
         {
            enemyTeam = kbGetPlayerTeam(player);
         }
      }
   }

   // Bail if earlier than 12 minutes.
   if (xsGetTime() < 12 * 60 * 1000)
   {
      return;
   }

   // We can't win/lose during treaty.
   if (aiTreatyActive() == true)
   {
      return;
   }

   // Update team totals, check for new high scores.
   xsArraySetInt(teamScores, myTeam, 0);
   xsArraySetInt(teamScores, enemyTeam, 0);
   int lowestRemainingScore = 100000; // Very high, will be reset by first real score.
   int lowestRemainingPlayer = -1;
   int highestScore = -1;
   int highestPlayer = -1;

   for (player = 1; < cNumberPlayers)
   {
      if (kbHasPlayerLost(player) == true)
      {
         continue;
      }
      
      score = aiGetScore(player) - xsArrayGetInt(startingScores, player); // Actual score relative to initial score.
      
      if (score < lowestRemainingScore)
      {
         lowestRemainingScore = score;
         lowestRemainingPlayer = player;
      }
      if (score > highestScore)
      {
         highestScore = score;
         highestPlayer = player;
      }
      if (score > xsArrayGetInt(highScores, player))
      {
         xsArraySetInt(highScores, player, score); // Set personal high score.
      }
      if (kbGetPlayerTeam(player) == myTeam)       // Update team scores.
      {
         xsArraySetInt(teamScores, myTeam, xsArrayGetInt(teamScores, myTeam) + score);
      }
      else // Enemy team.
      {
         xsArraySetInt(teamScores, enemyTeam, xsArrayGetInt(teamScores, enemyTeam) + score);
      }
   }

   // Bools used to indicate chat usage, prevent re-use.
   static bool enemyNearlyDead = false;
   static bool enemyStrong = false;
   static bool losingEnemyStrong = false;
   static bool losingEnemyWeak = false;
   static bool losingAllyStrong = false;
   static bool losingAllyWeak = false;
   static bool winningNormal = false;
   static bool winningAllyStrong = false;
   static bool winningAllyWeak = false;

   static int shouldResignCount = 0;         // Set to 1, 2 and 3 as chats are used.
   static int shouldResignLastTime = 420000; // When did I last suggest resigning?  Consider it again 3 min later.
                                             // Defaults to 7 min, so first suggestion won't be until 10 minutes.

   // Attempt to fire chats, from most specific to most general.
   // When we chat, mark that one used and exit for now, i.e no more than one chat per rule execution.

   // Check the winning / losing situations, if it's neither it's a tie.
   bool winning = false;
   bool losing = false;
   float ourAverageScore = (aiGetScore(cMyID) + aiGetScore(firstHumanAlly)) / 2.0;

   // We are winning chats.
   if (xsArrayGetInt(teamScores, myTeam) > (1.20 * xsArrayGetInt(teamScores, enemyTeam)))
   {
      winning = true;

      // Are we winning because my ally rocks?
      if ((winningAllyStrong == false) && (firstHumanAlly == highestPlayer))
      {
         winningAllyStrong = true;
         sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreWinningHeIsStronger);
         return;
      }

      // Are we winning in spite of my weak ally?
      if ((winningAllyWeak == false) && (cMyID == highestPlayer))
      {
         winningAllyWeak = true;
         sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreWinningHeIsWeaker);
         return;
      }

      // OK, we're winning, but neither of us has high score.
      if (winningNormal == false)
      {
         winningNormal = true;
         sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreWinning);
         return;
      }
   }

   // We are losing chats.
   if (xsArrayGetInt(teamScores, myTeam) < (0.70 * xsArrayGetInt(teamScores, enemyTeam)))
   { 
      losing = true;

      // Talk about resigning?
      if ((shouldResignCount < 3) &&
          ((xsGetTime() - shouldResignLastTime) > 3 * 60 * 1000)) // Haven't done it 3 times or within 3 minutes.
      {
         switch (shouldResignCount)
         {
            case 0:
            {
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeShouldResign1);
               break;
            }
            case 1:
            {
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeShouldResign2);
               break;
            }
            case 2:
            {
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeShouldResign3);
               break;
            }
         }
         shouldResignCount++;
         shouldResignLastTime = xsGetTime();
         return;
      }

      // HEADS UP: not all chats were made for each civilization. So let's say
      // we are playing as Germans and we've spotted a weak Hausa. If we then set
      // losingEnemyWeak to true and send cAICommPromptToAllyWeAreLosingEnemyWeakHausa
      // we've wasted our taunt. Because Germans don't have VO for this line.
      // So try to only send a chat when we actually have the VO recorded for it.
      
      // Check for "we are losing but let's kill the weakling"
      if ((losingEnemyWeak == false) && (kbIsPlayerEnemy(lowestRemainingPlayer) == true))
      {
         switch (kbGetCivForPlayer(lowestRemainingPlayer))
         {
            // Legacy Europeans.
            case cCivRussians:
            {
               losingEnemyWeak = true; // chat used.
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakRussian);
               return;
            }
            case cCivFrench:
            {
               losingEnemyWeak = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakFrench);
               return;
            }
            case cCivGermans:
            {
               losingEnemyWeak = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakGerman);
               return;
            }
            case cCivBritish:
            {
               losingEnemyWeak = true; 
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakBritish);
               return;
            }
            case cCivSpanish:
            {
               losingEnemyWeak = true; 
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakSpanish);
               return;
            }
            case cCivDutch:
            {
               losingEnemyWeak = true; 
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakDutch);
               return;
            }
            case cCivPortuguese:
            {
               losingEnemyWeak = true; 
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakPortuguese);
               return;
            }
            case cCivOttomans:
            {
               if ((cMyCiv != cCivGermans) && (cMyCiv != cCivPortuguese) && (cMyCiv != cCivSpanish) && (cMyCiv != cCivDutch))
               {
                  losingEnemyWeak = true; 
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakOttoman);
                  return;
               }
               break;
            }
            // The Warchiefs.
            case cCivXPAztec:
            {
               losingEnemyWeak = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakAztec);
               return;
            }
            case cCivXPSioux:
            {
               if ((civIsDEciv() == true) && (cMyCiv != cCivDEInca))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakSioux);
                  return;
               }
               break;
            }
            case cCivXPIroquois:
            {
               if ((cMyCiv == cCivSpanish) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEEthiopians) ||
                   (cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakIroquois);
                  return;
               }
               break;
            }
            // The Asian Dynasties.
            case cCivJapanese:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakJapanese);
                  return;
               }
               break;
            }
            case cCivChinese:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakChinese);
                  return;
               }
               break;
            }
            case cCivIndians:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakIndian);
                  return;
               }
               break;
            }
            // Definitive Edition.
            case cCivDEInca:
            {
               if (civIsDEciv() == true)
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakInca);
                  return;
               }
               break;
            }
            case cCivDESwedish:
            {
               if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                   (cMyCiv == cCivDEHausa))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakSwedes);
                  return;
               }
               break;
            }
            case cCivDEAmericans:
            {
               if ((cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakAmerican);
                  return;
               }
               break;
            }
            case cCivDEEthiopians:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakEthiopian);
                  return;
               }
               break;
            }
            case cCivDEHausa:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakHausa);
                  return;
               }
               break;
            }
            case cCivDEMexicans:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyWeakMexican);
                  return;
               }
               break;
            }
         }
      }

      // Check for losing while enemy player has high score.
      if ((losingEnemyStrong == false) && (kbIsPlayerEnemy(highestPlayer) == true))
      {
         switch (kbGetCivForPlayer(highestPlayer))
         {
            // Legacy Europeans.
            case cCivRussians:
            {
               losingEnemyStrong = true; // chat used.
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongRussian);
               return;
            }
            case cCivFrench:
            {
               losingEnemyStrong = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongFrench);
               return;
            }
            case cCivGermans:
            {
               if ((civIsAsian() == true) || (civIsDEciv() == true) || (cMyCiv == cCivOttomans))
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongGerman);
                  return;
               }
               break;
            }
            case cCivBritish:
            {
               losingEnemyStrong = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongBritish);
               return;
            }
            case cCivSpanish:
            {
               losingEnemyStrong = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongSpanish);
               return;
            }
            case cCivDutch:
            {
               losingEnemyStrong = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongDutch);
               return;
            }
            case cCivPortuguese:
            {
               losingEnemyStrong = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongPortuguese);
               return;
            }
            case cCivOttomans:
            {
               if ((cMyCiv != cCivBritish) && (cMyCiv != cCivPortuguese))
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongOttoman);
                  return;
               }
               break;
            }
            // The Warchiefs.
            case cCivXPAztec:
            {
               losingEnemyWeak = true;
               sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongAztec);
               return;
            }
            case cCivXPSioux:
            {
               if ((civIsDEciv() == true) && (cMyCiv != cCivDEInca))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongSioux);
                  return;
               }
               break;
            }
            case cCivXPIroquois:
            {
               if ((cMyCiv == cCivXPSioux) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEEthiopians) ||
                   (cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongIroquois);
                  return;
               }
               break;
            }
            // The Asian Dynasties.
            case cCivJapanese:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongJapanese);
                  return;
               }
               break;
            }
            case cCivChinese:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongChinese);
                  return;
               }
               break;
            }
            case cCivIndians:
            {
               if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongIndian);
                  return;
               }
               break;
            }
            // Definitive Edition.
            case cCivDEInca:
            {
               if (civIsDEciv() == true)
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongInca);
                  return;
               }
               break;
            }
            case cCivDESwedish:
            {
               if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                   (cMyCiv == cCivDEHausa))
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongSwedes);
                  return;
               }
               break;
            }
            case cCivDEAmericans:
            {
               if ((cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                   (cMyCiv == cCivDEHausa))
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongAmerican);
                  return;
               }
               break;
            }
            case cCivDEEthiopians:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongEthiopian);
                  return;
               }
               break;
            }
            case cCivDEHausa:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongHausa);
                  return;
               }
               break;
            }
            case cCivDEMexicans:
            {
               if (civIsAfrican() == true)
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingEnemyStrongMexican);
                  return;
               }
               break;
            }
         }
      }

      // If we're here, we're losing but our team has the high score.  If it's my ally, we're losing because I suck.
      if ((losingAllyStrong == false) && (firstHumanAlly == highestPlayer))
      {
         losingAllyStrong = true;
         sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingHeIsStronger);
         return;
      }
      if ((losingAllyWeak == false) && (cMyID == highestPlayer))
      {
         losingAllyWeak = true;
         sendStatement(firstHumanAlly, cAICommPromptToAllyWeAreLosingHeIsWeaker);
         return;
      }
   } // End chats while we're losing.

   if ((winning == false) && (losing == false))
   { 
      // Check for a near-death enemy while the match is even.
      if ((enemyNearlyDead == false) && (kbIsPlayerEnemy(lowestRemainingPlayer) == true))
      {
         if ((lowestRemainingScore * 1.5) < xsArrayGetInt(highScores, lowestRemainingPlayer)) // He's down to 75% of his highscore.
         {
            switch (kbGetCivForPlayer(lowestRemainingPlayer))
            {
               // Legacy Europeans.
               case cCivRussians:
               {
                  enemyNearlyDead = true; // chat used.
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadRussian);
                  return;
               }
               case cCivFrench:
               {
                  enemyNearlyDead = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadFrench);
                  return;
               }
               case cCivBritish:
               {
                  enemyNearlyDead = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadBritish);
                  return;
               }
               case cCivSpanish:
               {
                  enemyNearlyDead = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadSpanish);
                  return;
               }
               case cCivGermans:
               {
                  if (cMyCiv != cCivXPAztec)
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadGerman);
                     return;
                  }
                  break;
               }
               case cCivOttomans:
               {
                  if ((cMyCiv != cCivBritish) && (cMyCiv != cCivPortuguese) && (cMyCiv != cCivOttomans))
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadOttoman);
                     return;
                  }
                  break;
               }
               case cCivDutch:
               {
                  enemyNearlyDead = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadDutch);
                  return;
               }
               case cCivPortuguese:
               {
                  enemyNearlyDead = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadPortuguese);
                  return;
               }
               // The Warchiefs.
               case cCivXPAztec:
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadAztec);
                  return;
               }
               case cCivXPSioux:
               {
                  if (((civIsDEciv() == true) && (cMyCiv != cCivDEInca)) || (cMyCiv == cCivXPIroquois))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadSioux);
                     return;
                  }
                  break;
               }
               case cCivXPIroquois:
               {
                  if ((cMyCiv == cCivXPSioux) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEEthiopians) ||
                     (cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadIroquois);
                     return;
                  }
                  break;
               }
               // The Asian Dynasties.
               case cCivJapanese:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadJapanese);
                     return;
                  }
                  break;
               }
               case cCivChinese:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadChinese);
                     return;
                  }
                  break;
               }
               case cCivIndians:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadIndian);
                     return;
                  }
                  break;
               }
               // Definitive Edition.
               case cCivDEInca:
               {
                  if (civIsDEciv() == true)
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadInca);
                     return;
                  }
                  break;
               }
               case cCivDESwedish:
               {
                  if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                      (cMyCiv == cCivDEHausa))
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadSwedes);
                     return;
                  }
                  break;
               }
               case cCivDEAmericans:
               {
                  if ((cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                      (cMyCiv == cCivDEHausa))
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadAmerican);
                     return;
                  }
                  break;
               }
               case cCivDEEthiopians:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadEthiopian);
                     return;
                  }
                  break;
               }
               case cCivDEHausa:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadHausa);
                     return;
                  }
                  break;
               }
               case cCivDEMexicans:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyNearlyDeadMexican);
                     return;
                  }
                  break;
               }
            }
         }
      }

      // Check for very strong enemy.
      if ((enemyStrong == false) && (kbIsPlayerEnemy(highestPlayer) == true))
      {
         if ((ourAverageScore * 1.3) < highestScore) // Enemy has high score, it's at least 30% above our average.
         { 
            switch (kbGetCivForPlayer(highestPlayer))
            {
               // Legacy Europeans.
               case cCivRussians:
               {
                  enemyStrong = true; // chat used.
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongRussian);
                  return;
               }
               case cCivFrench:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongFrench);
                  return;
               }
               case cCivBritish:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongBritish);
                  return;
               }
               case cCivSpanish:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongSpanish);
                  return;
               }
               case cCivGermans:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongGerman);
                  return;
               }
               case cCivOttomans:
               {
                  if ((cMyCiv != cCivBritish) && (cMyCiv != cCivPortuguese))
                  {
                     enemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongOttoman);
                     return;
                  }
                  break;
               }
               case cCivDutch:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongDutch);
                  return;
               }
               case cCivPortuguese:
               {
                  enemyStrong = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongPortuguese);
                  return;
               }
               // The Warchiefs.
               case cCivXPAztec:
               {
                  losingEnemyWeak = true;
                  sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongAztec);
                  return;
               }
               case cCivXPSioux:
               {
                  if ((civIsDEciv() == true) && (cMyCiv != cCivDEInca))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongSioux);
                     return;
                  }
                  break;
               }
               case cCivXPIroquois:
               {
                  if ((cMyCiv == cCivXPSioux) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEEthiopians) ||
                      (cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongIroquois);
                     return;
                  }
                  break;
               }
               // The Asian Dynasties.
               case cCivJapanese:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongJapanese);
                     return;
                  }
                  break;
               }
               case cCivChinese:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongChinese);
                     return;
                  }
                  break;
               }
               case cCivIndians:
               {
                  if ((civIsAsian() == true) || ((civIsDEciv() == true) && (cMyCiv != cCivDEInca)))
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongIndian);
                     return;
                  }
                  break;
               }
               // Definitive Edition.
               case cCivDEInca:
               {
                  if (civIsDEciv() == true)
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongInca);
                     return;
                  }
                  break;
               }
               case cCivDESwedish:
               {
                  if ((cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                      (cMyCiv == cCivDEHausa))
                  {
                     enemyNearlyDead = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongSwedes);
                     return;
                  }
                  break;
               }
               case cCivDEAmericans:
               {
                  if ((cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEEthiopians) ||
                      (cMyCiv == cCivDEHausa))
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongAmerican);
                     return;
                  }
                  break;
               }
               case cCivDEEthiopians:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongEthiopian);
                     return;
                  }
                  break;
               }
               case cCivDEHausa:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyStrong = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongHausa);
                     return;
                  }
                  break;
               }
               case cCivDEMexicans:
               {
                  if (civIsAfrican() == true)
                  {
                     losingEnemyWeak = true;
                     sendStatement(firstHumanAlly, cAICommPromptToAllyEnemyStrongMexican);
                     return;
                  }
                  break;
               }
            }
         }
      }
   }
}

//==============================================================================
/* firstEnemyUnitSpotted
   We pick a target player by looking at which enemy lies opposite of us.
   We monitor if we see a unit belonging to him, if we do send a message.
*/
//==============================================================================
rule firstEnemyUnitSpotted
inactive
minInterval 5
{
   static int targetPlayer = -1;

   if (targetPlayer < 0)
   {
      targetPlayer = getEnemyPlayerByTeamPosition(getTeamPosition(cMyID)); // Corresponding player on other team.
      if (targetPlayer < 0)
      {
         xsDisableSelf();
         debugChats("No corresponding player on other team, firstEnemyUnitSpotted is deactivating");
         return;
      }
      debugChats("Rule firstEnemyUnitSpotted will watch for player #" + targetPlayer);
   }

   if (kbUnitCount(targetPlayer, cUnitTypeLogicalTypeLandMilitary, cUnitStateAlive) > 0)
   {  // We see one of this player's units for the first time... let's do some analysis on it.
      // Get a random unit of the target player, definitely not guaranteed to be the first we see.
      int unitID = getUnit(cUnitTypeLogicalTypeLandMilitary, targetPlayer, cUnitStateAlive); 

      vector unitPosition = kbUnitGetPosition(unitID);
      // Three tests in priority order....anything near my town, an explorer anywhere, or default.
      if (distance(kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)), unitPosition) < 60.0)
      {
         sendStatement(targetPlayer, cAICommPromptToEnemyISeeHisFirstMilitaryMyTown, unitPosition);
         debugChats("Spotted a unit near my town, so I'm threatening player #" + targetPlayer);
      }
      else if (kbUnitIsType(unitID, cUnitTypeExplorer) == true)
      {
         sendStatement(targetPlayer, cAICommPromptToEnemyISeeHisExplorerFirstTime, unitPosition);
         debugChats("Spotted an enemy explorer, so I'm threatening player #" + targetPlayer);
      }
      else
      {
         sendStatement(targetPlayer, cAICommPromptToEnemyISeeHisFirstMilitary, unitPosition);
         debugChats("Spotted an enemy military unit for the first time, so I'm threatening player #" + targetPlayer);
      }
      xsDisableSelf();
   }
}

//==============================================================================
// Monopoly related chats.
//==============================================================================
void monopolyStartHandler(int teamID = -1)
{
   debugChats("Monopoly started for team: " + teamID);
   if (teamID < 0)
   {
      return;
   }
   // If this is my team, congratulate teammates and taunt enemies.
   if (kbGetPlayerTeam(cMyID) == teamID)
   {
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenWeGetMonopoly);
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenWeGetMonopoly);
   }
   else // Otherwise, snide comment to enemies and condolences to partners.
   {
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenEnemiesGetMonopoly);
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenTheyGetMonopoly);
   }
   gIsMonopolyRunning = true;
   gMonopolyTeam = teamID;
   xsEnableRule("monopolyTimer");
}

void monopolyEndHandler(int teamID = -1)
{
   debugChats("Monopoly ended for team: " + teamID);
   if (teamID < 0)
   {
      return;
   }
   // If this is my team, console partners, and send defiant message to enemies.
   if (kbGetPlayerTeam(cMyID) == teamID)
   {
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyEnemyDestroyedMonopoly);
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyTheyDestroyedMonopoly);
   }
   else
   {
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyIDestroyedMonopoly);
   }
   gIsMonopolyRunning = false;
   gMonopolyTeam = -1;
   xsDisableRule("monopolyTimer");
}

rule monopolyTimer
inactive
minInterval 240 // This means it's now 1 minute until the monopoly completes.
{
   // If this is my team, congratulate teammates and taunt enemies.
   if (kbGetPlayerTeam(cMyID) == gMonopolyTeam)
   {
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAlly1MinuteLeftOurMonopoly);
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemy1MinuteLeftOurMonopoly);
   }
   else // Otherwise, snide comment to enemies and panic to partners.
   {
      sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAlly1MinuteLeftEnemyMonopoly);
      sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemy1MinuteLeftEnemyMonopoly);
   }
}

//==============================================================================
/* getNuggetChatID
   Called from the nugget event handler (nuggetHandler). Given the player ID, determine what
   type of nugget was just claimed, and return a specific appropriate chat ID, if any.

   If none apply, return the general 'got nugget' chat ID.
*/
//==============================================================================

int getNuggetChatID(int playerID = -1)
{
   int retVal = cAICommPromptToEnemyWhenHeGathersNugget;
   int type = aiGetLastCollectedNuggetType(playerID);
   int effect = aiGetLastCollectedNuggetEffect(playerID);

   switch (type)
   {
      case cNuggetTypeAdjustResource:
      {
         switch (effect)
         {
            case cResourceGold:
            {
               retVal = cAICommPromptToEnemyWhenHeGathersNuggetCoin;
               break;
            }
            case cResourceFood:
            {
               retVal = cAICommPromptToEnemyWhenHeGathersNuggetFood;
               break;
            }
            case cResourceWood:
            {
               retVal = cAICommPromptToEnemyWhenHeGathersNuggetWood;
               break;
            }
         }
         break;
      }
      case cNuggetTypeSpawnUnit:
      {
         if (effect == cUnitTypeypMongolScout)
         {
            retVal = cAICommPromptToEnemyWhenHeGathersNuggetNatives;
         }
         if ((effect == cUnitTypedeHouseAfricanTreasureReward) || (effect == cUnitTypeSheep) || (effect == cUnitTypeCow) ||
             (effect == cUnitTypeCoveredWagon) || (effect == cUnitTypeLlama) || (effect == cUnitTypeYPStableWagon) ||
             (effect == cUnitTypeypWaterBuffalo) || (effect == cUnitTypedeHousePlymouthTreasureReward) || 
             (effect == cUnitTypedeShrineJapaneseTreasureReward) || (effect == cUnitTypeypGoat) || (effect == cUnitTypedeZebuCattle)||
             (effect == cUnitTypedeFishingBoatAfrican) || (effect == cUnitTypeypFishingBoatAsian))
         {
            retVal = cAICommPromptToEnemyWhenHeGathersNuggetSettlers;
         }
         break;
      }
      case cNuggetTypeGiveLOS:
      {
         break;
      }
      case cNuggetTypeAdjustSpeed:
      {
         break;
      }
      case cNuggetTypeAdjustHP:
      {
         break;
      }
      case cNuggetTypeConvertUnit:
      {
         if ((effect == cUnitTypeNatMedicineMan) || (effect == cUnitTypeNatClubman) || (effect == cUnitTypeNatRifleman) ||
             (effect == cUnitTypeNatHuaminca) || (effect == cUnitTypeNatTomahawk) || (effect == cUnitTypeNativeScout) ||
             (effect == cUnitTypeNatEagleWarrior) || (effect == cUnitTypeNatKlamathRifleman) || (effect == cUnitTypeypNatMercGurkha))
         {
            retVal = cAICommPromptToEnemyWhenHeGathersNuggetNatives;
         }
         if ((effect == cUnitTypeSettler) || (effect == cUnitTypeCoureur) || (effect == cUnitTypeSettlerNative) ||
             (effect == cUnitTypeypSettlerAsian) || (effect == cUnitTypeypSettlerIndian) || (effect == cUnitTypePilgrim) ||
             (effect == cUnitTypeypSettlerIndian) || (effect == cUnitTypedeAfricanVillagerNugget))
         {
            retVal = cAICommPromptToEnemyWhenHeGathersNuggetSettlers;
         }
         break;
      }
   }

   return (retVal);
}

//==============================================================================
// nuggetHandler
// Nugget event handler, called when somebody gathers a nugget.
//==============================================================================
void nuggetHandler(int playerID = -1)
{
   if (kbGetAge() > cAge2)
   {
      return; // Do not send these chats (or even bother keeping count) after age 2 ends.
   }
   // This should never fire.
   if ((playerID < 1) || (playerID > cNumberPlayers))
   {
      return;
   }
   
   debugChats("Player " + playerID + " gathered a nugget");
   static int nuggetCounts = -1; // Array handle, nuggetCounts[i] will track how many nuggets each player has claimed.
   static int totalNuggets = 0;
   int defaultChatID = getNuggetChatID(playerID);

   // Initialize the array if we haven't done this before.
   if (nuggetCounts < 0)
   {
      nuggetCounts = xsArrayCreateInt(cNumberPlayers, 0, "Nugget Counts");
   }

   totalNuggets = totalNuggets + 1;
   // Increase how many nuggets this player has found.
   xsArraySetInt(nuggetCounts, playerID, xsArrayGetInt(nuggetCounts, playerID) + 1);

   // Check to see if one of the special-case chats might be appropriate.
   // If so, use it, otherwise, fall through to the generic ones.
   // First, some bookkeeping.
   int count = 0;
   int lowestPlayer = -1;
   int lowestCount = 100000; // Insanely high start value, first pass will reset it.
   int totalCount = 0;
   int averageCount = 0;
   int highestPlayer = -1;
   int highestCount = 0;
   for (i = 1; < cNumberPlayers)
   {
      count = xsArrayGetInt(nuggetCounts, i); // How many nuggets has player i gathered?
      if (count < lowestCount)
      {
         lowestCount = count;
         lowestPlayer = i;
      }
      if (count > highestCount)
      {
         highestCount = count;
         highestPlayer = i;
      }
      totalCount += count;
   }
   averageCount = totalCount / (cNumberPlayers - 1);

   if (totalCount == 1) // This is the first nugget collected in the game.
   {
      if (playerID != cMyID)
      {
         if (kbIsPlayerAlly(playerID) == true)
         {
            sendStatement(playerID, cAICommPromptToAllyWhenHeGathersFirstNugget);
         }
         else
         {
            sendStatement(playerID, cAICommPromptToEnemyWhenHeGathersFirstNugget);
         }
         return;
      }
   }
   
   int myCount = xsArrayGetInt(nuggetCounts, cMyID);
   if (playerID != cMyID) // Check if this player is way ahead of me.
   {
      // How many nuggets has the person collected we're now calling this handler for.
      int playerIDNuggetCount = xsArrayGetInt(nuggetCounts, playerID);
      if (((playerIDNuggetCount - myCount) >= 2) && (playerIDNuggetCount >= (myCount * 2)))
      {
         if (kbIsPlayerAlly(playerID) == true)
         {
            sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetHeIsAhead);
         }
         else
         {
            sendStatement(playerID, cAICommPromptToEnemyWhenHeGathersNuggetHeIsAhead);
         }
         return;
      }
   }
   else // Check if I'm way ahead of any other players.
   {
      bool messageSent = false;
      int playerNuggetCount = 0;
      for (player = 1; < cNumberPlayers)
      {
         playerNuggetCount = xsArrayGetInt(nuggetCounts, player);
         if (((myCount - playerNuggetCount) >= 2) && (myCount >= (playerNuggetCount * 2)))
         {
            if (kbIsPlayerAlly(player) == true)
            {
               sendStatement(player, cAICommPromptToAllyWhenIGatherNuggetIAmAhead);
               messageSent = true;
            }
            else
            {
               sendStatement(player, cAICommPromptToEnemyWhenIGatherNuggetIAmAhead);
               messageSent = true;
            }
         }
      }
      if (messageSent == true)
      {
         return;
      }
   }
   
   // Check to see if the nugget was gathered near a main base.
   // For now, check playerID's explorer location, assume nugget was gathered there.
   const int cNuggetRange = 100; // Nuggets within this many meters of a TC are "owned".
   vector explorerPos = cInvalidVector;
   int tcID = -1;
   int explorerID = getUnit(cUnitTypeExplorer, playerID, cUnitStateAlive);

   if (explorerID >= 0) // We know of an explorer for this player.
   {
      if (kbUnitVisible(explorerID) == true)
      { 
         explorerPos = kbUnitGetPosition(explorerID);
         if (playerID == cMyID)
         {  // Get nearest ally TC distance                  
            tcID = getUnitByLocation(cUnitTypeAgeUpBuilding, cPlayerRelationAllyExcludingSelf, cUnitStateAlive, explorerPos, cNuggetRange);
            if ((tcID > 0) && (kbUnitGetPlayerID(tcID) != cMyID))
            { // A TC is near, owned by an ally, and it's not mine so I stole a nugget from him.
               sendStatement(kbUnitGetPlayerID(tcID), cAICommPromptToAllyWhenIGatherNuggetHisBase);
               return;
            }
            // Check if there in an enemy TC within range.
            tcID = getUnitByLocation(cUnitTypeAgeUpBuilding, cPlayerRelationEnemy, cUnitStateAlive, explorerPos, cNuggetRange);
            if (tcID > 0)
            { // A TC is near, owned by an enemy so I stole a nugget from him.
               sendStatement(kbUnitGetPlayerID(tcID), cAICommPromptToEnemyWhenIGatherNuggetHisBase);
               return;
            }
         }
         else
         {
            if (kbIsPlayerAlly(playerID) == true)
            { // An ally has found a nugget, see if it's close to my TC
               tcID = getUnitByLocation(cUnitTypeAgeUpBuilding, cMyID, cUnitStateAlive, explorerPos, cNuggetRange);
               if (tcID > 0)
               {                                                                         // That jerk took my nugget!
                  sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetMyBase); // He got one in my zone.
                  return;
               }
            }
            else
            { // An enemy has found a nugget, see if it's in my zone
               tcID = getUnitByLocation(cUnitTypeAgeUpBuilding, cMyID, cUnitStateAlive, explorerPos, cNuggetRange);
               if (tcID > 0)
               {                                                                          // That jerk took my nugget!
                  sendStatement(playerID, cAICommPromptToEnemyWhenHeGathersNuggetMyBase); // He got one in my zone.
                  return;
               }
            }
         } 
      }   
   }  

   // No special events fired, so go with generic messages.
   // defaultChatID has the appropriate chat if an enemy gathered the nugget...send it.
   // Otherwise, convert to the appropriate case.
   if (playerID != cMyID)
   {
      if (kbIsPlayerEnemy(playerID) == true)
      {
         sendStatement(playerID, defaultChatID);
      }
      else
      { // Find out what was returned, send the equivalent ally version
         switch (defaultChatID)
         {
            case cAICommPromptToEnemyWhenHeGathersNugget:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNugget);
               break;
            }
            case cAICommPromptToEnemyWhenHeGathersNuggetCoin:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetCoin);
               break;
            }
            case cAICommPromptToEnemyWhenHeGathersNuggetFood:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetFood);
               break;
            }
            case cAICommPromptToEnemyWhenHeGathersNuggetWood:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetWood);
               break;
            }
            case cAICommPromptToEnemyWhenHeGathersNuggetNatives:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetNatives);
               break;
            }
            case cAICommPromptToEnemyWhenHeGathersNuggetSettlers:
            {
               sendStatement(playerID, cAICommPromptToAllyWhenHeGathersNuggetSettlers);
               break;
            }
         }
      }
   }
   else
   {
      // I gathered the nugget. Figure out what kind it is based on the defaultChatID enemy version.
      // Substitute appropriate ally and enemy chats.
      switch (defaultChatID)
      {
         case cAICommPromptToEnemyWhenHeGathersNugget:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNugget);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNugget);
            break;
         }
         case cAICommPromptToEnemyWhenHeGathersNuggetCoin:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNuggetCoin);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNuggetCoin);
            break;
         }
         case cAICommPromptToEnemyWhenHeGathersNuggetFood:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNuggetFood);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNuggetFood);
            break;
         }
         case cAICommPromptToEnemyWhenHeGathersNuggetWood:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNuggetWood);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNuggetWood);
            break;
         }
         case cAICommPromptToEnemyWhenHeGathersNuggetNatives:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNuggetNatives);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNuggetNatives);
            break;
         }
         case cAICommPromptToEnemyWhenHeGathersNuggetSettlers:
         {
            sendStatement(cPlayerRelationAllyExcludingSelf, cAICommPromptToAllyWhenIGatherNuggetSettlers);
            sendStatement(cPlayerRelationEnemy, cAICommPromptToEnemyWhenIGatherNuggetSettlers);
            break;
         }
      }
   }

   return;
}

//==============================================================================
// commHandler
// This event handler is called whenever a human player requests something via the Diplomacy menu.
// Or a scenario uses the aiComm triggers.
//==============================================================================
void commHandler(int chatID = -1, int statementID = -1)
{
   int fromID = -1; // Which player sent this?

   if (chatID >= 0)
   {
      fromID = aiCommsGetSendingPlayer(chatID);
   }
   else
   {
      fromID = aiCommsGetStatementPlayerID(statementID);
   }

   // DO NOT react to my own commands/requests.
   // DO NOT accept commands/requests from enemies.
   if ((fromID == cMyID) || ((kbIsPlayerEnemy(fromID) == true) && (fromID != 0)))
   {
      return;
   }

   // The campaign team has indicated this menu shouldn't function inside of SP content.
   // Because it could mess with their design of the allied AIs.
   // But trigger requests we of course do take!
   if ((gSPC == true) && (fromID != 0))
   {
      sendStatement(fromID, cAICommPromptToAllyDeclineProhibited);
      return;
   }

   int age = kbGetAge();
   if (age == cAge1)
   {  // Don't do anything in Exploration since it often makes no sense or would mess up our start.
      if (chatID >= 0)
      {
         // Only respond to chats.
         sendStatement(fromID, cAICommPromptToAllyDeclineProhibited);
      }
      return;
   }
   
   int verb = -1;
   int targetType = -1;
   int target = -1;
   vector location = cInvalidVector;

   if (chatID >= 0)
   {
      verb = aiCommsGetChatVerb(chatID); // Like cPlayerChatVerbAttack or cPlayerChatVerbDefend.
      targetType = aiCommsGetChatTargetType(chatID); // Like cPlayerChatTargetTypePlayers or cPlayerChatTargetTypeLocation.
      target = aiCommsGetTargetListItem(chatID, 0); // Like cResourceFood or cUnitTypeAbstractArtillery.
      location = aiCommsGetTargetLocation(chatID); // Target location
   }
   else if (statementID >= 0)
   {
      int promptType = aiCommsGetStatementPromptType(statementID);

      // Only respond to certain prompt types.
      switch(promptType)
      {
         case cAICommPromptToAllyINeedHelpMyBase:
         {
            verb = cPlayerChatVerbAttack;
            targetType = cPlayerChatTargetTypeLocation;
            location = aiCommsGetStatementPosition(statementID);
         }
         case cAICommPromptToAllyRequestFood:
         {
            verb = cPlayerChatVerbTribute;
            target = cResourceFood;
            break;
         }
         case cAICommPromptToAllyRequestWood:
         {
            verb = cPlayerChatVerbTribute;
            target = cResourceWood;
            break;
         }
         case cAICommPromptToAllyRequestCoin:
         {
            verb = cPlayerChatVerbTribute;
            target = cResourceGold;
            break;
         }            
         default:
         {
            // Ignore this prompt.
            debugChats("Ignoring prompt type: "+promptType);
            return;
         }
      }

      debugChats("Handling prompt type: "+promptType);
   }
   else // Invalid chat and statement.
   {
      return;
   }
   
   static float initialbtRushBoom = -2.0;
   static float initialbtOffenseDefense = -2.0;
   static float initialbtBiasCav = -2.0;
   static float initialbtBiasInf = -2.0;
   static float initialbtBiasArt = -2.0;
   if (initialbtRushBoom == -2.0) // First run.
   {
      initialbtRushBoom = btRushBoom;
      initialbtOffenseDefense = btOffenseDefense;
      initialbtBiasCav = btBiasCav;
      initialbtBiasInf = btBiasInf;
      initialbtBiasArt = btBiasArt;
   }

   // Assume it's from a player unless we find out it's player 0, Gaia, indicating a trigger.
   // We currently do nothing with this information since we haven't implemented most of the trigger stuff.
   //int opportunitySource = cOpportunitySourceAllyRequest; 
   //if (fromID == 0)                                       
   //{
   //   opportunitySource = cOpportunitySourceTrigger;
   //}

   debugChats("***** Incoming Communication *****");
   debugChats("From player: " + fromID + ", verb: " + verb + ", targetType: " + targetType + ", target: " + target);

   switch (verb) // Parse this message starting with the verb.
   {
      case cPlayerChatVerbAttack:
      {
         if (aiTreatyActive() == true)
         {
            sendStatement(fromID, cAICommPromptToAllyDeclineProhibited);
            debugChats("Deny attack/defend request because treaty is active");
            break;
         }

         int numUnits = aiPlanGetNumberUnits(gLandReservePlan, cUnitTypeLogicalTypeLandMilitary);
         int currentFreeMilitaryPop = 0;
         for (int i = 0; i < numUnits; i++)
         {
            int unitID = aiPlanGetUnitByIndex(gLandReservePlan, i);
            currentFreeMilitaryPop += kbGetPopSlots(cMyID, kbUnitGetProtoUnitID(unitID));
         }
         if (currentFreeMilitaryPop < 5)
         {
            sendStatement(fromID, cAICommPromptToAllyDeclineNoArmy);
            debugChats("Deny attack/defend request because no army");
            break;
         }
         if (currentFreeMilitaryPop < 15)
         {
            sendStatement(fromID, cAICommPromptToAllyDeclineSmallArmy);
            debugChats("Deny attack/defend request because small army");
            break;
         }

         if (isDefendingOrAttacking() == true)
         {
            sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
            break;
         }
         
         debugChats("Location(vector) of the requested attack / defend: " + location);
         switch (targetType)
         {
            case cPlayerChatTargetTypeLocation:
            {
               // This means our human ally has requested we "attack" this location.
               // Attack here can mean either of 2 things: "attack" or "defend".
               // We get how many buildings there are at the provided location and decide what to do based off that.
               
               int mainBaseID = kbBaseGetMainID(cMyID);
               // Always defend ourselves first.
               if (gDefenseReflexBaseID == mainBaseID)
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
                  debugChats("Deny attack/defend request because we're under attack ourselves");
                  break;
               }
               
               int numEnemyBuildings = getUnitCountByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
                  location, 50.0);
               int numAlliedBuildings = getUnitCountByLocation(cUnitTypeBuilding, cPlayerRelationAlly, cUnitStateAlive,
                  location, 50.0);
               
               // We do not defend or attack in an open space, there must be buildings present.
               if ((numEnemyBuildings == 0) && (numAlliedBuildings == 0))
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
                  debugChats("Deny attack/defend request because no buildings found");
                  break;
               }
               
               int combatPlanID = -1;

               // Attack plan.
               if (numEnemyBuildings >= numAlliedBuildings)
               {  
                  int enemyBuildingID = getClosestUnitByLocation(cUnitTypeBuilding, cPlayerRelationEnemyNotGaia, cUnitStateAlive,
                     location, 50.0);
                  int playerToAttack = kbUnitGetPlayerID(enemyBuildingID);
                  vector gatherPoint = kbBaseGetMilitaryGatherPoint(cMyID, mainBaseID);
                  
                  combatPlanID = aiPlanCreate("commHandler Attack Player " + playerToAttack, cPlanCombat);

                  aiPlanSetVariableInt(combatPlanID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeAttack);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanTargetPlayerID, 0, playerToAttack);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanTargetBaseID, 0, kbUnitGetBaseID(enemyBuildingID));
                  aiPlanSetVariableVector(combatPlanID, cCombatPlanTargetPoint, 0, location);
                  aiPlanSetVariableVector(combatPlanID, cCombatPlanGatherPoint, 0, gatherPoint);
                  aiPlanSetVariableFloat(combatPlanID, cCombatPlanGatherDistance, 0, 40.0);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanAttackRoutePattern, 0, cCombatPlanAttackRoutePatternRandom);
            
                  if (cDifficultyCurrent >= cDifficultyHard)
                  {
                     aiPlanSetVariableInt(combatPlanID, cCombatPlanRefreshFrequency, 0, 300);
                     aiPlanSetVariableInt(combatPlanID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeRetreat | cCombatPlanDoneModeBaseGone);
                     aiPlanSetVariableInt(combatPlanID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeOutnumbered);
                     updateMilitaryTrainPlanBuildings(gForwardBaseID);
                     if (cDifficultyCurrent >= cDifficultyExpert)
                     {
                        aiPlanSetVariableBool(combatPlanID, cCombatPlanAllowMoreUnitsDuringAttack, 0, true);
                     }
                  }
                  else
                  {
                     aiPlanSetVariableInt(combatPlanID, cCombatPlanRefreshFrequency, 0, 1000);
                     aiPlanSetVariableInt(combatPlanID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeBaseGone);
                  }
                  aiPlanSetBaseID(combatPlanID, mainBaseID);
                  aiPlanSetInitialPosition(combatPlanID, gatherPoint);
            
                  addUnitsToMilitaryPlan(combatPlanID);
            
                  aiPlanSetActive(combatPlanID);
            
                  gLastAttackMissionTime = xsGetTime();
                  
                  sendStatement(fromID, cAICommPromptToAllyIWillAttackWithYou, location);
                  debugChats("Confirming attack request");
               }
               else // Defend plan.
               {
                  int alliedBuildingID = getClosestUnitByLocation(cUnitTypeBuilding, cPlayerRelationAlly, cUnitStateAlive,
                     location, 50.0);
                  int playerToDefend = kbUnitGetPlayerID(alliedBuildingID);
                  combatPlanID = aiPlanCreate("commHandler Defend Player " + playerToDefend, cPlanCombat);
                  
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanCombatType, 0, cCombatPlanCombatTypeDefend);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanTargetPlayerID, 0, playerToDefend);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanTargetBaseID, 0, kbUnitGetBaseID(alliedBuildingID));
                  aiPlanSetVariableVector(combatPlanID, cCombatPlanTargetPoint, 0, location);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanRefreshFrequency, 0, cDifficultyCurrent >= cDifficultyHard ? 300 : 1000);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanDoneMode, 0, cCombatPlanDoneModeNoTarget);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanNoTargetTimeout, 0, 30000);
                  aiPlanSetVariableInt(combatPlanID, cCombatPlanRetreatMode, 0, cCombatPlanRetreatModeNone);
                  aiPlanSetOrphan(combatPlanID, true);

                  addUnitsToMilitaryPlan(combatPlanID);
                  aiPlanSetActive(combatPlanID);
                  sendStatement(fromID, cAICommPromptToAllyIWillHelpDefend, location);
                  debugChats("Confirming defend request");
               }
               break;
            }
            case cPlayerChatTargetTypeUnits:
            {
               // This is only available via triggers.
               // You must provide a premade army inside of the editor which the AI will then attack.
               // This doesn't work yet, just deny.
               sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
               break;
            }
         }
         break;
      } // End attack.
   
      case cPlayerChatVerbTribute:
      {
         if (fromID == 0) // This was a trigger command.
         {
            debugChats("Trigger tribute command");
            fromID = 1; // We always tribute to player 1 when a trigger asks us to tribute.
         }
         debugChats("Command was to tribute to player " + fromID);
         debugChats("Requested resource is: " + kbGetResourceName(target));
         
         switch (target)
         {
            case cResourceGold:
            {
               if (handleTributeRequest(cResourceGold, fromID) == true)
               {
                  sendStatement(fromID, cAICommPromptToAllyITributedCoin);
               }
               else
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineCantAfford);
               }
               break;
            }
            case cResourceWood:
            {
               if (handleTributeRequest(cResourceWood, fromID) == true)
               {
                  sendStatement(fromID, cAICommPromptToAllyITributedWood);
               }
               else
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineCantAfford);
               }
               break;
            }
           case cResourceFood:
            {
               if (handleTributeRequest(cResourceFood, fromID) == true)
               {
                  sendStatement(fromID, cAICommPromptToAllyITributedFood);
               }
               else
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineCantAfford);
               }
               break;
            }
         }
         break;
      } // End tribute.
   
      case cPlayerChatVerbFeed: // monitorFeeding will tribute to the player if we have enough resources once a minute.
      {
         debugChats("Command was to feed resources to player: " + fromID);
         debugChats("Requested resource is: " + kbGetResourceName(target));
         switch (target)
         {
            case cResourceGold:
            {
               debugChats("We accept and will feed some Gold");
               gFeedGoldTo = fromID;
               if (xsIsRuleEnabled("monitorFeeding") == false)
               {
                  xsEnableRule("monitorFeeding");
                  monitorFeeding();
               }
               sendStatement(fromID, cAICommPromptToAllyIWillFeedCoin);
               break;
            }
            case cResourceWood:
            {
               debugChats("We accept and will feed some Wood");
               gFeedWoodTo = fromID;
               if (xsIsRuleEnabled("monitorFeeding") == false)
               {
                  xsEnableRule("monitorFeeding");
                  monitorFeeding();
               }
               sendStatement(fromID, cAICommPromptToAllyIWillFeedWood);
               break;
            }
            case cResourceFood:
            {
               debugChats("We accept and will feed some Food");
               gFeedFoodTo = fromID;
               if (xsIsRuleEnabled("monitorFeeding") == false)
               {
                  xsEnableRule("monitorFeeding");
                  monitorFeeding();
               }
               sendStatement(fromID, cAICommPromptToAllyIWillFeedFood);
               break;
            }
         }
         break;
      } // End feed.
   
      case cPlayerChatVerbTrain:
      {
         // You can ask the AI to focus on 3 different unit types without needing to cancel first, guard for that.
         switch (target)
         {
            case cUnitTypeAbstractInfantry:
            {
               btBiasCav = initialbtBiasCav;
               btBiasArt = initialbtBiasArt;
               btBiasInf += 0.5;
               if (btBiasInf > 1.0)
               {
                  btBiasInf = 1.0;
               }
               sendStatement(fromID, cAICommPromptToAllyConfirmInf);
               break;
            }
            case cUnitTypeAbstractCavalry:
            {
               btBiasInf = initialbtBiasInf;
               btBiasArt = initialbtBiasArt;
               btBiasCav += 0.5;
               if (btBiasCav > 1.0)
               {
                  btBiasCav = 1.0;
               }
               sendStatement(fromID, cAICommPromptToAllyConfirmCav);
               break;
            }
            case cUnitTypeAbstractArtillery:
            {
               // These civs only get artillery when they're in the Imperial Age.
               if (((cMyCiv == cCivXPSioux) ||
                    (cMyCiv == cCivXPAztec) ||
                    (cMyCiv == cCivDEInca)) &&
                    (age != cAge5))
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineProhibited);
                  break;
               }
               // Only Swedes get artillery in Commerce Age, the rest must wait until Fortress Age.
               if ((cMyCiv != cCivDESwedish) &&
                   (age == cAge2))
               {
                  sendStatement(fromID, cAICommPromptToAllyDeclineProhibited);
                  break;
               }
               btBiasCav = initialbtBiasCav;
               btBiasInf = initialbtBiasInf;
               btBiasArt += 0.5;
               if (btBiasArt > 1.0)
               {
                  btBiasArt = 1.0;
               }
               sendStatement(fromID, cAICommPromptToAllyConfirmArt);
               break;
            }
         }
         break;
      } // End train.
      
      case cPlayerChatVerbDefend:
      {
         // This is only available via triggers, you must provide a location in the trigger.
         // We should then create a combat plan on defend mode on that location.
         // Doesn't work yet, just deny.
         sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
         break;
      } // End defend.
      
      case cPlayerChatVerbClaim:
      {  
         // This is only available via triggers, you must provide a location in the trigger.
         // We should then scan the location for a Trading Post socket and make a build plan for it.
         // Doesn't work yet, just deny.
         sendStatement(fromID, cAICommPromptToAllyDeclineGeneral);
         break;
      } // End Claim.
      
      case cPlayerChatVerbStrategy:
      {
         // You can ask the AI to do the 3 different strategies without needing to cancel first, guard for that.
         if (target == cPlayerChatTargetStrategyRush)
         {
            gTowerCommandActive = true;
            btRushBoom = 1.0;
            gCommandNumTowers = 0;
            btOffenseDefense = initialbtOffenseDefense;
         }
         else if (target == cPlayerChatTargetStrategyBoom)
         {
            btRushBoom = -1.0;
            btOffenseDefense = initialbtOffenseDefense;
            gTowerCommandActive = false;
         }
         else if (target == cPlayerChatTargetStrategyTurtle)
         {
            gTowerCommandActive = true;
            btOffenseDefense = -1.0;
            btRushBoom = initialbtRushBoom;
   
            if (cDifficultyCurrent <= cDifficultyEasy) // Easy / Standard.
            {
               gCommandNumTowers = 3; // 1 More than the default maximum.
            }
            else if (cDifficultyCurrent <= cDifficultyHard) // Moderate / Hard.
            {
               gCommandNumTowers = 5; // 1 More than the default maximum.
            }
            else // Hardest / Extreme.
            {    // We just max out on Towers where we normally would only do that in the cvMaxAge.
               gCommandNumTowers = kbGetBuildLimit(cMyID, gTowerUnit);
            }
         }
         // We just always accept this request.
         sendStatement(fromID, cAICommPromptToAllyConfirm);
         break;
      } // End strategy.
      
      case cPlayerChatVerbCancel:
      {
         // We do not destroy the ongoing defend/attack plans because
         // that would be very bad if the units are currently in combat.

         // Clear Feeding (ongoing tribute) settings.
         gFeedGoldTo = 0;
         gFeedWoodTo = 0;
         gFeedFoodTo = 0;
   
         // No longer use the custom Tower limits.
         gTowerCommandActive = false;
   
         // Reset the sliders.
         btRushBoom = initialbtRushBoom;
         btOffenseDefense = initialbtOffenseDefense;
         btBiasCav = initialbtBiasCav;
         btBiasInf = initialbtBiasInf;
         btBiasArt = initialbtBiasArt;

         // We always allow cancellation.
         sendStatement(fromID, cAICommPromptToAllyConfirm);
         break;
      } // End cancel.
      
      default:
      {
         debugChats("WARNING: Command verb not found, verb value is: " + verb);
         break;
      }
   }
   debugChats("***** End of communication *****");
}