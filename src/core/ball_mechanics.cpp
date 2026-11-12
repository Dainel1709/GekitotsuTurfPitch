#include "ball_mechanics.hpp"

#ifdef GODOT_GDEXTENSION_ENABLED

namespace godot {

void BallMechanics::_bind_methods() {
    // Métodos principales de física y simulación
    ClassDB::bind_method(D_METHOD("update", "delta"), &BallMechanics::update);
    ClassDB::bind_method(D_METHOD("kick", "dir_x", "dir_z", "force", "elevation"), &BallMechanics::kick, DEFVAL(0.0));
    ClassDB::bind_method(D_METHOD("bounce", "normal_x", "normal_z", "custom_restitution"), &BallMechanics::bounce, DEFVAL(-1.0));
    ClassDB::bind_method(D_METHOD("apply_impulse", "ix", "iy", "iz"), &BallMechanics::apply_impulse);
    ClassDB::bind_method(D_METHOD("dribble", "move_x", "move_z", "player_speed"), &BallMechanics::dribble);
    ClassDB::bind_method(D_METHOD("reset", "x", "y", "z"), &BallMechanics::reset, DEFVAL(0.0), DEFVAL(0.25), DEFVAL(0.0));

    // Posición
    ClassDB::bind_method(D_METHOD("get_pos_x"), &BallMechanics::get_pos_x);
    ClassDB::bind_method(D_METHOD("get_pos_y"), &BallMechanics::get_pos_y);
    ClassDB::bind_method(D_METHOD("get_pos_z"), &BallMechanics::get_pos_z);
    ClassDB::bind_method(D_METHOD("set_position", "x", "y", "z"), &BallMechanics::set_position);

    // Velocidad
    ClassDB::bind_method(D_METHOD("get_vel_x"), &BallMechanics::get_vel_x);
    ClassDB::bind_method(D_METHOD("get_vel_y"), &BallMechanics::get_vel_y);
    ClassDB::bind_method(D_METHOD("get_vel_z"), &BallMechanics::get_vel_z);
    ClassDB::bind_method(D_METHOD("set_velocity", "vx", "vy", "vz"), &BallMechanics::set_velocity);

    // Métricas de estado
    ClassDB::bind_method(D_METHOD("get_speed"), &BallMechanics::get_speed);
    ClassDB::bind_method(D_METHOD("get_horizontal_speed"), &BallMechanics::get_horizontal_speed);
    ClassDB::bind_method(D_METHOD("is_airborne"), &BallMechanics::is_airborne);
    ClassDB::bind_method(D_METHOD("is_moving"), &BallMechanics::is_moving);

    // Propiedades físicas
    ClassDB::bind_method(D_METHOD("get_friction"), &BallMechanics::get_friction);
    ClassDB::bind_method(D_METHOD("set_friction", "f"), &BallMechanics::set_friction);
    ClassDB::bind_method(D_METHOD("get_restitution"), &BallMechanics::get_restitution);
    ClassDB::bind_method(D_METHOD("set_restitution", "r"), &BallMechanics::set_restitution);
    ClassDB::bind_method(D_METHOD("get_radius"), &BallMechanics::get_radius);
    ClassDB::bind_method(D_METHOD("set_radius", "r"), &BallMechanics::set_radius);

    // Exponer al Inspector de Godot
    ClassDB::add_property("BallMechanics", PropertyInfo(Variant::FLOAT, "friction"), "set_friction", "get_friction");
    ClassDB::add_property("BallMechanics", PropertyInfo(Variant::FLOAT, "restitution"), "set_restitution", "get_restitution");
    ClassDB::add_property("BallMechanics", PropertyInfo(Variant::FLOAT, "radius"), "set_radius", "get_radius");
}

void BallMechanics::update(double delta) {
    physics.update(static_cast<float>(delta));
}

void BallMechanics::kick(double dir_x, double dir_z, double force, double elevation) {
    physics.kick(static_cast<float>(dir_x), static_cast<float>(dir_z),
                 static_cast<float>(force), static_cast<float>(elevation));
}

void BallMechanics::bounce(double normal_x, double normal_z, double custom_restitution) {
    physics.bounce(static_cast<float>(normal_x), static_cast<float>(normal_z),
                   static_cast<float>(custom_restitution));
}

void BallMechanics::apply_impulse(double ix, double iy, double iz) {
    physics.apply_impulse(static_cast<float>(ix), static_cast<float>(iy), static_cast<float>(iz));
}

void BallMechanics::dribble(double move_x, double move_z, double player_speed) {
    physics.dribble(static_cast<float>(move_x), static_cast<float>(move_z),
                    static_cast<float>(player_speed));
}

void BallMechanics::reset(double x, double y, double z) {
    physics.reset(static_cast<float>(x), static_cast<float>(y), static_cast<float>(z));
}

double BallMechanics::get_pos_x() const { return static_cast<double>(physics.get_pos_x()); }
double BallMechanics::get_pos_y() const { return static_cast<double>(physics.get_pos_y()); }
double BallMechanics::get_pos_z() const { return static_cast<double>(physics.get_pos_z()); }

void BallMechanics::set_position(double x, double y, double z) {
    physics.set_position(static_cast<float>(x), static_cast<float>(y), static_cast<float>(z));
}

double BallMechanics::get_vel_x() const { return static_cast<double>(physics.get_vel_x()); }
double BallMechanics::get_vel_y() const { return static_cast<double>(physics.get_vel_y()); }
double BallMechanics::get_vel_z() const { return static_cast<double>(physics.get_vel_z()); }

void BallMechanics::set_velocity(double vx, double vy, double vz) {
    physics.set_velocity(static_cast<float>(vx), static_cast<float>(vy), static_cast<float>(vz));
}

double BallMechanics::get_speed() const { return static_cast<double>(physics.get_speed()); }
double BallMechanics::get_horizontal_speed() const { return static_cast<double>(physics.get_horizontal_speed()); }
bool BallMechanics::is_airborne() const { return physics.is_airborne(); }
bool BallMechanics::is_moving() const { return physics.is_moving(); }

double BallMechanics::get_friction() const { return static_cast<double>(physics.get_friction()); }
void BallMechanics::set_friction(double f) { physics.set_friction(static_cast<float>(f)); }

double BallMechanics::get_restitution() const { return static_cast<double>(physics.get_restitution()); }
void BallMechanics::set_restitution(double r) { physics.set_restitution(static_cast<float>(r)); }

double BallMechanics::get_radius() const { return static_cast<double>(physics.get_radius()); }
void BallMechanics::set_radius(double r) { physics.set_radius(static_cast<float>(r)); }

} // namespace godot

#else

// Modo standalone
namespace gtp {
    [[maybe_unused]] inline void dummy_ball_registration() noexcept {}
}

#endif // GODOT_GDEXTENSION_ENABLED
