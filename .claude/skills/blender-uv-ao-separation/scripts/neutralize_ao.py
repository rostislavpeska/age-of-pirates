"""Apply a shared neutral mask before AO enters any material channel.

Values are normalized floats. AO=1 means no occlusion. The mask is one shared
atlas-space image used by every stacked instance; never a per-member override.
"""
import numpy as np

def neutralize(ao,mask):
 a=np.asarray(ao,dtype=float);m=np.asarray(mask,dtype=float)
 if a.shape!=m.shape or a.ndim!=2:raise ValueError('AO and mask must be same-size scalar images')
 if not np.isfinite(a).all() or not np.isfinite(m).all() or a.min()<0 or a.max()>1 or m.min()<0 or m.max()>1:
  raise ValueError('normalized finite AO and mask required')
 return a*(1-m)+m
