# Chạy cặp TSO/TSR có seed cố định; chỉ cần Julia standard library.
using Random
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
include(joinpath(@__DIR__, "statistics.jl"))
using .PDPCRMember1, .PDPCRMember2, .PDPCRMember3, .ExperimentStatistics

function options(args)
    opts = Dict("sizes" => "15,30", "robots" => "5,10", "seeds" => "1,2",
                "iterations" => "5000", "step" => "100",
                "output" => joinpath(@__DIR__, "..", "results", "member3"))
    for arg in args
        startswith(arg, "--") && occursin('=', arg) ||
            throw(ArgumentError("Dùng --key=value, ví dụ --iterations=5000"))
        key, value = split(arg[3:end], '='; limit=2)
        haskey(opts, key) || throw(ArgumentError("Tùy chọn không hợp lệ: $key"))
        opts[key] = value
    end
    parse_list(key) = [parse(Int, strip(x)) for x in split(opts[key], ',')]
    sizes, robots, seeds = parse_list("sizes"), parse_list("robots"), parse_list("seeds")
    all(>(0), sizes) && all(>(0), robots) && !isempty(seeds) ||
        throw(ArgumentError("sizes, robots phải dương; seeds không được rỗng"))
    iterations, step = parse(Int, opts["iterations"]), parse(Int, opts["step"])
    iterations >= 0 && step > 0 || throw(ArgumentError("iterations >= 0 và step > 0"))
    return (; sizes, robots, seeds, iterations, step, output=opts["output"])
end

function run_comparison(opts)
    # Julia biên dịch ở lần gọi đầu; làm nóng cả hai phiên bản trước khi đo thời gian.
    warm_instance = generate_instance(8, 5; seed=0)
    warm_problem = FlowProblem(warm_instance)
    warm_initial = from_solution(warm_problem, warm_instance,
                                 greedy_initial_solution(warm_instance; seed=0))
    for version in (:TSO, :TSR)
        tabu_search(warm_initial; config=default_tabu_config(8, version; max_iterations=2),
                    rng=MersenneTwister(0))
    end
    pairs = NamedTuple[]
    runs = NamedTuple[]
    run_header = ["n", "m", "seed", "version", "initial_makespan", "best_makespan",
                  "seconds", "iterations", "elite_restarts", "initial_restarts",
                  "reroute_moves", "reverse_moves", "redistribute_moves"]
    summary_header = ["n", "m", "instances", "tso_best", "tso_mean", "tsr_best", "tsr_mean",
                      "tso_mean_seconds", "tsr_mean_seconds", "tsr_better", "tsr_better_percent",
                      "improvement_mean_percent", "improvement_min_percent",
                      "improvement_max_percent"]
    convergence_header = ["n", "m", "iteration", "tso_percent", "tsr_percent"]
    mkpath(opts.output)
    write_rows(joinpath(opts.output, "runs.csv"), run_header, runs)
    for n in opts.sizes, m in opts.robots, seed in opts.seeds
        instance = generate_instance(n, m; seed)
        problem = FlowProblem(instance)
        initial = from_solution(problem, instance, greedy_initial_solution(instance; seed))
        results = Dict{Symbol,TabuResult}()
        seconds = Dict{Symbol,Float64}()
        for version in (:TSO, :TSR)
            config = default_tabu_config(n, version; max_iterations=opts.iterations)
            next_initial(rng) = from_solution(problem, instance,
                diversified_greedy_solution(instance; rng))
            elapsed = @elapsed result = tabu_search(initial; config,
                rng=MersenneTwister(seed), restart_initial=next_initial)
            results[version] = result
            seconds[version] = elapsed
            push!(runs, (n=n, m=m, seed=seed, version=version,
                initial_makespan=result.initial_makespan,
                best_makespan=result.best_makespan, seconds=elapsed,
                iterations=result.iterations, elite_restarts=result.elite_restarts,
                initial_restarts=result.initial_restarts,
                reroute_moves=result.selected_moves[:reroute],
                reverse_moves=result.selected_moves[:reverse],
                redistribute_moves=result.selected_moves[:redistribute]))
            println("n=$n m=$m seed=$seed $version: ", round(result.best_makespan; digits=3),
                    " (", round(elapsed; digits=2), " s)")
            flush(stdout)
            write_rows(joinpath(opts.output, "runs.csv"), run_header, runs)
        end
        push!(pairs, (n=n, m=m, seed=seed, tso=results[:TSO], tsr=results[:TSR],
                      tso_seconds=seconds[:TSO], tsr_seconds=seconds[:TSR]))
        write_rows(joinpath(opts.output, "summary.csv"), summary_header, summarize_pairs(pairs))
        write_rows(joinpath(opts.output, "convergence.csv"), convergence_header,
                   convergence_rows(pairs; step=opts.step))
    end
    summary = summarize_pairs(pairs)
    return pairs, summary
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_comparison(options(ARGS))
end
