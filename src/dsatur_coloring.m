function [colors, k] = dsatur_coloring(adj)
    % dsatur_coloring: Klasik DSatur (Degree of Saturation) algoritmasi.
    % Brelaz (1979)'in orijinal tanimina gore calisir:
    %   - Her adimda, "doygunluk derecesi" (komsularinda kullanilan farkli
    %     renk sayisi) en yuksek olan dugum secilir.
    %   - Esitlik durumunda, orijinal (statik) derecesi en yuksek olan
    %     dugum tercih edilir.
    %   - Secilen dugume, komsularinda kullanilmayan en kucuk renk atanir.
    %
    % Bu fonksiyon deterministiktir (rastgelelik icermez), bu yuzden tek
    % bir cagri yeterlidir; TS/HS gibi 10 kez calistirmaya gerek yoktur.
    % Literaturde en yaygin kullanilan "constructive" baseline algoritma
    % olarak, TS ve HS'in ne kadar katma deger sagladigini gostermek
    % icin kullanilir.
    %
    % Inputs:
    %   adj: n x n binary komsuluk matrisi
    %
    % Outputs:
    %   colors: 1 x n atanan renkler
    %   k: kullanilan toplam renk sayisi

    n = size(adj, 1);
    colors = zeros(1, n);
    degrees = sum(adj, 2);
    sat_degree = zeros(n, 1);
    uncolored = true(n, 1);

    for step = 1:n
        candidates = find(uncolored);

        % 1. kriter: en yuksek doygunluk derecesi
        sat_vals = sat_degree(candidates);
        max_sat = max(sat_vals);
        tied = candidates(sat_vals == max_sat);

        % 2. kriter (esitlik bozucu): en yuksek statik derece
        [~, idx] = max(degrees(tied));
        node = tied(idx);

        % Komsularda kullanilan renkleri bul
        neighbors = find(adj(node, :));
        used_colors = colors(neighbors);
        used_colors = used_colors(used_colors > 0);

        % Kullanilmayan en kucuk rengi ata
        c = 1;
        while ismember(c, used_colors)
            c = c + 1;
        end
        colors(node) = c;
        uncolored(node) = false;

        % Renklenmemis komsularin doygunluk derecesini guncelle
        for j = 1:length(neighbors)
            nb = neighbors(j);
            if uncolored(nb)
                nb_neighbors = find(adj(nb, :));
                nb_colors = colors(nb_neighbors);
                sat_degree(nb) = length(unique(nb_colors(nb_colors > 0)));
            end
        end
    end

    k = max(colors);
end
