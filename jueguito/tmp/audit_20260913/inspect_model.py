import bpy
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[2]
path = root / 'assets/characters/player/models/char_6_c583a7dd/strong_man.glb'
with path.open('rb') as stream:
    magic, version, length = struct.unpack('<III', stream.read(12))
    size, kind = struct.unpack('<II', stream.read(8))
    data = json.loads(stream.read(size))
accessors = data.get('accessors', [])
primitives = [p for m in data.get('meshes', []) for p in m['primitives']]
result = {
    'blender_version': bpy.app.version_string,
    'file_mb': round(path.stat().st_size / 1048576, 2),
    'meshes': len(data.get('meshes', [])),
    'primitives': len(primitives),
    'materials': len(data.get('materials', [])),
    'vertices': sum(accessors[p['attributes']['POSITION']]['count'] for p in primitives),
    'triangles': sum(accessors[p['indices']]['count'] // 3 for p in primitives if 'indices' in p and p.get('mode', 4) == 4),
    'skin_joints': [len(s['joints']) for s in data.get('skins', [])],
    'morph_targets_per_primitive': [len(p.get('targets', [])) for p in primitives],
    'animations': [a.get('name') for a in data.get('animations', [])],
}
(Path(__file__).parent / 'model_stats.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
