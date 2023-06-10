rule I_Update_Ports
active
runImmediately
minInterval 0
{
    if (trPlayerUnitCountSpecific(0, "zpChinaTreasureShip") >= 1)
    {
        trSetUnitIdleProcessing(true);
        
        int playerID = 1;
        while(kbIsPlayerValid(playerID))
        {
            trTechSetStatus(playerID, cTechzpGaiaKillTreasureship, cTechStatusActive);
            playerID++;
        }

        xsDisableSelf();
    }
}

rule Activate_Consulate
active
runImmediately
minInterval 0
{
    int playerID = 1;
    while(kbIsPlayerValid(playerID))
    {
        if (kbIsPlayerHuman(playerID) == false)
        {
            playerID++;
            continue;
        }
        
        if (trTechStatusCheck(playerID, cTechzpIsPirateMap, cTechStatusActive) == false)
        {
            trTechSetStatus(playerID, cTechzpIsPirateMap, cTechStatusActive);
        }

        if (trTechStatusResearching(playerID, cTechzpPickConsulateTechAvailable))
        {
            if (kbGetCivForPlayer(playerID) == cCivChinese
                || kbGetCivForPlayer(playerID) == cCivJapanese
                || kbGetCivForPlayer(playerID) == cCivIndians)
            {
                trTechSetStatus(playerID, cTechzpTurnConsulateOffWokou, cTechStatusUnobtainable);
                trTechSetStatus(playerID, cTechzpTurnConsulateOffMaltese, cTechStatusUnobtainable);

                if (kbGetCivForPlayer(playerID) == cCivChinese)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnChinese, cTechStatusActive);
                }
                else if (kbGetCivForPlayer(playerID) == cCivJapanese)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnJapanese, cTechStatusActive);
                }
                else if (kbGetCivForPlayer(playerID) == cCivIndians)
                {
                    trTechSetStatus(playerID, cTechzpTurnConsulateOnIndian, cTechStatusActive);
                }

                if (trCurrentPlayer() == playerID)
                {
                    uiConsulateUIInSelected();
                }
            }
        }

        if (trTechStatusResearching(playerID, cTechzpBlackmailing))
        {
            trTechSetStatus(playerID, cTechzpTurnConsulateOffWokou, cTechStatusActive);
            trTechSetStatus(playerID, cTechzpTurnConsulateOnJapanese, cTechStatusUnobtainable);
            trTechSetStatus(playerID, cTechzpTurnConsulateOnChinese, cTechStatusUnobtainable);
            trTechSetStatus(playerID, cTechzpTurnConsulateOnIndian, cTechStatusUnobtainable);
            trTechSetStatus(playerID, cTechzpTurnConsulateOffMaltese, cTechStatusUnobtainable);

            xsEnableRule("Italian_Vilager_Balance");
            xsEnableRule("Italian_Gondola_Balance");

            if (trCurrentPlayer() == playerID)
            {
                uiConsulateUIInSelected();
            }
        }

        playerID++;
    }
}

rule Italian_Vilager_Balance
inactive
runImmediately
minInterval 0
{
    int playerID = 1;
    while(kbIsPlayerValid(playerID))
    {
        if (kbGetCivForPlayer(playerID) == cCivDEItalians)
        {
            trTechSetStatus(playerID, cTechzpItalianSettlerBallance, cTechStatusActive);
        }

        playerID++;
    }
}

rule Italian_Gondola_Balance
inactive
runImmediately
minInterval 0
{
    int playerID = 1;
    while(kbIsPlayerValid(playerID))
    {
        if (trTechStatusCheck(playerID, cTechDEHCGondolas, cTechStatusActive))
        {
            trTechSetStatus(playerID, cTechzpItalianGondolaBallance, cTechStatusActive);
        }

        playerID++;
    }
}
