# https://github.com/dina-lab3D/CombFold#os-requirements
# Linux: Debian 10
FROM python:3.13-slim

# The Combinatorial assembler depends on Boost which can be installed using:
RUN DEBIAN_FRONTEND=noninteractive apt-get update --quiet \
    && apt-get install --yes --quiet build-essential git libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN python -m venv .venv
ENV PATH="/app/.venv/bin:$PATH"
RUN pip install numpy biopython scipy

RUN git clone https://github.com/dina-lab3D/CombFold.git
RUN cd CombFold/CombinatorialAssembler && make

ENTRYPOINT ["python", "/app/CombFold/scripts/run_on_pdbs.py"]
