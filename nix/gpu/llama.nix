{ config, pkgs, pkgs-unstable, ... }:

let
  ggufPath = "/home/hans/.lmstudio/models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-IQ3_XXS.gguf";
in
{
  environment.systemPackages = [ 
    (pkgs-unstable.llama-cpp.override { cudaSupport = true; })
  ];

  systemd.services.llama-server = {
    description = "llama-server - Qwen3.6 IQ3_XXS";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs-unstable.llama-cpp.override { cudaSupport = true; }}/bin/llama-server \
          --model          ${ggufPath} \
          --host           0.0.0.0 \
          --port           8080 \
          --n-gpu-layers   999 \
          --ctx-size       32768 \
          --chat-template-kwargs '{"preserve_thinking": true}'
      '';
      Restart        = "on-failure";
      StateDirectory = "llama";
      SupplementaryGroups = [ "video" "render" ];
    };
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    package  = pkgs-unstable.open-webui;
    environment = {
      OLLAMA_API_BASE_URL = "http://disabled";   # disable ollama
      OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
      OPENAI_API_KEY      = "not-needed";        # llama-server doesn't auth
      WEBUI_AUTH          = "false";             # skip login for local use
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 8080 ];
}