# SRAdownloadSingleCell

### Purpose: 
Download SRA files fast with sra-tools function `fasterq-dump`. Organize .fastq.gz files to samples (GSM codes), and rename for Cellranger. 

<br />

### Requirements: 
- sra-tools v3.2.0
- csvkit v1.0.5
- pigz v2.4 - note, I used a verison pre-installed on NYU HPC, not myelf or in conda.
- later versions will probably work fine.

Conda yml file included in repo: 

I think Pigz was installed from [here](https://zlib.net/pigz/).

<br />

### Input parameters: 
- `infolder`: a folder that contains a subdirectory called sratabfolder. This subfolder can contain one or more files like below.
- `nthreads`: number of CPUs used by fasterq-dump and pigz.
- `alloutsdir`: where to write all files. default is ${infolder}/GEOSRA


<br />

### Outputs: 
Two folders, with the following info:
- **GSEdir**: the raw downloaded fastq files per GSE study.
- **PARSED**: For each GSE study, soft-links (symlinks) to files in GSEdir are sorted by "GSM" sample. Additinaly, the symlinks are named in a manner that is compatible for Cellranger. The symlinks can be used for downstream applications, like Cellranger.

<br />

## Input format:

The `infolder` should lead to a directory with structure like below. You must create a subfolder called "sraruntables" that has SraRunTable files within.

```
infolder/
└── sraruntables
    ├── SraRunTable_GSE141038_SharmaOneBl.csv
    ├── SraRunTable_GSE161494_AfonsoOneCtl.csv
    ├── SraRunTable_GSE168389_SchlegelTwoBlAndOneReg.csv
    ├── SraRunTable_GSE246316_BarciaDuranTwoLL.csv
    └── SraRunTable_GSE253555_CyrTwoBL.csv
```

These SraRunTable files can be downloaded from GEO / SRA: GEO accessions should have a link at the bottom of the page mentioning "SRA Run Selector". Then you can download the Metadata from SRARunSelector. Finally, to use this tool, you must rename it like this, to add the GSE and some study description.


Minimally, each .csv file must contain a column called `Run` with the "SRR" codes, and a column called `Sample Name` which contains the GSM code (I am not sure if it will work if something else is there besides GSM code - probably it will, unless whitespaces are present).

For example, each file minimally should have two columns like this:

```
Run,Sample Name
SRR10533819,GSM4192841
```

The order of these columns or the presence/absence of other columns is not important.

<br />

## Method
1. From each of the sraruntables (ie, for each GSE), extract all SRRs, download via fasterq-dump, and zip with pigz.
2. A single GSM sample can have multiple SRR IDs (ie if there are multiple "lanes" for one single scRNAseq sample). Thus, we map SRRs to each GSM (sample). Organize SRRs to GSM folders, and place symlinks of each SRR ID's fastq files within. It should work if there are even more than 2 fastq files (tested on srrid_1-3.fastq.gz) - a prior version with parallel-fastq-dump did not split these properly and this script was hardcoded with fq (1-2) (this is fixed now).
3. convert the fastq symlink names to be compatible with Cellranger.

Potential future plan: just fully rename the fastq files, rather than use symlink.
