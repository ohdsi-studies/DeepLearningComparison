# if you want to run this code, you need to have the following packages installed:
# install.packages("remotes")
# remotes::install_github("OHDSI/DatabaseConnector@v6.2.3")
# remotes::install_github("OHDSI/PatientLevelPrediction@v6.3.5")
# remotes::install_github("OHDSI/CohortGenerator@v0.8.1")
# remotes::install_github("OHDSI/CirceR@v1.3.2")
# install.packages("stringr")


library(remotes)
library(stringr)
library(DatabaseConnector) # remotes::install_github("OHDSI/DatabaseConnector@v6.2.3")
library(PatientLevelPrediction) # remotes::install_github("OHDSI/PatientLevelPrediction@v6.3.5")
library(CohortGenerator) # remotes::install_github("OHDSI/CohortGenerator@v0.8.1")
library(CirceR)

# Inputs to run (edit these for your CDM):
# ========================================= #

## uncomment below option to set a custom temporary folder for Andromeda
# options(andromedaTempFolder = "")

minCellCount <- as.numeric(Sys.getenv('MIN_CELL_COUNT'))
cdmDatabaseName = Sys.getenv("DATABASE")
outputDirectory <- "/output/"

# fill in your connection details and path to driver
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = Sys.getenv('DBMS'), 
  server = Sys.getenv("DATABASE_SERVER"), 
  user = Sys.getenv("DATABASE_USER"),
  password = Sys.getenv("DATABASE_PASSWORD"),
  port = Sys.getenv("DATABASE_PORT"),
  pathToDriver = Sys.getenv("DRIVER_PATH")
)

cdmDatabaseSchema <- Sys.getenv("CDM_SCHEMA")
cohortDatabaseSchema <- Sys.getenv("WORK_SCHEMA")
cohortTable <- Sys.getenv("TABLE1_COHORT_TABLE")

# ensure this file path points to the cohorts folder in DeepLearningComparison folder
cohortDirectory <- "/project/cohorts" # file.path(getwd(), "cohorts")

# =========== END OF INPUTS ========== #

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
    
    # handle min cell count
    mask <- as.numeric(gsub(",", "", tableOne$Count)) < minCellCount
    mask[is.na(mask)] <- FALSE
    tableOne[[2]] <- ifelse(mask, paste0("<", minCellCount), tableOne[[2]])
    tableOne[[3]] <- ifelse(mask, "-", tableOne[[3]])
    
    pop <- dementia_population
    data <- data.frame(
      c("Population count",
        "Outcome count",
        "Median time-at-risk (interquartile range)",
        "Female",
        "Male"),
      c(ifelse(nrow(pop) < minCellCount, paste0("<", minCellCount), nrow(pop)),
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("<", minCellCount), sum(pop$outcomeCount)),
        median(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8532)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8507))),
      c(100.0,
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("-"), round(sum(pop$outcomeCount)/nrow(pop)*100, 1)),
        IQR(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("-"), round(sum(pop$gender == 8532)/nrow(pop)*100, 1)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("-"), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
      ))
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
    
    # handle min cell count
    mask <- as.numeric(gsub(",", "", tableOne$Count)) < minCellCount
    mask[is.na(mask)] <- FALSE
    tableOne[[2]] <- ifelse(mask, paste0("<", minCellCount), tableOne[[2]])
    tableOne[[3]] <- ifelse(mask, "-", tableOne[[3]])
    
    pop <- bipolar_population
    data <- data.frame(
      c("Population count",
        "Outcome count",
        "Median time-at-risk (interquartile range)",
        "Female",
        "Male"),
      c(ifelse(nrow(pop) < minCellCount, paste0("<", minCellCount), nrow(pop)),
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("<", minCellCount), sum(pop$outcomeCount)),
        median(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8532)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8507))),
      c(100.0,
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("-"), round(sum(pop$outcomeCount)/nrow(pop)*100, 1)),
        IQR(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("-"), round(sum(pop$gender == 8532)/nrow(pop)*100, 1)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("-"), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
      ))
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
    
    # handle min cell count
    mask <- as.numeric(gsub(",", "", tableOne$Count)) < minCellCount
    mask[is.na(mask)] <- FALSE
    tableOne[[2]] <- ifelse(mask, paste0("<", minCellCount), tableOne[[2]])
    tableOne[[3]] <- ifelse(mask, "-", tableOne[[3]])
    
    pop <- lungcancer_population
    data <- data.frame(
      c("Population count",
        "Outcome count",
        "Median time-at-risk (interquartile range)",
        "Female",
        "Male"),
      c(ifelse(nrow(pop) < minCellCount, paste0("<", minCellCount), nrow(pop)),
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("<", minCellCount), sum(pop$outcomeCount)),
        median(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8532)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("<", minCellCount), sum(pop$gender == 8507))),
      c(100.0,
        ifelse(sum(pop$outcomeCount) < minCellCount, paste0("-"), round(sum(pop$outcomeCount)/nrow(pop)*100, 1)),
        IQR(pop$timeAtRisk),
        ifelse(sum(pop$gender == 8532) < minCellCount, paste0("-"), round(sum(pop$gender == 8532)/nrow(pop)*100, 1)),
        ifelse(sum(pop$gender == 8507) < minCellCount, paste0("-"), round(sum(pop$gender == 8507)/nrow(pop)*100, 1))
      ))
    names(data) <- names(tableOne)
    tableOne <- rbind(data, tableOne)
    
    saveRDS(tableOne, file.path(outputDirectory, "lungcancer.rds"))
  }
)
