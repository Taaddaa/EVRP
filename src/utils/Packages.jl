using Pkg;Pkg.activate("EVRP")
Pkg.instantiate()
using DataFrames,LinearAlgebra, Printf, Random, BSON
using Plots
include("Data_struct.jl")
include("IO.jl")
include("Eval.jl")
include("Charger_insertion.jl")
include("CW.jl")
include("ALNS.jl")
include("ALNS_funcs.jl")
# include("utils/Tests.jl")
