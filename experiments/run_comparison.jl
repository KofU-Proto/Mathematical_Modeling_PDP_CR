# Chạy cặp TSO/TSR có seed cố định; chỉ cần Julia standard library.
using Random
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
include(joinpath(@__DIR__, "statistics.jl"))
using .PDPCRMember1, .PDPCRMember2, .PDPCRMember3, .ExperimentStatistics

function options(args)
    opts = Dict("sizes" => "15,30", "robots" => "5,10", "seeds" => "1,2",
                "iterations" => "5000", "step" => "100",
                "initial-trials" => "50", "k-range" => "1,2",
                "input-dir" => "", "demand-seed" => "42",
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
    initial_trials = parse(Int, opts["initial-trials"])
    range_values = parse_list("k-range")
    length(range_values) == 2 || throw(ArgumentError("k-range cần hai số, ví dụ 1,2"))
    k_range = (range_values[1], range_values[2])
    initial_trials >= 1 && 1 <= k_range[1] <= k_range[2] ||
        throw(ArgumentError("cần initial-trials >= 1 và 1 <= k1 <= k2"))
    return (; sizes, robots, seeds, iterations, step, initial_trials, k_range,
             input_dir=opts["input-dir"], demand_seed=parse(Int, opts["demand-seed"]),
             output=opts["output"])
end

function experiment_cases(opts)
    if isempty(opts.input_dir)
        return [(n=n, m=m, seed=seed, source="synthetic_n$(n)_seed$(seed)",
                 instance=generate_instance(n, m; seed))
                for n in opts.sizes for m in opts.robots for seed in opts.seeds]
    end
    isdir(opts.input_dir) || throw(ArgumentError("Không tìm thấy input-dir: $(opts.input_dir)"))
    files = sort(filter(name -> endswith(lowercase(name), ".vrp"), readdir(opts.input_dir)))
    isempty(files) && throw(ArgumentError("input-dir không có file .vrp"))
    cases = NamedTuple[]
    for (index, file) in enumerate(files)
        matched = match(r"(?i)^lc1_(\d+)_\d+\.vrp$", file)
        matched === nothing && throw(ArgumentError("Tên file không phải LC1_x_y.vrp: $file"))
        nominal_n = 50 * parse(Int, matched.captures[1])
        for m in opts.robots
            instance = load_li_lim_vrp(joinpath(opts.input_dir, file), m;
                                        seed=opts.demand_seed)
            push!(cases, (n=nominal_n, m=m, seed=index, source=file, instance=instance))
        end
    end
    return cases
end

function run_comparison(opts)
    # Julia biên dịch ở lần gọi đầu; làm nóng cả hai phiên bản trước khi đo thời gian.
    warm_instance = generate_instance(8, 5; seed=0)
    warm_problem = FlowProblem(warm_instance)
    warm_initial = from_solution(warm_problem, warm_instance,
        best_s_greedy_solution(warm_instance; rng=MersenneTwister(0), trials=2))
    for version in (:TSO, :TSR)
        tabu_search(warm_initial; config=default_tabu_config(8, version; max_iterations=2),
                    rng=MersenneTwister(0),
                    restart_initial=rng -> from_solution(warm_problem, warm_instance,
                        best_s_greedy_solution(warm_instance; rng, trials=2)))
    end
    pairs = NamedTuple[]
    runs = NamedTuple[]
    run_header = ["n", "actual_tasks", "m", "seed", "source", "demand_seed", "version", "initial_makespan", "best_makespan",
                  "seconds", "iterations", "initial_trials", "k1", "k2",
                  "elite_restarts", "initial_restarts",
                  "reroute_moves", "reverse_moves", "redistribute_moves"]
    summary_header = ["n", "m", "instances", "tso_best", "tso_mean", "tsr_best", "tsr_mean",
                      "tso_mean_seconds", "tsr_mean_seconds", "tsr_better", "tsr_better_percent",
                      "improvement_mean_percent", "improvement_min_percent",
                      "improvement_max_percent"]
    convergence_header = ["n", "m", "iteration", "tso_percent", "tsr_percent"]
    mkpath(opts.output)
    write_rows(joinpath(opts.output, "runs.csv"), run_header, runs)
    for case in experiment_cases(opts)
        (; n, m, seed, source, instance) = case
        actual_n = length(instance.tasks)
        problem = FlowProblem(instance)
        initial = from_solution(problem, instance,
            best_s_greedy_solution(instance; rng=MersenneTwister(seed),
                k_range=opts.k_range, trials=opts.initial_trials))
        results = Dict{Symbol,TabuResult}()
        seconds = Dict{Symbol,Float64}()
        for version in (:TSO, :TSR)
            config = default_tabu_config(actual_n, version; max_iterations=opts.iterations,
                initial_trials=opts.initial_trials, initial_k_range=opts.k_range)
            next_initial(rng) = from_solution(problem, instance,
                best_s_greedy_solution(instance; rng, k_range=opts.k_range,
                    trials=opts.initial_trials))
            elapsed = @elapsed result = tabu_search(initial; config,
                rng=MersenneTwister(seed), restart_initial=next_initial)
            results[version] = result
            seconds[version] = elapsed
            push!(runs, (n=n, actual_tasks=actual_n, m=m, seed=seed, source=source,
                demand_seed=isempty(opts.input_dir) ? "" : opts.demand_seed, version=version,
                initial_makespan=result.initial_makespan,
                best_makespan=result.best_makespan, seconds=elapsed,
                iterations=result.iterations, initial_trials=opts.initial_trials,
                k1=opts.k_range[1], k2=opts.k_range[2],
                elite_restarts=result.elite_restarts,
                initial_restarts=result.initial_restarts,
                reroute_moves=result.selected_moves[:reroute],
                reverse_moves=result.selected_moves[:reverse],
                redistribute_moves=result.selected_moves[:redistribute]))
            println("source=$source n=$n actual_tasks=$actual_n m=$m seed=$seed $version: ", round(result.best_makespan; digits=3),
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
