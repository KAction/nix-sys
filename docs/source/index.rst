.. nix-sys documentation master file, created by
   sphinx-quickstart on Sun Aug 15 18:14:44 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to nix-sys's documentation!
===================================

.. toctree::
   :maxdepth: 2
   :caption: Contents:


Problem and existing solutions
******************************

`Nix package manager`_ provides elegant and powerful mechanism for
building and combining software, enabling creation of reproducible and
traceable software configurations. Unfortunately, `Nix break-through`
is only about creating immutable file paths in Nix store, while full
operating system also need to handle mutable files (logs, caches,
databases) and processes to run.

This is why `NixOS`_ was created. Unfortunately, unlike Nix, which is
all about mechanism, NixOS has significant amount of policy hard-wired
into it -- systemd init system, glibc posix library, grub bootloader and
so on. Changing it is possible in theory, but is unsupported and quite
hard.

On top of these particular choices, NixOS has concept of modules -- Nix
functions that provide high-level view on service configuration. For
example, `module for ssh server`_ allows configuring of about 40 options
out of those listed in sshd_config(8), and has escape hatch to plug
verbatim config if user some option not covered.

NixOS modules make configuration easier in simple cases, like when
administrator wants to start some ssh server with some config on port 22, and
get in the way of administrator who wants to setup particular implementation
with very specific set of options.

Goal of nix-sys project is to provide basis for building Nix-based operating
system without any bias toward any particular system configuration. Mechanism,
not policy.

.. _Nix package manager: https://nixos.org/download.html
.. _Nix break-through: https://edolstra.github.io/pubs/nixos-icfp2008-final.pdf
.. _NixOS: https://nixos.org
.. _module for ssh server: https://search.nixos.org/options?channel=21.05&query=openssh


Quick start
***********

Nix-sys allows user to declaratively specify, which files and directories
must be present on filesystem, and builds derivation that ensures that.
For example, let's consider following simple example::


    # This is default.nix
    { pkgs ? import <nixpkgs> { } }:
    let
      nix-sys-repo = pkgs.fetchgit {
        url = "https://git.sr.ht/~kaction/nix-sys";
        rev = "d1b4185735984cfa79480f1a8f7e5f9915d05854";
        sha256 = "1ysldklfms97pa89506gfx6lmjim265mcf5g4j18f0x3vkz4cw1h";
      };
      nix-sys = (import nix-sys-repo { }).nix-sys;
      manifest = {
        symlink = {
          "/usr/local/bin/hello" = { path = "${pkgs.hello}/bin/hello"; };
        };
        copy = {
          "/etc/banner.txt" = {
            path = pkgs.writeText "banner.txt" ''
              Configured with nix-sys
            '';
            mode = "644";
          };
        };
      };

    in nix-sys.override {
      manifest = pkgs.writeText "manifest.json" (builtins.toJSON manifest);
    }

First two assignments are standard way to fetch and import Nix code from remote
repository, interesting thing happens in definition of manifest, which, as can
be guessed, prescribes creation of one symlink and one regular file. It does
not matter how manifest json file was generated as long as it has right format.
Generating it from Nix attribute set is just one possibility. See next section
for detailed description of manifest format.

Building this `default.nix` file produces output path containing `bin/nix-sys`
executable, which can be used either on local machine or transferred to remote
one via `nix-copy-closure`. Running this executable as root, e.g::

    $ sudo ./result/bin/nix-sys

creates files, directories and symlinks specified by the manifest.

Now, if we remove drop some part of manifest, re-build and re-run nix-sys, it
would remove corresponding entries from filesystem. In a way, nix-sys can be
seen as Nix-powered package manager that manages single package: whole system.

Manifest format
***************

Manifest is json file, containing object with pre-defined list of top-level
keys, all of which are optional.

copy
----

This part of manifest specifies that file at specified location must be copied
from some specified path, with ownership and permissions configured according
to the manifest. In general, symbolic links (next subsection) are preferable,
since they are faster to create and do not waste disk space, but some programs
do not work correctly with symlinks where regular file is expected. Also,
regular files can be made suid/sgid.

Value of `copy` key in maniest must be object with keys being absolute paths
and values being object, specifying properties of the file at that location.

path
  Mandatory. Source file to copy content from. In most cases it would
  be path inside Nix store, but it may be path to arbitrary file that
  exists on target system. Keep in mind that any file that gets into Nix
  store is world-readable.

mode
  Mandatory. File permissions, specified as either integer or string,
  containing octal number. So, both `"4555"` and `2413` are accepted
  as mode of suid, world-readable and world-executable file.

owner
  Optional. Numeric identifier of the file owner, defaulting to 0 (superuser).

group
  Optional. Numeric identifier of the file group, defaulting to 0.


symlink
-------

This part of manifest specifies that file must be symlink to another file, in
many cases located inside Nix store.

Value of `symlink` key in maniest must be object with keys being absolute
paths and values being either object with single key `path` or string.
In both cases it specifies symlink destination.

mkdir
-----

If file is created as either copy or symlink, as mentioned in previous
sub-sections, its parent directories are created automatically with 755
permissions and 0:0 ownership if they do not already exist.

This part of manifest specifies that file must be a directory, with specifying
ownership and permissions. Note, that once `mkdir` rule is removed from the
manifest, nix-sys will remove that directory only if it is empty.

Value of `mkdir` key in maniest must be object with keys being absolute paths
and values being objects, specifying properties of the file at that location.

mode
  Mandatory. File permissions, specified as either integer or string,
  containing octal number. So, both `"4555"` and `2413` are accepted
  as mode of suid, world-readable and world-executable file.

owner
  Optional. Numeric identifier of the file owner, defaulting to 0 (superuser).

group
  Optional. Numeric identifier of the file group, defaulting to 0.


exec
----

If this key present, its value must be string specifying absolute path
to a program, into which nix-sys will execute as last operation. Program
is run with root permissions, without any command line arguments and
with empty environment. It means that if program needs some variables,
like `PATH`, it needs to set them itself.


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
