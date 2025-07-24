
include: '../rules/common.smk'

rule openfold_test:
    """
    Docker file does not seem to install third-party dependancies?? - 

    Docker image does not have unit tests:
        git clone https://github.com/aqlaboratory/openfold.git
        git checkout v2.0.0
    
    https://openfold.readthedocs.io/en/latest/original_readme.html#building-and-using-the-docker-container
    nvidia-smi
    python3 /opt/openfold/run_pretrained_openfold.py --help
    apt-get install -y libaio-dev

    df: /cluster/home/jjaenes/.triton/autotune: No such file or directory

    """
    params:
        bind_database = f'--bind {config["openfold"]["database"]}:/database',
        bind_params = f'--bind {config["openfold"]["params"]}:/opt/openfold/openfold/resources/params',
        #bind_tests = f'--bind openfold/tests:/opt/openfold/tests',
        container = root_path(config["openfold"]["container"]),
        #template_mmcif_dir = '/database/pdb_mmcif/mmcif_files/',
        #uniref90_database_path = '--uniref90_database_path /database/uniref90/uniref90.fasta',
        #mgnify_database_path = '--mgnify_database_path /database/mgnify/mgy_clusters_2018_12.fa',
        #pdb_seqres_database_path = '--pdb_seqres_database_path /database/pdb_seqres/pdb_seqres.txt',
        #uniref30_database_path = '--uniref30_database_path /database/uniref30/UniRef30_2021_03',
        #uniprot_database_path = '--uniprot_database_path /database/uniprot/uniprot.fasta',
        #bfd_database_path = '--bfd_database_path /database/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt',
        #binary_paths = '--jackhmmer_binary_path jackhmmer --hhblits_binary_path hhblits --hmmsearch_binary_path hmmsearch --hmmbuild_binary_path hmmbuild --kalign_binary_path kalign'
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
        singularity exec --nv --writable-tmpfs {params.bind_database} {params.bind_params} {params.container} sh -c '\
            cd /opt/openfold && \
            ./scripts/run_unit_tests.sh'
    """
