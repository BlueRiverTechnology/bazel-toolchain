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

def _darwin_sdk_path(rctx):
    if rctx.os.name != "mac os x":
        return ""

    exec_result = rctx.execute(["/usr/bin/xcrun", "--show-sdk-path", "--sdk", "macosx"])
    if exec_result.return_code:
        fail("Failed to detect OSX SDK path: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    if exec_result.stderr:
        print(exec_result.stderr)
    return exec_result.stdout.strip()

def _default_sysroot(rctx):
    if rctx.os.name == "mac os x":
        return _darwin_sdk_path(rctx)
    else:
        return ""

def _tool_path(rctx, attr_value, default):
    tool_path = {}
    tool = {}
    for cpu in rctx.attr.enable_cpus:
        tool_value = attr_value.get(cpu, default = "")

        if not tool_value:
            tool_path[cpu] = default
            continue

        # If the path is an absolute path, use it as-is. Check for things that
        # start with "/" and not "//" to identify absolute paths, but also support
        # passing the path as "/" to indicate the root directory.
        if tool_value[0] == "/" and (len(tool_value) == 1 or tool_value[1] != "/"):
            tool_path[cpu] = tool_value
            continue

        tool[cpu] = Label(tool_value)
        if tool[cpu].workspace_root:
            tool_path[cpu] = tool[cpu].workspace_root + "/" + tool[cpu].package
        else:
            tool_path[cpu] = tool[cpu].package
    return tool_path, tool

# Return the sysroot path and the label to the files, if sysroot is not a system path, for each CPU.
def sysroot_path(rctx):
    return _tool_path(rctx, rctx.attr.sysroot, _default_sysroot(rctx))

def cuda_path(rctx):
    return _tool_path(rctx, rctx.attr.cuda_path, None)
