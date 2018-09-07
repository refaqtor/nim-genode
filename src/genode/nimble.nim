backend = "cpp"

import strutils

task depot, "Create depot package":
  let
    defines = """

      SRC_DIR=$${GENODE_DEPOT_DIR}/$${GENODE_DEPOT_USER}/src/$name/$version
      BIN_DIR=$${GENODE_DEPOT_DIR}/$${GENODE_DEPOT_USER}/bin/x86_64/$name/$version
      PKG_DIR=$${GENODE_DEPOT_DIR}/$${GENODE_DEPOT_USER}/pkg/$name/$version
      """ % [ "name", depotPkgName, "version", version ]

    depotChecks = """

        [ -z "$${GENODE_DEPOT_DIR}" ] && [ -z "$${GENODE_DEPOT_USER}" ] && /
        [ ! -e "$${SRC_DIR}" ] &&  [ ! -e "$${BIN_DIR}" ] && [ ! -e "$${PKG_DIR}" ]
      """

    depotBuild = """
      nimble build --os:genode -d:posix -d:release
      mkdir -p "$${BIN_DIR}"
      mv "$bin" "$${BIN_DIR}"

      mkdir -p "$${SRC_DIR}"

      if [ -e "archives" ] && [ -e "runtime" ] && [ -e "README" ]
      then
        mkdir -p "$${PKG_DIR}"
        cp README runtime "$${PKG_DIR}"
        cp archives "$${PKG_DIR}"
        grep /libc/ /opt/genode-sdk-x86_64/archives >> "$${PKG_DIR}/archives"
        grep /vfs/  /opt/genode-sdk-x86_64/archives >> "$${PKG_DIR}/archives"
        echo src/$name/$version >> "$${PKG_DIR}/archives"
      fi
      """ % [ "name", depotPkgName, "version", version, "bin", join(bin) ]

  exec(defines & depotChecks)
  exec(defines & depotBuild)

#[
  exec ""
  let
    deobinDir = "depot/bin/x86_64/$1/$2" % [ depotPkgName, version ]
    pkgDir = "depot/pkg/$1/$2" % [ depotPkgName, version ]
  exec("mkdir -p $1" % binDir)
  for b in bin:
    exec("mv -v $2 $1/$2" % [binDir, b])
  if fileExists "runtime":
    echo """a "runtime" file is present, generating a runtime package"""
    if not fileExists "README":
      raiseAssert "refusing to generate runtime package without a README"
    let sh = """
      mkdir -p $1
      cp README runtime $1
      """
    exec(sh % pkgDir)
  else:
    echo """no "runtime" is present, not generating a runtime package"""
]#


# TODO: read /sdk/depot/archives for dependency versions
# generate a package with a runtime using some templating
