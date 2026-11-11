# Módulo DeSiGNAR (Data Structures GeNeral librARy)

Este directorio está destinado a la integración de la biblioteca **DeSiGNAR** (`R3mmurd/DeSiGNAR`) en C++17.

### Propósito en Gekitotsu Turf Pitch
- **Estructuras de Grafos y Árboles de Decisión:** Representación de ramificaciones narrativas (Disciplina Deportiva vs. Reputación Urbana).
- **Algoritmos y Heurísticas:** Utilidades para IA y gestión de recorridos en grafos de eventos y decisiones.

### Métodos de Integración Recomendados
1. **Submódulo Git (Recomendado):**
   ```bash
   git submodule add https://github.com/R3mmurd/DeSiGNAR.git src/designar/DeSiGNAR
   ```
2. **Archivos de Cabecera (Header-Only):**
   Copiar las cabeceras requeridas de DeSiGNAR directamente en esta carpeta para compilación estática junto a GDExtension.
