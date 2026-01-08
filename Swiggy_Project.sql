--******************************************************** Swiggy DataBase ** ********************************************************
--============================================== Data validation & cleaning ==============================================
------------------------------------ Nulll Check
SELECT
	SUM (CASE WHEN [State] IS NULL THEN 1 ELSE 0 END) AS null_state,
	SUM (CASE WHEN [City] IS NULL THEN 1 ELSE 0 END) AS null_city,
	SUM (CASE WHEN [Order_Date] IS NULL THEN 1 ELSE 0 END) AS null_date,
	SUM (CASE WHEN [Restaurant_Name] IS NULL THEN 1 ELSE 0 END) AS null_resturant,
	SUM (CASE WHEN [Location] IS NULL THEN 1 ELSE 0 END) AS null_location,
	SUM (CASE WHEN [Category] IS NULL THEN 1 ELSE 0 END) AS null_category,
	SUM (CASE WHEN [Dish_Name] IS NULL THEN 1 ELSE 0 END) AS null_dish,
	SUM (CASE WHEN [Price_INR] IS NULL THEN 1 ELSE 0 END) AS null_price,
	SUM (CASE WHEN [Rating] IS NULL THEN 1 ELSE 0 END) AS null_rating,
	SUM (CASE WHEN [Rating_Count] IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM [Swiggy_DB].[dbo].[swiggy_Data]

------------------------------------ Blank or Empty String
SELECT
	*
FROM [Swiggy_DB].[dbo].[swiggy_Data]
WHERE [State] = '' OR [City] = '' OR [Restaurant_Name] = '' OR [Location] = '' OR [Category] = '' OR [Dish_Name] = '' OR [Price_INR] = ''

------------------------------------ Duplicate Detection
SELECT
	 [State], [City], [Order_Date], [Restaurant_Name], [Location], [Category], [Dish_Name], [Price_INR], [Rating], [Rating_Count], COUNT(*) AS CNT
FROM [Swiggy_DB].[dbo].[swiggy_Data]
GROUP BY [State], [Order_Date], [City], [Restaurant_Name], [Location], [Category], [Dish_Name], [Price_INR], [Rating], [Rating_Count]
HAVING COUNT(*) >1

------------------------------------ Renmove Duplicate
WITH CTE AS (
	SELECT *, ROW_NUMBER() OVER(
			PARTITION BY State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count
			ORDER BY( SELECT NULL)
		) AS rn
	FROM [Swiggy_DB].[dbo].[swiggy_Data]
)
DELETE FROM CTE WHERE rn>1

--============================================== Creating Schema ==============================================
--======================================= Dimentional Tables =======================================
------------------------------------ Date Table
CREATE TABLE Dim_Date(
	Date_Id INT IDENTITY(1,1) PRIMARY KEY,
	Full_Date DATE,
	Year INT,
	Month INT,
	Month_Name VARCHAR(20),
	Quarter INT,
	Day INT,
	Week INT
)
 
------------------------------------ Location Table
CREATE TABLE Dim_Location(
	Location_Id INT IDENTITY(1,1) PRIMARY KEY,
	State VARCHAR(100),
	City VARCHAR(100),
	Location VARCHAR(200),
)

------------------------------------ Restaurant Table
CREATE TABLE Dim_Restaurant(
	Restaurant_Id INT IDENTITY(1,1) PRIMARY KEY,
	Restaurant_Name VARCHAR(200)
)

------------------------------------ Category Table
CREATE TABLE Dim_Category(
	Category_Id INT IDENTITY(1,1) PRIMARY KEY,
	Category_Name VARCHAR(200)
)

------------------------------------ Dish Table
CREATE TABLE Dim_Dish(
	Dish_Id INT IDENTITY(1,1) PRIMARY KEY,
	Dish_Name VARCHAR(200)
)

--======================================= Fact Table =======================================
CREATE TABLE Fact_Orders(
	Order_Id INT IDENTITY(1,1) PRIMARY KEY,
	Date_Id INT,
	Price_INR DECIMAL(10,2),
	Rating DECIMAL (4,2),
	Rating_Count INT,

	Location_Id INT,
	Restaurant_Id INT,
	Category_Id INT,
	Dish_Id INT,

	FOREIGN KEY (Date_Id) REFERENCES Dim_Date(Date_Id),
	FOREIGN KEY (Location_Id) REFERENCES Dim_Location(Location_Id),
	FOREIGN KEY (Restaurant_Id) REFERENCES Dim_Restaurant(Restaurant_Id),
	FOREIGN KEY (Category_Id) REFERENCES Dim_Category(Category_Id),
	FOREIGN KEY (Dish_Id) REFERENCES Dim_Dish(Dish_Id),
)

--============================================== Insert Date Schema ==============================================
------------------------------------ Date
INSERT INTO Dim_Date( Full_Date, Year, Month, Month_Name, Quarter, Day, Week)
SELECT DISTINCT 
	Order_Date, YEAR(Order_Date), MONTH(Order_Date), DATENAME(Month,Order_Date), DATEPART(Quarter, Order_Date), DAY(Order_Date), DATEPART(week,Order_Date)
FROM swiggy_Data
WHERE Order_Date IS NOT NULL

------------------------------------Location
INSERT INTO Dim_Location(State,City,Location)
SELECT DISTINCT State, City, Location FROM swiggy_Data

------------------------------------ Restaurant
INSERT INTO Dim_Restaurant (Restaurant_Name)
SELECT DISTINCT Restaurant_Name FROM swiggy_Data

------------------------------------ Category
INSERT INTO Dim_Category(Category_Name)
SELECT DISTINCT Category FROM swiggy_Data

------------------------------------ Dish
INSERT INTO Dim_Dish(Dish_Name)
SELECT DISTINCT Dish_Name FROM swiggy_Data

------------------------------------ Fact
INSERT INTO Fact_Orders(Date_Id, Price_INR, Rating, Rating_Count, Location_Id, Restaurant_Id, Category_Id, Dish_Id)
SELECT
	dd.Date_Id, S.Price_INR, S.Rating, S.Rating_Count, dl.Location_Id, dr.Restaurant_Id, dc.Category_Id, ds.Dish_Id
FROM swiggy_Data S
JOIN Dim_Date dd ON (dd.Full_Date = S.Order_Date)
JOIN Dim_Location dl ON (dl.Location = S.Location AND dl.City = S.City AND dl.State = S.State)
JOIN Dim_Restaurant dr ON (dr.Restaurant_Name = S.Restaurant_Name)
JOIN Dim_Category dc ON (dc.Category_Name = S.Category)
JOIN Dim_Dish ds ON (ds.Dish_Name = S.Dish_Name)


--============================================== KPI's ==============================================
------------------------------------ Total Orders
SELECT COUNT(*) AS Total_Orders
FROM Fact_Orders

------------------------------------ Total Revenue
SELECT FORMAT(SUM(CONVERT(FLOAT,Price_INR))/1000000, 'N2')+' INR Million' AS Total_Revenue
FROM Fact_Orders

------------------------------------ Average Dish Price
SELECT FORMAT(AVG(CONVERT(FLOAT, Price_INR)), 'N2')+' INR' AS Average_Dish_Price
FROM Fact_Orders

------------------------------------ Average Rating
SELECT FORMAT(AVG(CONVERT(FLOAT, Rating)), 'N2')+ ' INR' AS Average_Rating
FROM Fact_Orders

--============================================== Monthly Order Trends ==============================================
SELECT D.Year, D.Month, D.Month_Name, COUNT(Order_Id) Total_Orders
FROM Fact_Orders F
JOIN Dim_Date D ON (D.Date_Id = F.Date_Id)
GROUP BY D.Year, D.Month, D.Month_Name
ORDER BY COUNT(Order_Id) DESC

--============================================== Quarterly Order Trends ==============================================
SELECT D.Year, D.Quarter, COUNT(Order_Id) Total_Orders
FROM Fact_Orders F
JOIN Dim_Date D ON (D.Date_Id = F.Date_Id)
GROUP BY D.Year, D.Quarter
ORDER BY COUNT(Order_Id) DESC

--============================================== Year-wise growth ==============================================
SELECT D.Year, COUNT(Order_Id) Total_Orders
FROM Fact_Orders F
JOIN Dim_Date D ON (D.Date_Id = F.Date_Id)
GROUP BY D.Year
ORDER BY COUNT(Order_Id) DESC

--============================================== Day of Week Patterns ==============================================
SELECT D.Year, DATENAME(weekday,D.Full_Date) DayName, COUNT(Order_Id) Total_Orders
FROM Fact_Orders F
JOIN Dim_Date D ON (D.Date_Id = F.Date_Id)
GROUP BY D.Year, DATENAME(weekday,D.Full_Date)
ORDER BY COUNT(Order_Id) DESC

--============================================== Top 10 Cities by Order Volume ==============================================
SELECT TOP 10 L.City, COUNT(F.Order_Id) AS Total_Orders
FROM Fact_Orders F
JOIN Dim_Location L ON (L.Location_Id = F.Location_Id)
GROUP BY L.City
ORDER BY COUNT(F.Order_Id) 

--============================================== Revenue Contribution by States ==============================================
SELECT L.State, SUM(F.Price_INR) AS Total_Revenue
FROM Fact_Orders F
JOIN Dim_Location L ON (L.Location_Id = F.Location_Id)
GROUP BY L.State

--============================================== Top 10 Restaurants by Orders ==============================================
SELECT TOP 10
	R.Restaurant_Name, COUNT(F.Order_Id) AS Total_Orders
FROM Fact_Orders F
JOIN Dim_Restaurant R ON (R.Restaurant_Id = F.Restaurant_Id)
GROUP BY R.Restaurant_Name
ORDER BY COUNT(F.Order_Id) DESC

--============================================== Top Categories ==============================================
SELECT
	C.Category_Name, COUNT(F.Order_Id) AS Total_Orders
FROM Fact_Orders F
JOIN Dim_Category C ON (C.Category_Id = F.Category_Id)
GROUP BY C.Category_Name
ORDER BY COUNT(F.Order_Id) DESC

--============================================== Most Odered Dishes ==============================================
SELECT D.Dish_Name, COUNT(F.Order_Id) AS Total_Orders
FROM Fact_Orders F
JOIN Dim_Dish D ON (D.Dish_Id = F.Dish_Id)
GROUP BY D.Dish_Name
ORDER BY COUNT(F.Order_Id) DESC

--============================================== Cuisine Performance ==============================================
SELECT
	C.Category_Name, COUNT(F.Order_Id) AS Total_Orders, AVG(F.Rating) AS Avg_Rating
FROM Fact_Orders F
JOIN Dim_Category C ON (C.Category_Id = F.Category_Id)
GROUP BY C.Category_Name
ORDER BY COUNT(F.Order_Id) DESC

--============================================== Customer Spending Insights ==============================================
SELECT
	CASE
		WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199' 
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299' 
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 499 THEN '300 - 499' 
		ELSE '500+' 
	END AS Price_Range,
	COUNT(Order_Id) AS Total_Orders
FROM Fact_Orders F
GROUP BY
	CASE
		WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199' 
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299' 
		WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 499 THEN '300 - 499' 
		ELSE '500+' 
	END
ORDER BY Total_Orders DESC

--============================================== Ratings Analysis ==============================================
SELECT
	Rating, COUNT(Order_Id) AS Total_Orders
FROM Fact_Orders
GROUP BY Rating
ORDER BY Rating DESC