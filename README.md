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