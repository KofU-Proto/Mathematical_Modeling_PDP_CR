"""Tabu Search theo Algorithm 9 và Bảng 5.2, Chương 5 luận án Nguyen (2025)."""

Base.@kwdef struct TabuConfig
    version::Symbol = :TSR
    max_iterations::Int = 5000
    restart_elite::Int = 300
    restart_initial::Int = 600
    beta::Float64 = 0.3
    tabu_add_size::Int = 0
    tabu_redis_size::Int = 0
    neighborhood::NeighborhoodConfig = NeighborhoodConfig()
end

"""Tham số Bảng 5.2; các phép chia đều lấy floor, kể cả tabu size bằng 0."""
function default_tabu_config(n::Integer, version::Symbol=:TSR; kwargs...)
    n >= 0 || throw(ArgumentError("n phải không âm"))
    version in (:TSO, :TSR) || throw(ArgumentError("version phải là :TSO hoặc :TSR"))
    defaults = (;
        version,
        beta=version === :TSR ? 0.3 : 0.0,
        tabu_add_size=n ÷ 8,
        tabu_redis_size=version === :TSR ? n ÷ 15 : 0,
        neighborhood=default_config(n, version),
    )
    return TabuConfig(; merge(defaults, (; kwargs...))...)
end

struct TabuResult
    best::FlowSolution
    initial_makespan::Float64
    best_makespan::Float64
    history::Vector{Float64}
    iterations::Int
    elite_restarts::Int
    initial_restarts::Int
    selected_moves::Dict{Symbol,Int}
end

function _validate_config(config::TabuConfig)
    config.version in (:TSO, :TSR) || throw(ArgumentError("version không hợp lệ"))
    config.max_iterations >= 0 || throw(ArgumentError("max_iterations phải không âm"))
    0 < config.restart_elite < config.restart_initial ||
        throw(ArgumentError("cần 0 < restart_elite < restart_initial"))
    0 <= config.beta <= 1 || throw(ArgumentError("beta phải thuộc [0,1]"))
    config.tabu_add_size >= 0 && config.tabu_redis_size >= 0 ||
        throw(ArgumentError("tabu size phải không âm"))
    config.version === :TSO && config.neighborhood.n_redis != 0 &&
        throw(ArgumentError("TSO không dùng redistribute"))
    return config
end

function _push_tabu!(queue::Vector{T}, item::T, capacity::Int) where T
    capacity == 0 && return queue
    push!(queue, item)
    length(queue) > capacity && popfirst!(queue)
    return queue
end

function _best(candidates)
    isempty(candidates) && return nothing
    return argmin(c -> c.after, candidates)
end

function _choose_candidate(candidates::Vector{Candidate}, best_value::Float64,
                           config::TabuConfig, rng::AbstractRNG)
    orig = _best([c for c in candidates if !(c.move isa RedistributeMove)])
    redis = _best([c for c in candidates if c.move isa RedistributeMove])
    if isnothing(orig)
        return redis
    elseif isnothing(redis)
        return orig
    end
    best = redis.after < orig.after ? redis : orig
    if best.after < best_value - 1e-9
        return best
    end
    return rand(rng) < config.beta ? redis : orig
end

"""
Tìm kiếm từ cùng một nghiệm đầu để so sánh TSO/TSR công bằng.
`restart_initial(rng)` phải trả về FlowSolution khả thi cùng bài toán; nếu không
cung cấp, bước restart 600 vòng quay về một bản sao nghiệm đầu.
`history[k+1]` lưu incumbent sau k vòng, nên có cả điểm k=0.
"""
function tabu_search(initial::FlowSolution;
                     config::TabuConfig=default_tabu_config(initial.problem.n),
                     rng::AbstractRNG=Random.default_rng(),
                     restart_initial::Union{Nothing,Function}=nothing)
    _validate_config(config)
    validate_flow_solution(initial)
    current = copy(initial)
    best = copy(initial)
    best_value = makespan(best)
    history = Float64[best_value]
    tl_add = Tuple{Int,Int}[]
    tl_redis = Int[]
    stagnant = 0
    elite_restarts = 0
    initial_restarts = 0
    counts = Dict(:reroute => 0, :reverse => 0, :redistribute => 0)

    for _ in 1:config.max_iterations
        candidates = generate_neighbors(current; config=config.neighborhood, rng)
        allowed = [c for c in candidates if !is_tabu(c.move, tl_add, tl_redis)]
        chosen = _choose_candidate(allowed, best_value, config, rng)
        if !isnothing(chosen)
            current = materialize(current, chosen)
            kind = neighborhood_name(chosen.move)
            counts[kind] += 1
            for arc in removed_arcs(chosen.move)
                _push_tabu!(tl_add, arc, config.tabu_add_size)
            end
            if chosen.move isa RedistributeMove
                _push_tabu!(tl_redis, chosen.move.zeta, config.tabu_redis_size)
            end
            if chosen.after < best_value - 1e-9
                best = copy(current)
                best_value = chosen.after
                stagnant = 0
            else
                stagnant += 1
            end
        else
            # Không có ứng viên hợp lệ hoặc tất cả đang tabu.
            stagnant += 1
            empty!(tl_add)
            empty!(tl_redis)
        end

        if stagnant >= config.restart_initial
            fresh = isnothing(restart_initial) ? copy(initial) : restart_initial(rng)
            fresh.problem === initial.problem ||
                throw(ArgumentError("nghiệm restart không cùng bài toán"))
            validate_flow_solution(fresh)
            current = copy(fresh)
            empty!(tl_add)
            empty!(tl_redis)
            initial_restarts += 1
            stagnant = 0
            fresh_value = makespan(current)
            if fresh_value < best_value - 1e-9
                best = copy(current)
                best_value = fresh_value
            end
        elseif stagnant == config.restart_elite
            current = copy(best)
            empty!(tl_add)
            empty!(tl_redis)
            elite_restarts += 1
        end
        push!(history, best_value)
    end
    return TabuResult(best, first(history), best_value, history,
                      config.max_iterations, elite_restarts, initial_restarts, counts)
end

"""Tiện ích dùng greedy của Thành viên 1 để tạo nghiệm đầu và nghiệm restart."""
function tabu_search(instance::ProblemInstance;
                     config::TabuConfig=default_tabu_config(length(instance.tasks)),
                     seed::Integer=0)
    problem = FlowProblem(instance)
    make_initial(s) = from_solution(problem, instance, greedy_initial_solution(instance; seed=s))
    initial = make_initial(seed)
    rng = MersenneTwister(seed)
    return tabu_search(initial; config, rng,
                       restart_initial=rng -> make_initial(rand(rng, 1:typemax(Int))))
end
