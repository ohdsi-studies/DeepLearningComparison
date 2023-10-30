if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("stringr")) install.packages("stringr"); library(stringr)
if (!require("CohortGenerator")) remotes::install_github('ohdsi/CohortGenerator', upgrade = "never"); library(CohortGenerator)
if (!require("CirceR")) remotes::install_github('ohdsi/CirceR', upgrade = "never"); library(CirceR)

# ------------------------------------------------------------------------------

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms ="",
  server = "",
  port = 5439,
  user = "",
  password = "",
  extraSettings = "",
  pathToDriver = ""
)

cdmDatabaseSchema <- ""
cohortDatabaseSchema <- ""
cohortTable <- ""

# ------------------------------------------------------------------------------

cohortsToCreate <- CohortGenerator::createEmptyCohortDefinitionSet()
cohortDirectory <- file.path(getwd(), "cohorts")
allCohorts <- dir(cohortDirectory)
cohorts <- allCohorts

numextract <- function(string){as.numeric(stringr::str_extract(string, "[-+]?[0-9]*\\.?[0-9]+"))}
for (i in 1:length(cohorts)) {
    cohortFile <- file.path(cohortDirectory, cohorts[[i]])
    cohortName <- tools::file_path_sans_ext(basename(cohortFile))
    cohortJson <- readChar(cohortFile, file.info(cohortFile)$size)
    cohortExpression <- CirceR::cohortExpressionFromJson(cohortJson)
    cohortSql <- CirceR::buildCohortQuery(cohortExpression,
                                          options = CirceR::createGenerateOptions(generateStats = FALSE))
    cohortsToCreate <- rbind(cohortsToCreate, data.frame(cohortId = numextract(cohortName),
                                                         cohortName = cohortName,
                                                         sql = cohortSql,
                                                         json = cohortJson,
                                                         stringsAsFactors = FALSE))
}

# -----------------

# create cohorts and store in cohort tables in scratch space
cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)
CohortGenerator::createCohortTables(connectionDetails = connectionDetails,
                                    cohortDatabaseSchema = cohortDatabaseSchema,
                                    cohortTableNames = cohortTableNames)
cohortsGenerated <- CohortGenerator::generateCohortSet(connectionDetails = connectionDetails,
                                                       cdmDatabaseSchema = cdmDatabaseSchema,
                                                       cohortDatabaseSchema = cohortDatabaseSchema,
                                                       cohortTableNames = cohortTableNames,
                                                       cohortDefinitionSet = cohortsToCreate)


covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = T,
  useDemographicsAge = T,
  useDrugEraLongTerm = T,
  useConditionOccurrenceLongTerm = T,
  useCharlsonIndex = T,
  longTermStartDays = -365,
  endDays = 0
)

# get plpData and save in folders with name of database
for (database in databases) {
  databaseDetails <- PatientLevelPrediction::createDatabaseDetails(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cdmDatabaseName = database$name,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    outcomeDatabaseSchema = cohortDatabaseSchema,
    outcomeTable = cohortTable,
    targetId = 11931,
    outcomeIds = 6243
  )
  
  
  plpData <- PatientLevelPrediction::getPlpData(
    databaseDetails=databaseDetails,
    covariateSettings = covariateSettings
  )
  
  saveDir <- file.path('./data/', database$name)
  if (!dir.exists(saveDir)) {
    dir.create(saveDir, recursive=T)
  }
  PatientLevelPrediction::savePlpData(plpData, file=saveDir)
}

# -----------------

reticulate::use_virtualenv('/data/home/efridgeirsson/PycharmProjects/Sard/venv/')
pytorch <- reticulate::import('torch')
library(PatientLevelPrediction)
source('utils.R')
library(config)

config <- get('database')

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms=config$dbms,
                                             server=config$path,
                                             user=config$user,
                                             password=config$password,
                                             pathToDriver=config$driver)


defaultCovariateSettings <- FeatureExtraction::createDefaultCovariateSettings()

tableOneCovariateSettings <- FeatureExtraction::createTable1CovariateSettings(covariateSettings = defaultCovariateSettings)


# mortaliy T: 50001, O: 487
# readmission: T: 486, O: 486
# dementia: T: 1, O: 2
databaseDetails <- createDatabaseDetails()
restrictPlpDataSettings <- createRestrictPlpDataSettings()

tableOnePlpData <- PatientLevelPrediction::getPlpData(covariateSettings = tableOneCovariateSettings,
                                                      databaseDetails = databaseDetails,
                                                      restrictPlpDataSettings = restrictPlpDataSettings)

tableOneCovData <- tableOnePlpData$covariateData


# this is just my custom code to get the population dataframe
dataPath <- './data/sequence_dementia_fixed_splitting/'
python_data <- pytorch$load(file.path(dataPath, 'python_data'))

#python_data$population$to_feather(file.path(dataPath, 'population.feather'))
population <- arrow::read_feather(file.path(dataPath, 'population.feather'))

# filter to population
filteredTableOneCovData <- tableOneCovData
filteredTableOneCovData$covariates <- tableOneCovData$covariates %>% dplyr::filter(rowId %in% !!population$rowId)
attr(filteredTableOneCovData, 'metaData')$populationSize <- nrow(population)


AggregatedtableOneCovData <- FeatureExtraction::aggregateCovariates(filteredTableOneCovData)
tableOne <- FeatureExtraction::createTable1(AggregatedtableOneCovData)

saveRDS(tableOne, './results/tableOnes/dementia.rds')
