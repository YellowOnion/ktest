{
  description = "Flake for ktest kernel builds";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    utils.url = "github:numtide/flake-utils";
    src.url = "git+https://evilpiepirate.org/git/bcachefs.git";
    src.flake = false;
    buildRoot.url = "path:dummy-kernel-build";
    buildRoot.flake = false;
    bcachefs-tools.url = "git+https://evilpiepirate.org/git/bcachefs-tools.git";
  };

  outputs = { self, nixpkgs, utils,
              src,
              buildRoot,
              bcachefs-tools }:

    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        ktest = pkgs.nix-gitignore.gitignoreSource [] ./. ;

        kernelVersion =
          let s = lib.removeSuffix "\n"
                  (builtins.readFile "${buildRoot}/include/config/kernel.release");
          in builtins.trace "kernelVersion: ${s}" s;
        version = lib.concatStringsSep "." [
          (lib.versions.majorMinor kernelVersion)
          (lib.versions.patch kernelVersion)
        ];

        ## TODO plumb kernel version automatically in to builds.
        preBuiltKernel = pkgs.callPackage ./kernel_install.nix {
                            inherit src buildRoot version kernelVersion;
                          };
        srcBuildKernel = pkgs.callPackage ({buildLinux, ... } @ args:
          buildLinux (args // {
            inherit version src;
            modDirVersion = kernelVersion;

            kernelPatches = [];

            extraConfig = ''
              BCACHFS_FS m
            '';

          extraMeta.branch =  pkgs.lib.versions.majorMinor version;
                          } // (args.argsOverride or {}))) {};
        defaultKernel = if (import buildRoot).isPreBuilt then preBuiltKernel else srcBuildKernel;
      in {
        packages = {
          inherit preBuiltKernel srcBuildKernel bcachefs-tools;
          default = defaultKernel;
          nixosConfigurations.ktest-guest = (nixpkgs.lib.nixosSystem {
                system = system;
                modules =
                  [ ./vm-guest.nix
                    #./qemu-vm.nix
                    ({ config, pkgs, ... }: {
                      # Let 'nixos-version --json' know about the Git revision
                      # of this flake.
                      system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
                      boot.kernelPackages = pkgs.linuxPackagesFor defaultKernel;

                      environment.systemPackages = [
                        bcachefs-tools
                        pkgs.linuxPackages_latest.perf
                      ];
                    })
                  ];
          }).config.system.build.vm;
        };
    });
}
