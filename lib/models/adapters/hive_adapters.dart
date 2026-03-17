// lib/models/adapters/hive_adapters.dart
import 'package:hive/hive.dart';
import '../user_model.dart';
import '../category_model.dart';
import '../course_model.dart';
import '../chapter_model.dart';
import '../video_model.dart';
import '../note_model.dart';
import '../question_model.dart';
import '../exam_model.dart';
import '../exam_result_model.dart';
import '../subscription_model.dart';
import '../payment_model.dart';
import '../notification_model.dart';
import '../progress_model.dart';
import '../chatbot_model.dart';
import '../streak_model.dart';
import '../school_model.dart';
import '../setting_model.dart';
import '../parent_link_model.dart';

part 'hive_adapters.g.dart';

// Run flutter pub run build_runner build to generate this file

@HiveType(typeId: 0)
class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    // FIX: Convert dynamic map to Map<String, dynamic>
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return User.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 1)
class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 1;

  @override
  Category read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Category.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 2)
class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 2;

  @override
  Course read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Course.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 3)
class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 3;

  @override
  Chapter read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Chapter.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 4)
class VideoAdapter extends TypeAdapter<Video> {
  @override
  final int typeId = 4;

  @override
  Video read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Video.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Video obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 5)
class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 5;

  @override
  Note read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Note.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 6)
class QuestionAdapter extends TypeAdapter<Question> {
  @override
  final int typeId = 6;

  @override
  Question read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Question.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Question obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 7)
class ExamAdapter extends TypeAdapter<Exam> {
  @override
  final int typeId = 7;

  @override
  Exam read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Exam.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Exam obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 8)
class ExamResultAdapter extends TypeAdapter<ExamResult> {
  @override
  final int typeId = 8;

  @override
  ExamResult read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return ExamResult.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, ExamResult obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 9)
class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 9;

  @override
  Subscription read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Subscription.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 10)
class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 10;

  @override
  Payment read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Payment.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 11)
class NotificationAdapter extends TypeAdapter<Notification> {
  @override
  final int typeId = 11;

  @override
  Notification read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Notification.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Notification obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 12)
class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 12;

  @override
  UserProgress read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return UserProgress.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 13)
class ChatbotMessageAdapter extends TypeAdapter<ChatbotMessage> {
  @override
  final int typeId = 13;

  @override
  ChatbotMessage read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return ChatbotMessage.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, ChatbotMessage obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 14)
class ChatbotConversationAdapter extends TypeAdapter<ChatbotConversation> {
  @override
  final int typeId = 14;

  @override
  ChatbotConversation read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return ChatbotConversation.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, ChatbotConversation obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 15)
class StreakAdapter extends TypeAdapter<Streak> {
  @override
  final int typeId = 15;

  @override
  Streak read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Streak.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Streak obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 16)
class SchoolAdapter extends TypeAdapter<School> {
  @override
  final int typeId = 16;

  @override
  School read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return School.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, School obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 17)
class SettingAdapter extends TypeAdapter<Setting> {
  @override
  final int typeId = 17;

  @override
  Setting read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return Setting.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, Setting obj) {
    writer.write(obj.toJson());
  }
}

@HiveType(typeId: 18)
class ParentLinkAdapter extends TypeAdapter<ParentLink> {
  @override
  final int typeId = 18;

  @override
  ParentLink read(BinaryReader reader) {
    final dynamicMap = reader.read();
    final Map<String, dynamic> typedMap = {};
    if (dynamicMap is Map) {
      dynamicMap.forEach((key, value) {
        typedMap[key.toString()] = value;
      });
    }
    return ParentLink.fromJson(typedMap);
  }

  @override
  void write(BinaryWriter writer, ParentLink obj) {
    writer.write(obj.toJson());
  }
}
