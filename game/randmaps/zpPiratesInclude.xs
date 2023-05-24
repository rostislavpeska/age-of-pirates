// If dev mode, load TR script from local file. Otherwise, load from subscription.
const bool isDevMode = true;

// The TR script to load.
const string trScriptDev = "../mods/local/age-of-pirates/game/randmaps/zpPiratesFeatures.xs";
const string trScriptSub = "../mods/subscribed/age-of-pirates/game/randmaps/zpPiratesFeatures.xs";

// Add Age of Pirates features to the map.
void zpAddPiratesFeatures(void)
{
    rmCreateTrigger("LoadPiratesFeatures");
    rmSwitchToTrigger(rmTriggerID("LoadPiratesFeatures"));
    rmAddTriggerEffect("Send Chat");
    rmSetTriggerEffectParamInt("PlayerID", 0);
    rmSetTriggerEffectParam("Message", "\");}} include \"" + (isDevMode ? trScriptDev : trScriptSub) + "\"; rule dfjhgadgi active { if (true) { xsDisableSelf(); //");
}
