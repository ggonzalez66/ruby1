# Combate de Viridy: sin armas ni Liquid Beast

Viridy pelea con sus garras, sus patadas y la lanza jade. Las armas (catálogo, pedestales, perfiles comunes y sprites) y la Liquid Beast como forma transformable se retiraron: su código sigue en el historial de Git, en el commit 23ef354 y anteriores. La identidad de la bestia queda en tres sitios: los pesados, las ejecuciones y Wrath of Nature.

Arte de la bestia: la hoja propuesta por el usuario (`~/ruby1_referencias/bestia/usuario_bestia_v1.png`, fondo magenta), armada con `tools/art/assemble_beast_user.py` (chroma key, limpieza del borde rosado y componentes conectados).

- `viridy_beast_head_v2.png`: 5 cabezas con la llama creciendo hacia atrás y las fauces fijas en x = 610. La embestida las recorre todas; la picada y la salida alargada usan la 4 y la 5; el mascado de la ejecución alterna la 1 y la 2.
- `viridy_wrath_beast_v2.png`: la bestia completa, con la boca en x = 660. Por el suelo galopa (frames 0 a 3, con las patas apoyadas en el suelo en cada frame y polvo en cada pisada); en el aire o en diagonal arremete con las llamaradas estiradas (frames 4 a 6); en la frenada y la rotura se agacha (frames 7 a 10).

El cuerpo serpentino dibujado (`beast_trail.gd`) solo acompaña las ejecuciones; los dibujos nuevos ya traen su propia llama. La cabeza anterior (`viridy_beast_head.png`) se conserva.

## Controles

| Acción | Mando por defecto | Teclado/ratón por defecto |
| --- | --- | --- |
| Ligero (combo de 5) | X | Clic izquierdo |
| Pesado: embestida en el suelo, picada en el aire | Y | Clic derecho |
| Uppercut | Arriba + Y | W / ↑ + clic derecho |
| Aim (mantener) / recuperar la lanza clavada (un toque) | LT | Clic central |
| Soltarse del sabueso (machacar) | X | Clic izquierdo |
| Apuntar en Aim | Stick derecho | Ratón |
| Lanzar la lanza en Aim | RT | Shift |
| Dash / correr | RT | Shift |
| Parry / guardia | LB o B | Tab |
| Cámara lenta | RB | — |

Es el esquema de antes de las armas (versión de controles 9). Los ajustes guardados en las versiones 5 a 8 recuperan LT, el parry y la cámara lenta en su botón por defecto. Aim permite caminar y saltar, pero cancela la carrera y el dash, y RT lanza en vez de dashear. Mientras LT siga pulsado (también después de lanzar) RT nunca dashea ni corre, y un RT pulsado con LT no dashea hasta soltarlo y volver a pulsarlo.

El dash usa una sola pose, `viridy_dash.png`, con sus colores originales.

## Combo ligero y pesado

`light_combo.gd` lleva el combo ligero: tres zarpazos con su geometría original y dos patadas. Tiempos a 60 Hz (startup / active / recovery):

| Golpe | S / A / R | Daño | Alcance | Notas |
| --- | --- | --- | --- | --- |
| Zarpazo 1 | 2 / 3 / 5 | 1 | polígono original | |
| Zarpazo 2 | 2 / 3 / 5 | 1 | polígono original | |
| Zarpazo 3 | 3 / 4 / 6 | 2 | polígono del remate | |
| Patada 1 | 3 / 4 / 7 | 2 | 118 × 65 | stagger 0,35 s, empuje 340 |
| Patada 2 | 4 / 5 / 8 | 2 | 132 × 75 | stagger 0,5 s, empuje 440 |

Startup anticipa sin daño, active golpea una vez a cada objetivo y recovery mantiene la acción ocupada. El buffer de ligero espera al recovery. Los ligeros encadenan en el aire, pero solo sostienen a Viridy después de conectar con un enemigo, hasta aterrizar.

El pesado ya no es un string: en el suelo es la embestida única hacia delante, con 1 s de reutilización; en el aire, la picada (adelante, diagonal o dive) que rebota al golpear. Los dos usan la cabeza de la bestia en llamas. El recovery de cualquier ligero, incluidos los ataques en carrera en su segunda mitad, se cancela al instante en un pesado. Un pesado pulsado antes del recovery queda en cola y sale en cuanto empieza.

Sprites de las patadas: la hoja propuesta por el usuario (`~/ruby1_referencias/patadas/usuario_patadas_v1.png`, 2 filas × 6 frames), armada con `tools/art/assemble_kicks_user.py` en `viridy_kick1_v2_arcade.png` y `viridy_kick2_v2_arcade.png`. Son 6 frames de 768 × 512 con los pies en y = 480, y la grilla de la hoja hace de ancla. Cada figura se separa por componentes conectados, y se escala a la altura del golpe ligero 1. Se muestran con sus colores, sin la corrección jade. Por fase: startup recorre guardia y dos recogidas, active muestra la pierna extendida, recovery muestra recuperación y guardia (`KICK_FRAMES`).

Queda como alternativa una v1 de 3 frames hecha con SD (`viridy_kick1_arcade.png`, `viridy_kick2_arcade.png`, de `tools/art/kick_art.py`). Usa esqueletos OpenPose con ControlNet union, pixel art LoRA e IP-Adapter, y sus crudos están en `~/ruby1_referencias/patadas`. Capturas del juego en `docs/art/unarmed_rework/runtime/`, hechas con `tools/art/capture_unarmed.gd`.

## Ejecuciones

- **OPEN:** el parry abre a un enemigo pequeño durante 2 s. Poca vida no abre.
- **DYING:** a cero de vida un enemigo pequeño queda 4 s inactivo y ejecutable. Cada golpe que no ejecuta le resta 1,4 s (al tercero explota).
- **Regla única:** un pesado (embestida, picada, dive o uppercut) que conecta con un rubí OPEN o DYING lo ejecuta. El golpe que deja al enemigo a cero no lo ejecuta en el mismo impacto: primero entra en DYING. Parry + pesado es un riposte con ejecución.
- **Lanza:** recuperar la lanza clavada en un enemigo OPEN o DYING teletransporta a Viridy y lo ejecuta.
- **Recompensa:** curación, mucha Ferocity, dash disponible, y se devuelven el doble salto y el uppercut aéreo. Si DYING expira, el enemigo muere sin recompensa.
- **Cadena:** el estallido de una ejecución reinicia a 4 s el DYING de los vecinos dentro de su radio («¡CADENA!»), en vez de restarles tiempo. El estallido de un DYING que expira solo los golpea.
- **Jefes:** conservan postura, críticos y ventana final; los ejecuta cualquier pesado.
- **Stagger** (patadas): interrumpe y aturde; no abre el rubí.

## Lanza jade

Mantener LT abre Aim; RT la lanza en la dirección apuntada a 1300 px/s. Vuela recta 0,45 s y luego la gravedad la curva. Se clava en un enemigo (marca con quemadura no letal de hasta 2 s) o en el terreno. Con la lanza clavada, un toque de LT la recupera; en vuelo no. El regreso hace poco daño (2, luego 70 %, 49 %… por orden de contacto, mínimo 1) y atrae una vez a cada enemigo atravesado (Soul pull). Recuperarla con LT mantenido no reabre Aim hasta volver a pulsarlo.

**Shine lanza:** rugir (parry) mientras la lanza vuelve la dispara otra vez, recta, contra el último enemigo en que estuvo clavada. Encadena recuperar, rugir y recuperar. Los enemigos que la shinean de vuelta siguen funcionando como antes.

## Wrath of Nature

En rango SSS, agacharse carga Wrath; el pesado abre la dirección y luego la embestida. Ya no requiere transformarse. Durante el avance aparece la bestia completa: 300 px de celda en pantalla (antes 185), con las fauces 56 px por delante de Viridy. Por el suelo galopa con las patas en el suelo; en el aire o en diagonal arremete. Al frenar se agacha. La captura es una cápsula de radio 58 (antes 38) que llega hasta las fauces. El pesado durante el avance frena gradualmente y ejecuta ahí lo capturado. Contra una pared, el peso lo devuelve varios metros. Desde el suelo no se apunta hacia abajo ni hacia atrás.

## Enemigos y gauntlet

Perseguidor, escudero y halcón usan sprites de autómatas (`enemy_skin.gd`, `tools/art/enemy_art.py`). Los enemigos nuevos, el guardián mecha y sus reglas se describen en [docs/art/enemies_v2/README.md](../art/enemies_v2/README.md). El gauntlet vuelve a empezar directamente con la primera oleada y conserva la torre trepable y los semipisos laterales. El santuario ya no tiene pedestales.

## Validación

- `test_unarmed_combat.gd`: combo de 5, embestida y picada con la cabeza de león, sostén aéreo solo al conectar, Aim + RT, recall con LT, estados del rubí y ejecución por pesado.
- `test_execution_rework.gd`: cadena de DYING, expiración sin cadena, recursos aéreos devueltos y Wrath sin transformación.
- `test_attack_phases.gd`: daño por fase de los cinco ligeros, buffer, poses y cola del pesado.
- `test_dying_interactions.gd`: recall ordenado, ejecución real de los cuatro enemigos pequeños, golpes en DYING y parry con B y LB.
- `test_jade_soul_pull.gd`, `test_spirit_spear.gd`, `test_shine_shield.gd`: teleejecución en OPEN y DYING, shine lanza.

## Ejecutables

Exportados con Godot 4.2.2 para Windows (`builds/windows/Ruby1.exe`) y Linux (`builds/linux/Ruby1.x86_64`). Tamaños y SHA-256 en `builds.json`, arranque en `native_smoke.json`. Lanzado desde WSL, el exe de Windows siempre devuelve código 1, también con builds anteriores. Los binarios están en `builds/`, ignorado por Git.
