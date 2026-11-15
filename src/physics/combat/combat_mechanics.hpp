#ifndef COMBAT_MECHANICS_HPP
#define COMBAT_MECHANICS_HPP

#include <algorithm>
#include <cmath>

namespace gtp {

/**
 * @brief Estado de la máquina de estados de la IA del rival callejero.
 */
enum class AICombatState {
    APPROACHING,
    ATTACKING,
    IDLE
};

/**
 * @brief Lógica C++ para el sistema de combate callejero (1 vs 1).
 */
class FighterCombatLogic {
private:
    float health = 100.0f;
    float max_health = 100.0f;
    float punch_damage = 20.0f;
    float punch_range = 65.0f;
    float punch_cooldown = 0.45f;
    float ai_attack_interval = 1.2f;
    float ai_timer = 0.0f;
    float cooldown_timer = 0.0f;

public:
    FighterCombatLogic() = default;
    explicit FighterCombatLogic(float hp, float dmg = 20.0f, float range = 65.0f)
        : health(hp), max_health(hp), punch_damage(dmg), punch_range(range) {}

    void update(float delta) {
        if (cooldown_timer > 0.0f) {
            cooldown_timer = std::max(0.0f, cooldown_timer - delta);
        }
    }

    [[nodiscard]] bool can_punch() const noexcept {
        return cooldown_timer <= 0.001f && health > 0.0f;
    }

    bool execute_punch() noexcept {
        if (!can_punch()) return false;
        cooldown_timer = punch_cooldown;
        return true;
    }

    float take_damage(float damage) noexcept {
        health = std::max(0.0f, health - damage);
        return health;
    }

    [[nodiscard]] bool is_defeated() const noexcept {
        return health <= 0.0f;
    }

    [[nodiscard]] bool is_in_punch_range(float my_x, float target_x) const noexcept {
        return std::abs(my_x - target_x) <= punch_range;
    }

    /**
     * @brief Procesa el ciclo de decisión de la IA rival cada frame.
     * Si está fuera de rango, avanza hacia el jugador.
     * Si está a rango, espera el intervalo de 1.2s y ejecuta el golpe.
     */
    AICombatState process_ai_tick(float my_x, float target_x, float delta, bool& out_should_punch, int& out_move_direction) {
        out_should_punch = false;
        out_move_direction = 0;

        if (health <= 0.0f) return AICombatState::IDLE;

        float dist = std::abs(my_x - target_x);

        if (dist > punch_range * 0.85f) {
            ai_timer = 0.0f;
            out_move_direction = (target_x < my_x) ? -1 : 1;
            return AICombatState::APPROACHING;
        }

        // En rango de golpe: encarar y acumular temporizador hacia 1.2s
        out_move_direction = 0;
        ai_timer += delta;
        if (ai_timer >= ai_attack_interval) {
            ai_timer = 0.0f;
            if (can_punch()) {
                execute_punch();
                out_should_punch = true;
                return AICombatState::ATTACKING;
            }
        }

        return AICombatState::IDLE;
    }

    // Getters y Setters
    [[nodiscard]] float get_health() const noexcept { return health; }
    void set_health(float val) noexcept { health = std::clamp(val, 0.0f, max_health); }
    [[nodiscard]] float get_max_health() const noexcept { return max_health; }
    void set_max_health(float val) noexcept { max_health = std::max(1.0f, val); }
    [[nodiscard]] float get_punch_damage() const noexcept { return punch_damage; }
    void set_punch_damage(float val) noexcept { punch_damage = std::max(0.0f, val); }
    [[nodiscard]] float get_punch_range() const noexcept { return punch_range; }
    void set_punch_range(float val) noexcept { punch_range = std::max(1.0f, val); }
    [[nodiscard]] float get_punch_cooldown() const noexcept { return punch_cooldown; }
    void set_punch_cooldown(float val) noexcept { punch_cooldown = std::max(0.05f, val); }
    [[nodiscard]] float get_ai_attack_interval() const noexcept { return ai_attack_interval; }
    void set_ai_attack_interval(float val) noexcept { ai_attack_interval = std::max(0.1f, val); }
};

} // namespace gtp

#endif // COMBAT_MECHANICS_HPP
