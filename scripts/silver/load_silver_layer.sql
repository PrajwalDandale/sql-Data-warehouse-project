/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    call silver.load_silver;
===============================================================================
*/

USE silver;

DELIMITER $$

DROP PROCEDURE IF EXISTS silver.load_silver $$

CREATE PROCEDURE silver.load_silver()
BEGIN

    /* ============================================================
       VARIABLES
       ============================================================ */

    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;

    DECLARE batch_start DATETIME;
    DECLARE batch_end DATETIME;

    DECLARE rows_loaded INT DEFAULT 0;
    DECLARE total_rows INT DEFAULT 0;

    DECLARE error_message TEXT;
    DECLARE error_state CHAR(5);

    /* ============================================================
       GLOBAL ERROR HANDLER
       ============================================================ */

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN

        GET DIAGNOSTICS CONDITION 1
            error_state = RETURNED_SQLSTATE,
            error_message = MESSAGE_TEXT;

        SET end_time = NOW();

        SELECT '================================================' AS message;
        SELECT 'SILVER LOAD FAILED' AS message;
        SELECT CONCAT('Error Time      : ', end_time) AS message;
        SELECT CONCAT('SQLSTATE        : ', error_state) AS message;
        SELECT CONCAT('Error Message   : ', error_message) AS message;
        SELECT CONCAT(
            'Total Duration   : ',
            TIMESTAMPDIFF(SECOND, start_time, end_time),
            ' seconds'
        ) AS message;
        SELECT '================================================' AS message;

    END;


    /* ============================================================
       START BATCH
       ============================================================ */

    SET start_time = NOW();

    SELECT '================================================' AS message;
    SELECT 'SILVER LAYER LOAD STARTED' AS message;
    SELECT CONCAT('Start Time : ', start_time) AS message;
    SELECT '================================================' AS message;


    /* ============================================================
       1. CRM CUSTOMER
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.crm_cust_info...' AS message;

    TRUNCATE TABLE silver.crm_cust_info;

    INSERT INTO silver.crm_cust_info
    (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),

        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                THEN 'Married'
            ELSE 'UNKNOWN'
        END,

        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'M'
                THEN 'MALE'
            WHEN UPPER(TRIM(cst_gndr)) = 'F'
                THEN 'FEMALE'
            ELSE 'UNKNOWN'
        END,

        cst_create_date

    FROM
    (
        SELECT *,
            ROW_NUMBER() OVER
            (
                PARTITION BY cst_id
                ORDER BY cst_create_date DESC
            ) AS flag_last

        FROM bronze.crm_cust_info

        WHERE cst_id IS NOT NULL
          AND cst_id <> 0

    ) t

    WHERE flag_last = 1;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'crm_cust_info loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       2. CRM PRODUCT
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.crm_prd_info...' AS message;

    TRUNCATE TABLE silver.crm_prd_info;

    INSERT INTO silver.crm_prd_info
    (
        prd_id,
        prd_key,
        cat_id,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,

        SUBSTRING(prd_key, 7) AS prd_key,

        REPLACE(
            SUBSTRING(prd_key, 1, 5),
            '-',
            '_'
        ) AS cat_id,

        prd_nm,

        prd_cost,

        CASE
            WHEN UPPER(TRIM(prd_line)) = 'M'
                THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'R'
                THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'S'
                THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T'
                THEN 'Touring'
            ELSE 'UNKNOWN'
        END,

        prd_start_dt,

        DATE_SUB(
            LEAD(prd_start_dt) OVER
            (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            ),
            INTERVAL 1 DAY
        )

    FROM bronze.crm_prd_info;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'crm_prd_info loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       3. CRM SALES DETAILS
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.crm_sales_details...' AS message;

    TRUNCATE TABLE silver.crm_sales_details;

    INSERT INTO silver.crm_sales_details
    (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,

        CASE
            WHEN sls_order_dt = 0
              OR LENGTH(sls_order_dt) <> 8
                THEN NULL
            ELSE STR_TO_DATE(sls_order_dt, '%Y%m%d')
        END,

        CASE
            WHEN sls_ship_dt = 0
              OR LENGTH(sls_ship_dt) <> 8
                THEN NULL
            ELSE STR_TO_DATE(sls_ship_dt, '%Y%m%d')
        END,

        CASE
            WHEN sls_due_dt = 0
              OR LENGTH(sls_due_dt) <> 8
                THEN NULL
            ELSE STR_TO_DATE(sls_due_dt, '%Y%m%d')
        END,

        CASE
            WHEN sls_sales IS NULL
              OR sls_sales <= 0
              OR sls_sales <> sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END,

        sls_quantity,

        CASE
            WHEN sls_price IS NULL
              OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END

    FROM bronze.crm_sales_details;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'crm_sales_details loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       4. ERP CUSTOMER
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.erp_cust_az12...' AS message;

    TRUNCATE TABLE silver.erp_cust_az12;

    INSERT INTO silver.erp_cust_az12
    (
        cid,
        bdate,
        gen
    )
    SELECT

        CASE
            WHEN cid LIKE 'NAS%'
                THEN SUBSTRING(cid, 4)
            ELSE cid
        END,

        CASE
            WHEN bdate > NOW()
                THEN NULL
            ELSE bdate
        END,

        CASE
            WHEN UPPER(
                TRIM(
                    REPLACE(
                        REPLACE(gen, '\r', ''),
                        '\n', ''
                    )
                )
            ) IN ('M', 'MALE')
                THEN 'Male'

            WHEN UPPER(
                TRIM(
                    REPLACE(
                        REPLACE(gen, '\r', ''),
                        '\n', ''
                    )
                )
            ) IN ('F', 'FEMALE')
                THEN 'Female'

            ELSE 'UNKNOWN'
        END

    FROM bronze.erp_cust_az12;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'erp_cust_az12 loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       5. ERP LOCATION
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.erp_loc_a101...' AS message;

    TRUNCATE TABLE silver.erp_loc_a101;

    INSERT INTO silver.erp_loc_a101
    (
        cid,
        cntry
    )
    SELECT
        REPLACE(cid, '-', ''),

        CASE
            WHEN UPPER(
                TRIM(
                    REPLACE(
                        REPLACE(cntry, '\r', ''),
                        '\n', ''
                    )
                )
            ) = 'DE'
                THEN 'Germany'

            WHEN UPPER(
                TRIM(
                    REPLACE(
                        REPLACE(cntry, '\r', ''),
                        '\n', ''
                    )
                )
            ) IN ('US', 'USA')
                THEN 'United States'

            WHEN UPPER(
                TRIM(
                    REPLACE(
                        REPLACE(cntry, '\r', ''),
                        '\n', ''
                    )
                )
            ) = ''
            OR cntry IS NULL
                THEN 'UNKNOWN'

            ELSE cntry
        END

    FROM bronze.erp_loc_a101;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'erp_loc_a101 loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       6. ERP PRODUCT CATEGORY
       ============================================================ */

    SET batch_start = NOW();

    SELECT '------------------------------------------------' AS message;
    SELECT 'Loading silver.erp_px_cat_g1v2...' AS message;

    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    INSERT INTO silver.erp_px_cat_g1v2
    (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        id,
        cat,
        subcat,
        maintenance

    FROM bronze.erp_px_cat_g1v2;

    SET rows_loaded = ROW_COUNT();
    SET total_rows = total_rows + rows_loaded;
    SET batch_end = NOW();

    SELECT 'erp_px_cat_g1v2 loaded successfully' AS message;
    SELECT CONCAT('  Rows Loaded : ', rows_loaded) AS message;
    SELECT CONCAT(
        '  Duration    : ',
        TIMESTAMPDIFF(SECOND, batch_start, batch_end),
        ' seconds'
    ) AS message;


    /* ============================================================
       FINAL SUMMARY
       ============================================================ */

    SET end_time = NOW();

    SELECT '================================================' AS message;
    SELECT 'SILVER LAYER LOAD COMPLETED SUCCESSFULLY' AS message;
    SELECT CONCAT('Start Time       : ', start_time) AS message;
    SELECT CONCAT('End Time         : ', end_time) AS message;
    SELECT CONCAT(
        'Total Duration   : ',
        TIMESTAMPDIFF(SECOND, start_time, end_time),
        ' seconds'
    ) AS message;
    SELECT CONCAT('Total Rows Loaded: ', total_rows) AS message;
    SELECT '================================================' AS message;

END $$

DELIMITER ;
