function _objective_mc_min_fuel_cost_polynomial_linquad(pm::AbstractUnbalancedPowerModel; report::Bool=true)
    gen_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum(var(pm, n, :pg, i))

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = gen["cost"][1]*pg^2 + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end
    end

    storage_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,storage) in nw_ref[:storage]
            ps = var(pm, n, :ps, i)

            if ps > 0.0
                if length(storage["cost"]) == 1
                    storage_cost[(n,i)] = storage["cost"][1]
                elseif length(storage["cost"]) == 2
                    storage_cost[(n,i)] = storage["cost"][1]*ps + storage["cost"][2]
                elseif length(storage["cost"]) == 3
                    storage_cost[(n,i)] = storage["cost"][1]*ps^2 + storage["cost"][2]*ps + storage["cost"][3]
                else
                    storage_cost[(n,i)] = 0.0
                end
            else
                storage_csot[(n,i)] = 0.0
            end
        end
    end

    return JuMP.@objective(pm.model, Min,
        sum(sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )) + 
        sum(sum( storage_cost[(n,i)] for (i,storage) in nw_ref[:storage] ))
        for (n, nw_ref) in nws(pm))
end

function hell()
    print("hell")
end
