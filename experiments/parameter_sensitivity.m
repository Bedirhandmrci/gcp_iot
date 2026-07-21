% parameter_sensitivity.m
% FAZ 4: Parametre Duyarlilik Taramasi
%
% TS icin (alpha, beta) ve HS icin (HMCR, PAR) parametrelerinin, zor/sinir
% durumdaki iki instance uzerinde COZUM KALITESI ve YAKINSAMA HIZI
% uzerindeki etkisini sistematik olarak olcer.
%
% Feasibility dongusu yerine SABIT bir k degeri kullanilir (ana deneyde
% TS'in sinirda kaldigi k), boylece parametrelerin arama dinamigi
% uzerindeki etkisi net gozlemlenebilir.

clc; clear; close all;

folder_name = 'instances';
max_iter = 1000;
num_runs = 5;

% ---------------------------------------------------------------
% TEST EDILECEK INSTANCE'LAR VE SINIR K DEGERLERI
% (Ana deneyde TS'in Best/Worst araliginin tam sinirinda kaldigi k'lar)
% ---------------------------------------------------------------
tuning_targets = struct( ...
    'file', {'le450_5a.col', 'DSJC500.1.col'}, ...
    'k',    {9,              15} ...
);

% ---------------------------------------------------------------
% IKINCI HEDEF SETI: HS'IN ANA DENEYDE ZATEN BASARILI OLDUGU (feasible
% bulabildigi) k seviyeleri. Amac: parametre etkisizliginin SADECE asiri
% siki k'larda mi, yoksa genel olarak mi gozlemlendigini ayirt etmek.
% ---------------------------------------------------------------
tuning_targets_easy = struct( ...
    'file', {'le450_5a.col', 'DSJC500.1.col'}, ...
    'k',    {11,             17} ...
);

% ---------------------------------------------------------------
% TABU SEARCH GRID
% ---------------------------------------------------------------
alpha_grid = [0.2, 0.4, 0.6];
beta_grid  = [0, 5, 10];

TS_Sensitivity = table();

fprintf('=== TABU SEARCH PARAMETRE TARAMASI ===\n');
for t = 1:length(tuning_targets)
    filepath = fullfile(folder_name, tuning_targets(t).file);
    if ~isfile(filepath)
        warning('Dosya bulunamadi: %s', tuning_targets(t).file);
        continue;
    end
    adj = read_dimacs_graph(filepath);
    k = tuning_targets(t).k;

    for a = 1:length(alpha_grid)
        for b = 1:length(beta_grid)
            alpha = alpha_grid(a);
            beta  = beta_grid(b);

            final_conflicts = zeros(num_runs, 1);
            conv_iter = nan(num_runs, 1);
            run_time = zeros(num_runs, 1);

            for run = 1:num_runs
                rng(run);
                tic;
                [~, best_conf, history] = tabu_search(adj, k, max_iter, alpha, beta, 'greedy');
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

            newRow = table(string(tuning_targets(t).file), k, alpha, beta, ...
                mean(final_conflicts), std(final_conflicts), feasible_rate, ...
                mean_conv_iter, mean(run_time), ...
                'VariableNames', {'Instance','K','Alpha','Beta', ...
                'Mean_FinalConflicts','Std_FinalConflicts','FeasibleRate_Pct', ...
                'Mean_ConvIter','Mean_Time'});

            TS_Sensitivity = [TS_Sensitivity; newRow];

            fprintf('%s | k=%d | alpha=%.1f beta=%d -> FeasibleRate=%.0f%%, MeanConflicts=%.2f, ConvIter=%.1f\n', ...
                tuning_targets(t).file, k, alpha, beta, feasible_rate, mean(final_conflicts), mean_conv_iter);
        end
    end
end

writetable(TS_Sensitivity, 'TS_Parameter_Sensitivity.xlsx');
writetable(TS_Sensitivity, 'TS_Parameter_Sensitivity.csv', 'Delimiter', ';');

% ---------------------------------------------------------------
% HARMONY SEARCH GRID
% ---------------------------------------------------------------
HMCR_grid = [0.70, 0.85, 0.95];
PAR_grid  = [0.10, 0.30, 0.50];
HMS_fixed = 20;

HS_Sensitivity = table();

fprintf('\n=== HARMONY SEARCH PARAMETRE TARAMASI ===\n');
for t = 1:length(tuning_targets)
    filepath = fullfile(folder_name, tuning_targets(t).file);
    if ~isfile(filepath)
        continue;
    end
    adj = read_dimacs_graph(filepath);
    k = tuning_targets(t).k;

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

            newRow = table(string(tuning_targets(t).file), k, HMCR, PAR, ...
                mean(final_conflicts), std(final_conflicts), feasible_rate, ...
                mean_conv_iter, mean(run_time), ...
                'VariableNames', {'Instance','K','HMCR','PAR', ...
                'Mean_FinalConflicts','Std_FinalConflicts','FeasibleRate_Pct', ...
                'Mean_ConvIter','Mean_Time'});

            HS_Sensitivity = [HS_Sensitivity; newRow];

            fprintf('%s | k=%d | HMCR=%.2f PAR=%.2f -> FeasibleRate=%.0f%%, MeanConflicts=%.2f, ConvIter=%.1f\n', ...
                tuning_targets(t).file, k, HMCR, PAR, feasible_rate, mean(final_conflicts), mean_conv_iter);
        end
    end
end

writetable(HS_Sensitivity, 'HS_Parameter_Sensitivity.xlsx');
writetable(HS_Sensitivity, 'HS_Parameter_Sensitivity.csv', 'Delimiter', ';');

% ---------------------------------------------------------------
% HS - KOLAY K SEVIYESI TARAMASI (parametre etkisizliginin sadece asiri
% siki k'larda mi gorulduugunu dogrulamak icin)
% ---------------------------------------------------------------
HS_Sensitivity_Easy = table();

fprintf('\n=== HARMONY SEARCH PARAMETRE TARAMASI (KOLAY K) ===\n');
for t = 1:length(tuning_targets_easy)
    filepath = fullfile(folder_name, tuning_targets_easy(t).file);
    if ~isfile(filepath)
        continue;
    end
    adj = read_dimacs_graph(filepath);
    k = tuning_targets_easy(t).k;

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

            newRow = table(string(tuning_targets_easy(t).file), k, HMCR, PAR, ...
                mean(final_conflicts), std(final_conflicts), feasible_rate, ...
                mean_conv_iter, mean(run_time), ...
                'VariableNames', {'Instance','K','HMCR','PAR', ...
                'Mean_FinalConflicts','Std_FinalConflicts','FeasibleRate_Pct', ...
                'Mean_ConvIter','Mean_Time'});

            HS_Sensitivity_Easy = [HS_Sensitivity_Easy; newRow];

            fprintf('%s | k=%d | HMCR=%.2f PAR=%.2f -> FeasibleRate=%.0f%%, MeanConflicts=%.2f, ConvIter=%.1f\n', ...
                tuning_targets_easy(t).file, k, HMCR, PAR, feasible_rate, mean(final_conflicts), mean_conv_iter);
        end
    end
end

writetable(HS_Sensitivity_Easy, 'HS_Parameter_Sensitivity_Easy.xlsx');
writetable(HS_Sensitivity_Easy, 'HS_Parameter_Sensitivity_Easy.csv', 'Delimiter', ';');

fprintf('\nTamamlandi. TS_Parameter_Sensitivity.xlsx, HS_Parameter_Sensitivity.xlsx ve HS_Parameter_Sensitivity_Easy.xlsx kaydedildi.\n');
