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

