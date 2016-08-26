# Heroku buildpack for PredictionIO

[PredictionIO](http://docs.prediction.io/start/) is an open source machine learning analytics application. 


Two apps are composed to make a basic PredictionIO service:

1. **Engine**: a specialized machine learning app which provides training of a model and then queries against that model; generated from a template or custom code.
2. **Eventserver**: a simple HTTP API app for capturing events to process from other systems; shareable between multiple engines.


## Create the Eventserver

```bash
git clone https://github.com/heroku/heroku-buildpack-pio.git pio-eventserver
cd pio-eventserver

heroku create my-eventserver-name
heroku addons:create heroku-postgresql:standard-0
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-pio.git
heroku buildpacks:add -i 2 https://github.com/heroku/spark-in-space.git
heroku buildpacks:add -i 3 heroku/scala

git push heroku master
```

* We specify a `standard-0` database, because the free `hobby-dev` database is limited to 10,000 records.

### Generate an app record on the eventserver

```bash
heroku run 'pio app new my-pio-app-name'
```

* The app name, ID, & access key will be needed in a later step.

### Find the eventserver's Postgresql add-on

```bash
heroku addons
```

* The `postgres-` ID will be needed in a later step.


## Create an Engine

[Install PredictionIO locally](http://predictionio.incubator.apache.org/install/) and [download an engine template](http://predictionio.incubator.apache.org/start/download/) from the [gallery](http://predictionio.incubator.apache.org/gallery/template-gallery/).

`cd` into the engine directory, and make it a git repo:

```bash
git init
```

### Create a Heroku app for the engine

```bash
heroku create my-engine-name
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-jvm-common.git
heroku buildpacks:add -i 2 https://github.com/heroku/heroku-buildpack-pio.git
heroku buildpacks:add -i 3 https://github.com/heroku/spark-in-space.git
```

### Configure the Heroku app to use the eventserver

Replace the Postgres ID & eventserver config values with those from above:

```bash
heroku addons:attach postgresql-name-XXXXX
heroku config:set PIO_EVENTSERVER_IP=my-eventserver-name PIO_EVENTSERVER_PORT=80 ACCESS_KEY=XXXXX APP_NAME=my-pio-app-name
```

### Deploy to Heroku

```bash
git push heroku master
```

### Import data

This step will vary based on the engine. See the template's docs for instructions.

### Train the model

```bash
heroku run bash --size Performance-M
cd pio-engine
pio train -- --driver-memory 2g
```

* We specify a larger, more expensive dyno size for training. Adjust the `--size` & `--driver-memory` flags to fit each other & your requirements.
