/* Анализа рынка труда для аналитиков данных и системных аналитиков на основе данных hh.ru (май–июнь 2024)
 * 
 * Автор: Андреева Анна Алексеевна
 * 
 * 10.11.2025 */

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'parcing_table' AND table_schema = 'public';

-- 1. Получение статистики по заработной плате
SELECT 
    ROUND(AVG(salary_from), 2) AS avg_salary_from,
    ROUND(AVG(salary_to), 2) AS avg_salary_to,
    MIN(salary_from) AS min_salary_from,
    MAX(salary_from) AS max_salary_from,
    MIN(salary_to) AS min_salary_to,
    MAX(salary_to) AS max_salary_to,
    COUNT(salary_from) AS count_from,
    COUNT(salary_to) AS count_to
FROM public.parcing_table
WHERE salary_from IS NOT NULL OR salary_to IS NOT NULL;


-- 2.1 Количество ваканский по регионам 
SELECT 
    area,
    COUNT(*) AS vacancy_count
FROM public.parcing_table
GROUP BY area
ORDER BY vacancy_count DESC;

-- 2.2 Количество вакансий по регионам
SELECT 
    employer,
    COUNT(*) AS vacancy_count
FROM public.parcing_table
GROUP BY employer
ORDER BY vacancy_count DESC; 


-- 3.1 Количество вакансий по типу занятости
SELECT employment,
       COUNT(*) AS vacancies_count
FROM public.parcing_table 
GROUP BY employment 
ORDER BY vacancies_count DESC;

-- 3.2 Количество вакансий по графику работы	
SELECT schedule,
       COUNT(*) AS vacancies_count 
FROM public.parcing_table 
GROUP BY schedule 
ORDER BY vacancies_count DESC;


-- 4.1 выявление специалистов по грейдам
SELECT experience,
       COUNT(*) AS vacancies_count
FROM public.parcing_table 
GROUP BY experience 
ORDER BY vacancies_count DESC;

-- 4.2 Распределение грейдов: Data Analyst vs System Analyst + Общее
WITH categorized AS (
    SELECT 
        experience,
        CASE 
            WHEN LOWER(name) LIKE '%data analyst%' 
              OR LOWER(name) LIKE '%аналитик данных%' 
              OR LOWER(name) LIKE '%data-аналитик%' 
              OR LOWER(name) LIKE '%bi аналитик%' 
              OR LOWER(name) LIKE '%bi-аналитик%' 
                THEN 'Data Analyst'
            WHEN LOWER(name) LIKE '%системный аналитик%' 
              OR LOWER(name) LIKE '%system analyst%' 
                THEN 'System Analyst'
            ELSE NULL 
        END AS analyst_type
    FROM public.parcing_table
    WHERE LOWER(name) LIKE '%data analyst%'
       OR LOWER(name) LIKE '%аналитик данных%'
       OR LOWER(name) LIKE '%системный аналитик%'
       OR LOWER(name) LIKE '%system analyst%'
       OR LOWER(name) LIKE '%bi аналитик%'
       OR LOWER(name) LIKE '%data-аналитик%'
       OR LOWER(name) LIKE '%bi-аналитик%'
),
graded AS (
    SELECT 
        CASE 
            WHEN LOWER(experience) LIKE '%без опыта%' 
              OR LOWER(experience) LIKE '%junior%' 
              OR LOWER(experience) LIKE '%0%' 
              OR LOWER(experience) LIKE '%стажер%' THEN 'Junior'
            WHEN LOWER(experience) LIKE '%middle%' 
              OR LOWER(experience) LIKE '%1-3%' 
              OR LOWER(experience) LIKE '%2-4%' THEN 'Middle'
            WHEN LOWER(experience) LIKE '%senior%' 
              OR LOWER(experience) LIKE '%3-6%' 
              OR LOWER(experience) LIKE '%6+%' THEN 'Senior'
            ELSE 'Не указан'
        END AS grade_level,
        analyst_type
    FROM categorized
    WHERE analyst_type IS NOT NULL
)
SELECT 
    grade_level,
    COUNT(CASE WHEN analyst_type = 'Data Analyst' THEN 1 END) AS data_analysts_count,
    COUNT(CASE WHEN analyst_type = 'System Analyst' THEN 1 END) AS system_analysts_count,
    COUNT(*) AS total_analysts_count  -- общее количество системных аналитиков и аналитиков данных
FROM graded
GROUP BY grade_level
ORDER BY 
    CASE grade_level 
        WHEN 'Junior' THEN 1 
        WHEN 'Middle' THEN 2 
        WHEN 'Senior' THEN 3 
        ELSE 4 
    END;


-- 5. Определение основных работодателей, предлагаемые зарплаты и условия труда для аналитиков
SELECT employer,
       COUNT(*) AS vacancies_count,
       ROUND(AVG(salary_from), 2) AS avg_salary_from,
       ROUND(AVG(salary_to), 2) AS avg_salary_to,
       employment,
       schedule
FROM public.parcing_table 
WHERE name LIKE '%Аналитик данных%' 
	  OR name LIKE '%аналитик данных%' 
	  OR name LIKE '%Системный аналитик%' 
	  OR name LIKE '%системный аналитик%'
GROUP BY employer, employment, schedule 
ORDER BY vacancies_count DESC;


-- 6. Востребованные Навыки hard и soft skills 
WITH analysts AS (
    SELECT 
        experience,
        key_skills_1, key_skills_2, key_skills_3, key_skills_4,
        soft_skills_1, soft_skills_2, soft_skills_3, soft_skills_4
    FROM public.parcing_table
    WHERE LOWER(name) LIKE '%data analyst%'
       OR LOWER(name) LIKE '%аналитик данных%'
       OR LOWER(name) LIKE '%системный аналитик%'
       OR LOWER(name) LIKE '%system analyst%'
       OR LOWER(name) LIKE '%bi аналитик%'
       OR LOWER(name) LIKE '%data-аналитик%'
       OR LOWER(name) LIKE '%bi-аналитик%'
),
-- HARD SKILLS: считаем demand ДО JOIN 
hard_with_demand AS (
    SELECT 
        grade,
        skill,
        demand,
        ROW_NUMBER() OVER (PARTITION BY grade ORDER BY demand DESC) AS rn
    FROM (
        SELECT 
            CASE
                WHEN LOWER(experience) LIKE '%без опыта%' OR LOWER(experience) LIKE '%junior%' THEN 'Junior'
                WHEN LOWER(experience) LIKE '%middle%' THEN 'Middle'
                WHEN LOWER(experience) LIKE '%senior%' THEN 'Senior'
                ELSE 'Не указан'
            END AS grade,
            TRIM(UPPER(skill)) AS skill,
            COUNT(*) AS demand
        FROM analysts
        CROSS JOIN LATERAL (
            VALUES (key_skills_1), (key_skills_2), (key_skills_3), (key_skills_4)
        ) AS v(skill)
        WHERE skill IS NOT NULL AND TRIM(skill) != ''
        GROUP BY grade, skill
    ) t
),
-- SOFT SKILLS: считаем demand ДО JOIN
soft_with_demand AS (
    SELECT 
        grade,
        skill,
        demand,
        ROW_NUMBER() OVER (PARTITION BY grade ORDER BY demand DESC) AS rn
    FROM (
        SELECT 
            CASE
                WHEN LOWER(experience) LIKE '%без опыта%' OR LOWER(experience) LIKE '%junior%' THEN 'Junior'
                WHEN LOWER(experience) LIKE '%middle%' THEN 'Middle'
                WHEN LOWER(experience) LIKE '%senior%' THEN 'Senior'
                ELSE 'Не указан'
            END AS grade,
            TRIM(UPPER(skill)) AS skill,
            COUNT(*) AS demand
        FROM analysts
        CROSS JOIN LATERAL (
            VALUES (soft_skills_1), (soft_skills_2), (soft_skills_3), (soft_skills_4)
        ) AS v(skill)
        WHERE skill IS NOT NULL AND TRIM(skill) != ''
        GROUP BY grade, skill
    ) t
)
-- Объединяем по грейду и рангу (1-й с 1-м)
SELECT 
    COALESCE(h.grade, s.grade) AS grade,
    h.skill AS hard_skill,
    h.demand AS demand_hard,
    s.skill AS soft_skill,
    s.demand AS demand_soft
FROM hard_with_demand h
FULL OUTER JOIN soft_with_demand s
    ON h.grade = s.grade 
   AND h.rn = s.rn
WHERE COALESCE(h.rn, s.rn) <= 5
ORDER BY 
    CASE COALESCE(h.grade, s.grade)
        WHEN 'Junior' THEN 1
        WHEN 'Middle' THEN 2
        WHEN 'Senior' THEN 3
        ELSE 4
    END,
    COALESCE(h.rn, s.rn);




