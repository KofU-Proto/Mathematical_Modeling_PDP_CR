# Run from the project root with:
#   julia --project=. examples\visualize_sample.jl
#
# Steps:
# 1. Load the sample pickup-and-delivery instance.
# 2. Build a feasible greedy robot assignment and evaluate its synchronized schedule.
# 3. Export the route map and per-robot Gantt chart as an SVG under plots/.

project_dir = dirname(@__DIR__)
include(joinpath(project_dir, "src", "PDPCRMember1.jl"))
using .PDPCRMember1

instance = load_instance(joinpath(project_dir, "data", "sample.csv"), 2)
println("Loaded tasks: ", length(instance.tasks))
println("Robot count: ", instance.robot_count)

solution = greedy_initial_solution(instance; seed=7)
println("Feasible solution: ", is_feasible(instance, solution))
println("Task order: ", solution.order)
robot_routes_by_id = [
    [instance.tasks[index].id for index in solution.order if robot in solution.teams[index]]
    for robot in 1:instance.robot_count
]
println("Robot routes: ", robot_routes_by_id)

schedule = evaluate_schedule(instance, solution)
println("Start times: ", schedule.start_times)
println("Finish times: ", schedule.finish_times)
println("Makespan: ", schedule.makespan)

output_path = joinpath(project_dir, "plots", "sample_simulation.svg")
visualize_solution(instance, solution; output_path)
println("Visualization written to: ", output_path)
