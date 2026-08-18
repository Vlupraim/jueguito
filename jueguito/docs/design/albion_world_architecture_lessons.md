# Lecciones de Albion para la arquitectura del mundo

Estado: investigación inicial, 1 de agosto de 2026.

## Alcance y criterio de evidencia

Este documento estudia problemas reconocidos públicamente por Sandbox
Interactive durante la evolución de Albion Online y los traduce a riesgos de
nuestro proyecto. No intenta copiar su mundo, economía ni reglas PvP.

Se priorizan artículos y declaraciones oficiales. Los comentarios de jugadores
se consideran señales cualitativas, no hechos técnicos confirmados. Albion no
ha publicado en estas fuentes su implementación completa de servidores ni del
renderer cartográfico; cuando este documento propone una arquitectura, está
marcada como recomendación propia.

## Resumen ejecutivo

Albion confirma que un mundo segmentado no se resuelve solamente construyendo
muchos mapas. Los problemas difíciles aparecen en las fronteras entre sistemas:

- topología comprensible sin repetición mecánica;
- progresión territorial sin crear un único extremo dominante;
- capacidad limitada de cada zona sin permitir que se use como arma;
- entradas y salidas que no produzcan emboscadas inevitables;
- recursos dinámicos reproducibles y persistentes;
- migración segura cuando cambia la geografía;
- contenido suficiente para la población real de cada horario;
- mapas visualmente claros que sigan representando la geometría jugable.

Nuestro proyecto ya tiene una ventaja: sector, atlas, terreno exportado y estado
del personaje están separados. Sin embargo, todavía mezcla definición estática,
presentación cliente y simulación autoritativa en varios puntos que deben
separarse antes de escalar a multijugador real.

## Problemas encontrados por Albion y lecciones transferibles

### 1. Equilibrio perfecto produjo repetición y predicción

Las antiguas Tierras Lejanas se diseñaron de forma simétrica, limpia y
equilibrada. El resultado fue un patrón que los jugadores podían anticipar:
después de cierto tier venía otro y determinados objetivos aparecían a una
distancia regular. El rediseño introdujo excepciones locales —tiers y biomas
vecinos inesperados— pero conservó reglas macro legibles, como una mayor
densidad de valor hacia el centro.

**Lección:** regularidad de datos no debe significar regularidad de experiencia.
La topología necesita reglas globales comprensibles y variación local diseñada.

**Riesgo actual:** `MapDataManager._generate_sector_portals()` conecta cada
celda con sus cuatro vecinos cardinales y el grado se calcula mediante distancia
Manhattan al centro. Si esas funciones dejan de ser provisionales, reproducen el
mismo mundo predecible que Albion terminó reemplazando.

Fuente: [Dev Talk: The New Outlands](https://albiononline.com/news/devtalk-new-outlands).

### 2. Un mundo “estirado” bloqueó la progresión territorial

Albion separó inicialmente las áreas débiles y valiosas mediante mucha distancia,
con el endgame concentrado en un extremo. En la práctica, los gremios ocuparon
el espacio disponible y no encontraron una progresión razonable hacia Mercia.
La revisión colocó gran valor en un centro atacable desde varios lados y agregó
hotspots secundarios distribuidos por el continente.

**Lección:** la distancia por sí sola no crea progresión. Deben existir varias
rutas, escalones intermedios y objetivos alternativos; el lugar más valioso no
puede tener una única dirección de acceso.

Fuente: [Dev Talk: Queen Update Introduction](https://albiononline.com/news/devtalk-queen-update-introduction).

### 3. Cada mapa artesanal tiene un costo alto y multidisciplinario

El proceso publicado por Albion comienza con una ficha de requisitos, pasa por
boceto, terreno, estructuras críticas, caminos, decoración, recursos, conexión
en un editor mundial, prueba local y finalmente playtest integrado. En 2015
estimaban unas 35 horas de trabajo para un mapa pequeño.

**Lección:** no debemos exigir acabado artesanal completo para poder añadir un
sector. Necesitamos una plantilla de datos validable y pases separados:

1. propósito, escala, bioma y conexiones;
2. terreno y rutas navegables;
3. puntos críticos y recursos;
4. decoración;
5. proxy cartográfico;
6. validación local e integrada.

Fuente: [How a Map for Albion Online is Designed](https://albiononline.com/news/map-design-albion).

### 4. La claridad se degradó por ruido y mapas genéricos

En `Lands Awakened`, Albion reconoció que muchos layouts antiguos se sentían
saturados o genéricos. Rehicieron los mapas para reducir clutter, crear temas
memorables y hacer los choke points parte natural de cada bioma. Además, el
terreno estratégico visible en el mundo pasó a reflejarse en el mapa.

**Lección:** el mapa regional no debe mostrar todos los objetos del sector. Debe
resumir las decisiones espaciales: costa, desnivel, rutas, bloqueos, salidas y
landmarks. El piloto 3D de `Tab` debe ser un proxy cartográfico, no una segunda
cámara que renderice indiscriminadamente el nivel completo.

Fuentes: [Dev Talk: Biome Rework](https://albiononline.com/news/devtalk-biome-rework) y
[Lands Awakened](https://albiononline.com/update/lands-awakened).

### 5. La capacidad de una zona se convirtió en una mecánica explotable

Los ejércitos podían llenar un cluster hasta su límite y negar la entrada al
rival. Albion creó la Smart Cluster Queue para repartir plazas de una zona
saturada y trasladar el excedente a zonas adyacentes. Después tuvo que corregir
un nuevo abuso: entrar y salir deliberadamente para expulsar rivales y evitar
que volvieran a ponerse en cola. Agregó protección temporal, penalización por
retirada temprana y ciclos de cola más largos.

**Lección:** un límite técnico visible siempre puede transformarse en estrategia.
Colas, transferencias y prioridades deben ser autoritativas, resistentes a
identidades/grupos manipulados y diseñadas junto a las entradas físicas.

Fuentes: [Queen Update Introduction](https://albiononline.com/news/devtalk-queen-update-introduction),
[Smart Cluster Queue — declaración de desarrollador](https://forum.albiononline.com/index.php/Thread/131458-Smart-Cluster-Queue/) y
[Skip Overcrowded Clusters](https://forum.albiononline.com/index.php/Thread/141216-Skip-Overcrowded-Clusters/).

### 6. Los portales concentraron emboscadas

Tras el lanzamiento de Queen, las zonas de portal se convirtieron en algunos de
los lugares más peligrosos. Albion añadió conexiones, santuarios de invisibilidad,
silencio temporal y cooldown para que entrar al mundo peligroso no significara
morir antes de tomar una decisión.

**Lección:** una transición de sector requiere un contrato completo: reserva de
destino, punto seguro validado, protección breve, prevención de doble tránsito y
fallback si el destino no está disponible. El spawn no debe coincidir con un
punto que el enemigo pueda bloquear permanentemente.

Fuente: [Anti Portal-Ganking Measures](https://forum.albiononline.com/index.php/Thread/125487-Anti-Portal-Ganking-Measures-with-Patch-7/).

### 7. Los recursos dinámicos necesitan posiciones candidatas y estado estable

Albion mantiene un conjunto de posiciones posibles por zona y activa una parte
según tier y otros parámetros. La redistribución ocurre durante mantenimiento,
pero cada nodo conserva cargas y tiempo pendiente de reaparición.

**Lección:** separar tres conceptos:

- definición estática de posiciones candidatas;
- selección determinista/autoritativa de posiciones activas;
- estado persistente de cada instancia activa.

**Riesgo actual:** nuestro cliente genera abundancias con `randi_range()` al
cargar `MapDataManager`, y el servidor provisional solo conserva
`resource_id -> respawn_at`. Dos clientes podrían construir atlas distintos y
no existe aún partición/versionado del estado por sector.

Fuente: [Resource Distribution Changes in the New Outlands](https://forum.albiononline.com/index.php/Thread/122488-Resource-Distribution-Changes-in-the-New-Outlands/).

### 8. Cambiar el mundo obliga a migrar estado persistente

El reemplazo de las Tierras Lejanas exigió evacuar jugadores, bancos y bóvedas;
algunos edificios y cofres podían perderse, y ciertos sistemas todavía no tenían
una regla de migración cerrada cuando se anunció el cambio. Otro rediseño movió
automáticamente escondites cerca de su posición anterior y permitió corregirlos
durante una ventana limitada.

**Lección:** una coordenada no puede ser la identidad permanente de una entidad.
Sectores, asentamientos y contenedores necesitan IDs estables, versión de
topología y scripts de migración idempotentes con destino seguro.

Fuentes: [The New Outlands](https://albiononline.com/news/devtalk-new-outlands) y
[Biome Rework](https://albiononline.com/news/devtalk-biome-rework).

### 9. La topología dinámica necesitó límites y luego un reenfoque

Las Roads of Avalon usan un grafo cuyos enlaces cambian, tienen duración y
capacidad. Esto produce exploración y atajos sin añadir conexiones permanentes.
Con el tiempo Albion tuvo que reenfocarlas hacia grupos pequeños, dificultar el
control total de regiones valiosas y ajustar conexiones y recompensas según la
actividad observada.

**Lección:** una conexión dinámica no debe ser solo `origen -> destino`. Necesita
ID, versión, apertura, expiración, capacidad, reglas de acceso y telemetría. No
conviene construir este sistema hasta que el tránsito estático sea seguro.

Fuentes: [Roads of Avalon, Part 1](https://albiononline.com/news/devtalk-roads-of-avalon-part-1),
[Development Update 2022](https://albiononline.com/news/development-update-sep-2022) y
[Paths to Glory](https://albiononline.com/news/dev-talk-paths-to-glory).

### 10. La población real no se distribuye como predice el diseño

Albion ha ajustado contenido y recompensas basándose en actividad por servidor y
horario. También ha usado modos temporales para concentrar población en lugar de
mantener demasiadas actividades permanentemente abiertas.

**Lección:** no diseñar tasas dinámicas sin observabilidad. Antes necesitamos
métricas por sector: jugadores concurrentes, tiempo de permanencia, entradas,
salidas, muertes, recursos recolectados y latencia de simulación.

Fuentes: [Paths to Glory](https://albiononline.com/news/dev-talk-paths-to-glory) y
[Development Update May 2026](https://albiononline.com/news/dev-update-may-2026).

### 11. El estilo visual también es una decisión de rendimiento

Albion atribuyó parte de su estilo limpio y legible a las restricciones de un
cliente multiplataforma. La optimización para dispositivos modestos benefició a
todas las versiones.

**Lección:** el mapa 3D regional debe usar malla reducida, materiales compartidos,
props instanciados y actualización bajo demanda. No debe duplicar Terrain3D,
vegetación física y simulación del sector dentro del HUD.

Fuente: [On Cross-Platform Development](https://albiononline.com/news/cross-platform-development).

## Auditoría de nuestra arquitectura actual

### Fortalezas que conviene conservar

- El atlas posee un archivo fuente versionado (`map_design_sectors_5km.json`).
- Cada personaje guarda sector y posición por separado.
- Los exports de Terrain3D separan altura, control, superficie y metadata.
- El mapa local y el atlas consumen datos compartidos mediante `MapDataManager`.
- El contenido artesanal de un sector puede vivir en una escena independiente.

### Riesgos prioritarios

| Prioridad | Riesgo actual | Consecuencia futura |
| --- | --- | --- |
| P0 | Recursos y hostiles aleatorios en el cliente | Clientes inconsistentes, imposible reproducir o depurar |
| P0 | Toda celda recibe cuatro portales cardinales | Rutas sobre océano, topología repetitiva y sin identidad |
| P0 | Sector identificado principalmente por coordenada | Migraciones peligrosas cuando cambie el atlas |
| P0 | Servidor autoritativo todavía vive como mock dentro del cliente | No existe aislamiento, capacidad ni transferencia real entre sectores |
| P1 | Los 2546 sectores se enriquecen y cargan de una vez | Escala mal al añadir estado, nombres, rutas y POI detallados |
| P1 | Estado de recursos es una tabla global sin partición/versionado | Colisiones de IDs y migraciones difíciles |
| P1 | El atlas mezcla datos reales con placeholders procedurales | La presentación puede comunicar reglas que el servidor no comparte |
| P2 | El mapa regional actual ignora la altura que recibe | No puede representar relieve ni choke points jugables |

## Arquitectura objetivo recomendada

```text
WorldDefinition (versionada, estática)
  ├─ regiones y sectores con UUID estable
  ├─ grafo explícito de conexiones
  ├─ bioma, reglas y posiciones candidatas
  └─ migraciones entre versiones

WorldTopologyService (servidor autoritativo)
  ├─ conexiones activas y capacidad
  ├─ reserva/transferencia entre sectores
  └─ validación de spawn y fallback

SectorRuntime (estado particionado)
  ├─ jugadores y entidades dinámicas
  ├─ recursos activos y respawn
  └─ métricas de población/rendimiento

MapProjection (cliente, solo lectura)
  ├─ minimapa 2D
  ├─ proxy 3D regional de Tab
  └─ atlas 2D mundial
```

La proyección cartográfica nunca debe inventar peligro, recursos o conexiones.
Solamente representa una instantánea aprobada por la definición o el servidor.

## Orden de trabajo propuesto

### Ahora, mientras existe un solo sector jugable

1. Definir esquema `WorldDefinition v2` con UUID, tipo de celda y conexiones
   explícitas; mantener coordenadas solo como ubicación cartográfica.
2. Sustituir azar cliente por valores estáticos o una semilla/versionado común.
3. Crear un validador offline: conexiones recíprocas, tierra/agua, salidas,
   archivos Terrain3D, spawn seguro y IDs únicos.
4. Construir el proxy 3D de `Tab` para `(27, 30)` desde altura y superficies.
5. Añadir a la ficha de cada sector propósito, landmarks, rutas y presupuesto de
   recursos antes de decorarlo.

### Antes de multijugador persistente

1. Extraer el mock autoritativo del cliente.
2. Definir handshake de cambio de sector y recuperación ante fallo.
3. Particionar estado por sector y guardar snapshots versionados.
4. Probar migraciones sobre copias de datos persistentes.
5. Instrumentar concurrencia, tránsito, economía y latencia.

### Solo cuando la población lo justifique

1. Capacidad por sector y colas.
2. Instancias o destinos alternativos controlados.
3. Conexiones temporales.
4. Ajuste dinámico de contenido mediante métricas agregadas.

## Conclusión

La similitud programática con Albion no está en Godot frente a Unity ni en la
apariencia isométrica. Está en que ambos mundos se componen de zonas conectadas
con estado persistente, economía y concurrencia. La decisión más valiosa ahora
es tratar el atlas como un grafo versionado y autoritativo, no como una cuadrícula
visual. Hacerlo mientras solo existe un sector terminado es barato; hacerlo
después de poblar el mundo exige evacuaciones y excepciones como las que Albion
tuvo que administrar.
