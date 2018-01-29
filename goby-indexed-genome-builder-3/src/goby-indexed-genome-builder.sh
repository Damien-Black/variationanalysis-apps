#!/bin/bash
# goby-indexed-genome-builder 0.0.1
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

    mkdir -p /input/FASTA_Genome
    mkdir -p /input/scripts
    mkdir -p /out/Goby_Genome

    # download the gzipped genome
    echo "Downloading genome file '${FASTA_Genome_name}'"
    dx download "${FASTA_Genome}" -o /input/FASTA_Genome/${FASTA_Genome_name}
    #unzip
    (cd /input/FASTA_Genome; gunzip ${FASTA_Genome_name})

    echo "Downloading the docker image..."
    dx-docker pull artifacts/variationanalysis-app:${Image_Version} &>/dev/null

    genome=`basename /input/FASTA_Genome/*.fa*`

    ls -lrt
    cat >/input/scripts/index.sh <<EOL
    #!/bin/bash
    set -x
    cd /input/FASTA_Genome
    samtools faidx /input/FASTA_Genome/*.fasta
    cd /out/Goby_Genome/
    goby 6g build-sequence-cache /input/FASTA_Genome/${genome}
    ls -lrt /input/FASTA_Genome/
    ls -lrt /out/Goby_Genome/

EOL
    chmod u+x /input/scripts/index.sh

    #index
    dx-docker run \
        -v /input/:/input \
        -v /out/:/out \
        artifacts/variationanalysis-app:${Image_Version} \
        bash -c "source ~/.bashrc; cd /out/Goby_Genome; /input/scripts/index.sh"

    mkdir -p $HOME/out/Goby_Genome
    
    # the goby genome files are created in the input folder not in the working dir, can we fix this?
    mv /input/FASTA_Genome/*.sizes $HOME/out/Goby_Genome/ || true
    mv /input/FASTA_Genome/*.bases $HOME/out/Goby_Genome/ || true
    mv /input/FASTA_Genome/*.ignore $HOME/out/Goby_Genome/ || true
    mv /input/FASTA_Genome/*.names $HOME/out/Goby_Genome/ || true
    
    dx-upload-all-outputs --parallel
}
