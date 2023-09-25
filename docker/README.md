To build:

```docker build . -f docker/Dockerfile -t deeplearningcomparison```

To run, first populate ```secrets.env``` with your info. Then run:

```docker run -it --env-file secrets.env -v /host/output/folder:/output deeplearningcomparison```

The host output folder needs to be a path where you want the results to be written

Then you are in an R session and can run

```source('codeToRun.R')```

