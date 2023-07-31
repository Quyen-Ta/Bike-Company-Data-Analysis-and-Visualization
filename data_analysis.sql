--A. DATA PROFILING:
--A1. Explore table structure: #columns, #rows, column name, data type
USE Bikecompany; GO
sp_columns 'BikeSales'; --14 columns
sp_columns 'Product';   -- 2 columns
sp_columns 'Location';  -- 2 columns
SELECT COUNT(*) AS Row_Count1 FROM BikeSales; -- 69.7k rows

--A2. Categorical columns: unique values & counts
--Year & Month: 2015 Jan to 2016 July
SELECT DISTINCT Year, Month 
FROM Bikecompany..BikeSales ORDER BY Year,Month;
--Gender
SELECT DISTINCT [Customer Gender] FROM Bikecompany..BikeSales;
--Country & State: 4 countries: US, UK, France, Germnay
SELECT DISTINCT Country FROM Bikecompany..Location;
SELECT Country, COUNT(State) AS #States FROM  Bikecompany..Location GROUP BY  Country;
--Product: 3 categories: Accessories, Bikes, Clothing, 17 subcategories
SELECT DISTINCT [Product Category] FROM Bikecompany..Product;
SELECT [Product Category], COUNT([Sub Category]) AS #Subcat FROM Bikecompany..Product GROUP BY [Product Category];

--A3. Numerical columns: descriptive statistics
SELECT 
 AVG([Customer Age]) AS AvgAge, MIN([Customer Age]) AS MinAge, MAX([Customer Age]) AS MaxAge,
 AVG([Revenue]) AS AvgRev, MIN([Revenue]) AS MinRev, MAX([Revenue]) AS MaxRev,
 AVG(Quantity) AS AvgQ, MIN(Quantity) AS MinQ, MAX(Quantity) AS MaxQ,
 AVG(Cost) AS AvgCost, MIN(Cost) AS MinCost, MAX(Cost) AS MaxCost,
 AVG([Unit Cost]) AS AvgUCost, MIN([Unit Cost]) AS MinUCost, MAX([Unit Cost]) AS MaxUCost,
 AVG([Unit Price]) AS AvgUPrice, MIN([Unit Price]) AS MinUPrice, MAX([Unit Price]) AS MaxUPrice FROM Bikecompany..BikeSales;
--No negative numbers

--A4. Identify Nulls: 
SELECT *
FROM Bikecompany..BikeSales
WHERE Year IS NULL
   OR [Customer Age] IS NULL
   OR [Sub Category] IS NULL
   OR State IS NULL
   OR Quantity IS NULL
   OR Cost IS NULL
   OR Revenue IS NULL;
--There are 2 rows with Nulls

SELECT DISTINCT Column1 FROM Bikecompany..BikeSales
--No value in this column

--B. DATA CLEANING
--B1. Handle missing values: DELETE, DROP COLUMN
DELETE FROM Bikecompany..BikeSales
WHERE Year IS NULL

ALTER TABLE Bikecompany..BikeSales
DROP COLUMN Column1;

--B2. Update existing columns: UDPATE, CASE
--Gender: F,M -> Female, Male
UPDATE Bikecompany..BikeSales
SET [Customer Gender]= CASE
WHEN [Customer Gender]='F' THEN 'Female'
WHEN [Customer Gender]='M' THEN 'Male'
END;

--B3. Add new columns
--YearMonth: ADD, CAST, Concatenate, CASE (Convert Month names into numerical values)
ALTER TABLE Bikecompany..BikeSales
ADD YearMonth AS 
	CAST(Year AS varchar(4))+
	CASE
		WHEN [Month] = 'January' THEN '01'
        WHEN [Month] = 'February' THEN '02'
        WHEN [Month] = 'March' THEN '03'
        WHEN [Month] = 'April' THEN '04'
        WHEN [Month] = 'May' THEN '05'
        WHEN [Month] = 'June' THEN '06'
        WHEN [Month] = 'July' THEN '07'
        WHEN [Month] = 'August' THEN '08'
        WHEN [Month] = 'September' THEN '09'
        WHEN [Month] = 'October' THEN '10'
        WHEN [Month] = 'November' THEN '11'
        WHEN [Month] = 'December' THEN '12'
		ELSE NULL
		END;
SELECT DISTINCT YearMonth FROM Bikecompany..BikeSales ORDER BY YearMonth;--check

--Profit
ALTER TABLE Bikecompany..BikeSales
ADD Profit AS (Revenue-Cost);

--Age group
ALTER TABLE Bikecompany..Bikesales
ADD AgeGroup AS CASE
	WHEN [Customer Age] < 20 THEN 'Under 20'
	WHEN [Customer Age] >= 20 AND [Customer Age]<40 THEN 'Young Adults'
	WHEN [Customer Age] >= 40 AND [Customer Age]<60 THEN 'Middle-aged Adults'
	WHEN [Customer Age] >= 60 THEN 'Seniors'
	ELSE NULL
	END;

--B4. JOIN & Create Temp Table
CREATE TABLE #Joined_Bikesales (
    Year INT,
    Month VARCHAR(50),
    [Customer Age] INT,
    [Customer Gender] VARCHAR(50),
    State VARCHAR(100),
    Country VARCHAR(50),
    [Sub Category] VARCHAR(50),
	[Product Category] VARCHAR(50),
    Quantity INT,
    [Unit Cost] DECIMAL(10, 0),
    [Unit Price] DECIMAL(10, 0),
    Cost DECIMAL(10, 0),
    Revenue DECIMAL(10, 0),
    YearMonth VARCHAR(50),
    Profit DECIMAL(10, 0),
    AgeGroup VARCHAR(50));

INSERT INTO #Joined_Bikesales
SELECT Year,Month,[Customer Age],[Customer Gender],BikeSales.State,Country,BikeSales.[Sub Category],[Product Category],Quantity,[Unit Cost],[Unit Price],Cost,Revenue,YearMonth,Profit,AgeGroup
FROM Bikecompany..BikeSales
JOIN Bikecompany..Product ON BikeSales.[Sub Category]=Product.[Sub Category]
JOIN Bikecompany..Location ON BikeSales.[State]=Location.[State];

SELECT *
FROM #Joined_Bikesales;


--C. DATA ANALYSIS
--C1. Customer Analysis: Which age group or gender makes the most purchases?
SELECT  AgeGroup, 
		SUM(Revenue) AS TotalRev,
		SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare
FROM Bikecompany..BikeSales
GROUP BY AgeGroup
ORDER BY TotalRev DESC;

/*Answer:
- Young adults aged 20-40 is the target age group, accounting for around 60% of Revenue
- The gender split is roughly 50-50*/


--C2. Product Analysis
--What are our top performing products in terms of Sales?
SELECT [Product Category],
		SUM(Revenue) AS TotalRev
FROM #Joined_Bikesales
GROUP BY [Product Category]
ORDER BY TotalRev DESC;

SELECT [Product Category], [Sub Category],
		SUM(Revenue) AS TotalRev,
		SUM(Revenue)/ SUM(SUM(Revenue))	OVER() AS RevShare
FROM #Joined_Bikesales
GROUP BY [Product Category], [Sub Category]
ORDER BY TotalRev DESC;

WITH CTE_Bikesales AS (
SELECT [Product Category], [Sub Category],
		SUM(Revenue) AS TotalRev,
		SUM(Revenue)/ SUM(SUM(Revenue))	OVER() AS RevShare,
		ROW_NUMBER () OVER (ORDER BY SUM(Revenue) DESC) AS RowNum
FROM #Joined_Bikesales
GROUP BY [Product Category], [Sub Category]
)
SELECT SUM(RevShare)
FROM CTE_BikeSales
WHERE RowNum<=5
/*Answer:
- Top 5 products: Bikes (Moutain, Road, Touring Bikes) & Accessories (Helmets, Tires & Tubes)
- Top 5 account for ~80% Revenue
- Functions used: Window function, CTE, ROW_NUMBER*/

--What are our top performing products in terms of Profit margin?
SELECT [Product Category],
		(SUM(Profit)/SUM(Revenue)) AS ProfitMargin
FROM #Joined_Bikesales
GROUP BY [Product Category]
ORDER BY ProfitMargin DESC;


SELECT [Product Category], [Sub Category],
		(SUM(Profit)/SUM(Revenue)) AS ProfitMargin
FROM #Joined_Bikesales
GROUP BY [Product Category], [Sub Category]
ORDER BY ProfitMargin DESC;

/*Answer:
- Despit having the highest sales, Bikes have really low profit margin (2.9%)
- Accessories and Clothing have relatively high margin (16-19%)
- Bike Racks is the subcat with highest margin (25%)
*/

--C3. Geographic Insights
--Top performing markets (Sales & Profit)
SELECT  Country,
		SUM(Revenue) AS TotalRev,
		SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare,
		(SUM(Profit)/SUM(Revenue)) AS ProfitMargin
FROM #Joined_Bikesales
GROUP BY Country
ORDER BY TotalRev DESC;
/*Answer: 
- The US is the largest market with 46% Rev share, the other 3 markets have roughly the same share (15-19%)
- Germany has the highest margin (22.6%) while all other markets have really low margin (~7%). This is an interesting insight which we could dig deeper into
*/

/*Why does Germany have such high margin? Is it high across all sub categories?
What is their pricing strategy? Do they have lower production cost?*/

SELECT [Sub Category], Country, (SUM(Profit)/SUM(Revenue)) AS ProfitMargin, SUM(Quantity) AS Quantity, AVG([Unit Cost]) AS AVG_Unit_Cost, AVG([Unit Price]) AS AVG_Unit_Price
FROM #Joined_Bikesales
GROUP BY [Sub Category], Country
ORDER BY [Sub Category], Country;

/*Answer:
- Germany has high profit margin across all sub categories compared to other countries
- Particularly for bikes, the main category, Germany enjoys profit margin of >15%, while the corresponding number for others is <2%. The US even suffers from loss for this category
- The reason for this lies in Germany's pricing strategy. They are able to set higher prices while there seems to be no considerable differences in production cost among 4 countries 
*/

--Why can Germany set higher prices? Can we look at their customer demographics/ age?
SELECT Country, AVG([Customer Age]) AS AvgAge
FROM #Joined_Bikesales
GROUP BY Country

SELECT  AgeGroup, SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare
FROM #Joined_Bikesales WHERE Country='Germany' GROUP BY AgeGroup ORDER BY AgeGroup;

SELECT  AgeGroup, SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare
FROM #Joined_Bikesales WHERE Country='United States' GROUP BY AgeGroup ORDER BY AgeGroup

SELECT  AgeGroup, SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare
FROM #Joined_Bikesales WHERE Country='United Kingdom' GROUP BY AgeGroup ORDER BY AgeGroup

SELECT  AgeGroup, SUM(Revenue)/ SUM(SUM(Revenue)) OVER() AS RevShare
FROM #Joined_Bikesales WHERE Country='France' GROUP BY AgeGroup ORDER BY AgeGroup

/*Answer:
- Germany has the youngest customers (average age of 34) while the US customers are a bit older (average age of 37)
- While young adults account for 63% Sales in Germany, this group only make up of 55% Sales in the US
- France and the UK have quite similar customer age compared to Germany
- It might be possible that younger customers are more willing to spend more money on bikes and accessories. Other countries can consider attracting younger audience in their marketing activities 
*/

--How has profit margin changed over time in different countries?
SELECT Country, YearMonth, (SUM(Profit)/SUM(Revenue)) AS ProfitMargin
FROM #Joined_Bikesales
GROUP BY Country, YearMonth
ORDER BY Country, YearMonth;

/*Answer:
- It seems like for the entire year of 2015, the US, France and the UK saw really low profit margin and frequently suffered from loss
- On the other hand, Germany saw stable positive profit margin throughout the period
- On a positive note, the situation has picked up significantly since 2016 for all countries
*/
