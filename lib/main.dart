import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toml/toml.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Frame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'My Photo Frame'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<String> seen = [];
  File? imageFile;
  Color backgroundColor = Colors.white;
  Timer? timerAutoPlay;
  Timer? timerNav;
  bool loading = false;
  bool imageLocked = false;
  bool autoPlay = false;
  bool showNav = false;
  Config conf = Config();
  String errorMessage = "";

  late Animation a;
  late AnimationController ac;

  @override
  void initState() {
    ac = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000)
    );
    a = CurvedAnimation(parent: ac, curve: Curves.easeIn);
    loading = true;
    super.initState();

    // TODO show loading state, if error occurs display it nicely.
    loadConfig(path.join(getUserDirectory(), '.photo_frame')).then((value) {
      print("let's go?");
      conf = value;
      loading = false;
      autoPlay = conf.autoPlay;
      _displayNextImage();
      return null;
    }).catchError((e) {
      print(e);
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    });
  }

  void _displayNextImage() async {
    if (imageLocked == true) {
      print('animation is transitioning! $imageLocked');
      return;
    }
    imageLocked = true;
    if (timerAutoPlay != null) {
      timerAutoPlay!.cancel();
      timerAutoPlay = null;
    }
    String filepath = getNextImage(conf.directory, seen);
    if (seen.length > 0 && filepath == '') {
      seen.length = 0;
      filepath = getNextImage(conf.directory, seen);
    }
    if (filepath == '') {
      print("Hey we can't find a file :/");
      imageLocked = false;
      return;
    }
    seen.add(filepath);
    File f = File(filepath);
    FileImage i = FileImage(f);
    PaletteGenerator palette = await PaletteGenerator.fromImageProvider(i);

    ac..reverse();
    await Future.delayed(Duration(milliseconds: 1000));

    setState(() {
      imageFile = File(filepath);
      if (palette.mutedColor != null) {
        backgroundColor = palette.mutedColor!.color;
      } else if (palette.dominantColor != null ) {
        backgroundColor = palette.dominantColor!.color;
      } else {
        backgroundColor = Colors.black;
      }
      ac..forward();
    });
    await Future.delayed(Duration(milliseconds: 1000));
    imageLocked = false;
    if (autoPlay == true) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    timerAutoPlay = Timer(conf.autoPlayDuration, () => {_displayNextImage()});
  }

  void _showNav() async {
    if (timerNav != null) {
      timerNav!.cancel();
    }
    setState(() {
      showNav = true;
    });
    timerNav = Timer(Duration(milliseconds: 10000), () => {
      setState(() {
        showNav = false;
      })
    });
  }

  void _onTap() {
    print('onTap!');
    _displayNextImage();
  }

  void _onTapNav() {
    print('onTapNav!');
    _showNav();
  }

  void _onTapToggleAutoPlay() {
    print('onTapToggleAutoPlay!');
    if (autoPlay == true && timerAutoPlay != null) {
      timerAutoPlay!.cancel();
      timerAutoPlay = null;
    } else if (autoPlay != true) {
      _startAutoPlay();
    }
    setState(() {
      autoPlay = !autoPlay;
    });
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading == true) {
      return Scaffold(body: Center(
        child: Text("✌", style: TextStyle(fontSize: 48),)
      ));
    } else if (errorMessage != "") {
      return Scaffold(body: Center(
        child: Text(errorMessage, style: GoogleFonts.poppins(
          fontSize: 24,
        ))
      ));
    }

    List<Shadow> shadows = [];// [Shadow(color: Colors.black, offset: Offset.fromDirection(0, 0.0), blurRadius: 3)];
    var font = GoogleFonts.poppins(
      fontWeight: FontWeight.normal,
      fontSize: 16,
      color: Colors.white,
      shadows: shadows,
    );

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            color: backgroundColor,
            duration: Duration(milliseconds: 1000),
          ),
          imageFile == null ? Container() : Center(child: FadeTransition(
              opacity: a as Animation<double>,
              child: Image.file(imageFile!),
            ),
          ),
          Column(
            children: [
              AnimatedOpacity(
                opacity: showNav == true ? 1.0 : 0.0,
                duration: Duration(milliseconds: 0),
                child: Container(
                  color: backgroundColor.withOpacity(0.3), //Colors.black38,
                  child: Column(
                    children: [
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaY: 10, sigmaX: 10),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _onTapNav,
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                                      child: DecoratedIcon(CupertinoIcons.clock_solid,
                                        size: 16.0,
                                        shadows: shadows,
                                      ),
                                    ),
                                    Text(
                                      getDateStr(),
                                      style: font,
                                    ),
                                    Spacer(),
                                    Text('Auto Play',
                                      style: font,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                                      child: GestureDetector(
                                          onTap: _onTapToggleAutoPlay,
                                          child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: DecoratedIcon(
                                                autoPlay == false ? CupertinoIcons.play_circle : CupertinoIcons.pause_circle,
                                                size: 16.0,
                                                shadows: shadows,
                                              )
                                          )
                                      ),
                                    ),
                                  ],
                                )
                            ),
                          ),
                        ),
                      ),
                      Container(height: 1, color: Colors.white.withOpacity(0.1)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _onTap,
                  child: Container(color: Colors.black.withOpacity(0.0))
                )
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String getDateStr() {
  return DateFormat.yMMMMd().add_jm().format(DateTime.now());
}

bool isSupportedFile(String filepath) {
  return ['.jpeg', '.jfif', '.jpg', '.gif', '.png', '.webp', '.bmp', '.wbmp'].contains(path.extension(filepath.toLowerCase()));
}

String getNextImage(Directory dir, List<String> omit) {
  List<FileSystemEntity> fs = dir.listSync();
  List<String> possiblePaths = [];
  for (var i = 0; i < fs.length; i++) {
    var x = fs[i].absolute.path;
    if (!isSupportedFile(x)) {
      continue;
    }
    if (!omit.contains(x)) {
      possiblePaths.add(x);
    }
  }
  if (possiblePaths.length <= 0) {
    return "";
  }
  return possiblePaths[Random().nextInt(possiblePaths.length)];
}

class Config {
  Directory directory = Directory('.');
  Duration autoPlayDuration = Duration(seconds: 10);
  bool autoPlay = false;
}

Future<Config> loadConfig(String filename) async {
  var c = Config();
  TomlDocument doc;
  doc = await TomlDocument.load(filename);
  var m = doc.toMap();
  if (m['autoplay_duration'] is int) {
    c.autoPlayDuration = Duration(seconds: m['autoplay_duration']);
  }
  if (m['directory'] is String) {
    c.directory = Directory(m['directory']);
  }
  if (m['autoplay'] is bool) {
    c.autoPlay = m['autoplay'] ?? false;
  }
  await Future.delayed(Duration(milliseconds: 1000));
  return c;
}

String getUserDirectory() {
  String str = '';
  Map<String, String> env = Platform.environment;
  switch (Platform.operatingSystem) {
    case "linux":
    case "macos":
      str = env['HOME'] ?? '';
      break;
    case "windows":
      str = env['UserProfile'] ?? '';
      break;
  }
  return str;
}