#!/usr/bin/env bash
./build-app.sh variation-analysis
./build-app.sh bam-to-goby
./build-app.sh goby-indexed-genome-builder --bill-to org-campagnelab
./build-app.sh parallel-gatk-realigner
./build-app.sh prepare-sbi-training-set