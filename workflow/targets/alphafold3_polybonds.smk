
if 'ids' in config['alphafold3'].keys():
    ids = config['alphafold3']['ids']
else:
    ids, = glob_wildcards('alphafold3_bonds/{id}.json')

include: '../rules/common.smk'

localrules: alphafold3_polymer_bonds

rule alphafold3_polymer_bonds:
    input:
        json = 'alphafold3_bonds/{id}.json',
    output:
        json = 'alphafold3_jsons/{id}.json',
    envmodules: *config['envmodules_offline']
    shell: """
        alphafold3_polymer_bonds --source_path={input.json} --output_path={output.json}
    """

rule alphafold3_polybonds:
    # AlphaFold3 run with MSAs as individual jobs, all predictions as a single GPU job
    input:
        expand('alphafold3_jsons/{id}.json', id=ids),
        #expand('alphafold3_msas/{id}_data.json.gz', id=ids),
        #expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
