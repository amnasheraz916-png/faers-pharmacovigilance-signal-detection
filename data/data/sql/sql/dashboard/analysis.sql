-- =====================================================
-- FAERS Pharmacovigilance Signal Detection Analysis
-- Drug: Vedolizumab
-- Tools: SQLite + Tableau
-- =====================================================


-- =====================================================
-- 1. Deduplicate Drug Table
-- Keep only primary suspect (PS) drugs
-- Remove duplicate drug reports
-- =====================================================

CREATE TABLE drug_ps_dedup AS
SELECT DISTINCT
    primaryid,
    drugname_clean
FROM drug
WHERE role_cod = 'PS';



-- =====================================================
-- 2. Deduplicate Reaction Table
-- Remove duplicate reactions per report
-- =====================================================

CREATE TABLE reac_dedup AS
SELECT DISTINCT
    primaryid,
    reaction_clean
FROM reac;



-- =====================================================
-- 3. Create Final Master Table
-- Join drug, reaction, and demographics
-- Remove:
-- - NULL age
-- - age = 0
-- - missing sex
-- =====================================================

CREATE TABLE master_final AS
SELECT DISTINCT
    d.primaryid,
    d.drugname_clean,
    r.reaction_clean,
    demo.age,
    demo.sex
FROM drug_ps_dedup d
JOIN reac_dedup r
    ON d.primaryid = r.primaryid
LEFT JOIN demo
    ON d.primaryid = demo.primaryid
WHERE demo.age IS NOT NULL
  AND demo.age > 0
  AND demo.sex IS NOT NULL
  AND demo.sex <> '';



-- =====================================================
-- 4. Signal Counts (a)
-- Count drug-reaction combinations
-- =====================================================

CREATE TABLE signal_counts AS
SELECT
    drugname_clean AS drug,
    reaction_clean AS reaction,
    COUNT(*) AS a
FROM master_final
GROUP BY
    drugname_clean,
    reaction_clean;



-- =====================================================
-- 5. Drug Totals
-- Total reports per drug
-- =====================================================

CREATE TABLE drug_totals AS
SELECT
    drugname_clean AS drug,
    COUNT(*) AS total_drug_reports
FROM master_final
GROUP BY drugname_clean;



-- =====================================================
-- 6. Reaction Totals
-- Total reports per reaction
-- =====================================================

CREATE TABLE reaction_totals AS
SELECT
    reaction_clean AS reaction,
    COUNT(*) AS total_reaction_reports
FROM master_final
GROUP BY reaction_clean;



-- =====================================================
-- 7. Calculate ROR and PRR
-- =====================================================

CREATE TABLE signal_summary AS
SELECT
    s.drug,
    s.reaction,
    s.a,

    (d.total_drug_reports - s.a) AS b,

    (r.total_reaction_reports - s.a) AS c,

    (
      (SELECT COUNT(*) FROM master_final)
      - s.a
      - (d.total_drug_reports - s.a)
      - (r.total_reaction_reports - s.a)
    ) AS d,

    ROUND(
      CAST(
        (
          s.a *
          (
            (SELECT COUNT(*) FROM master_final)
            - s.a
            - (d.total_drug_reports - s.a)
            - (r.total_reaction_reports - s.a)
          )
        ) AS FLOAT
      )
      /
      (
        (d.total_drug_reports - s.a)
        *
        (r.total_reaction_reports - s.a)
      ),
      2
    ) AS ROR,

    ROUND(
      (
        CAST(s.a AS FLOAT)
        /
        d.total_drug_reports
      )
      /
      (
        CAST(
          (r.total_reaction_reports - s.a)
          AS FLOAT
        )
        /
        (
          (SELECT COUNT(*) FROM master_final)
          - d.total_drug_reports
        )
      ),
      2
    ) AS PRR

FROM signal_counts s
JOIN drug_totals d
    ON s.drug = d.drug
JOIN reaction_totals r
    ON s.reaction = r.reaction;



-- =====================================================
-- 8. Clean Signal Table
-- Remove indication-related
-- and administrative noise
-- =====================================================

CREATE TABLE signal_summary_clean AS
SELECT *
FROM signal_summary
WHERE reaction NOT IN (
    'CROHN''S DISEASE',
    'OFF LABEL USE',
    'PRODUCT DOSE OMISSION ISSUE',
    'PRODUCT USE ISSUE',
    'INAPPROPRIATE SCHEDULE OF PRODUCT ADMINISTRATION'
);



-- =====================================================
-- 9. View Top Vedolizumab Signals
-- =====================================================

SELECT *
FROM signal_summary_clean
WHERE drug = 'VEDOLIZUMAB'
ORDER BY ROR DESC;