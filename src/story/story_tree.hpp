#ifndef STORY_TREE_HPP
#define STORY_TREE_HPP

#include <string>
#include <vector>
#include <memory>
#include <iostream>

namespace gtp {

/**
 * @brief Estadísticas clave del protagonista en Gekitotsu Turf Pitch.
 * Rastrea la dualidad entre la disciplina deportiva profesional y la reputación callejera.
 */
struct PlayerStats {
    int sports_discipline = 0;   // Disciplina Deportiva (Día / Club)
    int street_reputation = 0;   // Reputación en el Asfalto (Noche / Calle)
    int combat_technique = 0;    // Técnica de Combate
    int energy = 100;            // Nivel de energía/estamina
    int money = 0;               // Dinero acumulado
    int current_day = 1;         // Día del ciclo de vida hacia los 18 años
};

/**
 * @brief Modificadores numéricos que una decisión aplica sobre las estadísticas del jugador.
 */
struct StatModifier {
    int sports_discipline = 0;
    int street_reputation = 0;
    int combat_technique = 0;
    int energy = 0;
    int money = 0;

    StatModifier() = default;
    StatModifier(int discipline, int reputation, int combat = 0, int nrg = 0, int cash = 0)
        : sports_discipline(discipline), street_reputation(reputation),
          combat_technique(combat), energy(nrg), money(cash) {}
};

/**
 * @brief Identificador de la rama elegida.
 */
enum class DecisionBranch {
    DISCIPLINE_LEFT,          // Rama izquierda: Disciplina deportiva / Club profesional
    STREET_REPUTATION_RIGHT   // Rama derecha: Reputación en el asfalto / Noche urbana
};

// Declaración anticipada del nodo
struct StoryNode;

/**
 * @brief Estructura de una opción dentro de un nodo de la historia.
 */
struct StoryOption {
    std::string text;
    StatModifier modifier;
    std::shared_ptr<StoryNode> target_node = nullptr;

    StoryOption() = default;
    StoryOption(const std::string& option_text,
                const StatModifier& mod,
                std::shared_ptr<StoryNode> next_node = nullptr)
        : text(option_text), modifier(mod), target_node(std::move(next_node)) {}
};

/**
 * @brief Nodo del árbol/grafo de decisiones.
 * Cada nodo presenta un contexto y dos ramas mutuamente excluyentes:
 * - Rama Izquierda (left_option): Disciplina deportiva.
 * - Rama Derecha (right_option): Reputación callejera.
 */
struct StoryNode {
    std::string id;
    std::string title;
    std::string description;

    StoryOption left_option;   // Rama izquierda: Disciplina deportiva
    StoryOption right_option;  // Rama derecha: Reputación callejera

    StoryNode() = default;
    StoryNode(std::string node_id, std::string node_title, std::string node_desc)
        : id(std::move(node_id)), title(std::move(node_title)), description(std::move(node_desc)) {}

    /**
     * @brief Indica si el nodo actual es un desenlace / nodo hoja sin más decisiones.
     */
    [[nodiscard]] bool is_leaf() const {
        return (left_option.target_node == nullptr) && (right_option.target_node == nullptr);
    }
};

/**
 * @brief Registro histórico de una decisión ejecutada por el jugador.
 */
struct DecisionRecord {
    std::string node_id;
    DecisionBranch chosen_branch;
    std::string choice_text;
    StatModifier applied_modifier;
};

/**
 * @brief Clase gestora para recorrer el árbol de decisiones, controlar el flujo narrativo
 * y actualizar dinámicamente las estadísticas del jugador.
 */
class StoryTreeManager {
private:
    std::shared_ptr<StoryNode> root_node = nullptr;
    std::shared_ptr<StoryNode> current_node = nullptr;
    PlayerStats player_stats;
    std::vector<DecisionRecord> decision_history;

public:
    StoryTreeManager() = default;

    explicit StoryTreeManager(std::shared_ptr<StoryNode> root)
        : root_node(root), current_node(std::move(root)) {}

    /**
     * @brief Asigna el nodo raíz y posiciona al jugador en el inicio.
     */
    void set_root_node(std::shared_ptr<StoryNode> root) {
        root_node = std::move(root);
        current_node = root_node;
    }

    /**
     * @brief Obtiene el nodo actual en el que se encuentra el jugador.
     */
    [[nodiscard]] std::shared_ptr<StoryNode> get_current_node() const {
        return current_node;
    }

    /**
     * @brief Obtiene las estadísticas acumuladas del jugador.
     */
    [[nodiscard]] const PlayerStats& get_player_stats() const {
        return player_stats;
    }

    /**
     * @brief Modifica manualmente o por evento las estadísticas del jugador.
     */
    void apply_stat_modifier(const StatModifier& mod) {
        player_stats.sports_discipline += mod.sports_discipline;
        player_stats.street_reputation += mod.street_reputation;
        player_stats.combat_technique += mod.combat_technique;
        player_stats.energy += mod.energy;
        player_stats.money += mod.money;
    }

    /**
     * @brief Avanza por la rama izquierda (Disciplina Deportiva).
     * @return true si se avanzó con éxito al siguiente nodo, false si no hay nodo destino.
     */
    bool choose_discipline_left() {
        return advance(DecisionBranch::DISCIPLINE_LEFT);
    }

    /**
     * @brief Avanza por la rama derecha (Reputación Callejera).
     * @return true si se avanzó con éxito al siguiente nodo, false si no hay nodo destino.
     */
    bool choose_street_right() {
        return advance(DecisionBranch::STREET_REPUTATION_RIGHT);
    }

    /**
     * @brief Avanza en el grafo seleccionando la rama indicada.
     * @param branch Rama a elegir (DISCIPLINE_LEFT o STREET_REPUTATION_RIGHT).
     * @return true si el avance fue exitoso, false en caso contrario.
     */
    bool advance(DecisionBranch branch) {
        if (!current_node) {
            return false;
        }

        const StoryOption& chosen_option = (branch == DecisionBranch::DISCIPLINE_LEFT)
                                             ? current_node->left_option
                                             : current_node->right_option;

        if (!chosen_option.target_node) {
            return false;
        }

        // Aplicar los cambios en estadísticas
        apply_stat_modifier(chosen_option.modifier);

        // Registrar en el historial de decisiones
        decision_history.push_back({
            current_node->id,
            branch,
            chosen_option.text,
            chosen_option.modifier
        });

        // Mover al siguiente nodo e incrementar el día
        current_node = chosen_option.target_node;
        player_stats.current_day++;

        return true;
    }

    /**
     * @brief Comprueba si el jugador ha alcanzado un nodo de final o desenlace.
     */
    [[nodiscard]] bool is_terminal_node() const {
        return current_node != nullptr && current_node->is_leaf();
    }

    /**
     * @brief Retorna el historial completo de decisiones tomadas.
     */
    [[nodiscard]] const std::vector<DecisionRecord>& get_decision_history() const {
        return decision_history;
    }

    /**
     * @brief Reinicia el estado del jugador y lo regresa al nodo raíz.
     */
    void reset_to_root() {
        current_node = root_node;
        player_stats = PlayerStats();
        decision_history.clear();
    }
};

} // namespace gtp

#endif // STORY_TREE_HPP
