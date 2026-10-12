SET SESSION bronze.compression_codec = 'ZSTD';

CREATE OR REPLACE TABLE bronze.lakehouse.raw_customer
WITH (format = 'PARQUET')
AS SELECT
     custkey, name, address, nationkey, phone, acctbal, mktsegment, comment,
     TIMESTAMP '2026-10-01 09:00:00' AS loaded_at
   FROM tpch.sf1.customer;

CREATE OR REPLACE TABLE bronze.lakehouse.raw_orders
WITH (format = 'PARQUET', partitioning = ARRAY['year(orderdate)'])
AS SELECT
     orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority,
     clerk, shippriority, comment,
     TIMESTAMP '2026-10-01 09:00:00' AS loaded_at
   FROM tpch.sf1.orders;

CREATE OR REPLACE TABLE bronze.lakehouse.raw_lineitem
WITH (format = 'PARQUET')
AS SELECT
     orderkey, partkey, suppkey, linenumber, quantity, extendedprice, discount,
     tax, returnflag, linestatus, shipdate, commitdate, receiptdate,
     shipinstruct, shipmode, comment,
     TIMESTAMP '2026-10-01 09:00:00' AS loaded_at
   FROM tpch.sf1.lineitem;
