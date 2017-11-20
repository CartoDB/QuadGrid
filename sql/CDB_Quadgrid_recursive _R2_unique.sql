-- function
CREATE OR REPLACE FUNCTION CDB_QuadGrid_unique(
    IN tablename regclass,
    IN threshold integer,
    IN uniqueid text
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
DECLARE
    wm_column text;
BEGIN

    -- retrieve actual name of webmercator index
    -- because the name of it is related to the original name of the table
    EXECUTE 'SELECT indexname FROM pg_indexes WHERE tablename = '||quote_literal(tablename)||' and indexname like '||quote_literal('%_the_geom_webmercator_idx')  INTO wm_column ;

    -- sort the table by the_geom_webmercator
    -- this improves performance 15% - 25%
    -- depending on how the data is spread
    -- the time needed for clustering is
    EXECUTE 'CLUSTER '||tablename||' USING ' || wm_column;

    -- vaccum the table for map visibility results in no improvement
    -- https://www.postgresql.org/docs/current/static/routine-vacuuming.html#VACUUM-FOR-VISIBILITY-MAP
    RETURN QUERY EXECUTE
   'WITH
    RECURSIVE t(pid, id, x, y, z, e) AS (
        SELECT
            '||quote_literal('')||','||quote_literal('0')||',0,0,0, count(distinct '||uniqueid||') FROM '||tablename||' group by dow, h
        UNION ALL
        SELECT
            t.id,
            t.id ||'||quote_literal('-')||'|| (row_number() over())::text,
            x*2 + xx,
            y*2 + yy,
            z+1,
            (SELECT count(distinct '||uniqueid||') FROM '||tablename||' WHERE ST_Intersects(the_geom_webmercator, CDB_XYZ_Extent(x*2 + xx, y*2 + yy, z+1)))
        FROM
            t,
            (VALUES (0, 0), (0, 1), (1, 1), (1, 0)) as c(xx, yy)
        WHERE e >= '||threshold||' AND z < 25
    ),
    potential as(SELECT pid, id, x, y, z, e FROM t WHERE e >= '||threshold||'),
    cleaned as(
        SELECT x, y, z, e, coalesce(c, 0) as c
        FROM
            potential p1
        left join
            lateral(SELECT count(1) as c FROM potential where pid = p1.id) p2
        ON 1=1
    )
    SELECT
        ST_transform(CDB_XYZ_Extent(x, y, z), 3857) as the_geom,
        e as occurrences
    FROM cleaned
    WHERE c = 0;';
END;
$$ language plpgsql IMMUTABLE;
