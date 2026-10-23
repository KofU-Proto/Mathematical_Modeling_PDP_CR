"""Đọc bản Li & Lim PDPTW dạng VRPLIB và bỏ các trường không dùng trong PDP-CR.

Mỗi pickup cùng delivery tương ứng trở thành một `PDPTask`. Depot và tọa độ
được giữ nguyên; nhu cầu robot lấy đều từ `1:max_required_robots` bằng `seed`.
"""
function load_li_lim_vrp(path::AbstractString, robot_count::Integer;
                         seed::Integer=0, max_required_robots::Integer=5)
    isfile(path) || throw(ArgumentError("Không tìm thấy file Li & Lim: $path"))
    robot_count >= 1 || throw(ArgumentError("robot_count phải dương"))
    1 <= max_required_robots <= robot_count ||
        throw(ArgumentError("max_required_robots phải từ 1 đến robot_count"))

    dimension = nothing
    name = splitext(basename(path))[1]
    section = ""
    coordinates = Dict{Int,Tuple{Float64,Float64}}()
    siblings = Dict{Int,Tuple{Int,Int}}()
    depot_ids = Int[]
    for (line_number, raw_line) in enumerate(eachline(path))
        line = strip(raw_line)
        isempty(line) && continue
        if line == "NODE_COORD_SECTION" || line == "PICKUP_AND_DELIVERY_SECTION" ||
           line == "DEPOT_SECTION" || line == "EOF"
            section = line
            continue
        end
        section == "EOF" && break
        if isempty(section)
            if startswith(line, "DIMENSION:")
                dimension = parse(Int, strip(split(line, ':'; limit=2)[2]))
            elseif startswith(line, "NAME:")
                name = strip(split(line, ':'; limit=2)[2])
            end
            continue
        end
        fields = split(line)
        if section == "NODE_COORD_SECTION"
            length(fields) == 3 || throw(ArgumentError("Tọa độ không hợp lệ dòng $line_number"))
            id = parse(Int, fields[1])
            haskey(coordinates, id) && throw(ArgumentError("Node $id bị lặp"))
            coordinates[id] = (parse(Float64, fields[2]), parse(Float64, fields[3]))
        elseif section == "PICKUP_AND_DELIVERY_SECTION"
            length(fields) == 7 || throw(ArgumentError("Cặp pickup/delivery không hợp lệ dòng $line_number"))
            id = parse(Int, fields[1])
            haskey(siblings, id) && throw(ArgumentError("Node $id bị lặp trong cặp"))
            siblings[id] = (parse(Int, fields[6]), parse(Int, fields[7]))
        elseif section == "DEPOT_SECTION"
            id = parse(Int, fields[1])
            id == -1 || push!(depot_ids, id)
        end
    end
    dimension === nothing && throw(ArgumentError("Thiếu DIMENSION"))
    length(coordinates) == dimension && length(siblings) == dimension ||
        throw(ArgumentError("Số node không khớp DIMENSION"))
    length(depot_ids) == 1 || throw(ArgumentError("Cần đúng một depot"))
    depot_id = only(depot_ids)
    haskey(coordinates, depot_id) || throw(ArgumentError("Depot không có tọa độ"))
    siblings[depot_id] == (0, 0) || throw(ArgumentError("Depot có sibling"))

    rng = MersenneTwister(seed)
    tasks = PDPTask[]
    paired = Set([depot_id])
    for pickup_id in sort!(collect(keys(siblings)))
        pickup_id == depot_id && continue
        pickup_sibling, delivery_id = siblings[pickup_id]
        delivery_id == 0 && continue
        pickup_sibling == 0 || throw(ArgumentError("Node $pickup_id có hai sibling"))
        haskey(siblings, delivery_id) && siblings[delivery_id] == (pickup_id, 0) ||
            throw(ArgumentError("Cặp $pickup_id → $delivery_id không đối xứng"))
        delivery_id != depot_id && !(pickup_id in paired) && !(delivery_id in paired) ||
            throw(ArgumentError("Node thuộc nhiều cặp"))
        pickup = coordinates[pickup_id]
        delivery = coordinates[delivery_id]
        push!(tasks, PDPTask("$(name)_$(pickup_id)", pickup, delivery,
                             distance(pickup, delivery), rand(rng, 1:max_required_robots)))
        push!(paired, pickup_id)
        push!(paired, delivery_id)
    end
    length(paired) == dimension || throw(ArgumentError("Có node không thuộc cặp pickup/delivery"))
    return ProblemInstance(tasks, robot_count; depot=coordinates[depot_id])
end
