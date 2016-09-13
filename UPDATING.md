Update an engine from PIO 0.9 to 0.10
==================================

## `build.sbt`

### Add the release candidate repo

```scala

resolvers += "ASF PIO 0.10.0-rc1" at "https://repository.apache.org/content/repositories/orgapachepredictionio-1001"

```

* Ensure this line has a blank line before and a blank line after it.

### Update the entry in `libraryDependencies`

```scala
  "org.apache.predictionio" %% "predictionio-core" % pioVersion.value % "provided"
```

## `src/main/scala/*`

### Update dependency namespace

Replace all occurences of
```
import io.prediction.*
```

with
```
import org.apache.predictionio.*
```
