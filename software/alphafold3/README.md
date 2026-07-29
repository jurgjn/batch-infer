[![Docker Pulls](https://img.shields.io/docker/pulls/jurgjn/alphafold3)](https://hub.docker.com/r/jurgjn/alphafold3)

#### Vanilla [builds](https://github.com/jurgjn/batch-infer/blob/develop/software/alphafold3/build.ipynb), tags match commit/version from [google-deepmind/alphafold3](https://github.com/google-deepmind/alphafold3/)
- [v3.0.4](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.4)
from Jul 28 2026
- [v3.0.3](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.3)
from Jun 9 2026
- [v3.0.2](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.2)
from Apr 20 2026
- [608edb6](https://github.com/google-deepmind/alphafold3/tree/608edb684db9f6fd0e677fea01c4cefc60f8a8aa)
from Mar 10 2026
- [ebfe70a](https://github.com/google-deepmind/alphafold3/tree/ebfe70a27a6a1ad18c77664191c5f7fa486ebee9)
from Feb 4 2026
- [b78e215](https://github.com/google-deepmind/alphafold3/tree/b78e2153948a0effc5aa70cbd6b605af693170df)
from Jan 9 2026
(supports [Blackwell GPUs](https://github.com/google-deepmind/alphafold3/issues/394#issuecomment-3729122024), e.g. RTX PRO 6000)
- [a8ecdb2](https://github.com/google-deepmind/alphafold3/tree/a8ecdb2d7a433c5e9f8510a0f52434a0c55018c4)
from Sep 8 2025
- [2e2ffc1](https://github.com/google-deepmind/alphafold3/tree/2e2ffc10ab13b1d6f0234d0007488c4a3dedf3e6)
from Aug 7 2025
- [0422023](https://github.com/google-deepmind/alphafold3/tree/042202363b0842a81b2b5c948b2c7c14704ef9f4)
from Jul 14 2025
- [v3.0.1](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.1)
from Jan 23 2025
(latest [release](https://github.com/google-deepmind/alphafold3/issues/395#issuecomment-2841971760), default in [batch-infer](https://github.com/jurgjn/batch-infer))
- [v3.0.0](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.0)
from Nov 11 2024

#### Custom builds
- [97d66d2](https://github.com/sokrypton/alphafold3/tree/97d66d2873d10080f476c8014e743ee70890fb5a)
from [sokrypton/alphafold3](https://github.com/sokrypton/alphafold3)
to [use OpenFold3 weights](https://x.com/sokrypton/status/2066223464210370862)
- [v3.0.1-daint1](https://github.com/jurgjn/alphafold3/commit/7afc573abb895e96a1294796d50fe297c572fce2) for arm64/gh200 (Grace Hopper)
by modifying a single line in pyproject.toml from [jurgjn/alphafold3](https://github.com/jurgjn/alphafold3/)
(and removing all hashes from dev-requirements.txt)

#### See also
- [Singularity Containers for Protein Prediction Models](https://github.com/EpiGenomicsCode/ProteinStruct-Containers/)
- [Getting AlphaFold 3 to run on AMD GPUs](https://www.linkedin.com/pulse/getting-alphafold-3-run-amd-gpus-owain-kenway-egite)
- [Source Code Update for GPU Blackwell and CC 12.0 Compatibility in AlphaFold 3](https://github.com/google-deepmind/alphafold3/issues/394)
