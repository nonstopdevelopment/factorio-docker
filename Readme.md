## Factorio Server Docker

A container for building and running a Dockerized Factorio server in a very insecure manner with ENV 

Project to run Factorio headless on Kubernetes OpenShift so this is a work in progress.

Image currently pulls the latest from Factorio website and then creates a server with out any space age or plugins.


#### ENV Variables To Set
```
FACTORIO_USERNAME
FACTORIO_PASSWORD
FACTORIO_SERVER_NAME
FACTORIO_SERVER_DESCRIPTION
```

Currently runs a default game with no plugins so it removes Space Age, Elevated Rails, and Quality.

This is built for a very specific use case so won't be ideal for most unless you just need a framework. Will be building a new version of this.
