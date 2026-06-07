--  Create WAREHOUSE
CREATE WAREHOUSE health_ops_wh
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

USE WAREHOUSE health_ops_wh;

-- Create Database
CREATE DATABASE health_ops_db;

USE health_ops_db;

-- Create Schema
CREATE SCHEMA health_ops_schema;

USE SCHEMA health_ops_schema;

-- Data exploration

--sample of data
select * from patient limit 10;

--count of rows
select count(*) from patient;
-- data exploration

-- check null values

SELECT
    COUNT(*) AS Total_rows,
    COUNT_IF(patient_admission_date IS NULL) AS date_nulls,
    COUNT_IF(patient_admission_time IS NULL) AS time_nulls,
    COUNT_IF(patient_age IS NULL) AS age_nulls,
    COUNT_IF(patient_gender IS NULL) AS gender_nulls,
    COUNT_IF(patient_race IS NULL) AS race_nulls,
    COUNT_IF(department_referral IS NULL) AS department_nulls,
    COUNT_IF(patient_admission_flag IS NULL) AS admission_flag_nulls,
    COUNT_IF(patient_waittime IS NULL) AS waittime_nulls,    COUNT_IF(patient_satisfaction_score IS NULL) AS satisfaction_nulls,
    COUNT_IF(visit_type IS NULL) AS visit_nulls,
    COUNT_IF(doctor_id IS NULL) AS doctor_nulls
FROM patient;

--Date range
select min(patient_admission_date) as start_date,
max(patient_admission_date) as end_date from patient;

-- checking patients per department
select department_referral, count(*) as total_patients
from patient
group by department_referral
order by total_patients desc;

-- patient distribution by gender
select patient_gender, count(*) as total_patients
from patient
group by patient_gender
order by total_patients desc;

-- doctors data exploration

select * from doctor limit 10;

-- doctors per department
select department, count(doctor_id) as "Number of doctors"
from doctor
group by department
order by "Number of doctors" desc;

-- Data Cleaning

CREATE OR REPLACE TABLE patient_cleaned AS
SELECT * REPLACE(

-- Fix date
TO_DATE(patient_admission_date, 'DD-MM-YYYY') AS patient_admission_date,

-- Fix nulls in department
COALESCE(department_referral, 'Unknown') AS department_referral,

-- Fix gender
IFF(LOWER(patient_gender) = 'femaleemale', 'Unknown', patient_gender) AS patient_gender
)

from patient;

-- data analysis 

--Q1 How has patient volume changed over time? Calculate  monthly patient encounter counts to identify trends and growth patterns.
select
extract(month from patient_admission_date) as month,
extract(year from patient_admission_date) as year,
count(*) as patient_volume
from patient_cleaned
group by year,month
order by year, month;

select
extract(year from patient_admission_date) as year,
count(*) as patient_volume
from patient_cleaned
group by year
order by year;

--Q2 How does patient volume vary by visit type (Emergency vs Walk-in vs Scheduled)?
select visit_type, count(*) as total_patients
from patient_cleaned
group by visit_type
order by total_patients desc;

--Q3. What is the average wait time across the hospital, and how does it vary by department?
select ROUND(AVG(patient_waittime),2) 
from patient_cleaned;

select department_referral,
ROUND(AVG(patient_waittime),2) as avg_wait_time
from patient_cleaned
group by department_referral
order by avg_wait_time desc;

-- Q4. What % of patients wait more than 30 mins?

-- 100 * patients who wait for > 30 mins / total patients 

select 100 * count_if(patient_waittime > 30) / count(*)
from patient_cleaned;

--Q5. What are the peak hours for patient arrivals?
select extract(hour from patient_admission_time) as hour, count(*) as patient_volume
from patient_cleaned
group by hour
order by hour;

--Q6. Which department & hour of the day combinations experience the highest wait times?
select department_referral, 
extract(hour from patient_admission_time) as hour,
ROUND(AVG(patient_waittime),2) as avg_wait_time
from patient_cleaned
group by department_referral, hour
order by avg_wait_time desc;

--Q7. How does patient satisfaction vary by department?
select department_referral,
ROUND(AVG(patient_satisfaction_score),2) as avg_satisfaction_score
from patient_cleaned
where patient_satisfaction_score is not null
group by department_referral
order by avg_satisfaction_score desc;


--Q8. How do admission rates differ across departments?
select department_referral,
ROUND(100 * (COUNT_IF(patient_admission_flag = 'Admission')/COUNT(*)),2) as rate_of_patients_admission
from patient_cleaned
group by department_referral
order by rate_of_patients_admission desc ;


--Q9. Is there a relationship between wait time duration and likelihood of patient admission?
select
case when patient_waittime >= 30 then 'Long Wait'
    when patient_waittime >= 15 then 'Medium Wait'
    else 'Short Wait' end as wait_time,
 COUNT_IF(patient_admission_flag = 'Admission') as admissions
from patient_cleaned
group by wait_time
order by admissions desc ;


--Q10. How do different shifts compare in terms of patient load and wait time?
select
d.shift_type,
COUNT(p.patient_id) as patient_volume,
ROUND(AVG(p.patient_waittime),2) as avg_wait_time
from patient_cleaned p
JOIN doctor d 
    ON p.doctor_id = d.doctor_id
group by d.shift_type
order by avg_wait_time desc;