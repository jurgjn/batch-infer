
ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/common.smk'
include: '../rules/rosettafold2PPI.smk'

rule rosettafold:
    input:
        comb_log = expand('rosettafoldPPI_combined_logs/{id}-combined-res.tsv',id=ids),
        completed_run = 'rosettafoldPPI_combined_mats/completed.txt'
