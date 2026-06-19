CREATE EXTERNAL TABLE IF NOT EXISTS db_aecorsoft_dev.aecorsoft_data (
  ingestion_ts TIMESTAMP
)
PARTITIONED BY (codproceso STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
STORED AS INPUTFORMAT 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat'
LOCATION 's3://artifact1-aecorsoft-landing-850995559699-us-east-1/AECORSOFT/aecorsoft_data/'
TBLPROPERTIES (
  'classification' = 'parquet',
  'table_type' = 'EXTERNAL_TABLE',
  'parquet.compress' = 'SNAPPY'
);
