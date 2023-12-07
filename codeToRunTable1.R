
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("stringr")) install.packages("stringr"); library(stringr)
if (!require("DatabaseConnector")) install.packages("DatabaseConnector"); library(DatabaseConnector)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction', upgrade = "never"); library(PatientLevelPrediction)
if (!require("CohortGenerator")) remotes::install_github('ohdsi/CohortGenerator', upgrade = "never"); library(CohortGenerator)
if (!require("CirceR")) remotes::install_github('ohdsi/CirceR', upgrade = "never"); library(CirceR)

# ------------------------------------------------------------------------------

## uncomment below option to set a custom temporary folder
# options(andromedaTempFolder = "")

cdmDatabaseName = ""
outputDirectory <- ""

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "",
  server = "",
  port = 0000,
  user = "",
  password = "",
)

cdmDatabaseSchema <- ""
cohortDatabaseSchema <- ""
cohortTable <- "dlc_cohorts"

# ensure this file path points to the cohorts folder in DeepLearningComparison
cohortDirectory <- file.path(getwd(), "cohorts")

# ------------------------------------------------------------------------------
dir.create(file.path(outputDirectory, "dlc_table1_results"))
outputDirectory <- file.path(outputDirectory, "dlc_table1_results")
cohortIds <- list(dementia=list(target=11931, outcome=6243),
                bipolar=list(target=11454, outcome=10461),
                lungcancer=list(target=11932, outcome=298))

cohortsToCreate <- CohortGenerator::createEmptyCohortDefinitionSet()
allCohorts <- dir(cohortDirectory)
cohorts <- allCohorts

numExtract <- function(string) {
  as.numeric(
    stringr::str_extract(
      string,
      "[-+]?[0-9]*\\.?[0-9]+"
    )
  )
}

for (i in 1:length(cohorts)) {
  cohortFile <- file.path(cohortDirectory, cohorts[[i]])
  cohortName <- tools::file_path_sans_ext(basename(cohortFile))
  cohortJson <- readChar(cohortFile, file.info(cohortFile)$size)
  cohortExpression <- CirceR::cohortExpressionFromJson(cohortJson)
  cohortSql <- CirceR::buildCohortQuery(
    cohortExpression,
    options = CirceR::createGenerateOptions(generateStats = FALSE))
  cohortsToCreate <- rbind(
    cohortsToCreate,
    data.frame(
      cohortId = numExtract(cohortName),
      cohortName = cohortName,
      sql = cohortSql,
      json = cohortJson,
      stringsAsFactors = FALSE
    )
  )
}

# create cohorts and store in cohort tables in scratch space
cohortTableNames <- CohortGenerator::getCohortTableNames(
  cohortTable = cohortTable
)
CohortGenerator::createCohortTables(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTableNames = cohortTableNames
)
cohortsGenerated <- CohortGenerator::generateCohortSet(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTableNames = cohortTableNames,
  cohortDefinitionSet = cohortsToCreate
)

defaultCovariateSettings <- FeatureExtraction::createDefaultCovariateSettings()
covariateSettings <- FeatureExtraction::createTable1CovariateSettings(
  covariateSettings = defaultCovariateSettings
)

# dementia -----------------------------------------------------------------

databaseDetails_dementia <- PatientLevelPrediction::createDatabaseDetails(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cdmDatabaseName = cdmDatabaseName,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outcomeDatabaseSchema = cohortDatabaseSchema,
  outcomeTable = cohortTable,
  targetId = cohortIds$dementia$target,
  outcomeIds = cohortIds$dementia$outcome
)

try(
  {
    plpData_dementia <- PatientLevelPrediction::getPlpData(
      databaseDetails = databaseDetails_dementia,
      covariateSettings = covariateSettings,
      restrictPlpDataSettings = PatientLevelPrediction::createRestrictPlpDataSettings()
    )
    
    tableOneCovData <- plpData_dementia$covariateData
    
    # dementia
    dementiaPopulationSettings <- createStudyPopulationSettings(
      binary = T, 
      includeAllOutcomes = T, 
      firstExposureOnly = T, 
      washoutPeriod = 365, 
      removeSubjectsWithPriorOutcome = F, 
      priorOutcomeLookback = 99999, 
      requireTimeAtRisk = T, 
      minTimeAtRisk = 1, 
      riskWindowStart = 1, 
      startAnchor = 'cohort start', 
      endAnchor = 'cohort start', 
      riskWindowEnd = 1825
    )
    
    dementia_population <- PatientLevelPrediction::createStudyPopulation(
      plpData = plpData_dementia,
      cohortIds$dementia$outcome,
      dementiaPopulationSettings
    )
    
    #filter to population
    filteredTableOneCovData <- tableOneCovData
    filteredTableOneCovData$covariates <- tableOneCovData$covariates %>%
      dplyr::filter(rowId %in% !!dementia_population$rowId)
    attr(filteredTableOneCovData, 'metaData')$populationSize <- nrow(dementia_population)
    AggregatedtableOneCovData <- FeatureExtraction::aggregateCovariates(filteredTableOneCovData)
    
    tableOne <- FeatureExtraction::createTable1(
      AggregatedtableOneCovData,
      output = 'one column',
      showCounts = TRUE,
      showPercent = TRUE
    )
    
    pop <- dementia_population
    data <- data.frame(
      c("Population count", "Outcome count", "Median time-at-risk (interquartile range)", "Female", "Male"),
      c(nrow(pop), sum(pop$outcomeCount), median(pop$timeAtRisk), sum(pop$gender == 8532), sum(pop$gender == 8507)),
      c(100.0, round(sum(pop$outcomeCount)/nrow(pop)*100, 1), IQR(pop$timeAtRisk), round(sum(pop$gender == 8532)/nrow(pop)*100, 1), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
    )
    names(data) <- names(tableOne)
    tableOne <- rbind(data, tableOne)
    
    saveRDS(tableOne, file.path(outputDirectory, "dementia.rds"))
  }
)

# bipolar -----------------------------------------------------------------

databaseDetails_bipolar <- PatientLevelPrediction::createDatabaseDetails(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cdmDatabaseName = cdmDatabaseName,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outcomeDatabaseSchema = cohortDatabaseSchema,
  outcomeTable = cohortTable,
  targetId = cohortIds$bipolar$target,
  outcomeIds = cohortIds$bipolar$outcome
)

try(
  {
    plpData_bipolar <- PatientLevelPrediction::getPlpData(
      databaseDetails = databaseDetails_bipolar,
      covariateSettings = covariateSettings,
      restrictPlpDataSettings = PatientLevelPrediction::createRestrictPlpDataSettings()
    )
    
    tableOneCovData <- plpData_bipolar$covariateData
    
    bipolarPopulationSettings <- createStudyPopulationSettings(
      removeSubjectsWithPriorOutcome = T,
      priorOutcomeLookback = 99999,
      requireTimeAtRisk = T,
      minTimeAtRisk = 1,
      riskWindowStart = 1,
      startAnchor = 'cohort start',
      riskWindowEnd = 365,
      endAnchor = 'cohort start'
    )
    
    bipolar_population <- PatientLevelPrediction::createStudyPopulation(
      plpData = plpData_bipolar,
      cohortIds$bipolar$outcome,
      bipolarPopulationSettings
    )
    
    #filter to population
    filteredTableOneCovData <- tableOneCovData
    filteredTableOneCovData$covariates <- tableOneCovData$covariates %>%
      dplyr::filter(rowId %in% !!bipolar_population$rowId)
    attr(filteredTableOneCovData, 'metaData')$populationSize <- nrow(bipolar_population)
    AggregatedtableOneCovData <- FeatureExtraction::aggregateCovariates(filteredTableOneCovData)
    
    tableOne <- FeatureExtraction::createTable1(
      AggregatedtableOneCovData,
      output = 'one column',
      showCounts = TRUE,
      showPercent = TRUE
    )
    
    pop <- bipolar_population
    data <- data.frame(
      c("Population count", "Outcome count", "Median time-at-risk (interquartile range)", "Female", "Male"),
      c(nrow(pop), sum(pop$outcomeCount), median(pop$timeAtRisk), sum(pop$gender == 8532), sum(pop$gender == 8507)),
      c(100.0, round(sum(pop$outcomeCount)/nrow(pop)*100, 1), IQR(pop$timeAtRisk), round(sum(pop$gender == 8532)/nrow(pop)*100, 1), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
    )
    names(data) <- names(tableOne)
    tableOne <- rbind(data, tableOne)
    
    saveRDS(tableOne, file.path(outputDirectory, "bipolar.rds"))
  }
)


# lungcancer -----------------------------------------------------------------

databaseDetails_lungcancer <- PatientLevelPrediction::createDatabaseDetails(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cdmDatabaseName = cdmDatabaseName,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outcomeDatabaseSchema = cohortDatabaseSchema,
  outcomeTable = cohortTable,
  targetId = cohortIds$lungcancer$target,
  outcomeIds = cohortIds$lungcancer$outcome
)

try(
  {
    plpData_lungcancer <- PatientLevelPrediction::getPlpData(
      databaseDetails = databaseDetails_lungcancer,
      covariateSettings = covariateSettings,
      restrictPlpDataSettings = PatientLevelPrediction::createRestrictPlpDataSettings()
    )
    
    tableOneCovData <- plpData_lungcancer$covariateData
    
    lungCancerPopulationSettings <- createStudyPopulationSettings(
      removeSubjectsWithPriorOutcome = T,
      priorOutcomeLookback = 99999,
      requireTimeAtRisk = T,
      minTimeAtRisk = 1,
      riskWindowStart = 1,
      startAnchor = 'cohort start',
      riskWindowEnd = 1095,
      endAnchor = 'cohort start'
    )
    
    lungcancer_population <- PatientLevelPrediction::createStudyPopulation(
      plpData = plpData_lungcancer,
      cohortIds$lungcancer$outcome,
      lungCancerPopulationSettings
    )
    
    #filter to population
    filteredTableOneCovData <- tableOneCovData
    filteredTableOneCovData$covariates <- tableOneCovData$covariates %>%
      dplyr::filter(rowId %in% !!lungcancer_population$rowId)
    attr(filteredTableOneCovData, 'metaData')$populationSize <- nrow(lungcancer_population)
    AggregatedtableOneCovData <- FeatureExtraction::aggregateCovariates(filteredTableOneCovData)
    
    tableOne <- FeatureExtraction::createTable1(
      AggregatedtableOneCovData,
      output = 'one column',
      showCounts = TRUE,
      showPercent = TRUE
    )
    
    pop <- lungcancer_population
    data <- data.frame(
      c("Population count", "Outcome count", "Median time-at-risk (interquartile range)", "Female", "Male"),
      c(nrow(pop), sum(pop$outcomeCount), median(pop$timeAtRisk), sum(pop$gender == 8532), sum(pop$gender == 8507)),
      c(100.0, round(sum(pop$outcomeCount)/nrow(pop)*100, 1), IQR(pop$timeAtRisk), round(sum(pop$gender == 8532)/nrow(pop)*100, 1), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
    )
    names(data) <- names(tableOne)
    tableOne <- rbind(data, tableOne)
    
    saveRDS(tableOne, file.path(outputDirectory, "lungcancer.rds"))
  }
)