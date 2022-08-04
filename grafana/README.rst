Developing Graphs
=================

The ``run-grafana.sh`` script in this directory will start a Docker
container with Grafana listening on port 3000.  It will then load the
datasources and dashboards in this directory.  Repeated runs of the
script will re-load the scripts.

You can log into the instance with the username "admin" and password
"password".  You can then use the Grafana UI to develop graphs.

The "share" icon on the graph in the UI can be used to export a JSON
file, which your browser will download.  You can copy that to this
directory (or update existing files) and submit a review.
