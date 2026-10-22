/*
  base de chat segun el MER (inelco_chat_db)

  la base se crea aparte, una sola vez:
    psql -U postgres -c "CREATE DATABASE inelco_chat_db"

  y despues se corre este script dentro de ella:
    psql -U postgres -d inelco_chat_db -f inelco_chat_db.sql

  se puede ejecutar varias veces, las tablas y los datos iniciales no se duplican
*/

-- enum del MER: quien envio el mensaje
DO $$ BEGIN
    CREATE TYPE enum_tipo_remitente AS ENUM ('usuario', 'ia', 'sistema');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


/*
  roles dentro del chat

  no son los permisos del sistema, solo el papel que tiene cada uno en una sala.
*/
CREATE TABLE IF NOT EXISTS roles_chat (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);


/*
  chat / sala

  hay una sala por consulta, por eso consulta_id es unique (relacion "origina" 1 a 1 del MER).
  el id de la consulta llega por evento desde tickets y no lleva fk porque esa tabla
  esta en otra base. fecha_fin queda en null mientras la sala sigue abierta.
*/
CREATE TABLE IF NOT EXISTS chats (
    id SERIAL PRIMARY KEY,
    consulta_id INTEGER NOT NULL UNIQUE,
    fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMPTZ NULL
);


/*
  participantes de la sala

  usuario_id es referencia logica a inelco_users_db (usuarios.id). una persona no puede
  estar dos veces en la misma sala.
*/
CREATE TABLE IF NOT EXISTS participantes (
    id SERIAL PRIMARY KEY,
    chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL,
    rol_chat_id INTEGER NOT NULL REFERENCES roles_chat(id),
    UNIQUE (chat_id, usuario_id)
);


/*
  mensajes

  usuario_id es null cuando escribe la ia o el sistema, por eso existe tipo_remitente
  para distinguir de quien es cada mensaje.
*/
CREATE TABLE IF NOT EXISTS mensajes (
    id SERIAL PRIMARY KEY,
    chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    usuario_id UUID NULL,
    tipo_remitente enum_tipo_remitente NOT NULL,
    contenido TEXT NOT NULL,
    fecha_envio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- indice para paginar el historial de una sala ordenado por fecha (GET /chats/{id}/mensajes)
CREATE INDEX IF NOT EXISTS idx_mensajes_chat_fecha ON mensajes (chat_id, fecha_envio);


/*
  galeria unificada de adjuntos

  aca solo se guarda la url, el archivo en si vive en el almacenamiento externo.
  tipo_archivo es el mime type y tamano esta en bytes.
*/
CREATE TABLE IF NOT EXISTS adjuntos (
    id SERIAL PRIMARY KEY,
    mensaje_id INTEGER NOT NULL REFERENCES mensajes(id) ON DELETE CASCADE,
    url_almacenamiento TEXT NOT NULL,
    nombre_archivo VARCHAR(255) NOT NULL,
    tipo_archivo VARCHAR(100) NOT NULL,
    tamano INTEGER NOT NULL,
    fecha_carga TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


/*
  datos iniciales

  los roles tienen que existir antes de crear el primer participante.
*/
INSERT INTO roles_chat (nombre) VALUES
    ('Cliente'),
    ('Tecnico'),
    ('IA'),
    ('Supervisor')
ON CONFLICT (nombre) DO NOTHING;
