Deep Learning Comparison
=============

<img src="https://img.shields.io/badge/Study%20Status-Repo%20Created-lightgray.svg" alt="Study Status: Repo Created">

- Analytics use case(s): **Patient-Level Prediction**
- Study type: **Methods Research*
- Tags: **Deep Learning**
- Study lead: **-**
- Study lead forums tag: **[[Lead tag]](https://forums.ohdsi.org/u/[Lead tag])**
- Study start date: **-**
- Study end date: **-**
- Protocol: **-**
- Publications: **-**
- Results explorer: **-**

A comparison of different deep learning models for three prediciton tasks previously studied: predicitng 3-year risk of lung cancer in low risk population, predicting 10-year risk of dementia and predicitng 1-year risk bipolar in MDD.

This study will use Strategus and requires: 
- OMOP CDM database
- Java for the JDBC connection
- R (plus R studio is recommended)
- The R package keyring to be set up

# Code To Run

```{r}
# Install latest Strategus
remotes::install_github("ohdsi/Strategus", ref = 'develop')

# load Strategus
library(Strategus)
library(dplyr)

# Inputs to run (edit these for your CDM):
# ========================================= #

database <- 'databaseName'
connectionDetailsReference <- "databaseName"
outputFolder <- '/Users/username/Documents/saveLocation'
cdmDatabaseSchema <- keyring::key_get('cdmDatabaseSchema', database)
workDatabaseSchema <- "schema where you can read/write to"
cohortTable <- "plp_pca"
  
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = keyring::key_get('dbms', database),
  server = keyring::key_get('server', database),
  user = keyring::key_get('user', database),
  password = keyring::key_get('pw', database),
  port = keyring::key_get('port', database)
)

# end inputs

storeConnectionDetails(connectionDetails = connectionDetails,
                       connectionDetailsReference = connectionDetailsReference)

executionSettings <- createExecutionSettings(
  connectionDetailsReference = connectionDetailsReference,
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTable),
  workFolder = file.path(outputFolder, "strategusWork"),
  resultsFolder = file.path(outputFolder, "strategusOutput"),
  minCellCount = 5
)

# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = file.path(outputFolder,"StrategusInstantiatedModules"))

url <- "https://raw.githubusercontent.com/ohdsi-studies/DeepLearningComparison/master/deep_comp_study.json"
json <- readLines(file(url))
json2 <- paste(json, collaplse = '\n')
analysisSpecifications <- ParallelLogger::convertJsonToSettings(json2)

execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputFolder,"strategusExecution")
)
```

