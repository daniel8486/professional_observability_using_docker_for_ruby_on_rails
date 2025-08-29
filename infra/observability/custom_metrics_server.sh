#!/bin/bash

STATE_FILE="/tmp/docker_containers_state.txt"
CURRENT_STATE=$(docker ps --format '{{.Names}} {{.Status}} {{.CreatedAt}}')

if [ ! -f "$STATE_FILE" ]; then
  echo "$CURRENT_STATE" > "$STATE_FILE"
fi

PREV_STATE=$(cat "$STATE_FILE")

if [ "$CURRENT_STATE" != "$PREV_STATE" ]; then
  echo "$CURRENT_STATE" > "$STATE_FILE"
  # Só exporta as métricas se houve mudança
  docker ps --format '{{.Names}} {{.Status}} {{.CreatedAt}}' | while read -r name status created; do
    echo "custom_docker_names_statuses{name=\"$name\",status=\"$status\",created=\"$created\"} 1"
  done
fi

PG_CONN_STATE_FILE="/tmp/pg_connections_state.txt"
CURRENT_PG_CONN_STATE=$(PGPASSWORD="SEUPASSWORD" \
psql -h localhost -U postgres -d seuBancodeDados -t -A -F',' \
-c "SELECT pid, usename, client_addr, application_name, state, query_start FROM pg_stat_activity WHERE client_addr IS NOT NULL;")

if [ ! -f "$PG_CONN_STATE_FILE" ]; then
  echo "$CURRENT_PG_CONN_STATE" > "$PG_CONN_STATE_FILE"
fi

PREV_PG_CONN_STATE=$(cat "$PG_CONN_STATE_FILE")

if [ "$CURRENT_PG_CONN_STATE" != "$PREV_PG_CONN_STATE" ]; then
  echo "$CURRENT_PG_CONN_STATE" > "$PG_CONN_STATE_FILE"
  echo "$CURRENT_PG_CONN_STATE" | while IFS=',' read -r pid usename client_addr application_name state query_start; do
    echo "custom_pg_connection_detail{pid=\"$pid\",user=\"$usename\",ip=\"$client_addr\",app=\"$application_name\",state=\"$state\",query_start=\"$query_start\"} 1"
  done
fi

PG_CONN_IP_STATE_FILE="/tmp/pg_conn_ips_state.txt"
CURRENT_PG_CONN_IP_STATE=$(PGPASSWORD="SEUPASSWORD" \
psql -h localhost -U postgres -d seuBancodeDados -t -A \
-c "SELECT client_addr FROM pg_stat_activity WHERE client_addr IS NOT NULL;" | xargs)

if [ ! -f "$PG_CONN_IP_STATE_FILE" ]; then
  echo "$CURRENT_PG_CONN_IP_STATE" > "$PG_CONN_IP_STATE_FILE"
fi

PREV_PG_CONN_IP_STATE=$(cat "$PG_CONN_IP_STATE_FILE")

if [ "$CURRENT_PG_CONN_IP_STATE" != "$PREV_PG_CONN_IP_STATE" ]; then
  echo "$CURRENT_PG_CONN_IP_STATE" > "$PG_CONN_IP_STATE_FILE"
  for ip in $CURRENT_PG_CONN_IP_STATE; do
    echo "custom_pg_connection_ip{ip=\"$ip\"} 1"
  done
fi


# Uptime do servidor (em segundos)
uptime_seconds=$(awk '{print int($1)}' /proc/uptime)

# Downtime: timestamp do último boot
last_boot=$(who -b | awk '{print $3 " " $4}')

# Uptime do banco Postgres (em segundos)
pg_uptime=$(ps -eo etimes,cmd | grep '[p]ostgres' | awk '{print $1}' | sort -n | head -1)

# Containers Docker UP
docker_up=$(docker ps -q | wc -l)

# Containers Docker DOWN
docker_down=$(docker ps -a --filter "status=exited" -q | wc -l)

# Containers Docker names and statuses
# Exemplo: "container_name1 running 2023-10-01T12:00:00Z container_name2 exited 2023-10-01T12:05:
docker_names=$(docker ps --format '{{.Names}} {{.Status}} {{.CreatedAt}}')

# Conexões ativas ao Postgres
# Exemplo: "10" (número de conexões ativas)
pg_connections=$(PGPASSWORD="SEUPASSWORD" psql -h localhost -U postgres -d seuBancodeDados -t -c "SELECT count(*) FROM pg_stat_activity;" | xargs)

# Exporta os IPs das conexões ativas ao Postgres
# Exemplo: "192.168.0.1 192.168.0.2"
pg_conn_ips=$(PGPASSWORD="SEUPASSWORD" psql -h localhost -U postgres -d seuBancodeDados -t -c "SELECT client_addr FROM pg_stat_activity WHERE client_addr IS NOT NULL;" | xargs)
# Para cada container rodando, exporte nome, status e data de criação como labels

# while read -r name status created; do
#   echo "custom_docker_names_statuses{name=\"$name\",status=\"$status\",created=\"$created\"} 1"
# done < <(docker ps --format '{{.Names}} {{.Status}} {{.CreatedAt}}')

cat <<EOF
# HELP custom_uptime_seconds Uptime do servidor em segundos
# TYPE custom_uptime_seconds gauge
custom_uptime_seconds $uptime_seconds

# HELP custom_last_boot Último boot do servidor (string)
# TYPE custom_last_boot gauge
custom_last_boot 0

# HELP custom_pg_uptime_seconds Uptime do Postgres em segundos
# TYPE custom_pg_uptime_seconds gauge
custom_pg_uptime_seconds ${pg_uptime:-0}

# HELP custom_pg_connections Conexões ativas ao Postgres
# TYPE custom_pg_connections gauge
custom_pg_connections ${pg_connections:-0}

# HELP custom_pg_connection_ip IPs das conexões ativas ao Postgres
# TYPE custom_pg_connection_ip gauge

# HELP custom_docker_up Containers Docker UP
# TYPE custom_docker_up gauge
custom_docker_up $docker_up

# HELP custom_docker_down Containers Docker DOWN
# TYPE custom_docker_down gauge
custom_docker_down $docker_down

# HELP custom_docker_names_statuses Nomes e status dos containers Docker
# TYPE custom_docker_names_statuses gauge
EOF

# Exporta containers Docker SÓ se houver mudança
if [ "$CURRENT_STATE" != "$PREV_STATE" ]; then
  echo "$CURRENT_STATE" > "$STATE_FILE"
  echo "$CURRENT_STATE" | while read -r name status created; do
    echo "custom_docker_names_statuses{name=\"$name\",status=\"$status\",created=\"$created\"} 1"
  done
else
  cat "$STATE_FILE" | while read -r name status created; do
    echo "custom_docker_names_statuses{name=\"$name\",status=\"$status\",created=\"$created\"} 1"
  done
fi

# Exporta conexões detalhadas SÓ se houver mudança
if [ "$CURRENT_PG_CONN_STATE" != "$PREV_PG_CONN_STATE" ]; then
  echo "$CURRENT_PG_CONN_STATE" > "$PG_CONN_STATE_FILE"
  echo "$CURRENT_PG_CONN_STATE" | while IFS=',' read -r pid usename client_addr application_name state query_start; do
    echo "custom_pg_connection_detail{pid=\"$pid\",user=\"$usename\",ip=\"$client_addr\",app=\"$application_name\",state=\"$state\",query_start=\"$query_start\"} 1"
  done
else
  cat "$PG_CONN_STATE_FILE" | while IFS=',' read -r pid usename client_addr application_name state query_start; do
    echo "custom_pg_connection_detail{pid=\"$pid\",user=\"$usename\",ip=\"$client_addr\",app=\"$application_name\",state=\"$state\",query_start=\"$query_start\"} 1"
  done
fi

# Exporta IPs das conexões SÓ se houver mudança
if [ "$CURRENT_PG_CONN_IP_STATE" != "$PREV_PG_CONN_IP_STATE" ]; then
  echo "$CURRENT_PG_CONN_IP_STATE" > "$PG_CONN_IP_STATE_FILE"
  for ip in $CURRENT_PG_CONN_IP_STATE; do
    echo "custom_pg_connection_ip{ip=\"$ip\"} 1"
  done
else
  for ip in $PREV_PG_CONN_IP_STATE; do
    echo "custom_pg_connection_ip{ip=\"$ip\"} 1"
  done
fi