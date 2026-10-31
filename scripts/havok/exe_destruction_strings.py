import re
d = open(r'C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\AoE3DE_s.exe', 'rb').read()
def ctx(tok, n=3, w=160):
    out = []
    for m in list(re.finditer(re.escape(tok), d))[:n]:
        s = d[max(0, m.start()-w):m.end()+w]
        out.append(re.sub(rb'[^\x20-\x7e]+', b' | ', s).decode())
    return out
for tok in (b'simskeleton', b'physicsSystemBindings', b'physicsShape', b'PhysicsOnDeath', b'generic_destruction', b'destructionTech', b'disableAfterDestruction', b'physicsDeltaTime'):
    print(f'\n=== {tok.decode()} ({len(list(re.finditer(re.escape(tok), d)))}x) ===')
    for c in ctx(tok): print('  ', c[:330])
