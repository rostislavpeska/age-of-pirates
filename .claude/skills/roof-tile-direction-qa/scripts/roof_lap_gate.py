"""Check supplied HIGH relief samples; this does not extract geometry or accept a bake."""
import math


def assess(distances, relief, downhill, minimum_dominance=3.0):
    if len(distances)!=len(relief) or len(relief)<5:
        raise ValueError('Supply at least five paired samples')
    if len(downhill)!=3 or not all(math.isfinite(x) for x in list(distances)+list(relief)+list(downhill)):
        raise ValueError('Finite samples and a 3D physical direction are required')
    length=math.sqrt(sum(x*x for x in downhill))
    if length<=1e-12 or downhill[2]/length>=-1e-4:
        raise ValueError('Declared downhill frame must descend on the sampled slope')
    if any(b<=a for a,b in zip(distances,distances[1:])):
        raise ValueError('Sample distance must increase downhill')
    slopes=[(b-a)/(d-c) for a,b,c,d in zip(relief,relief[1:],distances,distances[1:])]
    rise=max(0.,max(slopes));drop=max(0.,-min(slopes));dominance=drop/max(rise,1e-12)
    return {'status':'PASS' if drop>1e-6 and dominance>=minimum_dominance else 'FAIL',
            'steepest_downhill_drop':drop,'steepest_downhill_rise':rise,'drop_to_rise':dominance,
            'minimum_dominance':minimum_dominance,'scope':'HIGH relief only; low-map and engine checks separate'}
