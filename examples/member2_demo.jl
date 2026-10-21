# Minh họa phần Thành viên 2: flow-DAG + ba neighborhood.
#   julia --project=. examples/member2_demo.jl
using Random, Printf
include(joinpath(@__DIR__, "..", "src", "PDPCR.jl"))
using .PDPCRMember1, .PDPCRMember2

rng = MersenneTwister(2026)
instance = generate_instance(40, 8; seed=2026)
solution = greedy_initial_solution(instance; seed=2026)
problem = FlowProblem(instance)
s = from_solution(problem, instance, solution)
ev = evaluate(s)

println("== Nghiệm greedy dạng flow-DAG ==")
@printf("n = %d task, m = %d robot, %d cung có flow\n", problem.n, problem.m, length(arcs(s)))
@printf("makespan = %.3f (evaluator Thành viên 1: %.3f)\n", ev.makespan, makespan(instance, solution))
println("cung găng: ", critical_arcs(s, ev))

println("\n== Redistribute tại một lát cắt ==")
zeta = choose_cut(s, rng)
res = redistribute(s, zeta; ev, rng)
cross, pl, pr = cut_flows(s, res.cut)
@printf("ζ = %d: |N_left| = %d, |N_right| = %d, %d cung qua lát cắt\n",
        zeta, length(res.cut.left), length(res.cut.right), length(cross))
@printf("makespan %.3f → %.3f sau %d bước dời flow\n", res.before, res.after, length(res.steps))

println("\n== Láng giềng tốt nhất của từng neighborhood ==")
for (name, cands) in (
    "redistribute (mọi ζ)" => redistribute_neighbors(s; ev, rng),
    "reroute max,ca,δ"     => reroute_neighbors(s; ev, rng),
    "reroute max,ca"       => reroute_neighbors(s; ev, variant=:max_ca, rng),
    "reverse ca"           => reverse_neighbors(s; ev, rng),
)
    if isempty(cands)
        println(rpad(name, 22), ": không có láng giềng hợp lệ")
        continue
    end
    best = argmin(c -> c.after, cands)
    @printf("%-22s: %4d láng giềng, tốt nhất %.3f → %.3f  (%s)\n",
            name, length(cands), best.before, best.after, best.move)
end

println("\n== Leo đồi đơn giản (chỉ để minh họa; Tabu Search là phần Thành viên 3) ==")
current = s
for it in 1:30
    cands = generate_neighbors(current; config=NeighborhoodConfig(reroute_variant=:max_ca), rng)
    isempty(cands) && break
    best = argmin(c -> c.after, cands)
    best.after < best.before - 1e-9 || break
    @printf("vòng %2d: %-12s %.3f → %.3f\n", it, neighborhood_name(best.move), best.before, best.after)
    global current = materialize(current, best)
end
validate_flow_solution(current)
final_solution = to_solution(current)
@printf("Kết quả: %.3f → %.3f, nghiệm khả thi theo Thành viên 1: %s\n",
        ev.makespan, makespan(current), is_feasible(instance, final_solution))
