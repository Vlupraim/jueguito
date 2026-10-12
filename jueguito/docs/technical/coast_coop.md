# Costa cooperativa · Windows 64 bits

Esta versión permite entrar a la Costa del Naufragio con un amigo. Comparte
posición, orientación, caminar/correr/saltar/nadar/talar, equipo en las manos
y estado de los pinos. El servidor concede la madera y guarda inventarios y
tiempos de reaparición. El cliente conserva la cámara, HUD y controles actuales.

## Archivos para jugar

En `dist/` del repositorio:

- `Jueguito-Cliente-Windows.zip`: envía este ZIP a tu amigo. Ambos extraen la
  carpeta completa y abren `Jueguito.exe`. No hace falta instalar Godot.
- `Jueguito-Servidor-Windows.zip`: para el PC que aloja la partida. Extrae todo
  y abre `IniciarServidor.bat`. Mantén esa consola abierta mientras juegan.

El EXE, su PCK y la DLL de Terrain3D deben permanecer juntos. El servidor usa
la exportación dedicada de Godot, sin ventana de juego ni renderizado.

## Arranque y conexión

1. Abre `servidor/server.cfg`. La clave aleatoria está en `room_key`; compártela
   con tu amigo. Puedes cambiarla con el servidor cerrado. Puerto predeterminado:
   **7777 UDP**. `bind="*"` escucha en las interfaces disponibles.
2. Ejecuta `IniciarServidor.bat`. Espera `COOP_SERVER_READY ... port=7777`.
3. Abre el cliente y elige **Jugar en línea**. En el mismo PC del servidor usa
   `127.0.0.1`. Escribe puerto `7777`, tu nombre y la clave.
4. Tu amigo usa tu **IPv4 pública** o dominio, el mismo puerto y clave, y un
   nombre distinto. En la misma red local usa la IP local del PC servidor.
5. Ambos aparecen en la playa. WASD mueve, Espacio salta, Shift corre,
   clic derecho arrastrado orbita y la rueda acerca/aleja. Abre el inventario
   con I, equipa el hacha y pulsa un pino para acercarte y talarlo.

Con la cámara vinculada, el personaje gira hacia el movimiento y la cámara lo
sigue con un pequeño retraso y giro limitado. Mantener A, S o D conserva ese
rumbo; cambiar la dirección toma como referencia lo que ves en ese momento.
Los giros grandes reducen brevemente el avance para evitar deslizamiento lateral.
Mientras arrastras con clic derecho el giro de cámara es manual. La primera persona
conserva el control directo de la mirada.

Reutilizar el mismo nombre recupera su inventario guardado. La identificación
por nombre y clave compartida es para esta prueba entre amigos: todavía no
hay autenticación de cuentas de un servicio público. El viaje a otros sectores
está desactivado en línea para mantener a todos en la misma costa.

## Router y firewall

La IP local observada en este PC durante la preparación fue **192.168.1.130**,
con puerta de enlace **192.168.1.1**. Comprueba `ipconfig` si cambia de conexión.
Reserva esa IP para el PC en DHCP del router y agrega una regla:

| Campo | Valor |
|---|---|
| Nombre | Jueguito |
| Protocolo | UDP |
| Puerto externo | 7777 |
| IP de destino | 192.168.1.130 |
| Puerto interno | 7777 |

ENet utiliza UDP; este juego no necesita una regla TCP.
[Documentación de Godot](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

Permite `JueguitoServidor.exe` en el Firewall de Windows. La carpeta del servidor
incluye `AbrirFirewall.ps1` y `AbrirFirewall.bat`: si quieres, ejecuta el BAT como
administrador para crear una regla limitada a ese programa y puerto. No se ha
ejecutado ni se ha modificado el router durante la preparación.
[Referencia de Microsoft](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule).

El cliente de tu amigo no necesita redirigir puertos en su router. Primero
comprueba conexión local; después prueba desde otra conexión a Internet.
Una página que comprueba puertos TCP no valida este servidor UDP.

Si hay dos routers con NAT, la regla debe atravesar ambos. Si el proveedor usa
CGNAT, solicita una IPv4 pública o usen una red privada virtual que permita UDP;
en ese caso se conectan a la IP de esa red. Un router con WAN privada/CGNAT no
puede publicar el servidor solo con su regla local.
[Guía de diagnóstico de TP-Link](https://www.tp-link.com/it/support/faq/785/).

## Guardado y límites de esta versión

`servidor/server_data/state.json` se crea al jugar. Guarda inventarios por nombre
y pinos agotados; conserva esa carpeta al actualizar el servidor. Los pinos dan
cuatro maderas y reaparecen después de nueve minutos, según el reloj del servidor.

El servidor admite hasta 16 conexiones; la validación realizada usa dos clientes.
Valida clave, versión, nombres duplicados, límites del sector, altura aproximada,
velocidad, propiedad del equipo, distancia a los árboles, duración y exclusión
de tala. La locomoción usa predicción local y comprobaciones de servidor; todavía
no simula todas las colisiones, combate o física de un MMO en el servidor.
No se ha confirmado acceso por Internet hasta configurar el router y probar desde fuera.

## Desarrollo y comprobación

Godot 4.7 estable, plantillas Windows x86_64. Los presets están en
`export_presets.cfg`. `scripts/tools/build_coop.ps1` exporta secuencialmente,
prepara configuración/arranque/firewall y genera los ZIP en `dist/`.
Si faltan plantillas, descarga las oficiales a `.godot/export_runtime/templates.tpz`
y extrae los cuatro EXE Windows x86_64 a `.godot/export_runtime/templates/`.
Descarga oficial: https://godotengine.org/download/archive/4.7-stable/.

Ejemplo desde la raíz del repositorio:

```powershell
& ./jueguito/scripts/tools/build_coop.ps1 -Engine 'C:/ruta/Godot_v4.7-stable_win64_console.exe'
& ./jueguito/scripts/tools/test_coop.ps1 -Engine 'C:/ruta/Godot_v4.7-stable_win64_console.exe'
& ./jueguito/scripts/tools/test_coop.ps1 -Engine 'C:/ruta/Godot_v4.7-stable_win64_console.exe' -Client "$PWD/dist/cliente/Jueguito.exe" -Server "$PWD/dist/servidor/JueguitoServidor.exe"
```

La prueba utiliza UDP 17777 y datos aislados en `.godot/network_validation/`.
Inicia y cierra solo sus propios procesos; comprueba conexión, personajes remotos,
movimiento/salto/equipo, rechazo de teletransporte, tala compartida sin duplicar
madera, restauración visual cuando se rechaza una tala, desconexión, clave errónea
y persistencia después de reiniciar el servidor. Los logs quedan en esa carpeta.

`data/network/coast_session_catalog.json` corresponde al terreno y a los pinos
guardados actualmente. Si cambias las posiciones, recompila su catálogo con
`scripts/tools/build_coop_catalog.gd` antes de exportar ambos paquetes.
