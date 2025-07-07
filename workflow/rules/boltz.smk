
rule boltz_predict:
    """
    - Unsetting SLURM_* turns off auto-requeue in PyTorch Lightning - https://github.com/Lightning-AI/pytorch-lightning/issues/6389
    """
    input:
        yaml = 'boltz_input/{id}.yaml',
    output:
        cif0 = 'boltz_predict/boltz_results_{id}/predictions/{id}/{id}_model_0.cif.gz',
    params:
        bind_input = '--bind boltz_input:/root/boltz_input',
        bind_output = '--bind $TMPDIR/boltz_predict:/root/boltz_output',
        bind_cache = f'--bind {config["boltz"]["cache"]}:/root/cache',
        boltz_cache = f'{config["boltz"]["cache"]}',
        container = config['boltz']['container'],
        xtra_args = '--use_msa_server --cache /root/cache',
    envmodules: *config['envmodules_offline']
    shell: """
        mkdir -p {params.boltz_cache}
        SMKDIR=`pwd`
        mkdir -p $TMPDIR/boltz_predict
        singularity exec --nv {params.bind_input} {params.bind_output} {params.bind_cache} {params.container} \
            sh -c 'unset SLURM_JOB_NAME &&\
                unset SLURM_NTASKS &&\
                unset SLURM_NTASKS_PER_NODE &&\
                boltz predict /root/boltz_input/{wildcards.id}.yaml --out_dir /root/boltz_output {params.xtra_args} --num_workers {threads}'
        gzip -r $TMPDIR/boltz_predict/
        rsync -auv $TMPDIR/boltz_predict $SMKDIR/
    """
