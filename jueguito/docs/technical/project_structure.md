# Estructura jerarquica del proyecto

Esta guia existe para no olvidar sistemas del documento de diseno. No significa que todo deba implementarse ahora; solo reserva lugares claros para cuando el juego crezca.

## Raiz

```text
addons/       Plugins de Godot, por ejemplo Terrain3D.
assets/       Arte, audio, modelos, texturas y archivos importables.
data/         JSON, exports, datos generados, balance y muestras.
docs/         Diseno, tecnica, arte y produccion.
resources/    Resources de Godot: .tres, .res, definiciones editables.
scenes/       Escenas .tscn instanciables.
scripts/      Logica GDScript.
server/       Futuro servidor autoritativo.
shaders/      Shaders.
tests/        Pruebas.
tools/        Herramientas externas o scripts de pipeline.
```

## Personaje jugador

```text
assets/characters/player/
  models/                  Modelo .glb/.gltf/.fbx.
  rigs/                    Skeletons, rigs fuente y variantes.
  animations/
    idle/                  Quieto, respiracion, poses.
    locomotion/            Walk, run, strafe, turn, jump.
    combat/                Ataques, bloqueos, impactos, casteos.
    gathering/             Talar, minar, recolectar, pescar.
    crafting/              Usar estaciones.
    emotes/                Gestos sociales.
  materials/
  textures/
  audio/
    footsteps/             Pasos por superficie.
    voice/                 Esfuerzo, respiracion, voces.
    equipment/             Ropa, armadura, armas.
  vfx/

scenes/characters/player/  Escena jugable del personaje.
scripts/characters/player/
  movement/
  camera/
  animation/
  input/
  state/
resources/characters/player/
```

## Razas, NPCs y criaturas

```text
assets/characters/races/
assets/characters/npcs/
scenes/characters/npcs/
scripts/characters/npcs/
resources/races/

assets/creatures/dragons/
  models/
  rigs/
  animations/baby/
  animations/juvenile/
  animations/adult/
  animations/ancient/
  materials/
  textures/
  audio/
  vfx/

scenes/creatures/dragons/
scripts/creatures/dragons/
resources/dragons/
  breeds/                  Fuego, tierra, maritimo, niebla, etc.
  growth/                  Bebe, joven, adulto, antiguo.
  training/                Roles entrenados.
  upkeep/                  Costo de mantenimiento.
```

## Mundo, sectores y generacion

```text
assets/environment/
  terrain/
    textures/grass/
    textures/sand/
    textures/rock/
    textures/snow/
    textures/swamp/
    textures/arcane/
    heightmaps/
    masks/
  water/
  foliage/
  rocks/
  buildings/
  props/

scenes/world/
  generators/              Generadores de mapa/sector.
  sectors/generated/       Sectores generados.
  sectors/handmade/        Sectores editados a mano.
  terrain/
  water/

scripts/world/
  generators/
  terrain/
  surfaces/
  water/
  sectors/

data/design/
  world_map/
  sector_templates/
  biomes/
  surfaces/

data/generated/
  sectors/
  terrain/
  navigation/
  resources/
  routes/
  dungeons/
```

## Recursos destructibles y regeneracion

```text
assets/environment/props/resources/
assets/environment/rocks/ore_nodes/
assets/environment/foliage/trees/
assets/environment/foliage/plants/

scenes/world/resources/
  trees/
  rocks/
  plants/
  minerals/
  animals/

scripts/world/resources/
  nodes/                   Vida, herramienta requerida, estado destruido.
  gathering/               Accion de recolectar, canalizacion, interrupcion.
  respawn/                 Regeneracion, rareza, temporizadores.

scripts/systems/resources/
resources/resources/
  nodes/
  respawn/
data/design/resources/
data/balance/resources/
```

## Objetos interactuables

```text
assets/environment/props/interactables/

scenes/world/props/interactables/
  chests/
  doors/
  loot_bags/               Bolsa/lapida de muerte.
  crafting_stations/
  shops/
  market_boards/
  notices/

scripts/systems/interaction/
scripts/systems/loot/
scripts/systems/death_loot/
resources/items/loot_tables/
data/design/death_loot/
data/balance/death_loot/
```

## Items, inventario, equipamiento y durabilidad

```text
assets/items/
  equipment/armor/
  equipment/tools/
  weapons/melee/
  weapons/ranged/
  weapons/magic/
  resources/basic/
  resources/rare/
  resources/arcane/
  icons/

resources/items/
  materials/
  equipment/
  weapons/
  consumables/
  currencies/
  loot_tables/

scripts/systems/
  inventory/
  items/
  equipment/
  durability/

data/balance/items/
```

## Crafting

```text
assets/environment/buildings/crafting_stations/
scenes/world/props/interactables/crafting_stations/
resources/crafting/
  recipes/
  stations/
scripts/systems/crafting/
data/balance/crafting/
```

## Economia, mercado y monedas

```text
resources/economy/
  markets/
  currencies/
  taxes/

scripts/systems/economy/
  currency/
  markets/
  taxes/
  pricing/

data/design/economy/
data/balance/economy/
assets/ui/icons/economy/
scenes/ui/market/
scripts/ui/market/
```

## Rutas, comercio y transporte

```text
assets/vehicles/
  boats/
  caravans/
  carts/
  air/

scenes/world/vehicles/
  boats/
  caravans/
  carts/
  air/

scenes/world/routes/
  land/
  sea/
  air/

scripts/world/routes/
scripts/systems/routes/
  planning/                Planificar ruta.
  manifests/               Manifiestos/cargas visibles o robables.
  interception/            Emboscadas, incautacion, bloqueo.

resources/routes/
  land/
  sea/
  air/

data/design/routes/
data/design/ports/
data/balance/transport/
```

## Espionaje, informacion y sabotaje

```text
scripts/systems/espionage/
  intel/                   Informacion como objeto/dato.
  infiltration/            Permisos, acceso, confianza.
  sabotage/                Sabotajes permitidos por reglas.

resources/espionage/
  intel/
  sabotage/

data/design/espionage/
docs/design/espionage/
scripts/systems/logging/
scripts/systems/moderation/
```

## Facciones, casas, reinos y territorio

```text
assets/factions/
  banners/
  heraldry/
  territory_markers/

resources/factions/
  houses/
  kingdoms/
  permissions/

resources/politics/
  seasons/
  elections/
  rebellions/

scenes/world/territory/
  claims/
  borders/
  objectives/
  sieges/

scripts/systems/factions/
  houses/
  kingdoms/
  permissions/

scripts/systems/politics/
  seasons/
  elections/
  rebellions/

scripts/systems/territory/
  claims/
  sieges/

data/design/territories/
data/design/factions/
data/design/politics/
data/design/seasons/
data/balance/territory/
data/balance/seasons/
```

## Dungeons

```text
assets/dungeons/
  solo/
  group/
  open_world/
  seasonal/
  rooms/
  entrances/
  traps/
  bosses/
  props/

scenes/world/dungeons/
  solo/                    Dungeons solitarias.
  group/                   Dungeons grupales.
  open_world/              Dungeons no instanciadas/disputables.
  seasonal/                Eventos de temporada/reino.
  rooms/
  entrances/
  bosses/
  traps/

scripts/world/dungeons/
resources/dungeons/
  solo/
  group/
  open_world/
  seasonal/

data/design/dungeons/
data/balance/dungeons/
data/generated/dungeons/
docs/design/dungeons/
assets/audio/music/dungeons/
assets/audio/ambience/dungeons/
assets/audio/sfx/dungeons/
```

## Combate, maestrias y progresion

```text
scripts/systems/combat/
scripts/systems/skills/
  masteries/
  abilities/

resources/skills/
  masteries/
  abilities/

resources/status_effects/
assets/vfx/combat/
assets/vfx/magic/
data/balance/combat/
data/balance/masteries/
docs/design/combat/
docs/design/progression/
```

## UI

```text
assets/ui/
  icons/inventory/
  icons/skills/
  icons/economy/
  icons/map/
  icons/factions/
  fonts/
  themes/
  cursors/

scenes/ui/
  hud/
  menus/
  inventory/
  market/
  crafting/
  map/world_map/
  map/minimap/
  factions/
  politics/
  chat/
  debug/

scripts/ui/
  hud/
  inventory/
  market/
  crafting/
  map/
  factions/
  politics/
  chat/
  debug/
```

## Herramientas internas

```text
scenes/tools/editor/
  map_painter/
  sector_painter/
  object_painter/

scripts/tools/editor/
  map_painter/
  sector_painter/
  object_painter/

tools/
  importers/
  exporters/
  generators/
  balance/
  build/
  debug/
```

## Servidor autoritativo futuro

```text
server/
  src/
    auth/
    networking/
    world/
    inventory/
    economy/
    factions/
    routes/
    espionage/
    combat/
    persistence/
    admin/
  config/
  migrations/
  tests/

scripts/systems/networking/
  client/
  shared/
  server_messages/

scripts/systems/persistence/
data/save_samples/
```

## Audio y VFX

```text
assets/audio/
  music/exploration/
  music/combat/
  music/cities/
  music/dungeons/
  ambience/biomes/
  ambience/cities/
  ambience/dungeons/
  sfx/combat/
  sfx/environment/
  sfx/ui/
  sfx/crafting/
  sfx/gathering/
  sfx/economy/
  sfx/vehicles/
  sfx/dragons/
  sfx/dungeons/

assets/vfx/
  combat/
  magic/
  environment/
  water/
  crafting/
  dragons/
  ui/
```

## Pruebas

```text
tests/
  unit/
  integration/
  scenes/
  server/
  tools/

scenes/test/
  player/
  world/
  networking/
  economy/
```

## Nota sobre Git

Git no guarda carpetas vacias. Esta guia es el respaldo de la jerarquia completa. Cuando una carpeta deba quedar versionada aunque aun no tenga assets reales, se puede agregar un `.gitkeep`.
