# alphafold_on_euler

This project is to create a script to help users estimate the computing resources required for AlphaFold jobs and automatically output a  run script ready to be submitted.

Usage:

```
./setup_alphafold_run_script.sh -f [Fasta file] -w [work directory] --max_template_date yyyy-mm-dd -b [LSF/SLURM]
```

Example:

```
[jarunanp@eu-login-20 alphafold_on_euler]$ ./setup_alphafold_run_script.sh -f ../../fastafiles/IFGSC_6mer.fasta -w $SCRATCH/alphafold_run
  Reading /cluster/home/jarunanp/alphafold_run/fastafiles/IFGSC_6mer.fasta
  Protein name:              IFGSC_6mer
  Number of sequences:       6
  Protein type:              multimer
  Number of amino acids:
                    sum:     1246
                    max:     242
  Estimate required resources:
    Run time: 
    Number of CPUs: 
    Total CPU memory: 
    Number of GPUs: 
    Total GPU memory: 
    Total scratch space: 
  Output an LSF run script for AlphaFold2: /cluster/scratch/jarunanp/21_12_alphafold_benchmark/scripts/alphafold_on_euler/run_alphafold.bsub
```

## Postprocessing

This script includes a postprocessing step using
[gitlab.ethz.ch/sis/alphafold-postprocessing](https://gitlab.ethz.ch/sis/alphafold-postprocessing).
It will generate a `plot` directory with some plots.
