{
  outputs = { ... }: {
    lib = {
      withDocPath =
        { pkgs
        , stdenv ? pkgs.stdenv }:
        attrs: let
          inherit (pkgs) lib;
          inherit (builtins) concatStringsSep filter map toPath toString pathExists;

          allPossibleInputs = stdenv.defaultBuildInputs ++ stdenv.defaultNativeBuildInputs
                              ++ stdenv.allowedRequisites
                              ++ (attrs.buildInputs or [])
                              ++ (attrs.nativeBuildInputs or [])
                              # grab unwrapped cc, wrapped one does not have an info output
                              ++ (lib.optional (builtins.hasAttr "cc" stdenv) stdenv.cc.cc);
          allowedInputs = lib.subtractLists stdenv.disallowedRequisites allPossibleInputs;
          inputDrvs = lib.unique (filter lib.isDerivation allowedInputs);
          infoOuts = map (lib.getOutput "info") inputDrvs;
          manOuts = map (lib.getOutput "man") inputDrvs;

          docPaths = suffix: outs: filter pathExists (map (out: toPath "${out}/${suffix}") outs);
          infoPathsPre = docPaths "share/info" infoOuts;
          manPaths = docPaths "share/man" manOuts;

          # some packages neglect to build an info dir file
          fixInfoDir = stdenv.mkDerivation {
            inherit (stdenv) system;
            name = "add-missing-info-dirs";
            passAsFile = ["buildCommand"];
            buildCommand = ''
              shopt -s nullglob
              mkdir -p $out/share/info
              for pkg in ${concatStringsSep " " (map toPath infoOuts)}; do
                [[ -s $pks/share/info/dir ]] && continue || :
                for file in $pkg/share/info/*.info{,.gz}; do
                   ${pkgs.texinfo}/bin/install-info $file $out/share/info/dir
                done
              done
            '';
          };

          infoPaths = infoPathsPre ++ [(toPath "${fixInfoDir}/share/info")];
        in
          attrs
          // {
            shellHook = attrs.shellHook or "" + ''
              export INFOPATH=${builtins.concatStringsSep ":" infoPaths}:$INFOPATH
              export MANPATH=${builtins.concatStringsSep ":" manPaths}:$MANPATH
            '';
          };
    };
  };
}
