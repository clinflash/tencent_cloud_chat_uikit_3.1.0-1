import 'dart:convert';
import 'dart:io';

import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/tim_uikit_cloud_custom_data.dart';
import 'package:tencent_im_base/tencent_im_base.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class TUIChatModelTools {
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();

  OfflinePushInfo buildMessagePushInfo(
      V2TimMessage message, String convID, ConvType convType, String lang) {
    String createJSON(String convID) {
      return "{\"conversationID\": \"$convID\"}";
    }

    if (globalModel.chatConfig.offlinePushInfo != null) {
      final customData =
          globalModel.chatConfig.offlinePushInfo!(message, convID, convType);
      if (customData != null) {
        return customData;
      }
    }

    String title = lang == 'zh'
        ? '收到聊天消息，请立即查看'
        : 'You have received a chat message. Please check it immediately';

    // If user provides null, use default ext.
    String ext = globalModel.chatConfig.notificationExt != null
        ? globalModel.chatConfig.notificationExt!(message, convID, convType) ??
            (convType == ConvType.c2c
                ? createJSON("c2c_${message.sender}")
                : createJSON("group_$convID"))
        : (convType == ConvType.c2c
            ? createJSON("c2c_${message.sender}")
            : createJSON("group_$convID"));

    String desc = message.userID ?? message.groupID ?? "";
    String messageSummary = "";
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        messageSummary = lang == 'zh' ? "自定义消息" : 'Custom message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        messageSummary = lang == 'zh' ? "表情消息" : 'Emoji message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        messageSummary = lang == 'zh' ? '文件消息' : 'File message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        messageSummary = lang == 'zh'? '群提示消息':'Group notification';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        messageSummary = lang == 'zh'? '图片消息': 'Image message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        messageSummary =lang == 'zh'? '位置消息': 'Location message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        messageSummary =lang == 'zh'? '合并转发消息': 'Combined message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        messageSummary =lang == 'zh'? '语音消息': 'Voice message';
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        messageSummary = message.textElem!.text!;
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        messageSummary =lang == 'zh'? '视频消息': 'Video message';
        break;
    }

    if (globalModel.chatConfig.notificationBody != null) {
      desc =
          globalModel.chatConfig.notificationBody!(message, convID, convType) ??
              messageSummary;
    } else {
      desc = messageSummary;
    }

    return OfflinePushInfo.fromJson({
      "title": title,
      "desc": desc,
      "disablePush": false,
      "ext": ext,
      "iOSSound": globalModel.chatConfig.notificationIOSSound,
      "androidSound": globalModel.chatConfig.notificationAndroidSound,
      "ignoreIOSBadge": false,
      "androidOPPOChannelID": globalModel.chatConfig.notificationOPPOChannelID,
    });
  }

  V2TimMessage setUserInfoForMessage(V2TimMessage messageInfo, String? id) {
    final loginUserInfo = _coreServices.loginUserInfo;
    if (loginUserInfo != null) {
      messageInfo.faceUrl = loginUserInfo.faceUrl;
      messageInfo.nickName = loginUserInfo.nickName;
      messageInfo.sender = loginUserInfo.userID;
    }
    messageInfo.timestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000).ceil();
    messageInfo.isSelf = true;
    messageInfo.id = id;

    return messageInfo;
  }

  String getMessageSummary(V2TimMessage message,
      String? Function(V2TimMessage message)? abstractMessageBuilder) {
    final String? customAbstractMessage =
        abstractMessageBuilder != null ? abstractMessageBuilder(message) : null;
    if (customAbstractMessage != null) {
      return customAbstractMessage;
    }

    final elemType = message.elemType;
    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return "[表情消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return "[自定义消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return "[文件消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return "[群消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return "[图片消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return "[位置消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return "[合并消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_NONE:
        return "[没有元素]";
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return "[语音消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text ?? "[文本消息]";
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return "[视频消息]";
      default:
        return "";
    }
  }

  String getMessageAbstract(V2TimMessage message,
      String? Function(V2TimMessage message)? abstractMessageBuilder) {
    final messageAbstract = RepliedMessageAbstract(
        summary: TIM_t(getMessageSummary(message, abstractMessageBuilder)),
        elemType: message.elemType,
        msgID: message.msgID,
        timestamp: message.timestamp,
        seq: message.seq);
    return jsonEncode(messageAbstract.toJson());
  }

  Future<V2TimMessage?> getExistingMessageByID(
      {required String msgID,
      required String conversationID,
      required ConvType conversationType}) async {
    final currentHistoryMsgList =
        globalModel.messageListMap[conversationID] ?? [];
    final int? targetIndex = currentHistoryMsgList.indexWhere((item) {
      return item.msgID == msgID;
    });

    if (targetIndex != null &&
        targetIndex > -1 &&
        currentHistoryMsgList.isNotEmpty) {
      return currentHistoryMsgList[targetIndex];
    } else {
      return null;
    }
  }

  Future<bool> hasZeroSize(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      return fileSize == 0;
    } catch (e) {
      return false;
    }
  }
}
