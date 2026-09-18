#!/usr/bin/env python3
"""Generates BlueRing.xcodeproj/project.pbxproj for the Inkpulse iOS game.
Deterministic UUIDs (uuid5 of the path) keep the file stable."""
import os, uuid

ROOT = "/home/hatch/workspace/bluering"
PROJDIR = os.path.join(ROOT, "BlueRing.xcodeproj")
os.makedirs(PROJDIR, exist_ok=True)

def uid(name: str) -> str:
    return uuid.uuid5(uuid.NAMESPACE_URL, "bluering:" + name).hex[:24].upper()

# (path relative to BlueRing/, lastKnownFileType, in sources?, in resources?)
SWIFT_FILES = [
    "BlueRingApp.swift",
    "ContentView.swift",
    "Game/GameScene.swift",
    "Game/OctopusNode.swift",
    "Game/Predators.swift",
    "Services/GameState.swift",
    "Services/Helpers.swift",
    "Services/StoreService.swift",
    "Services/AdsService.swift",
    "Services/GameCenterService.swift",
]
OTHER_FILES = [
    ("BlueRing.storekit", "file.storekit", False, False),
    ("BlueRing.entitlements", "text.plist.entitlements", False, False),
    ("Assets.xcassets", "folder.assetcatalog", False, True),
]

o = []  # objects lines

def emit(line: str):
    o.append(line)

# ---------- ids ----------
proj_id = uid("project")
target_id = uid("target")
main_group = uid("group:main")
app_group = uid("group:BlueRing")
game_group = uid("group:Game")
svc_group = uid("group:Services")
products_group = uid("group:Products")
app_ref = uid("ref:BlueRing.app")
sources_phase = uid("phase:sources")
frameworks_phase = uid("phase:frameworks")
resources_phase = uid("phase:resources")
proj_cfg_list = uid("cfglist:project")
target_cfg_list = uid("cfglist:target")
proj_dbg = uid("config:project:debug")
proj_rel = uid("config:project:release")
tgt_dbg = uid("config:target:debug")
tgt_rel = uid("config:target:release")

build_files = {}   # path -> buildfile id
file_refs = {}     # path -> fileref id
for p in SWIFT_FILES:
    build_files[p] = uid("build:" + p)
    file_refs[p] = uid("ref:" + p)
for p, _, _, _ in OTHER_FILES:
    file_refs[p] = uid("ref:" + p)
    if p == "Assets.xcassets":
        build_files[p] = uid("build:" + p)

# ---------- PBXBuildFile ----------
emit("/* Begin PBXBuildFile section */")
for p in SWIFT_FILES:
    emit(f"\t\t{build_files[p]} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[p]} /* {os.path.basename(p)} */; }};")
emit(f"\t\t{build_files['Assets.xcassets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs['Assets.xcassets']} /* Assets.xcassets */; }};")
emit("/* End PBXBuildFile section */")
emit("")

# ---------- PBXFileReference ----------
emit("/* Begin PBXFileReference section */")
for p in SWIFT_FILES:
    emit(f"\t\t{file_refs[p]} /* {os.path.basename(p)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(p)}; sourceTree = \"<group>\"; }};")
for p, ftype, _, _ in OTHER_FILES:
    emit(f"\t\t{file_refs[p]} /* {p} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {p}; sourceTree = \"<group>\"; }};")
emit(f"\t\t{app_ref} /* BlueRing.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BlueRing.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
emit("/* End PBXFileReference section */")
emit("")

# ---------- Phases ----------
emit("/* Begin PBXFrameworksBuildPhase section */")
emit(f"\t\t{frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
emit("/* End PBXFrameworksBuildPhase section */")
emit("")
emit("/* Begin PBXResourcesBuildPhase section */")
emit(f"\t\t{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({build_files['Assets.xcassets']} /* Assets.xcassets in Resources */,); runOnlyForDeploymentPostprocessing = 0; }};")
emit("/* End PBXResourcesBuildPhase section */")
emit("")
emit("/* Begin PBXSourcesBuildPhase section */")
src_files = ",\n".join(f"\t\t\t\t{build_files[p]} /* {os.path.basename(p)} in Sources */" for p in SWIFT_FILES)
emit(f"\t\t{sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n{src_files},\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; }};")
emit("/* End PBXSourcesBuildPhase section */")
emit("")

# ---------- Groups ----------
emit("/* Begin PBXGroup section */")
emit(f"\t\t{main_group} = {{isa = PBXGroup; children = ({app_group}, {products_group},); sourceTree = \"<group>\"; }};")
emit(f"\t\t{app_group} = {{isa = PBXGroup; children = ({file_refs['BlueRingApp.swift']}, {file_refs['ContentView.swift']}, {game_group}, {svc_group}, {file_refs['BlueRing.storekit']}, {file_refs['BlueRing.entitlements']}, {file_refs['Assets.xcassets']},); name = BlueRing; path = BlueRing; sourceTree = \"<group>\"; }};")
game_children = ", ".join(file_refs[p] for p in SWIFT_FILES if p.startswith("Game/"))
svc_children = ", ".join(file_refs[p] for p in SWIFT_FILES if p.startswith("Services/"))
emit(f"\t\t{game_group} = {{isa = PBXGroup; children = ({game_children},); name = Game; sourceTree = \"<group>\"; }};")
emit(f"\t\t{svc_group} = {{isa = PBXGroup; children = ({svc_children},); name = Services; sourceTree = \"<group>\"; }};")
emit(f"\t\t{products_group} = {{isa = PBXGroup; children = ({app_ref} /* BlueRing.app */,); name = Products; sourceTree = \"<group>\"; }};")
emit("/* End PBXGroup section */")
emit("")

# ---------- Target ----------
emit("/* Begin PBXNativeTarget section */")
emit(f"\t\t{target_id} /* BlueRing */ = {{isa = PBXNativeTarget; buildConfigurationList = {target_cfg_list} /* Build configuration list for PBXNativeTarget \"BlueRing\" */; buildPhases = ({sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */,); buildRules = (); dependencies = (); name = BlueRing; productName = BlueRing; productReference = {app_ref} /* BlueRing.app */; productType = \"com.apple.product-type.application\"; }};")
emit("/* End PBXNativeTarget section */")
emit("")

# ---------- Project ----------
emit("/* Begin PBXProject section */")
emit(f"\t\t{proj_id} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{{target_id} = {{CreatedOnToolsVersion = 16.0; }};}};}}; buildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject \"BlueRing\" */; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,); mainGroup = {main_group}; productRefGroup = {products_group} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = ({target_id} /* BlueRing */,); }};")
emit("/* End PBXProject section */")
emit("")

# ---------- Configurations ----------
def cfg(id_, name, settings):
    lines = [f"\t\t{id_} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{"]
    for k, v in settings.items():
        lines.append(f"\t\t\t{k} = {v};")
    lines.append("\t\t}; name = %s; };" % name)
    return "\n".join(lines)

proj_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "COPY_PHASE_STRIP": "NO",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
}
proj_dbg = dict(proj_common, DEBUG_INFORMATION_FORMAT="dwarf",
                GCC_DYNAMIC_NO_PIC="NO", GCC_OPTIMIZATION_LEVEL="0",
                GCC_PREPROCESSOR_DEFINITIONS='("DEBUG=1", "$(inherited)")',
                MTL_ENABLE_DEBUG_INFO="INCLUDE_SOURCE", ONLY_ACTIVE_ARCH="YES",
                SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG",
                SWIFT_OPTIMIZATION_LEVEL='"-Onone"')
proj_rel = dict(proj_common, DEBUG_INFORMATION_FORMAT='"dwarf-with-dsym"',
                ENABLE_NS_ASSERTIONS="NO", MTL_ENABLE_DEBUG_INFO="NO",
                SWIFT_OPTIMIZATION_LEVEL='"-O"', VALIDATE_PRODUCT="YES")

tgt_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CODE_SIGN_ENTITLEMENTS": "BlueRing/BlueRing.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": '""',
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Inkpulse",
    "INFOPLIST_KEY_LSRequiresIPhoneOS": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIRequiredDeviceCapabilities": "arm64",
    "INFOPLIST_KEY_UIStatusBarStyle": "UIStatusBarStyleLightContent",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": '"UIInterfaceOrientationPortrait"',
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.rhymaun.bluering",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
tgt_dbg = dict(tgt_common, CODE_SIGN_IDENTITY='"Apple Development"',
               DEBUG_INFORMATION_FORMAT="dwarf", GCC_OPTIMIZATION_LEVEL="0",
               SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG",
               SWIFT_OPTIMIZATION_LEVEL='"-Onone"', ONLY_ACTIVE_ARCH="YES")
tgt_rel = dict(tgt_common, CODE_SIGN_IDENTITY='"Apple Distribution"',
               DEBUG_INFORMATION_FORMAT='"dwarf-with-dsym"',
               SWIFT_OPTIMIZATION_LEVEL='"-O"', VALIDATE_PRODUCT="YES")

emit("/* Begin XCBuildConfiguration section */")
emit(cfg(proj_dbg, "Debug", proj_dbg))
emit(cfg(proj_rel, "Release", proj_rel))
emit(cfg(tgt_dbg, "Debug", tgt_dbg))
emit(cfg(tgt_rel, "Release", tgt_rel))
emit("/* End XCBuildConfiguration section */")
emit("")

# ---------- Configuration lists ----------
emit("/* Begin XCConfigurationList section */")
emit(f"\t\t{proj_cfg_list} /* Build configuration list for PBXProject \"BlueRing\" */ = {{isa = XCConfigurationList; buildConfigurations = ({proj_dbg} /* Debug */, {proj_rel} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
emit(f"\t\t{target_cfg_list} /* Build configuration list for PBXNativeTarget \"BlueRing\" */ = {{isa = XCConfigurationList; buildConfigurations = ({tgt_dbg} /* Debug */, {tgt_rel} /* Release */,); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
emit("/* End XCConfigurationList section */")

body = "\n".join(o)
header = """// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {
"""
footer = f"""\t}};
\trootObject = {proj_id} /* Project object */;
}}
"""

with open(os.path.join(PROJDIR, "project.pbxproj"), "w") as f:
    f.write(header + body + "\n" + footer)

# crude balance sanity check
text = header + body + "\n" + footer
assert text.count("{") == text.count("}"), "brace mismatch"
assert text.count("(") == text.count(")"), "paren mismatch"
print("wrote project.pbxproj, balance OK")
