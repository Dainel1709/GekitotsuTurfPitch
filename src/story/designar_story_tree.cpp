#include "designar_story_tree.hpp"
#include <algorithm>
#include <sstream>

namespace gtp {

std::string DeSiGNARStoryTree::rebalance_story_tree(int combate, int disciplina, int reputacion,
                                                    int goals, int assists, int red_cards, int matchday) {
    // Sincronizar estadísticas base
    stats.combat_technique = combate;
    stats.sports_discipline = disciplina;
    stats.street_reputation = reputacion;
    stats.current_day = std::max(1, matchday);

    // Fórmula del Índice de Balance Narrativo:
    // football_score = disciplina + reputacion + (player_goals + player_assists) * 2
    // street_score   = int(combate * 1.8) + (red_cards_total * 10)
    // balance_delta  = football_score - street_score
    football_score = disciplina + reputacion + (goals + assists) * 2;
    street_score = static_cast<int>(combate * 1.8) + (red_cards * 10);
    balance_delta = football_score - street_score;

    // Clasificación de la rama dominante
    if (balance_delta >= 10) {
        active_branch_id = "ELITE_FOOTBALL";
        active_branch_name = "Rama Élite Deportiva";
    } else if (balance_delta <= -10) {
        active_branch_id = "STREET_BRAWLER";
        active_branch_name = "Rama Submundo Callejero";
    } else {
        active_branch_id = "DUAL_LIFE";
        active_branch_name = "Rama Doble Vida";
    }

    // Rebalancear pesos de nodos pendientes en el árbol binario DeSiGNAR
    if (root) {
        if (root->left) {
            root->left->data.weight = (active_branch_id == "ELITE_FOOTBALL") ? 10 :
                                      (active_branch_id == "DUAL_LIFE" ? 5 : 1);
            if (root->left->left) {
                root->left->left->data.weight = (disciplina <= 0 || red_cards >= 2) ? 100 : 1;
            }
            if (root->left->right) {
                root->left->right->data.weight = (combate >= 22 && matchday >= 4) ? 20 : 2;
            }
        }
        if (root->right) {
            root->right->data.weight = (active_branch_id == "STREET_BRAWLER") ? 10 :
                                       (active_branch_id == "DUAL_LIFE" ? 5 : 1);
            if (root->right->left) {
                root->right->left->data.weight = (disciplina < 10 && matchday >= 6) ? 25 : 2;
            }
            if (root->right->right) {
                root->right->right->data.weight = ((combate >= 25 || street_score > football_score) && matchday >= 8) ? 30 : 3;
            }
        }
    }

    // Seleccionar evento dinámico acorde a la rama dominante y la jornada
    std::ostringstream title_ss;
    std::ostringstream prompt_ss;

    if (active_branch_id == "ELITE_FOOTBALL") {
        title_ss << "Ojeadores en la Grada (J" << matchday << ")";
        prompt_ss << "Los visores del primer equipo siguen cada pase tuyo. "
                  << "Tu perfil futbolístico domina el árbol (Delta +" << balance_delta << "): "
                  << "el Golden Boy está al alcance si mantienes la disciplina y sumas G+A.";
    } else if (active_branch_id == "STREET_BRAWLER") {
        title_ss << "Presión del Submundo (J" << matchday << ")";
        prompt_ss << "Tu fama en el callejón supera al césped (Delta " << balance_delta << "). "
                  << "Promotores clandestinos y pandillas rivales te buscan tras cada partido; "
                  << "las emboscadas y ofertas de pelea acechan.";
    } else {
        title_ss << "Dilema de Doble Vida (J" << matchday << ")";
        prompt_ss << "Caminas sobre la cuerda floja entre la cantera y el asfalto (Delta " << balance_delta << "). "
                  << "Un paso hacia el club o hacia el callejón inclinará tu destino definitivo.";
    }

    dynamic_event_title = title_ss.str();
    dynamic_event_prompt = prompt_ss.str();

    return active_branch_id;
}

} // namespace gtp
