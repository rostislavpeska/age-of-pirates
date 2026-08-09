// mapcheck fixture: exactly ONE same-block duplicate declaration ('a').
// Sibling-block redeclarations and for-header declarations are legal and
// must NOT be flagged.
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(400, 400);
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);

   int a = 1;
   int a = 2;

   if (a > 1) {
      int b = 1;
   }
   else {
      int b = 2;
   }

   for (int i = 0; i < 2; i++) {
      rmEchoInfo("first loop");
   }
   for (int i = 0; i < 3; i++) {
      rmEchoInfo("second loop");
   }

   rmSetStatusText("", 1.0);
}
