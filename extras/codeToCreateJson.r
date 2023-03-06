
rstudioapi::restartSession()
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("dplyr")) install.packages("dplyr"); library(dplyr)
if (!require("Strategus")) remotes::install_github('ohdsi/Strategus', upgrade = "never"); library(Strategus)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction', upgrade = "never"); library(PatientLevelPrediction)
if (!require("DeepPatientLevelPrediction")) remotes::install_github('ohdsi/DeepPatientLevelPrediction', ref = "develop", upgrade = "never"); library(DeepPatientLevelPrediction)

################################################################################
# COHORTS ######################################################################
################################################################################

cohortIds <- list(dementia = list(target = 11762, outcome = 6243),
                  lungCancer = list(target = 11765, outcome = 298),
                  bipolar = list(target = 10460, outcome = 10461))

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


# COHOT GENERATION SETTINGS

# source the cohort generator settings function
source("https://raw.githubusercontent.com/OHDSI/CohortGeneratorModule/v0.0.13/SettingsFunctions.R")
# this loads a function called createCohortGeneratorModuleSpecifications that takes as
# input incremental (boolean) and generateStats (boolean)

# specify the inputs to create the cohort generator specification
cohortGeneratorModuleSpecifications <- createCohortGeneratorModuleSpecifications(
  incremental = TRUE,
  generateStats = F
)

################################################################################
# UNIVERSAL ANALYSIS SETTINGS ##################################################
################################################################################

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
################################################################################
# POPULATION SETTINGS ##########################################################
################################################################################

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

################################################################################
# MODEL SETTINGS ###############################################################
################################################################################

logisticRegressionModelSettings <- setLassoLogisticRegression(
  seed = 1e3
)

gradientBoostingModelSettings <- setGradientBoostingMachine(
  seed = 1e3
)

multiLayerPerceptronModelSettings <- setMultiLayerPerceptron(
  seed = 1e3,
  sizeEmbedding = 2^(6:9),
  numLayers = 1:8,
  sizeHidden = 2^(6:10),
  dropout = seq(0, 3e-1, 5e-2),
  weightDecay = c(1e-6, 1e-3),
  learningRate = "auto",
  device = 'cuda:0',
  hyperParamSearch = 'random',
  randomSample = 1e2,
  randomSampleSeed = 123,
  batchSize = 2^10,
  epochs = 50
)

resNetModelSettings <- setResNet(
  sizeEmbedding = 2^(6:9),
  numLayers = 1:8,
  sizeHidden = 2^(6:10),
  hiddenFactor = 1:4,
  hiddenDropout = seq(0, 3e-1, 5e-2),
  residualDropout = seq(0, 3e-1, 5e-2),
  hyperParamSearch = 'random',
  randomSample = 1e2,
  randomSampleSeed = 123,
  estimatorSettings = setEstimator(
    weightDecay = c(1e-6, 1e-3),
    batchSize=5*2^10,
    learningRate = "auto",
    device = "cuda:0",
    epochs=5e1,
    seed=1e3,
    earlyStopping = list(useEarlyStopping=TRUE,
                         params = list(patience=6)))
)

transformerModelSettings <- setTransformer(
  numBlocks = 2:4,
  dimToken = 2^(6:9),
  dimOut = 1,
  numHeads = c(2, 4, 8),
  attDropout = seq(0, 3e-1, 5e-2),
  ffnDropout = seq(0, 3e-1, 5e-2),
  resDropout = seq(0, 3e-1, 5e-2),
  dimHidden = NULL,
  dimHiddenRatio = 4/3,
  hyperParamSearch = 'random',
  randomSample = 1e2,
  randomSampleSeed = 123,
  estimatorSettings = setEstimator(
    weightDecay = c(1e-6, 1e-3),
    batchSize=2^10,
    learningRate = "auto",
    device = 'cuda:0',
    epochs=5e1,
    seed=1e3,
    earlyStopping = list(useEarlyStopping=TRUE,
                         params = list(patience=6)))
)

modelSettings <- list(
  logisticRegressionModelSettings,
  gradientBoostingModelSettings,
  multiLayerPerceptronModelSettings,
  resNetModelSettings,
  transformerModelSettings
)

################################################################################
# MODEL DESIGNS ################################################################
################################################################################

modelDesignList <- list()
class(modelDesignList) <- 'leGrandeDesignListOfList'

# lung cancer
for (modelSetting in modelSettings) {
  modelDesignList <- append(
    modelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$lungCancer$target,
      outcomeId = cohortIds$lungCancer$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = lungCancerPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = preprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# MDD bipolar 1-year
for (modelSetting in modelSettings) {
  modelDesignList <- append(
    modelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$bipolar$target,
      outcomeId = cohortIds$bipolar$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = bipolarPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = preprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# dementia 5-year
for (modelSetting in modelSettings) {
  modelDesignList <- append(
    modelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$dementia$target,
      outcomeId = cohortIds$dementia$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = dementiaPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = preprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# source the latest PatientLevelPredictionModule SettingsFunctions.R
source("https://raw.githubusercontent.com/OHDSI/DeepPatientLevelPredictionModule/v0.0.1/SettingsFunctions.R")

# this will load a function called createPatientLevelPredictionModuleSpecifications
# that takes as input a modelDesignList
# createPatientLevelPredictionModuleSpecifications(modelDesignList)

# now we create a specification for the prediction module
# using the model designs list we define previously as input
patientLevelPredictionModuleSpecifications <- createDeepPatientLevelPredictionModuleSpecifications(modelDesignList)


# CREATING FULL STUDY SPEC
analysisSpecifications <- createEmptyAnalysisSpecificiations() %>%
  addSharedResources(createCohortSharedResource(cohortDefinitions)) %>%
  addModuleSpecifications(cohortGeneratorModuleSpecifications) %>%
  addModuleSpecifications(patientLevelPredictionModuleSpecifications)

# SAVING TO SHARE
ParallelLogger::saveSettingsToJson(analysisSpecifications, '/Users/jreps/Documents/GitHub/DeepLearningComparison/deep_comp_study.json')







# RUNNING JSON SPEC
# load the json spec
analysisSpecifications <- ParallelLogger::loadSettingsFromJson('<location to json file>')

connectionDetailsReference <- "Example"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = keyring::key_get('dbms', 'all'),
  server = keyring::key_get('server', 'ccae'),
  user = keyring::key_get('user', 'all'),
  password = keyring::key_get('pw', 'all'),
  port = keyring::key_get('port', 'all')#,
)

workDatabaseSchema <- keyring::key_get('workDatabaseSchema', 'all')
cdmDatabaseSchema <- keyring::key_get('cmdDatabaseSchema', 'ccae')

outputLocation <- '/Users/jreps/Documents/plp_example'
minCellCount <- 5
cohortTableName <- "strategus_example1"

##=========== END OF INPUTS ==========

storeConnectionDetails(
  connectionDetails = connectionDetails,
  connectionDetailsReference = connectionDetailsReference
)

executionSettings <- createExecutionSettings(
  connectionDetailsReference = connectionDetailsReference,
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, "strategusWork"),
  resultsFolder = file.path(outputLocation, "strategusOutput"),
  minCellCount = minCellCount
)

# Note: this environmental variable should be set once for each compute node
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = file.path(outputLocation, "StrategusInstantiatedModules"))

execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  executionScriptFolder = file.path(outputLocation, "strategusExecution")
)

