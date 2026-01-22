
rule repairpdb:
    """
    Run foldx repairpdb on structure; output the final .pdb, and a .zip archive of the complete output (multiple files per mutation)
    """
    input:
        pdb = pfile(struct_id='{}', step='{prev_steps}', suffix='.pdb'),
    output:
        pdb = pfile(struct_id='{}', step='{prev_steps}.repairpdb', suffix='.pdb'),
        #zip = pfile(struct_id='{}', step='{prev_steps}.repairpdb', suffix='.zip'),
    params:
        foldx_bin = '/cluster/home/jjaenes/project/software/foldx/foldx_20241231',
        pdb_dir = lambda wc, input: os.path.dirname(input.pdb),
        pdb_basename = lambda wc, input, output: os.path.basename(input.pdb),
    shell: """
        OUTPUT_DIR="$TMPDIR/RepairPDB_{wildcards.struct_id}"
        mkdir -p $OUTPUT_DIR
        {params.foldx_bin} --command=RepairPDB --pdb-dir={params.pdb_dir} --pdb={params.pdb_basename} --output-dir=$OUTPUT_DIR
        #cd $OUTPUT_DIR
        #zip {wildcards.struct_id}.zip *
        #cd -
        cp $OUTPUT_DIR/{wildcards.struct_id}_Repair.pdb {output.pdb}
        #cp $OUTPUT_DIR/{wildcards.struct_id}.zip output.zip
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

rule pssm:
    """
    Calculate ddG values for all residues using `PssmStability` on a monomer structure
    Pssm segfaults on monomer structures during/after analyseComplex-related steps
    PssmStability seems to be a lightly documented (https://foldxsuite.crg.eu/command/Pssm) version of the Pssm command intended to be used on monomers
    """
    input:
        pdb = pfile(struct_id='{}', step='{prev_steps}', suffix='.pdb'),
    output:
        #zip = pfile(struct_id='{}', step='{prev_steps}.pssm', suffix='.zip'),
        tsv = pfile(struct_id='{}', step='{prev_steps}.pssm', suffix='.tsv'),
        sstat = pfile(struct_id='{}', step='{prev_steps}.pssm', suffix='_sstat.tsv'),
    params:
        foldx_bin = '/cluster/home/jjaenes/project/software/foldx/foldx_20241231',
        aminoacids = 'ACDEFGHIKLMNPQRSTVWY', # Bio.SeqUtils.IUPACData.protein_letters
        positions = lambda wc, input: pssm_positions(input.pdb), #'QA5a,VA6a', #lambda wc, input, output: wc.pos,
        pdb_dir = lambda wc, input: os.path.dirname(input.pdb),
        pdb_basename = lambda wc, input, output: os.path.basename(input.pdb),
        output_dir = lambda wc: f'{os.environ["TMPDIR"]}/PssmStability_{wc.struct_id}',
    resources:
        #runtime = lambda wildcards, attempt: ['4h', '1d', '3d', '1w'][attempt - 1]
        runtime = lambda wildcards, attempt: ['3d', '1w'][attempt - 1]
    run:
        shell('mkdir -p {params.output_dir}')
        shell('{params.foldx_bin} --command=PssmStability --aminoacids={params.aminoacids} --positions={params.positions} --pdb-dir={params.pdb_dir} --pdb={params.pdb_basename} --output-dir={params.output_dir}')
        #Uncomment to keep full output as a .zip archive; this will be in GBs per structure
        #shell("""
        #    cd {params.output_dir}
        #    zip {wildcards.struct_id}.zip *
        #    cd -
        #    cp {params.output_dir}/{wildcards.struct_id}.zip {output.zip}
        #""")
        pssm_write_summary(params.output_dir, wildcards.struct_id, output.tsv)
        shell("sstat --all --parsable2 --job $SLURM_JOB_ID | tr '|' '\\t' > {output.sstat}")