# AlphaFold 3 inference with pre-calculated data pipeline output

*This is still experimental/work-in-progress*

Specify directories (one or more) with pre-calculated data pipeline output in `config.yaml`:
```
alphafold3:
  ...
  data_sources: >-
    --data_dir=/cluster/project/beltrao/shared/25.06_alphafold3_msas_yeast
  ...
```

Run AlphaFold 3 with the following three batch-infer "steps":
- `alphafold3_datafill_missing` checks all input sequences against `data_sources` to find sequences without pre-calculated data pipeline output:
    - reads all input JSONs from `alphafold3_jsons/`
    - writes missing sequence input JSONs to `alphafold3_missing/`
- `alphafold3_datafill_msas` runs AlphaFold 3 data pipeline for missing sequences:
    - runs data pipeline for all missing sequence from `alphafold3_missing/`
    - writes the output to `alphafold3_msas/`
- `alphafold3_datafill_predictions` runs theinference step:
    - reads input JSONs from `alphafold3_jsons/`
    - creates data pipeline output (in local scratch) based `data_sources` and/or `alphafold3_msas/`
    - writes structure predictions to `alphafold3_predictions/`

