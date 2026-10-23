# Tổng hợp 50 cặp TSO/TSR trên Li & Lim LC1 theo đúng mẫu gap của luận án:
# 100 * (TSO - TSR) / TSR. Giữ các summary.csv gốc (mẫu số TSO) để đối chiếu.
using Statistics

const RESULT_ROOT = joinpath(@__DIR__, "..", "results", "member3")
const CLASSES = [(100, "2_paper_init"), (200, "4"), (300, "6"),
                 (400, "8"), (500, "10")]
const PAPER = Dict(100 => (8, 2.35), 200 => (8, 1.21),
                   300 => (7, 0.51), 400 => (9, 1.71), 500 => (8, 2.53))

function summarize_run_file(path::AbstractString)
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("CSV rỗng: $path"))
    headers = split(first(lines), ',')
    column = Dict(name => index for (index, name) in enumerate(headers))
    values = Dict{String,Dict{String,Float64}}()
    initial = Dict{String,Float64}()
    for line in lines[2:end]
        isempty(line) && continue
        fields = split(line, ',')
        source, version = fields[column["source"]], fields[column["version"]]
        results = get!(values, source, Dict{String,Float64}())
        haskey(results, version) && throw(ArgumentError("Lặp $source $version trong $path"))
        results[version] = parse(Float64, fields[column["best_makespan"]])
        start = parse(Float64, fields[column["initial_makespan"]])
        if haskey(initial, source)
            initial[source] ≈ start || throw(ArgumentError("Nghiệm đầu khác nhau: $source"))
        else
            initial[source] = start
        end
    end
    length(values) == 10 || throw(ArgumentError("Cần 10 file trong $path; có $(length(values))"))
    all(haskey(v, "TSO") && haskey(v, "TSR") for v in Base.values(values)) ||
        throw(ArgumentError("Thiếu một phiên bản TSO/TSR trong $path"))
    pairs = collect(Base.values(values))
    gap_paper = [100 * (v["TSO"] - v["TSR"]) / v["TSR"] for v in pairs]
    gap_tso = [100 * (v["TSO"] - v["TSR"]) / v["TSO"] for v in pairs]
    return (instances=length(pairs), better=count(>(1e-9), gap_paper),
            gap_paper=mean(gap_paper), gap_tso=mean(gap_tso),
            gap_min=minimum(gap_paper), gap_max=maximum(gap_paper),
            tso_mean=mean(v["TSO"] for v in pairs),
            tsr_mean=mean(v["TSR"] for v in pairs))
end

function write_comparison(output::AbstractString)
    mkpath(dirname(output))
    open(output, "w") do io
        println(io, "mode,n,instances,tsr_better,gap_paper_percent,gap_tso_percent,gap_min_percent,gap_max_percent,tso_mean,tsr_mean,paper_better,paper_gap_percent")
        for (mode, suffix) in (("sample_all_cuts", ""), ("changed_only", "_changed"))
            for (n, name) in CLASSES
                result = summarize_run_file(joinpath(RESULT_ROOT, "li_lim_lc1_$(name)$(suffix)", "runs.csv"))
                paper_better, paper_gap = PAPER[n]
                println(io, join((mode, n, result.instances, result.better,
                                  result.gap_paper, result.gap_tso, result.gap_min,
                                  result.gap_max, result.tso_mean, result.tsr_mean,
                                  paper_better, paper_gap), ','))
            end
        end
    end
    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    output = isempty(ARGS) ? joinpath(RESULT_ROOT, "li_lim_comparison.csv") : only(ARGS)
    println(write_comparison(output))
end
