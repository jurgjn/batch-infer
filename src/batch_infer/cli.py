
import collections, contextlib, copy, filecmp, glob, importlib, importlib.resources, io, itertools, json, os, os.path, re, subprocess, sys, time, zipfile, warnings
from datetime import datetime
from pathlib import Path
from pprint import pprint

import click

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def batch_infer_path(subpath):
    return Path(__file__).parent.parent.parent.resolve() / subpath

@click.group()
def cli():
    pass

#https://click.palletsprojects.com/en/stable/advanced/#forwarding-unknown-options
@cli.command(short_help='Check for files & output sbatch script to start a run', context_settings=dict(ignore_unknown_options=True,))
@click.argument('target', type=str)
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
@click.argument('snakemake_args', nargs=-1, type=click.UNPROCESSED)
def start(target, results_path, snakemake_args):
    """
    batch-infer start alphafold3_datafill_missing
    """

    jobname = f'batch_infer:{target}'
    output_path = results_path / f'.snakemake-eu/logs/{datetime.today().strftime("%y-%m-%d")}/{jobname}-%j.txt'
    lockfile_path = results_path / '.snakemake-eu/batch-infer.lock'
    activate_path = Path(__file__).parent.parent.parent.resolve() / '.venv/bin/activate'
    snakefile_path = Path(__file__).parent.parent.parent.resolve() / f'workflow/targets/{target}.smk'
    configfile_path1 = Path(__file__).parent.parent.parent.resolve() / 'workflow/config/defaults.yaml'
    configfile_path2 = results_path / f'config.yaml'
    for path_ in [activate_path, snakefile_path, configfile_path1, configfile_path2]:
        if not path_.is_file():
            eprint(f'Not a file: {path_}')
            sys.exit(1)

    profile_path = Path(__file__).parent.parent.parent.resolve() / 'workflow/profiles/default'
    for path_ in [results_path, profile_path,]:
        if not path_.is_dir():
            eprint(f'Not a directory: {path_}')
            sys.exit(1)

    # .batch-infer.jobid
    # .batch-infer.sbatch
    jobid_path = results_path / '.batch-infer.lock'
    sbatch_path = results_path / '.batch-infer.sbatch'

    with open(sbatch_path, 'w') as f:
        f.write(f"""#!/usr/bin/env bash
#SBATCH --job-name={jobname}
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4G
#SBATCH --tmp=16G
#SBATCH --time=0-03:00:00
#SBATCH --output={output_path.resolve()}
module load stack/2025-06 python/3.13.0 eth_proxy
source {activate_path.resolve()}
export SMK_JOB_NAME_PREFIX=batch-infer:$SLURM_JOB_ID:
snakemake {target} {' '.join(snakemake_args)} \\
    --snakefile {snakefile_path.resolve()} \\
    --configfile {configfile_path1.resolve()} {configfile_path2.resolve() if configfile_path2.is_file() else ''} \\
    --profile={profile_path.resolve()} \\
    --directory {results_path.resolve()} \\
    --rerun-triggers mtime
myjobs -j $SLURM_JOB_ID
rm {jobid_path.resolve()}
rm {sbatch_path.resolve()}
""")

    run_sbatch = subprocess.run(['sbatch', sbatch_path], capture_output=True, text=True)
    try:
        re_ = re.search(r"Submitted batch job (\d+)$", run_sbatch.stdout)
        jobid = int(re_.group(1))
    except:
        print('Cannot extract jobid from', run_sbatch.stdout)

    with open(jobid_path, 'w') as f:
        f.write(str(jobid))

def get_lockfile_jobid(results_path):
    lockfile_path = results_path / '.batch-infer.lock'
    if not lockfile_path.is_file():
        click.echo('No lockfile found, exiting..')
        raise click.exceptions.Exit(0)

    with open(lockfile_path) as fh:
        jobid = fh.read().strip()
    return jobid

@cli.command(short_help='Show batch-infer jobs running in results_path')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def status(results_path):
    jobid_ = get_lockfile_jobid(results_path)
    subprocess.run(f'squeue --format="%.18i %.20P %.128j %.8T %.16M %.16l %40R" | column -t --table-right 1,5,6 | awk "NR==1 || /{jobid_}/"', shell=True) 

@cli.command(short_help='Print scancel command to stop batch-infer jobs running in results_path')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def stop(results_path):
    jobid_ = get_lockfile_jobid(results_path)
    str_ = subprocess.run("squeue --format='%.18i %.128j' --noheader | " + f'awk "/{jobid_}/"' + " | awk '{ print $1 }' | tr '\n' ' '", shell=True, capture_output=True).stdout.decode('ascii')
    print('scancel %s' % (str_,)) 

@cli.command(short_help='Snakemake unlock')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def unlock(results_path):
    # Run snakemake with a minimal setup to locally unlock the directory
    run_unlock = subprocess.run(['uv', 'tool', 'run', '--from', 'batch-infer', 'python', '-m', 'snakemake', 
                                 '--snakefile', batch_infer_path('workflow/targets/alphafold3_db_dir.smk'),
                                 '--configfile', batch_infer_path('workflow/config/defaults.yaml'),
                                 '--directory', results_path,
                                 '--unlock'], check=True)
    
    for file in [ results_path / '.batch-infer.lock', results_path / '.batch-infer.sbatch' ]:
        if file.is_file():
            click.echo(f'Removing {file.relative_to(results_path)}')
            file.unlink(missing_ok=True)
