
ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/common.smk'
include: '../rules/rosettafold2PPI.smk'

rule rosettafold:
    input:
        log=expand('rosettafoldPPI_predicted_msas/{id}/{id}-{other}-res.tsv',id=ids,other=[x for x in ids if x != "{id}"]),
        completed_run = 'rosettafoldPPI_combined_mats/completed.txt'
