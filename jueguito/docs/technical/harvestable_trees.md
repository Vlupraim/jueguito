# Arboles talables

## Variantes disponibles

Los GLB fuente viven en
`res://assets/environment/foliage/trees/harvestable/`. Las escenas preparadas
para gameplay estan en `res://scenes/world/resources/trees/`:

- `pine_tall_01.tscn`
- `palm_curved_01.tscn`
- `acacia_01.tscn`
- `broadleaf_01.tscn`
- `pine_dense_01.tscn`
- `willow_rooted_01.tscn`

Todas heredan de `harvestable_tree.tscn`. El script calcula los limites del GLB,
lo escala a la altura configurada y coloca su base sobre Y=0. Cada variante tiene
una capsula fisica ajustada al tronco y una caja de seleccion que cubre el arbol.

## Flujo jugable actual

1. El jugador hace clic sobre el arbol.
2. Si esta lejos, camina hasta un punto seguro frente al tronco.
3. Al entrar en rango se detiene, mira al arbol y reproduce `shared/chop`.
4. El HUD muestra una canalizacion de 7 segundos.
5. Al completar, el servidor mock entrega `Madera`, bloquea el recurso y registra
   su fecha de respawn.
6. El arbol cae, se oculta y deja un tocon provisional.
7. Luego de 540 segundos reaparece cuando existe un jugador a menos de 60 metros.

Moverse con clic derecho, cerrar el control jugable o salir del rango cancela la
canalizacion. Todavia no se exige un hacha; esa validacion se incorporara cuando
exista el sistema de equipamiento.

Este flujo describe el prototipo previo a la migracion. La direccion aprobada en
`res://docs/design/player_movement_camera_interaction.md` elimina el movimiento
por clic y la autoaproximacion. En el flujo objetivo el jugador se acerca con
`WASD`; un clic lejano solo selecciona el arbol y la tala comienza con `E` o clic
izquierdo cuando ya esta dentro del alcance. Moverse, saltar, perder el rango o
cerrar el control jugable cancela la canalizacion.

## Identidad y persistencia

Cada colocacion puede definir manualmente `resource_id`. Si queda vacio, se deriva
de la ruta de la escena y de su posicion mundial. El `ServerMock` mantiene
`resource_id -> respawn_at` durante la sesion y evita recolectar dos veces el mismo
arbol. La implementacion de servidor real debera persistir esa tabla en base de
datos.

## Terrain3D

Los pinos que ya fueron pintados con el Instancer de Terrain3D siguen siendo
MultiMesh decorativo y no se vuelven interactuables automaticamente. Para un
bosque completamente talable hay que convertir sus transforms a colocaciones de
estas escenas o a un administrador de recursos con proxies cercanos. No se deben
superponer las escenas talables sobre pinos MultiMesh, porque al talar seguiria
visible la copia decorativa.

## Pruebas

- `tests/scenes/harvestable_tree_assets_smoke.gd`
- `tests/scenes/harvestable_tree_flow_smoke.tscn`
- `tests/scenes/gameplay_hud_smoke.tscn`
- `tests/scenes/character_chop_animation_smoke.gd`
