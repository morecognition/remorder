import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_remo/flutter_remo.dart';
import 'package:path_provider/path_provider.dart';

class RemoTransmission extends StatelessWidget {
  @override
  Widget build(BuildContext _) {
    Future<Directory> tmpDirectory = getTemporaryDirectory();
    Future<Directory?> externalStorageDirectory = getExternalStorageDirectory();
    final String tmpFileName = 'tmp.json';
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: BlocBuilder<RemoBloc, RemoState>(
          builder: (builderContext, remoState) {
            if (remoState is Connected) {
              return IconButton(
                icon: Icon(Icons.play_arrow),
                onPressed: () {
                  BlocProvider.of<RemoBloc>(builderContext)
                      .add(OnStartTransmission());
                },
              );
            } else if (remoState is StartingTransmission ||
                remoState is StoppingTransmission) {
              return Center(
                child: CircularProgressIndicator(),
              );
            } else if (remoState is TransmissionStarted) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Container(
                    height: 45,
                    width: MediaQuery.of(builderContext).size.width * 0.95,
                    child: Row(
                      children: [
                        _ColorLabel(color: Colors.red, text: 'C1'),
                        Spacer(),
                        _ColorLabel(color: Colors.pink, text: 'C2'),
                        Spacer(),
                        _ColorLabel(color: Colors.orange, text: 'C3'),
                        Spacer(),
                        _ColorLabel(color: Colors.yellow, text: 'C4'),
                        Spacer(),
                        _ColorLabel(color: Colors.green, text: 'C5'),
                        Spacer(),
                        _ColorLabel(color: Colors.green.shade900, text: 'C6'),
                        Spacer(),
                        _ColorLabel(color: Colors.blue, text: 'C7'),
                        Spacer(),
                        _ColorLabel(color: Colors.grey, text: 'C8'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FutureBuilder<Directory?>(
                        future: tmpDirectory,
                        builder: (BuildContext context,
                            AsyncSnapshot<Directory?> snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return _DataChart(
                              remoDataStream: remoState.remoDataStream,
                              tmpDirectory: snapshot.data!,
                              tmpFileName: tmpFileName,
                            );
                          } else {
                            return CircularProgressIndicator();
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: () {
                      BlocProvider.of<RemoBloc>(builderContext).add(
                        OnStopTransmission(),
                      );
                    },
                  ),
                  SizedBox(height: 15),
                ],
              );
            } else if (remoState is Disconnected) {
              return Center(
                child: Text('Please go back and connect Remo.'),
              );
            } else if (remoState is TransmissionStopped) {
              return FutureBuilder(
                future: Future.wait([tmpDirectory, externalStorageDirectory]),
                builder: (BuildContext context,
                    AsyncSnapshot<List<dynamic>> snapshot) {
                  if (snapshot.hasData &&
                      snapshot.data != null &&
                      snapshot.data![0] != null &&
                      snapshot.data![1] != null) {
                    return _SavePrompt(
                      tmpDirectory: snapshot.data![0]! as Directory,
                      externalStorageDirectory: snapshot.data![1]! as Directory,
                      tmpFileName: tmpFileName,
                    );
                  } else {
                    return CircularProgressIndicator();
                  }
                },
              );
            } else {
              return Center(
                child: Text(
                  'Unhandled state: ' + remoState.runtimeType.toString(),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _ColorLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(),
            color: color,
            borderRadius: BorderRadius.all(
              Radius.circular(20),
            ),
          ),
          width: 30,
          height: 25,
        ),
        Text(text),
      ],
    );
  }

  const _ColorLabel({Key? key, required this.color, required this.text})
      : super(key: key);
  final Color color;
  final String text;
}

class _DataChart extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _DataChartState(
      remoDataStream: remoDataStream,
      tmpDirectory: tmpDirectory,
      tmpFileName: tmpFileName,
    );
  }

  const _DataChart({
    Key? key,
    required this.remoDataStream,
    required this.tmpDirectory,
    required this.tmpFileName,
  }) : super(key: key);

  final Stream<RemoData> remoDataStream;
  final Directory tmpDirectory;
  final String tmpFileName;
}

class _DataChartState extends State<_DataChart> {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 20,
        minX: _emgChannels[0].first.x,
        maxX: _emgChannels[0].last.x,
        lineTouchData: LineTouchData(enabled: false),
        clipData: FlClipData.all(),
        gridData: FlGridData(show: true),
        lineBarsData: [
          emgLine(0, Colors.red),
          emgLine(1, Colors.pink),
          emgLine(2, Colors.orange),
          emgLine(3, Colors.yellow),
          emgLine(4, Colors.green),
          emgLine(5, Colors.green.shade900),
          emgLine(6, Colors.blue),
          emgLine(7, Colors.grey),
        ],
        axisTitleData: FlAxisTitleData(
          leftTitle: AxisTitle(
              showTitle: true,
              titleText: 'millivolt',
              margin: 0,
              textAlign: TextAlign.right),
          bottomTitle: AxisTitle(
              showTitle: true,
              titleText: 'samples',
              margin: 0,
              textAlign: TextAlign.right),
        ),
      ),
      swapAnimationDuration: Duration.zero,
    );
  }

  LineChartBarData emgLine(int emgIndex, Color color) {
    return LineChartBarData(
      spots: _emgChannels[emgIndex],
      dotData: FlDotData(show: false),
      isCurved: false,
      colors: [color],
      barWidth: 2,
    );
  }

  @override
  void initState() {
    super.initState();
    // Creating file handle.
    String path = tmpDirectory.path;
    file = File('$path/$tmpFileName');
    // Overwriting an empty string to make sure the file has no content.
    file.writeAsString('');
    remoStreamSubscription = remoDataStream.listen(
      (remoData) {
        setState(
          () {
            // Adding value to the chart's buffer.
            for (int i = 0; i < channels; ++i) {
              _emgChannels[i].add(
                FlSpot(xvalue, remoData.emg[i]),
              );
              _emgChannels[i].removeAt(0);
            }
            xvalue += step;

            // Appending received remo data to the file as JSON.
            file.writeAsString(
              remoData.toJson().toString(),
              mode: FileMode.append,
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    remoStreamSubscription.cancel();
  }

  _DataChartState({
    required this.remoDataStream,
    required this.tmpDirectory,
    required this.tmpFileName,
  });

  double xvalue = 0;
  double step = 0.05;

  // Number of samples to keep in the graph;
  static const int _windowSize = 100;
  // 8 is the number of EMG channels available in Remo.
  static const int channels = 8;
  List<List<FlSpot>> _emgChannels = List.generate(
    channels,
    (int) => List<FlSpot>.generate(
      _windowSize,
      (int) => FlSpot(0, 0),
      growable: true,
    ),
  );

  late Directory tempDir;
  late File file;

  late final StreamSubscription<RemoData> remoStreamSubscription;
  final Stream<RemoData> remoDataStream;
  final Directory tmpDirectory;
  final String tmpFileName;
}

class _SavePrompt extends StatefulWidget {
  const _SavePrompt(
      {Key? key,
      required this.tmpDirectory,
      required this.tmpFileName,
      required this.externalStorageDirectory})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SaveState(
        tmpDirectory: tmpDirectory,
        tmpFileName: tmpFileName,
        externalStorageDirectory: externalStorageDirectory);
  }

  final Directory tmpDirectory;
  final Directory externalStorageDirectory;
  final String tmpFileName;
}

class _SaveState extends State<_SavePrompt> {
  final Directory tmpDirectory;
  final Directory externalStorageDirectory;
  final String tmpFileName;
  late String selectedFileName = tmpFileName;

  _SaveState({
    required this.tmpDirectory,
    required this.tmpFileName,
    required this.externalStorageDirectory,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          child: TextField(
            onChanged: (value) {
              setState(() {
                selectedFileName = value;
              });
            },
          ),
        ),
        Text('.json'),
        TextButton(
          onPressed: () async {
            if (tmpFileName.isEmpty) {
              return;
            }

            final String newFilePath =
                externalStorageDirectory.path + '/$selectedFileName.json';
            final String tmpFilePath = tmpDirectory.path + '/$tmpFileName';

            File tmpFile = File(tmpFilePath);
            await tmpFile.copy(newFilePath);

            await tmpFile.delete();

            BlocProvider.of<RemoBloc>(context).add(OnResetTransmission());
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
