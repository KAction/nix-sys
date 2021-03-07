self: super: {
  pure-cdb = super.buildPythonPackage {
    pname = "python-pure-cdb";
    version = "3.1.1";
    src = builtins.fetchGit {
      url = "https://github.com/bbayles/python-pure-cdb";
      rev = "a1f496a95b892c1304e637fb352f663c65eb2655";
    };
    checkInputs = with self; [ flake8 ];
  };
}
