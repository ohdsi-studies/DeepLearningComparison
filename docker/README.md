# Deep Learning Comparison - Docker

The study consists of three separate analyses that can be executed using Docker containers.
- **Table 1** - Produces Table 1 for a scientific article, providing a summary of demographic characteristics and comorbidities of the target populations.
- **Model Development** - Trains conventional and deep learning models for the target populations.
- **Model Validation** - Validates conventional and deep learning models that have been developed on other databases.

## Execute study
### Preparation
To run the analyses you must specify connection and execution parameters in a `secrets.env` file. This can be done by creating a text file named `secrets.env` or by downloading our template from [here](https://github.com/ohdsi-studies/DeepLearningComparison/blob/master/docker/secrets.env).  Below is the format for `secrets.env`, exemplified with a sample database configuration. 
```
DATABASE=ehr_database_v1234
DBMS=redshift
DATABASE_SERVER=database/ehr-v1234
DATABASE_USER=jdoe
DATABASE_PASSWORD=secret_password
DATABASE_PORT=5432
WORK_SCHEMA=jdoe_schema
STRATEGUS_COHORT_TABLE=strategus_cohort_table
TABLE1_COHORT_TABLE=table1_cohort_table
MIN_CELL_COUNT=5
CDM_SCHEMA=cdm_schema
```

### Run Table 1 Analysis
Download the latest version of the Table 1 Docker container.
```
docker pull ohdsi/deeplearningcomparison:table1_latest
```

To run the Table 1 Docker container, replace `/host/output/folder` with your desired output directory path, and `/host/secret/folder/secrets.env` with the path to your `secrets.env` file.
```
docker run -it --env-file /host/secret/folder/secrets.env -v /host/output/folder:/output deeplearningcomparison:table1_latest
```
Running the Docker container will open an R session. Execute the Table 1 analysis as follows.
```
source('codeToRunTable1.R')
```
In the output directory, the analysis may generate up to three files.
- `dementia.rds`
- `lungcancer.rds`
- `bipolar.rds`

These files contain the Table 1 information for each of the three target populations. If any of the files are missing, it likely indicates that your database lacks cases within one or more of the target populations. The existing output files can be opened in an R session as follows.
```
dementia_table1 <- readRDS('/host/output/folder/dementia.rds')
lungcancer_table1 <- readRDS('/host/output/folder/lungcancer.rds')
dbipolar_table1 <- readRDS('/host/output/folder/bipolar.rds')
```
Inspect the three files in your R environment before sharing them with us.

### Run Model Development

Docker containers are available for 

To build (if needed - better to pull the created image):

```docker build . -f docker/Dockerfile -t deeplearningcomparison```

You can pull the latest version:

```docker pull docker.io/ohdsi/deeplearningcomparison:latest```

To run, first populate a file ```secrets.env``` with your site specific info. See example in docker directory.

To use GPUs with docker you need to install nvidia container toolkit. There are instructions here:
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

Then you can run:

```docker run -it --env-file secrets.env --runtime=nvidia --gpus all -v /host/output/folder:/output ohdsi/deeplearningcomparison:latest```

The host output folder needs to be a path where you want the results to be written

Then you are in an R session in the container and can run

```source('codeToRun.R')```

By default the container will try to access `cuda:0`. If you instead want to run it on a specific gpu then you can use the environment variable `CUDA_VISIBLE_DEVICES` to select the device, for example to use `cuda:1`:

```CUDA_VISIBLE_DEVICE=1 docker run -it --env-file secrets.env --runtime=nvidia --gpus all -v /host/output/folder:/output ohdsi/deeplearningcomparison:latest```

If you want to run this container with Podman on GPUs you need to use the container device interface which has instructions here:
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html

Then your command to run the container would be:

```podman run -it --device nvidia.com/gpu=all --security-opt=label=disable --env-file=secrets.env -v /host/output/folder:/output ohdsi/deeplearningcomparison```

If you want to run it using a different container runtime and need help please open an issue.

### Run Model Validation
