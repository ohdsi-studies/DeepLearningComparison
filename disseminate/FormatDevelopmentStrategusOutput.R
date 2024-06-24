library(dplyr)
library(tidyr)

getAllAuc <- function(strategusOutputPath) {
  
  combinedData <- NULL
  subdirs <- list.files(strategusOutputPath, full.names = TRUE)
  
  for (dir in subdirs) {
    folder <- basename(dir)
    print(basename(folder))
    
    allFiles <- list.files(dir, pattern = "models.csv", full.names = TRUE, recursive = TRUE)
    
    for(modelFilePath in allFiles) {
      # Assume the same naming pattern and location for database_details.csv and database_meta_data.csv
      directoryPath <- dirname(modelFilePath)
      databaseDetailsPath <- file.path(directoryPath, "database_details.csv")
      databaseMetaDataPath <- file.path(directoryPath, "database_meta_data.csv")
      evalDataPath <- file.path(directoryPath, "evaluation_statistics.csv")
      modelDesign <- file.path(directoryPath, "model_designs.csv")
      cohorts <- file.path(directoryPath, "cohorts.csv")
      
      # Read models.csv
      modelData <- read.csv(modelFilePath)
      databaseDetails <- read.csv(databaseDetailsPath)
      databaseMetaData <- read.csv(databaseMetaDataPath)
      evalData <- read.csv(evalDataPath)
      modelDesign <- read.csv(modelDesign)
      cohorts <- read.csv(cohorts)
      
      enrichedData <- merge(modelData, databaseDetails, by = "database_id")
      finalModelData <- merge(enrichedData, databaseMetaData, by.y = "database_id", by.x = "database_meta_data_id")
      finalModelData <- merge(finalModelData, modelDesign, by = "model_design_id")
      finalModelData <- merge(finalModelData, cohorts, by.x = "outcome_id", by.y = "cohort_id")
      
      evalData <- evalData %>%
        dplyr::filter(metric == "AUROC" | metric == "AUPRC" | metric == "Eavg", evaluation == "Test") %>%
        tidyr::pivot_wider(names_from = metric, values_from = value)
      
      finalModelData <- merge(finalModelData, evalData, by.x = "model_id", by.y = "performance_id")
      
      # Combine with previous iterations' data
      if(is.null(combinedData)) {
        combinedData <- finalModelData
      } else {
        combinedData <- rbind(combinedData, finalModelData)
      }
    }
  }
  
  finalSelectedData <- combinedData %>%
    select(database_meta_data_id, model_id, model_design_id, model_type, AUROC, AUPRC, Eavg, cohort_definition_id, cohort_name)
  # ensure development and validation database are the same for internal validation
  # finalSelectedData$validation <- finalSelectedData$cdm_source_abbreviation
  finalSelectedData$validation_database_meta_data_id <- finalSelectedData$database_meta_data_id
  
  return(finalSelectedData)
}