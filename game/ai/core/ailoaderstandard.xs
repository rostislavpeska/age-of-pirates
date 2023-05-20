//==============================================================================
/* aiLoaderStandard.xs
   
   Create a new loader file for each personality.  Always specify loader
   file names (not the main or header files) in scenarios.
*/
//==============================================================================



include "aiHeader.xs";     // Gets global vars, function forward declarations
include "aiMain.xs";       // The bulk of the AI



//==============================================================================
/*	preInit()

	This function is called in main() before any of the normal initialization 
	happens.  Use it to override default values of variables as needed for 
	personality or scenario effects.
*/
//==============================================================================
void preInit(void)
{
   aiEcho("preInit() starting.");

   if (aiGetGameMode() == cGameModeEconomyMode)
   {
      aiEcho("Economy mode setup");

      btRushBoom = -1.0; // boom
      btOffenseDefense = -1.0; // defend
      cvOkToAttack = false;
      cvOkToTrainArmy = false;
      cvOkToTrainNavy = false;
      cvOkToAllyNatives = false;
   }
}




//==============================================================================
/*	postInit()

	This function is called in main() after the normal initialization is 
	complete.  Use it to override settings and decisions made by the startup logic.
*/
//==============================================================================
void postInit(void)
{
   aiEcho("postInit() starting.");
}




//==============================================================================
/*	Rules

	Add personality-specific or scenario-specific rules in the section below.
*/
//==============================================================================

//==============================================================================
// Water Trade Route Socfkets
//==============================================================================

rule CaribTPMonitor
active
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
active
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
active
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
active
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

    xsArraySetInt(proxy_list, 1, cUnitTypezpFireShipProxy);
    xsArraySetInt(ship_list, 1, cUnitTypeypFireship);

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
active
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
active
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
active
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
active
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
active
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
active
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
active
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
