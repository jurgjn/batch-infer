# Batch inference of protein structure

Run AlphaFold3 on [Euler](https://scicomp.ethz.ch/wiki/Getting_started_with_clusters) at scale with data pipeline (MSA), and structure prediction steps parallelised across nodes.

As an example, the _e. coli_ reference proteome has 4,402 monomers. The data pipeline steps took 2 days with up to 500 CPU jobs running simultaneously. The structure prediction steps took ~4 hours with ~15 GPU jobs running simultaneously. The data pipeline step failed for three very short sequences (A5A624, P0DPN7, P0AD72).

- Data pipeline runs on CPU-only nodes, each input as a separate job. Runtime per input ranges from an hour to a few days. Jobs that run out of RAM/runtime automatically re-start with increased resources.
- Structure prediction runs on nodes with an A100 GPU, typically taking minutes per input. The runtime is predictable from the
[number of input tokens](results/af3_predict_runtime.ipynb).
We can use this to group inputs by size, and run one structure prediction job per group. This minimizes model startup, recompilation, and job scheduler waiting time.
- Uses [local scratch](https://scicomp.ethz.ch/wiki/Using_local_scratch), compresses input/output with gzip (~5x space/traffic reduction).
- Can use monomer data pipeline output to generate the input for multimer structure prediction. This can speed up interaction screens, e.g. protein-protein or protein-ligand...

## Quick start
This will run AlphaFold3 for all 
[input .json files](https://github.com/google-deepmind/alphafold3/blob/main/docs/input.md)
in
[results/alphafold3_examples/alphafold3_jsons/](results/alphafold3_adhoc_examples/alphafold3_jsons/)

Clone the repository:
```
cd /cluster/scratch/$USER
git clone --recurse-submodules https://github.com/jurgjn/batch-infer.git
cd batch-infer
```

Edit 
[results/alphafold3_adhoc_examples/config.yaml](results/alphafold3_adhoc_examples/config.yaml)
to locate your AlphaFold3 model parameters. These are
[obtained from DeepMind on a per-user basis](https://github.com/google-deepmind/alphafold3?tab=readme-ov-file#obtaining-model-parameters).

Start the pipeline with:
```
./batch-infer alphafold3_onegpu results/alphafold3_adhoc_examples | sbatch
```

See [alphafold3_adhoc_examples.ipynb](results/alphafold3_adhoc_examples/alphafold3_adhoc_examples.ipynb) for a more detailed walk-through.
