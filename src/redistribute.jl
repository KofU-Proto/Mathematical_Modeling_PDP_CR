"""
Redistribute neighborhood (bài báo, Mục 3.1, Algorithm 3).

Ý tưởng: cắt thứ tự topo tại vị trí `ζ`, chia node thành `N_left` (luôn chứa
source) và `N_right` (luôn chứa sink). Mọi đường source → sink đi qua lát cắt
đúng một lần, nên

    makespan = max_{(i,j) qua lát cắt, f_ij > 0} Δ_ij,   Δ_ij = L̄_i + t_ij + L*_j.

`L̄_i` (i bên trái) và `L*_j` (j bên phải) không đổi khi chỉ sửa các cung qua
lát cắt, nên ta có thể phân phối lại flow qua lát cắt (giữ nguyên `π_i^left`,
`π_j^right`) để giảm makespan mà không phải tính lại toàn bộ lịch.
"""

"""Một lát cắt của thứ tự topo."""
struct Cut
    zeta::Int
    left::Vector{Int}
    right::Vector{Int}
end

"""Phép biến đổi redistribute tại vị trí cắt `ζ`."""
struct RedistributeMove <: Move
    zeta::Int
end

"""Nhật ký một vòng lặp của Algorithm 3 (phục vụ báo cáo/minh họa)."""
struct RedistributeStep
    cmax::Float64
    removed_arc::Tuple{Int,Int}
    gamma::Vector{Int}
    delta::Int
end

"""Kết quả redistribute trên một lát cắt."""
struct RedistributeResult
    solution::FlowSolution
    cut::Cut
    before::Float64
    after::Float64
    steps::Vector{RedistributeStep}
end

# ---------------------------------------------------------------------------
# Các hàm trên lát cắt
# ---------------------------------------------------------------------------

"""Số vị trí cắt hợp lệ: `ζ ∈ 1:n+1` (`ζ` = số node bên trái, kể cả source)."""
cut_positions(s::FlowSolution) = 1:(s.problem.n + 1)

"""Chọn ngẫu nhiên vị trí cắt `ζ` (bài báo chọn ngẫu nhiên)."""
choose_cut(s::FlowSolution, rng::AbstractRNG=Random.default_rng()) = rand(rng, cut_positions(s))

"""
Chia đồ thị theo thứ tự topo `order` tại `ζ`: `ζ` node đầu thuộc `N_left`,
phần còn lại thuộc `N_right`.
"""
function split_at(order::AbstractVector{<:Integer}, zeta::Integer)
    1 <= zeta < length(order) || throw(ArgumentError("ζ phải nằm trong 1:$(length(order) - 1)"))
    return Cut(Int(zeta), order[1:zeta], order[(zeta + 1):end])
end

split_at(ev::FlowEvaluation, zeta::Integer) = split_at(ev.order, zeta)

"""
Flow đi qua lát cắt. Trả về `(cross, π_left, π_right)` với
`cross[(i, j)] = f_ij` cho `i ∈ N_left, j ∈ N_right`,
`π_left[i] = Σ_j f_ij`, `π_right[j] = Σ_i f_ij`.
"""
function cut_flows(s::FlowSolution, cut::Cut)
    in_right = Set(cut.right)
    cross = Dict{Tuple{Int,Int},Int}()
    pi_left = Dict{Int,Int}()
    pi_right = Dict{Int,Int}()
    for i in cut.left, (j, f) in s.out[i + 1]
        j in in_right || continue
        cross[(i, j)] = f
        pi_left[i] = get(pi_left, i, 0) + f
        pi_right[j] = get(pi_right, j, 0) + f
    end
    return cross, pi_left, pi_right
end

# ---------------------------------------------------------------------------
# Algorithm 3 trên dữ liệu lát cắt (hàm thuần, dễ kiểm thử bằng ví dụ bài báo)
# ---------------------------------------------------------------------------

"""
Tìm dãy `Γ = (i*, j1, i2, j2, …, iK, j*)` (Algorithm 3, dòng 8) bằng BFS xen kẽ:

- bước trái → phải `(i_k, j_k)`: cung được tăng flow, phải *không* bị cấm;
- bước phải → trái `(i_{k+1}, j_k)`: cung được giảm flow, phải có `f > 0`.

Cung `(i*, j*)` bị cấm nên `K ≥ 2`. Trả về `nothing` nếu không tìm thấy.
"""
function find_gamma(cross, forbidden, left, right, istar, jstar)
    parent_right = Dict{Int,Int}()   # j ↦ i đứng trước nó trong Γ
    parent_left = Dict{Int,Int}()    # i ↦ j đứng trước nó trong Γ
    visited_left = Set{Int}([istar])
    queue = [istar]
    head = 1
    while head <= length(queue)
        i = queue[head]
        head += 1
        for j in right
            haskey(parent_right, j) && continue
            (i, j) in forbidden && continue
            if j == jstar
                # Dựng lại Γ từ j* về i*.
                gamma = [jstar, i]
                node = i
                while node != istar
                    jprev = parent_left[node]
                    push!(gamma, jprev)
                    node = parent_right[jprev]
                    push!(gamma, node)
                end
                return reverse!(gamma)
            end
            parent_right[j] = i
            for inext in left
                inext in visited_left && continue
                get(cross, (inext, j), 0) > 0 || continue
                push!(visited_left, inext)
                parent_left[inext] = j
                push!(queue, inext)
            end
        end
    end
    return nothing
end

"""
Algorithm 3 – phân phối lại flow qua lát cắt.

- `cross`: flow hiện tại qua lát cắt (`Dict((i, j) => f_ij)`), bị sửa tại chỗ.
- `delta(i, j)`: hàm trả về `Δ_ij = L̄_i + t_ij + L*_j`.
- `cmax`: makespan hiện tại.

Trả về `(cmax_mới, steps)`. Mỗi vòng: cập nhật `Cmax`, lấy tập cung cấm
`A_f = {Δ_ij ≥ Cmax}`, chọn ngẫu nhiên cung găng `(i*, j*)` có flow, tìm `Γ`
rồi dời `δ` đơn vị flow dọc `Γ`. Dừng khi không tìm được `Γ`.
"""
function redistribute_cut!(
    cross::Dict{Tuple{Int,Int},Int},
    left::AbstractVector{<:Integer},
    right::AbstractVector{<:Integer},
    delta::Function,
    cmax::Real;
    rng::AbstractRNG=Random.default_rng(),
    tol::Real=1e-9,
    max_iterations::Integer=10_000,
)
    # Chỉ node có flow qua lát cắt mới tham gia được vào Γ.
    active_left = sort!(unique([i for ((i, _), f) in cross if f > 0]))
    active_right = sort!(unique([j for ((_, j), f) in cross if f > 0]))
    D = Dict((i, j) => Float64(delta(i, j)) for i in active_left for j in active_right)
    steps = RedistributeStep[]
    current = Float64(cmax)

    for _ in 1:max_iterations
        positive = [(a, f) for (a, f) in cross if f > 0]
        isempty(positive) && break
        current = min(current, maximum(D[a] for (a, _) in positive))       # dòng 4
        threshold = current - tol * max(1.0, abs(current))
        forbidden = Set(a for (a, d) in D if d >= threshold)               # dòng 5
        amax = sort!([a for (a, _) in positive if a in forbidden])         # dòng 6
        isempty(amax) && break
        istar, jstar = amax[rand(rng, 1:length(amax))]                     # dòng 7
        gamma = find_gamma(cross, forbidden, active_left, active_right, istar, jstar)
        isnothing(gamma) && break                                          # dòng 9–10
        # Γ = (i1=i*, j1, i2, j2, …, iK, jK=j*):
        #   tăng (i_k, j_k), giảm (i_{k+1}, j_k) và (i*, j*).
        lefts = gamma[1:2:end]
        rights = gamma[2:2:end]
        K = length(lefts)
        decreased = [(lefts[k + 1], rights[k]) for k in 1:(K - 1)]
        push!(decreased, (istar, jstar))
        increased = [(lefts[k], rights[k]) for k in 1:K]
        amount = minimum(cross[a] for a in decreased)                     # dòng 12
        for a in decreased
            cross[a] -= amount
            cross[a] == 0 && delete!(cross, a)
        end
        for a in increased
            cross[a] = get(cross, a, 0) + amount
        end
        push!(steps, RedistributeStep(current, (istar, jstar), gamma, amount))
    end
    positive = [a for (a, f) in cross if f > 0]
    final = isempty(positive) ? current : min(current, maximum(D[a] for a in positive))
    return final, steps
end

# ---------------------------------------------------------------------------
# Áp dụng trên flow-DAG
# ---------------------------------------------------------------------------

"""
Chạy Algorithm 3 tại lát cắt `ζ` mà không sửa `s`. Trả về
`(changes, cut, before, after, steps)`; `changes` là thay đổi flow trên các cung
qua lát cắt. Vì mọi đường source → sink cắt qua lát cắt đúng một lần nên
`after` chính là makespan mới (không cần đánh giá lại).
"""
function redistribute_changes(
    s::FlowSolution,
    zeta::Integer;
    ev::Union{Nothing,FlowEvaluation}=nothing,
    rng::AbstractRNG=Random.default_rng(),
)
    ev = isnothing(ev) ? evaluate(s) : ev
    isnothing(ev) && throw(ArgumentError("Flow graph có chu trình"))
    cut = split_at(ev, zeta)
    cross, _, _ = cut_flows(s, cut)
    original = copy(cross)
    delta(i, j) = arc_length(s, ev, i, j)
    after, steps = redistribute_cut!(cross, cut.left, cut.right, delta, ev.makespan; rng)
    changes = FlowChanges()
    for a in union(keys(original), keys(cross))
        d = get(cross, a, 0) - get(original, a, 0)
        d != 0 && push!(changes, (a[1], a[2], d))
    end
    sort!(changes; by=x -> x[3])   # giảm trước, tăng sau: flow không bao giờ âm
    return changes, cut, ev.makespan, after, steps
end

"""
Áp dụng redistribute tại lát cắt `ζ`. Trả về `RedistributeResult`; nghiệm mới
là bản sao (nghiệm cũ không bị sửa). Makespan mới không bao giờ lớn hơn cũ.
"""
function redistribute(
    s::FlowSolution,
    zeta::Integer;
    ev::Union{Nothing,FlowEvaluation}=nothing,
    rng::AbstractRNG=Random.default_rng(),
    validate::Bool=false,
)
    changes, cut, before, after, steps = redistribute_changes(s, zeta; ev, rng)
    result = apply_changes!(copy(s), changes)
    validate && validate_flow_solution(result)
    return RedistributeResult(result, cut, before, after, steps)
end

move_changes(s::FlowSolution, move::RedistributeMove; ev=nothing, rng=Random.default_rng()) =
    first(redistribute_changes(s, move.zeta; ev, rng))

"""
Sinh các nghiệm láng giềng redistribute. `zetas` mặc định là `limit` vị trí cắt
ngẫu nhiên khác nhau (hoặc mọi vị trí nếu `limit === nothing`).
"""
function redistribute_neighbors(
    s::FlowSolution;
    ev::Union{Nothing,FlowEvaluation}=nothing,
    limit::Union{Nothing,Integer}=nothing,
    zetas=nothing,
    rng::AbstractRNG=Random.default_rng(),
    validate::Bool=false,
)
    ev = isnothing(ev) ? evaluate(s) : ev
    positions = isnothing(zetas) ? collect(cut_positions(s)) : collect(zetas)
    if !isnothing(limit) && isnothing(zetas)
        shuffle!(rng, positions)
        positions = positions[1:min(limit, length(positions))]
    end
    candidates = Candidate[]
    for z in positions
        changes, _, before, after, _ = redistribute_changes(s, z; ev, rng)
        _push_candidate!(candidates, s, RedistributeMove(z), changes, before, after, validate)
    end
    return candidates
end
