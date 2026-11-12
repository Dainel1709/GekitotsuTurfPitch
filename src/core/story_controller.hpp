#ifndef STORY_CONTROLLER_HPP
#define STORY_CONTROLLER_HPP

#include <string>
#include "../story/designar_story_tree.hpp"

namespace gtp {

/**
 * @brief Controlador que conecta el árbol de decisiones DeSiGNAR con las interfaces
 * y escenas de Godot (menús de decisiones, HUD de estadísticas y transiciones).
 */
class StoryController {
private:
    DeSiGNARStoryTree tree;

public:
    StoryController() = default;

    // --- Navegación del Árbol ---
    bool choose_discipline() {
        return tree.choose_discipline();
    }

    bool choose_street() {
        return tree.choose_street();
    }

    [[nodiscard]] bool is_career_over() const noexcept {
        return tree.is_career_over();
    }

    // --- Consultas del Dilema Actual ---
    [[nodiscard]] std::string get_current_id() const {
        auto* node = tree.get_current_node();
        return node ? node->data.id : "";
    }

    [[nodiscard]] std::string get_current_title() const {
        auto* node = tree.get_current_node();
        return node ? node->data.title : "";
    }

    [[nodiscard]] std::string get_current_prompt() const {
        auto* node = tree.get_current_node();
        return node ? node->data.prompt : "";
    }

    [[nodiscard]] std::string get_discipline_option_text() const {
        auto* node = tree.get_current_node();
        return node ? node->data.discipline_option_text : "";
    }

    [[nodiscard]] std::string get_street_option_text() const {
        auto* node = tree.get_current_node();
        return node ? node->data.street_option_text : "";
    }

    [[nodiscard]] std::string get_ending_summary() const {
        auto* node = tree.get_current_node();
        return node ? node->data.ending_summary : "";
    }

    // --- Consulta de Estadísticas ---
    [[nodiscard]] int get_discipline_points() const noexcept {
        return tree.get_player_stats().sports_discipline;
    }

    [[nodiscard]] int get_sports_discipline() const noexcept {
        return tree.get_player_stats().sports_discipline;
    }

    [[nodiscard]] int get_street_reputation() const noexcept {
        return tree.get_player_stats().street_reputation;
    }

    [[nodiscard]] int get_combat_technique() const noexcept {
        return tree.get_player_stats().combat_technique;
    }

    [[nodiscard]] int get_energy() const noexcept {
        return tree.get_player_stats().energy;
    }

    [[nodiscard]] int get_money() const noexcept {
        return tree.get_player_stats().money;
    }

    [[nodiscard]] int get_current_day() const noexcept {
        return tree.get_player_stats().current_day;
    }
};

} // namespace gtp

#endif // STORY_CONTROLLER_HPP
