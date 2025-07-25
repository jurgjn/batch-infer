
include: '../rules/common.smk'

rule openfold_test:
    """
        Ran 117 tests in 377.980s
        OK (skipped=41)
    """
    params:
        #bind_database = f'--bind {config["openfold"]["database"]}:/database',
        bind_local_scratch = '--bind $TMPDIR',
        bind_params = f'--bind {config["openfold"]["params"]}:/opt/openfold/openfold/resources/params',
        bind_triton_autotune = '--bind $TMPDIR/_triton_autotune:/cluster/home/jjaenes/.triton/autotune',
        container = root_path(config["openfold"]["container"]),
        #template_mmcif_dir = '/database/pdb_mmcif/mmcif_files/',
        #uniref90_database_path = '--uniref90_database_path /database/uniref90/uniref90.fasta',
        #mgnify_database_path = '--mgnify_database_path /database/mgnify/mgy_clusters_2018_12.fa',
        #pdb_seqres_database_path = '--pdb_seqres_database_path /database/pdb_seqres/pdb_seqres.txt',
        #uniref30_database_path = '--uniref30_database_path /database/uniref30/UniRef30_2021_03',
        #uniprot_database_path = '--uniprot_database_path /database/uniprot/uniprot.fasta',
        #bfd_database_path = '--bfd_database_path /database/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt',
        #binary_paths = '--jackhmmer_binary_path jackhmmer --hhblits_binary_path hhblits --hmmsearch_binary_path hmmsearch --hmmbuild_binary_path hmmbuild --kalign_binary_path kalign'
    threads: 4
    resources:
        runtime = '4h',
        mem_mb = 65536,
        disk_mb = 65536,
        slurm_extra = "'--gpus=rtx_4090%1 --gres=gpumem%24g'",
        #mem_mb = 98304,
        #disk_mb = 98304,
        #slurm_extra = "'--gpus=1 --gres=gpumem%80g'",
    envmodules: *config['envmodules_offline']
    shell: """
        unset XDG_CACHE_HOME
        mkdir -p $TMPDIR/_triton_autotune
        singularity exec --nv --pwd /opt/openfold/ --env MAX_JOBS={threads} --env XDG_CACHE_HOME=$TMPDIR/_xdg_cache_home \
            {params.bind_local_scratch} {params.bind_params} {params.bind_triton_autotune} {params.container} \
            /usr/local/bin/_entrypoint.sh /opt/openfold/scripts/run_unit_tests.sh
    """
