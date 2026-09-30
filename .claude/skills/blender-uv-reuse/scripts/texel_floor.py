"""Validate measured final/source density on BOTH axes. Measurement and visual approval are separate."""
import math

def check(report):
    failures=[]
    def positive(x):
        return isinstance(x,(float,int)) and not isinstance(x,bool) and math.isfinite(x) and x>0
    reference=report.get('reference',{})
    floor=reference.get('floor')
    if not reference.get('evidence') or not reference.get('units') or not positive(floor):
        return ['missing measured vanilla reference, units or positive floor']
    gain=report.get('required_linear_gain',1)
    if not positive(gain):return ['invalid requested gain']
    baseline=report.get('baseline_density')
    if gain>1 and not positive(baseline):return ['missing baseline for requested gain']
    target=max(floor,baseline*gain if gain>1 else floor)
    rows=report.get('components')
    if not rows:return ['missing component measurements']
    for row in rows:
        for field in ['final_density','source_supported_density']:
            xy=row.get(field)
            if not isinstance(xy,(tuple,list)) or len(xy)!=2 or not all(positive(x) for x in xy):
                failures.append(f"{row.get('id','?')}: missing/invalid {field}")
            elif min(xy)+1e-4<target:
                failures.append(f"{row.get('id','?')}: {field} {xy} below {target}")
    return failures
