using PowerModelsDistribution
using Ipopt
using JuMP
using PowerPlots
using Plots

include("utils/constraint_utils.jl")
include("utils/load_data.jl")
results_path = "results/2025-04-09_solar_carga_armazenamento_opf/"

########################
# construção de modelo #
########################

data_path = "1-MVLV-urban-5.303-1-no_sw"
load_data = get_load_data(data_path, 1, 1)

gen_data = get_gen_data(data_path, 1, 2) .* 20

eng_model = PowerModelsDistribution.parse_file("4Bus-DY-Bal/4Bus-DY-Bal.DSS")


############################
# adicionando um novo bus #
############################
add_bus!(eng_model,
         "n5",
         rg=[0.0],
         grounded=[4],
         status=ENABLED,
         terminals=[1, 2, 3, 4],
         xg=[0.0])


##########################
# adicionando nova linha #
##########################
line3 = copy(eng_model["line"]["line2"])
line3["f_bus"] = "n3"
line3["t_bus"] = "n5"
eng_model["line"]["line3"] = line3


##########################
# adicionando nova carga #
##########################
add_load!(eng_model,
          "load2",
          "n5",
          [1, 2, 3, 4],
          pd_nom=[1800.0, 1800.0, 1800.0],
          configuration=WYE,
          status=ENABLED,
          vm_nom=2.40178,
          dispatchable=NO,
          qd_nom=[871.78, 871.78, 871.78])


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

eng_model["time_series"] = Dict("pd_ts_l1" => pd_ts_l1, "qd_ts_l1" => qd_ts_l1)
eng_model["load"]["load2"]["time_series"] = Dict("pd_nom" => "pd_ts_l1",
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
           pg_ub=[1100, 0],
           pg_lb=[1100, 0],
           qg_ub=[0, 0],
           qg_lb=[0, 0])
eng_model["time_series"]["pd_ts_g1"] = pd_ts_g1
eng_model["solar"]["pv1"]["time_series"] = Dict("pg_ub" => "pd_ts_g1",
                                                "pg_lb" => "pd_ts_g1")

add_solar!(eng_model,
           "pv2",
           "n5",
           configuration=WYE,
           [2, 4],
           pg=[0, 0],
           qg=[0, 0],
           pg_ub=[1100, 0],
           pg_lb=[1100, 0],
           qg_ub=[0, 0],
           qg_lb=[0, 0])
eng_model["time_series"]["pd_ts_g1"] = pd_ts_g1
eng_model["solar"]["pv2"]["time_series"] = Dict("pg_ub" => "pd_ts_g1",
                                                "pg_lb" => "pd_ts_g1")
                                        

#############################
# adicionando armazenamento #
#############################
add_storage!(eng_model,
             "bess_1",
             "n4",
             configuration=WYE,
             [1, 4],
             energy=40000,
             energy_ub=80000,
             charge_ub=6000,
             discharge_ub=5000,
             sm_ub=150000,
             cm_ub=1e6,
             qex=0,
             pex=0,
             charge_efficiency=100,
             discharge_efficiency=100,
             qs_ub=0,
             qs_lb=0,
             rs=0,
             xs=0)

add_storage!(eng_model,
             "bess_2",
             "n5",
             configuration=WYE,
             [2, 4],
             energy=40000,
             energy_ub=80000,
             charge_ub=6000,
             discharge_ub=5000,
             sm_ub=150000,
             cm_ub=1e6,
             qex=0,
             pex=0,
             charge_efficiency=100,
             discharge_efficiency=100,
             qs_ub=0,
             qs_lb=0,
             rs=0,
             xs=0)

#######################
# solucionando modelo #
#######################
result = solve_mc_model(eng_model, ACPUPowerModel, Ipopt.Optimizer, build_mn_mc_opf; multinetwork=true)

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

bus_n4_1_voltage = []
bus_n4_2_voltage = []
bus_n4_3_voltage = []

for i in 1:96
    # line 2
    push!(line_active_power, .- round(sum(result["solution"]["nw"]["$i"]["line"]["line2"]["pt"]); digits=4))
    push!(line_reactive_power, .- round(sum(result["solution"]["nw"]["$i"]["line"]["line2"]["qt"]); digits=4))

    # load 1
    push!(load_active_power, round(sum(result["solution"]["nw"]["$i"]["load"]["load1"]["pd"]); digits=4))
    push!(load_reactive_power, round(sum(result["solution"]["nw"]["$i"]["load"]["load1"]["qd"]); digits=4))

    # solar 1
    push!(solar_active_power, .- round(sum(result["solution"]["nw"]["$i"]["solar"]["pv1"]["pg"]); digits=4))
    push!(solar_reactive_power, .- round(sum(result["solution"]["nw"]["$i"]["solar"]["pv1"]["qg"]); digits=4))

    # bess 1
    push!(bess_active_power, round(sum(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["ps"]); digits=4))
    push!(bess_reactive_power, round(sum(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["qs"]); digits=4))
    push!(bess_state, round(result["solution"]["nw"]["$i"]["storage"]["bess_1"]["se"]; digits=4))

    # bus n4
    push!(bus_n4_1_voltage, round(result["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][1]; digits=4))
    push!(bus_n4_2_voltage, round(result["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][2]; digits=4))
    push!(bus_n4_3_voltage, round(result["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][3]; digits=4))

end

#######################################
# plotagem de graficos para validacao #
#######################################
plot(time_indexes, load_active_power, label="Carga 1", linewidth=2)
plot!(time_indexes, solar_active_power, label="Sistema FV", linewidth=2)
plot!(time_indexes, line_active_power, label="Fluxo na Linha", linewidth=2)
plot!(time_indexes, bess_active_power, label="Armazenamento", linewidth=2)
title!("Potência Ativa dos Componentes")
xlabel!("Tempo (h)")
ylabel!("Potência (W)")
savefig(results_path * "potencia_ativa.png")

plot(time_indexes, solar_active_power .+ load_active_power .+ bess_active_power, label="Balanço no barramento", linewidth=2)
plot!(time_indexes, line_active_power, label="Fluxo na Linha", linewidth=2)
title!("Comparacao balanço e fluxo na linha")
xlabel!("Tempo (h)")
ylabel!("Potência (W)")
savefig(results_path * "validacao_linha.png")


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

plot(time_indexes, bus_n4_1_voltage, label="Tensão na Fase 1", linewidth=2)
plot!(time_indexes, bus_n4_2_voltage, label="Tensão na Fase 2", linewidth=2)
plot!(time_indexes, bus_n4_3_voltage, label="Tensão na Fase 3", linewidth=2)
title!("Tensão nas fases (barramento nr)")
xlabel!("Tempo (h)")
ylabel!("Tensão em Kv")
savefig(results_path * "tensao_barramento.png")


###################
# plotando modelo #
###################
math_model = PowerModelsDistribution.transform_data_model(eng_model)
powerplot(math_model, show_flow=true)
pm = instantiate_mc_model(eng_model, ACPUPowerModel, build_mn_mc_opf, multinetwork=true)
