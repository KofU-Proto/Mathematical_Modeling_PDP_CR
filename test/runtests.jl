using Test
include(joinpath(@__DIR__, "..", "src", "PDPCRMember1.jl"))
using .PDPCRMember1

@testset "PDP-CR data model and validation" begin
    task = PDPTask("A", (0, 0), (3, 4), 5, 2)
    @test task.processing_time == 5
    @test distance(task.pickup, task.delivery) == 5
    @test_throws ArgumentError PDPTask("", (0, 0), (1, 1), 1, 1)
    @test_throws ArgumentError ProblemInstance([task], 1)
    @test_throws ArgumentError ProblemInstance([task, task], 2)
end

@testset "PDP-CR greedy, flow and evaluator" begin
    instance = ProblemInstance([
        PDPTask("A", (1, 0), (2, 0), 5, 1),
        PDPTask("B", (3, 0), (4, 0), 2, 2),
        PDPTask("C", (5, 0), (6, 0), 1, 1),
    ], 2)
    solution = greedy_initial_solution(instance; seed=4)
    graph = build_flow_graph(instance, solution)
    schedule = evaluate_schedule(instance, solution)

    @test validate_solution(instance, solution)
    @test is_feasible(instance, solution)
    @test length(graph.topological_order) == length(instance.tasks) + 2
    @test sum(flow for (from, _, flow) in graph.flows if from == 0) == 2
    @test sum(flow for (_, to, flow) in graph.flows if to == length(instance.tasks) + 1) == 2
    @test makespan(instance, solution) == schedule.makespan
    @test schedule.makespan >= maximum(schedule.finish_times)
end

@testset "PDP-CR synchronization wait" begin
    instance = ProblemInstance([
        PDPTask("A", (10, 0), (10, 0), 5, 1),
        PDPTask("B", (0, 0), (0, 0), 1, 2),
    ], 2)
    solution = Solution([1, 2], [[1], [1, 2]])
    schedule = evaluate_schedule(instance, solution)
    @test schedule.start_times[2] == 25.0
    @test is_feasible(instance, solution)
end

@testset "PDP-CR data generation and CSV" begin
    first = generate_instance(8, 5; seed=21)
    second = generate_instance(8, 5; seed=21)
    @test first.tasks == second.tasks
    @test all(1 <= task.required_robots <= 5 for task in first.tasks)
    sample_path = joinpath(@__DIR__, "..", "data", "sample.csv")
    sample = load_instance(sample_path, 2)
    @test length(sample.tasks) == 3
    @test is_feasible(sample, greedy_initial_solution(sample; seed=7))

    mktempdir() do directory
        path = joinpath(directory, "tasks.csv")
        save_instance(first, path)
        loaded = load_instance(path, 5)
        @test loaded.tasks == first.tasks

        blank_processing = joinpath(directory, "blank-processing.csv")
        write(
            blank_processing,
            "task_id,pickup_x,pickup_y,delivery_x,delivery_y,required_robots\n" *
            "A,0,0,3,4,1\n",
        )
        loaded_blank = load_instance(blank_processing, 1)
        @test loaded_blank.tasks[1].processing_time == 5
    end
end

@testset "PDP-CR SVG visualization" begin
    instance = load_instance(joinpath(@__DIR__, "..", "data", "sample.csv"), 2)
    solution = greedy_initial_solution(instance; seed=7)
    mktempdir() do directory
        svg_path = visualize_solution(
            instance,
            solution;
            output_path=joinpath(directory, "simulation.svg"),
        )
        svg = read(svg_path, String)
        @test occursin("<svg", svg)
        @test occursin("A", svg)
        @test occursin("Robot 1", svg)
        @test occursin("Lịch thực hiện", svg)
        @test occursin("makespan", svg)
    end
end
