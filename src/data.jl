"""Dữ liệu PDP-CR, sinh instance có seed và đọc/ghi định dạng CSV."""

const Point2D = NTuple{2,Float64}

"""
Một nhiệm vụ pickup-delivery.

- `id`: mã nhiệm vụ duy nhất.
- `pickup`, `delivery`: tọa độ nhận hàng và giao hàng.
- `processing_time`: thời gian thực hiện nhiệm vụ sau khi đủ robot.
- `required_robots`: số robot phải đồng thời thực hiện nhiệm vụ.
"""
struct PDPTask
    id::String
    pickup::Point2D
    delivery::Point2D
    processing_time::Float64
    required_robots::Int

    function PDPTask(
        id::AbstractString,
        pickup::Tuple{<:Real,<:Real},
        delivery::Tuple{<:Real,<:Real},
        processing_time::Real,
        required_robots::Integer,
    )
        task_id = strip(String(id))
        isempty(task_id) && throw(ArgumentError("task_id không được để trống"))
        p = (Float64(pickup[1]), Float64(pickup[2]))
        d = (Float64(delivery[1]), Float64(delivery[2]))
        duration = Float64(processing_time)
        all(isfinite, (p..., d..., duration)) ||
            throw(ArgumentError("Tọa độ và processing_time phải hữu hạn"))
        duration >= 0 || throw(ArgumentError("processing_time không được âm"))
        required_robots >= 1 ||
            throw(ArgumentError("required_robots phải là số nguyên dương"))
        new(task_id, p, d, duration, Int(required_robots))
    end
end

"""
Một instance gồm danh sách nhiệm vụ, đội robot đồng nhất và depot chung.

Robot được đánh số `1:robot_count`; depot mặc định ở tọa độ `(0, 0)`.
"""
struct ProblemInstance
    tasks::Vector{PDPTask}
    robot_count::Int
    depot::Point2D

    function ProblemInstance(
        tasks::AbstractVector{PDPTask},
        robot_count::Integer;
        depot::Tuple{<:Real,<:Real}=(0.0, 0.0),
    )
        robot_count >= 1 || throw(ArgumentError("robot_count phải lớn hơn 0"))
        depot_point = (Float64(depot[1]), Float64(depot[2]))
        all(isfinite, depot_point) || throw(ArgumentError("Tọa độ depot phải hữu hạn"))
        ids = getfield.(tasks, :id)
        length(ids) == length(unique(ids)) ||
            throw(ArgumentError("Mã task_id phải duy nhất"))
        for task in tasks
            task.required_robots <= robot_count ||
                throw(ArgumentError(
                    "Task $(task.id) cần $(task.required_robots) robot, " *
                    "nhưng đội chỉ có $robot_count robot",
                ))
        end
        new(collect(tasks), Int(robot_count), depot_point)
    end
end

"""Khoảng cách Euclidean giữa hai điểm 2D."""
distance(a::Point2D, b::Point2D)::Float64 = hypot(a[1] - b[1], a[2] - b[2])

"""
Thời gian đi giữa hai task: từ điểm giao của `from_task` đến điểm nhận `to_task`.
"""
travel_time(from_task::PDPTask, to_task::PDPTask)::Float64 =
    distance(from_task.delivery, to_task.pickup)

"""
Sinh instance ngẫu nhiên tái lập được bằng `seed`.

Processing time bằng khoảng cách pickup-delivery; nhu cầu robot được lấy
đều từ `1` đến `min(robot_count, max_required_robots)`.
"""
function generate_instance(
    task_count::Integer,
    robot_count::Integer;
    seed::Integer=0,
    max_coordinate::Real=100.0,
    max_required_robots::Integer=5,
    depot::Tuple{<:Real,<:Real}=(0.0, 0.0),
)
    task_count >= 0 || throw(ArgumentError("task_count không được âm"))
    robot_count >= 1 || throw(ArgumentError("robot_count phải lớn hơn 0"))
    isfinite(max_coordinate) && max_coordinate > 0 ||
        throw(ArgumentError("max_coordinate phải dương và hữu hạn"))
    max_required_robots >= 1 ||
        throw(ArgumentError("max_required_robots phải lớn hơn 0"))

    rng = MersenneTwister(seed)
    demand_max = min(robot_count, max_required_robots)
    tasks = PDPTask[]
    for index in 1:task_count
        pickup = (rand(rng) * max_coordinate, rand(rng) * max_coordinate)
        delivery = (rand(rng) * max_coordinate, rand(rng) * max_coordinate)
        duration = distance(pickup, delivery)
        task_id = "T$(lpad(index, 4, '0'))"
        push!(tasks, PDPTask(task_id, pickup, delivery, duration, rand(rng, 1:demand_max)))
    end
    return ProblemInstance(tasks, robot_count; depot)
end

"""Tách một dòng CSV, hỗ trợ dấu phẩy và dấu nháy kép bên trong field."""
function parse_csv_row(line::AbstractString)
    fields = String[]
    field = IOBuffer()
    in_quotes = false
    chars = collect(line)
    index = 1
    while index <= length(chars)
        char = chars[index]
        if char == '"'
            if in_quotes && index < length(chars) && chars[index + 1] == '"'
                print(field, '"')
                index += 1
            else
                in_quotes = !in_quotes
            end
        elseif char == ',' && !in_quotes
            push!(fields, strip(String(take!(field))))
        else
            print(field, char)
        end
        index += 1
    end
    in_quotes && throw(ArgumentError("CSV có dấu nháy kép chưa đóng"))
    push!(fields, strip(String(take!(field))))
    return fields
end

"""Escape field CSV khi có dấu phẩy, dấu nháy kép hoặc xuống dòng."""
function csv_escape(value)
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text) || occursin('\r', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    return text
end

"""
Đọc instance CSV. Cột bắt buộc: task_id, pickup/delivery coordinates,
required_robots; processing_time có thể bỏ trống và sẽ lấy khoảng cách Euclidean.
"""
function load_instance(
    path::AbstractString,
    robot_count::Integer;
    depot::Tuple{<:Real,<:Real}=(0.0, 0.0),
)
    isfile(path) || throw(ArgumentError("Không tìm thấy file dữ liệu: $path"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("File CSV rỗng: $path"))

    header = parse_csv_row(replace(first(lines), "\ufeff" => ""))
    required = (
        "task_id",
        "pickup_x",
        "pickup_y",
        "delivery_x",
        "delivery_y",
        "required_robots",
    )
    missing = filter(name -> !(name in header), required)
    isempty(missing) ||
        throw(ArgumentError("Thiếu cột bắt buộc trong CSV: $(join(missing, ", "))"))
    length(header) == length(unique(header)) ||
        throw(ArgumentError("Tên cột CSV bị trùng"))
    columns = Dict(name => findfirst(==(name), header) for name in header)

    tasks = PDPTask[]
    for (row_index, line) in enumerate(lines[2:end])
        line_number = row_index + 1
        isempty(strip(line)) && continue
        try
            fields = parse_csv_row(line)
            value(column) = begin
                position = columns[column]
                position <= length(fields) ||
                    throw(ArgumentError("thiếu giá trị ở cột $column"))
                fields[position]
            end
            pickup = (parse(Float64, value("pickup_x")), parse(Float64, value("pickup_y")))
            delivery = (
                parse(Float64, value("delivery_x")),
                parse(Float64, value("delivery_y")),
            )
            processing_index = get(columns, "processing_time", nothing)
            processing_text =
                isnothing(processing_index) || processing_index > length(fields) ?
                "" : fields[processing_index]
            processing_time =
                isempty(processing_text) ? distance(pickup, delivery) : parse(Float64, processing_text)
            demand = parse(Int, value("required_robots"))
            push!(tasks, PDPTask(value("task_id"), pickup, delivery, processing_time, demand))
        catch error
            error isa InterruptException && rethrow()
            throw(ArgumentError(
                "Dữ liệu không hợp lệ tại $path, dòng $line_number: " *
                sprint(showerror, error),
            ))
        end
    end
    return ProblemInstance(tasks, robot_count; depot)
end

"""Ghi instance ra CSV; tự tạo thư mục cha nếu cần."""
function save_instance(instance::ProblemInstance, path::AbstractString)
    mkpath(dirname(abspath(path)))
    header = (
        "task_id",
        "pickup_x",
        "pickup_y",
        "delivery_x",
        "delivery_y",
        "processing_time",
        "required_robots",
    )
    open(path, "w") do io
        println(io, join(header, ','))
        for task in instance.tasks
            row = (
                task.id,
                task.pickup[1],
                task.pickup[2],
                task.delivery[1],
                task.delivery[2],
                task.processing_time,
                task.required_robots,
            )
            println(io, join(csv_escape.(row), ','))
        end
    end
    return path
end
