import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../local_storage/key_value_storage.dart';
import '../state/audio_state.dart';
import '../util/custom_dropdown.dart';
import '../util/custom_widget.dart';
import '../util/episodegrid.dart';
import '../util/extension_helper.dart';
import 'popup_menu.dart';

class LayoutSetting extends StatefulWidget {
  const LayoutSetting({Key key}) : super(key: key);

  @override
  _LayoutSettingState createState() => _LayoutSettingState();
}

class _LayoutSettingState extends State<LayoutSetting> {
  Future<Layout> _getLayout(String key) async {
    var keyValueStorage = KeyValueStorage(key);
    var layout = await keyValueStorage.getInt();
    return Layout.values[layout];
  }

  String _getHeightString(PlayerHeight mode) {
    final s = context.s;
    switch (mode) {
      case PlayerHeight.short:
        return s.playerHeightShort;
        break;
      case PlayerHeight.mid:
        return s.playerHeightMed;
        break;
      case PlayerHeight.tall:
        return s.playerHeightTall;
        break;
      default:
        return '';
    }
  }

  Widget _gridOptions(BuildContext context,
          {String key,
          Layout layout,
          Layout option,
          double scale,
          BorderRadiusGeometry borderRadius}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
        child: InkWell(
          onTap: () async {
            var storage = KeyValueStorage(key);
            await storage.saveInt(option.index);
            setState(() {});
          },
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 400),
            height: 30,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: layout == option
                  ? context.accentColor
                  : context.primaryColorDark,
            ),
            alignment: Alignment.center,
            child: SizedBox(
              height: 10,
              width: 30,
              child: CustomPaint(
                painter: LayoutPainter(
                    scale,
                    layout == option
                        ? Colors.white
                        : context.textTheme.bodyText1.color),
              ),
            ),
          ),
        ),
      );

  Widget _setDefaultGrid(BuildContext context, {String key}) {
    return FutureBuilder<Layout>(
        future: _getLayout(key),
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _gridOptions(
                      context,
                      key: key,
                      layout: snapshot.data,
                      option: Layout.one,
                      scale: 4,
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          topLeft: Radius.circular(5)),
                    ),
                    _gridOptions(
                      context,
                      key: key,
                      layout: snapshot.data,
                      option: Layout.two,
                      scale: 1,
                    ),
                    _gridOptions(context,
                        key: key,
                        layout: snapshot.data,
                        option: Layout.three,
                        scale: 0,
                        borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(5),
                            topRight: Radius.circular(5))),
                  ],
                )
              : Center();
        });
  }

  Widget _setDefaultGridView(BuildContext context, {String text, String key}) {
    return Padding(
      padding: EdgeInsets.only(left: 70.0, right: 20, bottom: 10),
      child: context.width > 360
          ? Row(
              children: [
                Text(
                  text,
                ),
                Spacer(),
                _setDefaultGrid(context, key: key),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                ),
                _setDefaultGrid(context, key: key),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    var audio = Provider.of<AudioPlayerNotifier>(context, listen: false);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: Theme.of(context).accentColorBrightness,
        systemNavigationBarColor: context.primaryColor,
        systemNavigationBarIconBrightness:
            Theme.of(context).accentColorBrightness,
      ),
      child: Scaffold(
          appBar: AppBar(
            title: Text(s.settingsLayout),
            elevation: 0,
            backgroundColor: context.primaryColor,
          ),
          body: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(10.0),
                ),
                Container(
                  height: 30.0,
                  padding: EdgeInsets.symmetric(horizontal: 70),
                  alignment: Alignment.centerLeft,
                  child: Text(s.settingsPopupMenu,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(color: Theme.of(context).accentColor)),
                ),
                ListTile(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PopupMenuSetting())),
                  contentPadding: EdgeInsets.only(left: 70.0, right: 20),
                  title: Text(s.settingsPopupMenu),
                  subtitle: Text(s.settingsPopupMenuDes),
                ),
                Divider(height: 2),
                Padding(
                  padding: EdgeInsets.all(10.0),
                ),
                Container(
                  height: 30.0,
                  padding: EdgeInsets.symmetric(horizontal: 70),
                  alignment: Alignment.centerLeft,
                  child: Text(s.player,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(color: Theme.of(context).accentColor)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.only(
                      left: 70.0, right: 20, bottom: 10, top: 10),
                  title: Text(s.settingsPlayerHeight),
                  subtitle: Text(s.settingsPlayerHeightDes),
                  trailing: Selector<AudioPlayerNotifier, PlayerHeight>(
                    selector: (_, audio) => audio.playerHeight,
                    builder: (_, data, __) => MyDropdownButton(
                        hint: Text(_getHeightString(data)),
                        underline: Center(),
                        elevation: 1,
                        value: data.index,
                        items: <int>[0, 1, 2].map<DropdownMenuItem<int>>((e) {
                          return DropdownMenuItem<int>(
                              value: e,
                              child: Text(
                                  _getHeightString(PlayerHeight.values[e])));
                        }).toList(),
                        onChanged: (index) =>
                            audio.setPlayerHeight = PlayerHeight.values[index]),
                  ),
                ),
                Divider(height: 2),
                Padding(
                  padding: EdgeInsets.all(10.0),
                ),
                Container(
                  height: 30.0,
                  padding: EdgeInsets.symmetric(horizontal: 70),
                  alignment: Alignment.centerLeft,
                  child: Text(s.settingsDefaultGrid,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(color: Theme.of(context).accentColor)),
                ),
                ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    children: <Widget>[
                      _setDefaultGridView(context,
                          text: s.settingsDefaultGridPodcast,
                          key: podcastLayoutKey),
                      _setDefaultGridView(context,
                          text: s.settingsDefaultGridRecent,
                          key: recentLayoutKey),
                      _setDefaultGridView(context,
                          text: s.settingsDefaultGridFavorite,
                          key: favLayoutKey),
                      _setDefaultGridView(context,
                          text: s.settingsDefaultGridDownload,
                          key: downloadLayoutKey),
                    ]),
                Divider(height: 2),
              ],
            ),
          )),
    );
  }
}
