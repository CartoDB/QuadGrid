CREATE OR REPLACE FUNCTION CDB_QuadGrid(
    IN points geometry[],
    IN threshold integer,
    IN resolution integer DEFAULT 1
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
DECLARE
    -- geom
    cell geometry;
    center geometry;
    vertex geometry[];
    -- indexes
    i bigint;
    -- final results
    cs geometry[]; -- cells
    ns bigint[]; -- count of points in cells
    vs integer[]; -- validity check of cells
    -- loop vars
    cp geometry[]; -- points in parent cell
    tcs geometry[]; -- children cells
    tns bigint[]; -- count of points in children cells
    tvs integer[]; -- validity check of children cells
    checker integer;  -- at least 1 children is valid
BEGIN

    -- NOTES - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    --      0: not valid
    --      1: valid and might be resampled
    --      2: valid and added to results
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    -- all the calcs are made in 3857 to keep the geometries' shape
    SELECT array_agg(st_transform(t.g, 3857)) into points from unnest(points) as t(g);

    -- CELL #0, minimum bounding square
    cell := ST_Envelope(ST_MinimumBoundingCircle(ST_collect(points)));

    -- initialize cs, ns, vs arrays
    cs := ARRAY[cell];
    ns := ARRAY[array_length(points, 1)];
    IF ns[1] < threshold THEN
        RAISE EXCEPTION 'The initial number of points(%) is below the threshold(%)', ns[1], threshold ;
        vs := ARRAY[0];
    ELSEIF (ST_XMax(cell) - ST_XMin(cell)) < resolution THEN
        RAISE EXCEPTION 'The initial spatial size of the dataset is below the resolution (% pseudometers)', resolution ;
        vs := ARRAY[0];
    ELSE
        vs := ARRAY[1];
    END IF;

    -- looping the loop
    LOOP

        -- first cell that can be splitted
        i := array_position(vs, 1);

        -- loop end condition
        -- no more cells to be splitted
        EXIT WHEN i is null;

        -- else
        cell := cs[i];

        -- if next generation size is below resolution,
        -- keep this cell and continue
        IF (ST_XMax(cell) - ST_XMin(cell)) < 2 * resolution THEN
            vs[i] := 2;
            CONTINUE;
        END IF;

        -- if the cell can be splitted,
        -- retrieve the center (center)
        center := ST_centroid(cell);
        -- cell's corners (vertex)
        SELECT
            array_agg((dp).geom) into vertex
        FROM (SELECT ST_DumpPoints(ST_ExteriorRing(cell)) as dp) _vertex
        WHERE (dp).path[1] < 5;
        -- points within the cell (cp)
        SELECT array_agg(t.g) INTO cp FROM unnest(points) as t(g) where ST_Intersects(cell, t.g);

        -- get the next depth level
        WITH
        -- build the new generation
        _children as(
            SELECT
                ST_Envelope(ST_MakeLine(center, _nodes.node)) as geom
            FROM unnest(vertex) as _nodes(node)
        ),
        -- evaluate the population and validity of children cells
        _childrenval as(
            SELECT
                geom,
                _c.nn,
                CASE WHEN _c.nn < threshold THEN 0 ELSE 1 END AS v
            FROM _children
            CROSS JOIN
            LATERAL (
                SELECT count(1) as nn FROM unnest(cp) as t(g) where ST_Intersects(_children.geom, t.g)
            ) _c
        )
        -- aggregate the children
        SELECT
            array_agg(geom),
            array_agg(nn),
            array_agg(v),
            sum(v)
        INTO
            tcs, tns, tvs, checker
        FROM _childrenval;

        -- if all the children are below the threshold,
        -- add the parent to results and continue
        IF checker = 0 THEN
            vs[i] := 2;
        -- else, drop the parent and add the children
        -- to the list of potential results
        ELSE
            vs[i] := 0;
            WITH pre as(
                SELECT p.* FROM unnest(cs,ns,vs) as p(cc,nn,vv)
                WHERE p.vv > 0
                UNION ALL
                SELECT t.* FROM unnest(tcs,tns,tvs) as t(cc,nn,vv)
                WHERE t.vv = 1
            )
            SELECT
                array_agg(cc),
                array_agg(nn),
                array_agg(vv)
            INTO cs, ns, vs
            FROM pre;

        END IF;

    END LOOP;

    -- explode the valid results to a usable table
    RETURN QUERY
        SELECT
            st_transform(t.gg, 4326) as the_geom,
            t.nn as occurrences
        FROM
            unnest(cs,ns,vs) as t(gg,nn,vv)
        WHERE t.vv = 2;

END;
$$ language plpgsql IMMUTABLE;