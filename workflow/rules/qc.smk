################################          QC           ##################################

rule CheckInputs:
    output:
       touch("config/.input.check")
    params:
       metadata=config['samples'],
       chroms=config['chroms'],
       gffpath=config['ref']['gff'],
       gene_names=config['ref']['genenames']
    log:
        "logs/CheckInputs.log"
    run:
        metadata = pd.read_csv(params.metadata, sep="\t")
        #check to see if fastq files 
        for sample in metadata.samples:
            for n in [1,2]:
                fqpath = f"resources/reads/{sample}_{n}.fastq.gz"
                assert os.path.isfile(fqpath), f"all sample names in 'samples.tsv' do not match a .fastq.gz file in the {worflow.basedir}/resources/reads/ directory"
        # check that the chromosomes are present in the gff file 
        check_chroms(params.gffpath, params.chroms)
        # check column names of gene_names.tsv
        gene_names = pd.read_csv(params.gene_names, sep="\t")
        colnames = ['Gene_stable_ID', 'Gene_description', 'Gene_name']
        assert (gene_names.columns == colnames).all(), f"Column names of gene_names.tsv should be {colnames}"

rule FastQC:
    input:
        "resources/reads/{sample}_{n}.fastq.gz"
    output:
        html="resources/reads/qc/{sample}_{n}_fastqc.html",
        zip="resources/reads/qc/{sample}_{n}_fastqc.zip"
    log:
        "logs/FastQC/{sample}_{n}_QC.log"
    params:
        outdir="--outdir resources/reads/qc"
    wrapper:
        "0.72.0/bio/fastqc"

rule BamStats:
    input:
        bam = "resources/alignments/{sample}.marked.bam",
        idx = "resources/alignments/{sample}.marked.bam.bai"
    output:
        stats = "resources/alignments/bamStats/{sample}.flagstat"
    log:
        "logs/BamStats/{sample}.log"
    wrapper:
        "0.70.0/bio/samtools/flagstat"

rule Coverage:
    input:
        bam = "resources/alignments/{sample}.marked.bam",
        idx = "resources/alignments/{sample}.marked.bam.bai"
    output:
        "resources/alignments/coverage/{sample}.mosdepth.summary.txt"
    log:
        "logs/Coverage/{sample}.log"
    conda:
        "../envs/depth.yaml"
    params:
        prefix = lambda w, output: output[0].split(os.extsep)[0],
        windowsize = 300
    threads:4
    shell: "mosdepth --threads {threads} --fast-mode --by {params.windowsize} --no-per-base {params.prefix} {input.bam}"

rule vcfStats:
    input:
        vcf = "results/variants/vcfs/annot.variants.{chrom}.vcf.gz"
    output:
        vcfStats = "results/variants/vcfs/stats/{chrom}.txt"
    conda:
        "../envs/variants.yaml"
    log:
        "logs/vcfStats/{chrom}.log"
    shell:
        """
        bcftools stats {input} > {output} 2> {log}
        """
