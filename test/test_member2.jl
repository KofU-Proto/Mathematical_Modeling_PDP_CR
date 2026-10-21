using Test
using Random
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
using .PDPCRMember1, .PDPCRMember2

"""Ví dụ 1 trong bài báo: n = 3 task, m = 2 robot, ma trận t_ij ở Bảng 2."""
function paper_example1()
    # Node 0 = depot xuất phát, 1..3 = task, 4 = depot đích.
    T = [
        0.0 6 7 10 0
        0 0 2 7 3
        0 4 0 6 6
        0 3 4 0 9
        0 0 0 0 0
    ]
    return FlowProblem([3.0, 2.5, 2.5], [2, 1, 1], T, 2)
end

@testset "Flow-DAG: biểu diễn và Algorithm 1–2 (ví dụ 1 bài báo)" begin
    p = paper_example1()
    # Robot 1: task 2 → task 1; robot 2: task 3 → task 1 (Hình 3–4).
    s = from_routes(p, [[2, 1], [3, 1]])
    @test validate_flow_solution(s)
    @test flow(s, 2, 1) == 1 && flow(s, 3, 1) == 1 && flow(s, 1, 4) == 2
    ev = evaluate(s)
    @test ev.L[2 + 1] == 7.0          # task 2 bắt đầu lúc t_02 = 7
    @test ev.L[3 + 1] == 10.0         # task 3 bắt đầu lúc t_03 = 10
    @test ev.L[1 + 1] == 15.5         # max(9.5 + 4, 12.5 + 3): robot đi từ task 2 phải chờ
    @test ev.makespan == 21.5         # 15.5 + 3 + 3
    @test ev.Lstar[1] == ev.makespan  # L*_0 = độ dài đường dài nhất
    @test first(ev.order) == 0 && last(ev.order) == 4
    @test critical_arcs(s, ev) == [(0, 3), (1, 4), (3, 1)]
    @test sort(to_routes(s)) == [[2, 1], [3, 1]]
end

@testset "Kiểm tra tính hợp lệ" begin
    p = paper_example1()
    s = from_routes(p, [[2, 1], [3, 1]])
    broken = copy(s)
    add_flow!(broken, 2, 1, 1)                 # vi phạm bảo toàn flow
    @test !is_valid(broken)
    cyc = copy(s)
    add_flow!(cyc, 1, 4, -1); add_flow!(cyc, 1, 2, 1)   # tạo chu trình 2 → 1 → 2
    @test !is_acyclic(cyc) && !is_valid(cyc)
    @test isinf(makespan(cyc))
    @test is_valid(s)                          # nghiệm gốc không bị sửa
end

@testset "Algorithm 3 – ví dụ 3 bài báo (Cmax 24 → 22)" begin
    # Bên trái: S=0, A=1, B=2, C=3; bên phải: D=4, E=5, S'=6 (cắt tại ζ = 4).
    Δ = Dict(
        (1, 4) => 20.0, (1, 5) => 17.0,
        (2, 4) => 16.0, (2, 5) => 16.0,
        (3, 4) => 22.0, (3, 5) => 24.0,
    )
    cross = Dict((1, 4) => 4, (2, 5) => 1, (3, 5) => 2)   # π_A=4, π_B=1, π_C=2
    cmax, steps = redistribute_cut!(cross, [0, 1, 2, 3], [4, 5, 6], (i, j) -> Δ[(i, j)], 24.0)
    @test cmax == 22.0
    @test length(steps) == 1
    @test steps[1].removed_arc == (3, 5)        # (i*, j*) = (C, E)
    @test steps[1].gamma == [3, 4, 1, 5]        # Γ = (C, D, A, E)
    @test steps[1].delta == 2
    @test cross == Dict((1, 4) => 2, (1, 5) => 2, (2, 5) => 1, (3, 4) => 2)
    # π_left, π_right được giữ nguyên.
    @test sum(f for ((i, _), f) in cross if i == 1) == 4
    @test sum(f for ((_, j), f) in cross if j == 5) == 3
end

@testset "Reroute và reverse trên ví dụ nhỏ" begin
    p = paper_example1()
    s = from_routes(p, [[2, 1], [3, 1]])
    # Reroute (0,2) & (3,1): f_02, f_31 giảm; f_01, f_32 tăng (robot 2 làm 3 → 2 → 1).
    t = apply_move(s, RerouteMove(0, 2, 3, 1, 1))
    @test !isnothing(t) && is_valid(t)
    @test flow(t, 0, 1) == 1 && flow(t, 3, 2) == 1
    @test isnothing(apply_move(s, RerouteMove(0, 2, 2, 1, 1)))   # u == j → tự lặp
    @test isnothing(apply_move(s, RerouteMove(0, 2, 3, 1, 2)))   # thiếu flow
    # Reverse cung (3, 1): robot 2 làm task 1 trước task 3 — cần r_1 = 2 nên
    # một robot nữa phải tới 1; U = {0}, V = {4}.
    r = apply_move(s, ReverseMove(3, 1))
    @test !isnothing(r) && is_valid(r)
    @test flow(r, 1, 3) == 1 && flow(r, 3, 1) == 0
    @test isnothing(apply_move(s, ReverseMove(0, 3)))             # không đảo cung depot
end

@testset "Neighborhood trên instance ngẫu nhiên" begin
    redis_improved = 0
    for seed in 1:40
        rng = MersenneTwister(seed)
        inst = generate_instance(rand(rng, 6:30), rand(rng, 2:8); seed)
        sol = greedy_initial_solution(inst; seed)
        p = FlowProblem(inst)
        s = from_solution(p, inst, sol)
        @test validate_flow_solution(s)
        @test makespan(s) ≈ PDPCRMember1.makespan(inst, sol)
        # Vòng chuyển đổi Solution ↔ FlowSolution giữ nguyên flow.
        @test arcs(from_solution(p, inst, to_solution(s))) == arcs(s)

        before = arcs(s)
        config = NeighborhoodConfig(n_redis=nothing, n_reroute=15, n_reverse=10, validate=true)
        cands = generate_neighbors(s; config, rng)
        @test arcs(s) == before                      # nghiệm hiện tại không bị sửa
        for c in cands
            t = materialize(s, c)
            @test is_valid(t)
            @test c.before ≈ makespan(s)
            @test c.after ≈ makespan(t)              # makespan sau biến đổi chính xác
            @test c.after ≈ evaluate(t).makespan     # khớp Algorithm 1
            @test c.after ≈ PDPCRMember1.makespan(inst, to_solution(t))
            @test arcs(apply_move(s, c.move; rng=MersenneTwister(0))) isa Vector
            if c.move isa RedistributeMove
                @test c.after <= c.before + 1e-9     # redistribute không làm tệ hơn
                redis_improved += improvement(c) > 1e-9
            end
        end
    end
    @test redis_improved > 0
end

@testset "Cấu hình và thuộc tính tabu" begin
    @test default_config(150, :TSO).n_redis == 0
    @test default_config(150, :TSR).n_redis == 10
    @test is_tabu(RerouteMove(1, 2, 3, 4, 1), Set([(1, 4)]), Set{Int}())
    @test !is_tabu(RerouteMove(1, 2, 3, 4, 1), Set([(1, 2)]), Set{Int}())
    @test is_tabu(ReverseMove(1, 2), Set([(2, 1)]), Set{Int}())
    @test is_tabu(RedistributeMove(5), Set{Tuple{Int,Int}}(), Set([5]))
    @test removed_arcs(ReverseMove(1, 2)) == [(1, 2)]
end
