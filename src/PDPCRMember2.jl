"""
PDP-CR — Thành viên 2: biểu diễn nghiệm flow-DAG và ba neighborhood
(redistribute, reroute, reverse).

Module này dùng kiểu dữ liệu của `PDPCRMember1`; nạp cả hai qua `src/PDPCR.jl`.
"""
module PDPCRMember2

using Random
using ..PDPCRMember1
import ..PDPCRMember1: makespan

include("flow_graph.jl")
include("neighborhoods.jl")   # nạp cả redistribute.jl, reroute.jl, reverse.jl

# flow_graph.jl
export FlowProblem, FlowSolution, FlowEvaluation
export flow, set_flow!, add_flow!, arcs, successors, predecessors, inflow, outflow
export from_routes, from_solution, to_routes, to_solution
export topological_order, is_acyclic, earliest_start, longest_to_sink, evaluate
export makespan, arc_length, critical_arcs, validate_flow_solution, is_valid
# neighborhoods.jl
export Move, Candidate, NeighborhoodConfig, default_config, generate_neighbors
export FlowChanges, improvement, neighborhood_name, removed_arcs, added_arcs, is_tabu
export apply_move, move_changes, materialize, try_changes, apply_changes, apply_changes!, revert_changes!
# redistribute.jl
export Cut, RedistributeMove, RedistributeResult, RedistributeStep
export cut_positions, choose_cut, split_at, cut_flows, find_gamma
export redistribute_cut!, redistribute, redistribute_changes, redistribute_neighbors
# reroute.jl / reverse.jl
export RerouteMove, reroute_neighbors, ReverseMove, reverse_neighbors

end
