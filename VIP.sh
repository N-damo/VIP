#!/bin/bash
#
#	This is the main driver script for the VIP pipeline.
#
#	Quick guide:
#	Create default config file.
#		$0 -z -i <NGSfile> -p <454/iontor/illumina> -f <fastq/fasta/bam/sam> -r <reference_path>
#
#	Run VIP with the config file:
#		$0 -c <configfile> -i <NGSfile>
#
#	Run VIP with verification mode
#		$0 -i <NGSfile> -v
### Authors : Yang Li <liyang@ivdc.chinacdc.cn>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2015-07-05
#

VIP_version="0.1.1"

if [ $# -lt 1 ]
then
	echo "Please type $0 -h for helps"
	exit 65
fi

while getopts ":i:f:p:c:r:zhv" opt
do
	case "${opt}" in
		i) NGS=${OPTARG}
		   HELP=0		
		;;
		f) FORMAT=${OPTARG}
		#echo "${OPTARG}"
		;;
		c) config_file=${OPTARG}
		;; 
		h) HELP=1
		#echo "HELP IS $HELP"
		;;
		z) CONFIG=1 # create config_file
		;;
		v) VERIFICATION=1 # check the dependancies
		;;
		r) REF_PATH=${OPTARG} #reference DB path
		;;
		p) PLATFORM=${OPTARG} #
		;;
		?) echo "Option -${opt} requires an argument. Please type $0 -h for helps" >&2
		exit 1
		;;
	esac
done

if [ $HELP -eq 1 ]
then
	cat <<USAGE

VIP version ${VIP_version}

This program will run the VIP pipeline with the parameters supplied by the config file.

Command Line Switches:

	-h	Show this help & ignore all other switches

	-i	Specify NGS file for processing

	-f	Specify NGS file format (fastq/fasta/bam/sam)
		
		VIP will support more NGS file formats in the future
		
	-p	Specify the sequence platform (iontor/illumina/454)
		
		VIP will perform further analysis accroding to the sequencing platform.
		
	-r	Specify the PATH for database (DB)

		VIP will search the reference DB under the Path provided.
		
			• host_DB
			• fast_nucl_DB
			• sense_nucl_DB
			• sense_prot_DB
			• tax_DB

	-v	Verification mode

		When using verification mode, VIP will check necessary dependencies.
		This same verification is also done before each VIP run.

			• software dependencies
				VIP will check for the presence of all software dependencies. (software lists are available online)
			• taxonomy lookup functionality
				VIP verifies the functionality of the taxonomy lookup. 

	-z	This switch will create a standard config file.

Usage:

	Create default config file.
		$0 -z -i <NGSfile> -p <454/iontor/illumina> -f <fastq/fasta/bam/sam> -r <reference_path>

	Run VIP with the config file:
		$0 -c <configfile> -i <NGSfile>

	Run VIP with verification mode
		$0 -i <NGSfile> -v

USAGE
	exit
fi

if [ ! -f $NGS ]
then
	echo "$NGS file doesnot exist. Please check it"
	exit 65
fi

if [ ! $CONFIG ]
then
	CONFIG=0
fi

if [ $CONFIG -eq "1" ] && [ -f $NGS ] && [ $PLATFORM ] && [ $FORMAT ]
then
	if [ "$PLATFORM" = "illumina" ]
	then
		quality_threshold=20
	elif [ "$PLATFORM" = "iontor" ]
	then
		quality_threshold=17
	elif [ "$PLATFORM" = "454" ]
	then	
		quality_threshold=15
	else
		echo "$0:The platform $PLATFORM cannot be supported. Please check the platform. Currently the format supported by this pipeline are : illumina/iontor/454"
		exit 65
	fi

	if [ "$FORMAT" = "bam" ] || [ "$FORMAT" = "sam" ] || [ "$FORMAT" = "fastq" ] || [ "$FORMAT" = "fasta" ]
	then 
		echo "The format of Input file is $FORMAT"
	else
		echo "$0:NOT A VALID FILE FORMAT. Please check the format of the input file. Currently the format supported by this pipeline are : sam/bam/fastq/fasta"
	exit 65
	fi
#------------------------------------------------------------------------------------------------
(
	cat <<EOF
# This is the config file used by VIP. 
# It contains parameters critical for VIP. Please 
# Do not change the VIP_version - it is auto-generated.
# and used to ensure that the config file used matches the version of the VIP pipeline run.
VIP_config_version="$VIP_version"

##########################
#  PATH for VIP
##########################
#The variable REF_PATH is the top branch of VIP scripts and its dependancies.
#All software dependencies were installed in REF_PATH/bin

PATH=$PATH:/usr/VIP:/usr/VIP/bin:/usr/VIP/edirect
VIP_TT_DIR=$REF_PATH

##########################
#  Input file
##########################

#VIP can take NGS file generated from different sequencing platform, such as 454/iontor/illumina.
inputfile="$NGS"

#input filetype. [FASTA/FASTQ/BAM/SAM]
inputtype="$FORMAT"
#sequence platform. [454/iontor/illumina]
platform="$PLATFORM"

##########################
#  Quality version
##########################

#FASTQ quality score type: [Sanger/Illumina]
#Sanger = Sanger score (ASCII-33)
#Illumina = Illumina score (ASCII-64)
#For more details about quality version, refer to https://en.wikipedia.org/wiki/FASTQ_format#Quality
quality="Sanger"

##########################
# Run Mode
##########################

#Run mode to use. [fast/sense]
#fast mode allows nucleotide alignment (Bowtie2) to viral DB collected from ViPR/IRD
#sense mode allows both nucleotide alignment and amino acid alignment to curated viral databases collected from nt/nr
run_mode="sense"

##########################
# Preprocessing
##########################

#preprocess parameter to skip preprocessing or not
#skipping preprocess is useful for large data sets that have already undergone preprocessing step such as data from SRA.
#default yes
#preprocess=Y/N
preprocess="Y"

#Specific parameters for preprocess
#average quality cutoff (17 for PGM, 15 for 454, 18 for illumina)
quality_cutoff="$quality_threshold"
#length_cutoff: after quality and adaptor trimming, any sequence with length smaller than length_cutoff will be discarded
length_cutoff="20"

#Cropping reads prior to further process
#left_cutoff = start crop from left
#crop_length = start crop from right
left_cutoff=10
right_cutoff=0

#Removing Background-related reads
#default yes
#background=Y/N
background=Y

##########################
# Bowtie2
##########################

#Bowtie2 executable
#if using installer.sh under VIP, the path should be /usr/bin/
bowtie_path="/usr/bin/"

##########################
# RAPSEARCH
##########################

#RAPSearch database method to use. [Viral/NR]
#if using installer.sh under VIP, the path should be /usr/VIP/bin
rapsearch_path="/usr/VIP/bin"

#RAPSearch e_cutoffs
#E-value of 1e+1, 1e+0 1e-1 is represented by RAPSearch2 http://omics.informatics.indiana.edu/mg/RAPSearch2/ in log form (1,0,-1).
#Larger E-values are required to find highly divergent viral sequences.
rapsearch_ecutoff="1"

#This parameter sets whether RAPSearch will be run in its fast mode or its normal mode.
# see RAPSearch -a option for details
# T will give (10~30 fold) speed improvement, at the cost of sensitivity at high e-values
# [T: perform fast search, F: perform normal search]
rapsearch_mode="T"


##########################
# de novo Assembly
##########################

#kmer value for multiple k-mer based de novo assembly process
kmer_start=7
kmer_end=31
kmer_step=2

##########################
# Reference Data
##########################
#	• host_DB
#	• fast_nucl_DB
#	• sense_nucl_DB
#	• sense_prot_DB
#	• sense_bac_DB
#	• tax_DB
#	
# bowtie-indexed database of host genome for subtraction phase

host_DB="$REF_PATH/HOST/host"

# directory for databases in fast mode 
# directory must ONLY contain bowtie indexed databases (ViPR/IRD)
fast_nucl_DB="$REF_PATH/FAST/vipdb_fast"

# directory for databases in sense mode
# directory must ONLY contain bowtie indexed databases (NT)
sense_nucl_DB="$REF_PATH/SENSE/NUCL/vipdb_sense_nucl"

# directory for bacteria database in sense mode
sense_bac_DB="$REF_PATH/BAC/vipdb_sense_bac"

#Taxonomy Reference data directory
#This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh" 
#gi_taxid_nucl.db - nucleotide db of gi/taxid
#gi_taxid_prot.db - protein db of gi/taxid
#names_nodes_scientific.db - db of taxonid/taxonomy
tax_DB="$REF_PATH/TAX/"

#RAPSearch viral database name: indexed protein dataset (Refseq)
#make sure that directory also includes the .info file 
sense_prot_DB="$REF_PATH/SENSE/AA/vipdb_sense_prot"

EOF
) > $NGS.conf
#chmod 777 $NGS.conf
echo "Config file for $NGS generated! Please type $0 -c $NGS.conf -i $NGS to run VIP"
exit
fi
# 
if [ -r $config_file ] &&  [ -f "$NGS" ]
then
	source $config_file
	#verify that config file version matches SURPI version
	if [ "$VIP_config_version" != "$VIP_version" ]
	then
		echo "ERROR!!!ERROR!!!"
		echo "The config file $NGS.conf was created by VIP version $VIP_config_version not the current VIP version $VIP_version"
		echo "Please re-generate the config file with current VIP version $VIP_version."
		exit 65
	fi
	
else
	echo "Please check the config file $config_file and the ngs file $NGS."
	exit 65
fi
####system info
total_cores=$(grep processor /proc/cpuinfo | wc -l)
####
echo -e "############################################################################"
echo -e "##### ####### # ##    ######################################################"
echo -e "###### ##### ## ## ## ######################################################"
echo -e "####### ### ### ##    ######################################################"
echo -e "######## # #### ## #########################################################"
echo -e "######### ##### ## #########################################################"
echo -e "############################################################################"
echo -e "####\tParameters:"
echo -e "####\tThe NGS file:	"$inputfile""
echo -e "####\tThe NGS file format:	"$inputtype""
echo -e "####\tThe platform is:	"$platform""
echo -e "####\tQuality format is:	"$quality""
echo -e "####\tPreprocess?:	"$preprocess""
echo -e "####\tquality_cutoff:	"$quality_cutoff""
echo -e "####\tThe min length of reads to keep:	"$length_cutoff""
echo -e "####\tLetters were discarded from 5 end:	"$left_cutoff""
echo -e "####\tLetters were discarded from 3 end:	"$right_cutoff""
echo -e "####\tbackground?:	$background"
echo -e "####\trapsearch_ecutoff:	$rapsearch_ecutoff"
echo -e "####\trapsearch_mode:	"$rapsearch_mode""
echo -e "####\tkmer_start:	"$kmer_start""
echo -e "####\tkmer_end:	"$kmer_end""
echo -e "####\tkmer_step:	"$kmer_step""
echo -e "####\trun_mode:	"$run_mode""
echo -e "####\thost_DB:	"$host_DB""
echo -e "####\tfast_nucl_DB:	"$fast_nucl_DB""
echo -e "####\tsense_nucl_DB:	"$sense_nucl_DB""
echo -e "####\tsense_prot_DB:	"$sense_prot_DB""
echo -e "####\tsense_bac_DB: "$sense_bac_DB""
echo -e "####\ttax_DB:	"$tax_DB""
echo -e "####\ttotal_cores:	"$total_cores""
echo -e "$(date)\t$0\tVerification Begins..."
PATH=$PATH:/usr/VIP/:/usr/VIP/bin/:/usr/VIP/bin/edirect/
#verify software dependencies
declare -a software_list=("seqtk" "prinseq-lite.pl" "bowtie2" "rapsearch" "velvetg" "velveth" "oases" "oases_pipeline.py" "mafft" "picard-tools" "distributionCalc.pl" "distributionPlot.py")
echo "#####################################################################################"
echo "#####################SOFTWARE DEPENDENCY VERIFICATION"
echo "#####################################################################################"
for command in "${software_list[@]}"
do
        if hash $command 2>/dev/null; then
                echo -e "$command: passed"
        else
                echo
                echo -e "$command: failed"
                echo -e "$command does not appear to be installed properly."
                echo -e "Please check VIP installation and \$PATH, then restart the pipeline"
                echo -e "SOFTWARE DEPENDENCY VERIFICATION failed"
	exit 65
        fi
done
echo "#####################################################################################"
echo "#####################SOFTWARE DEPENDENCY VERIFICATION PASSED"
echo "#####################################################################################"
#########
echo -e "$(date)\t$0\tVirus Identification Pipeline (VIP) begins"
BEGIN_VIP=$(date +%s)
mkdir $inputfile.report
curdir=`pwd`
# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

if [ "$preprocess" = "Y" ]
then
	echo -e "$(date)\t$0\tBegin to preprocess"
	if [ -f $inputfile.preprocessed ]
	then	
		echo -e "$inputfile.preprocessed has been existing. The preprocess has to be skip"
	else
		START_PREPROCESS=$(date +%s)
		preprocess.sh "$inputfile" "$inputtype" "$platform" "$length_cutoff" "$left_cutoff" "$right_cutoff" "$quality_cutoff"
		mv $inputfile.preprocessed.* $inputfile.preprocessed
		END_PREPROCESS=$(date +%s)
		DIFF_PREPROCESS=$(( $END_PREPROCESS - $START_PREPROCESS ))
		echo -e "$(date)\t$0\tPreprocess took $DIFF_PREPROCESS seconds"		
	fi
else
	echo -e "The preprocess has been skip."
	num_total_reads=`prinseq-lite.pl -stats_info -fasta $inputfile | grep "reads" | awk '{print$3}'`
	echo -e "Total_sequences\t$num_total_reads" > $inputfile.reads_distribution
	mv $inputfile $inputfile.preprocessed
	sleep 5
fi

# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
#####HUMAN MAPPING########
if [ -f "$inputfile.nohost.fastq" ]
then
	echo -e "$(date)\t$0\t$inputfile.nohost.fastq has been existing. The process for removing human-related reads has been skip."
	sleep 5
else
	if [ "$background" = "Y" ]
	then
		echo -e "$(date)\t$0\tBegin to filter reads related to human"
		echo -e "$(date)\t$0\tThe directory of the human database is "$host_DB""
		echo -e "$(date)\t$0\tBegin to alignmet against the human database"
		START_HUMAN=$(date +%s)
		if [ "$format" = "fasta" ]
		then
			echo -e "The command is\t###bowtie2 -x "$host_DB" -r $inputfile.preprocessed -S $inputfile.preprocessed.human.sam -f -p $total_cores###"
			bowtie2 -x "$host_DB" -r $inputfile.preprocessed -S $inputfile.preprocessed.human.sam -f -p $total_cores
		else
			echo -e "The command is\t###bowtie2 -x "$host_DB" -r $inputfile.preprocessed -S $inputfile.preprocessed.human.sam -q -p $total_cores###"
			bowtie2 -x "$host_DB" -r $inputfile.preprocessed -S $inputfile.preprocessed.human.sam -q -p $total_cores
		fi 
		egrep -v "^@" $inputfile.preprocessed.human.sam | awk '{if($3 == "*") print "@"$1"\n"$10"\n""+"$1"\n"$11}' > $inputfile.nohost.fastq
		Host_related_reads=`egrep -v "^@" $inputfile.preprocessed.human.sam | awk '{if($3 != "*") print$1}' | uniq | wc -l | awk '{print$1}'` 
		END_HUMAN=$(date +%s)
		DIFF_HUMAN=$(( $END_HUMAN - $START_HUMAN ))
		echo -e "Host_reads\t$Host_related_reads" >> $inputfile.reads_distribution	
		echo -e "$(date)\t$0\tHuman-related reads has been removed. This process took $DIFF_HUMAN seconds"
	else
		mv $inputfile.preprocessed $inputfile.nohost.fastq
		#echo "Host_reads: 0" >> $inputfile.reads_distribution			
		echo -e "The process for removing human-related reads has been skip."
		sleep 5
	fi
fi

# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

######MODE##############
if [ "$run_mode" = "fast" ]
then
	if [ -f "$inputfile.nohost.fast_nucl.sam" ]
	then	
		echo -e "$(date)\t$0\t$inputfile.nohost.fast_nucl.sam has been existing. The process for alignment to VIPR/IRD nucletide database has been skip."
		sleep 5
	else
		echo -e "$(date)\t$0\tThe mode is "$run_mode""
		echo -e "$(date)\t$0\tThe database are based from VIPR/IRD nucl and prot database"
		START_FAST_NUCL=$(date +%s)
		echo -e "$(date)\t$0\t####Bowtie to VIPR/IRD nucl database####"
		bowtie2 -x "$fast_nucl_DB" -r $inputfile.nohost.fastq -S $inputfile.nohost.fast_nucl.sam -q -p $total_cores --local
		END_FAST_NUCL=$(date +%s)
		DIFF_FAST_NUCL=$(( $END_FAST_NUCL - $START_FAST_NUCL ))
		echo -e "$(date)\t$0\t####Alignment $inputfile.nohost.fastq to VIPR/IRD nucl database DONE. The process took $DIFF_FAST_NUCL seconds####"
	fi
	Virus_related_reads=`egrep -v "^@" $inputfile.nohost.fast_nucl.sam | awk '{if($3 != "*") print$1}' | uniq | wc -l | awk '{print$1}'`
	echo -e "Viral_reads\t$Virus_related_reads" >> $inputfile.reads_distribution	
	#echo -e "Total_viral\t$Virus_related_reads" > temp.top5virus.$inputfile
	echo -e "$(date)\t$0\t####Extract match/unmatach records from $inputfile.nohost.fast_nucl.sam####"
	egrep -v "^@" $inputfile.nohost.fast_nucl.sam | awk '{if($3 != "*") print }' > $inputfile.nohost.fast_nucl.match.sam	#分类学
	#echo -e "$(date)\t$0\t####Extract match/unmatach records from $inputfile.nohost.fast_nucl.sam DONE####"
elif [ "$run_mode" = "sense" ]
then
	####remove bac-related reads	
	if [ -f "$inputfile.nohost.nobac.fastq" ] 
	then
		echo -e "$(date)\t$0\t$inputfile.nohost.nobac.sam has been existing. The process for alignment to Bac_NT (NCBI) database has been skip."
		sleep 5 
	else
		echo -e "$(date)\t$0\tProcess for removing Bacteria reads begin"
		echo -e "$(date)\t$0\tThe database for bacteria is $sense_bac_DB"
		bowtie2 -x $sense_bac_DB -r $inputfile.nohost.fastq -S $inputfile.nohost.bac.sam -q -p $total_cores
		echo -e "$(date)\t$0\tAlignment to bacteria database has been finished"
		echo -e "$(date)\t$0\tExtract reads"
		egrep -v "^@" $inputfile.nohost.bac.sam | awk '{if($3 == "*") print "@"$1"\n"$10"\n""+"$1"\n"$11}' > $inputfile.nohost.nobac.fastq
 #reads ,fastq format, no host, no bac
		Bac_related_reads=`egrep -v "^@" $inputfile.nohost.bac.sam | awk '{if($3 != "*") print$1}' | uniq | wc -l | awk '{print$1}'`
		echo -e "Bac_reads\t$Bac_related_reads" >> $inputfile.reads_distribution
	fi
	if [ -f "$inputfile.nohost.nobac.sense_nucl.sam" ]
	then
		echo -e "$(date)\t$0\t$inputfile.nohost.nobac.sense_nucl.sam has been existing. The process for alignment to Virus_NT (NCBI) database has been skip."
		sleep 5
	else
		echo -e "$(date)\t$0\tThe mode is $run_mode"
		echo -e "$(date)\t$0\tThe database are based from Virus_NT(NCBI) database"
		START_SENSE_NUCL=$(date +%s)
		echo -e "$(date)\t$0\t####Bowtie to Virus_NT(NCBI) database####"
		bowtie2 -x $sense_nucl_DB -r $inputfile.nohost.nobac.fastq -S $inputfile.nohost.nobac.sense_nucl.sam -q -p $total_cores --local
		END_SENSE_NUCL=$(date +%s)
		DIFF_SENSE_NUCL=$(( $END_SENSE_NUCL - $START_SENSE_NUCL ))
		echo -e "$(date)\t$0\t####Alignment $inputfile.nohost.nobac.fastq to Virus_NT (NCBI) database DONE. The process took $DIFF_SENSE_NUCL seconds####"
		Virus_related_nucl_reads=`egrep -v "^@" $inputfile.nohost.nobac.sense_nucl.sam | awk '{if($3 != "*") print$1}' | uniq | wc -l | awk '{print$1}'`

	fi
	echo -e "$(date)\t$0\t####Extract match/unmatach records from $inputfile.nohost.nobac.sense_nucl.sam####"
	egrep -v "^@" $inputfile.nohost.nobac.sense_nucl.sam | awk '{if($3 != "*") print }' > $inputfile.nohost.nobac.sense_nucl.match.sam
	egrep -v "^@" $inputfile.nohost.nobac.sense_nucl.sam | awk '{if($3 == "*") print ">"$1"\n"$10}' > $inputfile.nohost.nobac.sense_nucl.unmatch.fa
	#egrep -v "^@" $inputfile.nohost.nobac.sense_nucl.sam > $inputfile.nohost.nobac.allreads.sam	#组装+蛋白比对
	echo -e "$(date)\t$0\t####Extract match/unmatach records from $inputfile.nohost.nobac.sense_nucl.sam DONE####"
	echo -e "$(date)\t$0\t####Alignment $inputfile.nohost.nobac.sense_nucl.unmatch.fa to Virus_NR (NCBI) prot datebase####"
	if [ -f "$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8" ]
	then
		echo -e "$(date)\t$0\t$inputfile.nohost.nobac.unmatch.contigs.sense.prot.m8 has been existing. The process for alignment to Virus_NR (NCBI) protein database has been skip."
		sleep 5
	else
		#echo -e 
		START_SENSE_PROT=$(date +%s)
		#awk '{print ">"$1"\n"$10}' $inputfile.nohost.sense_nucl.unmatch.sam > $inputfile.nohost.sense_nucl.unmatch.fasta
		echo -e "$(date)\t$0\trapsearch -q "$inputfile.nohost.nobac.sense_nucl.unmatch.fa" -d "$sense_prot_DB" -o $inputfile.nohost.nobac.unmatch.contigs.sense.prot -z "$total_cores" -e "$rapsearch_ecutoff" -g "$rapsearch_mode" -v 1 -b 1 -t N"	
		rapsearch -q "$inputfile.nohost.nobac.sense_nucl.unmatch.fa" -d "$sense_prot_DB" -o $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot -z "$total_cores" -e "$rapsearch_ecutoff" -g "$rapsearch_mode" -v 1 -b 1 -t N
		END_SENSE_PROT=$(date +%s)
		DIFF_SENSE_PROT=$(( $END_SENSE_PROT - $START_SENSE_PROT ))
		echo -e "$(date)\t$0\t####Alignment $inputfile.nohost.sense_nucl.unmatch.sam to Virus_NT (NCBI) prot database DONE. The process took $DIFF_SENSE_PROT seconds####"
		Virus_related_prot_reads=`egrep -v "^#" $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8 | awk '{print$1}' | uniq | wc -l | awk '{print$1}'`
		Virus_sense_reads=$(($Virus_related_prot_reads+$Virus_related_nucl_reads))
		echo -e "Viral_reads\t$Virus_sense_reads" >> $inputfile.reads_distribution
		#echo -e "Total_viral\t$Virus_sense_reads" > temp.top5virus.$inputfile	
		#cp temp.top5virus.$inputfile $curdir/$inputfile.report/
	fi
fi


# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

######Taxonmoy classfication##############

if [ -f "$inputfile.nohost.fast_nucl.match.sam" ] 
then
	echo -e "$(date)\t$0\t####Restore the full length of reads being soft-cut during local alignment####"
	get_fulllength.sh $inputfile.nohost.fastq $inputfile.nohost.fast_nucl.match.sam sam
elif [ -f "$inputfile.nohost.nobac.sense_nucl.match.sam" ] && [ -f "$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8" ]
then
	echo -e "$(date)\t$0\t####Add the seq information to the prot alignment result:$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8"
	#cat $inputfile.nohost.nobac.fastq $inputfile.nohost.nobac.allreads.sam.addseq.contigs.fastq > $inputfile.nohost.nobac.contigs.fastq
	get_fulllength.sh $inputfile.nohost.nobac.fastq $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8 blast
	echo -e "$(date)\t$0\t####Restore the full length of reads being soft-cut during local alignment####"
	get_fulllength.sh $inputfile.nohost.nobac.fastq $inputfile.nohost.nobac.sense_nucl.match.sam sam
fi

# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

if [ -f "$inputfile.nohost.fast_nucl.match.sam.addseq" ] 
then
	echo "$(date)\t$0\t####Taxnomoy Identification module for FAST mode result begins####"
	START_FAST_TAXI=$(date +%s)
	echo "$(date)\t$0\t####sh TaxI.sh $inputfile.nohost.fast_nucl.match.sam sam nucl $total_cores "$tax_DB"####"
	TaxI.sh "$inputfile.nohost.fast_nucl.match.sam.addseq" sam nucl $total_cores "$tax_DB"
	#echo "$(date)\t$0\t####sh TaxI.sh $inputfile.nohost.fast_nucl.unmatch.RAPSearch.prot.m8 blast prot $total_cores "$tax_DB"####"
	#sh TaxI.sh $inputfile.nohost.fast_nucl.unmatch.RAPSearch.prot.m8.addseq blast prot $total_cores "$tax_DB"
	END_FAST_TAXI=$(date +%s)
	DIFF_FAST_TAXI=$(( $END_FAST_TAXI - $START_FAST_TAXI))
	echo -e "$(date)\t$0\t####Parsing fast mode result with TAXI DONE. The process took $DIFF_FAST_TAXI seconds####"
elif [ -f "$inputfile.nohost.nobac.sense_nucl.match.sam.addseq" ] && [ -f "$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq" ]
then
	echo "$(date)\t$0\t####Taxnomoy Identification module for SENSE mode result begins####"
	START_TAXI=$(date +%s)
	echo "$(date)\t$0\t####sh TaxI.sh $inputfile.nohost.fast_nucl.match.sam sam nucl $total_cores "$tax_DB"####"
	TaxI.sh "$inputfile.nohost.nobac.sense_nucl.match.sam.addseq" sam nucl $total_cores "$tax_DB"
	echo "$(date)\t$0\t####sh TaxI.sh $inputfile.nohost.fast_nucl.unmatch.RAPSearch.prot.m8 blast prot $total_cores "$tax_DB"####"
	TaxI.sh "$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq" blast prot $total_cores "$tax_DB"
	END_TAXI=$(date +%s)
	DIFF_TAXI=$(( $END_TAXI - $START_TAXI))
	echo -e "$(date)\t$0\t####Parsing Sense mode result with TAXI DONE. The process took $DIFF_TAXI seconds####"
elif [ "$run_mode" = "sense" ]
then
	echo -e "$(date)\t$0\tFile missing: $inputfile.nohost.nobac.sense_nucl.match.sam.addseq, $inputfile.nohost.nobac.unmatch.contigs.sense.prot.m8.addseq"
elif [ "$run_mode" = "fast" ]
then
	echo -e "$(date)\t$0\tFile missing: $inputfile.nohost.fast_nucl.match.sam.addseq"
fi

# echo -e "$(date)\t$0\tFree pagecache"
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

##phygo and covplot##

if [ -f "$inputfile.nohost.fast_nucl.match.sam.addseq.all.annotated" ] 
then
	covplot.sh $inputfile.nohost.fast_nucl.match.sam.addseq.all.annotated $inputfile.nohost.fast_nucl.unmatch.RAPSearch.prot.m8.addseq.all.annotated $inputfile fast $platform $kmer_start $kmer_end $kmer_step
	##获得各个genus所对应的文件。根据coverage，输出前10,下一句的10以后可以替换
	#sort -r -k2,2 -n coverage | head -n 20 | awk '{print$1}' > temp.best20.$inputfile
	#sort -r -k2,2 -n $inputfile.coverage | awk '{if($2>20)print$1}' > temp.best20.$inputfile
	#sort -r -k2,2 -n coverage | awk '{if($2>20)print$1"\t"$2}' > ./$inputfile.coverage_report/best20.$inputfile	
	while read coverage_genus
	do
		cd temp.$coverage_genus.$inputfile
		#cp *.png $curdir/$inputfile.coverage_report/
		cp *.png $curdir/$inputfile.report/
		#cd $curdir/$inputfile.coverage_report/
		#mv temp.$coverage_genus.$inputfile.blastn.png $inputfile.$coverage_genus.png
		cd $curdir
	done < temp.all.$inputfile.uniq.genus
	sort -t $'\t' -r -k4,4 -n ./$inputfile.report/temp.$inputfile.covreport > ./$inputfile.report/temp.best20.$inputfile.temp
	echo -e "Species\tGenus\tGI\t%Coverage\tReads_hit\tReads_num\tAverage depth of coverage" > ./$inputfile.report/temp.best20.$inputfile.title
	cat ./$inputfile.report/temp.best20.$inputfile.title ./$inputfile.report/temp.best20.$inputfile.temp > ./$inputfile.report/taxi.$inputfile.table
	cd $curdir/$inputfile.report/
	##
	#modified version 0.4

	END_VIP=$(date +%s)
	DIFF_VIP=$(($END_VIP-$BEGIN_VIP))
	echo -e "$(date)\t$0\tVIP took $DIFF_VIP seconds"
	###reads_distribution	update for 0.0.3
	cd $curdir/
	distributionCalc.pl $inputfile.reads_distribution $inputfile reads
	distributionPlot.py $inputfile.reads_distribution $inputfile reads
	###reads_distribution.$inputfile.png
	cp reads_distribution.$inputfile.png $curdir/$inputfile.report/
	###virus distribution	
	cd $curdir/$inputfile.report/
	#cp $curdir/temp.top5virus.$inputfile $curdir/$inputfile.report/
	awk -F'\t' '{print$2"\t"$4"\t"$6}' taxi.$inputfile.table | head -n  6 > temp.top5virus.$inputfile
	#distributionCalc.pl temp.top5virus.$inputfile $inputfile virus
	##bar chart (modified when version 0.4)	
	
	distributionPlot.py temp.top5virus.$inputfile $inputfile virus
	echo -e "htmlGen.pl taxi.$inputfile.table $inputfile $run_mode $DIFF_VIP $VIP_TT_DIR"
	htmlGen.pl taxi.$inputfile.table $inputfile $run_mode $DIFF_VIP $VIP_TT_DIR
elif [ -f "$inputfile.nohost.nobac.sense_nucl.match.sam.addseq.all.annotated" ] && [ -f "$inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq.all.annotated" ]
then
##updated part for 0.0.2
#add a condition for viruses analysis
	grep "Viruses" $inputfile.nohost.nobac.sense_nucl.match.sam.addseq.all.annotated > $inputfile.nohost.nobac.sense_nucl.match.sam.addseq.VIRUSES.all.annotated
	grep "Viruses" $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq.all.annotated > $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq.VIRUSES.all.annotated
	covplot.sh $inputfile.nohost.nobac.sense_nucl.match.sam.addseq.VIRUSES.all.annotated $inputfile.nohost.nobac.sense_nucl.unmatch.fa.prot.m8.addseq.VIRUSES.all.annotated $inputfile sense $platform $kmer_start $kmer_end $kmer_step
	while read coverage_genus
	do
		cd temp.$coverage_genus.$inputfile
		cp *.png $curdir/$inputfile.report/
		cd $curdir
	done < temp.all.$inputfile.uniq.genus
	sort -t $'\t' -r -k4,4 -n ./$inputfile.report/temp.$inputfile.covreport > ./$inputfile.report/temp.best20.$inputfile.temp
	echo -e "Species\tGenus\tGI\t%Coverage\tReads_hit\tReads_num\tAverage depth of coverage" > ./$inputfile.report/temp.best20.$inputfile.title
	cat ./$inputfile.report/temp.best20.$inputfile.title ./$inputfile.report/temp.best20.$inputfile.temp > ./$inputfile.report/taxi.$inputfile.table
	cd $curdir/$inputfile.report/
	END_VIP=$(date +%s)
	DIFF_VIP=$(($END_VIP-$BEGIN_VIP))
	echo -e "$(date)\t$0\tPreprocess took $DIFF_VIP seconds"
	###reads_distribution	
	cd $curdir/
	distributionCalc.pl $inputfile.reads_distribution $inputfile reads
	distributionPlot.py $inputfile.reads_distribution $inputfile reads
	cp reads_distribution.$inputfile.png $curdir/$inputfile.report/
	###virus distribution	
	cd $curdir/$inputfile.report/
	cp $curdir/temp.top5virus.$inputfile $curdir/$inputfile.report/
	awk -F'\t' '{print$2"\t"$4"\t"$6}' taxi.$inputfile.table | head -n  6 > temp.top5virus.$inputfile
	#distributionCalc.pl temp.top5virus.$inputfile $inputfile virus
	##bar chart (modified when version 0.4)	
	distributionPlot.py temp.top5virus.$inputfile $inputfile virus
	echo -e "htmlGen.pl taxi.$inputfile.table $inputfile $run_mode $DIFF_VIP $VIP_TT_DIR"
	htmlGen.pl taxi.$inputfile.table $inputfile $run_mode $DIFF_VIP $VIP_TT_DIR
fi





#END_VIP=$(date +%s)
#DIFF_VIP=$(($END_VIP-$BEGIN_VIP))
#echo -e "$(date)\t$0\tPreprocess took $DIFF_VIP seconds"
echo -e "Please check the VIP_report.html under the path: $curdir\\$inputfile.report"


