
if (!require("remotes")) install.packages("remotes"); library(remotes)
if (!require("dplyr")) install.packages("dplyr"); library(dplyr)
if (!require("Strategus")) remotes::install_github('ohdsi/Strategus@v0.1.0', upgrade = "never"); library(Strategus)
if (!require("PatientLevelPrediction")) remotes::install_github('ohdsi/PatientLevelPrediction@v6.3.5', upgrade = "never"); library(PatientLevelPrediction)
if (!require("DeepPatientLevelPrediction")) remotes::install_github('ohdsi/DeepPatientLevelPrediction@v2.0.2', upgrade = "never"); library(DeepPatientLevelPrediction)

################################################################################
# COHORTS ######################################################################
################################################################################

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
source("https://raw.githubusercontent.com/OHDSI/CohortGeneratorModule/v0.2.1/SettingsFunctions.R")
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
  sampleSize = NULL,
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

getDevice <- function() {
  dev <- Sys.getenv("deepPLPDevice")
  if(dev == "") {
    if (torch$cuda$is_available()) dev<-"cuda:0" else dev<-"cpu"
  }
  dev
}

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
    device = getDevice,
    epochs=5e1,
    seed=1e3,
    earlyStopping = list(useEarlyStopping=TRUE,
                         params = list(patience=4)))
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
    batchSize=2^9,
    learningRate = "auto",
    device = getDevice,
    epochs=5e1,
    seed=1e3,
    earlyStopping = list(useEarlyStopping=TRUE,
                         params = list(patience=4)))
)

classicModelSettings <- list(logisticRegressionModelSettings,
                               gradientBoostingModelSettings)

deepModelSettings <- list(
  resNetModelSettings ,
  transformerModelSettings
)

################################################################################
# MODEL DESIGNS ################################################################
################################################################################

deepModelDesignList <- list()
class(deepModelDesignList) <- 'leGrandeDesignListOfList'

classicModelDesignList <- list()
class(classicModelDesignList) <- 'leGrandeDesignListOfList'

# lung cancer deep
for (modelSetting in deepModelSettings) {
  deepModelDesignList <- append(
    deepModelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$lungCancer$target,
      outcomeId = cohortIds$lungCancer$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = lungCancerPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = deepPreprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# lung cancer classic
for (modelSetting in classicModelSettings) {
  classicModelDesignList <- append(
    classicModelDesignList,
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

# MDD bipolar 1-year deep
for (modelSetting in deepModelSettings) {
  deepModelDesignList <- append(
    deepModelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$bipolar$target,
      outcomeId = cohortIds$bipolar$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = bipolarPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = deepPreprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# MDD bipolar 1-year classic
for (modelSetting in classicModelSettings) {
  classicModelDesignList <- append(
    classicModelDesignList,
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



# dementia 5-year deep
for (modelSetting in deepModelSettings) {
  deepModelDesignList <- append(
    deepModelDesignList,
    list(PatientLevelPrediction::createModelDesign(
      targetId = cohortIds$dementia$target,
      outcomeId = cohortIds$dementia$outcome,
      restrictPlpDataSettings = restrictPlpDataSettings,
      populationSettings = dementiaPopulationSettings,
      covariateSettings = covariateSettings,
      featureEngineeringSettings = NULL,
      sampleSettings = NULL,
      preprocessSettings = deepPreprocessSettings,
      modelSettings = modelSetting,
      splitSettings = splitSettings,
      runCovariateSummary = T)
    )
  )
}

# dementia 5-year classic
for (modelSetting in classicModelSettings) {
  classicModelDesignList <- append(
    classicModelDesignList,
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
source("https://raw.githubusercontent.com/OHDSI/DeepPatientLevelPredictionModule/v0.2.0/SettingsFunctions.R")
source("https://raw.githubusercontent.com/OHDSI/PatientLevelPredictionModule/v0.2.1/SettingsFunctions.R")

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

# SAVING TO SHARE
ParallelLogger::saveSettingsToJson(analysisSpecifications, 'deep_comp_study.json')
