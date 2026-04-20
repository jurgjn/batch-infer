
import collections, contextlib, copy, filecmp, glob, io, itertools, json, os, os.path, subprocess, sys, time, zipfile, warnings
from datetime import datetime
from pathlib import Path
from pprint import pprint

import click

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

@click.group()
def cli():
    pass

#https://click.palletsprojects.com/en/stable/advanced/#forwarding-unknown-options
@cli.command(short_help='Check for files & output sbatch script to start a run', context_settings=dict(
    ignore_unknown_options=True,
))
@click.argument('target', type=str)
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path))
@click.argument('snakemake_args', nargs=-1, type=click.UNPROCESSED)
def start(target, results_path, snakemake_args):
    """
    Example:
        batch_infer sbatch alphafold3_datafill_missing projects/ubi_ncORFs/pairwise --dry-run | sbatch
    """

    jobname = f'batch_infer:{target}'
    output_path = results_path / f'.snakemake-eu/logs/{datetime.today().strftime("%y-%m-%d")}/{jobname}-%j.txt'

    activate_path = Path(__file__).parent.parent.parent.parent.parent.resolve() / '.venv/bin/activate'
    snakefile_path = Path(__file__).parent.parent.parent.resolve() / f'workflow/targets/{target}.smk'
    configfile_path1 = Path(__file__).parent.parent.parent.resolve() / 'workflow/config/defaults.yaml'
    configfile_path2 = results_path / f'config.yaml'
    for path_ in [activate_path, snakefile_path, configfile_path1,]:
        if not path_.is_file():
            eprint(f'Not a file: {path_}')
            sys.exit(1)

    profile_path = Path(__file__).parent.parent.parent.resolve() / 'workflow/profiles/default'
    for path_ in [results_path, profile_path,]:
        if not path_.is_dir():
            eprint(f'Not a directory: {path_}')
            sys.exit(1)

    print(f"""#!/usr/bin/env bash
#SBATCH --job-name={jobname}
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4G
#SBATCH --tmp=16G
#SBATCH --time=7-00:00:00
#SBATCH --output={output_path.resolve()}
module load stack/2025-06 python/3.13.0 eth_proxy
source {activate_path.resolve()}
export SMK_JOB_NAME_PREFIX=batch-infer:$SLURM_JOBID:
snakemake {target} {' '.join(snakemake_args)} \\
    --snakefile {snakefile_path.resolve()} \\
    --configfile {configfile_path1.resolve()} {configfile_path2.resolve() if configfile_path2.is_file() else ''} \\
    --profile={profile_path.resolve()} \\
    --directory {results_path.resolve()} \\
    --rerun-triggers mtime
myjobs -j $SLURM_JOB_ID
""")

@cli.command(short_help='Status')
def status():
    subprocess.run('squeue --format="%.18i %.12P %.128j %.8T %.16M %.16l %40R" | column -t --table-right 1,5,6', shell=True) 
