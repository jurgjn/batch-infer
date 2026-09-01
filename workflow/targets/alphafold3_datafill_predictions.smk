
include: '../rules/common.smk'

include: 'alphafold3_datafill_msas.smk'

# Mock partitioning to run one pool per job for now - should eventually become a checkpoint
def make_singleton_batches_():
    tsv_ = 'alphafold3_predictions/.alphafold3_datafill_predictions.tsv'
    os.makedirs('alphafold3_predictions/', exist_ok=True)
    if not os.path.isfile(tsv_):
        ids_jsons_, = snakemake.io.glob_wildcards('alphafold3_jsons/{id}.json')
        ids_infer_, = snakemake.io.glob_wildcards('alphafold3_predictions/{id}.zip')
        ids_todo_ = set(ids_jsons_) - set(ids_infer_)
        frame_ = pd.DataFrame({'id': sorted(ids_todo_)})
        frame_ = frame_.reset_index()
        frame_ = frame_.rename({'index': 'batch_id'}, axis=1)
        frame_[['id', 'batch_id']].to_csv(tsv_, sep='\t', header=True, index=False)
    return pd.read_csv(tsv_, sep='\t')

ids = make_singleton_batches_().id.tolist()

for batch_id, df_batch in make_singleton_batches_().groupby('batch_id'):
    #print(batch_id)
    #print(df_batch)

    rule: # Run AF3 structure prediction on a subset of .json-s (as implied by id-s)
        name:
            f'alphafold3_datafill_predictions_batch{batch_id}_{len(df_batch)}'
        input:
            json = expand('alphafold3_jsons/{id}.json', id=df_batch.id.tolist()),
            msas = 'alphafold3_msas/.af3io_data_index.json', # trigger missing MSAs
        output:
            cifs = expand('alphafold3_predictions/{id}.zip', id=df_batch.id.tolist()),
        params:
            activate = get_activate(),
            # alphafold3 id-s in the batch; datafill
            alphafold3_ids = ' '.join(df_batch.id.tolist()),
            data_sources = config['alphafold3']['data_sources'],
            # singularity
            singularity_args = config['alphafold3']['predictions']['singularity_args'],
            container = config['alphafold3']['container'],
            # container bind paths
            singularity_bind = (
                '--bind alphafold3_msas:/root/af_input '
                '--bind alphafold3_predictions:/root/af_output '
                f"--bind {config['alphafold3']['model_dir']}:/root/models "
                f"--bind {config['alphafold3']['db_dir']}:/root/public_databases "
                f"--bind {root_path('workflow/scripts')}:/app/scripts "
            ),
            # run_alphafold.py
            run_alphafold_wrapper = config['alphafold3']['predictions']['run_alphafold_wrapper'],
            run_alphafold_args = f"--norun_data_pipeline {config['alphafold3']['predictions']['run_alphafold_args']}",
            run_alphafold_dirs = (
                '--input_dir=/root/af_input '
                '--output_dir=/root/af_output '
                '--model_dir=/root/models '
                '--db_dir=/root/public_databases '
            ),
        retries: config['alphafold3']['predictions']['retries']
        resources:
            runtime = config['alphafold3']['predictions']['runtime'],
            mem_mb = config['alphafold3']['predictions']['mem_mb'],
            # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#dynamic-resources
            #mem_mb = lambda attempt: alphafold3_predictions_mem_mb if isinstance(alphafold3_predictions_mem_mb, int) else alphafold3_predictions_mem_mb[attempt - 1],
            disk_mb = config['alphafold3']['predictions']['disk_mb'],
            slurm_extra = config['alphafold3']['predictions']['slurm_extra'],
        envmodules: *config['envmodules_offline']
        shell: """
            source {params.activate}
            SMKDIR=`pwd`
            mkdir -p $TMPDIR/alphafold3_msas
            ALPHAFOLD3_IDS="{params.alphafold3_ids}"
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                echo ALPHAFOLD3_ID: "$ALPHAFOLD3_ID"
                JSON=alphafold3_jsons/"$ALPHAFOLD3_ID".json
                echo JSON: "$JSON"
                OUTPUT_DIR="$TMPDIR"/alphafold3_msas/
                echo OUTPUT_DIR: "$OUTPUT_DIR"
                af3io data-fill {params.data_sources} --data_dir=alphafold3_msas --json_path="$JSON" --output_dir="$OUTPUT_DIR"
            done
            ls -l $TMPDIR/alphafold3_msas
            
            mkdir -p $TMPDIR/alphafold3_predictions
            # run_alphafold.py caches compiled JAX code in /tmp/alphafold_cache;
            # bind it to node-local scratch via predictions/singularity_args
            mkdir -p $TMPDIR/alphafold_cache
            cd $TMPDIR
            echo Contents of $TMPDIR
            ls -l $TMPDIR
            singularity exec --nv --writable-tmpfs \
                {params.singularity_args} \
                {params.singularity_bind} \
                {params.container} \
                sh -c '/app/scripts/{params.run_alphafold_wrapper} {params.run_alphafold_args} {params.run_alphafold_dirs}'
            cd -

            cd $TMPDIR/alphafold3_predictions
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                OUT_DATA="$ALPHAFOLD3_ID"/"$ALPHAFOLD3_ID"_data.json
                echo Remove redundant data pipeline output "$OUT_DATA"
                rm $OUT_DATA
                echo Compressing predictions to $SMKDIR/alphafold3_predictions/$ALPHAFOLD3_ID.zip
                zip -r $SMKDIR/alphafold3_predictions/$ALPHAFOLD3_ID.zip $ALPHAFOLD3_ID
            done
        """

rule alphafold3_datafill_predictions:
    input:
        expand('alphafold3_predictions/{id}.zip', id=ids),
