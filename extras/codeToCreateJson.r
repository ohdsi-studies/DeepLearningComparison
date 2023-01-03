library(Strategus) # remotes::install_github('ohdsi/Strategus')
library(PatientLevelPrediction) # remotes::install_github('ohdsi/PatientLevelPrediction')
library(DeepPatientLevelPrediction) # remotes::install_github('ohdsi/DeepPatientLevelPrediction')
library(dplyr)

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
  cohortIds = c(301, 298, 10460, 10461, 9938, 6243),
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


# PREDICTION SETTINGS
covariateSettings <- FeatureExtraction::createCovariateSettings(
  useDemographicsGender = T,
  useDemographicsAgeGroup = T, #PLP age group
  useConditionGroupEraLongTerm  = T,
  useDrugGroupEraLongTerm = T,
)

modelDesignList <- list()
length(modelDesignList) <- 9

# lung cancer
modelDesignList[[1]] <- PatientLevelPrediction::createModelDesign(
  targetId = 301,
  outcomeId = 289,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*3,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultTransformer(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[2]] <- PatientLevelPrediction::createModelDesign(
  targetId = 301,
  outcomeId = 289,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*3,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultResNet(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[3]] <- PatientLevelPrediction::createModelDesign(
  targetId = 301,
  outcomeId = 289,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*3,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = PatientLevelPrediction::setLassoLogisticRegression(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

# MDD bipolar 1-year
modelDesignList[[4]] <- PatientLevelPrediction::createModelDesign(
  targetId = 10460,
  outcomeId = 10461,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 1*365,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultTransformer(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[5]] <- PatientLevelPrediction::createModelDesign(
  targetId = 10460,
  outcomeId = 10461,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*1,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultResNet(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[6]] <- PatientLevelPrediction::createModelDesign(
  targetId = 10460,
  outcomeId = 10461,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*1,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = PatientLevelPrediction::setLassoLogisticRegression(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)


# dementia 5-year
modelDesignList[[7]] <- PatientLevelPrediction::createModelDesign(
  targetId = 9938, 
  outcomeId = 6243,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 5*365,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultTransformer(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[8]] <- PatientLevelPrediction::createModelDesign(
  targetId = 9938, 
  outcomeId = 6243,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*5,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = DeepPatientLevelPrediction::setDefaultResNet(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

modelDesignList[[9]] <- PatientLevelPrediction::createModelDesign(
  targetId = 9938, 
  outcomeId = 6243,
  restrictPlpDataSettings = createRestrictPlpDataSettings(),
  populationSettings = createStudyPopulationSettings(
    removeSubjectsWithPriorOutcome = T,
    priorOutcomeLookback = 99999,
    requireTimeAtRisk = T,
    minTimeAtRisk = 1,
    riskWindowStart = 1,
    startAnchor = 'cohort start',
    riskWindowEnd = 365*5,
    endAnchor = 'cohort start'
  ),
  covariateSettings = covariateSettings,
  featureEngineeringSettings = NULL,
  sampleSettings = NULL,
  preprocessSettings = createPreprocessSettings(),
  modelSettings = PatientLevelPrediction::setLassoLogisticRegression(),
  splitSettings = createDefaultSplitSetting(),
  runCovariateSummary = T
)

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

