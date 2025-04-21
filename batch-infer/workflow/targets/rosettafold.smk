
ids, = glob_wildcards('alphafold3_jsons/{id}.json')

include: '../rules/common.smk'
include: '../rules/rosettafold2PPI.smk'

rule rosettafold:
    input:
        completed_run = 'rosettafoldPPI_combined_mats/completed.txt'
