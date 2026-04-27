#!/usr/bin/env bash
# Run inside the AF3 container replacing `python3 run_alphafold.py`
cd /app/alphafold

echo Running nvidia-smi
nvidia-smi
echo Finished nvidia-smi

echo Adjusting pair_transition_shard_spec in model_config.py to shard in chunks of 256 for v3.0.2..
git apply <<EOF
diff --git a/src/alphafold3/model/model_config.py b/src/alphafold3/model/model_config.py
index 0128e9e..3fee692 100644
--- a/src/alphafold3/model/model_config.py
+++ b/src/alphafold3/model/model_config.py
@@ -27,7 +27,8 @@ class GlobalConfig(base_config.BaseConfig):
   pair_attention_chunk_size: Sequence[_Shape2DType] = ((1536, 128), (None, 32))
   pair_transition_shard_spec: Sequence[_Shape2DType] = (
       (2048, None),
-      (None, 1024),
+      (3072, 1024),
+      (None, 256),
   )
   # Note: flash_attention_implementation = 'xla' means no flash attention.
   flash_attention_implementation: tokamax.DotProductAttentionImplementation = (
EOF

echo Starting run_alphafold.py
python3 run_alphafold.py $@
