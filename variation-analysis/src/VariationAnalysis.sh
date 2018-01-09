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

    # create the data directories to mount into the Docker container
    mkdir -p /input/indexed_genome
    mkdir -p /input/alignment
    mkdir -p /output/sbi
    mkdir -p /output/vcf

    for i in "${!Genome[@]}"; do
        echo "Downloading genome file '${Genome_name[$i]}'"
        dx download "${Genome[$i]}" -o /input/indexed_genome/${Genome_name[$i]}
    done

    for i in "${!Goby_Alignment[@]}"; do
        echo "Downloading goby alignment file '${Goby_Alignment_name[$i]}'"
        dx download "${Goby_Alignment[$i]}" -o -f /input/alignment/${Goby_Alignment_name[$i]}
    done

    echo "Downloading the docker image..."
    dx-docker pull artifacts/variationanalysis-app:latest &>/dev/null

    # configure
    genome_basename=`basename /input/indexed_genome/*.bases | cut -d. -f1`
    echo "export SBI_GENOME=/input/indexed_genome/${genome_basename}" >> /input/configure.sh
    alignment_basename=`basename /input/alignment/*.entries | cut -d. -f1`
    echo "export GOBY_ALIGNMENT=/input/alignment/${alignment_basename}" >> /input/configure.sh
    echo "export GOBY_NUM_SLICES=1" >> /input/configure.sh
    # adjust num threads to match number of cores -1:
    cpus=`grep physical  /proc/cpuinfo |grep id|wc -l`
    echo "export SBI_NUM_THREADS=${cpus}" >> /input/configure.sh
    echo "export INCLUDE_INDELS='true'" >> /input/configure.sh
    echo "export REALIGN_AROUND_INDELS='false'" >> /input/configure.sh
    echo "export REF_SAMPLING_RATE='1.0'" >> /input/configure.sh
    echo "export OUTPUT_BASENAME=${alignment_basename}" >> /input/configure.sh
    echo "export DO_CONCAT='false'" >> /input/configure.sh
    cat /input/configure.sh

    dx-docker run \
        -v /input/:/input \
        -v /output/sbi:/output/sbi \
        artifacts/variationanalysis-app:latest \
        bash -c "source ~/.bashrc; source /input/configure.sh; cd /output/sbi; parallel-genotype-sbi.sh 10g \"/input/alignment/${alignment_basename}\" 2>&1 | tee parallel-genotype-sbi.log"

    ls -lrt /output/sbi
    mkdir -p /input/model/

    echo "Downloading model file '${Model_Archive_name}'"
    dx download "${Model_Archive}" -o /input/model/${Model_Archive_name}
    (cd /input/model/; tar -zxvf Model_*.tar.gz; rm Model_*.tar.gz)

    mkdir -p /input/scripts

    cat >/input/scripts/merge.sh <<EOL
    #!/bin/bash
    cd /output/vcf/
    cat *-observed-regions.bed | sort -k1,1 -k2,2n | mergeBed > model-bestscore-observed-regions.bed
    bgzip -f model-bestscore-observed-regions.bed
    tabix -f model-bestscore-observed-regions.bed.gz
EOL
    chmod u+x /input/scripts/merge.sh
    # invoke the predict-genotypes-many script inside the container
    dx-docker run \
        -v /output/sbi/:/input/sbi \
        -v /input/:/input \
        -v /output/vcf/:/output/vcf \
        artifacts/variationanalysis-app:latest \
        bash -c "source ~/.bashrc; source /input/configure.sh;  cd /output/vcf; predict-genotypes-many.sh 10g /input/model/ \"${Model_Name}\" /input/sbi/*.sbi; /input/scripts/merge.sh"


    echo "Content of output/vcf:"
    ls -lrt /output/vcf/
    # publish the output
    mkdir -p $HOME/out/Predictions
    mv /output/vcf/*.vcf.gz.tbi $HOME/out/Predictions/
    mv /output/vcf/*.vcf.gz $HOME/out/Predictions/
    mv /output/vcf/model-bestscore-observed-regions.bed.gz $HOME/out/Predictions/

    echo "Content of Predictions:"
    ls -lrt $HOME/out/Predictions/

    dx-upload-all-outputs

}
