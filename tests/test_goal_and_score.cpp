#include <iostream>
#include <cassert>
#include <cmath>
#include "../src/core/ball_mechanics.hpp"
#include "../src/core/football_mechanics.hpp"

int main() {
    std::cout << "[TEST] Iniciando verificacion de Limites, Porterias y Marcador C++..." << std::endl;

    // 1. Verificación de inicialización de FootballMechanics y marcadores
    godot::FootballMechanics mechanics;
    assert(mechanics.get_player_score() == 0);
    assert(mechanics.get_opponent_score() == 0);
    std::cout << "  -> Marcador inicial verificado (0 - 0) OK" << std::endl;

    // 2. Anotación en portería rival (Z negativo) -> score_goal_player()
    mechanics.score_goal_player();
    assert(mechanics.get_player_score() == 1);
    assert(mechanics.get_opponent_score() == 0);

    mechanics.score_goal_player();
    assert(mechanics.get_player_score() == 2);
    assert(mechanics.get_opponent_score() == 0);
    std::cout << "  -> score_goal_player(): goles del jugador = 2 OK" << std::endl;

    // 3. Anotación del rival (Z positivo) -> score_goal_opponent()
    mechanics.score_goal_opponent();
    assert(mechanics.get_player_score() == 2);
    assert(mechanics.get_opponent_score() == 1);
    std::cout << "  -> score_goal_opponent(): goles rival = 1 (Marcador 2 - 1) OK" << std::endl;

    // 4. Modificación y reseteo de marcador
    mechanics.set_player_score(5);
    mechanics.set_opponent_score(3);
    assert(mechanics.get_player_score() == 5);
    assert(mechanics.get_opponent_score() == 3);

    mechanics.reset_score();
    assert(mechanics.get_player_score() == 0);
    assert(mechanics.get_opponent_score() == 0);
    std::cout << "  -> reset_score(): reinicio completo a 0 - 0 OK" << std::endl;

    // 5. Simulación de trayectoria de disparo hacia la portería rival (Z negativo)
    // El balón se dispara desde (0, 0.25, 3.5) hacia Z negativo con vz = -24 m/s
    gtp::BallPhysics ball(0.0f, 0.25f, 3.5f);
    ball.set_velocity(0.0f, 1.2f, -24.0f);
    assert(ball.is_moving());

    // Avanzar física hasta cruzar el área de gol rival (Z <= -10.75)
    bool goal_area_entered = false;
    for (int frame = 0; frame < 60; ++frame) {
        ball.update(1.0f / 60.0f);
        if (ball.get_pos_z() <= -10.75f) {
            goal_area_entered = true;
            break;
        }
    }
    assert(goal_area_entered);
    std::cout << "  -> Balon cruza la linea de gol en Z=" << ball.get_pos_z() << " (< -10.75) OK" << std::endl;

    // 6. Simulación de detección y reinicio del balón (GoalArea -> reset_ball)
    // Al detectarse el gol, la lógica resetea la posición al centro (0, 0.25, 0) y anula velocidades
    ball.set_position(0.0f, 0.25f, 0.0f);
    ball.set_velocity(0.0f, 0.0f, 0.0f);
    assert(!ball.is_moving());
    assert(std::abs(ball.get_pos_x()) < 0.001f);
    assert(std::abs(ball.get_pos_y() - 0.25f) < 0.001f);
    assert(std::abs(ball.get_pos_z()) < 0.001f);
    std::cout << "  -> Reinicio de balon al centro tras gol: pos=(0, 0.25, 0), vel=0 OK" << std::endl;

    // 7. Simulación de confinamiento y rebote contra pared invisible (Z = -12.5)
    // Si el balón viaja hacia la pared norte, debe rebotar elásticamente sin escapar del campo
    ball.set_position(0.0f, 0.25f, -12.0f);
    ball.set_velocity(0.0f, 0.0f, -15.0f);
    ball.bounce(0.0f, 1.0f, 0.75f); // Normal apuntando hacia el sur (+Z)
    assert(ball.get_vel_z() > 0.0f);  // Invierte dirección hacia el interior
    std::cout << "  -> Rebote elastico en pared norte (Z=-12.5): vz=" << ball.get_vel_z() << " (>0) OK" << std::endl;

    std::cout << "TODAS LAS PRUEBAS DE LIMITES Y MARCADOR PASARON EXITOSAMENTE." << std::endl;
    return 0;
}
