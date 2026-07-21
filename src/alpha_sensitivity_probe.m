% alpha_sensitivity_probe.m
% TESHIS: Asama B'de TS, k=dsatur_k'ta (kanitlanmis feasible) bile
% 3000 iterasyonda sifira inemiyordu. Hipotez: T = floor(alpha*f(S)) + rand(0,beta)
% formulu, bu graflarin yuksek baslangic catisma sayisinda (yogun IoT
% graflari, DIMACS'tan çok daha yogun) asiri buyuk tenure uretip aramayi
% kilitliyor olabilir. Farkli alpha degerleriyle hizli bir tarama.
clc; clear;

regime = 'industrial';   % en carpici basarisizligin oldugu rejim
N = 3000;
seed = 1;
beta_ts = 5;
test_iters = 3000;
probe_runs = 3;
% GUNCELLEME: ilk tarama (0.02-0.4) TERS yonde bir trend gosterdi --
% alpha KUCULDUKCE catisma ARTTI (kisa tenure = dongu/erken yakalanma).
% Simdi yonu tersine cevirip YUKARI dogru ariyoruz.
alphas_to_test = [0.4, 0.8, 1.2, 1.6, 2.0, 3.0];   % 0.4 = onceki en iyi sonuc

phys.FreqHz=2.4e9; phys.TxPowerDBm=0; phys.NoiseFloorDBm=-95; phys.SinrThreshDB=4; phys.NumChannels=16;
[adj, ~, meta] = generate_iot_topology(N, regime, 'Seed', seed, ...
    'FreqHz', phys.FreqHz, 'TxPowerDBm', phys.TxPowerDBm, 'NoiseFloorDBm', phys.NoiseFloorDBm, ...
    'SinrThreshDB', phys.SinrThreshDB, 'NumChannels', phys.NumChannels, ...
    'PathLossExp', 3.8, 'ShadowSigmaDB', 9, 'LinkRangeM', 15, 'Density', 42000);

[~, dsatur_k] = dsatur_coloring(adj);
fprintf('%s N=%d | MeanDeg=%.1f | DSatur_K=%d (bu k feasible oldugu KANITLI)\n\n', ...
    regime, N, meta.MeanDegree, dsatur_k);

fprintf('%-8s %-15s %-10s\n', 'alpha', 'TS_mean_conf', 'TS_std');
for a = alphas_to_test
    c = zeros(probe_runs, 1);
    for r = 1:probe_runs
        rng(r);
        [~, c(r), ~] = tabu_search(adj, dsatur_k, test_iters, a, beta_ts, 'greedy');
    end
    fprintf('%-8.2f %-15.2f %-10.2f\n', a, mean(c), std(c));
end