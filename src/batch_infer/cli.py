
import collections, contextlib, copy, filecmp, glob, importlib, importlib.resources, io, itertools, json, os, os.path, re, subprocess, sys, time, zipfile, warnings
from datetime import datetime
from pathlib import Path
from pprint import pprint

import click

from .common import *

@click.group()
def cli():
    pass

class BatchInferError(Exception):
    """Raised when a batch-infer step fails to submit, fails on Slurm, or does not produce its expected output."""
    pass

# Order matters: each target consumes the previous target's output.
DATAFILL_PIPELINE_TARGETS = [
    'alphafold3_datafill_missing',
    'alphafold3_datafill_msas',
    'alphafold3_datafill_predictions',
]

def _submit_target(target, results_path, snakemake_args=()):
    """
    Write an sbatch script for `target` and submit it via sbatch.
    Returns the submitted Slurm job id (int). Raises BatchInferError on any failure.
    """
    jobname = f'batch_infer:{target}'
    activate_path = get_activate()
    snakefile_path = batch_infer_path(f'workflow/targets/{target}.smk')
    configfile1_path = batch_infer_path('workflow/config/defaults.yaml')
    configfile2_path = results_path / f'config.yaml'
    for path_ in [activate_path, snakefile_path, configfile1_path]:
        if not path_.is_file():
            raise BatchInferError(f'Not a file: {path_}')

    profile_path = batch_infer_path('workflow/profiles/default')
    for path_ in [results_path, profile_path,]:
        if not path_.is_dir():
            raise BatchInferError(f'Not a directory: {path_}')

    sbatch_path = results_path / '.batch-infer.sbatch'
    jobid_path = results_path / '.batch-infer.lock'

    with open(sbatch_path, 'w') as f:
        f.write(f"""#!/usr/bin/env bash
#SBATCH --job-name={jobname}
#SBATCH --chdir={results_path.resolve()}
#SBATCH --output=.snakemake-eu/logs/{datetime.today().strftime("%y-%m-%d")}/{jobname}-%j.txt
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4G
#SBATCH --tmp=16G
#SBATCH --time=7-00:00:00
module load stack/2025-06 python/3.13.0 eth_proxy
source {activate_path.resolve()}
export SMK_JOB_NAME_PREFIX=batch-infer:$SLURM_JOB_ID:
snakemake {target} {' '.join(snakemake_args)} \\
    --snakefile {snakefile_path.resolve()} \\
    --configfile {configfile1_path.resolve()} {configfile2_path.resolve() if configfile2_path.is_file() else ''} \\
    --profile={profile_path.resolve()} \\
    --directory {results_path.resolve()} \\
    --rerun-triggers mtime
myjobs -j $SLURM_JOB_ID
rm {jobid_path.resolve()}
rm {sbatch_path.resolve()}
""")

    run_sbatch = subprocess.run(['sbatch', sbatch_path], capture_output=True, text=True)
    re_ = re.search(r"Submitted batch job (\d+)$", run_sbatch.stdout)
    if re_ is None:
        raise BatchInferError(f'Cannot extract jobid from sbatch output: stdout={run_sbatch.stdout!r} stderr={run_sbatch.stderr!r}')
    jobid = int(re_.group(1))

    with open(jobid_path, 'w') as f:
        f.write(str(jobid))

    return jobid

def _wait_for_job(jobid, poll_interval=60):
    """
    Block until Slurm no longer reports `jobid` as pending/running (via squeue).
    """
    while True:
        squeue_ = subprocess.run(['squeue', '-h', '-j', str(jobid)], capture_output=True, text=True)
        if squeue_.stdout.strip() == '':
            return
        time.sleep(poll_interval)

def _get_job_exit_state(jobid, retries=5, retry_interval=5):
    """
    Query sacct for the final state of the driver job (ignoring .batch/.extern sub-steps),
    e.g. 'COMPLETED', 'FAILED', 'TIMEOUT', 'CANCELLED', 'OUT_OF_MEMORY'.
    Returns None if sacct has no record of the job (e.g. accounting DB lag).
    """
    for attempt in range(retries):
        sacct_ = subprocess.run(['sacct', '-j', str(jobid), '-n', '-P', '-o', 'JobID,State'], capture_output=True, text=True)
        for line in sacct_.stdout.splitlines():
            jobid_, _, state_ = line.partition('|')
            if jobid_.strip() == str(jobid):
                return state_.strip()
        time.sleep(retry_interval)
    return None

def _check_expected_output(target, results_path):
    """
    Sanity-check that `target` produced its declared Snakemake output under results_path.
    Raises BatchInferError if the expected output is missing/empty.
    """
    if target == 'alphafold3_datafill_missing':
        missing_dir = results_path / 'alphafold3_missing'
        if not missing_dir.is_dir():
            raise BatchInferError(f'Expected output directory not found: {missing_dir}')

    elif target == 'alphafold3_datafill_msas':
        index_path = results_path / 'alphafold3_msas' / '.af3io_data_index.json'
        if not index_path.is_file():
            raise BatchInferError(f'Expected output file not found: {index_path}')

    elif target == 'alphafold3_datafill_predictions':
        ids_ = [p.stem for p in (results_path / 'alphafold3_jsons').glob('*.json')]
        zip_path = lambda id_: results_path / 'alphafold3_predictions' / f'{id_}.zip'
        problems_ = sorted(
            id_ for id_ in ids_
            if not zip_path(id_).is_file() or zip_path(id_).stat().st_size == 0
        )
        if problems_:
            shown_ = problems_[:10]
            raise BatchInferError(f'Missing or empty prediction output for {len(problems_)} id(s): {shown_}{"..." if len(problems_) > 10 else ""}')

    else:
        raise BatchInferError(f'No output check defined for target: {target}')

@cli.command(short_help='Check for files & output sbatch script to start a run', context_settings=dict(ignore_unknown_options=True,))
@click.argument('target', type=str, default='alphafold3_datafill_predictions')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
@click.argument('snakemake_args', nargs=-1, type=click.UNPROCESSED) #https://click.palletsprojects.com/en/stable/advanced/#forwarding-unknown-options
def start(target, results_path, snakemake_args):
    """
    batch-infer start alphafold3_datafill_missing
    """
    try:
        _submit_target(target, results_path, snakemake_args)
    except BatchInferError as e:
        eprint(str(e))
        sys.exit(1)

def get_lockfile_jobid(results_path):
    lockfile_path = results_path / '.batch-infer.lock'
    if not lockfile_path.is_file():
        click.echo('No lockfile found, exiting..')
        raise click.exceptions.Exit(0)

    with open(lockfile_path) as fh:
        jobid = fh.read().strip()
    return jobid

@cli.command(short_help='Show batch-infer jobs/status')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def status(results_path):
    jobid_ = get_lockfile_jobid(results_path)
    subprocess.run(f'squeue --format="%.18i %.20P %.128j %.8T %.16M %.16l %40R" | column -t --table-right 1,5,6 | awk "NR==1 || /{jobid_}/"', shell=True) 

@cli.command(short_help='Stop batch-infer jobs')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def stop(results_path):
    jobid_ = get_lockfile_jobid(results_path)
    str_ = subprocess.run("squeue --format='%.18i %.128j' --noheader | " + f'awk "/{jobid_}/"' + " | awk '{ print $1 }' | tr '\n' ' '", shell=True, capture_output=True).stdout.decode('ascii')
    args_ = ('scancel %s' % (str_,)).split()
    subprocess.run(args_, check=True)

@cli.command(short_help='Unlock/remove temporary files')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
def unlock(results_path):
    # Run snakemake with a minimal setup to locally unlock the directory
    subprocess.run([sys.executable, '-m', 'snakemake', 
                    '--snakefile', batch_infer_path('workflow/targets/alphafold3_db_dir.smk'),
                    '--configfile', batch_infer_path('workflow/config/defaults.yaml'),
                    '--directory', results_path,
                    '--unlock'], check=True)
    
    # Remove batch-infer script, lockfile
    for file in [ results_path / '.batch-infer.lock', results_path / '.batch-infer.sbatch' ]:
        if file.is_file():
            click.echo(f'Removing {file.relative_to(results_path)}')
            file.unlink(missing_ok=True)

@cli.command(short_help='Run alphafold3_datafill_missing, _msas & _predictions sequentially')
@click.argument('results_path', type=click.Path(exists=True, file_okay=False, dir_okay=True, writable=True, path_type=Path), default=Path.cwd())
@click.option('--poll-interval', default=60, show_default=True, help='Seconds between Slurm job status checks while waiting.')
def datafill(results_path, poll_interval):
    """
    Wrapper around `start` that runs the full datafill pipeline in order,
    waiting for each Slurm job to finish and validating its output before
    starting the next stage:

    \b
        batch-infer start alphafold3_datafill_missing
        batch-infer start alphafold3_datafill_msas
        batch-infer start alphafold3_datafill_predictions

    Aborts (non-zero exit) if a stage fails to submit, finishes with a
    non-COMPLETED Slurm state, or does not produce its expected output.
    """
    for target in DATAFILL_PIPELINE_TARGETS:
        click.echo(f'[datafill] Submitting {target}...')
        try:
            jobid = _submit_target(target, results_path)
        except BatchInferError as e:
            eprint(f'[datafill] Failed to submit {target}: {e}')
            sys.exit(1)

        click.echo(f'[datafill] {target} submitted as Slurm job {jobid}, waiting for it to finish...')
        _wait_for_job(jobid, poll_interval=poll_interval)

        state = _get_job_exit_state(jobid)
        if state is None or not state.startswith('COMPLETED'):
            eprint(f'[datafill] {target} (job {jobid}) did not complete successfully (sacct state: {state}).')
            eprint(f'[datafill] Check Slurm logs under {results_path / ".snakemake-eu" / "logs"}. Aborting pipeline.')
            sys.exit(1)

        try:
            _check_expected_output(target, results_path)
        except BatchInferError as e:
            eprint(f'[datafill] {target} (job {jobid}) reported success but expected output is missing: {e}')
            sys.exit(1)

        click.echo(f'[datafill] {target} completed successfully.')

    click.echo('[datafill] Pipeline finished: missing -> msas -> predictions all completed.')
