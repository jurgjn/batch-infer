[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/jurgjn/batch-infer)

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
module load stack/2025-06 python
cd /cluster/scratch/$USER
git clone --branch develop --recurse-submodules https://github.com/jurgjn/batch-infer.git
cd batch-infer
uv tool install -e . --with-executables-from af3io
```

See [this notebook](results/alphafold3_datafill/run_alphafold.ipynb) for an example with pre-calculated data pipeline output.

## Faster predictions with Anthropic's af3_torch kit
Anthropic's [model-optimization kits](https://github.com/anthropics/uplifting-biomolecular-modeling) include `af3_torch`, a PyTorch port of AlphaFold 3 with fused GPU kernels. It runs the [OpenFold3](https://github.com/aqlaboratory/openfold-3) weights; DeepMind's AlphaFold 3 weights are not supported. The original kit loads only the OpenFold3 preview-2 weights. [This fork](https://github.com/juliabuhmann/uplifting-biomolecular-modeling/tree/add-af3torch-openbind-porter) adds:
- a porter for the OpenFold3 **openbind** weights (`--variant ob`)
- a kernel fix so the kit runs on compute capability 12.0 (RTX PRO 6000)
- a GitHub Action that publishes the image

`alphafold3_datafill_predictions_batched` runs the kit in place of `run_alphafold.py` and packs several inputs into one GPU job (`alphafold3.predictions_batched` in the config), so model start-up and compilation are paid once per job.

Tested only on the **NVIDIA RTX PRO 6000 Blackwell Server Edition (96 GB)** on Euler, 3 recycles, 5 diffusion samples. Measured empirically with batch-infer over many pools of ~4,500 tokens: **7.4 minutes per pool**. Inputs above 4,500 tokens run out of GPU memory and are refused by the batching (`tokens_max`).

1. Pull the published image:
   ```
   apptainer build af3_torch-kit.sif docker://ghcr.io/juliabuhmann/af3_torch-kit:6737cbf
   ```
2. Get the weights (downloads and converts the openbind checkpoint into an empty directory):
   ```
   apptainer exec --bind <weights dir>:/weights/af3_torch af3_torch-kit.sif \
     bash -c 'cd /kit/af3_torch && bash run.sh install --weights /weights/af3_torch --fetch --variant ob'
   ```
3. Copy [examples/af3torch_kit/config.yaml](examples/af3torch_kit/config.yaml) into the run directory, set `container` and `model_dir`, and start as usual:
   ```
   batch-infer start alphafold3_datafill_predictions_batched <run dir>
   ```
   The batching values in the example were measured on the RTX PRO 6000. For other GPUs, re-measure `runtime_table_s`. Pools over `tokens_max` are listed in `alphafold3_predictions/.alphafold3_datafill_predictions_batched.tsv.refused`.
