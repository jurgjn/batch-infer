
include: '../rules/common.smk'

rule alphafold3_pooledPPI_run:
    """
    Generate pools for an all-vs-all pooled PPI screen

    Enable diagnostics, see https://numba.readthedocs.io/en/stable/user/parallel.html#diagnostics
        export NUMBA_PARALLEL_DIAGNOSTICS=1
    
    Dependencies:
        pip install tqdm numba
    """
    input:
        tsv = 'alphafold3_jsons/.alphafold3_pooledPPI_proteins.tsv'
    output:
        tsv = 'alphafold3_jsons/.alphafold3_pooledPPI_pools.tsv'
    params:
        alphafold3_pooledPPI = root_path('workflow/scripts/alphafold3_pooled-PPI'),
    threads: 64
    resources:
        runtime = '1d',
        mem_mb = 98304,
        disk_mb = 98304,
        slurm_extra = "'--constraint=\"EPYC_9654\"'", #https://scicomp.ethz.ch/wiki/Euler#CPU_Nodes
    shell: """
        export NUMBA_NUM_THREADS={threads}
        cat {input.tsv} | {params.alphafold3_pooledPPI} > {output.tsv}
        myjobs -j $SLURM_JOB_ID
    """

rule alphafold3_pooledPPI:
    input:
        'alphafold3_jsons/.alphafold3_pooledPPI_pools.tsv'
