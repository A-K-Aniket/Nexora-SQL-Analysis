Create database Nexora_Analytics;
use nexora_Analytics;

-- Dimension tables
CREATE TABLE IF NOT EXISTS DimAccount (
    AccountID INT NOT NULL,
    AccountCode VARCHAR(30),
    AccountName VARCHAR(150),
    AccountType VARCHAR(60),
    AccountGroup VARCHAR(100),
    StatementType VARCHAR(60),
    SortOrder INT,
    SignMultiplier INT,
    PRIMARY KEY (AccountID)
);

CREATE TABLE IF NOT EXISTS DimDate (
    DateKey INT NOT NULL,
    `Date` DATE NOT NULL,
    `Year` SMALLINT,
    Quarter VARCHAR(5),
    QuarterNumber TINYINT,
    MonthNumber TINYINT,
    MonthName VARCHAR(20),
    MonthYear VARCHAR(12),
    MonthStartDate DATE,
    WeekNumber TINYINT,
    DayName VARCHAR(12),
    DayOfWeek TINYINT,
    IsWeekend TINYINT(1),
    PRIMARY KEY (DateKey),
    UNIQUE KEY uq_dimdate_date (`Date`)
);

CREATE TABLE IF NOT EXISTS DimDepartment (
    DepartmentID INT NOT NULL,
    DepartmentName VARCHAR(100),
    DepartmentHead VARCHAR(150),
    CostCenter VARCHAR(30),
    DepartmentType VARCHAR(80),
    PRIMARY KEY (DepartmentID)
);

CREATE TABLE IF NOT EXISTS DimProduct (
    ProductID INT NOT NULL,
    ProductName VARCHAR(200),
    Category VARCHAR(100),
    SubCategory VARCHAR(100),
    Brand VARCHAR(100),
    ProductType VARCHAR(50),
    StandardCost DECIMAL(14,2),
    ListPrice DECIMAL(14,2),
    PRIMARY KEY (ProductID)
);

CREATE TABLE IF NOT EXISTS DimRegion (
    RegionID INT NOT NULL,
    RegionName VARCHAR(100),
    Country VARCHAR(100),
    City VARCHAR(100),
    Market VARCHAR(60),
    RegionalManager VARCHAR(150),
    PRIMARY KEY (RegionID)
);

-- Fact tables
CREATE TABLE IF NOT EXISTS FactSales (
    SalesID INT NOT NULL,
    OrderDate DATE,
    ProductID INT,
    RegionID INT,
    DepartmentID INT,
    AccountID INT,
    Quantity INT,
    UnitPrice DECIMAL(14,2),
    DiscountAmount DECIMAL(14,2),
    GrossSales DECIMAL(14,2),
    NetRevenue DECIMAL(14,2),
    COGS DECIMAL(14,2),
    GrossProfit DECIMAL(14,2),
    PRIMARY KEY (SalesID),
    KEY ix_sales_date (OrderDate),
    KEY ix_sales_product (ProductID),
    KEY ix_sales_region (RegionID),
    KEY ix_sales_department (DepartmentID),
    KEY ix_sales_account (AccountID),
    CONSTRAINT fk_sales_product FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID),
    CONSTRAINT fk_sales_region FOREIGN KEY (RegionID) REFERENCES DimRegion(RegionID),
    CONSTRAINT fk_sales_department FOREIGN KEY (DepartmentID) REFERENCES DimDepartment(DepartmentID),
    CONSTRAINT fk_sales_account FOREIGN KEY (AccountID) REFERENCES DimAccount(AccountID),
    CONSTRAINT fk_sales_date FOREIGN KEY (OrderDate) REFERENCES DimDate(`Date`)
);

CREATE TABLE IF NOT EXISTS FactExpenses (
    ExpenseID INT NOT NULL,
    ExpenseDate DATE,
    DepartmentID INT,
    RegionID INT,
    AccountID INT,
    VendorName VARCHAR(200),
    ExpenseDescription VARCHAR(300),
    ExpenseCategory VARCHAR(100),
    ExpenseAmount DECIMAL(14,2),
    PaymentStatus VARCHAR(50),
    PRIMARY KEY (ExpenseID),
    KEY ix_expenses_date (ExpenseDate),
    KEY ix_expenses_department (DepartmentID),
    KEY ix_expenses_region (RegionID),
    KEY ix_expenses_account (AccountID),
    CONSTRAINT fk_expenses_department FOREIGN KEY (DepartmentID) REFERENCES DimDepartment(DepartmentID),
    CONSTRAINT fk_expenses_region FOREIGN KEY (RegionID) REFERENCES DimRegion(RegionID),
    CONSTRAINT fk_expenses_account FOREIGN KEY (AccountID) REFERENCES DimAccount(AccountID),
    CONSTRAINT fk_expenses_date FOREIGN KEY (ExpenseDate) REFERENCES DimDate(`Date`)
);

CREATE TABLE IF NOT EXISTS FactBudget (
    BudgetID INT NOT NULL,
    MonthStartDate DATE,
    DepartmentID INT,
    RegionID INT,
    AccountID INT,
    BudgetAmount DECIMAL(14,2),
    BudgetVersion VARCHAR(50),
    PRIMARY KEY (BudgetID),
    KEY ix_budget_month (MonthStartDate),
    KEY ix_budget_department (DepartmentID),
    KEY ix_budget_region (RegionID),
    KEY ix_budget_account (AccountID),
    CONSTRAINT fk_budget_department FOREIGN KEY (DepartmentID) REFERENCES DimDepartment(DepartmentID),
    CONSTRAINT fk_budget_region FOREIGN KEY (RegionID) REFERENCES DimRegion(RegionID),
    CONSTRAINT fk_budget_account FOREIGN KEY (AccountID) REFERENCES DimAccount(AccountID)
);


-- ----------------------------------------------------------------------------
-- Q1. Overall Sales & Profitability Summary (2023 - 2025)
-- Business Purpose: Understand total transaction volume, gross sales, 
-- discounts given, net revenue earned, product cost (COGS), and gross profit.
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(SalesID) AS Total_Transactions,
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(SUM(GrossSales), 2) AS Total_Gross_Sales,
    ROUND(SUM(DiscountAmount), 2) AS Total_Discounts,
    ROUND(SUM(NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(COGS), 2) AS Total_COGS,
    ROUND(SUM(GrossProfit), 2) AS Total_Gross_Profit,
    ROUND((SUM(GrossProfit) / SUM(NetRevenue)) * 100, 2) AS Gross_Profit_Margin_Pct
FROM FactSales;

-- ----------------------------------------------------------------------------
-- Q2. Overall Expenses and Budget Summary (Plus BudgetVersion Check)
-- Business Purpose: Check total expenses and inspect BudgetVersion in FactBudget
-- to ensure we don't double-count multiple budget versions.
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(ExpenseID) AS Total_Expense_Records,
    ROUND(SUM(ExpenseAmount), 2) AS Total_Expenses
FROM FactExpenses;

SELECT 
    BudgetVersion,
    COUNT(BudgetID) AS Budget_Records,
    ROUND(SUM(BudgetAmount), 2) AS Total_Budget_Amount
FROM FactBudget
GROUP BY BudgetVersion;

-- ----------------------------------------------------------------------------
-- Q3. Company Dimension Breakdown & Negative Profit Inspection
-- Business Purpose: See the exact list of Regions, Departments, and Product 
-- Categories, and quantify the 90 negative-profit sales transactions.
-- ----------------------------------------------------------------------------
SELECT RegionID, RegionName, Country, City, Market FROM DimRegion;

SELECT DepartmentID, DepartmentName, DepartmentType, CostCenter FROM DimDepartment;

SELECT 
    Category, 
    COUNT(DISTINCT SubCategory) AS SubCategories, 
    COUNT(ProductID) AS Total_Products,
    ROUND(MIN(ListPrice), 2) AS Min_Price,
    ROUND(MAX(ListPrice), 2) AS Max_Price
FROM DimProduct
GROUP BY Category;

-- Inspect the impact of the 90 negative gross profit transactions found in Phase 2
SELECT 
    COUNT(SalesID) AS Negative_Profit_Orders,
    ROUND(SUM(GrossSales), 2) AS Gross_Sales_On_Loss_Orders,
    ROUND(SUM(DiscountAmount), 2) AS Discounts_On_Loss_Orders,
    ROUND(SUM(NetRevenue), 2) AS Net_Revenue_On_Loss_Orders,
    ROUND(SUM(COGS), 2) AS COGS_On_Loss_Orders,
    ROUND(SUM(GrossProfit), 2) AS Total_Loss_Amount
FROM FactSales
WHERE GrossProfit < 0;


-- Combined Phase 3 Baseline Summary (Single Result Grid)
SELECT '1. Total Sales Transactions' AS Metric, COUNT(SalesID) AS Value FROM FactSales
UNION ALL
SELECT '2. Total Units Sold', SUM(Quantity) FROM FactSales
UNION ALL
SELECT '3. Total Gross Sales', ROUND(SUM(GrossSales), 2) FROM FactSales
UNION ALL
SELECT '4. Total Discounts', ROUND(SUM(DiscountAmount), 2) FROM FactSales
UNION ALL
SELECT '5. Total Net Revenue', ROUND(SUM(NetRevenue), 2) FROM FactSales
UNION ALL
SELECT '6. Total COGS', ROUND(SUM(COGS), 2) FROM FactSales
UNION ALL
SELECT '7. Total Gross Profit', ROUND(SUM(GrossProfit), 2) FROM FactSales
UNION ALL
SELECT '8. Gross Profit Margin (%)', ROUND((SUM(GrossProfit) / SUM(NetRevenue)) * 100, 2) FROM FactSales
UNION ALL
SELECT '9. Total Expense Records', COUNT(ExpenseID) FROM FactExpenses
UNION ALL
SELECT '10. Total Expenses Amount', ROUND(SUM(ExpenseAmount), 2) FROM FactExpenses
UNION ALL
SELECT '11. Total Budget Records', COUNT(BudgetID) FROM FactBudget
UNION ALL
SELECT '12. Distinct Budget Versions', COUNT(DISTINCT BudgetVersion) FROM FactBudget
UNION ALL
SELECT CONCAT('13. Budget Total - ', BudgetVersion), ROUND(SUM(BudgetAmount), 2) FROM FactBudget GROUP BY BudgetVersion;



SELECT '1. Total Sales Transactions' AS Metric, COUNT(SalesID) AS Value FROM FactSales
UNION ALL
SELECT '2. Total Units Sold', SUM(Quantity) FROM FactSales
UNION ALL
SELECT '3. Total Gross Sales', ROUND(SUM(GrossSales), 2) FROM FactSales
UNION ALL
SELECT '4. Total Discounts', ROUND(SUM(DiscountAmount), 2) FROM FactSales
UNION ALL
SELECT '5. Total Net Revenue', ROUND(SUM(NetRevenue), 2) FROM FactSales
UNION ALL
SELECT '6. Total COGS', ROUND(SUM(COGS), 2) FROM FactSales
UNION ALL
SELECT '7. Total Gross Profit', ROUND(SUM(GrossProfit), 2) FROM FactSales
UNION ALL
SELECT '8. Gross Profit Margin (%)', ROUND((SUM(GrossProfit) / SUM(NetRevenue)) * 100, 2) FROM FactSales
UNION ALL
SELECT '9. Total Expense Records', COUNT(ExpenseID) FROM FactExpenses
UNION ALL
SELECT '10. Total Expenses Amount', ROUND(SUM(ExpenseAmount), 2) FROM FactExpenses
UNION ALL
SELECT '11. Total Budget Records', COUNT(BudgetID) FROM FactBudget
UNION ALL
SELECT '12. Distinct Budget Versions', COUNT(DISTINCT BudgetVersion) FROM FactBudget
UNION ALL
SELECT CONCAT('13. Budget Total - ', BudgetVersion), ROUND(SUM(BudgetAmount), 2) FROM FactBudget GROUP BY BudgetVersion;

SELECT '1. Total Sales Transactions' AS Metric, COUNT(SalesID) AS Value FROM FactSales
UNION ALL
SELECT '2. Total Units Sold', SUM(Quantity) FROM FactSales
UNION ALL
SELECT '3. Total Gross Sales', ROUND(SUM(GrossSales), 2) FROM FactSales
UNION ALL
SELECT '4. Total Discounts', ROUND(SUM(DiscountAmount), 2) FROM FactSales
UNION ALL
SELECT '5. Total Net Revenue', ROUND(SUM(NetRevenue), 2) FROM FactSales
UNION ALL
SELECT '6. Total COGS', ROUND(SUM(COGS), 2) FROM FactSales
UNION ALL
SELECT '7. Total Gross Profit', ROUND(SUM(GrossProfit), 2) FROM FactSales
UNION ALL
SELECT '8. Gross Profit Margin (%)', ROUND((SUM(GrossProfit) / SUM(NetRevenue)) * 100, 2) FROM FactSales
UNION ALL
SELECT '9. Total Expense Records', COUNT(ExpenseID) FROM FactExpenses
UNION ALL
SELECT '10. Total Expenses Amount', ROUND(SUM(ExpenseAmount), 2) FROM FactExpenses
UNION ALL
SELECT '11. Total Budget Records', COUNT(BudgetID) FROM FactBudget
UNION ALL
SELECT '12. Distinct Budget Versions', COUNT(DISTINCT BudgetVersion) FROM FactBudget
UNION ALL
SELECT CONCAT('13. Budget Total - ', BudgetVersion), ROUND(SUM(BudgetAmount), 2) FROM FactBudget GROUP BY BudgetVersion;


-- ============================================================================
-- File: 04_Sales_Revenue_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Analyze sales, net revenue, COGS, gross profit, AOV, and growth 
--          trends across years, quarters, and months (2023 - 2025).
-- ============================================================================

USE Nexora_Analytics;

-- ----------------------------------------------------------------------------
-- Q4. Annual Sales & Profitability Breakdown (2023 - 2025)
-- Business Purpose: Compare yearly transaction volume, units sold, average 
-- order value (AOV), net revenue, COGS, and gross profit margin by year.
-- ----------------------------------------------------------------------------
SELECT 
    YEAR(OrderDate) AS Sales_Year,
    COUNT(SalesID) AS Total_Orders,
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(AVG(NetRevenue), 2) AS Avg_Order_Value,
    ROUND(SUM(GrossSales), 2) AS Gross_Sales,
    ROUND(SUM(DiscountAmount), 2) AS Discounts,
    ROUND(SUM(NetRevenue), 2) AS Net_Revenue,
    ROUND(SUM(COGS), 2) AS Total_COGS,
    ROUND(SUM(GrossProfit), 2) AS Gross_Profit,
    ROUND((SUM(GrossProfit) / SUM(NetRevenue)) * 100, 2) AS Gross_Margin_Pct
FROM FactSales
GROUP BY YEAR(OrderDate)
ORDER BY Sales_Year;

-- ----------------------------------------------------------------------------
-- Q5. Year-over-Year (YoY) Revenue and Profit Growth
-- Business Purpose: Measure the exact percentage growth in Net Revenue and 
-- Gross Profit from one year to the next using a CTE and LAG().
-- ----------------------------------------------------------------------------
WITH YearlyMetrics AS (
    SELECT 
        YEAR(OrderDate) AS Sales_Year,
        ROUND(SUM(NetRevenue), 2) AS Net_Revenue,
        ROUND(SUM(GrossProfit), 2) AS Gross_Profit
    FROM FactSales
    GROUP BY YEAR(OrderDate)
)
SELECT 
    Sales_Year,
    Net_Revenue,
    LAG(Net_Revenue) OVER (ORDER BY Sales_Year) AS Prev_Year_Revenue,
    ROUND(
        ((Net_Revenue - LAG(Net_Revenue) OVER (ORDER BY Sales_Year)) 
        / LAG(Net_Revenue) OVER (ORDER BY Sales_Year)) * 100, 2
    ) AS Revenue_YoY_Growth_Pct,
    Gross_Profit,
    ROUND(
        ((Gross_Profit - LAG(Gross_Profit) OVER (ORDER BY Sales_Year)) 
        / LAG(Gross_Profit) OVER (ORDER BY Sales_Year)) * 100, 2
    ) AS Profit_YoY_Growth_Pct
FROM YearlyMetrics
ORDER BY Sales_Year;

-- ----------------------------------------------------------------------------
-- Q6. Quarterly Revenue & Profit Breakdown
-- Business Purpose: Join FactSales with DimDate to evaluate quarterly 
-- performance and identify strong vs. weak quarters each year.
-- ----------------------------------------------------------------------------
SELECT 
    d.Year AS Sales_Year,
    d.Quarter,
    COUNT(s.SalesID) AS Total_Orders,
    ROUND(SUM(s.NetRevenue), 2) AS Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Gross_Profit,
    ROUND((SUM(s.GrossProfit) / SUM(s.NetRevenue)) * 100, 2) AS Gross_Margin_Pct
FROM FactSales s
INNER JOIN DimDate d ON s.OrderDate = d.Date
GROUP BY d.Year, d.Quarter, d.QuarterNumber
ORDER BY d.Year, d.QuarterNumber;

-- ----------------------------------------------------------------------------
-- Q7. Overall Monthly Seasonality (2023 - 2025 Combined)
-- Business Purpose: Identify which calendar months generate the highest 
-- and lowest revenue across the 3-year period.
-- ----------------------------------------------------------------------------
SELECT 
    d.MonthNumber,
    d.MonthName,
    COUNT(s.SalesID) AS Total_Orders,
    SUM(s.Quantity) AS Units_Sold,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit
FROM FactSales s
INNER JOIN DimDate d ON s.OrderDate = d.Date
GROUP BY d.MonthNumber, d.MonthName
ORDER BY d.MonthNumber;



-- ============================================================================
-- File: 05_Product_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Analyze product performance, top and bottom sellers, categories, 
--          and gross profit contribution.
-- ============================================================================

USE Nexora_Analytics;

-- ----------------------------------------------------------------------------
-- Q8. Top 5 Products by Net Revenue
-- ----------------------------------------------------------------------------
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    COUNT(s.SalesID) AS Total_Orders,
    SUM(s.Quantity) AS Total_Units_Sold,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit
FROM FactSales s
INNER JOIN DimProduct p ON s.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, p.Category, p.SubCategory
ORDER BY Total_Net_Revenue DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- Q9. Bottom 5 Products by Net Revenue
-- ----------------------------------------------------------------------------
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    COUNT(s.SalesID) AS Total_Orders,
    SUM(s.Quantity) AS Total_Units_Sold,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit
FROM FactSales s
INNER JOIN DimProduct p ON s.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, p.Category, p.SubCategory
ORDER BY Total_Net_Revenue ASC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- Q10. Product Category Performance Breakdown
-- ----------------------------------------------------------------------------
SELECT 
    p.Category,
    COUNT(DISTINCT p.ProductID) AS Product_Count,
    SUM(s.Quantity) AS Total_Units_Sold,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit,
    ROUND((SUM(s.GrossProfit) / SUM(s.NetRevenue)) * 100, 2) AS Gross_Margin_Pct
FROM FactSales s
INNER JOIN DimProduct p ON s.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY Total_Net_Revenue DESC;

-- ============================================================================
-- File: 06_Regional_Department_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Evaluate sales, revenue, and profitability across regions and departments.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Q11. Performance by Region
-- ----------------------------------------------------------------------------
SELECT 
    r.RegionID,
    r.RegionName,
    r.Country,
    COUNT(s.SalesID) AS Total_Orders,
    SUM(s.Quantity) AS Total_Units_Sold,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit,
    ROUND((SUM(s.GrossProfit) / SUM(s.NetRevenue)) * 100, 2) AS Gross_Margin_Pct
FROM FactSales s
INNER JOIN DimRegion r ON s.RegionID = r.RegionID
GROUP BY r.RegionID, r.RegionName, r.Country
ORDER BY Total_Net_Revenue DESC;

-- ----------------------------------------------------------------------------
-- Q12. Performance by Department (Sales & Gross Profit)
-- ----------------------------------------------------------------------------
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    d.DepartmentType,
    COUNT(s.SalesID) AS Total_Orders,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit,
    ROUND((SUM(s.GrossProfit) / SUM(s.NetRevenue)) * 100, 2) AS Gross_Margin_Pct
FROM FactSales s
INNER JOIN DimDepartment d ON s.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentID, d.DepartmentName, d.DepartmentType
ORDER BY Total_Net_Revenue DESC;


-- ============================================================================
-- File: 07_Expense_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Analyze operating expenses by department, category, and vendor.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Q13. Total Expenses by Department
-- ----------------------------------------------------------------------------
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    COUNT(e.ExpenseID) AS Expense_Transactions,
    ROUND(SUM(e.ExpenseAmount), 2) AS Total_Expenses
FROM FactExpenses e
INNER JOIN DimDepartment d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentID, d.DepartmentName
ORDER BY Total_Expenses DESC;

-- ----------------------------------------------------------------------------
-- Q14. Expenses by Category
-- ----------------------------------------------------------------------------
SELECT 
    ExpenseCategory,
    COUNT(ExpenseID) AS Transaction_Count,
    ROUND(SUM(ExpenseAmount), 2) AS Total_Expenses,
    ROUND(AVG(ExpenseAmount), 2) AS Avg_Expense_Amount
FROM FactExpenses
GROUP BY ExpenseCategory
ORDER BY Total_Expenses DESC;

-- ----------------------------------------------------------------------------
-- Q15. Top 5 Expense Vendors
-- ----------------------------------------------------------------------------
SELECT 
    VendorName,
    COUNT(ExpenseID) AS Transaction_Count,
    ROUND(SUM(ExpenseAmount), 2) AS Total_Expenses
FROM FactExpenses
GROUP BY VendorName
ORDER BY Total_Expenses DESC
LIMIT 5;


-- ============================================================================
-- File: 08_Budget_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Compare actual operating expenses against the Revised Budget by department.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q16. Department Budget vs. Actual Expenses (Using Revised Budget)
-- ----------------------------------------------------------------------------
WITH DepartmentBudget AS (
    SELECT 
			DepartmentID,
        SUM(BudgetAmount) AS Total_Budget
    FROM FactBudget
    WHERE BudgetVersion = 'Revised'
    GROUP BY DepartmentID
),
DepartmentActuals AS (
    SELECT 
        DepartmentID,
        SUM(ExpenseAmount) AS Total_Expenses
    FROM FactExpenses
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentName,
    ROUND(b.Total_Budget, 2) AS Revised_Budget,
    ROUND(a.Total_Expenses, 2) AS Actual_Expenses,
    ROUND(a.Total_Expenses - b.Total_Budget, 2) AS Budget_Variance,
    ROUND((a.Total_Expenses / b.Total_Budget) * 100, 2) AS Budget_Utilization_Pct
FROM DepartmentBudget b
INNER JOIN DepartmentActuals a ON b.DepartmentID = a.DepartmentID
INNER JOIN DimDepartment d ON b.DepartmentID = d.DepartmentID
ORDER BY Budget_Utilization_Pct DESC;

-- ============================================================================
-- File: 09_Advanced_Analysis.sql
-- Project: Nexora Technologies & Retail – Business Performance Analysis
-- Purpose: Intermediate advanced queries using CTEs and window functions 
--          (Running totals and regional ranking).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q17. Running Total of Net Revenue Over Time (Chronological Order)
-- ----------------------------------------------------------------------------
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(s.OrderDate, '%Y-%m-01') AS Month_Start,
        ROUND(SUM(s.NetRevenue), 2) AS Monthly_Revenue
    FROM FactSales s
    GROUP BY DATE_FORMAT(s.OrderDate, '%Y-%m-01')
)
SELECT 
    Month_Start,
    Monthly_Revenue,
    ROUND(SUM(Monthly_Revenue) OVER (ORDER BY Month_Start), 2) AS Running_Total_Revenue
FROM MonthlyRevenue
ORDER BY Month_Start;

-- ----------------------------------------------------------------------------
-- Q18. Regional Profitability Ranking using Window Functions
-- ----------------------------------------------------------------------------
SELECT 
    r.RegionName,
    ROUND(SUM(s.NetRevenue), 2) AS Total_Net_Revenue,
    ROUND(SUM(s.GrossProfit), 2) AS Total_Gross_Profit,
    RANK() OVER (ORDER BY SUM(s.GrossProfit) DESC) AS Profit_Rank
FROM FactSales s
INNER JOIN DimRegion r ON s.RegionID = r.RegionID
GROUP BY r.RegionID, r.RegionName;
