extern const bool devMode = true;

// Inject the specified TR script.
void zpInclude(string filename = "", string foldername = "age-of-pirates")
{
    if (devMode)
    {
        rmCreateTrigger("Include " + filename);
        rmAddTriggerEffect("ZP Include");
        rmSetTriggerEffectParam("Foldername", foldername);
        rmSetTriggerEffectParam("Filename", filename);
    }
}
