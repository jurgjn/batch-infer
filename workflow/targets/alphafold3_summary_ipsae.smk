
import functools, pandas as pd, af3io, pooled_ppi
from pprint import pprint

# https://github.com/DunbrackLab/IPSAE/issues/26#issuecomment-3930485269
# > You're correct -- the dist_cutoff does not change the scores. The first cutoff (the PAE cutoff) is used to calculate the ipSAE scores 
# > and the nres1 and nres2 numbers reflect the number of residues in chain1 and chain2 respectively that have at least one residue pair 
# > better than the cutoff with the other chain.
pae_cutoff = config['alphafold3_summary_ipsae']['pae_cutoff']
dist_cutoff = config['alphafold3_summary_ipsae']['dist_cutoff']

rule alphafold3_summary_ipsae_run:
    input:
        zip = 'alphafold3_predictions/{name}.zip',
    output:
        pml         = f'alphafold3_summary_ipsae_{pae_cutoff}_{dist_cutoff}/{{name}}/{{name}}_model_{pae_cutoff}_{dist_cutoff}.pml.gz',
        txt         = f'alphafold3_summary_ipsae_{pae_cutoff}_{dist_cutoff}/{{name}}/{{name}}_model_{pae_cutoff}_{dist_cutoff}.txt.gz',
        byres_txt   = f'alphafold3_summary_ipsae_{pae_cutoff}_{dist_cutoff}/{{name}}/{{name}}_model_{pae_cutoff}_{dist_cutoff}_byres.txt.gz',
    params:
        confidences = lambda wc: f'{wc.name}/{wc.name}_confidences.json',
        summary     = lambda wc: f'{wc.name}/{wc.name}_summary_confidences.json',
        model       = lambda wc: f'{wc.name}/{wc.name}_model.cif',
        ipsae_py    = '/cluster/project/beltrao/jjaenes/25.12_pooled-ppi-yeast/packages/batch-infer/software/IPSAE/ipsae.py',
    threads: 1
    retries: 1
    resources:
        # https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#dynamic-resources
        runtime = lambda wc, attempt: ['1h', '1d', '3d', '7d'][attempt - 1],
        mem_mb = lambda wc, attempt: [12288, 32768, 65536, 131072][attempt - 1]
    shell: """
        mkdir -p $TMPDIR/{wildcards.name}
        unzip -p {input.zip} {params.confidences} > $TMPDIR/{params.confidences}
        unzip -p {input.zip} {params.summary}     > $TMPDIR/{params.summary}
        unzip -p {input.zip} {params.model}       > $TMPDIR/{params.model}
        python {params.ipsae_py} $TMPDIR/{params.confidences} $TMPDIR/{params.model} {pae_cutoff} {dist_cutoff}
        gzip -c $TMPDIR/{wildcards.name}/{wildcards.name}_model_{pae_cutoff}_{dist_cutoff}.pml > {output.pml}
        gzip -c $TMPDIR/{wildcards.name}/{wildcards.name}_model_{pae_cutoff}_{dist_cutoff}.txt > {output.txt}
        gzip -c $TMPDIR/{wildcards.name}/{wildcards.name}_model_{pae_cutoff}_{dist_cutoff}_byres.txt > {output.byres_txt}
        """

names, = glob_wildcards('alphafold3_predictions/{name}.zip')

localrules: alphafold3_summary_ipsae

rule alphafold3_summary_ipsae:
    input:
        expand(f'alphafold3_summary_ipsae_{pae_cutoff}_{dist_cutoff}/{{name}}/{{name}}_model_{pae_cutoff}_{dist_cutoff}.txt.gz', name=names),
