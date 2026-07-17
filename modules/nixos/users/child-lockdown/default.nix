{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  # Users declared with profile = "child" on this host.
  childUsers = attrNames (filterAttrs (_: u: u.profile == "child") config.${namespace}.users);

  # NetworkManager actions that enable/disable networking. Denying these makes
  # the GNOME quick-settings wifi/network toggle refuse for child users, while
  # leaving existing connections up and usable.
  deniedActions = [
    "org.freedesktop.NetworkManager.enable-disable-network"
    "org.freedesktop.NetworkManager.enable-disable-wifi"
    "org.freedesktop.NetworkManager.enable-disable-wwan"
  ];

  userList = concatMapStringsSep " || " (u: ''subject.user == "${u}"'') childUsers;
  actionList = concatMapStringsSep "\n      || " (a: ''action.id == "${a}"'') deniedActions;

  rule = ''
    // Deny network enable/disable for restricted child accounts.
    // Written to a 00- file so it is evaluated before NixOS's 10-nixos.rules
    // (which grants the networkmanager group), and NO short-circuits.
    polkit.addRule(function(action, subject) {
      if ((${userList})
      && (${actionList})) {
        return polkit.Result.NO;
      }
    });
  '';
in
{
  config = mkIf (childUsers != [ ]) {
    environment.etc."polkit-1/rules.d/00-child-network-lockdown.rules".text = rule;
  };
}
