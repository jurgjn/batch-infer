
include: '../rules/common.smk'

localrules: alphafold3_summary

rule alphafold3_summary:
    # ./batch-infer alphafold3_summary results/alphafold3_adhoc_examples | sbatch
    output:
        tsv = 'alphafold3_summary.tsv'
    run:
        ids_ = alphafold3_gather_ids(include_jsons=True, include_msas=True, include_predictions=True)
        df_ = pd.DataFrame({'id': sorted(ids_)})
        df_['json'] = map_eu(alphafold3_json_path, df_['id'])
        df_['data'] = map_eu(alphafold3_data_path, df_['id'])
        df_['pred'] = map_eu(alphafold3_pred_path, df_['id'])
        df_.to_csv(output.tsv, sep='\t', index=False, header=True)
