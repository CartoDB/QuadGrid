# QuadGrid
Quadgrid for [GDPR](http://www.eugdpr.org/) compliance which will be compulsory starting in March 2018

As the telco data has a lot of concerns in terms of privacy, an irregular grid where the size of the cell is the minimal one that complies with the limitations (like a minimum number of events per cell as threshold) will provide the best resolution across the area of study being compliant with the restriction.

The idea is to provide an irregular grid where each cell has the maximal LoD (up to a given resolution) while being compliant with a restriction (occurences per cell above a given threshold). This **QuadGrid** is the result of aplying [quadtree](https://en.wikipedia.org/wiki/Quadtree) schema with a different restriction.

![image](https://user-images.githubusercontent.com/9017165/31018568-ecf6c8e8-a52c-11e7-95b7-b358aff06839.png)

Link to test:  https://team.carto.com/u/abel/builder/b1275d91-bc38-4d49-a1b2-6b5166856021/embed

Current version (SQL) is below **O(N³)**, recursive version (SQL) is much faster, close to **O(N)**. Related to threshold size, R2 (recursive SQL) preocessing time is decreasing with the square of the threshold, as expected.

Some benchmarks (local OnPrem 2.0, timeout 5min, SQL versions)

| version | streetlamps (7K) | benches (20K) | benches (65K) | thrashbins (90K) |flights (100K, WW) | trees (150K) | flights (400K, WW) |
|---|---|---|---|---|---|---|---|
| 1 | 211 ms  | 44 s  | timeout  | |  timeout  |  timeout  |  timeout  |
| 2  | 59 ms | 8 s | 75.3 s  |  |4:14 min  |  timeout  |  timeout  |
| 3  | 50 ms | 7 s | 68.3 s  | 1:47 min |3:43 min  | 4:59 min |  timeout  |
| R2  | 19 ms |  | 1.4 s  | 2.11 s | |  4 s |  4:15 min  |
