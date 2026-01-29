# https://github.com/ntranoslab/esm-variants
FROM nvidia/cuda:12.6.0-base-ubuntu22.04

RUN apt-get update && apt-get install --yes \
    build-essential \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install into /app/esm-variants following ntranoslab/esm-variants
WORKDIR /app/esm-variants
RUN pip3 install tqdm numpy pandas biopython torch fair-esm
RUN git clone https://github.com/ntranoslab/esm-variants.git .

# Run example.fasta from ntranoslab/esm-variants to store default ESM model weights in the container
COPY example.fasta .
RUN python3 esm_score_missense_mutations.py --input-fasta-file example.fasta --output-csv-file esm_scores.csv
RUN cat esm_scores.csv

CMD ["python3", "esm_score_missense_mutations.py"]
