library(fs)

# begin inputs -----------------------------------------------------------------

plpDataPath <- ""
modelsParentFolder <- ""
device <- "cuda:0"
trainEventCount <- c(100, 200, 300, 400, 500, 600, 700, 800, 900, 1000,
                     1500, 2000, 2500, 3000, 5000, 7500, 10000)

# end inputs -------------------------------------------------------------------

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
        device = device
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
        device = device
      ),
      randomSample = 1
    )
  }
  
  plpData <- PatientLevelPrediction::loadPlpData(plpDataPath)
  
  # studyPopulation <- PatientLevelPrediction::createStudyPopulation(
  #   plpData = plpData,
  #   outcomeId = model$modelDesign$outcomeId,
  #   populationSettings = model$modelDesign$populationSettings
  # )
  
  splitSettings <- PatientLevelPrediction::createDefaultSplitSetting(
    splitSeed = model$modelDesign$splitSettings$seed,
    testFraction = model$modelDesign$splitSettings$test,
    nfold = model$modelDesign$splitSettings$nfold,
    trainFraction = model$modelDesign$splitSettings$train
  )
  
  learningCurve <- PatientLevelPrediction::createLearningCurve(
    plpData = plpData,
    outcomeId = model$modelDesign$outcomeId,
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
    ),
    learningCurveSettings = model$modelDesign$learningCurveSettings
  )
}
