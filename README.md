# G.T.P. – Gekitotsu Turf Pitch
> *"Impacto en la cancha / Impacto en el terreno: ¿Hasta dónde llegarías cuando el balón ya no es suficiente?"*

[![Godot Engine](https://img.shields.io/badge/Motor-Godot%203.6%20GLES2-blue?logo=godot-engine)](https://godotengine.org/)
[![C++](https://img.shields.io/badge/Rendimiento-C%2B%2B%20(GDNative%20%2F%20GDExtension)-00599C?logo=c%2B%2B)](https://isocpp.org/)
[![Género](https://img.shields.io/badge/Género-RPG%20Deportivo%20%2F%20Arcade-orange)](https://github.com/)
[![Plataforma](https://img.shields.io/badge/Plataforma-PC%20%2F%20PPSSPP%20Style-green)](https://github.com/)

---

## 📌 Resumen del Proyecto
**G.T.P. – Gekitotsu Turf Pitch** es un **RPG Deportivo y de Acción Arcade** que combina fútbol cenital rápido, combate callejero 1 vs 1 y toma de decisiones narrativas. El juego explora la constante tensión entre la disciplina en la cantera de un club profesional y la supervivencia en el asfalto nocturno.

Diseñado con una arquitectura modular y optimizado para **Godot 3.6 (GLES2)** con aceleración nativa en **C++ (GDNative / GDExtension)**:
* **Entorno y Gameplay en Godot:** Gestión ágil de escenas 3D/2D, interfaces de usuario (HUD), animaciones y máquinas de estado en GDScript.
* **Núcleo de Alto Rendimiento en C++:** Cálculo optimizado de físicas arcade de balón, fuerzas de impacto, cálculo de pases y persistencia del árbol narrativo (`FootballMechanics`, `GekitotsuStoryManager`).
* **Compatibilidad Universal:** Optimizado para hardware de especificaciones contenidas mediante el renderizador GLES2 de Godot 3.6.

---

## 🕹️ Modos de Juego y Mecánicas

### 1. Cancha de Fútbol Oficial (40×90m) y Entorno Perimetral
* **Campo Reglamentario:** Dimensiones ampliadas a **40 m de ancho (eje X) por 90 m de largo (eje Z)** con líneas de cal, círculos y áreas calibradas sin z-fighting.
* **Entorno Perimetral Completo:**
  * Base exterior masiva (`StadiumGround`) de **120 × 160 m** que garantiza cero vacíos en los bordes de la pantalla.
  * Pistas de escape perimetrales en los 4 costados (`RunoffNorth`, `RunoffSouth`, `RunoffWest`, `RunoffEast`).
  * Gradas bajas y muros perimetrales de concreto (`StadiumPerimeter`) que enmarcan la cancha.
  * Franja perimetral despejada y nivelada (1.5 a 3.0 m) con nodo contenedor **`AdBoards`** (Spatial) listo para instanciar vallas publicitarias.
* **Cámara Cenital Dinámica (`PitchCamera.gd`):**
  * Perspectiva aérea inclinada (-74° en X) con seguimiento suave e interpolado del foco entre Ryu (jugador) y el balón.
  * *Look-ahead* reactivo hacia porterías en el último tercio de cancha.
  * Zoom dinámico y elevación proporcional a la separación de los actores para mantener siempre la acción encuadrada.
* **Físicas del Balón 2.5D (`FootballBall.gd`):**
  * Simulación física como `RigidBody` con amortiguación vertical para mantener el balón en el césped sin rebotes desmedidos.
  * Sombra proyectada dinámica que se escala y atenúa según la altura.
* **Conducción y Pases:**
  * **Dribbling fluido:** Conducción natural en plano X/Z que orbita al girar 180° sin efecto catapulta.
  * **Autopase largo (*Knock-on*):** Doble pulsación de Sprint (*R / W*) para adelantar el balón y ganar aceleración temporal (+22%).
  * **Pases Asistidos:**
    * Botón $\times$ (Cruz / Z): Pase corto raso asistido hacia compañeros desmarcados.
    * Botón $\bigcirc$ (Círculo / X): Pase bombeado / Centro al área.
    * Botón $\Delta$ (Triángulo / S): Pase en profundidad al hueco con anticipación de desmarque en velocidad.
    * Botón $\square$ (Cuadrado / A): Disparo cargado a puerta con medidor de potencia.
  * **Tiro Especial (*Gekitotsu Shot*):** Al alcanzar el 100% en la barra de Furia, presionar **Gatillo L + Disparo** desata un remate a máxima velocidad (>35 m/s) con destello dorado.
* **Inteligencia Artificial de Partido (`FootballAI.gd`):**
  * **Porteros:** Seguimiento lateral dinámico bajo los tres palos, cobertura de ángulo y despejes con impulso cuando el balón entra en el área de salvada.
  * **Rivales:** Presión activa, robo por contacto físico (*tackle*), conducción orientada hacia la portería sur y remates potentes.
  * **Compañeros Aliados:** Desmarque en bandas, líneas de pase abiertas y ejecución inmediata de pase hacia Ryu al solicitarlo con el botón **L (Q)**.
* **HUD y Cronómetro Oficial (`PitchHUD.gd`):**
  * Partido reglamentario de 90:00 minutos cronometrados (1 segundo real = 30 segundos de juego, total 180 s).
  * Selector de táctica rápida con **SELECT**: *Equilibrado*, *Ofensivo*, *Defensivo*.
  * Marcador de goles, indicador de Furia en tiempo real y menú de pausa (START).

---

### 2. Arena de Combate 1 vs 1 (`FightArena.tscn`)
* **Combate 2D Arcade (*Beat 'em Up*):**
  * Cadena de combo fluido de 6 golpes progresivos con *hitstop* y *hitstun* calibrados.
  * Sistema de bloqueo con mitigación de daño y carga defensiva de Furia.
  * Esquive rápido y contraataques.
  * **Ataque Especial (*Gekitotsu Breaker*):** Golpe devastador al 100% de furia con 520 px/s de empuje (*knockback*).

---

### 3. Calendario Diario y Progresión RPG (`MainGame.tscn`)
* Estructura narrativa inspirada en *Persona* y *New Star Soccer*.
* Toma de decisiones diarias que equilibran:
  * **Disciplina Deportiva:** Aumenta resistencia, reduce el drenaje de estamina al esprintar y mejora el control del balón.
  * **Técnica de Combate:** Incrementa la potencia de tiro, daño de golpes y velocidad de acumulación de Furia.
  * **Dinero y Reputación Callejera:** Desbloquea rutas de supervivencia urbana y define el desenlace de la trayectoria a los 18 años.

---

## 🎮 Controles

El juego ofrece compatibilidad completa con mandos estilo **PPSSPP / Consola** y teclado (excluyendo controles WASD para evitar conflictos de movimiento):

| Acción | Mando PlayStation (PS4/PS5) | Mando Xbox / Estándar | Teclado |
|---|---|---|---|
| **Movimiento** | Cruceta D-Pad / Stick Izquierdo | Cruceta D-Pad / Stick Izquierdo | Flechas Direccionales |
| **Pase Corto / Tackle** | $\times$ (Cruz) | A | Z |
| **Pase en Profundidad** | $\Delta$ (Triángulo) | Y | S |
| **Centro / Disparo\*** | $\square$ (Cuadrado) / $\bigcirc$ (Círculo) | X / B | A / X |
| **Sprint (Correr)** | R1 / R2 | RB / RT | W |
| **Pedir Balón / Control** | L1 / L2 | LB / LT | Q |
| **Tiro Especial** | L1 + Botón de Disparo | LB + Botón de Disparo | Q + Disparo (Furia 100%) |
| **Cambiar Táctica** | SELECT / Share | View / Back | Tab / T |
| **Pausar Partido** | START / Options | Menu / Start | Esc / P / Enter |
| **Frenar Rivales (Test)**| — | — | F (Shift: pulso / normal: toggle) |

*\*Configuración de Disparo y Centro alternable en tiempo real entre esquemas **FIFA Clásico** ($\bigcirc$ Disparo, $\square$ Centro) y **PES Alternativo** ($\square$ Disparo, $\bigcirc$ Centro) a través de `GameSettings.gd`.*

---

## 🛠️ Stack Tecnológico
* **Motor:** Godot Engine 3.6 (soporte estable GLES2 para PC y dispositivos de gama media/baja).
* **Lógica Nativa:** C++17 mediante GDNative / GDExtension (`src/core/`, `src/physics/`).
* **Compilación Nativa:** CMake + MinGW / GCC / MSVC para generar bibliotecas dinámicas (`bin/libgekitotsu.windows.release.x86_64.dll`).
* **Autoload Globales:**
  * `GameSettings.gd`: Detección automática de hardware DualShock 4 / DualSense / Xbox y gestión de esquemas de control.

---

## 📂 Estructura del Repositorio

```text
📦 GekitotsuTurfPitch
 ┣ 📂 assets/              # Modelos 3D, animaciones, texturas y audio
 ┣ 📂 bin/                 # Bibliotecas compiladas C++ y definiciones GDNative (.gdnlib, .dll)
 ┣ 📂 scenes/              # Escenas de Godot
 ┃ ┣ 📜 FootballPitch.tscn # Cancha de fútbol 40x90m con gradas y entorno perimetral
 ┃ ┣ 📜 FootballBall.tscn  # Balón físico arcade con sombra proyectada
 ┃ ┣ 📜 FightArena.tscn    # Arena de combate 1 vs 1 en 2D
 ┃ ┣ 📜 MainGame.tscn      # Hub de decisiones y progresión RPG
 ┃ ┗ 📜 TitleScreen.tscn   # Menú principal con navegación por gamepad
 ┣ 📂 scripts/             # Controladores GDScript
 ┃ ┣ 📂 autoload/          # Scripts singleton (GameSettings.gd)
 ┃ ┣ 📜 FootballAI.gd      # IA de porteros, rivales y compañeros de equipo
 ┃ ┣ 📜 FootballBall.gd    # Comportamiento físico y visual del balón
 ┃ ┣ 📜 GoalArea.gd        # Detección de goles y reposición de actores
 ┃ ┣ 📜 PitchCamera.gd     # Cámara cenital dinámica con interpolación suave
 ┃ ┣ 📜 PitchHUD.gd        # HUD de partido: reloj 90 min, marcador y tácticas
 ┃ ┣ 📜 Player.gd          # Jugador principal (Ryu): controles, dribbling y furia
 ┃ ┗ 📜 Fighter.gd         # Controlador de combate arcade para FightArena
 ┣ 📂 src/                 # Código fuente C++ (físicas, mecánicas y story tree)
 ┣ 📂 tests/               # Suite de tests unitarios automatizados (Godot headless y C++)
 ┣ 📜 project.godot        # Configuración principal del motor Godot 3.6
 ┗ 📜 README.md            # Documentación oficial del proyecto
```

---

## 🧪 Pruebas y Validación Automatizada

El proyecto incluye una suite completa de pruebas unitarias ejecutables en modo *headless* sin interfaz gráfica para validar la estabilidad en pipelines de CI/CD:

```powershell
# Ejecución de tests en Godot 3.6 headless:
godot --no-window --path . -s tests/test_football_ai.gd
godot --no-window --path . -s tests/test_dribble_and_knock_on.gd
godot --no-window --path . -s tests/test_freeze_and_assisted_pass.gd
godot --no-window --path . -s tests/test_game_settings.gd
godot --no-window --path . -s tests/test_fight_arena_load.gd
```

Cada prueba finaliza invocando `get_tree().quit(0)` garantizando un código de retorno limpio tras validar aserciones críticas de físicas, inteligencia artificial, esquemas de control y cálculo de daño.
