USE supply_chain_analytics;

SELECT
    (SELECT COUNT(DISTINCT product_id)
     FROM product_data) AS total_products,

    (SELECT COUNT(DISTINCT depot_id)
     FROM depot_master) AS total_depots,

    (SELECT COUNT(DISTINCT supplier_id)
     FROM supplier_master) AS total_suppliers,

    (SELECT SUM(quantity)
     FROM sales_master) AS total_units_sold,

    (SELECT SUM(net_sales)
     FROM sales_master) AS total_sales,

    (SELECT SUM(received_qty)
     FROM receiving_master) AS total_received;
     
     
    -- 2 DEPOT SALES HIGHEST
    SELECT
    d.depot_id,
    d.depot_name,
    SUM(s.net_sales) AS total_sales
FROM sales_master s
JOIN depot_master d
    ON s.depot_id = d.depot_id
GROUP BY
    d.depot_id,
    d.depot_name
ORDER BY total_sales DESC; 


-- Depot_wise_unit_sold

SELECT
    d.depot_name,
    SUM(s.quantity) AS total_units_sold
FROM sales_master s
JOIN depot_master d
    ON s.depot_id = d.depot_id
GROUP BY d.depot_name
ORDER BY total_units_sold DESC;


-- 4 category_wise_sales
SELECT
    p.category,
    SUM(s.net_sales) AS total_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_sales DESC;

-- 5Product_wise_sales

SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS units_sold,
    SUM(s.net_sales) AS total_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY total_sales DESC;
     
	-- 6 Top 10 Product
    
    SELECT
    p.product_id,
    p.product_name,
    SUM(s.quantity) AS units_sold,
    SUM(s.net_sales) AS total_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_sales DESC
LIMIT 10;
     
-- Bottom 10 Product
SELECT
    p.product_id,
    p.product_name,
    SUM(s.quantity) AS units_sold,
    SUM(s.net_sales) AS total_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_sales
LIMIT 10;

-- 8 Monthly_Sales
SELECT
    DATE_FORMAT(date, '%Y-%m') AS month,
    SUM(net_sales) AS total_sales,
    SUM(quantity) AS units_sold
FROM sales_master
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month;
     
 --  9Monthly_Receiving_Trend
 SELECT
    DATE_FORMAT(receipt_date, '%Y-%m') AS month,
    SUM(received_qty) AS total_received
FROM receiving_master
GROUP BY DATE_FORMAT(receipt_date, '%Y-%m')
ORDER BY month;


--  10Supplier_Performance
SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(r.receipt_id) AS total_receipts,
    SUM(r.received_qty) AS total_received,
    AVG(r.lead_time_days) AS avg_lead_time
FROM receiving_master r
JOIN supplier_master s
    ON r.supplier_id = s.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
ORDER BY total_received DESC;

-- 11 Supplier_On_Time_Dilivery
SELECT
    s.supplier_name,

    COUNT(r.receipt_id) AS total_receipts,

    SUM(
        CASE
            WHEN r.on_time = 'Yes' THEN 1
            ELSE 0
        END
    ) AS on_time_receipts,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN r.on_time = 'Yes' THEN 1
                ELSE 0
            END
        ) / COUNT(r.receipt_id),
        2
    ) AS on_time_percentage

FROM receiving_master r

JOIN supplier_master s
    ON r.supplier_id = s.supplier_id

GROUP BY s.supplier_id, s.supplier_name
ORDER BY on_time_percentage DESC;

-- 12PO RECEIVED_QUANTITY

SELECT
    s.supplier_name,

    SUM(r.po_quantity) AS total_po_quantity,

    SUM(r.received_qty) AS total_received,

    SUM(r.po_quantity - r.received_qty) AS pending_quantity

FROM receiving_master r

JOIN supplier_master s
    ON r.supplier_id = s.supplier_id

GROUP BY
    s.supplier_id,
    s.supplier_name

ORDER BY pending_quantity DESC;

--  13Current_Inventory_By_Depot
SELECT
    d.depot_name,
    SUM(i.closing_stock) AS current_stock
FROM inventory_master i
JOIN depot_master d
    ON i.depot_id = d.depot_id
GROUP BY d.depot_name
ORDER BY current_stock DESC;

-- Inventory_value
SELECT
    SUM(i.closing_stock * p.unit_cost) AS inventory_value
FROM inventory_master i
JOIN product_data p
    ON i.product_id = p.product_id;
    
    -- INVENTORY BY CATEGORY
SELECT
p.category,
SUM(i.closing_stock) AS stock_quantity,
SUM(i.closing_stock * p.unit_cost) AS inventory_value
FROM inventory_master i
JOIN product_data p
    ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY inventory_value DESC;

-- 16Current_Stock by product and depot
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        date,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    li.depot_id,
    d.depot_name,
    li.product_id,
    p.product_name,
    p.category,
    li.date,
    li.closing_stock AS current_stock
FROM latest_inventory li
JOIN depot_master d
    ON li.depot_id = d.depot_id
JOIN product_data p
    ON li.product_id = p.product_id
WHERE li.rn = 1
ORDER BY li.closing_stock DESC;

-- Total Current_Stock
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    SUM(closing_stock) AS total_current_inventory
FROM latest_inventory
WHERE rn = 1;

-- Current_inventory_value
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    SUM(li.closing_stock * p.unit_cost) AS current_inventory_value
FROM latest_inventory li
JOIN product_data p
    ON li.product_id = p.product_id
WHERE li.rn = 1;

-- Current_Inventory_By_Depot
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        date,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    li.depot_id,
    d.depot_name,
    SUM(li.closing_stock) AS current_stock
FROM latest_inventory li
JOIN depot_master d
    ON li.depot_id = d.depot_id
WHERE li.rn = 1
GROUP BY li.depot_id, d.depot_name
ORDER BY current_stock DESC;

-- Current_inventory_by_category
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    p.category,
    SUM(li.closing_stock) AS current_stock
FROM latest_inventory li
JOIN product_data p
    ON li.product_id = p.product_id
WHERE li.rn = 1
GROUP BY p.category
ORDER BY current_stock DESC;

-- 21 Low Stock Products
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        date,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
)

SELECT
    li.depot_id,
    d.depot_name,
    li.product_id,
    p.product_name,
    p.category,
    li.closing_stock AS current_stock
FROM latest_inventory li
JOIN depot_master d
    ON li.depot_id = d.depot_id
JOIN product_data p
    ON li.product_id = p.product_id
WHERE li.rn = 1
  AND li.closing_stock <= 100
ORDER BY li.closing_stock ASC;

-- 22slow moving_product
SELECT
    s.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS units_sold,
    SUM(s.net_sales) AS net_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
WHERE s.date >= DATE_SUB(
    (SELECT MAX(date) FROM sales_master),
    INTERVAL 6 MONTH
)
GROUP BY
    s.product_id,
    p.product_name,
    p.category
ORDER BY units_sold ASC
LIMIT 10;

-- 23Fast_Moving_Products
SELECT
    s.product_id,
    p.product_name,
    p.category,
    SUM(s.quantity) AS units_sold,
    SUM(s.net_sales) AS net_sales
FROM sales_master s
JOIN product_data p
    ON s.product_id = p.product_id
WHERE s.date >= DATE_SUB(
    (SELECT MAX(date) FROM sales_master),
    INTERVAL 6 MONTH
)
GROUP BY
    s.product_id,
    p.product_name,
    p.category
ORDER BY units_sold DESC
LIMIT 10;


-- 24___Days OF inventory

WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
),

last_6_month_sales AS (
    SELECT
        product_id,
        SUM(quantity) AS units_sold
    FROM sales_master
    WHERE date >= DATE_SUB(
        (SELECT MAX(date) FROM sales_master),
        INTERVAL 6 MONTH
    )
    GROUP BY product_id
)

SELECT
    li.product_id,
    p.product_name,
    p.category,
    SUM(li.closing_stock) AS current_stock,
    COALESCE(s.units_sold, 0) AS units_sold_6_months,

    ROUND(
        COALESCE(s.units_sold, 0) / 180,
        2
    ) AS avg_daily_sales,

    CASE
        WHEN COALESCE(s.units_sold, 0) = 0 THEN NULL
        ELSE ROUND(
            SUM(li.closing_stock) /
            (s.units_sold / 180),
            2
        )
    END AS days_of_inventory

FROM latest_inventory li

JOIN product_data p
    ON li.product_id = p.product_id

LEFT JOIN last_6_month_sales s
    ON li.product_id = s.product_id

WHERE li.rn = 1

GROUP BY
    li.product_id,
    p.product_name,
    p.category,
    s.units_sold

ORDER BY days_of_inventory ASC;

-- 25 Replinishment Candidates
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
),

sales_6_months AS (
    SELECT
        product_id,
        SUM(quantity) AS units_sold
    FROM sales_master
    WHERE date >= DATE_SUB(
        (SELECT MAX(date) FROM sales_master),
        INTERVAL 6 MONTH
    )
    GROUP BY product_id
)

SELECT
    li.depot_id,
    d.depot_name,
    li.product_id,
    p.product_name,
    p.category,
    li.closing_stock AS current_stock,

    s.lead_time_days,

    ROUND(
        COALESCE(s6.units_sold, 0) / 180,
        2
    ) AS avg_daily_sales,

    ROUND(
        (COALESCE(s6.units_sold, 0) / 180)
        * s.lead_time_days,
        2
    ) AS reorder_point,

    CASE
        WHEN li.closing_stock <
             ((COALESCE(s6.units_sold, 0) / 180) * s.lead_time_days)
        THEN 'Replenishment Required'
        ELSE 'Stock Sufficient'
    END AS replenishment_status

FROM latest_inventory li

JOIN depot_master d
    ON li.depot_id = d.depot_id

JOIN product_data p
    ON li.product_id = p.product_id

JOIN supplier_master s
    ON p.supplier_id = s.supplier_id

LEFT JOIN sales_6_months s6
    ON li.product_id = s6.product_id

WHERE li.rn = 1

ORDER BY
    replenishment_status DESC,
    li.closing_stock ASC;

-- 26 Depot Performance
WITH latest_inventory AS (
    SELECT
        depot_id,
        product_id,
        closing_stock,
        ROW_NUMBER() OVER (
            PARTITION BY depot_id, product_id
            ORDER BY date DESC
        ) AS rn
    FROM inventory_master
),

depot_inventory AS (
    SELECT
        li.depot_id,
        SUM(li.closing_stock) AS current_stock,
        SUM(li.closing_stock * p.unit_cost) AS inventory_value
    FROM latest_inventory li
    JOIN product_data p
        ON li.product_id = p.product_id
    WHERE li.rn = 1
    GROUP BY li.depot_id
),

depot_sales AS (
    SELECT
        depot_id,
        SUM(quantity) AS units_sold,
        SUM(net_sales) AS net_sales
    FROM sales_master
    GROUP BY depot_id
)

SELECT
    d.depot_id,
    d.depot_name,
    d.city,
    d.region,

    COALESCE(ds.units_sold, 0) AS units_sold,
    COALESCE(ds.net_sales, 0) AS net_sales,
    COALESCE(di.current_stock, 0) AS current_stock,
    COALESCE(di.inventory_value, 0) AS inventory_value

FROM depot_master d

LEFT JOIN depot_sales ds
    ON d.depot_id = ds.depot_id

LEFT JOIN depot_inventory di
    ON d.depot_id = di.depot_id

ORDER BY net_sales DESC;






     