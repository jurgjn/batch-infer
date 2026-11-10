
include: '../rules/common.smk'

include: 'alphafold3_datafill_msas.smk'

# alphafold3_datafill_predictions with several pools per GPU job: each batch is one job that fills all its pools with one
# af3io call and predicts them with one container call over --input_dir, so model start-up and compilation are paid once
# per job. Written for Anthropic's af3_torch kit (README), works with any run_alphafold_wrapper.
# config alphafold3.predictions_batched sets the grouping (defaults.yaml); everything else (container, wrapper, args,
# mem_mb, slurm_extra) comes from alphafold3.predictions. The batch list is cached in BATCHES_TSV_ so that job-side parses
# see the same rules; delete it after adding or removing input JSONs.
#
# The declared output of a batch is a marker file (alphafold3_predictions/.batches/batch<N>_<digest>.done), not the
# zips: snakemake deletes the outputs of a failed job, which would remove the zips of the pools that did finish.
# Zips are written atomically, pools that already have a zip are skipped, and a job with any pool lacking output
# exits non-zero (no marker), so re-running the target runs only what is missing.
BATCHES_TSV_ = 'alphafold3_predictions/.alphafold3_datafill_predictions_batched.tsv'
MARKER_DIR_ = 'alphafold3_predictions/.batches'
BATCHING_ = config['alphafold3'].get('predictions_batched') or {}
# keys of an earlier version of this target; only the behaviour of their values below is implemented
if int(BATCHING_.get('threads', 1)) != 1 or BATCHING_.get('early_zip', False):
    raise ValueError('alphafold3.predictions_batched: threads != 1 / early_zip true are not supported (one container call per batch, zips after it)')

def batch_marker_(batch_id, ids_):
    # the digest ties a marker to its pool ids, so a regenerated batch list never matches an old marker
    import hashlib
    digest_ = hashlib.sha1(' '.join(ids_).encode()).hexdigest()[:8]
    return f'{MARKER_DIR_}/batch{batch_id}_{digest_}.done'

def make_batches_():
    os.makedirs(MARKER_DIR_, exist_ok=True)
    if not os.path.isfile(BATCHES_TSV_):
        ids_jsons_, = snakemake.io.glob_wildcards('alphafold3_jsons/{id}.json')
        ids_infer_, = snakemake.io.glob_wildcards('alphafold3_predictions/{id}.zip')
        frame_ = pd.DataFrame({'id': sorted(set(ids_jsons_) - set(ids_infer_))})
        frame_['tokens'] = frame_['id'].map(lambda id: alphafold3_json_tokens(f'alphafold3_jsons/{id}.json'))
        ok_ = pd.Series(True, index=frame_.index)
        if BATCHING_.get('tokens_min') is not None:
            ok_ &= frame_['tokens'] >= BATCHING_['tokens_min']
        if BATCHING_.get('tokens_max') is not None:
            ok_ &= frame_['tokens'] <= BATCHING_['tokens_max']
        if (~ok_).any():
            frame_[~ok_].to_csv(BATCHES_TSV_ + '.refused', sep='\t', index=False)
            eprint(f'{(~ok_).sum()} pool(s) outside tokens_min/tokens_max not batched, listed in {BATCHES_TSV_}.refused')
        budget_hrs_ = BATCHING_.get('budget_hrs')
        frame_ = pack_batches(
            frame_[ok_],
            max_per_batch=int(BATCHING_.get('max_pools_per_job', 1)),
            budget_s=None if budget_hrs_ is None else float(budget_hrs_) * 3600 - float(BATCHING_.get('job_overhead_s', 0)),
            runtime_table_s=BATCHING_.get('runtime_table_s'),
            order=BATCHING_.get('order', 'none'),
        )
        frame_[['id', 'batch_id', 'tokens', 'runtime_s']].to_csv(BATCHES_TSV_, sep='\t', header=True, index=False)
        if frame_['batch_id'].nunique() < len(frame_):
            eprint(frame_.groupby('batch_id').agg(pools=('id', 'size'), tokens_max=('tokens', 'max'), est_min=('runtime_s', lambda s: round(s.sum() / 60, 1))).to_string())
    return pd.read_csv(BATCHES_TSV_, sep='\t', dtype={'id': str})

batches_ = make_batches_()
ids = batches_.id.tolist()
markers_ = []

for batch_id, df_batch in batches_.groupby('batch_id'):
    marker_ = batch_marker_(batch_id, df_batch.id.tolist())
    markers_.append(marker_)

    rule: # Run AF3 structure prediction on a subset of .json-s (as implied by id-s)
        name:
            f'alphafold3_datafill_predictions_batched{batch_id}_{len(df_batch)}'
        input:
            json = expand('alphafold3_jsons/{id}.json', id=df_batch.id.tolist()),
            msas = 'alphafold3_msas/.af3io_data_index.json', # trigger missing MSAs
        output:
            done = marker_,
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
            # remove redundant <id>_data.json from predictions before zipping (default: True, i.e. current behaviour)
            drop_data = 'true' if config['alphafold3']['predictions'].get('drop_data', True) else 'false',
            # predicted runtime of the batch in minutes (nan without a runtime table), compare with CONTAINER_START/END
            est_min = round(df_batch.runtime_s.sum() / 60, 1),
        retries: config['alphafold3']['predictions']['retries']
        resources:
            runtime = BATCHING_.get('runtime') or config['alphafold3']['predictions']['runtime'],
            mem_mb = config['alphafold3']['predictions']['mem_mb'],
            # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#dynamic-resources
            #mem_mb = lambda attempt: alphafold3_predictions_mem_mb if isinstance(alphafold3_predictions_mem_mb, int) else alphafold3_predictions_mem_mb[attempt - 1],
            disk_mb = max(int(BATCHING_.get('disk_mb_min') or config['alphafold3']['predictions']['disk_mb']), int(BATCHING_.get('disk_mb_per_pool', 0)) * len(df_batch)),
            slurm_extra = config['alphafold3']['predictions']['slurm_extra'],
        envmodules: *config['envmodules_offline']
        shell: """
            source {params.activate}
            SMKDIR=`pwd`
            echo BATCH: {params.alphafold3_ids}
            echo BATCH_EST_MIN: {params.est_min}

            # pools that already have a zip are not run again
            ALPHAFOLD3_IDS=""
            for ALPHAFOLD3_ID in {params.alphafold3_ids}; do
                if [ -f $SMKDIR/alphafold3_predictions/"$ALPHAFOLD3_ID".zip ]; then
                    echo POOL_STATUS "$ALPHAFOLD3_ID" already_zipped
                else
                    ALPHAFOLD3_IDS="$ALPHAFOLD3_IDS $ALPHAFOLD3_ID"
                fi
            done
            if [ -z "$ALPHAFOLD3_IDS" ]; then
                echo BATCH_DONE: every pool already zipped
                touch $SMKDIR/{output.done}
                exit 0
            fi

            # one af3io call for the whole batch: the data index of each --data_dir is loaded (or, without
            # .af3io_data_index.json, rebuilt by reading every file) once per job instead of once per pool
            mkdir -p $TMPDIR/alphafold3_jsons $TMPDIR/alphafold3_msas
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                ln -sfn $SMKDIR/alphafold3_jsons/"$ALPHAFOLD3_ID".json $TMPDIR/alphafold3_jsons/"$ALPHAFOLD3_ID".json
            done
            echo FILL_START: `date -Is`
            af3io data-fill {params.data_sources} --data_dir=alphafold3_msas --input_dir=$TMPDIR/alphafold3_jsons --output_dir=$TMPDIR/alphafold3_msas/
            echo FILL_END: `date -Is`
            ls -l $TMPDIR/alphafold3_msas

            mkdir -p $TMPDIR/alphafold3_predictions $TMPDIR/alphafold_cache
            cd $TMPDIR
            echo Contents of $TMPDIR
            ls -l $TMPDIR
            echo CONTAINER_START: `date -Is`
            CONTAINER_RC=0
            singularity exec --nv --writable-tmpfs \
                {params.singularity_args} \
                {params.singularity_bind} \
                {params.container} \
                sh -c '/app/scripts/{params.run_alphafold_wrapper} {params.run_alphafold_args} {params.run_alphafold_dirs}' || CONTAINER_RC=$?
            echo CONTAINER_END: `date -Is` rc=$CONTAINER_RC
            cd -

            # one zip per pool with a summary; .zip.tmp + mv so an interrupted job never leaves a partial zip
            cd $TMPDIR/alphafold3_predictions
            N_FAILED=0
            for ALPHAFOLD3_ID in $ALPHAFOLD3_IDS; do
                if [ ! -f "$ALPHAFOLD3_ID"/"$ALPHAFOLD3_ID"_summary_confidences.json ]; then
                    echo POOL_STATUS "$ALPHAFOLD3_ID" missing_output
                    N_FAILED=$((N_FAILED + 1))
                    continue
                fi
                if [ "{params.drop_data}" = "true" ]; then
                    OUT_DATA="$ALPHAFOLD3_ID"/"$ALPHAFOLD3_ID"_data.json
                    echo Remove redundant data pipeline output "$OUT_DATA"
                    rm -f $OUT_DATA
                fi
                echo Compressing predictions to $SMKDIR/alphafold3_predictions/$ALPHAFOLD3_ID.zip
                if zip -q -r $SMKDIR/alphafold3_predictions/"$ALPHAFOLD3_ID".zip.tmp "$ALPHAFOLD3_ID" \
                    && mv $SMKDIR/alphafold3_predictions/"$ALPHAFOLD3_ID".zip.tmp $SMKDIR/alphafold3_predictions/"$ALPHAFOLD3_ID".zip; then
                    echo POOL_STATUS "$ALPHAFOLD3_ID" ok
                else
                    echo POOL_STATUS "$ALPHAFOLD3_ID" zip_failed
                    N_FAILED=$((N_FAILED + 1))
                fi
            done
            cd -
            echo BATCH_DONE: failed=$N_FAILED of `echo $ALPHAFOLD3_IDS | wc -w` container_rc=$CONTAINER_RC
            if [ "$N_FAILED" -gt 0 ]; then
                echo "ERROR: $N_FAILED pool(s) without a zip; re-run the target to retry them" >&2
                exit 1
            fi
            touch $SMKDIR/{output.done}
        """

rule alphafold3_datafill_predictions_batched:
    input:
        markers_,
