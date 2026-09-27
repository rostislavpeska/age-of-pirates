"""Read-only visibility sampling; source polygons remain unchanged."""
import math
import numpy as np

def camera_directions(elevations, azimuth_count, phase=0):
    return np.array([(math.cos(e)*math.cos(a),math.cos(e)*math.sin(a),math.sin(e))
                     for e in np.radians(elevations)
                     for a in np.arange(azimuth_count)*2*math.pi/azimuth_count+phase])


def triangle_samples(triangles, edge_fraction=.02, dense=False):
    weights=[(1/3,1/3,1/3)]
    q=edge_fraction
    weights += [(1-2*q,q,q),(q,1-2*q,q),(q,q,1-2*q),
                (.5-q,.5-q,2*q),(.5-q,2*q,.5-q),(2*q,.5-q,.5-q)]
    if dense:
        for i in range(1,7):
            for j in range(1,8-i):weights.append((i/8,j/8,1-(i+j)/8))
    return np.concatenate([np.asarray(weights)@t for t in triangles])
