# docker-ubuntu

[![build](https://github.com/gostamp/docker-ubuntu/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/gostamp/docker-ubuntu/actions/workflows/build.yml)

Images are signed using [cosign](https://github.com/sigstore/cosign).
To verify signatures, run:

```text
cosign verify "ghcr.io/gostamp/ubuntu-full:latest" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --certificate-identity-regexp="https://github.com/gostamp/docker-ubuntu/.github/workflows/release.yml"
```
