//==============================================================================
/* aiHumanAssists.xs
   
   Create an AI for Definitive Edition that just prepares the kb & sets up some basic plans for the Human players to use for things like auto-scout and managing resource gatherers.

*/
//==============================================================================

extern float gTSFactorDistance = -200.0;  // negative is good
extern float gTSFactorPoint = 10.0;			// positive is good
extern float gTSFactorTimeToDone = 0.0;	// positive is good
extern float gTSFactorBase = 100.0;			// positive is good
extern float gTSFactorDanger = -10.0;		// negative is good

//==============================================================================
// main
//==============================================================================
void main(void)
{
   aiEcho("Human player assists AI startup.");
   aiEcho("Game type is " + aiGetGameType() + ", 0=Scn, 1=Saved, 2=Rand, 3=GC, 4=Cmpgn");
   aiEcho("Map name is " + cRandomMapName);

   aiRandSetSeed(-1);         // Set our random seed.  "-1" is a random init.
   kbAreaCalculate();         // Analyze the map, create area matrix
   aiSetEscrowsDisabled(true); // Disable escrows so we can have full control of our resources

   //-- set the default Resource Selector factor.
   kbSetTargetSelectorFactor(cTSFactorDistance, gTSFactorDistance);
   kbSetTargetSelectorFactor(cTSFactorPoint, gTSFactorPoint);
   kbSetTargetSelectorFactor(cTSFactorTimeToDone, gTSFactorTimeToDone);
   kbSetTargetSelectorFactor(cTSFactorBase, gTSFactorBase);
   kbSetTargetSelectorFactor(cTSFactorDanger, gTSFactorDanger);

   xsEnableRule("tradeCog");
}

//==============================================================================
// distance
//
// Will return a float with the 3D distance between two vectors
//==============================================================================
float assistDistance(vector v1 = cInvalidVector, vector v2 = cInvalidVector)
{
   vector delta = v1 - v2;
   return (xsVectorLength(delta));
}

//==============================================================================
// createSimpleAssistUnitQuery
//==============================================================================
int createSimpleAssistUnitQuery(int unitTypeID = -1, int playerRelationOrID = cMyID, int state = cUnitStateAlive,
                          vector position = cInvalidVector, float radius = -1.0)
{
   static int unitQueryID = -1;

   // If we don't have the query yet, create one.
   if (unitQueryID < 0)
   {
      unitQueryID = kbUnitQueryCreate("miscSimpleUnitQuery Unit Type: " + unitTypeID);
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
      //kbUnitQuerySetPosition(unitQueryID, position);
      //kbUnitQuerySetMaximumDistance(unitQueryID, radius);
      kbUnitQuerySetIgnoreKnockedOutUnits(unitQueryID, true);
   }
   else
   {
      return (-1);
   }

   kbUnitQueryResetResults(unitQueryID);
   return (unitQueryID);
}

vector getNewDockLoc(vector cogLoc = cInvalidVector)
{
   if (cogLoc == cInvalidVector) return cInvalidVector;

   vector dockLoc = cInvalidVector;
   int dockQuery = -1;
   int dockCount = 0;
   int newDockDestinationID = -1;
   int dockResultRandInt = -1;
   
   dockQuery = createSimpleAssistUnitQuery(cUnitTypeHansaTradePoint, cPlayerRelationAlly, cUnitStateAlive);
   dockCount = kbUnitQueryExecute(dockQuery);

   dockResultRandInt = aiRandInt(dockCount);
   newDockDestinationID = kbUnitQueryGetResult(dockQuery, dockResultRandInt);
   if (assistDistance(kbUnitGetPosition(newDockDestinationID), cogLoc) > 20)
   {
      dockLoc = kbUnitGetPosition(newDockDestinationID);  
   }
   else if (dockResultRandInt > 0)
   {
      dockLoc = kbUnitGetPosition(kbUnitQueryGetResult(dockQuery, dockResultRandInt - 1));
   }

   return dockLoc;
}

rule tradeCog
inactive
minInterval 2
{
   int tradeCogID = -1;
   int tradeCogQuery = -1;
   int cogNum = -1;
   vector cogLoc = cInvalidVector;
   vector newDockLoc = cInvalidVector;

   tradeCogQuery = createSimpleAssistUnitQuery(cUnitTypezpHanseaticTradeship, cMyID, cUnitStateAlive);
   cogNum = kbUnitQueryExecute(tradeCogQuery);

   for(i = 0; < cogNum)
   {
      tradeCogID = kbUnitQueryGetResult(tradeCogQuery, i);
      if (kbUnitGetActionType(tradeCogID) == cActionTypeIdle)
      {
         cogLoc = kbUnitGetPosition(tradeCogID);
         newDockLoc = getNewDockLoc(cogLoc);

         if (newDockLoc != cInvalidVector)
         {
            aiTaskUnitMove(tradeCogID, newDockLoc);
         }
      }
   }
}

