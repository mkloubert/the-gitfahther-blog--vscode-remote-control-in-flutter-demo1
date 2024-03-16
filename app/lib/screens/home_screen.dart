// MIT License
//
// Copyright (c) 2024 Marcel Joachim Kloubert (https://marcel.coffee)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// The initial basic home screen.
class HomeScreen extends StatefulWidget {
  /// Initializes a new instance of this class, with an optional
  /// and custom [key].
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    if (_isOpening) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      return Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: _pickAndOpenFileOnRemote,
          child: const Text("Open file in VSCode"),
        ),
      );
    }
  }

  Future<void> _pickAndOpenFileOnRemote() async {
    setState(() {
      _isOpening = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Select text file',
          allowMultiple: false,
          type: FileType.any,
          withData: true);
      if (result == null) {
        return;
      }
      if (result.files.length != 1) {
        return;
      }

      final selectedFile = result.files[0];

      final url = Uri.parse("http://localhost:4000/api/v1/editors");
      final headers = {
        "Content-Type": "application/json",
      };
      final body = {
        'extension': selectedFile.extension ?? '',
        'text': utf8.decoder.convert(selectedFile.bytes!)
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode != 204) {
        throw HttpException(
          "Unexpected status code: ${response.statusCode}",
          uri: url,
        );
      }
    } catch (error) {
      _showErrorDialog(error);
    } finally {
      setState(() {
        _isOpening = false;
      });
    }
  }

  _showErrorDialog(dynamic error) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ERROR!'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("$error"),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).catchError((error) {
      print("ERROR: $error");
    });
  }
}
