# helm-oci
Helm Plugin to provides OCI support, including downloader & chartmuseum compatible proxy

# Install

## prerequesties

- libcurl

## install
```
helm plugin install https://github.com/johnlinvc/helm-oci
```

# Usage

## Downloader

Add an OCI registry as repo, and download chart from the repo.

Set oci(docker registry) user to `OCI_USER` env var, password to `OCI_PW` env var.

```
export OCI_USER=DOCKER_REGISTRY_USER
export OCI_PW=PASSWORD
helm repo add oci-test oci+login://registry.azurecr.io
helm pull oci-test/chart
```

### Limit the repos to pull from

Pulling everything from the OCI registry take quite some time if there's a large amount of repos in it.
We can limit the repos to pull from with following syntax when adding repo

```
helm repo add oci-test oci+login://registry.azurecr.io?repo=chart1,chart2
```

## Proxy

Start a chartmuseum compatible proxy for the OCI registry.

## Compatibility

### Tested OCI registries
- Azure ACR
- Docker Registry

### Untested OCI registries
- harbor


# TODO

- Retry curl requests
- Show error when user and/or password is missing.
- Get user/password from docker password storage.
- Support registiry that don't require login
- Delete the temp files, also delete them with EXIT signal
- Option to limit the repo in registry, instead of fetching all repos.
