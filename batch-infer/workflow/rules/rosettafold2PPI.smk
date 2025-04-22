import sys
import numpy as np
from datetime import datetime

p2src = '/cluster/project/beltrao/spasca/eukaryoma/PPI_stuff/Eukaryoma_PPI_analysis/src'
sys.path.append(p2src)
import utils

rosetta_github_p = '/cluster/project/beltrao/spasca/rosettafold-ppi/downloads/RoseTTAFold2-PPI/'
rosetta_fold_p = '/cluster/project/beltrao/spasca/rosettafold-ppi/downloads/SE3nv.sif'

wildcard_constraints:
    rule = r'[^\W0-9](\w|_)*', # https://stackoverflow.com/questions/49100678/regex-matching-unicode-variable-names
    id=r'[^\W0-9][\.\w]*', # https://github.com/google-deepmind/alphafold3/blob/d7758637f3a682c99ddb325869eab9f19361ebcd/src/alphafold3/common/folding_input.py#L1001-L1005

include: 'common.smk'

rule rosettafold_msas:
    """
    Run AF3 data pipeline for one input .json
    """
    input:
        json = 'alphafold3_jsons/{id}.json',
    output:
        json = 'alphafold3_msas/{id}_data.json.gz',
    params:
        # bind paths
        af_input = '--bind alphafold3_jsons:/root/af_input',
        af_output = '--bind alphafold3_msas:/root/af_output',
        models = f'--bind {config["alphafold3_models"]}:/root/models',
        databases = f'--bind {config["alphafold3_databases"]}:/root/public_databases',
        #databases_fallback = f'--bind {config["alphafold3_databases_fallback"]}:/root/public_databases_fallback',
        docker = root_path(config['alphafold3_docker']),
        # run_alphafold.py
        json_path = lambda wc: f'--json_path=/root/af_input/{wc.id}.json',
        output_dir = '--output_dir=/root/af_output',
        model_dir ='--model_dir=/root/models',
        db_dir = '--db_dir=/root/public_databases',
        #db_dir_fallback = '--db_dir=/root/public_databases_fallback',
        xtra_args = '--norun_inference',
    envmodules:
        'stack/2024-05', 'gcc/13.2.0',
    # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#defining-retries-for-fallible-rules
    # Re-attempt (failed) MSAs with increasing runtimes (4h, 1d, 3d)
    retries: 3
    shell: """
        SMKDIR=`pwd`
        rsync -auq $SMKDIR/ $TMPDIR --include='alphafold3_jsons' --include='{input.json}' --exclude='*'
        mkdir -p $TMPDIR/alphafold3_msas
        cd $TMPDIR
        singularity exec {params.af_input} {params.af_output} {params.models} {params.databases} {params.docker} \
            sh -c 'python3 /app/alphafold/run_alphafold.py \
                {params.json_path} \
                {params.output_dir} \
                {params.model_dir} \
                {params.db_dir} \
                {params.xtra_args}'
        cd -
        gzip $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json
        cp $TMPDIR/alphafold3_msas/{wildcards.id}/{wildcards.id}_data.json.gz $SMKDIR/alphafold3_msas/{wildcards.id}_data.json.gz
    """

rule rosettafoldPPI_combined_msas:
    # combine the MSAs together
    input:
        json = 'alphafold3_msas/{id}_data.json.gz',
        other_json= 'alphafold3_msas/{other}_data.json.gz',
    output:
        # For each file, create a folder with comparison results
        fasta='rosettafoldPPI_combined_msas/{id}/{id}-{other}-joined.fa',
        a3m='rosettafoldPPI_combined_msas/{id}/{id}-{other}-joined.a3m'
    params:
        path_to_reform = '{p2src}/src/reformat.pl'.format(p2src=p2src)
    run:
        """
         if not os.path.exists('rosettafoldPPI_combined_msas/{id}/'):
            os.mkdir('rosettafoldPPI_combined_msas/{id}/')
         joined_fasta = utils.join_alg_a3m({json}, {other_json})
         SeqIO.write(joined_fasta, fs_out+'.fa','fasta')
         os.system('{path_to_reform} fas a3m {fasta} {a3m}')
         """

rule rosettafoldPPI_predictions:
    # combine the MSAs together
    input:
        fasta='rosettafoldPPI_combined_msas/{id}/{id}-{other}-joined.fa',
        a3m='rosettafoldPPI_combined_msas/{id}/{id}-{other}-joined.a3m'
    output:
        # For each file, create a folder with comparison results
        log='rosettafoldPPI_predicted_msas/{id}/{id}-{other}-res.tsv'
    shell:
       """
       # make input file
       CURDIR=`pwd`
       THISTMP=$TMPDIR/{id}_{other}
       mkdir $THISTMP
       cd $THISTMP
       echo $CURDIR/{a3m} $(head -1 $CURDIR/{a3m}|cut -d_ -f2)>input_file
       # run prediction
        singularity exec --bind ./:/work/users --bind {rosetta_github_p}:/home/RoseTTAFold2-PPI --nv {rosetta_fold_p} \
       /bin/bash -c "cd /work/users && python /home/RoseTTAFold2-PPI/sec/predict_list_PPI.py input_file" && touch run_complete
        # save output
        mv input_file.log $CURDIR/{log}
"""

rule rosettafoldPPI_combine_logs:
    # combine the MSAs together
    input:
        log=expand('rosettafoldPPI_predicted_msas/{id}/{id}-{other}-res.tsv',id=ids,other=[x for x in ids if x != "{id}"]),
    output:
        comb_log = 'rosettafoldPPI_combined_logs/{id}-combined-res.tsv'
    shell:
       """
       # combine the logs in one file per protein
       for f in $(ls {fold})
       do
            grep -v 'done' {fold}/$f >> {comb_log}
       done
       # and then kill them!
       # kill not yet implemented
"""

rule rosettafoldPPI_generate_mats:
    input:
        comb_log=expand('rosettafoldPPI_combined_logs/{id}-combined-res.tsv',id=ids),
    output:
        short_mat_o = 'rosettafoldPPI_combined_mats/short_mat_{}.npy',
        short_mat_i= 'rosettafoldPPI_combined_mats/short_mat_{}.tsv',
        long_mat_o = 'rosettafoldPPI_combined_mats/long_mat_{}.npy',
        long_mat_i= 'rosettafoldPPI_combined_mats/long_mat_{}.tsv',
        completed_run = 'rosettafoldPPI_combined_mats/completed.txt'
    params:
        now = datetime.now().isoformat(timespec='minutes').replace('-','').replace(':','')
    run:
        """
        short_mat_o = short_mat_o.format(params.now)
        short_mat_i = short_mat_i.format(params.now)
        long_mat_o = long_mat_o.format(params.now)
        long_mat_i = long_mat_i.format(params.now)
        
        inf_list = next(os.walk({comb_fold}))[2]
        inp_list = [x.split('/')[-1].split('-')[0] for x in inf_list]
        
        data_storage = {} # save interaction score in a dict of dicts with the two interactors as keys and the prediction score as value
        
        for f in inf_list:
            for line in open({comb_fold} + f):
                line = line.split('\t')
                p1 = line[0].split('-')[0]
                p2 = line[0].split('-')[1]
                score = float(line[1])
        
                data_storage[p1] = data_storage.get(p1,{}) | {p2:score}
                data_storage[p2] = data_storage.get(p2,{}) | {p1:score}
        
        long_inp_list = list(data_storage.keys())
       
        # create short mat
        short_mat = np.diag(np.full(slen,1.))
        for i in range(slen):
            ip = inp_list[i]
            for j in range(slen):
                jp = inp_list[j]
                if ip in data_storage:
                    if jp in data_storage[ip]:
                        short_mat[i][j] = data_storage[ip][jp]
                        short_mat[j][i] = data_storage[jp][ip]
        # save short mat and ids order
        print('created short mat of len {}'.format(slen))
        np.save({short_mat_o},short_mat)
        open({short_mat_i},'w').write('\t'.join(inp_list))
        
        # create long mat
        long_mat = np.diag(np.full(llen,1.))
        for i in range(llen):
            ip = long_inp_list[i]
            for j in range(llen):
                jp = long_inp_list[j]
                if ip in data_storage:
                    if jp in data_storage[ip]:
                        long_mat[i][j] = data_storage[ip][jp]
                        long_mat[j][i] = data_storage[jp][ip]
        # save long mat and ids order
        print('created long mat of len {}'.format(llen))
        np.save({long_mat_o},long_mat)
        open({long_mat_i},'w').write('\t'.join(long_inp_list))
        
        open('{completed_run}','w').write('completed!')

        """

