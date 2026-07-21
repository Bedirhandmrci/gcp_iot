function [colors, max_k] = greedy_coloring(adj, randomize)
    % greedy_coloring: Derece tabanli baslangic renklendirmesi uretir.
    % randomize=true ise siralamaya kucuk bir rastgele gurultu eklenir
    % (Harmony Memory'de cesitlilik saglamak icin).
    %
    % Inputs:
    %   adj: n x n binary komsuluk matrisi
    %   randomize: true/false
    %
    % Outputs:
    %   colors: 1 x n atanan renkler
    %   max_k: kullanilan renk sayisi

    n = size(adj, 1);
    degrees = sum(adj);

    if randomize
        noise = rand(1, n) * 0.5;
        [~, order] = sort(degrees + noise, 'descend');
    else
        [~, order] = sort(degrees, 'descend');
    end

    colors = zeros(1, n);

    for i = 1:n
        node = order(i);
        neighbors = (adj(node, :) == 1);
        neighbor_colors = colors(neighbors);
        neighbor_colors = neighbor_colors(neighbor_colors > 0);

        c = 1;
        while ismember(c, neighbor_colors)
            c = c + 1;
        end
        colors(node) = c;
    end

    max_k = max(colors);
end
