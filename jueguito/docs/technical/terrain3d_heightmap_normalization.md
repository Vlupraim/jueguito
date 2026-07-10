# Normalizacion anti-cortes de Terrain3D

La normalizacion anti-cortes no es lo mismo que suavizar todo el terreno.

- `Suavizar cargado` promedia el heightmap completo y sirve para bajar ruido general.
- `Evitar cortes` detecta lineas duras, expande una zona de reparacion alrededor de ellas y fuerza una normalizacion estricta. Sirve para dejar el resultado parecido a una pasada manual fuerte de suavizado, sin tocar todo el sector.
- `Permitir cortes intencionales` debe quedar apagado por defecto. Enciendelo solo cuando quieras conservar acantilados o terrazas duras.

## Desde el dock

1. Carga un sector en la herramienta de terreno.
2. En `Normalizar terreno`, deja `Permitir cortes intencionales` apagado.
3. Ajusta `Corte m`; `1.5` es el punto de partida estricto.
4. Usa `Evitar cortes` para el sector cargado o `Evitar cortes seleccion` para una seleccion multiple.

Sube `Corte m` si el terreno queda demasiado blando. Baja `Corte m` si siguen apareciendo escalones o rayas duras. Activa `Permitir cortes intencionales` solo cuando quieras conservar acantilados o terrazas duras.

## Desde consola

Dry-run sobre un sector:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://scripts/tools/editor/terrain3d_heightmap_maintenance.gd -- --sector 12 9 --repair-cuts --threshold 1.5 --dry-run
```

Aplicar a un sector:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://scripts/tools/editor/terrain3d_heightmap_maintenance.gd -- --sector 12 9 --repair-cuts --threshold 1.5 --apply
```

Aplicar a todos los exports:

```powershell
& 'C:\Users\dzzav\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://scripts/tools/editor/terrain3d_heightmap_maintenance.gd -- --all-exported --repair-cuts --threshold 1.5 --apply
```

El modo `--apply` guarda un backup de cada `height.exr` tocado en `res://data/terrain3d_export_backups/`.
