import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:barcode_image/barcode_image.dart' as bc;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thermal_printer/models/bluetooth_printer.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const _primaryColor = Color.fromARGB(255, 19, 99, 233);

  Map<String, dynamic> billData = {};

  String appDocumentsPath = "";
  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  void _loadFolder() async {
    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    setState(() {
      appDocumentsPath = appDocumentsDirectory.path;
    });
  }

  Device? selectedPrinter;

  void selectDevice(Device device) async {
    setState(() {
      selectedPrinter = device;
    });
  }

  void deSelectDevice() async {
    setState(() {
      selectedPrinter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Future _generateBillBytes() async {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile, spaceBetweenRows: 1);
      List<int> bytes = [];
      DateTime now = DateTime.now();
      billData['bill_id'] = "670427010001";
      billData['user_id'] = "U00100001";
      billData['org_id'] = '';
      billData['issue_date'] =
          DateFormat('dd/MM/').format(now) + (now.year + 543).toString();
      billData['due_date'] =
          DateFormat('dd/MM/').format(now) + (now.year + 543).toString();
      billData['path'] = "001";
      billData['user_name'] = "นาย จาคี อินทปัญญา";
      billData['address'] =
          "49/12 ซอย 6 ถ.นิพัทธ์สงเคราะห์ 1 ต.หาดใหญ่ อ.หาดใหญ่ จ.สงขลา 90110";
      billData['bf_num'] = "23";
      billData['cur_num'] = "24";
      billData['bf_unit'] = "5496";
      billData['cur_unit'] = "5520";
      billData['water_value'] = "174.00";
      billData['discount'] = "0.00";
      billData['service'] = "10.00";
      billData['vat'] = "12.88";
      billData['sub_total'] = "196.88";
      billData['debt_month'] = "0";
      billData['debt_value'] = "0.00";
      billData['total'] = "196.88";
      billData["bf_date"] =
          DateFormat('dd/MM/').format(now) + (now.year + 543).toString();
      billData['expired_date'] =
          DateFormat('dd/MM/').format(now) + (now.year + 543).toString();
      billData['bank_due_date'] =
          DateFormat('dd/MM/').format(now) + (now.year + 543).toString();

      const suffixId = '00';
      const taxServiceId = '0994000577770';
      String ref1 = "00100001";
      String ref2 =
          '${billData['bill_id']}${(now.year + 543).toString().substring(2)}${DateFormat('MMdd').format(now)}';
      num sum = num.parse(billData['total']);
      String amount = sum.toDouble().toStringAsFixed(2).replaceAll('.', '');
      String barcodeData = '|$taxServiceId$suffixId\r$ref1\r$ref2\r$amount';

      // counter service data
      List<int> counterServiceConstants = [5, 3, 5, 2, 9];
      int sumValue = 0;
      String counterServiceRef2 =
          '${billData['bill_id']}${DateFormat('yyMMdd').format(now)}';
      List counterServiceRef =
          '$ref1$counterServiceRef2${amount.padLeft(7, '0')}'.split('');
      counterServiceRef.asMap().forEach((index, value) {
        sumValue += int.parse(value) *
            counterServiceConstants[index % counterServiceConstants.length];
      });
      String checkDigit = ((sumValue * 69) % 100).toString().padLeft(2, '0');
      String counterServiceData =
          '|$taxServiceId$suffixId\r$ref1$checkDigit\r$counterServiceRef2\r$amount';
      // blank image
      String blankImageB64 =
          'R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';

      // barcode image ---------------------------
      img.Image image;
      // img.Image image = img.Image(1300, 100); // 40x450 no \r | speed 1
      // img.Image image = img.Image(3000, 280); // 38x500 with \r | speed 1
      // img.fill(image, img.getColor(255, 255, 255));
      // bc.drawBarcode(image, bc.Barcode.code128(escapes: true), barcodeData);
      // File('$appDocumentsPath/barcode.png')
      //     .writeAsBytesSync(img.encodePng(image));
      // image = img.copyRotate(image, -90);

      // String barCodeB64 = base64Encode(img.encodePng(image));

      // QRcode image ---------------------------
      // head
      // String qrCodeData = widget.waterBill.waterUserNumber.toString();
      image = img.Image(450, 450);
      img.fill(image, img.getColor(255, 255, 255));
      bc.drawBarcode(image, bc.Barcode.qrCode(), barcodeData);
      String qrCodeB64 = base64Encode(img.encodePng(image));

      // bottom
      image = img.Image(500, 500);
      img.fill(image, img.getColor(255, 255, 255));
      bc.drawBarcode(image, bc.Barcode.qrCode(), barcodeData);
      String qrCodeBarB64 = base64Encode(img.encodePng(image));

      // qrcode counter service
      image = img.Image(300, 300);
      img.fill(image, img.getColor(255, 255, 255));
      bc.drawBarcode(image, bc.Barcode.qrCode(), counterServiceData);
      String counterServiceQRB64 = base64Encode(img.encodePng(image));

      // RePaste data ---------------------------
      String data = await rootBundle.loadString("assets/prapa.svg");
      // style
      data = data.replaceAll(RegExp(r'font-weight:normal'), 'font-weight:bold');
      data = data.replaceAll(RegExp(r'font-size:8px'), 'font-size:9px');
      // data
      data = data.replaceAll(RegExp(r'{{bill_type}}'), 'ใบแจ้งค่าน้ำประปา');
      data = data.replaceAll(
          RegExp(r'{{sub_bill_type}}'), '(ไม่ใช่ใบเสร็จรับเงิน)');
      data = data.replaceAll(RegExp(r'{{bill_id}}'), billData['bill_id']);
      data = data.replaceAll(RegExp(r'{{user_id}}'), billData['user_id']);
      data = data.replaceAll(RegExp(r'{{org_id}}'), billData['org_id']);
      // data = data.replaceAll(RegExp(r'{{issue_date}}'), '03/01/62 11:06');
      data = data.replaceAll(RegExp(r'{{issue_date}}'),
          "${billData['issue_date']} ${DateFormat.Hm().format(now)}");
      data = data.replaceAll(RegExp(r'{{due_date}}'), billData['due_date']);
      data = data.replaceAll(RegExp(r'{{path}}'), billData['path']);
      data = data.replaceAll(RegExp(r'{{user_name}}'), billData['user_name']);
      data = data.replaceAll(
          RegExp(r'{{address1}}'),
          billData['address'].substring(
              0,
              billData['address'].length > 35
                  ? 36
                  : billData['address'].length)); // must less than 36 chars
      data = data.replaceAll(
          RegExp(r'{{address2}}'),
          billData['address'].length > 35
              ? billData['address'].substring(36)
              : "");

      data = data.replaceAll(RegExp(r'{{bf_date}}'), billData['bf_date']);
      data =
          data.replaceAll(RegExp(r'{{cur_date}}'), "${billData['issue_date']}");
      data = data.replaceAll(RegExp(r'{{bf_num}}'), billData['bf_num']);
      data = data.replaceAll(RegExp(r'{{cur_num}}'), billData['cur_num']);
      data = data.replaceAll(RegExp(r'{{bf_unit}}'), billData['bf_unit']);
      data = data.replaceAll(RegExp(r'{{cur_unit}}'), billData['cur_unit']);

      data =
          data.replaceAll(RegExp(r'{{water_value}}'), billData['water_value']);
      data = data.replaceAll(RegExp(r'{{discount}}'), billData['discount']);
      data = data.replaceAll(RegExp(r'{{service}}'), billData['service']);
      data = data.replaceAll(RegExp(r'{{vat}}'), billData['vat']);
      data = data.replaceAll(RegExp(r'{{sub_total}}'), billData['sub_total']);
      data = data.replaceAll(
          RegExp(r'{{debt_month}}'), billData['debt_month'].toString());
      data = data.replaceAll(RegExp(r'{{debt_value}}'), billData['debt_value']);
      data = data.replaceAll(RegExp(r'{{total}}'), billData['total']);

      // data =
      //     data.replaceAll(RegExp(r'{{suspend_date}}'), billData['expired_date']);
      data = data.replaceAll(
          RegExp(r'{{suspend_date}}'), billData['bank_due_date']);

      // add check if is_debt true
      // if (waterUser.isDebit) {
      //   data = data.replaceAll(RegExp(r'สแกนจ่าย'), '');
      //   data = data.replaceAll(RegExp(r'{{qr_code_bar_b64}}'), blankImageB64);
      //   data = data.replaceAll(RegExp(r'ชำระเงินค่าน้ำประปาเทศบาลนครภูเก็ต'),
      //       'ชำระค่าน้ำประปาผ่านบัญชีธนาคาร');
      //   data = data.replaceAll(RegExp(r'{{cs_qrcode}}'), blankImageB64);
      //   data = data.replaceAll(RegExp(r'iVBO.*='), blankImageB64);
      //   data = data.replaceAll(RegExp(r'Comp Code: 99421'), '');
      //   data = data.replaceAll(RegExp(r'\(Ref.1\):'), '');
      //   data = data.replaceAll(RegExp(r'{{ref_1}}'), '');
      //   data = data.replaceAll(RegExp(r'\(Ref.2\):'), '');
      //   data = data.replaceAll(RegExp(r'{{ref_2}}'), '');
      //   data = data.replaceAll(RegExp(r'{{cs_data}}'), '');
      //   data = data.replaceAll(RegExp(r'{{qr_code_b64}}'), blankImageB64);
      // } else if (billData['debt_month'] == 0) {
      data = data.replaceAll(RegExp(r'{{qr_code_bar_b64}}'), qrCodeBarB64);
      data = data.replaceAll(RegExp(r'{{cs_qrcode}}'), blankImageB64);
      data = data.replaceAll(
          RegExp(r'{{cs_data}}'), counterServiceData.replaceAll('/r', ' '));
      data = data.replaceAll(RegExp(r'{{ref_1}}'), ref1);
      data = data.replaceAll(RegExp(r'{{ref_2}}'), ref2);
      data = data.replaceAll(RegExp(r'{{qr_code_b64}}'), qrCodeB64);
      // } else {
      //   data = data.replaceAll(RegExp(r'สแกนจ่าย'), '');
      //   data = data.replaceAll(RegExp(r'{{qr_code_bar_b64}}'), blankImageB64);
      //   data = data.replaceAll(RegExp(r'{{cs_qrcode}}'), blankImageB64);
      //   data = data.replaceAll(RegExp(r'ชำระเงินค่าน้ำประปาเทศบาลนครภูเก็ต'),
      //       'โปรดตรวจสอบหนี้ค้างที่กองการประปาเทศบาลนครภูเก็ต');
      //   data = data.replaceAll(RegExp(r'iVBO.*='), blankImageB64);
      //   data = data.replaceAll(RegExp(r'Comp Code: 99421'), '');
      //   data = data.replaceAll(RegExp(r'\(Ref.1\):'), '');
      //   data = data.replaceAll(RegExp(r'{{ref_1}}'), '');
      //   data = data.replaceAll(RegExp(r'\(Ref.2\):'), '');
      //   data = data.replaceAll(RegExp(r'{{ref_2}}'), '');
      //   data = data.replaceAll(RegExp(r'{{cs_data}}'), '');
      //   data = data.replaceAll(RegExp(r'{{qr_code_b64}}'), blankImageB64);
      // }

      // File('$appDocumentsPath/prapa.svg').writeAsStringSync(data);
      data = data.replaceAll(
          RegExp(r'สแกนจ่าย'), 'สแกนจ่ายภายใน ${billData['bank_due_date']}');
      data = data.replaceAll(RegExp(r'{{qr_code_b64}}'), qrCodeB64);

      DrawableRoot s = await svg.fromSvgString(data, data);
      var picture = s.toPicture(size: const Size(590, 1575));
      var sImg = await picture.toImage(590, 1575);
      var bytes2 = (await sImg.toByteData(format: ImageByteFormat.png))!;

      var testImage = img.decodeImage(bytes2.buffer.asUint8List())!;
      File('$appDocumentsPath/billPrapa.png')
          .writeAsBytesSync(bytes2.buffer.asUint8List());
      bytes += generator.image(testImage);

      final File file = File('$appDocumentsPath/text.txt');
      await file.writeAsString(data);
    }

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(
              // lazy for  run since app start
              create: (context) => BluetoothPrinter(),
              lazy: false)
        ],
        builder: (context, child) {
          BluetoothPrinter bluetoothPrinter = context.watch<BluetoothPrinter>();
          bool scanning = bluetoothPrinter.scanning;
          bool isConnected = bluetoothPrinter.isConnected;
          Device? connectedPrinter = bluetoothPrinter.connectedPrinter;
          bool isRegisterdBluetoothDevice =
              bluetoothPrinter.isRegisterdBluetoothDevice();

          return MaterialApp(
            theme: ThemeData(
              brightness: Brightness.light,
              textTheme: GoogleFonts.notoSansThaiTextTheme(const TextTheme()),
            ),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 80),
                      Text("1. กดค้นหาอุปกรณ์"),
                      OutlinedButton(
                        onPressed: !scanning
                            ? () {
                                context.read<BluetoothPrinter>().scan();
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(scanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth),
                            Text(scanning
                                ? "กำลังค้นหาอุปกรณ์"
                                : "ค้นหาอุปกรณ์"),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child:
                            Text('2.เลือกรายชื่ออุปกรณ์ที่ต้องการจะเชื่อมต่อ'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Consumer<BluetoothPrinter>(
                          builder: ((context, btp, child) => Column(
                                children: btp.devices.map((device) {
                                  bool deviceSelected =
                                      selectedPrinter != null &&
                                          (device.address != null &&
                                              selectedPrinter!.address ==
                                                  device.address);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 7),
                                    decoration: BoxDecoration(
                                      border: deviceSelected
                                          ? Border.all(
                                              color: Colors.black, width: 2)
                                          : Border.all(
                                              color: Colors.white, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: deviceSelected
                                            ? [
                                                Colors.black45,
                                                Colors.black38,
                                              ]
                                            : [
                                                const Color.fromARGB(
                                                    255, 149, 154, 158),
                                                const Color.fromARGB(
                                                    255, 171, 176, 180),
                                              ],
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        "${device.deviceName}",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        "${device.address}",
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.white),
                                      ),
                                      onTap: () {
                                        if (deviceSelected) {
                                          deSelectDevice();
                                        } else {
                                          selectDevice(device);
                                        }
                                      },
                                      leading: const Icon(
                                        Icons.bluetooth,
                                        color: Colors.white,
                                        size: 35,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              )),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Text('3.กดเชื่อมต่อ'),
                      ),
                      connectedPrinter != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.green,
                                        Colors.green.withBlue(150),
                                        Colors.green.withBlue(250),
                                      ],
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      "${connectedPrinter.deviceName}",
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      "${connectedPrinter.address}",
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.white),
                                    ),
                                    leading: const Icon(
                                      Icons.bluetooth,
                                      color: Colors.white,
                                      size: 35,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: selectedPrinter != null && !isConnected
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    minimumSize: const Size.fromHeight(40)),
                                onPressed: isConnected
                                    ? null
                                    : () async {
                                        await context
                                            .read<BluetoothPrinter>()
                                            .connectDevice(selectedPrinter!,
                                                reconnect: true);
                                      },
                                child: const Text("กดเพื่อเชื่อมต่อ",
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? const Color.fromARGB(255, 212, 86, 76)
                                        : Colors.grey,
                                    minimumSize: const Size.fromHeight(40)),
                                onPressed: !isConnected
                                    ? null
                                    : () async {
                                        await context
                                            .read<BluetoothPrinter>()
                                            .disconnectDevice();
                                      },
                                child: Text(
                                    isConnected
                                        ? "ยกเลิกการเชื่อมต่อ"
                                        : "รอการเชื่อมต่อ",
                                    style: TextStyle(
                                      color: isConnected ? Colors.white : null,
                                    ),
                                    textAlign: TextAlign.center),
                              ),
                      ),
                      isRegisterdBluetoothDevice == true
                          ? ElevatedButton(
                              style: ButtonStyle(
                                foregroundColor:
                                    MaterialStatePropertyAll<Color>(
                                        Colors.red[800]!),
                                overlayColor: MaterialStatePropertyAll<Color>(
                                    Colors.red[800]!),
                                surfaceTintColor:
                                    MaterialStatePropertyAll<Color>(
                                        Colors.red[800]!),
                              ),
                              onPressed: () {
                                context
                                    .read<BluetoothPrinter>()
                                    .deRegisterBluetoothDevice();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.delete),
                                  SizedBox(width: 3),
                                  Text("ลืมอุปกรณ์"),
                                ],
                              ),
                            )
                          : const SizedBox(),
                      SizedBox(height: 15),
                      Text("4.เมื่อเชื่อมต่อแล้ว สามารถพิมพ์หน้าทดสอบได้"),
                      SizedBox(height: 8),
                      isConnected
                          ? ElevatedButton(
                              style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStatePropertyAll(Colors.blue)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.print,
                                    color: Colors.white,
                                  ),
                                  Text(" พิมพ์หน้าทดสอบ",
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                              onPressed: () async {
                                await _generateBillBytes();
                              },
                            )
                          : MaterialButton(
                              onPressed: () {},
                              hoverColor: null,
                              splashColor: null,
                              highlightColor: null,
                              focusColor: null,
                              color: Colors.grey[300],
                              shape: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(200),
                                  borderSide: BorderSide(
                                      width: 1, color: Colors.transparent)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.print, color: Colors.grey),
                                  Text(
                                    " พิมพ์หน้าทดสอบ",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              )),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}
