#ifndef FOOTBALL_MECHANICS_HPP
#define FOOTBALL_MECHANICS_HPP

#include <algorithm>
#include <cmath>

namespace gtp {

/**
 * @brief Núcleo C++ puro para la física y gestión de estamina/movimiento del canterano.
 */
class FootballPlayerPhysics {
private:
    float base_speed = 10.0f;
    float sprint_multiplier = 1.6f;
    float stamina = 100.0f;
    float max_stamina = 100.0f;
    float stamina_drain_rate = 20.0f;       // Consumo por segundo al correr
    float stamina_sprint_drain_rate = 35.0f; // Consumo por segundo en sprint
    float stamina_recovery_rate = 15.0f;    // Recuperación por segundo al estar quieto
    bool is_moving = false;
    bool is_sprinting = false;

public:
    FootballPlayerPhysics() = default;

    void update_stamina(float delta) {
        if (delta <= 0.0f) return;

        if (is_moving) {
            float drain = is_sprinting ? stamina_sprint_drain_rate : stamina_drain_rate;
            stamina = std::max(0.0f, stamina - drain * delta);
        } else {
            stamina = std::min(max_stamina, stamina + stamina_recovery_rate * delta);
        }
    }

    [[nodiscard]] float get_current_speed() const noexcept {
        // Si no hay estamina, la velocidad decae a un 40% (estado de agotamiento)
        float fatigue_penalty = (stamina <= 0.0f) ? 0.4f : 1.0f;
        float sprint_bonus = is_sprinting && (stamina > 0.0f) ? sprint_multiplier : 1.0f;
        return base_speed * sprint_bonus * fatigue_penalty;
    }

    // --- Getters y Setters ---
    [[nodiscard]] float get_base_speed() const noexcept { return base_speed; }
    void set_base_speed(float speed) noexcept { base_speed = std::max(0.0f, speed); }

    [[nodiscard]] float get_stamina() const noexcept { return stamina; }
    void set_stamina(float value) noexcept { stamina = std::clamp(value, 0.0f, max_stamina); }

    [[nodiscard]] float get_max_stamina() const noexcept { return max_stamina; }
    void set_max_stamina(float value) noexcept { max_stamina = std::max(1.0f, value); }

    [[nodiscard]] bool get_is_moving() const noexcept { return is_moving; }
    void set_moving(bool moving) noexcept { is_moving = moving; }

    [[nodiscard]] bool get_is_sprinting() const noexcept { return is_sprinting; }
    void set_sprinting(bool sprinting) noexcept { is_sprinting = sprinting; }

    void drain_stamina(float amount) noexcept {
        stamina = std::max(0.0f, stamina - amount);
    }

    void recover_stamina(float amount) noexcept {
        stamina = std::min(max_stamina, stamina + amount);
    }
};

} // namespace gtp

#ifdef GODOT_GDEXTENSION_ENABLED
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

/**
 * @brief Enlace GDExtension para el motor de fútbol hacia Godot Engine.
 */
class FootballMechanics : public Node {
    GDCLASS(FootballMechanics, Node)

private:
    gtp::FootballPlayerPhysics physics;

protected:
    static void _bind_methods();

public:
    FootballMechanics() = default;
    ~FootballMechanics() override = default;

    void update_stamina(double delta);
    double get_current_speed() const;
    double get_base_speed() const;
    void set_base_speed(double speed);
    double get_stamina() const;
    void set_stamina(double value);
    double get_max_stamina() const;
    void set_max_stamina(double value);
    bool is_moving() const;
    void set_moving(bool moving);
    bool is_sprinting() const;
    void set_sprinting(bool sprinting);
    void drain_stamina(double amount);
};

} // namespace godot

#else

// Modo C++ Estándar / Standalone
namespace godot {

class FootballMechanics {
private:
    gtp::FootballPlayerPhysics physics;

public:
    FootballMechanics() = default;

    void update_stamina(double delta) {
        physics.update_stamina(static_cast<float>(delta));
    }

    [[nodiscard]] double get_current_speed() const {
        return static_cast<double>(physics.get_current_speed());
    }

    [[nodiscard]] double get_base_speed() const {
        return static_cast<double>(physics.get_base_speed());
    }

    void set_base_speed(double speed) {
        physics.set_base_speed(static_cast<float>(speed));
    }

    [[nodiscard]] double get_stamina() const {
        return static_cast<double>(physics.get_stamina());
    }

    void set_stamina(double value) {
        physics.set_stamina(static_cast<float>(value));
    }

    [[nodiscard]] double get_max_stamina() const {
        return static_cast<double>(physics.get_max_stamina());
    }

    void set_max_stamina(double value) {
        physics.set_max_stamina(static_cast<float>(value));
    }

    [[nodiscard]] bool is_moving() const {
        return physics.get_is_moving();
    }

    void set_moving(bool moving) {
        physics.set_moving(moving);
    }

    [[nodiscard]] bool is_sprinting() const {
        return physics.get_is_sprinting();
    }

    void set_sprinting(bool sprinting) {
        physics.set_sprinting(sprinting);
    }

    void drain_stamina(double amount) {
        physics.drain_stamina(static_cast<float>(amount));
    }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // FOOTBALL_MECHANICS_HPP
