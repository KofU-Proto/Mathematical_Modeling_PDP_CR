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

Chạy mô phỏng mẫu và xuất hình SVG:

```powershell
julia --project=. examples\visualize_sample.jl
```

Hình được lưu tại `plots/sample_simulation.svg` và có thể mở bằng trình duyệt.

Đọc instance CSV có các cột `task_id,pickup_x,pickup_y,delivery_x,delivery_y,
processing_time,required_robots`. Có thể bỏ cột `processing_time` hoặc để
trống giá trị; khi đó module tự tính khoảng cách Euclidean pickup-delivery.
File mẫu nằm tại `data/sample.csv`.

```julia
instance = load_instance("data/sample.csv", 2)
save_instance(instance, "data/generated.csv")
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
