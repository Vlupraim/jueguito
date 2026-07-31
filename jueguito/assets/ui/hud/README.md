# Kit visual del HUD

## Estructura

- La raiz conserva los maestros RGBA sin recortar.
- `source/` conserva las fuentes con croma para poder rehacer el mate.
- `runtime/` contiene las texturas recortadas y optimizadas que consume Godot.
- `docs/design/concepts/hud/asset_iterations/` conserva todas las exploraciones, incluidas las variantes no usadas en el HUD base.

## Direccion visual

- Cartografia antigua con bronce oscuro, laton apagado y pergamino envejecido.
- La ornamentacion se concentra en la silueta; el centro de cada modulo queda limpio.
- Ningun estado depende solo del color. Foco, peligro, bloqueo y cooldown deben combinar valor, contorno, patron y simbolo.
- Las sombras se aplican desde Godot para conservar legibilidad sobre escenas claras u oscuras sin duplicar texturas.

## Uso previsto

- `portrait_frame.png`: marco del retrato provisional o avatar futuro.
- `action_slot_frame.png`: marco neutral; los estados se aplican por codigo.
- `resource_bar_frame.png`: marco comun para salud, energia y experiencia; cada relleno usa patron distinto.
- `minimap_frame_parchment.png`: variante base del minimapa.
- `minimap_frame_metal.png`: variante alternativa o posible evolucion.
- `pause_panel.png`: fondo escalable del menu de pausa.
- `menu_button.png`: fondo escalable de botones; foco y pulsacion se aplican por codigo.
- `map_menu_shell.png`: carcasa completa del mapa regional; su hueco transparente recibe el mapa dinamico del sector.
- `world_atlas_shell.png`: carcasa exclusiva del atlas, sin columna fija y con carta de ancho completo.
- `map_screen_frame.png` y `map_viewport_frame.png`: iteraciones anteriores conservadas como material de boceto; ya no se superponen en las vistas activas.

Ejecutar `scripts/tools/prepare_hud_raster_assets.py` despues de reemplazar un maestro.
