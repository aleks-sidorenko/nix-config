{ routerConfig, ... }:
{
  terraform = {
    required_providers.routeros = {
      source = "terraform-routeros/routeros";
      version = "~> 1.99";
    };

    # NOTE: State encryption is configured via packages/router/encryption.tf.hcl
    # because OpenTofu encryption references are not expressible in JSON/terranix.
  };

  provider.routeros = {
    hosturl = "api://${routerConfig.gateway}";
    username = "\${var.routeros_username}";
    password = "\${var.routeros_password}";
  };

  variable = {
    routeros_username = {
      type = "string";
      default = routerConfig.username;
      description = "RouterOS API username";
    };
    routeros_password = {
      type = "string";
      sensitive = true;
      description = "RouterOS API password";
    };
    wifi_password = {
      type = "string";
      sensitive = true;
      description = "WiFi password for CAPsMAN security";
    };
    state_passphrase = {
      type = "string";
      sensitive = true;
      description = "Passphrase for OpenTofu state encryption (min 16 chars)";
    };
  };
}
