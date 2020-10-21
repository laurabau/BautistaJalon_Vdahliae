#!/bin/bash
set -ueo pipefail
#
#---------  go to dir and work aliases -------------------------------------------------------------
echo "go to dir work vd"
cd /gpfs/home/ldb185/scratch/vd/PA_Israel_chrom/
WORKDIR=/gpfs/home/ldb185/scratch/vd/PA_Israel_chrom/
VCFNAME=paisrael_fbyes
#
#
#---------  ref genome and alias -------------------------------------------------------
echo "alias -- ref genome, index ---"
REF=/gpfs/home/ldb185/scratch/vd/ref/VdLs.17genome_chromosomal.fasta
samtools faidx $REF
bwa index $REF
#
# ----------- gunzip the files --------------------------------------------------------------
echo "gunzip fastq.gz files"
for i in /gpfs/home/ldb185/scratch/vd/plate1/*.fq.gz;
do
	gunzip ${i}
done
#
#
########------------------------- trimming -----------------------------------------------
echo "trimming low quality"
for i in $(ls /gpfs/home/ldb185/scratch/vd/plate1/*.fq | rev | cut -c 6- | rev | uniq); do  
	java -jar /gpfs/home/ldb185/scratch/vd/Trimmomatic-0.36/trimmomatic-0.36.jar PE ${i}_1.fq ${i}_2.fq > ${i}_trimmed
done
#
#	
#----------------- Alignment quick start:  ----------------------------------------
# For paired-end reads:
echo "mkdir sambam"
mkdir $WORKDIR/sambam/
echo
echo "bwa alignment and copying sam files to sambam folder"
echo
for file in $(ls $WORKDIR/*.fq | rev | cut -c 6- | rev | uniq); do
		bwa mem -M -R "@RG\tID:$file\tLB:$file\tPL:Illumina\tPM:nextseq\tSM:$file" $REF ${file}_1.fq ${file}_2.fq > ${file}.sam  
done
#
#
#---------sam to sorted bam --------------------------------------------------------------
echo 
echo "converting to bam and sorting"
echo
for i in $(ls $WORKDIR/*.sam | rev | cut -c 5- | rev | uniq); do
	samtools view -Shu ${i}.sam | sambamba sort /dev/stdin -o ${i}_sorted.bam
done 
echo "mark duplicates"
for i in $(ls $WORKDIR/*_sorted.bam | rev | cut -c 12- | rev | uniq); do
	sambamba markdup ${i}_sorted.bam ${i}_sorted_dup.bam
done
#
#
#-------------- Joint calling -----------------
echo 
echo "----- calling variants using freebayes -----"
echo
echo
# you need to have .bam files and .bai (index files) in the same folder when calling Variants.
freebayes -f $REF $WORKDIR/*_sorted_dup.bam > ${VCFNAME}.vcf 
echo
vcffilter -f "TYPE = snp & DP > 5 & MQ > 30" ${VCFNAME}.vcf > ${VCFNAME}_filter.vcf 
# 
echo 
echo " bgzip and tabix"
echo
bgzip ${VCFNAME}.vcf
tabix -h -p vcf ${VCFNAME}.vcf.gz
# 
echo "-------- done ----"
#


