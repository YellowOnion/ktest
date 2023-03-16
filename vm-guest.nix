{ modulesPath, config, lib, pkgs, ... }:

{
  ## Add this back when we upstream the patched version.
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  boot.initrd.includeDefaultModules = false;

  boot.kernelParams = [
    "mitigations=off"
  ];
  virtualisation = {
    graphics = false;
    qemu = {
      minimalParams = true;
      options = [
        "-chardev" "stdio,id=kgdb"
        "-serial"  "unix:\${ktest_out}/vm/kgdb,server,nowait"
        "-monitor" "unix:\${ktest_out}/vm/mon,server,nowait"
      ];
    };
  };

  environment.systemPackages =  builtins.attrValues {
    inherit (pkgs)
      curl
      xfstests
      strace
      gdb
      trace-cmd
      blktrace
      iotop
      htop
      btrfs-progs
      jfsutils
      nilfs-utils
      f2fs-tools
      pciutils

      #stress test
      fio
      dbench
      bonnie
      fsmark

      nbd

      # nfs-kernel-server ?

      cryptsetup

      # weird block layer crap
      multipath-tools
      sg3_utils
      # srptools ?
    ;
  };

#    systemd.services.ktestrunner = {
#      wantedBy = [ "multi-user.target" ];

#        serviceConfig = {
#          Type = "forking";
#          TimeoutSec = 0;
#          RemainAfterExit = "yes";
#          ExecStart = "${ktest-runner}/bin/testrunner.wrapper";
#        };
#    };
  system.stateVersion = "23.05";
}
