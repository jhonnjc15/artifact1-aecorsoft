CREATE EXTERNAL TABLE IF NOT EXISTS db_aecorsoft_dev.aecorsoft_data (
  ingestion_ts TIMESTAMP
)
PARTITIONED BY (codproceso STRING)
STORED AS PARQUET
LOCATION 's3://<bucket>/<ruta-base>/'
TBLPROPERTIES (
  'parquet.compress' = 'SNAPPY',
  'classification' = 'parquet',
  'table_type' = 'EXTERNAL_TABLE'
);
