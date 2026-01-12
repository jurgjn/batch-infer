
include: '../rules/common.smk'

rule alphafold3_datafill_index:
    output:
        index = os.path.join(config['alphafold3_datafill_index']['data_dir'], '.af3io_data_index.json'),
    params:
        activate = root_path('.venv/bin/activate'),
        data_sources = config['alphafold3']['data_sources'],
    resources:
        runtime = '4h',
    envmodules: *config['envmodules']
    shell: """
        source {params.activate}
        af3io data-fill {params.data_sources} --write-index
    """
