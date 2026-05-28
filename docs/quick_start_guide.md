# amd-ph-core/tbvarpipe v1.2.1 Quick Start Guide

This guide walks through the end-to-end process of running the TB
variant-calling pipeline (`tbvarpipe`) hosted in the `amd-ph-core`
GitHub namespace. It covers preparing a working directory and executing
the pipeline using Nextflow with either Docker or Singularity profiles.
The Singularity profile is used when running in HPC
environments; in this setup Singularity automatically pulls and converts
Docker images as needed.

## Contents

1. [Prerequisites](#prerequisites)
2. [Running the Pipeline](#running-the-pipeline)
   - [Step 1: Create a Working Directory](#step-1-create-a-working-directory)
   - [Step 2: Download & Extract Static Assets](#step-2-download--extract-static-assets)
   - [Step 3: Create Configuration File](#step-3-create-configuration-file)
   - [Step 4: Download the Sample Sheet](#step-4-download-the-sample-sheet)
   - [Step 5: Run the Pipeline](#step-5-run-the-pipeline)
        - [To run via Docker](#to-run-via-docker)
        - [To run via Singularity](#to-run-via-singularity)
3. [Expected Output](#expected-output)
4. [Troubleshooting](#troubleshooting)
    - [Stale Revision Error](#stale-revision-error)
    - [Sample Sheet Column Mismatch](#sample-sheet-column-mismatch)
    - [Static Assets Not Found](#static-assets-not-found)
5. [Complete Setup Script](#complete-setup-script)
6. [Appendix A: References](#appendix-a-references)
7. [Appendix B: Version History](#appendix-b-version-history)
8. [Appendix C: Contact Information](#appendix-c-contact-information)

## Prerequisites

Prior to proceeding, ensure the following requirements are met:

  - **Nextflow** installed and available on your PATH.
      - Versions 24.10, 25.04, or 25.10 are recommended.

  - **A supported container runtime** is installed and running.
      - Docker or Singularity (for HPC)

  - **Internet connectivity** is available to allow retrieval of
    required containers from quay.io and cloning of the pipeline
    repository from GitHub.

  - **Sufficient local disk space, CPU, and memory** is available to
    accommodate the pipeline's resource requirements.
    - 6 CPUs and 32 GB of RAM
    - 20 GB of disk space free
    - See [Table 1](#table-1-required-resources-to-run-amd-ph-coretbvarpipe)
      for details

#### Table 1: Required resources to run amd-ph-core/tbvarpipe

| Process Name                       | CPUs | Memory |
| ---------------------------------- | ---: | -----: |
| CAT_FASTQ                          |    2 |   2 GB |
| CLOCKWORK_MINIMAP2                 |    6 |  36 GB |
| CLOCKWORK_REMOVECONTAM             |    2 |  12 GB |
| SAMTOOLS_VIEW, SAMTOOLS_VIEW_*     |    1 |   2 GB |
| VARPIPE_*(custom analysis modules) |    2 | 500 MB |
| BWA_INDEX                          |    2 |   4 GB |
| SAMTOOLS_FAIDX                     |    3 | 500 MB |
| PICARD_*                           |    3 |  12 GB |
| VARPIPE_BWAMEM                     |    3 |   6 GB |
| VARPIPE_SNPEFF_*                   |    3 |   6 GB |
| GATK4_*                            |    4 |  24 GB |
| TRIMMOMATIC                        |    2 |   2 GB |
| VARPIPE_TAR                        |    3 |   1 GB |
| MULTIQC                            |    1 |   6 GB |

## Running the Pipeline

Overview for executing the pipeline, outlining the primary
actions required to initiate and run the analysis.

### Step 1: Create a Working Directory

Create a dedicated directory for the test run. All outputs, the
sample sheet, and the local config will live here.

```shell
mkdir test-tbvarpipe
cd test-tbvarpipe
```

### Step 2: Download & Extract Static Assets

The pipeline requires a static-assets tarball that contains reference
data (databases, reference genomes, etc.). Fetch and extract it into
your working directory.

```shell
# Download the static assets archive and extract in place
wget https://ftp.cdc.gov/pub/AMD_Platform/tbvarpipe-static-assets-1.0.0.tar.gz
tar -xvf tbvarpipe-static-assets-1.0.0.tar.gz
```

After extraction you should see a directory named
`amd-ph-core-static-assets/`. This path is referenced by the
`params.static_assets` key in your local config (see
[Step 3](#step-3-create-configuration-file)).

### Step 3: Create Configuration File

Create a minimal Nextflow config file in your working directory (see
[Table 2](#table-2-configuration-file-parameter-descriptions) for
parameter descriptions). It sets three things:

1.  Timestamped work directory
2.  The path to the static assets
3.  Timestamped output directory

```shell
cat <<'EOF' > local.config 
ts = new Date().format('yyyy.MM.dd-HH.mm.ss')
workDir = "work/${ts}" 
params {
  static_assets = "${System.getenv('PWD')}/amd-ph-core-static-assets"
  outdir = "results/${ts}"
}
EOF
```

#### Table 2: Configuration file parameter descriptions

| Parameter / Setting    | Description |
| ---------------------- | ----------- |
| `ts`                   | Groovy expression that generates a timestamp string (e.g. 2025.03.21-14.30.00). Used to make every run directory unique. |
| `workDir`              | Nextflow intermediate/work directory. Scoped per run to avoid collisions when re-running. |
| `params.static_assets` | Path to the extracted static-assets directory. Must match the directory name produced by the tar extraction in Step 2. |
| `params.outdir`        | Final results directory. Timestamped alongside workDir so inputs and outputs from each run are traceable. |

### Step 4: Download the Sample Sheet

A test sample sheet is maintained in the oamd-bio-test-data repository
on GitHub. Download it into your working directory with wget. One of
the two test samples is expected to fail QC and will not produce all
outputs as a result. Samples have been selected from the publicly
available [iValiD-TB](https://www.frontiersin.org/journals/tuberculosis/articles/10.3389/ftubr.2024.1441923/full)
dataset.

```shell
wget https://raw.githubusercontent.com/CDCgov/oamd-bio-test-data/refs/heads/tbmainsurveillance/samplesheet/samplesheet.csv
```

**NOTE**: The sample sheet uses the `fastq_1` through `fastq_8` column
convention (eight FASTQ fields per row, one sample per row). Each sample
requires an even number of FASTQ files (i.e., paired reads), with at
least one pair of files per sample.

### Step 5: Run the Pipeline

With all prerequisites in place, execute the pipeline. The commands
below use either the Docker profile or Singularity profile, the local
config from [Step 3](#step-3-create-configuration-file), and the sample
sheet from [Step 4](#step-4-download-the-sample-sheet). The `-latest`
flag instructs Nextflow to pull the most recent code at the specified
revision, bypassing any locally cached copy. See [Table 3](#table-3-run-command-flag-descriptions)
for descriptions of all run command flags (`-c`, `-r`, etc.)

#### To run via Docker

```shell
nextflow run amd-ph-core/tbvarpipe \
  -r 1.2.1 \
  -latest \
  -profile docker \
  -c local.config \
  --input samplesheet.csv
```

#### To run via Singularity

When running in HPC environments where Docker is not available, the pipeline can be
run with Nextflow using a Singularity profile. In this setup
Singularity automatically pulls and converts Docker images as needed.

**Note**: Additional configuration is needed for Singularity before running the pipeline.

##### Set a Temporary Directory with Sufficient Disk Space

```shell
# replace with your actual scratch/tmp path
export TMPDIR=</path/to/scratch>/tmp
export SINGULARITY_TMPDIR=$TMPDIR
mkdir -p $TMPDIR
```

##### Update the local.config to Direct Singularity to the Temporary Directory 

```shell
cat <<'EOF' >> local.config
singularity {
  runOptions = "--bind ${System.getenv('TMPDIR')}:/tmp"
}
EOF
```

##### Run the Pipeline

```shell
nextflow run amd-ph-core/tbvarpipe \
  -r 1.2.1 \
  -latest \
  -profile singularity \
  -c local.config \
  --input samplesheet.csv
```

#### Table 3: Run Command Flag Descriptions

| Parameter/Setting         | Description |
| ------------------------- | ----------- |
| `amd-ph-core/tbvarpipe`   | GitHub repository path. Nextflow resolves this automatically. |
| `-r 1.2.1`                | Explicit git revision to run. Always pin a version to ensure reproducibility. |
| `-latest`                 | Forces Nextflow to pull the latest code at the given revision, overwriting any stale local cache. Equivalent to manually clearing `~/.nextflow/assets/amd-ph-core/tbvarpipe` before running. |
| `-profile docker`         | Activates the Docker execution profile defined in the pipeline's nextflow.config. |
| `-c local.config`         | Merges your local.config settings (`workDir`, `static_assets`, `outdir`) into the pipeline configuration. |
| `--input samplesheet.csv` | Path to the sample sheet downloaded in [Step 4](#step-4-download-the-sample-sheet). |

NOTE: On first run, Nextflow will pull all Docker containers from quay.io. This may take several minutes depending on network speed. Subsequent runs with the same containers will be significantly faster.

## Expected Output 

After a successful run, two timestamped directories will appear in your
working directory:
  - `work/YYYY.MM.DD-HH.mm.ss/` -- Nextflow intermediate files (cache,
    logs, staged inputs)
  - `results/YYYY.MM.DD-HH.mm.ss/` -- Final pipeline outputs (VCF files,
    reports, QC summaries)

Early in the run you will see Nextflow begin staging SRR samples
(downloaded from SRA) and container images being pulled. The pipeline
will create these directories automatically.

## Troubleshooting

### Stale Revision Error

If Nextflow reports that the current revision is stale or cannot find
revision 1.2.1, confirm that the `-latest` flag is present in your run
command. If the issue persists, manually clear the cache with the
following command and re-run.

```shell
rm -rf ~/.nextflow/assets/amd-ph-core/tbvarpipe 
```

### Sample Sheet Column Mismatch

The pipeline expects a sample sheet with eight columns (fastq_1, ...,
fastq_8) where between two and eight FASTQ paths may be input per row
(one sample per row, with an even number of FASTQ files per sample).
If you provide a sample sheet with fewer columns in the header or an
odd number of files, the pipeline will fail. Use the canonical test
sample sheet from Step 4 to verify your format.

### Static Assets Not Found

Ensure the extracted directory name exactly matches the value of
`params.static_assets` in local.config. The default is
`amd-ph-core-static-assets`.

## Complete Setup Script

The following script combines all steps above (using the Docker
profile). Copy it into a shell script and execute it from the
directory where you want your run to live.

To use, save the script below as `run-tbvarpipe.sh`, then:

```shell
chmod +x run-tbvarpipe.sh
./run-tbvarpipe.sh
```

```shell
#!/usr/bin/env bash
# run-tbvarpipe.sh

set -euo pipefail

# 1. Create and enter working directory
mkdir -p test-tbvarpipe && cd test-tbvarpipe

# 2. Download and extract static assets
wget https://ftp.cdc.gov/pub/AMD_Platform/tbvarpipe-static-assets-1.0.0.tar.gz
tar -xvf tbvarpipe-static-assets-1.0.0.tar.gz

# 3. Write local.config
cat <<'EOF' > local.config
ts = new Date().format('yyyy.MM.dd-HH.mm.ss')
workDir = "work/${ts}"
params {
  static_assets = "${System.getenv('PWD')}/amd-ph-core-static-assets"
  outdir = "results/${ts}"
}
EOF

# 4. Download test sample sheet
wget https://raw.githubusercontent.com/CDCgov/oamd-bio-test-data/refs/heads/tbmainsurveillance/samplesheet/samplesheet.csv

# 5. Run the pipeline
nextflow run amd-ph-core/tbvarpipe \
  -r 1.2.1 \
  -latest \
  -profile docker \
  -c local.config \
  --input samplesheet.csv
```

## Appendix A: References

The following table summarizes the resources referenced in this document.

| Resource | Description |
| -------- | ----------- |
| [amd-ph-core/tbvarpipe](https://github.com/amd-ph-core/tbvarpipe/) | Public GitHub repository; README contains the canonical run command. |
| [CDCgov/oamd-bio-test-data](https://github.com/CDCgov/oamd-bio-test-data/tree/tbmainsurveillance) | Public GitHub repository hosting test data for AMD Platform workflows. `tbmainsurveillance` branch contains the reference sample sheet. |
| [quay.io/us-cdcgov](https://quay.io/organization/us-cdcgov) | Public container registry |
| [Nextflow Documentation](https://www.nextflow.io/docs/latest) | Documentation for Nextflow |

## Appendix B: Version History

| **VERSION** | **IMPLEMENTED BY** | **REVISION DATE** | **REASON** |
| ----------- | ------------------ | ----------------- | ---------- |
| 1.0         |  AMD Platform Team | 05/20/2026        | Provide users with instructions for setting up and running the amd-ph-core/tbvarpipe bioinformatics pipeline. |

## Appendix C: Contact Information

> U.S. Centers for Disease Control and Prevention<br />
> National Center for Emerging and Zoonotic Infectious Diseases<br />
> Division of Infectious Disease Readiness and Innovation<br />
> Office of Advanced Molecular Detection <br />
> Web: https://www.cdc.gov/advanced-molecular-detection/<br />
> Help: [AMD Platform Help Desk](https://servicedesk.cdc.gov/esc?id=sc_cat_item&table=sc_cat_item&sys_id=51f3f8541b69da906aa6ece2604bcbfd&searchTerm=amd%20platform)