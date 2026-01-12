--******************************************************** Monday Coffee DataBase ** ********************************************************
--============================================== Create Schema ==============================================
------------------------------------ City Table
CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
)

------------------------------------ Customer Table
CREATE TABLE customer
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
)

------------------------------------ Product Table
CREATE TABLE product
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
)

------------------------------------ Sales Table
CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
)

--============================================== Report & Data Analysis ==============================================
--## Key Questions
-- 1. **Coffee Consumers Count**  
--   How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT
	City_Name, FORMAT((Population*0.25)/1000000,'N2') AS Coffee_Counsumer_In_Millions
FROM city
ORDER BY 2 DESC

--2. **Total Revenue from Coffee Sales**  
--   What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

SELECT
	FORMAT(SUM(Total)/1000000,'N2')+' M' AS Total_Revenue
FROM Sales
WHERE 
	(YEAR(sale_date) = 2023) AND (DATEPART(Quarter, sale_date) = 4)

--3. **Sales Count for Each Product**  
--   How many units of each coffee product have been sold?

SELECT P.Product_Name, COUNT(S.Sale_Id) AS Total_Orders
FROM Sales S
JOIN Product P ON (P.Product_Id = S.Product_Id)
GROUP BY P.Product_Name
ORDER BY 2 DESC

--4. **Average Sales Amount per City**  
--   What is the average sales amount per customer in each city?

SELECT 
	CI.City_Name, SUM(S.Total) AS Total_Revenue, COUNT(DISTINCT C.Customer_Id) AS Total_Customer,
        Format((SUM(S.Total)/ COUNT(DISTINCT C.Customer_Id)),'N2'
) AS Avg_Amount_Per_Cust_City
FROM Sales S
JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
JOIN City CI ON (CI.City_Id = C.City_Id)
GROUP BY CI.City_Name
ORDER BY SUM(S.Total)

--5. **City Population and Coffee Consumers**  
--   Provide a list of cities along with their populations and estimated coffee consumers.
WITH City_Table AS(
	SELECT 
		City_Name, FORMAT((Population*0.25)/1000000,'N2') AS Coffee_Consumer
	FROM City
),

Customer_Table AS(
	SELECT 
		CI.City_Name, COUNT(DISTINCT C.Customer_Id) AS Unique_Customer
	FROM Sales S
	JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
	JOIN City CI ON (CI.City_Id = C.City_Id)
	GROUP BY CI.City_Name
)

SELECT CT.City_Name,Unique_Customer, Coffee_Consumer AS Coffee_Consumer_In_Millions
FROM Customer_Table AS CT
JOIN City_Table CI ON (CT.City_Name = CI.City_Name)

--6. **Top Selling Products by City**  
--   What are the top 3 selling products in each city based on sales volume?

SELECT *
FROM
(
SELECT
	CI.City_Name,  P.Product_Name, COUNT(S.Sale_Id) Total_Orders, DENSE_RANK() OVER(PARTITION BY CI.City_Name ORDER BY COUNT(S.Sale_Id) DESC) AS Rank
FROM sales S
JOIN product P ON (P.product_id = S.product_id)
JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
JOIN City CI ON (CI.City_Id = C.City_Id)
GROUP BY CI.City_Name,  P.Product_Name
) AS TL
WHERE Rank <=3

--7. **Customer Segmentation by City**  
--   How many unique customers are there in each city who have purchased coffee products?

SELECT
	CI.City_Name, COUNT(DISTINCT C.Customer_Id) AS Unique_Customer
FROM City CI
JOIN Customer C ON (C.City_Id = CI.City_Id)
JOIN Sales S ON (S.Customer_Id = C.Customer_Id)
WHERE S.Product_Id BETWEEN 1 AND 14
GROUP BY CI.City_Name
ORDER BY COUNT(DISTINCT C.Customer_Id) DESC

--8. **Average Sale vs Rent**  
--   Find each city and their average sale per customer and avg rent per customer

SELECT
	CI.City_Name, ROUND(SUM(CONVERT(FLOAT,S.Total)) / COUNT(DISTINCT C.Customer_Id),2) AS Avg_Sales,
	ROUND(CONVERT(FLOAT,CI.Estimated_Rent) / COUNT(DISTINCT C.Customer_Id),2) AS Avg_Rent
FROM Sales S
JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
JOIN City CI ON (CI.City_Id = C.City_Id)
GROUP BY CI.City_Name, CI.Estimated_Rent
ORDER BY CI.City_Name

--9. **Monthly Sales Growth**  
--   Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly) by city.

WITH Monthly_Sales AS
(
	SELECT 
		CI.City_Name, MONTH(S.sale_date) AS Month, YEAR(S.sale_date) AS Year, SUM(S.Total) AS Cr_Month_Sales
	FROM Sales S
	JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
	JOIN City CI ON ( CI.City_Id = C.City_Id)
	GROUP BY CI.City_Name, MONTH(S.sale_date), YEAR(S.sale_date) 
),
Growth_Ratio AS
(
	SELECT 
		City_Name, Month, Year, Cr_Month_Sales, LAG(Cr_Month_Sales,1) OVER(PARTITION BY City_Name ORDER BY Year,Month) AS La_Month_Sale
	FROM Monthly_Sales
	--GROUP BY City_Name, Month, Year, Cr_Month_Sales
)
SELECT
	City_Name, Month, Year ,Cr_Month_Sales, La_Month_Sale,
	CASE 
		WHEN La_Month_Sale IS NULL OR La_Month_Sale = 0 THEN NULL
		ELSE ROUND(CONVERT(FLOAT,Cr_Month_Sales-La_Month_Sale)/La_Month_Sale *100,2)
		END AS Growth_Ratio
FROM Growth_Ratio

--10. **Market Potential Analysis**  
--    Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated  coffee consumer

SELECT 
	CI.City_Name, SUM(S.Total) AS Total_Sales, CI.Estimated_Rent AS Total_Rent, COUNT( DISTINCT C.Customer_Id) AS Total_Customer,
	ROUND(CONVERT(FLOAT,(CI.Population * 0.25)/1000000),2) AS Estimated_Coffee_Consumer_In_Million,
	ROUND(SUM(CONVERT(FLOAT,S.Total)) / COUNT(DISTINCT C.Customer_Id),2) AS Avg_Sales,
	ROUND(CONVERT(FLOAT,CI.Estimated_Rent) / COUNT(DISTINCT C.Customer_Id),2) AS Avg_Rent
FROM Sales S
JOIN Customer C ON (C.Customer_Id = S.Customer_Id)
JOIN City CI ON (CI.City_Id = C.City_Id)
GROUP BY CI.City_Name, CI.Estimated_Rent, CI.Population
ORDER BY SUM(S.Total) DESC

--    ######## Recommendations
/*After analyzing the data, the recommended top three cities for new store openings are:

**City 1: Pune**  
1. Average rent per customer is very low.  
2. Highest total revenue.  
3. Average sales per customer is also high.

**City 2: Delhi**  
1. Highest estimated coffee consumers at 7.7 million.  
2. Highest total number of customers, which is 68.  
3. Average rent per customer is 330 (still under 500).

**City 3: Jaipur**  
1. Highest number of customers, which is 69.  
2. Average rent per customer is very low at 156.  
3. Average sales per customer is better at 11.6k.
*/
