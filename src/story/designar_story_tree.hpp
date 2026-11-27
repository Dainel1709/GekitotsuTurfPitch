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

    // Peso dinámico del nodo en el árbol DeSiGNAR (actualizado por rebalance_story_tree)
    int weight = 1;
};

/**
 * @brief Árbol Narrativo de Decisiones de DeSiGNAR para Gekitotsu Turf Pitch.
 * Gestiona el recorrido desde el debut juvenil (raíz) hasta los 4 desenlaces posibles.
 */
class DeSiGNARStoryTree {
public:
    using Node = Designar::DecisionTreeNode<NarrativeDilemma>;

    static PlayerStats& get_global_stats() {
        static PlayerStats global_stats{0, 0, 0, 100, 0, 1};
        return global_stats;
    }

private:
    Node* root = nullptr;
    Node* current = nullptr;
    PlayerStats& stats;

    // Estado del motor de balanceo narrativo dinámico
    int football_score = 0;
    int street_score = 0;
    int balance_delta = 0;
    std::string active_branch_id = "DUAL_LIFE";
    std::string active_branch_name = "Rama Doble Vida";
    std::string dynamic_event_title;
    std::string dynamic_event_prompt;

    void free_subtree(Node* node) {
        if (!node) return;
        free_subtree(node->left);
        free_subtree(node->right);
        delete node;
    }

public:
    DeSiGNARStoryTree() : stats(get_global_stats()) {
        build_default_career_tree();
    }

    ~DeSiGNARStoryTree() {
        free_subtree(root);
    }

    /**
     * @brief Construye la jerarquía completa del árbol de decisiones.
     * Árbol ramificado real con finales anticipados (J2-J7) y finales de cierre (J8).
     *
     * Estructura del árbol:
     * ┌── CREATE_PLAYER → PROLOGUE_HIT → SELECT_ACADEMY → LEAGUE
     * │
     * ├── [J2-J7] EXPELLED_EARLY          (disc <= 0 ó red_cards >= 2)
     * │
     * ├── [J4]    MID_J4_OFFER
     * │           ├── Rechazar → continúa LEAGUE
     * │           └── Aceptar → PRO_FIGHTER_EARLY
     * │
     * ├── [J6]    AMBUSH_J6_BRAWL
     * │           ├── Gana → continúa LEAGUE
     * │           └── Pierde → HOSPITAL_DREAM_BAD
     * │
     * └── [J8]    POST_J8_CHOICE
     *             ├── Ignorar pelea → evaluar liga
     *             │   ├── 1.º + g+a>11 → GOLDEN_BOY_CHAMPION
     *             │   ├── 1.º          → LEAGUE_CHAMPION
     *             │   ├── 2.º          → PRO_RUNNER_UP
     *             │   └── 3.º+         → RELEASED_BAD
     *             └── Aceptar pelea → FINAL_BRAWL
     *                 ├── Gana + comb>=25 → PRO_FIGHTER_J8
     *                 ├── Gana + comb<25  → evaluar liga
     *                 └── Pierde          → HOSPITAL_DREAM_BAD
     */
    void build_default_career_tree() {
        // --- Nivel 0: Raíz (Inicio de trayectoria) ---
        root = new Node({
            "DAY_01",
            "La Encrucijada de la Cantera",
            "Has sido admitido en las pruebas del club juvenil, pero esta noche hay una pelea clandestina en el callejón que paga el alquiler familiar.",
            "Quedarte a descansar para el entrenamiento de mañana (+Disciplina, -Dinero)",
            StatModifier(+15, -5, 0, +20, 0),
            "Aceptar la pelea clandestina (+Reputación, +Dinero, +Combate, -Energía)",
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

        // --- Nivel 2: Finales del Árbol Narrativo Completo ---

        // Final 1: EXPELLED_EARLY (Malo Temprano J2-J7) — disc<=0 ó red_cards>=2
        root->left->left = new Node({
            "ENDING_EXPELLED_EARLY",
            "Final Malo Temprano: Expulsado por Indisciplina",
            "La cantera te expulsa por indisciplina reiterada antes de completar la temporada.",
            "", StatModifier(), "", StatModifier(),
            "Las tarjetas rojas y la falta de disciplina deportiva han truncado tu carrera. El sueño del fútbol profesional se desvanece en el asfalto."
        });

        // Final 2: PRO_FIGHTER_EARLY (Alternativo Temprano J4) — comb>=22 y acepta oferta
        root->left->right = new Node({
            "ENDING_PRO_FIGHTER_EARLY",
            "Final Alternativo Temprano: Peleador Profesional (J4)",
            "Un promotor de peleas clandestinas te ofrece dejar el fútbol tras el 4.º partido.",
            "", StatModifier(), "", StatModifier(),
            "Decides abandonar el fútbol y dedicarte al mundo de las peleas profesionales. La cantera pierde un talento, pero el ring gana una estrella."
        });

        // Final 3: HOSPITAL_DREAM_BAD (Trágico J6/J8) — pierde emboscada/pelea final
        root->right->left = new Node({
            "ENDING_HOSPITAL_DREAM_BAD",
            "Final Trágico: Hospital — Todo Fue un Sueño",
            "Un golpe brutal en la cabeza te deja inconsciente.",
            "", StatModifier(), "", StatModifier(),
            "Despiertas en una cama de hospital sin poder sentir tus piernas. Los médicos te explican que todo lo vivido podría haber sido un sueño febril. El final más oscuro."
        });

        // Final 4: PRO_FIGHTER_J8 (Alternativo J8) — gana pelea final con comb>=25
        root->right->right = new Node({
            "ENDING_PRO_FIGHTER_J8",
            "Final Alternativo: Peleador Profesional (J8)",
            "Tras completar las 8 jornadas, ganas la emboscada final y decides dedicarte al combate.",
            "", StatModifier(), "", StatModifier(),
            "Con una técnica de combate de élite, decides dedicar tu vida al combate profesional. Un camino distinto, pero igualmente glorioso."
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

    /**
     * @brief Aplica las recompensas e impacto estadístico de un partido de fútbol en las estadísticas del canterano.
     */
    void apply_match_result(int player_goals, int opponent_goals) {
        if (player_goals > opponent_goals) {
            stats.sports_discipline += 15;
            stats.combat_technique += 5;
            stats.money += 250;
        } else if (player_goals == opponent_goals) {
            stats.sports_discipline += 5;
            stats.money += 50;
        } else {
            stats.street_reputation += 10;
            stats.combat_technique += 5;
            stats.money += 50;
        }
        stats.current_day++;
    }

    /**
     * @brief Aplica las consecuencias de una pelea callejera en las estadísticas del canterano.
     * Si gana: suma técnica de combate (+15) y reputación callejera (+20), además de dinero (+150).
     * Si pierde: resta disciplina deportiva (-10) y energía/salud (-25), adquiriendo experiencia urbana (+5 reputación).
     */
    void apply_fight_result(bool player_won) {
        if (player_won) {
            stats.combat_technique += 15;
            stats.street_reputation += 20;
            stats.money += 150;
        } else {
            stats.sports_discipline = std::max(0, stats.sports_discipline - 10);
            stats.energy = std::max(0, stats.energy - 25);
            stats.street_reputation += 5;
        }
        stats.current_day++;
    }

    void add_sports_discipline(int amount) noexcept { stats.sports_discipline += amount; }
    void add_street_reputation(int amount) noexcept { stats.street_reputation += amount; }
    void add_combat_technique(int amount) noexcept { stats.combat_technique += amount; }
    void add_money(int amount) noexcept { stats.money += amount; }

    // --- Motor de Balanceo Narrativo por Estadísticas (DeSiGNAR) ---
    std::string rebalance_story_tree(int combate, int disciplina, int reputacion,
                                     int goals, int assists, int red_cards, int matchday);

    [[nodiscard]] int get_football_score() const noexcept { return football_score; }
    [[nodiscard]] int get_street_score() const noexcept { return street_score; }
    [[nodiscard]] int get_balance_delta() const noexcept { return balance_delta; }
    [[nodiscard]] std::string get_active_branch_id() const { return active_branch_id; }
    [[nodiscard]] std::string get_active_branch_name() const { return active_branch_name; }
    [[nodiscard]] std::string get_dynamic_event_title() const { return dynamic_event_title; }
    [[nodiscard]] std::string get_dynamic_event_prompt() const { return dynamic_event_prompt; }
};

} // namespace gtp

#endif // DESIGNAR_STORY_TREE_HPP
