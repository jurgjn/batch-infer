# Batch inference of protein structure

Run AlphaFold3 on [Euler](https://scicomp.ethz.ch/wiki/Getting_started_with_clusters) with data pipeline (MSA) and structure prediction steps parallelised across nodes.
- Data pipeline runs on CPU-only nodes, each input as a separate job. Runtime ranges from an hour to a few days. Jobs that run out of RAM/runtime automatically re-start with increased resources.
- Structure prediction runs on nodes with an A100 GPU, typically taking minutes per input. We therefore group inputs by size, and run one structure prediction job per group to minimize model startup, recompilation, and job scheduler waiting time.
- Uses [local scratch](https://scicomp.ethz.ch/wiki/Using_local_scratch), compresses input/output with gzip (~5x space/traffic reduction).
- Can use monomer data pipeline output to generate the necessary input for multimer structure prediction. This can speed up interaction screens, e.g. protein-protein or protein-ligand...

## Quick start
This will run AlphaFold3 for all 
[input .json files](https://github.com/google-deepmind/alphafold3/blob/main/docs/input.md)
in
[results/alphafold3_examples/alphafold3_jsons/](results/alphafold3_examples/alphafold3_jsons/)

Clone the repository:
```
cd /cluster/scratch/$USER
git clone --recurse-submodules https://github.com/jurgjn/batch-infer.git
```

Edit 
[results/alphafold3_examples/config.yaml](results/alphafold3_examples/config.yaml)
to locate your AlphaFold3 model parameters. These are
[obtained from DeepMind on a per-user basis](https://github.com/google-deepmind/alphafold3?tab=readme-ov-file#obtaining-model-parameters).

Start the pipeline with:
```
./batch-infer alphafold3 results/alphafold3_examples | sbatch
```

See [EXAMPLE.ipynb](EXAMPLE.ipynb) for a more detailed walk-through.

---
Table to keep track of AlphaFold3 and related co-folding methods
| Name       | Repo    |
| ---------- | ------- |
| AlphaFold3 | [google-deepmind/alphafold3](https://github.com/google-deepmind/alphafold3) |
| Boltz-1    | [jwohlwend/boltz](https://github.com/jwohlwend/boltz) |
| Chai-1     | [chaidiscovery/chai-lab](https://github.com/chaidiscovery/chai-lab) |
| HelixFold  | [PaddlePaddle/PaddleHelix](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold) |
| OpenFold3  | [(TBD)](https://bsky.app/profile/moalquraishi.bsky.social/post/3lbeqspkunc2w) | 
| Protenix   | [bytedance/Protenix](https://github.com/bytedance/Protenix) |
