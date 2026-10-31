/**************************************************************************************************
Age of Empires III AI Scripting Reference

The functions and constants are not sorted by game version.
Some of them may not work in Age of Empires III and Age of Empires III - The War Chiefs.

This reference is subject to change with the updates of the tutorial that you can find here:
https://eso-community.net/viewtopic.php?f=33&t=19871

NOTES:
* int <-> float conversion is bugged
* float is bugged: 1 * 1.0 != 1.0 * 1
* the state of a unit at 0 hitpoints is cUnitStateDead - it's a nightmare with trees and animals
* trade route upgrades are always "obtainable" (see tech statuses in constants and techtree in functions)
* Mother Nature is the enemy of all players except herself
* Vectors have a non-commutative property: vector v = v * a is correct, v = a * v leads to an error
**************************************************************************************************/

/******************************************************************************
    FUNCTIONS
******************************************************************************/

// ============================================================================
// RULES
// ============================================================================

// Makes the specified rule inactive
void xsDisableRule( string ruleName = "" );
// Call this inside an active rule to make it inactive
void xsDisableSelf(  );
// Makes the specified rule active
void xsEnableRule( string ruleName = "" );
// Returns true if the specified rule is active, returns false otherwise
bool xsIsRuleEnabled( string ruleName = "" );
// Sets the priority of the specified rule, a high-priority rule is generally called first
void xsSetRulePriority( string ruleName = "", int priority = 0  );
// Call this inside a rule to set the priority of that rule
void xsSetRulePrioritySelf( int priority = 0  );
// Sets the min interval of the specified rule
void xsSetRuleMinInterval( string ruleName = "", int interval = 0  );
// Call this inside a rule to set the min interval of that rule
void xsSetRuleMinIntervalSelf( int interval = 0  );
// Sets the max interval of the specified rule
void xsSetRuleMaxInterval( string ruleName = "", int interval = 0  );
// Call this inside a rule to set the max interval of that rule
void xsSetRuleMaxIntervalSelf( int interval = 0  );
// Makes all rules in the specified rule group active
void xsEnableRuleGroup( string ruleGroupName = "" );
// Makes all rules in the specified rule group inactive
void xsDisableRuleGroup( string ruleGroupName = "" );

// ============================================================================
// VECTORS
// ============================================================================

// Returns the x component of the specified vector
float xsVectorGetX( vector v = cOriginVector  );
// Returns the y component of the specified vector
float xsVectorGetY( vector v = cOriginVector  );
// Returns the z component of the specified vector
float xsVectorGetZ( vector v = cOriginVector  );
// Set the x component of the specified vector, then returns the new vector
vector xsVectorSetX( vector v = cOriginVector, float x = 0  );
// Set the y component of the specified vector, then returns the new vector
vector xsVectorSetY( vector v = cOriginVector, float y = 0  );
// Set the z component of the specified vector, then returns the new vector
vector xsVectorSetZ( vector v = cOriginVector, float z = 0  );
// Set the 3 components into a vector, then returns the new vector
vector xsVectorSet( float x = 0, float y = 0, float z = 0  );
// Returns the length of the specified vector
float xsVectorLength( vector v = cOriginVector  );
// Returns the normalized version of the specified vector
vector xsVectorNormalize( vector v = cOriginVector  );

// ============================================================================
// ARRAYS
// ============================================================================

// Creates an integer array with the specified name and size, then returns the ID of that array
int xsArrayCreateInt( int size = -1, int defaultValue = 0, string name = "" );
// Sets a value at the specified index in the requested array
bool xsArraySetInt( int arrayID = -1, int index = -1, int value = -1  );
// Gets the value at the specified index in the requested array
int xsArrayGetInt( int arrayID = -1, int index = -1  );
// Creates a float  array with the specified name and size, then returns the ID of that array
int xsArrayCreateFloat( int size = -1, float defaultValue = 0, string name = "" );
// Sets a value at the specified index in the requested array
bool xsArraySetFloat( int arrayID = -1, int index = -1, float value = -1  );
// Gets the value at the specified index in the requested array
float xsArrayGetFloat( int arrayID = -1, int index = -1  );
// Creates a boolean  array with the specified name and size, then returns the ID of that array
int xsArrayCreateBool( int size = -1, bool defaultValue = false, string name = "" );
// Sets a value at the specified index in the requested array
bool xsArraySetBool( int arrayID = -1, int index = -1, bool value = false  );
// Gets the value at the specified index in the requested array
bool xsArrayGetBool( int a = -1, int b = -1  );
// Creates a string  array with the specified name and size, then returns the ID of that array
int xsArrayCreateString( int size = -1, string defaultValue = "<default string>", string name = "" );
// Sets a value at the specified index in the requested array
bool xsArraySetString( int arrayID = -1, int index = -1, string value = "<default string>" );
// Gets the value at the specified index in the requested array
string xsArrayGetString( int arrayID = -1, int index = -1  );
// Creates a vector  array with the specified name and size, then returns the ID of that array
int xsArrayCreateVector( int size = -1, vector defaultValue = cInvalidVector, string name = "" );
// Sets a value at the specified index in the requested array
bool xsArraySetVector( int arrayID = -1, int index = -1, vector value = cInvalidVector  );
// Gets the value at the specified index in the requested array
vector xsArrayGetVector( int arrayID = -1, int index = -1  );
// Gets the specified array's size
int xsArrayGetSize( int arrayID = -1  );
// Blogs out all XS arrays
void xsDumpArrays(  );

// ============================================================================
// CONTEXT PLAYER
// ============================================================================

// Returns the ID of the context player
int xsGetContextPlayer(  );
// Sets the specified player as the context player ( DO NOT DO THIS IF YOU DO NOT KNOW WHAT YOU ARE DOING  ).
void xsSetContextPlayer( int playerID = -1  );

// ============================================================================
// MISCELLANEOUS
// ============================================================================

// Returns the current gametime ( in milliseconds  ).
int xsGetTime(  );
// Setups a runtime event.  Don't use this.
bool xsAddRuntimeEvent( string foo = "", string bar = "", int something = -1  );
// Runs the secret XSFID for the function. USE WITH CAUTION.
int xsGetFunctionID( string a = "" );

// ============================================================================
// RANDOM NUMBER GENERATOR
// ============================================================================

// Sets the seed of the random number generator
void aiRandSetSeed( int seed = -1  );
// Returns a random number ( mod'ed by max if provided  )
int aiRandInt( int max = -1  );
// Returns a random location guaranteed to be on the map
vector aiRandLocation(  );

// ============================================================================
// PERSONALITY
// ============================================================================

// Sets playerID's AI to the given filename (rooted at Game Folder\AI3)
void aiSet( string filename = "None", int playerID = -1  );
// Sets a breakpoint
void aiBreakpointSet( int a = -1, string b = "", int c = -1, bool d = true  );
// Restart XS execution after the current breakpoint
void aiBreakpointGo( int a = -1  );
// Returns the context player's personality filename without the .personality file extension (in Game Folder\AI3)
string aiGetPersonality(  );
// Returns the rush boom scale of the context player
float aiPersonalityGetRushBoom(  );
// Returns the number of players in the Personality's history.
int aiPersonalityGetNumberPlayerHistories(  );
// Creates a player history with the specified name
int aiPersonalityCreatePlayerHistory( string a = "" );
// Resets the given player history
bool aiPersonalityResetPlayerHistory( int playerHistoryIndex = -1  );
// Returns the name of the index-th player in the Personality's history
string aiPersonalityGetPlayerHistoryName( int index = -1  );
// Returns a playerHistoryIndex if this personality has played searchPlayerName before
int aiPersonalityGetPlayerHistoryIndex( string searchPlayerName = "" );
// Returns the user value, given the playerHistoryIndex and the userVarName
float aiPersonalityGetPlayerUserVar( int playerHistoryIndex = -1, string userVarName = "" );
// Sets the value, given the playerHistoryIndex, userVarName ( max 255 chars  ), and value
bool aiPersonalitySetPlayerUserVar( int playerHistoryIndex = -1, string userVarName = "", float val = -1  );
// Returns the number of games played against/with the given the playerHistoryIndex
int aiPersonalityGetPlayerGamesPlayed( int playerHistoryIndex = -1, int playerRelation = -1  );
// Returns the given resource from the gameIndex game. If gameIndex is -1, this will return the avg of all games played
float aiPersonalityGetGameResource( int playerHistoryIndex = -1, int gameIndex = -1, int resourceID = -1  );

bool aiPersonalityGetDidIWinLastGameVS( int playerHistoryIndex = -1  );
// Returns the unit count from the gameIndex game. If gameIndex is -1, this will return the avg of all games played.
int aiPersonalityGetGameUnitCount( int playerHistoryIndex = -1, int gameIndex = -1, int unitType = -1  );
// Returns the 1st attacktime from the gameIndex game.
int aiPersonalityGetGameFirstAttackTime( int playerHistoryIndex = -1, int gameIndex = -1  );
// Returns the total games the given player has won against this AI
int aiPersonalityGetTotalGameWins( int playerHistoryIndex = -1, int playerRelation = -1  );

// ============================================================================
// MOST HATED PLAYER
// ============================================================================
// Returns the script-defined most hated player ID for this player.
int aiGetMostHatedPlayerID(  );
// Returns the playerID for the player the AI thinks it should be attacking.
int aiCalculateMostHatedPlayerID( int comparePlayerID = -1  );
// Sets the script-defined most hated player ID for this player.
void aiSetMostHatedPlayerID( int v = -1  );

// ============================================================================
// POPULATION
// ============================================================================

// Returns the available economy pop for this player.
int aiGetAvailableEconomyPop(  );
// Returns the current economy pop for this player.
int aiGetCurrentEconomyPop(  );
// Returns the script-defined economy pop for this player.
int aiGetEconomyPop(  );
// Set the script-defined economy pop for this player.
void aiSetEconomyPop( int v = 100  );
// Returns the script-defined military pop for this player.
int aiGetAvailableMilitaryPop(  );
// Returns the script-defined military pop for this player.
int aiGetMilitaryPop(  );
// Set the script-defined military pop for this player.
void aiSetMilitaryPop( int v = 100  );

// ============================================================================
// ECONOMY/MILITARY
// ============================================================================

// Returns the economy priority percentage.
float aiGetEconomyPercentage(  );
// Set the economy priority percentage.
void aiSetEconomyPercentage( float v = 0.5  );
// Returns the militarypriority percentage.
float aiGetMilitaryPercentage(  );
// Set the military priority percentage.
void aiSetMilitaryPercentage( float v = 0.5  );

// ============================================================================
// ATTACK RESPONSE DISTANCE
// ============================================================================

// Returns the attack response distance.
float aiGetAttackResponseDistance(  );
// Set the attack response distance.
void aiSetAttackResponseDistance( float v = 50  );

// ============================================================================
// AI PLANS
// ============================================================================

// Returns the number of matching goals.
int aiGoalGetNumber( int goalType = -1, int goalState = -1, bool active = true  );
// Returns the ID of matching goal.
int aiGoalGetIDByIndex( int goalType = -1, int goalState = -1, bool active = true, int index = -1  );
// Returns the number of matching plans.
int aiPlanGetNumber( int planType = -1, int planState = -1, bool active = true  );
// Returns the ID of matching plan.
int aiPlanGetIDByIndex( int planType = -1, int planState = -1, bool active = true, int index = -1  );
// Creates a plan of the given name and type.
int aiPlanCreate( string planName = "", int typeName = -1  );
// Destroys the given plan.
bool aiPlanDestroy( int planID = -1  );
// Destroys the plan of the given name.
bool aiPlanDestroyByName( string name = "" );
// Returns the ID of the plan with the given name.
int aiPlanGetID( string name = "" );
// Returns the ID of the first plan containing the given string in its name.
int aiPlanGetIDSubStr( string searchStr = "" );
// Returns the ID of the plan with the given parms.
int aiPlanGetIDByTypeAndVariableType( int planType = -1, int varType = -1, int varID = -1, bool active = true  );
// Returns the ID of the plan with the given active index.
int aiPlanGetIDByActiveIndex( int activeIndex = -1  );
// Returns the name of the given plan.
string aiPlanGetName( int planID = -1  );
// Returns the type of the given plan.
int aiPlanGetType( int planID = -1  );
// Returns the state of the given plan.
int aiPlanGetState( int planID = -1  );
// Returns the priority of the given plan.
int aiPlanGetActualPriority( int planID = -1  );
// Returns the priority of the given plan.
int aiPlanGetDesiredPriority( int planID = -1  );
// Sets the priority of the given plan.
bool aiPlanSetDesiredPriority( int planID = -1, int priority = -1  );
// Adds a unit type to the plan.
bool aiPlanAddUnitType( int planID = -1, int unitTypeID = -1, int numberNeed = -1, int numberWant = -1, int numberMax = -1  );
// Returns the number of units currently assigned in the given plan.
int aiPlanGetNumberUnits( int planID = -1, int unitTypeID = -1  );
// Adds a unit to the plan.
bool aiPlanAddUnit( int planID = -1, int unitID = -1  );
// Returns the location for this plan.
vector aiPlanGetLocation( int planID = -1  );
// Returns the initial positon that was set for this plan.
vector aiPlanGetInitialPosition( int planID = -1  );
// Sets the initial positon for this plan.
void aiPlanSetInitialPosition( int planID = -1, vector initialPosition = cInvalidVector  );
// Sets the waypoints of the given plan to the waypoints of the given path.
bool aiPlanSetWaypoints( int planID = -1, int pathID = -1  );
// Adds the waypoint to the given plan.
bool aiPlanAddWaypoint( int planID = -1, vector waypoint = cInvalidVector  );
// Returns the number of values for this variable index.
int aiPlanGetNumberVariableValues( int planID = -1, int planVariableIndex = -1  );
// Sets the number of values for this variable.
bool aiPlanSetNumberVariableValues( int planID = -1, int planVariableIndex = -1, int numberValues = -1, bool clearCurrentValues = true  );
// Removes the index-th value of the variable.
bool aiPlanRemoveVariableValue( int planID = -1, int planVariableIndex = -1, int variableIndex = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetVariableInt( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, int value = -1  );
// Gets the given variable of the given plan.
int aiPlanGetVariableInt( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetVariableFloat( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, float value = -1  );
// Gets the given variable of the given plan.
float aiPlanGetVariableFloat( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetVariableVector( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, vector value = cInvalidVector  );
// Gets the given variable of the given plan.
vector aiPlanGetVariableVector( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetVariableBool( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, bool value = false  );
// Gets the given variable of the given plan.
bool aiPlanGetVariableBool( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetVariableString( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, string value = "" );
// Gets the given variable of the given plan.
string aiPlanGetVariableString( int planID = -1, int planVariableIndex = -1  );
// Returns the number of values for this variable index.
int aiPlanGetNumberUserVariableValues( int planID = -1, int planVariableIndex = -1  );
// Sets the number of values for this variable.
bool aiPlanSetNumberUserVariableValues( int planID = -1, int planVariableIndex = -1, int numberValues = -1, bool clearCurrentValues = true  );
// Removes all of the user variables from the given plan.
bool aiPlanRemoveUserVariables( int planID = -1  );
// Removes the user variable.
bool aiPlanRemoveUserVariable( int planID = -1, int planVariableIndex = -1  );
// Removes the index-th value of the user variable.
bool aiPlanRemoveUserVariableValue( int planID = -1, int planVariableIndex = -1, int variableIndex = -1  );
// Adds the variable to the given plan.
bool aiPlanAddUserVariableInt( int planID = -1, int planVariableIndex = -1, string name = "", int numberValues = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetUserVariableInt( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, int value = -1  );
// Gets the given variable of the given plan.
int aiPlanGetUserVariableInt( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Adds the variable to the given plan.
bool aiPlanAddUserVariableFloat( int planID = -1, int planVariableIndex = -1, string name = "", int numberValues = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetUserVariableFloat( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, float value = -1  );
// Gets the given variable of the given plan.
float aiPlanGetUserVariableFloat( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Adds the variable to the given plan.
bool aiPlanAddUserVariableVector( int planID = -1, int planVariableIndex = -1, string name = "", int numberValues = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetUserVariableVector( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, vector value = cInvalidVector  );
// Gets the given variable of the given plan.
vector aiPlanGetUserVariableVector( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Adds the variable to the given plan.
bool aiPlanAddUserVariableBool( int planID = -1, int planVariableIndex = -1, string name = "", int numberValues = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetUserVariableBool( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, bool value = false  );
// Gets the given variable of the given plan.
bool aiPlanGetUserVariableBool( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Adds the variable to the given plan.
bool aiPlanAddUserVariableString( int planID = -1, int planVariableIndex = -1, string name = "", int numberValues = -1  );
// Sets the given variable of the given plan.
bool aiPlanSetUserVariableString( int planID = -1, int planVariableIndex = -1, int valueIndex = -1, string value = "" );
// Gets the given variable of the given plan.
string aiPlanGetUserVariableString( int planID = -1, int planVariableIndex = -1, int valueIndex = -1  );
// Gets the active-ness of the given plan.
bool aiPlanGetActive( int planID = -1  );
// Sets active on/off for the given plan.
bool aiPlanSetActive( int planID = -1, bool active = true  );
// Gets the noMoreUnits-ness of the given plan.
bool aiPlanGetNoMoreUnits( int planID = -1  );
// Sets noMoreUnits on/off for the given plan.
bool aiPlanSetNoMoreUnits( int planID = -1, bool v = true  );
// Gets the orphan-ness of the given plan.
bool aiPlanGetOrphan( int planID = -1  );
// Sets orphan on/off for the given plan.
bool aiPlanSetOrphan( int planID = -1, bool orphan = true  );
// Gets the UA response-ness of the given plan.
bool aiPlanGetAllowUnderAttackResponse( int planID = -1  );
// Sets under attack response on/off for the given plan.
bool aiPlanSetAllowUnderAttackResponse( int planID = -1, bool uAR = true  );
// Gets the unit stance of the given plan - see UNIT STANCES in CONSTANTS
int aiPlanGetUnitStance( int planID = -1 );
// Sets unit stance for the given plan - see UNIT STANCES in CONSTANTS
bool aiPlanSetUnitStance( int planID = -1, int stance = 0  );
// Sets 'requiresAllNeedUnits' on/off for the given plan.
bool aiPlanSetRequiresAllNeedUnits( int planID = -1, bool rANU = true  );
// Sets event handler function for the given plan and event.
bool aiPlanSetEventHandler( int planID = -1, int eventType = -1, string handlerName = "" );
// Sets the escrow for the plan.
bool aiPlanSetEscrowID( int planID = -1, int escrowID = -1  );
// Gets the escrow for the plan.
int aiPlanGetEscrowID( int planID = -1  );
// Gets the economy flag of the given plan.
bool aiPlanGetEconomy( int planID = -1  );
// Sets economy on/off for the given plan.
bool aiPlanSetEconomy( int planID = -1, bool v = true  );
// Gets the military flag of the given plan.
bool aiPlanGetMilitary( int planID = -1  );
// Sets military on/off for the given plan.
bool aiPlanSetMilitary( int planID = -1, bool v = true  );
// Gets the attack flag of the given plan.
bool aiPlanGetAttack( int planID = -1  );
// Sets attack flag on/off for the given plan.
bool aiPlanSetAttack( int planID = -1, bool v = true  );
// sets the plan's base id.
bool aiPlanSetBaseID( int planID = -1, int baseID = -1  );
// gets the plan's base id.
int aiPlanGetBaseID( int planID = -1  );
// Gets the of idle plans of the given type.
int aiGetNumberIdlePlans( int planType = -1  );
// gets total aiCost of plan's units, weighted for HP if requested.
float aiPlanGetUnitCost( int planID = -1, bool considerHitPoints = false  );
// Returns the number of unassigned units of the given type.
int aiNumberUnassignedUnits( int typeID = -1  );
// Returns the number of unassigned units based on the goal's unit type( s  ).
int aiNumberUnassignedUnitsByGoal( int goalID = -1  );

// ============================================================================
// AI COMMUNICATIONS
//=============================================================================

// Enables or disables the chats from this ai player.
void aiCommsAllowChat( bool flag = true  );
// Sends a statement to the designated player.
int aiCommsSendStatement( int targetPlayerID = -1, int promptType = -1  );
// Sends a statement to the designated player. Adds a location flare.
int aiCommsSendStatementWithVector( int targetPlayerID = -1, int promptType = -1, vector v = cInvalidVector  );
// Sets the handler for the communications system ( invalid name unsets the handler  ).
bool aiCommsSetEventHandler( string handlerFunctionName = "" );
// get sending player for specified sentence.
int aiCommsGetSendingPlayer( int sentenceID = -1  );
// get chat verb for specified sentence.
int aiCommsGetChatVerb( int sentenceID = -1  );
// get target type for specified sentence.
int aiCommsGetChatTargetType( int sentenceID = -1  );
// get number of items in target list for specified sentence.
int aiCommsGetTargetListCount( int sentenceID = -1  );
// get index item from specified sentence.
int aiCommsGetTargetListItem( int sentenceID = -1, int index = -1  );
// get target location from specified sentence.
vector aiCommsGetTargetLocation( int sentenceID = -1  );
// send a reply to a sentence.
void aiCommsSendReply( int sentenceID = -1, int responseID = -1  );

// ============================================================================
// EVENT HANDLERS
// ============================================================================

// Sets the handler for given type of event.
bool aiSetHandler( string handlerFunctionName = "", int type = -1  );

// ============================================================================
// AI TASKS
// ============================================================================

// Does a lightweight ( no plan  ) move tasking of the given unit to the given location.
bool aiTaskUnitMove( int unitID = -1, vector position = cOriginVector  );
// Does a lightweight ( no plan  ) work tasking of the given unit on the given target unit.
bool aiTaskUnitWork( int unitID = -1, int targetUnitID = -1  );
// Does a lightweight ( no plan  ) build tasking of the given unit to build the given building.
bool aiTaskUnitBuild( int unitID = -1, int buildingTypeID = -1, vector position = cOriginVector  );
// Does a lightweight ( no plan  ) train tasking of the given unit for the given target unit type.
bool aiTaskUnitTrain( int unitID = -1, int unitTypeID = -1  );
// Does a lightweight ( no plan  ) research tasking of the given unit for the given tech ID.
bool aiTaskUnitResearch( int unitID = -1, int techID = -1  );
// Deletes the given unit.
bool aiTaskUnitDelete( int unitID = -1  );
// sets the specified tactic on the specified unit.
bool aiUnitSetTactic( int unitID = -1, int tacticID = -1  );
// gets the specified unit's current tactic.
int aiUnitGetTactic( int unitID = -1  );

// ============================================================================
// AI RESOURCES
// ============================================================================

// Tributes the given player.
bool aiTribute( int playerID = -1, int resourceID = -1, float amount = -1  );
// sells ( +100  ) the given resource.
bool aiSellResourceOnMarket( int resourceID = -1  );
// buys ( +100  ) the given resource.
bool aiBuyResourceOnMarket( int resourceID = -1  );
// Returns the amount required to buy 100 units of the given resource.
float aiGetMarketBuyCost( int resourceID = -1  );
// Returns the amount received for selling 100 units of the given resource.
float aiGetMarketSellCost( int resourceID = -1  );

// ============================================================================
// AI ECONOMY
// ============================================================================

// Returns the RGP weight.
float aiGetResourceGathererPercentageWeight( int rgpIndex = -1  );
// Sets the RGP weight.
void aiSetResourceGathererPercentageWeight( int rgpIndex = -1, float weight = 0.5  );
// Normalizes all of the resource gatherer percentages weights to 1.0.
void aiNormalizeResourceGathererPercentageWeights(  );
// Returns the resource gatherer percentage for the given resource.
float aiGetResourceGathererPercentage( int resourceID = -1, int rgpIndex = 0  );
// Sets the resource gatherer percentage for the given resource ( if normalized is true, the percentages will be normalized to 1.0  ).
void aiSetResourceGathererPercentage( int resourceID = -1, float value = 0, bool normalize = false, int rgpIndex = 0  );
// Normalizes all of the resource gatherer percentages to 1.0.
void aiNormalizeResourceGathererPercentages( int rgpIndex = 0  );
// Gets the number of plans for the given breakdown.
int aiGetResourceBreakdownNumberPlans( int resourceTypeID = -1, int resourceSubTypeID = -1, int baseID = -1  );
// Gets the priority of the plans for the given breakdown.
int aiGetResourceBreakdownPlanPriority( int resourceTypeID = -1, int resourceSubTypeID = -1, int baseID = -1  );
// Gets the percentage for the given breakdown.
float aiGetResourceBreakdownPercentage( int resourceTypeID = -1, int resourceSubTypeID = -1, int baseID = -1  );
// Sets a subtype breakdown for a resource.
bool aiSetResourceBreakdown( int resourceTypeID = -1, int resourceSubTypeID = -1, int numberPlans = 0, int planPriority = 50, float percentage = 0, int baseID = -1  );
// Removes the given breakdown.
bool aiRemoveResourceBreakdown( int resourceTypeID = -1, int resourceSubTypeID = -1, int baseID = -1  );
// Returns the auto gather escrow ID.
int aiGetAutoGatherEscrowID(  );
// Sets the auto gather escrow ID.
void aiSetAutoGatherEscrowID( int escrowID = -1  );
// Returns the auto Farm escrow ID.
int aiGetAutoFarmEscrowID(  );
// Sets the auto Farm escrow ID.
void aiSetAutoFarmEscrowID( int escrowID = -1  );
// Returns the per plan farm build limit.
int aiGetFarmLimit(  );
// Sets the per plan farm build limit.
void aiSetFarmLimit( int limit = -1  );
// Returns allow buildings on/off.
bool aiGetAllowBuildings(  );
// Sets allow buildings on/off.
void aiSetAllowBuildings( bool v = true  );
// returns the current resource need for the given resource.
float aiGetCurrentResourceNeed( int resourceID = -1  );

// ============================================================================
// AI CHATS
// ============================================================================

// CP AI chat to playerID.
void aiChat( int playerID = -1, string chatString = "None" );

// ============================================================================
// AI OPPORTUNITIES
// ============================================================================

// adds an opportunity to the list and returns the id.
int aiCreateOpportunity( int type = -1, int targettype = -1, int targetID = -1, int targetPlayerID = -1, int source = -1  );
// activates or deactivates an opportunity on the player's opp list.
void aiActivateOpportunity( int opportunityID = -1, bool flag = true  );
// remove an opportunity on the player's opp list.
void aiDestroyOpportunity( int opportunityID = -1  );
// finds the best currently scored opp.
void aiFindBestOpportunity(  );
// gets the source id from this opportunity
int aiGetOpportunitySourceID( int opportunityID = -1  );
// gets the source type from this opportunity
int aiGetOpportunitySourceType( int opportunityID = -1  );
// gets the radius from this opportunity
float aiGetOpportunityRadius( float opportunityID = -1  );
// gets the target playerID from this opportunity
int aiGetOpportunityTargetPlayerID( int opportunityID = -1  );
// gets the target type from this opportunity
int aiGetOpportunityTargetType( int opportunityID = -1  );
// gets the type from this opportunity
int aiGetOpportunityType( int opportunityID = -1  );
// gets the location from this opportunity
vector aiGetOpportunityLocation( int opportunityID = -1  );
// gets the target id from this opportunity
int aiGetOpportunityTargetID( int opportunityID = -1  );
// sets the target type for this opp.
void aiSetOpportunityTargetType( int opportunityID = -1, int targetType = -1  );
// sets the target id for this opp.
void aiSetOpportunityTargetID( int opportunityID = -1, int targetType = -1  );
// sets the radius for this opp.
void aiSetOpportunityRadius( int opportunityID = -1, float radius = -1  );
// sets the location for this opp.
void aiSetOpportunityLocation( int opportunityID = -1, vector location = cInvalidVector  );
// sets the score for this opp.
bool aiSetOpportunityScore( int oppID = -1, int permission = -1, float affordable = -1, float classscore = -1, float instance = -1, float total = -1  );

// ============================================================================
// AI DIFFICULTIES - see DIFFICULTIES in CONSTANTS
//=============================================================================

// Returns the world difficulty level.
int aiGetWorldDifficulty(  );
// Sets the world difficulty level.
void aiSetWorldDifficulty( int v = -1  );
// Returns the name of the level.
string aiGetWorldDifficultyName( int level = -1 );

// ============================================================================
// GAME MODES
// ============================================================================

// Returns the game's mode
int aiGetGameMode(  );
// Returned values:
extern const int cGameModeSupremacy; // if ( aiGetGameMode() == cGameModeSupremacy ) then the game mode is Supremacy
extern const int cGameModeConquest; // Not implemented in AOE3
extern const int cGameModeLightning; // Not implemented in AOE3
extern const int cGameModeDeathmatch; // if ( aiGetGameMode() == cGameModeDeathmatch ) then the game mode is Deathmatch

// ============================================================================
// POLITICIANS
// ============================================================================

// Sets the scripts choice for the AgeX Politician.
void aiSetPoliticianChoice( int age = -1, int puid = -1  );
// Gets the scripts choice for the AgeX Politician.
int aiGetPoliticianChoice( int age = -1  );
// Call this to make the AI fill out what Politicians are available.
bool aiPopulatePoliticianList(  );
// Gets the number of Politicans avaiable for AgeX.
int aiGetPoliticianListCount( int age = -1  );
// Gets the index'th Politicans avaiable for AgeX.
int aiGetPoliticianListByIndex( int age = -1, int index = -1  );

// ============================================================================
// HOMECITY
// ============================================================================

// Returns the number of cards in the Current HC.
int aiHCCardsGetTotal(  );
// Has the cardindex been bought yet?
bool aiHCCardsIsCardBought( int cardIndex = -1  );
// Can I buy this card now?
bool aiHCCardsCanIBuyThisCard( int deckIndex = -1, int cardIndex = -1  );
// Buy this card now
bool aiHCCardsBuyCard( int cardIndex = -1  );
// For this cardIndex, get the age prereq.
int aiHCCardsGetCardAgePrereq( int cardIndex = -1  );
// For this cardIndex, get the age prereq.
int aiHCCardsGetCardLevel( int cardIndex = -1  );
// For this cardIndex, get the TechID.
int aiHCCardsGetCardTechID( int a = -1  );
// For this cardIndex, get the UnitType.
int aiHCCardsGetCardUnitType( int a = -1  );
// For this cardIndex, get the UnitCount.
int aiHCCardsGetCardUnitCount( int a = -1  );
// For this cardIndex, get the CardCount, -1 is Infinite.
int aiHCCardsGetCardCount( int a = -1  );
// Get the best card using the optional cardtype and optional resourcePreference - see CARD TYPES and RESOURCES in CONSTANTS
int aiHCCardsFindBestCard( int cardType = -1, int levelPref = -1, int resourcePref = -1  );
// Returns the number of decks in the Current HC.
int aiHCGetNumberDecks(  );
// Create a new HC Deck with the given name.
int aiHCDeckCreate( string a = "AI Deck" );
// Makes the deckIndex the current active HC deck.
bool aiHCDeckActivate( int deckIndex = -1  );
// Adds the card given to the givenHC Deck.
bool aiHCDeckAddCardToDeck( int deckIndex = -1, int cardIndex = -1  );
// Returns the number of cards in the Current HC Deck.
int aiHCDeckGetNumberCards( int deckIndex = -1  );
// play this card.
bool aiHCDeckPlayCard( int cardIndex = -1  );
// For this card, get the age prereq
int aiHCDeckGetCardAgePrereq( int deckIndex = -1, int cardIndex = -1  );
// For this card, get the level
int aiHCDeckGetCardLevel( int deckIndex = -1, int cardIndex = -1  );
// For this card, get the techID
int aiHCDeckGetCardTechID( int deckIndex = -1, int cardIndex = -1  );
// For this card, get the unitType
int aiHCDeckGetCardUnitType( int deckIndex = -1, int cardIndex = -1  );
// For this card, get the unit Count
int aiHCDeckGetCardUnitCount( int deckIndex = -1, int cardIndex = -1  );
// Can we play this card from the given deck?
bool aiHCDeckCanPlayCard( int cardIndex = -1  );
// Gets how many cards of this type we can send. -1 mean infinite.
int aiHCDeckCardGetCardCount( int deskIndex = -1, int cardIndex = -1  );

// ============================================================================
// MISCELLANEOUS
// ============================================================================

// Returns the captain for the given player's team.
int aiGetCaptainPlayerID( int playerID = -1  );
// returns whether or not its cool to turn ai autosaves on.
bool aiGetAutosaveOn(  );
// Turns auto gathering of military units at bases on/off.
bool aiSetAutoGatherMilitaryUnits( bool v = true  );
// sets the ai's Explore Danger Threshold value.
bool aiSetExploreDangerThreshold( float value = -1  );
// gets the ai's Explore Danger Threshold value.
float aiGetExploreDangerThreshold(  );
// Sets the RM bool in the AI.
void aiSetRandomMap( bool v = false  );
// sets the pause all age upgrades flag in the AI.
void aiSetPauseAllAgeUpgrades( bool v = false  );
// gets the pause all age upgrades flag from the AI.
bool aiGetPauseAllAgeUpgrades( bool a = false  );
// sets the min number of units in an attack army.
void aiSetMinArmySize( int v = 5  );
// sets the min number of needed units to gather aggressive animals.
void aiSetMinNumberNeedForGatheringAggressvies( int v = 0  );
// gets the min number of needed units to gather aggressive animals.
int aiGetMinNumberNeedForGatheringAggressives(  );
// sets the min number of wanted units to gather aggressive animals.
void aiSetMinNumberWantForGatheringAggressives( int v = 0  );
// gets the min number of wanted units to gather aggressive animals.
int aiGetMinNumberWantForGatheringAggressives(  );
// reigns the current player..
void aiResign(  );
// asks the player if its ok to resign
void aiAttemptResign( int a = -1  );
// sets the limit for how many LOS Protounits the AI can build
void aiSetMaxLOSProtoUnitLimit( int limit = -1  );
// gets the limit for how many LOS Protounits the AI can build
int aiGetMaxLOSProtoUnitLimit(  );
// gets the current Pop needs of all the plans.
int aiGetPopNeeds(  );
// switch the newBaseID to be the main base.
void aiSwitchMainBase( int newBaseID = -1, bool force = false  );
// Sets your default stance for all of your units - see UNIT STANCES in CONSTANTS
void aiSetDefaultStance( int defaultStance = -1  );
// Tells the AI if this is a water map or not.
void aiSetWaterMap( bool v = true  );
// Tells us if the AI thinks this is a water map or not.
bool aiGetWaterMap(  );
// Is this a certain maptype or not. ( AIFishingUseful, AITransportRequired, AITransportUseful  )
bool aiIsMapType( string mapType = "AIFishingUseful" );
// Returns the HCGP.
vector aiGetHCGatherPoint(  );
// Sets the HCGP.
bool aiSetHCGatherPoint(  );
// returns the score for the given player.
int aiGetScore( int playerID = -1  );
// returns the number of teams in the game.
int aiGetNumberTeams(  );
// Queues the auto savegame.
void aiQueueAutoSavegame( int saveNumber = -1  );
// returns true, if this is a multiplayer game.
bool aiIsMultiplayer(  );
// returns the ID of the fallen explorer; if there isn't one, returns -1
int aiGetFallenExplorerID(  );
// ransoms the specified explorer using funds from the specified escrow account and spawns it from the specified building.
bool aiRansomExplorer( int explorerID = -1, int escrowID = -1, int sourceBuildingID = -1  );
// builds walls around the specified building's colony using the specified escrow.
bool aiBuildWall( int buildingID = -1, int escrowID = -1  );
// returns whether it is allowed to build a wall around the specified building's colony, and whether the player can afford it from the specified escrow.
bool aiCanBuildWall( int buildingID = -1, int escrowID = -1  );
// returns the wall radius for the specified building's colony.
float aiGetWallRadius( int buildingID = -1  );
// returns whether a wall exists around the specified building's colony.
bool aiDoesWallExist( int buildingID = -1  );
// returns the current game type - see GAME TYPES in CONSTANTS
int aiGetGameType(  );
// Prevent a resource from being spent by the AI.
void aiResourceLock( int resourceID = -1  );
// Allow a resource to be spent by the AI.
void aiResourceUnlock( int resourceID = -1  );
// Is this Escrow resource locked.
bool aiResourceIsLocked( int resourceID = -1  );
// breaks the treaty using funds from the given escrow.
bool aiBreakTreaty( int escrowID = -1  );
// checks whether the given player has a treaty.
bool aiTreatyActive(  );
// Gets the last collected nugget's type
int aiGetLastCollectedNuggetType( int playerID = -1  );
// Gets the last collected nugget's effect
int aiGetLastCollectedNuggetEffect( int playerID = -1  );
// Gets the number of tradeposts controlled by this team ( for monopoly victory  ).
int aiGetNumberTradePostsControlled( int teamID = -1  );
// Gets the number of tradeposts needed to make a monopoly win possible.
int aiGetNumberTradePostsNeededForMonopoly(  );
// Returns true if the monopoly command can be given now.  Does not check cost.
bool aiReadyForTradeMonopoly(  );
// Executes a trade monopoly command, returns false if it fails.
bool aiDoTradeMonopoly(  );
// Returns true if a trade monopoly is possible in this game type.
bool aiIsMonopolyAllowed(  );
// Gets the number of relics controlled by this team ( for relic victory  ).
int aiGetNumberRelicsControlled( int teamID = -1  );
// Gets the number of relics needed to make a relic win possible.
int aiGetNumberRelicsNeededForVictory(  );
// Returns true if a relic capture victory is possible in this game type.
bool aiIsRelicCaptureAllowed(  );
// Returns true if a King of the Hill victory is possible in this game type.
bool aiIsKOTHAllowed(  );
// Gets the team that is king of the hill.
int aiGetKOTHController(  );
// Returns true if this team is king of the hill.
bool aiIsTeamKOTH( int teamID = -1  );

// ============================================================================
// KNOWLEDGE BASES
// ============================================================================

// KB dump for player2's units from player1's perspective.
void kbDump( int player1 = -1, int player2 = -1  );
// KB dump for player2's units of the given type from player1's perspective.
void kbDumpType( int player1 = -1, int player2 = -1, string typeName = "Invalid" );
// Cheats and looks at all of the units on the map.  This will format your harddrive if you're not authorized to use it.
void kbLookAtAllUnitsOnMap(  );
// Returns whether the game is over or not.
bool kbIsGameOver(  );
// Returns true if the location is currently visible to the player.
bool kbLocationVisible( vector location = cInvalidVector  );
// returns the visible area group that matches the given criteria.
int kbFindAreaGroup( int groupType = -1, float surfaceAreaRatio = 1, int compareAreaID = -1  );
// returns the visible area group that matches the given criteria.
int kbFindAreaGroupByLocation( int groupType = -1, float relativeX = 0.5, float relativeZ = 0.5  );
// returns the id of the best building to repair.
int kbFindBestBuildingToRepair( vector position = cInvalidVector, float distance = 50, float healthRatio = 1, int repairUnderAttackUnitTypeID = -1  );

// ============================================================================
// POPULATION
// ============================================================================

// Returns the current population for the player.
int kbGetPop(  );
// Returns the current population cap for the player.
int kbGetPopCap(  );

// ============================================================================
// AGE - see AGES in CONSTANTS
// ============================================================================

// Returns the current age for the current player.
int kbGetAge(  );
// Returns the current age for the player specified.
int kbGetAgeForPlayer( int id = -1  );

// ============================================================================
// CULTURE & CIVILIZATION
// ============================================================================

// Returns the culture for the player.
int kbGetCulture(  );
// Returns the culture for the given player.
int kbGetCultureForPlayer( int a = -1  );
// Returns the culture name for the given culture.
string kbGetCultureName( int a = -1  );
// Returns the civilization for the player.
int kbGetCiv(  );
// Returns the civ for the given player.
int kbGetCivForPlayer( int a = -1  );
// Returns the civ name for the given civ.
string kbGetCivName( int civID = -1  );

// ============================================================================
// QUERIES
// ============================================================================

// Creates a unit query, returns the query ID.
int kbUnitQueryCreate( string name = "DEFAULT" );
// Resets the given unit query data AND results.
bool kbUnitQueryResetData( int queryID = -1  );
// Resets the given unit query results.
bool kbUnitQueryResetResults( int queryID = -1  );
// Destroys the given unit query.
bool kbUnitQueryDestroy( int queryID = -1  );
// Returns the number of results in the current query.
int kbUnitQueryNumberResults( int queryID = -1  );
// Returns the UnitID of the index-th result in the current query.
int kbUnitQueryGetResult( int queryID = -1, int index = -1  );
// Sets query data.
bool kbUnitQuerySetPlayerID( int queryID = -1, int playerID = -1, bool resetQueryData = true  );
// Sets query data - see PLAYER RELATIONS in CONSTANTS
bool kbUnitQuerySetPlayerRelation( int queryID = -1, int playerRelation = -1  );
// Sets query data.
bool kbUnitQuerySetUnitType( int queryID = -1, int unitTypeID = -1  );
// Sets query data.
bool kbUnitQuerySetActionType( int queryID = -1, int actionTypeID = -1  );
// Sets query data.
bool kbUnitQuerySetState( int queryID = -1, int state = 255  );
// Sets query data.
bool kbUnitQuerySetPosition( int queryID = -1, vector v = cOriginVector  );
// Sets query data.
bool kbUnitQuerySetMaximumDistance( int queryID = -1, float distance = 0  );
// Sets query data.
bool kbUnitQuerySetIgnoreKnockedOutUnits( int queryID = -1, bool v = true  );
// If parm is true, results are sorted in ascending distance order from the query position.
bool kbUnitQuerySetAscendingSort( int queryID = -1, bool v = true  );
// Sets query data.
bool kbUnitQuerySetBaseID( int queryID = -1, int baseID = -1  );
// Sets query data.
bool kbUnitQuerySetAreaID( int queryID = -1, int areaID = -1  );
// Sets query data.
bool kbUnitQuerySetAreaGroupID( int queryID = -1, int areaGroupID = -1  );
// Sets query data.
bool kbUnitQuerySetArmyID( int queryID = -1, int armyID = -1  );
// Sets query data.
bool kbUnitQuerySetSeeableOnly( int queryID = -1, bool seeableOnly = true  );
// Executes the current query; returns number of results.
int kbUnitQueryExecute( int queryID = -1  );
// Executes the current query on the previous query's results; returns the new number of results.
int kbUnitQueryExecuteOnQuery( int currentQueryID = -1, int previousQueryID = -1  );
// Executes the current query on the previous query's results; returns the new number of results.
int kbUnitQueryExecuteOnQueryByName( int currentQueryID = -1, string previousQueryName = "" );
// gets total aiCost of query's units, weighted for HP if requested.
float kbUnitQueryGetUnitCost( int queryID = -1, bool considerHealth = false  );
// gets HP of query's units, using current HP if requested.
float kbUnitQueryGetUnitHitpoints( int queryID = -1, bool considerHealth = false  );

// ============================================================================
// UNITS
// ============================================================================

// Returns the player ID for this unit ID.
int kbUnitGetPlayerID( int unitID = -1  );
// Returns the plan ID for this unit ID.
int kbUnitGetPlanID( int unitID = -1  );
// Returns the base ID for this unit ID.
int kbUnitGetBaseID( int unitID = -1  );
// Returns the area ID for this unit ID.
int kbUnitGetAreaID( int unitID = -1  );
// Returns the army ID for this unit ID.
int kbUnitGetArmyID( int unitID = -1  );
// Returns the movementType for this unitTypeID.
int kbUnitGetMovementType( int unitTypeID = -1  );
// Returns the current hitpoints for this unit ID.
float kbUnitGetCurrentHitpoints( int unitID = -1  );
// Returns the maximum hitpoints for this unit ID.
float kbUnitGetMaximumHitpoints( int unitID = -1  );
// Returns the health for this unit ID.
float kbUnitGetHealth( int unitID = -1  );
// Returns the current AI cost ( worth  ) for this unit ID.
float kbUnitGetCurrentAICost( int unitID = -1  );
// Returns the maximum AI cost ( worth  ) for this unit ID.
float kbUnitGetMaximumAICost( int unitID = -1  );
// Returns the position for this unit ID.
vector kbUnitGetPosition( int unitID = -1 );
// Returns true if the unit is of the unitTypeID.
bool kbUnitIsType( int unitID = -1, int unitTypeID = -1  );
// Returns the actionTypeID of the unit.
int kbUnitGetActionType( int unitID = -1  );
// Returns the target unit ID of the given unit.
int kbUnitGetTargetUnitID( int unitID = -1  );
// Returns the number of units currently working on the given unit.
int kbUnitGetNumberWorkers( int unitID = -1  );
// Returns the index-th worker unit ID.
int kbUnitGetWorkerID( int unitID = -1, int index = -1  );
// Returns the number of the unit type you are allowed to have ( ONLY WORKS ON BASE UNIT TYPES  ); returns -1 if there is no limit.
int kbGetBuildLimit( int player = -1, int unitTypeID = -1  );
// Returns amount of pop cap addition provided by the given unit type ( ONLY WORKS ON BASE UNIT TYPES  ).
int kbGetPopCapAddition( int player = -1, int unitTypeID = -1  );
// Returns the number of pop slots this unit takes ( ONLY WORKS ON BASE UNIT TYPES  ).
int kbGetPopSlots( int player = -1, int unitTypeID = -1  );
// Returns the number of pop slots currently occupied by this unit type.
int kbGetPopulationSlotsByUnitTypeID( int playerID = -1, int unitTypeID = -1  );
// Returns the number of pop slots currently occupied by the results in the given query.
int kbGetPopulationSlotsByQueryID( int queryID = -1  );
// Returns a quick unit count of units for a player.
int kbUnitCount( int player = 0, int unitTypeID = -1, int stateID = 2  );
// Returns a quick unit count of player2's units from player1's perspective.
void kbUnitCountConsole( int playerID1 = -1, int playerID2 = -1, string unitType = "", string state = "" );
// Returns true if the unit is currently visible to the player.
bool kbUnitVisible( int unitID = -1  );
// Returns the position of the cinematic block.
vector kbGetBlockPosition( string blockName = "" );
// Returns the UnitID of the cinematic block.
int kbGetBlockID( string blockName = "" );
// Returns a random, valid PUID that's of the given type.
int kbGetRandomEnabledPUID( int unitTypeID = -1, int escrowID = -1  );
// Returns the name of the protounit ID.
string kbGetProtoUnitName( int protoUnitTypeID = -1  );
// Returns the base type ID of the unit.
int kbGetUnitBaseTypeID( int unitID = -1  );
// Returns the name of the unit type.
string kbGetUnitTypeName( int unitTypeID = -1  );

// ============================================================================
// TERRAIN ANALYSIS
// ============================================================================

// Returns the center vector of the map.
vector kbGetMapCenter(  );
// Returns the X size of the map.
float kbGetMapXSize(  );
// Returns the Z size of the map.
float kbGetMapZSize(  );
// Creates areas and area groups. DO THIS BEFORE ANYTHING ELSE IN YOUR SCRIPT.
void kbAreaCalculate( float a = -1, bool b = true, vector c = cInvalidVector, vector d = cInvalidVector, vector e = cInvalidVector, vector f = cInvalidVector  );
// Returns the number of areas.
int kbAreaGetNumber(  );
// Returns the ID of the given area.
int kbAreaGetIDByPosition( vector position = cOriginVector  );
// Returns the ID of the given area group.
int kbAreaGroupGetIDByPosition( vector position = cOriginVector  );
// Returns the center of the given areaGroup.
vector kbAreaGroupGetCenter( int groupID = -1  );
// Returns the center of the given area.
vector kbAreaGetCenter( int areaID = -1  );
// Returns the number of tiles in the given area.
int kbAreaGetNumberTiles( int areaID = -1  );
// Returns the number of black tiles in the given area.
int kbAreaGetNumberBlackTiles( int areaID = -1  );
// Returns the number of visible tiles in the given area.
int kbAreaGetNumberVisibleTiles( int areaID = -1  );
// Returns the number of fog tiles in the given area.
int kbAreaGetNumberFogTiles( int areaID = -1  );
// Returns the gametime of the last visibility change for the given area.
int kbAreaGetVisibilityChangeTime( int areaID = -1  );
// Returns the number of units in the given area.
int kbAreaGetNumberUnits( int areaID = -1  );
// Returns the Unit ID of the index-th unit in the given area.
int kbAreaGetUnitID( int areaID = -1, int index = -1  );
// Returns the number of border areas for the given area.
int kbAreaGetNumberBorderAreas( int areaID = -1  );
// Returns the Area ID of the index-th border area in the given area.
int kbAreaGetBorderAreaID( int areaID = -1, int index = -1  );
// Returns the Type of area.
int kbAreaGetType( int areaID = -1  );

// ============================================================================
// VICTORY POINT SITES (TRADING POSTS, SOCKETS)
// ============================================================================

// returns an area's VP site ID ( -1 if an area doesn't have a VP site  ).
int kbAreaGetVPSiteID( int areaID = -1  );
// returns ID for an array containing VP site IDs that match the specified parameters.
int kbVPSiteQuery( int scoreType = -1, int playerRelationOrID = -1, int siteState = -1  );
// blogs out info about all VP sites.
void kbDumpVPSiteInfo(  );
// returns the specified VP site's type ( e.g., native, trade, etc  ).
int kbVPSiteGetType( int siteID = -1  );
// returns the specified VP site's world location.
vector kbVPSiteGetLocation( int siteID = -1  );
// returns the specified VP site's owning player.
int kbVPSiteGetOwnerPlayerID( int siteID = -1  );
// returns the specified VP site's state.
int kbVPSiteGetState( int siteID = -1  );
// returns the protounit ID for the VP generator that corresponds to this type of VP site.
int kbGetVPGeneratorByScoreType( int siteType = -1  );
// Returns the Area ID of the closest area, of the given types, to given postion.
int kbAreaGetClosetArea( vector position = cInvalidVector, int areaType = -1, int areaType1 = -1, float minDistance = -1  );

// ============================================================================
// PATHS
// ============================================================================

// Creates a path with the given name.
int kbPathCreate( string name = "" );
// Destroys the given path.
bool kbPathDestroy( int pathID = -1  );
// Returns the number of paths.
int kbPathGetNumber(  );
// Returns the index-th path ID.
int kbPathGetIDByIndex( int index = -1  );
// Returns the name of the given path.
string kbPathGetName( int pathID = -1  );
// Returns the length of the given path.
float kbPathGetLength( int pathID = -1  );
// Returns the number of waypoints in the given path.
int kbPathGetNumberWaypoints( int pathID = -1  );
// Adds the waypoint to the given path.
bool kbPathAddWaypoint( int pathID = -1, vector waypoint = cOriginVector  );
// Returns the appropriate waypoint from the given path.
vector kbPathGetWaypoint( int pathID = -1, int waypointNumber = -1  );
// Returns true if the given unit type can path from pointA to pointB.
bool kbCanSimPath( vector pointA = cOriginVector, vector pointB = cOriginVector, int protoUnitTypeID = -1, float range = 0  );
// Returns true if the given unit type can path from pointA to pointB.
bool kbCanPath2( vector pointA = cOriginVector, vector pointB = cOriginVector, int protoUnitTypeID = -1, float range = 0  );
// Returns the Route ID if successful.
int kbCreateAttackRoute( string name = "BAD", int startAreaID = -1, int goalAreaID = -1, int numInitialRoutes = 3  );
// Returns the Route ID if successful.
int kbCreateAttackRouteWithPath( string name = "BAD", vector startPt = cOriginVector, vector endPt = cOriginVector  );
// Returns true if the route was deleted.
bool kbDestroyAttackRoute( int routeID = -1  );
// add a new sector to path to.
bool kbAddAttackRouteSector( int sector = -1  );
// ignore this area when finding the route.
bool kbAddAttackRouteIgnoreID( int ignoreAreaID = -1  );
// ignore this areatype when finding the route.
bool kbAddAttackRouteIgnoreType( int ignoreAreaTypeID = -1  );
// Rreturns true if path was added to attack route.
bool kbAttackRouteAddPath( int attackRouteID = -1, int pathID = -1  );
// find all the paths to the sector specified.
bool kbMakeAttackRoutes(  );
// Returns num paths from start to goal area.
int kbGetNumAttackRoutes( int startAreaID = -1, int goalAreaID = -1  );
// Returns the id of the routes from area1 to area2.
int kbGetAttackRouteID( int startAreaID = -1, int goalAreaID = -1  );

// ============================================================================
// ESCROWS
// ============================================================================

// Creates an escrow.
int kbEscrowCreate( string name = "", int resourceID = -1, float percentage = 0, int parentID = -1  );
// Destroys an escrow.
bool kbEscrowDestroy( int escrowID = -1, bool promoteChildren = false  );
// Returns the ID of the named escrow.
int kbEscrowGetID( string name = "" );
// Returns the percentage of the escrow.
float kbEscrowGetPercentage( int escrowID = -1, int resourceID = -1  );
// Sets the percentage of the escrow.
bool kbEscrowSetPercentage( int escrowID = -1, int resourceID = -1, float percentage = 0  );
// Sets the cap of the escrow.
bool kbEscrowSetCap( int escrowID = -1, int resourceID = -1, float cap = 0  );
// Returns the amount of credits in the given escrow for the given resource.
float kbEscrowGetAmount( int escrowID = -1, int resourceID = -1  );
// Removes all credits ( and puts them into the root escrow  ) of the given resource type from the given escrow.
bool kbEscrowFlush( int escrowID = -1, int resourceID = -1, bool flushChildren = false  );
// Reallocates the current resource stockpile into the escrows.
bool kbEscrowAllocateCurrentResources(  );

// ============================================================================
// BUILDING PLACEMENTS
// ============================================================================

// Creates a building placement; returns the ID.
int kbBuildingPlacementCreate( string name = "" );
// Destroys the given building placement.
bool kbBuildingPlacementDestroy( int id = -1  );
// Resets the current building placement.
bool kbBuildingPlacementResetResults(  );
// Selects the given building placement.
bool kbBuildingPlacementSelect( int id = -1  );
// Sets event handler function for the current BP and event.
bool kbBuildingPlacementSetEventHandler( int eventType = -1, string handlerName = "" );
// Sets the building type for the current building placement.
bool kbBuildingPlacementSetBuildingType( int buildingTypeID = -1  );
// Sets the base ID and location preference for the current building placement.
bool kbBuildingPlacementSetBaseID( int baseID = -1, int locationPref = -1  );
// Adds the Area ID to the current BP ( with the given number of border area layers  ), addCenterInfluence - adds a positional influence from the area center.
bool kbBuildingPlacementAddAreaID( int areaID = -1, int numberBorderAreaLayers = 0, bool addCenterInfluence = true  );
// Adds the AreaGroup ID to the current BP.
bool kbBuildingPlacementAddAreaGroupID( int areaGroupID = -1  );
// Sets up center position-based BP.
bool kbBuildingPlacementSetCenterPosition( vector position = cInvalidVector, float distance = -1, float obstructionRadius = 6  );
// Adds the unit influence for the current building placement.
bool kbBuildingPlacementAddUnitInfluence( int typeID = -1, float value = -1, float distance = -1, int kbResourceID = -1  );
// Adds the position influence for the current building placement.
bool kbBuildingPlacementAddPositionInfluence( vector position = cInvalidVector, float value = -1, float distance = -1  );
// Sets the minimum acceptable value for evaluated spots in the BP.
bool kbBuildingPlacementSetMinimumValue( float minimumValue = -1  );
// Starts the placement of current building.
bool kbBuildingPlacementStart(  );
// Returns the vector result position for given BP ID.
vector kbBuildingPlacementGetResultPosition( int bpID = -1  );
// Returns the result value for given BP ID.
float kbBuildingPlacementGetResultValue( int bpID = -1  );

// ============================================================================
// TARGET SELECTOR
// ============================================================================

// Creates a target selector; returns the ID.
int kbTargetSelectorCreate( string name = "" );
// Destroys the given target selector.
bool kbTargetSelectorDestroy( int id = -1  );
// Resets the current target selector.
bool kbTargetSelectorResetResults(  );
// Selects the given target selector.
bool kbTargetSelectorSelect( int id = -1  );
// Add the UAIT for the given BASE unit type as a filter.
bool kbTargetSelectorAddUnitType( int protoUnitTypeID = -1  );
// Sets the list of potential targets to the results in the given query.
bool kbTargetSelectorAddQueryResults( int queryID = -1  );
// Returns the number of results in the given target selector.
int kbTargetSelectorGetNumberResults(  );
// Returns the result value for given index of the current target selector.
int kbTargetSelectorGetResultValue( int index = -1  );
// Starts the current target selector.
bool kbTargetSelectorStart(  );
// Returns true if amount of resource is within distance of a dropsite.
bool kbSetupForResource( int baseID = -1, int resourceID = -1, float distance = 15, float amount = 500  );
// sets the TargetSelector Factor value.
void kbSetTargetSelectorFactor( int type = -1, float val = 50  );
// gets the TargetSelector Factor value.
float kbGetTargetSelectorFactor( int type = -1  );

// ============================================================================
// RESOURCES
// ============================================================================

// Returns the current amount XP the given player has.
int kbResourceGetXP( int playerID = -1  );
// Returns the current amount of the given resource.
float kbResourceGet( int resourceID = -1  );
// Returns the maximum amount of the given resource you can have.
float kbMaximumResourceGet( int resourceID = -1  );
// Returns the total amount of the given resource gathered to this point in the game.
float kbTotalResourceGet( int resourceID = -1  );
// Returns the number of valid KB resources for the given plan/base.
int kbGetNumberValidResourcesByPlan( int planID = -1, int baseID = -1  );
// Returns the number of valid KB resources for the resource types.
int kbGetNumberValidResources( int baseID = -1, int resourceTypeID = -1, int resourceSubTypeID = -1, float distance = -1  );
// Returns the resource amount of valid KB resources for the resource types.
float kbGetAmountValidResources( int baseID = -1, int resourceTypeID = -1, int resourceSubTypeID = -1, float distance = -1  );
// Returns the resource income over the last X seconds.
float kbGetResourceIncome( int resourceID = -1, float seconds = 60, bool relative = false  );

// ============================================================================
// TECHTREE
// ============================================================================

// Returns the current HomeCity Level of the given player.
int kbGetHCLevel( int playerID = -1  );
// Returns true if the protoUnit is currently available.
bool kbProtoUnitAvailable( int protoUnitID = -1  );
// Returns the ID of the protounit.
int kbGetProtoUnitID( string name = "" );
// Returns the unit's protounit ID.
int kbUnitGetProtoUnitID( int unitID = -1  );
// Returns true if the player can afford the proto unit.
bool kbCanAffordUnit( int protoUnitTypeID = -1, int escrowID = -1  );
// returns the cost of the protounit for the given resource.
float kbUnitCostPerResource( int protoUnitID = -1, int resourceID = -1  );
// Returns true if the player can afford the tech.
bool kbCanAffordTech( int techID = -1, int escrowID = -1  );
// returns the cost of the tech for the given resource.
float kbTechCostPerResource( int techID = -1, int resourceID = -1  );
// Returns true if the protounit is of the unitTypeID.
bool kbProtoUnitIsType( int playerID = -1, int protoUnitID = -1, int unitTypeID = -1  );
// Returns the current tech status for the current player of the requested tech.
int kbTechGetStatus( int techID = -1  );
// Returns the percent complete for the the requested tech of the current player.
float kbGetTechPercentComplete( int techID = -1  );
// Returns the combat efficiency of the comparison ( in terms of playerID1's units  ).
float kbGetCombatEfficiency( int playerID1 = -1, int unitTypeID1 = -1, int playerID2 = -1, int unitTypeID2 = -1  );
// Returns the AI cost weight for the given resource.
float kbGetAICostWeight( int resourceID = -1  );
// Sets the weight this resource type is given during AI cost calculuations.
bool kbSetAICostWeight( int resourceID = -1, float weight = -1  );
// Returns the AI cost for the given protoUnit type ID.
float kbGetProtoUnitAICost( int protoUnitTypeID = -1  );
// Returns the AI cost for the given tech ID.
float kbGetTechAICost( int techID = -1  );
// Returns the name of the tech ID.
string kbGetTechName( int techID = -1  );

// ============================================================================
// PLAYERS
// ============================================================================

// Returns the player's resigned status.
bool kbIsPlayerResigned( int playerID = -1  );
// Returns the player's lost status.
bool kbHasPlayerLost( int playerID = -1  );
// Returns the player's team number.
int kbGetPlayerTeam( int playerID = -1  );
// Returns the player's name.
string kbGetPlayerName( int playerID = -1  );
// Returns true if the given player is an enemy.
bool kbIsPlayerEnemy( int playerID = -1  );
// Returns true if the given player is a neutral player.
bool kbIsPlayerNeutral( int playerID = -1  );
// Returns true if the given player is an ally.
bool kbIsPlayerAlly( int playerID = -1  );
// Returns true if the given player is a mutual ally.
bool kbIsPlayerMutualAlly( int playerID = -1  );
// Returns the number of mutual allies.
int kbGetNumberMutualAllies(  );
// Returns true if the given player is a valid player ( i.e. it exists in the game  ).
bool kbIsPlayerValid( int playerID = -1  );
// Returns true if the given player is a a human player.
bool kbIsPlayerHuman( int playerID = -1  );
// Returns the player's handicap multiplier ( ie., 1.0 = no handicap  ).
float kbGetPlayerHandicap( int playerID = -1  );
// Sets the indicated player's handicap multiplier ( ie., 1.0 = no handicap  ).
void kbSetPlayerHandicap( int playerID = -1, float handicap = 1  );

// ============================================================================
// BASES
// ============================================================================

// Returns the location of the main town.
vector kbGetTownLocation(  );
// Returns the area ID of the main town.
int kbGetTownAreaID(  );
// Sets the location of the main town.
bool kbSetTownLocation( vector location = cInvalidVector  );
// Returns the auto base creation value.
bool kbGetAutoBaseCreate(  );
// Sets the auto base creation value.
void kbSetAutoBaseCreate( bool v = true  );
// Returns the auto base creation distance.
float kbGetAutoBaseCreateDistance(  );
// Sets the auto base creation distance.
void kbSetAutoBaseCreateDistance( float v = 50  );
// Returns the auto base detection value.
bool kbGetAutoBaseDetect(  );
// Sets the auto base detection value.
void kbSetAutoBaseDetect( bool v = true  );
// Returns the auto base creation distance.
float kbGetAutoBaseDetectDistance(  );
// Sets the auto base creation distance.
void kbSetAutoBaseDetectDistance( float v = 50  );
// gets the nearest base of player relation from the location - see PLAYER RELATIONS in CONSTANTS
int kbFindClosestBase( int playerRelation = -1, vector location = cInvalidVector  );
// Returns the ID of the next base that will be created.
int kbBaseGetNextID(  );
// Returns the number of bases for the given player.
int kbBaseGetNumber( int playerID = -1  );
// Returns the BaseID for the given base.
int kbBaseGetIDByIndex( int playerID = -1, int index = -1  );
// Creates a base.
int kbBaseCreate( int playerID = -1, string name = "NoBaseName", vector position = cInvalidVector, float distance = -1  );
// Finds/Creates a resource base.
int kbBaseFindCreateResourceBase( int resourceType = -1, int resourceSubType = -1, int parentBaseID = -1  );
// Finds/Creates a 'forward' military base against the given enemy base.
int kbBaseFindForwardMilitaryBase( int a = -1, int b = -1, int c = -1  );
// Destroys the given base.
bool kbBaseDestroy( int playerID = -1, int baseID = -1  );
// Destroys all of the bases for the given player.
void kbBaseDestroyAll( int playerID = -1  );
// Gets the location of the base.
vector kbBaseGetLocation( int playerID = -1, int baseID = -1  );
// Gets the last known damage location of the base.
vector kbBaseGetLastKnownDamageLocation( int a = -1, int b = -1  );
// Returns the player ID of the specified base's owner.
int kbBaseGetOwner( int baseID = -1  );
// Sets the front ( and back  ) of the base.
bool kbBaseSetFrontVector( int playerID = -1, int baseID = -1, vector frontVector = cInvalidVector  );
// Gets the front vector of the base.
vector kbBaseGetFrontVector( int playerID = -1, int baseID = -1  );
// Gets the back vector of the base.
vector kbBaseGetBackVector( int playerID = -1, int baseID = -1  );
// Returns the number of continuous seconds the base has been under attack.
int kbBaseGetTimeUnderAttack( int playerID = -1, int baseID = -1  );
// Gets the under attack flag of the base.
bool kbBaseGetUnderAttack( int playerID = -1, int baseID = -1  );
// Sets the active flag of the base.
bool kbBaseSetActive( int playerID = -1, int baseID = -1, bool active = true  );
// Gets the active flag of the base.
bool kbBaseGetActive( int playerID = -1, int baseID = -1  );
// Gets the main base ID for the player.
int kbBaseGetMainID( int playerID = -1  );
// Sets the main flag of the base.
bool kbBaseSetMain( int playerID = -1, int baseID = -1, bool main = true  );
// Gets the main flag of the base.
bool kbBaseGetMain( int playerID = -1, int baseID = -1  );
// Sets the forward flag of the base.
bool kbBaseSetForward( int playerID = -1, int baseID = -1, bool forward = true  );
// Gets the forward flag of the base.
bool kbBaseGetForward( int playerID = -1, int baseID = -1  );
// Sets the settlement flag of the base.
bool kbBaseSetSettlement( int playerID = -1, int baseID = -1, bool settlement = true  );
// Gets the settlement flag of the base.
bool kbBaseGetSettlement( int playerID = -1, int baseID = -1  );
// Sets the military flag of the base.
bool kbBaseSetMilitary( int playerID = -1, int baseID = -1, bool military = true  );
// Gets the military flag of the base.
bool kbBaseGetMilitary( int playerID = -1, int baseID = -1  );
// Gets the military gather point of the base.
vector kbBaseGetMilitaryGatherPoint( int playerID = -1, int baseID = -1  );
// Sets the military gather point of the base.
bool kbBaseSetMilitaryGatherPoint( int playerID = -1, int baseID = -1, vector gatherPoint = cInvalidVector  );
// Sets the economy flag of the base.
bool kbBaseSetEconomy( int playerID = -1, int baseID = -1, bool Economy = true  );
// Gets the economy flag of the base.
bool kbBaseGetEconomy( int playerID = -1, int baseID = -1  );
// Gets the maximum resource distance of the base.
float kbBaseGetMaximumResourceDistance( int playerID = -1, int baseID = -1  );
// Sets the maximum resource distance of the base.
void kbBaseSetMaximumResourceDistance( int playerID = -1, int baseID = -1, float distance = 100  );
// Adds the given unit to the base.
bool kbBaseAddUnit( int playerID = -1, int baseID = -1, int unitID = -1  );
// Removes the given unit to the base.
bool kbBaseRemoveUnit( int playerID = -1, int baseID = -1, int unitID = -1  );
// Returns the number of units that match the criteria - see PLAYER RELATIONS and UNIT TYPES in CONSTANTS
int kbBaseGetNumberUnits( int playerID = -1, int baseID = -1, int relation = -1, int unitTypeID = -1  );
// set the explicit position that every forward base will use.
void kbSetForwardBasePosition( vector position = cInvalidVector  );

// ============================================================================
// UNIT PICKER
// ============================================================================

// Creates a unit pick.
int kbUnitPickCreate( string name = "NoUPName" );
// Destroys the given unit pick.
bool kbUnitPickDestroy( int upID = -1  );
// Resets all of the unit pick data.
bool kbUnitPickResetAll( int upID = -1  );
// Resets the unit pick results.
bool kbUnitPickResetResults( int upID = -1  );
// Gets the unit pick preference weight.
float kbUnitPickGetPreferenceWeight( int upID = -1  );
// Sets the unit pick preference weight.
bool kbUnitPickSetPreferenceWeight( int upID = -1, float v = 0.5  );
// Sets the unit pick enemy player ID.
bool kbUnitPickSetEnemyPlayerID( int upID = -1, int playerID = -1  );
// Sets the unit pick combat efficiency weight.
bool kbUnitPickSetCombatEfficiencyWeight( int upID = -1, float a = 0.5  );
// Resets the enemy unit typeIDs for the unit pick combat efficiency calculation.
bool kbUnitPickResetCombatEfficiencyTypes( int upID = -1  );
// Adds an enemy unit typeID to the unit pick combat efficiency calculation.
bool kbUnitPickAddCombatEfficiencyType( int upID = -1, int typeID = -1, float weight = 1  );
// Sets the unit pick cost weight.
bool kbUnitPickSetCostWeight( int upID = -1, float a = 0.5  );
// Sets the unit pick movement type.
bool kbUnitPickSetMovementType( int upID = -1, int movementType = 1  );
// Sets the unit pick desired number unit types.
bool kbUnitPickSetDesiredNumberUnitTypes( int upID = -1, int number = 1, int numberBuildings = 1, bool degradeNumberBuildings = false  );
// Gets the unit pick desired number unit types.
int kbUnitPickGetDesiredNumberUnitTypes( int upID = -1  );
// Sets the unit pick desired number buildings for the index-th unit type.
bool kbUnitPickSetDesiredNumberBuildings( int upID = -1, int index = 1, int numberBuildings = 1  );
// gets the unit pick desired number buildings for the index-th unit type.
int kbUnitPickGetDesiredNumberBuildings( int upID = -1, int index = 0  );
// Sets the unit pick desired number unit types.
bool kbUnitPickSetMinimumNumberUnits( int upID = -1, int number = 1  );
// Gets the unit pick minimum number units.
int kbUnitPickGetMinimumNumberUnits( int upID = -1  );
// Sets the unit pick desired number unit types.
bool kbUnitPickSetMaximumNumberUnits( int upID = -1, int number = 1  );
// Gets the unit pick maximum number units.
int kbUnitPickGetMaximumNumberUnits( int upID = -1  );
// Sets the unit pick desired min pop.
bool kbUnitPickSetMinimumPop( int upID = -1, int number = 1  );
// Gets the unit pick minimum pop.
int kbUnitPickGetMinimumPop( int upID = -1  );
// Sets the unit pick desired max pop.
bool kbUnitPickSetMaximumPop( int upID = -1, int number = 1  );
// Gets the unit pick maximum pop.
int kbUnitPickGetMaximumPop( int upID = -1  );
// Sets the unit pick attack unit type.
bool kbUnitPickSetAttackUnitType( int upID = -1, int type = 1  );
// Gets the unit pick attack unit type.
int kbUnitPickGetAttackUnitType( int upID = -1  );
// Sets the unit pick attack unit type.
bool kbUnitPickSetGoalCombatEfficiencyType( int upID = -1, int type = 1  );
// Gets the unit pick attack unit type.
int kbUnitPickGetGoalCombatEfficiencyType( int upID = -1  );
// Sets the preferenceFactor for that unit type.
bool kbUnitPickSetPreferenceFactor( int upID = -1, int unitTypeID = -1, float preferenceFactor = 0  );
// Adjusts the preferenceFactor for that unit type ( uses 50.0 as the base if the UP doesn't exist yet  ).
bool kbUnitPickAdjustPreferenceFactor( int upID = -1, int unitTypeID = -1, float baseFactorAdjustment = 0  );
// Runs the unit pick.
int kbUnitPickRun( int upID = -1  );
// Returns the number of unit pick results.
int kbUnitPickGetNumberResults( int upID = -1  );
// Returns the index-th ProtoUnitID.
int kbUnitPickGetResult( int upID = -1, int index = -1  );

// ============================================================================
// PROGRESSION
// ============================================================================

// Creates a unit progression of the given name.
int kbCreateUnitProgression( string unitName = "", string name = "" );
// Creates a tech progression of the given name.
int kbCreateTechProgression( string techName = "", string name = "" );
// gets cheapest researchable unit upgrade, optionally for specified unit/unit line.
int kbTechTreeGetCheapestUnitUpgrade( int unitTypeID = -1  );
// gets cheapest researchable econ upgrade, optionally for specified resource unit type.
int kbTechTreeGetCheapestEconUpgrade( int resourceUnitTypeID = -1  );
// Dumps the current state of the KBTT.
void kbTechTreeDump(  );
// Returns the total number of steps to complete the progression.
int kbProgressionGetTotalNodes( int progressionID = -1  );
// Returns the total cost of the given resource for this progressionID. A resourceID of -1 will return the total Cost.
float kbProgessionGetTotalResourceCost( int progressionID = -1, int resourceID = -1  );
// Returns the type of node at the given index, either Unit type or Tech type.
int kbProgressionGetNodeType( int progressionID = -1, int nodeIndex = -1  );
// Returns the data at nodeIndex, either UnitID or TechID, depending on the type.
int kbProgressionGetNodeData( int progressionID = -1, int nodeIndex = -1  );

/******************************************************************************
    CONSTANTS
******************************************************************************/

// ============================================================================
// UNIT TYPES
// ============================================================================
// This list contains only the internal unit types. If you want to see the
// user-defined units, open Game Folder\Data\protoy.xml (The Asian Dynasties)
// or protox.xml (The War Chiefs) or proto.xml (Age of Empires III)

cUnitTypeUnit
cUnitTypeShip
cUnitTypeBuilding
cUnitTypeMilitaryBuilding
cUnitTypeEconomicBuilding
cUnitTypeDropsite
cUnitTypeResource
cUnitTypeHuntedResource
cUnitTypeMinedResource
cUnitTypeLandResource
cUnitTypeWaterResource
cUnitTypeProjectile
cUnitTypeNature
cUnitTypeSpecialPowers
cUnitTypeUnattackable
cUnitTypeAbstractTemple
cUnitTypeMilitary
cUnitTypeHero
cUnitTypeTree
cUnitTypeAbstractInfantry
cUnitTypeAbstractCavalry
cUnitTypeAbstractArcher
cUnitTypeAbstractVillager
cUnitTypeAbstractFarm
cUnitTypeAbstractDock
cUnitTypeInventoryHolder
cUnitTypeInventoryItem
cUnitTypeUseableItem
cUnitTypeStrengthBonus
cUnitTypeTradeableTo
cUnitTypeTradeableFrom
cUnitTypeAbstractSiegeWeapon
cUnitTypeFlyingUnit
cUnitTypeMythUnit
cUnitTypeEconomic
cUnitTypeRanged
cUnitTypeFastSpeed
cUnitTypeAverageSpeed
cUnitTypeSlowSpeed
cUnitTypeGeneric
cUnitTypeUnitClass
cUnitTypeBuildingClass
cUnitTypeNatureClass
cUnitTypeEmbellishmentClass
cUnitTypeTestClass
cUnitTypeE3Class
cUnitTypeAll
cUnitTypeActionGather
cUnitTypeActionTrain
cUnitTypeActionBuild
cUnitTypeActionAttack
cUnitTypeActionTrickle
cUnitTypeFish
cUnitTypeTransport
cUnitTypeAbstractWall
cUnitTypeHerdable
cUnitTypeAbstractSettlement
cUnitTypeBuildingsThatShoot
cUnitTypeMythUnitGodPower
cUnitTypeParticipatesInBattlecries
cUnitTypeAffectedByTownBell
cUnitTypeMinimapFilterMilitary
cUnitTypeMinimapFilterEconomic
cUnitTypeTradeUnit
cUnitTypeHealable
cUnitTypeFavoriteUnit
cUnitTypeRailroadUnit
cUnitTypeAbstractRailroadStation
cUnitTypeAbstractFort
cUnitTypeAbstractImperialArmy
cUnitTypeAbstractResourceCrate
cUnitTypeAbstractArtillery
cUnitTypeAbstractCavalryInfantry
cUnitTypeAbstractPet
cUnitTypeConvertsHerds
cUnitTypeSocket
cUnitTypeAircraft
cUnitTypeAbstractLightInfantry
cUnitTypeAbstractHeavyCavalry
cUnitTypeHuntable
cUnitTypeGuardian
cUnitTypeAbstractSiegeTrooper
cUnitTypeAbstractFirePit
cUnitTypeAbstractCanSeeStealth
cUnitTypeMercenary
cUnitTypeAbstractWarShip
cUnitTypeAbstractLightCavalry
cUnitTypeAbstractTradeMarket
cUnitTypeAbstractShrine
cUnitTypeAbstractWonder
cUnitTypeAbstractTypeHuntableMagnet
cUnitTypeAbstractTypeHerdableMagnet
cUnitTypeAbstractBannerArmy
cUnitTypeAbstractMonk
cUnitTypeAbstractZamburak
cUnitTypeAbstractSepoy
cUnitTypeAbstractRajput
cUnitTypeAbstractUrumi
cUnitTypeAbstractSowar
cUnitTypeAbstractMahout
cUnitTypeAbstractHowdah
cUnitTypeAbstractMercFlailiphant
cUnitTypeAbstractSiegeElephant
cUnitTypeTrade
cUnitTypeXP
cUnitTypeAbstractDaimyo
cUnitTypeAbstractElephant
cUnitTypeAbstractCamel
cUnitTypeAbstractMilitaryWonder
cUnitTypeAbstractPoliticalWonder
cUnitTypeAbstractReligiousWonder
cUnitTypeAbstractHandElephant
cUnitTypeAbstractGurkha
cUnitTypeAbstractMansabdar
cUnitTypeAbstractChineseMonk
cUnitTypeAbstractGunpowderTrooper
cUnitTypeAbstractHandInfantry
cUnitTypeAbstractHeavyInfantry
cUnitTypeAbstractNativeWarrior
cUnitTypeAbstractRangedInfantry
cUnitTypeAbstractRangedCavalry
cUnitTypeAbstractHandCavalry
cUnitTypeAbstractGunpowderCavalry
cUnitTypeAbstractFishingBoat
cUnitTypeGiantBuddha
cUnitTypeWaterGuardian
cUnitTypeCannotConvertHill
cUnitTypeAbstractJapaneseMonk
cUnitTypeGold
cUnitTypeAnimalPrey
cUnitTypeFood
cUnitTypeWood
cUnitTypeFoodDropsite
cUnitTypeHack
cUnitTypeWoodDropsite
cUnitTypeGoldDropsite
cUnitTypeLogicalTypeVillagersRespondToAttack
cUnitTypeLogicalTypeHandUnitsAutoAttack
cUnitTypeLogicalTypeVillagersAttack
cUnitTypeLogicalTypeNeededForVictory
cUnitTypeLogicalTypeAffectedByTownBell
cUnitTypeNativeBuilding
cUnitTypeAbstractHouse
cUnitTypeLogicalTypeEasySelectAvoid
cUnitTypeColonyBuilding
cUnitTypeLogicalTypeLandMilitary
cUnitTypeLogicalTypeNavalMilitary
cUnitTypeLogicalTypeGarrisonInShips
cUnitTypeAbstractPikeman
cUnitTypeAbstractMine
cUnitTypeLifespanUnit
cUnitTypeTradePostSocket
cUnitTypeNativeSocket
cUnitTypeHasBountyValue
cUnitTypeAbstractLancer
cUnitTypeValidIdleVillager
cUnitTypeMercType2
cUnitTypeMercType3
cUnitTypeMercType4
cUnitTypeMercType5
cUnitTypeVictoryPointBuilding
cUnitTypeLogicalTypeBuildingsNotWalls
cUnitTypeLogicalTypeValidSPCUnitsDeadCondition
cUnitTypeAbstractTownCenter
cUnitTypeLogicalTypeTCBuildLimit
cUnitTypeCountsTowardEconomicScore
cUnitTypeCountsTowardMilitaryScore
cUnitTypeLogicalTypeRangedUnitsAttack
cUnitTypeLogicalTypeRangedUnitsAutoAttack
cUnitTypeLogicalTypeHandUnitsAttack
cUnitTypeLogicalTypeValidSharpshoot
cUnitTypeAbstractFruit
cUnitTypeAbstractNugget
cUnitTypeMercType1
cUnitTypeLogicalTypeMinimapFilterEconomic
cUnitTypeLogicalTypeMinimapFilterMilitary
cUnitTypeLogicalTypeScout
cUnitTypeLogicalTypeShipsAndBuildings
cUnitTypeLogicalTypeHealed
cUnitTypeAbstractWagon
cUnitTypeAbstractWhale
cUnitTypeAbstractFish
cUnitTypeAbstractHandSiege
cUnitTypeAbstractIndianMonk
cUnitTypeAbstractJunk
cUnitTypeAbstractConsulateUnit
cUnitTypeAbstractConsulateSiegeFortress
cUnitTypeAbstractConsulateSiegeIndustrial
cUnitTypeAbstractAgraFort
cUnitTypeAbstractWokou
cUnitTypeAbstractIrregular
cUnitTypeAbstractCaptureable
cUnitTypeAbstractBarracks2
cUnitTypeAbstractStables
cUnitTypeAbstractFoundry
cUnitTypeAbstractConsulateUnitColonial
cUnitTypeAbstractCoyoteMan
cUnitTypeWater
cUnitTypeAbstractNuggetLand
cUnitTypeAbstractNuggetWater
cUnitTypeLogicalTypeValidSabotage
cUnitTypeAbstractPig
cUnitTypeLogicalTypeBuildingsNotWallsOrGroves

// ============================================================================
// UNIT STANCES
// ============================================================================

extern const int cUnitStanceAggressive;
extern const int cUnitStanceDefensive;
extern const int cUnitStancePassive;
extern const int cUnitStanceStandGround;

// ============================================================================
// PLAYER RELATIONS
// ============================================================================

extern const int cPlayerRelationAny;
extern const int cPlayerRelationSelf;
extern const int cPlayerRelationEnemy;
extern const int cPlayerRelationAlly;
extern const int cPlayerRelationEnemyNotGaia;

// ============================================================================
// CARD TYPES
// ============================================================================

extern const int cHCCardTypeEcon;
extern const int cHCCardTypeMilitary;
extern const int cHCCardTypeWagon;
extern const int cHCCardTypeTeam;

// ============================================================================
// RGP SYSTEMS
// ============================================================================

extern const int cRGPScript;
extern const int cRGPCost;
extern const int cRGPActual;

// ============================================================================
// NUGGET TYPES
// ============================================================================

extern const int cNuggetTypeAdjustResource;
extern const int cNuggetTypeSpawnUnit;
extern const int cNuggetTypeGiveLOS;
extern const int cNuggetTypeAdjustSpeed;
extern const int cNuggetTypeAdjustHP;
extern const int cNuggetTypeConvertUnit;
extern const int cNuggetTypeGiveTech;

// ============================================================================
// RESOURCES SUBTYPES
// ============================================================================

extern const int cAIResourceSubTypeEasy;
extern const int cAIResourceSubTypeHerdable;
extern const int cAIResourceSubTypeHunt;
extern const int cAIResourceSubTypeHuntAggressive;
extern const int cAIResourceSubTypeFarm;
extern const int cAIResourceSubTypeFish;
extern const int cAIResourceSubTypeTrade;

extern const int cMaxSettlersPerMine;
extern const int cMaxSettlersPerMill;

// ============================================================================
// TARGET SELECTOR FACTORS
// ============================================================================

extern const int cTSFactorDistance;
extern const int cTSFactorPoint;
extern const int cTSFactorTimeToDone;
extern const int cTSFactorBase;
extern const int cTSFactorDanger;

// ============================================================================
// ESCROWS
// ============================================================================

extern const int cRootEscrowID;
extern const int cEconomyEscrowID;
extern const int cMilitaryEscrowID;
extern const int cEmergencyEscrowID;

// ============================================================================
// PLAN TYPES
// ============================================================================

extern const int cPlanMove;
extern const int cPlanAttack;
extern const int cPlanBuild;
extern const int cPlanTrain;
extern const int cPlanResearch;
extern const int cPlanWork;
extern const int cPlanGather;
extern const int cPlanExplore;
extern const int cPlanData;
extern const int cPlanProgression;
extern const int cPlanFarm;
extern const int cPlanHunt;
extern const int cPlanHuntAggressive;
extern const int cPlanFish;
extern const int cPlanHerd;
extern const int cPlanTransport;
extern const int cPlanAttackStrategy;
extern const int cPlanRemoved1;
extern const int cPlanDefend;
extern const int cPlanReserve;
extern const int cPlanGoal;
extern const int cPlanGatherGoal;
extern const int cPlanTrade;
extern const int cPlanGatherNuggets;
extern const int cPlanMission;
extern const int cPlanBuildWall;
extern const int cPlanTownBell;
extern const int cPlanTower;
extern const int cPlanNativeResearch;

// ============================================================================
// OPPORTUNITY SOURCES
// ============================================================================

extern const int cOpportunitySourceAutoGenerated;
extern const int cOpportunitySourceAllyRequest;
extern const int cOpportunitySourceTrigger;

// ============================================================================
// OPPORTUNITY TYPES
// ============================================================================

extern const int cOpportunityTypeDestroy;
extern const int cOpportunityTypeClaim;
extern const int cOpportunityTypeRaid;
extern const int cOpportunityTypeDefend;
extern const int cOpportunityTypeRescueExplorer;

// ============================================================================
// OPPORTUNITY TARGET TYPES
// ============================================================================

extern const int cOpportunityTargetTypeBase;
extern const int cOpportunityTargetTypeVPSite;
extern const int cOpportunityTargetTypeResource;
extern const int cOpportunityTargetTypePointRadius;
extern const int cOpportunityTargetTypeUnitList;

// ============================================================================
// MISSION TYPES
// ============================================================================

extern const int cMissionTypeNone;
extern const int cMissionTypeAttack;
extern const int cMissionTypeDefend;
extern const int cMissionTypeClaim;
extern const int cMissionTypeRaid;

// ============================================================================
// PLAN STATES
// ============================================================================

extern const int cPlanStateNone;
extern const int cPlanStateDone;
extern const int cPlanStateFailed;
extern const int cPlanStateBuild;
extern const int cPlanStateGather;
extern const int cPlanStatePlace;
extern const int cPlanStateExplore;
extern const int cPlanStateTrain;
extern const int cPlanStateResearch;
extern const int cPlanStateAttack;
extern const int cPlanStateGoto;
extern const int cPlanStateEmpower;
extern const int cPlanStateEnter;
extern const int cPlanStateExit;
extern const int cPlanStateEvaluate;
extern const int cPlanStatePatrol;
extern const int cPlanStateRetreat;
extern const int cPlanStateWorking;
extern const int cPlanStateTransport;
extern const int cPlanStateDualPlace;
extern const int cPlanStateWait;
extern const int cPlanStateCast;
extern const int cPlanStateVillagerAttack;
extern const int cPlanStateClaimNugget;
extern const int cPlanStateGatherResources;
extern const int cPlanStateIdle;

// ============================================================================
// PLAN EVENTS
// ============================================================================

extern const int cPlanEventDone;
extern const int cPlanEventFailed;
extern const int cPlanEventPoll;
extern const int cPlanEventIdle;
extern const int cPlanEventStateChange;

// ============================================================================
// PLAN VARIABLES
// ============================================================================

// Gather plan
extern const int cGatherPlanKBResourceID;
extern const int cGatherPlanResourceID;
extern const int cGatherPlanResourceType;
extern const int cGatherPlanResourceSubType;
extern const int cGatherPlanBreakDownID;
extern const int cGatherPlanResourceUnitTypeFilter;
extern const int cGatherPlanFindNewResourceTimeOut;

// Build plan
extern const int cBuildPlanBuildingPlacementID;
extern const int cBuildPlanBuildingTypeID;
extern const int cBuildPlanInfluenceUnitTypeID;
extern const int cBuildPlanInfluenceUnitDistance;
extern const int cBuildPlanInfluenceUnitValue;
extern const int cBuildPlanInfluenceUnitFalloff;
extern const int cBuildPlanAreaID;
extern const int cBuildPlanCenterPosition;
extern const int cBuildPlanCenterPositionDistance;
extern const int cBuildPlanVPSiteID;
extern const int cBuildPlanSocketID;
extern const int cBuildPlanBuildUnitID;
extern const int cBuildPlanFoundationID;
extern const int cBuildPlanInfluencePosition;
extern const int cBuildPlanInfluencePositionDistance;
extern const int cBuildPlanInfluencePositionValue;
extern const int cBuildPlanInfluencePositionFalloff;
extern const int cBuildPlanDockPlacementPoint;
extern const int cBuildPlanNumAreaBorderLayers;
extern const int cBuildPlanBuildingBufferSpace;
extern const int cBuildPlanFailOnUnaffordable;
extern const int cBuildPlanInfluenceKBResourceID;
extern const int cBuildPlanRandomBPValue;
extern const int cBuildPlanInfluenceAtBuilderPosition;
extern const int cBuildPlanInfluenceBuilderPositionValue;
extern const int cBuildPlanInfluenceBuilderPositionDistance;
extern const int cBuildPlanInfluenceBuilderPositionFalloff;
extern const int cBuildPlanRetries;
extern const int cBuildPlanMaxRetries;
extern const int cBuildPlanPendingCommands;
extern const int cBuildPlanFailureCause;
extern const int cBuildPlanFailureCauseFloat;
extern const int cBuildPlanMaxCanPaths;
extern const int cBuildPlanCanPathStartIndex;
extern const int cBuildPlanInfluenceVPSiteType;
extern const int cBuildPlanInfluenceVPSiteTypeValue;
extern const int cBuildPlanInfluenceVPSiteTypeDistance;
extern const int cBuildPlanInfluenceVPSiteTypeFalloff;

// Train plan
extern const int cTrainPlanBuildingID;
extern const int cTrainPlanIntoArmyID;
extern const int cTrainPlanIntoPlanID;
extern const int cTrainPlanIntoBaseID;
extern const int cTrainPlanNumberToTrain;
extern const int cTrainPlanNumberToMaintain;
extern const int cTrainPlanNumberTrained;
extern const int cTrainPlanUnitType;
extern const int cTrainPlanBuildFromType;
extern const int cTrainPlanTrainedUnitID;
extern const int cTrainPlanFrequency;
extern const int cTrainPlanUseMultipleBuildings;
extern const int cTrainPlanGatherPoint;
extern const int cTrainPlanGatherTargetID;
extern const int cTrainPlanMaintainBaseID;
extern const int cTrainPlanMaintainAreaID;
extern const int cTrainPlanBatchSize;
extern const int cTrainPlanMaxQueueSize;

// Explore plan
extern const int cExplorePlanLOSMultiplier;
extern const int cExplorePlanDoLoops;
extern const int cExplorePlanDoneLoops;
extern const int cExplorePlanNumberOfLoops;
extern const int cExplorePlanPointsInLoop;
extern const int cExplorePlanAvoidingAttackedAreas;
extern const int cExplorePlanReExploreAreas;
extern const int cExplorePlanLOSProtoUnitID;
extern const int cExplorePlanBuildPosition;
extern const int cExplorePlanBuilderUnitType;
extern const int cExplorePlanCanBuildLOSProto;
extern const int cExplorePlanHandleDamageTime;
extern const int cExplorePlanHandleDamageFrequency;
extern const int cExplorePlanQuitWhenPointIsVisible;
extern const int cExplorePlanQuitWhenPointIsVisiblePt;
extern const int cExplorePlanCurrentNuggetID;
extern const int cExplorePlanNuggetsToGather;
extern const int cExplorePlanOkToGatherNuggets;

// Research plan
extern const int cResearchPlanBuildingID;
extern const int cResearchPlanBuildingTypeID;
extern const int cResearchPlanTechID;
extern const int cResearchPlanBuildingAbstractTypeID;

// Attack plan
extern const int cAttackPlanPlayerID;
extern const int cAttackPlanSpecificTargetID;
extern const int cAttackPlanTargetTypeID;
extern const int cAttackPlanQueryID;
extern const int cAttackPlanAttackRouteID;
extern const int cAttackPlanAttackRoutePattern;
extern const int cAttackPlanGatherPoint;
extern const int cAttackPlanGatherDistance;
extern const int cAttackPlanTargetID;
extern const int cAttackPlanMoveAttack;
extern const int cAttackPlanNumberAttacks;
extern const int cAttackPlanRefreshFrequency;
extern const int cAttackPlanLastRefreshTime;
extern const int cAttackPlanHandleDamageTime;
extern const int cAttackPlanHandleDamageFrequency;
extern const int cAttackPlanBaseAttackMode;
extern const int cAttackPlanPathID;
extern const int cAttackPlanFromGoalID;
extern const int cAttackPlanRetreatMode;
extern const int cAttackPlanTargetAreaGroups;
extern const int cAttackPlanTeleportLocation;
extern const int cAttackPlanAutoUseGPs;
extern const int cAttackPlanPowerID;
extern const int cAttackPlanGatherStartTime;
extern const int cAttackPlanTargetResourceType;
extern const int cAttackPlanAttackPoint;
extern const int cAttackPlanAttackPointEngageRange;
extern const int cAttackPlanAttackExplicitBaseID;
extern const int cAttackPlanGatherWaitTime;
extern const int cAttackPlanAttackRoutePatternLRU;
extern const int cAttackPlanAttackRoutePatternMRU;
extern const int cAttackPlanAttackRoutePatternRandom;
extern const int cAttackPlanAttackRoutePatternBest;
extern const int cAttackPlanBaseAttackModeNone;
extern const int cAttackPlanBaseAttackModeWeakest;
extern const int cAttackPlanBaseAttackModeStrongest;
extern const int cAttackPlanBaseAttackModeLRU;
extern const int cAttackPlanBaseAttackModeMRU;
extern const int cAttackPlanBaseAttackModeRandom;
extern const int cAttackPlanBaseAttackModeClosest;
extern const int cAttackPlanBaseAttackModeFarthest;
extern const int cAttackPlanBaseAttackModeExplicit;
extern const int cAttackPlanRetreatModeNone;
extern const int cAttackPlanRetreatModeOutnumbered;
extern const int cAttackPlanRetreatModeWillLose;

// Progression plan
extern const int cProgressionPlanPollingTime;
extern const int cProgressionPlanProgressionID;
extern const int cProgressionPlanTrainUnitAtEnd;
extern const int cProgressionPlanNumGoalUnitsToBuild;
extern const int cProgressionPlanGoalUnitID;
extern const int cProgressionPlanGoalTechID;
extern const int cProgressionPlanBuildAreaID;
extern const int cProgressionPlanCurrentGoalID;
extern const int cProgressionPlanCurrentGoalType;
extern const int cProgressionPlanCurrentStep;
extern const int cProgressionPlanCurrentStepPlanID;
extern const int cProgressionPlanPaused;
extern const int cProgressionPlanAdvanceOneStep;
extern const int cProgressionPlanRunInParallel;
extern const int cProgressionPlanChildProgressions;
extern const int cProgressionPlanBuildingPref;

// Herd plan
extern const int cHerdPlanBuildingID;
extern const int cHerdPlanBuildingTypeID;
extern const int cHerdPlanDistance;

// Fish plan
extern const int cFishPlanLandPoint;
extern const int cFishPlanWaterPoint;
extern const int cFishPlanLandGroupID;
extern const int cFishPlanWaterGroupID;
extern const int cFishPlanAutoTrainBoats;
extern const int cFishPlanNumberInTraining;
extern const int cFishPlanDockID;
extern const int cFishPlanMaximumDockDist;
extern const int cFishPlanPlaceRetries;
extern const int cFishPlanMaxPlaceRetries;
extern const int cFishPlanBuildDock;

// Transport plan
extern const int cTransportPlanTransportID;
extern const int cTransportPlanTransportTypeID;
extern const int cTransportPlanGatherPoint;
extern const int cTransportPlanTargetPoint;
extern const int cTransportPlanGatherAreaGroup;
extern const int cTransportPlanTargetAreaGroup;
extern const int cTransportPlanGatherArea;
extern const int cTransportPlanTargetArea;
extern const int cTransportPlanPathType;
extern const int cTransportPlanPathPlanned;
extern const int cTransportPlanReturnWhenDone;
extern const int cTransportPlanMaximizeXportMovement;
extern const int cTransportPlanUnitsMoved;
extern const int cTransportPlanIgnoreAreaIDs;
extern const int cTransportPlanBestDangerArea;
extern const int cTransportPlanBestDangerValue;
extern const int cTransportPlanDropOffPoint;
extern const int cTransportPlanPersistent;
extern const int cTransportPlanMiddleAreaGroups;
extern const int cTransportPlanTakeMoreUnits;

// Trade plan - not implemented in AOE3
extern const int cTradePlanTargetUnitTypeID;
extern const int cTradePlanTargetUnitID;
extern const int cTradePlanStartPosition;
extern const int cTradePlanTradeUnitType;
extern const int cTradePlanTradeUnitTypeMax;
extern const int cTradePlanMarketID;

// Tower plan - not implemented in AOE3
extern const int cTowerPlanCenterLocation;
extern const int cTowerPlanAreaID;
extern const int cTowerPlanDistanceFromCenter;
extern const int cTowerPlanMaximizeLOS;
extern const int cTowerPlanMaximizeAttack;
extern const int cTowerPlanNumberToBuild;
extern const int cTowerPlanBuildLocations;
extern const int cTowerPlanProtoIDToBuild;
extern const int cTowerPlanAttackLOSModifier;
extern const int cTowerPlanLOSModifier;

extern const int cAttackStrategyPlanPlayerID;
extern const int cAttackStrategyPlanNumberTotalAttacks;

// Defend plan
extern const int cDefendPlanDefendTargetID;
extern const int cDefendPlanDefendAreaID;
extern const int cDefendPlanDefendBaseID;
extern const int cDefendPlanDefendPoint;
extern const int cDefendPlanEngageRange;
extern const int cDefendPlanPatrol;
extern const int cDefendPlanPatrolWaypoint;
extern const int cDefendPlanCurrentWaypoint;
extern const int cDefendPlanTargetID;
extern const int cDefendPlanGatherDistance;
extern const int cDefendPlanRefreshFrequency;
extern const int cDefendPlanLastRefreshTime;
extern const int cDefendPlanAttackTypeID;
extern const int cDefendPlanGatherPercentage;
extern const int cDefendPlanNoTargetTimeout;
extern const int cDefendPlanNoTargetTimer;
extern const int cDefendPlanStopTakingUnits;
extern const int cDefendPlanStopTakingUnitTime;

// Nugget plan
extern const int cNuggetPlanGatherDistance;
extern const int cNuggetPlanGatherPercentage;
extern const int cNuggetPlanMaxGuardianStrength;
extern const int cNuggetPlanTargetNuggetID;
extern const int cNuggetPlanTargetGatherPosition;

// Reserve plan
extern const int cReservePlanPlanType;

// Goal plan
extern const int cGoalPlanGoalType;
extern const int cGoalPlanGoalSubType;
extern const int cGoalPlanMinTime;
extern const int cGoalPlanMaxTime;
extern const int cGoalPlanMinAge;
extern const int cGoalPlanMaxAge;
extern const int cGoalPlanRepeat;
extern const int cGoalPlanExecuteCount;
extern const int cGoalPlanDoneGoal;
extern const int cGoalPlanFailGoal;
extern const int cGoalPlanExecuteGoal;
extern const int cGoalPlanAutoUpdateState;
extern const int cGoalPlanAutoUpdateBase;
extern const int cGoalPlanAutoUpdateAttackPlayerID;
extern const int cGoalPlanTargetType;
extern const int cGoalPlanTarget;
extern const int cGoalPlanTargetPoint;
extern const int cGoalPlanTargetNumber;
extern const int cGoalPlanMinUnitNumber;
extern const int cGoalPlanMaxUnitNumber;
extern const int cGoalPlanUnitPickerID;
extern const int cGoalPlanUnitPickerFrequency;
extern const int cGoalPlanUnitPickerTime;
extern const int cGoalPlanAttackPlayerID;
extern const int cGoalPlanAttackStartFrequency;
extern const int cGoalPlanAttackStartTime;
extern const int cGoalPlanUnitTypeID;
extern const int cGoalPlanBaseID;
extern const int cGoalPlanAllowRetreat;
extern const int cGoalPlanUpgradeBuilding;
extern const int cGoalPlanSetAreaGroups;
extern const int cGoalPlanIdleAttack;
extern const int cGoalPlanAreaGroupID;
extern const int cGoalPlanFunctionID;
extern const int cGoalPlanFunctionParm;
extern const int cGoalPlanBuildingTypeID;
extern const int cGoalPlanBuildingPlacementID;
extern const int cGoalPlanBuildingSearchID;
extern const int cGoalPlanActiveHealthTypeID;
extern const int cGoalPlanActiveHealth;
extern const int cGoalPlanAttackRoutePatternType;
extern const int cGoalPlanUpgradeFilterType;
extern const int cGoalPlanReservePlanID;
extern const int cGoalPlanFindBestOpp;
extern const int cGoalPlanMinOppScoreForGo;
extern const int cGoalPlanGoalTypeForwardBase;
extern const int cGoalPlanGoalTypeCreateBase;
extern const int cGoalPlanGoalTypeMainBase;
extern const int cGoalPlanGoalTypeAttack;
extern const int cGoalPlanGoalTypeDefend;
extern const int cGoalPlanGoalTypeTrain;
extern const int cGoalPlanGoalTypeMaintain;
extern const int cGoalPlanGoalTypeResearch;
extern const int cGoalPlanGoalTypeAge;
extern const int cGoalPlanGoalTypeCallback;
extern const int cGoalPlanGoalTypeBuilding;
extern const int cGoalPlanGoalSubTypeEmpty1;
extern const int cGoalPlanGoalSubTypeEmpty2;
extern const int cGoalPlanTargetTypeArea;
extern const int cGoalPlanTargetTypeAreaGroup;
extern const int cGoalPlanTargetTypePoint;
extern const int cGoalPlanTargetTypeUnitType;
extern const int cGoalPlanTargetTypeUnit;
extern const int cGoalPlanTargetTypePlayer;
extern const int cGoalPlanTargetTypePlayerRelation;
extern const int cGoalPlanTargetTypeTech;

// Gather goal plan
extern const int cGatherGoalPlanScriptRPGPct;
extern const int cGatherGoalPlanCostRPGPct;
extern const int cGatherGoalPlanGathererPct;
extern const int cGatherGoalPlanNumFoodPlans;
extern const int cGatherGoalPlanNumWoodPlans;
extern const int cGatherGoalPlanNumGoldPlans;
extern const int cGatherGoalPlanMinResourceAmt;
extern const int cGatherGoalPlanResourceCostWeight;
extern const int cGatherGoalPlanFarmLimitPerPlan;
extern const int cGatherGoalPlanMaxFarmLimit;
extern const int cGatherGoalPlanResourceSkew;

// Wall build plan
extern const int cBuildWallPlanWallType;
extern const int cBuildWallPlanWallStart;
extern const int cBuildWallPlanWallEnd;
extern const int cBuildWallPlanWallRingCenterPoint;
extern const int cBuildWallPlanWallRingRadius;
extern const int cBuildWallPlanNumberOfGates;
extern const int cBuildWallPlanAreaIDs;
extern const int cBuildWallPlanFoundationID;
extern const int cBuildWallPlanGateIndices;
extern const int cBuildWallPlanGateProtoIDs;
extern const int cBuildWallPlanEdgeOfMapBuffer;
extern const int cBuildWallPlanPieces;
extern const int cBuildWallPlanPiecePositions;
extern const int cBuildWallPlanPieceRotations;
extern const int cBuildWallPlanEnRoute;
extern const int cBuildWallPlanWallTypeStraight;
extern const int cBuildWallPlanWallTypeRing;
extern const int cBuildWallPlanWallTypeArea;

// Missions
extern const int cMissionPlanPlanID;
extern const int cMissionPlanType;
extern const int cMissionPlanStartTime;
extern const int cMissionPlanTarget;
extern const int cMissionPlanVector1;
extern const int cMissionPlanVector2;
extern const int cMissionPlanFloat1;
extern const int cMissionPlanFloat2;
extern const int cMissionPlanOpportunityID;


extern const int cTransportPathTypePoints;
extern const int cTransportPathTypeAreas;

// Firepit dance plan
extern const int cNativeResearchPlanBuildingID;
extern const int cNativeResearchPlanTacticID;

// ============================================================================
// RESIGN TYPES
// ============================================================================

extern const int cResignGatherers;
extern const int cResignTeammates;
extern const int cResignMilitaryPop;

// ============================================================================
// MOVEMENT TYPES
// ============================================================================

extern const int cMovementTypeNone;
extern const int cMovementTypeLand;
extern const int cMovementTypeWater;
extern const int cMovementTypeAir;
extern const int cMovementTypeNonSolid;

// ============================================================================
// UNIT STATES
// ============================================================================

extern const int cUnitStateNone;
extern const int cUnitStateBuilding;
extern const int cUnitStateAlive;
extern const int cUnitStateDead;
extern const int cUnitStateQueued;
extern const int cUnitStateAny;
extern const int cUnitStateABQ;

// ============================================================================
// BUILDING PLACEMENT EVENTS
// ============================================================================

extern const int cBuildingPlacementEventDone;
extern const int cBuildingPlacementEventFailed;

extern const int cUnitQueryNoArmy;
extern const int cUnitQueryInvalidArmy;

// ============================================================================
// BUILDING PLACEMENT PREFERENCES
// ============================================================================

extern const int cBuildingPlacementPreferenceNone;
extern const int cBuildingPlacementPreferenceBack;
extern const int cBuildingPlacementPreferenceFront;
extern const int cBuildingPlacementPreferenceLeft;

// ============================================================================
// BUILDING PLACEMENT INFLUENCES
// ============================================================================

extern const int cBPIFalloffLinear;
extern const int cBPIFalloffNone;
extern const int cBPIFalloffLinearInverse;

// ============================================================================
// RESOURCE TYPES
// ============================================================================

extern const int cResourceGold;
extern const int cResourceWood;
extern const int cResourceFood;
extern const int cResourceFame;
extern const int cResourceSkillPoints;
extern const int cResourceXP;
extern const int cResourceShips;
extern const int cResourceTrade;
extern const int cAllResources;

// ============================================================================
// TECH STATUSES
// ============================================================================

extern const int cTechStatusUnobtainable;
extern const int cTechStatusObtainable;
extern const int cTechStatusActive;

// ============================================================================
// ATTACK ROUTES
// ============================================================================

extern const int cAttackRouteFrontRight;
extern const int cAttackRouteRightFront;
extern const int cAttackRouteRightBack;
extern const int cAttackRouteBackRight;
extern const int cAttackRouteBackLeft;
extern const int cAttackRouteLeftBack;
extern const int cAttackRouteLeftFront;
extern const int cAttackRouteFrontLeft;

// ============================================================================
// AREA TYPES
// ============================================================================

extern const int cAreaTypeForest;
extern const int cAreaTypeWater;
extern const int cAreaTypeImpassableLand;
extern const int cAreaTypeVPSite;
extern const int cAreaGroupTypeLand;
extern const int cAreaGroupTypeWater;
extern const int cAreaGroupTypeImpassableLand;

// ============================================================================
// EVENT HANDLERS
// ============================================================================

extern const int cXSAgeHandler;
extern const int cXSPowerHandler;
extern const int cXSRetreatHandler;
extern const int cXSResignHandler;
extern const int cXSBuildHandler;
extern const int cXSHomeCityTransportArriveHandler;
extern const int cXSHomeCityTransportReturnHandler;
extern const int cXSHomeCityLevelUpHandler;
extern const int cXSTreatyBrokenHandler;
extern const int cXSShipResourceGranted;
extern const int cXSAutoCreatePlanHandler;
extern const int cXSNuggetHandler;
extern const int cXSPlayerAgeHandler;
extern const int cXSScoreOppHandler;
extern const int cXSMissionStartHandler;
extern const int cXSMissionEndHandler;
extern const int cXSGameOverHandler;
extern const int cXSMonopolyStartHandler;
extern const int cXSMonopolyEndHandler;
extern const int cXSWonderVictoryStartHandler;
extern const int cXSWonderVictoryEndHandler;
extern const int cXSRelicVictoryStartHandler;
extern const int cXSRelicVictoryEndHandler;
extern const int cXSKOTHVictoryStartHandler;
extern const int cXSKOTHVictoryEndHandler;

// ============================================================================
// PLAYER CHAT VERBS
// ============================================================================

extern const int cPlayerChatVerbInvalid;
extern const int cPlayerChatVerbAttack;
extern const int cPlayerChatVerbDefend;
extern const int cPlayerChatVerbTribute;
extern const int cPlayerChatVerbFeed;
extern const int cPlayerChatVerbCancel;
extern const int cPlayerChatVerbClaim;
extern const int cPlayerChatVerbTrain;
extern const int cPlayerChatVerbStrategy;

// ============================================================================
// PLAYER CHAT TARGET TYPES
// ============================================================================

extern const int cPlayerChatTargetTypeInvalid;
extern const int cPlayerChatTargetTypePlayers;
extern const int cPlayerChatTargetTypeUnits;
extern const int cPlayerChatTargetTypeUnitTypes;
extern const int cPlayerChatTargetTypeResource;
extern const int cPlayerChatTargetTypeLocation;

// ============================================================================
// PLAYER CHAT TARGET STRATEGIES
// ============================================================================

extern const int cPlayerChatTargetStrategyInvalid;
extern const int cPlayerChatTargetStrategyRush;
extern const int cPlayerChatTargetStrategyBoom;
extern const int cPlayerChatTargetStrategyTurtle;

// ============================================================================
// PLAYER CHAT RESPONSE TYPES
// ============================================================================

extern const int cPlayerChatResponseTypeYes;
extern const int cPlayerChatResponseTypeNo;

// ============================================================================
// VICTORY POINT TYPES
// ============================================================================

extern const int cVPInvalid;
extern const int cVPAll;
extern const int cVPNative;
extern const int cVPSecret;
extern const int cVPTrade;
extern const int cVPConqueror;
extern const int cVPGranted;

// ============================================================================
// VICTORY POINT STATES
// ============================================================================

extern const int cVPStateAny;
extern const int cVPStateNone;
extern const int cVPStateSite;
extern const int cVPStateBuilding;
extern const int cVPStateCompleted;

// ============================================================================
// GAME TYPES
// ============================================================================

extern const int cGameTypeScenario;
extern const int cGameTypeSaved;
extern const int cGameTypeRandom;
extern const int cGameTypeCampaign;

// ============================================================================
// AGES
// ============================================================================

extern const int cAge1;
extern const int cAge2;
extern const int cAge3;
extern const int cAge4;
extern const int cAge5;

// ============================================================================
// DIFFICULTIES
// ============================================================================

extern const int cDifficultySandbox;
extern const int cDifficultyEasy;
extern const int cDifficultyModerate;
extern const int cDifficultyHard;
extern const int cDifficultyExpert;