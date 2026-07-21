% parameter_sensitivity_hs_boundary.m
% FAZ 4 - TAMAMLAYICI DENEY
%
% Onceki iki HS taramasi da "tuzak" k degerlerine denk geldi:
%   - k=9 / k=15  -> greedy seeding yetersiz, arama hic ilerleyemiyor
%   - k=11 / k=17 -> greedy seeding zaten yeterli, arama hic gerekmiyor
% Bu script, ikisi arasindaki "gercek mucadele bolgesi"nde
% (orijinal rapordaki Figure 3'te kullanilan mantikla ayni) HS'in
% parametre duyarliligini test eder.

clc; clear; close all;

folder_name = 'instances';
max_iter = 1000;
num_runs = 5;
HMS_fixed = 20;

HMCR_grid = [0.70, 0.85, 0.95];
PAR_grid  = [0.10, 0.30, 0.50];

% SINIR BOLGESI K DEGERLERI
tuning_targets_boundary = struct( ...
    'file', {'le450_5a.col', 'DSJC500.1.col'}, ...
    'k',    {10,             16} ...
);

HS_Sensitivity_Boundary = table();

fprintf('=== HARMONY SEARCH PARAMETRE TARAMASI (SINIR BOLGESI) ===\n');
for t = 1:length(tuning_targets_boundary)
    filepath = fullfile(folder_name, tuning_targets_boundary(t).file);
    if ~isfile(filepath)
        warning('Dosya bulunamadi: %s', tuning_targets_boundary(t).file);
        continue;
    end
    adj = read_dimacs_graph(filepath);
    k = tuning_targets_boundary(t).k;

    for h = 1:length(HMCR_grid)
        for p = 1:length(PAR_grid)
            HMCR = HMCR_grid(h);
            PAR  = PAR_grid(p);

            final_conflicts = zeros(num_runs, 1);
            conv_iter = nan(num_runs, 1);
            run_time = zeros(num_runs, 1);

            for run = 1:num_runs
                rng(run);
                tic;
                [~, best_conf, history] = harmony_search(adj, k, max_iter, HMS_fixed, HMCR, PAR, 'greedy');
                run_time(run) = toc;
                final_conflicts(run) = best_conf;

                zero_idx = find(history == 0, 1);
                if ~isempty(zero_idx)
                    conv_iter(run) = zero_idx;
                end
            end

            feasible_rate = 100 * sum(final_conflicts == 0) / num_runs;
            mean_conv_iter = mean(conv_iter(~isnan(conv_iter)));
            if isnan(mean_conv_iter)
                mean_conv_iter = NaN;
            end

            newRow = table(string(tuning_targets_boundary(t).file), k, HMCR, PAR, ...
                mean(final_conflicts), std(final_conflicts), feasible_rate, ...
                mean_conv_iter, mean(run_time), ...
                'VariableNames', {'Instance','K','HMCR','PAR', ...
                'Mean_FinalConflicts','Std_FinalConflicts','FeasibleRate_Pct', ...
                'Mean_ConvIter','Mean_Time'});

            HS_Sensitivity_Boundary = [HS_Sensitivity_Boundary; newRow];

            fprintf('%s | k=%d | HMCR=%.2f PAR=%.2f -> FeasibleRate=%.0f%%, MeanConflicts=%.2f, ConvIter=%.1f\n', ...
                tuning_targets_boundary(t).file, k, HMCR, PAR, feasible_rate, mean(final_conflicts), mean_conv_iter);
        end
    end
end

writetable(HS_Sensitivity_Boundary, 'HS_Parameter_Sensitivity_Boundary.xlsx');
writetable(HS_Sensitivity_Boundary, 'HS_Parameter_Sensitivity_Boundary.csv', 'Delimiter', ';');

fprintf('\nTamamlandi. HS_Parameter_Sensitivity_Boundary.xlsx kaydedildi.\n');
