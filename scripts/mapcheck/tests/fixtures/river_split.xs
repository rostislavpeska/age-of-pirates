// mapcheck fixture: land map cut in two by a river with no fords — the two
// players cannot walk to each other and DEEP covers only the river band.
// Expect G5 FAIL (plan Part F class "is playable").
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.35, 0);

   // Horizontal river between the ring's P2 north/south anchors (engine
   // ring convention pinned 2026-08-10: fraction 0 = NORTH, clockwise).
   int riverID = rmRiverCreate(-1, "Amazon Rainforest River Muddy", 4, 4, 8, 8);
   rmRiverAddWaypoint(riverID, 0.0, 0.5);
   rmRiverAddWaypoint(riverID, 1.0, 0.5);
   rmRiverBuild(riverID);

   rmSetStatusText("", 1.0);
}
