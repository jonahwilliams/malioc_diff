// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:colorize/colorize.dart';

final parser = ArgParser()
  ..addOption('input', abbr: 'i', help: 'directory to process shaders in.')
  ..addOption('output',
      abbr: 'o', help: 'compute archive and write to given path.')
  ..addOption('diff',
      abbr: 'd',
      help: 'compute diff of current shaders with archive at provided path.')
  ..addMultiOption('core', abbr: 'c', defaultsTo: kCore, help: 'the GPUs.')
  ..addOption('print',
      help: 'display contents of archive provided to this path.')
  ..addOption('shader', help: 'filter shaders processed by the given string.')
  ..addFlag('help', abbr: 'h', help: 'print usage', negatable: false);

const List<String> kCore = [
  'Mali-T880',
  'Mali-T860',
  'Mali-T830',
  'Mali-T820',
  'Mali-T760',
  'Mali-T720',
  'Mali-G78AE',
  'Mali-G78',
  'Mali-G77',
  'Mali-G76',
  'Mali-G72',
  'Mali-G715',
  'Mali-G710',
  'Mali-G71',
  'Mali-G68',
  'Mali-G615',
  'Mali-G610',
  'Mali-G57',
  'Mali-G52',
  'Mali-G510',
  'Mali-G51',
  'Mali-G310',
  'Mali-G31',
  'Immortalis-G715',
];

const Set<String> kNoise = {
  'Note: This tool shows only the shader-visible property state.',
  'API configuration may also impact the value of some properties.'
};

void main(List<String> args) {
  var argResults = parser.parse(args);

  final bool help = argResults['help'];
  if (help) {
    print('A tool for analyzing the output of malioc.\n');
    print(parser.usage);
    exit(0);
  }
  final String? inputDirectory = argResults['input'];
  final String? output = argResults['output'];
  final String? diffInput = argResults['diff'];
  final String? shader = argResults['shader'];
  final String? printPath = argResults['print'];
  final List<String> cores = argResults['core'] as List<String>;

  if (printPath != null) {
    var bytes = File(printPath).readAsBytesSync();
    var unCompressedBytes = gzip.decode(bytes);
    var stringContents = utf8.decode(unCompressedBytes);
    var jsonContents = json.decode(stringContents) as Map<String, Object?>;
    for (var key in jsonContents.keys) {
      print(key);
      var contents = jsonContents[key] as Map<String, Object?>;
      for (var key2 in contents.keys) {
        print(key2);
        print(contents[key2]);
      }
    }
    exit(0);
  }
  inputDirectory!;

  var results = <String, Map<String, String>>{};
  for (var entity in Directory(inputDirectory).listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.frag.gles') &&
        !entity.path.contains('ssbo')) {
      if (shader != null) {
        if (!entity.path.contains(shader)) {
          continue;
        }
      }
      for (var core in cores) {
        var result = Process.runSync('malioc', <String>[
          entity.path,
          '--fragment',
          '--core',
          core,
        ]);
        if (result.exitCode != 0) {
          color(entity.path, front: Styles.RED);
          print(result.stdout);
          print(result.stderr);
          exit(1);
        }
        (results[entity.path] ??= <String, String>{})[core] = result.stdout;
      }
    }
  }
  if (output != null) {
    var stringContents = json.encode(results);
    var byteContents = utf8.encode(stringContents);
    var compressedContents = gzip.encode(byteContents);
    File(output).writeAsBytesSync(compressedContents);
    exit(0);
  }
  if (diffInput != null) {
    var bytes = File(diffInput).readAsBytesSync();
    var unCompressedBytes = gzip.decode(bytes);
    var stringContents = utf8.decode(unCompressedBytes);
    var jsonContents = json.decode(stringContents) as Map<String, Object?>;

    for (var shaderPath in results.keys) {
      if (!jsonContents.containsKey(shaderPath)) {
        print('New Shader: $shaderPath, Skipping...');
        continue;
      }
      color('**[$shaderPath]**', isBold: true);
      var profiles = jsonContents[shaderPath] as Map<String, Object?>;
      for (var core in cores) {
        if (!profiles.containsKey(core)) {
          print('New Core: $core, Skipping...');
          continue;
        }
        var oldContents = (profiles[core] as String).trim().split('\n');
        var newContents =
            (results[shaderPath]![core] as String).trim().split('\n');
        bool hadDifference = false;
        if (oldContents.length != newContents.length) {
          hadDifference = true;
        } else {
          for (int i = 0; i < oldContents.length; i++) {
            if (oldContents[i].trim() != newContents[i].trim()) {
              hadDifference = true;
            }
          }
        }

        if (!hadDifference) {
          color('  [$core] (IDENTICAL)',
              isUnderline: true, front: Styles.LIGHT_GRAY);
          continue;
        }
        print('');
        color('[$core]', isBold: true, front: Styles.BLACK);
        bool seenHeader = false;
        for (int i = 0; i < oldContents.length; i++) {
          if (oldContents[i].trim() != newContents[i].trim()) {
            color('- ${oldContents[i]}', front: Styles.RED);
            color('+ ${newContents[i]}', front: Styles.GREEN);
          } else {
            if (oldContents[i].contains('Main shader')) {
              seenHeader = true;
            }
            if (seenHeader &&
                !kNoise.any((element) => oldContents[i].contains(element))) {
              print(oldContents[i]);
            }
          }
        }
        print('');
      }
    }
    exit(0);
  }
}
