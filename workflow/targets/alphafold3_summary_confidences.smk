
import af3io, functools, pandas as pd
from pooled_ppi.core import *
from pathlib import Path
from pprint import pprint

rule alphafold3_summary_confidences_run:
    output:
        'summary_confidences.parquet'
    threads: 96
    resources:
        runtime = '4h',
        mem_mb = 98304,
    run:
        prediction_paths = list(Path('./').resolve().glob(f'**/alphafold3_predictions/*.zip'))
        printlen(prediction_paths, 'predictions found')
        summary_confidences = pd.concat(parallel_map(af3io.predictions.read_summary_confidences, prediction_paths), axis=0).reset_index(drop=True)
        summary_confidences.astype({'predictions_path': str}).to_parquet('summary_confidences.parquet', compression='zstd')

localrules: alphafold3_summary_confidences

rule alphafold3_summary_confidences:
    input:
        'summary_confidences.parquet',
