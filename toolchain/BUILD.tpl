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

package(default_visibility = ["//visibility:public"])

load("@rules_cc//cc:defs.bzl", "cc_toolchain_suite")

exports_files(["Makevars"])

# Some targets may need to directly depend on these files.
exports_files(glob(["bin/*", "lib/*"]))

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "cc_wrapper",
    srcs = ["bin/cc_wrapper.sh"],
)

filegroup(
    name = "sysroot_components",
    srcs = %{sysroot_labels},
)

load(":cc_toolchain_config.bzl", "do_toolchain_configs")

do_toolchain_configs()

## LLVM toolchain files
# Needed when not using absolute paths.

filegroup(
    name = "clang",
    srcs = [
        "bin/clang",
        "bin/clang++",
        "bin/clang-cpp",
    ],
)

filegroup(
    name = "ld",
    srcs = [
        "bin/ld.lld",
        "bin/ld",
        "bin/ld.gold",  # Dummy file on non-linux.
    ],
)

filegroup(
    name = "include",
    srcs = glob([
        "libcxx-*/include/c++/**",
    ] + ["%sinclude/c++/**" % maybe_target for maybe_target in %{all_maybe_target}]
    + ["%slib/clang/%{llvm_version}/include/**" % maybe_target for maybe_target in %{all_maybe_target}]
    ),
)

filegroup(
    name = "lib",
    srcs = glob(
        [
            "libcxx-*/lib/lib*.a",
        ] + ["%slib/lib*.a" % maybe_target for maybe_target in %{all_maybe_target}]
        + ["%slib/clang/%{llvm_version}/lib/**/*.a" % maybe_target for maybe_target in %{all_maybe_target}]
        + ["%slib/clang/%{llvm_version}/lib/**/*.a.syms" % maybe_target for maybe_target in %{all_maybe_target}],
        exclude = [
            "**/lib/libLLVM*.a",
            "**/lib/libclang*.a",
            "**/lib/liblld*.a",
        ],
    ),
)

filegroup(
    name = "compiler_components",
    srcs = [
        ":clang",
        ":include",
        ":sysroot_components",
        "@com_grail_bazel_toolchain//toolchain:blacklists",
    ] + %{cuda_path_labels},
)

filegroup(
    name = "ar",
    srcs = ["bin/llvm-ar"],
)

filegroup(
    name = "as",
    srcs = [
        "bin/clang",
        "bin/llvm-as",
    ],
)

filegroup(
    name = "nm",
    srcs = ["bin/llvm-nm"],
)

filegroup(
    name = "objcopy",
    srcs = ["bin/llvm-objcopy"],
)

filegroup(
    name = "strip",
    srcs = ["bin/llvm-strip"],
)

filegroup(
    name = "objdump",
    srcs = ["bin/llvm-objdump"],
)

filegroup(
    name = "profdata",
    srcs = ["bin/llvm-profdata"],
)

filegroup(
    name = "dwp",
    srcs = ["bin/llvm-dwp"],
)

filegroup(
    name = "ranlib",
    srcs = ["bin/llvm-ranlib"],
)

filegroup(
    name = "readelf",
    srcs = ["bin/llvm-readelf"],
)

filegroup(
    name = "clang-format",
    srcs = ["bin/clang-format"],
)

filegroup(
    name = "git-clang-format",
    srcs = ["bin/git-clang-format"],
)

sh_binary(
    name = "llvm-cov",
    srcs = ["bin/llvm-cov"],
)

filegroup(
    name = "binutils_components",
    srcs = glob(["bin/*"]),
)

filegroup(
    name = "linker_components",
    srcs = [
        ":clang",
        ":ld",
        ":ar",
        ":lib",
        ":sysroot_components",
        "@com_grail_bazel_toolchain//toolchain:blacklists",
    ],
)

filegroup(
    name = "all_components",
    srcs = [
        ":binutils_components",
        ":compiler_components",
        ":linker_components",
    ],
)
