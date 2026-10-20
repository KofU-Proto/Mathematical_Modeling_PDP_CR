"""Tạo SVG mô phỏng tuyến robot và lịch thực hiện nhiệm vụ."""

const ROBOT_COLORS = (
    "#2563eb",
    "#dc2626",
    "#059669",
    "#9333ea",
    "#ea580c",
    "#0891b2",
    "#be123c",
    "#4d7c0f",
)

"""Escape ký tự XML để chèn nhãn dữ liệu an toàn vào SVG."""
function svg_escape(value)
    return replace(
        string(value),
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&apos;",
    )
end

"""Chọn màu tuyến có thể phân biệt cho mỗi robot."""
robot_color(robot::Integer) = ROBOT_COLORS[mod1(robot, length(ROBOT_COLORS))]

"""
Xuất một hình SVG gồm sơ đồ tọa độ pickup/delivery và timeline Gantt.

Mỗi tuyến robot được vẽ từ depot qua pickup, delivery của các task theo thứ tự
nghiệm rồi quay về depot. Gantt hiển thị thời gian di chuyển/chờ (nét đứt),
thời gian xử lý từng task và các khoảng chờ đồng bộ của robot đến sớm.
"""
function visualize_solution(
    instance::ProblemInstance,
    solution::Solution;
    output_path::AbstractString=joinpath("plots", "simulation.svg"),
)
    validate_solution(instance, solution)
    schedule = evaluate_schedule(instance, solution)
    routes = robot_routes(instance, solution)

    canvas_width, canvas_height = 1500.0, 790.0
    map_x, map_y = 48.0, 105.0
    map_width, map_height = 660.0, 570.0
    chart_x, chart_y = 805.0, 150.0
    chart_width, chart_height = 635.0, 470.0

    coordinates = Point2D[instance.depot]
    for task in instance.tasks
        push!(coordinates, task.pickup, task.delivery)
    end
    x_values, y_values = first.(coordinates), last.(coordinates)
    x_min, x_max = extrema(x_values)
    y_min, y_max = extrema(y_values)
    x_span, y_span = max(x_max - x_min, 1.0), max(y_max - y_min, 1.0)
    x_min -= 0.08 * x_span
    x_max += 0.08 * x_span
    y_min -= 0.08 * y_span
    y_max += 0.08 * y_span

    scale = min(map_width / (x_max - x_min), map_height / (y_max - y_min))
    used_width = (x_max - x_min) * scale
    used_height = (y_max - y_min) * scale
    plot_x = map_x + (map_width - used_width) / 2
    plot_y = map_y + (map_height - used_height) / 2
    map_point(point::Point2D) = (
        plot_x + (point[1] - x_min) * scale,
        plot_y + used_height - (point[2] - y_min) * scale,
    )
    horizon = max(schedule.makespan, 1.0)

    mkpath(dirname(abspath(output_path)))
    open(output_path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="790" viewBox="0 0 1500 790">
<defs>
  <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 z" fill="context-stroke"/>
  </marker>
  <pattern id="waitHatch" width="7" height="7" patternTransform="rotate(45)" patternUnits="userSpaceOnUse">
    <rect width="7" height="7" fill="#fff7ed"/>
    <line x1="0" y1="0" x2="0" y2="7" stroke="#f97316" stroke-width="2"/>
  </pattern>
</defs>
<rect width="100%" height="100%" fill="#ffffff"/>
<text x="750" y="38" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="24" font-weight="700" fill="#172033">Mô phỏng PDP-CR: tuyến robot và lịch đồng bộ</text>
<text x="$(map_x)" y="77" font-family="Segoe UI, sans-serif" font-size="18" font-weight="700" fill="#172033">1. Tuyến trên mặt bằng</text>
<text x="$(chart_x)" y="77" font-family="Segoe UI, sans-serif" font-size="18" font-weight="700" fill="#172033">2. Lịch thực hiện theo robot</text>
""")

        print_map_grid(io, map_x, map_y, map_width, map_height, x_min, x_max, y_min, y_max, map_point)
        print_route_edges(io, instance, routes, map_point)
        print_task_markers(io, instance, map_point)
        print_depot_marker(io, map_point(instance.depot))
        print_map_legend(io, instance, map_x, map_y + map_height + 38)
        print_gantt(io, instance, solution, schedule, routes, chart_x, chart_y, chart_width, chart_height, horizon)
        println(io, """<text x="48" y="775" font-family="Segoe UI, sans-serif" font-size="12" fill="#475569">Màu nét liền: tuyến robot · ○ pickup · □ delivery · gạch chéo: chờ đồng bộ · Gantt: nét đứt = di chuyển/chờ</text>
<text x="1440" y="775" text-anchor="end" font-family="Segoe UI, sans-serif" font-size="12" fill="#475569">makespan = $(round(schedule.makespan, digits=2))</text>
</svg>
""")
    end
    return output_path
end

"""Lập tuyến task theo thứ tự nghiệm cho từng robot."""
function robot_routes(instance::ProblemInstance, solution::Solution)
    routes = [Int[] for _ in 1:instance.robot_count]
    order_position = zeros(Int, length(instance.tasks))
    for (position, task_index) in enumerate(solution.order)
        order_position[task_index] = position
    end
    for task_index in eachindex(solution.teams), robot in solution.teams[task_index]
        push!(routes[robot], task_index)
    end
    for route in routes
        sort!(route; by=task_index -> order_position[task_index])
    end
    return routes
end

"""Vẽ lưới tọa độ và nhãn trục của sơ đồ mặt bằng."""
function print_map_grid(io, x, y, width, height, x_min, x_max, y_min, y_max, map_point)
    println(io, """<rect x="$x" y="$y" width="$width" height="$height" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>""")
    for tick in 0:4
        xv = x_min + (x_max - x_min) * tick / 4
        yv = y_min + (y_max - y_min) * tick / 4
        gx, _ = map_point((xv, y_min))
        _, gy = map_point((x_min, yv))
        println(io, """<line x1="$(round(gx,digits=2))" y1="$y" x2="$(round(gx,digits=2))" y2="$(y+height)" stroke="#e2e8f0"/>""")
        println(io, """<line x1="$x" y1="$(round(gy,digits=2))" x2="$(x+width)" y2="$(round(gy,digits=2))" stroke="#e2e8f0"/>""")
        println(io, """<text x="$(round(gx,digits=2))" y="$(y+height+17)" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#64748b">$(round(xv,digits=1))</text>""")
        println(io, """<text x="$(x-7)" y="$(round(gy+3,digits=2))" text-anchor="end" font-family="sans-serif" font-size="10" fill="#64748b">$(round(yv,digits=1))</text>""")
    end
end

"""Vẽ các đoạn tuyến có mũi tên: depot, pickup, delivery và task kế tiếp."""
function print_route_edges(io, instance, routes, map_point)
    for (robot, route) in enumerate(routes)
        isempty(route) && continue
        color = robot_color(robot)
        waypoints = Point2D[instance.depot]
        for task_index in route
            task = instance.tasks[task_index]
            push!(waypoints, task.pickup, task.delivery)
        end
        push!(waypoints, instance.depot)
        for (from, to) in zip(waypoints, waypoints[2:end])
            x1, y1 = map_point(from)
            x2, y2 = map_point(to)
            dx, dy = x2 - x1, y2 - y1
            length = hypot(dx, dy)
            length < 2 && continue
            if length > 14
                inset = 9.0
                x2 -= dx / length * inset
                y2 -= dy / length * inset
            end
            println(io, """<line x1="$(round(x1,digits=2))" y1="$(round(y1,digits=2))" x2="$(round(x2,digits=2))" y2="$(round(y2,digits=2))" stroke="$color" stroke-width="2.6" stroke-opacity="0.7" marker-end="url(#arrow)"/>""")
        end
    end
end

"""Vẽ và gắn nhãn pickup circle/delivery square cho tất cả task."""
function print_task_markers(io, instance, map_point)
    for task in instance.tasks
        px, py = map_point(task.pickup)
        dx, dy = map_point(task.delivery)
        println(io, """<line x1="$(round(px,digits=2))" y1="$(round(py,digits=2))" x2="$(round(dx,digits=2))" y2="$(round(dy,digits=2))" stroke="#64748b" stroke-width="1.2" stroke-dasharray="3,3"/>""")
        println(io, """<circle cx="$(round(px,digits=2))" cy="$(round(py,digits=2))" r="6" fill="#fbbf24" stroke="#92400e" stroke-width="1.5"/>""")
        println(io, """<rect x="$(round(dx-5,digits=2))" y="$(round(dy-5,digits=2))" width="10" height="10" fill="#fb7185" stroke="#9f1239" stroke-width="1.5"/>""")
        println(io, """<text x="$(round(px+7,digits=2))" y="$(round(py-7,digits=2))" font-family="sans-serif" font-size="11" font-weight="700" fill="#0f172a">$(svg_escape(task.id))</text>""")
    end
end

"""Vẽ depot và nhãn."""
function print_depot_marker(io, point)
    x, y = point
    println(io, """<circle cx="$(round(x,digits=2))" cy="$(round(y,digits=2))" r="10" fill="#1e293b" stroke="#ffffff" stroke-width="2"/>""")
    println(io, """<text x="$(round(x+12,digits=2))" y="$(round(y+4,digits=2))" font-family="sans-serif" font-size="12" font-weight="700" fill="#0f172a">Depot</text>""")
end

"""Vẽ chú giải màu robot và ký hiệu pickup/delivery."""
function print_map_legend(io, instance, x, y)
    for robot in 1:instance.robot_count
        column, row = (robot - 1) % 4, (robot - 1) ÷ 4
        lx, ly = x + column * 105, y + row * 22
        color = robot_color(robot)
        println(io, """<line x1="$lx" y1="$ly" x2="$(lx+24)" y2="$ly" stroke="$color" stroke-width="4"/>""")
        println(io, """<text x="$(lx+30)" y="$(ly+4)" font-family="sans-serif" font-size="11" fill="#334155">Robot $robot</text>""")
    end
    legend_y = y + 22 * cld(instance.robot_count, 4) + 4
    println(io, """<circle cx="$(x+7)" cy="$legend_y" r="5" fill="#fbbf24" stroke="#92400e"/>""")
    println(io, """<text x="$(x+17)" y="$(legend_y+4)" font-family="sans-serif" font-size="11" fill="#334155">Pickup</text>""")
    println(io, """<rect x="$(x+90)" y="$(legend_y-5)" width="10" height="10" fill="#fb7185" stroke="#9f1239"/>""")
    println(io, """<text x="$(x+106)" y="$(legend_y+4)" font-family="sans-serif" font-size="11" fill="#334155">Delivery</text>""")
end

"""Vẽ timeline Gantt của robot, bao gồm các khoảng chờ đồng bộ."""
function print_gantt(io, instance, solution, schedule, routes, x, y, width, height, horizon)
    row_height = height / max(instance.robot_count, 1)
    println(io, """<rect x="$x" y="$y" width="$width" height="$height" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>""")
    for tick in 0:5
        time = horizon * tick / 5
        gx = x + width * tick / 5
        println(io, """<line x1="$(round(gx,digits=2))" y1="$y" x2="$(round(gx,digits=2))" y2="$(y+height)" stroke="#e2e8f0"/>""")
        println(io, """<text x="$(round(gx,digits=2))" y="$(y+height+20)" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#64748b">$(round(time,digits=1))</text>""")
    end

    for robot in 1:instance.robot_count
        center_y = y + (robot - 0.5) * row_height
        println(io, """<text x="$(x-12)" y="$(round(center_y+4,digits=2))" text-anchor="end" font-family="sans-serif" font-size="11" fill="$(robot_color(robot))">R$robot</text>""")
        previous_task = 0
        previous_finish = 0.0
        for task_index in routes[robot]
            task = instance.tasks[task_index]
            arrival = previous_task == 0 ?
                distance(instance.depot, task.pickup) :
                schedule.finish_times[previous_task] + travel_time(instance.tasks[previous_task], task)
            task_start = schedule.start_times[task_index]
            if task_start > previous_finish + 1e-9
                gap_x = x + previous_finish / horizon * width
                gap_end = x + task_start / horizon * width
                arrival_x = x + min(arrival, task_start) / horizon * width
                if arrival > previous_finish + 1e-9
                    println(io, """<line x1="$(round(gap_x,digits=2))" y1="$(round(center_y,digits=2))" x2="$(round(arrival_x,digits=2))" y2="$(round(center_y,digits=2))" stroke="#64748b" stroke-width="2" stroke-dasharray="4,3"/>""")
                end
                if task_start > max(arrival, previous_finish) + 1e-9
                    wait_start = x + max(arrival, previous_finish) / horizon * width
                    println(io, """<rect x="$(round(wait_start,digits=2))" y="$(round(center_y-row_height*0.24,digits=2))" width="$(round(gap_end-wait_start,digits=2))" height="$(round(row_height*0.48,digits=2))" fill="url(#waitHatch)" stroke="#f97316" stroke-width="1"/>""")
                end
            end

            bar_x = x + task_start / horizon * width
            bar_end = x + schedule.finish_times[task_index] / horizon * width
            bar_width = max(bar_end - bar_x, 2.0)
            color = robot_color(robot)
            println(io, """<rect x="$(round(bar_x,digits=2))" y="$(round(center_y-row_height*0.28,digits=2))" width="$(round(bar_width,digits=2))" height="$(round(row_height*0.56,digits=2))" rx="3" fill="$color" fill-opacity="0.86"/>""")
            if bar_width >= 28
                println(io, """<text x="$(round(bar_x+bar_width/2,digits=2))" y="$(round(center_y+4,digits=2))" text-anchor="middle" font-family="sans-serif" font-size="10" font-weight="700" fill="#ffffff">$(svg_escape(task.id))</text>""")
            end
            previous_task = task_index
            previous_finish = schedule.finish_times[task_index]
        end

        if previous_task != 0
            return_time = previous_finish + distance(instance.tasks[previous_task].delivery, instance.depot)
            return_x = x + previous_finish / horizon * width
            return_end = x + return_time / horizon * width
            println(io, """<line x1="$(round(return_x,digits=2))" y1="$(round(center_y,digits=2))" x2="$(round(return_end,digits=2))" y2="$(round(center_y,digits=2))" stroke="$(robot_color(robot))" stroke-width="2.2" stroke-dasharray="4,3" marker-end="url(#arrow)"/>""")
        end
    end

    println(io, """<text x="$(x+width/2)" y="$(y+height+42)" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#334155">Thời gian</text>""")
    println(io, """<text x="$(x+5)" y="$(y+height+64)" font-family="sans-serif" font-size="10" fill="#64748b">Khoảng nét đứt: di chuyển · Vùng gạch chéo: chờ đủ robot · Thanh màu: xử lý task</text>""")
end
