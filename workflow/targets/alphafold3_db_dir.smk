
include: '../rules/common.smk'

rule alphafold3_db_dir:
    """
    https://github.com/google-deepmind/alphafold3/blob/main/docs/installation.md
    """
    output:
        os.path.join(config['alphafold3']['db_dir'], 'bfd-first_non_consensus_sequences.fasta'),
        os.path.join(config['alphafold3']['db_dir'], 'mgy_clusters_2022_05.fa'),
        os.path.join(config['alphafold3']['db_dir'], 'nt_rna_2023_02_23_clust_seq_id_90_cov_80_rep_seq.fasta'),
        os.path.join(config['alphafold3']['db_dir'], 'pdb_seqres_2022_09_28.fasta'),
        os.path.join(config['alphafold3']['db_dir'], 'rfam_14_9_clust_seq_id_90_cov_80_rep_seq.fasta'),
        os.path.join(config['alphafold3']['db_dir'], 'rnacentral_active_seq_id_90_cov_80_linclust.fasta'),
        os.path.join(config['alphafold3']['db_dir'], 'uniprot_all_2021_04.fa'),
        os.path.join(config['alphafold3']['db_dir'], 'uniref90_2022_05.fa'),
    params:
        db_dir = config['alphafold3']['db_dir'],
        fetch_databases_url = config['alphafold3']['fetch_databases_url'],
    threads: 8
    resources:
        runtime = '4h',
    envmodules: *config['envmodules']
    shell: """
        cd {params.db_dir}
        wget {params.fetch_databases_url}
        chmod u+x fetch_databases.sh
        ./fetch_databases.sh {params.db_dir}
        cd -
        du -s --inodes {params.db_dir}
        du -sh {params.db_dir}
    """
