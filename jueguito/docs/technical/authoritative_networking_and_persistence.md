# Red autoritativa, sectores y persistencia

Este documento fija la arquitectura objetivo inicial del MMO Territorial. Su
propósito es permitir comenzar con una infraestructura pequeña sin introducir
decisiones que impidan crecer después.

La decisión base es usar un servidor autoritativo orientado a acciones. El
cliente presenta el mundo y predice respuestas visuales; el servidor conserva
la verdad lógica mínima, valida las intenciones y decide todos los resultados
que afectan a otros jugadores o a datos persistentes.

## Principios

- La primera versión utiliza un único proceso de servidor Godot `headless`.
- Ese proceso puede administrar jugadores y estado lógico de múltiples sectores.
- No se asigna un servidor dedicado por sector.
- Cada cliente carga y renderiza localmente el sector en el que se encuentra.
- Los clientes no actúan como servidores ni se transfieren entre sí partes del
  sector. No existe una arquitectura P2P.
- El servidor no renderiza texturas, follaje, agua, partículas ni UI.
- El cliente comunica intenciones; el servidor decide resultados.
- PostgreSQL guarda estado duradero, no la simulación de cada frame.
- FastAPI se ocupa de cuentas y operaciones web; no del movimiento ni del combate
  en tiempo real.

## Componentes

```text
Cliente Godot
  |-- HTTPS --> FastAPI de cuentas
  |                |-- PostgreSQL
  |                `-- proveedor de correo
  |
  `-- canal de juego --> servidor Godot autoritativo
                           |-- estado activo en RAM
                           `-- PostgreSQL para persistencia
```

### Cliente Godot

El cliente mantiene en su RAM la representación necesaria para jugar:

- terreno, mallas, texturas y materiales;
- árboles, rocas, edificios y decoración;
- animaciones, sonido, partículas e interfaz;
- caché visual del sector actual y, si corresponde, zonas vecinas;
- predicción visual de movimiento y acciones para evitar una respuesta torpe.

Cada computador paga su propio costo de renderizado. Si diez jugadores coinciden
en un sector, cada uno renderiza su propia copia; no se suman sus memorias para
formar una memoria compartida. La distribución natural consiste en que el
servidor no paga ese costo gráfico y cada cliente resuelve su presentación.

### Servidor Godot autoritativo

El servidor conserva únicamente datos necesarios para aplicar reglas:

- identidad, posición y estado oficial de los jugadores;
- sector de cada jugador y entidades dentro de su área de interés;
- acciones activas y sus tiempos;
- recursos modificados, agotados o en regeneración;
- enemigos y objetos dinámicos relevantes;
- inventarios, equipamiento, cooldowns, vida y estados de combate;
- reglas para validar alcance, herramientas, colisiones y permisos.

Un árbol lógico puede ocupar unos pocos campos aunque su representación visual
tenga mallas, texturas, sonidos y animaciones. El servidor debe poder ejecutar
la lógica sin GPU y sin cargar los recursos visuales.

### FastAPI de cuentas

FastAPI administra el plano de cuentas:

- registro con correo y contraseña;
- verificación de correo mediante código;
- login, renovación y revocación de sesiones;
- recuperación sencilla de contraseña;
- entrega de una credencial que el servidor Godot pueda validar.

Después de verificar el correo, el registro activa la cuenta, crea la sesión y
lleva al usuario al roster. FastAPI no recibe posiciones por frame, ataques ni
golpes de recolección.

### PostgreSQL

PostgreSQL conserva información que debe sobrevivir reinicios:

- cuentas y sesiones;
- personajes e inventarios;
- equipamiento, progreso y economía;
- estado persistente excepcional del mundo;
- tiempos de regeneración que deban sobrevivir una caída;
- auditoría de operaciones críticas.

Las credenciales de PostgreSQL sólo existen en servicios de confianza. Nunca se
incluyen en el ejecutable del jugador.

## Sectores y uso de memoria

Los sectores jugables actuales miden `5 km x 5 km`. Esa medida de diseño no
obliga a mantener todo el sector con el máximo detalle al mismo tiempo.

### Carga visual configurable

El usuario puede ajustar, según su computador:

- distancia de dibujado;
- niveles de detalle de terreno, vegetación y edificios;
- densidad de decoración no interactiva;
- resolución de texturas y sombras;
- distancia de animación de entidades;
- cantidad de sectores o franjas vecinas conservadas como caché.

Estas opciones sólo modifican presentación y consumo local. Un recurso
interactuable no deja de existir lógicamente porque el usuario reduzca el
follaje. La configuración tampoco aumenta el alcance permitido para interactuar,
atacar o detectar información que el servidor no haya enviado.

### Área de interés

El servidor envía a cada cliente sólo el estado dinámico que necesita conocer.
El área de interés es una regla de gameplay controlada por el servidor y no debe
confundirse con la distancia gráfica elegida por el usuario.

Ejemplos de datos filtrados por interés:

- jugadores y criaturas cercanas;
- recursos cuyo estado difiere del estado base;
- proyectiles, efectos y objetos soltados relevantes;
- cambios de edificios o terreno dentro del rango permitido.

### Estado base y excepciones

El contenido estático del sector viaja en el build del cliente o en paquetes de
contenido versionados. Cliente y servidor comparten identificadores estables para
los objetos interactuables.

El servidor no necesita instanciar permanentemente cada árbol del mundo. Puede
interpretar que todo recurso conserva su estado base salvo las excepciones:

```text
tree:sector_27_30:184 -> siendo_talado por player_9281
tree:sector_27_30:233 -> talado; respawn 2026-07-28T22:45:00Z
tree:sector_27_30:901 -> vida 40/100
```

Un sector sin jugadores puede descargarse de la simulación activa después de un
periodo de gracia. Antes se persisten las excepciones duraderas. Al reactivarlo,
el servidor reconstruye su estado base y aplica esas excepciones.

## Protocolo de acciones

### Recolección canalizada

Para una tala que completa una acción después de varios segundos:

1. El cliente envía `start_gather(resource_id, tool_id)`.
2. El servidor comprueba sector, distancia, herramienta, permisos, estado del
   recurso y que el personaje pueda comenzar otra acción.
3. El servidor registra la acción y su instante oficial de inicio.
4. El cliente reproduce animación, sonido y barra de progreso localmente.
5. Al completar la presentación, el cliente envía `finish_gather(action_id)`.
6. El servidor valida duración, posición, interrupciones y estado actual.
7. En una sola operación lógica marca el recurso, calcula el botín y actualiza el
   inventario oficial.
8. El servidor replica el resultado a los jugadores interesados y agenda la
   persistencia.

No se confía en un mensaje que diga simplemente `obtuve 5 maderas`. El servidor
calcula la recompensa. Si el jugador se mueve, muere, cambia de herramienta o se
desconecta, la acción puede cancelarse.

La regla de concurrencia del recurso debe definirse por tipo. Un árbol podría
bloquearse para un único jugador durante una acción canalizada, o admitir golpes
de varios jugadores manteniendo vida compartida. En ambos casos el propietario
del estado es el servidor.

### Recolección por golpes

Si cada golpe tiene consecuencias independientes, el cliente envía una intención
por golpe relevante. El servidor valida cooldown, distancia y herramienta, resta
vida y replica el nuevo estado. No se envía tráfico por cada frame de animación.

### Combate

El combate usa autoridad más frecuente:

1. El cliente captura el input y puede iniciar la animación inmediatamente.
2. Envía una intención de ataque con habilidad, dirección y referencias
   necesarias; nunca envía el daño como verdad.
3. El servidor valida posición oficial, alcance, cooldown, recursos, equipo,
   objetivo, colisión temporal y reglas del ataque.
4. El servidor calcula impacto, daño, efectos, muerte y recompensas.
5. Replica el resultado al atacante, la víctima y demás observadores relevantes.

La predicción del cliente mejora la sensación, pero debe poder corregirse cuando
el servidor rechaza o modifica el resultado.

### Movimiento

El movimiento necesita actualizaciones más frecuentes que la recolección, pero
no debe persistirse en PostgreSQL por frame. El cliente predice, el servidor
mantiene una posición oficial, aplica límites de velocidad y corrige divergencias.
La posición se persiste en checkpoints, cambios de sector y desconexiones.

El contrato de entrada se define en
`res://docs/design/player_movement_camera_interaction.md`. Para la locomoción
normal el cliente comunica intención direccional, carrera, orientación relevante
y solicitud de salto; no una posición de destino elegida por clic. El servidor
valida velocidad horizontal y vertical, estado apoyado, impulso de salto,
gravedad, control aéreo, superficies, agua y límites del sector antes de aceptar
el estado resultante. La predicción local debe poder reconciliar posición y
velocidad sin reproducir un segundo salto ni una interacción ya cancelada.

## Capas de persistencia

### RAM del cliente

Es una caché no confiable. Perderla o modificarla no cambia la verdad oficial.

### RAM del servidor

Contiene la simulación activa y permite responder sin consultar PostgreSQL para
cada acción. Es autoritativa mientras el proceso vive, pero debe volcar cambios
duraderos con una estrategia explícita.

### PostgreSQL

Es la fuente durable para reconstruir cuentas, personajes, inventarios y
excepciones persistentes. Las operaciones económicas o de inventario importantes
se realizan transaccionalmente para no entregar un objeto sin registrar su origen
o consumirlo dos veces.

### Momentos de guardado

- inmediatamente para transacciones económicas críticas;
- al obtener, gastar o transferir bienes importantes;
- al cambiar de sector;
- al desconectarse correctamente;
- mediante checkpoints periódicos;
- durante un apagado ordenado del servidor.

Se necesita además recuperación ante caída: journal de eventos críticos o
guardados suficientemente frecuentes, operaciones idempotentes y reconciliación
al reiniciar. No se debe depender únicamente del evento de desconexión.

## Sesión y entrada al mundo

1. El cliente registra o autentica la cuenta mediante FastAPI sobre HTTPS.
2. FastAPI devuelve una credencial de sesión de duración limitada.
3. El cliente abre conexión con el servidor Godot y presenta esa credencial.
4. El servidor valida firma, expiración y audiencia, o consulta al servicio de
   cuentas cuando sea necesario.
5. El servidor carga el roster y, al seleccionar personaje, su estado durable.
6. Asigna el sector y entrega estado dinámico dentro del área de interés.
7. El cliente carga localmente los recursos visuales del sector.

El servidor valida la sesión al conectar y en eventos sensibles, no mediante una
consulta HTTP por cada movimiento.

## Escalado

### Fase inicial

- una API FastAPI;
- un PostgreSQL;
- un servidor Godot para múltiples sectores;
- estado de sectores activos en RAM y persistencia de excepciones;
- clientes con calidad visual configurable.

### Optimización antes de dividir servidores

Antes de agregar procesos de juego se aplican:

- filtrado por área de interés;
- activación y suspensión de sectores sin jugadores;
- ticks de simulación distintos según relevancia;
- estructuras de estado dispersas;
- batching de persistencia no crítica;
- perfiles y pruebas de carga con escenarios reales.

### División futura condicionada por métricas

Sólo si un proceso deja de cumplir el presupuesto de CPU, RAM, latencia o ancho
de banda, el mundo puede repartirse entre varios procesos. La unidad de reparto
podría ser un conjunto de sectores, una instancia excepcional o una región de
infraestructura. Esta posibilidad no implica reservar hoy un servidor por
sector.

FastAPI puede replicarse horizontalmente porque sus instancias no conservan la
simulación del mundo. PostgreSQL escala primero verticalmente y con índices,
pooling y consultas medidas; réplicas o particionado se incorporan sólo cuando la
carga real lo requiera.

## Seguridad y consistencia

- El cliente nunca decide recompensas, daño, cooldowns ni propiedad.
- Cada petición usa identificadores de acción para evitar duplicados por reintento.
- El servidor limita frecuencia, tamaño y secuencia de mensajes.
- Los cambios de inventario críticos se auditan con causa y actor.
- Los identificadores de objetos del sector deben ser estables entre builds.
- Cliente y servidor negocian una versión compatible del contenido.
- Una desconexión cancela o resuelve de forma definida las acciones en curso.
- Los mensajes de error públicos no revelan secretos ni existencia de cuentas.

## Decisiones todavía abiertas

- tala canalizada exclusiva o vida compartida por golpes;
- duración y política de regeneración de cada recurso;
- radio de interés de gameplay por tipo de entidad;
- frecuencia de checkpoints de posición e inventario;
- política de reconexión y reserva temporal del personaje;
- comportamiento exacto al cruzar el borde entre sectores;
- qué excepciones del mundo sobreviven reinicios y durante cuánto tiempo.

Estas decisiones pueden variar por sistema sin cambiar la arquitectura general.

## Orden de implementación recomendado

1. Sustituir el registro automático del `ServerMock` por el flujo real de cuentas.
2. Definir contratos y mensajes versionados entre cliente, FastAPI y servidor.
3. Crear el servidor Godot `headless` con autenticación y sesión de personaje.
4. Sincronizar dos clientes dentro de un mismo sector.
5. Implementar una acción de tala autoritativa de inicio a fin.
6. Persistir inventario y excepciones de recursos en PostgreSQL.
7. Implementar movimiento oficial con predicción y corrección.
8. Diseñar el combate autoritativo sobre el mismo modelo de intenciones.
9. Medir CPU, RAM, latencia, ancho de banda y consultas antes de escalar.
