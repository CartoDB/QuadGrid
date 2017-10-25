WITH
-- build all the possible cells
RECURSIVE t(pid, id, x, y, z, hour, e) AS (
    SELECT
        '','0',0,0,0, hour, count(*) FROM day_27_2017 group by hour
    UNION ALL
    SELECT
        t.id, t.id ||'-'|| (row_number() over())::text,x*2 + xx,y*2 + yy,z+1,
       t.hour, (SELECT count(distinct clientid) FROM day_27_2017 WHERE the_geom_webmercator && CDB_XYZ_Extent(x*2 + xx, y*2 + yy, z+1) and hour=t.hour)
    FROM t, (VALUES (0, 0), (0, 1), (1, 1), (1, 0)) as c(xx, yy)
    WHERE e >= 25 AND z < 25
),
-- filter the non compliant cells
potential as(SELECT pid, id, x, y, z, hour, e FROM t WHERE e >= 25),
-- check the cells with children
cleaned as(
    SELECT x, y, z,  hour, e, coalesce(c, 0) as c
    FROM
        potential p1
    left join
        lateral(SELECT count(1) as c FROM potential where pid = p1.id) p2
    ON 1=1
)
-- filter the cells with children and return geometries instead of tile coordinates
SELECT
    hour,
    ST_transform(CDB_XYZ_Extent(x, y, z), 3857) as the_geom,
    e as occurrences
FROM cleaned
WHERE c = 0


-- function
CREATE OR REPLACE FUNCTION CDB_QuadGrid_vodafone(
    IN tablename regclass,
    IN threshold integer
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
BEGIN
    RETURN QUERY EXECUTE
   'WITH
    RECURSIVE t(pid, id, x, y, z, dow, h, e) AS (
        SELECT
            '||quote_literal('')||','||quote_literal('0')||',0,0,0, dow, h, count(distinct clientid) FROM '||tablename||' group by dow, h
        UNION ALL
        SELECT
            t.id,
            t.id ||'||quote_literal('-')||'|| (row_number() over())::text,
            x*2 + xx,
            y*2 + yy,
            z+1,
            t.dow,
            t.h,
            (SELECT count(distinct clientid) FROM '||tablename||' WHERE ST_Intersects(the_geom_webmercator, CDB_XYZ_Extent(x*2 + xx, y*2 + yy, z+1)) and dow = t.dow and h = t.h)
        FROM
            t,
            (VALUES (0, 0), (0, 1), (1, 1), (1, 0)) as c(xx, yy)
        WHERE e >= '||threshold||' AND z < 25
    ),
    potential as(SELECT pid, id, x, y, z, dow, h, e FROM t WHERE e >= '||threshold||'),
    cleaned as(
        SELECT x, y, z, dow, h, e, coalesce(c, 0) as c
        FROM
            potential p1
        left join
            lateral(SELECT count(1) as c FROM potential where pid = p1.id) p2
        ON 1=1
    )
    SELECT
        dow, h,
        ST_transform(CDB_XYZ_Extent(x, y, z), 3857) as the_geom,
        e as occurrences
    FROM cleaned
    WHERE c = 0;';
END;
$$ language plpgsql IMMUTABLE;
