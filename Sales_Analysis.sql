SELECT *
FROM Sales_data;

SELECT *
FROM Sales_data
WHERE TRY_CAST(SALES AS FLOAT) IS NULL;

ALTER TABLE Sales_data
ALTER COLUMN SALES FLOAT;

EXEC sp_help 'Sales_data';


-- Questions to be Answered

-- 1. What is the total sales per year and per quarter?

WITH SalesByQuater AS 
(
SELECT
SUM(SALES) AS total_sales,
QTR_ID,
YEAR_ID
FROM Sales_data
GROUP BY QTR_ID,
	YEAR_ID )

SELECT 
ROUND(SUM(total_sales),2) AS TotalSales,
QTR_ID AS Quater,
YEAR_ID AS Year
FROM SalesByQuater
GROUP BY YEAR_ID,
		QTR_ID
ORDER BY 3


-- 2. What is the average order value per customer?
WITH AverageOrderValue AS (
SELECT
CUSTOMERNAME,
SUM(QUANTITYORDERED) AS TotalOrder,
ROUND(SUM(SALES),2) AS TotalSales
FROM Sales_data
GROUP BY CUSTOMERNAME )

SELECT 
CUSTOMERNAME,
TotalOrder,
TotalSales,
ROUND((TotalSales/TotalOrder),2) AS AverageOrderValue
FROM AverageOrderValue
GROUP BY CUSTOMERNAME,
		TotalOrder,
		TotalSales;

-- 3. Which month had the highest total sales?
WITH Monthly_Totals AS (
	SELECT 
	MONTH_ID,
	SUM(SALES) AS TotalSales
	FROM Sales_data
	GROUP BY MONTH_ID
	)
SELECT
DATENAME(MONTH, DATEFROMPARTS(2025, MONTH_ID, 1)) AS Month_Name, -- Converts the Month Number to actual month
ROUND(TotalSales,2) AS TotalSales,
RANK() OVER (ORDER BY TotalSales DESC) AS SalesRank
FROM Monthly_Totals;

-- 4 Calculate month-over-month sales growth?
WITH MonthOverMonth AS (
	SELECT
		MONTH_ID,
		SUM(SALES) AS TotalSales
	FROM Sales_data
	GROUP BY MONTH_ID
)


-- Use LAG to compare current month sales with previous month's sale
SELECT 
	DATENAME(MONTH, DATEFROMPARTS(2025, MONTH_ID, 1)) AS Month_Name,
	ROUND(TotalSales, 2) AS TotalSales,
	LAG(TotalSales) OVER (ORDER BY MONTH_ID) AS PrevMonthSales,
	TotalSales - LAG(TotalSales) OVER (ORDER BY MONTH_ID) AS MonthlyDifference,
	ROUND(
		CASE 
			WHEN LAG(TotalSales) OVER (ORDER BY MONTH_ID) IS NULL THEN NULL
			WHEN LAG(TotalSales) OVER (ORDER BY MONTH_ID) = 0 THEN NULL
			ELSE ((TotalSales - LAG(TotalSales) OVER (ORDER BY MONTH_ID)) * 1.0 / LAG(TotalSales) OVER (ORDER BY MONTH_ID)) * 100
		END
	, 2) AS MonthlyGrowthPercent
FROM MonthOverMonth
ORDER BY MONTH_ID;



-- Customer Analysis
-- 5 Which customers placed the most orders?

WITH CustomerOrderCount AS (
    SELECT 
        CUSTOMERNAME,
        COUNT(DISTINCT ORDERNUMBER) AS TotalOrders
    FROM Sales_data
    GROUP BY CUSTOMERNAME
)
SELECT 
    CUSTOMERNAME,
    TotalOrders
FROM CustomerOrderCount
ORDER BY 2 DESC;

-- 6. Identify customers who placed orders in every quarter of a year

WITH CustomerDetails AS 
( 
SELECT
DISTINCT CUSTOMERNAME,
QTR_ID,
YEAR_ID
FROM Sales_data ),

CountOfQuaters AS
(
SELECT CUSTOMERNAME,
COUNT(DISTINCT QTR_ID) AS QuaterCount,
YEAR_ID
FROM CustomerDetails
GROUP BY CUSTOMERNAME,
		YEAR_ID )

SELECT 
CUSTOMERNAME,
QuaterCount,
YEAR_ID
FROM CountOfQuaters
WHERE QuaterCount = 4;


-- Product Analysis
-- 7. Which product lines generate the most revenue?

SELECT
PRODUCTLINE,
ROUND(SUM(SALES),2) AS TotalSales
FROM Sales_data
GROUP BY PRODUCTLINE;

-- 8. Calculate the difference between MSRP and average selling price per product


WITH avg_price AS (
    SELECT
        PRODUCTCODE,
		PRODUCTLINE,
		MSRP,
        AVG(PRICEEACH) AS AvgSellingPrice
    FROM Sales_data
    GROUP BY PRODUCTCODE,
			PRODUCTLINE,
			MSRP
)

SELECT
    PRODUCTCODE,
    PRODUCTLINE,
    MSRP,
    ROUND(AvgSellingPrice, 2) AS AvgSellPrice,
    ROUND((MSRP - AvgSellingPrice), 2) AS PriceDifference
FROM avg_price
GROUP BY 
PRODUCTCODE, 
PRODUCTLINE,
MSRP,
AvgSellingPrice
ORDER BY PriceDifference DESC;

-- 9. Identify underperforming products (low sales & low quantity ordered)

-- Step 1: Calculate total sales and quantity for each product line
WITH product_totals AS (
    SELECT
        PRODUCTLINE,
        ROUND(SUM(SALES),2) AS TotalSales,
        SUM(QUANTITYORDERED) AS TotalQuantity
    FROM Sales_data
    GROUP BY PRODUCTLINE
),

-- Step 2: Compute the average sales and quantity across all product lines
product_averages AS (
    SELECT
        ROUND(AVG(TotalSales),2) AS AvgSales,
        AVG(TotalQuantity) AS AvgQuantity
    FROM product_totals
)

-- Step 3: Identify underperforming product lines and include benchmark columns
SELECT
    pt.PRODUCTLINE,
    pt.TotalSales,
    pa.AvgSales AS BenchmarkAvgSales,
    pt.TotalQuantity,
    pa.AvgQuantity AS BenchmarkAvgQuantity
FROM product_totals pt
JOIN product_averages pa ON 1=1
WHERE
    pt.TotalSales < pa.AvgSales AND
    pt.TotalQuantity < pa.AvgQuantity
ORDER BY 
    pt.TotalSales ASC,
    pt.TotalQuantity ASC;



-- Time Series / Trend Analysis
-- 10. What is the trend of sales over time (monthly or quarterly)?

SELECT
QTR_ID,
YEAR_ID,
ROUND(SUM(SALES),2) AS TotalSales
FROM Sales_data
GROUP BY QTR_ID,
           YEAR_ID
ORDER BY YEAR_ID,
          QTR_ID;

-- 11. Rank months by sales within each year
WITH monthly_sales AS (
    SELECT
        YEAR_ID,
        MONTH_ID,
        DATENAME(MONTH, DATEFROMPARTS(YEAR_ID, MONTH_ID, 1)) AS Month_Name,
        ROUND(SUM(SALES),2) AS TotalSales
    FROM Sales_data
    GROUP BY YEAR_ID,
            MONTH_ID,
            DATENAME(MONTH, DATEFROMPARTS(YEAR_ID, MONTH_ID, 1))   
)

SELECT
    YEAR_ID,
    Month_Name,
    TotalSales,
    RANK() OVER (PARTITION BY YEAR_ID ORDER BY TotalSales DESC) AS SalesRank
FROM monthly_sales
ORDER BY YEAR_ID, SalesRank;

-- 12. Calculate cumulative sales by month per year.

WITH monthly_sales AS (
    SELECT
        YEAR_ID,
        MONTH_ID,
       ROUND(SUM(SALES),2) AS TotalSales
    FROM Sales_data
    GROUP BY YEAR_ID,
            MONTH_ID
)

SELECT
    YEAR_ID,
    DATENAME(MONTH, DATEFROMPARTS(YEAR_ID, MONTH_ID, 1)) AS Month_Name,
    TotalSales,
    SUM(TotalSales) OVER (PARTITION BY YEAR_ID ORDER BY MONTH_ID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CumulativeSales
FROM monthly_sales
ORDER BY YEAR_ID, MONTH_ID;




