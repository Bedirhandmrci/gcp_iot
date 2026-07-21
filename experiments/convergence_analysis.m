% convergence_analysis.m
% FAZ 6: Cok-run ortalama + golgeli guven araligi ile yakinsama analizi.
%
% Orijinal rapordaki Figure 3, TEK bir run'a dayaniyordu (stokastik bir
% algoritma icin yanitlayici olabilir). Bu script, ayni k seviyelerinde
% (Faz 4'te kesfedilen "mucadele bolgesi") 10 bagimsiz run'in ORTALAMA
% yakinsama egrisini ve std sapmasini (golgeli bant olarak) hesaplayip
% cizer. Ayrica Faz 4'te bulunan iyilestirilmis HS parametrelerini
% (HMCR=0.95, PAR=0.1) orijinal ayarla (HMCR=0.85, PAR=0.3) karsilastirir.

clc; clear; close all;

folder_name = 'instances';
max_iter = 1000;
num_runs = 10;

alpha_ts = 0.4; beta_ts = 5;
HMS_fixed = 20;
HMCR_default = 0.85; PAR_default = 0.3;
HMCR_tuned = 0.95;   PAR_tuned = 0.1;

targets = struct( ...
    'file', {'le450_5a.col', 'DSJC500.1.col'}, ...
    'k',    {10,             16} ...
);

for t = 1:length(targets)
    filepath = fullfile(folder_name, targets(t).file);
    if ~isfile(filepath)
        warning('Dosya bulunamadi: %s', targets(t).file);
        continue;
    end
    adj = read_dimacs_graph(filepath);
    k = targets(t).k;
    instance_name = erase(targets(t).file, '.col');

    fprintf('Isleniyor: %s (k=%d)...\n', targets(t).file, k);

    TS_hist = zeros(max_iter, num_runs);
    HS_def_hist = zeros(max_iter, num_runs);
    HS_tuned_hist = zeros(max_iter, num_runs);

    for run = 1:num_runs
        rng(run);
        [~, ~, h] = tabu_search(adj, k, max_iter, alpha_ts, beta_ts, 'greedy');
        TS_hist(:, run) = h;

        rng(run);
        [~, ~, h] = harmony_search(adj, k, max_iter, HMS_fixed, HMCR_default, PAR_default, 'greedy');
        HS_def_hist(:, run) = h;

        rng(run);
        [~, ~, h] = harmony_search(adj, k, max_iter, HMS_fixed, HMCR_tuned, PAR_tuned, 'greedy');
        HS_tuned_hist(:, run) = h;
    end

    % --- Ortalama ve std hesapla (her iterasyon icin, 10 run uzerinden) ---
    TS_mean = mean(TS_hist, 2);       TS_std = std(TS_hist, 0, 2);
    HSd_mean = mean(HS_def_hist, 2);  HSd_std = std(HS_def_hist, 0, 2);
    HSt_mean = mean(HS_tuned_hist, 2); HSt_std = std(HS_tuned_hist, 0, 2);

    % --- Kac run'in tam feasibility'ye ulastigini raporla ---
    TS_success = sum(TS_hist(end,:) == 0);
    HSd_success = sum(HS_def_hist(end,:) == 0);
    HSt_success = sum(HS_tuned_hist(end,:) == 0);
    fprintf('  TS: %d/%d run feasibility''e ulasti | HS-default: %d/%d | HS-tuned: %d/%d\n', ...
        TS_success, num_runs, HSd_success, num_runs, HSt_success, num_runs);

    % --- Ham veriyi kaydet ---
    iter_vec = (1:max_iter)';
    RawTable = table(iter_vec, TS_mean, TS_std, HSd_mean, HSd_std, HSt_mean, HSt_std, ...
        'VariableNames', {'Iteration','TS_Mean','TS_Std','HS_Default_Mean','HS_Default_Std', ...
        'HS_Tuned_Mean','HS_Tuned_Std'});
    writetable(RawTable, sprintf('Convergence_%s_k%d_raw.csv', instance_name, k));

    % --- GOLGELI GUVEN ARALIGI GRAFIGI ---
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 500]);
    hold on;

    x = (1:max_iter)';
    xf = [x; flipud(x)];

    % TS golge (mavi)
    yf = [TS_mean + TS_std; flipud(TS_mean - TS_std)];
    fill(xf, yf, [0.2 0.4 0.9], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, TS_mean, 'b-', 'LineWidth', 1.8, 'DisplayName', 'Tabu Search (Adaptive)');

    % HS-default golge (kirmizi)
    yf = [HSd_mean + HSd_std; flipud(HSd_mean - HSd_std)];
    fill(xf, yf, [0.9 0.2 0.2], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, HSd_mean, 'r--', 'LineWidth', 1.8, 'DisplayName', 'Harmony Search (HMCR=0.85, PAR=0.3)');

    % HS-tuned golge (yesil)
    yf = [HSt_mean + HSt_std; flipud(HSt_mean - HSt_std)];
    fill(xf, yf, [0.2 0.7 0.3], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, HSt_mean, 'g-.', 'LineWidth', 1.8, 'DisplayName', 'Harmony Search (HMCR=0.95, PAR=0.1, Tuned)');

    xlabel('Iterations');
    ylabel('Number of Conflicts (mean \pm std, 10 runs)');
    title(sprintf('Convergence Analysis: %s (k=%d)', targets(t).file, k));
    legend('show', 'Location', 'northeast');
    grid on;
    hold off;

    saveas(fig, sprintf('Convergence_%s_k%d.png', instance_name, k));
    close(fig);
end

fprintf('\nTamamlandi. Her instance icin bir .png grafik ve bir _raw.csv dosyasi kaydedildi.\n');
