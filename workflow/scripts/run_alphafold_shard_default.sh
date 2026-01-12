#!/usr/bin/env bash
# Adjust environment to run AF3 based on available hardware
# Run inside the AF3 container replacing `python3 run_alphafold.py`
cd /app/alphafold

echo Running nvidia-smi
nvidia-smi
echo Finished nvidia-smi

echo Starting run_alphafold.py
python3 run_alphafold.py $@
