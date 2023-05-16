import 'package:flutter/material.dart';
import 'dart:io';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
//打开浏览器
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(
    const MaterialApp(
      home: QRScannerExample(),
    ),
  );
}

///示例app
class QRScannerExample extends StatefulWidget {
  const QRScannerExample({super.key});

  @override
  State<QRScannerExample> createState() => _QRScannerExampleState();
}

/// 扫描示例app
class _QRScannerExampleState extends State<QRScannerExample> {
  ///扫描结果列表, final只是不能重新分配，内容是可以修改的
  final List<Barcode> scanHistorys = [];

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
    // setState(() {// scanpage已经刷新了，历史页面未加载不用刷新，app页面也不用
    scanHistorys.add(newData);
    // });
  }

  @override
  Widget build(BuildContext context) {
    //根据当前坐标选择页面
    switch (_selectedIndex) {
      case 0:
        curPage = ScanPage(
          onGetScanData: addData,
        );
        break;
      case 1:
        curPage = HistoryPage(scanHistorys: scanHistorys);
        break;
      default:
        throw '错误的tab index';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("二维码扫描器"),
      ),
      body: curPage, // 当前页面
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
  final void Function(Barcode newData) onGetScanData;
  const ScanPage({super.key, required this.onGetScanData});

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

  late Function onGetScanData;

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
        widget.onGetScanData(result!);
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
  final List<Barcode> scanHistorys;
  const HistoryPage({super.key, required this.scanHistorys});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: HistoryListView(scanHistorys: scanHistorys),
    );
  }
}

///历史记录列表
class HistoryListView extends StatelessWidget {
  final List<Barcode> scanHistorys;
  const HistoryListView({super.key, required this.scanHistorys});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: scanHistorys.length,
      itemBuilder: (BuildContext context, int index) {
        return ListTile(
          leading: GestureDetector(
            child: const Icon(Icons.qr_code_2),
            onTap: () {
              // 在浏览器中打开
              _launchUrl(Uri.parse(scanHistorys[index].code!), context);
            },
          ),
          title: GestureDetector(
            child: Text('${scanHistorys[index].code}'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('详情'),
                  content: Text(scanHistorys[index].code!), // 显示过长的链接
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          subtitle: Text(describeEnum(scanHistorys[index].format)),
          trailing: GestureDetector(
            child: const Icon(Icons.content_copy),
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: scanHistorys[index].code)); // 复制到剪贴板
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
  void _launchUrl(Uri url, BuildContext context) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('没有找到合适的处理应用'),
        duration: Duration(seconds: 1),
      ));
    }
  }
}
