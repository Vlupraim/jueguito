# Assets estilizados de terreno y vegetacion

## Carpetas activas

- Texturas que usa Terrain3D ahora: `res://assets/environment/terrain/textures/stylized/terrain_slots/`
- Biblioteca completa Kalponic ground: `res://assets/environment/terrain/textures/stylized/kalponic_ground/`
- Biblioteca completa Kalponic vegetation: `res://assets/environment/terrain/textures/stylized/kalponic_vegetation/`
- Modelos Quaternius para pasto, arboles, rocas y props: `res://assets/environment/vegetation/quaternius_stylized_nature/`
- Respaldo de texturas realistas antiguas: `res://_incoming_assets/_legacy_realistic_terrain_textures/`

`_incoming_assets` tiene `.gdignore`, asi que sirve como bodega y no como carpeta activa de trabajo.

## Slots de textura del terreno

Los IDs se mantienen compatibles con el generador:

- `0` - `00_TierraSeca`
- `1` - `01_Arena`
- `2` - `02_Pasto`
- `3` - `03_TierraHumeda`
- `4` - `04_Roca`
- `5` - `05_Arcano`
- `6` - `06_Nieve`
- `7` - `07_Pantano`

Para cambiar una textura base, reemplaza el PNG correspondiente en `terrain_slots` o cambia la entrada en `res://scripts/tools/editor/setup_terrain3d_resources.gd` y ejecuta:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://scripts/tools/editor/setup_terrain3d_resources.gd
```

## Mesh assets ya configurados

`res://assets/environment/terrain/jueguito_terrain_assets.tres` incluye estos modelos listos para pintar con el Instancer de Terrain3D:

- `00_PastoCorto` - `Grass_Common_Short.gltf`
- `01_PastoAlto` - `Grass_Wispy_Tall.gltf`
- `02_Arbusto` - `Bush_Common.gltf`
- `03_ArbolComun` - `CommonTree_1.gltf`
- `04_ArbolComunAlto` - `CommonTree_3.gltf`
- `05_Pino` - `Pine_1.gltf`
- `06_RocaMediana` - `Rock_Medium_1.gltf`
- `07_Hongo` - `Mushroom_Common.gltf`

## Como pintar arboles, pasto y props

1. Abre una escena con tu nodo `Terrain3D` y selecciona el terreno.
2. En el dock de Terrain3D, entra a la lista de `Meshes`.
3. Elige `00_PastoCorto`, `03_ArbolComun`, `05_Pino`, etc.
4. Activa la herramienta `Instance Meshes` / Instancer.
5. Pinta sobre el terreno con click. Usa `Ctrl + click` para remover.
6. Ajusta tamano de brocha, fuerza/densidad, escala aleatoria y rotacion desde el panel de Terrain3D.

Para pasto usa densidad alta y brochas medianas. Para arboles usa densidad baja, escala aleatoria y brochazos cortos. Para rocas y hongos conviene pintar por manchas pequenas.

## Que modelo elegir

- Pasto: `Grass_Common_Short`, `Grass_Common_Tall`, `Grass_Wispy_Short`, `Grass_Wispy_Tall`.
- Arboles verdes: `CommonTree_1` a `CommonTree_5`.
- Pinos: `Pine_1` a `Pine_5`.
- Arboles raros o secos: `TwistedTree_*`, `DeadTree_*`.
- Arbustos y plantas: `Bush_Common`, `Bush_Common_Flowers`, `Plant_1`, `Plant_7`, `Fern_1`.
- Detalles chicos: `Flower_*`, `Mushroom_*`, `Clover_*`.
- Rocas y caminos: `Rock_Medium_*`, `Pebble_*`, `RockPath_*`.

## Reglas practicas

- Usa el Instancer de Terrain3D para cantidades grandes. Evita poner cientos de `MeshInstance3D` sueltos.
- Si algo flota o se hunde, abre el mesh asset en el inspector y ajusta `height_offset`.
- Si el mapa se ve demasiado cargado, baja `density` o pinta con una brocha mas pequena.
- Para un arbol importante cerca de una casa o entrada, puedes arrastrar el `.gltf` directo a la escena y colocarlo a mano.
- Si quieres sumar otro modelo al listado rapido, agregalo en `MESH_ASSETS` dentro de `setup_terrain3d_resources.gd` y vuelve a ejecutar el script.
