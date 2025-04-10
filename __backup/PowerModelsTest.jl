using PowerModels
using PowerModelsDistribution
using Plots
using JuMP
using Ipopt

const PMD = PowerModelsDistribution
const PM = PowerModels

data = PowerModelsDistribution.parse_file("case3_unbalanced.dss")

model = PMD.instantiate_mc_model(data,
                                 ACPUPowerModel,
                                 PMD.build_mc_opf)

jump_model = model.model

println("Objective Function:")
println(objective_function(jump_model))

println("Variables:")
for variable in all_variables(jump_model)
    println(variable)
end

for (F, S) in list_of_constraint_types(jump_model)
    println("Constraints of type $F in $S:")
    for con in all_constraints(jump_model, F, S)
        println("Name: ", name(con))
        println("Constraint: ", constraint_object(con))
        println("-------------------")
    end
end