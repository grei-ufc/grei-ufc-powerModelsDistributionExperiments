using DataFrames
using CSV

"""
    get_load_data(grid_data_path::String,
                  n_days::Int=30
                  load_index::Union{Nothing, Int}=nothing)
Seleciona um perfil e lê o perfil de carga referente ao perfil selecionado.

### Input

- `grid_data_path` -- (grid_data_path::String) indica o diretório onde estão
                      os dados de carga.
- `n_days` -- (optional, default: 30) Número de dias de simulação
- `load_index` -- (optional, default: nothing) caso um valor seja passado
                  o perfil selecionado será daquele indice, caso contrario
                  será selecionado um pefil aleatório.


### Output

Dataframe com o perfil de carga ativa e reativa.
"""
function get_load_data(grid_data_path::String, n_days::Int=30, load_index::Union{Nothing, Int}=nothing)
    load_df = CSV.read(joinpath(grid_data_path, "Load.csv"), DataFrame, delim=";")[139:243, :]
    load_profile_df = CSV.read(joinpath(grid_data_path, "LoadProfile.csv"), DataFrame, delim=";")

    month_delta = 24 * 4 * n_days * 1

    if load_index !== nothing
        load = load_df[load_index % 100 + 1, :]
        start_day = 15 * 24 * 4 + month_delta
    else
        load_index = rand(1:size(load_df)[2])
        load = load_df[load_index, :]
        start_day = rand(0:n_days) * 24 * 4 + month_delta
    end

    end_day = start_day + n_days * 24 * 4

    load_p_data = load_profile_df[:, string(load.profile, "_pload")][start_day:end_day]
    load_q_data = load_profile_df[:, string(load.profile, "_qload")][start_day:end_day]

    load_p_data = load_p_data[1:(24 * 4 * n_days)]
    load_q_data = load_q_data[1:(24 * 4 * n_days)]

    load_df = Dict("pload" => load_p_data, "qload"=> load_q_data)
    load_df = DataFrame(load_df)

    return load_df

end



"""
    get_gen_data(grid_data_path::String,
                 n_days::Int=30,
                 gen_index::Union{Nothing, Int}=nothing)
Seleciona um perfil e lê o perfil de geração referente ao perfil selecionado.

### Input

- `grid_data_path` -- indica o diretório onde estão
                      os dados de geração.
- `n_days` -- (optional, default: 30) Número de dias de simulação
- `gen_index` -- (optional, default: nothing) caso um valor seja passado
                  o perfil selecionado será daquele indice, caso contrario
                  será selecionado um pefil aleatório.

### Output

Dataframe com o perfil de geração ativa e reativa.
"""
function get_gen_data(grid_data_path::String, n_days::Int=30, gen_index::Union{Nothing, Int}=nothing)
    gen_df = CSV.read(joinpath(grid_data_path, "RES.csv"), DataFrame, delim=";")[135:147, :]
    gen_profile_df = CSV.read(joinpath(grid_data_path, "RESProfile.csv"), DataFrame, delim=";")

    month_delta = 24 * 4 * n_days

    if gen_index !== nothing
        gen = gen_df[gen_index % 12 + 1, :]
        start_day = 15 * 24 * 4 + month_delta
    else
        gen_index = rand(1:size(gen_df)[2])
        gen = gen_df[gen_index, :]
        start_day = rand(0:n_days) * 24 * 4 + month_delta
    end

    end_day = start_day + n_days * 24 * 4
    
    gen_p_data = gen_profile_df[start_day:end_day, gen.profile]
    gen_p_data = (gen_p_data[1:(24 * 4 * n_days)])

    gens_df = Dict("pgen" => gen_p_data)
    gens_df = DataFrame(gens_df)

    return gens_df

end

"""
    get_spot_prices_data(grid_data_path::String,
                         n_days::Int=30,
                         spot_index::Union{Nothing, Int}=nothing)
Le dados referentes ao preço spot de energia.

### Input

- `grid_data_path` -- indica o diretório onde estão
                      os dados de carga.
- `n_days` -- (optional, default: 30) Número de dias de simulação
- `spot_index` -- (optional, default: nothing) caso um valor seja passado
                  o perfil selecionado será daquele indice, caso contrario
                  será selecionado indice aleatorio.


### Output

Dataframe com preço da energia.
"""
function get_spot_prices_data(market_data_path::String, n_days::Int=30, spot_index::Union{Nothing, Int}=nothing)
    spot_prices_df = CSV.read(joinpath(market_data_path, "Nordpool_Market_Data-3.csv"), DataFrame, delim=",")

    if spot_index !== nothing
        month_delta = 24 * n_days * 6
        start_day = (spot_index % n_days) * 24 + month_delta
        end_day = start_day + n_days * 24
    else
        month_delta = 24 * n_days * 6
        start_day = rand(0:n_days) * 24 + month_delta
        end_day = start_day + n_days * 24
    end

    spot_p_data = spot_prices_df[start_day:end_day, "SpotPriceEUR"]

    v1 = ones(4)
    spot_p_data = vcat([v1 .* x for x in spot_p_data]...)
    spot_p_data = spot_p_data[1: n_days' * 4 * n_days - 1]
    spot_df = Dict("Price" => spot_p_data)
    spot_df = DataFrame(spot_df)

    return spot_df

end