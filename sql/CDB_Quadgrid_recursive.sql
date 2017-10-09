CREATE OR REPLACE FUNCTION CDB_QuadGrid_r2(
    IN tablename regclass,
    IN threshold integer,
    IN resolution integer DEFAULT 1
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
BEGIN
    RETURN QUERY EXECUTE
   ' WITH
    RECURSIVE t(pid, id, x, y, z, e) AS (
        SELECT
            '||quote_literal('')||','||quote_literal('0')||',0,0,0,(SELECT count(*) FROM '||tablename||')
        UNION ALL
        SELECT
            t.id, t.id ||'||quote_literal('-')||'|| (row_number() over())::text,x*2 + xx,y*2 + yy,z+1,
            (SELECT count(*) FROM '||tablename||' WHERE ST_Intersects(the_geom_webmercator,CDB_XYZ_Extent(x*2 + xx, y*2 + yy, z+1))
        FROM t, (VALUES (0, 0), (0, 1), (1, 1), (1, 0)) as c(xx, yy)
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


-- //// support functions /// https://github.com/CartoDB/cartodb-postgresql/blob/master/scripts-available/CDB_XYZ.sql ////////////////////////////

CREATE OR REPLACE FUNCTION CDB_XYZ_Resolution(z INTEGER)
RETURNS FLOAT8
AS $$
  SELECT 6378137.0*2.0*pi() / 256.0 / power(2.0, z);
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION CDB_XYZ_Extent(x INTEGER, y INTEGER, z INTEGER)
RETURNS GEOMETRY
AS $$
DECLARE
  origin_shift FLOAT8;
  initial_resolution FLOAT8;
  tile_geo_size FLOAT8;
  pixres FLOAT8;
  xmin FLOAT8;
  ymin FLOAT8;
  xmax FLOAT8;
  ymax FLOAT8;
  earth_circumference FLOAT8;
  tile_size INTEGER;
BEGIN

  tile_size := 256;

  initial_resolution := CDB_XYZ_Resolution(0);

  origin_shift := (initial_resolution * tile_size) / 2.0;

  pixres := initial_resolution / (power(2,z));

  tile_geo_size = tile_size * pixres;

  xmin := -origin_shift + x*tile_geo_size;
  xmax := -origin_shift + (x+1)*tile_geo_size;

  ymin := origin_shift - y*tile_geo_size;
  ymax := origin_shift - (y+1)*tile_geo_size;

  RETURN ST_MakeEnvelope(xmin, ymin, xmax, ymax, 3857);

END
$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT;


-- //////// test recursion on 150K ///////////////////////////////////////////////////////////////////////////////////////////

SELECT * FROM CDB_QuadGrid_r2('arbrat', 25);


-- /////// VODAFONE /////////////////////////////////////////////////////////////////////////////////////////////////////////
-- unique customers, per dow and hour //////////////////////////////////////////////////////////////////////////////////////

-- add dow and hour
SELECT
    clientid,
    extract(isodow from timestamp) as dow,
    extract(hour from timestamp) as h,
    the_geom
FROM sample

-- raw query
WITH
RECURSIVE t(pid, id, x, y, z, dow, h, e) AS (
    SELECT
        '','0',0,0,0, dow, h, count(*) FROM sample_dowh group by dow, h
    UNION ALL
    SELECT
        t.id, t.id ||'-'|| (row_number() over())::text,x*2 + xx,y*2 + yy,z+1,
      t.dow, t.h, (SELECT count(distinct clientid) FROM sample_dowh WHERE the_geom_webmercator && CDB_XYZ_Extent(x*2 + xx, y*2 + yy, z+1) and dow =t.dow and h=t.h)
    FROM t, (VALUES (0, 0), (0, 1), (1, 1), (1, 0)) as c(xx, yy)
    WHERE e >= 25 AND z < 25
),
potential as(SELECT pid, id, x, y, z, dow, h, e FROM t WHERE e >= 25),
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
