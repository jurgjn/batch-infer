#!/usr/bin/bash

# Initialize variables
FASTAFILE="undefined.fasta"
WORKDIR=$PWD
MAX_TEMPLATE_DATE=$(date +'%Y-%m-%d')

print_help()
{
   # Display Help
   echo "Script to create input file for AlphaFold2 on Euler."
   echo
   echo "Syntax: setup_alphafold_run_script.sh [-f fastafile] [-w working directory] [--max_template_date Y-M-D] [--skip_minimization]"
   echo "options:"
   echo "-h                     print help and exit"
   echo "-f                     FASTA filename"
   echo "-w                     working directory"
   echo "--max_template_date    format: "
   echo "--skip_minimization    no Amber minimization will be performed"
   echo
}


# Print help if not options are provided
if [[ $# -eq 0 ]];then
    print_help
    exit 1
fi


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
          FASTAFILE=$(readlink -m $2)
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
        --max_template_date)
          # The max template date of the databases to use for pair representation
          # This could affect the accuracy of the outcome
          MAX_TEMPLAT_DATE="$2"
          shift;
          shift;
          ;;
	--skip_minimization)
	  # Amber minimization is done per default
	  # For large proteins with more than 3000 amino acids minimzation is time consuming
          SKIP_MINIMIZATION=True
	  shift;
	  ;;
        * )
          print_help
          exit 1
    esac
done



# Count the number of lines in the fastafile
n_lines=$(grep -cve '^\s*$' $FASTAFILE)
echo "  Number of sequences:       $((n_lines/2))"
# Determine if the protein is a monomer or multimer
# If n_lines = 2 => 1 protein sequence => monomer
# If n_lines > 2 => multiple protein sequences => multimer
if (( "$n_lines" <= 2 )); then
    echo "  Protein type:              monomer"
    OPTIONS="--pdb70_database_path=\$DATA_DIR/pdb70/pdb70 "
elif (( "$n_lines" > 2 )); then
    echo "  Protein type:              multimer"
    OPTIONS="--model_preset=multimer --pdb_seqres_database_path=\$DATA_DIR/pdb_seqres/pdb_seqres.txt --uniprot_database_path=\$DATA_DIR/uniprot/uniprot.fasta \\"
fi

# Determine the sequence length
# The required total GPU mem depends on the sum of the number of amino acids
# The required total CPU mem depends on the max of the number of amino acids
sum_aa=$(awk ' { getline aa; sum+=length(aa); } END { print sum } ' $FASTAFILE)
max_aa=$(awk ' BEGIN {max=0} { getline aa; if (length(aa) > max) {max=length(aa)}} END { print max } ' $FASTAFILE)
echo "  Number of amino acids:"
echo "                    sum:     $sum_aa"
echo "                    max:     $max_aa"

# Estimate the required computing resources
# For simplicity, the two types of GPUs users could select are RTX 2080 Ti with 11GB GPU mem (GPU_MEM_MB>=10240) 
# and TITAN RTX with 24GB GPU mem (GPU_MEM_MB >= 20480)
if (( "$sum_aa" < 200 )); then
    RUNTIME="04:00"
    NCPUS=12
    NGPUS=1
    GPU_MEM_MB=10240
    TOTAL_GPU_MEM_MB=10240
    TOTAL_CPU_MEM_MB=120000
    TOTAL_SCRATCH_MB=120000
    ENABLE_UNIFIED_MEMORY=0
    MEM_FRACTION=1
elif (( "$sum_aa" >= 200 )) && (( "$sum_aa" < 1500 )); then
    RUNTIME="24:00"
    NCPUS=12
    NGPUS=1
    GPU_MEM_MB=10240
    TOTAL_GPU_MEM_MB=20480
    TOTAL_CPU_MEM_MB=120000
    TOTAL_SCRATCH_MB=120000
    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=2
elif (( "$sum_aa" >= 1500 )) && (( "$sum_aa" < 2500 )); then
    RUNTIME="24:00"
    NCPUS=24
    NGPUS=1
    GPU_MEM_MB=20480
    TOTAL_GPU_MEM_MB=81920
    TOTAL_CPU_MEM_MB=240000
    TOTAL_SCRATCH_MB=240000
    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=$((TOTAL_GPU_MEM_MB/GPU_MEM_MB))
elif (( "$sum_aa" >= 2500 )) && (( "$sum_aa" < 3500 )); then
    RUNTIME="48:00"
    NCPUS=48
    NGPUS=1
    GPU_MEM_MB=20480
    TOTAL_GPU_MEM_MB=81920
    TOTAL_CPU_MEM_MB=480000
    TOTAL_SCRATCH_MB=240000
    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=$((TOTAL_GPU_MEM_MB/GPU_MEM_MB))
elif (( "$sum_aa" >= 3500 )); then
    RUNTIME="120:00"
    NCPUS=64
    NGPUS=1
    GPU_MEM_MB=20480
    TOTAL_GPU_MEM_MB=163840
    TOTAL_CPU_MEM_MB=640000
    TOTAL_SCRATCH_MB=320000
    ENABLE_UNIFIED_MEMORY=1
    MEM_FRACTION=$((TOTAL_GPU_MEM_MB/GPU_MEM_MB))
fi

echo -e "    Estimate required resources: " 
echo -e "    Run time: " $RUNTIME
echo -e "    Number of CPUs: " $NCPUS
echo -e "    Total CPU memory: " $TOTAL_CPU_MEM_MB
echo -e "    Number of GPUs: " $NGPUS
echo -e "    Total GPU memory: " $TOTAL_GPU_MEM_MB
echo -e "    Total scratch space: " $TOTAL_SCRATCH_MB

########################################
# Output an LSF run script for AlphaFold
########################################

mkdir -p $WORKDIR
RUNSCRIPT=$WORKDIR/"run_alphafold.bsub"
echo -e "  Output an LSF run script for AlphaFold2: $RUNSCRIPT"

cat <<EOF > $RUNSCRIPT  
#!/usr/bin/bash
#BSUB -n $NCPUS
#BSUB -n $RUNTIME
#BSUB -R "rusage[mem=$((TOTAL_CPU_MEM_MB/NCPUS)), scratch=$((TOTAL_SCRATCH_MB/NCPUS))]"
#BSUB -R "rusage[ngpus_excl_p=$NGPUS] select[gpu_mtotal0>=$GPU_MEM_MB]"
#BSUB -R "span[hosts=1]"
#BSUB -J alphafold

source /cluster/apps/local/env2lmod.sh
module load gcc/6.3.0 openmpi/4.0.2 alphafold/2.2.0
source /cluster/apps/nss/alphafold/venv_alphafold/bin/activate

# Define paths to databases and out put directory
DATA_DIR=/cluster/project/alphafold
OUTPUT_DIR=\${TMPDIR}/output

# Activate unified memory
export TF_FORCE_UNIFIED_MEMORY=$ENABLE_UNIFIED_MEMORY
export XLA_PYTHON_CLIENT_MEM_FRACTION=$MEM_FRACTION.0

python /cluster/apps/nss/alphafold/alphafold-2.1.1/run_alphafold.py \\
--data_dir=\$DATA_DIR \\
--output_dir=\$OUTPUT_DIR \\
--max_template_date="$MAX_TEMPLATE_DATE" \\
--bfd_database_path=\$DATA_DIR/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \\
--uniref90_database_path=\$DATA_DIR/uniref90/uniref90.fasta \\
--uniclust30_database_path=\$DATA_DIR/uniclust30/uniclust30_2018_08/uniclust30_2018_08 \\
--mgnify_database_path=\$DATA_DIR/mgnify/mgy_clusters_2018_12.fa \\
--template_mmcif_dir=\$DATA_DIR/pdb_mmcif/mmcif_files \\
--obsolete_pdbs_path=\$DATA_DIR/pdb_mmcif/obsolete.dat \\
--fasta_paths=$FASTAFILE \\
$OPTIONS

mkdir -p output/$PROTEIN
rsync -av \$TMPDIR/output/$PROTEIN ./output/$PROTEIN

EOF

#env2lmod
#module load gcc/6.3.0 openmpi/4.0.2 alphafold/2.1.1
#alphafold_init
