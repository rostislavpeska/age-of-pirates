// mapcheck fixture: missing rmTerrainInitialize — documented crash cause
// (guide 21.1:10508). Expect S3 FAIL.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);
   rmSetStatusText("", 1.0);
}
