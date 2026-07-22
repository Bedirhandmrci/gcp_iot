# Adaptive Tabu Search vs. Conflict-Driven Harmony Search for Channel Assignment in Dense IoT Networks

This repository contains the MATLAB implementation, experiment drivers, and raw result data accompanying the paper:

> B. Demirci, "Adaptive Tabu Search versus Conflict-Driven Harmony Search for Channel Assignment in Dense IoT Networks: From DIMACS Benchmarks to Physically-Grounded TSCH Topologies," *submitted to IEEE Internet of Things Journal*, 2026.

**Status:** The manuscript is currently under review. This repository is being actively finalized; a stable, tagged release with full documentation and run instructions will be published upon acceptance.

## Repository Structure

```
gcp_iot/
├── README.md
├── src/                        # Core algorithm implementations
│   ├── tabu_search.m           # Adaptive Tabu Search (Algorithm 1)
│   ├── tabu_search_naive.m     # Naive (non-delta) TS, used for speedup benchmarking
│   ├── harmony_search.m        # Conflict-Driven Harmony Search (Algorithm 2)
│   ├── dsatur_coloring.m       # DSatur constructive baseline
│   ├── greedy_coloring.m       # Randomized degree-ordered greedy seeding
│   ├── calculate_fitness.m     # Conflict-count objective function
│   ├── read_dimacs_graph.m     # DIMACS .col file parser
│   └── generate_iot_topology.m # Phase 2 SINR-derived conflict graph generator
│
├── experiments/                 # Experiment drivers (produce the paper's tables/figures)
│   ├── batch_experiment.m               # Main Phase 1 comparative runs (Tables III, IV)
│   ├── parameter_sensitivity.m          # TS/HS parameter sweeps (Section VI-D)
│   ├── parameter_sensitivity_hs_boundary.m
│   ├── convergence_analysis.m           # Multi-run convergence trajectories (Fig. 6)
│   ├── delta_evaluation_speedtest.m     # Naive vs. delta evaluation benchmark (Table VII)
│   ├── tsch_experiment.m                # Phase 2 Stage A/B driver
│   └── generate_all_figures.m           # Regenerates all figures in the paper
│
├── results/                     # Raw output data underlying the paper's tables
│   ├── GCP_Ablation_RawRuns.csv
│   ├── GCP_Ablation_Results.csv
│   ├── TS_Parameter_Sensitivity.csv
│   ├── HS_Parameter_Sensitivity.csv
│   ├── HS_Parameter_Sensitivity_Easy.csv
│   ├── HS_Parameter_Sensitivity_Boundary.csv
│   ├── DeltaEvaluation_SpeedTest.csv
│   ├── Convergence_DSJC500.1_k16_raw.csv
│   ├── Convergence_le450_5a_k10_raw.csv
│   ├── TSCH_Results.xlsx
│   └── TSCH_Results_SMOKETEST.xlsx
│
├── data/
│   └── instances/               # DIMACS benchmark graphs (.col) used in Phase 1
│
└── figures/                     # Publication-ready figures (as used in the manuscript)
```

## Requirements

- MATLAB (developed and tested on MATLAB, Apple Silicon macOS)
- No additional toolboxes beyond base MATLAB are required unless noted in individual scripts

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/Bedirhandmrci/gcp_iot.git
   ```
2. Open the project root in MATLAB.
3. Run `experiments/batch_experiment.m` to reproduce the Phase 1 DIMACS comparison (Tables III–VI).
4. Run `experiments/tsch_experiment.m` to reproduce the Phase 2 physically-grounded topology comparison (Tables VIII–IX).
5. Run `experiments/generate_all_figures.m` to regenerate all figures from the raw result files in `results/`.

Detailed per-script usage notes will be added as the repository is finalized.

## Data

The `data/instances/` directory contains the 17 DIMACS benchmark graphs used in Phase 1 (`myciel3`–`myciel6`, `david`, `huck`, `games120`, `miles250`, `queen8_8`, `queen13_13`, `DSJC250.5`, `DSJC500.1`, `flat300_28_0`, `le450_5a`, `le450_15b`, `le450_25c`, `fpsol2.i.1`), obtained from the [DIMACS Implementation Challenge](http://dimacs.rutgers.edu/archive/Challenges/) graph coloring benchmark suite.

Phase 2 topologies are generated synthetically at runtime by `src/generate_iot_topology.m` from the physical-layer parameters listed in Table I of the paper (they are not static files, since each topology is instantiated stochastically via a Poisson point process; the specific realizations used in the paper are fixed by random seed for reproducibility).

## Citation

If you use this code or data, please cite the paper (full citation to be added upon publication).

## License

To be determined upon publication.

## Contact

Bedirhan Demirci
Department of Data Science and Analytics, Topkapı University
bedirhandemirci@topkapi.edu.tr
