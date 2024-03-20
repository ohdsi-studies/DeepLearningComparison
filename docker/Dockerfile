FROM docker.io/rocker/r-ver:4.2.3 as build

RUN apt-get -y update && apt-get install -y \
      default-jre \
      default-jdk \
      libxml2-dev \
      libglpk-dev \
      libsodium-dev \
      libsecret-1-dev \
      python3-pip \
      python3-venv \
      libssl-dev  \
      --no-install-recommends \
      && apt-get clean

WORKDIR /project

# change default location of cache to project folder
RUN mkdir -p renv/.cache
ENV RENV_PATHS_CACHE /project/renv/.cache

RUN echo "options(repos=list(CRAN='https://packagemanager.posit.co/cran/__linux__/jammy/latest'))" >> /root/.Rprofile
COPY docker/setupProjectEnv.R setupProjectEnv.R
RUN R cmd javareconf &&  \
    Rscript setupProjectEnv.R 

RUN Rscript -e "DatabaseConnector::downloadJdbcDrivers(dbms='all', pathToDriver='/database_drivers/')"

# initialize modules
COPY study_execution_jsons/deep_comp_study.json deep_comp_study.json
COPY docker/initialiseModules.R initialiseModules.R
RUN Rscript initialiseModules.R

# set up python, without conda and pip caches
WORKDIR /modules/DeepPatientLevelPredictionModule_0.2.2/
ENV RETICULATE_MINICONDA_PATH=/opt/conda/
RUN Rscript -e "renv::activate('.')" \
    -e "reticulate::install_miniconda()" \
    -e "reticulate::conda_install(envname = 'r-reticulate', packages=c('python=3.10'))"

ENV PIP_NO_CACHE_DIR=1
RUN Rscript -e "renv::restore()" \
    && rm -rf /root/.cache/R/renv \
    && /opt/conda/bin/conda clean -afy

FROM docker.io/rocker/r-ver:4.2.3

COPY --from=build /project /project
COPY --from=build /modules /modules
COPY --from=build /opt/conda /opt/conda
COPY --from=build /database_drivers /database_drivers
COPY --from=build /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# runtime dependanceis
RUN apt-get -y update && apt-get install -y \
      default-jre \
      libxml2 \
      libglpk40 \
      libsodium23 \
      libsecret-1-0 \
      libssl3 \
      --no-install-recommends \
      && R cmd javareconf \
      && apt-get clean

RUN mkdir /output

# create system keyring
WORKDIR /project
RUN Rscript -e "install.packages('keyring')" && \
    Rscript -e "keyring::keyring_create('system', password='1234')"
ENV STRATEGUS_KEYRING_PASSWORD=1234

COPY codeToRun.R codeToRun.R


