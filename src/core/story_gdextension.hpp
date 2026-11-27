#ifndef STORY_GDEXTENSION_HPP
#define STORY_GDEXTENSION_HPP

#include "story_controller.hpp"

#ifdef GODOT_GDEXTENSION_ENABLED
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class GekitotsuStoryManager : public Node {
    GDCLASS(GekitotsuStoryManager, Node)

private:
    gtp::StoryController controller;

protected:
    static void _bind_methods() {
        // Enlace de métodos hacia el motor Godot y GDScript
        ClassDB::bind_method(D_METHOD("get_current_title"), &GekitotsuStoryManager::get_current_title);
        ClassDB::bind_method(D_METHOD("get_current_prompt"), &GekitotsuStoryManager::get_current_prompt);
        ClassDB::bind_method(D_METHOD("get_discipline_option_text"), &GekitotsuStoryManager::get_discipline_option_text);
        ClassDB::bind_method(D_METHOD("get_street_option_text"), &GekitotsuStoryManager::get_street_option_text);
        ClassDB::bind_method(D_METHOD("get_ending_summary"), &GekitotsuStoryManager::get_ending_summary);
        ClassDB::bind_method(D_METHOD("choose_discipline"), &GekitotsuStoryManager::choose_discipline);
        ClassDB::bind_method(D_METHOD("choose_street"), &GekitotsuStoryManager::choose_street);
        ClassDB::bind_method(D_METHOD("get_discipline_points"), &GekitotsuStoryManager::get_discipline_points);
        ClassDB::bind_method(D_METHOD("get_street_reputation"), &GekitotsuStoryManager::get_street_reputation);
        ClassDB::bind_method(D_METHOD("get_combat_technique"), &GekitotsuStoryManager::get_combat_technique);
        ClassDB::bind_method(D_METHOD("get_money"), &GekitotsuStoryManager::get_money);
        ClassDB::bind_method(D_METHOD("get_energy"), &GekitotsuStoryManager::get_energy);
        ClassDB::bind_method(D_METHOD("get_current_day"), &GekitotsuStoryManager::get_current_day);
        ClassDB::bind_method(D_METHOD("is_career_over"), &GekitotsuStoryManager::is_career_over);
        ClassDB::bind_method(D_METHOD("apply_match_result", "player_goals", "opponent_goals"), &GekitotsuStoryManager::apply_match_result);
        ClassDB::bind_method(D_METHOD("apply_fight_result", "player_won"), &GekitotsuStoryManager::apply_fight_result);
        ClassDB::bind_method(D_METHOD("rebalance_story_tree", "combate", "disciplina", "reputacion", "goals", "assists", "red_cards", "matchday"), &GekitotsuStoryManager::rebalance_story_tree);
        ClassDB::bind_method(D_METHOD("get_active_branch_name"), &GekitotsuStoryManager::get_active_branch_name);
        ClassDB::bind_method(D_METHOD("get_balance_delta"), &GekitotsuStoryManager::get_balance_delta);
        ClassDB::bind_method(D_METHOD("get_football_score"), &GekitotsuStoryManager::get_football_score);
        ClassDB::bind_method(D_METHOD("get_street_score"), &GekitotsuStoryManager::get_street_score);
        ClassDB::bind_method(D_METHOD("get_active_branch_id"), &GekitotsuStoryManager::get_active_branch_id);
        ClassDB::bind_method(D_METHOD("get_dynamic_event_title"), &GekitotsuStoryManager::get_dynamic_event_title);
        ClassDB::bind_method(D_METHOD("get_dynamic_event_prompt"), &GekitotsuStoryManager::get_dynamic_event_prompt);
    }

public:
    GekitotsuStoryManager() = default;
    ~GekitotsuStoryManager() override = default;

    // --- 1. get_current_title ---
    String get_current_title() const {
        return String(controller.get_current_title().c_str());
    }

    // --- 2. get_current_prompt ---
    String get_current_prompt() const {
        return String(controller.get_current_prompt().c_str());
    }

    String get_discipline_option_text() const {
        return String(controller.get_discipline_option_text().c_str());
    }

    String get_street_option_text() const {
        return String(controller.get_street_option_text().c_str());
    }

    String get_ending_summary() const {
        return String(controller.get_ending_summary().c_str());
    }

    // --- 3. choose_discipline ---
    bool choose_discipline() {
        return controller.choose_discipline();
    }

    // --- 4. choose_street ---
    bool choose_street() {
        return controller.choose_street();
    }

    // --- 5. get_discipline_points ---
    int get_discipline_points() const {
        return controller.get_discipline_points();
    }

    // --- 6. get_street_reputation ---
    int get_street_reputation() const {
        return controller.get_street_reputation();
    }

    int get_combat_technique() const {
        return controller.get_combat_technique();
    }

    int get_money() const {
        return controller.get_money();
    }

    int get_energy() const {
        return controller.get_energy();
    }

    int get_current_day() const {
        return controller.get_current_day();
    }

    // --- 7. is_career_over ---
    bool is_career_over() const {
        return controller.is_career_over();
    }

    void apply_match_result(int player_goals, int opponent_goals) {
        controller.apply_match_result(player_goals, opponent_goals);
    }

    void apply_fight_result(bool player_won) {
        controller.apply_fight_result(player_won);
    }

    String rebalance_story_tree(int combate, int disciplina, int reputacion,
                                int goals, int assists, int red_cards, int matchday) {
        return String(controller.rebalance_story_tree(
            combate, disciplina, reputacion, goals, assists, red_cards, matchday).c_str());
    }

    String get_active_branch_name() const {
        return String(controller.get_active_branch_name().c_str());
    }

    int get_balance_delta() const {
        return controller.get_balance_delta();
    }

    int get_football_score() const {
        return controller.get_football_score();
    }

    int get_street_score() const {
        return controller.get_street_score();
    }

    String get_active_branch_id() const {
        return String(controller.get_active_branch_id().c_str());
    }

    String get_dynamic_event_title() const {
        return String(controller.get_dynamic_event_title().c_str());
    }

    String get_dynamic_event_prompt() const {
        return String(controller.get_dynamic_event_prompt().c_str());
    }
};

} // namespace godot

#else

// Modo C++ Estándar (Standalone / Tests sin dependencias externas)
namespace godot {

class GekitotsuStoryManager {
private:
    gtp::StoryController controller;

public:
    GekitotsuStoryManager() = default;

    // --- 1. get_current_title ---
    std::string get_current_title() const {
        return controller.get_current_title();
    }

    // --- 2. get_current_prompt ---
    std::string get_current_prompt() const {
        return controller.get_current_prompt();
    }

    std::string get_discipline_option_text() const {
        return controller.get_discipline_option_text();
    }

    std::string get_street_option_text() const {
        return controller.get_street_option_text();
    }

    std::string get_ending_summary() const {
        return controller.get_ending_summary();
    }

    // --- 3. choose_discipline ---
    bool choose_discipline() {
        return controller.choose_discipline();
    }

    // --- 4. choose_street ---
    bool choose_street() {
        return controller.choose_street();
    }

    // --- 5. get_discipline_points ---
    int get_discipline_points() const {
        return controller.get_discipline_points();
    }

    // --- 6. get_street_reputation ---
    int get_street_reputation() const {
        return controller.get_street_reputation();
    }

    int get_combat_technique() const {
        return controller.get_combat_technique();
    }

    int get_money() const {
        return controller.get_money();
    }

    int get_energy() const {
        return controller.get_energy();
    }

    int get_current_day() const {
        return controller.get_current_day();
    }

    // --- 7. is_career_over ---
    bool is_career_over() const {
        return controller.is_career_over();
    }

    void apply_match_result(int player_goals, int opponent_goals) {
        controller.apply_match_result(player_goals, opponent_goals);
    }

    void apply_fight_result(bool player_won) {
        controller.apply_fight_result(player_won);
    }

    std::string rebalance_story_tree(int combate, int disciplina, int reputacion,
                                     int goals, int assists, int red_cards, int matchday) {
        return controller.rebalance_story_tree(
            combate, disciplina, reputacion, goals, assists, red_cards, matchday);
    }

    std::string get_active_branch_name() const {
        return controller.get_active_branch_name();
    }

    int get_balance_delta() const {
        return controller.get_balance_delta();
    }

    int get_football_score() const {
        return controller.get_football_score();
    }

    int get_street_score() const {
        return controller.get_street_score();
    }

    std::string get_active_branch_id() const {
        return controller.get_active_branch_id();
    }

    std::string get_dynamic_event_title() const {
        return controller.get_dynamic_event_title();
    }

    std::string get_dynamic_event_prompt() const {
        return controller.get_dynamic_event_prompt();
    }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // STORY_GDEXTENSION_HPP
