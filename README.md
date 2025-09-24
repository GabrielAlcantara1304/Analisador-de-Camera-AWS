# 🤖 Analisador de Câmera: Detecção de Dedos em Tempo Real + AWS

Sistema end-to-end que detecta quantos dedos você levanta usando a webcam, processa eventos em tempo real na AWS e armazena histórico para análise.

## 🎯 O que faz

- **Detecção em tempo real** com Python, OpenCV e MediaPipe
- **Streaming de eventos** para AWS Kinesis Data Streams (JSON: `{"dedos": x}`)
- **Processamento serverless** com AWS Lambda ("Você levantou x dedos" nos logs)
- **Armazenamento persistente** via Kinesis Firehose no Amazon S3
- **Infraestrutura como código** com Terraform

## 🏗️ Arquitetura

```
Webcam → Python/OpenCV/MediaPipe → Kinesis Data Stream → 
├── Lambda (processamento/monitoramento)
└── Firehose → S3 (data lake)
```

## 🚀 Tecnologias

- **Frontend**: Python 3.11, OpenCV, MediaPipe
- **Cloud**: AWS Kinesis, Lambda, Firehose, S3
- **IaC**: Terraform
- **Detecção**: Landmarks de mão com algoritmo customizado

## 📋 Pré-requisitos

- Python 3.11+ (x64)
- AWS CLI configurado
- Terraform 1.6+
- Câmera funcional

## 🛠️ Instalação e Deploy

### 1. Clone o repositório
```bash
git clone https://github.com/GabrielAlcantara1304/Analisador-de-Camera-AWS.git
cd Analisador-de-Camera-AWS
```

### 2. Deploy da infraestrutura
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 3. Configure credenciais
```bash
# Opção A: Use suas credenciais padrão
aws configure

# Opção B: Use o usuário criado pelo Terraform
terraform output producer_access_key_id
terraform output producer_secret_access_key
```

### 4. Execute o aplicativo
```bash
cd python
python -m venv .venv
.\.venv\Scripts\activate  # Windows
pip install -r requirements.txt

# Configure variáveis de ambiente
$env:KINESIS_STREAM_NAME = "$(terraform -chdir=..\terraform output -raw kinesis_stream_name)"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Execute
python app.py
```

## 📊 Monitoramento

### Logs do Lambda
```bash
aws logs tail /aws/lambda/$(terraform -chdir=terraform output -raw lambda_function_name) --follow
```

### Dados no S3
```bash
aws s3 ls s3://$(terraform -chdir=terraform output -raw s3_bucket_name) --recursive
```

### Stream do Kinesis
```bash
aws kinesis describe-stream-summary --stream-name $(terraform -chdir=terraform output -raw kinesis_stream_name)
```

## 🔧 Configuração

### Variáveis de ambiente
- `KINESIS_STREAM_NAME`: Nome do stream (padrão: `hand-gestures-stream`)
- `AWS_DEFAULT_REGION`: Região AWS (padrão: `us-east-1`)
- `MIN_SEND_INTERVAL_SEC`: Intervalo mínimo entre envios (padrão: `0.2`)

### Personalização
- Ajuste `MIN_SEND_INTERVAL_SEC` para controlar frequência de envio
- Modifique `project_name` no `terraform/variables.tf`
- Configure `kinesis_shard_count` para escalabilidade

## 🎮 Como usar

1. Execute `python app.py`
2. Posicione sua mão na frente da câmera
3. Levante 1-5 dedos
4. Veja a contagem em tempo real na janela
5. Pressione `q` para sair

## 🔍 Algoritmo de detecção

- **Polegar**: Compara coordenada X do tip (4) com IP (3) baseado na mão (Left/Right)
- **Outros dedos**: Compara coordenada Y do tip com PIP (tip acima = dedo levantado)
- **Suporte**: Mão esquerda e direita com detecção automática

## 🚀 Evoluções possíveis

### Integração com EventBridge
- Roteamento por regras (ex.: 5 dedos → "ok")
- Fan-out para múltiplos destinos (Lambda, SQS, SNS)
- Agendamentos com EventBridge Scheduler
- Pipelines com EventBridge Pipes

### Analytics e ML
- Dashboards em tempo real (QuickSight)
- Modelos ML com SageMaker (gestos complexos)
- ETL com Glue Jobs
- Busca com OpenSearch

### APIs e Integração
- API Gateway para métricas REST
- WebRTC para streaming de vídeo
- IoT Core para múltiplos dispositivos
- Step Functions para orquestração

## 📁 Estrutura do projeto

```
├── python/
│   ├── app.py              # Aplicação principal
│   └── requirements.txt    # Dependências Python
├── lambda/
│   └── handler.py          # Função Lambda
├── terraform/
│   ├── main.tf            # Recursos AWS
│   ├── variables.tf       # Variáveis
│   ├── outputs.tf         # Outputs
│   └── versions.tf        # Versões providers
├── .gitignore             # Arquivos ignorados
└── README.md              # Este arquivo
```

## 🧹 Limpeza

```bash
cd terraform
terraform destroy -auto-approve
```

## 📝 Formato dos dados

### Evento no Kinesis
```json
{"dedos": 3}
```

### Log do Lambda
```
INFO: Você levantou 3 dedos
```

### Arquivo no S3 (via Firehose)
```
{"dedos": 3}
{"dedos": 2}
{"dedos": 5}
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para detalhes.

## 👨‍💻 Autor

**Gabriel Alcântara**
- GitHub: [@GabrielAlcantara1304](https://github.com/GabrielAlcantara1304)
- LinkedIn: [Gabriel Alcântara](https://linkedin.com/in/gabrielhein6)

## 🙏 Agradecimentos

- MediaPipe pela detecção de landmarks
- AWS pelos serviços serverless
- Comunidade open source

---

⭐ **Se este projeto te ajudou, considere dar uma estrela!**