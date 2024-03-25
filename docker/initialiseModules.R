json <- paste(readLines("./study_execution_jsons/deep_comp_study.json"), collapse = "\n")
analysisSpecifications <- ParallelLogger::convertJsonToSettings(json)
Sys.setenv("INSTANTIATED_MODULES_FOLDER" = "/modules")
Strategus::ensureAllModulesInstantiated(analysisSpecifications)
