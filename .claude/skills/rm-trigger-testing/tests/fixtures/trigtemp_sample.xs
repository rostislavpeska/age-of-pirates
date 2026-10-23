//==============================================================================
// TEST TRIGGER SCRIPT
//==============================================================================
// rm-trigger-testing fixture: a trimmed copy of <profile>\Trigger\trigtemp.xs written by the
// London generation of 2026-09-22 20:54. Kept: the nine London rules below, verbatim, except
// that trEventFire / trDisableTrigger lines whose target rule is not in this file were removed.
// Appended: a SYNTHETIC ping-pong pair (_Towers_ON1 <-> _Towers_ON2, the shape of the persistent
// minimap flare removed in 8ac63e04) and a SYNTHETIC dead select (_DeadSelect).


void main(void)
{
   trEventSetHandler(2371,  "eventHandler");
   trEventSetHandler(2377,  "eventHandler");
   trEventSetHandler(2406,  "eventHandler");
   trEventSetHandler(2410,  "eventHandler");
   trEventSetHandler(2426,  "eventHandler");
   trEventSetHandler(2472,  "eventHandler");
   trEventSetHandler(2484,  "eventHandler");
   trEventSetHandler(9001,  "eventHandler");
   trEventSetHandler(9002,  "eventHandler");
}

void eventHandler(int eventID=-1)
{
   switch(eventID)
   {
   case 2371:
   {
      xsEnableRule("_TowerConvS_Plr2");
      trEcho("Trigger enabling rule TowerConvS_Plr2");
      break;
   }
   case 2377:
   {
      xsEnableRule("_TowerConvS_Plr1");
      trEcho("Trigger enabling rule TowerConvS_Plr1");
      break;
   }
   case 2406:
   {
      xsEnableRule("_Bridge_OFF_Plr1");
      trEcho("Trigger enabling rule Bridge_OFF_Plr1");
      break;
   }
   case 2410:
   {
      xsEnableRule("_Bridge_ON_Plr1");
      trEcho("Trigger enabling rule Bridge_ON_Plr1");
      break;
   }
   case 2426:
   {
      xsEnableRule("_BridgeTowers_Setup1");
      trEcho("Trigger enabling rule BridgeTowers_Setup1");
      break;
   }
   case 2472:
   {
      xsEnableRule("_BuildTowerS1_ON_Plr1");
      trEcho("Trigger enabling rule BuildTowerS1_ON_Plr1");
      break;
   }
   case 2484:
   {
      xsEnableRule("_BuildTowerS1_OFF_Plr1");
      trEcho("Trigger enabling rule BuildTowerS1_OFF_Plr1");
      break;
   }
   case 9001:
   {
      xsEnableRule("_Towers_ON2");
      trEcho("Trigger enabling rule Towers_ON2");
      break;
   }
   case 9002:
   {
      xsEnableRule("_Towers_ON1");
      trEcho("Trigger enabling rule Towers_ON1");
      break;
   }
   }
}

rule _TowerSUnlock
highFrequency
active
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trNuggetCollectable("1024"));


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(1012);
      trUnitSuspendAction("AutoConvert",False);
      trEventFire(2377);
      trEventFire(2371);
      xsDisableRule("_TowerSUnlock");
      trEcho("Trigger disabling rule TowerSUnlock");
   }
}

rule _TowerConvS_Plr1
highFrequency
inactive
{
   bool bVar0 = (true);

   trUnitSelectClear();
   trUnitSelectByID(1012);
   bool bVar1 = (trUnitIsOwnedBy(1));


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trUnitConvert(1);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,1,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,1,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,1,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,1,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,1,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(985);
      trUnitConvert(1);
      trUnitSelectClear();
      trUnitSelectByID(1079);
      trUnitConvert(1);
      trMinimapFlare(1, 10, vector(67.494499,1.000000,255.850296), True);
      trMinimapFlare(2, 10, vector(67.494499,1.000000,255.850296), True);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trUnitHighlight(2.5, true);
      trEventFire(2371);
      trSoundsetPlay("SheepFound");
      xsDisableRule("_TowerConvS_Plr1");
      trEcho("Trigger disabling rule TowerConvS_Plr1");
   }
}

rule _TowerConvS_Plr2
highFrequency
inactive
{
   bool bVar0 = (true);

   trUnitSelectClear();
   trUnitSelectByID(1012);
   bool bVar1 = (trUnitIsOwnedBy(2));


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trUnitConvert(2);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(0,2,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(1,2,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(2,2,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(3,2,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"SPCFortGate",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"zpSPCSocketCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"zpSPCCityTowerWooden",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"deSPCFortWallMediumProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"deSPCFortCornerProp",40);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trConvertUnitsInArea(4,2,"deSPCFortWallLargeProp",40);
      trUnitSelectClear();
      trUnitSelectByID(985);
      trUnitConvert(2);
      trUnitSelectClear();
      trUnitSelectByID(1079);
      trUnitConvert(2);
      trMinimapFlare(1, 10, vector(67.494499,1.000000,255.850296), True);
      trMinimapFlare(2, 10, vector(67.494499,1.000000,255.850296), True);
      trUnitSelectClear();
      trUnitSelectByID(1023);
      trUnitHighlight(2.5, true);
      trEventFire(2377);
      trSoundsetPlay("SheepFound");
      xsDisableRule("_TowerConvS_Plr2");
      trEcho("Trigger disabling rule TowerConvS_Plr2");
   }
}

rule _Bridge_ON_Plr1
highFrequency
active
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trCountUnitsInArea("226",1,"TradingPost",8) >= 1);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"SPCFortGate",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"deSPCFortWallLargeProp",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"zpSPCFortCornerPropFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"zpSPCSocketCityTowerFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"zpSPCCityTowerFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(208);
      trUnitConvert(1);
      trUnitSelectClear();
      trUnitSelectByID(233);
      trUnitConvert(1);
      trEventFire(2406);
      xsDisableRule("_Bridge_ON_Plr1");
      trEcho("Trigger disabling rule Bridge_ON_Plr1");
   }
}

rule _Bridge_OFF_Plr1
highFrequency
inactive
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trCountUnitsInArea("226",1,"TradingPost",8) == 0);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"SPCFortGate",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"deSPCFortWallLargeProp",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"zpSPCFortCornerPropFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"zpSPCSocketCityTowerFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"zpSPCCityTowerFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(208);
      trUnitConvert(0);
      trUnitSelectClear();
      trUnitSelectByID(233);
      trUnitConvert(0);
      trEventFire(2410);
      xsDisableRule("_Bridge_OFF_Plr1");
      trEcho("Trigger disabling rule Bridge_OFF_Plr1");
   }
}

rule _BuildTowerS1_ON_Plr1
highFrequency
inactive
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trCountUnitsInArea("1173",1,"zpSPCWoodenTowerAIProxy",10) >= 1);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trSocketBuild(1, "1173", "zpSPCCityTowerWooden");
      trEventFire(2484);
      xsDisableRule("_BuildTowerS1_ON_Plr1");
      trEcho("Trigger disabling rule BuildTowerS1_ON_Plr1");
   }
}

rule _BuildTowerS1_OFF_Plr1
highFrequency
inactive
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = ((trTimeMS()-(cActivationTime*1000)) >= 1200.00000000);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trEventFire(2472);
      xsDisableRule("_BuildTowerS1_OFF_Plr1");
      trEcho("Trigger disabling rule BuildTowerS1_OFF_Plr1");
   }
}

rule _BridgeTowers_Setup0
highFrequency
active
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = ((trTimeMS()-(cActivationTime*1000)) >= 10);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(0,1,"zpSPCSocketCityTowerFlat",30);
      trEventFire(2426);
      xsDisableRule("_BridgeTowers_Setup0");
      trEcho("Trigger disabling rule BridgeTowers_Setup0");
   }
}

rule _BridgeTowers_Setup1
highFrequency
inactive
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = ((trTimeMS()-(cActivationTime*1000)) >= 10);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trSocketBuild(1, "281", "zpSPCCityTowerFlat");
      trSocketBuild(1, "282", "zpSPCCityTowerFlat");
      trSocketBuild(1, "283", "zpSPCCityTowerFlat");
      trSocketBuild(1, "284", "zpSPCCityTowerFlat");
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"zpSPCCityTowerFlat",30);
      trUnitSelectClear();
      trUnitSelectByID(223);
      trConvertUnitsInArea(1,0,"zpSPCSocketCityTowerFlat",30);
      xsDisableRule("_BridgeTowers_Setup1");
      trEcho("Trigger disabling rule BridgeTowers_Setup1");
   }
}

rule _Towers_ON1
highFrequency
active
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trTeamUnitCountSpecific(1, "zpSPCTowerOfLondon") >= 1);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trMinimapFlare(1, 10, vector(67.494499,1.000000,255.850296), True);
      trEventFire(9001);
      xsDisableRule("_Towers_ON1");
      trEcho("Trigger disabling rule Towers_ON1");
   }
}

rule _Towers_ON2
highFrequency
active
runImmediately
{
   bool bVar0 = (true);

   bool bVar1 = (trTeamUnitCountSpecific(2, "zpSPCTowerOfLondon") >= 1);


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      trMinimapFlare(2, 10, vector(67.494499,1.000000,255.850296), True);
      trEventFire(9002);
      xsDisableRule("_Towers_ON2");
      trEcho("Trigger disabling rule Towers_ON2");
   }
}

rule _DeadSelect
highFrequency
inactive
runImmediately
{
   bool bVar0 = (true);

   trUnitSelectClear();
   trUnitSelect("262148");
   bool bVar1 = (trUnitIsOwnedBy(1));


   bool tempExp = (bVar0 && bVar1);
   if (tempExp)
   {
      trSetUnitIdleProcessing(true);
      xsDisableRule("_DeadSelect");
      trEcho("Trigger disabling rule DeadSelect");
   }
}
