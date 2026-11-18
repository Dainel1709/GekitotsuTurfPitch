#ifndef FOOTBALL_MECHANICS_HPP
#define FOOTBALL_MECHANICS_HPP

#include <algorithm>
#include <cmath>
#include "../story/designar_story_tree.hpp"

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
    float short_pass_force = 10.0f;         // Botón X: Pase corto raso
    float lob_pass_force = 17.0f;           // Botón O: Centro / pase bombeado
    float through_pass_force = 20.0f;       // Botón Δ: Pase en profundidad / al hueco
    float pass_stamina_cost = 4.0f;         // Menor consumo de estamina al pasar
    int team_tactic = 0;                    // 0: Equilibrado, 1: Ofensivo, 2: Defensivo

    // Marcador de partido / Puntuación
    int player_score = 0;                   // Goles a favor (jugador)
    int opponent_score = 0;                 // Goles en contra (rival)

public:
    FootballPlayerPhysics() = default;

    void update_stamina(float delta) {
        if (delta <= 0.0f) return;

        if (is_moving) {
            float drain = is_sprinting ? stamina_sprint_drain_rate : stamina_drain_rate;
            if (team_tactic == 1) drain *= 1.15f; // Táctica ofensiva consume más estamina
            stamina = std::max(0.0f, stamina - drain * delta);
        } else {
            float rec = stamina_recovery_rate;
            if (team_tactic == 2) rec *= 1.25f; // Táctica defensiva recupera más rápido
            stamina = std::min(max_stamina, stamina + rec * delta);
        }
    }

    [[nodiscard]] float get_current_speed() const noexcept {
        // Si no hay estamina, la velocidad decae a un 40% (estado de agotamiento)
        float fatigue_penalty = (stamina <= 0.0f) ? 0.4f : 1.0f;
        float sprint_bonus = is_sprinting && (stamina > 0.0f) ? sprint_multiplier : 1.0f;
        float tactic_bonus = (team_tactic == 1) ? 1.08f : (team_tactic == 2 ? 0.95f : 1.0f);
        return base_speed * sprint_bonus * fatigue_penalty * tactic_bonus;
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

    [[nodiscard]] float get_short_pass_force() const noexcept { return short_pass_force; }
    void set_short_pass_force(float force) noexcept { short_pass_force = std::max(1.0f, force); }

    [[nodiscard]] float get_lob_pass_force() const noexcept { return lob_pass_force; }
    void set_lob_pass_force(float force) noexcept { lob_pass_force = std::max(1.0f, force); }

    [[nodiscard]] float get_through_pass_force() const noexcept { return through_pass_force; }
    void set_through_pass_force(float force) noexcept { through_pass_force = std::max(1.0f, force); }

    void set_team_tactic(int tactic) noexcept { team_tactic = std::clamp(tactic, 0, 2); }
    [[nodiscard]] int get_team_tactic() const noexcept { return team_tactic; }

    [[nodiscard]] float get_pass_stamina_cost() const noexcept { return pass_stamina_cost; }
    void set_pass_stamina_cost(float cost) noexcept { pass_stamina_cost = std::max(0.0f, cost); }

    /**
     * @brief Botón X: Calcula el vector de fuerza 3D para un pase corto suave y raso.
     */
    void calculate_pass_vector(float dir_x, float dir_z,
                              float& out_vx, float& out_vy, float& out_vz) const noexcept {
        float len = std::sqrt(dir_x * dir_x + dir_z * dir_z);
        if (len > 0.0001f) {
            dir_x /= len;
            dir_z /= len;
        } else {
            dir_x = 0.0f;
            dir_z = -1.0f;
        }

        float force = short_pass_force;
        if (stamina < 30.0f) {
            force *= (0.7f + 0.3f * (std::max(0.0f, stamina) / 30.0f));
        }

        out_vx = dir_x * force;
        out_vz = dir_z * force;
        out_vy = 0.08f; // Raso
    }

    /**
     * @brief Botón O (Círculo): Pase bombeado / Centro con elevación moderada en Y.
     */
    void calculate_lob_pass_vector(float dir_x, float dir_z,
                                  float& out_vx, float& out_vy, float& out_vz) const noexcept {
        float len = std::sqrt(dir_x * dir_x + dir_z * dir_z);
        if (len > 0.0001f) {
            dir_x /= len;
            dir_z /= len;
        } else {
            dir_x = 0.0f;
            dir_z = -1.0f;
        }

        float force = lob_pass_force;
        if (stamina < 30.0f) {
            force *= (0.6f + 0.4f * (std::max(0.0f, stamina) / 30.0f));
        }

        out_vx = dir_x * force;
        out_vz = dir_z * force;
        out_vy = 4.2f; // Elevación moderada en Y para pase bombeado / centro
    }

    /**
     * @brief Botón Δ (Triángulo): Pase en profundidad / al hueco rápido y raso hacia adelante.
     */
    void calculate_through_pass_vector(float dir_x, float dir_z,
                                      float& out_vx, float& out_vy, float& out_vz) const noexcept {
        float len = std::sqrt(dir_x * dir_x + dir_z * dir_z);
        if (len > 0.0001f) {
            dir_x /= len;
            dir_z /= len;
        } else {
            dir_x = 0.0f;
            dir_z = -1.0f;
        }

        float force = through_pass_force;
        if (stamina < 30.0f) {
            force *= (0.7f + 0.3f * (std::max(0.0f, stamina) / 30.0f));
        }

        out_vx = dir_x * force;
        out_vz = dir_z * force;
        out_vy = 0.05f; // Raso y rápido
    }

    void apply_match_result(int p_score, int opp_score) {
        if (p_score > opp_score) {
            DeSiGNARStoryTree::get_global_stats().sports_discipline += 15;
            DeSiGNARStoryTree::get_global_stats().combat_technique += 5;
            DeSiGNARStoryTree::get_global_stats().money += 250;
        } else if (p_score == opp_score) {
            DeSiGNARStoryTree::get_global_stats().sports_discipline += 5;
            DeSiGNARStoryTree::get_global_stats().money += 50;
        } else {
            DeSiGNARStoryTree::get_global_stats().street_reputation += 10;
            DeSiGNARStoryTree::get_global_stats().combat_technique += 5;
            DeSiGNARStoryTree::get_global_stats().money += 50;
        }
        DeSiGNARStoryTree::get_global_stats().current_day++;
    }

    // --- Métodos de Puntuación y Marcador ---
    void score_goal_player() noexcept {
        ++player_score;
    }

    void score_goal_opponent() noexcept {
        ++opponent_score;
    }

    [[nodiscard]] int get_player_score() const noexcept {
        return player_score;
    }

    void set_player_score(int score) noexcept {
        player_score = std::max(0, score);
    }

    [[nodiscard]] int get_opponent_score() const noexcept {
        return opponent_score;
    }

    void set_opponent_score(int score) noexcept {
        opponent_score = std::max(0, score);
    }

    void reset_score() noexcept {
        player_score = 0;
        opponent_score = 0;
    }

    [[nodiscard]] float get_stamina_sprint_drain_rate() const noexcept {
        return stamina_sprint_drain_rate;
    }

    void set_stamina_sprint_drain_rate(float rate) noexcept {
        stamina_sprint_drain_rate = rate;
    }

    void apply_rpg_stats(int combat, int discipline) noexcept {
        float disc_factor = std::clamp(1.0f - static_cast<float>(discipline) * 0.006f, 0.55f, 1.0f);
        stamina_sprint_drain_rate = 35.0f * disc_factor;
        float combat_factor = 1.0f + static_cast<float>(combat) * 0.008f;
        base_kick_force = 16.0f * combat_factor;
        max_kick_force = 28.0f * combat_factor;
    }
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
    Vector3 calculate_pass_force(double dir_x, double dir_z);
    Vector3 calculate_lob_pass(double dir_x, double dir_z);
    Vector3 calculate_through_pass(double dir_x, double dir_z);
    double calculate_kick_force_magnitude(double charge_ratio = 1.0) const;
    double get_base_kick_force() const;
    void set_base_kick_force(double force);
    double get_max_kick_force() const;
    void set_max_kick_force(double force);
    double get_short_pass_force() const;
    void set_short_pass_force(double force);
    void set_team_tactic(int tactic);
    int get_team_tactic() const;

    // Métodos de puntuación y marcador
    void score_goal_player();
    void score_goal_opponent();
    int get_player_score() const;
    void set_player_score(int score);
    int get_opponent_score() const;
    void set_opponent_score(int score);
    void reset_score();
    void apply_match_result(int player_score, int opponent_score);
    void apply_rpg_stats(int combat, int discipline);
    double get_stamina_sprint_drain_rate() const;
    void set_stamina_sprint_drain_rate(double rate);
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

    [[nodiscard]] Vector3 calculate_pass_force(double dir_x, double dir_z) const {
        float vx = 0.0f, vy = 0.0f, vz = 0.0f;
        physics.calculate_pass_vector(static_cast<float>(dir_x), static_cast<float>(dir_z), vx, vy, vz);
        return Vector3(static_cast<double>(vx), static_cast<double>(vy), static_cast<double>(vz));
    }

    [[nodiscard]] Vector3 calculate_lob_pass(double dir_x, double dir_z) const {
        float vx = 0.0f, vy = 0.0f, vz = 0.0f;
        physics.calculate_lob_pass_vector(static_cast<float>(dir_x), static_cast<float>(dir_z), vx, vy, vz);
        return Vector3(static_cast<double>(vx), static_cast<double>(vy), static_cast<double>(vz));
    }

    [[nodiscard]] Vector3 calculate_through_pass(double dir_x, double dir_z) const {
        float vx = 0.0f, vy = 0.0f, vz = 0.0f;
        physics.calculate_through_pass_vector(static_cast<float>(dir_x), static_cast<float>(dir_z), vx, vy, vz);
        return Vector3(static_cast<double>(vx), static_cast<double>(vy), static_cast<double>(vz));
    }

    void set_team_tactic(int tactic) {
        physics.set_team_tactic(tactic);
    }

    [[nodiscard]] int get_team_tactic() const {
        return physics.get_team_tactic();
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

    [[nodiscard]] double get_short_pass_force() const {
        return static_cast<double>(physics.get_short_pass_force());
    }

    void set_short_pass_force(double force) {
        physics.set_short_pass_force(static_cast<float>(force));
    }

    // Métodos de puntuación y marcador (Standalone)
    void score_goal_player() {
        physics.score_goal_player();
    }

    void score_goal_opponent() {
        physics.score_goal_opponent();
    }

    [[nodiscard]] int get_player_score() const {
        return physics.get_player_score();
    }

    void set_player_score(int score) {
        physics.set_player_score(score);
    }

    [[nodiscard]] int get_opponent_score() const {
        return physics.get_opponent_score();
    }

    void set_opponent_score(int score) {
        physics.set_opponent_score(score);
    }

    void reset_score() {
        physics.reset_score();
    }

    void apply_match_result(int player_score, int opponent_score) {
        physics.apply_match_result(player_score, opponent_score);
    }

    void apply_rpg_stats(int combat, int discipline) {
        physics.apply_rpg_stats(combat, discipline);
    }

    [[nodiscard]] double get_stamina_sprint_drain_rate() const {
        return static_cast<double>(physics.get_stamina_sprint_drain_rate());
    }

    void set_stamina_sprint_drain_rate(double rate) {
        physics.set_stamina_sprint_drain_rate(static_cast<float>(rate));
    }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // FOOTBALL_MECHANICS_HPP
