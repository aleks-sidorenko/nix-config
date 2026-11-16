# What sonarr, radarr and prowlarr share: an API key secret and a config.xml
# rendered from it, installed before each start, and the service user.
{
  lib,
  name,
  title,
  port,
  dataDir,
  group,
}:
config:
let
  secret = "service-${name}-api-key";
  template = "${name}-config.xml";
in
{
  sops.secrets.${secret} = {
    owner = name;
    inherit group;
    mode = "0400";
  };

  sops.templates.${template} = {
    content = ''
      <Config>
        <BindAddress>127.0.0.1</BindAddress>
        <Port>${toString port}</Port>
        <ApiKey>${config.sops.placeholder.${secret}}</ApiKey>
        <AuthenticationMethod>External</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <LogDbEnabled>False</LogDbEnabled>
        <InstanceName>${title}</InstanceName>
      </Config>
    '';
    owner = name;
    inherit group;
    mode = "0400";
  };

  users.users.${name} = {
    isSystemUser = true;
    group = lib.mkForce group;
    extraGroups = [ "users" ];
    home = dataDir;
    createHome = true;
    description = "${title} user";
  };

  # cp keeps the source's mode; the template is read-only, so an explicit mode
  # is required or the app can't rewrite its own config next start.
  systemd.services.${name}.preStart = ''
    install -m 0600 ${config.sops.templates.${template}.path} ${dataDir}/config.xml
  '';
}
