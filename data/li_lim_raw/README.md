# Li & Lim LC1 source files

These 50 `.vrp` files were downloaded on 2026-10-23 from
`https://raw.githubusercontent.com/PyVRP/Instances/main/PDPTW/`.
Classes `LC1_2`, `LC1_4`, `LC1_6`, and `LC1_8` are in subdirectories
`Li200`, `Li400`, `Li600`, and `Li800` respectively. Class `LC1_10` is at the
top level.
The PyVRP files identify themselves as conversions of the SINTEF Li & Lim
benchmark. `SHA256SUMS` records the exact bytes used here.

The class names are approximate request counts: `LC1_2` is about 100 requests,
`LC1_4` about 200, and so on. The `LC1_2` files have 103–107
pickup-delivery pairs, so experiments record both the nominal class and the
actual pair count. No task is dropped. The source depot is
preserved. The PDPTW demand, time windows, service time, fleet and capacity
fields are discarded; PDP-CR processing time is Euclidean pickup-to-delivery
distance. Robot requirements are independently sampled from `1:5` with the
documented conversion seed. This recreates the *method* described in the thesis;
the author's exact converted files, selected benchmark cases and RNG seed are
not known.

Primary source and format description:
https://www.sintef.no/projectweb/top/pdptw/li-lim-benchmark/
https://www.sintef.no/projectweb/top/pdptw/documentation/
