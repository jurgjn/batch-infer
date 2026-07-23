
import af3io, functools, pandas as pd
from pooled_ppi.core import *
from pathlib import Path
from pprint import pprint

rule alphafold3_summary_scores_run:
    input:
        '{prefix}/alphafold3_predictions/'
    output:
        '{prefix}/summary_confidences.parquet'
    threads: 64
    resources:
        runtime = '4h',
        mem_mb = 262144,
    run:
        prediction_paths = list(Path(input[0]).resolve().glob('*.zip')).head(100)
        printlen(prediction_paths, 'predictions found')
        summary_confidences = pd.concat(parallel_map(af3io.predictions.read_summary_scores, prediction_paths), axis=0).reset_index(drop=True)
        summary_confidences.astype({'predictions_path': str}).to_parquet(output[0], compression='zstd')

def alphafold3_summary_scores_input():
    predictions = pd.DataFrame({'predictions_path': [ path.relative_to(Path.cwd()) for path in Path.cwd().glob('**/alphafold3_predictions/*.zip') ]})
    predictions['predictions_prefix'] = [ path.parents[1] for path in predictions['predictions_path'] ]
    return (predictions['predictions_prefix'] / 'summary_confidences.parquet').drop_duplicates().map(str)

localrules: alphafold3_summary_scores

rule alphafold3_summary_scores:
    input:
        #'25.12/daint-gh200/summary_confidences.parquet',
        alphafold3_summary_scores_input()
    output:
        'summary_confidences.parquet'
    run:
        pd.concat([pd.read_parquet(input_file) for input_file in input ], axis=0).reset_index(drop=True).to_parquet(output[0], compression='zstd')
