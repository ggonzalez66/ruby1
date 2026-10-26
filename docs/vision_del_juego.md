# Ruby1: visión del juego, historia y estructura roguelike

Este documento recoge la visión definida por el creador del juego. Establece el género, el mundo, la historia completa, el significado de una run y sus dos finales. Describe el diseño objetivo de Ruby1; no implica que todos estos sistemas estén implementados en el prototipo.

Las cuestiones que todavía necesitan una decisión se enumeran al final. Las propuestas de la conversación que no fueron confirmadas no se consideran reglas definitivas.

## 1. Tipo de juego

Ruby1 será un **roguelike de acción y plataformas 2D para un jugador**, centrado en el combate frenético, la movilidad, el dominio de sus mecánicas y la construcción de capacidades durante cada run.

El jugador controla a Viridy, un espíritu de la naturaleza con forma de león verde alquímico. Parte del santuario del Árbol Madre y elige cómo avanzar por un mapa de territorios hexagonales hacia la Ciudad Negra. Las rutas, los encuentros, las armas, las mejoras y las combinaciones de enemigos permiten que cada expedición sea diferente.

La historia tiene un destino definido, pero alcanzarlo y completar su desenlace exige superar una run. Llegar al poder supremo abre una última elección: conservar ese poder como regente o arriesgarlo todo para regresar al hogar y entregar la propia existencia.

### Pilares de la experiencia

- **Combate y movimiento expresivos:** acción rápida, acrobacias, combinaciones de ataques y medidor de estilo. La habilidad del jugador debe tener un papel central.
- **Expediciones variables:** elección de arma inicial, rutas, mejoras y oportunidades diferentes durante cada intento.
- **Recuperación de la naturaleza:** liberar territorios y enfrentarse a la expansión de las máquinas forma parte del recorrido de la run.
- **Absorción de rubies:** obtener vida, capacidades y, en casos concretos, habilidades de enemigos o jefes mediante sus núcleos.
- **Contraste visual y ambiental:** entornos naturales bellos, exuberantes y vivos frente a la ocupación industrial, la tecnología y la corrupción de la Ciudad Negra.
- **Una culminación exigente:** los combates finales, el ascenso de movilidad y la posibilidad de regresar transformado constituyen desafíos distintos dentro de una misma expedición.
- **Rejugabilidad y speedrun:** las rutas y combinaciones variables conviven con el interés por completar los recorridos y finales cada vez más rápido.

## 2. El mundo

### El Árbol Madre y el santuario

Un árbol gigantesco constituye el corazón de la naturaleza. Su santuario es un paraíso de agua, vegetación, fauna y megafauna. Es el hogar de Viridy y el hub desde el que comienza las expediciones.

El árbol se comunica espiritualmente con Viridy desde el principio. Esa presencia establece una relación entre el protagonista, su origen y la vida que debe proteger.

Viridy es su **último fruto** y la última esperanza de detener la expansión de la Ciudad Negra.

### La Ciudad Negra

En el extremo opuesto se encuentra la Ciudad Negra, corazón de la tecnología y la corrupción. Su civilización está compuesta por máquinas e inteligencias artificiales. La humanidad ya no existe; algunos androides todavía creen ser humanos, aunque son IAs.

La ciudad busca ocupar todo el espacio de la naturaleza. Sus máquinas arrasan terrenos, flora y fauna para expandirse y producir rubies. Las rutas negras que parten de ella alcanzan progresivamente los territorios cercanos al santuario.

La oposición entre naturaleza y tecnología debe distinguirse tanto en los paisajes como en los habitantes, los enemigos y las transformaciones del terreno. También existen territorios gobernados por híbridos de animal y máquina.

### Los rubies

Los rubies son núcleos de energía inspirados en las piedras filosofales de *Fullmetal Alchemist*. Su secreto es que contienen la fuerza vital de seres que alguna vez estuvieron vivos: almas.

La energía que alimenta a la civilización mecánica procede, por tanto, de la vida que destruye para producir esos núcleos.

Viridy puede absorber rubies en su propio cuerpo. Esa absorción aumenta su vida o sus capacidades y, en casos específicos, permite obtener habilidades de los enemigos, especialmente de jefes.

Se contempla una colección de rubies identificados mediante números, como `Ruby389` o `Ruby444`, asociados a enemigos o jefes encontrados durante las runs. El alcance de ese registro y su persistencia todavía deben concretarse.

### La Torre, la Corona y el sol

En el corazón de la Ciudad Negra se levanta la Torre. En su cima se encuentra la Corona, donde se experimenta con el sol para absorber su poder.

El proyecto opaca la luz natural del planeta mientras las máquinas producen su propia luz artificial. Alcanzar la Torre y destruir el dispositivo que roba el sol es el objetivo de la expedición de Viridy.

### La leyenda del Ruby1

El Ruby1 es el ruby original, el primero, el primordial. Todos lo desean, pero nadie conoce con certeza cuál es ni dónde se encuentra. La sospecha de que está en el sol impulsa los experimentos de la Ciudad Negra.

Esa búsqueda también obsesiona al Caballero del Falso Sol, protector del proyecto de la Corona.

## 3. Viridy y su transformación

Viridy es una bestia feroz nacida de la naturaleza, un espíritu y el último fruto del Árbol Madre. Su identidad como león verde está inspirada en la alquimia.

Sus poderes son disolutivos: puede disolver el metal de las máquinas y absorber los rubies que contienen. Su crecimiento durante una run vincula directamente la progresión del combate con el secreto de esos núcleos.

Su recorrido culmina en tres figuras leoninas:

| Figura | Papel en la historia |
| --- | --- |
| **Viridy, el León Verde** | El protagonista nacido de la naturaleza, feroz y dotado de poderes disolutivos. |
| **El León Albo** | La perfección encarnada, encontrada en el interior del sol; rival y posterior compañero de Viridy. |
| **El León Rojo o León de Ruby** | La obra final, nacida de la fusión de ambos leones con el Ruby1. |

Estas figuras forman parte de la culminación narrativa. No se ha establecido que el León Rojo se conserve como personaje inicial en expediciones posteriores.

## 4. Qué significa una run

Una run es una expedición desde el santuario del Árbol Madre hacia la Ciudad Negra, la Torre y el interior del sol. Puede terminar en fracaso, en la elección de conservar el poder obtenido o en el regreso y sacrificio que restaura el origen.

### Preparación y elección de ruta

Cada intento comienza en el santuario. El jugador elige un arma inicial y consulta un mapa de territorios hexagonales. En él se observan las rutas negras trazadas desde la Ciudad Negra hacia la naturaleza y se decide por cuál avanzar.

Las rutas ofrecen diferentes combinaciones de biomas, terrenos, enemigos, mejoras y jefes. También puede haber territorios verdes que beneficien la expedición.

### Avance, combate y recuperación de territorios

Durante la run, Viridy combate contra las máquinas, absorbe rubies, desarrolla sus capacidades y recupera los territorios que consigue liberar. Las decisiones de ruta permiten buscar oportunidades, asumir riesgos o intentar llegar más rápido a la ciudad.

La variedad prevista incluye:

- Diferentes armas iniciales y mejoras obtenidas durante la expedición.
- Enemigos y jefes mecánicos que la Ciudad Negra puede volver a producir. Encontrar otra unidad no implica resucitar exactamente a la que fue destruida y absorbida antes.
- Variantes élite de jefes mecánicos y jefes especiales asociados a determinadas zonas.
- Territorios gobernados por híbridos de animal y máquina.
- Territorios naturales todavía libres de las máquinas, pero habitados por bestias temibles. Vencer a algunas de estas bestias puede permitir domesticarlas y obtener su ayuda mediante invocaciones en las zonas finales.

El contraste entre los territorios y sus habitantes debe aportar variedad reconocible. La entrada en la Ciudad Negra representa un cambio de ambiente y una subida de exigencia, con máquinas más fuertes.

### Fracaso y reconstrucción

Si Viridy muere, se deshace como espíritu de la naturaleza. Se plantea que los rubies que alcanzó a reunir retornen al árbol, haciendo posible vincular el fracaso de la expedición con el regreso a su origen.

Los territorios recuperados durante el intento se pierden al resetear la run. Su conquista no se considera una liberación permanente del mapa entre expediciones.

La selección exacta de recursos, mejoras, desbloqueos o registros que persisten entre intentos todavía no está fijada. El retorno de los rubies al árbol no establece por sí solo que Viridy conserve todos sus poderes o que todos esos rubies se conviertan en una moneda permanente.

También está pendiente resolver cómo funciona el regreso tras un fracaso ocurrido después de la muerte del Árbol Madre. La muerte del árbol al entrar en la ciudad forma parte de la historia; su relación con los siguientes intentos necesita una regla específica.

### Victoria y riesgo final

Alcanzar al León Rojo abre una decisión de cierre. El jugador puede conservar su estado supremo y convertirse en regente, o intentar regresar al árbol para restaurarlo mediante su sacrificio.

Durante el regreso, Viridy mantiene un poder extraordinario, pero todavía puede morir. También puede recuperar territorios que no logró conquistar durante la ida. Completar esa vuelta exige un dominio adicional y constituye el desenlace más exigente del recorrido propuesto.

Morir durante el ascenso o el regreso es un fracaso de la expedición, no un tercer final narrativo. Las reglas concretas de reinicio y recuperación de esos tramos quedan por definir.

## 5. Historia completa

### El último fruto

En un mundo donde la humanidad ya desapareció, la Ciudad Negra extiende sus máquinas sobre los espacios naturales. Bosques, animales y otros seres vivos son arrasados para alimentar una civilización artificial mediante los rubies, núcleos que ocultan en su interior las almas de la vida consumida.

El gran Árbol Madre, corazón de la naturaleza, da origen a Viridy, su último fruto. Este espíritu con forma de león verde es su última esperanza para detener la expansión de la ciudad. El árbol lo acompaña mediante una comunicación espiritual desde el comienzo de su recorrido.

Viridy posee la capacidad de disolver el metal de las máquinas y absorber sus rubies. A medida que combate y se abre camino, esa absorción aumenta su vida y sus capacidades; ciertos enemigos y jefes también pueden entregarle habilidades particulares.

### Desde la jungla hasta la ciudad

Viridy parte del santuario y avanza desde la jungla hacia los campos dominados por las máquinas. Elige rutas, libera territorios, se enfrenta a diferentes formas de ocupación y puede obtener la ayuda de bestias naturales que haya vencido y domesticado.

La dirección de su viaje conduce a la Ciudad Negra. Allí se concentra el poder que amenaza con ocupar toda la naturaleza. Al entrar en la ciudad, el Árbol Madre muere y se corta su comunicación con Viridy.

Viridy continúa hacia la Torre, situada en el corazón de la ciudad, y asciende hasta la Corona. En ese lugar, las máquinas experimentan con el sol para apropiarse de su energía, oscureciendo la luz natural del planeta y sustituyéndola por iluminación artificial.

### El Caballero del Falso Sol

El guardián de ese proyecto es el Caballero del Falso Sol. Está obsesionado con la leyenda del Ruby1, el núcleo primordial que todos desean y que se sospecha oculto en el sol.

Cuando conoce la capacidad de Viridy para disolver metal y absorber rubies dentro de su cuerpo, lo convierte en uno de sus objetivos.

Viridy debe derrotar al caballero para superar la protección del proyecto y acceder al interior del sol.

### El León Albo

Dentro del sol, Viridy encuentra al León Albo, su último jefe. El enfrentamiento es un combate de doble o *doppelgänger*: el León Albo representa la perfección encarnada y se muestra claramente superior a Viridy.

Viridy logra vencerlo, pero el resultado del combate conduce a un entendimiento. Ambos reconocen que deben unirse para alcanzar algo mayor.

La culminación pasa entonces del enfrentamiento a la cooperación de ambos leones.

### El ascenso al Ruby1

Tras el combate comienza una secuencia de parkour, movilidad y speedrunning hacia lo más alto. Viridy y el León Albo deben superar obstáculos y enemigos de oscuridad que representan imperfecciones.

El Ruby1 se encuentra en la cima. Alcanzarlo exige completar el ascenso; fracasar significa morir.

Cuando ambos leones llegan al Ruby1, se funden con él en un shinespark final. Tras un destello blanco nace una nueva criatura: el León Rojo, el León de Ruby, la obra final.

Con esa transformación, el sol se libera.

### La elección del poder y el regreso

La obtención del estado supremo abre los dos finales. Viridy puede conservar ese poder como León Regente Supremo, o emprender la vuelta al Árbol Madre.

Si decide regresar, debe recorrer el camino de vuelta en su forma de León Rojo. Es extraordinariamente poderoso, pero todavía puede morir antes de completar su propósito. Durante ese trayecto puede recuperar territorios que quedaron sin liberar.

Al llegar al hogar encuentra el árbol muerto. La voz espiritual que lo acompañó desde el inicio ya no responde.

Viridy se ofrece para sacrificarse dentro de él. Entrega su existencia y, mediante ese acto, devuelve la vida al Árbol Madre y a toda la tierra. La naturaleza vuelve a resurgir.

## 6. Los dos finales

Los nombres siguientes describen los desenlaces; los títulos definitivos de presentación pueden decidirse más adelante.

### Final 1: el León Regente Supremo

Después de alcanzar el Ruby1, transformarse en León Rojo y liberar el sol, el jugador elige conservar el poder obtenido y quedarse como regente supremo.

La run concluye con Viridy en su estado supremo. No completa el regreso sacrificial al Árbol Madre y, por tanto, no consuma mediante ese sacrificio la restauración descrita en el segundo final.

Este final reconoce la capacidad de llegar hasta el Ruby1 y completar la transformación. Los detalles sobre el reinado posterior y el destino político del mundo no están establecidos.

### Final 2: el regreso al origen

Después de alcanzar el Ruby1, transformarse en León Rojo y liberar el sol, el jugador elige arriesgar su victoria e iniciar el camino de regreso.

Debe sobrevivir a la vuelta incluso en ese estado de poder extraordinario. Puede recuperar territorios pendientes antes de llegar al santuario.

En el hogar, el Árbol Madre permanece muerto y en silencio. Viridy entrega su propia existencia dentro de él. El árbol revive y la vida vuelve a toda la tierra.

Este final completa la misión de restaurar la naturaleza y exige superar tanto la ida como el regreso. La criatura que reunió el poder supremo termina devolviéndolo a su origen mediante el sacrificio.

| Aspecto | León Regente Supremo | Regreso al origen |
| --- | --- | --- |
| Alcanzar el Ruby1 y convertirse en León Rojo | Sí | Sí |
| Liberar el sol | Sí | Sí |
| Conservar el poder como regente | Sí | No: entrega su existencia al árbol |
| Completar el regreso con riesgo de morir | No | Sí |
| Revivir al Árbol Madre mediante el sacrificio | No | Sí |
| Restauración final de la naturaleza mediante esa entrega | No se consuma | Sí |

## 7. Referencias creativas declaradas

Estas referencias orientan aspectos concretos del proyecto; no establecen que Ruby1 deba reproducir todos sus sistemas.

- **Alquimia:** el León Verde, el León Albo y el León Rojo; disolución, transformación y obra final.
- **Fullmetal Alchemist:** la inspiración de los rubies como piedras de energía que contienen fuerza vital o almas.
- **Hades:** el santuario como hub, la salida a nuevas expediciones y la elección de un arma inicial.
- **Darkest Dungeon, Inscryption y Star Fox:** referencias para elegir rutas y avanzar entre territorios del mapa.
- **Pixel Dungeon y el Amuleto de Yendor:** referencia para elegir entre cerrar la victoria obtenida o arriesgar una vuelta adicional.
- **Dead Cells:** acción, rejugabilidad, dominio de recorridos y motivación por conseguir tiempos bajos.
- **Risk of Rain 2:** referencia para las variantes élite de enemigos o jefes mecánicos.

## 8. Decisiones todavía abiertas

- Qué recursos, desbloqueos, mejoras y registros se conservan entre runs, y cómo se utilizan los rubies que regresan al árbol.
- Cómo se reconstruye Viridy y cómo funciona el santuario después de un fracaso posterior a la muerte del Árbol Madre. Tampoco está fijado si ese acontecimiento persiste entre intentos o se repite dentro de cada run.
- Si el mapa de regreso conserva exactamente la topología de la ida y cómo cambian sus territorios. Esa continuidad fue propuesta en la conversación, pero todavía no se ha fijado como regla.
- Cómo se eligen y cambian las armas, y qué habilidades obtenidas de jefes pertenecen solo al intento o se desbloquean de manera permanente.
- Cómo se obtienen, invocan y limitan las ayudas de las bestias naturales.
- Cómo funciona el catálogo numerado de rubies y qué significa cada número.
- Las reglas de muerte, checkpoints o reinicio en el tramo final y durante el regreso. La exigencia del desenlace está definida; el sistema concreto de recuperación no.
- Cómo se registran los finales y sus tiempos, y qué continúa o se desbloquea después de completar cualquiera de ellos.
