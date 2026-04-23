{ config, pkgs, pkgs-unstable, ... }:

let
  ggufPath = "/home/hans/.lmstudio/models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-IQ3_XXS.gguf";
  mcpConfig = pkgs.writeText "mcp-config.json" (builtins.toJSON {
    mcpServers = {
      searxng = {
        command = "${pkgs.nodejs}/bin/npx";
        args    = [ "-y" "mcp-searxng" ];
        env     = { SEARXNG_URL = "http://localhost:8081"; };
      };
      nixos = {
        command = "${pkgs.uv}/bin/uvx";
        args    = [ "mcp-nixos" ];
      };
    };
  });
in
{
  environment.systemPackages = [ 
    (pkgs-unstable.llama-cpp.override { cudaSupport = true; })
    pkgs.nodejs
    pkgs.uv
  ];

  systemd.services.mcp-proxy = {
    description = "MCP proxy for llama-server";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    path = [ pkgs.bash pkgs.nodejs pkgs.uv ]; 
    serviceConfig = {
      ExecStart = ''
        ${pkgs.uv}/bin/uvx mcp-proxy \
          --named-server-config ${mcpConfig} \
          --allow-origin "*" \
          --port 8001 \
          --reasoning-budget 4096 \
          --reasoning-budget-message "... thinking budget exceeded, let's answer now." \
          --stateless
      '';
      Restart = "on-failure";
    };
  };

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
          --chat-template-kwargs '{"preserve_thinking": true}' \
          --webui-mcp-proxy 
      '';
      Restart        = "on-failure";
      StateDirectory = "llama";
      SupplementaryGroups = [ "video" "render" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}