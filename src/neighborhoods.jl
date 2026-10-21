"""
Giao diện chung cho các neighborhood (dùng bởi Tabu Search của Thành viên 3).

Mỗi phép biến đổi là một `Move`. Mỗi láng giềng là một `Candidate` lưu phép
biến đổi, danh sách thay đổi flow `[(i, j, Δf), …]` và makespan trước/sau.
Láng giềng được đánh giá *tại chỗ* (áp dụng → tính makespan → hoàn tác) nên
không phải sao chép đồ thị; chỉ khi Tabu Search chọn một láng giềng mới gọi
`materialize` để tạo nghiệm mới.
"""

"""Kiểu cha của mọi phép biến đổi neighborhood."""
abstract type Move end

"""Danh sách thay đổi flow: mỗi phần tử `(i, j, Δf)` nghĩa là `f_ij += Δf`."""
const FlowChanges = Vector{Tuple{Int,Int,Int}}

"""Một nghiệm láng giềng (chưa được tạo ra; dùng `materialize`)."""
struct Candidate
    move::Move
    changes::FlowChanges
    before::Float64
    after::Float64
end

"""Áp dụng thay đổi flow tại chỗ."""
function apply_changes!(s::FlowSolution, changes::AbstractVector{Tuple{Int,Int,Int}})
    for (i, j, d) in changes
        add_flow!(s, i, j, d)
    end
    return s
end

"""Hoàn tác thay đổi flow tại chỗ."""
function revert_changes!(s::FlowSolution, changes::AbstractVector{Tuple{Int,Int,Int}})
    for (i, j, d) in Iterators.reverse(changes)
        add_flow!(s, i, j, -d)
    end
    return s
end

"""
Thử thay đổi trên `s` (áp dụng tại chỗ, tính makespan, hoàn tác).
Trả về makespan sau biến đổi, `Inf` nếu tạo chu trình. `s` không đổi khi trả về.
"""
function try_changes(s::FlowSolution, changes::AbstractVector{Tuple{Int,Int,Int}})
    apply_changes!(s, changes)
    value = makespan(s)
    revert_changes!(s, changes)
    return value
end

"""Tạo bản sao của `s` đã áp dụng thay đổi; `nothing` nếu tạo chu trình."""
function apply_changes(s::FlowSolution, changes::AbstractVector{Tuple{Int,Int,Int}})
    t = apply_changes!(copy(s), changes)
    return is_acyclic(t) ? t : nothing
end

"""Tạo nghiệm mới (bản sao) từ một láng giềng của `s`."""
materialize(s::FlowSolution, c::Candidate) = apply_changes!(copy(s), c.changes)

"""
Áp dụng một phép biến đổi lên `s`, trả về nghiệm mới (bản sao) hoặc `nothing`
nếu không hợp lệ. Mỗi loại move định nghĩa `move_changes(s, move; ev, rng)`.
"""
function apply_move(s::FlowSolution, move::Move; ev=nothing, rng::AbstractRNG=Random.default_rng())
    changes = move_changes(s, move; ev, rng)
    isnothing(changes) && return nothing
    return apply_changes(s, changes)
end

"""Thêm láng giềng (đã kiểm tra hợp lệ nếu `validate`) vào danh sách."""
function _push_candidate!(out, s, move, changes, before, after, validate)
    isfinite(after) || return false
    if validate
        t = apply_changes!(copy(s), changes)
        validate_flow_solution(t)
        abs(makespan(t) - after) <= 1e-9 * max(1.0, after) ||
            error("makespan dự đoán khác makespan thực của láng giềng $(move)")
    end
    push!(out, Candidate(move, changes, before, after))
    return true
end

# Ba neighborhood cụ thể (cần `Move`, `Candidate` ở trên).
include("redistribute.jl")
include("reroute.jl")
include("reverse.jl")

"""Mức cải thiện makespan (`> 0` là tốt hơn)."""
improvement(c::Candidate) = c.before - c.after

"""Tên neighborhood của một phép biến đổi."""
neighborhood_name(::Move) = :unknown

"""
Tham số sinh láng giềng, tương ứng Bảng 4 của bài báo.

- `n_redis`, `n_reroute`, `n_reverse`: số láng giềng tối đa mỗi loại
  (`0` để tắt; `nothing` để không giới hạn).
- `reroute_variant`: `:max_ca_delta`, `:max_ca` hoặc `:full`.
- `reverse_critical_only`: chỉ đảo cung găng.
- `validate`: kiểm tra đầy đủ tính hợp lệ của mọi láng giềng (chậm hơn).
"""
Base.@kwdef struct NeighborhoodConfig
    n_redis::Union{Nothing,Int} = nothing
    n_reroute::Union{Nothing,Int} = nothing
    n_reverse::Union{Nothing,Int} = nothing
    reroute_variant::Symbol = :max_ca_delta
    reverse_critical_only::Bool = true
    validate::Bool = false
end

"""
Cấu hình mặc định theo Bảng 4 cho `n` task.
`:TSO` chỉ dùng reroute + reverse; `:TSR` thêm redistribute.
"""
function default_config(n::Integer, version::Symbol=:TSR)
    if version === :TSO
        return NeighborhoodConfig(n_redis=0, n_reroute=max(1, n ÷ 3), n_reverse=max(1, n ÷ 9))
    elseif version === :TSR
        return NeighborhoodConfig(
            n_redis=max(1, n ÷ 15), n_reroute=max(1, n ÷ 5), n_reverse=max(1, n ÷ 15),
        )
    end
    throw(ArgumentError("version phải là :TSO hoặc :TSR"))
end

"""
Sinh toàn bộ láng giềng của nghiệm hiện tại theo `config`.
Chỉ đánh giá lịch (topo, L, L*) một lần rồi dùng chung cho cả ba neighborhood.
"""
function generate_neighbors(
    s::FlowSolution;
    config::NeighborhoodConfig=NeighborhoodConfig(),
    rng::AbstractRNG=Random.default_rng(),
)
    ev = evaluate(s)
    isnothing(ev) && throw(ArgumentError("Flow graph có chu trình"))
    result = Candidate[]
    if config.n_redis != 0
        append!(result, redistribute_neighbors(s; ev, limit=config.n_redis, rng, validate=config.validate))
    end
    if config.n_reroute != 0
        append!(result, reroute_neighbors(
            s; ev, variant=config.reroute_variant, limit=config.n_reroute, rng, validate=config.validate,
        ))
    end
    if config.n_reverse != 0
        append!(result, reverse_neighbors(
            s; ev, critical_only=config.reverse_critical_only, limit=config.n_reverse, rng,
            validate=config.validate,
        ))
    end
    return result
end

# ---------------------------------------------------------------------------
# Thuộc tính tabu (Mục 4 bài báo)
# ---------------------------------------------------------------------------

neighborhood_name(::RedistributeMove) = :redistribute
neighborhood_name(::RerouteMove) = :reroute
neighborhood_name(::ReverseMove) = :reverse

"""Các cung bị phép biến đổi xóa/giảm flow (lưu vào `TL_add`)."""
removed_arcs(mv::RerouteMove) = [(mv.i, mv.j), (mv.u, mv.v)]
removed_arcs(mv::ReverseMove) = [(mv.i, mv.j)]
removed_arcs(::RedistributeMove) = Tuple{Int,Int}[]

"""Các cung được phép biến đổi thêm flow (dùng để kiểm tra tabu)."""
added_arcs(mv::RerouteMove) = [(mv.i, mv.v), (mv.u, mv.j)]
added_arcs(mv::ReverseMove) = [(mv.j, mv.i)]
added_arcs(::RedistributeMove) = Tuple{Int,Int}[]

"""
Kiểm tra tabu theo bài báo:

- reroute/reverse là tabu nếu nó thêm lại một cung vừa bị xóa (`TL_add`);
  với reverse `(i', j')` điều này nghĩa là `(j', i') ∈ TL_add`;
- redistribute tại `ζ` là tabu nếu `ζ ∈ TL_redis`.
"""
is_tabu(mv::Move, tl_add, tl_redis) = any(a -> a in tl_add, added_arcs(mv))
is_tabu(mv::RedistributeMove, tl_add, tl_redis) = mv.zeta in tl_redis
