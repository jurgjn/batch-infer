
ids_, = glob_wildcards('boltz_input/{id}.yaml')

include: '../rules/common.smk'
include: '../rules/boltz.smk'

rule boltz:
    input:
        expand('boltz_predict/boltz_results_{id}/predictions/{id}/{id}_model_0.cif.gz', id=ids_)
