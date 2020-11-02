import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_signalr_test/main.dart';
import 'package:flutter_app_signalr_test/models/chat_model.dart';
import 'package:flutter_app_signalr_test/models/firebase_login_model.dart';
import 'package:signalr_core/signalr_core.dart';

import 'chat_page.dart';
import 'models/message_model.dart';
import 'package:http/http.dart' as http;

class HostChatPage extends StatefulWidget {
  final FirebaseLoginModel firebaseLoginModel;

  HostChatPage(this.firebaseLoginModel);

  @override
  _HostChatPageState createState() => _HostChatPageState();
}

class _HostChatPageState extends State<HostChatPage> {
  ChatUserModel chatPartner;
  List<MessageModel> messages = [];
  HubConnection connection;

  Future<List<ChatUserModel>> getUsers() async {
    List<ChatUserModel> chatModels = [];
    final response = await http.get(
        'https://ankiisignalrtest.azurewebsites.net/api/apihome',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.firebaseLoginModel.idToken}',
        });
    if (response.statusCode == 200) {
      var listJson = jsonDecode(response.body.toString());
      var listUsers =
          (listJson as List).map((e) => ChatUserModel.fromJson(e)).toList();
      chatModels = listUsers;
    } else {
      chatModels = [];
    }
    return chatModels;
  }

  disconnect() async {
    if (connection != null) {
      if (chatPartner != null) {
        connection.invoke(DISCONNECT_WITH_PARTNER, args: [chatPartner.email]);
      }
      connection.invoke(DISCONNECT);
      connection.stop();
    }
  }

  connect() async {
    connection = HubConnectionBuilder()
        .withUrl(
            '$DOMAIN/chathub',
            HttpConnectionOptions(logging: (level, mess) {
              print("[${level.index}] : $mess");
            }, accessTokenFactory: () async {
              return widget.firebaseLoginModel.idToken;
            }))
        .build();
    await connection.start();
    connection.on(RECEIVE_MESSAGE, (arguments) {
      if (arguments is List) {
        _onMessage(arguments);
        _onConnectWithPartner(arguments);
        _onDisconnectWithPartner(arguments);
        setState(() {});
      }
    });
  }

  _onMessage(List arguments) {
    if (arguments.length == 3) {
      if (arguments.first == RECEIVE_MESSAGE) {
        messages.add(ChatMessageModel(
            from: arguments[1],
            content: arguments.last,
            dateTime: DateTime.now()));
      }
    }
  }

  _onConnectWithPartner(List arguments) {
    if (arguments.length == 2) {
      if (arguments.first == CONNECT_WITH_PARTNER) {
        chatPartner = ChatUserModel(
            hasPartner: true, email: arguments.last, isConnected: true);
        messages.add(MessageModel(
            content: '${chatPartner.email} joined', dateTime: DateTime.now()));
      }
    }
  }

  _onDisconnectWithPartner(List arguments) {
    if (arguments.length == 2) {
      if (arguments.first == DISCONNECT_WITH_PARTNER) {
        chatPartner = null;
        messages = [];
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connect();
    Future.delayed(Duration(seconds: 30), () {
      if (chatPartner == null && this.mounted) {
        disconnect();
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          await disconnect();
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  disconnect();
                  Navigator.pop(context);
                }),
            title: chatPartner != null ? Text(chatPartner.email) : null,
          ),
          body: Container(
            padding: EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Expanded(child: _buildMessages()), _buildInput()],
            ),
          ),
        ));
  }

  final controller = TextEditingController();

  Widget _buildMessages() {
    return chatPartner == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              Text('Dang tim nguoi chat')
            ],
          )
        : ListView(
            children: messages.map((e) => __buildMessage(e)).toList(),
          );
  }

  Widget __buildMessage(MessageModel messageModel) {
    return Container(
      margin: EdgeInsets.all(10),
      alignment: !(messageModel is ChatMessageModel)
          ? Alignment.center
          : messageModel is ChatMessageModel &&
                  messageModel.from == widget.firebaseLoginModel.email
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Column(
        children: [
          Text(
            messageModel.dateTime.toString(),
            style: TextStyle(fontSize: 10, color: Colors.black12),
          ),
          Text(messageModel.content),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      child: chatPartner == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                        fillColor: Colors.black12,
                        filled: true,
                        border: InputBorder.none),
                  ),
                ),
                IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () async {
                      if (connection != null) {
                        connection.invoke(SEND_MESSAGE,
                            args: [chatPartner.email, controller.text]);
                        controller.text = '';
                      }
                    })
              ],
            ),
    );
  }
}
