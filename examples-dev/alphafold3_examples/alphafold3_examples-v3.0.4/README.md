Official AlphaFold 3 input examples from [google-deepmind/alphafold3/examples](https://github.com/google-deepmind/alphafold3/tree/main/examples).

`.alphafold3_upstream/` is a sparse checkout (`examples/` only) of the official repo (not tracked here); `alphafold3_jsons/` contains copies of the `.json`-s in the flat layout expected by the workflow.

Initial setup:
```
git clone --filter=blob:none --sparse https://github.com/google-deepmind/alphafold3.git .alphafold3_upstream
git -C .alphafold3_upstream sparse-checkout set examples
```

Pull changes from upstream:
```
git -C .alphafold3_upstream pull
rsync -av --delete --include='*.json' --exclude='*' .alphafold3_upstream/examples/ alphafold3_jsons/
```
