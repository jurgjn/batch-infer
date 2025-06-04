
- `alphafold3_onegpu` starts from input .json-s in `alphafold3_jsons`, runs data pipeline (one per input), and predictions (all as one GPU job)
- `alphafold3_msas_only` starts from input .json-s in `alphafold3_jsons`, runs data pipeline (one per input)
- `alphafold3_predictions_multigpu` starts from data pipeline output in `alphafold3_msas`, predicts prediction step input times, groups inputs by size into 4-hour group, submits each group as a separate GPU job

- `alphafold3_tests` runs predictions on all available GPU models
