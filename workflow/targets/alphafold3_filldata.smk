

include: '../rules/common.smk'

localrules: alphafold3_filldata

rule alphafold3_filldata:
    """
    https://github.com/google-deepmind/alphafold3/blob/main/docs/installation.md
    """
    output:
        json = os.path.join(config['alphafold3']['msas_cache'], '.alphafold3_filldata.json'),
    params:
        alphafold3_filldata = os.path.join(root_path("workflow/scripts"), 'alphafold3_filldata'),
        msas_cache = config['alphafold3']['msas_cache'],
    envmodules: *config['envmodules']
    shell: """
        {params.alphafold3_filldata} {params.msas_cache}
    """
