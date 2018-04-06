#!/bin/bash
# genotype-tensor 0.0.1
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

    dx-download-all-inputs --parallel

    CONFIG_FILE="${HOME}/in/scripts/configure.sh"
    mkdir -p ${HOME}/in/scripts/
    mkdir -p $HOME/out/Predictions
    
    set -x
    #flatten the inputs in a single folder
    find ${HOME}/in/Genome/ -type f -name "${Genome_prefix[0]}.*" -execdir mv {} .. \;
    find ${HOME}/in/Goby_Alignment/ -type f -name "${Goby_Alignment_prefix[0]}.*" -execdir mv {} .. \;

    # configure
    #genome_basename=`basename /input/indexed_genome/*.bases .bases`
    echo "export SBI_GENOME=/in/Genome/${Genome_prefix[0]}" >> ${CONFIG_FILE}
    echo "export GOBY_ALIGNMENT=/in/Goby_Alignment/${Goby_Alignment_prefix[0]}" >> ${CONFIG_FILE}
    echo "export GOBY_NUM_SLICES=${Num_Slices}" >> ${CONFIG_FILE}
    echo "export MODEL_PATH=/in/Model_Archive/" >> ${CONFIG_FILE}
    echo "export MODEL_NAME=${Model_Name}" >> ${CONFIG_FILE}

    cpus=`grep physical  /proc/cpuinfo |grep id|wc -l`
    memory=`cat /proc/meminfo | grep MemAvailable | awk '{print $2}'`
    # memory is expressed in kb, /1024 to transform in Mb and assign it to each thread
    parallel_executions=`echo $(( memory / 1048576 / 10  ))`
    echo "export SBI_NUM_THREADS=${parallel_executions}" >> ${CONFIG_FILE}
    echo "export INCLUDE_INDELS='true'" >> ${CONFIG_FILE}
    echo "export REALIGN_AROUND_INDELS='false'" >> ${CONFIG_FILE}
    echo "export REF_SAMPLING_RATE='1.0'" >> ${CONFIG_FILE}
    echo "export OUTPUT_BASENAME=${Goby_Alignment_prefix[0]}" >> ${CONFIG_FILE}
    echo "export DO_CONCAT='false'" >> ${CONFIG_FILE}
    cat /input/configure.sh



    cat >${HOME}/in/run.sh <<EOL
        #!/bin/bash
        source /in/scripts/configure.sh
        source /in/scripts/working_script.sh
        execute
EOL
    chmod a+x  ${HOME}/in/run.sh


    echo "Downloading the docker image..."
    dx-docker pull artifacts/variationanalysis-app:${Image_Version} &>/dev/null

    dx-docker run \
        -v ${HOME}/out/:/out/ \
        -v ${HOME}/in/:/in/ \
        artifacts/variationanalysis-app:${Image_Version} \
        bash -c "source ~/.bashrc; /in/run.sh"

}