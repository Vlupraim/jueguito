# Flujo de mapas (Estilo Albion Online)

El juego utiliza una estructura de navegación y visualización espacial de tres escalas coordinadas mediante `MapDataManager`.

## 1. Minimapa del HUD (`minimap.tscn` / `minimap.gd`)

- **Persistencia**: Visible continuamente en la esquina del HUD de juego.
- **Forma y Estilo**: Marco circular metálico/vidrio con radar de posición en tiempo real.
- **Marcadores**:
  - Marcador central del jugador `▲` orientado con la cámara.
  - Marcadores de portales de sector `🌀` con tooltip al pasar el ratón.
  - Marcadores de pings tácticos (Alerta ⚠️, Ataque ⚔️, Defensa 🛡️).
- **Insignias de Zona**:
  - `T1-T8`: Nivel de Tier del sector actual.
  - Categoria de Riesgo / Hazard: Zona Azul (Segura), Zona Amarilla (PvP no letal), Zona Roja (PvP letal) y Zona Negra (Tierras Lejanas).
  - Contador de jugadores hostiles en zonas PvP (`☠ Hostiles: X`).
- **Controles**:
  - Botones `+` / `-` para cambiar el nivel de zoom táctico.
  - Botones `[N]` (Mapa de Sector) y `[M]` (Mapa Mundial).

## 2. Mapa de Sector / Cluster (`sector_map.tscn` / `sector_map.gd`)

- **Activación**: Se abre con `N`, `Tab` o haciendo clic en el Minimapa.
- **Visualización**: Renderizado en mapa de acuarela 2D generado por `local_map_texture_builder.gd`.
- **Cabecera**:
  - Nombre del Sector (ej. *"Estepa - Sector [33, 19]"*).
  - Placa de Tier (`TIER 4`), insignia de peligro y contador de hostiles.
- **Navegación e Interacción**:
  - Arrastre con clic izquierdo y zoom suave con la rueda del ratón o slider.
  - Botón *"Centrar en Jugador"* (`Espacio`).
  - **Portales de Borde**: Botones interactivos en las salidas con tooltip del sector destino y su Tier. Al hacer clic, inspecciona dicho sector.
  - **Sistema de Pings**: Doble clic coloca un ping en el sector. `Ctrl + Doble Clic` = Clic de Ataque, `Shift + Doble Clic` = Clic de Defensa.
  - **Panel de Filtros y Recursos**: Permite ocultar/mostrar capas de portales y recursos, mostrando la lista de abundancia de Madera, Mineral, Piel, Fibra y Roca.
  - Botón directo para pasar al Mapa Mundial `[M]`.

## 3. Mapa Mundial / Atlas Macro (`world_map.tscn` / `world_map.gd`)

- **Activación**: Se abre con `M` o desde el mapa de sector.
- **Matriz Macro**: Lee la cuadrícula de 67 x 38 sectores de 5 km (`map_design_sectors_5km.json`).
- **Modos de Vista**:
  - *Vista por Riesgo (PvP)*: Colorea cada celda según su nivel de peligro (Azul, Amarillo, Rojo, Negro).
  - *Vista por Bioma*: Colorea las celdas según el tipo de bioma (Bosque, Estepa, Pantano, Montaña, etc.).
- **Buscador Global**:
  - Barra de búsqueda superior para filtrar sectores por nombre, bioma o tier (ej. "T6", "Estepa", "Bosque").
- **Panel Previsualizador de Sector**:
  - Al seleccionar un nodo en la cuadrícula, muestra la tarjeta de detalles (Tier, Bioma, Riesgo y Recursos).
  - Botón *"🔍 Inspeccionar Mapa de Sector"* que carga y abre el Mapa de Sector para la celda seleccionada.

---

## Flujo Completo de Teclas y Transición

```text
HUD --[N / Tab / Clic Minimapa]--> Mapa de Sector --[M / Botón Mundo]--> Mapa Mundial
HUD -------------------------[M]------------------------------------> Mapa Mundial
Mapa Mundial --[Clic "Inspeccionar Sector"]--------------------------> Mapa de Sector
Mapa de Sector / Mapa Mundial --[Esc / Clic ✕]-----------------------> HUD
```
