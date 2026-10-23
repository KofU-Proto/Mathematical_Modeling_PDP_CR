# Xuất SVG hội tụ từ results/member3/convergence.csv, không cần package ngoài.

function read_convergence(path)
    lines = readlines(path)
    length(lines) >= 2 || throw(ArgumentError("convergence.csv không có dữ liệu"))
    rows = NamedTuple[]
    for line in lines[2:end]
        n, m, iteration, tso, tsr = split(line, ',')
        push!(rows, (n=parse(Int, n), m=parse(Int, m),
                     iteration=parse(Int, iteration),
                     tso=parse(Float64, tso), tsr=parse(Float64, tsr)))
    end
    return rows
end

function plot_group(rows, path)
    width, height = 960, 540
    left, right, top, bottom = 82, 35, 58, 72
    plot_w, plot_h = width - left - right, height - top - bottom
    max_iter = maximum(row.iteration for row in rows)
    min_percent = min(95.0, floor(minimum(min(row.tso, row.tsr) for row in rows) - 2))
    max_percent = 101.0
    min_percent < max_percent || (min_percent = max_percent - 1)
    x(v) = left + plot_w * v / max(1, max_iter)
    y(v) = top + plot_h * (max_percent - v) / (max_percent - min_percent)
    points(key) = join(("$(round(x(row.iteration); digits=1)),$(round(y(getproperty(row, key)); digits=1))"
                        for row in rows), ' ')
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $width $height\" role=\"img\" aria-label=\"TSO và TSR: makespan tốt nhất theo iteration\">")
        println(io, "<rect width=\"$width\" height=\"$height\" fill=\"white\"/>")
        println(io, "<text x=\"$left\" y=\"34\" font-family=\"sans-serif\" font-size=\"21\">Hội tụ TSO / TSR · n=$(first(rows).n), m=$(first(rows).m)</text>")
        for tick in range(min_percent, max_percent; length=6)
            yy = y(tick)
            println(io, "<line x1=\"$left\" x2=\"$(width-right)\" y1=\"$yy\" y2=\"$yy\" stroke=\"#e5e7eb\"/>")
            println(io, "<text x=\"$(left-12)\" y=\"$(yy+5)\" text-anchor=\"end\" font-family=\"sans-serif\" font-size=\"13\">$(round(tick; digits=1))%</text>")
        end
        for tick in range(0, max_iter; length=6)
            xx = x(tick)
            println(io, "<text x=\"$xx\" y=\"$(height-bottom+26)\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"13\">$(round(Int,tick))</text>")
        end
        println(io, "<line x1=\"$left\" x2=\"$left\" y1=\"$top\" y2=\"$(height-bottom)\" stroke=\"#374151\"/>")
        println(io, "<line x1=\"$left\" x2=\"$(width-right)\" y1=\"$(height-bottom)\" y2=\"$(height-bottom)\" stroke=\"#374151\"/>")
        println(io, "<polyline fill=\"none\" stroke=\"#d97706\" stroke-width=\"3\" points=\"$(points(:tso))\"/>")
        println(io, "<polyline fill=\"none\" stroke=\"#2563eb\" stroke-width=\"3\" points=\"$(points(:tsr))\"/>")
        println(io, "<text x=\"$(width÷2)\" y=\"$(height-15)\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"14\">Iteration</text>")
        println(io, "<text x=\"$(width-right-125)\" y=\"$(top+20)\" fill=\"#d97706\" font-family=\"sans-serif\" font-size=\"15\">TSO</text>")
        println(io, "<text x=\"$(width-right-65)\" y=\"$(top+20)\" fill=\"#2563eb\" font-family=\"sans-serif\" font-size=\"15\">TSR</text>")
        println(io, "</svg>")
    end
    return path
end

function plot_all(input, output_dir)
    rows = read_convergence(input)
    paths = String[]
    for (n, m) in sort!(unique([(row.n, row.m) for row in rows]))
        group = [row for row in rows if row.n == n && row.m == m]
        push!(paths, plot_group(group, joinpath(output_dir, "convergence_n$(n)_m$(m).svg")))
    end
    return paths
end

if abspath(PROGRAM_FILE) == @__FILE__
    input = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "results", "member3", "convergence.csv")
    output = length(ARGS) >= 2 ? ARGS[2] : joinpath(@__DIR__, "..", "plots", "member3")
    foreach(println, plot_all(input, output))
end
