"""
Reroute neighborhood (bài báo Mục 3.2, theo [10]).

Chọn hai cung `(i, j)` và `(u, v)` có flow dương, dời `q` đơn vị flow:

    f_ij -= q,  f_uv -= q,  f_iv += q,  f_uj += q.

Bảo toàn flow tại mọi node được giữ nguyên; chỉ cần kiểm tra đồ thị mới không có
chu trình (cung mới `(i, v)`, `(u, j)` có thể tạo chu trình).
"""

"""Phép reroute: dời `q` flow từ `(i, j), (u, v)` sang `(i, v), (u, j)`."""
struct RerouteMove <: Move
    i::Int
    j::Int
    u::Int
    v::Int
    q::Int
end

"""
Danh sách thay đổi flow của reroute, hoặc `nothing` nếu phép biến đổi không hợp
lệ cục bộ (thiếu flow, tạo cung tự lặp, không làm thay đổi gì). Việc kiểm tra
chu trình được làm khi áp dụng (`apply_move`, `try_changes`).
"""
function move_changes(s::FlowSolution, mv::RerouteMove; ev=nothing, rng=nothing)
    (; i, j, u, v, q) = mv
    q >= 1 || return nothing
    (i == u || j == v) && return nothing          # không thay đổi gì
    (i == v || u == j) && return nothing          # cung tự lặp
    flow(s, i, j) >= q && flow(s, u, v) >= q || return nothing
    return FlowChanges([(i, j, -q), (u, v, -q), (i, v, q), (u, j, q)])
end

"""
Sinh láng giềng reroute.

- `variant = :max_ca_delta` (mặc định, `N_reroute^{max,ca,δ}`): chỉ dùng cung găng
  có `t_ij` lớn nhất, ghép với mọi cung `(u, v)`, `q = min(f_ij, f_uv)`.
- `variant = :max_ca` (`N_reroute^{max,ca}`): mọi cung găng × mọi cung, `q` tối đa.
- `variant = :full` (`N_reroute`): mọi cặp cung, mọi `q ∈ 1:min(f_ij, f_uv)`.

`limit` giới hạn số láng giềng hợp lệ trả về (lấy mẫu ngẫu nhiên).
"""
function reroute_neighbors(
    s::FlowSolution;
    ev::Union{Nothing,FlowEvaluation}=nothing,
    variant::Symbol=:max_ca_delta,
    limit::Union{Nothing,Integer}=nothing,
    rng::AbstractRNG=Random.default_rng(),
    validate::Bool=false,
)
    ev = isnothing(ev) ? evaluate(s) : ev
    all_arcs = [(i, j) for (i, j, _) in arcs(s)]
    if variant === :full
        first_arcs = all_arcs
    else
        crit = critical_arcs(s, ev)
        if variant === :max_ca_delta && !isempty(crit)
            best = maximum(tt(s.problem, i, j) for (i, j) in crit)
            crit = [a for a in crit if tt(s.problem, a...) == best]
            crit = [crit[rand(rng, 1:length(crit))]]
        elseif variant ∉ (:max_ca, :max_ca_delta)
            throw(ArgumentError("variant không hợp lệ: $variant"))
        end
        first_arcs = crit
    end

    moves = RerouteMove[]
    for (i, j) in first_arcs, (u, v) in all_arcs
        (i, j) == (u, v) && continue
        qmax = min(flow(s, i, j), flow(s, u, v))
        qs = variant === :full ? (1:qmax) : (qmax:qmax)
        for q in qs
            push!(moves, RerouteMove(i, j, u, v, q))
        end
    end
    shuffle!(rng, moves)

    candidates = Candidate[]
    for mv in moves
        changes = move_changes(s, mv)
        isnothing(changes) && continue
        _push_candidate!(candidates, s, mv, changes, ev.makespan, try_changes(s, changes), validate)
        !isnothing(limit) && length(candidates) >= limit && break
    end
    return candidates
end
