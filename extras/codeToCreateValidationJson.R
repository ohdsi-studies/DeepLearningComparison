
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("dplyr")) install.packages("dplyr"); library(dplyr)
if (!require("Strategus")) remotes::install_github('ohdsi/Strategus', upgrade = "never"); library(Strategus)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction', upgrade = "never"); library(PatientLevelPrediction)
if (!require("DeepPatientLevelPrediction")) remotes::install_github('ohdsi/DeepPatientLevelPrediction', upgrade = "never"); library(DeepPatientLevelPrediction)

options(renv.config.mran.enabled = FALSE)

# MODEL TRANSFER ----------------------------------------------------------

# library(Eunomia)
# connectionDetails <- getEunomiaConnectionDetails()
# Eunomia::createCohorts(connectionDetails)

source('https://raw.githubusercontent.com/OHDSI/ModelTransferModule/main/SettingsFunctions.R')

s3Settings <- data_frame(modelZipLocation = character(), bucket = character(), region = character()) |>
  add_row(modelZipLocation="ipci/ipci.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1") |>
  add_row(modelZipLocation="opehr/lr.zip", bucket="s3://ohdsi-dlc/", region="eu-west-1")
  
modelTransferModuleSpecs <- createModelTransferModuleSpecifications(
  s3Settings = s3Settings
)

# 
# analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
#   addModuleSpecifications(modelTransferModuleSpecs)
#   # addSharedResources(createCohortSharedResource(cohortDefinitions)) |>
#   # addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
#   # addModuleSpecifications(patientLevelPredictionModuleSpecifications)|>
#   # addModuleSpecifications(deepPatientLevelPredictionModuleSpecifications)
# 
# # SAVING TO SHARE
# ParallelLogger::saveSettingsToJson(analysisSpecifications, 'deep_comp_val_study.json')
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
#   restart=F
# )

# COHORTS -----------------------------------------------------------------

cohortIds <- list(dementia = list(target = 11931, outcome = 6243),
                  lungCancer = list(target = 11932, outcome = 298),
                  bipolar = list(target = 11454, outcome = 10461))

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

# bipolar
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


source('https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionValidationModule/main/SettingsFunctions.R')


predictionValidationModuleSpecifications <- createPatientLevelPredictionValidationModuleSpecifications()


# source the latest PatientLevelPredictionModule SettingsFunctions.R
source("https://raw.githubusercontent.com/OHDSI/DeepPatientLevelPredictionModule/v0.0.8/SettingsFunctions.R")
source("https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionModule/v0.1.0/SettingsFunctions.R")

# this will load a function called createPatientLevelPredictionModuleSpecifications
# that takes as input a modelDesignList
# createPatientLevelPredictionModuleSpecifications(modelDesignList)

# now we create a specification for the prediction module
# using the model designs list we define previously as input
deepPatientLevelPredictionModuleSpecifications <- createDeepPatientLevelPredictionModuleSpecifications(deepModelDesignList)
patientLevelPredictionModuleSpecifications <- createPatientLevelPredictionModuleSpecifications(classicModelDesignList)


# CREATING FULL STUDY SPEC
analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addSharedResources(createCohortSharedResource(cohortDefinitions)) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
 addModuleSpecifications(patientLevelPredictionModuleSpecifications)|>
  addModuleSpecifications(deepPatientLevelPredictionModuleSpecifications)

analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addModuleSpecifications(modelTransferModuleSpecs) |>
  addSharedResources(createCohortSharedResource(cohortDefinitions)) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  addModuleSpecifications(patientLevelPredictionModuleSpecifications)|>
  
  

# SAVING TO SHARE
ParallelLogger::saveSettingsToJson(analysisSpecifications, 'deep_comp_study.json')
