{
  # k9s is the configured tool; the rest are bare packages, so one aspect holds both.
  den.aspects.dev.k8s.homeManager =
    { pkgs, ... }:
    {
      programs.k9s.enable = true;

      home.packages = builtins.attrValues {
        inherit (pkgs)
          kubectl
          kubectx
          kubelogin
          kubelogin-oidc
          stern
          kubernetes-helm
          kustomize
          fluxcd
          kubefwd
          ;
      };
    };
}
