---
name: aoe3de-homecity-backdrop
description: "Author, slice, test, and deploy Age of Empires III DE Home City backdrops, in-game map skyboxes, and cinematic photo-vistas. Covers cylindrical arc geometry, 3D ground cutoff calculus, zero-delta seam slicing, spatial slot ordering, programmatic silhouette anti-aliasing, lighting sets/material variants, DXT1 DDT conversion, and automated continuity tests."
---

# AoE3 DE Backdrop & Skybox Creation Pipeline

Use this skill when authoring, modifying, testing, or deploying panoramic backdrop cylinders, in-game map perimeter skyboxes, cinematic trigger camera vistas, and lighting variants for Age of Empires III Definitive Edition.

---

## 1. Skybox Architecture: Home City vs Map / Cinematic Photoshots

AoE3 DE employs skyboxes and backdrops in two distinct technical configurations:

| Feature | Home City Backdrop Cylinder | Map Perimeter & Cinematic Skybox |
| :--- | :--- | :--- |
| **Geometry** | Cylindrical mesh arc ($\sim 110^\circ - 120^\circ$) behind city. **Open arc (not $360^\circ$)**. | Full $360^\circ$ cylinder, hemisphere skydome, or panoramic card. |
| **Panel Division** | Segmented into **4 discrete material panels** (`matA`, `matB`, `matC`, `matD`). | Single continuous texture or segmented tiles. |
| **Ground Cutoff** | **Fixed 3D ground mesh cutoff**: bottom $\sim 22.3\%$ is submerged below terrain. | Variable: matched to map water plane elevation ($z=0$) or terrain rim. |
| **Wrap Seam ($D \mid A$)** | **Discontinuous**. Panel D right edge must NOT connect to Panel A left edge. | **Continuous**. If the camera can rotate $360^\circ$, wrap seam delta must be $\approx 0.00$. |
| **Aspect Ratio** | Strict **$4:1$ width-to-height ratio** ($W = 4 \times H_{crop}$). | Typically $2:1$ equirectangular or $4:1$ panoramic strip. |
| **Engine Material** | `sky_basic` material definition with multiple `<parameters variant="...">` slots. | `sky_basic` or terrain sky shader, switched via `rmSetLightingSet` or trigger cameras. |

---

## 2. Geometry & The 3D Ground Cutoff Calculus

### A. The Home City Ground Cutoff
Across European, Asian, and Native Home Cities, the backdrop cylinder rests on an armature that partially submerges the bottom into the 3D ground:
- **Submerged Fraction**: Bottom **$22.3\%$** of the cylinder height is beneath `*_groundShape`.
- **4:1 Crop Measurement**: For a crop of height $H_{crop}$ (e.g., $344$ px in a $1376 \times 344$ strip, or $1376$ px in a $5504 \times 1376$ strip):
  $$y_{cutoff} \approx 0.777 \times H_{crop}$$
  *(e.g., $y \approx 267$ px from top in 344h, or $y \approx 1069$ px from top in 1376h).*
- **Rule**:
  1. All architecture, village compounds, courtyards, bridges, and winding rivers must sit **strictly above** $y_{cutoff}$ ($y_{local} \le 0.75 \times H_{crop}$).
  2. The bottom $20\% - 25\%$ must be open green meadow, foothills, or riverbank buffer.
  3. **Zero Foreground Obstructions**: No close-up edge framing trees or foreground boulders.

### B. Map Perimeter & Cinematic Trigger Cam Backdrops
- When using a backdrop cylinder for in-game scenario cutscenes or map perimeters (`rmSetLightingSet` / trigger cameras):
  - Calibrate the horizon line to the map camera pitch (typically $40^\circ - 55^\circ$ isometric tilt).
  - If the map camera pans full circle, ensure the master panorama was painted as a seamless $360^\circ$ wrap.

### C. The Home City Camera Contract & Regression Guard
In `data/homecity<civ>.xml`, each civilization specifies its primary viewport camera (`<camera>` and `<widescreencamera>`):
- **Wars of Liberty (WoL) Korean Camera**: Korea strictly uses `aztec\aztec_homecity_cathedral_camera.cam` (the established WoL cathedral camera pitch overlooking the valley).
- **Rule**: Never replace a civilization's dedicated camera angle with vanilla China (`china\china_homecity_camera.cam`) or Japan! Changing the camera angle alters the visible horizon pitch and misaligns the 3D ground cutoff.
- **Enforcement**: The automated regression gate in `test_backdrop_seam_continuity.py` (`test_korean_homecity_camera_contract`) asserts this contract and fails any change away from the WoL camera.

---

## 3. Composition & Image Generation Formula

1. **Aspect Ratio**: 16:9 panoramic master (e.g. $1376 \times 768$ base, upscaled via Topaz to $5504 \times 1376$).
2. **Top 45%–55% (Vast Open Sky)**:
   - Expansive morning dawn, sunset, or misty haze gradient with delicate cirrus clouds.
   - Ample vertical breathing room allows flexible crop height adjustments ($y_0$) to balance mountain height against camera pitch.
3. **Upper-Mid 15%–20% (Distant Horizon Silhouette)**:
   - Mountain spires or ridges sitting low along the horizon ($\le 50\%$ frame height from bottom).
4. **Lower-Mid 15%–20% (Civilization Settlement & River)**:
   - River inlet/gorge curving from left to center.
   - Traditional civ architecture (e.g., Joseon Hanok compounds with dark Giwa curved tile roofs and low stone courtyards) scaled to panoramic distance ($\sim 30\%$ smaller than hero scale).
5. **Lower 25%–30% (Ground Buffer)**:
   - Open green meadow and riverbank buffer.

---

## 4. The Spatial Slot Ordering Contract (Preventing Seam Glitches)

In Blender and AoE3 engine `.material` definitions, the material slots along the cylinder arc **must strictly advance from Screen-Left to Screen-Right**:
- **Slot 0**: Screen Left $\to$ `matA` ($U: 0.000 \dots 0.257403$)
- **Slot 1**: Mid-Left $\to$ `matB` ($U: 0.257403 \dots 0.500000$)
- **Slot 2**: Mid-Right $\to$ `matC` ($U: 0.500000 \dots 0.742597$)
- **Slot 3**: Screen Right $\to$ `matD` ($U: 0.742597 \dots 1.000000$)

> [!CAUTION]
> If Slot 0 is assigned `matD` and Slot 1 is assigned `matA`, the rightmost edge meets the leftmost edge. On an open arc backdrop, this produces a jarring, broken vertical seam in the viewport!

### Zero-Delta Seam Slicing:
Standard non-inclusive slicing (`crop[:, x0:x1]`) leaves a 1-pixel gap in source coordinates, creating a visible seam delta when upscaled. Always use **inclusive boundary column sharing**:
```python
seams = [0.000000, 0.257403, 0.500000, 0.742597, 1.000000]
seam_cols = [int(round(s * (W - 1))) for s in seams]

# Inclusive slicing: adjacent panels share the boundary column
panel_A = master[:, seam_cols[0] : seam_cols[1] + 1] # Shares seam_cols[1]
panel_B = master[:, seam_cols[1] : seam_cols[2] + 1] # Shares seam_cols[2]
panel_C = master[:, seam_cols[2] : seam_cols[3] + 1] # Shares seam_cols[3]
panel_D = master[:, seam_cols[3] : seam_cols[4] + 1]
```

---

## 5. Programmatic Mountain Silhouette Anti-Aliasing & Softening

AI upscaling models (Topaz, Real-ESRGAN, Magnific) often leave distant mountain silhouettes overly sharp, dark-outlined, or pixelated compared to vanilla AoE3 matte paintings (which use soft watercolor / atmospheric washes).

### Programmatic Filter Recipe:
To soften the mountain silhouettes without blurring sharp village architecture:
```python
import cv2, numpy as np

# 1. Bilateral filter on mountain zone (removes pixelation, preserves painterly mass)
bilateral = cv2.bilateralFilter(img, d=9, sigmaColor=50, sigmaSpace=9)

# 2. Detect high-contrast silhouette edges against sky in mountain zone only
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
edges = cv2.Canny(gray, 30, 80)
edges[int(H * 0.55):, :] = 0  # Preserve sharp village!
edges[:int(H * 0.13), :] = 0  # Preserve sky

edge_mask = cv2.dilate(edges, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
edge_weight = (cv2.GaussianBlur(edge_mask.astype(np.float32), (0, 0), sigmaX=3.0) / 255.0)[:, :, np.newaxis]
edge_blurred = cv2.GaussianBlur(img, (0, 0), sigmaX=3.5, sigmaY=3.5)

# 3. Vertical blending ramp: mountain zone only
y_ramp = np.zeros((H, 1, 1), dtype=np.float32)
# ramp up from sky, full on peaks, ramp down above village
...
smoothed_mtn = bilateral.astype(np.float32) * (1.0 - edge_weight) + edge_blurred.astype(np.float32) * edge_weight
soft_full = img.astype(np.float32) * (1.0 - y_ramp) + smoothed_mtn * y_ramp
final_master = cv2.addWeighted(img, 0.20, soft_full, 0.80, 0)
```

---

## 6. Lighting Sets & Material Variants Architecture

AoE3 DE dynamically swaps Home City and map skybox textures across lighting conditions using submaterial variant blocks in `.material`:

```xml
<material>
  <submaterial name="mata">
    <materialdef name="sky_basic" />
    <parameters>
      <!-- Variant 0 (Default): Morning / Day -->
      <texture name="Texture" override="homecity\korean\korean_background\textures\korean_bg_matA_basecolor" />
    </parameters>
    <parameters variant="1">
      <!-- Variant 1: Night -->
      <texture name="Texture" override="homecity\korean\korean_background\textures\variationid1\korean_bg_night_matA_basecolor" />
    </parameters>
    <parameters variant="2">
      <!-- Variant 2: Winter / Snow Sunset -->
      <texture name="Texture" override="homecity\korean\korean_background\textures\variationid2\korean_bg_snow_matA_basecolor" />
    </parameters>
    <parameters variant="3">
      <!-- Variant 3: Misty Morning / Indigo Blue Mountain Fog -->
      <texture name="Texture" override="homecity\korean\korean_background\textures\variationid3\korean_bg_misty_matA_basecolor" />
    </parameters>
  </submaterial>
  <!-- Repeat for matb, matc, matd -->
</material>
```

### Game Lighting Control:
- **Home City UI**: Activated in `data/homecity<civ>.xml` via `<prop>` entries (e.g. `<prop active="1">Korean_LightDay</prop>`, `<prop>Korean_LightMisty</prop>`).
- **Map Scripting**: Set via `rmSetLightingSet("<LightingSetName>")` in `.xs` map scripts.
- **Twin Rebuild**: Any XML edit in `data/` must have its `.xml.xmb` twin rebuilt via `xmbc.py build data/<file>.xml`.

---

## 7. DDT Texture Generation & Deployment

1. **Resolution**: Each panel is resized to $2048 \times 2048$.
2. **Compression**: DXT1 with full mipmaps via `scripts/havok/ddt_dxt1.py`:
   ```bash
   python scripts/havok/ddt_dxt1.py --drop-alpha --size 2048 temp_panel.png target_mat.ddt
   ```
3. **Byte Size Gate**: Exact size for a valid 2048x2048 DXT1 DDT is **`2,796,328 bytes`**.
4. **Deploy Paths**:
   - Base: `art/homecity/<civ>/<civ>_background/textures/<civ>_bg_mat[A-D]_basecolor.ddt`
   - Variants: `art/homecity/<civ>/<civ>_background/textures/variationid[1-3]/<civ>_bg_[variant]_mat[A-D]_basecolor.ddt`

---

## 8. Automated Verification Suite

Run before every commit:
```bash
python -m pytest scripts/tools/tests/test_backdrop_seam_continuity.py -v
```

The test asserts:
1. `test_game_mod_ddt_assets`: All 4 `.ddt` files exist in mod with exact 2,796,328 byte size.
2. `test_texture_seam_pixel_continuity`: Internal seams ($A|B, B|C, C|D$) have sub-pixel continuous values (mean delta $< 5.0$), while negative test confirms wrap seam ($D|A$) is discontinuous.
3. `test_blender_backdrop_spatial_slot_ordering`: Blender material slots monotonically advance Left-to-Right in screen coordinates ($X_0 < X_1 < X_2 < X_3$) and correspond to `matA`, `matB`, `matC`, `matD`.
4. `test_blender_mesh_seam_coincidence_and_uvs`: Adjacent cylinder panels share $\ge 3$ coincident boundary vertices with $U \approx 1.0 \to U \approx 0.0$ UV continuity.
