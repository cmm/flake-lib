{
  outputs = { ... }: {
    lib = {
      withInfoPath = self: stdenv: attrs:
        attrs
        // {
          shellHook = attrs.shellHook or "" + (let
            inherit (self.inputs.nixpkgs) lib;
            inherit (builtins) filter map;

            allPossibleInputs = stdenv.defaultBuildInputs ++ stdenv.defaultNativeBuildInputs
                                ++ stdenv.allowedRequisites
                                ++ (attrs.buildInputs or [])
                                ++ (attrs.nativeBuildInputs or [])
                                ++ (lib.optional (builtins.hasAttr "cc" stdenv) stdenv.cc.cc);
            allowedInputs = lib.subtractLists stdenv.disallowedRequisites allPossibleInputs;
            inputDrvs = lib.unique (filter lib.isDerivation allowedInputs);
            infoOuts = map (lib.getOutput "info") inputDrvs;
            infoPaths = filter builtins.pathExists (map (out: builtins.toPath "${out}/share/info") infoOuts);
          in ''
            export INFOPATH=${builtins.concatStringsSep ":" infoPaths}:$INFOPATH
          '');
        };
    };
  };
}
