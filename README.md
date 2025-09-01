# Observabilidade Ruby On Rails

Estes docker servem para criar a observabilidade de API, Banco de Dados ( Postgres ), Docker UP e DOWN, saúde dos containers, Redis, Sidekiq , RabbitMQ , Grafana e Prometheus.


# Essas GEM devem ser adcionadas ao projeto no Gemfile

- gem "prometheus_exporter"
- gem "yabeda"
- gem "yabeda-prometheus"
- gem "yabeda-rails"
- gem "yabeda-http_requests"
- gem "yabeda-puma-plugin"
- gem "sidekiq-prometheus-exporter"

# Na pasta Infra/Observability/Config 

Conforme suas documentações 
- elasticsearch
- filebeat
- grafana
- kibana
- loki
- prometheus
- promtail 

# Na pasta Infra/Obervability

- Customizei um arquivo custom_metrics_server.py
- custom_metrics_server.sh
- custom_monitor.sh 

Estes são metricas customizadas, podendo ser ajustadas e criada novas a sua vontade

# Como Rodar 
Estando em infra/observability

Subir os containers

```sh 
  docker compose -f docker-compose.observality.yml 
```

Para configurar e instalar o bkp automatizado pelo N8N

```sh 
  docker compose -f  docker-compose.n8n.yml
```

### Em Construção o PASSO A PASSO
