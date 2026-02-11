# _e. coli_ proteome - monomer predictions

- [alphafold3_jsons.ipynb](alphafold3_jsons.ipynb) generates AlphaFold3 .json inputs for every protein
- [alphafold3_msas.ipynb](alphafold3_msas.ipynb) runs the data pipeline steps (~2 days with 500 simultaneous jobs)
    - [retry_alphafold3_msas.ipynb](retry_alphafold3_msas.ipynb) unsuccessfully re-attempts the data pipeline step for three very short sequences (A5A624, P0DPN7, P0AD72)
- [alphafold3_predictions.ipynb](alphafold3_predictions.ipynb) runs the structure prediction steps (~4 hours with ~15 simultaneous GPU jobs)
    - [retry_alphafold3_predictions.ipynb](retry_alphafold3_predictions.ipynb) re-runs structures from one job that failed due to a timeout (~1.5 hours on 3 GPUs)