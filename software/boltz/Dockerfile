# See also:
# https://github.com/jwohlwend/boltz/pull/38
# https://github.com/google-deepmind/alphafold3/blob/main/docker/Dockerfile

FROM nvidia/cuda:12.8.0-base-ubuntu24.04

ARG BOLTZ_VERSION

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update --quiet \
    && apt-get install --yes --quiet python3.12 python3-pip python3.12-venv python3.12-dev \
    && apt-get install --yes --quiet git wget gcc g++ make zlib1g-dev zstd

RUN python3 -m venv /boltz_venv
ENV PATH="/boltz_venv/bin:$PATH"

RUN pip3 install --no-cache-dir --upgrade pip

ENV BOLTZ_VERSION=${BOLTZ_VERSION}

RUN pip3 install --no-cache-dir setuptools \
    && pip3 install --no-cache-dir boltz==${BOLTZ_VERSION}

# Solves numba-related `RuntimeError: cannot cache function`
ENV NUMBA_CACHE_DIR=/tmp/numba_cache

ENTRYPOINT ["boltz"]
