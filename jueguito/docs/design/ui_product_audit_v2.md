# Auditoría de producto visual y recorrido UI — v2

Estado: primera pasada sistémica implementada y validada a 1280 × 720.

## Veredicto directo

La interfaz ya posee una dirección material reconocible, pero todavía no es un
sistema visual terminado. Antes de esta pasada se veía como varias maquetas
competentes ensambladas: portada, HUD, inventario, Maestrías y mapas utilizaban
escalas y grados de ornamentación diferentes. El mayor defecto no era la falta
de arte, sino la falta de reglas compartidas.

La corrección v2 reduce el ornamento por control, unifica estados y reserva las
imágenes para elementos donde aportan materialidad. El resultado se acerca a un
producto navegable, aunque sigue siendo claramente un prototipo por los textos,
estadísticas, habilidades y estados de juego aún provisionales.

## Recorrido auditado

| Tramo | Diagnóstico | Cambios aplicados | Pendiente |
| --- | --- | --- | --- |
| Portada | Panel sobredimensionado, vacío y cuatro acciones visualmente iguales | Menor panel, ritmo vertical compacto, iconos consistentes y botones construidos por tema | Nombre e identidad final del juego |
| Login | Inputs correctos, checks deformados por placas de botón y aviso de prototipo demasiado visible | Checks binarios silenciosos, acción y retorno consistentes, foco legible | Recuperación de cuenta, errores reales y política de sesión |
| Créditos | Correcto como placeholder, escaso como pantalla final | Se conservó sobrio | Créditos, licencias y enlaces reales |
| Opciones | Buena cobertura funcional; estados `Activado` eran texto fijo incluso al desmarcar | Switches sin texto falso, tabs claras, cierre vectorial y pie útil | Valores numéricos, remapeo de controles y confirmación de video |
| Roster | Composición vacía, centro sin propósito y una segunda ventana que repetía la decisión del slot | Los cuatro slots son la navegación: uno vacío abre el creador; uno ocupado revela únicamente `Iniciar aventura`; fondo low-poly propio de ruinas, sendero y lago | Enriquecer la ficha cuando estén cerrados raza, clase y origen |
| Creador | Títulos repetidos, cuerpo sobreexpuesto y controles con ornamento excesivo | Títulos diferenciados, controles sobrios, corrección del viewport 3D y escenario compartido con el roster | Sistema completo de apariencia; no invertir más arte antes de definirlo |
| HUD | El panel único impedía personalizar su jerarquía; la primera separación conservó ranuras demasiado ornamentadas y teclas sobredimensionadas | Tres módulos editables centrados al 65%; ranuras compactas de 42 px con tecla secundaria en esquina; marcos codeados simples; rango 45–160% | Iconografía real de habilidades, cooldowns, estados y prueba en combate |
| Inventario | La ventana centrada dominaba la pantalla y el viewport 3D duplicaba al personaje sin aportar una decisión | Panel lateral derecho; equipo 3×3 preparado para nueve categorías; solo las manos están activas; estadísticas plegables; mochila 5×N desplazable; sin segundo render 3D | Conectar cabeza, torso, pies, capa, mochila equipada y consumibles cuando existan sus sistemas; reemplazar estadísticas placeholder |
| Pausa | Todas las acciones competían mediante la misma placa ilustrada | Un único estilo base, iconos utilitarios y aviso de mundo activo | Diferenciar claramente pausa local y servidor multijugador |
| Maestrías | Buena estructura global, nodos todavía crípticos | Arrastre, cursor contextual, centrado y cierre inequívoco | Iconos semánticos, filtros, zoom y estados bloqueado/disponible/aprendido |
| Mapa regional | La carta 2D no comunicaba relieve y la primera maqueta parecía una baldosa flotante | Proxy 3D reducido desde altura/superficie real, costa suavizada, mar continuo, vegetación, proyección compartida para marcadores y datos regionales reales | Caminos, salidas, naufragio/POI y continuidad terrestre con vecinos |
| Atlas mundial | Fuerte identidad, pero selección y grilla parecían herramientas de autor | Carta con falsa perspectiva y relieve horneado; grilla solo en zoom regional; selección corregida sobre la proyección | LOD de nombres, rutas principales y capas cartográficas finales |
| Confirmaciones | Dependen de `ConfirmationDialog` y rompen la carcasa visual | Auditadas dentro del recorrido | Reemplazar por modal propio compartido antes de beta |

## Imágenes, código y el equivalente a CSS en Godot

### Debe programarse

- Geometría responsiva: anchors, `Container`, márgenes y zonas seguras.
- Tamaños mínimos, navegación por teclado/gamepad, foco y tooltips.
- Estados `normal`, `hover`, `pressed`, `disabled`, seleccionado y error.
- Barras, cooldowns, scroll, drag, tabs, switches y animaciones.
- Color, borde, radio, sombra y padding mediante `Theme` y `StyleBox`.
- Iconos utilitarios geométricos en SVG: cerrar, volver, zoom, expandir,
  centrar, opciones y salir.
- Todo texto, número o atajo que pueda cambiar por idioma o input activo.

`Theme` + `StyleBox` cumplen el papel más cercano a CSS. Los `Container` son el
equivalente del sistema de layout. Las escenas `.tscn` definen la estructura y
GDScript conecta comportamiento y estados.

### Debe ser imagen raster

- Fondos pintados o ilustraciones de portada.
- Atlas, pergaminos y mapas con información visual no geométrica.
- Texturas de cuero, papel, metal o desgaste cuando se vean a tamaño suficiente.
- Retratos, objetos, habilidades y emblemas con identidad propia.
- Marcos grandes cuya irregularidad sea parte de la dirección artística.

Una imagen raster no debe contener texto localizable ni estados interactivos.
Tampoco debe convertirse en el botón completo si necesita estirarse a muchos
anchos: esa fue la causa de las placas deformadas y del exceso de ornamento.

### Debe ser híbrido

- Panel grande: textura o marco artístico con centro extensible mediante
  `StyleBoxTexture`/nine-slice, contenido y padding codeados.
- Ranura: marco reutilizable como imagen; icono, cantidad, cooldown y selección
  dibujados por controles separados.
- Botón con identidad: base codeada y pictograma SVG/raster independiente.
- Barra: marco artístico opcional, relleno y valores siempre programados.

Regla práctica: si el elemento cambia de tamaño, idioma, estado o contenido,
su estructura debe estar en código. Si comunica material, mundo o identidad,
puede ser imagen.

## Sistema adoptado

- Botón base oscuro con borde de latón discreto y geometría estable.
- Hover mediante contraste y borde; nunca desplazando el control.
- Pressed mediante oscurecimiento y ajuste interno mínimo.
- Iconos monocromos de 18–21 px dentro de controles de 40–52 px.
- Una sola familia tipográfica y escala de títulos de 23–34 px.
- Cierre siempre con el mismo SVG; no letras `X`, símbolos Unicode ni arte
  generado ambiguo.
- Placas ilustradas completas retiradas de acciones genéricas.

## Qué no funcionó

- Usar la misma placa ornamental para acción principal, secundaria y check.
- Generar por IA un cierre ornamentado: a tamaño real parecía armas cruzadas.
- Colocar un emblema no aprobado en el centro de la portada: competía con el
  nombre sin que la identidad del juego estuviera cerrada.
- Repetir “Crear personaje” como título global, título de panel y botón.
- Mostrar el texto fijo `Activado` al lado de switches que podían estar apagados.
- Decir “la aventura está en pausa” en una experiencia cuyo servidor continúa.

## Prioridades restantes

### P0 — antes de considerar la UI cerrada

1. Sustituir `ConfirmationDialog` por un modal compartido del juego.
2. Validar todo el recorrido a 1280 × 720, 1920 × 1080, ultrawide y escalas
   0.8/1.0/1.25/1.5, incluyendo textos largos.
3. Revisar foco visible y navegación completa con teclado y gamepad.
4. Resolver el comportamiento real de pausa local frente al mundo multijugador.

### P1 — siguiente pasada de producto

1. Ampliar roster/creador cuando estén definidas las opciones definitivas de apariencia y origen.
2. Ajustar la mochila para que el scroll pertenezca claramente a la cuadrícula.
3. Diseñar iconos y estados semánticos del Árbol de Maestrías.
4. Probar tamaño y contraste del HUD sobre combate, bosque, costa, noche y nieve.
5. Reemplazar placeholders de estadísticas y habilidades por datos reales.
6. Añadir al mapa regional rutas, salidas y POI autorales; no llenar el proxy
   con decoración procedural que pueda confundirse con contenido jugable.
7. Hacer deterministas los recursos/peligro expuestos por `MapDataManager`
   antes de implementar filtros o comparar territorios.
8. Separar la coordenada técnica del prólogo del atlas público cuando se cierre
   el flujo tutorial → mundo persistente.

### P2 — pulido

1. Transiciones de 100–140 ms respetando “reducir movimiento”.
2. Sonidos compartidos de hover, aceptar, cancelar y error.
3. Tooltips con formato único: verbo primero, atajo al final.
4. Pruebas de contraste, daltonismo y legibilidad a distancia.

## Pipeline recomendado para nuevos recursos

1. Definir primero función, estados y tamaños reales.
2. Construir un control sin arte y validarlo en varias resoluciones.
3. Elegir SVG para pictogramas y raster para material/ilustración.
4. Separar marco, icono, texto y estado en archivos o nodos distintos.
5. Importar en Godot y capturar a tamaño real; nunca aprobar desde el PNG grande.
6. Verificar normal, hover, pressed, disabled, foco y escala antes de reutilizar.

## Auditoría del piloto cartográfico

Capturas verificadas:

- `concepts/hud/asset_iterations/implemented_map_regional_v2.png`: mapa de
  Sector con relieve 3D liviano, datos reales y marcadores proyectados.
- `concepts/hud/asset_iterations/implemented_world_atlas_full_v2.png`: atlas
  completo sin grilla técnica, para juzgar silueta, relieve y perspectiva.
- `concepts/hud/asset_iterations/implemented_world_atlas_v2.png`: zoom regional
  con grilla, selección y ficha territorial.

Veredicto: la arquitectura visual ya es válida como piloto. El mapa regional
se lee como territorio y el atlas como carta, pero ninguno debe considerarse
arte final. El mayor salto de calidad siguiente no vendrá de más marcos ni de
más shader: vendrá de rutas, nombres, hitos y jerarquía de información autoral.
