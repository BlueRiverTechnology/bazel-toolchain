# Copyright 2018 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "@com_grail_bazel_toolchain//toolchain/internal:llvm_distributions.bzl",
    _download_llvm = "download_llvm",
    _download_llvm_preconfigured = "download_llvm_preconfigured",
)
load(
    "@com_grail_bazel_toolchain//toolchain/internal:sysroot.bzl",
    _cuda_path = "cuda_path",
    _sysroot_path = "sysroot_path",
)
load("@rules_cc//cc:defs.bzl", _cc_toolchain = "cc_toolchain")

def _makevars_ld_flags(rctx):
    if rctx.os.name == "mac os x":
        return ""

    # lld, as of LLVM 7, is experimental for Mach-O, so we use it only on linux.
    return "-fuse-ld=lld"

def llvm_toolchain_impl(rctx):
    if rctx.os.name.startswith("windows"):
        rctx.file("BUILD")
        rctx.file("toolchains.bzl", """
def llvm_register_toolchains():
    pass
        """)
        return

    repo_path = str(rctx.path(""))
    relative_path_prefix = "external/%s/" % rctx.name
    maybe_target = {
        cpu: "target-%s/" % cpu
        for cpu in rctx.attr.enable_cpus
        if cpu in rctx.attr.target_distribution.keys()
    }
    all_maybe_target = list(maybe_target.values())
    for cpu in rctx.attr.enable_cpus:
        if cpu not in rctx.attr.target_distribution.keys():
            all_maybe_target.append("")
            break
    if rctx.attr.absolute_paths:
        toolchain_path_prefix = repo_path + "/"
    else:
        toolchain_path_prefix = relative_path_prefix

    additional_cxx_builtin_include_directories = {
        cpu: rctx.attr.cxx_builtin_include_directories.get(cpu, [])
        for cpu in rctx.attr.enable_cpus
    }

    sysroot_path, sysroot = _sysroot_path(rctx)
    sysroot_labels = [str(label) for label in sysroot.values() if label]
    sysroot_prefix = {
        cpu: "%sysroot%" if sysroot_path[cpu] else ""
        for cpu in rctx.attr.enable_cpus
    }

    cuda_path, cuda_labels = _cuda_path(rctx)
    cuda_path_labels = [str(label) for label in cuda_labels.values() if label]

    substitutions = {
        "%{repo_name}": rctx.name,
        "%{llvm_version}": rctx.attr.llvm_version,
        "%{toolchain_path_prefix}": toolchain_path_prefix,
        "%{tools_path_prefix}": (repo_path + "/") if rctx.attr.absolute_paths else relative_path_prefix,
        "%{debug_toolchain_path_prefix}": relative_path_prefix,
        "%{sysroot_path}": repr(sysroot_path),
        "%{sysroot_prefix}": repr(sysroot_prefix),
        "%{sysroot_labels}": repr(sysroot_labels),
        "%{cuda_path}": repr(cuda_path),
        "%{cuda_path_labels}": repr(cuda_path_labels),
        "%{absolute_paths}": "True" if rctx.attr.absolute_paths else "False",
        "%{makevars_ld_flags}": _makevars_ld_flags(rctx),
        "%{maybe_target}": repr(maybe_target),
        "%{all_maybe_target}": repr(all_maybe_target),
        "%{enable_cpus}": repr(rctx.attr.enable_cpus),
        "%{additional_cxx_builtin_include_directories}": repr(additional_cxx_builtin_include_directories),
    }

    rctx.template(
        "toolchains.bzl",
        Label("@com_grail_bazel_toolchain//toolchain:toolchains.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "cc_toolchain_config.bzl",
        Label("@com_grail_bazel_toolchain//toolchain:cc_toolchain_config.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "bin/cc_wrapper.sh",  # Co-located with the linker to help rules_go.
        Label("@com_grail_bazel_toolchain//toolchain:cc_wrapper.sh.tpl"),
        substitutions,
    )
    rctx.template(
        "Makevars",
        Label("@com_grail_bazel_toolchain//toolchain:Makevars.tpl"),
        substitutions,
    )
    rctx.template(
        "BUILD",
        Label("@com_grail_bazel_toolchain//toolchain:BUILD.tpl"),
        substitutions,
    )

    if rctx.attr.go_support:
        rctx.symlink("/usr/bin/ar", "bin/ar")  # For GoLink.

        # For GoCompile on macOS; compiler path is set from linker path.
        # It also helps clang driver sometimes for the linker to be colocated with the compiler.
        rctx.symlink("/usr/bin/ld", "bin/ld")
        if rctx.os.name == "linux":
            rctx.symlink("/usr/bin/ld.gold", "bin/ld.gold")
        else:
            # Add dummy file for non-linux so we don't have to put conditional logic in BUILD.
            rctx.file("bin/ld.gold")
    else:
        # Add dummy files so we don't have to put conditional logic in BUILD
        rctx.file("bin/ld")
        rctx.file("bin/ld.gold")

    # Repository implementation functions can be restarted, keep expensive ops at the end.
    if not _download_llvm(rctx):
        _download_llvm_preconfigured(rctx)

def conditional_cc_toolchain(name, toolchain_config, darwin, absolute_paths = False):
    # Toolchain macro for BUILD file to use conditional logic.

    if absolute_paths:
        _cc_toolchain(
            name = name,
            all_files = ":empty",
            compiler_files = ":empty",
            dwp_files = ":empty",
            linker_files = ":empty",
            objcopy_files = ":empty",
            strip_files = ":empty",
            supports_param_files = 0 if darwin else 1,
            toolchain_config = toolchain_config,
        )
    else:
        extra_files = [":cc_wrapper"] if darwin else []
        native.filegroup(name = name + "-all-files", srcs = [":all_components"] + extra_files)
        native.filegroup(name = name + "-archiver-files", srcs = [":ar"] + extra_files)
        native.filegroup(name = name + "-assembler-files", srcs = [":as"] + extra_files)
        native.filegroup(name = name + "-compiler-files", srcs = [":compiler_components"] + extra_files)
        native.filegroup(name = name + "-linker-files", srcs = [":linker_components"] + extra_files)
        _cc_toolchain(
            name = name,
            all_files = name + "-all-files",
            ar_files = name + "-archiver-files",
            as_files = name + "-assembler-files",
            compiler_files = name + "-compiler-files",
            dwp_files = ":empty",
            linker_files = name + "-linker-files",
            objcopy_files = ":objcopy",
            strip_files = ":strip",
            supports_param_files = 0 if darwin else 1,
            toolchain_config = toolchain_config,
        )
