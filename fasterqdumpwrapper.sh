#!/bin/bash -l
#SBATCH -p cpu_dev,cpu_short,cpu_medium,fn_short,fn_medium
#SBATCH --job-name=fqd
#SBATCH -N 1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=20gb
#SBATCH -t 12:00:00
#SBATCH -o /PATH/TO/JOBREPS/%x-%A_%a.out
#SBATCH --array=0-4

### Zero-based indexing: for 5 sratables, 0-4 will be the indices
# 0 - SraRunTable_GSE141038_SharmaOneBl.csv
# 1 - SraRunTable_GSE161494_AfonsoOneCtl.csv
# 2 - SraRunTable_GSE168389_SchlegelTwoBlAndOneReg.csv
# 3 - SraRunTable_GSE246316_BarciaDuranTwoLL.csv
# 4 - SraRunTable_GSE253555_CyrTwoBL.csv

# YOU MUST SOURCE YOUR OWN CONDA ENV OR ACTIVATE IT WITH "conda activate"
source /gpfs/data/cvrcbioinfolab/af1778/condaenvs/CONDA_SH_SCRIPTS/sratoolkit_af1778.sh



## INPARAMS ##

#INPUT FOLDER, SHOULD HAVE A SUBDIR CALLED sraruntables
# infolder=/gpfs/data/moorelab/CoenERV.2025.03.04/data/MouseMetaAnalysis
infolder=PATH/TO/FOLDER

#n threads
nthreads=10

#outputs
alloutsdir=${infolder}/GEOSRA



## CLOSE INPARAM DEFS


### get the sra ids from the sra table ###
cd $infolder

## first, get the sra table
sratabfolder=${infolder}/sraruntables
srafiles=($(ls -1q "$sratabfolder"))
this_srafile=${srafiles[$SLURM_ARRAY_TASK_ID]}

srafilepath=$sratabfolder/$this_srafile

echo $this_srafile
echo $SLURM_ARRAY_TASK_ID
echo $srafilepath



## strip GSE id and make outdir


# Remove 'SraRunTable_' from the start
gse_id="${this_srafile#SraRunTable_}"
# Remove everything after the first '_'
gse_id="${gse_id%%_*}"
echo "$gse_id"

#lets call outdir as the gse srr dir
rawoutsdir=$alloutsdir/GSEdir
outdir=$rawoutsdir/$gse_id

mkdir -p $outdir
cd $outdir





##### DOWNLOAD SRR USING FASTERQDUMP
printf '\n\n\nFASTERQDUMP START\n\n\n'



### loop over SRRs in the file ####

# read the file, get the Run column

## Extract column index for "Run"
# col_idx=$(head -1 "$srafilepath" | awk -F',' '{for (i=1; i<=NF; i++) if ($i ~ /^ *Run *$/) print i}')
## Extract values from that column (excluding header) and store in array
# mapfile -t run_array < <(awk -F',' -v col="$col_idx" 'NR > 1 {print $col}' "$srafilepath")

#actually use csvkit to get run column as an array; and get all other relevant info now...
# mapfile -t run_ids < <(csvcut -c "Run" "$srafilepath" | tail -n +2)
mapfile -t sample_names < <(csvcut -c "Sample Name" "$srafilepath" | tail -n +2)
mapfile -t run_ids < <(csvcut -c "Run" "$srafilepath" | tail -n +2)
mapfile -t sample_names_dedup < <(printf '%s\n' "${sample_names[@]}" | sort -u)



# Loop over array


printf '\n\n\nRunning...\n\n\n'

for SRR_ID in "${run_ids[@]}"; do

	echo "$SRR_ID"

#	parallel-fastq-dump \
#        --sra-id $SRR_ID \
#        --tmpdir $outdir \
#        --threads $nthreads \
#        --split-files \
#        --gzip

        printf '\n\n'
        echo 'Prefetching'

	prefetch $SRR_ID


        printf '\n\n'
	echo 'Dumping'

	fasterq-dump \
	${SRR_ID}/${SRR_ID}.sra \
	--split-3 \
	--include-technical \
	-vvv \
	-p \
	-x \
	-e $nthreads

	printf '\n\n'
	echo 'Zipping'

	pigz -p $nthreads *.fastq


done





printf '\n\n\nFASTERQDUMP DONE\n\n\n'







### prepare sample parsing
printf '\n\n\nPARSING START\n\n\n'

cd $infolder
# outdir=${infolder}/GEOSRA/gsedir
# newoutdir=${infolder}/GEOSRA/PARSED
newoutdir=${alloutsdir}/PARSED
sampoutdir=$newoutdir/$gse_id


mkdir -p $sampoutdir
cd $sampoutdir



# Read "Sample Name" and "Run" columns into arrays using csvcut
# mapfile -t sample_names < <(csvcut -c "Sample Name" "$srafilepath" | tail -n +2)
# mapfile -t run_ids < <(csvcut -c "Run" "$srafilepath" | tail -n +2)
# mapfile -t sample_names_dedup < <(printf '%s\n' "${sample_names[@]}" | sort -u)

declare -A sample_map  # Associative array to map samples to SRR IDs

# Populate mapping
for i in "${!sample_names[@]}"; do
    sample="${sample_names[$i]}"
    run="${run_ids[$i]}"
    sample_map["$sample"]+="$run "  # Append run IDs to the sample key
done



## test the mapping ##
printf '\n\n\nPARSING TEST\n\n\n'

for sample in "${!sample_map[@]}"; do
        echo $sample

    for run in ${sample_map["$sample"]}; do
        echo "${sample} - ${run}"

         for fqfile in $(ls $outdir/${run}_*.fastq.gz); do
                echo $fqfile; 
	done

    done

printf '\n\n'

done



printf '\n\n\nPARSING ATTEMPTING\n\n\n'


# Create directories and symlink files
for sample in "${!sample_map[@]}"; do
    sample_dir="$sampoutdir/$sample"
    mkdir -p "$sample_dir"

    for run in ${sample_map["$sample"]}; do

	 for fqfile in $(ls $outdir/${run}_*.fastq.gz); do
		# echo $fqfile; 

		ln -s $fqfile $sample_dir/

		done
    done
done




printf '\n\n\nPARSING DONE\n\n\n'







### RENAME FOR CELLRANGER ###
printf '\n\n\nRENAME FOR CELLRANGER START\n\n\n'

cd $infolder


base_dir=$newoutdir

#get dedeuplicated sample name array
# mapfile -t sample_names_dedup < <(printf '%s\n' "${sample_names[@]}" | sort -u)



# loop thru dirs, changing the names to 10X friendly format
# if one GSM had multiple SRRs, name them like "lanes" of sequencing 
# which is (probably actually how it happened)

for gsm_name in "${sample_names_dedup[@]}"; do


    echo $gsm_name
    gsm_dir=$base_dir/$gse_id/$gsm_name
    echo $gsm_dir

    #extract srr ids for this folder
    srr_ids=($(ls "$gsm_dir" | sed -E 's/_[0-9]\.fastq\.gz//' | sort -u))



    # Assign lane numbers dynamically
    lane_number=1
    for srr_id in "${srr_ids[@]}"; do
	#echo $srr_id
        #for read in 1 2; do
        #    old_file="$gsm_dir/${srr_id}_${read}.fastq.gz"
        #    new_name="$gsm_dir/${gsm_name}_S1_L$(printf "%03d" "$lane_number")_R${read}_001.fastq.gz"

	for old_file_fp in $(ls $gsm_dir/${srr_id}_*.fastq.gz); do
	    old_file=$(basename $old_file_fp)

	    #extract read num
	    readnum="${old_file##*_}"
	    readnum="${readnum%%.*}"

	    #define new name
	    new_name="$gsm_dir/${gsm_name}_S1_L$(printf "%03d" "$lane_number")_R${readnum}_001.fastq.gz"

            # Rename symlink
            ls $old_file_fp
            echo $new_name
            mv -v "$old_file_fp" "$new_name"
        done
        ((lane_number++))  # Increment lane number
    done

    printf '\n'


done





printf '\n\n\nRENAME FOR CELLRANGER DONE\n\n\n'



