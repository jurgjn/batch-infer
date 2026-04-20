
import functools, pandas as pd, af3io, pooled_ppi
from pathlib import Path
from pprint import pprint

rule alphafold3_summary_confidences_run:
    output:
        'summary_confidences.parquetf'
    threads: 1
    resources:
        # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#dynamic-resources
        runtime = lambda wc, attempt: ['1h', '1d', '3d', '7d'][attempt - 1],
        mem_mb = lambda wc, attempt: [12288, 32768, 65536, 131072][attempt - 1]
    run:
        summary_confidences = pd.concat(parallel_map(af3io.predictions.read_summary_confidences, pp.predictions['path']), axis=0).reset_index(drop=True)
        summary_confidences.astype({'predictions_path': str}).to_parquet('summary_confidences.parquet', compression='zstd')

names, = glob_wildcards('alphafold3_predictions/{name}.zip')

localrules: alphafold3_summary_ipsae


pprint(pooled_ppi.predictions.glob_alphafold3_predictions(Path('./')))

rule alphafold3_summary_confidences:
    input:
        'summary_confidences.parquet',
