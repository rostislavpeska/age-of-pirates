// mapcheck fixture: minimal clean land map — expects ZERO FAIL findings.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);

   int tcID = rmCreateObjectDef("player TC");
   rmAddObjectDefItem(tcID, "TownCenter", 1, 0.0);
   rmPlaceObjectDefPerPlayer(tcID, false, 1);

   rmSetStatusText("", 1.0);
}
