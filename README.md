# Projeto F.L.E.E.T. - Entrega DevOps (Azure)

## 1. Descrição da Solução
Esta é uma aplicação backend em Java/Spring Boot que serve como o sistema de gerenciamento para pátios da Mottu. Ela oferece um painel web para um Super Administrador e uma API REST para os Administradores de Pátio, permitindo o cadastro de unidades, funcionários e a gestão de acesso via Magic Links.

## 2. Benefícios para o Negócio
A solução digitaliza e automatiza o controle de pátios, substituindo o processo manual baseado em pranchetas. Isso resulta em:
- **Redução de Erros Humanos:** Minimiza falhas no registro de dados.
- **Otimização de Tempo:** Agiliza o trabalho dos operadores e administradores.
- **Visibilidade em Tempo Real:** Fornece dados atualizados sobre a operação.
- **Segurança:** Controla o acesso às funcionalidades através de perfis e autenticação robusta.

## 3. Arquitetura da Solução na Azure
A arquitetura implementada na Azure utiliza uma abordagem de containers para a aplicação e um banco de dados como serviço (PaaS), garantindo escalabilidade e separação de responsabilidades.

![Arquitetura da Solução](arquitetura.png)

## 4. Passo a Passo para o Deploy

### Pré-requisitos
- [Git](https://git-scm.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

### Passo 1: Clonar o Repositório
```bash
git clone https://github.com/FLEET-MOTTU/DEVOPS-SPRINT3.git
cd javafleet
```

### Passo 2: Login na Azure
```bash
az login
```
(Uma janela do navegador será aberta para você fazer o login na sua conta Azure).

### Passo 3: Criar os Recursos na Nuvem (Scripts Azure CLI)

```bash
RESOURCE_GROUP="rg-fleet"
LOCATION="brazilsouth"
ACR_NAME="acrfltSEUNOME" # Nome do Container Registry (letras minúsculas)
MYSQL_SERVER_NAME="mysql-fleet-SEU_NOME"
MYSQL_ADMIN_USER="mottuadmin"
MYSQL_ADMIN_PASSWORD="PasswordMottu@2025" # Use uma senha forte
DB_NAME="fleetdb"
ACI_NAME="aci-fleet-app"

# 1. Criar um Grupo de Recursos
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Criar o Servidor de Banco de Dados MySQL
az mysql flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME \
  --admin-user $MYSQL_ADMIN_USER \
  --admin-password $MYSQL_ADMIN_PASSWORD \
  --sku-name Standard_B1ms --tier Burstable \
  --public-access 0.0.0.0 --storage-size 32 --version 8.0

# 3. Criar o banco de dados 'fleetdb'
az mysql flexible-server db create \
  -g $RESOURCE_GROUP -s $MYSQL_SERVER_NAME \
  -d $DB_NAME

# 4. Criar o Azure Container Registry (ACR)
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
```

### Passo 4: Build e Push da Imagem Docker
Primeiro, compile o projeto Java e depois construa e envie a imagem para o ACR.

```bash
# Compile e empacote o projeto Java
mvn clean package -DskipTests

# Faça login no seu ACR
az acr login --name $ACR_NAME

# Construa a imagem Docker
docker build -t $ACR_NAME.azurecr.io/fleet-app:v1 .

# Envie a imagem para o ACR
docker push $ACR_NAME.azurecr.io/fleet-app:v1
```

### Passo 5: Executar a Aplicação no Azure Container Instances (ACI)
Agora, vamos criar o container ACI, passando as variáveis de ambiente para ele se conectar ao banco de dados.

```bash
# Pegar o FQDN (host) do servidor MySQL
DB_HOST=$(az mysql flexible-server show -g $RESOURCE_GROUP -n $MYSQL_SERVER_NAME --query "fullyQualifiedDomainName" -o tsv)

# Criar a instância de container
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $ACI_NAME \
  --image $ACR_NAME.azurecr.io/fleet-app:v1 \
  --registry-login-server $ACR_NAME.azurecr.io \
  --registry-username $(az acr credential show -n $ACR_NAME --query "username" -o tsv) \
  --registry-password $(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv) \
  --dns-name-label fleet-app-SEUNOME \
  --ports 8080 \
  --environment-variables \
    'DB_HOST'=$DB_HOST \
    'DB_PORT'='3306' \
    'DB_NAME'=$DB_NAME \
    'DB_USER'=$MYSQL_ADMIN_USER \
    'DB_PASSWORD'=$MYSQL_ADMIN_PASSWORD \
    'JWT_KEY'='a2c8a2b5e0f7e4d3c1b9a8e7f6d5c4b3a2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7'
```
Aguarde alguns minutos para o container iniciar. Você pode verificar o status com `az container show -g $RESOURCE_GROUP -n $ACI_NAME`.

### Passo 6: Testando a Aplicação
Quando o container estiver `Running`, pegue a URL pública dele:

```bash
# Pegar a URL pública da aplicação
APP_URL=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query "ipAddress.fqdn" -o tsv)
echo "Sua aplicação está rodando em: http://$APP_URL:8080"
```
Acesse `http://SUA_URL:8080/swagger-ui.html` para testar o CRUD.

**Exemplo de teste (Criar Funcionário - POST):**
- **Endpoint:** `POST /api/funcionarios`
- **JSON Body:**
```json
{
  "nome": "Funcionario Teste Azure",
  "telefone": "11987654321",
  "cargo": "OPERACIONAL"
}
```
(Lembre-se de se autenticar via `/api/auth/login` primeiro para obter o token JWT).