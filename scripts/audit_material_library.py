"""Read-only asset inspection. Writes thumbnails/reports, never edits source textures."""
from pathlib import Path
import csv, hashlib, json, math, re
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
project = root / 'jueguito'
output = root / 'art/environment/material_audit_v1'
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
base = project / 'assets/environment/terrain/textures/stylized'
catalog = list(csv.DictReader((base/'curated_ground/catalogo.csv').open(encoding='utf-8-sig'), delimiter=';'))
stats = []
for path in sorted(base.rglob('*.png')):
    im = Image.open(path)
    stats.append({'path': path.relative_to(project).as_posix(), 'size': im.size,
                  'mode': im.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(output/'inventory.json').write_text(json.dumps(stats, indent=2), encoding='utf-8')

def sheet(items, filename, title, columns=5, page_size=25):
    for index in range(0, len(items), page_size):
        page = items[index:index+page_size]
        result = Image.new('RGB', (columns*210, 55+math.ceil(len(page)/columns)*235), '#19212a')
        draw = ImageDraw.Draw(result)
        draw.text((12, 16), title, font=font, fill='#eee3cc')
        for n, (path,label) in enumerate(page):
            x, y = n%columns*210+9, 55+n//columns*235
            im = Image.open(path).convert('RGB')
            im.thumbnail((192,192))
            result.paste(im, (x,y))
            draw.text((x,y+195), label[:25], font=font, fill='#eee3cc')
        result.save(output/f'{filename}_{index//page_size+1}.png')

sheet([(base/'curated_ground'/r['categoria']/r['archivo'], f"{r['id']:>3} {r['archivo'].rsplit('_',1)[0]}") for r in catalog], 'ground_library', 'Biblioteca completa: IDs del catalogo, originales intactos')
vegetation = sorted((base/'kalponic_vegetation').glob('*.png'), key=lambda p:int(re.search(r'\((\d+)\)',p.name)[1]))
sheet([(p,p.stem) for p in vegetation], 'vegetation_library', 'Biblioteca de vegetacion: texturas fuente')
slots = sorted((base/'terrain_slots').glob('*.png'))
sheet([(p,p.stem) for p in slots], 'original_slots', 'Texturas originales principales y nieve')
print(f'Audited {len(stats)} files, {len({s["sha256"] for s in stats})} distinct images, {len(catalog)} ground designs, {len(vegetation)} vegetation designs.')

# Extend the review to every loose texture in the environment, including PBR
# maps and model UV atlases. Reports are diagnostic thumbnails, never assets.
extra = sorted(p for p in (project/'assets/environment').rglob('*') if p.suffix.lower() in ['.png','.jpg','.jpeg','.webp'] and base not in p.parents and 'natural_v1' not in p.parts)
environment_stats = list(stats)
for path in extra:
    im = Image.open(path)
    environment_stats.append({'path':path.relative_to(project).as_posix(), 'size':im.size, 'mode':im.mode,
                              'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(output/'environment_inventory.json').write_text(json.dumps(environment_stats, indent=2), encoding='utf-8')
sheet([(p,p.name) for p in extra], 'extra_environment', 'Modelos, vegetacion 3D y agua: todos los mapas fuente')

new = sorted((project/'assets/environment/terrain/textures/natural_v1').glob('*.png'))
new = [p for p in new if 'normal_roughness' not in p.name]
tiles = Image.new('RGB',(5*210,55+math.ceil(len(new)/5)*235),'#19212a')
draw = ImageDraw.Draw(tiles)
draw.text((12,16),'Prueba 2x2 de repeticion: materiales nuevos',font=font,fill='#eee3cc')
for index,path in enumerate(new):
    im = Image.open(path).convert('RGB').resize((96,96))
    x,y = index%5*210+9,55+index//5*235
    for dx,dy in [(0,0),(96,0),(0,96),(96,96)]: tiles.paste(im,(x+dx,y+dy))
    draw.text((x,y+195),path.stem,font=font,fill='#eee3cc')
tiles.save(output/'new_materials_tiling.png')
print(f'Extended audit: {len(environment_stats)} original environment files, {len(extra)} model/water maps, {len(new)} new diffuse textures.')
