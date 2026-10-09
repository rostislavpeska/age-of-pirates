# Third-party origin of skinned-model-check

Reviewed and trialled 2026-10-09 on the DE yabusame rider (owner: "get them, try them, if you succeed, modify
them for our case and add to the repo").

| Source | Licence | Use here |
| --- | --- | --- |
| [blender-game-skills](https://github.com/majidmanzarpour/blender-game-skills), `skills/blender-image-to-3d/scripts/validate.py` and `roundtrip.py` (default branch, downloaded 2026-10-09) | MIT (below) | **Adapted** into `scripts/skin_check.py`: the skin-weight and armature checks, the clay-render report. Changed for AoE3 converter output (scale, seam doubles and vanilla tiny weights reported as INFO), added the rig binding checks and the baseline diff. Both originals ran unmodified on the rider FBX first: 0 FAIL, 4 explainable WARN. |
| [blender-rig-audit](https://claudskills.com/skills/blender-rig-audit/) (HHSOLL/freestyle; source repository no longer reachable) | none stated | **Idea only, no text or code**: the checklist "armature present, mesh bound, vertex groups present, single armature". |
| [blender-kiln](https://github.com/elithril/blender-kiln) | MIT | **Reviewed, not adopted**: its tools target glTF/web pipelines and a Blender MCP; `bind_rigid_parts.py` folds bone-parented props into a skinned glTF, while AoE3 attaches props through the animfile. |

## MIT License (blender-game-skills)

```
MIT License

Copyright (c) 2026 Majid Manzarpour

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
