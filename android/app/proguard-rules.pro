# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Video Player
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# GSON/JSON
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# HTTP/Network
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Firebase Messaging
-keep class com.google.firebase.messaging.FirebaseMessagingService { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService {
    <init>();
    void onCreate();
    void onMessageReceived(com.google.firebase.messaging.RemoteMessage);
}

# Firebase Analytics
-keep class com.google.firebase.analytics.FirebaseAnalytics { *; }
-keep class * extends com.google.firebase.analytics.FirebaseAnalytics {
    <init>();
}

# Desugar JDK libs
-keep class com.android.tools.desugar.runtime.** { *; }

# Keep annotations
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

# Keep application class
-keep public class * extends android.app.Application

# Keep callback methods
-keepclassmembers class * {
    public void on*(**);
}

# Keep resource class members
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-keep class com.google.gson.** { *; }

# Dio
-keep class com.dio.** { *; }
-dontwarn com.dio.**

# Shared Preferences
-keep class * implements android.content.SharedPreferences { *; }

# Material Design
-keep class com.google.android.material.** { *; }

# Exoplayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Timezone data
-keep class tzdata.** { *; }

# JWT/Encryption
-keep class * extends java.security.Key {
    *;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# For enumeration support
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep View bindings
-keepclassmembers class * extends android.view.View {
   void set*(***);
   *** get*();
}