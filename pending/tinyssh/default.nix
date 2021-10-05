{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "tinyssh";
  version = "20210601";
  src = fetchFromGitHub {
    owner = "janmojzis";
    repo = "tinyssh";
    rev = version;
    sha256 = "sha256-+THoPiD6dW5ZuiQmmLckOJGyjhzdF3qF0DgC51zjGY8=";
  };
  preConfigure = ''
    echo /bin       > conf-bin
    echo /share/man > conf-man
  '';
  DESTDIR = placeholder "out";
  meta = { maintainers = with lib.maintainers; [ kaction ]; };
}
