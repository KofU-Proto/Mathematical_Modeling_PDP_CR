# Run from the project root with:
#   julia --project=. examples\visualize_sample.jl
#
# Steps:
# 1. Load each sample instance for m in {1, 2} and n in {5, 10, 15}.
# 2. Build a feasible greedy robot assignment and evaluate its synchronized schedule.
# 3. Export a route map and per-robot Gantt chart for each instance under plots/.

project_dir = dirname(@__DIR__)
include(joinpath(project_dir, "src", "PDPCRMember1.jl"))
using .PDPCRMember1

data_dir = joinpath(project_dir, "data")
plots_dir = joinpath(project_dir, "plots")
mkpath(plots_dir)

for robot_count in (1, 2), task_count in (5, 10, 15)
    stem = "sample_m$(robot_count)_n$(task_count)"
    instance = load_instance(joinpath(data_dir, "$stem.csv"), robot_count)
    solution = greedy_initial_solution(instance; seed=7)
    feasible = is_feasible(instance, solution)
    feasible || error("Greedy solution is infeasible for $stem")
    schedule = evaluate_schedule(instance, solution)

    println("\n=== $stem ===")
    println("Loaded tasks: ", length(instance.tasks))
    println("Robot count: ", instance.robot_count)
    println("Feasible solution: ", feasible)
    println("Task order: ", [instance.tasks[index].id for index in solution.order])
    robot_routes_by_id = [
        [instance.tasks[index].id for index in solution.order if robot in solution.teams[index]]
        for robot in 1:instance.robot_count
    ]
    println("Robot routes: ", robot_routes_by_id)
    println("Task schedule (task, assigned robots, start, finish):")
    for index in solution.order
        println(
            "  ",
            instance.tasks[index].id,
            ", ",
            solution.teams[index],
            ", ",
            round(schedule.start_times[index], digits=2),
            ", ",
            round(schedule.finish_times[index], digits=2),
        )
    end
    println("Makespan: ", round(schedule.makespan, digits=2))

    output_path = joinpath(plots_dir, "sample_simulation_m$(robot_count)_n$(task_count).svg")
    visualize_solution(instance, solution; output_path)
    println("Visualization written to: ", output_path)
end
