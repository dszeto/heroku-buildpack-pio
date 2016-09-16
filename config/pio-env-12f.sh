#!/usr/bin/env bash

# PredictionIO Main Configuration
#
# This section controls core behavior of PredictionIO. It is very likely that
# you need to change these to fit your site.

# SPARK_HOME: Apache Spark is a hard dependency and must be configured.
# Must match $spark_dist_dir in bin.compile
SPARK_HOME=/app/spark-home

# ES_CONF_DIR: You must configure this if you have advanced configuration for
#              your Elasticsearch setup.
# ES_CONF_DIR=/opt/elasticsearch

# HADOOP_CONF_DIR: You must configure this if you intend to run PredictionIO
#                  with Hadoop 2.
# HADOOP_CONF_DIR=/opt/hadoop

# HBASE_CONF_DIR: You must configure this if you intend to run PredictionIO
#                 with HBase on a remote cluster.
# HBASE_CONF_DIR=$PIO_HOME/vendors/hbase-1.0.0/conf

# Filesystem paths where PredictionIO uses as block storage.
PIO_FS_BASEDIR=$HOME/.pio_store
PIO_FS_ENGINESDIR=$PIO_FS_BASEDIR/engines
PIO_FS_TMPDIR=$PIO_FS_BASEDIR/tmp
