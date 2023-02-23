# postgres - SQL code for various views of the blitscan database

# species counts by red-list status within each genus 
CREATE VIEW genera AS
    SELECT *,count(*) FROM
        (SELECT split_part(name_sci, ' ', 1) AS genus,status
        FROM species) AS foo
    GROUP BY genus,status
    ORDER BY genus,count DESC;


# document count per-species - corresponding to the per-status boxplot
# under 'species coverage' on the dashboard
CREATE VIEW doc_count AS
    SELECT foo."SISRecID",name_com,name_sci,status,count FROM
        (SELECT CAST(unnest(string_to_array(species, '|')) AS Integer) AS "SISRecID",count(*) 
            FROM links
            GROUP BY "SISRecID") AS foo
        INNER JOIN
        (SELECT status,name_com,name_sci,"SISRecID" 
            FROM species) AS bar
        ON foo."SISRecID" = bar."SISRecID"
    ORDER BY status,count desc;


# Journal titles coming from OpenAlex
SELECT "container.title",count(*) 
FROM dois 
WHERE doi IN (
    SELECT DISTINCT doi 
    FROM openalex
)
GROUP BY "container.title"
ORDER BY count DESC;

# language distribution for conservation-relevant docs since 2010 from OpenAlex
SELECT regexp_replace(language, 'en\||\|en', '') AS lang,count(*) 
FROM links 
WHERE search_term ilike 'openalex%' 
    AND language!='en' AND gotscore=1 
    AND score > -8.0 
    AND length(species)>0 
    AND date > '2010-01-01' 
GROUP BY lang 
ORDER BY count DESC 
LIMIT 15;

# average processing count of English vs non-English pver past month
SELECT english,min(count),avg(count),max(count) 
FROM (
    SELECT query_date,
            (language != 'en' AND gotspecies=1 AND length(species)>0) AS english,
            count(*) 
    FROM links where gottext = 1 
    GROUP BY query_date,english 
    ORDER BY query_date DESC 
    limit 30
    ) AS foo 
GROPU BY english;

# building on document count per-species above - 
# restrict to OpenAlex and get language counts too
SELECT foo.sisrecid,name_com,name_sci,status,lang,count FROM
    (SELECT CAST(unnest(string_to_array(species, '|')) AS Integer) AS sisrecid,
            regexp_replace(language, 'en\||\|en', '') AS lang,
            count(*) 
        FROM links
        WHERE search_term ilike 'openalex%'
        GROUP BY sisrecid,lang) AS foo 
        
    INNER JOIN
    (SELECT status,name_com,name_sci,"SISRecID" AS sisrecid
        FROM species) AS bar
    ON foo.sisrecid = bar.sisrecid
ORDER BY foo.sisrecid,count DESC;
