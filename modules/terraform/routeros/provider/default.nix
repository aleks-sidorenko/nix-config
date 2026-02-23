{ routerConfig, ... }:
{
  terraform = {
    required_providers.routeros = {
      source = "terraform-routeros/routeros";
      version = "~> 1.99";
    };

    # OpenTofu native state encryption
    encryption = {
      key_provider.pbkdf2.state = {
        passphrase = "\${var.state_passphrase}";
      };
      method.aes_gcm.state = {
        keys = "\${key_provider.pbkdf2.state}";
      };
      state = {
        method = "\${method.aes_gcm.state}";
      };
      # Uncomment for initial migration from unencrypted state:
      # method.unencrypted.migration = {};
      # state.fallback.method = "\${method.unencrypted.migration}";
    };
  };

  provider.routeros = {
    hosturl = "api://${routerConfig.gateway}";
    username = "\${var.routeros_username}";
    password = "\${var.routeros_password}";
  };

  variable = {
    routeros_username = {
      type = "string";
      default = "admin";
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
