SHOW NAMESPACES IN bronze;
SHOW TABLES IN bronze.lakehouse;

SELECT count(*) AS lineitem_rows FROM bronze.lakehouse.raw_lineitem;
SELECT orderkey, linenumber, quantity, extendedprice, shipdate
FROM bronze.lakehouse.raw_lineitem
ORDER BY orderkey, linenumber
LIMIT 5;

SELECT count(*) AS large_orders_found
FROM (SELECT orderkey FROM bronze.lakehouse.raw_lineitem
      GROUP BY orderkey HAVING sum(quantity) > 300) s;

SELECT count(*) AS data_files, sum(file_size_in_bytes) AS bytes
FROM bronze.lakehouse.raw_lineitem.files;
SELECT snapshot_id, operation FROM bronze.lakehouse.raw_orders.snapshots;
SELECT partition, record_count, file_count FROM bronze.lakehouse.raw_orders.partitions
ORDER BY partition;
