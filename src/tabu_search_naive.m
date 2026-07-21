function [best_sol, best_conflicts, history, total_eval_calls] = tabu_search_naive(adj, k, max_iter, alpha, beta)
    % tabu_search_naive: tabu_search.m ile MANTIKSAL OLARAK OZDES, tek
    % fark: her aday hamle (node->color) icin celiski sayisi DELTA
    % EVALUATION ile DEGIL, calculate_fitness() cagrisiyla TUM GRAFI
    % yeniden tarayarak (O(n^2)) hesaplanir.
    %
    % SADECE HIZ KIYASLAMASI (Faz 5) icin var; cozum kalitesi acisindan
    % tabu_search.m ile ayni davranisi sergilemesi beklenir, cunku
    % matematiksel olarak hesaplanan celiski degeri ayni sonucu vermelidir
    % - fark yalnizca HESAPLAMA MALIYETINDEDIR.
    %
    % Outputs (ekstra): total_eval_calls - calculate_fitness'in kac kez
    % cagrildigi (Faz 5 raporunda "degerlendirme sayisi" olarak da
    % kullanilabilir).

    n = size(adj, 1);

    [greedy_sol, ~] = greedy_coloring(adj, false);
    out_of_bounds = (greedy_sol > k);
    greedy_sol(out_of_bounds) = randi([1, k], 1, sum(out_of_bounds));
    current_sol = greedy_sol;

    [current_conflicts, ~] = calculate_fitness(current_sol, adj);
    total_eval_calls = 1;

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

            for c = 1:k
                if c == old_color
                    continue;
                end

                % --- NAIVE (TAM MATRIS) DEGERLENDIRME ---
                % Delta evaluation KULLANILMIYOR: tum cozum kopyalanip
                % tum grafta celiski yeniden sayiliyor (O(n^2)).
                candidate_sol = current_sol;
                candidate_sol(node) = c;
                neighbor_conflicts = calculate_fitness(candidate_sol, adj);
                total_eval_calls = total_eval_calls + 1;

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

            candidate_sol = current_sol;
            candidate_sol(random_node) = random_color;
            current_conflicts = calculate_fitness(candidate_sol, adj);
            total_eval_calls = total_eval_calls + 1;
            current_sol(random_node) = random_color;
        end

        history(iter) = best_conflicts;
    end
end
