import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:virtual_try_on/preview_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key, required this.cameras}) : super(key: key);

  final List<CameraDescription>? cameras;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;
  bool _isCameraInitialized = false;

  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;

  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;

  FlashMode? _currentFlashMode;

  // To store the retrieved files
  List<File> allFileList = [];

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    initCamera(widget.cameras![0]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    onNewCameraSelected(widget.cameras![0]);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<XFile?> takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return null;
    }
    if (_cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      XFile picture = await _cameraController.takePicture();
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PreviewPage(
                    picture: picture,
                  )));
      return picture;
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  Future initCamera(CameraDescription cameraDescription) async {
    _cameraController =
        CameraController(cameraDescription, ResolutionPreset.high);
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = _cameraController;

    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Initialize controller
    try {
      await cameraController.initialize();
      cameraController
          .getMaxZoomLevel()
          .then((value) => _maxAvailableZoom = value);

      cameraController
          .getMinZoomLevel()
          .then((value) => _minAvailableZoom = value);

      cameraController
          .getMinExposureOffset()
          .then((value) => _minAvailableExposureOffset = value);

      cameraController
          .getMaxExposureOffset()
          .then((value) => _maxAvailableExposureOffset = value);

      _currentFlashMode = _cameraController.value.flashMode;
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }
    // Dispose the previous controller
    await previousCameraController.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        _cameraController = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });
    // Initialize controller
    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }
    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = _cameraController.value.isInitialized;
      });
    }
  }

  refreshAlreadyCapturedImages() async {
    // Get the directory
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();

    List<Map<int, dynamic>> fileNames = [];

    // Searching for all the image and video files using
    // their default format, and storing them
    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    // Retrieving the recent file
    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _imageFile = File('${directory.path}/$recentFileName');
      // Checking whether it is an image or a video file
      // if (recentFileName.contains('.mp4')) {
      //   _videoFile = File('${directory.path}/$recentFileName');
      //   _startVideoPlayer();
      // } else {
      //   _imageFile = File('${directory.path}/$recentFileName');
      // }

      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (!cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         body: SafeArea(
//       child: Stack(children: [
//         (_cameraController.value.isInitialized)
//             ? CameraPreview(_cameraController)
//             : Container(
//                 color: Colors.black,
//                 child: const Center(child: CircularProgressIndicator())),
//         Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               height: MediaQuery.of(context).size.height * 0.20,
//               decoration: const BoxDecoration(
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//                   color: Colors.black),
//               child:
//                   Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
//                 Expanded(
//                     child: IconButton(
//                   padding: EdgeInsets.zero,
//                   iconSize: 30,
//                   icon: Icon(
//                       _isRearCameraSelected
//                           ? CupertinoIcons.switch_camera
//                           : CupertinoIcons.switch_camera_solid,
//                       color: Colors.white),
//                   onPressed: () {
//                     setState(
//                         () => _isRearCameraSelected = !_isRearCameraSelected);
//                     initCamera(widget.cameras![_isRearCameraSelected ? 0 : 1]);
//                   },
//                 )),
//                 Expanded(
//                     child: IconButton(
//                   onPressed: takePicture,
//                   iconSize: 50,
//                   padding: EdgeInsets.zero,
//                   constraints: const BoxConstraints(),
//                   icon: const Icon(Icons.circle, color: Colors.white),
//                 )),
//                 const Spacer(),
//               ]),
//             )),
//       ]),
//     ));
//   }
// }

  @override
  Widget build(BuildContext context) {
    double screenwidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(children: [
            cameraPreview(screenwidth),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      imageQualityDropdown(),
                      flashModes(screenwidth),
                    ],
                  ),
                ),
                SizedBox(
                  height: 170,
                ),
                exposureLevelBar(screenwidth),
                SizedBox(
                  height: 170,
                ),
                zoomLevelBar(screenwidth),
              ],
            )
          ]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              cameraToggle(),
              cameraShutter(),
              capturedImagePreview(),
            ],
          ),
        ],
      ),
    );
  }

  Padding exposureLevelBar(double screenwidth) {
    return Padding(
        padding: EdgeInsets.only(right: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _currentExposureOffset.toStringAsFixed(1) + 'x',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                height: 20,
                child: Slider(
                  value: _currentExposureOffset,
                  min: _minAvailableExposureOffset,
                  max: _maxAvailableExposureOffset,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: (value) async {
                    setState(() {
                      _currentExposureOffset = value;
                    });
                    await _cameraController.setExposureOffset(value);
                  },
                ),
              ),
            ),
          ],
        ));
  }

  Container capturedImagePreview() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white, width: 2),
        image: _imageFile != null
            ? DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

  InkWell cameraShutter() {
    return InkWell(
      onTap: () async {
        XFile? rawImage = await takePicture();
        File imageFile = File(rawImage!.path);

        int currentUnix = DateTime.now().millisecondsSinceEpoch;
        final directory = await getApplicationDocumentsDirectory();
        String fileFormat = imageFile.path.split('.').last;

        await imageFile.copy(
          '${directory.path}/$currentUnix.$fileFormat',
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.circle, color: Colors.white38, size: 80),
          Icon(Icons.circle, color: Colors.white, size: 65),
        ],
      ),
    );
  }

  InkWell cameraToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _isCameraInitialized = false;
        });
        onNewCameraSelected(
          widget.cameras![_isRearCameraSelected ? 0 : 1],
        );
        setState(() {
          _isRearCameraSelected = !_isRearCameraSelected;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.circle,
            color: Colors.black38,
            size: 60,
          ),
          Icon(
            _isRearCameraSelected ? Icons.camera_front : Icons.camera_rear,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }

  DropdownButton<ResolutionPreset> imageQualityDropdown() {
    return DropdownButton<ResolutionPreset>(
      dropdownColor: Colors.black87,
      underline: Container(),
      value: currentResolutionPreset,
      items: [
        for (ResolutionPreset preset in resolutionPresets)
          DropdownMenuItem(
            child: Text(
              preset.toString().split('.')[1].toUpperCase(),
              style: TextStyle(color: Colors.white),
            ),
            value: preset,
          )
      ],
      onChanged: (value) {
        setState(() {
          currentResolutionPreset = value!;
          _isCameraInitialized = false;
        });
        onNewCameraSelected(_cameraController.description);
      },
      hint: Text("Select item"),
    );
  }

  SizedBox cameraPreview(double screenwidth) {
    return SizedBox(
      width: screenwidth,
      height: screenwidth * (16 / 9),
      child: _isCameraInitialized
          ? AspectRatio(
              aspectRatio: 1 / _cameraController.value.aspectRatio,
              child: _cameraController.buildPreview(),
            )
          : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }

  Row flashModes(double screenwidth) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.flash_off),
          color:
              _currentFlashMode == FlashMode.off ? Colors.amber : Colors.white,
          onPressed: () {
            setState(() {
              _currentFlashMode = FlashMode.off;
            });
            _cameraController.setFlashMode(FlashMode.off);
          },
        ),
        IconButton(
          icon: const Icon(Icons.flash_auto),
          color:
              _currentFlashMode == FlashMode.auto ? Colors.amber : Colors.white,
          onPressed: () {
            setState(() {
              _currentFlashMode = FlashMode.auto;
            });
            _cameraController.setFlashMode(FlashMode.auto);
          },
        ),
        IconButton(
          icon: const Icon(Icons.flash_on),
          color: _currentFlashMode == FlashMode.always
              ? Colors.amber
              : Colors.white,
          onPressed: () {
            setState(() {
              _currentFlashMode = FlashMode.always;
            });
            _cameraController.setFlashMode(FlashMode.always);
          },
        ),
        IconButton(
          icon: const Icon(Icons.highlight),
          color: _currentFlashMode == FlashMode.torch
              ? Colors.amber
              : Colors.white,
          onPressed: () {
            setState(() {
              _currentFlashMode = FlashMode.torch;
            });
            _cameraController.setFlashMode(FlashMode.torch);
          },
        ),
      ],
    );
  }

  Row zoomLevelBar(double screenwidth) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _currentZoomLevel,
            min: _minAvailableZoom,
            max: _maxAvailableZoom,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) async {
              setState(() {
                _currentZoomLevel = value;
              });
              await _cameraController.setZoomLevel(value);
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _currentZoomLevel.toStringAsFixed(1) + 'x',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
