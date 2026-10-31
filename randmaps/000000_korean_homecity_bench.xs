// 000000_korean_homecity_bench.xs - Lighting test bench for Korean Home City & Backdrop
// 600x600 map so the 354m x 286m Home City & Backdrop fit with generous margin.
// Unit pivot placed at (410m, 205m) so the geometric center of the Home City & Backdrop sits at map center (300m, 300m).

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   rmSetStatusText("", 0.01);
   rmSetMapSize(600, 600);
   rmSetMapElevationHeightBlend(1);
   rmSetSeaLevel(0.0);
   rmSetLightingSet("Herald_Island_Skirmish");
   rmSetMapElevationParameters(cElevTurbulence, 0.0, 1, 0.0, 0.0);
   rmSetBaseTerrainMix("africa desert rock");
   rmTerrainInitialize("deccan\\ground_grass3_deccan", 0.0);
   rmSetMapType("grass");
   chooseMercs();
   rmSetWorldCircleConstraint(false);
   rmDefineClass("player");
   rmSetStatusText("", 0.30);

   rmSetPlacementSection(0.0, 1.0);
   rmPlacePlayersCircular(0.40, 0.40, 0.0);
   rmPlacePlayer(1, 0.50, 0.50);
   rmSetStatusText("", 0.50);

   // Pivot offset (410m, 205m) = fraction (0.683333, 0.341667) centers the 354m x 286m Home City at map center (300m, 300m)
   float hcX = rmXMetersToFraction(410.0);
   float hcZ = rmZMetersToFraction(205.0);

   // 1. Place Home City Buildings & Ground (includes all 5 main HC buildings + filler blocks + bridges + docks + boats)
   int hcModelDef = rmCreateObjectDef("Korean Homecity Model");
   rmAddObjectDefItem(hcModelDef, "zzTESTKoreanHomecityModel", 1, 0.0);
   rmSetObjectDefMinDistance(hcModelDef, 0.0);
   rmSetObjectDefMaxDistance(hcModelDef, 0.0);
   rmSetObjectDefAllowOverlap(hcModelDef, true);
   rmPlaceObjectDefAtLoc(hcModelDef, 1, hcX, hcZ);

   // 2. Place Backdrop Cylinder at exact same pivot
   int bgDef = rmCreateObjectDef("Korean Homecity Backdrop");
   rmAddObjectDefItem(bgDef, "zzTESTKoreanHomecityBackdrop", 1, 0.0);
   rmSetObjectDefMinDistance(bgDef, 0.0);
   rmSetObjectDefMaxDistance(bgDef, 0.0);
   rmSetObjectDefAllowOverlap(bgDef, true);
   rmPlaceObjectDefAtLoc(bgDef, 1, hcX, hcZ);

   // 3. Place Water Plate at exact same pivot
   int waterDef = rmCreateObjectDef("Korean Homecity Water");
   rmAddObjectDefItem(waterDef, "zzTESTKoreanHomecityWater", 1, 0.0);
   rmSetObjectDefMinDistance(waterDef, 0.0);
   rmSetObjectDefMaxDistance(waterDef, 0.0);
   rmSetObjectDefAllowOverlap(waterDef, true);
   rmPlaceObjectDefAtLoc(waterDef, 1, hcX, hcZ);

   // Keep Player 1 alive in Playtest
   int keepAliveDef = rmCreateObjectDef("keep alive settler");
   rmAddObjectDefItem(keepAliveDef, "Settler", 1, 0.0);
   rmSetObjectDefMinDistance(keepAliveDef, 0.0);
   rmSetObjectDefMaxDistance(keepAliveDef, 0.0);
   rmPlaceObjectDefAtLoc(keepAliveDef, 1, 0.05, 0.05);

   rmSetStatusText("", 0.80);

   // ---- Triggers: Sequential Testbed Lighting Demonstration
   rmCreateTrigger("InitCamera");
   rmCreateTrigger("Light_BlueMountains");
   rmCreateTrigger("Light_MistyMorning");
   rmCreateTrigger("Light_KoreaSkirmish");
   rmCreateTrigger("Light_YellowRiver");
   rmCreateTrigger("Light_Himalayas");
   rmCreateTrigger("Light_Andes");
   rmCreateTrigger("Light_ChinaMorning");
   rmCreateTrigger("Light_ResetJapan");

   // Trigger: InitCamera (0s) - Herald Island
   rmSwitchToTrigger(rmTriggerID("InitCamera"));
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerPriority(4);
   rmAddTriggerEffect("Render Fog/Black Map");
   rmSetTriggerEffectParam("Black", "false");
   rmSetTriggerEffectParam("Fog", "false");
   rmAddTriggerEffect("Cinematic Mode");
   rmSetTriggerEffectParam("Enter", "true");
   rmSetTriggerEffectParam("Letterbox", "false");
   rmAddTriggerEffect("Camera Cut");
   rmSetTriggerEffectParam("CameraInfo", "vector(413.676530,30.544399,150.796352), vector(-0.527055,-0.109373,0.842764), vector(-0.057993,0.994001,0.092732), vector(0.847850,0.000000,0.530236)");
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "Herald_Island_Skirmish");
   rmSetTriggerEffectParam("FadeTime", "1.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [1/8]: Herald Island (herald_island_skirmish)");

   // Trigger: Light_BlueMountains (at 12s) - AoP Blue Mountains
   rmSwitchToTrigger(rmTriggerID("Light_BlueMountains"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 12);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "India_yic1a1");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [2/8]: Blue Mountains AoP (India_yic1a1)");

   // Trigger: Light_MistyMorning (at 24s)
   rmSwitchToTrigger(rmTriggerID("Light_MistyMorning"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 24);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "japan_misty_morning");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [3/8]: Misty Morning (japan_misty_morning)");

   // Trigger: Light_KoreaSkirmish (at 36s)
   rmSwitchToTrigger(rmTriggerID("Light_KoreaSkirmish"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 36);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "Korea_Skirmish");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [4/8]: Korea Skirmish (Korea_Skirmish)");

   // Trigger: Light_YellowRiver (at 48s)
   rmSwitchToTrigger(rmTriggerID("Light_YellowRiver"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 48);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "yellow_river_wet_skirmish");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [5/8]: Yellow River Wet Mist (yellow_river_wet_skirmish)");

   // Trigger: Light_Himalayas (at 60s)
   rmSwitchToTrigger(rmTriggerID("Light_Himalayas"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 60);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "HimalayasUpper_skirmish");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [6/8]: Himalayas Upper Mist (HimalayasUpper_skirmish)");

   // Trigger: Light_Andes (at 72s)
   rmSwitchToTrigger(rmTriggerID("Light_Andes"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 72);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "Andes_Skirmish");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [7/8]: Andes / London Fog (Andes_Skirmish)");

   // Trigger: Light_ChinaMorning (at 84s)
   rmSwitchToTrigger(rmTriggerID("Light_ChinaMorning"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 84);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "china");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING [8/8]: Chinese Morning (china)");

   // Trigger: Light_ResetJapan (at 96s)
   rmSwitchToTrigger(rmTriggerID("Light_ResetJapan"));
   rmSetTriggerActive(true);
   rmAddTriggerCondition("Timer");
   rmSetTriggerConditionParamInt("Param1", 96);
   rmAddTriggerEffect("Set Lighting");
   rmSetTriggerEffectParam("SetName", "Japan");
   rmSetTriggerEffectParam("FadeTime", "3.0");
   rmAddTriggerEffect("Send Chat");
   rmSetTriggerEffectParamInt("PlayerID", 1);
   rmSetTriggerEffectParam("Message", "LIGHTING: Reset to Default Japan Sunset");

   rmSetStatusText("", 1.0);
}
