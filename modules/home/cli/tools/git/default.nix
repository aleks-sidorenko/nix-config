{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.git;

  rewriteURL = lib.mapAttrs' (key: value: {
    name = "url.${key}";
    value = {
      insteadOf = value;
    };
  }) cfg.urlRewrites;
in
{
  options.${namespace}.cli.tools.git = with types; {
    enable = mkBoolOpt false "Whether or not to enable git.";
    email = mkOpt (nullOr str) "aleks.sidorenko@gmail.com" "The email to use with git.";
    fullName = mkOpt (nullOr str) "Alexander Sidorenko" "The full name to use with git.";
    urlRewrites = mkOpt (attrsOf str) { } "url we need to rewrite i.e. ssh to http";
    allowedSigners = mkOpt str "~/.ssh/id_ed25519.pub" "The public key used for signing commits";
  };

  config = mkIf cfg.enable {
    home.file.".ssh/allowed_signers".text = "* ${cfg.allowedSigners}";

    programs.git = {
      enable = true;
      settings = {

        user = {
          name = cfg.fullName;
          email = cfg.email;
        };

        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        commit.gpgsign = true;
        user.signingkey = cfg.allowedSigners;

        diff.tool = "difftastic";
        difftool = {
          prompt = "false";
          difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
        };

        log = {
          showSignature = "true";
        };

        pull = {
          rebase = true;
        };

        init = {
          defaultBranch = "master";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };
      };

      signing = {
        signByDefault = true;
        key = cfg.allowedSigners;
      };

      ignores = [
        ".direnv"
        "result"
      ];

    };

    programs.difftastic = {
      enable = true;
    };

  };
}
