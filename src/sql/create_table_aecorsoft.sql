CREATE EXTERNAL TABLE IF NOT EXISTS db_aecorsoft_dev.aecorsoft_data (
  kostl STRING,
  ktext STRING
)
PARTITIONED BY (
  codproceso STRING
)
ROW FORMAT SERDE
  'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
STORED AS INPUTFORMAT
  'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat'
OUTPUTFORMAT
  'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat'
LOCATION
  's3://ue1stgtestas3dtl001-landing/UE1STGTESTS3LOG001/SAP/CSKT/prueba/'
TBLPROPERTIES (
  'classification' = 'parquet',
  'table_type' = 'EXTERNAL_TABLE'
);
