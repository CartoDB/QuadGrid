-- ordered by number of points, descending
with a as (
  SELECT array_agg(the_geom) as points fROM flights where cartodb_id % 3= 0 limit 100000
  )
SELECT qg.* FROM a, CDB_QuadGrid(a.points, 25, 1000)  qg;

with a as (
  SELECT array_agg(the_geom) as points fROM benches
  )
SELECT qg.* FROM a, CDB_QuadGrid(a.points, 25)   qg;

with a as (
  SELECT array_agg(the_geom) as points fROM benches where cartodb_id % 3= 0 limit 20000
  )
SELECT qg.* FROM a, CDB_QuadGrid(a.points, 25)  qg;

with a as (
  SELECT array_agg(the_geom) as points fROM streetlamps
  )
SELECT qg.* FROM a, CDB_QuadGrid(a.points, 25)  qg;


-- to check the number of resulting cells and coverage
with a as (
  SELECT array_agg(the_geom) as points fROM bancos_madrid where cartodb_id % 3= 0 limit 20000
  )
SELECT count(1), sum(occurrences), avg(occurrences) FROM a, CDB_QuadGrid(a.points, 25)  qg;
