# Research behind the arrangement gates (2026-10-11)

Two read-only research briefs (set dressing, then physics) condensed; numbers marked *heuristic* are practitioner
recommendations, not sourced constants.

## Why a first layout reads "boxy"

Measured on the rejected first spec: 80 % (Consulate) and 100 % (Monastery) of non-round props sat within 5 deg of a
building axis, with 1 and 3 axis rows. Nearest-neighbour spread did not catch it (Monastery CV 0.60, random-like).
Boxiness is orientation + rows + no contact, not spacing.

## Set dressing

- Story first: props sit where people use them, "placed according to usage logic, not grid alignment" (80.lv); each
  cluster tells one small story (Smith & Worch, GDC 2010 "What Happened Here?").
- Hierarchy: hero, then secondary clusters, then filler; leave negative space (0.8-1.5 m between clusters, zone fill
  15-40 %, *heuristic*). Hero clusters 5-7 props, secondary 3, singles <= 20 % (*heuristic*).
- Anchor to architecture: walls, corners, under eaves, beside doors - never in door boxes, stairs or paths.
- Off-kilter: "objects in the real world are rarely perfectly aligned" (Pluralsight). Wall-huggers +-3-10 deg and 2-8 cm
  off the wall; directed props +-20-45 deg around their task direction; stack tops 5-25 deg and 10-20 % offset;
  no random tilt on standing props (*heuristic ranges*).
- Variety: >= 1 lean, >= 1 tipped, >= 2 stacks per building (*heuristic*).
- RTS readability: "bigger shapes, not as much little dots" (Blizzard art direction, StarCraft II). Props under 20 cm
  only on a host; judge silhouettes at the game pitch.

## Methods

- Poisson-disk (Bridson 2007) spreads evenly - too uniform alone. Thomas / Matern cluster processes (spatstat
  `rThomas`, `rMatClust`) place children around parents; here the parents are story anchors (sigma 0.3-0.6 m).
- Geometry Nodes scatter outputs instances (not linked-duplicate objects) and cannot run per-prop BVH gates: preview only.
- Chosen: seeded rejection sampling around anchors with relation templates and BVH gates (deterministic, locally
  stable - the same aims as Guerrilla's Horizon Zero Dawn placement system).

## Metrics

- Axis alignment A = share of asymmetric props with d < 5 deg, d = min(theta mod 90, 90 - theta mod 90). Gate A <= 0.35.
- Axis rows: groups of >= 3 centres sharing x or y within 0.10 m. Gate 0 (declared rows jitter 3-6 cm).
- Clark-Evans R = mean NN distance / E[d]; Donnelly (1978) edge correction for a window of area A, perimeter P:
  E[d] = 0.5 sqrt(A/n) + (0.0514 + 0.041 / sqrt(n)) P / n. Verified here by Monte Carlo (20 000 random patterns each):
  rectangles 2 x 3 m n 12, 1.3 x 0.8 m n 5, 4 x 4 m n 30, 2.2 x 3.5 m n 8 -> formula within 0.4 % of the simulated mean
  (uncorrected 0.5 sqrt(A/n) is 8-21 % low). sd(R) = 0.27 (n 5), 0.21 (n 8), 0.17 (n 12), 0.10 (n 30): advisory only.
  R < 1 clustered, ~1 random, > 1 regular; want <= 0.8, flag >= 1.1.
- NN CV: random ~0.52 (Rayleigh), grid 0; want >= 0.45 (advisory, misses rows).
- Orientation entropy over 9 bins of d (0-45 deg), normalised: >= 0.6 when >= 6 asymmetric props (advisory).
- Physicality: >= 30 % of props touch a prop or wall (gap <= 1 cm); <= 20 % isolated (nothing within 0.6 m).

## Physics (Blender rigid body, background)

- World: substeps 20 (480 Hz at 24 fps), solver iterations 30 (steadier stacks), frames run in order.
- Passive colliders: ground slab (top z = 0), LOW parts near the props (mesh; a triangle mesh has no thickness).
- Active props: one convex-hull proxy per multi-part prop (rigid bodies need mesh objects; never apply rigid bodies or
  transforms to linked duplicates that share catalog meshes). `collision_margin` 0.004 (the 0.04 default rounds 40 cm
  props). Compound proxies only where a concavity matters.
- friction 0.6 props / 0.8 ground, restitution 0, damping 0.3 linear / 0.6 angular; mass = hull volume x density.
- Blender manual: objects under ~20 cm are unstable -> place small props analytically.
- At rest: 12 consecutive frames with < 0.5 mm and < 0.05 deg per frame; reject large travel / unintended flips.
- Write back root_final = proxy_final @ proxy_initial^-1 @ root_initial; delete proxies and the world.
- Hybrid (the studio pattern: Unreal "Keep Simulation Changes", Houdini Drop LOP, Blender "Physics Dropper"): physics
  is an authoring tool and the result is frozen; upright props on flat ground rest analytically (exact, stable across
  Blender versions); lean / tipped / stack settle under gravity.

## Static stability

- Support polygon = hull of contacts; centre of mass inside with margin >= max(2 cm, 10 % of the smallest width).
- Leaning prop: ladder case, mu_req = d_com / h_contact = tan(theta) / 2 for a uniform body leaning theta from
  vertical; wood on wood 0.25-0.5 (Engineering ToolBox) -> gate mu_req <= 0.4. Cannon wheel (r 0.625) at 13 deg: 0.115.
- Stacks: upper COM inside the lower top, heavier / larger below, <= 3 levels.
- A barrel on its side on level ground is in neutral equilibrium (the brief suggested chocks on both sides; reported
  here, not gated).

## Sources

- https://www.pluralsight.com/resources/blog/software-development/dress-importance-set-dressing
- https://80.lv/articles/3d-environment-artist-on-what-makes-environments-believable/
- https://gdcvault.com/play/1012647/What-Happened-Here-Environmental
- https://www.blizzplanet.com/blog/comments/eurogamer_interviews_samwise_didier
- https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
- https://rdrr.io/cran/spatstat.random/man/rMatClust.html and https://rdrr.io/github/spatstat/spatstat.core/man/clarkevans.html
- https://www.guerrilla-games.com/read/gpu-based-procedural-placement-in-horizon-zero-dawn
- https://docs.blender.org/manual/en/latest/physics/rigid_body/properties/collisions.html
- https://docs.blender.org/api/current/bpy.types.RigidBodyObject.html and bpy.types.RigidBodyWorld.html
- https://docs.unrealengine.com/4.27/BuildingWorlds/LevelEditor/InEditorTesting/KeepSimulationChanges
- https://www.sidefx.com/docs/houdini/nodes/lop/houdinirbdprocedural.html
- https://superhivemarket.com/products/physics-dropper/docs
- https://engineeringtoolbox.com/friction-coefficients-d_778.html
- https://wikis.mit.edu/confluence/display/RELATE/The+Ladder+Problem
- Donnelly, K. (1978) "Simulations to determine the variance and edge-effect of total nearest neighbour distance",
  in Hodder (ed.), Simulation Studies in Archaeology, CUP, 91-95 (constants verified by simulation, above).
