# helm-oci
Helm downloader Plugin to provides OCI support

# Install

## prerequesties

- libcurl

```
helm plugin install https://github.com/johnlinvc/helm-oci
```

# Usage

Set oci(docker registry) user to `OCI_USER` env var, password to `OCI_PW` env var.

```
export OCI_USER=DOCKER_REGISTRY_USER
export OCI_PW=PASSWORD
helm repo add oci-test oci+login://registry.azurecr.io
helm pull oci-test/chart
```

# TODO

- Show error when user and/or password is missing.
- Get user/password from docker password storage.
- Support registiry that don't require login
- Delete the temp files, also delete them with EXIT signal
