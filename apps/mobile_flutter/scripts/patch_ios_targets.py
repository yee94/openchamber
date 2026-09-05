#!/usr/bin/env python3
"""Inject the four native iOS targets into Runner.xcodeproj/project.pbxproj."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "ios" / "Runner.xcodeproj" / "project.pbxproj"

# 24-char hex IDs (Xcode style). Do not copy Capacitor DEVELOPMENT_TEAM.
IDS = {
    "embed": "F0D0000000000000000000E1",
    "widget_shared": "F0A1000000000000000000A1",
    "widget_widgets": "F0A1000000000000000000A2",
    "widget_control": "F0A1000000000000000000A3",
    "widget_live": "F0A1000000000000000000A4",
    "widget_attrs": "F0A1000000000000000000A5",
    "widget_assets": "F0A1000000000000000000A6",
    "widget_ent": "F0A1000000000000000000A7",
    "widget_info": "F0A1000000000000000000A8",
    "widget_product": "F0A1000000000000000000A9",
    "widget_src_shared": "F0A2000000000000000000B1",
    "widget_src_widgets": "F0A2000000000000000000B2",
    "widget_src_control": "F0A2000000000000000000B3",
    "widget_src_live": "F0A2000000000000000000B4",
    "widget_src_attrs": "F0A2000000000000000000B5",
    "widget_res_assets": "F0A2000000000000000000B6",
    "widget_embed": "F0A2000000000000000000B7",
    "widget_fw": "F0A3000000000000000000C1",
    "widget_res": "F0A3000000000000000000C2",
    "widget_src": "F0A3000000000000000000C3",
    "widget_proxy": "F0A4000000000000000000D1",
    "widget_dep": "F0A4000000000000000000D2",
    "widget_target": "F0A4000000000000000000D3",
    "widget_dbg": "F0A5000000000000000000E1",
    "widget_rel": "F0A5000000000000000000E2",
    "widget_prf": "F0A5000000000000000000E3",
    "widget_group": "F0A6000000000000000000F1",
    "widget_cfgs": "F0A8000000000000000000A1",
    "nse_src_file": "F0B1000000000000000000A1",
    "nse_ent": "F0B1000000000000000000A2",
    "nse_info": "F0B1000000000000000000A3",
    "nse_product": "F0B1000000000000000000A7",
    "nse_src_build": "F0B2000000000000000000B1",
    "nse_embed": "F0B2000000000000000000B5",
    "nse_fw": "F0B3000000000000000000C1",
    "nse_res": "F0B3000000000000000000C2",
    "nse_src": "F0B3000000000000000000C3",
    "nse_proxy": "F0B4000000000000000000D1",
    "nse_dep": "F0B4000000000000000000D2",
    "nse_target": "F0B4000000000000000000D3",
    "nse_dbg": "F0B5000000000000000000E1",
    "nse_rel": "F0B5000000000000000000E2",
    "nse_prf": "F0B5000000000000000000E3",
    "nse_group": "F0B6000000000000000000F1",
    "nse_cfgs": "F0B8000000000000000000A1",
    "share_vc": "F0E1000000000000000000A1",
    "share_info": "F0E1000000000000000000A2",
    "share_ent": "F0E1000000000000000000A3",
    "share_product": "F0E1000000000000000000A4",
    "share_src_vc": "F0E2000000000000000000B1",
    "share_src_store": "F0E2000000000000000000B2",
    "share_embed": "F0E2000000000000000000B3",
    "share_fw": "F0E3000000000000000000C1",
    "share_res": "F0E3000000000000000000C2",
    "share_src": "F0E3000000000000000000C3",
    "share_proxy": "F0E4000000000000000000D1",
    "share_dep": "F0E4000000000000000000D2",
    "share_target": "F0E4000000000000000000D3",
    "share_dbg": "F0E5000000000000000000E1",
    "share_rel": "F0E5000000000000000000E2",
    "share_prf": "F0E5000000000000000000E3",
    "share_group": "F0E6000000000000000000F1",
    "share_cfgs": "F0E8000000000000000000A1",
    "store_file": "F0D1000000000000000000A1",
    "la_mgr": "F0D3000000000000000000A2",
    "la_attrs_runner": "F0D3000000000000000000A1",
    "control_runner": "F0A1000000000000000000C3",
    "composer_view": "F0D4000000000000000000A1",
    "tab_view": "F0D5000000000000000000A1",
    "plugins": "F0C1000000000000000000A1",
    "store_src": "F0D2000000000000000000B1",
    "la_mgr_src": "F0D3000000000000000000B3",
    "la_attrs_src": "F0D3000000000000000000B1",
    "control_src": "F0A2000000000000000000C3",
    "composer_src": "F0D4000000000000000000B1",
    "tab_src": "F0D5000000000000000000B1",
    "plugins_src": "F0C2000000000000000000B1",
    "native_group": "F0C6000000000000000000F1",
}

def ext_settings(bundle, plist, entitlements, deploy):
    return f"""{{
				CODE_SIGN_ENTITLEMENTS = {entitlements};
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = {plist};
				IPHONEOS_DEPLOYMENT_TARGET = {deploy};
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = {bundle};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}}"""


def main() -> None:
    text = PBX.read_text()
    if "OpenChamberWidget" in text and "PBXNativeTarget" in text and "com.yee94.openchamber.OpenChamberWidget" in text:
        print("pbxproj already has extension targets")
        return

    build_files = f"""
		{IDS['widget_src_shared']} /* WidgetShared.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_shared']} /* WidgetShared.swift */; }};
		{IDS['widget_src_widgets']} /* OpenChamberWidgets.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_widgets']} /* OpenChamberWidgets.swift */; }};
		{IDS['widget_src_control']} /* OpenChamberControl.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_control']} /* OpenChamberControl.swift */; }};
		{IDS['widget_src_live']} /* OpenChamberLiveActivity.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_live']} /* OpenChamberLiveActivity.swift */; }};
		{IDS['widget_src_attrs']} /* OpenChamberActivityAttributes.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_attrs']} /* OpenChamberActivityAttributes.swift */; }};
		{IDS['widget_res_assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_assets']} /* Assets.xcassets */; }};
		{IDS['widget_embed']} /* OpenChamberWidget.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {IDS['widget_product']} /* OpenChamberWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
		{IDS['nse_src_build']} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['nse_src_file']} /* NotificationService.swift */; }};
		{IDS['nse_embed']} /* OpenChamberNotificationService.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {IDS['nse_product']} /* OpenChamberNotificationService.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
		{IDS['share_src_vc']} /* ShareViewController.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['share_vc']} /* ShareViewController.swift */; }};
		{IDS['share_src_store']} /* OpenChamberShareStore.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['store_file']} /* OpenChamberShareStore.swift */; }};
		{IDS['share_embed']} /* OpenChamberShareExtension.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {IDS['share_product']} /* OpenChamberShareExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
		{IDS['store_src']} /* OpenChamberShareStore.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['store_file']} /* OpenChamberShareStore.swift */; }};
		{IDS['la_mgr_src']} /* OpenChamberLiveActivityManager.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['la_mgr']} /* OpenChamberLiveActivityManager.swift */; }};
		{IDS['la_attrs_src']} /* OpenChamberActivityAttributes.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['la_attrs_runner']} /* OpenChamberActivityAttributes.swift */; }};
		{IDS['control_src']} /* OpenChamberControl.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['control_runner']} /* OpenChamberControl.swift */; }};
		{IDS['composer_src']} /* OpenChamberComposerView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['composer_view']} /* OpenChamberComposerView.swift */; }};
		{IDS['tab_src']} /* OpenChamberTabBarView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['tab_view']} /* OpenChamberTabBarView.swift */; }};
		{IDS['plugins_src']} /* OpenChamberFlutterPlugins.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS['plugins']} /* OpenChamberFlutterPlugins.swift */; }};
"""
    text = text.replace("/* End PBXBuildFile section */", build_files + "/* End PBXBuildFile section */")

    proxies = f"""
		{IDS['widget_proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 97C146E61CF9000F007C117D /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {IDS['widget_target']};
			remoteInfo = OpenChamberWidget;
		}};
		{IDS['nse_proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 97C146E61CF9000F007C117D /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {IDS['nse_target']};
			remoteInfo = OpenChamberNotificationService;
		}};
		{IDS['share_proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 97C146E61CF9000F007C117D /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {IDS['share_target']};
			remoteInfo = OpenChamberShareExtension;
		}};
"""
    text = text.replace("/* End PBXContainerItemProxy section */", proxies + "/* End PBXContainerItemProxy section */")

    embed = f"""
		{IDS['embed']} /* Embed App Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				{IDS['widget_embed']} /* OpenChamberWidget.appex in Embed App Extensions */,
				{IDS['nse_embed']} /* OpenChamberNotificationService.appex in Embed App Extensions */,
				{IDS['share_embed']} /* OpenChamberShareExtension.appex in Embed App Extensions */,
			);
			name = "Embed App Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
    text = text.replace("/* End PBXCopyFilesBuildPhase section */", embed + "/* End PBXCopyFilesBuildPhase section */")

    file_refs = f"""
		{IDS['widget_shared']} /* WidgetShared.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetShared.swift; sourceTree = "<group>"; }};
		{IDS['widget_widgets']} /* OpenChamberWidgets.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberWidgets.swift; sourceTree = "<group>"; }};
		{IDS['widget_control']} /* OpenChamberControl.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberControl.swift; sourceTree = "<group>"; }};
		{IDS['widget_live']} /* OpenChamberLiveActivity.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberLiveActivity.swift; sourceTree = "<group>"; }};
		{IDS['widget_attrs']} /* OpenChamberActivityAttributes.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberActivityAttributes.swift; sourceTree = "<group>"; }};
		{IDS['widget_assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{IDS['widget_ent']} /* OpenChamberWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = OpenChamberWidget.entitlements; sourceTree = "<group>"; }};
		{IDS['widget_info']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{IDS['widget_product']} /* OpenChamberWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = OpenChamberWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{IDS['nse_src_file']} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; }};
		{IDS['nse_ent']} /* OpenChamberNotificationService.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = OpenChamberNotificationService.entitlements; sourceTree = "<group>"; }};
		{IDS['nse_info']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{IDS['nse_product']} /* OpenChamberNotificationService.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = OpenChamberNotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{IDS['share_vc']} /* ShareViewController.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareViewController.swift; sourceTree = "<group>"; }};
		{IDS['share_info']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{IDS['share_ent']} /* OpenChamberShareExtension.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = OpenChamberShareExtension.entitlements; sourceTree = "<group>"; }};
		{IDS['share_product']} /* OpenChamberShareExtension.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = OpenChamberShareExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{IDS['store_file']} /* OpenChamberShareStore.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberShareStore.swift; sourceTree = "<group>"; }};
		{IDS['la_mgr']} /* OpenChamberLiveActivityManager.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberLiveActivityManager.swift; sourceTree = "<group>"; }};
		{IDS['la_attrs_runner']} /* OpenChamberActivityAttributes.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberActivityAttributes.swift; sourceTree = "<group>"; }};
		{IDS['control_runner']} /* OpenChamberControl.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberControl.swift; sourceTree = "<group>"; }};
		{IDS['composer_view']} /* OpenChamberComposerView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberComposerView.swift; sourceTree = "<group>"; }};
		{IDS['tab_view']} /* OpenChamberTabBarView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberTabBarView.swift; sourceTree = "<group>"; }};
		{IDS['plugins']} /* OpenChamberFlutterPlugins.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OpenChamberFlutterPlugins.swift; sourceTree = "<group>"; }};
"""
    text = text.replace("/* End PBXFileReference section */", file_refs + "/* End PBXFileReference section */")

    frameworks = f"""
		{IDS['widget_fw']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['nse_fw']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['share_fw']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
    text = text.replace("/* End PBXFrameworksBuildPhase section */", frameworks + "/* End PBXFrameworksBuildPhase section */")

    groups = f"""
		{IDS['widget_group']} /* OpenChamberWidget */ = {{
			isa = PBXGroup;
			children = (
				{IDS['widget_shared']} /* WidgetShared.swift */,
				{IDS['widget_widgets']} /* OpenChamberWidgets.swift */,
				{IDS['widget_live']} /* OpenChamberLiveActivity.swift */,
				{IDS['widget_attrs']} /* OpenChamberActivityAttributes.swift */,
				{IDS['widget_control']} /* OpenChamberControl.swift */,
				{IDS['widget_assets']} /* Assets.xcassets */,
				{IDS['widget_info']} /* Info.plist */,
				{IDS['widget_ent']} /* OpenChamberWidget.entitlements */,
			);
			path = OpenChamberWidget;
			sourceTree = "<group>";
		}};
		{IDS['nse_group']} /* OpenChamberNotificationService */ = {{
			isa = PBXGroup;
			children = (
				{IDS['nse_src_file']} /* NotificationService.swift */,
				{IDS['nse_info']} /* Info.plist */,
				{IDS['nse_ent']} /* OpenChamberNotificationService.entitlements */,
			);
			path = OpenChamberNotificationService;
			sourceTree = "<group>";
		}};
		{IDS['share_group']} /* OpenChamberShareExtension */ = {{
			isa = PBXGroup;
			children = (
				{IDS['share_vc']} /* ShareViewController.swift */,
				{IDS['share_info']} /* Info.plist */,
				{IDS['share_ent']} /* OpenChamberShareExtension.entitlements */,
			);
			path = OpenChamberShareExtension;
			sourceTree = "<group>";
		}};
		{IDS['native_group']} /* Native */ = {{
			isa = PBXGroup;
			children = (
				{IDS['store_file']} /* OpenChamberShareStore.swift */,
				{IDS['la_mgr']} /* OpenChamberLiveActivityManager.swift */,
				{IDS['la_attrs_runner']} /* OpenChamberActivityAttributes.swift */,
				{IDS['control_runner']} /* OpenChamberControl.swift */,
				{IDS['composer_view']} /* OpenChamberComposerView.swift */,
				{IDS['tab_view']} /* OpenChamberTabBarView.swift */,
				{IDS['plugins']} /* OpenChamberFlutterPlugins.swift */,
			);
			path = Native;
			sourceTree = "<group>";
		}};
"""
    text = text.replace("/* End PBXGroup section */", groups + "/* End PBXGroup section */")
    text = text.replace(
        "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n",
        f"\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n\t\t\t\t{IDS['widget_group']} /* OpenChamberWidget */,\n\t\t\t\t{IDS['nse_group']} /* OpenChamberNotificationService */,\n\t\t\t\t{IDS['share_group']} /* OpenChamberShareExtension */,\n",
    )
    text = text.replace(
        "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n",
        f"\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n\t\t\t\t{IDS['widget_product']} /* OpenChamberWidget.appex */,\n\t\t\t\t{IDS['nse_product']} /* OpenChamberNotificationService.appex */,\n\t\t\t\t{IDS['share_product']} /* OpenChamberShareExtension.appex */,\n",
    )
    text = text.replace(
        "\t\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,\n",
        f"\t\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,\n\t\t\t\t{IDS['native_group']} /* Native */,\n",
    )

    targets = f"""
		{IDS['widget_target']} /* OpenChamberWidget */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {IDS['widget_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberWidget" */;
			buildPhases = (
				{IDS['widget_src']} /* Sources */,
				{IDS['widget_fw']} /* Frameworks */,
				{IDS['widget_res']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = OpenChamberWidget;
			productName = OpenChamberWidget;
			productReference = {IDS['widget_product']} /* OpenChamberWidget.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
		{IDS['nse_target']} /* OpenChamberNotificationService */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {IDS['nse_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberNotificationService" */;
			buildPhases = (
				{IDS['nse_src']} /* Sources */,
				{IDS['nse_fw']} /* Frameworks */,
				{IDS['nse_res']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = OpenChamberNotificationService;
			productName = OpenChamberNotificationService;
			productReference = {IDS['nse_product']} /* OpenChamberNotificationService.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
		{IDS['share_target']} /* OpenChamberShareExtension */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {IDS['share_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberShareExtension" */;
			buildPhases = (
				{IDS['share_src']} /* Sources */,
				{IDS['share_fw']} /* Frameworks */,
				{IDS['share_res']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = OpenChamberShareExtension;
			productName = OpenChamberShareExtension;
			productReference = {IDS['share_product']} /* OpenChamberShareExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
"""
    text = text.replace("/* End PBXNativeTarget section */", targets + "/* End PBXNativeTarget section */")
    text = text.replace(
        "\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,",
        f"\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n\t\t\t\t{IDS['embed']} /* Embed App Extensions */,\n\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,",
    )
    text = text.replace(
        "\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Runner;",
        f"""\t\t\tdependencies = (
\t\t\t\t{IDS['widget_dep']} /* PBXTargetDependency */,
\t\t\t\t{IDS['nse_dep']} /* PBXTargetDependency */,
\t\t\t\t{IDS['share_dep']} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = Runner;""",
    )
    text = text.replace(
        "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n",
        f"\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n\t\t\t\t{IDS['widget_target']} /* OpenChamberWidget */,\n\t\t\t\t{IDS['nse_target']} /* OpenChamberNotificationService */,\n\t\t\t\t{IDS['share_target']} /* OpenChamberShareExtension */,\n",
    )

    resources = f"""
		{IDS['widget_res']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['widget_res_assets']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['nse_res']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['share_res']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
    text = text.replace("/* End PBXResourcesBuildPhase section */", resources + "/* End PBXResourcesBuildPhase section */")

    sources = f"""
		{IDS['widget_src']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['widget_src_shared']} /* WidgetShared.swift in Sources */,
				{IDS['widget_src_widgets']} /* OpenChamberWidgets.swift in Sources */,
				{IDS['widget_src_control']} /* OpenChamberControl.swift in Sources */,
				{IDS['widget_src_live']} /* OpenChamberLiveActivity.swift in Sources */,
				{IDS['widget_src_attrs']} /* OpenChamberActivityAttributes.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['nse_src']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['nse_src_build']} /* NotificationService.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['share_src']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['share_src_vc']} /* ShareViewController.swift in Sources */,
				{IDS['share_src_store']} /* OpenChamberShareStore.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
    text = text.replace("/* End PBXSourcesBuildPhase section */", sources + "/* End PBXSourcesBuildPhase section */")
    text = text.replace(
        "\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,\n\t\t\t\t1498D2341E8E89220040F4C2 /* GeneratedPluginRegistrant.m in Sources */,",
        f"""\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,
\t\t\t\t1498D2341E8E89220040F4C2 /* GeneratedPluginRegistrant.m in Sources */,
\t\t\t\t{IDS['store_src']} /* OpenChamberShareStore.swift in Sources */,
\t\t\t\t{IDS['la_mgr_src']} /* OpenChamberLiveActivityManager.swift in Sources */,
\t\t\t\t{IDS['la_attrs_src']} /* OpenChamberActivityAttributes.swift in Sources */,
\t\t\t\t{IDS['control_src']} /* OpenChamberControl.swift in Sources */,
\t\t\t\t{IDS['composer_src']} /* OpenChamberComposerView.swift in Sources */,
\t\t\t\t{IDS['tab_src']} /* OpenChamberTabBarView.swift in Sources */,
\t\t\t\t{IDS['plugins_src']} /* OpenChamberFlutterPlugins.swift in Sources */,""",
    )

    deps = f"""
		{IDS['widget_dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {IDS['widget_target']} /* OpenChamberWidget */;
			targetProxy = {IDS['widget_proxy']} /* PBXContainerItemProxy */;
		}};
		{IDS['nse_dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {IDS['nse_target']} /* OpenChamberNotificationService */;
			targetProxy = {IDS['nse_proxy']} /* PBXContainerItemProxy */;
		}};
		{IDS['share_dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {IDS['share_target']} /* OpenChamberShareExtension */;
			targetProxy = {IDS['share_proxy']} /* PBXContainerItemProxy */;
		}};
"""
    text = text.replace("/* End PBXTargetDependency section */", deps + "/* End PBXTargetDependency section */")

    widget_cfg = ext_settings(
        "com.yee94.openchamber.OpenChamberWidget",
        "OpenChamberWidget/Info.plist",
        "OpenChamberWidget/OpenChamberWidget.entitlements",
        "17.0",
    )
    nse_cfg = ext_settings(
        "com.yee94.openchamber.OpenChamberNotificationService",
        "OpenChamberNotificationService/Info.plist",
        "OpenChamberNotificationService/OpenChamberNotificationService.entitlements",
        "15.5",
    )
    share_cfg = ext_settings(
        "com.yee94.openchamber.OpenChamberShareExtension",
        "OpenChamberShareExtension/Info.plist",
        "OpenChamberShareExtension/OpenChamberShareExtension.entitlements",
        "15.5",
    )
    configs = f"""
		{IDS['widget_dbg']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {widget_cfg}
			name = Debug;
		}};
		{IDS['widget_rel']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {widget_cfg}
			name = Release;
		}};
		{IDS['widget_prf']} /* Profile */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {widget_cfg}
			name = Profile;
		}};
		{IDS['nse_dbg']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {nse_cfg}
			name = Debug;
		}};
		{IDS['nse_rel']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {nse_cfg}
			name = Release;
		}};
		{IDS['nse_prf']} /* Profile */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {nse_cfg}
			name = Profile;
		}};
		{IDS['share_dbg']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {share_cfg}
			name = Debug;
		}};
		{IDS['share_rel']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {share_cfg}
			name = Release;
		}};
		{IDS['share_prf']} /* Profile */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {share_cfg}
			name = Profile;
		}};
"""
    text = text.replace("/* End XCBuildConfiguration section */", configs + "/* End XCBuildConfiguration section */")

    lists = f"""
		{IDS['widget_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberWidget" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['widget_dbg']} /* Debug */,
				{IDS['widget_rel']} /* Release */,
				{IDS['widget_prf']} /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{IDS['nse_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberNotificationService" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['nse_dbg']} /* Debug */,
				{IDS['nse_rel']} /* Release */,
				{IDS['nse_prf']} /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{IDS['share_cfgs']} /* Build configuration list for PBXNativeTarget "OpenChamberShareExtension" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['share_dbg']} /* Debug */,
				{IDS['share_rel']} /* Release */,
				{IDS['share_prf']} /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
"""
    text = text.replace("/* End XCConfigurationList section */", lists + "/* End XCConfigurationList section */")

    for marker in (
        "97C147061CF9000F007C117D /* Debug */",
        "97C147071CF9000F007C117D /* Release */",
        "249021D4217E4FDB00AE95B9 /* Profile */",
    ):
        old = f"{marker} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference"
        # add entitlements + deploy after CLANG_ENABLE_MODULES
        pass

    text = text.replace(
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tCLANG_ENABLE_MODULES = YES;\n\t\t\t\tCURRENT_PROJECT_VERSION = \"$(FLUTTER_BUILD_NUMBER)\";\n\t\t\t\tENABLE_BITCODE = NO;\n\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;",
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tCLANG_ENABLE_MODULES = YES;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tCURRENT_PROJECT_VERSION = \"$(FLUTTER_BUILD_NUMBER)\";\n\t\t\t\tENABLE_BITCODE = NO;\n\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.5;",
    )
    text = text.replace("IPHONEOS_DEPLOYMENT_TARGET = 12.0;", "IPHONEOS_DEPLOYMENT_TARGET = 15.5;")

    PBX.write_text(text)
    print("patched", PBX)


if __name__ == "__main__":
    main()
