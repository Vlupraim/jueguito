# Flujo de roster y creacion de personajes

La entrada al juego separa la seleccion y la creacion, pero reutiliza la misma
plataforma 3D y el mismo sistema de preview animado.

## Flujo de usuario

```text
Login
  -> roster de cuatro slots
     -> slot ocupado -> preview -> Iniciar aventura
     -> slot vacio -> Crear personaje
        -> nombre, cuerpo, cabello y color
        -> Crear -> roster con el nuevo personaje seleccionado
```

Un click sobre un personaje solo lo selecciona. La entrada al mundo requiere el
boton `Iniciar aventura`, evitando comenzar accidentalmente al navegar por la
lista.

## Estados de la escena

`character_selection_3d.tscn` tiene dos estados principales:

- `ROSTER`: panel izquierdo con cuatro slots y accion contextual inferior.
- `CREATOR`: formulario de personalizacion separado y preview central.

En `ROSTER`, la accion inferior muestra `Iniciar aventura` para un slot ocupado y
`Crear personaje` para uno vacio. En `CREATOR`, `Volver` restaura el slot que
estaba seleccionado sin crear datos.

## Reglas

- Cada cuenta admite como maximo cuatro personajes.
- El servidor simulado valida el limite; no depende solo de la interfaz.
- Una cuenta sin personajes selecciona inicialmente el primer slot vacio.
- Tras crear, el personaje vuelve seleccionado al roster.
- Cada seleccion actualiza el cuerpo y `shared/idle` sobre el pedestal.
- Los personajes nuevos comienzan directamente en el mundo Terrain3D, en el sector
  `(27, 30)`.

## Persistencia

Las cuentas siguen viviendo en memoria dentro de `ServerMock`. Al cerrar el juego
se pierden los personajes creados. El siguiente paso de infraestructura puede ser
serializar las cuentas a JSON local; la interfaz no deberia necesitar cambios para
incorporarlo.

## Prueba automatizada

`tests/scenes/character_roster_flow_smoke.tscn` comprueba:

- cuatro slots para una cuenta vacia;
- separacion visual entre roster y creador;
- creacion y seleccion automatica del personaje;
- preview central al seleccionar;
- accion de creacion en slots vacios;
- cuatro personajes permitidos y rechazo autoritativo del quinto.
