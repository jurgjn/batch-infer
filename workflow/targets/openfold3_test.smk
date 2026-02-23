
include: '../rules/common.smk'

rule openfold3_inference_verification:
    output:
        done = touch('openfold3_inference_verification.done'),
    params:
        container = config['openfold3']['container'],
    resources:
        runtime = config['openfold3']['runtime'],
        mem_mb = config['openfold3']['mem_mb'],
        disk_mb = config['openfold3']['disk_mb'],
        slurm_extra = config['openfold3']['slurm_extra'],
    envmodules:
        'eth_proxy', # No other envmodules as singularity will propagate any software stack into the container and openfold 3 will then try & use it to build pytorch extensions..
    shell: """
        mkdir -p $TMPDIR/_overlay
        mkdir -p $TMPDIR/_triton_cache_dir
        mkdir -p $TMPDIR/_xdg_cache_home
        unset MPLBACKEND
        unset XDG_CACHE_HOME
        singularity exec --nv \
            --env OPENFOLD_CACHE=/root/.openfold3 \
            --env TRITON_CACHE_DIR=$TMPDIR/_triton_cache_dir \
            --bind $TMPDIR/_triton_cache_dir \
            --env XDG_CACHE_HOME=$TMPDIR/_xdg_cache_home \
            --bind $TMPDIR/_xdg_cache_home \
            --overlay $TMPDIR/_overlay \
            {params.container} \
                sh -c 'python3 -c "import deepspeed; deepspeed.ops.op_builder.EvoformerAttnBuilder().load()"; pytest /opt/openfold3/openfold3/tests/ -m "inference_verification"'
    """

rule openfold3_test:
    input:
        'openfold3_inference_verification.done',
