# Raw Tortuga

Due to some limitations in `triggerdata.xml`, it is impossible to have a well-formatted trigger template code.
The resulting `trigtemp.xs` output looks extremely awful. Here's the raw script, shoud be much nicer to read :)

> ℹ️ I will write a more detailed documentation once this feature is finely tuned.

```cpp
// ==============================================================================================================
// Returns the index-th unit matching the criteria. Returns a random unit if index is negative.
// Use at the outermost layer of a nested loop.
// ==============================================================================================================
int zpGetUnit1(int unitTypeID = -1,
              int owner = cPlayerRelationAny,
              vector position = cInvalidVector,
              float distance = 30.0,
              int index = -1,
              int state = cUnitStateAlive)
{
  int ctx = xsGetContextPlayer();
  xsSetContextPlayer(0);
  kbLookAtAllUnitsOnMap();

  int numFound = 0;
  int unitID = -1;

  static int queryID = -1;
  if (queryID == -1) {
    queryID = kbUnitQueryCreate("ZP Get Unit 1");
    kbUnitQuerySetIgnoreKnockedOutUnits(queryID, true);
    kbUnitQuerySetAscendingSort(queryID, true);
  }

  if (index <= 0) {
    kbUnitQueryResetResults(queryID);
    kbUnitQuerySetUnitType(queryID, unitTypeID);
    kbUnitQuerySetState(queryID, state);
    kbUnitQuerySetPosition(queryID, position);
    kbUnitQuerySetMaximumDistance(queryID, distance);

    if (kbIsPlayerValid(owner) == true) {
      kbUnitQuerySetPlayerRelation(queryID, -1);
      kbUnitQuerySetPlayerID(queryID, owner, false);
    } else {
      kbUnitQuerySetPlayerID(queryID, -1, false);
      kbUnitQuerySetPlayerRelation(queryID, owner);
    }

    numFound = kbUnitQueryExecute(queryID);

    if (index <= -1) {
      trQuestVarSetFromRand("ZP Get Unit 1 Index", 0, numFound);
      unitID = kbUnitQueryGetResult(queryID, trQuestVarGet("ZP Get Unit 1 Index"));
      xsSetContextPlayer(ctx);
      return(unitID);
    }
  }

  unitID = kbUnitQueryGetResult(queryID, index);
  xsSetContextPlayer(ctx);
  return(unitID);
}

// ==============================================================================================================
// Returns the index-th unit matching the criteria. Returns a random unit if index is negative.
// Use at the innermost layer of a nested loop.
// ==============================================================================================================
int zpGetUnit2(int unitTypeID = -1,
              int owner = cPlayerRelationAny,
              vector position = cInvalidVector,
              float distance = 30.0,
              int index = -1,
              int state = cUnitStateAlive)
{
  int ctx = xsGetContextPlayer();
  xsSetContextPlayer(0);
  kbLookAtAllUnitsOnMap();

  int numFound = 0;
  int unitID = -1;

  static int queryID = -1;
  if (queryID == -1) {
    queryID = kbUnitQueryCreate("ZP Get Unit 2");
    kbUnitQuerySetIgnoreKnockedOutUnits(queryID, true);
    kbUnitQuerySetAscendingSort(queryID, true);
  }

  if (index <= 0) {
    kbUnitQueryResetResults(queryID);
    kbUnitQuerySetUnitType(queryID, unitTypeID);
    kbUnitQuerySetState(queryID, state);
    kbUnitQuerySetPosition(queryID, position);
    kbUnitQuerySetMaximumDistance(queryID, distance);

    if (kbIsPlayerValid(owner) == true) {
      kbUnitQuerySetPlayerRelation(queryID, -1);
      kbUnitQuerySetPlayerID(queryID, owner, false);
    } else {
      kbUnitQuerySetPlayerID(queryID, -1, false);
      kbUnitQuerySetPlayerRelation(queryID, owner);
    }

    numFound = kbUnitQueryExecute(queryID);

    if (index <= -1) {
      trQuestVarSetFromRand("ZP Get Unit 2 Index", 0, numFound);
      unitID = kbUnitQueryGetResult(queryID, trQuestVarGet("ZP Get Unit 2 Index"));
      xsSetContextPlayer(ctx);
      return(unitID);
    }
  }

  unitID = kbUnitQueryGetResult(queryID, index);
  xsSetContextPlayer(ctx);
  return(unitID);
}

// ==============================================================================================================
// Returns the number of units matching the criteria.
// ==============================================================================================================
int zpGetUnitCount(int unitTypeID = -1,
              int owner = cPlayerRelationAny,
              vector position = cInvalidVector,
              float distance = 30.0,
              int state = cUnitStateAlive)
{
  int ctx = xsGetContextPlayer();
  xsSetContextPlayer(0);
  kbLookAtAllUnitsOnMap();

  int numFound = 0;

  static int queryID = -1;
  if (queryID == -1) {
    queryID = kbUnitQueryCreate("ZP Count Units");
    kbUnitQuerySetIgnoreKnockedOutUnits(queryID, true);
  }

  kbUnitQueryResetResults(queryID);
  kbUnitQuerySetUnitType(queryID, unitTypeID);
  kbUnitQuerySetState(queryID, state);
  kbUnitQuerySetPosition(queryID, position);
  kbUnitQuerySetMaximumDistance(queryID, distance);

  if (kbIsPlayerValid(owner) == true) {
    kbUnitQuerySetPlayerRelation(queryID, -1);
    kbUnitQuerySetPlayerID(queryID, owner, false);
  } else {
    kbUnitQuerySetPlayerID(queryID, -1, false);
    kbUnitQuerySetPlayerRelation(queryID, owner);
  }

  numFound = kbUnitQueryExecute(queryID);
  xsSetContextPlayer(ctx);
  return(numFound);
}

// ==============================================================================================================
// Returns the specified unit's position.
// ==============================================================================================================
vector zpGetUnitPosition(int unitID = -1) {
  int ctx = xsGetContextPlayer();
  xsSetContextPlayer(0);
  kbLookAtAllUnitsOnMap();
  vector position = kbUnitGetPosition(unitID);
  xsSetContextPlayer(ctx);
  return(position);
}

// ==============================================================================================================
// Returns the ID of the specified unit's owner.
// ==============================================================================================================
int zpGetUnitOwner(int unitID = -1) {
   int ctx = xsGetContextPlayer();
   xsSetContextPlayer(0);
   kbLookAtAllUnitsOnMap();
   int owner = kbUnitGetPlayerID(unitID);
   xsSetContextPlayer(ctx);
   return(owner);
}

// ==============================================================================================================
// Tortuga-specific starting techs.
// ==============================================================================================================
rule Starting_Techs active runImmediately highFrequency {
  xsDisableSelf();
  for(playerID = 1; < 9) {
    trTechSetStatus(playerID, cTechDEEnableTradeRouteWater, cTechStatusActive);
  }
}

// ==============================================================================================================
// Human-specific features.
// ==============================================================================================================
rule Human_Features active runImmediately highFrequency {
  int playerID = trCurrentPlayer();
  if (kbIsPlayerHuman(playerID) == false) {
    xsDisableSelf();
    return;
  }
  trTechSetStatus(playerID, cTechzpIsPirateMap, cTechStatusActive);

  // ========================================================================================================
  // Activate Consulate.
  // ========================================================================================================
  if (trTechStatusResearching(playerID, cTechzpPickConsulateTechAvailable)) {
    if (kbGetCivForPlayer(playerID) == cCivChinese) {
      trTechSetStatus(playerID, cTechzpTurnConsulateOnChinese, cTechStatusActive);
    } else if (kbGetCivForPlayer(playerID) == cCivIndians) {
      trTechSetStatus(playerID, cTechzpTurnConsulateOnIndian, cTechStatusActive);
    } else if (kbGetCivForPlayer(playerID) == cCivJapanese) {
      trTechSetStatus(playerID, cTechzpTurnConsulateOnJapanese, cTechStatusActive);
    }
    trTechSetStatus(playerID, cTechzpTurnConsulateOffPirates, cTechStatusUnobtainable);
    if (trCurrentPlayer() == playerID) {
      uiConsulateUIInSelected();
    }
  }
  
  // ========================================================================================================
  // Activate Tortuga.
  // ========================================================================================================
  if (trTechStatusResearching(playerID, cTechzpTheBlackFlag)) {
    trTechSetStatus(playerID, cTechzpTurnConsulateOffPirates, cTechStatusActive);
    trTechSetStatus(playerID, cTechzpTurnConsulateOnChinese, cTechStatusUnobtainable);
    trTechSetStatus(playerID, cTechzpTurnConsulateOnIndian, cTechStatusUnobtainable);
    trTechSetStatus(playerID, cTechzpTurnConsulateOnJapanese, cTechStatusUnobtainable);
    if (kbGetCivForPlayer(playerID) == cCivDEItalians) {
      trTechSetStatus(playerID, cTechzpItalianSettlerBallance, cTechStatusActive);
    }
    if (trTechStatusCheck(playerID, cTechDEHCGondolas, cTechStatusActive) == true) {
      trTechSetStatus(playerID, cTechzpItalianGondolaBallance, cTechStatusActive);
    }
    if (trCurrentPlayer() == playerID) {
      uiConsulateUIInSelected();
    }
  }
}

// ==============================================================================================================
// Update Ports.
// ==============================================================================================================
rule Update_Ports active runImmediately highFrequency {
  if (trPlayerUnitCountSpecific(0, "deTradingGalleon") >= 1) {
    trTechSetStatus(0, cTechzpUpdatePort1, cTechStatusActive);
  }
  if (trPlayerUnitCountSpecific(0, "deTradingFluyt") >= 1) {
    trTechSetStatus(0, cTechzpUpdatePort2, cTechStatusActive);
  }
}

// ==============================================================================================================
// Handle Proxies and Ships.
// ==============================================================================================================
rule Pirates_Features active runImmediately highFrequency {
  const int cActivationCDN = 5000;
  const int cBuildLimitCDN = 500;
  static int lastPrivateer1 = -999999;
  static bool updatePrivateer1BuildLimit = false;
  static int lastPrivateer2 = -999999;
  static bool updatePrivateer2BuildLimit = false;
  static int lastQueenAnne1 = -999999;
  static int lastQueenAnne2 = -999999;
  static int lastNeptune1 = -999999;
  static int lastNeptune2 = -999999;
  static int lastBlackPearl1 = -999999;
  static int lastBlackPearl2 = -999999;
  static bool updateUniqueShipBuildLimit = false;

  int socketID = -1;
  vector socketPos = cInvalidVector;
  int closestTPID = -1;
  int playerID = -1;

  static int flag1 = -1;
  static int flag2 = -1;
  if (flag1 == -1) {
    flag1 = zpGetUnit1(cUnitTypezpPirateWaterSpawnFlag1, cPlayerRelationAny, kbGetMapCenter(), 5000.0, 0);
    flag2 = zpGetUnit1(cUnitTypezpPirateWaterSpawnFlag2, cPlayerRelationAny, kbGetMapCenter(), 5000.0, 0);
  }

  for (i = 0; < zpGetUnitCount(cUnitTypezpSocketPirates, cPlayerRelationAny, kbGetMapCenter(), 5000.0)) {
    socketID = zpGetUnit1(cUnitTypezpSocketPirates, cPlayerRelationAny, kbGetMapCenter(), 5000.0, i);
    socketPos = zpGetUnitPosition(socketID);
    closestTPID = zpGetUnit2(cUnitTypeTradingPost, cPlayerRelationAny, socketPos, 35.0, 0);
    playerID = -1;

    if (closestTPID == -1) {
      // ======================================================================================================
      // This socket has not been claimed.
      // ======================================================================================================
      lastPrivateer1 = -999999;
      updatePrivateer1BuildLimit = false;
      lastPrivateer2 = -999999;
      updatePrivateer2BuildLimit = false;
      lastQueenAnne1 = -999999;
      lastQueenAnne2 = -999999;
      lastNeptune1 = -999999;
      lastNeptune2 = -999999;
      lastBlackPearl1 = -999999;
      lastBlackPearl2 = -999999;
      updateUniqueShipBuildLimit = false;
      for (j = 0; < zpGetUnitCount(cUnitTypezpPirateWaterSpawnFlag1, cPlayerRelationAny, socketPos, 100.0)) {
        trUnitSelectClear();
        trUnitSelectByID(zpGetUnit2(cUnitTypezpPirateWaterSpawnFlag1, cPlayerRelationAny, socketPos, 100.0, i));
        trUnitConvert(0);
        trUnitSelectClear();
      }
      for (j = 0; < zpGetUnitCount(cUnitTypezpPirateWaterSpawnFlag2, cPlayerRelationAny, socketPos, 100.0)) {
        trUnitSelectClear();
        trUnitSelectByID(zpGetUnit2(cUnitTypezpPirateWaterSpawnFlag2, cPlayerRelationAny, socketPos, 100.0, i));
        trUnitConvert(0);
        trUnitSelectClear();
      }
    } else {
      // ======================================================================================================
      // This socket has been claimed.
      // ======================================================================================================
      playerID = zpGetUnitOwner(closestTPID);
      vector flag1Pos = zpGetUnitPosition(flag1);
      vector flag2Pos = zpGetUnitPosition(flag2);

      for (j = 0; < zpGetUnitCount(cUnitTypezpPirateWaterSpawnFlag1, cPlayerRelationAny, socketPos, 100.0)) {
        trUnitSelectClear();
        trUnitSelectByID(zpGetUnit2(cUnitTypezpPirateWaterSpawnFlag1, cPlayerRelationAny, socketPos, 100.0, i));
        trUnitConvert(playerID);
        trUnitSelectClear();
      }
      for (j = 0; < zpGetUnitCount(cUnitTypezpPirateWaterSpawnFlag2, cPlayerRelationAny, socketPos, 100.0)) {
        trUnitSelectClear();
        trUnitSelectByID(zpGetUnit2(cUnitTypezpPirateWaterSpawnFlag2, cPlayerRelationAny, socketPos, 100.0, i));
        trUnitConvert(playerID);
        trUnitSelectClear();
      }
      
      if (xsVectorLength(socketPos - flag1Pos) < xsVectorLength(socketPos - flag2Pos)) {
        // ====================================================================================================
        // PRIVATEER 1
        // ====================================================================================================
        if (trTimeMS() - lastPrivateer1 >= cBuildLimitCDN && updatePrivateer1BuildLimit == true) {
          updatePrivateer1BuildLimit = false;
          trTechSetStatus(playerID, cTechzpPrivateerBuildLimitReduceShadow, cTechStatusActive);
          trTechSetStatus(playerID, cTechzpTrainPrivateer1, cTechStatusUnobtainable);
        }
        if (trTimeMS() - lastPrivateer1 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpPrivateerProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainPrivateer1, cTechStatusActive);
            lastPrivateer1 = trTimeMS();
            updatePrivateer1BuildLimit = true;
          }
        }
        // ====================================================================================================
        // UNIQUE SHIP 1
        // ====================================================================================================
        if (updateUniqueShipBuildLimit) {
          updateUniqueShipBuildLimit = false;
          if ((trTimeMS() - lastQueenAnne1 >= cBuildLimitCDN) 
              || (trTimeMS() - lastQueenAnne2 >= cBuildLimitCDN)
              || (trTimeMS() - lastNeptune1 >= cBuildLimitCDN)
              || (trTimeMS() - lastNeptune2 >= cBuildLimitCDN)
              || (trTimeMS() - lastBlackPearl1 >= cBuildLimitCDN)
              || (trTimeMS() - lastBlackPearl2 >= cBuildLimitCDN))
          {
            trTechSetStatus(playerID, cTechzpReducePirateShipsBuildLimit, cTechStatusActive);
          }
        }
        // ====================================================================================================
        // QUEEN ANNE 1
        // ====================================================================================================
        if (trTimeMS() - lastQueenAnne1 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpSPCQueenAnneProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainQueenAnne1, cTechStatusActive);
            lastQueenAnne1 = trTimeMS();
            updateUniqueShipBuildLimit = true;
          }
        }
        // ====================================================================================================
        // NEPTUNE 1
        // ====================================================================================================
        if (trTimeMS() - lastNeptune1 >= cActivationCDN) {
          lastNeptune1 = trTimeMS();
          if (zpGetUnitCount(cUnitTypezpSPCNeptuneGalleyProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainNeptune1, cTechStatusActive);
            updateUniqueShipBuildLimit = true;
          }
        }
        // ====================================================================================================
        // BLACK PEARL 1
        // ====================================================================================================
        if (trTimeMS() - lastBlackPearl1 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpSPCBlackPearlProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainBlackPearl1, cTechStatusActive);
            lastBlackPearl1 = trTimeMS();
            updateUniqueShipBuildLimit = true;
          }
        }
      } else {
        // ====================================================================================================
        // PRIVATEER 2
        // ====================================================================================================
        if (trTimeMS() - lastPrivateer2 >= cBuildLimitCDN && updatePrivateer2BuildLimit == true) {
          updatePrivateer2BuildLimit = false;
          trTechSetStatus(playerID, cTechzpPrivateerBuildLimitReduceShadow, cTechStatusActive);
          trTechSetStatus(playerID, cTechzpTrainPrivateer2, cTechStatusUnobtainable);
        }
        if (trTimeMS() - lastPrivateer2 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpPrivateerProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainPrivateer2, cTechStatusActive);
            lastPrivateer2 = trTimeMS();
            updatePrivateer2BuildLimit = true;
          }
        }
        // ====================================================================================================
        // QUEEN ANNE 2
        // ====================================================================================================
        if (trTimeMS() - lastQueenAnne2 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpSPCQueenAnneProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainQueenAnne2, cTechStatusActive);
            lastQueenAnne2 = trTimeMS();
            updateUniqueShipBuildLimit = true;
          }
        }
        // ====================================================================================================
        // NEPTUNE 2
        // ====================================================================================================
        if (trTimeMS() - lastNeptune2 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpSPCNeptuneGalleyProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainNeptune2, cTechStatusActive);
            lastNeptune2 = trTimeMS();
            updateUniqueShipBuildLimit = true;
          }
        }
        // ====================================================================================================
        // BLACK PEARL 2
        // ====================================================================================================
        if (trTimeMS() - lastBlackPearl2 >= cActivationCDN) {
          if (zpGetUnitCount(cUnitTypezpSPCBlackPearlProxy, playerID, socketPos, 35.0) >= 1) {
            trTechSetStatus(playerID, cTechzpTrainBlackPearl2, cTechStatusActive);
            lastBlackPearl2 = trTimeMS();
            updateUniqueShipBuildLimit = true;
          }
        }
      }
    }
  }
}
```
