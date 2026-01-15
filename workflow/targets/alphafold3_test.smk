
include: '../rules/common.smk'

rule alphafold3_run_data_test:
    output:
        done = touch('alphafold3_data_test.done'),
    params:
        models = f'--bind {config["alphafold3"]["model_dir"]}:/root/models',
        databases = f'--bind {config["alphafold3"]["db_dir"]}:/root/public_databases',
        docker = root_path(config["alphafold3"]["container"]),
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
    resources:
        runtime = '1h',
        mem_mb = 65536,
        disk_mb = 65536,
    envmodules: *config['envmodules_offline']
    shell: """
        cd $TMPDIR
        echo Contents of $TMPDIR
        ls -l $TMPDIR
        singularity exec --writable-tmpfs {params.models} {params.databases} {params.docker} \
            sh -c 'cd /app/alphafold && python run_alphafold_data_test.py \
                {params.model_dir} \
                {params.db_dir}'
        cd -
        echo Contents of $TMPDIR
        ls -l $TMPDIR
    """

rule alphafold3_run_test:
    output:
        done = touch('alphafold3_test.done'),
    params:
        models = f'--bind {config["alphafold3"]["model_dir"]}:/root/models',
        databases = f'--bind {config["alphafold3"]["db_dir"]}:/root/public_databases',
        docker = root_path(config["alphafold3"]["container"]),
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
    resources:
        runtime = config['alphafold3']['test']['runtime'],
        mem_mb = config['alphafold3']['test']['mem_mb'],
        disk_mb = config['alphafold3']['test']['disk_mb'],
        slurm_extra = config['alphafold3']['test']['slurm_extra'],
    envmodules: *config['envmodules_offline']
    shell: """
        cd $TMPDIR
        echo Contents of $TMPDIR
        ls -l $TMPDIR
        singularity exec --nv {params.docker} sh -c 'nvidia-smi'
        singularity exec --nv --writable-tmpfs {params.models} {params.databases} {params.docker} \
            sh -c 'cd /app/alphafold && python run_alphafold_test.py \
                {params.model_dir} \
                {params.db_dir}'
        cd -
        echo Contents of $TMPDIR
        ls -l $TMPDIR
    """

rule alphafold3_test:
    input:
        'alphafold3_data_test.done',
        'alphafold3_test.done',
