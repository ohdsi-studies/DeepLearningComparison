# Install latest Strategus
# remotes::install_github("ohdsi/Strategus")

# load Strategus
library(Strategus)

# Inputs to run (edit these for your CDM):
# ========================================= #

database <- 'local' # your database name

# reference for the connection used by Strategus
connectionDetailsReference <- paste0("DeepLearningComparison_", database)

# where to save the output
outputFolder <- "./output/"


connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = 'postgresql',
  server = 'localhost/cdm',
  user = 'postgres',
  password = '1234',
  port = 5432,
  pathToDriver = "~/database_drivers"
)

# A schema with write access to store cohort tables
workDatabaseSchema <- 'results'

# name of cohort table for study
cohortTable <- "strategus_cohort_table"
# schema where the cdm data is
cdmDatabaseSchema <- "cdm"

# Aggregated statistics with cell count less than this are removed before sharing results.
minCellCount <- 5


# Location to Strategus modules
# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = '~/modules/')


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
