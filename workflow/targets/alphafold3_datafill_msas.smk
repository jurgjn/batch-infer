

include: '../rules/common.smk'

ids, = glob_wildcards('alphafold3_missing/{id}.json')

rule alphafold3_msas:
    """
    Run AF3 data pipeline for one input .json
    """
    input:
        json = 'alphafold3_missing/{id}.json',
    output:
        json = 'alphafold3_msas/{id}_data.json.gz',
    params:
        activate = root_path('.venv/bin/activate'),
        # bind paths
        af_input = '--bind alphafold3_missing:/root/af_input',
        af_output = '--bind alphafold3_msas:/root/af_output',
        models = f'--bind {config["alphafold3"]["model_dir"]}:/root/models',
        databases = f'--bind {config["alphafold3"]["db_dir"]}:/root/public_databases',
        #databases_fallback = f'--bind {config["alphafold3_databases_fallback"]}:/root/public_databases_fallback',
        docker = root_path(config["alphafold3"]["container"]),
        # run_alphafold.py
        json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}.json',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        #db_dir_fallback = '--db_dir=/root/public_databases_fallback',
        max_template_date = f'--max_template_date="{config["alphafold3"]["max_template_date"]}"',
        xtra_args = '--norun_inference',
    retries: config['alphafold3']['msas']['retries']
    envmodules: *config['envmodules_offline']
    shell: """
        source {params.activate}
        SMKDIR=`pwd`
        rsync -auq $SMKDIR/ $TMPDIR --include='alphafold3_missing' --include='{input.json}' --exclude='*'
        mkdir -p $TMPDIR/alphafold3_msas
        cd $TMPDIR
        singularity exec {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} \
            sh -c 'python3 /app/alphafold/run_alphafold.py \
                {params.json_path} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.max_template_date} \
                {params.xtra_args}'
        cd -
        gzip $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json
        cp $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json.gz $SMKDIR/alphafold3_msas/{wildcards.id}_data.json.gz
    """

localrules: alphafold3_datafill_msas

rule alphafold3_datafill_msas:
    input:
        expand('alphafold3_msas/{id}_data.json.gz', id=ids),
    output:
        'alphafold3_msas/.af3io_data_index.json',
    params:
        activate = root_path('.venv/bin/activate'),
    shell: """
        source {params.activate}
        mkdir -p alphafold3_msas/
        af3io data-fill --data_dir alphafold3_msas --write-index
    """
