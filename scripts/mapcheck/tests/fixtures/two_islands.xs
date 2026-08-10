// mapcheck fixture: two players on separate islands in open water — G5
// must report the separation as INFO (naval map assumed), never FAIL.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmSetSeaType("Amazon Rainforest River Muddy");
   rmTerrainInitialize("water");
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.35, 0);

   // Engine ring convention (pinned 2026-08-10): fraction 0 = NORTH,
   // clockwise — a P2 full ring lands players at (0.5,0.85)/(0.5,0.15).
   int isle1 = rmCreateArea("isle north");
   rmSetAreaLocation(isle1, 0.5, 0.85);
   rmSetAreaSize(isle1, 0.05, 0.05);
   rmSetAreaBaseHeight(isle1, 4.0);
   rmSetAreaCoherence(isle1, 1.0);
   rmBuildArea(isle1);

   int isle2 = rmCreateArea("isle south");
   rmSetAreaLocation(isle2, 0.5, 0.15);
   rmSetAreaSize(isle2, 0.05, 0.05);
   rmSetAreaBaseHeight(isle2, 4.0);
   rmSetAreaCoherence(isle2, 1.0);
   rmBuildArea(isle2);

   rmSetStatusText("", 1.0);
}
