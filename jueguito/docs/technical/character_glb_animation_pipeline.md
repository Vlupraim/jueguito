# Pipeline de personajes GLB con animaciones propias

Esta guia define el flujo provisional para incorporar personajes jugables sin
retargetear animaciones entre esqueletos diferentes durante la ejecucion.

## Decision actual

- Cada personaje se prepara y valida individualmente en Blender.
- Cada GLB final contiene su malla, texturas, skin, armature y animaciones.
- Un personaje utiliza las animaciones incluidas en su propio GLB.
- No se deben aplicar automaticamente los clips del Strongman a otro rig.
- Todos los cuerpos mantienen escala visual `1.0` y la misma capsula de gameplay.
- Los archivos `.blend` son fuentes editables; Godot consume los `.glb` finales.

Aunque dos esqueletos tengan los mismos nombres de huesos, sus rest poses y ejes
locales pueden ser distintos. Por eso compartir directamente un clip puede inclinar
el cuerpo, separar los pies del suelo o torcer las extremidades.

## Personaje disponible

Por ahora el unico cuerpo registrado en el selector es:

```text
body_id: strongman
model_path: res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb
animation_source_path: res://assets/characters/player/models/char_6_c583a7dd/strong_man.glb
visual_scale: 1.0
```

El Strongman contiene 25 clips y actua como personaje del mundo jugable provisional
mientras se preparan los demas cuerpos.

## Preparacion de un personaje en Blender

1. Importar el GLB con `File > Import > glTF 2.0`.
2. Guardar inmediatamente un `.blend` maestro.
3. Revisar malla, armature, skin, pesos y rest pose.
4. Incorporar y retargetear en Blender todas las animaciones necesarias para ese
   personaje.
5. Conservar cada Action mediante `Fake User` o una pista del NLA.
6. Comprobar que los clips de locomocion sean `in-place` si el movimiento lo
   controla `CharacterBody3D`.
7. Exportar con `File > Export > glTF 2.0` y habilitar animaciones, Actions y NLA
   Tracks cuando corresponda.
8. Abrir el GLB exportado de nuevo y comprobar que contiene todos los clips.

Como minimo, un cuerpo jugable debe traer:

```text
idle
walk
run
```

Para las siguientes mecanicas tambien es recomendable incorporar:

```text
jump
gather
attack
hit
death
```

Los nombres originales del proveedor pueden conservarse mientras exista un alias
canonico en el juego, por ejemplo `shared/idle`, `shared/walk` y `shared/run`.

## Incorporacion al proyecto

1. Crear una carpeta propia dentro de
   `res://assets/characters/player/models/<body_id>/`.
2. Copiar el GLB final y sus texturas necesarias.
3. Esperar a que Godot complete la importacion.
4. Confirmar que existe `Skeleton3D`, skin y `AnimationPlayer`.
5. Enumerar los clips y revisar `idle`, `walk` y `run` visualmente.
6. Agregar una entrada a `MODELS` en
   `res://scripts/ui/character_selection_3d.gd`.
7. Usar la misma ruta tanto en `model_path` como en `animation_source_path`.
8. Ejecutar las pruebas del selector y del mundo Terrain3D.

Ejemplo:

```gdscript
{
    "body_id": "nuevo_personaje",
    "name": "Nuevo personaje",
    "model_path": "res://assets/characters/player/models/nuevo_personaje/personaje.glb",
    "animation_source_path": "res://assets/characters/player/models/nuevo_personaje/personaje.glb",
    "visual_scale": 1.0,
}
```

No se debe colocar la ruta del Strongman en `animation_source_path` para un cuerpo
con otro armature.

## Agregar una animacion futura

Cuando a un personaje le falte una animacion:

1. Abrir su `.blend` maestro.
2. Importar la animacion donante.
3. Retargetearla al armature de ese personaje dentro de Blender.
4. Corregir pies, manos, root motion y duracion.
5. Guardarla como Action o pista NLA.
6. Volver a exportar el GLB completo de ese personaje.
7. Sustituir su GLB en el proyecto y revalidar sus clips.

Este trabajo se repite por personaje cuando sus rigs sean diferentes. Si en el
futuro todos los cuerpos se vinculan al mismo armature maestro, se podra volver a
una biblioteca de animaciones realmente compartida.

## T-pose y A-pose

Eliminar las animaciones de un GLB no cambia su rest pose ni lo vuelve compatible
con otro esqueleto. La T-pose o A-pose pertenece al armature y al bind pose del
skin. Un GLB sin clips puede servir como base limpia, pero antes de compartir
animaciones debe utilizar exactamente el mismo armature maestro o pasar por un
retargeting correcto.

## Control de versiones

- Mantener los GLB, texturas y fuentes Blender pesadas en Git LFS.
- No versionar respaldos `.blend1` como assets finales.
- Conservar una copia recuperable del `.blend` maestro antes de reemplazar un GLB.
- No sobrescribir el unico archivo fuente editable con una exportacion de runtime.

## Validacion

Las pruebas relevantes son:

```text
tests/scenes/character_animation_retarget_smoke.gd
tests/scenes/character_selection_3d_smoke.gd
tests/scenes/character_roster_flow_smoke.tscn
tests/scenes/player_shared_animation_smoke.tscn
```

Ademas de las pruebas automaticas, cada personaje requiere inspeccion visual. Las
pruebas pueden detectar recursos o pistas faltantes, pero no garantizan que pies,
manos, hombros y cadera se vean naturales.
