function [best_sol, best_conflicts, history] = tabu_search(adj, k, max_iter, alpha, beta, init_mode)
    % tabu_search: Grafik Renklendirme icin Adaptive Tabu Search.
    %
    % Inputs:
    %   adj: n x n binary komsuluk matrisi
    %   k: mevcut fizibilite alt-problemi icin izin verilen maksimum renk
    %   max_iter: k basina maksimum iterasyon
    %   alpha, beta: dinamik tabu tenure kontrol parametreleri
    %   init_mode: 'greedy' (varsayilan) veya 'random' (ablation testi icin)
    %
    % Outputs:
    %   best_sol: en iyi bulunan renk atama vektoru
    %   best_conflicts: en iyi celiski sayisi
    %   history: iterasyon basina en iyi celiski sayisi

    if nargin < 6
        init_mode = 'greedy';
    end

    n = size(adj, 1);

    % --- BASLANGIC COZUMU (ABLATION SWITCH) ---
    if strcmp(init_mode, 'random')
        % Ablation: tamamen rastgele baslangic, greedy seeding YOK
        current_sol = randi([1, k], 1, n);
    else
        % Varsayilan: greedy seeding
        [greedy_sol, ~] = greedy_coloring(adj, false);
        out_of_bounds = (greedy_sol > k);
        greedy_sol(out_of_bounds) = randi([1, k], 1, sum(out_of_bounds));
        current_sol = greedy_sol;
    end

    [current_conflicts, ~] = calculate_fitness(current_sol, adj);

    best_sol = current_sol;
    best_conflicts = current_conflicts;

    tabu_list = zeros(n, k);
    history = zeros(max_iter, 1);

    for iter = 1:max_iter
        if best_conflicts == 0
            history(iter:end) = 0;
            break;
        end

        color_match = (current_sol' == current_sol);
        active_conflicts = adj & color_match;
        conflicting_nodes = find(any(active_conflicts, 2))';

        if isempty(conflicting_nodes)
            break;
        end

        best_neighbor_conflicts = inf;
        best_move_node = -1;
        best_move_color = -1;

        for i = 1:length(conflicting_nodes)
            node = conflicting_nodes(i);
            old_color = current_sol(node);
            neighbors = (adj(node, :) == 1);
            conflicts_old = sum(current_sol(neighbors) == old_color);

            for c = 1:k
                if c == old_color
                    continue;
                end

                conflicts_new = sum(current_sol(neighbors) == c);
                neighbor_conflicts = current_conflicts - conflicts_old + conflicts_new;

                is_tabu = (tabu_list(node, c) >= iter);
                aspiration = (neighbor_conflicts < best_conflicts);

                if ~is_tabu || aspiration
                    if neighbor_conflicts < best_neighbor_conflicts
                        best_neighbor_conflicts = neighbor_conflicts;
                        best_move_node = node;
                        best_move_color = c;
                    end
                end
            end
        end

        if best_move_node ~= -1
            old_color = current_sol(best_move_node);
            current_sol(best_move_node) = best_move_color;
            current_conflicts = best_neighbor_conflicts;

            if current_conflicts < best_conflicts
                best_conflicts = current_conflicts;
                best_sol = current_sol;
            end

            dynamic_tenure = floor(alpha * current_conflicts) + randi([0, beta]);
            tabu_list(best_move_node, old_color) = iter + dynamic_tenure;
        else
            rand_idx = randi(length(conflicting_nodes));
            random_node = conflicting_nodes(rand_idx);
            random_color = randi([1, k]);

            neighbors = (adj(random_node, :) == 1);
            conflicts_old = sum(current_sol(neighbors) == current_sol(random_node));
            conflicts_new = sum(current_sol(neighbors) == random_color);

            current_conflicts = current_conflicts - conflicts_old + conflicts_new;
            current_sol(random_node) = random_color;
        end

        history(iter) = best_conflicts;
    end
end
