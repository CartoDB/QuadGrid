# QuadGrid
Quadgrid for [GDPR](http://www.eugdpr.org/) compliance which will be compulsory starting in March 2018

As the telco data has a lot of concerns in terms of privacy, an irregular grid where the size of the cell is the minimal one that complies with the limitations (like a minimum number of events per cell as threshold) will provide the best resolution across the area of study being compliant with the restriction.

In this test, can be noted that there are cells with `occurrences > 4 * threshold`, and that's because the size of that cell is just one step above resolution limit so it can't be split again regardless the high density.

![image](https://user-images.githubusercontent.com/9017165/31018568-ecf6c8e8-a52c-11e7-95b7-b358aff06839.png)

Link to test:  https://team.carto.com/u/abel/builder/b1275d91-bc38-4d49-a1b2-6b5166856021/embed

Current version (SQL) is **O(N³)**

Some benchmarks (locan OnPrem 2.0)

|  version | streetlamps (7K rows)   | benches (20K rows)   |   benches (65K rows)   |  flights (100K rows worldwide) |
|---|---|---|---|---|
| 1 | 211 ms  | 44 s  | >5min (timeout)  |  >5min (timeout)  |
| 2  | 59 ms | 8 s | 75.3 s  | 4:14 min  |
| 3  | 50 ms | 7 s | 68.3 s  |  4:10 min  |
