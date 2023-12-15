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
