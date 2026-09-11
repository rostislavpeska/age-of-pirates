# AoE3DE Comprehensive Data Guide ProtoUnit and ProtoAction Data

**ProtoUnits (protoy.xml)**

## Attributes

- **Legacy**
  - **DBID:** Sets the DBID for the ProtoUnit. Used for Post-Game and MP stat collection. It's a good practice to assign a unique DBID for every new protoUnit, even though it's not required for proper game functionality.
  - **Icon:** WPF path for unit icon, relative to _Data\\wpfg_.
  - **PortraitIcon:** WPF path for unit portrait, relative to _Data\\wpfg_.
  - **MinimapIcon:** Path to minimap icon texture, relative to the _Art_ folder.
  - **MinimapColor:** ProtoUnit minimap colour. Takes RGB colour parameters, which expect floating point values in the \[0.0, 1.0\] interval.

&lt;MinimapColor red='1.0000' blue='1.0000' green='1.0000'&gt;&lt;/MinimapColor&gt;

- - **MinimapShape:** If set to 1, the minimap indicator becomes smaller if protoUnit is under the fog of war. Unused, but still functional. Original intended purpose unknown.
    - **MinimapSize:** Size of minimap indicator. Defaults to 2.0, if not set.
    - **AnimFile:** Path to protoUnit animfile, relative to the _Art_ folder.
    - **PlacementFile:** Path to protoUnit placementRules file, relative to Data\\placement rules.
    - **DisplayNameID:** String ID for protoUnit displayed name.
    - **EditorNameID:** String ID for protoUnit displayed name in Scenario Editor listing.
    - **RolloverTextID:** String ID for protoUnit long rollover.
    - **ShortRolloverTextID:** String ID for protoUnit short rollover.
    - **WorldTooltipStringID:** String ID to be used for the persistently displayed world tooltip. Appears to be intended to be somehow used in the Grand Conquest game mode or in some sort of tutorial mode, different from the one in the retail release. Unused, but still functional. Requires _WorldToolTip_ protoUnitFlag to be set for proper functionality.
    - **ClassNameID:** AoM Leftover. String ID for protoUnit class to be displayed in long rollover. Unused, but still functional.
    - **GoodAgainstStringID:** AoM Leftover. String ID for protoUnit "Good Against" text to be displayed in long rollover. Unused, but still functional.
    - **BadAgainstStringID:** AoM Leftover. String ID for protoUnit "Bad Against" text to be displayed in long rollover. Unused, but still functional.
    - **MaxHitpoints:** ProtoUnit maximum amount of hitpoints
    - **InitialHitpoints:** ProtoUnit initial amount of hitpoints.
    - **LOS:** ProtoUnit Line of Sight.
    - **MaxVelocity:** ProtoUnit base speed value.
    - **MaxRunVelocity:** Appears to be protoUnit maximum speed for running,either when triggered through trigger effects or through extra speed gained through performing attack

actions with the _SpeedBoost_ flag set. Used in calculations that define when Jog and Run anims should be used by the unit.

- - **MovementType:** Defines which terrains the unit can move through.
    - **TurnRate:** ProtoUnit turning/rotation rate.
    - **~~​ BatchTrainNumber:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **UnitAIType:** ProtoUnit UnitAI type. Used for auto-attack behaviour, target selection, and other features related to overall unitAI handling.
    - **InitialUnitAIStance:** AoM leftover. Defines the initial stance for the UnitAI (_Aggressive_,

_Defensive_, _Passive_ or _StandGround_). Likely overridden by SquadMode data.

- - **PopulationCount:** ProtoUnit population count.
    - **SubCiv:** Restricts the training of this protoUnit to being allied to a particular minor civilization, or to a Native Settlement belonging to the specified minor civilization. Binds the unit build limit to a multiple of the alliance level towards the defined minor civilization and the number of Trading Posts built over Native Settlements belonging to it.
    - **TrainPoints:** Total amount of time in seconds required to train protoUnit.
    - **Cost:** ProtoUnit cost. Takes one parameter, _resourcetype_, which sets the resource type for each entry.
    - **CostEscalation:** Multiplicative factor to be applied over protoUnit's cost for every instance of the same protoUnit queued or in the map. Unused, but functional.
    - **ScoreValue:** ProtoUnit contribution to player score when trained or built. If set, overrides default value calculated from the cost.
    - **InitialResource:** Initial amount of resources carried by the unit. Takes one parameter,

_resourcetype_, which sets the resource type

&lt;InitialResource resourcetype='Food'&gt;50.0000&lt;/InitialResource&gt;

- - **~~​ InitialXP:~~** ~~Unused and deprecated.~~
    - **CarryCapacity:** Maximum amount of resources that can be carried by the unit. Takes one parameter, _resourcetype_, which sets the resource type. For units that don't carry resources, sets the resource types it's allowed to gather from when performing a _Hunting_ action.

&lt;CarryCapacity resourcetype='Food'&gt;500.0000&lt;/CarryCapacity&gt;

- - **GathererLimit:** Maximum number of units that can gather from this unit at a given time.
    - **BuilderLimit:** Maximum number of units that can build this unit when at foundation state at a given time.
    - **ContainedSpeedBonus:** Unused in AoE3 Legacy. In AoE3DE, defines how much each garrisoned unit contributes to its speed. Applied linearly.
    - **ObstructionRadiusX:** ProtoUnit obstruction radius in the X axis.
    - **ObstructionRadiusZ:** ProtoUnit obstruction radius in the Z axis.
    - **ObstructionRadius:** ProtoUnit obstruction radius in both X and Z axes. Unused, but functional.
    - **FlattenTerrainExpand:** Appears to define the additional radius by which the protoUnit causes the terrain to be flattened, when placed as a building.
    - **AllowedHeightVariance:** Maximum elevation height variance allowed over the area where the protoUnit is to be placed.
    - **WanderDistance:** Wandering distance value used by huntable herds.
    - **BuildPoints:** Total amount of time in seconds required to build protoUnit, when working at a 1.0 Work Rate over the Foundation.
    - **BuildingWorkRate:** Work rate value used by training, researching and maintaining (auto-spawn) actions.
    - **~~​ IdleTimeout:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **~~​ BoredTimeout:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **RechargeTime:** Recharge time used by Charged Actions/Abilities.
    - **~~​ CorpseDecalTime:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **CorpseDecayDelay:** Delay time in seconds before decay 'sinking' happens after unit death.
    - **Lifespan:** ProtoUnit lifespan.
    - **Decay:** Defines the delay time and the duration of decaying fadeout. Takes two parameters, _decay_ and _duration_.

&lt;Decay delay='0.0000' duration='2.0000'&gt;&lt;/Decay&gt;

- - **PopulationCapAddition:** Amount of population capacity to be added to player's population once protoUnit is fully built.
    - **DeadReplacement:** ProtoUnit to be placed upon destruction.
    - **BuildReplacement:** ProtoUnit that replaces originally placed unit once it's fully built.
    - **~~​ Footprint:~~** ~~Unused and deprecated.~~
    - **BuildLimit:** ProtoUnit build limit.
    - **MaxContained:** Maximum number of garrisoned units allowed.
    - **ProjectileProtoUnit:** Projectile unit to be used for ranged attack actions that do not explicitly define a projectile unit. Unused by common ranged units, but functional.
    - **ResourceDecay:** Resource decay rate for dead herdables and huntables.
    - **SocketUnitType:** Unit type where the protoUnit can be placed over, serving as a socket for the unit.
    - **SocketOffsetX:** Offset for socket placement in the X axis.
    - **SocketOffsetZ:** Offset for socket placement in the Z axis.
    - **AutoAttackRange:** ProtoUnit auto-attack range.
    - **ResourceSubType:** ProtoUnit resource subtype. Used for defining the gather cursor and by resource tasking code.
    - **~~​ CreationFadeTime:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **ProjectileSpinPeriod:** Spinning period for projectile protoUnits. Causes projectiles to spin at the set period when shot. Unused, but functional.
    - **HeightBob:** AoM leftover. Causes the altitude of flying units to slightly oscillate by periods of time while idle. Takes two parameters, _period_ and _magnitude_. Unused, but likely functional

&lt;HeightBob period="6.0000" magnitude="2.0000"&gt;&lt;/HeightBob&gt;

- - **PartisanType:** Partisan protounit to be spawned upon building's destruction, if partisans are enabled in the current civilization. Unused, but functional.
    - **PartisanCount:** Amount of partisan units to be spawned, if **PartisanType** is properly set and partisans are enabled in the current civilization. Unused, but functional.
    - **Bounty:** Amount of XP to be granted to enemy players upon the unit's destruction. From _Knights of The Mediterranean_ AoE3DE DLC onwards, it can take a _resourcetype_ attribute, allowing the assignment of rewards of different resources, besides XP.
    - **BuildBounty:** Amount of XP to be granted upon unit training or building full construction.

From _The African Royals_ AoE3DE DLC onwards, it can take a _resourcetype_ attribute, allowing the assignment of build rewards of different resources, besides XP.

&lt;BuildBounty&gt;7.0000&lt;/BuildBounty&gt;

&lt;BuildBounty resourcetype='Wood'&gt;7.0000&lt;/BuildBounty&gt;

- - **SoundVariant:** AoM leftover. Unused, liikely deprecated or rendered obsolete.
    - **BallisticSplashProto:** AoM leftover. ProtoUnit for SFX to be rendered upon projectile colliding on water. Unused, and, most likely, rendered obsolete by impact effect data.
    - **~~​ BallisticBounceProto:~~** ~~Unused and deprecated.~~
    - **BallisticImpactProto:** AoM leftover. ProtoUnit for SFX to be rendered upon projectile colliding against structures. Unused, and, most likely, rendered obsolete by impact effect data.
    - **~~​ GrantsPower:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **~~​ GrantsPowerDuration:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **ImpactType:** ProtoUnit impact type. Used for impact effects rendering.
    - **PhysicsInfo:** Path to protoUnit physics info files, relative to Data\\physics.
    - **SelectionPriority:** ProtoUnit selection priority value.
    - **AllowedAge:** Minimum age required to build or train the unit.
    - **Armor:** ProtoUnit Armor. Takes two parameters, _type_ and _value_. From _The African Royals_ AoE3DE onwards, protoUnits can have multiple functional **Armor** entries pointing to different damage types.

&lt;Armor type='Ranged' value='0.7500'&gt;&lt;/Armor&gt;

- - **~~​ SlotCount:~~** ~~Attribute intended to be used by the AirCraft system. Unused and not~~ ~~functional in AoE3.~~
    - **AutoGatherType:** Resource type for auto resource tasking. Unused, but likely functional.
    - **PlacementBuffer:** Additional avoidance radius to be used at building placement.

Unused, but likely functional.

- - **AnimStateMachine:** Path to protoUnit animation state machine file, relative to

_Data\\animstatemachine_

- - **~~​ ButtonPos:~~** ~~AoM leftover. Unused and deprecated.~~
    - **Train:** Adds a unit to the protoUnit's command panel. Takes three parameters: _row_, _page_, _column_. Despite being always set and processed by the game, the _row_ parameter is effectively unused.

&lt;Train row='0' page='0' column='3'&gt;Skirmisher&lt;/Train&gt;

From the original AoE3DE onwards, it can take a _trShow_ attribute which, when set on a Train entry on the Trading Post, will force the unit to be shown in Trading Posts placed on Trade Routes.

&lt;Train row='0' page='0' column='3' trshow='1'&gt;deChasqui&lt;/Train&gt;

- - **Tech:** Adds a tech to the protoUnit's command panel. Takes three parameters: _row_, _page_, _column_. Despite being always set and processed by the game, the _row_ parameter is effectively unused.

&lt;Tech row='0' page='2' column='1'&gt;NatBowyery&lt;/Tech&gt;

From the original AoE3DE onwards, it can take a _natShow_ attribute which, when set on a Tech entry on the Trading Post, will force the technology to be shown in Trading Posts placed on Native Settlements, regardless of the civilization.

&lt;Tech row='0' page='1' column='3' natshow='1'&gt;deMightyTambos&lt;/Tech&gt;

- - **Command:** Adds a ProtoUnitCommand to the protoUnit's command panel. Takes two parameters: _page_, _column_.

&lt;Command page='10' column='2'&gt;SetGatherPointEconomy&lt;/Command&gt;

From _Knights of the Mediterranean_ AoE3DE DLC onwards, it can take a _trCmdShift_ attribute which, when set on a Command entry on the Trading Post, will force the command to be shifted to the last row, when shown in Trading Posts placed on Trade Routes.

&lt;Tech row='0' page='1' column='3' trCmdShift='1'&gt;Ransom&lt;/Tech&gt;

- - **Contain:** Allows the set unitType to be garrisoned within the unit. Can take the following parameters:
        - **_external_:** If set to 1, contained units will be rendered outside containing building or unit.
        - **_popException_:** If set to 1, contained units of the given type won't have their population accounted for, while they are garrisoned. Available from original AoE3DE release onwards.
        - **_popDiscount_:** Deducts set value from the population of garrisoned units of the given type. Available from original AoE3DE release onwards.
        - **_inDelay_:** Delay time in seconds for garrisoning units of the given unit type. Available from _Knights of the Mediterranean_ AoE3DE DLC onwards.
        - **_outDelay_:** Delay time in seconds for ejecting units of the given unit type. Requires _MeteredGarrison_ protoUnit flag to be set in container for proper functionality. Available from _Knights of the Mediterranean_ AoE3DE DLC onwards.
    - **Tactics:** Path to protoUnit tactics file, relative to _Data\\tactics_.

## Definitive Edition

- - **SocketedMinimapIcon:** Path to minimap icon texture to be used by building if it's placed over a socket, relative to the _Art_ folder.
    - **CivFlagOverride:** Path to civilization flag texture, relative to the _Art_ folder, to be used instead of the flag of the current civilization.
    - **LegacyHotkeyContext:** Hotkey context to be used for Legacy hotkey keybinding.

Should be set to a valid hotkey context.

- - **UnitHelpOverride:** ProtoUnit of the help/history/compendium entry to be used, instead of the one of the current protoUnit.
    - **KnockoutTextID:** String ID to be used for the knockout message.
    - **KnockoutRescueHitpointRatio:** Minimum hitpoint ratio in which rescuing a

knocked-out unit by bringing friendly units to its vicinity is allowed. If it's not set, default hardcoded values will be used, according to the civType.

- - **HoverTextOverride:** String ID to be used when hovering over a foundation of this particular protoUnit. Uses default hardcoded formatted string, if not set.
    - **BuildTextOverride:** String ID to be used for the notification text once the building is fully built. Uses default hardcoded formatted string, if not set.
    - **ContainedHitPointBonus:** Defines how much each garrisoned unit contributes to its hit points. Applied linearly.
    - **PlacementObstructionRadiusX:** Obstruction radius to be used while placing foundations in the X axis. Used by buildings with crops, whose placement is restricted by _ObstructionAtLeastFromType_ conditions.
    - **PlacementObstructionRadiusZ:** Obstruction radius to be used while placing foundations in the Z axis. Used by buildings with crops, whose placement is restricted by _ObstructionAtLeastFromType_ conditions.
    - **FarmingRadiusX:** Radius of the walkable area of a farm building in the X axis. Requires the _UseFarmingAnims_ protoUnit flag to be set for proper functionality.
    - **FarmingRadiusZ:** Radius of the walkable area of a farm building in the Z axis. Requires the _UseFarmingAnims_ protoUnit flag to be set for proper functionality.
    - **FarmingNumStops:** Number of different positions an unit can move to after finishing a gathering cycle in a farming building, including its current position. Can't be set to a value lower than two. Requires the _UseFarmingAnims_ protoUnit flag to be set for proper functionality. If it's not set, it will default to the hardcoded value of 8.
    - **FarmingObstructionRadiusX:** Obstruction radius in the X axis to be used by farming code. Doesn't affect farm placement or building.
    - **FarmingObstructionRadiusZ:** Obstruction radius in the Z axis to be used by farming code. Doesn't affect farm placement or building.
    - **ChargeUsageTime:** Amount of time in seconds in which the main Charged Action is usable, after it's first triggered.
    - **AuxRechargeTime:** Recharge time used by Secondary Charged Actions/Abilities.
    - **AuxChargeUsageTime:** Amount of time in seconds in which the secondary Charged Action is usable, after it's first triggered.
    - **DodgeChance:** Chance of dodging an attack. Defaults to a hardcoded value if not set.

Requires protoUnit flag _CanDodgeAttacks_ to be set for proper functionality.

- - **DodgeMessageID:** String ID of the floating text message to be used when successfully dodging an attack. Defaults to a hardcoded value if not set. Requires protoUnit flag _CanDodgeAttacks_ to be set for proper functionality.
    - **DodgeSoundSet:** Soundset to be played when successfully dodging an attack. Defaults to a hardcoded value if not set. Requires protoUnit flag _CanDodgeAttacks_ to be set for proper functionality.
    - **SharedBuildLimitUnit:** ProtoUnit whose build limit value should be used for shared build limit. Requires protoUnit flag _UseSharedBuildLimit_ to be set for proper functionality.
    - **SharedBuildLimitUnitTypes:** Lists unit types or protoUnits which should be accounted for the shared build limit. Requires protoUnit flag _UseSharedBuildLimit_ to be set for proper functionality.

&lt;SharedBuildLimitUnitTypes&gt;

&lt;UnitType&gt;Outpost&lt;/UnitType&gt;

&lt;UnitType&gt;OutpostWagon&lt;/UnitType&gt;

&lt;UnitType&gt;deUSOutpostWagon&lt;/UnitType&gt;

&lt;UnitType&gt;deStateCapitolTrainOutpostWagon&lt;/UnitType&gt;

&lt;/SharedBuildLimitUnitTypes&gt;

- - **CommunityPlazaWeight:** Defines how many workers this unit should count as when gathering at a Community Plaza or a building which uses gathering place logic.
    - **CommunityPlazaLimit:** Defines how many instances of this particular unit can gather at the same time at a Community Plaza or a building which uses gathering place logic.
    - **ConversionResistance:** Multiplies the conversion time for this unit by the given value.
    - **DisplayedRange:** Overrides the displayed range value by the given value. Requires protoUnit flag _DisplayRange_ to be set for proper functionality.
    - **ScalingAuraScale:** Factor by which aura attachments will be scaled for this unit.
    - **AgeUpCostAbsoluteMultiplier:** Multiplier to the value by which kill bounties obtained by this unit contribute to the age-up discount.
    - **ResourceReturn:** Amount of resources to be given to the player in case the unit or building is destroyed. Resources aren't given if the unit or building was deleted, unless if the _ApplyResourceReturnIfDeleted_ protoUnit flag is set. Takes one parameter, _resourcetype_, which sets the resource type

&lt;ResourceReturn resourcetype='Gold'&gt;100.0000&lt;/ResourceReturn&gt;

- - **ResourceReturnRate:** Amount of resources to be given to the player, as a rate of the current cost of the unit, in case the unit or building is destroyed. Resources aren't given if the unit or building was deleted, unless if the _ApplyResourceReturnIfDeleted_ protoUnit flag is set. If the protoUnit flag _ResourceReturnRateTotalCost_ is set, it will account for the total cost of the unit in resources.

&lt;ResourceReturnRate resourcetype='Gold'&gt;0.5000&lt;/ResourceReturnRate&gt;

- - **GatherRateMultiplier:** Rate by which the gather rate of an unit gathering from an instance of this protoUnit will be multiplied.
    - **SharedSelectionUnitTypes:** List of unitTypes which will share double-selection with this unit.

&lt;SharedSelectionUnitTypes&gt;

&lt;UnitType&gt;deEmir2&lt;/UnitType&gt;

&lt;/SharedSelectionUnitTypes&gt;

- - **NotContain:** Forbids the set unitType from being garrisoned within the unit.
    - **StealthDiscoveryRadius:** Defines the minimum distance in which an enemy unit without the _AbstractCanSeeStealth_ flag can cause this unit to be discovered when in Stealth mode.
    - **InitialTactic:** Default tactic to be used by instances of the protoUnit upon creation.
    - **DeadTransform:** ProtoUnit to which the current unit will be transformed to upon reaching zero hitpoints.
    - **TrainBatchSize:** Defines the size of each unit training batch, overriding the default value of 5 units.
    - **UnitSellCommand:** Defines the protoUnitCommand through which this unit can be sold, through the _uiSellUnit_ console syscall.
    - **UnitSellRate:** Defines the rate in which the unit cost will be exchanged upon the usage of the unit selling command for this unit. Set to 1.0 by default.
    - **BuildLimitIncrement:** Additional build limit for protoUnit, which, for Native Settlement units, isn't scaled with the Alliance Level or the number of Trading Posts for the protoUnit's subCiv.
    - **SkinIcon:** WPF path for unit icon for a given skin, relative to Data\\wpfg. Takes one parameter, _id_, which denotes the ID of the skin for which the given icon will be used. Only applies for Hero units which support custom skins.
    - **SkinPortrait:** WPF path for unit portrait for a given skin, relative to Data\\wpfg. Takes one parameter, _id_, which denotes the ID of the skin for which the given portrait will be used. Only applies for Hero units which support custom skins.
    - **FakeCard:** Adds a non-HomeCity shipment to the protoUnit's command panel. Takes three parameters: _row_, _page_, _column_. Despite being always set and processed by the game, the _row_ parameter is effectively unused.

&lt;FakeCard row='0' page='2' column='1'&gt;DEBasilicaShipSpy1&lt;/FakeCard&gt;

- - **PanelNameID:** String ID for protoUnit displayed name in socket panel, if supported by the unit.
    - **PanelRolloverID:** String ID for protoUnit displayed rollover text in socket panel, if supported by the unit.
    - **AIStanceBaseDistance:** Base distance to be used for unit auto-attack reaction when its AI Stance is set to _Defensive_. Set to 30, by default.
    - **ContainedRegenRate:** Percentage-based regeneration rate for garrisoned units within the protoUnit. Only applies for buildings; overrides _DefaultContainedRegenRate_ in base civilization data.
    - **FreeBuildPoints:** Total amount of time in seconds required to build protoUnit for free through a unit belonging to the _AbstractFreeBuilder_ unit type (e.g. Italian Architect) when working at a 1.0 Work Rate over the Foundation.
    - **SocketBuildProtoUnit:** ProtoUnit to be built as a socketed building over the current unit when a _socketBuild_ command is applied.
    - **SocketBuildRate:** Rate in which a _socketBuild_ command will build the building referred through the _SocketBuildProtoUnit_ attribute.
    - **Recharge:** Recharge value used by the Primary Charged Actions/Abilities, which, unlike the _RechargeTime_ attribute, can be tied to variables other than elapsed time. Takes two parameters, _type_ and _init_, which are described as follows:
      - **_type_:** Defines the variable to be taken in account for charging. Can be set to _Time_ (elapsed time, same behaviour as _RechargeTime_), _Kills_ (number of kills), _Damage_ (total amount of damage inflicted) or _Attacks_ (number of hits inflicted by the unit.
      - **_init_:** Should be set to _1_ if Charged Ability is supposed to start charged and ready to use as soon as the unit is created, or _0_, otherwise. Set to _1_ by default.
    - **AuxRecharge:** Recharge value used by the Secondary Charged Actions/Abilities, which, unlike the Aux_RechargeTime_ attribute, can be tied to variables other than elapsed time. Takes the same parameters as _Recharge_.
    - **DeploymentCommand:** ProtoUnit command used for deployment of units currently garrisoned and that effectively replaces the default Ungarrisson command. Requires _DeploymentUngarrison_ protoUnit flag to be set for proper functionality.
    - **DetonationProtoAction:** ProtoAction to be triggered for detonation upon death.

Requires _DetonationDeath_ protoUnit flag to be set for proper functionality.

- - **DetonationCommand:** ProtoUnit command which is supposed to initiate detonation process and effectively replaces the default deletion command. Requires _DetonationDeath_ protoUnit flag to be set for proper functionality.
    - **DetonationHitpointThreshold:** Hit point ratio which, when reached, causes protoUnitCommand set through the _DetonationCommand_ attribute to be triggered, effectively initiating the detonation process.
    - **DetonationHitpointDecay:** Rate in which unit hitpoints will decay after detonation hitpoint threshold is reached.
    - **RoundelTierCount:** Number of rows of cannons to be taken in account for Roundel Attack actions.
    - **DisabledDuringNoRush:** When set to 1, building won't be constructible while Treaty period is active.
    - **VeterancyBonus:** Defines bonuses to be applied to the unit upon reaching specific veterancy ranks. Bonuses for each rank are defined through _VeterancyModify_ children notes, which take a _modifyType_ attribute that should be set to a valid modify type.

Requires _ExperienceUnit_ protoUnit flag to be set for proper functionality.

&lt;VeterancyBonus&gt;

&lt;Rank id='0'&gt;

&lt;VeterancyModify modifyType='MaxHP'&gt;1.15&lt;/VeterancyModify&gt;

&lt;VeterancyModify modifyType='ROF'&gt;0.85&lt;/VeterancyModify&gt;

&lt;/Rank&gt;

&lt;Rank id='1'&gt;

&lt;VeterancyModify modifyType='MaxHP'&gt;1.30&lt;/VeterancyModify&gt;

&lt;VeterancyModify modifyType='ROF'&gt;0.70&lt;/VeterancyModify&gt;

&lt;/Rank&gt;

&lt;Rank id='2'&gt;

&lt;VeterancyModify modifyType='MaxHP'&gt;1.45&lt;/VeterancyModify&gt;

&lt;VeterancyModify modifyType='ROF'&gt;0.55&lt;/VeterancyModify&gt;

&lt;/Rank&gt;

&lt;/VeterancyBonus&gt;

- - **AutoConvertSoundSet:** Soundset to be played when unit is converted through an

_AutoConvert_ protoAction.

- - **CapturedMinimapIcon:** Path to minimap icon texture to be used by unit or building if it's auto-capturable and has been captured by a non-GAIA player, relative to the _Art_ folder.
    - **SubCivLOS:** Additional LOS to be applied to building, if it's placed on a Native Socket belonging to a valid SubCiv.
    - **SocketBuildCommandID:** For Capturable Native Settlement sockets, ProtoUnitCommand to be displayed on the UI while no TP has been built over it.
    - **TransformCommand:** Protounit command to be researched when a transform command is issued over the unit.
    - **ChaosDuration:** Duration of chaos effects over the given unit. Overrides automatically calculated value based on unit bounty.
    - **UnitRegen:** Defines individual protoUnit regeneration rate. The supported parameters are listed as follows:
      - **_idleTimeout_:** Minimum amount of time in seconds a unit has to be idle before regeneration begins.
      - **_damageTimeout_:** Minimum amount of time in seconds since the last time the unit received any damage before regeneration begins.
      - **_rateLimit_:** Minimum unit hitpoint ratio that can be reached through degeneration, when setting regeneration rate to a negative value.
      - **_absolute_:** If present, regeneration rate will be linear/additive, instead of percentage-based.

## Flags

- **Legacy**
  - **NoUnitAI:** Self-explanatory.
  - **NotPlayerPlaceable:** Causes the unit to not be directly placeable through the Editor
  - **StartEnabled:** Unit starts enabled, without the necessity of being explicitly enabled by any technology.
  - **NotAlive:** Self-explanatory.
  - **TieToWaterSurface:** Self-explanatory.
  - **FlyingUnit:** Self-explanatory.
  - **NoTieToGround:** Self-explanatory.
  - **Collideable:** Self-explanatory. Set by default.
  - **NonCollideable:** Self-explanatory.
  - **Immoveable:** Self-explanatory.
  - **NoHPBar:** Self-explanatory.
  - **DieAtZeroHitpoints:** Self-explanatory. Set by default.
  - **DoNotDieAtZeroHitpoints:** Self-explanatory.
  - **DieAtZeroResources:** Self-explanatory.
  - **DoNotDieAtZeroResources:** Self-explanatory.
  - **ValidateResourceInventory:** Forces the game to verify current unit resource inventory against the carry capacity for each resource, and adjust it accordingly. Set by default.
  - **DoNotValidateResourceInventory:** Causes unit resource inventory to not be checked against the carry capacity for each resource.
  - **NoBloodOnDeath:** Self-explanatory.
  - **BloodOnDeath:** Self-explanatory. Set by default.
  - **DoesNotHaveGatherPoint:** Self-explanatory. Set by default.
  - **HasGatherPoint:** Self-explanatory.
  - **PlayerPlaceable:** Set by default.
  - **NonSolid:** Causes unit or building obstruction to not block units from passing through.
  - **Selectable:** Self-explanatory. Set by default.
  - **NotSelectable:** Self-explanatory.
  - **FlattenGround:** Self-explanatory.
  - **FadeInOnCreation:** Causes units to have a fade-in effect after being created. Unused, but seemingly functional.
  - **ObscuresUnits:** Self-explanatory.
  - **ObscuredByUnits:** Self-explanatory.
  - **NotObscuredByUnitsAsFoundation:** Self-explanatory.
  - **DoNotShowOnMinimap:** Self-explanatory.
  - **NonAutoFormedUnit:** Causes units to not adopt formations automatically.
  - **DontRotateObstruction:** Causes actual obstruction to be rotated accordingly to be building orientation.
  - **DoNotCreateUnitGroupAutomatically:** Causes unit to not automatically be added to a Squad once it's instantiated.
  - **VisibleUnderFog:** Self-explanatory.
  - **VisibleUnderFogIfGaia:** Self-explanatory.
  - **AlphaFadeLifespan:** If Lifespan is set for the protoUnit, causes the fade-out to begin as the lifespan time starts to be counted.
  - **Wanders:** Causes units to wander. Used for herdables and huntables. Seems to only affect GAIA-owned units.
  - **CollidesWithProjectiles:** Self-explanatory.
  - **Projectile:** Self-explanatory.
  - **FadeInOnBuild:** Causes buildings to have a fade-in effect after being fully built.
  - **NotSearchable:** Causes the unit to not be accounted for internal visible unit lookups.
  - **UnlimitedSupply:** Used for resource storages with unlimited supply of resources.
  - **FaceOutwards:** Causes unit to be placed facing the lowest terrain point. Unused, but likely functional.
  - **SnapPlacement:** Allows socketed buildings to properly snap into sockets during placement.
  - **~~​ SplitAtMaxInventory:~~** ~~Unused and deprecated.~~
  - **FadeOutDuringDeathAnimation:** Causes fade out to start as the death animation begins.
  - **ForceToGaia:** Self-explanatory.
  - **DoNotYawDuringMovement:** Intended to cause units to not rotate/turn while moving.

Unused, but likely functional.

- - **~~​ MarketAbility:~~** ~~Unused and deprecated.~~
    - **GivesLOSToAll:** Self-explanatory.
    - **Doppled:** Causes the unit to leave a doppelganger when under fog.
    - **NotDeleteable:** Self-explanatory.
    - **~~​ GarrisonBonus:~~** ~~Unused and deprecated.~~
    - **~~​ GarrisonSpeedBonus:~~** ~~Unused and deprecated.~~
    - **DestroyProjectile:** If set on a projectile protoUnit, causes it to be destroyed after reaching the target.
    - **OnlyInEditor:** Self-explanatory.
    - **~~​ CannotAttackDisabledUnits:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **OrientUnitWithGround:** Causes unit to orient itself with the ground.
    - **AlwaysFullColorAsCursor:** Determines whether or not we check obstructions and alter the color of this as a cursor item.
    - **ConstrainOrientation:** Enables orientation constraints for the code that orients a unit with the ground.
    - **~~​ InitialGarrisonOnly:~~** ~~AoM leftover. Unused and deprecated.~~
    - **WallBuild:** Self-explanatory.
    - **~~​ ShowGarrisonButton:~~** ~~Unused and deprecated.~~
    - **NotCommandable:** Causes unit to not be able to take commands.
    - **KillOnAnimLoop:** Causes unit to be killed on next animation loop.
    - **~~​ AlwaysCheckCollisions:~~** ~~Unused and deprecated. Original purpose unknown.~~
    - **AreaDamageConstant:** Causes the area damage inflicted by the unit to not vary with distance from the original attack target position. Unused, but functional.
    - **NoIdleActions:** Causes internal idle action to not be processed for this unit.
    - **NoProjectileDamage:** Causes projectile unit to inflict no damage.
    - **PlaceAnywhere:** Disables placement checks entirely.
    - **ProjectileTerrainOnly:** Forbids projectile unit from colliding against units. Unused, but likely functional.
    - **PlayerOwnsObstruction:** Used for Gate functionality.
    - **PlaceSocketWhenPlacing:** Causes Socket protoUnit to be placed once the building is placed. Unused, but likely functional. Requires _SocketUnitType_ to be set to a protoUnit, instead of an UnitType.
    - **AlwaysShowAsSocket:** Causes socket unit to remain visible after it's occupied.
    - **StartOnAnimationUpdate:** Causes unit to be initialized with persistent updates (i.e. for unit AI or persistent actions) disabled, except for animation updating.
    - **StartOnNoUpdate:** Causes unit to be initialized with persistent updates (i.e. for unit AI or persistent actions) disabled.
    - **DeadReplacementWhenDestroyed:** When set, causes the dead replacement to be only placed when the unit is actually destroyed, and not right after death/killing is triggered.
    - **AnnounceConversion:** AoM leftover. Causes a notification to be sent to all players when building is upgraded/transformed. Should be deemed deprecated, unless if upgrading/transforming, as used in AoM Settlements, can be performed over AoE3's iteration of the BANG engine.
    - **SelectWithObstruction:** If set, selection will also account for unit obstruction.
    - **ConvertOnStartBuild:** AoM leftover. Causes building to be converted to player as soon as upgrading/transforming process starts.
    - **PlaceAsFoundation:** Forces building to be not fully built on scenario load or when placed in the editor.
    - **ConvertToGaiaAtZeroHitpoints:** AoM leftover. Returns object to Gaia control at zero hitpoints. Unused, but likely functional.
    - **MakeUnbuiltAtZeroHitpoints:** Resets all construction progress when the unit hits zero hitpoints. Unused, but likely functional.
    - **~~​ ExcludeFromPlaytest:~~** ~~AoM leftover. Unused and deprecated.~~
    - **SolidFoundation:** Causes foundations to be solid and collideable at placement.
    - **HideGarrisonFlag:** Causes Garrison Flag to not show up over unit/building if it has garrisoned units. Unused, but functional.
    - **DoppleOnlyWhenDead:** If set, unit will only leave a doppelganger under fog when dead. Used for trees.
    - **DirectProjectile:** If set, launched projectiles fly direct in a straight line to their target.

Unused, but likely functional.

- - **ForceBuildingData:** If set, causes internal Building Data, containing attributes like Building Work Rate, to be initialized for the unit, even if it's not a building.
    - **DecalStickToWaterSurface:** If set, the decal will be computed using water vertices when over water.
    - **AllowAutoGarrison:** Allows auto-garrisoning by right-clicking for garrisonable units.
    - **~~​ OverrideInitialGarrison:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ TownBellButton:~~** ~~Unused and deprecated.~~
    - **MeteredGarrison:** Causes ungarrisoning/ejection to be done unit per unit, internally.

Unused, but functional.

- - **RevealFoundation:** AoM leftover. When set, causes this building's location to be revealed to all when first worked upon. Unused, but functional.
    - **ColorTransformNonGaia:** When set, causes the minimap icon to use the player color when unit is converted from gaia
    - **~~ApplyHandicapTraining:~~** ~~Unused and deprecated.~~
    - **Tracked:** Causes the unit to be accounted for by KB lookups.
    - **VisibleOwnerOnly:** Makes the unit become only visible to owner and allies.
    - **~~​ HideFromHelp:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ HideResourceInventory:~~** ~~AoM leftover. Unused and deprecated.~~
    - **NotRotateable:** Forbids object or building from being rotateable at placement.
    - **DestroyUnderBuilding:** Causes the object to be deleted once a building foundation is placed over it.
    - **~~​ NotScalable:~~** ~~Unused and deprecated. Possibly a leftover of scaling feature.~~
    - **GodPowerExclusion:** AoM leftover. Intended to prevent special powers/abilities from being targeted under the vicinity of the unit/building, akin to Isis monuments and Theia Hesperides Trees in AoM. Unused, but likely functional.
    - **Invulnerable:** Self-explanatory.
    - **DeadReplaceOnlyOnTimeout:** Limits dead replacement only to deaths due to lifespan expiring. Unused, but functional.
    - **~~​ SingleGatherer:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **InvulnerableIfGaia:** Self-explanatory.
    - **CorpseDecays:** Determines if unit is supposed to get corpse decals when the it dies.
    - **~~​ HideHitpointsIfGaia:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **~~​ FlareOnFullyBuilt:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ AnnounceFoundationStarted:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ VictoryBuilding:~~** ~~AoM leftover. Unused and deprecated.~~
    - **PaintTextureWhenPlacing:** If set, forces the editor to paint down a suitable texture underneath if required.
    - **~~​ Burnable:~~** ~~AoM leftover. Unused and deprecated.~~
    - **MutateDopples:** AoM leftover. Causes fog of war doppelgangers to be updated, in case base unit got mutated to another unitType.
    - **InvalidTownBellLocation:** Prevents building from receiving units for garrison from Town Bell activation.
    - **~~​ UseObstructionOnMinimap:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ UseAlignedObstructionOnMinimap:~~** ~~AoM leftover. Unused and deprecated.~~
    - **~~​ RenderAfterWater:~~** ~~Unused and deprecated.~~
    - **~~​ DontSortAlphaPolys:~~** ~~Unused and deprecated.~~
    - **DontMarkExtraFog:** Causes unit to not mark additional fog (unveil nearby fogged units)
    - **VisibleUnderFogOnlyAfterSeen:** If set, unit will become visible under the fog, if it had seen before by the player.
    - **RMCanRotate:** Allows unit to be rotated by RM placement.
    - **KnockoutDeath:** Enables hero death for unit.
    - **VariationLocked:** Causes unit graphical variation to be set into unit data upon scenario save.
    - **ExperienceUnit:** Causes kills of military units performed by this unit to be internally tracked by the unit's dynamic data. Has no practical effect over the game or the UI for Legacy, but for Definitive edition, as of _Knights of the Mediterranean_ DLC onwards, is required for the usage of the Veterancy system on units.
    - **FadeOutDecalOnDeath:** Causes unit decal to fade out upon death.
    - **AnnounceDestruction:** AoM leftover. Causes a notification to be sent to all players when destroyed. Unused, but likely functional.
    - **~~​ BattleMusicTrigger:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **RotateInPlace:** If set, allows units to rotate even if they are immovable
    - **AdjustPositionOnTerrainCollision:** If set, this unit will stop moving at the point of impact, and move to the point of intersection.
    - **HeroName1:** Causes unit to use randomly generated names, out of patterns defined in _randomnames.xml_. As of AoE3 original release onwards, _HeroName1_ and _HeroName2_ have the exact same functionality.
    - **HeroName2:** Causes unit to use randomly generated names, out of patterns defined in _randomnames.xml_. As of AoE3 original release onwards, _HeroName1_ and _HeroName2_ have the exact same functionality.
    - **~~HideCostFromDetailHelp:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **PreventsWallBuilding:** Should be set true for buildings/objects that won't allow a wall nearby. Unused, but functional.
    - **~~​ ColonyBuilding:~~** ~~Unused and deprecated. Likely a leftover of the old Colony system.~~
    - **StartingColonyBuilding:** Causes building to trigger starting units spawning upon first placement.
    - **~~​ ColonyPlacementCenter:~~** ~~Unused and deprecated. Likely a leftover of the old Colony~~ ~~system.~~
    - **~~​ ColonyPlacementL:~~** ~~Unused and deprecated. Likely a leftover of the old Colony system.~~
    - **CreateUniqueInstance:** Causes every instance of this unit to use its own instance of protoUnit data. Used for Trading Post functionality.
    - **TileAlignPlacement:** If set, item snaps to tile aligned locations when placing.
    - **Nugget:** Self-explanatory.
    - **WorldToolTip:** Causes persistent world tooltip to be displayed for the unit, while it's alive. Persistent world tooltip will use _WorldTooltipStringID_ for its text.
    - **OrientWithRiver:** Causes unit to orient itself with river flow.
    - **TCBuildLimit:** Causes unit to use shared TownCenter-Covered Wagon Build Limit.
    - **~~​ PerimeterGenerator:~~** ~~ProtoUnit flag intended to be used by the AirCraft system. Unused~~ ~~and not functional in AoE3.~~
    - **~~​ Airfield:~~** ~~ProtoUnit flag intended to be used by the AirCraft system. Unused and not~~ ~~functional in AoE3.~~
    - **~~​ Blocker:~~** ~~ProtoUnit flag intended to be used by the AirCraft system. Unused and not~~ ~~functional in AoE3.~~
    - **LockedSquad:** Groups trained units within the same squad when block training.

Unused, and likely only partially functional, since actual squad-locking isn't supported by the game engine anymore.

- - **SelectOnTrain:** Causes unit to be selected once it's trained. Unused, but likely functional.
    - **PlaceAnywhereRules:** Forces building to abide by placement rules, even if

_PlaceAnywhere_ protoUnit flag is set.

- - **ForcePopulationImpactWhenPlaced:** Enforces population impact right when building foundation is placed
    - **CanAutoHeal:** Specifies units that can auto-heal other units.
    - **ExcludeFromMoveAllMilitary:** Self-explanatory.
    - **DoNotShowAutoGatherRate:** If set, causes _AutoGather_ action information to not be shown in the UI.
    - **CanTargetButTakesNoDamage:** Self-explanatory.
    - **YPUsesExtraWorkerSlot:** Causes units to take two worker/gatherer slots when working/gathering.
    - **YPForceTrainAtBaseTrainPoints:** Forces units trained or maintained at this unit/building to use their base train points.
    - **AllowOverPopCap:** Allows unit to be trained, if there's at least one free population slot, regardless if player will go over population capacity afterwards.
    - **ShowTactics:** Causes building tactics defined through protoUnitCommands to be displayed in the UI.
    - **EnterHotkeyContext:** Allows building to have a proper hotkey context and, thus, accept hotkeys, even if it doesn't train units.
    - **CivSpecificText:** Allows this unit to properly use civilization-specific text in its tooltip, based on civ keys.
    - **AlwaysAllowOverPopCap:** Forces unit to be trained, even if there are no free population slots.
    - **NeverCountDeathAsLoss:** Causes unit's death to not be counted as loss for stat tracking.

## Definitive Edition

- - **CantBeSlowed:** Forbids unit from being affected by snaring/_TargetSpeedBoost_.
    - **BuildingShowTactics:** Causes building tactics defined through protoUnitCommands to be displayed in the UI.
    - **AllowTrainingOnWater:** Allows unit to be trained from a non-land unit.
    - **GatherFromTrees:** Allows non-_AbstractVillager_ units to gather from trees properly.
    - **DrawnToCrates:** Forces unit to auto-gather from nearby crates.
    - **DisplayRange:** Causes unit range to be displayed as a decal upon selection. Rendered obsolete with recently implemented game options, which allow displaying range for all units/buildings.
    - **InvulnerableToAreaDamage:** If set, this unit cannot receive any kind of damage from area attacks.
    - **DoNotDragSelectWithUnits:** If set, this unit won't be selected with other _UnitClass_ units when drag-selecting.
    - **TownDefenseUnit:** Intended to denote short-duration levied units. Obsolete.
    - **DontTrainInBatches:** Prevents batch training and forces train limit per action to 1.
    - **KillIfConverted:** If set, unit is automatically killed after being successfully converted/captured.
    - **ShowUnitResourceActionRates:** If set, current resource rates for UnitResource actions (i.e. Torp) are displayed in the UI.
    - **SettlerBuildLimit:** If set, unit will share build limit with all units with the _LogicalTypeSettlerBuildLimit_ unittype set, and will use the build limit of that civilization's Settler/Villager unit.
    - **UseSharedBuildLimit:** If set, unit will use the generic shared build limit.
    - **InflictsNoDamage:** If set, unit should not inflict any damage when attacking, regardless of protoAction attributes. Attacks performed by this unit will still raise warnings for enemies.
    - **DisplayDecoyInfo:** If set, displays fake unit info (portrait and rollovers) to enemies.
    - **CanDodgeAttacks:** Enables dodging behaviour for non-Japanese Monk units.
    - **NextResearchIsFree:** Forces the immediate next research to be added to the queue in a building to be free.
    - **DisableBigButtonUI:** If set, no UI slots will be reserved for big button, if building belongs to a native civ (civType 1).
    - **UnitTransformFree:** If set, transforming to this unit won't cost any resources.
    - **UseFarmingAnims:** If set, units will move around the gather site while gathering from it, akin to Mills and Farms.
    - **BuiltWithSeedingAnim:** If set, forces units to use farming animations when constructing the building.
    - **RangeDisplayedAsSquare:** If set, range is displayed as a square decal.
    - **AllowSocketPlacement:** Indicates units that behave like sockets, while not being of AbstractSocket type.
    - **OptionalSocketPlacement:** If set, a socket-able building will still be buildable outside a socket.
    - **ForceInfluenceRate:** If set, resources won't be gathered if no valid influence rate is set.
    - **AllowPlacementOnIce:** If set, allows a building to be placed over Ice terrain.
    - **GatherableWhenSocketed:** Intended for buildings which become gatherable when placed over a socket.
    - **DoNotQueue:** If set, unit won't obey building queue when trained.
    - **MagnetDoesNotLockUnits:** If set, magnet building won't make herdables/huntables unattackable.
    - **UseTacticArmorOverride:** If set, unit will check for armor overrides in tactic data.
    - **ResourceReturnRateTotalCost:** If set, return resource rate will be calcualated over the total cost, instead of per resource.
    - **ForceBatchTrain:** If set, _MultipleBlockTrain_ units/Banner Armies will be forced to use batch training
    - **UISkipActiveTechs:** If set, command panel won't 'reserve' slots for active techs.
    - **ApplyResourceReturnIfDeleted:** If set, resource return will be applied even if the unit was deleted by the player.
    - **AlliesIgnoreInfluenceRate:** If set, allied players gathering from this unit will ignore any checks for Influence Rate.
    - **GatherableByAllies:** If set, allows non-standard resource buildings to be gathered by allies.
    - **ShowAutoGatherAbsoluteInfo:** If set, unit UI will display the units/buildings which are improving its autogather rate, using the _AutoGatherAbsolute_ modifyType.
    - **DoTacticToSameUnitType:** If set, changing tactic for this unit will cause the change to be propagated to all instances of the same unit, akin to Japanese Shrine behaviour.
    - **DoNotDeleteDeadHuntOnPlacement:** If set, building will be forced to not remove dead hunt within its area when placed.
    - **CannotSnare:** If set, unit won't be able to cause enemy units to become slower temporarily (that is, 'snaring' them) through attack actions with the _TargetSpeedBoost_ protoAction flag set.
    - **BaseSpeedRunAnim:** If set, the base protoUnit speed will be used as a reference for the jog/run animation switch handling, allowing technology and protoPower GeneralEffect upgrades affecting the unit speed to cause it to use jog/run animations when moving, depending on the resulting unit speed value.
    - **HCEconomicGatherPointOnly:** If set, unit won't be able to be selected as the Home City arrival point for military shipments.
    - **DeadTransformBuildLimit:** If set, when a unit transform is triggered upon unit death, through the _DeadTransform_ protoUnit attribute, build limit will be checked for the target unit.
    - **ForceGatherSiteResource:** If set, the game will always use the gather site inventory resource ID for gathering, set through _ModifyGather_ unit actions, without checking the protoUnit main resource or the unit inventory itself.
    - **UseStaticFarmingAnims:** If set, units will gather from this gather site at predefined spots, defined as bones within the building model. This behaviour is the same as the one used in the Native Farm and in the Asian Rice Paddy, in legacy AoE3, and in the Mexican Hacienda, in the AoE3DE Mexican Civilization release.
    - **UseDanceActions:** If set, allows the unit to use _DanceBonus_ protoActions, include rate escalation behaviour with gatherers, even if it's not of Community Plaza type (_AbstractCommunityPlaza_).
    - **GatherGarrisonToggle:** If set, allows building to toggle between gathering and garrisonning mode.
    - **HerdablesIgnoreGatherPoint:** If set, herdables created/spawned from the unit will ignore gather point data.
    - **FreeRepair:** If set, repairing this unit costs no resources.
    - **CountHerdableAsGatherer:** If set, herdables gathering at this unit will be count as gatherers by the game KB.
    - **GatherersContributeToResourceRate:** If set, the total resource rate of gatherers with be added into the displayed auto-gather rate at the building for a protoAction with the flag _AddGathererContribution_.
    - **AllowGatheringWhenFull:** If set, full invetory checks will be disabled when gathering from this unit, allowing herdables to gather from this unit, even if their current resource inventory is full.
    - **ShowAreaHealRate:** If set, healing aura rate will be displayed on the UI, just as targeted healing rate is.
    - **ForceFullTechUpdate:** If set, the updating of all player tech nodes and tech prerequisite states will be enforced once the unit is initialized, to update technology prerequisites dependent on unit count.
    - **UseAnimalsLabel:** If set, the label for the gatherers listing in the stat panel will use the 'Animals' string.
    - **DanceActionNoWorkers:** If set, allows _DanceBonus_ protoActions to function properly for the given protoUnit at base rates, without accounting for or requiring workers at the building. Resulting behavior will be similar to Dojos, Confuncian Academies and similar buildings from AoE3:TAD.
    - **ChargeMoveAnim:** If set, unit will be allowed to use custom animations when moving to perform a charged action.
    - **SocketFreeBuilding:** If set, issuing a valid _SocketBuild_ command over this unit won't deduct building cost from the player's stockpile.
    - **CannotAttackIfGaia:** If set, unit won't be able to attack when belonging to GAIA.
    - **ApplyFlagOverrideIfGaia:** If set, civilization flag override, if available, will only be applied if unit belongs to GAIA.
    - **ForceFullTechUpdateTeam:** If set, the updating of all player tech nodes for the entire team will be enforced once the unit is initialized, to update unit count dependant tech prereqs.
    - **InvestmentBuilding:** If set, resource investment data will be displayed in the building's UI.
    - **FakeConversion:** If set, placing or converting the unit to a player won't change actual ownership of the unit, but will still set the given player as the owner for resource production through _AutoGather_ protoActions.
    - **AllowRebuildInGrouping:** If set, when placed in a RM grouping instance, unit position and orientation will be saved, allowing it to be re-built through the usage of the proper trigger effects.
    - **ForceUpdateVisualWhenCnverted:** If set, full unit visual update will be enforced upon conversion.
    - **DisplaySocketPanel:** If set, socket panel will be displayed when unit is owned by GAIA.
    - **TeamKillBounty:** If set, kill bounties granted by destroying this unit will benefit the entire team.
    - **MinimapDisplayOnTop:** If set, this unit's minimap icon will always be forced to be displayed on top of all other units within its vicinity.
    - **NotRepairable:** Prevents this building from being repaired when set.
    - **KillSocketWhenDestroyed:** If set, unit socket will be removed upon destruction.
    - **TeamBuildLimit:** If set, build limit logic will account for unit count throughout all team players.
    - **IgnoreDefaultEjectTimeout:** If set, unit ejection action won't check, internally, for the default _unitAI_ eject delay, if _MeteredGarrison_ protoUnit flag is set.
    - **DoNotQueueEjectActions:** If set, alongside with the _MeteredGarrison_ protoUnit flag, allows multiple units to be ejected at the same time, even if they have ejection delays set.
    - **SharedGarrison:** If set, garrisoned units will be shared throughout all other instances of the current protoUnit, and of other protoUnits which have this flag set.
    - **DisplayMinimumRange:** If set, range decal will be based on the minimum attack range of the unit, rather than the maximum range.
    - **DoNotAllowAllowAlliedGarrison:** If set, allies won't be able to garrison within this unit.
    - **DetonationDeath:** If set, unit will trigger a predefined protoAction upon death, damaging all units around it.
    - **BuildingExtendedDeathAnim:** If set, building will use the same handling for death animations used by units.
    - **EnforceBigButtonUI:** If set, sots will be reserved for a Native-style BigButton, regardless of the current civ type.
    - **DeploymentUngarrison:** If set, units won't be able to be ungarrisoned manually, but only through a previously-set deployment ability/command.
    - **ForceDisplaySquadModes:** If set, squadmodes/tactics will be displayed for this unit, even if it's not of Military type.
    - **HideIfSocketedFoundationUntouched:** If set, socket will be hidden, if building placed upon it is currently an untouched foundation.
    - **DisplayMaxRangeOnSelection:** Defaults to false. If set, in case unit is set to display minimum range on hovering, maximum range will be displayed upon selection.
    - **DisplayRangeToEnemies:** Defaults to false. If set, range decal will be rendered for this unit, according to game settings, regardless of unit ownership.
    - **ChargeIdleAnim:** If set, once either the primary or secondary charged abilities of the unit are ready to be used, unit idle and bored animations will be replaced by the ones set within the protoAction of the charged ability, if valid. When set alongside with _ChargeMoveAnim_, walking and running anims will also be replaced, regardless of the current target of the unit.
    - **DoNotDamageTrees:** When set, _TruckAttack_ protoActions assigned to the unit will not damage trees.
    - **TacticArmorUseBaseIfNotSet:** If set, alongside with UseTacticArmorOverride, unit will use base armor values, if tactic armor overrides for the current tactic are set to 0.
    - **TransformPropagateChargeState:** If set, propagates charged action state when transforming unit through _DelayedTransform_ protoActions or _TransformUnit_ tech effects.
    - **HerdableForceOriginalResource:** If set, the original resource carried by a herdable unit will never be cleared out when gathering from any resource object.
    - **NativePreview:** When set over a Native Socket protoUnit, enables native/subciv preview mode while socket is still empty.
    - **SocketSubCivAlliance:** If set, civilization data _SubCivAllianceCost_ will be used for socket building command.

# ProtoActions (Tactics)

## Attributes

- **Legacy**
  - **DBAction:** Loads protoAction data from DB data set on the protoUnit. Despite being used, specifically for the BoatManager protoActions in ships, it's obsolete, and has no effect, unless if such data is explicitly defined.
  - **Name:** ProtoAction internal name. Takes one parameter, _StringID_, which sets the displayed string ID for that protoAction. String IDs set in this way will be displayed for every instance of this protoAction name, regardless of the protoUnit.
  - **Type:** Action type for this protoAction.
  - **MaxRange:** ProtoAction maximum range.
  - **MinRange:** ProtoAction minimum range.
  - **OptimalRange:** ProtoAction optimal range. Unused and seemingly overridden, internally, by maximum range.
  - **TypedMaxRange:** Maximum range specific to a particular unitType.

&lt;TypedMaxRange type="Huntable"&gt;10&lt;/TypedMaxRange&gt;

- - **TypedMinRange:** Minimum range specific to a particular unitType. Unused, but likely functional. Takes the same arguments as _TypedMaxRange_.
    - **TypedOptimalRange:** Optimal range specific to a particular unitType. Unused, and seemingly overridden by maximum range internally. Takes the same arguments as _TypedMaxRange_.
    - **ROF:** ProtoAction rate of fire. From _The African Royals_ AoE3DE DLC onwards, it can take two arguments, _type_ and _target_, which causes the rate of fire value to dynamically vary according to a particular variable. The behaviour of the rate of fire variation for every possible _type_ value is described as follows:
      - **_HitpointRatio_:** Rate of fire linearly decreases as the unit's hitpoint ratio decreases, converging to the _target_ value, as the hitpoint ratio is closer to 0:

&lt;ROF type='HitpointRatio' target='1.5'&gt;3.000000&lt;/ROF&gt;

- - - **_MinRange_:** Rate of fire linearly decreases as the unit distance to the target unit decreases, converging to the _target_ value, as the distance approaches the minimum range:

&lt;ROF type='MinRange' target='2.0'&gt;3.000000&lt;/ROF&gt;

- - **Rate:** ProtoAction work rate for a particular unitType. For action types that aren't work rate-based, work rate values define which unitTypes are valid attack targets (for attacking actions) or unitTypes that are processed by this particular action (for _Spawn_ and _Maintain_ action types).

For _AutoGather_ actions, defines which resource types are gathered. For _Gather_ actions, it can also take a _resource_ attributes, to restrict the work rate to gathering a particular

resource, for targets which support multiple resources (i.e. Rice Paddies and African Fields)

&lt;Rate type='Mill'&gt;0.670000&lt;/Rate&gt;

&lt;Rate type='ypRicePaddy' resource='Food'&gt;0.500000&lt;/Rate&gt;

From the original AoE3DE release onwards, it can receive the _yield_ attribute, which allows setting a resource yield value, controlling how much the resource lasts.

&lt;Rate type='Tree' yield='1.200000'&gt;0.500000&lt;/Rate&gt;

From the United States civilization AoE3DE release onwards, it can receive a _overrideResource_ attribute which, for _Gather_ actions, causes the deposited resource to be overridden by the set resource.

&lt;Rate type='AbstractFish' overrideResource='Gold'&gt;0.500000&lt;/Rate&gt;

From _The African Royals_ AoE3DE DLC onwards, it can be used for inverted auras (_LikeBonus_ with _ModifyRateByType_ flag set), it can be used to set the contribution rate to the stat bonus for every unitType that affects the target unit.

&lt;Rate type='LogicalTypeLandMilitary'&gt;0.02&lt;/Rate&gt;

From the _Mexican Civilization_ AoE3DE release onwards,it can receive a _inventoryRate_ attribute, which defines in which resources will be deposited into the unit's own resource inventory, while performing a gather action towards the player's stockpile.

&lt;Rate type='deHacienda' inventoryRate='1.0'&gt;1.000000&lt;/Rate&gt;

- - **Anim:** ProtoAction main animation.
    - **ReloadAnim:** ProtoAction reload animation, for attacking actions.
    - **IdleAnim:** ProtoAction idling animation.
    - **AnimationRate:** ProtoAction animation rate. Set, by default, to 1.0. For _Spawn_ actions without the _SingleUse_ protoAction flag set, it can be used to set the average spawning delay.
    - **Damage:** ProtoAction damage.
    - **DamageType:** ProtoAction damage type.
    - **DamageArea:** ProtoAction damage area radius. Despite it always being set as a floating point value, in legacy AoE3, it's internally stored as an unsigned short integer. From _The African Royals_ AoE3DE DLC onwards, it's properly stored as a floating point value.
    - **OuterDamageAreaDistance:** Defines the minimum distance from a target unit to the impact point of an area damage from which the _OuterDamageAreaFactor_ will be fully applied and, thus, the area damage factor applied over the unit will be greater than or equal to that attribute's value,
    - **OuterDamageAreaFactor:** Attribute used as a base for the calculation of the area damage factor. In case the distance between the target unit to the impact point of the

area damage is smaller than or equal to the _OuterDamageAreaDistance_ value, the calculation of the damageAreaFactor will be done according to the following formula:

𝑎𝑟𝑒𝑎𝐷𝑎𝑚𝑎𝑔𝑒𝐹𝑎𝑐𝑡𝑜𝑟 = 1 −

𝑢𝑛𝑖𝑡𝐷𝑖𝑠𝑡𝑎𝑛𝑐𝑒

𝑜𝑢𝑡𝑒𝑟𝐷𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝐷𝑖𝑠𝑡𝑎𝑛𝑐𝑒

(

)(1 − 𝑜𝑢𝑡𝑒𝑟𝐷𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝐹𝑎𝑐𝑡𝑜𝑟)

Otherwise, the formula to be used will be as follows:

𝑎𝑟𝑒𝑎𝐷𝑎𝑚𝑎𝑔𝑒𝐹𝑎𝑐𝑡𝑜𝑟 = ⎡1 − ( 𝑢𝑛𝑖𝑡𝐷𝑖𝑠𝑡𝑎𝑛𝑐𝑒 − 𝑜𝑢𝑡𝑒𝑟𝐷𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝐷𝑖𝑠𝑡𝑎𝑛𝑐𝑒 )⎤𝑜𝑢𝑡𝑒𝑟𝐷𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝐹𝑎𝑐𝑡𝑜𝑟

⎣ 𝑑𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝑅𝑎𝑑𝑖𝑢𝑠 − 𝑜𝑢𝑡𝑒𝑟𝐷𝑎𝑚𝑎𝑔𝑒𝐴𝑟𝑒𝑎𝐷𝑖𝑠𝑡𝑎𝑛𝑐𝑒 ⎦

- - **DamageCap:** Maximum amount of total damage that can be inflicted by an area attack.

For a protoAction that has critical damage type set to _KillingBlow_, sets the maximum amount of HP an unit can have to be a valid target of the critical attack.

- - **DamageFlags:** Defines which players are affected by area attack through a combination of the following flags: _GAIA_, _Self_, _Ally_ and _Enemy_.
    - **DamageBonus:** Defines a damage bonus for an attack action.
    - **~~RangedAttackMode:~~** ~~Unused and deprecated.~~
    - **Projectile:** ProtoAction projectile protoUnit.
    - **MaxHeight:** Maximum height for projectile.
    - **~~​ HeightBonusMultiplier:~~** ~~Unused and deprecated.~~
    - **NumberBounces:** Appears to define the maximum number of targets a single projectile can hit.
    - **ImpactEffect:** ProtoAction impact effects file, relative to the _Art_ folder.
    - **~~​ Turret:~~** ~~Attribute intended to be used by the AirCraft system. Unused and not functional~~ ~~in AoE3.~~
    - **Yield:** ProtoAction resource yield. Applied to all work rates over a _Gather_ action. In Legacy, for Indian Villagers, it's hardcoded to be only applied for wood gathering. Rendered deprecated from the AoE3DE original release onwards.
    - **Accuracy:** ProtoAction accuracy.
    - **HitPercent:** Defines the chance of the critical attack defined by _HitPercentType_ being triggered.
    - **DamageMultiplier:** Damage multiplier to be applied upon critical attack activation.
    - **HitPercentType:** Defines the type of critical attack to be used. Multiple flags can be set by using multiple entries. Changing this value through techs cause flags to be added, instead of replaced. The possible values for this attribute are listed as follows:
      - **_CriticalAttack_:** Multiplies total attack by _DamageMultiplier_ when triggered.
      - **_KillingBlow_:** Causes unit to be killed, if triggered when unit is below the _DamageCap_ value. As for AoE3DE original release onwards, it cannot affect Artillery or War Ships.
      - **_Sweep_:** Causes sweep attack to be performed upon triggered.
      - **_Disciple_:** Causes dead enemy to be converted into _ypMonkDisciple_ when triggered.
      - **_CriticalDisciple_:** Enables both sweep and Disciple conversion behaviours, using separate RNGs. Sweep won't be triggered, if unit doesn't have sweep attack defined.
    - **DamageFactorCap:** Damage multiplier limit for garrison bonus damage.
    - **TrackRating:** Rate in which a moving target is tracked. The higher the value, the better the accuracy is against moving targets.
    - **~~​ Timer:~~** ~~Unused and deprecated.~~
    - **AreaSortMode:** Defines how units in a target area of effect are sorted for a protoAction.
    - **ImpactForceMin:** Minimum force multiplier for ragdoll effect upon attack.
    - **ImpactForceMax:** Maximum force multiplier for ragdoll effect upon attack.
    - **ImpactLaunchAngle:** Launch angle for ragdoll effect upon attack.
    - **ModifyType:** Modify type for _AutoRangedModify_, _LikeBonus_ and _DanceBonus_ with

_UnitModification_ dance type.

- - **ModifyProtoPower:** ProtoPower/Ability name of the power/ability to be affected by the _AbilityROF_ modifyType. Unused, but likely functional. Does not affect protoPowers/abilities with global cooldown.
    - **ModifyMultiplier:** For _AutoRangedModify_ actions, defines the multiplier to be used for the bonus to be applied by the aura. For _DanceBonus_ and _LikeBonus_ actions, defines the multiplier value used in the bonus factor calculation. For inverted aura actions (_LikeBonus_ with _ModifyRateByType_ flag set), available from _The African Royals_ AoE3DE DLC onwards, this attribute is unused.
    - **ModifyExponent:** For _DanceBonus_ and _LikeBonus_ actions, defines the exponent value used in the bonus factor calculation. For inverted aura actions, available from _The African Royals_ AoE3DE DLC onwards, this attribute is unused.

The calculation of the modifier factor for _LikeBonus_ and _DanceBonus_ is done using the following formula, if _ModifyExponent_ is set to a positive value:

𝑛𝑢𝑚𝑈𝑛𝑖𝑡𝑠

𝑓𝑎𝑐𝑡𝑜𝑟 = (𝑚𝑢𝑙𝑡𝑖𝑝𝑙𝑖𝑒𝑟)(𝑛𝑢𝑚𝑈𝑛𝑖𝑡𝑠) + 𝑒𝑥𝑝𝑜𝑛𝑒𝑛𝑡 − 1 + 𝑏𝑎𝑠𝑒

Otherwise

(−1)(𝑒𝑥𝑝𝑜𝑛𝑒𝑛𝑡)

𝑓𝑎𝑐𝑡𝑜𝑟 = (𝑚𝑢𝑙𝑡𝑖𝑝𝑙𝑖𝑒𝑟)(𝑛𝑢𝑚𝑈𝑛𝑖𝑡𝑠) + 𝑛𝑢𝑚𝑈𝑛𝑖𝑡𝑠 − 1 + 𝑏𝑎𝑠𝑒

- - **ModifyBase:** For _DanceBonus_ and _LikeBonus_ actions, defines the base value used in the bonus factor calculation. For inverted aura actions, available from _The African Royals_ AoE3DE DLC onwards, this attribute is unused.
    - **ModifyAbstractType:** Defines the unitType to be affected by the aura, for _AutoRangedModify_ actions; or by the Community Plaza/Fire Pit bonus, for _DanceBonus_ actions.
    - **ModifyProtoID:** Defines the protoUnit to be affected by the aura, for _AutoRangedModify_

actions; or by the Community Plaza/Fire Pit bonus, for _DanceBonus_ actions.

- - **DanceBonusType:** Bonus type for _DanceBonus_ actions. The valid types are _Training_, _XPTrickle_, _UnitModification_, _UnitSpawn_, _Regeneration_, _PopCap_, _WarChiefRansom_ and _Gathering_. As of AoE3DE original release, the _AutoGathering_ type is also available.
    - **ModelAttachment:** Attachment to be used by aura/_AutoRangedModify_ actions, relative to the _Art_ folder.
    - **ModelAttachmentBone:** Bone where _ModelAttachment_ is supposed to be attached to. Should be either a valid bone name, omitting the _bone__ prefix, or _bonethatdoesntexist_.

## Definitive Edition

- - **ScaleByContainedUnitType:** Defines separate rates by which every unit type contributes to garrison bonus.

&lt;ScaleByVontainedUnitType&gt;

&lt;Rate type='Military'&gt;0.101&lt;/Rate&gt;

&lt;/ScaleByVontainedUnitType&gt;

- - **ForbidAbstractType:** Defines unitTypes that cannot be affected by an

_AutoRangedModify_ action.

- - **ForbidUnitType:** Defines unitTypes that cannot be affected by an _AutoRangedModify_

action.

- - **AttachProtoUnit:** ProtoUnit to be attached to target upon attack.
    - **ModifyResource:** Resource to be produced by _DanceBonus_ action with _DanceType_ set to _AutoGathering_.
    - **ConversionDelay:** Delay time in seconds for conversion of target unit through a _Convert_

action. Affected by _ConversionResistance_ protoUnit attribute and action work rate.

- - **ModifyAmount:** Modification value used by modify types which perform changes linearly.
    - **ModifyTargetLimit:** Maximum number of units that can be affected by an aura, for _AutoRangedModify_ actions, or to be accounted for the total bonus calculation, for default _LikeBonus_ actions.
    - **DisplayedNumberProjectiles:** Displayed number of projectiles in the UI for this protoAction.
    - **CastPower:** Defines a protoPower to be cast once action is performed. Restricted to non-Broadside charged attack actions.
    - **CastPowerTargetType:** Defines the target type for the protoPower to be casted. The possible values for this attribute are listed as follows:
      - **_self_:** Casts the power over the attacker unit.
      - **_unit_:** Casts the power over the target unit
      - **_area_:** Casts the power over the vicinity of the target unit, taking its position as a reference point.
    - **DisplayNameID:** String ID for protoAction displayed name. Overrides default name and doesn't affect other instances of this protoAction.
    - **CivType:** Restricts action functionality to a specific _civType_.
    - **FullCapacityMultiplier:** Work rate multiplier to be applied for an _AutoGather_ action when unit is at its full resource capacity.
    - **ModifyDuration:** Duration/lifespan time in milliseconds for _AutoRangedModify_ action.
    - **GatheringMultiplier:** Work rate multiplier to be applied for an _AutoGather_ action when unit is performing a gathering action.
    - **MaintainWorkRateMultiplier:** Work rate multiplier to be applied to a _Maintain_ action.
    - **ModifyRateCap:** Bonus factor limit for inverted aura actions (_LikeBonus_ with

_ModifyRateByType_ flag set).

- - **EmpowerData:** Data to be used for _Empower_ actions targeted to units belonging to the player. For every unitType entry, the following attributes can be set:
        - **_Active_:** Defines whether or not a particular _EmpowerData_ entry is active. Set by default.
        - **_ForbidUnitType_:** Defines unitTypes that are forbidden from being affected by empowerment.
        - **_Anim_:** Animation to be used for empowering.
        - **_EmpowerArea_:** Area of effect for empowerment.
        - **_EmpowerRate_:** Defines the empowerment rate for a particular _modifyType_.
        - **_ModelAttachment_:** Similar functionality as of ProtoAction attribute.
        - **_ModelAttachmentBone_:** Similar functionality as of ProtoAction attribute.

&lt;EmpowerData&gt;

&lt;Building&gt;

&lt;ForbidUnitType&gt;MinedResource&lt;/ForbidUnitType&gt;

&lt;EmpowerRate modifyType="BuildRate"&gt;1.75&lt;/EmpowerRate&gt;

&lt;EmpowerRate modifyType="BuildingWorkRate"&gt;1.5&lt;/EmpowerRate&gt;

&lt;/Building&gt;

&lt;/EmpowerData&gt;

- - **EnemyEmpowerData:** Data to be used for _Empower_ actions targeted to units belonging to an enemy. Accepts the same attributes as _EmpowerData_.

&lt;EnemyEmpowerData&gt;

&lt;Military&gt;

&lt;Anim&gt;EmpowerEnemy&lt;/Anim&gt;

&lt;EmpowerArea&gt;1.0&lt;/EmpowerArea&gt;

&lt;EmpowerRate modifyType="ROF"&gt;2.0&lt;/EmpowerRate&gt;

&lt;EmpowerRate modifyType="HealRate"&gt;-2.0&lt;/EmpowerRate&gt;

&lt;ModelAttachment&gt;units\\attachments\\stun_stars.xml&lt;/ModelAttachment&gt;

&lt;ModelAttachmentBone&gt;bonethatdoesntexist&lt;/ModelAttachmentBone&gt;

&lt;/Military&gt;

&lt;/EnemyEmpowerData&gt;

- - **GAIAEmpowerData:** Data to be used for _Empower_ actions targeted to units belonging to Gaia. Accepts the same attributes as _EmpowerData_.

&lt;GAIAEmpowerData&gt;

&lt;AbstractMine&gt;

&lt;Anim&gt;DanceActive&lt;/Anim&gt;

&lt;EmpowerRate modifyType="ResourceGatherRate"&gt;1.1&lt;/EmpowerRate&gt;

&lt;EmpowerRate modifyType="ResourceYield"&gt;1.25&lt;/EmpowerRate&gt;

&lt;ModelAttachment&gt;effects\\ypack_auras\\torpgatherpower.xml&lt;/ModelAttachment&gt;

&lt;ModelAttachmentBone&gt;bonethatdoesntexist&lt;/ModelAttachmentBone&gt;

&lt;/AbstractMine&gt;

&lt;/GAIAEmpowerData&gt;

- - **DoNotAutoGatherUnlessGatheringTypes:** Restricts the activation of a particular _AutoGather_ action to unit gathering from a resource type belonging to any of the listed types.

&lt;DoNotAutoGatherUnlessGatheringTypes&gt;

&lt;UnitType&gt;AbstractField&lt;/UnitType&gt;

&lt;UnitType&gt;Mill&lt;/UnitType&gt;

&lt;UnitType&gt;ypRicePaddy&lt;/UnitType&gt;

&lt;UnitType&gt;Farm&lt;/UnitType&gt;

&lt;/DoNotAutoGatherUnlessGatheringTypes&gt;

- - **CannonLimit:** Number of cannons to be used by a _BroadsideAttack_ action. Defaults to using the predefined number of cannons within the unit's model, up to a limit of 6.
    - **MaintainTrainPoints:** Unit train points to be used for _Maintain_ action, instead of the default amount of train points set in the protoUnit data. As of the _Mexican Civilization_ release of AoE3DE, this attribute can be also applied to _DanceBonus_ protoActions of _UnitSpawn_ type.
    - **StunDuration:** Stun duration for non-standard _StunAttack_ protoActions.
    - **StunSoundSet:** Soundset for non-standard _StunAttack_ protoActions.
    - **AutoStealthDelay:** Minimum delay in which auto-stealth can be re-activated, after unit is discovered.
    - **AutoStealthLifespan:** Lifespan for auto-stealth action.
    - **FlagOverrideUnit:** ProtoUnit that holds the flag to be applied for unit modification of

_PeaceFlag_ type.

- - **SelfDamageMultiplier:** Percentage of damage to be reflected back to attacker when a critical attack of _CriticalAttack_ type is triggered.
    - **HitPercentSoundSet:** Soundset to be used when a critical attack of _CriticalAttack_ type is triggered.
    - **WalkAnim:** ProtoAction-specific movement animation.
    - **JogAnim:** ProtoAction-specific jog animation
    - **RunAnim:** ProtoAction-specific running animation.
    - **BoredAnim:** ProtoAction-specific bored animation.
    - **FreeBuildRate:** Defines work rate for free building through _AbstractFreeBuilder_ units for a particular unit type. Takes the same basic attributes of _WorkRate_, except for the ones specific to gathering actions.
    - **InvestmentResource:** For _AutoGather_ actions, defines which resource from the investment pool will be deducted while the resource trickle is active.
    - **SubCiv:** Restricts the current action to only be active in case the unit is linked to the set subCiv.
    - **DirectionalDamageRefAngle:** Reference angle in radians for directional damage target selection.
    - **MinTimeBetweenMultiAttacks:** For Roundel Attack actions, defines the minimum interval between two consecutive attacks done to separate targets.
    - **SubCivType:** Restricts the current action to only be active in case the unit is linked to a subCiv belonging to the given _subCivType_.
    - **TypedAnim:** For _Gather_ protoActions, overrides the animation to be used for gathering from a given target unitType. Takes one parameter, _unitType_, which defines the target unit type for which the given animation will be used while gathering.

## Flags

- **Legacy**
  - **AttackAction:** Sets protoAction as a valid attack action.
  - **Active:** Sets protoAction as active.

### ActiveIfContainsUnits

- - **ScaleByContainedUnits:** Scales attack according to the amount of garrisoned units.

Shouldn't be set if protoAction is supposed to use _ScaleByContainedUnitType_.

- - **HandLogic:** Defines protoAction as a hand attack action.
    - **RangedLogic:** Defines protoAction as a ranged attack action.
    - **SpeedBoost:** Causes unit speed to be boosted by a predefined factor upon attacking.
    - **TargetSpeedBoost:** Causes target unit speed to be hindered by a predefined factor upon attacking.
    - **Persistent:** Causes protoAction to be persistently processed.
    - **~~​ UseBuckets:~~** ~~Unused and Deprecated. Likely not intended for AoE3.~~
    - **AddResourcesToInventory:** If set, _AutoGather_ action will deposit resources within unit's inventory, instead of the player's stockpile.

### AddResourcesFasterWhenOwned

- - **SingleUse:** Causes protoAction to be useable only once. Only valid for _AutoGather_, _Build_, _Maintain_, _Spawn_ and _Attaching_.
    - **SingleUsePlayer:** For _BroadsideAttack_, causes attack to only use one single cannon. For _Spawn_, causes protoAction to be effectively deactivated, preventing other instances of this unit from using it. As of the _Mexican Civilization_ AoE3DE release onwards, such behaviour persists to saved and recorded games.
    - **YearBased:** Causes the number of spawned units by a _Spawn_ action to vary by a factor of the current game Year. Unused, but functional.
    - **Throw:** Causes units to be 'thrown' upon dying by an attack performed by this protoAction.
    - **InitialROF:** Requires unit to reload before performing the first attack. Unused, but likely functional.
    - **Linear:** For _Maintain_ actions, causes the number of produced units to be incremented by one at each iteration. The maximum number of units that can be produced in a iteration is capped by the work rate value.
    - **NoCost:** Causes manually set _AutoRepair_ protoActions to not cost resources. Unused, but likely functional.
    - **BaseDamageCap:** Causes area attack actions to not account for damage bonuses for damage cap checking.
    - **DropsiteGathering:** Enables dropsite gathering for gathering actions.
    - **TargetGround:** Causes ranged actions to use the ground position of the unit as a reference for targeting.
    - **InstantBallistics:** Causes projectiles to travel instantly, instead of at their movement speed.
    - **SelfDestruct:** Causes unit to self-destruct upon attacking.
    - **~~​ PerimeterWallCheck:~~** ~~Attribute intended to be used by the AirCraft system. Unused and~~ ~~not functional in AoE3.~~
    - **PerfectAccuracy:** Causes ranged attack to be fully accurate on non-moving targets.
    - **PhysicsOnSelfDestruct:** Use physics to throw unit if it protoAction has self destruct flag set.
    - **ChargeAction:** Sets this protoAction as a charged attack action.
    - **ShowQueueWhileWaiting:** If set, _Maintain_ actions will be shown in both the unit queue and the global game queue, if they are on waiting state. Set to 1 by default.
    - **DoNotAutoGatherUnlessGathering:** If set, it will cause the _AutoGather_ action to not generate resources if unit isn't performing a gathering action.
    - **TargetEnemy:** Causes an _AutoRangedModify_ action to affect only enemy units.
    - **ModifyExclusive:** Causes other _AutoRangedModify_ actions sharing the same modifyType to not be processed.

## Definitive Edition

- - **ExcludeFromRangeIndicator:** Excludes action from being processed for range decal displaying.
    - **~~​ CastWhenAnimationFinished:~~** ~~Deprecated.~~
    - **UnrandomizeCannonROF:** Forces Cannon shots to use the ROF set in the protoAction, without random variations.
    - **TargetGaia:** Causes an _AutoRangedModify_ action to affect only Gaia units.
    - **DoNotIgnoreDead:** Causes an _AutoRangedModify_ action to also affect dead units.
    - **DeadExclusive:** Restrict an _AutoRangedModify_ action to only affect dead units.
    - **SingleUnit:** Causes an _AutoRangedModify_ action to only affect a single target.
    - **IncludeGaia:** Causes an _AutoRangedModify_ action to affect Gaia units, besides of player units.
    - **HideFromStats:** Hides protoAction from unit stats.
    - **ForceUpdateMode:** Forces units affected by an AutoRangedModify action set to not persistently update (i.e. with the _StartOnNoUpdate_ protoUnit flag set) to full update state, allowing them to be properly affected by auras.
    - **ModifySelf:** Causes _AutoRangedModify_ and _LikeBonus_ actions to affect the source unit.
    - **AuxChargeAction:** Sets this protoAction as a secondary charged attack action.
    - **CannotBeConvertedByAllies:** Prevents an _AutoConvert_ action from causing a friendly player from capturing the unit.
    - **TargetUnbuilt:** Restricts an _AutoRangedModify_ action to only affect targets which aren't fully built (i.e. building foundations and buildings under construction).
    - **RestrictToNativeSettlements:** Restricts an _AutoGather_ action to be only functional when the building is socketed over a Native Settlement.
    - **TargetEnemyIncludeGaia:** Causes an _AutoRangedModify_ action to affect only enemy or gaia units.
    - **NoStack:** Prevents more than one instance of an _AutoRangedModify_ action of the same source unit from affecting the same target unit, while still allowing it to be affected by other _AutoRangedModify_ actions set to the same modifyType.
    - **SquareAura:** Causes the area of effect of an _AutoRangedModify_ action to be a square, instead of circular.
    - **GatherLinkedResource:** Causes a _ResourceProxy_ action to account only for socketed resources, if any.
    - **DontKillWhenExpired:** Prevents a _ResourceProxy_ action from triggering unit death upon resource depletion.
    - **RestrictToGatherers:** Restricts an _AutoRangedModify_ action to only affect units gathering from the source unit.
    - **HealNonIdle:** Allows a _Heal_ action to heal non-idle units.
    - **UseHCGatherPoint:** Causes units produced by a _Maintain_ action to be delivered at the HC drop-off point.
    - **IncludeAlly:** Causes an _AutoRangedModify_ action to affect allied units, besides of player units.
    - **ModifyRateByType:** Causes a _LikeBonus_ protoAction to have inverted aura behaviour, making nearby units within the area defined by _MaxRange_ of the unitType defined in _ModifyAbstractType_ to contribute to the bonus applied to the source unit by rates defined through the _WorkRate_ entries.
    - **RestrictToKnockout:** Causes a _Maintain_ action to only be active when an unit is in knocked out state. As of the _Mexican Civilization_ AoE3DE release onwards, it can also be used in _Spawn_ actions, which causes, if used alongside with the _SingleUse_ flag, the unit spawning to be triggered every time the unit enters knockout state.
    - **ModifySingleActionByType:** Causes _AutoRangedModifyAction_ to not target an unit if it's already affected by another action set to the same _ModifyType_.
    - **NoStackIgnorePUID:** When set alongside with _NoStack_, also prevents instances of the protoAction from other protoUnits from affecting the same target unit.
    - **AutoGatherScaleByGatherRate:** Causes _AutoGather_ rate to be affected by the current gather rate of the unit.
    - **SpawnIgnoreBuildLimit:** Causes a _Spawn_ action to spawn units, regardless of build limit.
    - **DoNotAutoGatherIfSocketed:** Prevents an _AutoGather_ action from generating resources if building is placed over a socket.
    - **HandAttackDisplayRange:** Forces the range to be displayed for a hand attack protoAction.
    - **AttachForceDieWithUnit:** When in an _Attaching_ action, causes an unit without lifespan set attached to an enemy unit to be forcibly removed once the unit dies.
    - **AutoGatherInventoryIfNotSocketed:** Causes an _AutoGather_ action with the _GatherLinkedResource_ flag set to gather from the unit's own inventory, if it's not currently socketed.
    - **DisableAutoAttack:** For protoActions of _AutoStealth_ type, disables auto-attacking while the action is active.
    - **RestrictToIdleUnits:** Restricts an _AutoRangedModify_ action to only affect units that are currently idle.
    - **RestrictToValidRepairTargets:** Restricts an _AutoRangedModify_ action to only affect units that are valid targets for the Repair command.
    - **KeepAlive:** Forces a single-use _Maintain_ or _Spawn_ action to be kept alive, internally, preventing it from being re-triggered, in case persistent actions are reloaded through tactic switching.
    - **ModifyRangeUseLOS:** Causes an _AutoRangedModify_ action to use the current unit's LOS as its effective range.
    - **AttachValidTargetOnly:** Causes _AttachProtoUnits_ to only be spawned when the attack action has properly targeted a living valid target.
    - **AddGathererContribution:** Causes the displayed gathering rate for an _AutoGather_ action to also account for the total gathering rate of all units gathering from the current unit, if the _GatherersContributeToResourceRate_ protoUnit flag is set.
    - **DepositToGatherSiteOwner:** Causes a _Gather_ action to deposit resources to the gather site owner, instead of the current owner of the gatherer unit.
    - **RestrictToFullCapacityGatherers:** Restricts an _AutoRangedModify_ action to only affect units gathering from the source unit that have a full resource inventory.
    - **SpawnOnAnimationLoop:** For _Spawn_ protoActions,causes spawning to be performed once the current unit animation ends.
    - **DestroyUnitAfterUse:** For _Spawn_ protoActions, causes source unit to be killed after spawning action is performed when used alongside with the _SpawnOnAnimationLoop_ protoAction flag.
    - **ModifySelfOnly:** Restricts an _AutoRangedModify_ protoAction to only affect the current unit.
    - **FirstTC:** Restricts an _AutoRangedModify_ protoAction to only be active if the current unit is the first TC for the current player.
    - **ActiveIfGaia:** Causes the current action to be only active if unit belongs to Gaia.
    - **ActiveIfNotGaia:** Causes the current action to be only active if unit belongs to an actual non-Gaia player.
    - **AutoGatherTeam:** For _AutoGather_ actions, causes the resource trickle to benefit all players within the team, instead of just the owner of the unit.
    - **CannotBeConvertedByEnemies:** Prevents an _AutoConvert_ action from causing an enemy player to capture the unit.
    - **ForceSpawn:** Forces a _UnitSpawn_ action to be processed, and executed if/when applicable, by the game, in case it's assigned to a starting unit or building.
    - **ConvertToGaiaIfForbidden:** For _AutoConvert_ actions, causes unit to be converted to Gaia, in case it's captured by a player who has been is forbidden from capturing the current unit through scenario or RM triggers.
    - **NotActiveOnTreaty:** Sets the current action as inactive while the game is under a Treaty period.
    - **IncludeEnemy:** For inverted aura actions (_LikeBonus_ with _ModifyRateByType_ flag set), causes valid Enemy units to be accounted for modifier calculation.
    - **DirectionalDamage:** Sets an _Attack_ action with area of damage attack to inflict directional damage, instead of traditional area damage.
    - **TargetLock:** For _Attack_ actions, causes the unit to maintain its current target while it's under its LOS, even if it's outside the set maximum rage for the current action.
    - **BuildLimitSuspend:** For _Maintain_ actions, causes the action to suspend and save progress, in case build limit has been reached, instead of resetting it.
    - **DoesMultiAttack:** For Roundel Attack actions, allows the action to attack multiple targets at the same time when set.
    - **AutoGatherIfResourcesInvested:** Causes an _AutoGather_ action to only actually produce resources if player has at least one resource deposited as an investment.
    - **ShortConversionDelay:** Reduces action refreshing delay for an _AutoConvert_

protoAction.

## Modify Types

- **Legacy**
  - **Speed:** Unit maximum speed.
  - **MaxHP:** Unit maximum hit points.
  - **Damage:** Unit damage.
  - **~~​ MovingDamage:~~** ~~Unused and deprecated.~~
  - **SiegeDamage:** Unit siege damage. Affects, specifically, the damage inflicted against buildings and ships, and not necessarily all protoActions with the damageType set to _Siege_.
  - **Bounty:** Kill bounty obtained by affected units.
  - **UnitDamage:** Damage inflicted against units (as in non-buildings and non-ships).
  - **~~​ LOS:~~** ~~Line of Sight. Functional, but causes unit LOS to glitch after being applied.~~
  - **Armor:** SquadMode armor bonus. Not functional for units which aren't using a tactic/squadMode that enforces armor bonuses.
  - **GatherRate:** Gather rate for all resources.
  - **AbilityROF:** ProtoPower cooldown time for power set in _ModifyProtoPower_. Does not affect protoPowers with global cooldown.
  - **ROF:** Unit rate of fire.
  - **AutoGatherRate:** AutoGather rate for all actions.

## Definitive Edition

- - **UnitResource:** Consumes resource inventory for natural resources at a linear rate, based on the _ModifyAmount_ attribute value.
    - **BaseHP:** Unit hit points, applied over base protoUnit hitpoints, instead of the current value.
    - **BuildingWorkRate:** Building Work Rate.
    - **BuildRate:** Affects Building construction rate when affecting builders. Affects auto-building rate when affecting foundations placed by wagons.
    - **Chaos:** Enables Chaos behaviour on affected units.
    - **FarmingGatherRate:** Gather rate for farm objects (_AbstractFarm_ unitType).
    - **InfluenceRate:** Rate in which resources gathered by affected units will be converted into Influence.
    - **HealRate:** Linear heal rate, or progressive damage, if set as a negative value. For buildings, hit points addition/subtraction will be percentage-based.
    - **AutoGatherAbsolute:** AutoGather rate for all actions with a rate greater than zero. Adds to the AutoGather rate linearly, instead of multiplying.
    - **RepairCost:** Building repair cost.
    - **TrainingRate:** Building unit training rate.
    - **EconomicTrainingRate:** Building economic unit training rate.
    - **MilitaryTrainingRate:** Building military unit training rate.
    - **ResearchRate:** Building technology researching rate.
    - **ResourceGatherRate:** Resource gathering rate multiplier for gatherers gathering from the affected unit.
    - **ResourceYield:** Resource yield rate multiplier for gatherers gathering from the affected unit.
    - **NaturalFoodGatherRate:** Gather rate for natural food sources (targets with Food as their main resource and either _Nature_ or _NatureClass_ types set).
    - **TreeGatherRate:** Gather rate for trees.
    - **MineGatherRate:** Gather rate for mines (_MinedResource_ unitType).
    - **AutoBuildRate:** Auto-building rate for foundations placed by wagons.
    - **PeaceFlag:** Causes affected units to be perceived as friendly units by enemies, preventing them from being attacked by enemy units and vice-versa. If the affected units support civilization flag displaying, the flag will be replaced by the flag set in the _CivFlagOverride_ attribute of the protoUnit defined through the _FlagOverrideUnit_ protoAction attribute, if it's set to a valid value.
    - **BaseDamage:** Unit damage, applied over base protoUnit damage, instead of the current value.
    - **BuildBounty:** Building build bounty. Does not affect resources other than XP.
    - **RechargeTime:** Charged action recharge time. Affects both main and auxiliary recharge times.
    - **Range:** Maximum range.
    - **RangeAbsolute:** Maximum range. Adds linearly, instead of multiplying.
    - **Shield:** Redirects damage received by targeted units by the rate defined in

_ModifyMultiplier_. For units affected by multiple _Shield_ auras,

- - **BaseSpeed:** Unit maximum speed, applied over base protoUnit value.
    - **UnitRegenRate:** Unit regeneration rate defined through protoUnit or civilization data.

# Tactic Data

## Legacy

- - **Active:** Defines whether the tactic is active or not. Set to 1 (Active) by default.
    - **Action:** Adds a valid action for this tactic. Takes one attribute, _priority_, which defines choice priority for attack actions.
    - **CheckIfCanStealth:** Forces Stealth check to be performed before switching to this tactic. Takes one attribute, _range_, which defines the range in which it checks for enemy units within the vicinity of the unit that can forbid switching to a Stealth tactic.
    - **SpeedModifier:** Modifier to be applied to unit movement speed after switching to the current tactic.
    - **MaxHPModifier:** Modifier to be applied to unit hitpoints after switching to the current tactic.
    - **DamageModifier:** Modifier to be applied to unit damage after switching to the current tactic.
    - **~~​ MovingDamageModifier:~~** ~~Modifier intended to be applied to unit moving damage after~~ ~~switching to the current tactic. Deprecated, as it depends on non-functional modify type~~ _~~MovingDamage~~_~~.~~
    - **SiegeDamageModifier:** Modifier to be applied to unit siege damage after switching to the current tactic.
    - **UnitDamageModifier:** Modifier to be applied to unit damage against living targets (as in non-buildings and non-ships) after switching to the current tactic.
    - **~~​ UnitType:~~** ~~Intended to restrict the current tactic to a particular unit type. Superseded by~~ ~~SquadMode restriction to specific unit types.~~
    - **TooltipStringID:** String ID for world tooltip to be rendered over unit when switching to this tactic. Likely intended for internal Ensemble testing or an unknown tutorial mode.
    - **AttackType:** Unit type that defines valid attack targets.
    - **AutoAttackType:** Unit type that defines valid auto-attack targets. If not set, auto-attack will be disabled for the current tactic.
    - **AttackResponseType:** Unit type that defines valid retaliation targets.
    - **RunAway:** If set, enables running away behaviour.
    - **AutoRetarget:** If set, units will look for other targets automatically, if current attack target becomes invalid
    - **~~​ Exclusive:~~** ~~Deprecated. Original purpose unknown. Possibly intended to allow certain~~ ~~tactics to be simultaneously activated, when unset?~~
    - **~~​ MoveAttack:~~** ~~Deprecated. Apparently intended to allow Tactic to support simultaneous~~ ~~moving and attacking actions.~~
    - **ModelAttachment:** Model Attachment animfile to be applied over unit when switching to this tactic. Only applied if _ModelAttachmentBone_ is set to a valid bone.
    - **ModelAttachmentBone:** Bone where _ModelAttachment_ is supposed to be attached to.

Must be a valid bone name, omitting the _bone__ prefix.

- - **AgeRequirement:** Minimum age required for this tactic to be available. Set as an integer value.
    - **FireType:** Fire particle type to be rendered over unit when switching to this tactic (_Economic_, _Military_)
    - **ProtoUnitCommand:** ProtoUnitCommand linked to this tactic. Used for fetching HUD tactic icon and rollover for buildings that display tactics on the game HUD.
    - **Transition:** Defines transition data between the current tactic and a target tactic. For units, can be used to define a limber animation. For buildings, it's required in order to allow proper tactic switching. Takes the following parameters, which should be defined as XML children elements:
      - **_Tactic_:** Target Tactic.
      - **_~~​ Action~~_~~:~~** ~~Deprecated.~~
      - **_Anim_:** Transition animation.
      - **_Length_:** Transition length.
      - **_~~​ Enter~~_~~:~~** ~~Deprecated. Likely leftover of a primitive limbering system with separate~~ ~~entering and exiting modes.~~
      - **_Exit_:** Should be set to 1 for this to be a valid transition.
      - **_Automatic_:** If set, unit will transition automatically to tactic if it's required to perform an action that's only available in the target tactic.
      - **_CommandAutomatic_:** Allows automatic tactic transition, if required by a Game Command, in case _Automatic_ is not set.
      - **_LandOnly_:** If set, tactic transition will be forbidden if unit is on water.
    - **IdleAnim:** Idle animation for current tactic.
    - **BoredAnim:** Bored animation for current tactic.
    - **DeathAnim:** Death animation for current tactic.
    - **WalkAnim:** Movement animation for current tactic.
    - **MoveAnim:** Movement animation for current tactic.
    - **JogAnim:** Jog animation for current tactic.
    - **RunAnim:** Running animation for current tactic.

## Definitive Edition

- - **FakePortraitIcon:** Decoy portrait icon to be displayed to enemies when tactic is set.

Requires _DisplayDecoyInfo_ protoUnit flag to be set for proper functionality.

- - **FakeDisplayNameID:** Decoy unit name string to be displayed to enemies when tactic is set. Requires _DisplayDecoyInfo_ protoUnit flag to be set for proper functionality.
    - **FakeRolloverTextID:** Decoy unit long rollover string to be displayed to enemies when tactic is set. Requires _DisplayDecoyInfo_ protoUnit flag to be set for proper functionality.
    - **FakeShortRolloverTextID:** Decoy unit short rollover string to be displayed to enemies when tactic is set. Requires _DisplayDecoyInfo_ protoUnit flag to be set for proper functionality.
    - **ArmorOverride:** Armor override value to be used when this tactic is set. Takes two attributes, _type_ and _value_, which define, respectively, the armor type and armor value for the override. Requires _UseTacticArmorOverride_ protoUnit flag to be set for proper functionality. When using this system, separate armor values will need to be defined for each tactic. As of _Knights of the Mediterranean_ AoE3 DLC onwards, if protoUnit flag _TacticArmorUseBaseIfNotSet_, unit will fall back to default armor values from protoUnit data for each damage type not set in the tactic override.
    - **RolloverStringID:** String ID for tactic rollover. Overrides rollover for squadMode linked to tactic.
    - **ActiveIcon:** WPF path, relative to _Data\\wpfg_, to the icon to be displayed when tactic is selected. Overrides icon set for squadMode linked to tactic.
    - **AvailableIcon:** WPF path, relative to _Data\\wpfg_, to the icon to be displayed when tactic is available, but not selected. Overrides icon set for squadMode linked to tactic.
    - **UnavailableIcon:** WPF path, relative to _Data\\wpfg_, to the icon to be displayed when tactic is currently unavailable, due to being forbidden by a protoPower currently active. Overrides icon set for squadMode linked to tactic.
    - **AttackPriorityType:** Denotes an unit type which will receive an additional bonus attack prioritization factor when this tactic is active. Takes one attribute, _bonusFactor_, which defines the bonus value to be added to the attack prioritization factor.

&lt;AttackPriorityType bonusFactor="50.00"&gt;AbstractInfantry&lt;/AttackPriorityType&gt;

# ProtoUnitCommands (protounitcommands.xml)

## Legacy

- - **Name:** ProtoUnitCommand internal name.
    - **Command:** Console command to be executed.
    - **CommandPassesUnitID:** If present, first integer printf parameter on command will be replaced by the internal ID of the current unit.
    - **Icon:** ProtoUnitCommand icon path.
    - **ActiveIcon:** For ProtoUnitCommands linked to Building Tactics, defines the icon to be displayed when the tactic is currently active.
    - **DisabledIcon:** For ProtoUnitCommands linked to Building Tactics, defines the icon to be displayed when the tactic cannot be currently selected, either because the Building is currently switching to another tactic. Usually set to the same path as the default _Icon_.
    - **AssociatedTech:** Technology associated with the protoUnitCommand, defining command availability, cost and research time.
    - **UseMultiple:** If present in a protoUnitCommand associated with a particular technology, it will allow the protoUnitCommand to be executed multiple times.
    - **PrereqCommand:** Binds the availability of this command on the previous execution of the given protoUnitCommand.
    - **RolloverTextID:** String ID for default protoUnitCommand rollover.
    - **ActiveRolloverTextID:** For ProtoUnitCommands linked to Building Tactics, defines the rollover to be displayed when the tactic is currently active.
    - **DisabledRolloverTextID:** String ID for protoUnitCommand rollover to be displayed when command cannot be currently issued, despite it's being currently shown.
    - **ValueText:** Value text to be displayed over protoUnitCommand icon.
    - **~~​ HelpTopic:~~** ~~Deprecated.~~
    - **~~​ CloseMenu:~~** ~~Deprecated.~~

## Definitive Edition

- - **~~​ DBID:~~** ~~Deprecated~~
    - **AssociatedPower:** Associates the protoUnitCommand with the given protoPower, causing it to share cooldown with the protoPower.
    - **ForbidTech:** Technology to be temporarily forbidden while this protoUnitCommand is being researched, if it's associated with a technology.
    - **SpawnCommand:** Causes protoUnitCommand to spawn units once executed. Requires the protoUnitCommand to be associated with a technology for proper functionality.
    - **UnitType:** ProtoUnit to be spawned, if _SpawnCommand_ is set.
    - **Amount:** Amount of units to be spawned, if _SpawnCommand_ is set.
    - **CastPower:** Causes protoUnitCommand to cast _AssociatedPower_.
    - **SubCiv:** Restricts the protoUnitCommand to be only displayed and usable if building is on a socket belonging to the given SubCiv.
    - **BindToChargeAction:** Binds the protoUnitCommand to the main Charged Action, causing it to be non-executable and to display the cooldown of the main Charged Action.
    - **DoNotAllowOverPopLimit:** Forbids the command from being executed if player is above the population limit.
    - **DoNotAllowIfUnitDamaged:** Forbids the command from being executed if current unit is damaged.
    - **UseBigButton:** If present, causes protoUnitCommand to use Native Big Button.
    - **UseBigHugeButton:** If present, causes protoUnitCommand to use Big Huge/Consulate option button.
    - **UseMediumButton:** If present, causes protoUnitCommand to use the first Big Ability/Medium Button slot.
    - **UseMediumButton2:** If present, causes protoUnitCommand to use the second Big Ability/Medium Button slot.
    - **UseMediumButton3:** If present, causes protoUnitCommand to use the third Big Ability/Medium Button slot.
    - **SocketBuild:** If present, indicates that the current protoUnitCommand triggers a SocketBuild command, and causes it to display the cost, if applicable.
    - **DisplayAsPassive:** If present, command will be displayed and handled as a passive action entry.
    - **NotCancellable:** If present, protoUnitCommand, if researchable, won't be cancellable once queued.
    - **Deploy:** If present, denotes that this protoUnitCommand will perform a deployment action for a building which uses deployment ungarrisoning.
    - **SubCivAlliance:** If present, denotes that this protoUnitCommand is a TP auto-building command, allowing it to be properly displayed on a Native Socket while in preview mode, and hidden, while on a TP.
    - **CanQueue:** If present, causes a researchable protoUnitCommand to be queueable alongside units and technologies.
    - **TransformSelected:** If present, when executed with multiple units selected, triggers the respective _TransformCommand_, if applicable, for each selected unit.
    - **CostProtoUnit:** Sets protoUnit whose cost will be shown as command cost. Effect is purely visual and does not effectively cause the protoUnitCommand to have a cost.
    - **Ransom:** If present, denotes that this protoUnitCommand is a researchable ransom command.
    - **UseBigButton2:** If present, causes protoUnitCommand to use the secondary Big Button slot.
    - **UseBigButton3:** If present, causes protoUnitCommand to use the tertiary Big Button slot.

# Civilization Data (civs.xml)

## Attributes

- **Legacy**
  - **Name:** Internal Civilization name.
  - **Main:** Denotes whether the civilization is meant to be a playable civilization, when set to 1, or a SubCiv/Revolution civilization, otherwise.
  - **GameID:** Defines the Expansion Pack this civilization belongs to. Deprecated in AoE3DE, obsolete for the overwhelming majority of AoE3 mods.
  - **StatsID:** Unique identifier to be used by MP stats collector for this particular civilization.
  - **~~​ Portrait:~~** ~~Deprecated.~~
  - **~~​ CircleMenuBackground:~~** ~~Deprecated. Likely not meant to be used in AoE3.~~
  - **Culture:** Civilization culture, as defined in culture data in cultures.xml.
  - **DisplayNameID:** String ID for civilization displayed name.
  - **RolloverNameID:** String ID for civilization rollover.
  - **~~​ AlliedID:~~** ~~Deprecated. Likely used for the original native system.~~
  - **~~​ AlliedOtherID:~~** ~~Deprecated. Likely used for the original native system.~~
  - **~~​ UnAlliedID:~~** ~~Deprecated. Likely used for the original native system.~~
  - **AgeTech:** Assigns a technology to be activated once the player reaches a given age, or, for native SubCivs, when a player allies with it. It can take the following parameters, which should be declared as XML children elements:
    - **_Age_:** Age name/identifier. For Native SubCivs, only the _Age0_ entry needs to be defined.
    - **_Tech_:** Technology to be activated.
  - **BigAgeTech:** Assigns technologies to be activated when allying to this SubCiv when it's initialized as a 'Big SubCiv' (i.e. a subCiv initialized with the third parameter in the _rmSetSubCiv_ RM syscall, usually omitted, is explicitly set to _true_). Due to how those technologies are processed internally, unlike normal _AgeTech_ definition for Native SubCivs, _BigAgeTech_ entries have to be defined for every age. Takes the same parameters as _AgeTech_.
  - **~~​ AgeAdvanceTech:~~** ~~Deprecated. Likely meant to be the initial/primitive implementation~~ ~~for Politician data. Intended to take the same parameters as~~ _~~AgeTech~~_~~.~~
  - **PostIndustrialTech:** Technology to be activated at a Post-Industrial start.
  - **PostImperialTech:** Technology to be activated at a Post-Imperial start.
  - **DeathMatchTech:** Technology to be activated when in DeathMatch game mode.
  - **TeamTech:** Technology to be activated for all team players at the beginning of the game, akin to AoE2 Team Bonuses. Multiple instances of the same civilization or the same technology don't cause its effect to stack.
  - **AgeNameID:** Sets the displayed age name for the age set through the _age_ attribute.

Deprecated in AoE3DE.

- - **ExclusiveSubCivs:** Designed to prevent other players from allying with a particular SubCiv, in case a player of the current civilization happens to be allied with it. Doesn't

prevent Trading Post from being built, but it won't have access to any of the units or technologies from the SubCiv.

- - **SubCivAllianceModifier:** Civilization-specific multiplier to be applied over

_SubCivAllianceCost_.

- - **HCShipmentModifier:** Multiplier to be applied over the amount of XP required to obtain a shipment.
    - **HCShipmentGrowthModifier:** Factor applied linearly over _ShipmentXPGrowth_, as defined in _VictoryPoints_ data for every shipment sent, impacting the amount of XP required for obtaining the next Shipment., until the amount of shipments surpasses the value defined in _HCMaxShipmentMaxGrowthModifier_.
    - **HCMaxShipmentMaxGrowthModifier:** Maximum amount of shipments in which

_HCShipmentGrowthModifier_ will be applied.

- - **~~​ BountyModifier:~~** ~~Deprecated. Intended for scrapped Japanese Bushido XP system.~~
    - **CampaignXPBonusHC:** Bonus multiplier for post-game Home City XP when playing this civilization in a Campaign.
    - **AdditionalWonderBuildRate:** Builder work rate multiplier for Wonders according to the number of builders the Wonder foundation currently has. The order in which the tag is inserted within a civilization data determines the number of workers the given value is linked to (i.e. first tag will define work rate value for 1 worker; second, for two workers, etc.).
    - **BuildingEfficiency:** Work rate multiplier for additional builders on foundations.
    - **_Resource Name:_** _Gold, Wood, Food, Fame, SkillPoints, XP, Ships, Trade, Influence_ \- Sets initial resource amount for the given resource in Legacy, which only affects the Scenario Editor in AoE3DE. Can take attributes, most of which are non-functional, and not meant to be used in AoE3 (_nameID_, _hudIcon_, _textColor_, _countCommand_), except for _icon_, which can be used to set the icon path for the resource icon to be displayed in cost strings, not affecting other usages of the resource icon.
    - **TreatyCost:** Defines the default cost for initiating a treaty with this civilization through the _Create Treaty_ trigger effect. Likely intended for a greater gameplay feature which didn't make it to the final game. The cost in each resource is set through parameters, defined as children XML elements, named after the resource names (_Gold, Wood, Food, Fame, SkillPoints, XP, Ships, Trade, Influence_) and containing the intended resource cost for the respective resource.
    - **StartingUnit:** Defines a starting unit for this civilization.
    - **TownStartingUnit:** Defines a town starting unit, which is only placed after the first Town Center is built. From AoE3DE _The African Royals_ DLC onwards, can take _resourceAmount_ attribute to replace initial main resource value for placed unit.
    - **RandomStartingUnits:** If set, semi-random starting units will be spawned, according to one of starting items defined within colony data. If not set, only units explicitly defined within civilization data will be granted to the player upon game start.
    - **AllyUnit:** Unit to be spawned when successfully allying with this SubCiv by building a Trading Post over its socket. Just as _StartingUnit_ and similar civilization attributes, one entry has to be declared for every unit to be spawned.
    - **BigAllyUnit:** Unit to be spawned when successfully allying with this SubCiv by building a Trading Post over its socket, when this SubCiv is initialized as a Big SubCiv within a Random Map (i.e. a subCiv initialized with the third parameter in the _rmSetSubCiv_ RM syscall, usually omitted, is explicitly set to _true_). Just as _StartingUnit_ and similar civilization attributes, one entry has to be declared for every unit to be spawned.
    - **Partisans:** If set, enables the spawning of partisan units upon building destruction, if set in protoUnit data. Set this like &lt;Partisans&gt;1&lt;/Partisans&gt;.
    - **~~​ ReinforcementAuto:~~** ~~Deprecated.~~
    - **~~​ ReinforcementPerimeterWallCheck:~~** ~~Deprecated.~~
    - **~~​ ReinforcementCostFactor:~~** ~~Deprecated.~~
    - **~~​ ReinforcementAttackDelay:~~** ~~Deprecated.~~
    - **~~​ ReinforcementTrainRate:~~** ~~Deprecated~~
    - **~~​ GatherPointSound:~~** ~~Deprecated.~~
    - **~~​ Wall:~~** ~~Deprecated. Defines the protoUnit for the wall type set through the~~ _~~type~~_ ~~attribute~~ ~~(~~_~~Straight2~~_~~,~~ _~~Straight3~~_~~,~~ _~~Straight4~~_~~,~~ _~~Straight5~~_~~,~~ _~~Gate~~_~~,~~ _~~Connector~~_~~) Intended for Perimeter Wall~~ ~~feature.~~
    - **HomeCityFilename:** Base HomeCity data file path.
    - **HomeCityFlagTexture:** Civilization flag texture to be rendered on top of buildings.
    - **HomeCityFlagButtonSet:** Small button set for civilization flag, used for in-game UI. Deprecated in AoE3DE.
    - **HomeCityFlagButtonSetLarge:** Large button set for civilization flag, used for pre-game lobbies. Deprecated in AoE3DE.
    - **PostgameFlagTexture:** Texture for post-game flag. Deprecated in AoE3DE.
    - **MatchmakingTextures:** Defines civilization textures intended to be used in ESO UI. Mostly deprecated for AoE3DE. The supported parameters, which should be declared as children elements, are listed as follows:
      - **_BannerTexture_:** Large civilization banner base texture for ESO.
      - **_BannerTextureCoords_:** Texture coordinates for civilization banner. Defined as a pair of (x,y) proportional relative coordinates within the \[0,1\] range.
      - **_PortraitTexture_:** Large civilization leader portrait base texture for ESO.
      - **_PortraitTextureCoords_:** Texture coordinates for large civilization leader portrait
      - **_SmallPortraitTexture_:** Small civilization leader portrait base texture for ESO. Used in the Diplomacy dialog, in case civilization has no _personality_ file assigned to it. In AoE3DE, WPF texture path is obtained through this attribute, in case _SmallPortraitTextureWPF_ isn't set.
      - **_SmallPortraitTextureCoords_:** Texture coordinates for small civilization leader portrait. Usually set to _0 0 1 1_, as _SmallPortraitTexture_ is always set to an individual texture file.
      - **_SmallPortraitTextureWPF_:** WPF texture path for small civilization leader portrait. Solely used in the Diplomacy dialog, in case civilization has no _personality_ file assigned to it.
    - **UnitRegen:** Defines unit regeneration for a particular unittype. The supported parameters, which should be declared as children elements, are listed as follows:
      - **_UnitType_:** Target unitType.
      - **_Rate_:** Percentage-based regeneration rate.
      - **_IdleTimeout_:** Minimum amount of time in seconds a unit has to be idle before regeneration begins.
      - **_DamageTimeout_:** Minimum amount of time in seconds since the last time the unit received any damage before regeneration begins.
      - **_RateLimit_:** Minimum unit hitpoint ratio that can be reached through degeneration, when setting regeneration rate to a negative value. Available from AoE3DE _American Civilization_ release onwards.
      - **_Absolute_:** Linear/additive regeneration rate. Available from AoE3DE _The African Royals_ DLC onwards.
    - **~~​ UnitMultiple:~~** ~~Deprecated. Apparently intended to be used as data for an alternative~~ ~~training method for native units in early AoE3 versions. Takes~~ _~~Name~~_~~,~~ _~~Count~~_~~,~~ _~~MinCount~~_~~,~~ _~~MaxCount~~_~~,~~ _~~CountIncrement~~_~~,~~ _~~CountPoints~~_~~,~~ _~~TrainPoints~~_~~,~~ _~~ActiveIcon~~_~~,~~ _~~DisabledIcon~~_ ~~as~~ ~~arguments, declared as XML child elements.~~
    - **BlockTrain:** Defines single-unit block training entries. The supported parameters, which should be declared as children elements, are listed as follows:
      - **_Building_:** Building where this block training entry should be available.
      - **_Unit_:** ProtoUnit to be trained
      - **_Count_:** Amount of units in blocktrain entry.
    - **MultipleBlockTrain:** Defines multi-unit block training entries. The supported parameters, which should be declared as children elements, are listed as follows:
      - **_Building_:** Building where this block training entry should be available.
      - **_MultipleBlockUnit:_** Placeholder unit which triggers block training upon being trained from the source building for the multiple block train entry.
      - **_Units_:** Lists protoUnits to be trained as children _Unit_ tags.
      - **_UnitCounts_:** Lists unit counts, as children _Count_ tags, for every protoUnit listed in

_Units_, following the same order.

- - **Key:** Key to be used for fetching correct display string for units using rollovers with civilization-specific text.
    - **Visible:** If set, civilization will be selectable by players in both Single Player and Multiplayer lobbies, if a valid homeCity assigned to this civilization exists. Set to 1 by default.
    - **VisibleInEditor:** If set, civilization will be selectable for players in the Scenario Editor. Set to 1 by default.

## Definitive Edition

- - **CivType:** Sets the civilization type, which can enable or assign special behaviour to the civilization. Set to 0 (European/Generic) by default. The possible values are listed as follows:
        - **_0_:** European/Generic
        - **_1_:** TWC Native
        - **_2_:** TWC SPC Native
        - **_3_:** Asian
        - **_4_:** SPC Asian
        - **_5_:** SPC European
        - **_6_:** African
        - **_7_:** American
    - **PolCivName:** String to be used to look up for the age up tech entries in politicianData for the current civilization, for the TWC Native and Asian aging-up systems.
    - **SettlerProtoName:** ProtoUnit name for default settler protoUnit, to be delivered through TEAM Villager/Settler cards and used for obtaining shared Villager build limit.
    - **PoliticianBaseStringID:** Base string ID to be used for Politician UI title. If not set, it will default to the value linked to the given civType (_34448_ for European/Generic, _111400_ for TWC Native, _111404_ for Asian, or _111408_ for American)
    - **RevolutionHomeCityName:** String ID for Revolution Home City name override.
    - **RevolutionDeckSize:** Displayed maximum deck size for Revolution Civilization. Doesn't impact game behaviour.
    - **UseExtendedDeckUI:** If present, enables Extended Deck for the civilization.
    - **HeroHCLabelID:** String ID for Hero/Explorer name label in Home City Edit dialog. If not set, it will default to the value linked to the given civType (_69202_ for Asian, _110613_ for American, _36439_ for all others).
    - **SecondHeroHCLabelID:** String ID for second Hero/Explorer name label in Home City Edit dialog, if applicable. If not set, it will default to the same string used for the first one.
    - **UseTwoHeroNames:** If present, two Hero/Explorer entries will be displayed for this civilization in the Home City Edit dialog.
    - **InfluenceRate:** Rate set for each of the core game resources (_Food_, _Wood_, _Gold_), used for calculating Influence cost for an unit through the _calculateInfluenceCost_ data effect. Values for each of the core resources are set through XML children elements, named after the resource names, containing the rate values for each resource.
    - **StartingResourcesMultiplier:** Multipliers to be applied over the granted starting resources amount, defined for each resource. The multiplier for each resource is set through parameters, defined as children XML elements, named after the resource names (_Gold, Wood, Food, Fame, SkillPoints, XP, Ships, Trade, Influence_) and containing the intended value cost for the respective resource.
    - **TreatyTech:** Technology to be activated when in Treaty game mode.
    - **~~​ TwoTownTech:~~** ~~Deprecated.~~
    - **EmpireWarsTech:** Technology to be activated when in Empire Wars game mode.
    - **AdditionalFOAKTech:** Additional non-standard technology which can trigger Trade Monopoly victory condition.
    - **MaximumAgeUpResourceCost:** Maximum total age up resource cost for each age.

Used for determining whether a Community Plaza protoAction with a _DanceBonusType_ set to a _AgeUpCostAbsolute_ has produced a discount greater than the maximum age up cost for the current age for this civilization. The value for each age is set through parameters, defined as children XML elements, named after the internal age names for each Age, except for Exploration/Discovery.

- - **~~​ TwoTownStartingUnit:~~** ~~Deprecated.~~
    - **EmpireWarsStartingUnit:** Defines a _TownStartingUnit_ exclusive for the Empire Wars game mode. All default _TownStartingUnit_ entries are ignored for Empire Wars mode,

regardless of whether or not there are any _EmpireWarsStartingUnit_ entries set. Accepts the same attributes as _TownStartingUnit_.

- - **DeathMatchStartingUnit:** Defines an additional _TownStartingUnit_ exclusive for the Death Match game mode. Accepts the same attributes as _TownStartingUnit_.
    - **EmpireWarsResources:** Defines additional starting resources for Empire Wars game mode The value for each resource is set through parameters, defined as children XML elements, named after the resource names (_Gold, Wood, Food, Fame, SkillPoints, XP, Ships, Trade, Influence_).
    - **EmpireWarsShipmentModifier:** Multiplier to be applied over the amount of XP required to obtain a shipment for Empire Wars mode. Stacks with default factor defined through _HCShipmentModifier_.
    - **EmpireWarsShipmentGrowthModifier:** Multiplier applied over _ShipmentXPGrowth_, as defined in _VictoryPoints_ data for every shipment sent, impacting the amount of XP required for obtaining the next Shipment in Empire Wars Mode. Unlike _HCShipmentGrowthModifier_, this is a static invariable value.
    - **EmpireWarsShipmentXPMaximumModifier:** Multiplier applied over _ShipmentXPMaximum_, as defined in _VictoryPoints_ data, altering the maximum value that the amount of XP required for a single shipment can reach.
    - **EmpireWarsShipmentRates:** Defines shipment rates for each valid HC card age value for Empire Wars mode. The value for each age is set through parameters, defined as children XML elements, named after the internal age names for each Age, except for Imperial.
    - **EmpireWarsAgeUpRates:** Defines age up rates for each age for Empire Wars mode. The value for each age is set through parameters, defined as children XML elements, named after the internal age names for each Age, except for Exploration/Discovery.
    - **HomeCityFlagForceTeamColor:** If set, player colour will be applied over the civilization flag texture to be rendered on top of buildings. Requires the texture to have a properly set alpha channel.
    - **HomeCityFlagButtonWPF:** Path for WPF texture to be used for in-game flag button.
    - **HomeCityFlagIconWPF:** Path for WPF texture to be used for pre-game flag button in SP/MP lobbies.
    - **HomeCityPreviewWPF:** Path for WPF texture to be used for civilization compendium entry.
    - **PostgameFlagIconWPF:** Path for WPF texture to be used for civilization post-game flag.
    - **RevolutionFlagWPF:** Path for WPF texture to be used for revolution banner to be displayed in Politician UI, if applicable.
    - **DisplayRevolutionFlag:** If set to 1, Revolution Banner set in _RevolutionFlagWPF_ will be displayed in Politician UI;
    - **CanPayFreeFoundations:** If present, allows player to pay for the completion of a foundation placed by an _AbstractFreeBuilder_.
    - **FreeBuildingEfficiency:** Work rate multiplier for additional builders on free foundations (i.e. foundations placed by an _AbstractFreeBuilder_).
    - **SubCivType:** Sets the subCiv type. Does not impact the overall behaviour.
    - **AllianceCost:** For subCivs, overrides the cost for building a TP through the auto-build command in capturable native sockets. The cost in each resource is set through parameters, defined as children XML elements, named after the resource names (_Gold, Wood, Food, Fame, SkillPoints, XP, Ships, Trade, Influence_) and containing the intended resource cost for the respective resource.

## Non-Civilization Attributes

- **Legacy**
  - **SubCivAllianceCost:** Deprecated attribute in Legacy AoE3. As of _Knights of The Mediterranean_ AoE3DE DLC, defines the cost to be used for the auto-build command in capturable Native Sockets.
  - **~~​ SubCivAllianceCostFactor:~~** ~~Deprecated.~~

### Definitive Edition

- - **MaxDeckSize:** Default maximum deck size.
    - **DefaultPopLimit:** Default base population limit.
    - **DefaultPopExtraLimit:** Default base value for maximum population limit increment, which can be added through tech effects or specific _DanceBonus_ types.
    - **DefaultContainedRegenRate:** Default percentage-based regeneration rate for garrisoned units within buildings.
    - **DisplayFame:** If set to _1_, causes Fame resource to be displayed in main game UI for all civilizations.

# TechTree (techtreey.xml)

## Attributes

- **Legacy**
  - **DBID:** Sets the DBID for the Technology, used internally for checks related to homeCity saved data. It's a good practice to assign a unique DBID for every new technology.
  - **DisplayNameID:** String ID for the technology displayed name.
  - **Cost:** Technology cost. Takes one parameter, _resourcetype_, which sets the resource type for each entry.
  - **ResearchPoints:** Total amount of time in seconds required to research the technology.
  - **ResearchLimit:** Number of times in which the technology can be researched. Set to 1 by default.
  - **Status:** Initial availability status of the technology. Can be set to _UNOBTAINABLE_, _OBTAINABLE_ or _ACTIVE_.
  - **Icon:** WPF path for technology icon, relative to _Data\\wpfg_.
  - **RolloverTextID:** String ID for the technology long rollover.
  - **~~​ LongRolloverTextID:~~** ~~Unused and deprecated.~~
  - **~~​ ButtonPos:~~** ~~AoM leftover. Unused and deprecated.~~

## Definitive Edition

- - **RevolutionCiv:** Defines the revolution civilization to be used for Revolution option technologies.
    - **SequesterTech:** For Consulate option technologies, defines the sequester/undo alliance technology to be re-enabled, once that particular consulate relation is chosen at the second time.
    - **ValueText:** Value text to be displayed over technologies, akin to the ones used in protoUnitCommands. Supports the same data fetchers as the ones supported by protoUnitCommands. Requires the technology flag _DEUsesValueText_ to be set for proper functionality.
    - **DynamicCostKBStat:** KB Stat to be used as a reference for technology cost escalation.
    - **KBStatFactorCap:** Maximum factor for KB Stat based cost escalation.
    - **UnlockID:** For technologies used for displaying Alliance Unlocks in the Politician UI, defines the string ID for a list entry within the Alliance Unlock description. Should be nested within an _Unlocks_ tag and requires the _DEAllegianceUnlock_ technology flag to be set.

&lt;Unlocks&gt;

&lt;UnlockID&gt;103363&lt;/UnlockID&gt;

&lt;UnlockID&gt;103364&lt;/UnlockID&gt;

&lt;/Unlocks&gt;

## Flags

- **Legacy**
  - **Volatile:** AoM leftover. Denotes a technology that's meant to be automatically activated once its prerequisites are met. Used for _Persistent_ technologies in AoM.
  - **AlwaysShowButton:** Forces a technology to be always shown in the UI, even when it's not available to be researched.
  - **ExcludeFromPlaytest:** Causes the technology to be disabled if the _Playtest_

configuration is set in the game configuration file.

- - **DynamicCost:** Causes the technology cost to scale according to the number of enemy units present on the map.
    - **AgeUpgrade:** Self-explanatory.
    - **~~​ HideFromDetailHelp:~~** ~~AoM Leftover. Unused and deprecated.~~
    - **Shadow:** Denotes technologies that aren't supposed to be shown in the UI or to generate notifications upon research.
    - **UniqueProtoUnitInstance:** Denotes technologies that are applied individually for every instance of a particular protoUnit.
    - **UpgradeTech:** Denotes a unit upgrade technology. Used for internal KB Tech Tree processing.
    - **ForceLastInLine:** Forces a particular unit upgrade technology to be considered as the last in its upgrade chain.
    - **HomeCity:** Indicates that the technology will be used as a Home City card.
    - **TeamTech:** Causes the effect of the technology to be applied to the entire team of the player who researched it.
    - **OrPrereqs:** Causes the prerequisites of a technology to be processed using _OR_ logic, allowing the technology to be made available as soon as at least one of the tech prerequisites are met.
    - **UniqueTech:** Meant to indicate a civilization-specific technology, but doesn't impact technology behaviour.
    - **CountsTowardEconomicScore:** Causes the technology to count toward economic score once researched.
    - **CountsTowardMilitaryScore:** Causes the technology to count toward military score once researched.
    - **DoNotQueue:** Allows the technology to override and ignore the building queue to be researched.
    - **NativeDance:** Causes the technology to take the Native Big Button slot in the UI.
    - **RevoltTech:** Self-explanatory.
    - **YPInfiniteTech:** Self-explanatory.
    - **CheckLandHCGatherPoint:** Prevents the technology from being researched in case there's no land Home City Gather Point available.
    - **CheckWaterHCGatherPoint:** Prevents the technology from being researched in case there's no water Home City Gather Point available.
    - **YPNeverLastInLine:** Prevents the technology from being set as the last in its upgrade chain.
    - **YPNauticalTPOnly:** Causes the technology to be only displayed in Trading Posts linked to Trade Routes of the Nautical type. In _The Asian Dynasties_, Trading Routes in Asian maps are, internally, classified as 'Nautical' Trade Routes.
    - **YPLandTPOnly:** Causes the technology to be only displayed in Trading Posts linked to Trade Routes of the Land type.
    - **YPCheckPopCap:** Forces checking if the player has free population capacity before researching the technology.
    - **YPUseBigButton2:** Unused. Causes the technology to take the first Big Button slot in the command panel UI.
    - **YPUseBigButton3:** Unused. Causes the technology to take the second Big Button slot in the command panel UI.
    - **YPAlwaysDisableButtonInGrid:** Forces the technology to be always shown as disabled in the command panel UI.
    - **YPUseBigHugeButton:** Causes the technology to take the entirety of the command panel UI. Used for the Consulate Relations button.
    - **YPConsulateTech:** Denotes a Consulate relation option technology.
    - **YPForceUnapply:** Forces the technology to be reverted once it's set to _Unobtainable_

status.

- - **YPNeverObtainableAfterUse:** Forbids the technology from being set to Obtainable in case it is already active.
    - **YPMonasteryTech:** Denotes an Asian monastery technology. Doesn't impact technology behaviour.
    - **YPCapturableTradeRouteUpgradeTech:** Denotes a technology to be made available in Capturable Trading Posts.
    - **YPGridShiftRowRightOne:** Causes all subsequent items of the row that this tech is in to be shifted one position to the right.
    - **YPSequesterTech:** Denotes an End Consulate Relations technology.
    - **YPConsulateImprovement:** Denotes a Consulate improvement. Doesn't impact technology behaviour.
    - **ypConsulateImprovementImperial:** Denotes a Consulate improvement made available at the Imperial Age. Doesn't impact technology behaviour.
    - **YPNativeImprovement:** Denotes a Native Settlement improvement. Doesn't impact technology behaviour.
    - **YPWondersColonial:** Denotes an _AgeUpgrade_ technology linked to a Colonial/Commerce Age Wonder. Doesn't impact technology behaviour.
    - **YPWondersFortress:** Denotes an _AgeUpgrade_ technology linked to a Fortress Age Wonder. Doesn't impact technology behaviour.
    - **YPWondersIndustrial:** Denotes an _AgeUpgrade_ technology linked to an Industrial Age Wonder. Doesn't impact technology behaviour.
    - **YPWondersImperial:** Denotes an _AgeUpgrade_ technology linked to an Imperial Age Wonder. Doesn't impact technology behaviour.
    - **YPBlockade:** Denotes a technology meant to apply a Blockade. Prevents the technology from being researched if Blockades are disabled.
    - **YPNoTextMessage:** Causes the technology to not generate notifications upon research.
    - **YPIgnorePopCostBuildLimitFreeHCUnitIfTechObtainable:** Causes any _FreeHomeCityUnitIfTechObtainable_ or _FreeHomeCityUnitByTechActiveCount_ (DE) tech effects to not block a Home City card from being sent in case they go over a unit's Build Limit. In Legacy, those effects don't cause extra units to be delivered. In Definitive Edition, they'll send units, unless the _DEForceLegacyIgnoreBehavior_ technology flag is set.
    - **YPRecalcHCTrainQueuePointsWhenShipped:** Forces the shipping time for currently queued Home City cards to be recalculated when the technology is researched.

## Definitive Edition

- - **DEForceUniqueInstancePrereqUpdate:** Forces prerequisites for technologies applied over individual instances of particular units (such as Trade Route Upgrades) to be properly updated, once this technology is researched.
    - **DEDisplayAsAge0Prereq:** Causes a technology to be recognized as a Discovery/Exploration Age requirement when used as a prerequisite for another technology, allowing the age prerequisite indicator to be shown.
    - **DEDisplayAsAge1Prereq:** Causes a technology to be recognized as an Colonial/Commerce Age requirement when used as a prerequisite for another technology, allowing the age prerequisite indicator to be shown, even in the absence of _Colonialize_ among the technology prerequisites.
    - **DEDisplayAsAge2Prereq:** Causes a technology to be recognized as an Fortress Age requirement when used as a prerequisite for another technology, allowing the age prerequisite indicator to be shown, even in the absence of _Fortressize_ among the technology prerequisites.
    - **DEDisplayAsAge3Prereq:** Causes a technology to be recognized as an Industrial Age requirement when used as a prerequisite for another technology, allowing the age prerequisite indicator to be shown, even in the absence of _Industrialize_ among the technology prerequisites.
    - **DEDisplayAsAge4Prereq:** Causes a technology to be recognized as an Imperial Age requirement when used as a prerequisite for another technology, allowing the age prerequisite indicator to be shown, even in the absence of _Imperialize_ among the technology prerequisites.
    - **FakeAgeUpgrade:** Denotes a fake technology that takes the place of the Age Button for cultures with non-standard aging up mechanisms (such as the Asian culture).
    - **DEIgnorePopCostBuildLimitFreeHCUnitByCount:** Causes any _FreeHomeCityUnitByShipmentCount, FreeHomeCityUnitByShipmentCountResource_ or _FreeHomeCityUnitByUnitCount_ tech effects to not block a Home City card from being sent in case they go over a unit's Build Limit. They'll send units, unless if the _DEForceLegacyIgnoreBehavior_ technology flag is set.
    - **DETradeRouteUpgrade:** Denotes a Trade Route upgrade technology. Doesn't impact technology behaviour.
    - **DEHCCardDynamicCount:** Causes a Home City card unit count to be dynamically updated according to the number of units it currently delivers, if it doesn't have any _DisplayUnitCount_ value set in the Home City file.
    - **DEHCCardForcePopCheck:** Forces the card to check for the current player free population capacity, even in cases where it's impossible to determine which types of units will be sent, based on the expected amount of units (for example, when the _FreeHomeCityUnitRandom_ tech effect is used).
    - **DECostConvertToInfluence:** Denotes a technology whose cost should be converted to Influence when made available to a civilization belonging to the African Culture, in the _The African Royals_ AoE3DE DLC. Doesn't inherently impact technology behaviour.
    - **DENativeUnitUpgrade:** Denotes an upgrade to a particular native unit. Doesn't impact technology behaviour.
    - **DEUsesValueText:** Allows a technology to display value text.
    - **DEAllegianceUnlock:** Denotes an African Alliance Unlock entry to be displayed in the Politician UI.
    - **DEUseMediumButton:** Causes the technology to take the first Medium Button/Big Ability (2x2) slot in the UI.
    - **DECheckBuildLimit:** Forbids the technology from being researched in case it delivers units that would cause the player to go over the build limit for a particular unit.
    - **DEUseMediumButton2:** Causes the technology to take the second Medium Button/Big Ability (2x2) slot in the UI.
    - **DEUseMediumButton3:** Causes the technology to take the third Medium Button/Big Ability (2x2) slot in the UI.
    - **DENoTextMessageIfFree:** Causes the technology to not generate notifications upon research, in case it costs no resources.
    - **DEAccumulateUnitCount:** Causes unit limit checks for this technology to account for all effects that deliver units, instead of the last checked one or the first one that failed.
    - **DEDoNotCheckUnitCapWhenShipping:** Forces dynamic unit shipping tech effects that check for unit build limit after the technology has been set to active to not perform this check.
    - **DEDoNotAllowDuringNoRush:** Forbids a technology from being researched while a Treaty is active.
    - **DERevertRevolution:** Denotes a revolution reversion/return to home country technology.
    - **DESubRevolution:** Denotes a revolution that is only supposed to be made available after the player revolts.
    - **DEAge1Revolution:** Denotes a revolution that is enabled at the Colonial/Commerce Age.
    - **DEAge2Revolution:** Denotes a revolution that is enabled at the Fortress Age.
    - **DENonStandardRevolution:** Denotes a revolution option that does follow the standard design introduced in _The War Chiefs_.
    - **DEHideAdvancedRollover:** Causes advanced effect information to not be shown for the technology.
    - **DETradeMonopolyCondition:** Denotes a non-standard technology that can trigger Trade Monopoly victory condition. For proper full functionality, the _AdditionalFOAKTech_ civ attribute needs to be set to the name of the technology for the civilization(s) that are supposed to have this technology available.
    - **DEUpdatePopulationCount:** Forces a technology linked to a Home City Card to update the player's current and future population count once the Card is sent.
    - **DEUnobtainableAfterActive:** Causes the technology to be set back to _Unobtainable_ status once it's set to _Active_. It will automatically revert its effects if the technology is then set to _Obtainable_ again. The process of setting it to _Obtainable_ can be done automatically by adding the _Volatile_ flag to the technology. So when _DEUnobtainableAfterActive_ is used alongside the _Volatile_ flag, it can be used to create a self-reversible persistent technology. Tip: spawn units.
    - **DEBuildLimitUnitCap:** Causes _unitCap_ in dynamic unit shipment effects to be limited by the build limit of the delivered units.
    - **DEForceCostUpdate:** Allows technology cost to be changed in all cases, even for resources with its base value set to zero.
    - **DEMarketTechnology:** Denotes a market technology. Doesn't impact technology behaviour.
    - **DEFarmingTechnology:** Denotes a farming technology. Doesn't impact technology behaviour.
    - **DEFakeCard:** Indicates that this technology will be used for a building-based shipment/fake card.
    - **DEShipmentPlaySound:** If set, unit creation sounds will be played for units delivered through the standard shipment effects (_FreeHomeCityUnit_ and _FreeHomeCityUnitIfTechObtainable_).
    - **DEPlayerTechCostAbsolute:** Denotes that this technology will be affected by building build bounty-based progressive tech cost discount.
    - **DEHospitalTechnology:** Denotes a Maltese hospital technology. Doesn't impact technology behaviour.
    - **DESetObtainableIfFailed:** If set, technology will become obtainable and re-researchable, in case its effects have failed to be applied.
    - **DECheckForValidCards:** If set, technology won't be researchable if, for some reason, player doesn't currently have any valid sendable cards from HomeCity.
    - **DERiverTPOnly:** Causes the technology to be only displayed in Trading Posts linked to Trade Routes of the River type.
    - **DEColonialMercShipment:** Denotes a Colonial/Commerce Age Mercenary or Native Support shipment. Doesn't impact technology behaviour.
    - **DEFortressMercShipment:** Denotes a Fortress Age Mercenary or Native Support shipment. Doesn't impact technology behaviour.
    - **DEIndustrialMercShipment:** Denotes an Industrial Age Mercenary or Native Support shipment. Doesn't impact technology behaviour.
    - **DEIndustrialRepeatMercShipment:** Denotes an Industrial Age Infinite Mercenary or Native Support shipment. Doesn't impact technology behaviour.
    - **DECompanyMercShipment:** Denotes an Italian Mercenary Company shipment.

Doesn't impact technology behaviour.

- - **DEDoNotAllowIfRevolted:** Prevents the given technology from being researched, if player has revolted or has a revolution queued.
    - **DERequiresImperialAge:** Prevents the given technology from being researched if current match settings do not support Imperial
    - **DEForceUnapplyIfActive:** Forces the technology to be reverted once it's set to

_Unobtainable_ status, if and only if its previous state was _Active_.

**Prerequisites**

| **Legacy** |     |     |     |     |
| --- |     |     |     |     | --- | --- | --- | --- |
| **Type** | **Description** | **Attributes** |     | **Syntax** |
| **TechStatus** | Checks whether or not the status of a particular technology matches the given value. | **status** | The expected status of the given technology (_active_, _obtainable_, _unobtainable_) | <TechStatus status<br><br>\='Active'>DEChurchMissionFervor&lt;/TechStatus&gt; |
| **HomeCityLevel** | Checks whether or not the Home City level of the current player matches the expected condition. | **operator** | Operator to be used for condition checking (_gt_, _lt_, _e_). Different operators can be combined. If not set, it will default to _gte_ (greater than or equal) | &lt;HomeCityLevel&gt;20&lt;/HomeCityLevel&gt; |
| **SpecificAge** | AoM leftover. Checks whether or not the age of the current player matches the expected condition. Still functional in AoE3. | **operator** | Operator to be used for condition checking. | &lt;SpecificAge operator='e'&gt;Age0&lt;/SpecificAge&gt; |
| **TypeCount** | AoM leftover. Checks whether or not the total count of units of the given type in the given state(s) for the player matches the expected condition.<br><br>In Legacy AoE3, as prerequisite status updates are only triggered either when a technology is researched or the player total popcap is changed, _TypeCount_ | **unit** | Unit Type to be checked. | &lt;TypeCount unit='TownCenter' count='1' operator='gte' state='aliveState' /&gt; |
| **count** | Expected unit count |
| **operator** | Operator to be used for condition checking. |
| **state** | Expected unit KB state (_aliveState_, _deadState_, _buildingState_, _anyState_, _noneState_). States can be combined, when |

|     | prerequisites can only work properly over buildings or units that change the player's total popcap.<br><br>In AoE3DE, from the _Mexican Civilization_ release onwards, units and buildings can be assigned the _ForceFullTechUpdate_ protoUnitFlag, so they can trigger prereq updates once built/created and once destroyed/killed, and thus be properly accounted for this particular prerequisite type. |     | separated by space or comma. If not set, defaults to _anyState_, in AoM and Legacy AoE3, or to _noneState_, in AoE3DE. |     |
| --- | --- | --- | --- | --- |
| **Culture** | AoM leftover. Checks whether or not the civilization of the current player belongs to either of the listed cultures. | **cultureName** | Self-explanatory. | &lt;Culture&gt;<br><br>&lt;cultureName&gt;Mediterranean&lt;/cultureName&gt;<br><br>&lt;/Culture&gt; |
| **Civilization** | AoM leftover. Checks whether or not the current player belongs to either of the listed civilizations. | **civName** | Self-explanatory. | &lt;Civilization&gt;<br><br>&lt;civName&gt;Portuguese&lt;/civName&gt;<br><br>&lt;civName&gt;Spanish&lt;/civName&gt;<br><br>&lt;/Civilization&gt; |
| **Definitive Edition** |     |     |     |     |
| **KBStat** | Checks whether or not the value of a given KB Stat matches the expected condition. | **kbStat** | KB Stat to be used for the prerequisite, selected from a subset of the available KB Stats used by the game. A list of the supported KB Stats for technologies can be found at the end of the | &lt;KBStat kbStat='teamSubCivAllianceLevel' kbParam='SPCCityState' value='2' operator='gte' /&gt; |

|     |     |     | document. |     |
| --- | --- | --- | --- | --- |
| **kbParam** | _Optional_: KB Stat parameter for supported KB Stats that can take a parameter. Read as SubCiv ID for _teamSubCivAllianceLev el_. |
| **value** | Expected value. |
| **operator** | Operator to be used for condition checking. |

**Effects**

| **Legacy** |     |     |     |     |
| --- |     |     |     |     | --- | --- | --- | --- |
| **Type** | **Description** | **Attributes** |     | **Syntax** |
| **SetName** | Changes the displayed name of a protoUnit. | **proto** | ProtoUnit name. | &lt;Effect type ='SetName' proto ='ypMonastery' newName ='63263'&gt;&lt;/Effect&gt; |
| **tech** | Technology name. (AoE3DE) |
|     | As of AoE3DE onwards, it can also affect technologies and change both short and long rollover strings. | <Effect type ='SetName' tech<br><br>\='DEHCREVMilitaryFrontier' newName ='80921'<br><br>newRollover ='80925' reqTech='Age0Russian'>&lt;/Effect&gt; |
| **newName** | String ID for new protoUnit or technology displayed name |
| **newRollover** | _Optional_: String ID for new protoUnit or technology rollover. (AoE3DE) |
|     |     | **newShortRollover** | _Optional_: String ID for new protoUnit short rollover. (AoE3DE) |     |
|     |     | **reqTech** | _Optional_: Required technology for change to be applied. |     |

|     |     | **newEditorName** | _Optional_: String ID for new protoUnit editor name. (AoE3DE) |     |     |
| --- | --- | --- | --- | --- |     | --- |
| **newClassName** | _Optional_: String ID for new protoUnit _ClassNameID_ (AoE3DE) |
| **newGoodAgainst** | _Optional_: String ID for new protoUnit _GoodAgainstStringID_ (AoE3DE) |
| **newBadAgainst** | _Optional_: String ID for new protoUnit _BadAgainstStringID_ (AoE3DE) |
| **newWorldTooltipText** | _Optional_: String ID for new protoUnit _WorldTooltipStringID_ (AoE3DE) |
| **Sound** | AoM leftover. Plays the given soundset for the current player. |     |     | <Effect | type='Sound'>AgeAdvance&lt;/Effect&gt; |
| **TextOutput** | Outputs the given string ID as a game notification. | **all** | _Optional_: When set to '_true_', notification will be shown to all players. | <Effect | type ='TextOutputAll'>91746&lt;/Effect&gt; |
| **TextOutputAll** | Outputs the given string ID as a game notification for all players. |     |     | <Effect | type ='TextOutput'>70320&lt;/Effect&gt; |
| **SetAge** | Sets the age for the current player. |     |     | <Effect | type ='SetAge'>Age2&lt;/Effect&gt; |
| **TechStatus** | Changes the status of a given technology. | **status** | Desired tech status (_active_,<br><br>_obtainable_ or _unobtainable_) | <Effect type ='TechStatus' status<br><br>\='active'>VeteranFinnishRiders&lt;/Effect&gt; |     |
| **Data** | Applies a particular data change, taking up to 2 parameters, | **amount** | Floating point amount to be processed by data effect. |     |     |

<div class="joplin-table-wrapper"><table><tbody><tr><th rowspan="3"></th><th rowspan="2"><p>besides amount and</p><p><em>relativity</em>.</p><p>For more information, refer to the Data Effects table.</p></th><th><p><strong>subType</strong></p></th><th><p>Data effect subtype. Defines the actual effect to be applied through this Data Effect. Refer to subsequent tables for more information.</p></th><th rowspan="3"></th></tr><tr><td></td><td rowspan="2"><p>Defines how the attribute should be changed by the given amount. Not applicable to all data effect subtypes.</p><ul><li><strong><em>Assign</em></strong>: Replaces value by</li></ul><p><em>amount</em>.</p><ul><li><strong><em>Absolute</em></strong>: Adds <em>amount </em>to attribute.</li><li><strong><em>Percent</em></strong>: Multiplies attribute value by <em>amount</em>.</li><li><strong><em>BasePercent</em></strong>: Adjusts attribute value by <em>amount</em>, using the original unaltered attribute value as base.</li><li><strong><em>Override</em></strong>: Replaces <em>both </em>the current and the original (base) attribute value by <em>amount</em>, changing the behaviour of subsequent <em>BasePercent </em>relativity <em>Data </em>effects. Only valid for <em>Cost</em>, <em>WorkRate </em>and <em>CalculateInfluenceCost </em>subtypes (AoE3DE).</li><li><strong><em>DefaultValue</em></strong>: Exclusive to <em>BuildBountySpecific </em>subtype. Sets the <em>BuildBounty </em>of a</li></ul><p>non-standard resource to the same value as the default XP <em>BuildBounty</em>.</p></td></tr><tr><td></td><td><p><strong>relativity</strong></p></td></tr><tr><td><p><strong>SharedLOS</strong></p></td><td><p>Grants the current player the LOS of other players.</p></td><td><p><strong>all</strong></p></td><td><p><em>Optional</em>: If set to '<em>true</em>', all players are revealed, regardless of team alignment.</p></td><td><p>&lt;Effect all ='true' type ='SharedLOS'&gt;&lt;/Effect&gt;</p></td></tr></tbody></table></div>

| **Blockade** | Initiates a blockade over enemy home cities, preventing them from receiving shipments |     |     | &lt;Effect type ='Blockade'/&gt; |
| --- | --- | --- | --- | --- |
| **ShowHCView** | Switches the current player to the Home City view, if available, in case the player is not in Home City view or is viewing another player's HC. Unused, but functional. |     |     | &lt;Effect type ='ShowHCView'/&gt; |
| **ShowWorldView** | Switches the current player to the game world view, if available, in case the player is currently at the Home City view. Unused, but functional. |     |     | &lt;Effect type ='ShowWorldView'/&gt; |
| **ModifyProtoUnit** | Modifies the displayed name and/or the hitpoints of a given protoUnit. Unused, but functional. Superseded by _SetName_ and _Data_ effects. Likely originally intended for internal playtesting and experimenting by Ensemble. | **proto** | ProtoUnit to be modified. |     |
| **newName** | _Optional_: String ID for displayed name. |
| **newHP** | _Optional_: New HP value. Only affects maximum HP. |
| **InitiateRevolution** | Initiates a revolution process, changing the player's deck and flag to the one of the revolution civilization the technology is linked to and transforming all player civilian units into | **proto** | _Optional_: Name of the protoUnit to which all land civilian units will be transformed. Defaults to _xpColonialMilitia_, if not set. If set to '_none_', civilian units are kept as-is (AoE3DE) | &lt;Effect type ='InitiateRevolution' /&gt;<br><br><Effect type ='InitiateRevolution' proto<br><br>\='Musketeer' /><br><br><Effect type ='InitiateRevolution' proto<br><br>\='none' saveDeck ='True' extDeck='True'>&lt;/Effect&gt; |

|     | _xpColonialMilitia_.<br><br>The Revolution Civilization is obtained from the technology name, by removing the 12-character prefix from the revolution technology. From AoE3DE onwards, it can also be set through the _RevolutionCiv_ technology attribute.<br><br>Once executed, in Legacy, disables revolutions for all players in the opposite team. From AoE3DE onwards, this behaviour has been removed.<br><br>Cannot take any arguments in Legacy. | **selfMsg** | _Optional_: String ID for UI alert and notification to be displayed for the revolting player. Default TWC value is used, if not set. (AoE3DE) |     |
| --- | --- | --- | --- | --- |
| **playerMsg** | _Optional_: String ID for UI alert and notification to be displayed to other players. Default TWC value is used, if not set. (AoE3DE) |
| **saveDeck** | _Optional_: If set to '_true_', saves the current deck of the player internally, allowing it to be restored upon Return to Home Country/RevertRevolution. (AoE3DE: Mexican Civilization) |
| **extDeck** | _Optional_: If set to '_true_', Extended Deck cards are kept upon revolting. (AoE3DE: Mexican Civilization) |
| **TransformUnit** | Transforms all instances of a particular protoUnit into a given target protoUnit. | **fromProtoID** | Source protoUnit. | <Effect type ='TransformUnit' toprotoid<br><br>\='xpColonialMilitia' fromprotoid ='Settler' /> |
| **toProtoID** | Destination protoUnit. |
| **ResourceExchange** | Exchanges the entirety of the stockpile of a given resource into another resource, while multiplying by the given factor. | **fromResource** | Source resource. | <Effect type ='ResourceExchange' multiplier<br><br>\='1.25' toresource ='Wood' fromresource ='Gold'<br><br>/> |
| **toResource** | Destination resource. |
| **multiplier** | Multiplier. |
| **SetOnBuildingDeathTech** | Sets technologies to be triggered upon building destruction, according to the cost paid for a building's construction, up to 1000 resources. | **amount** | Index of the technology to be assigned. | <Effect type ='SetOnBuildingDeathTech' amount<br><br>\='0.00' amount2<br><br>\='100.00'>ypSpawnIrregulars&lt;/Effect&gt;<br><br><Effect type ='SetOnBuildingDeathTech' amount<br><br>\='1.00' amount2 |
| **amount2** | Divider amount used to determine the combined amount of times the |

|     |     |     | technologies should be activated upon a building's destruction, according to its cost.. Only read for the first tech to be assigned (i.e. index<br><br>\== 0).<br><br>E.g., for a building costing 600 resources, and a divider set to 100, one tech would be activated 6 times, while 2 techs, both would be activated 3 times each, etc. | \='0.00'>ypSpawnPeasants&lt;/Effect&gt; |
| --- | --- | --- | --- | --- |
| **Data2** | Applies a particular data change, taking up to 4 parameters, besides amount and _relativity_.<br><br>For more information, refer to the Data2 Effects table. | Refer to basic attributes listed in '_Data_' effect type. |     |     |
| **Definitive Edition** |     |     |     |     |
| **CommandAdd** | Adds a protoUnit, technology or protoUnitCommand to a protoUnit's UI at a specific position. | **proto** | ProtoUnit to be added. | <Effect type ='CommandAdd' command<br><br>\='deNatSomaliLighthouse' page ='0' column ='3'><br><br>&lt;Target type ='ProtoUnit'&gt;TradingPost&lt;/Target&gt;<br><br>&lt;/Effect&gt; |
| **tech** | Technology to be added. |
| **command** | ProtoUnitCommand to be added |
| **page** | Page/Row in UI |
| **column** | Column in UI. If set to _\-1_, it will add the entry to the first free slot in the given page/row. |
| **natShow** | _Optional_: If set to 1, and effect is meant to assign a technology to the Trading |

|     |     |     | Post, it will be forcibly displayed on Native Settlement TPs. |     |
| --- | --- | --- | --- | --- |
| **trShow** | _Optional_: If set to 1, and effect is meant to assign an unit to the Trading Post, it will be forcibly displayed on Trade Route TPs. |
| **trCmdShift** | _Optional_: If set to 1, and effect is meant to assign a command to the Trading Post, it will be forcibly displayed on the last row on Trade Route TPs. |
| **ConsoleCommand** | Executes a console command. |     |     | <Effect type<br><br>\='ConsoleCommand'>blackmap&lt;/Effect&gt; |
| **CommandRemove** | Removes a protoUnit, technology or protoUnitCommand from a protoUnit's UI. | **proto** | ProtoUnit to be removed. | <Effect type ='CommandRemove' proto<br><br>\='Falconet'><br><br>&lt;Target type ='ProtoUnit'&gt;dePalace&lt;/Target&gt;<br><br>&lt;/Effect&gt; |
| **tech** | Technology to be removed. |
| **command** | ProtoUnitCommand to be removed. |
| **CreatePower** | Applies the effect of a given protoPower. | **protoPower** | ProtoPower to be applied, | &lt;Effect type ='CreatePower' protoPower='dePowerUSExpedition' /&gt; |
| **AddHomeCityCard** | Adds a Home City card to the extended deck.<br><br>Requires the _UseExtendedDeckUI_ flag to be set in the civilization data for proper functionality. | **tech** | Technology to be added as a card. Expected to have _HomeCity_ flag set. | <Effect type ='AddHomeCityCard' tech<br><br>\='DEHCFedMXTzotzilUprising' maxCount ='1' agePrereq='1' unitCount='0' infiniteInLastAge='0' /> |
| **maxCount** | Akin to the homonymous Home City Card attribute. |
| **agePrereq** |
| **unitCount** |
| **infiniteInLast Age** |

| **TextOutputTechName** | Outputs the given string ID as a game notification, while inserting the technology name within the displayed text.<br><br>This effect expects the string to be displayed to contain one printf-style parameter for string ('_%s_'). | **all** | _Optional_: When set to '_true_', notification will be shown to all players. | <Effect type<br><br>\='TextOutputTechName'>110130&lt;/Effect&gt; |
| --- | --- | --- | --- | --- |
| **ResetHomeCityCardCount** | Resets the amount of times a particular time has been sent, allowing it to be re-sent. | **tech** | Technology name of the Home City card to be reset. | <Effect type ='ResetHomeCityCardCount' tech<br><br>\='HCShipFoodCrates2' /> |
| **RandomTech** | Randomly selects a given amount of technologies from a list and changes their status. | **select** | Number of techs to be selected. | &lt;Effect type='RandomTech' select='3' status='active'&gt;<br><br>&lt;Tech&gt;SaloonBlackRider&lt;/Tech&gt;<br><br>&lt;Tech&gt;SaloonCorsair&lt;/Tech&gt;<br><br>&lt;Tech&gt;SaloonElmeti&lt;/Tech&gt;<br><br>&lt;Tech&gt;SaloonMameluke&lt;/Tech&gt;<br><br>&lt;Tech&gt;SaloonManchu&lt;/Tech&gt;<br><br>&lt;/Effect&gt; |
| **status** | New status to be assigned to selected techs. |
| **TextEffectOutput** | Displays an UI alert to all players. | **reason** | UI alert type to be displayed (_revolution_, _tradeMonopoly_, _koth_, _revertRevolution_, _papal_, _treaty_) | <Effect type ='TextEffectOutput' reason<br><br>\='Revolution' selfMsg ='104580' playerMsg<br><br>\='104581' /> |
| **selfMsg** | String ID for UI alert and notification to be displayed for the current player. |
| **playerMsg** | String ID for UI alert and notification to be displayed to other players. Expected to receive player name. |
| **SetOnShipmentSentTech** | Adds or removes technologies to be | **amount** | Should be set to _1_, if technology is meant to be | <Effect type ='SetOnShipmentSentTech' amount<br><br>\='1.00'>DEREVShipPetard&lt;/Effect&gt; |

|     | activated once a shipment is received. |     | added; _0_, if excluded. |     |
| --- | --- | --- | --- | --- |
| **minAge** | _Optional_: Minimum age prerequisite a card needs to have in order to trigger this technology when received. |
| **maxAge** | _Optional_: Maximum age prerequisite a card should have in order to trigger this technology when received. |
| **allowInfinite** | _Optional_: When set to '_True_', Infinite cards will be affected. Set to '_True_' by default. |
| **ResourceInventoryExchange** | Exchanges the entirety of the total resource inventory of all instances of a particular protoUnit into another resource, depositing into the player's stockpile, while multiplying by the given factor. | **unitType** | Target unit type or protoUnit. | &lt;Effect type ='ResourceInventoryExchange' multiplier ='0.70' unittype='AbstractBovine' toresource ='Influence' fromresource ='Food' keepUnit='True' /&gt; |
| **fromResource** | Source resource. |
| **toResource** | Destination resource. |
| **multiplier** | Multiplier. |
| **keepUnit** | _Optional_: If set to '_true_', units will be kept, once the effect is applied, but with no resource storage. Set to '_false_' by default. |
| **AddTrickleByResource** | Grants to the player a variable trickle of a particular resource, that grows linearly according to the total stockpile of the given resource(s). | **resource** | Trickle resource. | <Effect type ='AddTrickleByResource' resource<br><br>\='Gold' minValue ='0.001' maxValue ='4.0'<br><br>minSrcValue ='1.00' maxSrcValue ='4000.00' srcResource1 ='Food' srcResource2 ='Wood' /> |
| **minValue** | Minimum trickle value when total stockpiled amount of the reference resource(s) is at the minimum. |
| **maxValue** | Maximum trickle value when total stockpiled amount of the reference resource(s) is at the maximum. |

|     |     | **srcResource1** | Reference resource for trickle value. |     |
| --- | --- | --- | --- | --- |
| **srcResource2** | _Optional_: Secondary reference resource for trickle value. |
| **minSrcValue** | Minimum combined stockpiled value of the reference resource(s) for trickle generation.<br><br>If total value is lesser than or equal than this, trickle will default to the value set in<br><br>_minValue_. |
| **maxSrcValue** | Maximum combined stockpiled of the reference resource(s) for trickle calculation.<br><br>If total value is greater or equal than this, trickle will default to the value set in _maxValue_. |
| **ResourceExchange2** | Exchanges the entirety of the stockpile of a given resource into two resources, while multiplying by the given factors. | **fromResource** | Source resource. | <Effect type ='ResourceExchange2' multiplier<br><br>\='0.50' toresource ='Wood' multiplier2 ='0.50' toresource2 ='Gold' fromresource ='Food' /> |
| **toresource** | First destination resource. |
| **multiplier** | Multiplier for first destination resource. |
| **toresource2** | Second destination resource. |
| **multiplier2** | Multiplier for second destination resource. |
| **RevertRevolution** | Undos the current revolution, returning the player to the source civilization. | **selfMsg** | String ID for UI alert and notification to be displayed for current player. | <Effect type ='RevertRevolution' selfMsg<br><br>\='112858' playerMsg ='112859' /> |
| **playerMsg** | String ID for UI alert and notification to be displayed to |

|     |     |     | other players. |     |
| --- | --- | --- | --- | --- |
| **ReplaceUnit** | Similar to _TransformUnit_, except that it forces the instantiation of a new unit and the removal of the previous one, instead of transforming directly. | **fromProtoID** | Source protoUnit. | &lt;Effect type ='ReplaceUnit' toprotoid ='WarHut' fromprotoid ='Stable' /&gt; |
| **toProtoID** | Destination protoUnit. |
| **ForbidTech** | Adds or removes a given tech from the list of forbidden techs of the current player.<br><br>Can be used to<br><br>re-enable technologies previously set explicitly as _Unobtainable_. | **amount** | If set to _1_, technology will be added into forbidden techs list, if set to _0_, it will be removed. | <Effect type ='ForbidTech' amount<br><br>\='0.00'>Howitzer&lt;/Effect&gt; |
| **ResetResendableCards** | Resets the card status of all Home City cards with _InfiniteInLastAge_ set. |     |     | &lt;Effect type ='ResetResendableCards' /&gt; |
| **SetOnTechResearchedTech** | Adds or removes technologies to be activated once a technology is researched.. | **amount** | Should be set to _1_, if technology is meant to be added; _0_, if excluded. | <Effect type ='SetOnTechResearchedTech' amount<br><br>\='1.00'>DEShipItalianVillager&lt;/Effect&gt; |
| **~~minAge~~** | ~~Unused for this effect.~~ |
| **~~maxAge~~** | ~~Unused for this effect.~~ |
| **UIAlert** | Displays an UI Alert. | **reason** | UI alert type to be displayed (_revolution_, _tradeMonopoly_, _koth_, _revertRevolution_, _papal_, _treaty_) | <Effect type ='UIAlert' reason ='Papal' selfMsg<br><br>\='-1' playerMsg ='123306' target ='Enemy' playerName ='False' duration ='1250' /> |
| **selfMsg** | String ID for UI alert and notification to be displayed for the current player. |

|     |     | **playerMsg** | String ID for UI alert and notification to be displayed to other players. Expected to receive player name by default. |     |
| --- | --- | --- | --- | --- |
| **target** | Defies to which players the alert will be displayed through a combination of the following flags: _Self_, _Ally_, _Enemy_, _All_. |
| **playerName** | When set to '_True_', player name will be displayed within UI alert string. |
| **duration** | UI alert duration in milliseconds. Set to 2500 (2.5s) by default. |
| **ResetActiveOnce** | Resets _activeOnce_ internal flag for a target shadow technology, allowing it to be triggered again. |     |     | <Effect type<br><br>\='ResetActiveOnce'>DECircleArmyShadow2Switch&lt;/E ffect&gt; |
| **TechSlot** | Sets or modifies special command panel UI slot in which technology is to be displayed. | **slot** | Special slot in the command panel in which the tech is to be displayed (_bigButton_, _bigButton2_, _bigButton3_, _mediumButton_, _mediumButton2_, _mediumButton3_, _bigHugeButton_) | <Effect type ='TechSlot' slot<br><br>\='bigButton'>ypPickConsulateTech&lt;/Effect&gt; |
| **HomeCityCardMakeInfinite** | Causes a given card to become infinitely resendable. | **tech** | Technology name of the Home City card to be reset. | &lt;Effect type ='HomeCityCardMakeInfinite' tech='DEHCShipSebastopolMortarRepeat'/&gt; |

**Data Effect Subtypes**

| **Legacy** |     |     |     |     |
| --- |     |     |     |     | --- | --- | --- | --- |
| **Type** | **Description** | **Target** | **Attributes** |     |
| **Hitpoints** | ProtoUnit Hitpoints. | _ProtoUnit_ |     |     |
| **~~Scale~~** |     | _~~ProtoUnit~~_ |     |     |
| **LOS** | ProtoUnit LOS. | _ProtoUnit_ |     |     |
| **WorkRate** | ProtoAction Work Rate. | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Rate entry unitType. |
| **Cost** | ProtoUnit or Technology Cost. | _ProtoUnit Tech_<br><br>_techWithFlag_ | **resource** | Resource name. |
| **reqTech** | _Optional_: Required technology for effect to be applied (AoE3DE: The African Royals) |
| **CarryCapacity** | ProtoUnit Resource Carry Capacity. | _ProtoUnit_ | **resource** | Resource name. |
| **~~RETIREDObstructionSize~~** |     | _~~ProtoUnit~~_ |     |     |
| **MaximumVelocity** | ProtoUnit movement speed. | _ProtoUnit_ |     |     |
| **MaximumRange** | ProtoAction Maximum Range. | _ProtoUnit_ | **action** | ProtoAction name. |
| **TrainPoints** | ProtoUnit Train Points. | _ProtoUnit_ |     |     |

| **Resource** | Player Resource Stockpile.<br><br>Only supports _Absolute_ and _Assign_ relativities properly. | _Player_ | **resource** | Resource name. |
| --- | --- | --- | --- | --- |
| **InventoryAmount** | ProtoUnit resource inventory amount. | _ProtoUnit_ | **resource** | Resource name. |
| **Damage** | ProtoAction Damage. | _ProtoUnit_ | **action** | ProtoAction name. |
| **allActions** | If set to _1_, modification will be applied to all actions within the protoUnit. |
| **~~UnusedUsedToBeUnitLine~~** |     | _~~ProtoUnit~~_ |     |     |
| **MaxResource** | Player resource cap for a given resource. Only supports _Absolute_ relativity.<br><br>Sets resource cap to the current resource stockpile plus a delta defined in the _amount_. |     | **resource** | Resource name. |
| **~~PermanentCost~~** |     | _~~ProtoUnit~~_ | **~~resource~~** | ~~Resource name.~~ |
| **Enable** | Enable/Disable ProtoUnit. | _ProtoUnit_ |     |     |
| **~~InventoryCarried~~** |     | _~~ProtoUnit~~_ | **~~resource~~** | ~~Resource name.~~ |
| **AnimationRate** | ProtoAction Animation Rate. | _ProtoUnit_ | **action** | ProtoAction name. |
| **~~HeroCost~~** |     | _~~Unknown~~_ | **~~slot~~** | ~~Unknown.~~ |

| **PopulationCap** | Player population Capacity. | _Player_ |     |     |
| --- | --- | --- | --- | --- |
| **SetCivilization** | Player Civilization. | _Player_ | **civ** | Civilization name. |
| **Market** | Market attributes. | _Player_ | **component** | Market system attribute to be modified (_BuyFactor_, _SellFactor_, _BuyDelta_, _SellDelta_, _BuyFactorSpecific_, _SellFactorSpecific_).<br><br>_BuyFactorSpecific_ and _SellFactorSpecific_ are only available from AoE3DE: The African Royals onwards) |
| **resource** | Resource for _BuyFactorSpecific_ and _SellFactorSpecific_ modification (AoE3DE: The African Royals) |
| **MaximumContained** | ProtoUnit garrison capacity, | _ProtoUnit_ |     |     |
| **MinimumRange** | ProtoAction Minimum Range. | _ProtoUnit_ | **action** | ProtoAction name. |
| **~~UpgradeLevel~~** | AoM Leftover. Deprecated | _~~ProtoUnit~~_ | **~~stat~~** | ~~AoM unit stat. Deprecated.~~ |
| **ResourceTrickleRate** | Player automatic resource trickle rate. | _Player_ | **resource** | Resource name. |
| **MinimumResourceTrickleRate** | Minimum automatic Trickle Rate for a given resource.<br><br>Only supports _Absolute_ and _Assign_ relativities properly. | _Player_ | **resource** | Resource name. |
| **MaximumResourceTrickleRate** | Maximum automatic Trickle Rate for a given resource. | _Player_ | **resource** | Resource name. |

|     | Only supports _Absolute_ and _Assign_ relativities properly. |     |     |     |
| --- | --- | --- | --- | --- |
| **DamageBonus** | ProtoAction Damage Bonus. | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Damage Bonus unit type. |
| **TributePenalty** | Player Tribute Penalty. | _Player_ |     |     |
| **PopulationCount** | ProtoUnit population count. | _ProtoUnit_ |     |     |
| **~~InventorySlot~~** |     | _~~ProtoUnit~~_ |     |     |
| **PopulationCapAddition** | ProtoUnit population cap support. | _ProtoUnit_ |     |     |
| **ActionEnable** | Enable/Disable protoAction. | _ProtoUnit_ | **action** | ProtoAction name. |
| **Lifespan** | ProtoUnit Lifespan. | _ProtoUnit_ |     |     |
| **RechargeTime** | ProtoUnit recharge time for Charged Actions. | _ProtoUnit_ |     |     |
| **BuildLimit** | ProtoUnit Build Limit. | _ProtoUnit_ |     |     |
| **TrackRating** | ProtoAction Track Rating. | _ProtoUnit_ | **action** | ProtoAction name. |
| **BuildPoints** | ProtoUnit Build Points. | _ProtoUnit_ |     |     |
| **~~HomeCityStartingUnit~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |

| **~~HomeCityTransportTime~~** |     | _~~Player~~_ |     |     |
| --- | --- | --- | --- | --- |
| **~~HomeCityTransportUnitLimit~~** |     | _~~Player~~_ |     |     |
| **~~EnableMercs~~** |     | _~~Player~~_ |     |     |
| **~~EnableCoffers~~** |     | _~~Player~~_ |     |     |
| **~~EnablePlantations~~** |     | _~~Player~~_ |     |     |
| **~~EnableTradeRouteCoin~~** |     | _~~Player~~_ |     |     |
| **~~EnableTradeRouteLOS~~** |     | _~~Player~~_ |     |     |
| **~~EnableTradeRouteTransport~~** |     | _~~Player~~_ |     |     |
| **UpdateVisual** | Forces visual updating of a given protoUnit for all its instances. | _Player_ | **unitType** | Affected unit type. |
| **UpgradeSubCivAlliance** | Deprecated in Legacy. In AoE3DE, allies with the given SubCiv and defines/increases Build Limit multiplier.<br><br>Only supports _Absolute_ relativity properly. | _Player_ | **civ** | SubCiv name. |
| **GrantsPowerDuration** | Deprecated in Legacy. In AoE3DE, as of _Knights of the Mediterranean_ DLC onwards, initiates cooldown for powers | _Player_ | **protoPower** | ProtoPower name. |

|     | which start in cooldown. |     |     |     |
| --- | --- | --- | --- | --- |
| **~~HomeCityBucketMinCount~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **~~HomeCityBucketMaxCount~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **~~HomeCityBucketCountIncrement~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **FreeHomeCityUnit** | Delivers the amount of the given protoUnit to the player at the HC gather point. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **convertSettlers** | If set to '_true_', civilian units will be converted to the civilization's main civilian unit (set through the _SettlerProtoName_ civ attribute) before being delivered (AoE3DE). |
| **CostBuildingTechs** | Changes the cost of all tech entries within a given protoUnit. | _ProtoUnit_ | **resource** | Resource name. |
| **CostBuildingUnits** | Changes the cost of all train entries within a given protoUnit. | _ProtoUnit_ | **resource** | Resource name. |
| **CostBuildingAll** | Changes the cost of all train and tech entries within a given protoUnit. | _ProtoUnit_ | **resource** | Resource name. |
| **TacticEnable** | Enables/Disables a Tactic. | _ProtoUnit_ | **tactic** | Tactic name. |
| **UnitRegenRate** | Alters unit regeneration rate for an existing entry. | _Player ProtoUnit_ | **unitType** | Regen entry unit type. Should be omitted when modifying a specific protounit, rather than a civilization regen entry (_ProtoUnit_ target) |
| **~~NativeBucketMinCount~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **~~civ~~** | ~~SubCiv name. Unknown intended usage.~~ |

| **~~NativeBucketMaxCount~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| --- | --- | --- | --- | --- |
| **~~civ~~** | ~~SubCiv name. Unknown intended usage.~~ |
| **~~NativeBucketCountIncrement~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **~~civ~~** | ~~SubCiv name. Unknown intended usage.~~ |
| **~~EnableMercs2~~** |     | _~~Player~~_ |     |     |
| **~~EnableMercs3~~** |     | _~~Player~~_ |     |     |
| **~~EnableMercs4~~** |     | _~~Player~~_ |     |     |
| **~~EnableMercs5~~** |     | _~~Player~~_ |     |     |
| **~~HomeCityBucketCountPoints~~** |     | _~~Player~~_ | **~~unitType~~** | ~~Unit Type. Unknown intended usage.~~ |
| **BlockTrainCount** | Alters or adds single-block training data (i.e. the one<br><br>used by Russians) for a given ProtoUnit. | _Player_ | **unitType** | Block train unit. |
| **unitType2** | Block train source building. |
| **AllowedAge** | ProtoUnit allowed age. | _ProtoUnit_ |     |     |
| **DamageArea** | ProtoAction damage area. | _ProtoUnit_ | **action** | ProtoAction name. |
| **~~XPTrickleRate~~** | Deprecated.<br><br>Superseded by<br><br>non-resource specific effect. | _~~Player~~_ |     |     |
| **~~MinimumXPTrickleRate~~** | Deprecated.<br><br>Superseded by<br><br>non-resource specific | _~~Player~~_ |     |     |

|     | effect. |     |     |     |
| --- | --- | --- | --- | --- |
| **~~MaximumXPTrickleRate~~** | Deprecated.<br><br>Superseded by<br><br>non-resource specific effect. | _~~Player~~_ |     |     |
| **SetAge** | Sets Player current age to _amount_ value. | _Player_ |     |     |
| **UpgradeTradeRoute** | Upgrades Trade Route to the given level. | _Player_ |     |     |
| **GathererLimit** | ProtoUnit Gatherer Limit. | _ProtoUnit_ |     |     |
| **~~SlotCount~~** | Attribute intended to be used by the AirCraft system.<br><br>Unused and not functional in AoE3. | _~~ProtoUnit~~_ |     |     |
| **FreeHomeCityMerc** | Delivers a random amount in the range of \[_amount/2, amount_\] of units of a single randomly picked protoUnit belonging to the given unitType.<br><br>Cannot be properly used with a generic UnitType, unless if _DEHCCardForcePop Check_ technology flag is set | _Player_ | **unitType** | Unit Type to be used for determining the protoUnit to be delivered. |

| **AddTrain** | Adds Train Entry to ProtoUnit at first free slot in row/page 0. | _ProtoUnit_ | **unitType** | ProtoUnit to be assigned. |
| --- | --- | --- | --- | --- |
| **HitPercent** | ProtoAction Hit Percent. | _ProtoUnit_ | **action** | ProtoAction name. |
| **DamageMultiplier** | ProtoAction Damage Multiplier. | _ProtoUnit_ | **action** | ProtoAction name. |
| **HitPercentType** | ProtoAction Critical hit type. Always adds flags, regardless of arguments. | _ProtoUnit_ | **action** | ProtoAction name. |
| **hitPercentType** | Critical hit type flag (_CriticalAttack_, _KillingBlow_, _Sweep_, _Disciple_, _CriticalDisciple_) |
| **ResearchPoints** | Technology Research Points. | _Tech_<br><br>_techWithFlag_ |     |     |
| **BuildBounty** | ProtoUnit Build Bounty. | _ProtoUnit_ |     |     |
| **PopulationCapBonus** | Additional population capacity for player. Limited to 250. | _Player_ |     |     |
| **PopulationCapExtra** | Additional population limit for player.<br><br>Limited to 50. | _Player_ |     |     |
| **RevealLOS** | Reveals all GAIA units of target unitType. | _ProtoUnit_ |     |     |
| **DamageCap** | ProtoAction Damage Cap. Automatically adjusted by _Damage_ data effect subtype for ProtoActions that | _ProtoUnit_ | **action** | ProtoAction name. |

|     | inflict Area Damage. |     |     |     |
| --- | --- | --- | --- | --- |
| **XPRate** | Multiplier to be applied over Trade Route granted resources. Applied as a multiplier over current value, regardless of relativity. | _Player_ |     |     |
| **Armor** | ProtoUnit default armor. | _ProtoUnit_ |     |     |
| **BuildingWorkRate** | ProtoUnit work rate for train and research actions. | _ProtoUnit_ |     |     |
| **ActionAdd** | Adds instance of given action to all currently existing instances of the given ProtoUnit. | _Player_ | **unitType** | Affected unitType. |
| **action** | ProtoAction name. |
| **SetCivRelation** | Consulate Civ Relation. | _Player_ | **civ** | Civilization to be used for initiating relations. If set to '_none_', relations will be ended with current civilization. |
| **FreeHomeCityUnitIfTechObtainable** | Delivers the amount of the given protoUnit to the player at the HC gather point, if the given technology is _obtainable_ or _active_.<br><br>Delivery isn't performed if the amount of new units would cause the build | _Player_ | **unitType** | ProtoUnit to be delivered |
| **tech** | Technology to be used for condition checking. |

|     | limit to exceed, unless if technology flag<br><br>_DEDoNotCheckUnitC apWhenShipping_ is set. |     |     |     |
| --- | --- | --- | --- | --- |
| **CopyUnitPortraitAndIcon** | Copies Unit and Portrait paths from protoUnit in _Target_ to given protoUnit. | _ProtoUnit_ | **unitType** | Target protoUnit for icon and portrait modification |
| **copy** | _Optional_: Defines copying mode for unit icon and portrait. Can be set to _PortraitOnly_, for only copying portrait, _IconOnly_, for only copying icon, or be left unset, to copy both into destination protoUnit. |
| **DamageForAllHandLogicActions** | ProtoAction damage for all _HandLogic_ actions in the ProtoUnit. | _ProtoUnit_ |     |     |
| **PlayerSpecificTrainLimitPerAction** | Default unit batch size. | _Player_ |     |     |
| **Definitive Edition** |     |     |     |     |
| **ActionAddAttachingUnit** | ProtoAction attaching unit. | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Attaching protoUnit to be assigned to protoAction. |
| **SpeedModifier** | Tactic Speed Modifier. | _ProtoUnit_ | **tactic** | Tactic name. |
| **Yield** | ProtoAction resource Yield. | _ProtoUnit_ | **action** | ProtoAction name. |
| **RateOfFire** | ProtoAction rate of fire. | _ProtoUnit_ | **action** | ProtoAction name. |

| **CommunityPlazaWeight** | ProtoUnit Community Plaza Worker Weight. | _ProtoUnit_ |     |     |
| --- | --- | --- | --- | --- |
| **ConversionResistance** | ProtoUnit Conversion Resistance | _ProtoUnit_ |     |     |
| **SetCivFlag** | Set current player civilization flag to the one of the given civ. | _Player_ | **civ** | Civilization name. |
| **SetCivName** | Set current player civilization name to the one of the given civ. | _Player_ | **civ** | Civilization name. |
| **RansomCostAddition** | Adds the value set in _amount_ to the cost for ransoming a hero. | _Player_ |     |     |
| **ResourceReturn** | ProtoUnit Resource Return | _ProtoUnit_ |     |     |
| **ArmorType** | ProtoUnit default armor type. | _ProtoUnit_ | **newType** | New armor type to be set to default protoUnit armor (_Hand_, _Ranged_ or<br><br>_Siege_) |
| **UpgradeAllTradeRoutes** | Upgrades all Trade Routes in the map to the given level. | _Player_ |     |     |
| **FreeHomeCityUnitByUnitCount** | Delivers the amount of the given protoUnit to the player at the HC gather point, for every owned unit belonging to the given unitType. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **countType** | UnitType to be used for counting. |
| **KillBounty** | ProtoUnit Kill Bounty. | _ProtoUnit_ |     |     |

| **EnableAutoCrateGather** | Sets/unsets _DrawnToCrates_ PU flag. | _ProtoUnit_ |     |     |
| --- | --- | --- | --- | --- |
| **FreeHomeCityUnitByTechActiveCount** | Delivers the amount of the given protoUnit to the player at the HC gather point, for every time the given technology had been activated, | _Player_ | **unitType** | ProtoUnit to be delivered |
| **tech** | Technology to be used for counting. |
| **BountyResourceOverride** | Overrides the resource of the granted kill bounty for a particular target unit type. | _Player_ | **unitType** | Affected UnitType. |
| **resource** | Resource override for granted kill bounty |
| **UnitHelpOverride** | ProtoUnit Unit Help Override unit. | _ProtoUnit_ |     |     |
| **CopyTacticAnims** | Copies animations from a source tactic to a target tactic. | _ProtoUnit_ | **fromTactic** | Source tactic. |
| **toTactic** | Destination tactic. |
| **Snare** | Sets/unsets ProtoAction _TargetSpeedBoost_ flag. | _ProtoUnit_ | **action** | ProtoAction name. |
| **ConversionDelay** | ProtoAction Conversion Delay. | _ProtoUnit_ | **action** | ProtoAction name. |
| **CopyTechIcon** | Copies icon from given technology to target technology, | _Tech_ | **tech** | Source Technology containing icon to be copied. |

| **AutoAttackType** | Tactic Auto Attack Type. | _ProtoUnit_ | **tactic** | Tactic name |
| --- | --- | --- | --- | --- |
| **unitType** | Unit Type to be used as auto-attack type. |
| **UnitRegenRateLimit** | Alter HitPoint rate limit for negative UnitRegen for a given unitType. | _Player ProtoUnit_ | **unitType** | Regen entry unit type. Should be omitted when modifying a specific protounit, rather than a civilization regen entry (_ProtoUnit_ target) |
| **ResourceIfTechObtainable** | Adjusts player Resource Stockpile, if given technology is active or obtainable.. | _Player_ | **resource** | Resource name. |
| **tech** | Technology to be used for condition checking. |
| **ActionDisplayName** | ProtoAction Display Name override. | _ProtoUnit_ | **action** | ProtoAction name. |
| **stringID** | New displayed string ID. |
| **FreeHomeCityUnitByShipmentCount** | Delivers the amount of the given protoUnit to the player at the HC gather point, for every shipment sent so far. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **includeSelf** | _Optional_: If set to '_true_', the current shipment will be included for the calculation. |
| **EnableSharedBuildLimit** | Sets/Unsets _UseSharedBuildLimit_ PU flag. | _ProtoUnit_ |     |     |
| **SharedBuildLimitUnit** | ProtoUnit Shared Build Limit Unit. | _ProtoUnit_ | **unitType** | ProtoUnit to be set as Shared Build Limit Unit. |
| **AddSharedBuildLimitUnitType** | Adds a Shared Build Limit Unit Type entry to PU. | _ProtoUnit_ | **unitType** | UnitType to be added to protoUnit Shared Build Limit UnitTypes list. |
| **PartisanUnit** | ProtoUnit Partisan UnitType and | _ProtoUnit_ | **unitType** | ProtoUnit to be used for Partisan spawning. |

|     | Partisan count.<br><br>Requires _Partisans_ to be set in civilization data. |     |     |     |
| --- | --- | --- | --- | --- |
| **SetUnitType** | Sets/unsets UnitType. | _ProtoUnit_ | **unitType** | UnitType name. |
| **FreeHomeCityUnitRandom** | Ships the given amount of randomly selected units either belonging to the given unitType or, if it's not set, to the list of protoUnits. | _Player_ | **unitType** | UnitType to which all randomly selected units will belong to. |
| Content:<br><br>**Unit** | List of units from which randomly selected units will be picked, if _unitType_ isn't set. Should be defined within the content of XML and nested within a _Units_ tag, |
| **EnableDodge** | Sets/unsets _CanDodgeAttacks_ PU flag. | _ProtoUnit_ |     |     |
| **DodgeChance** | ProtoUnit Dodge Chance. | _ProtoUnit_ |     |     |
| **SetNextResearchFree** | Sets/unsets _NextResearchIsFree_ PU flag. | _ProtoUnit_ |     |     |
| **EnableAutoFormations** | Unsets/sets _NonAutoFormedUnit_ PU flag. | _ProtoUnit_ |     |     |
| **SharedSettlerBuildLimit** | Sets/unsets _SettlerBuildLimit_ PU flag. | _ProtoUnit_ |     |     |
| **CalculateInfluenceCost** | Calculates Influence cost for protoUnit, based on influence | _ProtoUnit_ | **calcType** | Calculation type to be used. Supports only one valid value, currently (1). |

|     | rates defined on civilization data. |     |     |     |
| --- | --- | --- | --- | --- |
| **ArmorSpecific** | Sets specific armor type for protoUnit, allowing for multiple armor types in the same unit | _ProtoUnit_ | **newtype** | Armor type value to be set or changed. |
| **BuildBountySpecific** | ProtoUnit resource-specific Build Bounty. | _ProtoUnit_ | **resource** | Resource name. |
| **LivestockExchangeRate** | Changes Livestock Market Exchange Rate for a given resource. | _Player_ | **resource** | Resource name. |
| **LivestockRecoveryRate** | Changes Livestock Market Recovery Rate for a given resource. | _Player_ | **resource** | Resource name. |
| **RevealEnemyLOS** | Reveals all current instances of given unitType belonging to all enemy players. | _Player_ | **unitType** | UnitType to be revealed; |
| **GatheringMultiplier** | ProtoAction Gathering Multiplier. | _ProtoUnit_ | **action** | ProtoAction name. |
| **DisplayedRange** | ProtoUnit Displayed Range. | _ProtoUnit_ |     |     |
| **SquareAura** | Sets/Unsets _RangeDisplayedAsSq uare_ PU flag. | _ProtoUnit_ |     |     |

| **ProtoActionAdd** | Instantiates and assigns given protoAction from given protoUnit to target protoUnit(s). | _ProtoUnit_ | **protoAction** | ProtoAction to be instantiated. |
| --- | --- | --- | --- | --- |
| **unitType** | Source unit for protoAction data. |
| **ResourceReturnRate** | ProtoUnit Resource Return Rate. | _ProtoUnit_ | **resource** | Resource name. |
| **ResourceReturnRateTotalCost** | Sets/Unsets _ResourceReturnRate TotalCost_. | _ProtoUnit_ |     |     |
| **FullCapacityMultiplier** | ProtoAction Full Capacity Multiplier. | _ProtoUnit_ | **action** | ProtoAction name. |
| **LivestockMinCapacityKeepUnit** | Sets whether or not Herdables should be kept after sold at the Livestock Market, being reverted to units with minimal resource capacity. | _Player_ |     |     |
| **ResourceByKBStat** | Adjusts player Resource Stockpile by the value of a particular KB Stat multiplied by the given _amount_. | _Player_ | **resource** | Resource name. |
| **kbStat** | KB Stat to be used for the effect, selected from a subset of the available KB Stats used by the game. A list of the supported KB Stats for tech effects can be found at the end of the document. |
| **NextAgeUpDoubleEffect** | When set, causes Data/Data2 effects in next AgeUp technology to have double effect, if applicable. | _Player_ |     |     |

| **NextAgeUpTimeFactor** | Factor to be applied to the research time of next AgeUp technology. | _Player_ |     |     |
| --- | --- | --- | --- | --- |
| **NextAgeUpTimeAbsolute** | Linear amount to be applied to the research time of next AgeUp technology. | _Player_ |     |     |
| **SplitCost** | Splits given protoUnit cost resource into given resource, using _amount_ as rate.<br><br>Replaces base cost for destination resource. | _ProtoUnit_ | **resource** | Source resource name. |
| **resource2** | Target resource name. |
| **PlacementRulesOverride** | Replaces protoUnit placementRules by the ones of given protoUnit. | _ProtoUnit_ | **unitType** | UnitType containing new placementRules information |
| **ResourceByUnitCount** | Adjusts player Resource Stockpile by the total amount of owned units of a particular unitType, multiplied by the given _amount_. | _Player_ | **resource** | Resource name. |
| **unitType** | UnitType to be used for calculation. |
| **UnitRegenAbsolute** | Alters unit linear regeneration rate for an existing entry. | _Player_ | **unitType** | Regen entry unitType. |
| **NextAgeUpCostAbsolute** | Linear amount to be applied to the | _Player_ |     |     |

|     | research cost of next AgeUp technology. |     |     |     |
| --- | --- | --- | --- | --- |
| **AgeUpCostAbsoluteKillXPFactor** | Factor by which each XP point earned through kill bounties will contribute towards the next age up cost discount. | _Player_ |     |     |
| **AgeUpCostAbsoluteRateCap** | Rate limit to the resulting AgeUp cost after applying age-up discount. | _Player_ |     |     |
| **AddContainedType** | Adds a Contained Type entry to ProtoUnit. | _ProtoUnit_ | **unitType** | Unit Type name. |
| **GarrisonBonusDamage** | Sets or changes protoAction garrison bonus damage for a given unitType. | _ProtoUnit_ | **unitType** | Unit Type name. |
| **MaintainTrainPoints** | ProtoAction Maintain Train Points. | _ProtoUnit_ | **action** | ProtoAction name. |
| **TacticArmor** | Tactic armor override value. | _ProtoUnit_ | **tactic** | Tactic name. |
| **armorType** | Armor override type to be changed |
| **DeadTransform** | ProtoUnit Dead Transform. | _ProtoUnit_ |     |     |
| **DeadTransformBuildLimit** | Sets/unsets _DeadTransformBuildL imit_ PU flag. | _ProtoUnit_ |     |     |

| **DamageForAllRangedLogicActions** | ProtoAction damage for all _RangedLogic_ actions in the ProtoUnit. | _ProtoUnit_ |     |     |
| --- | --- | --- | --- | --- |
| **PowerROF** | Alters Cooldown for a given protoPower.<br><br>Can only be used over protoPowers which use global cooldown, instead of per-unit cooldown. | _Player_ | **protoPower** | ProtoPower name. |
| **FreeRepair** | Sets/unsets<br><br>_FreeRepair_ PU flag. | _ProtoUnit_ |     |     |
| **RemoveUnits** | Removes all units belonging to a particular unitType. | _Player_ | **unitType** | Unit Type to be removed. |
| **PowerDataOverride** | Copies protoPower icon, name and rollover from a source protoPower to a target protoPower. | _Player_ | **fromProtoPower** | Source protoPower. |
| **toProtoPower** | Target protoPower. |
| **UseRandomNames** | Sets/unsets _HeroName1_ or _HeroName2_ PU flags. | _ProtoUnit_ |     |     |
| **TrainBatchSize** | ProtoUnit Train Batch Size. | _ProtoUnit_ |     |     |
| **AuxRechargeTime** | ProtoUnit recharge time for Aux/Secondary Charged Actions. | _ProtoUnit_ |     |     |

| **SelfDamageMultiplier** | ProtoAction Self Damage Multiplier. | _ProtoUnit_ | **action** | ProtoAction name. |
| --- | --- | --- | --- | --- |
| **InventoryRate** | Inventory Rate for Gather protoAction at a given unitType. | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Rate entry unitType. |
| **TradeMonopoly** | Initiates Trade Monopoly, if allowed. | _Player_ |     |     |
| **InitialTactic** | ProtoUnit Initial/Default tactic | _ProtoUnit_ |     |     |
| **FreeHomeCityUnitTechActiveCycle** | Delivers a variable cyclical amount of the given protoUnit to the player at the HC gather point for every time the effect is triggered. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **tech** | Technology to be used as reference for calculation. |
| **SetForceFullTechUpdate** | Sets/unsets _ForceFullTechUpdate_ PU flag. | _ProtoUnit_ |     |     |
| **ResourceAsCrates** | Delivers a given resource amount as crates, using default game crates. | _Player_ | **resource** | Resource name. |
| **reqTech** | _Optional_: Required technology for effect to be applied. |
| **ModifyRate** | Modifies protoAction _ModifyMultiplier_ or _ModifyAmount_. | _ProtoUnit_ | **action** | ProtoAction name. |
| **BuildLimitIncrement** | ProtoUnit Build Limit Increment. | _ProtoUnit_ |     |     |

| **NextAgeUpCostAbsoluteShipmentRate** | Factor by which each shipment sent in the current age will contribute towards the next age up cost discount. | _Player_ |     |     |
| --- | --- | --- | --- | --- |
| **NextAgeUpTimeFactorShipmentRate** | Factor by which each shipment sent in the current age will contribute towards the next age up time reduction. | _Player_ |     |     |
| **FreeBuildRate** | Build protoAction work rate towards free buildings (i.e. buildings placed by _AbstractFreeBuilder_ units) | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Rate entry unitType. |
| **SetForceFullTechUpdateTeam** | Sets/unsets _ForceFullTechUpdate Team_ PU flag. | _ProtoUnit_ |     |     |
| **FreeBuildPoints** | ProtoUnit Free Build Points. | _ProtoUnit_ |     |     |
| **VeterancyEnable** | Sets/unsets _ExperienceUnit_ PU flag. | _ProtoUnit_ |     |     |
| **VeterancyBonus** | Assigns or modifies a particular veterancy bonus for a protoUnit. | _ProtoUnit_ | **rank** | Rank of veterancy bonus data to be modified. |
| **modifyType** | _ModifyType_ of the _VeterancyModify_ entry to be modified. |
| **InvestmentAmount** | Modifies the default investment value. | _Player_ |     |     |

| **InvestmentCap** | Modifies the maximum investment value. | _Player_ |     |     |
| --- | --- | --- | --- | --- |
| **InvestmentEnable** | Enables/Disables resource investments. | _Player_ |     |     |
| **AutoGatherBonus** | Sets global multiplier to be applied to all autogather actions. | _Player_ |     |     |
| **FakeConversion** | Sets/unsets _FakeConversion_ protoUnit flag. | _ProtoUnit_ |     |     |
| **ProtoUnitFlag** | Sets/unsets a given protoUnit flag through its internal ID | _ProtoUnit_ | **flagID** | Internal protoUnit flag ID. |
| **PopulationLimit** | Modifies base population limit for the current player. Set to 200, by default. | _Player_ |     |     |
| **PopulationExtraLimit** | Modifies maximum population limit increment, which can be added through tech effects or specific _DanceBonus_ types. | _Player_ |     |     |
| **PopulationLimitDelta** | Applies a delta to current total population limit. Can be set to a negative value. | _Player_ |     |     |

| **TradeRouteBonus** | Sets/modifies additional resource amount to be granted to the current player once trader passes through a trade route TP. | _Player_ | **resource** | Resource name. |
| --- | --- | --- | --- | --- |
| **TradeRouteBonusTeam** | Sets/modifies additional resource amount to be granted to the entire current player's team once trader passes through a trade route TP. | _Player_ | **resource** | Resource name. |
| **BountySpecificBonus** | Sets/modifies additional resource amount to be granted once an unit which has resource-specific bounty is killed. | _Player_ | **resource** | Resource name. |
| **EnableTechXPReward** | Enables/disables XP rewards for researching technologies and sending shipments. | _Player_ |     |     |
| **ResourceIfTechActive** | Adjusts player Resource Stockpile, if given technology is active, specifically. | _Player_ | **resource** | Resource name. |
| **tech** | Technology to be used for condition checking. |
| **MarketReset** | Resets global market rates for all players. | _Player_ |     |     |

| **TechCostAbsolute** | Adjust directly cost discount to be applied to technologies with the _DEPlayerTechCostAb solute_ flag set. | _Player_ |     |     |
| --- | --- | --- | --- | --- |
| **TechCostAbsoluteBountyRate** | Adjusts the factor in which build bounty will contribute to the cost discount of techs with the _DEPlayerTechCostAb solute_ flag set. | _Player_ |     |     |
| **SendRandomCard** | Immediately sends and applies a randomly selected card among the available valid cards. | _Player_ |     |     |
| **InvestResource** | Adds given resource amount to resource investment pool. | _Player_ | **resource** | Resource name. |
| **RechargeInit** | Sets whether or not primary charged ability will start at charged state once unit is created. | _ProtoUnit_ |     |     |
| **AuxRechargeInit** | Sets whether or not secondary charged ability will start at charged state once unit is created. | _ProtoUnit_ |     |     |

| **DamageTimeoutTrickle** | Player automatic resource trickle rate to be granted if player hasn't taken any damage from<br><br>non-GAIA foes for the given time | _Player_ | **resource** | Resource name. |
| --- | --- | --- | --- | --- |
| **timeout** | Amount of time, in seconds, in which the player should not have received any damage from non-GAIA sources, in order for trickle to be applied. |
| **RevealMap** | Explores the entire map, without giving LOS. | _Player_ |     |     |
| **ScoreValue** | ProtoUnit Score Value. | _ProtoUnit_ |     |     |
| **SubCivAllianceCostMultiplier** | Multiplier to be applied over<br><br>auto-built TP cost. | _Player_ |     |     |
| **SubCivLOS** | ProtoUnit SubCivLOS. | _ProtoUnit._ |     |     |
| **AttackPriority** | Adjusts the attack priority for a given target unitType for a specific tactic. | _ProtoUnit_ | **tactic** | Tactic name. |
| **unitType** | Target unitType to be affected. |

**Data2 Effect Subtypes**

| **Legacy** |     |     |     |     |
| --- |     |     |     |     | --- | --- | --- | --- |
| **Type** | **Description** | **Target** | **Attributes** |     |
| **WorkRateSpecific** | ProtoAction Work Rate | _ProtoUnit_ | **action** | ProtoAction name. |

|     | for a particular resource. |     | **unitType** | Rate entry unitType. |
| --- | --- | --- | --- | --- |
| **resource** | Rate entry resource. |
| **FreeHomeCityUnitShipped** | Delivers the amount of the given protoUnit to the player at the HC gather point, containing a given amount of another unit. | _ProtoUnit_ | **unitType** | ProtoUnit to be delivered. |
| **unitType2** | ProtoUnit to be contained within delivered units. |
| **amount2** | Amount of contained units per delivered unit. |
| **Definitive Edition** |     |     |     |     |
| **YieldSpecific** | ProtoAction Resource Yield for a particular resource | _Player_ | **action** | ProtoAction name. |
| **unitType** | Rate entry unitType. |
| **resource** | Rate entry resource. |
| **FreeHomeCityUnitResource** | Delivers the amount of the given protoUnit to the player at the HC gather point, while increasing the resource inventory of the unit for a given resource by a given amount. | _Player_ | **unitType** | ProtoUnit to be delivered. |
| **resource** | Resource name |
| **resValue** | Additional resource amount. |
| **FreeHomeCityUnitByUnitCount** | Delivers the amount of the given protoUnit to the player at the HC gather point, for every owned unit belonging to the given unitType, with a limit on the | _Player_ | **unitType** | ProtoUnit to be delivered |
| **countType** | UnitType to be used for counting. |
| **unitCap** | Maximum amount of units to be delivered. |

|     | maximum amount of units to be delivered. |     |     |     |
| --- | --- | --- | --- | --- |
| **BountyResourceOverride** | Overrides the resource or assigns an additional one for the granted kill bounty for a particular target unit type. | _Player_ | **unitType** | Affected UnitType. |
| **resource** | Resource override for granted kill bounty |
| **extraBounty** | _Optional_: If set to '_true_', bounty override entries will grant additional resources. |
| **bountyRate** | _Optional_: Resource percentage rate over the original XP<br><br>_KillBounty_ for new resource entry. |
| **FreeHomeCityUnitByShipmentCountResource** | Delivers the amount of the given protoUnit to the player at the HC gather point, for every shipment sent so far, while increasing the resource inventory of the unit for a given resource by a given amount. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **includeSelf** | _Optional_: If set to '_true_', the current shipment will be included for the calculation. |
| **resource** | Resource name |
| **resValue** | Additional resource amount. |
| **GatherResourceOverride** | Sets Resource Override for a particular Gather ProtoAction. | _ProtoUnit_ | **action** | ProtoAction name. |
| **unitType** | Rate entry unitType. |
| **resource** | Rate entry resource. |
| **EmpowerEnable** | Enables a particular empower entry within an _Empower_ protoAction. | _ProtoUnit_ | **action** | ProtoAction name. |
| **empowerType** | Target empowering type (_self_, _enemy_, _gaia_). |
| **unitType** | Target empowering unitType. |
| **EmpowerModify** | Modifies a given<br><br>_EmpowerRate_ in a | _ProtoUnit_ | **action** | ProtoAction name. |

|     | particular empower entry within an _Empower_ protoAction. |     | **empowerType** | Target empowering type (_self_, _enemy_, _gaia_). |
| --- | --- | --- | --- | --- |
| **unitType** | Target empowering unitType. |
| **modifyType** | _ModifyType_ of the _EmpowerRate_ to be modified |
| **ResourceByKBStat** | Adjusts player Resource Stockpile by the value of a particular KB Stat multiplied by the given _amount_, within the set limit for granted resources. | _Player_ | **resource** | Resource name. |
| **kbStat** | KB Stat to be used for the effect, selected from a subset of the available KB Stats used by the game |
| **kbParamResource** | _Optional_: KB Stat resource parameter for supported KB Stats that can take a resource ID as parameter. |
| **kbParamSubCiv** | _Optional_: KB Stat resource parameter for supported KB Stats that can take a civ ID as parameter. |
| **resourceCap** | _Optional_: Maximum amount of resources to be granted |
| **FreeHomeCityUnitByKBStat** | Delivers the amount of the given protoUnit to the player at the HC gather point multiplied by the value of given KB Stat value, within the set limit for shipped units. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **kbStat** | KB Stat to be used for the effect, selected from a subset of the available KB Stats used by the game |
| **unitCap** | _Optional_: Maximum amount of units to be delivered. |
| **ResourceByUnitCount** | Adjusts player Resource Stockpile by the total amount of owned units of a particular unitType, multiplied by the given _amount_. | _Player_ | **resource** | Resource name. |
| **unitType** | UnitType to be used for calculation. |
| **includeDead** | _Optional_: If set to '_true_', unit count will also account for dead units. |
| **EmpowerArea** | Modifies the effective area of an empower | _ProtoUnit_ | **action** | ProtoAction name. |

|     | entry within an<br><br>_Empower_ protoAction. |     | **empowerType** | Target empowering type (_self_, _enemy_, _gaia_). |
| --- | --- | --- | --- | --- |
| **unitType** | Target empowering unitType. |
| **FreeHomeCityUnitToGatherPoint** | Delivers the amount of the given protoUnit to the player at an instance of the given unitType to be used as gatherPoint | _Player_ | **unitType** | ProtoUnit to be delivered |
| **gpUnitType** | UnitType to be used as alternative gather point. |
| **resource** | _Optional_: Resource name |
| **resValue** | _Optional_: Additional resource amount. |
| **FreeHomeCityUnitByKBQuery** | Delivers the amount of the given protoUnit to the player at the HC gather point multiplied by the result a KB Query, within the set limit for shipped units. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **queryUnitType** | UnitType to be queried. |
| **queryState** | KB Query state flags (_Building_, _Alive_, _Dead_, _Queued_, _Any_). Flags can be combined |
| **unitCap** | Maximum amount of units to be delivered. |
| **FreeHomeCityUnitResourceIfTechObtainable** | Delivers the amount of the given protoUnit to the player at the HC gather point, if the given technology is _obtainable_ or _active_, while changing the resource storage of delivered units. | _Player_ | **unitType** | ProtoUnit to be delivered |
| **tech** | Technology to be used for condition checking. |
| **resource** | _Optional_: Resource name |
| **resValue** | _Optional_: Additional resource amount. |
| **ResourceByKBQuery** | Adjusts player Resource Stockpile by the result a KB Query multiplied by the given _amount_, within the set limit for granted resources. | _Player_ | **resource** | Resource name. |
| **queryUnitType** | UnitType to be queried. |
| **queryState** | KB Query state flags (_Building_, _Alive_, _Dead_, _Queued_, _Any_). Flags can be combined |

|     |     |     | **resourceCap** | _Optional_: Maximum amount of resources to be granted |
| --- | --- | --- | --- | --- |
| **ResourceAsCratesByShipmentCount** | Delivers a given resource amount as crates, using default game crates, for every shipment sent so far | _Player_ | **resource** | Resource name. |
| **reqTech** | _Optional_: Required technology for effect to be applied. |
| **includeSelf** | _Optional_: If set to '_true_', the current shipment will be included for the calculation. |
| **CopyUnitPortraitAndIcon** | Copies Unit and Portrait paths from protoUnit in _Target_ to given protoUnit. | _ProtoUnit_ | **unitType** | Target protoUnit for icon and portrait modification |
| **copy** | _Optional_: Defines copying mode for unit icon and portrait. Can be set to _PortraitOnly_, for only copying portrait, _IconOnly_, for only copying icon, or be left unset, to copy both into destination protoUnit. |
| **skinID** | Skin ID to which the icon and portrait will be assigned. |
| **BountyResourceExtra** | Assigns an additional bounty override for the granted kill bounty for a particular target unit type. | _Player_ | **unitType** | Affected UnitType. |
| **resource** | Resource override for granted kill bounty |
| **priority** | Priority to be used for additional bounty override, in case the given unit type already has bounty overrides assigned to it, directly or indirectly. The lower the _priority_ value, the higher the priority. |
| **bountyRate** | _Optional_: Resource percentage rate over the original XP<br><br>_KillBounty_ for new resource entry. |
| **FreeHomeCityUnitResourceIfTechActive** | Delivers the amount of the given protoUnit to the player at the HC gather point, if the given technology is _active_, specifically, while changing the resource storage of | _Player_ | **unitType** | ProtoUnit to be delivered |
| **tech** | Technology to be used for condition checking. |
| **resource** | _Optional_: Resource name |
| **resValue** | _Optional_: Additional resource amount. |

|     | delivered units. |     |     |     |
| --- | --- | --- | --- | --- |
| **UpgradeAllTradeRoutes** | Upgrades all Trade Routes in the map to the given level. | _Player_ | **landTech** | Technology to be applied for Land trade routes, in case current technology is in a Naval or River trade route. |
| **waterTech** | Technology to be applied for Naval trade routes, in case current technology is in a Land or River trade route. |
| **riverTech** | Technology to be applied for River trade routes, in case current technology is in a Land or Naval trade route. |

**Appendix**

| **Supported KBStats for Tech Effects** |     |     |
| --- |     |     | --- | --- |
| **Name** | **Parameter** | **Description** |
| **enemyUnitsKilled** | **\-** | Enemy units killed by the current player. |
| **enemyBuildingsKilled** | **\-** | Enemy buildings destroyed by the current player. |
| **unitsLost** | **\-** | Units lost by the current player. Doesn't account for deleted units. |
| **buildingsLost** | **\-** | Buildings lost by the current player. Doesn't account for deleted buildings. |
| **tradeProfit** | Resource ID | Total trade route income for the current player, for either the given resource, if parameter is set, or all resources |
| **totalMinedResources** | **\-** | Total amount of resources obtained from objects of type _MinedResource_ or<br><br>_LogicalTypeAccumulateMinedResources_. |
| **unitsKilledCost** | **\-** | Total cost of all units killed by the current player; |
| **buildingsKilledCost** | **\-** | Total cost of all buildings destroyed by the current player; |
| **totalTradingPostTrickleIncome** | Resource ID | Total trickle income (i.e. AutoGather income) from Trading Posts route for the current player, for either the given resource, if parameter is set, or all resources |
| **villagersLost** | **\-** | Total amount of villagers (i.e. units of _LogicalTypeLandEconomy_ unitType) lost by the player. |
| **herdablesLost** | **\-** | Total amount of herdables lost by the player. |
| **teamSubCivAllianceLevel** | Civilization ID | Alliance level (number of Trading Posts plus Alliance Level set by technologies) for the current player's team. |
| **totalTechReward** | **\-** | Total reward value for technologies researched so far and shipments sent so |

|     |     | far, even if XP rewards for technologies aren't enabled. |
| --- | --- | --- |
| **costUnitsTrained** | Resource ID | Total cost of all units trained by the current player, for either the given resource, if parameter is set, or all resources |
| **treasureResources** | Resource ID | Total income from all treasures collected by the current player, for either the given resource, if parameter is set, or all resources |
| **totalHuntedResources** | \-  | Total amount of resources obtained from objects of type _Huntable_. |

| **Internal ProtoUnitFlags and IDs** |     |     |     |     |     |     |     |     |     |     |     |
| --- |     |     |     |     |     |     |     |     |     |     |     | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **0** | **cHasGatherData** | **50** | **cGarrisonBonus** | **100** | **cRotateable** | **150** | **cSelectOnTrain** | **200** | **cGatherableByAllies** | **250** | **cDamageTrees** |
| **1** | **cPlayerPlaceable** | **51** | **cCanAttackDisabled Units** | **101** | **cScalable** | **151** | **cPlaceAnywhereRul es** | **201** | **cShowAutoGatherAbsoluteInf o** | **251** | **cTacticArmorUseBaseIfNotSet** |
| **2** | **cCollideable** | **52** | **cUnused1** | **102** | **cGodPowerExclusio n** | **152** | **cForcePopulationIm pactWhenPlaced** | **202** | **cDoTacticToSameUnitType** | **252** | **cTransformPropagateChargeState** |
| **3** | **cTieToGround** | **53** | **cOrientUnitWithGrou nd** | **103** | **cInvulnerable** | **153** | **cCanAutoHeal** | **203** | **cDoNotDeleteDeadHuntOnPla cement** | **253** | **cHerdableForceOriginalResource** |
| **4** | **cImmoveable** | **54** | **cAlwaysFullColorAs Cursor** | **104** | **cDeadReplaceOnlyO nTimeout** | **154** | **cExcludeFromMove AllMilitary** | **204** | **cCannotSnare** | **254** | **cNativePreview** |
| **5** | **cDisplayHitpointsIfSelected** | **55** | **cConstrainOrientatio n** | **105** | **cSingleGatherer** | **155** | **cShowAutoGatherRa te** | **205** | **cBaseSpeedRunAnim** | **255** | **cSocketSubCivAlliance** |
| **6** | **cTieToWaterSurface** | **56** | **cPaintTextureWhenP lacing** | **106** | **cInvulnerableIfGaia** | **156** | **cCanTargetButTakes NoDamage** | **206** | **cHCEconomicGatherPointOnl y** |     |     |
| **7** | **cGenerateWaterSplashes** | **57** | **cInitialGarrisonOnly** | **107** | **cCorpseDecays** | **157** | **cUsesExtraWorkerSl ot** | **207** | **cDeadTransformBuildLimit** |
| **8** | **cVisibleUnderFog** | **58** | **cWallBuild** | **108** | **cCantBeSlowed** | **158** | **cForceTrainAtBaseTr ainPoints** | **208** | **cForceGatherSiteResource** |
| **9** | **cVisibleUnderFogIfGaia** | **59** | **cShowGarrisonButto n** | **109** | **cHideHitpointsIfGaia** | **159** | **cAllowOverPopCap** | **209** | **cUseStaticFarmingAnims** |
| **10** | **cProjectile** | **60** | **cCommandable** | **110** | **cFlareOnFullyBuilt** | **160** | **cShowTactics** | **210** | **cUseDanceActions** |
| **11** | **cHasLOS** | **61** | **cKillOnAnimLoop** | **111** | **cAnnounceFoundati onStarted** | **161** | **cEnterHotkeyContex t** | **211** | **cGatherGarrisonToggle** |

| **12** | **cSelectable** | **62** | **cAlwaysCheckCollisi ons** | **112** | **cVictoryBuilding** | **162** | **cCivSpecificText** | **212** | **cHerdablesIgnoreGatherPoint** |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **13** | **cDieAtZeroHitpoints** | **63** | **cAreaDamageConsta nt** | **113** | **cBurnable** | **163** | **cAlwaysAllowOverP opCap** | **213** | **cFreeRepair** |
| **14** | **cDieAtZeroResources** | **64** | **cNoIdleActions** | **114** | **cMutateDopples** | **164** | **cNeverCountDeathA sLoss** | **214** | **cCountHerdableAsGatherer** |
| **15** | **cValidateResourceInventory** | **65** | **cProjectileDamage** | **115** | **cUseObstructionOn Minimap** | **165** | **cBuildingShowTactic s** | **215** | **cGatherersContributeToReso urceRate** |
| **16** | **cHasGatherPoint** | **66** | **cGarrisonSpeedBon us** | **116** | **cUseAlignedObstruc tionOnMinimap** | **166** | **cAllowTrainingOnWa ter,** | **216** | **cAllowGatheringWhenFull** |
| **17** | **cBloodOnDeath** | **67** | **cPlaceAnywhere** | **117** | **cInvalidTownBellLoc ation** | **167** | **cGatherFromTrees** | **217** | **cShowAreaHealRate** |
| **18** | **cNonSolid** | **68** | **cProjectileTerrainOnl y** | **118** | **cRenderAfterWater** | **168** | **cDrawnToCrates** | **218** | **cForceFullTechUpdate** |
| **19** | **cObscuresUnits** | **69** | **cPlayerOwnsObstru ction** | **119** | **cDontSortAlphaPoly s** | **169** | **cDisplayRange** | **219** | **cUseAnimalsLabel** |
| **20** | **cObscuredByUnits** | **70** | **cPlaceSocketWhenP lacing** | **120** | **cDontMarkExtraFog** | **170** | **cInvulnerableToArea Damage** | **220** | **cDanceActionNoWorkers** |
| **21** | **cNotObscuredByUnitsAsFo undation** | **71** | **cAlwaysShowAsSoc ket** | **121** | **cVisibleUnderFogOn lyAfterSeen** | **171** | **cDoNotDragSelectWi thUnits** | **221** | **cChargeMoveAnim** |
| **22** | **cFlattenGround** | **72** | **cStartOnAnimationU pdate** | **122** | **cRMCanRotate** | **172** | **cTownDefenseUnit** | **222** | **cSocketFreeBuilding** |
| **23** | **cUseProtoUnitMinimapColor** | **73** | **cStartOnNoUpdate** | **123** | **cKnockoutDeath** | **173** | **cDontTrainInBatches** | **223** | **cCannotAttackIfGaia** |
| **24** | **cFadeInOnCreation** | **74** | **cDeadReplacement WhenDestroyed** | **124** | **cVariationLocked** | **174** | **cKillIfConverted** | **224** | **cApplyFlagOverrideIfGaia** |
| **25** | **cShowOnMinimap** | **75** | **cAnnounceConversi on** | **125** | **cExperienceUnit** | **175** | **cShowUnitResource ActionRates** | **225** | **cForceFullTechUpdateTeam** |
| **26** | **cAutoFormedUnit** | **76** | **cSelectWithObstruct ion** | **126** | **cFadeOutDecalOnDe ath** | **176** | **cSettlerBuildLimit** | **226** | **cInvestmentBuilding** |
| **27** | **cRotateObstruction** | **77** | **cDestroyUnderBuildi ng** | **127** | **cAnnounceDestructi on** | **177** | **cUseSharedBuildLim it** | **227** | **cFakeConversion** |
| **28** | **cCreateUnitGroupAutomatic ally** | **78** | **cConvertOnStartBuil d** | **128** | **cBattleMusicTrigger** | **178** | **cInflictsNoDamage** | **228** | **cAllowRebuildInGrouping** |
| **29** | **cCollidesWithProjectiles** | **79** | **cPlaceAsFoundation** | **129** | **cRotateInPlace** | **179** | **cDisplayDecoyInfo** | **229** | **cForceUpdateVisualWhenCnv erted** |
| **30** | **cFadeInOnBuild** | **80** | **cConvertToGaiaAtZe roHitpoints** | **130** | **cAdjustPositionOnT errainCollision** | **180** | **cCanDodgeAttacks** | **230** | **cDisplaySocketPanel** |

| **31** | **cAlphaFadeLifespan** | **81** | **cMakeUnbuiltAtZero Hitpoints** | **131** | **cHeroName1** | **181** | **cNextResearchIsFre e** | **231** | **cTeamKillBounty** |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **32** | **cWanders** | **82** | **cExcludeFromPlayte st** | **132** | **cHeroName2** | **182** | **cDisableBigButtonUI** | **232** | **cMinimapDisplayOnTop** |
| **33** | **cFlyingUnit** | **83** | **cSolidFoundation** | **133** | **cHideCostFromDetai lHelp** | **183** | **cUnitTransformFree** | **233** | **cRepairable** |
| **34** | **cHeightBob** | **84** | **cHideGarrisonFlag** | **134** | **cPreventsWallBuildi ng** | **184** | **cUseFarmingAnims** | **234** | **cKillSocketWhenDestroyed** |
| **35** | **cSearchable** | **85** | **cDoppleOnlyWhenD ead** | **135** | **cColonyBuilding** | **185** | **cBuiltWithSeedingA nim** | **235** | **cTeamBuildLimit** |
| **36** | **cUnlimitedSupply** | **86** | **cDirectProjectile** | **136** | **cStartingColonyBuil ding** | **186** | **cRangeDisplayedAs Square** | **236** | **cIgnoreDefaultEjectTimeout** |
| **37** | **cFaceOutwards** | **87** | **cForceBuildingData** | **137** | **cColonyPlacementC enter** | **187** | **cAllowSocketPlacem ent** | **237** | **cQueueEjectActions** |
| **38** | **cSnapPlacement** | **88** | **cDecalStickToWater Surface** | **138** | **cColonyPlacementL** | **188** | **cOptionalSocketPlac ement** | **238** | **cSharedGarrison** |
| **39** | **cStartEnabled** | **89** | **cAllowAutoGarrison** | **139** | **cCreateUniqueInstan ce** | **189** | **cForceInfluenceRate** | **239** | **cDisplayMinimumRange** |
| **40** | **cSplitAtMaxInventory** | **90** | **cOverrideInitialGarri son** | **140** | **cUniqueInstance** | **190** | **cAllowPlacementOnI ce** | **240** | **cAllowAlliedGarrison** |
| **41** | **cFadeOutDuringDeathAnima tion** | **91** | **cTownBellButton** | **141** | **cTileAlignPlacement** | **191** | **cGatherableWhenSo cketed** | **241** | **cDetonationDeath** |
| **42** | **cForceToGaia** | **92** | **cMeteredGarrison** | **142** | **cNugget** | **192** | **cDoNotQueue** | **242** | **cBuildingExtendedDeathAnim** |
| **43** | **cYawDuringMovement** | **93** | **cRevealFoundation** | **143** | **cWorldToolTip** | **193** | **cMagnetDoesNotLoc kUnits** | **243** | **cEnforceBigButtonUI** |
| **44** | **cMarketAbility** | **94** | **cMinimapColorXfrm NonGaia** | **144** | **cOrientWithRiver** | **194** | **cUseTacticArmorOv erride** | **244** | **cDeploymentUngarrison** |
| **45** | **cGivesLOSToAll** | **95** | **cApplyHandicapTrai ning** | **145** | **cTCBuildLimit** | **195** | **cResourceReturnRat eTotalCost** | **245** | **cForceDisplaySquadModes** |
| **46** | **cDoppled** | **96** | **cTracked** | **146** | **cPerimeterGenerator** | **196** | **cForceBatchTrain** | **246** | **cHideIfSocketedFoundationU ntouched** |
| **47** | **cDeleteable** | **97** | **cVisibleOwnerOnly** | **147** | **cAirfield** | **197** | **cUISkipActiveTechs** | **247** | **cDisplayMaxRangeOnSelectio n** |
| **48** | **cDestroyProjectile** | **98** | **cHideFromHelp** | **148** | **cBlocker** | **198** | **cApplyResourceRet urnIfDeleted** | **248** | **cDisplayRangeToEnemies** |
| **49** | **cOnlyInEditor** | **99** | **cHideResourceInven tory** | **149** | **cLockedSquad** | **199** | **cAlliesIgnoreInfluen ceRate** | **249** | **cChargeIdleAnim** |

# Placement Rules (data\placementrules\*.xml)

A placement rule file decides where a building may be dropped. A protoUnit points at one through its _PlacementFile_ attribute, resolved relative to `Data\placementrules`. A random map can repoint a protoUnit at a different rule file for that map only — see _Random Map Data Overrides_ below. The _PlacementRulesOverride_ tech effect swaps one protoUnit's rule set for another protoUnit's at runtime.

The root element is _PlacementRules_; anything else is rejected with `Expected tag 'PlacementRules' but found '%S' instead.` (exe 0x02409548). Every child element is one rule: the element name is the rule type, the element text is the target unitType, and the qualifiers are XML attributes. An unrecognised child name produces `'%S' is not a valid rule type.` (exe 0x024097e0). Matching is case-insensitive; every shipped file writes tags and attributes fully lowercase.

All rules in a file must pass for placement to be allowed. Rules with no target unitType (_DistanceAtLeastFromCliff_, _DistanceAtLeastFromTradeRoute_) are usually written as empty elements.

&lt;placementrules&gt;

&lt;obstructionatleastfromtype player="any" foundation="any" distance="8" errorstringid="34686"&gt;Mill&lt;/obstructionatleastfromtype&gt;

&lt;distanceatleastfromtype player="enemy" foundation="any" distance="65" errorstringid="25521"&gt;FirstTC&lt;/distanceatleastfromtype&gt;

&lt;distanceatleastfromcliff distance="6" errorstringid="25529" /&gt;

&lt;/placementrules&gt;

Only the Definitive Edition executable was available when this section was written, so **no Legacy / Definitive Edition split is claimed for this parser** — the entries below are what the DE parser accepts. Where a rule type or attribute is never used by shipped data it is marked as such, in the same spirit as the unused protoUnit flags documented above.

## Rule Types

The complete rule-type vocabulary is a contiguous block of wide strings at exe 0x02409580-0x024097da, corroborated by the RTTI class names `.?AVBPlacementRule*@@` at exe 0x02f20288-0x02f205d8. Usage counts below are element counts in the 30 vanilla files under `Data\placementrules` versus the 15 files in this mod.

- **DistanceAtLeastFromType:** Placement fails if any matching unit is closer than _distance_, measured centre to centre. The workhorse rule — vanilla 174, this mod 117. (exe 0x024095c0)
- **DistanceAtMostFromType:** Placement fails unless a matching unit is within _distance_. Used to force a building to stay near your own base — vanilla 22, this mod 13. (exe 0x02409590)
- **ObstructionAtLeastFromType:** As _DistanceAtLeastFromType_, but measured from the target's obstruction rather than its centre, so the target's footprint counts against the gap. Vanilla 188, this mod 80. (exe 0x024095f0)
- **DistanceAtLeastFromCliff:** Placement fails if a cliff is within _distance_. Takes no target unitType — only _distance_ and _errorStringID_. Vanilla 21, this mod 9. (exe 0x024097a8)
- **DistanceAtLeastFromTradeRoute:** Placement fails if the trade route is within _distance_. Takes no target unitType. Vanilla 6 (mills, fields, plantations, Community Plaza), this mod 2. (exe 0x024096b8)
- **DistanceAtMostFromSocket:** Placement fails unless a socket of the target unitType is within _distance_; on success the building is snapped onto that socket. This is the rule that makes Trading Posts buildable only on sockets. Carries the socket-specific attributes _linkUnit_, _successStringID_ and _occupiedStringID_. Vanilla 1 (`tradepost.xml`), this mod 2. (exe 0x02409640)
- **DistanceAtMostFromTradeRoute:** The inverse of _DistanceAtLeastFromTradeRoute_ — placement fails unless the trade route is within _distance_. Present in the parser and in RTTI (`BPlacementRuleDistanceAtMostFromTradeRoute`); **no vanilla or mod file uses it**. (exe 0x02409678)
- **DistanceAtMostFromWater:** Placement fails unless water is within _distance_. Parser and RTTI only; **no vanilla or mod file uses it** — docks instead rely on the engine's built-in shoreline check. (exe 0x024096f8)
- **DistanceAtMostFromMapEdge:** Placement fails unless the map edge is within _distance_. Parser and RTTI only; **no vanilla or mod file uses it**. (exe 0x02409748)
- **InsidePerimeterWall:** Placement is restricted to the interior of a perimeter wall. Parser and RTTI only; **no vanilla or mod file uses it**. Related to the _PerimeterGenerator_ protoUnit flag, itself unused. (exe 0x02409780)
- **InColony:** Placement is restricted to a colony as defined in `Data\placementrules\colonies.xml`. Parser and RTTI only; **no vanilla or mod file uses it**. Pairs with the equally unused _allowTeamColony_ attribute. (exe 0x02409628)
- **FortLinkType:** Fort-linking rule (`BPlacementRuleFortLink`), presumably the SPC fort-wall attach behaviour. Parser and RTTI only; **no vanilla or mod file uses it**. Purpose unverified. (exe 0x02409728)
- **MapType:** Restricts the rule set by random map type, validated against the same map-type name list the nugget parser uses — a bad value yields `'%S' is not a valid map type` (exe 0x02409508). The class `BPlacementRuleMapType` exists at exe 0x02f205a8, but the tag literal is not in the rule-type block; it is pooled with the nugget parser's `MapType` at exe 0x023ade30. **No vanilla or mod file uses it**, so the exact spelling accepted here is unverified.
- **And:** Composite rule — all child rules must pass. `BPlacementRuleAnd` at exe 0x02f202b0. **No vanilla or mod file uses it.** (exe 0x02409580)
- **Or:** Composite rule — any child rule may pass. `BPlacementRuleOr` at exe 0x02f202d8. **No vanilla or mod file uses it.** The literal is two characters long and sits immediately after _and_, which is why a three-character-minimum string scan misses it. (exe 0x02409588)

## Attributes

Attribute names are stored as ASCII in a contiguous block at exe 0x024093a8-0x02409548, interleaved with the parser's own error strings. Counts below are attribute occurrences across vanilla plus this mod.

- **player:** Which players' units the rule tests against. Required on the three unitType rules — 594 uses. See _player Values_ below.
- **foundation:** Which build state of the target counts. Required on the three unitType rules; every shipped file writes `any` (594 uses). The only other value literal in the parser's block is `fullybuilt` (exe 0x024094a8), which **no vanilla or mod file uses**. (exe 0x02409498)
- **distance:** The distance threshold, in world units. Required by every rule type; omitting it yields `No distance specified.` (exe 0x02409410). 635 uses. The attribute name itself is a pooled literal and does not sit in the placement block.
- **errorStringID:** String ID of the message shown when the rule blocks placement. Present on every rule in every shipped file — 635 uses. (exe 0x024093a8)
- **successStringID:** String ID shown when the rule is satisfied. Used only by _DistanceAtMostFromSocket_, to label a valid socket. 3 uses. (exe 0x024093b8)
- **occupiedStringID:** String ID shown when the target socket is already taken. Used only by _DistanceAtMostFromSocket_. 3 uses. (exe 0x024094f0)
- **linkUnit:** `true` on a _DistanceAtMostFromSocket_ rule links the new building to the socket it snapped to. All 3 socket rules in vanilla and this mod set it. (exe 0x024093e0)
- **noRushOnly:** `true` restricts the rule to the No-Rush period, after which it stops blocking. Used on the Trading Post's "must be near your first Town Centre" rule so the restriction lifts once No-Rush ends. 32 uses. (exe 0x02409440)
- **nugget:** `true` on a _DistanceAtLeastFromType_ rule whose target is _AbstractNugget_. Every one of the 15 uses in vanilla and this mod is exactly that pairing, so the attribute appears to scope the check to treasure instances; **exact behaviour unverified**. (exe 0x024093d8)
- **hideUnderFog:** `true` makes the rule not report against units the player cannot currently see, so a placement error cannot be used to probe fogged ground. Only 2 uses, both in vanilla `torp.xml` against _deTorp_ / _deTorpGeneric_. (exe 0x024093c8)
- **includeObstructionRadius:** Presumably makes a distance rule measure from the placed building's own obstruction as well. **No vanilla or mod file uses it**; purpose unverified. (exe 0x024094c0)
- **allowTeamColony:** Presumably widens an _InColony_ test to a team-mate's colony. **No vanilla or mod file uses it**, consistent with _InColony_ itself being unused; purpose unverified. (exe 0x024094e0)
- **linkTakenStringID:** A missing value for it yields `No link taken string id.` (exe 0x02409468). **No vanilla or mod file uses this spelling** — shipped socket rules write _occupiedStringID_ instead, so this is most likely the internal name of the same slot, or a superseded alias. Purpose unverified. (exe 0x02409450)

Two further parser errors exist for malformed input: `Invalid type.` when the element text is not a known unitType (exe 0x02409400), and `'%S' is not a valid map type` (exe 0x02409508).

## player Values

Six literals make up the ownership enum. `any`, `team` and `ally` sit inside the placement-rule block; `self`, `enemy` and `gaia` are a pooled triple shared with the protoAction parser's block. Only three are ever written in shipped data.

- **any:** Every player, gaia included. 520 uses. Vanilla rules written with `player="any"` target gaia-owned objects such as _AbstractNugget_, _AbstractMine_, _Herdable_, _Huntable_ and _ypKingsHill_, which is what establishes that `any` covers gaia. (exe 0x02409428)
- **enemy:** Players you are at war with. 41 uses — the classic "no building within 65 of an enemy Town Centre" rule. (exe 0x02408e80)
- **team:** You and your allies. 33 uses. (exe 0x02409430)
- **gaia:** Gaia-owned units. **No vanilla or mod file uses it**, so its behaviour is inferred, not observed. It is a separate literal from `enemy`, but do not read that as `enemy` excluding gaia — the engine's player-relation enum, exported to XS at exe 0x0241b718-0x0241b7e8 as `cPlayerRelationAny`, `cPlayerRelationSelf`, `cPlayerRelationEnemy`, `cPlayerRelationAlly`, `cPlayerRelationEnemyNotGaia` and `cPlayerRelationAllyExcludingSelf`, carries a distinct _EnemyNotGaia_ value, which implies plain _Enemy_ **includes** gaia-owned units. Treat `player="enemy"` as covering capturable, socketed and map-placed objects until tested otherwise. (exe 0x02408e90)
- **self:** The placing player only. **No vanilla or mod file uses it.** (exe 0x02408e70)
- **ally:** Allies only, presumably excluding yourself, as distinct from `team`. **No vanilla or mod file uses it.** (exe 0x02409488)

## Colonies (data\placementrules\colonies.xml)

`colonies.xml` shares the `placementrules` folder but is a separate parser with root _Colonies_, rejecting anything else with `Expected tag 'Colonies' but found '%S' instead.` (exe 0x02409878); its per-entry parser reports `Expected tag 'Colony' but found '%S' instead.` (exe 0x0242b1d8). It is what the unused _InColony_ rule and _allowTeamColony_ attribute refer to. Vanilla ships two colonies, `Standard` and `SPCMilitaryColony`, both used by the campaign colony system.

- **Colony:** One colony definition. Attribute **name** is its identifier.
- **StartTypes:** Container of _Type_ elements naming the protoUnits that seed a colony. Attribute **maxCount** on each _Type_ caps how many seed it.
- **AddTypes:** Container of _Type_ elements naming the unitTypes that count as belonging to a colony once built.
- **WallCost / WallRepairCost:** Containers of resource elements (_Food_, _Wood_) for raising and repairing the colony wall.
- **WallRadius / WallMaxRadius / WallRadiusIncrease / WallRadiusIncreaseInterval:** Colony wall geometry and its growth over time, in world units and seconds.
- **WallBuildRate / WallDownTime / WallDamageRadius / WallSegments:** Colony wall build speed, downtime after being breached, damage radius and segment count.
- **StartingUnits:** Container of _StartingUnitInfo_ blocks, each holding _UnitType_ elements with a **count** attribute plus _ApplyStringID_, _ApplyStringIDAsian_ and _ApplyStringIDNative_ for the message shown to European, Asian and Native civs respectively.

# Nuggets (nuggets.xml, nuggetmods.xml)

A nugget is a treasure: a gaia-owned prop guarded by hostile units, which grants a reward when the guardians are cleared and the treasure is walked into. `Data\nuggets.xml` is the vanilla list; a mod adds its own in `Data\nuggetmods.xml`, whose root element is _NuggetMods_ rather than _NuggetManager_ — this mod ships 234 nuggets that way. Both files then use the same _Nuggets_ / _Nugget_ body.

The parser is `BNuggetManager` (`e:\_work\p4\gass_dev\source\age3\nuggetmanager.cpp`, exe 0x02416fb0). Its tag vocabulary is a contiguous block of wide strings at exe 0x024171f0-0x02417450, with _Nugget_, _Guardian_, _GuardianUnit_ and _MapType_ pooled into a neighbouring block at exe 0x023ade00-0x023ade40. Which nuggets a map receives is filtered by _MapType_ and by the difficulty window set with the `rmSetNuggetDifficulty` random-map syscall (exe 0x024afe40).

As with placement rules, only the Definitive Edition executable was available, so **no Legacy / Definitive Edition split is claimed for this parser**.

&lt;nugget&gt;

&lt;name&gt;Blueberries&lt;/name&gt;

&lt;type&gt;AdjustResource&lt;/type&gt;

&lt;nuggetunit&gt;NuggetBearCampsite&lt;/nuggetunit&gt;

&lt;rolloverstringid&gt;25460&lt;/rolloverstringid&gt;

&lt;applystringid&gt;25461&lt;/applystringid&gt;

&lt;resource&gt;Food&lt;/resource&gt;

&lt;amount&gt;140&lt;/amount&gt;

&lt;maptype&gt;greatLakes&lt;/maptype&gt;

&lt;guardianunit&gt;

&lt;unit&gt;BlackBear&lt;/unit&gt;

&lt;idleanim&gt;Bear_Campsite_Idle&lt;/idleanim&gt;

&lt;attachdummy&gt;bone_nuggetA&lt;/attachdummy&gt;

&lt;/guardianunit&gt;

&lt;difficulty&gt;3&lt;/difficulty&gt;

&lt;/nugget&gt;

## Attributes

Counts below are element counts in vanilla `nuggets.xml` (961 nuggets) versus this mod's `nuggetmods.xml` (234 nuggets).

- **Name:** Internal nugget name, and the handle used by random-map and trigger code. Required — one per nugget. Pooled literal, no unique offset.
- **Type:** Nugget effect type. Optional — 953 of 961 vanilla nuggets set it, and a nugget without one still loads. See _Nugget Types_ below. Pooled literal.
- **NuggetUnit:** The protoUnit used as the visible treasure prop. Required in practice — vanilla 961, this mod 212. (exe 0x024172a8)
- **RolloverStringID:** String ID for the rollover shown before the treasure is claimed. Vanilla 959, this mod 212. (exe 0x023a25f0)
- **ApplyStringID:** String ID for the message shown when the reward is granted. Vanilla 959, this mod 212. (exe 0x024172c0)
- **Resource:** Resource granted by an _AdjustResource_ nugget — `Food`, `Wood`, `Gold`, `XP`. Vanilla 705, this mod 113. Pooled literal.
- **Amount:** Amount granted. For _AdjustResource_ the resource quantity, for _SpawnUnit_ the unit count, for _AdjustHP_ a multiplier. Vanilla 813, this mod 149.
- **Resource2 / Amount2:** A second resource and quantity, letting one treasure pay out twice. Vanilla 94 each, this mod 12 each. (exe 0x02417370, 0x02417388)
- **UnitType:** For a _SpawnUnit_ nugget, the protoUnit to spawn; _Amount_ gives the count. Also used inside _ResourceModEntry_. Vanilla 100, this mod 26.
- **Tech:** For a _GiveTech_ nugget, the technology to activate. Vanilla 78, this mod 9. Pooled literal.
- **TargetType:** Restricts an _AdjustHP_ or _AdjustSpeed_ nugget to a unitType — vanilla uses `Hero` so a treasure buffs the Explorer only. Vanilla 19, this mod 2. Pooled literal.
- **MapType:** Random map type this nugget may appear on. Repeated once per map — the single most common element in the file. Vanilla 5055, this mod 643. (exe 0x023ade30)
- **Difficulty:** Difficulty weight used to filter nuggets against the window set by `rmSetNuggetDifficulty`. Vanilla 934, this mod 211. (exe 0x024173f0)
- **Guardian:** Shorthand guardian entry — a protoUnit name, repeated once per guardian, with no animation data. Vanilla 1900, this mod 460. (exe 0x023ade40)
- **GuardianUnit:** Long-form guardian entry, a container element — see _Guardian and Convert Sub-Elements_ below. Vanilla 683, this mod 357. (exe 0x023ade10)
- **ConvertUnit:** Container element describing a unit handed to the player by a _ConvertUnit_ nugget, using the same sub-elements as _GuardianUnit_. Vanilla 81, this mod 34. (exe 0x024172e0)
- **ConvertSettler:** `true` marks a _ConvertUnit_ nugget whose reward is a settler — the vanilla kidnap treasures. Vanilla 16, this mod 16. (exe 0x02417440)
- **KillUnitOnApply:** `0` keeps the guarded unit alive when the treasure is claimed instead of removing it. Vanilla 63, this mod 18. (exe 0x02417408)
- **TeamNugget:** `1` makes the reward apply to the whole team rather than the collecting player. Vanilla 87, this mod 12. (exe 0x02417428)
- **WaterNugget:** `true` marks a treasure placed on water and collectable by ships. Vanilla 63, this mod 28. (exe 0x02417290)
- **Icon:** Overrides the icon used for the treasure notification. Vanilla 7, this mod 5.
- **Idle2Anim:** Present in the parser's tag block between _SpawnUnit_ and _ExitAnim_, so presumably a second idle animation for a guardian or converted unit. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02417310)
- **EnterAnim:** Counterpart to _ExitAnim_. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02417340)
- **Pattern:** **No vanilla or mod file uses it**; purpose unknown. (exe 0x02417398)
- **ExploreDistance:** **No vanilla or mod file uses it**; purpose unknown, the name suggests a reveal or discovery radius. (exe 0x024173a8)
- **GuardianDistance:** **No vanilla or mod file uses it**; purpose unknown, the name suggests how far guardians are scattered around the prop. (exe 0x024173c8)
- **SpawnUnit:** A wide literal sitting inside the tag block, adjacent to _ConvertUnit_ which is a real container tag. **No vanilla or mod file uses `<spawnunit>` as an element** — _SpawnUnit_ nuggets name their unit with _UnitType_ and _Amount_ instead — so this may be a container tag that was never used, or the enum comparison for the nugget type. Purpose unverified. (exe 0x024172f8)

## Nugget Types

Seven values, stored as ASCII in a contiguous block at exe 0x02ec2110-0x02ec2170. The engine also exports them to XS as `cNuggetType*` constants (exe 0x0241bbc8-0x0241bcb8), which is what fixes the set exactly.

- **AdjustResource:** Grants _Resource_ / _Amount_, optionally a second payout through _Resource2_ / _Amount2_. By far the most common — vanilla 705, this mod 113. Vanilla also writes the lowercase-initial spelling `adjustResource` 83 times, so the comparison is case-insensitive. (exe 0x02ec2110)
- **SpawnUnit:** Spawns _Amount_ units of _UnitType_ for the collector. Vanilla 82, this mod 26. (exe 0x02ec2120)
- **ConvertUnit:** Hands over the units listed in the _ConvertUnit_ containers. Vanilla 67, this mod 26. (exe 0x02ec2130)
- **GiveTech:** Activates the technology named in _Tech_. Vanilla 78, this mod 9. (exe 0x02ec2168)
- **AdjustHP:** Multiplies hitpoints of _TargetType_ by _Amount_. Vanilla 19, this mod 2. (exe 0x02ec2158)
- **AdjustSpeed:** Multiplies movement speed of _TargetType_ by _Amount_. Vanilla 2, this mod 0. (exe 0x02ec2148)
- **GiveLOS:** Grants line of sight. Exported to XS as `cNuggetTypeGiveLOS` and present in the enum block, but **no vanilla or mod nugget uses it**. (exe 0x02ec2140)

## Guardian and Convert Sub-Elements

_GuardianUnit_ and _ConvertUnit_ are containers; each instance describes one unit and how it is posed on the treasure prop. Both accept the same children. `Did not find dummy location, creating from source.` and `Could not place where we wanted it, destroying.` (exe 0x02417180, 0x024171b8) are the placement diagnostics for this step.

- **Unit:** ProtoUnit to place. Vanilla 764, this mod 391.
- **IdleAnim:** Animation the unit loops while the treasure is unclaimed. Vanilla 550, this mod 119. (exe 0x0240ca40)
- **ExitAnim:** Animation played when the treasure is claimed and the unit breaks from its pose. Vanilla 392, this mod 115. (exe 0x02417328)
- **AttachDummy:** Name of the bone/dummy on the treasure prop that the unit is attached to, for example `bone_nuggetA`. Vanilla 698, this mod 154. (exe 0x02417358)

## ResourceModTech Entries

Optional block at the head of the file, wrapping the treasure-multiplier technologies. Vanilla defines six; this mod defines none.

- **ResourceModTechEntries:** Container of _ResourceModTechEntry_ blocks. (exe 0x02417210)
- **ResourceModTechEntry:** One technology and the units it affects. (exe 0x023adda8)
- **ResourceModTech:** The technology name, for example `DEHCREVLetterOfMarque`. (exe 0x023add88)
- **ResourceModEntries:** Container of _ResourceModEntry_ blocks. (exe 0x02417240)
- **ResourceModEntry:** One unitType and its multiplier. (exe 0x023addd8)
- **UnitType:** The unitType whose treasure collection is modified — `Unit` for all units.
- **ModValue:** The multiplier applied, for example `2.0`. (exe 0x02417278)

# Random Map Data Overrides (randmaps\&lt;map&gt;.mods.xml)

A random map can rewrite protoUnit data for the duration of that map alone. The engine looks for a file named after the map script with the suffix `.mods.xml` alongside it in `randmaps\` — the suffix literal is at exe 0x0235b2d8. This is how a map rebinds a building's placement rules: `randmaps\zpistanbulb.mods.xml` repoints _Dock_, _YPDockAsian_ and _dePort_ at `dock_city.xml`, so the city map's tighter dock spacing applies without touching the global `protomods.xml`.

**No vanilla map ships a `.mods.xml`** — the feature exists in the engine but the shipped random maps do not use it. This mod ships 17 of them.

A sibling suffix `.mods.tactics` exists at exe 0x023adbd0, next to the `.tactics` and `Tactics` literals, implying a matching per-map tactics override. **This mod does not use it and no vanilla map does**; purpose unverified.

Note that neither the literal `protomods` nor the literal `mods` for these element names appears in the executable's string tables, in ASCII or in UTF-16 — the parser evidently resolves them without a stored literal, exactly as the `*mods.xml` data-file names themselves are composed at runtime. Their existence is established from working data files, not from the binary. A failed string scan is not evidence that a name is unsupported.

## Structure

&lt;?xml version="1.0"?&gt;

&lt;mods&gt;

&lt;protomods&gt;

&lt;unit name="Dock"&gt;

&lt;placementfile&gt;dock_city.xml&lt;/placementfile&gt;

&lt;/unit&gt;

&lt;unit id="20330" name="zpAmericanEmbassy"&gt;

&lt;flag&gt;NoIdleActions&lt;/flag&gt;

&lt;flag mergemode="remove"&gt;NotSelectable&lt;/flag&gt;

&lt;/unit&gt;

&lt;/protomods&gt;

&lt;/mods&gt;

- **Mods:** Root element. _ProtoMods_ is the only child witnessed in working files.
- **ProtoMods:** Container of _Unit_ overrides. Takes an optional **version** attribute, written `version='1'` in two of this mod's 17 files (`zpgrinch.mods.xml`, `zpwinterwonderlandii.mods.xml`); its effect is unverified, and the other 15 files omit it with no observable difference.
- **Unit:** One protoUnit to override. Attribute **name** is the protoUnit's internal name and is always present — 845 uses across this mod's 17 files. Attribute **id** is the numeric protoUnit id, written alongside _name_ in 9 cases; it is redundant where _name_ resolves.

Inside _Unit_, any protoUnit element from `protoy.xml` / `protomods.xml` is accepted and replaces the value for that map. Elements this mod actually overrides per map, with occurrence counts across its 17 files: _PlacementFile_ 462, _Flag_ 487, _AnimFile_ 94, _Icon_ 76, _PortraitIcon_ 76, _ObstructionRadiusX_ 67, _ObstructionRadiusZ_ 67, _DisplayNameID_ 37, _Cost_ 25, _MinimapIcon_ 24, _UnitType_ 22, _UnitRegen_ 19, _BuildPoints_ 16, _InitialHitpoints_ 15, _MaxHitpoints_ 15, _Tactics_ 13, _DamageBonus_ 7, _TrainPoints_ 7, _RolloverTextID_ 6, _ShortRolloverTextID_ 6, _CivFlagOverride_ 6, _Command_ 6, _ProtoAction_ 4, _LOS_ 3, _Damage_ 3, _DamageType_ 3, _MaxRange_ 3, _ROF_ 3, _MovementType_ 2, _InitialResource_ 1, _Train_ 1. Attributes carried on those elements behave exactly as in `protomods.xml` — _resourcetype_ on _Cost_ and _InitialResource_, _damagetimeout_ on _UnitRegen_, _type_ on _DamageBonus_ and _Rate_, _page_ / _column_ / _row_ on _Command_ and _Train_.

## Merge Modes

Every element inside _Unit_ accepts a **mergeMode** attribute controlling how the override combines with the base data. The attribute name is at exe 0x02652250. This is the same mechanism used by the global `data\*mods.xml` family (`protomods.xml`, `civmods.xml`, `techtreemods.xml`, `protounitcommandmods.xml`, `politicianmods.xml`, `maptypemods.xml`, `mapspecifictechmods.xml`, `nuggetmods.xml`, `randomnamemods.xml`).

- **add:** Adds the entry to the existing list rather than replacing it. 1968 uses across this mod's data. Writing it is usually unnecessary: an element given without _mergeMode_ already appends when the target is a list (_Flag_, _UnitType_) and overwrites when the target is a scalar (_PlacementFile_, _MaxHitpoints_). The literal is pooled with an unrelated `add` elsewhere in the binary rather than stored next to _mergeMode_.
- **remove:** Deletes the named entry from the existing list. This is how a map strips a flag it does not want — `&lt;flag mergemode="remove"&gt;NotSelectable&lt;/flag&gt;` and `&lt;flag mergemode="remove"&gt;TieToWaterSurface&lt;/flag&gt;` in `zpistanbulb.mods.xml`. 64 uses. (exe 0x02652240)
- **replace:** Replaces the existing list wholesale. 3 uses in this mod. Pooled literal, like _add_.
- **modify:** Sits directly beside _remove_ and _mergeMode_ in the binary, so it is almost certainly a fourth value of this enum. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02652230)