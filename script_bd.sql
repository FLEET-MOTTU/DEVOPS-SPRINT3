-- Compilei todo o conteudo da pasta src/main/resources/db/migration para este script unico
-- só para facilitar a visualização, não é usado de fato pelo flyway, só para avaliação

CREATE TABLE usuario_admin (
    id BINARY(16) NOT NULL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'PATEO_ADMIN',
    status VARCHAR(20) NOT NULL DEFAULT 'ATIVO',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pateo (
    id BINARY(16) NOT NULL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    planta_baixa_url VARCHAR(255),
    planta_largura INT,
    planta_altura INT,
    gerenciado_por_id BINARY(16) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ATIVO',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (gerenciado_por_id) REFERENCES usuario_admin(id)
);

CREATE TABLE zona (
    id BINARY(16) NOT NULL PRIMARY KEY,
    pateo_id BINARY(16) NOT NULL,
    criado_por_id BINARY(16) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cor VARCHAR(7),
    coordenadas GEOMETRY NOT NULL SRID 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pateo_id) REFERENCES pateo(id),
    FOREIGN KEY (criado_por_id) REFERENCES usuario_admin(id),
    SPATIAL INDEX(coordenadas)
);

CREATE TABLE funcionario (
    id BINARY(16) NOT NULL PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    nome VARCHAR(255) NOT NULL,
    telefone VARCHAR(15) NOT NULL,
    cargo ENUM('OPERACIONAL', 'ADMINISTRATIVO', 'TEMPORARIO') NOT NULL,
    status ENUM('ATIVO', 'SUSPENSO', 'REMOVIDO') NOT NULL,
    foto_url VARCHAR(255),
    ultimo_login TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pateo_id BINARY(16) NOT NULL,
    CONSTRAINT fk_funcionario_pateo FOREIGN KEY (pateo_id) REFERENCES pateo(id)
);

CREATE TABLE token_acesso (
    id BINARY(16) NOT NULL PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    funcionario_id BINARY(16) NOT NULL,
    criado_em TIMESTAMP NOT NULL,
    expira_em TIMESTAMP NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    dispositivo_info VARCHAR(255),
    FOREIGN KEY (funcionario_id) REFERENCES funcionario(id) ON DELETE CASCADE
);