### A Pluto.jl notebook ###
# v0.16.3

using Markdown
using InteractiveUtils

# ╔═╡ 762cef5a-15ba-11ec-28ab-53ab54299fd6
begin
	using Images
	using ImageIO
	using ImageFiltering
	using ImageFeatures
	using Statistics
	using ImageMorphology
	using ImageBinarization
	using PyCall
	using Conda
	using ImageDraw
    using CoordinateTransformations
end

# ╔═╡ beb2d2ef-ce1a-4c09-a7aa-0a3a8d720ac2
md"""
### Entrega mac0468
#### Gabriel Baraldi NUSP: 10336553
"""

# ╔═╡ f92a33ce-414e-4201-a340-59e82afc8c11
md"""
### Introdução
"""

# ╔═╡ 4349264f-1971-4068-a231-6d650f688f14
md"""
Eu decidi fazer a entrega na linguagem Julia, usando um formato chamado notebook [Pluto](https://github.com/fonsp/Pluto.jl), ele é similar a um notebook Jupyter, mas é escrito em julia e é reativo, ou seja, alterar uma célula altera as células que dependem nele. Além disso ele gera documentos muito bonitos.
A linguagem julia soluciona o problema das duas linguagens, ela permite abstrações como python, mas é tão rápida quanto C/C++, permitindo o uso de loops for normalmente, o que facilita a implementação de algumas coisas.


As instruções para rodar esse notebook estão a seguir:
- Navegar para o site [https://julialang.org/downloads/](https://julialang.org/downloads/)
- Baixar e instalar conforme as instruções dadas no site.
- Abrir o programa da linguagem, ele deve abrir um terminal.
- Neste terminal apertar a tecla `]`, deve mudar a cor do prompt, após isso digitar `add Pluto`, deve demorar um pouco para ele baixar as dependencias. Ao terminar aperte o backspace para voltar para o terminal normal
- De volta ao terminal normal digite `using Pluto` e de enter e depois digite `Pluto.run()`
- Isso deve abrir a interface do notebook no navegador, nela existe a opção `Open from File`, nela navegue até o arquivo `.jl` que acompanha este PDF. Isso vai abrir o notebook, é possível que demore para rodar de inicio, pois ele precisará compilar as funções e baixar as dependencias necessárias para rodar o notebook
"""

# ╔═╡ 239b6397-ef7d-4edc-bf0c-035c7bcfe74f
md"""
Esse notebook tem o propósito de desenvolver um método de ler automáticamente os códigos das páginas de provas usando ferramentas de visão computacional. Foram estudadas algumas opções de como fazer essa leitura e as opções estão descritas abaixo.
"""

# ╔═╡ c5538fbb-6f5d-4e06-ab75-ab017b3aceb0
md"""
#### Importando as biblitecas de julia e de python necessárias
"""

# ╔═╡ 75096176-2f71-439d-b653-36f7a681af5d
Conda.add("opencv")
#Rodar essa célula uma vez só

# ╔═╡ 4fbca8d8-2ed9-4e9f-bdb5-c5decc7d794b
cv2 = pyimport("cv2")

# ╔═╡ 59943fdb-9f3c-4d05-b1cf-8d5b2861e0ef
np = pyimport("numpy")

# ╔═╡ 439a8461-1d00-4eab-908d-0ab41b00ccbb
md"""
As funções a seguir são um método genérico que, dado pontos os pontos que algum algoritmo devolveu como sendo os circulos a serem identificados, retorna os códigos ou dá erro se o numero de verificação não bate.
"""

# ╔═╡ ba77f21a-d657-4365-882c-e028882a7b30
md"""
#### Funções do método genérico
"""

# ╔═╡ ca98da5a-1e7a-4cbf-a32c-7fb2c69aba94
md"""
Isso é um struct simples para agrupar os resultados
"""

# ╔═╡ 2cccd021-f246-4161-8fe4-67c812e356c2
struct Prova{T}
	number::Int
	page::Int
	code::Int
	nusp::T
end

# ╔═╡ efe4c427-6479-486b-9f9d-c43c8d114256
md"""
Distância entre dois pontos
"""

# ╔═╡ 84cc71ad-4aad-47b9-a11b-d630e852402c
dist(pt1,pt2) = sqrt((pt1[1]-pt2[1])^2 + (pt1[2]-pt2[2])^2)

# ╔═╡ 92716939-5ca1-4729-a157-6620bc46d8b9
md"""
Esta função dado os pontos interessantes, acha os do canto superior esquerdo e direito usando uma heurística simples que escolhe os pontos mais proximos dos cantos superiores sendo suscetivel a falsos positivos
"""

# ╔═╡ 334a15d8-578d-458a-8d5d-43c4194a13cc
begin
	function find_top_points(points,img)
		if length(points) < 4
			throw(ErrorException("Não foram encontrados keypoins suficientes"))
		end
		super_esq = argmin(x-> dist(x,(1,1)),points)
		super_dir = argmin(x-> dist(x,(1,size(img)[2])),points)
		super_esq,super_dir
	end
end

# ╔═╡ bab46def-766c-4234-9730-e9b49c60ca0c
md"""
As próximas funcões encontram os cantos dos códigos dando os valores x, y e w do ponto do canto superior esquerdo
"""

# ╔═╡ 851ed1d9-27ae-42c0-bd42-10b97d0fbe0a
begin
	codinf_cantosupesq(x,y,w) = ceil(Int,x+ w * 0.259), ceil(Int,y+ w * -0.0208)
	codinf_cantoinfdir(x,y,w) = ceil(Int,x+ w * 0.474), ceil(Int,y+ w * -0.0032)
end

# ╔═╡ 07d4b3f5-1ee8-4a9c-8d04-a52e76938b33
begin
	nuspcantosupesq(x,y,w) = ceil(Int,x+ w * 0.0456), ceil(Int,y+ w * 0.111)
	nuspcantoinfdir(x,y,w) = ceil(Int,x+ w * 0.2484), ceil(Int,y+ w * 0.4049)
end

# ╔═╡ bd563de1-729c-492b-bcba-3040109899d5
begin
	codsup_cantosupesq(x,y,w) = ceil(Int,x+ w * 0.259), ceil(Int,y+ w * -0.0435)
	codsup_cantoinfdir(x,y,w) = ceil(Int,x+ w * 0.474), ceil(Int,y+ w * -0.0258)
end

# ╔═╡ d21bdc84-fcb7-4b9e-a3dd-5d87a18c4452
md"""
Estas funções encontram o local dos códigos diretamente a partir dos keypoints e da imagem
"""

# ╔═╡ 92d7f269-096c-45bf-80b4-fc45a5b10599
md"""
Essa função lê a imagem e a partir dela o número USP, ela faz isso separando cada digito em um pedaço e tirando a média desse digito e, coluna por coluna, vai escolhendo o com o menor média(mais escuro).
"""

# ╔═╡ c8ef8326-9e59-4111-b196-2706c6252de1
md"""
Essa função lê a imagem e le os códigos e verifica se são validos. A leitura dos códigos é feita de uma maneira simples, são identificados os quadrados individuais e verificados tirando a média dos pontos e vendo se eles são pretos ou brancos.
"""

# ╔═╡ 601df038-efe1-412f-8483-d16db47f885d
function ler_codigo(codigo)
	codigo2 = zeros(Bool,12)
	for i in 1:12
		digitoini1 = round(Int,size(codigo)[2]/12*(i-1))+1
		digitofim1 = round(Int,size(codigo)[2]/12*i)
		codigo2[i] = Float64(mean(codigo[:,digitoini1:digitofim1])) < 0.5
	end
	codigo2
end

# ╔═╡ b259605f-9a7c-4b27-8653-c5769c569ebe
md"""
Essa função transforma um vetor de bools em um número
"""

# ╔═╡ fe8bf5ed-ffd0-4e5c-9a99-f219a187ae47
decode(x) = mapreduce(i->x[i] << (lastindex(x)-i), +, eachindex(x))

# ╔═╡ 26201faa-40ca-4ea1-9318-ddadef24b0d9
md"""
Essa combina tudo e retorna a pagina lida.
"""

# ╔═╡ c57cb67b-a279-4426-8b57-1cf1ba259ac1
md"""
### Simple Blob OpenCV
O primeiro métdo de achar os keypoints é o simple\_blob\_detector do OpenCV. Como preparação da imagem foram realizadas as operações morfológicas close e open da biblioteca ImageMorphology.jl. Elas reduzem o ruidos do tipo salt and pepper o que torna os circulos mais sólidos, facilitando a sua detecção.
"""

# ╔═╡ dca6e824-e22d-4da3-a64d-2ece636234e9
md"""
### Laplacian of Gaussian
A função a seguir usa um Kernel do tipo Laplacian of Gaussian para escolher os pontos mais importantes da imagem e colocar no leitor de pontos genérico. Essa função é mais lenta que a simple\_blob\_detect e é um método menos robusto
"""

# ╔═╡ 601f6e06-c47a-4bf7-bea1-e04c16693415
function keypoints_LoG(img)
	sigma = 16
	kernel = Kernel.LoG(sigma)
	filtered = Float64.(imfilter(img, kernel).*sigma^2)
	indices = CartesianIndices(filtered)[(sortperm(vec(filtered), rev = true))]
	
	points = Vector{CartesianIndex{2}}()
	push!(points,indices[1])
	
	for i in indices
		if length(points) >= 8
			break
		end
		if minimum(dist.(points,(i,))) > 500
			push!(points,i)
		end
	end
	return points
end

# ╔═╡ 52ef5cb4-f2b8-46ce-bead-10c6f12e478b
md"""
Conversão de objetos do python para o julia, isso é necessário pois foi utilizada a biblioteca PyCall para chamar o openCV pelo python. Isso foi feito pois a biblioteca OpenCV do julia não está funcionando corretamente.
"""

# ╔═╡ 10400e43-0646-49dc-99ae-c0aa11564fbd
begin
	point(keypoint::PyObject) = (keypoint.pt[2],keypoint.pt[1])
	point(keypoint) = keypoint
	point(keypoint::CartesianIndex{2}) = (keypoint[1],keypoint[2])
end

# ╔═╡ 483c2d4d-d5f8-4e1f-ac8d-64e1dce4e5f2
function localnusp(keypoints, img)
	points = point.(keypoints)
	point1, point2 = find_top_points(points,img)
	w = dist(point1,point2)
	x = point1[2]
	y = point1[1]
	nuspcantosupesq(x,y,w),nuspcantoinfdir(x,y,w)
end

# ╔═╡ 1cfb9bf5-0ded-4a92-9c29-398d9c8efb77
function localcodsup(keypoints, img)
	points = point.(keypoints)
	point1, point2 = find_top_points(points,img)
	w = dist(point1,point2)
	x = point1[2]
	y = point1[1]
	codsup_cantosupesq(x,y,w),codsup_cantoinfdir(x,y,w)
end

# ╔═╡ b0311d12-1562-46a8-9e28-46d1cbe49c6d
function localcodinf(keypoints, img)
	points = point.(keypoints)
	point1, point2 = find_top_points(points,img)
	w = dist(point1,point2)
	x = point1[2]
	y = point1[1]
	codinf_cantosupesq(x,y,w),codinf_cantoinfdir(x,y,w)
end

# ╔═╡ fdc2beae-8f23-41ec-8f48-d359159f5d6b
function ler2codigos(keypoints,img)
	csesup, cidsup = localcodsup(keypoints,img)
	codigosup = img[csesup[2]:cidsup[2],csesup[1]:cidsup[1]]
	sup = ler_codigo(codigosup)
	cseinf, cidinf = localcodinf(keypoints,img)
	codigoinf = img[cseinf[2]:cidinf[2],cseinf[1]:cidinf[1]]
	inf = ler_codigo(codigoinf)
	numeroprova = decode(sup)
	pag = decode(inf[1:6])
	numver = decode(inf[7:12])
		if numver != (60 - ((numeroprova−1)*4+(pag−1))%60)
			throw(ErrorException("código invalido"))
		end
	return numeroprova,pag,numver
end

# ╔═╡ db550d42-7591-4311-8019-ff3abf484691
julopencv(x) = UInt8.(reinterpret(UInt8,N0f8.(x)))

# ╔═╡ eb60f6f0-3978-4fc5-bcb6-a664ae3179f0
function keypoints_ocv(img,detector)
	imgocv = julopencv(img)
	keypoints = detector.detect(imgocv)
	return keypoints
end

# ╔═╡ 9b618cde-d420-40e9-8c4c-4a791795e363
opencvtojulia(x) = a = BGR.(reinterpret.(N0f8,x[:,:,3]),reinterpret.(N0f8,x[:,:,2]),reinterpret.(N0f8,x[:,:,1]))

# ╔═╡ f9a44691-ecab-462c-bf1d-3a6f9ff2a443
md"""
#### Exemplo de imagem no notebook
"""

# ╔═╡ dfa22931-c5ae-4d5b-a298-474d3180d63a
begin
	alg = AdaptiveThreshold(window_size = 500)
	img1 = binarize(1 .-Gray.(load("scans/mac2166-t8.PDF-page-001-000.pbm")), alg)
end

# ╔═╡ f91b498e-2af3-423b-a8d6-9d711ad9d086
function ler_nusp(keypoints,img)
	cse,cid = localnusp(keypoints,img)
	codigo = img1[cse[2]:cid[2],cse[1]:cid[1]]
	temp = zeros(10)
	codigos = zeros(Int,8)
	for coluna in 1:8
		for linha in 1:10
			digitoini1 = round(Int,size(codigo)[2]/8*(coluna-1))+1
			digitofim1 = round(Int,size(codigo)[2]/8*coluna)
			digitoini2 = round(Int,size(codigo)[1]/10*(linha-1))+1
			digitofim2 = round(Int,size(codigo)[1]/10*linha)
			temp[linha] = mean(codigo[digitoini2:digitofim2,digitoini1:digitofim1])
		end
		codigos[coluna] = argmin(temp) - 1
	end
	return string(codigos...)
end

# ╔═╡ 2e88b0d3-e8d6-43ee-85aa-b484d8f76d83
function ler_prova(keypoints,img)
	num,pag,ver = ler2codigos(keypoints,img)
	if pag == 1
		nusp = ler_nusp(keypoints,img)
	else
		nusp = ""
	end
	return Prova(num,pag,ver,nusp)
end

# ╔═╡ 14395c27-c8cc-4c6f-a598-9a7c4b9f3530
function ler_prova_ocv(caminho,detector)
	@show caminho
	alg = AdaptiveThreshold(window_size = 500)
	img = binarize(1 .- Gray.(load(caminho)), alg)
	img1 = opening(closing(img))
	keypoints = keypoints_ocv(img1, detector)
	return ler_prova(keypoints,img)
end

# ╔═╡ e9d1f063-6bfd-462a-84b2-57d361919233
function ler_prova_LoG(caminho)
	@show caminho
	alg = AdaptiveThreshold(window_size = 500)
	img = binarize(1 .- Gray.(load(caminho)), alg)
	img1 = opening(closing(img))
	keypoints = keypoints_LoG(img1)
	return ler_prova(keypoints,img)
end

# ╔═╡ a65b546b-690b-4983-a1a5-216f31048702
typeof(1 .-Gray.(load("scans/mac2166-t8.PDF-page-001-000.pbm")))

# ╔═╡ f9e807c3-91c4-4e6d-b4bc-7bcb95e5a232
typeof(img1)

# ╔═╡ 4115e028-8c02-4797-9b16-a4892c216c52
md"""
##### Exemplo de como o processo acontece:
Primeiro é criado o detector do openCV, e são detectados os keypoints
"""

# ╔═╡ 8b7c857e-09c4-4ac2-9e3d-b38de62cb518
begin
	params = cv2.SimpleBlobDetector_Params()
	# Change thresholds
	params.minThreshold = 50
	params.maxThreshold = 250
	# Filter by Area.
	params.filterByArea = true
	params.minArea = 2000
	# Filter by Circularity
	params.filterByCircularity = true
	params.minCircularity = 0.84
	# Filter by Convexity
	params.filterByConvexity = true
	params.maxConvexity = 1
	# Filter by Inertia
	params.filterByInertia = false
	params.minInertiaRatio = 0.01
end

# ╔═╡ 44c6d7e2-89ba-4899-9e0c-036a73e27909
detect = cv2.SimpleBlobDetector_create(params)

# ╔═╡ 06f0956c-2f25-40bb-9436-314fdaecf574
img = julopencv(opening(closing(img1)));

# ╔═╡ 0cbfe6f0-fde1-430f-a68a-67ffef15285c
md"""
#### Keypoints Identificados
"""

# ╔═╡ 07bfb43f-8f00-4768-ad73-cf1b6c5022e5
md"""
##### Com os keypoints identificamos a região do NUSP na imagem
"""

# ╔═╡ 26d74ab9-9cad-4fc5-b902-5b2e92faffd0
md"""
##### Com o nusp selecionado temos de selecionar colula por coluna e depois linha por linha, assim lendo o código
"""

# ╔═╡ c5854a35-9483-464b-a4a7-85aaae4fcaac
md"""
###### A célula abaixo lê uma imagem do disco e acha as suas informações usando o método simple\_blob\_detect do OpenCV
"""

# ╔═╡ 70e7d260-1cea-488b-836e-abc7fe9fb691
ler_prova_ocv("scans/mac2166-t8.PDF-page-001-000.pbm",detect)

# ╔═╡ eeb7f7c9-f8ce-4342-ade2-6dc4da82bace
# ler_prova_ocv.(readdir("scans", join = true)[1:end],detect) 
# Esta célula demora para rodar portanto está comentada, ela roda o diretório inteiro

# ╔═╡ 404d28c9-f74c-4bbc-96ae-d13af0355887
md"""
###### Esta identifica a página, mas usando o método Laplacian of Gaussian
"""

# ╔═╡ 64b02891-d0ca-4354-9f98-8c7dfd697398
# ler_prova_LoG.(readdir("scans", join = true)[152:end])

# ╔═╡ bbd1cf52-74d8-4124-9183-09ee6b4a6382
md"""
## Conclusões scan:

Os métodos descritos tem mais de 98% de precisão quando avaliando as provas escaneadas com bastante precisão, o que é esperado, pois elas tem boa qualidade, constraste e estão bastante alinhadas com os eixos da imagem. O maior desafio foi ajustar os parâmetros de cada um dos algoritmos desenvolvidos, principalmente o Laplacian of Gaussian se mostrou muito sensível a escolha de seus parâmetros.
"""

# ╔═╡ 61be6c71-ae18-42aa-a6dc-2d2ba9ffc878
md"""
#### Processando imagens do scan2
Para processar essas imagens é necessário fazer um tratamento prévio.

- A primeira coisa a ser feita é um thresholding, foi utilizado o algoritmo de thresholding adaptativo descrito neste  [artigo](https://doi.org/10.1080/2151237x.2007.10129236) . A implementação utilizada é a da biblioteca ImageBinarization.jl.
- Depois é verificada se a imagem tem seu tamanho horizontal maior que o vertical e, se sim, ela é rotacionada 90 graus.
- Com a imagem rotacionada usamos o mesmo método de encontrar os pontos usando o simpleblobdetection do openCV precedido de uma operação de fechamento e uma de abertura. 
- Com esses pontos é utilizada uma heuristica simples para que assume que o ponto mais próximo do canto superior esquerdo é o ponto correto desta posição, o ponto mais próximo dele é avaliado como canto superior direito, e o terceiro ponto mais próximo é o canto inferior esquerdo. A partir destes pontos é construida uma AffineMap, que rotaciona e altera a imagem para a posição correta.
- É assumido que os pontos estão nos lugares corretos e a partir dessa imagem e dos keypoints da `img1` o algoritmo descrito na parte 1 é utilizado. Como a heurística de escolha de pontos é suscetível a falhas, são testadas também outras combinações possíveis de pontos para ver see algum tem sucesso. 

Para algumas imagens o método não funciona, as falhas são devido ao fato de que as bolinhas não foram identificadas, e isso acontece geralmente pois o thresholding não foi bom o suficiente.
"""

# ╔═╡ 3ef5e51a-13da-4892-a8f9-153944283386
md"""
##### Exemplo de imagem do scan2
"""

# ╔═╡ 2f1fd839-8b1c-4800-ab45-2f3dc141f056
img10 = binarize(Gray.(load("scans2/amc021.jpg")), alg)

# ╔═╡ 9089b195-350b-4642-bbe8-da0b5693d0e0
img5 = imresize(ifelse.(isnan.(img10),Gray(1.),img10),size(img1));

# ╔═╡ 9d710335-bb66-4287-b40d-f750aa3eef15
md"""
Parametros do detector
"""

# ╔═╡ a41af8c5-92ee-494b-a7f9-31dfd0599afd
begin
	params2 = cv2.SimpleBlobDetector_Params()
	# Change thresholds
	params2.minThreshold = 30
	params2.maxThreshold = 300
	# Filter by Area.
	params2.filterByArea = true
	params2.minArea = 900
	# Filter by Circularity
	params2.filterByCircularity = true
	params2.minCircularity = 0.80
	
	params2.maxCircularity = 1
	# Filter by Convexity
	params2.filterByConvexity = false
	params2.minConvexity = 0.98
	params2.maxConvexity = 1
	# Filter by Inertia
	params2.filterByInertia = false
	params2.minInertiaRatio = 0.8
end


# ╔═╡ 3d37a078-3b26-4700-b7ba-7f68994f7eac
begin
	img4 = opening(closing(dilate(dilate(img5))))
	img6 = julopencv(img4)
end;

# ╔═╡ 264960d4-5a6b-4dc2-b711-11b74b400c2b
detect2 = cv2.SimpleBlobDetector_create(params2)

# ╔═╡ fc602db2-bbf4-4953-a7bd-51c18c91b67c
keypoints = detect2.detect(img)

# ╔═╡ a48cf337-33e3-4254-9136-d14d155b6cb1
img2 = RGB.(img1); for key in keypoints 
	img2[clamp.(floor(Int,key.pt[2])-20:floor(Int,key.pt[2])+20,1,4680),clamp.(floor(Int,key.pt[1]-20):floor(Int,key.pt[1])+20,1,3310)] .= RGB(1,0,0); end

# ╔═╡ 84ad3be7-9889-4853-8f84-e495e29f7233
img2

# ╔═╡ 86e86062-bbab-421a-a3d2-ec23ade63b37
cse,cid = localnusp(keypoints,img1)

# ╔═╡ 486e7b73-14a5-4f2f-8706-39dd27d896f4
begin
	img3 = RGB.(img1)
	img3[cse[2]:cid[2],cse[1]:cid[1]] .= RGB(1,0,0)
	img3
end

# ╔═╡ 12d74c0d-973f-4974-8d23-33bbc7e84827
nusp = img1[cse[2]:cid[2],cse[1]:cid[1]]

# ╔═╡ 18c5c634-089d-46f6-aca1-9d98c1589152
begin
	coluna = 1
	linha = 1
	digitoini1 = round(Int,size(nusp)[2]/8*(coluna-1))+1
	digitofim1 = round(Int,size(nusp)[2]/8*coluna)
	digitoini2 = round(Int,size(nusp)[1]/10*(linha-1))+1
	digitofim2 = round(Int,size(nusp)[1]/10*linha)
	nusp[:,digitoini1:digitofim1]
	# nusp[digitoini2:digitofim2,digitoini1:digitofim1]
end

# ╔═╡ 30071e79-cfef-4296-b509-a1222c780f1a
nusp[digitoini2:digitofim2,digitoini1:digitofim1]

# ╔═╡ 242dd1f8-9840-4771-bfb3-7e21d0ce9213
keypoints4 = (detect2.detect(img6))

# ╔═╡ d8a7843e-d4a0-4d3a-80c5-a146138bf488
md"""
Imagem com os blobs detectados
"""

# ╔═╡ 22986f2d-ff92-4dab-a7d7-249701858c66
md"""
Vamos tentar achar, dados os keypoints da imagem, os pontos equivalentes ao canto superior esquerdo, direito, e o canto inferior esquerdo.
"""

# ╔═╡ 8de68341-6577-4e74-a76f-9350096834e2
function chutes(points)
	chute1 = findmin(x->dist((1,1),x),points)[2]
	chutetemp = argmin(dist.((points[chute1],),points[(1:4).!=chute1]))
	if chute1 == 1
		chutetemp = chutetemp +1
	elseif chute1 == 2
		chutetemp = ifelse(chutetemp == 1, 1, chutetemp+1)
	elseif chute1 == 3
		chutetemp = ifelse(chutetemp <= 2, chutetemp, 4)
	else
		chutetemp = chutetemp 
	end
	chute3t = argmin(x->dist(points[chute1],x),points[[x != chutetemp && x != chute1 for x in 1:4]])
	chute3 = findfirst((chute3t,) .== points)
	return (chute1,chutetemp,chute3)
end

# ╔═╡ bc76a4b3-39de-4295-8523-85fdd1a4d714
md"""
Assumindo que os pontos foram escolhidos corretamente, criamos um AffineMap para corrigir a rotação da prova
"""

# ╔═╡ 048b9aea-0e9f-4b44-b69f-075bcc15aec2
function getaffinetransform(fixed_points,moving_points)
	X = permutedims(hcat(map(x -> [x..., 1.0], moving_points)...))
	Y = hcat(map(x -> x[1], fixed_points), map(x -> x[2], fixed_points))
	c = X \ Y
	c = c'
	A = c[1:2, 1:2]
	b = c[:, 3]
	f = AffineMap(A, b)
end

# ╔═╡ b5138607-37e9-417d-9dfb-a0601bd293ac
md"""
##### Imagem com a rotação corrigida
"""

# ╔═╡ af11c265-efdd-4eba-a5cf-d6b69cc52ac2
md"""
Com a rotação da prova corrigida é questão de chamar a função de identificação de prova definida anteriormente
"""

# ╔═╡ cde60a3f-996a-4c2f-b645-f5b965d5fbd3
function trychute(chute,points,mpoints,img,keypoints)
	fixed_points = points[[chute...]]
	f = getaffinetransform(fixed_points,mpoints)
	imgw = warp(img, f,axes(img))
	img8 = ifelse.(isnan.(imgw),Gray(1.),imgw)
	return ler_prova(keypoints, img8)
end

# ╔═╡ fe771a63-efad-472d-84c9-5077b03ad7e8
function try4chute(chute,points,mpoints,img,keypoints)
	try
		trychute(chute,points,mpoints,img,keypoints)
	catch
		novo_chute = (chute[2],chute[1],sum(1:4) - sum(chute))
		try 
			trychute(novo_chute,points,mpoints,img,keypoints)
		catch
			novo_chute = (chute[3],sum(1:4) - sum(chute),chute[1])
			try
				trychute(novo_chute,points,mpoints,img,keypoints)
			catch
				novo_chute = (sum(1:4) - sum(chute),chute[3],chute[2])
				trychute(novo_chute,points,mpoints,img,keypoints)
			end
		end

	end
end

# ╔═╡ 1220002b-81f8-46e2-851e-041b412c0e44
md"""
A função abaixo recebe um caminho e tenta ler a prova. Ela não funciona para todas as imagens, mas é confiavel o suficiente
"""

# ╔═╡ 988088c2-7036-4743-bc6a-ca8d7339e2a1
function find_corners(points1,img)
	if length(points1) < 4
		throw(ErrorException("Não foram encontrados keypoints suficientes"))
	end
	points = copy(points1)
	super_esq1 = findmin(x-> dist(x,(1,1)),points)
	super_esq = points[super_esq1[2]]
	deleteat!(points,super_esq1[2])
	super_dir1 = findmin(x-> dist(x,(1,size(img)[2])),points)
	super_dir = points[super_dir1[2]]
	deleteat!(points,super_dir1[2])
	inf_esq1 = findmin(x-> dist(x,(size(img)[1],1)),points)
	inf_esq = points[inf_esq1[2]]
	deleteat!(points,inf_esq1[2])
	inf_dir = argmin(x-> dist(x,(size(img)[1],size(img)[2])),points)
	super_esq,super_dir,inf_esq, inf_dir
end

# ╔═╡ 72541b7b-6edf-45f2-a260-bbc92e780873
keypoints5 = find_corners(point.(keypoints4),img5)

# ╔═╡ 00eaccaa-a9b0-4592-a763-74a8e94c19d5
img7 = RGB.(img5); for key in keypoints5
	img7[clamp.(floor(Int,key[1])-20:floor(Int,key[1])+20,1,4680),clamp.(floor(Int,key[2]-20):floor(Int,key[2])+20,1,3310)] .= RGB(1,0,0); end

# ╔═╡ d12eb747-f960-4c34-a6cf-70f6cc99cdd0
img7

# ╔═╡ 2bbee6de-d0f7-44f1-8926-74db773e1f63
points = [[x[1],x[2]] for x in keypoints5]

# ╔═╡ 40f393de-c358-4543-9f07-60ce8802ae6e
chute = chutes(points)

# ╔═╡ ccc4252b-a983-4f5d-bf70-8e3cfb88280f
fixed_points = points[[chute...]]

# ╔═╡ 8521f24d-940c-4ccd-bed5-bc4c5ef138b8
moving_points = [[x[1],x[2]] for x in find_corners(point.(keypoints),img1)][[1,2,3]]

# ╔═╡ 5790590d-255b-4795-a47c-184edeabaec8
f = getaffinetransform(fixed_points,moving_points)

# ╔═╡ 2e06f4b7-66c1-4ffb-ac49-1edb61e4f53c
begin
	imgw = warp(img5, f,axes(img5));
end

# ╔═╡ 52f8c5b8-282f-4808-b393-fb2cd74c5738
try4chute(chute,points,moving_points,img5,keypoints)

# ╔═╡ f9c5b2fe-97cc-493d-859d-8dd3bb3ba647
function tryread_ocv(caminho, detector, mpoints, keypointsmestre,masterimg)
	@show caminho
	alg = AdaptiveThreshold(window_size = 500)
	img10 = binarize(Gray.(load(caminho)), alg)
	if size(img10)[1] < size(img10)[2]
		img12 = imrotate(Gray{Float64}.(img10),-pi/2)
		img5 = imresize(ifelse.(isnan.(img12),Gray(1.),img12),size(masterimg))
	else
		img5 = imresize(ifelse.(isnan.(img10),Gray(1.),img10),size(masterimg))
	end
	img1 = opening(closing(dilate(dilate(img5))))
	img6 = julopencv(img1)
	key = (detector.detect(img6))
	point.(key)
	point1 = find_corners(point.(key),img5)
	points = [[x[1],x[2]] for x in point1]
	return try4chute(chutes(points),points,mpoints,img5,keypointsmestre)
end

# ╔═╡ 91d93f76-e6a9-4c2e-8f9e-29bec5bedfc8
md"""
A célula abaixo também tem execução bastante lenta pois lê todos os arquivos e processa
"""

# ╔═╡ 79af3db8-d485-4aa9-915a-42004929c7a9
# tryread_ocv.(readdir("scans2", join = true)[15:end],(detect2,), (moving_points,), (keypoints,),(img1,))

# ╔═╡ bdbe5e90-e2b6-4c74-85a6-6bb428156379
tryread_ocv.("scans2/amc038.jpg",(detect2,), (moving_points,), (keypoints,),(img1,))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Conda = "8f4d0f93-b110-5947-807f-2305c1781a2d"
CoordinateTransformations = "150eb455-5306-5404-9cee-2592286d6298"
ImageBinarization = "cbc4b850-ae4b-5111-9e64-df94c024a13d"
ImageDraw = "4381153b-2b60-58ae-a1ba-fd683676385f"
ImageFeatures = "92ff4b2b-8094-53d3-b29d-97f740f06cef"
ImageFiltering = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
ImageIO = "82e4d734-157c-48bb-816b-45c225c6df19"
ImageMorphology = "787d08f9-d448-5407-9aad-5290dd7ab264"
Images = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Conda = "~1.5.2"
CoordinateTransformations = "~0.6.1"
ImageBinarization = "~0.2.7"
ImageDraw = "~0.2.5"
ImageFeatures = "~0.4.5"
ImageFiltering = "~0.6.21"
ImageIO = "~0.5.8"
ImageMorphology = "~0.2.11"
Images = "~0.24.1"
PyCall = "~1.92.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc1"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "485ee0867925449198280d4af84bdb46a2a404d0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.0.1"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArrayInterface]]
deps = ["IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "d84c956c4c0548b4caf0e4e96cf5b6494b5b1529"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.1.32"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "a4d07a1c313392a77042855df46c5f534076fab9"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "d127d5e4d86c7680b20c35d40b503c74b9a39b5e"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.4"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "4ce9393e871aca86cc457d9f66976c3da6902ea7"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.4.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "a66a8e024807c4b3d186eb1cab2aff3505271f8e"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.6"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "4866e381721b30fac8dda4c8cb1d9db45c8d2994"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.37.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.Conda]]
deps = ["JSON", "VersionParsing"]
git-tree-sha1 = "299304989a5e6473d985212c28928899c74e9421"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.5.2"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "6d1c23e740a586955645500bbec662476204a52c"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.1"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DataAPI]]
git-tree-sha1 = "bec2532f8adb82005476c141ec23e921fc20971b"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.8.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "9f46deb4d4ee4494ffb5a40a27a2aced67bdd838"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.4"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "a837fdf80f333415b69684ba8e8ae6ba76de6aaa"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.24.18"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "8041575f021cba5a099a456b4163c9a08b566a02"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.1.0"

[[deps.ExprTools]]
git-tree-sha1 = "b7e3d17636b348f005f11040025ae8c6f645fe92"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.6"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "70a0cfd9b1c86b0209e38fbfe6d8231fd606eeaf"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.1"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "463cb335fa22c4ebacfd1faba5fde14edb80d96c"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.5"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "3c041d2ac0a52a12a27af2782b34900d9c3ee68c"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.1"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "693210145367e7685d8604aee33d9bfb85db8b31"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.11.9"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "2c1cf4df419938ece72de17f368a021ee162762e"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.0"

[[deps.HistogramThresholding]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "2209954a25238b5f95ce3e1ca270dcef6013463a"
uuid = "2c695a8d-9458-5d45-9878-1b8a99cf7853"
version = "0.2.5"

[[deps.IdentityRanges]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be8fcd695c4da16a1d6d0cd213cb88090a150e3b"
uuid = "bbac6d45-d8f3-5730-bfe4-7a449cd117ca"
version = "0.3.1"

[[deps.IfElse]]
git-tree-sha1 = "28e837ff3e7a6c3cdb252ce49fb412c8eb3caeef"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.0"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "794ad1d922c432082bc1aaa9fa8ffbd1fe74e621"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.9"

[[deps.ImageBinarization]]
deps = ["ColorVectorSpace", "HistogramThresholding", "ImageContrastAdjustment", "ImageCore", "LinearAlgebra", "Polynomials", "Reexport", "Statistics"]
git-tree-sha1 = "b4df49f71ebd24f6988acb437eee789a8cb84858"
uuid = "cbc4b850-ae4b-5111-9e64-df94c024a13d"
version = "0.2.7"

[[deps.ImageContrastAdjustment]]
deps = ["ColorVectorSpace", "ImageCore", "ImageTransformations", "Parameters"]
git-tree-sha1 = "2e6084db6cccab11fe0bc3e4130bd3d117092ed9"
uuid = "f332f351-ec65-5f6a-b3d1-319c6670881a"
version = "0.3.7"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "db645f20b59f060d8cfae696bc9538d13fd86416"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.8.22"

[[deps.ImageDistances]]
deps = ["ColorVectorSpace", "Distances", "ImageCore", "ImageMorphology", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "6378c34a3c3a216235210d19b9f495ecfff2f85f"
uuid = "51556ac3-7006-55f5-8cb3-34580c88182d"
version = "0.2.13"

[[deps.ImageDraw]]
deps = ["Distances", "ImageCore", "LinearAlgebra"]
git-tree-sha1 = "6ed6e945d909f87c3013e391dcd3b2a56e48b331"
uuid = "4381153b-2b60-58ae-a1ba-fd683676385f"
version = "0.2.5"

[[deps.ImageFeatures]]
deps = ["Distributions", "Images", "Random", "SparseArrays"]
git-tree-sha1 = "c91e36180441788b317ce812fd744636b3a7de1c"
uuid = "92ff4b2b-8094-53d3-b29d-97f740f06cef"
version = "0.4.5"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ColorVectorSpace", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageCore", "LinearAlgebra", "OffsetArrays", "Requires", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "bf96839133212d3eff4a1c3a80c57abc7cfbf0ce"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.6.21"

[[deps.ImageIO]]
deps = ["FileIO", "Netpbm", "OpenEXR", "PNGFiles", "TiffImages", "UUIDs"]
git-tree-sha1 = "13c826abd23931d909e4c5538643d9691f62a617"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.5.8"

[[deps.ImageMagick]]
deps = ["FileIO", "ImageCore", "ImageMagick_jll", "InteractiveUtils", "Libdl", "Pkg", "Random"]
git-tree-sha1 = "5bc1cb62e0c5f1005868358db0692c994c3a13c6"
uuid = "6218d12a-5da1-5696-b52f-db25d2ecc6d1"
version = "1.2.1"

[[deps.ImageMagick_jll]]
deps = ["JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pkg", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1c0a2295cca535fabaf2029062912591e9b61987"
uuid = "c73af94c-d91f-53ed-93a7-00f77d67a9d7"
version = "6.9.10-12+3"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ColorVectorSpace", "ImageAxes", "ImageCore", "IndirectArrays"]
git-tree-sha1 = "ae76038347dc4edcdb06b541595268fca65b6a42"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.5"

[[deps.ImageMorphology]]
deps = ["ColorVectorSpace", "ImageCore", "LinearAlgebra", "TiledIteration"]
git-tree-sha1 = "68e7cbcd7dfaa3c2f74b0a8ab3066f5de8f2b71d"
uuid = "787d08f9-d448-5407-9aad-5290dd7ab264"
version = "0.2.11"

[[deps.ImageQualityIndexes]]
deps = ["ColorVectorSpace", "ImageCore", "ImageDistances", "ImageFiltering", "OffsetArrays", "Statistics"]
git-tree-sha1 = "1198f85fa2481a3bb94bf937495ba1916f12b533"
uuid = "2996bd0c-7a13-11e9-2da2-2f5ce47296a9"
version = "0.2.2"

[[deps.ImageShow]]
deps = ["Base64", "FileIO", "ImageCore", "OffsetArrays", "Requires", "StackViews"]
git-tree-sha1 = "832abfd709fa436a562db47fd8e81377f72b01f9"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.1"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "ColorVectorSpace", "CoordinateTransformations", "IdentityRanges", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "e4cc551e4295a5c96545bb3083058c24b78d4cf0"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.8.13"

[[deps.Images]]
deps = ["AxisArrays", "Base64", "ColorVectorSpace", "FileIO", "Graphics", "ImageAxes", "ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "ImageIO", "ImageMagick", "ImageMetadata", "ImageMorphology", "ImageQualityIndexes", "ImageShow", "ImageTransformations", "IndirectArrays", "OffsetArrays", "Random", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "TiledIteration"]
git-tree-sha1 = "8b714d5e11c91a0d945717430ec20f9251af4bd2"
uuid = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
version = "0.24.1"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "c2a145a145dc03a7620af1444e0264ef907bd44f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "0.5.1"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "61aa005707ea2cebf47c8d780da8dc9bc4e0c512"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.4"

[[deps.IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "3cc368af3f110a767ac786560045dceddfc16758"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.3"

[[deps.Intervals]]
deps = ["Dates", "Printf", "RecipesBase", "Serialization", "TimeZones"]
git-tree-sha1 = "323a38ed1952d30586d0fe03412cde9399d3618b"
uuid = "d8418881-c3e1-53bb-8760-2df7ec849ed5"
version = "1.5.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "f76424439413893a832026ca355fe273e93bce94"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.0"

[[deps.IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "34dc30f868e368f8a17b728a1238f3fcda43931a"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.3"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "5455aef09b40e5020e1520f551fa3135040d4ed0"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2021.1.1+2"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mocking]]
deps = ["ExprTools"]
git-tree-sha1 = "748f6e1e4de814b101911e64cc12d83a6af66782"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.2"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3927848ccebcc165952dc0d9ac9aa274a87bfe01"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "0.2.20"

[[deps.NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[deps.Netpbm]]
deps = ["ColorVectorSpace", "FileIO", "ImageCore"]
git-tree-sha1 = "09589171688f0039f13ebe0fdcc7288f50228b52"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "c870a0d713b51e4b49be6432eff0e26a4325afee"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.6"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "4dd403333bcf0909341cfe57ec115152f937d7d8"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.1"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "e14c485f6beee0c7a8dcf6128bf70b85f1fe201e"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.9"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "646eed6f6a5d8df6708f15ea7e02a7a2c4fe4800"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.10"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "2276ac65f1e236e0a6ea70baff3f62ad4c625345"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.2"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "9d8c00ef7a8d110787ff6f170579846f776133a9"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.4"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[deps.Polynomials]]
deps = ["Intervals", "LinearAlgebra", "MutableArithmetics", "RecipesBase"]
git-tree-sha1 = "0bbfdcd8cda81b8144de4be8a67f5717e959a005"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "2.0.14"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "afadeba63d90ff223a6a48d2009434ecee2ec9e8"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.1"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "169bb8ea6b1b143c5cf57df6d34d022a7b60c6db"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.92.3"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "7dff99fbc740e2f8228c6878e2aad6d7c2678098"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.1"

[[deps.RecipesBase]]
git-tree-sha1 = "44a75aa7a527910ee3d1751d1f0e4148698add9e"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.Rotations]]
deps = ["LinearAlgebra", "StaticArrays", "Statistics"]
git-tree-sha1 = "2ed8d8a16d703f900168822d83699b8c3c1a5cd8"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.0.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "LogExpFunctions", "OpenSpecFun_jll"]
git-tree-sha1 = "a322a9493e49c5f3a10b50df3aedaf1cdb3244b7"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.6.1"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.Static]]
deps = ["IfElse"]
git-tree-sha1 = "a8f30abc7c64a39d389680b74e749cf33f872a70"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.3.3"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3240808c6d463ac46f1c1cd7638375cd22abbccb"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.12"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8cbbc098554648c84f79a463c9ff0fd277144b6c"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.10"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "46d7ccc7104860c38b11966dd1f72ff042f382e4"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.10"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "OffsetArrays", "OrderedCollections", "PkgVersion", "ProgressMeter"]
git-tree-sha1 = "632a8d4dbbad6627a4d2d21b1c6ebcaeebb1e1ed"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.4.2"

[[deps.TiledIteration]]
deps = ["OffsetArrays"]
git-tree-sha1 = "52c5f816857bfb3291c7d25420b1f4aca0a74d18"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.3.0"

[[deps.TimeZones]]
deps = ["Dates", "Future", "LazyArtifacts", "Mocking", "Pkg", "Printf", "RecipesBase", "Serialization", "Unicode"]
git-tree-sha1 = "6c9040665b2da00d30143261aea22c7427aada1c"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.5.7"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.VersionParsing]]
git-tree-sha1 = "80229be1f670524750d905f8fc8148e5a8c4537f"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.2.0"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "59e2ad8fd1591ea019a5259bd012d7aee15f995c"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─beb2d2ef-ce1a-4c09-a7aa-0a3a8d720ac2
# ╟─f92a33ce-414e-4201-a340-59e82afc8c11
# ╟─4349264f-1971-4068-a231-6d650f688f14
# ╟─239b6397-ef7d-4edc-bf0c-035c7bcfe74f
# ╟─c5538fbb-6f5d-4e06-ab75-ab017b3aceb0
# ╠═762cef5a-15ba-11ec-28ab-53ab54299fd6
# ╠═75096176-2f71-439d-b653-36f7a681af5d
# ╠═4fbca8d8-2ed9-4e9f-bdb5-c5decc7d794b
# ╠═59943fdb-9f3c-4d05-b1cf-8d5b2861e0ef
# ╟─439a8461-1d00-4eab-908d-0ab41b00ccbb
# ╠═ba77f21a-d657-4365-882c-e028882a7b30
# ╟─ca98da5a-1e7a-4cbf-a32c-7fb2c69aba94
# ╠═2cccd021-f246-4161-8fe4-67c812e356c2
# ╟─efe4c427-6479-486b-9f9d-c43c8d114256
# ╠═84cc71ad-4aad-47b9-a11b-d630e852402c
# ╟─92716939-5ca1-4729-a157-6620bc46d8b9
# ╠═334a15d8-578d-458a-8d5d-43c4194a13cc
# ╟─bab46def-766c-4234-9730-e9b49c60ca0c
# ╠═851ed1d9-27ae-42c0-bd42-10b97d0fbe0a
# ╠═07d4b3f5-1ee8-4a9c-8d04-a52e76938b33
# ╠═bd563de1-729c-492b-bcba-3040109899d5
# ╟─d21bdc84-fcb7-4b9e-a3dd-5d87a18c4452
# ╠═483c2d4d-d5f8-4e1f-ac8d-64e1dce4e5f2
# ╠═1cfb9bf5-0ded-4a92-9c29-398d9c8efb77
# ╠═b0311d12-1562-46a8-9e28-46d1cbe49c6d
# ╟─92d7f269-096c-45bf-80b4-fc45a5b10599
# ╠═f91b498e-2af3-423b-a8d6-9d711ad9d086
# ╟─c8ef8326-9e59-4111-b196-2706c6252de1
# ╠═601df038-efe1-412f-8483-d16db47f885d
# ╠═fdc2beae-8f23-41ec-8f48-d359159f5d6b
# ╟─b259605f-9a7c-4b27-8653-c5769c569ebe
# ╠═fe8bf5ed-ffd0-4e5c-9a99-f219a187ae47
# ╟─26201faa-40ca-4ea1-9318-ddadef24b0d9
# ╠═2e88b0d3-e8d6-43ee-85aa-b484d8f76d83
# ╟─c57cb67b-a279-4426-8b57-1cf1ba259ac1
# ╠═eb60f6f0-3978-4fc5-bcb6-a664ae3179f0
# ╠═14395c27-c8cc-4c6f-a598-9a7c4b9f3530
# ╟─dca6e824-e22d-4da3-a64d-2ece636234e9
# ╠═601f6e06-c47a-4bf7-bea1-e04c16693415
# ╠═e9d1f063-6bfd-462a-84b2-57d361919233
# ╟─52ef5cb4-f2b8-46ce-bead-10c6f12e478b
# ╠═10400e43-0646-49dc-99ae-c0aa11564fbd
# ╠═db550d42-7591-4311-8019-ff3abf484691
# ╠═9b618cde-d420-40e9-8c4c-4a791795e363
# ╟─f9a44691-ecab-462c-bf1d-3a6f9ff2a443
# ╠═dfa22931-c5ae-4d5b-a298-474d3180d63a
# ╠═a65b546b-690b-4983-a1a5-216f31048702
# ╠═f9e807c3-91c4-4e6d-b4bc-7bcb95e5a232
# ╟─4115e028-8c02-4797-9b16-a4892c216c52
# ╠═8b7c857e-09c4-4ac2-9e3d-b38de62cb518
# ╠═44c6d7e2-89ba-4899-9e0c-036a73e27909
# ╠═06f0956c-2f25-40bb-9436-314fdaecf574
# ╠═fc602db2-bbf4-4953-a7bd-51c18c91b67c
# ╟─a48cf337-33e3-4254-9136-d14d155b6cb1
# ╟─0cbfe6f0-fde1-430f-a68a-67ffef15285c
# ╟─84ad3be7-9889-4853-8f84-e495e29f7233
# ╠═86e86062-bbab-421a-a3d2-ec23ade63b37
# ╟─07bfb43f-8f00-4768-ad73-cf1b6c5022e5
# ╟─486e7b73-14a5-4f2f-8706-39dd27d896f4
# ╟─12d74c0d-973f-4974-8d23-33bbc7e84827
# ╟─26d74ab9-9cad-4fc5-b902-5b2e92faffd0
# ╟─18c5c634-089d-46f6-aca1-9d98c1589152
# ╟─30071e79-cfef-4296-b509-a1222c780f1a
# ╟─c5854a35-9483-464b-a4a7-85aaae4fcaac
# ╠═70e7d260-1cea-488b-836e-abc7fe9fb691
# ╠═eeb7f7c9-f8ce-4342-ade2-6dc4da82bace
# ╟─404d28c9-f74c-4bbc-96ae-d13af0355887
# ╠═64b02891-d0ca-4354-9f98-8c7dfd697398
# ╟─bbd1cf52-74d8-4124-9183-09ee6b4a6382
# ╟─61be6c71-ae18-42aa-a6dc-2d2ba9ffc878
# ╟─3ef5e51a-13da-4892-a8f9-153944283386
# ╠═2f1fd839-8b1c-4800-ab45-2f3dc141f056
# ╠═9089b195-350b-4642-bbe8-da0b5693d0e0
# ╟─9d710335-bb66-4287-b40d-f750aa3eef15
# ╠═a41af8c5-92ee-494b-a7f9-31dfd0599afd
# ╠═3d37a078-3b26-4700-b7ba-7f68994f7eac
# ╠═264960d4-5a6b-4dc2-b711-11b74b400c2b
# ╠═242dd1f8-9840-4771-bfb3-7e21d0ce9213
# ╠═72541b7b-6edf-45f2-a260-bbc92e780873
# ╟─d8a7843e-d4a0-4d3a-80c5-a146138bf488
# ╟─00eaccaa-a9b0-4592-a763-74a8e94c19d5
# ╠═d12eb747-f960-4c34-a6cf-70f6cc99cdd0
# ╟─22986f2d-ff92-4dab-a7d7-249701858c66
# ╠═8de68341-6577-4e74-a76f-9350096834e2
# ╠═8521f24d-940c-4ccd-bed5-bc4c5ef138b8
# ╠═2bbee6de-d0f7-44f1-8926-74db773e1f63
# ╠═40f393de-c358-4543-9f07-60ce8802ae6e
# ╠═ccc4252b-a983-4f5d-bf70-8e3cfb88280f
# ╟─bc76a4b3-39de-4295-8523-85fdd1a4d714
# ╠═048b9aea-0e9f-4b44-b69f-075bcc15aec2
# ╠═5790590d-255b-4795-a47c-184edeabaec8
# ╟─b5138607-37e9-417d-9dfb-a0601bd293ac
# ╠═2e06f4b7-66c1-4ffb-ac49-1edb61e4f53c
# ╟─af11c265-efdd-4eba-a5cf-d6b69cc52ac2
# ╠═52f8c5b8-282f-4808-b393-fb2cd74c5738
# ╠═cde60a3f-996a-4c2f-b645-f5b965d5fbd3
# ╠═fe771a63-efad-472d-84c9-5077b03ad7e8
# ╟─1220002b-81f8-46e2-851e-041b412c0e44
# ╠═988088c2-7036-4743-bc6a-ca8d7339e2a1
# ╠═f9c5b2fe-97cc-493d-859d-8dd3bb3ba647
# ╟─91d93f76-e6a9-4c2e-8f9e-29bec5bedfc8
# ╠═79af3db8-d485-4aa9-915a-42004929c7a9
# ╠═bdbe5e90-e2b6-4c74-85a6-6bb428156379
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
