# Base de combate roguelite

Implementación inicial: Viridy empieza **desarmado**. Las armas cambian ligeros y heavies terrestres, además de los perfiles de uppercut, dash attack, screw y heavy aéreo (ver abajo). Los ligeros también encadenan en el aire; solo sostienen en el aire después de conectar con un enemigo (hasta aterrizar), así que atacar al vacío no permite volar.

## Controles

| Acción | Mando por defecto | Teclado/ratón por defecto |
| --- | --- | --- |
| Equipar arma suspendida | Arriba, cerca del pedestal | W / ↑ |
| Ligero | X | Clic izquierdo |
| Heavy; mantener para cargar cuando corresponde | Y | Clic derecho |
| Uppercut | Arriba + Y | W / ↑ + clic derecho |
| Aim | Mantener LT | Mantener clic central |
| Apuntar en Aim | Stick derecho | Ratón |
| Lanzar / recuperar arma | RB mientras se mantiene LT | Clic izquierdo durante Aim |
| Liquid Beast | B | Q |
| Parry / guardia (solo Viridy) | LB | Tab |
| Dash / correr | RT | Shift |

Aim permite caminar y saltar, pero cancela carrera y dash. Lanzar conserva la identidad del arma: fuera de la mano se utiliza Unarmed; recuperarla devuelve el arma original. Equipar otra en un pedestal retira el lanzamiento pendiente. No se pueden generar copias mediante recall o cambio de arma.

## Armas y balance de partida

Datos en `weapon_catalog.gd`; daño base antes de modificadores de personaje, riposte y Ferocity. Los números son un primer balance jugable, no progresión definitiva.

| Arma | Cadena ligera | Cadena pesada terrestre | Daño ligero por golpe | Daño pesado |
| --- | --- | --- | --- | --- |
| Unarmed | 3 golpes originales + 2 patadas de mayor alcance | 3 patadas con stagger | 1 / 1 / 2 / 2 / 2 | 2 / 2 / 3 |
| Espada | 4 cortes; remate con stagger | Estocada, seguida de ráfaga de 3 cortes | 2 / 2 / 2 / 3 | 3; luego 2 × 3 |
| Hacha de guerra | 2 swings; giro final de 2 vueltas que golpea ambos lados | Descendente cargable | 3 / 3 / 3 × 2 | 5–10 |
| Martillo | 2 golpes amplios, segundo en área | Descendente cargable en área con stun | 5 / 6 | 7–14 |
| Lanza / Guja | Estocada, 2 cortes y giro a ambos lados | Embestida cargable; siguiente pulsación gira a ambos lados | 2 / 2 / 2 / 3 | 4–8 / 3 |

Para resolver la diferencia entre las dos descripciones iniciales de Unarmed se implementó la primera: **cinco ligeros**, manteniendo las tres poses y geometrías existentes, y añadiendo dos patadas. Los tiempos ahora se dividen en las tres fases descritas a continuación. La propuesta alternativa de cuatro ligeros no está activa.

La carga alcanza el máximo en 0,85 s; se mantiene hasta soltar. Aumenta daño, alcance y empuje; la guja también aumenta la velocidad de embestida. El martillo tiene superarmadura durante sus ataques: recibe daño, pero no pierde el ataque por hitstun. No concede invulnerabilidad.

Cada pulso de un giro o ráfaga puede golpear una vez a cada enemigo. El alcance y la cobertura frontal o bilateral corresponden al ataque. Las paredes bloquean el daño, y la embestida usa las colisiones del jugador. `H` permite ver las hitboxes.

Los sprites de armas son SVG propios con siluetas distintas. Las poses corporales se reutilizan de las animaciones actuales; aún no hay animaciones específicas de patadas ni de todos los strings. El estado de arma y la carga se muestran en pantalla.

## Startup, fase activa y recuperación

Las cadenas ligeras y heavy de las cinco armas usan tres fases explícitas, también cuando se ejecutan en el aire. Los valores se expresan en frames de referencia a **60 Hz**, pero se ejecutan en segundos y escalan juntos con `attack_speed_multiplier`. Cada tripleta representa **startup / active / recovery**; cada columna enumera los golpes de la cadena en orden.

| Arma | Ligeros (S / A / R) | Heavy (S / A / R) |
| --- | --- | --- |
| Unarmed | 2/3/5 · 2/3/5 · 3/4/6 · 3/4/7 · 4/5/8 | 4/5/6 · 4/5/7 · 5/6/8 |
| Espada | 4/5/5 · 4/5/5 · 4/6/5 · 5/7/8 | 6/7/9 · 6/18/13 |
| Hacha | 6/4/11 · 7/4/12 · 8/12/26 | 9/6/20 |
| Martillo | 8/5/19 · 9/6/24 | 11/7/29 |
| Lanza / Guja | 4/5/5 · 4/6/5 · 4/6/5 · 5/10/10 | 7/8/13 · 6/10/13 |

Startup anticipa sin daño; active habilita los impactos; recovery conserva la acción ocupada sin infligir daño. El buffer de ligero/heavy espera a terminar recovery antes de comenzar el startup del siguiente golpe. El último golpe incluye toda su recuperación en la tabla, sin el cooldown adicional anterior de 0,12 s. Las cancelaciones defensivas existentes, como parry, siguen disponibles; dash continúa bloqueado mientras el ataque está ocupado.

Unarmed tiene anticipaciones breves y ventanas cortas; sus patadas heavy añaden tiempo en las tres fases. Espada es la referencia y guja mantiene un ritmo próximo con mayor alcance. Hacha y martillo tienen swings breves y concentran su peso en recovery. Los giros dobles del hacha y la ráfaga de espada reparten sus dos/tres pulsos dentro de active, una vez por objetivo y pulso. Un tick largo comprueba todos los intervalos atravesados.

El recovery de cualquier ligero (strings de arma y ataques en carrera, en su segunda mitad y su lag) se cancela en un pesado; un pesado pulsado antes espera en cola y sale al empezar el recovery.

La carga mantenida hace de startup: al soltar se descuenta del startup el tiempo ya cargado, así que una carga completa golpea al instante y un toque conserva su anticipación. Cargar en el suelo frena con polvo y derrape y corta la carrera; al terminar el golpe, manteniendo RT se sale corriendo hacia el lado que se mantenga, sin frenada de giro. Las poses existentes siguen el reloj de combate y las estelas se muestran durante active. Daño, alcance y reglas de suspensión aérea siguen usando los perfiles existentes. Uppercut, screw, ataques de carrera, dive y Liquid Beast conservan su sistema actual.

Regresión específica: `tests/integration/test_attack_phases.gd` comprueba daño por fase en los 27 golpes, límites temporales, pulsos, carga, velocidad, cancelación, poses y buffer por input: 180/180. La revisión completa de integración y herramientas pasó 1304/1304; detalle en `attack_phases_validation.json`.

## Presentación de las armas

Sprites en pixel art (fase 2) generados desde los bocetos con `tools/art/weapon_art.py` (siluetas + ComfyUI); el punto de agarre de cada arma está en `weapon_catalog.gd` (`GRIP`). Los SVG anteriores se conservan.

Los tajos de los strings alternan descendente y ascendente (el segundo del martillo sube); los golpes pesados únicos bajan. Los giros (hacha y guja) son horizontales: el arma orbita en una elipse, se acorta de canto, pasa por detrás del cuerpo y deja una estela más tenue detrás. La ráfaga del segundo heavy de la espada muestra tres estocadas a distintas alturas con destello y sonido de estocada. Capturas: `tools/art/capture_weapon_feel.gd` (carpeta en `CAPTURE_DIR`).

## Wrath of Nature

Pulsar heavy durante el avance frena gradualmente (desliza ~140 px) y ejecuta ahí los Rubies capturados. Si choca con una pared, durante el avance o la frenada, el peso lo devuelve varios metros (~150 px) antes de romperlos. Desde el suelo no se puede apuntar hacia abajo (abajo-adelante, abajo, abajo-atrás) ni hacia atrás; en el aire sí.

## Enemigos y gauntlet

Perseguidor, escudero y halcón usan sprites de autómatas (`assets/sprites/enemies/`, de `tools/art/enemy_art.py`) montados por `enemy_skin.gd` sobre sus polígonos: hitboxes, brazos y animaciones no cambian y el sprite copia el tinte de golpe y aviso. El gauntlet suma una torre trepable a la izquierda y semipisos alternados en las dos paredes con escalones para subir. El rugido de la pose (`growl`) ya no tiene notas graves.

## Liquid Beast y enemigos

La transformación dura indefinidamente. Hay 0,45 s de cooldown entre cambios de forma. Mantener ligero produce aliento jade continuo; los heavies, el dive y el uppercut pueden ejecutar núcleos OPEN o DYING. Se puede dashear y correr manteniendo RT: como Viridy, basta mantener RT para seguir corriendo y el stick solo elige el lado; salta normal, sin salto largo, flips ni wallride. En el uppercut la bestia apunta hacia arriba. Al transformarse se abalanza al instante como un heavy: adelante por defecto, arriba con arriba y abajo con abajo (en el aire). Bunnyhop: saltar justo al aterrizar corriendo suma la misma velocidad que el de Viridy. Aspecto: cabeza de león espiritual con melena de fuego verde (`viridy_beast_head.png`, de `tools/art/beast_head_art.py` sobre el boceto del usuario); el cuerpo serpentino es un VFX que sigue a la cabeza (`beast_trail.gd`) y la cabeza se inclina al subir y al caer. El aliento jade tiene su sonido en bucle, muy bajo (`fire_breath`). No tiene parry ni guardia, y Aim queda inactivo. Al salir de una ejecución rebota sin flip ni impulso extra de carrera.

- **OPEN:** el parry abre a un enemigo pequeño durante 2 s. Si no se ejecuta, vuelve al combate. Tener poca vida ya no produce OPEN.
- **DYING:** un enemigo pequeño a 0 de vida queda inactivo y ejecutable durante 4 s. Cada golpe le resta 1,4 s (al tercero explota), así que ejecutarlo exige no machacarlo. Después explota su ruby y muere. Ejecutarlo antes resuelve la baja y conserva la recompensa de ejecución.
- **Stagger:** interrumpe el ataque y aturde; no abre el ruby.
- Solo Liquid Beast reclama rubies para ejecutar. El uppercut de Viridy y el recall no ejecutan. Wrath conserva su excepción de capturar enemigos con vida, pero requiere Liquid Beast para reclamar sus núcleos.
- Los jefes conservan postura, críticos y ventana final existentes; también requieren Liquid Beast para la captura.

El arma arrojada mantiene su marca jade y DoT no letal de hasta 2 s. En el regreso golpea y atrae a todos los enemigos atravesados, ordenados por contacto: 100 %, 70 %, 49 %… del daño de recall, redondeado a entero y con mínimo de 1. Un enemigo no recibe impactos repetidos en el mismo regreso. No hay teleejecución mediante recall.

## Dónde probar

**Level Testing → Santuario:** cinco pedestales en la orilla oeste (hacia la izquierda desde el Árbol Madre), incluyendo uno para volver a Unarmed. No añade progresión ni salida del santuario.

**Gauntlet:** empieza en preparación, con los cinco pedestales y un portal azul. Cruzarlo retira los pedestales, inicia el reloj y la primera oleada. Las siguientes rondas mantienen sus portales habituales.

La base del personaje expone `max_health`, `damage_multiplier` y `attack_speed_multiplier` para futuras mejoras. Esta entrega no implementa todavía economía de rubies, persistencia de mejoras, mapa procedural ni armas de fuego.

## Validación

- `test_roguelite_combat.gd`: cadenas por inputs, carga, superarmadura, suspensión aérea, Aim, formas, OPEN/DYING y preparación del gauntlet.
- `test_weapon_interactions.gd`: orden y daño decreciente del recall, cobertura contra paredes, embestida, ejecución por colisión real de los cuatro enemigos pequeños y controles del mando.
- Suites previas actualizadas para aperturas explícitas, equipamiento elegido en fixtures y selección inicial del gauntlet.
- Capturas con renderer: `tools/art/capture_roguelite_combat.gd`; archivos en `runtime/`.
- Resultados de la revisión en `validation.json`.

## Ejecutables

Exportados con Godot 4.2.2 para Windows (`builds/windows/Ruby1.exe`) y Linux (`builds/linux/Ruby1.x86_64`). Tamaños y SHA-256 en `builds.json`. Ambos ejecutables arrancaron las nueve escenas de menú, Level Testing, Santuario y modos de juego desde su PCK embebido, con datos temporales y sin errores de scripts. Linux (headless): 9/9 con código 0. Windows (OpenGL Compatibility y headless): las nueve corrieron sus 300 frames sin errores, pero lanzado desde WSL el proceso devuelve código 1, también con el build del commit anterior; no se pudo confirmar la carga de cada escena desde el log de un build release. Detalle en `native_smoke.json`. Los binarios permanecen en `builds/`, ignorado por Git.

## Acciones comunes por arma

Dash attack, screw, uppercut y dive usan perfiles de `weapon_catalog.gd` (COMMON).
Desarmado mantiene su base. Espada y guja conservan las trayectorias y agregan
un segundo pulso de 1 de daño a dash, screw y uppercut; dive tiene +1 de daño
y conserva el rebote. Cada pulso puede golpear una vez a cada objetivo.
Guja escala el área a 1,6; espada conserva el área base.
Hacha añade 2 de daño por impacto, área ×1,25 y 0,4 s de stagger;
martillo añade 4, área ×1,35 y 0,7 s de stagger, con superarmadura.
Hacha reproduce las acciones temporizadas a velocidad ×0,8 y martillo a ×0,65;
sus cooldowns se alargan en la misma proporción. Las reglas de cancelación se conservan.

El ataque pesado aéreo de hacha/martillo arrastra enemigos pequeños y no rebota.
Al aterrizar hace una explosión de 6/10 de daño base, respectivamente, con
0,8/1,4 s de stagger y cobertura horizontal de 260/340 px. Las paredes bloquean
el daño. Cancelar, recibir una interrupción, cambiar arma, reaparecer o salir
libera los objetivos. Los jefes reciben daño pero no se arrastran.
Liquid Beast conserva sus ataques y ejecuciones propios.

LT mantiene Aim; RB lanza/recupera en Aim. X queda para ataque ligero.
Con ratón se mantiene clic central y se lanza con clic izquierdo.
Cámara lenta queda sin asignación por defecto en el mando.
Estos valores son un primer balance para probar, sin implementar aún procs.

| Arma | Dash attack | Screw | Uppercut | Dive (contacto + aterrizaje) | Velocidad de acciones temporizadas |
| --- | --- | --- | --- | --- | --- |
| Desarmado | 3 | 2 | 3 | 2, rebota | 1 |
| Espada | 3 + 1 | 2 + 1 | 3 + 1 | 3, rebota | 1 |
| Hacha | 5 | 4 | 5 | 4 + AoE 6 | 0,8 |
| Martillo | 7 | 6 | 7 | 6 + AoE 10 | 0,65 |
| Guja | 3 + 1 | 2 + 1 | 3 + 1 | 3, rebota | 1 |

Daños nominales sin Ferocity, riposte ni mejoras. Los pulsos adicionales solo
conectan si el enemigo sigue dentro del área cuando ocurre el segundo impacto.
