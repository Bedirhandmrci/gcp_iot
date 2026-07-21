function [A, coords, meta] = generate_iot_topology(N, regime, varargin)
%GENERATE_IOT_TOPOLOGY Physically-grounded SINR-derived IoT conflict graph.
%   (TSCH / IEEE 802.15.4e industrial-WSN calibration)
%
%   [A, COORDS, META] = GENERATE_IOT_TOPOLOGY(N, REGIME) places N IoT
%   devices as a homogeneous Poisson Point Process (PPP) over a square
%   area sized to match the requested deployment REGIME's target device
%   density, then derives a co-channel conflict graph from a genuine
%   SINR calculation: for every candidate pair, the received desired
%   signal power (at the regime's typical link range), the received
%   interference power (from the candidate neighbor, log-distance path
%   loss + log-normal shadowing), and the receiver noise floor are all
%   combined into SINR = Psignal / (Pinterference + Pnoise); an edge is
%   added iff the resulting SINR falls below SinrThreshDB. This is a
%   pairwise, dominant-interferer approximation (see LIMITATION below),
%   but -- unlike a bare received-power/coverage threshold -- it is a
%   true signal-to-interference-plus-noise ratio, honestly named.
%
%   REGIME (case-insensitive) -- calibrated for IEEE 802.15.4e / TSCH
%   industrial wireless sensor deployments (2.4 GHz, short range, high
%   multipath), NOT for LPWAN/cellular-style long-range links:
%       'sparse'      open outdoor / low-clutter industrial compound
%       'urban'       multi-building indoor facility campus
%       'industrial'  ultra-dense factory floor (heavy multipath/NLOS)
%   Density/link-range/path-loss figures below are illustrative
%   order-of-magnitude defaults -- replace with values cited from a
%   specific site survey or standard before using them in the paper.
%
%   Name-Value options (all optional, override regime defaults):
%       'Density'        devices / km^2
%       'NumChannels'    number of orthogonal channels (k upper bound)
%                        (default 16, matching IEEE 802.15.4 @ 2.4 GHz)
%       'FreqHz'         carrier frequency [Hz]              (default 2.4e9)
%       'TxPowerDBm'     transmit power [dBm]                (default 0)
%       'NoiseFloorDBm'  receiver noise floor [dBm]          (default -95)
%       'PathLossExp'    path-loss exponent n                (regime default)
%       'ShadowSigmaDB'  log-normal shadowing std dev [dB]   (regime default)
%       'SinrThreshDB'   minimum usable SINR [dB]            (default 4)
%       'LinkRangeM'     typical device-to-coordinator distance [m]
%       'Seed'           RNG seed, for reproducibility       (default 42)
%
%   OUTPUTS
%       A     N x N sparse logical conflict (adjacency) matrix
%       coords N x 2 device (x, y) coordinates in meters
%       meta  struct with every realized parameter (log this per
%             instance for reproducibility, same spirit as Table I/II)
%
%   MODEL DETAIL
%   Free-space reference path loss at d0 = 1 m is computed from FreqHz
%   via PL(d0) = 20*log10(4*pi*d0*f/c); path loss at distance d is then
%   PL(d) = PL(d0) + 10*n*log10(d/d0). A KD-tree candidate search first
%   bounds the pairs worth evaluating, using the interference-limited,
%   noise-free analytic guard radius
%       R_I = LinkRangeM * 10^(SinrThreshDB / (10*PathLossExp))
%   expanded for the shadowing tail and a conservative margin for the
%   noise term. The FINAL edge decision for every candidate pair is
%   always the exact SINR formula above, with an independent log-normal
%   shadow draw per pair -- so the stochastic shadowing itself produces
%   a smooth, probabilistic connectivity boundary rather than a
%   hand-added smoothing function on top of an analytic cutoff.
%
%   LIMITATION (report this explicitly in the paper): this is a
%   PAIRWISE, DOMINANT-INTERFERER approximation of the true cumulative,
%   multi-interferer SINR seen at a real receiver under simultaneous
%   co-channel transmissions from several neighbors at once. It is a
%   standard, citable simplification in the channel-assignment-as-
%   graph-coloring literature, but it is a modeling choice, not a
%   validated field measurement -- do not present it as the latter.
%
%   EXAMPLE
%       [A, coords, meta] = generate_iot_topology(3000, 'industrial', 'Seed', 7);
%       fprintf('n=%d, edges=%d, mean degree=%.2f, k<=%d\n', ...
%           size(A,1), meta.NumEdges, meta.MeanDegree, meta.k_upper_bound);

    p = inputParser;
    addRequired(p, 'N');
    addRequired(p, 'regime');
    addParameter(p, 'Density', []);
    addParameter(p, 'NumChannels', 16);
    addParameter(p, 'FreqHz', 2.4e9);
    addParameter(p, 'TxPowerDBm', 0);
    addParameter(p, 'NoiseFloorDBm', -95);
    addParameter(p, 'PathLossExp', []);
    addParameter(p, 'ShadowSigmaDB', []);
    addParameter(p, 'SinrThreshDB', 4);
    addParameter(p, 'LinkRangeM', []);
    addParameter(p, 'Seed', 42);
    parse(p, N, regime, varargin{:});
    opt = p.Results;

    rng(opt.Seed);

    % ---- Regime defaults (TSCH / 802.15.4e industrial-WSN calibration) ----
    switch lower(regime)
        case 'sparse'
            defaultDensity   = 1000;   % devices / km^2
            defaultPLE       = 2.5;    % open outdoor, near line-of-sight
            defaultSigma     = 4;      % dB
            defaultLinkRange = 80;     % m
        case 'urban'
            defaultDensity   = 7000;
            defaultPLE       = 3.0;    % indoor, moderate clutter
            defaultSigma     = 6;
            defaultLinkRange = 30;
        case 'industrial'
            defaultDensity   = 42000;
            defaultPLE       = 3.8;    % heavy multipath / metal machinery NLOS
            defaultSigma     = 9;
            defaultLinkRange = 15;
        otherwise
            error('generate_iot_topology:badRegime', ...
                'Unknown regime "%s". Use sparse | urban | industrial.', regime);
    end

    if isempty(opt.Density),       opt.Density       = defaultDensity;   end
    if isempty(opt.PathLossExp),   opt.PathLossExp   = defaultPLE;       end
    if isempty(opt.ShadowSigmaDB), opt.ShadowSigmaDB = defaultSigma;     end
    if isempty(opt.LinkRangeM),    opt.LinkRangeM    = defaultLinkRange; end

    % ---- PPP deployment area sized to hit the target density ----
    areaKm2 = N / opt.Density;
    sideM   = sqrt(areaKm2) * 1000;
    coords  = sideM * rand(N, 2);

    % ---- Free-space reference path loss at 1 m, from carrier frequency ----
    c  = 299792458;       % speed of light, m/s
    d0 = 1;                % reference distance, m
    PL_d0 = 20 * log10(4 * pi * d0 * opt.FreqHz / c);
    pathLossFn = @(d) PL_d0 + 10 * opt.PathLossExp * log10(max(d, d0) / d0);

    % ---- Desired-signal received power at the regime's typical link range ----
    Prx_signal_dBm = opt.TxPowerDBm - pathLossFn(opt.LinkRangeM);
    Prx_signal_mW  = 10 ^ (Prx_signal_dBm / 10);
    Pnoise_mW      = 10 ^ (opt.NoiseFloorDBm / 10);

    % ---- Analytic, noise-free guard radius (candidate-search bound only) ----
    R_I = opt.LinkRangeM * 10 ^ (opt.SinrThreshDB / (10 * opt.PathLossExp));
    shadowSpanM  = R_I * (3 * opt.ShadowSigmaDB / (10 * opt.PathLossExp));
    searchRadius = 1.5 * (R_I + shadowSpanM);   % extra margin for the noise term

    % ---- Efficient candidate-pair search via KD-tree ----
    [idx, dist] = rangesearch(coords, coords, searchRadius);

    edgeRows = cell(N, 1);
    edgeCols = cell(N, 1);
    for i = 1:N
        neighbors = idx{i};
        distances = dist{i};
        mask = neighbors > i;              % each unordered pair once
        nb   = neighbors(mask);
        dd   = max(distances(mask), d0);

        % Independent log-normal shadowing draw per candidate pair --
        % this randomness is what turns a hard SINR threshold into a
        % smooth, probabilistic connectivity boundary across the graph.
        shadowDB       = opt.ShadowSigmaDB * randn(size(dd));
        Prx_interf_dBm = opt.TxPowerDBm - pathLossFn(dd) + shadowDB;
        Prx_interf_mW  = 10 .^ (Prx_interf_dBm / 10);

        SINR_linear = Prx_signal_mW ./ (Prx_interf_mW + Pnoise_mW);
        SINR_dB     = 10 * log10(SINR_linear);

        keep = SINR_dB < opt.SinrThreshDB;   % SINR too low -> co-channel conflict

        edgeRows{i} = repmat(i, sum(keep), 1);
        edgeCols{i} = nb(keep).';
    end
    rows = vertcat(edgeRows{:});
    cols = vertcat(edgeCols{:});
    A = sparse([rows; cols], [cols; rows], true, N, N);

    % ---- Metadata for reproducibility / paper reporting ----
    meta                  = opt;
    meta.AreaKm2           = areaKm2;
    meta.SideM             = sideM;
    meta.RefPathLossDB     = PL_d0;
    meta.DesiredSignalDBm  = Prx_signal_dBm;
    meta.GuardRadiusM      = R_I;
    meta.SearchRadiusM     = searchRadius;
    meta.NumEdges          = nnz(A) / 2;
    meta.MeanDegree        = full(mean(sum(A, 2)));
    meta.k_upper_bound     = opt.NumChannels;
end
