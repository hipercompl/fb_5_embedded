import 'dart:io';
import 'package:flutter/material.dart';

import 'package:fb_5_embedded/fb_5_embedded.dart' as fb_embedded;
import 'package:fbdb/fbdb.dart';
import 'package:path_provider/path_provider.dart' as paths;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _dbData = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const vgap = SizedBox(height: 30);
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('fb_embedded example')),
          body: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const .all(10),
              child: Column(
                mainAxisAlignment: .center,
                crossAxisAlignment: .center,
                mainAxisSize: .max,
                children: [
                  FilledButton(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const CircularProgressIndicator(value: null),
                              const SizedBox(width: 20),
                              const Text("Deploying Firebird..."),
                            ],
                          ),
                        ),
                      );
                      try {
                        // deploy (or re-deploy) the embedded engine assets
                        await fb_embedded.setUpEmbedded(forceRedeploy: true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Error"),
                              content: Text(e.toString()),
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                        }
                      }
                    },
                    child: Text("1. Deploy embedded Firebird"),
                  ),
                  vgap,
                  FilledButton(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const CircularProgressIndicator(value: null),
                              const SizedBox(width: 20),
                              const Text("Talking to database..."),
                            ],
                          ),
                        ),
                      );
                      try {
                        final dbDir = await paths
                            .getApplicationDocumentsDirectory();
                        final dbPath =
                            "${dbDir.absolute.path}${Platform.pathSeparator}fbe_test.fdb";
                        if (await File(dbPath).exists()) {
                          await File(dbPath).delete();
                        }
                        // call setup, but without forcing redeployment
                        await fb_embedded.setUpEmbedded();
                        final db = await FbDb.createDatabase(
                          database: dbPath,
                          options: FbOptions(dbCharset: "UTF8"),
                        );
                        try {
                          await db.execute(
                            sql:
                                "create table TEST_TABLE ( "
                                "   ID integer not null, "
                                "   MSG varchar(50), "
                                "   constraint PK_TEST_TABLE primary key (ID) "
                                ") ",
                          );
                          await db.execute(
                            sql:
                                "insert into TEST_TABLE (ID, MSG) "
                                "values (?, ?) ",
                            parameters: [1, "Succes! ☺"],
                          );
                          final row = await db.selectOne(
                            sql:
                                "select MSG from TEST_TABLE "
                                "where ID=? ",
                            parameters: [1],
                          );
                          setState(() {
                            if (row != null && row.isNotEmpty) {
                              _dbData = row["MSG"];
                            }
                          });
                        } finally {
                          await db.detach();
                          await File(dbPath).delete();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Error"),
                              content: Text(e.toString()),
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                        }
                      }
                    },
                    child: Text("2. Test embedded Firebird"),
                  ),
                  vgap,
                  Text(_dbData, style: textStyle, textAlign: .center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
