## Dentro da VM
1. git clone https://github.com/eduardoSantiag0/hackaton-setup
1. chmod +x keygen.sh
1. chmod +x configurar-grupos.sh
1. ``./admin/configurar-grupos.sh <IP DA MAQUINA> <NUMERO GRUPOS> 51820``
1. sudo docker compose up -d
1. Enviar email para os participantes que ficarão na pasta admin/emails


### configurar-grupos.sh gera: 
- Chave privada do WireGuard em admin/wg0.config.
- Gera a chave publica a partir da priv
- Gera um par de chaves para cada grupo. As privadas são armazenadas em admin/chaves-privadas/grupoN-privkey.txt.
- Adiciona uma seção [Peer] ao admin/wg0.config para cada grupo, contendo sua chave pública e seu IP VPN autorizado.
Cada grupo executa: 
- Atribui um endereço a cada grupo
- Calcula o IP correspondente de cada container (enviado como GRUPO_CONTAINER_IP)
- Gera admin/emails/grupoN.txt, contendo instruções e as seis variáveis necessárias para a conexão: PRIVATE_KEY, ADDRESS, SERVER_PUBLIC_KEY, ENDPOINT, ALLOWED_IPS e GRUPO_CONTAINER_IP

### Cada grupo deve:
- Copiar o bloco do email para grupo-template/.env
- Executar ./gerar-conf.sh (gera o wg0.conf a partir do .env)
- Executar `docker compose up -d` (assim não precisa instalar o WireGuard na máquina deles)
- Acessar a aplicação do grupo em http://localhost:8080 (a app do grupo
  precisa escutar na porta 8080 dentro do container deles, convenção fixa)

Link para template dos pariticpantes: 
- [https://github.com/eduardoSantiag0/hackaton-participante/](https://github.com/eduardoSantiag0/hackaton-participante)


### Arquitetura da infraestrutura

**Template dos participantes:**
[hackaton-participante](https://github.com/eduardoSantiag0/hackaton-participante/)

```mermaid
flowchart TB
    subgraph PARTICIPANTES["Computadores dos participantes"]
        direction LR

        subgraph G1["Equipe 1 - Docker Compose"]
            B1["localhost:8080"] --> S1["Proxy socat"]
            S1 --> W1["Cliente WireGuard"]
        end

        subgraph G2["Equipe 2 - Docker Compose"]
            B2["localhost:8080"] --> S2["Proxy socat"]
            S2 --> W2["Cliente WireGuard"]
        end
    end

    INTERNET(("Internet"))

    subgraph VM["VM do Organizador - IP Publico"]
        WG["Servidor WireGuard - UDP 51820"]

        subgraph DOCKER["Docker Network - 172.28.10.0/24"]
            APP1["Container Grupo 1 - 172.28.10.11"]
            APP2["Container Grupo 2 - 172.28.10.12"]
            APPN["Container Grupo N"]
        end

        WG --> APP1
        WG --> APP2
        WG -.-> APPN
    end

    W1 <--> INTERNET
    W2 <--> INTERNET
    INTERNET <-->|UDP 51820| WG

    classDef vpn fill:#dbeafe,stroke:#2563eb,color:#1e40af
    classDef container fill:#dcfce7,stroke:#16a34a,color:#166534
    classDef proxy fill:#fef3c7,stroke:#d97706,color:#92400e

    class W1,W2,WG vpn
    class APP1,APP2,APPN container
    class S1,S2 proxy
```

