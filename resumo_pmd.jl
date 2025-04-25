### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 214e3fe1-bb7d-4a16-8d43-545d92fd7f46
begin
	using Pkg
	Pkg.activate(".")
end

# ╔═╡ d9e0015c-1ebf-4ed4-84fc-91581dc68329
begin
	using PlutoUI
	imagem = LocalResource("./esquema.png")
end
	

# ╔═╡ 60618384-9814-4e87-a005-a3e9d8f7522e
begin
	using PowerModelsDistribution
	using Ipopt
end

# ╔═╡ d1c7a687-f800-4c31-a928-707da41a2c02
md"
# Modelagem de redes de distribuição utilizando PowerModelsDistribution.jl

O **PowerModelsDistribution.jl** se trata de um pacote que auxilia na modelagem e simulação de sistemas de distribuição.\


Um problema de fluxo de potência pode possuir infinitas soluções, entretanto, para determinado objetivo, como por exemplo, redução de custo operacional, existe uma solução dentre as infinitas soluções que trás o melhor valor possível para situação, quer seja um valor máximo ou um valor mínimo, respeitando as restrições do sistema. Muitas vezes essa solução pode ser encontrada através da derivação onde encontramos pontos máximos ou mínimos das funções, mas em sistemas de distribuição esses problemas geralmente são complexos, sendo necessário uma abordagem computacional.


O nome da área da matemática que lida com esse tipo de problema é a otimização. Se trata de métodos para encontrar a melhor solução possível para um problema respeitando uma série de restrições. O PowerModelsDistribution.jl foi elaborado com base em outra biblioteca chamada JuMP.jl, que é uma biblioteca mais geral de otimização. Com isso, as ferramentas fornecidas pelo PowerModelsDistribution.jl são auxiliares para construir esses problemas específicos de distribuição, como alguns problemas comuns, e formulação das variáveis da rede de forma que respeitem os modelos de fenômenos físicos, como leis de Kirchhoff, balanço de energia, etc.
"

# ╔═╡ 87ebd329-fb6e-4010-8bee-ab050cabc084
md"
# Leitura de modelos

É possível ler um modelo do tipo .DSS construído com o OpenDSS, existem varios exemplos disponíveis gratuitamente. O IEEE disponibiliza alguns modelos padrão para que novas formas de resolver problemas relacionados a rede possam ser comparáveis. O modelo que será utilizado neste material será o Standard 4-bus Cases dísponível neste [link](https://cmte.ieee.org/pes-testfeeders/resources/).


Abaixo a leitura do arquivo OpenDSS é feita e então é possível ver as características da rede.


A imagem abaixo descreve um diagrama unifilar da da rede analisada.
"

# ╔═╡ 04ee572d-2c0b-4f56-bd31-002f0ecfd109
base_model = PowerModelsDistribution.parse_file("4Bus-DY-Bal/4Bus-DY-Bal.DSS")

# ╔═╡ 00b84a98-f5ec-4642-bf37-b6cc95084651
initial_model = copy(base_model)

# ╔═╡ f30f3551-3ee9-4a1f-a31f-697264b4c421
md"
Para realizar a simulação, é necessário definir a formulação do sistema e o problema que será resolvido. A formulação desse problema em específico se trata de uma rede trifásica de corrente alternada desbalanceada com o objetivo de otimização reduzir o custo.


Uma descrição mais detalhada da formulação pode ser encontrada neste [artigo](https://ieeexplore.ieee.org/document/4153495)


Já o problema de otimização, reduzir custos pode ser representado pela equação a seguir.
"

# ╔═╡ fbded098-e9f9-4727-82c3-6e92a32d8106
md"
## **Função Objetivo**
Minimizar custo de geração:
```math
\min \sum_{k \in \mathcal{G}} c_k \cdot P_{g_k}
```
onde $c_k$ é o custo marginal do gerador $k$.

## **Restrições Principais**
1. **Balanço de Potência**:
```math
\sum_{i \in B} (S_{g_i} - S_{d_i}) = V_i \left( \sum_{j} Y_{ij} V_j \right)^*
```

2. **Limites Operacionais**:
   ```math
   \begin{aligned}
   &\mathbf{V}^\min \leq |\mathbf{V}| \leq \mathbf{V}^\max \\
   &|\mathbf{I}| \leq \mathbf{I}^\max \\
   &\mathbf{S}_g^\min \leq \mathbf{S}_g \leq \mathbf{S}_g^\max
   \end{aligned}
   ```

3. **Restrições de Segurança**:
   ```math
   \Delta \theta_{ij} \leq \Delta \theta^\max \quad \forall (i,j) \in \mathcal{B}_{ramos}
   ```
"

# ╔═╡ 000c1992-8744-42bb-8384-fd7c2babd059
# ACPUPowerModel vem de alternating current
# build_mc_opf vem de build multi conductor power flow
# IPopt é o método de otimização utilizado
result = solve_mc_model(initial_model,
						ACPUPowerModel,
						Ipopt.Optimizer,
						build_mc_opf)

# ╔═╡ 771f4fe4-99cd-4119-99f1-6838efafbdfa
md"
O resultado é retornado em um dicionário.
"

# ╔═╡ 259708bd-60fc-4c36-a20a-6af4115327bc
md"
Como se trata de um problema que não possui flexibilidade de controle, este problema em específico possui apenas uma solução, que é o resultado final do fluxo de potência. Mas é possível por exemplo identificar a potencia perdida na linha. Na formulação mencionada anteriormente o fluxo de potencia da linha se da em direção ao centro da linha, e a nomeclatora 'from' e 'to' dizem os barramentos em que a linha está conectada.

Portanto como o sinal da entrada e saida do fluxo de potência são opostos, para determinar as perdas na linha 2 basta somar a entrada e a saída.
"

# ╔═╡ 842d7d2d-94be-4022-9129-7ec24f7aa13a
begin
	line2_loss = sum(result["solution"]["line"]["line2"]["pt"] .+ result["solution"]["line"]["line2"]["pf"])
	print("A perda na linha 2 é de $line2_loss W")
end

# ╔═╡ 003a2f81-ae2f-4d10-ac96-d0a48cf1b592
md"
De forma similar é possível calcular as perdas no transformador que esta conectado entre as linhas 1 e 2
"

# ╔═╡ f5488cb4-0389-45bf-b28b-1a29152a9313
begin
	# Sinal trocado pois o transformador está entre as linhas
	tramsformer_loss = sum(.- result["solution"]["line"]["line1"]["pt"] .- result["solution"]["line"]["line2"]["pf"])
	print("As perdas no trasnformador são de $tramsformer_loss W")
end

# ╔═╡ d5d0001a-fc16-493c-88b6-3bfe91d8dbc6
md"
# Adicionando séries temporais


Para adicionar uma série temporal é necessário adicionar um novo componente no modela chamado 'time_series'. Ele funciona como um 'banco de dados' de séries temporais  existentes no sistema, e para adicionar uma série temporal no componente basta indicar qual a variável será representada por qual série temporal
"

# ╔═╡ 2306d36d-90b1-49ec-b46e-0a2e9cddacba
time_series_model = copy(initial_model)

# ╔═╡ 63fdd637-afc4-4eb2-9662-a51b4616baac
begin
	using DataFrames
	using CSV
	include("utils/load_data.jl") # funções para coletar dados
	data_path = "1-MVLV-urban-5.303-1-no_sw"
	load_data = get_load_data(data_path, 1, 1) # coleta de 1 dia de dados de carga

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
	
	time_series_model["time_series"] = (
		Dict("pd_ts_l1" => pd_ts_l1, "qd_ts_l1" => qd_ts_l1))
	time_series_model["load"]["load1"]["time_series"] = (
		Dict("pd_nom" => "pd_ts_l1", "qd_nom" => "qd_ts_l1"))

	# para lidar com séries temporais é necessário incluir multinetwork = true
	result_time_series = solve_mc_model(
		time_series_model,
		ACPUPowerModel,
		Ipopt.Optimizer,
		build_mn_mc_opf;
		multinetwork=true) 
	
end

# ╔═╡ 576577f2-a6b8-4dd2-9ffe-1a02e47f36d5
begin
	########################
	# avaliando resultados #
	########################
	line_active_power = []
	line_reactive_power = []
	
	load_active_power = []
	load_reactive_power = []
	
	bus_n4_1_voltage = []
	bus_n4_2_voltage = []
	bus_n4_3_voltage = []
	
	for i in 1:96
	    # line 2
	    push!(line_active_power, .- round(sum(result_time_series["solution"]["nw"]["$i"]["line"]["line2"]["pt"]); digits=4))
	    push!(line_reactive_power, .- round(sum(result_time_series["solution"]["nw"]["$i"]["line"]["line2"]["qt"]); digits=4))
	
	    # load 1
	    push!(load_active_power, round(sum(result_time_series["solution"]["nw"]["$i"]["load"]["load1"]["pd"]); digits=4))
	    push!(load_reactive_power, round(sum(result_time_series["solution"]["nw"]["$i"]["load"]["load1"]["qd"]); digits=4))
	
	    # bus n4
	    push!(bus_n4_1_voltage, round(result_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][1]; digits=4))
	    push!(bus_n4_2_voltage, round(result_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][2]; digits=4))
	    push!(bus_n4_3_voltage, round(result_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][3]; digits=4))
	
	end
end

# ╔═╡ 77929ffa-2198-4772-8308-47e526a88b2f
begin
	using Plots
	plot(time_indexes, load_active_power, label="Carga 1", linewidth=2)
	plot!(time_indexes, .- line_active_power, label="Fluxo na Linha", linewidth=2)
	title!("Potência Ativa dos Componentes")
	xlabel!("Tempo (h)")
	ylabel!("Potência (W)")
end

# ╔═╡ 8512c1b7-258f-4883-bd55-88a6b714524d
begin
	plot(time_indexes, bus_n4_1_voltage, label="Tensão na Fase 1", linewidth=2)
	plot!(time_indexes, bus_n4_2_voltage, label="Tensão na Fase 2", linewidth=2)
	plot!(time_indexes, bus_n4_3_voltage, label="Tensão na Fase 3", linewidth=2)
	title!("Tensão nas fases (barramento n4)")
	xlabel!("Tempo (h)")
	ylabel!("Tensão em Kv")
end

# ╔═╡ 06f99391-7b9e-4f08-8e4f-ad0f932f3c9e
md"
# Adicionando fonte fotovoltaica e baterias
Ao adicionar uma fonte fotovoltaica é necessário passar um limite inferior e um limite superior de geração, o que ja torna o problema mais complexo, onde a solução ótima se da dentro desse intervalo se adicionando essas restrições e adicionando a geração como variável de escolha. É possível tambem passar um limite superior igual ao inferior para indicar que não a margem para controle.


As baterias não possuem perdas neste estudo.
"

# ╔═╡ d2837289-71c3-4cf6-933c-cb798fd11b88
begin
	############################
	# adicionando um novo bus #
	############################
	time_series_solar_model = copy(time_series_model)
	add_bus!(time_series_solar_model,
	         "n5",
	         rg=[0.0],
	         grounded=[4],
	         status=ENABLED,
	         terminals=[1, 2, 3, 4],
	         xg=[0.0])


	##########################
	# adicionando nova linha #
	##########################
	line3 = copy(time_series_solar_model["line"]["line2"])
	line3["f_bus"] = "n3"
	line3["t_bus"] = "n5"
	time_series_solar_model["line"]["line3"] = line3
	
	
	##########################
	# adicionando nova carga #
	##########################
	add_load!(time_series_solar_model,
	          "load2",
	          "n5",
	          [1, 2, 3, 4],
	          pd_nom=[1800.0, 1800.0, 1800.0],
	          configuration=WYE,
	          status=ENABLED,
	          vm_nom=2.40178,
	          dispatchable=NO,
	          qd_nom=[871.78, 871.78, 871.78])
	time_series_solar_model["time_series"] = (
		Dict("pd_ts_l1" => pd_ts_l1, "qd_ts_l1" => qd_ts_l1))
	time_series_solar_model["load"]["load2"]["time_series"] = (
		Dict("pd_nom" => "pd_ts_l1", "qd_nom" => "qd_ts_l1"))
	
	
	# carrega um perfil de geração e mutiplica por 20
	gen_data = get_gen_data(data_path, 1, 2) .* 20

	gen_data_1 = []
	for i in gen_data.pgen
	    push!(gen_data_1, [i, 0])
	end
	
	pd_ts_g1 = Dict("time" => time_indexes,
	                "values" => gen_data_1,
	                "offset" => 0,
	                "replace" => false)
	
	add_solar!(time_series_solar_model,
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
	time_series_solar_model["time_series"]["pd_ts_g1"] = (
		pd_ts_g1)
	time_series_solar_model["solar"]["pv1"]["time_series"] = (
		Dict("pg_ub" => "pd_ts_g1", "pg_lb" => "pd_ts_g1"))

	add_solar!(time_series_solar_model,
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
	time_series_solar_model["solar"]["pv2"]["time_series"] = (
		Dict("pg_ub" => "pd_ts_g1", "pg_lb" => "pd_ts_g1"))

	#############################
	# adicionando armazenamento #
	#############################
	add_storage!(time_series_solar_model,
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
	
	add_storage!(time_series_solar_model,
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
	
	result_solar_time_series = solve_mc_model(
		time_series_solar_model,
		ACPUPowerModel,
		Ipopt.Optimizer,
		build_mn_mc_opf;
		multinetwork=true)
	
end

# ╔═╡ 4d7c68f2-5b50-4ba2-8d20-5d6c978fd3e3
begin
	########################
	# avaliando resultados #
	########################
	line_active_power_solar = []
	
	load_active_power_solar = []

	solar_active_power = []

	bess_active_power = []
	bess_reactive_power = []
	bess_state = []
	
	bus_n4_1_voltage_solar = []
	bus_n4_2_voltage_solar = []
	bus_n4_3_voltage_solar = []
	
	for i in 1:96
	    # line 2
	    push!(line_active_power_solar, .- round(sum(result_solar_time_series["solution"]["nw"]["$i"]["line"]["line2"]["pt"]); digits=4))
	
	    # load 1
	    push!(load_active_power_solar, round(sum(result_solar_time_series["solution"]["nw"]["$i"]["load"]["load1"]["pd"]); digits=4))
		
		# solar 1
	    push!(solar_active_power, .- round(sum(result_solar_time_series["solution"]["nw"]["$i"]["solar"]["pv1"]["pg"]); digits=4))

		# bess power and state
	push!(bess_active_power, round(sum(result_solar_time_series["solution"]["nw"]["$i"]["storage"]["bess_1"]["ps"]); digits=4))
	push!(bess_state, round(result_solar_time_series["solution"]["nw"]["$i"]["storage"]["bess_1"]["se"]; digits=4))

	
	    # bus n4
	    push!(bus_n4_1_voltage_solar, round(result_solar_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][1]; digits=4))
	    push!(bus_n4_2_voltage_solar, round(result_solar_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][2]; digits=4))
	    push!(bus_n4_3_voltage_solar, round(result_solar_time_series["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][3]; digits=4))
	
	end
end

# ╔═╡ 797917f5-177d-4e9c-a312-19a609e20a22
begin
	plot(time_indexes, load_active_power_solar, label="Carga 1", linewidth=2)
	plot!(time_indexes, solar_active_power, label="Sistema FV", linewidth=2)
	plot!(time_indexes, line_active_power_solar, label="Fluxo na Linha", linewidth=2)
	plot!(time_indexes, bess_active_power, label="Armazenamento", linewidth=2)
	title!("Potência Ativa dos Componentes")
	xlabel!("Tempo (h)")
	ylabel!("Potência (W)")
end

# ╔═╡ a4e9bee3-380b-4514-b3a6-d0931c609046
begin
	plot(time_indexes, bus_n4_1_voltage_solar, label="Tensão na Fase 1", linewidth=2)
	plot!(time_indexes, bus_n4_2_voltage_solar, label="Tensão na Fase 2", linewidth=2)
	plot!(time_indexes, bus_n4_3_voltage_solar, label="Tensão na Fase 3", linewidth=2)
	title!("Tensão nas fases (barramento n4)")
	xlabel!("Tempo (h)")
	ylabel!("Tensão em Kv")
end

# ╔═╡ b906c838-8a82-49b2-8e0c-ce4f5beaf4db
begin
	plot(time_indexes, solar_active_power .+ load_active_power_solar .+ bess_active_power, label="Balanço no barramento", linewidth=2)
	plot!(time_indexes, .- line_active_power_solar, label="Fluxo na Linha", linewidth=2)
	title!("Comparacao balanço e fluxo na linha")
	xlabel!("Tempo (h)")
	ylabel!("Potência (W)")
end

# ╔═╡ 5d5f566e-549a-46c3-8064-94ca1114761e
begin
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
end

# ╔═╡ 9e96c2d5-09cb-47d8-ae52-e753dcf6849c
md"
# Adicionando preços a geração
Apenas para exemplificar, será adicionado um intervalo de operação para o sistema fotovoltaico e um preço para a geração maior do que o preço da fonte de tensão. espera-se que a fonte fotovoltaica opere com menor capacidade possível, e espera-se o contrário caso a fonte fotovoltaica tenha um custo menor que o da fonte.
"

# ╔═╡ 5471c3f5-15d7-486a-a731-d43a383e21be
begin
	time_series_solar_model_high = copy(time_series_solar_model)
	time_series_solar_model_high["voltage_source"]["source"]["cost_pg_parameters"] = [0, 0]
	time_series_solar_model_high["solar"]["pv1"]["cost_pg_parameters"] = [100, 0]
	time_series_solar_model_high["solar"]["pv2"]["cost_pg_parameters"] = [100, 0]

	time_series_solar_model_high["solar"]["pv1"]["pg_lb"] = [0, 0]
	time_series_solar_model_high["solar"]["pv2"]["pg_lb"] = [0, 0]
	
	result_solar_time_series_high = solve_mc_model(
	time_series_solar_model_high,
	ACPUPowerModel,
	Ipopt.Optimizer,
	build_mn_mc_opf;
	multinetwork=true)
end

# ╔═╡ 25eb40d1-fba5-48f7-86f5-c4b1ff732f7c
begin
	########################
	# avaliando resultados #
	########################
	line_active_power_solar_high = []
	
	load_active_power_solar_high = []

	solar_active_power_high = []

	bess_active_power_high = []
	bess_reactive_power_high = []
	bess_state_high = []
	
	bus_n4_1_voltage_solar_high = []
	bus_n4_2_voltage_solar_high = []
	bus_n4_3_voltage_solar_high = []
	
	for i in 1:96
	    # line 2
	    push!(line_active_power_solar_high, .- round(sum(result_solar_time_series_high["solution"]["nw"]["$i"]["line"]["line2"]["pt"]); digits=4))
	
	    # load 1
	    push!(load_active_power_solar_high, round(sum(result_solar_time_series_high["solution"]["nw"]["$i"]["load"]["load1"]["pd"]); digits=4))
		
		# solar 1
	    push!(solar_active_power_high, .- round(sum(result_solar_time_series_high["solution"]["nw"]["$i"]["solar"]["pv1"]["pg"]); digits=4))

		# bess power and state
	push!(bess_active_power_high, round(sum(result_solar_time_series_high["solution"]["nw"]["$i"]["storage"]["bess_1"]["ps"]); digits=4))
	push!(bess_state_high, round(result_solar_time_series_high["solution"]["nw"]["$i"]["storage"]["bess_1"]["se"]; digits=4))

	
	    # bus n4
	    push!(bus_n4_1_voltage_solar_high, round(result_solar_time_series_high["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][1]; digits=4))
	    push!(bus_n4_2_voltage_solar_high, round(result_solar_time_series_high["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][2]; digits=4))
	    push!(bus_n4_3_voltage_solar_high, round(result_solar_time_series_high["solution"]["nw"]["$i"]["bus"]["n4"]["vm"][3]; digits=4))
	
	end
end

# ╔═╡ 15b85e25-7567-4b0b-9e32-13dc70752d28
begin
	plot(time_indexes, load_active_power_solar_high, label="Carga 1", linewidth=2)
	plot!(time_indexes, solar_active_power_high, label="Sistema FV", linewidth=2)
	plot!(time_indexes, line_active_power_solar_high, label="Fluxo na Linha", linewidth=2)
	plot!(time_indexes, bess_active_power_high, label="Armazenamento", linewidth=2)
	title!("Potência Ativa dos Componentes")
	xlabel!("Tempo (h)")
	ylabel!("Potência (W)")
end

# ╔═╡ 7a80f7a3-954c-48dd-9412-19daaeb0cc98
begin
	plot(time_indexes, bus_n4_1_voltage_solar_high, label="Tensão na Fase 1", linewidth=2)
	plot!(time_indexes, bus_n4_2_voltage_solar_high, label="Tensão na Fase 2", linewidth=2)
	plot!(time_indexes, bus_n4_3_voltage_solar_high, label="Tensão na Fase 3", linewidth=2)
	title!("Tensão nas fases (barramento n4)")
	xlabel!("Tempo (h)")
	ylabel!("Tensão em Kv")
end

# ╔═╡ 5ef4159e-044a-4470-affa-4f6fdff8dc16
begin
	plot(time_indexes, solar_active_power_high .+ load_active_power_solar_high .+ bess_active_power_high, label="Balanço no barramento", linewidth=2)
	plot!(time_indexes, .- line_active_power_solar_high, label="Fluxo na Linha", linewidth=2)
	title!("Comparacao balanço e fluxo na linha")
	xlabel!("Tempo (h)")
	ylabel!("Potência (W)")
end

# ╔═╡ c1634e01-9a06-4f24-88ac-9ecfce50bb59
begin
	plot(time_indexes, bess_active_power_high, 
	    label="Potência Ativa (W)", 
	    ylabel="Potência Ativa (W)",
	    legend=:topright)
	plot!(twinx(), time_indexes, bess_state_high, 
	    label="Estado do Armazenamento (Wh)", 
	    color=:red,
	    ylabel="Estado de Carga (Wh)",
	    legend=:topleft)
	title!("Potência Ativa e Estado do Armazenamento")
end

# ╔═╡ Cell order:
# ╟─d1c7a687-f800-4c31-a928-707da41a2c02
# ╟─87ebd329-fb6e-4010-8bee-ab050cabc084
# ╠═214e3fe1-bb7d-4a16-8d43-545d92fd7f46
# ╠═d9e0015c-1ebf-4ed4-84fc-91581dc68329
# ╠═60618384-9814-4e87-a005-a3e9d8f7522e
# ╠═04ee572d-2c0b-4f56-bd31-002f0ecfd109
# ╠═00b84a98-f5ec-4642-bf37-b6cc95084651
# ╟─f30f3551-3ee9-4a1f-a31f-697264b4c421
# ╟─fbded098-e9f9-4727-82c3-6e92a32d8106
# ╠═000c1992-8744-42bb-8384-fd7c2babd059
# ╟─771f4fe4-99cd-4119-99f1-6838efafbdfa
# ╟─259708bd-60fc-4c36-a20a-6af4115327bc
# ╠═842d7d2d-94be-4022-9129-7ec24f7aa13a
# ╟─003a2f81-ae2f-4d10-ac96-d0a48cf1b592
# ╠═f5488cb4-0389-45bf-b28b-1a29152a9313
# ╟─d5d0001a-fc16-493c-88b6-3bfe91d8dbc6
# ╠═2306d36d-90b1-49ec-b46e-0a2e9cddacba
# ╠═63fdd637-afc4-4eb2-9662-a51b4616baac
# ╠═576577f2-a6b8-4dd2-9ffe-1a02e47f36d5
# ╠═77929ffa-2198-4772-8308-47e526a88b2f
# ╠═8512c1b7-258f-4883-bd55-88a6b714524d
# ╟─06f99391-7b9e-4f08-8e4f-ad0f932f3c9e
# ╠═d2837289-71c3-4cf6-933c-cb798fd11b88
# ╠═4d7c68f2-5b50-4ba2-8d20-5d6c978fd3e3
# ╠═797917f5-177d-4e9c-a312-19a609e20a22
# ╠═a4e9bee3-380b-4514-b3a6-d0931c609046
# ╠═b906c838-8a82-49b2-8e0c-ce4f5beaf4db
# ╠═5d5f566e-549a-46c3-8064-94ca1114761e
# ╟─9e96c2d5-09cb-47d8-ae52-e753dcf6849c
# ╠═5471c3f5-15d7-486a-a731-d43a383e21be
# ╠═25eb40d1-fba5-48f7-86f5-c4b1ff732f7c
# ╠═15b85e25-7567-4b0b-9e32-13dc70752d28
# ╠═7a80f7a3-954c-48dd-9412-19daaeb0cc98
# ╠═5ef4159e-044a-4470-affa-4f6fdff8dc16
# ╠═c1634e01-9a06-4f24-88ac-9ecfce50bb59
