import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pinput/pin_put/pin_put.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:global_configuration/global_configuration.dart';
import 'package:async/async.dart';
import 'package:Lenderly/screens/selection_pick_mode.dart';
import 'package:path/path.dart';
import 'package:Lenderly/config/app_config.dart' as config;
import 'package:Lenderly/screens/loan_details.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class IdentityVerification extends StatefulWidget {

  final int pageIndex;

  const IdentityVerification({Key key, this.pageIndex}) : super(key: key);
  @override
  _IdentityVerificationState createState() => _IdentityVerificationState();
}

class _IdentityVerificationState extends State<IdentityVerification> {

  final TextEditingController _pinPutController = TextEditingController();
  final FocusNode _pinPutFocusNode = FocusNode();

  VideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;
  var codeController = new TextEditingController();
  GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  YoutubePlayerController _examplevideocontroller = YoutubePlayerController(
      initialVideoId: 'grAyu6jl6wQ',
      flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
      ),
  );

  File passportFile;
  File idFrontFile;
  File idBackFile;
  File videoFile;
  File proofAddressFile;
  String mati_token;
  String token;
  String phone;
  int _initialIndex = 0;
  int time = 90;
  String code;
  bool isLoadingid = false;
  bool isLoading = false;
  bool isLoadingmobile = false;
  bool isLoadingresend = false;
  String identitytype = 'not_identity';
  String idtitle = '';
  String _pinCode;
  bool isselfieverified = false;
  bool ismobileverified = false;
  bool isemailverified = false;

   BoxDecoration get _pinPutDecoration {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      boxShadow: [
        BoxShadow(
          blurRadius: 12,
          color: Colors.black26,
        )
      ]
    );
  }

  @override
  void initState() {
    getverifycode1();
    super.initState();
  }

  @override
  void deactivate() {
    // Pauses video while navigating to next page.
    _examplevideocontroller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _examplevideocontroller.dispose();
    codeController.dispose();
    _pinPutController.dispose();
    super.dispose();
  }

  void getverifycode1() async {
    await getData();
    if (!ismobileverified) {
      getVerifyCode(false);
    }
  }

  Future<void> getData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() { 
      if (prefs.containsKey('identity_type')) {
        identitytype = prefs.getString('identity_type');
        if (identitytype == "passport") {
          idtitle = 'Take a Passport';
        }
        if (identitytype == "national_id") {
          idtitle = 'Take a National ID';
        }
        if (identitytype == "driver_license") {
          idtitle = 'Take a Driving Permit';
        }
      }
      isselfieverified = json.decode(prefs.getString('current_user'))['idisverified'];
      ismobileverified = json.decode(prefs.getString('current_user'))['phonenumberisverified'];
      isemailverified = json.decode(prefs.getString('current_user'))['emailisverified'];
      token = prefs.getString('user_token');
      phone = json.decode(prefs.getString('current_user'))['mobilephonenumber'];
    });
    print('identitytype: $identitytype');
    print('idTitle: $idtitle');
    print('token: $token');
    print('phone: $phone');
  }

  Future<void> getVerifyCode(bool resend) async {
    setState(() {
      isLoadingmobile = true;
    });
    final String url = '${GlobalConfiguration().getString('api_base_url')}';
    final client = new http.Client();
    Map data = {
      "endpoint": "verifyphonenumbertoken",
      "accesstoken": token
    };
    final response = await client.post(
      url,
      body: json.encode(data)
    );
    print('reponsebody: ${response.body.toString()}');

    if (response.statusCode == 200) {
      setState(() {
        code = json.decode(response.body)['phonenumbertoken'];
      });
      print('code: $code');
      sendSMS(resend);
    } else {
      setState(() {
        isLoadingmobile = false;
      });
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Something went wrong for getting verification code!'),
      ));
    }
  }

  Future<void> sendSMS(bool resend) async {
    final String sms_url = '${GlobalConfiguration().getString('sms_base_url')}';
    final client = new http.Client();
    
    Map sms_data = {
      "username" :"buytech",
      "userid" :"20200",
      "handle" :"3b10ba8de6dc3f5303787dd8e0961c11",
      "msg" :code,
      "from" :"Lenderely",
      "to" : '63$phone',
    };

    final response = await client.post(
      sms_url,
      body: sms_data
    );

    print('reponsebody: ${response.body.toString()}');
    setState(() {
      isLoadingmobile = false;
    });
    if (response.statusCode == 200) {
      List responseList = response.body.toString().split(" ");
      if(responseList[0] == 'OK') {
        if (!resend) {
          setTimerAndCode();
        } else {
          scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text('Successfully resend code to the $phone'),
          ));
          _pinPutController.text = null;
          if (time != 0) {
            setState(() {time = 90;});
          } else {
            setState(() {time = 90;});
            setTimerAndCode();
          }
        }
      } else {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Something went wrong for sending sms code!'),
        ));
      }
    }
  }

  void setTimerAndCode() {
    const oneSec = const Duration(seconds:1);
    new Timer.periodic(oneSec, (Timer t) {
      if(time > 0) {
        setState(() {
          time--;
        });
      } else {
        t.cancel();
        time = 0;
      }
    });
  }

  // =========== Selfie Identity Verification Part via Mati.com ==============

  void getAuthorizationToken(BuildContext context) async {
    final String url = '${GlobalConfiguration().getString('mati_base_url')}oauth';
    final client = new http.Client();
    String username = "5f3164e3e2ec23001bd647bf";
    String password = "C0YKW534TB5F1ZMQWT885C1VWH9JX5PR";
    String basicAuth =
      'Basic ' + base64Encode(utf8.encode('$username:$password'));

    final response = await client.post(
      url,
      headers: {
        "Authorization": basicAuth,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: {"grant_type": "client_credentials"}
    );
    print('getAuthorizationToken: ${response.body.toString()}');
    if (response.statusCode == 200) {
      setState(() {
        mati_token = json.decode(response.body)['access_token'];
      });
      createIdentity(context);
    } else {
      setState(() {
        isLoadingid = false;
      });
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Something went wrong for uploading identity data.')
      ));
    }
  }

  void createIdentity(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map currentUser = json.decode(prefs.getString('current_user'));
    String token = prefs.getString('user_token');
    final String url = '${GlobalConfiguration().getString('mati_base_url')}v2/identities';
    final client = new http.Client();

    final response = await client.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: json.encode({
        "flowId": "5f324eb330f3af001b33bfa5",
        "metadata": {
            "user": currentUser['name'],
            "id": "123123",
            "email": currentUser['email']
        }
      })
    );
    print('createIdentity: ${response.body.toString()}');
    if (response.statusCode == 200) {
      sendDocument(json.decode(response.body)['_id'], context);
    } else {
      setState(() {
        isLoadingid = false;
      });
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Something went wrong for uploading identity data')
      ));
    }
  }

  void sendDocument(String id, BuildContext context) async {

    final String url = '${GlobalConfiguration().getString('mati_base_url')}v2/identities/$id/send-input';
    var request = new http.MultipartRequest("POST", Uri.parse(url));
    print(url);

    Map<String, String> headers = {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": "Bearer $mati_token"
    };

    var stream_idFront, length_idFront, multipartFile1;
    var stream_idBack, length_idBack, multipartFile2;
    var stream_passport, length_passport, multipartFile3;
    if (idFrontFile != null) {
      stream_idFront = new http.ByteStream(DelegatingStream.typed(idFrontFile.openRead()));
      length_idFront = await idFrontFile.length();
      multipartFile1 = new http.MultipartFile('document', stream_idFront, length_idFront, filename: basename(idFrontFile.path));
      print(basename(idFrontFile.path));
    }
    if (idBackFile != null) {
      stream_idBack = new http.ByteStream(DelegatingStream.typed(idBackFile.openRead()));
      length_idBack = await idBackFile.length();
      multipartFile2 = new http.MultipartFile('document', stream_idBack, length_idBack, filename: basename(idBackFile.path));
      print(basename(idBackFile.path));
    }
    if (passportFile != null) {
      stream_passport = new http.ByteStream(DelegatingStream.typed(passportFile.openRead()));
      length_passport = await passportFile.length();
      multipartFile3 = new http.MultipartFile('document', stream_passport, length_passport, filename: basename(passportFile.path));
      print(basename(passportFile.path));
    }
    var stream_proof = new http.ByteStream(DelegatingStream.typed(proofAddressFile.openRead()));
    var length_proof = await proofAddressFile.length();
    var stream_video = new http.ByteStream(DelegatingStream.typed(videoFile.openRead()));
    var length_video = await videoFile.length();

    print(basename(proofAddressFile.path));
    print(basename(videoFile.path));

    var multipartFile4 = new http.MultipartFile('document', stream_proof, length_proof, filename: basename(proofAddressFile.path));
    var multipartFile5 = new http.MultipartFile('video', stream_video, length_video, filename: basename(videoFile.path));

    if (identitytype == "passport") {
      request.files.addAll([multipartFile3,multipartFile4,multipartFile5]);
      request.fields['inputs'] = '[{"inputType": "document-photo","group": 0,"data": {"type": "passport","country": "NL","page": "front","filename": "${basename(passportFile.path)}"}},{"inputType": "document-photo","group": 1,"data": {"type": "proof-of-residency","country": "NL","page": "front","filename": "${basename(proofAddressFile.path)}"}},{"inputType": "selfie-video","data": {"filename": "${basename(videoFile.path)}"}}]';
    }
    if (identitytype == "national_id") {
      request.files.addAll([multipartFile1, multipartFile2,multipartFile4,multipartFile5]);
      request.fields['inputs'] = '[{"inputType": "document-photo","group": 0,"data": {"type": "national-id","country": "NL","page": "front","filename": "${basename(idFrontFile.path)}"}},{"inputType": "document-photo","group": 0,"data": {"type": "national-id","country": "NL","page": "back","filename": "${basename(idBackFile.path)}"}},{"inputType": "document-photo","group": 1,"data": {"type": "proof-of-residency","country": "NL","page": "front","filename": "${basename(proofAddressFile.path)}"}},{"inputType": "selfie-video","data": {"filename": "${basename(videoFile.path)}"}}]';
    }
    if (identitytype == "driver_license") {
      request.files.addAll([multipartFile1, multipartFile2,multipartFile4,multipartFile5]);
      request.fields['inputs'] = '[{"inputType": "document-photo","group": 0,"data": {"type": "driving-license","country": "NL","page": "front","filename": "${basename(idFrontFile.path)}"}},{"inputType": "document-photo","group": 0,"data": {"type": "driving-license","country": "NL","page": "back","filename": "${basename(idBackFile.path)}"}},{"inputType": "document-photo","group": 1,"data": {"type": "proof-of-residency","country": "NL","page": "front","filename": "${basename(proofAddressFile.path)}"}},{"inputType": "selfie-video","data": {"filename": "${basename(videoFile.path)}"}}]';
    }
    request.headers.addAll(headers);

    var response = await request.send();
    print(response.statusCode);
    setState(() {
      isLoadingid = false;
    });

    // listen for response
    response.stream.transform(utf8.decoder).listen((value) {
      print(value);
      // retrieveWebhook(id, context);
      if (ismobileverified) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => IdentityVerification(pageIndex: 2),
        ));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => IdentityVerification(pageIndex: 1),
        ));
      }
    });
    if (response.statusCode == 200) {
      print("success!!!!!!!!!!!!!!!!!!!!!!!!!!");
    }
  }

  void retrieveWebhook(String id, BuildContext context) async {
    final String url = '${GlobalConfiguration().getString('mati_base_url')}v2/verifications/$id';
    final client = new http.Client();

    final response = await client.get(
      url,
      headers: {
        "Authorization": "Bearer $mati_token",
        "Content-Type": "application/x-www-form-urlencoded"
      }
    );
    setState(() {
      isLoadingid = false;
    });
    print('retrieveWebhook: ${response.body.toString()}');
    if (ismobileverified) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => IdentityVerification(pageIndex: 2),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => IdentityVerification(pageIndex: 1),
      ));
    }
    if (response.statusCode == 200) {
      print('success!!!!!!!!!!!!!!');
    }
  }

  validation() {
    if (identitytype == "passport") {
      if (passportFile == null) {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Please select passport file.')
        ));
        return false;
      }
    }
    if (identitytype == "national_id" || identitytype == "driver_license") {
      if (idFrontFile == null) {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Please select ID front file.')
        ));
        return false;
      }
      if (idBackFile == null) {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Please select ID back file.')
        ));
        return false;
      }
    }
    if (proofAddressFile == null) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Please select proof of residence file.')
      ));
      return false;
    }
    if (videoFile == null) {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Please select video file.')
      ));
      return false;
    }
    return true;
  }

  Future<File> _getCroppImage(File file, String title) async {
    File croppedFile = await ImageCropper.cropImage(
      sourcePath: file.path,
      cropStyle: CropStyle.rectangle,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9
      ],
      androidUiSettings: AndroidUiSettings(
        showCropGrid: false,
        toolbarColor: config.HexColor('#1D6285'),
        toolbarTitle: title,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false),
      iosUiSettings: IOSUiSettings(
        minimumAspectRatio: 1.0,
      )
    );
    return croppedFile;
  }

  void _choosePassportImage(BuildContext context) async {
    File file;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SelectionPickMode()),
    );
    if (result != null) {
      file = await ImagePicker.pickImage(source: result == 'gallery' ? ImageSource.gallery : ImageSource.camera);
    } else {
      return;
    }
    print('file.path: '+file.path);
    File croppedFile = await _getCroppImage(file, 'Passport Photo');
    if (croppedFile != null) {
      setState(() {
        passportFile = croppedFile;
      });
    }
  }

  void _chooseIDFrontImage(BuildContext context) async {
    File file;
    file = await ImagePicker.pickImage(source: ImageSource.camera);
    print('file.path: '+file.path);
    // File croppedFile = await _getCroppImage(file, 'ID Front Photo');
    if (file != null) {
      setState(() {
        idFrontFile = file;
      });
    }
  }

  void _chooseIDBackImage(BuildContext context) async {
    File file;
    file = await ImagePicker.pickImage(source: ImageSource.camera);
    print('file.path: '+file.path);
    // File croppedFile = await _getCroppImage(file, 'ID Back Photo');
    if (file != null) {
      setState(() {
        idBackFile = file;
      });
    }
  }

  void _chooseProofAddressImage(BuildContext context) async {
    File file;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SelectionPickMode()),
    );
    if (result != null) {
      file = await ImagePicker.pickImage(source: result == 'gallery' ? ImageSource.gallery : ImageSource.camera);
    } else {
      return;
    }
    print('file.path: '+file.path);
    // File croppedFile = await _getCroppImage(file, 'Proof of Address Photo');
    if (file != null) {
      setState(() {
        proofAddressFile = file;
      });
    }
  }

  Future getVideo() async {
    Future<File> _videoFile = ImagePicker.pickVideo(source: ImageSource.camera);
    _videoFile.then((file) async {
      setState(() {
        videoFile = file;
        _controller = VideoPlayerController.file(videoFile);

        // Initialize the controller and store the Future for later use.
        _initializeVideoPlayerFuture = _controller.initialize();

        // Use the controller to loop the video.
        _controller.setLooping(true);
      });
    });
  }

  void _modalBottomSheetMenu(BuildContext context){
    showModalBottomSheet(
        context: context,
        builder: (builder){
          return new Container(
            height: 250.0,
            color: Colors.transparent, //could change this to Color(0xFF737373), 
                        //so you don't have to change MaterialApp canvasColor
            child: YoutubePlayer(
                controller: _examplevideocontroller,
                liveUIColor: Colors.amber,
            ),
          );
        }
    );
  }

  
  // ===================== Mobile Number verification part =======================
  
  void verifyCode(BuildContext context, String veri_code) {
    print(time);
    if(time == 0) {
      setState(() {
        isLoading = false;
      });
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Timeout!. Please send again request!'),
      ));
    } else {
      if(veri_code == code) {
        verifyPhonenumber(context);
      } else {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Verification code is wrong! Please retry!'),
        ));
      }
    }
  }

  void verifyPhonenumber(BuildContext context) async {
    final String url = '${GlobalConfiguration().getString('api_base_url')}';
    final client = new http.Client();
    print(code);
    Map data = {
      "endpoint": "verifyphonenumber",
      "accesstoken": token,
      "params": {
        "phonenumbertoken": code
      }
    };
    final response = await client.post(
      url,
      body: json.encode(data)
    );
    print('reponsebody: ${response.body.toString()}');
    setState(() {
      isLoading = false;
    });

    if (response.statusCode == 200) {
      setState(() {
        ismobileverified = true;
      });
      if (isemailverified) {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => LoanDetails(),
        ));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => IdentityVerification(pageIndex: 2,),
        ));
      }
    } else {
      scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Something went wrong for getting verification code!'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.pageIndex == null ? 0 : widget.pageIndex,
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          bottom: TabBar(
            unselectedLabelColor: Color.fromRGBO(255, 255, 255, 0.25),
            tabs: [
              Tab(icon: Text('Selfie', style: GoogleFonts.poppins(fontSize: 10))),
              Tab(icon: Text('Mobile', style: GoogleFonts.poppins(fontSize: 10))),
              Tab(icon: Text('Email', style: GoogleFonts.poppins(fontSize: 10))),
            ],
          ),
          title: Text('Identity Verification', style: GoogleFonts.poppins(fontSize: 20)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  config.HexColor('#1D6285'),
                  config.HexColor('#27ADDE'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [            
            // ============= Selfie tab ================
            SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0),
                width: config.App(context).appWidth(100),
                child: isselfieverified ? Column(
                  children: [
                    SizedBox(height: 100,),
                    Text('Verified!', style: TextStyle(color: Colors.blueAccent, fontSize: 40),)
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Passport, Id part
                    Text(
                      idtitle,
                      style: GoogleFonts.poppins(
                        color: config.HexColor('#1D6285'),
                        fontSize: 10,
                      )
                    ),
                    SizedBox(height: 4.0,),
                    identitytype == "passport" ? GestureDetector(
                      onTap: () {
                        _choosePassportImage(context);
                      },
                      child: passportFile == null ? Container(
                        width: config.App(context).appWidth(100)-60,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: config.HexColor('#1D6285')),
                        ),
                        child: Center(
                          child: Container(
                            child: Image.asset('assets/images/plus.png'),
                          ),
                        ),
                      )
                      : Container(
                        width: config.App(context).appWidth(100),
                        alignment: Alignment.center,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Image.file(passportFile, height: 150, width: 200, fit: BoxFit.fill,)
                        ),
                      )                      
                    ) : 
                    identitytype == "national_id" || identitytype == "driver_license" ? Container(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _chooseIDFrontImage(context);
                            },
                            child: idFrontFile == null ? Container(
                              width: (config.App(context).appWidth(100)-80)/2,
                              height: 93,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                border: Border.all(color: config.HexColor('#1D6285'))
                              ),
                              child: Center(
                                child: Container(
                                  // child: Image.asset('assets/images/plus.png'),
                                  child: Text('ID Front',
                                    style: GoogleFonts.poppins(
                                      color: config.HexColor('#1D6285'),
                                      fontSize: 10,
                                    )
                                  ),
                                ),
                              ),
                            ) : Container(
                              width: (config.App(context).appWidth(100)-80)/2,
                              height: 93,
                              alignment: Alignment.center,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.file(idFrontFile, fit: BoxFit.fill,)
                              ),
                            ),
                          ),
                          SizedBox(width: 20,),
                          GestureDetector(
                            onTap: () {
                              _chooseIDBackImage(context);
                            },
                            child: idBackFile == null ? Container(
                              width: (config.App(context).appWidth(100)-80)/2,
                              height: 93,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                border: Border.all(color: config.HexColor('#1D6285'))
                              ),
                              child: Center(
                                child: Container(
                                  child: Text('ID Back',
                                    style: GoogleFonts.poppins(
                                      color: config.HexColor('#1D6285'),
                                      fontSize: 10,
                                    )
                                  ),
                                ),
                              ),
                            ) : Container(
                              width: (config.App(context).appWidth(100)-80)/2,
                              height: 93,
                              alignment: Alignment.center,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.file(idBackFile, fit: BoxFit.fill,)
                              ),
                            ),
                          )
                        ],
                      ),
                    ) : Container(),
                    SizedBox(height: 6.0,),

                    // Selfie video part
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Take a Selfie Video',
                          style: GoogleFonts.poppins(
                            color: config.HexColor('#1D6285'),
                            fontSize: 10,
                          )
                        ),
                        GestureDetector(
                          onTap: () {
                            _modalBottomSheetMenu(context);
                          },
                          child: Text(
                            'View example',
                            style: GoogleFonts.poppins(
                              color: config.HexColor('#1D6285'),
                              fontSize: 10,
                              decoration: TextDecoration.underline
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 4.0,),
                    GestureDetector(
                      onTap: () {
                        getVideo();
                      },
                      child: Container(
                        width: config.App(context).appWidth(100)-60,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: config.HexColor('#1D6285'))
                        ),
                        child: videoFile != null ? Visibility(
                          visible: _controller != null,
                          child: FutureBuilder(
                            future: _initializeVideoPlayerFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done) {
                                // If the VideoPlayerController has finished initialization, use
                                // the data it provides to limit the aspect ratio of the video.
                                return AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio,
                                  // Use the VideoPlayer widget to display the video.
                                  child: VideoPlayer(_controller),
                                );
                              } else {
                                // If the VideoPlayerController is still initializing, show a
                                // loading spinner.
                                return Center(child: CircularProgressIndicator());
                              }
                            },
                          ),
                        ) : Center(
                          child: Container(
                            child: Image.asset('assets/images/plus.png'),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.0,),

                    // Proof Address Part
                    Text(
                      'Add proof of address',
                      style: GoogleFonts.poppins(
                        color: config.HexColor('#1D6285'),
                        fontSize: 10,
                      )
                    ),
                    SizedBox(height: 4.0,),
                    GestureDetector(
                      onTap: () {
                        _chooseProofAddressImage(context);
                      },
                      child: proofAddressFile == null ? Container(
                        width: config.App(context).appWidth(100)-60,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: config.HexColor('#1D6285'))
                        ),
                        child: Center(
                          child: Container(
                            child: Image.asset('assets/images/plus.png'),
                          ),
                        ),
                      )
                      : Container(
                        width: config.App(context).appWidth(100),
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Image.file(proofAddressFile, height: 150, width: 200, fit: BoxFit.fill,)
                        ),
                      )
                    ),
                    SizedBox(height: 15.0,),

                    // Submit button
                    Container(
                      height: 51,
                      width: config.App(context).appWidth(100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromRGBO(29, 98, 133, 1), 
                            Color.fromRGBO(39, 173, 222, 1)
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(10))
                      ),
                      child: FlatButton(
                        onPressed: () {
                          if (validation()) {
                            setState(() {
                              isLoadingid = true;
                            });
                            getAuthorizationToken(context);
                          }
                        },
                        child: isLoadingid ? Center(child: CircularProgressIndicator(valueColor:  AlwaysStoppedAnimation(Colors.white)))
                        : Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: config.App(context).appHeight(2.2),
                          )
                        ),
                      ),
                    ),
                    SizedBox(height: 6,)
                  ],
                )
              ),
            ),
            
            // ============= Mobile tab ================

            SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0),
                width: config.App(context).appWidth(100),
                child: isLoadingmobile ? Center(child: CircularProgressIndicator(valueColor:  AlwaysStoppedAnimation(Colors.blue)))
                : ismobileverified ? Column(
                  children: [
                    SizedBox(height: 100,),
                    Text('Verified!', style: TextStyle(color: Colors.blueAccent, fontSize: 40),)
                  ],
                )
                : Column(
                  children: [
                    SizedBox(height: 50,),
                    Icon(Icons.vpn_key, color: Colors.blue, size: 34,),
                    SizedBox(height: 35,),
                    Text('Enter the One Time Password (OTP), Sent to your Phone Number (+****${phone.substring(phone.length-3, phone.length)})',
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 35,),

                    // Verfication Code InputField
                    PinPut(
                      fieldsCount: 6,
                      onSubmit: (String pin) {
                        setState(() {
                          _pinCode = pin;
                        });
                      },
                      focusNode: _pinPutFocusNode,
                      controller: _pinPutController,
                      submittedFieldDecoration: _pinPutDecoration.copyWith(
                          borderRadius: BorderRadius.circular(20)),
                      selectedFieldDecoration: _pinPutDecoration,
                      followingFieldDecoration: _pinPutDecoration.copyWith(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        border: Border.all(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 110.0,),
                    Text('Did\'nt Recieve OTP?',
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15.0,),

                    GestureDetector(
                      onTap: () {
                        getVerifyCode(true);
                      },
                      child: Text('Resend',
                        style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#1D6285')),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    Text(time.toString(),
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 100.0,),

                    // Submit button
                    Container(
                      height: 51,
                      width: config.App(context).appWidth(100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromRGBO(29, 98, 133, 1), 
                            Color.fromRGBO(39, 173, 222, 1)
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(10))
                      ),
                      child: FlatButton(
                        onPressed: () {
                          setState(() {
                            _pinCode = _pinPutController.text;
                          });
                          print('_pinCode = $_pinCode');
                          if (_pinCode != '') {
                            setState(() {
                              isLoading = true;
                            });
                            verifyCode(context, _pinCode);
                          } else {
                            scaffoldKey.currentState.showSnackBar(SnackBar(
                              content: Text('Please fill this codefiled!'),
                            ));
                          }
                        },
                        child: isLoading ? Center(child: CircularProgressIndicator(valueColor:  AlwaysStoppedAnimation(Colors.blue)))
                        : Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: config.App(context).appHeight(2.2),
                          )
                        ),
                      ),
                    ),
                    SizedBox(height: 6,)
                  ],
                )
              ),
            ),
            
            // ============= Email tab =================
            SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0),
                width: config.App(context).appWidth(100),
                child: Column(
                  children: [
                    SizedBox(height: 50,),
                    Image.asset('assets/images/mail.png'),
                    SizedBox(height: 35,),
                    Text('Click the verification link sent to tsw*****8@gmail.com.',
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 73,),

                    Text('Not Verified',
                      style: GoogleFonts.poppins(fontSize: 28, color: config.HexColor('#FF0000')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 70.0,),

                    Text('Did\'nt Recieve Verification Link?',
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15.0,),

                    GestureDetector(
                      onTap: () {
                        
                      },
                      child: Text('Resend',
                        style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#1D6285')),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text('90s',
                      style: GoogleFonts.poppins(fontSize: 15, color: config.HexColor('#AEAEAE')),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 100.0,),

                    // Submit button
                    Container(
                      height: 51,
                      width: config.App(context).appWidth(100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromRGBO(29, 98, 133, 1), 
                            Color.fromRGBO(39, 173, 222, 1)
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(10))
                      ),
                      child: FlatButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => LoanDetails(),
                          ));
                        },
                        child: Text(
                          'Next',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: config.App(context).appHeight(2.2),
                          )
                        ),
                      ),
                    ),
                    SizedBox(height: 6,)
                  ],
                )
              ),
            ),
          ],
        ),
        floatingActionButton: _controller == null
        ? null
        : FloatingActionButton(
            onPressed: () {
              // Wrap the play or pause in a call to `setState`. This ensures the
              // correct icon is shown.
              setState(() {
                // If the video is playing, pause it.
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  // If the video is paused, play it.
                  _controller.play();
                }
              });
            },
            // Display the correct icon depending on the state of the player.
            child: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
      )
    );
  }
}