
"gen connections adaptation of min energy cost with storage polynomial linquad objective"
function objective_mc_min_energy_cost_storage(pm::AbstractUnbalancedPowerModel; report::Bool=true)
    gen_cost = Dict()

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum(var(pm, n, :pg, i))
            pg_injection = max(0, pg)

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg_injection + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = gen["cost"][1]*pg_injection^2 + gen["cost"][2]*pg_injection + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end
    end
    total_gen_cost = sum(sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] ) for (n, nw_ref) in nws(pm))

    storage_cost = Dict()
    for (n, nw_ref) in nws(pm)
        for (i,storage) in nw_ref[:storage]
            ps = sum(var(pm, n, :ps, i))
            injection = - min(0, ps)

            if length(storage["cost"]) == 1
                storage_cost[(n,i)] = storage["cost"][1]
            elseif length(storage["cost"]) == 2
                storage_cost[(n,i)] = storage["cost"][1]*injection + storage["cost"][2]
            elseif length(storage["cost"]) == 3
                storage_cost[(n,i)] = storage["cost"][1]*injection^2 + storage["cost"][2]*injection + storage["cost"][3]
            else
                storage_cost[(n,i)] = 0.0
            end
        end
    end
   total_storage_cost = sum(sum( storage_cost[(n,i)] for (i,storage) in nw_ref[:storage] ) for (n, nw_ref) in nws(pm))

    return JuMP.@objective(pm.model, Min, total_gen_cost + total_storage_cost)
end
