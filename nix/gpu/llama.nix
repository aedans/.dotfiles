{ config, pkgs, pkgs-unstable, ... }:

# out=$(NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link --print-out-paths '.^out' --expr '
#   let
#     pkgs = import (builtins.getFlake "nixpkgs/nixos-unstable") {
#       config = { allowUnfree = true; cudaSupport = true; };
#     };
#   in (pkgs.llama-cpp.override { cudaSupport = true; }).overrideAttrs (old: {
#     src = pkgs.fetchFromGitHub {
#       owner = "PrismML-Eng"; repo = "llama.cpp"; rev = "prism";
#       hash = "sha256-AATH4Bg0nhbuftEA1xcwAX0geVNmuBY5UWK5u2vgEYI=";
#     };
#     npmDepsHash = "sha256-pjdbI6NcZRlJVd62xhgbLhWrwFYwgsIwjORqvo1+VD8=";
#   })
# ')
#   "$out/bin/llama-server" \
#     -m /home/hans/.lmstudio/models/prism-ml/Ternary-Bonsai-27B-gguf/Ternary-Bonsai-27B-Q2_0.gguf \
#     -ngl 99 -c 262144 -fa 1 \
#     --cache-type-k q4_0 --cache-type-v q4_0 \
#     --temp 0.5 --top-p 0.85 --top-k 20 --min-p 0

let
  ggufPath = "/home/hans/.lmstudio/models/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_S.gguf";
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
          --stateless
      '';
      Restart = "on-failure";
    };
  };

  systemd.services.llama-server = {
    description = "llama-server";
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
          --cache-type-k   q4_0 \
          --cache-type-v   q4_0 \
          --flash-attn     on \
          --reasoning-budget 4096 \
          --reasoning-budget-message "... thinking budget exceeded, let's answer now." \
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
