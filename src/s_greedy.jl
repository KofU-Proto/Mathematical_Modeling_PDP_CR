"""S-greedy append theo Algorithm 5–6, Chương 4 luận án Nguyen (2025)."""

"""
Algorithm 6: thêm tối đa `kinsert` task vào các tuyến robot trong một lượt.
Danh sách L được cố định trước khi gán task. Mỗi robot được dùng tối đa một lần
trong lượt; các nhóm robot chưa đủ người có thể bị rút khi robot được gán cho
task khác.
"""
function _append_s_greedy_batch!(instance::ProblemInstance,
                                 routes::Vector{Vector{Int}}, ready::Vector{Float64},
                                 locations::Vector{Point2D}, remaining::BitVector,
                                 order::Vector{Int}, kinsert::Int)
    n, m = length(instance.tasks), instance.robot_count
    L = Tuple{Float64,Int,Int}[]
    for i in 1:n
        remaining[i] || continue
        task = instance.tasks[i]
        for k in 1:m
            push!(L, (ready[k] + distance(locations[k], task.pickup), i, k))
        end
    end
    sort!(L)  # tăng theo l'ki; khi bằng nhau, task và robot có thứ tự cố định

    inserted_robot = falses(m)
    inserted_task = falses(n)
    best_paths = [Int[] for _ in 1:n]
    current_tasks = [Int[] for _ in 1:m]
    current_count = zeros(Int, n)
    robots_left = m
    completed = 0

    for (arrival, i, k) in L
        task = instance.tasks[i]
        if task.required_robots > robots_left || inserted_task[i] || inserted_robot[k]
            continue
        end
        push!(best_paths[i], k)
        current_count[i] += 1
        push!(current_tasks[k], i)
        if current_count[i] == task.required_robots
            finish = arrival + task.processing_time
            for robot in best_paths[i]
                push!(routes[robot], i)
                ready[robot] = finish
                locations[robot] = task.delivery
                inserted_robot[robot] = true
                for other in current_tasks[robot]
                    other == i && continue
                    filter!(!=(robot), best_paths[other])
                    current_count[other] -= 1
                end
            end
            remaining[i] = false
            inserted_task[i] = true
            push!(order, i)
            completed += 1
            robots_left -= task.required_robots
            kinsert -= 1
            (kinsert == 0 || robots_left == 0) && break
        end
    end
    completed >= 1 || error("Algorithm 6 không thêm được task nào")
    return completed
end

"""
Algorithm 5: chọn ngẫu nhiên `kinsert ∈ k_range`, rồi áp dụng Algorithm 6
cho đến khi mọi task được gán. Mặc định dùng khoảng 1–2 của luận án.
Trả về `Solution` của Thành viên 1 để chuyển sang flow-DAG của Thành viên 2.
"""
function s_greedy_solution(instance::ProblemInstance;
                           rng::AbstractRNG=Random.default_rng(),
                           k_range::Tuple{Int,Int}=(1, 2))
    k1, k2 = k_range
    1 <= k1 <= k2 || throw(ArgumentError("cần 1 <= k1 <= k2"))
    n, m = length(instance.tasks), instance.robot_count
    remaining = trues(n)
    routes = [Int[] for _ in 1:m]
    ready = zeros(Float64, m)
    locations = fill(instance.depot, m)
    order = Int[]
    while any(remaining)
        kinsert = rand(rng, k1:k2)
        _append_s_greedy_batch!(instance, routes, ready, locations, remaining,
                                order, kinsert)
    end
    teams = [Int[] for _ in 1:n]
    for (robot, route) in enumerate(routes), i in route
        push!(teams[i], robot)
    end
    solution = Solution(order, teams)
    validate_solution(instance, solution)
    return solution
end

"""Chọn nghiệm có makespan nhỏ nhất trong `trials` lần chạy S-greedy."""
function best_s_greedy_solution(instance::ProblemInstance;
                                rng::AbstractRNG=Random.default_rng(),
                                k_range::Tuple{Int,Int}=(1, 2), trials::Int=50)
    trials >= 1 || throw(ArgumentError("trials phải dương"))
    best = nothing
    best_value = Inf
    for _ in 1:trials
        candidate = s_greedy_solution(instance; rng, k_range)
        value = PDPCRMember1.makespan(instance, candidate)
        if value < best_value
            best = candidate
            best_value = value
        end
    end
    return best
end
