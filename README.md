# Heroku buildpack for PredictionIO

[PredictionIO](http://predictionio.incubator.apache.org) is an open source machine learning framework. 


Two apps are composed to make a basic PredictionIO service:

1. **Engine**: a specialized machine learning app which provides training of a model and then queries against that model; generated from a [template](https://predictionio.incubator.apache.org/gallery/template-gallery/) or [custom code](https://predictionio.incubator.apache.org/customize/).
2. **Eventserver**: a simple HTTP API app for capturing events to process from other systems; shareable between multiple engines.


## Docs 📚

✏️ Throughout these docs, code terms that start with `$` represent a value (shell variable) that should be replaced with a customized value, e.g `$eventserver_name`, `$engine_name`, `$postgres_addon_id`…

* [Heroku architectures](#heroku-architectures)
  * [Cluster on Heroku Enterprise](#cluster-on-heroku-enterprise)
    1. [Apps created in the Space](#apps-created-in-the-space)
    1. [Database in the Common Runtime](#database-in-the-common-runtime)
    1. [Set Spark master on an engine](#set-spark-master-on-an-engine)
  * [Single dyno on Common Runtime](#single-dyno-on-common-runtime)
* [Eventserver](#eventserver)
  1. [Create the eventserver](#create-the-eventserver)
  1. [Deploy the eventserver](#deploy-the-eventserver)
* [Engine](#engine)
  1. [Create an engine](#create-an-engine)
  1. [Create a Heroku app for the engine](#create-a-heroku-app-for-the-engine)
  1. [Create a PredictionIO app in the eventserver](#create-a-predictionio-app-in-the-eventserver)
  1. [Configure the Heroku app to use the eventserver](#configure-the-heroku-app-to-use-the-eventserver)
  1. [Update `engine.json`](#update-engine-json)
  1. [Import data](#import-data)
  1. [Deploy to Heroku](#deploy-to-heroku)
* [Training](#training)
  * [Automatic training](#automatic-training)
  * [Manual training](#manual-training)
* [Evaluation](#evaluation)
  1. [Changes required for evaluation](#changes-required-for-evaluation)
  1. [Perform evaluation](#perform-evaluation)
  1. [Re-deploy best parameters](#re-deploy-best-parameters)
* [Configuration](#configuration)
  * [Environment variables](#environment-variables)
* [Running commands](#running-commands)


## Heroku architectures

Two styles of deployment are possible on Heroku.

### Cluster on Heroku Enterprise

Use PredictionIO engines with a scalable Spark cluster.

Deploy [spark-in-space](https://github.com/heroku/spark-in-space) into a [Private Space](https://devcenter.heroku.com/articles/private-spaces).

#### Apps created in the Space

The eventserver & engine apps must be created with the `--space` option set to the name of a Private Space:

```bash
heroku create $eventserver_name --space $space_name
heroku create $engine_name --space $space_name
```

#### Database in the Common Runtime

🚨 *Database connection is required during build. Stateless builds to solve this issue are in discussion on the [Apache Software Foundation Spark users mailing list](http://predictionio.incubator.apache.org/support/)*

When [creating the eventserver's database](#create-the-eventserver), a few extra arguments are required to attach to the Private Space.

```bash
heroku addons:create heroku-postgresql:standard-0 --region=us -a $eventserver_name --confirm $eventserver_name
```

#### Set Spark master on an engine

Engines must be pointed at the Spark master. Include the `--master` option along with any other [Spark options](#environment-variables):

```bash
heroku config:set \
  PIO_TRAIN_SPARK_OPTS='--master spark://1.master.$spark_master_name.app.localspace:7077' \
  PIO_SPARK_OPTS='--master spark://1.master.$spark_master_name.app.localspace:7077'
```

### Single dyno on Common Runtime

This buildpacks supports deploying PredictionIO engines on a single dyno outside a Private Space.

The approach runs Spark within the same process as PredictionIO. This is only recommended for experimental, proof-of-concept work. The limited resources of a single dyno restrict use of typically large, statistically significant datasets.

Only **Performance-L** dynos with 14GB RAM (currently $16/day) provide reasonable utility in this configuration.


## Eventserver

### Create the eventserver

```bash
git clone https://github.com/heroku/heroku-buildpack-pio.git pio-eventserver
cd pio-eventserver

heroku create $eventserver_name
heroku addons:create heroku-postgresql:standard-0
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-pio.git
heroku buildpacks:add -i 2 https://github.com/heroku/spark-in-space.git
heroku buildpacks:add -i 3 heroku/scala
```

* Note the Postgres add-on identifier, e.g. `postgresql-aerodynamic-00000`; use it below in place of `$postgres_addon_id`
* We specify a `standard-0` database, because the free `hobby-dev` database is limited to 10,000 records.

### Deploy the eventserver

We delay deployment until the database is ready.

```bash
heroku pg:wait && git push heroku master
```


## Engine

### Create an engine

[Install PredictionIO locally](https://predictionio.incubator.apache.org/install/) and [download an engine template](https://predictionio.incubator.apache.org/start/download/) from the [gallery](https://predictionio.incubator.apache.org/gallery/template-gallery/). This can be as simple as downloading the source from Github and expanding it on your local computer.

`cd` into the engine directory, and ensure it is a git repo:

```bash
git init
```

### Create a Heroku app for the engine

```bash
heroku create $engine_name
heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-jvm-common.git
heroku buildpacks:add -i 2 https://github.com/heroku/heroku-buildpack-pio.git
heroku buildpacks:add -i 3 https://github.com/heroku/spark-in-space.git
```

### Create a PredictionIO app in the eventserver

```bash
heroku run 'pio app new $pio_app_name' -a $eventserver_name
```

* This returns an access key for the app; use it below in place of `$pio_app_access_key`.

### Configure the Heroku app to use the eventserver

Replace the Postgres ID & eventserver config values with those from above:

```bash
heroku addons:attach $postgres_addon_id
heroku config:set \
  PIO_EVENTSERVER_IP=$eventserver_name.herokuapp.com \
  PIO_EVENTSERVER_PORT=80 \
  PIO_EVENTSERVER_ACCESS_KEY=$pio_app_access_key \
  PIO_EVENTSERVER_APP_NAME=$pio_app_name
```

### Update `engine.json`

Modify this file to make sure the `appName` parameter matches the app record [created in the eventserver](#generate-an-app-record-on-the-eventserver).

```json
  "datasource": {
    "params" : {
      "appName": "$pio_app_name"
    }
  }
```

* If the `appName` param is missing, you may need to [upgrade the template](https://predictionio.incubator.apache.org/resources/upgrade/).

### Import data

This step will vary based on the engine. See the template's docs for instructions.

### Deploy to Heroku

```bash
git add .
git commit -m "Initial PIO engine"
git push heroku master
```

## Training

### Automatic training

🚨 *Private Spaces do not currently support the release-phase script for automatic training. See: [Manual training](#manual-training).*

`pio train` will automatically run during [release-phase of the Heroku app](https://devcenter.heroku.com/articles/release-phase).

The release dyno size should be set to a larger dyno, like Performance-L:

```bash
heroku ps:scale release=0:Performance-L
```

Auto training may be disabled with:

```bash
heroku config:set PIO_TRAIN_ON_RELEASE=false
```

### Manual training

```bash
heroku run train

# You may need to revive the app from "crashed" state.
heroku restart
```

## Evaluation

PredictionIO provides an [Evaluation mode for engines](https://predictionio.incubator.apache.org/evaluation/), which uses cross-validation to help select optimum engine parameters.

⚠️ Only engines that contain `src/main/scala/Evaluation.scala` support Evaluation mode.

### Changes required for evaluation

To run evaluation on Heroku, ensure `src/main/scala/Evaluation.scala` references the engine's name through the environment. Check the source file to verify that `appName` is set to `sys.env("PIO_EVENTSERVER_APP_NAME")`. For example:

```scala
DataSourceParams(appName = sys.env("PIO_EVENTSERVER_APP_NAME"), evalK = Some(5))
```

♻️ If that change was made, then commit, deploy, & re-train before proceeding.

### Perform evaluation

Next, start a console & change to the engine's directory:

```bash
heroku run bash
$ cd pio-engine/
```

Then, start the process, specifying the evaluation & engine params classes from the `Evaluation.scala` source file. For example:

```bash
$ pio eval \
    org.template.classification.AccuracyEvaluation \
    org.template.classification.EngineParamsList  \
    -- --driver-class-path /app/lib/postgresql_jdbc.jar
```

### Re-deploy best parameters

Once `pio eval` completes, still in the Heroku console, copy the contents of `best.json`:

```bash
$ cat best.json
```

♻️ Paste into your local `engine.json`, commit, & deploy.


## Configuration

### Environment variables

Engine deployments honor the following config vars:

* `PIO_OPTS`
  * options passed as `pio $opts`
  * see: [`pio` command reference](https://predictionio.incubator.apache.org/cli/)
  * example:

    ```bash
    heroku config:set PIO_OPTS='--variant best.json'
    ```
* `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`
  * **deploy** & **training** options passed through to `spark-submit $opts`
  * see: [`spark-submit` reference](http://spark.apache.org/docs/1.6.1/submitting-applications.html)
  * example:

    ```bash
    heroku config:set \
      PIO_SPARK_OPTS='--total-executor-cores 2 --executor-memory 1g' \
      PIO_TRAIN_SPARK_OPTS='--total-executor-cores 8 --executor-memory 4g'
    ```
* `PIO_EVENTSERVER_IP`
  * in Private Space: `web.$eventserver_name.app.localspace`
  * in Common Runtime: `$eventserver_name.herokuapp.com`
* `PIO_EVENTSERVER_PORT`
  * always `80` for Heroku apps
* `PIO_EVENTSERVER_APP_NAME` & `PIO_EVENTSERVER_ACCESS_KEY'
  * generated by running `pio app new $pio_app_name` on the eventserver

## Running commands

`pio` commands that require DB access will need to have the driver specified as an argument (bug with PIO 0.9.5 + Spark 1.6.1):

```bash
pio $command -- --driver-class-path /app/lib/postgresql_jdbc.jar
```

#### To run directly with Heroku CLI

```bash
heroku run "cd pio-engine && pio $command -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

#### Useful commands

Check engine status:

```bash
heroku run "cd pio-engine && pio status -- --driver-class-path /app/lib/postgresql_jdbc.jar"
```

