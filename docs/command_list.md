Find sth. Commands
uiFindIdleType([string typeName], [bool shiftSelectsAll]) : finds the next idle unit of the given type in the arbitrary order of unit ID, so that it can be called repeatedly to cycle. bool type variables = true or false
uiFindIdleType2([string typeName], [bool shiftSelectsAll]) : finds the next idle unit of the given type in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindAllOfSelectedType() : finds all units of the same type as the selected unit.
uiFindAllOfType([string typeName]) : finds all units of the same type.
uiFindAllOfTwoTypes([string typeName1], [string typeName2]) : finds all units belonging to any of the two provided types.
uiFindAllOfTypeIdle([string typeName]) : finds all idle units of the same type.
uiFindAllOfTypeIdle2([string typeName]) : finds all idle units of the same type.
uiFindTownBellTC() : finds the next town center that has the town bell active, so that it can be called repeatedly to cycle.
uiFindType([string typeName]) : finds the next unit(idle or not) of the given type in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindTwoTypes([string typeName1], [string typeName2]) : finds the next unit of the given two types in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindAnyOfTypes("[string typeName1, typeName2, typeName3, ...]") : finds the next unit of any of the given types(separated by commas or spaces) in the arbitrary order of unit ID, so that it can be called repeatedly to cycle
uiFindNativeSite : finds the next Trading Post over a Native Site in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindTradeRouteSite : finds the next Trading Post over a Trade Route Site in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindNativeSiteSubCiv : finds the next Trading Post over a Native Site belonging to the given subCiv in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindFattenedHerdable : finds the next fattened herdable in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindAllFattenedHerdables : finds all fattened herdables.
uiFindResourceGatherers ([string resourcetypeName]) : finds the next resource gatherer unit of the given resource type in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
[string resourcetypeName] = “Food”, “Wood”, “Gold”, “XP”,“Trade”, “Influence” or “Ships”
uiFindGatherersNotGathering () : finds the gatherer unit that’s not gathering in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiFindDancers () : finds the next native settler dancing at the firepit/CommunityPlaza in the arbitrary order of unit ID, so that it can be called repeatedly to cycle.
uiLookAtSelection : moves the camera to see the first selected unit.
uiCreateNumberGroup([integer GroupID]) : creates a number group with the currently selected units.
[GroupID] = 0~9
uiClearNumberGroup([integer GroupID]) : erases the given number group.
uiSelectNumberGroup([integer GroupID]) : selects the units in the given number group.
uiAddSelectNumberGroup([integer GroupID]) : adds the units in the given number group to current selection.
uiRemoveFromAnyNumberGroup : removes current selection from any army.
uiLookAtNumberGroup([integer GroupID]) : moves the camera to see the given number group.
[typeName] can input ProtoName or <unittype>, I will list some of the <unittype> related to unit counters, the rest can be found from protoy.xml (need to be extracted from the data.bar using the Resource Manager).
LogicalTypeLandEconomy : Land Villager
AbstractPet
Hero
Mercenary
MercType2 : Spy-like Unit that effective against mercenaries and heroes.
Guardian : Treasure guardians
AbstractInfantry
AbstractCavalry
AbstractLightInfantry : Shock Infantry “Two-legged cavalry”
AbstractArtillery
AbstractHeavyInfantry
AbstractSkirmisher : Light Infantry
AbstractCounterSkirmisher : Light Infantry that excels at countering other Light Infantry.
AbstractHeavyCavalry
AbstractCoyoteMan : Hand Shock Infantry “Two-legged Heavy Cavalry”
AbstractLightCavalry : Light Ranged Cavalry
AbstractRangedShockInfantry : Ranged Shock Infantry “Two-legged Light Ranged Cavalry”
AbstractFishingBoat
AbstractWarShip

Do sth. Commands
doAbilityInType([string protoPowerName], [string ProtoName]) : use ability in proto unit type if the player has one.
doAbilityInSelected([string protoPowerName]) : use ability in current unit selection.
doCommandInSelected([string commandName]) : use command in current unit selection.
researchTechInSelected([string techName]) : research a tech in current unit selection.
commandResearchInSelected([string commandName]) : researches a protounit command associated with a tech in current unit selection.
commandTransformInSelected : researches the transform command set in protoUnit data for each unit in current unit selection.
trainInSelected([string ProtoName], [integer traincount]) : tries to train the selected unit type in any valid selected unit.
tis([string ProtoName], [integer traincount]) : just like train in selected, but more abbreviated.
cancelAllQueuedInSelected() : cancel all queued units and researches in all valid selected units.
sendFakeCardInSelected([string techName]) : send a fake card through current unit selection.
homeCityTrain2([integer playerID], [integer cardIndex], [bool extendedDeck]) : Sends the given HC card in the home city without open HC panel, playerID = -1 cardIndex = 0~39, if extendedDeck = true, send federal card instead.
uiPoliticianUIInSelected([string techName]) : research an age-up/wonder tech in current unit selection.(Only the panel is called out, still need to manually select)
uiConsulateUIInSelected() : research a pick consulate alliance tech in current unit selection.(Only the panel is called out, still need to manually select)
uiDeleteSelectedUnit : deletes selected unit.
uiDeleteAllSelectedUnit : deletes all selected unit without confirmation.
activateCommandPanel([integer rowNumber], [integer columnNumber]) : Presses a button on the command panel at the specified location with 0,0 being top left.
shiftActivateCommandPanel([integer rowNumber], [integer columnNumber]) : Shift-Presses a button on the command panel at the specified location with 0,0 being top left.
activateCommandButton([integer columnNumber]) : Presses a button on the command panel command button row at the specified index.
[ProtoName] can input ProtoName found from protoy.xml
[protoPowerName] can input Ability Name found from abilities.xml
[commandName] can input protounitcommand Name found from protounitcommands.xml
[techName] can input ProtoName found from techtreey.xml
All the above in-program names can be found by searching the in-game names in the stringtabley.xml to obtain the string _locid and then searching for <displaynameid>.

Some examples of map commands
map("numpad4", "game", "uiFindAllOfTypeIdle(\"WallConnector\")uiDeleteAllSelectedUnits")
The famous easy pillarless-walling hotkeys
map("numpad4", "game", "uiFindAllOfType(\"AbstractInfantry\") uiCreateNumberGroup(0) uiFindAllOfType(\"Hero\")uiRemoveFromAnyNumberGroup uiSelectNumberGroup(0)")
Finds all infantry and culls heroes from them.
map("numpad4", "game", "doAbilityInType(\"ypPowerSmokeBomb\", \"ypmonkjapanese\") doAbilityInType(\"ypPowerSmokeBomb\", \"ypmonkjapanese2\")")
Let two Japanese monks throw smoke bombs simultaneously.