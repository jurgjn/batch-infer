
include: '../rules/common.smk'

rule alphafold3_summary_scores_run:
    input:
        '{prefix}/alphafold3_predictions/'
    output:
        '{prefix}/alphafold3_summary_confidences.parquet'
    threads: 64
    resources:
        runtime = '4h',
        mem_mb = 262144,
    run:
        prediction_paths = list(Path(input[0]).absolute().glob('*.zip'))#[:10]
        printlen(prediction_paths, 'predictions found')
        summary_confidences = pd.concat(parallel_map(af3io.predictions.read_summary_scores, prediction_paths), axis=0).reset_index(drop=True)
        summary_confidences.astype({'predictions_path': str}).to_parquet(output[0], compression='zstd')

checkpoint alphafold3_summary_batches:
    output:
        'alphafold3_summary_confidences_batches.parquet'
    threads: 64
    resources:
        runtime = '4h',
        mem_mb = 32768,
    run:
        predictions = pd.DataFrame({'predictions_path': [ path.relative_to(Path.cwd()) for path in Path.cwd().glob('**/alphafold3_predictions/*.zip') ]})
        predictions['predictions_prefix'] = [ path.parents[1] for path in predictions['predictions_path'] ]
        batches = (predictions['predictions_prefix'] / 'alphafold3_summary_confidences.parquet').drop_duplicates().map(str)
        batches.to_frame(name='predictions_prefix').to_parquet(output[0], compression='zstd')

def alphafold3_summary_scores_concat_input(wildcards):
    path = checkpoints.alphafold3_summary_batches.get().output[0]
    batches = pd.read_parquet(path)
    print(batches)
    return batches['predictions_prefix'].tolist()

rule alphafold3_summary_scores_concat:
    input:
        alphafold3_summary_scores_concat_input
    output:
        'alphafold3_summary_confidences.parquet'
    threads: 64
    resources:
        runtime = '4h',
        mem_mb = 131072,
    run:
        pd.concat([pd.read_parquet(input_file) for input_file in input ], axis=0).reset_index(drop=True).to_parquet(output[0], compression='zstd')

localrules: alphafold3_summary_scores

rule alphafold3_summary_scores:
    input:
        'alphafold3_summary_confidences.parquet'
