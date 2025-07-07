
include: '../rules/common.smk'

rule colabfold_msas:
    input:
        csv = 'colabfold_msas_csv/{colabfold_input}.csv',
    output:
        done = 'colabfold_msas_done/{colabfold_input}.done.txt',
    params:
        cache = config['colabfold']['cache'],
        databases = config['colabfold']['databases'],
        container = config['colabfold']['container'],
        xtra_args = config['colabfold']['search_xtra_args'],
    shell: """
        echo Copying input from cluster storage to local scratch
        SMKDIR=`pwd`
        rsync -auq $SMKDIR/ $TMPDIR --include='{input.csv}' --exclude='*'

        echo Running colabfold_search in $TMPDIR
        cd $TMPDIR
        singularity run -B $(pwd):/work -B {params.databases}:/databases {params.container} \
            colabfold_search --threads {threads} {params.xtra_args} /work/{input.csv} /databases /work/colabfold_msas
        mkdir -p colabfold_msas_done
        touch {output.done}
        cd -

        echo Compressing output and copying back to cluster storage
        gzip $TMPDIR/colabfold_msas/*.a3m
        rsync -auv $TMPDIR/colabfold_msas $SMKDIR/
        rsync -auv $TMPDIR/colabfold_msas_done $SMKDIR/
    """

rule colabfold_predictions:
    input:
        msas = 'colabfold_msas',
    output:
        predictions = directory('colabfold_predictions'),
    params:
        cache = config['colabfold']['cache'],
        databases = config['colabfold']['databases'],
        container = config['colabfold']['container'],
        xtra_args = config['colabfold']['batch_xtra_args'],
    shell: """
        echo Copying input from cluster storage to local scratch
        SMKDIR=`pwd`
        rsync -auv $SMKDIR/ $TMPDIR --include='colabfold_msas' --include='colabfold_msas/*.a3m.gz' --exclude='*'
        gunzip -r $TMPDIR/colabfold_msas/

        echo Running colabfold_batch in $TMPDIR
        cd $TMPDIR
        singularity run --nv -B $(pwd):/work -B {params.databases}:/databases -B {params.cache}:/cache {params.container} \
            colabfold_batch {params.xtra_args} /work/colabfold_msas /work/colabfold_predictions
        cd -

        echo Compressing output and copying back to cluster storage
        gzip -r $TMPDIR/colabfold_predictions/*.a3m
        gzip -r $TMPDIR/colabfold_predictions/*.json
        gzip -r $TMPDIR/colabfold_predictions/*.pdb
        rsync -auv $TMPDIR/{rule} $SMKDIR/
    """

ids_, = glob_wildcards('colabfold_input/{id}.csv')

rule colabfold:
    input:
        expand('colabfold_msas_done/{id}.done.txt', id=ids_),
