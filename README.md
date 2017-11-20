# QuadGrid

Because of the upcoming EU law for privacy, the [GDPR](http://www.eugdpr.org/), I started working on a way to provide a griding method that could provide the custtomers the highest level of detail of their data while being compliant with the law.

In a simplistic way, the requirement is to avoid any way to identify an individual based on the exposed data. So we need to generate `overviews` of the data where the KPIs are aggregated and the anonimity enforced. In terms of location data, the provider should also provides spatial-temporal anonymization, and this requirement is not explicitally defined by the law. Some providers are limiting the level of detail to existing administrative divisios like `census tracts` or an arbitrary sized and located grid of 0.25km² cells.

As this 500m x 500m cell size can be quite far from optimal in most of the cases:
* Urban center, shooping area: the amount of occurences in a cell this size can be several orders higher than the threshold
* Low populated country side: a cell this size might enclose so few occurences that it could identify an individual

Census tracts might be better fitted to the population, but in terms of inhabitants not passers by. 

So the idea might be an adaptative grid where the size of the cell is the minimal one (max level of detail) that complies with the limitations (like a minimum number of events or unique individuals per cell as threshold) will provide the best resolution across the area of study being compliant with the legal restriction.

This **QuadGrid** is the result of aplying [quadtree](https://en.wikipedia.org/wiki/Quadtree) schema with a different restriction.

![image](https://user-images.githubusercontent.com/9017165/33017584-283b9502-cdf3-11e7-92a8-0ab6d021b93d.png)

Link to test:  https://team.carto.com/u/abel/builder/b1275d91-bc38-4d49-a1b2-6b5166856021/embed

We're using the [webmercator tiling schema](https://msdn.microsoft.com/en-us/library/bb259689.aspx) as the way to define the cells, so the result can be easyly assimilated to common web mapping tools

I stared with a plain PL/pgSQL version in order to have a debugging version of the algorithm, and then thanks to a talk with [javisantana](https://github.com/javisantana) , I move it to a recursive version that had a great impact on performance and led me to research on [index clustering](https://www.postgresql.org/docs/current/static/sql-cluster.html) that improved the performance even more

Performance:
* Plain SQL (V1): below **O(N³)**
* Recursive SQL (R2): close to **O(N)**
* Python: WiP

Related to threshold size, R2 (recursive SQL) preprocessing time is decreasing with the square of the threshold, as expected.

Some benchmarks (local OnPrem 2.0, timeout 5min, SQL versions)

| version | streetlamps (7K) | benches (20K) | benches (65K) | thrashbins (90K) |flights (100K, WW) | trees (150K) | flights (400K, WW) |
|---|---|---|---|---|---|---|---|
| 1 | 211 ms  | 44 s  | timeout  | |  timeout  |  timeout  |  timeout  |
| 2  | 59 ms | 8 s | 75.3 s  |  |4:14 min  |  timeout  |  timeout  |
| 3  | 50 ms | 7 s | 68.3 s  | 1:47 min |3:43 min  | 4:59 min |  timeout  |
| R2  | 19 ms |  | 1.4 s  | 2.11 s | |  4 s |  4:15 min  |
| R2 + cluster  | 60 ms |  | 2.6 s  | 4 s | |  9.25 s |  48 s  |
