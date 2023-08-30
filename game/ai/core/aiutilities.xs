//==============================================================================
/* aiUtilities.xs

   This file contains utility functions used among all files.

*/
//==============================================================================

//==============================================================================
// Debug output functions.
//==============================================================================

void debugUtilities (string message = "")
{
   if (cDebugUtilities == true)
   {
      aiEcho(message);
   }
}

void debugBuildings (string message = "")
{
   if (cDebugBuildings == true)
   {
      aiEcho(message);
   }
}

void debugTechs (string message = "")
{
   if (cDebugTechs == true)
   {
      aiEcho(message);
   }
}

void debugExploration (string message = "")
{
   if (cDebugExploration == true)
   {
      aiEcho(message);
   }
}

void debugEconomy (string message = "")
{
   if (cDebugEconomy == true)
   {
      aiEcho(message);
   }
}

void debugMilitary (string message = "")
{
   if (cDebugMilitary == true)
   {
      aiEcho(message);
   }
}

void debugHCCards (string message = "")
{
   if (cDebugHCCards == true)
   {
      aiEcho(message);
   }
}

void debugChats (string message = "")
{
   if (cDebugChats == true)
   {
      aiEcho(message);
   }
}

void debugSetup (string message = "")
{
   if (cDebugSetup == true)
   {
      aiEcho(message);
   }
}

void debugCore (string message = "")
{
   if (cDebugCore == true)
   {
      aiEcho(message);
   }
}

//==============================================================================
// Civilization checks.
//==============================================================================

bool civIsNative(void)
{
   if ((cMyCiv == cCivXPAztec) || (cMyCiv == cCivXPIroquois) || (cMyCiv == cCivXPSioux) || (cMyCiv == cCivDEInca))
   {
      return (true);
   }
   return (false);
}

bool civIsAsian(void)
{
   if ((cMyCiv == cCivJapanese) || (cMyCiv == cCivChinese) || (cMyCiv == cCivIndians) || (cMyCiv == cCivSPCIndians) ||
       (cMyCiv == cCivSPCChinese) || (cMyCiv == cCivSPCJapanese) || (cMyCiv == cCivSPCJapaneseEnemy))
   {
      return (true);
   }
   return (false);
}

bool civIsAfrican(void)
{
   if ((cMyCiv == cCivDEEthiopians) || (cMyCiv == cCivDEHausa))
   {
      return (true);
   }
   return (false);
}

bool civIsEuropean(void) { return (civIsNative() == false && civIsAsian() == false && civIsAfrican() == false); }

bool civIsDEciv(void)
{
   if ((cMyCiv == cCivDEInca) || (cMyCiv == cCivDESwedish) || (cMyCiv == cCivDEAmericans) || (cMyCiv == cCivDEEthiopians) ||
       (cMyCiv == cCivDEHausa) || (cMyCiv == cCivDEMexicans) || (cMyCiv == cCivDEItalians) || (cMyCiv == cCivDEMaltese))
   {
      return (true);
   }
   return (false);
}

bool isMinorNativePresent(int minorNative = -1)
{
   return(minorNative >= 0 ? ((gNativeTribeCiv1 == minorNative) || (gNativeTribeCiv2 == minorNative) || 
          (gNativeTribeCiv3 == minorNative)) : false);
}

//==============================================================================
//==============================================================================
//==============================================================================
//==============================================================================
//==============================================================================
// Algorithms
//==============================================================================
//==============================================================================
//==============================================================================
//==============================================================================
//==============================================================================
vector rotateByReferencePoint(vector refPoint = cInvalidVector, vector vec = cInvalidVector, float angle = 0.0)
{
   if ((refPoint == cInvalidVector) || (vec == cInvalidVector))
      return (cInvalidVector);

   float x = xsVectorGetX(vec);
   float z = xsVectorGetZ(vec);
   vector finalLocation = cInvalidVector;
   finalLocation = xsVectorSet(x * cos(angle) - z * sin(angle) + xsVectorGetX(refPoint),
      0.0, x * sin(angle) + z * cos(angle) + xsVectorGetZ(refPoint));
   return (finalLocation);
}

void randomShuffleIntArray(int array = -1, int size = 0)
{
   int i = size - 1;
   int j = 0;
   int temp = 0;
   while (i >= 0)
   {
      j = aiRandInt(i + 1);
      temp = xsArrayGetInt(array, i);
      xsArraySetInt(array, i, xsArrayGetInt(array, j));
      xsArraySetInt(array, j, temp);
      i = i - 1;
   }
}

//==============================================================================
bool arraySortIntComp(int a = -1, int b = -1) { return (a < b); }
//==============================================================================
// arraySortInt
//==============================================================================
void arraySortInt(int arrayID = -1, int begin = 0, int end = -1, bool(int, int) comp = arraySortIntComp)
{
   int j = 0;
   int key = 0;

   if (end < 0)
   {
      end = xsArrayGetSize(arrayID);
   }
   for (i = begin + 1; < end)
   {
      key = xsArrayGetInt(arrayID, i);
      j = i - 1;
      while ((j >= 0) && (comp(xsArrayGetInt(arrayID, j), key) == false))
      {
         xsArraySetInt(arrayID, j + 1, xsArrayGetInt(arrayID, j));
         j--;
      }
      xsArraySetInt(arrayID, j + 1, key);
   }
}

//==============================================================================
// arraySortFloat
/*
   Takes two arrays, the source and the target.
   Source has the original values, and is a float array.
   Target (int array) will receive the indexes into source in descending order.  For example,
   if the highest value in source is source[17] with a value of 91, then
   arraySort(source, target) will assign target[0] the value of 17, and
   source[target[0]] will be 91.

*/
//==============================================================================
bool arraySortFloat(int sourceArray = -1, int targetArray = -1)
{
   int pass = 0;
   int i = 0;
   int size = xsArrayGetSize(sourceArray);
   if (size != xsArrayGetSize(targetArray))
   {
      debugUtilities("ArraySort error, source and target are not of same size");
      return (false);
   }

   float highestScore = 1000000.0; // Highest score found on previous pass
   float highScore = -1000000.0;   // Highest score found on this pass
   int highestScoreIndex = -1;     // Which element had the high score last pass?
   int highScoreIndex = -1;        // Which element has the highest score so far this pass?
   for (pass = 0; < size)          // Sort the array
   {
      highScore = -1000000.0;
      highScoreIndex = -1;
      for (i = 0; < size) // Look for highest remaining value
      {
         if (xsArrayGetFloat(sourceArray, i) > highestScore) // We're over the highest score, already been selected.  Skip.
         {
            continue;
         }
         if ((xsArrayGetFloat(sourceArray, i) == highestScore) &&
             (highestScoreIndex >= i)) // Tie with a later one, we've been selected.  Skip.
         {
            continue;
         }
         if (xsArrayGetFloat(sourceArray, i) <= highScore) // We're not the highest so far on this pass, skip.
         {
            continue;
         }
         highScore = xsArrayGetFloat(sourceArray, i); // This is the highest score this pass
         highScoreIndex = i;                          // So remember this index
      }
      xsArraySetInt(targetArray, pass, highScoreIndex);
      highestScore = highScore; // Save this for next pass
      highestScoreIndex = highScoreIndex;
   }
   return (true);
}

//==============================================================================
/* sigmoid(float base, float adjustment, float floor, float ceiling)

   Used to adjust a number up or down in a sigmoid fashion, so that it
   grows very slowly at values near the bottom of the range, quickly near
   the center, and slowly near the upper limit.

   Used with the many 0..1 range variables, this lets us adjust them up
   or down by arbitrary "percentages" while retaining the 0..1 boundaries.
   That is, a 50% "boost" (1.5 adjustment) to a .9 score gives .933, while a


   Base is the number to be adjusted.
   Adjustment of 1.0 means 100%, i.e. stay where you are.
   Adjustment of 2.0 means to move it up by the LESSER movement of:
      Doubling the (base-floor) amount, or
      Cutting the (ceiling-base) in half (mul by 1/2.0).

   With a default floor of 0 and ceiling of 1, it gives these results:
      sigmoid(.1, 2.0) = .2
      sigmoid(.333, 2.0) = .667, upper and lower adjustments equal
      sigmoid(.8, 2.0) = .9, adjusted up 50% (1/2.0) of the headroom.
      sigmoid(.1, 5.0) = .50 (5x base, rather than moving up to .82)
      sigmoid(.333, 5.0) = .866, (leaving 1/5 of the .667 headroom)
      sigmoid(.8, 5.0) = .96 (leaving 1/5 of the .20 headroom)

   Adjustments of less than 1.0 (neutral) do the opposite...they move the
   value DOWN by the lesser movement of:
      Increasing headroom by a factor of 1/adjustment, or
      Decreasing footroom by multiplying by adjustment.
      sigmoid(.1, .5) = .05   (footroom*adjustment)
      sigmoid(.667, .5) = .333  (footroom*adjustment) = (headroom doubled)
      sigmoid(.8, .2) = .16 (footroom*0.2)

   Not intended for base < 0.  Ceiling must be > floor.  Must have floor <= base <= ceiling.
*/
//==============================================================================
float sigmoid(float base = -1.0 /*required*/, float adjust = 1.0, float floor = 0.0, float ceiling = 1.0)
{
   float retVal = -1.0;
   if (base < 0.0)
   {
      return (retVal);
   }
   if (ceiling <= floor)
   {
      return (retVal);
   }
   if (base < floor)
   {
      return (retVal);
   }
   if (base > ceiling)
   {
      return (retVal);
   }

   float footroom = base - floor;
   float headroom = ceiling - base;

   float footBasedNewValue = 0.0; // This will be the value created by adjusting the footroom, i.e.
                                  // increasing a small value.
   float headBasedNewValue = 0.0; // This will be the value created by adjusting the headroom, i.e.
                                  // increasing a value that's closer to ceiling than floor.

   if (adjust > 1.0)
   { // Increasing
      footBasedNewValue = floor + (footroom * adjust);
      headBasedNewValue = ceiling - (headroom / adjust);

      // Pick the value that resulted in the smaller net movement
      if ((footBasedNewValue - base) < (headBasedNewValue - base))
         retVal = footBasedNewValue; // The foot adjustment gave the smaller move.
      else
         retVal = headBasedNewValue; // The head adjustment gave the smaller move
   }
   else
   { // Decreasing
      footBasedNewValue = floor + (footroom * adjust);
      headBasedNewValue = ceiling - (headroom / adjust);

      // Pick the value that resulted in the smaller net movement
      if ((base - footBasedNewValue) < (base - headBasedNewValue))
      {
         retVal = footBasedNewValue; // The foot adjustment gave the smaller move.
      }
      else
      {
         retVal = headBasedNewValue; // The head adjustment gave the smaller move
   }
   }

   debugUtilities("sigmoid(" + base + ", " + adjust + ", " + floor + ", " + ceiling + ") is " + retVal);
   return (retVal);
}

//==============================================================================
// distance
//
// Will return a float with the 3D distance between two vectors
//==============================================================================
float distance(vector v1 = cInvalidVector, vector v2 = cInvalidVector)
{
   vector delta = v1 - v2;
   return (xsVectorLength(delta));
}

//==============================================================================
// getAreaGroupTileTypePercentage
//==============================================================================
float getAreaGroupTileTypePercentage(int areaGroupID = -1, int tileType = cTileBlack)
{
   int areaID = -1;
   float numberTiles = 0.0;
   float numberTotalTiles = 0.0;
   int numberAreas = kbAreaGroupGetNumberAreas(areaGroupID);
   for (i = 0; < numberAreas)
   {
      areaID = kbAreaGroupGetAreaID(areaGroupID, i);
      if ((tileType & cTileBlack) == cTileBlack)
      {
         numberTiles = numberTiles + kbAreaGetNumberBlackTiles(areaID);
      }
      if ((tileType & cTileFog) == cTileFog)
      {
         numberTiles = numberTiles + kbAreaGetNumberFogTiles(areaID);
      }
      if ((tileType & cTileVisible) == cTileVisible)
      {
         numberTiles = numberTiles + kbAreaGetNumberVisibleTiles(areaID);
      }
      numberTotalTiles = numberTotalTiles + kbAreaGetNumberTiles(areaID);
   }
   return (numberTiles / numberTotalTiles);
}

//==============================================================================
// getAreaGroupNumberTiles
//==============================================================================
int getAreaGroupNumberTiles(int areaGroupID = -1)
{
   int areaID = -1;
   int numberTotalTiles = 0;
   int numberAreas = kbAreaGroupGetNumberAreas(areaGroupID);
   for (i = 0; < numberAreas)
   {
      areaID = kbAreaGroupGetAreaID(areaGroupID, i);
      numberTotalTiles = numberTotalTiles + kbAreaGetNumberTiles(areaID);
   }
   return (numberTotalTiles);
}

vector getStartingLocation(void)
{
   if (gStartingLocationOverride != cInvalidVector)
   {
      return (gStartingLocationOverride);
   }
   return (kbGetPlayerStartingPosition(cMyID));
}

vector guessEnemyLocation(int player = -1)
{
   if (player < 0)
   {
      player = aiGetMostHatedPlayerID();
   }
   vector position = kbGetPlayerStartingPosition(player);

   if ((cDifficultyCurrent >= cDifficultyHard) && (position != cInvalidVector))
   {
      // For higher difficulties, assuming the AI played on this map before, it should have a rough idea of the enemy
      // location.
      float xError = kbGetMapXSize() * 0.1;
      float zError = kbGetMapZSize() * 0.1;
      xsVectorSetX(position, xsVectorGetX(position) + aiRandFloat(0.0 - xError, xError));
      xsVectorSetZ(position, xsVectorGetZ(position) + aiRandFloat(0.0 - zError, zError));
   }
   else
   {
      // For lower difficulties, just simply create a mirror image of our base.
      vector myBaseLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID)); // Main base location...need to find reflection.
      vector mapCenter = kbGetMapCenter();
      vector centerOffset = mapCenter - myBaseLocation;
      position = mapCenter + centerOffset;
   }

   return (position);
}

int getMapID(void)
{
   int mapIndex = 0;
   for (mapIndex = 0; < xsArrayGetSize(gMapNames))
   {
      if (xsArrayGetString(gMapNames, mapIndex) == cRandomMapName)
      {
         return (mapIndex);
      }
   }
   return (-1);
}

float getMilitaryUnitStrength(int puid = -1)
{
   float retVal = 0.0;
   retVal = retVal + kbUnitCostPerResource(puid, cResourceFood) * 0.992 + kbUnitCostPerResource(puid, cResourceWood) * 1.818 +
            kbUnitCostPerResource(puid, cResourceGold) * 1.587;
   retVal = retVal * 0.01;
   return (retVal);
}

int indexProtoUnitInUnitPicker(int puid = -1)
{
   int result = -1;
   for (i = 0; < gNumArmyUnitTypes)
   {
      result = kbUnitPickGetResult(gLandUnitPicker, i);
      if (puid == result)
      {
         return (i);
      }
   }
   return (-1);
}

int getSettlerShortfall()
{ // How many Settlers do we currently want to be trained extra?
   int villTarget = xsArrayGetInt(gTargetSettlerCounts, kbGetAge()); // How many we want to have this age.
   int villCount = aiGetCurrentEconomyPop(); // How many we have, this syscall also takes other economic units than our
                                             // gEconUnit into account.
   // AssertiveWall: Give asian civs higher settler target during age up since they can continue training
   if (civIsAsian() == true && aiPlanGetState(gAgeUpResearchPlan) == cPlanStateBuild)
   {
      villTarget += 5;
   }
   return (villTarget - villCount);
}

//==============================================================================
// getAllyCount() // Returns number of allies EXCLUDING self
//==============================================================================
int getAllyCount()
{
   int retVal = 0;

   int player = 0;
   for (player = 1; < cNumberPlayers)
   {
      if (player == cMyID)
      {
         continue;
      }
      if (kbIsPlayerAlly(player) == true)
      {
         retVal = retVal + 1;
   }
   }

   return (retVal);
}

//==============================================================================
// getHumanAllyCount() // Returns number of human allies EXCLUDING self
//==============================================================================
int getHumanAllyCount()
{
   int retVal = 0;

   int player = 0;
   for (player = 1; < cNumberPlayers)
   {
      if (player == cMyID)
      {
         continue;
      }
      if (((kbIsPlayerAlly(player)) == true) && (kbIsPlayerHuman(player)))
      {
         retVal = retVal + 1;
   }
   }

   return (retVal);
}

//==============================================================================
// getEnemyCount() // Returns number of enemies excluding gaia
//==============================================================================
int getEnemyCount()
{
   int retVal = 0;

   int player = 0;
   for (player = 1; < cNumberPlayers)
   {
      if (player == cMyID)
      {
         continue;
      }
      if (kbIsPlayerEnemy(player) == true)
      {
         retVal = retVal + 1;
   }
   }

   return (retVal);
}

//==============================================================================
// getTeamPosition
/*
   Returns the player's position in his/her team, i.e. in a 123 vs 456 game,
   player 5's team position is 2, player 3 is 3, player 4 is 1.

   Excludes resigned players.

*/
//==============================================================================
int getTeamPosition(int playerID = -1)
{
   int index = -1;       // Used for traversal
   int playerToGet = -1; // i.e. get the 2nd matching playe

   // Traverse list of players, increment when we find a teammate, return when we find my number.
   int retVal = 0; // Zero if I don't exist...
   for (index = 1; < cNumberPlayers)
   {
      if ((kbHasPlayerLost(index) == false) && (kbGetPlayerTeam(playerID) == kbGetPlayerTeam(index)))
      {
         retVal = retVal + 1; // That's another match
      }
      if (index == playerID)
      {
         return (retVal);
   }
   }
   return (-1);
}

//==============================================================================
/* getEnemyPlayerByTeamPosition

   Returns the ID of the Nth player on the enemy team, returns -1 if
   there aren't that many players.
   Excludes resigned players.
*/
//==============================================================================
int getEnemyPlayerByTeamPosition(int position = -1)
{

   int matchCount = 0;
   int index = -1;       // Used for traversal
   int playerToGet = -1; // i.e. get the 2nd matching playe

   // Traverse list of players, return when we find the matching player
   for (index = 1; < cNumberPlayers)
   {
      if ((kbHasPlayerLost(index) == false) && (kbGetPlayerTeam(cMyID) != kbGetPlayerTeam(index)))
      {
         matchCount = matchCount + 1; // Enemy player, add to the count
      }

      if (matchCount == position)
      {
         return (index);
   }
   }
   return (-1);
}


//==============================================================================
// agingUp
//==============================================================================
bool agingUp()
{
   int planState = cPlanStateResearch;
   if (civIsAsian() == true)
   {
      planState = cPlanStateBuild;
   }
   return (aiPlanGetState(gAgeUpResearchPlan) == planState);
}

//==============================================================================
/* needMoreHouses
   We stop building houses when we have enough room for gMaxPop + 10.
   If you change something here also look at updateResourceDistribution
   since Houses are calculated there too.
*/
//==============================================================================
bool needMoreHouses()
{
   // Nothing to do with Lakota because we always max out pop cap without anything.
   if (cMyCiv == cCivXPSioux)
   {
      return (false);
   }
   int age = kbGetAge();
   // Nothing to do with lakota because we always max out pop cap without anything.
   if (age == cAge1)
   {
      int ownedHouses = kbUnitCount(cMyID, gHouseUnit, cUnitStateAlive) +
         aiPlanGetNumberByTypeAndVariableType(cPlanBuild, cBuildPlanBuildingTypeID, gHouseUnit, true);
      if ((ownedHouses == 0) || 
          ((ownedHouses == 1) && (agingUp() == true)))
      {
         return (true);
      }
      else
      {
         return (false);
      }
   }
   
   int popCap = kbGetPopCap();
   return ((popCap - kbGetPop() < 10 + 5 * age) && (popCap < gMaxPop + 10));
}

//==============================================================================
// getUnit
// Will return a random unit matching the parameters
//==============================================================================
int getUnit(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1); // Clear the player ID, so playerRelation takes precedence.
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound > 0)
   {
      return (kbUnitQueryGetResult(unitQueryID, aiRandInt(numberFound))); // Return a random dude(tte)
   }
   return (-1);
}

//==============================================================================
// createSimpleUnitQuery
//==============================================================================
int createSimpleUnitQuery(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                          vector position = cInvalidVector, float radius = -1.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscSimpleUnitQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1); // Clear the player ID, so playerRelation takes precedence.
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, position);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   return (unitQueryID);
}


//==============================================================================
// createSimpleIdleUnitQuery
// AssertiveWall: Same as simple unit query, except only finds idle units
//==============================================================================
int createSimpleIdleUnitQuery(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                          vector position = cInvalidVector, float radius = -1.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscSimpleUnitQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1); // Clear the player ID, so playerRelation takes precedence.
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetActionType(unitQueryID, cActionTypeIdle); // AssertiveWall: this is the only change
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, position);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   return (unitQueryID);
}

//==============================================================================
// createSimpleGaiaUnitQuery
// ATTENTION: before you call this function switch your context to Gaia(0) otherwise this won't work.
// Then in your code first kbUnitQueryExecute the query BEFORE you switch back to cMyID.
//==============================================================================
int createSimpleGaiaUnitQuery(int unitTypeID = -1, int state = cUnitStateAlive, vector position = cInvalidVector,
                              float radius = -1.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscSimpleUnitQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      kbUnitQuerySetPlayerID(unitQueryID, 0);
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, position);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   return (unitQueryID);
}

//==============================================================================
// getGaiaUnitCount
// Unit count from Gaia's perspective, use with caution to avoid cheating.
//==============================================================================
int getGaiaUnitCount(int unitTypeID = -1)
{
   xsSetContextPlayer(0);
   int numberFound = kbUnitCount(0, unitTypeID);
   xsSetContextPlayer(cMyID);
   return (numberFound);
}

//==============================================================================
// getClosestGaiaUnitPosition
// Query closest unit's position from gaia's perspective, use with caution to avoid cheating.
//==============================================================================
vector getClosestGaiaUnitPosition(int unitTypeID = -1, vector position = cInvalidVector, float radius = -1.0)
{
   xsSetContextPlayer(0);
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("getClosestGaiaUnitPositionQuery");
   }

   // Define a query to get all matching units.
   if (unitQueryID != -1)
   {
      kbUnitQuerySetPlayerID(unitQueryID, 0);
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, cUnitStateAlive);
      kbUnitQuerySetPosition(unitQueryID, position);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetAscendingSort(unitQueryID, true);
   }
   else
   {
      xsSetContextPlayer(cMyID);
      return (cInvalidVector);
   }

   kbUnitQueryResetResults(unitQueryID);

   if (kbUnitQueryExecute(unitQueryID) > 0)
   {
      // Get the location of the first(closest) unit.
      vector closestFishPosition = kbUnitGetPosition(kbUnitQueryGetResult(unitQueryID, 0)); 
      xsSetContextPlayer(cMyID);
      return (closestFishPosition);
   }
   xsSetContextPlayer(cMyID);
   return (cInvalidVector);
}


//==============================================================================
// getRandomGaiaUnitPosition
// Query random unit's position from gaia's perspective, use with caution to avoid cheating.
//==============================================================================
vector getRandomGaiaUnitPosition(int unitTypeID = -1, vector position = cInvalidVector, float radius = -1.0)
{
   xsSetContextPlayer(0);
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("getRandomGaiaUnitPositionQuery");
   }

   // Define a query to get all matching units.
   if (unitQueryID != -1)
   {
      kbUnitQuerySetPlayerID(unitQueryID, 0);
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, cUnitStateAlive);
      kbUnitQuerySetPosition(unitQueryID, position);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
   }
   else
   {
      xsSetContextPlayer(cMyID);
      return (cInvalidVector);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);

   if (kbUnitQueryExecute(unitQueryID) > 0)
   {
      // Get the location of a random unit.
      vector RandomFishPosition = kbUnitGetPosition(kbUnitQueryGetResult(unitQueryID, aiRandInt(numberFound))); 
      xsSetContextPlayer(cMyID);
      return (RandomFishPosition);
   }
   xsSetContextPlayer(cMyID);
   return (cInvalidVector);
}


//==============================================================================
// getUnitByTech
// Will return a random unit matching the parameters
//==============================================================================
int getUnitByTech(int unitTypeID = -1, int TechID = -1)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitByTechQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      kbUnitQuerySetPlayerID(unitQueryID, cMyID);
      kbUnitQuerySetPlayerRelation(unitQueryID, -1);
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetTechID(unitQueryID, TechID);
      kbUnitQuerySetState(unitQueryID, cUnitStateAlive);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound > 0)
   {
      return (kbUnitQueryGetResult(unitQueryID, aiRandInt(numberFound)));
   }
   return (-1);
}

//==============================================================================
// getUnitByLocation
// Will return a random unit matching the parameters
//==============================================================================
int getUnitByLocation(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                      vector location = cInvalidVector, float radius = 20.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitLocationQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1);
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, location);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound > 0)
   {
      return (kbUnitQueryGetResult(unitQueryID, aiRandInt(numberFound))); // Return a random dude(tte)
   }
   return (-1);
}

//==============================================================================
// getClosestUnitByLocation
// Will return a random unit matching the parameters
//==============================================================================
int getClosestUnitByLocation(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                             vector location = cInvalidVector, float radius = 20.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitLocationQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1);
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, location);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
      kbUnitQuerySetAscendingSort(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound > 0)
   {
      return (kbUnitQueryGetResult(unitQueryID, 0)); // Return the first unit
   }
   return (-1);
}

//==============================================================================
// AssetiveWall: getClosestVisibleUnitByLocation
// Will return a random unit matching the parameters
//==============================================================================
int getClosestVisibleUnitByLocation(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                             vector location = cInvalidVector, float radius = 20.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitLocationQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1);
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, location);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
      kbUnitQuerySetAscendingSort(unitQueryID, true);
      kbUnitQuerySetSeeableOnly(unitQueryID, true); // AssertiveWall: only change
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   if (numberFound > 0)
   {
      return (kbUnitQueryGetResult(unitQueryID, 0)); // Return the first unit
   }
   return (-1);
}

//==============================================================================
// getUnitCountByLocation
// Returns the number of matching units in the point/radius specified
//==============================================================================
int getUnitCountByLocation(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                           vector location = cInvalidVector, float radius = 20.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscGetUnitLocationQuery");
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1);
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
      kbUnitQuerySetPosition(unitQueryID, location);
      kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   return (kbUnitQueryExecute(unitQueryID));
}

//==============================================================================
// getUnitCountByTactic
//==============================================================================
int getUnitCountByTactic(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive, int tacticID = -1)
{
   int count = 0;
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("tacticUnitQuery");
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }

   // Define a query to get all matching units
   if (unitQueryID != -1)
   {
      if (playerRelationOrID > 1000) // Too big for player ID number
      {
         kbUnitQuerySetPlayerID(unitQueryID, -1);
         kbUnitQuerySetPlayerRelation(unitQueryID, playerRelationOrID);
      }
      else
      {
         kbUnitQuerySetPlayerRelation(unitQueryID, -1);
         kbUnitQuerySetPlayerID(unitQueryID, playerRelationOrID);
      }
      kbUnitQuerySetUnitType(unitQueryID, unitTypeID);
      kbUnitQuerySetState(unitQueryID, state);
   }
   else
   {
      return (0);
   }

   kbUnitQueryResetResults(unitQueryID);
   int numberFound = kbUnitQueryExecute(unitQueryID);
   for (i = 0; < numberFound)
   {
      if (aiUnitGetTactic(kbUnitQueryGetResult(unitQueryID, i)) == tacticID)
      {
         count = count + 1;
   }
   }

   return (count);
}

//==============================================================================
// checkAliveSuitableTradingPost
// Trading Posts can have different purposes when placed on different minor native sockets.
// If you need a specific one you can use this function to get one matching your wanted subCiv.
//==============================================================================
int checkAliveSuitableTradingPost(int subCivID = -1)
{
   int queryID = createSimpleUnitQuery(cUnitTypeTradingPost, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(queryID);
   int tradingPostID = -1;
   for (i = 0; < numberFound)
   {
      tradingPostID = kbUnitQueryGetResult(queryID, i);
      if (kbUnitGetSubCiv(tradingPostID) == subCivID)
      {
         return (tradingPostID); // We've found a Trading Post that has the right subciv so we return this ID and quit.
      }
   }
   return (-1);
}

//==============================================================================
// baseBuildingCount
// Returns how many buildings are in the base.
//==============================================================================
int baseBuildingCount(int baseID = -1, int relation = cPlayerRelationAny, int state = cUnitStateAlive)
{
   int retVal = -1;

   if (baseID >= 0)
   {
      // Check for buildings in the base, regardless of player ID (only baseOwner can have buildings there)
      int owner = kbBaseGetOwner(baseID);
      retVal = getUnitCountByLocation(cUnitTypeBuilding, relation, state,
         kbBaseGetLocation(owner, baseID), kbBaseGetDistance(owner, baseID));
   }

   return (retVal);
}

//==============================================================================
// isProtoUnitAffordable
// Returns whether the unit is affordable by also considering resource crates we have.
//==============================================================================
bool isProtoUnitAffordable(int puid = -1)
{
   int crateQuery = createSimpleUnitQuery(cUnitTypeAbstractResourceCrate, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(crateQuery);
   for (resource = cResourceGold; <= cResourceFood)
   {
      float total = kbResourceGet(resource);
      for (i = 0; < numberFound)
      {
         int crateID = kbUnitQueryGetResult(crateQuery, i);
         total = total + kbUnitGetResourceAmount(crateID, resource) * kbGetPlayerHandicap(cMyID);
      }
      if (total < kbUnitCostPerResource(puid, resource))
      {
         return (false);
   }
   }
   return (true);
}

//==============================================================================
// getMostNeededResource
// Returns which resource we currently need most, obtained via using gResourceNeeds.
//==============================================================================
int getMostNeededResource(bool checkDepletedResources = true)
{
   float neededFood = xsArrayGetFloat(gResourceNeeds, cResourceFood);
   float neededWood = xsArrayGetFloat(gResourceNeeds, cResourceWood);
   float neededGold = xsArrayGetFloat(gResourceNeeds, cResourceGold);
   int retval = cResourceFood;
   
   if (checkDepletedResources == true && gMarketBuySellTypes != 0)
   {
      if ((gMarketBuySellTypes & (1 << cMarketBuyFoodWithGold)) != 0 && neededFood > 0.0)
      {
         return (cResourceFood);
      }
      if ((gMarketBuySellTypes & (1 << cMarketBuyWoodWithGold)) != 0 && neededWood > 0.0)
      {
         return (cResourceWood);
   }

      // cMarketSellFoodForGold and cMarketSellWoodForGold
      if (neededGold > 0.0)
         return (cResourceGold);
   }

   if (neededWood > neededFood)
   {
      retval = cResourceWood;
   }
   else if (neededGold > neededFood)
   {
      retval = cResourceGold;
   }
   if (neededGold > neededWood)
   {
      retval = cResourceGold;
   }
   
   return (retval);
}

//==============================================================================
// getNumberIdleVillagers
// Get number of idle villagers without a plan.
//==============================================================================
int getNumberIdleVillagers(bool reset = true)
{
   int villagerQuery = createSimpleUnitQuery(gEconUnit, cMyID, cUnitStateAlive);
   kbUnitQuerySetActionType(villagerQuery, cActionTypeIdle);
   int numberFound = kbUnitQueryExecute(villagerQuery);
   static int numberIdleVillagers = 0;

   if (reset == true)
   {
      for (i = 0; < numberFound)
      {
         int unitID = kbUnitQueryGetResult(villagerQuery, i);
         if (kbUnitGetPlanID(unitID) >= 0)
         {
            continue;
         }
         numberIdleVillagers = numberIdleVillagers + 1;
      }
   }

   return (numberIdleVillagers);
}

//==============================================================================
/* getPlayerArmyHPs
   Queries all land military units.
   Totals hitpoints (ideal if considerHealth false, otherwise actual.)
   Returns total
*/
//==============================================================================
float getPlayerArmyHPs(int playerID = -1, bool considerHealth = false)
{
   int queryID = -1; // Will recreate each time, as changing player trashes existing query settings.

   if (playerID <= 0)
   {
      return (-1.0);
   }

   queryID = kbUnitQueryCreate("getStrongestEnemyArmyHPs");
   kbUnitQuerySetIgnoreKnockedOutUnits(queryID, true);
   kbUnitQuerySetPlayerID(queryID, playerID, true);
   kbUnitQuerySetUnitType(queryID, cUnitTypeLogicalTypeLandMilitary);
   kbUnitQuerySetState(queryID, cUnitStateAlive);
   kbUnitQueryResetResults(queryID);
   kbUnitQueryExecute(queryID);

   return (kbUnitQueryGetUnitHitpoints(queryID, considerHealth));
}

//==============================================================================
// createSimpleResearchPlan
//==============================================================================
int createSimpleResearchPlan(int techID = -1, int buildingPUID = -1, int escrowID = cRootEscrowID,
                             int pri = 50, int resourcePri = 50)
{
   int planID = aiPlanCreate("Simple Research Plan, " + kbGetTechName(techID), cPlanResearch);
   if (planID < 0)
   {
      debugTechs("Failed to create Simple Research Plan for " + kbGetTechName(techID));
   }
   else
   {
      aiPlanSetVariableInt(planID, cResearchPlanTechID, 0, techID);
      aiPlanSetVariableInt(planID, cResearchPlanBuildingTypeID, 0, buildingPUID);
      aiPlanSetDesiredPriority(planID, pri);
      aiPlanSetDesiredResourcePriority(planID, resourcePri);
      aiPlanSetActive(planID);
      debugTechs("Created a Simple Research Plan for: " + kbGetTechName(techID) + " with plan number: " + planID);
   }

   return (planID);
}

//==============================================================================
// createProtoUnitCommandResearchPlan
//==============================================================================
int createProtoUnitCommandResearchPlan(int protoUnitCommandID = -1, int buildingID = -1, int escrowID = cRootEscrowID,
                             int pri = 50, int resourcePri = 50)
{
   int planID = aiPlanCreate("Proto Unit Command Research Plan, " + kbProtoUnitCommandGetName(protoUnitCommandID), cPlanResearch);
   if (planID < 0)
   {
      debugTechs("Failed to create Proto Unit Command Research Plan for " + kbProtoUnitCommandGetName(protoUnitCommandID));
   }
   else
   {
      aiPlanSetVariableInt(planID, cResearchPlanProtoUnitCommandID, 0, protoUnitCommandID);
      aiPlanSetVariableInt(planID, cResearchPlanBuildingID, 0, buildingID);
      aiPlanSetDesiredPriority(planID, pri);
      aiPlanSetDesiredResourcePriority(planID, resourcePri);
      aiPlanSetActive(planID);
      debugTechs("Created a Proto Unit Command Research Plan for: " + kbProtoUnitCommandGetName(protoUnitCommandID) + " with plan number: " + planID);
   }

   return (planID);
}

//==============================================================================
// createSimpleResearchPlanSpecificBuilding
//==============================================================================
int createSimpleResearchPlanSpecificBuilding(int techID = -1, int buildingID = -1, int escrowID = cRootEscrowID,
                                             int pri = 50, int resourcePri = 50)
{
   int planID = aiPlanCreate("Simple Research Plan Specific Building, " + kbGetTechName(techID), cPlanResearch);
   if (planID < 0)
   {
      debugTechs("Failed to create Simple Research Plan Specific Building for " + kbGetTechName(techID));
   }
   else
   {
      aiPlanSetVariableInt(planID, cResearchPlanTechID, 0, techID);
      aiPlanSetVariableInt(planID, cResearchPlanBuildingID, 0, buildingID);
      aiPlanSetDesiredPriority(planID, pri);
      aiPlanSetDesiredResourcePriority(planID, resourcePri);
      aiPlanSetActive(planID);
      debugTechs("Created a Simple Research Plan Specific Building for: " + kbGetTechName(techID) + " with plan number: " + planID);
   }

   return (planID);
}

//==============================================================================
// researchSimpleTech
//==============================================================================
bool researchSimpleTech(int techID = -1, int buildingPUID = -1, int buildingID = -1, int resourcePri = 50)
{
   int techStatus = kbTechGetStatus(techID);
   if (techStatus == cTechStatusActive)
   {
      return (true);
   }
   if (techStatus == cTechStatusUnobtainable)
   {
      return (false);
   } // If it's Obtainable we continue with the logic.

   int upgradePlanID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, techID);
   if (upgradePlanID < 0) // We have no plan yet, check if we should create one.
   {
      if (buildingPUID >= 0)
      {
         createSimpleResearchPlan(techID, buildingPUID, cMilitaryEscrowID, 50, resourcePri);
      }
      else
      {
         createSimpleResearchPlanSpecificBuilding(techID, buildingID, cMilitaryEscrowID, 50, resourcePri);
      }
   }
   return (false);
}

bool researchSimpleTechShouldCreate() { return (true); }
//==============================================================================
// researchSimpleTechByCondition
//==============================================================================
bool researchSimpleTechByCondition(int techID = -1, bool() shouldCreate = researchSimpleTechShouldCreate,
                                   int buildingPUID = -1, int buildingID = -1, int resourcePri = 50)
{
   int techStatus = kbTechGetStatus(techID);
   if (techStatus == cTechStatusActive)
   {
      return (true);
   }
   if (techStatus == cTechStatusUnobtainable)
   {
      return (false);
   } // If it's Obtainable we continue with the logic.

   bool create = shouldCreate();
   int upgradePlanID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, techID);
   if (upgradePlanID >= 0) // We have a plan already.
   {
      if (create == false) // Check if we need to destroy it.
      {
         aiPlanDestroy(upgradePlanID);
      }
   }
   else if (create == true) // We have no plan yet, check if we should create one.
   {
      if (buildingPUID >= 0)
      {
         createSimpleResearchPlan(techID, buildingPUID, cMilitaryEscrowID, 50, resourcePri);
      }
      else
      {
         createSimpleResearchPlanSpecificBuilding(techID, buildingID, cMilitaryEscrowID, 50, resourcePri);
      }
   }
   return (false);
}

//==============================================================================
// researchSimpleTechByConditionEventHandler
//==============================================================================
bool researchSimpleTechByConditionEventHandler(int techID = -1, bool() shouldCreate = researchSimpleTechShouldCreate,
                                               string eventHandlerName = "", int buildingPUID = -1, int buildingID = -1,
                                               int resourcePri = 50)
{
   int techStatus = kbTechGetStatus(techID);
   if (techStatus == cTechStatusActive)
   {
      return (true);
   }
   if (techStatus == cTechStatusUnobtainable)
   {
      return (false);
   } // If it's Obtainable we continue with the logic.

   bool create = shouldCreate();
   int upgradePlanID = aiPlanGetIDByTypeAndVariableType(cPlanResearch, cResearchPlanTechID, techID);
   if (upgradePlanID >= 0) // We have a plan already.
   {
      if (create == false) // Check if we need to destroy it.
      {
         aiPlanDestroy(upgradePlanID);
      }
   }
   else if (create == true) // We have no plan yet, check if we should create one.
   {
      if (buildingPUID >= 0)
      {
         upgradePlanID = createSimpleResearchPlan(techID, buildingPUID, cMilitaryEscrowID, 50, resourcePri);
      }
      else
      {
         upgradePlanID = createSimpleResearchPlanSpecificBuilding(techID, buildingID, cMilitaryEscrowID, 50, resourcePri);
      }
      aiPlanSetEventHandler(upgradePlanID, cPlanEventStateChange, eventHandlerName);
   }
   return (false);
}

//==============================================================================
// createNativeResearchPlan
//==============================================================================
int createNativeResearchPlan(int tacticID = cTacticNormal, int pri = 50, int need = 1, int want = 5, int max = 10)
{
   int buildingID = getUnit(cUnitTypeCommunityPlaza);
   int planID = -1;

   if (buildingID == -1)
   {
      return (-1);
   }

   debugCore("Creating native research plan for tactic ID " + tacticID);
   planID = aiPlanCreate("NativeResearch " + tacticID, cPlanNativeResearch);

   if (planID < 0)
   {
      debugCore("Failed to create simple research plan for " + tacticID);
      return (-1);
   }
   else
   {
      // TODO: Change tactic ID based on power you want and remove use of tech ID
      aiPlanSetVariableInt(planID, cNativeResearchPlanTacticID, 0, tacticID);
      aiPlanSetVariableInt(planID, cNativeResearchPlanBuildingID, 0, buildingID);
      aiPlanSetDesiredPriority(planID, pri);
      aiPlanAddUnitType(planID, gEconUnit, need, want, max);
      aiPlanSetActive(planID);
   }
   return (planID);
}

//==============================================================================
// createSimpleMaintainPlan
//==============================================================================
int createSimpleMaintainPlan(int puid = -1, int number = 1, bool economy = true, int baseID = -1, int batchSize = 1)
{
   // Create a the plan name.
   string planName = "Military";
   if (economy == true)
   {
      planName = "Economy";
   }
   planName = planName + kbGetProtoUnitName(puid) + "Maintain";
   int planID = aiPlanCreate(planName, cPlanTrain);
   if (planID < 0)
   {
      return (-1);
   }

   // Unit type.
   aiPlanSetVariableInt(planID, cTrainPlanUnitType, 0, puid);
   // Number.
   aiPlanSetVariableInt(planID, cTrainPlanNumberToMaintain, 0, number);
   // Batch size
   aiPlanSetVariableInt(planID, cTrainPlanBatchSize, 0, batchSize);

   // If we have a base ID, use it.
   if (baseID >= 0)
   {
      aiPlanSetBaseID(planID, baseID);
      if (economy == false)
      {
         aiPlanSetVariableVector(planID, cTrainPlanGatherPoint, 0, kbBaseGetMilitaryGatherPoint(cMyID, baseID));
   }
   }

   aiPlanSetActive(planID);
   return (planID);
}

//==============================================================================
// createSimpleBuildPlan
// Does all the necessary set up to get a valid build plan at the position we want.
// It returns the plan ID of the last made plan (in the case of multiple plans in 1 go).
//==============================================================================
int createSimpleBuildPlan(int puid = -1, int numberWanted = 1, int pri = 100, bool economy = true,
                          int escrowID = -1, int baseID = -1, int numberBuilders = 1, int parentPlanID = -1,
                          bool noQueue = false)
{
   if (cvOkToBuild == false)
   {
      return (-1); // Return invalid plan ID.
   }

   int planID = -1;

   // Create the right number of plans.
   for (i = 0; < numberWanted)
   {
      planID = aiPlanCreate("Simple Build Plan for " + numberWanted + " " + kbGetUnitTypeName(puid), cPlanBuild, parentPlanID);
      if (planID < 0) // We somehow failed to create a plan.
      {
         debugBuildings("Failed to create a Simple Build Plan for " + kbGetUnitTypeName(puid));
         return (-1);
      }
      // What to build.
      aiPlanSetVariableInt(planID, cBuildPlanBuildingTypeID, 0, puid);

      // 3 Meter separation between buildings, this can still be overwritten in selectBuildPlanPosition.
      aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 6.0);
      if (puid == gFarmUnit || puid == gPlantationUnit || puid == cUnitTypedeBasilica)
      {
         aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 12.0);
      }

      // Set the priority.
      aiPlanSetDesiredPriority(planID, pri);

      // Add builders to the plan if that is requested.
      // This only adds the needed/wanted/minimum variables of the unittype to the plan not the actual builders.
      if (numberBuilders > 0)
      {
         if (addBuilderToPlan(planID, puid, numberBuilders) == false)
         {
            aiPlanDestroy(planID);
            return (-1);
         }
      }

      // If we don't create a queue all the plans will take builders instantly.
      // If those builders are Settlers for example you will suddenly have a lot less gathering.
      if (noQueue == true)
      {
         selectBuildPlanPosition(planID, puid, baseID);
      }
      else
      {
         bool queue = (i > 0);
         if (queue == false)
         {
            // Position.
            if (selectBuildPlanPosition(planID, puid, baseID) == false)
            {
               queue = true;
            }
         }

         if (queue == true)
         {
            // Queue this building.
            aiPlanSetActive(planID, false);
            // Save the base ID.
            aiPlanSetBaseID(planID, baseID);

            int queueSize = xsArrayGetSize(gQueuedBuildPlans);

            queue = false;

            for (j = 0; < queueSize)
            {
               if (xsArrayGetInt(gQueuedBuildPlans, j) >= 0)
               {
                  continue;
               }
               xsArraySetInt(gQueuedBuildPlans, j, planID);
               queue = true;
               break;
            }

            if (queue == false)
            {
               xsArrayResizeInt(gQueuedBuildPlans, queueSize + 1);
               xsArraySetInt(gQueuedBuildPlans, queueSize, planID);
            }

            continue;
         }
      }

      debugBuildings("Created a Simple Build Plan for: " + numberWanted + " " + kbGetUnitTypeName(puid) +
         " with plan number: " + planID);
      aiPlanSetActive(planID, true);
   }

   return (planID); // Only really useful if numberWanted == 1, otherwise returns last plan ID.
}

//==============================================================================
// createLocationBuildPlan
//==============================================================================
int createLocationBuildPlan(int puid = -1, int number = 1, int pri = 100, bool economy = true,
                            int escrowID = -1, vector position = cInvalidVector, int numberBuilders = 1)
{
   if (cvOkToBuild == false)
   {
      return (-1);
   }
   // Create the right number of plans.
   for (i = 0; < number)
   {
      int planID = aiPlanCreate("Location Build Plan, " + number + " " + kbGetUnitTypeName(puid), cPlanBuild);
      if (planID < 0)
      {
         return (-1);
      }
      // What to build
      aiPlanSetVariableInt(planID, cBuildPlanBuildingTypeID, 0, puid);

      aiPlanSetVariableVector(planID, cBuildPlanCenterPosition, 0, position);
      aiPlanSetVariableFloat(planID, cBuildPlanCenterPositionDistance, 0, 30.0);

      // 3 meter separation
      aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 3.0);
      if (puid == gFarmUnit)
      {
         aiPlanSetVariableFloat(planID, cBuildPlanBuildingBufferSpace, 0, 8.0);
      }

      // Priority.
      aiPlanSetDesiredPriority(planID, pri);

      // Builders.
      if (numberBuilders > 0 && addBuilderToPlan(planID, puid, numberBuilders) == false)
      {
         aiPlanDestroy(planID);
         return (-1);
      }

      aiPlanSetVariableVector(planID, cBuildPlanInfluencePosition, 0, position);              // Influence toward position
      aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionDistance, 0, 100.0);          // 100m range.
      aiPlanSetVariableFloat(planID, cBuildPlanInfluencePositionValue, 0, 200.0);             // 200 points max
      aiPlanSetVariableInt(planID, cBuildPlanInfluencePositionFalloff, 0, cBPIFalloffLinear); // Linear slope falloff

      debugBuildings("Created a Location Build Plan for: " + kbGetUnitTypeName(puid) + " with plan number: " + planID);
      aiPlanSetActive(planID);
   }
   return (planID); // Only really useful if number == 1, otherwise returns last value.
}

//==============================================================================
// createRepairPlan
//==============================================================================
int createRepairPlan(int pri = 50)
{
   // Check if we're under attack.
   if (gDefenseReflexBaseID == kbBaseGetMainID(cMyID))
   {
      return (-1);
   }

   int buildingQueryID = createSimpleUnitQuery(cUnitTypeBuilding, cMyID, cUnitStateAlive);
   int buildingID = -1;
   int buildingToRepair = -1;
   int buildingTypeID = -1;
   int planID = -1;

   int numberFound = kbUnitQueryExecute(buildingQueryID);
   for (i = 0; < numberFound)
   {
      // search for important buildings, this list seems to be wildly incomplete.
      buildingID = kbUnitQueryGetResult(buildingQueryID, i);
      buildingTypeID = kbUnitGetProtoUnitID(buildingID);
      if ((buildingTypeID == cUnitTypeFortFrontier) || (buildingTypeID == cUnitTypeFactory) || (buildingTypeID == cUnitTypeypDojo) ||
          (buildingTypeID == cUnitTypeTownCenter) || (buildingTypeID == cUnitTypedeSPCCommandPost) || (buildingTypeID == cUnitTypeTradingPost))
      {
         if (kbUnitGetHealth(buildingID) < 0.75)
         {
            buildingToRepair = buildingID;
            break;
         }
      }
   }

   if (buildingToRepair == -1)
   {
      for (i = 0; < numberFound)
      {
         buildingID = kbUnitQueryGetResult(buildingQueryID, i);
         if (kbUnitGetHealth(buildingID) < 0.5)
         {
            buildingToRepair = buildingID;
            break;
         }
      }
   }

   if (buildingToRepair == -1)
   {
      return (-1);
   }

   debugBuildings("Creating repair plan for building ID " + buildingToRepair);
   planID = aiPlanCreate(kbGetUnitTypeName(kbUnitGetProtoUnitID(buildingToRepair)) +
      " Repair " + buildingToRepair, cPlanRepair);

   if (planID < 0)
   {
      debugBuildings("Failed to create simple repair plan for " + buildingID);
      return (-1);
   }
   else
   {
      aiPlanSetVariableInt(planID, cRepairPlanTargetID, 0, buildingToRepair);
      aiPlanSetVariableBool(planID, cRepairPlanPersistent, 0, false);
      aiPlanSetDesiredResourcePriority(planID, pri);
      aiPlanSetActive(planID);
   }
   return (planID);
}

//==============================================================================
// createTransportPlan
//==============================================================================
int createTransportPlan(vector gatherPoint = cInvalidVector, vector targetPoint = cInvalidVector,
                        int pri = 50, bool returnWhenDone = true)
{
   int shipQueryID = createSimpleUnitQuery(cUnitTypeTransport, cMyID, cUnitStateAlive);
   int numberFound = kbUnitQueryExecute(shipQueryID);
   int shipID = -1;
   float shipHitpoints = 0.0;
   int unitPlanID = -1;
   int transportID = -1;
   float transportHitpoints = 0.0;
   
   for (i = 0; < numberFound)
   {
      shipID = kbUnitQueryGetResult(shipQueryID, i);
      unitPlanID = kbUnitGetPlanID(shipID);
      if ((unitPlanID >= 0) && ((aiPlanGetDesiredPriority(unitPlanID) > pri) || (aiPlanGetType(unitPlanID) == cPlanTransport)))
      {
         continue;
      }
      shipHitpoints = kbUnitGetCurrentHitpoints(shipID);
      if (shipHitpoints > transportHitpoints)
      {
         transportID = shipID;
         transportHitpoints = shipHitpoints;
      }
   }

   if (transportID < 0)
   {
      return (-1);
   }

   int planID = aiPlanCreate(kbGetUnitTypeName(kbUnitGetProtoUnitID(transportID)) + " Transport Plan, ", cPlanTransport);

   if (planID < 0)
   {
      return (-1);
   }

   aiPlanSetVariableInt(planID, cTransportPlanTransportID, 0, transportID);
   aiPlanSetVariableInt(planID, cTransportPlanTransportTypeID, 0, kbUnitGetProtoUnitID(transportID));

   // Desired number of transport ships increases through ages. 
   int age = kbGetAge();
   int minShips = 1;
   int wantedShips = 1;
   int maxShips = 1;
   /*if (age <= cAge2)
   {
      minShips = 1;
      wantedShips = 2;
      maxShips = 3;
   }
   if (age == cAge3)
   {
      minShips = 1;
      wantedShips = 2;
      maxShips = 4;         
   }
   if (age == cAge4)
   {
      minShips = 1;
      wantedShips = 2;
      maxShips = 5;         
   }
   if (age == cAge5)
   {
      minShips = 1;
      wantedShips = 3;
      maxShips = 6;         
   }*/
   // must add the transport unit otherwise other plans might try to use this unit
   aiPlanAddUnitType(planID, kbUnitGetProtoUnitID(transportID), minShips, wantedShips, maxShips);

   if (aiPlanAddUnit(planID, transportID) == false)
   {
      aiPlanDestroy(planID);
      return (-1);
   }

   aiPlanSetVariableVector(planID, cTransportPlanGatherPoint, 0, gatherPoint);
   aiPlanSetVariableVector(planID, cTransportPlanTargetPoint, 0, targetPoint);
   aiPlanSetVariableBool(planID, cTransportPlanReturnWhenDone, 0, returnWhenDone);
   aiPlanSetVariableBool(planID, cTransportPlanPersistent, 0, false);
   aiPlanSetVariableBool(planID, cTransportPlanMaximizeXportMovement, 0, true);
   aiPlanSetVariableInt(planID, cTransportPlanPathType, 0, cTransportPathTypePoints);

   aiPlanSetRequiresAllNeedUnits(planID, true);
   aiPlanSetDesiredPriority(planID, pri);
   aiPlanSetActive(planID);

   return (planID);
}

//==============================================================================
// createMainBase
//==============================================================================
int createMainBase(vector mainVec = cInvalidVector)
{
   debugBuildings("Creating main base at " + mainVec);
   if (mainVec == cInvalidVector)
   {
      return (-1);
   }

   int oldMainID = kbBaseGetMainID(cMyID);

   while (oldMainID >= 0)
   {
      debugBuildings("Old main base was " + oldMainID + " at " + kbBaseGetLocation(cMyID, oldMainID));

      // Remove old base's resource breakdowns
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeEasy, oldMainID);
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHunt, oldMainID);
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHerdable, oldMainID);
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeHuntAggressive, oldMainID);
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeFish, oldMainID);
      aiRemoveResourceBreakdown(cResourceFood, cAIResourceSubTypeFarm, oldMainID);
      aiRemoveResourceBreakdown(cResourceWood, cAIResourceSubTypeEasy, oldMainID);
      aiRemoveResourceBreakdown(cResourceGold, cAIResourceSubTypeEasy, oldMainID);

      kbBaseDestroy(cMyID, oldMainID);
      oldMainID = kbBaseGetMainID(cMyID);
   }

   // Also destroy bases nearby that can overlap with our radius.
   for (i = 0; < kbBaseGetNumber(cMyID))
   {
      int baseID = kbBaseGetIDByIndex(cMyID, i);
      if (distance(kbBaseGetLocation(cMyID, baseID), mainVec) < kbBaseGetDistance(cMyID, baseID))
      {
         kbBaseDestroy(cMyID, baseID);
   }
   }

   int newBaseID = kbBaseCreate(cMyID, "Base" + kbBaseGetNextID(), mainVec, 50.0);
   debugBuildings("New main base ID is " + newBaseID);
   if (newBaseID > -1)
   {
      // Figure out the front vector.
      vector baseFront = xsVectorNormalize(kbGetMapCenter() - mainVec);
      kbBaseSetFrontVector(cMyID, newBaseID, baseFront);
      debugBuildings("Setting front vector to " + baseFront);
      // Military gather point.
      float milDist = 40.0;
      int mainAreaGroupID = kbAreaGroupGetIDByPosition(mainVec);
      while (kbAreaGroupGetIDByPosition(mainVec + (baseFront * milDist)) != mainAreaGroupID)
      {
         milDist = milDist - 5.0;
         if (milDist < 6.0)
         {
            break;
      }
      }
      vector militaryGatherPoint = mainVec + (baseFront * milDist);

      kbBaseSetMilitaryGatherPoint(cMyID, newBaseID, militaryGatherPoint);
      // Set the other flags.
      kbBaseSetMilitary(cMyID, newBaseID, true);
      kbBaseSetEconomy(cMyID, newBaseID, true);
      // Set the resource distance limit.

      // 200m x 200m map, assume I'm 25 meters in, I'm 150m from enemy base.  This sets the range at 80m.
      //(cMyID, newBaseID, (kbGetMapXSize() + kbGetMapZSize())/5);   // 40% of average of map x and z dimensions.
      float dist = distance(kbGetMapCenter(), kbBaseGetLocation(cMyID, newBaseID));
      // Limit our distance, don't go pass the center of the map
      if (dist < 150.0)
      {
         kbBaseSetMaximumResourceDistance(cMyID, newBaseID, dist);
      }
      else
      {
         kbBaseSetMaximumResourceDistance(cMyID, newBaseID, 50.0); // down from 150, 100 led to age-2 gold starvation
      }

      kbBaseSetSettlement(cMyID, newBaseID, true);
      // Set the main-ness of the base.
      kbBaseSetMain(cMyID, newBaseID, true);

      // Add the TC, if any.
      int tcID = getUnit(cUnitTypeAgeUpBuilding, cMyID, cUnitStateABQ);
      if (tcID >= 0)
      {
         kbBaseAddUnit(cMyID, newBaseID, tcID);
   }
   }

   // Move the defend plan and reserve plan
   xsEnableRule("endDefenseReflexDelay"); // Delay so that new base ID will exist

   return (newBaseID);
}

//==============================================================================
// handleTributeRequest
// Checks whether we have enough resources to be able to afford a tribute.
// And if we have enough we also make the tribute here.
//==============================================================================
bool handleTributeRequest(int resourceToTribute = -1, int playerToTributeTo = -1)
{
   int amountAvailable = xsArrayGetFloat(gResourceNeeds, resourceToTribute) * -0.85; // Leave room for tribute penalty.
   if (aiResourceIsLocked(resourceToTribute) == true)
   {
      amountAvailable = 0.0;
   }
   if (amountAvailable > 100.0) // We will tribute something.
   { 
      debugUtilities("We will tribute some: " + kbGetResourceName(resourceToTribute) + " to player: " + playerToTributeTo);
      gLastTribSentTime = xsGetTime();
      if (amountAvailable > 200.0)
      {
         aiTribute(playerToTributeTo, resourceToTribute, amountAvailable / 2);
      }
      else
      {
         aiTribute(playerToTributeTo, resourceToTribute, 100.0);
      }
      return (true);
   }
   debugUtilities("We don't have enough: "+ kbGetResourceName(resourceToTribute) + " to tribute to player: " + playerToTributeTo);
   return (false);
}

//==============================================================================
/* isDefendingOrAttacking
   We only allow 1 "real" combat plan to be active at a time
   So that would be either a main attack plan or a defend plan not being one
   of the 5 persistent combat defend plans. So exclude all those in this search.
*/
//==============================================================================
bool isDefendingOrAttacking()
{
   int numPlans = aiPlanGetActiveCount();
   int existingPlanID = -1;
   
   for (int i = 0; i < numPlans; i++)
   {
      existingPlanID = aiPlanGetIDByActiveIndex(i);
      if (aiPlanGetType(existingPlanID) != cPlanCombat)
      {
         continue;
      }
      //if (aiPlanGetType(existingPlanID) == gLandAttackPlanID)
      //{
      //   return (true);
      //}
      if (aiPlanGetVariableInt(existingPlanID, cCombatPlanCombatType, 0) == cCombatPlanCombatTypeDefend)
      {
         if ((existingPlanID != gExplorerControlPlan) &&
             (existingPlanID != gLandDefendPlan0) && 
             (existingPlanID != gLandReservePlan) && 
             (existingPlanID != gHealerPlan) && 
             (existingPlanID != gNavyRepairPlan) && 
             (existingPlanID != gNavyDefendPlan) &&
             (existingPlanID != gNavyAttackPlan) &&
             (existingPlanID != gCoastalGunPlan) &&
             (existingPlanID != gEndlessWaterRaidPlan)) // AssertiveWall: Don't stop if there's navy attack plans
         {
            debugUtilities("isDefendingOrAttacking: don't create another combat plan because we already have one named: "
               + aiPlanGetName(existingPlanID));
            return (true);
         }
      }
      else // Attack plan.
      {
         if ((aiPlanGetParentID(existingPlanID) < 0) && // No parent so not a reinforcing child plan.
             (existingPlanID != gNavyAttackPlan && existingPlanID != gCoastalGunPlan && existingPlanID != gEndlessWaterRaidPlan))
         {
            debugUtilities("isDefendingOrAttacking: don't create another combat plan because we already have one named: "
               + aiPlanGetName(existingPlanID));
            return (true);
         }
      }
   }

   return (false);
}

