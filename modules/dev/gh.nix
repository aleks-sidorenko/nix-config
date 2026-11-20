{
  den.aspects.dev.gh.homeManager.programs.gh = {
    enable = true;
    # Auth is `gh auth login` (keyring): an exported token would override it, and SSO orgs reject the classic one.
    settings.git_protocol = "ssh";
  };
}
