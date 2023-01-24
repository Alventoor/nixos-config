{ lib, config, pkgs, ... }:
{
  programs.firefox = {
    enable = true;

    policies = {
      DisablePocket = true;
      PromptForDownloadLocation = true;
      SearchBar = "separate";
    };

    preferences = {
        "browser.cache.disk.enable" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "widget.use-xdg-desktop-portal.mime-handler" = 1;
    };
  };
}
