#!/usr/bin/env bash
./build-app.sh variation-analysis-3
./build-app.sh bam-to-goby-3
./build-app.sh goby-indexed-genome-builder-3
./build-app.sh parallel-gatk-realigner-3
./build-app.sh prepare-sbi-training-set-3
./build-app.sh extract-chromosomes-5
./build-app.sh genotypeSbi-to-tensors-3