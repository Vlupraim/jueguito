# Direccion visual del HUD

Estado: direccion visual v2 implementada.

## Principio general

El HUD debe sentirse como un conjunto de instrumentos fisicos del mundo: cartas usadas, cuero oscuro, laton envejecido y tinta deslavada. La interfaz persistente debe ser ligera. Los mapas regional y mundial son modos de concentracion a pantalla completa, no ventanas flotantes.

## Vista de juego

- Centro inferior: cuatro habilidades y Vida forman un módulo a la izquierda;
  cuatro accesos y Maná forman otro a la derecha. Entre ambos, un tercer módulo
  usa un medallón circular grande como núcleo y monta `Q/E/R/F` sobre su borde,
  en distribución cardinal y sin una estrella literal.
- La composición recomendada usa el antiguo `120%` como nuevo `100%` en los tres módulos, alineados
  al borde inferior y agrupados alrededor del núcleo. `Restaurar` recupera
  exactamente este tamaño y posición; el jugador puede ajustar cada módulo
  entre `35%` y `160%` respecto de la nueva base.
- Las ranuras de habilidad usan una base compacta de 42 px antes del escalado.
  La tecla es metadata visual pequeña en la esquina inferior derecha; el centro
  queda reservado para el icono, cooldown y estados futuros. Nunca se presenta
  la tecla grande como contenido principal de la habilidad.
- Los marcos de ranura se construyen con `StyleBox` de un píxel y no reutilizan
  la placa ilustrada gruesa del prototipo. Esto conserva proporción y legibilidad
  al reducir el módulo.
- El centro del núcleo abre el Árbol de Maestrías. Las ranuras insignia quedan preparadas, pero no simulan habilidades que todavía no existen.
- El oro y la plata no aparecen en el HUD persistente. La economia se presentara dentro de interfaces contextuales cuando tenga una funcion jugable clara.
- Superior derecha: unico minimapa local inclinado, con borde de pergamino desgastado, nombre de zona y tres controles de borde: acercar, alejar y expandir.
- Centro de la pantalla: libre salvo informacion contextual temporal.
- El minimapa usa la textura y posicion reales del sector; no replica datos ni crea una segunda fuente cartografica.
- `Tab` y `M` permanecen como atajos aprendidos en el tutorial, no como etiquetas permanentes del minimapa.

### Edicion del HUD

- Los módulos persistentes visibles (Vida, Núcleo, Maná, estamina y minimapa)
  comparten el mismo espacio de edición. Se pueden superponer libremente; solo
  se limita su posición al viewport. Un clic en una parte visible trae ese
  módulo al frente y permite arrastrarlo. Se guardan posición, tamaño y orden.
- El tamaño físico que antes se mostraba como 120% pasa a mostrarse como 100%.
  El default de los tres módulos de combate aumenta desde el antiguo 65%.
  Los tamaños personalizados existentes conservan su dimensión física al migrar.
- Las alas Vida/Habilidades, Núcleo insignia y Maná/Accesos son tres módulos
  independientes: el jugador decide su posición y escala. `Restaurar` recupera
  la composición simétrica recomendada al nuevo `100%` (antiguo `120%`).
- La escala se configura por modulo, ademas de una escala global de interfaz.
- Las posiciones se guardan como ancla normalizada mas offset, no como pixeles absolutos, para sobrevivir a cambios de resolucion.
- El modo de edicion muestra limites, alineacion y boton de restaurar valores recomendados.
- El minimapa conserva personalizacion de inclinacion y color del puntero.

## Inventario

- Panel lateral anclado a la derecha, de aproximadamente un tercio del viewport.
  No bloquea el centro ni oculta innecesariamente el personaje que ya existe en
  el mundo.
- El inventario no crea un segundo viewport 3D. La lectura del equipo se resuelve
  con iconos 2D; esto reduce coste de render, complejidad y duplicación visual.
- Los iconos de objetos usan recursos PNG independientes del modelo jugable,
  normalizados a un lienzo transparente de 256 px, centrados por peso visual y
  con margen uniforme. Los modelos GLB quedan reservados exclusivamente para el
  mundo 3D.
- Cabecera con nombre del personaje, acceso a Maestrías, título y cierre.
- El equipamiento usa una matriz estable de tres por tres inspirada en la
  claridad estructural de Albion, no en su tratamiento gráfico:

  ```text
  Mochila equipada | Cabeza | Capa
  Mano principal   | Torso  | Mano secundaria
  Consumible       | Pies   | Alimento
  ```

- Mano principal y secundaria son funcionales hoy. Las otras siete ranuras
  permanecen desactivadas, con icono y tooltip de sistema futuro; no simulan
  mecánicas inexistentes. Guantes, joyería u otra categoría futura pueden
  agregarse como una fila adicional sin ensanchar el panel.
- Estadísticas es un acordeón cerrado por defecto. Al abrirlo, conserva el
  tamaño exterior del panel y reduce temporalmente el área visible de la
  mochila.
- La franja de resumen muestra dano, defensa y ocupacion. Dano y defensa permanecen explicitamente como placeholders hasta conectar el sistema de atributos.
- Mochila fija de 24 espacios en cinco columnas compactas. El viewport muestra
  unas tres filas y permite desplazamiento vertical; una fracción de la fila
  siguiente comunica que existe más contenido sin convertir la mochila en la
  superficie dominante de la ventana.
- Armas, herramientas, escudos y armaduras no son apilables: cada unidad ocupa
  una ranura. Los recursos homogéneos, como madera e hierro, sí comparten ranura
  y muestran su cantidad. La futura durabilidad y calidad requerirán un ID de
  instancia por pieza, pero la presentación ya respeta esa ocupación.
- La paleta usa cuero carbon, pergamino oscuro y laton envejecido, junto con la tipografia configurada en el tema medieval del proyecto.
- Los placeholders visuales siempre se muestran con guion y texto de sistema pendiente; nunca inventan cifras de gameplay.
- Los objetos equipables conservan interaccion directa; las ranuras superiores permiten desequipar y la cuadricula permite equipar o guardar.
- El inventario se dibuja por encima del HUD persistente para que el núcleo de
  habilidades nunca invada sus controles.

## Vista Sector (`Tab`)

- Cubre casi todo el viewport con un margen seguro reducido.
- Cabecera compartida con titulo, coordenadas, tabs Sector/Mundo y cierre con `Esc`.
- La carta regional ocupa aproximadamente el 75 % del ancho.
- Columna derecha estrecha para ubicacion, salidas y marcas.
- Herramientas inferiores limitadas a acciones funcionales: centrar, ping, ataque, defensa y zoom.
- Sin buscador ni filtros hasta que tengan datos y comportamiento reales.
- La carta no es una pintura fija. Se deriva de `surface_reference.png`, `height_preview.png` y capas de contenido del sector cargado.
- Costa, relieve, objetos y marcador mantienen la misma transformacion espacial que el terreno jugable.
- Los elementos ilustrativos se dibujan como overlays a escala; nunca pueden deformar la geografia base.

## Vista Mundo (`M`)

- Reutiliza exactamente la misma carcasa, cabecera, tabs y ritmo visual de Sector.
- El atlas es una ilustracion territorial continua; las divisiones son limites cartograficos sutiles, no una matriz de botones.
- La seleccion muestra territorio, bioma, grado y recursos en la columna derecha.
- Controles inferiores: region actual, mundo completo y zoom.
- El boceto territorial y el JSON de sectores siguen siendo las fuentes estructurales. Una futura ilustracion pintada debe respetar sus costas y coordenadas.
- La costa, islas, fronteras y rutas de `assets/boceto.png` son invariantes.
- La mascara de superficie determina tierra, costa, agua somera y agua profunda.
- `map_design_biomes.json` determina el bioma. La presentacion suaviza bordes entre celdas sin cambiar su pertenencia logica.
- Los polos superior e inferior son hielo/nieve. La influencia polar se interpola por latitud y vecindad hacia puntas y esquinas de los continentes en media luna.
- El oceano permanece liquido en todas las latitudes durante esta fase; la influencia polar solo modifica tierra e islas.
- La gran medialuna occidental se mantiene como terreno bajo, sin la cadena montanosa longitudinal del primer estudio.
- Castillos, ciudades, caminos y puntos de interes son una capa autoral separada. No se generan automaticamente.
- Barcos o bestiario marino pueden existir como decoracion oceanica no interactiva, claramente separados de los datos de gameplay.

## Carga y autoridad cartografica

- El servidor conserva autoridad sobre sector, posiciones, portales, recursos y estados compartidos.
- El cliente descarga o abre un paquete de sector al viajar: terreno, referencias cartograficas, colisiones y manifiesto de contenido.
- El minimapa y `Tab` se construyen localmente desde ese paquete y se cachean; no requieren transmitir imagenes continuamente desde el servidor.
- Al cruzar de sector se descarga la escena anterior cuando corresponde, se abre una transicion breve y se activa el nuevo paquete solo cuando sus datos minimos estan listos.
- El atlas mundial permanece liviano: textura base global, mascara/biomas y metadatos resumidos. El contenido detallado se solicita al seleccionar o entrar a un sector.

### Tutorial

- Costa del Naufragio es una instancia local y privada del prologo, no un territorio ordinario del mundo persistente.
- Su mapa se carga desde el paquete tutorial del cliente y puede usar coordenadas tecnicas internas sin aparecer en el atlas mundial.
- Al terminar navegando, el cliente descarga el tutorial, conecta con el mundo persistente y carga el primer sector real asignado por el servidor.
- La posibilidad de regresar al tutorial queda como decision futura y no condiciona la topologia mundial actual.

## Navegacion

- Desde juego: `Tab` abre Sector; `M` abre Mundo.
- Con un mapa abierto: `Tab` cambia a Sector y `M` cambia a Mundo sin cerrar primero.
- `Esc` vuelve al juego.
- El HUD persistente se oculta mientras cualquiera de los mapas esta abierto.
- El movimiento del personaje queda bloqueado, excepto en un futuro modo de viaje explicitamente activado.

## Direccion de materiales

- Pergamino: marfil sucio, fibras visibles, manchas suaves y bordes irregulares gastados.
- Estructura: cuero carbon y laton opaco; evitar marcos dorados brillantes.
- Estados: dorado tenue para seleccion, oxblood para peligro/salud y teal desaturado para energia.
- Tipografia: serif cartografica para titulos; sans/serif muy legible para controles pequenos.
- Ornamentacion: solo cuando ayuda a reconocer escala, norte, peligro o navegacion.

## Cursores

- Los recursos fuente conservan 64 px, pero se presentan a 40 px para aproximarse al 125 % del cursor clasico de Windows sin perder la silueta medieval.
- Menus, inventario, selector de personaje y controles de interfaz usan la flecha normal.
- El terreno 3D usa la mano apuntando como cursor base de movimiento e interaccion.
- Los campos editables usan un I-beam propio del kit para evitar el salto entre el cursor grande y el cursor de texto del sistema.
- Los estados de arrastre conservan mano abierta y mano cerrada; ataque, PvP y zoom quedan reservados para sus mecanicas contextuales.

## Decisiones pendientes

1. Barra de acciones siempre visible o atenuada/replegable fuera de combate.
2. Contenido futuro del desplegable de personaje: estado PvP y efectos activos solo cuando existan esas mecanicas.
3. Grado de irregularidad del borde del minimapa para no perder legibilidad al reducirlo.
4. Nivel de detalle del atlas pintado en zoom completo y en zoom regional.

## Implementacion propuesta

1. Convertir Sector y Mundo en controles full-rect responsivos con una carcasa compartida.
2. Mantener el minimapa unico arriba a la derecha y concentrar retrato y acciones abajo al centro.
3. Separar los adornos en recursos reutilizables: marco, tabs, retrato, slots y panel lateral.
4. Generar el atlas pintado respetando el boceto existente y vincular seleccion/hover a `MapDataManager`.
5. Validar a 1280x720, 1920x1080 y ultrawide, incluyendo escala de UI y contraste.

## Laminas v1

- `concepts/hud/hud_gameplay_v1.png`
- `concepts/hud/hud_sector_fullscreen_v1.png`
- `concepts/hud/hud_world_fullscreen_v1.png`

## Estudios v2 basados en fuentes reales

- `concepts/hud/hud_sector_fullscreen_v2_source_faithful.png`: usa superficie y altura reales del tutorial como invariantes.
- `concepts/hud/world_atlas_style_study_v2.png`: estudio de paleta y pincel sobre el boceto real. No es textura de produccion porque la fidelidad final debe obtenerse mediante composicion determinista de boceto, mascara y biomas.
- `concepts/hud/world_atlas_style_study_v3_liquid_ocean.png`: revision aprobable con oceano liquido, nieve limitada a tierra polar y medialuna occidental sin cordillera.
- `concepts/hud/world_atlas_style_study_v4_polar_continents.png`: referencia final corregida; conserva oceano liquido y recupera los continentes polares continuos de los bordes norte y sur.
- `assets/ui/maps/world_atlas_cartographic.png`: textura cartografica conectada actualmente al atlas jugable; respeta la geografia, rutas y divisiones del boceto fuente.

## Estado implementado

- HUD persistente centrado: cuatro habilidades a cada lado del núcleo, cuatro ranuras insignia cardinales, acceso a Maestrías y barras laterales de vida y maná.
- Oro y plata no aparecen en el HUD persistente; se reservan para interfaces económicas contextuales.
- Minimapa real en la esquina superior derecha, derivado del sector cargado, con marcador orientado, controles minimalistas de zoom/expansion y borde de pergamino desgastado.
- El minimapa compacto no muestra pestanas ni recordatorios `Tab`/`M`; esos accesos siguen funcionando por teclado y en tutorial.
- Edicion de HUD con `F10` o desde pausa: arrastre, escala con rueda, persistencia por modulo y restauracion.
- `Tab` abre el mapa regional como menú de pantalla completa y usa un proxy 3D
  reducido del sector cuando existen altura y superficie exportadas; conserva
  la carta 2D como fallback.
- `M` abre el atlas mundial con falsa perspectiva, relieve horneado, zoom,
  paneo, hover territorial y centrado en la región actual. La grilla de sectores
  solo se revela en zoom cercano.
- Sector y Mundo son estados exclusivos: cambiar de pestaña oculta la anterior y cerrar Mundo devuelve directamente al juego.
