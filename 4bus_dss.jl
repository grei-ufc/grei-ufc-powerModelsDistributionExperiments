using PowerModelsDistribution
using Ipopt
using JuMP
using PowerPlots
using Plots

include("utils/constraint_utils.jl")
include("utils/load_data.jl")

results_path = "results/2025-04-09_solar_carga_armazenamento/"

########################
# construção de modelo #
########################

data_path = "1-MVLV-urban-5.303-1-no_sw"
load_data = get_load_data(data_path, 1, 1)

gen_data = get_gen_data(data_path, 1, 2) .* 10

eng_model = PowerModelsDistribution.parse_file("4Bus-DY-Bal/4Bus-DY-Bal.DSS")


#######################################
# adicionando série temporal de carga #
#######################################
time_indexes = collect(1:96) ./ 4

# carga ativa
pd_ts_l1 = Dict("time" => time_indexes,
                "values" => load_data.pload,
                "offset" => 0,
                "replace" => false)

# carga reativa
qd_ts_l1 = Dict("time" => time_indexes,
                "values" => load_data.qload,
                "offset" => 0,
                "replace" => false)

eng_model["time_series"] = Dict("pd_ts_l1" => pd_ts_l1, "qd_ts_l1" => qd_ts_l1)
eng_model["load"]["load1"]["time_series"] = Dict("pd_nom" => "pd_ts_l1",
                                                 "qd_nom" => "qd_ts_l1")


#########################################
# adicionando série temporal de geracao #
#########################################
gen_data_1 = []
for i in gen_data.pgen
    push!(gen_data_1, [i, 0])
end

pd_ts_g1 = Dict("time" => time_indexes,
                "values" => gen_data_1,
                "offset" => 0,
                "replace" => false)

add_solar!(eng_model,
           "pv1",
           "n4",
           configuration=WYE,
           [1, 4],
           pg=[0, 0],
           qg=[0, 0],
           pg_ub=[1100, 10],
           pg_lb=[1000, 0],
           qg_ub=[1100, 10],
           qg_lb=[-1100, -10])
eng_model["time_series"]["pd_ts_g1"] = pd_ts_g1
eng_model["solar"]["pv1"]["time_series"] = Dict("pg_ub" => "pd_ts_g1",
                                                "pg_lb" => "pd_ts_g1")

"""
#############################
# adicionando armazenamento #
#############################
add_storage!(eng_model,
             "bess_1",
             "n4",
             configuration=WYE,
             [1, 2, 3, 4],
             energy=0,
             energy_ub=200000,
             charge_ub=5000,
             discharge_ub=6000,
             sm_ub=8000,
             cm_ub=10000,
             qex=0.00001,
             pex=0.00001,
             charge_efficiency=0.99,
             discharge_efficiency=0.99,
             qs_ub=5000,
             qs_lb=-5000,
             rs=0.00001,
             xs=0.00005,
             ps=5000,
             qs=5000)

"""
#######################
# solucionando modelo #
#######################
result = solve_mn_mc_opf(eng_model, ACPUPowerModel, Ipopt.Optimizer)


########################
# avaliando resultados #
########################
line_active_power = []
line_reactive_power = []

load_active_power = []
load_reactive_power = []

solar_active_power = []
solar_reactive_power = []

bess_active_power = []
bess_reactive_power = []
bess_state = []

for i in 1:96
    # line 2
    push!(line_active_power, round(sum(result["solution"]["nw"]["$i"]["line"]["line1"]["pf"]); digits=2))
    push!(line_reactive_power, round(sum(result["solution"]["nw"]["$i"]["line"]["line1"]["qf"]); digits=2))

    # load 1
    push!(load_active_power, round(sum(result["solution"]["nw"]["$i"]["load"]["load1"]["pd"]); digits=2))
    push!(load_reactive_power, round(sum(result["solution"]["nw"]["$i"]["load"]["load1"]["qd"]); digits=2))

    # solar 1
    push!(solar_active_power, round(sum(result["solution"]["nw"]["$i"]["solar"]["pv1"]["pg"]); digits=2))
    push!(solar_reactive_power, round(sum(result["solution"]["nw"]["$i"]["solar"]["pv1"]["qg"]); digits=2))

    # bess 1
    push!(bess_active_power, round(sum(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["ps"]); digits=2))
    push!(bess_reactive_power, round(sum(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["qs"]); digits=2))
    push!(bess_state, round(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["se"]; digits=2))

end

#######################################
# plotagem de graficos para validacao #
#######################################
plot(time_indexes, load_active_power, label="Carga 1", linewidth=2)
plot!(time_indexes, solar_active_power, label="Sistema FV", linewidth=2)
plot!(time_indexes, line_active_power, label="Fluxo na Linha", linewidth=2)
p#lot!(time_indexes, bess_active_power, label="Armazenamento", linewidth=2)
title!("Potência Ativa dos Componentes")
xlabel!("Tempo (h)")
ylabel!("Potência (W)")
savefig(results_path * "potencia_ativa.png")

plot(time_indexes, load_reactive_power, label="Carga 1", linewidth=2)
plot!(time_indexes, solar_reactive_power, label="Sistema FV", linewidth=2)
plot!(time_indexes, line_reactive_power, label="Fluxo na Linha", linewidth=2)
#plot!(time_indexes, bess_reactive_power, label="Armazenamento", linewidth=2)
title!("Potência Reativa dos Componentes")
xlabel!("Tempo (h)")
ylabel!("Potência (W)")
savefig(results_path * "potencia_reativa.png")

plot(time_indexes, load_active_power .- solar_active_power, label="Balanço no nó", linewidth=2)
plot!(time_indexes, line_active_power, label="Fluxo na Linha", linewidth=2)
title!("Comparacao balanço e fluxo na linha")
xlabel!("Tempo (h)")
ylabel!("Potência (W)")
savefig(results_path * "validacao_linha.png")

"""
plot(time_indexes, bess_active_power, 
    label="Potência Ativa (W)", 
    ylabel="Potência Ativa (W)",
    legend=:topright)
plot!(twinx(), time_indexes, bess_state, 
    label="Estado do Armazenamento (Wh)", 
    color=:red,
    ylabel="Estado de Carga (Wh)",
    legend=:topleft)
title!("Potência Ativa e Estado do Armazenamento")
savefig(results_path * "estado_armazenamento_ativo.png")

plot(time_indexes, bess_reactive_power, 
    label="Potência Ativa (W)", 
    ylabel="Potência Ativa (W)",
    legend=:topright)
plot!(twinx(), time_indexes, bess_state, 
    label="Estado do Armazenamento (Wh)",
    color=:red,
    ylabel="Estado de Carga (Wh)",
    legend=:topleft)
title!("Potência Ativa e Estado do Armazenamento")
savefig(results_path * "estado_armazenamento_reativo.png")"""


###################
# plotando modelo #
###################
math_model = PowerModelsDistribution.transform_data_model(eng_model)
powerplot(math_model, show_flow=true)


##########################
# inspecionando o modelo #
##########################
pm = instantiate_mc_model(eng_model, ACPUPowerModel, build_mn_mc_opf)

mc_model = pm.model

set_optimizer(mc_model, Ipopt.Optimizer)
optimize!(mc_model)

check_violations(mc_model, 0.00002)
