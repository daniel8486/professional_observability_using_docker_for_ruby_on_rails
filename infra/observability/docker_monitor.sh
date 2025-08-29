#!/bin/bash

# Diretório base dos logs
BASE_LOG_DIR="/var/log/docker-monitor"
DATE_DIR=$(date +'%Y-%m-%d')
TIME_FILE=$(date +'%H-%M')
LOG_FILE="$BASE_LOG_DIR/$DATE_DIR/$TIME_FILE.log"

mkdir -p "$BASE_LOG_DIR/$DATE_DIR"

echo "===== [$(date '+%Y-%m-%d %H:%M:%S')] Docker Monitor =====" >> "$LOG_FILE"

containers=$(docker ps -a --format '{{.ID}} {{.Names}}')

while read -r line; do
  container_id=$(echo $line | awk '{print $1}')
  container_name=$(echo $line | awk '{print $2}')

  status=$(docker inspect -f '{{.State.Status}}' "$container_id")
  health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container_id")
  started_at=$(docker inspect -f '{{.State.StartedAt}}' "$container_id")
  finished_at=$(docker inspect -f '{{.State.FinishedAt}}' "$container_id")
  networks=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container_id")
  echo "  Redes: $networks" >> "$LOG_FILE"
  
  for net in $networks; do
   connected=$(docker network inspect "$net" --format '{{range .Containers}}{{.Name}} {{end}}')
   echo "  Network: $net | Containers: $connected" >> "$LOG_FILE"
  done

  echo "Container: $container_name" >> "$LOG_FILE"
  echo "  ID: $container_id" >> "$LOG_FILE"
  echo "  Status: $status" >> "$LOG_FILE"
  echo "  Health: $health" >> "$LOG_FILE"
  echo "  StartedAt: $started_at" >> "$LOG_FILE"
  echo "  Redes: $networks" >> "$LOG_FILE"

  if [ "$status" != "running" ]; then
    echo "  StoppedAt: $finished_at" >> "$LOG_FILE"
    reason=$(docker inspect -f '{{.State.ExitCode}} - {{.State.Error}}' "$container_id")
    echo "  Parado (possível motivo): $reason" >> "$LOG_FILE"
  fi

  echo "  >>> Últimos 5 logs:" >> "$LOG_FILE"
  docker logs --tail 5 "$container_id" 2>&1 | sed 's/^/    /' >> "$LOG_FILE"
  echo "--------------------------------------------------" >> "$LOG_FILE"
done <<< "$containers"

## Chama o crontrab -e no servidor para agendar a execução deste script

# Exemplo de agendamento:

# * * * * * /var/log/docker_monitor.sh
# * * * * * sleep 30 && /var/log/docker_monitor.sh