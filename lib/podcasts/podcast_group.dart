import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../local_storage/sqflite_localpodcast.dart';
import '../state/podcast_group.dart';
import '../type/podcastlocal.dart';
import '../util/duraiton_picker.dart';
import '../util/extension_helper.dart';
import '../util/general_dialog.dart';

class PodcastGroupList extends StatefulWidget {
  final PodcastGroup group;
  PodcastGroupList({this.group, Key key}) : super(key: key);
  @override
  _PodcastGroupListState createState() => _PodcastGroupListState();
}

class _PodcastGroupListState extends State<PodcastGroupList> {
  @override
  Widget build(BuildContext context) {
    var groupList = Provider.of<GroupList>(context, listen: false);
    return widget.group.podcastList.length == 0
        ? Container(
            color: Theme.of(context).primaryColor,
          )
        : Container(
            color: Theme.of(context).primaryColor,
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final podcast = widget.group.podcasts.removeAt(oldIndex);
                  widget.group.podcasts.insert(newIndex, podcast);
                });
                widget.group.orderedPodcasts = widget.group.podcasts;
                groupList.addToOrderChanged(widget.group);
              },
              children: widget.group.podcasts.map<Widget>((podcastLocal) {
                return Container(
                  decoration:
                      BoxDecoration(color: Theme.of(context).primaryColor),
                  key: ObjectKey(podcastLocal.title),
                  child: _PodcastCard(
                    podcastLocal: podcastLocal,
                    group: widget.group,
                  ),
                );
              }).toList(),
            ),
          );
  }
}

class _PodcastCard extends StatefulWidget {
  final PodcastLocal podcastLocal;
  final PodcastGroup group;
  _PodcastCard({this.podcastLocal, this.group, Key key}) : super(key: key);
  @override
  __PodcastCardState createState() => __PodcastCardState();
}

class __PodcastCardState extends State<_PodcastCard>
    with SingleTickerProviderStateMixin {
  bool _loadMenu;
  bool _addGroup;
  List<PodcastGroup> _selectedGroups;
  List<PodcastGroup> _belongGroups;
  AnimationController _controller;
  Animation _animation;
  double _value;
  int _seconds;
  int _skipSeconds;

  Future<int> _getSkipSecond(String id) async {
    var dbHelper = DBHelper();
    var seconds = await dbHelper.getSkipSeconds(id);
    _skipSeconds = seconds;
    return seconds;
  }

  _saveSkipSeconds(String id, int seconds) async {
    var dbHelper = DBHelper();
    await dbHelper.saveSkipSeconds(id, seconds);
  }

  _setAutoDownload(String id, bool boo) async {
    var permission = await _checkPermmison();
    if (permission) {
      var dbHelper = DBHelper();
      await dbHelper.saveAutoDownload(id, boo: boo);
    }
  }

  Future<bool> _getAutoDownload(String id) async {
    var dbHelper = DBHelper();
    return await dbHelper.getAutoDownload(id);
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

  @override
  void initState() {
    super.initState();
    _loadMenu = false;
    _addGroup = false;
    _selectedGroups = [widget.group];
    _value = 0;
    _seconds = 0;
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {
          _value = _animation.value;
        });
      });
  }

  Widget _buttonOnMenu({Widget icon, VoidCallback onTap, String tooltip}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
              height: 50.0,
              padding: EdgeInsets.symmetric(horizontal: 5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: icon,
                  ),
                  Text(tooltip, style: context.textTheme.subtitle2),
                ],
              )),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.podcastLocal.backgroudColor(context);
    final s = context.s;
    var width = context.width;
    var groupList = context.watch<GroupList>();
    _belongGroups = groupList.getPodcastGroup(widget.podcastLocal.id);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: Divider.createBorderSide(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => setState(
              () {
                _loadMenu = !_loadMenu;
                if (_value == 0) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              height: 100,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      child: Icon(
                        Icons.unfold_more,
                        color: c,
                      ),
                    ),
                    Container(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        child: Container(
                          height: 60,
                          width: 60,
                          child: Image.file(
                              File("${widget.podcastLocal.imagePath}")),
                        ),
                      ),
                    ),
                    Container(
                        width: width / 2,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.podcastLocal.title,
                                maxLines: 2,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Row(
                              children: _belongGroups.map((group) {
                                return Container(
                                    padding: EdgeInsets.only(right: 5.0),
                                    child: Text(group.name));
                              }).toList(),
                            ),
                          ],
                        )),
                    Spacer(),
                    Transform.rotate(
                      angle: math.pi * _value,
                      child: Icon(Icons.keyboard_arrow_down),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.0),
                    ),
                  ]),
            ),
          ),
          !_loadMenu
              ? Center()
              : Container(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context).primaryColorDark),
                            top: BorderSide(
                                color: Theme.of(context).primaryColorDark))),
                    height: 50,
                    child: _addGroup
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                      children:
                                          groupList.groups.map<Widget>((group) {
                                    return Container(
                                      padding: EdgeInsets.only(left: 5.0),
                                      child: FilterChip(
                                        key: ValueKey<String>(group.id),
                                        label: Text(group.name),
                                        selected:
                                            _selectedGroups.contains(group),
                                        onSelected: (value) {
                                          setState(() {
                                            if (!value) {
                                              _selectedGroups.remove(group);
                                            } else {
                                              _selectedGroups.add(group);
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  }).toList()),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: () => setState(() {
                                        _addGroup = false;
                                      }),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        if (_selectedGroups.length > 0) {
                                          setState(() {
                                            _addGroup = false;
                                          });
                                          await groupList.changeGroup(
                                            widget.podcastLocal.id,
                                            _selectedGroups,
                                          );
                                          Fluttertoast.showToast(
                                            msg: s.toastSettingSaved,
                                            gravity: ToastGravity.BOTTOM,
                                          );
                                        } else {
                                          Fluttertoast.showToast(
                                            msg: s.toastOneGroup,
                                            gravity: ToastGravity.BOTTOM,
                                          );
                                        }
                                      },
                                      icon: Icon(Icons.done),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              _buttonOnMenu(
                                  icon: Icon(Icons.add,
                                      size: _value == 0 ? 1 : 20 * _value),
                                  onTap: () {
                                    setState(() {
                                      _addGroup = true;
                                    });
                                  },
                                  tooltip: s.groups(0)),
                              FutureBuilder<bool>(
                                future:
                                    _getAutoDownload(widget.podcastLocal.id),
                                initialData: false,
                                builder: (context, snapshot) {
                                  return _buttonOnMenu(
                                    icon: Container(
                                      child: Icon(Icons.file_download,
                                          size: _value * 15,
                                          color: snapshot.data
                                              ? Colors.white
                                              : null),
                                      height: _value == 0 ? 1 : 20 * _value,
                                      width: _value == 0 ? 1 : 20 * _value,
                                      decoration: BoxDecoration(
                                          border: snapshot.data
                                              ? Border.all(
                                                  width: 1,
                                                  color: snapshot.data
                                                      ? context.accentColor
                                                      : context.textTheme
                                                          .subtitle1.color)
                                              : null,
                                          shape: BoxShape.circle,
                                          color: snapshot.data
                                              ? context.accentColor
                                              : null),
                                    ),
                                    tooltip: s.autoDownload,
                                    onTap: () async {
                                      await _setAutoDownload(
                                          widget.podcastLocal.id,
                                          !snapshot.data);
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                              FutureBuilder<int>(
                                  future:
                                      _getSkipSecond(widget.podcastLocal.id),
                                  initialData: 0,
                                  builder: (context, snapshot) {
                                    return _buttonOnMenu(
                                        icon: Icon(
                                          Icons.fast_forward,
                                          size: _value == 0 ? 1 : 20 * (_value),
                                        ),
                                        tooltip:
                                            'Skip${snapshot.data == 0 ? '' : snapshot.data.toTime}',
                                        onTap: () {
                                          generalDialog(
                                            context,
                                            title: Text(s.skipSecondsAtStart,
                                                maxLines: 2),
                                            content: DurationPicker(
                                              duration: Duration(
                                                  seconds: _skipSeconds ?? 0),
                                              onChange: (value) =>
                                                  _seconds = value.inSeconds,
                                            ),
                                            actions: <Widget>[
                                              FlatButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _seconds = 0;
                                                },
                                                child: Text(
                                                  s.cancel,
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                ),
                                              ),
                                              FlatButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _saveSkipSeconds(
                                                      widget.podcastLocal.id,
                                                      _seconds);
                                                },
                                                child: Text(
                                                  s.confirm,
                                                  style: TextStyle(
                                                      color:
                                                          context.accentColor),
                                                ),
                                              )
                                            ],
                                          );
                                        });
                                  }),
                              _buttonOnMenu(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: _value == 0 ? 1 : 20 * _value,
                                  ),
                                  tooltip: s.remove,
                                  onTap: () {
                                    generalDialog(
                                      context,
                                      title: Text(s.removeConfirm),
                                      content: Text(s.removePodcastDes),
                                      actions: <Widget>[
                                        FlatButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text(
                                            s.cancel,
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                        ),
                                        FlatButton(
                                          onPressed: () {
                                            groupList.removePodcast(
                                                widget.podcastLocal.id);
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            s.confirm,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        )
                                      ],
                                    );
                                  }),
                            ],
                          ),
                  ),
                ),
        ],
      ),
    );
  }
}

class RenameGroup extends StatefulWidget {
  final PodcastGroup group;
  RenameGroup({this.group, Key key}) : super(key: key);
  @override
  _RenameGroupState createState() => _RenameGroupState();
}

class _RenameGroupState extends State<RenameGroup> {
  TextEditingController _controller;
  String _newName;
  int _error;

  @override
  void initState() {
    super.initState();
    _error = 0;
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var groupList = Provider.of<GroupList>(context, listen: false);
    List list = groupList.groups.map((e) => e.name).toList();
    final s = context.s;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor:
            Theme.of(context).brightness == Brightness.light
                ? Color.fromRGBO(113, 113, 113, 1)
                : Color.fromRGBO(5, 5, 5, 1),
      ),
      child: AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        elevation: 1,
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        titlePadding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
        actionsPadding: EdgeInsets.all(0),
        actions: <Widget>[
          FlatButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              s.cancel,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          FlatButton(
            onPressed: () async {
              if (list.contains(_newName)) {
                setState(() => _error = 1);
              } else {
                var newGroup = PodcastGroup(_newName,
                    color: widget.group.color,
                    id: widget.group.id,
                    podcastList: widget.group.podcastList);
                groupList.updateGroup(newGroup);
                Navigator.of(context).pop();
              }
            },
            child: Text(s.confirm,
                style: TextStyle(color: Theme.of(context).accentColor)),
          )
        ],
        title:
            SizedBox(width: context.width - 160, child: Text(s.editGroupName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                hintText: widget.group.name,
                hintStyle: TextStyle(fontSize: 18),
                filled: true,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).accentColor, width: 2.0),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).accentColor, width: 2.0),
                ),
              ),
              cursorRadius: Radius.circular(2),
              autofocus: true,
              maxLines: 1,
              controller: _controller,
              onChanged: (value) {
                _newName = value;
              },
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: (_error == 1)
                  ? Text(
                      s.groupExisted,
                      style: TextStyle(color: Colors.red[400]),
                    )
                  : Center(),
            ),
          ],
        ),
      ),
    );
  }
}
