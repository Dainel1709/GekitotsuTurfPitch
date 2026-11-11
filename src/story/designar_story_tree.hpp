#ifndef DESIGNAR_STORY_TREE_HPP
#define DESIGNAR_STORY_TREE_HPP

#include <string>
#include <memory>
#include <vector>
#include <functional>
#include "story_tree.hpp"

// Enlace conceptual con la biblioteca DeSiGNAR (R3mmurd/DeSiGNAR)
// Si se incluye la cabecera oficial de DeSiGNAR: #include <avltree.hpp> o <graph.hpp>
namespace Designar {
    // Prototipo de nodo binario acorde a la arquitectura BaseBinTreeNode de DeSiGNAR
    template <typename T>
    struct DecisionTreeNode {
        T data;
        DecisionTreeNode* left = nullptr;   // Rama: Disciplina Deportiva (El Club)
        DecisionTreeNode* right = nullptr;  // Rama: Reputación en el Asfalto (La Calle)

        explicit DecisionTreeNode(T val) : data(std::move(val)) {}
        
        [[nodiscard]] bool is_leaf() const noexcept {
            return left == nullptr && right == nullptr;
        }
    };
}

namespace gtp {

/**
 * @brief Datos contenidos en cada hito del árbol de decisiones de DeSiGNAR.
 */
struct NarrativeDilemma {
    std::string id;
    std::string title;
    std::string prompt;
    
    // Opciones asociadas a la bifurcación
    std::string discipline_option_text;
    StatModifier discipline_impact;

    std::string street_option_text;
    StatModifier street_impact;

    // Desenlace en caso de ser nodo hoja (Final a los 18 años)
    std::string ending_summary;
};

/**
 * @brief Árbol Narrativo de Decisiones de DeSiGNAR para Gekitotsu Turf Pitch.
 * Gestiona el recorrido desde el debut juvenil (raíz) hasta los 4 desenlaces posibles.
 */
class DeSiGNARStoryTree {
public:
    using Node = Designar::DecisionTreeNode<NarrativeDilemma>;

private:
    Node* root = nullptr;
    Node* current = nullptr;
    PlayerStats stats;

    void free_subtree(Node* node) {
        if (!node) return;
        free_subtree(node->left);
        free_subtree(node->right);
        delete node;
    }

public:
    DeSiGNARStoryTree() {
        build_default_career_tree();
    }

    ~DeSiGNARStoryTree() {
        free_subtree(root);
    }

    /**
     * @brief Construye la jerarquía completa del árbol de decisiones.
     * Nivel 1: El Dilema Inicial (Día 1)
     * Nivel 2: Bifurcación Cantera vs. Pandilla
     * Nivel 3: Nodos Hoja con los 4 Finales Sorpresa a los 18 años
     */
    void build_default_career_tree() {
        // --- Nivel 0: Raíz (Inicio de carrera) ---
        root = new Node({
            "DAY_01",
            "La Encrucijada de la Cantera",
            "Has sido admitido en las pruebas del club juvenil, pero esta noche hay una carrera clandestina que paga el alquiler familiar.",
            "Quedarte a descansar para el entrenamiento de mañana (+Disciplina, -Dinero)",
            StatModifier(+15, -5, 0, +20, 0),
            "Asistir a la carrera clandestina (+Reputación, +Dinero, -Energía)",
            StatModifier(-10, +20, +5, -30, +500),
            ""
        });

        // --- Nivel 1: Subárbol Izquierdo (Ruta Profesional / Disciplina) ---
        root->left = new Node({
            "PRO_STAGE_01",
            "La Titularidad en Juego",
            "El director técnico nota tu esfuerzo y te ofrece la banda de capitán si dejas de frecuentar el barrio.",
            "Firmar compromiso de exclusividad con el club",
            StatModifier(+25, -15, 0, +10, +1000),
            "Rechazar el contrato para no olvidar tus raíces urbanas",
            StatModifier(-10, +15, +10, -10, 0),
            ""
        });

        // --- Nivel 1: Subárbol Derecho (Ruta Asfalto / Calle) ---
        root->right = new Node({
            "STREET_STAGE_01",
            "El Ajuste de Cuentas",
            "Un líder local te desafía a una pelea 1v1 tras ganar dinero en su zona de apuestas.",
            "Huir al estadio para buscar refugio con tus compañeros",
            StatModifier(+10, -20, 0, -20, 0),
            "Aceptar el combate en el callejón",
            StatModifier(-25, +30, +25, -40, +1500),
            ""
        });

        // --- Nivel 2 (Finales Sorpresa): Hojas de la Rama Disciplinada ---
        // Hoja Izquierda-Izquierda: Balón de Oro / Élite
        root->left->left = new Node({
            "ENDING_PRO_LEGEND",
            "Final 1: El Prodigio de la Élite",
            "Cumples 18 años firmando con el primer equipo profesional.",
            "", StatModifier(), "", StatModifier(),
            "Has alcanzado el estrellato internacional con disciplina inquebrantable."
        });

        // Hoja Izquierda-Derecha: El Gladiador del Césped
        root->left->right = new Node({
            "ENDING_PITCH_GLADIATOR",
            "Final 2: El Gladiador del Césped",
            "Jugador estrella y capitán, pero temido por tu agresividad y pasado urbano.",
            "", StatModifier(), "", StatModifier(),
            "Idolatrado por la afición humilde, temido por los rivales dentro del campo."
        });

        // --- Nivel 2 (Finales Sorpresa): Hojas de la Rama Callejera ---
        // Hoja Derecha-Izquierda: El Juguete Roto
        root->right->left = new Node({
            "ENDING_BROKEN_DREAM",
            "Final 3: El Sueño Truncado",
            "El club te expulsa por indisciplina y tus deudas te consumen.",
            "", StatModifier(), "", StatModifier(),
            "Un talento desperdiciado que terminó como leyenda urbana de barrio."
        });

        // Hoja Derecha-Derecha: El Capo del Asfalto
        root->right->right = new Node({
            "ENDING_STREET_KINGPIN",
            "Final 4: El Rey del Asfalto",
            "Dominas los circuitos de carreras y combates clandestinos de la ciudad.",
            "", StatModifier(), "", StatModifier(),
            "Cambiaste los tacos de fútbol por el control total de las apuestas nocturnas."
        });

        current = root;
    }

    [[nodiscard]] Node* get_current_node() const noexcept {
        return current;
    }

    [[nodiscard]] const PlayerStats& get_player_stats() const noexcept {
        return stats;
    }

    /**
     * @brief Avanza por la rama izquierda (Disciplina Deportiva / El Club).
     */
    bool choose_discipline() {
        if (!current || !current->left) return false;
        stats.sports_discipline += current->data.discipline_impact.sports_discipline;
        stats.street_reputation += current->data.discipline_impact.street_reputation;
        stats.combat_technique += current->data.discipline_impact.combat_technique;
        stats.energy += current->data.discipline_impact.energy;
        stats.money += current->data.discipline_impact.money;
        stats.current_day++;
        current = current->left;
        return true;
    }

    /**
     * @brief Avanza por la rama derecha (Reputación Callejera / El Asfalto).
     */
    bool choose_street() {
        if (!current || !current->right) return false;
        stats.sports_discipline += current->data.street_impact.sports_discipline;
        stats.street_reputation += current->data.street_impact.street_reputation;
        stats.combat_technique += current->data.street_impact.combat_technique;
        stats.energy += current->data.street_impact.energy;
        stats.money += current->data.street_impact.money;
        stats.current_day++;
        current = current->right;
        return true;
    }

    [[nodiscard]] bool is_career_over() const noexcept {
        return current != nullptr && current->is_leaf();
    }
};

} // namespace gtp

#endif // DESIGNAR_STORY_TREE_HPP
