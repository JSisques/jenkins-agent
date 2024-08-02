#!/bin/bash

# Función para mostrar el uso del script
show_usage() {
    echo "Uso: $0 -jenkins_master_ip <JENKINS_MASTER_IP> -agent_secret <AGENT_SECRET>"
    echo ""
    echo "Descripción:"
    echo "  Este script configura un agente Jenkins en una Raspberry Pi."
    echo "  - Instala Java si no está presente."
    echo "  - Descarga el archivo agent.jar del servidor Jenkins master."
    echo "  - Configura el agente para que se inicie automáticamente al arranque del sistema."
    echo ""
    echo "Opciones:"
    echo "  -jenkins_master_ip <JENKINS_MASTER_IP>   La dirección IP o el nombre de dominio del servidor Jenkins master."
    echo "  -agent_secret <AGENT_SECRET>             El secreto del agente proporcionado por el servidor Jenkins master."
    echo "  --help                                  Muestra esta ayuda."
    exit 1
}

# Procesar argumentos
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -jenkins_master_ip) JENKINS_MASTER_IP="$2"; shift ;;
        -agent_secret) AGENT_SECRET="$2"; shift ;;
        --help) show_usage ;;
        *) show_usage ;;
    esac
    shift
done

# Verificar que se han proporcionado los parámetros necesarios
if [ -z "$JENKINS_MASTER_IP" ] || [ -z "$AGENT_SECRET" ]; then
    show_usage
fi

# Variables
JENKINS_AGENT_NAME="jenkins-agent"
JENKINS_AGENT_WORKDIR="/home/$USER/jenkins"
AGENT_JAR_URL="http://$JENKINS_MASTER_IP:8080/jnlpJars/agent.jar"
SSH_USER="$USER"

# Función para instalar Java
install_java() {
    echo "Instalando Java..."
    sudo apt-get update
    sudo apt-get install -y openjdk-11-jre-headless
}

# Función para descargar y configurar el agente Jenkins
configure_agent() {
    echo "Configurando el agente Jenkins..."

    # Crear el directorio de trabajo
    mkdir -p "$JENKINS_AGENT_WORKDIR"
    cd "$JENKINS_AGENT_WORKDIR" || { echo "Error al acceder al directorio $JENKINS_AGENT_WORKDIR"; exit 1; }

    # Descargar el archivo agent.jar
    echo "Descargando agent.jar desde $AGENT_JAR_URL..."
    wget "$AGENT_JAR_URL" -O agent.jar || { echo "Error al descargar agent.jar"; exit 1; }

    # Crear el script para iniciar el agente
    cat <<EOF > start-agent.sh
#!/bin/bash
echo "Iniciando el agente Jenkins..."
java -jar agent.jar -jnlpUrl http://$JENKINS_MASTER_IP:8080/computer/$JENKINS_AGENT_NAME/slave-agent.jnlp -secret $AGENT_SECRET -workDir $JENKINS_AGENT_WORKDIR
EOF

    # Hacer ejecutable el script
    chmod +x start-agent.sh

    # Crear un archivo de servicio systemd para ejecutar el agente al iniciar
    echo "Creando el archivo de servicio systemd..."
    cat <<EOF | sudo tee /etc/systemd/system/jenkins-agent.service
[Unit]
Description=Jenkins Agent Service
After=network.target

[Service]
User=$SSH_USER
WorkingDirectory=$JENKINS_AGENT_WORKDIR
ExecStart=/bin/bash $JENKINS_AGENT_WORKDIR/start-agent.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Habilitar y arrancar el servicio
    echo "Habilitando y arrancando el servicio Jenkins Agent..."
    sudo systemctl daemon-reload
    sudo systemctl enable jenkins-agent
    sudo systemctl start jenkins-agent

    echo "El agente Jenkins ha sido configurado y está en ejecución."
}

# Main script execution
echo "Iniciando configuración del agente Jenkins..."

install_java
configure_agent

echo "Configuración completada con éxito."
