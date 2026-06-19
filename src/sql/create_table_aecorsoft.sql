CREATE EXTERNAL TABLE IF NOT EXISTS db_aecorsoft_dev.br_cskt (
  kostl STRING,
  ktext STRING
)
PARTITIONED BY (datbi_part STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
STORED AS INPUTFORMAT 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat'
LOCATION 's3://ue1stgtestas3dtl005-bronze/UE1STGTESTS3LOG001/SAP/CSKT/br_cskt/'
TBLPROPERTIES (
  'classification' = 'parquet',
  'table_type' = 'EXTERNAL_TABLE',
  'projection.enabled' = 'true',
  'projection.datbi_part.type' = 'enum',
  'projection.datbi_part.values' = '2014-12-31,9999-12-31',
  'storage.location.template' = 's3://ue1stgtestas3dtl005-bronze/UE1STGTESTS3LOG001/SAP/CSKT/br_cskt/DATBI_PART=${datbi_part}/'
);
