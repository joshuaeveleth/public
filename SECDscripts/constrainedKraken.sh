#! /bin/sh

# Paired script to run with multiple pairs of fastq files in one directory is "email-secdKraken.sh {argument}"

# Runs in a folder with only two fastq files
# Runs Kraken, Krona, organizes taxIDs and generates folders for further analysis. Runs Abyss, BLAST, BWA on those files and generates reports
# Results are in ${name}-resultsSummary.txt

# Required scripts:
	#krakenProcessing.py
	#fetch-genomes-fasta.py
	#coveragebyr.r

NR_CPUS=60 # Computer cores to use when analyzing
#unzip files if needed
find . -name "*gz" -type f -print0 | xargs -0 -n 1 -P $NR_CPUS gunzip

#sample name is the name of the fastq files minus any identifying information from the sequencer
sampleName=`ls *_R1* | sed 's/_.*//' | sed 's/\..*//'`

#make a folder to put important files in that will be uploaded back to submitter
mkdir ${sampleName}_upload
uploadFolder=${sampleName}_upload

###########################################
#Environment Controls:  Set these to tailor script towards analyzing certain groups of organisms

if [[ $1 == all ]]; then   #All viruses
    organism="all"
    #Standard database
    krakenDatabase="/home/shared/databases/kraken/std/"
    #Names of organisms interested in doing further analysis on- derived from Kraken report.
    searchTerms="/home/shared/databases/kraken/searchTerms/allSearchTerms"
    #Names of organisms to exclude from analysis- derived from Kraken report
    notSearchTerms="/home/shared/databases/kraken/searchTerms/allNOTSearchTerms"
    #How many Genbank entries to align to per organism folder
    numAlignmentsPerFolder='1'

elif [[ $1 == secd ]]; then  #4 porcine coronaviruses
    # set controls here
    organism="secd"
    krakenDatabase="/home/shared/databases/kraken/stdPlusSECD" 
    searchTerms="/home/shared/databases/kraken/searchTerms/secdSearchTerms"
    notSearchTerms="/home/shared/databases/kraken/searchTerms/secdNOTSearchTerms"
    numAlignmentsPerFolder='1'

# Add more arguments here with another elif statement

else
    echo ""
    echo "Incorrect argument! Must use one of the following arguments: all, secd"
    echo "For example, type ~$ masterKraken.sh all"
    echo ""
    exit 1
fi

#########################################

echo "Kraken database selected is: $krakenDatabase"
echo "Organism chosen is: $organism"
echo "Search terms are: `cat $searchTerms`"

# Run Kraken
kraken --db ${krakenDatabase} --threads ${NR_CPUS} --paired *fastq* > $sampleName-output.txt && kraken-report --db ${krakenDatabase} $sampleName-output.txt > $sampleName-kraken_report.txt

# Run Krona
cut -f2,3 $sampleName-output.txt > $sampleName-kronaInput.txt; 
/usr/local/bin/ktImportTaxonomy $sampleName-kronaInput.txt; 
mv taxonomy.krona.html $sampleName-KronaGraphic.html; 
mv taxonomy.krona.html.files $sampleName-taxonomy.krona.html.files
mv ${sampleName}-KronaGraphic.html $uploadFolder

# Set variables and paths
output=`ls *-output.txt`
report=`ls *kraken_report.txt`
cp $report $uploadFolder

#Directory where script is called
root=`pwd`

#Variable for files containing reads
forReads=`echo *_R1*`
revReads=`echo *_R2*`
#Beginning of resultsSumary.txt report
summaryFile=$root/${sampleName}-resultsSummary.txt
#Calculate files sizes
forFileSize=`ls -lh $forReads | awk '{print $5}'`
revFileSize=`ls -lh $revReads | awk '{print $5}'`
#Calculate count of reads in each file
forCount=`grep -c "^+$" $forReads`
revCount=`grep -c "^+$" $revReads`

echo "#################### Sample: $sampleName ####################" >> $summaryFile
echo "" >> $summaryFile
printf "%s, %s file size, %'.0f reads\n" ${forReads} ${forFileSize} ${forCount} >> $summaryFile
printf "%s, %s file size, %'.0f reads\n" ${revReads} ${revFileSize} ${revCount} >> $summaryFile
echo "" >> $summaryFile
declare -i x=${forCount}
declare -i y=${revCount}
echo "" | awk -v x=$x -v y=$y '{printf "Total single end read count: %'\''d\n", x+y}' >> $summaryFile
echo "" >> $summaryFile

#Section of results summary that calculates number of reads per type of organism (ex: ssRNA virus)
echo "Summary of Findings (paired end reads)" >> $summaryFile
cRead=`grep -c "^C" $output`
uRead=`grep -c "^U" $output`
virusreport=`awk ' $5 == "10239" {print $2}' $report`
posssRNA=`awk ' $5 == "35278" {print $2}' $report`
negssRNA=`awk ' $5 == "35301" {print $2}' $report`
dsRNA=`awk ' $5 == "35325" {print $2}' $report`
ssDNA=`awk ' $5 == "29258" {print $2}' $report`
dsDNA=`awk ' $5 == "35237" {print $2}' $report`
let allReads=cRead+uRead
if [ -z $virusreport ]; then
	virusreport="zero"
fi
if [ -z $posssRNA ]; then
	posssRNA="zero"
fi
if [ -z $negssRNA ]; then
	negssRNA="zero"
fi
if [ -z $dsRNA ]; then
	dsRNA="zero"
fi
if [ -z $ssDNA ]; then
	ssDNA="zero"
fi
if [ -z $dsDNA ]; then
	dsDNA="zero"
fi
declare -i x=${cRead}
declare -i y=${uRead}
declare -i v=${virusreport}
declare -i pr=${posssRNA}
declare -i nr=${negssRNA}
declare -i dr=${dsRNA}
declare -i sd=${ssDNA}
declare -i dd=${dsDNA}
declare -i z=${allReads}

pvRead=`awk -v v=$v -v z=$z 'BEGIN { print (v / z)*100 }'`
pcRead=`awk -v x=$x -v z=$z 'BEGIN { print (x / z)*100 }'`
puRead=`awk -v x=$y -v z=$z 'BEGIN { print (x / z)*100 }'`
prRead=`awk -v x=$pr -v z=$z 'BEGIN { print (x / z)*100 }'`
nrRead=`awk -v x=$nr -v z=$z 'BEGIN { print (x / z)*100 }'`
drRead=`awk -v x=$dr -v z=$z 'BEGIN { print (x / z)*100 }'`
sdRead=`awk -v x=$sd -v z=$z 'BEGIN { print (x / z)*100 }'`
ddRead=`awk -v x=$dd -v z=$z 'BEGIN { print (x / z)*100 }'`

echo "`printf "%'.0f\n" ${cRead}` porcine, bacteria, and virus classified reads --> ${pcRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${virusreport}` virus reads --> ${pvRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${posssRNA}` positive ssRNA virus reads --> ${prRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${negssRNA}` negative ssRNA virus reads --> ${nrRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${dsRNA}` dsRNA virus reads --> ${drRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${ssDNA}` ssDNA virus reads --> ${sdRead}%" >> $summaryFile
echo "`printf "%'.0f\n" ${dsDNA}` dsDNA virus reads --> ${ddRead}%" >> $summaryFile
echo "" >> $summaryFile
echo "See attached HTML report for a representation of classified reads" >> $summaryFile
echo "" >> $summaryFile

# Run krakenProcessing.py to get hierarchical taxonID lists 
krakenProcessing.py $report $organism
echo "krakenProcessing is done"

# Output of krakenProcessing.py is a series of folders, representing the increasing specificity of kraken classifications
# Example: column5= Viruses, cellular organisms, etc.
#          column10= Virus strain a

cd $root/hierarchicalClustering
hc=`pwd`
mkdir $root/toInvestigateFurther
cd $root/toInvestigateFurther
TIF=`pwd`
cd $hc

# for each column folder, look in folder, and see if any file names match any terms in appropriate searchTerms file
# if file name matches search term, move to "toInvestigateFurther" directory
echo "Begin to look inside  hierarchical folders"
for i in *; do
    cd $hc
    cd ./$i
    for j in `cat $searchTerms`; do
        fileToMove=`ls * | grep $j`
        cat ./$fileToMove >> $hc/uniqueTaxIDs
        cp ./$fileToMove $TIF
    done
done

cd $TIF
#find directories that match something in notSearchTerms
for j in `cat $notSearchTerms`; do
    ls * | grep $j >> $root/directoriesToRemove.txt
done

#Remove directories flagged
for i in `cat $root/directoriesToRemove.txt`; do
    rm -rf $TIF/$i
done

echo "Completed gathering taxIDs"

#take only uniqueTaxIDs
cat $hc/uniqueTaxIDs | sort | uniq > $hc/finalUniqueTaxIDs.txt

#Prepare isolated reads folder
mkdir $root/isolatedReads
cd $root/isolatedReads
isolatedReads=`pwd`
mv $hc/finalUniqueTaxIDs.txt $isolatedReads

cd $isolatedReads
#move kraken output file to isolatedReads directory
mv $root/$output $isolatedReads
outputFilePath='pwd'/$output

echo "Starting isolated reads script"

cd $isolatedReads
# Run subset of Tod's script to bin by each taxonID in list of unique taxIDs of interest 
for id in `cat $isolatedReads/finalUniqueTaxIDs.txt`; do 
	date
	echo "*** Getting reads for taxon id: $id"
	cd $isolatedReads
	idname=${id}
	mkdir ${idname}
	echo "idname is: $idname"
	awk -v id=$id ' $3 == id {print $2}' $output >> ./${idname}/${idname}.reads
	readsfound=`grep -c ".*" ./${idname}/${idname}.reads`
	echo "Number of reads to be found: $readsfound"
	cd ${idname}
        grep -F -A3 -h -f ./${idname}.reads ../../*.fastq >> ${sampleName}.${idname}.fastq
	egrep -A3 "1:N:" ${sampleName}.${idname}.fastq | grep -v '^--$' > ${sampleName}.${idname}_R1.fastq
	egrep -A3 "2:N:" ${sampleName}.${idname}.fastq | grep -v '^--$' > ${sampleName}.${idname}_R2.fastq
	rm ${sampleName}.${idname}.fastq
done
cd $root

cd $TIF
#Make folder for each list of taxonIDs and have folder name be the name of the organism 
for k in *; do
    folderName=$(ls $k | sed 's/.\{12\}$//')
    mkdir $folderName
    mv $k $folderName
done

#Change Deltacoronavirus to DeltaHKU15 if secd
if [ $organism=='secd' ]; then
   mv _Deltacoronavirus _Deltacoronavirus-HKU15
   mv _Deltacoronavirus-HKU15/_DeltacoronavirusListOfTaxIDs _Deltacoronavirus-HKU15/_Deltacoronavirus-HKU15ListOfTaxIDs
fi

#Remove leading underscore in folder name
cd $TIF
for f in *; do
    g=`echo $f | sed 's/^_//'`
    mv $f $g
    mv $g/${f}ListOfTaxIDs $g/${g}ListOfTaxIDs
done

# Make new fastq files by matching the single taxonID fastqs with the list of taxonIDs that are grouped in a hierarchy
for folder in *; do
    cd $TIF
    cd ./$folder
    touch ${folder}_R1.fastq
    touch ${folder}_R2.fastq
    #n is taxID
    file="${folder}ListOfTaxIDs"
	#echo "At $LINENO this is output from file variable"
	echo "$file"
   	echo "Getting reads..." 
	for n in `cat ./$file`; do        
		cd $isolatedReads
        	cd ./$n
        	cat *_R1.fastq >> $TIF/$folder/${folder}_R1.fastq
        	cat *_R2.fastq >> $TIF/$folder/${folder}_R2.fastq
    		#grep "^@[AM][0-9]" *_R1.fastq >> $TIF/$folder/${folder}_header1.txt
		#grep "^@[AM][0-9]" *_R2.fastq >> $TIF/$folder/${folder}_header2.txt

	done
	#cat $TIF/$folder/${folder}_header1.txt $TIF/$folder/${folder}_header2.txt > $TIF/$folder/${folder}_allheaders.txt
	#sort < $TIF/$folder/${folder}_allheaders.txt | uniq > $TIF/$folder/${folder}_uniqheaders.txt
	#grep -F -A3 -h -f $TIF/$folder/${folder}_uniqheaders.txt ${root}/${forReads} | grep -v '^--$' > $TIF/$folder/${folder}_R1.fastq
	#grep -F -A3 -h -f $TIF/$folder/${folder}_uniqheaders.txt ${root}/${revReads} | grep -v '^--$' > $TIF/$folder/${folder}_R2.fastq
done

cd $root

echo "Starting Assembly/Alignment portion of script"
#Assemble and BLAST subset fastq files to determine best references to align full fastqs with
#Start assembly/BLAST result file
virusSummary=$root/secdsummary.txt
if [ $organism == 'secd' ]; then
    echo "SECD Virus Findings" >> $virusSummary
elif [ $organism == 'all' ]; then
    echo "Virus Findings" >> $virusSummary
fi

cd $TIF
picardPath='/usr/local/bin/picard-tools-1.117/'
GATKPath='/usr/local/bin/GenomeAnalysisTK/GenomeAnalysisTK.jar'
# For each toInvestigateFurther directory"
for f in *; do
    cd $TIF
    cd ./$f
    echo "--> $f" >> $virusSummary
    readsFound=`cat *.fastq | grep -c "^+$"`
    echo "Reads found: `printf "%'.0f\n" ${readsFound}`" >> $virusSummary
    #Run Abyss
    abyss_run.sh
    cd *_abyss
    
    #Output assembly stats.
    if [ -e ./*stats.tab ]; then
	numContigs=`cat *-8.fa | grep -c ">"`
 	echo "Number of contigs assembled is: $numContigs" >> $virusSummary
        cat ./*stats.tab >> $virusSummary
    else
	echo "Unable to scaffold contigs" >> $virusSummary
    fi

    #BLAST contigs if abyss worked
    if [ -s ./*-8.fa ]; then
	blast-contigs.sh ./*-8.fa
	mv *-8.fa ${f}-contigs-8.fa
	cp ${f}-contigs-8.fa $root/$uploadFolder
        # if no 8.fa file, blast the 3.fa file
    elif [ -s ./*-3.fa ]; then
	numContigs=`cat *-3.fa | grep -c ">"`
	echo "Number of contigs assembled is: $numContigs" >> $virusSummary
	blast-contigs.sh ./*-3.fa
	mv *-3.fa ${f}-contigs-3.fa
	cp ${f}-contigs-3.fa $root/$uploadFolder
    else
 	echo "Unable to assemble contigs"
	echo "No BLAST results to report" >> $virusSummary
	echo "" >> $virusSummary
    fi

    # paste results in report
    if [ -s BLAST-summary* ]; then       
        echo "" >> $virusSummary
	echo "BLAST results of assembled contigs: " >> $virusSummary
	#echo "" >> $virusSummary
	if [ $organism == 'secd' ]; then
            cat BLAST-summary* >> $virusSummary
        elif [ $organism == 'all' ]; then
    	    cat BLAST-summary* | head >> $virusSummary
	else
	    echo "no blast results to report"
	fi
	echo "" >> $virusSummary
	topResult=`sed '1d' BLAST-summary* | head | grep "genome" | awk '{print $2}' | head -1` #column 2 is accession number
	#echo "Top Result is $topResult"
	#species=`sed '1d' BLAST-summary* | grep "genome" | awk '{print $7}' | head -1` #column 7 is second name of species
	desc=`sed '1d' BLAST-summary* | head | grep "genome" | awk '{print $2, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16}' | head -1`
	#If there is a top result
	if [[ -z $topResult ]]; then
	    #check if top result is related to the folder name $f 
	    #match=`echo $f | grep $species`
	    #If they do not match, search "virus" and change topResult and desc
	    #if [[ -z $match ]]; then
	    sed '1d' BLAST-summary* | head | grep "virus" | awk '{print $2}' | head -3 >> $root/genomesToDownload.txt
	    sed '1d' BLAST-summary* | head | grep "virus" | awk '{print $2, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16}' | head -3 >> $root/genomesKey.txt
	elif [[ ! -z $topResult ]]; then
	    echo $topResult >> $root/genomesToDownload.txt
	    echo $desc >> $root/genomesKey.txt
	else
	    echo "No accessions chosen for alignment" >> $virusSummary
	fi
            #sed '1d' BLAST-summary* | grep "genome" | awk '{print $2}' | head -$numAlignmentsPerFolder >> $root/genomesToDownload.txt
	#There is no "genome" top result, search for "virus" instead and take top result
        #elif [[ -z $topResult ]]; then
	 #   topResult=`sed '1d' BLAST-summary* | grep "virus" | awk '{print $2}' | head -1` 
	 #   desc=`sed '1d' BLAST-summary* | grep "virus" | awk '{print $2, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16}' | head -1`
	#fi
	#echo $topResult >> $root/genomesToDownload.txt
        #echo $desc >> $root/genomesKey.txt
    fi
done

#Finalize genomes to download (remove duplicate entries
cd $root
echo "$(cat $root/genomesKey.txt | sort | uniq)" >> finalGenomesKey.txt
echo "$(cat $root/genomesToDownload.txt | sort | uniq)" >> finalGenomesToDownload.txt
#read -p "$LINENO Enter"
rm $root/genomesToDownload.txt
rm $root/genomesKey.txt

mydb="/usr/local/bin/ncbi-blast-2.2.29+" 
#If finalGenomesToDownload is not empty, download genomes and begin aligning total reads to them
if [ -s $root/finalGenomesToDownload.txt ]; then    
    echo "***********************"
    echo "Downloading genomes"
    mkdir alignments
    cd alignments
    alignments=`pwd`
    for h in `cat $root/finalGenomesToDownload.txt`; do
        #genomeName=`echo $h | sed 's/\..*//'`
	cd $alignments
	acc=$h
	mkdir $acc
	cd $acc
	ls ${mydb} > $root/list.txt
	p=`grep "${acc}" $root/list.txt`
	if [[ ! -z "$p" ]]; then
	    echo "Genome previously downloaded. Copying now"
	    cp ${mydb}/$p .
	else
	    echo "Downloading from NCBI"
	    fetch-genomes-fasta.py $acc
	    accFasta="${acc}.fasta"
	    if [ -s $accFasta ]; then
		echo "Downloaded from NCBI, good to continue."
		cp $accFasta $mydb
	    else
		echo "Try downloading again"
		sleep 20
		fetch-genomes-fasta.py $acc
		sleep 5
		if [ -s $accFasta ]; then
		    echo "Downloaded from NCBI, good to continue."
		    cp $accFasta $mydb
		else
		    echo "Try downloading again"
		    sleep 120
		    fetch-genomes-fasta.py $acc
		    sleep 5
		    if [ -s $accFasta ]; then
			echo "Downloaded from NCBI, good to continue."
			cp $accFasta $mydb
		    else
			echo "Try downloading again"
			sleep 320
			fetch-genomes-fasta.py $acc
			sleep 5
			if [ -s $accFasta ]; then
			    echo "Downloaded from NCBI, good to continue."
			    cp $accFasta $mydb
			else 
			    echo "Fasta file ${acc} failed to download from NCBI." >> $root/failureSummary.txt
			fi
		    fi
  		fi
	    fi
	#else
	#    echo "invalid accession number"
	fi
    done
#read -p "$LINENO Enter"
#    # for each genome, make a folder and put the fasta file in the folder
    #for h in *; do
     #   genomeName=`echo $h | sed 's/\..*//'`
     #   mkdir $genomeName
     #   mv $h $genomeName
    #done

    #Full, original forward read file
    readOneFile=`ls ${root}/*_R1*.fastq`
    echo "Read one file is: $readOneFile"
    #Full, original reverse read file
    readTwoFile=`ls ${root}/*_R2*.fastq`
    echo "Read two file is: $readTwoFile"
    forCount=`grep -c "^+$" $readOneFile`
    revCount=`grep -c "^+$" $readTwoFile`

    #Start file to capture alignment summaries
    alignmentSummary=$root/alignmentSummary.txt
    #Report header is the short blurb that will go at the top of emails generated by email-secdKraken.sh
    reportHeader=$root/reportHeader.txt
    echo "##### Sample: $sampleName #####" >> $reportHeader
    if [ -s $root/failureSummary.txt ]; then
	cat $root/failureSummary.txt >> $alignmentSummary
	cat $root/failureSummary.txt >> $reportHeader
    fi
#read -p "$LINENO Enter"
    # for each genome folder (g is Accession #)
    cd $alignments
    echo "Results of Reference Alignments" >> $alignmentSummary
    for g in *; do
        cd $alignments
        cd ./$g
        ref=`ls *.fasta`
        echo "Reference file is $ref"
	if [ ! -z $ref ]; then
	    #read -p "$LINENO Enter"
            bwa index $ref
            samtools faidx $ref
            java -Xmx4g -jar ${picardPath}/CreateSequenceDictionary.jar REFERENCE=${ref} OUTPUT=${g}.dict
            bwa mem -M -B 1 -t 10 -T 20 -P -a -R @RG"\t"ID:"$g""\t"PL:ILLUMINA"\t"PU:"$g"_RG1_UNIT1"\t"LB:"$g"_LIB1"\t"SM:"$g" $ref $readOneFile $readTwoFile > ${g}.sam
            samtools view -bh -T $ref ${g}.sam > ${g}.raw.bam
            echo "Sorting Bam"
            samtools sort ${g}.raw.bam ${g}.sorted
            echo "****Indexing Bam"
            samtools index ${g}.sorted.bam
            rm ${g}.sam
	    rm ${g}.raw.bam
	    samtools view -h -b -F4 ${g}.sorted.bam > ./$g.mappedReads.bam
            if [ -e $readTwoFile ]; then
                java -Xmx2g -jar ${picardPath}/SamToFastq.jar INPUT=./$g.mappedReads.bam FASTQ=./${g}-mapped_R1.fastq SECOND_END_FASTQ=./${g}-mapped_R2.fastq
	    fi
   	    java -Xmx4g -jar ${GATKPath} -R $ref -T UnifiedGenotyper -glm BOTH -out_mode EMIT_ALL_SITES -I ${g}.sorted.bam -o ${g}.UG.vcf -nct 8
	    # Number of reads mapped to reference
	    mapCount=`cat *.fastq | grep -c "^+$"`
	    #Length of reference  
	    countNTs=`grep -v ">" $ref | wc | awk '{print $3}'`
	    #Number of nucleotides in reference with coverage
	    covCount=`grep -v "#" ${g}.UG.vcf | awk '{print $2, $4, $5, $6, $8}' | sed 's/\(.*\) .DP=\([0-9]*\).*/\1 \2/g' | awk '{if ($5 != "." ) print $0}' | grep -c ".*"`
	    declare -i x=${covCount}
	    declare -i y=${countNTs}
	    #Percent of reference with coverage
	    perc=`awk -v x=$x -v y=$y 'BEGIN { print(x/y)*100}'`
	    #Average depth of coverage for the reference
	    depthcov=`bamtools coverage -in ${g}.sorted.bam | awk '{sum+=$3} END { print sum/NR"X", "Average Depth of Coverage"}'`
	    refName=`grep $g ${root}/finalGenomesKey.txt | uniq`
	    # For SECD samples, to label R graph key correctly with virus abbreviation instead of accession number
	    abbrev=""
	    a=`echo $refName | grep "epidemic diarrhea virus"`
	    aprime=`echo $refName | grep "PEDV"`
	    b=`echo $refName | grep "PRCV"`
	    bprime=`echo $refName | grep "Porcine respiratory coronavirus"`
	    c=`echo $refName | grep "Transmissible gastroenteritis virus"`
	    cprime=`echo $refName | grep "TGEV"`
	    d=`echo $refName | grep "HKU15"`
	    if [[ ! -z $a ]] || [[ ! -z $aprime ]]; then
	        abbrev='PEDV'
	    elif [[ ! -z $b ]] || [[ ! -z $bprime ]]; then
	        abbrev='PRCV'
	    elif [[ ! -z $c ]] || [[ ! -z $cprime ]]; then
	        abbrev='TGEV'
	    elif [[ ! -z $d ]]; then
	        abbrev='PDCoV'
	    else
	        abbrev=$g
	    fi
	
	    bamtools coverage -in ${g}.sorted.bam | awk -v x=$abbrev 'BEGIN{OFS="\t"}{print x, $2, $3}' >> ${g}-coveragefile
            echo "`printf "%'.0f\n" ${mapCount}` reads aligned to $refName" >> $alignmentSummary
            echo "`printf "%'.0f\n" ${mapCount}` reads aligned to $refName" >> $reportHeader
	    echo "${perc}% genome coverage, $depthcov" >> $alignmentSummary
	    echo "${perc}% genome coverage, $depthcov" >> $reportHeader
            echo "" >> $reportHeader
	    echo "" >> $alignmentSummary
	fi
    done
else
    exit 1
fi

cd $root
#Put report together
cat $alignmentSummary >> $summaryFile
rm $alignmentSummary
cat $virusSummary >> $summaryFile
rm $virusSummary
rm directoriesToRemove.txt
rm *reportFormattedFile.txt
rm *kronaInput.txt
rm $root/list.txt
#rm finalGenomesKey.txt
#rm finalGenomesToDownload.txt 

#Prepare mergefile to feed to R script to generate R graph
cd $root/alignments
for i in `find . -name "*-coveragefile"`; do 
    echo "$i"
    cat $i >> $root/${sampleName}-mergefile;
done
highnumber=`awk 'BEGIN {max = 0} {if ($3>max) max=$3} END {print max}' $root/${sampleName}-mergefile`
if [[ highnumber -gt 5000 ]]; then
    highnumber=5000
fi
echo "Highnumber for the y axis is: $highnumber"
coveragebyr.r $root/${sampleName}-mergefile $sampleName $highnumber
mv myplot.pdf ${sampleName}.Rgraph.pdf
mv ${sampleName}.Rgraph.pdf $root/${sampleName}.CoverageProfile.pdf

#Finish moving files to uploadFolder
mv $root/${sampleName}.CoverageProfile.pdf $root/$uploadFolder
mv $summaryFile $root/$uploadFolder
#Copy everything in upload folder to submissions if an secd sample
if [ $organism == 'secd' ]; then
    cp -r $root/$uploadFolder /data/id/pedv/submissions/newfiles
fi

# Created by Kaity Brien, 2014-11-14    	
