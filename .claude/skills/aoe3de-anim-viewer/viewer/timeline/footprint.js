// Footprint dots (M4): where each FootstepLeft/Right tag's footprintbone is at the tag's time. A second Rig with the
// page's options is posed at the tag's first main time; the bone is looked up by the engine's name rule (exact, then
// the alias) in the models of the tag's side. Pure (no DOM): node --test checks it against the Python composition
// (tests/js/m4).
//
// Rule for a bone the model lacks (the vanilla horses' `HS Bone Hoof ...` names exist only as <definebone> lines; a
// <definebone> does not create a GR2 bone, aoe3de-model-attachments): the dot sits at the model origin. That is what
// the engine does for an attach to such a bone (verified on the Korean stable horses); that footprints follow the same
// rule is an ASSUMPTION, labelled per dot (status 'origin-assumed').
import { Rig } from '../lib/rig.js';

// dots for the footstep tags of a timeline (model.buildTimeline) under rig options {anim, variant, logic, sync, method}
export function footprintDots(bundle, rigOpts, timeline) {
  const tags = timeline.tags || [];
  const steps = tags.filter((t) => t.footstep);
  if (!steps.length) return [];
  const rig = new Rig(bundle, rigOpts);
  const out = [];
  for (const tag of steps) {
    const t = Math.min(Math.max(tag.time, 0), timeline.D);
    rig.pose(t);
    const side = rig.instances.filter((x) => x.role === tag.role && x.animfile === tag.animfile);
    const rec = { tag: tags.indexOf(tag), type: tag.type, role: tag.role, animfile: tag.animfile, fraction: tag.fraction, time: t,
      reached: tag.reached.length > 0, bone: tag.footprintbone, model: side[0] ? side[0].model.id : null, index: -1,
      match: null, status: 'no-footprintbone', position: null };
    if (!side.length) { rec.status = 'side-missing'; out.push(rec); continue; }
    if (!tag.footprintbone) { out.push(rec); continue; }   // no bone named: no dot (nothing to place)
    let hit = null;
    for (const inst of side) {
      const i = inst.model.boneIndex(tag.footprintbone);
      if (i >= 0) { hit = { inst, i }; break; }
    }
    if (hit) {
      const w = hit.inst.worlds;
      rec.model = hit.inst.model.id;
      rec.index = hit.i;
      rec.boneName = hit.inst.model.names[hit.i];
      rec.position = [w[hit.i * 16 + 12], w[hit.i * 16 + 13], w[hit.i * 16 + 14]];
      rec.status = 'bone';
    } else {
      const p = side[0].placement;                        // the model origin in the world (placement translation)
      rec.position = [p[12], p[13], p[14]];
      rec.status = 'origin-assumed';
    }
    out.push(rec);
  }
  return out;
}

export const FOOTPRINT_NOTES = {
  bone: 'the footprintbone\'s world position at the tag time (viewer pose)',
  'origin-assumed': 'the footprintbone is not in the model (a <definebone> only): drawn at the model origin, the rule ' +
    'verified for attaches, ASSUMED for footprints',
  'no-footprintbone': 'the tag names no footprintbone: no dot',
  'side-missing': 'the tag\'s side has no model in this logic state',
};
