/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap              } from 'plugin/nf-schema'
include { paramsSummaryMultiqc          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText        } from '../subworkflows/local/utils_nfcore_tbvarpipe_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PH-CORE MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQ_CLOCKWORK_DECONTAMINATE                         } from "../subworkflows/amd-ph-core/fastq_clockwork_decontaminate"
include { CAT_FASTQ                                             } from '../modules/nf-core/cat/fastq/main'
include { UNTAR                                                 } from '../modules/nf-core/untar/main'
include { VARPIPE_CORE as VARPIPE                               } from '../subworkflows/amd-ph-core/varpipe_core/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TBVARPIPE {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    // metadata

    main:

    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    ch_samplesheet
        .branch { _meta, fastqs ->
            multiple: fastqs.size() > 2
            single_pair: fastqs.size() == 2
        }
        .set { ch_fastqs }

    // MODULE: CAT_FASTQ (Concat step for samples with > 2 Fastqs)
    CAT_FASTQ(
        ch_fastqs.multiple
    )
    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first())

    ch_reads = CAT_FASTQ.out.reads.mix(ch_fastqs.single_pair)

    // SUBWORKFLOW (Optional): CLOCKWORK_PREPROCESS
    if (params.clockwork && params.clockwork_ref_preprocessing && params.clockwork_meta_preprocessing) {
        FASTQ_CLOCKWORK_DECONTAMINATE(
            ch_reads,
            params.clockwork_ref_preprocessing,
            params.clockwork_meta_preprocessing
        )
        ch_reads_decontam = FASTQ_CLOCKWORK_DECONTAMINATE.out.decontaminated_fastq
        ch_versions = ch_versions.mix(FASTQ_CLOCKWORK_DECONTAMINATE.out.versions)
    } else {
        ch_reads_decontam = ch_reads
    }

    // Extract snpEff cache if provided as tarball
    if (params.snpeff_cache?.endsWith('.tar.gz') || params.snpeff_cache?.endsWith('.tgz')) {
        UNTAR(Channel.of([[id: 'snpeff_cache'], file(params.snpeff_cache)]))
        ch_snpeff_cache = UNTAR.out.untar.map { _meta, cache -> cache }
        ch_versions = ch_versions.mix(UNTAR.out.versions)
    } else {
        ch_snpeff_cache = Channel.of(params.snpeff_cache)
    }

    // SUBWORKFLOW: VARPIPE
    VARPIPE(ch_reads_decontam,
        params.date,
        params.ref_fasta,
        params.bedlist_amp,
        params.bedlist_one,
        params.bedlist_two,
        params.bedstruct,
        params.mutationloci,
        params.included,
        params.reported,
        params.lineages,
        params.snpeff_db,
        ch_snpeff_cache
    )
    ch_versions = ch_versions.mix(VARPIPE.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(VARPIPE.out.multiqc_inputs)

    // Collate and save software versions
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'tbvarpipe_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    // Collect module and subworkflow component hashes
    Channel.fromPath("${projectDir}/modules.json")
        .splitJson(path: "repos")
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info"
        ) {
            def modules = [:]
            modules[it.key] = it.value
            def yaml = new org.yaml.snakeyaml.Yaml()
            [
                'tbvarpipe_software_' + 'components_git_sha.yml',
                "${yaml.dump(modules)}"
            ]
        }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = Channel.empty() // MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}
