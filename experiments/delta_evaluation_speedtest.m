% delta_evaluation_speedtest.m
% FAZ 5: Delta Evaluation'in naive (tam O(n^2) matris) hesaplamaya gore
% saglakdigi hiz kazancini SAYISAL olarak olcer.
%
% Adillik icin: her iki versiyon da AYNI (kasitli olarak infeasible) k
% degerinde, AYNI sabit iterasyon sayisinda (erken durmadan) calistirilir.
% Boylece "kim once bitirdi" degil, "AYNI ISI kim ne kadar surede yapti"
% olculur.

clc; clear; close all;

folder_name = 'instances';
max_iter = 30;   % Naive versiyon buyuk graflarda yavas olabilir, dusuk tutuyoruz
alpha_ts = 0.4;
beta_ts = 5;
num_runs = 3;    % Hiz olcumu icin 3 run yeterli (kalite degil, sure olculuyor)

% ---------------------------------------------------------------
% KASITLI OLARAK INFEASIBLE K DEGERLERI
% (kromatik sayinin altinda VEYA Faz 4'te 1000 iterasyonda bile
% cozulemedigi kanitlanmis k'lar -> hicbir zaman erken durmaz)
% ---------------------------------------------------------------
speed_targets = struct( ...
    'file', {'myciel4.col', 'queen13_13.col', 'le450_5a.col', 'DSJC500.1.col'}, ...
    'k',    {3,              10,               9,              15} ...
);

SpeedResults = table();

fprintf('=== DELTA EVALUATION vs NAIVE HIZ KIYASLAMASI ===\n');
for t = 1:length(speed_targets)
    filepath = fullfile(folder_name, speed_targets(t).file);
    if ~isfile(filepath)
        warning('Dosya bulunamadi: %s', speed_targets(t).file);
        continue;
    end
    adj = read_dimacs_graph(filepath);
    n = size(adj, 1);
    edges = sum(adj(:)) / 2;
    k = speed_targets(t).k;

    delta_times = zeros(num_runs, 1);
    naive_times = zeros(num_runs, 1);
    naive_eval_calls = zeros(num_runs, 1);

    for run = 1:num_runs
        % --- VECTORIZED DELTA EVALUATION (mevcut tabu_search.m) ---
        rng(run);
        tic;
        [~, ~, ~] = tabu_search(adj, k, max_iter, alpha_ts, beta_ts, 'greedy');
        delta_times(run) = toc;

        % --- NAIVE TAM MATRIS HESAPLAMA ---
        rng(run);
        tic;
        [~, ~, ~, eval_calls] = tabu_search_naive(adj, k, max_iter, alpha_ts, beta_ts);
        naive_times(run) = toc;
        naive_eval_calls(run) = eval_calls;
    end

    mean_delta = mean(delta_times);
    mean_naive = mean(naive_times);
    speedup = mean_naive / mean_delta;

    newRow = table(string(speed_targets(t).file), n, edges, k, max_iter, ...
        mean_delta, mean_naive, speedup, mean(naive_eval_calls), ...
        'VariableNames', {'Instance','Nodes','Edges','K','MaxIter', ...
        'DeltaEval_Time','Naive_Time','Speedup_Factor','Naive_EvalCalls'});

    SpeedResults = [SpeedResults; newRow];

    fprintf('%s (n=%d, e=%d, k=%d): Delta=%.4fs, Naive=%.4fs, Speedup=%.1fx (%.0f eval cagrisi)\n', ...
        speed_targets(t).file, n, edges, k, mean_delta, mean_naive, speedup, mean(naive_eval_calls));
end

writetable(SpeedResults, 'DeltaEvaluation_SpeedTest.xlsx');
writetable(SpeedResults, 'DeltaEvaluation_SpeedTest.csv', 'Delimiter', ';');

fprintf('\nTamamlandi. DeltaEvaluation_SpeedTest.xlsx kaydedildi.\n');
