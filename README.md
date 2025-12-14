# `fb_5_embedded`

[Firebird](https://firebirdsql.org) **embedded** database engine version 5 packaged for Android.

## Getting Started
While the Firebird embedded engine for Android is freely available for downlod at [the Firebird official site](https://firebirdsql.org/en/firebird-5-0#android-embed), it is packaged as an `.aar` archive and requires some extra steps on the target Android system before it can be used (see [this Kotlin file](https://github.com/FirebirdSQL/firebird/blob/master/android/embedded/src/main/java/org/firebirdsql/android/embedded/FirebirdConf.kt) from the official Firebird sources). This includes copying internal Firebird engine files (configuration files, ICU data files, etc.) out of the application bundle (Firebird is not able to read them directly from the bundled assets), into a standard directory in the Android file system, accessible to the process (application), in which the embedded engine is used. Furthermore, before loading and using the embedded engine's dynamic libraries, the application needs to set some environment variables (`FIREBIRD`, `FIREBIRD_TMP` and `FIREBIRD_LOCK`) to tell the engine where the assest are located and where the engine can create its temporary and lock files.

Both the `.aar` format and the extra work with deployment pose some inconvenience for casual Flutter developers.

The *fb_5_embedded* plugin does all this work for you. It contains the current Firebird embedded shared libraries from the version 5 series, packaged as native Android dependencies of the Flutter plugin (they will be added automatically to your application when you use the plugin), and all the required setup and deployment comes down to calling a **single function** from the plugin: `setUpEmbedded`.

## Quick start
Suppose you're developing a Flutter Android application and want to use the Firebird embedded database engine.

Those are the required steps:

1. Add the *fb_5_embedded* plugin as a dependency of your project:

    ```bash
    flutter pub add fb_5_embedded
    flutter pub get
    ```

2. Import the package in your application code:

    ```dart
    import 'package:fb_5_embedded/fb_5_embedded.dart' as fb_embedded;
    ```

3. Before using the engine (i.e. before you attach to or create any databases, even before you load the *libfbclient.so* client library), call the setup function from the imported package:

    ```dart
    await fb_embedded.setUpEmbedded();
    ```

Now you're all set up and good to go! If you use the [*fbdb*](https://pub.dev/packages/fbdb) package to access the database, you can call `FbDb.attach` or `FbDb.createDatabase`, providing just the path to the database file, and omitting the host name, port number, user name and password.

You may also want to look at the [included example](https://github.com/hipercompl/fb_5_embedded/tree/main/example) or the [embedded branch of the *fbdb* demo application](https://github.com/hipercompl/fbdbmobdemo/tree/embedded).

## Firebird versions vs plugin versions

The *fb_5_embedded* plugin bundles the current stable Firebird embedded engine from the 5.x version lineup (as available on [Firebird web site](https://firebirdsql.org)).

In other words, when Firebird development team publishes a new version of Firebird (e.g. Firebird 6.0.0), the *fb_5_embedded* plugin will stick to the 5.x version of Firebird engine. In general, major versions of Firebird engine are mutually incompatible. They require additional steps to migrate a database from one version to the other. On the other hand, if the Firebird team publishes a new 5.x bugfix revision, the *fb_5_embedded* will start shipping the new version (it should be compatible with all previous 5.x versions).

However, when the Firebird team publishes version 6 of the Firebird server, its embedded engine will be packaged as a new plugin: *fb_6_embedded* (which will in turn stick to the 6.x. version of Firebird), and so on.

This way, the dependencies of your application should remain stable (migration to a new major Firebird version has to be performed as a conscious step, the plugin will not migrate you by accident), and, at the same time, you should be able to take advantage of all bugfixes released by the Firebird team to the version you're currently using.

## Usage

The plugin bundles both the Firebird embedded Android shared libraries (for different architectures), and additional files (configs, ICU data, error messages) required by the embedded engine for normal operation.

While the shared libraries from the plugin, bundled with your application (the bundling is done automatically by Flutter CLI during compilation), work just fine on the target Android device, there is a problem with the additional Firebird files. The embedded engine is implemented in such way that it **cannot** read those files directly from the assets of your Android application bundle. They need to be copied before use to a different location, the location being a standard file system directory in the target system (the files will take about 25 MB of additional space on the device). The location of this directory (it is called the **Firebird root** directory), as an absolute path, has to be provided to the Firebird engine's shared libraries via the `FIREBIRD` environment variable.

Additionally, the Firebird engine needs to access two additional locations in the file system:

* a directory to store temporary files (created when handling some queries, rebuilding indices, etc.),

* a directory to store lock files (internal Firebird files guarding the database from getting corrupted due to unsynchronized access).

Both those directories also need to be passed down to the embedded engine via environment variables (`FIREBIRD_TMP` and `FIREBIRD_LOCK`, respectively) and need to be created beforehand.

All the work described above is fully automated by the plugin's published `setUpEmbedded` function. In a typical scenario, you - an application developer - don't need to care about any of this stuff, you just call `setUpEmbedded`, `await` its completion and you're all set.

The function is smart enough to detect the presence of the Firebird root directory and doesn't copy the assets every time it is called (unless you demand the redeployment), so the first call may take a while (time required to copy the assets from the app bundle to the target directory), and all subsequent calls will take hardly any time at all.

### The `setUpEmbedded` function.
The `setUpEmbedded` is the only function you need to call in your code in order to prepare the bundled Firebird engine to work.

The prototype of `setUpEmbedded` is as follows:

```dart
Future<void> setUpEmbedded({
  String? firebirdRoot,
  String? firebirdTmp,
  String? firebirdLock,
  AssetBundle? bundle,
  bool forceRedeploy = false,
})
```

All the parameters are optional.

* `firebirdRoot` - the location of the root Firebird directory (see the previous section), in which all internal config and data files reside. The default is the `firebird` subdirectory of the private application data directory (as returned by `getApplicationDocumentsDirectory` of the [path_provider](https://pub.dev/packages/path_provider) plugin).

* `firebirdTmp` - the location to store temporary files. Defaults to the `tmp` subdirectory of `firebirdRoot`.

* `firebirdLock` - the location to manage lock files. Defaults to the `lock` subdirectory of `firebirdRoot`.

* `bundle` - the asset bundle to copy the Firebird files from. Defaults to [`rootBundle`](https://api.flutter.dev/flutter/services/rootBundle.html), consider using [`DefaultAssetBundle.of(context)`](https://api.flutter.dev/flutter/widgets/DefaultAssetBundle/of.html).

* `forceRedeploy` - if `true`, the Firebird assets will be copied to `firebirdRoot` even if `firebirdRoot` already exists. By default, if `firebirdRoot` exists, it is assumed the setup has already been done before and there's no need to copy the files again.

So, when you call

```dart
await setUpEmbedded();
```

for the very first time, the following will happen:

* a new directory `firebird` will be created inside the private data directory of your application,

* inside the created `firebird` directory, two additional subdirectories will be created: `tmp` and `lock`,

* all internal Firebird files included in the bundled assets (`fbintl.conf`, `firebird.conf`, `icudt63l.dat`, `firebird.msg`, etc.) will be copied to the `firebird` directory,

* the environment variables: `FIREBIRD`, `FIREBIRD_TMP` and `FIREBIRD_LOCK` will be set automatically to point to the new directories.

At this point you can load the shared libraries of the Firebird embedded engine and start using it. If you use the [*fbdb*](https://pub.dev/packages/fbdb) Firebird access library, it is safe at this point to call `FbDb.attach` or `FbDb.createDatabase`. To use the embedded engine, provide just the database file path in the `database` parameter, and omit `host`, `port`, `user` and `password`.

All the subsequent calls of `setUpEmbedded` in the same application (even after application restarts) will be much faster. They will detect the presence of the Firebird root directory and no file copying will take place. The function will just set the environment variables.

### Other functions of the plugin
All other functions published by the plugin perform parts of the work `setUpEmbeedded` does:

* `getDefaultFBRoot` - returns the default location of the Firebird root directory (`firebird` subdirectory of the private data directory of the application),

* `setFBEnvVars` - sets the relevant Firebird environment variables,

* `createFBDirs` - creates the Firebird root, tmp and lock directories,

* `deployFBAssets` - copies the Firebird internal files from the asset bundle to the Firebird root directory.

Under normal circumstances, there's no need to call these functions directly. They are publicly available to provide help in customized deployments.

For more details please refer to the API documentation of the plugin.

### Customized config
Should you need to change any of the provided Firebird files (for example to use a custom `firebird.conf`), **first** call `setUpEmbedded`, and later **overwrite** the relevant files in the directory reported by `getDefaultFBRoot` with your own versions.

The plugin bundles stock config and data files, exactly as included in the official Firebird embedded for Android `.aar` package.

### Final application bundle size
Please keep in mind, that the plugin bundles the Firebird embedded engine for three different CPU architectures (Arm 32-bit, Arm 64-bit and Intel 64-bit), so the size of the final `.apk` or `.aab` may be significant (expect 130MB or more). However, if you leverage the modern `.aab` (application bundle) format, your end users will need to download only part of the bundle, matching their device's architecture.

### Shared databases
You have to keep in mind, that the engine provided by this plugin will be **private** to your application. By "private" we mean it will not be accessible to other applications on the device (even by other applications you yourself developed).

If you install two different applications on the same target device, both of which bundle and use the Firebird embedded engine, each of the applications will use **its own** instance of the engine. They can even differ in versions, depending on the version of the plugin each of the application was compiled with.

Therefore, as a general advice, you **should not share** databases between applications in embedded mode. If you do, then unless you're really careful and know exactly what you're doing, you will probably end up with a **corrupted database**. That's because every engine will try to access and modify the database file, not knowing about the other engine trying to do the same in parallel. So, if you *really* need to share a single database between different applications, consider these options:

1. Use the full-scaled Android server, not the embedded one, and connect via TCP/IP (localhost) from all applications. The applications do not use the embedded engine, there is one system-wide Firebird on the device (deployment in this way may not be easy).

2. Make sure all applications accessing the shared database use **exactly** the same version of the embedded engine and **set up a global lock directory**, passing its location via the `firebirdLock` parameter (identical in all applications) when calling `setUpEmbedded`. The global lock directory has to be created in such way that all applications have permission to write to it (that's outside of the scope of this plugin, you'll need to cope with this issue on your own).

3. Have each application use its own private database and private engine, and think about sharing relevant data between applications in a way that would not require sharing the internal database files.

It's just best to avoid shared databases when using embedded engine.

## Footnotes

* *Firebird is a registered trademark of the [Firebird Foundation](https://firebirdsql.org/en/firebird-foundation/).*
