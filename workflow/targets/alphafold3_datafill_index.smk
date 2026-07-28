
include: '../rules/common.smk'

rule alphafold3_datafill_index:
    params:
        activate = get_activate(),
        data_sources = config['alphafold3']['data_sources'],
    resources:
        runtime = '1d',
        mem_mb = 16384,
        disk_mb = 16384,
        slurm_extra = '',
    envmodules: *config['envmodules']
    shell: """
        source {params.activate}
        af3io data-fill {params.data_sources} --write-index
    """
