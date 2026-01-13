
include: '../rules/common.smk'

rule singularity_pull:
    params:
        container_dir = config["singularity"]["container_dir"],
        pull = config["singularity"]["pull"],
    resources:
        runtime = '1h',
        mem_mb = 24576,
        disk_mb = 24576,
    envmodules: *config['envmodules']
    shell: """
        export APPTAINER_CACHEDIR=$SCRATCH/.apptainer
        export APPTAINER_TMPDIR=$TMPDIR
        cd {params.container_dir}
        singularity pull {params.pull}
    """
