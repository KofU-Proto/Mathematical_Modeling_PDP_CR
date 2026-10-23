# PDP-CR — Thành viên 1 (Julia)

Module Julia cho phần mô hình dữ liệu, biểu diễn nghiệm, flow-DAG/evaluator và
nghiệm greedy ban đầu. Mã này dùng Julia standard library, không cần package
ngoài.

## Chạy kiểm thử

Mở PowerShell tại thư mục project:

```powershell
Set-Location "\Mathematical_Modeling_PDP_CR"
julia --project=. test/runtests.jl
```

## Dùng module

```julia
include("src/PDPCRMember1.jl")
using .PDPCRMember1

instance = generate_instance(10, 6; seed=7)
solution = greedy_initial_solution(instance; seed=7)
schedule = evaluate_schedule(instance, solution)

println("Makespan = ", schedule.makespan)
println("Feasible = ", is_feasible(instance, solution))
visualize_solution(instance, solution; output_path="plots/sample_simulation.svg")
```

Hàm `visualize_solution` xuất một file SVG gồm sơ đồ tuyến robot trên mặt bằng
và biểu đồ Gantt. Màu sắc phân biệt robot; mũi tên chỉ hướng đi; vùng gạch chéo
trong Gantt biểu diễn robot chờ các thành viên khác của đội đến task.

Chạy mô phỏng cả 6 bộ sample và xuất hình SVG:

```powershell
julia --project=. examples\visualize_sample.jl
```

Mỗi instance sinh một hình riêng tại `plots/sample_simulation_m{m}_n{n}.svg`;
có thể mở các hình bằng trình duyệt.

Đọc instance CSV có các cột `task_id,pickup_x,pickup_y,delivery_x,delivery_y,
processing_time,required_robots`. Có thể bỏ cột `processing_time` hoặc để
trống giá trị; khi đó module tự tính khoảng cách Euclidean pickup-delivery.
File mẫu nằm tại `data/sample.csv`.

```julia
instance = load_instance("data/sample.csv", 2)
save_instance(instance, "data/generated.csv")
```

### Bộ sample theo số robot và số task

Thư mục `data/` có 6 instance CSV bao phủ mọi tổ hợp `m ∈ {1, 2}` robot và
`n ∈ {5, 10, 15}` task. Tên file theo dạng `sample_m{m}_n{n}.csv`, ví dụ
`data/sample_m2_n10.csv`. Các file được sinh tái lập bằng seed cố định; số
robot yêu cầu của mỗi task luôn không vượt quá số robot trong instance.

Để tạo lại toàn bộ bộ dữ liệu:

```powershell
julia --project=. examples\generate_sample_data.jl
```

Ví dụ nạp bộ `m=2`, `n=10`:

```julia
instance = load_instance("data/sample_m2_n10.csv", 2)
```

## Thành phần đã triển khai

- `src/data.jl`: `PDPTask`, `ProblemInstance`, khoảng cách, sinh dữ liệu và CSV.
- `src/solution.jl`: thứ tự ưu tiên, đội robot theo task và kiểm tra nghiệm.
- `src/evaluator.jl`: tạo flow-DAG, kiểm tra bảo toàn flow, tính lịch đồng bộ,
  thời gian di chuyển, thời gian quay về depot và makespan.
- `src/initial_solution.jl`: greedy initializer chọn task và robot dựa trên
  thời điểm hoàn tất dự kiến sớm nhất.
- `test/runtests.jl`: kiểm tra dữ liệu, CSV, tính khả thi, flow và evaluator.

Robot được đánh số từ 1 đến m; task được đánh số theo vị trí trong `instance.tasks`.
Nguồn flow dùng node 0, sink dùng node n+1. Đây là phần việc Thành viên 1;
neighborhood và Tabu Search được tích hợp ở các module khác.
---

# PDP-CR — Thành viên 2: flow-DAG và neighborhood (Julia)

Module `PDPCRMember2` cài đặt cách biểu diễn nghiệm dạng flow-DAG và ba
neighborhood của bài báo *Redistribute neighborhood in the PDP-CR*. Module dùng
kiểu dữ liệu của Thành viên 1; nạp cả hai qua `src/PDPCR.jl`.

```powershell
julia --project=. test/test_member2.jl        # kiểm thử (gồm ví dụ 1 và ví dụ 3 của bài báo)
julia --project=. examples/member2_demo.jl    # minh họa
```

```julia
include("src/PDPCR.jl")
using .PDPCRMember1, .PDPCRMember2, Random

instance = generate_instance(40, 8; seed=1)
s  = from_solution(FlowProblem(instance), instance, greedy_initial_solution(instance; seed=1))
ev = evaluate(s)                     # thứ tự topo, L, L̄, L*, makespan
res = redistribute(s, choose_cut(s)) # cắt tại ζ ngẫu nhiên và phân phối lại flow
cands = generate_neighbors(s; config=default_config(40, :TSR), rng=MersenneTwister(1))
best = argmin(c -> c.after, cands)
s = materialize(s, best)             # nghiệm mới
```

| File | Nội dung |
| :--- | :--- |
| `src/flow_graph.jl` | `FlowProblem`, `FlowSolution`; chuyển đổi với `Solution`; thứ tự topo; Algorithm 1–2 (`L`, `L*`); makespan; cung găng; kiểm tra hợp lệ |
| `src/neighborhoods.jl` | `Move`, `Candidate`, đánh giá tại chỗ, `generate_neighbors`, cấu hình Bảng 4, thuộc tính tabu |
| `src/redistribute.jl` | chọn `ζ`, chia `N_left`/`N_right`, flow qua lát cắt, Algorithm 3 |
| `src/reroute.jl` | reroute (`full`, `max,ca`, `max,ca,δ`) |
| `src/reverse.jl` | reverse (cung găng) |
| `report/member2_neighborhoods.md` | bản nháp phần phương pháp cho báo cáo |

---

# PDP-CR — Thành viên 3: Tabu Search và thực nghiệm (Julia)

`src/PDPCRMember3.jl` dùng trực tiếp `FlowSolution` và ba neighborhood của phần 2.
`TSO` dùng reroute và reverse; `TSR` thêm redistribute. Tham số mặc định theo
Bảng 5.2, Chương 5 luận án Nguyen (2025): 5.000 vòng, tabu size `⌊n/8⌋` và
`⌊n/15⌋`, `β = 0,3` cho TSR, quay về nghiệm tốt nhất sau 300 vòng không cải
thiện và tạo nghiệm đầu mới sau 600 vòng. Với `n < 15`, phần 2 vẫn sinh ít nhất
một láng giềng mỗi loại để bộ dữ liệu nhỏ có thể chạy được.

```bash
julia --project=. test/test_member3.jl
julia --project=. experiments/run_comparison.jl --sizes=15,30,50 --robots=5,10 --seeds=1,2 --iterations=5000 --step=100 --output=results/member3
julia --project=. experiments/plot_results.jl results/member3/convergence.csv plots/member3
```

Lệnh thực nghiệm sinh cùng một instance và cùng nghiệm greedy ban đầu cho TSO
và TSR ở mỗi bộ `(n,m,seed)`. `runs.csv` ghi từng lượt; `summary.csv` ghi
makespan tốt nhất/trung bình, thời gian, số lần TSR tốt hơn và mức cải thiện
`100 × (TSO − TSR) / TSO`; `convergence.csv` ghi makespan tốt nhất theo vòng
theo phần trăm so với nghiệm đầu (100%). CSV được ghi dần trong quá trình chạy.
Các SVG tương ứng nằm trong `plots/member3/`.

Kết quả chạy hiện tại và diễn giải nằm tại `report/member3_tabu_search.md`.
Thử nghiệm này dùng instance ngẫu nhiên do phần 1 sinh ra và một biến thể greedy
để tạo nghiệm restart. Nó không dùng bộ instance Li & Lim hay S-greedy đầy đủ
trong luận án, nên số liệu không phải phép tái lập trực tiếp Bảng 5 của bài báo.
