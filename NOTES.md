# Notes
- Improve documentation & examples, e.g. MSA caching 
- Build & test [v3.0.2](https://github.com/google-deepmind/alphafold3/issues/395) once released
- Currently only one type of GPU (A100 80GB), can we use others, e.g. A100 40GB?
    - Run AF3 tests as a target:
[run_alphafold_test.py](https://github.com/google-deepmind/alphafold3/blob/main/run_alphafold_test.py)
and
[run_alphafold_data_test.py](https://github.com/google-deepmind/alphafold3/blob/main/run_alphafold_data_test.py)
- Optimise number of simultaneous MSA jobs (currently set to 500)
    - Alternative locations for the public databases, e.g. SSD or global scratch?
    - Striping - https://wiki.lustre.org/Configuring_Lustre_File_Striping
    - Batch MSA jobs & download local copy every time (takes ~30mins, traffic considerations?)
- Downstream processing, e.g. scoring biases, interaction patterns, ...
- Other co-folding methods

| Name       | Repo    |
| ---------- | ------- |
| AlphaFold3 | [google-deepmind/alphafold3](https://github.com/google-deepmind/alphafold3) |
| Boltz-1    | [jwohlwend/boltz](https://github.com/jwohlwend/boltz) |
| Chai-1     | [chaidiscovery/chai-lab](https://github.com/chaidiscovery/chai-lab) |
| HelixFold  | [PaddlePaddle/PaddleHelix](https://github.com/PaddlePaddle/PaddleHelix/tree/dev/apps/protein_folding/helixfold) |
| Ligo       | [Ligo-Biosciences/AlphaFold3](https://github.com/Ligo-Biosciences/AlphaFold3) |
| OpenFold3  | [(TBD)](https://bsky.app/profile/moalquraishi.bsky.social/post/3lbeqspkunc2w) | 
| Protenix   | [bytedance/Protenix](https://github.com/bytedance/Protenix) |
