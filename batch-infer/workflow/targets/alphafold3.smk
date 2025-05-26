
ids_jsons_, = glob_wildcards('alphafold3_jsons/{id}.json')
ids_msas_, = glob_wildcards('alphafold3_msas/{id}_data.json.gz')
ids = set(ids_jsons_) | set(ids_msas_)

include: '../rules/common.smk'
include: '../rules/alphafold3_msas.smk'
include: '../rules/alphafold3_predictions.smk'

rule alphafold3:
    # AlphaFold3 run with MSAs as individual jobs, all predictions as a single GPU job
    input:
        #expand('alphafold3_msas/{id}_data.json.gz', id=ids),
        expand('alphafold3_predictions/{id}/{id}_model.cif.gz', id=ids),
