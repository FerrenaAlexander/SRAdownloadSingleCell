# SRAdownloadSingleCell

#### Purpose: 
download SRA files fast with `parallel-fastq-dump`. Organize files to samples (GSM codes) and rename for Cellranger. 

#### Requirements: 
- parallel-fastq-dump v0.6.7
- sra-tools v3.2.0
- csvkit v1.0.5

Conda yml file included in repo.


#### Input parameters: 
- `infolder`: a folder that contains a subdirectory called sratabfolder. This subfolder can contain one or more files like below.
- `nthreads`: number of CPUs used by parallel-fastq-dump
- `alloutsdir`: where to write all files. default is ${infolder}/GEOSRA


#### Outputs: 
Two folders, with the following info:
- **GSEdir**: the raw downloaded fastq files per GSE study.
- **PARSED**: For each GSE study, soft-links (symlinks) to files in GSEdir are sorted by "GSM" sample. Additinaly, the symlinks are named in a manner that is compatible for Cellranger. The symlinks can be used for downstream applications, like Cellranger.



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
