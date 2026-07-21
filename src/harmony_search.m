function [best_sol, best_conflicts, history] = harmony_search(adj, k, max_iter, HMS, HMCR, PAR, init_mode)
    % harmony_search: Grafik Renklendirme icin Conflict-Driven Harmony Search.
    %
    % Inputs:
    %   adj: n x n binary komsuluk matrisi
    %   k: mevcut fizibilite alt-problemi icin izin verilen maksimum renk
    %   max_iter: maksimum iterasyon
    %   HMS, HMCR, PAR: Harmony Search parametreleri
    %   init_mode: 'greedy' (varsayilan) veya 'random' (ablation testi icin)
    %
    % Outputs:
    %   best_sol: en iyi bulunan renk atama vektoru
    %   best_conflicts: en iyi celiski sayisi
    %   history: iterasyon basina en iyi celiski sayisi

    if nargin < 7
        init_mode = 'greedy';
    end

    n = size(adj, 1);
    HM = zeros(HMS, n);
    HM_fitness = zeros(HMS, 1);

    % --- HARMONY MEMORY BASLATMA (ABLATION SWITCH) ---
    for i = 1:HMS
        if strcmp(init_mode, 'random')
            % Ablation: tamamen rastgele baslangic, greedy seeding YOK
            sol = randi([1, k], 1, n);
        else
            % Varsayilan: randomize edilmis greedy seeding
            [sol, ~] = greedy_coloring(adj, true);
            out_of_bounds = (sol > k);
            sol(out_of_bounds) = randi([1, k], 1, sum(out_of_bounds));
        end

        HM(i, :) = sol;
        [HM_fitness(i), ~] = calculate_fitness(HM(i, :), adj);
    end

    history = zeros(max_iter, 1);
    [best_conflicts, best_idx] = min(HM_fitness);
    best_sol = HM(best_idx, :);

    for iter = 1:max_iter
        if best_conflicts == 0
            history(iter:end) = 0;
            break;
        end

        base_idx = randi(HMS);
        new_harmony = HM(base_idx, :);

        color_match = (new_harmony' == new_harmony);
        active_conflicts = adj & color_match;
        conflicting_nodes = find(any(active_conflicts, 2))';

        if ~isempty(conflicting_nodes)
            for idx = 1:length(conflicting_nodes)
                j = conflicting_nodes(idx);

                if rand() < HMCR
                    rand_idx = randi(HMS);
                    new_harmony(j) = HM(rand_idx, j);

                    if rand() < PAR
                        old_color = new_harmony(j);
                        new_color = randi([1, k]);
                        while new_color == old_color && k > 1
                            new_color = randi([1, k]);
                        end
                        new_harmony(j) = new_color;
                    end
                else
                    new_harmony(j) = randi([1, k]);
                end
            end
        end

        [new_conflicts, ~] = calculate_fitness(new_harmony, adj);
        [worst_conflicts, worst_idx] = max(HM_fitness);

        if new_conflicts < worst_conflicts
            HM(worst_idx, :) = new_harmony;
            HM_fitness(worst_idx) = new_conflicts;

            if new_conflicts < best_conflicts
                best_conflicts = new_conflicts;
                best_sol = new_harmony;
            end
        end

        history(iter) = best_conflicts;
    end
end
