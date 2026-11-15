#include <iostream>
#include <cassert>
#include <cmath>
#include "../src/physics/combat/combat_mechanics.hpp"
#include "../src/story/designar_story_tree.hpp"

int main() {
    std::cout << "[TEST] Iniciando verificacion de FighterCombatLogic y consecuencias narrativas..." << std::endl;

    // 1. Verificación de inicialización
    gtp::FighterCombatLogic player(100.0f, 20.0f, 65.0f);
    gtp::FighterCombatLogic rival(100.0f, 15.0f, 65.0f);

    assert(player.get_health() == 100.0f);
    assert(player.can_punch());
    std::cout << "  -> Inicializacion de luchadores OK" << std::endl;

    // 2. Ejecución de golpe y cooldown
    bool punched = player.execute_punch();
    assert(punched);
    assert(!player.can_punch()); // En cooldown
    std::cout << "  -> Cooldown tras golpe verificado OK" << std::endl;

    player.update(0.5f); // Supera cooldown de 0.45s
    assert(player.can_punch());
    std::cout << "  -> Recuperacion de golpe tras cooldown OK" << std::endl;

    // 3. Daño y derrota
    rival.take_damage(20.0f);
    assert(rival.get_health() == 80.0f);
    rival.take_damage(80.0f);
    assert(rival.get_health() == 0.0f);
    assert(rival.is_defeated());
    std::cout << "  -> Deteccion de dano y derrota OK" << std::endl;

    // 4. Lógica de IA (acercarse si está lejos, golpear a 1.2s si está cerca)
    gtp::FighterCombatLogic ai(100.0f, 15.0f, 65.0f);
    bool should_punch = false;
    int move_dir = 0;

    // IA en x=500, objetivo en x=200 (distancia = 300 > 65)
    auto state = ai.process_ai_tick(500.0f, 200.0f, 0.1f, should_punch, move_dir);
    assert(state == gtp::AICombatState::APPROACHING);
    assert(move_dir == -1); // Avanza a la izquierda
    assert(!should_punch);
    std::cout << "  -> IA: movimiento hacia el jugador cuando esta lejos OK" << std::endl;

    // IA en x=240, objetivo en x=200 (distancia = 40 <= 65)
    state = ai.process_ai_tick(240.0f, 200.0f, 0.6f, should_punch, move_dir);
    assert(move_dir == 0); // No necesita moverse
    assert(!should_punch); // Aún no llega a 1.2s

    state = ai.process_ai_tick(240.0f, 200.0f, 0.65f, should_punch, move_dir); // Total 1.25s >= 1.2s
    assert(state == gtp::AICombatState::ATTACKING);
    assert(should_punch);
    std::cout << "  -> IA: ejecucion de golpe cada 1.2s al estar en rango OK" << std::endl;

    // 5. Verificación de consecuencias narrativas (GekitotsuStoryManager / DeSiGNARStoryTree)
    int prev_combat = gtp::DeSiGNARStoryTree::get_global_stats().combat_technique;
    int prev_rep = gtp::DeSiGNARStoryTree::get_global_stats().street_reputation;
    gtp::DeSiGNARStoryTree tree;
    tree.apply_fight_result(true); // Victoria
    assert(gtp::DeSiGNARStoryTree::get_global_stats().combat_technique == prev_combat + 15);
    assert(gtp::DeSiGNARStoryTree::get_global_stats().street_reputation == prev_rep + 20);
    std::cout << "  -> Consecuencia de Victoria: +15 Combate, +20 Reputacion OK" << std::endl;

    int prev_disc = gtp::DeSiGNARStoryTree::get_global_stats().sports_discipline;
    tree.apply_fight_result(false); // Derrota
    assert(gtp::DeSiGNARStoryTree::get_global_stats().sports_discipline <= prev_disc);
    std::cout << "  -> Consecuencia de Derrota: penalizacion de disciplina/salud OK" << std::endl;

    std::cout << "TODAS LAS PRUEBAS DE COMBATE PASARON EXITOSAMENTE." << std::endl;
    return 0;
}
