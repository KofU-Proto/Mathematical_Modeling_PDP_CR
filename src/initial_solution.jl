"""Greedy initializer cho assignment robot và thứ tự tác vụ."""

"""
Tạo nghiệm khả thi bằng cách lặp chọn task có thời gian hoàn tất dự kiến nhỏ
nhất, cấp cho task nhóm robot đến pickup sớm nhất, sau đó cập nhật vị trí
và thời điểm sẵn sàng của các robot đó.
"""
function greedy_initial_solution(instance::ProblemInstance; seed::Integer=0)
    rng = MersenneTwister(seed)
    task_count, robot_count = length(instance.tasks), instance.robot_count
    remaining = trues(task_count)
    ready_time = zeros(Float64, robot_count)
    robot_location = fill(instance.depot, robot_count)
    teams = [Int[] for _ in 1:task_count]
    order = Int[]

    while any(remaining)
        best_key = (Inf, Inf, typemax(Int))
        selected_task = 0
        selected_team = Int[]

        for task_index in 1:task_count
            remaining[task_index] || continue
            task = instance.tasks[task_index]
            arrivals = [
                (
                    ready_time[robot] + distance(robot_location[robot], task.pickup),
                    robot,
                )
                for robot in 1:robot_count
            ]
            sort!(arrivals; by=first)
            team_arrivals = arrivals[1:task.required_robots]
            estimated_finish = maximum(first, team_arrivals) + task.processing_time
            key = (estimated_finish, rand(rng), task_index)
            if key < best_key
                best_key = key
                selected_task = task_index
                selected_team = sort(last.(team_arrivals))
            end
        end

        task = instance.tasks[selected_task]
        arrival_time = maximum(
            ready_time[robot] + distance(robot_location[robot], task.pickup)
            for robot in selected_team
        )
        finish_time = arrival_time + task.processing_time
        for robot in selected_team
            ready_time[robot] = finish_time
            robot_location[robot] = task.delivery
        end
        teams[selected_task] = selected_team
        push!(order, selected_task)
        remaining[selected_task] = false
    end

    solution = Solution(order, teams)
    validate_solution(instance, solution)
    return solution
end
