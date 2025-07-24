
include: '../rules/common.smk'

localrules: singularity_pull

rule singularity_pull:
    params:
        container_dir = config["singularity"]["container_dir"],
        pull = config["singularity"]["pull"],
    envmodules: *config['envmodules']
    shell: """
        export APPTAINER_CACHEDIR=$SCRATCH/.apptainer
        export APPTAINER_TMPDIR=$TMPDIR
        cd {params.container_dir}
        singularity pull {params.pull}
    """
