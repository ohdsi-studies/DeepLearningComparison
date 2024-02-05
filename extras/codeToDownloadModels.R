library(dplyr)

# Sys.setenv(AWS_ACCESS_KEY_ID="")
# Sys.setenv(AWS_SECRET_ACCESS_KEY="")
# Sys.setenv(AWS_DEFAULT_REGION = "eu-west-1")

bucket <- "s3://ohdsi-dlc/"
region <- "eu-west-1"
s3Folder <- "dlc-output"

s3Settings <- tibble(modelZipLocation = character(), bucket = character(), region = character()) |>
  add_row(modelZipLocation=s3Folder, bucket=bucket, region=region)

saveFolder <- "~/Desktop/ohdsi-dlc-download-test"

# code that takes s3 details and download the models and returns the locations plus details as data.frame
getModelsFromS3 <- function(
    s3Settings,
    saveFolder
) {

  if(is.null(s3Settings)){
    return(NULL)
  }
  
  info <- data.frame()
  
  for(i in 1:nrow(s3Settings)){
    
    modelSaved <- F
    saveToLoc <- ''
    
    validBucket <- aws.s3::bucket_exists(
      bucket = s3Settings$bucket[i], 
      region = s3Settings$region[i]
    )
    
    if(validBucket){
      subfolder <- s3Settings$modelZipLocation[i]
      bucket <- s3Settings$bucket[i]
      region <- s3Settings$region[i]
      
      result <- aws.s3::get_bucket_df(bucket = bucket, region = region)
      paths <- fs::path(result$Key)
      
      workDir <- findWorkDir(bucket, subfolder, region)
      analyses <- findAnalysesNames(bucket, workDir, region)
      
      if(length(analyses) > 0) {
        if(!dir.exists(file.path(saveFolder, "models"))){
          dir.create(file.path(saveFolder, "models"), recursive = T)
        }
        saveToLoc <- file.path(saveFolder, "models")
        
        for (analysis in analyses) {
          analysis_paths <- paths[fs::path_has_parent(paths, fs::path(workDir, analysis))]
          
          for(obj in analysis_paths) {
            # split work directory from path
            relative_paths <- fs::path_rel(obj, start = workDir)
            # remove artifacts created by current path location
            filtered_paths <- relative_paths[relative_paths != "."]
            # Construct the file path where you want to save the file locally
            local_file_path <- fs::path(saveToLoc, filtered_paths)
            
            # Download the file from S3
            aws.s3::save_object(obj, bucket, file = local_file_path)
          }
          ParallelLogger::logInfo(paste0("Downloaded: ", analysis, " to ", saveToLoc))
        }
      } else{
        ParallelLogger::logInfo(paste0("No ",s3Settings$modelZipLocation[i]," in bucket ", s3Settings$bucket[i], " in region ", s3Settings$region[i] ))
      } 
    }else{
      ParallelLogger::logInfo(paste0("No bucket ", s3Settings$bucket[i] ," in region ", s3Settings$region[i]))
    }
    
    info <- rbind(
      info,
      data.frame(
        originalLocation = "PLACEHOLDER", 
        modelSavedLocally = TRUE, 
        localLocation = saveToLoc
      )
    )
    
  }
  
  return(info)
}


findWorkDir <- function(bucket, subfolder, region) {
  # list all content in the bucket
  result <- aws.s3::get_bucket_df(bucket = bucket, region = region)
  # extract paths of all content
  paths <- fs::path(result$Key)
  # split paths up for easier processing
  split_path <- fs::path_split(paths)
  
  # find the full path of the subfolder with models for validation
  results_sapply <- sapply(split_path, function(x) { 
    identical(tail(x, 1), subfolder) 
  })
  subfolder_path <- paths[results_sapply]
  
  return(subfolder_path)
}

findAnalysesNames <- function(bucket, workDir, region) {
  # list all content in the bucket
  result <- aws.s3::get_bucket_df(bucket = bucket, region = region)
  # extract paths of all content
  paths <- fs::path(result$Key)
  # filter for paths in work directory
  work_dir_paths <- paths[fs::path_has_parent(paths, workDir)]
  # split work directory from path
  relative_paths <- fs::path_rel(work_dir_paths, start = workDir)
  # remove artifacts created by current path location
  filtered_paths <- relative_paths[relative_paths != "."]
  # get only the top level directories
  top_level_dirs <- sapply(fs::path_split(filtered_paths), function(p) p[[1]])
  top_level_dirs <- unique(top_level_dirs)
  return(top_level_dirs)
}

# download all Strategus outputs
getModelsFromS3(s3Settings, saveFolder)

