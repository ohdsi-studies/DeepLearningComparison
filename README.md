Deep Learning Comparison
========================

<img src="https://img.shields.io/badge/Study%20Status-Design%20Finalized-brightgreen.svg" alt="Study Status: Design Finalized">

- Analytics use case(s): **Patient-Level Prediction**
- Study type: **Methods Research**
- Tags: **Deep Learning**
- Study lead: **Chungsoo Kim, Henrik John, Jenna Reps and Egill Fridgeirsson**
- Study lead forums tag: **-**
- Study start date: **-**
- Study end date: **-**
- Protocol: [**Protocol**](StudyProtocol.pdf)
- Publications: **-**
- Results explorer: **-**

A comparison of different deep learning models for three prediction tasks previously studied: predicting 3-year risk of lung cancer in low risk population, predicting 10-year risk of dementia and predicting 1-year risk bipolar in MDD.

This study will use Strategus (v0.1.0) and requires: - OMOP CDM database - Java for the JDBC connection - R (plus R studio is recommended) - The R package keyring to be set up

Note that by default the study will run on ```cuda:0```. If you have more GPUs and want to use a specific one you can specify the environment variable CUDA_VISIBLE_DEVICES to the required gpu before execution. For example using R:

```R
Sys.setenv("CUDA_VISIBLE_DEVICES" = "1") # run on GPU number 2 (0-indexed)
```

We also provide a docker container, which is by far the easiest way to run the study if your environment supports it. For more information see readme in docker subfolder.

# Recommended hardware requirements
CPUs : 8
CPU memory: 32GB
GPU : Cuda capable GPU with at least 12-16 GB of GPU memory, can depend on size of data for Transformer model. 
Diskspace: 50GB 

# Code To Run
First you need to clone this git repo to the machine where you want to run the study which has access to both the database and GPUs.

We recommend running the table1 script first to ensure that the target populations are present in your database. This script requires recent versions of PatientLevelPrediction (v6.3.5), CohortGenerator (v.0.8.1) and DatabaseConnector (v6.2.3). Make sure to edit the codeToRunTable1.R to match your environment. All variables needed are inside the input markers.

```r
# install these packages if needed
remotes::install_github("OHDSI/DatabaseConnector@v6.2.3")
remotes::install_github("OHDSI/PatientLevelPrediction@v6.3.5")
remotes::install_github("OHDSI/CohortGenerator@v0.8.1")
remotes::install_github("OHDSI/CirceR@v1.3.2")

# Inputs to run (edit these for your CDM):
# ========================================= #

# code with variables to be edited for your environ

# ========================================= #
```

Then to run the script execute:

``` r
source('codeToRunTable1.R')
```

To run the model development execute the following code, make sure you adjust the inputs to your environment. This snippet is as well stored in codeToRun.R

```{r}
# Install Strategus if needed
# remotes::install_github("ohdsi/Strategus@v0.1.0")

# load Strategus
library(Strategus)

# Inputs to run (edit these for your CDM):
# ========================================= #

database <- Sys.getenv("DATABASE") # your database name 

# reference for the connection used by Strategus
connectionDetailsReference <- paste0("DeepLearningComparison_", database)

# where to save the output - a directory in your environment
outputFolder <- "/output/"

# fill in your connection details and path to driver
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = Sys.getenv('DBMS'), 
  server = Sys.getenv("DATABASE_SERVER"), 
  user = Sys.getenv("DATABASE_USER"),
  password = Sys.getenv("DATABASE_PASSWORD"),
  port = Sys.getenv("DATABASE_PORT"),
  pathToDriver = "/database_drivers"
)

# A schema with write access to store cohort tables
workDatabaseSchema <- Sys.getenv("WORK_SCHEMA")

# name of cohort table that will be created for study
cohortTable <- Sys.getenv("STRATEGUS_COHORT_TABLE")

# schema where the cdm data is
cdmDatabaseSchema <- Sys.getenv("CDM_SCHEMA")

# Aggregated statistics with cell count less than this are removed before sharing results.
minCellCount <- 5


# Location to Strategus modules
# If you've ran Strategus studies before on the machine this directory should already exist.
# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = '/modules/')

 
# =========== END OF INPUTS ========== #

Strategus::storeConnectionDetails(
  connectionDetails = connectionDetails,
  connectionDetailsReference = connectionDetailsReference
)

executionSettings <- Strategus::createCdmExecutionSettings(
  connectionDetailsReference = connectionDetailsReference,
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTable),
  workFolder = file.path(outputFolder, "strategusWork"),
  resultsFolder = file.path(outputFolder, "strategusOutput"),
  minCellCount = minCellCount
)

json <- paste(readLines('./study_execution_jsons/deep_comp_study.json'), collapse = '\n')
analysisSpecifications <- ParallelLogger::convertJsonToSettings(json)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputFolder, "strategusExecution"),
  restart = F
)
```


