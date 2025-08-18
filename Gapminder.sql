DROP DATABASE IF EXISTS countries;
CREATE DATABASE countries;
USE countries;

-- Create Country table
CREATE TABLE Country (
    country_id INT PRIMARY KEY AUTO_INCREMENT,
    country_name VARCHAR(100) UNIQUE NOT NULL,
    iso_alpha CHAR(3) UNIQUE NOT NULL,
    iso_num INT UNIQUE NOT NULL
);

-- Create Continent table
CREATE TABLE Continent (
    continent_id INT PRIMARY KEY AUTO_INCREMENT,
    continent_name VARCHAR(50) UNIQUE NOT NULL
);

-- Create Country_Continent relationship table
CREATE TABLE Country_Continent (
    country_id INT,
    continent_id INT,
    PRIMARY KEY (country_id, continent_id),
    FOREIGN KEY (country_id) REFERENCES Country(country_id),
    FOREIGN KEY (continent_id) REFERENCES Continent(continent_id)
);

-- Create Years table
CREATE TABLE Years (
    year_id INT PRIMARY KEY AUTO_INCREMENT,
    year_value INT UNIQUE NOT NULL
);

-- Create GDP_Category table (NOTE: Use INT instead of SERIAL for compatibility)
CREATE TABLE GDP_Category (
    gdp_category_id INT PRIMARY KEY AUTO_INCREMENT,
    gdp_category_name VARCHAR(50),
    min_gdp DECIMAL(15, 2),
    max_gdp DECIMAL(15, 2)
);

CREATE TABLE EconomicMetrics (
    economic_metrics_id INT AUTO_INCREMENT PRIMARY KEY,
    country_id INT NOT NULL,
    year_id INT NOT NULL,
    gdp_per_capita DECIMAL(15, 2),
    gdp_category_id INT,
    UNIQUE KEY unique_country_year (country_id, year_id),
    FOREIGN KEY (country_id) REFERENCES Country(country_id),
    FOREIGN KEY (year_id) REFERENCES Years(year_id),
    FOREIGN KEY (gdp_category_id) REFERENCES GDP_Category(gdp_category_id)
);

-- Insert GDP Categories
INSERT INTO GDP_Category (gdp_category_name, min_gdp, max_gdp) VALUES
('Low Income', 0, 1000),
('Lower-Middle Income', 1001, 4000),
('Upper-Middle Income', 4001, 12000),
('High Income', 12001, 999999999);

select * from country;
select * from continent;
select * from country_continent;
select * from years;
select * from GDP_category;
select * from EconomicMetrics;

use countries;

-- 1) Countries with 'High Income' GDP category in the most recent year
SELECT c.country_name, em.gdp_per_capita
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Years y ON em.year_id = y.year_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
WHERE y.year_value = (SELECT MAX(year_value) FROM Years)
  AND g.gdp_category_name = 'High Income';
  
-- 2) Top 5 countries by GDP per capita growth between the first and last year
SELECT c.country_name, 
       MAX(em.gdp_per_capita) - MIN(em.gdp_per_capita) AS gdp_growth
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
GROUP BY c.country_name
ORDER BY gdp_growth DESC
LIMIT 5;

-- 3) Average GDP per capita by continent in 2007
SELECT ct.continent_name, AVG(em.gdp_per_capita) AS avg_gdp
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Country_Continent cc ON c.country_id = cc.country_id
JOIN Continent ct ON cc.continent_id = ct.continent_id
JOIN Years y ON em.year_id = y.year_id
WHERE y.year_value = 2007
GROUP BY ct.continent_name;

-- 4) Find countries that changed GDP categories between 1957 and 1977
SELECT c.country_name, y1.year_value AS year_start, g1.gdp_category_name AS category_start,
                         y2.year_value AS year_end, g2.gdp_category_name AS category_end
FROM EconomicMetrics em1
JOIN EconomicMetrics em2 ON em1.country_id = em2.country_id
JOIN Country c ON em1.country_id = c.country_id
JOIN Years y1 ON em1.year_id = y1.year_id
JOIN Years y2 ON em2.year_id = y2.year_id
JOIN GDP_Category g1 ON em1.gdp_category_id = g1.gdp_category_id
JOIN GDP_Category g2 ON em2.gdp_category_id = g2.gdp_category_id
WHERE y1.year_value = 1957 AND y2.year_value = 1977
  AND g1.gdp_category_id <> g2.gdp_category_id;
  
-- 5) Number of countries in each GDP category for the latest year
SELECT g.gdp_category_name, COUNT(*) AS country_count
FROM EconomicMetrics em
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
JOIN Years y ON em.year_id = y.year_id
WHERE y.year_value = (SELECT MAX(year_value) FROM Years)
GROUP BY g.gdp_category_name;

-- 6) Find continents where all countries are in the 'High Income' category (latest year)
SELECT ct.continent_name
FROM Continent ct
JOIN Country_Continent cc ON ct.continent_id = cc.continent_id
JOIN Country c ON cc.country_id = c.country_id
JOIN EconomicMetrics em ON c.country_id = em.country_id
JOIN Years y ON em.year_id = y.year_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
WHERE y.year_value = (SELECT MAX(year_value) FROM Years)
GROUP BY ct.continent_name
HAVING MIN(g.gdp_category_name) = 'High Income';

-- 7) Countries that never reached 'High Income' status
SELECT DISTINCT c.country_name
FROM Country c
WHERE c.country_id NOT IN (
    SELECT em.country_id
    FROM EconomicMetrics em
    JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
    WHERE g.gdp_category_name = 'High Income'
);

-- 8) GDP per capita trend for Brazil
SELECT y.year_value, em.gdp_per_capita
FROM EconomicMetrics em
JOIN Years y ON em.year_id = y.year_id
JOIN Country c ON em.country_id = c.country_id
WHERE c.country_name = 'Brazil'
ORDER BY y.year_value;

-- 9) Find the GDP category threshold breaches for any country over time
SELECT c.country_name, y.year_value, g.gdp_category_name, em.gdp_per_capita
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Years y ON em.year_id = y.year_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
ORDER BY c.country_name, y.year_value;

-- 10) Year when a specific country (e.g., 'Albania') moved to 'Upper-Middle Income'
SELECT y.year_value
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Years y ON em.year_id = y.year_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
WHERE c.country_name = 'Albania' AND g.gdp_category_name = 'Upper-Middle Income'
ORDER BY y.year_value
LIMIT 1;

-- 11) Countries with decreasing GDP per capita for 3 consecutive years
WITH RankedGDP AS (
  SELECT em.country_id, y.year_value, em.gdp_per_capita,
         LAG(em.gdp_per_capita, 1) OVER (PARTITION BY em.country_id ORDER BY y.year_value) AS prev1,
         LAG(em.gdp_per_capita, 2) OVER (PARTITION BY em.country_id ORDER BY y.year_value) AS prev2
  FROM EconomicMetrics em
  JOIN Years y ON em.year_id = y.year_id
)
SELECT DISTINCT c.country_name
FROM RankedGDP rg
JOIN Country c ON rg.country_id = c.country_id
WHERE rg.gdp_per_capita < rg.prev1 AND rg.prev1 < rg.prev2;

-- 12) Maximum GDP per capita by country
SELECT c.country_name, MAX(em.gdp_per_capita) AS max_gdp
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
GROUP BY c.country_name;

-- 13) List all countries and their GDP categories over time
SELECT c.country_name, y.year_value, g.gdp_category_name
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Years y ON em.year_id = y.year_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
ORDER BY c.country_name, y.year_value;

-- 14) Count of countries per continent per GDP category in 1997
SELECT ct.continent_name, g.gdp_category_name, COUNT(*) AS country_count
FROM EconomicMetrics em
JOIN Country c ON em.country_id = c.country_id
JOIN Country_Continent cc ON c.country_id = cc.country_id
JOIN Continent ct ON cc.continent_id = ct.continent_id
JOIN GDP_Category g ON em.gdp_category_id = g.gdp_category_id
JOIN Years y ON em.year_id = y.year_id
WHERE y.year_value = 1997
GROUP BY ct.continent_name, g.gdp_category_name;

-- 15) Countries that moved directly from 'Low Income' to 'Upper-Middle Income' or higher
SELECT DISTINCT c.country_name
FROM Country c
JOIN EconomicMetrics em1 ON c.country_id = em1.country_id
JOIN GDP_Category g1 ON em1.gdp_category_id = g1.gdp_category_id
JOIN EconomicMetrics em2 ON c.country_id = em2.country_id
JOIN GDP_Category g2 ON em2.gdp_category_id = g2.gdp_category_id
WHERE g1.gdp_category_name = 'Low Income'
  AND g2.gdp_category_name IN ('Upper-Middle Income', 'High Income')
  AND em1.year_id < em2.year_id;