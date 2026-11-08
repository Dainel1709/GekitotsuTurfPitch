# G.T.P. – Gekitotsu Pitch
> *"Impacto en la cancha / Impacto en el terreno: ¿Hasta dónde llegarías cuando el balón ya no es suficiente?"*

[![Godot Engine](https://img.shields.io/badge/Motor-Godot-blue?logo=godot-engine)](https://godotengine.org/)
[![C++](https://img.shields.io/badge/Rendimiento-C++%20(GDExtension)-00599C?logo=c%2B%2B)](https://isocpp.org/)
[![Género](https://img.shields.io/badge/Género-RPG%20Deportivo-orange)](https://github.com/)

---

## 📌 Resumen del Proyecto y Enfoque de Evaluación
**G.T.P. – Gekitotsu Pitch** es un **RPG Deportivo** de acción y simulación narrativa que explora la constante tensión entre la disciplina de la élite futbolística y la cruda supervivencia del entorno urbano. 

Este proyecto ha sido diseñado estratégicamente para ser evaluado bajo estrictos criterios de **diseño de jugabilidad, arquitectura modular y eficiencia técnica**:
* **Diseño e Interfaz Ágil:** Se emplea **Godot** para gestionar la interfaz de usuario (UI), menús, transiciones de escenas y el flujo diario del protagonista.
* **Alto Rendimiento en C++:** Para evitar cuellos de botella y garantizar una jugabilidad fluida y precisa, los núcleos pesados del sistema (como el motor de físicas arcade de los vehículos y la detección de colisiones/hitboxes en los combates) están implementados en **C++** mediante **GDExtension**.

---

## 🕹️ Estilo de Juego y Ciclo Diario
El flujo de juego sigue una estructura de calendario diario con gestión de tiempo y energía (inspirada en la toma de decisiones de títulos como *Persona* y la progresión de carrera de *New Star Soccer*). Cada jornada se divide en dos bloques:
1. **El Día (El Club Deportivo):** Entrenamientos y partidos oficiales en la liga juvenil para demostrar la valía deportiva.
2. **La Noche (El Asfalto y la Calle):** Decisiones de tiempo libre y supervivencia urbana que impactan directamente el estado físico, la reputación y las estadísticas del protagonista.

---

## ⚙️ Mecánicas Principales y Referencias
La experiencia de juego se articula en tres pilares mecánicos principales con referentes consagrados en la industria:

* **Modo Liga (Fútbol Arcade y Momentos Críticos):**
  * *Gameplay:* Cámara cenital ágil donde el jugador controla exclusivamente al canterano (*New Star Soccer* y *Sensible Soccer*). El partido avanza rápido hasta activar un **Momento Clave** (mano a mano, tiro libre), ralentizando la acción para ejecutar la jugada decisiva.
  * *Medidor de Furia:* Si las provocaciones rivales llenan la barra, el jugador puede desatar una pelea a puño limpio en pleno césped (tarjeta roja inmediata y sanciones del club).
* **Peleas Callejeras (Combate 1 vs 1):**
  * *Gameplay:* Perspectiva lateral 2D (estilo *Beat 'em up* clásico como *Streets of Rage*) basada en la gestión de estamina: golpes rápidos, ganchos para romper guardia, esquives y contraataques para ganar respeto en el barrio a costa de riesgo físico.
* **Carreras Clandestinas de Autos (Conducción Arcade):**
  * *Gameplay:* Conducción nocturna ágil para conseguir dinero rápido ante la falta de un contrato profesional lucrativo, esquivando tráfico civil y dominando curvas (inspirado en las persecuciones clásicas de los primeros *GTA* o *OutRun*).

---

## 🛠️ Stack Tecnológico y Arquitectura
* **Motor Base:** Godot Engine (para nodos, escenas y gestión de UI mediante GDScript).
* **Núcleo de Optimización:** C++ / GDExtension (para lógica de rendimiento crítico, físicas arcade y persistencia de datos globales).
* **Gestión de Estado (Autoload):** Script global centralizado que rastrea las estadísticas internas del jugador (*Disciplina Deportiva, Técnica de Combate y Reputación en el Asfalto*) para determinar de forma totalmente orgánica uno de los **finales sorpresa** al cumplir los 18 años.

---

## 📂 Estructura del Repositorio
```text
📦 Gekitotsu-Turf-Pitch
 ┣ 📂 bin / src          # Módulos de lógica pesada y optimización en C++ (GDExtension)
 ┣ 📂 res://scenes       # Escenas de Godot (Cancha, Callejón, Pista de Carreras, Menús)
 ┣ 📂 res://scripts      # Controladores de UI, diálogos y flujos en GDScript
 ┗ 📄 README.md          # Documentación oficial del proyecto
