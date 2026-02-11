```
cd /cluster/scratch/$USER
git clone --recurse-submodules https://github.com/jurgjn/batch-infer.git
cd batch-infer
git checkout develop

module load stack/.2024-06-silent python/3.11.6 eth_proxy
software/smk-simple-slurm-eu/venv-create.sh software/venvs/batch-infer-venv
source software/venvs/batch-infer-venv/bin/activate
pip install alphafold3-polymer-bonds
pip install dockq
```
