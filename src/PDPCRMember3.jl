"""Thành viên 3: Tabu Search và giao diện chạy thí nghiệm PDP-CR."""
module PDPCRMember3

using Random
using ..PDPCRMember1
using ..PDPCRMember2

include("s_greedy.jl")
include("tabu_search.jl")

export TabuConfig, TabuResult, default_tabu_config, tabu_search
export s_greedy_solution, best_s_greedy_solution

end
