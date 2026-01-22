
import os, os.path
import Bio, Bio.PDB
import pandas as pd

ids, = glob_wildcards('input_pdb/{id}.pdb')

rule repairpdb:
    """
    Run foldx repairpdb on structure; output the final .pdb, and a .zip archive of the complete output (multiple files per mutation)
    """
    input:
        pdb = 'input_pdb/{id}.pdb',
    output:
        pdb = 'repairpdb/{id}.pdb',
        #zip = 'repairpdb/{id}.zip',
    params:
        binary = config['foldx']['binary'],
        pdb_dir = lambda wc, input: os.path.dirname(input.pdb),
        pdb_basename = lambda wc, input, output: os.path.basename(input.pdb),
    threads: 1
    resources:
        runtime = lambda wc, attempt: ['4h', '1d', '3d', '1w'][attempt - 1],
        mem_mb = 4096,
        disk_mb = 4096,
    retries: 3
    shell: """
        OUTPUT_DIR="$TMPDIR/RepairPDB_{wildcards.id}"
        mkdir -p $OUTPUT_DIR
        {params.binary} --command=RepairPDB --pdb-dir={params.pdb_dir} --pdb={params.pdb_basename} --output-dir=$OUTPUT_DIR
        #cd $OUTPUT_DIR
        #zip {wildcards.id}.zip *
        #cd -
        cp $OUTPUT_DIR/{wildcards.id}_Repair.pdb {output.pdb}
        #cp $OUTPUT_DIR/{wildcards.id}.zip output.zip
    """

def pssm_positions(file):
    """
    Generates `--positions` argument for `foldx pssm` to mutate all residues into all possible amino acids
    The syntax used for `--positions` is described at: https://foldxsuite.crg.eu/command/PositionScan
    Example/test:
        print(pssm_positions(pfile(struct_id='Q9Y5Z9', step='af2.trim_bf.repairpdb', suffix='.pdb', base='results/foldx')))
    """
    parser = Bio.PDB.PDBParser(QUIET=True)
    struct = parser.get_structure(file, file)
    chain, = struct[0].get_chains()

    def get_resseq(resid):
        return resid.get_id()[1]

    def get_resname(resid):
        resname3 = str(resid.get_resname()).capitalize()
        return Bio.Data.IUPACData.protein_letters_3to1[resname3]

    def get_resid_pssmstr(resid):
        return f'{get_resname(resid)}{chain.id}{get_resseq(resid)}a'

    #return ','.join(list(map(get_resid_pssmstr, Bio.PDB.Selection.unfold_entities(struct[0][chain.id], 'R')))[:2])
    return ','.join(list(map(get_resid_pssmstr, Bio.PDB.Selection.unfold_entities(struct[0][chain.id], 'R'))))

def pssm_write_summary(output_dir, struct_id, out_tsv):
    #zip_ = '../../results/foldx/af2.repairpdb.pssm/Q9/Y5/Z9/Q9Y5Z9.zip'
    #zip_ = pfile(struct_id=struct_id, step='af2.trim_bf.repairpdb.pssm', suffix='.zip', base='../../results/human/')
    txt_ = os.path.join(output_dir, 'individual_list_0_PSSM.txt')
    avg_ = os.path.join(output_dir, f'Average_{struct_id}.fxout')
    with open(txt_) as fh_txt_:
        df_pos_ = pd.read_csv(fh_txt_, names=['pssm_pos'])
    with open(avg_) as fh_avg_:
        df_avg_ = pd.read_csv(fh_avg_, sep='\t')

    def parse_pssm_pos(r):
        aa_pos = int(r.pssm_pos[2:-2])
        aa_ref = r.pssm_pos[0]
        aa_alt = r.pssm_pos[-2]
        chain = r.pssm_pos[1]
        return aa_ref, chain, aa_pos, aa_alt

    df_ = pd.concat([df_pos_, df_avg_], axis=1)
    df_[['aa_ref', 'chain', 'aa_pos', 'aa_alt']] = df_.apply(parse_pssm_pos, axis=1, result_type='expand')
    def apply_(r):
        return f'{struct_id}/{r.aa_ref}{r.aa_pos}{r.aa_alt}'
    df_['variant_id'] = df_.apply(apply_, axis=1)

    cols_ = df_.columns[-5:].tolist() + df_.columns[:-5].tolist()
    df_ = df_[cols_]
    df_.to_csv(out_tsv, sep='\t', header=True, index=False)

rule repairpdb_pssm:
    """
    Calculate ddG values for all residues using `PssmStability` on a monomer structure
    Pssm segfaults on monomer structures during/after analyseComplex-related steps
    PssmStability seems to be a lightly documented (https://foldxsuite.crg.eu/command/Pssm) version of the Pssm command intended to be used on monomers
    """
    input:
        pdb = 'repairpdb/{id}.pdb',
    output:
        tsv = 'repairpdb.pssm/{id}.tsv',
        #zip = 'repairpdb.pssm/{id}.zip',
    params:
        binary = config['foldx']['binary'],
        aminoacids = 'ACDEFGHIKLMNPQRSTVWY', # Bio.SeqUtils.IUPACData.protein_letters
        positions = 'CA143a,PA144a,EA145a', # Q7Z4H8/P144L
        #positions = lambda wc, input: pssm_positions(input.pdb),
        pdb_dir = lambda wc, input: os.path.dirname(input.pdb),
        pdb_basename = lambda wc, input, output: os.path.basename(input.pdb),
        output_dir = lambda wc: f'{os.environ["TMPDIR"]}/PssmStability_{wc.id}',
    threads: 1
    resources:
        runtime = lambda wc, attempt: ['1d', '3d', '1w'][attempt - 1],
        mem_mb = 4096,
        disk_mb = 4096,
    retries: 2
    run:
        shell('echo "Creating directory" && mkdir -p {params.output_dir}')
        shell('{params.binary} --command=PssmStability --aminoacids={params.aminoacids} --positions={params.positions} --pdb-dir={params.pdb_dir} --pdb={params.pdb_basename} --output-dir={params.output_dir}')
        #Uncomment to keep full output as a .zip archive; this will be in GBs per structure
        #shell("""
        #    cd {params.output_dir}
        #    zip {wildcards.id}.zip *
        #    cd -
        #    cp {params.output_dir}/{wildcards.id}.zip {output.zip}
        #""")
        pssm_write_summary(params.output_dir, wildcards.id, output.tsv)

rule foldx_monomer:
    input:
        #expand('repairpdb/{id}.pdb', id=ids),
        expand('repairpdb.pssm/{id}.tsv', id=ids),
