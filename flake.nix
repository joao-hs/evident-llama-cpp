{
  description = "Reproducible and Immutable NixOS Images";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    evident-instance = {
      url = "gitlab:dpss-inesc-id/achilles-cvm/dev?dir=instance";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      perSystem = { config, pkgs, ... }: {
        packages =
        let
          mkBundle = inputs.evident-instance.apps.x86_64-linux.mkBundle;
        in
        {
          gce = pkgs.callPackage ./src {
            platform = "gce";
            inherit inputs;
            evidentInstancePackage = mkBundle {
              mandatoryFeature = "snp_gce";
              optionalFeatures = [
                "debug"
                "request_certificate"
              ];
              certificateIssuerEndpoint = "gce.intermediate-ca.evident.joaohs.com:5010";
            };
            withDebug = true;
            domain = "gce-llama-cpp.joaohs.com";
          };
          ec2 = pkgs.callPackage ./src {
            platform = "ec2";
            inputs = inputs;
            evidentInstancePackage = mkBundle {
              mandatoryFeature = "snp_ec2";
              optionalFeatures = [
                "debug"
                "request_certificate"
              ];
              certificateIssuerEndpoint = "gce.intermediate-ca.evident.joaohs.com:5010";
            };
            withDebug = true;
            domain = "ec2-llama-cpp.joaohs.com";
          };
        };
      };
    };
}
