# Função para verificar violações
function check_violations(model, tol=1e-6)
    for c in all_constraints(model; include_variable_in_set_constraints=false)
        co = constraint_object(c)
        lhs_val = value(co.func)  # Valor do lado esquerdo (LHS)
        set = co.set

        if set isa MOI.LessThan{Float64}
            rhs_val = set.upper  # Valor do lado direito (RHS)
            viol = lhs_val - rhs_val
            if viol > tol
                println("Restrição: $c")
                println("Restrição $(name(c)) violada: $(lhs_val) > $(rhs_val) (violação: $(viol))")
            end

        elseif set isa MOI.GreaterThan{Float64}
            rhs_val = set.lower
            viol = rhs_val - lhs_val
            if viol > tol
                println("Restrição: $c")
                println("Restrição $(name(c)) violada: $(lhs_val) < $(rhs_val) (violação: $(viol))")
            end

        elseif set isa MOI.EqualTo{Float64}
            rhs_val = set.value
            viol = abs(lhs_val - rhs_val)
            if viol > tol
                println("Restrição: $c")
                println("Restrição $(name(c)) violada: $(lhs_val) ≠ $(rhs_val) (violação: $(viol))")
            end
        end
    end
end
