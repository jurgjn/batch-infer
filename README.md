# Batch inference of protein structure

Run AlphaFold3 on [Euler](https://scicomp.ethz.ch/wiki/Getting_started_with_clusters) at scale with data pipeline (MSA), and structure prediction steps parallelised across nodes. As an example, the _e. coli_ reference proteome has 4,402 monomers. The data pipeline steps took 2 days with up to 500 CPU jobs running simultaneously. The structure prediction steps took ~4 hours with ~15 GPU jobs running simultaneously. A small number of inputs [failed/had to be re-run](results/alphafold3_ecoli/README.md).
- Data pipeline runs on CPU-only nodes, each input as a separate job. Runtime per input ranges from an hour to a few days. Jobs that run out of RAM/runtime automatically re-start with increased resources.
- Structure prediction runs on nodes with an A100 GPU, typically taking minutes per input. The runtime is predictable from the
[number of input tokens](results/alphafold3_runtime/af3_predict_runtime.ipynb).
We can use this to group inputs by size, and run one structure prediction job per group. This minimizes model startup, recompilation, and job scheduler waiting time.
- Uses [local scratch](https://scicomp.ethz.ch/wiki/Using_local_scratch), compresses input/output with gzip (~5x space/traffic reduction).
- Can use monomer data pipeline output to generate the input for multimer structure prediction. This can speed up interaction screens, e.g. protein-protein or protein-ligand...

## Quick start
Clone the repository & install dependancies:
```
cd /cluster/scratch/$USER
git clone --recurse-submodules https://github.com/jurgjn/batch-infer.git
cd batch-infer
# Switch to develop branch for using pre-computed MSAs
git checkout develop
# Create the batch-infer venv by dry-running tests
./batch-infer alphafold3_test results/alphafold3_test --dry-run | sbatch
```

Copy your AlphaFold 3 model parameters to `~/.alphafold3_model_dir/af3.bin.zst`. The model parameters have to be [obtained from DeepMind on a per-user basis](https://github.com/google-deepmind/alphafold3?tab=readme-ov-file#obtaining-model-parameters).

See [results/alphafold3_datafill](results/alphafold3_datafill) for an example with pre-calculated data pipeline output.
