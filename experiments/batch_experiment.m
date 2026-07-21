% batch_experiment.m
% FAZ 1: Genisletilmis DIMACS benchmark seti + Greedy vs Random baslangic
% (ablation) deneyi. Her instance icin hem TS hem HS, hem 'greedy' hem
% 'random' init_mode ile num_runs kez calistirilir.

clc; clear; close all;

folder_name = 'instances';

% ---------------------------------------------------------------
% GENISLETILMIS BENCHMARK SETI
% Orijinal 10 instance + yogun/zor kategoriden 7 yeni instance
% ---------------------------------------------------------------
instances = {
    'myciel3.col', 'myciel4.col', 'david.col', 'huck.col', ...
    'myciel5.col', 'games120.col', 'miles250.col', ...
    'myciel6.col', 'le450_5a.col', 'fpsol2.i.1.col', ...
    'queen8_8.col', 'queen13_13.col', 'DSJC250.5.col', ...
    'DSJC500.1.col', 'flat300_28_0.col', 'le450_15b.col', 'le450_25c.col'
};

% ---------------------------------------------------------------
% BILINEN (VEYA EN IYI BILINEN) KROMATIK SAYILAR - %Dev hesaplamasi icin
% NOT: DSJC ve flat ailesi icin bu degerler ISPATLANMIS optimal DEGIL,
% literaturdeki EN IYI BILINEN (best-known) degerlerdir. Bu instance'lar
% icin %Dev yorumlanirken bu ayrim mutlaka belirtilmelidir.
% ---------------------------------------------------------------
kstar_map = containers.Map();
kstar_map('myciel3.col')      = 4;
kstar_map('myciel4.col')      = 5;
kstar_map('david.col')        = 11;
kstar_map('huck.col')         = 11;
kstar_map('myciel5.col')      = 6;
kstar_map('games120.col')     = 9;
kstar_map('miles250.col')     = 8;
kstar_map('myciel6.col')      = 7;
kstar_map('le450_5a.col')     = 5;
kstar_map('fpsol2.i.1.col')   = 65;
kstar_map('queen8_8.col')     = 9;
kstar_map('queen13_13.col')   = 13;
kstar_map('DSJC250.5.col')    = 28;   % best-known
kstar_map('DSJC500.1.col')    = 12;   % best-known
kstar_map('flat300_28_0.col') = 28;   % best-known
kstar_map('le450_15b.col')    = 15;
kstar_map('le450_25c.col')    = 25;

num_instances = length(instances);
num_runs = 10;
max_iter = 1000;

% TABU SEARCH PARAMETRELERI
alpha_ts = 0.4;
beta_ts  = 5;

% HARMONY SEARCH PARAMETRELERI
HMS = 20; HMCR = 0.85; PAR = 0.3;

% ABLATION MODLARI: 'greedy' = orijinal davranis, 'random' = kontrol grubu
init_modes = {'greedy', 'random'};

ResultsTable = table();

% ---------------------------------------------------------------
% HAM RUN VERISI (istatistiksel test icin gerekli)
% Her satir: tek bir run'in tek bir algoritma icin sonucu.
% Bu "long format" tablo, Wilcoxon/Mann-Whitney gibi run-level
% istatistiksel testler icin gereklidir; ozet tablo (mean/std) bunu
% saglamaz.
% ---------------------------------------------------------------
RawResults = table();

fprintf('Batch deneyler basliyor (genisletilmis set + ablation)...\n');

for i = 1:num_instances
    filepath = fullfile(folder_name, instances{i});
    if ~isfile(filepath)
        warning('Dosya %s bulunamadi. Atlaniyor... (instances/ klasorune indirdiniz mi?)', instances{i});
        continue;
    end

    adj = read_dimacs_graph(filepath);
    n = size(adj, 1);
    edges = sum(adj(:)) / 2;
    degrees = sum(adj);

    % Greedy modu icin siki ust sinir
    [~, greedy_k] = greedy_coloring(adj, false);
    % Random modu icin KLASIK (Welsh-Powell) teorik ust sinir
    % (greedy'nin sikilastirdigi sinirdan FARKLI olmali, aksi halde
    % ablation'in amaci gecersiz kalir)
    theoretical_k = max(degrees) + 1;

    % --- DSATUR BASELINE ---
    % Deterministik oldugu icin tek cagri yeterli. Bu, TS/HS'in
    % literaturdeki standart constructive algoritmaya gore sagladigi
    % katma degeri gostermek icin kullanilacak (Faz 2).
    dsatur_tic = tic;
    [~, dsatur_k] = dsatur_coloring(adj);
    dsatur_time = toc(dsatur_tic);

    if isKey(kstar_map, instances{i})
        kstar = kstar_map(instances{i});
    else
        kstar = NaN;
    end

    if ~isnan(kstar)
        dsatur_dev = 100 * (dsatur_k - kstar) / kstar;
    else
        dsatur_dev = NaN;
    end

    fprintf('Isleniyor: %s (Nodes: %d, Edges: %d, Greedy k: %d, DSatur k: %d, Teorik k: %d)\n', ...
        instances{i}, n, edges, greedy_k, dsatur_k, theoretical_k);

    for m = 1:length(init_modes)
        mode = init_modes{m};

        if strcmp(mode, 'greedy')
            start_k = greedy_k;
        else
            start_k = theoretical_k;
        end

        ts_k = zeros(num_runs, 1); ts_t = zeros(num_runs, 1);
        hs_k = zeros(num_runs, 1); hs_t = zeros(num_runs, 1);

        for run = 1:num_runs
            % ------------------- TABU SEARCH -------------------
            rng(run);
            tic;
            curr_k = start_k;
            best_k_ts = curr_k;
            while curr_k > 0
                [~, best_conf, ~] = tabu_search(adj, curr_k, max_iter, alpha_ts, beta_ts, mode);
                if best_conf == 0
                    best_k_ts = curr_k;
                    curr_k = curr_k - 1;
                else
                    break;
                end
            end
            ts_t(run) = toc;
            ts_k(run) = best_k_ts;

            % ------------------ HARMONY SEARCH ------------------
            rng(run);
            tic;
            curr_k = start_k;
            best_k_hs = curr_k;
            while curr_k > 0
                [~, best_conf, ~] = harmony_search(adj, curr_k, max_iter, HMS, HMCR, PAR, mode);
                if best_conf == 0
                    best_k_hs = curr_k;
                    curr_k = curr_k - 1;
                else
                    break;
                end
            end
            hs_t(run) = toc;
            hs_k(run) = best_k_hs;

            % --- Bu run'in ham sonucunu long-format tabloya ekle ---
            rawRowTS = table(string(instances{i}), string(mode), "TS", run, ...
                ts_k(run), ts_t(run), ...
                'VariableNames', {'Instance','Mode','Algorithm','Run','K','Time'});
            rawRowHS = table(string(instances{i}), string(mode), "HS", run, ...
                hs_k(run), hs_t(run), ...
                'VariableNames', {'Instance','Mode','Algorithm','Run','K','Time'});
            RawResults = [RawResults; rawRowTS; rawRowHS];
        end

        % %Dev hesaplamasi (kstar bilinmiyorsa NaN kalir)
        if ~isnan(kstar)
            ts_dev = 100 * (mean(ts_k) - kstar) / kstar;
            hs_dev = 100 * (mean(hs_k) - kstar) / kstar;
        else
            ts_dev = NaN;
            hs_dev = NaN;
        end

        newRow = table(string(instances{i}), string(mode), n, edges, kstar, ...
            dsatur_k, dsatur_dev, dsatur_time, ...
            min(ts_k), max(ts_k), mean(ts_k), std(ts_k), mean(ts_t), ts_dev, ...
            min(hs_k), max(hs_k), mean(hs_k), std(hs_k), mean(hs_t), hs_dev, ...
            'VariableNames', {'Instance', 'Mode', 'Nodes', 'Edges', 'Kstar', ...
            'DSatur_K', 'DSatur_Dev', 'DSatur_Time', ...
            'TS_Best', 'TS_Worst', 'TS_Mean', 'TS_Std', 'TS_Time', 'TS_Dev', ...
            'HS_Best', 'HS_Worst', 'HS_Mean', 'HS_Std', 'HS_Time', 'HS_Dev'});

        ResultsTable = [ResultsTable; newRow];
    end
end

% ---------------------------------------------------------------
% SONUCLARI KAYDET
% ---------------------------------------------------------------
numeric_vars = {'DSatur_Dev','DSatur_Time','TS_Mean','TS_Std','TS_Time','TS_Dev','HS_Mean','HS_Std','HS_Time','HS_Dev'};
for v = 1:length(numeric_vars)
    ResultsTable.(numeric_vars{v}) = round(ResultsTable.(numeric_vars{v}), 4);
end

excel_filename = 'GCP_Ablation_Results.xlsx';
writetable(ResultsTable, excel_filename);

csv_filename = 'GCP_Ablation_Results.csv';
writetable(ResultsTable, csv_filename, 'Delimiter', ';');

fprintf('\nTamamlandi. Ozet sonuclar %s ve %s dosyalarina kaydedildi.\n', excel_filename, csv_filename);
fprintf('Toplam satir sayisi: %d (instance x mode kombinasyonu)\n', height(ResultsTable));

% ---------------------------------------------------------------
% HAM RUN VERISINI KAYDET (istatistiksel test icin)
% ---------------------------------------------------------------
raw_excel_filename = 'GCP_Ablation_RawRuns.xlsx';
writetable(RawResults, raw_excel_filename);

raw_csv_filename = 'GCP_Ablation_RawRuns.csv';
writetable(RawResults, raw_csv_filename, 'Delimiter', ';');

fprintf('Ham run verisi %s ve %s dosyalarina kaydedildi.\n', raw_excel_filename, raw_csv_filename);
fprintf('Toplam ham satir sayisi: %d (instance x mode x algoritma x run)\n', height(RawResults));
