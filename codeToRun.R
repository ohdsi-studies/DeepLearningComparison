# Install latest Strategus
# remotes::install_github("ohdsi/Strategus")

# load Strategus
library(Strategus)

# Inputs to run (edit these for your CDM):
# ========================================= #

database <- 'databaseName' # your database name

# reference for the connection used by Strategus
connectionDetailsReference <- paste0("DeepLearningComparison_", database)

# where to save the output
outputFolder <- 'outputLocation'


connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = keyring::key_get('dbms', 'all'), 
  server = keyring::key_get('server', database), 
  user = keyring::key_get('user', 'all'),
  password = keyring::key_get('pw', 'all'),
  port = keyring::key_get('port', 'all'),
  pathToDriver = Sys.getenv("REDSHIFT_DRIVER")
)

# A schema with write access to store cohort tables
workDatabaseSchema <- keyring::key_get('workDatabaseSchema', 'all')

# name of cohort table for study
cohortTable <- "strategus_cohort_table"

# schema where the cdm data is
cdmDatabaseSchema <- keyring::key_get('cdmDatabaseSchema', database)

# Aggregated statistics with cell count less than this are removed before sharing results.
minCellCount <- 5


# Location to Strategus modules
# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = 'moduleLocation')

 
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

json <- paste(readLines('deep_comp_study.json'), collapse = '\n')
analysisSpecifications <- ParallelLogger::convertJsonToSettings(json)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputFolder, "strategusExecution"),
  restart=F
)
