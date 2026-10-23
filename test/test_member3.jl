using Test
using Random
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
using .PDPCRMember1, .PDPCRMember2, .PDPCRMember3

@testset "Tabu Search: tham số và bất biến" begin
    tso = default_tabu_config(150, :TSO)
    tsr = default_tabu_config(150, :TSR)
    @test (tso.tabu_add_size, tso.tabu_redis_size, tso.beta) == (18, 0, 0.0)
    @test (tsr.tabu_add_size, tsr.tabu_redis_size, tsr.beta) == (18, 10, 0.3)
    @test tsr.neighborhood.n_redis == 10
    @test_throws ArgumentError default_tabu_config(10, :bad)

    instance = generate_instance(15, 4; seed=8)
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
