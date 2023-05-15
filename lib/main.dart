import 'package:flutter/material.dart';
import 'dart:io';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
//打开浏览器
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(
    MaterialApp(
      home: QRScannerExample(
        key: qrExampleState,
      ),
    ),
  );
}

///使用global key获取当前state对象
final GlobalKey<_QRScannerExampleState> qrExampleState =
    GlobalKey<_QRScannerExampleState>(debugLabel: '_QRScannerExampleState');

///示例app
class QRScannerExample extends StatefulWidget {
  QRScannerExample({super.key});

  @override
  State<QRScannerExample> createState() => _QRScannerExampleState();

  ///数据添加回调函数
  void onDataAdded(Barcode newData) {
    final state = qrExampleState.currentState;
    if (state != null) {
      state.addData(newData);
    }
  }
}

/// 扫描示例app
class _QRScannerExampleState extends State<QRScannerExample> {
  ///扫描结果列表
  List<Barcode> scanHistorys = [];

  ///当前页面
  Widget? curPage;

  ///当前选中页面坐标
  int _selectedIndex = 0;

  ///根据选中的页面坐标选择页面
  ///0:扫描页面
  ///1:历史页面
  void _onItemTapped(int value) {
    setState(() {
      _selectedIndex = value;
    });
  }

  ///添加历史数据
  void addData(Barcode newData) {
    setState(() {
      scanHistorys.add(newData);
    });
  }

  @override
  Widget build(BuildContext context) {
    //根据当前坐标选择页面
    switch (_selectedIndex) {
      case 0:
        curPage = ScanPage();
        break;
      case 1:
        curPage = HistoryPage(scanHistorys: scanHistorys);
        break;
      default:
        curPage = ScanPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("二维码扫描器"),
      ),
      body: curPage,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '扫描',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '历史',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

///扫描子页面
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<StatefulWidget> createState() => _ScanPage();
}

///扫描子页面State类
class _ScanPage extends State<ScanPage> {
  /// QRScanner key
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  ///扫描结果
  Barcode? result;

  ///当前上下文
  late BuildContext curContext;

  ///扫描控制器
  QRViewController? controller;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    curContext = context;
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: (result != null)
                ? Text(
                    'Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                : const Text('请扫描...'),
          ),
        )
      ],
    );
  }

  ///当扫描部件打开时，持有控制器，创建结果回调处理
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.pauseCamera();
      setState(() {
        result = scanData;
        //获取父级 widget
        final parent =
            context.findAncestorWidgetOfExactType<QRScannerExample>();
        if (parent != null) {
          //添加到历史列表
          parent.onDataAdded(scanData);
        } else {
          Dialog(
            child: Text('没有找到父控件'),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

///历史记录页面
class HistoryPage extends StatelessWidget {
  List<Barcode> scanHistorys;
  HistoryPage({super.key, required this.scanHistorys});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: HistoryListView(scanHistorys: scanHistorys),
    );
  }
}

///历史记录列表
class HistoryListView extends StatelessWidget {
  List<Barcode> scanHistorys;
  HistoryListView({super.key, required this.scanHistorys});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: scanHistorys.length,
      itemBuilder: (BuildContext context, int index) {
        return ListTile(
          leading: GestureDetector(
            child: Icon(Icons.qr_code_2),
            onTap: () {
              // 在浏览器中打开
              _launchUrl(Uri.parse(scanHistorys[index].code!));
            },
          ),
          title: GestureDetector(
            child: Text('${scanHistorys[index].code}'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text('详情'),
                  content: Text(scanHistorys[index].code!), // 显示过长的链接
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          subtitle: Text('${describeEnum(scanHistorys[index].format)}'),
          trailing: GestureDetector(
            child: Icon(Icons.content_copy),
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: scanHistorys[index].code)); // 复制到剪贴板
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('已复制到剪贴板'),
                duration: Duration(seconds: 1),
              ));
            },
          ),
        );
      },
    );
  }

  ///打开浏览器访问链接
  void _launchUrl(Uri url) async {
    // if (await canLaunchUrl(url)) {
    //   await launchUrl(url);
    // } else {
    //   throw '打开 $url 错误';
    // }
    await launchUrl(url);
  }
}
