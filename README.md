### Pipeline summary:
-------------------------------------------------------------------------------------------------------------------------------------------------------
<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. PhiX adapter trimming and filtering of reads using BBDuK ([`BBDuK`](https://github.com/BioInfoTools/BBMap))
2. Read filtering, adapter trimming, quality profiling and base correction using fastp ([`fastp`](https://github.com/OpenGene/fastp))
3. Raw Reads QC Assessment specifics found in "QC Summary by Read Processing State" section 

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
#### <div align="center">*T Denotes Trimmed Reads that Were Not Assembled</div>
#### <div align="center">*A Denotes Reads that Proceed to Assembly</div>
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

### Analysis of Trimmed Reads
--------------------------------------------------------------------------------------------------------------------------------------------------------
4T. Gene detection and allele calling for antibiotic resistance, virulence (adding hypervirulence genes beyond their mention in the alerts section?), and/or plasmids using srst2 AR ([`srst2 AR`](https://github.com/katholt/srst2) <br>
5T. Report sequence types based on MLST alleles and profile definitions using srst2 MLST ([`srst2 MLST`](https://github.com/katholt/srst2)) <br>
6T. Kraken2 ()<br>

### Assembly
--------------------------------------------------------------------------------------------------------------------------------------------------------
5. Assemby of trimed reads using SPAdes ([`SPAdes`](https://github.com/ablab/spades))<br>
### Analysis of Assembled Reads <= 500bps
--------------------------------------------------------------------------------------------------------------------------------------------------------
4A. Assess assembly quality using QUAST ([`QUAST`](https://github.com/ablab/quast)) <br>
5A. Measure the nucleotide-level coding region similarity (between genomes) using fastANI ([`fastANI`](https://github.com/ParBLiSS/FastANI))<br>
6A. Type multiple loci to characterized isolates of microbial species using MLST ([`MLST`](https://github.com/tseemann/mlst))<br>
7A. Detect hypervirulence genes and find best matches to untranslated genes from a gene database using GAMMA ([`GAMMA`](https://github.com/rastanton/GAMMA))<br>
9A. Rapid whole genome annotation using Prokka ([`PROKKA`](https://github.com/tseemann/prokka))<br>
10A. Assess genome assembly for completeness using BUSCO ([`BUSCO`](https://busco.ezlab.org/))<br>
11A. KRAKEN2 ()<br>

    

<!-- Add conditional statement to workflow nf files to differentiate-->
### Format Results of Analysis

### QC Summary by Read Processing State

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->
#### Raw Reads
1. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))<br>
2. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

#### Trimmed Reads




![Workflow](https://github.com/MzDiaz824/QuAISAR_Nextflow/docs/images/WF.PNG?raw=true)

### Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console

    nextflow run nf-core/quaisar -profile test,YOURPROFILE

    ```

    Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

    > * The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
    > * Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > * If you are using `singularity` and are persistently observing issues downloading Singularity images directly due to timeout or network issues, then you can use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, you can use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
    > * If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

    ```console

    nextflow run nf-core/quaisar -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> --input samplesheet.csv --genome GRCh37

    ```

## Documentation


The nf-core/quaisar pipeline comes with documentation about the pipeline [usage](https://nf-co.re/quaisar/usage), [parameters](https://nf-co.re/quaisar/parameters) and [output](https://nf-co.re/quaisar/output).

## Credits

nf-core/quaisar was originally written by Rich Stanton, Nick Vlachos, Alyssa Kent, Maria Diaz, and Jill Hagey.


We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#quaisar` channel](https://nfcore.slack.com/channels/quaisar) (you can join with [this invite](https://nf-co.re/join/slack)).


## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->

<!-- If you use  nf-core/quaisar for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->


<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->
An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).


## Introduction (Needs to be developed then will move to top of page)

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->

**nf-core/quaisar** is a bioinformatics best-practice analysis pipeline for Quality, Assembly, Identification, Sequencing Typing, Annotation and Resistance mechanisms.


The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/quaisar/results)
