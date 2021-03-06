import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:webfeed/webfeed.dart';

import '../local_storage/sqflite_localpodcast.dart';
import '../type/play_histroy.dart';
import '../type/podcastlocal.dart';
import '../util/custom_widget.dart';
import '../util/duraiton_picker.dart';
import '../util/extension_helper.dart';
import '../util/general_dialog.dart';

enum MarkStatus { start, complete, none }
enum RefreshCoverStatus { start, complete, error, none }

class PodcastSetting extends StatefulWidget {
  const PodcastSetting({this.podcastLocal, Key key}) : super(key: key);
  final PodcastLocal podcastLocal;

  @override
  _PodcastSettingState createState() => _PodcastSettingState();
}

class _PodcastSettingState extends State<PodcastSetting> {
  MarkStatus _markStatus = MarkStatus.none;
  RefreshCoverStatus _coverStatus = RefreshCoverStatus.none;
  int _seconds = 0;

  Future<void> _setAutoDownload(bool boo) async {
    var permission = await _checkPermmison();
    if (permission) {
      var dbHelper = DBHelper();
      await dbHelper.saveAutoDownload(widget.podcastLocal.id, boo: boo);
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveSkipSeconds(int seconds) async {
    var dbHelper = DBHelper();
    await dbHelper.saveSkipSeconds(widget.podcastLocal.id, seconds);
  }

  Future<void> _markListened(String podcastId) async {
    setState(() {
      _markStatus = MarkStatus.start;
    });
    var dbHelper = DBHelper();
    var episodes = await dbHelper.getRssItem(podcastId, -1, reverse: true);
    for (var episode in episodes) {
      var marked = await dbHelper.checkMarked(episode);
      if (!marked) {
        final history = PlayHistory(episode.title, episode.enclosureUrl, 0, 1);
        await dbHelper.saveHistory(history);
        if (mounted) {
          setState(() {
            _markStatus = MarkStatus.complete;
          });
        }
      }
    }
  }

  void _confirmMarkListened(BuildContext context) => generalDialog(
        context,
        title: Text(context.s.markConfirm),
        content: Text(context.s.markConfirmContent),
        actions: <Widget>[
          FlatButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              context.s.cancel,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          FlatButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _markListened(widget.podcastLocal.id);
            },
            child: Text(
              context.s.confirm,
              style: TextStyle(color: context.accentColor),
            ),
          )
        ],
      );

  Future<void> _refreshArtWork() async {
    setState(() => _coverStatus = RefreshCoverStatus.start);
    var options = BaseOptions(
      connectTimeout: 30000,
      receiveTimeout: 90000,
    );

    var dio = Dio(options);
    String imageUrl;

    try {
      var response = await dio.get(widget.podcastLocal.rssUrl);
      try {
        var p = RssFeed.parse(response.data);
        imageUrl = p.itunes.image.href ?? p.image.url;
      } catch (e) {
        developer.log(e.toString());
        if (mounted) setState(() => _coverStatus = RefreshCoverStatus.error);
      }
    } catch (e) {
      developer.log(e.toString());
      if (mounted) setState(() => _coverStatus = RefreshCoverStatus.error);
    }
    if (imageUrl != null &&
        imageUrl.contains('http') &&
        (imageUrl != widget.podcastLocal.imageUrl ||
            !File(widget.podcastLocal.imageUrl).existsSync())) {
      try {
        img.Image thumbnail;
        var imageResponse = await dio.get<List<int>>(imageUrl,
            options: Options(
              responseType: ResponseType.bytes,
            ));
        var image = img.decodeImage(imageResponse.data);
        thumbnail = img.copyResize(image, width: 300);
        if (thumbnail != null) {
          var dir = await getApplicationDocumentsDirectory();
          File("${dir.path}/${widget.podcastLocal.id}.png")
            ..writeAsBytesSync(img.encodePng(thumbnail));
          if (mounted) {
            setState(() => _coverStatus = RefreshCoverStatus.complete);
          }
        }
      } catch (e) {
        developer.log(e.toString());
        if (mounted) setState(() => _coverStatus = RefreshCoverStatus.error);
      }
    } else if (_coverStatus == RefreshCoverStatus.start && mounted) {
      setState(() => _coverStatus = RefreshCoverStatus.complete);
    }
  }

  Future<bool> _checkPermmison() async {
    var permission = await Permission.storage.status;
    if (permission != PermissionStatus.granted) {
      var permissions = await [Permission.storage].request();
      if (permissions[Permission.storage] == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }

  Future<bool> _getAutoDownload(String id) async {
    var dbHelper = DBHelper();
    return await dbHelper.getAutoDownload(id);
  }

  Future<int> _getSkipSecond(String id) async {
    var dbHelper = DBHelper();
    var seconds = await dbHelper.getSkipSeconds(id);
    return seconds;
  }

  Widget _getRefreshStatusIcon(RefreshCoverStatus status) {
    switch (status) {
      case RefreshCoverStatus.none:
        return Center();
        break;
      case RefreshCoverStatus.start:
        return CircularProgressIndicator(strokeWidth: 2);
        break;
      case RefreshCoverStatus.complete:
        return Icon(Icons.done);
        break;
      case RefreshCoverStatus.error:
        return Icon(Icons.refresh, color: Colors.red);
        break;
      default:
        return Center();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FutureBuilder<bool>(
              future: _getAutoDownload(widget.podcastLocal.id),
              initialData: false,
              builder: (context, snapshot) {
                return ListTile(
                  onTap: () => _setAutoDownload(!snapshot.data),
                  leading: SizedBox(
                    height: 18,
                    width: 18,
                    child: CustomPaint(
                      painter: DownloadPainter(
                        color: context.brightness == Brightness.light
                            ? Colors.grey[600]
                            : Colors.white,
                        fraction: 0,
                        progressColor: context.accentColor,
                      ),
                    ),
                  ),
                  title: Text(s.autoDownload),
                  trailing: Transform.scale(
                    scale: 0.9,
                    child: Switch(
                        value: snapshot.data, onChanged: _setAutoDownload),
                  ),
                );
              }),
          Divider(height: 1),
          FutureBuilder<int>(
            future: _getSkipSecond(widget.podcastLocal.id),
            initialData: 0,
            builder: (context, snapshot) => ListTile(
              onTap: () {
                generalDialog(
                  context,
                  title: Text(s.skipSecondsAtStart, maxLines: 2),
                  content: DurationPicker(
                    duration: Duration(seconds: snapshot.data),
                    onChange: (value) => _seconds = value.inSeconds,
                  ),
                  actions: <Widget>[
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _seconds = 0;
                      },
                      child: Text(
                        s.cancel,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _saveSkipSeconds(_seconds);
                      },
                      child: Text(
                        s.confirm,
                        style: TextStyle(color: context.accentColor),
                      ),
                    )
                  ],
                ).then((value) => setState(() {}));
              },
              leading: Icon(Icons.fast_forward),
              title: Text(s.skipSecondsAtStart),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Text(snapshot.data.toTime),
              ),
            ),
          ),
          Divider(height: 1),
          ListTile(
              onTap: () {
                if (_markStatus != MarkStatus.start) {
                  _confirmMarkListened(context);
                }
              },
              title: Text(s.menuMarkAllListened),
              leading: SizedBox(
                height: 20,
                width: 20,
                child: CustomPaint(
                  painter: ListenedAllPainter(
                      context.brightness == Brightness.light
                          ? Colors.grey[600]
                          : Colors.white,
                      stroke: 2),
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: _markStatus == MarkStatus.none
                        ? Center()
                        : _markStatus == MarkStatus.start
                            ? CircularProgressIndicator(strokeWidth: 2)
                            : Icon(Icons.done)),
              )),
          Divider(height: 1),
          ListTile(
              onTap: () {
                if (_coverStatus != RefreshCoverStatus.start) {
                  _refreshArtWork();
                }
              },
              title: Text(s.refreshArtwork),
              leading: Icon(Icons.refresh),
              trailing: Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: _getRefreshStatusIcon(_coverStatus)))),
          Divider(height: 1),
        ]);
  }
}
