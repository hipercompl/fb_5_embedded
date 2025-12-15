/// Firebird 5 embedded server for Android.
///
/// Bundles the binaries of the Firebird embedded
/// server (from firebirdsql.org) in a Flutter plugin.
/// Contains convenient functions to set up the embedded
/// engine on Android, which requires deploying Firebird
/// config and data files in the filesystem of the target
/// Android device and setting up environment variables
/// so that the embedded engine knows where to look for
/// its internal files. Sets up temporary and lock
/// locations for the embedded engine.
library;

import "dart:io";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart" as path_provider;
import "package:osenv/osenv.dart" as osenv;

/// Prepares the bundled Firebird embedded engine on the local device.
///
/// This is the all-in-one function, performing all necessary steps
/// for Firebird embedded to work on an Android device.
///
/// It creates directories for the Firebird root folder, the temporary folder
/// and the folder for lock files and copies all required Firebird
/// assets to the Firebird root directory.
/// If [firebirdRoot] is not provided, the standard location (as returned
/// by [getFBRoot] function) will be used. The defaults for [firebirdTmp]
/// and [firebirdLock] are [firebirdRoot]/tmp and [firebirdRoot]/lock],
/// respectively.
///
/// The default location for assets is the private data directory of
/// the application (as returned by `getApplicationDocumentsDirectory`
/// of the path_provider plugin), in which a subdirectory `firebird`
/// will be created and all the assets will be placed inside it.
///
/// The calling code may omit all arguments (in which case the root directory
/// will be auto-determined, and tmp and lock will be set relative to it),
/// may provide only [firebirdRoot] (in which case tmp and lock will be
/// set relative to it), or use any other combination; any provided directory
/// will be used as is, one not provided will be determined automatically.
///
/// If any of the directories does not exist, it will be created.
///
/// If the root folder alreadt exists, by default
/// no assets will be copied (it is assumed the assets have already
/// been deployed), unless [forceRedeploy] is set to `true`,
/// in which case the assets will be copied again, overwriting
/// ones that are present in [firebirdRoot].
///
/// The assets are copied from the asset bundle [bundle], which
/// defaults to [rootBundle] if not provided (however, in some
/// scenarios you might want to provide your own bundle or
/// use `DefaultAssetBundle.of(context)`).
///
/// The function doesn't return anything, on errors exceptions are
/// thrown.
///
/// Example:
/// ```dart
/// import "package:fb_embedded/fb_embedded.dart" as fbe;
///
/// try {
///   await fbe.setUpEmbedded();
///   // embedded Firebird ready
/// } catch (e) {
///   // handle errors
/// }
/// ```
///
/// Example (provide custom directory, force redeployment):
/// ```dart
/// import "package:fb_embedded/fb_embedded.dart" as fbe;
///
/// try {
///   await fbe.setUpEmbedded(
///     firebirdRoot: "/tmp/fbemb",
///     forceRedeploy: true,
///   );
///   // embedded Firebird ready
/// } catch (e) {
///   // handle errors
/// }
/// ```
Future<void> setUpEmbedded({
  String? firebirdRoot,
  String? firebirdTmp,
  String? firebirdLock,
  AssetBundle? bundle,
  bool forceRedeploy = false,
}) async {
  if (!Platform.isAndroid) {
    throw UnimplementedError("Only Android platform is supported.");
  }
  firebirdRoot ??= await getDefaultFBRoot();
  firebirdTmp ??= "$firebirdRoot${Platform.pathSeparator}tmp";
  firebirdLock ??= "$firebirdRoot${Platform.pathSeparator}lock";

  final rootExisted = await Directory(firebirdRoot).exists();

  await createFBDirs(
    firebirdRoot: firebirdRoot,
    firebirdTmp: firebirdTmp,
    firebirdLock: firebirdLock,
  );
  await deployFBAssets(
    firebirdRoot: firebirdRoot,
    bundle: bundle,
    forceRedeploy: forceRedeploy || !rootExisted,
  );
  await setFBEnvVars(
    firebirdRoot: firebirdRoot,
    firebirdTmp: firebirdTmp,
    firebirdLock: firebirdLock,
    forceSet: forceRedeploy,
  );
}

/// Determines the default Firebird root directory.
///
/// This is the directory, in which all Firebird embedded assets
/// (configs, ICU data, firebird.msg) need to be stored.
/// On Adnroid, it is the `firebird` subdirectory of the private
/// data directory of the current application (as returned
/// by the `getApplicationDocumentsDirectory` function
/// from the path_provider plugin).
Future<String> getDefaultFBRoot() async {
  if (!Platform.isAndroid) {
    throw UnimplementedError("Only Android platform is supported.");
  }
  final docDir = await path_provider.getApplicationDocumentsDirectory();
  return "${docDir.absolute.path}${Platform.pathSeparator}firebird";
}

/// Sets the environment variables for Firebird embedded.
///
/// Setting the variables informs the Firebird embedded engine,
/// how to locate its root, temp and lock directories.
/// If [firebirdRoot] is not provided, the standard location (as returned
/// by [getFBRoot] function) will be used. The defaults for [firebirdTmp]
/// and [firebirdLock] are [firebirdRoot]/tmp and [firebirdRoot]/lock],
/// respectively.
/// The calling code may omit all arguments (in which case the root directory
/// will be auto-determined, and tmp and lock will be set relative to it),
/// may provide only [firebirdRoot] (in which case tmp and lock will be
/// set relative to it), or use any other combination; any provided directory
/// will be used as is, one not provided will be determined automatically.
/// By default, if any of the corresponding environment variables
/// (`FIREBIRD`, `FIREBIRD_TMP`, `FIREBIRD_LOCK`) is already set, it
/// won't be changed (will remain as is), unless [forceSet] is `true`.
Future<void> setFBEnvVars({
  String? firebirdRoot,
  String? firebirdTmp,
  String? firebirdLock,
  bool forceSet = false,
}) async {
  if (!Platform.isAndroid) {
    throw UnimplementedError("Only Android platform is supported.");
  }
  const fbRootVar = "FIREBIRD";
  const fbTmpVar = "FIREBIRD_TMP";
  const fbLockVar = "FIREBIRD_LOCK";

  firebirdRoot ??= await getDefaultFBRoot();
  firebirdTmp ??= "$firebirdRoot${Platform.pathSeparator}tmp";
  firebirdLock ??= "$firebirdRoot${Platform.pathSeparator}lock";

  _maybeSetVar(fbRootVar, firebirdRoot, forceSet);
  _maybeSetVar(fbTmpVar, firebirdTmp, forceSet);
  _maybeSetVar(fbLockVar, firebirdLock, forceSet);
}

/// Creates the directory structure for the Firebird embedded engine.
Future<void> createFBDirs({
  required String firebirdRoot,
  required String firebirdTmp,
  required String firebirdLock,
}) async {
  if (!Platform.isAndroid) {
    throw UnimplementedError("Only Android platform is supported.");
  }
  final dRoot = Directory(firebirdRoot);
  final dTmp = Directory(firebirdTmp);
  final dLock = Directory(firebirdLock);

  for (final dir in [dRoot, dTmp, dLock]) {
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
  }
}

/// Deploys Firebird embedded assets on the local device.
///
/// Copies the bundled Firebird embedded assets from the Flutter assets
/// bundled with the application to the Firebird root directory.
/// The root directory can be provided by the calling code, or
/// (when [firebirdRoot] is omitted) can be determined automatically
/// via [getFBRoot].
/// If the root folder is not present, it will be created and the assets
/// will be copied. On the other hand, if it does exist, by default
/// no assets will be copied, unless [forceRedeploy] is set to `true`,
/// in which case the assets will be copied again, possibly overwriting
/// ones that are present in [firebirdRoot].
Future<void> deployFBAssets({
  String? firebirdRoot,
  AssetBundle? bundle,
  bool forceRedeploy = false,
}) async {
  if (!Platform.isAndroid) {
    throw UnimplementedError("Only Android platform is supported.");
  }
  firebirdRoot ??= await getDefaultFBRoot();
  final rootExists = await Directory(firebirdRoot).exists();
  if (rootExists && !forceRedeploy) {
    // Firebird root already exists and we're not allowed to
    // re-deploy the assets
    return;
  } else if (!rootExists) {
    await Directory(firebirdRoot).create(recursive: true);
  }

  const fbAssetPrefix = "packages/fb_5_embedded/assets";
  bundle ??= rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith(fbAssetPrefix)) {
      // these are not the droids (oops: assets) you are looking for
      continue;
    }
    final targetPath = asset.replaceFirst(fbAssetPrefix, firebirdRoot);
    await _copyFromBundle(bundle, asset, targetPath);
  }
}

/// Sets an environment variable conditionally.
///
/// The variable [name] will be set to [value], unless
/// it already has a value and [forceSet] is `false`.
void _maybeSetVar(String name, String value, bool forceSet) {
  final currVal = osenv.getEnv(name);
  if (forceSet || currVal == null || currVal.trim().isEmpty) {
    osenv.setEnv(name, value);
  }
}

/// Copies a single asset [assetName] from the bundled assets
/// of [bundle] to the location [targetDir] in the file system.
Future<void> _copyFromBundle(
  AssetBundle bundle,
  String assetName,
  String targetPath,
) async {
  final content = await bundle.load(assetName);
  await File(targetPath).writeAsBytes(
    content.buffer.asUint8List(content.offsetInBytes, content.lengthInBytes),
  );
}
