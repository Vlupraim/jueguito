# Flujo provisional: inventario, equipamiento y tala

Esta primera vertical del tutorial conecta un item real con el personaje y los
arboles talables. Todavia no reemplaza al futuro sistema persistente de items.

## Ranuras de manos

- **Mano principal:** armas de una mano, herramientas y armas de dos manos.
- **Mano secundaria:** otra arma de una mano o un objeto secundario como escudo.
- La espada vikinga permite espada + espada o espada + escudo.
- El arco vikingo es de dos manos: se muestra en principal y vacia secundaria.
- El hacha sigue siendo de una mano y conserva el tipo de herramienta `axe`.
- Las animaciones base asignadas son `attack` para espada, `archery_shot` para
  arco y `chop` para hacha. Por ahora `chop` reutiliza el ataque basico
  `attack`, reproducido a `1.30x`. Durante la tala, cada repeticion
  captura la pose final y la mezcla durante `0.28 s` con el golpe siguiente para
  evitar el salto brusco del brazo hacia la pose inicial.

## Como probarlo

1. Iniciar sesion con `admin` y entrar con `Vlupraim`, o crear un personaje.
2. Abrir el inventario con `I`.
3. Hacer clic en **Hacha de leñador**. El slot muestra `Equipado` y el modelo se
   monta en el hueso `RightHand` del personaje.
4. Hacer clic en un arbol creado con una de las escenas de
   `res://scenes/world/resources/trees/`.
5. El personaje se acerca, reproduce `shared/chop` durante siete segundos,
   recibe madera y el arbol entra en su espera de reaparicion de nueve minutos.
6. Volver a hacer clic en el hacha dentro del inventario para guardarla. Sin el
   hacha equipada, el arbol no permite iniciar la tala.

## Responsabilidades actuales

- `item_catalog.gd` describe el icono, modelo, tipo de herramienta y ajuste en
  la mano.
- `GameManager` conserva la herramienta equipada durante la sesion local.
- `gameplay_hud.gd` muestra el icono y permite equipar/guardar con clic.
- `player_controller.gd` crea el `BoneAttachment3D` en la mano derecha.
- `harvestable_tree.gd` exige una herramienta de tipo `axe`.
- `NetworkManager.ServerMock` sigue validando la recompensa y el respawn.

## Siguientes pasos del tutorial

1. Sustituir la entrega inicial por una mision o un objeto recogible.
2. Mostrar un mensaje cuando se intenta talar sin hacha.
3. Añadir durabilidad, calidad y estadisticas a la herramienta.
4. Crear el icono de madera y una definicion propia para ese recurso.
5. Persistir inventario y equipamiento en el servidor real.
