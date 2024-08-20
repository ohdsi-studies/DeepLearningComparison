# Deep Learning Comparison - Docker {#deep-learning-comparison---docker}

The study consists of three separate analyses that can be executed using Docker containers. - **Table 1** - Produces Table 1 for a scientific article, providing a summary of demographic characteristics and comorbidities of the target populations. - **Model Development** - Trains conventional and deep learning models for the target populations. - **Model Validation** - Validates conventional and deep learning models that have been developed on other databases.

## Content

-   [Deep Learning Comparison - Docker](#deep-learning-comparison---docker)
    -   [Preparation](#preparation)
        -   [Connection and execution details](#connection-and-execution-details)
        -   [Hardware acceleration](#hardware-acceleration)
    -   [Execute study](#execute-study)
        -   [Run Table 1 Analysis](#run-table-1-analysis)
        -   [Run Model Development](#run-model-development)
        -   [Run Model Validation](#run-model-validation)
    -   [Share results](#share-results)

## Preparation {#preparation}

### Connection and execution details {#connection-and-execution-details}

To run the analyses you must specify connection and execution parameters in a `secrets.env` file. This can be done by creating a text file named `secrets.env` or by downloading our template from [here](https://github.com/ohdsi-studies/DeepLearningComparison/blob/master/docker/secrets.env). Below is the format for `secrets.env`, exemplified with a sample database configuration.

```         
DATABASE=ehr_database_v1234
DBMS=redshift
DATABASE_SERVER=database/ehr-v1234
DATABASE_USER=jdoe
DATABASE_PASSWORD=secret_password
DATABASE_PORT=5432
DATABASE_CONNECTION_STRING=
DATABASE_TEMP_SCHEMA=
WORK_SCHEMA=jdoe_schema
STRATEGUS_COHORT_TABLE=strategus_cohort_table
MIN_CELL_COUNT=5
CDM_SCHEMA=cdm_schema

# only required for table 1
TABLE1_COHORT_TABLE=table1_cohort_table
```

Leave those fields empty that you don't use when connecting to your database.

### Hardware acceleration {#hardware-acceleration}

We recommend to execute the study on a GPU as this will significantly reduce execution time.

To enable GPU support with Docker, please install the NVIDIA Container Toolkit by following the instructions here: <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>

If using Podman with GPUs, refer to the Container Device Interface guidelines here: <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html>

## Execute study {#execute-study}

### Run Table 1 Analysis {#run-table-1-analysis}

Download the latest version of the Table 1 Docker container.

```         
docker pull ohdsi/deeplearningcomparison:table1_latest
```

To run the Table 1 Docker container, replace `/host/output/folder` with your desired output directory path, and `/host/secret/folder/secrets.env` with the path to your `secrets.env` file.

```         
docker run -it --env-file /host/secret/folder/secrets.env -v /host/output/folder:/output ohdsi/deeplearningcomparison:table1_latest
```

Running the Docker container will open an R session. Execute the Table 1 analysis as follows.

```         
source('codeToRunTable1.R')
```

In the output directory, the analysis may generate up to three files. - `dementia.rds` - `lungcancer.rds` - `bipolar.rds`

These files contain the Table 1 information for each of the three target populations. If any of the files are missing, it likely indicates that your database lacks cases within one or more of the target populations. The existing output files can be opened in an R session as follows.

```         
dementia_table1 <- readRDS('/host/output/folder/dementia.rds')
lungcancer_table1 <- readRDS('/host/output/folder/lungcancer.rds')
bipolar_table1 <- readRDS('/host/output/folder/bipolar.rds')
```

Inspect the three files in your R environment before sharing them with us as described [here](#share-results).

### Run Model Development {#run-model-development}

Download the latest version of the Development Docker container.

```         
docker pull docker.io/ohdsi/deeplearningcomparison:latest
```

To run the Validation Docker container, replace `/host/output/folder` with your desired output directory path, and `/host/secret/folder/secrets.env` with the path to your `secrets.env` file.

```         
docker run -it --env-file secrets.env --runtime=nvidia --gpus all -v /host/output/folder:/output ohdsi/deeplearningcomparison:latest
```

Running the Docker container will open an R session. Execute the Development analysis as follows.

```         
source('codeToRun.R')
```

By default the container will try to access `cuda:0`. If you instead want to run it on a specific gpu then you can use the environment variable `CUDA_VISIBLE_DEVICES` to select the device, for example to use `cuda:1`:

`CUDA_VISIBLE_DEVICE=1 docker run -it --env-file secrets.env --runtime=nvidia --gpus all -v /host/output/folder:/output ohdsi/deeplearningcomparison:latest`

Then your command to run the container would be:

`podman run -it --device nvidia.com/gpu=all --security-opt=label=disable --env-file=secrets.env -v /host/output/folder:/output ohdsi/deeplearningcomparison`

If you want to run it using a different container runtime and need help please open an issue.

In the output directory, the analysis generates three folders. Compress and share the `strategusOutput` folder as described [here](#share-results).

### Run Model Validation {#run-model-validation}

Download the latest version of the Validation Docker container.

```         
docker pull docker.io/ohdsi/deeplearningcomparison_validation:latest
```

To run the Validation Docker container, replace `/host/validation/output/folder` with your desired validation output directory path, and `/host/secret/folder/secrets.env` with the path to your `secrets.env` file. Ensure that this validation output directory is different from the output directory used for the model development analysis.

There are various run configurations possible:

1.  Run on the default GPU with the NVIDIA runtime. Refer back to the hardware acceleration section for more information on how to set up GPU support [here](#hardware-acceleration).

```         
docker run -it --env-file /host/secret/folder/secrets.env --runtime=nvidia --gpus all -v /host/validation/output/folder:/output ohdsi/deeplearningcomparison_validation:latest
```

2.  Explicitly specify the GPU to run on.

```         
docker run -it --env-file /host/secret/folder/secrets.env
--runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=1 -v /host/validation/output/folder:/output
ohdsi/deeplearningcomparison_validation:latest
```

3.  Run on CPU by not providing the NVIDIA runtime.

```         
docker run -it --env-file /host/secret/folder/secrets.env -v /host/validation/output/folder:/output
ohdsi/deeplearningcomparison_validation:latest
```

The container can also be executed on different container runtimes such as Podman.

```         
podman run -it --device nvidia.com/gpu=all --security-opt=label=disable --env-file=/host/secret/folder/secrets.env -v /host/validation/output/folder:/output ohdsi/deeplearningcomparison_validation:latest
```

Running the Docker container will open an R session. Execute the Validation analysis as follows.

```         
source('codeToRunValidation.R')
```

In the validation output directory, the analysis generates three folders. Compress and share the `strategusOutput` folder as described [here](#share-results).

## Share Results {#share-results}

The result files are generated using the OHDSI pipeline, which ensures that only non-identifying data is included in the output files. Nevertheless, before sharing any results with us, we kindly ask you to double-check that the files do not contain any data that you are not permitted to share. To securely share the results with the study coordinator, we use the `OhdsiSharing` R package. We suggest to compress multiple result files into a Zip archive.

Install the `OhdsiSharing` package:

```         
library(remotes)
remotes::install_github("ohdsi/OhdsiSharing")
library(OhdsiSharing)
```

Use the following code to upload the results to the OHDSI SFTP server. Please contact us to receive the data site public key.

```         
dataSiteKey <- "/path/to/public-key/study-data-site-dlc" # path to the data site public key
userName <- "study-data-site-dlc" # the user name to access the SFTP server
fileName <- "/path/to/results.zip" # the path to the results to be shared
remoteFolder <- "your-site-name" # a name to identify your site or database

OhdsiSharing::sftpUploadFile(
  privateKeyFileName = dataSiteKey,
  userName = userName,
  fileName = fileName,
  remoteFolder = remoteFolder
)
```
