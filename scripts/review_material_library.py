"""Record the visual review of the complete source pack; never change its images."""
from pathlib import Path
import csv, json

root = Path(__file__).resolve().parents[1]
base = root / 'jueguito/assets/environment/terrain/textures/stylized'
out = root / 'art/environment/material_audit_v1'
notes = {}
def mark(ids, verdict, note):
    for i in ids: notes[i] = (verdict, note)

mark([1], 'candidato', 'Gravilla legible; bajar contraste de piedras y comprobar tamaño junto al personaje.')
mark([2,3], 'rehacer', 'Arcilla dividida en placas con bordes oscuros demasiado dibujados.')
mark([4], 'rehacer', 'Grietas enormes y repetidas; parece una superficie rota, no tierra general.')
mark([5,6], 'candidato', 'Granulado útil; quitar sombras y brillos pintados antes de usar iluminación dinámica.')
mark([7], 'rehacer', 'Azul frío y contornos pétreos; no sirve como hielo o nieve natural.')
mark([8,9], 'rehacer', 'Acantilado con sombras profundas pintadas; relieve aparente contradice la luz del juego.')
mark([10,12], 'reserva fantástica', 'Piedra violeta pulida; mantener para un lugar mágico definido, no suelo común.')
mark([11,13], 'rehacer', 'Facetas y realces claros demasiado grandes; suavizar formas y reducir contraste.')
mark([14], 'reserva fantástica', 'Tierra violeta homogénea; carece de identidad mineral y necesita contexto fantástico.')
mark([15,16], 'candidato', 'Gravilla útil pero rosa/salmón excesivo; reducir saturación y escala de marcas.')
mark([17,18], 'rehacer', 'Lajas ocres con brillos dibujados muy fuertes; aspecto de piezas de juguete.')
mark([19,20], 'reserva temática', 'Cráneos reconocibles repitiéndose en cada baldosa; reservar para decoración localizada.')
mark([21,22], 'reserva fantástica', 'Lava muy luminosa; precisa material emisivo específico, no diffuse del suelo normal.')
mark([23], 'candidato', 'La arena más aprovechable del banco; aún demasiado amarilla bajo el sol del tutorial.')
mark([24,25], 'rehacer', 'Piedras abultadas o bloques grandes; rompe la escala visual de una playa.')
mark([26], 'rehacer', 'Arcilla con grietas claras y contornos uniformes; las líneas se repiten demasiado.')
mark([27,28], 'rehacer', 'Roca gris con bordes fuertes y sombras dibujadas; iluminación plana de ilustración.')
mark([29,30], 'rehacer', 'Arcilla naranja muy saturada y grandes formas repetidas.')
mark([31,32], 'candidato', 'Suelo granular útil; ocre saturado y piedras algo grandes para cubrir toda una región.')
mark([33], 'candidato', 'Tierra roja fina legible; conservar concepto mineral con un rojo menos dominante.')
mark([34,35], 'rehacer', 'Barro fracturado en placas secas; incoherente para zonas húmedas continuas.')
mark([36,37], 'candidato', 'Grava rojiza útil para variación; piedras demasiado identificables al repetirse.')
mark([38,39], 'rehacer', 'Tono marrón aprovechable pero facetas grandes y bordes oscuros dominan.')
mark([40], 'rehacer', 'Lajas grises desproporcionadas; parecen adoquines incluso en acantilados.')
mark([41,42], 'rehacer', 'Verde oliva confunde barro con roca; falta grano fino y separación material.')
mark([43,44], 'candidato', 'Tierra moteada relativamente discreta; mejorar rugosidad y evitar repetición a distancia.')
mark([45], 'candidato', 'Suelo fino aprovechable; naranja/cobre demasiado dominante con iluminación cálida.')
mark([46], 'rehacer', 'Relieve pétreo grueso para una base de suelo; luces pintadas demasiado fuertes.')
mark([47], 'candidato', 'Arena ocre usable como variante seca; moderar amarillo y contraste.')
mark([48], 'rehacer', 'La ceniza parece grava; necesita polvo fino y menos piedras protagonistas.')
mark([49,50], 'rehacer', 'Piedras oscuras con contornos negros uniformes; aspecto de mosaico dibujado.')
mark([51,52], 'candidato', 'Tierra y pequeñas piedras legibles; saturación rojiza excesiva para superficie general.')
mark([53,54], 'rehacer', 'Bloques de barro chocolate; tamaño y volumen ilustrado no encajan con suelo húmedo.')
mark([55], 'rehacer', 'El nombre de tierra húmeda contradice las grandes placas secas agrietadas.')
mark([56], 'candidato', 'Barro con grava útil; moderar brillo pintado y escala de piedras.')
mark([57], 'rehacer', 'Bultos enormes con reflejos claros; parece piedra brillante y no barro.')
mark([58], 'reserva fantástica', 'Violeta oscuro sin identidad terrestre; reservar hasta definir bioma arcano.')
mark([59], 'candidato', 'Tierra roja granular; usable como acento después de rebajar saturación.')
mark([60,61], 'rehacer', 'Cantos negros con brillo dorado pintado; humedad debería responder a la luz real.')
mark([62,63], 'reserva fantástica', 'Magma naranja muy evidente; necesita shader y transición propia.')
mark([64,65], 'rehacer', 'Musgo sobre bloques contorneados; interior del tutorial parece roca pintada y no humus.')
mark([66,67], 'rehacer', 'Pantano representado por polígonos verdes de roca; no transmite barro o materia orgánica.')
mark([68,69], 'rehacer', 'Grava beige demasiado ordenada y facetada; repetición visible.')
mark([70], 'rehacer', 'Pasto con piedras blancas muy luminosas; escala y brillo distraen del personaje.')
mark([71], 'rehacer', 'Musgo con grandes rocas y luces pintadas; el verde funciona como relleno plano.')
mark([72], 'reserva fantástica', 'Gemas turquesa brillantes; no pueden sustituir un suelo arcano completo.')
mark([73], 'reserva temática', 'Agua dibujada dentro de una imagen estática; no es la superficie OceanWater usada en juego.')
mark([74,75,76], 'rehacer', 'Roca roja/naranja de contornos fuertes y grandes facetas; aspecto muy caricaturesco.')
mark([77,78], 'rehacer', 'Caliza blanca abultada con bordes dibujados; confunde nieve, roca y espuma.')
mark([79,80,81,82], 'rehacer', 'Lajas marrones con relieve y brillo pintados; demasiada información repetida.')
mark([83,84], 'rehacer', 'Roca negra pulida con reflejos incrustados; bajo el sol parece plástico mojado.')
mark([85,86], 'rehacer', 'La nieve se lee como piedras blancas; reemplazar por grano y acumulaciones suaves.')
mark([87,88], 'rehacer', 'Cantos húmedos con pequeños reflejos duros pintados; no siguen la dirección del sol.')
mark([89,90], 'rehacer', 'Empedrado dorado con facetas exageradas; usar desgaste y juntas menos fuertes.')
mark([91,92], 'rehacer', 'Empedrado rojo/naranja muy saturado y contornos uniformes.')
mark([93,94], 'rehacer', 'Empedrado marrón con luces pintadas; el patrón de baldosa es demasiado protagonista.')
mark([95,96], 'reserva fantástica', 'Rocas ámbar semejantes a caramelos; conservar sólo como recurso mineral especial.')
mark([97,98], 'rehacer', 'Pavimento facetado y muy amarillo; reducir contraste de juntas y crear desgaste.')
mark([99,100], 'reserva fantástica', 'Cristales naranja brillantes; deben ser acentos o geometría mineral, no base repetida.')
assert set(notes) == set(range(1,101))

vegetation_notes = [
 'Pasto suave pintado: candidato para variación lejana, no sustituye hojas 3D.',
 'Hojas verdes grandes y duras: parece alfombra decorativa.',
 'Cobertura amarilla de hojas: reservar para otoño con escala menor.',
 'Verde fluorescente: descartar como base del entorno.',
 'Flores pintadas: decoración puntual, no cobertura repetida de todo el suelo.',
 'Hojas salvia grandes: demasiado planas y de escala evidente.',
 'Verde oscuro esponjoso: posible variación de musgo, necesita fibras finas.',
 'Pasto con formas de almohadilla: demasiado caricaturesco.',
 'Cian frío en hojas: no encaja con pradera natural común.',
 'Hojas rojas: otoño o bioma definido, no pradera general.',
 'Hojarasca marrón: concepto aprovechable, falta irregularidad y relieve sutil.',
 'Manchas de pasto neón sobre arena: saturación y transición duras.',
 'Flores amarillas como manchas: escala excesiva y repetición visible.',
 'Otoño muy denso e ilustrado: sólo cobertura secundaria localizada.',
 'Hojas cian brillantes: reserva fantástica, no base terrestre.',
 'Azul-violeta: reserva fantástica con iluminación y bioma propios.',
 'Pasto activo original: hojas muy grandes, verde saturado y volúmenes pintados.',
 'Pasto apagado: candidato más coherente; aún hay formas gruesas repetidas.',
 'Pasto apagado alternativo: candidato, bajar contraste y escala de hojas.',
 'Tierra negra con hojas grandes y piedras rojas: demasiadas formas protagonistas.',
 'Variante oscura con hojas y piedras: bordes dibujados y contraste excesivo.',
 'Flores rosas pintadas: acento puntual; mejor separarlas en vegetación 3D.',
 'Hoja/roca plana: bordes fuertes confunden los materiales.',
 'Trébol verde uniforme: plano y grande; patrón de alfombra.',
 'Pasto fino con piedras: candidato útil, quitar sombras ya dibujadas.',
 'Pasto seco: buena variedad conceptual, falta grano fino y escala uniforme.',
 'Hoja oscura con flor azul: cobertura decorativa puntual, no suelo general.',
 'Humus otoñal suave: candidato como variante secundaria, evitar cobertura homogénea.',
 'Hojas verdes duras y claras: brillo pintado y patrón reconocible.',
 'Trébol amarillo grande: saturación y escala excesivas.'
]
assert len(vegetation_notes) == 30
catalog = list(csv.DictReader((base/'curated_ground/catalogo.csv').open(encoding='utf-8-sig'), delimiter=';'))
with (out/'revision_completa.csv').open('w', encoding='utf-8-sig', newline='') as file:
    writer = csv.writer(file, delimiter=';')
    writer.writerow(['biblioteca','id_fuente','archivo','decision','critica'])
    for row in catalog:
        verdict, note = notes[int(row['id'])]
        writer.writerow(['Ground',row['id'],row['archivo'],verdict,note])
    for number,note in enumerate(vegetation_notes,31):
        writer.writerow(['Vegetation',number,f'Vegetation ({number}).png','referencia; sustituida como base activa',note])
    writer.writerow(['Derivada','pasto_a','pasto variante preparada','sustituida','Deriva del mismo pasto original: cambiar color no elimina las hojas grandes dibujadas.'])
    writer.writerow(['Derivada','pasto_b','pasto variante preparada','sustituida','La copia con otro tinte conserva el patrón y el relieve pintado del original.'])

print('REVIEW_COMPLETE ground=100 vegetation=30 derived=2 source_images_unchanged=true')

environment = json.loads((out/'environment_inventory.json').read_text(encoding='utf-8'))
with (out/'revision_modelos_agua.csv').open('w',encoding='utf-8-sig',newline='') as file:
    writer = csv.writer(file,delimiter=';')
    writer.writerow(['archivo','tipo','critica','accion'])
    for item in environment:
        path = item['path']
        if '/textures/stylized/' in path: continue
        name = Path(path).name.lower()
        kind, critique, action = 'albedo', '', 'Conservar fuente; revisar sobre el modelo con sus UV.'
        if '/water/' in path:
            kind, critique, action = 'agua', 'El normal y height conservan detalle útil; espuma legible. La apariencia real depende del shader, no del baseColor turquesa.', 'Conservar OceanWater. Normal, height y máscara de espuma están conectados; los otros mapas son banco de referencia.'
            if name == 'foam003.png': critique = 'Es una previsualización esférica del proveedor, no una textura para aplicar al agua.'
        elif '/quaternius_' in path:
            critique = 'Paleta y geometría muy simplificadas; cambiar sólo la textura no elimina las facetas del modelo.'
            if 'normal' in name and 'bark' in name:
                kind, critique = 'normal', 'Corteza con grandes crestas: coherente con el albedo original, demasiado gruesa para una dirección más natural.'
            elif 'bark' in name: critique = 'Corteza con grietas largas uniformes y volumen pintado; suavizar albedo y normal juntos, preservando UV.'
            elif 'leaves' in name or 'leaf_' in name: critique = 'Hojas de paleta plana o atlas muy ilustrado; requiere rehacer también silueta/densidad para evitar copa de juguete.'
            elif 'rocks' in name: critique = 'Roca facetada con contornos y luces pintadas; no usar como sustituto del nuevo suelo.'
            elif 'grass' in name:
                critique,action = 'Bandas de color saturadas para el modelo de pasto; demasiado uniforme.', 'El pasto nuevo usa material mate oliva propio, conservando el mesh fuente.'
            elif 'flowers' in name: critique = 'Flores muy redondas y luminosas; reservar como acentos pequeños, evitando el atlas completo sobre una superficie.'
            elif 'mushrooms' in name: critique = 'Sombreros de hongos muy ilustrados: recurso secundario, revisar escala y saturación en el modelo.'
        elif 'emissive' in name or ('castles' in path and '_3.' in name):
            kind, critique = 'emisión', 'Mapa prácticamente negro: no aporta luz. Excepción árbol 05 con áreas claras: revisar transparencia/emisión sobre UV.'
            action = 'Emisión del árbol 05 desactivada mediante material externo; conserva atlas y normal. Los demás mapas negros no aportan luz.'
        elif 'metallic_roughness' in name or ('castles' in path and '_1.' in name):
            kind, critique = 'PBR empaquetado', 'Naranja es dato de canales, no color del objeto. Variación de rugosidad limitada y correlacionada con las manchas del albedo.'
            action = 'Mantener canales G rugosidad/B metal de glTF; comparar con material más mate sin editar RGB como pintura.'
        elif 'normal' in name or ('castles' in path and '_2.' in name):
            kind, critique = 'normal', 'Normal mayormente plano con detalle débil: los brillos visibles del albedo no equivalen a relieve real.'
        elif '/rocks/' in path:
            critique = 'Roca gris con musgo y líneas blancas de brillo ya dibujadas; dos pares son duplicados renombrados. Se verá pulida incluso con material mate.'
        elif '/foliage/' in path:
            critique = 'Atlas de hojas con manchas grandes y colores muy saturados en árboles 02/04; árbol 05 tiene fondo blanco problemático. Árboles 01/03/06 más discretos pero planos.'
        elif '/castles/' in path:
            critique = 'Atlas fragmentado con piedra/musgo; fortaleza 01 tiene verde muy saturado. Mantener UV, no sustituir por una textura cuadrada de suelo.'
        else:
            critique = 'Madera/tela apagadas con manchas y sombras ya pintadas. Buen color general, detalle confuso: requiere revisión del atlas a distancia de interacción.'
        writer.writerow([path,kind,critique,action])
print('REVIEW_EXTRA_COMPLETE model_water_maps=108')
