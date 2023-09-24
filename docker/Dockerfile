FROM rocker/r-ver:4.2.3 as build

RUN apt-get -y update && apt-get install -y \
      default-jre \
      default-jdk \
      libxml2-dev \
      libglpk-dev \
      libsodium-dev \
      libsecret-1-dev \
      python3-pip \
      python3-venv \ 
      --no-install-recommends \
      && apt-get clean

WORKDIR /project
COPY renv.lock renv.lock

RUN mkdir -p renv
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# change default location of cache to project folder
RUN mkdir renv/.cache
ENV RENV_PATHS_CACHE /project/renv/.cache

RUN R cmd javareconf \
    && Rscript -e "renv::restore(confirm = FALSE)" \
    && Rscript -e "DatabaseConnector::downloadJdbcDrivers(dbms='all', pathToDriver='/database_drivers/')"

# initialize modules
COPY deep_comp_study.json deep_comp_study.json
COPY docker/initialiseModules.R initialiseModules.R
RUN Rscript initialiseModules.R

# Add xgboost to plpModule
COPY docker/addXGBoost.R addXGBoost.R
RUN Rscript -e "renv::run(script='addXGBoost.R',  project='/modules/PatientLevelPredictionModule_0.2.0')"

# set up python, without conda and pip caches
WORKDIR /modules/DeepPatientLevelPredictionModule_0.1.0/
ENV RETICULATE_MINICONDA_PATH=/opt/conda/
RUN Rscript -e "renv::activate('.')" \
    -e "reticulate::install_miniconda()" \
    -e "reticulate::conda_install(envname = 'r-reticulate', packages=c('python=3.10'))"

ENV PIP_NO_CACHE_DIR=1     
RUN Rscript -e "renv::restore()" \
    && rm -rf /root/.cache/R/renv \ 
    && /opt/conda/bin/conda clean -afy

FROM rocker/r-ver:4.2.3

COPY --from=build /project /project
COPY --from=build /modules /modules
COPY --from=build /opt/conda /opt/conda

# runtime dependanceis
RUN apt-get -y update && apt-get install -y \
      default-jre \
      libxml2 \
      libglpk40 \
      libsodium23 \
      libsecret-1-0 \ 
      --no-install-recommends \
      && R cmd javareconf \
      && apt-get clean

# create system keyring
WORKDIR /modules/DeepPatientLevelPredictionModule_0.1.0/
RUN Rscript -e "keyring::keyring_create('system', password='1234')"
ENV STRATEGUS_KEYRING_PASSWORD=1234

WORKDIR /project
COPY codeToRun.R codeToRun.R

# add user that owns the output folder
RUN groupadd -r user && useradd -g user -m user

RUN mkdir /output && chown -R user:user /output

USER user



