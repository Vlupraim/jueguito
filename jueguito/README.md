# Jueguito - Prototipo de mapa MMO

Prototipo Godot para construir un MMO territorial por capas: primero mapa macro, luego sectores locales de 5 km x 5 km, despues edicion Terrain3D y finalmente gameplay.
El proyecto usa `Boceto.png` como silueta continental base y lo convierte en datos editables: superficie, bioma, sectores y exports de terreno.

La estructura de carpetas futura esta documentada en `res://docs/technical/project_structure.md`.

## Contexto para colaboradores

Este proyecto esta en fase de herramientas, no de juego final. Lo importante ahora es que el mapa sea navegable, entendible y editable.

Idea central:

- Mundo continental con dos medialunas laterales y una region central mas peligrosa.
- El mapa macro sirve para decidir continentes, costas, puertos, rutas, zonas politicas y sectores.
- Cada sector jugable mide `5 km x 5 km`.
- Terrain3D se usa como espacio de edicion manual posterior: el generador entrega una base, no el arte final.
- Los biomas existen como capa de diseno, pero todavia no son reglas definitivas de gameplay.
- Por defecto, la herramienta Terrain3D puede generar solo desde superficies: tierra, costa, agua y agua profunda. Esto evita que un bioma provisional de montana/desierto/pantano afecte demasiado temprano la forma del terreno.

Archivos clave:

- `res://assets/boceto.png`: imagen base del mapa.
- `res://data/map_design_surface_mask.png`: mascara pintada de superficie.
- `res://data/map_design_biomes.json`: capa macro de biomas.
- `res://data/map_design_sectors_5km.json`: sectores exportados desde el pintor, con superficie dominante y bioma por sector.
- `res://data/terrain3d_sector_overrides.json`: correcciones manuales por sector para regenerar Terrain3D sin tocar el mapa base.
- `res://data/terrain3d_exports/sector_X_Y/`: exports Terrain3D por sector.
- `res://addons/jueguito_terrain_tools/`: plugin propio del dock `Mapa Sectores MMO`.
- `res://scripts/tools/editor/terrain3d_sector_exporter.gd`: exporter que crea `height.exr` y metadata.

## Como abrir

1. Abre Godot 4.
2. Importa o abre `project.godot` desde esta carpeta.
3. Presiona `F5` para ejecutar la escena principal de capas: `res://scenes/map_layer_painter.tscn`.

La escena 3D plana sigue disponible en `res://scenes/map_flat_world_3d.tscn`.
La escena de generacion local por sector sigue disponible en `res://scenes/sector_world_generator.tscn`.
La escena 3D sigue disponible en `res://scenes/map_walk_3d.tscn`.
La escena 2D anterior sigue disponible en `res://scenes/map_prototype.tscn`.

## Generador local por sector

La escena `res://scenes/sector_world_generator.tscn` lee `res://data/map_design_sectors_5km.json` y `res://data/map_design_surface_mask.png`.
Con esos datos genera una zona local de `5 km x 5 km` con altura simple, agua segun la mascara, color por bioma/superficie y marcadores placeholder de recursos.
El generador agrega playa automaticamente en bordes cercanos al agua y suaviza alturas cerca de costas/bordes para evitar cortes rectos tipo pared.
Tambien genera colliders iniciales: tierra/costa como `StaticBody3D`, agua como `Area3D` detectable y un bloqueo separado para impedir que personajes entren al agua mas alla de la franja de vadeo definida.
La escena instancia `res://scenes/characters/player/player.tscn` como personaje placeholder para probar caminata y colisiones.
Mientras el terreno sea procedural de prototipo, el jugador usa movimiento guiado por el generador: toma X/Z del input y el generador devuelve la altura caminable. Los colliders fisicos quedan como infraestructura futura, pero no sostienen solos esta prueba.

Este no es el generador final: es el puente entre el mapa macro pintado y los futuros mapas locales recorribles.

- `N` / `P`: cambiar entre sectores jugables.
- `1` a `7`: saltar al siguiente sector del bioma elegido.
- `0`: saltar al siguiente sector sin bioma.
- `T` / `C` / `O` / `F`: saltar al siguiente sector con tierra, costa, agua o agua profunda.
- `WASD` o flechas: mover personaje en modo jugador.
- `Shift`: correr.
- Rueda del mouse: acercar/alejar camara del personaje.
- `V`: alternar entre camara de jugador y camara libre debug.
- En camara libre: `WASD` o flechas recorren, `Q` / `E` bajan o suben, `Shift` / `Ctrl` cambian velocidad.
- En camara libre: boton derecho + mover mouse mira alrededor, rueda del mouse cambia altura.
- `R`: reset de jugador o camara segun el modo actual.
- `G`: mostrar/ocultar grilla local de 5 km.
- Panel `Editor de sector 3D`: minimapa local del sector 5 km x 5 km.
- En el minimapa 3D, hover muestra coordenada local y superficie.
- Click en el minimapa mueve la vista activa: jugador si estas en modo jugador, camara si estas en modo camara libre.
- Click derecho o doble click en el minimapa fuerza camara libre y la coloca sobre ese punto.
- Boton `Export Terrain3D` o `Ctrl+E`: exporta el sector actual a `res://data/terrain3d_exports/sector_X_Y/`.
- La exportacion crea `height.exr`, `height_preview.png`, `surface_reference.png` y `metadata.json`.
- `height.exr` es la base para importar en Terrain3D; `metadata.json` guarda escala horizontal, resolucion y rango de altura.
- Resolucion actual de export prototipo: `513 x 513`, suficiente para probar edicion sin congelar demasiado el editor.

Smoke test del generador local:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tests/scenes/sector_world_generator_smoke.gd
```

Debe imprimir una posicion `SMOKE_PLAYER_POSITION` con `Y` positiva.

Smoke test de exportacion Terrain3D:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tests/scenes/sector_world_generator_export_smoke.gd
```

Debe crear una carpeta de sector dentro de `res://data/terrain3d_exports/`.

## Terrain3D

Terrain3D ya esta instalado en `res://addons/terrain_3d/` y se usa para editar sectors exportados como heightmaps.
El plugin propio `Jueguito Terrain Tools` no reemplaza a Terrain3D: agrega una capa de navegacion MMO encima para elegir, generar y cargar sectores del mapa global.
Terrain3D soporta pintura de texturas, colores, roughness/wetness, agujeros y foliage instancing. En este proyecto todavia estamos usando principalmente `height.exr`; la pintura de materiales sera la siguiente capa de lectura visual.

## Texturas de terreno

La idea correcta no es que cada bioma sea una sola textura. Un sector puede ser templado, pero tener pasto en planicies, roca en laderas fuertes, arena en playas y nieve en cumbres. Por eso conviene separar:

- Superficie macro: tierra, costa, agua, agua profunda.
- Bioma macro: templado, desierto, nieve, montana, pantano, etc.
- Material visual Terrain3D: pasto, arena, roca, nieve, barro, tierra humeda, etc.

Convencion inicial recomendada para slots Terrain3D:

- `0`: tierra seca / desierto.
- `1`: arena / costa / fondo bajo.
- `2`: pasto / pradera.
- `3`: tierra humeda / selva o pasto oscuro.
- `4`: roca / acantilado.
- `5`: roca secundaria / material raro provisional.
- `6`: nieve.
- `7`: barro / pantano.

Esta convencion debe mantenerse estable porque Terrain3D guarda IDs de textura en sus mapas internos. Cambiar el orden despues puede hacer que un sector pintado como pasto aparezca como roca.

Para agregar texturas:

1. Guarda los archivos en `res://assets/environment/terrain/textures/`, idealmente separados por carpeta (`grass`, `rock`, `sand`, `snow`, `swamp`, etc.).
2. Selecciona el nodo `Importer` dentro de `res://scenes/tools/editor/terrain3d_sector_workspace.tscn`.
3. En el panel inferior de Terrain3D, abre `Textures`.
4. Usa el boton `+` o arrastra una textura al slot. Terrain3D acepta `Texture2D` y recursos `Terrain3DTextureAsset`.
5. Para una textura completa, crea o usa un `Terrain3DTextureAsset` con albedo, normal y parametros de roughness/escala.
6. Para probar sin descargar nada, se puede mirar `res://demo/data/assets.tres`, que trae una textura de roca y una de pasto de ejemplo.

Para pintar manualmente:

1. Selecciona el nodo `Importer`.
2. Elige una textura en el panel `Textures`.
3. Usa la herramienta `Paint Texture` para pintar directo o `Spray Texture` para mezclar.
4. Usa el filtro `Slope` de Terrain3D para limitar la pintura por pendiente: pasto en pendientes suaves, roca en pendientes fuertes.
5. Ajusta `Size`, `Strength` y `Roughness` para que el pincel no sea demasiado agresivo.

Regla visual recomendada:

- Planicies templadas: pasto.
- Costa: arena sobre la franja de costa; agua visual aparte.
- Laderas abruptas: roca, aunque el bioma sea templado.
- Cumbres altas: nieve si el bioma o altura lo justifica.
- Pantano: barro/tierra humeda en zonas bajas.
- Desierto: arena/tierra seca, con roca en cortes fuertes.

El agua no deberia resolverse como textura Terrain3D principal. El exportador hunde o aplana el fondo donde hay agua, pero el agua final deberia ser un plano, mesh o sistema aparte con shader, colision y reglas de navegacion. Asi podemos impedir que el jugador entre mas de 5-10 m sin convertir todo el mar en terreno caminable.

Automatizacion actual:

- El exportador genera `control.exr` y `control_preview.png` junto a `height.exr`.
- `control.exr` es la primera pasada de texturas para Terrain3D.
- La libreria compartida de texturas vive en `res://assets/environment/terrain/jueguito_terrain_assets.tres`.
- El material compartido vive en `res://assets/environment/terrain/jueguito_terrain_material.tres`.
- Tierra plana -> pasto o tierra seca/humeda segun bioma.
- Costa y fondo bajo de agua -> arena.
- Pendiente fuerte -> roca como overlay.
- Altura alta + bioma frio/montana -> nieve como overlay.
- Agua -> fondo arenoso; el agua visual sigue separada.

Orden fijo de texturas Terrain3D:

- `0`: tierra seca / desierto.
- `1`: arena / costa / fondo bajo.
- `2`: pasto / pradera.
- `3`: tierra humeda / selva o pasto oscuro.
- `4`: roca / acantilado.
- `5`: roca secundaria / material raro provisional.
- `6`: nieve.
- `7`: barro / pantano.

Este orden debe mantenerse porque los `control.exr` guardan indices, no nombres. Si falta una textura en ese indice, Terrain3D puede mostrar negro aunque el terreno o la pintura sigan guardados.

El recurso compartido que fija esta lista vive en `res://assets/environment/terrain/jueguito_terrain_assets.tres`. Si agregas, cambias o reordenas texturas desde Terrain3D, usa `Guardar sector` en el dock para persistir tambien esa libreria; `Ctrl+S` solo guarda la escena abierta y puede dejar cambios de Terrain3D sin escribir.

El dock `Mapa Sectores MMO` carga `control.exr` automaticamente si existe. Si un sector fue exportado antes de esta automatizacion y no tiene `control.exr`, usa `Generar + cargar` para un sector puntual o `Regenerar seleccion` para rehacer varios sectores.

Importante: si un sector ya tiene export o ediciones guardadas, el dock intenta cargar esas ediciones para no pisarlas. Usar `Generar + cargar` o `Regenerar seleccion` pide confirmacion antes de crear una base fresca.

Por ahora la prioridad sigue siendo semi-manual: el exportador entrega una primera textura base para no pintar todo a mano, y despues se pule en Terrain3D con pincel.

Instalar addons en Godot:

- Desde AssetLib: descarga el addon, luego activa en `Proyecto > Ajustes del proyecto > Plugins`.
- Manual: copia la carpeta del addon a `res://addons/nombre_del_addon/`, reinicia Godot si hace falta y activalo en `Plugins`.
- Las texturas no son addons obligatorios. Normalmente son assets: imagenes PBR/tiling que se guardan dentro de `res://assets/environment/terrain/textures/` y se asignan a Terrain3D.

## Workspace Terrain3D

Para editar sectores con orientacion, usa `res://scenes/tools/editor/terrain3d_sector_workspace.tscn` en vez del importer crudo del plugin.

La escena contiene:

- `Importer`: el nodo Terrain3D donde se cargan `height.exr`, control/color y se guardan datos.
- `SectorGuide`: una guia 3D de sectores alrededor del actual, con labels `[x, y]`, norte/sur/este/oeste y posiciones de importacion.

El proyecto activa el plugin propio `Jueguito Terrain Tools`, que agrega un dock llamado `Mapa Sectores MMO`.
Ese dock muestra el mapa 2D global, marca en verde los sectores que tienen export Terrain3D, permite cargar sectores exportados y puede generar/importar el sector seleccionado sin abrir el generador runtime.

Funciones actuales del dock:

- Overlay de superficies: tierra, costa, agua y agua profunda.
- Overlay opcional de biomas para revisar rapidamente que tiene cada sector.
- Panel de inspeccion del sector seleccionado: superficie dominante, bioma, estado de export, rango de altura y modo de export usado.
- Toggle `Usar biomas`: apagado genera terreno solo desde superficies; encendido permite que el bioma afecte altura/color de referencia.
- Selectores `Bioma` y `Terreno`: permiten guardar una correccion manual para el sector o seleccion multiple antes de regenerar.
- `Aplicar correccion`: guarda la correccion elegida en `res://data/terrain3d_sector_overrides.json`.
- `Limpiar correccion`: quita la correccion del sector o seleccion multiple y vuelve al mapa base.
- `Pin`: evita minimizar accidentalmente el panel mientras se trabaja.
- El ancho del dock se ajusta arrastrando su borde en Godot; el separador bajo el mapa permite repartir la altura entre el mapa y las opciones.
- Zoom con rueda o botones `Zoom - / 100% / Zoom +`.
- Boton medio o derecho: arrastrar el mapa. El paneo se detiene en los bordes para que el mapa no pueda perderse fuera de la vista.
- Click normal: selecciona sector y limpia seleccion multiple.
- `Ctrl + click`: suma o quita un sector de la seleccion multiple.
- Arrastrar con click izquierdo: seleccion rectangular de sectores.
- `Ctrl + arrastrar`: suma sectores a una seleccion existente.
- `Generar + cargar`: exporta el sector seleccionado y lo carga al centro de Terrain3D.
- `Generar faltantes`: exporta solo los sectores seleccionados que aun no estan verdes/exportados; si detecta sectores ya generados, pregunta antes y los omite.
- `Regenerar seleccion`: reexporta todos los sectores seleccionados, incluso si ya estaban verdes/exportados; siempre pide confirmacion.
- `Guardar sector`: guarda el sector cargado en `res://data/terrain3d_edits/sector_X_Y/` y tambien persiste la libreria/material compartido de Terrain3D.
- `Abrir pintor`: vuelve al editor de capas para corregir superficie/bioma antes de exportar.

Nota de guardado: `Ctrl+S` de Godot guarda la escena abierta. Para persistir escultura/pintura de Terrain3D usa `Guardar sector`; el dock tambien intenta guardar el sector activo al cerrarse.

Flujo recomendado:

1. Abre `res://scenes/tools/editor/terrain3d_sector_workspace.tscn`.
2. Selecciona el nodo `Importer`.
3. Usa el dock `Mapa Sectores MMO`.
4. Elige un cuadro en el mapa.
5. Revisa el panel `Sector`: superficie, bioma y export.
6. Si el sector esta mal clasificado, elige un `Bioma` o `Terreno` en los selectores y usa `Aplicar correccion`.
7. Decide si quieres generar `solo superficies` o `superficies + biomas`.
8. Si ya esta verde, usa `Cargar sector`; si no esta verde o quieres regenerarlo, usa `Generar + cargar`.
9. Para preparar varios sectores, arrastra con click izquierdo sobre el mapa, aplica una correccion si hace falta y usa `Generar faltantes`.
10. Usa `Regenerar seleccion` solo cuando quieras rehacer conscientemente sectores ya exportados.
11. Usa la guia 3D para saber en que sector estas y hacia donde queda cada vecino.

El boton `Abrir generador para exportar sector` queda como alternativa para revisar el sector en la escena jugable antes de exportarlo manualmente.

Nota de costas: el exportador suaviza agua y costa para evitar pozos o paredes duras en Terrain3D. El agua queda como fondo bajo cercano a costa; mas adelante el plano/material de agua se manejara como capa visual y de gameplay aparte.
Nota de biomas: el bioma de montana se calibro usando `[9, 12]` como referencia jugable. Los exports antiguos con picos de 300-400 m fueron reexportados hacia un techo cercano a 100-105 m.
Nota de correcciones: una correccion de `Terreno` fuerza el sector completo como tierra, costa/arena, agua o agua profunda al regenerar. Una correccion de `Bioma` cambia la lectura del bioma para ese sector; solo afecta la altura si `Usar biomas` esta encendido. Estas correcciones no modifican `map_design_sectors_5km.json` ni la mascara pintada, son una capa reversible para iterar rapido en Terrain3D.

Sectores candidatos para pruebas de spawn/tutorial:

- `[14, 5]`, `[15, 5]`, `[14, 15]`, `[15, 15]`: sectores de prueba generados para comparar lectura.
- `[14, 6]` y `[14, 16]`: candidatos mencionados para posible spawn/tutorial futuro.
- Estos sectores no quedan decididos como spawn final; son puntos de referencia para prototipar ritmo, escala y primeras rutas.

Convencion de importacion para vecinos:

- Sector actual: `Import Position = 0, 0`.
- Vecino este: `5000, 0`.
- Vecino oeste: `-5000, 0`.
- Vecino sur: `0, 5000`.
- Vecino norte: `0, -5000`.

## Terreno plano 3D

Esta escena lee `res://data/map_design_surface_mask.png` y lo convierte en una planicie gigante con colores de diseno. No usa texturas finales todavia.

- `WASD` o flechas: recorrer.
- `Q` / `E`: bajar o subir.
- `Shift` / `Ctrl`: moverse rapido o lento.
- Boton derecho + mover mouse: mirar alrededor.
- Rueda del mouse: cambiar altura.
- `R`: reset de camara.
- `G`: mostrar/ocultar grilla de 10 km.

## Pintor de biomas

El editor ahora tiene un panel lateral de herramientas. Puedes cambiar modo, seleccion de capa, vistas y guardado con botones, o seguir usando atajos de teclado.
Tambien tiene un minimapa arriba a la derecha para trabajar como editor de terreno: al pasar el mouse muestra region, sector de 5 km y celda de detalle; click centra la camara y doble click o click derecho acerca al sector de 5 km para pintar fino.

La grilla de `10 km x 10 km` representa macro-regiones. La grilla de `5 km x 5 km` representa sectores jugables/base para mapas locales.

`Tab` alterna entre tres herramientas:

- Biomas por recuadro: decisiones macro por celda de 10 km x 10 km.
- Balde tierra/agua: relleno fino usando las lineas del boceto como barrera.
- Lineas / cierres: repasar o borrar barreras tecnicas cuando una costa no cierra bien.

### Modo biomas

- `1`: templado.
- `2`: desierto.
- `3`: selva / humedo.
- `4`: nieve / polar.
- `5`: montana.
- `6`: pantano.
- `7`: arcano / raro.
- Clic izquierdo: pintar celda.
- `Shift` + clic izquierdo o clic derecho: borrar celda.

### Modo balde tierra/agua

- `1`: tierra.
- `2`: agua.
- `3`: costa.
- `4`: agua profunda.
- Clic izquierdo mantenido: rellenar regiones por celdas de detalle.
- Clic derecho mantenido: borrar regiones por celdas de detalle.
- Botones `10 km`, `5 km`, `2 km`, `1 km`: cambian la celda de detalle usada por el balde.

El balde no rellena el mapa completo: queda limitado a la celda de detalle elegida. Para costa conviene usar 2 km o 1 km. Las lineas del boceto se convierten en una capa tecnica reforzada para que funcionen como barrera.

### Modo lineas / cierres

- Clic izquierdo: dibujar barrera tecnica.
- Clic derecho o `Shift` + clic izquierdo: borrar barrera tecnica.

Este modo sirve para corregir fugas del balde cuando una costa del boceto no cierra bien.

### Controles comunes

- Boton medio: arrastrar camara.
- Rueda del mouse: zoom.
- `WASD` o flechas: mover camara.
- `Shift` / `Ctrl`: moverse rapido o lento con teclado.
- `G`: mostrar/ocultar grilla.
- `B`: mostrar/ocultar boceto base.
- `M`: mostrar/ocultar mascara tierra/agua.
- `C`: mostrar/ocultar celdas de bioma.
- `L`: mostrar/ocultar lineas reforzadas usadas como barrera del balde.
- `X`: mostrar/ocultar sectores de 5 km.
- `Ctrl+S`: guardar capa.
- `Ctrl+L`: cargar capa.

La capa se guarda en `res://data/map_design_biomes.json`. Cada celda pintada conserva su coordenada de grilla y el bioma elegido.
La mascara tierra/agua se guarda en `res://data/map_design_surface_mask.png`.
Las lineas corregidas se guardan en `res://data/map_design_barriers.png`.
El boton `Export sectores` genera `res://data/map_design_sectors_5km.json`, con bioma y superficie dominante por sector de 5 km.

## Escena 3D

- `WASD` o flechas: recorrer el mapa.
- `Q` / `E`: bajar o subir.
- `Shift` / `Ctrl`: acelerar o moverse lento.
- Boton derecho + mover mouse: mirar alrededor.
- Rueda del mouse: cambiar altura.
- `R`: reset de camara.
- `G`: mostrar/ocultar grilla de escala.

Esta escena usa el boceto como una maqueta plana gigante. No es terreno final todavia: sirve para sentir tamano, distancias, lectura de rutas y posibles puntos de entrada.

Escala provisional: el boceto completo esta escalado x10 respecto al primer prototipo. Cada recuadro de la grilla representa 10 km x 10 km, es decir 100 km2. Con esta escala, el boceto completo mide aproximadamente 334 km x 188 km.

## Escena 2D

- `WASD` o flechas: mover camara.
- Rueda del mouse: zoom.
- Boton derecho o medio: arrastrar camara.
- `R`: reset de camara.
- `O`: mostrar/ocultar capas experimentales de rutas, zonas y puertos.
- `G`: mostrar/ocultar grilla.

Las capas experimentales estan apagadas por defecto porque no son decisiones de diseno aprobadas; solo son ayudas temporales para probar ideas encima del boceto.
La escala de grilla coincide con la escena 3D: cada recuadro representa 10 km x 10 km.

## Intencion

Este prototipo no intenta resolver combate, economia ni arte final. Solo busca responder si el mapa dibujado se siente grande, legible y util para rutas, puertos, archipielagos, zonas de riesgo y futura planificacion de manifiestos.
