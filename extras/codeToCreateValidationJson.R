
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("dplyr")) install.packages("dplyr"); library(dplyr)
if (!require("tibble")) install.packages("tibble"); library(tibble)
if (!require("Strategus")) remotes::install_github('ohdsi/Strategus', upgrade = "never"); library(Strategus)
if (!require("ROhdsiWebApi")) remotes::install_github('ohdsi/ROhdsiWebApi', upgrade = "never"); library(ROhdsiWebApi)
if (!require("CirceR")) install.packages('CirceR'); library(CirceR)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction', ref="develop", upgrade = "never", force = TRUE); library(PatientLevelPrediction)
if (!require("DeepPatientLevelPrediction")) remotes::install_github('ohdsi/DeepPatientLevelPrediction', upgrade = "never"); library(DeepPatientLevelPrediction)

# MODEL TRANSFER Module --------------------------------------------------------
source('https://raw.githubusercontent.com/OHDSI/ModelTransferModule/v0.0.10/SettingsFunctions.R')

s3Settings <- tibble(modelZipLocation = character(), bucket = character(), region = character()) |>
  add_row(modelZipLocation="dlc-output", bucket="s3://ohdsi-dlc/", region="eu-west-1")

modelTransferModuleSpecs <- createModelTransferModuleSpecifications(
  s3Settings = s3Settings
)

# COHORT GENERATOR MODULE ------------------------------------------------------
source("https://raw.githubusercontent.com/mi-erasmusmc/CohortGeneratorModule/v0.2.2/SettingsFunctions.R")

cohortIds <- list(dementia = list(target = 11931, outcome = 6243),
                  bipolar = list(target = 11454, outcome = 10461),
                  lungCancer = list(target = 11932, outcome = 298))

baseUrl <- keyring::key_get('webapi', 'baseurl')
ROhdsiWebApi::authorizeWebApi(
  baseUrl = baseUrl,
  authMethod = 'windows',
  webApiUsername = keyring::key_get('webapi', 'username'),
  webApiPassword = keyring::key_get('webapi', 'password')
)

cohortDefinitions <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = baseUrl,
  cohortIds = unlist(cohortIds),
  generateStats = F
)
# modify the cohort
cohortDefinitions <- lapply(1:length(cohortDefinitions$atlasId), function(i){list(
  cohortId = cohortDefinitions$cohortId[i],
  cohortName = cohortDefinitions$cohortName[i],
  cohortDefinition = cohortDefinitions$json[i]
)})

createCohortSharedResource <- function(cohortDefinitionSet) {
  sharedResource <- list(cohortDefinitions = cohortDefinitionSet)
  class(sharedResource) <- c("CohortDefinitionSharedResources", "SharedResources")
  return(sharedResource)
}

cohortGeneratorModuleSpecifications <- createCohortGeneratorModuleSpecifications(
  incremental = TRUE,
  generateStats = F
)

# UNIVERSAL ANALYSIS SETTINGS --------------------------------------------------

covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = T,
  useDemographicsAge = T,
  useConditionOccurrenceLongTerm  = T,
  useDrugEraLongTerm = T,
  useCharlsonIndex = T,
  longTermStartDays = -365,
  endDays = 0
)

source('https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionValidationModule/v0.0.11/SettingsFunctions.R')
source('https://raw.githubusercontent.com/OHDSI/DeepPatientLevelPredictionValidationModule/v0.0.3/SettingsFunctions.R')

validationComponentsList <- list(
  list(
    targetId = NULL, # use model setting
    oucomeId = NULL, # use model setting
    restrictPlpDataSettings = NULL, # use model setting
    validationSettings = PatientLevelPrediction::createValidationSettings(
      recalibrate = NULL, # use model setting
      runCovariateSummary = T
    ),
    populationSettings = NULL  
  )
)

predictionValidationModuleSpecifications <- createPatientLevelPredictionValidationModuleSpecifications(
  validationComponentsList = validationComponentsList
)

predictionValidationModuleSpecificationsDeep <- createDeepPatientLevelPredictionValidationModuleSpecifications(
  validationComponentsList = validationComponentsList
)

analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addModuleSpecifications(modelTransferModuleSpecs) |>
  addSharedResources(createCohortSharedResource(cohortDefinitions)) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  addModuleSpecifications(predictionValidationModuleSpecifications) |>
  addModuleSpecifications(predictionValidationModuleSpecificationsDeep)

ParallelLogger::saveSettingsToJson(analysisSpecifications, file.path('study_execution_jsons', 'dlc_validation_study.json'))
