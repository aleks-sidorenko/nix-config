{
  den.aspects.security.pass = {
    # pass-import pulls secretstorage, which pulls jeepney; its checkPhase needs
    # a session bus that the darwin build sandbox cannot start. Only that phase
    # is dropped: the check inputs its imports check needs stay.
    darwin.nixpkgs.overlays = [
      (_final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (_pyfinal: pyprev: {
            jeepney = pyprev.jeepney.overridePythonAttrs {
              checkPhase = ''
                runHook preCheck
                runHook postCheck
              '';
            };
          })
        ];
      })
    ];

    homeManager =
      { config, pkgs, ... }:
      {
        programs.password-store = {
          enable = true;
          settings.PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
          package = pkgs.pass.withExtensions (p: [
            p.pass-otp
            p.pass-file
            p.pass-import
          ]);
        };
      };
  };
}
