// mapcheck fixture: one bad proto, one bad grouping, one bad water type —
// the silent no-spawn class (guide 21.2). Expect exactly three S4 FAILs.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);

   int badID = rmCreateObjectDef("bad def");
   rmAddObjectDefItem(badID, "Musketeeer", 1, 0.0);
   rmPlaceObjectDefAtLoc(badID, 0, 0.5, 0.5);

   int gID = rmCreateGrouping("bad grouping", "Rogue_Factory_Japan");
   rmPlaceGroupingAtLoc(gID, 0, 0.4, 0.4);

   int lakeID = rmCreateArea("bad lake");
   rmSetAreaLocation(lakeID, 0.3, 0.7);
   rmSetAreaSize(lakeID, 0.02, 0.02);
   rmSetAreaWaterType(lakeID, "Atlantis Lake");
   rmBuildArea(lakeID);

   rmSetStatusText("", 1.0);
}
