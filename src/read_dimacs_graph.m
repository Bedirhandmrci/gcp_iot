function adjMatrix = read_dimacs_graph(filename)
    % read_dimacs_graph: DIMACS .col dosyasini okur ve komsuluk matrisini dondurur.
    fid = fopen(filename, 'r');
    if fid == -1
        error('File could not be opened. Check the path and filename.');
    end
    numNodes = 0;
    adjMatrix = [];
    while ~feof(fid)
        line = fgetl(fid);
        line = strtrim(line);
        if isempty(line) || line(1) == 'c'
            continue;
        elseif line(1) == 'p'
            parts = strsplit(line, ' ');
            parts = parts(~cellfun(@isempty, parts));
            numNodes = str2double(parts{3});
            adjMatrix = zeros(numNodes, numNodes);
        elseif line(1) == 'e'
            parts = strsplit(line, ' ');
            parts = parts(~cellfun(@isempty, parts));
            u = str2double(parts{2});
            v = str2double(parts{3});
            adjMatrix(u, v) = 1;
            adjMatrix(v, u) = 1;
        end
    end
    fclose(fid);
end
