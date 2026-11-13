SELECT outputs.run_id,
       runs.folder || '/' || outputs.path AS file, 
       sha256                                     
FROM outputs
JOIN runs ON runs.run_id = outputs.run_id
WHERE outputs.path = 'cohort.filtered.vcf.gz';
