# Batch inference of protein structure

Run AlphaFold3 on Euler with data pipeline (MSA) and structure prediction steps parallelised across nodes.
- Data pipeline runs on CPU-only nodes, each input as a separate job. Runtime ranges from an hour to a few days. Jobs that run out of RAM/runtime automatically re-start with increased resources.
- Structure prediction runs on nodes with an A100 GPU, typically taking minutes per input. We therefore group inputs by size, and run one structure prediction job per group to minimize model startup, recompilation, and job scheduler waiting time.
- Uses local scratch & compress input/output using gzip (~5x space/traffic reduction).
- We can use monomer data pipeline output to generate the necessary input for multimer structure prediction, this speeds up protein-protein interaction screens

## Quick start

This will run AlphaFold3 for all input .json files at: `results/alphafold3_examples/alphafold3_jsons`

Clone the repository:
```
cd /cluster/scratch/$USER
git clone --recurse-submodules https://github.com/jurgjn/batch-infer.git
```

Edit `results/alphafold3_examples/config.yaml` to point your AlphaFold3 model weights:
```
cat results/alphafold3_examples/config.yaml
```

Start the pipeline with:
```
./batch-infer alphafold3 results/alphafold3_examples | sbatch
```

See [EXAMPLE.ipynb](EXAMPLE.ipynb) for detailed walk-through with all input/output.

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
