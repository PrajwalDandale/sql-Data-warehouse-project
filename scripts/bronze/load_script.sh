/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This script loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `LOAD DATA` command to load data from csv Files to bronze tables.

Usage Example:
    /.load_bronze_new.sh;
===============================================================================
*/

#!/bin/bash

start_time=$(date +%s)

echo "======================================"
echo "Starting Bronze Layer Data Load"
echo "Start Time: $(date)"
echo "======================================"

load_table() {

    local table_name=$1
    local file_path=$2
    table_start=$(date +%s)

    echo ""
    echo "Loading $table_name ..."

    mysql --local-infile=1 -e "
    TRUNCATE TABLE $table_name;

    LOAD DATA LOCAL INFILE '$file_path'
    INTO TABLE $table_name
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '\"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;
    "
    table_end=$(date +%s)
    duration=$((table_end - table_start))

    if [ $? -eq 0 ]; then
        echo "✓ $table_name loaded successfully. (${duration}seconds)"
    else
        echo "✗ Error loading $table_name. (${duration}seconds)"
        exit 1
    fi
}

load_table \
"bronze.crm_cust_info" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_crm/cust_info.csv"

load_table \
"bronze.crm_prd_info" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_crm/prd_info.csv"

load_table \
"bronze.crm_sales_details" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_crm/sales_details.csv"

load_table \
"bronze.erp_cust_az12" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_erp/CUST_AZ12.csv"

load_table \
"bronze.erp_loc_a101" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_erp/LOC_A101.csv"

load_table \
"bronze.erp_px_cat_g1v2" \
"/Users/prajwal/Documents/UDEMY/SQL/sql-data-warehouse-project/datasets/source_erp/PX_CAT_G1V2.csv"

end_time=$(date +%s)
duration=$((end_time-start_time))
echo ""
echo "======================================"
echo "Bronze Layer Loaded Successfully"
echo "End Time: $(date)"
echo "Total Duration: ${duration} seconds"
echo "======================================"
