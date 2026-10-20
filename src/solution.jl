"""Kiểu dữ liệu và xác thực nghiệm assignment/priority."""

"""
Một nghiệm khả thi ứng viên:

- `order`: thứ tự ưu tiên toàn cục, dùng task index `1:n`.
- `teams[i]`: các robot (đánh số `1:m`) được cấp cho task index `i`.
"""
struct Solution
    order::Vector{Int}
    teams::Vector{Vector{Int}}

    function Solution(order::AbstractVector{<:Integer}, teams::AbstractVector)
        normalized_teams = Vector{Vector{Int}}()
        for team in teams
            team isa AbstractVector{<:Integer} ||
                throw(ArgumentError("Mỗi đội robot phải là một vector số nguyên"))
            push!(normalized_teams, sort!(Int.(team)))
        end
        new(Int.(order), normalized_teams)
    end
end

"""Kiểm tra mỗi task xuất hiện đúng một lần và được cấp đúng đội robot."""
function validate_solution(instance::ProblemInstance, solution::Solution)
    task_count = length(instance.tasks)
    length(solution.order) == task_count &&
        sort(solution.order) == collect(1:task_count) ||
        throw(ArgumentError("order phải chứa mỗi task index từ 1:n đúng một lần"))
    length(solution.teams) == task_count ||
        throw(ArgumentError("Phải có một team cho mỗi task"))

    for task_index in 1:task_count
        task = instance.tasks[task_index]
        team = solution.teams[task_index]
        length(team) == task.required_robots ||
            throw(ArgumentError(
                "Task $(task.id) cần đúng $(task.required_robots) robot",
            ))
        length(unique(team)) == length(team) ||
            throw(ArgumentError("Team của task $(task.id) chứa robot trùng"))
        all(robot -> 1 <= robot <= instance.robot_count, team) ||
            throw(ArgumentError("Team của task $(task.id) có robot ngoài đội"))
    end
    return true
end
