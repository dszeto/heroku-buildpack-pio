# Heroku buildpack for PredictionIO

[PredictionIO](http://docs.prediction.io/start/) is an open source machine learning analytics application. 


Two apps are composed to make a basic PredictionIO service:

1. **Engine**: a specialized machine learning app which provides training of a model and then queries against that model; generated from a [template](http://predictionio.incubator.apache.org/gallery/template-gallery/) or [custom code](http://predictionio.incubator.apache.org/customize/).
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
```

* We specify a `standard-0` database, because the free `hobby-dev` database is limited to 10,000 records.

### Deploy the eventserver

We delay deployment until the database is ready.

```bash
heroku pg:wait && git push heroku master
```

### Generate an app record on the eventserver

```bash
heroku run 'pio app new my-pio-app-name'
```

* The app name, ID, & access key will be needed in a later step.

### Find the eventserver's Postgresql add-on

Look for the add-on identifier, like `postgresql-aerodynamic-00000`.

```bash
heroku addons
```

* The identifier will be needed in a later step


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
heroku config:set PIO_EVENTSERVER_IP=my-eventserver-name.herokuapp.com PIO_EVENTSERVER_PORT=80 ACCESS_KEY=XXXXX APP_NAME=my-pio-app-name
```

### Update `engine.json`

Modify this file to make sure the `appName` parameter matches the app record [created in the eventserver](#generate-an-app-record-on-the-eventserver).

```json
  "datasource": {
    "params" : {
      "appName": "my-pio-app-name"
    }
  }
```

* If the `appName` param is missing, you may need to [upgrade the template](http://predictionio.incubator.apache.org/resources/upgrade/).

### Import data

This step will vary based on the engine. See the template's docs for instructions.

### Deploy to Heroku

```bash
git add .
git commit -m "Initial PIO engine"
git push heroku master
```

### Train the model

#### Automatic training

`pio train` will automatically run during [release-phase of the Heroku app](https://devcenter.heroku.com/articles/release-phase).

The release dyno size should be set to a larger dyno, like Performance-L:

```bash
heroku ps:scale release=0:Performance-L
```

Auto training may be disabled with:

```bash
heroku config:set PIO_TRAIN_ON_RELEASE=false
```

#### Manual training

```bash
heroku run train --size Performance-L

# If this was the first training, revive the app from "crashed" state.
heroku restart
```

* We specify a larger, more expensive dyno size for training. Adjust the `--size` & `--driver-memory` flags to fit each other & your requirements.

#### Configure training

Pass additional options for:

* **pio** set `PIO_TRAIN_OPTS`
  * example: `heroku config:set PIO_OPTS='--variant engine-b.json'`
* **spark-submit** set `PIO_TRAIN_SPARK_OPTS`
  * example: `heroku config:set PIO_TRAIN_SPARK_OPTS='--driver-memory 12g'`

### Running commands

`pio` commands that require DB access will need to have the driver specified as an argument (bug with PIO 0.9.5 + Spark 1.6.1):

```bash
pio ${command} -- --driver-class-path /app/lib/postgresql_jdbc.jar
```

#### To run directly with Heroku CLI

```bash
heroku run "cd pio-engine && pio ${command} -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

#### Useful commands

Check engine status:

```bash
heroku run "cd pio-engine && pio status -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

