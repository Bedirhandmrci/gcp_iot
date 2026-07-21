% generate_all_figures.m
%   - GCP_Ablation_Results.xlsx
%   - TS_Parameter_Sensitivity.xlsx
%   - HS_Parameter_Sensitivity_Boundary.xlsx
%   - DeltaEvaluation_SpeedTest.xlsx
%   - Convergence_le450_5a_k10_raw.csv
%   - Convergence_DSJC500_1_k16_raw.csv
%

clc; clear; close all;

if ~exist('figures', 'dir')
    mkdir('figures');
end

% Ortak renk paleti (makaledeki Python/matplotlib versiyonuyla eslesir)
COLOR_BLUE   = [0.122 0.306 0.612];   % TS
COLOR_RED    = [0.757 0.153 0.176];   % HS
COLOR_GREEN  = [0.180 0.545 0.341];   % HS-tuned
COLOR_GRAY   = [0.533 0.533 0.533];   % DSatur
COLOR_LBLUE  = [0.498 0.659 0.878];   % TS-random (acik ton)
COLOR_LRED   = [0.910 0.604 0.616];   % HS-random (acik ton)

set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 9);

%% ========================================================================
%  FIGURE 1: DSatur vs TS vs HS (main comparison, hard instances)
%  ========================================================================
T = readtable('GCP_Ablation_Results.xlsx');
Tg = T(strcmp(T.Mode, 'greedy'), :);

hard = {'queen8_8.col','queen13_13.col','DSJC250.5.col','DSJC500.1.col', ...
        'flat300_28_0.col','le450_5a.col'};

dsatur_vals = zeros(1, numel(hard));
hs_vals = zeros(1, numel(hard));
ts_vals = zeros(1, numel(hard));
labels = cell(1, numel(hard));

for i = 1:numel(hard)
    row = Tg(strcmp(Tg.Instance, hard{i}), :);
    dsatur_vals(i) = row.DSatur_K;
    hs_vals(i) = row.HS_Mean;
    ts_vals(i) = row.TS_Mean;
    labels{i} = erase(hard{i}, '.col');
end

fig1 = figure('Units', 'inches', 'Position', [0 0 7.0 3.0]);
data = [dsatur_vals; hs_vals; ts_vals]';
b = bar(data, 'grouped');
b(1).FaceColor = COLOR_GRAY;
b(2).FaceColor = COLOR_RED;
b(3).FaceColor = COLOR_BLUE;

set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 15);
ylabel('Number of colors (k)');
legend({'DSatur (baseline)', 'Harmony Search', 'Tabu Search'}, ...
    'Location', 'northwest', 'FontSize', 8);
grid on; box on;

exportgraphics(fig1, 'figures/fig_main_comparison.pdf', 'ContentType', 'vector');
fprintf('fig_main_comparison.pdf kaydedildi.\n');

%% ========================================================================
%  FIGURE 2: Ablation - greedy vs random seeding robustness
%  ========================================================================
picks = {'le450_25c.col','flat300_28_0.col','DSJC250.5.col','le450_5a.col'};

ts_greedy = zeros(1, numel(picks));
ts_random = zeros(1, numel(picks));
hs_greedy = zeros(1, numel(picks));
hs_random = zeros(1, numel(picks));
picklabels = cell(1, numel(picks));

for i = 1:numel(picks)
    rg = T(strcmp(T.Instance, picks{i}) & strcmp(T.Mode, 'greedy'), :);
    rr = T(strcmp(T.Instance, picks{i}) & strcmp(T.Mode, 'random'), :);
    ts_greedy(i) = rg.TS_Mean;
    ts_random(i) = rr.TS_Mean;
    hs_greedy(i) = rg.HS_Mean;
    hs_random(i) = rr.HS_Mean;
    picklabels{i} = erase(picks{i}, '.col');
end

fig2 = figure('Units', 'inches', 'Position', [0 0 7.0 3.0]);
data2 = [ts_greedy; ts_random; hs_greedy; hs_random]';
b2 = bar(data2, 'grouped');
b2(1).FaceColor = COLOR_BLUE;
b2(2).FaceColor = COLOR_LBLUE;
b2(3).FaceColor = COLOR_RED;
b2(4).FaceColor = COLOR_LRED;

set(gca, 'XTickLabel', picklabels);
ylabel('Mean number of colors (k)');
legend({'TS (greedy seed)', 'TS (random seed)', 'HS (greedy seed)', 'HS (random seed)'}, ...
    'Location', 'northwest', 'FontSize', 7, 'NumColumns', 2);
grid on; box on;

exportgraphics(fig2, 'figures/fig_ablation.pdf', 'ContentType', 'vector');
fprintf('fig_ablation.pdf kaydedildi.\n');

%% ========================================================================
%  FIGURE 3: TS parameter sensitivity heatmaps (alpha x beta)
%  ========================================================================
Tts = readtable('TS_Parameter_Sensitivity.xlsx');
ts_instances = unique(Tts.Instance, 'stable');

fig3 = figure('Units', 'inches', 'Position', [0 0 7.2 3.0]);
for i = 1:numel(ts_instances)
    sub = Tts(strcmp(Tts.Instance, ts_instances{i}), :);
    alphas = unique(sub.Alpha);
    betas = sort(unique(sub.Beta), 'descend');

    M = zeros(numel(betas), numel(alphas));
    for a = 1:numel(alphas)
        for bta = 1:numel(betas)
            v = sub.Mean_FinalConflicts(sub.Alpha == alphas(a) & sub.Beta == betas(bta));
            M(bta, a) = v;
        end
    end

    subplot(1, 2, i);
    imagesc(M);
    colormap(gca, flipud(autumn));
    colorbar;
    set(gca, 'XTick', 1:numel(alphas), 'XTickLabel', string(alphas));
    set(gca, 'YTick', 1:numel(betas), 'YTickLabel', string(betas));
    xlabel('\alpha'); ylabel('\beta');
    k_val = sub.K(1);
    title(sprintf('%s (k=%d)', erase(ts_instances{i}, '.col'), k_val), 'FontSize', 9);

    for a = 1:numel(alphas)
        for bta = 1:numel(betas)
            text(a, bta, sprintf('%.1f', M(bta, a)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, ...
                'Color', 'k');
        end
    end
end

exportgraphics(fig3, 'figures/fig_ts_sensitivity.pdf', 'ContentType', 'vector');
fprintf('fig_ts_sensitivity.pdf kaydedildi.\n');

%% ========================================================================
%  FIGURE 4: HS parameter sensitivity heatmaps (HMCR x PAR, boundary regime)
%  ========================================================================
Ths = readtable('HS_Parameter_Sensitivity_Boundary.xlsx');
hs_instances = unique(Ths.Instance, 'stable');

fig4 = figure('Units', 'inches', 'Position', [0 0 7.2 3.0]);
for i = 1:numel(hs_instances)
    sub = Ths(strcmp(Ths.Instance, hs_instances{i}), :);
    hmcrs = unique(sub.HMCR);
    pars = sort(unique(sub.PAR), 'descend');

    M = zeros(numel(pars), numel(hmcrs));
    for h = 1:numel(hmcrs)
        for p = 1:numel(pars)
            v = sub.Mean_FinalConflicts(sub.HMCR == hmcrs(h) & sub.PAR == pars(p));
            M(p, h) = v;
        end
    end

    subplot(1, 2, i);
    imagesc(M);
    colormap(gca, flipud(autumn));
    colorbar;
    set(gca, 'XTick', 1:numel(hmcrs), 'XTickLabel', string(hmcrs));
    set(gca, 'YTick', 1:numel(pars), 'YTickLabel', string(pars));
    xlabel('HMCR'); ylabel('PAR');
    k_val = sub.K(1);
    title(sprintf('%s (k=%d)', erase(hs_instances{i}, '.col'), k_val), 'FontSize', 9);

    for h = 1:numel(hmcrs)
        for p = 1:numel(pars)
            text(h, p, sprintf('%.1f', M(p, h)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, ...
                'Color', 'k');
        end
    end
end

exportgraphics(fig4, 'figures/fig_hs_sensitivity.pdf', 'ContentType', 'vector');
fprintf('fig_hs_sensitivity.pdf kaydedildi.\n');

%% ========================================================================
%  FIGURE 5: Delta evaluation speedup
%  ========================================================================
Tsp = readtable('DeltaEvaluation_SpeedTest.xlsx');
[~, sortIdx] = sort(Tsp.Edges);
Tsp = Tsp(sortIdx, :);

fig5 = figure('Units', 'inches', 'Position', [0 0 3.4 2.6]);
barColors = zeros(height(Tsp), 3);
for i = 1:height(Tsp)
    if Tsp.Speedup_Factor(i) >= 1
        barColors(i, :) = COLOR_BLUE;
    else
        barColors(i, :) = COLOR_RED;
    end
end

b5 = bar(Tsp.Speedup_Factor, 'FaceColor', 'flat');
b5.CData = barColors;

xlabels5 = cell(height(Tsp), 1);
for i = 1:height(Tsp)
    xlabels5{i} = sprintf('%s\n(%d edges)', erase(Tsp.Instance{i}, '.col'), Tsp.Edges(i));
end
set(gca, 'XTickLabel', xlabels5, 'FontSize', 7);
ylabel('Speedup factor (naive / delta)');
yline(1.0, ':', 'Color', [0.4 0.4 0.4]);

for i = 1:height(Tsp)
    v = Tsp.Speedup_Factor(i);
    yoffset = 2; if v <= 1, yoffset = 0.05; end
    text(i, v + yoffset, sprintf('%.1fx', v), ...
        'HorizontalAlignment', 'center', 'FontSize', 7);
end
grid on; box on;

exportgraphics(fig5, 'figures/fig_speedup.pdf', 'ContentType', 'vector');
fprintf('fig_speedup.pdf kaydedildi.\n');

%% ========================================================================
%  FIGURE 6: Multi-run convergence (mean +/- std shaded bands)
%  ========================================================================
configs = { ...
    'Convergence_le450_5a_k10_raw.csv', 'le450\_5a.col (k=10)'; ...
    'Convergence_DSJC500.1_k16_raw.csv', 'DSJC500.1.col (k=16)' ...
};

fig6 = figure('Units', 'inches', 'Position', [0 0 7.2 2.9]);
for i = 1:size(configs, 1)
    Tc = readtable(configs{i, 1});
    x = Tc.Iteration;

    subplot(1, 2, i); hold on;

    % TS (mavi)
    fill([x; flipud(x)], [Tc.TS_Mean + Tc.TS_Std; flipud(Tc.TS_Mean - Tc.TS_Std)], ...
        COLOR_BLUE, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, Tc.TS_Mean, 'Color', COLOR_BLUE, 'LineWidth', 1.4, 'DisplayName', 'Tabu Search');

    % HS-default (kirmizi, kesikli)
    fill([x; flipud(x)], [Tc.HS_Default_Mean + Tc.HS_Default_Std; flipud(Tc.HS_Default_Mean - Tc.HS_Default_Std)], ...
        COLOR_RED, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, Tc.HS_Default_Mean, '--', 'Color', COLOR_RED, 'LineWidth', 1.4, ...
        'DisplayName', 'HS (HMCR=0.85, PAR=0.3)');

    % HS-tuned (yesil, nokta-cizgi)
    fill([x; flipud(x)], [Tc.HS_Tuned_Mean + Tc.HS_Tuned_Std; flipud(Tc.HS_Tuned_Mean - Tc.HS_Tuned_Std)], ...
        COLOR_GREEN, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(x, Tc.HS_Tuned_Mean, '-.', 'Color', COLOR_GREEN, 'LineWidth', 1.4, ...
        'DisplayName', 'HS (HMCR=0.95, PAR=0.1)');

    xlabel('Iteration');
    if i == 1
        ylabel('Mean conflicts (10 runs)');
        legend('show', 'Location', 'northeast', 'FontSize', 6.5);
    end
    title(configs{i, 2}, 'FontSize', 9);
    xlim([0 1000]); ylim([0 inf]);
    grid on; box on;
    hold off;
end

exportgraphics(fig6, 'figures/fig_convergence.pdf', 'ContentType', 'vector');
fprintf('fig_convergence.pdf kaydedildi.\n');

fprintf('\nTum gorseller "figures/" klasorune kaydedildi.\n');
