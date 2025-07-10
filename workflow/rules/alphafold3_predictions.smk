
rule alphafold3_predictions:
    # Run AF3 structure prediction on all .json-s
    input:
        json = expand('alphafold3_msas/{id}_data.json.gz', id=ids),
    output:
        cifs = expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
        # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
    params:
        # bind paths
        af_input = '--bind alphafold3_msas:/root/af_input',
        af_output = lambda wildcards: '--bind alphafold3_predictions:/root/af_output',
        models = f'--bind {config["alphafold3"]["model_dir"]}:/root/models',
        databases = f'--bind {config["alphafold3"]["db_dir"]}:/root/public_databases',
        scripts = f'--bind {root_path("workflow/scripts")}:/app/scripts',
        docker = root_path(config["alphafold3"]["container"]),
        # run_alphafold.py
        #json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}/{wc.id}_data.json',
        input_dir = '--input_dir=/root/af_input',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        # https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md
        xtra_args = '--norun_data_pipeline',# --flash_attention_implementation=xla',
        # Add --jax_compilation_cache_dir <YOUR_DIRECTORY>
    envmodules: *config['envmodules_offline']
    shell: """
        TODO_JSONS=$TMPDIR/alphafold_predictions_todo.txt
        echo "{input.json}" | tr ' ' '\\n' > $TODO_JSONS
        echo Contents of $TODO_JSONS
        cat $TODO_JSONS
        SMKDIR=`pwd`
        echo Running rsync from $SMKDIR to $TMPDIR
        rsync -av --files-from $TODO_JSONS ./ $TMPDIR
        #rsync -auv $SMKDIR/ $TMPDIR --include='alphafold3_msas' --include='alphafold3_msas/*_data.json.gz' --exclude='*'
        gunzip -r $TMPDIR/alphafold3_msas/
        mkdir -p $TMPDIR/{rule}
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
        gzip -r $TMPDIR/{rule}/
        echo Running rsync from $TMPDIR to $SMKDIR
        rsync -auv $TMPDIR/{rule} $SMKDIR/
    """
