import mysql.connector
from getpass import getpass
from mysql.connector import Error

def create_db_connection(host_name, user_name, user_password, db_name):
    connection = None
    try:
        connection = mysql.connector.connect(
            host=host_name,
            user=user_name,
            passwd=user_password,
            database=db_name
        )
        print("✅ Conexão com o banco de dados realizada com sucesso")
    except Error as err:
        print(f"❌ Erro na conexão com o banco de dados: {err}")
    return connection

# Descobrir se o usuário logado é um administrador
def descobrir_tipo_usuario(conn, login):
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id_user FROM usuario WHERE login = %s", (login,))
        resultado = cursor.fetchone()
        if resultado:
            id_user = resultado[0]
            cursor.execute("SELECT * FROM administrador WHERE id_user = %s", (id_user,))
            if cursor.fetchone():
                return "admin"
            else:
                return "usuario"
        else:
            return None
    except mysql.connector.Error as err:
        print(f"Erro ao verificar tipo de usuário: {err}")
        return None

# Menu para administrador
def menu_administrador(conn):
    while True:
        print("\n📁 Menu do Administrador")
        print("1. Listar todos os usuários")
        print("2. Listar todos os arquivos")
        print("3. Sair")

        opcao = input("Escolha uma opção: ")

        if opcao == "1":
            listar_usuarios(conn)
        elif opcao == "2":
            listar_arquivos(conn)
        elif opcao == "3":
            print("Saindo do menu de administrador.")
            break
        else:
            print("❌ Opção inválida.")

# Menu para usuário comum
def menu_usuario(conn, login):
    while True:
        print("\n📂 Menu do Usuário")
        print("1. Listar meus arquivos")
        print("2. Ver meus compartilhamentos")
        print("3. Sair")

        opcao = input("Escolha uma opção: ")

        if opcao == "1":
            listar_arquivos_usuario(conn, login)
        elif opcao == "2":
            listar_compartilhamentos_usuario(conn, login)
        elif opcao == "3":
            print("Saindo do menu de usuário.")
            break
        else:
            print("❌ Opção inválida.")

# Listar todos os usuários (admin)
def listar_usuarios(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT id_user, login, email, data_ingresso FROM usuario")
    for row in cursor.fetchall():
        print(row)

# Listar todos os arquivos (admin)
def listar_arquivos(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT id_arq, nome, tipo, perm_acesso, tam_bytes FROM arquivo")
    for row in cursor.fetchall():
        print(row)

# Listar arquivos do usuário logado
def listar_arquivos_usuario(conn, login):
    cursor = conn.cursor()
    cursor.execute("SELECT id_user FROM usuario WHERE login = %s", (login,))
    user = cursor.fetchone()
    if not user:
        print("❌ Usuário não encontrado.")
        return
    id_user = user[0]

    query = """
        SELECT id_arq, nome, tipo, perm_acesso, ultima_mod, localizacao, url 
        FROM arquivo 
        WHERE id_user = %s
           OR id_arq IN (SELECT id_arq FROM compartilhamento WHERE id_destinatario = %s)
    """
    cursor.execute(query, (id_user, id_user))
    arquivos = cursor.fetchall()

    if not arquivos:
        print("📁 Nenhum arquivo encontrado.")
    else:
        for arq in arquivos:
            print(arq)

# Listar arquivos compartilhados com o usuário
def listar_compartilhamentos_usuario(conn, login):
    cursor = conn.cursor()
    cursor.execute("SELECT id_user FROM usuario WHERE login = %s", (login,))
    user = cursor.fetchone()
    if not user:
        print("❌ Usuário não encontrado.")
        return
    id_user = user[0]

    query = """
        SELECT a.nome, a.tipo, a.url, c.data_
        FROM compartilhamento c
        JOIN arquivo a ON c.id_arq = a.id_arq
        WHERE c.id_destinatario = %s
    """
    cursor.execute(query, (id_user,))
    compartilhados = cursor.fetchall()

    if not compartilhados:
        print("🔐 Nenhum arquivo compartilhado com você.")
    else:
        for row in compartilhados:
            print(row)

def main():
    print("🔐 Bem-vindo ao sistema de arquivos")

    # Conecta com o MySQL já usando root e sua senha fixa
    conn = create_db_connection("localhost", "root", "My#Sql8427@", "webdriver")
    if conn is None:
        print("❌ Não foi possível conectar ao banco de dados.")
        return

    try:
        login = input("🔑 Digite seu login de acesso: ")
        senha = input("🔑 Digite sua senha de acesso: ")

        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM usuario WHERE login = %s AND senha = %s", (login, senha))
        usuario = cursor.fetchone()

        if usuario is None:
            print("❌ Login ou senha incorretos.")
            return

        tipo = descobrir_tipo_usuario(conn, login)
        print(f"✅ Login bem-sucedido. Tipo de usuário: {tipo}")

        if tipo == "admin":
            menu_administrador(conn)
        elif tipo == "usuario":
            menu_usuario(conn, login)
        else:
            print("❌ Tipo de usuário não reconhecido.")

    except mysql.connector.Error as err:
        print(f"Erro na conexão: {err}")

    finally:
        if conn.is_connected():
            conn.close()

if __name__ == "__main__":
    main()
