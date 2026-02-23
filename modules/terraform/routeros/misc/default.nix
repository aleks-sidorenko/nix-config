{ ... }:
{
  # LCD settings (no dedicated terraform resource)
  resource.routeros_rest.lcd = {
    path = "/lcd";
    data = builtins.toJSON {
      default-screen = "log";
      enabled = "false";
      touch-screen = "disabled";
    };
  };

  # Serial port naming
  resource.routeros_rest.port_serial0 = {
    path = "/port";
    data = builtins.toJSON {
      ".id" = "*0";
      name = "serial0";
    };
  };

  # SMB default user disabled
  resource.routeros_rest.smb_user_default = {
    path = "/ip/smb/users";
    data = builtins.toJSON {
      ".id" = "*0";
      disabled = "true";
    };
  };

  # SMB default share
  resource.routeros_rest.smb_share_default = {
    path = "/ip/smb/shares";
    data = builtins.toJSON {
      ".id" = "*0";
      directory = "/pub";
    };
  };

  # Wireless security profiles default
  resource.routeros_rest.wireless_security_default = {
    path = "/interface/wireless/security-profiles";
    data = builtins.toJSON {
      ".id" = "*0";
      supplicant-identity = "MikroTik";
    };
  };
}
