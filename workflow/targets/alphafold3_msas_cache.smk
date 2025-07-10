
include: '../rules/common.smk'
include: '../rules/alphafold3_msas_cache.smk'

ids = pd.read_csv('alphafold3_msas_cache.txt', comment='#', names=['id'])['id'].tolist()

rule alphafold3_msas_cache:
    input:
        expand('alphafold3_msas/{id}_data.json.gz', id=ids),
