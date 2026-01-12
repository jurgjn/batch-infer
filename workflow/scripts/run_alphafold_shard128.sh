#!/usr/bin/env bash
# Run inside the AF3 container replacing `python3 run_alphafold.py`
cd /app/alphafold

echo Running nvidia-smi
nvidia-smi
echo Finished nvidia-smi

echo Adjusting pair_transition_shard_spec in model_config.py to shard in chunks of 128
git apply <<EOF
diff --git a/src/alphafold3/model/model_config.py b/src/alphafold3/model/model_config.py
index 2040d8f..aafb94a 100644
--- a/src/alphafold3/model/model_config.py
+++ b/src/alphafold3/model/model_config.py
@@ -26,7 +26,7 @@ class GlobalConfig(base_config.BaseConfig):
   pair_attention_chunk_size: Sequence[_Shape2DType] = ((1536, 128), (None, 32))
   pair_transition_shard_spec: Sequence[_Shape2DType] = (
       (2048, None),
-      (None, 1024),
+      (None, 128),
   )
   # Note: flash_attention_implementation = 'xla' means no flash attention.
   flash_attention_implementation: attention.Implementation = 'triton'
EOF

echo Starting run_alphafold.py
python3 run_alphafold.py $@
