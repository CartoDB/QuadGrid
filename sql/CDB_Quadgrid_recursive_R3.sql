CREATE OR REPLACE FUNCTION CDB_QuadGrid_R3(
    IN tablename regclass,
    IN threshold integer,
    IN resolution integer DEFAULT 1
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
DECLARE
    WEBMERCATOR_R numeric;
    EARTH_DIAMETER numeric;
BEGIN
    -- webmercator stuff
    -- calculated here to avoid extra work within the loops
    WEBMERCATOR_R := 6378137.0;
    EARTH_DIAMETER := WEBMERCATOR_R * 2.0 * PI();

    -- recursive stuff
    RETURN QUERY EXECUTE
    ' WITH
    RECURSIVE t(pid, id, x, y, z, e) AS (
        SELECT
            '||quote_literal('')||',
            '||quote_literal('0')||',
            0,
            0,
            0,
            (SELECT count(*) FROM '||tablename||')
        UNION ALL
        SELECT
            t.id,
            t.id ||'||quote_literal('-')||'|| (row_number() over())::text,
            x*2 + xx,
            y*2 + yy,
            z+1,
            (SELECT count(*) FROM '||tablename||' WHERE CDB_PointInTile(the_geom_webmercator, x*2 + xx, y*2 + yy, z+1, ' ||EARTH_DIAMETER || ' ))
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

-- ///////// support function ///////////////////////////////////////////////////////////////////////////////

CREATE OR REPLACE FUNCTION CDB_PointInTile(
    the_geom_webmercator geometry,
    x INTEGER,
    y INTEGER,
    z INTEGER,
    EARTH_DIAMETER numeric -- webmercator_earth_diameter
)
RETURNS boolean AS $$
DECLARE
    z_factor numeric;
    px numeric;
    py numeric;
    pixel_pos numeric[];
    result boolean;
BEGIN
    z_factor := 2^(z+8) / EARTH_DIAMETER;
    -- world coordinates related to (-180, 90)
    px := ST_X(the_geom_webmercator) + 0.5 * EARTH_DIAMETER;
    py := 0.5 * EARTH_DIAMETER - ST_Y(the_geom_webmercator);
    -- display coordinates
    pixel_pos := ARRAY[px * z_factor, py * z_factor];

    result := (x = FLOOR(pixel_pos[1]/256) AND  y = FLOOR(pixel_pos[2]/256)) ;

    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- //////// test recursion on 150K //////////////////////////////////////////////////////////////////////////

SELECT * FROM CDB_QuadGrid_R3('arbrat', 25);


-- notes

pixel_pos = [ x * 2^tile_z * 256 / EARTH_DIAMETER, y * 2^tile_z * 256 / EARTH_DIAMETER]
if(Math.floor(pixel_pos[0] / 256) == tile_x && Math.floor(pixel_pos[1] / 256) == tile_y) -> dentro
