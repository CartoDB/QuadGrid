CREATE OR REPLACE FUNCTION CDB_QuadGrid_old(
    IN points geometry[],
    IN threshold integer,
    IN resolution integer DEFAULT 1
    )
RETURNS TABLE(the_geom geometry, occurrences bigint)  AS $$
DECLARE
    -- initial
    cell geometry;
    -- indexes
    i bigint;
    n bigint;
    -- loop vars
    cs geometry[];
    ns bigint[];
    vs bigint[];
    tcs geometry[];
    tns bigint[];
    tvs bigint[];
    -- checks
    checker integer;
BEGIN

    -- NOTES - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- all the calcs are made in 3857 to keep the geometries' shape
    -- valid:
    --      0: not valid
    --      1: valid and might be resampled
    --      2: valid and added to results
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    -- CELL #0, minimum bounding square
    cell := ST_Transform(ST_Envelope(ST_MinimumBoundingCircle(ST_collect(points))), 3857);
    cs := ARRAY[cell];
    ns := ARRAY[array_length(points, 1)];
    IF ns[1] < threshold THEN
        RAISE EXCEPTION 'The initial number of points(%) is below the threshold(%)', ns[1], threshold ;
        vs := ARRAY[0];
    ELSE
        vs := ARRAY[1];
    END IF;

    -- looping the loop
    n :=1;
    i := 1;
    LOOP

        cell := cs[i];

        -- loop end condition
        EXIT WHEN i > n;

        -- not valid, continue
        IF vs[i] = 0 THEN
            cs[i] = null;
            i := i + 1;
            CONTINUE;
        END IF;

        -- if next generation size is below resolution,
        -- keep this cell and continue
        IF (ST_XMax(cell) - ST_XMin(cell)) < 2 * resolution THEN
            vs[i] := 2;
            i := i + 1;
            CONTINUE;
        END IF;

        -- else, get the next depth level
        WITH
        -- points datasaset
        _p as(
            SELECT st_transform(t.g, 3857) as geom from unnest(points) as t(g)
        ),
        -- the current cell is now the parent of the next generation
        _parent as(
            SELECT
                cell as geom,
                ST_centroid(cell) as center
        ),
        -- new generation, 4 childs per parent
        _children as(
            SELECT
                ST_Envelope(ST_MakeLine(_parent.center, _nodes.node)) as geom
            FROM
            _parent,
            (
                    SELECT
                        (dp).geom AS node
                    FROM (SELECT ST_DumpPoints(ST_ExteriorRing(geom)) as dp FROM _parent) _vertex
                    WHERE (dp).path[1] < 5
            ) _nodes
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
                SELECT count(1) as nn FROM _p where ST_Intersects(_children.geom, _p.geom)
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
            i := i + 1;
        -- else, invalidate the parent and add the children to the list
        ELSE
            vs[i] := 0;
            cs[i] = null;
            cs := cs || tcs;
            ns := ns || tns;
            vs := vs || tvs;
            n := array_length(cs, 1);
            i := i + 1;
        END IF;

    END LOOP;

    -- epxplode the valid results to a usable table
    RETURN QUERY
        SELECT
            st_transform(t.g, 4326) as the_geom,
            t.n as occurrences
        FROM
            unnest(cs,ns,vs) as t(g,n,v)
        WHERE t.v = 2;

END;
$$ language plpgsql IMMUTABLE;
