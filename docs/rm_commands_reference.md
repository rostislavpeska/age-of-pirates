# RM Commands Reference - Categorized

**Total Commands:** 266
**Source:** Official Documentation + Existing Reference (Merged & Organized)
**Last Updated:** 2025-11-05

## 📋 Table of Contents

1. [General Purpose](#general-purpose) - 43 commands
2. [Players](#players) - 22 commands
3. [Areas](#areas) - 42 commands
4. [Connections](#connections) - 18 commands
5. [Objects](#objects) - 17 commands
6. [Fair Locations](#fair-locations) - 7 commands
7. [Constraints](#constraints) - 21 commands
8. [Trade Routes](#trade-routes) - 8 commands
9. [Groupings](#groupings) - 8 commands
10. [Triggers](#triggers) - 20 commands
11. [Classes](#classes) - 2 commands
12. [Rivers](#rivers) - 3 commands
13. [Sub Civilizations](#sub-civilizations) - 1 commands
14. [Other Commands](#other-commands) - 54 commands

---

## General Purpose

**`rmAddMapTerrainByAngleInfo(string terrain, float minSlope, float maxSlope, float outerRange)`**
Adds a terrain to paint on tiles that are sloped between the specified angles (0 degrees is flat terrain, 90 degrees is sheer terrain), modified by a random number between 0.0 and outerRange.

**`rmAddMapTerrainByHeightInfo(string terrain, float minHeight, float maxHeight, float outerRange)`**
Adds a terrain to paint between the specified heights, modified by a random number between 0.0 and outerRange.

**`rmAreaFractionToTiles(float fraction)`**
Converts an area from fraction of the map to tile count. Fractions are relative to map size, so sometimes you may want to use them.

**`rmAreaTilesToFraction(int tiles)`**
Converts area tile count to fraction of map.

**`rmDefineConstant(string name, int value)`**
Defines an integer constant. This allows you to create named constants that can be used throughout your random map script for better code readability and maintainability.

**`rmDegreesToRadians(float degrees)`**
Converts an angle in degrees to radians.

**`rmEchoError( string echoString, int level )`**
Random map echo.

**`rmEchoInfo( string echoString, int level)`**
Random map echo. Use this to spit out information while debugging a script. It is not shown to the player.

**`rmEchoWarning( string echoString, int level )`**
Random map echo.

**`rmGetIsFFA()`**
Returns true if this map is set to be a FFA game which means each player on their own team.

**`rmGetIsKOTH()`**
Returns true if this map is set to be a King of the Hill game.

**`rmGetIsRelicCapture()`**
Returns true if this map is set to be a relic game..

**`int rmGetMapXSize( void )`**
Returns the X size of the map.

**`int rmGetMapZSize( void )`**
Returns the Z size of the map.

**`rmGetNomadStart()`**
Returns true if this map is to place a covered wagon instead of a town center.

**`rmGetSeaLevel()`**
Gets the sea level for the map.

**`rmIsMapType( string type )`**
Returns true if the map belongs to the given type.

**`rmMetersToTiles(float meters)`**
Converts a distance in meters to a number of tiles.

**`rmRandFloat(float min, float max)`**
Returns a random float between min and max. This is a random number generator useful for determining random events. Because it is a float, it can handle decimals.

**`rmRandInt(int min, int max)`**
Returns a random integer between min and max. This is a random number generator useful for determining random events. Because it is an integer, it cannot handle decimals, but that makes it useful for placing down numbers of objects.

**`rmSetBaseTerrainMix(string mixName)`**
Initializes the base terrain with the requested mix. Call before rmTerrainInitialize.

**`rmSetGaiaCiv(long civ)`**
Sets Gaia's civilization. This is only useful if you place Gaia objects that vary by civilization, such as special civilisation units.

**`rmSetLightingSet(string name)`**
Sets a lighting set. You can specify a lighting set from the scenario editor to be used for your RMS. This command must be placed after terrain is initialized.

**`rmSetMapElevationHeightBlend(int blend)`**
Sets how much to smooth the overall terrain after initializing with noise.

**`rmSetMapElevationParameters(int type, float freq, int octaves, float persistence, float variation)`**
Sets up terrain for initializing with a noise layer.

**`rmSetMapSize( int x, int z)`**
Sets the size of the map. X and Z are in meters. They do not need to be the same if you want to create a rectangular map. All ES maps scale map size by number of players.

**`rmSetMapType( string type )`**
Indicates that this map is of a certain type (it can be multiple types simultaneously.

**`rmSetNuggetDifficulty(int minLevel, int maxLevel)`**
Sets the min/max difficulty levels for placing nuggets.

**`rmSetSeaLevel()`**
Sets the sea level for the map.

**`rmSetSeaType(string name)`**
Sets the sea type for the map. This is used if terrain is initialized to water.

**`rmSetStatusText(status, progress)`**
Sets the friendly cool loading screen text. This text will be seen by players while the map is generating. If you do not at least specify percentages in the progress parameter, the “loading bar” will not advance during map generation.

**`rmSetWindMagnitude(float magnitude)`**
sets the global wind magnitude (1.0f is default).

**`rmTerrainInitialize( string baseTerrain, float height)`**
Initializes the terrain to the base type and height. Specifies the base terrain to use for a map. If set to water, sea type needs to be defined. Initial terrain is usually grass, sand, snow or water.

**`rmTilesToMeters(int tiles)`**
Converts a number of tiles to a distance in meters.

**`rmXFractionToMeters(float meters)`**
Converts a fraction of the map in the x direction to meters

**`rmXFractionToTiles(float fraction)`**
Converts an fraction of the map in the x direction to tile count.

**`rmXMetersToFraction(float meters)`**
Converts meters into a fraction of the map in the x direction.

**`rmXTilesToFraction(int tiles)`**
Converts tile count in the x direction to fraction of map.

**`rmZFractionToMeters(float meters)`**
Converts meters a fraction of the map in the z direction to meters.

**`rmZFractionToTiles(float fraction)`**
Converts an fraction of the map in the z direction to tile count.

**`rmZMetersToFraction(float meters)`**
Converts meters into a fraction of the map in the z direction.

**`rmZTilesToFraction(int tiles)`**
Converts tile count in the z direction to fraction of map.

**`sqrt(float x)`**
Returns the square root of x.

---

## Players

**`int rmGetAverageHomeCityLevel( void )`**
Returns the average (rounded down) HC Level of the players in the game.

**`rmGetCivID(string civilization)`**
Sets the civilization to compare with the players civilization. Example:

**`int rmGetHighHomeCityLevel( void )`**
Returns the highest HC Level of the players in the game.

**`int rmGetHomeCityLevel( int playerID )`**
Returns the HC Level of the given player.

**`int rmGetLowHomeCityLevel( void )`**
Returns the lowest HC Level of the players in the game.

**`rmGetNumberPlayersOnTeam(int teamID)`**
Gets the number of players on the given team. Useful for scaling area or resources in a team area based on number of players on that team.

**`rmGetPlayerCiv(int playerID)`**
Gets the civilization the specified player is on.

**`rmPlacePlayer(2, 0.8, 0.2)`**
Sets one player location.

**`rmPlacePlayersCircular(float minFraction, float maxFraction, float angleVariation)`**
Makes a circle of player locations. Places players in a circle. Variation is determined by the difference between the min and max. Angle variation determines whether players are equidistant or can be slightly closer or farther apart. Circular placement is generally the most versatile, but will not work on all map types, such as non-square maps.

**`rmPlacePlayersLine(0.2, 0.8, 0.8, 0.8, 20, 10)`**
Makes a line of player locations.

**`rmPlacePlayersRiver(int riverID, float distVariation, float spacingVariation, float edgeDistance)`**
Makes a line of player locations along the specified river.

**`rmPlacePlayersSquare(float dist, float distVariation, float spacingVariationfloat)`**
Makes a square of player locations. Places players in a square, which automatically adjusts to a rectangle for rectangular maps. Unlike the circle, variance here is determined by a plus or minus (the distVariation) off of the mean distance. SpacingVariation determines whether players are equidistant or can be slightly closer or farther apart.

**`rmPlayerLocXFraction(int playerID)`**
Gets a player's start location x fraction.

**`rmPlayerLocZFraction(int playerID)`**
Gets a player's start location z fraction. Use these commands when you don’t know where a player’s starting location is and you need the values to place other areas or resources.

**`bool rmSetHomeCityGatherPoint( int playerID, vector point )`**
Sets the HCGP for the given player.

**`bool rmSetHomeCityWaterSpawnPoint( int playerID, vector point )`**
Sets the HCWSP for the given player.

**`rmSetPlacementSection(float fromPercent, float toPercent)`**
When placing players in a circle or square, this command allows you to skip part of the circle or square, in essence removing a slice from the pie (maybe you want to fit an ocean or sea in there like in Texas). The default for fromPercent is 0, and the default for toPercent is 1. That means use the whole circle or square. You can pass in something like 0.25 and 0.50 to have the players placed from 25% in to 50% in along the circle or square. For circular placement, 0 is at 9:00, 0.25 is at 12:00, 0.5 is at 3:00, and 0.75 is at 6:00. For square placement (think of the square as a line that follows a square), 0 is at 6:00, 0.25 is at 9:00, 0.5 is at 12:00, and 0.75 is at 3:00.

**`rmSetPlacementTeam(-1)`**
Sets the team to place.

**`rmSetPlayerArea(int playerID, int areaID)`**
Sets a player's 'official' area.

**`rmSetPlayerPlacementArea(float minX, float minZ, float maxX, float maxZ)`**
Sets the area of the map to use for player placement. Use this command if, for example, you want to place players in one quadrant of a map.

**`rmSetTeamArea(int teamID, int areaID)`**
Sets a team's 'official' area. When you want an area to belong to a player (i.e. this is the location from which you will place player resources) assign it to a player. Teams work the same way. Usually you want to iterate through number of players using for(i=1; <cNumberPlayers).

**`rmSetTeamSpacingModifier(float modifier)`**
Sets the team spacing modifier. Normally, all players are placed equidistant. This command allows you to force team members closer together. Values of 0.3-0.5 return the best results. Values less than 0.25 may not provide enough space for starting resources.

---

## Areas

**`rmAddAreaCliffEdgeAvoidClass(int areaID, int avoidID, float minDist)`**
Adds a class for an area's cliff edge to avoid. You can tell a cliff edge to avoid a certain class, such as a connection. Remember that connections must be created before the cliff (see below).

**`rmAddAreaCliffRandomWaypoints(int areaID, float endXFraction, float endZFraction, int count, float maxVariation)`**
Adds random waypoints to the specified cliff valley area.

**`rmAddAreaCliffWaypoint(int areaID, float xFraction, float zFraction)`**
Adds the given waypoint to the specified cliff area (for valleys).

**`bool rmAddAreaConstraint(int areaID, int constraintID)`**
Add specified constraint to an area.

**`rmAddAreaInfluencePoint(int areaID, float xFraction, float zFraction)`**
Adds an area influence point.

**`rmAddAreaInfluenceSegment(int areaID, float xFraction1, float zFraction1, float xFraction2, float zFraction2)`**
Adds an area influence segment. You may want an area to grow towards specific points or lines. A circular area placed at the center of the map with an influence point of 1, 1 will produce a peninsula that protrudes towards 12 o’clock. Influence points and segments can be useful in getting areas, such as rivers, to extend beyond the edge of the map.

**`rmAddAreaRemoveType(int areaID, string typeName)`**
Add an unit type that the specified area removes. Sometimes you may want an area to clean itself of objects, such as removing trees from ice. This will only work if the objects are already placed before the area, which is the reverse of how most ES maps are generated. You can reference specific units or abstract types, such as “unit” and “building.”

**`rmAddAreaTerrainLayer(bonusIslandID, "texas\ground4_tex", 0, 6)`**
Adds a terrain layer to an area.

**`rmAddAreaTerrainReplacement(int areaID, string terrainTypeName, string newTypeName)`**
Adds a terrain replacement rule to the area. If you place an area with no terrain specified, it will use the terrain of the parent area (including the base map). However, specifying terrain replacement will paint an area only when another texture is present. This command is most useful with connections, where you want to replace water with land where a connection goes across a river, or replace rock with snow for mountain passes.

**`bool rmAddAreaToClass(int areaID, int classID)`**
Add given area to specified class.

**`rmAreaID(string name)`**
Gets area ID for given area name.

**`rmBuildAllAreas()`**
Simulatenously builds all unbuilt areas. Does not include connections.

**`rmBuildArea(int areaID)`**
Builds the specified area. Actually builds the area. Choosing when to use this command can have a big effect on your map. For example, if you define a lake area and then build it, land that is placed later can stick into the lake or be placed as islands. On the other hand, if the land and water are built at the same time, they will try to avoid each other (if the proper constraints are set). Generally, player areas should all be built at the same time to make sure there is enough space for ever player.

**`rmCreateArea(string name, int parentAreaID)`**
Creates an area. Creates an area and lets you name it. Areas without a parentArea use the entire map as their parentArea. You can also make existing areas the parentArea, in order to place a sub-area within a player area, for example. Areas will generally try to place several times and will return an error message if they fail. To ignore this error message, use setAreaWarnFailure below.

**`rmFindCloserArea(float xFraction, float zFraction, int area1, int area2)`**
Returns which area is closer.

**`vector rmGetAreaClosestPoint( int areaID, vector point, float pullback, int constraintID )`**
Returns the point in areaID that's closest to the given point, optionally requiring that it pass the given constraint.

**`rmPaintAreaTerrain(int areaID)`**
Paints the terrain for a specified area.

**`rmPaintAreaTerrainByAngle(long areaID, string terrain, float minAngle, float maxAngle, float outerRange)`**
Paints the area's tiles in the specified angle range with specified terrain (with outerRange buffer if feathering is desired).

**`rmSetAreaBaseHeight(int areaID, float height)`**
Sets the base height for an area. If not specified, the area will adopt the height of the parent area, including the base height of the map if no parent area is specified. Make sure to place land higher than water if you want to place land objects (such as TownCenter) later.

**`rmSetAreaCliffEdge(int areaID, int count, float size, float variance, float spacing, int mapEdge)`**
Set cliff edge parameters for an area. Determines whether there should be pathable ramps or not connecting the top of the cliff to the surrounding area. Count - Number of cliff edges to create. The count times the size should not be more than 1.0. Defaults to 1. size - This specifies how much of the area's outline should be turned into cliff edges. It should be between 0.0 and 1.0. Set to 1.0 to make the whole area surrounded. Defaults to 0.5. Variance - The variance to use for the size. Defaults to 0.0. Spacing - Spacing modifier. This should be between 0.0 and 1.0. The smaller this is, the closer together the cliff edges will be. Defaults to 1.0. MapEdge - Specifies where the cliff edge should be in relation to the map edge. Set to 0 for any, 1 to be away from the map edge, or 2 to be close to the map edge. Defaults to 0.

**`rmSetAreaCliffHeight(int areaID, float val, float variance, float ramp)`**
Set an area's cliff height. Val - Make positive for raised cliffs and negative for lowered cliffs. Defaults to 4.0.

**`rmSetAreaCliffPainting(int areaID, bool paintGround, bool paintOutsideEdge, bool paintSide, float minSideHeight, bool paintInsideEdge)`**
Set cliff painting options for an area. Determines how a cliff is painted with impassable and passable textures. PaintGround - Specifies if the ground should be painted or just left whatever it already is. Defaults true. PaintSide - Specifies if the cliff sides should be painted. Defaults true. PaintEdge - Specifies if the cliff edge should be painted. This is the area between the cliff side and the ground. Defaults true. MinSideHeight - Specifies the minimum height that a cliff tile must be sloped before treating it as a cliff side. Set to 0 to have the minimum amount of cliff sides painted. Defaults to 1.5.

**`rmSetAreaCliffType(int areaID, string cliffName)`**
Sets the cliff type for an area. Cliffs are handled differently from other terrain in order to allow you to handle features like ramps. However, you can use setAreaTerrainType to place an impassable cliff-texture as a normal area as well. CliffName should use a cliff type from the Editor.

**`rmSetAreaCoherence(int areaID, float coherence)`**
Sets area coherence (0-1). Coherent areas tend to stay together more. The effect is harder to notice on smaller areas.

**`rmSetAreaForestClumpiness(int areaID, float density)`**
Sets the forest density for an area.

**`rmSetAreaForestDensity(int areaID, float density)`**
Sets the forest density for an area.

**`rmSetAreaForestType(int areaID, string forestName)`**
Sets the forest type for an area.

**`rmSetAreaForestUnderbrush(int areaID, float density)`**
Sets the forest density for an area.

**`rmSetAreaHeightBlend(int areaID, int heightBlend)`**
Sets how smoothly area height blends into surroundings. Corresponds to the smooth tool in the Scenario Editor. Usually a heightBlend of 0 will leave geometric-looking jagged edges. A heightBlend of 1 will smooth smaller areas. A heightBlend of 2 will smooth larger areas or areas of disproportionate heights. Anything above 2 may flatten an area completely.

**`rmSetAreaLocPlayer(int areaID, int playerID)`**
Set the area location to player's location. This is a shortcut for placing an area at the player’s location. Generally, this is used when tiny player areas are first placed as placeholders, then SetAreaLocPlayer can be used to make larger player areas later or to place a sub-area (such as a terrain patch) near the player’s Town Center.

**`rmSetAreaLocTeam(int areaID, int teamID)`**
Set the area location to team's location. Just like SetAreaLocPlayer except it applies to team areas.

**`rmSetAreaLocation(int areaID, float xFraction, float zFraction)`**
Set the area location. Sometimes you want to place an area in a specific location, such as 0.5, 0.5, the center of the map.

**`rmSetAreaMaxBlobDistance(int areaID, float dist)`**
Sets maximum blob distance. Specifies how far apart blobs can be from each other. The greater the distance, the more the area will tend towards serpentine instead of circular (envision a chain of beads). However, if you specify many blobs, this variation may become obscured as more and more blobs are placed for the area.

**`rmSetAreaMaxBlobs(int areaID, int blobs)`**
Sets maximum number of area blobs. An area can be placed with multiple blobs. Blobs are placed independently, using the minimum and maximum distances below. Areas made with a single blob will be circular. Areas made with multiple blobs can be come long and sinuous.

**`rmSetAreaMinBlobDistance(int areaID, float dist)`**
Sets minimum blob distance.

**`rmSetAreaMinBlobs(int areaID, int blobs)`**
Sets minimum number of area blobs.

**`rmSetAreaSize(float minFraction, float maxFraction)`**
Set the area size to a min/max fraction of the map. The min and max can be set to the same value if you want no size variation. Experiment with different values to make sure your area is not too large or too small to be seen. Even if your area does not place special terrain, it can be helpful to temporarily paint the area with a distinct texture, such as black or snow, to see where and if it is actually getting placed.

**`rmSetAreaSmoothDistance(int areaID, int smoothDistance)`**
Sets area edge smoothing distance. Distance is number of neighboring points to consider in each direction. Water areas benefit from more smoothness as it eliminates small bumps and indentations.

**`rmSetAreaTerrainLayerVariance(int areaID, bool variance)`**
Specifies if the area should vary the terrain layer edges. Usually, variance in terrain layers looks better, but sometimes you might want to turn it off. Defaults to true.

**`rmSetAreaTerrainType(bonusIslandID, "texas\ground2_tex")`**
Sets the terrain type for an area.

**`rmSetAreaWarnFailure(int areaID, bool warn)`**
Sets whether the area build process will warn if it fails. It is very easy to over-constrain areas to the point where there is no room for them. This can cause two problems: the map may take a long time to generate, or if you are in debug mode (see above), the debugger will pop up and generation will stop. Sometimes you want to catch these errors, but when you are done with your map it is a good idea to set SetAreaWarnFailure to false.

**`rmSetAreaWaterType(int areaID, string waterName)`**
Sets the water type for an area. Paints the area with a water type. Use the water types from the scenario editor. Because water types automatically change elevation and can place objects, they tend to affect areas a little larger than specified. Just allow plenty of room.

---

## Connections

**`rmAddConnectionArea(int connectionID, int areaID)`**
Adds an area to the connection. This is only valid if you set the connection type is set to cConnectAreas. You must specify this while defining the area, after the connection is defined, and before building the connection.

**`bool rmAddConnectionConstraint(int connectionID, int constraintID)`**
Add specified constraint to a connection.

**`bool rmAddConnectionEndConstraint(int connectionID, int constraintID)`**
Add specified constraint for a connection end point.

**`bool rmAddConnectionStartConstraint(int connectionID, int constraintID)`**
Add specified constraint for a connection start point.

**`rmAddConnectionTerrainReplacement(int connectionID, string terrainTypeName, string newTypeName)`**
Adds a terrain replacement rule to the connection. These commands all work exactly as they do for areas, but must be called out specifically for connections.

**`rmAddConnectionToClass(int connectionID, int classID)`**
Adds the connection to specified class. Useful with constraints for areas or objects placed after the connection.

**`rmBuildConnection(int connectionID)`**
Builds the given connection. Make sure the areas are built first. RmBuildAllAreas does not include connections.

**`rmCreateConnection(string name)`**
Creates an connection. Defines a new connection.

**`rmSetConnectionBaseHeight(int connectionID, float width)`**
Sets the base height of a connection.

**`rmSetConnectionBaseTerrainCost(int connectionID, float cost)`**
Sets the base terrain cost for a connection. This is the cost that will be used for all terrains that don't have a cost set with rmSetConnectionTerrainCost. The default cost for each terrain type is 1 if this is not called.

**`rmSetConnectionCoherence(int connectionID, float width)`**
Sets area coherence (0-1).

**`rmSetConnectionHeightBlend(int connectionID, float width)`**
Sets how smoothly connection height blends into surroundings.

**`rmSetConnectionPositionVariance(int connectionID, float variance)`**
Sets the position variance of a connection. The connection will normally start at the area's position, but this allows it to vary from that position. You can set this to -1 for it to pick completely random positions within the starting and ending areas. This command is often needed when specifying multiple connections (for example, one within a team and another between teams) so that the connections do not overlap.

**`rmSetConnectionSmoothDistance(int connectionID, float width)`**
Sets connection edge smoothing distance (distance is number of neighboring points to consider in each direction).

**`rmSetConnectionTerrainCost(int connectionID, string terrainTypeName, float cost)`**
Sets the terrain cost for a connection. When you need a connection to avoid a type of terrain, set this value. If you place roads between players, you might want them to avoid forests or cliffs. The cost must be greater than or equal to 1, or set to -1 to specify a terrain is impassable.

**`rmSetConnectionType(int connectionID, int connectionType, bool connectAll, float connectPercentage)`**
Sets the connection type. This command determines which players are connected. The valid values for connectionType are:

**`rmSetConnectionWarnFailure(int connectionID, bool warn)`**
Sets whether a connection warns on failure.

**`rmSetConnectionWidth(int connectionID, float width, float variance)`**
Sets the width of a connection. Because connections are often the only pathable area over a barrier such as water or rock, set this wide enough to prevent pathing problems, typically > 8.

---

## Objects

**`rmAddObjectDefConstraint(id, playerConstraint)`**
Add specified constraint to given object def.

**`rmAddObjectDefItem(id, "TownCenter", 1, 0.0)`**
for(i=1; <cNumberPlayers) { for(j=0; <rmGetNumberFairLocs(i))

**`rmAddObjectDefToClass(startingOutpostID2, classOutpost)`**
Add given object def to specified class.

**`rmCreateObjectDef(string name)`**
Creates an object definition. Used to define a new object.

**`rmGetNumberUnitsPlaced(int objectDefID)`**
These three commands can be used to detect failed cases of object placement. Perhaps you want to try and place an object a second time with fewer constraints if it fails the first time.

**`rmGetUnitPlaced(int objectDefID, int index)`**
Returns the unit ID at the specified index for the given object definition.

**`rmGetUnitPlacedOfPlayer(int objectDefID, int playerID)`**
Returns the unit ID placed for the specified player.

**`vector rmGetUnitPosition( int unitID )`**
Returns the position of the unit.

**`rmPlaceObjectDefAtAreaLoc(int defID, int playerID, int areaID, long placeCount)`**
Place object definition for the player at the given area's location. The difference between this and placeObjectDefAtLoc is that the latter needs an X, Z coordinate, while this command just finds the area’s center location.

**`rmPlaceObjectDefAtLoc(int defID, int playerID, float xFraction, float zFraction, long placeCount)`**
Place object definition at specific location for given player. Placing objects this way is useful when you don’t want to place them for every player, as in the case where you place different units for different civilizations. You can set int playerID to 0 to make sure nobody owns the object. Here’s a nice shortcut:

**`rmPlaceObjectDefAtRandomAreaOfClass(int defID, int playerID, int classID, long placeCount)`**
Place object definition for the player at the location of a random area in the given class.

**`rmPlaceObjectDefInArea(int defID, int playerID, int areaID, long placeCount)`**
Place object definition for the player in the given area. Places the object randomly within the entire area (as apposed to the center location).

**`rmPlaceObjectDefInRandomAreaOfClass(int defID, int playerID, int classID, long placeCount)`**
Place object definition for the player in a random area in the given class. The difference between these two is that the first uses the area’s location while the second just finds a random location within an area. Return playerID as 0 to place an object not owned.

**`rmPlaceObjectDefPerPlayer(int defID, bool playerOwned, long placeCount)`**
Place object definition per player. This command is often the fastest way to place objects, particularly when compared to doinf for loops over player number. However, it isn’t applicable when you don’t want to place the object at least once for every player. Return playerOwned as false if you want the object to belong to gaia.

**`rmSetIgnoreForceToGaia(bool val)`**
Can be used to force any placed object, even resources, to belong to a player. This overrides the default behavior where certain objects (like resources) are automatically assigned to Gaia.

**`rmSetObjectDefMaxDistance(int defID, float dist)`**
Set the maximum distance for the object definition (in meters). These distances apply to the object location. If the object location equals a player’s location, then these are the min and max from the player starting area (usually the Town Center). A useful approach is to place the object at location 0.5, 0.5 (the center of the map) and assign a maxDistance of half of the map. See the subchapter "Map Grid" above for more explanations.

**`rmSetObjectDefMinDistance(int defID, float dist)`**
Set the minimum distance for the object definition (in meters).

---

## Fair Locations

**`int rmAddFairLoc(string unitName, bool forward, bool inside, float minPlayerDist, float maxPlayerDist, float locDist, float edgeDist, bool playerArea, bool teamArea)`**
Adds some fairLoc placement info.

**`bool rmAddFairLocConstraint(int fairLocID, int constraintID)`**
Add specified constraint to a fairLoc placement.

**`float rmFairLocXFraction(int playerID, int index)`**
Gets a player's fairLoc x fraction.

**`float rmFairLocZFraction(int playerID, int index)`**
Gets a player's fairLoc z fraction.

**`int rmGetNumberFairLocs(int playerID)`**
Gets a player's number of fairLocs.

**`bool rmPlaceFairLocs()`**
Sets fairLoc placement locations.

**`rmResetFairLocs()`**
Resets fairLoc placment info. Once you are done with a set of fairLocs and want to create another set, you should call rmResetFairLocs. This clears out any fairLocs you previously added.

---

## Constraints

**`rmConstraintID(string name)`**
Gets constraint ID for given constraint name.

**`int rmCreateAreaConstraint(string name, int areaID)`**
Make a constraint that forces something to remain within an area.

**`int rmCreateAreaDistanceConstraint(string name, int areaID, float distance)`**
Make an area distance constraint.

**`int rmCreateAreaMaxDistanceConstraint(string name, int areaID, float distance)`**
Make an area max distance constraint.

**`int rmCreateAreaOverlapConstraint(string name, int areaID)`**
Make an area overlap constraint.

**`int rmCreateBoxConstraint(string name, float startX, float startZ, float endX, float endZ, float bufferFraction)`**
Make a box constraint.

**`int rmCreateClassDistanceConstraint(string name, int classID, float distance)`**
Make a class distance constraint.

**`int rmCreateCliffEdgeConstraint(string name, int areaID)`**
Make a constraint that forces something to remain within an area's cliff edge.

**`int rmCreateCliffEdgeDistanceConstraint(string name, int areaID, float distance)`**
Make an area cliff edge distance constraint.

**`int rmCreateCliffEdgeMaxDistanceConstraint(string name, int areaID, float distance)`**
Make an area cliff edge max distance constraint.

**`int rmCreateCliffRampConstraint(string name, int areaID)`**
Make a constraint that forces something to remain within an area's cliff ramp edge.

**`int rmCreateCliffRampDistanceConstraint(string name, int areaID, float distance)`**
Make an area cliff ramp edge distance constraint.

**`int rmCreateCliffRampMaxDistanceConstraint(string name, int areaID, float distance)`**
Make an area cliff ramp edge max distance constraint.

**`int rmCreateEdgeConstraint(string name, int areaID)`**
Make a constraint that forces something to remain within an area's edge.

**`int rmCreateEdgeDistanceConstraint(string name, int areaID, float distance)`**
Make an area edge distance constraint.

**`int rmCreateEdgeMaxDistanceConstraint(string name, int areaID, float distance)`**
Make an area edge max distance constraint.

**`int rmCreateMaxHeightConstraint(string name, float height)`**
Make an max height constraint (terrain must be less than given height).

**`int rmCreateTerrainDistanceConstraint(string name, string type, bool passable, float distance)`**
Make a constraint to avoid terrain with certain a passability.

**`int rmCreateTerrainMaxDistanceConstraint(string name, string type, bool passable, float distance)`**
Make a constraint to be close to terrain with certain a passability.

**`int rmCreateTradeRouteDistanceConstraint(string name, float minDistance)`**
Make a constraint to avoid trade routes.

**`int rmCreateTypeDistanceConstraint(string name, int classID, float distance)`**
Make a type distance constraint.

---

## Trade Routes

**`rmAddRandomTradeRouteWaypoints(int tradeRouteID, float endXFraction, float endZFraction, int count, float maxVariation)`**
Adds random waypoints to the specified trade route.

**`rmAddRandomTradeRouteWaypointsVector(int tradeRouteID, vector v, int count, float maxVariation)`**
Adds random waypoints to the specified trade route.

**`rmAddTradeRouteWaypoint(int tradeRouteID, float xFraction, float zFraction)`**
Adds the given waypoint to the specified trade route.

**`rmAddTradeRouteWaypointVector(int tradeRouteID, vector v)`**
Adds the given waypoint to the specified trade route.

**`rmBuildTradeRoute(int tradeRouteID, string terrainTypeName)`**
Builds the trade route with the given terrain type.

**`rmCreateTradeRoute()`**
Creates a trade route.

**`rmCreateTradeRouteWaypointsInArea(int tradeRouteID, int areaID, float length)`**
Creates a trade route in the specified area.

**`rmGetTradeRouteWayPoint(int tradeRouteID, float fraction)`**
Retrieves a waypoint along the trade route based on the fraction.

---

## Groupings

**`bool rmAddGroupingConstraint(int GroupingID, int constraintID)`**
Add specified constraint to a grouping.

**`bool rmAddGroupingToClass(int GroupingID, int classID)`**
Add given grouping to specified class.

**`rmCreateGrouping(string name, string filename)`**
Creates a grouping.

**`bool rmPlaceGroupingAtLoc(int groupingID, int playerID, float xFraction, float zFraction, int placeCount)`**
Place grouping at specified location.

**`bool rmPlaceGroupingAtPoint(int groupingID, int playerID, vector point, int placeCount)`**
Place grouping at specified point.

**`rmPlaceGroupingInArea(int groupingID, int playerID, int areaID, int placeCount)`**
Place grouping for the player in the given area.

**`rmSetGroupingMaxDistance(int defID, float dist)`**
Set the maximum distance for the grouping (in meters).

**`rmSetGroupingMinDistance(int defID, float dist)`**
Set the minimum distance for the grouping (in meters).

---

## Triggers

**`rmAddTriggerCondition(string conditionType)`**
Adds a condition to the current trigger. Refer to C:\...\Age of Empires III\trigger\typetest.xml for lists of available conditions and their parameters.

**`rmAddTriggerEffect(string effectType)`**
Adds an effect to the current trigger. Refer to C:\...\Age of Empires III\trigger\typetest.xml for lists of available effects and their parameters.

**`rmAddUnitsToArmy(int playerID, int armyID, int objectDefID)`**
Triggers that affect armies require that the armies be defined first.

**`rmCreateArmy(int playerID, string armyName)`**
Creates an army for the specified player. Triggers that affect armies require that the armies be defined first.

**`rmCreateTrigger(string triggerName)`**
Used to create a new trigger. Example: rmCreateTrigger("MyTrigger1");

**`rmSetTriggerActive(bool active)`**
Sets the activity of the trigger straight after the map was loaded. If you want to fire this trigger later in game select false, else true.

**`rmSetTriggerConditionParam(string paramName, string value, bool add)`**
Sets a string parameter for the current trigger condition. The 'add' parameter determines if this is an additional parameter or replaces existing ones.

**`rmSetTriggerConditionParamArmy(string paramName, int playerID, int armyID, bool add)`**
Sets an army parameter for the current trigger condition. Refer to C:\...\Age of Empires III\trigger\typetest.xml for lists of available conditions and their parameters.

**`rmSetTriggerConditionParamFloat(string paramName, float value, bool add)`**
Sets a float parameter for the current trigger condition.

**`rmSetTriggerConditionParamInt(string paramName, int value, bool add)`**
Sets an integer parameter for the current trigger condition.

**`rmSetTriggerEffectParam(string paramName, string value, bool add)`**
Sets a string parameter for the current trigger effect. Example: rmSetTriggerEffectParam("ResName","Food").

**`rmSetTriggerEffectParamArmy(string paramName, int playerID, int armyID, bool add)`**
Sets an army parameter for the current trigger effect. Armies must be created first using rmCreateArmy.

**`rmSetTriggerEffectParamFloat(string paramName, float value, bool add)`**
Sets a float parameter for the current trigger effect. Refer to C:\...\Age of Empires III\trigger\typetest.xml for lists of available effects and their parameters.

**`rmSetTriggerEffectParamInt(string paramName, int value, bool add)`**
Sets an integer parameter for the current trigger effect. Example: rmSetTriggerEffectParamInt("Amount",1000).

**`rmSetTriggerLoop(bool loop)`**
Sets the repetition mode of the trigger. Be careful using loops, since they can easily run mad and stop. Better use 2 triggers instead and fire them towards each other, using the "Fire Event" trigger effect.

**`rmSetTriggerPriority(int priority)`**
Sets the trigger priority. priority has values between 0 (low) and 4 (highest).

**`rmSetTriggerRunImmediately(bool runImmediately)`**
runImmediately should always be true if you use the trigger for firing cinematics or sounds.

**`rmSetVCFile(string filename)`**
You can set up alternate victory condition files for your RMS. This feature is fairly complex and should only be attempted by an advanced user.

**`rmSwitchToTrigger(int triggerID)`**
This command is useful for setting up triggers by player. You need to define all the triggers first, but then you can switch to different ones to specify their conditions and effects. Example:

**`rmTriggerID(string triggerName)`**
Like areas and objects, triggers must be defined before they can be used.

---

## Classes

**`rmClassID(string name)`**
Gets class ID for given class name.

**`int rmDefineClass(string className)`**
Define a class with the given name.

---

## Rivers

**`rmRiverAddWaypoint(riverID, xFraction, zFraction)`**
Add waypoint to a river. Don't mix with rmRiverSetConnections or rmRiverConnectRiver

**`rmRiverCreate(int areaID, string waterType, int breaks, int offset, int minR, int maxR)`**
make a river dude.

**`rmSetRiverFoundationParams(int tileBuffer, float heightOffset) -- sets up river foundation parameters`**
the terrain buffer around the river, and the height of the banks above water level

---

## Sub Civilizations

**`rmSetSubCiv(int index, string civName, bool big)`**
Sets a given sub civ in the world.

---

## Other Commands

Commands not yet categorized or with unclear categorization.

**`CliffEdgermSetArea(int areaID, int count, float size, float variance, float spacing, int mapEdge)`**
Set cliff edge parameters for an area.

**`rmAddClosestPointConstraint( int constraintID )`**
Adds constraint to closest point finder.

**`rmAddMerc(string unitName, float count, float minCount, float maxCount, float countIncrement, bool multipleUses )`**
Adds mercs of to the merc manager for this game.

**`rmAddObjectDefItemByTypeID(int defID, int unitTypeID, int count, float clusterDistance)`**
Add item to object definition.

**`rmAddPlayerResource(int playerID, string resourceName, float amount)`**
Adds to a player's resource amount.

**`rmAllocateSubCivs(int number)`**
Allocates the number of sub civs in the world.

**`rmClearClosestPointConstraints()`**
Clears constraints for closest point finder.

**`int rmCreateCornerConstraint(string name, int corner, bool outside)`**
Make a constraint to pass if in or out of a corner.

**`bool rmCreateHCGPAllyConstraint(string name, long playerID, float minDistance)`**
Create home city gather point constraint to avoid given player's ally's HCGPs.

**`bool rmCreateHCGPConstraint(string name, float minDistance)`**
Create home city gather point constraint to avoid all HCGPs.

**`bool rmCreateHCGPEnemyConstraint(string name, long playerID, float minDistance)`**
Create home city gather point constraint to avoid given player's enemy's HCGPs.

**`bool rmCreateHCGPSelfConstraint(string name, long playerID, float minDistance)`**
Create home city gather point constraint to avoid given player's HCGP.

**`int rmCreatePieConstraint(string name, float xFraction, float zFraction, float insideRadius, float outsideRadius, float minAngle, float maxAngle, float bufferFraction)`**
Makes a 'pie' constraint.

**`rmCreateStartingUnitsObjectDef(float clusterDistance)`**
Creates special object definition for starting units with the given cluster distance.

**`rmDoLightingEffect("lightSetName", blendInTime, effectTime, blendOutTime)`**
applies a lighting set effect.

**`rmDoLightingFade("lightSetName", fadeTime)`**
applies a lighting set fade.

**`rmEnableLocalWater( bool enable )`**
Enables / disables local water disturbances.

**`rmFillMapCorners()`**
Fill map corners with blackmap.

**`rmFindClosestPoint(float xFraction, float zFraction, float maxDistance)`**
Finds closest point satisfying the preset constraints.

**`rmGetPlayerCulture(int playerID)`**
Gets the culture the specified player is on.

**`rmGetPlayerName(int playerID)`**
Gets a player's name.

**`rmGetPlayerTeam(int playerID)`**
Gets the team the specified player is on.

**`rmMultiplyPlayerResource(int playerID, string resourceName, float factor)`**
Multiplys a player's resource amount by the given factor.

**`rmPaintAreaTerrainByHeight(long areaID, string terrain, float minHeight, float maxHeight, float outerRange)`**
Paints the area's tiles in the specified height range with specified terrain (with outerRange buffer if feathering is desired).

**`rmPlaceMapClusters(string terrain, string protounit)`**
place object clusters (of the specified protounit) around the map, and also optionally paint with the specified terrain.

**`rmPlaceObjectDefAtPoint(int defID, int playerID, vector point, int placeCount)`**
Place object definition at specific point for given player.

**`rmSetAreaEdgeFilling(int areaID, int borderSize)`**
Enable edge filling and set a border search size (for Carolina and similar maps with a big continent).

**`rmSetAreaElevationEdgeFalloffDist(int areaID, float dist)`**
Sets the area elevation noise to falloff as it gets closer to the area edge.

**`rmSetAreaElevationMinFrequency(int areaID, float freq)`**
Sets the area elevation variation noise frequency (best >0 and <1).

**`rmSetAreaElevationNoiseBias(int areaID, float bias)`**
Sets the area elevation variation noise bias (-1 means down only, 0 means +- equally, 1 means up only.)

**`rmSetAreaElevationOctaves(int areaID, int octaves)`**
Sets the area elevation variation noise octaves.

**`rmSetAreaElevationPersistence(int areaID, float persistence)`**
Sets the area elevation variation noise persistence (best >0 and <1).

**`rmSetAreaElevationType(int areaID, int type)`**
Sets the area elevation variation type (cElevNormal, cElevFractalSum, cElevTurbulence).

**`rmSetAreaElevationVariation(int areaID, float variation)`**
Sets the area elevation variation height (amount to vary +- from area base height).

**`rmSetAreaMix(int areaID, string mixName)`**
Sets the mix for an area. Overrides terrain type if it is also set.

**`rmSetAreaObeyWorldCircleConstraint(int areaID, bool constrain)`**
Determines whether an area obeys world circle constraint.

**`rmSetAreaReveal(int areaID, int tiles)`**
Sets the area to be revealed (-1 means don't reveal, 0 means reveal, >0 means reveal plus that number of extra tiles.

**`rmSetGlobalRain(percent)`**
sets the global rain percent.

**`rmSetGlobalSnow(percent)`**
sets the global snow percent.

**`rmSetGlobalStormLength(length, timeBetweenStorms)`**
sets storm length and time between storm in seconds.

**`rmSetMapClusteringNoiseParams(float minFrequency, int octaves, float persistence)`**
sets up cluster system; standard inputs to noise generator used to determine cluster placement.

**`rmSetMapClusteringObjectParams(int minObjectCount, int maxObjectCount, float maxPosOffset)`**
sets up cluster system; min/max objects per tile (default: 0-3), and max random offset when placing (default: 0.5 tiles).

**`rmSetMapClusteringPlacementParams(float paintThreshold, float placeMinVal, float placeMaxVal, int type)`**
sets up cluster system; valid ranges are from -1.0 to 1.0 and are compared to the internal noise field for deciding where to paint terrain and place clusters. Type is cClusterLand, or cClusterWater, or cClusterShallowWater, or cClusterEverywhere.

**`rmSetObjectDefAllowOverlap(int defID, bool on)`**
Lets objects overlap within this object def.

**`rmSetObjectDefCreateHerd(int defID, bool on)`**
Creates a herd out of all units placed in this object def.

**`rmSetObjectDefForceFullRotation(int defID, bool on)`**
Forces things in this object def to get full arbitrary rotation.

**`rmSetObjectDefGarrisonSecondaryUnits(int defID, bool on)`**
Turn on the garrison secondary units flag.

**`rmSetObjectDefGarrisonStartingUnits(int defID, bool on)`**
Turn on the garrison starting units flag.

**`rmSetObjectDefHerdAngle(int defID, float angle)`**
Set a herd angle(clockwise from +z) in the object def.

**`rmSetObjectDefTradeRouteID(int defID, int tradeRouteID)`**
Set the trade route for all objects in this object definition.

**`rmSetOcean(bool reveal)`**
Sets whether or not to reveal oceans.

**`rmSetPlayerLocation (int playerID, float xFraction, float zFraction)`**
Manually sets a player's starting location.

**`rmSetPlayerResource(int playerID, string resourceName, float amount)`**
Sets a player's resource amount.

**`rmSetWorldCircleConstraint(bool constrain)`**
sets whether RM activities should be constrained to the main world circle.

## Special Commands

**`rmGetIsTreaty()`**
returns true if the game is a treaty mode.



