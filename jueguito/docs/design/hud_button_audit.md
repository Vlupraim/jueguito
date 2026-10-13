# Auditoría visual de botones y efectos

Estado: primera auditoría posterior al rediseño del HUD.

## Sistema objetivo

Todos los controles deben pertenecer a una de estas familias:

| Familia | Uso | Tamaño mínimo | Tratamiento |
| --- | --- | ---: | --- |
| Acción principal | Entrar, crear, confirmar, continuar | 44 px alto | Botón de cuero completo, texto y foco visible |
| Acción secundaria | Volver, opciones, editar, restaurar | 40 px alto | Mismo marco con menor contraste |
| Icono utilitario | Cerrar, zoom, expandir, centrar | 40 × 40 px | Recurso pictográfico, sin caracteres tipográficos |
| Ranura | Habilidad, insignia, objeto, equipo | 40–68 px | Marco consistente, estado equipado/enfriamiento separado |
| Navegación | Tabs, árbol, mapa | 40 px alto | Estado seleccionado inequívoco y cursor contextual |

Cada botón interactivo debe tener `normal`, `hover`, `pressed`, `disabled` y
foco de teclado. El hover aumenta contraste y brillo sin mover la geometría; el
pressed oscurece el fondo y reduce el brillo del icono. La transición visual
objetivo es de 100–140 ms. Los iconos conservan tooltip y alternativa de teclado.

## Corregido en esta pasada

- El emblema generado de Maestrías reemplaza la estrella tipográfica del HUD y
  también identifica el botón del inventario.
- El cierre SVG compartido reemplaza `X`, `×`, `ESC X` y otros cierres
  tipográficos en inventario, Maestrías, Opciones, mapa regional y atlas mundial.
- El Árbol de Maestrías usa cursor de mano, admite arrastre y abre centrado en su
  núcleo inferior.
- Las cuatro insignias mantienen una distribución cardinal alrededor del emblema,
  con conectores discretos en lugar de una estrella literal.

## Hallazgos pendientes priorizados

### P1 — siguiente familia de recursos

- Crear iconos para ping, leyenda y restauración. Zoom, expansión, centrado y
  edición del HUD ya usan SVG compartidos.
- Unificar el cierre de diálogos nativos (`ConfirmationDialog`) cuando exista una
  carcasa de diálogo propia; hoy dependen del tema del sistema.
- Definir una placa seleccionada para tabs Sector/Mundo y para categorías de
  Opciones, evitando depender solamente del color del texto.

### P2 — respuesta y accesibilidad

- Añadir un sonido UI breve y compartido para hover, aceptar, cancelar y error.
- Revisar contraste de estados disabled y foco con filtros de daltonismo.
- Añadir indicadores de teclado/gamepad sin incrustar letras dentro del arte.
- Normalizar tooltips: verbo primero, atajo al final entre paréntesis.

### P3 — deuda estructural

- Extraer los estilos creados por código a un tema de controles compartido.
- Crear un componente único `IconButton` para evitar configurar manualmente
  icono, tamaño, tooltip y estados en cada pantalla.
- Separar arte de marco, pictograma y estado para reutilizar recursos sin generar
  una imagen completa por cada variante de hover.
