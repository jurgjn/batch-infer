
include: '../rules/common.smk'

rule alphafold3_datafill_missing:
    input:
        input_dir = 'alphafold3_jsons',
    output:
        missing_dir = directory('alphafold3_missing'),
    params:
        activate = root_path('.venv/bin/activate'),
        data_sources = config['alphafold3']['data_sources'],
    resources:
        runtime = '2h',
    envmodules: *config['envmodules']
    shell: """
        source {params.activate}
        mkdir -p {output.missing_dir}
        af3io data-fill {params.data_sources} --input_dir {input.input_dir} --missing_dir {output.missing_dir}
    """
