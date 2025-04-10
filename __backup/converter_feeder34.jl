using ExcelReaders
using DataFrames
using PowerModelsDistribution
using PowerPlots

const PMD = PowerModelsDistribution

###########################
# Definir modelo da carga #
###########################
function loadtype(s::String)
    if s == "PQ"
        return POWER
    elseif s == "I"
        return CURRENT
    else "Z"
        return IMPEDANCE
    end
end

####################
# Ler as planilhas #
####################

# linhas
line_data_path = "feeder34/line data.xls"
line_data = readxlsheet(line_data_path, "Sheet1")

# cargas distribuidas
load_data_path = "feeder34/distributed load data.xls"
load_data = readxlsheet(load_data_path, "Sheet1")

# cargas individuais
spot_load_data_path = "feeder34/spot load data.xls"
spot_load_data = readxlsheet(spot_load_data_path, "Sheet1")

# transformadores
transformers_data_path = "feeder34/Transformer Data.xls"
transformers_data = readxlsheet(transformers_data_path, "Sheet1")

# reguladores
regulator_data_path = "feeder34/Regulator Data.xls"
regulator_data = readxlsheet(regulator_data_path, "Sheet1")

# capacitores
capacitor_data_path = "feeder34/cap data.xls"
capacitor_data = readxlsheet(capacitor_data_path, "Sheet1")

# configuracao
config_data_path = "feeder34/config.xls"
config_data = readxlsheet(config_data_path, "Sheet1")

#########################
# modelando componentes #
#########################

network = PMD.Model()

# nós
nodes = unique(vcat(line_data[4:end, 1], line_data[4:end, 2]))
for node in nodes
    node_id = Int(node)
    node_id = string(node_id)
    PMD.add_bus!(network, node_id, terminals=[1, 0], grounded=[0])
end

# linhas
lines = line_data[4:end, :]
for line in eachrow(lines)
    f_bus = Int(line[1])
    f_bus = string(f_bus)
    t_bus = Int(line[2])
    t_bus = string(t_bus)
    length = line[3]
    f_connection = [1, 0]
    t_connection = [1, 0]
    PMD.add_line!(network, "line_$f_bus-$t_bus",
                  f_bus,
                  t_bus,
                  f_connection,
                  t_connection,
                  rs=fill(0.0001, 2, 2),
                  xs=fill(0.0001, 2, 2))
end

# carga distribuida
for load in eachrow(load_data)
    if load[1] in nodes
        bus_id = Int(load[1])
        bus_id = string(bus_id)
        p = (load[4] + load[6] + load[8]) / 3
        q = (load[5] + load[7] + load[9]) / 3
        config, model = split(load[3], "-")
        PMD.add_load!(network,
                      "distributed_load_$bus_id",
                      bus_id,
                      [1, 0],
                      model=loadtype(string(model)),
                      pd_nom=[p],
                      qd_nom=[q])
    end
end

# carga pontual
for load in eachrow(spot_load_data)
    if load[1] in nodes
        bus_id = Int(load[1])
        bus_id = string(bus_id)
        p = (load[3] + load[5] + load[7]) / 3
        q = (load[4] + load[6] + load[8]) / 3
        config, model = split(load[2], "-")
        PMD.add_load!(network,
                      "spot_load_$bus_id",
                      bus_id,
                      [1, 0],
                      model=loadtype(string(model)),
                      pd_nom=[p],
                      qd_nom=[q])
    end
end

# transformadores
transformer_config = replace(transformers_data[5,1], " " => "")
f_bus = 0
t_bus = 0

for line in eachrow(lines)
    println(line[4])
    if line[4] === transformer_config
        f_bus = Int(line[1])
        f_bus = string(f_bus)
        t_bus = Int(line[2])
        t_bus = string(t_bus)
    end
end

transformer_buses = [f_bus, t_bus]
transformer_connections = [[1, 0], [1, 0]]
transformer_conn_config = [WYE, WYE]
transformer_reatance = [0.048, 0.048]
transformer_resistence = [0.019, 0.019]
transformer_vm = [24.9, 4.16]
transformer_kVA = [0.5, 0.5]

PMD.add_transformer!(network,
                     "transformer_832_888",
                     transformer_buses[1],
                     transformer_buses[2],
                     transformer_connections[1],
                     transformer_connections[2],
                     configurations=transformer_conn_config,
                     xsc=transformer_reatance,
                     rw=transformer_resistence,
                     vm_nom=transformer_vm,
                     sm_nom=transformer_kVA)
