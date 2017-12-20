#!/bin/bash
# VariationAnalysis 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

main() {

    # The dx command-line tool downloads the input files
    # to the local file system using variable names for the filenames.

    # Create the data directories to mount into the Docker container
    mkdir -p /input/indexed_genome
    mkdir -p /input/alignment
    mkdir -p /output/sbi
    mkdir -p /output/vcf

    for i in "${!Genome[@]}"; do
        echo "Downloading genome file '${Genome_name[$i]}'"
        dx download "${Genome[$i]}" -o /input/indexed_genome/${Genome_name[$i]}
    done

    for i in "${!Goby_Aligment[@]}"; do
        echo "Downloading goby alignment file '${Goby_Aligment_name[$i]}'"
        dx download "${Goby_Aligment[$i]}" -o /input/alignment/${Goby_Aligment_name[$i]}
    done

    dx-docker pull artifacts/variationanalysis-app:latest

    genome_basename=`basename /input/indexed_genome/*.bases | cut -d. -f1`
    echo "export SBI_GENOME=/input/indexed_genome/${genome_basename}" >> /input/configure.sh
    alignment_basename=`basename /input/alignment/*.entries | cut -d. -f1`
    echo "export GOBY_ALIGNMENT=/input/alignment/${alignment_basename}" >> /input/configure.sh
    echo "export GOBY_NUM_SLICES=50" >> /input/configure.sh
    # adjust num threads to match number of cores -1:
    echo "export SBI_NUM_THREADS=7" >> /input/configure.sh
    echo "export INCLUDE_INDELS='true'" >> /input/configure.sh
    echo "export REALIGN_AROUND_INDELS='false'" >> /input/configure.sh
    echo "export REF_SAMPLING_RATE='1.0'" >> /input/configure.sh
    dx-docker run \
        -v /input/:/input \
        -v /output/sbi:/output/sbi \
        artifacts/variationanalysis-app:latest \
        bash -c "source ~/.bashrc; source /input/configure.sh; cd /output/sbi; parallel-genotype-sbi.sh 10g ${GOBY_ALIGNMENT} 2>&1 | tee parallel-genotype-sbi.log"

    ls -lrt /output/sbi
    mkdir -p /input/model/

    echo "Downloading model file '${Model_archive_name}'"
    dx download "${Model_archive}" -o /input/model/${Model_archive_name}
    (cd /input/model/; tar -zxvf Model_*.tar.gz; rm Model_*.tar.gz)

    # invoke the predict-genotypes-many script inside the container
    dx-docker run \
        -v /output/sbi/:/input/sbi
        -v /input/model/:/input/model \
        -v /output/vcf/:/output/vcf \
        artifacts/variationanalysis-app:latest \
        bash -c "source ~/.bashrc; cd /output/vcf; predict-genotypes-many.sh 10g /input/model/ ${Model_name} /input/sbi/*.sbi" 

    # To recover the original filenames, you can use the output of
    # dx describe "$sorted_bam" --name.

    # Fill in your application code here.
    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.

    # The following line(s) use the utility dx-jobutil-add-output to format and                                                                                                          ls -l
    # add output variables to your job's output as appropriate for the output
    # class.

    for i in "${!predictions[@]}"; do
        dx-jobutil-add-output /output/prediction.vcf "${predictions[$i]}" --class=array:file
    done

}
