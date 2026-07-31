# Kit de cursores medievales

Set original de cursores fuente de 64 x 64 px para la interfaz y las interacciones del juego. En ejecucion se reducen a 40 x 40 px, aproximadamente un 125 % del cursor clasico de Windows.

| Archivo | Uso |
| --- | --- |
| `cursor_arrow.png` | Navegacion normal y menus |
| `cursor_wait.png` | Espera y carga |
| `cursor_pointing_hand.png` | Botones, enlaces y seleccion |
| `cursor_grab.png` | Elemento o mapa arrastrable |
| `cursor_grabbing.png` | Arrastre activo |
| `cursor_attack.png` | Ataque normal y PvP desactivado en zona segura; espada solitaria apuntando a la izquierda |
| `cursor_pvp_enabled.png` | PvP activado; espadas cruzadas |
| `cursor_forbidden.png` | Accion no permitida |
| `cursor_zoom_in.png` | Acercar |
| `cursor_zoom_out.png` | Alejar |
| `cursor_move.png` | Mover en cualquier direccion |
| `cursor_chat.png` | Chat o conversacion |
| `cursor_help.png` | Ayuda o contexto desconocido |
| `cursor_text.png` | Escritura y seleccion dentro de campos de texto |

`CursorManager` registra automaticamente los estados estandar de Godot. Para un modo contextual:

```gdscript
CursorManager.set_cursor_mode(CursorManager.ATTACK)
CursorManager.set_cursor_mode(CursorManager.PVP_DISABLED)
CursorManager.set_cursor_mode(CursorManager.PVP_ENABLED)
CursorManager.set_cursor_mode(CursorManager.ZOOM_IN)
CursorManager.reset_cursor()
```

## Produccion del arte

El atlas fue generado con ImageGen en modo integrado, usando una imagen aportada por el usuario solo como referencia conceptual. El resultado es un diseno original ajustado al HUD oscuro medieval del proyecto. Se genero sobre fondo croma plano, se extrajo a transparencia y se dividio mediante `scripts/tools/prepare_cursor_assets.py`.

Prompt final:

> Production sprite sheet for medieval fantasy game mouse cursors. Exactly twelve distinct icons in a strict 4-column by 3-row grid: classic arrow, hourglass, armored pointing finger, open armored gauntlet, closed armored gauntlet, crossed Viking swords, forbidden symbol, zoom-in magnifier, zoom-out magnifier, four-direction move arrows, speech bubble, and question-mark hook. Hand-painted game UI style matching a dark low-poly medieval MMO interface; crisp silhouettes, slightly angular shapes, dark charcoal outline, aged iron, brown leather, muted parchment, and warm antique-gold accents. Isolated icons with consistent scale and generous spacing on a perfectly flat `#00ff00` chroma-key background. No text, labels, title, watermark, logo, cast shadows, grid lines, or extra objects.

Revision de la espada solitaria:

> Create exactly one solitary Viking sword icon for the standard attack cursor and PvP-disabled safe zones, matching the existing kit. The sharp blade tip must point clearly toward the left, with the tip in the upper-left and the hilt in the lower-right. Aged iron blade, brown leather grip, antique-gold guard and pommel, dark outline, crisp hand-painted silhouette on a perfectly flat `#00ff00` chroma-key background. No second sword, crossed weapons, shield, hand, text, watermark, shadow, or frame.
