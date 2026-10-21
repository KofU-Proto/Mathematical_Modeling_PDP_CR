"""
Reverse neighborhood (bài báo Mục 3.2, theo [10]).

Đảo chiều cung `(i, j)` giữa hai task: `q = f_ij` robot giờ làm `j` trước rồi
mới tới `i` (`f_ji = q`). Để giữ bảo toàn flow:

- `i` nhận thêm `q` flow từ `j` ⇒ bớt `q` flow vào `i` từ tập tiền nhiệm `U`,
  chuyển chúng sang đi vào `j` (`f_ui -= a_u`, `f_uj += a_u`).
- `j` gửi thêm `q` flow sang `i` ⇒ bớt `q` flow ra từ `j` tới tập hậu nhiệm `V`,
  chuyển chúng sang đi ra từ `i` (`f_jv -= b_v`, `f_iv += b_v`).

`U` được chọn theo thời điểm robot tới `i` tăng dần (`L̄_u + t_ui`), `V` theo
`t_jv` tăng dần; cả hai là tập tối thiểu có tổng flow `≥ q`, phần tử cuối chỉ
góp phần còn thiếu (`q_a`, `q_b` trong bài báo).
"""

"""Phép reverse trên cung `(i, j)` (cả hai đều là task)."""
struct ReverseMove <: Move
    i::Int
    j::Int
end

"""Chọn tập tối thiểu theo thứ tự ưu tiên, trả về các cặp `(node, lượng)`."""
function _take_prefix(candidates::Vector{Tuple{Int,Int}}, q::Int)
    taken = Tuple{Int,Int}[]
    remaining = q
    for (node, f) in candidates
        remaining == 0 && break
        a = min(f, remaining)
        push!(taken, (node, a))
        remaining -= a
    end
    remaining == 0 || return nothing
    return taken
end

"""
Danh sách thay đổi flow của reverse, hoặc `nothing` nếu cung không nằm giữa hai
task hoặc không có flow. Việc kiểm tra chu trình được làm khi áp dụng.
"""
function move_changes(s::FlowSolution, mv::ReverseMove; ev=nothing, rng=nothing)
    p = s.problem
    (; i, j) = mv
    (1 <= i <= p.n && 1 <= j <= p.n) || return nothing
    q = flow(s, i, j)
    q >= 1 || return nothing
    ev = isnothing(ev) ? evaluate(s) : ev

    # U: tiền nhiệm của i (trừ j), ưu tiên robot tới i sớm hơn.
    preds = [(u, f) for (u, f) in s.in_[i + 1] if u != j]
    sort!(preds; by=uf -> (ev.Lbar[uf[1] + 1] + tt(p, uf[1], i), uf[1]))
    U = _take_prefix(preds, q)
    # V: hậu nhiệm của j (trừ i), ưu tiên quãng đi ngắn hơn.
    succs = [(v, f) for (v, f) in s.out[j + 1] if v != i]
    sort!(succs; by=vf -> (tt(p, j, vf[1]), vf[1]))
    V = _take_prefix(succs, q)
    (isnothing(U) || isnothing(V)) && return nothing

    changes = FlowChanges([(i, j, -q), (j, i, q)])
    for (u, a) in U
        push!(changes, (u, i, -a), (u, j, a))
    end
    for (v, b) in V
        push!(changes, (j, v, -b), (i, v, b))
    end
    return changes
end

"""
Sinh láng giềng reverse. `critical_only=true` (mặc định) cho `N_reverse^{ca}`:
chỉ đảo các cung găng giữa hai task. `limit` giới hạn số láng giềng hợp lệ.
"""
function reverse_neighbors(
    s::FlowSolution;
    ev::Union{Nothing,FlowEvaluation}=nothing,
    critical_only::Bool=true,
    limit::Union{Nothing,Integer}=nothing,
    rng::AbstractRNG=Random.default_rng(),
    validate::Bool=false,
)
    ev = isnothing(ev) ? evaluate(s) : ev
    p = s.problem
    pool = critical_only ? critical_arcs(s, ev; tasks_only=true) :
        [(i, j) for (i, j, _) in arcs(s) if 1 <= i <= p.n && 1 <= j <= p.n]
    shuffle!(rng, pool)
    candidates = Candidate[]
    for (i, j) in pool
        mv = ReverseMove(i, j)
        changes = move_changes(s, mv; ev)
        isnothing(changes) && continue
        _push_candidate!(candidates, s, mv, changes, ev.makespan, try_changes(s, changes), validate)
        !isnothing(limit) && length(candidates) >= limit && break
    end
    return candidates
end
