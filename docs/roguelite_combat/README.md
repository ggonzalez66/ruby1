# Base de combate roguelite

Implementación inicial: Viridy empieza **desarmado**. Las armas cambian ligeros y heavies terrestres; uppercut, dash attack, screw y heavy aéreo conservan sus entradas y movimiento. Los ligeros también encadenan en el aire, con suspensión durante el string y un impulso al conectar.

## Controles

| Acción | Mando por defecto | Teclado/ratón por defecto |
| --- | --- | --- |
| Equipar arma suspendida | Arriba, cerca del pedestal | W / ↑ |
| Ligero | X | Clic izquierdo |
| Heavy; mantener para cargar cuando corresponde | Y | Clic derecho |
| Uppercut | Arriba + Y | W / ↑ + clic derecho |
| Aim | Mantener LT | Mantener clic central |
| Apuntar en Aim | Stick derecho | Ratón |
| Lanzar / recuperar arma | X mientras se mantiene LT | Clic izquierdo durante Aim |
| Liquid Beast | B | Q |
| Parry / guardia | LB | Tab |
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

Para resolver la diferencia entre las dos descripciones iniciales de Unarmed se implementó la primera: **cinco ligeros**, manteniendo las tres poses, geometrías y duraciones existentes (0,16 / 0,16 / 0,22 s), y añadiendo dos patadas. La propuesta alternativa de cuatro ligeros no está activa.

La carga alcanza el máximo en 0,85 s; se mantiene hasta soltar. Aumenta daño, alcance y empuje; la guja también aumenta la velocidad de embestida. El martillo tiene superarmadura durante sus ataques: recibe daño, pero no pierde el ataque por hitstun. No concede invulnerabilidad.

Cada pulso de un giro o ráfaga puede golpear una vez a cada enemigo. El alcance y la cobertura frontal o bilateral corresponden al ataque. Las paredes bloquean el daño, y la embestida usa las colisiones del jugador. `H` permite ver las hitboxes.

Los sprites de armas son SVG propios con siluetas distintas. Las poses corporales se reutilizan de las animaciones actuales; aún no hay animaciones específicas de patadas ni de todos los strings. El estado de arma y la carga se muestran en pantalla.

## Liquid Beast y enemigos

La transformación dura indefinidamente. Hay 0,45 s de cooldown entre cambios de forma. Mantener ligero produce aliento jade continuo; los heavies y el dive conservan las mordidas existentes y pueden ejecutar. Se puede correr, dashear y parrear. Aim queda inactivo.

- **OPEN:** el parry abre a un enemigo pequeño durante 2 s. Si no se ejecuta, vuelve al combate. Tener poca vida ya no produce OPEN.
- **DYING:** un enemigo pequeño a 0 de vida queda inactivo y ejecutable durante 4 s. Después explota su ruby y muere. Ejecutarlo antes resuelve la baja y conserva la recompensa de ejecución.
- **Stagger:** interrumpe el ataque y aturde; no abre el ruby.
- Solo Liquid Beast reclama rubies para ejecutar. El uppercut común y el recall no ejecutan. Wrath conserva su excepción de capturar enemigos con vida, pero requiere Liquid Beast para reclamar sus núcleos.
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

Exportados con Godot 4.2.2 para Windows (`builds/windows/Ruby1.exe`) y Linux (`builds/linux/Ruby1.x86_64`). Tamaños y SHA-256 en `builds.json`. Ambos ejecutables arrancaron las nueve escenas de menú, Level Testing, Santuario y modos de juego desde su PCK embebido, con datos temporales: 18/18 arranques correctos, sin errores de scripts. Además, la suite del Santuario pasó 25/25 checks sobre el ejecutable nativo de Windows con OpenGL Compatibility. Detalle y avisos de cierre en `native_smoke.json`. Los binarios permanecen en `builds/`, ignorado por Git.
