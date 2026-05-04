using Pkg;Pkg.activate("EVRP")
Pkg.instantiate()
using DataFrames,LinearAlgebra, Printf, Random, BSON
using CairoMakie
include("Data_struct.jl")
include("IO.jl")
include("Eval.jl")
include("Charger_insertion.jl")
include("CW.jl")
include("ALNS.jl")
include("ALNS_funcs.jl")
include("../Visualize/Visualization.jl")
# include("utils/Tests.jl")
