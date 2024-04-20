---Creating Main Table---
DROP TABLE IF EXISTS spells CASCADE;
CREATE TABLE spells(
	web_scraper_order VARCHAR,
	web_scraper_start_url VARCHAR,
	pagination VARCHAR,
	spell_element VARCHAR,
	spell_element_href VARCHAR,
	spell_name 	VARCHAR,
	spell_level VARCHAR,
	spell_castingtime VARCHAR,
	spell_compents VARCHAR,
	spell_school VARCHAR,
	spell_attack_save VARCHAR,
	spell_damage_effecr VARCHAR,
	spell_descript VARCHAR,
	spell_tag VARCHAR,
	spell_class_avail VARCHAR 
);
---Populating Table---
COPY spells (web_scraper_order, web_scraper_start_url, pagination, spell_element,spell_element_href,
	spell_name, spell_level,spell_castingtime,spell_compents,spell_school,spell_attack_save,
	spell_damage_effecr,spell_descript,spell_tag,spell_class_avail
)
FROM 'C:\Users\Public\dndattempt2.csv'
WITH (FORMAT CSV, header, delimiter ',');

select * from spells;
---Dropping duplicates/inaccessable spells---
SELECT spell_name, COUNT(*) as spell_count
FROM spells
GROUP BY spell_name
ORDER BY COUNT(*) DESC;


DELETE FROM spells WHERE spell_name='The Book of Many Things';


DELETE FROM spells WHERE spell_name='Planescape: Adventures in the Multiverse';


DELETE FROM spells WHERE spell_name='Icewind Dale: Rime of the Frostmaiden';


ALTER TABLE spells
DROP COLUMN spell_element;


ALTER TABLE spells
DROP COLUMN pagination;



---Adding Primary Key---
ALTER TABLE spells
ADD spell_id SERIAL PRIMARY KEY;

----Fixing spell tags-----	

--Getting rid of the strange spacing---
UPDATE spells
SET spell_tag = 
		REGEXP_SPLIT_TO_ARRAY( -- results in {'Damage', 'Movement', 'Combat'}
			REGEXP_REPLACE(      -- results in 'Damage Movement Combat'
				REGEXP_REPLACE(    -- results in 'DamageMovementCombat'
					spell_tag, 
					E'Spell Tags:|[\\t\\n\\r\\s+]', 
					'', 
					'g' ),
				E'([a-z])([A-Z])', 
				'\1 \2', 
				'g'),
			' ');

select spell_tag from spells;

---FIXING CLASS TAGS---
UPDATE spells
SET spell_class_avail=  REGEXP_SPLIT_TO_ARRAY(
		REGEXP_REPLACE(
			REGEXP_REPLACE(   
				spell_class_avail, 
				E'[\\t\\n\\r]+|Available For:|[\\t\\n\\r]+', 
				'', 
				'g' ),
			E'([A-Za-z]+)',
			'\1',
			'g'),
		'                                                            ');

select spell_class_avail from spells;


select * from spells;

ALTER TABLE spells
DROP COLUMN web_scraper_order,
DROP COLUMN web_scraper_start_url;
--
--DATABASE VIEWS
--View 1: Spell Summary
CREATE VIEW spell_summary AS
SELECT spell_id, spell_name, spell_level, spell_tag, spell_class_avail
FROM spells;

SELECT * FROM spell_summary;

--View 2: Spell Count by School
CREATE VIEW spell_count_by_school AS
SELECT spell_school, COUNT(*) as spell_count
FROM spells
GROUP BY spell_school;

SELECT * FROM spell_count_by_school;

--View 3: Spells with Attack or Save
CREATE VIEW spells_with_attack_save AS
SELECT spell_id, spell_name, spell_attack_save
FROM spells
WHERE spell_attack_save != 'None';

SELECT * FROM spells_with_attack_save;
----
CREATE VIEW wizard_spells AS
SELECT spell_id, spell_name, spell_class_avail
FROM spells
WHERE spell_class_avail ILIKE '%Wizard%';

SELECT * FROM wizard_spells;

--STORED PROCEDURE to enables entry of a record
--insert_spell
CREATE OR REPLACE PROCEDURE insert_spell(
    p_name VARCHAR,
    p_level VARCHAR,
    p_school VARCHAR,
    p_tag VARCHAR
)
AS
$$
BEGIN
    INSERT INTO spells (spell_name, spell_level, spell_school, spell_tag)
    VALUES (p_name, p_level, p_school, p_tag);
END;
$$
LANGUAGE plpgsql;

--TESTING
-- Call the procedure to insert a new spell
CALL insert_spell('New Spell', '3', 'Evocation', 'Damage');
-- Check the result
SELECT * FROM spells WHERE spell_name = 'New Spell';

--STORED PROCEDURE to export a CSV file containing the data from one of the views
CREATE OR REPLACE PROCEDURE export_spell_summary_csv()
AS
$$
BEGIN
    COPY (SELECT * FROM spell_summary) TO '/public/spell_summary.csv' WITH CSV HEADER; --i guess change to whatever the correct path is
END;
$$
LANGUAGE plpgsql;

--TESTING
-- Call the procedure to export the spell summary to CSV
CALL export_spell_summary_csv();

--TRIGGER to intercept a delete on the main table and instead perform an archive
CREATE OR REPLACE FUNCTION archive_deleted_spell()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO spells_archive
    SELECT OLD.*;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER archive_spell_trigger
BEFORE DELETE ON spells
FOR EACH ROW
EXECUTE FUNCTION archive_deleted_spell();
