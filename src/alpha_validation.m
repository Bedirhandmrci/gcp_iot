% alpha_validation.m
% TESHIS SONUCU: industrial rejiminde alpha=3.0, k=dsatur_k'ta TS'i
% 0.00+-0.00 catisma sonucuna tasidi (3 probe run). Simdi bunu (a) tam
% 10 run ile, (b) her ucu rejimde ayri ayri dogruluyoruz -- optimal alpha
% rejime gore degisebilir (ortalama derece 54-78 arasinda farkli).
clc; clear;

regimes        = {'sparse', 'urban', 'industrial'};
N_values        = [500, 1500, 3000];
seed           = 1;
beta_ts        = 5;
test_iters     = 3000;
num_runs       = 10;
alphas_to_test = [0.4, 1.6, 2.0, 3.0, 4.0];   % mevcut + bulunan aday + biraz otesi

regime_ple     = struct('sparse', 2.5, 'urban', 3.0, 'industrial', 3.8);
regime_sigma   = struct('sparse', 4,   'urban', 6,   'industrial', 9);
regime_range   = struct('sparse', 80,  'urban', 30,  'industrial', 15);
regime_density = struct('sparse', 1000, 'urban', 7000, 'industrial', 42000);
phys.FreqHz=2.4e9; phys.TxPowerDBm=0; phys.NoiseFloorDBm=-95; phys.SinrThreshDB=4; phys.NumChannels=16;

for i = 1:length(regimes)
    regime = regimes{i};
    N = N_values(i);
    [adj, ~, meta] = generate_iot_topology(N, regime, 'Seed', seed, ...
        'FreqHz', phys.FreqHz, 'TxPowerDBm', phys.TxPowerDBm, 'NoiseFloorDBm', phys.NoiseFloorDBm, ...
        'SinrThreshDB', phys.SinrThreshDB, 'NumChannels', phys.NumChannels, ...
        'PathLossExp', regime_ple.(regime), 'ShadowSigmaDB', regime_sigma.(regime), ...
        'LinkRangeM', regime_range.(regime), 'Density', regime_density.(regime));
    [~, dsatur_k] = dsatur_coloring(adj);

    fprintf('\n=== %s (N=%d, MeanDeg=%.1f, DSatur_K=%d) ===\n', regime, N, meta.MeanDegree, dsatur_k);
    fprintf('%-8s %-15s %-10s %-12s\n', 'alpha', 'TS_mean_conf', 'TS_std', 'ZeroRuns');
    for a = alphas_to_test
        c = zeros(num_runs, 1);
        for r = 1:num_runs
            rng(r);
            [~, c(r), ~] = tabu_search(adj, dsatur_k, test_iters, a, beta_ts, 'greedy');
        end
        fprintf('%-8.2f %-15.2f %-10.2f %d/%d\n', a, mean(c), std(c), sum(c==0), num_runs);
    end
end
