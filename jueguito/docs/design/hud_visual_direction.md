# Direccion visual del HUD

Estado: direccion visual v2 implementada.

## Principio general

El HUD debe sentirse como un conjunto de instrumentos fisicos del mundo: cartas usadas, cuero oscuro, laton envejecido y tinta deslavada. La interfaz persistente debe ser ligera. Los mapas regional y mundial son modos de concentracion a pantalla completa, no ventanas flotantes.

## Vista de juego

- Inferior centro: retrato circular como nucleo del personaje. Un clic despliega nombre, nivel, vida y energia hacia arriba; cerrado no ocupa espacio informativo adicional.
- Centro inferior, sobre el retrato: cuatro habilidades a la izquierda, tres habilidades insignia al centro y cuatro accesos de objetos a la derecha. Vida y mana cierran la composicion debajo de los grupos laterales.
- Superior centro: contador simetrico de oro y plata con identificadores de moneda. No se muestran estadisticas competitivas sin una mecanica que las justifique.
- Superior derecha: unico minimapa local inclinado, con borde de pergamino desgastado, nombre de zona y tres controles de borde: acercar, alejar y expandir.
- Centro de la pantalla: libre salvo informacion contextual temporal.
- El minimapa usa la textura y posicion reales del sector; no replica datos ni crea una segunda fuente cartografica.
- `Tab` y `M` permanecen como atajos aprendidos en el tutorial, no como etiquetas permanentes del minimapa.

### Edicion del HUD

- Cada modulo persistente se puede mover dentro de una zona segura: personaje, acciones, oro y minimapa.
- La escala se configura por modulo, ademas de una escala global de interfaz.
- Las posiciones se guardan como ancla normalizada mas offset, no como pixeles absolutos, para sobrevivir a cambios de resolucion.
- El modo de edicion muestra limites, alineacion y boton de restaurar valores recomendados.
- El minimapa conserva personalizacion de inclinacion y color del puntero.

## Inventario

- Ventana vertical anclada al costado derecho, inspirada en inventarios compactos de MMO sin copiar su decoracion literal.
- Cabecera con retrato, nombre del personaje, titulo y cierre; debajo aparecen solamente las ranuras de equipo que ya tienen logica real: mano principal y secundaria.
- Franja de recursos con oro, cantidad total de objetos y ocupacion de mochila.
- Mochila fija de 24 espacios en cuatro columnas. Las pilas existentes muestran icono, nombre abreviado y cantidad; los espacios libres conservan la cuadricula visible.
- La paleta usa cuero carbon, pergamino oscuro y laton envejecido, junto con la tipografia configurada en el tema medieval del proyecto.
- No se muestran estadisticas, categorias o ranuras ficticias hasta que existan sistemas que las respalden.
- Los objetos equipables conservan interaccion directa; las ranuras superiores permiten desequipar y la cuadricula permite equipar o guardar.

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

- HUD persistente centrado: retrato colapsado que despliega datos hacia arriba; cuatro habilidades, tres insignias y cuatro objetos sobre el nucleo, con vida y mana laterales.
- Contadores de oro y plata centrados arriba, preparados para leer moneda autoritativa del personaje.
- Minimapa real en la esquina superior derecha, derivado del sector cargado, con marcador orientado, controles minimalistas de zoom/expansion y borde de pergamino desgastado.
- El minimapa compacto no muestra pestanas ni recordatorios `Tab`/`M`; esos accesos siguen funcionando por teclado y en tutorial.
- Edicion de HUD con `F10` o desde pausa: arrastre, escala con rueda, persistencia por modulo y restauracion.
- `Tab` abre el mapa regional como menu de pantalla completa; `M` abre el atlas mundial con zoom, paneo, hover territorial y centrar en region actual.
- Sector y Mundo son estados exclusivos: cambiar de pestaña oculta la anterior y cerrar Mundo devuelve directamente al juego.
