{
  systemd.services.searxng-mcp = {
    description = "SearXNG MCP server";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];

    environment.SEARXNG_URL = "http://localhost:8081";

    serviceConfig = {
      ExecStart = "${pkgs.nodejs}/bin/npx -y mcp-searxng";
      Restart   = "on-failure";
    };
  };
}