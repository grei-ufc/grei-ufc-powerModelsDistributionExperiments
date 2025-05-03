"converts engineering storage into mathematical storage"
function _map_eng2math_storage!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    for (name, eng_obj) in get(data_eng, "storage", Dict{Any,Dict{String,Any}}())
        math_obj = _init_math_obj("storage", name, eng_obj, length(data_math["storage"])+1; pass_props=pass_props)

        math_obj["storage_bus"] = data_math["bus_lookup"][eng_obj["bus"]]
        math_obj["configuration"] = get(eng_obj, "configuration", WYE)

        math_obj["energy"] = eng_obj["energy"]
        math_obj["energy_rating"] = eng_obj["energy_ub"]
        math_obj["charge_rating"] = eng_obj["charge_ub"]
        math_obj["discharge_rating"] = eng_obj["discharge_ub"]
        math_obj["charge_efficiency"] = eng_obj["charge_efficiency"] / 100.0
        math_obj["discharge_efficiency"] = eng_obj["discharge_efficiency"] / 100.0
        math_obj["thermal_rating"] = get(eng_obj, "sm_ub", Inf)
        math_obj["qmin"] = eng_obj["qs_lb"]
        math_obj["qmax"] = eng_obj["qs_ub"]
        math_obj["r"] = eng_obj["rs"]
        math_obj["x"] = eng_obj["xs"]
        math_obj["p_loss"] = eng_obj["pex"]
        math_obj["q_loss"] = eng_obj["qex"]
        math_obj["cost"] = eng_obj["cost"]

        math_obj["ps"] = get(eng_obj, "ps", 0.0)
        math_obj["qs"] = get(eng_obj, "qs", 0.0)

        math_obj["control_mode"] = control_mode = Int(get(eng_obj, "control_mode", FREQUENCYDROOP))
        bus_type = data_math["bus"]["$(math_obj["storage_bus"])"]["bus_type"]
        data_math["bus"]["$(math_obj["storage_bus"])"]["bus_type"] = _compute_bus_type(bus_type, math_obj["status"], control_mode)
        if control_mode == Int(ISOCHRONOUS) && math_obj["status"] == 1
            data_math["bus"]["$(math_obj["storage_bus"])"]["va"] = [0.0, -120, 120, zeros(length(data_math["bus"]["$(math_obj["storage_bus"])"]) - 3)...][data_math["bus"]["$(math_obj["storage_bus"])"]["terminals"]]
        end

        data_math["storage"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => "storage.$(math_obj["index"])",
            "unmap_function" => "_map_math2eng_storage!",
        ))
    end
end