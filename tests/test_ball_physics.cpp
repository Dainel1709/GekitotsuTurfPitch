#include <iostream>
#include <cassert>
#include <cmath>
#include "../src/core/ball_mechanics.hpp"
#include "../src/core/football_mechanics.hpp"

int main() {
    std::cout << "[TEST] Iniciando verificacion de BallPhysics y FootballPlayerPhysics..." << std::endl;

    gtp::BallPhysics ball(0.0f, 0.25f, 0.0f);
    assert(std::abs(ball.get_pos_y() - 0.25f) < 0.001f);
    assert(!ball.is_moving());

    // 1. Prueba de Disparo (Kick)
    ball.kick(1.0f, 0.0f, 20.0f, 0.25f);
    assert(ball.is_moving());
    assert(ball.get_vel_x() > 19.9f);
    assert(ball.get_vel_y() > 2.0f); // Elevacion
    std::cout << "  -> Disparo inicial: vx=" << ball.get_vel_x() << ", vy=" << ball.get_vel_y() << " OK" << std::endl;

    // 2. Simulacion de vuelo y caida (Update)
    for (int i = 0; i < 60; ++i) {
        ball.update(1.0f / 60.0f);
    }
    assert(ball.get_pos_x() > 5.0f);
    std::cout << "  -> Vuelo y avance tras 1s: pos_x=" << ball.get_pos_x() << ", pos_y=" << ball.get_pos_y() << " OK" << std::endl;

    // 3. Prueba de Rebote (Bounce) contra pared normal (-1, 0)
    ball.set_velocity(15.0f, 0.0f, 0.0f);
    ball.bounce(-1.0f, 0.0f, 0.8f);
    assert(ball.get_vel_x() < -10.0f); // Debe rebotar invirtiendo direccion horizontal
    std::cout << "  -> Rebote elastico contra pared: vx_bounce=" << ball.get_vel_x() << " OK" << std::endl;

    // 4. Prueba de Friccion y detencion
    ball.set_velocity(2.0f, 0.0f, 0.0f);
    ball.set_position(ball.get_pos_x(), 0.25f, ball.get_pos_z());
    for (int i = 0; i < 180; ++i) {
        ball.update(1.0f / 60.0f);
    }
    assert(ball.get_speed() < 0.1f);
    std::cout << "  -> Friccion en cesped: el balon se detiene con suavidad (speed=" << ball.get_speed() << ") OK" << std::endl;

    // 5. Prueba de Dribling suave
    ball.dribble(0.0f, 1.0f, 8.0f);
    assert(ball.get_vel_z() > 8.0f);
    std::cout << "  -> Dribling: conduccion del balon en vz=" << ball.get_vel_z() << " OK" << std::endl;

    // 6. Prueba de estamina de jugador al disparar
    gtp::FootballPlayerPhysics player;
    assert(player.get_stamina() == 100.0f);
    player.drain_stamina(20.0f);
    assert(player.get_stamina() == 80.0f);
    std::cout << "  -> Drenaje de estamina de jugador: stamina=" << player.get_stamina() << " OK" << std::endl;

    // 7. Prueba de cálculo de fuerza de patada (C++ Backend)
    float quick_tap_force = player.calculate_kick_force_magnitude(0.0f);
    float full_charge_force = player.calculate_kick_force_magnitude(1.0f);
    assert(quick_tap_force == 16.0f);
    assert(full_charge_force == 28.0f);
    assert(full_charge_force > quick_tap_force);
    std::cout << "  -> Fuerza de disparo: toque=" << quick_tap_force << ", carga max=" << full_charge_force << " OK" << std::endl;

    // 8. Prueba de fatiga física en el disparo (estamina baja)
    player.set_stamina(10.0f); // Estamina crítica
    float fatigued_force = player.calculate_kick_force_magnitude(1.0f);
    assert(fatigued_force < full_charge_force);
    std::cout << "  -> Penalizacion por fatiga: fuerza=" << fatigued_force << " (< " << full_charge_force << ") OK" << std::endl;

    // 9. Prueba de vector de patada y acotación vertical en Y
    float k_vx, k_vy, k_vz;
    player.set_stamina(100.0f);
    player.calculate_kick_vector(1.0f, 0.0f, 1.0f, k_vx, k_vy, k_vz);
    assert(k_vx == 28.0f);
    assert(k_vz == 0.0f);
    assert(k_vy <= 1.6f); // Límite de rebote alto en Y
    std::cout << "  -> Vector 3D patada arcade: vx=" << k_vx << ", vy_elev=" << k_vy << " (limitado en Y) OK" << std::endl;

    // 10. Prueba del sistema de marcador y goles (C++ Backend)
    assert(player.get_player_score() == 0);
    assert(player.get_opponent_score() == 0);
    player.score_goal_player();
    assert(player.get_player_score() == 1);
    assert(player.get_opponent_score() == 0);
    player.score_goal_player();
    player.score_goal_opponent();
    assert(player.get_player_score() == 2);
    assert(player.get_opponent_score() == 1);
    player.reset_score();
    assert(player.get_player_score() == 0);
    assert(player.get_opponent_score() == 0);

    godot::FootballMechanics mechanics;
    assert(mechanics.get_player_score() == 0);
    mechanics.score_goal_player();
    mechanics.score_goal_player();
    mechanics.score_goal_opponent();
    assert(mechanics.get_player_score() == 2);
    assert(mechanics.get_opponent_score() == 1);
    mechanics.reset_score();
    assert(mechanics.get_player_score() == 0);
    assert(mechanics.get_opponent_score() == 0);
    std::cout << "  -> Marcador de partido (C++ score_goal_player / score_goal_opponent / reset): OK" << std::endl;

    std::cout << "TODOS LOS TESTS PASARON EXITOSAMENTE." << std::endl;
    return 0;
}
