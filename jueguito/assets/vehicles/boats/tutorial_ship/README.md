# Barco inicial del tutorial

Los GLB originales importados desde Meshy viven en `models/`. Para colocar los
barcos en Godot se deben usar las escenas preparadas, no arrastrar los GLB
directamente:

- `res://scenes/world/vehicles/boats/destroyed_ship.tscn`
- `res://scenes/world/vehicles/boats/ship.tscn`

Las escenas ya aplican la escala aproximada de nueve metros, corrigen la
orientacion del modelo y agregan una colision simple de casco. El origen vertical
creado en Meshy se conserva: el naufragio queda cerca del suelo y el barco sano
mantiene parte del casco bajo su origen para usarlo como linea de flotacion.

## Colocacion del naufragio

1. Abrir `res://scenes/tools/editor/terrain3d_sector_workspace.tscn`.
2. Cargar el sector tutorial `(27, 30)` desde el dock `Mapa Sectores MMO`.
3. Arrastrar `destroyed_ship.tscn` desde FileSystem hasta la escena.
4. Mover el nodo raiz `DestroyedShip`; no modificar la escala del hijo `Model`.
5. Ajustar `Position Y` hasta apoyar el casco en la arena.
6. Girar principalmente `Rotation Y` para orientar la proa y usar un poco de
   `Rotation X/Z` si debe verse encallado.
7. Copiar `Transform > Position` y `Rotation Degrees` para registrar esa
   colocacion en el contenido permanente del sector.

Guardar solamente el workspace no incorpora el objeto a la escena jugable. La
transformacion elegida debe copiarse a la escena de contenido del sector antes
de probar el juego.
