FROM rocker/rstudio:4.2.3 AS base

RUN apt-get -y update && apt-get install -y default-jre default-jdk \
      libxml2-dev \
      libglpk-dev \
      libsodium-dev \
      libsecret-1-dev
  
RUN R cmd javareconf

RUN R -e "install.packages('renv')"

WORKDIR /home/rstudio/project
COPY renv.lock renv.lock

RUN mkdir -p renv
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# change default location of cache to project folder
RUN mkdir renv/.cache
ENV RENV_PATHS_CACHE /home/rstudio/project/renv/.cache

RUN R -e "renv::restore()"

COPY . .