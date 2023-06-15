// ============================================================================
// The following code will work for the zptortuga map only.
// We will use it as a starting point for the ongoing trigger rework.
// ============================================================================

// ============================================================================
// Globals
// ============================================================================

const float cConversionRadius = 100.0;
const float cSocketRadius = 35.0;

const string cFlag1 = "zpPirateWaterSpawnFlag1";
const string cFlag2 = "zpPirateWaterSpawnFlag2";

const int cSocket1ID = 5;
const int cSocket2ID = 56;


// ============================================================================
// Functions
// ============================================================================

int getSocketOwner(int socketID = -1)
{
    int socketOwner = 0;
    for (playerID = 0; < 9)
    {
        if (trCountUnitsInArea("" + socketID, playerID, "TradingPost", cSocketRadius) >= 1)
        {
            socketOwner = playerID;
            break;
        }
    }

    return(socketOwner);
}


// ============================================================================
// Rules
// ============================================================================

rule StartingTechs
active
runImmediately
highFrequency
{
    xsDisableSelf();
    for (playerID = 1; < 9)
    {
        if (kbIsPlayerValid(playerID) == false)
        {
            break;
        }
        trTechSetStatus(playerID, cTechDEEnableTradeRouteWater, cTechStatusActive);
    }
}

rule UpdatePortsI
active
runImmediately
highFrequency
{
    if (trPlayerUnitCountSpecific(0, "deTradingGalleon") >= 1)
    {
        trTechSetStatus(0, cTechzpUpdatePort1, cTechStatusActive);
        xsDisableSelf();
    }
}

rule UpdatePortsII
active
runImmediately
highFrequency
{
    if (trPlayerUnitCountSpecific(0, "deTradingFluyt") >= 1)
    {
        trTechSetStatus(0, cTechzpUpdatePort2, cTechStatusActive);
        xsDisableSelf();
    }
}

rule TurnOnPirates1
active
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (socketOwner >= 1)
    {
        trUnitSelectClear();
        trUnitSelectByID(cSocket1ID);
        trConvertUnitsInArea(0, socketOwner, cFlag1, cConversionRadius);

        xsEnableRule("TurnOffPirates1");
        xsEnableRule("TrainPrivateer1ON");
        xsEnableRule("TrainQueenAnne1ON");
        xsEnableRule("TrainBlackPearl1ON");
        xsEnableRule("TrainNeptuneGalley1ON");
        xsDisableSelf();
    }
}

rule TurnOffPirates1
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (socketOwner <= 0)
    {
        trUnitSelectClear();
        trUnitSelectByID(cSocket1ID);
        for (playerID = 1; < 9)
        {
            if (kbIsPlayerValid(playerID) == false)
            {
                break;
            }

            trConvertUnitsInArea(playerID, 0, cFlag1, cConversionRadius);

            xsEnableRule("TurnOnPirates1");
            xsDisableRule("TrainPrivateer1ON");
            xsDisableRule("TrainQueenAnne1ON");
            xsDisableRule("TrainBlackPearl1ON");
            xsDisableRule("TrainNeptuneGalley1ON");
            xsDisableSelf();
        }
    }
}

rule TrainPrivateer1ON
inactive
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trCountUnitsInArea("" + cSocket1ID, socketOwner, "zpPrivateerProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainPrivateer1, cTechStatusActive);
        xsEnableRule("TrainPrivateer1OFF");
        xsEnableRule("TrainPrivateer1TIME");
        xsDisableSelf();
    }
}

rule TrainPrivateer1OFF
inactive
highFrequency
runImmediately
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainPrivateer1ON");
        xsDisableSelf();
    }
}

rule TrainPrivateer1TIME
inactive
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trTime() - cActivationTime >= 2)
    {
        trTechSetStatus(socketOwner, cTechzpPrivateerBuildLimitReduceShadow, cTechStatusActive);
        trTechSetStatus(socketOwner, cTechzpTrainPrivateer1, cTechStatusUnobtainable);
        xsDisableSelf();
    }
}

rule TrainQueenAnne1ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trCountUnitsInArea("" + cSocket1ID, socketOwner, "zpSPCQueenAnneProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainQueenAnne1, cTechStatusActive);
        xsEnableRule("TrainUniqueShip1TIME");
        xsEnableRule("TrainQueenAnne1OFF");
        xsDisableSelf();
    }
}

rule TrainQueenAnne1OFF
inactive
runImmediately
highFrequency
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainQueenAnne1ON");
        xsDisableSelf();
    }
}

rule TrainUniqueShip1TIME
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trTime() - cActivationTime >= 2)
    {
        trTechSetStatus(socketOwner, cTechzpReducePirateShipsBuildLimit, cTechStatusActive);
        xsDisableSelf();
    }
}

rule TrainBlackPearl1ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trCountUnitsInArea("" + cSocket1ID, socketOwner, "zpSPCBlackPearlProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainBlackPearl1, cTechStatusActive);
        xsEnableRule("TrainUniqueShip1TIME");
        xsEnableRule("TrainBlackPearl1OFF");
        xsDisableSelf();
    }
}

rule TrainBlackPearl1OFF
inactive
runImmediately
highFrequency
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainBlackPearl1ON");
        xsDisableSelf();
    }
}

rule TrainNeptuneGalley1ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket1ID);
    if (trCountUnitsInArea("" + cSocket1ID, socketOwner, "zpSPCNeptuneGalleyProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainNeptune1, cTechStatusActive);
        xsEnableRule("TrainUniqueShip1TIME");
        xsEnableRule("TrainNeptuneGalley1OFF");
        xsDisableSelf();
    }
}

rule TrainNeptuneGalley1OFF
inactive
runImmediately
highFrequency
{
    if (trTimeMS() - cActivationTime * 1000 >= 5000)
    {
        xsEnableRule("TrainNeptuneGalley1ON");
        xsDisableSelf();
    }
}

rule TurnOnPirates2
active
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (socketOwner >= 1)
    {
        trUnitSelectClear();
        trUnitSelectByID(cSocket2ID);
        trConvertUnitsInArea(0, socketOwner, cFlag2, cConversionRadius);

        xsEnableRule("TurnOffPirates2");
        xsEnableRule("TrainPrivateer2ON");
        xsEnableRule("TrainQueenAnne2ON");
        xsEnableRule("TrainBlackPearl2ON");
        xsEnableRule("TrainNeptuneGalley2ON");
        xsDisableSelf();
    }
}

rule TurnOffPirates2
inactive
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (socketOwner <= 0)
    {
        trUnitSelectClear();
        trUnitSelectByID(cSocket2ID);
        for (playerID = 1; < 9)
        {
            if (kbIsPlayerValid(playerID) == false)
            {
                break;
            }

            trConvertUnitsInArea(playerID, 0, cFlag2, cConversionRadius);

            xsEnableRule("TurnOnPirates2");
            xsDisableRule("TrainPrivateer2ON");
            xsDisableRule("TrainQueenAnne2ON");
            xsDisableRule("TrainBlackPearl2ON");
            xsDisableRule("TrainNeptuneGalley2ON");
            xsDisableSelf();
        }
    }
}

rule TrainPrivateer2ON
inactive
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trCountUnitsInArea("" + cSocket2ID, socketOwner, "zpPrivateerProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainPrivateer2, cTechStatusActive);
        xsEnableRule("TrainPrivateer2OFF");
        xsEnableRule("TrainPrivateer2TIME");
        xsDisableSelf();
    }
}

rule TrainPrivateer2OFF
inactive
highFrequency
runImmediately
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainPrivateer2ON");
        xsDisableSelf();
    }
}

rule TrainPrivateer2TIME
inactive
highFrequency
runImmediately
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trTime() - cActivationTime >= 2)
    {
        trTechSetStatus(socketOwner, cTechzpPrivateerBuildLimitReduceShadow, cTechStatusActive);
        trTechSetStatus(socketOwner, cTechzpTrainPrivateer2, cTechStatusUnobtainable);
        xsDisableSelf();
    }
}

rule TrainQueenAnne2ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trCountUnitsInArea("" + cSocket2ID, socketOwner, "zpSPCQueenAnneProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainQueenAnne2, cTechStatusActive);
        xsEnableRule("TrainUniqueShip2TIME");
        xsEnableRule("TrainQueenAnne2OFF");
        xsDisableSelf();
    }
}

rule TrainQueenAnne2OFF
inactive
runImmediately
highFrequency
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainQueenAnne2ON");
        xsDisableSelf();
    }
}

rule TrainUniqueShip2TIME
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trTime() - cActivationTime >= 2)
    {
        trTechSetStatus(socketOwner, cTechzpReducePirateShipsBuildLimit, cTechStatusActive);
        xsDisableSelf();
    }
}

rule TrainBlackPearl2ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trCountUnitsInArea("" + cSocket2ID, socketOwner, "zpSPCBlackPearlProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainBlackPearl2, cTechStatusActive);
        xsEnableRule("TrainUniqueShip2TIME");
        xsEnableRule("TrainBlackPearl2OFF");
        xsDisableSelf();
    }
}

rule TrainBlackPearl2OFF
inactive
runImmediately
highFrequency
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainBlackPearl2ON");
        xsDisableSelf();
    }
}

rule TrainNeptuneGalley2ON
inactive
runImmediately
highFrequency
{
    int socketOwner = getSocketOwner(cSocket2ID);
    if (trCountUnitsInArea("" + cSocket2ID, socketOwner, "zpSPCNeptuneGalleyProxy", cSocketRadius) >= 1)
    {
        trTechSetStatus(socketOwner, cTechzpTrainNeptune2, cTechStatusActive);
        xsEnableRule("TrainUniqueShip2TIME");
        xsEnableRule("TrainNeptuneGalley2OFF");
        xsDisableSelf();
    }
}

rule TrainNeptuneGalley2OFF
inactive
runImmediately
highFrequency
{
    if (trTime() - cActivationTime >= 5)
    {
        xsEnableRule("TrainNeptuneGalley2ON");
        xsDisableSelf();
    }
}

rule ActivateConsulates
active
runImmediately
highFrequency
{
    for (playerID = 1; < 9)
    {
        if (kbIsPlayerValid(playerID) == false)
        {
            break;
        }

        if (kbIsPlayerHuman(playerID) == false)
        {
            continue;
        }

        if (trTechStatusCheck(playerID, cTechzpIsPirateMap, cTechStatusActive) == false)
        {
            trTechSetStatus(playerID, cTechzpIsPirateMap, cTechStatusActive);
        }

        if (kbGetCivForPlayer(playerID) == cCivChinese
            || kbGetCivForPlayer(playerID) == cCivIndians
            || kbGetCivForPlayer(playerID) == cCivJapanese)
        {
            if (trTechStatusResearching(playerID, cTechzpPickConsulateTechAvailable) == true)
            {
                if (kbGetCivForPlayer(playerID) == cCivChinese)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnChinese, cTechStatusActive);
                }
                else if (kbGetCivForPlayer(playerID) == cCivIndians)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnIndian, cTechStatusActive);
                }
                else if (kbGetCivForPlayer(playerID) == cCivJapanese)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnJapanese, cTechStatusActive);
                }

                if (trCurrentPlayer() == playerID)
                {
                    uiConsulateUIInSelected();
                }
            }
        }

        if (trTechStatusResearching(playerID, cTechzpTheBlackFlag) == true)
        {
            trTechSetStatus(playerID, cTechzpTurnConsulateOffPirates, cTechStatusActive);

            if (trCurrentPlayer() == playerID)
            {
                uiConsulateUIInSelected();
            }

            if (kbGetCivForPlayer(playerID) == cCivDEItalians
                && trTechStatusCheck(playerID, cTechzpItalianSettlerBallance, cTechStatusActive) == false)
            {
                trTechSetStatus(playerID, cTechzpItalianSettlerBallance, cTechStatusActive);
            }

            if (trTechStatusCheck(playerID, cTechDEHCGondolas, cTechStatusActive) == true
                && trTechStatusCheck(playerID, cTechzpItalianGondolaBallance, cTechStatusActive) == false)
            {
                trTechSetStatus(playerID, cTechzpItalianGondolaBallance, cTechStatusActive);
            }
        }
    }
}
