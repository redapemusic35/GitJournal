import 'dart:io';

import 'package:gitjournal/settings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gitjournal/utils/logger.dart';

Future<void> migrateSettings(
  SharedPreferences pref,
  String gitBaseDir,
) async {
  var version = pref.getInt('settingsVersion') ?? -1;

  if (version == 0) {
    Log.i("Migrating settings from v0 -> v1");
    var cache = p.join(gitBaseDir, "cache.json");
    if (File(cache).existsSync()) {
      await File(cache).delete();
    }

    var localGitRepoConfigured =
        pref.getBool("localGitRepoConfigured") ?? false;
    var remoteGitRepoConfigured =
        pref.getBool("remoteGitRepoConfigured") ?? false;

    if (localGitRepoConfigured && !remoteGitRepoConfigured) {
      Log.i("Migrating from local and remote repos to a single one");
      var oldName = p.join(gitBaseDir, "journal_local");
      var newName = p.join(gitBaseDir, "journal");

      await Directory(oldName).rename(newName);
      var folderName = "journal";

      await pref.setString('remoteGitRepoPath', folderName);
    }

    var oldDir = Directory(p.join(gitBaseDir, '../files'));
    if (oldDir.existsSync()) {
      // Move everything from the old dir
      var stream = await (oldDir.list().toList());
      for (var fsEntity in stream) {
        var stat = await fsEntity.stat();
        if (stat.type != FileSystemEntityType.directory) {
          var fileName = p.basename(fsEntity.path);
          if (fileName == 'cache.json') {
            await File(fsEntity.path).delete();
          }
          continue;
        }

        var folderName = p.basename(fsEntity.path);
        if (folderName.startsWith('journal') || folderName.startsWith('ssh')) {
          var newPath = p.join(gitBaseDir, folderName);
          if (!Directory(newPath).existsSync()) {
            await Directory(fsEntity.path).rename(newPath);
          }
        }
      }
    }

    // Save the ssh keys
    var oldSshDir = Directory(p.join(gitBaseDir, '../files/ssh'));
    if (oldSshDir.existsSync()) {
      var sshPublicKeyPath = p.join(oldSshDir.path, "id_rsa.pub");
      var sshPrivateKeyPath = p.join(oldSshDir.path, "id_rsa");

      var publicKeyExists = File(sshPublicKeyPath).existsSync();
      var privateKeyExists = File(sshPrivateKeyPath).existsSync();
      if (publicKeyExists && privateKeyExists) {
        var sshPublicKey = await File(sshPublicKeyPath).readAsString();
        var sshPrivateKey = await File(sshPrivateKeyPath).readAsString();

        await pref.setString("sshPublicKey", sshPublicKey);
        await pref.setString("sshPrivateKey", sshPrivateKey);
        await pref.setString("sshPassword", "");
      }

      await oldSshDir.delete(recursive: true);
    }

    var newSshDir = Directory(p.join(gitBaseDir, 'ssh'));
    if (newSshDir.existsSync()) {
      var sshPublicKeyPath = p.join(newSshDir.path, "id_rsa.pub");
      var sshPrivateKeyPath = p.join(newSshDir.path, "id_rsa");

      var publicKeyExists = File(sshPublicKeyPath).existsSync();
      var privateKeyExists = File(sshPrivateKeyPath).existsSync();
      if (publicKeyExists && privateKeyExists) {
        var sshPublicKey = await File(sshPublicKeyPath).readAsString();
        var sshPrivateKey = await File(sshPrivateKeyPath).readAsString();

        await pref.setString("sshPublicKey", sshPublicKey);
        await pref.setString("sshPrivateKey", sshPrivateKey);
        await pref.setString("sshPassword", "");
      }

      await newSshDir.delete(recursive: true);
    }

    version = 1;
    await pref.setInt("settingsVersion", version);
  }

  if (version == 1) {
    Log.i("Migrating settings from v1 -> v2");
    var prefix = "${DEFAULT_ID}_";

    var stringKeys = [
      'gitAuthor',
      'gitAuthorEmail',
      'noteFileNameFormat',
      'journalNoteFileNameFormat',
      'yamlModifiedKey',
      'yamlCreatedKey',
      'yamlTagsKey',
      'customMetaData',
      'defaultNewNoteFolderSpec',
      'journalEditordefaultNewNoteFolderSpec',
      'remoteSyncFrequency',
      'sortingField',
      'sortingOrder',
      'defaultEditor',
      'defaultView',
      'markdownDefaultView',
      'markdownLastUsedView',
      'folderViewHeaderType',
      'homeScreen',
      'imageLocationSpec',
      'remoteGitRepoPath',
      'sshPublicKey',
      'sshPrivateKey',
      'sshPassword',
      'storageLocation',
    ];
    for (var key in stringKeys) {
      var value = pref.getString(key);
      if (value != null) {
        await pref.remove(key);
        await pref.setString(prefix + key, value);
      }
    }

    var boolKeys = [
      'yamlHeaderEnabled',
      'journalEditorSingleNote',
      'showNoteSummary',
      'emojiParser',
      'zenMode',
      'saveTitleInH1',
      'swipeToDelete',
      'bottomMenuBar',
      'storeInternally',
    ];
    for (var key in boolKeys) {
      var value = pref.getBool(key);
      if (value != null) {
        await pref.remove(key);
        await pref.setBool(prefix + key, value);
      }
    }

    var stringListKeys = [
      'inlineTagPrefixes',
    ];
    for (var key in stringListKeys) {
      var value = pref.getStringList(key);
      if (value != null) {
        await pref.remove(key);
        await pref.setStringList(prefix + key, value);
      }
    }

    version = 2;
    await pref.remove("settingsVersion");
    await pref.setInt(prefix + "settingsVersion", version);
  }
}
