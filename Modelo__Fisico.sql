CREATE DATABASE IF NOT EXISTS webdriver;
USE webdriver;

-- Apagar tabelas na ordem correta para evitar conflito de FK
DROP TABLE IF EXISTS atividades_recentes;
DROP TABLE IF EXISTS compartilhamento;
DROP TABLE IF EXISTS comenta;
DROP TABLE IF EXISTS comentario;
DROP TABLE IF EXISTS suporte;
DROP TABLE IF EXISTS administrador;
DROP TABLE IF EXISTS opera;
DROP TABLE IF EXISTS historico;
DROP TABLE IF EXISTS arquivo;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS instituicao;
DROP TABLE IF EXISTS plano;
DROP PROCEDURE IF EXISTS Remover_arquivo;
DROP PROCEDURE IF EXISTS Atualizar_arquivo;
DROP PROCEDURE IF EXISTS Remover_arquivo;
DROP PROCEDURE IF EXISTS Buscar_arquivo;
DROP PROCEDURE IF EXISTS Buscar_arquivos_usuario;
DROP PROCEDURE IF EXISTS Verificar_atividades;
DROP PROCEDURE IF EXISTS Conta_usuarios;
DROP PROCEDURE IF EXISTS VerArquivosUsuario;
DROP PROCEDURE IF EXISTS HistoricoUsuario;
DROP PROCEDURE IF EXISTS AtividadesRecentesUsuario;
DROP PROCEDURE IF EXISTS Chavear;
DROP PROCEDURE IF EXISTS Remover_acessos;


-- TABELAS PRINCIPAIS
CREATE TABLE plano(
	id_plano INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(20),
    duracao INT,
    aquisicao DATE,
    espaco_user VARCHAR(30) NOT NULL
);

CREATE TABLE instituicao(
	id_ins INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(20),
    causa_social VARCHAR(50),
    email VARCHAR(50),
    endereco VARCHAR(100),
    id_plano INT NOT NULL,
    FOREIGN KEY(id_plano) REFERENCES plano(id_plano)
);

CREATE TABLE usuario(
	id_user INT PRIMARY KEY AUTO_INCREMENT,
    id_ins INT NOT NULL,
	login VARCHAR(10),
	senha VARCHAR(10),
	email VARCHAR(30),
	data_ingresso DATE,
    FOREIGN KEY (id_ins) REFERENCES instituicao(id_ins)
);

CREATE TABLE arquivo(
	id_arq INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50),
    tipo VARCHAR(10),
    perm_acesso ENUM('Proprietário', 'Convidado') NOT NULL,
    tam_bytes INT,
    ultima_mod DATE,
    hora TIME,
    localizacao VARCHAR(20),
    url VARCHAR(20),
    id_user INT NOT NULL,
    FOREIGN KEY(id_user) REFERENCES usuario(id_user)
);

CREATE TABLE historico(
	id_hist INT PRIMARY KEY AUTO_INCREMENT,
    data_ DATE,
    hora TIME,
    operacao VARCHAR(10) CHECK (operacao='Carregar' OR operacao='Atualizar' OR operacao='Remover'),
    cont_mudado TEXT,
    id_arq INT NOT NULL,
    FOREIGN KEY(id_arq) REFERENCES arquivo(id_arq)
);

CREATE TABLE opera(
	id_op INT PRIMARY KEY AUTO_INCREMENT,
    tipo VARCHAR(10) CHECK (tipo='Carregar' OR tipo='Atualizar' OR tipo='Remover'),
    data_ DATE,
    hora TIME,
	id_user INT NOT NULL,
    id_arq INT NOT NULL,
    FOREIGN KEY(id_user) REFERENCES usuario(id_user),
    FOREIGN KEY(id_arq) REFERENCES arquivo(id_arq)
);

CREATE TABLE administrador(
	id_adm INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT NOT NULL,
    FOREIGN KEY(id_user) REFERENCES usuario(id_user)
);

CREATE TABLE suporte(
	id_sup INT PRIMARY KEY AUTO_INCREMENT,
    descricao VARCHAR(100),
    dia DATE,
    hora TIME,
    id_user INT NOT NULL,
    FOREIGN KEY(id_user) REFERENCES usuario(id_user),
    id_adm INT NOT NULL,
    FOREIGN KEY(id_adm) REFERENCES administrador(id_adm)
);

CREATE TABLE comentario(
	id_com INT PRIMARY KEY AUTO_INCREMENT,
    conteudo VARCHAR(300),
    data_ DATE,
    hora TIME
);

CREATE TABLE comenta(
	id_user INT NOT NULL,
    id_com INT NOT NULL,
    id_arq INT NOT NULL,
    FOREIGN KEY(id_user) REFERENCES usuario(id_user),
    FOREIGN KEY(id_com) REFERENCES comentario(id_com),
    FOREIGN KEY(id_arq) REFERENCES arquivo(id_arq)
);

CREATE TABLE compartilhamento(
	id_destinatario INT NOT NULL,
    id_dono INT NOT NULL,
    id_arq INT NOT NULL,
    data_ DATE,
    FOREIGN KEY(id_destinatario) REFERENCES usuario(id_user),
    FOREIGN KEY(id_dono) REFERENCES usuario(id_user),
    FOREIGN KEY(id_arq) REFERENCES arquivo(id_arq)
);

CREATE TABLE atividades_recentes(
    id_arquivo INT NOT NULL,
    ultima_versao DATE NOT NULL,
    acesso VARCHAR(20) CHECK (acesso='Prioritário' OR acesso='Não Prioritário'),
    FOREIGN KEY(id_arquivo) REFERENCES arquivo(id_arq)
);

-- O resto do seu script segue aqui (procedures, triggers, etc)


-- PROCEDURES
DELIMITER //

CREATE PROCEDURE Remover_arquivo(IN arquivo_id INT)
BEGIN
    DELETE FROM historico WHERE id_arq = arquivo_id;
    DELETE FROM compartilhamento WHERE id_arq = arquivo_id;
    DELETE FROM opera WHERE id_arq = arquivo_id;
    DELETE FROM arquivo WHERE id_arq = arquivo_id;
END //

CREATE PROCEDURE Atualizar_arquivo(
    IN arquivo_id INT,
    IN novo_nome VARCHAR(50),
    IN novo_tipo VARCHAR(10),
    IN nova_permissao VARCHAR(20),
    IN nova_localizacao VARCHAR(20),
    IN novo_url VARCHAR(20)
)
BEGIN
    UPDATE arquivo
    SET 
        nome = novo_nome,
        tipo = novo_tipo,
        perm_acesso = nova_permissao,
        localizacao = nova_localizacao,
        url = novo_url,
        ultima_mod = CURDATE(),
        hora = CURTIME()
    WHERE id_arq = arquivo_id;
END //


CREATE PROCEDURE Buscar_arquivo(IN arquivo_id INT)
BEGIN
    SELECT * FROM arquivo WHERE id_arq = arquivo_id;
END //

CREATE PROCEDURE Buscar_arquivos_usuario(IN user_id INT)
BEGIN
    SELECT * FROM arquivo
    WHERE id_user = user_id
       OR id_arq IN (SELECT id_arq FROM compartilhamento WHERE id_destinatario = user_id);
END //


CREATE PROCEDURE Verificar_atividades()
BEGIN
    UPDATE atividades_recentes SET ultima_versao = CURDATE();
END //

CREATE PROCEDURE Conta_usuarios(IN arquivo_id INT)
BEGIN
    DECLARE total_usuarios INT;

    SELECT COUNT(DISTINCT id_destinatario) INTO total_usuarios
    FROM compartilhamento
    WHERE id_arq = arquivo_id;

    SELECT total_usuarios AS "Total de Usuários com Acesso";
END //

CREATE PROCEDURE VerArquivosUsuario(IN user_id INT)
BEGIN
    SELECT 
        a.id_arq,
        a.nome,
        a.ultima_mod,
        a.hora,
        a.localizacao,
        a.url,
        a.tipo,
        a.perm_acesso,
        a.tam_bytes,
        a.id_user
    FROM arquivo a
    WHERE a.id_user = user_id
       OR EXISTS (
           SELECT 1 FROM compartilhamento c 
           WHERE c.id_arq = a.id_arq AND c.id_destinatario = user_id
       );
END //

CREATE PROCEDURE HistoricoUsuario(IN user_id INT)
BEGIN
    SELECT 
        h.data_ AS data,
        h.hora,
        h.operacao,
        h.cont_mudado AS conteudo_alterado
    FROM historico h
    JOIN arquivo a ON h.id_arq = a.id_arq
    WHERE a.id_user = user_id
       OR EXISTS (
           SELECT 1 FROM compartilhamento c 
           WHERE c.id_arq = a.id_arq AND c.id_destinatario = user_id
       );
END //


CREATE PROCEDURE AtividadesRecentesUsuario(IN user_id INT)
BEGIN
    SELECT 
        ar.id_arq,
        ar.nome,
        ar.ultima_mod,
        ar.hora,
        ar.localizacao,
        ar.url,
        ar.tipo,
        ar.perm_acesso,
        ar.tam_bytes,
        ar.id_user
    FROM arquivo ar
    JOIN atividades_recentes ar_ativ ON ar.id_arq = ar_ativ.id_arquivo
    WHERE ar.id_user = user_id
       OR EXISTS (
           SELECT 1 FROM compartilhamento c 
           WHERE c.id_arq = ar.id_arq AND c.id_destinatario = user_id
       );
END //


CREATE PROCEDURE Chavear(IN arquivo_id INT)
BEGIN
    UPDATE arquivo
    SET perm_acesso = CASE
        WHEN perm_acesso = 'Proprietário' THEN 'Convidado'
        ELSE 'Proprietário'
    END
    WHERE id_arq = arquivo_id;
END //


CREATE PROCEDURE Remover_acessos(IN arquivo_id INT)
BEGIN
    DELETE FROM compartilhamento
    WHERE id_arq = arquivo_id
      AND id_destinatario <> (SELECT id_user FROM arquivo WHERE id_arq = arquivo_id);
END //

DELIMITER ;


-- ROLES E USUÁRIOS

-- Remover roles se já existirem
DROP ROLE IF EXISTS PapelUsuario;
DROP ROLE IF EXISTS PapelEmpresa;
DROP ROLE IF EXISTS PapelAdm;

-- Criar roles
CREATE ROLE PapelUsuario;
CREATE ROLE PapelEmpresa;
CREATE ROLE PapelAdm;

-- Conceder permissões aos roles
GRANT SELECT, INSERT, UPDATE ON webdriver.arquivo TO PapelUsuario;
GRANT SELECT ON webdriver.usuario TO PapelEmpresa;
GRANT SELECT ON webdriver.arquivo TO PapelEmpresa;
GRANT ALL PRIVILEGES ON webdriver.* TO PapelAdm;

-- Remover usuários se já existirem
DROP USER IF EXISTS 'Luquinhas14'@'localhost';
DROP USER IF EXISTS 'Amorinha'@'localhost';
DROP USER IF EXISTS 'Letty'@'localhost';

-- Criar usuários
CREATE USER 'Luquinhas14'@'localhost' IDENTIFIED BY 'ben10';
CREATE USER 'Amorinha'@'localhost' IDENTIFIED BY 'amora';
CREATE USER 'Letty'@'localhost' IDENTIFIED BY 'let123';

-- Atribuir roles aos usuários
GRANT PapelUsuario TO 'Luquinhas14'@'localhost';
GRANT PapelUsuario TO 'Amorinha'@'localhost';
GRANT PapelAdm TO 'Letty'@'localhost';

-- VIEWS
DROP VIEW IF EXISTS VisaoUsuario;

CREATE VIEW VisaoUsuario AS
SELECT 
    a.id_arq,
    a.nome,
    a.tipo,
    a.perm_acesso,
    a.tam_bytes,
    a.ultima_mod,
    a.hora,
    a.localizacao,
    a.url,
    a.id_user AS dono,
    c.id_destinatario
FROM arquivo a
LEFT JOIN compartilhamento c ON a.id_arq = c.id_arq;

DROP VIEW IF EXISTS VisaoAdm;
CREATE VIEW VisaoAdm AS
SELECT 
    id_arq,
    nome,
    tipo,
    perm_acesso,
    tam_bytes,
    ultima_mod,
    hora,
    localizacao,
    url,
    id_user
FROM arquivo;

DROP VIEW IF EXISTS HistoricoCompleto;
CREATE VIEW HistoricoCompleto AS
SELECT 
    h.id_hist,
    h.data_,
    h.hora,
    h.operacao,
    h.cont_mudado,
    h.id_arq
FROM historico h;

-- TRIGGERS
DELIMITER //

CREATE TRIGGER Safe_security BEFORE INSERT ON arquivo
FOR EACH ROW
BEGIN
    IF LOWER(NEW.tipo) = 'exe' THEN
       SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Proibido a inserção de arquivos executáveis';
    END IF;
END;//

CREATE TRIGGER Registrar_operacao AFTER INSERT ON opera
FOR EACH ROW
BEGIN
    UPDATE atividades_recentes
    SET ultima_versao = NEW.data_
    WHERE id_arquivo = NEW.id_arq;
END;//

DELIMITER ;

INSERT INTO plano (nome, duracao, aquisicao, espaco_user)
VALUES ('Plano Básico', 30, CURDATE(), '5GB');
SELECT * FROM plano;

INSERT INTO instituicao (nome, causa_social, email, endereco, id_plano)
VALUES (
  'Instituição Exemplo',
  'Educação para Todos',
  'inst@email.com',
  'Rua Exemplo, 123',
  1
);
SELECT * FROM instituicao;
INSERT INTO usuario (login, senha, email, data_ingresso, id_ins)
VALUES ('admin', '1234', 'admin@email.com', CURDATE(), 1);

INSERT INTO administrador (id_user)
SELECT id_user FROM usuario WHERE login = 'admin';
SELECT * FROM usuario;
SELECT * FROM administrador;

INSERT INTO usuario (login, senha, email, data_ingresso, id_ins)
VALUES ('usuario1', 'senha123', 'usuario1@email.com', CURDATE(), 1);
SELECT * FROM instituicao;
SELECT * FROM usuario;
INSERT INTO arquivo (nome, tipo, perm_acesso, tam_bytes, ultima_mod, hora, localizacao, url, id_user)
VALUES 
('documento1.pdf', 'pdf', 'Proprietário', 1024, CURDATE(), CURTIME(), '/meus_documentos', 'http://url1.com', 2),
('foto1.jpg', 'jpg', 'Proprietário', 2048, CURDATE(), CURTIME(), '/minhas_fotos', 'http://url2.com', 2);
INSERT INTO compartilhamento (id_destinatario, id_dono, id_arq, data_)
VALUES (2, 1, 1, CURDATE());
