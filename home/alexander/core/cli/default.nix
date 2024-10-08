{pkgs, ...}: {
  imports = [
    ./misc.nix
    ./bash.nix
    ./bat.nix
    ./direnv.nix
    ./fish.nix
    ./gh.nix
    ./git.nix
    ./gpg.nix
    ./jujutsu.nix
    ./nushell.nix
    ./nix-index.nix
    ./pfetch.nix
    ./shellcolor.nix
    ./ssh.nix
    ./fzf.nix
  ];
}
