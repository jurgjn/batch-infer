
include: '../rules/common.smk'

tsv_ = f'alphafold3_predictions/.alphafold3_predictions_filldata.tsv'
if not os.path.isfile(tsv_):
    os.makedirs(os.path.dirname(tsv_), exist_ok=True)
    runtime_sec_ = humanfriendly.parse_timespan(config['alphafold3']['predictions_multigpu_runtime'])
    runtime_buf_ = runtime_sec_ * config['alphafold3']['predictions_multigpu_buffer_time']
    runtime_hrs_ = int(runtime_buf_ / (60*60))

    alphafold3_read_predictions_multigpu(
        batch_runtime_hrs=runtime_hrs_,
        tokens_min = config['alphafold3']['predictions_multigpu_tokens_min'],
        tokens_max = config['alphafold3']['predictions_multigpu_tokens_max'],
    ).to_csv(tsv_, sep='\t', index=False, header=True)

ids = pd.read_csv(tsv_, sep='\t').id.tolist()

for batch_id, df_batch in pd.read_csv(tsv_, sep='\t').groupby('batch_id'):
    #print(batch_id)
    #print(df_batch)

    rule: # Run AF3 structure prediction on a subset of .json-s (as implied by id-s)
        name:
            f'alphafold3_predictions_batch{batch_id}_{len(df_batch)}'
        input:
            json = expand('alphafold3_jsons/{id}.json', id=df_batch.id.tolist()),
        output:
            cifs = expand('alphafold3_predictions/{id}.zip', id=df_batch.id.tolist()),
        params:
            # bind paths
            af_input = '--bind alphafold3_msas:/root/af_input',
            af_output = lambda wildcards: '--bind alphafold3_predictions:/root/af_output',
            models = f'--bind {config["alphafold3"]["model_dir"]}:/root/models',
            databases = f'--bind {config["alphafold3"]["db_dir"]}:/root/public_databases',
            scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
            docker = root_path(config["alphafold3"]["container"]),
            alphafold3_filldata = os.path.join(root_path("workflow/scripts"), 'alphafold3_filldata'),
            alphafold3_msas_cache = config['alphafold3']['msas_cache'],
            alphafold3_ids = ' '.join(df_batch.id.tolist()),
            # run_alphafold.py
            #json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}/{wc.id}_data.json',
            input_dir = '--input_dir=/root/af_input',
            output_dir = '--output_dir=/root/af_output',
            model_dir ='--model_dir=/root/models',
            db_dir = '--db_dir=/root/public_databases',
            # https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md
            xtra_args = '--norun_data_pipeline',
        resources:
            runtime = config['alphafold3']['predictions_multigpu_runtime'],
            mem_mb = 98304,
            disk_mb = 98304,
            slurm_extra = "'--gpus=1 --gres=gpumem%80g'",
            #mem_mb = 65536,
            #disk_mb = 65536,
            #slurm_extra = "'--gpus=rtx_4090%1 --gres=gpumem%24g'",
        envmodules: *config['envmodules_offline']
        shell: """
            SMKDIR=`pwd`
            mkdir -p $TMPDIR/alphafold3_msas
            ALPHAFOLD3_IDS="{params.alphafold3_ids}"
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                echo ALPHAFOLD3_ID: "$ALPHAFOLD3_ID"
                JSON=alphafold3_jsons/"$ALPHAFOLD3_ID".json
                echo JSON: "$JSON"
                DATA="$TMPDIR"/alphafold3_msas/"$ALPHAFOLD3_ID"_data.json
                echo DATA: "$DATA"
                cat "$JSON" | {params.alphafold3_filldata} {params.alphafold3_msas_cache} > "$DATA"
            done
            ls -l $TMPDIR/alphafold3_msas
            
            mkdir -p $TMPDIR/alphafold3_predictions
            cd $TMPDIR
            echo Contents of $TMPDIR
            ls -l $TMPDIR
            singularity exec --nv {params.docker} sh -c 'nvidia-smi'
            singularity exec --nv --writable-tmpfs {params.af_input} {params.af_output} {params.models} {params.databases} {params.scripts} {params.docker} \
                sh -c '/app/scripts/run_alphafold.sh \
                    {params.input_dir} \
                    {params.output_dir} \
                    {params.model_dir} \
                    {params.db_dir} \
                    {params.xtra_args}'
            cd -

            cd $TMPDIR/alphafold3_predictions
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                echo Compressing predictions to $SMKDIR/alphafold3_predictions/$ALPHAFOLD3_ID.zip
                zip -r $SMKDIR/alphafold3_predictions/$ALPHAFOLD3_ID.zip $ALPHAFOLD3_ID
            done
        """

rule alphafold3_predictions_filldata:
    input:
        expand('alphafold3_predictions/{id}.zip', id=ids),
