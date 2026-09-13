// 000_hkt_test - destruction-physics test bench (not a playable map).
// Player 1 starts at the map centre with three buildings 12 m away:
//   House (vanilla)  Saloon (vanilla)  zpSheriffOffice (mod copy of the Saloon art)
// t = 25 s : each of the three takes 700 damage  -> damage-stage debris should fall
// t = 45 s : each takes 9999 damage               -> death collapse
// Nothing else happens; watch the three buildings from the start camera.
// Spine (rmSetMapSize / rmTerrainInitialize / rmPlacePlayersCircular) is mandatory - see memory
// "RM script spine must survive any cut". The includes + chooseMercs() + rmSetMapType are what
// every working map does before placing anything: a Saloon's train list is built from the
// mercenary set at world creation, and without chooseMercs() generation aborted (crash +0xA7508D).

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   rmSetStatusText("", 0.01);
   rmSetMapSize(200, 200);
   rmSetMapElevationHeightBlend(1);
   rmSetSeaLevel(0.0);
   rmSetLightingSet("sonora_skirmish");
   rmSetMapElevationParameters(cElevTurbulence, 0.02, 2, 0.5, 1.0);
   rmSetBaseTerrainMix("africa desert rock");
   rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
   rmSetMapType("arabia");
   rmSetMapType("desert");
   chooseMercs();
   rmSetWorldCircleConstraint(true);
   rmDefineClass("player");
   rmSetStatusText("", 0.30);

   // players: a small ring so player 1 (the human) is near the centre and the camera opens on it
   rmSetPlacementSection(0.0, 1.0);
   rmPlacePlayersCircular(0.12, 0.12, 0.0);
   rmSetStatusText("", 0.50);

   int tcID = rmCreateObjectDef("player TC");
   rmAddObjectDefItem(tcID, "TownCenter", 1, 0.0);
   rmSetObjectDefMinDistance(tcID, 0.0);
   rmSetObjectDefMaxDistance(tcID, 0.0);
   for(i=1; <= cNumberNonGaiaPlayers)
   {
      rmPlaceObjectDefAtLoc(tcID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }
   int tc1 = rmGetUnitPlacedOfPlayer(tcID, 1);   // engine unit id of player 1's TC: SrcObject wants a unit id, not a def id

   // the three test subjects, player 1 only
   int houseID = rmCreateObjectDef("hkt house");
   rmAddObjectDefItem(houseID, "House", 1, 0.0);
   rmSetObjectDefMinDistance(houseID, 0.0);
   rmSetObjectDefMaxDistance(houseID, 0.0);

   int saloonID = rmCreateObjectDef("hkt saloon");
   rmAddObjectDefItem(saloonID, "Saloon", 1, 0.0);
   rmSetObjectDefMinDistance(saloonID, 0.0);
   rmSetObjectDefMaxDistance(saloonID, 0.0);

   int sheriffID = rmCreateObjectDef("hkt sheriff");
   rmAddObjectDefItem(sheriffID, "zpSheriffOffice", 1, 0.0);
   rmSetObjectDefMinDistance(sheriffID, 0.0);
   rmSetObjectDefMaxDistance(sheriffID, 0.0);

   float px = rmPlayerLocXFraction(1);
   float pz = rmPlayerLocZFraction(1);
   float dx = rmXMetersToFraction(14.0);
   float dz = rmZMetersToFraction(14.0);
   rmPlaceObjectDefAtLoc(houseID, 1, px + dx, pz);
   rmPlaceObjectDefAtLoc(saloonID, 1, px - dx, pz);
   rmPlaceObjectDefAtLoc(sheriffID, 1, px, pz + dz);
   rmSetStatusText("", 0.80);

   // t = 25 s: damage stage
   rmCreateTrigger("hkt_stage");
   rmSwitchToTrigger(rmTriggerID("hkt_stage"));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(false);
   rmSetTriggerLoop(false);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 25);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "House");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 700.0);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "Saloon");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 700.0);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "zpSheriffOffice");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 700.0);

   // t = 45 s: death
   rmCreateTrigger("hkt_kill");
   rmSwitchToTrigger(rmTriggerID("hkt_kill"));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(false);
   rmSetTriggerLoop(false);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 45);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "House");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 9999.0);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "Saloon");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 9999.0);
   rmAddTriggerEffect("Damage Units in Area");
   rmSetTriggerEffectParam("SrcObject", tc1);
   rmSetTriggerEffectParamInt("Player", 1);
   rmSetTriggerEffectParam("UnitType", "zpSheriffOffice");
   rmSetTriggerEffectParamFloat("Dist", 40.0);
   rmSetTriggerEffectParamFloat("Damage", 9999.0);

   rmSetStatusText("", 1.0);
}
