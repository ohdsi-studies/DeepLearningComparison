
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("dplyr")) install.packages("dplyr"); library(dplyr)
if (!require("Strategus")) remotes::install_github('ohdsi/Strategus', upgrade = "never"); library(Strategus)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction', upgrade = "never"); library(PatientLevelPrediction)
if (!require("DeepPatientLevelPrediction")) remotes::install_github('ohdsi/DeepPatientLevelPrediction', upgrade = "never"); library(DeepPatientLevelPrediction)
if (!require("Eunomia")) remotes::install_github('ohdsi/Eunomia', upgrade = "never"); library(Eunomia)

options(renv.config.mran.enabled = FALSE)

# MODEL TRANSFER ----------------------------------------------------------


source('https://raw.githubusercontent.com/OHDSI/ModelTransferModule/v0.0.7/SettingsFunctions.R')

s3Settings <- tibble(modelZipLocation = character(), bucket = character(), region = character()) |>
  add_row(modelZipLocation="lungcancer/ipci/lr.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ipci/gb.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ipci/rn.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ipci/tf.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opehr/lr.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opehr/gb.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opehr/rn.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opehr/tf.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opses/lr.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opses/gb.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opses/rn.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/opses/tf.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ausom/lr.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ausom/gb.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ausom/rn.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="lungcancer/ausom/tf.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1")
  
modelTransferModuleSpecs <- createModelTransferModuleSpecifications(
  s3Settings = s3Settings
)


# DEBUG MODEL TRANSFER MODULE ---------------------------------------------



# library(Eunomia)
# connectionDetails <- getEunomiaConnectionDetails()
# 
# analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
#   addModuleSpecifications(modelTransferModuleSpecs)
# 
# # reference for the connection used by Strategus
# database <- 'databaseName' # your database name
# connectionDetailsReference <- paste0("DeepLearningComparison_", database)
# Strategus::storeConnectionDetails(
#   connectionDetails = connectionDetails,
#   connectionDetailsReference = connectionDetailsReference
# )
# 
# # name of cohort table for study
# cohortTable <- "strategus_cohort_table"
# 
# workDirectory <- getwd()
# outputFolder <- file.path(workDirectory, "outputFolder")
# 
# executionSettings <- Strategus::createCdmExecutionSettings(
#   connectionDetailsReference = connectionDetailsReference,
#   workDatabaseSchema = "main",
#   cdmDatabaseSchema = "main",
#   cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTable),
#   workFolder = file.path(workDirectory, "strategusWork"),
#   resultsFolder = file.path(workDirectory, "strategusOutput"),
#   minCellCount = 5
# )
# 
# Sys.setenv("INSTANTIATED_MODULES_FOLDER" = 'moduleLocation')
# 
# Strategus::execute(
#   analysisSpecifications = analysisSpecifications,
#   executionSettings = executionSettings,
#   executionScriptFolder = file.path(workDirectory, "strategusExecution"),
#   restart=F,
#   keyringName = NULL
# )

# COHORTS -----------------------------------------------------------------

cohortIds <- list(lungCancer = list(target = 11932, outcome = 298))

# EXTRACTING COHORTS
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


# COHORT GENERATION SETTINGS

# source the cohort generator settings function
source("https://raw.githubusercontent.com/OHDSI/CohortGeneratorModule/v0.1.0/SettingsFunctions.R")
# this loads a function called createCohortGeneratorModuleSpecifications that takes as
# input incremental (boolean) and generateStats (boolean)

# specify the inputs to create the cohort generator specification
cohortGeneratorModuleSpecifications <- createCohortGeneratorModuleSpecifications(
  incremental = TRUE,
  generateStats = F
)

# UNIVERSAL ANALYSIS SETTINGS ---------------------------------------------

covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = T,
  useDemographicsAge = T,
  useConditionOccurrenceLongTerm  = T,
  useDrugEraLongTerm = T,
  useCharlsonIndex = T,
  longTermStartDays = -365,
  endDays = 0
)

restrictPlpDataSettings <- createRestrictPlpDataSettings(
  sampleSize = 1e6,
)

splitSettings <- createDefaultSplitSetting(
  testFraction = .25,
  trainFraction = .75,
  nfold = 3,
  splitSeed = 123,
  type = 'stratified'
)

preprocessSettings <- createPreprocessSettings(
  minFraction = 1e-3,
  normalize = TRUE,
  removeRedundancy = TRUE
)

deepPreprocessSettings <- createPreprocessSettings(
  minFraction = 1e-3,
  normalize = TRUE,
  removeRedundancy = TRUE
)

#  POPULATION SETTINGS ----------------------------------------------------

# lung cancer
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

source('https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionValidationModule/main/SettingsFunctions.R')

validationComponentsList <- list(
  list(
    targetId = cohortIds$lungcancer$target,
    oucomeId = cohortIds$lungcancer$outcome,
    restrictPlpDataSettings = restrictPlpDataSettings, # vector
    validationSettings = PatientLevelPrediction::createValidationSettings(
      recalibrate = NULL,
      runCovariateSummary = T
    ),
    populationSettings = lungCancerPopulationSettings  
  )
)

predictionValidationModuleSpecifications <- createPatientLevelPredictionValidationModuleSpecifications(
  validationComponentsList = validationComponentsList
)

analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addModuleSpecifications(modelTransferModuleSpecs) |>
  addSharedResources(createCohortSharedResource(cohortDefinitions)) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  addModuleSpecifications(predictionValidationModuleSpecifications)

# SAVING TO SHARE
ParallelLogger::saveSettingsToJson(analysisSpecifications, 'deep_comp_lungcancer_val_study.json')

