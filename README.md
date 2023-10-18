# Introduction

The sandcastle is a containerized deployment of GNU Taler

It uses podman to build an image and run a single container that
has systemd running inside.


# Prerequisites

You need (on your host system):
* podman
* bash


# Building the Container Image

1. Set buildconfig/$component.tag to the right git tag you want to build
2. Run ./sandcastle-build to build the Taler container.  The resulting container
   is tagged as taler-base-all


# Configuring the Deployment

It is recommended that for each deployment, you clone the deployment.git
repository and create a branch with deployment-specific changes.

Currently there is not much configuration.

The main adjustments to be made are:

* scripts/demo/setup-sandcastle.sh has the currency on top of the file
* sandcastle-run has variables for the port that'll be exposed ("published") on
  the host.  They can be overwritten with environment variables
  (``TALER_SANDCASTLE_PORT_$COMPONENT``).


# Running the Deployment

Run ``./sandcastle-run`` to run the single container.  The container will be
named taler-sandcastle.

You can run the container in the background by passing ``-d``.  Note that ``./sandcastle-run`` is just
a wrapper around ``podman run``.

The running container publishes ports to the host as defined in ``./sandcastle-run``.
You can manually verify these port mappings via ``podman port taler-sandcastle``.

# Stopping the deployment

```
podman stop taler-sandcastle
```


# Poking Around

You can poke around in a running sandcastle instance by running

```
podman exec -it taler-sandcastle /bin/bash
```

Or, as a shortcut:

```
./sandcastle-enter
```

This will drop you into a shell inside the running container,
where you have access to systemd, journalctl, etc.


# Data Storage

All persistent data is stored in a podman volume called
talerdata.  You can see where it is in your filesystem
by running ``podman volume inspect talerdata``.

That volume also contains the postgres database files.


# Provisioning Details

The whole deployment is configured by the script ``/provision/setup-sandcastle.sh``.
This script will be run as a oneshot systemd service and will disable itself after
the first success.

To troubleshoot, run ``journalctl -u setup-sandcastle.service``.

There are different setup scripts in the ``scripts/$SANDCASTLE_SETUP_NAME``
folders. Specifically:

* ``none`` does no setup at all
* ``demo`` is the usual Taler demo
* TBD: ``regio`` is a currency conversion setup

By default, ``demo`` is used.  To mount a different provision script, set ``$SANDCASTLE_SETUP_NAME``
when running ``./sandcastle-run``.

You can always manually run the provisioning script inside the container as
``/scripts/$SANDCASTLE_SETUP_NAME/setup-sandcastle.sh``.


# Neat Things That Already Work

* Rebulding the base image is incremental, since we use layers.  If the tag
  of the exchange is changed, only the exchange and components that depend
  on it are rebuilt.
* Inside the container, the service names resolve to localhost,
  and on localhost a reverse proxy with locally signed certificates
  ensures that services can talk to each other *within* the container
  by using their *public* base URL.


# Future Extensions

* Fix rewards by deploying Javier's reward topup script inside the container via a systemd timer!
* Variant where credentials use proper secret management instead of hard-coding all
  passwords to "sandbox".
* Better way to access logs, better way to expose errors during provisioning
* The Dockerfile should introduce nightly tags for debian packages it builds.
  Currently it just uses the latest defined version, which is confusing.
* Deploy the Taler woocommerce plugin, wordpress plugin, Joomla plugin
* Do self-tests of the deployment using the wallet CLI
* Running the auditor
* Running a currency conversion setup with multiple libeufin-bank instances
* Allow a localhost-only, non-tls setup for being able to access a non-tls
  Taler deployment on the podman host.
* Instead of exposing HTTP ports, we could expose everything via unix domain sockets,
  avoiding port collision problems.
* Instead of requiring the reverse proxy to handle TLS,
  the sandcastle container itself could do TLS termination with caddy.
* To improve performance, allow connecting to an external database
* Make it easy to import and export the persistent data
* Extra tooling to checkpoint images/containers to revert to a previous
  state quickly.
