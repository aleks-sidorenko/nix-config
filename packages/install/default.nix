{
  writeShellScriptBin,
  gum,
  ...
}:
# Taken from: https://github.com/IogaMaster/dotfiles/blob/main/packages/install/default.nix
writeShellScriptBin "install" ''
  ${gum}/bin/gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "✨ Alexander's dotfiles installer ✨"
  echo "This script will wipe the remote system!"
  ${gum}/bin/gum confirm "Cancel..." && exit

  echo
  echo "🔥 kexec into the NixOS Installer..."
  ssh root@$2 'curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | tar -xzf- -C /root'
  ssh root@$2 '/root/kexec/run'

  echo
  echo "⏰ Waiting for host nixos to come online..."
  while true; do ping -c1 nixos > /dev/null && break; done

  echo
  echo "📥 Grabbing hardware config..."
  ssh root@nixos 'nixos-generate-config --show-hardware-config --root /mnt' > systems/x86_64-linux/$1/hardware-configuration.nix

  echo
  echo "✅ Installing..."
  nix run github:nix-community/nixos-anywhere -- --flake .#$1 root@nixos

  echo
  echo "✨ Done!!!"
''
