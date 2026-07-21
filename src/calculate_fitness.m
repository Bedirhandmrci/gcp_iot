function [conflicts, num_colors] = calculate_fitness(sol, adj)
    % calculate_fitness: Bir renklendirme cozumunun celiski sayisini hesaplar.
    %
    % Inputs:
    %   sol: 1 x n renk atama vektoru
    %   adj: n x n binary komsuluk matrisi
    %
    % Outputs:
    %   conflicts: toplam ihlal (celiskili kenar) sayisi
    %   num_colors: kullanilan farkli renk sayisi

    color_match = (sol' == sol);
    conflicts = sum(sum(triu(adj & color_match, 1)));
    num_colors = length(unique(sol));
end
