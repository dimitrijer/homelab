# Override oslo-log to preserve the fixture module which is needed for testing
# other Oslo packages like oslo.versionedobjects
self: super: {
  pythonPackagesExtensions = super.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      oslo-log = python-prev.oslo-log.overridePythonAttrs (old: {
        # Preserve the fixture directory which is removed by default
        postInstall = (old.postInstall or "") + ''
          # Restore fixture module from source
          if [ -d "$src/oslo_log/fixture" ]; then
            cp -r $src/oslo_log/fixture $out/${python-final.python.sitePackages}/oslo_log/
          fi
        '';
      });
    })
  ];
}
