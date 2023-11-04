To build:

```docker build . -f docker/Dockerfile -t deeplearningcomparison```

You can also pull the latest version:

```docker pull docker.io/egillax/deeplearningcomparison```

NOTE: currently the image is on my personal repo but in future will be on an official OHDSI repo

To run, first populate ```secrets.env``` with your site specific info. 

To use GPUs with docker you need to install nvidia container toolkit. There are instructions here: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

Then you can run:

```docker run -it --env-file secrets.env --runtime=nvidia --gpus all -v /host/output/folder:/output egillax/deeplearningcomparison```

The host output folder needs to be a path where you want the results to be written

Then you are in an R session in the container and can run

```source('codeToRun.R')```

If you want to run this container with Podman on GPUs you need to use the container device interface which has instructions here:
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html

Then your command to run the container would be:

```podman run -it --device nvidia.com/gpu=all --security-opt=label=disable --env-file=secrets.env -v /host/output/folder:/output egillax/deeplearningcomparison```

If you want to run it using a different container runtime and need help please open an issue.