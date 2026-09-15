import sys, collections, os
sys.path.insert(0, os.path.dirname(__file__))
from hkt_read import Tagfile
for f in sys.argv[1:]:
    tf = Tagfile(f)
    pd = tf.read_item(tf.deref(tf.read_item(1)[0]['namedVariants'])[0]['variant'][1])[0]
    s = tf.read_item(tf.deref(pd['systems'])[0][1])[0]
    c = collections.Counter()
    for r in tf.deref(s['rigidBodies']):
        rb = tf.read_item(r[1])[0]
        pv = {p['key']: p['value']['data'] for p in tf.deref(rb['properties'])}
        c[(pv[0x12A002], rb['motion']['type'], rb['collidable']['broadPhaseHandle']['objectQualityType'], rb['motion']['motionState']['deactivationClass'], rb['motion']['inertiaAndMassInv'][3] == 0)] += 1
    print(os.path.basename(f), '(sim, motion, quality, deact, massless):', dict(c))
