# Projeto F.L.E.E.T. - Entrega DevOps (Azure)

## 1. Descrição da Solução
Esta é uma aplicação backend em Java/Spring Boot que serve como o sistema de gerenciamento para pátios da Mottu. Ela oferece um painel web para um Super Administrador e uma API REST para os Administradores de Pátio, permitindo o cadastro de unidades, funcionários e a gestão de acesso.

## 2. Benefícios para o Negócio
A solução digitaliza e automatiza o controle de pátios, substituindo o processo manual baseado em pranchetas. Isso resulta em:
- **Redução de Erros Humanos:** Minimiza falhas no registro de dados.
- **Otimização de Tempo:** Agiliza o trabalho dos operadores e administradores.
- **Visibilidade em Tempo Real:** Fornece dados atualizados sobre a operação.
- **Segurança:** Controla o acesso às funcionalidades através de perfis e autenticação robusta.

## 3. Arquitetura da Solução na Azure
A arquitetura implementada na Azure utiliza uma abordagem de containers para a aplicação e um banco de dados como serviço (PaaS), garantindo escalabilidade e separação de responsabilidades. Os serviços principais utilizados são:
- **Azure Container Instances (ACI):** Para executar a aplicação Java em um container de forma rápida e sem gerenciamento de servidores.
- **Azure Container Registry (ACR):** Para armazenar e gerenciar a imagem Docker da aplicação de forma privada e segura.
- **Azure Database for MySQL (Flexible Server):** Como nosso banco de dados relacional gerenciado.

![Arquitetura da Solução](arquitetura.png)

## 4. Passo a Passo para o Deploy
Este guia detalha o processo completo para provisionar a infraestrutura na Azure e implantar a aplicação F.L.E.E.T. com todos os comandos que foram utilizados durante o processo:

### Pré-requisitos
- [Git](https://git-scm.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Java 17](oracle.com/java/technologies/downloads/)
- [Maven](maven.apache.org/download.cgi)

### Passo 1: Clonar o Repositório
```bash
git clone https://github.com/FLEET-MOTTU/DEVOPS-SPRINT3.git
cd DEVOPS-SPRINT3
```

### Passo 2: Autenticação na Azure
```bash
az login
```
(Uma janela do navegador será aberta para você fazer o login na sua conta Azure).

### Passo 3: Scripts Azure CLI

# 1. Configuração das Variáveis de Ambiente
Copie o bloco de comandos abaixo e cole no seu terminal. A única variável que você deve alterar é NOME_UNICO para garantir que os recursos criados na Azure sejam únicos e não entrem em conflito com outros.

```bash
NOME_UNICO="exemplo-nome"
RESOURCE_GROUP="rg-fleet-$NOME_UNICO"
LOCATION="westus2"
ACR_NAME="acrflt$(echo $NOME_UNICO | tr '[:upper:]' '[:lower:]' | tr -d '_-')a"
MYSQL_SERVER_NAME="mysql-fleet-$NOME_UNICO"
MYSQL_ADMIN_USER="mottuadmin"
DB_NAME="fleetdb"
DB_PASSWORD="PasswordMottu@2025"
ACI_NAME="aci-fleet-app"
```

# 2. Provisionamento da Infraestrutura na Azure
Com as variáveis configuradas, execute os comandos abaixo em sequência para criar todos os recursos necessários na nuvem.

```bash
# 1. Criar o Grupo de Recursos para organizar tudo
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Criar o Servidor de Banco de Dados MySQL Flexível
az mysql flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME \
  --admin-user $MYSQL_ADMIN_USER \
  --admin-password $DB_PASSWORD \
  --sku-name Standard_B1s \
  --tier Burstable \
  --public-access 0.0.0.0 --storage-size 32 --version 8.0.21

# 3. Criar a regra de firewall para permitir acesso público ao banco (APENAS PARA TESTES, inseguro para produção)
az mysql flexible-server firewall-rule create --resource-group $RESOURCE_GROUP --name $MYSQL_SERVER_NAME --rule-name "AllowAll" --start-ip-address "0.0.0.0" --end-ip-address "255.255.255.255"

# 4. Criar o banco de dados 'fleetdb' dentro do servidor
az mysql flexible-server db create -g $RESOURCE_GROUP -s $MYSQL_SERVER_NAME -d $DB_NAME

# 5. Criar o Azure Container Registry (ACR) para hospedar nossa imagem Docker
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
```

# 3. Build e Push da Imagem Docker
Agora, vamos compilar a aplicação Java, criar a imagem Docker e enviá-la para o nosso ACR. (IMPORATE: esteja na raiz do repositório clonado)

```bash
# 1. Compilar o projeto Java e gerar o arquivo .jar
mvn clean package -DskipTests

# 2. Fazer login no ACR
az acr login --name $ACR_NAME

# 3. Construir a imagem Docker com base no Dockerfile
docker build -t $ACR_NAME.azurecr.io/fleet-app:v1 .

# 4. Enviar a imagem para o ACR na Azure
docker push $ACR_NAME.azurecr.io/fleet-app:v1
```

# 4. Deploy da Aplicação no Azure Container Instances (ACI)
O último passo é executar a imagem que está no ACR como um container na Azure, injetando as variáveis de ambiente para a conexão com o banco de dados.

```bash
# 1. Obter o endereço do servidor de banco de dados
DB_HOST=$(az mysql flexible-server show -g $RESOURCE_GROUP -n $MYSQL_SERVER_NAME --query "fullyQualifiedDomainName" -o tsv)

# 2. Obter as credenciais do ACR
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# 3. Criar o container da aplicação
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $ACI_NAME \
  --image $ACR_NAME.azurecr.io/fleet-app:v1 \
  --os-type Linux \
  --cpu 1 \
  --memory 1.5 \
  --registry-login-server $ACR_NAME.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label fleet-app-$(echo $NOME_UNICO | tr '[:upper:]' '[:lower:]' | tr -d '_-') \
  --ports 8080 \
  --environment-variables \
    DB_HOST=$(echo $DB_HOST | tr -d '\r') \
    DB_PORT=3306 \
    DB_NAME=$DB_NAME \
    DB_USER=$MYSQL_ADMIN_USER \
    DB_PASSWORD=$DB_PASSWORD \
    JWT_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30' \
    JWT_EXPIRATION=86400000 \
    SPRING_PROFILES_ACTIVE=dev \
    APPLICATION_BASE_URL="http://fleet-app-$(echo $NOME_UNICO | tr '[:upper:]' '[:lower:]' | tr -d '_-').$LOCATION.azurecontainer.io:8080" \
    LOCAL_IP=127.0.0.1
```

# 5. Verificação e Teste
Aguarde alguns minutos para o container iniciar.

```bash
# 1. Obter a URL pública da aplicação
APP_URL=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query "ipAddress.fqdn" -o tsv)
echo "Aplicação rodando em: http://$APP_URL:8080"

# 2. Acessar a documentação da API
echo "Swagger UI disponível em: http://$APP_URL:8080/swagger-ui/index.html"
```
Use o Swagger UI no seu navegador para interagir com os endpoints da API e testar as funcionalidades de CRUD. (Lembre-se de se autenticar via `/api/auth/login` primeiro para obter o token JWT).

Para verificar os dados diretamente no banco de dados, você pode se conectar usando qualquer cliente MySQL com o seguinte comando (usando o cliente do seu PC, por exemplo):

```bash
mysql -h SEU_DB_HOST -u mottuadmin -p"SUA_SENHA" --ssl-mode=REQUIRED fleetdb
```
Nota: Substitua SEU_DB_HOST pelo valor da variável $DB_HOST e SUA_SENHA pela senha definida.


# 6. Estrutura do Banco de Dados
Para referência, o script completo com a estrutura de todas as tabelas criadas pela aplicação (via Flyway) está disponível na raiz do repositório no arquivo script_bd.sql.


# 7. Limpando os recursos
Para remover todos os recursos criados neste guia e evitar cobranças, basta deletar o grupo de recursos. Este comando apagará tudo permanentemente.

```bash
az group delete --name $RESOURCE_GROUP --yes
```
az group create --name $RESOURCE_GROUP --location $LOCATION


# 8. Vídeo de Demonstração do Processo de Deploy:
- [Link](https://www.youtube.com/watch?v=zSlLnh5lH5E)

