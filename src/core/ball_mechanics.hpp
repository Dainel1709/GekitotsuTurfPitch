#ifndef BALL_MECHANICS_HPP
#define BALL_MECHANICS_HPP

#include <algorithm>
#include <cmath>

namespace gtp {

/**
 * @brief Núcleo matemático y físico en C++ puro para la pelota de fútbol 2.5D.
 * Gestiona cinemática, fricción de rodadura en césped, gravedad/arco aéreo y rebotes elásticos.
 */
class BallPhysics {
private:
    // Posición 3D (X, Z en césped, Y elevación/altura)
    float pos_x = 0.0f;
    float pos_y = 0.25f;
    float pos_z = 0.0f;

    // Vector de velocidad
    float vel_x = 0.0f;
    float vel_y = 0.0f;
    float vel_z = 0.0f;

    // Parámetros físicos estándar FIFA / Arcade
    float radius = 0.25f;                  // Radio del balón en metros
    float mass = 0.43f;                    // Masa en kg
    float ground_friction = 1.85f;         // Desaceleración por fricción en césped
    float air_drag = 0.12f;                // Resistencia aerodinámica
    float restitution = 0.75f;             // Coeficiente de rebote (0.0 = inelástico, 1.0 = perfectamente elástico)
    float ground_bounce_factor = 0.55f;    // Pérdida de energía vertical al botar contra el césped
    float gravity = 19.6f;                 // Gravedad en m/s² (arcade nítido)
    float min_velocity_cutoff = 0.05f;     // Umbral de parada para evitar jittering
    float max_speed = 36.0f;               // Velocidad terminal del disparo

public:
    BallPhysics() = default;

    BallPhysics(float x, float y, float z)
        : pos_x(x), pos_y(y), pos_z(z) {}

    /**
     * @brief Actualiza la integración física de velocidad, posición, fricción y gravedad.
     */
    void update(float delta) {
        if (delta <= 0.0f) return;

        bool airborne = is_airborne();

        if (airborne) {
            // Aplicar gravedad vertical
            vel_y -= gravity * delta;

            // Resistencia aerodinámica en los 3 ejes
            vel_x -= vel_x * air_drag * delta;
            vel_y -= vel_y * air_drag * delta;
            vel_z -= vel_z * air_drag * delta;

            // Integración de posición
            pos_x += vel_x * delta;
            pos_y += vel_y * delta;
            pos_z += vel_z * delta;

            // Detección de impacto contra el suelo
            if (pos_y <= radius) {
                pos_y = radius;
                if (vel_y < -1.5f) {
                    // Rebote vertical contra el césped
                    vel_y = -vel_y * ground_bounce_factor;
                    // Pérdida adicional por rozamiento de impacto en X y Z
                    vel_x *= 0.85f;
                    vel_z *= 0.85f;
                } else {
                    vel_y = 0.0f;
                }
            }
        } else {
            // Balón rodando en el césped: fricción de rodamiento continua
            pos_y = radius;
            vel_y = 0.0f;

            float horizontal_speed = std::sqrt(vel_x * vel_x + vel_z * vel_z);
            if (horizontal_speed > min_velocity_cutoff) {
                float drop = ground_friction * 9.8f * delta;
                float new_speed = std::max(0.0f, horizontal_speed - drop);
                float ratio = new_speed / horizontal_speed;
                vel_x *= ratio;
                vel_z *= ratio;

                pos_x += vel_x * delta;
                pos_z += vel_z * delta;
            } else {
                vel_x = 0.0f;
                vel_z = 0.0f;
            }
        }
    }

    /**
     * @brief Aplica un disparo o pase al balón con dirección, potencia y elevación.
     */
    void kick(float dir_x, float dir_z, float force, float elevation = 0.0f) {
        float len = std::sqrt(dir_x * dir_x + dir_z * dir_z);
        if (len > 0.0001f) {
            dir_x /= len;
            dir_z /= len;
        } else {
            dir_x = 0.0f;
            dir_z = -1.0f;
        }

        force = std::clamp(force, 0.0f, max_speed);
        elevation = std::clamp(elevation, 0.0f, 1.0f);

        vel_x = dir_x * force;
        vel_z = dir_z * force;
        vel_y = elevation * force * 0.55f;
    }

    /**
     * @brief Rebote elástico contra una normal 2D (postes, paredes, vallas de la cancha).
     */
    void bounce(float normal_x, float normal_z, float custom_restitution = -1.0f) {
        float n_len = std::sqrt(normal_x * normal_x + normal_z * normal_z);
        if (n_len > 0.0001f) {
            normal_x /= n_len;
            normal_z /= n_len;
        }

        float dot = vel_x * normal_x + vel_z * normal_z;
        if (dot < 0.0f) { // Solo si se dirige hacia la superficie
            float e = (custom_restitution >= 0.0f) ? custom_restitution : restitution;
            vel_x -= (1.0f + e) * dot * normal_x;
            vel_z -= (1.0f + e) * dot * normal_z;
        }
    }

    /**
     * @brief Aplica un impulso instantáneo tridimensional.
     */
    void apply_impulse(float ix, float iy, float iz) {
        if (mass > 0.001f) {
            vel_x += ix / mass;
            vel_y += iy / mass;
            vel_z += iz / mass;
        }
    }

    /**
     * @brief Conducción suave de balón por parte del jugador al avanzar sobre él.
     */
    void dribble(float move_x, float move_z, float player_speed) {
        float len = std::sqrt(move_x * move_x + move_z * move_z);
        if (len > 0.0001f) {
            move_x /= len;
            move_z /= len;
            float target_speed = std::min(max_speed, player_speed * 1.15f);
            vel_x = move_x * target_speed;
            vel_z = move_z * target_speed;
        }
    }

    /**
     * @brief Reinicia el balón a una posición específica con velocidad cero.
     */
    void reset(float x = 0.0f, float y = 0.25f, float z = 0.0f) {
        pos_x = x;
        pos_y = std::max(radius, y);
        pos_z = z;
        vel_x = 0.0f;
        vel_y = 0.0f;
        vel_z = 0.0f;
    }

    // --- Consultas y Modificadores ---
    [[nodiscard]] bool is_airborne() const noexcept {
        return pos_y > (radius + 0.01f) || std::abs(vel_y) > 0.1f;
    }

    [[nodiscard]] bool is_moving() const noexcept {
        return (vel_x * vel_x + vel_y * vel_y + vel_z * vel_z) > (min_velocity_cutoff * min_velocity_cutoff);
    }

    [[nodiscard]] float get_speed() const noexcept {
        return std::sqrt(vel_x * vel_x + vel_y * vel_y + vel_z * vel_z);
    }

    [[nodiscard]] float get_horizontal_speed() const noexcept {
        return std::sqrt(vel_x * vel_x + vel_z * vel_z);
    }

    // Posición
    [[nodiscard]] float get_pos_x() const noexcept { return pos_x; }
    [[nodiscard]] float get_pos_y() const noexcept { return pos_y; }
    [[nodiscard]] float get_pos_z() const noexcept { return pos_z; }
    void set_position(float x, float y, float z) noexcept {
        pos_x = x; pos_y = y; pos_z = z;
    }

    // Velocidad
    [[nodiscard]] float get_vel_x() const noexcept { return vel_x; }
    [[nodiscard]] float get_vel_y() const noexcept { return vel_y; }
    [[nodiscard]] float get_vel_z() const noexcept { return vel_z; }
    void set_velocity(float vx, float vy, float vz) noexcept {
        vel_x = vx; vel_y = vy; vel_z = vz;
    }

    // Fricción y Restitución
    [[nodiscard]] float get_friction() const noexcept { return ground_friction; }
    void set_friction(float f) noexcept { ground_friction = std::max(0.0f, f); }

    [[nodiscard]] float get_restitution() const noexcept { return restitution; }
    void set_restitution(float r) noexcept { restitution = std::clamp(r, 0.0f, 1.0f); }

    [[nodiscard]] float get_radius() const noexcept { return radius; }
    void set_radius(float r) noexcept { radius = std::max(0.05f, r); }

    [[nodiscard]] float get_mass() const noexcept { return mass; }
    void set_mass(float m) noexcept { mass = std::max(0.05f, m); }
};

} // namespace gtp

#ifdef GODOT_GDEXTENSION_ENABLED
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

/**
 * @brief Enlace GDExtension para el motor de físicas del balón hacia Godot.
 */
class BallMechanics : public Node {
    GDCLASS(BallMechanics, Node)

private:
    gtp::BallPhysics physics;

protected:
    static void _bind_methods();

public:
    BallMechanics() = default;
    ~BallMechanics() override = default;

    void update(double delta);
    void kick(double dir_x, double dir_z, double force, double elevation);
    void bounce(double normal_x, double normal_z, double custom_restitution);
    void apply_impulse(double ix, double iy, double iz);
    void dribble(double move_x, double move_z, double player_speed);
    void reset(double x, double y, double z);

    double get_pos_x() const;
    double get_pos_y() const;
    double get_pos_z() const;
    void set_position(double x, double y, double z);

    double get_vel_x() const;
    double get_vel_y() const;
    double get_vel_z() const;
    void set_velocity(double vx, double vy, double vz);

    double get_speed() const;
    double get_horizontal_speed() const;
    bool is_airborne() const;
    bool is_moving() const;

    double get_friction() const;
    void set_friction(double f);
    double get_restitution() const;
    void set_restitution(double r);
    double get_radius() const;
    void set_radius(double r);
};

} // namespace godot

#else

// Modo Standalone C++ / Fallback
namespace godot {

class BallMechanics {
private:
    gtp::BallPhysics physics;

public:
    BallMechanics() = default;

    void update(double delta) {
        physics.update(static_cast<float>(delta));
    }

    void kick(double dir_x, double dir_z, double force, double elevation = 0.0) {
        physics.kick(static_cast<float>(dir_x), static_cast<float>(dir_z),
                     static_cast<float>(force), static_cast<float>(elevation));
    }

    void bounce(double normal_x, double normal_z, double custom_restitution = -1.0) {
        physics.bounce(static_cast<float>(normal_x), static_cast<float>(normal_z),
                       static_cast<float>(custom_restitution));
    }

    void apply_impulse(double ix, double iy, double iz) {
        physics.apply_impulse(static_cast<float>(ix), static_cast<float>(iy), static_cast<float>(iz));
    }

    void dribble(double move_x, double move_z, double player_speed) {
        physics.dribble(static_cast<float>(move_x), static_cast<float>(move_z),
                        static_cast<float>(player_speed));
    }

    void reset(double x = 0.0, double y = 0.25, double z = 0.0) {
        physics.reset(static_cast<float>(x), static_cast<float>(y), static_cast<float>(z));
    }

    [[nodiscard]] double get_pos_x() const { return static_cast<double>(physics.get_pos_x()); }
    [[nodiscard]] double get_pos_y() const { return static_cast<double>(physics.get_pos_y()); }
    [[nodiscard]] double get_pos_z() const { return static_cast<double>(physics.get_pos_z()); }
    void set_position(double x, double y, double z) {
        physics.set_position(static_cast<float>(x), static_cast<float>(y), static_cast<float>(z));
    }

    [[nodiscard]] double get_vel_x() const { return static_cast<double>(physics.get_vel_x()); }
    [[nodiscard]] double get_vel_y() const { return static_cast<double>(physics.get_vel_y()); }
    [[nodiscard]] double get_vel_z() const { return static_cast<double>(physics.get_vel_z()); }
    void set_velocity(double vx, double vy, double vz) {
        physics.set_velocity(static_cast<float>(vx), static_cast<float>(vy), static_cast<float>(vz));
    }

    [[nodiscard]] double get_speed() const { return static_cast<double>(physics.get_speed()); }
    [[nodiscard]] double get_horizontal_speed() const { return static_cast<double>(physics.get_horizontal_speed()); }
    [[nodiscard]] bool is_airborne() const { return physics.is_airborne(); }
    [[nodiscard]] bool is_moving() const { return physics.is_moving(); }

    [[nodiscard]] double get_friction() const { return static_cast<double>(physics.get_friction()); }
    void set_friction(double f) { physics.set_friction(static_cast<float>(f)); }

    [[nodiscard]] double get_restitution() const { return static_cast<double>(physics.get_restitution()); }
    void set_restitution(double r) { physics.set_restitution(static_cast<float>(r)); }

    [[nodiscard]] double get_radius() const { return static_cast<double>(physics.get_radius()); }
    void set_radius(double r) { physics.set_radius(static_cast<float>(r)); }
};

} // namespace godot

#endif // GODOT_GDEXTENSION_ENABLED

#endif // BALL_MECHANICS_HPP
