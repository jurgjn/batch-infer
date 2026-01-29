
include: '../rules/common.smk'

ids, = glob_wildcards('input-fasta/{id}.fasta')

rule run_esm_score_missense_mutations:
    input:
        fasta = 'input-fasta/{id}.fasta',
    output:
        csv = 'output-csv/{id}.csv',
    params:
        bind_input = '--bind input-fasta:/root/input-fasta',
        bind_output = '--bind output-csv:/root/output-csv',
        container = '/cluster/project/beltrao/shared/alphafold3/images/esm-variants_latest.sif',
    resources:
        runtime = '1d',
        mem_mb = 65536,
        disk_mb = 65536,
        slurm_extra = '--gpus=rtx_2080_ti:1',
    #envmodules: *config['envmodules'] # Model weights should be in the container but running without eth_proxy still fails with `ConnectionRefusedError: [Errno 111] Connection refused`
    envmodules: *config['envmodules_offline']
    shell: """
        # Set APPTAINER_BINDPATH to re-download/use model weights from scratch
        #export APPTAINER_BINDPATH="/cluster/scratch/$USER"
        #echo APPTAINER_BINDPATH set to $APPTAINER_BINDPATH
        # Set XDG_CACHE_HOME=/root/.cache to use model weights from the container
        singularity exec --nv --writable-tmpfs \
            --env XDG_CACHE_HOME=/root/.cache \
            {params.bind_input} \
            {params.bind_output} \
            {params.container} \
            sh -c 'cd /app/esm-variants && python3 esm_score_missense_mutations.py \
                --input-fasta-file /root/input-fasta/{wildcards.id}.fasta \
                --output-csv-file /root/output-csv/{wildcards.id}.csv'
    """

rule esm_score_missense_mutations:
    input:
        expand('output-csv/{id}.csv', id=ids),
