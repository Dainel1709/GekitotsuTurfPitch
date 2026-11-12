#ifndef FOOTBALL_MECHANICS_HPP
#define FOOTBALL_MECHANICS_HPP

#include <algorithm>
#include <cmath>

namespace gtp {

/**
 * @brief Núcleo C++ puro para la física, gestión de estamina, movimiento y cálculo de disparo del canterano.
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

    // Parámetros y estadísticas de disparo arcade
    float base_kick_force = 16.0f;          // Fuerza base de patada / pase
    float max_kick_force = 28.0f;           // Fuerza máxima con carga completa
    float kick_stamina_cost = 8.0f;         // Coste base de estamina por patear

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

    /**
     * @brief Calcula la magnitud escalar de la fuerza de pateo influenciada por la estamina y la carga.
     * @param charge_ratio Proporción de carga entre 0.0 (toque rápido) y 1.0 (tiro a máxima potencia).
     * @return Magnitud de fuerza resultante en m/s (impulso).
     */
    [[nodiscard]] float calculate_kick_force_magnitude(float charge_ratio = 1.0f) const noexcept {
        float charge = std::clamp(charge_ratio, 0.0f, 1.0f);
        float raw_force = base_kick_force + (max_kick_force - base_kick_force) * charge;

        // Influencia de la estamina / fatiga física:
        // Si la estamina >= 30%, el jugador rinde al 100%.
        // Por debajo de 30%, la potencia decae gradualmente hasta un 50%.
        float stamina_efficiency = 1.0f;
        if (stamina < 30.0f) {
            stamina_efficiency = 0.5f + 0.5f * (std::max(0.0f, stamina) / 30.0f);
        }

        return raw_force * stamina_efficiency;
    }

    /**
     * @brief Calcula el vector de fuerza 3D de la patada, manteniendo el juego arcade en el plano X/Z
     * y limitando los rebotes altos en Y.
     */
    void calculate_kick_vector(float dir_x, float dir_z, float charge_ratio,
                              float& out_vx, float& out_vy, float& out_vz) const noexcept {
        float len = std::sqrt(dir_x * dir_x + dir_z * dir_z);
        if (len > 0.0001f) {
            dir_x /= len;
            dir_z /= len;
        } else {
            dir_x = 1.0f;
            dir_z = 0.0f;
        }

        float force = calculate_kick_force_magnitude(charge_ratio);
        out_vx = dir_x * force;
        out_vz = dir_z * force;

        // Elevación en Y moderada (máximo 1.6 de impulso hacia arriba para evitar descontrol)
        float charge = std::clamp(charge_ratio, 0.0f, 1.0f);
        out_vy = std::min(1.6f, force * (0.04f + 0.05f * charge));
    }

    // --- Getters y Setters de Movimiento y Estamina ---
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

    // --- Getters y Setters de Patada ---
    [[nodiscard]] float get_base_kick_force() const noexcept { return base_kick_force; }
    void set_base_kick_force(float force) noexcept { base_kick_force = std::max(1.0f, force); }

    [[nodiscard]] float get_max_kick_force() const noexcept { return max_kick_force; }
    void set_max_kick_force(float force) noexcept { max_kick_force = std::max(base_kick_force, force); }

    [[nodiscard]] float get_kick_stamina_cost() const noexcept { return kick_stamina_cost; }
    void set_kick_stamina_cost(float cost) noexcept { kick_stamina_cost = std::max(0.0f, cost); }
};

} // namespace gtp

#ifdef GODOT_GDEXTENSION_ENABLED
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>

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

    // Nuevos métodos de disparo y pateo
    Vector3 calculate_kick_force(double dir_x, double dir_z, double charge_ratio = 1.0);
    double calculate_kick_force_magnitude(double charge_ratio = 1.0) const;
    double get_base_kick_force() const;
    void set_base_kick_force(double force);
    double get_max_kick_force() const;
    void set_max_kick_force(double force);
};

} // namespace godot

#else

// Modo C++ Estándar / Standalone
namespace godot {

struct Vector3 {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;

    Vector3() = default;
    constexpr Vector3(double px, double py, double pz) : x(px), y(py), z(pz) {}
};

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

    // Métodos de disparo / patada
    [[nodiscard]] Vector3 calculate_kick_force(double dir_x, double dir_z, double charge_ratio = 1.0) const {
        float vx = 0.0f, vy = 0.0f, vz = 0.0f;
        physics.calculate_kick_vector(static_cast<float>(dir_x), static_cast<float>(dir_z),
                                     static_cast<float>(charge_ratio), vx, vy, vz);
        return Vector3(static_cast<double>(vx), static_cast<double>(vy), static_cast<double>(vz));
    }

    [[nodiscard]] double calculate_kick_force_magnitude(double charge_ratio = 1.0) const {
        return static_cast<double>(physics.calculate_kick_force_magnitude(static_cast<float>(charge_ratio)));
    }

    [[nodiscard]] double get_base_kick_force() const {
        return static_cast<double>(physics.get_base_kick_force());
    }

    void set_base_kick_force(double force) {
        physics.set_base_kick_force(static_cast<float>(force));
    }

    [[nodiscard]] double get_max_kick_force() const {
        return static_cast<double>(physics.get_max_kick_force());
    }

    void set_max_kick_force(double force) {
        physics.set_max_kick_force(static_cast<float>(force));
    }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // FOOTBALL_MECHANICS_HPP
