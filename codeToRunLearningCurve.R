library(fs)
library(DeepPatientLevelPrediction)

# begin inputs -----------------------------------------------------------------

OpehrDataPaths <-c()
OpsesDataPaths <- c()

OpehrModels <- ""
OpsesModels <- ""

# chose which large database to run on
plpDataPath <- OpehrDataPaths

modelsParentFolder <- OpehrModels
device <- "cuda:0"
trainEventCount <- c(
  seq(100, 900, 100),
  seq(1000, 9000, 1000),
  seq(10000, 90000, 10000),
  seq(100000, 200000, 100000)
)

# end inputs -------------------------------------------------------------------

loadedData <- list()

modelPaths <- fs::dir_ls(path = modelsParentFolder, type = "directory", recurse = FALSE)

for (path in modelPaths) {
  model <- PatientLevelPrediction::loadPlpModel(path)
  
  pythonModel <- torch$load(
    file.path(model$model, "DeepEstimatorModel.pt"),
    map_location = "cpu"
  )
  
  if ("ResNet" == model$trainDetails$modelName) {
    modelSetting <- DeepPatientLevelPrediction::setResNet(
      numLayers = as.numeric(model$trainDetails$finalModelParameters$numLayers),
      sizeHidden = as.numeric(model$trainDetails$finalModelParameters$sizeHidden),
      hiddenFactor = as.numeric(model$trainDetails$finalModelParameters$hiddenFactor),
      residualDropout = as.numeric(model$trainDetails$finalModelParameters$residualDropout),
      hiddenDropout = as.numeric(model$trainDetails$finalModelParameters$hiddenDropout),
      sizeEmbedding = as.numeric(model$trainDetails$finalModelParameters$sizeEmbedding),
      estimatorSettings = DeepPatientLevelPrediction::setEstimator(
        weightDecay = as.numeric(model$trainDetails$finalModelParameters$estimator.weightDecay),
        learningRate = "auto",
        batchSize = as.numeric(pythonModel$estimator_settings$batch_size), 
        epochs = as.numeric(pythonModel$estimator_settings$epochs),
        device = device,
        earlyStopping = list(
          useEarlyStopping = TRUE,
          params = list(patience = 4)
        )
      ),
      randomSample = 1
    )
  } else if ("Transformer" == model$trainDetails$modelName) {
    modelSetting <- DeepPatientLevelPrediction::setTransformer(
      numBlocks = as.numeric(model$trainDetails$finalModelParameters$numBlocks),
      dimToken = as.numeric(model$trainDetails$finalModelParameters$dimToken),
      dimOut = as.numeric(model$trainDetails$finalModelParameters$dimOut),
      numHeads = as.numeric(model$trainDetails$finalModelParameters$numHeads),
      attDropout = as.numeric(model$trainDetails$finalModelParameters$attDropout),
      ffnDropout = as.numeric(model$trainDetails$finalModelParameters$ffnDropout),
      resDropout = as.numeric(model$trainDetails$finalModelParameters$resDropout),
      dimHidden = as.numeric(model$trainDetails$finalModelParameters$dimHidden),
      estimatorSettings = DeepPatientLevelPrediction::setEstimator(
        weightDecay = as.numeric(model$trainDetails$finalModelParameters$estimator.weightDecay),
        learningRate = "auto",
        batchSize = as.numeric(pythonModel$estimator_settings$batch_size), 
        epochs = as.numeric(pythonModel$estimator_settings$epochs),
        device = device,
        earlyStopping = list(
          useEarlyStopping = TRUE,
          params = list(patience = 4)
        )
      ),
      randomSample = 1
    )
  }
  
  for (i in seq_along(plpDataPath)) {
    loadedData[[i]] <- PatientLevelPrediction::loadPlpData(plpDataPath[i])
  }

  matchingIndex <- which(sapply(loadedData, function(data) {
    outcomeIds <- data$outcomes$outcomeId
    outcomeIds[1] == model$modelDesign$outcomeId
  }))
  
  splitSettings <- PatientLevelPrediction::createDefaultSplitSetting(
    splitSeed = model$modelDesign$splitSettings$seed,
    testFraction = model$modelDesign$splitSettings$test,
    nfold = model$modelDesign$splitSettings$nfold,
    trainFraction = model$modelDesign$splitSettings$train
  )
  
  saveDir <- file.path(paste0("learningCurve_", loadedData[[matchingIndex]]$metaData$databaseDetails$cdmDatabaseSchema,"_", model$trainDetails$modelName,"_", model$modelDesign$outcomeId))
  
  learningCurve <- PatientLevelPrediction::createLearningCurve(
    plpData = loadedData[[matchingIndex]],
    outcomeId = model$modelDesign$outcomeId,
    saveDirectory = saveDir,
    parallel = F,
    modelSettings = modelSetting,
    populationSettings = model$modelDesign$populationSettings,
    splitSettings = splitSettings,
    trainEvents = trainEventCount,
    sampleSettings = model$modelDesign$sampleSettings,
    featureEngineeringSettings = model$modelDesign$featureEngineeringSettings,
    preprocessSettings = model$modelDesign$preprocessSettings,
    executeSettings = PatientLevelPrediction::createExecuteSettings(
      runSplitData = T, # overriding the model settings
      runSampleData = F, # overriding the model settings
      runfeatureEngineering = F, # overriding the model settings
      runPreprocessData = T, # overriding the model settings
      runModelDevelopment = T, # overriding the model settings
      runCovariateSummary = F # dont need cov summary since it takes a long time
    )
  )
  saveRDS(
    learningCurve,
    file = file.path(
      saveDir,
      paste0("learningCurve_", loadedData[[matchingIndex]]$metaData$databaseDetails$cdmDatabaseSchema, model$trainDetails$modelName, "_O", model$modelDesign$outcomeId, ".rds")
      )
    )
}
