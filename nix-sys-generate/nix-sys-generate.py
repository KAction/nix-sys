#!/usr/bin/python
import click
import json
from os import path
import jinja2
import functools
import cdblib
from operator import itemgetter

# Making database that contains references to all source files keeps
# alive more than strictly necessary: there is no need to keep alive
# source for "copy" action.
#
# But it makes thing simpler. "copy" actions should be rare, anyway.
CDB_PATH = "/nix/var/nix/gcroots/nix-sys.cdb"

def get_template(template_directory, name):
    path = f"{template_directory}/{name}"
    with open(path) as fp:
        return jinja2.Template(fp.read())


def render_template(template_directory, _name, **kwargs):
    return get_template(template_directory, _name).render(**kwargs)


def validate_target_path(target):
    if target.endswith("/"):
        raise ValueError(f"Target `{target}' ends with slash")
    if not target.startswith("/"):
        raise ValueError(f"Target `{target}' is not absolute path")
    if path.normpath(target) != target:
        raise ValueError(f"Target `{target}' is not normalized")


def parent_directories(filepath):
    parent = filepath
    while parent != "/":
        parent = path.dirname(parent)
        yield parent


def make_output_config(out, manifest, hash, render, output_cdb):
    parents = {}

    for target in manifest:
        validate_target_path(target)

        for parent in parent_directories(target):
            parents[parent] = target

    for target in manifest:
        another = parents.get(target)
        if another and manifest[another]["action"] != "mkdir":
            msg = f"Target `{target}' is parent of `{another}' target"
            raise ValueError(msg)

    directories = {d: dict(name=d) for d in parents}
    rules = [(k, v) for k, v in manifest.items() if v["action"] == "mkdir"]
    for d, spec in rules:
        directories[d] = dict(name=d, **spec)
    directories = sorted(directories.values(), key=itemgetter("name"))
    out.write(render("mkdir.j2", values=directories))
    out.write(render("strings.j2", name="parents", values=sorted(parents)))

    values = [k for k, v in manifest.items() if v["action"] == "unlink"]
    out.write(render("strings.j2", name="to_unlink", values=values))

    for action in ["copy", "symlink"]:
        rules = [(k, v) for k, v in manifest.items() if v["action"] == action]
        out.write(render(f"{action}.j2", hash=hash, rules=rules))
    out.write(f'const char *newcdb_path = "{output_cdb}";')
    out.write(f'const char *oldcdb_path = "{CDB_PATH}";')


def make_output_cdb(out, manifest):
    with cdblib.Writer(out) as out:
        for target in manifest:
            # Everything to make C code simple and avoids allocation.
            parents = b"\0".join(dir.encode("utf-8")
                                 for dir in parent_directories(target))
            parents += b"\0\0"

            target = target.encode("utf-8") + b"\0"
            out.put(target, parents)


@click.command()
@click.option("--hash", required=True)
@click.option("--manifest", required=True)
@click.option("--template-directory", required=True)
@click.option("--output-config", required=True)
@click.option("--output-cdb", required=True)
@click.option("--staged-output-cdb")
def main(hash, manifest, template_directory, output_config, output_cdb, staged_output_cdb):
    manifest = json.loads(manifest)
    render = functools.partial(render_template, template_directory)
    manifest[CDB_PATH] = dict(path=output_cdb, action="symlink")

    if output_config:
        with open(output_config, "w") as out:
            make_output_config(out, manifest, hash, render, output_cdb)

    if output_cdb:
        with open(staged_output_cdb or output_cdb, "wb") as out:
            make_output_cdb(out, manifest)

main()
