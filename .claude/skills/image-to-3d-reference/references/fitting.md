# Fitting a generated figure to a skeleton, and using it

Evidence: one armoured rider fitted to its target rider skeleton (2026-10-11, journal `2026-10-11-claude-opus-01`,
`2026-10-11-claude-opus-fit-01` to `-05`). The method is generic; the numbers are that case.

## Fit on landmarks, never on the bounding box

- **must** fit with one uniform scale and a translation, chosen by eye on landmarks on metric orthographic overlays
  (front and side): chin, neck base, shoulder line, hips, knees, ankles, with the soles on the ground.
- **must not** scale the bounding box to the rig height: headgear, a plume or a raised weapon sticks out. The rider's
  bounding-box fit gave scale 2.0135, the landmark fit 2.31 (12.8 % larger): the head would have sat a head too low.
- With the soles fixed, the chin decides the scale (on the rider 1 % of scale moved the chin 1.8 cm). A weighted
  least squares over the landmarks (weights 1/sigma^2, small sigma for visible landmarks, large for hidden joints)
  is a good cross-check: 2.318 against the chosen 2.31.
- Record the residuals per landmark: the rider's were chin +0.5 cm, neck -0.8, shoulder -4.6, ankle +0.7. A large
  residual at a hidden or inferred joint usually reflects the design's proportions, not a fit error.
- Automatic landmark finders fail on generated figures: a helmet's neck guard read as the neck (scale off about
  10 %), hands hidden in sleeves or bracers read as skin. Pick by eye.

Make the overlay metric: render the generated model and the target body (or skeleton) with the same orthographic
camera and scale (`scripts/render_ortho.py` gives the mapping for the generated model; render the body with the
same height, centre and ortho scale), then compare outlines and landmark heights in pixels / px_per_m.

## What a generated figure gives, and what it does not (fit stage)

| Usable (within 0.5-1 cm on the rider) | Not usable |
| --- | --- |
| chin, neck base, ankle heights | shoulder joint: arms fused to the coat and shoulder flaps, inferred +-2 cm (-4.6 cm against the rig) |
| headgear dimensions (brim, bowl, finial) | hips and knees: hidden under the coat, inferred +-5 cm |
| hem heights all round, front and back splits of a coat, skirt flare | arm segment lengths: did not match the rig (0.36 / 0.23 against 0.304 each) |
| torso width and depth at the chest, boots, colours | the head's fore-aft position (5 cm forward of the head bone) |

Later stages of the same remodel (journal `2026-10-11-claude-opus-body-01`, `-helmet-02`, `2026-10-11-claude-opus-03`):

- **Body:** outside-in horizontal ray profiles of the fitted mesh (24 angles, 1-2 cm height steps) drove the torso,
  belt, collar, guard and every skirt-panel ring; the final low-poly sits median 0.1-0.3 cm, p90 under 1 cm from the
  generated surface there. Rays that hit fused sleeves (6 of 24 angles at the torso sides) or passed through a skirt
  split were replaced by interpolation and by the coat edge.
- **Helmet:** bowl, brim, finial, plume top and flap top within 0.7 cm (the plume path came out 2.6 cm longer);
  placement came from the rig head (the generated head sits 5 cm forward) and the flap length from the clip motion
  (full-length flaps entered the torso in 19 of 73 attack keys).
- **Drape:** a coat copied from a standing figure lies like a board over a flexed thigh when seated; the seated look
  comes from pose tests, not from the reference.

**must not** copy the generated proportions onto the rig: once the head matched, the shoulders sat low and the torso
long. The rig's proportions win; the generated model supplies volumes, hems, panel layout and colours.

## Mesh traits

- **Internal surfaces.** The rider had trouser legs inside the coat, a skull with ears inside the helmet, a neck
  inside the collar. Orthographic section renders (Workbench, camera clip start on the cut plane, e.g. y = 0 or
  x = 0.10) expose them and give hidden landmarks: neck base, armpit, crotch, and the panel layout of split skirts.
- **No clean loops.** Do not chain mesh sections into loops: the importer splits vertices at UV seams (17,722 islands
  after a decimation) and even welded the surface stays non-manifold, so a slice breaks into 150-300 pieces.
  Measure with point-cloud windows along the section, or on flat-albedo orthographic renders classified by colour
  (0.5 mm per pixel).

## Using it

- **must** keep the generated high-poly unposed, as the design and bake reference, parented to an empty that carries
  the landmark scale.
- **must not** deform it into the bind pose with weights transferred from a body: coat and armour skirts beside the
  hanging hands take arm weights and flare like wings when the arms go to the bind angle.
- Model the low-poly in the reference's pose over it, skin it with controlled weights, then take the LOW-poly to the
  bind pose (rest = a copy of the rig's pose). With the image route the reference already stands in the bind pose,
  so this step falls away. The organic modeling skill's gates (G1 silhouette approval, G2 pose test) apply
  unchanged; the generated model is only the reference.
- A generated figure without the target pose is still a reference for volumes; with the target pose (image route) it
  also serves as a direct overlay for the blockout.

Time on the rider: about 40 min of background fitting and measuring; it replaced guessing sizes from four renders.
