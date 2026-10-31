//==============================================================================
/* aiAttackSystem.xs

   File for the new attack system. 
   
   This system is designed to completely replace attack and defend plans.

   The system is written to manage military from several levels:
      - Individual Actions
      - Tactical Movements
      - Operational Analysis
      - Strategic Analysis


*/
//==============================================================================

//==============================================================================
// Globals
//==============================================================================
extern int gAttackSystemPlanID = -1;
extern vector gAttackSystemOperationalLocation = cInvalidVector;
extern int gAttackSystemOperationalGoal = -1;
extern int gAttackSystemStrategicGoal = -1;
extern int gAttackSystemStrategicEnemy = -1;
extern int gAttackSystemState = -1;

extern const int cOperationalGoalAdvance = 0;            // Try to advance and move forward
extern const int cOperationalGoalHold = 1;               // Try to hold, do not try to take more territory
extern const int cOperationalGoalRegroup = 2;            // Pull back and regroup forces

extern const int cStrategicGoalDefend = 0;               // Don't try to attack, just defend the base and allies
extern const int cStrategicGoalMapControl = 1;           // Use the army to gain map control
extern const int cStrategicGoalAttrit = 2;               // Slowly advance, gaining map control and destroying as much enemy stuff as possible
extern const int cStrategicGoalManuever = 3;              // Attempt to manuever into enemy's weak points

extern const int cAttackSystemTacticAttack = 0;          // Attack a point
extern const int cAttackSystemTacticHold = 1;            // Try to hold a point
extern const int cAttackSystemTacticDelay = 2;           // Attempt to slow an enemy army down
extern const int cAttackSystemTacticRaid = 3;            // Attack a point, but retreat at first sign of trouble

extern const int cAttackSystemStateIdle = 0;             // Sitting idle
extern const int cAttackSystemStateMoving = 1;           // Moving to a destination
extern const int cAttackSystemStateDefending = 2;        // Defending a position. Different than idle
extern const int cAttackSystemStateAttacking = 3;        // Reached the thing we want to attack, and attacking it

extern bool gAttackSystemInCombat = false;               // Stores whether our forces are in combat or not



//==============================================================================
// Utility functions
//==============================================================================

//==============================================================================
// getCulvType
//    Returns the unit type of the civ's culvering unit
//==============================================================================
int getCulvType(void)
{
   switch(cMyCiv) 
   {
      case cCivIndians : 
      {
         return cUnitTypeypSiegeElephant;
      }
      case cCivJapanese :
      case cCivSPCJapanese :
      case cCivSPCJapaneseEnemy : 
      {
         return cUnitTypeypFlamingArrow;
      }
      case cCivChinese :
      case cCivSPCChinese :
      {
         return cUnitTypeypHandMortar;
      }
      case cCivXPSioux :
      {
         return -1;
      }
      case cCivXPIroquois :
      {
         return cUnitTypexpLightCannon;
      }
      case cCivXPAztec :
      {
         return cUnitTypexpArrowKnight;
      }
      case cCivDEInca :
      {  // Inca will use huaracas (deSlinger) as dragoons
         return -1;
      }
      default : 
      {
         return cUnitTypeCulverin;
      }
   }
}

//==============================================================================
// getUnitType
//    Handles the main unit types: Heavy Inf, Heavy Cav, Skirmisher, Dragoon,
//       pike, falconet, culverin, mortar, 
//    Note: Culverin is used as a default type for all culv units
//==============================================================================
int getUnitType(int unitID = -1, int playerID = cMyID)
{

   if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractHeavyCavalry) == true)
   { return cUnitTypeAbstractHeavyCavalry;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractCoyoteMan) == true)
   { return cUnitTypeAbstractCoyoteMan;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractLightInfantry) == true)
   { return cUnitTypeAbstractLightInfantry;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractLightCavalry) == true)
   { return cUnitTypeAbstractLightCavalry;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractPikeman) == true)
   { return cUnitTypeAbstractPikeman;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractHandInfantry) == true)
   { return cUnitTypeAbstractHandInfantry;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractHeavyInfantry) == true)
   { return cUnitTypeAbstractHeavyInfantry;}
   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), getCulvType()) == true)
   { return cUnitTypeCulverin;}


   else if (kbProtoUnitIsType(playerID, kbUnitGetProtoUnitID(unitID), cUnitTypeAbstractPikeman) == true)
   { return cUnitTypeAbstractPikeman;}

   return (-1);

}


//==============================================================================
// End Utility functions
//==============================================================================




//==============================================================================
/*
   individualActions

   handles each individual unit and manages who they should attack and in what
   stance
*/
//==============================================================================
void individualActions(int planID = -1)
{
   int numUnits = aiPlanGetNumberUnits(planID, cUnitTypeLogicalTypeLandMilitary);
   int tempUnitID = -1;
   int tempUnitType = -1;
   vector tempUnitLocation = cInvalidVector;
   int tempTargetID = -1;
   int bestTargetID = -1;

   for (i = 0; < numUnits)
   {
      // start with the unit
      tempUnitID = aiPlanGetUnitByIndex(planID, i);
      tempUnitType = getUnitType(tempUnitID, cMyID);        // Find out the unit type
      tempUnitLocation = kbUnitGetPosition(tempUnitID);     

      switch(tempUnitType) 
      {
         case cUnitTypeAbstractHeavyInfantry : 
         {
            // If we have nearby hand cav, switch to melee and attack
            bestTargetID = getClosestUnitByLocation(cUnitTypeAbstractHandCavalry, cPlayerRelationEnemyNotGaia, cUnitStateAlive, tempUnitLocation, 5.0);
            if (bestTargetID > 0)
            {
               aiSetUnitTactic(tempUnitID, cTacticMelee);
               aiTaskUnitWork(tempUnitID, bestTargetID);
               break;
            }
            else if (aiUnitGetTactic(tempUnitID) == cTacticMelee)
            {
               aiSetUnitTactic(tempUnitID, cTacticVolley);
            }

            // Didn't find nearby cav, so attack closest thing
            bestTargetID = getClosestUnitByLocation(cUnitTypeLogicalTypeLandMilitary, cPlayerRelationEnemyNotGaia, cUnitStateAlive, tempUnitLocation, 30); 
            if (bestTargetID > 0)
            {
               aiTaskUnitWork(tempUnitID, bestTargetID);
            }

            break;
         }
         case cUnitTypeAbstractHeavyCavalry : 
         case cUnitTypeAbstractCoyoteMan :
         {  
            // nothing yet. Should auto-attack
         }
         case cUnitTypeAbstractPikeman :
         case cUnitTypeAbstractHandInfantry :
         {  
            // Look for closest hand cav within 5 yards
            bestTargetID = getClosestUnitByLocation(cUnitTypeAbstractHandCavalry, cPlayerRelationEnemyNotGaia, cUnitStateAlive, tempUnitLocation, 5.0);
            if (bestTargetID > 0)
            {
               aiTaskUnitWork(tempUnitID, bestTargetID);
               break;
            }
         }
         case cUnitTypeCulverin :
         {  // Attack closest artillery
            bestTargetID = getClosestUnitByLocation(cUnitTypeAbstractArtillery, cPlayerRelationEnemyNotGaia, cUnitStateAlive, tempUnitLocation, 30); 
            if (bestTargetID > 0)
            {
               aiTaskUnitWork(tempUnitID, bestTargetID);
            }
         }
         default : 
         { 
            // nothing yet. Should auto-attack
         }
      }
   }


   return;
}

//==============================================================================
/*
   tacticalMovements

   Makes decisions mid-fight and arranges units in small groups, typically 
   by type

   Returns:
      -1    nothing to do
       0    no movement
       1    movement
       2    retreat
*/
//==============================================================================
int tacticalMovements(int planID = -1)
{
   vector planPosition = aiPlanGetLocation(planID);
   bool returnInt = -1;

   // Analyze enemy arrangement
      // Enemy Artillery

   int enArtyQuery = createSimpleUnitQuery(cUnitTypeAbstractArtillery, cPlayerRelationEnemyNotGaia, cUnitStateAlive, planPosition, 40.0);
   int numberEnArtyFound = kbUnitQueryExecute(enArtyQuery);
   int culvNum = -1;
   int culvType = getCulvType();
   int goonNum = -1;
   int goonType = cUnitTypeDragoon;

   if (numberEnArtyFound > 0)
   {
      // Analyze what we have to deal with them
      culvNum = aiPlanGetNumberUnits(planID, culvType);
      goonNum = aiPlanGetNumberUnits(planID, goonType);
      if (culvNum > 2 * numberEnArtyFound)
      {
         // do nothing, let the culv take out artillery through individual action
      }
      else if (goonNum > 2 * numberEnArtyFound)
      {
         // nothing yet
      }
   }


      // Enemy Skirmishers

      // Enemy Cav Defense

   // Make manuevers
   // Note: move these units into child plans
      //conductCavalryFlank(attackLoc);
      //blockCavalry(defendLoc);
      //conductSkirmish();



   return (-1);
}

//==============================================================================
/*
   operationalAnalysis

   Decided where to move army within the stated goals. Decides if we should be
   attacking or defending

*/
//==============================================================================
void operationalAnalysis(int planID = -1)
{
   // Do some basic analysis for now based on our strategic goal
   switch(gAttackSystemStrategicGoal) 
   {
      case cStrategicGoalManuever : 
      {
         gAttackSystemOperationalGoal = cOperationalGoalAdvance;
         gAttackSystemOperationalLocation = guessEnemyLocation();
      }
      case cStrategicGoalDefend : 
      {
         gAttackSystemOperationalGoal = cOperationalGoalHold;
         gAttackSystemOperationalLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
      }
      default : 
      {
         gAttackSystemOperationalGoal = cOperationalGoalRegroup;
         gAttackSystemOperationalLocation = kbBaseGetLocation(cMyID, kbBaseGetMainID(cMyID));
      }
   }

}

//==============================================================================
/*
   strategicAnalysis

   Makes broad decisions like how aggressive we should be and who we should
   be attacking

*/
//==============================================================================
void strategicAnalysis(int planID = -1)
{
   // Start out basic. grab most hated player ID and attack based on if we can or not
   gAttackSystemStrategicEnemy = aiGetMostHatedPlayerID();
   
   if (allowedToAttack == true)
   {
      gAttackSystemStrategicGoal = cStrategicGoalManuever;
   }
   else
   {
      gAttackSystemStrategicGoal = cStrategicGoalDefend;
   }

}




//==============================================================================
/*
   attackSystemRule

   Runs the 

*/
//==============================================================================
rule attackSystemRule
inactive
minInterval 1
{
   // Set up attack plan
   if (gAttackSystemPlanID < 0)
   {
      gAttackSystemPlanID = aiPlanCreate("Attack System", cPlanReserve);
      aiPlanAddUnitType(gAttackSystemPlanID, cUnitTypeLogicalTypeLandMilitary, 0, 0, 200);
      aiPlanSetNoMoreUnits(gAttackSystemPlanID, true);
      aiPlanSetDesiredPriority(gAttackSystemPlanID, 50); // not sure how to handle this. We still want things like cannon corners and coastal guns
      aiPlanSetActive(gAttackSystemPlanID);
   }

   int tacticalMovementreturnValue = -1;

   // Check if we are in combat
   if (gAttackSystemInCombat == true)
   {
      // First check for tactical movements, run individual actions if we aren't retreating.
      //    Any tactical movements should get moved into a child plan
      tacticalMovementreturnValue = tacticalMovements(gAttackSystemPlanID);
      if (tacticalMovementreturnValue <= 1) // As long as we aren't retreating we can run individual actions
      {
         individualActions(gAttackSystemPlanID);
      }
   }
   else
   {
      // We can conduct strategic and operational analysis
      strategicAnalysis(gAttackSystemPlanID);
      operationalAnalysis(gAttackSystemPlanID);
   }


}