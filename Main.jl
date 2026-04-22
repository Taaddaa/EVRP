using DataFrames
include("utils.jl")

custumers = parse_costumers("costumers.txt")
depot= (x=18.190, y=6.320)
# typeof(depot)
speed=30
range=40
charging_time=30
charger_num=5



