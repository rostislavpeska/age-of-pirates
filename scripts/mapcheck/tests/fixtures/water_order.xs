// mapcheck fixture: rmSetSeaType called AFTER the flooded terrain init —
// community guidance (AOE_Fan tutorial) orders it before. Expect S3 WARN.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("water");
   rmSetSeaType("Amazon Rainforest River Muddy");
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);
   rmSetStatusText("", 1.0);
}
