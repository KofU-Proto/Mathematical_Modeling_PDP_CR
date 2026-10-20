"""Flow-DAG, kiểm tra tính khả thi và tính lịch/makespan PDP-CR."""

"""
Flow-DAG theo thứ tự task index `1:n`; nguồn là `0`, đích là `n+1`.
Mỗi tuple trong `flows` có dạng `(from, to, robot_count)`.
"""
struct FlowGraph
    nodes::Vector{Int}
    flows::Vector{Tuple{Int,Int,Int}}
    predecessors::Vector{Vector{Int}}
    topological_order::Vector{Int}
end

"""Lịch sớm nhất: start/finish được đánh chỉ số theo task index."""
struct Schedule
    start_times::Vector{Float64}
    finish_times::Vector{Float64}
    makespan::Float64
end

"""Dựng cung flow bằng cách nối các task liên tiếp trên tuyến của mỗi robot."""
function build_flow_graph(instance::ProblemInstance, solution::Solution)
    validate_solution(instance, solution)
    task_count, robot_count = length(instance.tasks), instance.robot_count
    sink = task_count + 1
    position = zeros(Int, task_count)
    for (rank, task_index) in enumerate(solution.order)
        position[task_index] = rank
    end

    routes = [Int[] for _ in 1:robot_count]
    for task_index in 1:task_count, robot in solution.teams[task_index]
        push!(routes[robot], task_index)
    end
    flows = Dict{Tuple{Int,Int},Int}()
    predecessors = [Set{Int}() for _ in 1:task_count]
    add_flow(from, to) = (flows[(from, to)] = get(flows, (from, to), 0) + 1)

    for route in routes
        sort!(route; by=task_index -> position[task_index])
        if isempty(route)
            add_flow(0, sink)
            continue
        end
        add_flow(0, first(route))
        for (from, to) in zip(route, route[2:end])
            add_flow(from, to)
            push!(predecessors[to], from)
        end
        add_flow(last(route), sink)
    end

    arcs = [(from, to, flow) for ((from, to), flow) in flows]
    sort!(arcs; by=arc -> (arc[1], arc[2]))
    graph = FlowGraph(
        [0; solution.order; sink],
        arcs,
        [sort!(collect(pred); by=task_index -> position[task_index]) for pred in predecessors],
        [0; solution.order; sink],
    )
    validate_flow_graph(instance, graph)
    return graph
end

"""Kiểm tra bảo toàn flow, đúng nhu cầu task và quan hệ topo acyclic."""
function validate_flow_graph(instance::ProblemInstance, graph::FlowGraph)
    task_count = length(instance.tasks)
    sink = task_count + 1
    rank = Dict(node => index for (index, node) in enumerate(graph.topological_order))
    inflow, outflow = zeros(Int, task_count), zeros(Int, task_count)
    source_flow, sink_flow = 0, 0

    for (from, to, flow) in graph.flows
        flow > 0 || throw(ArgumentError("Flow trên cung phải dương"))
        if from == 0
            source_flow += flow
        elseif 1 <= from <= task_count
            outflow[from] += flow
        else
            throw(ArgumentError("Nút xuất phát không tồn tại: $from"))
        end
        if to == sink
            sink_flow += flow
        elseif 1 <= to <= task_count
            inflow[to] += flow
        else
            throw(ArgumentError("Nút đích không tồn tại: $to"))
        end
        if from != 0 && to != sink
            rank[from] < rank[to] ||
                throw(ArgumentError("Cung flow vi phạm topo, đồ thị có chu trình"))
        end
    end

    source_flow == instance.robot_count ||
        throw(ArgumentError("Tổng flow từ depot nguồn không bằng số robot"))
    sink_flow == instance.robot_count ||
        throw(ArgumentError("Tổng flow về depot đích không bằng số robot"))
    for task_index in 1:task_count
        demand = instance.tasks[task_index].required_robots
        inflow[task_index] == demand ||
            throw(ArgumentError("Flow vào task $(instance.tasks[task_index].id) không bằng nhu cầu"))
        outflow[task_index] == demand ||
            throw(ArgumentError("Flow ra task $(instance.tasks[task_index].id) không bằng nhu cầu"))
    end
    return true
end

"""
Tính thời điểm bắt đầu sớm nhất bằng truyền thời gian trên DAG.
Task chờ robot đến muộn nhất; makespan tính cả hành trình về depot.
"""
function evaluate_schedule(instance::ProblemInstance, solution::Solution)
    graph = build_flow_graph(instance, solution)
    task_count = length(instance.tasks)
    starts, finishes = zeros(Float64, task_count), zeros(Float64, task_count)
    task_by_id = instance.tasks
    predecessors = graph.predecessors

    for task_index in solution.order
        task = task_by_id[task_index]
        pred = predecessors[task_index]
        if isempty(pred)
            starts[task_index] = distance(instance.depot, task.pickup)
        else
            starts[task_index] = maximum(
                finishes[parent] + travel_time(task_by_id[parent], task)
                for parent in pred
            )
        end
        finishes[task_index] = starts[task_index] + task.processing_time
    end

    has_successor = falses(task_count)
    for (from, to, _) in graph.flows
        if 1 <= from <= task_count && 1 <= to <= task_count
            has_successor[from] = true
        end
    end
    terminal_finish = [
        finishes[index] + distance(task_by_id[index].delivery, instance.depot)
        for index in 1:task_count if !has_successor[index]
    ]
    objective = isempty(terminal_finish) ? 0.0 : maximum(terminal_finish)
    return Schedule(starts, finishes, objective)
end

"""Tính objective PDP-CR là thời điểm robot cuối cùng quay về depot."""
makespan(instance::ProblemInstance, solution::Solution) =
    evaluate_schedule(instance, solution).makespan

"""Trả về `true` nếu nghiệm vượt qua các kiểm tra assignment và flow-DAG."""
function is_feasible(instance::ProblemInstance, solution::Solution)
    try
        validate_solution(instance, solution)
        build_flow_graph(instance, solution)
        return true
    catch error
        error isa ArgumentError || rethrow()
        return false
    end
end
