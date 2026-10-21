/*
  base de chat (salas, participantes, mensajes, adjuntos)

  la base se crea aparte, una sola vez:
    psql -U postgres -c "CREATE DATABASE inelco_chat_db"

  y despues se corre este script dentro de ella:
    psql -U postgres -d inelco_chat_db -f inelco_chat_db.sql

  desde psql tambien sirve: \c inelco_chat_db y luego \i inelco_chat_db.sql
  se puede ejecutar varias veces, las tablas y los roles iniciales no se duplican
*/

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


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

  hay una sala por consulta, por eso consulta_id es unique. el id de la consulta llega
  por evento desde tickets y no lleva fk porque esa tabla esta en otra base.
  fecha_fin queda en null mientras la sala sigue abierta.
*/
CREATE TABLE IF NOT EXISTS chats (
    id SERIAL PRIMARY KEY,
    consulta_id INTEGER NOT NULL UNIQUE,
    fecha_inicio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMP WITH TIME ZONE NULL
);


/*
  participantes de la sala

  usuario_id es referencia logica a inelco_users_db. una persona no puede estar dos
  veces en la misma sala.
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
    tipo_remitente VARCHAR(20) NOT NULL CHECK (tipo_remitente IN ('usuario', 'ia', 'sistema')),
    contenido TEXT NOT NULL,
    fecha_envio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


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
    fecha_carga TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
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
