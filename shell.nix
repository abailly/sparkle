{ nixpkgs ? import <nixpkgs> {}, ghc ? nixpkgs.haskell.compiler.ghc7103 }:

with nixpkgs;
with stdenv.lib;

let
  spark = nixpkgs.spark.override { mesosSupport = false; };

  jvmlibdir =
    if stdenv.isLinux
    then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
    else "${openjdk}/jre/lib/server";

  # TODO: remove once https://github.com/NixOS/nixpkgs/pull/15989 is merged.
  buildStackProject =
    { buildInputs ? []
    , extraArgs ? []
    , LD_LIBRARY_PATH ? ""
    , ghc ? ghc
    , ...
    }@args:

    stdenv.mkDerivation (args // {

    buildInputs =
      buildInputs ++
      optional stdenv.isLinux glibcLocales ++
      [ ghc pkgconfig ];

    STACK_IN_NIX_SHELL=1;
    STACK_IN_NIX_EXTRA_ARGS =
      args.STACK_IN_NIX_EXTRA_ARGS or
      concatMap (pkg: ["--extra-lib-dirs=${pkg}/lib"
                       "--extra-include-dirs=${pkg}/include"]) buildInputs ++
      extraArgs;

    # XXX: workaround for https://ghc.haskell.org/trac/ghc/ticket/11042.
    LD_LIBRARY_PATH = makeLibraryPath (LD_LIBRARY_PATH ++ buildInputs);

    preferLocalBuild = true;

    configurePhase = args.configurePhase or "stack setup";

    buildPhase = args.buildPhase or "stack build";

    checkPhase = args.checkPhase or "stack test";

    doCheck = args.doCheck or true;

    installPhase = args.installPhase or ''
      stack --local-bin-path=$out/bin build --copy-bins
    '';
    });
in
buildStackProject {
  name = "sparkle";
  buildInputs =
    [ gradle
      openjdk
      spark
      which
      zlib
      # to fetch distributed-closure
      git
      openssh
      ghc
    ];
  inherit ghc;
  extraArgs = ["--extra-lib-dirs=${jvmlibdir}"];
  # XXX Workaround https://ghc.haskell.org/trac/ghc/ticket/11042.
  LD_LIBRARY_PATH = [jvmlibdir];
}
