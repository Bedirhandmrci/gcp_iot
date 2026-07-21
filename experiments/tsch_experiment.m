% tsch_experiment.m
% FAZ 2: TSCH / IEEE 802.15.4e Endustriyel IoT Aglarinda Kanal Atamasi.
%
% ONEMLI: Once SMOKE_TEST = true ile calistir (birkac dakika surer).
% Hatasiz bittiğini ve sureleri gordukten SONRA SMOKE_TEST = false yapip
% tam olcekli deneyi baslat -- aksi halde saatlerce suren, hatali/anlamsiz
% sonuclar veren bir kosuya kor kor girersin (bir onceki calistirmada oldugu gibi).
%
% BU SURUMDE DUZELTILEN IKI SORUN:
%   1) find_ts_feasible_k'da, TS ilk denemede basarisiz olursa fonksiyon
%      SESSIZCE varsayilan (yanlis) degerleri "basari" gibi donduruyordu.
%      Artik any_success bayragiyla acikca basarisizligi raporluyor.
%   2) Asama A, "HS-TS farkinin maksimum oldugu k'yi bul" seklinde otomatik
%      genisleyen bir aramaydi; bu fiziksel graflarda fark k kucüldukce
%      SINIRSIZ artabiliyor (ic maksimum yok), bu da aramanin hep
%      hard_cap'e carpmasina ve anlamsiz derecede kucuk bir k secilmesine
%      yol aciyordu. Artik SABIT, kucuk bir offset sweep'i (Faz 1 Fig 3/4
%      tarzi) kullaniliyor -- "en iyisini bul" degil "birkac noktayi olc".
clc; clear; close all;

% ================== CALISMA MODU ==================
SMOKE_TEST = false;   % alpha=3.0 dogrulandi, artik tam kosuya hazir

if SMOKE_TEST
    regimes             = {'sparse'};
    N_values              = 80;
    num_topology_seeds    = 1;
    num_runs               = 3;
    stressA.offsets         = [1, 2];
    stressA.probe_iters     = 100;
    stressA.probe_runs      = 2;
    stressA.max_iter        = 200;
    feasB.iters              = 300;
    feasB.probe_runs         = 2;
    feasB.max_search_steps   = 5;
else
    % ONERI: ilk gercek kosuda REGIMES_TO_RUN'i {'industrial'} yaparak
    % SADECE en agir rejimi calistir, gercek sureyi dogrula, SONRA tam
    % listeye gec. Endustriyel tek basina ~2.5 saat civarinda (tipik
    % senaryo tahmini) -- diger ikisi cok daha hizli.
    regimes             = {'sparse', 'urban', 'industrial'};
    N_values              = [500, 1500, 3000];
    num_topology_seeds    = 3;
    num_runs               = 10;
    stressA.offsets         = [1, 2, 3];   % sabit, sinirli sweep -- otomatik "en iyiyi ara" YOK
    stressA.probe_iters     = 300;
    stressA.probe_runs      = 3;
    stressA.max_iter        = 1000;
    feasB.iters              = 3000;
    feasB.probe_runs         = 2;    % 3 -> 2 (Asama B arama maliyetini azaltmak icin)
    feasB.max_search_steps   = 8;    % 15 -> 8 (guvenlik tavani, tipik ihtiyac ~2 adim)
end

% Alt kume calistirmak icin (ör. once sadece endustriyel): asagidaki
% satiri degistir, ör. REGIMES_TO_RUN = {'industrial'};
REGIMES_TO_RUN = regimes;
keepIdx = ismember(regimes, REGIMES_TO_RUN);
regimes = regimes(keepIdx);
N_values = N_values(keepIdx);

init_mode      = 'greedy';
feasB.epsilon  = 0.5;

% ---------------- Fiziksel Katman (TSCH / IEEE 802.15.4e, 2.4 GHz) ----------------
phys.FreqHz        = 2.4e9;
phys.TxPowerDBm     = 0;
phys.NoiseFloorDBm  = -95;
phys.SinrThreshDB   = 4;
phys.NumChannels    = 16;

regime_ple     = struct('sparse', 2.5, 'urban', 3.0, 'industrial', 3.8);
regime_sigma   = struct('sparse', 4,   'urban', 6,   'industrial', 9);
regime_range   = struct('sparse', 80,  'urban', 30,  'industrial', 15);
regime_density = struct('sparse', 1000, 'urban', 7000, 'industrial', 42000);

% Algoritma parametreleri.
% HMS/HMCR/PAR: Faz 1'in Section VI-D'sinde DIMACS "contested k" rejimi
% icin yeniden ayarlanmis HS degerleri.
%
% alpha_ts: ONEMLI DUZELTME. Orijinal DIMACS-kalibreli deger (0.4) bu
% fiziksel IoT graflarinda (ortalama derece 54-79, DIMACS'tan cok daha
% yogun) TS'in k=dsatur_k'ta (kanitli feasible) bile sifir catismaya
% inememesine yol aciyordu -- kisa tabu hafizasi, aynen HS'nin Faz 1'deki
% orijinal parametrelerle contested k'da yasadigina benzer sekilde,
% arama dongulere kilitleniyordu. alpha_sensitivity_probe.m +
% alpha_validation.m ile 3 rejimde de dogrulandi: alpha=3.0 civarinda
% performans platoya oturuyor (alpha=4.0 ek fayda saglamiyor), ve TS
% neredeyse tum run'larda tam feasibility'ye ulasiyor (6-9/10, rejime
% gore). Eskiden alpha_ts=0.4 kullanmak, TS'i HS'e kiyasla haksiz yere
% "ince ayarsiz" birakiyordu (HS zaten Faz-1-retuned degerleri
% kullaniyordu) -- bu artik duzeltildi, karsilastirma simdi adil.
alpha_ts = 3.0; beta_ts = 5;
HMS = 20; HMCR = 0.95; PAR = 0.1;

% ---------------- Ana Dongu ----------------
StressRows      = table();
SweepRows       = table();   % Faz 1 Fig 3/4 tarzi, "en iyiyi secme" iddiasi olmayan ham sweep
FeasibilityRows = table();

fprintf('--- FAZ 2: TSCH / IEEE 802.15.4e Fiziksel Ag Simulasyonu (2 asamali) ---\n');
fprintf('--- MOD: %s ---\n\n', ternary(SMOKE_TEST, 'SMOKE TEST (hizli dogrulama)', 'TAM OLCEKLI DENEY'));

total_start = tic;
total_instances = numel(regimes) * num_topology_seeds;
inst_counter = 0;

for i = 1:length(regimes)
    regime = regimes{i};
    N = N_values(i);

    for tseed = 1:num_topology_seeds
        inst_counter = inst_counter + 1;
        inst_start = tic;
        instance_name = sprintf('TSCH_%s_%dnodes_seed%d', regime, N, tseed);
        fprintf('[%d/%d] %s baslatiliyor...\n', inst_counter, total_instances, instance_name);

        [adj, ~, meta] = generate_iot_topology(N, regime, ...
            'Seed', tseed, ...
            'FreqHz', phys.FreqHz, 'TxPowerDBm', phys.TxPowerDBm, ...
            'NoiseFloorDBm', phys.NoiseFloorDBm, 'SinrThreshDB', phys.SinrThreshDB, ...
            'NumChannels', phys.NumChannels, 'PathLossExp', regime_ple.(regime), ...
            'ShadowSigmaDB', regime_sigma.(regime), 'LinkRangeM', regime_range.(regime), ...
            'Density', regime_density.(regime));

        [~, dsatur_k] = dsatur_coloring(adj);
        fprintf('   Kenar: %d | MeanDeg: %.2f | DSatur_K: %d  (%.1f sn)\n', ...
            meta.NumEdges, meta.MeanDegree, dsatur_k, toc(inst_start));

        % =============== ASAMA A: sabit, sinirli offset sweep ===============
        sweep_t = tic;
        for offset = stressA.offsets
            k_test = dsatur_k - offset;
            if k_test < 1, continue; end
            [ts_p, hs_p] = run_comparison(adj, k_test, stressA.probe_iters, stressA.probe_runs, ...
                alpha_ts, beta_ts, HMS, HMCR, PAR, init_mode);
            SweepRows = [SweepRows; table(string(instance_name), string(regime), tseed, ...
                offset, k_test, mean(ts_p), mean(hs_p), mean(hs_p) - mean(ts_p), ...
                'VariableNames', {'Instance','Regime','TopologySeed','Offset','K', ...
                'TS_ProbeMean','HS_ProbeMean','Gap'})]; %#ok<AGROW>
        end
        fprintf('   Asama A sweep tamamlandi (%.1f sn)\n', toc(sweep_t));

        % Sabit tasarim secimi: sweep'teki EN BUYUK offset (en zorlayici,
        % ONCEDEN belirlenmis nokta -- "gap'i maksimize eden k'yi ara" DEGIL)
        target_k = dsatur_k - stressA.offsets(end);
        cmp_t = tic;
        [ts_c, hs_c] = run_comparison(adj, target_k, stressA.max_iter, num_runs, ...
            alpha_ts, beta_ts, HMS, HMCR, PAR, init_mode);
        [pA, rA] = mw_test(ts_c, hs_c);
        fprintf('   [Asama A] Target_K=%d (sabit offset=%d) | TS=%.1f HS=%.1f | p=%.4g r=%.2f (%.1f sn)\n', ...
            target_k, stressA.offsets(end), mean(ts_c), mean(hs_c), pA, rA, toc(cmp_t));

        StressRows = [StressRows; table(string(instance_name), string(regime), tseed, N, ...
            meta.NumEdges, meta.MeanDegree, dsatur_k, target_k, stressA.offsets(end), ...
            mean(ts_c), std(ts_c), mean(hs_c), std(hs_c), pA, rA, ...
            'VariableNames', {'Instance','Regime','TopologySeed','Nodes','Edges', ...
            'MeanDegree','DSatur_K','Target_K','FixedOffset', ...
            'TS_Mean_Conflicts','TS_Std','HS_Mean_Conflicts','HS_Std', ...
            'MannWhitney_p','RankBiserial_r'})]; %#ok<AGROW>

        % =============== ASAMA B: near-feasibility k (HATASI DUZELTILDI) ===============
        feas_t = tic;
        [feasible_k, ts_feas_mean, steps_used, any_success] = find_ts_feasible_k(adj, dsatur_k, ...
            feasB.iters, feasB.probe_runs, feasB.epsilon, feasB.max_search_steps, ...
            alpha_ts, beta_ts, init_mode);

        if ~any_success
            warning(['%s: TS, dsatur_k=%d dahil test edilen HICBIR k degerinde ' ...
                'feas_epsilon=%.2f altina inemedi (feas_iters=%d yetersiz olabilir). ' ...
                'Karsilastirma dsatur_k ile yapiliyor, ama bu bir "basari" degil.'], ...
                instance_name, dsatur_k, feasB.epsilon, feasB.iters);
        end
        fprintf('   Asama B arama tamamlandi (%.1f sn, %d adim, basari=%d)\n', ...
            toc(feas_t), steps_used, any_success);

        cmpB_t = tic;
        [ts_cB, hs_cB] = run_comparison(adj, feasible_k, feasB.iters, num_runs, ...
            alpha_ts, beta_ts, HMS, HMCR, PAR, init_mode);
        [pB, rB] = mw_test(ts_cB, hs_cB);
        ts_zero = sum(ts_cB == 0);
        hs_zero = sum(hs_cB == 0);
        fprintf(['   [Asama B] Feasible_K=%d | TS 0-conflict:%d/%d HS 0-conflict:%d/%d | ' ...
                 'p=%.4g r=%.2f (%.1f sn)\n'], ...
            feasible_k, ts_zero, num_runs, hs_zero, num_runs, pB, rB, toc(cmpB_t));

        FeasibilityRows = [FeasibilityRows; table(string(instance_name), string(regime), tseed, N, ...
            meta.NumEdges, meta.MeanDegree, dsatur_k, feasible_k, steps_used, any_success, ...
            mean(ts_cB), std(ts_cB), ts_zero, mean(hs_cB), std(hs_cB), hs_zero, pB, rB, ...
            'VariableNames', {'Instance','Regime','TopologySeed','Nodes','Edges', ...
            'MeanDegree','DSatur_K','Feasible_K','SearchSteps','AnySuccess', ...
            'TS_Mean_Conflicts','TS_Std','TS_ZeroConflictRuns', ...
            'HS_Mean_Conflicts','HS_Std','HS_ZeroConflictRuns', ...
            'MannWhitney_p','RankBiserial_r'})]; %#ok<AGROW>

        fprintf('[%d/%d] %s TAMAMLANDI (toplam %.1f sn)\n', ...
            inst_counter, total_instances, instance_name, toc(inst_start));

        % ---- Checkpoint: her instance sonrasi kaydet (uzun kosuyu guvenli kesintiye acar) ----
        save('tsch_checkpoint.mat', 'StressRows', 'SweepRows', 'FeasibilityRows', 'inst_counter');
        fprintf('   (checkpoint kaydedildi: tsch_checkpoint.mat)\n\n');
    end
end

% ---------------- Holm-Bonferroni: her asama kendi ailesi icinde ----------------
StressRows.p_Holm      = holm_bonferroni(StressRows.MannWhitney_p);
FeasibilityRows.p_Holm = holm_bonferroni(FeasibilityRows.MannWhitney_p);

fprintf('=== OZET ===\n');
fprintf('Toplam sure: %.1f dakika\n', toc(total_start) / 60);
fprintf('Asama A anlamli instance: %d/%d\n', sum(StressRows.p_Holm < 0.05), height(StressRows));
fprintf('Asama B anlamli instance: %d/%d | basarisiz arama: %d/%d\n', ...
    sum(FeasibilityRows.p_Holm < 0.05), height(FeasibilityRows), ...
    sum(~FeasibilityRows.AnySuccess), height(FeasibilityRows));

% ---------------- Disa Aktarim ----------------
suffix = ternary(SMOKE_TEST, '_SMOKETEST', '');
writetable(StressRows,      sprintf('TSCH_Results%s.xlsx', suffix), 'Sheet', 'StressRegime_A');
writetable(SweepRows,       sprintf('TSCH_Results%s.xlsx', suffix), 'Sheet', 'Sweep_A_raw');
writetable(FeasibilityRows, sprintf('TSCH_Results%s.xlsx', suffix), 'Sheet', 'FeasibilityRegime_B');
fprintf('Sonuclar TSCH_Results%s.xlsx dosyasina kaydedildi.\n', suffix);


% ================= Yardimci Fonksiyonlar =================

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function [ts_c, hs_c] = run_comparison(adj, k, max_iter, num_runs, ...
        alpha_ts, beta_ts, HMS, HMCR, PAR, init_mode)
    ts_c = zeros(num_runs, 1);
    hs_c = zeros(num_runs, 1);
    for run = 1:num_runs
        rng(run);
        [~, ts_c(run), ~] = tabu_search(adj, k, max_iter, alpha_ts, beta_ts, init_mode);
        rng(run);
        [~, hs_c(run), ~] = harmony_search(adj, k, max_iter, HMS, HMCR, PAR, init_mode);
    end
end

function [pval, r_effect] = mw_test(ts_c, hs_c)
    [pval, ~, stats] = ranksum(ts_c, hs_c, 'method', 'exact');
    n1 = numel(ts_c); n2 = numel(hs_c);
    U = stats.ranksum - n1 * (n1 + 1) / 2;
    r_effect = 1 - 2 * U / (n1 * n2);
end

function [feasible_k, ts_probe_mean, steps_used, any_success] = find_ts_feasible_k(adj, dsatur_k, ...
        feas_iters, feas_probe_runs, feas_epsilon, max_search_steps, alpha_ts, beta_ts, init_mode)
%FIND_TS_FEASIBLE_K k = dsatur_k'dan asagi inerek TS'in (neredeyse) sifir
%   catisma ile cozebildigi en siki k'yi bulur. ARTIK basarisizligi
%   ACIKCA raporluyor (any_success=false) -- onceki surumde bu durumda
%   sessizce yanlis "basari" degerleri donduruluyordu.
    k = dsatur_k;
    feasible_k = NaN;
    ts_probe_mean = NaN;
    steps_used = 0;
    any_success = false;
    while k >= 1 && steps_used < max_search_steps
        step_t = tic;
        ts_c = zeros(feas_probe_runs, 1);
        for r = 1:feas_probe_runs
            rng(r);
            [~, ts_c(r), ~] = tabu_search(adj, k, feas_iters, alpha_ts, beta_ts, init_mode);
        end
        m = mean(ts_c);
        steps_used = steps_used + 1;
        fprintf('      Asama B adim %d: k=%d -> TS_mean_conflict=%.2f (%.1f sn)\n', ...
            steps_used, k, m, toc(step_t));
        if m > feas_epsilon
            break;
        end
        feasible_k = k;
        ts_probe_mean = m;
        any_success = true;
        k = k - 1;
    end
    if ~any_success
        feasible_k = dsatur_k;   % guvenli, dogru bir sekilde "basarisiz" olarak isaretlenmis geri donus
    end
end

function p_corrected = holm_bonferroni(p_values)
    m = numel(p_values);
    [sorted_p, order] = sort(p_values);
    adjusted = zeros(m, 1);
    running_max = 0;
    for k = 1:m
        val = min((m - k + 1) * sorted_p(k), 1);
        running_max = max(running_max, val);
        adjusted(k) = running_max;
    end
    p_corrected = zeros(m, 1);
    p_corrected(order) = adjusted;
end