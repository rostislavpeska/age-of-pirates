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
    }
    if (getGaiaUnitCount(cUnitTypezpNativeHouseJewish) > 0)
    {
        xsEnableRule("maintainJewishSettlers");
    }
    if ((getGaiaUnitCount(cUnitTypezpSPCBlueMosque) > 0) || (getGaiaUnitCount(cUnitTypezpSPCGreatMosque) > 0))
    {
        xsEnableRule("maintainSufiSettlers");
        xsEnableRule("maintainSufiBedouins");
        xsEnableRule("SufiBigButtonMonitor");
        xsEnableRule("SufiTechMonitor");
        xsEnableRule("SufiWhiteFortManager");
    }
    if (getGaiaUnitCount(cUnitTypezpSPCGreatBuddha) > 0)
    {
        xsEnableRule("maintainZenSettlers");
        xsEnableRule("ZenBigButtonMonitor");
        xsEnableRule("ZenTechMonitor");
        xsEnableRule("nativeWagonMonitor");
    }
    if (getGaiaUnitCount(cUnitTypezpNativeAztecTempleA) > 0)
    {
        xsEnableRule("zpMaintainAztecNativeVillagers");
        xsEnableRule("zpNativeAztecBigButtonMonitor");
        xsEnableRule("nativeWagonMonitor");
        xsEnableRule("zpAztecTechMonitor");
    }
    if (getGaiaUnitCount(cUnitTypezpWeaponFactoryWinter) > 0)
    {
        xsEnableRule("MaintainScientistShips");
        xsEnableRule("MaintainScientistTanks");
        xsEnableRule("MaintainScientistAirship");
        xsEnableRule("zpScientistTechMonitor");
        xsEnableRule("nativeWagonMonitor");
        xsEnableRule("submarineTactics");
    }

    if (getGaiaUnitCount(cUnitTypezpNativeHouseInuit) > 0)
    {
        xsEnableRule("zpInuitTechMonitor");

    }
    if (getGaiaUnitCount(cUnitTypezpNativeHouseMaltese) > 0)
    {
        xsEnableRule("zpMalteseTechMonitor");

    }
    
    xsDisableSelf();
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
            subTactic = cTacticzpDive;
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
minInterval 30
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
mininterval 60
{
   if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
      {
      return; // Player has no Aztec socket.
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
// Maintain Proxies in Scientist Trading Post
//==============================================================================

rule MaintainScientistShips
inactive
minInterval 30
{
  const int list_size = 23;
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
minInterval 30
{
  const int list_size = 1;
  static int proxy_list = -1;
  static int ship_list = -1;

  if (kbUnitCount(cMyID, cUnitTypezpSocketScientists, cUnitStateAny) == 0)
   {
      return;
   }

   if (kbTechGetStatus(cTechzpBattleAirship) == cTechStatusActive)
   {

      if (proxy_list == -1)
      {
         proxy_list = xsArrayCreateInt(list_size, -1, "List of Scientist Airship Proxies");
         ship_list = xsArrayCreateInt(list_size, -1, "List of Scientist Airships");

         xsArraySetInt(proxy_list, 0, cUnitTypezpAirshipProxy);
         xsArraySetInt(ship_list, 0, cUnitTypezpAirship);
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
}