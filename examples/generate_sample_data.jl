# Run from the project root with:
#   julia --project=. examples\generate_sample_data.jl
#
# Generate the six reproducible CSV instances for m in {1, 2} robots and
# n in {5, 10, 15} tasks. Task robot requirements are bounded by m.

project_dir = dirname(@__DIR__)
include(joinpath(project_dir, "src", "PDPCRMember1.jl"))
using .PDPCRMember1

data_dir = joinpath(project_dir, "data")
for robot_count in (1, 2), task_count in (5, 10, 15)
    instance = generate_instance(
        task_count,
        robot_count;
        seed=100 * robot_count + task_count,
        max_required_robots=robot_count,
    )
    filename = "sample_m$(robot_count)_n$(task_count).csv"
    output_path = joinpath(data_dir, filename)
    save_instance(instance, output_path)
    println(
        "Created $filename: m=$robot_count, n=$task_count, ",
        "robot demands=", getfield.(instance.tasks, :required_robots),
    )
end
