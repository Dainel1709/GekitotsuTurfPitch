#include "football_mechanics.hpp"

#ifdef GODOT_GDEXTENSION_ENABLED

namespace godot {

void FootballMechanics::_bind_methods() {
    // Métodos para el cálculo y gestión de estamina
    ClassDB::bind_method(D_METHOD("update_stamina", "delta"), &FootballMechanics::update_stamina);
    ClassDB::bind_method(D_METHOD("drain_stamina", "amount"), &FootballMechanics::drain_stamina);
    ClassDB::bind_method(D_METHOD("get_stamina"), &FootballMechanics::get_stamina);
    ClassDB::bind_method(D_METHOD("set_stamina", "value"), &FootballMechanics::set_stamina);
    ClassDB::bind_method(D_METHOD("get_max_stamina"), &FootballMechanics::get_max_stamina);
    ClassDB::bind_method(D_METHOD("set_max_stamina", "value"), &FootballMechanics::set_max_stamina);

    // Métodos para el control de movimiento y velocidades
    ClassDB::bind_method(D_METHOD("get_base_speed"), &FootballMechanics::get_base_speed);
    ClassDB::bind_method(D_METHOD("set_base_speed", "speed"), &FootballMechanics::set_base_speed);
    ClassDB::bind_method(D_METHOD("get_current_speed"), &FootballMechanics::get_current_speed);
    ClassDB::bind_method(D_METHOD("is_moving"), &FootballMechanics::is_moving);
    ClassDB::bind_method(D_METHOD("set_moving", "moving"), &FootballMechanics::set_moving);
    ClassDB::bind_method(D_METHOD("is_sprinting"), &FootballMechanics::is_sprinting);
    ClassDB::bind_method(D_METHOD("set_sprinting", "sprinting"), &FootballMechanics::set_sprinting);

    // Métodos para cálculo de fuerza y vector de disparo / patada
    ClassDB::bind_method(D_METHOD("calculate_kick_force", "dir_x", "dir_z", "charge_ratio"), &FootballMechanics::calculate_kick_force, DEFVAL(1.0));
    ClassDB::bind_method(D_METHOD("calculate_kick_force_magnitude", "charge_ratio"), &FootballMechanics::calculate_kick_force_magnitude, DEFVAL(1.0));
    ClassDB::bind_method(D_METHOD("get_base_kick_force"), &FootballMechanics::get_base_kick_force);
    ClassDB::bind_method(D_METHOD("set_base_kick_force", "force"), &FootballMechanics::set_base_kick_force);
    ClassDB::bind_method(D_METHOD("get_max_kick_force"), &FootballMechanics::get_max_kick_force);
    ClassDB::bind_method(D_METHOD("set_max_kick_force", "force"), &FootballMechanics::set_max_kick_force);

    // Propiedades expuestas al Inspector de Godot
    ClassDB::add_property("FootballMechanics", PropertyInfo(Variant::FLOAT, "base_speed"), "set_base_speed", "get_base_speed");
    ClassDB::add_property("FootballMechanics", PropertyInfo(Variant::FLOAT, "stamina"), "set_stamina", "get_stamina");
    ClassDB::add_property("FootballMechanics", PropertyInfo(Variant::FLOAT, "max_stamina"), "set_max_stamina", "get_max_stamina");
    ClassDB::add_property("FootballMechanics", PropertyInfo(Variant::FLOAT, "base_kick_force"), "set_base_kick_force", "get_base_kick_force");
    ClassDB::add_property("FootballMechanics", PropertyInfo(Variant::FLOAT, "max_kick_force"), "set_max_kick_force", "get_max_kick_force");
}

void FootballMechanics::update_stamina(double delta) {
    physics.update_stamina(static_cast<float>(delta));
}

double FootballMechanics::get_current_speed() const {
    return static_cast<double>(physics.get_current_speed());
}

double FootballMechanics::get_base_speed() const {
    return static_cast<double>(physics.get_base_speed());
}

void FootballMechanics::set_base_speed(double speed) {
    physics.set_base_speed(static_cast<float>(speed));
}

double FootballMechanics::get_stamina() const {
    return static_cast<double>(physics.get_stamina());
}

void FootballMechanics::set_stamina(double value) {
    physics.set_stamina(static_cast<float>(value));
}

double FootballMechanics::get_max_stamina() const {
    return static_cast<double>(physics.get_max_stamina());
}

void FootballMechanics::set_max_stamina(double value) {
    physics.set_max_stamina(static_cast<float>(value));
}

bool FootballMechanics::is_moving() const {
    return physics.get_is_moving();
}

void FootballMechanics::set_moving(bool moving) {
    physics.set_moving(moving);
}

bool FootballMechanics::is_sprinting() const {
    return physics.get_is_sprinting();
}

void FootballMechanics::set_sprinting(bool sprinting) {
    physics.set_sprinting(sprinting);
}

void FootballMechanics::drain_stamina(double amount) {
    physics.drain_stamina(static_cast<float>(amount));
}

Vector3 FootballMechanics::calculate_kick_force(double dir_x, double dir_z, double charge_ratio) {
    float vx = 0.0f, vy = 0.0f, vz = 0.0f;
    physics.calculate_kick_vector(static_cast<float>(dir_x), static_cast<float>(dir_z),
                                 static_cast<float>(charge_ratio), vx, vy, vz);
    return Vector3(vx, vy, vz);
}

double FootballMechanics::calculate_kick_force_magnitude(double charge_ratio) const {
    return static_cast<double>(physics.calculate_kick_force_magnitude(static_cast<float>(charge_ratio)));
}

double FootballMechanics::get_base_kick_force() const {
    return static_cast<double>(physics.get_base_kick_force());
}

void FootballMechanics::set_base_kick_force(double force) {
    physics.set_base_kick_force(static_cast<float>(force));
}

double FootballMechanics::get_max_kick_force() const {
    return static_cast<double>(physics.get_max_kick_force());
}

void FootballMechanics::set_max_kick_force(double force) {
    physics.set_max_kick_force(static_cast<float>(force));
}

} // namespace godot

#else

// Modo standalone
namespace gtp {
    [[maybe_unused]] inline void dummy_football_registration() noexcept {}
}

#endif // GODOT_GDEXTENSION_ENABLED
