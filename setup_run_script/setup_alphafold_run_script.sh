#!/bin/bash

# Initialize variables
FASTAFILE="undefined.fasta"
WORKDIR=$PWD
MAX_TEMPLATE_DATE=$(date +'%Y-%m-%d')
BATCH_SYS="SLURM"

print_help()
{
   # Display Help
   echo "Script to create input file for AlphaFold2 on Euler. This script poroposes the resources that could be used for a given protein length."
   echo "We would advise to keep the number of cores set to 8, as our scaling tests did not show any improvements in runtime with an increased number of cores."
   echo "However, if you have a better estimation for the runtime, memory and other resources/parameters, please feel free to modify the script to fit your requirements." 
   echo
   echo "Syntax: setup_alphafold_run_script.sh [-f fastafile] [-w working directory] [--max_template_date Y-M-D] [--reduced_dbs] [--skip_minimization] [--reduced_rsync]"
   echo "options:"
   echo "-h                     print help and exit"
   echo "-f                     FASTA filename"
   echo "-s                     shareholder group for the use of GPUs. Mandatory for the submissions of scripts with SLURM"
   echo "-w                     working directory"
   echo "--reduced_dbs          use settings with reduced hardware requirements"
   echo "--max_template_date    format: "
   echo "--skip_minimization    no Amber minimization will be performed"
   echo "--reduced_rsync        skip copying large output files (MSAs, .pkl-files) from temporary storage on the compute node"
   echo
   exit 1
}

# Print help if not options are provided
if [[ $# -eq 0 ]];then
    print_help
    exit 1
fi

REDUCED_DBS=False
SKIP_MINIMIZATION=False
REDUCED_RSYNC=False

# Parse in arguments
while [[ $# -gt 0 ]]; do
    case $1 in
	 -h|--help)
          # Print help and exit
          print_help
          exit
	  ;;
        -f|--fastafile)
          # Get absolute path
          FASTAFILE=$(readlink -f $2)
          # Get the protein name
          fastaname=$(basename -- "$FASTAFILE")
          PROTEIN="${fastaname%.*}"
          echo "  Reading $FASTAFILE"
          echo "  Protein name:              $PROTEIN"
          shift;
          shift;
          ;;
        -w|--workdir)
          # Users can specify a work directory, e.g., $SCRATCH/alphafold_tests
          # Otherwise it will use the current directy as a work directory
          WORKDIR="$2"
          shift;
          shift;
          ;;
        -s|--shareholder)
          # For the submission of SLURM jobs, the shareholder group is mandatory
          SHAREHOLDER_GROUP="$2"
          shift;
          shift;
          ;;
        --max_template_date)
          # The max template date of the databases to use for pair representation
          # This could affect the accuracy of the outcome
          MAX_TEMPLATE_DATE="$2"
          shift;
          shift;
          ;;
	--reduced_dbs)
	  # Amber minimization is done per default
	  # For large proteins with more than 3000 amino acids minimzation is time consuming
          REDUCED_DBS=True
	  shift;
	  ;;
	--skip_minimization)
	  # Amber minimization is done per default
	  # For large proteins with more than 3000 amino acids minimzation is time consuming
          SKIP_MINIMIZATION=True
	  shift;
	  ;;
	--reduced_rsync)
	  # Skip copying large results files (MSAs, pickles) from the compute nodes
          REDUCED_RSYNC=True
	  shift;
	  ;;
        * )
          print_help
          exit 1
    esac
done


if [[ $BATCH_SYS = "SLURM" &&  $SHAREHOLDER_GROUP = "" ]]; then
        echo
        echo -e "Please provide your shareholder group with the -s option"
        echo -e "This parameter is mandatory when requesting GPUs with SLURM"
        echo -e "You can display all the groups you are a part of on Euler using the my_share_info command"
        echo
        print_help
fi

# Count the number of lines in the fastafile
n_lines=$(cat $FASTAFILE | awk '{if(NR==1) {print $0} else {if($0 ~ /^>/) {print "\n"$0} else {printf $0}}}' | grep -cve '^\s*$')
echo "  Number of sequences:       $((n_lines/2))"

# Determine if the protein is a monomer or multimer
# If n_lines = 2 => 1 protein sequence => monomer
# If n_lines > 2 => multiple protein sequences => multimer
if (( "$n_lines" <= 2 )); then
    echo "  Protein type:              monomer"
    OPTIONS="--model_preset=monomer --pdb70_database_path=\$DATA_DIR/pdb70/pdb70 \\"$'\n'
elif (( "$n_lines" > 2 )); then
    echo "  Protein type:              multimer"
    OPTIONS="--model_preset=multimer --pdb_seqres_database_path=\$DATA_DIR/pdb_seqres/pdb_seqres.txt --uniprot_database_path=\$DATA_DIR/uniprot/uniprot.fasta \\"$'\n'
    if (( "$REDUCED_DBS" == True )); then
        OPTIONS+="--num_multimer_predictions_per_model=1 \\"$'\n'
    fi
fi

if [ "$REDUCED_DBS" = True ]; then
    OPTIONS+="--db_preset=reduced_dbs \\"$'\n'
    OPTIONS+="--small_bfd_database_path=\$DATA_DIR/small_bfd/bfd-first_non_consensus_sequences.fasta \\"$'\n'
else
    OPTIONS+="--db_preset=full_dbs \\"$'\n'
    OPTIONS+="--bfd_database_path=\$DATA_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \\"$'\n'
    OPTIONS+="--uniref30_database_path=\$DATA_DIR/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \\"$'\n'
fi

if [ "$SKIP_MINIMIZATION" = True ]; then
    OPTIONS+="--run_relax=False --use_gpu_relax=False \\"$'\n'
else
    OPTIONS+="--run_relax=True --use_gpu_relax=True \\"$'\n'
fi

if [ "$REDUCED_RSYNC" = True ]; then
    RSYNC_OPTIONS="--exclude msas/ --exclude '*.pkl' "
else
    RSYNC_OPTIONS=""
fi

# Determine the sequence length
# The required total GPU mem depends on the sum of the number of amino acids
# The required total CPU mem depends on the max of the number of amino acids
sum_aa=$(cat $FASTAFILE | awk '{if(NR==1) {print $0} else {if($0 ~ /^>/) {print "\n"$0} else {printf $0}}}' | awk ' { getline aa; sum+=length(aa); } END { print sum } ')
max_aa=$(cat $FASTAFILE | awk '{if(NR==1) {print $0} else {if($0 ~ /^>/) {print "\n"$0} else {printf $0}}}' | awk ' BEGIN {max=0} { getline aa; if (length(aa) > max) {max=length(aa)}} END { print max } ')
echo "  Number of amino acids:"
echo "                    sum:     $sum_aa"
echo "                    max:     $max_aa"

# Estimate the required computing resources
NCPUS=8
NGPUS=1
if (( "$sum_aa" < 200 )); then
    RUNTIME="04:00"
    
    GPU_MEM_MB=10240
    
    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=120000

    ENABLE_UNIFIED_MEMORY=0
    MEM_FRACTION=1

elif (( "$sum_aa" >= 200 )) && (( "$sum_aa" < 1500 )); then
    RUNTIME="24:00"
    
    GPU_MEM_MB=20240
    
    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=120000

    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=2

elif (( "$sum_aa" >= 1500 )) && (( "$sum_aa" < 2500 )); then
    RUNTIME="24:00"

    GPU_MEM_MB=40000
    
    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=240000

    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=4

elif (( "$sum_aa" >= 2500 )) && (( "$sum_aa" < 3500 )); then
    RUNTIME="48:00"

    GPU_MEM_MB=80000

    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=240000
    
    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=4

elif (( "$sum_aa" >= 3500 )); then
    RUNTIME="120:00"
    
    GPU_MEM_MB=80000
    
    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=320000

    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=8
fi

echo
echo -e "    Estimate required resources, please do not hesitate to adjust if required: "
echo -e "    Run time:            " $RUNTIME
echo -e "    Number of CPUs:      " $NCPUS
echo -e "    Total CPU memory:    " $TOTAL_CPU_MEM_MB
echo -e "    Number of GPUs:      " $NGPUS
echo -e "    Total GPU memory:    " $GPU_MEM_MB
echo -e "    Total scratch space: " $TOTAL_SCRATCH_MB
echo

########################################
# Output an SLURM run script for AlphaFold
########################################

mkdir -p $WORKDIR
RUNSCRIPT=$WORKDIR/"$PROTEIN.sbatch"
echo -e "  Output a SLURM run script for AlphaFold2: $RUNSCRIPT"

RUNTIME="${RUNTIME}":00" "

cat <<EOF > $RUNSCRIPT
#!/usr/bin/bash
#SBATCH -n $NCPUS
#SBATCH --time=$RUNTIME
#SBATCH --mem-per-cpu=$((TOTAL_CPU_MEM_MB/NCPUS))
#SBATCH --ntasks-per-node=$NCPUS
#SBATCH --nodes=1
#SBATCH -G $NGPUS
#SBATCH --gres=gpumem:$GPU_MEM_MB
#SBATCH --tmp=$TOTAL_SCRATCH_MB
#SBATCH -A $SHAREHOLDER_GROUP
#SBATCH -J af2_$PROTEIN
#SBATCH -e $WORKDIR/$PROTEIN.err.txt
#SBATCH -o $WORKDIR/$PROTEIN.out.txt

source /cluster/apps/local/env2lmod.sh
module load gcc/6.3.0 openmpi/4.0.2 alphafold/2.3.1
module load alphafold-postprocessing
source /cluster/apps/nss/alphafold/venv_alphafold_2.3.1/bin/activate

# Define paths to databases and output directory
DATA_DIR=/cluster/project/alphafold
OUTPUT_DIR=\${TMPDIR}/output

# Activate unified memory
export TF_FORCE_UNIFIED_MEMORY=$ENABLE_UNIFIED_MEMORY
export XLA_PYTHON_CLIENT_MEM_FRACTION=${MEM_FRACTION}.0


python /cluster/apps/nss/alphafold/alphafold-2.3.1/run_alphafold.py \\
--data_dir=\$DATA_DIR \\
--output_dir=\$OUTPUT_DIR \\
--max_template_date="$MAX_TEMPLATE_DATE" \\
--uniref90_database_path=\$DATA_DIR/uniref90/uniref90.fasta \\
--mgnify_database_path=\$DATA_DIR/mgnify/mgy_clusters_2018_12.fa \\
--template_mmcif_dir=\$DATA_DIR/pdb_mmcif/mmcif_files \\
--obsolete_pdbs_path=\$DATA_DIR/pdb_mmcif/obsolete.dat \\
$OPTIONS --fasta_paths=$FASTAFILE

# Produce some plots using the postprocessing script from
# https://gitlab.ethz.ch/sis/alphafold-postprocessing
# :

python -u /cluster/apps/nss/alphafold/alphafold-postprocessing/1.0.0/bin/postprocessing.py -o $OUTPUT_DIR/$PROTEIN/plots $OUTPUT_DIR/$PROTEIN

rsync -av $RSYNC_OPTIONS \$TMPDIR/output/$PROTEIN $WORKDIR

touch $WORKDIR/$PROTEIN.done

EOF
