"""Thống kê so sánh cặp TSO/TSR trên cùng instance và nghiệm đầu."""
module ExperimentStatistics

using Statistics

export summarize_pairs, convergence_rows, write_rows

function write_rows(path::AbstractString, header::Vector{String}, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(header, ','))
        for row in rows
            println(io, join((getproperty(row, Symbol(key)) for key in header), ','))
        end
    end
    return path
end

"""Mỗi cặp gồm kết quả TSO và TSR cho cùng n, m, seed."""
function summarize_pairs(pairs)
    groups = sort!(unique([(p.n, p.m) for p in pairs]))
    rows = NamedTuple[]
    for (n, m) in groups
        group = [p for p in pairs if p.n == n && p.m == m]
        diffs = [100 * (p.tso.best_makespan - p.tsr.best_makespan) /
                 p.tso.best_makespan for p in group]
        better = count(>(1e-9), diffs)
        push!(rows, (n=n, m=m, instances=length(group),
            tso_best=minimum(p.tso.best_makespan for p in group),
            tso_mean=mean(p.tso.best_makespan for p in group),
            tsr_best=minimum(p.tsr.best_makespan for p in group),
            tsr_mean=mean(p.tsr.best_makespan for p in group),
            tso_mean_seconds=mean(p.tso_seconds for p in group),
            tsr_mean_seconds=mean(p.tsr_seconds for p in group),
            tsr_better=better,
            tsr_better_percent=100 * better / length(group),
            improvement_mean_percent=mean(diffs),
            improvement_min_percent=minimum(diffs),
            improvement_max_percent=maximum(diffs)))
    end
    return rows
end

"""Giá trị incumbent trung bình theo % makespan ban đầu, tương tự Hình 12."""
function convergence_rows(pairs; step::Int=100)
    step >= 1 || throw(ArgumentError("step phải dương"))
    rows = NamedTuple[]
    for (n, m) in sort!(unique([(p.n, p.m) for p in pairs]))
        group = [p for p in pairs if p.n == n && p.m == m]
        length(unique(length(p.tso.history) for p in group)) == 1 ||
            throw(ArgumentError("Các lịch sử phải cùng số iteration"))
        final_iteration = length(first(group).tso.history) - 1
        points = unique([collect(0:step:final_iteration); final_iteration])
        for iteration in points
            push!(rows, (n=n, m=m, iteration=iteration,
                tso_percent=mean(100 * p.tso.history[iteration + 1] /
                                 p.tso.initial_makespan for p in group),
                tsr_percent=mean(100 * p.tsr.history[iteration + 1] /
                                 p.tsr.initial_makespan for p in group)))
        end
    end
    return rows
end

end
