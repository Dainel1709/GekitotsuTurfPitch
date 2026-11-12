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
        // Enlace de los 7 métodos clave hacia el motor Godot y GDScript
        ClassDB::bind_method(D_METHOD("get_current_title"), &GekitotsuStoryManager::get_current_title);
        ClassDB::bind_method(D_METHOD("get_current_prompt"), &GekitotsuStoryManager::get_current_prompt);
        ClassDB::bind_method(D_METHOD("choose_discipline"), &GekitotsuStoryManager::choose_discipline);
        ClassDB::bind_method(D_METHOD("choose_street"), &GekitotsuStoryManager::choose_street);
        ClassDB::bind_method(D_METHOD("get_discipline_points"), &GekitotsuStoryManager::get_discipline_points);
        ClassDB::bind_method(D_METHOD("get_street_reputation"), &GekitotsuStoryManager::get_street_reputation);
        ClassDB::bind_method(D_METHOD("is_career_over"), &GekitotsuStoryManager::is_career_over);
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

    // --- 7. is_career_over ---
    bool is_career_over() const {
        return controller.is_career_over();
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

    // --- 7. is_career_over ---
    bool is_career_over() const {
        return controller.is_career_over();
    }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // STORY_GDEXTENSION_HPP
