"""
Biểu diễn nghiệm PDP-CR dưới dạng flow-DAG (Thành viên 2).

Quy ước node: `0` là depot xuất phát (source), `1:n` là task, `n+1` là depot
đích (sink). Một đơn vị flow trên cung `(i, j)` là một robot đi làm task `j`
ngay sau task `i`. Các mảng theo node dùng chỉ số `node + 1` (Julia 1-based).
"""

# ---------------------------------------------------------------------------
# Dữ liệu tĩnh của bài toán
# ---------------------------------------------------------------------------

"""
Dữ liệu tĩnh mà các neighborhood cần.

- `n`, `m`: số task và số robot.
- `c[i+1]`: thời gian xử lý `c_i` (`c_0 = c_{n+1} = 0`).
- `r[i+1]`: số robot yêu cầu `r_i` (`r_0 = r_{n+1} = m`).
- `T[i+1, j+1]`: thời gian đi `t_ij` từ điểm giao của `i` đến điểm nhận của `j`.
- `labels[i+1]`: nhãn hiển thị của node.
"""
struct FlowProblem
    n::Int
    m::Int
    c::Vector{Float64}
    r::Vector{Int}
    T::Matrix{Float64}
    labels::Vector{String}
end

"""
Dựng `FlowProblem` từ dữ liệu thô.

`processing`, `required`: độ dài `n` (chỉ các task). `travel`: ma trận
`(n+2)×(n+2)` theo thứ tự node `0, 1, …, n+1`.
"""
function FlowProblem(
    processing::AbstractVector{<:Real},
    required::AbstractVector{<:Integer},
    travel::AbstractMatrix{<:Real},
    robot_count::Integer;
    labels::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
)
    n = length(processing)
    length(required) == n || throw(ArgumentError("required phải có độ dài n"))
    size(travel) == (n + 2, n + 2) ||
        throw(ArgumentError("travel phải có kích thước (n+2)×(n+2)"))
    robot_count >= 1 || throw(ArgumentError("robot_count phải dương"))
    all(1 .<= required .<= robot_count) ||
        throw(ArgumentError("Mỗi r_i phải nằm trong 1:m"))
    node_labels = isnothing(labels) ?
        ["S"; [string(i) for i in 1:n]; "S'"] : String.(collect(labels))
    length(node_labels) == n + 2 || throw(ArgumentError("labels phải có n+2 phần tử"))
    return FlowProblem(
        n,
        Int(robot_count),
        [0.0; Float64.(processing); 0.0],
        [Int(robot_count); Int.(required); Int(robot_count)],
        Float64.(travel),
        node_labels,
    )
end

"""Dựng `FlowProblem` từ `ProblemInstance` của Thành viên 1."""
function FlowProblem(instance::ProblemInstance)
    tasks = instance.tasks
    n = length(tasks)
    T = zeros(Float64, n + 2, n + 2)
    for j in 1:n
        T[1, j + 1] = distance(instance.depot, tasks[j].pickup)          # t_{0j}
        T[j + 1, n + 2] = distance(tasks[j].delivery, instance.depot)    # t_{j,n+1}
        for i in 1:n
            i == j && continue
            T[i + 1, j + 1] = travel_time(tasks[i], tasks[j])            # t_{ij}
        end
    end
    return FlowProblem(
        [task.processing_time for task in tasks],
        [task.required_robots for task in tasks],
        T,
        instance.robot_count;
        labels=["S"; [task.id for task in tasks]; "S'"],
    )
end

source(p::FlowProblem) = 0
sink(p::FlowProblem) = p.n + 1
nodes(p::FlowProblem) = 0:(p.n + 1)
tasks(p::FlowProblem) = 1:p.n
proc(p::FlowProblem, i::Integer) = p.c[i + 1]
req(p::FlowProblem, i::Integer) = p.r[i + 1]
tt(p::FlowProblem, i::Integer, j::Integer) = p.T[i + 1, j + 1]
label(p::FlowProblem, i::Integer) = p.labels[i + 1]

# ---------------------------------------------------------------------------
# Nghiệm dạng flow-DAG
# ---------------------------------------------------------------------------

"""
Nghiệm PDP-CR dạng flow-DAG. Lưu cả danh sách kề ra và vào để duyệt nhanh:
`out[i+1][j] == in_[j+1][i] == f_ij > 0`. Cung có flow 0 không được lưu.
"""
mutable struct FlowSolution
    problem::FlowProblem
    out::Vector{Dict{Int,Int}}
    in_::Vector{Dict{Int,Int}}
end

FlowSolution(p::FlowProblem) =
    FlowSolution(p, [Dict{Int,Int}() for _ in 1:(p.n + 2)], [Dict{Int,Int}() for _ in 1:(p.n + 2)])

Base.copy(s::FlowSolution) = FlowSolution(s.problem, [copy(d) for d in s.out], [copy(d) for d in s.in_])

"""Số flow `f_ij` trên cung `(i, j)`."""
flow(s::FlowSolution, i::Integer, j::Integer) = get(s.out[i + 1], j, 0)

"""Đặt `f_ij = value`; xóa cung khi `value == 0`."""
function set_flow!(s::FlowSolution, i::Integer, j::Integer, value::Integer)
    value >= 0 || throw(ArgumentError("Flow âm trên cung ($i, $j)"))
    if value == 0
        delete!(s.out[i + 1], j)
        delete!(s.in_[j + 1], i)
    else
        s.out[i + 1][j] = value
        s.in_[j + 1][i] = value
    end
    return s
end

"""Cộng `delta` (có thể âm) vào `f_ij`."""
add_flow!(s::FlowSolution, i::Integer, j::Integer, delta::Integer) =
    set_flow!(s, i, j, flow(s, i, j) + delta)

successors(s::FlowSolution, i::Integer) = keys(s.out[i + 1])
predecessors(s::FlowSolution, j::Integer) = keys(s.in_[j + 1])
outflow(s::FlowSolution, i::Integer) = sum(values(s.out[i + 1]); init=0)
inflow(s::FlowSolution, j::Integer) = sum(values(s.in_[j + 1]); init=0)

"""Danh sách cung `(i, j, f_ij)` có flow dương, sắp theo `(i, j)`."""
function arcs(s::FlowSolution)
    result = Tuple{Int,Int,Int}[]
    for i in nodes(s.problem), (j, f) in s.out[i + 1]
        push!(result, (i, j, f))
    end
    sort!(result)
    return result
end

"""
Dựng flow-DAG từ tuyến của các robot. `routes[k]` là dãy task robot `k` làm
(không ghi depot); tuyến rỗng nghĩa là robot đi thẳng `0 → n+1`.
"""
function from_routes(p::FlowProblem, routes::AbstractVector)
    length(routes) == p.m || throw(ArgumentError("Cần đúng m = $(p.m) tuyến"))
    s = FlowSolution(p)
    for route in routes
        path = [0; Int.(route); sink(p)]
        for (a, b) in zip(path, path[2:end])
            add_flow!(s, a, b, 1)
        end
    end
    validate_flow_solution(s)
    return s
end

"""Dựng flow-DAG từ `Solution` (order + teams) của Thành viên 1."""
function from_solution(p::FlowProblem, instance::ProblemInstance, solution::Solution)
    graph = build_flow_graph(instance, solution)
    s = FlowSolution(p)
    for (i, j, f) in graph.flows
        add_flow!(s, i, j, f)
    end
    validate_flow_solution(s)
    return s
end

"""
Phân rã flow thành `m` tuyến robot (flow decomposition trên DAG): mỗi robot
xuất phát từ `0` và đi theo một cung còn flow cho tới `n+1`.
"""
function to_routes(s::FlowSolution)
    p = s.problem
    residual = [copy(d) for d in s.out]
    routes = Vector{Vector{Int}}()
    for _ in 1:p.m
        route = Int[]
        node = 0
        while node != sink(p)
            nxt = minimum(keys(residual[node + 1]))  # chọn tất định
            residual[node + 1][nxt] -= 1
            residual[node + 1][nxt] == 0 && delete!(residual[node + 1], nxt)
            node = nxt
            node != sink(p) && push!(route, node)
        end
        push!(routes, route)
    end
    return routes
end

"""Chuyển flow-DAG về `Solution` của Thành viên 1 (order theo thứ tự topo)."""
function to_solution(s::FlowSolution)
    p = s.problem
    order = topological_order(s)
    isnothing(order) && throw(ArgumentError("Flow graph có chu trình"))
    teams = [Int[] for _ in 1:p.n]
    for (robot, route) in enumerate(to_routes(s)), task in route
        push!(teams[task], robot)
    end
    return Solution([v for v in order if 1 <= v <= p.n], teams)
end

# ---------------------------------------------------------------------------
# Thứ tự topo, L, L* và makespan
# ---------------------------------------------------------------------------

"""
Thứ tự topo theo thuật toán Kahn trên toàn bộ node `0:n+1`.
Trả về `nothing` nếu đồ thị có chu trình.
"""
function topological_order(s::FlowSolution)
    p = s.problem
    indeg = [length(s.in_[v + 1]) for v in nodes(p)]
    queue = [v for v in nodes(p) if indeg[v + 1] == 0]
    order = Int[]
    head = 1
    while head <= length(queue)
        v = queue[head]
        head += 1
        push!(order, v)
        for w in sort!(collect(successors(s, v)))
            indeg[w + 1] -= 1
            indeg[w + 1] == 0 && push!(queue, w)
        end
    end
    return length(order) == p.n + 2 ? order : nothing
end

"""
`true` nếu flow graph không có chu trình. Bản Kahn rút gọn (không sắp xếp,
không lưu thứ tự) vì được gọi cho mọi phép biến đổi thử.
"""
function is_acyclic(s::FlowSolution)
    total = s.problem.n + 2
    indeg = Vector{Int}(undef, total)
    stack = Int[]
    sizehint!(stack, total)
    for k in 1:total
        indeg[k] = length(s.in_[k])
        indeg[k] == 0 && push!(stack, k - 1)
    end
    seen = 0
    while !isempty(stack)
        v = pop!(stack)
        seen += 1
        for w in keys(s.out[v + 1])
            indeg[w + 1] -= 1
            indeg[w + 1] == 0 && push!(stack, w)
        end
    end
    return seen == total
end

"""
Algorithm 1 (bài báo): `L[j+1]` là thời điểm sớm nhất task `j` bắt đầu,
`L_j = max_{i→j} (L_i + c_i + t_ij)`, `L_0 = 0`. `L_{n+1}` là makespan.
"""
function earliest_start(s::FlowSolution, order::AbstractVector{<:Integer})
    p = s.problem
    L = fill(-Inf, p.n + 2)
    L[1] = 0.0
    for i in order, j in successors(s, i)
        cand = L[i + 1] + proc(p, i) + tt(p, i, j)
        cand > L[j + 1] && (L[j + 1] = cand)
    end
    return L
end

"""
Algorithm 2 (bài báo): `Lstar[i+1]` là độ dài đường dài nhất từ pickup của
`i` tới sink, `L*_i = c_i + max_{i→j} (t_ij + L*_j)`, `L*_{n+1} = 0`.
"""
function longest_to_sink(s::FlowSolution, order::AbstractVector{<:Integer})
    p = s.problem
    Lstar = fill(-Inf, p.n + 2)
    Lstar[end] = 0.0
    for j in Iterators.reverse(order), i in predecessors(s, j)
        cand = Lstar[j + 1] + proc(p, i) + tt(p, i, j)
        cand > Lstar[i + 1] && (Lstar[i + 1] = cand)
    end
    return Lstar
end

"""
Kết quả đánh giá một flow-DAG.

- `order`: thứ tự topo dùng để cắt (sắp theo `L`, hòa thì theo Kahn).
- `L`, `Lbar = L + c`, `Lstar`: như Algorithm 1–2.
- `makespan`: `L_{n+1}`.
"""
struct FlowEvaluation
    order::Vector{Int}
    L::Vector{Float64}
    Lbar::Vector{Float64}
    Lstar::Vector{Float64}
    makespan::Float64
end

"""
Đánh giá flow-DAG: thứ tự topo, `L`, `L̄`, `L*`, makespan.
Trả về `nothing` nếu có chu trình.

Thứ tự cắt được sắp theo thời điểm bắt đầu sớm nhất `L`; đây vẫn là thứ tự topo
vì với mọi cung `i → j` ta có `L_j ≥ L_i + c_i + t_ij ≥ L_i` (hòa thì giữ thứ tự
Kahn).
"""
function evaluate(s::FlowSolution)
    kahn = topological_order(s)
    isnothing(kahn) && return nothing
    p = s.problem
    L = earliest_start(s, kahn)
    Lstar = longest_to_sink(s, kahn)
    position = zeros(Int, p.n + 2)
    for (k, v) in enumerate(kahn)
        position[v + 1] = k
    end
    order = sort(kahn; by=v -> (L[v + 1], position[v + 1]))
    order[1] == 0 || (order = [0; filter(!=(0), order)])
    order[end] == sink(p) || (order = [filter(!=(sink(p)), order); sink(p)])
    Lbar = L .+ p.c
    return FlowEvaluation(order, L, Lbar, Lstar, L[end])
end

"""
Makespan của flow-DAG (`Inf` nếu có chu trình). Gộp Kahn và Algorithm 1 trong
một lượt: khi node được lấy ra khỏi ngăn xếp, mọi tiền nhiệm đã xử lý xong nên
`L` của nó đã là giá trị cuối cùng.
"""
function makespan(s::FlowSolution)
    p = s.problem
    total = p.n + 2
    indeg = Vector{Int}(undef, total)
    L = fill(-Inf, total)
    L[1] = 0.0
    stack = Int[]
    sizehint!(stack, total)
    for k in 1:total
        indeg[k] = length(s.in_[k])
        indeg[k] == 0 && push!(stack, k - 1)
    end
    seen = 0
    while !isempty(stack)
        v = pop!(stack)
        seen += 1
        base = L[v + 1] + p.c[v + 1]
        for (w, _) in s.out[v + 1]
            cand = base + p.T[v + 1, w + 1]
            cand > L[w + 1] && (L[w + 1] = cand)
            indeg[w + 1] -= 1
            indeg[w + 1] == 0 && push!(stack, w)
        end
    end
    return seen == total ? L[end] : Inf
end

"""Độ dài đường dài nhất đi qua cung `(i, j)`: `Δ_ij = L̄_i + t_ij + L*_j`."""
arc_length(s::FlowSolution, ev::FlowEvaluation, i::Integer, j::Integer) =
    ev.Lbar[i + 1] + tt(s.problem, i, j) + ev.Lstar[j + 1]

"""
Cung găng: cung có flow dương nằm trên một đường dài nhất (`Δ_ij = makespan`).
Mặc định bỏ cung nối với depot khi `tasks_only=true` (dùng cho reverse).
"""
function critical_arcs(s::FlowSolution, ev::FlowEvaluation; tol::Real=1e-9, tasks_only::Bool=false)
    p = s.problem
    result = Tuple{Int,Int}[]
    for (i, j, _) in arcs(s)
        tasks_only && !(1 <= i <= p.n && 1 <= j <= p.n) && continue
        abs(arc_length(s, ev, i, j) - ev.makespan) <= tol * max(1.0, ev.makespan) &&
            push!(result, (i, j))
    end
    return result
end

# ---------------------------------------------------------------------------
# Kiểm tra tính hợp lệ
# ---------------------------------------------------------------------------

"""
Kiểm tra flow-DAG hợp lệ, ném `ArgumentError` nếu vi phạm:

1. Không có cung tự lặp, cung vào source, cung ra từ sink; flow nguyên dương.
2. Danh sách kề `out`/`in_` khớp nhau.
3. Source phát đúng `m` flow, sink nhận đúng `m` flow (ràng buộc (2)–(3)).
4. Mỗi task có flow vào = flow ra = `r_i` (ràng buộc (4)–(5)).
5. Đồ thị không có chu trình.
"""
function validate_flow_solution(s::FlowSolution)
    p = s.problem
    for i in nodes(p), (j, f) in s.out[i + 1]
        i == j && throw(ArgumentError("Cung tự lặp tại node $i"))
        j == 0 && throw(ArgumentError("Có cung đi vào source"))
        i == sink(p) && throw(ArgumentError("Có cung đi ra từ sink"))
        0 <= j <= sink(p) || throw(ArgumentError("Node không tồn tại: $j"))
        f > 0 || throw(ArgumentError("Flow trên cung ($i, $j) phải dương"))
        get(s.in_[j + 1], i, 0) == f ||
            throw(ArgumentError("Danh sách kề vào/ra không khớp tại ($i, $j)"))
    end
    sum(length, s.out) == sum(length, s.in_) ||
        throw(ArgumentError("Danh sách kề vào/ra không khớp"))
    outflow(s, 0) == p.m || throw(ArgumentError("Flow ra từ source ≠ m"))
    inflow(s, sink(p)) == p.m || throw(ArgumentError("Flow vào sink ≠ m"))
    for i in tasks(p)
        inflow(s, i) == req(p, i) ||
            throw(ArgumentError("Flow vào task $(label(p, i)) ≠ r_i = $(req(p, i))"))
        outflow(s, i) == req(p, i) ||
            throw(ArgumentError("Flow ra task $(label(p, i)) ≠ r_i = $(req(p, i))"))
    end
    is_acyclic(s) || throw(ArgumentError("Flow graph có chu trình"))
    return true
end

"""`true` nếu flow-DAG hợp lệ."""
function is_valid(s::FlowSolution)
    try
        return validate_flow_solution(s)
    catch err
        err isa ArgumentError || rethrow()
        return false
    end
end

function Base.show(io::IO, s::FlowSolution)
    p = s.problem
    parts = ["$(label(p, i))→$(label(p, j)):$f" for (i, j, f) in arcs(s)]
    print(io, "FlowSolution(n=$(p.n), m=$(p.m); ", join(parts, ", "), ")")
end
