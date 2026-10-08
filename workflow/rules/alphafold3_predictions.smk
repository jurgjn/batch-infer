
rule alphafold3_predictions:
    # Run AF3 structure prediction on all .json-s
    input:
        json = expand('alphafold3_msas/{id}_data.json.gz', id=ids),
    output:
        cifs = expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
        # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
    params:
        activate = get_activate(),
        # alphafold3 id-s in the batch; datafill
        #alphafold3_ids = ' '.join(df_batch.id.tolist()),
        #data_sources = config['alphafold3']['data_sources'],
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
    resources:
        runtime = config['alphafold3']['predictions']['runtime'],
        mem_mb = config['alphafold3']['predictions']['mem_mb'],
        disk_mb = config['alphafold3']['predictions']['disk_mb'],
        slurm_extra = config['alphafold3']['predictions']['slurm_extra'],
    envmodules: *config['envmodules_offline']
    shell: """
        source {params.activate}
        TODO_JSONS=$TMPDIR/alphafold_predictions_todo.txt
        echo "{input.json}" | tr ' ' '\\n' > $TODO_JSONS
        echo Contents of $TODO_JSONS
        cat $TODO_JSONS
        SMKDIR=`pwd`
        echo Running rsync from $SMKDIR to $TMPDIR
        rsync -av --files-from $TODO_JSONS ./ $TMPDIR
        #rsync -auv $SMKDIR/ $TMPDIR --include='alphafold3_msas' --include='alphafold3_msas/*_data.json.gz' --exclude='*'
        gunzip -r $TMPDIR/alphafold3_msas/
        mkdir -p $TMPDIR/alphafold3_predictions
        cd $TMPDIR
        echo Contents of $TMPDIR
        ls -l $TMPDIR
        singularity exec --nv --writable-tmpfs \
            {params.singularity_args} \
            {params.singularity_bind} \
            {params.container} \
            sh -c '/app/scripts/{params.run_alphafold_wrapper} {params.run_alphafold_args} {params.run_alphafold_dirs}'
        cd -
        gzip -r $TMPDIR/{rule}/
        echo Running rsync from $TMPDIR to $SMKDIR
        rsync -auv $TMPDIR/{rule} $SMKDIR/
    """
