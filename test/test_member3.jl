using Test
using Random
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
using .PDPCRMember1, .PDPCRMember2, .PDPCRMember3
include(joinpath(@__DIR__, "..", "experiments", "statistics.jl"))
using .ExperimentStatistics

@testset "Li & Lim VRPLIB → PDP-CR" begin
    mktempdir() do dir
        path = joinpath(dir, "LC1_2_test.vrp")
        write(path, """NAME: LC1_2_test
TYPE: PDPTW
DIMENSION: 5
NODE_COORD_SECTION
1 7 8
2 10 10
3 1 1
4 13 14
5 4 5
PICKUP_AND_DELIVERY_SECTION
1 0 0 0 0 0 0
2 1 0 0 0 0 4
3 1 0 0 0 0 5
4 -1 0 0 0 2 0
5 -1 0 0 0 3 0
DEPOT_SECTION
1
-1
EOF
""")
        instance = load_li_lim_vrp(path, 10; seed=42)
        @test instance.depot == (7.0, 8.0)
        @test length(instance.tasks) == 2
        @test instance.tasks[1].pickup == (10.0, 10.0)
        @test instance.tasks[1].delivery == (13.0, 14.0)
        @test instance.tasks[1].processing_time == 5.0
        @test instance.tasks == load_li_lim_vrp(path, 10; seed=42).tasks
        @test all(1 <= task.required_robots <= 5 for task in instance.tasks)
        @test_throws ArgumentError load_li_lim_vrp(path, 4)
        bad = joinpath(dir, "bad.vrp")
        write(bad, replace(read(path, String), "4 -1 0 0 0 2 0" => "4 -1 0 0 0 3 0"))
        @test_throws ArgumentError load_li_lim_vrp(bad, 10)
    end
end

@testset "Redistribute chỉ lấy láng giềng có thay đổi (tùy chọn)" begin
    path = joinpath(@__DIR__, "..", "data", "li_lim_raw", "lc1_2_1.vrp")
    inst = load_li_lim_vrp(path, 10; seed=42)
    sol = best_s_greedy_solution(inst; rng=MersenneTwister(1), trials=50)
    flow = from_solution(FlowProblem(inst), inst, sol)
    all_candidates = redistribute_neighbors(flow; rng=MersenneTwister(1))
    changed = redistribute_neighbors(flow; limit=7, skip_unchanged=true,
                                     rng=MersenneTwister(1), validate=true)
    @test any(c -> isempty(c.changes), all_candidates)
    @test !isempty(changed)
    @test length(changed) <= 7
    @test all(c -> !isempty(c.changes), changed)
    @test all(c -> makespan(materialize(flow, c)) ≈ c.after, changed)
end

@testset "Tabu Search: tham số và bất biến" begin
    tso = default_tabu_config(150, :TSO)
    tsr = default_tabu_config(150, :TSR)
    @test (tso.tabu_add_size, tso.tabu_redis_size, tso.beta) == (18, 0, 0.0)
    @test (tsr.tabu_add_size, tsr.tabu_redis_size, tsr.beta) == (18, 10, 0.3)
    @test tsr.neighborhood.n_redis == 10
    @test_throws ArgumentError default_tabu_config(10, :bad)

    instance = generate_instance(15, 4; seed=8)
    fresh = s_greedy_solution(instance; rng=MersenneTwister(8))
    @test validate_solution(instance, fresh)
    @test is_feasible(instance, fresh)
    initial = from_solution(FlowProblem(instance), instance, greedy_initial_solution(instance; seed=8))
    original_arcs = arcs(initial)
    for version in (:TSO, :TSR)
        config = default_tabu_config(15, version; max_iterations=30)
        result = tabu_search(initial; config, rng=MersenneTwister(3))
        @test result.iterations == 30
        @test length(result.history) == 31
        @test result.initial_makespan ≈ makespan(initial)
        @test result.best_makespan ≈ makespan(result.best)
        @test all(diff(result.history) .<= 1e-9)
        @test result.best_makespan <= result.initial_makespan + 1e-9
        @test validate_flow_solution(result.best)
        @test arcs(initial) == original_arcs
        @test sum(values(result.selected_moves)) <= result.iterations
        version === :TSO && @test result.selected_moves[:redistribute] == 0
    end
end

@testset "S-greedy Algorithm 5–6 và best-of-trials" begin
    instance = ProblemInstance([
        PDPTask("A", (0, 0), (1, 0), 1, 1),
        PDPTask("B", (10, 0), (11, 0), 1, 1),
    ], 2)
    sol = s_greedy_solution(instance; rng=MersenneTwister(1), k_range=(2, 2))
    @test sol.order == [1, 2]
    @test sol.teams == [[1], [2]]
    @test is_feasible(instance, sol)
    @test_throws ArgumentError s_greedy_solution(instance; k_range=(2, 1))
    @test_throws ArgumentError best_s_greedy_solution(instance; trials=0)

    for seed in 1:20
        inst = generate_instance(12, 5; seed)
        s = s_greedy_solution(inst; rng=MersenneTwister(seed), k_range=(1, 3))
        @test is_feasible(inst, s)
        f = from_solution(FlowProblem(inst), inst, s)
        @test makespan(f) ≈ PDPCRMember1.makespan(inst, s)
    end
    inst = generate_instance(15, 5; seed=20)
    rng = MersenneTwister(9)
    values = [PDPCRMember1.makespan(inst, s_greedy_solution(inst; rng)) for _ in 1:10]
    best = best_s_greedy_solution(inst; rng=MersenneTwister(9), trials=10)
    @test PDPCRMember1.makespan(inst, best) ≈ minimum(values)
    config = default_tabu_config(15, :TSO; max_iterations=0, initial_trials=10)
    wrapped = tabu_search(inst; config, seed=9)
    @test wrapped.initial_makespan ≈ PDPCRMember1.makespan(inst, best)
    @test wrapped.best_makespan == wrapped.initial_makespan
end

@testset "Thống kê cặp và đường hội tụ" begin
    pairs = [
        (n=15, m=5, seed=1,
         tso=(best_makespan=90.0, initial_makespan=100.0, history=[100.0, 90.0]),
         tsr=(best_makespan=80.0, initial_makespan=100.0, history=[100.0, 80.0]),
         tso_seconds=2.0, tsr_seconds=3.0),
        (n=15, m=5, seed=2,
         tso=(best_makespan=80.0, initial_makespan=100.0, history=[100.0, 80.0]),
         tsr=(best_makespan=85.0, initial_makespan=100.0, history=[100.0, 85.0]),
         tso_seconds=4.0, tsr_seconds=5.0),
    ]
    summary = only(summarize_pairs(pairs))
    @test summary.instances == 2
    @test summary.tso_mean == 85.0
    @test summary.tsr_mean == 82.5
    @test summary.tsr_better == 1
    @test summary.tsr_better_percent == 50.0
    @test summary.improvement_mean_percent ≈ (100 * 10 / 90 - 100 * 5 / 80) / 2
    curve = convergence_rows(pairs; step=1)
    @test curve[1].iteration == 0
    @test curve[1].tso_percent == 100
    @test curve[end].tsr_percent == 82.5
end

@testset "Tabu Search: restart và FIFO" begin
    instance = generate_instance(5, 2; seed=1)
    initial = from_solution(FlowProblem(instance), instance, greedy_initial_solution(instance; seed=1))
    empty_neighborhood = NeighborhoodConfig(n_redis=0, n_reroute=0, n_reverse=0)
    config = default_tabu_config(5, :TSO; max_iterations=9, restart_elite=2,
                                 restart_initial=4, neighborhood=empty_neighborhood)
    result = tabu_search(initial; config, rng=MersenneTwister(1))
    @test result.elite_restarts == 2
    @test result.initial_restarts == 2
    @test result.best_makespan == result.initial_makespan
    queue = Int[]
    PDPCRMember3._push_tabu!(queue, 1, 2)
    PDPCRMember3._push_tabu!(queue, 2, 2)
    PDPCRMember3._push_tabu!(queue, 3, 2)
    @test queue == [2, 3]
end
