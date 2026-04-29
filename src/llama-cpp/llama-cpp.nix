{
  pkgs,
  domain,
  ...
}:
let
  llamaModel = pkgs.fetchurl {
    name = "llama-3.1-8b-instruct-q4-k-m.gguf";
    url = "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/bf5b95e96dac0462e2a09145ec66cae9a3f12067/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf";
    hash = "sha256-ewZPWEK/lTLJFFbe2iiKG2cjl6VPpymqZllShjAzVXw=";
  };
  localPort = 8080;
  sslCertificatePath = "/etc/evident/pki/instance/public/instance.crt.pem";
  failoverSslCertificatePath = "/etc/evident/pki/instance/public/instance-root.crt.pem";
  sslCertificateKeyPath = "/etc/evident/pki/instance/private/instance.key.der";
  username = "worker";

  tlsDir = "/var/lib/nginx-tls";
  workerCert = "${tlsDir}/worker.crt";
  workerKey = "${tlsDir}/worker.key";
  workerCsr = "${tlsDir}/worker.csr";

  generateWorkerCert = pkgs.writeShellScript "generate-worker-cert" ''
    CA_CERT="${sslCertificatePath}"
    if [ ! -f "$CA_CERT" ]; then
      echo "Using self-signed CA certificate as fallback since $CA_CERT is missing"
      CA_CERT="${failoverSslCertificatePath}"
    fi

    CA_KEY="${sslCertificateKeyPath}"
    DOMAIN="${domain}"
    OUT_DIR="${tlsDir}"
    WORKER_KEY="${workerKey}"
    WORKER_CSR="${workerCsr}"
    WORKER_CERT="${workerCert}"

    set -uo pipefail

    mkdir -p "$OUT_DIR"

    ${pkgs.openssl}/bin/openssl genrsa -out "$WORKER_KEY" 4096

    ${pkgs.openssl}/bin/openssl req -new \
        -key "$WORKER_KEY" \
        -subj "/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN" \
        -out "$WORKER_CSR"
    ${pkgs.openssl}/bin/openssl x509 -req \
        -in "$WORKER_CSR" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -days 120 \
        -sha256 \
        -copy_extensions copyall \
        -out "$WORKER_CERT"

    cat "$CA_CERT" >> "$WORKER_CERT"

    chown -R nginx:nginx "$WORKER_KEY" "$WORKER_CERT" "$OUT_DIR"
    chmod 600 "$WORKER_KEY" "$WORKER_CERT"

    rm -f "$WORKER_CSR"
  '';
in
{
  # Configure the llama-cpp specific user

  users.users.${username} = {
    createHome = false;
    isSystemUser = true;
    group = "worker";
    shell = "${pkgs.shadow}/bin/nologin";
  };
  users.groups.worker = {};

  # Configure the llama-cpp server as a systemd service

  systemd.services.generate-worker-cert = {
      description = "Generate TLS worker certificate from root CA";
      after = [ "evident-server.service" ];
      requires = [ "evident-server.service" ];
      before = [ "nginx.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = generateWorkerCert;
        UMask = "0077";
        User = "root";
      };
    };

  systemd.services.llama-cpp = {
    description = "LLaMA.cpp Server";
    after = [ "network.target" "evident-server.service" ];
    requires = [ "evident-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.llama-cpp}/bin/llama-server --model ${llamaModel} --port ${toString localPort}";
      User = "${username}";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "300s";
    };
  };

  # nginx configuration to terminate TLS and proxy to the llama-cpp server
  services.nginx = {
    enable = true;

    # Disable the default nginx server that listens on 80
    virtualHosts."_default_" = {
      default = true;
      rejectSSL = true;
      extraConfig = "return 444;";
    };

    virtualHosts.${domain} = {
      onlySSL = true;  # no plain HTTP at all, not even to redirect
      sslCertificate = workerCert;
      sslCertificateKey = workerKey;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString localPort}";
        proxyWebsockets = true;  # llama.cpp supports ws for streaming
        extraConfig = ''
          proxy_read_timeout 300s;  # LLM responses can be slow
          proxy_buffering off;      # required for streaming tokens
        '';
      };
    };
  };

  # Ensure nginx starts after llama.cpp
  systemd.services.nginx = {
    after = [ "llama-cpp.service" "generate-worker-cert.service" ];
    requires = [ "llama-cpp.service" "generate-worker-cert.service" ];
    wantedBy = [ "multi-user.target" ];
  };

  networking.firewall.allowedTCPPorts = [
    443
  ];
}
