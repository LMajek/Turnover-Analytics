CREATE DATABASE turnover;

USE turnover;

SELECT * FROM hr;

-- Data Cleaning --

SET sql_safe_updates = 0;

ALTER TABLE hr RENAME COLUMN ï»¿id TO id;

DESCRIBE hr;

SELECT birthdate FROM hr;

UPDATE hr
SET birthdate = CASE
WHEN birthdate LIKE '%-%'THEN date_format(str_to_date(birthdate, '%m-%d-%Y'), '%Y-%m-%d')
WHEN birthdate LIKE '%/%'THEN date_format(str_to_date(birthdate, '%m/%d/%Y'), '%Y-%m-%d')
ELSE NULL 
END;

ALTER TABLE hr MODIFY COLUMN birthdate DATE;

SELECT hire_date FROM hr;

UPDATE hr
SET hire_date = CASE
WHEN hire_date LIKE '%-%'THEN date_format(str_to_date(hire_date, '%m-%d-%Y'), '%Y-%m-%d')
WHEN hire_date LIKE '%/%'THEN date_format(str_to_date(hire_date, '%m/%d/%Y'), '%Y-%m-%d')
ELSE NULL 
END;

ALTER TABLE hr MODIFY COLUMN hire_date DATE;

SELECT termdate FROM hr;

UPDATE hr
SET termdate = date(str_to_date(termdate, '%Y-%m-%d %H:%i:%s UTC'))
WHERE termdate IS NOT NULL AND termdate !='';

-- Change empty termination dates to NULL instead of blank

UPDATE hr
SET termdate = null
WHERE termdate = '';

ALTER TABLE hr MODIFY COLUMN termdate DATE;


-- Exploring Data for Current Employees --

-- Add age column to data

ALTER TABLE hr ADD COLUMN age INT;

UPDATE hr 
SET age = timestampdiff(YEAR, birthdate, curdate());

-- Group employees by age

SELECT
min(age) AS youngest,
max(age) AS oldest
FROM hr;

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist,
count(*) AS Total
FROM hr
WHERE termdate IS NULL
GROUP BY age_dist
ORDER BY age_dist;

-- Gender distribution

SELECT 
gender, count(*) AS Total
FROM hr
WHERE termdate IS NULL
GROUP BY gender;

-- HQ or Remote

SELECT
location, count(*) AS Total
FROM hr
WHERE termdate is NULL
GROUP BY location;

-- Location by state
SELECT
location_state, count(*) AS Total
FROM hr 
WHERE termdate IS NULL
GROUP BY location_state
ORDER BY Total DESC;

-- Multivariate Analysis

-- Age group per department 

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist, department,
count(*) AS Total
FROM hr
WHERE termdate IS NULL
GROUP BY age_dist, department
ORDER BY age_dist, department;


-- Exploring Data for Ex Employees --

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist,
count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
GROUP BY age_dist
ORDER BY age_dist;

-- Gender distribution

SELECT 
gender, count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
GROUP BY gender;

-- HQ or Remote

SELECT
location, count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
GROUP BY location;

-- Location by state
SELECT
location_state, count(*) AS Total
FROM hr 
WHERE termdate IS NOT NULL
GROUP BY location_state
ORDER BY Total DESC;

-- Multivariate Analysis

-- Age group per department 

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist, department,
count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
GROUP BY age_dist, department
ORDER BY age_dist, department;


-- Termination Stats --

-- Average age at exit date

SELECT
ROUND(AVG(timestampdiff(YEAR, birthdate, termdate)),0) AS avg_term_age
FROM hr
WHERE termdate IS NOT NULL AND termdate;


-- Avg employment length

SELECT
ROUND(AVG(datediff(termdate, hire_date))/365,0) AS avg_employment_len
FROM hr
WHERE termdate IS NOT NULL;

-- Turnover rate by department

SELECT department,
count(*) AS Dept_Total,
count(CASE
WHEN termdate IS NOT NULL THEN 1
END) AS Terminated_Total,
ROUND((count(CASE
WHEN termdate IS NOT NULL THEN 1
END)/count(*))*100,1) AS Turnover_Rate
FROM hr
GROUP BY department
ORDER BY Turnover_Rate DESC;


-- Active employees per year

SELECT y.year,
SUM(CASE WHEN hire_date <= y.year_end_date THEN 1 ELSE 0 END) -
SUM(CASE WHEN termdate IS NOT NULL AND termdate <= y.year_end_date THEN 1 ELSE 0 END) AS active_employees
FROM (
SELECT DISTINCT YEAR(hire_date) AS year, LAST_DAY(CONCAT(YEAR(hire_date), '-12-31')) AS year_end_date
FROM hr
UNION
SELECT DISTINCT YEAR(termdate), LAST_DAY(CONCAT(YEAR(termdate), '-12-31'))
FROM hr WHERE termdate IS NOT NULL
) y
JOIN hr ON 1=1
GROUP BY y.year, y.year_end_date
ORDER BY y.year;

-- Termination rate per year

WITH ActiveEmployees AS (
SELECT y.year,
SUM(CASE WHEN hire_date <= y.year_end_date THEN 1 ELSE 0 END) -
SUM(CASE WHEN termdate IS NOT NULL AND termdate <= y.year_end_date THEN 1 ELSE 0 END) AS active_employees
FROM (
SELECT DISTINCT YEAR(hire_date) AS year, LAST_DAY(CONCAT(YEAR(hire_date), '-12-31')) AS year_end_date
FROM hr
UNION
SELECT DISTINCT YEAR(termdate), LAST_DAY(CONCAT(YEAR(termdate), '-12-31'))
FROM hr WHERE termdate IS NOT NULL
) y
JOIN hr ON 1=1
GROUP BY y.year, y.year_end_date
),

YearlyTerminations AS (
SELECT YEAR(termdate) AS year, count(*) AS terminations
FROM hr
WHERE termdate IS NOT NULL
GROUP BY YEAR(termdate)
)

SELECT yt.year,
terminations,
LAG(active_employees) OVER (ORDER BY yt.year) AS employees_start_of_year,
(terminations / LAG(active_employees) OVER (ORDER BY yt.year)) * 100 AS termination_rate
FROM YearlyTerminations yt
LEFT JOIN ActiveEmployees ae ON yt.year = ae.year
ORDER BY yt.year;

-- Termination rate per year for 18-24 age group

WITH ActiveEmployees AS (
SELECT y.year,
SUM(CASE WHEN hire_date <= y.year_end_date AND age >= 18 AND age <= 24 THEN 1 ELSE 0 END) -
SUM(CASE WHEN termdate IS NOT NULL AND termdate <= y.year_end_date AND age >= 18 AND age <= 24 THEN 1 ELSE 0 END) AS active_employees
FROM (
SELECT DISTINCT YEAR(hire_date) AS year, LAST_DAY(CONCAT(YEAR(hire_date), '-12-31')) AS year_end_date
FROM hr
UNION
SELECT DISTINCT YEAR(termdate), LAST_DAY(CONCAT(YEAR(termdate), '-12-31'))
FROM hr WHERE termdate IS NOT NULL
) y
JOIN hr ON 1=1
GROUP BY y.year, y.year_end_date
),

YearlyTerminations AS (
SELECT YEAR(termdate) AS year, count(*) AS terminations
FROM hr
WHERE termdate IS NOT NULL AND age >= 18 AND age <= 24
GROUP BY YEAR(termdate)
)

SELECT yt.year,
terminations,
LAG(active_employees) OVER (ORDER BY yt.year) AS employees_start_of_year,
(terminations / LAG(active_employees) OVER (ORDER BY yt.year)) * 100 AS termination_rate
FROM YearlyTerminations yt
LEFT JOIN ActiveEmployees ae ON yt.year = ae.year
ORDER BY yt.year;

-- Age Group Termination in Accounting Department

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist,
department,
count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
AND department IN ('Accounting')
GROUP BY age_dist, department
ORDER BY age_dist, department;

-- Age Group Termination in Auditing Department

SELECT
CASE
WHEN age >= 18 AND age <= 24 THEN '18-24'
WHEN age >= 25 AND age <= 34 THEN '25-34'
WHEN age >= 35 AND age <= 44 THEN '35-44'
WHEN age >= 45 AND age <= 54 THEN '45-54'
ELSE '55 and Over'
END AS age_dist,
department,
count(*) AS Total
FROM hr
WHERE termdate IS NOT NULL
AND department IN ('Auditing')
GROUP BY age_dist, department
ORDER BY age_dist, department;


