# https://github.com/microsoft/bioemu
FROM nvidia/cuda:12.8.0-base-ubuntu24.04

ARG BIOEMU_VERSION

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update --quiet \
    && apt-get install --yes --quiet python3.12 python3-pip python3.12-venv python3.12-dev \
    && apt-get install --yes --quiet git wget gcc g++ make zlib1g-dev zstd

RUN python3 -m venv /bioemu_venv
ENV PATH="/bioemu_venv/bin:$PATH"

RUN pip3 install --no-cache-dir --upgrade pip

ENV BIOEMU_VERSION=${BIOEMU_VERSION}

RUN pip3 install --no-cache-dir setuptools \
    && pip3 install --no-cache-dir bioemu==${BIOEMU_VERSION}

# > The first time bioemu is used to sample structures, it will also setup Colabfold on a separate virtual environment for MSA and embedding generation.
ENV BIOEMU_COLABFOLD_DIR=/colabfold

# > To run a tiny test using the default model parameters and denoising settings:
RUN python -m bioemu.sample --sequence GYDPETGTWG --num_samples 10 --output_dir /test-chignolin

ENTRYPOINT ["python"]
